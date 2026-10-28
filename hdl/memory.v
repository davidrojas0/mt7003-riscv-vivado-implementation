`timescale 1ns/1ps
//==============================================================================
// Módulo : memory  (Memoria única de instrucciones y datos)
// Proyecto: Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// Funcionalidad:
//   RAM de 2^ADDR_BITS palabras de 32 bits compartida entre instrucciones y
//   datos (como en el diagrama multiciclo v2). Lectura asíncrona de una palabra
//   completa; escritura síncrona (flanco positivo) de palabra (sw) o de un
//   solo byte (sb).
//
// Entradas:
//   clk
//   mem_write         MemWrite: habilita la escritura
//   byte_write        ByteWrite: 1 = escribe solo write_data[7:0] (sb);
//                                0 = escribe la palabra completa (sw)
//   addr       [31:0] dirección en bytes
//   write_data [31:0] dato a escribir (viene del registro B = rs2)
// Salida:
//   read_data  [31:0] palabra en la dirección addr (los 2 bits bajos se ignoran)
//
// Parámetros:
//   ADDR_BITS  cantidad de bits de índice de palabra (8 -> 256 palabras = 1 KiB)
//   INIT_FILE  archivo .mem en hexadecimal (una palabra por línea). Si es ""
//              la memoria arranca en cero.
//
// Mapa de memoria: solo se usan los bits addr[ADDR_BITS+1:2]; el resto de la
// dirección se ignora (la memoria se "repite"). Por eso la pila que arranca con
// sp = 0 -> 0xFFFFFFE0 cae en la parte alta de la memoria (0x3E0 con 1 KiB) y
// el programa en la parte baja, sin necesidad de inicializar sp.
//
// Dump de memoria: la tarea dump escribe un archivo con una línea por palabra:
//     <dirección en hex> <valor en hex>      p. ej.  0x3e0 0x62000000
// Si only_nonzero = 1 omite las palabras en cero.
//
// Razón de existir: el enunciado exige memoria de datos/instrucciones y poder
// volcar su contenido a un archivo para revisarlo.
//==============================================================================
module memory #(
    parameter ADDR_BITS = 8,
    parameter INIT_FILE = "instrucciones_main.mem"
) (
    input  wire        clk,
    input  wire        mem_write,
    input  wire        byte_write,
    input  wire [31:0] addr,
    input  wire [31:0] write_data,
    output wire [31:0] read_data
);

    localparam DEPTH = 1 << ADDR_BITS;

    reg [31:0] mem [0:DEPTH-1];
    reg [31:0] tmp;
    integer    i;

    wire [ADDR_BITS-1:0] word_idx = addr[ADDR_BITS+1:2];

    // Lectura asíncrona
    assign read_data = mem[word_idx];

    // Contenido inicial: ceros y luego el programa
    initial begin
        for (i = 0; i < DEPTH; i = i + 1)
            mem[i] = 32'd0;
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, mem);
    end

    // Escritura síncrona de palabra o de byte
    always @(posedge clk) begin
        if (mem_write) begin
            if (byte_write) begin
                tmp = mem[word_idx];
                case (addr[1:0])
                    2'd0: tmp[7:0]   = write_data[7:0];
                    2'd1: tmp[15:8]  = write_data[7:0];
                    2'd2: tmp[23:16] = write_data[7:0];
                    2'd3: tmp[31:24] = write_data[7:0];
                endcase
                mem[word_idx] <= tmp;
            end else begin
                mem[word_idx] <= write_data;
            end
        end
    end

    // Volcado de memoria a archivo de texto
    task dump;
        input [8*128-1:0] filename;
        input             only_nonzero;
        integer fd;
        integer k;
        begin
            fd = $fopen(filename, "w");
            for (k = 0; k < DEPTH; k = k + 1) begin
                if (!only_nonzero || mem[k] != 32'd0)
                    $fdisplay(fd, "0x%0h 0x%08h", k * 4, mem[k]);
            end
            $fclose(fd);
        end
    endtask

endmodule
