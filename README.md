# Tensor Processing Unit
Replicating the Google TPU v1 paper on a small scale in SystemVerilog. 
It is a 4 × 4 systolic array of multiply-accumulate (MAC) cells, plus a tiny buffer for inputs and a FIFO for weights. A one row 32 bit Accumulator. The test feeds two 4 × 4 matrices into the array and checks that the bottom row of the result matches a software calculation satisying 4x4 Matrix Multiplication. 
