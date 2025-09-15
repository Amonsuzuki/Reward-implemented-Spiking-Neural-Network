module tt_um_snn (
    input  wire [7:0] ui_in,
    output wire [7:0] uo_out,
    input  wire [7:0] uio_in,
    output wire [7:0] uio_out,
    output wire [7:0] uio_oe,
    input  wire       ena,   // always 1 when design powered
    input  wire       clk,
    input  wire       rst_n
);
    localparam ADDR_W = 4;
    localparam DW     = 8;

    // -----------------------
    // Phase select:
    //  0 = write weights
    //  1 = inference
    // -----------------------
    wire phase_infer = uio_in[0];

    // -----------------------
    // Memory wires
    // -----------------------
    reg                  mem_we;
    reg  [ADDR_W-1:0]    mem_addr;
    reg  [DW-1:0]        mem_wdata;
    wire [DW-1:0]        mem_rdata;

    Memory #(
        .ADDR_W(ADDR_W),
        .DW(DW)
    ) memory_i (
        .clk   (clk),
        .rst_n (rst_n),
        .we    (mem_we),
        .addr  (mem_addr),
        .wdata (mem_wdata),
        .rdata (mem_rdata)
    );

    // -----------------------
    // Multilayer wires
    // -----------------------
    wire                  ml_w_req;
    wire [ADDR_W-1:0]     ml_w_addr;
    reg                   ml_w_valid;
    reg  [DW-1:0]         ml_w_data;

    wire [7:0]            ml_prediction;
    wire                  ml_done;
    reg                   ml_start;   // 1-cycle start pulse in Phase 1

    Multilayer #(
        .ADDR_W(ADDR_W),
        .DW(DW)
    ) multilayer_i (
        .ui_in     (ui_in),
        .uio_in    (uio_in),
        .start     (ml_start),
        .clk       (clk),
        .rst_n     (rst_n),
        .w_req     (ml_w_req),
        .w_addr    (ml_w_addr),
        .w_valid   (ml_w_valid),
        .w_data    (ml_w_data),
        .prediction(ml_prediction),
        .done      (ml_done)
    );

    // -----------------------
    // Simple read pipeline:
    //  - When ML raises ml_w_req, latch addr
    //  - Next cycle, mem_rdata is valid -> drive ml_w_valid/ml_w_data for 1 cycle
    // -----------------------
    reg                   rd_pending;
    reg [ADDR_W-1:0]      rd_addr_q;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_we      <= 1'b0;
            mem_addr    <= '0;
            mem_wdata   <= '0;
            ml_start    <= 1'b0;
            rd_pending  <= 1'b0;
            rd_addr_q   <= '0;
            ml_w_valid  <= 1'b0;
            ml_w_data   <= '0;
        end else begin
            ml_w_valid <= 1'b0; // default

            if (!phase_infer) begin
                // -------------------
                // Phase 0: host writes
                // -------------------
                // Example address mapping: use uio_in[7:4] as addr
                mem_we    <= 1'b1;
                mem_addr  <= uio_in[7:4];   // host supplies address in upper nibble
                mem_wdata <= ui_in;         // host supplies data on ui_in
                rd_pending<= 1'b0;
                ml_start  <= 1'b0;
            end else begin
                // -------------------
                // Phase 1: inference
                // -------------------
                mem_we <= 1'b0;

                // Fire a start pulse whenever ML is idle/done and inputs are "ready".
                // You can refine this condition to your exact protocol.
                if (ml_done) begin
                    ml_start <= 1'b1;  // start next pass after done
                end else begin
                    ml_start <= 1'b0;
                end

                // Issue read on request (one at a time)
                if (ml_w_req && !rd_pending) begin
                    mem_addr   <= ml_w_addr;
                    rd_addr_q  <= ml_w_addr;
                    rd_pending <= 1'b1;
                end else if (rd_pending) begin
                    // one cycle after addr set, rdata is ready
                    ml_w_data  <= mem_rdata;
                    ml_w_valid <= 1'b1;     // 1-cycle valid strobe
                    rd_pending <= 1'b0;
                end
            end
        end
    end

    // -----------------------
    // Outputs
   // -----------------------
    assign uo_out  = phase_infer ? ml_prediction : 8'h00; // show prediction in Phase 1
    assign uio_out = 8'h00;
    assign uio_oe  = 8'h00;

    // keep 'ena' used
    wire _unused = ena;

endmodule 
