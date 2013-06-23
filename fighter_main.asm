Main:
	LDA Timer			; Get the timer value
	BEQ Main			; If the timer is 0, we aren't able to continue
	DEC Timer			; Clear var, tell to wait until next NMI

;----- Read Controller -----;
	LDA #$01
	STA $4016
	LDA #$00
	STA $4016			; Tell controllers to latch buttons

ReadA:
	LDA $4016			; Player 1 - A
	AND #$01			; Only need to check the first bit
	BEQ ReadB
	LDA Paused			; Get the paused 'boolean'
	BNE ReadB			; If we are paused (1) keep on moving

	;-- Check Missile State --;
	LDA PlayerMissileFiring
	BEQ ReadB			; If 'PlayerMissileFiring' is (0) a missile is active, don't fire a new one

	;-- Check Missile Count --;
	LDA PlayerMissileID
	CMP #$01
	BEQ ReadAEMP		; If ID is 1, check EMP count
	CMP #$02
	BEQ ReadATracker	; If ID is 2, check Tracker count
	JMP ReadAYes		; Otherwise, we can fire a missile
ReadAEMP:
	LDA EMPCount		; Get EMP count
	BEQ ReadB			; If EMPCount == 0, we can't fire, go to /b/
	JMP ReadAYes		; Otherwise we can fire so move on
ReadATracker:
	LDA TrackerCount	; Get Tracker count
	BEQ ReadB			; If TrackerCount == 0, we can't fire, go to /b/
ReadAYes:

	;-- Fire a new missile --;
	LDA PlayerX			; Get the ship's current horizontal position
	CLC
	ADC #$05			; Add 5 to the horizontal position to align it with the left turret
	STA PlayerMissileX	; Set the missile's current position
	LDA PlayerY			; Get the ship's current vertical position
	SEC
	SBC #$05			; Move it up 5 slots to align it with the beginning of the left turret
	STA PlayerMissileY	; Set the missile's vertical position
	LDX #$00
	STX PlayerMissileFiring	; Indicate missile is firing
	INX
	STX ThreatLevel		; Increase threat level to 1, missile fired

	;-- Update Displayed Items --;
	JSR SR_MissileCount	; Update the amount of missiles available

	LDA #$30			; Load a base value of #$30
	CLC
	ADC PlayerMissileID	; Add the missile ID to the base value ($30, $31, or $32) (standard missile, EMP, tracker)
	STA $0219			; Write new value to get current missile sprite

ReadB:
	LDA $4016			; Player 1 - B
	AND #$01
	BEQ ReadSelect

ReadSelect:
	LDA $4016			; Player 1 - Select
	AND #$01
	BEQ SelectNotPressed
	LDA Paused			; Get paused status
	BNE ReadStart		; If paused (1), skip this section
	LDA PlayerMissileFiring	; Get missile status
	BEQ ReadStart		; If a missile is firing (0) we cannot change missiles

	LDA SelectDown
	BNE SelectPressed	; If select was already down, don't do anything
	LDX PlayerMissileID	; Get the current missile's ID
	INX					; Up the missile ID by 1
	STX PlayerMissileID	; Store the new ID
	CPX #$03
	BNE MarkIcon		; If the ID isn't 3, we are fine, underline the current missile
	LDX #$00			; If ID is 3, change it to 0
	STX PlayerMissileID	; Store the new ID of 0
MarkIcon:
	JSR SR_MissileSelect	; Goto subroutine that underlines the current missile
	LDA #$00			; Load 0
	STA $2005			; Write 0000 to $2005 to reset the X,Y coordinates
	STA $2005			; That get corrupted during the missile underline routine
SelectPressed:
	LDA #$01
	STA SelectDown		; Indicate select is pressed
	JMP ReadStart		; Move on to next button
SelectNotPressed:
	LDA #$00
	STA SelectDown		; Indicate select is not pressed

ReadStart:
	LDA $4016			; Player 1 - Start
	AND #$01
	BEQ StartNotPressed

	LDA StartDown		; Check if start is still down
	BNE StartPressed	; If it was already down, keep going
	;-- Toggle Pause State --;
	LDA Paused			; Get the paused value
	EOR #$01			; Toggle the paused state
	STA Paused			; Store the new value
	JSR SR_Pause		; Either remove or add 'PAUSED' based on value of Paused
StartPressed:
	LDA #$01
	STA StartDown		; Indicate start is down
	JMP ReadUp			; Finish up here
StartNotPressed:
	LDA #$00
	STA StartDown		; Indicate start is not down

ReadUp:
	LDA $4016			; Player 1 - Up
	AND #$01
	BEQ ReadDown
	LDA Paused
	BNE ReadDown

	;-- Move ship up --;
	LDA PlayerY			; Get the current Y position
	SEC
	SBC #$02			; Subtract 2 from it (move it up 2 slots)
	STA PlayerY			; Store the new vertical postion

ReadDown:
	LDA $4016			; Player 1 - Down
	AND #$01
	BEQ ReadLeft
	LDA Paused
	BNE ReadLeft

	;-- Move ship down --;
	LDA PlayerY			; Get the current Y position
	CLC
	ADC #$02			; Add 2 (move it down 2 slots)
	STA PlayerY			; Store the new position

ReadLeft:
	LDA $4016
	AND #$01
	BEQ ReadRight
	LDA Paused			; Get the paused 'boolean'
	BNE ReadRight		; If we are paused (1) keep on moving

	;-- Move ship to the left --;
	LDA PlayerX			; Get ship's 'X' position
	SEC					; Set carry
	SBC #$02			; Move 2 spots to the left
	STA PlayerX			; Update value

ReadRight:
	LDA $4016
	AND #$01
	BEQ ReadControllersDone
	LDA Paused				; Get the paused 'boolean'
	BNE ReadControllersDone	; If we are paused (1) keep on moving

	;-- Move ship to the right --;
	LDA PlayerX			; Get ship's 'X' position
	CLC					; Clear carry
	ADC #$02			; Move 2 spots to the right
	STA PlayerX			; Update Value

ReadControllersDone:
;----- Controllers Read -----;
	LDA Paused			; Get paused boolean
	BEQ CheckShip		; If paused == 0, we aren't paused, keep going
	JMP Main			; If paused != 0, we are paused, go back to start

	;-- Check Ship Location --;
CheckShip:
	LDA PlayerX			; Get the current horizontal position
	CMP #$3A
	BCS ShipCheckRight	; If the location is greater than the left edge, move to next checkpoint
	LDA #$3A			; Otherwise, get the leftmost limit and reposition the ship there
	STA PlayerX			; Store the new value
	JMP ShipCheckBottom	; Move on and check the vertical positioning
ShipCheckRight:
	CMP #$AE
	BCC ShipCheckBottom	; If the location is less than the right edge, move to the next checkpoint
	LDA #$AE			; Otherwise, get the leftmost limit and reposition the ship there
	STA PlayerX			; Store the new position
ShipCheckBottom:
	LDA PlayerY			; Get the current vertical position
	CMP #$D8
	BCC ShipCheckTop	; If the location is less than the bottom edge, move to the next checkpoint
	LDA #$D8			; Otherwise, get the bottom limit and reposition the ship there
	STA PlayerY			; Store the new vertical position
	JMP ShipCheckEnd	; Move to the end of the ship position check
ShipCheckTop:
	CMP #$30
	BCS ShipCheckEnd	; If the vertical position is less than the top limit, ship check is over
	LDA #$30			; Otherwise, get the top limit and set the position there
	STA PlayerY			; Store the new position
ShipCheckEnd:

	;-- Move Missile --;
	LDA PlayerMissileFiring
	BNE AIStart			; If we aren't firing a missile, we are done here ya'll
	DEC PlayerMissileY	; Move the missile two slots up as a preliminary measure
	DEC PlayerMissileY
	LDA PlayerMissileID	; Ottherwise, get the current missile ID
	BEQ Missile1		; If missile is missile 1 (Standard missile) goto appropriate place
	CMP #$01
	BEQ Missile2		; If missile is missle 2 (EMP) goto appropriate place
	JMP Missile3		; If not the above 2, it is missile 3
Missile1:
	DEC PlayerMissileY
	JMP EndOfMissile
Missile2:
	LDA PlayerMissileY
	CMP EMPTimer
	BCC Missile2_LT		; If the location is less than EMPTimer, detonation
	JMP EndOfMissile	; Else we're done here
Missile2_LT:
	LDA #$0F
	STA $0219			; Set the missile sprite as a blank tiles
	LDA #$01
	STA PlayerMissileFiring	; A missile is no longer being fired
	LDA #$00
	STA ThreatLevel		; EMP is now gone, set there is no threat
	JMP EndOfMissile	; We're outta here
Missile3:
	LDA PlayerMissileY	; Get the current missile position
	SEC
	SBC #$04			; Subtract 5 from it (push it forward 5 slots)
	STA PlayerMissileY	; Store the new location
	LDA EnemyLeftX		; Get the enemy ship's left most coordinate
	CMP PlayerMissileX
	BCC Missile3_2		; If the missile's position is greater, goto next checkpoint
	INC PlayerMissileX	; Otherwise increase the x position by one
	JMP EndOfMissile	; Finish up missile calculations
Missile3_2:
	LDA EnemyRightX		; Get the enemy ship's right most coordinate
	CMP PlayerMissileX
	BCS EndOfMissile	; If the missile's position is less, get out of here
	DEC PlayerMissileX	; Otherwise decrease the x position by one
EndOfMissile:
	;-- Check if out of map --;
	LDA PlayerMissileY
	CMP #$08			; Check if it is greater than 3
	BCS AIStart			; If it is, move on to AI check
	LDX #$01			; Else, missile is out of bounds
	STX PlayerMissileFiring	; Allow another missile to fire'
	DEX
	STX ThreatLevel		; Missile is gone, threat level 0
	LDA #$0F
	STA $0219			; Store blank tile in tile # address
						; Makes missile tile invisible

	;-- Enemy Ship AI --;
AIStart:
	LDA PlayerMissileFiring
	BNE EndOfRoundCheck	; If we aren't firing a missile, we don't need to run threat assesment

	LDA EnemyRightX		; Get the enemy's right X coordinate
	SEC
	SBC #$10			; Subtract 16 from the X coordinate. X = Enemy midship

	LDY PlayerMissileY	; Get the player's current missile position
	CPY #$70			; Compare the Y coordinate to $70
	BCS ThreatLevel1	; If greater than $70, Threat Level 1
	CPY #$30			; Compare the Y coordinate to $30
	BCC ThreatLevel3	; If the Y coordinate is less than $30, Threat Level 3
	JMP ThreatLevel2	; Otherwise the Y coordinate is between $70-$30, Threat Level 2

ThreatLevel1:
	JMP ThreatLevelEnd	; We are done here, skip the other threat levels
ThreatLevel2:
	JMP ThreatLevelEnd	; We are done here, skip the remaining threat level
ThreatLevel3:
ThreatLevelEnd:

EnemyCheckLeft:
	LDA EnemyLeftX		; Get the enemy's left edge position
	CMP #$3C			; Compare it to #$3C
	BCS EnemyCheckRight	; If the position is >= check the right side
	LDA #$3C
	STA EnemyLeftX		; Otherwise load up #$3C (which is the left limit) and set that as the ship's position
	CLC
	ADC #$18			; Add #$18
	STA EnemyRightX		; Set the right position marker to be #$18 (24) more than the left position
	JMP EndOfRoundCheck	; Jump to the end of the loop
EnemyCheckRight:
	LDA EnemyRightX		; Get the enemy's right edge
	CMP #$BC
	BCC EndOfRoundCheck	; If the position is less than the right limit (#$AE) then we are done here
	LDA #$BC			; Otherwise, load up the right limit position
	STA EnemyRightX		; Store the limit as the new position
	SEC
	SBC #$18			; Subtract #$18
	STA EnemyLeftX		; Set the left position marker to be #$18 (24) less than the right marker


	;-- Check For End Of Round --;
EndOfRoundCheck:
	LDA EnemyLife		; Get the enemy ship's current health count
	BEQ EndOfRoundCheck_EOR	; If the health is equal to 0, we have an end of round situation
	JMP EndOfMain		; If all else fails, we don't have an end of round situation
EndOfRoundCheck_EOR:
	JSR SR_NewRound		; Subroutine to initiate new round
	JMP PreMain			; Start the new round

EndOfMain:
	JSR SR_Missile		; Move missile routine
	JSR SR_MissileCheck	; Check if the missile(s) have collided with anything
	JSR SR_Player		; Move player ship
	JSR SR_Enemy		; Move enemy ship
	JMP Main			; Move to the beginning of the loop