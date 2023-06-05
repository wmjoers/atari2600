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

RANDOM_SEED = $72

LOGO_BK_COLOR = $38             ; logo mode background color - color mode
LOGO_BK_BW = $06                ; logo mode background color - black & white
LOGO_FADE_INIT_STATE = 4        ; initial value for the logo fade in state
LOGO_FADE_INIT_DELAY = 40       ; initial delay value before logo fades in
LOGO_FADE_DELAY = 20            ; delay for each fade step - 20 frames/step

GAME_BK_COLOR = $C8             ; game background color - color mode
GAME_BK_BW = $08                ; game background color - black & white
GAME_PF_COLOR = $C0             ; game playfield color - color mode
GAME_PF_BW = $02                ; game playfield color - black & white
GAME_SKY_COLOR = $78            ; game sky color - color mode
GAME_SKY_BW = $06               ; game sky color - black & white
GAME_SCOREBOARD_COLOR = $0      ; game score board color - all modes

GAME_PLAYER_HEIGHT = 9          ; player sprite height
GAME_BUG_HEIGHT = 9             ; bug sprite height


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; RAM variables located outside ROM at address $0080
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

    seg.u variables
    org $80                     ; RAM address memory start

LM_LogoFadeState    ds 1        ; current logo fade state
LM_LogoFadeDelay    ds 1        ; current logo fade delay

GM_BackgroundColor  ds 1
GM_SkyColor         ds 1

GM_PlayerPtr        ds 2
GM_PlayerColorPtr   ds 2
GM_PlayerXPos       ds 1
GM_PlayerYPos       ds 1

GM_BirdPtr          ds 2
GM_BirdColorPtr     ds 2
GM_BirdYPos         ds 1
GM_BirdReflection   ds 1

GM_BugColorPtr      ds 2
GM_BugXPos          ds 1
GM_BugYPos          ds 1
GM_PlayfieldIdx     ds 1

PFCounter           ds 1
Random              ds 1

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

    lda #RANDOM_SEED
    sta Random

    lda #LOGO_FADE_INIT_STATE   
    sta LM_LogoFadeState        ; initialize logo fade state
    lda #LOGO_FADE_INIT_DELAY
    sta LM_LogoFadeDelay        ; initialize logo fade delay

    SET_POINTER GM_PlayerPtr, GM_DRESS_IDLE
    SET_POINTER GM_PlayerColorPtr, GM_PLAYER_COLOR_IDLE

    SET_POINTER GM_BugColorPtr, GM_BUG_COLOR

    SET_POINTER GM_BirdPtr, GM_BIRD_1

    lda #62
    sta GM_PlayerXPos
    lda #21
    sta GM_PlayerYPos

    jsr PlaceBug

    lda #4
    sta GM_BirdYPos
    lda #0
    sta GM_BirdReflection

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
    lda #LOGO_BK_COLOR    
    sta COLUBK                  ; set background color
    lda LM_LogoFade_Color,Y 
    sta COLUPF                  ; set logo color
    jmp .LM_SetColorDone
.LM_BWMode:
    lda #LOGO_BK_BW       
    sta COLUBK                  ; set background color
    lda LM_LogoFade_BW,Y
    sta COLUPF                  ; set logo color
.LM_SetColorDone

.LM_VBLankWait:
    ldx INTIM
    bne .LM_VBLankWait          ; wait until timer is done
    lda #0
    sta WSYNC                   ; get a fresh scanline
    ; ------------------------- 
    sta VBLANK                  ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Playfield - 192 scanlines - 14592 mc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

.LM_Top                         ; waste 68 scanlines
    ldx #68
    WAIT_X_WSYNC
    ; -------------------------

.LM_Middle                      ; logo is a total of 36 scanlines
    ldy #0                      ; Y = index to playfield bytes
.LM_LoopY:
    ldx #4                      ; draw every logo line 4 scanlines
.LM_LoopX:
    sta WSYNC                   ; get fresh scanline
    ; -------------------------
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
    ; -------------------------
    lda #0                  
    sta PF0                     ; reset playfield graphics
    sta PF1
    sta PF2

.LM_Bottom
    ldx #87                     ; waste remaining 87 scanlines
    WAIT_X_WSYNC
    ; -------------------------

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Overscan - 30 scanlines - 2280 mc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2                      ; A = 2 = #%00000010
    sta VBLANK                  ; Turn on VBLANK
    lda #TIMER_OVERSCAN
    sta TIM64T                  ; set timer to 35x64 = 2240 mc

.LM_CheckReset:
    lda SWCHB                   ; load console switches
    and #RESET_MASK             
    bne .LM_NoReset
    jmp Reset                   ; jump to reset if reset button has been pressed
.LM_NoReset:

.LM_CheckLeftButton:
    lda INPT4                   ; load left joystick button
    and #LEFT_BTN_MASK
    bne .LM_NoLeftButton
    sta WSYNC
    jmp GM_NextFrame            ; start game if button is pressed
.LM_NoLeftButton:

.LM_OverscanWait:
    ldx INTIM
    bne .LM_OverscanWait        ; wait until timer is done
    sta WSYNC
    ; -------------------------
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
    ; -------------------------
    sta HMOVE                   ; apply positions offset

.GM_SetColor:                   ; set correct colors
    lda SWCHB
    and BW_MASK
    beq .GM_BWMode
.GM_ColorMode:
    lda #GAME_SKY_COLOR
    sta GM_SkyColor
    lda #GAME_BK_COLOR        
    sta GM_BackgroundColor
    lda #GAME_PF_COLOR
    sta COLUPF
    SET_POINTER GM_PlayerColorPtr, GM_PLAYER_COLOR_IDLE
    SET_POINTER GM_BugColorPtr, GM_BUG_COLOR
    SET_POINTER GM_BirdColorPtr, GM_BIRD_COLOR
    jmp .GM_SetColorDone
.GM_BWMode:
    lda #GAME_SKY_BW
    sta GM_SkyColor
    lda #GAME_BK_BW
    sta GM_BackgroundColor
    lda #GAME_PF_BW
    sta COLUPF
    SET_POINTER GM_PlayerColorPtr, GM_PLAYER_BW_IDLE
    SET_POINTER GM_BugColorPtr, GM_BUG_BW
    SET_POINTER GM_BirdColorPtr, GM_BIRD_BW
.GM_SetColorDone:
    lda #GAME_SCOREBOARD_COLOR
    sta COLUBK

.GM_SetGraphics
    lda SWCHB
    and #%01000000
    beq .GM_SetDress
.GM_SetPants:
    SET_POINTER GM_PlayerPtr, GM_PANTS_IDLE
    jmp .GM_SetGraphicsDone
.GM_SetDress:
    SET_POINTER GM_PlayerPtr, GM_DRESS_IDLE
.GM_SetGraphicsDone:

.GM_CheckCollisions:
    lda CXPPMM
    and #%10000000
    beq .GM_CheckCollisionsDone
    jsr PlaceBug
.GM_CheckCollisionsDone:
    sta CXCLR

.GM_PlayfieldInit
    lda #71                     
    sta PFCounter               ; 144/2 scanelines

.GM_VBLankWait:
    ldx INTIM
    bne .GM_VBLankWait          ; wait until timer is done
    lda #0
    sta WSYNC                   ; get a fresh scanline
    ; -------------------------
    sta VBLANK                  ; turn off VBLANK

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Score Board - 20 scanlines - 1520 mc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #23
    sta TIM64T                  ; set timer to 35x64 = 2240 mc

.GM_ScoreBoardWait:
    ldx INTIM
    bne .GM_ScoreBoardWait      ; wait until timer is done
    sta WSYNC                   ; get a fresh scanline
    ; -------------------------

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Sky - 30 scanlines - 1520 mc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda GM_SkyColor
    sta COLUBK
    ldx #15
    lda #0
    sta VDELP0                  ; clear vertical delay för player 0

    lda GM_BirdReflection
    sta REFP0

.GM_SkyLoop:

.GM_DrawBird:
    txa                         ; transfer X to A
    sec                         ; make sure carry flag is set
    sbc GM_BirdYPos             ; subtract sprite Y coordinate
    cmp GAME_PLAYER_HEIGHT      ; are we inside the sprite height bounds?
    bcc .GM_WriteBird           ; if result < SpriteHeight, call subroutine
    lda #0                      ; else, set index to 0
.GM_WriteBird:
    tay
    lda (GM_BirdPtr),Y          ; load player bitmap slice of data
    sta WSYNC                   ; wait for next scanline
    ; ------------------------- 
    sta GRP0                    ; set graphics for player 0 slice
    lda (GM_BirdColorPtr),Y     ; load player color from lookup table
    sta COLUP0                  ; set color for player 1 slice
.GM_DrawBirdDone:
    sta WSYNC                   ; wait for next scanline
    ; -------------------------
    dex
    bne .GM_SkyLoop


;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Playfield - 152 scanlines - 11552 mc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda GM_BackgroundColor
    sta COLUBK
    lda #1
    sta VDELP0                  ; set vertical delay för player 0
    lda #0
    sta REFP0

.GM_PlayfieldLoop:

.GM_DrawPlayer:
    lda PFCounter               ; A = current scanline in playfield
    sec                         ; make sure carry flag is set
    sbc GM_PlayerYPos           ; subtract sprite Y coordinate
    cmp GAME_PLAYER_HEIGHT      ; are we inside the sprite height bounds?
    bcc .GM_WritePlayer         ; if result < height then A contains the index
    lda #0                      ; else, set A to 0
.GM_WritePlayer:
    tay
    lda (GM_PlayerPtr),Y        ; load player bitmap slice of data
    sta GRP0                    ; set graphics for player 0 slice - delayed
    lda (GM_PlayerColorPtr),Y   ; load player color from lookup table
    tax
.GM_DrawPlayerDone:

.GM_DrawBug:
    lda PFCounter               ; transfer X to A
    sec                         ; make sure carry flag is set
    sbc GM_BugYPos              ; subtract sprite Y coordinate
    cmp GAME_PLAYER_HEIGHT      ; are we inside the sprite height bounds?
    bcc .GM_WriteBug            ; if result < SpriteHeight, call subroutine
    lda #0                      ; else, set index to 0
.GM_WriteBug:
    tay
    lda GM_BUG,Y                ; load player bitmap slice of data
    sta WSYNC                   ; wait for next scanline
    ; ------------------------- 
    sta GRP1                    ; set graphics for player 1 + 0 slice
    stx COLUP0                  ; set color for player 0 slice
    lda (GM_BugColorPtr),Y      ; load player color from lookup table
    sta COLUP1                  ; set color for player 1 slice
.GM_DrawBugDone:

    sta WSYNC                   ; wait for end of second scanline
    ; -------------------------  
    dec PFCounter
    bne .GM_PlayfieldLoop       ; repeat next scanline until finished

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Overscan - 30 scanlines - 2280 mc
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    lda #2                      ; A = 2 = #%00000010
    sta VBLANK                  ; Turn on VBLANK
    lda #TIMER_OVERSCAN         
    sta TIM64T                  ; set timer to 35x64 = 2240 mc

.GM_CheckReset:
    lda SWCHB                   ; load console switches
    and #RESET_MASK             
    bne .GM_NoReset
    jmp Reset                   ; jump to reset if reset button has been pressed
.GM_NoReset:

.GM_CheckInputUp:
    lda #%00010000
    bit SWCHA
    bne .GM_CheckInputDown
    inc GM_PlayerYPos

.GM_CheckInputDown:
    lda #%00100000
    bit SWCHA
    bne .GM_CheckInputLeft
    dec GM_PlayerYPos

.GM_CheckInputLeft:
    lda #%01000000
    bit SWCHA
    bne .GM_CheckInputRight
    lda #%00001000
    sta GM_BirdReflection
    dec GM_PlayerXPos

.GM_CheckInputRight:
    lda #%10000000
    bit SWCHA
    bne .GM_CheckInputDone
    lda #0
    sta GM_BirdReflection
    inc GM_PlayerXPos

.GM_CheckInputDone:

.GM_OverscanWait:
    ldx INTIM
    bne .GM_OverscanWait        ; wait until timer is done
    sta WSYNC
    ; -------------------------  
    jmp GM_NextFrame

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subruotines
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

PlaceBug subroutine
    jsr Randomize
    lda Random
    and #%01111111
    sta GM_BugXPos
    jsr Randomize
    lda Random
    and #%00111111
    sta GM_BugYPos
    rts

Randomize subroutine
    lda Random
    asl
    eor Random
    asl
    eor Random
    asl
    asl
    eor Random
    asl
    rol Random               ; performs a series of shifts and bit operations
    rts

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
        ; -------------------------  
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

Digits:
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00110011          ;  ##  ##
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #
    .byte %00010001          ;   #   #

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %00010001          ;   #   #
    .byte %01110111          ; ### ###

    .byte %00100010          ;  #   #
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #

    .byte %01110111          ; ### ###
    .byte %01010101          ; # # # #
    .byte %01100110          ; ##  ##
    .byte %01010101          ; # # # #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01000100          ; #   #
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###

    .byte %01100110          ; ##  ##
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01010101          ; # # # #
    .byte %01100110          ; ##  ##

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01110111          ; ### ###

    .byte %01110111          ; ### ###
    .byte %01000100          ; #   #
    .byte %01100110          ; ##  ##
    .byte %01000100          ; #   #
    .byte %01000100          ; #   #

;---Graphics Data from PlayerPal 2600---

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
GM_BIRD_1:
    .byte #0
    .byte #%00000000;$1C
    .byte #%00000001;$1C
    .byte #%00111111;$0E
    .byte #%11111110;$0A
    .byte #%00011000;$0E
    .byte #%01110110;$0E
    .byte #%00000000;$0E
    .byte #%00000000;$0E
GM_BIRD_2:
    .byte #0
    .byte #%00000000;$1C
    .byte #%00000001;$1C
    .byte #%00111111;$0E
    .byte #%11111110;$0A
    .byte #%11111000;$0E
    .byte #%00000000;$0E
    .byte #%00000000;$0E
    .byte #%00000000;$0E

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
GM_BIRD_COLOR:
    .byte #0
    .byte #$1C;
    .byte #$1C;
    .byte #$0E;
    .byte #$0A;
    .byte #$0E;
    .byte #$0E;
    .byte #$0E;
    .byte #$0E;
GM_BIRD_BW:
    .byte #0
    .byte #$0C;
    .byte #$0C;
    .byte #$0E;
    .byte #$0A;
    .byte #$0E;
    .byte #$0E;
    .byte #$0E;
    .byte #$0E;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Fill the 4K ROM
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
    org $FFFC                   ; insert two pointers at the end of ROM
    .word Reset                 ; reset vector
    .word Reset                 ; interrupt Vector

    