`timescale 1ns/1ps
//==============================================================================
// Módulo : regfile
// Proyecto: Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// Funcionalidad:
//   Banco de 32 registros de 32 bits (x0..x31) con dos puertos de lectura
//   asíncronos y un puerto de escritura síncrono (flanco positivo).
//   x0 vale siempre 0: se lee como 0 y cualquier escritura en x0 se ignora.
//
// Entradas:
//   clk, rst (síncrono, pone todos los registros en 0)
//   we          RegWrite: habilita la escritura
//   a1 [4:0]    rs1 = Instr[19:15]
//   a2 [4:0]    rs2 = Instr[24:20]
//   a3 [4:0]    rd  = Instr[11:7]
//   wd3 [31:0]  dato a escribir en rd (sale del MUX ResultSrc)
// Salidas:
//   rd1, rd2 [31:0]  contenido de rs1 y rs2
//
// Razón de existir: almacena los registros visibles al programa (sp, ra, s0,
// a4, a5...). El reset a 0 hace que el programa de prueba arranque con
// sp = 0, ra = 0 y s0 = 0, que es lo que supone el resultado esperado.
//==============================================================================
module regfile (
    input  wire        clk,
    input  wire        rst,
    input  wire        we,
    input  wire [4:0]  a1,
    input  wire [4:0]  a2,
    input  wire [4:0]  a3,
    input  wire [31:0] wd3,
    output wire [31:0] rd1,
    output wire [31:0] rd2
);

    reg [31:0] regs [0:31];
    integer i;

    // Lecturas asíncronas; x0 se fuerza a 0
    assign rd1 = (a1 == 5'd0) ? 32'd0 : regs[a1];
    assign rd2 = (a2 == 5'd0) ? 32'd0 : regs[a2];

    always @(posedge clk) begin
        if (rst) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 32'd0;
        end else if (we && (a3 != 5'd0)) begin
            regs[a3] <= wd3;
        end
    end

endmodule
