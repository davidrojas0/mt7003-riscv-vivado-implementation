`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: reg_data_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar la captura y retención secuencial síncrona del registro de datos leídos
// de memoria (MDR / Datos), verificando la inicialización en 0x0000_0000 bajo reset
// activo en alto (rst=1), la captura del bus in_read_data en el flanco de subida del
// reloj (clk) y el reinicio síncrono durante la operación.
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : clk=0, rst=1, in_read_data=0x0000_0000
// 2. t = 15 ns : rst=0, in_read_data=0x1234_5678 (Carga de primer dato leído de RAM)
// 3. t = 25 ns : in_read_data=0xCAFE_BABE       (Cambio en el bus de lectura de RAM)
// 4. t = 35 ns : rst=1, in_read_data=0xABCD_EF01 (Aplicar reset síncrono)
// 5. t = 45 ns : rst=0, in_read_data=0x9988_7766 (Liberar reset y cargar nuevo dato)
// 6. t = 55 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. En t=10 ns (posedge clk con rst=1): out_data = 0x0000_0000.
// 2. En t=20 ns (posedge clk tras rst=0): out_data = 0x1234_5678.
// 3. En t=30 ns (posedge clk): out_data = 0xCAFE_BABE.
// 4. En t=40 ns (posedge clk con rst=1): out_data = 0x0000_0000 (Reset síncrono).
// 5. En t=50 ns (posedge clk tras rst=0): out_data = 0x9988_7766.
//////////////////////////////////////////////////////////////////////////////////

module reg_datos_tb;

    // Entradas al DUT
    reg        clk;
    reg        rst;
    reg [31:0] in_read_data;

    // Salida del DUT
    wire [31:0] out_data;

    // Instanciación del módulo bajo prueba
    reg_datos uut (
        .clk(clk),
        .rst(rst),
        .in_read_data(in_read_data),
        .out_data(out_data)
    );

    // Generador de reloj (Período = 10 ns)
    always #5 clk = ~clk;

    initial begin
        // 1. Estado inicial en Reset
        clk          = 0;
        rst          = 1;
        in_read_data = 32'h0000_0000;

        #15; // Pasa posedge t=10ns (Reset activo)
        $display("[%0t ns] Test 1 (Reset inicial): out_data = 0x%h (Esperado: 0x00000000)", $time, out_data);

        // 2. Liberar reset y muestrear primer dato (0x12345678)
        rst          = 0;
        in_read_data = 32'h1234_5678;

        #10; // Pasa posedge t=20ns
        $display("[%0t ns] Test 2 (Muestreo dato RAM 1): out_data = 0x%h (Esperado: 0x12345678)", $time, out_data);

        // 3. Muestrear segundo dato (0xCAFEBABE)
        in_read_data = 32'hCAFE_BABE;

        #10; // Pasa posedge t=30ns
        $display("[%0t ns] Test 3 (Muestreo dato RAM 2): out_data = 0x%h (Esperado: 0xCAFEBABE)", $time, out_data);

        // 4. Reset síncrono durante operación
        rst          = 1;
        in_read_data = 32'hABCD_EF01;

        #10; // Pasa posedge t=40ns
        $display("[%0t ns] Test 4 (Reset síncrono): out_data = 0x%h (Esperado: 0x00000000)", $time, out_data);

        // 5. Carga posterior a la liberación de reset (0x99887766)
        rst          = 0;
        in_read_data = 32'h9988_7766;

        #10; // Pasa posedge t=50ns
        $display("[%0t ns] Test 5 (Carga pos-reset): out_data = 0x%h (Esperado: 0x99887766)", $time, out_data);

        #5;
        $display("--- Simulación del Módulo reg_data Finalizada Exitosamente ---");
        $finish;
    end

endmodule