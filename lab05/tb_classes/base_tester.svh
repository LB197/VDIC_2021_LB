//`ifdef QUESTA
//virtual class base_tester extends uvm_component;
//`else
//`ifdef INCA
// irun requires abstract class when using virtual functions
// note: irun warns about the virtual class instantiation, this will be an
// error in future releases.
virtual class base_tester extends uvm_component;
//`else
//class base_tester extends uvm_component;
//`endif
//`endif

	`uvm_component_utils(base_tester)

	virtual alu_bfm bfm;

	function new (string name, uvm_component parent);
		super.new(name, parent);
	endfunction : new

	function void build_phase(uvm_phase phase);
		if(!uvm_config_db #(virtual alu_bfm)::get(null, "*","bfm", bfm))
			$fatal(1,"Failed to get BFM");
	endfunction : build_phase

	pure virtual function operation_t get_op();

	pure virtual function bit [31:0] get_data();

	task run_phase(uvm_phase phase);

		operation_t  op_set;
		bit [31:0] A_data;
		bit [31:0] B_data;

		phase.raise_objection(this);

		bfm.reset_alu();

		repeat (1000) begin : random_loop

			op_set = get_op();
			A_data = get_data();
			B_data = get_data();

			bfm.send_op(A_data, B_data, op_set);
			wait (bfm.getExpectedValues == 0);
		end : random_loop
		
			phase.drop_objection(this);

	endtask : run_phase

endclass : base_tester
