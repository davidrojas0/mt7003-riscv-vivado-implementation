`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: reg_a
// Descripción: Registro secuencial síncrono de 32 bits con reinicio activo en alto (rst).
//              Almacena el valor leído del primer puerto del Banco de Registros
//              (Read_Data_1 / rs1) durante la etapa de decodificación (Decode),
//              estabilizando el operando A para el multiplexor ALUSrcA y la ALU.
//////////////////////////////////////////////////////////////////////////////////

module reg_a (
    input  wire        clk,
    input  wire        rst,
    input  wire [31:0] in_read_data_1,
    output reg  [31:0] out_a
);

    always @(posedge clk) begin
        if (rst) begin
            out_a <= 32'h0000_0000;
        end else begin
            out_a <= in_read_data_1;
        end
    end

endmodule