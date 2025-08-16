/*
 * Copyright (c) 2025 Amon Suzuki
 * SPDX-License-Identifier: Apache-2.0
 */

`default_nettype none

module tt_um_snn (
	input wire [7:0] ui_in,
	output wire [7:0] uo_out,
	input wire [7:0] uio_in,
	output wire [7:0] uio_out,
	output wire [7:0] uio_oe,
	input wire ena, // always 1 when the design is powered
	input wire clk,
	input wire rst_n
	);

	// common
	wire write_mode = uio_in[0];

	// memory
	wire [3:0] addr_ext = {uio_in[7], uio_in[6:4]};
	wire [3:0] addr_int;
	wire [3:0] addr = write_mode ? addr_ext : addr_int;
	wire [7:0] packet;


	Memory memory(
		.ui_in(ui_in),
		.addr(addr),
		.write_mode(write_mode),
		.packet(packet),
		.clk(clk),
		.rst_n(rst_n)
	);


	// multilayer
	wire [7:0] prediction;

	Multilayer multilayer(
		.ui_in(ui_in),
		.uio_in(uio_in),
		.write_mode(write_mode),
		.prediction(prediction),
		.addr_int(addr_int),
		.packet(packet),
		.clk(clk),
		.rst_n(rst_n)
	);

	assign uo_out = (write_mode) ? packet : prediction;


	assign uio_out = 8'h00;
	assign uio_oe = 8'h00;


	wire _unused = ena;


endmodule
