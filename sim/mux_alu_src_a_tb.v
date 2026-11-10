`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: mux_alu_src_a_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar la conmutación correcta e instantánea del multiplexor 3 a 1 del operando A
// de la ALU, verificando la selección entre el PC (2'b00), OldPC (2'b01), el registro
// fuente A (2'b10) y la protección mediante el caso por defecto (2'b11).
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : in_pc = 0x0000_0004, in_old_pc = 0x0000_0000, in_reg_a = 0x0000_0055, ALUSrcA = 2'b00 (Fetch: PC)
// 2. t = 10 ns : ALUSrcA = 2'b01                                                                    (Decode/Branch: OldPC)
// 3. t = 20 ns : ALUSrcA = 2'b10                                                                    (Execute: Reg A)
// 4. t = 30 ns : ALUSrcA = 2'b11                                                                    (Prueba de cláusula default)
// 5. t = 40 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. out_src_a = 0x0000_0004 (Selecciona in_pc para calcular PC + 4)
// 2. out_src_a = 0x0000_0000 (Selecciona in_old_pc para cálculo de dirección de salto)
// 3. out_src_a = 0x0000_0055 (Selecciona el dato del registro rs1)
// 4. out_src_a = 0x0000_0004 (Retorna a in_pc por cláusula default de protección)
//////////////////////////////////////////////////////////////////////////////////

module mux_alu_src_a_tb;

    // Entradas al DUT
    reg [31:0] in_pc;
    reg [31:0] in_old_pc;
    reg [31:0] in_reg_a;
    reg [1:0]  ALUSrcA;

    // Salida del DUT
    wire [31:0] out_src_a;

    // Instanciación del módulo bajo prueba
    mux_alu_src_a uut (
        .in_pc(in_pc),
        .in_old_pc(in_old_pc),
        .in_reg_a(in_reg_a),
        .ALUSrcA(ALUSrcA),
        .out_src_a(out_src_a)
    );

    initial begin
        // 1. Inicialización: Selección Fetch (ALUSrcA = 2'b00)
        in_pc     = 32'h0000_0004;
        in_old_pc = 32'h0000_0000;
        in_reg_a  = 32'h0000_0055;
        ALUSrcA   = 2'b00;

        #10;
        $display("[%0t ns] Test 1 (Fetch - ALUSrcA=00): out_src_a = 0x%h (Esperado: 0x00000004)", $time, out_src_a);

        // 2. Selección de OldPC para Saltos (ALUSrcA = 2'b01)
        ALUSrcA = 2'b01;
        #10;
        $display("[%0t ns] Test 2 (Saltos - ALUSrcA=01): out_src_a = 0x%h (Esperado: 0x00000000)", $time, out_src_a);

        // 3. Selección de Dato de Registro A (ALUSrcA = 2'b10)
        ALUSrcA = 2'b10;
        #10;
        $display("[%0t ns] Test 3 (Operando Reg A - ALUSrcA=10): out_src_a = 0x%h (Esperado: 0x00000055)", $time, out_src_a);

        // 4. Selección No Válida / Default (ALUSrcA = 2'b11)
        ALUSrcA = 2'b11;
        #10;
        $display("[%0t ns] Test 4 (Caso Default - ALUSrcA=11): out_src_a = 0x%h (Esperado: 0x00000004)", $time, out_src_a);

        #10;
        $display("--- Simulación del Módulo mux_alu_src_a Finalizada Exitosamente ---");
        $finish;
    end

endmodule