`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: imm_decoder_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar la decodificación del formato de instrucción a partir del opcode,
// verificando que se asigne correctamente el selector ImmSrc para los
// formatos Tipo I, S, B, J y U de la arquitectura RV32I[cite: 1].
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : opcode=0x13 (Tipo I - Aritmética)
// 2. t = 10 ns : opcode=0x03 (Tipo I - lw)
// 3. t = 20 ns : opcode=0x23 (Tipo S - sw/sb)
// 4. t = 30 ns : opcode=0x63 (Tipo B - bne/bge)
// 5. t = 40 ns : opcode=0x6F (Tipo J - jal)
// 6. t = 50 ns : opcode=0x37 (Tipo U - lui)
// 7. t = 60 ns : opcode=0x7F (Opcode inválido para evaluar caso por defecto)
// 8. t = 70 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. En t=0  ns : ImmSrc = 000 (Tipo I)
// 2. En t=10 ns : ImmSrc = 000 (Tipo I)
// 3. En t=20 ns : ImmSrc = 001 (Tipo S)
// 4. En t=30 ns : ImmSrc = 010 (Tipo B)
// 5. En t=40 ns : ImmSrc = 011 (Tipo J)
// 6. En t=50 ns : ImmSrc = 100 (Tipo U)
// 7. En t=60 ns : ImmSrc = 000 (Default)
//////////////////////////////////////////////////////////////////////////////////

module imm_decoder_tb;

    // Entradas al DUT
    reg [6:0] opcode;

    // Salida del DUT
    wire [2:0] ImmSrc;

    // Instanciación
    imm_decoder uut (
        .opcode(opcode),
        .ImmSrc(ImmSrc)
    );

    initial begin
        // 1. Tipo I (Aritmética)
        opcode = 7'b0010011;
        #10;
        $display("[%0t ns] Test 1 (Tipo I Arit): ImmSrc=%b (Esperado: 000)", $time, ImmSrc);

        // 2. Tipo I (Load)
        opcode = 7'b0000011;
        #10;
        $display("[%0t ns] Test 2 (Tipo I Load): ImmSrc=%b (Esperado: 000)", $time, ImmSrc);

        // 3. Tipo S (Store)
        opcode = 7'b0100011;
        #10;
        $display("[%0t ns] Test 3 (Tipo S Store): ImmSrc=%b (Esperado: 001)", $time, ImmSrc);

        // 4. Tipo B (Branch)
        opcode = 7'b1100011;
        #10;
        $display("[%0t ns] Test 4 (Tipo B Branch): ImmSrc=%b (Esperado: 010)", $time, ImmSrc);

        // 5. Tipo J (Jump)
        opcode = 7'b1101111;
        #10;
        $display("[%0t ns] Test 5 (Tipo J Jump): ImmSrc=%b (Esperado: 011)", $time, ImmSrc);

        // 6. Tipo U (LUI)
        opcode = 7'b0110111;
        #10;
        $display("[%0t ns] Test 6 (Tipo U LUI): ImmSrc=%b (Esperado: 100)", $time, ImmSrc);

        // 7. Default
        opcode = 7'b1111111;
        #10;
        $display("[%0t ns] Test 7 (Default): ImmSrc=%b (Esperado: 000)", $time, ImmSrc);

        #10;
        $display("--- Simulación del Módulo imm_decoder Finalizada Exitosamente ---");
        $finish;
    end

endmodule