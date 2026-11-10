`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: mux_adr_src_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar el funcionamiento del multiplexor combinacional de dirección de memoria,
// verificando que la conmutación entre la dirección del PC (AdrSrc=0) y la dirección
// de datos (AdrSrc=1) responda inmediatamente sin demoras de reloj ni estados X.
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : in_pc = 0x0000_0004, in_result = 0x1000_0020, AdrSrc = 0 (Selección Fetch)
// 2. t = 10 ns : AdrSrc = 1                                              (Conmutación a Acceso a Datos)
// 3. t = 20 ns : in_pc = 0x0000_0008, in_result = 0x1000_0024             (Cambio dinámico de entradas con AdrSrc=1)
// 4. t = 30 ns : AdrSrc = 0                                              (Retorno a selección Fetch)
// 5. t = 40 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. out_adr = 0x0000_0004 (Selecciona in_pc para la etapa de Fetch)
// 2. out_adr = 0x1000_0020 (Conmuta a in_result para acceso a RAM lw/sw)
// 3. out_adr = 0x1000_0024 (Sigue seleccionando in_result actualizado)
// 4. out_adr = 0x0000_0008 (Retorna a in_pc)
//////////////////////////////////////////////////////////////////////////////////

module mux_adr_src_tb;

    // Señales de entrada al DUT
    reg [31:0] in_pc;
    reg [31:0] in_result;
    reg        AdrSrc;

    // Salida del DUT
    wire [31:0] out_adr;

    // Instanciación del módulo bajo prueba (DUT)
    mux_adr_src uut (
        .in_pc(in_pc),
        .in_result(in_result),
        .AdrSrc(AdrSrc),
        .out_adr(out_adr)
    );

    initial begin
        // 1. Estado inicial: Selección Fetch (AdrSrc = 0)
        in_pc     = 32'h0000_0004;
        in_result = 32'h1000_0020;
        AdrSrc    = 1'b0;

        #10;
        $display("[%0t ns] Test 1 (Fetch - AdrSrc=0): out_adr = 0x%h (Esperado: 0x00000004)", $time, out_adr);

        // 2. Conmutación a Acceso a Datos (AdrSrc = 1)
        AdrSrc = 1'b1;
        #10;
        $display("[%0t ns] Test 2 (Memory Access - AdrSrc=1): out_adr = 0x%h (Esperado: 0x10000020)", $time, out_adr);

        // 3. Cambio dinámico de datos de entrada mientras AdrSrc = 1
        in_pc     = 32'h0000_0008;
        in_result = 32'h1000_0024;
        #10;
        $display("[%0t ns] Test 3 (Entradas actualizadas - AdrSrc=1): out_adr = 0x%h (Esperado: 0x10000024)", $time, out_adr);

        // 4. Regreso a selección Fetch (AdrSrc = 0)
        AdrSrc = 1'b0;
        #10;
        $display("[%0t ns] Test 4 (Regreso a Fetch - AdrSrc=0): out_adr = 0x%h (Esperado: 0x00000008)", $time, out_adr);

        #10;
        $display("--- Simulación del Módulo mux_adr_src Finalizada Exitosamente ---");
        $finish;
    end

endmodule