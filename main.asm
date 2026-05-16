INCLUDE "hardware.inc"

DEF MAX_ENEMIES EQU 4

DEF KI_WAVE_COOLDOWN EQU 180

SECTION "Header", ROM0[$100]
    jp EntryPoint
    ds $150 - @, 0

SECTION "WRAM Variables", WRAM0

wGameState:       db

wJoyDir:          db
wJoyButtons:      db

wPlayerX:         db
wPlayerY:         db
wPlayerDir:       db
wPlayerHealth:    db
wPlayerInvuln:    db
wPlayerMoveTimer: db

wKiWaveCharges:   db
wKiWaveTimer:     db
wKiWaveCooldown:  db

wProjectileX:     db
wProjectileY:     db
wProjectileDir:   db
wProjectileActive: db

; Four enemy slots. This replaces the old single-enemy setup.
wEnemy0X:         db
wEnemy0Y:         db
wEnemy0Active:    db
wEnemy0MoveTimer: db
wEnemy0Type:      db
wEnemy0DX:        db
wEnemy0DY:        db

wEnemy1X:         db
wEnemy1Y:         db
wEnemy1Active:    db
wEnemy1MoveTimer: db
wEnemy1Type:      db
wEnemy1DX:        db
wEnemy1DY:        db

wEnemy2X:         db
wEnemy2Y:         db
wEnemy2Active:    db
wEnemy2MoveTimer: db
wEnemy2Type:      db
wEnemy2DX:        db
wEnemy2DY:        db

wEnemy3X:         db
wEnemy3Y:         db
wEnemy3Active:    db
wEnemy3MoveTimer: db
wEnemy3Type:      db
wEnemy3DX:        db
wEnemy3DY:        db

wDay:             db
wSpiritsLeft:     db
wScoreLo:         db
wScoreHi:         db
wRNG:             db
wHUDDirty:        db

SECTION "Main Code", ROM0

EntryPoint:
    di
    ld sp, $FFFE

    call WaitVBlank

    xor a
    ldh [rLCDC], a

    xor a
    ldh [rSCX], a
    ldh [rSCY], a

    ld a, %11100100
    ldh [rBGP], a
    ldh [rOBP0], a
    ldh [rOBP1], a

    call LoadCGBPalettes
    call LoadSpriteTiles
    call ClearBackgroundMap
    call ClearOAM
    call InitTitle

    ; LCD on, tile data at $8000, sprites on, BG on.
    ld a, %10010011
    ldh [rLCDC], a

MainLoop:
    call WaitVBlank
    call ReadJoypad
    call UpdateRNG
    call UpdateGame
    call UpdateHUDIfDirty
    call DrawSprites
    jr MainLoop

; ------------------------------------------------------------
; Game state logic
; ------------------------------------------------------------

UpdateGame:
    ld a, [wGameState]

    cp STATE_TITLE
    jr z, UpdateTitle

    cp STATE_PLAYING
    jr z, UpdatePlaying

    cp STATE_GAMEOVER
    jr z, UpdateGameOver

    ret

UpdateTitle:
    ; Press Start to begin.
    ld a, [wJoyButtons]
    bit 3, a
    ret z

    call InitGame
    ret

UpdateGameOver:
    ; Press Start to restart.
    ld a, [wJoyButtons]
    bit 3, a
    ret z

    call InitGame
    ret

UpdatePlaying:
    call UpdatePlayerInvuln
    call UpdatePlayer
    call UpdateKiWave
    call UpdateProjectile
    call UpdateEnemies
    call CheckProjectileEnemyCollisions
    call CheckKiWaveEnemyCollisions
    call CheckEnemyPlayerCollisions
    call CheckWaveClear
    ret

; ------------------------------------------------------------
; Initialisation
; ------------------------------------------------------------

InitTitle:
    ld a, STATE_TITLE
    ld [wGameState], a

    ld a, 80
    ld [wPlayerX], a

    ld a, 120
    ld [wPlayerY], a

    ld a, 5
    ld [wPlayerHealth], a

    ld a, 1
    ld [wDay], a
    ld [wKiWaveCharges], a

    xor a
    ld [wProjectileActive], a
    ld [wScoreLo], a
    ld [wScoreHi], a
    ld [wKiWaveTimer], a
    ld [wKiWaveCooldown], a
    call ClearEnemies
    call MarkHUDDirty

    ret

InitGame:
    ld a, STATE_PLAYING
    ld [wGameState], a

    ld a, 80
    ld [wPlayerX], a

    ld a, 120
    ld [wPlayerY], a

    ld a, DIR_UP
    ld [wPlayerDir], a

    ld a, 5
    ld [wPlayerHealth], a

    xor a
    ld [wPlayerInvuln], a
    ld [wPlayerMoveTimer], a
    ld [wProjectileActive], a
    ld [wScoreLo], a
    ld [wScoreHi], a
    ld [wKiWaveTimer], a
    ld [wKiWaveCooldown], a

    call ClearEnemies

    ld a, 1
    ld [wKiWaveCharges], a
    ld [wDay], a

    ld a, 91
    ld [wRNG], a

    call GetSpiritsForCurrentDay
    ld [wSpiritsLeft], a

    call SpawnToCap
    call MarkHUDDirty
    ret

ClearEnemies:
    xor a
    ld [wEnemy0Active], a
    ld [wEnemy1Active], a
    ld [wEnemy2Active], a
    ld [wEnemy3Active], a
    ld [wEnemy0MoveTimer], a
    ld [wEnemy1MoveTimer], a
    ld [wEnemy2MoveTimer], a
    ld [wEnemy3MoveTimer], a
    ld [wEnemy0Type], a
    ld [wEnemy1Type], a
    ld [wEnemy2Type], a
    ld [wEnemy3Type], a
    ld [wEnemy0DX], a
    ld [wEnemy1DX], a
    ld [wEnemy2DX], a
    ld [wEnemy3DX], a
    ld [wEnemy0DY], a
    ld [wEnemy1DY], a
    ld [wEnemy2DY], a
    ld [wEnemy3DY], a
    ret

; ------------------------------------------------------------
; Joypad
; ------------------------------------------------------------

ReadJoypad:
    ; Direction bits after inversion: bit 0 = Right, 1 = Left, 2 = Up, 3 = Down.
    ld a, $20
    ldh [rP1], a
    ldh a, [rP1]
    ldh a, [rP1]
    cpl
    and $0F
    ld [wJoyDir], a

    ; Action bits after inversion: bit 0 = A, 1 = B, 2 = Select, 3 = Start.
    ld a, $10
    ldh [rP1], a
    ldh a, [rP1]
    ldh a, [rP1]
    cpl
    and $0F
    ld [wJoyButtons], a

    ret

; ------------------------------------------------------------
; Player
; ------------------------------------------------------------

UpdatePlayerInvuln:
    ld a, [wPlayerInvuln]
    and a
    ret z

    dec a
    ld [wPlayerInvuln], a
    ret

UpdatePlayer:
    ; A fires a ki blast if one is not already active.
    ld a, [wJoyButtons]
    bit 0, a
    jr z, .movementTimer

    ld a, [wProjectileActive]
    and a
    jr nz, .movementTimer

    call FireProjectile

.movementTimer:
    ; Only move the player every 3 frames.
    ld a, [wPlayerMoveTimer]
    inc a
    ld [wPlayerMoveTimer], a

    cp 2
    ret c

    xor a
    ld [wPlayerMoveTimer], a

    ld a, [wJoyDir]

    ; Right
    bit 0, a
    jr z, .checkLeft

    ld a, DIR_RIGHT
    ld [wPlayerDir], a

    ld a, [wPlayerX]
    cp 152
    ret nc
    inc a
    ld [wPlayerX], a
    ret

.checkLeft:
    ld a, [wJoyDir]
    bit 1, a
    jr z, .checkUp

    ld a, DIR_LEFT
    ld [wPlayerDir], a

    ld a, [wPlayerX]
    cp 16
    ret c
    dec a
    ld [wPlayerX], a
    ret

.checkUp:
    ld a, [wJoyDir]
    bit 2, a
    jr z, .checkDown

    ld a, DIR_UP
    ld [wPlayerDir], a

    ; Keep player below the portal lane and HUD area.
    ld a, [wPlayerY]
    cp 64
    ret c
    dec a
    ld [wPlayerY], a
    ret

.checkDown:
    ld a, [wJoyDir]
    bit 3, a
    ret z

    ld a, DIR_DOWN
    ld [wPlayerDir], a

    ld a, [wPlayerY]
    cp 144
    ret nc
    inc a
    ld [wPlayerY], a
    ret

FireProjectile:
    ld a, 1
    ld [wProjectileActive], a

    ld a, [wPlayerX]
    ld [wProjectileX], a

    ld a, [wPlayerY]
    ld [wProjectileY], a

    ld a, [wPlayerDir]
    ld [wProjectileDir], a

    ret

; ------------------------------------------------------------
; Ki Wave
; ------------------------------------------------------------

UpdateKiWave:
    ; Count down the visible Ki Wave burst.
    ld a, [wKiWaveTimer]
    and a
    jr z, .updateCooldown

    dec a
    ld [wKiWaveTimer], a

.updateCooldown:
    ; If Ki Wave is already ready, no cooldown is needed.
    ld a, [wKiWaveCharges]
    and a
    jr nz, .checkInput

    ; If not ready, count cooldown down.
    ld a, [wKiWaveCooldown]
    and a
    jr z, .restoreCharge

    dec a
    ld [wKiWaveCooldown], a

    ; If cooldown just reached zero, restore charge.
    and a
    jr nz, .checkInput

.restoreCharge:
    ld a, 1
    ld [wKiWaveCharges], a
    call MarkHUDDirty

.checkInput:
    ; B triggers Ki Wave, but only if ready.
    ld a, [wJoyButtons]
    bit 1, a
    ret z

    ld a, [wKiWaveCharges]
    and a
    ret z

    ; Spend the charge.
    xor a
    ld [wKiWaveCharges], a
    call MarkHUDDirty

    ; Start cooldown.
    ld a, KI_WAVE_COOLDOWN
    ld [wKiWaveCooldown], a

    ; Start visual burst timer.
    ld a, 12
    ld [wKiWaveTimer], a

    ret

; ------------------------------------------------------------
; Projectile
; ------------------------------------------------------------

UpdateProjectile:
    ld a, [wProjectileActive]
    and a
    ret z

    ld a, [wProjectileDir]

    cp DIR_RIGHT
    jr z, .moveRight

    cp DIR_LEFT
    jr z, .moveLeft

    cp DIR_UP
    jr z, .moveUp

    cp DIR_DOWN
    jr z, .moveDown

    ret

.moveRight:
    ld a, [wProjectileX]
    add 2
    ld [wProjectileX], a
    cp 160
    jr c, .done
    jr .deactivate

.moveLeft:
    ld a, [wProjectileX]
    sub 2
    ld [wProjectileX], a
    cp 8
    jr nc, .done
    jr .deactivate

.moveUp:
    ld a, [wProjectileY]
    sub 2
    ld [wProjectileY], a
    cp 16
    jr nc, .done
    jr .deactivate

.moveDown:
    ld a, [wProjectileY]
    add 2
    ld [wProjectileY], a
    cp 152
    jr c, .done

.deactivate:
    xor a
    ld [wProjectileActive], a

.done:
    ret

; ------------------------------------------------------------
; Difficulty, spawning, and enemies
; ------------------------------------------------------------

GetSpiritsForCurrentDay:
    ; Returns total spirits to defeat for the current day in A.
    ld a, [wDay]
    dec a

    cp 10
    jr c, .inRange

    ld a, 9

.inRange:
    ld e, a
    ld d, 0
    ld hl, SpiritsPerDayTable
    add hl, de
    ld a, [hl]
    ret

GetActiveEnemyCap:
    ; Day 1 = 1 active enemy, Day 2 = 2, Day 3 = 3, Day 4+ = 4.
    ld a, [wDay]
    cp 4
    jr c, .useDay

    ld a, 4
    ret

.useDay:
    and a
    ret nz

    ld a, 1
    ret

CountActiveEnemies:
    ld b, 0

    ld a, [wEnemy0Active]
    and a
    jr z, .check1
    inc b
.check1:
    ld a, [wEnemy1Active]
    and a
    jr z, .check2
    inc b
.check2:
    ld a, [wEnemy2Active]
    and a
    jr z, .check3
    inc b
.check3:
    ld a, [wEnemy3Active]
    and a
    jr z, .done
    inc b
.done:
    ld a, b
    ret

GetDesiredActiveEnemies:
    ; Desired active enemies = min(active cap, spirits still left).
    call GetActiveEnemyCap
    ld b, a

    ld a, [wSpiritsLeft]
    cp b
    jr c, .spiritsLower

    ld a, b
.spiritsLower:
    ret

SpawnToCap:
    ; Keep spawning until active enemies reach the current day cap
    ; or there are no spirits left for the day.

.loop:
    call CountActiveEnemies
    ld c, a              ; C = current active enemy count

    call GetDesiredActiveEnemies
    cp c                 ; desired active count - current active count
    ret z
    ret c

    call SpawnOneEnemy
    jr .loop

SpawnOneEnemy:
    ld a, [wSpiritsLeft]
    and a
    ret z

    ld a, [wEnemy0Active]
    and a
    jr z, .slot0

    ld a, [wEnemy1Active]
    and a
    jr z, .slot1

    ld a, [wEnemy2Active]
    and a
    jr z, .slot2

    ld a, [wEnemy3Active]
    and a
    jr z, .slot3

    ret

.slot0:
    call MakeRandomPortalX
    ld [wEnemy0X], a
    ld a, 48
    ld [wEnemy0Y], a
    call ChooseEnemyType
    ld [wEnemy0Type], a
    call InitEnemy0Velocity
    ld a, 1
    ld [wEnemy0Active], a
    xor a
    ld [wEnemy0MoveTimer], a
    ret

.slot1:
    call MakeRandomPortalX
    ld [wEnemy1X], a
    ld a, 48
    ld [wEnemy1Y], a
    call ChooseEnemyType
    ld [wEnemy1Type], a
    call InitEnemy1Velocity
    ld a, 1
    ld [wEnemy1Active], a
    xor a
    ld [wEnemy1MoveTimer], a
    ret

.slot2:
    call MakeRandomPortalX
    ld [wEnemy2X], a
    ld a, 48
    ld [wEnemy2Y], a
    call ChooseEnemyType
    ld [wEnemy2Type], a
    call InitEnemy2Velocity
    ld a, 1
    ld [wEnemy2Active], a
    xor a
    ld [wEnemy2MoveTimer], a
    ret

.slot3:
    call MakeRandomPortalX
    ld [wEnemy3X], a
    ld a, 48
    ld [wEnemy3Y], a
    call ChooseEnemyType
    ld [wEnemy3Type], a
    call InitEnemy3Velocity
    ld a, 1
    ld [wEnemy3Active], a
    xor a
    ld [wEnemy3MoveTimer], a
    ret

MakeRandomPortalX:
    call UpdateRNG
    ld a, [wRNG]
    and $7F
    add 16
    ret

ChooseEnemyType:
    ; Day 1 only uses chasing spirits.
    ; From Day 2 onward, roughly half of new spirits become wandering spirits.
    ld a, [wDay]
    cp 2
    jr nc, .canWander

    xor a
    ret

.canWander:
    call UpdateRNG
    ld a, [wRNG]
    and 1
    ret

InitEnemy0Velocity:
    call MakeRandomVelocity
    ld [wEnemy0DX], a
    ld a, b
    ld [wEnemy0DY], a
    ret

InitEnemy1Velocity:
    call MakeRandomVelocity
    ld [wEnemy1DX], a
    ld a, b
    ld [wEnemy1DY], a
    ret

InitEnemy2Velocity:
    call MakeRandomVelocity
    ld [wEnemy2DX], a
    ld a, b
    ld [wEnemy2DY], a
    ret

InitEnemy3Velocity:
    call MakeRandomVelocity
    ld [wEnemy3DX], a
    ld a, b
    ld [wEnemy3DY], a
    ret

MakeRandomVelocity:
    ; Output:
    ; A = X velocity, B = Y velocity.
    ; Values are 1 or 255. 255 acts as -1 when added to position.
    call UpdateRNG

    ld a, [wRNG]
    bit 0, a
    jr z, .xLeft

    ld a, 1
    jr .setY

.xLeft:
    ld a, 255

.setY:
    ld b, a

    ld a, [wRNG]
    bit 1, a
    jr z, .yUp

    ld a, 1
    jr .done

.yUp:
    ld a, 255

.done:
    ; Return X velocity in A, Y velocity in B.
    ld c, a
    ld a, b
    ld b, c
    ret

UpdateEnemies:
    call UpdateEnemy0
    call UpdateEnemy1
    call UpdateEnemy2
    call UpdateEnemy3
    ret

UpdateEnemy0:
    ld a, [wEnemy0Active]
    and a
    ret z

    ld a, [wEnemy0MoveTimer]
    inc a
    ld [wEnemy0MoveTimer], a

    ; Wandering spirits move every 3 frames.
    ld a, [wEnemy0Type]
    and a
    jr z, .chaseTimer

.wanderTimer:
    ld a, [wEnemy0MoveTimer]
    cp 3
    ret c
    xor a
    ld [wEnemy0MoveTimer], a
    call MoveEnemy0Wander
    ret

.chaseTimer:
    ld a, [wEnemy0MoveTimer]
    cp 4
    ret c
    xor a
    ld [wEnemy0MoveTimer], a
    call MoveEnemy0TowardPlayer
    ret

UpdateEnemy1:
    ld a, [wEnemy1Active]
    and a
    ret z

    ld a, [wEnemy1MoveTimer]
    inc a
    ld [wEnemy1MoveTimer], a

    ; Wandering spirits move every 3 frames.
    ld a, [wEnemy1Type]
    and a
    jr z, .chaseTimer

.wanderTimer:
    ld a, [wEnemy1MoveTimer]
    cp 3
    ret c
    xor a
    ld [wEnemy1MoveTimer], a
    call MoveEnemy1Wander
    ret

.chaseTimer:
    ld a, [wEnemy1MoveTimer]
    cp 4
    ret c
    xor a
    ld [wEnemy1MoveTimer], a
    call MoveEnemy1TowardPlayer
    ret

UpdateEnemy2:
    ld a, [wEnemy2Active]
    and a
    ret z

    ld a, [wEnemy2MoveTimer]
    inc a
    ld [wEnemy2MoveTimer], a

    ; Wandering spirits move every 3 frames.
    ld a, [wEnemy2Type]
    and a
    jr z, .chaseTimer

.wanderTimer:
    ld a, [wEnemy2MoveTimer]
    cp 3
    ret c
    xor a
    ld [wEnemy2MoveTimer], a
    call MoveEnemy2Wander
    ret

.chaseTimer:
    ld a, [wEnemy2MoveTimer]
    cp 4
    ret c
    xor a
    ld [wEnemy2MoveTimer], a
    call MoveEnemy2TowardPlayer
    ret

UpdateEnemy3:
    ld a, [wEnemy3Active]
    and a
    ret z

    ld a, [wEnemy3MoveTimer]
    inc a
    ld [wEnemy3MoveTimer], a

    ; Wandering spirits move every 3 frames.
    ld a, [wEnemy3Type]
    and a
    jr z, .chaseTimer

.wanderTimer:
    ld a, [wEnemy3MoveTimer]
    cp 3
    ret c
    xor a
    ld [wEnemy3MoveTimer], a
    call MoveEnemy3Wander
    ret

.chaseTimer:
    ld a, [wEnemy3MoveTimer]
    cp 4
    ret c
    xor a
    ld [wEnemy3MoveTimer], a
    call MoveEnemy3TowardPlayer
    ret

MoveEnemy0TowardPlayer:
    ld a, [wEnemy0X]
    ld b, a
    ld a, [wPlayerX]
    cp b
    jr z, .moveY
    jr c, .left
.right:
    ld a, [wEnemy0X]
    inc a
    ld [wEnemy0X], a
    jr .moveY
.left:
    ld a, [wEnemy0X]
    dec a
    ld [wEnemy0X], a
.moveY:
    ld a, [wEnemy0Y]
    ld b, a
    ld a, [wPlayerY]
    cp b
    ret z
    jr c, .up
.down:
    ld a, [wEnemy0Y]
    inc a
    ld [wEnemy0Y], a
    ret
.up:
    ld a, [wEnemy0Y]
    dec a
    ld [wEnemy0Y], a
    ret

MoveEnemy1TowardPlayer:
    ld a, [wEnemy1X]
    ld b, a
    ld a, [wPlayerX]
    cp b
    jr z, .moveY
    jr c, .left
.right:
    ld a, [wEnemy1X]
    inc a
    ld [wEnemy1X], a
    jr .moveY
.left:
    ld a, [wEnemy1X]
    dec a
    ld [wEnemy1X], a
.moveY:
    ld a, [wEnemy1Y]
    ld b, a
    ld a, [wPlayerY]
    cp b
    ret z
    jr c, .up
.down:
    ld a, [wEnemy1Y]
    inc a
    ld [wEnemy1Y], a
    ret
.up:
    ld a, [wEnemy1Y]
    dec a
    ld [wEnemy1Y], a
    ret

MoveEnemy2TowardPlayer:
    ld a, [wEnemy2X]
    ld b, a
    ld a, [wPlayerX]
    cp b
    jr z, .moveY
    jr c, .left
.right:
    ld a, [wEnemy2X]
    inc a
    ld [wEnemy2X], a
    jr .moveY
.left:
    ld a, [wEnemy2X]
    dec a
    ld [wEnemy2X], a
.moveY:
    ld a, [wEnemy2Y]
    ld b, a
    ld a, [wPlayerY]
    cp b
    ret z
    jr c, .up
.down:
    ld a, [wEnemy2Y]
    inc a
    ld [wEnemy2Y], a
    ret
.up:
    ld a, [wEnemy2Y]
    dec a
    ld [wEnemy2Y], a
    ret

MoveEnemy3TowardPlayer:
    ld a, [wEnemy3X]
    ld b, a
    ld a, [wPlayerX]
    cp b
    jr z, .moveY
    jr c, .left
.right:
    ld a, [wEnemy3X]
    inc a
    ld [wEnemy3X], a
    jr .moveY
.left:
    ld a, [wEnemy3X]
    dec a
    ld [wEnemy3X], a
.moveY:
    ld a, [wEnemy3Y]
    ld b, a
    ld a, [wPlayerY]
    cp b
    ret z
    jr c, .up
.down:
    ld a, [wEnemy3Y]
    inc a
    ld [wEnemy3Y], a
    ret
.up:
    ld a, [wEnemy3Y]
    dec a
    ld [wEnemy3Y], a
    ret


MoveEnemy0Wander:
    call BounceEnemy0
    ld a, [wEnemy0X]
    ld b, a
    ld a, [wEnemy0DX]
    add b
    ld [wEnemy0X], a
    ld a, [wEnemy0Y]
    ld b, a
    ld a, [wEnemy0DY]
    add b
    ld [wEnemy0Y], a
    ret

MoveEnemy1Wander:
    call BounceEnemy1
    ld a, [wEnemy1X]
    ld b, a
    ld a, [wEnemy1DX]
    add b
    ld [wEnemy1X], a
    ld a, [wEnemy1Y]
    ld b, a
    ld a, [wEnemy1DY]
    add b
    ld [wEnemy1Y], a
    ret

MoveEnemy2Wander:
    call BounceEnemy2
    ld a, [wEnemy2X]
    ld b, a
    ld a, [wEnemy2DX]
    add b
    ld [wEnemy2X], a
    ld a, [wEnemy2Y]
    ld b, a
    ld a, [wEnemy2DY]
    add b
    ld [wEnemy2Y], a
    ret

MoveEnemy3Wander:
    call BounceEnemy3
    ld a, [wEnemy3X]
    ld b, a
    ld a, [wEnemy3DX]
    add b
    ld [wEnemy3X], a
    ld a, [wEnemy3Y]
    ld b, a
    ld a, [wEnemy3DY]
    add b
    ld [wEnemy3Y], a
    ret

BounceEnemy0:
    ld a, [wEnemy0X]
    cp 16
    jr nc, .checkRight
    ld a, 1
    ld [wEnemy0DX], a
.checkRight:
    ld a, [wEnemy0X]
    cp 152
    jr c, .checkTop
    ld a, 255
    ld [wEnemy0DX], a
.checkTop:
    ld a, [wEnemy0Y]
    cp 48
    jr nc, .checkBottom
    ld a, 1
    ld [wEnemy0DY], a
.checkBottom:
    ld a, [wEnemy0Y]
    cp 144
    ret c
    ld a, 255
    ld [wEnemy0DY], a
    ret

BounceEnemy1:
    ld a, [wEnemy1X]
    cp 16
    jr nc, .checkRight
    ld a, 1
    ld [wEnemy1DX], a
.checkRight:
    ld a, [wEnemy1X]
    cp 152
    jr c, .checkTop
    ld a, 255
    ld [wEnemy1DX], a
.checkTop:
    ld a, [wEnemy1Y]
    cp 48
    jr nc, .checkBottom
    ld a, 1
    ld [wEnemy1DY], a
.checkBottom:
    ld a, [wEnemy1Y]
    cp 144
    ret c
    ld a, 255
    ld [wEnemy1DY], a
    ret

BounceEnemy2:
    ld a, [wEnemy2X]
    cp 16
    jr nc, .checkRight
    ld a, 1
    ld [wEnemy2DX], a
.checkRight:
    ld a, [wEnemy2X]
    cp 152
    jr c, .checkTop
    ld a, 255
    ld [wEnemy2DX], a
.checkTop:
    ld a, [wEnemy2Y]
    cp 48
    jr nc, .checkBottom
    ld a, 1
    ld [wEnemy2DY], a
.checkBottom:
    ld a, [wEnemy2Y]
    cp 144
    ret c
    ld a, 255
    ld [wEnemy2DY], a
    ret

BounceEnemy3:
    ld a, [wEnemy3X]
    cp 16
    jr nc, .checkRight
    ld a, 1
    ld [wEnemy3DX], a
.checkRight:
    ld a, [wEnemy3X]
    cp 152
    jr c, .checkTop
    ld a, 255
    ld [wEnemy3DX], a
.checkTop:
    ld a, [wEnemy3Y]
    cp 48
    jr nc, .checkBottom
    ld a, 1
    ld [wEnemy3DY], a
.checkBottom:
    ld a, [wEnemy3Y]
    cp 144
    ret c
    ld a, 255
    ld [wEnemy3DY], a
    ret

; ------------------------------------------------------------
; Collisions
; ------------------------------------------------------------

EnemyKilledNormal:
    ld a, [wSpiritsLeft]
    and a
    jr z, .score
    dec a
    ld [wSpiritsLeft], a
.score:
    ld a, [wScoreLo]
    add 10
    ld [wScoreLo], a
    jr nc, .done
    ld a, [wScoreHi]
    inc a
    ld [wScoreHi], a
.done:
    call MarkHUDDirty
    ret

EnemyKilledWave:
    ld a, [wSpiritsLeft]
    and a
    jr z, .score
    dec a
    ld [wSpiritsLeft], a
.score:
    ld a, [wScoreLo]
    add 20
    ld [wScoreLo], a
    jr nc, .done
    ld a, [wScoreHi]
    inc a
    ld [wScoreHi], a
.done:
    call MarkHUDDirty
    ret

CheckProjectileEnemyCollisions:
    ld a, [wProjectileActive]
    and a
    ret z

    call CheckProjectileEnemy0
    ld a, [wProjectileActive]
    and a
    ret z

    call CheckProjectileEnemy1
    ld a, [wProjectileActive]
    and a
    ret z

    call CheckProjectileEnemy2
    ld a, [wProjectileActive]
    and a
    ret z

    call CheckProjectileEnemy3
    ret

CheckProjectileEnemy0:
    ld a, [wEnemy0Active]
    and a
    ret z
    ld a, [wEnemy0X]
    ld b, a
    ld a, [wProjectileX]
    call AbsDiffAAndB
    cp 8
    ret nc
    ld a, [wEnemy0Y]
    ld b, a
    ld a, [wProjectileY]
    call AbsDiffAAndB
    cp 8
    ret nc
    xor a
    ld [wEnemy0Active], a
    ld [wProjectileActive], a
    call EnemyKilledNormal
    ret

CheckProjectileEnemy1:
    ld a, [wEnemy1Active]
    and a
    ret z
    ld a, [wEnemy1X]
    ld b, a
    ld a, [wProjectileX]
    call AbsDiffAAndB
    cp 8
    ret nc
    ld a, [wEnemy1Y]
    ld b, a
    ld a, [wProjectileY]
    call AbsDiffAAndB
    cp 8
    ret nc
    xor a
    ld [wEnemy1Active], a
    ld [wProjectileActive], a
    call EnemyKilledNormal
    ret

CheckProjectileEnemy2:
    ld a, [wEnemy2Active]
    and a
    ret z
    ld a, [wEnemy2X]
    ld b, a
    ld a, [wProjectileX]
    call AbsDiffAAndB
    cp 8
    ret nc
    ld a, [wEnemy2Y]
    ld b, a
    ld a, [wProjectileY]
    call AbsDiffAAndB
    cp 8
    ret nc
    xor a
    ld [wEnemy2Active], a
    ld [wProjectileActive], a
    call EnemyKilledNormal
    ret

CheckProjectileEnemy3:
    ld a, [wEnemy3Active]
    and a
    ret z
    ld a, [wEnemy3X]
    ld b, a
    ld a, [wProjectileX]
    call AbsDiffAAndB
    cp 8
    ret nc
    ld a, [wEnemy3Y]
    ld b, a
    ld a, [wProjectileY]
    call AbsDiffAAndB
    cp 8
    ret nc
    xor a
    ld [wEnemy3Active], a
    ld [wProjectileActive], a
    call EnemyKilledNormal
    ret

CheckKiWaveEnemyCollisions:
    ld a, [wKiWaveTimer]
    and a
    ret z

    call CheckKiWaveEnemy0
    call CheckKiWaveEnemy1
    call CheckKiWaveEnemy2
    call CheckKiWaveEnemy3
    ret

CheckKiWaveEnemy0:
    ld a, [wEnemy0Active]
    and a
    ret z
    ld a, [wEnemy0X]
    ld b, a
    ld a, [wPlayerX]
    call AbsDiffAAndB
    cp 28
    ret nc
    ld a, [wEnemy0Y]
    ld b, a
    ld a, [wPlayerY]
    call AbsDiffAAndB
    cp 28
    ret nc
    xor a
    ld [wEnemy0Active], a
    call EnemyKilledWave
    ret

CheckKiWaveEnemy1:
    ld a, [wEnemy1Active]
    and a
    ret z
    ld a, [wEnemy1X]
    ld b, a
    ld a, [wPlayerX]
    call AbsDiffAAndB
    cp 28
    ret nc
    ld a, [wEnemy1Y]
    ld b, a
    ld a, [wPlayerY]
    call AbsDiffAAndB
    cp 28
    ret nc
    xor a
    ld [wEnemy1Active], a
    call EnemyKilledWave
    ret

CheckKiWaveEnemy2:
    ld a, [wEnemy2Active]
    and a
    ret z
    ld a, [wEnemy2X]
    ld b, a
    ld a, [wPlayerX]
    call AbsDiffAAndB
    cp 28
    ret nc
    ld a, [wEnemy2Y]
    ld b, a
    ld a, [wPlayerY]
    call AbsDiffAAndB
    cp 28
    ret nc
    xor a
    ld [wEnemy2Active], a
    call EnemyKilledWave
    ret

CheckKiWaveEnemy3:
    ld a, [wEnemy3Active]
    and a
    ret z
    ld a, [wEnemy3X]
    ld b, a
    ld a, [wPlayerX]
    call AbsDiffAAndB
    cp 28
    ret nc
    ld a, [wEnemy3Y]
    ld b, a
    ld a, [wPlayerY]
    call AbsDiffAAndB
    cp 28
    ret nc
    xor a
    ld [wEnemy3Active], a
    call EnemyKilledWave
    ret

CheckEnemyPlayerCollisions:
    ld a, [wPlayerInvuln]
    and a
    ret nz

    call CheckPlayerEnemy0
    ld a, [wPlayerInvuln]
    and a
    ret nz

    call CheckPlayerEnemy1
    ld a, [wPlayerInvuln]
    and a
    ret nz

    call CheckPlayerEnemy2
    ld a, [wPlayerInvuln]
    and a
    ret nz

    call CheckPlayerEnemy3
    ret

DamagePlayer:
    ld a, [wPlayerHealth]
    dec a
    ld [wPlayerHealth], a
    call MarkHUDDirty

    ld a, 60
    ld [wPlayerInvuln], a

    ld a, [wPlayerHealth]
    and a
    ret nz

    ld a, STATE_GAMEOVER
    ld [wGameState], a

    xor a
    ld [wProjectileActive], a
    call ClearEnemies
    ret

CheckPlayerEnemy0:
    ld a, [wEnemy0Active]
    and a
    ret z
    ld a, [wEnemy0X]
    ld b, a
    ld a, [wPlayerX]
    call AbsDiffAAndB
    cp 8
    ret nc
    ld a, [wEnemy0Y]
    ld b, a
    ld a, [wPlayerY]
    call AbsDiffAAndB
    cp 8
    ret nc
    xor a
    ld [wEnemy0Active], a
    call DamagePlayer
    ret

CheckPlayerEnemy1:
    ld a, [wEnemy1Active]
    and a
    ret z
    ld a, [wEnemy1X]
    ld b, a
    ld a, [wPlayerX]
    call AbsDiffAAndB
    cp 8
    ret nc
    ld a, [wEnemy1Y]
    ld b, a
    ld a, [wPlayerY]
    call AbsDiffAAndB
    cp 8
    ret nc
    xor a
    ld [wEnemy1Active], a
    call DamagePlayer
    ret

CheckPlayerEnemy2:
    ld a, [wEnemy2Active]
    and a
    ret z
    ld a, [wEnemy2X]
    ld b, a
    ld a, [wPlayerX]
    call AbsDiffAAndB
    cp 8
    ret nc
    ld a, [wEnemy2Y]
    ld b, a
    ld a, [wPlayerY]
    call AbsDiffAAndB
    cp 8
    ret nc
    xor a
    ld [wEnemy2Active], a
    call DamagePlayer
    ret

CheckPlayerEnemy3:
    ld a, [wEnemy3Active]
    and a
    ret z
    ld a, [wEnemy3X]
    ld b, a
    ld a, [wPlayerX]
    call AbsDiffAAndB
    cp 8
    ret nc
    ld a, [wEnemy3Y]
    ld b, a
    ld a, [wPlayerY]
    call AbsDiffAAndB
    cp 8
    ret nc
    xor a
    ld [wEnemy3Active], a
    call DamagePlayer
    ret

CheckWaveClear:
    ; If all spirits for the day are gone, advance the day.
    ld a, [wSpiritsLeft]
    and a
    jr nz, .spawnMore

    call CountActiveEnemies
    and a
    ret nz

    ld a, [wDay]
    inc a
    ld [wDay], a

    ld a, 1
    ld [wKiWaveCharges], a

    xor a
    ld [wKiWaveCooldown], a

    call GetSpiritsForCurrentDay
    ld [wSpiritsLeft], a
    call MarkHUDDirty

.spawnMore:
    call SpawnToCap
    ret

AbsDiffAAndB:
    ; A = first value, B = second value, output A = absolute difference.
    cp b
    jr nc, .aGreaterOrEqual

    ld c, a
    ld a, b
    sub c
    ret

.aGreaterOrEqual:
    sub b
    ret

; ------------------------------------------------------------
; Drawing and RNG
; ------------------------------------------------------------

UpdateRNG:
    ld a, [wRNG]
    add $17
    ld b, a
    ld a, [wPlayerX]
    xor b
    ld [wRNG], a
    ret

DrawSprites:
    ld hl, _OAMRAM

    ; Sprite 0: Player
    ld a, [wPlayerY]
    ld [hli], a
    ld a, [wPlayerX]
    ld [hli], a
    ld a, 1
    ld [hli], a
    ld a, 0
    ld [hli], a

    ; Sprites 1-4: Enemies
    call DrawEnemy0
    call DrawEnemy1
    call DrawEnemy2
    call DrawEnemy3

    ; Sprite 5: Ki blast
    ld a, [wProjectileActive]
    and a
    jr z, .hideProjectile

    ld a, [wProjectileY]
    ld [hli], a
    ld a, [wProjectileX]
    ld [hli], a
    ld a, 3
    ld [hli], a
    ld a, 2
    ld [hli], a
    jr .portal

.hideProjectile:
    xor a
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld [hli], a

.portal:
    ; Sprites 6-15: full-width portal line.
    call DrawPortalLine

    ; Sprites 16-19: Ki Wave visual.
    call DrawKiWaveSprites

    ; 20 sprite slots used, 20 remaining.
    call HideRemainingSprites
    ret

DrawEnemy0:
    ld a, [wEnemy0Active]
    and a
    jr z, HideOneSprite
    ld a, [wEnemy0Y]
    ld [hli], a
    ld a, [wEnemy0X]
    ld [hli], a

    ld a, [wEnemy0Type]
    and a
    jr z, .normalTile

    ld a, 20
    jr .writeTile

.normalTile:
    ld a, 2

.writeTile:
    ld [hli], a
    ld a, 1
    ld [hli], a
    ret

DrawEnemy1:
    ld a, [wEnemy1Active]
    and a
    jr z, HideOneSprite
    ld a, [wEnemy1Y]
    ld [hli], a
    ld a, [wEnemy1X]
    ld [hli], a

    ld a, [wEnemy1Type]
    and a
    jr z, .normalTile

    ld a, 20
    jr .writeTile

.normalTile:
    ld a, 2

.writeTile:
    ld [hli], a
    ld a, 1
    ld [hli], a
    ret

DrawEnemy2:
    ld a, [wEnemy2Active]
    and a
    jr z, HideOneSprite
    ld a, [wEnemy2Y]
    ld [hli], a
    ld a, [wEnemy2X]
    ld [hli], a

    ld a, [wEnemy2Type]
    and a
    jr z, .normalTile

    ld a, 20
    jr .writeTile

.normalTile:
    ld a, 2

.writeTile:
    ld [hli], a
    ld a, 1
    ld [hli], a
    ret

DrawEnemy3:
    ld a, [wEnemy3Active]
    and a
    jr z, HideOneSprite
    ld a, [wEnemy3Y]
    ld [hli], a
    ld a, [wEnemy3X]
    ld [hli], a

    ld a, [wEnemy3Type]
    and a
    jr z, .normalTile

    ld a, 20
    jr .writeTile

.normalTile:
    ld a, 2

.writeTile:
    ld [hli], a
    ld a, 1
    ld [hli], a
    ret

HideOneSprite:
    xor a
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ret

DrawPortalLine:
    ld b, 5
    ld c, 16

.loop:
    ld a, 40
    ld [hli], a
    ld a, c
    ld [hli], a
    ld a, 4
    ld [hli], a
    ld a, 3
    ld [hli], a

    ld a, c
    add 32
    ld c, a

    dec b
    jr nz, .loop
    ret

DrawKiWaveSprites:
    ld a, [wKiWaveTimer]
    and a
    jr z, .hideWave

    ; Wave above player.
    ld a, [wPlayerY]
    sub 16
    ld [hli], a
    ld a, [wPlayerX]
    ld [hli], a
    ld a, 5
    ld [hli], a
    ld a, 2
    ld [hli], a

    ; Wave below player.
    ld a, [wPlayerY]
    add 16
    ld [hli], a
    ld a, [wPlayerX]
    ld [hli], a
    ld a, 5
    ld [hli], a
    ld a, 2
    ld [hli], a

    ; Wave left of player.
    ld a, [wPlayerY]
    ld [hli], a
    ld a, [wPlayerX]
    sub 16
    ld [hli], a
    ld a, 5
    ld [hli], a
    ld a, 2
    ld [hli], a

    ; Wave right of player.
    ld a, [wPlayerY]
    ld [hli], a
    ld a, [wPlayerX]
    add 16
    ld [hli], a
    ld a, 5
    ld [hli], a
    ld a, 2
    ld [hli], a
    ret

.hideWave:
    call HideOneSprite
    call HideOneSprite
    call HideOneSprite
    call HideOneSprite
    ret

HideRemainingSprites:
    ld b, 25
    xor a
.loop:
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld [hli], a
    dec b
    jr nz, .loop
    ret

; ------------------------------------------------------------
; HUD
; ------------------------------------------------------------

MarkHUDDirty:
    ld a, 1
    ld [wHUDDirty], a
    ret

UpdateHUDIfDirty:
    ld a, [wHUDDirty]
    and a
    ret z

    xor a
    ld [wHUDDirty], a

    call UpdateHUD
    ret


ClearHUDRows:
    ld hl, _SCRN0 + 32
    ld b, 20
.clearTop:
    xor a
    ld [hli], a
    dec b
    jr nz, .clearTop

    ld hl, _SCRN0 + 512
    ld b, 20
.clearBottom:
    xor a
    ld [hli], a
    dec b
    jr nz, .clearBottom
    ret

UpdateHUD:
    ; call ClearHUDRows

    ; Health - top left: H5
    ld hl, _SCRN0 + 32 + 1
    ld a, TILE_H
    ld [hli], a
    ld a, [wPlayerHealth]
    call WriteDigitInc

    ; Score - top middle: S000
    ld hl, _SCRN0 + 32 + 8
    ld a, TILE_S
    ld [hli], a
    call WriteScore3Digits

    ; Day - top right: D1
    ld hl, _SCRN0 + 32 + 17
    ld a, TILE_D
    ld [hli], a
    ld a, [wDay]
    call WriteDigitInc

    ; Ki Wave - bottom left: W1
    ld hl, _SCRN0 + 512 + 1
    ld a, TILE_W
    ld [hli], a
    ld a, [wKiWaveCharges]
    call WriteDigitInc
    ret

WriteDigitInc:
    cp 10
    jr c, .validDigit
    ld a, 9
.validDigit:
    add TILE_DIGIT_0
    ld [hli], a
    ret

WriteScore3Digits:
    ld a, [wScoreLo]
    ld c, a

    ld b, 0
.hundredsLoop:
    ld a, c
    cp 100
    jr c, .writeHundreds
    sub 100
    ld c, a
    inc b
    jr .hundredsLoop
.writeHundreds:
    ld a, b
    call WriteDigitInc

    ld b, 0
.tensLoop:
    ld a, c
    cp 10
    jr c, .writeTens
    sub 10
    ld c, a
    inc b
    jr .tensLoop
.writeTens:
    ld a, b
    call WriteDigitInc

    ld a, c
    call WriteDigitInc
    ret

; ------------------------------------------------------------
; Graphics loading
; ------------------------------------------------------------

LoadSpriteTiles:
    ld de, SpriteTiles
    ld hl, _VRAM
    ld bc, SpriteTilesEnd - SpriteTiles
.copyLoop:
    ld a, [de]
    ld [hli], a
    inc de
    dec bc
    ld a, b
    or c
    jr nz, .copyLoop
    ret

LoadCGBPalettes:
    ld a, $80
    ldh [rBCPS], a
    ld de, BGPalette
    ld b, 8
.copyBG:
    ld a, [de]
    ldh [rBCPD], a
    inc de
    dec b
    jr nz, .copyBG

    ld a, $80
    ldh [rOCPS], a
    ld de, OBJPalettes
    ld b, 32
.copyOBJ:
    ld a, [de]
    ldh [rOCPD], a
    inc de
    dec b
    jr nz, .copyOBJ
    ret

; ------------------------------------------------------------
; Timing and clearing
; ------------------------------------------------------------

WaitVBlank:
    ; First wait until we are OUT of VBlank.
    ; This prevents the loop from running multiple times during the same VBlank.
.waitNotVBlank:
    ldh a, [rLY]
    cp 144
    jr nc, .waitNotVBlank

    ; Then wait until the next VBlank starts.
.waitVBlank:
    ldh a, [rLY]
    cp 144
    jr c, .waitVBlank

    ret

ClearOAM:
    ld hl, _OAMRAM
    ld b, 160
.loop:
    xor a
    ld [hli], a
    dec b
    jr nz, .loop
    ret

ClearBackgroundMap:
    ld hl, _SCRN0
    ld bc, 1024
.loop:
    xor a
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, .loop
    ret

; ------------------------------------------------------------
; Data
; ------------------------------------------------------------

SpiritsPerDayTable:
    db 3, 5, 9, 15, 24, 36, 52, 72, 96, 120

SECTION "Graphics Data", ROM0

; 4-colour Game Boy Color palettes.
; Each colour is 15-bit BGR, little endian.
BGPalette:
    db $6B, $35 ; colour 0: medium grey
    db $4A, $29 ; colour 1: dark grey
    db $21, $14 ; colour 2: darker grey
    db $00, $00 ; colour 3: black

OBJPalettes:
; OBJ palette 0: Player / monk, warm gold
    db $FF, $7F ; colour 0: transparent / white
    db $9F, $02 ; colour 1: orange
    db $FF, $03 ; colour 2: yellow
    db $1F, $02 ; colour 3: deep orange

; OBJ palette 1: Spirit, dark blue
    db $FF, $7F ; colour 0: transparent / white
    db $00, $40 ; colour 1: dark blue
    db $1F, $00 ; colour 2: darker blue/purple
    db $00, $40 ; colour 3: dark blue

; OBJ palette 2: Ki blast / Ki Wave, light blue
    db $FF, $7F ; colour 0: transparent / white
    db $0C, $7F ; colour 1: light blue
    db $E0, $7F ; colour 2: cyan
    db $0C, $7F ; colour 3: light blue

; OBJ palette 3: Portal, darker purple
    db $FF, $7F ; colour 0: transparent / white
    db $10, $40 ; colour 1: dark purple
    db $08, $20 ; colour 2: very dark purple
    db $10, $40 ; colour 3: dark purple

SpriteTiles:
; Tile 0: Blank tile
    db %00000000, %00000000
    db %00000000, %00000000
    db %00000000, %00000000
    db %00000000, %00000000
    db %00000000, %00000000
    db %00000000, %00000000
    db %00000000, %00000000
    db %00000000, %00000000

; Tile 1: Player / monk
    db %00011000, %00011000
    db %00111100, %00111100
    db %01111110, %01111110
    db %01011010, %01011010
    db %01111110, %01111110
    db %00100100, %00100100
    db %01000010, %01000010
    db %10000001, %10000001

; Tile 2: Spirit
    db %00111100, %00111100
    db %01111110, %01111110
    db %11011011, %11011011
    db %11111111, %11111111
    db %11111111, %11111111
    db %10111101, %10111101
    db %10011001, %10011001
    db %01000010, %01000010

; Tile 3: Ki blast
    db %00000000, %00000000
    db %00011000, %00011000
    db %00111100, %00111100
    db %01111110, %01111110
    db %01111110, %01111110
    db %00111100, %00111100
    db %00011000, %00011000
    db %00000000, %00000000

; Tile 4: Portal
    db %00111100, %00111100
    db %01000010, %01000010
    db %10011001, %10011001
    db %10111101, %10111101
    db %10111101, %10111101
    db %10011001, %10011001
    db %01000010, %01000010
    db %00111100, %00111100

; Tile 5: Ki Wave
    db %00011000, %00011000
    db %00100100, %00100100
    db %01000010, %01000010
    db %10000001, %10000001
    db %10000001, %10000001
    db %01000010, %01000010
    db %00100100, %00100100
    db %00011000, %00011000

; Tile 6: H
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001
    db %11111111, %11111111
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001

; Tile 7: D
    db %11111100, %11111100
    db %10000010, %10000010
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000010, %10000010
    db %11111100, %11111100

; Tile 8: S
    db %01111110, %01111110
    db %10000000, %10000000
    db %10000000, %10000000
    db %01111100, %01111100
    db %00000010, %00000010
    db %00000001, %00000001
    db %00000001, %00000001
    db %11111110, %11111110

; Tile 9: W
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001
    db %10011001, %10011001
    db %10011001, %10011001
    db %10100101, %10100101
    db %11000011, %11000011
    db %10000001, %10000001

; Tile 10: 0
    db %00111100, %00111100
    db %01000010, %01000010
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001
    db %01000010, %01000010
    db %00111100, %00111100

; Tile 11: 1
    db %00011000, %00011000
    db %00111000, %00111000
    db %00011000, %00011000
    db %00011000, %00011000
    db %00011000, %00011000
    db %00011000, %00011000
    db %00011000, %00011000
    db %01111110, %01111110

; Tile 12: 2
    db %00111100, %00111100
    db %01000010, %01000010
    db %00000010, %00000010
    db %00000100, %00000100
    db %00011000, %00011000
    db %00100000, %00100000
    db %01000000, %01000000
    db %01111110, %01111110

; Tile 13: 3
    db %00111100, %00111100
    db %01000010, %01000010
    db %00000010, %00000010
    db %00011100, %00011100
    db %00000010, %00000010
    db %00000010, %00000010
    db %01000010, %01000010
    db %00111100, %00111100

; Tile 14: 4
    db %00000100, %00000100
    db %00001100, %00001100
    db %00010100, %00010100
    db %00100100, %00100100
    db %01000100, %01000100
    db %11111110, %11111110
    db %00000100, %00000100
    db %00000100, %00000100

; Tile 15: 5
    db %01111110, %01111110
    db %01000000, %01000000
    db %01000000, %01000000
    db %01111100, %01111100
    db %00000010, %00000010
    db %00000010, %00000010
    db %01000010, %01000010
    db %00111100, %00111100

; Tile 16: 6
    db %00111100, %00111100
    db %01000010, %01000010
    db %01000000, %01000000
    db %01111100, %01111100
    db %01000010, %01000010
    db %01000010, %01000010
    db %01000010, %01000010
    db %00111100, %00111100

; Tile 17: 7
    db %01111110, %01111110
    db %00000010, %00000010
    db %00000100, %00000100
    db %00001000, %00001000
    db %00010000, %00010000
    db %00100000, %00100000
    db %00100000, %00100000
    db %00100000, %00100000

; Tile 18: 8
    db %00111100, %00111100
    db %01000010, %01000010
    db %01000010, %01000010
    db %00111100, %00111100
    db %01000010, %01000010
    db %01000010, %01000010
    db %01000010, %01000010
    db %00111100, %00111100

; Tile 19: 9
    db %00111100, %00111100
    db %01000010, %01000010
    db %01000010, %01000010
    db %01000010, %01000010
    db %00111110, %00111110
    db %00000010, %00000010
    db %01000010, %01000010
    db %00111100, %00111100

; Tile 20: Wandering Spirit
    db %00011000, %00011000
    db %00111100, %00111100
    db %01111110, %01111110
    db %11111111, %11111111
    db %11100111, %11100111
    db %01111110, %01111110
    db %00111100, %00111100
    db %00011000, %00011000

SpriteTilesEnd:
