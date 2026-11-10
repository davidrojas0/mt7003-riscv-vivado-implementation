`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: imm_decoder
// Descripción: Lógica combinacional que identifica el formato de la instrucción
//              actual a partir de su código de operación (opcode) para instruir
//              al módulo imm_extend sobre cómo extraer y extender el inmediato[cite: 1].
//////////////////////////////////////////////////////////////////////////////////

module imm_decoder (
    input  wire [6:0] opcode,
    output reg  [2:0] ImmSrc
);

    always @(*) begin
        case (opcode)
            7'b0010011, // Tipo I (addi, slli, andi)
            7'b0000011: ImmSrc = 3'b000; // Tipo I (lw)
            7'b0100011: ImmSrc = 3'b001; // Tipo S (sw, sb)
            7'b1100011: ImmSrc = 3'b010; // Tipo B (bne, bge)
            7'b1101111: ImmSrc = 3'b011; // Tipo J (jal)
            7'b0110111: ImmSrc = 3'b100; // Tipo U (lui)
            default:    ImmSrc = 3'b000;
        endcase
    end

endmodule