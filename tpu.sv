// TPU
// Unified buffer is 256x8
// Weight FIFO is 8-bit
// Accumulator is 1 32-bit row

// `include "tpu_config.sv"

module tpu (
    input logic clk,
    input logic reset_n,

    input logic host_instruction_valid,
    input logic [31:0] host_instruction,
    output logic host_instruction_ready,

    input logic [DW-1:0] host_write_data,
    input logic host_wdata_valid,
    input logic [11:0] host_write_address,

    output logic mmu_done
);

    // Instriction Buffer
    tpu_instruction_e ib_opcode;
    logic [28:0] ib_imm;
    logic ib_full;

    assign host_instruction_ready = ~ib_full;

    always_ff @(posedge clk or negedge reset_n) begin
        if (!reset_n) ib_full <= 0;
        else if (host_instruction_valid && host_instruction_ready) begin
            {ib_opcode, ib_imm} <= host_instruction;
            ib_full <= 1;
        end
        else if (ib_full && mmu_done) begin // clears instruction buffer
            ib_full <= 0;
        end
    end

    // Unified Buffer 256x8
    logic [DW-1:0] ub_mem [256];
    logic [7:0] ub_read_address;
    logic [DW-1:0] ub_read_data;

    always_ff @(posedge clk) begin
        if (host_wdata_valid && ib_opcode==READ_HOST_MEMORY)
            ub_mem[host_write_address[7:0]] <= host_write_data;
        ub_read_data <= ub_mem[ub_read_address];
    end

    // Weight FIFO 8
    logic [DW-1:0] wfifo_mem [8];
    logic [2:0] wf_write, wf_read, wf_used;
    logic [DW-1:0] wfifo_data_out;

    // push form host when opcode == READ_WEIGHTS
    always_ff @(posedge clk) if (host_wdata_valid && ib_opcode==READ_WEIGHTS) begin
        wfifo_mem[wf_write] <= host_write_data;
        wf_write <= wf_write + 1;
        wf_used <= wf_used + 1;
    end

    // Pop one word per cycle when MMU active
    always_ff @(posedge clk) if (wf_used != 0 && mmu_active) begin
        wfifo_data_out <= wfifo_mem[wf_read];
        wf_read <= wf_read + 1;
        wf_used <= wf_used - 1;
    end

    // Matrix Multiply Unit MMU
    logic mmu_active;
    logic mmu_valid_input;
    logic mmu_valid_output;
    logic signed [AW-1:0] psum_row [N];

    assign mmu_active = (ib_opcode == MATRIX_MULTIPLY);
    assign mmu_valid_input = mmu_active;

    mmu_array u_mmu (
        .clk(clk),
        .valid_i (mmu_valid_input),
        .activation_rows ( '{ub_read_data, ub_read_data, ub_read_data, ub_read_data}),
        .weight_columns ( '{wfifo_data_out, wfifo_data_out, wfifo_data_out, wfifo_data_out}),
        .valid_o (mmu_valid_output),
        .psum_rows (psum_row)
    );

    assign mmu_done = mmu_valid_output;

    // Accumulator 32-bit row
    logic signed [AW-1:0] acc_row [N];

    always_ff @(posedge clk)
        if (mmu_valid_output) 
            for (int i = 0; i < N; i++) acc_row[i] <= psum_row[i];

endmodule



    

