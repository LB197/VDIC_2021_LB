import alu_pkg::*;

//------------------------------------------------------------------------------
// the interface
//------------------------------------------------------------------------------

interface alu_bfm;

//------------------------------------------------------------------------------
// dut connections
//------------------------------------------------------------------------------

    bit                 clk;
    bit                 rst_n;
    bit                 sin;
    logic               sout;

//---------------------------------
// Input related variables
//---------------------------------

    bit ERR_CRC, ERR_BIT;
    bit [31:0] A_data, B_data;
    bit [2:0] errors;
    logic done;
    logic data_sent;
    logic [39:0] result;

//---------------------------------
// Output related variables
//---------------------------------

    logic [31:0] C;
    logic [7:0] ctl;

// ----------------------------------------
// clk generation
// ----------------------------------------

    initial begin : clk_gen
        clk = 0;
        forever begin : clk_frv
            #10;
            clk = ~clk;
        end
    end

//------------------------------------------------------------------------------
// local variables
//------------------------------------------------------------------------------

    operation_t op_set;
    assign op = op_set; // convert from enum to bit
    command_monitor command_monitor_h;
    result_monitor result_monitor_h;

//------------------------------------------------------------------------------
// reset task
//------------------------------------------------------------------------------
    task reset_alu();
    `ifdef DEBUG
        $display("%0t DEBUG: reset_alu", $time);
    `endif
        rst_n = 1'b0;
        @(negedge clk);
        rst_n = 1'b1;
        sin = 1'b1;
    endtask

//---------------------------------

    task send_packet(packet_type_t packet_type, input bit [7:0] input_8b_data);
        integer i;
        begin
            @(negedge clk) sin = 1'b0;
            @(negedge clk) sin = packet_type;
            for (i = 0; i < 8; i = i + 1)
                @(negedge clk) sin = input_8b_data[7-i];
            @(negedge clk) sin = 1'b1;
        end
    endtask : send_packet

//---------------------------------

    task send_32b_data_packet(input bit [31:0] input_32b_data, bit data_error);
        integer i;
        begin
            for (i = 0; i < (data_error ? $urandom%3 : 4); i = i + 1)
                send_packet(DATA, input_32b_data[31-8*i-:8]);
        end
    endtask : send_32b_data_packet

//---------------------------------

    task send_ctl_packet(input operation_t op_code, input bit [3:0] CRCin);
        begin
            send_packet(CTL, {1'b0, op_code, CRCin});
        end
    endtask : send_ctl_packet

//---------------------------------

    function operation_t get_op_when_error();
        bit [2:0] op_choice;
        op_choice = 2'($urandom);
        case (op_choice)
            2'b00 : return and_op;
            2'b01 : return or_op;
            2'b10 : return add_op;
            2'b11 : return sub_op;
        endcase // case (op_choice)
    endfunction : get_op_when_error

//---------------------------------
    task send_data_to_input(input bit [31:0] A, input bit [31:0] B, input operation_t op_code, input bit crc_error, input bit data_nr_error, input bit data_bit_error);
        integer bit_data_error;

        bit [31:0] A_val, B_val;
        bit [3:0] CRCin;
        bit corrupted_bit;
        corrupted_bit = $urandom%31;

        A_val = A;
        B_val = B;
        if (data_bit_error) begin
            if (1'($urandom)) A_val[corrupted_bit] = ~A_val[corrupted_bit];
            else B_val[corrupted_bit] = ~B_val[corrupted_bit];
        end

        begin
            CRCin = calculate_CRCin(A, B, op_code);
            send_32b_data_packet(B_val, data_nr_error);
            send_32b_data_packet(A_val, data_nr_error);
            if(crc_error) CRCin = CRCin ^ 4'b0001;
            send_ctl_packet(op_code, CRCin);
        end
    endtask : send_data_to_input

//-----------------------------------------------------------------------------
// CRC function for data[67:0] ,   crc[3:0]=1+x^1+x^4;
//-----------------------------------------------------------------------------

// polynomial: x^4 + x^1 + 1
// data width: 68
// convention: the first serial bit is D[67]
    function [3:0] calculate_CRCin(bit [31:0] A, bit [31:0] B, operation_t op_set);

        reg [67:0] d;
        reg [3:0] c;
        reg [3:0] CRC;
        begin
            d = {B, A, 1'b1, op_set};
            c = 4'b0000;

            CRC[0] = d[66] ^ d[64] ^ d[63] ^ d[60] ^ d[56] ^ d[55] ^ d[54] ^ d[53] ^ d[51] ^ d[49] ^ d[48] ^ d[45] ^ d[41] ^ d[40] ^ d[39] ^ d[38] ^ d[36] ^ d[34] ^ d[33] ^ d[30] ^ d[26] ^ d[25] ^ d[24] ^ d[23] ^ d[21] ^ d[19] ^ d[18] ^ d[15] ^ d[11] ^ d[10] ^ d[9] ^ d[8] ^ d[6] ^ d[4] ^ d[3] ^ d[0] ^ c[0] ^ c[2];
            CRC[1] = d[67] ^ d[66] ^ d[65] ^ d[63] ^ d[61] ^ d[60] ^ d[57] ^ d[53] ^ d[52] ^ d[51] ^ d[50] ^ d[48] ^ d[46] ^ d[45] ^ d[42] ^ d[38] ^ d[37] ^ d[36] ^ d[35] ^ d[33] ^ d[31] ^ d[30] ^ d[27] ^ d[23] ^ d[22] ^ d[21] ^ d[20] ^ d[18] ^ d[16] ^ d[15] ^ d[12] ^ d[8] ^ d[7] ^ d[6] ^ d[5] ^ d[3] ^ d[1] ^ d[0] ^ c[1] ^ c[2] ^ c[3];
            CRC[2] = d[67] ^ d[66] ^ d[64] ^ d[62] ^ d[61] ^ d[58] ^ d[54] ^ d[53] ^ d[52] ^ d[51] ^ d[49] ^ d[47] ^ d[46] ^ d[43] ^ d[39] ^ d[38] ^ d[37] ^ d[36] ^ d[34] ^ d[32] ^ d[31] ^ d[28] ^ d[24] ^ d[23] ^ d[22] ^ d[21] ^ d[19] ^ d[17] ^ d[16] ^ d[13] ^ d[9] ^ d[8] ^ d[7] ^ d[6] ^ d[4] ^ d[2] ^ d[1] ^ c[0] ^ c[2] ^ c[3];
            CRC[3] = d[67] ^ d[65] ^ d[63] ^ d[62] ^ d[59] ^ d[55] ^ d[54] ^ d[53] ^ d[52] ^ d[50] ^ d[48] ^ d[47] ^ d[44] ^ d[40] ^ d[39] ^ d[38] ^ d[37] ^ d[35] ^ d[33] ^ d[32] ^ d[29] ^ d[25] ^ d[24] ^ d[23] ^ d[22] ^ d[20] ^ d[18] ^ d[17] ^ d[14] ^ d[10] ^ d[9] ^ d[8] ^ d[7] ^ d[5] ^ d[3] ^ d[2] ^ c[1] ^ c[3];
            calculate_CRCin = CRC;
        end
    endfunction

//------------------------------------------------------------------------------
// xD
//------------------------------------------------------------------------------

    task read_packet (output logic [7:0] output_8b_data, output packet_type_t packet_type);
        integer i;
        begin
            wait(sout == 1'b0);
            @(negedge clk);
            @(negedge clk) packet_type = packet_type_t'(sout);
            for (i = 0; i < 8; i = i + 1)
                @(negedge clk) output_8b_data[7 - i] = sout;
            wait(sout == 1'b1);
        end

    endtask : read_packet

    task read_data_from_output(output logic [31:0] C, output logic [7:0] ctl, output logic done);
        integer i;
        logic [7:0] data_out[5];
        packet_type_t data_type[5];

        begin
            done = 1'b0;
            read_packet(data_out[0], data_type[0]);
            case (data_type[0])
                DATA: begin// no_error
                    for (i = 1; i < 5; i = i + 1)
                        read_packet(data_out[i], data_type[i]);
                    C = {data_out[0], data_out[1], data_out[2], data_out[3]};
                    ctl = data_out[4][7:0];
                end
                CTL: begin// error
                    ctl = data_out[0][7:0];
                end
            endcase
            done = 1'b1;
        end
    endtask : read_data_from_output


//------------------------------------------------------------------------------
// xD
//------------------------------------------------------------------------------

    task send_op(input bit[31:0] iA_data, input bit [31:0] iB_data, input operation_t iop, output logic [39:0] alu_result);
        op_set = iop;
        A_data = iA_data;
        B_data = iB_data;

        ERR_CRC  =  1'b0;
        ERR_BIT  =  1'b0;
        data_sent = 1'b0;
        case (op_set)
            3'b111: begin : rst_op
                reset_alu();
            end
            3'b010 : begin : case_wrong_op
                send_data_to_input(iA_data, iB_data, op_set, 1'b0, 1'b0, 1'b0);
            end : case_wrong_op
                3'b011 : begin : case_wrong_crc
                ERR_CRC = 1'($urandom);
                ERR_BIT = !ERR_CRC;
                send_data_to_input(iA_data, iB_data, get_op_when_error(), ERR_CRC, 1'b0, ERR_BIT);
            end : case_wrong_crc
                3'b110 : begin : case_wrong_ctl
                send_data_to_input(iA_data, iB_data, get_op_when_error(), 1'b0, 1'b1, 1'b0);
            end : case_wrong_ctl
                default: begin : case_default
                send_data_to_input(iA_data, iB_data, op_set, 1'b0, 1'b0, 1'b0);
            end : case_default
        endcase

        data_sent = 1'b1;
        done = 1'b0;
        if(op_set != 3'b111) begin
            read_data_from_output(C, ctl, done);
            alu_result[39:8] = C;
            alu_result[7:0] = ctl;            
            result = alu_result;
        end
        #10;
    endtask : send_op

//------------------------------------------------------------------------------
// convert binary op code to enum
//------------------------------------------------------------------------------

    function operation_t op2enum(operation_t op_set);
        operation_t opi;
        if( ! $cast(opi,op_set) )
            $fatal(1, "Illegal operation on op bus");
        return opi;
    endfunction : op2enum

//    function operation_t op2enum();
//        case (op)
//            3'b000 : return and_op;
//            3'b001 : return or_op;
//            3'b010 : return add_op;
//            3'b011 : return sub_op;
//            3'b100 : return op_cor;
//            3'b101 : return crc_cor;
//            3'b110 : return ctl_cor;
//            3'b111 : return rst_op;
//            default : $fatal(1, "Illegal operation on op bus");
//        endcase // case (op)
//    endfunction : op2enum



//------------------------------------------------------------------------------
// write command monitor
//------------------------------------------------------------------------------

    initial begin : op_monitor
        command_transaction command;
        forever begin : self_checker
            @(negedge data_sent);
            command_monitor_h.write_to_monitor(A_data, B_data, op2enum(op_set));
        end : self_checker

    end : op_monitor


    always @(negedge rst_n) begin : rst_monitor
        command_transaction command;
        if (command_monitor_h != null) //guard against VCS time 0 negedge
            command_monitor_h.write_to_monitor(32'($random),0,rst_op);
    end : rst_monitor

    initial begin : result_monitor_thread
        forever begin : result_monitor
            @(posedge done) ;
            result_monitor_h.write_to_monitor(result, op_set);
        end : result_monitor
    end : result_monitor_thread

endinterface : alu_bfm