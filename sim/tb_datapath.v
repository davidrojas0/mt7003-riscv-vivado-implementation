`timescale 1ns/1ps
//==============================================================================
// Testbench : tb_datapath   (ruta de datos, SIN unidad de control)
// Proyecto  : Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// OBJETIVO
//   Verificar la interconexión de la ruta de datos (PC, OldPC, Instr, Data,
//   A, B, ALUOut, banco de registros, ImmGen, ALU, memoria y multiplexores)
//   manejando las señales de control "a mano" ciclo a ciclo, como lo haría la
//   FSM.  Así se prueba la ruta de datos de forma independiente.
//
// PROGRAMA (se escribe en la memoria sin usar archivo .mem)
//   0x00: addi x5, x0, 33     0x02100293
//   0x04: sw   x5, 16(x0)     0x00502823
//   0x08: lw   x6, 16(x0)     0x01002303   (lee la palabra 0x10 que escribió sw)
//
// ESTÍMULOS (un conjunto de señales de control por ciclo)
//   addi : FETCH, DECODE, EXEC_I, ALUWB
//   sw   : FETCH, DECODE, MEMADR, MEMWRITE
//   lw   : FETCH, DECODE, MEMADR, MEMREAD, MEMWB
//
// RESULTADOS ESPERADOS
//   - Tras FETCH de addi: PC = 4, Instr = 0x02100293, OldPC = 0, opcode = 0x13
//   - Tras ALUWB: x5 = 33
//   - Tras FETCH de sw:  PC = 8, OldPC = 4;  tras DECODE: B = 33
//   - Tras MEMADR: ALUOut = 16;  tras MEMWRITE: memoria[0x10] = 33
//   - Tras MEMREAD: Data = 33;  tras MEMWB: x6 = 33
//==============================================================================
module tb_datapath;

    reg        clk = 1'b0;
    reg        rst = 1'b1;
    reg        pc_write = 0, ir_write = 0, adr_src = 0, mem_write = 0, byte_write = 0, reg_write = 0;
    reg  [1:0] alu_src_a = 0, alu_src_b = 0, result_src = 0;
    reg  [2:0] alu_ctrl = 0, imm_src = 0;
    wire [6:0] opcode, funct7;
    wire [2:0] funct3;
    wire       zero;
    integer    errors = 0;

    datapath #(.ADDR_BITS(8), .INIT_FILE("")) dut (
        .clk(clk), .rst(rst),
        .pc_write(pc_write), .ir_write(ir_write), .adr_src(adr_src),
        .mem_write(mem_write), .byte_write(byte_write), .reg_write(reg_write),
        .alu_src_a(alu_src_a), .alu_src_b(alu_src_b), .alu_ctrl(alu_ctrl),
        .imm_src(imm_src), .result_src(result_src),
        .opcode(opcode), .funct3(funct3), .funct7(funct7), .zero(zero)
    );

    always #5 clk = ~clk;

    // Aplica un conjunto de señales de control durante un ciclo completo
    task drive;
        input pcw, irw, adr, mw, bw, rw;
        input [1:0] asa, asb;
        input [2:0] alu, imm;
        input [1:0] rs;
        begin
            pc_write = pcw; ir_write = irw; adr_src = adr; mem_write = mw;
            byte_write = bw; reg_write = rw; alu_src_a = asa; alu_src_b = asb;
            alu_ctrl = alu; imm_src = imm; result_src = rs;
            @(negedge clk);
            // inactivar escrituras para el siguiente ciclo
            pc_write = 0; ir_write = 0; mem_write = 0; byte_write = 0; reg_write = 0;
        end
    endtask

    task check;
        input [8*20-1:0] name;
        input [31:0] got, expected;
        begin
            if (got !== expected) begin
                $display("  FAIL %0s: obtenido 0x%08h, esperado 0x%08h", name, got, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        #1;
        dut.u_mem.mem[0] = 32'h02100293;   // addi x5, x0, 33
        dut.u_mem.mem[1] = 32'h00502823;   // sw   x5, 16(x0)
        dut.u_mem.mem[2] = 32'h01002303;   // lw   x6, 16(x0)

        repeat (2) @(negedge clk);
        rst = 1'b0;

        //----------------------------- addi x5, x0, 33 ------------------------
        //     pcw irw adr mw bw rw | asa  asb   | alu   imm   | rs
        drive(1,  1,  0,  0, 0, 0,   2'b00,2'b10, 3'b000,3'b000, 2'b10);  // FETCH
        check("PC tras FETCH",  dut.pc,     32'd4);
        check("Instr addi",     dut.instr,  32'h02100293);
        check("OldPC",          dut.old_pc, 32'd0);
        check("opcode",         {25'd0, opcode}, 32'h13);
        drive(0,  0,  0,  0, 0, 0,   2'b01,2'b01, 3'b000,3'b000, 2'b00);  // DECODE
        drive(0,  0,  0,  0, 0, 0,   2'b10,2'b01, 3'b000,3'b000, 2'b00);  // EXEC_I
        check("ALUOut addi",    dut.alu_out_reg, 32'd33);
        drive(0,  0,  0,  0, 0, 1,   2'b00,2'b00, 3'b000,3'b000, 2'b00);  // ALUWB
        check("x5",             dut.u_rf.regs[5], 32'd33);

        //----------------------------- sw x5, 16(x0) ---------------------------
        drive(1,  1,  0,  0, 0, 0,   2'b00,2'b10, 3'b000,3'b001, 2'b10);  // FETCH
        check("PC tras FETCH sw", dut.pc,     32'd8);
        check("OldPC sw",         dut.old_pc, 32'd4);
        check("Instr sw",         dut.instr,  32'h00502823);
        drive(0,  0,  0,  0, 0, 0,   2'b01,2'b01, 3'b000,3'b001, 2'b00);  // DECODE
        check("B = x5",           dut.b_reg,  32'd33);
        drive(0,  0,  0,  0, 0, 0,   2'b10,2'b01, 3'b000,3'b001, 2'b00);  // MEMADR
        check("ALUOut = 16",      dut.alu_out_reg, 32'd16);
        drive(0,  0,  1,  1, 0, 0,   2'b00,2'b00, 3'b000,3'b001, 2'b00);  // MEMWRITE
        check("mem[0x10]",        dut.u_mem.mem[4], 32'd33);

        //----------------------------- lw x6, 16(x0) --------------------------
        drive(1,  1,  0,  0, 0, 0,   2'b00,2'b10, 3'b000,3'b000, 2'b10);  // FETCH
        check("Instr lw",         dut.instr,  32'h01002303);
        drive(0,  0,  0,  0, 0, 0,   2'b01,2'b01, 3'b000,3'b000, 2'b00);  // DECODE
        drive(0,  0,  0,  0, 0, 0,   2'b10,2'b01, 3'b000,3'b000, 2'b00);  // MEMADR
        check("ALUOut lw = 16",   dut.alu_out_reg, 32'd16);
        drive(0,  0,  1,  0, 0, 0,   2'b00,2'b00, 3'b000,3'b000, 2'b00);  // MEMREAD
        check("Data = 33",        dut.data_reg, 32'd33);
        drive(0,  0,  0,  0, 0, 1,   2'b00,2'b00, 3'b000,3'b000, 2'b01);  // MEMWB
        check("x6",               dut.u_rf.regs[6], 32'd33);

        if (errors == 0) $display("RESULTADO: PASS  (tb_datapath)");
        else             $display("RESULTADO: FAIL  (tb_datapath: %0d errores)", errors);
        $finish;
    end

endmodule
