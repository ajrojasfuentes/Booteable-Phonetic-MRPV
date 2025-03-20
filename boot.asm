[org 0x7C00]  ; Indicar al ensamblador que el código se cargará en la dirección 0x7C00
[bits 16]     ; Indicar al ensamblador que el código es de 16 bits

start:
    ; Configurar segmentos
    xor ax, ax          ; Poner AX en 0 para inicializar los registros de segmento
    mov ds, ax          ; Configurar el segmento de datos (DS) en 0
    mov es, ax          ; Configurar el segmento extra (ES) en 0

    ; Cargar el MBR desde el segundo sector (sector 2) del disco
    mov ah, 0x02        ; Función de lectura de disco (BIOS interrupt 13h)
    mov al, 1           ; Número de sectores a leer (1 sector)
    mov ch, 0           ; Cilindro 0 (parte alta del CHS)
    mov cl, 2           ; Sector 2 (parte baja del CHS)
    mov dh, 0           ; Cabeza 0 (parte media del CHS)
    mov dl, 0x80        ; Primera unidad de disco duro (0x80 es el primer disco duro)
    mov bx, 0x7E00      ; Dirección de carga en memoria (después del bootloader)
    int 0x13            ; Llamar a la interrupción de BIOS para leer el sector

    jmp 0x7E00          ; Saltar a la dirección de carga del MBR para continuar la ejecución

times 510-($-$$) db 0   ; Rellenar con ceros hasta alcanzar 510 bytes
dw 0xAA55               ; Firma del bootloader (2 bytes), totalizando 512 bytes
