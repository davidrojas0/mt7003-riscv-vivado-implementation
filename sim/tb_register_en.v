`timescale 1ns/1ps
//==============================================================================
// Testbench : tb_register_en
// Proyecto  : Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// OBJETIVO
//   Verificar el registro con habilitación y reset síncrono (WIDTH = 32).
//
// ESTÍMULOS (cambios aplicados en el flanco negativo, muestreo en el positivo)
//   1. rst = 1 con en = 1 y d = 0xDEADBEEF           -> q debe quedar en 0
//   2. rst = 0, en = 1, d = 0x12345678               -> q captura 0x12345678
//   3. en = 0, d = 0xFFFFFFFF                        -> q conserva 0x12345678
//   4. en = 1, d = 0xCAFE0001                        -> q captura 0xCAFE0001
//   5. rst = 1 de nuevo                              -> q vuelve a 0 aunque en = 1
//   6. d cambia entre flancos sin que q cambie (no es transparente)
//
// RESULTADOS ESPERADOS
//   q sigue la secuencia 0, 0x12345678, 0x12345678, 0xCAFE0001, 0.
//==============================================================================
module tb_register_en;

    reg         clk = 1'b0;
    reg         rst = 1'b0;
    reg         en  = 1'b0;
    reg  [31:0] d   = 32'd0;
    wire [31:0] q;
    integer     errors = 0;

    register_en #(.WIDTH(32)) dut (.clk(clk), .rst(rst), .en(en), .d(d), .q(q));

    always #5 clk = ~clk;

    task expect_q;
        input [8*24-1:0] name;
        input [31:0] expected;
        begin
            if (q !== expected) begin
                $display("  FAIL %0s: q=0x%08h (esperado 0x%08h)", name, q, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // 1. reset
        @(negedge clk); rst = 1; en = 1; d = 32'hDEADBEEF;
        @(negedge clk); expect_q("reset", 32'd0);

        // 2. captura
        rst = 0; en = 1; d = 32'h12345678;
        @(negedge clk); expect_q("captura", 32'h12345678);

        // 3. enable = 0 conserva
        en = 0; d = 32'hFFFFFFFF;
        @(negedge clk); expect_q("conserva (en=0)", 32'h12345678);

        // 6. d cambia a mitad de ciclo y q no cambia hasta el flanco
        #2 d = 32'hAAAAAAAA;
        #1 expect_q("no transparente", 32'h12345678);

        // 4. captura de nuevo
        en = 1; d = 32'hCAFE0001;
        @(negedge clk); expect_q("captura 2", 32'hCAFE0001);

        // 5. reset con en = 1
        rst = 1; d = 32'h11111111;
        @(negedge clk); expect_q("reset 2", 32'd0);

        if (errors == 0) $display("RESULTADO: PASS  (tb_register_en)");
        else             $display("RESULTADO: FAIL  (tb_register_en: %0d errores)", errors);
        $finish;
    end

endmodule
