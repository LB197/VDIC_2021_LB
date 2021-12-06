class scoreboard extends uvm_subscriber #(bit[39:0]);
    `uvm_component_utils(scoreboard)

    virtual alu_bfm bfm;
    uvm_tlm_analysis_fifo #(command_s) cmd_f;

    function new (string name, uvm_component parent);
        super.new(name, parent);
    endfunction : new

    function void build_phase(uvm_phase phase);
        cmd_f = new ("cmd_f", this);
    endfunction : build_phase

    bit [31:0] Cexp;
    bit [7:0] ctl_exp;

    function void get_expected(command_s cmd);

        bit Carry, Overflow, Negative, Zero, parity;
        bit [32:0] Cext;
        bit [3:0]   flags_exp;
        bit [2:0]   CRCexp;
        bit [5:0]   error_flags;

        Carry =     1'b0;
        Overflow =  1'b0;
        Negative =  1'b0;
        Zero =      1'b0;
        Cext =      0;
  `ifdef DEBUG
        $display("%0t DEBUG: get_expected(%0d,%0d,%0d)",$time, A_data, B_data, op_set);
  `endif

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
        end else if ((cmd.op == op_cor) || (cmd.op == crc_cor) || (cmd.op == ctl_cor)) begin
            parity = (1'b1 ^ error_flags[5] ^ error_flags[4] ^ error_flags[3] ^ error_flags[2] ^ error_flags[1] ^ error_flags[0]);
            ctl_exp = {1'b1, error_flags, parity};
        end
    endfunction

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

    function void write(bit [39:0] t);

        command_s cmd;
        cmd.A  = 0;
        cmd.B  = 0;
        cmd.op = rst_op;
        do
            if (!cmd_f.try_get(cmd))
                $fatal(1, "Missing command in self checker");
            
        while (cmd.op == rst_op);
        get_expected(cmd);

        if(((cmd.op == crc_cor) || (cmd.op == ctl_cor) || (cmd.op == op_cor)) && (ctl_exp === t[7:0])) begin
     `ifdef DEBUG
            $display("%0t Test passed with correct error frame", $time);
     `endif
        end else assert (( Cexp === t[39:8]) && (ctl_exp === t[7:0])) begin
            
     `ifdef DEBUG
                $display("%0t Test passed with correct data for A=%0d B=%0d op_set=%0d", $time, cmd.A, cmd.B, cmd.op);
     `endif
            end else begin
                $fatal(1, "%0t Test FAILED for A=%0d B=%0d op_set=%0d\nExpected: %d  received: %d ctl_exp: %b, ctl: %b",
                    $time, cmd.A, cmd.B, cmd.op , Cexp, t[39:8], ctl_exp, t[7:0]);
            end;

    endfunction : write

endclass : scoreboard
