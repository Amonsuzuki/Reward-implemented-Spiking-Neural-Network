`default_nettype none

module Multilayer (
	input wire [7:0] ui_in,
	input wire [7:0] uio_in,
	output reg write_mode,
	output wire [7:0] prediction,
	output reg [3:0] addr_int,
	input wire [7:0] packet_from,
	output reg [7:0] packet_to,
	output wire update,
	input wire clk,
	input wire rst_n
);
	localparam LAYERS = 8;

	wire [7:0] ui_in1 = {4'h0, ui_in[7:4]};
	wire [7:0] ui_in2 = {4'h0, ui_in[3:0]};
	wire [7:0] uio_in3 = {4'h0, uio_in[7:4]};
	wire [7:0] uio_in4 = {4'h0, uio_in[3:1]};// exception for write_mode bit


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

	reg [2:0] state;
	reg [$clog2(LAYERS)-1:0] layer_idx;

	localparam S_IDLE=0, S_LOAD0=0, S_LOAD1=2, S_COMPUTE=3, S_UPDATE0=4, S_UPDATE1=5, S_NEXT=6, S_FIN=7;

	assign update = 1'b1;

	// initialize
	always @* begin
		// sum up
		sum1 = ui_in1 + ui_in2;
		sum2 = uio_in3 + uio_in4;
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
	end
        



	always @(posedge clk or negedge rst_n) begin
		if (!rst_n) begin
			state <= S_IDLE;
			layer_idx <= '0;
			addr_int <= 4'h0;
			weight1 = 4'h0;
			weight2 = 4'h0;
			weight3 = 4'h0;
			weight4 = 4'h0;
		end else begin
			if (write_mode) begin
				state <= S_IDLE;
			end else begin
				case (state)
					S_IDLE: begin addr_int <= 4'h0 + layer_idx; state <= S_LOAD0; end
					S_LOAD0: begin weight1 <= packet_from[7:4]; weight2 <= packet_from[3:0]; addr_int <= 4'h7 + layer_idx; state <= S_LOAD1; end
					S_LOAD1: begin weight3 <= packet_from[7:4]; weight4 <= packet_from[3:0]; state <= S_COMPUTE; end
					S_COMPUTE: begin
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
									weight1 = weight1 + 4'h1;
								end
							end
							else if (weight1 != 4'b1000) begin
								weight1 = weight1 - 4'h1;
							end
                
							if (stateB == 1'b1) begin
								if (weight3 != 4'b0111) begin
									weight3 = weight3 + 4'h1;
								end
							end
							else if (weight3 != 4'b1000) begin
								weight3 = weight3 - 4'h1;
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
					S_UPDATE0: begin
						write_mode <= 1'b1;
						packet_to[7:4] <= weight3;
						packet_to[3:0] <= weight4;
						addr_int <= 4'h0 + layer_idx;
						state <= S_UPDATE1;
					end
					S_UPDATE1: begin
						packet_to[7:4] <= weight1;
						packet_to[3:0] <= weight2;
						write_mode <= '0;
						state <= S_NEXT;
					end
					S_NEXT: begin
						if (layer_idx == LAYERS-1) begin
							layer_idx <= '0;
							state <= S_FIN;
						end else begin
							layer_idx <= layer_idx + 1'b1;
							state <= S_IDLE;
						end
					end
				endcase
			end
		end
	end

	assign update = 1'b1;
	assign prediction = (sum1 << weight5) + (sum2 << weight6);

endmodule
