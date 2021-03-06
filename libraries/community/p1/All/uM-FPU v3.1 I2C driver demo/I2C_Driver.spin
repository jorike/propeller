{{
┌──────────────────────────┬────────────────────┬────────────────────────┐
│   I2C_Driver.spin v1.2   │ Author: I. Kövesdi │ Release:   25 08 2008  │
├──────────────────────────┴────────────────────┴────────────────────────┤
│                    Copyright (c) 2008 CompElit Inc.                    │               
│                   See end of file for terms of use.                    │               
├────────────────────────────────────────────────────────────────────────┤
│                                                                        │
│  This is an I2C driver object implemented in SPIN. It uses only one COG│
│ for the SPIN interpreter.                                              │ 
│                                                                        │
├────────────────────────────────────────────────────────────────────────┤
│ Background and Detail:                                                 │
│  This I2C driver is designed for the uM-FPU driver object and beside   │
│ the basic I2C routines it contains additional procedures to facilitate │
│ easy FPU programming.                                                  │
│                                                                        │ 
├────────────────────────────────────────────────────────────────────────┤
│ Note:                                                                  │
│  The [read/write] clock speed of this driver is about [18/24] KHz and  │
│ the data burst rate is about [2/3] Kbytes/sec. If this speed is        │
│ adequate for your application you can use this simple I2C driver for   │
│ other I2C devices. In that case you can assemble your device specific  │
│ routines from the five basic I2C procedures: Start, Stop, Write(byte), │
│ ReadChar, Read(byte) as shown in the code for the FPU. The only        │
│ restriction is that every address/data is eight bit long. Beside the   │
│ I2C driver for the FPU there is another example of how to use this I2C │
│ driver. This is the DS1621_I2C_Driver in the package.                  │
│  You should know, that uM-FPU can communicate with much higher I2C bus │
│ speed (400 KHz) than this simple driver can provide.                   │ 
│  The write procedures of this driver usually return the acknowledge bit│
│ or bits for multiple byte write operations. This useful error detection│
│ feature, however, was not used in the demo application.                │
│  You can make this driver slightly faster by removing the lines dealing│
│ with clock streching.                                                  │
│                                                                        │  
└────────────────────────────────────────────────────────────────────────┘


}}
CON

'I2C constants
  _NAK            = 1
  _ACK            = 0

  _MAXSTRL        = 16              'Default Max. Str Length  


VAR

  byte  sda, scl                    'I2C line variables
  byte  str[_MAXSTRL]               'String buffer


'Data Flow within I2C_Driver object:
'=======================================
'This Driver object is implemented fully in SPIN.  Beside the 5 basic
'I2C routines (Start, Stop, Write(byte), WriteChar, Read(byte)) it
'contains many FPU specific procedures composed from the basic ones.
'All parameters between these levels are passed and returned by value.
'
'
'Data Flow between I2C_Driver object and a calling SPIN code object:
'===================================================================
'External SPIN code objects can call the available PUB procedures of this
'FPU_SPI_Driver object in the standard way. Except for the strings or 32
'bit variable arrays all parameters are passed by value. Strings and  32
'bit HUB register arrays are passed by reference. 

  
PUB Init(i2cSDA, i2cSCL) : okay
'-------------------------------------------------------------------------
'----------------------------------┌──────┐-------------------------------
'----------------------------------│ Init │-------------------------------
'----------------------------------└──────┘-------------------------------
'-------------------------------------------------------------------------
''     Action: Initilizes I2C bus lines
''             Cheks for HIGH and STABLE lines                                          
'' Parameters: I2C lines                                         
''    Results: okay (in HUB memory) if everybody is on board.         
''+Reads/Uses: /sda, scl
''    +Writes: sda, scl
''      Calls: None
'-------------------------------------------------------------------------
  sda := i2cSDA          'Initialize I2C line variables
  scl := i2cSCL
  
  dira[sda] ~            'Define them as inputs
  dira[scl] ~
  outa[sda] := 0         'These are the only 2 "outa"s in this driver
  outa[scl] := 0         'and they are yet hidden, as sda, scl are inputs
                         'at the moment and the pull up resistors pull the
                         'lines up to HIGH.
                         'SDA, SCL lines can be driven from HIGH to LOW by
                         'changing them from input to output. Switching
                         'them back as inputs releases the lines to go off
                         'HIGH again by the pull up resistors

  'Some I2C device maybe left in an invalid state, try to reinitialize...                       
  dira[scl] ~~           'Set SCL to LOW
  repeat 9               'Put out up to 9 clock pulses
    dira[scl] ~          'SCL goes to HIGH
    dira[scl] ~~         'SCL goes to LOW
    if ina[sda]          'Repeat if SDA is driven LOW erroneously by a
      quit               'hanged up device
  dira[scl] ~            'Set SCL to HIGH     

  'Both SDA and SCL  should be HIGH now as with an I2C bus at idle
  okay := true
  repeat 1000            'Check for stable HIGH SDA and SCL for a while 
    if (ina[sda] == 0)   
      okay := false
    if (ina[scl] == 0)
      okay := false

  return okay
'-------------------------------------------------------------------------
    

PUB PingDeviceAt(addr) : okay | ackBit
'-------------------------------------------------------------------------
'----------------------------┌──────────────┐-----------------------------
'----------------------------│ PingDeviceAt │-----------------------------
'----------------------------└──────────────┘-----------------------------
'-------------------------------------------------------------------------
''     Action: Sends Device Address and listens to the ACK bit from that
''             address                                                      
'' Parameters: Device Address                                         
''    Results: Okay if Device Address ACKnowledged                             
''+Reads/Uses: /_ACK
''    +Writes: None
''      Calls: Start, Write, Stop
'-------------------------------------------------------------------------
  Start
  ackBit := Write(addr | 0)
  Stop
  
  if ackBit == _ACK
    okay := true
  else
    okay := false
    
  return okay
'-------------------------------------------------------------------------

  
PUB ReadByteFrom(addr, reg) : i2cData | ackBits
'-------------------------------------------------------------------------
'------------------------------┌──────────────┐---------------------------
'------------------------------│ ReadByteFrom │---------------------------
'------------------------------└──────────────┘---------------------------
'-------------------------------------------------------------------------
''     Action: Reads a byte from a Device's Register                                                      
'' Parameters: Device Address, Device Register                                         
''    Results: I2C Data byte in the LS byte of i2cData(32 bit)                             
''+Reads/Uses: /_NAK
''    +Writes: None
''      Calls: Start, Write, Read, Stop
'-------------------------------------------------------------------------
  ackBits := 0

  Start
  ackBits := (ackBits << 1) | Write(addr)      
  ackBits := (ackBits << 1) | Write(reg)      
    
  Start
  ackBits := (ackBits << 1) | Write(addr | 1)   'Address with Read bit set
  i2cData := Read(_NAK)
  Stop

  'Return the data      
  return i2cData
'-------------------------------------------------------------------------


PUB Read2BytesFrom(addr, reg) : i2cData | ackBits, dataByte
'-------------------------------------------------------------------------
'---------------------------┌────────────────┐----------------------------
'---------------------------│ Read2BytesFrom │----------------------------
'---------------------------└────────────────┘----------------------------
'-------------------------------------------------------------------------
''     Action: Reads 2 bytes from a Device's Register                                                      
'' Parameters: Device Address, Device Register                                         
''    Results: 2 I2C Data bytes in the lower 2 bytes of i2cData(32 bit)                            
''+Reads/Uses: /_ACK, _NAK
''    +Writes: None
''      Calls: Start, Write, Read, Stop
'-------------------------------------------------------------------------
  ackBits := 0

  Start
  ackBits := (ackBits << 1) | Write(addr)      
  ackBits := (ackBits << 1) | Write(reg)      
    
  Start
  ackBits := (ackBits << 1) | Write(addr | 1) 'Address with Read bit set
  dataByte := Read(_ACK)
  i2cData := dataByte << 8
  dataByte := Read(_NAK)
  i2cData := i2cData + dataByte
  Stop

  'Return the data      
  return i2cData
'-------------------------------------------------------------------------

  
PUB ReadRegFrom(addr, reg) : i2cData | ackBits, dataByte
'-------------------------------------------------------------------------
'----------------------------┌─────────────┐------------------------------
'----------------------------│ ReadRegFrom │------------------------------
'----------------------------└─────────────┘------------------------------
'-------------------------------------------------------------------------
''     Action: Reads a 32 bit value from a Device's Register                                                      
'' Parameters: Device Address, Device Register                                         
''    Results: 32 bit i2cData                             
''+Reads/Uses: /_ACK, _NAK
''    +Writes: None
''      Calls: Start, Write, Read, Stop
'-------------------------------------------------------------------------
  ackBits := 0

  Start
  ackBits := (ackBits << 1) | Write(addr)      
  ackBits := (ackBits << 1) | Write(reg)      
    
  Start
  ackBits := (ackBits << 1) | Write(addr | 1) 'Repeat with read bit set
  dataByte := Read(_ACK)
  i2cData := dataByte << 8
  dataByte := Read(_ACK)
  i2cData := i2cData + dataByte
  i2cData := i2cData << 8
  dataByte := Read(_ACK)
  i2cData := i2cData + dataByte
  i2cData := i2cData << 8
  dataByte := Read(_NAK)
  i2cData := i2cData + dataByte
  Stop

  'Return the data      
  return i2cData
'-------------------------------------------------------------------------


PUB ReadStrFrom(addr, reg) : strPtr | ackBits, char, cntr, done
'-------------------------------------------------------------------------
'----------------------------┌─────────────┐------------------------------
'----------------------------│ ReadStrFrom │------------------------------
'----------------------------└─────────────┘------------------------------
'-------------------------------------------------------------------------
''     Action: Reads a String from a Device's register                                                      
'' Parameters: Device Address, Register                                         
''    Results: Pointer to string in HUB memory.                             
''+Reads/Uses: /str,_MAXSTRL
''    +Writes: str
''      Calls: Start, Write, Read, Stop
'------------------------------------------------------------------------- 
  ackBits := 0
  Start
  ackBits := (ackBits << 1) | Write(addr)      
  ackBits := (ackBits << 1) | Write(reg)      
  Start
  ackBits := (ackBits << 1) | Write(addr | 1)'Repeat with read bit set
  done := false
  cntr := 0 
  repeat 
    char := ReadChar
    str[cntr++] := char
    if (char == 0)
      done := true
    if cntr > (_MAXSTRL - 1)
      done := true
      str[_MAXSTRL - 1] := 0  
  until done
  Stop

  'Return the pointer to the string      
  return @str
'-------------------------------------------------------------------------

    
PUB WriteByteTo(addr, reg, lng) : ackBits
'-------------------------------------------------------------------------
'----------------------------┌─────────────┐------------------------------
'----------------------------│ WriteByteTo │------------------------------
'----------------------------└─────────────┘------------------------------
'-------------------------------------------------------------------------
''     Action: Writes one byte (LS byte of a 32 bit long) to a Device's
''             register                                                        
'' Parameters: Device Address, Register, Long value                                         
''    Results: ackBits                             
''+Reads/Uses: None
''    +Writes: None
''      Calls: Start, Write, Stop
'-------------------------------------------------------------------------
'Return the ACK bits from the device address
  ackBits := 0
  Start
  ackBits := (ackBits << 1) | Write(addr)
  ackBits := (ackBits << 1) | Write(reg)
  ackBits := (ackBits << 1) | Write(lng)
  Stop

  return ackBits
'-------------------------------------------------------------------------


PUB Write2BytesTo(addr, reg, b1, b2) : ackBits
'-------------------------------------------------------------------------
'---------------------------┌───────────────┐-----------------------------
'---------------------------│ Write2BytesTo │-----------------------------
'---------------------------└───────────────┘-----------------------------
'-------------------------------------------------------------------------
''     Action: Writes 2 bytes (LS bytes of two 32 bit longs) to a Device's
''             register                                                        
'' Parameters: Device Address, Register, 2 Long values                                         
''    Results: ackBits                             
''+Reads/Uses: None
''    +Writes: None
''      Calls: Start, Write, Stop
'-------------------------------------------------------------------------
'Write two bytes to the device's register 
'Return the ACK bits from the device address
  ackBits := 0
  Start
  ackBits := (ackBits << 1) | Write(addr)
  ackBits := (ackBits << 1) | Write(reg)
  ackBits := (ackBits << 1) | Write(b1)
  ackBits := (ackBits << 1) | Write(b2)
  Stop

  return ackBits
'-------------------------------------------------------------------------


PUB Write3BytesTo(addr, reg, b1, b2, b3) : ackBits
'-------------------------------------------------------------------------
'-----------------------------┌───────────────┐---------------------------
'-----------------------------│ Write3BytesTo │---------------------------
'-----------------------------└───────────────┘---------------------------
'-------------------------------------------------------------------------
''     Action: Writes 3 bytes (LS bytes of 3 32 bit longs) to a Device's
''             register                                                        
'' Parameters: Device Address, Register, 3 Longs                                         
''    Results: ackBits                             
''+Reads/Uses: None
''    +Writes: None
''      Calls: Start, Write, Stop
'-------------------------------------------------------------------------
  ackBits := 0
  Start
  ackBits := (ackBits << 1) | Write(addr)
  ackBits := (ackBits << 1) | Write(reg)
  ackBits := (ackBits << 1) | Write(b1)
  ackBits := (ackBits << 1) | Write(b2)
  ackBits := (ackBits << 1) | Write(b3)
  Stop

  return ackBits  
'-------------------------------------------------------------------------


PUB Write4BytesTo(addr, reg, b1, b2, b3, b4) : ackBits
'-------------------------------------------------------------------------
'-----------------------------┌───────────────┐---------------------------
'-----------------------------│ Write4BytesTo │---------------------------
'-----------------------------└───────────────┘---------------------------
'-------------------------------------------------------------------------
''     Action: Writes 4 bytes (LS bytes of 4 32 bit longs) to a Device's
''             register                                                        
'' Parameters: Device Address, Register, 4 Longs                                         
''    Results: ackBits                             
''+Reads/Uses: None
''    +Writes: None
''      Calls: Start, Write, Stop
'-------------------------------------------------------------------------
  ackBits := 0
  Start
  ackBits := (ackBits << 1) | Write(addr)
  ackBits := (ackBits << 1) | Write(reg)
  ackBits := (ackBits << 1) | Write(b1)
  ackBits := (ackBits << 1) | Write(b2)
  ackBits := (ackBits << 1) | Write(b3)
  ackBits := (ackBits << 1) | Write(b4)
  Stop

  return ackBits  
'-------------------------------------------------------------------------

  
PUB Write5BytesTo(addr, reg, b1, b2, b3, b4, b5) : ackBits
'-------------------------------------------------------------------------
'-----------------------------┌───────────────┐---------------------------
'-----------------------------│ Write5BytesTo │---------------------------
'-----------------------------└───────────────┘---------------------------
'-------------------------------------------------------------------------
''     Action: Writes 5 bytes (LS bytes of 5 32 bit longs) to a Device's
''             register                                                        
'' Parameters: Device Address, Register, 5 Longs                                         
''    Results: ackBits                             
''+Reads/Uses: None
''    +Writes: None
''      Calls: Start, Write, Stop
'-------------------------------------------------------------------------
  ackBits := 0
  Start
  ackBits := (ackBits << 1) | Write(addr)
  ackBits := (ackBits << 1) | Write(reg)
  ackBits := (ackBits << 1) | Write(b1)
  ackBits := (ackBits << 1) | Write(b2)
  ackBits := (ackBits << 1) | Write(b3)
  ackBits := (ackBits << 1) | Write(b4)
  ackBits := (ackBits << 1) | Write(b5)
  Stop

  return ackBits  
'-------------------------------------------------------------------------


PUB Write6BytesTo(addr, reg, b1, b2, b3, b4, b5, b6) : ackBits
'-------------------------------------------------------------------------
'----------------------------┌───────────────┐----------------------------
'----------------------------│ Write6BytesTo │----------------------------
'----------------------------└───────────────┘----------------------------
'-------------------------------------------------------------------------
''     Action: Writes 6 bytes (LS bytes of 6 32 bit longs) to a Device's
''             register                                                        
'' Parameters: Device Address, Register, 6 Longs                                         
''    Results: ackBits                             
''+Reads/Uses: None
''    +Writes: None
''      Calls: Start, Write, Stop
'-------------------------------------------------------------------------
  ackBits := 0
  Start
  ackBits := (ackBits << 1) | Write(addr)
  ackBits := (ackBits << 1) | Write(reg)
  ackBits := (ackBits << 1) | Write(b1)
  ackBits := (ackBits << 1) | Write(b2)
  ackBits := (ackBits << 1) | Write(b3)
  ackBits := (ackBits << 1) | Write(b4)
  ackBits := (ackBits << 1) | Write(b5)
  ackBits := (ackBits << 1) | Write(b6)
  Stop

  return ackBits
'-------------------------------------------------------------------------


PUB Write2BytesRegsTo(addr,reg,com,cntr,fPtr):ackB|cn,fv,b1,b2,b3,b4
'-------------------------------------------------------------------------
'-------------------------┌───────────────────┐---------------------------
'-------------------------│ Write2BytesRegsTo │---------------------------
'-------------------------└───────────────────┘---------------------------
'-------------------------------------------------------------------------
''     Action: Writes 2 bytes (2 LS bytes of Longs) and an Array of 32 bit
''             values (Floats or Longs) into a Device's Register                                                      
'' Parameters: Device Address, Register, Command byte, Counter byte,
''             pointer to Array of 32 bit values                                         
''    Results: ackB(its)                             
''+Reads/Uses: None
''    +Writes: None
''      Calls: Start, Write, Stop 
'------------------------------------------------------------------------- 
  ackB := 0
  Start
  ackB := (ackB << 1) | Write(addr)
  ackB := (ackB << 1) | Write(reg)
  ackB := (ackB << 1) | Write(com)
  ackB := (ackB << 1) | Write(cntr)
  cn := 0
  repeat cntr
    fv := long[fPtr][cn++]
    b4 := fv & $000000FF
    b3 := (fv ->= 8) & $000000FF
    b2 := (fv ->= 8) & $000000FF
    b1 := (fv ->= 8) & $000000FF
    ackB := (ackB << 1) | Write(b1)
    ackB := (ackB << 1) | Write(b2)
    ackB := (ackB << 1) | Write(b3)
    ackB := (ackB << 1) | Write(b4)          
  Stop

  return ackB
'-------------------------------------------------------------------------


PUB WriteByteStrTo(addr, reg, b, longPtr) : ackBits | cntr, char
'-------------------------------------------------------------------------
'--------------------------┌────────────────┐-----------------------------
'--------------------------│ WriteByteStrTo │-----------------------------
'--------------------------└────────────────┘-----------------------------
'-------------------------------------------------------------------------
''     Action: Writes a comand byte plus a String to a Device's Register                                                         
'' Parameters: Device Address, Register, Command byte, pointer to an array
''             of longs that contains in the LS bytes the original bytes
''             of the string.                                          
''    Results: ackBits                             
''+Reads/Uses: None
''    +Writes: None
''      Calls: Start, Write, Stop
''      Note.: "Write" writes bytes embedded in longs/LSB
'------------------------------------------------------------------------- 
  ackBits := 0
  Start
  ackBits := (ackBits << 1) | Write(addr)
  ackBits := (ackBits << 1) | Write(reg)
  ackBits := (ackBits << 1) | Write(b)
  cntr := 0  
  repeat
    char := long[longPtr][cntr++]
    ackBits := (ackBits << 1) | Write(char)
  until (char == 0)
  Stop
  
  return ackBits
'-------------------------------------------------------------------------


'Now come the basic I2C routines...


PUB Start
'-------------------------------------------------------------------------
'---------------------------------┌───────┐-------------------------------
'---------------------------------│ Start │-------------------------------
'---------------------------------└───────┘-------------------------------
'-------------------------------------------------------------------------
''     Action: Starts I2C bus                                                      
'' Parameters: None                                         
''    Results: None                             
''+Reads/Uses: /sda, scl
''    +Writes: None
''      Calls: None
'-------------------------------------------------------------------------
'I2C START sequence - the SDA goes from HIGH to LOW while SCL is HIGH
  dira[sda] ~                  'SDA released, i.e. goes to HIGH
  dira[scl] ~                  'SCL released, i.e. goes to HIGH
  repeat until ina[scl] == 1   'Check for clock stretching
  dira[sda] ~~                 'SDA drived to LOW while SCL HIGH: START!   
       
   
PUB Stop
'-------------------------------------------------------------------------
'----------------------------------┌──────┐-------------------------------
'----------------------------------│ Stop │-------------------------------
'----------------------------------└──────┘-------------------------------
'-------------------------------------------------------------------------
''     Action: Stops I2C bus                                                      
'' Parameters: None                                         
''    Results: None                             
''+Reads/Uses: /scl, sda
''    +Writes: None
''      Calls: None
'-------------------------------------------------------------------------
'I2C STOP sequence - the SDA goes from LOW to HIGH while SCL is HIGH
  dira[scl] ~                  'SCL goes to HIGH
  dira[sda] ~~                 'Set SDA LOW first, then 
  dira[sda] ~                  'SDA goes to HIGH while SCL HIGH : STOP!
'-------------------------------------------------------------------------


PUB Read(ackBit): lng
'-------------------------------------------------------------------------
'----------------------------------┌──────┐-------------------------------
'----------------------------------│ Read │-------------------------------
'----------------------------------└──────┘-------------------------------
'-------------------------------------------------------------------------
''     Action: Reads a Byte from the I2C bus
''             Sends ackBit in response                                                       
'' Parameters: ackBit                                        
''    Results: I2C Data Byte                             
''+Reads/Uses: /sda, scl
''    +Writes: None
''      Calls: None
'-------------------------------------------------------------------------
  'Set the SDA to input and SCL to output 
  dira[sda]~                     'Slave drives the SDA from now
  dira[scl]~~                    'SCL goes to LOW
     
  'Clock in the byte
  lng := 0
  repeat 8
    dira[scl]~                   'SCL goes to HIGH: Latch in SDA
    repeat until ina[scl] == 1   'Check for clock stretching
    lng := (lng << 1) | ina[sda] 'Read in SDA line
    dira[scl]~~                  'SCL goes to LOW, clock pulse finished.
                                 'Pulse width is about 42 us at 80 MHz and   
                                 'leading edge separation is about 55 us
                                 'Bit rate is 18 KHz, approximately
                                 'You can speed this a little bit up if
                                 'you remove the check for clock streching
                                 '(then approx. 25 KHz)
      
  'Send the ACK or NAK bit
  dira[sda] := !ackBit           'Prop drives the SDA again
  dira[scl]~                     'Toggle SCL HIGH
  dira[scl]~~                    'Toggle SCL LOW

  'Return the data in a 32 bit register
  return lng
'-------------------------------------------------------------------------


PUB ReadChar : i2cChar | ackB
'-------------------------------------------------------------------------
'-------------------------------┌──────────┐------------------------------
'-------------------------------│ ReadChar │------------------------------
'-------------------------------└──────────┘------------------------------
'-------------------------------------------------------------------------
''     Action: Reads a Char Byte from the I2C bus
''             Sends ACK for response to all nonzero char and NAK for
''             response to zero Char                                                       
''Parameters: None                                        
''   Results: I2C Char Byte                             
''Reads/Uses: /sda, scl, _ACK, _NAK
''   +Writes: None
''     Calls: None
'-------------------------------------------------------------------------
  'Set the SDA to input and SCL to output 
  dira[sda]~
  dira[scl]~~
     
  'Clock in the character
  i2cChar := 0
  repeat 8
    dira[scl]~                            'SCL goes to HIGH: Latch in SDA
    repeat until ina[scl] == 1            'Check for clock stretching
    i2cChar := (i2cChar << 1) | ina[sda]  'Read in SDA line
    dira[scl]~~                           'SCL goes to LOW

  'Check for end of string
  if i2cChar == 0
    ackB := _NAK     
  else
    ackB := _ACK

  'Send the ACK or NAK  
  dira[sda] := !ackB     
  dira[scl]~                       'Toggle SCL HIGH
  dira[scl]~~                      'Toggle SCL LOW
    
  'Return the character
  return i2cChar
'-------------------------------------------------------------------------

    
PUB Write(lng) : ackBit
'-------------------------------------------------------------------------
'---------------------------------┌───────┐-------------------------------
'---------------------------------│ Write │-------------------------------
'---------------------------------└───────┘-------------------------------
'-------------------------------------------------------------------------
''     Action:  Writes a byte to the I2C bus                                                     
'' Parameters:  Byte (in LS byte of a Long value)                                        
''    Results:  ackBit                            
''+Reads/Uses:  /scl, sda
''    +Writes:  None
''      Calls:  None
'-------------------------------------------------------------------------    
  lng <<= 24                       'Move  databyte from LS to MS position

  dira[scl]~~                      'Set the clock line to LOW

  'SDA line will be set during SCL line LOW. Data latched at the leading
  'edge of SCL clock pulse
  repeat 8
    dira[sda] := (!(lng <-= 1)&1)  'Set SDA according to data bit          
    dira[scl]~                     'Toggle SCL HIGH
    dira[scl]~~                    'Toggle SCL LOW
                             'Pulse width is about 10 us at 80 MHz and    
                             'leading edge separation is about 42 us.
                             'Bit rate is 24 KHz, approximately                                      
   
  'Read ACK bit from the addressed/responding slave
  dira[sda]~                       'Let SDA be drived by slaves    
  dira[scl]~                       'Toggle SCL HIGH to latch ACK bit
  ackBit := ina[sda]               'Read in the ACK bit   
  dira[scl]~~                      'Toggle SCL LOW  

  return ackBit              'Nonzero ACK bit usually (i.e. not always)
                             'means ERROR!. Calling code may check it.
'-------------------------------------------------------------------------


{{
┌────────────────────────────────────────────────────────────────────────┐
│                        TERMS OF USE: MIT License                       │                                                            
├────────────────────────────────────────────────────────────────────────┤
│  Permission is hereby granted, free of charge, to any person obtaining │
│ a copy of this software and associated documentation files (the        │ 
│ "Software"), to deal in the Software without restriction, including    │
│ without limitation the rights to use, copy, modify, merge, publish,    │
│ distribute, sublicense, and/or sell copies of the Software, and to     │
│ permit persons to whom the Software is furnished to do so, subject to  │
│ the following conditions:                                              │
│                                                                        │
│  The above copyright notice and this permission notice shall be        │
│ included in all copies or substantial portions of the Software.        │  
│                                                                        │
│  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND        │
│ EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF     │
│ MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. │
│ IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY   │
│ CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,   │
│ TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE      │
│ SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                 │
└────────────────────────────────────────────────────────────────────────┘
}}                                                                  