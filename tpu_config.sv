// TPU Configuration - No package, just parameters
parameter int N = 4;
parameter int DW = 8;
parameter int AW = 32;

typedef enum logic [2:0] {
    READ_HOST_MEMORY = 3'd0,
    READ_WEIGHTS = 3'd1,
    MATRIX_MULTIPLY = 3'd2,
    WRITE_HOST_MEMORY = 3'd3
} tpu_instruction_e;
