package alu_pkg;

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

	typedef enum bit {
		DATA = 1'b0,
		CTL  = 1'b1
	} packet_type_t;

`include "coverage.svh"
`include "tester.svh"
`include "scoreboard.svh"
`include "testbench.svh"

endpackage : alu_pkg