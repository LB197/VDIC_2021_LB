`timescale 1ns/1ps

package alu_pkg;

	import uvm_pkg::*;
	`include "uvm_macros.svh"

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

    // terminal print colors
    typedef enum {
        COLOR_BOLD_BLACK_ON_GREEN,
        COLOR_BOLD_BLACK_ON_RED,
        COLOR_BOLD_BLACK_ON_YELLOW,
        COLOR_BOLD_BLUE_ON_WHITE,
        COLOR_BLUE_ON_WHITE,
        COLOR_DEFAULT
    } print_color;

//------------------------------------------------------------------------------
// package functions
//------------------------------------------------------------------------------

    // used to modify the color of the text printed on the terminal

    function void set_print_color ( print_color c );
        string ctl;
        case(c)
            COLOR_BOLD_BLACK_ON_GREEN : ctl  = "\033\[1;30m\033\[102m";
            COLOR_BOLD_BLACK_ON_RED : ctl    = "\033\[1;30m\033\[101m";
            COLOR_BOLD_BLACK_ON_YELLOW : ctl = "\033\[1;30m\033\[103m";
            COLOR_BOLD_BLUE_ON_WHITE : ctl   = "\033\[1;34m\033\[107m";
            COLOR_BLUE_ON_WHITE : ctl        = "\033\[0;34m\033\[107m";
            COLOR_DEFAULT : ctl              = "\033\[0m\n";
            default : begin
                $error("set_print_color: bad argument");
                ctl                          = "";
            end
        endcase
        $write(ctl);
    endfunction

//------------------------------------------------------------------------------
// testbench classes
//------------------------------------------------------------------------------

`include "command_transaction.svh"
`include "minmax_transaction.svh"
`include "result_transaction.svh"
`include "coverage.svh"
`include "tester.svh"
`include "scoreboard.svh"
`include "driver.svh"
`include "command_monitor.svh"
`include "result_monitor.svh"
`include "env.svh"

//------------------------------------------------------------------------------
// test classes
//------------------------------------------------------------------------------

`include "random_command.svh"
`include "minmax_command.svh"

endpackage : alu_pkg