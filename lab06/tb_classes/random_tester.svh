/*
 Copyright 2013 Ray Salemi

 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at

 http://www.apache.org/licenses/LICENSE-2.0

 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */
class random_tester extends base_tester;

	`uvm_component_utils (random_tester)

	function new (string name, uvm_component parent);
		super.new(name, parent);
	endfunction : new

//---------------------------------
	function bit [31:0] get_data();
		bit [1:0] zero_ones;
		zero_ones = 2'($urandom);
		if (zero_ones == 2'b00)
			return 32'h0000_0000;
		else if (zero_ones == 2'b11)
			return 32'hFFFF_FFFF;
		else
			return 32'($urandom);
	endfunction : get_data

//---------------------------------

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

endclass : random_tester






