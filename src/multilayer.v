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
    input  wire [DW-1:0]          w_data,     // メモリから返るデータ

    // ---- (現状未使用の) 2本目インタフェース: そのまま残す ----
    output reg                    wb_req,
    output reg  [ADDR_W-1:0]      wb_addr,
    input  wire                   wb_valid,
    input  wire [DW-1:0]          wb_data,

    // ---- results ----
    output reg  [7:0]             prediction, // 最終出力
    output reg                    done        // 1サイクルだけHigh
);

    // ---- Memory上のアドレス割当（W1|W2 と W3|W4 をパック）----
    localparam [ADDR_W-1:0] W12_ADDR = 4'h0;
    localparam [ADDR_W-1:0] W34_ADDR = 4'h1;

    // ---- しきい値 ----
    localparam [7:0] TH1 = 8'h01;
    localparam [7:0] TH2 = 8'h01;

    // ---- L1入力ラッチ ----
    reg [7:0] in_a, in_b;

    // nibbleを0拡張して8bitに（元コードに合わせ b_lo は [3:1] のまま）
    wire [7:0] a_hi = {4'b0000, in_a[7:4]};
    wire [7:0] a_lo = {4'b0000, in_a[3:0]};
    wire [7:0] b_hi = {4'b0000, in_b[7:4]};
    wire [7:0] b_lo = {4'b0000, in_b[3:1]};

    // ---- L1結果/状態 ----
    reg [7:0] l1_sum1, l1_sum2;
    reg       stateA, stateB;

    // ---- L2途中値 ----
    reg [7:0] next1, next2, next3, next4;
    reg [7:0] l2_sum1, l2_sum2;

    // ---- 重みレジスタ ----
    reg  signed [3:0] w1, w2, w3, w4; // 符号付き4bit
    reg         [3:0] w5, w6;         // 未使用だが保持

    // ---- 符号付きシフト関数（負なら右シフト）----
    function [7:0] shift_by_signed;
        input [7:0] x;
        input signed [3:0] s;
        begin
            if (s >= 0)
                shift_by_signed = x << s;
            else
                shift_by_signed = x >> (-s);
        end
    endfunction

    // （未使用だが残す）符号4bitの飽和加算
    function [3:0] sat_add_s4;
        input signed [3:0] x;
        input signed [3:0] delta;
        reg   signed [4:0] t;
        begin
            t = x + delta;
            if      (t >  7) sat_add_s4 = 4'sd7;
            else if (t < -8) sat_add_s4 = -4'sd8;
            else             sat_add_s4 = t[3:0];
        end
    endfunction

    // ---- 状態機械（列挙子名をコードに合わせて定義）----
    typedef enum logic [3:0] {
        S_IDLE         = 4'd0,
        S_L1_ACCUM     = 4'd1,
        S_L2_REQ_W1_2  = 4'd2,
        S_L2_GET_W1_2  = 4'd3,
        S_L2_REQ_W3_4  = 4'd4,
        S_L2_GET_W3_4  = 4'd5,
        S_L2_COMPUTE   = 4'd6,
        S_DONE         = 4'd7
    } state_t;

    state_t st, st_n;

    // ---- 次状態/リクエスト線（組合せ）----
    always @* begin
        st_n   = st;
        w_req  = 1'b0;
        w_addr = '0;

        // 未使用IFはデフォルト0
        wb_req  = 1'b0;
        wb_addr = '0;

        case (st)
            S_IDLE: begin
                if (start) st_n = S_L1_ACCUM;
            end

            S_L1_ACCUM: begin
                st_n = S_L2_REQ_W1_2;
            end

            S_L2_REQ_W1_2: begin
                w_req  = 1'b1;
                w_addr = W12_ADDR;
                st_n   = S_L2_GET_W1_2;
            end
            S_L2_GET_W1_2: begin
                if (w_valid) st_n = S_L2_REQ_W3_4;
            end

            S_L2_REQ_W3_4: begin
                w_req  = 1'b1;
                w_addr = W34_ADDR;
                st_n   = S_L2_GET_W3_4;
            end
            S_L2_GET_W3_4: begin
                if (w_valid)st_n = S_L2_COMPUTE;
            end

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

            case (st)
                // --- 入力を開始時にラッチ ---
                S_IDLE: begin
                    if (start) begin
                        in_a <= ui_in;
                        in_b <= uio_in;
                    end
                end

                // --- L1: nibble和, しきい値判定 ---
                S_L1_ACCUM: begin
                    l1_sum1 <= a_hi + a_lo;          // = ui_in[7:4] + ui_in[3:0]
                    l1_sum2 <= b_hi + b_lo;          // = uio_in[7:4] + uio_in[3:1]（元コード踏襲）
                    stateA  <= (a_hi + a_lo) > TH1;
                    stateB  <= (b_hi + b_lo) > TH2;
                end

                // --- 重みを受け取り: 同一ラベル重複を1つに統合 ---
                S_L2_GET_W1_2: begin
                    if (w_valid) begin
                        w1 <= w_data[7:4];
                        w2 <= w_data[3:0];
                    end
                end
                S_L2_GET_W3_4: begin
                    if (w_valid) begin
                        w3 <= w_data[7:4];
                        w4 <= w_data[3:0];
                    end
                end

                // --- L2: しきい値を満たした側だけシフト合成 ---
                S_L2_COMPUTE: begin
                    next1 <= stateA ? shift_by_signed(l1_sum1, w1) : 8'h00;
                    next3 <= stateA ? shift_by_signed(l1_sum1, w2) : 8'h00;
                    next2 <= stateB ? shift_by_signed(l1_sum2, w3) : 8'h00;
                    next4 <= stateB ? shift_by_signed(l1_sum2, w4) : 8'h00;

                    l2_sum1 <= (stateA ? shift_by_signed(l1_sum1, w1) : 8'h00)
                             + (stateB ? shift_by_signed(l1_sum2, w3) : 8'h00);
                    l2_sum2 <= (stateA ? shift_by_signed(l1_sum1, w2) : 8'h00)
                             + (stateB ? shift_by_signed(l1_sum2, w4) : 8'h00);

                    prediction <= (l2_sum1 << w5) + (l2_sum2 << w6); // 元の式の枠に合わせ簡略（意味は不変のまま参照）
                end

                // --- 完了パルス ---
                S_DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule
 
