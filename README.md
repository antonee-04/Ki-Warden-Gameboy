# Ki-Warden-Gameboy

Ki Warden is a small survival shooter developed for the Nintendo Game Boy Colour using RGBDS assembly. The project was created for the Targeting Platforms module and focuses on programming for a constrained handheld platform rather than using a modern game engine.

The game places the player in control of a Ki Warden fighting waves of hostile spirits inside a temple-style arena. The project demonstrates direct Game Boy hardware interaction, including joypad input, sprite/OAM handling, VRAM tile loading, background tilemaps, Game Boy Colour palette setup, sound register control, and frame-safe updating through the VBlank period.

## Platform

- Target platform: Nintendo Game Boy Colour
- Language: RGBDS assembly
- Build tools: RGBDS
- Output format: `.gbc` ROM
- Main source file: `main.asm`

## Current Features

### Core Gameplay

- Title screen
- Temple-style gameplay arena
- Game state handling for title, gameplay, and game-over states
- Player movement using the Game Boy D-Pad
- Projectile shooting
- Ki wave ability with limited charges and cooldown behaviour
- Player health, knockback, flashing feedback, and temporary invulnerability after taking damage
- Score tracking up to 999999
- High score display on the game-over screen
- Day progression up to 99 days
- Extra Ki wave charge gained every 10 days
- Game-over and restart flow

### Enemy Systems

- Chasing spirit enemy type
- Wandering spirit enemy type
- Phase spirit enemy type introduced later in progression
- Wandering spirits move with X/Y velocity and bounce around the play area
- Phase spirits teleport near the player on a timer
- Four active enemy slots
- Day-based enemy scaling
- Active enemy cap to reduce performance cost
- Enemy collision with the player
- Projectile collision with enemies
- Ki wave collision with enemies

### Presentation and Feedback

- Tilemap-based title screen
- Tilemap-based game-over screen
- Temple arena background using custom background tiles
- HUD icons for health, score, day, and Ki wave charges
- Game Boy Colour background palette attributes for clearer HUD and arena presentation
- Sound effects for shooting, Ki wave, enemy hits, player damage, start/restart, and game over
- Title, gameplay, and game-over music
- Gameplay music speed increases as the day count rises

### Platform-Specific Implementation

- RGBDS assembly implementation
- Direct use of Game Boy hardware registers
- Joypad input through `rP1`
- Sprite drawing through OAM
- Manual sprite tile loading into VRAM
- Background tilemap drawing through VRAM
- Game Boy Colour palette setup
- Palette attributes written through CGB VRAM bank 1 using `rVBK`
- VBlank-aware main loop
- Byte-sized WRAM state variables for gameplay data
- Limited enemy count and simple movement behaviours to suit Game Boy constraints
- Sound and music produced through Game Boy sound registers rather than audio files

## Controls

| Button | Action |
| --- | --- |
| D-Pad | Move player |
| A | Fire Ki projectile |
| B | Use Ki wave |
| Start | Start / restart |

## Building the Project

The project can be built using RGBDS.

```bash
rgbasm -o main.o main.asm
rgblink -o KiWarden.gbc main.o
rgbfix -v -C -p 0 KiWarden.gbc
```

Alternatively, run the provided build script:

```bash
./build.sh
```

The script assembles main.asm, links the object file into KiWarden.gbc, runs rgbfix, and stops if any stage fails.

## Development History

The GitHub commit history does not show the full timeline of development because the repository was created near the end of the project to organise the final assessment submission and track the final stages of work.

Earlier development was completed locally through iterative versions of the RGBDS assembly files. A separate development diary has been produced for assessment, containing the early local development diary followed by the GitHub commit history from the point the repository was created.

The diary records the main technical milestones, implementation decisions, and platform-specific constraints encountered during development.
