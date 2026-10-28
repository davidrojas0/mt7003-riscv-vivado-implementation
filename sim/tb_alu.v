`timescale 1ns/1ps
//==============================================================================
// Testbench : tb_alu
// Proyecto  : Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// OBJETIVO
//   Verificar cada operación de la ALU (ADD, SUB, AND, OR, SLL, SLT), la
//   bandera zero y el comportamiento con códigos reservados.
//
// ESTÍMULOS (se aplica cada vector y se espera 1 ns antes de comparar)
//   ADD : 20 + (-4); 0xFFFFFFFF + 1 (desbordamiento a 0); 0xC000 + 0x7DF
//   SUB : 7 - 7 (zero = 1); 5 - 9 (negativo)
//   AND : 66 & 15 (= 2); 0xFF00FF00 & 0x0FF00FF0
//   OR  : 0xF0 | 0x0F
//   SLL : 33 << 1 (= 66); 1 << 31; el desplazamiento usa solo b[4:0] (b = 33 -> 1)
//   SLT : -1 < 1 (1); 1 < -1 (0); 5 < 5 (0); 0x80000000 < 0x7FFFFFFF (1, con signo)
//   Códigos 110 y 111 -> resultado 0
//
// RESULTADOS ESPERADOS
//   Cada línea compara result y zero con el valor esperado; al final se imprime
//   "RESULTADO: PASS" si no hubo ninguna diferencia.
//==============================================================================
module tb_alu;

    reg  [31:0] a, b;
    reg  [2:0]  op;
    wire [31:0] result;
    wire        zero;
    integer     errors = 0;

    alu dut (.a(a), .b(b), .alu_ctrl(op), .result(result), .zero(zero));

    task check;
        input [8*16-1:0] name;
        input [2:0]  c;
        input [31:0] x, y;
        input [31:0] exp_result;
        input        exp_zero;
        begin
            op = c; a = x; b = y;
            #1;
            if (result !== exp_result || zero !== exp_zero) begin
                $display("  FAIL %0s: a=0x%08h b=0x%08h -> result=0x%08h zero=%b (esperado 0x%08h, %b)",
                         name, x, y, result, zero, exp_result, exp_zero);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        check("ADD 20-4",       3'b000, 32'd20,        32'hFFFFFFFC, 32'd16,        1'b0);
        check("ADD overflow",   3'b000, 32'hFFFFFFFF,  32'd1,        32'd0,         1'b1);
        check("ADD lui+2015",   3'b000, 32'h0000C000,  32'h000007DF, 32'h0000C7DF,  1'b0);
        check("SUB igual",      3'b001, 32'd7,         32'd7,        32'd0,         1'b1);
        check("SUB negativo",   3'b001, 32'd5,         32'd9,        32'hFFFFFFFC,  1'b0);
        check("AND 66&15",      3'b010, 32'd66,        32'd15,       32'd2,         1'b0);
        check("AND mascara",    3'b010, 32'hFF00FF00,  32'h0FF00FF0, 32'h0F000F00,  1'b0);
        check("OR",             3'b011, 32'h000000F0,  32'h0000000F, 32'h000000FF,  1'b0);
        check("SLL 33<<1",      3'b100, 32'd33,        32'd1,        32'd66,        1'b0);
        check("SLL 1<<31",      3'b100, 32'd1,         32'd31,       32'h80000000,  1'b0);
        check("SLL usa b[4:0]", 3'b100, 32'd1,         32'd33,       32'd2,         1'b0);
        check("SLT -1<1",       3'b101, 32'hFFFFFFFF,  32'd1,        32'd1,         1'b0);
        check("SLT 1<-1",       3'b101, 32'd1,         32'hFFFFFFFF, 32'd0,         1'b1);
        check("SLT 5<5",        3'b101, 32'd5,         32'd5,        32'd0,         1'b1);
        check("SLT signo",      3'b101, 32'h80000000,  32'h7FFFFFFF, 32'd1,         1'b0);
        check("reservado 110",  3'b110, 32'd123,       32'd456,      32'd0,         1'b1);
        check("reservado 111",  3'b111, 32'd123,       32'd456,      32'd0,         1'b1);

        if (errors == 0) $display("RESULTADO: PASS  (tb_alu)");
        else             $display("RESULTADO: FAIL  (tb_alu: %0d errores)", errors);
        $finish;
    end

endmodule
