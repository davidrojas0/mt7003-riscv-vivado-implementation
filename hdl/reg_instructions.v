`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: reg_instructions
// Descripción: Registro secuencial síncrono de 32 bits con habilitador de escritura
//              (IRWrite) y reinicio activo en alto (rst). Almacena la palabra de
//              instrucción de 32 bits leída desde la memoria durante la etapa de
//              Fetch y la retiene inmune a cambios durante los demás ciclos.
//              Bajo reset (rst=1'b1), se reinicia al valor de la instrucción NOP
//              (32'h0000_0013 / addi x0, x0, 0).
//////////////////////////////////////////////////////////////////////////////////

module reg_instructions (
    input  wire        clk,
    input  wire        rst,
    input  wire        IRWrite,
    input  wire [31:0] in_instruction,
    output reg  [31:0] out_instruction
);

    always @(posedge clk) begin
        if (rst) begin
            out_instruction <= 32'h0000_0013; // NOP (addi x0, x0, 0)
        end else if (IRWrite) begin
            out_instruction <= in_instruction;
        end
    end

endmodule