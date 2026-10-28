`timescale 1ns/1ps
//==============================================================================
// Módulo : pc_write_logic  (Control de Escritura del PC)
// Proyecto: Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// Funcionalidad:
//   Genera la señal PCWrite que habilita la escritura del registro PC:
//
//       PCWrite = PCUpdate  OR  ( Branch AND (Zero XOR BranchInv) )
//
//   - PCUpdate : escritura incondicional (Fetch: PC+4, y jal: destino).
//   - Branch   : la instrucción actual es un salto condicional (estado Branch).
//   - Zero     : bandera de la ALU (resultado == 0).
//   - BranchInv: invierte la condición. Permite que una misma bandera Zero
//                sirva para ambos saltos del programa:
//        bne -> ALU resta;  salta si Zero = 0  (BranchInv = 1)
//        bge -> ALU slt;    salta si Zero = 1  (BranchInv = 0)
//
// Entradas : pc_update, branch, branch_inv, zero
// Salida   : pc_write
//
// Razón de existir: en el multiciclo el PC se escribe en distintos ciclos y
// por distintos motivos; este bloque centraliza esa decisión (ver diagrama).
//==============================================================================
module pc_write_logic (
    input  wire pc_update,
    input  wire branch,
    input  wire branch_inv,
    input  wire zero,
    output wire pc_write
);

    assign pc_write = pc_update | (branch & (zero ^ branch_inv));

endmodule
