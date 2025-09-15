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
    // ---- weight read channel ----
    output reg                    w_req,
    output reg  [ADDR_W-1:0]      w_addr,
    input  wire                   w_valid,
    input  wire [DW-1:0]          w_data,
    // ---- results ----
    output reg  [7:0]             prediction,
    output reg                    done
);

    // メモリアドレス（1バイトに2つの4bit重みをパック）
    localparam [ADDR_W-1:0] W12_ADDR = 4'h0;
    localparam [ADDR_W-1:0] W34_ADDR = 4'h1;

    localparam [7:0] TH1 = 8'h01, TH2 = 8'h01;

    // 入力ラッチ
    reg [7:0] in_a, in_b;
    wire [7:0] a_hi = {4'b0000, in_a[7:4]};
    wire [7:0] a_lo = {4'b0000, in_a[3:0]};
    wire [7:0] b_hi = {4'b0000, in_b[7:4]};
    wire [7:0] b_lo = {4'b0000, in_b[3:0]}; // ← 修正

    // L1
    reg [7:0] l1_sum1, l1_sum2;
    reg       stateA, stateB;

    // L2
    reg [7:0] next1, next2, next3, next4;
    reg [7:0] l2_sum1, l2_sum2;

    // 重み
    reg signed [3:0] w1, w2, w3, w4;
    reg        [3:0] w5, w6; // 使うなら別途読んでください

    // ---- 関数（Verilog形式で記述）----
    function [7:0] shift_by_signed;
        input [7:0] x;
        input signed [3:0] s;
        reg [3:0] mag;
    begin
        if (!s[3]) begin
            shift_by_signed = x << s;      // s >= 0
        end else begin
            mag = (~s) + 4'd1;             // abs(-s)
            shift_by_signed = x >> mag;    // 右シフト
        end
    end
    endfunction

    // ---- 状態（localparamで安定）----
    localparam S_IDLE       = 4'd0;
    localparam S_L1_ACCUM   = 4'd1;
    localparam S_RD_W12_REQ = 4'd2;
    localparam S_RD_W12_GET = 4'd3;
    localparam S_RD_W34_REQ = 4'd4;
    localparam S_RD_W34_GET = 4'd5;
    localparam S_L2_COMPUTE = 4'd6;
    localparam S_DONE       = 4'd7;

    reg [3:0] st, st_n;

    // 次状態（組合せ）
    always @* begin
        st_n  = st;
        w_req = 1'b0;
        w_addr = {ADDR_W{1'b0}};

        case (st)
            S_IDLE:       if (start) st_n = S_L1_ACCUM;
            S_L1_ACCUM:   st_n = S_RD_W12_REQ;

            S_RD_W12_REQ: begin w_req=1'b1; w_addr=W12_ADDR; st_n=S_RD_W12_GET; end
            S_RD_W12_GET: if (w_valid) st_n = S_RD_W34_REQ;

            S_RD_W34_REQ: begin w_req=1'b1; w_addr=W34_ADDR; st_n=S_RD_W34_GET; end
            S_RD_W34_GET: if (w_valid) st_n = S_L2_COMPUTE;

            S_L2_COMPUTE: st_n = S_DONE;
            S_DONE:       st_n = S_IDLE;
            default:      st_n = S_IDLE;
        endcase
    end

    // レジスタ更新
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            st <= S_IDLE;
            in_a<=0; in_b<=0;
            l1_sum1<=0; l1_sum2<=0;
            stateA<=0; stateB<=0;
            next1<=0; next2<=0; next3<=0; next4<=0;
            l2_sum1<=0; l2_sum2<=0;
            w1<=0; w2<=0; w3<=0; w4<=0; w5<=0; w6<=0;
            prediction<=0; done<=0;
        end else begin
            st   <= st_n;
            done <= 1'b0;

            case (st)
                S_IDLE: if (start) begin
                    in_a <= ui_in;
                    in_b <= uio_in;
                end

                S_L1_ACCUM: begin
                    l1_sum1 <= a_hi + a_lo;
                    l1_sum2 <= b_hi + b_lo;
                    stateA  <= (a_hi + a_lo) > TH1;
                    stateB  <= (b_hi + b_lo) > TH2;
                end

                S_RD_W12_GET: if (w_valid) begin
                    w1 <= w_data[7:4];
                    w2 <= w_data[3:0];
                end
                S_RD_W34_GET: if (w_valid) begin
                    w3 <= w_data[7:4];
                    w4 <= w_data[3:0];
                end

                S_L2_COMPUTE: begin
                    next1 <= stateA ? shift_by_signed(l1_sum1, w1) : 8'h00;
                    next3<= stateA ? shift_by_signed(l1_sum1, w2) : 8'h00;
                    next2 <= stateB ? shift_by_signed(l1_sum2, w3) : 8'h00;
                    next4 <= stateB ? shift_by_signed(l1_sum2, w4) : 8'h00;

                    l2_sum1 <= (stateA ? shift_by_signed(l1_sum1, w1) : 8'h00)
                             + (stateB ? shift_by_signed(l1_sum2, w3) : 8'h00);
                    l2_sum2 <= (stateA ? shift_by_signed(l1_sum1, w2) : 8'h00)
                             + (stateB ? shift_by_signed(l1_sum2, w4) : 8'h00);

                    prediction <= l2_sum1 + l2_sum2; // 必要なら <<w5/<<w6 を追加
                end

                S_DONE: begin
                    done <= 1'b1;
                end
            endcase
        end
    end
endmodule
 
