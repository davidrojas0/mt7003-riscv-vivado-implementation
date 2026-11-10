`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: control_fsm_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar la secuencia completa de transiciones de estados de la FSM de Control y
// la generación síncrona/combinacional de las 11 señales de control para todos
// los tipos de instrucciones RV32I (Tipo I Aritmética, Cargas lw, Almacenamientos sw/sb,
// Saltos Condicionales bne/bge, Saltos Incondicionales jal, Cargas Superiores lui y
// detección de trampa HALT).
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : clk=0, rst=1, opcode=0x00
// 2. t = 15 ns : rst=0, opcode=0x13 (Tipo I: addi) -> FETCH -> DECODE -> EXEC_I -> ALUWB -> FETCH
// 3. t = 55 ns : opcode=0x03 (Carga: lw)          -> DECODE -> MEMADR -> MEMREAD -> MEMWB -> FETCH
// 4. t = 105 ns: opcode=0x23 (Almacenamiento: sw) -> DECODE -> MEMADR -> MEMWRITE -> FETCH
// 5. t = 145 ns: opcode=0x63 (Salto: bne/bge)     -> DECODE -> BRANCH -> FETCH
// 6. t = 175 ns: opcode=0x6F (Salto: jal)         -> DECODE -> JAL1 -> JAL2 -> FETCH
// 7. t = 215 ns: opcode=0x37 (Carga Sup: lui)     -> DECODE -> EXEC_LUI -> ALUWB -> FETCH
// 8. t = 255 ns: opcode=0x7F (Opcode no reconocido) -> DECODE -> HALT
// 9. t = 285 ns: rst=1 (Verificar salida de estado HALT mediante reinicio)
// 10.t = 305 ns: Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. En t=10 ns (FETCH): IRWrite=1, PCUpdate=1, ResultSrc=10 (ALU), ALUSrcA=00, ALUSrcB=10 (4).
// 2. Ciclo addi (t=20..40ns): DECODE -> EXEC_I (ALUOp=10, ALUSrcA=10, ALUSrcB=01) -> ALUWB (RegWrite=1, ResultSrc=00).
// 3. Ciclo lw (t=60..90ns): DECODE -> MEMADR (ALUOp=00) -> MEMREAD (AdrSrc=1) -> MEMWB (RegWrite=1, ResultSrc=01).
// 4. Ciclo sw (t=110..130ns): DECODE -> MEMADR -> MEMWRITE (MemWrite=1, AdrSrc=1).
// 5. Ciclo bne (t=150..160ns): DECODE -> BRANCH (Branch=1, ALUOp=01 [SUB], ALUSrcA=10, ALUSrcB=00).
// 6. Ciclo jal (t=180..200ns): DECODE -> JAL1 (PCUpdate=1, ResultSrc=00) -> JAL2 (RegWrite=1, ResultSrc=10, ALUSrcA=01, ALUSrcB=10).
// 7. Ciclo lui (t=220..240ns): DECODE -> EXEC_LUI (ALUOp=11 [PASS-B], ALUSrcB=01) -> ALUWB (RegWrite=1).
// 8. En t=270 ns: HALT activado (halted=1, todas las escrituras deshabilitadas).
// 9. En t=290 ns: rst=1 fuerza la FSM a retornar al estado FETCH.
//////////////////////////////////////////////////////////////////////////////////

module control_fsm_tb;

    // Entradas al DUT
    reg       clk;
    reg       rst;
    reg [6:0] opcode;

    // Salidas del DUT
    wire       PCUpdate;
    wire       Branch;
    wire       IRWrite;
    wire       MemWrite;
    wire       RegWrite;
    wire [1:0] ResultSrc;
    wire [1:0] ALUSrcA;
    wire [1:0] ALUSrcB;
    wire       AdrSrc;
    wire [1:0] ALUOp;
    wire       halted;

    // Instanciación del módulo bajo prueba
    control_fsm uut (
        .clk(clk),
        .rst(rst),
        .opcode(opcode),
        .PCUpdate(PCUpdate),
        .Branch(Branch),
        .IRWrite(IRWrite),
        .MemWrite(MemWrite),
        .RegWrite(RegWrite),
        .ResultSrc(ResultSrc),
        .ALUSrcA(ALUSrcA),
        .ALUSrcB(ALUSrcB),
        .AdrSrc(AdrSrc),
        .ALUOp(ALUOp),
        .halted(halted)
    );

    // Generador de reloj (Período = 10 ns)
    always #5 clk = ~clk;

    initial begin
        // 1. Reset inicial
        clk    = 0;
        rst    = 1;
        opcode = 7'b0000000;

        #15; // posedge t=10ns (Estado FETCH)
        $display("[%0t ns] Test 1 (Reset -> FETCH): IRWrite=%b, PCUpdate=%b, AdrSrc=%b, ALUSrcA=%b, ALUSrcB=%b, ALUOp=%b",
                 $time, IRWrite, PCUpdate, AdrSrc, ALUSrcA, ALUSrcB, ALUOp);

        // 2. Ejecución de instrucción Tipo I (addi - 0x13)
        rst    = 0;
        opcode = 7'b0010011;

        #10; // posedge t=20ns (DECODE)
        $display("[%0t ns] Test 2.1 (addi - DECODE): ALUSrcA=%b, ALUSrcB=%b, ALUOp=%b", $time, ALUSrcA, ALUSrcB, ALUOp);

        #10; // posedge t=30ns (EXEC_I)
        $display("[%0t ns] Test 2.2 (addi - EXEC_I): ALUSrcA=%b, ALUSrcB=%b, ALUOp=%b (Esperado ALUOp: 10)", $time, ALUSrcA, ALUSrcB, ALUOp);

        #10; // posedge t=40ns (ALUWB)
        $display("[%0t ns] Test 2.3 (addi - ALUWB): RegWrite=%b (Esperado: 1), ResultSrc=%b (Esperado: 00)", $time, RegWrite, ResultSrc);

        #10; // posedge t=50ns (Retorno a FETCH)

        // 3. Ejecución de instrucción de Carga (lw - 0x03)
        opcode = 7'b0000011;

        #10; // posedge t=60ns (DECODE)
        #10; // posedge t=70ns (MEMADR)
        $display("[%0t ns] Test 3.1 (lw - MEMADR): ALUSrcA=%b, ALUSrcB=%b, ALUOp=%b", $time, ALUSrcA, ALUSrcB, ALUOp);

        #10; // posedge t=80ns (MEMREAD)
        $display("[%0t ns] Test 3.2 (lw - MEMREAD): AdrSrc=%b (Esperado: 1)", $time, AdrSrc);

        #10; // posedge t=90ns (MEMWB)
        $display("[%0t ns] Test 3.3 (lw - MEMWB): RegWrite=%b (Esperado: 1), ResultSrc=%b (Esperado: 01)", $time, RegWrite, ResultSrc);

        #10; // posedge t=100ns (Retorno a FETCH)

        // 4. Ejecución de instrucción de Almacenamiento (sw - 0x23)
        opcode = 7'b0100011;

        #10; // posedge t=110ns (DECODE)
        #10; // posedge t=120ns (MEMADR)
        #10; // posedge t=130ns (MEMWRITE)
        $display("[%0t ns] Test 4 (sw - MEMWRITE): MemWrite=%b (Esperado: 1), AdrSrc=%b (Esperado: 1)", $time, MemWrite, AdrSrc);

        #10; // posedge t=140ns (Retorno a FETCH)

        // 5. Ejecución de Salto Condicional (bne - 0x63)
        opcode = 7'b1100011;

        #10; // posedge t=150ns (DECODE)
        #10; // posedge t=160ns (BRANCH)
        $display("[%0t ns] Test 5 (bne - BRANCH): Branch=%b (Esperado: 1), ALUOp=%b (Esperado: 01 [SUB])", $time, Branch, ALUOp);

        #10; // posedge t=170ns (Retorno a FETCH)

        // 6. Ejecución de Salto Incondicional (jal - 0x6F)
        opcode = 7'b1101111;

        #10; // posedge t=180ns (DECODE)
        #10; // posedge t=190ns (JAL1)
        $display("[%0t ns] Test 6.1 (jal - JAL1): PCUpdate=%b (Esperado: 1), ResultSrc=%b (Esperado: 00)", $time, PCUpdate, ResultSrc);

        #10; // posedge t=200ns (JAL2)
        $display("[%0t ns] Test 6.2 (jal - JAL2): RegWrite=%b (Esperado: 1), ResultSrc=%b (Esperado: 10), ALUSrcA=%b, ALUSrcB=%b",
                 $time, RegWrite, ResultSrc, ALUSrcA, ALUSrcB);

        #10; // posedge t=210ns (Retorno a FETCH)

        // 7. Ejecución de Carga Superior (lui - 0x37)
        opcode = 7'b0110111;

        #10; // posedge t=220ns (DECODE)
        #10; // posedge t=230ns (EXEC_LUI)
        $display("[%0t ns] Test 7.1 (lui - EXEC_LUI): ALUOp=%b (Esperado: 11 [PASS-B]), ALUSrcB=%b", $time, ALUOp, ALUSrcB);

        #10; // posedge t=240ns (ALUWB)
        $display("[%0t ns] Test 7.2 (lui - ALUWB): RegWrite=%b (Esperado: 1)", $time, RegWrite);

        #10; // posedge t=250ns (Retorno a FETCH)

        // 8. Inserción de Opcode no soportado -> Trampa HALT
        opcode = 7'b1111111;

        #10; // posedge t=260ns (DECODE)
        #10; // posedge t=270ns (HALT)
        $display("[%0t ns] Test 8 (Opcode no valido -> HALT): halted=%b (Esperado: 1)", $time, halted);

        #10; // Permanece en HALT
        $display("[%0t ns] Test 8.1 (Verificacion permanencia HALT): halted=%b", $time, halted);

        // 9. Salida de HALT por Reset activo
        rst = 1;

        #10; // posedge t=290ns (Reinicio a FETCH)
        $display("[%0t ns] Test 9 (Reset desde HALT): halted=%b (Esperado: 0), IRWrite=%b (Esperado: 1)", $time, halted, IRWrite);

        #10;
        $display("--- Simulación del Módulo control_fsm Finalizada Exitosamente ---");
        $finish;
    end

endmodule