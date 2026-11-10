`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: reg_data
// Descripción: Registro secuencial síncrono de 32 bits con reinicio activo en alto (rst).
//              Captura de la Memoria Unificada la palabra de datos leída durante
//              la etapa de acceso a memoria (Memory) y la aísla para la etapa
//              de Reescritura (Write-Back) a través del multiplexor ResultSrc.
//////////////////////////////////////////////////////////////////////////////////

module reg_datos (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] in_read_data,
    output reg  [31:0] out_data
);

    always @(posedge clk) begin
        if (rst) begin
            out_data <= 32'h0000_0000;
        end else begin
            out_data <= in_read_data;
        end
    end

endmodule