`default_nettype none

module Multilayer #(
	parameter ADDR_W = 4,
	parameter DW = 8
)(
	input   wire  [7:0]         ui_in,
	input   wire  [7:0]         uio_in,
	input   wire  start,        
	input   wire  clk,          
	input   wire  rst_n,        
	output  reg   w_req,        
	output  reg   [ADDR_W-1:0]  w_addr,
	input   wire  w_valid,      
	input   wire  [DW-1:0]      w_data,
	output  reg   [7:0]         prediction,
	output  reg   done          
);
	wire [7:0] ui_in1 = {4'b0000, ui_in[7:4]};
	wire [7:0] ui_in2 = {4'b0000, ui_in[3:0]};
	wire [7:0] uio_in3 = {4'b0000, uio_in[7:4]};
	wire [7:0] uio_in4 = {4'b0000, uio_in[3:1]};

	reg [7:0] sum1;
	reg [7:0] threshold1 = 8'h01;
	reg [7:0] sum2;
	reg [7:0] threshold2 = 8'h01;
	reg stateA = 1'b0;
	reg stateB = 1'b0;
	reg signed [3:0] weight1 = 4'b0000;
	reg signed [3:0] weight2 = 4'b0000;
	reg signed [3:0] weight3 = 4'b0000;
	reg signed [3:0] weight4 = 4'b0000;
	reg [3:0] weight5 = 4'b0000;
	reg [3:0] weight6 = 4'b0000;

	// currently input is closed, not connected to next wire
	// put input to registor while learning is ongoing
	// why it can't be wire?
	reg [7:0] next_input1 = 8'h00;
	reg [7:0] next_input2 = 8'h00;
	reg [7:0] next_input3 = 8'h00;
	reg [7:0] next_input4 = 8'h00;
	reg [7:0] ui_in_tmp;
	reg [7:0] uio_in_tmp;

	function automatic [7:0] shift_by_signed(
	    input [7:0] x,
	    input signed [3:0] s
	);
	    begin
		shift_by_signed = (s >= 0) ? (x << s) : (x >> -s);
	    end
	endfunction

	typedef enum logic [3:0] {
	    S_IDLE       = 4'd0,
	    S_L1_ACCUM   = 4'd1,
	    S_L2_REQ_W1  = 4'd2,
	    S_L2_GET_W1  = 4'd3,
	    S_L2_REQ_W2  = 4'd4,
	    S_L2_GET_W2  = 4'd5,
	    S_L2_REQ_W3  = 4'd6,
	    S_L2_GET_W3  = 4'd7,
	    S_L2_REQ_W4  = 4'd8,
	    S_L2_GET_W4  = 4'd9,
	    S_L2_REQ_W5  = 4'd10,
	    S_L2_GET_W5  = 4'd11,
	    S_L2_REQ_W6  = 4'd12,
	    S_L2_GET_W6  = 4'd13,
	    S_L2_COMPUTE = 4'd14,    // L2の加算(sum1/2)を作る
	    S_DONE       = 4'd15
	} state_t;

	state_t st, st_n;



	// weight update should be clock
	always @* begin
		// initialize
		next_input1 = 8'h00;
		next_input2 = 8'h00;
		next_input3 = 8'h00;
		next_input4 = 8'h00;
		stateA = 1'b0;
		stateB = 1'b0;
		ui_in_tmp = 8'h00;
		uio_in_tmp = 8'h00;
		weight1 = 4'b0000;
		weight2 = 4'b0000;
		weight3 = 4'b0000;
		weight4 = 4'b0000;



		// 1------------------------------------------------------------
		// sum up initial

		sum1 = ui_in1 + ui_in2;
		sum2 = uio_in3 + uio_in4;
/*
		sum1 = ui_in[7:4] + ui_in[3:0];
		sum2 = uio_in[7:4] + uio_in[3:0];
*/
		// state

		// shift
		if (sum1 > threshold1) begin
			stateA = 1'b1;
			if (weight1 >= 0) begin
				next_input1 = sum1 << weight1;
			end
			if (weight1 < 0) begin
				next_input1 = sum1 >> -weight1;
			end
			if (weight2 >= 0) begin
				next_input3 = sum1 << weight2;
			end
			if (weight2 < 0) begin
				next_input3 = sum1 >> -weight2;
			end
		end

		if (sum2 > threshold2) begin
			stateB = 1'b1;
			if (weight3 >= 0) begin
				next_input2 = sum2 << weight3;
			end
			if (weight3 < 0) begin
				next_input2 = sum2 >> -weight3;
			end
			if (weight4 >= 0) begin
				next_input4 = sum2 << weight4;
			end
			if (weight4 < 0) begin
				next_input4 = sum2 >> -weight4;
			end
		end

		// 2------------------------------------------------------------
		// sum up
		if (ui_in != 8'b0) begin
			ui_in_tmp = ui_in[7:0];
		end
		if (uio_in != 8'b0) begin
			uio_in_tmp = uio_in[7:0];
		end	
		sum1 = next_input1 + next_input2;
		sum2 = next_input3 + next_input4;

		// weight update
		if (sum1 > threshold1) begin
			if (stateA == 1'b1) begin
				if (weight1 != 4'b0111) begin
					weight1 = weight1 + 5'b00001;
				end
			end
			else if (weight1 != 4'b1000) begin
				weight1 = weight1 - 5'b00001;
			end

			if (stateB == 1'b1) begin
				if (weight3 != 4'b0111) begin
					weight3 = weight3 + 5'b00001;
				end
			end
			else if (weight3 != 4'b1000) begin
				weight3 = weight3 - 5'b00001;
			end
		end
		else begin
			if (stateA == 1'b1 && weight1 != 4'b1000) begin
				weight1 = weight1 - 4'b0001;
			end
			if (stateB == 1'b1 && weight3 != 4'b1000) begin
				weight3 = weight3 - 4'b0001;
			end
			sum1 = 8'h00;
		end

		if (sum2 > threshold2) begin
			if (stateA == 1'b1) begin
				if  (weight2 != 4'b0111) begin
					weight2 = weight2 + 4'b0001;
				end
			end
			else if (weight2 != 4'b1000) begin
				weight2 = weight2 - 4'b0001;
			end
			if (stateB == 1'b1) begin
				if (weight4 != 4'b0111) begin
					weight4 = weight4 + 4'b0001;
				end
			end
			else if (weight4 != 4'b1000) begin
				weight4 = weight4 - 4'b0001;
			end
		end
		else begin
			if (stateA == 1'b1 && weight2 != 4'b0111) begin
				weight2 = weight2 - 4'b0001;
			end
			if (stateB == 1'b1 && weight4 != 4'b0111) begin
				weight4 = weight4 - 4'b0001;
			end
			sum2 = 8'h00;
		end

		// state
		if (sum1 > threshold1) begin
			stateA = 1'b1;
		end
		else begin
			stateA = 1'b0;
		end
		if (sum2 > threshold2) begin
			stateB = 1'b1;
		end
		else begin
			stateB = 1'b0;
		end


		// shift
		if (sum1 > threshold1) begin
			stateA = 1'b1;
			if (weight1 >= 0) begin
				next_input1 = sum1 << weight1;
			end
			if (weight1 < 0) begin
				next_input1 = sum1 >> -weight1;
			end
			if (weight2 >= 0) begin
				next_input3 = sum1 << weight2;
			end
			if (weight2 < 0) begin
				next_input3 = sum1 >> -weight2;
			end
		end

		if (sum2 > threshold2) begin
			stateB = 1'b1;
			if (weight3 >= 0) begin
				next_input2 = sum2 << weight3;
			end
			if (weight3 < 0) begin
				next_input2 = sum2 >> -weight3;
			end
			if (weight4 >= 0) begin
				next_input4 = sum2 << weight4;
			end
			if (weight4 < 0) begin
				next_input4 = sum2 >> -weight4;
			end
		end


	end

	assign prediction = (sum1 << weight5) + (sum2 << weight6);

endmodule
