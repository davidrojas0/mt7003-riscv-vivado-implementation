`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: alu_decoder_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar la traducción de operaciones genéricas (ALUOp) y específicas (funct3)
// al código de control físico de la ALU (ALUControl), verificando los estados
// de suma, resta, transferencias directas y operaciones bit a bit[cite: 1].
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : ALUOp=00, funct3=XXX (Cargas/Almacenamientos/Fetch)
// 2. t = 10 ns : ALUOp=01, funct3=XXX (Evaluación de saltos)
// 3. t = 20 ns : ALUOp=11, funct3=XXX (LUI - Carga Superior)
// 4. t = 30 ns : ALUOp=10, funct3=000 (addi - Suma)
// 5. t = 40 ns : ALUOp=10, funct3=111 (andi - AND)
// 6. t = 50 ns : ALUOp=10, funct3=001 (slli - Desplazamiento SLL)
// 7. t = 60 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. En t=0  ns : ALUControl = 000 (ADD)
// 2. En t=10 ns : ALUControl = 001 (SUB)
// 3. En t=20 ns : ALUControl = 100 (PASS-B)
// 4. En t=30 ns : ALUControl = 000 (ADD)
// 5. En t=40 ns : ALUControl = 010 (AND)
// 6. En t=50 ns : ALUControl = 011 (SLL)
//////////////////////////////////////////////////////////////////////////////////

module alu_decoder_tb;

    // Entradas al DUT
    reg [1:0] ALUOp;
    reg [2:0] funct3;

    // Salida del DUT
    wire [2:0] ALUControl;

    // Instanciación
    alu_decoder uut (
        .ALUOp(ALUOp),
        .funct3(funct3),
        .ALUControl(ALUControl)
    );

    initial begin
        // 1. Suma incondicional (ALUOp = 00)
        ALUOp  = 2'b00;
        funct3 = 3'b101; // Irrelevante
        #10;
        $display("[%0t ns] Test 1 (ALUOp=00, ADD general): ALUControl=%b (Esperado: 000)", $time, ALUControl);

        // 2. Resta incondicional (ALUOp = 01)
        ALUOp  = 2'b01;
        #10;
        $display("[%0t ns] Test 2 (ALUOp=01, SUB Branch): ALUControl=%b (Esperado: 001)", $time, ALUControl);

        // 3. Paso directo (ALUOp = 11)
        ALUOp  = 2'b11;
        #10;
        $display("[%0t ns] Test 3 (ALUOp=11, LUI): ALUControl=%b (Esperado: 100)", $time, ALUControl);

        // 4. Operación Aritmética Tipo I - addi (ALUOp = 10, funct3 = 000)
        ALUOp  = 2'b10;
        funct3 = 3'b000;
        #10;
        $display("[%0t ns] Test 4 (ALUOp=10, funct3=000 [addi]): ALUControl=%b (Esperado: 000)", $time, ALUControl);

        // 5. Operación Lógica Tipo I - andi (ALUOp = 10, funct3 = 111)
        funct3 = 3'b111;
        #10;
        $display("[%0t ns] Test 5 (ALUOp=10, funct3=111 [andi]): ALUControl=%b (Esperado: 010)", $time, ALUControl);

        // 6. Desplazamiento Tipo I - slli (ALUOp = 10, funct3 = 001)
        funct3 = 3'b001;
        #10;
        $display("[%0t ns] Test 6 (ALUOp=10, funct3=001 [slli]): ALUControl=%b (Esperado: 011)", $time, ALUControl);

        #10;
        $display("--- Simulación del Módulo alu_decoder Finalizada Exitosamente ---");
        $finish;
    end

endmodule