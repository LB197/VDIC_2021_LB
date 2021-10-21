module mtm_Alu_tb();

//------------------------------------------------------------------------------
// type and variable definitions
//------------------------------------------------------------------------------

	typedef enum bit[2:0] {
		and_op                   = 3'b000,
		or_op                    = 3'b001,
		add_op                   = 3'b100,
		sub_op                   = 3'b101
	} operation_t;
	bit                 clk;
	bit                 rst_n;
	bit                 sin;
	bit                 sout;
	operation_t         op_set;

	string             test_result = "PASSED";

// ----------------------------------------
// Device Under Test
// ----------------------------------------

	mtm_Alu u_mtm_Alu (
		.clk  (clk), //posedge active clock
		.rst_n(rst_n), //synchronous reset active low
		.sin  (sin), //serial data input
		.sout (sout) //serial data output
	);

// ----------------------------------------
// clk generation
// ----------------------------------------

	initial begin : clk_gen
		clk = 0;
		forever begin : clk_frv
			#10;
			clk = ~clk;
		end
	end


//------------------------------------------------------------------------------
// Tester
//------------------------------------------------------------------------------

//---------------------------------
// Random data generation functions

	function operation_t get_op();
		bit [1:0] op_choice;
		op_choice = $random;
		case (op_choice)
			2'b00 : return and_op;
			2'b01 : return or_op;
			2'b10 : return add_op;
			2'b11 : return sub_op;
		endcase // case (op_choice)
	endfunction : get_op
//---------------------------------

	function bit [31:0] get_data();
		bit [1:0] zero_ones;
		zero_ones = 2'($random);
		if (zero_ones == 2'b00)
			return 32'h00000000;
		else if (zero_ones == 2'b11)
			return 32'hFFFFFFFF;
		else
			return 32'($urandom%20);
	endfunction : get_data

//---------------------------------

	function [43:0] data_packet(input [31:0] A);
		return {2'b00,A[31:24], 1'b1,2'b00,A[23:16], 1'b1,2'b00,A[15:8], 1'b1,2'b00,A[7:0], 1'b1};
	endfunction : data_packet

//---------------------------------

	function [98:0] data_frame(input [43:0] A, input [43:0]B, [2:0] op_set, [3:0]CRC);
		return {B, A, 3'b010,op_set,CRC,1'b1};

	endfunction : data_frame
//------------------------
// Tester main
	initial begin : tester
		integer i;
		bit [2:0] op_set;
		bit [3:0] CRCin, flags_out;
		bit [2:0] CRCout;
		bit [31:0] A_data, B_data;
		bit [43:0] A_packet, B_packet;
		bit [98:0] data_in;
		bit [54:0] data_out;
		bit [31:0] expected_value;
		bit [31:0] C;

		reset_alu();


		repeat (20) begin : tester_main

			op_set = get_op();
			A_data = get_data();
			B_data = get_data();
			A_packet = data_packet(A_data);
			B_packet = data_packet(B_data);
			CRCin = calculate_CRCin(A_data, B_data, op_set);
			
			data_in = data_frame(A_packet, B_packet, op_set, CRCin);



			$display("Input data A=%d B=%d, OP_code %b, CRC: %b", $signed(A_data), $signed(B_data), op_set, CRCin);
			
			//------------------------------------------------------------------------------
			//Write data to input
			write_in(data_in);		
			read_out(C, flags_out, CRCout);

			//------------------------------------------------------------------------------
			//Read data from output

//			@(negedge sout) begin
//				foreach (data_out[i]) @(negedge clk) data_out[54 - i] = sout;
//			end
			
			//------------------------------------------------------------------------------
			// Data processing
//				temp_data = {data_out[42:35],data_out[31:24],data_out[20:13], data_out[9:2]};
//				temp_crc = data_out[53:51];
//				temp_flags = data_out[50:47];
//				foreach (temp_data[i]) C[i] = temp_data[31 - i];
//				foreach (temp_crc[i]) CRCout = temp_crc[2 - i];
//				foreach (temp_flags[i]) flags_out = temp_flags[3 - i];

			//------------------------------------------------------------------------------
			// temporary data check - scoreboard will do the job later

			expected_value = get_expected(A_data, B_data, op_set);
				$display("expected: %b", expected_value);
			if(C === expected_value) begin
				$display("Test passed with results C: %d, expected: %d\n", $signed(C), $signed(expected_value));
			end else begin
				$display("Test FAILED with results C: %d, expected: %d\n", $signed(C), $signed(expected_value));
			end
		end
		$finish;
	end : tester

//------------------------------------------------------------------------------
// reset task
//------------------------------------------------------------------------------
	task reset_alu();
	`ifdef DEBUG
		$display("%0t DEBUG: reset_alu", $time);
	`endif
		rst_n = 1'b0;
		@(negedge clk);
		rst_n = 1'b1;
		sin = 1'b1;
	endtask

//------------------------------------------------------------------------------
// Write data to input -- input_data - data you want to send
//------------------------------------------------------------------------------
	task write_in(bit[98:0] input_data);
	`ifdef DEBUG
		$display("%0t DEBUG: writing data to input", $time);
	`endif
		foreach (input_data[i]) @(negedge clk) sin = input_data[i];
	endtask
	
//------------------------------------------------------------------------------
// Read data from output -- output_data - returned value with swapped order of the bits
//------------------------------------------------------------------------------
	task read_out(output bit [31:0] C, output bit [3:0] flags_out, output bit [2:0] CRCout);		
		bit [54:0] data_out;
		bit [31:0] temp_data;
		bit [3:0] temp_flags;
		bit [2:0] temp_crc;
		`ifdef DEBUG
			$display("%0t DEBUG: reading data from output", $time);
		`endif
			@(negedge sout) begin
				foreach (data_out[i]) @(negedge clk) data_out[54 - i] = sout;
			end
			
			temp_data = {data_out[42:35],data_out[31:24],data_out[20:13], data_out[9:2]};
			temp_crc = data_out[53:51];
			temp_flags = data_out[50:47];
			foreach (temp_data[i]) C[i] = temp_data[31 - i];
			foreach (temp_crc[i]) CRCout[i] = temp_crc[2 - i];
			foreach (temp_flags[i]) flags_out[i] = temp_flags[3 - i];
	endtask


//------------------------------------------------------------------------------
// calculate expected result
//------------------------------------------------------------------------------
	function logic [31:0] get_expected(
			bit [31:0] A,
			bit [31:0] B,
			operation_t op_set
		);
		bit [31:0] ret;
	`ifdef DEBUG
		$display("%0t DEBUG: get_expected(%0d,%0d,%0d)",$time, A, B, op_set);
	`endif
		case(op_set)
			and_op : ret = B & A;
			or_op  : ret = B | A;
			add_op : ret = B + A;
			sub_op : ret = B - A;
			default: begin
				$display("%0t INTERNAL ERROR. get_expected: unexpected case argument: %s", $time, op_set);
				test_result = "FAILED";
				return -1;
			end
		endcase
		return(ret);
	endfunction
//------------------------------------------------------------------------------
// Temporary. The scoreboard data will be later used.
	final begin : finish_of_the_test
		$display("Test %s.",test_result);
	end
//------------------------------------------------------------------------------

//-----------------------------------------------------------------------------
// CRC function for data[67:0] ,   crc[3:0]=1+x^1+x^4;
//-----------------------------------------------------------------------------

	// polynomial: x^4 + x^1 + 1
	// data width: 68
	// convention: the first serial bit is D[67]
	function [3:0] calculate_CRCin(bit [31:0] A, bit [31:0] B, operation_t op_set);

		reg [67:0] d;
		reg [3:0] c;
		reg [3:0] CRC;
		begin
			d = {B, A, 1'b1, op_set};
			c = 4'b0000;

			CRC[0] = d[66] ^ d[64] ^ d[63] ^ d[60] ^ d[56] ^ d[55] ^ d[54] ^ d[53] ^ d[51] ^ d[49] ^ d[48] ^ d[45] ^ d[41] ^ d[40] ^ d[39] ^ d[38] ^ d[36] ^ d[34] ^ d[33] ^ d[30] ^ d[26] ^ d[25] ^ d[24] ^ d[23] ^ d[21] ^ d[19] ^ d[18] ^ d[15] ^ d[11] ^ d[10] ^ d[9] ^ d[8] ^ d[6] ^ d[4] ^ d[3] ^ d[0] ^ c[0] ^ c[2];
			CRC[1] = d[67] ^ d[66] ^ d[65] ^ d[63] ^ d[61] ^ d[60] ^ d[57] ^ d[53] ^ d[52] ^ d[51] ^ d[50] ^ d[48] ^ d[46] ^ d[45] ^ d[42] ^ d[38] ^ d[37] ^ d[36] ^ d[35] ^ d[33] ^ d[31] ^ d[30] ^ d[27] ^ d[23] ^ d[22] ^ d[21] ^ d[20] ^ d[18] ^ d[16] ^ d[15] ^ d[12] ^ d[8] ^ d[7] ^ d[6] ^ d[5] ^ d[3] ^ d[1] ^ d[0] ^ c[1] ^ c[2] ^ c[3];
			CRC[2] = d[67] ^ d[66] ^ d[64] ^ d[62] ^ d[61] ^ d[58] ^ d[54] ^ d[53] ^ d[52] ^ d[51] ^ d[49] ^ d[47] ^ d[46] ^ d[43] ^ d[39] ^ d[38] ^ d[37] ^ d[36] ^ d[34] ^ d[32] ^ d[31] ^ d[28] ^ d[24] ^ d[23] ^ d[22] ^ d[21] ^ d[19] ^ d[17] ^ d[16] ^ d[13] ^ d[9] ^ d[8] ^ d[7] ^ d[6] ^ d[4] ^ d[2] ^ d[1] ^ c[0] ^ c[2] ^ c[3];
			CRC[3] = d[67] ^ d[65] ^ d[63] ^ d[62] ^ d[59] ^ d[55] ^ d[54] ^ d[53] ^ d[52] ^ d[50] ^ d[48] ^ d[47] ^ d[44] ^ d[40] ^ d[39] ^ d[38] ^ d[37] ^ d[35] ^ d[33] ^ d[32] ^ d[29] ^ d[25] ^ d[24] ^ d[23] ^ d[22] ^ d[20] ^ d[18] ^ d[17] ^ d[14] ^ d[10] ^ d[9] ^ d[8] ^ d[7] ^ d[5] ^ d[3] ^ d[2] ^ c[1] ^ c[3];
			calculate_CRCin = CRC;
		end
	endfunction

//-----------------------------------------------------------------------------
// CRC function for data[36:0] ,   crc[2:0]=x^3 + x^1 + 1;
//-----------------------------------------------------------------------------
	// polynomial: x^3 + x^1 + 1
	// data width: 37
	// convention: the first serial bit is D[36]
	function [2:0] calculate_CRCout(bit [31:0] C, bit[3:0] flags);

		reg [36:0] d;
		reg [2:0] c;
		reg [2:0] CRC;
		begin

			d = {C, 1'b0, flags};
			c = 4'b0000;

			CRC[0] = d[35] ^ d[32] ^ d[31] ^ d[30] ^ d[28] ^ d[25] ^ d[24] ^ d[23] ^ d[21] ^ d[18] ^ d[17] ^ d[16] ^ d[14] ^ d[11] ^ d[10] ^ d[9] ^ d[7] ^ d[4] ^ d[3] ^ d[2] ^ d[0] ^ c[1];
			CRC[1] = d[36] ^ d[35] ^ d[33] ^ d[30] ^ d[29] ^ d[28] ^ d[26] ^ d[23] ^ d[22] ^ d[21] ^ d[19] ^ d[16] ^ d[15] ^ d[14] ^ d[12] ^ d[9] ^ d[8] ^ d[7] ^ d[5] ^ d[2] ^ d[1] ^ d[0] ^ c[1] ^ c[2];
			CRC[2] = d[36] ^ d[34] ^ d[31] ^ d[30] ^ d[29] ^ d[27] ^ d[24] ^ d[23] ^ d[22] ^ d[20] ^ d[17] ^ d[16] ^ d[15] ^ d[13] ^ d[10] ^ d[9] ^ d[8] ^ d[6] ^ d[3] ^ d[2] ^ d[1] ^ c[0] ^ c[2];
			calculate_CRCout = CRC;
		end
	endfunction



endmodule
