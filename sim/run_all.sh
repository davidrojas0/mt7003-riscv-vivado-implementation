#!/bin/bash
# Compila y ejecuta todos los testbenches con Icarus Verilog.
# Uso (desde cualquier carpeta):  bash sim/run_all.sh
cd "$(dirname "$0")" || exit 1
mkdir -p build
fail=0
for tb in tb_alu tb_register_en tb_regfile tb_immgen tb_memory tb_pc_write_logic tb_control_fsm tb_datapath tb_riscv_multiciclo; do
  iverilog -g2005 -s $tb -o build/$tb ../hdl/*.v $tb.v || { echo "ERROR compilando $tb"; fail=1; continue; }
  out=$(vvp build/$tb)
  echo "$out" | grep -E "FAIL|RESULTADO"
  echo "$out" | grep -q "RESULTADO: PASS" || fail=1
done
[ $fail -eq 0 ] && echo "=== TODOS LOS TESTBENCHES PASAN ===" || echo "=== HAY FALLAS ==="
exit $fail
