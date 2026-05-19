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
wPlayerInvuln:       db
wPlayerMoveTimer:    db
wPlayerKnockTimer:   db
wPlayerKnockDX:      db
wPlayerKnockDY:      db

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
wScoreThousands:  db
wScoreHundreds:   db
wScoreTens:       db
wScoreOnes:       db

wHighThousands:   db
wHighHundreds:    db
wHighTens:        db
wHighOnes:        db


wRNG:             db
wHUDDirty:        db

wMusicEnabled:       db

wMusicMelodyTimer:   db
wMusicMelodyIndex:   db

wMusicBassTimer:     db
wMusicBassIndex:     db

wMusicDrumTimer:     db
wMusicDrumIndex:     db

wGameplayMusicTempoCounter: db
wMusicFrameStep:            db

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
    call InitSound
    call LoadSpriteTiles
    call ClearBackgroundMap
    call ClearOAM
    call InitTitle

    ; LCD on, tile data at $8000, sprites on, BG on.
    ld a, %10010011
    ldh [rLCDC], a

MainLoop:
    call WaitVBlank

    ; Audio sequencer tick.
    call UpdateMusic

    ; Do graphics/tile updates first while we are closest to VBlank.
    call UpdateHUDIfDirty
    call DrawSprites

    ; Then process gameplay for the next frame.
    call ReadJoypad
    call UpdateRNG
    call UpdateGame

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

    call PlayStartGameSfx
    call InitGame
    ret

UpdateGameOver:
    ; Press Start to restart.
    ld a, [wJoyButtons]
    bit 3, a
    ret z

    call PlayStartGameSfx
    call InitGame
    ret

UpdatePlaying:
    call UpdatePlayerInvuln
    call UpdatePlayerKnockback
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
    ld [wScoreThousands], a
    ld [wScoreHundreds], a
    ld [wScoreTens], a
    ld [wScoreOnes], a
    ld [wHighThousands], a
    ld [wHighHundreds], a
    ld [wHighTens], a
    ld [wHighOnes], a
    ld [wKiWaveTimer], a
    ld [wKiWaveCooldown], a
    ld [wPlayerKnockTimer], a
    ld [wPlayerKnockDX], a
    ld [wPlayerKnockDY], a
    ld [wHUDDirty], a

    call ClearEnemies

    ; Title screen owns the background map.
    ; At boot the LCD is already off, so these VRAM writes are safe.
    call ClearBackgroundMap
    call ClearBackgroundAttributes
    call ClearOAM

    call DrawTitleArena
    call DrawTitleScreen
    call SetTitleScreenPalettes

    call StartTitleMusic

    ret

InitGame:
    ; Clear title/menu tiles before gameplay begins.
    ; LCD stays off while we draw the arena and set GBC HUD attributes.
    call ClearScreenForGameplay
    call DrawGameplayArena
    call SetGameplayHUDPalettes
    call TurnGameplayLCDOn
    call StopMusic

    ld a, STATE_PLAYING
    ld [wGameState], a

    call StartGameplayMusic

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
    ld [wScoreThousands], a
    ld [wScoreHundreds], a
    ld [wScoreTens], a
    ld [wScoreOnes], a
    ld [wKiWaveTimer], a
    ld [wKiWaveCooldown], a
    ld [wPlayerKnockTimer], a
    ld [wPlayerKnockDX], a
    ld [wPlayerKnockDY], a

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


EnterGameOver:
    ; Update high score before drawing the game-over screen.
    call UpdateHighScoreIfNeeded
    call StopMusic

    ; Stop gameplay objects.
    xor a
    ld [wProjectileActive], a
    ld [wPlayerKnockTimer], a
    ld [wPlayerKnockDX], a
    ld [wPlayerKnockDY], a
    ld [wHUDDirty], a
    call ClearEnemies

    ; Game-over screen owns the background map.
    call WaitVBlank
    xor a
    ldh [rLCDC], a

    call ClearBackgroundMap
    call ClearBackgroundAttributes
    call ClearOAM

    call DrawGameOverArena
    call DrawGameOverScreen
    call SetGameOverScreenPalettes

    ; LCD on, tile data at $8000, sprites on, BG on.
    ld a, %10010011
    ldh [rLCDC], a

    call PlayGameOverSfx

    ld a, STATE_GAMEOVER
    ld [wGameState], a

    call StartGameOverJingle

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

UpdatePlayerKnockback:
    ld a, [wPlayerKnockTimer]
    and a
    ret z

    dec a
    ld [wPlayerKnockTimer], a

    ; -----------------------------
    ; Move X by knockback direction.
    ; DX = 1 means right.
    ; DX = 255 means left.
    ; -----------------------------
    ld a, [wPlayerKnockDX]
    cp 1
    jr z, .knockRight

.knockLeft:
    ld a, [wPlayerX]
    cp 16
    jr c, .moveY
    dec a
    ld [wPlayerX], a
    jr .moveY

.knockRight:
    ld a, [wPlayerX]
    cp 152
    jr nc, .moveY
    inc a
    ld [wPlayerX], a

.moveY:
    ; -----------------------------
    ; Move Y by knockback direction.
    ; DY = 1 means down.
    ; DY = 255 means up.
    ; -----------------------------
    ld a, [wPlayerKnockDY]
    cp 1
    jr z, .knockDown

.knockUp:
    ld a, [wPlayerY]
    cp 64
    ret c
    dec a
    ld [wPlayerY], a
    ret

.knockDown:
    ld a, [wPlayerY]
    cp 144
    ret nc
    inc a
    ld [wPlayerY], a
    ret

UpdatePlayer:
    ; Do not allow manual movement while knockback is active.
    ld a, [wPlayerKnockTimer]
    and a
    ret nz

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

    call PlayKiBlastSfx

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

    call PlayKiWaveSfx

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
    call Add100Score
    call PlayEnemyHitSfx
    call MarkHUDDirty
    ret

EnemyKilledWave:
    ld a, [wSpiritsLeft]
    and a
    jr z, .score
    dec a
    ld [wSpiritsLeft], a

.score:
    call Add150Score
    call MarkHUDDirty
    ret

Add100Score:
    ld a, [wScoreHundreds]
    inc a
    cp 10
    jr c, .storeHundreds

    xor a
    ld [wScoreHundreds], a

    ld a, [wScoreThousands]
    inc a
    cp 10
    jr c, .storeThousands

    ; Clamp at 9999.
    ld a, 9
    ld [wScoreThousands], a
    ld [wScoreHundreds], a
    ld [wScoreTens], a
    ld [wScoreOnes], a
    ret

.storeThousands:
    ld [wScoreThousands], a
    ret

.storeHundreds:
    ld [wScoreHundreds], a
    ret


Add150Score:
    ; +100
    call Add100Score

    ; +50
    ld a, [wScoreTens]
    add 5
    cp 10
    jr c, .storeTens

    sub 10
    ld [wScoreTens], a

    ld a, [wScoreHundreds]
    inc a
    cp 10
    jr c, .storeHundreds

    xor a
    ld [wScoreHundreds], a

    ld a, [wScoreThousands]
    inc a
    cp 10
    jr c, .storeThousands

    ; Clamp at 9999.
    ld a, 9
    ld [wScoreThousands], a
    ld [wScoreHundreds], a
    ld [wScoreTens], a
    ld [wScoreOnes], a
    ret

.storeThousands:
    ld [wScoreThousands], a
    ret

.storeHundreds:
    ld [wScoreHundreds], a
    ret

.storeTens:
    ld [wScoreTens], a
    ret

UpdateHighScoreIfNeeded:
    ; Compare score thousands.
    ld a, [wScoreThousands]
    ld b, a
    ld a, [wHighThousands]
    cp b
    jr c, .copyScoreToHigh
    jr nz, .done

    ; Compare hundreds.
    ld a, [wScoreHundreds]
    ld b, a
    ld a, [wHighHundreds]
    cp b
    jr c, .copyScoreToHigh
    jr nz, .done

    ; Compare tens.
    ld a, [wScoreTens]
    ld b, a
    ld a, [wHighTens]
    cp b
    jr c, .copyScoreToHigh
    jr nz, .done

    ; Compare ones.
    ld a, [wScoreOnes]
    ld b, a
    ld a, [wHighOnes]
    cp b
    jr c, .copyScoreToHigh
    jr nz, .done

.done:
    ret

.copyScoreToHigh:
    ld a, [wScoreThousands]
    ld [wHighThousands], a

    ld a, [wScoreHundreds]
    ld [wHighHundreds], a

    ld a, [wScoreTens]
    ld [wHighTens], a

    ld a, [wScoreOnes]
    ld [wHighOnes], a

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

DamagePlayerFromEnemy:
    ; Input:
    ; B = enemy X
    ; C = enemy Y
    ; Sets knockback direction away from the enemy.

    ; X knockback direction.
    ld a, [wPlayerX]
    cp b
    jr nc, .pushRight

.pushLeft:
    ld a, 255
    ld [wPlayerKnockDX], a
    jr .setY

.pushRight:
    ld a, 1
    ld [wPlayerKnockDX], a

.setY:
    ; Y knockback direction.
    ld a, [wPlayerY]
    cp c
    jr nc, .pushDown

.pushUp:
    ld a, 255
    ld [wPlayerKnockDY], a
    jr .startKnockback

.pushDown:
    ld a, 1
    ld [wPlayerKnockDY], a

.startKnockback:
    ; Knockback lasts 12 frames.
    ld a, 12
    ld [wPlayerKnockTimer], a

    call DamagePlayer
    ret

DamagePlayer:
    ld a, [wPlayerHealth]
    dec a
    ld [wPlayerHealth], a
    call MarkHUDDirty
    call PlayPlayerHurtSfx

    ld a, 60
    ld [wPlayerInvuln], a

    ld a, [wPlayerHealth]
    and a
    ret nz

    call EnterGameOver
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
    ld a, [wEnemy0X]
    ld b, a
    ld a, [wEnemy0Y]
    ld c, a
    call DamagePlayerFromEnemy
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
    ld a, [wEnemy1X]
    ld b, a
    ld a, [wEnemy1Y]
    ld c, a
    call DamagePlayerFromEnemy
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
    ld a, [wEnemy2X]
    ld b, a
    ld a, [wEnemy2Y]
    ld c, a
    call DamagePlayerFromEnemy
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
    ld a, [wEnemy3X]
    ld b, a
    ld a, [wEnemy3Y]
    ld c, a
    call DamagePlayerFromEnemy
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
    ; On menu screens, hide all gameplay sprites.
    ld a, [wGameState]
    cp STATE_PLAYING
    jr z, .drawGameplaySprites

    call HideAllSprites
    ret

.drawGameplaySprites:
    ld hl, _OAMRAM

    ; Sprite 0: Player
    ; During invulnerability, hide the player every few frames
    ; to create a flashing damage effect.
    ld a, [wPlayerInvuln]
    and a
    jr z, .drawPlayer

    bit 2, a
    jr z, .drawPlayer

.hidePlayer:
    xor a
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld [hli], a
    jr .afterPlayer

.drawPlayer:
    ld a, [wPlayerY]
    ld [hli], a
    ld a, [wPlayerX]
    ld [hli], a
    ld a, 1
    ld [hli], a
    ld a, 0
    ld [hli], a

.afterPlayer:

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

HideAllSprites:
    ld hl, _OAMRAM
    ld b, 40
    xor a

.loop:
    ld [hli], a
    ld [hli], a
    ld [hli], a
    ld [hli], a

    dec b
    jr nz, .loop

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
; Gameplay arena background
; ------------------------------------------------------------

; ------------------------------------------------------------
; Title / game over arena backgrounds
; ------------------------------------------------------------

DrawTitleArena:
    ; Reuse the temple arena as the title background.
    call DrawGameplayArena

    ; Decorative emblem above the title.
    ld hl, _SCRN0 + 96 + 9
    ld a, TILE_TITLE_EMBLEM
    ld [hli], a
    ld [hli], a

    ; Small cracked stones around the prompt area.
    ld hl, _SCRN0 + 416 + 3
    ld a, TILE_FLOOR_CRACK
    ld [hl], a

    ld hl, _SCRN0 + 416 + 16
    ld a, TILE_FLOOR_CRACK
    ld [hl], a

    ret


DrawGameOverArena:
    ; Reuse the temple arena as the game over background.
    call DrawGameplayArena

    ; Spirit/skull marker above GAME OVER.
    ld hl, _SCRN0 + 64 + 9
    ld a, TILE_SKULL_ICON
    ld [hli], a
    ld [hli], a

    ; Extra cracked floor details to make this screen feel harsher.
    ld hl, _SCRN0 + 224 + 3
    ld a, TILE_FLOOR_CRACK
    ld [hl], a

    ld hl, _SCRN0 + 224 + 16
    ld a, TILE_FLOOR_CRACK
    ld [hl], a

    ld hl, _SCRN0 + 480 + 9
    ld a, TILE_FLOOR_CRACK
    ld [hl], a

    ret

DrawGameplayArena:
    ; Fill the visible 20x18 screen area with floor tiles.
    ; The full BG map is 32 tiles wide, so each visible row starts 32 tiles later.

    ld hl, _SCRN0
    ld b, 18

.rowLoop:
    push bc

    ld b, 20
.tileLoop:
    ld a, TILE_FLOOR
    ld [hli], a
    dec b
    jr nz, .tileLoop

    ; Move HL from end of visible row to start of next visible row.
    ; 32 total BG tiles per row - 20 visible tiles = 12 skipped tiles.
    ld de, 12
    add hl, de

    pop bc
    dec b
    jr nz, .rowLoop


    ; Top border row, row 0.
    ld hl, _SCRN0
    ld a, TILE_CORNER
    ld [hli], a

    ld b, 18
.topBorder:
    ld a, TILE_BORDER_H
    ld [hli], a
    dec b
    jr nz, .topBorder

    ld a, TILE_CORNER
    ld [hli], a


    ; Bottom border row, row 17.
    ld hl, _SCRN0 + 544
    ld a, TILE_CORNER
    ld [hli], a

    ld b, 18
.bottomBorder:
    ld a, TILE_BORDER_H
    ld [hli], a
    dec b
    jr nz, .bottomBorder

    ld a, TILE_CORNER
    ld [hli], a


    ; Left and right borders, rows 1-16.
    ld hl, _SCRN0 + 32
    ld b, 16

.sideLoop:
    ld a, TILE_BORDER_V
    ld [hl], a

    push hl
    ld de, 19
    add hl, de
    ld a, TILE_BORDER_V
    ld [hl], a
    pop hl

    ld de, 32
    add hl, de

    dec b
    jr nz, .sideLoop


    ; Add a few cracked floor details manually.
    ; These are decorative only.
    ld hl, _SCRN0 + 160 + 4
    ld a, TILE_FLOOR_CRACK
    ld [hl], a

    ld hl, _SCRN0 + 224 + 14
    ld a, TILE_FLOOR_CRACK
    ld [hl], a

    ld hl, _SCRN0 + 352 + 7
    ld a, TILE_FLOOR_CRACK
    ld [hl], a

    ld hl, _SCRN0 + 448 + 15
    ld a, TILE_FLOOR_CRACK
    ld [hl], a

    ret

; ------------------------------------------------------------
; HUD
; ------------------------------------------------------------

MarkHUDDirty:
    ld a, 1
    ld [wHUDDirty], a
    ret

UpdateHUDIfDirty:
    ; HUD should only draw during gameplay.
    ; Title and game-over screens own the background tilemap.
    ld a, [wGameState]
    cp STATE_PLAYING
    ret nz

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

DrawTitleScreen:
    ; --------------------------------------------------------
    ; Row 5: KI WARDEN
    ; --------------------------------------------------------
    ld hl, _SCRN0 + 160 + 6

    ld a, TILE_K
    ld [hli], a
    ld a, TILE_I
    ld [hli], a

    xor a
    ld [hli], a

    ld a, TILE_W
    ld [hli], a
    ld a, TILE_A
    ld [hli], a
    ld a, TILE_R
    ld [hli], a
    ld a, TILE_D
    ld [hli], a
    ld a, TILE_E
    ld [hli], a
    ld a, TILE_N
    ld [hli], a


    ; --------------------------------------------------------
    ; Row 8: KI WAVE / moon icons as decoration.
    ; --------------------------------------------------------
    ld hl, _SCRN0 + 256 + 7
    ld a, TILE_KI_ICON
    ld [hli], a

    xor a
    ld [hli], a

    ld a, TILE_MOON_ICON
    ld [hli], a

    xor a
    ld [hli], a

    ld a, TILE_KI_ICON
    ld [hli], a


    ; --------------------------------------------------------
    ; Row 12: PRESS START
    ; --------------------------------------------------------
    ld hl, _SCRN0 + 384 + 4

    ld a, TILE_P
    ld [hli], a
    ld a, TILE_R
    ld [hli], a
    ld a, TILE_E
    ld [hli], a
    ld a, TILE_S
    ld [hli], a
    ld a, TILE_S
    ld [hli], a

    xor a
    ld [hli], a

    ld a, TILE_S
    ld [hli], a
    ld a, TILE_T
    ld [hli], a
    ld a, TILE_A
    ld [hli], a
    ld a, TILE_R
    ld [hli], a
    ld a, TILE_T
    ld [hli], a

    ret

DrawGameOverScreen:
    ; --------------------------------------------------------
    ; Row 4: GAME OVER
    ; --------------------------------------------------------
    ld hl, _SCRN0 + 128 + 5

    ld a, TILE_G
    ld [hli], a
    ld a, TILE_A
    ld [hli], a
    ld a, TILE_M
    ld [hli], a
    ld a, TILE_E
    ld [hli], a

    xor a
    ld [hli], a

    ld a, TILE_O
    ld [hli], a
    ld a, TILE_V
    ld [hli], a
    ld a, TILE_E
    ld [hli], a
    ld a, TILE_R
    ld [hli], a


    ; --------------------------------------------------------
    ; Row 8: SCORE 0000
    ; --------------------------------------------------------
    ld hl, _SCRN0 + 256 + 4

    ld a, TILE_SCORE_ICON
    ld [hli], a

    xor a
    ld [hli], a

    ld a, TILE_S
    ld [hli], a
    ld a, TILE_C
    ld [hli], a
    ld a, TILE_O
    ld [hli], a
    ld a, TILE_R
    ld [hli], a
    ld a, TILE_E
    ld [hli], a

    xor a
    ld [hli], a

    call WriteScore4Digits


    ; --------------------------------------------------------
    ; Row 10: HIGH 0000
    ; --------------------------------------------------------
    ld hl, _SCRN0 + 320 + 5

    ld a, TILE_MOON_ICON
    ld [hli], a

    xor a
    ld [hli], a

    ld a, TILE_H
    ld [hli], a
    ld a, TILE_I
    ld [hli], a
    ld a, TILE_G
    ld [hli], a
    ld a, TILE_H
    ld [hli], a

    xor a
    ld [hli], a

    call WriteHighScore4Digits


    ; --------------------------------------------------------
    ; Row 14: PRESS START
    ; --------------------------------------------------------
    ld hl, _SCRN0 + 448 + 4

    ld a, TILE_P
    ld [hli], a
    ld a, TILE_R
    ld [hli], a
    ld a, TILE_E
    ld [hli], a
    ld a, TILE_S
    ld [hli], a
    ld a, TILE_S
    ld [hli], a

    xor a
    ld [hli], a

    ld a, TILE_S
    ld [hli], a
    ld a, TILE_T
    ld [hli], a
    ld a, TILE_A
    ld [hli], a
    ld a, TILE_R
    ld [hli], a
    ld a, TILE_T
    ld [hli], a

    ret

WriteHighScore4Digits:
    ld a, [wHighThousands]
    call WriteDigitInc

    ld a, [wHighHundreds]
    call WriteDigitInc

    ld a, [wHighTens]
    call WriteDigitInc

    ld a, [wHighOnes]
    call WriteDigitInc

    ret

; ------------------------------------------------------------
; GBC HUD palette attributes
; ------------------------------------------------------------

SetGameplayHUDPalettes:
    ; GBC background tile attributes live in VRAM bank 1.
    ; The normal tile numbers live in VRAM bank 0.
    ld a, 1
    ldh [rVBK], a

    ; Hearts: row 1, columns 1-5, palette 1 red.
    ld hl, _SCRN0 + 32 + 1
    ld b, 5
.hearts:
    ld a, PAL_BG_HEART
    ld [hli], a
    dec b
    jr nz, .hearts

    ; Score: row 1, columns 8-12, palette 2 white/gold.
    ; Icon + four digits.
    ld hl, _SCRN0 + 32 + 8
    ld b, 5
.score:
    ld a, PAL_BG_SCORE
    ld [hli], a
    dec b
    jr nz, .score

    ; Day: row 1, columns 17-18, palette 4 moon/white.
    ; Moon icon + digit.
    ld hl, _SCRN0 + 32 + 17
    ld b, 2
.day:
    ld a, PAL_BG_MOON
    ld [hli], a
    dec b
    jr nz, .day

    ; Ki Wave: row 16, columns 1-2, palette 3 blue.
    ; Ki icon + charge digit.
    ld hl, _SCRN0 + 512 + 1
    ld b, 2
.ki:
    ld a, PAL_BG_KI
    ld [hli], a
    dec b
    jr nz, .ki

    ; Always return to VRAM bank 0 so normal tilemap/tile writes work.
    xor a
    ldh [rVBK], a

    ret

SetTitleScreenPalettes:
    ; GBC BG attributes live in VRAM bank 1.
    ld a, 1
    ldh [rVBK], a

    ; Title emblem: row 3, columns 9-10, blue.
    ld hl, _SCRN0 + 96 + 9
    ld b, 2
.titleEmblem:
    ld a, PAL_BG_KI
    ld [hli], a
    dec b
    jr nz, .titleEmblem

    ; Main title: row 5, columns 6-14, gold.
    ld hl, _SCRN0 + 160 + 6
    ld b, 9
.titleText:
    ld a, PAL_BG_SCORE
    ld [hli], a
    dec b
    jr nz, .titleText

    ; Decorative icons: row 8, columns 7-11.
    ld hl, _SCRN0 + 256 + 7
    ld b, 5
.titleIcons:
    ld a, PAL_BG_KI
    ld [hli], a
    dec b
    jr nz, .titleIcons

    ; Press Start: row 12, columns 4-14, white.
    ld hl, _SCRN0 + 384 + 4
    ld b, 11
.titlePrompt:
    ld a, PAL_BG_MOON
    ld [hli], a
    dec b
    jr nz, .titlePrompt

    xor a
    ldh [rVBK], a

    ret

SetGameOverScreenPalettes:
    ; GBC BG attributes live in VRAM bank 1.
    ld a, 1
    ldh [rVBK], a

    ; Skull/spirit marker: row 2, columns 9-10, red.
    ld hl, _SCRN0 + 64 + 9
    ld b, 2
.gameOverIcon:
    ld a, PAL_BG_HEART
    ld [hli], a
    dec b
    jr nz, .gameOverIcon

    ; GAME OVER: row 4, columns 5-13, red.
    ld hl, _SCRN0 + 128 + 5
    ld b, 9
.gameOverTitle:
    ld a, PAL_BG_HEART
    ld [hli], a
    dec b
    jr nz, .gameOverTitle

    ; SCORE line: row 8, columns 4-15, gold.
    ld hl, _SCRN0 + 256 + 4
    ld b, 12
.gameOverScore:
    ld a, PAL_BG_SCORE
    ld [hli], a
    dec b
    jr nz, .gameOverScore

    ; HIGH line: row 10, columns 5-15, white.
    ld hl, _SCRN0 + 320 + 5
    ld b, 11
.gameOverHigh:
    ld a, PAL_BG_MOON
    ld [hli], a
    dec b
    jr nz, .gameOverHigh

    ; PRESS START: row 14, columns 4-14, blue.
    ld hl, _SCRN0 + 448 + 4
    ld b, 11
.gameOverPrompt:
    ld a, PAL_BG_KI
    ld [hli], a
    dec b
    jr nz, .gameOverPrompt

    xor a
    ldh [rVBK], a

    ret

UpdateHUD:
    ; --------------------------------------------------------
    ; Health - top left.
    ; Draw 5 heart slots. Full hearts are based on wPlayerHealth.
    ; Row 1, columns 1-5.
    ; --------------------------------------------------------
    ld hl, _SCRN0 + 32 + 1
    ld b, 5
    ld c, 1

.healthLoop:
    ld a, [wPlayerHealth]
    cp c
    jr c, .emptyHeart

    ld a, TILE_HEART_FULL
    jr .writeHeart

.emptyHeart:
    ld a, TILE_HEART_EMPTY

.writeHeart:
    ld [hli], a
    inc c
    dec b
    jr nz, .healthLoop


    ; --------------------------------------------------------
    ; Score - top middle.
    ; Icon + four digits.
    ; Row 1, columns 8-12.
    ; --------------------------------------------------------
    ld hl, _SCRN0 + 32 + 8
    ld a, TILE_SCORE_ICON
    ld [hli], a
    call WriteScore4Digits


    ; --------------------------------------------------------
    ; Day - top right.
    ; Moon icon + one digit.
    ; Row 1, columns 17-18.
    ; --------------------------------------------------------
    ld hl, _SCRN0 + 32 + 17
    ld a, TILE_MOON_ICON
    ld [hli], a
    ld a, [wDay]
    call WriteDigitInc


    ; --------------------------------------------------------
    ; Ki Wave - bottom left.
    ; Blue ki icon + charge digit.
    ; Row 16, columns 1-2.
    ;
    ; This moves it one row above the bottom border so it does not
    ; fight with the new arena frame.
    ; --------------------------------------------------------
    ld hl, _SCRN0 + 512 + 1
    ld a, TILE_KI_ICON
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

WriteScore4Digits:
    ld a, [wScoreThousands]
    call WriteDigitInc

    ld a, [wScoreHundreds]
    call WriteDigitInc

    ld a, [wScoreTens]
    call WriteDigitInc

    ld a, [wScoreOnes]
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
    ; Load all 8 background palettes.
    ; 8 palettes * 4 colours * 2 bytes = 64 bytes.
    ld a, $80
    ldh [rBCPS], a
    ld de, BGPalettes
    ld b, 64

.copyBG:
    ld a, [de]
    ldh [rBCPD], a
    inc de
    dec b
    jr nz, .copyBG

    ; Load existing object palettes.
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
; Sound
; ------------------------------------------------------------

InitSound:
    ; Enable the Game Boy sound hardware.
    ld a, $80
    ldh [rNR52], a

    ; Set left/right master volume.
    ld a, $77
    ldh [rNR50], a

    ; Route all sound channels to both speakers.
    ld a, $FF
    ldh [rNR51], a

    call LoadWavePattern

    ret

LoadWavePattern:
    ; Load a soft triangle-ish waveform into Channel 3 wave RAM.
    ; Each byte contains two 4-bit samples.
    ld hl, _AUD3WAVERAM
    ld de, WavePattern
    ld b, 16

.copyWave:
    ld a, [de]
    ld [hli], a
    inc de
    dec b
    jr nz, .copyWave

    ret

PlayKiBlastSfx:
    ; Ki blast: sharp zap + noisy fwoosh.
    ; Channel 1 gives the zappy pitch.
    ; Channel 4 gives the fire/fwoosh texture.

    ; Channel 1 - bright zap
    ld a, $00
    ldh [rNR10], a

    ld a, $40
    ldh [rNR11], a

    ld a, $D2
    ldh [rNR12], a

    ld a, $E0
    ldh [rNR13], a

    ld a, $87
    ldh [rNR14], a


    ; Channel 4 - short noisy fwoosh
    ld a, $10
    ldh [rNR41], a

    ld a, $93
    ldh [rNR42], a

    ld a, $45
    ldh [rNR43], a

    ld a, $80
    ldh [rNR44], a

    ret

PlayEnemyHitSfx:
    ; Lower pop/zap on channel 2.
    ld a, $40
    ldh [rNR21], a

    ld a, $A3
    ldh [rNR22], a

    ld a, $80
    ldh [rNR23], a

    ld a, $86
    ldh [rNR24], a

    ret


PlayKiWaveSfx:
    ; Ki Wave: deeper joom + buzzing forcefield.
    ; Channel 1 gives a heavier pulse.
    ; Channel 4 adds the bzz/static texture.

    ; Channel 1 - low force pulse
    ld a, $00
    ldh [rNR10], a

    ld a, $80
    ldh [rNR11], a

    ld a, $F5
    ldh [rNR12], a

    ld a, $40
    ldh [rNR13], a

    ld a, $86
    ldh [rNR14], a


    ; Channel 4 - forcefield buzz
    ld a, $20
    ldh [rNR41], a

    ld a, $A5
    ldh [rNR42], a

    ld a, $36
    ldh [rNR43], a

    ld a, $80
    ldh [rNR44], a

    ret

PlayPlayerHurtSfx:
    ; Harsh noise burst on channel 4.
    ld a, $1F
    ldh [rNR41], a

    ld a, $F3
    ldh [rNR42], a

    ld a, $5D
    ldh [rNR43], a

    ld a, $80
    ldh [rNR44], a

    ret

PlayStartGameSfx:
    ; Bright start/confirm sound.
    ; Uses channel 1 for a clean upward feeling ping.

    ld a, $00
    ldh [rNR10], a

    ld a, $40
    ldh [rNR11], a

    ld a, $F3
    ldh [rNR12], a

    ld a, $A0
    ldh [rNR13], a

    ld a, $87
    ldh [rNR14], a

    ret

PlayGameOverSfx:
    ; Low thud tone on channel 2.
    ld a, $80
    ldh [rNR21], a

    ld a, $F5
    ldh [rNR22], a

    ld a, $00
    ldh [rNR23], a

    ld a, $84
    ldh [rNR24], a

    ret


; ------------------------------------------------------------
; Music
; ------------------------------------------------------------

StartTitleMusic:
    ld a, 1
    ld [wMusicEnabled], a

    xor a
    ld [wMusicMelodyTimer], a
    ld [wMusicMelodyIndex], a
    ld [wMusicBassTimer], a
    ld [wMusicBassIndex], a
    ld [wMusicDrumTimer], a
    ld [wMusicDrumIndex], a

    ; Enable Channel 3 DAC for bass/wave layer.
    ld a, $80
    ldh [rNR30], a

    ; Channel 3 volume: half.
    ld a, $40
    ldh [rNR32], a

    ret

StartGameOverJingle:
    ld a, 1
    ld [wMusicEnabled], a

    xor a
    ld [wMusicMelodyTimer], a
    ld [wMusicMelodyIndex], a
    ld [wMusicBassTimer], a
    ld [wMusicBassIndex], a
    ld [wMusicDrumTimer], a
    ld [wMusicDrumIndex], a

    ; Enable Channel 3 DAC for bass layer.
    ld a, $80
    ldh [rNR30], a

    ; Channel 3 volume: half.
    ld a, $40
    ldh [rNR32], a

    ret

StartGameplayMusic:
    ld a, 1
    ld [wMusicEnabled], a

    xor a
    ld [wMusicMelodyTimer], a
    ld [wMusicMelodyIndex], a
    ld [wMusicBassTimer], a
    ld [wMusicBassIndex], a
    ld [wMusicDrumTimer], a
    ld [wMusicDrumIndex], a
    ld [wGameplayMusicTempoCounter], a
    ld [wMusicFrameStep], a

    ld a, 1
    ld [wMusicFrameStep], a

    ; Enable Channel 3 DAC for the gameplay pulse/bass.
    ld a, $80
    ldh [rNR30], a

    ; Channel 3 volume: half.
    ld a, $60
    ldh [rNR32], a

    ret

StopMusic:
    xor a
    ld [wMusicEnabled], a
    ld [wMusicMelodyTimer], a
    ld [wMusicMelodyIndex], a
    ld [wMusicBassTimer], a
    ld [wMusicBassIndex], a
    ld [wMusicDrumTimer], a
    ld [wMusicDrumIndex], a

    ld [wGameplayMusicTempoCounter], a
    ld [wMusicFrameStep], a

    ; Silence Channel 2 melody.
    xor a
    ldh [rNR22], a

    ; Disable Channel 3 bass.
    xor a
    ldh [rNR30], a

    ret

UpdateMusic:
    ld a, [wMusicEnabled]
    and a
    ret z

    ld a, [wGameState]

    cp STATE_TITLE
    jr z, .titleMusic

    cp STATE_PLAYING
    jr z, .gameplayMusic

    cp STATE_GAMEOVER
    jr z, .gameOverMusic

    call StopMusic
    ret

.titleMusic:
    call UpdateTitleMelody
    call UpdateTitleBass
    ret

.gameplayMusic:
    call UpdateGameplayTempo
    call UpdateGameplayMelody
    call UpdateGameplayBass
    ret

.gameOverMusic:
    call UpdateGameOverMelody
    call UpdateGameOverBass
    ret

UpdateTitleMelody:
    ld a, [wMusicMelodyTimer]
    and a
    jr z, .nextNote

    dec a
    ld [wMusicMelodyTimer], a
    ret

.nextNote:
    ld a, [wMusicMelodyIndex]
    ld e, a
    ld d, 0

    ld hl, TitleMelodyData
    add hl, de

    ; Byte 0 = frequency low, or $FF to loop.
    ld a, [hli]
    cp $FF
    jr z, .loopSong

    ; Store frequency low.
    ld c, a

    ; Channel 2 duty/length.
    ld a, $80
    ldh [rNR21], a

    ; Channel 2 volume envelope.
    ld a, $84
    ldh [rNR22], a

    ; Frequency low.
    ld a, c
    ldh [rNR23], a

    ; Byte 1 = frequency high + trigger.
    ld a, [hli]
    or $80
    ldh [rNR24], a

    ; Byte 2 = duration.
    ld a, [hli]
    ld [wMusicMelodyTimer], a

    ld a, [wMusicMelodyIndex]
    add 3
    ld [wMusicMelodyIndex], a

    ret

.loopSong:
    xor a
    ld [wMusicMelodyIndex], a
    ld [wMusicMelodyTimer], a
    ret


UpdateTitleBass:
    ld a, [wMusicBassTimer]
    and a
    jr z, .nextNote

    dec a
    ld [wMusicBassTimer], a
    ret

.nextNote:
    ld a, [wMusicBassIndex]
    ld e, a
    ld d, 0

    ld hl, TitleBassData
    add hl, de

    ld a, [hli]
    cp $FF
    jr z, .loopSong

    ; Frequency low on Channel 3.
    ldh [rNR33], a

    ; Frequency high + trigger.
    ld a, [hli]
    or $80
    ldh [rNR34], a

    ; Duration.
    ld a, [hli]
    ld [wMusicBassTimer], a

    ld a, [wMusicBassIndex]
    add 3
    ld [wMusicBassIndex], a

    ret

.loopSong:
    xor a
    ld [wMusicBassIndex], a
    ld [wMusicBassTimer], a
    ret

UpdateGameOverMelody:
    ld a, [wMusicMelodyTimer]
    and a
    jr z, .nextNote

    dec a
    ld [wMusicMelodyTimer], a
    ret

.nextNote:
    ld a, [wMusicMelodyIndex]
    ld e, a
    ld d, 0

    ld hl, GameOverMelodyData
    add hl, de

    ; Byte 0 = frequency low, $FE = stop, $FF = loop.
    ld a, [hli]
    cp $FE
    jr z, .endJingle
    cp $FF
    jr z, .loopSong

    ; Store frequency low.
    ld c, a

    ; Channel 2 duty/length.
    ld a, $80
    ldh [rNR21], a

    ; Softer envelope for a sad game over tone.
    ld a, $84
    ldh [rNR22], a

    ; Frequency low.
    ld a, c
    ldh [rNR23], a

    ; Frequency high + trigger.
    ld a, [hli]
    or $80
    ldh [rNR24], a

    ; Duration.
    ld a, [hli]
    ld [wMusicMelodyTimer], a

    ld a, [wMusicMelodyIndex]
    add 3
    ld [wMusicMelodyIndex], a

    ret

.loopSong:
    xor a
    ld [wMusicMelodyIndex], a
    ld [wMusicMelodyTimer], a
    ret

.endJingle:
    ; Stop melody channel only.
    xor a
    ldh [rNR22], a
    ld [wMusicMelodyTimer], a
    ret


UpdateGameOverBass:
    ld a, [wMusicBassTimer]
    and a
    jr z, .nextNote

    dec a
    ld [wMusicBassTimer], a
    ret

.nextNote:
    ld a, [wMusicBassIndex]
    ld e, a
    ld d, 0

    ld hl, GameOverBassData
    add hl, de

    ; Byte 0 = frequency low, $FE = stop, $FF = loop.
    ld a, [hli]
    cp $FE
    jr z, .endJingle
    cp $FF
    jr z, .loopSong

    ; Channel 3 frequency low.
    ldh [rNR33], a

    ; Channel 3 frequency high + trigger.
    ld a, [hli]
    or $80
    ldh [rNR34], a

    ; Duration.
    ld a, [hli]
    ld [wMusicBassTimer], a

    ld a, [wMusicBassIndex]
    add 3
    ld [wMusicBassIndex], a

    ret

.loopSong:
    xor a
    ld [wMusicBassIndex], a
    ld [wMusicBassTimer], a
    ret

.endJingle:
    ; Disable Channel 3 bass.
    xor a
    ldh [rNR30], a
    ld [wMusicBassTimer], a
    ret

UpdateGameplayMelody:
    ld a, [wMusicMelodyTimer]
    and a
    jr z, .nextNote

    ld b, a
    ld a, [wMusicFrameStep]
    ld c, a

    ld a, b
    cp c
    jr c, .melodyTimerZero

    sub c
    ld [wMusicMelodyTimer], a
    ret

.melodyTimerZero:
    xor a
    ld [wMusicMelodyTimer], a
    ret

.nextNote:
    ld a, [wMusicMelodyIndex]
    ld e, a
    ld d, 0

    ld hl, GameplayMelodyData
    add hl, de

    ; Byte 0 = frequency low, or $FF to loop.
    ld a, [hli]
    cp $FF
    jr z, .loopSong

    ; Store frequency low.
    ld c, a

    ; Channel 2 duty/length.
    ld a, $80
    ldh [rNR21], a

    ; Channel 2 volume envelope.
    ld a, $43
    ldh [rNR22], a

    ; Frequency low.
    ld a, c
    ldh [rNR23], a

    ; Frequency high + trigger.
    ld a, [hli]
    or $80
    ldh [rNR24], a

    ; Duration.
    ld a, [hli]
    ld [wMusicMelodyTimer], a

    ld a, [wMusicMelodyIndex]
    add 3
    ld [wMusicMelodyIndex], a

    ret

.loopSong:
    xor a
    ld [wMusicMelodyIndex], a
    ld [wMusicMelodyTimer], a
    ret


UpdateGameplayBass:
    ld a, [wMusicBassTimer]
    and a
    jr z, .nextNote

    ld b, a
    ld a, [wMusicFrameStep]
    ld c, a

    ld a, b
    cp c
    jr c, .bassTimerZero

    sub c
    ld [wMusicBassTimer], a
    ret

.bassTimerZero:
    xor a
    ld [wMusicBassTimer], a
    ret

.nextNote:
    ld a, [wMusicBassIndex]
    ld e, a
    ld d, 0

    ld hl, GameplayBassData
    add hl, de

    ; Byte 0 = frequency low, or $FF to loop.
    ld a, [hli]
    cp $FF
    jr z, .loopSong

    ; Channel 3 frequency low.
    ldh [rNR33], a

    ; Channel 3 frequency high + trigger.
    ld a, [hli]
    or $80
    ldh [rNR34], a

    ; Duration.
    ld a, [hli]
    ld [wMusicBassTimer], a

    ld a, [wMusicBassIndex]
    add 3
    ld [wMusicBassIndex], a

    ret

.loopSong:
    xor a
    ld [wMusicBassIndex], a
    ld [wMusicBassTimer], a
    ret

UpdateGameplayTempo:
    ; music timers tick down by 1.
    ld a, 1
    ld [wMusicFrameStep], a

    ; Every 5 days, gameplay music gains occasional extra ticks.
    ; This keeps the loop structure intact while subtly increasing tempo.
    ld a, [wDay]

    cp 20
    jr nc, .threshold4

    cp 15
    jr nc, .threshold6

    cp 10
    jr nc, .threshold8

    cp 5
    jr nc, .threshold12

    ret

.threshold12:
    ld b, 12
    jr .tickCounter

.threshold8:
    ld b, 8
    jr .tickCounter

.threshold6:
    ld b, 6
    jr .tickCounter

.threshold4:
    ld b, 4

.tickCounter:
    ld a, [wGameplayMusicTempoCounter]
    inc a
    ld [wGameplayMusicTempoCounter], a

    cp b
    ret c

    ; Counter reached threshold, so this frame gets an extra music tick.
    xor a
    ld [wGameplayMusicTempoCounter], a

    ld a, 2
    ld [wMusicFrameStep], a

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


ClearScreenForGameplay:
    ; Full background clears should happen while the LCD is off.
    ; Keep it off so the arena and GBC palette attributes can be written safely too.

    call WaitVBlank

    xor a
    ldh [rLCDC], a

    call ClearBackgroundMap
    call ClearBackgroundAttributes
    call ClearOAM

    ret


TurnGameplayLCDOn:
    ; LCD on, tile data at $8000, sprites on, BG on.
    ld a, %10010011
    ldh [rLCDC], a
    ret


ClearBackgroundMap:
    ; Clear tile IDs in VRAM bank 0.
    xor a
    ldh [rVBK], a

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


ClearBackgroundAttributes:
    ; Clear GBC BG attributes in VRAM bank 1.
    ; This resets palette attributes back to palette 0.
    ld a, 1
    ldh [rVBK], a

    ld hl, _SCRN0
    ld bc, 1024

.loop:
    xor a
    ld [hli], a
    dec bc
    ld a, b
    or c
    jr nz, .loop

    ; Return to normal tilemap bank.
    xor a
    ldh [rVBK], a

    ret

; ------------------------------------------------------------
; Data
; ------------------------------------------------------------

; ------------------------------------------------------------
; Title music data
; Channel 2 = melody
; Channel 3 = bass pulse
;
; Format:
; db frequencyLow, frequencyHigh, duration
; $FF loops table
; ------------------------------------------------------------

TitleMelodyData:
    ; 256-frame action style title loop.
    ; Each phrase = 64 frames.

    ; Phrase A - main hook
    db $42, $06, 8  ; D4
    db $89, $06, 8  ; F4
    db $D6, $06, 8  ; A4
    db $B2, $06, 8  ; G4
    db $89, $06, 8  ; F4
    db $72, $06, 8  ; E4
    db $42, $06, 16 ; D4

    ; Phrase B - climb
    db $42, $06, 8  ; D4
    db $89, $06, 8  ; F4
    db $B2, $06, 8  ; G4
    db $D6, $06, 8  ; A4
    db $06, $07, 8  ; C5
    db $D6, $06, 8  ; A4
    db $B2, $06, 16 ; G4

    ; Phrase C - higher answer
    db $D6, $06, 8  ; A4
    db $06, $07, 8  ; C5
    db $21, $07, 8  ; D5
    db $06, $07, 8  ; C5
    db $D6, $06, 8  ; A4
    db $B2, $06, 8  ; G4
    db $89, $06, 16 ; F4

    ; Phrase D - resolution
    db $B2, $06, 8  ; G4
    db $D6, $06, 8  ; A4
    db $B2, $06, 8  ; G4
    db $89, $06, 8  ; F4
    db $72, $06, 8  ; E4
    db $89, $06, 8  ; F4
    db $42, $06, 16 ; D4

    db $FF


TitleBassData:
    ; Same total length as melody: 4 x 64 = 256 frames.
    ; Keeps the loop locked together.

    db $83, $04, 64 ; D3
    db $11, $05, 64 ; F3
    db $63, $05, 64 ; G3
    db $83, $04, 64 ; D3

    db $FF

; ------------------------------------------------------------
; Game Over jingle data
; Channel 2 = melody
; Channel 3 = bass
;
; Format:
; db frequencyLow, frequencyHigh, duration
; $FE = end/stop channel
; $FF = loop, not used here
; ------------------------------------------------------------

GameOverMelodyData:
    db $21, $07, 18 ; D5
    db $06, $07, 18 ; C5
    db $D6, $06, 18 ; A4
    db $89, $06, 18 ; F4
    db $42, $06, 36 ; D4
    db $FE

GameOverBassData:
    db $83, $04, 36 ; D3
    db $11, $05, 36 ; F3
    db $83, $04, 54 ; D3
    db $FE

; ------------------------------------------------------------
; Gameplay music data
; Channel 2 = short melody stabs
; Channel 3 = steady pulse/bass
;
; Format:
; db frequencyLow, frequencyHigh, duration
; $FF loops table
; ------------------------------------------------------------

GameplayMelodyData:
    ; 128-frame tense gameplay loop.
    ; More restrained than the title music.
    ; Uses short repeated motifs so it feels tense without distracting.

    ; Phrase 1 - low tension
    db $42, $06, 12 ; D4
    db $72, $06, 8  ; E4
    db $89, $06, 12 ; F4
    db $72, $06, 8  ; E4
    db $42, $06, 24 ; D4

    ; Phrase 2 - slight lift
    db $42, $06, 12 ; D4
    db $89, $06, 8  ; F4
    db $B2, $06, 12 ; G4
    db $89, $06, 8  ; F4
    db $42, $06, 24 ; D4

    ; Phrase 3 - danger peak
    db $89, $06, 12 ; F4
    db $B2, $06, 8  ; G4
    db $D6, $06, 12 ; A4
    db $B2, $06, 8  ; G4
    db $89, $06, 24 ; F4

    ; Phrase 4 - drops back down
    db $72, $06, 12 ; E4
    db $89, $06, 8  ; F4
    db $72, $06, 12 ; E4
    db $42, $06, 8  ; D4
    db $42, $06, 24 ; D4

    db $FF


GameplayBassData:
    ; 256-frame bass loop matching the melody.
    ; Slow pulse keeps pressure without fighting gameplay SFX.

    db $83, $04, 32 ; D3
    db $83, $04, 32 ; D3
    db $11, $05, 32 ; F3
    db $83, $04, 32 ; D3

    db $63, $05, 32 ; G3
    db $11, $05, 32 ; F3
    db $83, $04, 32 ; D3
    db $83, $04, 32 ; D3

    db $FF

WavePattern:
    ; Soft triangle-ish waveform for Channel 3.
    db $01, $23, $45, $67
    db $89, $AB, $CD, $EF
    db $FE, $DC, $BA, $98
    db $76, $54, $32, $10

SpiritsPerDayTable:
    db 3, 5, 9, 15, 24, 36, 52, 72, 96, 120

SECTION "Graphics Data", ROM0

; 4-colour Game Boy Color palettes.
; Each colour is 15-bit BGR, little endian.
BGPalettes:
; BG palette 0: Arena / world grey
    db $6B, $35 ; colour 0: medium grey
    db $4A, $29 ; colour 1: dark grey
    db $21, $14 ; colour 2: darker grey
    db $00, $00 ; colour 3: black

; BG palette 1: Hearts, red
    db $6B, $35 ; colour 0: same floor grey
    db $1F, $00 ; colour 1: dark red
    db $3F, $00 ; colour 2: bright red
    db $3F, $00 ; colour 3: bright red

; BG palette 2: Score, gold/yellow
    db $6B, $35 ; colour 0: same floor grey
    db $FF, $7F ; colour 1: white
    db $FF, $03 ; colour 2: gold/yellow
    db $FF, $03 ; colour 3: gold/yellow

; BG palette 3: Ki icon pink, Ki number pink
    db $6B, $35 ; colour 0: same floor grey
    db $FF, $7F ; colour 1: white
    db $E0, $7F ; colour 2: cyan
    db $1F, $7C ; colour 3: bright blue

; BG palette 4: Moon icon and day number white
    db $6B, $35 ; colour 0: same floor grey
    db $FF, $7F ; colour 1: white
    db $9C, $73 ; colour 2: pale grey
    db $FF, $7F ; colour 3: white

; BG palette 5: spare, same as world
    db $6B, $35
    db $4A, $29
    db $21, $14
    db $00, $00

; BG palette 6: spare, same as world
    db $6B, $35
    db $4A, $29
    db $21, $14
    db $00, $00

; BG palette 7: spare, same as world
    db $6B, $35
    db $4A, $29
    db $21, $14
    db $00, $00

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

; Tile 21: K
    db %10000010, %10000010
    db %10000100, %10000100
    db %10001000, %10001000
    db %11110000, %11110000
    db %10001000, %10001000
    db %10000100, %10000100
    db %10000010, %10000010
    db %10000001, %10000001

; Tile 22: I
    db %01111110, %01111110
    db %00011000, %00011000
    db %00011000, %00011000
    db %00011000, %00011000
    db %00011000, %00011000
    db %00011000, %00011000
    db %00011000, %00011000
    db %01111110, %01111110

; Tile 23: A
    db %00111100, %00111100
    db %01000010, %01000010
    db %10000001, %10000001
    db %11111111, %11111111
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001

; Tile 24: R
    db %11111100, %11111100
    db %10000010, %10000010
    db %10000010, %10000010
    db %11111100, %11111100
    db %10001000, %10001000
    db %10000100, %10000100
    db %10000010, %10000010
    db %10000001, %10000001

; Tile 25: E
    db %11111111, %11111111
    db %10000000, %10000000
    db %10000000, %10000000
    db %11111100, %11111100
    db %10000000, %10000000
    db %10000000, %10000000
    db %10000000, %10000000
    db %11111111, %11111111

; Tile 26: N
    db %10000001, %10000001
    db %11000001, %11000001
    db %10100001, %10100001
    db %10010001, %10010001
    db %10001001, %10001001
    db %10000101, %10000101
    db %10000011, %10000011
    db %10000001, %10000001

; Tile 27: P
    db %11111100, %11111100
    db %10000010, %10000010
    db %10000010, %10000010
    db %11111100, %11111100
    db %10000000, %10000000
    db %10000000, %10000000
    db %10000000, %10000000
    db %10000000, %10000000

; Tile 28: T
    db %11111111, %11111111
    db %00011000, %00011000
    db %00011000, %00011000
    db %00011000, %00011000
    db %00011000, %00011000
    db %00011000, %00011000
    db %00011000, %00011000
    db %00011000, %00011000

; Tile 29: G
    db %00111110, %00111110
    db %01000000, %01000000
    db %10000000, %10000000
    db %10011110, %10011110
    db %10000010, %10000010
    db %10000010, %10000010
    db %01000010, %01000010
    db %00111100, %00111100

; Tile 30: M
    db %10000001, %10000001
    db %11000011, %11000011
    db %10100101, %10100101
    db %10011001, %10011001
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001

; Tile 31: O
    db %00111100, %00111100
    db %01000010, %01000010
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001
    db %01000010, %01000010
    db %00111100, %00111100

; Tile 32: V
    db %10000001, %10000001
    db %10000001, %10000001
    db %10000001, %10000001
    db %01000010, %01000010
    db %01000010, %01000010
    db %00100100, %00100100
    db %00100100, %00100100
    db %00011000, %00011000

; Tile 33: C
    db %00111110, %00111110
    db %01000000, %01000000
    db %10000000, %10000000
    db %10000000, %10000000
    db %10000000, %10000000
    db %10000000, %10000000
    db %01000000, %01000000
    db %00111110, %00111110

; Tile 34: Temple floor
    db %00000000, %00000000
    db %00010000, %00010000
    db %00000000, %00000000
    db %00000010, %00000010
    db %00000000, %00000000
    db %01000000, %01000000
    db %00000000, %00000000
    db %00000100, %00000100

; Tile 35: Cracked temple floor
    db %00000000, %00000000
    db %00010000, %00010000
    db %00110000, %00110000
    db %00011000, %00011000
    db %00001100, %00001100
    db %00000110, %00000110
    db %01000010, %01000010
    db %00000000, %00000000

; Tile 36: Horizontal border
    db %11111111, %11111111
    db %10000001, %10000001
    db %10111101, %10111101
    db %10100101, %10100101
    db %10100101, %10100101
    db %10111101, %10111101
    db %10000001, %10000001
    db %11111111, %11111111

; Tile 37: Vertical border
    db %11111111, %11111111
    db %10011001, %10011001
    db %10011001, %10011001
    db %10011001, %10011001
    db %10011001, %10011001
    db %10011001, %10011001
    db %10011001, %10011001
    db %11111111, %11111111

; Tile 38: Border corner
    db %11111111, %11111111
    db %10000001, %10000001
    db %10111101, %10111101
    db %10100101, %10100101
    db %10100101, %10100101
    db %10111101, %10111101
    db %10000001, %10000001
    db %11111111, %11111111

; Tile 39: Full heart
    db %00000000, %00000000
    db %01100110, %01100110
    db %11111111, %11111111
    db %11111111, %11111111
    db %11111111, %11111111
    db %01111110, %01111110
    db %00111100, %00111100
    db %00011000, %00011000

; Tile 40: Empty heart
    db %00000000, %00000000
    db %01100110, %00000000
    db %10011001, %00000000
    db %10000001, %00000000
    db %10000001, %00000000
    db %01000010, %00000000
    db %00100100, %00000000
    db %00011000, %00000000

; Tile 41: Score icon / shrine coin
    db %00011000, %00011000
    db %00111100, %00111100
    db %01111110, %01111110
    db %01100110, %01100110
    db %01111110, %01111110
    db %00111100, %00111100
    db %00011000, %00011000
    db %00000000, %00000000

; Tile 42: Ki wave icon
    db %00011000, %00011000
    db %00111100, %00111100
    db %01111110, %01111110
    db %11111111, %11111111
    db %01111110, %01111110
    db %00111100, %00111100
    db %00011000, %00011000
    db %00100100, %00100100

; Tile 43: Moon icon
    db %00011100, %00011100
    db %00111110, %00111110
    db %01111000, %01111000
    db %01110000, %01110000
    db %01110000, %01110000
    db %01111000, %01111000
    db %00111110, %00111110
    db %00011100, %00011100

; Tile 44: Title emblem / shrine ki mark
    db %00011000, %00011000
    db %00111100, %00111100
    db %01111110, %01111110
    db %11111111, %11111111
    db %10111101, %10111101
    db %00011000, %00011000
    db %00100100, %00100100
    db %01000010, %01000010

; Tile 45: Game over skull / fallen spirit
    db %00111100, %00111100
    db %01111110, %01111110
    db %11011011, %11011011
    db %11111111, %11111111
    db %10100101, %10100101
    db %11111111, %11111111
    db %01100110, %01100110
    db %00111100, %00111100

SpriteTilesEnd:
