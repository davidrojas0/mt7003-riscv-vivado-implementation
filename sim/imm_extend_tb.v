`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: imm_extend_tb
//
// OBJETIVO DE LA PRUEBA:
// Verificar la correcta extracción, concatenación de bits dispersos y extensión
// de signo a 32 bits para los 5 formatos de inmediato soportados por el procesador
// RV32I (Tipo I, Tipo S, Tipo B, Tipo J y Tipo U).
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : ImmSrc=3'b000 (Tipo I),  Instr con inmediato positivo +10 (0x00A)
// 2. t = 10 ns : ImmSrc=3'b000 (Tipo I),  Instr con inmediato negativo -4  (0xFFC)
// 3. t = 20 ns : ImmSrc=3'b001 (Tipo S),  Instr con offset de almacenamiento -8 (sw/sb)
// 4. t = 30 ns : ImmSrc=3'b010 (Tipo B),  Instr con offset de salto +16 (bne/bge)
// 5. t = 40 ns : ImmSrc=3'b011 (Tipo J),  Instr con offset de salto -12 (jal)
// 6. t = 50 ns : ImmSrc=3'b100 (Tipo U),  Instr con constante superior 0xC7DF0 (lui)
// 7. t = 60 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. ImmExt = 0x0000_000A (Extensión de signo positiva de 12 bits)
// 2. ImmExt = 0xFFFF_FFFC (Extensión de signo negativa de 12 bits)
// 3. ImmExt = 0xFFFF_FFF8 (Reconstrucción y extensión de signo Tipo S)
// 4. ImmExt = 0x0000_0010 (Reconstrucción de 13 bits con LSB=0 Tipo B)
// 5. ImmExt = 0xFFFF_FFF4 (Reconstrucción de 21 bits con LSB=0 Tipo J)
// 6. ImmExt = 0xC7DF_0000 (Carga de byte alto Tipo U con 12 ceros inferiores)
//////////////////////////////////////////////////////////////////////////////////

module imm_extend_tb;

    // Entradas al DUT
    reg [31:7] Instr;
    reg [2:0]  ImmSrc;

    // Salida del DUT
    wire [31:0] ImmExt;

    // Instanciación del módulo bajo prueba
    imm_extend uut (
        .Instr(Instr),
        .ImmSrc(ImmSrc),
        .ImmExt(ImmExt)
    );

    initial begin
        // 1. Tipo I (Inmediato Positivo: +10)
        ImmSrc = 3'b000;
        Instr[31:20] = 12'sd10; // 0x00A
        Instr[19:7]  = 13'b0;

        #10;
        $display("[%0t ns] Test 1 (Tipo I +10): ImmExt = 0x%h (Esperado: 0x0000000A)", $time, ImmExt);

        // 2. Tipo I (Inmediato Negativo: -4 -> 12'hFFC)
        ImmSrc = 3'b000;
        Instr[31:20] = 12'hFFC;

        #10;
        $display("[%0t ns] Test 2 (Tipo I -4): ImmExt = 0x%h (Esperado: 0xFFFFFFFC)", $time, ImmExt);

        // 3. Tipo S (Offset Negativo: -8 -> 12'hFF8)
        ImmSrc = 3'b001;
        Instr[31:25] = 7'b1111111;
        Instr[11:7]  = 5'b11000;

        #10;
        $display("[%0t ns] Test 3 (Tipo S -8): ImmExt = 0x%h (Esperado: 0xFFFFFFF8)", $time, ImmExt);

        // 4. Tipo B (Offset Positivo: +16 -> 13'h0010)
        ImmSrc = 3'b010;
        Instr[31]    = 1'b0;
        Instr[7]     = 1'b0;
        Instr[30:25] = 6'b000000;
        Instr[11:8]  = 4'b1000;

        #10;
        $display("[%0t ns] Test 4 (Tipo B +16): ImmExt = 0x%h (Esperado: 0x00000010)", $time, ImmExt);

        // 5. Tipo J (Offset Negativo: -12 -> 21'h1F_FFF4)
        ImmSrc = 3'b011;
        Instr[31]     = 1'b1;
        Instr[19:12]  = 8'hFF;
        Instr[20]     = 1'b1;
        Instr[30:21]  = 10'b1111111010;

        #10;
        $display("[%0t ns] Test 5 (Tipo J -12): ImmExt = 0x%h (Esperado: 0xFFFFFFF4)", $time, ImmExt);

        // 6. Tipo U (Inmediato Superior: 0xC7DF0)
        ImmSrc = 3'b100;
        Instr[31:12] = 20'hC7DF0;

        #10;
        $display("[%0t ns] Test 6 (Tipo U 0xC7DF0): ImmExt = 0x%h (Esperado: 0xC7DF0000)", $time, ImmExt);

        #10;
        $display("--- Simulación del Módulo imm_extend Finalizada Exitosamente ---");
        $finish;
    end

endmodule