`timescale 1ns/1ps
//==============================================================================
// Módulo : riscv_multiciclo  (Módulo principal)
// Proyecto: Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// Funcionalidad:
//   Une la ruta de datos (datapath), la unidad de control (control_fsm) y la
//   lógica de escritura del PC (pc_write_logic). Procesador RV32I multiciclo
//   que ejecuta el subconjunto de 10 instrucciones necesario para el
//   programa en C del proyecto: addi, lw, slli, andi, sw, sb, lui, bne, bge, jal.
//
// Entradas (únicas, según el enunciado):
//   clk   reloj
//   rst   reset síncrono, activo en alto
// Salida (solo observación, no es una entrada):
//   halted  1 cuando el procesador llegó a una instrucción no soportada o
//           ilegal (por ejemplo la palabra 0x00000000 que sigue al programa).
//
// Parámetros:
//   ADDR_BITS  tamaño de la memoria (2^ADDR_BITS palabras)
//   INIT_FILE  archivo .mem con el programa (único elemento que se cambia en
//              la defensa)
//
// Razón de existir: es el nivel superior que se simula en Vivado.
//==============================================================================
module riscv_multiciclo #(
    parameter ADDR_BITS = 8,
    parameter INIT_FILE = "instrucciones_main.mem"
) (
    input  wire clk,
    input  wire rst,
    output wire halted
);

    // Señales de control
    wire        reg_write, mem_write, byte_write, ir_write, adr_src;
    wire [1:0]  alu_src_a, alu_src_b, result_src;
    wire [2:0]  alu_ctrl, imm_src;
    wire        branch, branch_inv, pc_update, pc_write;
    // Del datapath al control
    wire [6:0]  opcode, funct7;
    wire [2:0]  funct3;
    wire        zero;

    control_fsm u_ctrl (
        .clk(clk), .rst(rst),
        .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .reg_write(reg_write), .mem_write(mem_write), .byte_write(byte_write),
        .ir_write(ir_write), .adr_src(adr_src),
        .alu_src_a(alu_src_a), .alu_src_b(alu_src_b), .result_src(result_src),
        .alu_ctrl(alu_ctrl), .imm_src(imm_src),
        .branch(branch), .branch_inv(branch_inv), .pc_update(pc_update),
        .halted(halted)
    );

    pc_write_logic u_pcw (
        .pc_update(pc_update), .branch(branch), .branch_inv(branch_inv),
        .zero(zero), .pc_write(pc_write)
    );

    datapath #(.ADDR_BITS(ADDR_BITS), .INIT_FILE(INIT_FILE)) u_dp (
        .clk(clk), .rst(rst),
        .pc_write(pc_write), .ir_write(ir_write), .adr_src(adr_src),
        .mem_write(mem_write), .byte_write(byte_write), .reg_write(reg_write),
        .alu_src_a(alu_src_a), .alu_src_b(alu_src_b), .alu_ctrl(alu_ctrl),
        .imm_src(imm_src), .result_src(result_src),
        .opcode(opcode), .funct3(funct3), .funct7(funct7), .zero(zero)
    );

endmodule
