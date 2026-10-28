`timescale 1ns/1ps
//==============================================================================
// Testbench : tb_control_fsm   (Unidad de Control: FSM tipo Moore)
// Proyecto  : Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// OBJETIVO
//   Verificar, estado por estado, las señales de control que genera la FSM
//   para cada una de las 10 instrucciones del subconjunto, el número de
//   ciclos por instrucción y la detención (HALT) ante instrucciones ilegales.
//
// ESTÍMULOS
//   Se aplica reset 2 ciclos. Luego, para cada instrucción, se presentan en
//   las entradas opcode / funct3 / funct7 (como lo haría el registro Instr) y
//   se avanza ciclo a ciclo muestreando las salidas en el flanco negativo.
//     addi, slli, andi : FETCH, DECODE, EXEC_I, ALUWB            (4 ciclos)
//     lw               : FETCH, DECODE, MEMADR, MEMREAD, MEMWB   (5 ciclos)
//     sw, sb           : FETCH, DECODE, MEMADR, MEMWRITE         (4 ciclos)
//     lui              : FETCH, DECODE, EXEC_LUI, ALUWB          (4 ciclos)
//     bne, bge         : FETCH, DECODE, BRANCH                   (3 ciclos)
//     jal              : FETCH, DECODE, JAL1, JAL2               (4 ciclos)
//   Casos de HALT: opcode desconocido (0x00000000), slli con funct7 != 0,
//   lw con funct3 inválido. En HALT la FSM no sale hasta un nuevo reset.
//
// RESULTADOS ESPERADOS
//   Las señales de cada estado coinciden con la tabla de la especificación
//   (docs/ESPECIFICACION.md). Orden de los argumentos de cada chequeo:
//   rw mw bw irw adr | asa asb rs | alu | br bi pcu | imm | halted
//==============================================================================
module tb_control_fsm;

    reg        clk = 1'b0;
    reg        rst = 1'b1;
    reg  [6:0] opcode = 7'd0;
    reg  [2:0] funct3 = 3'd0;
    reg  [6:0] funct7 = 7'd0;
    wire       reg_write, mem_write, byte_write, ir_write, adr_src;
    wire [1:0] alu_src_a, alu_src_b, result_src;
    wire [2:0] alu_ctrl, imm_src;
    wire       branch, branch_inv, pc_update, halted;
    integer    errors = 0;

    control_fsm dut (
        .clk(clk), .rst(rst), .opcode(opcode), .funct3(funct3), .funct7(funct7),
        .reg_write(reg_write), .mem_write(mem_write), .byte_write(byte_write),
        .ir_write(ir_write), .adr_src(adr_src), .alu_src_a(alu_src_a),
        .alu_src_b(alu_src_b), .result_src(result_src), .alu_ctrl(alu_ctrl),
        .imm_src(imm_src), .branch(branch), .branch_inv(branch_inv),
        .pc_update(pc_update), .halted(halted)
    );

    always #5 clk = ~clk;

    // Verifica el estado actual y luego avanza un ciclo
    task st;
        input [8*12-1:0] name;
        input rw, mw, bw, irw, adr;
        input [1:0] asa, asb, rs;
        input [2:0] alu;
        input br, bi, pcu;
        input [2:0] imm;
        input halt;
        reg [20:0] got, exp;
        begin
            got = {reg_write, mem_write, byte_write, ir_write, adr_src, alu_src_a, alu_src_b,
                   result_src, alu_ctrl, branch, branch_inv, pc_update, imm_src, halted};
            exp = {rw, mw, bw, irw, adr, asa, asb, rs, alu, br, bi, pcu, imm, halt};
            if (got !== exp) begin
                $display("  FAIL estado %0s (op=%b f3=%b): obtenido %b, esperado %b",
                         name, opcode, funct3, got, exp);
                errors = errors + 1;
            end
            @(negedge clk);
        end
    endtask

    task set_instr;
        input [6:0] op;
        input [2:0] f3;
        input [6:0] f7;
        begin opcode = op; funct3 = f3; funct7 = f7; #1; end   // #1: deja propagar la lógica combinacional
    endtask

    // FETCH y DECODE son iguales para todas las instrucciones (salvo imm_src)
    task fetch_decode;
        input [2:0] imm;
        begin
            st("FETCH",  0,0,0,1,0, 2'b00,2'b10,2'b10, 3'b000, 0,0,1, imm, 0);
            st("DECODE", 0,0,0,0,0, 2'b01,2'b01,2'b00, 3'b000, 0,0,0, imm, 0);
        end
    endtask

    initial begin
        repeat (2) @(negedge clk);
        rst = 1'b0;

        // addi  (I, ADD)
        set_instr(7'b0010011, 3'b000, 7'b0000000);
        fetch_decode(3'b000);
        st("EXEC_I",   0,0,0,0,0, 2'b10,2'b01,2'b00, 3'b000, 0,0,0, 3'b000, 0);
        st("ALUWB",    1,0,0,0,0, 2'b00,2'b00,2'b00, 3'b000, 0,0,0, 3'b000, 0);

        // slli  (I, SLL)
        set_instr(7'b0010011, 3'b001, 7'b0000000);
        fetch_decode(3'b000);
        st("EXEC_I",   0,0,0,0,0, 2'b10,2'b01,2'b00, 3'b100, 0,0,0, 3'b000, 0);
        st("ALUWB",    1,0,0,0,0, 2'b00,2'b00,2'b00, 3'b000, 0,0,0, 3'b000, 0);

        // andi  (I, AND)
        set_instr(7'b0010011, 3'b111, 7'b0000000);
        fetch_decode(3'b000);
        st("EXEC_I",   0,0,0,0,0, 2'b10,2'b01,2'b00, 3'b010, 0,0,0, 3'b000, 0);
        st("ALUWB",    1,0,0,0,0, 2'b00,2'b00,2'b00, 3'b000, 0,0,0, 3'b000, 0);

        // lw
        set_instr(7'b0000011, 3'b010, 7'b0000000);
        fetch_decode(3'b000);
        st("MEMADR",   0,0,0,0,0, 2'b10,2'b01,2'b00, 3'b000, 0,0,0, 3'b000, 0);
        st("MEMREAD",  0,0,0,0,1, 2'b00,2'b00,2'b00, 3'b000, 0,0,0, 3'b000, 0);
        st("MEMWB",    1,0,0,0,0, 2'b00,2'b00,2'b01, 3'b000, 0,0,0, 3'b000, 0);

        // sw
        set_instr(7'b0100011, 3'b010, 7'b0000000);
        fetch_decode(3'b001);
        st("MEMADR",   0,0,0,0,0, 2'b10,2'b01,2'b00, 3'b000, 0,0,0, 3'b001, 0);
        st("MEMWRITE", 0,1,0,0,1, 2'b00,2'b00,2'b00, 3'b000, 0,0,0, 3'b001, 0);

        // sb  (byte_write = 1)
        set_instr(7'b0100011, 3'b000, 7'b0000000);
        fetch_decode(3'b001);
        st("MEMADR",   0,0,0,0,0, 2'b10,2'b01,2'b00, 3'b000, 0,0,0, 3'b001, 0);
        st("MEMWRITE", 0,1,1,0,1, 2'b00,2'b00,2'b00, 3'b000, 0,0,0, 3'b001, 0);

        // lui
        set_instr(7'b0110111, 3'b100, 7'b0000000);   // funct3 es parte del inmediato: se ignora
        fetch_decode(3'b011);
        st("EXEC_LUI", 0,0,0,0,0, 2'b11,2'b01,2'b00, 3'b000, 0,0,0, 3'b011, 0);
        st("ALUWB",    1,0,0,0,0, 2'b00,2'b00,2'b00, 3'b000, 0,0,0, 3'b011, 0);

        // bne (funct3 = 001): SUB, branch_inv = 1
        set_instr(7'b1100011, 3'b001, 7'b0000000);
        fetch_decode(3'b010);
        st("BRANCH bne", 0,0,0,0,0, 2'b10,2'b00,2'b00, 3'b001, 1,1,0, 3'b010, 0);

        // bge (funct3 = 101): SLT, branch_inv = 0
        set_instr(7'b1100011, 3'b101, 7'b0000000);
        fetch_decode(3'b010);
        st("BRANCH bge", 0,0,0,0,0, 2'b10,2'b00,2'b00, 3'b101, 1,0,0, 3'b010, 0);

        // beq (funct3 = 000): SUB, branch_inv = 0     (extra soportado)
        set_instr(7'b1100011, 3'b000, 7'b0000000);
        fetch_decode(3'b010);
        st("BRANCH beq", 0,0,0,0,0, 2'b10,2'b00,2'b00, 3'b001, 1,0,0, 3'b010, 0);

        // blt (funct3 = 100): SLT, branch_inv = 1     (extra soportado)
        set_instr(7'b1100011, 3'b100, 7'b0000000);
        fetch_decode(3'b010);
        st("BRANCH blt", 0,0,0,0,0, 2'b10,2'b00,2'b00, 3'b101, 1,1,0, 3'b010, 0);

        // jal
        set_instr(7'b1101111, 3'b000, 7'b0000000);
        fetch_decode(3'b100);
        st("JAL1",     0,0,0,0,0, 2'b00,2'b00,2'b00, 3'b000, 0,0,1, 3'b100, 0);
        st("JAL2",     1,0,0,0,0, 2'b01,2'b10,2'b10, 3'b000, 0,0,0, 3'b100, 0);

        // ---------------- HALT: instrucción ilegal (0x00000000) ----------------
        set_instr(7'b0000000, 3'b000, 7'b0000000);
        fetch_decode(3'b000);
        st("HALT 1",   0,0,0,0,0, 2'b00,2'b00,2'b00, 3'b000, 0,0,0, 3'b000, 1);
        st("HALT 2",   0,0,0,0,0, 2'b00,2'b00,2'b00, 3'b000, 0,0,0, 3'b000, 1);
        st("HALT 3",   0,0,0,0,0, 2'b00,2'b00,2'b00, 3'b000, 0,0,0, 3'b000, 1);

        // reset saca de HALT
        rst = 1'b1; @(negedge clk); rst = 1'b0;
        set_instr(7'b0010011, 3'b000, 7'b0000000);
        st("FETCH rst", 0,0,0,1,0, 2'b00,2'b10,2'b10, 3'b000, 0,0,1, 3'b000, 0);

        // slli con funct7 != 0 -> HALT
        set_instr(7'b0010011, 3'b001, 7'b0100000);
        st("DECODE",   0,0,0,0,0, 2'b01,2'b01,2'b00, 3'b000, 0,0,0, 3'b000, 0);
        st("HALT slli", 0,0,0,0,0, 2'b00,2'b00,2'b00, 3'b000, 0,0,0, 3'b000, 1);

        // lw con funct3 inválido -> HALT
        rst = 1'b1; @(negedge clk); rst = 1'b0;
        set_instr(7'b0000011, 3'b001, 7'b0000000);
        st("FETCH",    0,0,0,1,0, 2'b00,2'b10,2'b10, 3'b000, 0,0,1, 3'b000, 0);
        st("DECODE",   0,0,0,0,0, 2'b01,2'b01,2'b00, 3'b000, 0,0,0, 3'b000, 0);
        st("HALT lw",  0,0,0,0,0, 2'b00,2'b00,2'b00, 3'b000, 0,0,0, 3'b000, 1);

        if (errors == 0) $display("RESULTADO: PASS  (tb_control_fsm)");
        else             $display("RESULTADO: FAIL  (tb_control_fsm: %0d errores)", errors);
        $finish;
    end

endmodule
