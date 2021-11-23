class tester;
	
    virtual alu_bfm bfm;

    function new (virtual alu_bfm b);
        bfm = b;
    endfunction : new

//---------------------------------
// Random data generation functions

	protected function operation_t get_op();
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
	protected function bit [31:0] get_data();
		bit [1:0] zero_ones;
		zero_ones = 2'($urandom);
		if (zero_ones == 2'b00)
			return 32'h0000_0000;
		else if (zero_ones == 2'b11)
			return 32'hFFFF_FFFF;
		else
			return 32'($urandom);
	endfunction : get_data

	task execute();
		operation_t  op_set;
		bit [31:0] A_data;
		bit [31:0] B_data;

		bfm.reset_alu();

		repeat (1000) begin : random_loop

			op_set = get_op();
			A_data = get_data();
			B_data = get_data();

			bfm.send_op(A_data, B_data, op_set);

		end : random_loop
		$finish;
	endtask : execute
endclass : tester