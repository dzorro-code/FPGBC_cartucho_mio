`timescale 1ns/1ps
module byte_comparator (
  input wire [2:0] BYTE_COUNT,
  output wire Z_BYTE
);
  assign Z_BYTE = (BYTE_COUNT == 3'd4);
endmodule
