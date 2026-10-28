`timescale 1ns/1ps
//==============================================================================
// Testbench : tb_pc_write_logic
// Proyecto  : Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// OBJETIVO
//   Verificar la lógica de escritura del PC:
//        pc_write = pc_update | (branch & (zero ^ branch_inv))
//
// ESTÍMULOS: las 16 combinaciones de {pc_update, branch, branch_inv, zero}.
//
// RESULTADOS ESPERADOS
//   - pc_update = 1                     -> pc_write = 1 siempre (fetch, jal)
//   - branch = 0 y pc_update = 0        -> pc_write = 0
//   - branch = 1, branch_inv = 0 (beq/bge): salta si zero = 1
//   - branch = 1, branch_inv = 1 (bne/blt): salta si zero = 0
//==============================================================================
module tb_pc_write_logic;

    reg  pc_update, branch, branch_inv, zero;
    wire pc_write;
    reg  expected;
    integer i, errors = 0;

    pc_write_logic dut (.pc_update(pc_update), .branch(branch), .branch_inv(branch_inv),
                        .zero(zero), .pc_write(pc_write));

    initial begin
        for (i = 0; i < 16; i = i + 1) begin
            {pc_update, branch, branch_inv, zero} = i[3:0];
            // Tabla de verdad escrita de forma independiente de la implementación
            if (pc_update)                         expected = 1'b1;
            else if (!branch)                      expected = 1'b0;
            else if (!branch_inv)                  expected = zero;      // salta si zero
            else                                   expected = !zero;     // salta si !zero
            #1;
            if (pc_write !== expected) begin
                $display("  FAIL upd=%b br=%b inv=%b zero=%b -> pc_write=%b (esperado %b)",
                         pc_update, branch, branch_inv, zero, pc_write, expected);
                errors = errors + 1;
            end
        end
        if (errors == 0) $display("RESULTADO: PASS  (tb_pc_write_logic, 16 combinaciones)");
        else             $display("RESULTADO: FAIL  (tb_pc_write_logic: %0d errores)", errors);
        $finish;
    end

endmodule
