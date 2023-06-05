    processor 6502

    include "vcs.h"
    include "macro.h"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    MAC WAIT_X_WSYNC       
.WaitX:
        sta WSYNC           ; Wait for horizontal blank
        dex                 ; X--
        bne .WaitX          ; Loop until X = 0
    ENDM


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Contants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

BW_MASK = %00001000             ; bitmask for black & white switch
RESET_MASK = %00000001          ; bitmask for reset switch
LEFT_BTN_MASK = %10000000       ; bitmask for left joystick button
TIMER_VBLANK = 43               ; value for TIM64T vertical blank timer
TIMER_OVERSCAN = 35             ; value for TIM64T overscan timer

LOGO_BACK_COLOR = $38           ; logo mode background color - color mode
LOGO_BACK_BW = $06              ; logo mode background color - black & white
LOGO_FADE_INIT_STATE = 4        ; initial value for the logo fade in state
LOGO_FADE_INIT_DELAY = 40       ; initial delay value before logo fades in
LOGO_FADE_DELAY = 20            ; delay for each fade step - 20 frames/step

GAME_BK_COLOR = $C8
GAME_BK_BW = $08
GAME_PF_COLOR = $C0
GAME_PF_BW = $02

GAME_PLAYER_HEIGHT = 9

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RAM variables located outside ROM at address $0080
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    seg.u variables
    org $80                     ; RAM address memory start

LM_LogoFadeState    ds 1        ; current logo fade state
LM_LogoFadeDelay    ds 1        ; current logo fade delay

GM_PlayerPtr        ds 2
GM_PlyAnimOfset     ds 1
GM_PlyAnimDelay     ds 1

GM_PlayerColorPtr   ds 2
GM_PlayerXPos       ds 1
GM_PlayerYPos       ds 1

GM_BugColorPtr      ds 2
GM_BugXPos          ds 1
GM_BugYPos          ds 1
GM_PlayfieldIdx     ds 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program start - Located at top of ROM at address $F000
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    seg code                
    org $F000                   ; start address of ROM

Reset:
    CLEAN_START                 ; set machine to known state on startup

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Init variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    lda #LOGO_FADE_INIT_STATE   
    sta LM_LogoFadeState        ; initialize logo fade state
    lda #LOGO_FADE_INIT_DELAY
    sta LM_LogoFadeDelay        ; initialize logo fade delay

    SET_POINTER GM_PlayerPtr, GM_DRESS_IDLE
    SET_POINTER GM_PlayerColorPtr, GM_PLAYER_COLOR_IDLE

    SET_POINTER GM_BugColorPtr, GM_BUG_COLOR

    lda #62
    sta GM_PlayerXPos
    lda #21
    sta GM_PlayerYPos
    lda #0
    sta GM_PlyAnimDelay
    sta GM_PlyAnimOfset

    lda #10
    sta GM_BugXPos
    lda #10
    sta GM_BugYPos

    lda #2
    sta VBLANK                  ; turn on VBLANK 

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; LOGO MODE - LM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LM_NextFrame:
    VERTICAL_SYNC               ; vertical sync - 3 scanlines

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Vertical Blank - 37 scanlines - 2812 mc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #TIMER_VBLANK
    sta TIM64T                  ; set timer to 43x64 = 2752 mc

.LM_Fade:                       ; handles logo fade in 
    lda LM_LogoFadeState    
    cmp #0      
    beq .LM_FadeDone            ; if fade in is complete then jump out
    dec LM_LogoFadeDelay        ; dec fade delay 
    bne .LM_FadeDone            ; if still waiting for delay then jump out
    dec LM_LogoFadeState        ; dec fade in state 
    lda #LOGO_FADE_DELAY    
    sta LM_LogoFadeDelay        ; restore fade in delay
.LM_FadeDone:

.LM_SetColor:                   ; set correct colors
    ldy LM_LogoFadeState        ; set Y = index of logo color
    lda SWCHB                   ; load console switches
    and #BW_MASK                ; check if black & white
    beq .LM_BWMode          
.LM_ColorMode:
    lda #LOGO_BACK_COLOR    
    sta COLUBK                  ; set background color
    lda LM_LogoFade_Color,Y 
    sta COLUPF                  ; set logo color
    jmp .LM_SetColorDone
.LM_BWMode:
    lda #LOGO_BACK_BW       
    sta COLUBK                  ; set background color
    lda LM_LogoFade_BW,Y
    sta COLUPF                  ; set logo color
.LM_SetColorDone

.LM_VBLankWait:
    ldx INTIM
    bne .LM_VBLankWait          ; wait until timer is done
    lda #0
    sta WSYNC                   ; get a fresh scanline
    sta VBLANK                  ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Playfield - 192 scanlines - 14592 mc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.LM_Top                         ; waste 68 scanlines
    ldx #68
    WAIT_X_WSYNC

.LM_Middle                      ; logo is a total of 36 scanlines
    ldy #0                      ; Y = index to playfield bytes
.LM_LoopY:
    ldx #4;                     ; draw every logo line 4 scanlines
.LM_LoopX:
    sta WSYNC                   ; get fresh scanline
    lda LM_LogoPF0,Y
    sta PF0                     ; set first part of left playfield 
    lda LM_LogoPF1,Y
    sta PF1                     ; set second part of left playfield 
    lda LM_LogoPF2,Y
    sta PF2                     ; set third part of left playfield 
    iny                         ; inc Y to get the right playfield bytes
    lda LM_LogoPF0,Y        
    sta PF0                     ; set first part of right playfield 
    lda LM_LogoPF1,Y        
    sta PF1                     ; set second part of right playfield
    lda LM_LogoPF2,Y        
    dey                         ; dec Y to bea able to repeat left/right for 4 lines
    nop                         ; just for timing
    sta PF2                     ; set third part of right playfield

    dex
    bne .LM_LoopX               ; loop while we havn't drawn 4 scanlines
    iny                     
    iny                         ; inc y by 2 to get to the next playfield byte pairs
    cpy #18                     ; all bytes drawn?
    bne .LM_LoopY               ; loop until all logo bytes are drawn

.LM_TurnOffLogo                 ; use 1 scanline to turn off logo
    lda WSYNC                   ; get a fresh scanline   
    lda #0                  
    sta PF0                     ; reset playfield graphics
    sta PF1
    sta PF2

.LM_Bottom
    ldx #87                     ; waste remaining 87 scanlines
    WAIT_X_WSYNC

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Overscan - 30 scanlines - 2280 mc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2                      ; A = 2 = #%00000010
    sta VBLANK                  ; Turn on VBLANK
    lda #TIMER_OVERSCAN
    sta TIM64T                  ; set timer to 35x64 = 2240 mc

    lda SWCHB                   ; load console switches
    and #RESET_MASK             
    bne .LM_NoReset
    jmp Reset                   ; jump to reset if reset button has been pressed
.LM_NoReset:

    lda INPT4                   ; load left joystick button
    and #LEFT_BTN_MASK
    bne .LM_NoFireButton
    sta WSYNC
    jmp GM_NextFrame            ; start game if button is pressed
.LM_NoFireButton:

.LM_OverscanWait:
    ldx INTIM
    bne .LM_OverscanWait        ; wait until timer is done
    sta WSYNC

    jmp LM_NextFrame


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; GAME MODE - GM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GM_NextFrame:
    VERTICAL_SYNC               ; Vertical sync - 3 scanlines

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Vertical Blank - 37 scanlines - 2812 mc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #TIMER_VBLANK
    sta TIM64T                  ; set timer to 43x64 = 2752 mc

    lda GM_PlayerXPos           ; load player x pos
    ldy #0                      ; set Y = 0 for player 0
    jsr SetObjectXPos           ; call subroutine to set object x pos 

    lda GM_BugXPos              ; load bug x pos
    ldy #1                      ; set Y = 1 for player 1
    jsr SetObjectXPos           ; call subroutine to set object x pos

    sta WSYNC                   ; geta fresh scanline 
    sta HMOVE                   ; apply positions offset

.GM_SetColor:                   ; set correct colors
    lda SWCHB
    and BW_MASK
    beq .GM_BWMode
.GM_ColorMode:
    lda #GAME_BK_COLOR        
    sta COLUBK
    lda #GAME_PF_COLOR
    sta COLUPF
    SET_POINTER GM_PlayerColorPtr, GM_PLAYER_COLOR_IDLE
    SET_POINTER GM_BugColorPtr, GM_BUG_COLOR
    jmp .GM_SetColorDone
.GM_BWMode:
    lda #GAME_BK_BW
    sta COLUBK
    lda #GAME_PF_BW
    sta COLUPF
    SET_POINTER GM_PlayerColorPtr, GM_PLAYER_BW_IDLE
    SET_POINTER GM_BugColorPtr, GM_BUG_BW
.GM_SetColorDone

.GM_VBLankWait:
    ldx INTIM
    bne .GM_VBLankWait          ; wait until timer is done
    lda #0
    sta WSYNC                   ; get a fresh scanline
    sta VBLANK                  ; turn off VBLANK
 
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Draw screen - 192 scanlines - 2 line kernel
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    ldx #96            ; X counter contains the remaining scanlines

.GM_KernelLoop:

    txa                 ; transfer X to A
    sec                 ; make sure carry flag is set
    sbc GM_PlayerYPos   ; subtract sprite Y coordinate
    cmp GAME_PLAYER_HEIGHT   ; are we inside the sprite height bounds?
    bcc .GM_LoadPlayer  ; if result < SpriteHeight, call subroutine
    lda #0              ; else, set index to 0
.GM_LoadPlayer:
    
    clc
    adc GM_PlyAnimOfset

    tay
    lda (GM_PlayerPtr),Y      ; load player bitmap slice of data

    sta WSYNC           ; wait for next scanline

    sta GRP0            ; set graphics for player 0 slice

    lda (GM_PlayerColorPtr),Y       ; load player color from lookup table
    sta COLUP0          ; set color for player 0 slice

    txa                 ; transfer X to A
    sec                 ; make sure carry flag is set
    sbc GM_BugYPos   ; subtract sprite Y coordinate
    cmp GAME_PLAYER_HEIGHT   ; are we inside the sprite height bounds?
    bcc .GM_LoadBug  ; if result < SpriteHeight, call subroutine
    lda #0              ; else, set index to 0
.GM_LoadBug:
    tay
    lda GM_BUG,Y      ; load player bitmap slice of data

    sta WSYNC           ; wait for next scanline

    sta GRP1            ; set graphics for player 0 slice
    lda (GM_BugColorPtr),Y       ; load player color from lookup table
    sta COLUP1          ; set color for player 0 slice

    dex
    bne .GM_KernelLoop   ; repeat next scanline until finished

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Handle overscan - 30 scanlines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.GM_OverScanWait:
    lda #2              ; A = 2 = #%00000010
    sta VBLANK          ; Turn on VBLANK
    ldx #27             ; X = 30-2
    WAIT_X_WSYNC        ; Wait for X scanlines

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Check input
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    lda #%00000001
    bit SWCHB
    bne .GM_NoReset
    jmp Reset
.GM_NoReset:

    lda #%01000000
    bit SWCHB
    beq .GM_SetDress
.GM_SetPants:
    SET_POINTER GM_PlayerPtr, GM_PANTS_IDLE
    jmp .GM_DificultyDone
.GM_SetDress:
    SET_POINTER GM_PlayerPtr, GM_DRESS_IDLE
.GM_DificultyDone:
    sta WSYNC

    ldx #0

.GM_CheckUp:
    lda #%00010000
    bit SWCHA
    bne .GM_CheckDown
    ldx #1
    inc GM_PlayerYPos

.GM_CheckDown:
    lda #%00100000
    bit SWCHA
    bne .GM_CheckLeft
    ldx #1
    dec GM_PlayerYPos

.GM_CheckLeft:
    lda #%01000000
    bit SWCHA
    bne .GM_CheckRight

    lda #2
    cmp GM_PlayerXPos
    beq .GM_CheckRight
    ldx #1
    dec GM_PlayerXPos

.GM_CheckRight:
    lda #%10000000
    bit SWCHA
    bne .GM_NoInput
    lda #134
    cmp GM_PlayerXPos
    beq .GM_NoInput
    ldx #1
    inc GM_PlayerXPos

.GM_NoInput:

    txa
    cmp #0
    beq .GM_NoAnim

    lda #GAME_PLAYER_HEIGHT
    sta GM_PlyAnimOfset
    jmp .GM_AnimDone
.GM_NoAnim:
    lda #0
    sta GM_PlyAnimOfset
.GM_AnimDone:

    sta WSYNC
    jmp GM_NextFrame


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subruotines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SetObjectXPos
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A : Contains the the desired x-coordinate
;; Y=0 : Player0
;; Y=1 : Player1
;; Y=2 : Missile0
;; Y=3 : Missile1
;; Y=4 : Ball
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SetObjectXPos subroutine
        sec                     ; Set carry flag
        sta WSYNC               ; Get fresh scanline
.Div15Loop                      ; Divide A with 15 by subtraction in loop
        sbc #15                 ; Subtract 15 from A
        bcs .Div15Loop          ; Loop if carry flag is set
        eor #7                  ; Adjust the remainder in A between -8 and 7
        REPEAT 4                ; Repeat 4 times
            asl                 ; Shift bits left by one
        REPEND                  ; End of repeat
        sta HMP0,Y              ; Set fine position value for object HMP0+Y
        sta RESP0,Y             ; Seset rough position for object HMP0+Y
        rts


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Lookup tabes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; https://www.masswerk.at/vcs-tools/TinyPlayfieldEditor/
; mode: asymmetric repeat line-height 4
LM_LogoPF0:
	.byte $00,$00,$00,$00,$00,$00,$00,$90   
	.byte $00,$40,$00,$40,$00,$40,$00,$40
	.byte $00,$70
LM_LogoPF1:
	.byte $00,$40,$00,$40,$00,$00,$05,$DE
	.byte $0A,$42,$0A,$4E,$08,$52,$08,$56
	.byte $38,$7B
LM_LogoPF2:
	.byte $00,$00,$00,$00,$80,$00,$F8,$00
	.byte $A5,$00,$A5,$00,$BF,$00,$85,$00
	.byte $39,$03

LM_LogoFade_Color:
    .byte $0E,$3E,$3C,$3A,$38

LM_LogoFade_BW:
    .byte $0E,$0C,$0A,$08,$06

;---Graphics Data from PlayerPal 2600---
; BGCOLOR = $C8

GM_DRESS_IDLE:
        .byte #0
        .byte #%01111110;$70
        .byte #%01111110;$70
        .byte #%00111100;$70
        .byte #%01011010;$84
        .byte #%01111110;$84
        .byte #%00011000;$F4
        .byte #%00111100;$00
        .byte #%00011000;$00
GM_DRESS_WALK1:
        .byte #0
        .byte #%01111000;$70
        .byte #%01111110;$70
        .byte #%00111100;$70
        .byte #%00011010;$84
        .byte #%01111110;$84
        .byte #%00011000;$F4
        .byte #%00111100;$00
        .byte #%00011000;$00
GM_DRESS_WALK2:
        .byte #0
        .byte #%00011110;$70
        .byte #%01111110;$70
        .byte #%00111100;$70
        .byte #%01011000;$84
        .byte #%01111110;$84
        .byte #%00011000;$F4
        .byte #%00111100;$00
        .byte #%00011000;$00
GM_PANTS_IDLE:
        .byte #0
        .byte #%01100110;$70
        .byte #%00100100;$70
        .byte #%00111100;$70
        .byte #%01011010;$84
        .byte #%01111110;$84
        .byte #%00011000;$F4
        .byte #%00111100;$00
        .byte #%00011000;$00
GM_PANTS_WALK1:
        .byte #0
        .byte #%01100000;$70
        .byte #%00100110;$70
        .byte #%00111100;$70
        .byte #%00011010;$84
        .byte #%01111110;$84
        .byte #%00011000;$F4
        .byte #%00111100;$00
        .byte #%00011000;$00
GM_PANTS_WALK2:
        .byte #0
        .byte #%00000110;$70
        .byte #%01100100;$70
        .byte #%00111100;$70
        .byte #%01011000;$84
        .byte #%01111110;$84
        .byte #%00011000;$F4
        .byte #%00111100;$00
        .byte #%00011000;$00
GM_BUG:
        .byte #0
        .byte #%00000000;$00
        .byte #%00000000;$00
        .byte #%01010010;$F0
        .byte #%00111100;$F0
        .byte #%00111100;$F2
        .byte #%01010010;$F0
        .byte #%00000000;$00
        .byte #%00000000;$00      
;---End Graphics Data---


;---Color Data from PlayerPal 2600---
GM_PLAYER_COLOR_IDLE:
        .byte #0
        .byte #$70;
        .byte #$70;
        .byte #$70;
        .byte #$84;
        .byte #$84;
        .byte #$F4;
        .byte #$00;
        .byte #$00;
GM_PLAYER_COLOR_WALK1:
        .byte #0
        .byte #$70;
        .byte #$70;
        .byte #$70;
        .byte #$84;
        .byte #$84;
        .byte #$F4;
        .byte #$00;
        .byte #$00;
GM_PLAYER_COLOR_WALK2:
        .byte #0
        .byte #$70;
        .byte #$70;
        .byte #$70;
        .byte #$84;
        .byte #$84;
        .byte #$F4;
        .byte #$00;
        .byte #$00;
GM_PLAYER_BW_IDLE:
        .byte #0
        .byte #$0;
        .byte #$0;
        .byte #$0;
        .byte #$02;
        .byte #$02;
        .byte #$04;
        .byte #$00;
        .byte #$00;
GM_PLAYER_BW_WALK1:
        .byte #0
        .byte #$0;
        .byte #$0;
        .byte #$0;
        .byte #$02;
        .byte #$02;
        .byte #$04;
        .byte #$00;
        .byte #$00;
GM_PLAYER_BW_WALK2:
        .byte #0
        .byte #$0;
        .byte #$0;
        .byte #$0;
        .byte #$02;
        .byte #$02;
        .byte #$04;
        .byte #$00;
        .byte #$00;
GM_BUG_COLOR:
        .byte #0
        .byte #$00;
        .byte #$00;
        .byte #$F0;
        .byte #$F0;
        .byte #$F2;
        .byte #$F0;
        .byte #$00;
        .byte #$00;
GM_BUG_BW:
        .byte #0
        .byte #$00;
        .byte #$00;
        .byte #$00;
        .byte #$00;
        .byte #$02;
        .byte #$00;
        .byte #$00;
        .byte #$00;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fill the 4K ROM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $FFFC                   ; insert two pointers at the end of ROM
    .word Reset                 ; reset vector
    .word Reset                 ; interrupt Vector

    