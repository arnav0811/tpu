// MAC unit / processing element
// `include "tpu_config.sv"

module mac #(
    parameter int DW = 8,
    parameter int AW = 32
) (
    input logic clk, // clock
    input logic [DW-1:0] act_in, // Activation from Unified Buffer
    input logic [DW-1:0] weight_in, // Weight from Weight FIFO
    output logic [DW-1:0] act_out, // Moves down to next processing element
    output logic [DW-1:0] weight_out, // mOves right to next processing element

    input logic valid_i, // if clock cycle carries data
    output logic valid_o, // one cycle delay

    output logic signed [AW-1:0] psum_o // Partial Sum

);

    // Sending operand down and right (systolic)
    // a path -> act_in -> cycle delay -> act_out moving north to south
    // w path -> weight_in -> cycle delay -> weight_out moving west to east
    logic [DW-1:0] a_q, w_q; // registers
    always_ff @(posedge clk) begin
        a_q <= act_in;
        w_q <= weight_in;
    end
    assign act_out = a_q;
    assign weight_out = w_q;

    // MAC logic 
    logic signed [AW-1:0] acc_r; // runnign partial sum
    always_ff @(posedge clk) begin
        valid_o <= valid_i;
        if (valid_i) 
            acc_r <= acc_r + $signed(act_in) * $signed(weight_in);
        else
            acc_r <= '0;
    end
    assign psum_o = acc_r;
endmodule