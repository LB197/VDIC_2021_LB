virtual class base_tester extends uvm_component;
        integer i;

    `uvm_component_utils(base_tester)

    uvm_put_port #(command_s) command_port;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        command_port = new("command_port", this);
    endfunction : build_phase

    pure virtual function operation_t get_op();

    pure virtual function bit [31:0] get_data();

    task run_phase(uvm_phase phase);

        command_s command;

        phase.raise_objection(this);
        command.op = rst_op;
        command_port.put(command);
        repeat (10000) begin : random_loop
            command.op = get_op();
            command.A = get_data();
            command.B = get_data();
            command_port.put(command);
        end : random_loop

        phase.drop_objection(this);

    endtask : run_phase

endclass : base_tester
