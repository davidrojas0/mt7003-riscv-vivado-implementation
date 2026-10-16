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

## Documentación y Bitácora
- [Bitácora de Desarrollo](./bitacora/)
- [Diagramas de Arquitectura](./docs/)
- [Enunciado del Proyecto](./docs/Proyecto_Microprocesador_II_SEM_2026.pdf)
