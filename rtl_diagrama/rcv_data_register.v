`timescale 1ns/1ps
// Un solo registro de 32 bits, como REG rcv-data en el datapath.
module rcv_data_register (
  input wire CLK, RST, LD, SHIFT,
  input wire [7:0] DATA_C,
  output reg [31:0] DATA_P
);
  always @(negedge CLK) begin
    if(RST) DATA_P <= 32'b0;
    else if(LD) DATA_P[7:0] <= DATA_C; // conserva los 24 bits superiores
    else if(SHIFT) DATA_P <= DATA_P << 8;
  end
endmodule
