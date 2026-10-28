# Especificación — Microarquitectura RV32I Multiciclo

**MT-7003 Microprocesadores y Microcontroladores · TEC · Grupo N° 3 · II Semestre 2026**

Este documento es la fuente de verdad del diseño: el código de `hdl/` y los testbenches de `sim/` se generaron a partir de él y de `docs/circuito_multiciclo_v2.png`. Si algo cambia en el hardware, se cambia primero aquí.

## 1. Alcance

Procesador RV32I **multiciclo** con memoria unificada (instrucciones + datos) que ejecuta el programa `src/pm_ev_grupos_6_estudiantes.c` (31 instrucciones en `sim/instrucciones_main.mem`). El módulo superior solo tiene como entradas `clk` y `rst` (requisito del enunciado); la salida `halted` es solo informativa.

### 1.1 Instrucciones soportadas

| Tipo | Instr. | Opcode | funct3 | funct7 | Operación |
|:--|:--|:--|:--|:--|:--|
| I | `addi` | 0010011 | 000 | — | rd ← rs1 + imm |
| I | `slli` | 0010011 | 001 | 0000000 | rd ← rs1 << imm[4:0] |
| I | `andi` | 0010011 | 111 | — | rd ← rs1 & imm |
| I | `lw` | 0000011 | 010 | — | rd ← Mem[rs1 + imm] |
| S | `sw` | 0100011 | 010 | — | Mem[rs1 + imm] ← rs2 |
| S | `sb` | 0100011 | 000 | — | Mem[rs1 + imm][7:0] ← rs2[7:0] |
| U | `lui` | 0110111 | — | — | rd ← imm[31:12] << 12 |
| B | `bne` | 1100011 | 001 | — | si rs1 ≠ rs2: PC ← PC + imm |
| B | `bge` | 1100011 | 101 | — | si rs1 ≥ rs2 (con signo): PC ← PC + imm |
| J | `jal` | 1101111 | — | — | rd ← PC + 4; PC ← PC + imm |

Pseudoinstrucciones: `li` = `addi`, `j` = `jal x0`, `bnez` = `bne rs,x0`. Extra gratis por el mismo hardware: `beq` (000) y `blt` (100).

**Instrucción ilegal** (opcode o funct no soportado, incluida la palabra `0x00000000` que sigue al programa): la FSM pasa a `HALT` y se queda ahí hasta un `rst`. `slli` con funct7 ≠ 0 también es ilegal.

## 2. Módulos (`hdl/`)

| Módulo | Archivo | Función | Puertos |
|:--|:--|:--|:--|
| `alu` | alu.v | Operaciones aritmético-lógicas | `a,b[31:0]`, `alu_ctrl[2:0]` → `result[31:0]`, `zero` |
| `register_en` | register_en.v | Registro con enable y reset síncrono (PC, OldPC, Instr, Data, A, B, ALUOut) | `clk,rst,en,d[W-1:0]` → `q` |
| `regfile` | regfile.v | 32×32, 2 lecturas asíncronas, 1 escritura síncrona, x0 = 0 | `clk,rst,we,a1,a2,a3,wd3` → `rd1,rd2` |
| `immgen` | immgen.v | Unidad de signo: extrae y extiende el inmediato | `instr[24:0]` (=Instr[31:7]), `imm_src[2:0]` → `imm` |
| `memory` | memory.v | Memoria unificada, lectura asíncrona, escritura de palabra o byte, `task dump` | `clk,mem_write,byte_write,addr,write_data` → `read_data` |
| `pc_write_logic` | pc_write_logic.v | Decide si se escribe el PC | `pc_update,branch,branch_inv,zero` → `pc_write` |
| `control_fsm` | control_fsm.v | Unidad de control (FSM Moore) | `clk,rst,opcode,funct3,funct7` → señales de control, `halted` |
| `datapath` | datapath.v | Ruta de datos completa (registros, muxes, ALU, memoria) | señales de control → `opcode,funct3,funct7,zero` |
| `riscv_multiciclo` | riscv_multiciclo.v | **Top**: FSM + PC Write Logic + datapath | `clk, rst` → `halted` |

### 2.1 Códigos

**ALU (`alu_ctrl`)**: 000 ADD · 001 SUB · 010 AND · 011 OR · 100 SLL · 101 SLT (con signo) · 110/111 → 0. `zero = (result == 0)`.

**ImmGen (`imm_src`)**: 000 I · 001 S · 010 B · 011 U · 100 J. Se deduce solo del opcode.

**ALUSrcA**: 00 PC · 01 OldPC · 10 A · 11 **cero**.  **ALUSrcB**: 00 B · 01 Inmediato · 10 constante 4 · 11 cero.

**ResultSrc**: 00 ALUOut · 01 Data · 10 ALUResult (directo, sin registrar).  **AdrSrc**: 0 PC · 1 Result.

### 2.2 Memoria

- Palabras de 32 bits, `2^ADDR_BITS` palabras (por defecto 256 = 1 KiB). Se indexa con `addr[ADDR_BITS+1:2]`, así que las direcciones **envuelven** (wrap-around).
- Se inicializa en cero y luego se carga `INIT_FILE` con `$readmemh`.
- Programa en las palabras 0–30. La pila arranca con `sp = 0`; el prólogo `addi sp,sp,-32` da `sp = 0xFFFFFFE0`, que envuelve al índice 248 (byte 0x3E0). Por eso **no se necesita inicializar sp**.
- `dump(nombre, solo_no_ceros)` escribe líneas `0x<dirección> 0x<dato>` (dirección de byte, hex en minúsculas).

## 3. FSM de control

Estados (Moore). `imm_src` se calcula del opcode, fuera de la tabla.

| Estado | Acción | Señales activas |
|:--|:--|:--|
| FETCH | Instr ← Mem[PC]; OldPC ← PC; PC ← PC+4 | IRWrite, PCUpdate, ALUSrcA=00, ALUSrcB=10, ALU=ADD, ResultSrc=10 |
| DECODE | A ← rs1; B ← rs2; ALUOut ← OldPC + imm | ALUSrcA=01, ALUSrcB=01 |
| MEMADR | ALUOut ← A + imm | ALUSrcA=10, ALUSrcB=01 |
| MEMREAD | Data ← Mem[ALUOut] | AdrSrc=1 |
| MEMWB | rd ← Data | ResultSrc=01, RegWrite |
| MEMWRITE | Mem[ALUOut] ← B | AdrSrc=1, MemWrite, ByteWrite (si `sb`) |
| EXEC_I | ALUOut ← A op imm | ALUSrcA=10, ALUSrcB=01, ALU según funct3 (001 SLL, 111 AND, otro ADD) |
| EXEC_LUI | ALUOut ← 0 + imm | ALUSrcA=11, ALUSrcB=01 |
| ALUWB | rd ← ALUOut | ResultSrc=00, RegWrite |
| BRANCH | Compara A con B; si se cumple PC ← ALUOut | ALUSrcA=10, ALUSrcB=00, Branch, ALU = (funct3[2] ? SLT : SUB), BranchInv = funct3[0]^funct3[2] |
| JAL1 | PC ← ALUOut (destino) | PCUpdate, ResultSrc=00 |
| JAL2 | rd ← OldPC + 4 | ALUSrcA=01, ALUSrcB=10, ResultSrc=10, RegWrite |
| HALT | No hace nada hasta `rst` | `halted = 1` |

**PC Write Logic**: `PCWrite = PCUpdate | (Branch & (Zero ^ BranchInv))`.
- `bne`: SUB, BranchInv=1 → salta si A−B ≠ 0.
- `bge`: SLT (A<B), BranchInv=0 → salta si el resultado es 0, o sea A ≥ B.

### Secuencias y ciclos

| Instrucción | Estados | Ciclos |
|:--|:--|:-:|
| addi, slli, andi | FETCH, DECODE, EXEC_I, ALUWB | 4 |
| lui | FETCH, DECODE, EXEC_LUI, ALUWB | 4 |
| lw | FETCH, DECODE, MEMADR, MEMREAD, MEMWB | 5 |
| sw, sb | FETCH, DECODE, MEMADR, MEMWRITE | 4 |
| bne, bge | FETCH, DECODE, BRANCH | 3 |
| jal | FETCH, DECODE, JAL1, JAL2 | 4 |

El programa completo ejecuta 42 instrucciones en **172 ciclos**; el procesador se detiene (`halted`) tras **174 ciclos** desde que se suelta el reset (2 más por el FETCH/DECODE de la palabra ilegal en 0x7C).

## 4. Diferencias con el diagrama `circuito_multiciclo_v2.png`

Estos cambios ya están dibujados en `docs/circuito_multiciclo_v3.png`.

| Cambio | Motivo |
|:--|:--|
| 4ª entrada de ALUSrcA = **0** | En `lui` los bits rs1 de la instrucción son parte del inmediato; sumar A daría un resultado incorrecto. |
| Señal **BranchInv** hacia PC Write Logic | `bne` (salta con Zero=0) y `bge` (salta con SLT=0) necesitan polaridades distintas. |
| `jal` en **dos estados** | El mux Result alimenta tanto al PC como al banco de registros; no se pueden escribir PC y rd con valores distintos en el mismo ciclo. |
| Estado **HALT** y salida `halted` | Detener el procesador al terminar el programa en vez de ejecutar basura. |
| **Zero** llega solo al Control de Escritura PC | La FSM no usa Zero: la decisión de salto se toma en PC Write Logic. |
| ResultSrc=10 (ALUResult directo) | Permite escribir el PC con PC+4 en FETCH sin pasar por ALUOut. |

**A confirmar con el profesor:** que una memoria unificada (como en el diagrama v2) cumple el requisito "memoria de datos / memoria de instrucciones" (4 pts cada una).

## 5. Valores esperados al finalizar el programa

| Dirección (byte) | Valor | Significado |
|:--|:--|:--|
| 0xFFFFFFE0 (idx 248) | 0x62000000 | `char a = 'b'` (byte 3) |
| 0xFFFFFFE4 | 0x0000C7DF | puntero `r` |
| 0xFFFFFFE8 | 0x00000002 | `i` |
| 0xFFFFFFEC | 0x00000002 | `b = (33 << 1) & 0xF` |
| 0xFFFFFFF8, 0xFFFFFFFC | 0 | `s0` y `ra` guardados |

Registros: `sp = 0xFFFFFFE0`, `s0 = 0`, `a4 = 2`, `a5 = 0`. Verificado con un emulador RV32 independiente en Python y con `tb_riscv_multiciclo`.

## 6. Verificación (`sim/`)

Cada testbench documenta **Objetivo / Estímulos / Resultados esperados** en su encabezado y es autoverificable (`RESULTADO: PASS/FAIL`).

| Testbench | Qué prueba |
|:--|:--|
| tb_alu | 6 operaciones, zero, desbordamiento, códigos reservados |
| tb_register_en | Reset, enable, no transparencia |
| tb_regfile | Lecturas/escrituras, x0, we=0, reset |
| tb_immgen | I, S, B, U, J con instrucciones reales del programa |
| tb_memory | Palabra, byte, wrap-around, **dump** |
| tb_pc_write_logic | 16 combinaciones |
| tb_control_fsm | Señales de cada estado de las 10 instrucciones + HALT |
| tb_datapath | addi, sw, lw con control manual |
| tb_riscv_multiciclo | Programa completo, 174 ciclos, memoria, registros, dump |

Ejecutar todo: `bash sim/run_all.sh` (requiere Icarus Verilog).

### Uso en Vivado

1. *Add Sources → Add or create design sources*: todos los `hdl/*.v`.
2. *Add or create simulation sources*: los `sim/tb_*.v` **y** `sim/instrucciones_main.mem`.
3. Seleccionar el testbench como *Top* de simulación (`tb_riscv_multiciclo` para la prueba final) y *Run Behavioral Simulation*.
4. Si el `.mem` no se encuentra, copiarlo al directorio de simulación (`<proyecto>.sim/sim_1/behav/xsim/`).
5. En la evaluación solo se cambia el archivo del programa (`INIT_FILE`); nada más del diseño.

## 7. Trazabilidad con la rúbrica

| Ítem | Dónde |
|:--|:--|
| ALU, Memoria datos/instrucciones, Unidad de signo, UC | alu.v, memory.v, immgen.v, control_fsm.v |
| Decodificaciones I, S, B, U, J | immgen.v + tb_immgen + tb_control_fsm |
| Dump de memoria | `memory.dump` + tb_memory + `sim/dump_memoria.txt` |
| Testbench por módulo documentado | `sim/tb_*.v` (encabezados) |
| Top solo con Clock y Reset | riscv_multiciclo.v |
| Bitácora | `bitacora/` y el historial de commits |
