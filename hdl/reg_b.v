`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: reg_b
// Descripción: Registro secuencial síncrono de 32 bits con reinicio activo en alto (rst).
//              Almacena el valor leído del segundo puerto del Banco de Registros
//              (Read_Data_2 / rs2) durante la etapa de decodificación (Decode),
//              suministrando el operando B al multiplexor ALUSrcB y el bus de
//              datos a escribir (WriteData) a la Memoria Unificada.
//////////////////////////////////////////////////////////////////////////////////

module reg_b (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] in_read_data_2,
    output reg  [31:0] out_b
);

    always @(posedge clk) begin
        if (rst) begin
            out_b <= 32'h0000_0000;
        end else begin
            out_b <= in_read_data_2;
        end
    end

endmodule