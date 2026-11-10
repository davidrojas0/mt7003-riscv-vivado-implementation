`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: register_file
// Descripción: Banco de 32 registros de 32 bits (x0-x31).
//              Lectura asíncrona de 2 puertos y escritura síncrona de 1 puerto.
//              El registro x0 está permanentemente enlazado a cero (32'h00000000).
//////////////////////////////////////////////////////////////////////////////////

module registers (
    input  wire        clk,          // Reloj principal
    input  wire [4:0]  Read_Reg_1,   // Dirección del registro fuente 1 (rs1)
    input  wire [4:0]  Read_Reg_2,   // Dirección del registro fuente 2 (rs2)
    input  wire [4:0]  Write_Reg,    // Dirección del registro destino (rd)
    input  wire [31:0] Write_Data,   // Dato de 32 bits a escribir en rd
    input  wire        RegWrite,     // Habilitador de escritura (Write Enable)
    output wire [31:0] Read_Data_1,  // Contenido leído de rs1
    output wire [31:0] Read_Data_2   // Contenido leído de rs2
);

    // Arreglo interno de 32 registros de 32 bits
    reg [31:0] regs [0:31];

    // Inicialización del arreglo a 0 para simulación
    integer i;
    initial begin
        for (i = 0; i < 32; i = i + 1) begin
            regs[i] = 32'h0000_0000;
        end
    end

    // Lectura Combinacional / Asíncrona con protección de x0
    assign Read_Data_1 = (Read_Reg_1 == 5'd0) ? 32'h0000_0000 : regs[Read_Reg_1];
    assign Read_Data_2 = (Read_Reg_2 == 5'd0) ? 32'h0000_0000 : regs[Read_Reg_2];

    // Escritura Síncrona en flanco de subida (descarta escrituras en x0)
    always @(posedge clk) begin
        if (RegWrite && (Write_Reg != 5'd0)) begin
            regs[Write_Reg] <= Write_Data;
        end
    end

endmodule