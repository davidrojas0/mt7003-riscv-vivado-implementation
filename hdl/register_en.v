`timescale 1ns/1ps
//==============================================================================
// Módulo : register_en
// Proyecto: Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// Funcionalidad:
//   Registro de WIDTH bits con habilitación (enable) y reset síncrono. Captura
//   d en el flanco positivo del reloj solo si en = 1; si en = 0 conserva su valor.
//
// Entradas : clk, rst (síncrono, activo en alto), en, d[WIDTH-1:0]
// Salidas  : q[WIDTH-1:0]
// Parámetro: WIDTH (por defecto 32)
//
// Razón de existir: la microarquitectura multiciclo necesita guardar resultados
// intermedios entre ciclos. Este único módulo genera todos los registros del
// diagrama: PC, PC Anterior (OldPC), Registro de Instrucciones, Registro de
// Datos, A, B y Registro Salida ALU.
//   - PC            : en = PCWrite
//   - OldPC y Instr : en = IRWrite
//   - Data, A, B, ALUOut: en = 1 (capturan en cada ciclo)
//==============================================================================
module register_en #(
    parameter WIDTH = 32
) (
    input  wire             clk,
    input  wire             rst,
    input  wire             en,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);

    always @(posedge clk) begin
        if (rst)
            q <= {WIDTH{1'b0}};
        else if (en)
            q <= d;
    end

endmodule
