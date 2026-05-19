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

; Title/text tile IDs
DEF TILE_K EQU 21
DEF TILE_I EQU 22
DEF TILE_A EQU 23
DEF TILE_R EQU 24
DEF TILE_E EQU 25
DEF TILE_N EQU 26
DEF TILE_P EQU 27
DEF TILE_T EQU 28
DEF TILE_G EQU 29
DEF TILE_M EQU 30
DEF TILE_O EQU 31
DEF TILE_V EQU 32
DEF TILE_C EQU 33

; Game Boy sound registers
DEF rNR10 EQU $FF10 ; Channel 1 sweep
DEF rNR11 EQU $FF11 ; Channel 1 duty/length
DEF rNR12 EQU $FF12 ; Channel 1 volume envelope
DEF rNR13 EQU $FF13 ; Channel 1 frequency low
DEF rNR14 EQU $FF14 ; Channel 1 frequency high/control

DEF rNR21 EQU $FF16 ; Channel 2 duty/length
DEF rNR22 EQU $FF17 ; Channel 2 volume envelope
DEF rNR23 EQU $FF18 ; Channel 2 frequency low
DEF rNR24 EQU $FF19 ; Channel 2 frequency high/control

DEF rNR41 EQU $FF20 ; Channel 4 length
DEF rNR42 EQU $FF21 ; Channel 4 volume envelope
DEF rNR43 EQU $FF22 ; Channel 4 noise frequency
DEF rNR44 EQU $FF23 ; Channel 4 control

DEF rNR50 EQU $FF24 ; Master volume
DEF rNR51 EQU $FF25 ; Sound output routing
DEF rNR52 EQU $FF26 ; Sound on/off