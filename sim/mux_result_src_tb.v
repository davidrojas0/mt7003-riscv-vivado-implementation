`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: mux_result_src_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar la conmutación combinacional del multiplexor de resultados 3 a 1 de 32 bits,
// verificando la selección correcta del resultado registrado de la ALU (ResultSrc=00),
// el dato leído de memoria (ResultSrc=01), el resultado directo combinacional de la ALU
// (ResultSrc=10) y el comportamiento seguro por defecto (ResultSrc=11).
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : in_reg_alu=0xAAAAAAAA, in_reg_datos=0xBBBBBBBB, in_alu=0xCCCCCCCC, ResultSrc=2'b00
// 2. t = 10 ns : ResultSrc = 2'b01 (Selección dato de memoria)
// 3. t = 20 ns : ResultSrc = 2'b10 (Selección ALU directo)
// 4. t = 30 ns : ResultSrc = 2'b11 (Selección no definida / default)
// 5. t = 40 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. En t=0  ns : out_result = 0xAAAAAAAA (Entrada in_reg_alu)
// 2. En t=10 ns : out_result = 0xBBBBBBBB (Entrada in_reg_datos)
// 3. En t=20 ns : out_result = 0xCCCCCCCC (Entrada in_alu)
// 4. En t=30 ns : out_result = 0x00000000 (Valor de seguridad default)
//////////////////////////////////////////////////////////////////////////////////

module mux_result_src_tb;

    // Entradas al DUT
    reg [31:0] in_reg_alu;
    reg [31:0] in_reg_datos;
    reg [31:0] in_alu;
    reg [1:0]  ResultSrc;

    // Salida del DUT
    wire [31:0] out_result;

    // Instanciación del módulo bajo prueba
    mux_result_src uut (
        .in_reg_alu(in_reg_alu),
        .in_reg_datos(in_reg_datos),
        .in_alu(in_alu),
        .ResultSrc(ResultSrc),
        .out_result(out_result)
    );

    initial begin
        // Valores base de entrada
        in_reg_alu   = 32'hAAAA_AAAA;
        in_reg_datos = 32'hBBBB_BBBB;
        in_alu       = 32'hCCCC_CCCC;

        // 1. Prueba de selección 00 (in_reg_alu)
        ResultSrc = 2'b00;
        #10;
        $display("[%0t ns] Test 1 (ResultSrc=00): out_result = 0x%h (Esperado: 0xAAAAAAAA)", $time, out_result);

        // 2. Prueba de selección 01 (in_reg_datos)
        ResultSrc = 2'b01;
        #10;
        $display("[%0t ns] Test 2 (ResultSrc=01): out_result = 0x%h (Esperado: 0xBBBBBBBB)", $time, out_result);

        // 3. Prueba de selección 10 (in_alu)
        ResultSrc = 2'b10;
        #10;
        $display("[%0t ns] Test 3 (ResultSrc=10): out_result = 0x%h (Esperado: 0xCCCCCCCC)", $time, out_result);

        // 4. Prueba de selección default (11)
        ResultSrc = 2'b11;
        #10;
        $display("[%0t ns] Test 4 (ResultSrc=11 Default): out_result = 0x%h (Esperado: 0x00000000)", $time, out_result);

        #10;
        $display("--- Simulación del Módulo mux_result_src Finalizada Exitosamente ---");
        $finish;
    end

endmodule