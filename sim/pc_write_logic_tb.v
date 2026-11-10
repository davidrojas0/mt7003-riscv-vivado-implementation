`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Testbench: pc_write_logic_tb
//
// OBJETIVO DE LA PRUEBA:
// Validar la síntesis combinacional de la señal PCWrite en el módulo pc_write_logic,
// comprobando la activación incondicional mediante PCUpdate=1, la retención cuando
// no hay intención de salto (PCUpdate=0, Branch=0), y la evaluación precisa de
// saltos condicionales para bne (funct3=001, ~Zero) y bge (funct3=101, GE).
//
// ESTÍMULOS (SECUENCIA EN TIEMPO):
// 1. t = 0  ns : PCUpdate=1, Branch=0, Zero=0, GE=0, funct3=3'b000 (Fetch / JAL: PCUpdate incondicional)
// 2. t = 10 ns : PCUpdate=0, Branch=0, Zero=0, GE=0, funct3=3'b000 (Hold general / Sin salto)
// 3. t = 20 ns : PCUpdate=0, Branch=1, Zero=0, GE=0, funct3=3'b001 (bne tomado: Zero=0)
// 4. t = 30 ns : PCUpdate=0, Branch=1, Zero=1, GE=0, funct3=3'b001 (bne no tomado: Zero=1)
// 5. t = 40 ns : PCUpdate=0, Branch=1, Zero=0, GE=1, funct3=3'b101 (bge tomado: GE=1)
// 6. t = 50 ns : PCUpdate=0, Branch=1, Zero=0, GE=0, funct3=3'b101 (bge no tomado: GE=0)
// 7. t = 60 ns : PCUpdate=0, Branch=1, Zero=0, GE=1, funct3=3'b000 (funct3 no coincidente)
// 8. t = 70 ns : Fin de simulación
//
// RESULTADOS ESPERADOS:
// 1. En t=0  ns : PCWrite = 1 (Activación incondicional por PCUpdate=1).
// 2. En t=10 ns : PCWrite = 0 (Sin actualización ni salto activo).
// 3. En t=20 ns : PCWrite = 1 (bne cumplido: Branch=1, funct3=001, Zero=0).
// 4. En t=30 ns : PCWrite = 0 (bne fallido: Branch=1, funct3=001, Zero=1).
// 5. En t=40 ns : PCWrite = 1 (bge cumplido: Branch=1, funct3=101, GE=1).
// 6. En t=50 ns : PCWrite = 0 (bge fallido: Branch=1, funct3=101, GE=0).
// 7. En t=60 ns : PCWrite = 0 (Funct3 no corresponde a salto condicional válido).
//////////////////////////////////////////////////////////////////////////////////

module pc_write_logic_tb;

    // Entradas al DUT
    reg       PCUpdate;
    reg       Branch;
    reg       Zero;
    reg       GE;
    reg [2:0] funct3;

    // Salida del DUT
    wire PCWrite;

    // Instanciación del módulo bajo prueba
    pc_write_logic uut (
        .PCUpdate(PCUpdate),
        .Branch(Branch),
        .Zero(Zero),
        .GE(GE),
        .funct3(funct3),
        .PCWrite(PCWrite)
    );

    initial begin
        // 1. Incondicional (Fetch / JAL)
        PCUpdate = 1;
        Branch   = 0;
        Zero     = 0;
        GE       = 0;
        funct3   = 3'b000;
        #10;
        $display("[%0t ns] Test 1 (PCUpdate incondicional): PCWrite = %b (Esperado: 1)", $time, PCWrite);

        // 2. Estado Hold (Sin actualización)
        PCUpdate = 0;
        Branch   = 0;
        #10;
        $display("[%0t ns] Test 2 (Hold sin salto): PCWrite = %b (Esperado: 0)", $time, PCWrite);

        // 3. Salto bne exitoso (Zero = 0)
        Branch = 1;
        funct3 = 3'b001; // bne
        Zero   = 0;
        #10;
        $display("[%0t ns] Test 3 (bne tomado): PCWrite = %b (Esperado: 1)", $time, PCWrite);

        // 4. Salto bne fallido (Zero = 1)
        Zero = 1;
        #10;
        $display("[%0t ns] Test 4 (bne no tomado): PCWrite = %b (Esperado: 0)", $time, PCWrite);

        // 5. Salto bge exitoso (GE = 1)
        funct3 = 3'b101; // bge
        Zero   = 0;
        GE     = 1;
        #10;
        $display("[%0t ns] Test 5 (bge tomado): PCWrite = %b (Esperado: 1)", $time, PCWrite);

        // 6. Salto bge fallido (GE = 0)
        GE = 0;
        #10;
        $display("[%0t ns] Test 6 (bge no tomado): PCWrite = %b (Esperado: 0)", $time, PCWrite);

        // 7. Funct3 no soportado para salteado
        funct3 = 3'b000;
        GE     = 1;
        #10;
        $display("[%0t ns] Test 7 (funct3 invalido): PCWrite = %b (Esperado: 0)", $time, PCWrite);

        #10;
        $display("--- Simulación del Módulo pc_write_logic Finalizada Exitosamente ---");
        $finish;
    end

endmodule