`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: memory_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar las operaciones de lectura combinacional y escritura síncrona en la
// Memoria Unificada RAM, verificando la escritura completa de palabras de 32 bits (sw)
// y la modificación aislada de bytes individuales (sb) mediante la máscara ByteWrite.
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : clk=0, MemWrite=0, ByteWrite=4'b0000, Address=0x0000_0000, WriteData=0
// 2. t = 15 ns : MemWrite=1, ByteWrite=4'b1111, Address=0x0000_0010, WriteData=0xDEADBEEF (Prueba sw)
// 3. t = 25 ns : MemWrite=0, ByteWrite=4'b0000, Address=0x0000_0010                      (Lectura sw)
// 4. t = 40 ns : MemWrite=1, ByteWrite=4'b0001, Address=0x0000_0010, WriteData=0x0000_00AA (Prueba sb byte 0)
// 5. t = 50 ns : MemWrite=0, ByteWrite=4'b0000, Address=0x0000_0010                      (Lectura tras sb byte 0)
// 6. t = 65 ns : MemWrite=1, ByteWrite=4'b0100, Address=0x0000_0010, WriteData=0x0055_0000 (Prueba sb byte 2)
// 7. t = 75 ns : MemWrite=0, ByteWrite=4'b0000, Address=0x0000_0010                      (Lectura tras sb byte 2)
// 8. t = 90 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. ReadData = Lectura inicial en 0x0000_0000.
// 2. En t=20 ns (flanco de reloj), se escribe 0xDEADBEEF en la dirección 0x0000_0010.
// 3. ReadData = 0xDEADBEEF (Palabra completa guardada por sw).
// 4. En t=40 ns, sólo el byte 0 [7:0] es modificado por 0xAA.
// 5. ReadData = 0xDEADBEAA (Mantiene 0xDEADBE intacto).
// 6. En t=70 ns, sólo el byte 2 [23:16] es modificado por 0x55.
// 7. ReadData = 0xDE55BEAA (Modificación aislada de byte sin alterar el resto).
//////////////////////////////////////////////////////////////////////////////////

module memory_tb;

    // Entradas al DUT
    reg        clk;
    reg [31:0] Address;
    reg [31:0] WriteData;
    reg        MemWrite;
    reg [3:0]  ByteWrite;

    // Salida del DUT
    wire [31:0] ReadData;

    // Instanciación del módulo bajo prueba
    memory #(
        .DEPTH(256)
    ) uut (
        .clk(clk),
        .Address(Address),
        .WriteData(WriteData),
        .MemWrite(MemWrite),
        .ByteWrite(ByteWrite),
        .ReadData(ReadData)
    );

    // Generador de Reloj (Período = 10 ns)
    always #5 clk = ~clk;

    initial begin
        // 1. Inicialización
        clk       = 1;
        Address   = 32'h0000_0000;
        WriteData = 32'h0000_0000;
        MemWrite  = 0;
        ByteWrite = 4'b0000;

        #15;
        $display("[%0t ns] Test 1 (Lectura Inicial en 0x0): ReadData = 0x%h", $time, ReadData);

        // 2. Escritura completa de palabra (sw) en dirección 0x10
        Address   = 32'h0000_0010;
        WriteData = 32'hDEADBEEF;
        MemWrite  = 1;
        ByteWrite = 4'b1111;

        #10; // Pasa el posedge en t=20ns
        // 3. Pasar a lectura para verificar sw
        MemWrite  = 0;
        ByteWrite = 4'b0000;
        #5;
        $display("[%0t ns] Test 2 (Lectura tras sw): ReadData = 0x%h (Esperado: 0xDEADBEEF)", $time, ReadData);

        // 4. Escritura de Byte 0 (sb) en dirección 0x10 (Sobrescribir 0xEF por 0xAA)
        #10;
        WriteData = 32'h0000_00AA;
        MemWrite  = 1;
        ByteWrite = 4'b0001; // Solo byte 0

        #10; // Pasa el posedge en t=40ns
        // 5. Pasar a lectura
        MemWrite  = 0;
        ByteWrite = 4'b0000;
        #5;
        $display("[%0t ns] Test 3 (Lectura tras sb byte 0): ReadData = 0x%h (Esperado: 0xDEADBEAA)", $time, ReadData);

        // 6. Escritura de Byte 2 (sb) en dirección 0x10 (Sobrescribir 0xAD por 0x55)
        #10;
        WriteData = 32'h0055_0000;
        MemWrite  = 1;
        ByteWrite = 4'b0100; // Solo byte 2

        #10; // Pasa el posedge en t=60ns
        // 7. Pasar a lectura
        MemWrite  = 0;
        ByteWrite = 4'b0000;
        #5;
        $display("[%0t ns] Test 4 (Lectura tras sb byte 2): ReadData = 0x%h (Esperado: 0xDE55BEAA)", $time, ReadData);

        #10;
        $display("--- Simulación del Módulo memory Finalizada Exitosamente ---");
        $finish;
    end

endmodule