class scoreboard extends uvm_subscriber #(result_transaction);
    `uvm_component_utils(scoreboard)

//------------------------------------------------------------------------------
// local typedefs
//------------------------------------------------------------------------------

    typedef enum bit {
        TEST_PASSED,
        TEST_FAILED
    } test_result;

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------

    virtual alu_bfm bfm;
    uvm_tlm_analysis_fifo #(command_transaction) cmd_f;

    protected test_result tr = TEST_PASSED; // the result of the current test

    protected bit Carry, Overflow, Negative, Zero, parity;
    protected bit [32:0] Cext;
    protected bit [3:0]   flags_exp;
    protected bit [2:0]   CRCexp;
    protected bit [5:0]   error_flags;
    protected bit [39:0] result;
    protected bit [7:0] pred_ctl;
    protected bit [7:0] act_ctl;

//------------------------------------------------------------------------------
// constructor
//------------------------------------------------------------------------------

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

//------------------------------------------------------------------------------
// print the PASSED/FAILED in color
//------------------------------------------------------------------------------
    protected function void print_test_result (test_result r);
        if(tr == TEST_PASSED) begin
            set_print_color(COLOR_BOLD_BLACK_ON_GREEN);
            $write ("-----------------------------------\n");
            $write ("----------- Test PASSED -----------\n");
            $write ("-----------------------------------");
            set_print_color(COLOR_DEFAULT);
            $write ("\n");
        end
        else begin
            set_print_color(COLOR_BOLD_BLACK_ON_RED);
            $write ("-----------------------------------\n");
            $write ("----------- Test FAILED -----------\n");
            $write ("-----------------------------------");
            set_print_color(COLOR_DEFAULT);
            $write ("\n");
        end
    endfunction

//------------------------------------------------------------------------------
// build phase
//------------------------------------------------------------------------------

    function void build_phase(uvm_phase phase);
        cmd_f = new ("cmd_f", this);
    endfunction : build_phase

//------------------------------------------------------------------------------
// function to calculate the expected ALU result
//------------------------------------------------------------------------------

    bit [31:0] Cexp;
    bit [7:0] ctl_exp;

    protected function result_transaction get_expected(command_transaction cmd);
        result_transaction predicted;

        predicted = new("predicted");
        
        Carry =     1'b0;
        Overflow =  1'b0;
        Negative =  1'b0;
        Zero =      1'b0;
        Cext =      0;

        case(cmd.op)
            and_op : begin
                Cexp = cmd.B & cmd.A;
            end
            or_op  : begin
                Cexp = cmd.B | cmd.A;
            end
            add_op : begin
                Cexp = cmd.B + cmd.A;
                Cext = {1'b0, cmd.B} + {1'b0, cmd.A};
                Overflow = (~(1'b0 ^ cmd.A[31] ^ cmd.B[31]) & (cmd.B[31] ^ Cext[31]));
                Carry = Cext[32];
            end
            sub_op : begin
                Cexp = cmd.B - cmd.A;
                Cext = {1'b0, cmd.B} - {1'b0, cmd.A};
                Overflow = (~(1'b1 ^ cmd.A[31] ^ cmd.B[31]) & (cmd.B[31] ^ Cext[31]));
                Carry = Cext[32];
            end
            op_cor : begin
                error_flags = {6'b001001};
            end
            crc_cor : begin
                error_flags = {6'b010010};
            end
            ctl_cor : begin
                error_flags = {6'b100100};
            end
        endcase

        if((cmd.op == and_op) || (cmd.op == or_op) || (cmd.op == add_op) || (cmd.op == sub_op)) begin
            Zero = !(Cexp);
            Negative = Cexp[31];
            flags_exp = {Carry, Overflow, Zero, Negative};
            CRCexp = calculate_CRCout(Cexp, flags_exp);
            ctl_exp = {1'b0, flags_exp, CRCexp};
            result = {Cexp, ctl_exp};
        end else if ((cmd.op == op_cor) || (cmd.op == crc_cor) || (cmd.op == ctl_cor)) begin
            Cexp = 32'hFFFF_FFFF;
            parity = (1'b1 ^ error_flags[5] ^ error_flags[4] ^ error_flags[3] ^ error_flags[2] ^ error_flags[1] ^ error_flags[0]);
            ctl_exp = {1'b1, error_flags, parity};
            result = {Cexp, ctl_exp};
        end
        predicted.op = cmd.op;
        predicted.result = result;
        predicted.result_data = Cexp;
        predicted.result_flags = ctl_exp;
        return predicted;

    endfunction : get_expected

//-----------------------------------------------------------------------------
// CRC function for data[36:0] ,   crc[2:0]=x^3 + x^1 + 1;
//-----------------------------------------------------------------------------
    // polynomial: x^3 + x^1 + 1
    // data width: 37
    // convention: the first serial bit is D[36]
    protected function [2:0] calculate_CRCout(bit [31:0] C, bit[3:0] flags);

        reg [36:0] d;
        reg [2:0] c;
        reg [2:0] CRC;
        begin

            d = {C, 1'b0, flags};
            c = 4'b0000;

            CRC[0] = d[35] ^ d[32] ^ d[31] ^ d[30] ^ d[28] ^ d[25] ^ d[24] ^ d[23] ^ d[21] ^ d[18] ^ d[17] ^ d[16] ^ d[14] ^ d[11] ^ d[10] ^ d[9] ^ d[7] ^ d[4] ^ d[3] ^ d[2] ^ d[0] ^ c[1];
            CRC[1] = d[36] ^ d[35] ^ d[33] ^ d[30] ^ d[29] ^ d[28] ^ d[26] ^ d[23] ^ d[22] ^ d[21] ^ d[19] ^ d[16] ^ d[15] ^ d[14] ^ d[12] ^ d[9] ^ d[8] ^ d[7] ^ d[5] ^ d[2] ^ d[1] ^ d[0] ^ c[1] ^ c[2];
            CRC[2] = d[36] ^ d[34] ^ d[31] ^ d[30] ^ d[29] ^ d[27] ^ d[24] ^ d[23] ^ d[22] ^ d[20] ^ d[17] ^ d[16] ^ d[15] ^ d[13] ^ d[10] ^ d[9] ^ d[8] ^ d[6] ^ d[3] ^ d[2] ^ d[1] ^ c[0] ^ c[2];
            calculate_CRCout = CRC;
        end
    endfunction

//------------------------------------------------------------------------------
// subscriber write function
//------------------------------------------------------------------------------

    function void write(result_transaction t);
        string data_str;
        command_transaction cmd;
        result_transaction predicted;

        do
            if (!cmd_f.try_get(cmd))
                $fatal(1, "Missing command in self checker");
        while (cmd.op == rst_op);

        predicted = get_expected(cmd);

        data_str  = { cmd.convert2string(),
            " ==>  Actual " , t.convert2string(),
            "/Predicted ",predicted.convert2string()};

            if (!predicted.compare(t)) begin
                `uvm_error("SELF CHECKER", {"FAIL: ",data_str})
                tr = TEST_FAILED;
            end
            else
                `uvm_info ("SELF CHECKER", {"PASS: ", data_str}, UVM_HIGH)
    endfunction : write

//------------------------------------------------------------------------------
// report phase
//------------------------------------------------------------------------------

    function void report_phase(uvm_phase phase);
        super.report_phase(phase);
        print_test_result(tr);
    endfunction : report_phase


endclass : scoreboard
