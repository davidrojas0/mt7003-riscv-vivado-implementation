`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: mux_adr_src
// Descripción: Multiplexor combinacional 2 a 1 de 32 bits. Selecciona la fuente
//              de dirección física para la Memoria Unificada (Fetch vs Access).
//////////////////////////////////////////////////////////////////////////////////

module mux_adr_src (
    input  wire [31:0] in_pc,      // Dirección del PC (Fetch, AdrSrc = 0)
    input  wire [31:0] in_result,  // Dirección calculada (Memory Access, AdrSrc = 1)
    input  wire        AdrSrc,     // Selector emitido por la FSM de control
    output reg  [31:0] out_adr     // Dirección enviada a la RAM
);

    always @(*) begin
        case (AdrSrc)
            1'b0:    out_adr = in_pc;
            1'b1:    out_adr = in_result;
            default: out_adr = in_pc;
        endcase
    end

endmodule