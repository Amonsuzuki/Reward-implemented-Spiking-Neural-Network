`default_nettype none

module tt_um_snn ( // use localparam
	input wire [7:0] ui_in,
	output wire [7:0] uo_out,
	input wire [7:0] uio_in,// this is not used currently, can be error
	output wire [7:0] uio_out,
	output wire [7:0] uio_oe,
	input wire ena,
	input wire clk,
	input wire rst_n
);

	wire [7:0] ui_hi = {4'b0000, ui_in[7:4]};
	wire [7:0] ui_lo = {4'b0000, ui_in[3:0]};
	wire [7:0] uio_hi = {4'b0000, uio_in[7:4]};
	wire [7:0] uio_lo = {4'b0000, uio_in[3:0]};


	reg [7:0] sum1;
	reg [7:0] threshold1 = 8'h01;
	reg [7:0] sum2;
	reg [7:0] threshold2 = 8'h01;
	reg stateA = 1'b0;
	reg stateB = 1'b0;
	reg signed [4:0] weight1 = 5'b00000;
	reg signed [4:0] weight2 = 5'b00000;
	reg signed [4:0] weight3 = 5'b00000;
	reg signed [4:0] weight4 = 5'b00000;
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

	integer i;

	always @* begin
		// 1------------------------------------------------------------
		// sum 2 inputs

		sum1 = ui_hi + ui_lo;
		sum2 = uio_hi + uio_lo;
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
				if (weight1 != 5'b01111) begin
					weight1 = weight1 + 5'b00001;
				end
			end
			else if (weight1 != 5'b10000) begin
				weight1 = weight1 - 5'b00001;
			end

			if (stateB == 1'b1) begin
				if (weight3 != 5'b01111) begin
					weight3 = weight3 + 5'b00001;
				end
			end
			else if (weight3 != 5'b10000) begin
				weight3 = weight3 - 5'b00001;
			end
		end
		else begin
			if (stateA == 1'b1 && weight1 != 5'b10000) begin
				weight1 = weight1 - 5'b00001;
			end
			if (stateB == 1'b1 && weight3 != 5'b10000) begin
				weight3 = weight3 - 5'b00001;
			end
			sum1 = 8'h00;
		end

		if (sum2 > threshold2) begin
			if (stateA == 1'b1) begin
				if  (weight2 != 5'b01111) begin
					weight2 = weight2 + 5'b00001;
				end
			end
			else if (weight2 != 5'b10000) begin
				weight2 = weight2 - 5'b00001;
			end
			if (stateB == 1'b1) begin
				if (weight4 != 5'b01111) begin
					weight4 = weight4 + 5'b00001;
				end
			end
			else if (weight4 != 5'b10000) begin
				weight4 = weight4 - 5'b00001;
			end
		end
		else begin
			if (stateA == 1'b1 && weight2 != 5'b01111) begin
				weight2 = weight2 - 5'b00001;
			end
			if (stateB == 1'b1 && weight4 != 5'b01111) begin
				weight4 = weight4 - 5'b00001;
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


		/*
		// 2------------------------------------------------------------
		// sum 2 inputs
		sum2 = uio_in[7:4] + uio_in[3:0];
		if (ui_in[7:0]) begin
			ui_in_tmp = ui_in[7:0];
		end
		if (uio_in[7:0]) begin
			uio_in_tmp = uio_in[7:0];
		end	
		sum1 = next_input1 + next_input2;
		sum2 = next_input3 + next_input4;
		// check if outcome exceeds threshold
		if (sum1 > threshold1) begin
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

			if (stateA == 1'b1) begin
				if (weight1 != 5'b01111) begin
					weight1 = weight1 + 5'b00001;
				end
			end
			else if (weight1 != 5'b10000) begin
				weight1 = weight1 - 5'b00001;
			end

			if (stateB == 1'b1) begin
				if (weight3 != 5'b01111) begin
					weight3 = weight3 + 5'b00001;
				end
			end
			else if (weight3 != 5'b10000) begin
				weight3 = weight3 - 5'b00001;
			end

			stateA = 1'b1;
		end
		else begin
			if (stateA == 1'b1 && weight1 != 5'b10000) begin
				weight1 = weight1 - 5'b00001;
			end
			if (stateB == 1'b1 && weight3 != 5'b10000) begin
				weight3 = weight3 - 5'b00001;
			end
			sum1 = 8'h00;
			stateA = 1'b0;
		end

		if (sum2 > threshold2) begin
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
			if (stateA == 1'b1) begin
				if  (weight2 != 5'b01111) begin
					weight2 = weight2 + 5'b00001;
				end
			end
			else if (weight2 != 5'b10000) begin
				weight2 = weight2 - 5'b00001;
			end
			if (stateB == 1'b1) begin
				if (weight4 != 5'b01111) begin
					weight4 = weight4 + 5'b00001;
				end
			end
			else if (weight4 != 5'b10000) begin
				weight4 = weight4 - 5'b00001;
			end
			stateB = 1'b1;
		end
		else begin
			if (stateA == 1'b1 && weight2 != 5'b01111) begin
				weight2 = weight2 - 5'b00001;
			end
			if (stateB == 1'b1 && weight4 != 5'b01111) begin
				weight4 = weight4 - 5'b00001;
			end
			sum2 = 8'h00;
			stateB = 1'b0;
		end
		*/
	end

	assign uo_out = (sum1 << weight5) + (sum2 << weight6);
	//assign uo_out = 8'b10110;
	assign uio_out = 8'h00;
	assign uio_oe = 8'h00;

	wire _unused = ena;


endmodule
