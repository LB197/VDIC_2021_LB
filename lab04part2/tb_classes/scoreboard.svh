class  scoreboard;
	virtual alu_bfm bfm;

	function new (virtual alu_bfm b);
		bfm = b;
	endfunction : new

	bit [31:0] Cexp;
	bit [7:0] ctl_exp;

	string test_result = "PASSED";

	protected function get_expected(
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

		if (errors != 0) begin
			if      (errors[2] == 1'b1) error_flags = {6'b100100};
			else if (errors[1] == 1'b1) error_flags = {6'b010010};
			else error_flags = {6'b001001};
		end

		parity = (1'b1 ^ error_flags[5] ^ error_flags[4] ^ error_flags[3] ^ error_flags[2] ^ error_flags[1] ^ error_flags[0]);

		Zero = !(Cexp);
		Negative = Cexp[31];
		Carry = Cext[32];

		flags_exp = {Carry, Overflow, Zero, Negative};
		CRCexp = calculate_CRCout(Cexp, flags_exp);

		if (errors) CTL_exp = {1'b1, error_flags, parity};
		else CTL_exp = {1'b0, flags_exp, CRCexp};

	endfunction
//------------------------------------------------------------------------------


//-----------------------------------------------------------------------------
// CRC function for data[36:0] ,   crc[2:0]=x^3 + x^1 + 1;
//-----------------------------------------------------------------------------
	// polynomial: x^3 + x^1 + 1
	// data width: 37
	// convention: the first serial bit is D[36]
	protected function [2:0] calculate_CRCout(bit [31:0] C, bit[3:0] flags);

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

	task execute();
		forever begin : scoreboard

			forever begin : get_expected_values
				@(posedge bfm.getExpectedValues) begin
					bfm.getExpectedValues = 1'b0;
					get_expected(bfm.A_data, bfm.B_data, bfm.op_set, bfm.errors, Cexp, ctl_exp);
				`ifdef DEBUG
					$display("A: %b B: %b op_set: %b errors: %b", bfm.A_data, bfm.B_data, bfm.op_set, bfm.errors);
				`endif
				end
			end : get_expected_values

			@(posedge bfm.doScoreboard) begin
				bfm.doScoreboard = 1'b0;
				if((bfm.C === Cexp) && (ctl_exp === bfm.ctl)) begin
	   `ifdef DEBUG
					$display("%0t Test passed with correct data for A=%0d B=%0d op_set=%0d", $time, bfm.A_data, bfm.B_data, bfm.op_set);
	   `endif
				end else if ((bfm.errors != 0) && (ctl_exp === bfm.ctl)) begin
	   `ifdef DEBUG
					$display("%0t Test passed with correct error frame", $time, bfm.A_data, bfm.B_data, bfm.op_set);
	   `endif
				end else begin
					$warning("%0t Test FAILED for A=%0d B=%0d op_set=%0d\nExpected: %d  received: %d ctl_exp: %b, ctl: %b",
						$time, bfm.A_data, bfm.B_data, bfm.op_set , Cexp, bfm.C, ctl_exp, bfm.ctl);
				end;
			end
		end: scoreboard
	endtask : execute
//  final begin : finish_of_the_test
//      $display("Test %s.",test_result);
//  end


endclass : scoreboard