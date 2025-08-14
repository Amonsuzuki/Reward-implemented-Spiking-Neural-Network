'default_nettype none
modeule tt_um_snn #(parameter WIDTH = 4) (
	input wire [7:0] ui_in,
	output wire [7:0] uo_out,
	input wire [7:0] uio_in,
	output wire [7:0] uio_out,
	output wire [7:0] uio_oe,
	input wire ena,
	input wire clk,
	input wire rst_n
);

	localparam [7:0] TH1 = 8'h01;
	localparam [7:0] TH2 = 8'h01;

	reg sigend [4:0] weight1, weight2, weight3, weight4;
	reg [3:0] weight5, weight6;
	reg stateA, stateB;

	reg [7:0] next_input1, next_input2, next_input3, next_input4;

	wire [7:0] sum1_0 = ui_in[7:4] + ui_in[3:0];
	wire [7:0] sum2_0 = uio_in[7:4] + uio_in[3:0];

	function automatic [7:0] var_shift_left(input [7:0] x, input signed [4:0] k);
		var_shift_left = (k > 0) ? (x << k[3:0]) : (k < 0) ? (x >> (-k[3:0])) : x;
	endfunction

	wire [7:0] n1_prop = (sum1_0 > TH1) ? var_shift_left(s1_0, weight1) : 8'h00;
	wire [7:0] n3_prop = (sum1_0 > TH1) ? var_shift_left(s1_0, weight2) : 8'h00;
	wire [7:0] n2_prop = (sum2_0 > TH2) ? var_shift_left(s2_0, weight3) : 8'h00;
	wire [7:0] n4_prop = (sum2_0 > TH2) ? var_shift_left(s2_0, weight4) : 8'h00;

	wire [7:0] s1_1 = next_input1 + next_input2;
	wire [7:0] s1_1 = next_input1 + next_input2;

	assign uo_out = (s1_1 << weight5) + (s2_1 << weight6);
	assign uio_out = 8'h00;
	assign uio_oe = 8'h00;
	wire _unused = ena;


	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			weight1 <=  5'sd0; weight2 <= 5'sd0; weight3 <= 5'sd0; weight4 <= 5'sd0;
			weight5 <= 4'd0; weight6 <= 4'd0;
			stateA <= 1'b0; stateB <= 1'b0;
			next_input1 <= 8'h00; next_input2 <= 8'h00;
			next_input3 <= 8'h00; next_input4 <= 8'h00;
		end else begin
			next_input1 <= n1_prop;
			next_input2 <= n2_prop;
			next_input3 <= n3_prop;
			next_input4 <= n4_prop;
			if (s1_0 > TH1) begin
				stateA <= 1'b1;
				if (stateA
			


endmodule
