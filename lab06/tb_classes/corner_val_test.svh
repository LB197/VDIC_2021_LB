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
class corner_val_test extends uvm_test;

    `uvm_component_utils(corner_val_test)

    function new (string name, uvm_component parent);
        super.new(name,parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        random_tester::type_id::set_type_override(corner_val_tester::get_type());
    endfunction : build_phase

//    env env_h;
//
//    function void build_phase(uvm_phase phase);
//        env_h = env::type_id::create("env_h",this);
//
//        // set the factory to produce a add_tester whenever it would produce
//        // a base_tester
//        base_tester::type_id::set_type_override(corner_val_tester::get_type());
//    endfunction : build_phase
//
//    function new (string name, uvm_component parent);
//        super.new(name,parent);
//    endfunction : new
//
//    virtual function void start_of_simulation_phase(uvm_phase phase);
//        super.start_of_simulation_phase(phase);
//        // Print the test topology
//        uvm_top.print_topology();
//    endfunction : start_of_simulation_phase

endclass

