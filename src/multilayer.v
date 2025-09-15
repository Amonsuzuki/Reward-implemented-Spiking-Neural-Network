`default_nettype none

module Multilayer #(
    parameter ADDR_W = 4,
    parameter DW     = 8
)(
    input  wire [7:0] ui_in,
    input  wire [7:0] uio_in,
    input  wire       start,     // Phase1の開始パルス（TOPから1サイクル）
    input  wire       clk,
    input  wire       rst_n,

    // ---- weight read channel (to/from TOP) ----
    output reg                    w_req,      // 重み読み要求
    output reg  [ADDR_W-1:0]      w_addr,     // 読みたい重みアドレス
    input  wire                   w_valid,    // TOPがw_data有効を1サイクル出す
    input  wire [DW-1:0]          w_data,     // メモリから返るデータ（下位4bit使用）

    // ---- results ----
    output reg  [7:0]             prediction, // 最終出力
    output reg                    done        // 1サイクルだけHigh
);
    // ---- Memory上のアドレス割当（自由に再配置可）----
    localparam [ADDR_W-1:0] W1_ADDR = 4'h0;
    localparam [ADDR_W-1:0] W2_ADDR = 4'h1;
    localparam [ADDR_W-1:0] W3_ADDR = 4'h2;
    localparam [ADDR_W-1:0] W4_ADDR = 4'h3;

    // ---- しきい値 ----
    localparam [7:0] TH1 = 8'h01;
    localparam [7:0] TH2 = 8'h01;

    // ---- L1入力ラッチ ----
    reg [7:0] in_a, in_b;

    // nibbleを0拡張して8bitに（元コードと同じ意味）
    wire [7:0] a_hi = {4'b0000, in_a[7:4]};
    wire [7:0] a_lo = {4'b0000, in_a[3:0]};
    wire [7:0] b_hi = {4'b0000, in_b[7:4]};
    wire [7:0] b_lo = {4'b0000, in_b[3:1]};

    // ---- L1結果/状態 ----
    reg [7:0] l1_sum1, l1_sum2;
    reg       stateA, stateB;   // (sum1>TH1), (sum2>TH2)

    // ---- L2途中値 ----
    reg [7:0] next1, next2, next3, next4;
    reg [7:0] l2_sum1, l2_sum2;

    // ---- 重みレジスタ ----
    reg  signed [3:0] w1, w2, w3, w4; // L2で使う符号付きシフト量
    reg         [3:0] w5, w6;         // 最後の左シフト量（非符号）

    // ---- 符号付きシフト関数（負なら右シフト）----
    
    function automatic [7:0] shift_by_signed(
        input [7:0] x,
        input signed [3:0] s
    );
        begin
            shift_by_signed = (s >= 0) ? (x << s) : (x >> -s);
        end
    endfunction


    // ---- 状態機械 ----
    typedef enum logic [3:0] {
        S_IDLE       = 4'd0,
        S_L1_ACCUM   = 4'd1,
        S_L2_REQ_W1  = 4'd2,
        S_L2_GET_W1  = 4'd3,
        S_L2_REQ_W2  = 4'd4,
        S_L2_GET_W2  = 4'd5,
        S_L2_REQ_W3  = 4'd6,
        S_L2_GET_W3  = 4'd7,
        S_L2_REQ_W4  = 4'd8,
        S_L2_GET_W4  = 4'd9,
        S_L2_COMPUTE = 4'd10,    // L2の加算(sum1/2)を作る
        S_DONE       = 4'd11
    } state_t;

    state_t st, st_n;

    // ---- 次状態/リクエスト線（組合せ）----
    always @* begin
        st_n  = st;
        w_req = 1'b0;
        w_addr = '0;

        unique case (st)
            S_IDLE: begin
                if (start) st_n = S_L1_ACCUM;
            end

            // ---- Layer 1: nibble和→しきい値判定 ----
            S_L1_ACCUM: begin
                st_n = S_L2_REQ_W1;
            end

            // ---- Layer 2: 重みを順に取得（w1..w4,w5,w6）----
            S_L2_REQ_W1_2: begin
                w_req  = 1'b1; w_addr = W1_ADDR; st_n = S_L2_GET_W1_2;
            end
            S_L2_GET_W1_2: begin
                if (w_valid) st_n = S_L2_REQ_W3_4;
            end

            S_L2_REQ_W3_4: begin
                w_req  = 1'b1; w_addr = W2_ADDR; st_n = S_L2_GET_W3_4;
            end
            S_L2_GET_W3_4: begin
                if (w_valid) st_n = S_L2_COMPUTE;
            end

            // ---- L2の合成値(l2_sum1/l2_sum2)を作る ----
            S_L2_COMPUTE: begin
                st_n = S_DONE;
            end

            S_DONE: begin
                st_n = S_IDLE;
            end

            default: st_n = S_IDLE;
        endcase
    end

    // ---- 順序回路：レジスタ更新 ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st         <= S_IDLE;
            in_a       <= 8'h00;
            in_b       <= 8'h00;
            l1_sum1    <= 8'h00;
            l1_sum2    <= 8'h00;
            stateA     <= 1'b0;
            stateB     <= 1'b0;
            next1      <= 8'h00;
            next2      <= 8'h00;
            next3      <= 8'h00;
            next4      <= 8'h00;
            l2_sum1    <= 8'h00;
            l2_sum2    <= 8'h00;
            w1         <= '0;
            w2         <= '0;
            w3         <= '0;
            w4         <= '0;
            w5         <= '0;
            w6         <= '0;
            prediction <= 8'h00;
            done       <= 1'b0;
        end else begin
            st   <= st_n;
            done <= 1'b0;

            unique case (st)
                // --- 入力を開始時にラッチ ---
                S_IDLE: begin
                    if (start) begin
                        in_a <= ui_in;
                        in_b <= uio_in;
                    end
                end

                // --- L1: nibble和, しきい値判定 ---
                S_L1_ACCUM: begin
                    l1_sum1 <= a_hi + a_lo;          // = ui_in1 + ui_in2
                    l1_sum2 <= b_hi + b_lo;          // = uio_in3 + uio_in4
                    stateA  <= (l1_sum1 > TH1);
                    stateB  <= (l1_sum2 > TH2);
                end

                // --- 重みを受け取り次第レジスタへ ---
                S_L2_GET_W1_2: if (w_valid) w1 <= w_data[7:4]; // 符号付き4bitとして解釈
                S_L2_GET_W1_2: if (w_valid) w2 <= w_data[3:0];
                S_L2_GET_W3_4: if (w_valid) w3 <= w_data[7:4];
                S_L2_GET_W3_4: if (w_valid) w4 <= w_data[3:0];

                // --- L2: しきい値を満たした側だけシフト合成 ---
                S_L2_COMPUTE: begin
                    // デフォルト0（元コードのnext_input初期化相当）
                    next1 <= 8'h00; next2 <= 8'h00; next3 <= 8'h00; next4 <= 8'h00;

                    if (stateA) begin
                        next1 <= shift_by_signed(l1_sum1, w1);
                        next3 <= shift_by_signed(l1_sum1, w2);
                    end
                    if (stateB) begin
                        next2 <= shift_by_signed(l1_sum2, w3);
                        next4 <= shift_by_signed(l1_sum2, w4);
                    end

                    l2_sum1  <= next1 + next2
                    l2_sum2  <= next3 + next4

                    // 最終出力: (l2_sum1 << w5) + (l2_sum2 << w6)
                    prediction <= ( (l2_sum1 << w5) + (l2_sum2 << w6) );
                end

                // --- 完了パルス ---
                S_DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule
 
