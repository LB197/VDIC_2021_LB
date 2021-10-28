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

	typedef enum bit {DATA = 1'b0, CTL = 1'b1} packet_type_t;

	bit                 clk;
	bit                 rst_n;
	bit                 sin;
	logic                 sout; //TODO change to logic

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
		bit [2:0] op_choice;
		op_choice = $random%5;
		case (op_choice)
			3'b000 : return and_op;
			3'b001 : return or_op;
			3'b010 : return add_op;
			3'b011 : return sub_op;
			3'b100 : return operation_t'(3'b010);
			3'b101 : return operation_t'(3'b011);
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
			return 32'($random);
	endfunction : get_data

//---------------------------------

	task send_packet(packet_type_t packet_type, input bit [7:0] input_8b_data);
		integer i;
		begin
			@(negedge clk) sin = 1'b0;
			@(negedge clk) sin = packet_type;
			for (i = 0; i < 8; i = i + 1)
				@(negedge clk) sin = input_8b_data[7-i];
			@(negedge clk) sin = 1'b1;
		end
	endtask : send_packet

//---------------------------------

	task send_32b_data_packet(input bit [31:0] input_32b_data, bit data_error);
		integer i;
		begin
			for (i = 0; i < (data_error ? $random%3 : 4); i = i + 1)
				send_packet(DATA, input_32b_data[31-8*i-:8]);
		end
	endtask : send_32b_data_packet

//---------------------------------

	task send_ctl_packet(input operation_t op_code, input bit [3:0] CRCin);
		begin
			send_packet(CTL, {1'b0, op_code, CRCin});
		end
	endtask : send_ctl_packet

//---------------------------------
	task send_data_to_input(input bit [31:0] A, input bit [31:0] B, input operation_t op_code, input bit crc_error, input bit data_nr_error, input bit data_bit_error);
		integer bit_data_error;

		bit [31:0] A_val, B_val;
		bit [3:0] CRCin;
		bit corrupted_bit;
		corrupted_bit = $random%31;

		A_val = A;
		B_val = B;
		if (data_bit_error && ~crc_error) begin
			if (1'($random)) A_val[corrupted_bit] = ~A_val[corrupted_bit];
			else B_val[corrupted_bit] = ~B_val[corrupted_bit];
		end

		begin
			CRCin = calculate_CRCin(A, B, op_code);
			send_32b_data_packet(B_val, data_nr_error);
			send_32b_data_packet(A_val, data_nr_error);
			if(crc_error) CRCin = CRCin ^ 4'b0001;
			send_ctl_packet(op_code, CRCin);
		end
	endtask : send_data_to_input

	task read_packet (output logic [7:0] output_8b_data, output packet_type_t packet_type);
		integer i;
		begin
			wait(sout == 1'b0);
			@(negedge clk);
			@(negedge clk) packet_type = packet_type_t'(sout);
			for (i = 0; i < 8; i = i + 1)
				@(negedge clk) output_8b_data[7 - i] = sout;
			wait(sout == 1'b1);
		end

	endtask : read_packet

	task read_data_from_output(output logic [31:0] C, output logic [7:0] ctl);
		integer i;
		logic [7:0] data_out[5];
		packet_type_t data_type[5];

		begin
			read_packet(data_out[0], data_type[0]);
			case (data_type[0])
				DATA: begin// no_error
					for (i = 1; i < 5; i = i + 1)
						read_packet(data_out[i], data_type[i]);
					C = {data_out[0], data_out[1], data_out[2], data_out[3]};
					ctl = data_out[4][7:0];
				end
				CTL: begin// error
					ctl = data_out[0][7:0];
				end
			endcase
		end
	endtask : read_data_from_output
//---------------------------------

// Tester main
	initial begin : tester
		integer i;
		integer j;
		bit [3:0] CRCin, calc_crc,  flags_out, flags_exp;
		bit [2:0] CRCout, CRCexp, errors;
		bit [31:0] A_data, B_data, C, Cexp, expected_value;
		bit [43:0] A_packet, B_packet;
		bit [98:0] data_in, data_prep;
		logic [54:0] data_out;
		bit ERR_CRC, ERR_OP, ERR_DATA, ERR_BIT;
		bit [5:0] error_flags, error_exp;
		bit parity, parity_exp;
		bit [7:0] ctl, ctl_exp;
		bit crc_error;
		bit [3:0] allzeroone;
		operation_t op_set;

		i = 0;
		j = 0;

		reset_alu();

		repeat (100000) begin : tester_main
			@(negedge clk)

				//reset before operation
				if(3'($random) == 0) reset_alu();

			ERR_CRC  =  1'b0;
			ERR_OP   =  1'b0;
			ERR_DATA =  1'b0;
			ERR_BIT  =  1'b0;

			op_set = get_op();

			allzeroone = 4'($random);
			if(allzeroone == 4'h0) begin
				A_data = 32'h00000000;
				B_data = 32'h00000000;
			end else if (allzeroone == 4'hF) begin
				A_data = 32'hFFFFFFFF;
				B_data = 32'hFFFFFFFF;
			end else begin
				A_data = get_data();
				B_data = get_data();
			end

			if (2'($random) == 0) ERR_BIT = 1'b1;
			if ((op_set == 3'b010) || (op_set == 3'b011)) ERR_OP = 1'b1;
			if (2'($random) == 0) ERR_CRC = 1'b1;
			if (2'($random) == 0) ERR_DATA = 1'b1;
			errors = {ERR_DATA, (ERR_CRC | ERR_BIT), ERR_OP};
			$display("errors %b op_set %b", errors, op_set);

			send_data_to_input(A_data, B_data, op_set, ERR_CRC, ERR_DATA, ERR_BIT);
			$display("Input data A=%d B=%d, OP_set %b", $signed(A_data), $signed(B_data), op_set);
			read_data_from_output(C, ctl);

			//------------------------------------------------------------------------------
			// temporary data check - scoreboard will do the job later
			get_expected(A_data, B_data, op_set, errors, Cexp, ctl_exp);
			$display("ctl_prs:%b", ctl);
			$display("ctl_exp:%b", ctl_exp);
			$display("Cprs:%b", C);
			$display("Cexp:%b\n", Cexp);
			begin
				if ((ctl == ctl_exp) && (C == Cexp) && (errors == 0)) i = i+1;
				else if ((ctl == ctl_exp) && (errors > 0)) i = i+1;
				else j = j + 1;
			end

			//reset after operation
			if(3'($random) == 0) reset_alu();
		end
		$display("passed: %d, failed: %d", i, j);
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
// calculate expected result
//------------------------------------------------------------------------------
	task get_expected(
			input       bit [31:0]  A_data, B_data,
			input       operation_t op_set,
			input       bit [2:0] errors,
			output      bit [31:0]  Cexp,
			output      bit [7:0]   CTL_exp
		);

		bit Carry, Overflow, Negative, Zero, parity;
		bit [32:0] Cext;
		bit [3:0]   flags_exp;
		bit [2:0]   CRCexp;
		bit [5:0]   error_flags;

		Carry =     1'b0;
		Overflow =  1'b0;
		Negative =  1'b0;
		Zero =      1'b0;
		Cext =      0;
  `ifdef DEBUG
		$display("%0t DEBUG: get_expected(%0d,%0d,%0d)",$time, A_data, B_data, op_set);
  `endif

		case(op_set)
			and_op : Cexp = B_data & A_data;
			or_op  : Cexp = B_data | A_data;
			add_op : begin
				Cexp = B_data + A_data;
				Cext = {1'b0, B_data} + {1'b0, A_data};
				Overflow = (~(1'b0 ^ A_data[31] ^ B_data[31]) & (B_data[31] ^ Cext[31]));
			end
			sub_op : begin
				Cexp = B_data - A_data;
				Cext = {1'b0, B_data} - {1'b0, A_data};
				Overflow = (~(1'b1 ^ A_data[31] ^ B_data[31]) & (B_data[31] ^ Cext[31]));
			end
		endcase
		//---------------------------------------

		if (errors > 0) begin
			if      (errors[2] == 1'b1) error_flags = {6'b100100};
			else if (errors[1] == 1'b1) error_flags = {6'b010010};
			else if (errors[0] == 1'b1) error_flags = {6'b001001};
			else error_flags = {6'b000000};
			parity = (1'b1 ^ error_flags[5] ^ error_flags[4] ^ error_flags[3] ^ error_flags[2] ^ error_flags[1] ^ error_flags[0]);
		end

		Zero = !(Cexp[31:0]);
		Negative = Cexp[31];
		Carry = Cext[32];

		flags_exp = {Carry, Overflow, Zero, Negative};
		CRCexp = calculate_CRCout(Cexp, flags_exp);

		if (errors) CTL_exp = {1'b1, error_flags, parity};
		else CTL_exp = {1'b0, flags_exp, CRCexp};

	endtask

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
