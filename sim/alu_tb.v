`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: alu_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar el correcto funcionamiento combinacional de la Unidad Aritmética Lógica
// (ALU), verificando las operaciones de suma (ADD), resta (SUB), AND lógico,
// desplazamiento a la izquierda (SLL) y transferencia directa (PASS-B), así como
// la generación correcta de las banderas Zero y Greater-Equal con signo (GE).
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : SrcA=10, SrcB=5, ALUControl=3'b000 (ADD)
// 2. t = 10 ns : SrcA=15, SrcB=15, ALUControl=3'b001 (SUB) -> Prueba de bandera Zero y GE
// 3. t = 20 ns : SrcA=20, SrcB=50, ALUControl=3'b001 (SUB) -> Prueba de GE (20 >= 50 es falso)
// 4. t = 30 ns : SrcA=-5, SrcB=-10, ALUControl=3 me 001 (SUB) -> GE con signo (-5 >= -10 es verdadero)
// 5. t = 40 ns : SrcA=0xFFFFFFFF, SrcB=0x0000000F, ALUControl=3'b010 (AND) -> Máscara de bits
// 6. t = 50 ns : SrcA=3, SrcB=4, ALUControl=3'b011 (SLL) -> Desplazamiento 3 << 4 = 48 (0x30)
// 7. t = 60 ns : SrcA=0x12345678, SrcB=0xC7DF0000, ALUControl=3'b100 (PASS-B) -> Operación LUI
// 8. t = 70 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. En t=0  ns : ALUResult = 15 (0x0000000F), Zero = 0, GE = 1
// 2. En t=10 ns : ALUResult = 0,  Zero = 1, GE = 1
// 3. En t=20 ns : ALUResult = -30 (32'hFFFFFFE2), Zero = 0, GE = 0
// 4. En t=30 ns : ALUResult = 5,   Zero = 0, GE = 1
// 5. En t=40 ns : ALUResult = 0x0000000F, Zero = 0, GE = 0
// 6. En t=50 ns : ALUResult = 48 (0x00000030), Zero = 0, GE = 0
// 7. En t=60 ns : ALUResult = 0xC7DF0000, Zero = 0, GE = 0
//////////////////////////////////////////////////////////////////////////////////

module alu_tb;

    // Entradas al DUT
    reg  [31:0] SrcA;
    reg  [31:0] SrcB;
    reg  [2:0]  ALUControl;

    // Salidas del DUT
    wire [31:0] ALUResult;
    wire        Zero;
    wire        GE;

    // Instanciación del módulo bajo prueba
    alu uut (
        .SrcA(SrcA),
        .SrcB(SrcB),
        .ALUControl(ALUControl),
        .ALUResult(ALUResult),
        .Zero(Zero),
        .GE(GE)
    );

    initial begin
        // 1. Suma (ADD)
        SrcA       = 32'd10;
        SrcB       = 32'd5;
        ALUControl = 3'b000;
        #10;
        $display("[%0t ns] Test 1 (ADD): 10 + 5 = %d (0x%h) | Zero=%b, GE=%b", $time, $signed(ALUResult), ALUResult, Zero, GE);

        // 2. Resta (SUB) con resultado 0 (Verificación de Zero)
        SrcA       = 32'd15;
        SrcB       = 32'd15;
        ALUControl = 3'b001;
        #10;
        $display("[%0t ns] Test 2 (SUB Zero): 15 - 15 = %d | Zero=%b (Esperado: 1), GE=%b (Esperado: 1)", $time, $signed(ALUResult), Zero, GE);

        // 3. Resta (SUB) sin Zero y SrcA < SrcB
        SrcA       = 32'd20;
        SrcB       = 32'd50;
        ALUControl = 3'b001;
        #10;
        $display("[%0t ns] Test 3 (SUB GE false): 20 - 50 = %d | Zero=%b, GE=%b (Esperado: 0)", $time, $signed(ALUResult), Zero, GE);

        // 4. Comparación con signo con números negativos (-5 >= -10)
        SrcA       = -32'd5;
        SrcB       = -32'd10;
        ALUControl = 3'b001;
        #10;
        $display("[%0t ns] Test 4 (Signed GE): -5 >= -10 | GE=%b (Esperado: 1)", $time, GE);

        // 5. Operación AND lógico
        SrcA       = 32'hFFFF_FFFF;
        SrcB       = 32'h0000_000F;
        ALUControl = 3'b010;
        #10;
        $display("[%0t ns] Test 5 (AND): 0x%h & 0x%h = 0x%h", $time, SrcA, SrcB, ALUResult);

        // 6. Desplazamiento lógico a la izquierda (SLL)
        SrcA       = 32'h0000_0003;
        SrcB       = 32'd4;
        ALUControl = 3'b011;
        #10;
        $display("[%0t ns] Test 6 (SLL): 3 << 4 = %d (0x%h)", $time, ALUResult, ALUResult);

        // 7. Paso directo de B (PASS-B / LUI)
        SrcA       = 32'h1234_5678;
        SrcB       = 32'hC7DF_0000;
        ALUControl = 3'b100;
        #10;
        $display("[%0t ns] Test 7 (PASS-B): Out = 0x%h (Esperado: 0xC7DF0000)", $time, ALUResult);

        #10;
        $display("--- Simulación del Módulo alu Finalizada Exitosamente ---");
        $finish;
    end

endmodule