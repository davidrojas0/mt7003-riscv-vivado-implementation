`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: top_rv32i
// Descripción: Módulo principal (Top-Level) que interconecta los 18 submódulos
//              de la microarquitectura multiciclo RV32I.
// Entradas: clk (Reloj del sistema), rst (Reinicio global activo en alto).
// Salidas:  halted (Bandera que indica parada del procesador).
//////////////////////////////////////////////////////////////////////////////////

module top_rv32i (
    input  wire clk,
    input  wire rst,
    output wire halted
);

    // =========================================================================
    // 0. DECLARACIÓN DE BUSES Y SEÑALES INTERNAS
    // =========================================================================
    
    // Buses de 32 bits principales
    wire [31:0] PC_out, OldPC_out;
    wire [31:0] MemAddr, MemReadData;
    wire [31:0] Instr;
    wire [31:0] RegRead1, RegRead2;
    wire [31:0] A_out, B_out;
    wire [31:0] ImmExt_out;
    wire [31:0] SrcA, SrcB, ALUResult_out, ALUOut_out;
    wire [31:0] Data_out;
    wire [31:0] Result_out;

    // Señales de Control (FSM y Decodificadores)
    wire        PCUpdate, Branch, BranchTaken, PCWrite;
    wire        IRWrite, MemWrite, RegWrite, AdrSrc;
    wire [1:0]  ResultSrc, ALUSrcA, ALUSrcB, ALUOp;
    wire [2:0]  ImmSrc, ALUControl;
    wire [3:0]  ByteWrite;
    
    // Banderas de la ALU
    wire        Zero, GE;

    // =========================================================================
    // 1. ZONA DE BÚSQUEDA Y DIRECCIONAMIENTO DE MEMORIA (FETCH)
    // =========================================================================

    // Módulo 1: Program Counter (PC)
    pc u_pc (
        .clk(clk),
        .rst(rst),
        .PCWrite(PCWrite),
        .in_pc_next(Result_out),
        .out_pc(PC_out)
    );

    // Módulo 2: Multiplexor de Dirección de Memoria (AdrSrc)
    mux_adr_src u_mux_adr_src (
        .in_pc(PC_out),
        .in_result(ALUOut_out),
        .AdrSrc(AdrSrc),
        .out_adr(MemAddr)
    );

    // Módulo 3: Memoria Unificada RAM
    memory u_memory (
        .clk(clk),
        .Address(MemAddr),
        .WriteData(B_out),
        .MemWrite(MemWrite),
        .ByteWrite(ByteWrite),
        .ReadData(MemReadData)
    );

    // Módulo 11: Registro de Instrucciones
    reg_instructions u_reg_instructions (
        .clk(clk),
        .rst(rst),
        .IRWrite(IRWrite),
        .in_instruction(MemReadData),
        .out_instruction(Instr)
    );

    // Módulo 10: Registro OldPC
    reg_old_pc u_reg_old_pc (
        .clk(clk),
        .rst(rst),
        .in_pc(PC_out),
        .out_old_pc(OldPC_out)
    );

    // =========================================================================
    // 2. ZONA DE DECODIFICACIÓN Y BANCO DE REGISTROS
    // =========================================================================

    // Módulo 4: Banco de Registros
    registers u_registers (
        .clk(clk),
        .Read_Reg_1(Instr[19:15]),
        .Read_Reg_2(Instr[24:20]),
        .Write_Reg(Instr[11:7]),
        .Write_Data(Result_out),
        .RegWrite(RegWrite),
        .Read_Data_1(RegRead1),
        .Read_Data_2(RegRead2)
    );

    // Módulo 5: Generador de Inmediatos (ImmExt)
    imm_extend u_imm_extend (
        .Instr(Instr[31:7]),
        .ImmSrc(ImmSrc),
        .ImmExt(ImmExt_out)
    );

    // Módulos 13 y 14: Registros Intermedios A y B
    reg_a u_reg_a (
        .clk(clk),
        .rst(rst),
        .in_read_data_1(RegRead1),
        .out_a(A_out)
    );

    reg_b u_reg_b (
        .clk(clk),
        .rst(rst),
        .in_read_data_2(RegRead2),
        .out_b(B_out)
    );

    // =========================================================================
    // 3. ZONA DE EJECUCIÓN (ALU)
    // =========================================================================

    // Módulo 6: Multiplexor ALUSrcA
    mux_alu_src_a u_mux_alu_src_a (
        .in_pc(PC_out),
        .in_old_pc(OldPC_out),
        .in_reg_a(A_out),
        .ALUSrcA(ALUSrcA),
        .out_src_a(SrcA)
    );

    // Módulo 7: Multiplexor ALUSrcB
    mux_alu_src_b u_mux_alu_src_b (
        .in_reg_b(B_out),
        .in_imm_ext(ImmExt_out),
        .in_4(32'd4),
        .ALUSrcB(ALUSrcB),
        .out_src_b(SrcB)
    );

    // Módulo 8: Unidad Aritmética Lógica (ALU)
    alu u_alu (
        .SrcA(SrcA),
        .SrcB(SrcB),
        .ALUControl(ALUControl),
        .ALUResult(ALUResult_out),
        .Zero(Zero),
        .GE(GE)
    );

    // Módulo 15: Registro de Salida de ALU (ALUOut)
    reg_alu_out u_reg_alu_out (
        .clk(clk),
        .rst(rst),
        .in_alu_result(ALUResult_out),
        .out_alu_out(ALUOut_out)
    );

    // =========================================================================
    // 4. ZONA DE MEMORIA DE DATOS Y REESCRITURA (WRITE-BACK)
    // =========================================================================

    // Módulo 12: Registro de Datos leídos de Memoria
    reg_datos u_reg_datos (
        .clk(clk),
        .rst(rst),
        .in_read_data(MemReadData),
        .out_data(Data_out)
    );

    // Módulo 9: Multiplexor ResultSrc
    mux_result_src u_mux_result_src (
        .in_reg_alu(ALUOut_out),
        .in_reg_datos(Data_out),
        .in_alu(ALUResult_out),
        .ResultSrc(ResultSrc),
        .out_result(Result_out)
    );

    // =========================================================================
    // 5. UNIDADES DE CONTROL Y DECODIFICACIÓN
    // =========================================================================

    // Módulo 16: Máquina de Estados Finitos (FSM)
    control_fsm u_control_fsm (
        .clk(clk),
        .rst(rst),
        .opcode(Instr[6:0]),
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

    // Módulo 17: Control de Escritura del PC
    pc_write_logic u_pc_write_logic (
        .PCUpdate(PCUpdate),
        .Branch(Branch),
        .Zero(Zero),
        .GE(GE),
        .funct3(Instr[14:12]),
        .PCWrite(PCWrite)
    );

    // Módulo 18.1: Decodificador de Inmediatos
    imm_decoder u_imm_decoder (
        .opcode(Instr[6:0]),
        .ImmSrc(ImmSrc)
    );

    // Módulo 18.2: Decodificador de ALU
    alu_decoder u_alu_decoder (
        .ALUOp(ALUOp),
        .funct3(Instr[14:12]),
        .ALUControl(ALUControl)
    );

    // Módulo 18.3: Decodificador de Bytes para RAM (Store Byte)
    byte_decoder u_byte_decoder (
        .MemWrite(MemWrite),
        .funct3(Instr[14:12]),
        .addr_low(MemAddr[1:0]), // Los 2 bits menos significativos de la dirección
        .ByteWrite(ByteWrite)
    );

endmodule