`timescale 1ns/1ps
//==============================================================================
// Módulo : control_fsm  (Unidad de Control: FSM + decodificadores)
// Proyecto: Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// Funcionalidad:
//   Máquina de estados tipo Moore que recuerda en qué paso de la instrucción
//   va y genera todas las señales de control de la ruta de datos. Incluye el
//   decodificador de instrucción (imm_src y alu_ctrl a partir de opcode/funct).
//
// Entradas:
//   clk, rst (síncrono: vuelve al estado FETCH)
//   opcode [6:0]  Instr[6:0]
//   funct3 [2:0]  Instr[14:12]
//   funct7 [6:0]  Instr[31:25]  (solo se usa para validar slli: debe ser 0)
//
// Salidas (todas en 0 salvo lo indicado en cada estado):
//   reg_write   RegWrite   habilita escritura en el banco de registros
//   mem_write   MemWrite   habilita escritura en memoria
//   byte_write  ByteWrite  escritura de un byte (sb)
//   ir_write    IRWrite    captura Instr y OldPC
//   adr_src     AdrSrc     0: dirección = PC   1: dirección = Result
//   alu_src_a   ALUSrcA    00 PC | 01 OldPC | 10 A | 11 cero
//   alu_src_b   ALUSrcB    00 B  | 01 inmediato | 10 constante 4 | 11 cero
//   result_src  ResultSrc  00 ALUOut | 01 Data | 10 resultado directo de la ALU
//   alu_ctrl    ALUCtrl    ver alu.v
//   imm_src     ImmSrc     ver immgen.v (depende solo del opcode)
//   branch      Branch     estado de salto condicional
//   branch_inv  BranchInv  invierte la condición Zero (ver pc_write_logic.v)
//   pc_update   PCUpdate   escritura incondicional del PC
//   halted                 1 en el estado HALT
//
// Estados y ciclos por instrucción (ver docs/ESPECIFICACION.md):
//   addi/slli/andi : FETCH, DECODE, EXEC_I, ALUWB                    (4 ciclos)
//   lui            : FETCH, DECODE, EXEC_LUI, ALUWB                  (4 ciclos)
//   lw             : FETCH, DECODE, MEMADR, MEMREAD, MEMWB           (5 ciclos)
//   sw / sb        : FETCH, DECODE, MEMADR, MEMWRITE                 (4 ciclos)
//   bne / bge      : FETCH, DECODE, BRANCH                           (3 ciclos)
//   jal            : FETCH, DECODE, JAL1, JAL2                       (4 ciclos)
//   cualquier otra instrucción, o campos funct no soportados -> HALT.
//   Como la palabra 0x00000000 es una instrucción ilegal en RISC-V, el
//   procesador se detiene solo al terminar el programa.
//
// Razón de existir: en el multiciclo la misma ruta de datos se usa de forma
// distinta en cada ciclo; esta FSM decide cuál.
//==============================================================================
module control_fsm (
    input  wire       clk,
    input  wire       rst,
    input  wire [6:0] opcode,
    input  wire [2:0] funct3,
    input  wire [6:0] funct7,
    output reg        reg_write,
    output reg        mem_write,
    output reg        byte_write,
    output reg        ir_write,
    output reg        adr_src,
    output reg  [1:0] alu_src_a,
    output reg  [1:0] alu_src_b,
    output reg  [1:0] result_src,
    output reg  [2:0] alu_ctrl,
    output reg  [2:0] imm_src,
    output reg        branch,
    output reg        branch_inv,
    output reg        pc_update,
    output wire       halted
);

    // Opcodes soportados
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_IMM    = 7'b0010011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;

    // Códigos de la ALU (iguales a alu.v)
    localparam ALU_ADD = 3'b000;
    localparam ALU_SUB = 3'b001;
    localparam ALU_AND = 3'b010;
    localparam ALU_SLL = 3'b100;
    localparam ALU_SLT = 3'b101;

    // Estados
    localparam [3:0] S_FETCH    = 4'd0;
    localparam [3:0] S_DECODE   = 4'd1;
    localparam [3:0] S_MEMADR   = 4'd2;
    localparam [3:0] S_MEMREAD  = 4'd3;
    localparam [3:0] S_MEMWB    = 4'd4;
    localparam [3:0] S_MEMWRITE = 4'd5;
    localparam [3:0] S_EXEC_I   = 4'd6;
    localparam [3:0] S_EXEC_LUI = 4'd7;
    localparam [3:0] S_ALUWB    = 4'd8;
    localparam [3:0] S_BRANCH   = 4'd9;
    localparam [3:0] S_JAL1     = 4'd10;
    localparam [3:0] S_JAL2     = 4'd11;
    localparam [3:0] S_HALT     = 4'd15;

    reg [3:0] state, next_state;

    // Validación de los campos funct soportados
    wire op_imm_ok = (funct3 == 3'b000) ||                              // addi
                     (funct3 == 3'b001 && funct7 == 7'b0000000) ||      // slli
                     (funct3 == 3'b111);                                // andi
    wire load_ok   = (funct3 == 3'b010);                                // lw
    wire store_ok  = (funct3 == 3'b010) || (funct3 == 3'b000);          // sw, sb
    wire branch_ok = (funct3 == 3'b000) || (funct3 == 3'b001) ||        // beq, bne
                     (funct3 == 3'b100) || (funct3 == 3'b101);          // blt, bge

    assign halted = (state == S_HALT);

    //--------------------------------------------------------------------------
    // Registro de estado
    //--------------------------------------------------------------------------
    always @(posedge clk) begin
        if (rst) state <= S_FETCH;
        else     state <= next_state;
    end

    //--------------------------------------------------------------------------
    // Lógica de próximo estado
    //--------------------------------------------------------------------------
    always @(*) begin
        case (state)
            S_FETCH:  next_state = S_DECODE;
            S_DECODE: begin
                case (opcode)
                    OP_IMM:    next_state = op_imm_ok ? S_EXEC_I : S_HALT;
                    OP_LOAD:   next_state = load_ok   ? S_MEMADR : S_HALT;
                    OP_STORE:  next_state = store_ok  ? S_MEMADR : S_HALT;
                    OP_LUI:    next_state = S_EXEC_LUI;
                    OP_BRANCH: next_state = branch_ok ? S_BRANCH : S_HALT;
                    OP_JAL:    next_state = S_JAL1;
                    default:   next_state = S_HALT;
                endcase
            end
            S_MEMADR:   next_state = (opcode == OP_LOAD) ? S_MEMREAD : S_MEMWRITE;
            S_MEMREAD:  next_state = S_MEMWB;
            S_MEMWB:    next_state = S_FETCH;
            S_MEMWRITE: next_state = S_FETCH;
            S_EXEC_I:   next_state = S_ALUWB;
            S_EXEC_LUI: next_state = S_ALUWB;
            S_ALUWB:    next_state = S_FETCH;
            S_BRANCH:   next_state = S_FETCH;
            S_JAL1:     next_state = S_JAL2;
            S_JAL2:     next_state = S_FETCH;
            default:    next_state = S_HALT;
        endcase
    end

    //--------------------------------------------------------------------------
    // Señales de control por estado (Moore)
    //--------------------------------------------------------------------------
    always @(*) begin
        // Valores por defecto: nada se escribe
        reg_write  = 1'b0;
        mem_write  = 1'b0;
        byte_write = 1'b0;
        ir_write   = 1'b0;
        adr_src    = 1'b0;
        alu_src_a  = 2'b00;
        alu_src_b  = 2'b00;
        result_src = 2'b00;
        alu_ctrl   = ALU_ADD;
        branch     = 1'b0;
        branch_inv = 1'b0;
        pc_update  = 1'b0;

        case (state)
            // PC+4 -> PC ; Memoria[PC] -> Instr ; PC -> OldPC
            S_FETCH: begin
                ir_write   = 1'b1;
                alu_src_a  = 2'b00;          // PC
                alu_src_b  = 2'b10;          // 4
                alu_ctrl   = ALU_ADD;
                result_src = 2'b10;          // resultado directo de la ALU
                pc_update  = 1'b1;
            end
            // A <- rs1 ; B <- rs2 ; ALUOut <- OldPC + inmediato (destino de salto)
            S_DECODE: begin
                alu_src_a  = 2'b01;          // OldPC
                alu_src_b  = 2'b01;          // inmediato
            end
            // ALUOut <- A + inmediato (dirección efectiva)
            S_MEMADR: begin
                alu_src_a  = 2'b10;          // A
                alu_src_b  = 2'b01;          // inmediato
            end
            // Data <- Memoria[ALUOut]
            S_MEMREAD: begin
                adr_src    = 1'b1;           // dirección = Result = ALUOut
            end
            // rd <- Data
            S_MEMWB: begin
                result_src = 2'b01;          // Data
                reg_write  = 1'b1;
            end
            // Memoria[ALUOut] <- B (palabra o byte)
            S_MEMWRITE: begin
                adr_src    = 1'b1;
                mem_write  = 1'b1;
                byte_write = (funct3 == 3'b000);   // sb
            end
            // ALUOut <- A op inmediato
            S_EXEC_I: begin
                alu_src_a  = 2'b10;          // A
                alu_src_b  = 2'b01;          // inmediato
                case (funct3)
                    3'b001:  alu_ctrl = ALU_SLL;   // slli
                    3'b111:  alu_ctrl = ALU_AND;   // andi
                    default: alu_ctrl = ALU_ADD;   // addi
                endcase
            end
            // ALUOut <- 0 + inmediato U
            S_EXEC_LUI: begin
                alu_src_a  = 2'b11;          // cero
                alu_src_b  = 2'b01;          // inmediato
            end
            // rd <- ALUOut
            S_ALUWB: begin
                result_src = 2'b00;
                reg_write  = 1'b1;
            end
            // Compara A con B; si se cumple, PC <- ALUOut (destino calculado en Decode)
            S_BRANCH: begin
                alu_src_a  = 2'b10;          // A
                alu_src_b  = 2'b00;          // B
                alu_ctrl   = funct3[2] ? ALU_SLT : ALU_SUB;
                branch     = 1'b1;
                branch_inv = funct3[0] ^ funct3[2];
                result_src = 2'b00;          // destino = ALUOut
            end
            // PC <- ALUOut (destino calculado en Decode)
            S_JAL1: begin
                result_src = 2'b00;
                pc_update  = 1'b1;
            end
            // rd <- OldPC + 4  (dirección de retorno)
            S_JAL2: begin
                alu_src_a  = 2'b01;          // OldPC
                alu_src_b  = 2'b10;          // 4
                result_src = 2'b10;
                reg_write  = 1'b1;
            end
            default: ;                       // S_HALT: no hace nada
        endcase
    end

    //--------------------------------------------------------------------------
    // Decodificador de formato de inmediato (depende solo del opcode)
    //--------------------------------------------------------------------------
    always @(*) begin
        case (opcode)
            OP_STORE:  imm_src = 3'b001;   // S
            OP_BRANCH: imm_src = 3'b010;   // B
            OP_LUI:    imm_src = 3'b011;   // U
            OP_JAL:    imm_src = 3'b100;   // J
            default:   imm_src = 3'b000;   // I (addi, slli, andi, lw)
        endcase
    end

endmodule
