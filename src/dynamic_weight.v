`default_nettype none

module Multilayer ( // use localparam
	input wire [7:0] ui_in,
	input wire [7:0] uio_in,
	input wire write_mode,
	output wire [7:0] prediction,
	output wire [3:0] addr_int,
	input wire [7:0] packet,
	input wire clk,
	input wire rst_n
);

	wire [7:0] ui_in1 = {4'h0, ui_in[7:4]};
	wire [7:0] ui_in2 = {4'h0, ui_in[3:0]};
	wire [7:0] uio_in3 = {4'h0, uio_in[7:4]};
	wire [7:0] uio_in4 = {4'h0, uio_in[3:1]};


	reg [7:0] sum1;
	reg [7:0] threshold1 = 8'h01;
	reg [7:0] sum2;
	reg [7:0] threshold2 = 8'h01;
	reg stateA = 1'b0;
	reg stateB = 1'b0;

	reg signed [3:0] weight1 = 4'h0;
	reg signed [3:0] weight2 = 4'h0;
	reg signed [3:0] weight3 = 4'h0;
	reg signed [3:0] weight4 = 4'h0;
	reg [3:0] weight5 = 4'h0;
	reg [3:0] weight6 = 4'h0;

	reg [7:0] next_input1 = 8'h00;
	reg [7:0] next_input2 = 8'h00;
	reg [7:0] next_input3 = 8'h00;
	reg [7:0] next_input4 = 8'h00;
	reg [7:0] ui_in_tmp;
	reg [7:0] uio_in_tmp;


	// initialize
	// sum up
	sum1 <= ui_in1 + ui_in2;
	sum2 <= uio_in3 + uio_in4;
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



	typedef enum logic [2:0] {
		IDLE, SET0, GET0, SET1, GET1, SET2, GET2, SET3, GET3, SET4, GET4, SET5, GET5, SET6, GET6, SET7, GET7, READY
	} state;

	state st;

	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			st <= IDLE;
			addr_int <= 4'h0;
			weight1 = 4'h0;
			weight2 = 4'h0;
			weight3 = 4'h0;
			weight4 = 4'h0;
		end else begin
			if (write_mode) begin
				st <= IDLE;
			end else begin
				case (st)
					IDLE: begin addr_int <= 4'h0; st <= SET0; end
					SET1: st <= GET1;
					GET1: begin weight1 <= packet[7:4]; weight2 <= packet[3:0] addr_int <= 4'h7; st <= SET2; end
					SET2: st <= GET2;
					GET2: begin weight3 <= packet[7:4]; weight4 <= packet[3:0] addr_int <= 4'h7; st <= SET3; end
					READY: begin
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
									weight1 = weight1 + 4'h01;
								end
							end
							else if (weight1 != 4'b1000) begin
								weight1 = weight1 - 4'h01;
							end
                
							if (stateB == 1'b1) begin
								if (weight3 != 4'b0111) begin
									weight3 = weight3 + 4'h01;
								end
							end
							else if (weight3 != 4'b1000) begin
								weight3 = weight3 - 4'h01;
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
				endcase
			end
		end
	end

	assign prediction = (sum1 << weight5) + (sum2 << weight6);

endmodule
