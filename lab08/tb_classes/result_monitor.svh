class result_monitor extends uvm_component;
    `uvm_component_utils(result_monitor)

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------

    virtual alu_bfm bfm;
    uvm_analysis_port #(result_transaction) ap;

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
    
        
        // get the bfm 
        alu_agent_config alu_agent_config_h;
        if(!uvm_config_db #(alu_agent_config)::get(this, "","config", alu_agent_config_h))
            `uvm_fatal("RESULT MONITOR", "Failed to get CONFIG");

        // pass the result_monitor handler to the BFM
        alu_agent_config_h.bfm.result_monitor_h = this;
        
        ap = new("ap",this);
        
    endfunction : build_phase

//------------------------------------------------------------------------------
// access function for BFM
//------------------------------------------------------------------------------

    function void write_to_monitor(logic [39:0] r, operation_t op);
        result_transaction result_t;
        result_t        = new("result_t");
        result_t.result = r;
        result_t.result_ctl = r[7:0];
        result_t.op = op;
        ap.write(result_t);
    endfunction : write_to_monitor


endclass : result_monitor
