`timescale 1ns/1ps
//==============================================================================
// Testbench : tb_regfile
// Proyecto  : Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// OBJETIVO
//   Verificar el banco de 32 registros: escritura síncrona, dos lecturas
//   independientes, x0 siempre en cero y reset.
//
// ESTÍMULOS
//   1. Reset: todos los registros en 0 (se leen x1 y x31).
//   2. Escribir x5 = 33 (we = 1) y x6 = 0xC7DF; leer x5 y x6 por los dos puertos.
//   3. Intentar escribir x0 = 0xFFFFFFFF -> x0 debe seguir en 0.
//   4. we = 0 con wd3 = 0x55555555 hacia x5 -> x5 no cambia.
//   5. Escribir x2 (sp) = 0xFFFFFFE0 y leerlo por el puerto 2.
//   6. Leer el mismo registro por ambos puertos.
//   7. Nuevo reset -> los registros escritos vuelven a 0.
//
// RESULTADOS ESPERADOS
//   Las lecturas devuelven los valores descritos; las escrituras prohibidas
//   (x0 y we = 0) no producen ningún cambio.
//==============================================================================
module tb_regfile;

    reg         clk = 1'b0;
    reg         rst = 1'b0;
    reg         we  = 1'b0;
    reg  [4:0]  a1 = 5'd0, a2 = 5'd0, a3 = 5'd0;
    reg  [31:0] wd3 = 32'd0;
    wire [31:0] rd1, rd2;
    integer     errors = 0;

    regfile dut (.clk(clk), .rst(rst), .we(we), .a1(a1), .a2(a2), .a3(a3),
                 .wd3(wd3), .rd1(rd1), .rd2(rd2));

    always #5 clk = ~clk;

    task expect_rd;
        input [8*24-1:0] name;
        input [31:0] e1, e2;
        begin
            #1;
            if (rd1 !== e1 || rd2 !== e2) begin
                $display("  FAIL %0s: rd1=0x%08h rd2=0x%08h (esperado 0x%08h, 0x%08h)",
                         name, rd1, rd2, e1, e2);
                errors = errors + 1;
            end
        end
    endtask

    task write_reg;
        input [4:0]  r;
        input [31:0] v;
        begin
            @(negedge clk); we = 1; a3 = r; wd3 = v;
            @(negedge clk); we = 0;
        end
    endtask

    initial begin
        // 1. reset
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        a1 = 5'd1; a2 = 5'd31;
        expect_rd("reset", 32'd0, 32'd0);

        // 2. escrituras y lecturas
        write_reg(5'd5, 32'd33);
        write_reg(5'd6, 32'h0000C7DF);
        a1 = 5'd5; a2 = 5'd6;
        expect_rd("x5 y x6", 32'd33, 32'h0000C7DF);

        // 3. x0 no se puede escribir
        write_reg(5'd0, 32'hFFFFFFFF);
        a1 = 5'd0; a2 = 5'd0;
        expect_rd("x0 = 0", 32'd0, 32'd0);

        // 4. we = 0 no escribe
        @(negedge clk); we = 0; a3 = 5'd5; wd3 = 32'h55555555;
        @(negedge clk);
        a1 = 5'd5; a2 = 5'd5;
        expect_rd("we=0 no escribe", 32'd33, 32'd33);

        // 5. sp
        write_reg(5'd2, 32'hFFFFFFE0);
        a1 = 5'd5; a2 = 5'd2;
        expect_rd("x5 y sp", 32'd33, 32'hFFFFFFE0);

        // 6. mismo registro por los dos puertos
        a1 = 5'd6; a2 = 5'd6;
        expect_rd("mismo registro", 32'h0000C7DF, 32'h0000C7DF);

        // 7. reset borra todo
        @(negedge clk); rst = 1;
        @(negedge clk); rst = 0;
        a1 = 5'd5; a2 = 5'd2;
        expect_rd("reset 2", 32'd0, 32'd0);

        if (errors == 0) $display("RESULTADO: PASS  (tb_regfile)");
        else             $display("RESULTADO: FAIL  (tb_regfile: %0d errores)", errors);
        $finish;
    end

endmodule
