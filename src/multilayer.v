`default_nettype none

module Multilayer #(
    parameter ADDR_W = 4,
    parameter DW     = 8
)(
    input  wire [7:0] ui_in,
    input  wire [7:0] uio_in,
    input  wire       start,
    input  wire       clk,
    input  wire       rst_n,
    // ---- read channel (existing) ----
    output reg                    w_req,
    output reg  [ADDR_W-1:0]      w_addr,
    input  wire                   w_valid,
    input  wire [DW-1:0]          w_data,
    // ---- write-back channel (NEW) ----
    output reg                    wb_req,
    output reg  [ADDR_W-1:0]      wb_addr,
    output reg  [DW-1:0]          wb_wdata,
    input  wire                   wb_ack,
    // ---- results ----
    output reg  [7:0]             prediction,
    output reg                    done
);
    // packed addresses: {w1,w2} and {w3,w4}
    localparam [ADDR_W-1:0] W12_ADDR = 4'h0;
    localparam [ADDR_W-1:0] W34_ADDR = 4'h1;

    localparam [7:0] TH1 = 8'h01, TH2 = 8'h01;

    // latch inputs
    reg [7:0] in_a, in_b;
    wire [7:0] a_hi = {4'b0, in_a[7:4]};
    wire [7:0] a_lo = {4'b0, in_a[3:0]};
    wire [7:0] b_hi = {4'b0, in_b[7:4]};
    wire [7:0] b_lo = {4'b0, in_b[3:0]}; // ← 元の[3:1]はバグに見えるので修正

    // L1
    reg [7:0] l1_sum1, l1_sum2;
    reg       stateA, stateB;

    // weights (signed 4-bit)
    reg  signed [3:0] w1, w2, w3, w4;

    // for compute
    reg [7:0] next1, next2, next3, next4;
    reg [7:0] l2_sum1, l2_sum2;

    // signed shift helper
    function automatic [7:0] shift_by_signed(input [7:0] x, input signed [3:0] s);
        begin
            shift_by_signed = (s >= 0) ? (x << s) : (x >> -s);
        end
    endfunction

    // saturating add for signed 4-bit (-8..+7)
    function automatic signed [3:0] sat_add_s4(
        input signed [3:0] x,
        input signed [3:0] delta
    );
        automatic signed [4:0] t;
        begin
            t = x + delta;               // 5bitで計算
            if      (t >  7) sat_add_s4 =  7;
            else if (t < -8) sat_add_s4 = -8;
            else             sat_add_s4 = t[3:0];
        end
    endfunction

    typedef enum logic [3:0] {
        S_IDLE        = 4'd0,
        S_L1_ACCUM    = 4'd1,
        // reads
        S_RD_W12_REQ  = 4'd2,
        S_RD_W12_GET  = 4'd3,
        S_RD_W34_REQ  = 4'd4,
        S_RD_W34_GET  = 4'd5,
        // compute + update
        S_L2_COMPUTE  = 4'd6,
        // write-backs
        S_WB_W12_REQ  = 4'd7,
        S_WB_W12_ACK  = 4'd8,
        S_WB_W34_REQ  = 4'd9,
        S_WB_W34_ACK  = 4'd10,
        S_DONE        = 4'd11
    } state_t;

    state_t st, st_n;

    // ------------ next-state / requests (comb) ------------
    always @* begin
        st_n   = st;
        w_req  = 1'b0; w_addr  = '0;
        wb_req = 1'b0; wb_addr = '0; wb_wdata = '0;

        unique case (st)
            S_IDLE:       if (start) st_n = S_L1_ACCUM;

            S_L1_ACCUM:   st_n = S_RD_W12_REQ;

            S_RD_W12_REQ: begin w_req=1'b1; w_addr=W12_ADDR; st_n=S_RD_W12_GET; end
            S_RD_W12_GET: if (w_valid) st_n = S_RD_W34_REQ;

            S_RD_W34_REQ: begin w_req=1'b1; w_addr=W34_ADDR; st_n=S_RD_W34_GET; end
            S_RD_W34_GET: if (w_valid) st_n = S_L2_COMPUTE;

            S_L2_COMPUTE: st_n = S_WB_W12_REQ;

            // write-back {w1,w2}
            S_WB_W12_REQ: begin
                wb_req  = 1'b1;
                wb_addr = W12_ADDR;
                wb_wdata= {w1[3:0], w2[3:0]};
                st_n    = S_WB_W12_ACK;
            end
            S_WB_W12_ACK: if (wb_ack) st_n = S_WB_W34_REQ;

            // write-back {w3,w4}
            S_WB_W34_REQ: begin
                wb_req  = 1'b1;
                wb_addr = W34_ADDR;
                wb_wdata= {w3[3:0], w4[3:0]};
                st_n    = S_WB_W34_ACK;
            end
            S_WB_W34_ACK: if (wb_ack) st_n = S_DONE;

            S_DONE:       st_n = S_IDLE;
            default:      st_n = S_IDLE;
        endcase
    end

    // ------------ sequential ------------
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begn
            st <= S_IDLE;
            in_a <= 0; in_b <= 0;
            l1_sum1 <= 0; l1_sum2 <= 0;
            stateA <= 0; stateB <= 0;
            w1 <= 0; w2 <= 0; w3 <= 0; w4 <= 0;
            next1<=0; next2<=0; next3<=0; next4<=0;
            l2_sum1<=0; l2_sum2<=0;
            prediction <= 0;
            done <= 0;
        end else begin
            st   <= st_n;
            done <= 1'b0;

            unique case (st)
                S_IDLE: if (start) begin
                    in_a <= ui_in;
                    in_b <= uio_in;
                end

                // L1: nibble和 & しきい値判定
                S_L1_ACCUM: begin
                    l1_sum1 <= a_hi + a_lo;
                    l1_sum2 <= b_hi + b_lo;
                    stateA  <= (a_hi + a_lo) > TH1;
                    stateB  <= (b_hi + b_lo) > TH2;
                end

                // 読取りで得た2ニブルをそれぞれ符号付き4bitで格納
                S_RD_W12_GET: if (w_valid) begin
                    w1 <= w_data[7:4];
                    w2 <= w_data[3:0];
                end
                S_RD_W34_GET: if (w_valid) begin
                    w3 <= w_data[7:4];
                    w4 <= w_data[3:0];
                end

                // L2計算 + 重み更新（あなたのロジックを同期化）
                S_L2_COMPUTE: begin
                    // 条件付きシフト（満たさない側は0）
                    next1 <= stateA ? shift_by_signed(l1_sum1, w1) : 8'h00;
                    next3 <= stateA ? shift_by_signed(l1_sum1, w2) : 8'h00;
                    next2 <= stateB ? shift_by_signed(l1_sum2, w3) : 8'h00;
                    next4 <= stateB ? shift_by_signed(l1_sum2, w4) : 8'h00;

                    l2_sum1 <= (stateA ? shift_by_signed(l1_sum1, w1) : 8'h00)
                             + (stateB ? shift_by_signed(l1_sum2, w3) : 8'h00);
                    l2_sum2 <= (stateA ? shift_by_signed(l1_sum1, w2) : 8'h00)
                             + (stateB ? shift_by_signed(l1_sum2, w4) : 8'h00);

                    // === 重み更新（元コードの意図を同期的に再現 / 符号4bitで飽和）===
                    // sum1 と TH1 に応じて w1,w3 を ±1
                    if (l1_sum1 > TH1) begin
                        w1 <= sat_add_s4(w1, stateA ? 4'sd1 : -4'sd1);
                        w3 <= sat_add_s4(w3, stateB ? 4'sd1 : -4'sd1);
                    end else begin
                        if (stateA) w1 <= sat_add_s4(w1, -4'sd1);
                        if (stateB) w3 <= sat_add_s4(w3, -4'sd1);
                    end
                    // sum2 と TH2 に応じて w2,w4 を ±1
                    if (l1_sum2 > TH2) begin
                        w2 <= sat_add_s4(w2, stateA ? 4'sd1 : -4'sd1);
                        w4 <= sat_add_s4(w4, stateB ? 4'sd1 : -4'sd1);
                    end else begin
                        if (stateA) w2 <= sat_add_s4(w2, -4'sd1);
                        if (stateB) w4 <= sat_add_s4(w4, -4'sd1);
                    end

                    // 最終出力はここでは出さず（必要なら別ステートで）
                    prediction <= (l2_sum1 << w5) + (l2_sum2 << w6); // 例：最後にw5/w6を使うなら加えて拡張可
                end

                // 書戻しは TOP 側の wb_ack で進む
                S_WB_W12_ACK: /* no reg changes here except ackを見るだけ */;
                S_WB_W34_ACK: /* 同上 */;

                S_DONE: begin
                    done <= 1'b1; // 1サイクル完了パルス
                end
            endcase
        end
    end
endmodule
i
