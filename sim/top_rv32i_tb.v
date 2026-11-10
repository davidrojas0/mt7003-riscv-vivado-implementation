`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: top_rv32i_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar el procesador completo instanciado bajo el top_rv32i. Inicializa el
// sistema mediante un reset activo en alto y deja correr el reloj (clk). 
// Supervisa constantemente la señal "halted" de salida para finalizar la 
// simulación cuando el procesador termina de ejecutar el programa en memoria.
//////////////////////////////////////////////////////////////////////////////////

module top_rv32i_tb;

    // Entradas del Sistema
    reg clk;
    reg rst;

    // Salidas del Sistema
    wire halted;

    // Instanciación del Top-Level del Procesador
    top_rv32i uut (
        .clk(clk),
        .rst(rst),
        .halted(halted)
    );

    // Generador de Reloj (Período = 10 ns)
    always #5 clk = ~clk;

    initial begin
        // Inicialización y aplicación de Reset
        $display("===============================================================");
        $display("   INICIANDO SIMULACION DEL PROCESADOR MULTICICLO RV32I        ");
        $display("===============================================================");
        
        clk = 0;
        rst = 1;
        
        // Mantener el reset activo por 2 ciclos completos de reloj
        #20;
        rst = 0;
        $display("[%0t ns] Reset liberado. El procesador inicia la ejecucion...", $time);
    end

    // Monitor inteligente: Detiene la simulación y genera el Dump cuando detecta 'halted'
    always @(posedge clk) begin
        if (halted) begin
            $display("===============================================================");
            $display("[%0t ns] BANDERA HALTED DETECTADA. Generando memory dump...", $time);
            
            // Exporta el contenido de la memoria RAM a un archivo de texto plano (memory_dump.mem)
            // Reemplaza "uut.u_memory.RAM" por la ruta jerárquica exacta hacia tu arreglo RAM en el Top
            $writememh("memory_dump.mem", uut.u_memory.ram);
            
            $display("Dump de memoria generado con exito en 'memory_dump.hex'.");
            $display("===============================================================");
            $finish;
        end
    end

    // Failsafe / Timeout por si el código entra en un bucle infinito
    initial begin
        #50000; // Ajusta este tiempo límite dependiendo del largo de tu código C compilado
        $display("===============================================================");
        $display("[%0t ns] ERROR: TIMEOUT DE SIMULACION ALCANZADO.", $time);
        $display("Es posible que el procesador este atrapado en un bucle infinito.");
        $display("===============================================================");
        $finish;
    end

endmodule