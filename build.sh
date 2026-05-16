#!/bin/sh

rgbasm -o main.o main.asm
if [ $? -ne 0 ]; then
    echo "rgbasm failed"
    exit 1
fi

rgblink -o KiWarden.gbc main.o
if [ $? -ne 0 ]; then
    echo "rgblink failed"
    exit 1
fi

rgbfix -v -C -p 0 KiWarden.gbc
if [ $? -ne 0 ]; then
    echo "rgbfix failed"
    exit 1
fi

echo "Built KiWarden.gbc successfully"