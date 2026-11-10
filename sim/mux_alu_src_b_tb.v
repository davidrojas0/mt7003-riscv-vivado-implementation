`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: mux_alu_src_b_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar la conmutación combinacional instantánea del multiplexor 3 a 1 del operando B
// de la ALU, verificando la selección entre el registro rs2 (2'b00), el inmediato
// extendido (2'b01), la constante fija 4 (2'b10) y la cláusula por defecto (2'b11).
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : in_reg_b = 0x0000_0010, in_imm_ext = 0x0000_0020, in_4 = 32'd4, ALUSrcB = 2'b00 (Execute rs2)
// 2. t = 10 ns : ALUSrcB = 2'b01                                                              (Decode/Execute Inmediato)
// 3. t = 20 ns : ALUSrcB = 2'b10                                                              (Fetch: Constante 4)
// 4. t = 30 ns : ALUSrcB = 2'b11                                                              (Prueba de caso default)
// 5. t = 40 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. out_src_b = 0x0000_0010 (Selecciona el dato del registro rs2)
// 2. out_src_b = 0x0000_0020 (Selecciona el inmediato extendido de 32 bits)
// 3. out_src_b = 0x0000_0004 (Selecciona la constante fija 4 para PC + 4)
// 4. out_src_b = 0x0000_0004 (Retorna a in_4 por cláusula default de protección)
//////////////////////////////////////////////////////////////////////////////////

module mux_alu_src_b_tb;

    // Entradas al DUT
    reg [31:0] in_reg_b;
    reg [31:0] in_imm_ext;
    reg [31:0] in_4;
    reg [1:0]  ALUSrcB;

    // Salida del DUT
    wire [31:0] out_src_b;

    // Instanciación del módulo bajo prueba
    mux_alu_src_b uut (
        .in_reg_b(in_reg_b),
        .in_imm_ext(in_imm_ext),
        .in_4(in_4),
        .ALUSrcB(ALUSrcB),
        .out_src_b(out_src_b)
    );

    initial begin
        // 1. Inicialización: Selección Registro B (ALUSrcB = 2'b00)
        in_reg_b   = 32'h0000_0010;
        in_imm_ext = 32'h0000_0020;
        in_4       = 32'd4;
        ALUSrcB    = 2'b00;

        #10;
        $display("[%0t ns] Test 1 (Reg B - ALUSrcB=00): out_src_b = 0x%h (Esperado: 0x00000010)", $time, out_src_b);

        // 2. Selección de Inmediato Extendido (ALUSrcB = 2'b01)
        ALUSrcB = 2'b01;
        #10;
        $display("[%0t ns] Test 2 (ImmExt - ALUSrcB=01): out_src_b = 0x%h (Esperado: 0x00000020)", $time, out_src_b);

        // 3. Selección de Constante 4 (ALUSrcB = 2'b10)
        ALUSrcB = 2'b10;
        #10;
        $display("[%0t ns] Test 3 (Constante 4 - ALUSrcB=10): out_src_b = 0x%h (Esperado: 0x00000004)", $time, out_src_b);

        // 4. Selección No Válida / Default (ALUSrcB = 2'b11)
        ALUSrcB = 2'b11;
        #10;
        $display("[%0t ns] Test 4 (Caso Default - ALUSrcB=11): out_src_b = 0x%h (Esperado: 0x00000004)", $time, out_src_b);

        #10;
        $display("--- Simulación del Módulo mux_alu_src_b Finalizada Exitosamente ---");
        $finish;
    end

endmodule