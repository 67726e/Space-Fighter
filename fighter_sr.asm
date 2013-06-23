;-- Move Player Ship --;
SR_Player:
	;-- Update Horizontal Position --;
	LDA PlayerX			; Get ship's horizontal marker
	STA $0203			; Write the first third
	STA $020F			; Top & bottom sections
	CLC
	ADC #$08			; Add 8 for next third
	STA $0207			; Write the second third
	STA $0213			; Top & bottom sections
	CLC
	ADC #$08			; Add 8 for final third
	STA $020B			; Write final third section
	STA $0217			; Both top and bottom sections
	;-- Update Vertical Position --;
	LDA PlayerY			; Get the ship's vertical position
	STA $0200			; Update the top row
	STA $0204			; Of the ship
	STA $0208
	CLC
	ADC #$08			; Add 8 to the vertical postion
	STA $020C			; Update the bottom row
	STA $0210			; Of the ship
	STA $0214
	RTS					; Ship is now moved in RAM (PPU still needs to update via NMI)



	;-- Move Enemy Ship --;
SR_Enemy:
	LDA EnemyLeftX
	STA $021F			; Top-Left
	STA $022F			; Middle-Left
	STA $023F			; Bottom-Left
	CLC
	ADC #$08
	STA $0223			; Top-MidLeft
	STA $0233			; Middle-MidLeft
	STA $0243			; Bottom-MidLeft
	CLC
	ADC #$08
	STA $0227			; Top-MidRight
	STA $0237			; Middle-MidRight
	STA $0247			; Bottom-MidRight
	CLC
	ADC #$08
	STA $022B			; Top-Right
	STA $023B			; Middle-Right
	STA $024B			; Bottom-Right
	RTS					; Ship has been moved, carry on



	;-- Show/Hide 'PAUSED' Text --;
SR_Pause:
	LDA Paused			; Get paused 'boolean'
	BEQ SR_UnPause		; If we are unpaused, goto unpause function
	LDA #$21
	STA $2006			; Write high byte $(21)ED of address
	LDA #$ED
	STA $2006			; Write low byte $21(ED) of address
	LDX #$00
SR_LoadPaused:
	LDA BackgroundPaused, x	; Get letter tiles for 'PAUSED'
	STA $2007			; Write it to the PPU via $2007
	INX
	CPX #$06			; If x == 6, we are done here
	BNE SR_LoadPaused	; Otherwise keep writing
	LDA #$00			; Load 0
	STA $2005			; Write 0000 to $2005 to reset
	STA $2005			; the X,Y coordinates
	RTS					; Subroutine is over
SR_UnPause:
	LDA #$21
	STA $2006			; Write high byte $(21)ED of address
	LDA #$ED
	STA $2006			; Write low byte $21(ED) of address
	LDX #$00
	LDA #$24			; Load a as the blank tile
SR_RemovePaused:
	STA $2007			; Write blank tile to background
	INX
	CPX #$06			; If x == 6 we are done
	BNE SR_RemovePaused
	LDA #$00			; Load 0
	STA $2005			; Write 0000 to $2005 to reset
	STA $2005			; the X,Y coordinates
	RTS					; Subroutine is over

	;-- Move Missile --;
SR_Missile:
	LDA PlayerMissileY	; Get vertical position
	STA $0218			; Write new position
	LDA PlayerMissileX	; Get horizontal position
	STA $021B			; Write new position
	RTS					; Missile now moved forward in RAM (PPU needs to update via NMI)



	;-- Change Selected Missile --;
SR_MissileSelect:
	LDX #$24			; Load X with the blank tile
	LDY #$53			; Load Y with the underline tile
	LDA PlayerMissileID
	BEQ SR_Missile1		; If PlayerMissileID is 0, goto first missile
	CMP #$01
	BEQ SR_Missile2		; If PlayerMissileID is 1, goto second missile
	JMP SR_Missile3		; Else it is the third missile (2)
SR_Missile1:
	LDA #$22
	STA $2006			; Write high byte $(22)BD of address
	LDA #$BE
	STA $2006			; Write low byte $22(BD) of address
	STX $2007			; Clear 3rd missile selector
	LDA #$22
	STA $2006			; Write high byte $(22)BA of address
	LDA #$BA
	STA $2006			; Write low byte $22(BA) of address
	STY $2007			; Set selector for 1st missile
	RTS
SR_Missile2:
	LDA #$22
	STA $2006			; Write high byte $(22)BA of address
	LDA #$BA
	STA $2006			; Write low byte $22(BA) of address
	STX $2007			; Clear 1st missile selector
	LDA #$22
	STA $2006			; Write the high byte $(22)BC of address
	LDA #$BC
	STA $2006			; Write the low byte $22(BC) of address
	STY $2007			; Set the selector for the 2nd missile
	RTS
SR_Missile3:
	LDA #$22
	STA $2006			; Write the high byte $(22)BC of address
	LDA #$BC
	STA $2006			; Write the low byte $22(BC) of address
	STX $2007			; Clear 2nd missile selector
	LDA #$22
	STA $2006			; Write high byte $(22)BD of address
	LDA #$BE
	STA $2006			; Write low byte $22(BD) of address
	STY $2007			; Set the selector for the 3rd missile
	RTS



	;-- Check Missile Collision --;
SR_MissileCheck:
	LDA PlayerMissileFiring	; Check if a missile is being fired
	BEQ SR_MissileCheckCont	; If a missile is being fired (0) then we are done checking for collision
	RTS
SR_MissileCheckCont:
	LDA PlayerMissileY	; Get the missile's vertical position
	CMP EnemyBottomY	; Compare the missile position to the ship's position
	BCS SR_MissileCheckEnd	; If the missile value is greater than (farter down) the ship's, we don't have a possible collision
	LDA PlayerMissileX	; Get the missile's horizontal position
	CLC
	ADC #$04			; Add 4 to the missile's x position to account for the blank spaces so proper contact is made with the left edge
	CMP EnemyLeftX		; Compare the missile to the enemy ship's leftmost edge
	BCC SR_MissileCheckEnd	; If the missile's position is less than (further to the left) we don't have a collision
	SEC
	SBC #$08			; Add 8 to compensate for the right edge of the missile
	CMP EnemyRightX		; Compare the missile to the enemy ship's rightmost edge
	BCS SR_MissileCheckEnd	; If the missile's position is greather than the rightmost edge, we also don't have a collision
SR_MissileCollision:
	LDX #$01			; Else, missile collision
	STX PlayerMissileFiring	; Allow another missile to fire
	DEX
	STX ThreatLevel		; Missile is gone, threat level 0
	LDA #$0F
	STA $0219			; Store blank tile in tile # address
						; Makes missile tile invisible
	DEC EnemyLife		; Decrease the enemies HP by 1
	INC PlayerScore		; Increase the player's score by 1
	JSR SR_UpdateScore	; Update the player's score
SR_MissileCheckEnd:
	RTS



	;-- Update Lives Shown --;
SR_UpdateLives:
	LDX #$00			; Clear X
	LDY #$00			; Clear Y
	LDA PlayerLives		; Get player's lives
	CMP #$0A			; Compare A with 10
	BCS SR_UpdateLivesTens	; If we have at least 10 lives, go to Tens
	JMP SR_UpdateLivesOnes	; Otherwise go to Ones
SR_UpdateLivesTens:
	INX					; Increment tens counter
	SEC
	SBC #$0A			; Subtract 10 from A
	CMP #$0A			; Compare 10 with A
	BCS SR_UpdateLivesTens	; Check if A is still at least 10
SR_UpdateLivesOnes:
	TAY					; Transfer A to Y thus putting remaining value in ones column
	LDA #$21
	STA $2006			; Write the high byte $(21)3D of address
	LDA #$3D
	STA $2006			; Write teh low byte $21(3D) of address
	STX $2007			; Write the tens column
	STY $2007			; Write the ones column
	LDA #$00
	STA $2005			; Write 0 to $2005 to reset the X/Y
	STA $2005			; Variables which are corrupted during write
	RTS



	;-- Update Missile Count --;
SR_MissileCount:
	LDA PlayerMissileID	; Get the current missile ID
	CMP #$01			; Compare it to 1 (EMP)
	BEQ SR_MissileCountEMP	; If the missile is the EMP, go to the appropriate code
	CMP #$02			; Compare it to 2 (Tracker)
	BEQ SR_MissileCountTracker	; If the missile is a tracker missile, go to the appropriate section
	RTS					; If neither, we don't need to update a missile count
SR_MissileCountEMP:
	DEC EMPCount		; Decrease the amount of EMPs
	LDA #$22
	STA $2006			; Write the high byte $(22)7C of address
	LDA #$7C
	STA $2006			; Write the low byte $22(7C) of address
	LDA EMPCount		; Get the current EMP count
	STA $2007			; Write the amount to $2007 to be displayed
	JMP SR_MissileCountEnd
SR_MissileCountTracker:
	DEC TrackerCount	; Decrease the amount of trackers
	LDA #$22
	STA $2006			; Write the high byte $(22)7E of address
	LDA #$7E
	STA $2006			; Write the low byte $(22)7C of address
	LDA TrackerCount	; Get the current Tracker Missile count
	STA $2007			; Write the amount to $2007
SR_MissileCountEnd:
	LDA #$00
	STA $2005			; Write #$00 to $2005 to reset the X/Y
	STA $2005			; Coordinates that are corrupted during $2007 write
	RTS



	;-- Setup For New Rounds --;
SR_NewRound:
	LDA #$00
	STA PlayerMissileX	; Set the missile's X & Y
	STA PlayerMissileY	; Coordinates to 0
	STA PlayerMissileID	; Set the current missile as the default missile
	LDA #$01
	STA EMPCount		; Give the player one EMP
	STA PlayerMissileFiring	; Set the the player as being able to fire a missile
	STA StartDown		; Set the start button as down as a precaution
	LDA #$02
	STA TrackerCount	; Give the player two Trackers
	LDA #$05
	STA EnemyLife		; Start of the enemy ship with 5hp again
	LDA #$70
	STA PlayerX			; Reset the player's horizontl position
	LDA #$C0
	STA PlayerY			; Reset the player's vertical position
	LDA #$70
	STA EnemyLeftX		; Set the enemy ship's left bound as #$70
	LDA #$88
	STA EnemyRightX		; Set the enemy ship's right bound as #$88
	LDA #$20
	STA EnemyBottomY	; Set the enemy ship's bottom bound as #$20
	LDA #$10
	STA EnemyTopY		; Set the enemy ship's top bound as #$10

	;-- Turn Off Background Rendering --;
	LDA #$00
	STA $2001			; Write 00 to $2001 to turn off background rendering

	;-- Clear Background --;
	LDA #$20
	STA $2006			; Write high byte $(20)00 of address
	LDA #$00
	STA $2006			; Write low byte $20(00) of address
	LDA #$24			; Assign A with the blank tile value
	LDX #$00			; Clear X
	LDY #$00			; Clear Y
SR_NewRoundClearBackground:
	STA $2007			; Write blank tile to $2007 (background)
	INX
	CPX #$F0			; Compare X with 240
	BNE SR_NewRoundClearBackground	; If not 240, keep going
	LDX #$00			; Clear X
	INY
	CPY #$04			; Compare Y with 4
	BNE SR_NewRoundClearBackground	; If not 4, keep going



	;-- Insert 'NEW ROUND' Code --;
	LDA #$21
	STA $2006			; Write high byte $(22)EC of address
	LDA #$2C
	STA $2006			; Write low byte $22(EC) of address
	LDX #$00
SR_NewRoundLoadNewRound:
	LDA BackgroundNewRound, x	; Fetch the next letter
	STA $2007			; Write the tile to $2007
	INX
	CPX #$09			; Compare x to 9
	BNE SR_NewRoundLoadNewRound	; If x isn't 9, we still need to load the tiles

		;-- Load 'PRESS START' --;
	LDA #$22
	STA $2006			; Write high byte $(22)EB of address
	LDA #$EB
	STA $2006			; Write low byte $22(EB) of address
	LDX #$00
SR_NewRoundPressStart:
	LDA BackgroundStartMenu, x	; Get the text value
	STA $2007			; Write it to the background
	INX
	CPX #$0B			; Compare X to 11
	BNE SR_NewRoundPressStart	; if X isn't 11, keep going

	LDA #$00
	STA $2005			; Write 0 to $2005 twice to reset the X/Y
	STA $2005			; Coordinates to 0, 0

	LDA #%00001110		; Enable background, no sprites
	STA $2001

	;-- Check For Start Press --;
SR_NewRoundReadControllers:
	LDA #$01
	STA $4016
	LDA #$00
	STA $4016			; Tell controllers to latch buttons

	LDA $4016			; A
	LDA $4016			; B
	LDA $4016			; Select
	LDA $4016			; Start
	AND #$01
	BEQ SR_NewRoundReadControllers	; If start wasn't pressed, continue reading the controller
	RTS					; Otherwise we can end this subroutine



	;-- Update Player Score --;
SR_UpdateScore:
	LDA PlayerScore		; Get the current score
	CMP #$64			; Compare it against 100
	BCS SR_UpdateScore_HLimit	; If PlayerScore is greater than or equal to 100
	JMP SR_UpdateScore_UpdateText	; Otherwise move on to update the score text
SR_UpdateScore_HLimit:
	SEC
	SBC #$64			; Subtract 100 from the player's score
	STA PlayerScore		; Store the new score
	INC PlayerScoreH	; Increment the amount of 100s in the player's score
SR_UpdateScore_UpdateText:
	LDA #$20
	STA $2006			; Write the high byte $(20)9C of address
	LDA #$9c
	STA $2006			; Write the low byte $20(9C) of address

	LDA PlayerScoreH	; Get the current value of the 100s column
	STA $2007			; Write the value of the 100s column to the background

	LDX #$00			; Clear X to be used as a counter for the 10s slot
	LDA PlayerScore		; Get the current score
SR_UpdateScore_Update10:
	CMP #$0A			; Compare the score to 10
	BCC SR_UpdateScore_Update10End	; If the score is less than 10, move on to the end of the check
	SEC
	SBC #$0A			; Otherwise subtract 10
	INX					; Increment X
	JMP SR_UpdateScore_Update10	; Jump to the beginning of the loop
SR_UpdateScore_Update10End:
	STX $2007			; Write the value of the X column to the background

	LDX #$00			; Clear X for use as a counter for the 1s slot
SR_UpdateScore_Update1:
	CMP #$00			; Compare to 0
	BEQ SR_UpdateScore_Update1End	; If A is 0, jump to the end of the loop
	SEC
	SBC #$01			; Otherwise subtract 1 from A
	INX					; Increment the 1s counter
	JMP SR_UpdateScore_Update1	; Jump to the beginning of the loop
SR_UpdateScore_Update1End:
	STX $2007			; Write the 1s column count to the background

	LDA #$00
	STA $2005			; Write 0 to $2005 to reset the
	STA $2005			; X,Y coordinates
	RTS					; The score is updated