// Tests

`timescale 1ns/1ps // time scale derivative unit/precsision
// `include "tpu_config.sv"
// `include "tpu.sv"

module mat_mul_tests;
    //  4x4 test vectors
    byte A [N][N] = '{{1, 2, 3, 4}, '{5, 6, 7, 8}, '{9, 10, 11, 12}, {13, 14, 15, 16}};
    byte B [N][N] = '{{1, 1, 1, 1}, '{2, 2, 2, 2}, '{3, 3, 3, 3}, {4, 4, 4, 4}};
    
    logic host_instruction_valid = 0;
    logic [31:0] host_instruction = 0;
    logic host_instruction_ready;
    logic [DW-1:0] host_write_data = 0;
    logic host_wdata_valid = 0;
    logic [11:0] host_write_address = 0;
    logic mmu_done;

    logic clk = 0, reset_n = 0;
    always #5 clk = ~clk; // 5 units
    
    // Declare loop variables at module level for iverilog
    integer i, j, k, col, index;

    tpu dut (
        .clk(clk),
        .reset_n(reset_n),
        .host_instruction_valid(host_instruction_valid),
        .host_instruction(host_instruction),
        .host_instruction_ready(host_instruction_ready),  
        .host_write_data(host_write_data),
        .host_wdata_valid(host_wdata_valid),
        .host_write_address(host_write_address),
        .mmu_done(mmu_done)
    );

    int golden [N][N]; // verification nomenclature sort of like golden std
    int got [N]; // output received

    initial begin
        repeat (3) @(posedge clk); // wait 3 clock cycles
        reset_n = 1;
        push_weights();
        push_activations();
        matmul();

        repeat (N*3) @(posedge clk); // wait for comuptation
        
        for (col = 0; col < N; col++)
            got[col] = dut.acc_row[col];
        calculate_golden();
        result();
        $finish; // terminate simulation entirely
    end

        
    // Helper fns
    task push_weights();
        host_issue_opcode(READ_WEIGHTS, 0);
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++)
                host_write_weights(B[i][j]);
    endtask

    task push_activations();
        host_issue_opcode(READ_HOST_MEMORY, 0);
        index = 0;
        for (i = 0; i < N; i++)
            for (j = 0; j < N; j++) begin
                host_write_ub(index, A[i][j]);
                index = index + 1;
            end
    endtask

    task matmul();
        host_issue_opcode(MATRIX_MULTIPLY, 0);
    endtask

    task calculate_golden();
        for (i = 0; i < N; i++) begin
            for (j = 0; j < N; j++) begin
                golden[i][j] = 0;
                for (k = 0; k < N; k++)
                    golden[i][j] += A[i][k] * B[k][j];
            end
        end
    endtask

    task result();
        // Accuulator only stores the bottom row of partial sums hence we test row 3
        $display("DUT row 3: %0d %0d %0d %0d", got[0], got[1], got[2], got[3]);
        $display("REF row 3: %0d %0d %0d %0d", golden[3][0], golden[3][1], golden[3][2], golden[3][3]);
        for (col = 0; col < N; col++) assert (got[col] == golden[3][col]) else $fatal("Mismatch col %0d", col);
        $display("PASS");
    endtask

    task host_write_weights(input byte data);
        @(posedge clk);
        host_wdata_valid <= 1;
        host_write_data <= data;
        @(posedge clk);
        host_wdata_valid <= 0;
    endtask

    task host_write_ub(input int address, input byte data);
        @(posedge clk);
        host_wdata_valid <= 1;
        host_write_data <= data;
        host_write_address <= address;
        @(posedge clk);
        host_wdata_valid <= 0;
    endtask

    task host_issue_opcode(input tpu_instruction_e opcode, input [28:0] imm);
        @(posedge clk);
        host_instruction_valid <= 1;
        host_instruction <= {opcode, imm};
        @(posedge clk);
        host_instruction_valid <= 0;
    endtask 
endmodule
