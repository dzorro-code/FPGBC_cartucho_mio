#!/usr/bin/env python3
"""Verifica la temporización real de la primera lectura en el VCD ejecutado."""
from pathlib import Path

vcd = Path(__file__).with_name('arreglobitscpu.vcd')
scopes = []
names = {}
values = {}
frames = []
time = 0
in_header = True
for raw in vcd.read_text().splitlines():
    line = raw.strip()
    if in_header:
        parts = line.split()
        if line.startswith('$scope'):
            scopes.append(parts[2])
        elif line.startswith('$upscope'):
            scopes.pop()
        elif line.startswith('$var'):
            names['.'.join(scopes + [parts[4]])] = parts[3]
        elif line.startswith('$enddefinitions'):
            in_header = False
        continue
    if line.startswith('#'):
        frames.append((time, values.copy()))
        time = int(line[1:])
    elif line.startswith('b'):
        value, code = line[1:].split()
        values[code] = value
    elif line and line[0] in '01xz':
        values[line[1:]] = line[0]
frames.append((time, values.copy()))

def read(frame, name):
    raw = frame.get(names[name], 'x')
    return None if any(x in raw for x in 'xz') else int(raw, 2)

state_name = 'tb_arreglobitscpu.dut.control.state'
state_changes = []
last = None
for t, frame in frames:
    state = read(frame, state_name)
    if state is not None and state != last:
        state_changes.append((t, state, frame))
        last = state
start = next(i for i, (_, state, _) in enumerate(state_changes) if state == 2)
seq = state_changes[start:start + 7]
assert [s for _, s, _ in seq] == [2, 3, 4, 5, 6, 7, 8]
t0 = seq[0][0]
assert [t-t0 for t, _, _ in seq] == [0, 10000, 20000, 30000, 40000, 50000, 60000]
assert [read(f, 'tb_arreglobitscpu.RE_CART') for _, _, f in seq] == [0, 0, 0, 1, 1, 1, 0]
assert read(seq[5][2], 'tb_arreglobitscpu.dut.LD_REG') == 1
assert read(seq[5][2], 'tb_arreglobitscpu.DATA_P') == 0
assert read(seq[6][2], 'tb_arreglobitscpu.DATA_P') == 0x12
assert len({read(f, 'tb_arreglobitscpu.DIR_MEM_OUT') for _, _, f in seq}) == 1
capture = next(f for t, f in frames if t == t0 + 55000)
assert read(capture, 'tb_arreglobitscpu.CLK') == 0
assert read(capture, state_name) == 7
assert read(capture, 'tb_arreglobitscpu.RE_CART') == 1
assert read(capture, 'tb_arreglobitscpu.dut.LD_REG') == 1
assert read(capture, 'tb_arreglobitscpu.DATA_P') == 0x12
assert read(capture, 'tb_arreglobitscpu.DIR_MEM_OUT') == read(seq[0][2], 'tb_arreglobitscpu.DIR_MEM_OUT')
for signal, clock_level in [('tb_arreglobitscpu.DATA_P', 0),
                            ('tb_arreglobitscpu.dut.BYTE_COUNT', 0),
                            (state_name, 1)]:
    previous = None
    for _, frame in frames:
        value = read(frame, signal)
        if value is not None and value != previous:
            assert read(frame, 'tb_arreglobitscpu.CLK') == clock_level, signal
        previous = value
print('PASS VCD: FSM posedge; datapath negedge; RE a +3 CLK; LD a +5 CLK; captura a +5.5 CLK dentro de LOAD; direccion estable.')
