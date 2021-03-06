{
                                ********************************************
                                  LSI/CSI  Quad couter DEMO    V0.2
                                ********************************************
                                      coded by Henk Kiela Opteq R&D 
                                ********************************************
                                See end of file for terms of use
                                
What this module does:

The propellor is able to connect directly to quadrature encoders.
For speedcontrol, the software version works OK.
LSI logis offers with the LSI7366 an 32 bit quadrature counter with trigger and compare,
connected via SPI.

This test program show an example of how to connect the LSI7366 to the Propellor

Release note: This version is a prototype, using slow BS2 functions. Maybe someone feels
inspired to build a version using Asm SPI routines

For the LSI7366 ic, please see www.probotics.eu
We also have a small demoboard, with buffered complementary encoder inputs available.

             ┌──────────┐
         ──│  | | 14│── +5V       P0 = fCKi Sample clock A quad B
  P0 fCKi──│2 ┌°───┐  │               P1 = SSN
  P1 SSN ──│4 │ /\ │  │──           P2 = SCK
  P2 SCK ──│5 │ /\ │12│── A         P3 = MISO
  P3 MISO──│6 │ /\ │11│── B         P4 = MOSI
  P4 MOSI──│7 │ /\ │10│── Index
             │  └────┘  │
     VSS ──│3   │──
             └──────────┘

LS7366 internal:
IR = instruction register providing read write access to various registers including the counters
MRD0 (r/w 1 byte)  mode register 0
MRD1 (r/w 1 byte)  mode register 1
DTR  (write only 1 to 4 byte) compare and preset register
CNTR (r/w 1 to 4 byte) counter (via OTR)
OTR  (Read only 1 to 4 byte) output register for CNTR
STR  (Read only 1 byte) status register


}

CON

  _CLKMODE = XTAL1 + PLL16X
  _XINFREQ = 5_000_000

   fCKi = 0
   SSN = 1
   SCK = 2
   MISO = 3
   MOSI = 4

   CR = 13
   LF = 10
   DebugLed1 = 16 '27
   TXD = 31
   RXD = 30
   Baud = 115200

VAR
  long Last_Freq, LastIndex

OBJ
   d    : "fullDuplexSerialPlus"
'   LS7366   : "LS7366"
   t    : "Timing" 

PUB Setup | i, LV
  dira[DebugLed1]~~
  !outa[DebugLed1]                         'Toggle I/O Pin for debug

  FREQOUT_Set(fCKi, 100000)              'Create F clock in 

  d.start(TXD, RXD, 0, Baud)
  d.str(string("Ls7366 test init",CR))
  t.pause1ms(1000)
'  d.str(string("Druk op toets",CR))
'  repeat while d.rxcheck<0 'wait for char to start
  d.str(string("Ls7366 test 2 ",CR))

  'init counter
  MDR0init   
  d.str(string("Ls7366 init ",CR))
  ShowStatus
  
 ' d.str(string("Druk op toets",CR))
 ' repeat while d.rxcheck<0 'wait for char to start
  d.str(string("Ls7366 test 2 ",CR))
'  DTRWrite(0)  'reset counter
'  CNTRLoad  'Preset counter with DTR
  LastIndex:=0
  repeat 
    !outa[DebugLed1]                         'Toggle I/O Pin for debug
'     d.str(string("Ls7366 test3 ",CR))
'     d.str(string(CR))     
     d.dec(i)
 '    d.str(string(CR))     
'     d.dec(MakeIR(1,1))
'     d.str(string(CR))     
'     d.str(string(CR))     
'     d.str(d.Bin(MakeIR(rCNTR,iLoad),8))
'     d.str(string(CR))     
     d.str(string(CR))     
     d.str(string("Ls7366 read MDR0 "))
     LV:=MDR0Read
     d.hex(LV,2)
     d.str(string(" "))     
     d.str(d.Bin(LV,8))
'     d.str(string(CR))     
     d.str(string(" OTR "))
     LV:=OTRRead
     d.dec(LV)
     LV:=STRRead     'Check Status register for index flag
     if (lv & $10) == $10  'index found save OTR first
       d.str(string("  STR "))
       d.str(d.Bin(LV,8))
       LV:=OTRRead
       LastIndex:=LV
'       d.str(string(CR))

       d.str(string(" * "))
       STRClear
       d.str(string(CR))     

     d.str(string(" CNTR "))
     d.dec(CNTRRead)
     d.str(string(" Index "))
     d.dec(LastIndex)
     d.str(string("  STR "))
     LV:=STRRead
     d.hex(LV,2)
     d.str(string(" "))     
     d.str(d.Bin(LV,8))
     d.str(string(CR))     
'     d.str(string("Write DTR transfer to CNTR and read CNTR "))
'     DTRWrite($1234)
'     DTRWrite(i)
'     CNTRLoad  'Preset counter with DTR
  '   d.hex(CNTRRead,4)
     d.str(string(CR))     
     
     
'     d.str(string(CR))
     i:=i+1 
     t.Pause1ms(300)

PRI ShowStatus | LV      'Show register status on debug device
  d.str(string("Ls7366 read MDR0 "))
  LV:=MDR0Read
  d.hex(LV,2)
  d.str(string(" "))     
  d.str(d.Bin(LV,8))
  d.str(string("  MDR1 "))
  LV:=MDR1Read
  d.hex(LV,2)
  d.str(string(" "))     
  d.str(d.Bin(LV,8))
  d.str(string("  STR "))
  LV:=STRRead
  d.hex(LV,2)
  d.str(string(" "))     
  d.str(d.Bin(LV,8))
  d.str(string(CR))     

     
Con
   rMDR0 = 1      'register selector
   rMDR1 = 2
   rDTR  = 3
   rCNTR = 4
   rOTR  = 5
   rSTR  = 6
   iCLR  = 0        'action selector
   iRD   = 1
   iWR   = 2
   iLOAD = 3

PRI MakeIR(R, A)| lIR  'Create IR command byte from register and action
  lIR:=A*64 + R*8
Return lIR
   
PUB MDR0init  'Init MDR0 register of LS7366
'     MDR0write($A3)     'MDR0 data: fck/2 sync index=rcnt, x4
'     MDR0write($3)     'MDR0 data: fck/1 async index=rcnt, x4
     CNTRClear
     STRClear
     MDR0write(%00110000)     'MDR0 data: fck/1 async index=rcnt, x4 Error in doc! 00=4x quad mode
'     MDR0write(%00000000)     'MDR0 data: fck/1 async index=rcnt, x4 Error in doc! 00=4x quad mode
     MDR1write(%00000000)     'MDR1 

PUB MDR0write (Value) | lIR  'Write MDR0 register
     SS(SSN,1) 'ends any communication to LS7366
     SS(SSN,0) 'start communication to LS7366 Msb first
     lIR:=MakeIR(rMDR0,iWR)
     ShiftOut(MOSI,SCK,lIR ,MSBFIRST,8) 'LS7366 IR WR_MDR0
     ShiftOut(MOSI,SCK, Value ,MSBFIRST,8) 'MDR0 data write
     SS(SSN,1) 'ends communication to LS7366

PUB MDR0Read | lMDR0, lIR   'Read MDR0 register of LS7366
     SS(SSN,1) 'ends any communication to LS7366
     SS(SSN,0) 'start communication to LS7366 Msb first
     lIR:=MakeIR(rMDR0,iRD)
     ShiftOut(MOSI,SCK,lIR ,MSBFIRST,8) 'LS7366 RD_MDR0
     lMDR0 := ShiftIn(MISO,SCK,MSBPRE,8) 'MDR0 read MSB before clock
     SS(SSN,1) 'ends communication to LS7366
     Return lMDR0

PUB MDR1write (Value) |lIR  'Write MDR1 register
     SS(SSN,1) 'ends any communication to LS7366
     SS(SSN,0) 'start communication to LS7366 Msb first
     lIR:=MakeIR(rMDR1,iWR)
     ShiftOut(MOSI,SCK,lIR ,MSBFIRST,8) 'LS7366 IR WR_MDR0
     ShiftOut(MOSI,SCK, Value ,MSBFIRST,8) 'MDR1 data write
     SS(SSN,1) 'ends communication to LS7366

PUB MDR1Read | lValue, lIR 'Read MDR1 register of LS7366
     SS(SSN,1) 'ends any communication to LS7366
     SS(SSN,0) 'start communication to LS7366 Msb first
     lIR:=MakeIR(rMDR1,iRD)
     ShiftOut(MOSI,SCK,lIR ,MSBFIRST,8) 'LS7366 RD_MDR0
     lValue := ShiftIn(MISO,SCK,MSBPRE,8) 'MDR1 read MSB before clock
     SS(SSN,1) 'ends communication to LS7366
     Return lValue

PUB CNTRRead | lValue, lIR 'Transfer 4 bytes from CNTR to OTR and send to serial out
     SS(SSN,1) 'ends any communication to LS7366
     SS(SSN,0) 'start communication to LS7366 Msb first
     lIR:=MakeIR(rCNTR,iRD)
     ShiftOut(MOSI,SCK,lIR ,MSBFIRST,8) 'LS7366 RD_MDR0
     lValue := ShiftIn(MISO,SCK,MSBPRE,32) 'Counter read MSB before clock
     SS(SSN,1) 'ends communication to LS7366
     Return lValue
     
PUB STRRead | lValue, lIR 'Read Status register
     SS(SSN,1) 'ends any communication to LS7366
     SS(SSN,0) 'start communication to LS7366 Msb first
     lIR:=MakeIR(rSTR,iRD)
     ShiftOut(MOSI,SCK,lIR ,MSBFIRST,8) 'LS7366 RD_MDR0
     lValue := ShiftIn(MISO,SCK,MSBPRE,8) 'Status read MSB before clock
     SS(SSN,1) 'ends communication to LS7366
     Return lValue

PUB DTRwrite (Value)| lIR    'Write DTR with 4 bytes
     SS(SSN,1) 'ends any communication to LS7366
     SS(SSN,0) 'start communication to LS7366 Msb first
     lIR:=MakeIR(rDTR,iWR)
     ShiftOut(MOSI,SCK,lIR ,MSBFIRST,8) 'LS7366 IR WR_MDR0
     ShiftOut(MOSI,SCK, Value ,MSBFIRST,32) 'MDR1 data write
     SS(SSN,1) 'ends communication to LS7366

PUB CNTRload | lIR    'Load counter with DTR value
     SS(SSN,1) 'ends any communication to LS7366
     SS(SSN,0) 'start communication to LS7366 Msb first
     lIR:=MakeIR(rCNTR,iLOAD)
     ShiftOut(MOSI,SCK,lIR ,MSBFIRST,8) 'LS7366 IR WR_MDR0
     SS(SSN,1) 'ends communication to LS7366
          
PUB CNTRClear | lIR    'Reset counter
     SS(SSN,1) 'ends any communication to LS7366
     SS(SSN,0) 'start communication to LS7366 Msb first
     lIR:=MakeIR(rCNTR,iCLR)
     ShiftOut(MOSI,SCK,lIR ,MSBFIRST,8) 'LS7366 IR WR_MDR0
     SS(SSN,1) 'ends communication to LS7366
          
PUB OTRRead | lValue, lIR    'Read OTR register to get last latched CNTR on index 
     SS(SSN,1) 'ends any communication to LS7366
     SS(SSN,0) 'start communication to LS7366 Msb first
     lIR:=MakeIR(rOTR,iRD)
     ShiftOut(MOSI,SCK,lIR ,MSBFIRST,8) 'LS7366 RD_MDR0
     lValue := ShiftIn(MISO,SCK,MSBPRE,32) 'Counter read MSB before clock
     SS(SSN,1) 'ends communication to LS7366
     Return lValue

          
PUB STRClear | lIR    'Reset counter
     SS(SSN,1) 'ends any communication to LS7366
     SS(SSN,0) 'start communication to LS7366 Msb first
     lIR:=MakeIR(rSTR,iCLR)
     ShiftOut(MOSI,SCK,lIR ,MSBFIRST,8) 'LS7366 IR WR_MDR0
     SS(SSN,1) 'ends communication to LS7366
          
PRI SS(SelPin, E)
'set select slave pin in desired 0 or 1= start. 0=starts comm 1 disables/ends comm
  dira[SelPin]~~                                           ' Set data as output
  outa[SelPin]:=E

PUB LS7366Reg(Register, Action, Value) | lIR, lResult 'Perform action on LS7366 register (See Con definition)   'later  
     lIR:=MakeIR(Register,Action)   'Prepare IR value
     SS(SSN,1) 'ends any communication to LS7366
     SS(SSN,0) 'start communication to LS7366 Msb first
     ShiftOut(MoSi,SCK,lIR ,MSBFIRST,8) 'LS7366 write IR 

     case Action          'Depending on IR command perform action
 '      iCLR :  'Done clear MDR0 or MDR1 or CNTR or STR
       iRD  :
         Case Register
           rMDR0:
             
           rMDR1:
           rDTR :
           rCNTR:
           rOTR :
           rSTR :
       iWR  :
         Case Register
           rMDR0, rMDR1:
             ShiftOut(MoSi,SCK, Value ,MSBFIRST,8) 'MDR0 data write
           rDTR :
           rCNTR:
           rOTR :
           rSTR :
  '     iLOAD: 'Done transfer DTR to CNTR or CNTR to OTR
             
     SS(SSN,1) 'ends communication to LS7366                           

{  ************************************************
  *  Taken from BS2 Functions Library Object      *
  *  Version 1.5.1                                *
  *  Copyright (c) 2007, Martin Hebel             *
  *************************************************  
}
con
  ' SHIFTOUT Constants
  LSBFIRST = 0
  MSBFIRST = 1
PUB SHIFTOUT (Dpin, Cpin, Value, Mode, Bits)| bitNum
{{
   Shift data out, master clock, for mode use ObjName#LSBFIRST, #MSBFIRST
   Clock rate is ~16Kbps.  Use at 80MHz only is recommended.
     BS2.SHIFTOUT(5,6,"B",BS2#LSBFIRST,8)
}}
    outa[Dpin]:=0                                          ' Data pin = 0
    dira[Dpin]~~                                           ' Set data as output
    outa[Cpin]:=0
    dira[Cpin]~~

    If Mode == LSBFIRST                                    ' Send LSB first    
       REPEAT Bits
          outa[Dpin] := Value                              ' Set output
          Value := Value >> 1                              ' Shift value right
          !outa[Cpin]                                      ' cycle clock
          !outa[Cpin]
          waitcnt(1000 + cnt)                              ' delay

    elseIf Mode == MSBFIRST                                ' Send MSB first               
       REPEAT Bits                                                                
          outa[Dpin] := Value >> (bits-1)                  ' Set output           
          Value := Value << 1                              ' Shift value right    
          !outa[Cpin]                                      ' cycle clock          
          !outa[Cpin]                                                             
          waitcnt(1000 + cnt)                              ' delay                
    outa[Dpin]~                                            ' Set data to low

con
  MSBPRE   = 0
  LSBPRE   = 1
  MSBPOST  = 2
  LSBPOST  = 3
     
PUB SHIFTIN (Dpin, Cpin, Mode, Bits) : Value | InBit
{{
   Shift data in, master clock, for mode use BS2#MSBPRE, #MSBPOST, #LSBPRE, #LSBPOST
   Clock rate is ~16Kbps.  Use at 80MHz only is recommended.
     X := BS2.SHIFTIN(5,6,BS2#MSBPOST,8)
}}
    dira[Dpin]~                                            ' Set data pin to input
    outa[Cpin]:=0                                          ' Set clock low 
    dira[Cpin]~~                                           ' Set clock pin to output 
                                                
    If Mode == MSBPRE                                      ' Mode - MSB, before clock
       Value:=0
       REPEAT Bits                                         ' for number of bits
          InBit:= ina[Dpin]                                ' get bit value
          Value := (Value << 1) + InBit                    ' Add to  value shifted by position
          !outa[Cpin]                                      ' cycle clock
          !outa[Cpin]
          waitcnt(1000 + cnt)                              ' time delay

    elseif Mode == MSBPOST                                 ' Mode - MSB, after clock              
       Value:=0                                                          
       REPEAT Bits                                         ' for number of bits                    
          !outa[Cpin]                                      ' cycle clock                         
          !outa[Cpin]                                         
          InBit:= ina[Dpin]                                ' get bit value                          
          Value := (Value << 1) + InBit                    ' Add to  value shifted by position                                         
          waitcnt(1000 + cnt)                              ' time delay                            
                                                                 
    elseif Mode == LSBPOST                                 ' Mode - LSB, after clock                    
       Value:=0                                                                                         
       REPEAT Bits                                         ' for number of bits                         
          !outa[Cpin]                                      ' cycle clock                          
          !outa[Cpin]                                                                             
          InBit:= ina[Dpin]                                ' get bit value                        
          Value := (InBit << (bits-1)) + (Value >> 1)      ' Add to  value shifted by position    
          waitcnt(1000 + cnt)                              ' time delay                           

    elseif Mode == LSBPRE                                  ' Mode - LSB, before clock             
       Value:=0                                                                                   
       REPEAT Bits                                         ' for number of bits                   
          InBit:= ina[Dpin]                                ' get bit value                        
          Value := (Value >> 1) + (InBit << (bits-1))      ' Add to  value shifted by position    
          !outa[Cpin]                                      ' cycle clock                          
          !outa[Cpin]                                                                             
          waitcnt(1000 + cnt)                              ' time delay                           

PUB FREQOUT_SET(Pin, Frequency) 
{{
   Plays frequency defined on pin INDEFINATELY does NOT support dual frequencies.
   Use Frequency of 0 to stop.
     BS2.FREQOUT_Set(5, 2500)  ' Produces 2500Hz on Pin 5 forever
     BS2.FREQOUT_Set(5,0)      ' Turns off frequency     
}}
   If Frequency <> Last_Freq                               ' Check to see if freq change
      Update(Pin,Frequency,0)                              ' update tone 
      Last_Freq := Frequency                               ' save last

PRI update(pin, freq, ch) | temp

{{updates either the A or B counter modules.

  Parameters:
    pin  - I/O pin to transmit the square wave
    freq - The frequency in Hz
    ch   - 0 for counter module A, or 1 for counter module B
  Returns:
    The value of cnt at the start of the signal
    Adapted from Code by Andy Lindsay
}}

      if freq == 0                                         ' freq = 0 turns off square wave
        waitpeq(0, |< pin, 0)                              ' Wait for low signal
        ctra := 0                                          ' Set CTRA/B to 0
        dira[pin]~                                         ' Make pin input
      temp := pin                                          ' CTRA/B[8..0] := pin
      temp += (%00100 << 26)                               ' CTRA/B[30..26] := %00100
      ctra := temp                                         ' Copy temp to CTRA/B
      frqa := calcFrq(freq)                                ' Set FRQA/B
      phsa := 0                                            ' Clear PHSA/B (start cycle low)
      dira[pin]~~                                          ' Make pin output
      result := cnt                                        ' Return the start time

PRI CalcFrq(freq)

  {Solve FRQA/B = frequency * (2^32) / clkfreq with binary long
  division (Thanks Chip!- signed Andy).
  
  Note: My version of this method relied on the FloatMath object.
  Not surprisingly, Chip's solution takes a fraction program space,
  memory, and time.  It's the binary long-division approach, which
  implements with the binary
  long division approach - Andy Lindsay, Parallax }  

  repeat 33                                    
    result <<= 1
    if freq => clkfreq
      freq -= clkfreq
      result++        
    freq <<= 1
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}     
