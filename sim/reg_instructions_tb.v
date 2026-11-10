`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: reg_instructions_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar la retención y captura secuencial del registro de instrucciones (IR),
// comprobando la inicialización a NOP (0x0000_0013) bajo reset activo en alto (rst=1),
// el muestreo de la instrucción leída desde la RAM cuando IRWrite=1, y la retención
// (Hold) de la instrucción ante variaciones en el bus de entrada cuando IRWrite=0.
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : clk=0, rst=1, IRWrite=0, in_instruction=0x0000_0000
// 2. t = 15 ns : rst=0, IRWrite=1, in_instruction=0x0050_0193 (Instrucción addi x3, x0, 5)
// 3. t = 25 ns : IRWrite=0, in_instruction=0xDEAD_BEEF (Cambio en bus de RAM con IRWrite=0)
// 4. t = 35 ns : IRWrite=1, in_instruction=0x0020_81B3 (Nueva instrucción add x3, x1, x2)
// 5. t = 45 ns : rst=1, IRWrite=0                      (Prueba de Reset síncrono)
// 6. t = 55 ns : rst=0, IRWrite=1, in_instruction=0x0000_0033 (Instrucción add x0, x0, x0)
// 7. t = 65 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. En t=10 ns (posedge clk con rst=1): out_instruction = 0x0000_0013 (NOP).
// 2. En t=20 ns (posedge clk con IRWrite=1): out_instruction = 0x0050_0193.
// 3. En t=30 ns (posedge clk con IRWrite=0): out_instruction = 0x0050_0193 (Retiene valor previo ignorando 0xDEADBEEF).
// 4. En t=40 ns (posedge clk con IRWrite=1): out_instruction = 0x0020_81B3.
// 5. En t=50 ns (posedge clk con rst=1): out_instruction = 0x0000_0013 (Restablece a NOP).
// 6. En t=60 ns (posedge clk con IRWrite=1): out_instruction = 0x0000_0033.
//////////////////////////////////////////////////////////////////////////////////

module reg_instructions_tb;

    // Entradas al DUT
    reg        clk;
    reg        rst;
    reg        IRWrite;
    reg [31:0] in_instruction;

    // Salida del DUT
    wire [31:0] out_instruction;

    // Instanciación del módulo bajo prueba
    reg_instructions uut (
        .clk(clk),
        .rst(rst),
        .IRWrite(IRWrite),
        .in_instruction(in_instruction),
        .out_instruction(out_instruction)
    );

    // Generador de reloj (Período = 10 ns)
    always #5 clk = ~clk;

    initial begin
        // 1. Estado inicial en Reset
        clk            = 0;
        rst            = 1;
        IRWrite        = 0;
        in_instruction = 32'h0000_0000;

        #15; // Pasa posedge t=10ns (Reset activo)
        $display("[%0t ns] Test 1 (Reset inicial): out_instruction = 0x%h (Esperado: 0x00000013 [NOP])", $time, out_instruction);

        // 2. Captura de primera instrucción (addi x3, x0, 5)
        rst            = 0;
        IRWrite        = 1;
        in_instruction = 32'h0050_0193;

        #10; // Pasa posedge t=20ns
        $display("[%0t ns] Test 2 (Captura con IRWrite=1): out_instruction = 0x%h (Esperado: 0x00500193)", $time, out_instruction);

        // 3. Prueba de retención (IRWrite = 0): Cambia bus de entrada a 0xDEADBEEF
        IRWrite        = 0;
        in_instruction = 32'hDEAD_BEEF;

        #10; // Pasa posedge t=30ns
        $display("[%0t ns] Test 3 (Retención con IRWrite=0): out_instruction = 0x%h (Esperado: 0x00500193)", $time, out_instruction);

        // 4. Captura de nueva instrucción (add x3, x1, x2)
        IRWrite        = 1;
        in_instruction = 32'h0020_81B3;

        #10; // Pasa posedge t=40ns
        $display("[%0t ns] Test 4 (Actualización con IRWrite=1): out_instruction = 0x%h (Esperado: 0x002081B3)", $time, out_instruction);

        // 5. Aplicación de reset síncrono
        rst     = 1;
        IRWrite = 0;

        #10; // Pasa posedge t=50ns
        $display("[%0t ns] Test 5 (Reset síncrono): out_instruction = 0x%h (Esperado: 0x00000013 [NOP])", $time, out_instruction);

        // 6. Carga final tras restablecimiento
        rst            = 0;
        IRWrite        = 1;
        in_instruction = 32'h0000_0033;

        #10; // Pasa posedge t=60ns
        $display("[%0t ns] Test 6 (Carga pos-reset): out_instruction = 0x%h (Esperado: 0x00000033)", $time, out_instruction);

        #5;
        $display("--- Simulación del Módulo reg_instructions Finalizada Exitosamente ---");
        $finish;
    end

endmodule