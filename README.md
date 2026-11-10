# Microarquitectura RV32I (Multiciclo)

**Curso:** MT-7003 Microprocesadores y Microcontroladores  
**Tecnológico de Costa Rica** | Escuela de Ingeniería Mecatrónica  
**Grupo N° 3** | II Semestre 2026  

## Descripción del Proyecto
Implementación de una microarquitectura multiciclo ([ver diagrama](docs/circuito_multiciclo_final.png)) en Verilog para el set reducido de instrucciones de enteros de la arquitectura de código abierto RISC-V (RV32I), validada en el entorno de simulación Vivado de AMD.

---

## Especificaciones del Procesador y Set de Instrucciones

### Análisis y Clasificación de Instrucciones RV32I
A partir del proceso de cross-compilación y [desensamblado](src/pm_ev_objdump_main.txt) del código en C suministrado, [`pm_ev_grupos_6_estudiantes.c`](src/pm_ev_grupos_6_estudiantes.c), se determinó un subconjunto mínimo de 10 instrucciones pertenecientes al ISA RV32I base, repartidas en 31 palabras de instrucción de 32 bits.

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

La señal de habilitación `PCWrite` es generada por la caja **Control de Escritura PC** (`pc_write_logic`), respondiendo formalmente a la siguiente ecuación booleana:

$$\text{PCWrite} = \text{PCUpdate} \lor \text{BranchTaken}$$

Donde la relación entre las señales de control y evaluación se divide en dos jerarquías conceptuales:
* **`Branch` (Control):** Señal booleana de 1 bit generada por la FSM que indica de forma general que la instrucción en curso es un salto condicional (`bne` o `bge`).
* **`BranchTaken` (Evaluación lógica):** Señal combinacional interna de la lógica de control que determina si el salto **efectivamente se cumple**, combinando la orden `Branch` con las banderas físicas emitidas por la ALU (`Zero` para evaluar desigualdad en `bne`, o `GE` para evaluar mayor o igual con signo en `bge`).

* **Durante la fase de Búsqueda (*Fetch* - Ciclo 1):** La FSM activa la señal incondicional `PCUpdate = 1`, lo que provoca que `PCWrite = 1`. En el flanco de subida del reloj, el PC almacena la suma de $PC + 4$ calculada por la ALU y entregada por el Mux `ResultSrc`.
* **Durante las fases intermedias (Ciclos 2 a 4):** Las señales `PCUpdate` y `Branch` se mantienen en `0`, forzando `PCWrite = 0`. Esto garantiza que la dirección del PC no varíe mientras la instrucción actual lee el Banco de Registros o accede a la Memoria de Datos.
* **During la fase de Salto Condicional (Instrucciones Tipo B):** Si la FSM emite `Branch = 1` y la ALU confirma que se cumple la condición requerida (`Zero = 0` para `bne` o `GE = 1` para `bge`), la lógica evalúa $\text{BranchTaken} = 1$. Esto activa `PCWrite = 1`, permitiendo que la dirección objetivo calculada de salto se cargue en el PC.

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
| `WriteData` | Entrada | 32 | Registro `B` | Dato de 32 bits entregado por el banco de registros para ser almacenado en la memoria. |
| `MemWrite` | Control | 1 | Unidad de Control (FSM) | Habilitador global de escritura (*Write Enable*). `1` activa la escritura en la RAM; `0` mantiene la memoria en modo lectura. |
| `ByteWrite` | Control | 4 | Unidad de Control (Decodificador) | Señal de habilitación de byte. Controla cuáles bytes específicos de la palabra de 32 bits deben ser modificados. |
| `ReadData` | Salida | 32 | Registros `Instrucciones` y `Datos` | Palabra de 32 bits leída en la dirección indicada por `Address`. La salida se conecta en paralelo a las entradas de los registros intermedios `Instrucciones` (IR) y `Datos` (MDR). |

#### Tabla de Funcionamiento y Operaciones de Memoria

| `MemWrite` | `ByteWrite` | Tipo de Acceso | Etapa de Ejecución | Instrucciones que lo Utilizan | Descripción de Operación |
| --- | --- | --- | --- | --- | --- |
| **`0`** | `4'b0000` | **Lectura (Read)** | *Fetch* | **Todas** las instrucciones (Ciclo 1) | Lee la palabra de instrucción apuntada por el `PC` y la deposita en la entrada del registro `Instrucciones`. |
| **`0`** | `4'b0000` | **Lectura (Read)** | *Memory Access* | `lw` | Lee la palabra de datos de 32 bits ubicada en la dirección calculada por la ALU y la deposita en el registro `Datos`. |
| **`1`** | `4'b1111` | **Escritura Word** | *Memory Access* | `sw` | Escribe los 32 bits del registro `Write Data` en la dirección de memoria apuntada por `ALUOut`. |
| **`1`** | `4'b0001`* | **Escritura Byte** | *Memory Access* | `sb` | Escribe únicamente los 8 bits menos significativos del registro `Write Data` (`WriteData[7:0]`) en la dirección correspondiente, según los bits `Address[1:0]`. |

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

* **Módulo:** `registers`
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

**Nota de Implementación en Verilog:* Para evitar la propagación de estados indeterminados (X) durante la simulación de instrucciones como lui (donde la ALU ignora el puerto A), el selector ALUSrcA debe ser forzado a un valor seguro determinista (2'b00) por la FSM, o el bloque Verilog del multiplexor debe incluir una cláusula default: out_src_a = in_pc;.

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
| `in_reg_datos` | Entrada | 32 | Registro `Datos` | Dato de 32 bits leído desde la Memoria Unificada y retenido durante la etapa de *Memory*. |
| `in_alu` | Entrada | 32 | Unidad Aritmética Lógica (`ALU`) | Resultado combinacional directo (sin registrar) proveniente de la salida de la ALU. |
| `ResultSrc` | Control | 2 | Unidad de Control (FSM) | Selector de 2 bits emitiendo el código de control que determina la fuente del bus de resultado. |
| `out_result` | Salida | 32 | Banco de Registros (`Write_Data`), Mux `AdrSrc`, `PC` | Bus de resultado final entregado a la reescritura de registros, dirección de memoria o actualización del $PC$. |

#### Tabla de Selección y Operación (`ResultSrc`)

| `ResultSrc` | Salida (`out_result`) | Etapa de Ejecución | Instrucciones que lo Utilizan | Descripción de Operación |
| --- | --- | --- | --- | --- |
| **`2'b00`** | `in_reg_alu` (`ALUOut`) | *Write-Back* / *Memory* | Tipo I, Tipo S | Entrega el resultado de operaciones aritméticas/lógicas o la dirección efectiva calculada en el ciclo previo hacia la reescritura de registros (`Write_Data`) o a la memoria (`in_result` del Mux `AdrSrc`). |
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

* **Módulo:** `reg_datos`
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

### 16. Unidad de Control (FSM Principal)

* **Módulo:** `control_fsm`
* **Tipo:** Máquina de Estados Finitos (FSM) tipo Moore, implementada mediante lógica secuencial síncrona y lógica combinacional para la decodificación de siguiente estado y salidas.
* **Propósito:** Actuar como el núcleo de coordinación de la microarquitectura multiciclo. Lee los bits de la instrucción actual (`opcode`) desde el registro `Instrucciones` para transitar entre estados y generar las señales de control de alto nivel que rigen la ruta de datos y los accesos a memoria en cada ciclo de reloj.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `clk` | Entrada | 1 | Sistema | Señal de reloj principal. Las transiciones de estado de la FSM ocurren en el flanco de subida (*posedge*). |
| `rst` | Entrada | 1 | Sistema | Reinicio global. Restablece la máquina de estados de manera síncrona o asíncrona al estado inicial `FETCH`. |
| `opcode` | Entrada | 7 | Registro `Instrucciones[6:0]` | Código de operación de la instrucción actual. Utilizado por la FSM combinacional para determinar el estado siguiente tras la decodificación. |
| `PCUpdate` | Salida | 1 | Control Escritura PC (`pc_write_logic`) | Fuerza la habilitación de escritura del $PC$. Se activa incondicionalmente en la fase de *Fetch* y en la instrucción `jal`. |
| `Branch` | Salida | 1 | Control Escritura PC (`pc_write_logic`) | Indica que se está evaluando un salto condicional (`bne`, `bge`), habilitando la lógica de cálculo `BranchTaken`. |
| `IRWrite` | Salida | 1 | Registro `Instrucciones` | Habilita la captura de una nueva instrucción desde la Memoria Unificada hacia el registro `Instrucciones`. |
| `MemWrite` | Salida | 1 | Memoria Unificada (`Memory`) | Habilitador global de escritura síncrona en la memoria RAM. |
| `RegWrite` | Salida | 1 | Banco de Registros (`Registers`) | Habilitador de escritura en el registro destino `rd` seleccionado. |
| `ResultSrc` | Salida | 2 | Mux `ResultSrc` | Selector que define el origen del dato de escritura o actualización del $PC$ (`00`=$ALUOut$, `01`=$Datos$, `10`=$ALU$). |
| `ALUSrcA` | Salida | 2 | Mux `ALUSrcA` | Selector del primer operando de la ALU (`00`=$PC$, `01`=$OldPC$, `10`=$A$). |
| `ALUSrcB` | Salida | 2 | Mux `ALUSrcB` | Selector del segundo operando de la ALU (`00`=$B$, `01`=$ImmExt$, `10`=Constante 4). |
| `AdrSrc` | Salida | 1 | Mux `AdrSrc` | Selector de dirección para la RAM (`0`=$PC$, `1`=Dirección en `ALUOut`). |
|`ALUOp` | Salida | 2 | Decodificador ALU (alu_decoder)| Código genérico de operación de la ALU (`00`=$ADD$, `01`=$SUB$, `10`=$Tipo-I$, `11`=$PASS-B$). |
| `halted` | Salida | 1 | Salida Superior (*Top Level*) | Bandera de parada. Se evalúa en `'1'` al detectar una instrucción no soportada o alcanzar el final del programa, congelando la FSM en el estado `HALT`. |

*(Nota: Las señales refinadas como `ALUControl`, `ImmSrc` y `ByteWrite` se generan en decodificadores auxiliares anexos a la FSM para evitar explosión de estados).*

#### Tabla de Estados y Generación de Señales (Tipo Moore)

| Estado de la FSM | Operación Lógica en la Ruta de Datos | Señales de Control Activas | Estado Siguiente |
| --- | --- | --- | --- |
| **`FETCH`** | Búsqueda de Instrucción:<br><br>1. Lee instrucción de RAM usando $PC$.<br><br>2. Guarda en registro `Instrucciones`.<br><br>3. Calcula y actualiza $PC = PC + 4$. | `IRWrite = 1`<br><br>`PCUpdate = 1`<br><br>`AdrSrc = 0`<br><br>`ALUSrcA = 2'b00` ($PC$)<br><br>`ALUSrcB = 2'b10` (4)<br><br>`ResultSrc = 2'b10` ($ALU$)<br><br>`ALUOp = 2'b00` (ADD) | Transición incondicional a `DECODE`. |
| **`DECODE`** | Decodificación y Lectura:<br><br>1. El Banco de Registros entrega asíncronamente $rs1$ a $A$ y $rs2$ a $B$.<br><br>2. ALU calcula dirección base para posibles saltos ($OldPC + ImmExt$) y almacena en `ALUOut`. | `ALUSrcA = 2'b01` ($OldPC$)<br><br>`ALUSrcB = 2'b01` ($ImmExt$)<br><br>`ALUOp = 2'b00` (ADD) | Depende del `opcode` (`MEMADR`, `EXEC_I`, `EXEC_LUI`, `BRANCH`, `JAL1` o `HALT`). |
| **`MEMADR`** | Cálculo de Dirección Base:<br><br>Calcula dirección de acceso a RAM sumando el registro base $A$ ($rs1$) con el inmediato (*offset*), depositando en `ALUOut`. | `ALUSrcA = 2'b10` ($A$)<br><br>`ALUSrcB = 2'b01` ($ImmExt$)<br><br>`ALUOp = 2'b00` (ADD) | Si `lw` $\rightarrow$ `MEMREAD`<br><br>Si `sw`/`sb` $\rightarrow$ `MEMWRITE`. |
| **`MEMREAD`** | Lectura de RAM:<br><br>La memoria lee los datos apuntados por `ALUOut` y los deposita en el bus, listos para ser muestreados por el registro `Datos`. | `AdrSrc = 1` ($ALUOut$) | Transición incondicional a `MEMWB`. |
| **`MEMWB`** | Reescritura Carga a Registro:<br><br>Transfiere la palabra desde el registro `Datos` hacia el Banco de Registros. | `ResultSrc = 2'b01` ($Datos$)<br><br>`RegWrite = 1` | Transición a `FETCH`. |
| **`MEMWRITE`** | Escritura en RAM:<br><br>Almacena la palabra o byte presente en el registro `B` dentro de la RAM usando la dirección en `ALUOut`. | `AdrSrc = 1` ($ALUOut$)<br><br>`MemWrite = 1` | Transición a `FETCH`. |
| **`EXEC_I`** | Ejecución Arit/Lóg:<br><br>Procesa en la ALU el registro $A$ ($rs1$) contra el inmediato $ImmExt$ (para `addi`, `slli`, `andi`) y guarda en `ALUOut`. | `ALUSrcA = 2'b10` ($A$)<br><br>`ALUSrcB = 2'b01` ($ImmExt$)<br><br>`ALUOp = 2'b10` decodificado según `funct3` | Transición a `ALUWB`. |
| **`EXEC_LUI`** | Carga de Inmediato Superior:<br><br>La ALU ejecuta la operación PASS-B, transfiriendo directamente el inmediato del registro `Instrucciones` al registro `ALUOut`. | `ALUSrcA = 2'b00` (Irrelevante)<br><br>`ALUSrcB = 2'b01` ($ImmExt$)<br><br>`ALUOp = 2'b11` (PASS-B) | Transición a `ALUWB`. |
| **`ALUWB`** | Reescritura ALU a Registro:<br><br>Transfiere el resultado computado desde `ALUOut` hacia el Banco de Registros. | `ResultSrc = 2'b00` ($ALUOut$)<br><br>`RegWrite = 1` | Transición a `FETCH`. |
| **`BRANCH`** | Evaluación de Salto Condicional:<br><br>La ALU realiza una resta o evaluación de signo entre $A$ ($rs1$) y $B$ ($rs2$). Emite señal genérica de control de salto `Branch`. | `ALUSrcA = 2'b10` ($A$)<br><br>`ALUSrcB = 2'b00` ($B$)<br><br>`ALUOp = 2'b01` (SUB)<br><br>**`Branch = 1`** | Transición a `FETCH`. |
| **`JAL1`** | Ejecutar Salto Incondicional:<br><br>Fuerza la carga inmediata de la dirección objetivo (previamente calculada en `DECODE` y retenida en `ALUOut`) en el $PC$. | **`PCUpdate = 1`**<br><br>`ResultSrc = 2'b00` ($ALUOut$) | Transición a `JAL2`. |
| **`JAL2`** | Guardar Dirección de Retorno:<br><br>Calcula y almacena la dirección de la siguiente instrucción secuencial ($OldPC + 4$) en el Banco de Registros ($ra$/$rd$). | `ALUSrcA = 2'b01` ($OldPC$)<br><br>`ALUSrcB = 2'b10` (4)<br><br>`ResultSrc = 2'b10` ($ALU$)<br><br>`RegWrite = 1`<br><br>`ALUOp = 2'b00` (ADD) | Transición a `FETCH`. |
| **`HALT`** | Parada de Ejecución:<br><br>Estado trampa que bloquea el avance del procesador. Se alcanza si el `opcode` decodificado no pertenece al subconjunto soportado o si se lee una instrucción en ceros (`0x00000000`). | `halted = 1`<br><br>Todas las señales de escritura en `0`. | Se mantiene en `HALT` de forma infinita hasta reiniciar el sistema con `rst`. |

#### Descripción Operativa

La **Unidad de Control (FSM)** organiza la ejecución temporal de cada instrucción garantizando que los módulos físicos (memoria, banco de registros, ALU) operen en fases coordinadas sin causar colisiones de datos en los buses, logrando la estructura multiciclo fundamental de la arquitectura.

1. **Diseño Tipo Moore:** La FSM implementada es del tipo Moore, lo que significa que el valor de las señales de control de salida depende única y exclusivamente del estado actual de la máquina y no de transiciones instantáneas, lo que garantiza estabilidad en las entradas asíncronas de los multiplexores y la ALU durante todo un pulso de reloj completo.
2. **Desacoplamiento de Complejidad:** La FSM no emite los códigos de control finos (como el selector aritmético exacto `ALUControl` o el bit de enmascaramiento de memoria `ByteWrite`). Únicamente activa el estado general (ej. `EXEC_I`); son los bloques decodificadores auxiliares independientes quienes mezclan este estado general con los sub-campos de instrucción `funct3` y `funct7` para concretar las acciones.

---

### 17. Control de Escritura PC (`pc_write_logic`)

* **Módulo:** `pc_write_logic`
* **Tipo:** Lógica combinacional.
* **Propósito:** Evaluar y sintetizar las banderas booleanas provenientes de la FSM de Control y de la Unidad Aritmética Lógica (ALU) para emitir la señal definitiva de habilitación de escritura (`PCWrite`) que permite la modificación del registro Program Counter.

#### Tabla de Interfaz (Puertos)

| Puerto | Dirección | Ancho (bits) | Origen / Destino | Descripción |
| --- | --- | --- | --- | --- |
| `PCUpdate` | Entrada | 1 | Unidad de Control (FSM) | Habilitador incondicional. Ordena escribir el PC sin importar evaluaciones lógicas (se usa para saltos incondicionales `jal` y el avance base del $PC+4$ en *Fetch*). |
| `Branch` | Entrada | 1 | Unidad de Control (FSM) | Habilitador condicional. Señal proveniente del estado `BRANCH` que indica que el procesador está intentando ejecutar un salto sujeto a evaluación matemática. |
| `Zero` | Entrada | 1 | Unidad Aritmética Lógica (`ALU`) | Bandera de Cero. Indica que el resultado de la sustracción en la ALU fue nulo (ambos operandos eran iguales). Se emplea para evaluar la desigualdad en la instrucción `bne`. |
| `GE` | Entrada | 1 | Unidad Aritmética Lógica (`ALU`) | Bandera de Mayor o Igual (*Greater or Equal*). Se activa si, interpretando los valores con signo, $SrcA \ge SrcB$. Evalúa el salto de la instrucción `bge`. |
| `funct3` | Entrada | 3 | Registro `Instrucciones[14:12]` | Campo de instrucción. Opcional/Requerido para discriminar la instrucción exacta dentro del formato de saltos (ej. `001` para `bne`, `101` para `bge`). |
| `PCWrite` | Salida | 1 | Program Counter (`PC`) | Señal global generada hacia el pin `Write Enable` del registro PC. Permite cargar la dirección presente en la entrada `in_pc_next`. |

#### Lógica Booleana y Generación de Señales Internas

El corazón de este bloque radica en la generación interna de la señal combinacional **`BranchTaken`**, la cual consolida la intención de salto (`Branch`=1) con la evaluación matemática efectiva provista por las banderas de la ALU.

1. **Determinación del Tipo de Salto:** La lógica interna lee el campo `funct3` (disponible desde el registro `Instrucciones`) para determinar qué condición está siendo evaluada en el ciclo actual:
* **Es `bne**`: Se detecta al leer `funct3 == 3'b001`. El salto se efectúa si los operandos son **diferentes**, por lo cual la bandera `Zero` de la ALU debe ser estrictamente `0` ($\neg\text{Zero}$).
* **Es `bge**`: Se detecta al leer `funct3 == 3'b101`. El salto se efectúa si $rs1 \ge rs2$ en magnitud signada, condición confirmada por la bandera directa $\text{GE} == 1$.

2. **Evaluación Efectiva (`BranchTaken`):** Esta señal interna se sintetiza combinando la intención con la confirmación:

$$\text{BranchTaken} = \text{Branch} \land \left[(\text{is bne} \land \neg\text{Zero}) \lor (\text{is bge} \land \text{GE}) \right]$$

3. **Ecuación de Salida (`PCWrite`):** La señal principal del módulo entregada al registro físico responde formalmente a un agrupamiento OR lógico:

$$\text{PCWrite} = \text{PCUpdate} \lor \text{BranchTaken}$$

#### Descripción Operativa

El módulo **Control de Escritura PC (`pc_write_logic`)** aísla la toma de decisiones críticas de direccionamiento para no sobrecargar el flujo estático de la FSM de Control Principal. Su principal utilidad radica en la asincronía de la evaluación.

Al encontrarse en el estado `BRANCH` de la máquina de estados, el reloj interno del sistema no avanza el estado hasta evaluar la condición de la ALU. Las banderas físicas resultantes (`Zero`, `GE`) viajan velozmente al bloque `pc_write_logic` a través de los buses combinacionales. Si la condición lógica se cumple, la salida combinacional `PCWrite` conmuta inmediatamente a `'1'`. De este modo, al ocurrir el flanco de subida al finalizar el estado, la condición ya ha sido debidamente procesada y el $PC$ efectúa la actualización sincrónica con su nueva dirección destino ($OldPC + ImmExt$) o, de fallar la condición, descarta el salto y permanece apuntando a $PC+4$.

---

### 18. Decodificadores Auxiliares

* **Módulos:** `imm_decoder`, `alu_decoder`, `byte_decoder`.
* **Tipo:** Lógica combinacional pura.
* **Propósito:** Desacoplar la complejidad de la FSM principal evaluando campos específicos de la instrucción (`opcode`, `funct3`, `funct7`) y bits de alineación de memoria para generar señales de control granulares y exactas.

#### 18.1 Decodificador de Inmediatos (`imm_decoder`)

Se encarga de identificar el formato de la instrucción actual a partir de su código de operación (`opcode`) para instruir al módulo `imm_extend` sobre cómo reordenar los bits.

| `opcode` (Instrucción `[6:0]`) | Tipo de Instrucción detectado | Salida `ImmSrc` | Operación en Módulo `imm_extend` |
| --- | --- | --- | --- |
| `0010011` / `0000011` | **Tipo I** (`addi`, `lw`, `slli`, `andi`) | **`3'b000`** | Extensión de signo de 12 bits (`Instr[31:20]`). |
| `0100011` | **Tipo S** (`sw`, `sb`) | **`3'b001`** | Concatenación de campos bajos y altos (`Instr[31:25]`, `Instr[11:7]`). |
| `1100011` | **Tipo B** (`bne`, `bge`) | **`3'b010`** | Reconstrucción de salto de 13 bits con $LSB = 0$. |
| `1101111` | **Tipo J** (`jal`) | **`3'b011`** | Reconstrucción de salto de 21 bits con $LSB = 0$. |
| `0110111` | **Tipo U** (`lui`) | **`3'b100`** | Desplazamiento a la parte alta con 12 ceros inferiores. |

#### 18.2 Decodificador de ALU (`alu_decoder`)

Traduce una señal de 2 bits de "Operación Genérica" (`ALUOp`) emitida por la FSM y los campos de la instrucción en el código de 3 bits exacto (`ALUControl`) que consume la ALU física.

| `ALUOp` (FSM) | `funct3` (Inst. `[14:12]`) | Instrucción Efectiva | Salida `ALUControl` | Acción en la ALU |
| --- | --- | --- | --- | --- |
| **`00`** | `XXX` | Cargas, Saltos, PC+4 | **`3'b000`** | Suma incondicional (`ADD`). |
| **`01`** | `XXX` | Evaluación de condición | **`3'b001`** | Resta incondicional (`SUB`). |
| **`11`** | `XXX` | Carga constante superior | **`3'b100`** | Transfiere entrada B directo (`PASS-B`). |
| **`10`** | `000` | Aritmética (`addi`) | **`3'b000`** | Suma (`ADD`). |
| **`10`** | `111` | Lógica de enmascaramiento (`andi`) | **`3'b010`** | AND lógico bit a bit. |
| **`10`** | `001` | Desplazamiento (`slli`) | **`3'b011`** | Desplazamiento lógico a la izquierda (`SLL`). |

#### 18.3 Decodificador de Máscara de Memoria (`byte_decoder`)

Genera el bus `ByteWrite` de 4 bits exigido por el bloque de RAM para gobernar las escrituras aisladas de bytes durante instrucciones Tipo S, basándose en la alineación física.

| `MemWrite` | `funct3` | Tipo de Almacenamiento | `Address[1:0]` (Alineación) | Salida `ByteWrite` | Acción Física en RAM |
| --- | --- | --- | --- | --- | --- |
| **`0`** | `XXX` | Lectura general | `XX` | **`4'b0000`** | Bloquea toda escritura. |
| **`1`** | `010` | Palabra (`sw`) | `XX` (Asume alineado) | **`4'b1111`** | Sobrescribe los 4 bytes simultáneamente. |
| **`1`** | `000` | Byte independiente (`sb`) | `2'b00` | **`4'b0001`** | Sobrescribe únicamente el byte 0 (bits `[7:0]`). |
| **`1`** | `000` | Byte independiente (`sb`) | `2'b01` | **`4'b0010`** | Sobrescribe únicamente el byte 1 (bits `[15:8]`). |
| **`1`** | `000` | Byte independiente (`sb`) | `2'b10` | **`4'b0100`** | Sobrescribe únicamente el byte 2 (bits `[23:16]`). |
| **`1`** | `000` | Byte independiente (`sb`) | `2'b11` | **`4'b1000`** | Sobrescribe únicamente el byte 3 (bits `[31:24]`). |

---

### 19. Interconexión del *Datapath* (Ruta de Datos)

La microarquitectura orquesta sus 18 bloques lógicos, registros secuenciales y unidades aritméticas a través de un esquema de buses de 32 bits jerarquizado en 5 grandes zonas de interconexión física:

#### 1. Malla de Direccionamiento de Memoria (Búsqueda y Acceso a RAM)

* El registro físico **`PC`** entrega continuamente la dirección actual en el puerto `in_pc` del multiplexor **`mux_adr_src`**.
* El registro **`ALUOut`** (que contiene la dirección efectiva calculada en ciclos previos) se enlaza con el puerto `in_result` del **`mux_adr_src`** a través del canal `00` del bus principal de resultados.
* El **`mux_adr_src`** encamina una única dirección de 32 bits hacia el puerto `Address` de la **`Memory`**, compartiendo hardware para fases de *Fetch* y acceso a *Datos*.

#### 2. Red de Extracción y Distribución de Instrucciones (Decodificación)

* Durante el *Fetch*, la **`Memory`** emite una palabra en `ReadData`, capturada por el registro **`Instrucciones`** al activar `IRWrite`.
* El bus de salida `out_instruction` del registro **`Instrucciones`** se divide topológicamente:
* Los bits `[6:0]` alimentan a la **FSM de Control** (`opcode`).
* Los bits `[19:15]`, `[24:20]` y `[11:7]` enrutan físicamente hacia las entradas `Read_Reg_1`, `Read_Reg_2` y `Write_Reg` del **Banco de Registros**.
* Los bits `[31:7]` cruzan masivamente hacia el generador **`imm_extend`**.
* Los bits `[14:12]` (`funct3`) alimentan a los decodificadores auxiliares **`alu_decoder`** y **`byte_decoder`**.



#### 3. Bus de Operandos y Ejecución (ALU)

* El **Banco de Registros** extrae el contenido direccionado asíncronamente. En el flanco activo, estos operandos se retienen de forma segura en los registros **`A`** y **`B`**.
* El canal `SrcA` de la ALU requiere convergencia: se alimenta desde el **`mux_alu_src_a`**, recogiendo buses del **`PC`**, **`OldPC`** y el registro intermedio **`A`**.
* El canal `SrcB` de la ALU requiere un abanico mayor: se alimenta desde el **`mux_alu_src_b`**, convergiendo el registro intermedio **`B`**, la expansión de 32 bits desde **`imm_extend`** y un alambre con una constante en hardware (`32'd4`).
* La salida de la **`ALU`** se divide inmediatamente en una vía asíncrona hacia el multiplexor final, y una vía síncrona retenida mediante el registro **`ALUOut`**.

#### 4. Bus de Transferencia y Escritura a RAM

* El registro intermedio **`B`**, además de abastecer a la ALU, enruta su salida `out_b` de manera directa hacia el puerto `WriteData` de la **`Memory`**.
* Esto permite inyectar datos para instrucciones de almacenamiento (`sw`, `sb`) de forma paralela a cualquier cómputo en la ALU.

#### 5. Malla de Resultados, Reescritura y Lazos de Retorno (Write-Back)

* El eje central de retroalimentación es el **`mux_result_src`**, el cual unifica la salida estabilizada en **`ALUOut`**, la información extraída de RAM retenida en el registro **`Datos`**, y un lazo de bypass asíncrono desde la **`ALU`**.
* La salida global de este multiplexor (`out_result`) retorna masivamente a lo largo de toda la placa de circuito para:
1. Ingresar en el puerto `Write_Data` del **Banco de Registros** para modificar el contexto de software.
2. Proveer direcciones a la memoria para el multiplexor **`mux_adr_src`**.
3. Ingresar al puerto `in_pc_next` del **`PC`** para la actualización de saltos y flujos.


* En paralelo, las líneas físicas puras de 1 bit generadas en la ALU (`Zero`, `GE`) viajan ininterrumpidamente hacia el módulo combinacional **`pc_write_logic`**, el cual cierra el ciclo realimentando la orden `PCWrite` sobre el Program Counter.

---

### 20. Tabla Maestra de Señales de Control de la Microarquitectura

Esta matriz define el diccionario oficial de conmutación de la microarquitectura. Detalla el origen en la jerarquía de control y su impacto exacto en el *datapath*.

| Señal de Control | Ancho (bits) | Módulo Origen | Módulo Destino | Descripción y Función de Hardware |
| --- | --- | --- | --- | --- |
| **`PCUpdate`** | 1 | Unidad de Control (FSM) | `pc_write_logic` | Activador incondicional lógico para la escritura del PC. Su valor en `'1'` fuerza el avance del puntero inminentemente en fases de *Fetch* y `jal`. |
| **`Branch`** | 1 | Unidad de Control (FSM) | `pc_write_logic` | Indicador de salto. Ordena al bloque auxiliar habilitar la matriz de evaluación para interpretar las banderas de la ALU durante ciclos `BRANCH`. |
| **`BranchTaken`** | 1 | `pc_write_logic` (Bloque Interno) | `pc_write_logic` | *Señal de lógica interna sintetizada*. Evalúa como `'1'` cuando el salto condicional es verificado y concedido por el circuito. |
| **`PCWrite`** | 1 | `pc_write_logic` | `pc` | Clavija final habilitadora. Permite al Flip-Flop del contador de programa cargar el bus alojado en `in_pc_next`. |
| **`IRWrite`** | 1 | Unidad de Control (FSM) | `reg_instructions` | Segregador de estado. Cuando es `'1'` (Ciclo 1), el registro absorbe el estado de la RAM; cuando es `'0'`, aisla la instrucción y la estabiliza. |
| **`AdrSrc`** | 1 | Unidad de Control (FSM) | `mux_adr_src` | Selector del bus de direcciones hacia la RAM. `'0'` rutea el avance del $PC$, `'1'` enruta los resultados estabilizados en $ALUOut$. |
| **`MemWrite`** | 1 | Unidad de Control (FSM) | `memory` | Puerta maestra de escritura para el bloque de RAM síncrona. Si es `'0'`, la memoria no permite modificaciones independientemente del bus. |
| **`ByteWrite`** | 4 | `byte_decoder` | `memory` | Conmutador fino para el habilitador de bytes de la RAM, permitiendo almacenar la memoria palabra entera (`1111`) o selectiva parcial (ej. `0100`). |
| **`RegWrite`** | 1 | Unidad de Control (FSM) | `registers` | Activador de escritura sobre el arreglo de 32x32. Habilita la actualización en la celda designada por `Write_Reg` (`rd`). |
| **`ImmSrc`** | 3 | `imm_decoder` | `imm_extend` | Comando que dictamina al generador interno el tipo de instrucción que está decodificando, indicando cómo desempaquetar y extender el inmediato. |
| **`ALUSrcA`** | 2 | Unidad de Control (FSM) | `mux_alu_src_a` | Administrador del canal A. Define si el cómputo se hará utilizando la dirección del `$PC$`, el resguardo de saltos en `$OldPC$` o el registro temporal de lectura `$A$`. |
| **`ALUSrcB`** | 2 | Unidad de Control (FSM) | `mux_alu_src_b` | Administrador del canal B. Alterna entre procesar la constante secuencial (`$4$`), el `$ImmExt$`, o el registro fuente complementario `$B$`. |
| ALUOp | 2 | Unidad de Control (FSM) | alu_decoder | Código genérico de operación (00=Suma, 01=Resta, 10=Tipo I, 11=PASS-B) enviado al decodificador secundario. |
| **`ALUControl`** | 3 | `alu_decoder` | `alu` | Selector determinista que transforma la etapa de estado y los bits directos `funct3` en la orden de aritmética física (Suma, Resta, PASS-B, AND, SLL). |
| **`ResultSrc`** | 2 | Unidad de Control (FSM) | `mux_result_src` | Selector de reescritura principal del procesador. Define si la salida de datos de todo el *datapath* es una memoria (`$Datos$`), registro interno retenido (`$ALUOut$`) o paso lógico sin estado (`$ALU$`). |
| **`halted`** | 1 | Unidad de Control (FSM) | Sistema Externo (Top) | Indicador visual de trampa (trap). Refleja externamente que el sistema interceptó una interrupción sin manejar, apagando la secuencia dinámica. |

---

---

## Resultados de Simulación y *Memory Dump*

A continuación se presenta el cuadro resumen con el estado final de la memoria unificada obtenido tras la simulación del procesador en Vivado. Muestra tanto el segmento de código (palabras de instrucción desde `0x0` hasta `0x78`) como la zona de almacenamiento de variables de datos (`0x3E0` a `0x3FC`), reflejando la ejecución de las instrucciones de almacenamiento (`sb`, `sw`), carga (`lui`) y control de flujo.

| Dirección de Memoria | Valor en hexadecimal |
| :--- | :--- |
| **Inicia** | **Instrucciones** |
| `0x0` | `0xfe010113` |
| `0x4` | `0x00112e23` |
| `0x8` | `0x00812c23` |
| `0xC` | `0x02010413` |
| `0x10` | `0x0000c7b7` |
| `0x14` | `0x7df78793` |
| `0x18` | `0xfef42223` |
| `0x1C` | `0x06300793` |
| `0x20` | `0xfef401a3` |
| `0x24` | `0x02100793` |
| `0x28` | `0xfef42623` |
| `0x2C` | `0xfe042423` |
| `0x30` | `0x03c0006f` |
| `0x34` | `0xfe842783` |
| `0x38` | `0x00079863` |
| `0x3C` | `0x06200793` |
| `0x40` | `0xfef401a3` |
| `0x44` | `0x01c0006f` |
| `0x48` | `0xfec42783` |
| `0x4C` | `0x00179793` |
| `0x50` | `0xfef42623` |
| `0x54` | `0xfec42783` |
| `0x58` | `0x00f7f793` |
| `0x5C` | `0xfef42623` |
| `0x60` | `0xfe842783` |
| `0x64` | `0x00178793` |
| `0x68` | `0xfef42423` |
| `0x6C` | `0xfe842703` |
| `0x70` | `0x00100793` |
| `0x74` | `0xfce7d0e3` |
| `0x78` | `0x00000793` |
| **Finaliza** | **Instrucciones** |
| **Inicia** | **Variables** |
| `0x3E0` | `0x62xxxxxx` |
| `0x3E4` | `0x0000c7df` |
| `0x3E8` | `0x00000002` |
| `0x3EC` | `0x00000002` |
| `0x3F8` | `0x00000000` |
| `0x3FC` | `0x00000000` |
| **Finaliza** | **Variables** |

---

## Documentación y Bitácora
- [Bitácora de Desarrollo](./bitacora/)
- [Diagramas de Arquitectura](./docs/)
- [Enunciado del Proyecto](./docs/Proyecto_Microprocesador_II_SEM_2026.pdf)
- [Módulos de Implementación](./hdl/)
- [Testbench de simulación](./sim/)

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
