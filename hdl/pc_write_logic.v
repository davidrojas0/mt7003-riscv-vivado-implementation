`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Módulo: pc_write_logic
// Descripción: Lógica combinacional que evalúa las señales de control de la FSM
//              (PCUpdate, Branch), el campo funct3 de la instrucción y las banderas
//              de la ALU (Zero, GE) para sintetizar la señal global de habilitación
//              de escritura del Program Counter (PCWrite).
//////////////////////////////////////////////////////////////////////////////////

module pc_write_logic (
    input  wire       PCUpdate,
    input  wire       Branch,
    input  wire       Zero,
    input  wire       GE,
    input  wire [2:0] funct3,
    output wire       PCWrite
);

    wire is_bne;
    wire is_bge;
    wire BranchTaken;

    // Discriminación de instrucción de salto condicional según el campo funct3
    assign is_bne = (funct3 == 3'b001); // Branch if Not Equal
    assign is_bge = (funct3 == 3'b101); // Branch if Greater or Equal

    // Evaluación lógica combinacional del cumplimiento del salto
    assign BranchTaken = Branch & ((is_bne & ~Zero) | (is_bge & GE));

    // Ecuación lógica final para la habilitación de escritura en el registro PC
    assign PCWrite = PCUpdate | BranchTaken;

endmodule