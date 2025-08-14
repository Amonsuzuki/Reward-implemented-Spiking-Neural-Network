/*
 * Copyright (c) 2024 Your Name
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_memory (
    input  wire [7:0] ui_in,    // Dedicated inputs
    output wire [7:0] uo_out,   // Dedicated outputs
    input  wire [7:0] uio_in,   // IOs: Input path
    output wire [7:0] uio_out,  // IOs: Output path
    output wire [7:0] uio_oe,   // IOs: Enable path (active high: 0=input, 1=output)
    input  wire       ena,      // always 1 when the design is powered, so you can ignore it
    input  wire       clk,      // clock
    input  wire       rst_n     // reset_n - low to reset
);


  //address control
  wire [3:0] addr = {uio_in[3], uio_in[2:0]}; //MSB == node, layer
  wire we = uio_in[4]; //write enable (active high)
	
  //memory array
  reg [7:0] mem [0:15];
  reg [7:0] rdata;

  integer i;
  always @(posedge clk or negedge rst_n) begin
	if (!rst_n) begin
		for (i = 0; i < 16; i = i + 1)
			mem[i] <= 8'h00;
		rdata <= 8'h00;
	end else begin
		if (we) begin
			mem[addr] <= ui_in;
			rdata <= ui_in;
		end else begin
			rdata <= mem[addr];
		end
	end
  end

  // All output pins must be assigned. If not used, assign to 0.
  assign uo_out  = rdata;  // Example: ou_out is the sum of ui_in and uio_in
  assign uio_out = 8'h00;
  assign uio_oe  = 8'h00;

  // List all unused inputs to prevent warnings
  wire _unused = ena;

endmodule
