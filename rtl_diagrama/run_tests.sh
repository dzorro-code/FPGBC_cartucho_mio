#!/usr/bin/env bash
# Simulación autocontenida y comprobación estructural; no programa la FPGA.
set -euo pipefail
cd -- "$(dirname -- "$0")"
mkdir -p build
sources=(top.v controller.v rcv_data_register.v byte_counter.v byte_comparator.v address_generator.v)
iverilog -g2012 -Wall -s tb_arreglobitscpu -o build/sim.out "${sources[@]}" tb_arreglobitscpu.v
vvp build/sim.out | tee build/simulation.log
iverilog -g2012 -Wall -s tb_clock_edges -o build/clock_edges.out "${sources[@]}" tb_clock_edges.v
vvp build/clock_edges.out | tee build/clock_edges.log
python3 verify_timing.py
if command -v yosys >/dev/null 2>&1; then
  yosys -Q -T -p "read_verilog ${sources[*]}; hierarchy -check -top arreglobitscpu; proc; check" > build/yosys.log
  python3 - <<'PY'
from pathlib import Path
s=Path('build/yosys.log').read_text()
assert 'Found and reported 0 problems.' in s
print('PASS Yosys: 0 problemas estructurales.')
PY
else
  printf '%s\n' 'Yosys no está instalado: se omitió la comprobación estructural.'
fi
