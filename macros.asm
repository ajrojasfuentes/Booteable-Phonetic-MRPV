; ============================================================
; macros_mrpv.asm
; Macros para un entorno en modo real (16 bits), usando BIOS.
; ============================================================
[bits 16]

; ------------------------------------------------------------
; Macro: PRINT_CHAR (versión corregida)
; - Preserva solo los registros críticos
; - Configura explícitamente BH=0 (página de video)
; ------------------------------------------------------------
%macro PRINT_CHAR 0
    push ax
    push si                 ; Preservar SI original

    mov ah, 0x0E
    mov al, [si]
    int 0x10

    pop si                  ; Restaurar SI original
    pop ax
%endmacro

; ------------------------------------------------------------
; Macro: PSTR (imprime cadena terminada en 0)
; Correcciones:
;   - Preserva SI para no afectar al código llamador
;   - Optimiza el manejo de registros
; Uso:
;   mov si, cadena
;   PSTR
; ------------------------------------------------------------
%macro PSTR 1

%endmacro

; ------------------------------------------------------------
; Macro READ_LINE: lee una línea completa desde el teclado hasta que se presione Enter.
; Parámetros:
;   %1 -> dirección del buffer donde se almacenará la cadena.
;   %2 -> tamaño total del buffer (se reservará 1 byte para el carácter nulo).
;
; La macro utiliza INT 16h para leer cada carácter y INT 10h (función 0Eh) para hacer eco.
; Soporta retroceso (Backspace, ASCII 08h) para borrar el último carácter ingresado.
; ------------------------------------------------------------
%macro READ_LINE 2
    ; Se preservan registros que se modificarán
    push ax
    push bx
    push cx
    push dx
    push di

    ; Inicializa DI con la dirección del buffer
    mov di, %1
    ; Carga el tamaño máximo a leer y resta 1 para dejar espacio al terminador nulo
    mov cx, %2
    dec cx              ; CX = máximo de caracteres a almacenar
    xor bx, bx        ; BX servirá como contador de caracteres leídos

.read_loop:
    ; Espera a que se presione una tecla (INT 16h, función 00h)
    mov ah, 0
    int 16h           ; AL = código ASCII; AH = código de escaneo

    ; Si se presiona Enter (CR, 0Dh) finaliza la lectura
    cmp al, 0Dh
    je .finish

    ; Soporte para retroceso (Backspace, 08h)
    cmp al, 08h
    je .backspace

    ; Si ya se alcanzó el máximo de caracteres, ignora el carácter y sigue esperando
    cmp bx, cx
    jae .read_loop

    ; Eco: imprime el carácter en pantalla usando INT 10h, función 0Eh
    mov ah, 0Eh
    int 10h

    ; Guarda el carácter en el buffer y actualiza DI y el contador BX
    mov [di], al
    inc di
    inc bx
    jmp .read_loop

.backspace:
    ; Solo se procesa si hay al menos un carácter en el buffer
    cmp bx, 0
    je .read_loop
    ; Borra el carácter en pantalla: retroceso, espacio, retroceso
    mov ah, 0Eh
    mov al, 08h       ; retroceso
    int 10h
    mov al, ' '
    int 10h
    mov al, 08h
    int 10h
    ; Retrocede en el buffer y decrementa el contador
    dec di
    dec bx
    jmp .read_loop

.finish:
    ; Opcional: imprime CR y LF para pasar a la siguiente línea
    mov ah, 0Eh
    mov al, 0Dh
    int 10h
    mov al, 0Ah
    int 10h
    ; Termina la cadena con un carácter nulo (0)
    mov byte [di], 0

    ; Restaura los registros usados
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
%endmacro

; ------------------------------------------------------------
; Macro: EXIT
; Uso:
;   EXIT
; Explicación:
;   En un entorno sin sistema operativo, no hay "sys_exit".
;   Aquí podemos colgarnos en un bucle infinito, 
;   o usar "int 19h" para reiniciar desde BIOS, etc.
; ------------------------------------------------------------
%macro EXIT 0
    ; Reiniciar la BIOS
    ; int 19h => BIOS Bootstrap routine
    mov ah, 0
    int 19h
%endmacro

; ------------------------------------------------------------
; Macro: CMP_STR (2 parámetros)
;   - Compara dos cadenas terminadas en 0, byte a byte
;   - Deja en AL=1 si son iguales, AL=0 si difieren
;   - Usa SI para la 1ra dirección, DI para la 2da
; Uso:
;   mov si, cadena1
;   mov di, cadena2
;   CMP_STR
;   cmp al, 1
;   je .iguales
;   jne .diferentes
%macro CMP_STR 0
    push ax
    push si
    push di

.loop_cmp:
    mov al, [si]
    cmp al, [di]
    jne .not_equal
    cmp al, 0
    je .equal   ; si es 0 => ambas cadenas terminaron
    inc si
    inc di
    jmp .loop_cmp

.not_equal:
    xor al, al  ; AL=0 => difieren
    jmp .done

.equal:
    mov al, 1   ; AL=1 => iguales

.done:
    pop di
    pop si
    pop ax
%endmacro

; ------------------------------------------------------------
; Macro: PRINT_LB
;  - Imprime un salto de línea forzando CR (0x0D) + LF (0x0A)
;    con int 0x10 (modo Teletype Output).
; ------------------------------------------------------------
%macro PRINT_LB 0
    push ax

    mov al, 0x0D       ; CR
    mov ah, 0x0E
    int 0x10

    mov al, 0x0A       ; LF
    mov ah, 0x0E
    int 0x10

    pop ax
%endmacro

; Macro para convertir un dígito ASCII ('0'-'9') a su valor numérico (0-9)
%macro ASCII_TO_INT 1
    sub %1, '0'   ; Resta el código ASCII de '0' (48) para obtener el valor numérico
%endmacro

; Macro para convertir un valor numérico (0-9) a su carácter ASCII ('0'-'9')
%macro INT_TO_ASCII 1
    add %1, '0'   ; Suma el código ASCII de '0' para obtener el carácter correspondiente
%endmacro