`timescale 1ns/1ps
// Puerto de 12 bits indexado igual que el dibujo: DIR_MEM_IN[13:2].
module address_generator (
  input wire [13:2] DIR_MEM_IN,
  input wire [1:0] BYTE_COUNT,
  output wire [13:0] DIR_MEM_OUT
);
  assign DIR_MEM_OUT = {DIR_MEM_IN, BYTE_COUNT};
endmodule
