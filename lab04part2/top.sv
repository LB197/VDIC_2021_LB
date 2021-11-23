module top;
	import alu_pkg::*;
	`include "alu_macros.svh"

	mtm_Alu u_mtm_Alu (
		.clk  (bfm.clk), //posedge active clock
		.rst_n(bfm.rst_n), //synchronous reset active low
		.sin  (bfm.sin), //serial data input
		.sout (bfm.sout) //serial data output
	);

	alu_bfm bfm();
	testbench testbench_h;

	initial begin
		testbench_h = new(bfm);
		testbench_h.execute();
	end

endmodule : top
