#!/bin/bash
# Script para compilar el bootloader y el programa principal,
# crear una imagen de disco y ejecutarla en QEMU.

set -e  # Termina el script si ocurre algún error

echo "1. Compilando el bootloader..."
nasm -f bin -o boot.bin boot.asm

echo "2. Compilando el programa principal..."
nasm -f bin -o MRPV.bin MRPV.asm

echo "3. Creando una imagen limpia de disco..."
dd if=/dev/zero of=disk.img bs=512 count=4096

echo "4. Insertando el bootloader en la imagen..."
dd if=boot.bin of=disk.img bs=512 count=1

echo "5. Insertando el programa principal en la imagen..."
dd if=MRPV.bin of=disk.img bs=512 seek=1

echo "6. Ejecutando la imagen en QEMU..."
qemu-system-x86_64 -drive format=raw,file=disk.img


