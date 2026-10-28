`timescale 1ns/1ps
//==============================================================================
// Testbench : tb_memory   (memoria unificada de instrucciones y datos)
// Proyecto  : Microarquitectura RV32I multiciclo - MT-7003 - Grupo N° 3
//------------------------------------------------------------------------------
// OBJETIVO
//   Verificar lectura asíncrona, escritura de palabra y de byte (sb), el
//   direccionamiento por palabra con "wrap-around" y el VOLCADO DE MEMORIA
//   (task dump) que pide el enunciado.  Se instancia con ADDR_BITS = 4
//   (16 palabras) y sin archivo de inicialización para que el resultado sea
//   fácil de revisar; la carga con $readmemh se prueba en tb_riscv_multiciclo.
//
// ESTÍMULOS
//   1. Lectura tras inicializar: todas las palabras en 0.
//   2. Escritura de palabra: mem[0x04] = 0x11223344 (lectura inmediata/asíncrona
//      después del flanco).
//   3. mem_write = 0 con otro dato: no cambia nada.
//   4. Escritura de byte (byte_write = 1) en las 4 posiciones 0x08..0x0B:
//      cada una modifica SOLO su byte.
//      (sb escribe el byte bajo del dato: 0xDD, 0xCC, 0xBB, 0xAA en 0x8..0xB).
//   6. Wrap-around: dirección 0xFFFFFFC4 (índice 1) lee la misma palabra que 0x4.
//   7. Dump con only_nonzero = 1 y con only_nonzero = 0 y lectura del archivo.
//
// RESULTADOS ESPERADOS
//   - mem[0x04] = 0x11223344; mem[0x08] = 0xAABBCCDD (compuesta byte a byte)
//   - lectura en 0xFFFFFFC4 = 0x11223344
//   - dump_tb_memoria.txt (solo no-ceros) contiene exactamente las líneas
//        0x4 0x11223344
//        0x8 0xaabbccdd
//==============================================================================
module tb_memory;

    reg         clk = 1'b0;
    reg         mem_write = 1'b0, byte_write = 1'b0;
    reg  [31:0] addr = 32'd0, write_data = 32'd0;
    wire [31:0] read_data;
    integer     errors = 0;
    integer     fd, n;
    reg  [31:0] fa, fd_data;

    memory #(.ADDR_BITS(4), .INIT_FILE("")) dut (
        .clk(clk), .mem_write(mem_write), .byte_write(byte_write),
        .addr(addr), .write_data(write_data), .read_data(read_data)
    );

    always #5 clk = ~clk;

    task expect_read;
        input [8*24-1:0] name;
        input [31:0] a;
        input [31:0] expected;
        begin
            addr = a; #1;
            if (read_data !== expected) begin
                $display("  FAIL %0s: mem[0x%08h]=0x%08h (esperado 0x%08h)", name, a, read_data, expected);
                errors = errors + 1;
            end
        end
    endtask

    task write_mem;
        input [31:0] a;
        input [31:0] d;
        input        is_byte;
        begin
            @(negedge clk); addr = a; write_data = d; byte_write = is_byte; mem_write = 1;
            @(negedge clk); mem_write = 0; byte_write = 0;
        end
    endtask

    initial begin
        expect_read("inicial 0x0", 32'h0, 32'h0);
        expect_read("inicial 0x3C", 32'h3C, 32'h0);

        write_mem(32'h4, 32'h11223344, 1'b0);
        expect_read("palabra 0x4", 32'h4, 32'h11223344);

        // mem_write = 0 no escribe
        @(negedge clk); addr = 32'h4; write_data = 32'hFFFFFFFF;
        @(negedge clk);
        expect_read("sin we", 32'h4, 32'h11223344);

        // Escritura de bytes: usa el byte bajo del dato
        write_mem(32'h8, 32'h000000DD, 1'b1);
        expect_read("byte0", 32'h8, 32'h000000DD);
        write_mem(32'h9, 32'h000000CC, 1'b1);
        expect_read("byte1", 32'h8, 32'h0000CCDD);
        write_mem(32'hA, 32'h000000BB, 1'b1);
        expect_read("byte2", 32'h8, 32'h00BBCCDD);
        write_mem(32'hB, 32'h000000AA, 1'b1);
        expect_read("byte3", 32'h8, 32'hAABBCCDD);
        // sb no debe tocar la palabra vecina
        expect_read("vecina", 32'h4, 32'h11223344);

        // Wrap-around: 0xFFFFFFC4 -> índice (0xFFFFFFC4 >> 2) & 0xF = 1
        expect_read("wrap", 32'hFFFFFFC4, 32'h11223344);

        // Volcado solo no-ceros
        dut.dump("dump_tb_memoria.txt", 1'b1);
        fd = $fopen("dump_tb_memoria.txt", "r");
        n = $fscanf(fd, "0x%h 0x%h\n", fa, fd_data);
        if (n != 2 || fa !== 32'h4 || fd_data !== 32'h11223344) begin
            $display("  FAIL dump linea 1: n=%0d addr=0x%h dato=0x%h", n, fa, fd_data); errors = errors + 1;
        end
        n = $fscanf(fd, "0x%h 0x%h\n", fa, fd_data);
        if (n != 2 || fa !== 32'h8 || fd_data !== 32'hAABBCCDD) begin
            $display("  FAIL dump linea 2: n=%0d addr=0x%h dato=0x%h", n, fa, fd_data); errors = errors + 1;
        end
        n = $fscanf(fd, "0x%h 0x%h\n", fa, fd_data);
        if (n == 2) begin
            $display("  FAIL dump: hay mas lineas de las esperadas"); errors = errors + 1;
        end
        $fclose(fd);

        // Volcado completo: 16 líneas
        dut.dump("dump_tb_memoria_completo.txt", 1'b0);
        fd = $fopen("dump_tb_memoria_completo.txt", "r");
        n = 0;
        begin : cuenta_lineas
            integer guard;
            guard = 0;
            // el tope (guard) evita un ciclo infinito si $fscanf se comporta distinto en otro simulador
            while (guard < 64 && $fscanf(fd, "0x%h 0x%h\n", fa, fd_data) == 2) begin
                n = n + 1;
                guard = guard + 1;
            end
        end
        $fclose(fd);
        if (n != 16) begin
            $display("  FAIL dump completo: %0d lineas (esperado 16)", n); errors = errors + 1;
        end

        if (errors == 0) $display("RESULTADO: PASS  (tb_memory)");
        else             $display("RESULTADO: FAIL  (tb_memory: %0d errores)", errors);
        $finish;
    end

endmodule
