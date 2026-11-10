`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: control_fsm
// Descripción: Máquina de Estados Finitos (FSM) tipo Moore que actúa como el
//              núcleo de coordinación de la microarquitectura multiciclo RV32I.
//              Decodifica el código de operación (opcode) de la instrucción actual
//              y genera las señales de control de alto nivel para coordinar las
//              etapas de Fetch, Decode, Execute, Memory y Write-Back.
//////////////////////////////////////////////////////////////////////////////////

module control_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire [6:0] opcode,
    output reg        PCUpdate,
    output reg        Branch,
    output reg        IRWrite,
    output reg        MemWrite,
    output reg        RegWrite,
    output reg  [1:0] ResultSrc,
    output reg  [1:0] ALUSrcA,
    output reg  [1:0] ALUSrcB,
    output reg        AdrSrc,
    output reg  [1:0] ALUOp,
    output reg        halted
);

    // Definición de codificación de estados (FSM Moore)
    localparam FETCH    = 4'd0,
               DECODE   = 4'd1,
               MEMADR   = 4'd2,
               MEMREAD  = 4'd3,
               MEMWB    = 4'd4,
               MEMWRITE = 4'd5,
               EXEC_I   = 4'd6,
               EXEC_LUI = 4'd7,
               ALUWB    = 4'd8,
               BRANCH   = 4'd9,
               JAL1     = 4'd10,
               JAL2     = 4'd11,
               HALT     = 4'd12;

    // Codificación de Opcodes soportados (RV32I)
    localparam OPCODE_LOAD   = 7'b0000011, // lw
               OPCODE_STORE  = 7'b0100011, // sw, sb
               OPCODE_TYPE_I = 7'b0010011, // addi, slli, andi
               OPCODE_LUI    = 7'b0110111, // lui
               OPCODE_BRANCH = 7'b1100011, // bne, bge
               OPCODE_JAL    = 7'b1101111; // jal

    reg [3:0] current_state, next_state;

    // 1. Registro de estado síncrono con Reset activo en alto
    always @(posedge clk) begin
        if (rst) begin
            current_state <= FETCH;
        end else begin
            current_state <= next_state;
        end
    end

    // 2. Lógica combinacional de transición de estado siguiente
    always @(*) begin
        case (current_state)
            FETCH: begin
                next_state = DECODE;
            end

            DECODE: begin
                case (opcode)
                    OPCODE_LOAD, OPCODE_STORE: next_state = MEMADR;
                    OPCODE_TYPE_I:            next_state = EXEC_I;
                    OPCODE_LUI:               next_state = EXEC_LUI;
                    OPCODE_BRANCH:            next_state = BRANCH;
                    OPCODE_JAL:               next_state = JAL1;
                    default:                  next_state = HALT;
                endcase
            end

            MEMADR: begin
                if (opcode == OPCODE_LOAD)
                    next_state = MEMREAD;
                else
                    next_state = MEMWRITE;
            end

            MEMREAD:  next_state = MEMWB;
            MEMWB:    next_state = FETCH;
            MEMWRITE: next_state = FETCH;
            EXEC_I:   next_state = ALUWB;
            EXEC_LUI: next_state = ALUWB;
            ALUWB:    next_state = FETCH;
            BRANCH:   next_state = FETCH;
            JAL1:     next_state = JAL2;
            JAL2:     next_state = FETCH;

            HALT: begin
                next_state = HALT; // Congelado hasta el reinicio por rst
            end

            default: next_state = FETCH;
        endcase
    end

    // 3. Lógica combinacional de salidas de control (Tipo Moore)
    always @(*) begin
        // Valores por defecto seguros
        PCUpdate  = 1'b0;
        Branch    = 1'b0;
        IRWrite   = 1'b0;
        MemWrite  = 1'b0;
        RegWrite  = 1'b0;
        ResultSrc = 2'b00;
        ALUSrcA   = 2'b00;
        ALUSrcB   = 2'b00;
        AdrSrc    = 1'b0;
        ALUOp     = 2'b00;
        halted    = 1'b0;

        case (current_state)
            FETCH: begin
                IRWrite   = 1'b1;
                PCUpdate  = 1'b1;
                AdrSrc    = 1'b0;
                ALUSrcA   = 2'b00; // PC
                ALUSrcB   = 2'b10; // 4
                ResultSrc = 2'b10; // ALU
                ALUOp     = 2'b00; // ADD
            end

            DECODE: begin
                ALUSrcA   = 2'b01; // OldPC
                ALUSrcB   = 2'b01; // ImmExt
                ALUOp     = 2'b00; // ADD (Precalculo de salto)
            end

            MEMADR: begin
                ALUSrcA   = 2'b10; // Registro A (rs1)
                ALUSrcB   = 2'b01; // ImmExt
                ALUOp     = 2'b00; // ADD (Dirección base + offset)
            end

            MEMREAD: begin
                AdrSrc    = 1'b1;  // ALUOut
            end

            MEMWB: begin
                ResultSrc = 2'b01; // Datos de memoria
                RegWrite  = 1'b1;
            end

            MEMWRITE: begin
                AdrSrc    = 1'b1;  // ALUOut
                MemWrite  = 1'b1;
            end

            EXEC_I: begin
                ALUSrcA   = 2'b10; // Registro A (rs1)
                ALUSrcB   = 2'b01; // ImmExt
                ALUOp     = 2'b10; // Decodificación por funct3
            end

            EXEC_LUI: begin
                ALUSrcA   = 2'b00;
                ALUSrcB   = 2'b01; // ImmExt
                ALUOp     = 2'b11; // PASS-B
            end

            ALUWB: begin
                ResultSrc = 2'b00; // ALUOut
                RegWrite  = 1'b1;
            end

            BRANCH: begin
                ALUSrcA   = 2'b10; // Registro A (rs1)
                ALUSrcB   = 2'b00; // Registro B (rs2)
                ALUOp     = 2'b01; // SUB (Comparación)
                Branch    = 1'b1;
            end

            JAL1: begin
                PCUpdate  = 1'b1;
                ResultSrc = 2'b00; // ALUOut (Dirección objetivo precalculada en DECODE)
            end

            JAL2: begin
                ALUSrcA   = 2'b01; // OldPC
                ALUSrcB   = 2'b10; // 4
                ResultSrc = 2'b10; // ALU
                RegWrite  = 1'b1; // 1
                ALUOp     = 2'b00; // ADD (OldPC + 4 en registro enlace rd)
            end

            HALT: begin
                halted    = 1'b1;
            end

            default: ;
        endcase
    end

endmodule