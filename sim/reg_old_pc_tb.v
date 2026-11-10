`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: reg_old_pc_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar el comportamiento secuencial síncrono del registro OldPC, comprobando
// la inicialización a 0x0000_0000 bajo reset activo en alto (rst=1), el muestreo
// y retención de la dirección in_pc en cada flanco de subida del reloj (clk), y
// el reinicio síncrono durante la operación.
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : clk=0, rst=1, in_pc=0x0000_0000
// 2. t = 15 ns : rst=0, in_pc=0x0000_0004 (Cargar dirección PC=4)
// 3. t = 25 ns : in_pc=0x0000_0008       (Cambio de in_pc previo al posedge t=30ns)
// 4. t = 35 ns : rst=1, in_pc=0x0000_000C (Aplicar reset síncrono activo en alto)
// 5. t = 45 ns : rst=0, in_pc=0x0000_0010 (Liberar reset y cargar dirección PC=16)
// 6. t = 55 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. En t=10 ns (posedge clk con rst=1): out_old_pc = 0x0000_0000.
// 2. En t=20 ns (posedge clk tras rst=0): out_old_pc = 0x0000_0004.
// 3. En t=30 ns (posedge clk): out_old_pc = 0x0000_0008.
// 4. En t=40 ns (posedge clk con rst=1): out_old_pc = 0x0000_0000 (Reset síncrono).
// 5. En t=50 ns (posedge clk tras rst=0): out_old_pc = 0x0000_0010.
//////////////////////////////////////////////////////////////////////////////////

module reg_old_pc_tb;

    // Entradas al DUT
    reg        clk;
    reg        rst;
    reg [31:0] in_pc;

    // Salida del DUT
    wire [31:0] out_old_pc;

    // Instanciación del módulo bajo prueba
    reg_old_pc uut (
        .clk(clk),
        .rst(rst),
        .in_pc(in_pc),
        .out_old_pc(out_old_pc)
    );

    // Generador de reloj (Período = 10 ns)
    always #5 clk = ~clk;

    initial begin
        // 1. Estado inicial con Reset activo
        clk   = 0;
        rst   = 1;
        in_pc = 32'h0000_0000;

        #15; // Pasa posedge t=10ns (Reset activo)
        $display("[%0t ns] Test 1 (Reset inicial): out_old_pc = 0x%h (Esperado: 0x00000000)", $time, out_old_pc);

        // 2. Liberación de Reset y carga de PC = 0x0000_0004
        rst   = 0;
        in_pc = 32'h0000_0004;

        #10; // Pasa posedge t=20ns
        $display("[%0t ns] Test 2 (Muestreo PC=0x4): out_old_pc = 0x%h (Esperado: 0x00000004)", $time, out_old_pc);

        // 3. Cambio de entrada a PC = 0x0000_0008
        in_pc = 32'h0000_0008;

        #10; // Pasa posedge t=30ns
        $display("[%0t ns] Test 3 (Muestreo PC=0x8): out_old_pc = 0x%h (Esperado: 0x00000008)", $time, out_old_pc);

        // 4. Aplicación de reset síncrono durante operación
        rst   = 1;
        in_pc = 32'h0000_000C;

        #10; // Pasa posedge t=40ns
        $display("[%0t ns] Test 4 (Reset síncrono): out_old_pc = 0x%h (Esperado: 0x00000000)", $time, out_old_pc);

        // 5. Liberar reset y cargar nuevo PC = 0x0000_0010
        rst   = 0;
        in_pc = 32'h0000_0010;

        #10; // Pasa posedge t=50ns
        $display("[%0t ns] Test 5 (Recuperación tras Reset): out_old_pc = 0x%h (Esperado: 0x00000010)", $time, out_old_pc);

        #5;
        $display("--- Simulación del Módulo reg_old_pc Finalizada Exitosamente ---");
        $finish;
    end

endmodule