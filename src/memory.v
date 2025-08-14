`default_nettype none

module Memory (
	input wire [7:0] ui_in,
	input wire [3:0] addr,
	input wire write_mode,
	output wire [7:0] packet,
	input wire clk,
	input wire rst_n
);
  // memory array allocation
  reg [7:0] mem [0:15];
  //reg [7:0] read_data;

  integer i;
  always @(posedge clk or negedge rst_n) begin
	// reset at the end
	if (!rst_n) begin
		for (i = 0; i < 16; i = i + 1)
			mem[i] <= 8'h00;
		//read_data <= 8'h00;
	// write and read
	end else begin
		if (write_mode) begin
			mem[addr] <= ui_in;
		/*
		end else begin
			packet <= mem[addr];*/
		end
	end
  end

  assign packet = mem[addr];

endmodule
