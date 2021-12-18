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
class random_command extends uvm_test;
    `uvm_component_utils(random_command)

//------------------------------------------------------------------------------
// env
//------------------------------------------------------------------------------

    env env_h;

//------------------------------------------------------------------------------
// constructor
//------------------------------------------------------------------------------

    function new (string name, uvm_component parent);
        super.new(name,parent);
    endfunction : new

//------------------------------------------------------------------------------
// build phase
//------------------------------------------------------------------------------

    function void build_phase(uvm_phase phase);
        env_h = env::type_id::create("env_h",this);
    endfunction : build_phase

//------------------------------------------------------------------------------
// end-of-elaboration phase
//------------------------------------------------------------------------------

    function void end_of_elaboration_phase(uvm_phase phase);
        // other printers available:
        // - uvm_default_line_printer
        // - uvm_default_tree_printer
        set_print_color(COLOR_BLUE_ON_WHITE);
        this.print(uvm_default_table_printer); // print test env topology
        set_print_color(COLOR_DEFAULT);
    endfunction : end_of_elaboration_phase

endclass
