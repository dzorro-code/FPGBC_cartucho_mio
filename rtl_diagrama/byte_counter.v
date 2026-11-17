`timescale 1ns/1ps
// Tres bits permiten representar 0,1,2,3 y el valor terminal 4.
module byte_counter (
  input wire CLK, RST, INC,
  output reg [2:0] BYTE_COUNT
);
  always @(negedge CLK) begin
    if(RST) BYTE_COUNT <= 3'b0;
    else if(INC) BYTE_COUNT <= BYTE_COUNT + 3'd1;
  end
endmodule
