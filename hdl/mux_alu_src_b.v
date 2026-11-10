`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: mux_alu_src_b
// Descripción: Multiplexor combinacional 3 a 1 de 32 bits. Selecciona la fuente
//              del segundo operando (SrcB) enviado a la ALU: Registro B (00),
//              Inmediato Extendido (01) o Constante 4 (10).
//////////////////////////////////////////////////////////////////////////////////

module mux_alu_src_b (
    input  wire [31:0] in_reg_b,   // Dato del registro rs2 (ALUSrcB = 2'b00)
    input  wire [31:0] in_imm_ext, // Inmediato extendido de 32 bits (ALUSrcB = 2'b01)
    input  wire [31:0] in_4,       // Constante fija 4 (ALUSrcB = 2'b10)
    input  wire [1:0]  ALUSrcB,    // Selector emitido por la FSM de control
    output reg  [31:0] out_src_b   // Operando 2 listo para ingresar a la ALU
);

    always @(*) begin
        case (ALUSrcB)
            2'b00:   out_src_b = in_reg_b;
            2'b01:   out_src_b = in_imm_ext;
            2'b10:   out_src_b = in_4;
            default: out_src_b = in_4; // Cláusula default de protección
        endcase
    end

endmodule