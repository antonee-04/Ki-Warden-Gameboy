# Ki-Warden-Gameboy



Ki Warden is a small survival shooter developed for the Nintendo Game Boy Colour using RGBDS assembly. The project was created for the Targeting Platforms module and focuses on programming for a constrained handheld platform rather than using a modern game engine.



The game places the player in control of a Ki Warden fighting waves of hostile spirits. The project demonstrates direct Game Boy hardware interaction, including joypad input, sprite/OAM handling, VRAM tile loading, palette setup, and frame-safe updating through the VBlank period.



**Platform**



\- Target platform: Nintendo Game Boy Colour

\- Language: RGBDS assembly

\- Build tools: RGBDS

\- Output format: `.gbc` ROM

\- Main source file: `main.asm`



**Current Features**



**Core Gameplay**



\- Title screen

\- Game state handling for title, gameplay, and game-over states

\- Player movement using the Game Boy D-Pad

\- Projectile shooting

\- Ki wave ability with limited charges/cooldown behaviour

\- Player health and temporary invulnerability after taking damage

\- Score tracking

\- Game-over and restart flow



**Enemy Systems**



\- Chasing spirit enemy type

\- Wandering spirit enemy type

\- Wandering spirits move with X/Y velocity and bounce around the play area

\- Four active enemy slots

\- Day-based enemy scaling

\- Active enemy cap to reduce performance cost

\- Enemy collision with the player

\- Projectile collision with enemies

\- Ki wave collision with enemies



**Platform-Specific Implementation**



\- RGBDS assembly implementation

\- Direct use of Game Boy hardware registers

\- Joypad input through `rP1`

\- Sprite drawing through OAM

\- Manual sprite tile loading into VRAM

\- Game Boy Colour palette setup

\- VBlank-aware main loop

\- Byte-sized WRAM state variables for gameplay data

\- Limited enemy count and simple movement behaviours to suit Game Boy constraints



**Controls**



| Button | Action |

| D-Pad | Move player |

| A | Fire Ki projectile |

| B | Use Ki wave |

| Start | Start / restart |



**Building the Project**



The project can be built using RGBDS.



```bash

rgbasm -o main.o main.asm

rgblink -o KiWarden.gbc main.o

rgbfix -v -C -p 0 KiWarden.gbc



## **Development History Note**



The GitHub commits for this repository do not show the full timeline of development. The repository was created near the end of the project to organise the final assessment submission and to track the final stages of work.



Earlier development was completed locally through iterative versions of the RGBDS assembly files. A development diary was kept during development, and I have pasted it below to show the main technical milestones, implementation decisions, and periods of work completed before the GitHub repository was created.



From the point the repository was created, the remaining changes are evidenced through the GitHub commit history.



### Development Diary

5 March 2026 - Initial RGBDS Setup (After being told GBDK was not hardware focused enough as a development tool)



Set up the basic RGBDS project structure.

Created the main assembly source file.

Added the Game Boy ROM header and entry point.

Added hardware.inc for Game Boy hardware register definitions.

Created an initial build process for assembling, linking, and fixing the ROM.

Updated the build script to output KiWarden.gbc.



7 March 2026 - Hardware Initialisation



Added start-up code for the Game Boy program.

Waited for VBlank before turning the LCD off for safe graphics setup.

Set up basic Game Boy palettes.

Added Game Boy Colour palette support.

Loaded sprite tile data into VRAM.

Cleared OAM before gameplay began.



10 March 2026 - Player Movement



Added player position variables in WRAM.

Implemented joypad input reading through the Game Boy joypad register.

Added D-Pad movement.

Added player direction tracking so projectiles could fire in the correct direction.

Added screen boundary checks to keep the player inside the play area.



13 March 2026 - Basic Gameplay State



Added a title state.

Added a gameplay state.

Added initial game state transitions.

Added player health.

Added basic restart behaviour.



20 March 2026 - Projectile System



Added projectile position, direction, and active state variables.

Added A-button projectile firing.

Added projectile movement in four directions.

Added projectile deactivation when leaving the play area.

Limited the projectile system to a single active projectile to keep the implementation efficient for the platform.



25 March 2026 - First Spirit Enemy



Added the first spirit enemy behaviour.

Implemented enemy position and active-state variables.

Added movement toward the player.

Added simple collision between enemies and the player.

Added player damage and temporary invulnerability.



29 March 2026 - Combat and Score



Added projectile collision against enemies.

Added enemy defeat behaviour.

Added score tracking using low/high score bytes.

Added basic HUD update logic.

Added dirty HUD updating so the HUD only refreshes when needed.



32 March 2026 - Ki Wave Ability



Added the Ki wave as a secondary attack.

Added Ki wave charge tracking.

Added Ki wave timer/cooldown behaviour.

Added collision checks between the Ki wave and active enemies.

Balanced the ability as a stronger but more limited option.



28 March 2026 - Day Progression



Added a day counter.

Added spirits remaining for the current day.

Added a spirits per day table.

Added logic to progress to the next day after spirits are cleared.

Increased enemy pressure as the day count rises.



31 March 2026 - Multiple Enemy Slots



Expanded the enemy system to support four active enemy slots.

Added separate WRAM variables for each enemy slot.

Added active enemy counting.

Added an active enemy cap based on the current day.

Added spawn to cap logic so the game can increase pressure without flooding the screen.



April 2026 - Documentation Pause

Development was paused due to mental health issues and in order to focus on other module deadlines like my final year project work.

The project was left with the core Game Boy gameplay loop working, including movement, shooting, enemies, score, health, and day progression.



1 May 2026 - Performance Tuning



Returned to Ki Warden to prepare for final assessment.

Reduced enemy update cost by limiting active enemies.

Tuned enemy movement timers.

Adjusted spawning so enemies appear gradually rather than all at once.

Kept enemy logic simple to better suit the Game Boy's limited processing budget.



5 May 2026 - Project Revision



Reviewed the project against the Targeting Platforms assessment brief.

Identified the need to better evidence Game Boy specific programming decisions.

Started organising the project for GitHub and technical documentation.



9 May 2026 - Second Enemy Type



Added a wandering spirit enemy type.

Added enemy type variables for each enemy slot.

Added X/Y velocity variables for wandering spirits.

Implemented bouncing movement against play-area boundaries.

Kept wandering spirits at a similar speed to normal spirits to avoid unfair difficulty spikes.



10 May 2026 - Enemy Variety and Balance



Added logic so Day 1 uses chasing spirits only.

Added mixed enemy types from Day 2 onward.

Tuned wandering spirit movement speed.

Adjusted enemy behaviour so the two spirit types feel different while remaining simple enough for the hardware.



11 May 2026 - HUD and Feedback Improvements



Improved HUD handling for health, day, score, and Ki wave information.

Added tile data for letters and numbers used by the HUD.

Kept HUD updates controlled through a dirty flag to avoid unnecessary updates every frame.



14 May 2026 - Build and Submission Preparation



Added error checks to the build script for rgbasm, rgblink, and rgbfix.

Prepared project files for GitHub upload.

Began writing the README and technical documentation.



14 May 2026 - GitHub Repository Created



Created the Ki-Warden-Gameboy GitHub repository.

Imported the existing RGBDS project files.

Added documentation explaining that earlier development was completed locally.

Began using GitHub commit history for remaining changes.

