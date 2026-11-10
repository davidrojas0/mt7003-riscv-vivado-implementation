`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: reg_alu_out_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar la captura secuencial síncrona y la retención del registro de salida de
// la ALU (ALUOut), comprobando la inicialización en 0x0000_0000 bajo reset activo
// en alto (rst=1), la transferencia del resultado de la ALU (in_alu_result) hacia
// la salida out_alu_out en el flanco de subida del reloj (clk) y la respuesta ante
// un reset síncrono durante la ejecución.
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : clk=0, rst=1, in_alu_result=0x0000_0000
// 2. t = 15 ns : rst=0, in_alu_result=0x0000_0044 (Resultado de cálculo de dirección o suma)
// 3. t = 25 ns : in_alu_result=0x1234_ABCD       (Resultado de operación ALU en Ciclo Execute)
// 4. t = 35 ns : rst=1, in_alu_result=0xFFFF_FFFF (Reset síncrono en operación)
// 5. t = 45 ns : rst=0, in_alu_result=0xDEFE_CAFE (Recuperación tras reset)
// 6. t = 55 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. En t=10 ns (posedge clk con rst=1): out_alu_out = 0x0000_0000.
// 2. En t=20 ns (posedge clk tras rst=0): out_alu_out = 0x0000_0044.
// 3. En t=30 ns (posedge clk): out_alu_out = 0x1234_ABCD.
// 4. En t=40 ns (posedge clk con rst=1): out_alu_out = 0x0000_0000 (Reset síncrono).
// 5. En t=50 ns (posedge clk tras rst=0): out_alu_out = 0xDEFE_CAFE.
//////////////////////////////////////////////////////////////////////////////////

module reg_alu_out_tb;

    // Entradas al DUT
    reg        clk;
    reg        rst;
    reg [31:0] in_alu_result;

    // Salida del DUT
    wire [31:0] out_alu_out;

    // Instanciación del módulo bajo prueba
    reg_alu_out uut (
        .clk(clk),
        .rst(rst),
        .in_alu_result(in_alu_result),
        .out_alu_out(out_alu_out)
    );

    // Generador de reloj (Período = 10 ns)
    always #5 clk = ~clk;

    initial begin
        // 1. Estado inicial en Reset
        clk           = 0;
        rst           = 1;
        in_alu_result = 32'h0000_0000;

        #15; // Pasa posedge t=10ns (Reset activo)
        $display("[%0t ns] Test 1 (Reset inicial): out_alu_out = 0x%h (Esperado: 0x00000000)", $time, out_alu_out);

        // 2. Liberar reset y muestrear primer resultado ALU (0x00000044)
        rst           = 0;
        in_alu_result = 32'h0000_0044;

        #10; // Pasa posedge t=20ns
        $display("[%0t ns] Test 2 (Muestreo ALUResult 1): out_alu_out = 0x%h (Esperado: 0x00000044)", $time, out_alu_out);

        // 3. Muestrear segundo resultado ALU (0x1234ABCD)
        in_alu_result = 32'h1234_ABCD;

        #10; // Pasa posedge t=30ns
        $display("[%0t ns] Test 3 (Muestreo ALUResult 2): out_alu_out = 0x%h (Esperado: 0x1234ABCD)", $time, out_alu_out);

        // 4. Reset síncrono durante operación
        rst           = 1;
        in_alu_result = 32'hFFFF_FFFF;

        #10; // Pasa posedge t=40ns
        $display("[%0t ns] Test 4 (Reset síncrono): out_alu_out = 0x%h (Esperado: 0x00000000)", $time, out_alu_out);

        // 5. Carga posterior a la liberación de reset (0xDEFECAFE)
        rst           = 0;
        in_alu_result = 32'hDEFE_CAFE;

        #10; // Pasa posedge t=50ns
        $display("[%0t ns] Test 5 (Carga pos-reset): out_alu_out = 0x%h (Esperado: 0xDEFECAFE)", $time, out_alu_out);

        #5;
        $display("--- Simulación del Módulo reg_alu_out Finalizada Exitosamente ---");
        $finish;
    end

endmodule