# Microarquitectura RV32I (Multiciclo)

**Curso:** MT-7003 Microprocesadores y Microcontroladores  
**Tecnológico de Costa Rica** | Escuela de Ingeniería Mecatrónica  
**Grupo N° 3** | II Semestre 2026  

## Descripción del Proyecto
Implementación de una microarquitectura multiciclo en Verilog para el set reducido de instrucciones de enteros de la arquitectura de código abierto RISC-V (RV32I), validada en el entorno de simulación Vivado de Xilinx.

---

## Especificaciones del Procesador y Set de Instrucciones

### Análisis y Clasificación de Instrucciones RV32I
A partir del proceso de cross-compilación y desensamblado del código en C suministrado, `pm_ev_grupos_6_estudiantes.c`, se determinó un subconjunto mínimo de 10 instrucciones pertenecientes al ISA RV32I base, repartidas en 31 palabras de instrucción de 32 bits.

Como se detalla en la tabla a continuación, el subconjunto se clasifica en 5 formatos principales de codificación:

* **Tipo I (Inmediato/Cargas):** Es el grupo más utilizado, encargado del manejo de constantes, desplazamientos (`slli`), operaciones lógicas (`andi`), aritmética de la pila (`addi`) y lectura de memoria (`lw`).
* **Tipo S (Almacenamiento):** Soportado mediante `sw` para enteros de 32 bits y `sb` para caracteres de 8 bits.
* **Tipo U (Inmediato Superior):** Requerido por `lui` para formar direcciones de memoria de 32 bits.
* **Tipo B (Saltos Condicionales):** Requerido por `bne` y `bge` para el control de flujo en estructuras `if-else` y bucles `for`.
* **Tipo J (Saltos Incondicionales):** Requerido por `jal` para saltos directos de bifurcación.

| Tipo / Formato | Mnemónico | Opcode [6:0] | funct3 | funct7 | Función en Código C |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Tipo I** | `addi` | `0010011` (`0x13`) | `000` | N/A | Gestión de pila (`sp`, `s0`), `i++`, `li` |
| **Tipo I** | `lw` | `0000011` (`0x03`) | `010` | N/A | Carga de palabra (32 bits) desde RAM |
| **Tipo I** | `slli` | `0010011` (`0x13`) | `001` | `0000000` | Desplazamiento a la izquierda (`b = b << 1`) |
| **Tipo I** | `andi` | `0010011` (`0x13`) | `111` | N/A | Máscara de bits AND (`b = b & 0xF`) |
| **Tipo S** | `sw` | `0100011` (`0x23`) | `010` | N/A | Escritura de palabra (32 bits) en RAM |
| **Tipo S** | `sb` | `0100011` (`0x23`) | `000` | N/A | Escritura de byte (`char a = 'c'`) |
| **Tipo U** | `lui` | `0110111` (`0x37`) | N/A | N/A | Carga del byte alto (`0xC7DF`) |
| **Tipo B** | `bne` | `1100011` (`0x63`) | `001` | N/A | Salto condicional `if (i == 0)` |
| **Tipo B** | `bge` | `1100011` (`0x63`) | `101` | N/A | Evaluación del bucle `for` |
| **Tipo J** | `jal` | `1101111` (`0x6F`) | N/A | N/A | Salto incondicional |

---

## Especificaciones por modulo
### 1. Program Counter (`PC`)

* **Módulo:** `pc`
* **Tipo:** Registro secuencial síncrono de 32 bits con habilitador de escritura (`PCWrite`) y reset.
* **Propósito:** Almacenar la dirección de memoria de la instrucción en ejecución. Mantiene su valor de forma estable durante las etapas intermedias de cada instrucción y se actualiza únicamente cuando la lógica de control habilita la señal `PCWrite`.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `clk` | Entrada | 1 | Sistema | Señal de reloj principal. La actualización del registro ocurre en el flanco de subida (*posedge*). |
| `rst` | Entrada | 1 | Sistema | Señal de reinicio global. Restablece el contenido del PC a la dirección inicial del programa (ej. `0x0000_0000`). |
| `PCWrite` | Control | 1 | Unidad de Control (`Control Escritura PC`) | Habilitador de escritura (*Write Enable*). Permite registrar la nueva dirección presente en `in_pc_next`. |
| `in_pc_next` | Entrada | 32 | Mux de Resultado (`ResultSrc`) | Dirección de la siguiente instrucción a ejecutar ($PC+4$ en la fase de *Fetch*, o la dirección de destino calculada para un salto condicional o incondicional). |
| `out_pc` | Salida | 32 | Mux `AdrSrc`, Registro `OldPC`, Mux `ALUSrcA` | Dirección física de la instrucción actual enviada al bus de memoria y a la ruta de datos. |

#### Tabla de Funcionamiento y Lógica de Control

| `rst` | `PCWrite` | Flanco de Reloj (`clk`) | Salida (`out_pc`) | Estado / Función |
| --- | --- | --- | --- | --- |
| **`1`** | `X` | `X` (Asíncrono / Síncrono) | `32'h0000_0000` | **Reset:** Inicializa el procesador en la dirección de arranque del código. |
| **`0`** | **`0`** | $\uparrow$ (Flanco de subida) | `out_pc` (mantiene valor anterior) | **Hold (Retención):** El PC conserva la dirección durante las etapas de Decodificación, Ejecución y Memoria. |
| **`0`** | **`1`** | $\uparrow$ (Flanco de subida) | `in_pc_next` | **Update (Actualización):** Almacena la nueva dirección calculada ($PC+4$ o dirección de salto). |

#### Descripción Operativa

El bloque **Program Counter (PC)** opera como un registro de estado de 32 bits. Para la arquitectura multiciclo la señal `PCWrite` actúa como un filtro que controla estrictamente cuándo debe avanzar el puntero de instrucciones.

La señal de habilitación `PCWrite` es generada por la caja **Control de Escritura PC** dentro de la Unidad de Control, respondiendo a la siguiente ecuación lógica:

$$\text{PCWrite} = \text{PCUpdate} \lor \text{BranchTaken}$$

* **Durante la fase de Búsqueda (*Fetch* - Ciclo 1):** La FSM activa la señal incondicional `PCUpdate = 1`, lo que provoca que `PCWrite = 1`. En el flanco de subida del reloj, el PC almacena la suma de $PC + 4$ calculada por la ALU y entregada por el Mux `ResultSrc`.
* **Durante las fases intermedias (Ciclos 2 a 4):** Las señales `PCUpdate` y `Branch` se mantienen en `0`, forzando `PCWrite = 0`. Esto garantiza que la dirección del PC no varíe mientras la instrucción actual lee el Banco de Registros o accede a la Memoria de Datos.
* **Durante la fase de Salto Condicional (Instrucciones Tipo B):** Si la condición de salto se evalúa como verdadera en la ALU (bandera `Zero = 1`) y la FSM indica que se trata de una instrucción de salto (`Branch = 1`), `PCWrite` se evalúa en `1`, permitiendo que la dirección objetivo calculada de salto se cargue en el PC.

---

### 2. Multiplexor de Dirección de Memoria (Mux `AdrSrc`)

* **Módulo:** `mux_adr_src`
* **Tipo:** Multiplexor combinacional 2 a 1 (32 bits)
* **Propósito:** Seleccionar la fuente de dirección física enviada a la Memoria Unificada (`Memory`), alternando entre la búsqueda de instrucciones (*Fetch*) y el acceso a datos (*Memory Access*).

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `in_pc` | Entrada | 32 | Program Counter (`PC`) | Dirección de la instrucción actual para la etapa de *Fetch*. |
| `in_result` | Entrada | 32 | Mux de Resultado (`ResultSrc`) | Dirección de memoria calculada por la ALU (proveniente de Mux `ResultSrc`). |
| `AdrSrc` | Control | 1 | Unidad de Control (FSM) | Selector de dirección emitido por la FSM. |
| `out_adr` | Salida | 32 | Memoria Unificada (`Address`) | Dirección física final enviada al bus de la RAM. |

#### Tabla de Selección y Operación

| `AdrSrc` | Salida (`out_adr`) | Etapa de Ejecución | Instrucciones que lo utilizan |
| --- | --- | --- | --- |
| **`0`** | `in_pc` | Búsqueda de Instrucción (*Fetch*) | **Todas** las instrucciones (primer ciclo de reloj). |
| **`1`** | `in_result` | Acceso a Memoria de Datos (*Memory*) | `lw` (lectura), `sw` y `sb` (escritura). |

#### Descripción Operativa

Este módulo conmuta la dirección entregada a la Memoria Unificada. En el primer ciclo de reloj de cualquier instrucción, la FSM mantiene `AdrSrc = 0` para leer la palabra de instrucción apuntada por el `PC`. En el ciclo de acceso a memoria para instrucciones Tipo I (cargas) o Tipo S (almacenamientos), la FSM conmuta `AdrSrc = 1`, permitiendo que la dirección efectiva calculada previamente por la ALU (que reside en la salida `ResultSrc` / `ALUOut`) direccione el dato a leer o escribir.

---

### 3. Memoria Unificada (`Memory`)

* **Módulo:** `memory`
* **Tipo:** Memoria RAM de puerto único unificada, síncrona para la escritura y organizada en palabras de 32 bits con acceso y direccionamiento alineado a nivel de byte (*Byte-Addressable*).
* **Propósito:** Almacenar de forma unificada tanto las instrucciones ejecutables del programa como el espacio de memoria de datos.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `clk` | Entrada | 1 | Sistema | Señal de reloj principal. Las operaciones de escritura en la RAM se sincronizan en el flanco de subida (*posedge*). |
| `Address` | Entrada | 32 | Mux `AdrSrc` | Dirección física a acceder. Corresponde a la dirección de instrucción (`PC`) en la etapa de *Fetch*, o a la dirección efectiva calculada por la ALU en la etapa de *Memory*. |
| `WriteData` | Entrada | 32 | Registro `Write Data` | Dato de 32 bits entregado por el banco de registros para ser almacenado en la memoria. |
| `MemWrite` | Control | 1 | Unidad de Control (FSM) | Habilitador global de escritura (*Write Enable*). `1` activa la escritura en la RAM; `0` mantiene la memoria en modo lectura. |
| `ByteWrite` | Control | 4 | Unidad de Control (Decodificador) | Señal de habilitación de byte. Controla cuáles bytes específicos de la palabra de 32 bits deben ser modificados. |
| `ReadData` | Salida | 32 | Registros `Instrucciones` y `Datos` | Palabra de 32 bits leída en la dirección indicada por `Address`. La salida se conecta en paralelo a las entradas de los registros intermedios `Instrucciones` (IR) y `Datos` (MDR). |

#### Tabla de Funcionamiento y Operaciones de Memoria

| `MemWrite` | `ByteWrite` | Tipo de Acceso | Etapa de Ejecución | Instrucciones que lo Utilizan | Descripción de Operación |
| --- | --- | --- | --- | --- | --- |
| **`0`** | `4'b0000` | **Lectura (Read)** | *Fetch* | **Todas** las instrucciones (Ciclo 1) | Lee la palabra de instrucción apuntada por el `PC` y la deposita en la entrada del registro `Instrucciones`. |
| **`0`** | `4'b0000` | **Lectura (Read)** | *Memory Access* | `lw` | Lee la palabra de datos de 32 bits ubicada en la dirección calculada por la ALU y la deposita en el registro `Data`. |
| **`1`** | `4'b1111` | **Escritura Word** | *Memory Access* | `sw` | Escribe los 32 bits del registro `Write Data` en la dirección de memoria apuntada por `ALUOut`. |
| **`1`** | `4'b0001`* | **Escritura Byte** | *Memory Access* | `sb` | Escribe únicamente los 8 bits menos significativos del registro `Write Data` (`WriteData[7:0]`) en la dirección correspondiente, según los bits `Adr[1:0]`. |

* *Nota: La señal de bytes `4'b0001`, `4'b0010`, `4'b0100` o `4'b1000` es conmutada dinámicamente por la Unidad de Control o la lógica de decodificación interna según la alineación indicada por los bits `Address[1:0]`.*

#### Descripción Operativa

El bloque **Memoria Unificada (`Memory`)** implementa un modelo de arquitectura donde el espacio de direcciones para código y datos es compartido dentro del mismo arreglo de almacenamiento.

1. **Operaciones de Lectura:**
Durante el ciclo de *Fetch* (Ciclo 1), la FSM mantiene `MemWrite = 0` y el multiplexor `AdrSrc` selecciona el puerto `PC`. La memoria entrega la palabra de instrucción de 32 bits en el puerto `ReadData`, la cual es muestreada y retenida por el registro `Instrucciones` al activarse la señal `IRWrite`. En una instrucción de carga de datos (`lw`), en el Ciclo 4 la memoria vuelve a leerse (`MemWrite = 0`), pero esta vez con la dirección proveniente de la ALU (`ALUOut`), entregando el dato al registro `Datos`.
2. **Operaciones de Escritura y Soporte para `sb` (*Store Byte*):**
Cuando se ejecuta una instrucción de almacenamiento (`sw` o `sb`), la FSM activa `MemWrite = 1` en la etapa de acceso a memoria.
* Para instrucciones **`sw`** (`funct3 = 010`), la señal de habilitación `ByteWrite` se establece en `4'b1111`, permitiendo la sobreescritura de los 4 bytes de la palabra de 32 bits.
* Para la instrucción **`sb`** (`funct3 = 000`), requerida por las asignaciones de variables tipo `char` en C (`char a = 'c'` y `a = 'b'`), la señal `ByteWrite` activa únicamente un carril de byte de los 4 disponibles según los bits menos significativos de la dirección (`Address[1:0]`). De esta forma, la RAM modifica de forma aislada los 8 bits del caracter deseado sin alterar los 24 bits contiguos en esa misma dirección de memoria.

---

### 4. Banco de Registros (`Registers`)

* **Módulo:** `register_file`
* **Tipo:** Arreglo de registros de lectura combinacional de 2 puertos y escritura secuencial síncrona de 1 puerto, compuesto por 32 registros de 32 bits.
* **Propósito:** Almacenar los 32 registros de propósito general de la arquitectura RV32I (`x0` a `x31`). Proporciona los operandos a la ruta de datos para la ejecución de instrucciones y almacena los resultados temporales o finales devueltos por la ALU o la memoria.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `clk` | Entrada | 1 | Sistema | Señal de reloj principal. Las escrituras en el banco de registros se efectúan de forma síncrona en el flanco de subida (*posedge*). |
| `Read_Reg_1` | Entrada | 5 | Registro `Instrucciones[19:15]` | Dirección de lectura del primer registro fuente (`rs1`). |
| `Read_Reg_2` | Entrada | 5 | Registro `Instrucciones[24:20]` | Dirección de lectura del segundo registro fuente (`rs2`). |
| `Write_Reg` | Entrada | 5 | Registro `Instrucciones[11:7]` | Dirección de escritura del registro destino (`rd`). |
| `Write_Data` | Entrada | 32 | Mux de Resultado (`ResultSrc`) | Dato de 32 bits a escribir en el registro destino indicado por `Write_Reg`. |
| `RegWrite` | Control | 1 | Unidad de Control (FSM) | Habilitador de escritura en registro destino. `1` autoriza la escritura en el registro `Write_Reg`; `0` deshabilita la escritura. |
| `Read_Data_1` | Salida | 32 | Registro `A` | Contenido de 32 bits leído del registro seleccionado por `Read_Reg_1`. |
| `Read_Data_2` | Salida | 32 | Registro `B` | Contenido de 32 bits leído del registro seleccionado por `Read_Reg_2`. |

#### Tabla de Funcionamiento y Lógica de Operación

| `RegWrite` | Registro Destino (`Write_Reg`) | Flanco de Reloj (`clk`) | Operación de Lectura (`Read_Data_1`, `Read_Data_2`) | Operación de Escritura (`Write_Data`) | Descripción / Estado |
| --- | --- | --- | --- | --- | --- |
| **`X`** | `X` | **Combinacional** | `Read_Data_1 = Regs[Read_Reg_1]`<br> <br>`Read_Data_2 = Regs[Read_Reg_2]` | N/A | **Lectura:** Los datos leídos se reflejan de forma inmediata. Si `Read_Reg_1` o `Read_Reg_2` apuntan a `5'b00000`, la salida es forzada a `32'h0000_0000`. |
| **`0`** | `X` | $\uparrow$ (Flanco de subida) | Continuamente activa | Ninguna | **Lectura Pura / Retención:** Sin cambios en el banco de registros durante las etapas de *Fetch*, *Decode* y *Memory*. |
| **`1`** | **`5'b00000` (`x0`)** | $\uparrow$ (Flanco de subida) | Continuamente activa | **Escritura ignorada** | **Protección de `x0`:** Intentos de escritura en el registro `x0` son descartados. El registro `x0` se mantiene de forma permanente en `0`. |
| **`1`** | **`Write_Reg != 0` <br> <br> (`x1`-`x31`)** | $\uparrow$ (Flanco de subida) | Continuamente activa | `Regs[Write_Reg] <= Write_Data` | ***Write-Back*:** Almacena el dato `Write_Data` en el registro destino `Write_Reg`. |

#### Descripción Operativa

El bloque **Banco de Registros (`Registers`)** contiene un arreglo de 32 registros de 32 bits de ancho. La arquitectura RV32I establece que el registro $x0$ (`zero`) está permanentemente enlazado a cero lógico ($x0 = 0$). Cualquier intento de sobrescribir $x0$ mediante la señal `RegWrite = 1` debe ser ignorado por el hardware.

1. **Acceso de Lectura Dual (Asíncrono):**
El módulo cuenta con dos puertos de lectura independientes (`Read_Reg_1` y `Read_Reg_2`). La lectura es completamente combinacional, lo que significa que el contenido de los registros direccionados aparece en los puertos `Read_Data_1` y `Read_Data_2` tan pronto como los campos de la instrucción `Instr[19:15]` y `Instr[24:20]` se estabilizan. En la arquitectura multiciclo, esta característica permite que en el **Ciclo 2 (Decodificación)** el procesador lea simultáneamente ambos registros fuente y almacene sus valores en los registros intermedios `A` y `B` sin perder ciclos de reloj en la espera de un flanco activo.
2. **Acceso de Escritura Único (Síncrono):**
El módulo dispone de un único puerto de escritura (`Write_Reg`). La escritura se realiza únicamente en la etapa de ***Write-Back*** si la FSM establece `RegWrite = 1`. En el flanco de subida del reloj (`clk`), si $WriteReg \neq 0$, el dato presente en `Write_Data` (proveniente del Mux `ResultSrc`) se registra de forma síncrona en $Regs[ WriteReg ]$.

---

### 5. Generador de Inmediatos (`ImmExt`)

* **Módulo:** `imm_extend`
* **Tipo:** Lógica combinacional.
* **Propósito:** Extraer los campos dispersos de inmediatos presentes en la palabra de instrucción, reordenar sus bits según el formato de codificación de la arquitectura RV32I y extender el signo hasta un ancho de 32 bits para ser utilizado como operando en la ALU.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `Instr` | Entrada | 25 | Registro `Instr[31:7]` | Bits de la instrucción actual (del bit 7 al 31) que contienen los operandos inmediatos codificados. |
| `ImmSrc` | Control | 3 | Decodificador / Unidad de Control | Selector de formato de inmediato. Determina cómo reinterpretar y concatenar los bits de la instrucción. |
| `ImmExt` | Salida | 32 | Mux `ALUSrcB` | Inmediato final de 32 bits con extensión de signo listo para ingresar a la ALU. |

#### Tabla de Funcionamiento y Selección de Formatos (`ImmSrc`)

| `ImmSrc` | Tipo de Instrucción | Codificación en Verilog (Concatenación y Extensión) | Formato del Inmediato Generado (32 bits) |
| --- | --- | --- | --- |
| **`3'b000`** | **Tipo I** | `{{20{Instr[31]}}, Instr[31:20]}` | Inmediato de 12 bits con extensión de signo en los 20 bits superiores. |
| **`3'b001`** | **Tipo S** | `{{20{Instr[31]}}, Instr[31:25], Instr[11:7]}` | Reconstruye el inmediato de 12 bits disperso entre `Instr[31:25]` y `Instr[11:7]`, extendiendo el signo. |
| **`3'b010`** | **Tipo B** | `{{20{Instr[31]}}, Instr[7], Instr[30:25], Instr[11:8], 1'b0}` | Reconstruye offset de salto de 13 bits (con LSB en `0`), extendiendo el signo en los 19 bits superiores. |
| **`3'b011`** | **Tipo J** | `{{12{Instr[31]}}, Instr[19:12], Instr[20], Instr[30:21], 1'b0}` | Reconstruye offset de salto de 21 bits (con LSB en `0`), extendiendo el signo en los 11 bits superiores. |
| **`3'b100`** | **Tipo U** | `{Instr[31:12], 12'b0000_0000_0000}` | Carga inmediata superior: toma los 20 bits más significativos y rellena los 12 bits inferiores con ceros (`12'b0`). |

* *Nota: Para la instrucción `slli`, el inmediato real de desplazamiento son solo los 5 bits menos significativos `Instr[24:20]`, pero la extensión del Tipo I es totalmente compatible ya que los bits superiores son ceros.*

#### Descripción Operativa

El bloque **Generador de Inmediatos (`imm_extend`)** opera de forma asíncrona mediante multiplexores combinacionales internos. La arquitectura RISC-V fue diseñada estratégicamente para que el bit más significativo de cualquier inmediato siempre se ubique en la posición `Instr[31]`. Esta propiedad permite que la **extensión de signo** se reduzca a replicar el bit `Instr[31]` en los bits superiores del bus de salida (`ImmExt[31:N]`).

1. **Extensión de Signo (Tratamiento de Números Negativos):**
Si el valor codificado es negativo (`Instr[31] = 1`), la sintaxis `{{N{Instr[31]}}, ...}` replica un `'1'` lógico en todos los bits superiores para preservar el valor en complemento a dos en una palabra de 32 bits. Si es positivo (`Instr[31] = 0`), los bits superiores se rellenan con `'0'`.
2. **Alineación de Saltos (Formatos Tipo B y Tipo J):**
Para las instrucciones de salto condicional (`bne`, `bge`) e incondicional (`jal`), los inmediatos representan un desplazamiento (*offset*) relativo al $PC$. Debido a que en RISC-V las instrucciones están alineadas en direcciones pares (múltiplos de 2 o 4 bytes), el bit menos significativo ($LSB$) del offset **siempre es cero**. Para ahorrar espacio en el código máquina, el hardware no almacena este $LSB$; en su lugar, el módulo `imm_extend` concatena explícitamente un `'0'` fijo al final (`1'b0`), realizando un desplazamiento a la izquierda implícito de 1 bit (multiplicación por 2).
3. **Inmediato de Carga Superior (Tipo U - `lui`):**
Para la instrucción `lui` (requerida al cargar constantes de direcciones superiores como `0xC7DF`), el módulo toma los 20 bits superiores de la instrucción (`Instr[31:12]`) y concatena 12 ceros en la parte baja, entregando la constante desplazada directamente al Mux `ResultSrc` a través de la ALU.

---

### 6. Multiplexor de Operando 1 de ALU (Mux `ALUSrcA`)

* **Módulo:** `mux_alu_src_a`
* **Tipo:** Multiplexor combinacional 3 a 1 de 32 bits.
* **Propósito:** Seleccionar la fuente del primer operando `SrcA` ingresado a la entrada `A` de la ALU, conmutando entre la dirección actual del `PC`, la dirección previa retenida en `OldPC` y el dato leído del registro fuente `rs1`.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `in_pc` | Entrada | 32 | Program Counter (`PC`) | Dirección actual del $PC$. Utilizada en la etapa de *Fetch* para calcular $PC + 4$. |
| `in_old_pc` | Entrada | 32 | Registro `OldPC` | Dirección física de la instrucción actual retenida en el registro `OldPC`. Utilizada para calcular direcciones de salto relativo. |
| `in_reg_a` | Entrada | 32 | Registro intermedio `A` | Contenido leído del registro fuente $rs1$ en la etapa de decodificación. |
| `ALUSrcA` | Control | 2 | Unidad de Control (FSM) | Selector de operando emitiendo el código de control de 2 bits. |
| `out_src_a` | Salida | 32 | Entrada $A$ de la `ALU` | Operando 1 de 32 bits seleccionado para la operación en la ALU. |

#### Tabla de Selección y Operación (`ALUSrcA`)

| `ALUSrcA` | Salida (`out_src_a`) | Etapa de Ejecución | Instrucciones que lo Utilizan | Descripción de Operación |
| --- | --- | --- | --- | --- |
| **`2'b00`** | `in_pc` | *Fetch* | **Todas** las instrucciones | Entrega el valor actual del $PC$ a la ALU para sumar +4 y calcular la dirección de la siguiente instrucción. |
| **`2'b01`** | `in_old_pc` | *Decode* / *Execute* | Tipo B y Tipo J | Entrega la dirección base de la instrucción actual ($OldPC$) para calcular la dirección objetivo del salto ($OldPC + ImmExt$). |
| **`2'b10`** | `in_reg_a` | *Execute* | Tipo I, Tipo S, Tipo B | Entrega el dato del registro fuente $rs1$ para ejecutar operaciones aritméticas/lógicas, direcciones de memoria o comparaciones de salto. |

#### Descripción Operativa

El bloque **Multiplexor `ALUSrcA`** rige el flujo del primer puerto de la ALU. Debido a la naturaleza multiciclo de la arquitectura, el valor del Program Counter evoluciona en el tiempo:
1. **Paso a la siguiente instrucción ($PC + 4$):** En el Ciclo 1 (*Fetch*), la FSM selecciona `ALUSrcA = 2'b00`, conectando directamente el puerto `PC` a la ALU.
2. **Cálculo de Saltos ($OldPC + ImmExt$):** Debido a que el $PC$ incrementa a $PC+4$ desde el Ciclo 1, su valor original se resguarda en el registro `OldPC`. Durante la evaluación o pre-cálculo de saltos, la FSM conmuta `ALUSrcA = 2'b01` para tomar la dirección base correcta.
3. **Ejecución General con Registros:** Para el resto de instrucciones donde se opera con el registro $rs1$, la FSM selecciona `ALUSrcA = 2'b10`, pasando el dato estable almacenado en el registro `A`.

---

### 7. Multiplexor de Operando 2 de ALU (Mux `ALUSrcB`)

* **Módulo:** `mux_alu_src_b`
* **Tipo:** Multiplexor combinacional 3 a 1 de 32 bits.
* **Propósito:** Seleccionar la fuente del segundo operando `SrcB` ingresado a la entrada `B` de la ALU, conmutando entre el dato del registro `rs2`, el inmediato de 32 bits (`ImmExt`) y la constante aritmética 4.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `in_reg_b` | Entrada | 32 | Registro intermedio `B` | Contenido leído del registro fuente $rs2$ en la etapa de decodificación. |
| `in_imm_ext` | Entrada | 32 | Generador `Extend` | Inmediato de 32 bits reconstruido y extendido con signo por el módulo `imm_extend`. |
| `in_4` | Entrada | 32 | Constante hardwired `32'd4` | Valor constante $4$ en 32 bits utilizado para el avance secuencial del $PC$. |
| `ALUSrcB` | Control | 2 | Unidad de Control (FSM) | Selector de operando emitiendo el código de control de 2 bits. |
| `out_src_b` | Salida | 32 | Entrada $B$ de la `ALU` | Operando 2 de 32 bits seleccionado para la operación en la ALU. |

#### Tabla de Selección y Operación (`ALUSrcB`)

| `ALUSrcB` | Salida (`out_src_b`) | Etapa de Ejecución | Instrucciones que lo Utilizan | Descripción de Operación |
| --- | --- | --- | --- | --- |
| **`2'b00`** | `in_reg_b` | *Execute* | Tipo B | Entrega el valor del registro fuente $rs2$ para realizar la resta/comparación ($A - B$) en la ALU. |
| **`2'b01`** | `in_imm_ext` | *Decode* / *Execute* | Tipo I, Tipo S, Tipo U, Tipos B y J | Entrega el inmediato procesado de 32 bits para operaciones aritméticas/lógicas con constantes, cálculo de direcciones físicas o cálculo del offset de salto. |
| **`2'b10`** | `in_4` | *Fetch* | **Todas** las instrucciones | Entrega la constante fija $+4$ para sumarla al $PC$ actual. |

#### Descripción Operativa

El **Multiplexor `ALUSrcB`** trabaja de manera coordinada con `ALUSrcA` para alimentar la ALU en cada ciclo del procesador:
1. **Suma de dirección secuencial ($PC + 4$):** En la fase de *Fetch*, mientras `ALUSrcA` entrega el $PC$, la FSM establece `ALUSrcB = 2'b10` para inyectar el número $4$ fijo, logrando $PC + 4$ en la salida de la ALU.
2. **Operaciones e Incrementos con Inmediato:** Para instrucciones con operandos inmediatos o cálculo de saltos relativos ($OldPC + ImmExt$), la FSM conmuta `ALUSrcB = 2'b01`, seleccionando el bus de 32 bits proveniente del módulo `imm_extend`.
3. **Comparaciones entre Registros:** En las instrucciones de salto condicional, el Ciclo 3 evalúa la condición restando los valores de los registros $rs1$ y $rs2$. Para esto, la FSM selecciona `ALUSrcB = 2'b00` para ingresar el contenido del registro `B`.

---

### 8. Unidad Aritmética Lógica (ALU)

* **Módulo:** `alu`
* **Tipo:** Lógica combinacional.
* **Propósito:** Ejecutar las operaciones aritméticas, lógicas, de desplazamiento y de comparación requeridas por el subconjunto de instrucciones RV32I, además de calcular las direcciones efectivas de memoria y los punteros de instrucción ($PC + 4$ y $OldPC + ImmExt$).

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `SrcA` | Entrada | 32 | Mux `ALUSrcA` | Primer operando de 32 bits ($A$). Corresponde al $PC$, $OldPC$ o al registro fuente $rs1$. |
| `SrcB` | Entrada | 32 | Mux `ALUSrcB` | Segundo operando de 32 bits ($B$). Corresponde al registro $rs2$, constante $4$ o al inmediato $ImmExt$. |
| `ALUControl` | Control | 3 | Decodificador de ALU | Código de control de 3 bits que selecciona la operación aritmética o lógica a ejecutar. |
| `ALUResult` | Salida | 32 | Registro `ALUOut`, Mux `ResultSrc` | Resultado principal de 32 bits obtenido tras procesar los operandos $SrcA$ y $SrcB$. |
| `Zero` | Salida | 1 | Unidad de Control (`Control Escritura PC`) | Bandera de cero. Se evalúa en `'1'` lógico únicamente si `ALUResult == 32'd0`. |
| `GE`  | Salida | 1 | Unidad de Control (`Control Escritura PC`) | Bandera de comparación (*Greater or Equal* ). Indica si $SrcA \ge SrcB$ en interpretación con signo para la instrucción `bge`. |

#### Tabla de Funcionamiento y Selección de Operaciones (`ALUControl`)

| `ALUControl` | Operación | Expresión Matemática / Lógica | Etapa de Ejecución | Instrucciones que lo Utilizan |
| --- | --- | --- | --- | --- |
| **`3'b000`** | **Suma (ADD)** | $\text{ALUResult} = SrcA + SrcB$ | *Fetch* / *Execute* | `addi`, `lw`, `sw`, `sb`, `jal`, $PC + 4$, $OldPC + ImmExt$. |
| **`3'b001`** | **Resta (SUB)** | $\text{ALUResult} = SrcA - SrcB$ | *Execute* | `bne`, `bge` (Evaluación de condición de salto). |
| **`3'b010`** | **AND Lógico** | $\text{ALUResult} = SrcA \land SrcB$ | *Execute* | `andi` (Máscaras de bits). |
| **`3'b011`** | **Desplazamiento Lógico Izq. (SLL)** | $\text{ALUResult} = SrcA \ll SrcB[4:0]$ | *Execute* | `slli` ($b = b \ll 1$). |
| **`3'b100`** | **Pasar $B$ (PASS-B)** | $\text{ALUResult} = SrcB$ | *Execute* | `lui` (Carga inmediata del byte alto). |

#### Descripción Operativa

El módulo **Unidad Aritmética Lógica (ALU)** es el núcleo de cómputo de la ruta de datos. Al ser un bloque de lógica combinacional pura, no contiene registros ni elementos de memoria; su salida `ALUResult` responde de manera asíncrona a los cambios en las entradas $SrcA$, $SrcB$ y al código de operación `ALUControl`.

1. **Reutilización Multiciclo:**
A diferencia de una arquitectura monociclo donde se requieren sumadores independientes para el $PC$, en este diseño la ALU principal se reutiliza secuencialmente en diferentes ciclos de reloj:
* **Ciclo 1 (*Fetch*):** Realiza la suma $PC + 4$ (`ALUControl = 3'b000`).
* **Ciclo 2 (*Decode*):** Precalcula la dirección de salto relativo $OldPC + ImmExt$ (`ALUControl = 3'b000`).
* **Ciclo 3 (*Execute*):** Ejecuta la operación aritmética, lógica, dirección de carga/almacenamiento o comparación especificada por la instrucción.
2. **Detalle de Operaciones de Cómputo:**
* **Suma (`3'b000`):** Calcula la dirección efectiva de memoria para `lw`, `sw` y `sb` mediante la adición del registro base ($rs1$) más el inmediato extendido ($ImmExt$).
* **Resta (`3'b001`):** Computa la diferencia $SrcA - SrcB$. Si ambos operandos son idénticos, la resta produce cero, activando la bandera `Zero = 1`.
* **AND Lógico (`3'b010`):** Realiza la operación bit a bit entre $SrcA$ y $SrcB$, utilizada en el programa para la máscara de bits `b & 0xF`.
* **Desplazamiento Lógico (`3'b011`):** Desplaza los bits de $SrcA$ a la izquierda tantos bits como indique el valor de 5 bits $SrcB[4:0]$ (`Instr[24:20]`), rellenando las posiciones vacías a la derecha con ceros.
* **Transferencia de Inmediato Superior (`3'b100`):** Transfiere de manera directa el inmediato $SrcB$ a la salida `ALUResult` sin modificación, permitiendo que `lui` cargue constantes superiores directamente al Mux `ResultSrc`.
3. **Evaluación de Condición para Saltos (`bne` y `bge`):**
* **Instrucción `bne` (*Branch if Not Equal*):** La ALU ejecuta la resta $rs1 - rs2$. Si $rs1 \neq rs2$, el resultado difiere de cero y la bandera `Zero` se evalúa en `'0'`. La lógica de control utiliza la condición $\text{Branch} \land \neg\text{Zero}$ para autorizar la actualización del $PC$ con la dirección de salto.
* **Instrucción `bge` (*Branch if Greater or Equal*):** La ALU evalúa la comparación con signo entre $rs1$ y $rs2$. Si el valor del registro $rs1$ es mayor o igual al valor de $rs2$, se activa la salida `GE = 1`, permitiendo a la lógica de control tomar la bifurcación del bucle `for`.

---

### 9. Multiplexor de Resultados (Mux `ResultSrc`)

* **Módulo:** `mux_result_src`
* **Tipo:** Multiplexor combinacional 3 a 1 de 32 bits.
* **Propósito:** Seleccionar el dato final de 32 bits que se entregará a la ruta de datos según la etapa de ejecución, conmutando entre el registro de salida de la ALU (`Salida_ALU`), el registro de datos leídos de memoria (`Datos`) y la salida combinacional directa de la ALU.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `in_reg_alu` | Entrada | 32 | Registro `ALUOut` | Resultado de la ALU calculado y almacenado en el registro intermedio durante la etapa de *Execute*. |
| `in_reg_datos` | Entrada | 32 | Registro `Data` (MDR) | Dato de 32 bits leído desde la Memoria Unificada y retenido durante la etapa de *Memory*. |
| `in_alu` | Entrada | 32 | Unidad Aritmética Lógica (`ALU`) | Resultado combinacional directo (sin registrar) proveniente de la salida de la ALU. |
| `ResultSrc` | Control | 2 | Unidad de Control (FSM) | Selector de 2 bits emitiendo el código de control que determina la fuente del bus de resultado. |
| `out_result` | Salida | 32 | Banco de Registros (`Write_Data`), Mux `AdrSrc`, `PC` | Bus de resultado final entregado a la reescritura de registros, dirección de memoria o actualización del $PC$. |

#### Tabla de Selección y Operación (`ResultSrc`)

| `ResultSrc` | Salida (`out_result`) | Etapa de Ejecución | Instrucciones que lo Utilizan | Descripción de Operación |
| --- | --- | --- | --- | --- |
| **`2'b00`** | `in_reg_alu` (`Salida_ALU`) | *Write-Back* / *Memory* | Tipo I, Tipo S | Entrega el resultado de operaciones aritméticas/lógicas o la dirección efectiva calculada en el ciclo previo hacia la reescritura de registros (`Write_Data`) o a la memoria (`in_result` del Mux `AdrSrc`). |
| **`2'b01`** | `in_reg_datos` (`Datos`) | *Write-Back* | Tipo I | Entrega la palabra de datos leída de la RAM y retenida en el registro `Datos` para guardarla en el registro destino `rd`. |
| **`2'b10`** | `in_alu` | *Fetch* / *Decode* / *Execute* | **Todas** las instrucciones (en *Fetch*), Tipo J, Tipo B | Entrega el resultado directo de la ALU ($PC + 4$ en *Fetch* para cargar en el $PC$, o la dirección de salto $OldPC + ImmExt$ en *Decode*/*Execute*). |

#### Descripción Operativa

El bloque **Multiplexor de Resultados (`ResultSrc`)** administra el bus principal de retorno de la arquitectura multiciclo. Dado que diferentes instrucciones producen sus resultados finales en distintos bloques hardware y ciclos de reloj, este multiplexor conmuta dinámicamente la fuente enviada a la etapa de Reescritura (*Write-Back*), a la Memoria Unificada y al Program Counter ($PC$):

1. **Salida Registrada de la ALU (`2'b00`):**
Para instrucciones aritmético-lógicas, el resultado computado en el Ciclo 3 se estabiliza en el registro intermedio `ALUOut`. En el Ciclo 4 (*Write-Back*), la FSM selecciona `ResultSrc = 2'b00` para escribir el valor en el Banco de Registros. Asimismo, durante instrucciones de acceso a memoria, este puerto suministra la dirección física calculada al puerto `in_result` del Mux `AdrSrc`.
2. **Dato Leído de Memoria (`2'b01`):**
Para la instrucción de carga `lw`, la RAM entrega el dato en el Ciclo 4 (*Memory*), el cual es muestreado en el registro intermedio `Datos`. En el Ciclo 5 (*Write-Back*), la FSM establece `ResultSrc = 2'b01` para canalizar dicho dato hacia el puerto de escritura `Write_Data` del Banco de Registros.
3. **Operación Combinacional Directa de la ALU (`2'b10`):**
Se utiliza cuando se requiere actualizar el $PC$ o capturar un resultado inmediatamente sin esperar un ciclo adicional en el registro `ALUOut`:
* **Fase de *Fetch* (Ciclo 1):** La ALU calcula $PC + 4$ de forma combinacional; la FSM selecciona `ResultSrc = 2'b10` para realimentar este valor inmediatamente al puerto `in_pc_next` del $PC$.
* **Saltos e Instrucción `jal`:** Suministra la dirección objetivo calculada ($OldPC + ImmExt$) o la dirección de retorno ($PC + 4$) para guardarla en el registro enlace $ra$ (`x1`).

---

Revisando el documento `0_Specs_3.md` con las reglas que definiste, la estructura es sólida y coherente. Solo quedan **3 detalles menores** para que esté alineado al 100%:

1. **Memoria Unificada (Sección 3 - Tabla de Interfaz):** En el puerto `WriteData`, la columna *Origen / Destino* aún indica `Registro Write Data`. Debe ajustarse a **`Registro B`**.


2. **Memoria Unificada (Sección 3 - Tabla de Operaciones):** En la fila de lectura `lw`, la descripción indica que el dato se deposita en el *registro `Data*`. Debe decir **`registro Datos`**.


3. **Mux de Resultados (Sección 9):** En la tabla de interfaz y descripciones, reemplazar las referencias residuales de `Data` por **`Datos`**.



---

A continuación tienes las especificaciones técnicas estandarizadas de los **6 Registros Intermedios** para agregarlas directamente al final de tu documento (`Secciones 10 a 15`):

---

### 10. Registro Puntero de Instrucción Anterior (`OldPC`)

* **Módulo:** `reg_old_pc`
* **Tipo:** Registro secuencial síncrono de 32 bits.
* **Propósito:** Retener la dirección de memoria de la instrucción actual durante sus etapas de ejecución. Suministra la dirección base para el cálculo de saltos relativos ($OldPC + ImmExt$) cuando el $PC$ principal ya ha avanzado a $PC + 4$.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `clk` | Entrada | 1 | Sistema | Reloj principal. Muestra y almacena en el flanco de subida (*posedge*). |
| `rst` | Entrada | 1 | Sistema | Reinicio global. Restablece el valor a `32'h0000_0000`. |
| `in_pc` | Entrada | 32 | Program Counter (`out_pc`) | Dirección actual entregada por el $PC$ durante la etapa de *Fetch*. |
| `out_old_pc` | Salida | 32 | Mux `ALUSrcA` (`in_old_pc`) | Dirección base retenida enviada a la ALU para el cálculo de direcciones de salto. |

#### Descripción Operativa

En el Ciclo 1 (*Fetch*), el registro `OldPC` muestra de forma síncrona el valor del $PC$ antes de que este sea incrementado por la ALU. Mantiene esta dirección fija durante los ciclos de Decodificación y Ejecución, garantizando que instrucciones como `bne`, `bge` y `jal` dispongan de la referencia física original para calcular la dirección destino del salto.

---

### 11. Registro de Instrucciones (`Instrucciones`)

* **Módulo:** `reg_instructions`
* **Tipo:** Registro secuencial síncrono de 32 bits con habilitador de escritura (`IRWrite`).
* **Propósito:** Almacenar la palabra de instrucción de 32 bits leída desde la Memoria Unificada durante la etapa de *Fetch*, manteniéndola inmune a cambios en el bus de memoria durante el resto de ciclos de la instrucción.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `clk` | Entrada | 1 | Sistema | Reloj principal. Muestra la instrucción en el flanco de subida (*posedge*). |
| `rst` | Entrada | 1 | Sistema | Reinicio global. Restablece el registro a la instrucción `NOP` (`32'h0000_0013`). |
| `IRWrite` | Control | 1 | Unidad de Control (FSM) | Habilitador de escritura (*Write Enable*). `1` autoriza la captura de la nueva instrucción desde la RAM. |
| `in_instruction` | Entrada | 32 | Memoria Unificada (`ReadData`) | Palabra de instrucción de 32 bits entregada por la memoria. |
| `out_instruction` | Salida | 32 | Unidad de Control, Banco de Registros, `ImmExt` | Bus de instrucción de 32 bits. Conecta `Instr[31:0]` a la FSM y sus campos a los puertos de lectura/escritura. |

#### Descripción Operativa

En el Ciclo 1 (*Fetch*), la FSM establece `IRWrite = 1`. En el flanco de subida del reloj, la palabra leída de la Memoria RAM se guarda en el registro `Instrucciones`. Durante los Ciclos 2 a 5, la FSM desactiva `IRWrite = 0`, bloqueando el contenido del registro para que los campos `opcode`, `funct3`, `funct7`, `rs1`, `rs2` y `rd` se mantengan constantes mientras el procesador ejecuta la instrucción.

---

### 12. Registro de Datos de Memoria (`Datos`)

* **Módulo:** `reg_data`
* **Tipo:** Registro secuencial síncrono de 32 bits.
* **Propósito:** Capturar de la Memoria Unificada la palabra de datos leída durante la etapa de acceso a memoria (*Memory*), aislándola para la etapa de Reescritura (*Write-Back*).

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `clk` | Entrada | 1 | Sistema | Reloj principal. Captura el dato leido en el flanco de subida (*posedge*). |
| `rst` | Entrada | 1 | Sistema | Reinicio global. Restablece la salida a `32'h0000_0000`. |
| `in_read_data` | Entrada | 32 | Memoria Unificada (`ReadData`) | Palabra de 32 bits leída desde la memoria RAM. |
| `out_data` | Salida | 32 | Mux `ResultSrc` (`in_reg_datos`) | Dato retenido enviado a la entrada `01` del Mux `ResultSrc` para ser reescrito en el Banco de Registros. |

#### Descripción Operativa

Durante la ejecución de la instrucción `lw`, en el Ciclo 4 (*Memory*) la RAM entrega el dato solicitado en el bus `ReadData`. En el flanco de subida al finalizar dicho ciclo, el registro `Datos` captura esta palabra, permitiendo que en el Ciclo 5 (*Write-Back*) el valor sea transferido al Banco de Registros a través del Mux `ResultSrc`.

---

### 13. Registro Intermedio de Operando A (`A`)

* **Módulo:** `reg_a`
* **Tipo:** Registro secuencial síncrono de 32 bits.
* **Propósito:** Guardar el valor leído del primer puerto del Banco de Registros (`Read_Data_1` / $rs1$) durante la etapa de decodificación, estabilizando el operando 1 para la ALU.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `clk` | Entrada | 1 | Sistema | Reloj principal. Muestra el contenido en el flanco de subida (*posedge*). |
| `rst` | Entrada | 1 | Sistema | Reinicio global. Restablece el valor a `32'h0000_0000`. |
| `in_read_data_1` | Entrada | 32 | Banco de Registros (`Read_Data_1`) | Contenido del registro $rs1$ leído asíncronamente en el Ciclo 2. |
| `out_a` | Salida | 32 | Mux `ALUSrcA` (`in_reg_a`) | Operando 1 de 32 bits entregado al Mux de entrada A de la ALU. |

#### Descripción Operativa

En el Ciclo 2 (*Decode*), el Banco de Registros entrega combinacionalmente en `Read_Data_1` el contenido del registro $rs1$. En el flanco de subida al finalizar el Ciclo 2, el registro `A` almacena este valor. Esto asegura que la entrada a la ALU no se vea afectada por variaciones en las señales de dirección del Banco de Registros durante la etapa de ejecución.

---

### 14. Registro Intermedio de Operando B (`B`)

* **Módulo:** `reg_b`
* **Tipo:** Registro secuencial síncrono de 32 bits.
* **Propósito:** Guardar el valor leído del segundo puerto del Banco de Registros (`Read_Data_2` / $rs2$) durante la etapa de decodificación, suministrando el operando 2 a la ALU y el dato de escritura a la Memoria Unificada.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `clk` | Entrada | 1 | Sistema | Reloj principal. Muestra el contenido en el flanco de subida (*posedge*). |
| `rst` | Entrada | 1 | Sistema | Reinicio global. Restablece el valor a `32'h0000_0000`. |
| `in_read_data_2` | Entrada | 32 | Banco de Registros (`Read_Data_2`) | Contenido del registro $rs2$ leído asíncronamente en el Ciclo 2. |
| `out_b` | Salida | 32 | Mux `ALUSrcB` (`in_reg_b`), Memoria (`WriteData`) | Operando 2 enviado a la entrada `00` del Mux `ALUSrcB` y al puerto `WriteData` de la memoria RAM. |

#### Descripción Operativa

De forma idéntica al registro `A`, en el Ciclo 2 (*Decode*) el registro `B` captura el contenido entregado por el puerto $rs2$ del Banco de Registros. Su salida `out_b` cumple una función doble: alimenta el Mux `ALUSrcB` para comparaciones de salto (`bne`, `bge`) y proporciona el bus de datos a escribir (`WriteData`) para las instrucciones de almacenamiento `sw` y `sb`.

---

### 15. Registro de Salida de ALU (`ALUOut`)

* **Módulo:** `reg_alu_out`
* **Tipo:** Registro secuencial síncrono de 32 bits.
* **Propósito:** Almacenar el resultado procesado por la ALU en la etapa de ejecución (*Execute*), preservando la dirección calculada o el resultado aritmético/lógico para las etapas posteriores de memoria o reescritura.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `clk` | Entrada | 1 | Sistema | Reloj principal. Captura el resultado de la ALU en el flanco de subida (*posedge*). |
| `rst` | Entrada | 1 | Sistema | Reinicio global. Restablece la salida a `32'h0000_0000`. |
| `in_alu_result` | Entrada | 32 | Unidad Aritmética Lógica (`ALUResult`) | Resultado combinacional de 32 bits generado por la ALU en el Ciclo 3. |
| `out_alu_out` | Salida | 32 | Mux `ResultSrc` (`in_reg_alu`) | Resultado registrado transferido al Mux de Resultados y al Mux `AdrSrc`. |

#### Descripción Operativa

En el Ciclo 3 (*Execute*), la ALU computa la operación asignada. Al terminar el ciclo, el registro `ALUOut` almacena este resultado en el flanco de subida del reloj. En el Ciclo 4, el valor guardado se canaliza hacia la Memoria Unificada (como dirección de acceso en `lw`, `sw` y `sb`) o hacia el Mux `ResultSrc` para ser reescrito en el Banco de Registros durante la etapa de *Write-Back*.

---

---

### 16. Unidad de Control (FSM Principal)

* **Módulo:** `control_fsm`
* **Tipo:** Máquina de Estados Finitos (FSM tipo Moore) combinada con decodificadores auxiliares.
* **Propósito:** Coordinar la secuencia temporal de ejecución de cada instrucción a través de los ciclos de reloj, emitiendo las señales de control para la ruta de datos y la memoria RAM.

#### Tabla de Estados y Salidas de Control (FSM Moore)

| Estado | Etapa / Función | Señales de Control Activas | Estado Siguiente |
| :--- | :--- | :--- | :--- |
| **`FETCH`** | Búsqueda de Instrucción | `IRWrite=1`, `PCUpdate=1`, `ALUSrcA=2'b00`, `ALUSrcB=2'b10`, `ALUControl=3'b000` (ADD), `ResultSrc=2'b10` | `DECODE` |
| **`DECODE`** | Decodificación y Lectura | `ALUSrcA=2'b01` ($OldPC$), `ALUSrcB=2'b01` ($Imm$), `ALUControl=3'b000` (ADD) | Según `opcode` |
| **`MEMADR`** | Cálculo Dir. Memoria | `ALUSrcA=2'b10` ($A$), `ALUSrcB=2'b01` ($Imm$), `ALUControl=3'b000` (ADD) | `MEMREAD` (`lw`) / `MEMWRITE` (`sw`/`sb`) |
| **`MEMREAD`** | Lectura de RAM | `AdrSrc=1` | `MEMWB` |
| **`MEMWB`** | Reescritura Carga | `ResultSrc=2'b01` ($Datos$), `RegWrite=1` | `FETCH` |
| **`MEMWRITE`** | Escritura en RAM | `AdrSrc=1`, `MemWrite=1` | `FETCH` |
| **`EXEC_I`** | Ejecución Arit/Lóg | `ALUSrcA=2'b10` ($A$), `ALUSrcB=2'b01` ($Imm$), `ALUControl` según `funct3` | `ALUWB` |
| **`EXEC_LUI`** | Carga Inmediato Alto | `ALUSrcB=2'b01` ($Imm$), `ALUControl=3'b100` (PASS-B) | `ALUWB` |
| **`ALUWB`** | Reescritura Registro | `ResultSrc=2'b00` ($ALUOut$), `RegWrite=1` | `FETCH` |
| **`BRANCH`** | Evaluación de Salto | `ALUSrcA=2'b10` ($A$), `ALUSrcB=2'b00` ($B$), `Branch=1`, `ALUControl=3'b001` (SUB) | `FETCH` |
| **`JAL1`** | Actualización PC Salto| `PCUpdate=1`, `ResultSrc=2'b00` ($ALUOut$) | `JAL2` |
| **`JAL2`** | Guardar Enlace $ra$ | `ALUSrcA=2'b01` ($OldPC$), `ALUSrcB=2'b10` (+4), `ResultSrc=2'b10`, `RegWrite=1` | `FETCH` |
| **`HALT`** | Estado de Parada | `halted = 1` (Mantiene congelado el procesador ante instrucción ilegal o fin de programa) | `HALT` |

---

### 17. Resumen de Señales de Control de la Microarquitectura

| Señal de Control | Ancho (bits) | Módulo Origen | Módulo Destino | Descripción / Función |
| :--- | :---: | :--- | :--- | :--- |
| `PCUpdate` | 1 | FSM (`control_fsm`) | `pc_write_logic` | Forzado incondicional de escritura en el $PC$ (fase de *Fetch* y *JAL*). |
| `Branch` | 1 | FSM (`control_fsm`) | `pc_write_logic` | Habilita la evaluación condicional de saltos (`bne`, `bge`). |
| `IRWrite` | 1 | FSM (`control_fsm`) | `reg_instructions` | Habilita la captura de la palabra de instrucción desde la RAM. |
| `AdrSrc` | 1 | FSM (`control_fsm`) | `mux_adr_src` | Selecciona dirección de RAM (`0`: $PC$, `1`: $Result$). |
| `MemWrite` | 1 | FSM (`control_fsm`) | `memory` | Habilita la escritura síncrona en la Memoria RAM. |
| `ByteWrite` | 4 | Decodificador | `memory` | Máscara de habilitación de byte para la instrucción `sb`. |
| `RegWrite` | 1 | FSM (`control_fsm`) | `register_file` | Habilita la escritura en el registro destino `Write_Reg`. |
| `ImmSrc` | 3 | Decodificador | `imm_extend` | Selector de formato de inmediato (`000`:I, `001`:S, `010`:B, `011`:J, `100`:U). |
| `ALUSrcA` | 2 | FSM (`control_fsm`) | `mux_alu_src_a` | Selector de entrada A de ALU (`00`:$PC$, `01`:$OldPC$, `10`:$A$). |
| `ALUSrcB` | 2 | FSM (`control_fsm`) | `mux_alu_src_b` | Selector de entrada B de ALU (`00`:$B$, `01`:$ImmExt$, `10`:$4$). |
| `ALUControl` | 3 | Decodificador ALU | `alu` | Operación de ALU (`000`:ADD, `001`:SUB, `010`:AND, `011`:SLL, `100`:PASS-B). |
| `ResultSrc` | 2 | FSM (`control_fsm`) | `mux_result_src` | Selector de resultado (`00`:$ALUOut$, `01`:$Datos$, `10`:$ALUDirecto$). |

---

## Documentación y Bitácora
- [Bitácora de Desarrollo](./bitacora/)
- [Diagramas de Arquitectura](./docs/)
- [Enunciado del Proyecto](./docs/Proyecto_Microprocesador_II_SEM_2026.pdf)

---

## Convenciones de Commits

Para mantener la trazabilidad y organización del proyecto, los commits del repositorio siguen el estándar de **Conventional Commits**:

```text
[tipo](módulo): Descripción breve del cambio en minúsculas

```

#### Tipos de Commit Utilizados:

* **`docs:`** Cambios en la documentación, bitácora (`/bitacora`), especificaciones o diagrama en el `README.md`.
* **`feat:`** Adición de nuevos módulos en Verilog (`/hdl`), testbenches (`/sim`) o scripts auxiliares.
* **`fix:`** Correcciones de errores sintácticos, de lógica o de señales en Verilog/simulación.
* **`refactor:`** Cambios en la arquitectura de hardware sin alterar la especificación funcional.
* **`chore:`** Tareas secundarias o mantenimiento del repositorio (limpieza de archivos, configuración).
