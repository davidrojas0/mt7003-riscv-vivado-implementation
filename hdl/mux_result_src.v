`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: mux_result_src
// Descripción: Multiplexor combinacional 3 a 1 de 32 bits que selecciona la fuente
//              del resultado final del procesador (salida registrada de ALU,
//              dato leído de memoria registrado o salida combinacional directa
//              de la ALU) según el código de control ResultSrc.
//////////////////////////////////////////////////////////////////////////////////

module mux_result_src (
    input  wire [31:0] in_reg_alu,
    input  wire [31:0] in_reg_datos,
    input  wire [31:0] in_alu,
    input  wire [1:0]  ResultSrc,
    output reg  [31:0] out_result
);

    always @(*) begin
        case (ResultSrc)
            2'b00:   out_result = in_reg_alu;
            2'b01:   out_result = in_reg_datos;
            2'b10:   out_result = in_alu;
            default: out_result = 32'h0000_0000;
        endcase
    end

endmodule