# Verilog del diagrama corregido

Referencia: `../arreglobitscpu_corregido.drawio`, tal como estaba guardado al generar esta versión. Los Verilog antiguos de la carpeta superior se conservan; **no deben compilarse mezclados con estos**, pues comparten el nombre del módulo principal.

## Archivos e interfaces

- `top.v`: módulo principal `arreglobitscpu`; entradas `CLK`, `RST`, `MEM_RSTRB`, `DIR_MEM_IN[15:0]`, `CS`, `DATA_C[7:0]`. Salidas `MEM_RBUSY`, `DATA_P[31:0]`, `DIR_MEM_OUT[15:0]`, `CS_CART`, `RE_CART` y el alias `RE`.
- `controller.v`: `control_fsm`, con entradas independientes `CLK`, `RST`, `MEM_RSTRB`, `CS`, `Z_BYTE`; salidas `LD_REG`, `SH_REG`, `RST_DP`, `INC_COUNT`, `MEM_RBUSY`, `CS_CART`, `RE_CART`.
- `rcv_data_register.v`: el único registro `rcv-data`; entradas `CLK`, `RST`, `LD`, `SHIFT`, `DATA_C[7:0]`; salida `DATA_P[31:0]`. `LD` reemplaza solamente los bits bajos y conserva los otros 24. `SHIFT` desplaza a la izquierda 8 bits. Prioridad: reset, carga, desplazamiento.
- `byte_counter.v`: entradas `CLK`, `RST`, `INC`; salida `BYTE_COUNT[2:0]`. Hace falta representar el valor terminal 4, por eso no puede tener solo dos bits.
- `byte_comparator.v`: entrada `BYTE_COUNT[2:0]`; salida `Z_BYTE`, igual a 1 cuando el contador llega a 4.
- `address_generator.v`: entrada `DIR_MEM_IN[13:2]` (12 bits) y `BYTE_COUNT[1:0]`; salida `DIR_MEM_OUT[13:0]` (14 bits), mediante concatenación, no suma.
- `tb_arreglobitscpu.v`: testbench autocorrectivo con referencias separadas para ambos flancos y volcado VCD.
- `tb_clock_edges.v`: prueba directa de carga, desplazamiento, contador y reset en bajada, y FSM en subida.
- `verify_timing.py`: comprueba sobre el VCD la temporización efectivamente simulada.

No se añade registro temporal de byte ni contador de espera. El borrado local `RST_DP` de START se combina con el reset externo para el registro y contador. La conexión de reset del contador mantiene el nombre interno `RSTCOUNT`.

## Secuencia y controles de la FSM

| Código | Estado | LD_REG | SH_REG | RST_DP | INC_COUNT | MEM_RBUSY | RE_CART | CS_CART |
|---|---|---|---|---|---|---|---|---|
| 0 | INIT | 0 | 0 | 0 | 0 | 0 | 0 | 0 |
| 1 | START | 0 | 0 | 1 | 0 | 1 | 0 | 0 |
| 2 | MEM | 0 | 0 | 0 | 0 | 1 | 0 | 0 |
| 3 | WAIT1 | 0 | 0 | 0 | 0 | 1 | 0 | 0 |
| 4 | WAIT2 | 0 | 0 | 0 | 0 | 1 | 0 | 0 |
| 5 | READ3 | 0 | 0 | 0 | 0 | 1 | 1 | 0 |
| 6 | WAIT4 | 0 | 0 | 0 | 0 | 1 | 1 | 0 |
| 7 | LOAD | 1 | 0 | 0 | 0 | 1 | 1 | 0 |
| 8 | ADD | 0 | 0 | 0 | 1 | 1 | 0 | 0 |
| 9 | COMP | 0 | 0 | 0 | 0 | 1 | 0 | 0 |
| 10 | SHIFT | 0 | 1 | 0 | 0 | 1 | 0 | 0 |
| 11 | MEM_BUSY0 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

```text
INIT --(MEM_RSTRB && CS)--> START --> MEM
MEM --> WAIT1 --> WAIT2 --> READ3 --> WAIT4 --> LOAD --> ADD --> COMP
COMP --(Z_BYTE=0)--> SHIFT --> MEM
COMP --(Z_BYTE=1)--> MEM_BUSY0 --> INIT
```

No hay estado `RE0`, ni espera adicional por liberación de solicitud. El procesador debe retirar la solicitud al finalizar, como se acordó. Si la mantiene, la FSM inicia otra transacción al volver a INIT. Si la retira durante una lectura ya aceptada, la operación continúa hasta completar los cuatro bytes.

`CS_CART=0` en todos los estados, exactamente como está en la FSM dibujada. El código no presupone ni cambia su polaridad eléctrica; cualquier adaptación al cartucho físico debe respetar la interfaz de la placa.

## Dirección: decisión explícita para los anchos del dibujo

El dibujo externo etiqueta buses de 16 bits, pero la concatenación interna literal contiene 14. Esta versión conserva ambas cosas así:

```verilog
DIR_MEM_OUT = {2'b00, DIR_MEM_IN[13:2], BYTE_COUNT[1:0]};
```

Se ignoran los bits `[1:0]` de entrada, tal como se pidió; **también se descartan `[15:14]`**, porque no aparecen en la concatenación del dibujo. Esto restringe las direcciones efectivas a 14 bits. No se cambió silenciosamente a `[15:2]`. Si esos dos bits superiores son necesarios para el sistema, hay que corregir ese ancho en el diseño y ampliar el concatenador.

No se registra la dirección base: el procesador debe mantener `DIR_MEM_IN` estable durante toda la transacción.

## Temporización real (FSM Moore)

Con `t0` en el flanco que entra a MEM y establece su etapa de dirección:

- `t0+1 CLK`: entra a WAIT1.
- `t0+2 CLK`: entra a WAIT2.
- `t0+3 CLK`: entra a READ3 y sube `RE_CART`.
- `t0+4 CLK`: entra a WAIT4; `RE_CART` sigue alto.
- `t0+5 CLK`: entra a LOAD y sube `LD_REG`.
- `t0+5.5 CLK`: **el registro captura `DATA_C` en el flanco de bajada dentro de LOAD**, mientras `RE_CART` sigue alto.
- `t0+6 CLK`: entra a ADD y baja `RE_CART`; el dato ya está capturado.

La FSM conserva `posedge CLK`. Los elementos secuenciales del datapath (`rcv_data_register` y `byte_counter`) usan **`negedge CLK`**, incluido su reset síncrono. El comparador y el concatenador de direcciones siguen siendo combinacionales: no se les añaden registros. Las señales de control se establecen en el flanco de subida y el datapath las ejecuta medio ciclo después. Este cambio adelanta la captura medio ciclo respecto a la versión anterior, que capturaba al salir de LOAD. `verify_timing.py` comprueba los flancos en el VCD ejecutado.

En ADD se incrementa el contador en el flanco de bajada dentro del estado; COMP compara el valor ya actualizado. SHIFT también desplaza en bajada. Se realizan 4 cargas y 3 desplazamientos: `12 34 56 78` produce `32'h12345678`.

La nueva temporización está comprobada en simulación; el camino FSM→datapath y el retorno datapath→FSM disponen de medio periodo cada uno y requieren verificación de timing antes de uso físico. No se modificó el archivo Draw.io ni se actualizó automáticamente la copia del RTL integrada en `digital_UN/Litex/cartridge/rtl_diagrama/`.

## Ejecutar las pruebas

Desde esta carpeta, el comando siguiente compila, simula, valida el VCD y ejecuta Yosys si está disponible:

```bash
bash run_tests.sh
```

Las salidas quedan en `build/simulation.log`, `build/yosys.log` y `arreglobitscpu.vcd`. Las pruebas comprueban controles por estado, secuencia de direcciones con bits bajos ignorados, cuatro cargas/tres desplazamientos, patrones distintos y aleatorios, reinicio entre operaciones, reset durante una lectura, solicitud retirada y solicitud mantenida.

## Ver ondas en GTKWave

Este comando abre el VCD con las señales ya seleccionadas:

```bash
gtkwave arreglobitscpu.vcd arreglobitscpu.gtkw
```

El código de estado de la tabla anterior permite identificar cada etapa en `dut.control.state`. El reset es síncrono, activo en alto, y debe aplicarse al arrancar.

Esto está probado en simulación RTL y revisado estructuralmente; no se ha programado ni probado una FPGA física.
