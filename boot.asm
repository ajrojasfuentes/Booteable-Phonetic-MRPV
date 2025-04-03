[org 0x7C00]  ; Código se cargará en la dirección 0x7C00
[bits 16]     ; Modo de 16 bits

start:
    ; Configurar segmentos
    xor ax, ax          ; Poner AX en 0 para inicializar los registros de segmento
    mov ds, ax          ; Configurar el segmento de datos (DS) en 0
    mov es, ax          ; Configurar el segmento extra (ES) en 0

    ; Cargar MRPV desde el segundo segmento 2
    mov ah, 0x02        ; Función de lectura de disco (BIOS interrupt 13h)
    mov al, 1           ; Número de segmentos a leer
    mov ch, 0
    mov cl, 2           ; Segmento 2
    mov dh, 0
    mov dl, 0x80        ; Primera unidad de disco duro (0x80 es el primer disco duro)
    mov bx, 0x7E00      ; Dirección de carga en memoria - dirección del MRPV.asm
    int 0x13            ; Llamar a la interrupción de BIOS para leer el sector

    jmp 0x7E00          ; Saltar a la dirección de carga del MBR para continuar

times 510-($-$$) db 0   ; Rellenar con ceros hasta alcanzar 510 bytes
dw 0xAA55               ; Firma del bootloader en los 2 bytes restantes
