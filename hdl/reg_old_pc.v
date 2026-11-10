`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: reg_old_pc
// Descripción: Registro secuencial síncrono de 32 bits con reinicio activo en alto (rst).
//              Retiene la dirección de memoria de la instrucción actual (OldPC)
//              capturando el valor entregado por el PC durante la etapa de Fetch.
//////////////////////////////////////////////////////////////////////////////////

module reg_old_pc (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] in_pc,
    output reg  [31:0] out_old_pc
);

    always @(posedge clk) begin
        if (rst) begin
            out_old_pc <= 32'h0000_0000;
        end else begin
            out_old_pc <= in_pc;
        end
    end

endmodule