class command_monitor extends uvm_component;
    `uvm_component_utils(command_monitor)

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------

    virtual alu_bfm bfm;
    uvm_analysis_port #(command_transaction) ap;

//------------------------------------------------------------------------------
// constructor
//------------------------------------------------------------------------------

    function new (string name, uvm_component parent);
        super.new(name,parent);
    endfunction
 
//------------------------------------------------------------------------------
// build phase
//------------------------------------------------------------------------------

    function void build_phase(uvm_phase phase);
        if(!uvm_config_db #(virtual alu_bfm)::get(null, "*","bfm", bfm))
            `uvm_fatal("COMMAND MONITOR", "Failed to get BFM")
        bfm.command_monitor_h = this;
        ap                    = new("ap",this);
    endfunction : build_phase

//------------------------------------------------------------------------------
// access function for BMF
//------------------------------------------------------------------------------

    function void write_to_monitor(bit [31:0] A, bit [31:0] B, operation_t op);
        command_transaction cmd;
        `uvm_info("COMMAND MONITOR",$sformatf("MONITOR: A: %8h  B: %8h  op: %s",
                A, B, op.name()), UVM_HIGH);
        cmd    = new("cmd");
        cmd.A  = A;
        cmd.B  = B;
        cmd.op = op;
        ap.write(cmd);
    endfunction : write_to_monitor
endclass : command_monitor

