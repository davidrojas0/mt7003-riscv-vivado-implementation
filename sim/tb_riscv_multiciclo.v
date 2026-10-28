`timescale 1ns/1ps
//==============================================================================
// Testbench : tb_riscv_multiciclo   (prueba de la solución completa)
// Proyecto  : Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// OBJETIVO
//   Verificar que el procesador completo ejecuta el programa en C del proyecto
//   (pm_ev_grupos_6_estudiantes.c, 31 instrucciones en instrucciones_main.mem)
//   y deja en memoria exactamente lo que la ejecución del código C produce.
//
// ESTÍMULOS
//   1. rst = 1 durante 2 ciclos de reloj y luego rst = 0.
//   2. El procesador corre solo (única entrada: clk y rst) hasta que halted = 1
//      (la palabra 0x00000000 después del programa es una instrucción ilegal).
//   3. Límite de seguridad: 1000 ciclos.
//   4. Al terminar se vuelca la memoria a "dump_memoria.txt".
//
// RESULTADOS ESPERADOS
//   - halted = 1 tras 174 ciclos (172 de las 42 instrucciones ejecutadas +
//     2 del fetch/decode de la instrucción ilegal).
//   - Memoria de datos (la pila de sp = 0 envuelve a 0xFFFFFFE0 -> índice 248):
//        0xFFFFFFE0 = 0x62000000   char a = 'b'  (byte alto de la palabra)
//        0xFFFFFFE4 = 0x0000C7DF   int *r
//        0xFFFFFFE8 = 0x00000002   i  (el bucle terminó con i = 2)
//        0xFFFFFFEC = 0x00000002   b  ((33 << 1) & 0xF = 2)
//        0xFFFFFFF8 = 0, 0xFFFFFFFC = 0  (s0 y ra guardados)
//   - Registros: sp (x2) = 0xFFFFFFE0, s0 (x8) = 0, a4 (x14) = 2, a5 (x15) = 0.
//   - El programa (palabras 0..30) no fue modificado.
//   - El resto de la memoria de datos permanece en 0.
//
// EJECUCIÓN (desde la carpeta sim/):  ver sim/run_all.sh
//   El archivo instrucciones_main.mem debe estar en el directorio de trabajo
//   del simulador. En Vivado: agregarlo como "simulation source".
//==============================================================================
module tb_riscv_multiciclo;

    localparam EXPECTED_CYCLES = 174;
    localparam PROG_WORDS      = 31;

    reg  clk = 1'b0;
    reg  rst = 1'b1;
    wire halted;

    integer errors = 0;
    integer cycles = 0;
    integer k;
    reg [31:0] prog [0:PROG_WORDS-1];

    riscv_multiciclo #(.ADDR_BITS(8), .INIT_FILE("instrucciones_main.mem")) dut (
        .clk(clk), .rst(rst), .halted(halted)
    );

    always #5 clk = ~clk;

    // Cuenta de ciclos desde que se suelta el reset hasta que se detiene
    always @(posedge clk) begin
        if (!rst && !halted) cycles = cycles + 1;
    end

    task check_word;
        input [8*20-1:0] name;
        input [31:0] got;
        input [31:0] expected;
        begin
            if (got !== expected) begin
                $display("  FAIL %0s: obtenido 0x%08h, esperado 0x%08h", name, got, expected);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        $readmemh("instrucciones_main.mem", prog);

        repeat (2) @(negedge clk);
        rst = 1'b0;

        // Esperar a que se detenga (con límite)
        k = 0;
        while (!halted && k < 1000) begin
            @(negedge clk);
            k = k + 1;
        end
        @(negedge clk);

        if (!halted) begin
            $display("  FAIL: el procesador no se detuvo en 1000 ciclos");
            errors = errors + 1;
        end

        check_word("ciclos",          cycles, EXPECTED_CYCLES);

        // Memoria de datos (índice = (dirección >> 2) & 255)
        check_word("mem[0xFFFFFFE0]", dut.u_dp.u_mem.mem[248], 32'h62000000);
        check_word("mem[0xFFFFFFE4]", dut.u_dp.u_mem.mem[249], 32'h0000C7DF);
        check_word("mem[0xFFFFFFE8]", dut.u_dp.u_mem.mem[250], 32'h00000002);
        check_word("mem[0xFFFFFFEC]", dut.u_dp.u_mem.mem[251], 32'h00000002);
        check_word("mem[0xFFFFFFF0]", dut.u_dp.u_mem.mem[252], 32'h00000000);
        check_word("mem[0xFFFFFFF4]", dut.u_dp.u_mem.mem[253], 32'h00000000);
        check_word("mem[0xFFFFFFF8]", dut.u_dp.u_mem.mem[254], 32'h00000000);
        check_word("mem[0xFFFFFFFC]", dut.u_dp.u_mem.mem[255], 32'h00000000);

        // Registros
        check_word("x2  (sp)", dut.u_dp.u_rf.regs[2],  32'hFFFFFFE0);
        check_word("x8  (s0)", dut.u_dp.u_rf.regs[8],  32'h00000000);
        check_word("x14 (a4)", dut.u_dp.u_rf.regs[14], 32'h00000002);
        check_word("x15 (a5)", dut.u_dp.u_rf.regs[15], 32'h00000000);

        // El programa no debe haberse modificado y el resto debe seguir en cero
        for (k = 0; k < PROG_WORDS; k = k + 1)
            check_word("programa", dut.u_dp.u_mem.mem[k], prog[k]);
        for (k = PROG_WORDS; k < 248; k = k + 1)
            check_word("zona libre", dut.u_dp.u_mem.mem[k], 32'h00000000);

        // Volcado de memoria (solo palabras distintas de cero)
        dut.u_dp.u_mem.dump("dump_memoria.txt", 1'b1);

        if (errors == 0)
            $display("RESULTADO: PASS  (tb_riscv_multiciclo: %0d ciclos, memoria y registros correctos)", cycles);
        else
            $display("RESULTADO: FAIL  (tb_riscv_multiciclo: %0d errores)", errors);
        $finish;
    end

endmodule
