`timescale 1ns/1ps
//==============================================================================
// Módulo : datapath  (Ruta de datos multiciclo)
// Proyecto: Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// Funcionalidad:
//   Implementa la ruta de datos del diagrama multiciclo v2: PC, memoria única,
//   registros intermedios (OldPC, Instr, Data, A, B, ALUOut), banco de
//   registros, generador de inmediatos, ALU y los multiplexores. No toma
//   decisiones: todas las selecciones llegan de la unidad de control.
//
// Entradas de control (ver control_fsm.v):
//   pc_write, ir_write, adr_src, mem_write, byte_write, reg_write,
//   alu_src_a[1:0], alu_src_b[1:0], alu_ctrl[2:0], imm_src[2:0], result_src[1:0]
// Salidas hacia el control:
//   opcode[6:0] = Instr[6:0]   funct3[2:0] = Instr[14:12]
//   funct7[6:0] = Instr[31:25] zero = bandera de la ALU
//
// Multiplexores:
//   AdrSrc    0: PC | 1: Result
//   ALUSrcA   00: PC | 01: OldPC | 10: A | 11: 0
//   ALUSrcB   00: B  | 01: ImmExt | 10: 4 | 11: 0
//   ResultSrc 00: ALUOut | 01: Data | 10: salida directa de la ALU
//   Result alimenta: entrada del PC, dirección de memoria (AdrSrc=1) y el
//   dato de escritura del banco de registros.
//
// Razón de existir: agrupa todo el hardware de datos para que la unidad de
// control quede claramente separada, como pide el enunciado.
//==============================================================================
module datapath #(
    parameter ADDR_BITS = 8,
    parameter INIT_FILE = "instrucciones_main.mem"
) (
    input  wire        clk,
    input  wire        rst,
    // Control
    input  wire        pc_write,
    input  wire        ir_write,
    input  wire        adr_src,
    input  wire        mem_write,
    input  wire        byte_write,
    input  wire        reg_write,
    input  wire [1:0]  alu_src_a,
    input  wire [1:0]  alu_src_b,
    input  wire [2:0]  alu_ctrl,
    input  wire [2:0]  imm_src,
    input  wire [1:0]  result_src,
    // Hacia el control
    output wire [6:0]  opcode,
    output wire [2:0]  funct3,
    output wire [6:0]  funct7,
    output wire        zero
);

    // Registros
    wire [31:0] pc, old_pc, instr, data_reg, a_reg, b_reg, alu_out_reg;
    // Combinacionales
    wire [31:0] mem_addr, mem_rdata, rd1, rd2, imm_ext, alu_result;
    reg  [31:0] src_a, src_b, result;

    // --- Campos de la instrucción -------------------------------------------
    assign opcode = instr[6:0];
    assign funct3 = instr[14:12];
    assign funct7 = instr[31:25];

    // --- PC y memoria --------------------------------------------------------
    register_en #(.WIDTH(32)) u_pc (
        .clk(clk), .rst(rst), .en(pc_write), .d(result), .q(pc)
    );

    assign mem_addr = adr_src ? result : pc;

    memory #(.ADDR_BITS(ADDR_BITS), .INIT_FILE(INIT_FILE)) u_mem (
        .clk(clk), .mem_write(mem_write), .byte_write(byte_write),
        .addr(mem_addr), .write_data(b_reg), .read_data(mem_rdata)
    );

    // --- Registros de instrucción y datos ------------------------------------
    register_en #(.WIDTH(32)) u_instr (
        .clk(clk), .rst(rst), .en(ir_write), .d(mem_rdata), .q(instr)
    );
    register_en #(.WIDTH(32)) u_oldpc (
        .clk(clk), .rst(rst), .en(ir_write), .d(pc), .q(old_pc)
    );
    register_en #(.WIDTH(32)) u_data (
        .clk(clk), .rst(rst), .en(1'b1), .d(mem_rdata), .q(data_reg)
    );

    // --- Banco de registros, A y B -------------------------------------------
    regfile u_rf (
        .clk(clk), .rst(rst), .we(reg_write),
        .a1(instr[19:15]), .a2(instr[24:20]), .a3(instr[11:7]),
        .wd3(result), .rd1(rd1), .rd2(rd2)
    );
    register_en #(.WIDTH(32)) u_a (
        .clk(clk), .rst(rst), .en(1'b1), .d(rd1), .q(a_reg)
    );
    register_en #(.WIDTH(32)) u_b (
        .clk(clk), .rst(rst), .en(1'b1), .d(rd2), .q(b_reg)
    );

    // --- Generador de inmediatos ---------------------------------------------
    immgen u_imm (
        .instr(instr[31:7]), .imm_src(imm_src), .imm(imm_ext)
    );

    // --- ALU y sus multiplexores ---------------------------------------------
    always @(*) begin
        case (alu_src_a)
            2'b00:   src_a = pc;
            2'b01:   src_a = old_pc;
            2'b10:   src_a = a_reg;
            default: src_a = 32'd0;
        endcase
    end

    always @(*) begin
        case (alu_src_b)
            2'b00:   src_b = b_reg;
            2'b01:   src_b = imm_ext;
            2'b10:   src_b = 32'd4;
            default: src_b = 32'd0;
        endcase
    end

    alu u_alu (
        .a(src_a), .b(src_b), .alu_ctrl(alu_ctrl),
        .result(alu_result), .zero(zero)
    );

    register_en #(.WIDTH(32)) u_aluout (
        .clk(clk), .rst(rst), .en(1'b1), .d(alu_result), .q(alu_out_reg)
    );

    // --- Selección del resultado ---------------------------------------------
    always @(*) begin
        case (result_src)
            2'b00:   result = alu_out_reg;
            2'b01:   result = data_reg;
            2'b10:   result = alu_result;
            default: result = 32'd0;
        endcase
    end

endmodule
