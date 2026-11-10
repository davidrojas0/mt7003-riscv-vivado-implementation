`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: alu_decoder
// Descripción: Traduce la señal genérica de 2 bits (ALUOp) emitida por la FSM
//              y el campo funct3 de la instrucción para generar el código exacto
//              (ALUControl) de 3 bits consumido por la ALU física[cite: 1].
//////////////////////////////////////////////////////////////////////////////////

module alu_decoder (
    input  wire [1:0] ALUOp,
    input  wire [2:0] funct3,
    output reg  [2:0] ALUControl
);

    always @(*) begin
        case (ALUOp)
            2'b00: ALUControl = 3'b000; // Suma (ADD) incondicional para PC, Saltos, Cargas/Almacenamientos
            2'b01: ALUControl = 3'b001; // Resta (SUB) para evaluación de condiciones
            2'b11: ALUControl = 3'b100; // Paso directo de constante superior (PASS-B)
            2'b10: begin                // Aritmética/Lógica, depende de funct3
                case (funct3)
                    3'b000:  ALUControl = 3'b000; // ADD (addi)
                    3'b111:  ALUControl = 3'b010; // AND (andi)
                    3'b001:  ALUControl = 3'b011; // SLL (slli)
                    default: ALUControl = 3'b000;
                endcase
            end
            default: ALUControl = 3'b000;
        endcase
    end

endmodule