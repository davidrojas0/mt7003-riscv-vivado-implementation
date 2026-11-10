`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: byte_decoder_tb
//
// OBJETIVO DE LA PRUEBA:
// Comprobar la generación de la máscara ByteWrite para habilitar bytes específicos
// en las transacciones de escritura de memoria (sw, sb) o bloquearlas durante
// lecturas y otras instrucciones[cite: 1].
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : MemWrite=0, funct3=XXX, addr_low=XX (Lectura/No memoria)
// 2. t = 10 ns : MemWrite=1, funct3=010 (sw), addr_low=00
// 3. t = 20 ns : MemWrite=1, funct3=000 (sb), addr_low=00 (Byte 0)
// 4. t = 30 ns : MemWrite=1, funct3=000 (sb), addr_low=01 (Byte 1)
// 5. t = 40 ns : MemWrite=1, funct3=000 (sb), addr_low=10 (Byte 2)
// 6. t = 50 ns : MemWrite=1, funct3=000 (sb), addr_low=11 (Byte 3)
// 7. t = 60 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. En t=0  ns : ByteWrite = 0000
// 2. En t=10 ns : ByteWrite = 1111 (Los 4 bytes activos)
// 3. En t=20 ns : ByteWrite = 0001
// 4. En t=30 ns : ByteWrite = 0010
// 5. En t=40 ns : ByteWrite = 0100
// 6. En t=50 ns : ByteWrite = 1000
//////////////////////////////////////////////////////////////////////////////////

module byte_decoder_tb;

    // Entradas al DUT
    reg       MemWrite;
    reg [2:0] funct3;
    reg [1:0] addr_low;

    // Salida del DUT
    wire [3:0] ByteWrite;

    // Instanciación
    byte_decoder uut (
        .MemWrite(MemWrite),
        .funct3(funct3),
        .addr_low(addr_low),
        .ByteWrite(ByteWrite)
    );

    initial begin
        // 1. Lectura / Estado sin acceso de escritura a memoria
        MemWrite = 0;
        funct3   = 3'b010;
        addr_low = 2'b00;
        #10;
        $display("[%0t ns] Test 1 (Lectura MemWrite=0): ByteWrite=%b (Esperado: 0000)", $time, ByteWrite);

        // 2. Almacenamiento de Palabra (sw)
        MemWrite = 1;
        funct3   = 3'b010;
        #10;
        $display("[%0t ns] Test 2 (Store Word 'sw'): ByteWrite=%b (Esperado: 1111)", $time, ByteWrite);

        // 3. Almacenamiento de Byte (sb) en dirección alineada a 0
        funct3   = 3'b000;
        addr_low = 2'b00;
        #10;
        $display("[%0t ns] Test 3 (Store Byte 'sb' [00]): ByteWrite=%b (Esperado: 0001)", $time, ByteWrite);

        // 4. Almacenamiento de Byte (sb) en dirección alineada a 1
        addr_low = 2'b01;
        #10;
        $display("[%0t ns] Test 4 (Store Byte 'sb' [01]): ByteWrite=%b (Esperado: 0010)", $time, ByteWrite);

        // 5. Almacenamiento de Byte (sb) en dirección alineada a 2
        addr_low = 2'b10;
        #10;
        $display("[%0t ns] Test 5 (Store Byte 'sb' [10]): ByteWrite=%b (Esperado: 0100)", $time, ByteWrite);

        // 6. Almacenamiento de Byte (sb) en dirección alineada a 3
        addr_low = 2'b11;
        #10;
        $display("[%0t ns] Test 6 (Store Byte 'sb' [11]): ByteWrite=%b (Esperado: 1000)", $time, ByteWrite);

        #10;
        $display("--- Simulación del Módulo byte_decoder Finalizada Exitosamente ---");
        $finish;
    end

endmodule