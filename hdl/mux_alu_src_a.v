`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: mux_alu_src_a
// Descripción: Multiplexor combinacional 3 a 1 de 32 bits. Selecciona la fuente
//              del primer operando (SrcA) enviado a la ALU: PC (00), OldPC (01)
//              o el registro intermedio A (10).
//////////////////////////////////////////////////////////////////////////////////

module mux_alu_src_a (
    input  wire [31:0] in_pc,      // Dirección actual del PC (ALUSrcA = 2'b00)
    input  wire [31:0] in_old_pc,  // Dirección base retenida (ALUSrcA = 2'b01)
    input  wire [31:0] in_reg_a,   // Dato leído del registro rs1 (ALUSrcA = 2'b10)
    input  wire [1:0]  ALUSrcA,    // Selector emitido por la FSM de control
    output reg  [31:0] out_src_a   // Operando 1 listo para ingresar a la ALU
);

    always @(*) begin
        case (ALUSrcA)
            2'b00:   out_src_a = in_pc;
            2'b01:   out_src_a = in_old_pc;
            2'b10:   out_src_a = in_reg_a;
            default: out_src_a = in_pc; // Cláusula default para evitar estados indeterminados
        endcase
    end

endmodule