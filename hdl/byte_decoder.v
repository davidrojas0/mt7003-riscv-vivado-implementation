`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: byte_decoder
// Descripción: Lógica combinacional que genera el bus ByteWrite de 4 bits
//              requerido por la RAM para ejecutar escrituras completas de
//              palabras (sw) o aislar bytes específicos (sb) dependiendo
//              de los bits de alineación de memoria address[1:0][cite: 1].
//////////////////////////////////////////////////////////////////////////////////

module byte_decoder (
    input  wire       MemWrite,
    input  wire [2:0] funct3,
    input  wire [1:0] addr_low,
    output reg  [3:0] ByteWrite
);

    always @(*) begin
        if (!MemWrite) begin
            ByteWrite = 4'b0000; // Bloquea escritura por completo
        end else begin
            case (funct3)
                3'b010: ByteWrite = 4'b1111; // Palabra completa (sw)
                3'b000: begin                // Byte aislado (sb)
                    case (addr_low)
                        2'b00:   ByteWrite = 4'b0001;
                        2'b01:   ByteWrite = 4'b0010;
                        2'b10:   ByteWrite = 4'b0100;
                        2'b11:   ByteWrite = 4'b1000;
                        default: ByteWrite = 4'b0001;
                    endcase
                end
                default: ByteWrite = 4'b1111;
            endcase
        end
    end

endmodule