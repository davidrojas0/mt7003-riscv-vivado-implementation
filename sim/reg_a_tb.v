`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: reg_a_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar la captura secuencial síncrona y la retención del registro intermedio A,
// comprobando la inicialización en 0x0000_0000 bajo reset activo en alto (rst=1),
// la transferencia del operando rs1 (in_read_data_1) hacia la salida out_a en el
// flanco de subida del reloj (clk) y la respuesta ante un reset síncrono en operación.
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : clk=0, rst=1, in_read_data_1=0x0000_0000
// 2. t = 15 ns : rst=0, in_read_data_1=0x0000_001F (Valor del registro rs1 = 31)
// 3. t = 25 ns : in_read_data_1=0xAAAA_5555       (Nuevo dato leído de rs1)
// 4. t = 35 ns : rst=1, in_read_data_1=0xFFFF_FFFF (Reset síncrono en operación)
// 5. t = 45 ns : rst=0, in_read_data_1=0x1234_8765 (Recuperación tras reset)
// 6. t = 55 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. En t=10 ns (posedge clk con rst=1): out_a = 0x0000_0000.
// 2. En t=20 ns (posedge clk tras rst=0): out_a = 0x0000_001F.
// 3. En t=30 ns (posedge clk): out_a = 0xAAAA_5555.
// 4. En t=40 ns (posedge clk con rst=1): out_a = 0x0000_0000 (Reset síncrono).
// 5. En t=50 ns (posedge clk tras rst=0): out_a = 0x1234_8765.
//////////////////////////////////////////////////////////////////////////////////

module reg_a_tb;

    // Entradas al DUT
    reg        clk;
    reg        rst;
    reg [31:0] in_read_data_1;

    // Salida del DUT
    wire [31:0] out_a;

    // Instanciación del módulo bajo prueba
    reg_a uut (
        .clk(clk),
        .rst(rst),
        .in_read_data_1(in_read_data_1),
        .out_a(out_a)
    );

    // Generador de reloj (Período = 10 ns)
    always #5 clk = ~clk;

    initial begin
        // 1. Estado inicial en Reset
        clk            = 0;
        rst            = 1;
        in_read_data_1 = 32'h0000_0000;

        #15; // Pasa posedge t=10ns (Reset activo)
        $display("[%0t ns] Test 1 (Reset inicial): out_a = 0x%h (Esperado: 0x00000000)", $time, out_a);

        // 2. Liberar reset y muestrear operando rs1 (0x0000001F)
        rst            = 0;
        in_read_data_1 = 32'h0000_001F;

        #10; // Pasa posedge t=20ns
        $display("[%0t ns] Test 2 (Muestreo rs1): out_a = 0x%h (Esperado: 0x0000001F)", $time, out_a);

        // 3. Muestrear segundo operando (0xAAAA5555)
        in_read_data_1 = 32'hAAAA_5555;

        #10; // Pasa posedge t=30ns
        $display("[%0t ns] Test 3 (Actualización rs1): out_a = 0x%h (Esperado: 0xAAAA5555)", $time, out_a);

        // 4. Reset síncrono durante operación
        rst            = 1;
        in_read_data_1 = 32'hFFFF_FFFF;

        #10; // Pasa posedge t=40ns
        $display("[%0t ns] Test 4 (Reset síncrono): out_a = 0x%h (Esperado: 0x00000000)", $time, out_a);

        // 5. Carga posterior a la liberación de reset (0x12348765)
        rst            = 0;
        in_read_data_1 = 32'h1234_8765;

        #10; // Pasa posedge t=50ns
        $display("[%0t ns] Test 5 (Carga pos-reset): out_a = 0x%h (Esperado: 0x12348765)", $time, out_a);

        #5;
        $display("--- Simulación del Módulo reg_a Finalizada Exitosamente ---");
        $finish;
    end

endmodule