// Matrix multiplication Unit
// `include "tpu_config.sv"

module mmu_array #(
    parameter int N = 4,
    parameter int DW = 8,
    parameter int AW = 32
) (
    input logic clk,
    input logic valid_i, // first input

    input logic [DW-1:0] activation_rows [N],
    input logic [DW-1:0] weight_columns [N],

    output logic valid_o,
    output logic signed [AW-1:0] psum_rows [N]
);
    // 2D Arrays
    logic [DW-1:0] a_bus [N][N+1];
    logic [DW-1:0] w_bus [N+1][N];
    logic valid_bus [N][N];
    logic signed [AW-1:0] psum_bus [N][N];

    for (genvar r = 0; r < N; r++) assign a_bus[r][0] = activation_rows[r];
    for (genvar c = 0; c < N; c++) assign w_bus[0][c] = weight_columns[c];

    generate
        for (genvar i = 0; i < N; i++) begin : ROW
            for (genvar j = 0; j < N; j++) begin : COL
                logic valid_in;
                logic [DW-1:0] act_out_wire;
                logic [DW-1:0] weight_out_wire;
                logic valid_out_wire;
                logic signed [AW-1:0] psum_out_wire;
                
                // Determine valid input
                if (j == 0) begin
                    assign valid_in = valid_i;
                end else begin
                    assign valid_in = valid_bus[i][j-1];
                end
                
                // instantiate processing element MAC
                mac #(.DW(DW), .AW(AW)) mac_i (
                    .clk(clk),
                    .valid_i(valid_in),
                    .valid_o(valid_out_wire),
                    .act_in(a_bus[i][j]), 
                    .weight_in(w_bus[i][j]),
                    .act_out(act_out_wire),
                    .weight_out(weight_out_wire),
                    .psum_o(psum_out_wire)
                );
                
                // Connect outputs
                assign valid_bus[i][j] = valid_out_wire;
                assign a_bus[i][j+1] = act_out_wire;
                assign w_bus[i+1][j] = weight_out_wire;
                assign psum_bus[i][j] = psum_out_wire;
            end
        end
    endgenerate
    
    // Connect the last column psum outputs to the module output
    for (genvar i = 0; i < N; i++) begin
        assign psum_rows[i] = psum_bus[i][N-1];
    end

    assign valid_o = valid_bus[N-1][N-1];
endmodule
