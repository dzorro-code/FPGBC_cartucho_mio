`timescale 1ns/1ps
// FSM Moore: conserva las salidas y transiciones del diagrama corregido.
// El procesador retira MEM_RSTRB/CS al finalizar; no hay espera extra.
module control_fsm (
  input wire CLK, RST, MEM_RSTRB, CS, Z_BYTE,
  output reg LD_REG, SH_REG, RST_DP, INC_COUNT,
  output reg MEM_RBUSY, CS_CART, RE_CART
);
  localparam [3:0] INIT=0, START=1, MEM=2, WAIT1=3, WAIT2=4,
    READ3=5, WAIT4=6, LOAD=7, ADD=8, COMP=9, SHIFT=10, MEM_BUSY0=11;
  reg [3:0] state, next_state;
  always @(posedge CLK) begin
    if(RST) state <= INIT;
    else state <= next_state;
  end
  always @* begin
    LD_REG=0; SH_REG=0; RST_DP=0; INC_COUNT=0;
    MEM_RBUSY=0; CS_CART=0; RE_CART=0;
    next_state=INIT;
    case(state)
      INIT: begin
        if(MEM_RSTRB && CS) next_state=START;
        else next_state=INIT;
      end
      START: begin MEM_RBUSY=1; RST_DP=1; next_state=MEM; end
      MEM: begin MEM_RBUSY=1; next_state=WAIT1; end
      WAIT1: begin MEM_RBUSY=1; next_state=WAIT2; end
      WAIT2: begin MEM_RBUSY=1; next_state=READ3; end
      READ3: begin MEM_RBUSY=1; RE_CART=1; next_state=WAIT4; end
      WAIT4: begin MEM_RBUSY=1; RE_CART=1; next_state=LOAD; end
      LOAD: begin MEM_RBUSY=1; RE_CART=1; LD_REG=1; next_state=ADD; end
      ADD: begin MEM_RBUSY=1; INC_COUNT=1; next_state=COMP; end
      COMP: begin
        MEM_RBUSY=1;
        if(Z_BYTE) next_state=MEM_BUSY0;
        else next_state=SHIFT;
      end
      SHIFT: begin MEM_RBUSY=1; SH_REG=1; next_state=MEM; end
      MEM_BUSY0: next_state=INIT;
      default: next_state=INIT;
    endcase
  end
endmodule
