module mtm_Alu_tb();

//------------------------------------------------------------------------------
// type and variable definitions
//------------------------------------------------------------------------------

	typedef enum bit[2:0] {
		and_op                   = 3'b000,
		or_op                    = 3'b001,
		add_op                   = 3'b100,
		sub_op                   = 3'b101,
		op_cor                   = 3'b010,
		crc_cor                  = 3'b011,
		ctl_cor                  = 3'b110,
		rst_op                   = 3'b111
	} operation_t;

	typedef enum bit {DATA = 1'b0, CTL = 1'b1} packet_type_t;

	bit                 clk;
	bit                 rst_n;
	bit                 sin;
	logic               sout; //TODO change to logic


	bit [31:0] A_data, B_data, C, Cexp;
	bit [2:0] errors;
	bit [7:0] ctl_exp, ctl;
	bit doScoreboard;
	operation_t op_set;

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
// Coverage
//------------------------------------------------------------------------------


	covergroup op_cov;

		option.name = "cg_op_cov";

		coverpoint op_set {
			// #A1 test all operations
			bins A1_all_operations_and 	= and_op;
			bins A1_all_operations_or 	= or_op;
			bins A1_all_operations_add 	= add_op;
			bins A1_all_operations_sub 	= sub_op;

			// #A2 execute all operations after reset
			bins A2_rst_opn_and[]       = (rst_op => and_op);
			bins A2_rst_opn_or[]        = (rst_op => or_op);
			bins A2_rst_opn_add[]       = (rst_op => add_op);
			bins A2_rst_opn_sub[]       = (rst_op => sub_op);


			// #A3 execute reset after all operations
			bins A3_opn_rst_and       = (and_op => rst_op);
			bins A3_opn_rst_or        = (or_op  => rst_op);
			bins A3_opn_rst_add       = (add_op => rst_op);
			bins A3_opn_rst_sub       = (sub_op => rst_op);
			
		}

	endgroup

// Covergroup checking for min and max arguments of the ALU

	covergroup zeros_or_ones_on_ops;

		option.name = "cg_zeros_or_ones_on_ops";

		all_ops : coverpoint op_set {
			ignore_bins null_ops = {op_cor, crc_cor, ctl_cor, rst_op};
		}

		a_leg: coverpoint A_data {
			bins zeros = {'h0000_0000};
			bins others= {['h0000_0001:'hFFFF_FFFE]};
			bins ones  = {'hFFFF_FFFF};
		}

		b_leg: coverpoint B_data {
			bins zeros = {'h0000_0000};
			bins others= {['h0000_0001:'hFFFF_FFFE]};
			bins ones  = {'hFFFF_FFFF};
		}

		B_op_00_FF: cross a_leg, b_leg, all_ops {

			// #B1 simulate all zero inwrong_no_data_framesput for all the operations

			bins B1_and_00          = binsof (all_ops) intersect {and_op} &&
			(binsof (a_leg.zeros) || binsof (b_leg.zeros));

			bins B1_or_00          = binsof (all_ops) intersect {or_op} &&
			(binsof (a_leg.zeros) || binsof (b_leg.zeros));

			bins B1_add_00          = binsof (all_ops) intersect {add_op} &&
			(binsof (a_leg.zeros) || binsof (b_leg.zeros));

			bins B1_sub_00          = binsof (all_ops) intersect {sub_op} &&
			(binsof (a_leg.zeros) || binsof (b_leg.zeros));

			// #B2 simulate all one input for all the operations

			bins B2_and_FF          = binsof (all_ops) intersect {and_op} &&
			(binsof (a_leg.ones) || binsof (b_leg.ones));

			bins B2_or_FF          = binsof (all_ops)  intersect {or_op} &&
			(binsof (a_leg.ones) || binsof (b_leg.ones));

			bins B2_add_FF          = binsof (all_ops) intersect {add_op} &&
			(binsof (a_leg.ones) || binsof (b_leg.ones));

			bins B2_sub_FF          = binsof (all_ops) intersect {sub_op} &&
			(binsof (a_leg.ones) || binsof (b_leg.ones));

			ignore_bins others_only =
			binsof(a_leg.others) && binsof(b_leg.others);
		}

	endgroup

// Covergroup checking what happens when error occurs

	covergroup error_flags;

		option.name = "cg_flagg_err_occ";

		coverpoint op_set {

			bins  C1_ctl_cor        = ctl_cor;

			bins  C2_op_cor         = op_cor;

			bins  C3_crc_cor        = crc_cor;
		}
	endgroup


	op_cov                      oc;
	zeros_or_ones_on_ops        c_00_FF;
	error_flags                 er_fl;


	initial begin : coverage
		oc      = new();
		c_00_FF = new();
		er_fl   = new();
		forever begin : sample_cov
			@(posedge clk);
			if(doScoreboard || !rst_n) begin
				oc.sample();
				c_00_FF.sample();
				er_fl.sample();
			end
		end
	end : coverage

//------------------------------------------------------------------------------
// Tester
//------------------------------------------------------------------------------

//---------------------------------
// Random data generation functions

	function operation_t get_op();
		bit [2:0] op_choice;
		op_choice = 3'($urandom);
		case (op_choice)
			3'b000 : return and_op;
			3'b001 : return or_op;
			3'b010 : return add_op;
			3'b011 : return sub_op;
			3'b100 : return op_cor;
			3'b101 : return crc_cor;
			3'b110 : return ctl_cor;
			3'b111 : return rst_op;
		endcase // case (op_choice)
	endfunction : get_op

//---------------------------------

	function operation_t get_op_when_error();
		bit [2:0] op_choice;
		op_choice = 2'($urandom);
		case (op_choice)
			2'b00 : return and_op;
			2'b01 : return or_op;
			2'b10 : return add_op;
			2'b11 : return sub_op;
		endcase // case (op_choice)
	endfunction : get_op_when_error

//---------------------------------
	function bit [31:0] get_data();
		bit [1:0] zero_ones;
		zero_ones = 2'($urandom);
		if (zero_ones == 2'b00)
			return 32'h00000000;
		else if (zero_ones == 2'b11)
			return 32'hFFFFFFFF;
		else
			return 32'($urandom);
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
			for (i = 0; i < (data_error ? $urandom%3 : 4); i = i + 1)
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
		corrupted_bit = $urandom%31;

		A_val = A;
		B_val = B;
		if (data_bit_error && ~crc_error) begin
			if (1'($urandom)) A_val[corrupted_bit] = ~A_val[corrupted_bit];
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
		logic [54:0] data_out;
		bit [3:0] CRCin, calc_crc,  flags_out, flags_exp;
		bit [2:0] CRCout, CRCexp;
		bit [43:0] A_packet, B_packet;
		bit [98:0] data_in, data_prep;
		bit ERR_CRC, ERR_OP, ERR_DATA, ERR_BIT;
		bit [5:0] error_flags, error_exp;
		bit parity, parity_exp;
		bit crc_error;
		bit [3:0] allzeroone;

		i = 0;
		j = 0;

		reset_alu();

		repeat (10000) begin : tester_main
			@(negedge clk)

				doScoreboard = 1'b0;
			ERR_CRC  =  1'b0;
			ERR_OP   =  1'b0;
			ERR_DATA =  1'b0;
			ERR_BIT  =  1'b0;

			op_set = get_op();
			A_data = get_data();
			B_data = get_data();



			case (op_set) // handle the start signnal
				3'b111: begin : case_rst_op
					reset_alu();
				end
				3'b010 : begin : case_wrong_op
					ERR_OP = 1'b1;
					errors = {ERR_DATA, (ERR_CRC | ERR_BIT), ERR_OP};
					send_data_to_input(A_data, B_data, op_set, ERR_CRC, ERR_DATA, ERR_BIT);
					read_data_from_output(C, ctl);
					doScoreboard = 1'b1;
				end
				3'b011 : begin : case_wrong_crc
					ERR_CRC = 1'($random);
					ERR_BIT = !ERR_CRC;
					errors = {ERR_DATA, (ERR_CRC | ERR_BIT), ERR_OP};
					send_data_to_input(A_data, B_data, get_op_when_error(), ERR_CRC, ERR_DATA, ERR_BIT);
					read_data_from_output(C, ctl);
					doScoreboard = 1'b1;
				end
				3'b110 : begin : case_wrong_ctl
					ERR_DATA = 1'b1;
					errors = {ERR_DATA, (ERR_CRC | ERR_BIT), ERR_OP};
					send_data_to_input(A_data, B_data, get_op_when_error(), ERR_CRC, ERR_DATA, ERR_BIT);
					read_data_from_output(C, ctl);
					doScoreboard = 1'b1;
				end
				default: begin : case_default
					errors = {ERR_DATA, (ERR_CRC | ERR_BIT), ERR_OP};
					send_data_to_input(A_data, B_data, op_set, ERR_CRC, ERR_DATA, ERR_BIT);
					read_data_from_output(C, ctl);

					doScoreboard = 1'b1;
				end
			endcase // case (op_set)
			$strobe("%0t coverage: %.4g\%",$time, $get_coverage());
			if($get_coverage() == 100) break;
		//------------------------------------------------------------------------------

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

		Zero = !(Cexp);
		Negative = Cexp[31];
		Carry = Cext[32];

		flags_exp = {Carry, Overflow, Zero, Negative};
		CRCexp = calculate_CRCout(Cexp, flags_exp);

		if (errors) CTL_exp = {1'b1, error_flags, parity};
		else CTL_exp = {1'b0, flags_exp, CRCexp};

	endtask//------------------------------------------------------------------------------

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


//------------------------------------------------------------------------------
// Scoreboard
//------------------------------------------------------------------------------

	always @(negedge clk) begin : scoreboard
		if(doScoreboard) begin:verify_result

			get_expected(A_data, B_data, op_set, errors, Cexp, ctl_exp);

			CHK_RESULT: if((C === Cexp) && (ctl_exp === ctl)) begin
		   `ifdef DEBUG
				$display("%0t Test passed with correct data for A=%0d B=%0d op_set=%0d", $time, A_data, B_data, op_set);
		   `endif
			end else if ((errors != 0) && (ctl_exp === ctl)) begin
		   `ifdef DEBUG
				$display("%0t Test passed with correct error frame", $time, A_data, B_data, op_set);
		   `endif
			end else begin
				$warning("%0t Test FAILED for A=%0d B=%0d op_set=%0d\nExpected: %d  received: %d ctl_exp: %b, ctl: %b",
					$time, A_data, B_data, op_set , C, Cexp, ctl_exp, ctl);
			end;

		end
	end : scoreboard

endmodule : mtm_Alu_tb