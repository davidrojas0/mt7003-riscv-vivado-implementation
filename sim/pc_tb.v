`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: pc_tb
//
// OBJETIVO DE LA PRUEBA:
// Verificar el correcto comportamiento secuencial del módulo Program Counter (PC),
// validando las operaciones de reinicio (Reset), retención de estado (Hold con PCWrite=0),
// actualización secuencial (Update con PCWrite=1) y carga de direcciones de salto.
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : rst=1, PCWrite=0, in_pc_next=0x0000_0000 (Reset inicial)
// 2. t = 15 ns : rst=0, PCWrite=0, in_pc_next=0x0000_0004 (Liberar reset, cambio en entrada sin PCWrite)
// 3. t = 25 ns : PCWrite=1                                (Habilitar escritura para avanzar PC+4)
// 4. t = 35 ns : PCWrite=0, in_pc_next=0x0000_0020 (Prueba de retención tras avance)
// 5. t = 45 ns : PCWrite=1                                (Cargar dirección de salto)
// 6. t = 55 ns : rst=1                                    (Reset en caliente)
//
// RESULTADOS ESPERADOS:
// 1. out_pc = 0x0000_0000 (Inicialización por reset)
// 2. out_pc = 0x0000_0000 (Mantiene valor previo al estar PCWrite en 0)
// 3. out_pc = 0x0000_0004 (Actualiza en el flanco de subida de reloj)
// 4. out_pc = 0x0000_0004 (Mantiene 0x4 aunque in_pc_next cambió a 0x20)
// 5. out_pc = 0x0000_0020 (Carga correctamente la dirección de salto)
// 6. out_pc = 0x0000_0000 (Restablece a cero asíncrona/sincrónicamente)
//////////////////////////////////////////////////////////////////////////////////

module pc_tb;

    reg        clk;
    reg        rst;
    reg        PCWrite;
    reg [31:0] in_pc_next;

    wire [31:0] out_pc;

    pc uut (
        .clk(clk),
        .rst(rst),
        .PCWrite(PCWrite),
        .in_pc_next(in_pc_next),
        .out_pc(out_pc)
    );

    always #5 clk = ~clk;

    initial begin
        clk = 0;
        rst = 1;
        PCWrite = 0;
        in_pc_next = 32'h0000_0000;

        #15;
        $display("[%0t ns] Test 1 (Reset): out_pc = 0x%h (Esperado: 0x00000000)", $time, out_pc);

        rst = 0;
        in_pc_next = 32'h0000_0004;
        #10;
        $display("[%0t ns] Test 2 (Hold con PCWrite=0): out_pc = 0x%h (Esperado: 0x00000000)", $time, out_pc);

        PCWrite = 1;
        #10;
        $display("[%0t ns] Test 3 (Update PCWrite=1): out_pc = 0x%h (Esperado: 0x00000004)", $time, out_pc);

        PCWrite = 0;
        in_pc_next = 32'h0000_0020;
        #10;
        $display("[%0t ns] Test 4 (Hold tras avance): out_pc = 0x%h (Esperado: 0x00000004)", $time, out_pc);

        PCWrite = 1;
        #10;
        $display("[%0t ns] Test 5 (Carga de salto): out_pc = 0x%h (Esperado: 0x00000020)", $time, out_pc);

        rst = 1;
        #5;
        $display("[%0t ns] Test 6 (Reset en caliente): out_pc = 0x%h (Esperado: 0x00000000)", $time, out_pc);

        #10;
        $display("--- Simulación del Módulo PC Finalizada Exitosamente ---");
        $finish;
    end

endmodule