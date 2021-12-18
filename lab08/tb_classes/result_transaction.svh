class result_transaction extends uvm_transaction;

//------------------------------------------------------------------------------
// transaction variables
//------------------------------------------------------------------------------

    bit [39:0] result;
    bit [7:0] result_ctl;
    operation_t op;

//------------------------------------------------------------------------------
// constructor
//------------------------------------------------------------------------------

    function new(string name = "");
        super.new(name);
    endfunction : new
//------------------------------------------------------------------------------
// transaction functions: do_copy, do_compare, convert2string
//------------------------------------------------------------------------------

    extern function void do_copy(uvm_object rhs);
    extern function bit do_compare(uvm_object rhs, uvm_comparer comparer);
    extern function string convert2string();

endclass : result_transaction
//------------------------------------------------------------------------------



    function void result_transaction::do_copy(uvm_object rhs);
        result_transaction copied_transaction_h;
        assert(rhs != null) else
            `uvm_fatal("RESULT TRANSACTION","Tried to copy null transaction");
        super.do_copy(rhs);
        assert($cast(copied_transaction_h,rhs)) else
            `uvm_fatal("RESULT TRANSACTION","Failed cast in do_copy");
        op = copied_transaction_h.op;
        result = copied_transaction_h.result;
        result_ctl = copied_transaction_h.result[7:0];
    endfunction : do_copy

    function string result_transaction::convert2string();
        string s;
        s = $sformatf("result: %10h",result);
        return s;
    endfunction : convert2string

    function bit result_transaction::do_compare(uvm_object rhs, uvm_comparer comparer);
        result_transaction RHS;
        bit same;

        assert(rhs != null) else
            `uvm_fatal("RESULT TRANSACTION","Tried to compare null transaction");
        same = super.do_compare(rhs, comparer);
        $cast(RHS, rhs);

        if((RHS.op == and_op) || (RHS.op == or_op) || (RHS.op == add_op) || (RHS.op == sub_op)) begin
            same = (result == RHS.result) && same;
            return same;
        end else if ((RHS.op == op_cor) || (RHS.op == crc_cor) || (RHS.op == ctl_cor)) begin
            same = (result_ctl == RHS.result_ctl) && same;
            return same;
        end else return 0;
    endfunction : do_compare
