`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: reg_b_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar la captura secuencial síncrona y la retención del registro intermedio B,
// comprobando la inicialización en 0x0000_0000 bajo reset activo en alto (rst=1),
// la transferencia del operando rs2 (in_read_data_2) hacia la salida out_b en el
// flanco de subida del reloj (clk) y la respuesta ante un reset síncrono en operación.
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : clk=0, rst=1, in_read_data_2=0x0000_0000
// 2. t = 15 ns : rst=0, in_read_data_2=0x0000_002A (Valor del registro rs2 = 42)
// 3. t = 25 ns : in_read_data_2=0x5555_AAAA       (Nuevo dato leído de rs2)
// 4. t = 35 ns : rst=1, in_read_data_2=0xFFFF_FFFF (Reset síncrono en operación)
// 5. t = 45 ns : rst=0, in_read_data_2=0x8765_4321 (Recuperación tras reset)
// 6. t = 55 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. En t=10 ns (posedge clk con rst=1): out_b = 0x0000_0000.
// 2. En t=20 ns (posedge clk tras rst=0): out_b = 0x0000_002A.
// 3. En t=30 ns (posedge clk): out_b = 0x5555_AAAA.
// 4. En t=40 ns (posedge clk con rst=1): out_b = 0x0000_0000 (Reset síncrono).
// 5. En t=50 ns (posedge clk tras rst=0): out_b = 0x8765_4321.
//////////////////////////////////////////////////////////////////////////////////

module reg_b_tb;

    // Entradas al DUT
    reg        clk;
    reg        rst;
    reg [31:0] in_read_data_2;

    // Salida del DUT
    wire [31:0] out_b;

    // Instanciación del módulo bajo prueba
    reg_b uut (
        .clk(clk),
        .rst(rst),
        .in_read_data_2(in_read_data_2),
        .out_b(out_b)
    );

    // Generador de reloj (Período = 10 ns)
    always #5 clk = ~clk;

    initial begin
        // 1. Estado inicial en Reset
        clk            = 0;
        rst            = 1;
        in_read_data_2 = 32'h0000_0000;

        #15; // Pasa posedge t=10ns (Reset activo)
        $display("[%0t ns] Test 1 (Reset inicial): out_b = 0x%h (Esperado: 0x00000000)", $time, out_b);

        // 2. Liberar reset y muestrear operando rs2 (0x0000002A)
        rst            = 0;
        in_read_data_2 = 32'h0000_002A;

        #10; // Pasa posedge t=20ns
        $display("[%0t ns] Test 2 (Muestreo rs2): out_b = 0x%h (Esperado: 0x0000002A)", $time, out_b);

        // 3. Muestrear segundo operando (0x5555AAAA)
        in_read_data_2 = 32'h5555_AAAA;

        #10; // Pasa posedge t=30ns
        $display("[%0t ns] Test 3 (Actualización rs2): out_b = 0x%h (Esperado: 0x5555AAAA)", $time, out_b);

        // 4. Reset síncrono durante operación
        rst            = 1;
        in_read_data_2 = 32'hFFFF_FFFF;

        #10; // Pasa posedge t=40ns
        $display("[%0t ns] Test 4 (Reset síncrono): out_b = 0x%h (Esperado: 0x00000000)", $time, out_b);

        // 5. Carga posterior a la liberación de reset (0x87654321)
        rst            = 0;
        in_read_data_2 = 32'h8765_4321;

        #10; // Pasa posedge t=50ns
        $display("[%0t ns] Test 5 (Carga pos-reset): out_b = 0x%h (Esperado: 0x87654321)", $time, out_b);

        #5;
        $display("--- Simulación del Módulo reg_b Finalizada Exitosamente ---");
        $finish;
    end

endmodule