`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: register_file_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar el acceso de lectura asíncrona dual y escritura síncrona en el banco
// de registros de 32x32 bits, verificando la escritura correcta en registros de
// propósito general (x1-x31), el aislamiento con RegWrite=0 y la protección contra
// sobreescritura del registro constante x0.
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : clk=0, RegWrite=0, Read_Reg_1=0, Read_Reg_2=1 (Lectura inicial)
// 2. t = 15 ns : RegWrite=1, Write_Reg=1, Write_Data=0x1234_5678 (Escritura en x1)
// 3. t = 30 ns : RegWrite=1, Write_Reg=0, Write_Data=0xDEAD_BEEF (Intento de escritura en x0)
// 4. t = 45 ns : RegWrite=1, Write_Reg=2, Write_Data=0xABCD_EF00, Read_Reg_1=1, Read_Reg_2=2 (Escritura en x2 y lectura dual x1/x2)
// 5. t = 600 ns : RegWrite=0, Write_Reg=3, Write_Data=0xFFFF_FFFF (Prueba con RegWrite=0)
// 6. t = 70 ns : Read_Reg_1=0, Read_Reg_2=3                     (Verificar x0 y x3 no modificado)
// 7. t = 85 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. Read_Data_1 = 0x0000_0000, Read_Data_2 = 0x0000_0000.
// 2. En t=15 ns (flanco de subida), x1 almacena 0x1234_5678.
// 3. En t=30 ns, el intento de escribir en x0 se ignora; x0 se mantiene en 0x0000_0000.
// 4. En t=55 ns, x2 almacena 0xABCD_EF00. Asíncronamente Read_Data_1=0x1234_5678 (x1) y Read_Data_2=0xABCD_EF00 (x2).
// 5. En t=60 ns, el registro x3 NO se modifica al estar RegWrite en 0.
// 6. Read_Data_1 = 0x0000_0000 (x0 retenido) y Read_Data_2 = 0x0000_0000 (x3 sin escribir).
//////////////////////////////////////////////////////////////////////////////////

module registers_tb;

    // Entradas al DUT
    reg        clk;
    reg  [4:0] Read_Reg_1;
    reg  [4:0] Read_Reg_2;
    reg  [4:0] Write_Reg;
    reg [31:0] Write_Data;
    reg        RegWrite;

    // Salidas del DUT
    wire [31:0] Read_Data_1;
    wire [31:0] Read_Data_2;

    // Instanciación del módulo bajo prueba
    registers uut (
        .clk(clk),
        .Read_Reg_1(Read_Reg_1),
        .Read_Reg_2(Read_Reg_2),
        .Write_Reg(Write_Reg),
        .Write_Data(Write_Data),
        .RegWrite(RegWrite),
        .Read_Data_1(Read_Data_1),
        .Read_Data_2(Read_Data_2)
    );

    // Generador de Reloj (Período = 10 ns)
    always #5 clk = ~clk;

    initial begin
        // 1. Inicialización de entradas
        clk        = 0;
        RegWrite   = 0;
        Read_Reg_1 = 5'd0;
        Read_Reg_2 = 5'd1;
        Write_Reg  = 5'd0;
        Write_Data = 32'h0000_0000;

        #15;
        $display("[%0t ns] Test 1 (Lectura Inicial): rs1(x0)=0x%h, rs2(x1)=0x%h", $time, Read_Data_1, Read_Data_2);

        // 2. Escritura en registro x1 (Write_Reg = 1)
        RegWrite   = 1;
        Write_Reg  = 5'd1;
        Write_Data = 32'h1234_5678;

        #10; // Flanco de subida en t=20ns
        $display("[%0t ns] Test 2 (Lectura tras escribir x1): rs2(x1)=0x%h (Esperado: 0x12345678)", $time, Read_Data_2);

        // 3. Intento de escritura en registro x0 (Write_Reg = 0)
        #5;
        Write_Reg  = 5'd0;
        Write_Data = 32'hDEAD_BEEF;

        #10; // Flanco de subida en t=30ns
        Read_Reg_1 = 5'd0;
        #2;
        $display("[%0t ns] Test 3 (Protección de x0): rs1(x0)=0x%h (Esperado: 0x00000000)", $time, Read_Data_1);

        // 4. Escritura en x2 y lectura dual simultánea (rs1=x1, rs2=x2)
        #3;
        Write_Reg  = 5'd2;
        Write_Data = 32'hABCD_EF00;

        #10; // Flanco de subida en t=40ns
        Read_Reg_1 = 5'd1;
        Read_Reg_2 = 5'd2;
        #2;
        $display("[%0t ns] Test 4 (Lectura Dual x1 y x2): rs1(x1)=0x%h (Esperado: 0x12345678), rs2(x2)=0x%h (Esperado: 0xABCDEF00)", 
                 $time, Read_Data_1, Read_Data_2);

        // 5. Deshabilitar RegWrite (RegWrite = 0) e intentar escribir en x3
        #3;
        RegWrite   = 0;
        Write_Reg  = 5'd3;
        Write_Data = 32'hFFFF_FFFF;

        #10; // Flanco de subida en t=50ns
        // 6. Verificar que x3 sigue en 0 y x0 se mantiene en 0
        Read_Reg_1 = 5'd0;
        Read_Reg_2 = 5'd3;
        #5;
        $display("[%0t ns] Test 5 (Retención RegWrite=0): rs1(x0)=0x%h (Esperado: 0x00000000), rs2(x3)=0x%h (Esperado: 0x00000000)", 
                 $time, Read_Data_1, Read_Data_2);

        #10;
        $display("--- Simulación del Módulo register_file Finalizada Exitosamente ---");
        $finish;
    end

endmodule