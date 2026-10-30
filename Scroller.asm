;--------------------------------------------;
; Program : SDA5708.asm                      ;
;--------------------------------------------;
; Interfacing a Nokia Dbox 9500S Display     ;
; with a 16F84                               ;
; The display is controlled by a SDA5708     ;
; And is connected on PIC's PORTA            ;
;--------------------------------------------;
; PORTA0 --> Reset                           ;
; PORTA1 --> Load                            ;
; PORTA2 --> Clock                           ;
; PORTA3 --> Data                            ;
;--------------------------------------------;
; 4 MHz Crystal

; Disable 302 Assembler Message
ERRORLEVEL -302

    processor p16f84a
    #include "./p16f84.inc"

    ; Config:
    ; Code Protect    OFF
    ; Power Up Timer  ON
    ; Watch Dog Timer OFF
    ; High Speed Oscillator
    __CONFIG _CP_OFF & _PWRTE_ON & _WDT_OFF & _HS_OSC


; --------------- Defines -------------------
MSGLN       equ     0x17    ; Message Length
CHRDSP      equ     0x08    ; Number of char on display

    ; LCD Pinouts
Reset       equ     0
Load        equ     1
Clk         equ     2
Dat         equ     3

    ; LCD Registers
;-----------------------------------------------------------------------------
; CtR is the control register, used to configure the beaviour of the display.
;     Accessed whenever bits 7 & 8 are 1
;     bit 5 is on in normal mode, 0 when issued a clear command
;     bit 3-0 sets the brigtness
; AdR is the address register, used to set the character to address (0 to 7)
;     Accessed whenever bits 8 and 6 are 1, and bit 7 is 0
;     last 3 bits are used to index the character
; CDR is the cell's pixel, it is automatically incremented
;     is accessed whenever bits 8,7 &6 are 0
;     remaing bits indicate : 1 pixel ON
;                             0 pixel OFF
;     Every character is drawn row by row
;     the number of rows is 7 and they need to be issued sequentially
;

CtR         equ     B'11100000'     ; Control Register
AdR         equ     B'10100000'     ; Address Register
CDR         equ     B'00000000'     ; Column Data Register

; -------------- Variables ------------------

    cblock 0x0C
        COUNT         ; Generic Counter
        COUNT_A       ; used in Delay soubroutine
        COUNT_B       ; See in the main
        INIT          ;   "   "   "
        CHAR          ;   "   "   "
        LCD_BRIGHT    ; Lcd brightness (Lower Nibble, 0000 = Max brightness)
        LCD_POS       ; Current Cursor Position
        BYTE          ; Byte to sent to LCD
    endc


    org 0x00
        goto        Program
; Lookup Table. Put at the start to avoid memory paging problems
; Return in w the number pointed by w. Each number correnspond to a letter of the message
; This way we have to implement only the letters that have to be shown.
Letter:
        addwf       PCL,F
        ; Use DT directive to generate the loockup table
        ;   B   U   O   N   A   N   O   T   T   E   _   E   _   B   U   O   N   G   I   O   R   N   O   _
        dt 0x0,0x1,0x2,0x3,0x4,0x3,0x2,0x5,0x5,0x6,0xA,0x6,0xA,0x0,0x1,0x2,0x3,0x7,0x8,0x2,0x9,0x3,0x2,0xA


   ;            Device Configuration
   ; ----------------------------------------
Program:

    banksel TRISA
        movlw       B'00000000'
        movwf       TRISA           ; PortA all output
        movlw       B'00000001'
        movwf       TRISB           ; PortB all output

    banksel PORTA
        movlw       B'00000011'     ; Reset=HI, Load=HI, Data/Clock=LO
        movwf       PORTA
        clrf        PORTB
        clrf        LCD_BRIGHT      ; Max brightness
        clrf        LCD_POS         ; Set Cursor to column 0

   ;         Main Program
   ; -------------------------------------------------
;Using 3 pointers:
        ;1) INIT    -> The Starting position inside the message increased
                       ;everytime the display is full
        ;2) COUNT_B -> The number of character to be displayed
                       ;(depends on the LCD)
        ;3) CHAR    -> The current character to be displayed, starting from
                       ;'INIT' and increased every character. It is wrapped
                       ;at the end of the message.
main:
        call        Init_Lcd
        clrf        CHAR
        movlw       0x00
        movwf       INIT
Start:
        movlw       CHRDSP      ; Load COUNT_B with the size of the display
        movwf       COUNT_B
        movf        INIT,W      ; Set the starting letter to be displayed (Copy INIT in CHAR)
        movwf       CHAR
Loop2:
        movf        CHAR,W
        call        Letter      ; Load W with the letter pointed by char
        call        Send_Char   ; Display the corrensponding letter

        incf        CHAR,F      ; Set next letter
        movlw       MSGLN+1     ; Is CHAR at end of message ?
        subwf       CHAR,W
        btfsc       STATUS,Z
        goto        Res_Char    ; Yes, set char to message start

No_Res_Char:
        decfsz      COUNT_B,F   ; No, go on
        goto        Loop2
        incf        INIT,F
        movlw       MSGLN+1     ; Check INIT=11 ?
        subwf       INIT,W
        btfsc       STATUS,Z
        goto        Res_Init    ; Yes, reset INIT to 0

No_Res_Init:
        movlw       0xFE
        movwf       COUNT_B
        movlw       0xFE        ; White a while
        call        Delay1
        decfsz      COUNT_B,F
        goto        $-3
        clrf        LCD_POS     ; Set cursor at init of display
        call        Set_Position

        goto        Start

Res_Char:
        movlw       0x00
        movwf       CHAR
        goto        No_Res_Char

Res_Init:
        movlw       0x00
        movwf       INIT
        goto        No_Res_Init


   ; ---------------------------------------------------------
   ;                   Soubrotines

;----------------------------------------;
; Soubroutine : Init_Lcd                 ;
;----------------------------------------;
; Init Lcd display.                      ;
; Issue RESET Signal                     ;
; Cursor to row 0  ( Due to RESET )      ;
; Set The brightness to LCD_BRIGHT       ;
;----------------------------------------;
Init_Lcd:
        bcf         PORTA,Reset     ; Reset!
        call        Delay
        bsf         PORTA,Reset     ;
        call        Clear_Display   ;
        return

;----------------------------------------;
; Soubroutine : Clear_Display            ;
;----------------------------------------;
; Clear the display                      ;
; Set The brightness                     ;
;----------------------------------------;
Clear_Display:
        movlw       CtR             ; Set Control Register
        andlw       B'11011111'     ; Set Bit 5 = 0 (Clear display)
        call        Send_Byte       ; Issue command
        call        Set_Brightness  ; Set Brightness (And put Bit 5 to 1)
        return

;--------------------------------------------;
; Soubroutine : Set_Brightness               ;
; Usage       : Put Brightness in LCD_BRIGHT ;
;               Call The soubroutine         ;
;--------------------------------------------;
; Set The brightness to LCD_BRIGHT           ;
;--------------------------------------------;
Set_Brightness:
        movlw       CtR             ; Set Control Register
        addwf       LCD_BRIGHT,W    ; Set Brightness
        call        Send_Byte       ; Issue command
        return

;-------------------------------------------;
; Soubroutine : Set_Position                ;
; Usage       : Put the position in LCD_POS ;
;               and call the soubroutine    ;
;-------------------------------------------;
; Set the cursor position on the display    ;
; At the value in LCD_POS                   ;
; Store the new position in LCD_POS         ;
;-------------------------------------------;
Set_Position:
        movlw       AdR             ; Set Address Register
        addwf       LCD_POS,W       ; Set Position
        call        Send_Byte       ; Issue command
        return

;----------------------------------------;
; Soubroutine : Send_Char                ;
;----------------------------------------;
; Send The character in W to LCD         ;
; Increase the cursor position           ;
; If cursor > 8 reset to 0               ;
;----------------------------------------;
Send_Char:
        addwf      PCL,F
        goto       Char_B       ; B
        goto       Char_U       ; U
        goto       Char_O       ; O
        goto       Char_N       ; N
        goto       Char_A       ; A
        goto       Char_T       ; T
        goto       Char_E       ; E
        goto       Char_G       ; G
        goto       Char_I       ; I
        goto       Char_R       ; R
        goto       Blank        ; ' '

Char_B:
        movlw       B'00011110'
        call        Send_Byte
        movlw       B'00001001'
        call        Send_Byte
        movlw       B'00001001'
        call        Send_Byte
        movlw       B'00001110'
        call        Send_Byte
        movlw       B'00001001'
        call        Send_Byte
        movlw       B'00001001'
        call        Send_Byte
        movlw       B'00011110'
        call        Send_Byte
        goto        Char_Sent

Char_U:
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00001110'
        call        Send_Byte
        goto        Char_Sent

Char_O:
        movlw       B'00001110'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00001110'
        call        Send_Byte
        goto        Char_Sent

Char_N:
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00011001'
        call        Send_Byte
        movlw       B'00010101'
        call        Send_Byte
        movlw       B'00010011'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        goto        Char_Sent

Char_A:
        movlw       B'00000100'
        call        Send_Byte
        movlw       B'00001010'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00011111'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        goto        Char_Sent

Char_T:
        movlw       B'00011111'
        call        Send_Byte
        movlw       B'00000100'
        call        Send_Byte
        movlw       B'00000100'
        call        Send_Byte
        movlw       B'00000100'
        call        Send_Byte
        movlw       B'00000100'
        call        Send_Byte
        movlw       B'00000100'
        call        Send_Byte
        movlw       B'00000100'
        call        Send_Byte
        goto        Char_Sent

Char_E:
        movlw       B'00011111'
        call        Send_Byte
        movlw       B'00010000'
        call        Send_Byte
        movlw       B'00010000'
        call        Send_Byte
        movlw       B'00011100'
        call        Send_Byte
        movlw       B'00010000'
        call        Send_Byte
        movlw       B'00010000'
        call        Send_Byte
        movlw       B'00011111'
        call        Send_Byte
        goto        Char_Sent

Char_G:
        movlw       B'00001111'
        call        Send_Byte
        movlw       B'00010000'
        call        Send_Byte
        movlw       B'00010000'
        call        Send_Byte
        movlw       B'00010111'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00001110'
        call        Send_Byte
        goto        Char_Sent

Char_I:
        movlw       B'00001110'
        call        Send_Byte
        movlw       B'00000100'
        call        Send_Byte
        movlw       B'00000100'
        call        Send_Byte
        movlw       B'00000100'
        call        Send_Byte
        movlw       B'00000100'
        call        Send_Byte
        movlw       B'00000100'
        call        Send_Byte
        movlw       B'00001110'
        call        Send_Byte
        goto        Char_Sent

Char_R:
        movlw       B'00011110'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        movlw       B'00011110'
        call        Send_Byte
        movlw       B'00010100'
        call        Send_Byte
        movlw       B'00010010'
        call        Send_Byte
        movlw       B'00010001'
        call        Send_Byte
        goto        Char_Sent

Blank:
        movlw       B'00000000'
        call        Send_Byte
        movlw       B'00000000'
        call        Send_Byte
        movlw       B'00000000'
        call        Send_Byte
        movlw       B'00000000'
        call        Send_Byte
        movlw       B'00000000'
        call        Send_Byte
        movlw       B'00000000'
        call        Send_Byte
        movlw       B'00000000'
        call        Send_Byte
        goto        Char_Sent

Char_Sent:
        incf        LCD_POS,F
        movlw       0x08
        xorwf       LCD_POS,W
        btfss       STATUS,Z        ; Is LCD_POS=8 ?
        goto        $+2             ; no, skip next instruction
        clrf        LCD_POS
        call        Set_Position
        return

;----------------------------------------;
; Soubroutine : Send_Byte                ;
; Usage :                                ;
;        movlw  'value'                  ;
;        call   Send_Byte                ;
;----------------------------------------;
; Send the value in W to the LCD         ;
; Put LOAD low                           ;
; And send every bit, on the rising edge ;
; of the clock signal                    ;
;----------------------------------------;
Send_Byte:
        movwf       BYTE
        movlw       0x08
        movwf       COUNT           ; Init BIT Counter
        bcf         PORTA,Load      ; Set Load low
Loop_Send:
        btfss       BYTE,0
        bcf         PORTA,Dat
        btfsc       BYTE,0
        bsf         PORTA,Dat
        bsf         PORTA,Clk
        call        Delay
        bcf         PORTA,Clk
        call        Delay
        bcf         STATUS,C
        rrf         BYTE,F
        decfsz      COUNT,F         ; All 8 bits trasmitted ?
        goto        Loop_Send       ; No, go on

        bsf         PORTA,Load      ; Yes, Disable LOAD, and reset DATA
        bcf         PORTA,Dat
        return

;-----------------------------;
;Soubroutine : Delay          ;
;-----------------------------;
; Delay Routine               ;
;-----------------------------;
Delay:
        movlw   0x8
Delay1:
        movwf   COUNT_A
        decfsz  COUNT_A,F
        goto    $-1
        return

Delay2:
        call    Delay
        call    Delay

        return


    end
