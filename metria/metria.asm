    processor 6502

    include "vcs.h"
    include "macro.h"

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Macros
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    MAC WAIT_X_WSYNC       
.WaitX:
        sta WSYNC           ; Wait for horizontal blank
        dex                 ; X--
        bne .WaitX          ; Loop until X = 0
    ENDM

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Contants
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

LOGO_BACKGROUND_COLOR = #$38
LOGO_BACKGROUND_BW = #$08
LOGO_COLOR = #$0E
LOGO_LINE = #24
LOGO_HEIGHT = #9
LOGO_FADE_INITIAL_DELAY = #40
LOGO_FADE_DELAY = #20

GAME_BK_BW = #$08
GAME_PLAYER_HEIGHT = #9

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RAM variables located outside ROM at address $0080
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    seg.u variables
    org $80

LM_LogoFade         ds 1
LM_LogoTick         ds 1

GM_PlayerPtr        ds 2
GM_PlayerColorPtr   ds 2
GM_PlayerXPos       ds 1
GM_PlayerYPos       ds 1
GM_PlayerMode       ds 1
GM_SelectActive     ds 1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Program start - Located at top of ROM at address $F000
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    seg code
    org $F000       

Reset:
    CLEAN_START

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Init variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    lda #4
    sta LM_LogoFade
    lda LOGO_FADE_INITIAL_DELAY
    sta LM_LogoTick

    SET_POINTER GM_PlayerPtr, GM_DRESS_IDLE
    SET_POINTER GM_PlayerColorPtr, GM_PLAYER_COLOR

    lda #67
    sta GM_PlayerXPos
    lda #46
    sta GM_PlayerYPos
    lda #0
    sta GM_PlayerMode
    lda #0
    sta GM_SelectActive

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MODE: LOGO - Start new frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
LM_NextFrame:
    lda #2                  ; A = 2 = #%00000010
    sta VBLANK              ; Turn on VBLANK
    VERTICAL_SYNC           ; Vertical sync - 3 scanlines

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Vertical blank - 37 scanlines total
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Wait for the remining scanlines - Total 37
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.LM_VBLankWait:
    ldx #37             ; X = 37
    WAIT_X_WSYNC        ; Wait for X scanlines

    lda #0              ; A = 0 = #%00000000
    sta VBLANK          ; Turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Draw screen - 192 scanlines - 2 scanline kernel
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    lda LM_LogoFade
    cmp #0
    beq .LM_FadeDone

    dec LM_LogoTick
    bne .LM_FadeDone

    dec LM_LogoFade
    lda LOGO_FADE_DELAY
    sta LM_LogoTick

.LM_FadeDone:
    ldy LM_LogoFade

    lda #%00001000
    bit SWCHB
    beq .LM_BW
.LM_Color:
    lda LOGO_BACKGROUND_COLOR           
    sta COLUBK
    lda LM_LogoFade_Color,Y
    sta COLUPF
    jmp .LM_Top
.LM_BW:
    lda LOGO_BACKGROUND_BW
    sta COLUBK
    lda LM_LogoFade_BW,Y
    sta COLUPF

.LM_Top                 ; 68
    ldx #68
    WAIT_X_WSYNC

.LM_Middle              ; 36
    ldy #0
.LM_LoopY:
    ldx #4;
.LM_LoopX:
    sta WSYNC
    lda LM_LogoPF0,Y
    sta PF0
    lda LM_LogoPF1,Y
    sta PF1
    lda LM_LogoPF2,Y
    sta PF2
    iny
    lda LM_LogoPF0,Y
    sta PF0
    lda LM_LogoPF1,Y
    sta PF1
    lda LM_LogoPF2,Y
    dey
    nop
    sta PF2

    dex
    bne .LM_LoopX
    iny
    iny
    tya
    cmp #18
    bne .LM_LoopY
.LM_TurnOffLogo
    lda WSYNC           ; 1   
    lda #0
    sta PF0
    sta PF1
    sta PF2

.LM_Bottom
    ldx #87             ; 87
    WAIT_X_WSYNC

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Handle overscan - 30 scanlines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.LM_OverScanWait:
    lda #2              ; A = 2 = #%00000010
    sta VBLANK          ; Turn on VBLANK
    ldx #29             ; X = 30-1
    WAIT_X_WSYNC        ; Wait for X scanlines

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Check input
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    lda #%00000001
    bit SWCHB
    bne .LM_NoReset
    jmp Reset
.LM_NoReset:

    lda #%10000000
    bit INPT4    
    bne .LM_NoFireButton
    jmp GM_NextFrame
.LM_NoFireButton:
    sta WSYNC

    jmp LM_NextFrame


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; MODE: GAME - Start new frame
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
GM_NextFrame:
    lda #2                  ; A = 2 = #%00000010
    sta VBLANK              ; Turn on VBLANK
    VERTICAL_SYNC           ; Vertical sync - 3 scanlines

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Vertical blank - 37 scanlines total
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    lda GM_PlayerXPos
    ldy #0
    jsr SetObjectXPos

    sta WSYNC               ; Wait for next scanline
    sta HMOVE               ; Apply the fine position offset

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Wait for the remining scanlines - Total 37
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.GM_VBLankWait:
    ldx #35             ; X = 37-2
    WAIT_X_WSYNC        ; Wait for X scanlines

    lda #0              ; A = 0 = #%00000000
    sta VBLANK          ; Turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Draw screen - 192 scanlines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    lda #%00001000
    bit SWCHB
    beq .GM_BW
.GM_Color:
    lda #$C8           
    sta COLUBK
    lda LOGO_COLOR
    sta COLUPF
    SET_POINTER GM_PlayerColorPtr, GM_PLAYER_COLOR
    jmp .GM_ColorDone
.GM_BW:
    lda GAME_BK_BW
    sta COLUBK
    lda LOGO_COLOR
    sta COLUPF
    SET_POINTER GM_PlayerColorPtr, GM_PLAYER_BW
.GM_ColorDone:

    ldx #96            ; X counter contains the remaining scanlines

Scanline:
    txa                 ; transfer X to A
    sec                 ; make sure carry flag is set
    sbc GM_PlayerYPos   ; subtract sprite Y coordinate
    cmp GAME_PLAYER_HEIGHT   ; are we inside the sprite height bounds?
    bcc .GM_LoadPlayer  ; if result < SpriteHeight, call subroutine
    lda #0              ; else, set index to 0

.GM_LoadPlayer:
    tay
    lda (GM_PlayerPtr),Y      ; load player bitmap slice of data

    sta WSYNC           ; wait for next scanline

    sta GRP0            ; set graphics for player 0 slice
    lda (GM_PlayerColorPtr),Y       ; load player color from lookup table
    sta COLUP0          ; set color for player 0 slice

    sta WSYNC           ; wait for next scanline

    dex
    bne Scanline        ; repeat next scanline until finished



;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Handle overscan - 30 scanlines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.GM_OverScanWait:
    lda #2              ; A = 2 = #%00000010
    sta VBLANK          ; Turn on VBLANK
    ldx #29             ; X = 30-1
    WAIT_X_WSYNC        ; Wait for X scanlines

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Check input
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    lda #%00000001
    bit SWCHB
    bne .GM_NoReset
    jmp Reset
.GM_NoReset:

    lda #%00000010
    bit SWCHB
    bne .GM_NoSelect

    lda GM_SelectActive
    cmp #0
    bne .GM_SelectDone

    lda #1
    sta GM_SelectActive

    lda #2
    eor SWCHB
    sta SWCHB

    lda #1
    eor GM_PlayerMode
    sta GM_PlayerMode
    cmp #0
    beq .GM_SET_DRESS
.GM_SET_PANTS:
    SET_POINTER GM_PlayerPtr, GM_PANTS_IDLE
    jmp .GM_SelectDone
.GM_SET_DRESS:
    SET_POINTER GM_PlayerPtr, GM_DRESS_IDLE
    jmp .GM_SelectDone
.GM_NoSelect:
    lda #0
    sta GM_SelectActive
.GM_SelectDone:

.GM_CheckUp:
    lda #%00010000
    bit SWCHA
    bne .GM_CheckDown
    inc GM_PlayerYPos

.GM_CheckDown:
    lda #%00100000
    bit SWCHA
    bne .GM_CheckLeft
    dec GM_PlayerYPos

.GM_CheckLeft:
    lda #%01000000
    bit SWCHA
    bne .GM_CheckRight
    dec GM_PlayerXPos

.GM_CheckRight:
    lda #%10000000
    bit SWCHA
    bne .GM_NoInput
    inc GM_PlayerXPos

.GM_NoInput:

    sta WSYNC


    jmp GM_NextFrame


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subruotines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; SetObjectXPos
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; A : Contains the the desired x-coordinate
;; Y=0 : Player0
;; Y=1 : Player1
;; Y=2 : Missile0
;; Y=3 : Missile1
;; Y=4 : Ball
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

SetObjectXPos subroutine
    sta WSYNC               ; Get fresh scanline
    sec                     ; Set carry flag
.Div15Loop                  ; Divide A with 15 by subtraction in loop
    sbc #15                 ; Subtract 15 from A
    bcs .Div15Loop          ; Loop if carry flag is set
    eor #7                  ; Adjust the remainder in A between -8 and 7
    REPEAT 4                ; Repeat 4 times
        asl                 ; Shift bits left by one
    REPEND                  ; End of repeat
    sta HMP0,Y              ; Set fine position value for object HMP0+Y
    sta RESP0,Y             ; Seset rough position for object HMP0+Y
    
    rts                     ; Return from subroutine

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Lookup tabes
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

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
    .byte $0E,$0E,$0C,$0A,$08


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
;---End Graphics Data---


;---Color Data from PlayerPal 2600---
GM_PLAYER_COLOR:
        .byte #0
        .byte #$70;
        .byte #$70;
        .byte #$70;
        .byte #$84;
        .byte #$84;
        .byte #$F4;
        .byte #$00;
        .byte #$00;

GM_PLAYER_BW:
        .byte #0
        .byte #$0;
        .byte #$0;
        .byte #$0;
        .byte #$02;
        .byte #$02;
        .byte #$04;
        .byte #$00;
        .byte #$00;

;---End Color Data---

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fill the 4K ROM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $FFFC
    .word Reset ; Reset vector
    .word Reset ; Interrupt Vector

    