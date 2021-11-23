class testbench;

    virtual alu_bfm bfm;

    function new (virtual alu_bfm b);
        bfm = b;
    endfunction : new

    tester tester_h;
    coverage coverage_h;
    scoreboard scoreboard_h;

    task execute();

// the tesbench components can be declared locally in the task, but this
// task will not exist later, when using UVM
//        tester tester_h;
//        coverage coverage_h;
//        scoreboard scoreboard_h;

        tester_h     = new(bfm);
        coverage_h   = new(bfm);
        scoreboard_h = new(bfm);

        fork
            coverage_h.execute();
            scoreboard_h.execute();
            tester_h.execute();
        join_none

    endtask : execute
endclass : testbench


