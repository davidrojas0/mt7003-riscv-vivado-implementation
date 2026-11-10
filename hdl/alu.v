`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: alu
// Descripción: Lógica combinacional para la ejecución de operaciones aritméticas
//              (ADD, SUB), lógicas (AND), de desplazamiento (SLL) y pasaje directo
//              (PASS-B). Genera las banderas de condición Zero y GE (comparación
//              con signo SrcA >= SrcB) para el procesador multiciclo RV32I.
//////////////////////////////////////////////////////////////////////////////////

module alu (
    input  wire [31:0] SrcA,
    input  wire [31:0] SrcB,
    input  wire [2:0]  ALUControl,
    output reg  [31:0] ALUResult,
    output wire        Zero,
    output wire        GE
);

    always @(*) begin
        case (ALUControl)
            3'b000:  ALUResult = SrcA + SrcB;               // ADD
            3'b001:  ALUResult = SrcA - SrcB;               // SUB
            3'b010:  ALUResult = SrcA & SrcB;               // AND
            3'b011:  ALUResult = SrcA << SrcB[4:0];         // SLL (Shift Left Logical)
            3'b100:  ALUResult = SrcB;                      // PASS-B (LUI)
            default: ALUResult = 32'h0000_0000;
        endcase
    end

    // Bandera de cero: se activa si el resultado es exactamente cero
    assign Zero = (ALUResult == 32'd0);

    // Bandera de mayor o igual: comparación con signo (SrcA >= SrcB)
    assign GE   = ($signed(SrcA) >= $signed(SrcB));

endmodule