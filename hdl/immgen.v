`timescale 1ns/1ps
//==============================================================================
// Módulo : immgen  (Generador de Inmediatos / Unidad de Signo)
// Proyecto: Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// Funcionalidad:
//   Reconstruye el inmediato de 32 bits (con extensión de signo) a partir de
//   los bits [31:7] de la instrucción, según el formato indicado por imm_src.
//
// Entradas:
//   instr   [24:0] Instr[31:7]  (el índice 24 corresponde al bit 31 = signo)
//   imm_src [2:0]  formato del inmediato
// Salida:
//   imm     [31:0] inmediato extendido
//
// imm_src  Formato  Instrucciones que lo usan   Armado del inmediato
//  000     I        addi, slli, andi, lw        sext(inst[31:20])
//  001     S        sw, sb                      sext(inst[31:25], inst[11:7])
//  010     B        bne, bge                    sext(inst[31], inst[7], inst[30:25], inst[11:8], 0)
//  011     U        lui                         inst[31:12] << 12
//  100     J        jal                         sext(inst[31], inst[19:12], inst[20], inst[30:21], 0)
//
// Razón de existir: cada formato RV32I guarda el inmediato en bits distintos
// (y en B/J desordenados, con el bit 0 implícito en 0). Este bloque los
// unifica para que la ALU siempre reciba un número de 32 bits.
// Nota de índices: in[k] = inst[k+7].
//==============================================================================
module immgen (
    input  wire [24:0] instr,
    input  wire [2:0]  imm_src,
    output reg  [31:0] imm
);

    always @(*) begin
        case (imm_src)
            3'b000:  imm = {{20{instr[24]}}, instr[24:13]};                                   // I
            3'b001:  imm = {{20{instr[24]}}, instr[24:18], instr[4:0]};                       // S
            3'b010:  imm = {{20{instr[24]}}, instr[0], instr[23:18], instr[4:1], 1'b0};       // B
            3'b011:  imm = {instr[24:5], 12'b0};                                              // U
            3'b100:  imm = {{12{instr[24]}}, instr[12:5], instr[13], instr[23:14], 1'b0};     // J
            default: imm = 32'd0;
        endcase
    end

endmodule
