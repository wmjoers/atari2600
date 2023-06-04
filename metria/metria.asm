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
LOGO_FADE_INITIAL_DELAY = 40
LOGO_FADE_DELAY = 20

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RAM variables located outside ROM at address $0080
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    seg.u variables
    org $80

LM_LogoFade    ds 1
LM_LogoTick    ds 1

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

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Wait for the remining scanlines - Total 37
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
.GM_VBLankWait:
    ldx #37             ; X = 37
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
    lda LOGO_BACKGROUND_COLOR           
    sta COLUBK
    lda LOGO_COLOR
    sta COLUPF
    jmp .GM_ColorDone
.GM_BW:
    lda LOGO_BACKGROUND_BW
    sta COLUBK
    lda LOGO_COLOR
    sta COLUPF
.GM_ColorDone:

    ldx #192
    WAIT_X_WSYNC

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
    sta WSYNC

    jmp GM_NextFrame




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
        .byte #%01111110;$70
        .byte #%01111110;$70
        .byte #%00111100;$70
        .byte #%01011010;$84
        .byte #%01111110;$84
        .byte #%00011000;$F4
        .byte #%00111100;$00
        .byte #%00011000;$00
GM_DRESS_WALK1:
        .byte #%01111000;$70
        .byte #%01111110;$70
        .byte #%00111100;$70
        .byte #%00011010;$84
        .byte #%01111110;$84
        .byte #%00011000;$F4
        .byte #%00111100;$00
        .byte #%00011000;$00
GM_DRESS_WALK2:
        .byte #%00011110;$70
        .byte #%01111110;$70
        .byte #%00111100;$70
        .byte #%01011000;$84
        .byte #%01111110;$84
        .byte #%00011000;$F4
        .byte #%00111100;$00
        .byte #%00011000;$00
GM_PANTS_IDLE:
        .byte #%01100110;$70
        .byte #%00100100;$70
        .byte #%00111100;$70
        .byte #%01011010;$84
        .byte #%01111110;$84
        .byte #%00011000;$F4
        .byte #%00111100;$00
        .byte #%00011000;$00
GM_PANTS_WALK1:
        .byte #%01100000;$70
        .byte #%00100110;$70
        .byte #%00111100;$70
        .byte #%00011010;$84
        .byte #%01111110;$84
        .byte #%00011000;$F4
        .byte #%00111100;$00
        .byte #%00011000;$00
GM_PANTS_WALK2:
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
GM_PLAYER_COLORS:
        .byte #$70;
        .byte #$70;
        .byte #$70;
        .byte #$84;
        .byte #$84;
        .byte #$F4;
        .byte #$00;
        .byte #$00;
;---End Color Data---

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fill the 4K ROM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $FFFC
    .word Reset ; Reset vector
    .word Reset ; Interrupt Vector

    