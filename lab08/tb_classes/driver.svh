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
class driver extends uvm_component;
    `uvm_component_utils(driver)

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------

    virtual alu_bfm bfm;
    uvm_get_port #(command_transaction) command_port;

//------------------------------------------------------------------------------
// constructor
//------------------------------------------------------------------------------

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

//------------------------------------------------------------------------------
// build phase
//------------------------------------------------------------------------------
 
   function void build_phase(uvm_phase phase);
      alu_agent_config alu_agent_config_h;
      if(!uvm_config_db #(alu_agent_config)::get(this, "","config", alu_agent_config_h))
        `uvm_fatal("DRIVER", "Failed to get config");
      bfm = alu_agent_config_h.bfm;
      command_port = new("command_port",this);
   endfunction : build_phase


//------------------------------------------------------------------------------
// run_phase
//------------------------------------------------------------------------------

    task run_phase(uvm_phase phase);
        bit unsigned [31:0] iA;
        bit unsigned [31:0] iB;
        operation_t op_set;
        logic [39:0] result;
        command_transaction command;
        forever begin : command_loop
            command_port.get(command);
            bfm.send_op(command.A, command.B, command.op, result);
        end : command_loop
        $display("A:%h, B:%h,op:%b, res: %h",command.A, command.B, command.op, result);
    endtask : run_phase


endclass : driver
