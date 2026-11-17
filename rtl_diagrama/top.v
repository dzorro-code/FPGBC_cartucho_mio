`timescale 1ns/1ps
// Diagrama: ../arreglobitscpu_corregido.drawio.
// RE y RE_CART son alias para conservar ambos nombres del dibujo/interfaz.
module arreglobitscpu (
  input wire CLK, RST, MEM_RSTRB,
  input wire [15:0] DIR_MEM_IN,
  input wire CS,
  input wire [7:0] DATA_C,
  output wire MEM_RBUSY,
  output wire [31:0] DATA_P,
  output wire [15:0] DIR_MEM_OUT,
  output wire CS_CART, RE_CART, RE
);
  wire LD_REG, SH_REG, RST_DP, INC_COUNT;
  wire [2:0] BYTE_COUNT;
  wire Z_BYTE;
  // RSTCOUNT es el nombre del borrado del contador en el datapath.
  // La salida RST_DP de START borra tanto el contador como rcv-data.
  wire RSTCOUNT = RST | RST_DP;
  wire [13:0] byte_address;

  control_fsm control (
    .CLK(CLK), .RST(RST), .MEM_RSTRB(MEM_RSTRB), .CS(CS), .Z_BYTE(Z_BYTE),
    .LD_REG(LD_REG), .SH_REG(SH_REG), .RST_DP(RST_DP), .INC_COUNT(INC_COUNT),
    .MEM_RBUSY(MEM_RBUSY), .CS_CART(CS_CART), .RE_CART(RE_CART)
  );
  rcv_data_register receive_register (
    .CLK(CLK), .RST(RSTCOUNT), .LD(LD_REG), .SHIFT(SH_REG),
    .DATA_C(DATA_C), .DATA_P(DATA_P)
  );
  byte_counter counter (
    .CLK(CLK), .RST(RSTCOUNT), .INC(INC_COUNT), .BYTE_COUNT(BYTE_COUNT)
  );
  byte_comparator comparator (.BYTE_COUNT(BYTE_COUNT), .Z_BYTE(Z_BYTE));
  address_generator address (
    .DIR_MEM_IN(DIR_MEM_IN[13:2]), .BYTE_COUNT(BYTE_COUNT[1:0]),
    .DIR_MEM_OUT(byte_address)
  );
  // La concatenación literal del dibujo tiene 14 bits; la interfaz externa
  // está rotulada de 16 bits. Extensión explícita, no suma de direcciones.
  assign DIR_MEM_OUT = {2'b00, byte_address};
  assign RE = RE_CART;
endmodule
