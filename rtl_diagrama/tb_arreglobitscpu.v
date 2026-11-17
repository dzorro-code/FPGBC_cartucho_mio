`timescale 1ns/1ps
// Referencia de prueba independiente de los localparam del DUT.
module tb_arreglobitscpu;
  reg CLK=0, RST=1, MEM_RSTRB=0, CS=0;
  reg [15:0] DIR_MEM_IN=16'h1203;
  reg [31:0] memory_word=32'h12345678;
  wire [7:0] DATA_C;
  wire [31:0] DATA_P;
  wire [15:0] DIR_MEM_OUT;
  wire MEM_RBUSY,CS_CART,RE_CART,RE;
  integer reference_state=0, expected_next;
  integer loads=0, shifts=0, completed=0, samples=0;
  reg [31:0] reference_data=0, before_data;
  reg [2:0] reference_count=0, before_count;
  reg [3:0] before_control;
  reg [15:0] read_address;
  reg [6:0] expected_controls;
  reg monitor=1;
  localparam INIT=0,START=1,MEM=2,WAIT1=3,WAIT2=4,
    READ3=5,WAIT4=6,LOAD=7,ADD=8,COMP=9,SHIFT=10,MEM_BUSY0=11;

  arreglobitscpu dut(.CLK(CLK),.RST(RST),.MEM_RSTRB(MEM_RSTRB),
    .DIR_MEM_IN(DIR_MEM_IN),.CS(CS),.DATA_C(DATA_C),
    .MEM_RBUSY(MEM_RBUSY),.DATA_P(DATA_P),.DIR_MEM_OUT(DIR_MEM_OUT),
    .CS_CART(CS_CART),.RE_CART(RE_CART),.RE(RE));
  always #5 CLK=~CLK;
  // La memoria se organiza por byte; no depende del contador interno del DUT.
  assign DATA_C = DIR_MEM_OUT[1:0]==0 ? memory_word[31:24] :
                  DIR_MEM_OUT[1:0]==1 ? memory_word[23:16] :
                  DIR_MEM_OUT[1:0]==2 ? memory_word[15:8] : memory_word[7:0];

  // La FSM cambia en posedge; el datapath NO debe cambiar en ese flanco.
  always @(posedge CLK) begin
    if(RST) begin
      reference_state=INIT;
      #1;
      if(dut.control.state!==INIT) $fatal(1,"Reset de FSM incorrecto");
    end else if(monitor) begin
      samples=samples+1;
      case(reference_state)
        // {LD_REG,SH_REG,RST_DP,INC_COUNT,MEM_RBUSY,RE_CART,CS_CART}
        INIT,MEM_BUSY0: expected_controls=7'b0000000;
        START: expected_controls=7'b0010100;
        MEM,WAIT1,WAIT2: expected_controls=7'b0000100;
        READ3,WAIT4: expected_controls=7'b0000110;
        LOAD: expected_controls=7'b1000110;
        ADD: expected_controls=7'b0001100;
        COMP: expected_controls=7'b0000100;
        SHIFT: expected_controls=7'b0100100;
        default:$fatal(1,"Estado de referencia invalido");
      endcase
      if({dut.LD_REG,dut.SH_REG,dut.RST_DP,dut.INC_COUNT,MEM_RBUSY,RE_CART,CS_CART} !== expected_controls)
        $fatal(1,"Controles distintos del diagrama, estado %0d",reference_state);
      if(RE !== RE_CART) $fatal(1,"Alias RE incorrecto");
      if(dut.control.state !== reference_state)
        $fatal(1,"Transicion incorrecta: ref=%0d dut=%0d",reference_state,dut.control.state);
      if(DIR_MEM_OUT !== {2'b00,DIR_MEM_IN[13:2],reference_count[1:0]})
        $fatal(1,"La direccion no usa la concatenacion del diagrama");
      if(dut.Z_BYTE !== (reference_count==4)) $fatal(1,"Comparador incorrecto");
      case(reference_state)
        INIT: expected_next=(MEM_RSTRB && CS)?START:INIT;
        START: expected_next=MEM;
        MEM: begin expected_next=WAIT1;read_address=DIR_MEM_OUT;end
        WAIT1: expected_next=WAIT2;
        WAIT2: expected_next=READ3;
        READ3: expected_next=WAIT4;
        WAIT4: expected_next=LOAD;
        LOAD: expected_next=ADD;
        ADD: expected_next=COMP;
        COMP: expected_next=(reference_count==4)?MEM_BUSY0:SHIFT;
        SHIFT: expected_next=MEM;
        MEM_BUSY0: begin
          expected_next=INIT;completed=completed+1;
          if(loads!=4 || shifts!=3 || reference_data!==memory_word)
            $fatal(1,"Resultado final: cargas=%0d shifts=%0d dato=%h esperado=%h",loads,shifts,reference_data,memory_word);
        end
      endcase
      if(reference_state>=WAIT1 && reference_state<=LOAD && DIR_MEM_OUT!==read_address)
        $fatal(1,"Direccion inestable durante lectura");
      before_data=DATA_P; before_count=dut.BYTE_COUNT;
      #1;
      reference_state=expected_next;
      if(DATA_P!==before_data || dut.BYTE_COUNT!==before_count)
        $fatal(1,"El datapath cambio en posedge");
      if(dut.control.state!==expected_next) $fatal(1,"Estado siguiente incorrecto");
    end
  end

  // El datapath ejecuta las salidas del estado vigente medio ciclo despues.
  always @(negedge CLK) begin
    before_control=dut.control.state;
    if(RST) begin
      reference_data=0;reference_count=0;loads=0;shifts=0;
    end else if(monitor) begin
      case(reference_state)
        START: begin reference_data=0;reference_count=0;loads=0;shifts=0;end
        LOAD: begin
          if(RE_CART!==1 || DIR_MEM_OUT!==read_address)
            $fatal(1,"Lectura no valida en el negedge de captura");
          reference_data[7:0]=DATA_C;loads=loads+1;
        end
        ADD: reference_count=reference_count+1'b1;
        SHIFT: begin
          if(reference_count==4) $fatal(1,"SHIFT tras el cuarto byte");
          reference_data=reference_data<<8;shifts=shifts+1;
        end
      endcase
    end
    #1;
    if(RST || monitor) begin
      if(DATA_P!==reference_data || dut.BYTE_COUNT!==reference_count)
        $fatal(1,"Error datapath negedge: DATA_P=%h esperado=%h contador=%0d esperado=%0d",DATA_P,reference_data,dut.BYTE_COUNT,reference_count);
      if(dut.control.state!==before_control) $fatal(1,"La FSM cambio en negedge");
    end
  end

  task transaction;
    input [31:0] word_in;
    input [15:0] address_in;
    input early_release;
    integer before_done;
    begin
      @(negedge CLK); #2;
      memory_word=word_in;DIR_MEM_IN=address_in;
      before_done=completed;CS=1;MEM_RSTRB=1;
      wait(MEM_RBUSY===1);
      if(early_release) begin @(negedge CLK); #2;CS=0;MEM_RSTRB=0;end
      wait(MEM_RBUSY===0);
      @(negedge CLK); #2;CS=0;MEM_RSTRB=0;
      wait(completed>before_done);
      @(negedge CLK); #2;
      if(DATA_P!==word_in) $fatal(1,"Palabra final incorrecta");
    end
  endtask

  integer i,before_repeat;
  initial begin
    $dumpfile("arreglobitscpu.vcd");$dumpvars(0,tb_arreglobitscpu);
    repeat(2) @(negedge CLK); #2;RST=0;
    // Todas las combinaciones inactivas de la solicitud.
    CS=0;MEM_RSTRB=0;repeat(3)@(negedge CLK); #2;
    CS=0;MEM_RSTRB=1;repeat(3)@(negedge CLK); #2;
    CS=1;MEM_RSTRB=0;repeat(3)@(negedge CLK); #2;
    transaction(32'h12345678,16'h1203,0);
    transaction(32'hA5000000,16'h1201,0);
    transaction(32'h0000005A,16'h1202,0);
    transaction(32'h00000000,16'hFFFF,0);
    transaction(32'hFFFFFFFF,16'h0000,1);
    for(i=0;i<64;i=i+1) transaction($random,$random,i%2);
    // Una solicitud mantenida vuelve a iniciar: no se inventa un estado FINISH.
    @(negedge CLK); #2;memory_word=32'hABCDEF42;DIR_MEM_IN=16'h4203;
    before_repeat=completed;CS=1;MEM_RSTRB=1;
    wait(completed>=before_repeat+2);
    @(negedge CLK); #2;CS=0;MEM_RSTRB=0;
    repeat(3)@(negedge CLK); #2;
    // Reset durante una lectura: vuelve a INIT y borra ambos registros.
    CS=1;MEM_RSTRB=1;wait(dut.control.state==READ3);
    @(negedge CLK); #2;RST=1;CS=0;MEM_RSTRB=0;
    repeat(2)@(negedge CLK); #2;RST=0;
    transaction(32'h10203040,16'h3FFD,0);
    $display("PASS: %0d transacciones completas; %0d ciclos comprobados; FSM posedge, datapath negedge, controles por estado, concatenacion, 4 LOAD/3 SHIFT, reset, solicitudes y datos.",completed,samples);
    $finish;
  end
  initial begin #100000; $fatal(1,"Timeout");end
endmodule
