;----- Create iNES Header -----;
	.inesprg 1	; 1x 16KB PRG Code
	.ineschr 1	; 1x 8KB CHR Data
	.inesmap 0	; mapper 0 = NROM, no bank swapping
	.inesmir 1	; background mirroring
;----- Declare Variables -----;
	.rsset $0000
Timer		.rs 1		; Holds the 'boolean' for determining if a move is allowable.
						; This is used as a mechanism to limit the times the player
						; may actually move so the game doesn't play too fast.
						; 0 == Wait for next NMI; 1 == Loop iteration allowable
SelectDown	.rs 1		; 0 == no; 1 == yes
StartDown	.rs 1		; 0 == no; 1 == yes
Paused		.rs 1		; Holds the 'boolean' for determining if a move is allowable.
						; Relies on the standard 'Press Start' to pause/unpause a game
						; 0 == Playing; 1 == Paused
PlayerX		.rs 1		; Holds the player's horizontal position
PlayerY		.rs 1		; Holds the player's vertical position
PlayerMissileFiring .rs 1	; Holds the 'boolean' for determining if the player can fire a new missile
						; 0 == Can't Fire; 1 == Can Fire
PlayerMissileX	.rs 1	; Holds the missile's horizontal position
PlayerMissileY	.rs 1	; Holds the missiles's vertical position
PlayerMissileID	.rs 1	; Holds the ID of the missle:
						; 0) Standard Missile - Inifinite Supply
						; 1) EMP - 1 per round
						; 2) Tracker Missile - 2 per round
PlayerLives		.rs 1	; Holds the number of lives the player currently has. Starts at 3
PlayerScore		.rs 1	; Holds the player's current score
PlayerScoreH	.rs 1	; Holds the player's number of 100s in score
TrackerCount	.rs	1	; Hold a space for number of Tracker Missiles (2)
EMPCount		.rs 1	; Hold a space for number of EMP's (1)
EMPTimer		.rs 1	; Holds a value between 0-250
						; The value is incremented by NMI. When a player
						; Fires an EMP, it will explode as soon as it becomes less
						; than the value.
	;-- Enemy Data --;
EnemyLeftX		.rs 1	; Holds the 'X' position that is the left edge of the ship
EnemyRightX		.rs 1	; Holds the 'X' position that is the right edge of the ship
EnemyBottomY	.rs 1	; Holds the 'Y' position that is the edge closest to the player's ship
EnemyTopY		.rs 1	; Holds the 'Y' position that is the edge farthest from the player's ship
EnemyLife		.rs 1	; Holds the amount of life. Starts off as 5, once it reaches 0, the ship is destroyed.
ThreatLevel		.rs 1	; Holds the value containing the AI's current threat level
						; 0 = No Missiles
						; 1 = Missile Fired -- Increased alert
						; 2 = Missile Mid-Field	-- Begin evasive actions
						; 3 = Missile Collision Imminent -- Throw out flak rounds
;----- Begin Main Code -----;
	.bank 0
	.org $C000
RESET:
	SEI					; Disable IRQs
	CLD					; Disable decimal mode
	LDX #$40
	STX $4017			; Disable APU frame IRQ
	LDX #$FF
	TXS					; Set up stack
	INX					; X = 0
	STX $2000			; Disable NMI
	STX $2001			; Disable renderings
	STX $4010			; Disable DMC IRQs

VBlankWait:
	BIT $2002
	BPL VBlankWait

ClrMem:
	LDA #$00
	STA $0000, x
	STA $0100, x
	STA $0200, x
	STA $0300, x
	STA $0400, x
	STA $0500, x
	STA $0600, x
	STA $0700, x
	LDA #$FE
	STA $0200, x
	INX
	BNE ClrMem

VBlankWait2:
	BIT $2002
	BPL VBlankWait2

;----- Load Palette Data -----;
	LDX $2002			; Read the PPU status to reset the latch
	LDA #$3F
	STA $2006			; Set the low byte $3F(00) of the address
	LDA #$00
	STA $2006			; Set the high byte of $(3F)00 of the address
	LDX #$00
LoadPalette:
	LDA Palette, x
	STA $2007
	INX
	CPX #$20
	BNE LoadPalette

;----- Start Menu -----;
StartMenu:
	;-- Clear Background --;
	LDA #$20
	STA $2006			; Write high byte $(20)00 of address
	LDA #$00
	STA $2006			; Write low byte $20(00) of address
	LDA #$24			; Assign A with the blank tile value
	LDX #$00			; Clear X
	LDY #$00			; Clear Y
StartMenu_ClearBackground:
	STA $2007			; Write blank tile to $2007 (background)
	INX
	CPX #$F0			; Compare X with 240
	BNE StartMenu_ClearBackground	; If not 240, keep going
	LDX #$00			; Clear X
	INY
	CPY #$04			; Compare Y with 4
	BNE StartMenu_ClearBackground	; If not 4, keep going

	;-- Load 'PRESS START' --;
	LDA #$22
	STA $2006			; Write high byte $(22)EB of address
	LDA #$EB
	STA $2006			; Write low byte $22(EB) of address
	LDX #$00
StartMenu_PressStart:
	LDA BackgroundStartMenu, x	; Get the text value
	STA $2007			; Write it to the background
	INX
	CPX #$0B			; Compare X to 11
	BNE StartMenu_PressStart	; if X isn't 11, keep going

	LDA #$00
	STA $2005			; Write 0 to $2005 twice to reset the X/Y
	STA $2005			; Coordinates to 0, 0

	LDA #%10010000		; Enable NMI, sprites from Pattern Table 0
	STA $2000
	LDA #%00011110		; Enable sprites
	STA $2001

StartMenu_ReadControllers
	LDA #$01
	STA $4016
	LDA #$00
	STA $4016			; Tell controllers to latch buttons

	LDA $4016			; A
	LDA $4016			; B
	LDA $4016			; Select
	LDA $4016			; Start
	AND #$01
	BEQ StartMenu_ReadControllers
StartMenuEnd:
;----- Start Menu Over -----;

	;----- Load Sprite Data -----;
	LDX #$00
LoadSprite:
	LDA Sprite, x
	STA $0200, x
	INX
	CPX #$4C
	BNE LoadSprite

;----- Initialize Variables -----;
	LDA #$00
	STA Paused			; Starts off the game as unpaused
	STA PlayerMissileX	; Load in a default value
	STA PlayerMissileY	; Load in a default value
	STA PlayerMissileID	; Starts off with the standard missile selected
	STA EMPTimer		; Start off the 'timer' at 0
	STA PlayerScore		; Start off the player with no points
	STA PlayerScoreH	; Start off the player with no points in the 100s column
	LDA #$01
	STA PlayerMissileFiring	; Missile is not firing, missile can be fired
	STA EMPCount		; Allocate 1 EMP
	STA StartDown		; Starts off as start as pressed to compensate for pressing at the title screen
	LDA #$02
	STA TrackerCount	; Allocate 2 Tracker Missiles
	LDA #$03
	STA PlayerLives		; Start of the amount of lives at 3
	LDA #$05
	STA EnemyLife		; Start off the enemy with 5 hp
	LDA #$70
	STA PlayerX			; Set ship's 'X' position to #$80
	LDA #$C0
	STA PlayerY			; Set ship's 'Y' position to #$C0
	LDA #$70
	STA EnemyLeftX		; Set leftmost edge as 70
	LDA #$88
	STA EnemyRightX		; Set rightmost edge as 90
	LDA #$20
	STA EnemyBottomY	; Set bottom edge as 20
	LDA #$10
	STA EnemyTopY		; Set top edge as 10

PreMain:
	LDA #$00
	STA $2001			; Write 00 to $2001 to turn off background rendering

;----- Load Background -----;
	LDA $2002			; Read PPU status to reset the latch
	LDA #$20
	STA $2006			; Write the high byte $(20)00 of address
	LDA #$00
	STA $2006			; Write the low byte of $20(00) of address
	LDX #$00
	LDY #$00
LoadBackground:
	LDA Background, x
	STA $2007
	INX
	CPX #$20
	BNE LoadBackground
	INY
	LDX #$00
	CPY #$1E
	BNE LoadBackground

;----- Load Text -----;
	;-- Load 'SCORE' --;
	LDA #$20
	STA $2006			; Write high byte $(20)5A of address
	LDA #$5A
	STA $2006			; Write low byte $20(59) of address
						; Can now write 'SCORE' in nametable
	LDX #$00
LoadScore:
	LDA BackgroundScore, x
	STA $2007
	INX
	CPX #$05
	BNE LoadScore

	;-- Load 'LIVES' --;
	LDA #$20
	STA $2006			; Write high byte $(20)9A of address
	LDA #$FA
	STA $2006			; Write low byte $20(9A) of address
						; Can now write 'LIVES' in nametable
	LDX #$00
LoadLives:
	LDA BackgroundLives, x
	STA $2007
	INX
	CPX #$05
	BNE LoadLives

	;-- Load '03' Lives Numbering --;
	LDA #$21
	STA $2006			; Write the high byte $(21)3D of address
	LDA #$3D
	STA $2006			; Write the low byte $21(3D) of address
	LDX #$00
	STX $2007			; Set first number as 0
	LDX #$03
	STX $2007			; Set second number as 3

	;-- Load Missile Icons --;
	LDA #$22
	STA $2006			; Write high byte $(22)9A of address
	LDA #$9A
	STA $2006			; Write low byte $22(9A) of address
						; Missile icons can now be displayed
	LDX #$00
LoadMissiles:
	LDA BackgroundMissiles, x
	STA $2007
	INX
	CPX #$05
	BNE LoadMissiles

	;-- Load Missile Numbers --;
	LDA #$22
	STA $2006			; Write high byte $(22)7A of address
	LDA #$7A
	STA $2006			; Write low byte $22(7A) of address
	LDX #$00
LoadNumbers:
	LDA BackgroundMissileNumbers, x
	STA $2007
	INX
	CPX #$05
	BNE LoadNumbers



	JSR SR_MissileSelect	; Draw the current missile selector
	JSR SR_UpdateScore		; Write the current score value

	LDA #$00
	STA $2005			; Write 0 to $2005 twice to reset the X/Y
	STA $2005			; Coordinates to 0, 0

	LDA #%00011110		; Enable NMI, sprites
	STA $2001

;----- Game Loop -----;
	.include "fighter_main.asm"	; Include the core game file
;----- Subroutines -----;
	.include "fighter_sr.asm"	; Include the subroutines file

;----- Start of NMI -----;
NMI:
	;-- Load Sprite Data --;
	LDA #$00
	STA $2003			; Set the low byte $02(00) of the RAM address
	LDA #$02
	STA $4014			; Set the high byte $(02)00 of the RAM address
	LDA #$00
	STA $2005			; Set the X and Y coordinates to be 0
	STA $2005			; meaning we have no scrolling

	LDA #$01
	STA Timer			; Set the flag to allow for another iteration through the current module

	INC EMPTimer		; Increase the 'random' location for the EMP detonation

	RTI
;----- End of NMI -----;

;----- Store Generic Data -----;
	.bank 1
	.org $E000
Palette:
	.db $0F,$2D,$07,$30, $0F,$0F,$0F,$30, $0F,$0F,$0F,$30, $0F,$0F,$0F,$30	; Background Palette
	.db $0F,$2D,$07,$30, $0F,$0F,$0F,$30, $0F,$0F,$0F,$30, $0F,$0F,$0F,$30	; Sprite Palette

Sprite:
	;	Vert  Tile#  Attr  Horiz

	;--- Player Gun Ship ---;
	.db $C0, $00, $00, $70	; top-left wing
	.db $C0, $01, $00, $78	; top-middle gun
	.db $C0, $02, $00, $80	; top-right wing
	.db $C8, $10, $00, $70	; bottom-left wing
	.db $C8, $11, $00, $78	; bottom-middle gun
	.db $C8, $12, $00, $80	; bottom-right wing

	;-- Player Missiles --;
	.db $00, $0F, $00, $00	; Starts off as standard missile
							; $0219 starts as 0F to make it invisible
							; $0219 holds tile number
							; Will be changed based on what missile is selected

	;-- Enemy Gun Platform --;
	.db $10, $04, $00, $70
	.db $10, $05, $00, $78
	.db $10, $06, $00, $80
	.db $10, $07, $00, $88

	.db $18, $14, $00, $70
	.db $18, $15, $00, $78
	.db $18, $16, $00, $80
	.db $18, $17, $00, $88

	.db $20, $24, $00, $70
	.db $20, $25, $00, $78
	.db $20, $26, $00, $80
	.db $20, $27, $00, $88

Attribute:
	.db %00000000

Background:
	;-- Standard row --;
	.db $24, $24, $24, $24, $24, $24, $24, $40, $24, $24, $24, $24, $24, $24, $24, $24
	.db $24, $24, $24, $24, $24, $24, $24, $24, $50, $24, $24, $24, $24, $24, $24, $24
BackgroundScore:
	;-- 'SCORE' Text --;
	.db $1C, $0C, $18, $1B, $0E	; 1C(S), 0C(C), 18(O), 1B(R), 0E(E)
BackgroundLives:
	;-- 'LIVES' Text --;
	.db $15, $12, $1F, $0E, $1C	; 15(L), 12(I), 1F(V), 0E(E), 1C(S)
BackgroundPaused:
	;-- 'PAUSED' Text --;
	.db $19, $0A, $1E, $1C, $0E, $0D	; 19(P), 0A(A), 1E(U), 1C(S), 0E(E), 0D(D)
BackgroundMissiles:
	;-- 3 Missile Icons --;
	.db $43, $24, $44, $24, $45	; $24 is a blank filler tile to space icons
BackgroundMissileNumbers:
	;-- Tells Missile Count --;
	.db $2A, $24, $01, $24, $02	; (Infinite Symbol), blank, 1, blank, 2
BackgroundStartMenu:
	;-- Tells Menu Options --;
	.db $19,$1B,$0E,$1C,$1C,	$24,	$1C,$1D,$0A,$1B,$1D	; P(19), R(1B), E(0E), S(1C), S(1C), _(24, blank tile), S(1C), T(1D), A(0A), R(1B), T(1D)
BackgroundNewRound:
	;-- Tells New Round --;
	.db $17,$0E,$20,	$24,	$1B,$18,$1E,$17,$0D	; N(17),E(0E),W(20) _(24, blank tiles), R(1B),O(18),U(1E),N(17),D(0D)

;----- Setup Addresses -----;
	.org $FFFA
	.dw NMI				; NMI is once per frame. Processor jumps to NMI
	.dw RESET			; When the processor first turns on or is reset, it jumps to RESET
	.dw 0				; Disable external interrupt IRQ

;----- Store Grahpic Data -----;
	.bank 2
	.org $0000
	.incbin "fighter.chr"