`default_nettype none

module tt_um_snn #(parameter WIDTH = 4) ( // use localparam
	input wire [7:0] ui_in,
	output wire [7:0] uo_out,
	input wire [7:0] uio_in,// this is not used currently, can be error
	output wire [7:0] uio_out,
	output wire [7:0] uio_oe,
	input wire ena,
	input wire clk,
	input wire rst_n
);

	reg [7:0] sum1;
	reg [7:0] threshold1 = 8'h01;
	reg [7:0] sum2;
	reg [7:0] threshold2 = 8'h01;

	integer i;

	always @* begin
		// sum 2 inputs
		sum1 = ui_in[3:0] + ui_in[7:4];
		sum2 = uio_in[3:0] + uio_in[7:4];
		// check if outcome exceeds threshold
		if (sum1 > threshold1) begin
			// sum up neurons
			sum1 = sum1 << 1;
		end
		else begin
			sum1 = 8'h00;
		end

		if (sum2 > threshold2) begin
			// sum up neurons
			sum2 = sum2 << 1;
		end
		else begin
			sum2 = 8'h00;
		end
	end

	assign uo_out = sum1 + sum2;
	//assign uo_out = 8'b10110;
	assign uio_out = 8'h00;
	assign uio_oe = 8'h00;

	wire _unused = ena;


endmodule
