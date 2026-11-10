`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: memory (Memoria Unificada RAM)
// Descripción: Memoria RAM de puerto único unificada de 32 bits, organizada en
//              palabras de 32 bits con acceso alineado a byte. Permite lectura
//              asíncrona y escritura síncrona habilitada por byte (ByteWrite).
//////////////////////////////////////////////////////////////////////////////////

module memory #(
    parameter DEPTH = 256  // Número de palabras de 32 bits (1024 bytes)
)(
    input  wire        clk,        // Reloj principal (escrituras en flanco de subida)
    input  wire [31:0] Address,    // Dirección física de 32 bits
    input  wire [31:0] WriteData,  // Dato de 32 bits a escribir (desde registro B)
    input  wire        MemWrite,   // Habilitador global de escritura (1 = Write, 0 = Read)
    input  wire [3:0]  ByteWrite,  // Habilitadores de carril por byte [3:0]
    output wire [31:0] ReadData    // Palabra de 32 bits leída
);

    // Arreglo de memoria RAM de DEPTH palabras x 32 bits
    reg [31:0] ram [0:DEPTH-1];
    
    // Carga inicial del archivo de instrucciones en hexadecimal
    initial begin
        $readmemh("instr_main.mem", ram);
    end

    // Alineación a nivel de palabra de 32 bits (dirección dividida entre 4)
    wire [7:0] word_idx = Address[9:2];

    // Lectura Combinacional / Asíncrona
    assign ReadData = ram[word_idx];

    // Escritura Síncrona con Habilitación Selectiva por Byte
    always @(posedge clk) begin
        if (MemWrite) begin
            if (ByteWrite == 4'b1111) begin
                // sw: Escritura de palabra completa (32 bits directos)
                ram[word_idx] <= WriteData;
            end 
            else begin
                // sb: Escritura de byte individual (toma WriteData[7:0] para el carril activo)
                if (ByteWrite[0]) ram[word_idx][7:0]   <= WriteData[7:0];
                if (ByteWrite[1]) ram[word_idx][15:8]  <= WriteData[7:0];
                if (ByteWrite[2]) ram[word_idx][23:16] <= WriteData[7:0];
                if (ByteWrite[3]) ram[word_idx][31:24] <= WriteData[7:0];
            end
        end
    end

endmodule