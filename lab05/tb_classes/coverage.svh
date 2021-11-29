class coverage extends uvm_component;

	`uvm_component_utils(coverage)

	virtual alu_bfm bfm;

	bit                  [31:0] A_data;
	bit                  [31:0] B_data;
	operation_t                op_set;


	covergroup op_cov;

		option.name = "cg_op_cov";

		coverpoint op_set {
			// #A1 test all operations
			bins A1_all_operations_and  = and_op;
			bins A1_all_operations_or   = or_op;
			bins A1_all_operations_add  = add_op;
			bins A1_all_operations_sub  = sub_op;

			// #A2 execute all operations after reset
			bins A2_rst_opn_and       = (rst_op => and_op);
			bins A2_rst_opn_or        = (rst_op => or_op);
			bins A2_rst_opn_add       = (rst_op => add_op);
			bins A2_rst_opn_sub       = (rst_op => sub_op);

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
			bins zeros  = {'h0000_0000};
			bins others = {['h0000_0001:'hFFFF_FFFE]};
			bins ones   = {'hFFFF_FFFF};
		}

		b_leg: coverpoint B_data {
			bins zeros  = {'h0000_0000};
			bins others = {['h0000_0001:'hFFFF_FFFE]};
			bins ones   = {'hFFFF_FFFF};
		}

		B_op_00_FF: cross a_leg, b_leg, all_ops {

			// #B1 Simulate all zeros on an input for all operations

			bins B1_and_00          = (binsof (all_ops) intersect {and_op} && (binsof (a_leg.zeros) || binsof (b_leg.zeros)));
			bins B1_or_00           = (binsof (all_ops) intersect {or_op}  && (binsof (a_leg.zeros) || binsof (b_leg.zeros)));
			bins B1_add_00          = (binsof (all_ops) intersect {add_op} && (binsof (a_leg.zeros) || binsof (b_leg.zeros)));
			bins B1_sub_00          = (binsof (all_ops) intersect {sub_op} && (binsof (a_leg.zeros) || binsof (b_leg.zeros)));

			// #B2 Simulate all ones on an input for all operations

			bins B2_and_FF          = (binsof (all_ops) intersect {and_op} && (binsof (a_leg.ones) || binsof (b_leg.ones)));
			bins B2_or_FF           = (binsof (all_ops) intersect {or_op}  && (binsof (a_leg.ones) || binsof (b_leg.ones)));
			bins B2_add_FF          = (binsof (all_ops) intersect {add_op} && (binsof (a_leg.ones) || binsof (b_leg.ones)));
			bins B2_sub_FF          = (binsof (all_ops) intersect {sub_op} && (binsof (a_leg.ones) || binsof (b_leg.ones)));
			ignore_bins others_only = (binsof(a_leg.others) && binsof(b_leg.others));
		}

	endgroup

// Covergroup checking what happens when error occurs

	covergroup error_flags;

		option.name = "cg_flagg_err_occ";

		coverpoint op_set {

			// Number of data packets before CTL packet
			bins  C1_ctl_cor        = ctl_cor;
			// OP code bits corruption
			bins  C2_op_cor         = op_cor;
			// Data bits corruption/CRC bits corruption
			bins  C3_crc_cor        = crc_cor;
		}
	endgroup

    function new (string name, uvm_component parent);
        super.new(name, parent);
		op_cov                      = new();
		zeros_or_ones_on_ops        = new();
		error_flags                 = new();
    endfunction : new

    function void build_phase(uvm_phase phase);
        if(!uvm_config_db #(virtual alu_bfm)::get(null, "*","bfm", bfm))
            $fatal(1,"Failed to get BFM");
    endfunction : build_phase

	task run_phase(uvm_phase phase);
		forever begin : sampling_block
			@(negedge bfm.clk);
			A_data      = bfm.A_data;
			B_data      = bfm.B_data;
			op_set      = bfm.op_set;
			op_cov.sample();
			zeros_or_ones_on_ops.sample();
			error_flags.sample();
		end : sampling_block
	 endtask : run_phase


endclass : coverage
