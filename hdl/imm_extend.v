`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: imm_extend
// Descripción: Lógica combinacional para la extracción y extensión de signo de
//              inmediatos en la microarquitectura RV32I. Soporta los formatos
//              Tipo I, Tipo S, Tipo B, Tipo J y Tipo U.
//////////////////////////////////////////////////////////////////////////////////

module imm_extend (
    input  wire [31:7] Instr,   // Bits [31:7] de la instrucción actual
    input  wire [2:0]  ImmSrc,  // Selector de formato de inmediato
    output reg  [31:0] ImmExt   // Inmediato extendido a 32 bits
);

    always @(*) begin
        case (ImmSrc)
            // Tipo I: Inmediato de 12 bits sign-extended (addi, lw, slli, andi)
            3'b000: ImmExt = {{20{Instr[31]}}, Instr[31:20]};

            // Tipo S: Inmediato de 12 bits sign-extended (sw, sb)
            3'b001: ImmExt = {{20{Instr[31]}}, Instr[31:25], Instr[11:7]};

            // Tipo B: Offset de salto de 13 bits sign-extended con LSB=0 (bne, bge)
            3'b010: ImmExt = {{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8], 1'b0};

            // Tipo J: Offset de salto de 21 bits sign-extended con LSB=0 (jal)
            3'b011: ImmExt = {{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21], 1'b0};

            // Tipo U: Inmediato superior de 20 bits (lui)
            3'b100: ImmExt = {Instr[31:12], 12'b0000_0000_0000};

            default: ImmExt = 32'h0000_0000;
        endcase
    end

endmodule