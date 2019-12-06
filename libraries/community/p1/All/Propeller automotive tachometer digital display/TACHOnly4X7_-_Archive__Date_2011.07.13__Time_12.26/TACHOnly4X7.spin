
{{ last edit session: 07'12'2011
*******************************************************************************                                                                                                                  
* TACHOMETER PROGRAM FOR A 4X7 SEGMENT LED NUMERIC DISPLAY                    *
* Author: Stan Cloyd                                                          * 
* Copyrite (c) 2011 Stan Cloyd                                                * 
* See end of file for terms of use.                                           *
*******************************************************************************
THIS APPLICATION IS DESIGNED TO RUN WITH AND SYNTH.SPIN AND jm_freqin.spin.
SYNTH.SPIN GENERATES A CLOCK PULSE COMPATIBLE WITH THE HARDWARE.
jm_freqin.spin calculates the frequency of a tachometer pulse generated by the
distributor or ECM of an internal combustion engine. 
CONSTANTS USED ARE FOR A 4-CYLINDER 4-STROKE ICE.
PUB SHIFTOUT TRANSMITS A STRING OF BITS TO A MOTOROLLA MC14489 DISPLAY DRIVER.
PUB DTH CONVERTS A DECIMAL NUMBER TO A HEX STRING IN MSB FIRST ORDER per the MC14489
specification sheet.   
}}
                                                 
CON
  _clkmode = xtal1 + pll16x
  _xinfreq = 5_000_000
  Dpin = 16                  'P16 - Prop TO PIN 12 DATA line.
  Cpin = 17                  'P17 - prop to pin 11 CLOCK line.
  Epin = 18                  'P18 - prop to pin 10 ENABLE line.
  Frequency = 8158           'MAX FREQ THAT PUB SHIFTOUT WORKS WITH IS 8158 Hz
  ANUN1=$6689                'REVERSE ORDER (MSB FIRST) FOR RPM IN SPECIAL DECODE
  RST   = $00                'CLEAR MC14489 GLITCHES
  CNFG1 = $FF                'special decode
  CNFG2 = $01                'hex decode
  
OBJ
                                                        'Author Credits:
  Freq : "Synth"      'synthesize a clock signal         Original Author: Chip Gracey
                                                        'Modified by Beau Schwabe 
                                                        'Copyriht (c) 2007 Parallax
  fc   : "jm_freqin"  'read frequency on tach pin        Copyrite (c) 2009 Jon McPhalen                            
  
VAR
  LONG HXCD, revs, HUNRM, HUN, DECRM, DEC, UNO
  BYTE bits

pub main | f
  Freq.Synth("A",Cpin, Frequency)    'LAUNCH CLOCK PULSE COUNTER FOR THE MC14489 (OPERATES IN THE BKGND)
  fc.init(0)                         'SPECIFY PIN ZERO AS THE ONE TO MONITOR FOR A TACH SIGNAL                          
  repeat
    f := fc.freq                     'CALL FOR FREQUENCY WITH DOT NOTATION
    if f > 0                         'IS FREQUQENCY READING POSITIVE?                          
      revs:=f*300865/100000          'CALCULATE RPM (4-CYLINDER)
      DTH(REVS)                      'CALCULATE AND REORDER HEX EQUIVELANT DISPLAY VALUE (MSB FIRST)                     
      bits:=8
      SHIFTOUT(CNFG2)                'SETUP CONFIGURATION FOR HEX DECODE MODE
      bits:=24
      SHIFTOUT(HXCD)                 'SHIFTOUT HEXCODE BIT-STRING
      REVS:=0
      HXCD:=0                        
      WAITCNT(CLKFREQ/5+CNT)          'LIMIT SAMPLING SPEED FOR CORRECT LOW RPM MONITORING  
    else                              'IF THERE IS NO SIGNAL ON PIN ZERO DISPLAY ANNUNCIATOR (RPM)
      BITS:=8
      SHIFTOUT(CNFG1)                 'SETUP CONFIGURATIONM FOR SPECIAL DECODE MODE
      bits:=24                            
      shiftout(anun1)                 'SHIFTOUT SPECIAL DECODE STRING FOR RPM
      WAITCNT(CLKFREQ+CNT)            'REFRESH DISPLAY ONCE EACH SECOND WHILE F==0
      bits:=8
      SHIFTOUT(RST)                   'CLEAR OUT SHIFT REGISTER IN THE MC14489

PUB DTH(RPM)             'DECIMAL-TO-HEX CONVERSION FOR MOTOROLLA MC14489 DISPLAY DRIVER
  
  HXCD  := RPM / 1000           'LOAD THOUSANDS INTEGER OF RPM INTO STRING
  HUNRM := RPM // 1000          'SAVE REMAINDER
  HUN   := HUNRM / 100          'SAVE HUNDREDS INTEGER OF RPM
  HXCD  += HUN << 4             'SHIFT HEX FOR HUNDREDS VALUE INTO STRING 
  DECRM := HUNRM // 100         'SAVE DECIMAL REMAINDER VALUE
  DEC   := DECRM / 10           'SAVE DECIMAL VALUE OF RPM
  HXCD  += DEC << 8             'SHIFT HEX FOR DECIMAL VALUE INTO STRING 
  UNO   := DECRM // 10          'SAVE ONES VALUE
  HXCD  += UNO << 12            'SHIFT ONES INTO STRING
 
PUB SHIFTOUT(Sob) | done
  done := 0
  REPEAT Bits
    IF outa[Epin] == 1                'IF Enable pin inactive then activate/lower it. Epin initialized
                                      ' high when shiftout called.
       WAITPEQ( |< Cpin, |< Cpin, 0)  'Wait for clock to go high
       WAITPNE( |< Cpin, |< Cpin, 0)  'wait for clock to go low (permissive for change of
                                      'enable pin state)
       OUTA[Epin] := 0                'activate enable pin low (permissive for bit-string transfer)
       DIRA[Epin] ~~                  'Enable pin activated/lowered only when clock pin is low to
                                      'preserve syncronization.   
    DIRA[Dpin]~~
    OUTA[Dpin] := Sob >> (Bits-1)     'Dpin IS THE DATA PIN, So IS THE BIT STRING TO SEND, B IS
                                      'THE NUMBER OF BITS TO SEND.
    Sob := Sob << 1                 
    WAITPNE( |< Cpin, |< Cpin, 0)     'Wait for clock pin to go low.
    WAITPEQ( |< Cpin, |< Cpin, 0)     'Wait for clock pin to go high. 
  WAITPNE  ( |< Cpin, |< Cpin, 0)     'Wait for clock pin to go low.
  OUTA[Epin] := 1                     'Deactivate enable pin high. (permissive for display refresh)
  DIRA[Epin] ~~
  done := 1
dat
{{
  Copyright (c) 2011 Stan Cloyd aka:yarisboy

  Permission is hereby granted, free of charge, to any person obtaining a copy of this
  software and associated documentation files (the "Software"), to deal in the Software
  without restriction, including without limitation the rights to use, copy, modify,
  merge, publish, distribute, sublicense, and/or sell copies of the Software, and to
  permit persons to whom the Software is furnished to do so, subject to the following
  conditions:

  The above copyright notice and this permission notice shall be included in all copies
  or substantial portions of the Software.

  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
  INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
  PARTICULAR PURPOSE AND NON-INFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
  CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE
  OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. 

}}                   