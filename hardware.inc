; Ki Warden - Game Boy / Game Boy Color hardware registers

DEF rP1     EQU $FF00 ; Joypad input
DEF rLCDC   EQU $FF40 ; LCD control
DEF rSTAT   EQU $FF41 ; LCD status
DEF rSCY    EQU $FF42 ; Scroll Y
DEF rSCX    EQU $FF43 ; Scroll X
DEF rLY     EQU $FF44 ; Current scanline
DEF rBGP    EQU $FF47 ; DMG background palette
DEF rOBP0   EQU $FF48 ; DMG object palette 0
DEF rOBP1   EQU $FF49 ; DMG object palette 1
DEF rWY     EQU $FF4A ; Window Y
DEF rWX     EQU $FF4B ; Window X

; Game Boy Color palette registers
DEF rBCPS   EQU $FF68 ; BG colour palette index
DEF rBCPD   EQU $FF69 ; BG colour palette data
DEF rOCPS   EQU $FF6A ; OBJ colour palette index
DEF rOCPD   EQU $FF6B ; OBJ colour palette data

DEF rIE     EQU $FFFF ; Interrupt enable

; Memory areas
DEF _VRAM   EQU $8000
DEF _OAMRAM EQU $FE00

; Game states
DEF STATE_TITLE    EQU 0
DEF STATE_PLAYING  EQU 1
DEF STATE_GAMEOVER EQU 2

; Directions
DEF DIR_RIGHT EQU 0
DEF DIR_LEFT  EQU 1
DEF DIR_UP    EQU 2
DEF DIR_DOWN  EQU 3

DEF _SCRN0 EQU $9800

; HUD tile IDs
DEF TILE_H       EQU 6
DEF TILE_D       EQU 7
DEF TILE_S       EQU 8
DEF TILE_W       EQU 9
DEF TILE_DIGIT_0 EQU 10