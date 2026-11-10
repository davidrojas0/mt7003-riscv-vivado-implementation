`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: pc (Program Counter)
// Descripción: Registro secuencial síncrono de 32 bits con habilitador de escritura
//              (PCWrite) y reset asíncrono/síncrono.
//////////////////////////////////////////////////////////////////////////////////

module pc (
    input  wire        clk,         // Reloj principal
    input  wire        rst,         // Reinicio global (Activo en '1')
    input  wire        PCWrite,     // Habilitador de escritura (Write Enable)
    input  wire [31:0] in_pc_next,  // Dirección de la siguiente instrucción
    output reg  [31:0] out_pc       // Dirección de la instrucción actual
);

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            out_pc <= 32'h0000_0000;
        end else if (PCWrite) begin
            out_pc <= in_pc_next;
        end
        // Si PCWrite == 0 y rst == 0, out_pc retiene su valor actual
    end

endmodule