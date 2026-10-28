`timescale 1ns/1ps
//==============================================================================
// Módulo : alu
// Proyecto: Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// Funcionalidad:
//   Unidad aritmético-lógica combinacional de 32 bits. En la microarquitectura
//   multiciclo esta única ALU se reutiliza en todos los ciclos:
//     - Fetch   : PC + 4
//     - Decode  : OldPC + inmediato (destino de saltos bne/bge/jal)
//     - Execute : operación de addi / slli / andi, dirección de lw/sw, lui
//     - Branch  : comparación de rs1 con rs2 (resta o menor-que)
//
// Entradas:
//   a        [31:0] Operando A (sale del MUX ALUSrcA)
//   b        [31:0] Operando B (sale del MUX ALUSrcB)
//   alu_ctrl [2:0]  Operación a realizar (ver tabla)
//
// Salidas:
//   result   [31:0] Resultado de la operación
//   zero            1 cuando result == 0. Se usa para decidir los saltos:
//                   - bne: SUB, salta si zero = 0 (rs1 != rs2)
//                   - bge: SLT, salta si zero = 1 (rs1 >= rs2, pues SLT = 0)
//
// Codificación de alu_ctrl:
//   000 ADD   a + b            (addi, lw, sw, lui, PC+4, destinos de salto)
//   001 SUB   a - b            (bne)
//   010 AND   a & b            (andi)
//   011 OR    a | b            (reservado, no lo usa el programa de prueba)
//   100 SLL   a << b[4:0]      (slli)
//   101 SLT   (a < b) con signo (bge)
//   110,111    reservado -> result = 0
//
// Razón de existir: el enunciado exige implementar la ALU en Verilog y es el
// único bloque que calcula; reutilizarla ahorra hardware en el multiciclo.
//==============================================================================
module alu (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  alu_ctrl,
    output reg  [31:0] result,
    output wire        zero
);

    localparam ALU_ADD = 3'b000;
    localparam ALU_SUB = 3'b001;
    localparam ALU_AND = 3'b010;
    localparam ALU_OR  = 3'b011;
    localparam ALU_SLL = 3'b100;
    localparam ALU_SLT = 3'b101;

    always @(*) begin
        case (alu_ctrl)
            ALU_ADD: result = a + b;
            ALU_SUB: result = a - b;
            ALU_AND: result = a & b;
            ALU_OR : result = a | b;
            ALU_SLL: result = a << b[4:0];
            ALU_SLT: result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);

endmodule
