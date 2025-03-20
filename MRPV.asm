[org 0x7E00]
[bits 16]
%define SCREEN 0XB800

; --------------------------------------------------------------------------
; Subrutina: main
;
; Descripción:
;   Punto de entrada del programa. Ejecuta 3 rondas en las que se calcula la
;   semilla (a partir de ticks y RTC), se generan 5 letras pseudoaleatorias, se
;   leen y evalúan 5 entradas fonéticas, y se espera 5 segundos entre rondas.
;   Al finalizar, se termina la ejecución del programa.
;
; Parámetros (Entrada):
;   - N/A.
;
; Registros modificados:
;   - Se utilizan registros generales según cada subrutina.
;
; Retorno (Salida):
;   - N/A.
;
; Ejemplo de uso:
;         ; Al iniciar el programa, se ejecuta el bucle principal.
;
; --------------------------------------------------------------------------
main:
    mov bx, 1            ; Se realizarán 3 rondas (BX = 1, 2, 3)

main_loop:
    ; ----------------------------------------------------------------------
    ; Mostrar mensaje de inicio de ronda
    ; ----------------------------------------------------------------------
    mov si, msgstart
    call print

    ; ----------------------------------------------------------------------
    ; (A) Calcular la semilla a partir de ticks y RTC
    ; ----------------------------------------------------------------------
    call SetSeedFromTime

    mov si, msg1
    call print

    ; ----------------------------------------------------------------------
    ; (B) Generar 5 letras (A..Z) y mostrarlas
    ; ----------------------------------------------------------------------
    call GenerateAndPrint

    ; ----------------------------------------------------------------------
    ; (C) Leer 5 cadenas (entradas fonéticas) y evaluarlas
    ; ----------------------------------------------------------------------
    call ProcessEntries

    ; ----------------------------------------------------------------------
    ; (E) Esperar aproximadamente 5 segundos antes de la siguiente ronda
    ; ----------------------------------------------------------------------
    call Wait5

    inc bx
    cmp bx, 4
    jne main_loop       ; Se repite mientras BX sea menor a 4

    ; ----------------------------------------------------------------------
    ; Terminar la ejecución del programa
    ; ----------------------------------------------------------------------
    call End

; --------------------------------------------------------------------------
; Subrutina: SetSeedFromTime
;
; Descripción:
;   Lee el contador de ticks desde la BIOS Data Area (offset 0x046C) y obtiene
;   la hora actual del RTC mediante INT 0x1A, función 2. Luego, combina ambos
;   valores mediante una operación XOR y almacena el resultado en la variable
;   global 'seed'. Este valor combinado puede utilizarse posteriormente como
;   semilla para generadores pseudoaleatorios.
;
; Parámetros (Entrada):
;   - N/A.
;
; Registros modificados:
;   - DS, AX, BX, DX.
;   - DS, BX y DX: Se guardan y restauran durante la ejecución.
;
; Retorno (Salida):
;   - N/A. La variable global 'seed' se actualiza con el valor resultante:
;         seed = (ticks XOR RTC)
;
; Ejemplo de uso:
;         call SetSeedFromTime
;         ; La variable 'seed' contendrá el valor combinado de ticks y RTC.
;
; --------------------------------------------------------------------------
SetSeedFromTime:
    push ds              ; Preserva DS para no alterar el segmento de datos del llamador
    push ax              ; Preserva AX
    push bx              ; Preserva BX
    push dx              ; Preserva DX

    ; Configurar DS para acceder a la BIOS Data Area.
    ; Se asume que DS=0 permite leer la BIOS Data Area. En algunos entornos
    ; puede ser necesario usar: mov ax, 0x40  / mov ds, ax
    xor ax, ax
    mov ds, ax

    ; ----------------------------------------------------------------------
    ; 1) Leer el contador de ticks:
    ;     Se obtiene el valor en [0x046C] de la BIOS Data Area y se guarda en BX.
    ; ----------------------------------------------------------------------
    mov ax, [0x046C]     ; Carga el contador de ticks en AX
    mov bx, ax           ; Copia el valor de ticks en BX

    ; ----------------------------------------------------------------------
    ; 2) Leer la hora actual del RTC:
    ;     Se invoca INT 0x1A, función 2, que retorna en DH (segundos) y DL
    ;     (fracciones de segundo). El resultado combinado se obtiene en DX.
    ; ----------------------------------------------------------------------
    mov ah, 2
    int 0x1A             ; RTC: retorna en DH:DL (valor en DX)

    ; ----------------------------------------------------------------------
    ; 3) Combinar los valores:
    ;     Se mueve el valor obtenido del RTC (DX) a AX y se realiza XOR con
    ;     el contador de ticks (almacenado en BX). El resultado se almacena en
    ;     la variable global 'seed'.
    ; ----------------------------------------------------------------------
    mov ax, dx           ; AX = valor obtenido del RTC
    xor ax, bx           ; AX = (RTC XOR ticks)
    mov [seed], ax       ; Actualiza la semilla global

    pop dx               ; Restaura DX
    pop bx               ; Restaura BX
    pop ax               ; Restaura AX
    pop ds               ; Restaura DS
    ret                  ; Retorna al llamador

; --------------------------------------------------------------------------
; Subrutina: GenerateAndPrint
;
; Descripción:
;   Genera 5 letras pseudoaleatorias en el rango ['A'..'Z'] mediante la subrutina
;   LCG_RAND16. Las letras generadas se almacenan en el buffer global 'buffer' y se
;   imprimen en pantalla, seguidas de un salto de línea.
;
; Parámetros (Entrada):
;   - N/A.
;
; Registros modificados:
;   - AX, BX, CX, SI.
;   - Se preservan y restauran los registros críticos.
;
; Retorno (Salida):
;   - 'buffer' contendrá la cadena de 5 letras generadas (terminada en 0).
;
; Ejemplo de uso:
;         call GenerateAndPrint
;         ; Se mostrará la cadena de letras en pantalla.
;
; --------------------------------------------------------------------------
GenerateAndPrint:
    push ax
    push bx
    push cx
    push si

    mov cx, 5
    xor bx, bx
.gen_letter:
    call LCG_RAND16       ; AX = número pseudoaleatorio [0..25]
    add al, 'A'           ; Convertir a letra (A..Z)
    mov [buffer+bx], al   ; Almacenar en 'buffer'
    inc bx
    loop .gen_letter

    mov byte [buffer+bx], 0   ; Terminador nulo

    mov si, buffer
    call print            ; Imprimir la cadena de letras

    mov si, ln
    call print            ; Imprimir salto de línea

    pop si
    pop cx
    pop bx
    pop ax
    ret

; --------------------------------------------------------------------------
; Subrutina: ProcessEntries
;
; Descripción:
;   Pide al usuario que ingrese 5 cadenas de texto (entradas fonéticas) y, tan
;   pronto que se recibe cada entrada, la compara con la palabra esperada obtenida
;   a partir de la letra generada en 'buffer' y la tabla fonética 'phonTable'. Si la
;   entrada es correcta se muestra "OK" y se incrementa un contador; si es incorrecta,
;   se muestra "NO". Al finalizar las 5 entradas, se imprime en pantalla un contador
;   que indica el puntaje total (cantidad de aciertos).
;
; Parámetros (Entrada):
;   - N/A.
;
; Registros modificados:
;   - AX, BX, CX, DX, SI, DI.
;   - Se guardan y restauran los registros críticos.
;
; Retorno (Salida):
;   - N/A. Se imprime en pantalla el puntaje total de aciertos.
;
; Ejemplo de uso:
;         call ProcessEntries
;         ; Se pedirá al usuario 5 entradas y se mostrará el puntaje total.
;
; --------------------------------------------------------------------------
ProcessEntries:
    push ax
    push bx
    push cx
    push dx
    push si
    push di

    xor bx, bx        ; BX = 0, índice de entrada (0 a 4)
    xor dx, dx        ; DX = 0, contador de aciertos

.process_loop:
    ; 1) Mostrar mensaje de solicitud de entrada
    mov si, msgentry
    call print

    ; 2) Leer una entrada y almacenarla en el buffer global 'entry'
    call read

    ; 3) Obtener la palabra esperada:
    ;    - Extraer la letra generada correspondiente a la entrada actual

    ;mov si, buffer
    ;call print
    xor ax, ax
    mov al, [buffer + bx]    ; Obtener la letra del buffer
    ;mov si, al
    ;call print
    sub al, 'A'              ; Convertir a índice (0..25)
    mov ah, 0
    shl ax, 1                ; Multiplicar el índice por 2 (cada puntero ocupa 2 bytes)

    ; Ahora AX es el offset en la tabla.

    push bx                ; Preserva el índice original
    mov bx, ax             ; BX = offset en phonTable
    mov si, phonTable      ; SI apunta al inicio de la tabla fonética
    add si, bx             ; SI = dirección del puntero de la palabra esperada
    mov ax, [si]           ; Cargar el puntero (la dirección de la cadena)
    mov si, ax             ; SI ahora apunta a la palabra fonética esperada
    pop bx                 ; Recupera el índice original

    ;call print             ; Se imprime la palabra para verificar (debugeando)

    ; 4) Comparar la entrada del usuario con la palabra esperada:
    mov di, entry         ; DI = dirección del buffer 'entry'
    call CMP_STR          ; Compara SI (esperada) y DI (entrada); resultado en AL

    cmp al, 1
    je .print_ok
    mov si, msgNo
    call print
    jmp .print_next
.print_ok:
    mov si, msgOk
    call print
    inc dx                ; Incrementa el contador de aciertos
.print_next:
    mov si, ln
    call print

    inc bx                ; Siguiente entrada
    cmp bx, 5
    jl .process_loop

    ; 5) Imprimir el puntaje total
    mov si, msgScore
    call print
    mov al, dl            ; DL contiene el puntaje total (0..5)
    add al, '0'           ; Convertir a carácter ASCII
    mov ah, 0x0E
    int 0x10              ; Imprimir el dígito
    mov si, ln
    call print

    pop di
    pop si
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; --------------------------------------------------------------------------
; Subrutina: Wait5
;
; Descripción:
;   Espera aproximadamente 5 segundos utilizando el contador de ticks de la BIOS
;   (offset 0x046C). Se suman alrededor de 91 ticks, asumiendo una tasa de 18.2
;   ticks por segundo.
;
; Parámetros (Entrada):
;   - N/A.
;
; Registros modificados:
;   - DS, AX, BX.
;   - DS y BX se preservan y restauran.
;
; Retorno (Salida):
;   - N/A.
;
; Ejemplo de uso:
;         call Wait5
;         ; Se espera ~5 segundos antes de continuar.
;
; --------------------------------------------------------------------------
Wait5:
    push ds
    push ax
    push bx

    xor ax, ax
    mov ds, ax

    mov bx, [0x046C]
    add bx, 91         ; Aproximadamente 5 segundos (91 ticks)

.wait_loop:
    mov ax, [0x046C]
    cmp ax, bx
    jb .wait_loop

    pop bx
    pop ax
    pop ds
    ret

; --------------------------------------------------------------------------
; Subrutina: End
;
; Descripción:
;   Finaliza la ejecución del programa. En entornos sin sistema operativo,
;   se reinicia el sistema utilizando INT 19h (Bootstrap).
;
; Parámetros (Entrada):
;   - N/A.
;
; Registros modificados:
;   - N/A.
;
; Retorno (Salida):
;   - N/A.
;
; Ejemplo de uso:
;         call End
;         ; El sistema se reinicia o el programa se detiene.
;
; --------------------------------------------------------------------------
End:
    EXIT

; --------------------------------------------------------------------------
;                          Subrutinas Auxiliares
; --------------------------------------------------------------------------

; --------------------------------------------------------------------------
; Subrutina: print
;
; Descripción:
;   Imprime en pantalla una cadena de caracteres ubicada en la dirección
;   apuntada por SI. La cadena debe estar terminada en 0 (byte nulo). Se
;   utiliza la interrupción 0x10, función 0x0E (teletipo) para mostrar cada
;   carácter en modo texto.
;
; Parámetros (Entrada):
;   - SI: Dirección de la cadena a imprimir (cadena terminada en 0).
;
; Registros modificados:
;   - AX y SI.
;   - Ambos se preservan y restauran durante la ejecución.
;
; Retorno (Salida):
;   - N/A. La cadena se imprime directamente en la pantalla.
;
; Ejemplo de uso:
;         mov si, cadena
;         call print
;
; --------------------------------------------------------------------------
print:
    push ax               ; Preserva AX
    push si               ; Preserva SI (puntero a la cadena)
.printloop:
    lodsb                 ; Carga el byte apuntado por SI en AL y avanza SI
    test al, al           ; Comprueba si AL es 0 (fin de cadena)
    jz .printend         ; Si AL es 0, termina la impresión
    mov ah, 0x0E         ; Función teletipo de la INT 0x10 para imprimir un carácter
    int 0x10             ; Imprime el carácter en AL
    jmp .printloop       ; Repite el ciclo para el siguiente carácter
.printend:
    pop si               ; Restaura SI original
    pop ax               ; Restaura AX
    ret                  ; Retorna al llamador

; --------------------------------------------------------------------------
; Subrutina: read
;
; Descripción:
;   Lee una cadena de caracteres desde el teclado y la almacena en el buffer
;   global 'entry'. Antes de comenzar la lectura, el buffer se limpia completamente
;   llenándolo con 0s, asegurando que no queden datos residuales. La entrada se
;   captura carácter a carácter mediante INT 16h, y se muestra en pantalla cada
;   carácter con INT 10h (modo teletipo). La lectura se finaliza al presionar la tecla
;   Enter (0Dh) o al alcanzar el límite máximo de 39 caracteres (dejando un byte
;   para el terminador nulo), garantizando que el buffer de 40 bytes se actualice con
;   una cadena terminada en 0.
;
; Parámetros (Entrada):
;   - N/A.
;
; Registros modificados:
;   - AX, BX, CX, DX, DI.
;   - Se preservan y restauran los registros críticos.
;
; Retorno (Salida):
;   - El buffer global 'entry' se actualiza con la cadena leída, terminada en 0.
;
; Ejemplo de uso:
;         call read
;         ; La cadena ingresada se almacena en 'entry'.
;
; --------------------------------------------------------------------------
read:
    push ax              ; Preserva AX
    push bx              ; Preserva BX
    push cx              ; Preserva CX
    push dx              ; Preserva DX
    push di              ; Preserva DI

    ; ----------------------------------------------------------------------
    ; 1) Limpiar el buffer 'entry' (40 bytes) con 0s
    ; ----------------------------------------------------------------------
    mov di, entry        ; DI apunta al inicio del buffer
    mov cx, 40           ; Número total de bytes a limpiar
    xor ax, ax           ; AX = 0, valor para limpiar
.clear_loop:
    mov byte [di], al    ; Escribe 0 en la posición actual del buffer
    inc di               ; Avanza al siguiente byte
    loop .clear_loop     ; Repite hasta limpiar 40 bytes

    ; Reinicia DI al inicio del buffer 'entry' para almacenar la entrada
    mov di, entry

    ; ----------------------------------------------------------------------
    ; 2) Configurar el máximo de caracteres a almacenar (40 - 1 = 39)
    ; ----------------------------------------------------------------------
    mov cx, 40
    dec cx               ; CX = 39, máximo de caracteres capturables
    xor bx, bx           ; Inicializa BX como contador de caracteres almacenados

.read_loop:
    ; ----------------------------------------------------------------------
    ; 3) Leer un carácter del teclado (INT 16h, función 0)
    ; ----------------------------------------------------------------------
    mov ah, 0
    int 16h              ; AL contiene el código ASCII del carácter leído

    ; ----------------------------------------------------------------------
    ; 4) Comprobar si se presionó Enter (fin de cadena)
    ; ----------------------------------------------------------------------
    cmp al, 0Dh
    je .finish

    ; ----------------------------------------------------------------------
    ; 5) Procesar Backspace (08h) para permitir edición
    ; ----------------------------------------------------------------------
    cmp al, 08h
    je .backspace

    ; ----------------------------------------------------------------------
    ; 6) Si se alcanzó el máximo de caracteres, ignorar el carácter
    ; ----------------------------------------------------------------------
    cmp bx, cx
    jae .read_loop

    ; ----------------------------------------------------------------------
    ; 7) Mostrar el carácter en pantalla (eco) y almacenarlo en el buffer
    ; ----------------------------------------------------------------------
    mov ah, 0Eh
    int 10h              ; Muestra el carácter en AL

    mov [di], al        ; Guarda el carácter en el buffer
    inc di              ; Avanza en el buffer
    inc bx              ; Incrementa el contador de caracteres
    jmp .read_loop

.backspace:
    ; ----------------------------------------------------------------------
    ; 8) Procesar retroceso (Backspace) si hay caracteres almacenados
    ; ----------------------------------------------------------------------
    cmp bx, 0
    je .read_loop       ; Si no hay caracteres, ignorar el Backspace

    ; Borra el carácter en pantalla: retroceso, espacio, retroceso
    mov ah, 0Eh
    mov al, 08h         ; Retroceso
    int 10h
    mov al, ' '         ; Espacio para borrar el carácter visualmente
    int 10h
    mov al, 08h         ; Retroceso nuevamente
    int 10h

    dec di              ; Retrocede en el buffer
    dec bx              ; Decrementa el contador de caracteres
    jmp .read_loop

.finish:
    ; ----------------------------------------------------------------------
    ; 9) Finalizar la cadena:
    ;     - Imprime CR y LF para pasar a la siguiente línea (opcional)
    ;     - Coloca un terminador nulo (0) en el buffer.
    ; ----------------------------------------------------------------------
    mov ah, 0Eh
    mov al, 0Dh         ; Carácter CR
    int 10h
    mov al, 0Ah         ; Carácter LF
    int 10h

    mov byte [di], 0    ; Terminador nulo en el buffer

    ; Restaura los registros usados
    pop di
    pop dx
    pop cx
    pop bx
    pop ax
    ret

; --------------------------------------------------------------------------
; Subrutina: LCG_RAND16
;
; Descripción:
;   Genera un valor pseudoaleatorio de 16 bits utilizando un Generador Lineal
;   Congruencial (LCG) a partir de la semilla global 'seed'. El nuevo valor de
;   la semilla se calcula como:
;
;   seed = (seed * 25173 + 13849) mod 65536
;
;   Luego, se filtra este valor al rango [0..25] (por ejemplo, para luego sumarle
;   'A' y obtener una letra mayúscula).
;
; Parámetros (Entrada):
;   - N/A.
;
; Registros modificados:
;   - AX, BX, DX
;   - BX y DX: Se guardan y restauran durante la ejecución.
;
; Retorno (Salida):
;   - AX = valor pseudoaleatorio en el rango [0..25].
;
; Ejemplo de uso:
;         call LCG_RAND16
;         ; Ahora AX contendrá un número entre 0 y 25.
;
; --------------------------------------------------------------------------
LCG_RAND16:
    push bx              ; Preserva BX, usado para el divisor
    push dx              ; Preserva DX, usado en la multiplicación y división

    ; --------------------------------------------------------
    ; 1) Calcular la nueva semilla:
    ;       seed = (seed * 25173 + 13849) mod 65536
    ; --------------------------------------------------------
    mov ax, [seed]       ; Carga la semilla actual en AX
    mov dx, 25173        ; Constante multiplicativa: 25173
    mul dx               ; Multiplica AX por DX; resultado de 32 bits en DX:AX
    add ax, 13849        ; Suma la constante aditiva: 13849
    adc dx, 0            ; Ajusta DX en caso de acarreo
    mov [seed], ax       ; Actualiza la semilla con la parte baja (16 bits) del resultado

    ; --------------------------------------------------------
    ; 2) Filtrar el valor al rango [0..25]:
    ;       valor = seed mod 26
    ; --------------------------------------------------------
    xor dx, dx           ; Limpia DX para preparar la división (se usa DX:AX)
    mov bx, 26           ; Establece el divisor (26)
    div bx               ; Divide DX:AX entre 26
                         ;   - Cociente en AX (no se usa)
                         ;   - Resto en DX, que es el valor en [0..25]
    mov ax, dx           ; Copia el resto a AX, que será el valor de retorno

    pop dx               ; Restaura DX
    pop bx               ; Restaura BX
    ret                  ; Retorna, dejando en AX el valor pseudoaleatorio [0..25]

; --------------------------------------------------------------------------
; Subrutina: CMP_STR
;
; Descripción:
;   Compara dos cadenas de caracteres terminadas en 0, byte a byte.
;
; Parámetros (Entrada):
;   - SI: Dirección de la primera cadena.
;   - DI: Dirección de la segunda cadena.
;
; Registros modificados:
;   - AX, SI, DI.
;
; Retorno (Salida):
;   - AL = 1 si las cadenas son iguales.
;   - AL = 0 si difieren.
;
; Ejemplo de uso:
;         mov si, cadena1
;         mov di, cadena2
;         call CMP_STR
;         cmp al, 1
;         je iguales
;         jne diferentes
;
; --------------------------------------------------------------------------
CMP_STR:
    push si
    push di
    push ax
.CMP_LOOP:
    mov al, [si]
    cmp al, [di]
    jne .not_equal
    cmp al, 0
    je .equal
    inc si
    inc di
    jmp .CMP_LOOP
.not_equal:
    xor al, al         ; AL = 0 (cadenas diferentes)
    jmp .done
.equal:
    mov al, 1          ; AL = 1 (cadenas iguales)
.done:
    pop ax
    pop di
    pop si
    ret

; --------------------------------------------------------------------------
;                          VARIABLES
; --------------------------------------------------------------------------
seed        dw 0
msgstart    db "Ejecutando MRPV...", 0x0D, 0x0A, 0
ln          db 0x0D, 0x0A, 0
msgentry    db "Digite el Fonetico: ", 0
msg1        db "Semilla Generada...", 0x0D, 0x0A, 0
msg2        db "Letras Generadas...", 0x0D, 0x0A, 0
msgCG       db "CGL...", 0x0D, 0x0A, 0
msg3        db "Entradas tomadas...", 0x0D, 0x0A, 0
msgOk       db "OK", 0x0D, 0x0A, 0
msgNo       db "NO", 0x0D, 0x0A, 0
msgScore    db "Puntaje: ", 0

buffer      times 6 db 0           ; 5 letras + terminador
entry       times 40 db 0          ; Buffer para entrada de 40 bytes (cadena terminada en 0)
input       resb 8

; -------------------- TABLA FONETICA --------------------
phonTable:
    dw pAlfa, pBravo, pCharlie, pDelta, pEcho, pFoxtrot, pGolf, pHotel
    dw pIndia, pJuliet, pKilo, pLima, pMike, pNovember, pOscar, pPapa
    dw pQuebec, pRomeo, pSierra, pTango, pUniform, pVictor, pWhiskey
    dw pXray, pYankee, pZulu

pAlfa     db "Alfa",0
pBravo    db "Bravo",0
pCharlie  db "Charlie",0
pDelta    db "Delta",0
pEcho     db "Echo",0
pFoxtrot  db "Foxtrot",0
pGolf     db "Golf",0
pHotel    db "Hotel",0
pIndia    db "India",0
pJuliet   db "Juliet",0
pKilo     db "Kilo",0
pLima     db "Lima",0
pMike     db "Mike",0
pNovember db "November",0
pOscar    db "Oscar",0
pPapa     db "Papa",0
pQuebec   db "Quebec",0
pRomeo    db "Romeo",0
pSierra   db "Sierra",0
pTango    db "Tango",0
pUniform  db "Uniform",0
pVictor   db "Victor",0
pWhiskey  db "Whiskey",0
pXray     db "X-ray",0
pYankee   db "Yankee",0
pZulu     db "Zulu",0
