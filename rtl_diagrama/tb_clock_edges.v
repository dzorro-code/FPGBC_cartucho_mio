`timescale 1ns/1ps
// Verifica flancos reales, no solo el valor final de la transaccion.
module tb_clock_edges;
  reg CLK=0, RST=1, LD=0, SHIFT=0, INC=0;
  reg [7:0] DATA_C=8'hA5;
  wire [31:0] DATA_P;
  wire [2:0] BYTE_COUNT;
  rcv_data_register data_reg(.CLK(CLK),.RST(RST),.LD(LD),.SHIFT(SHIFT),
    .DATA_C(DATA_C),.DATA_P(DATA_P));
  byte_counter counter(.CLK(CLK),.RST(RST),.INC(INC),.BYTE_COUNT(BYTE_COUNT));
  control_fsm control(.CLK(CLK),.RST(RST),.MEM_RSTRB(1'b1),.CS(1'b1),.Z_BYTE(1'b0));
  always #5 CLK=~CLK;

  initial begin
    // Mantener reset sobre ambos flancos para arrancar sin valores X.
    #12; RST=0; LD=1; INC=1;
    @(posedge CLK); #1;
    if(DATA_P!==0 || BYTE_COUNT!==0)
      $fatal(1,"El datapath actuo en posedge; debe esperar a negedge");
    if(control.state!==4'd1) $fatal(1,"La FSM no avanza en posedge");
    @(negedge CLK); #1;
    if(DATA_P!==32'h000000A5 || BYTE_COUNT!==1)
      $fatal(1,"Carga/contador no actuaron en negedge");
    if(control.state!==4'd1) $fatal(1,"La FSM cambio en negedge");
    LD=0; INC=0; SHIFT=1;
    @(posedge CLK); #1;
    if(DATA_P!==32'h000000A5 || BYTE_COUNT!==1 || control.state!==4'd2)
      $fatal(1,"Flanco incorrecto antes del desplazamiento");
    @(negedge CLK); #1;
    if(DATA_P!==32'h0000A500 || BYTE_COUNT!==1 || control.state!==4'd2)
      $fatal(1,"SHIFT no actuo exclusivamente en negedge");
    SHIFT=0; RST=1;
    @(posedge CLK); #1;
    if(control.state!==0 || DATA_P!==32'h0000A500 || BYTE_COUNT!==1)
      $fatal(1,"Reset: FSM debe usar posedge y datapath negedge");
    @(negedge CLK); #1;
    if(DATA_P!==0 || BYTE_COUNT!==0 || control.state!==0)
      $fatal(1,"Reset del datapath no actuo en negedge");
    $display("PASS flancos: FSM posedge; carga, shift, contador y reset del datapath negedge.");
    $finish;
  end
  initial begin #1000; $fatal(1,"Timeout flancos"); end
endmodule
