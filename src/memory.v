`default_nettype none

module Memory #(
	parameter ADDR_W = 4,
	parameter DW = 8
)(
	input wire clk,
	input wire rst_n,
	input wire we,
	input wire [ADDR_W-1:0] addr,
	input wire [DW-1:0] wdata,
	output reg [DW-1:0] rdata
);
  // memory array allocation
  reg [DW-1:0] mem [0:(1<<ADDR_W)-1];

  always @(posedge clk or negedge rst_n) begin
	// reset at the end
	if (!rst_n) begin
		rdata <= '0;
	// write and read
	end else begin
		if (we) begin
			mem[addr] <= wdata;
		end
		rdata <= mem[addr];
	end
  end

endmodule
