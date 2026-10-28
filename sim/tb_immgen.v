`timescale 1ns/1ps
//==============================================================================
// Testbench : tb_immgen   (Generador de Inmediatos / Unidad de Signo)
// Proyecto  : Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// OBJETIVO
//   Verificar los cinco formatos de inmediato (I, S, B, U, J) con la extensión
//   de signo, usando las instrucciones reales del programa de prueba. Los
//   valores esperados se tomaron del desensamblado (pm_ev_objdump_main.txt).
//
// ESTÍMULOS: instrucción completa (se pasan los bits [31:7]) + imm_src
//   I : fe010113 addi sp,sp,-32      -> -32          (0xFFFFFFE0)
//       00179793 slli a5,a5,1        -> 1
//       00f7f793 andi a5,a5,15       -> 15
//       fe842783 lw   a5,-24(s0)     -> -24          (0xFFFFFFE8)
//   S : 00112e23 sw ra,28(sp)        -> 28
//       fef401a3 sb a5,-29(s0)       -> -29          (0xFFFFFFE3)
//   B : 00079863 bnez a5,+16         -> 16
//       fce7d0e3 bge a5,a4,-64       -> -64          (0xFFFFFFC0)
//   U : 0000c7b7 lui a5,0xc          -> 0x0000C000
//       un lui con bit de signo      -> 0x80000000
//   J : 03c0006f j +60               -> 60
//       01c0006f j +28               -> 28
//       salto hacia atrás (jal -8)   -> -8           (0xFFFFFFF8)
//   imm_src inválido (101)           -> 0
//
// RESULTADOS ESPERADOS: cada imm coincide con el valor indicado.
//==============================================================================
module tb_immgen;

    reg  [31:0] instr;
    reg  [2:0]  imm_src;
    wire [31:0] imm;
    integer     errors = 0;

    immgen dut (.instr(instr[31:7]), .imm_src(imm_src), .imm(imm));

    task check;
        input [8*20-1:0] name;
        input [31:0] i;
        input [2:0]  s;
        input [31:0] expected;
        begin
            instr = i; imm_src = s;
            #1;
            if (imm !== expected) begin
                $display("  FAIL %0s: instr=0x%08h -> imm=0x%08h (esperado 0x%08h)", name, i, imm, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // Tipo I
        check("I addi -32",   32'hfe010113, 3'b000, 32'hFFFFFFE0);
        check("I slli 1",     32'h00179793, 3'b000, 32'h00000001);
        check("I andi 15",    32'h00f7f793, 3'b000, 32'h0000000F);
        check("I lw -24",     32'hfe842783, 3'b000, 32'hFFFFFFE8);
        // Tipo S
        check("S sw 28",      32'h00112e23, 3'b001, 32'h0000001C);
        check("S sb -29",     32'hfef401a3, 3'b001, 32'hFFFFFFE3);
        // Tipo B
        check("B bnez +16",   32'h00079863, 3'b010, 32'h00000010);
        check("B bge -64",    32'hfce7d0e3, 3'b010, 32'hFFFFFFC0);
        // Tipo U
        check("U lui 0xc",    32'h0000c7b7, 3'b011, 32'h0000C000);
        check("U lui signo",  32'h800007b7, 3'b011, 32'h80000000);
        // Tipo J
        check("J +60",        32'h03c0006f, 3'b100, 32'h0000003C);
        check("J +28",        32'h01c0006f, 3'b100, 32'h0000001C);
        check("J -8",         32'hff9ff06f, 3'b100, 32'hFFFFFFF8);
        // Código inválido
        check("imm_src 101",  32'hffffffff, 3'b101, 32'h00000000);

        if (errors == 0) $display("RESULTADO: PASS  (tb_immgen)");
        else             $display("RESULTADO: FAIL  (tb_immgen: %0d errores)", errors);
        $finish;
    end

endmodule
