/*
 * Copyright (c) 2025 Amon Suzuki
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_snn (
	input   wire  [7:0]  ui_in,                                      
	output  wire  [7:0]  uo_out,                                     
	input   wire  [7:0]  uio_in,                                     
	output  wire  [7:0]  uio_out,                                    
	output  wire  [7:0]  uio_oe,                                     
	input   wire  ena,   //        always  1  when  the  design  is  powered
	input   wire  clk,                                               
	input   wire  rst_n                                              
	);

	localparam  ADDR_W  =  4;
	localparam  DW      =  8;

	// -----------------------
	// Phase select
	//  0 = write weights
	//  1 = inference     
	// -----------------------
	wire phase_infer = uio_in[0];

	// -----------------------
	// Memory wires
	// -----------------------
	reg   mem_we; 
	reg   [ADDR_W-1:0]  mem_addr;
	reg   [DW-1:0]      mem_wdata;
	wire  [DW-1:0]      mem_rdata;// = ui_in, phase0

	Memory #(
		.ADDR_W(ADDR_W),
		.DW(DW)
	) memory_i(
		.clk(clk),
		.rst_n(rst_n),
		.we (mem_we),
		.addr(mem_addr),
		.wdata(mem_wdata),
		.rdata(mem_rdata)
	);

	// -----------------------
	// Multilayer wires
	// -----------------------
	wire  ml_w_req;     
	wire  [ADDR_W-1:0]  ml_w_addr;
	reg   ml_w_valid;   
	reg   [DW-1:0]      ml_w_data;

	wire                  ml_wb_req;
	wire [ADDR_W-1:0]     ml_wb_addr;
	wire [DW-1:0]         ml_wb_data;
	reg                   ml_wb_ack;

	wire  [7:0]      ml_prediction;
	wire  ml_done;   
	reg   ml_start;

	Multilayer #(
		.ADDR_W(ADDR_W),
		.DW(DW)
	) multilayer_i(
		.ui_in(ui_in),
		.uio_in(uio_in),
		.start(ml_start),
		.clk(clk),
		.rst_n(rst_n),
		.w_req(ml_w_req),
		.w_addr(ml_w_addr),
		.w_valid(ml_w_valid),
		.w_data(ml_w_data),
		.wb_req(ml_wb_req),
		.wb_addr(ml_wb_addr),
		.wb_wdata(ml_wb_data),
		.wb_ack(ml_wb_ack),
		.prediction(ml_prediction),
		.done(ml_done)
	);


	// -----------------------
	// Simple read pipeline:
	//  - When ML raises ml_w_req, latch addr
	//  - Next cycle, mem_rdata is valid -> drive ml_w_valid/ml_w_data for 1 cycle
	// -----------------------
	reg  op_pending, op_is_read;
	/*
	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			mem_we      <=  1'b0;
			mem_addr    <=  '0;
			mem_wdata   <=  '0;
			ml_start    <=  1'b0;
			rd_pending  <=  1'b0;
			rd_addr_q   <=  '0;
			ml_w_valid  <=  1'b0;
			ml_w_data   <=  '0;
		end else begin
			ml_w_valid <= 1'b0; // default

			if (!phase_infer) begin
				// Phase 0: write weights
				mem_we <= 1'b1;
				mem_addr <= uio_in[7:4];
				mem_wdata <= ui_in;
				rd_pending <= 1'b0;
				ml_start <= 1'b0;
			end else begin
				// Phase 1: inference
				mem_we <= 1'b0;
				
				if (ml_done) begin
					ml <= 1'b1;
				end else begin
					ml_start <= 1'b0;
				end

				if (ml_w_req && !rd_pending) begin
					mem_addr <= ml_w_addr;
					rd_addr <= ml_w_addr
					rd_pending <= 1'b1;
				end else if (rd_pending) begin
					ml_w_data <= mem_rdata;
					ml_w_valid <= 1'b1;
					rd_pending <= 1'b0;
				end
			end
		end
	end*/

	always @(posedge clk or negedge rst_n) begin
 	 if (!rst_n) begin
	    mem_we <= 1'b0; mem_addr <= '0; mem_wdata <= '0;
	    ml_w_valid <= 1'b0; ml_w_data <= '0;
	    ml_wb_ack  <= 1'b0;
	    op_pending <= 1'b0; op_is_read <= 1'b0;
	    ml_start   <= 1'b0;
	  end else begin
	    ml_w_valid <= 1'b0;
	    ml_wb_ack  <= 1'b0;
	    mem_we     <= 1'b0;

	    if (!phase_infer) begin
	      // Phase0: ホスト書込
	      mem_we    <= 1'b1;
	      mem_addr  <= uio_in[7:4];
	      mem_wdata <= ui_in;
	      op_pending<= 1'b0;
	      ml_start  <= 1'b0;

	    end else begin
	      // Phase1: 推論/学習
	      // ml_doneに応じて開始パルス（必要なら）
	      if (ml_done) ml_start <= 1'b1; else ml_start <= 1'b0;

	      if (!op_pending) begin
		// ① 書戻しを優先
		if (ml_wb_req) begin
		  mem_we    <= 1'b1;
		  mem_addr  <= ml_wb_addr;
		  mem_wdata <= ml_wb_data;
		  op_pending<= 1'b1;
		  op_is_read<= 1'b0;

		// ② 読取り
		end else if (ml_w_req) begin
		  mem_addr  <= ml_w_addr;   // 同期読み出し：次サイクルにrdata有効
		  op_pending<= 1'b1;
		  op_is_read<= 1'b1;
		end

	      end else begin
		// 前サイクルに発行した操作の返却
		if (op_is_read) begin
		  ml_w_data  <= mem_rdata;  // read data返却
		  ml_w_valid <= 1'b1;       // 1サイクルだけ
		end else begin
		  ml_wb_ack  <= 1'b1;       // write完了通知を1サイクル
		end
		op_pending <= 1'b0;
	      end
	    end
	  end
	end




	// -----------------------
	// Output
	// -----------------------
	assign uo_out = phase_infer ? ml_prediction : 8'h00;

	assign uio_out = 8'h00;
	assign uio_oe = 8'h00;


	wire _unused = ena;


endmodule
