`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: reg_alu_out
// Descripción: Registro secuencial síncrono de 32 bits con reinicio activo en alto (rst).
//              Almacena el resultado procesado por la ALU en la etapa de ejecución
//              (Execute), preservando la dirección calculada o el resultado
//              aritmético/lógico para las etapas posteriores de memoria o
//              reescritura (Write-Back) a través del multiplexor ResultSrc.
//////////////////////////////////////////////////////////////////////////////////

module reg_alu_out (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] in_alu_result,
    output reg  [31:0] out_alu_out
);

    always @(posedge clk) begin
        if (rst) begin
            out_alu_out <= 32'h0000_0000;
        end else begin
            out_alu_out <= in_alu_result;
        end
    end

endmodule