{{
┌────────────────────────────┬──────────────────┬────────────────────────┐
│ FPU32_ARITH_Demo.spin v3.0 │ Author:I.Kövesdi │ Release: 30 June 2011  │
├────────────────────────────┴──────────────────┴────────────────────────┤
│                    Copyright (c) 2011 CompElit Inc.                    │               
│                   See end of file for terms of use.                    │               
├────────────────────────────────────────────────────────────────────────┤
│  This is a terminal application to demonstrate uM-FPU v3.1 with 2-wire │
│ SPI connection. It exercises the FPU32_ARITH_Driver object. This driver│
│ focuses on basic arithmetics and uses one COG.                         │
│                                                                        │ 
├────────────────────────────────────────────────────────────────────────┤
│ Background and Detail:                                                 │
│  The FPU provides the user a comprehensive set of IEE 754 32-bit float,│
│ 32-bit LONG, string, FFT and matrix operations. It also has two 12-bit │
│ ADCs, a programmable serial TTL interface and an NMEA parser. The FPU  │
│ contains Flash memory and EEPROM for storing user defined functions and│
│ data and 128 32-bit registers for 32-bit FLOAT and 32-bit LONG data.   │
│  Mobilizing the User Defined Function capabilities of the FPU, compact │
│ code and fast data processing speed can be achieved with low-cost and  │
│ low power consumption in your embedded application.                    │
│                                                                        │    
├────────────────────────────────────────────────────────────────────────┤
│ Note:                                                                  │
│  The ARITH driver is a member of a family of drivers for the uM-FPU    │
│ v3.1 with 2-wire SPI connection. The family has been placed on OBEX:   │
│                                                                        │
│  FPU32_SPI     (Core driver of the FPU32 family)                       │
│ *FPU32_ARITH   (Basic arithmetic operations)                           │
│  FPU32_MATRIX  (Basic and advanced matrix operations)                  │
│  FPU32_FFT     (FFT with advanced options as, e.g. ZOOM FFT)     (soon)│
│                                                                        │
│  The procedures and functions of these drivers can be cherry picked and│
│ used together to build application specific uM-FPU v3.1 drivers.       │
│  Other specialized drivers, as GPS, MEMS, IMU, MAGN, NAVIG, ADC, DSP,  │
│ ANN, STR are in preparation with similar cross-compatibility features  │
│ around the instruction set and with the user defined function ability  │
│ of the uM-FPU v3.1.                                                    │
│                                                                        │
└────────────────────────────────────────────────────────────────────────┘
}}

CON

_CLKMODE = XTAL1 + PLL16X
_XINFREQ = 5_000_000

{
Schematics

                                              5V(REG)           
                                               │                     
P   │                                   10K    │  
  A3├4────────────────────────────┳─────────┫   
R   │                              │           │
  A4├5────────────────────┐       │           │
O   │                      │       │           │ 
  A5├6────┳──────┐                        │
P   │       │      12     16       1           │
            │    ┌──┴──────┴───────┴──┐        │                               
          1K    │ SIN   SCLK   /MCLR │        │                  
            │    │                    │        │
            │    │                AVDD├18──────┫       
            └─11┤SOUT             VDD├14──────┘
                 │                    │         
                 │     uM-FPU 3.1     │
                 │                    │                                                                                           
            ┌───4┤CS                  │         
            ┣───9┤SIN                 │             
            ┣──17┤AVSS                │         
            ┣──13┤VSS                 │         
            │    └────────────────────┘
            
           GND

The CS pin(4) of the FPU is tied to LOW to select SPI mode at Reset and
must remain LOW during operation. For this Demo the 2-wire SPI connection
was used, where the SOUT and SIN pins were connected through a 1K resistor
and the DIO pin(6) of the Propeller was connected to the SIN pin(12) of
the FPU.
}


'--------------------------------Connections------------------------------
'            On Propeller                           On FPU
'-----------------------------------  ------------------------------------
'Sym.   A#/IO       Function            Sym.  P#/IO        Function
'-------------------------------------------------------------------------
_MCLR = 3 'Out  FPU Master Clear   -->  MCLR  1  In   Master Clear
_FCLK = 4 'Out  FPU SPI Clock      -->  CLK  16  In   SPI Clock Input     
_FDIO = 5 ' Bi  FPU SPI In/Out     -->  SIN  12  In   SPI Data In 
'       └─────────────────via 1K   <--  SOUT 11 Out   SPI Data Out


OBJ

PST     : "Parallax Serial Terminal"   'From Parallax Inc.
                                       'v1.0
                                       
FPU     : "FPU32_ARITH_Driver"         'v3.0

  
VAR

LONG  okay, fpu32, char
LONG  ptr
LONG  cog_ID

LONG  longs[12]

LONG  cntr, time, dTime


DAT '------------------------Start of SPIN code---------------------------

  
PUB StartApplication | addr_                           
'-------------------------------------------------------------------------
'---------------------------┌──────────────────┐--------------------------
'---------------------------│ StartApplication │--------------------------
'---------------------------└──────────────────┘--------------------------
'-------------------------------------------------------------------------
''     Action: -Starts driver objects
''             -Makes a MASTER CLEAR of the FPU and
''             -Calls 2 demo procedures
'' Parameters: None
''    Results: None
''+Reads/Uses: /fpu32 Hardware constants from CON section
''    +Writes: fpu32
''      Calls: FullDuplexSerialPlus--->PST.Start
''             FPU32_SPI_Driver ------>FPU.StartCOG
''                                     FPU.StopCOG 
''             FPU32_SPI_Demo 
'-------------------------------------------------------------------------
'Start FullDuplexSerialPlus DBG terminal
PST.Start(57600)
  
WAITCNT(6 * CLKFREQ + CNT)

PST.Char(PST#CS)
PST.Str(STRING("FPU32_ARITH_Driver demo started..."))
PST.Chars(PST#NL, 2)

WAITCNT(CLKFREQ + CNT)

addr_ := @cog_ID

fpu32 := FALSE

'FPU Master Clear...
PST.Str(STRING("FPU Master Clear...", PST#NL))
OUTA[_MCLR]~~ 
DIRA[_MCLR]~~
OUTA[_MCLR]~
WAITCNT(CLKFREQ + CNT)
OUTA[_MCLR]~~
DIRA[_MCLR]~
WAITCNT(CLKFREQ + CNT)

fpu32 := FPU.StartDriver(_FDIO, _FCLK, addr_)

IF fpu32

  PST.Char(PST#CS)
  PST.Str(STRING("FPU32_ARITH_Driver started in COG "))
  PST.Dec(cog_ID)
  PST.Chars(PST#NL, 2)
  WAITCNT(CLKFREQ + CNT)

  FPU32_ARITH_Demo
  
  PST.Char(PST#NL)
  PST.Str(STRING("FPU32_ARITH_Driver Demo terminated normally..."))

  FPU.StopDriver
   
ELSE
  PST.Char(PST#NL)
  PST.Str(STRING("FPU32_ARITH_Driver Start failed!"))
  PST.Str(STRING(PST#NL, PST#NL))

WAITCNT(CLKFREQ + CNT)

PST.Stop  
'-------------------------------------------------------------------------    


PRI FPU32_ARITH_Demo|i,r,c,floatVal,floatval2,floatRes,strPtr,strPtr2
'-------------------------------------------------------------------------
'---------------------------┌──────────────────┐--------------------------
'---------------------------│ FPU32_ARITH_Demo │--------------------------
'---------------------------└──────────────────┘--------------------------
'-------------------------------------------------------------------------
'     Action: Demonstrates some FPU features by calling 
'             FPU32_SPI_Driver procedures
' Parameters: None
'    Results: None
'+Reads/Uses: /okay, char, Some constants from the FPU object
'    +Writes: okay, char
'      Calls: FullDuplexSerialPlus------>PST.Str
'                                        PST.Dec
'                                        PST.Hex
'                                        PST.Bin   
'             FPU32_SPI_Driver --------->FPU. Most of the procedures
'-------------------------------------------------------------------------
PST.Char(PST#CS) 
PST.Str(STRING("---uM-FPU-V3.1 with 2-wire SPI connection---"))
PST.Char(PST#NL)

WAITCNT(CLKFREQ + CNT)

okay := FALSE
okay := Fpu.Reset
PST.Char(PST#NL)   
IF okay
  PST.Str(STRING("FPU Software Reset done..."))
  PST.Char(PST#NL)
ELSE
  PST.Str(STRING("FPU Software Reset failed..."))
  PST.Char(PST#NL)
  PST.Str(STRING("Please check hardware and restart..."))
  PST.Char(PST#NL)
  REPEAT

WAITCNT(CLKFREQ + CNT)

char := FPU.ReadSyncChar
PST.Char(PST#NL)
PST.Str(STRING("Response to _SYNC: $"))
PST.Hex(char, 2)
IF (char == FPU#_SYNC_CHAR)
  PST.Str(STRING("    (OK)"))
  PST.Char(PST#NL)  
ELSE
  PST.Str(STRING("   Not OK!"))   
  PST.Char(PST#NL)
  PST.Str(STRING("Please check hardware and restart..."))
  PST.Char(PST#NL)
  REPEAT

WAITCNT(CLKFREQ + CNT)

PST.Char(PST#NL)
PST.Str(STRING("   Version String: "))
FPU.WriteCmd(FPU#_VERSION)
FPU.Wait
PST.Str(FPU.ReadStr)

WAITCNT(CLKFREQ + CNT) 

PST.Char(PST#NL)
PST.Str(STRING("     Version Code: $"))
FPU.WriteCmd(FPU#_VERSION)
FPU.Wait
FPU.WriteCmd(FPU#_LREAD0)
PST.Hex(FPU.ReadReg, 8)

WAITCNT(CLKFREQ + CNT) 

PST.Char(PST#NL)
PST.Str(STRING(" Clock ticks / ms: "))
PST.Dec(FPU.ReadInterVar(FPU#_TICKS))
PST.Chars(PST#NL, 2) 

WAITCNT(CLKFREQ + CNT)

PST.Str(STRING("         Checksum: $"))
FPU.WriteCmd(FPU#_CHECKSUM)
FPU.Wait
FPU.WriteCmd(FPU#_LREAD0)
PST.Hex(FPU.ReadReg, 8)
PST.Char(PST#NL)

QueryReboot
    
PST.Char(PST#CS)    
PST.Str(STRING("Stored math constants:"))
PST.Chars(PST#NL, 2) 

PST.Str(STRING("         Pi = "))
FPU.WriteCmd(FPU#_LOADPI)
FPU.WriteCmdByte(FPU#_SELECTA, 0)
FPU.WriteCmdByte(FPU#_FTOA, 0)
WAITCNT(FPU#_FTOAD + CNT)
FPU.Wait
PST.Str(FPU.ReadStr)
PST.Char(PST#NL)
 
PST.Str(STRING("          e = "))
FPU.WriteCmd(FPU#_LOADE)
FPU.WriteCmdByte(FPU#_SELECTA, 0)
FPU.WriteCmdByte(FPU#_FTOA, 0)
WAITCNT(FPU#_FTOAD + CNT)
FPU.Wait
PST.Str(FPU.ReadStr)
PST.Char(PST#NL)

PST.Char(PST#NL)
PST.Str(STRING("Some physical constants:"))
PST.Char(PST#NL)
PST.Char(PST#NL) 

PST.Str(STRING("  Speed of light c = "))
FPU.WriteCmdByte(FPU#_LOADCON, FPU#_C)
FPU.WriteCmdByte(FPU#_SELECTA, 0)
FPU.WriteCmdByte(FPU#_FTOA, 0)
WAITCNT(FPU#_FTOAD + CNT)
FPU.Wait
PST.Str(FPU.ReadStr)
PST.Str(STRING(" m/s", PST#NL))

PST.Str(STRING("Gravity constant g = "))
FPU.WriteCmdByte(FPU#_LOADCON, FPU#_MEANG)
FPU.WriteCmdByte(FPU#_SELECTA, 0)
FPU.WriteCmdByte(FPU#_FTOA, 0)
WAITCNT(FPU#_FTOAD + CNT)
FPU.Wait
PST.Str(FPU.ReadStr)
PST.Str(STRING(" m/s^2", PST#NL))
  
PST.Str(STRING("Int. Std. Atm. ISA = "))
FPU.WriteCmdByte(FPU#_LOADCON, FPU#_STDATM)
FPU.WriteCmdByte(FPU#_SELECTA, 0)
FPU.WriteCmdByte(FPU#_FTOA, 0)
WAITCNT(FPU#_FTOAD + CNT)
FPU.Wait
PST.Str(FPU.ReadStr)
PST.Str(STRING(" kPa", PST#NL))

QueryReboot

PST.Char(PST#CS)
PST.Str(STRING("Conversions between STRING and LONG or FLOAT"))
PST.Str(STRING(PST#NL, PST#NL))

FPU.WriteCmdByte(FPU#_SELECTA, 0)         'Let Reg[0] be Reg[A]      

'LONG to STRING
'Write SPIN generated LONG directly into FPU/Reg[A]. No conversion here
FPU.WriteCmdLONG(FPU#_LWRITEA, 3456789)
'Then read this long value back from Reg[A] as a string   
PST.Str(STRING("  3456789(LONG) as STRING: '"))
PST.Str(FPU.ReadRaLongAsStr(0))
PST.Str(STRING("'"))
PST.Char(PST#NL)

'STRING to LONG
'Convert a SPIN generated STRING into LONG in FPU/Reg[A]      
strPtr := STRING("1234567")
FPU.WriteCmdStr(FPU#_ATOL, strPtr)
'Display the LONG value in Reg[A] as a string  
PST.Str(STRING("'1234567'(STRING) as LONG: "))
PST.Str(FPU.ReadRaLongAsStr(0))
PST.Char(PST#NL)

'FLOAT to STRING
'Write SPIN generated FLOAT directly into FPU/Reg[A]. No conversion here
FPU.WriteCmdLONG(FPU#_FWRITEA, 3.141593)
'Display the FLOAT value in Reg[A] as a string   
PST.Str(STRING("3.141593(FLOAT) as STRING: '"))
PST.Str(FPU.ReadRaFloatAsStr(0))
PST.Str(STRING("'"))
PST.Char(PST#NL)

'STRING to FLOAT 
strPtr := STRING("2.7283")
'Convert a SPIN generated STRING into FLOAT in FPU/Reg[A] 
FPU.WriteCmdStr(FPU#_ATOF, strPtr)
'Display the FLOAT value in Reg[A] as a string   
PST.Str(STRING("'2.7283'(STRING) as FLOAT: "))
PST.Str(FPU.ReadRaFloatAsStr(0))
PST.Char(PST#NL)

QueryReboot

PST.Char(PST#CS)
PST.Str(STRING("Conversions between LONG and FLOAT"))
PST.Str(STRING(PST#NL, PST#NL))

'LONG to FLOAT
'Convert a SPIN generated LONG into FLOAT within the FPU
'Load LONG value
FPU.WriteCmdLONG(FPU#_LWRITEA, 45678)
'Convert it to FLOAT
FPU.WriteCmd(FPU#_FLOAT)  
'Display the FLOAT value in Reg[A] as a string   
PST.Str(STRING("     45678(LONG) as FLOAT: "))
PST.Str(FPU.ReadRaFloatAsStr(0))
PST.Char(PST#NL)

'FLOAT to LONG
'Convert a SPIN generated FLOAT into LONG within the FPU
'Load SPIN generated FLOAT value
FPU.WriteCmdLONG(FPU#_FWRITEA, 456.78)
'Convert it to LONG
FPU.WriteCmd(FPU#_FIXR)  
'Display the LONG value in Reg[A] as a string   
PST.Str(STRING("    456.78(FLOAT) as LONG: "))
PST.Str(FPU.ReadRaLongAsStr(0))
PST.Char(PST#NL)

QueryReboot

PST.Char(PST#CS)    
PST.Str(STRING("32-bit FLOAT addition"))
PST.Chars(PST#NL, 2)

strPtr := STRING("-1.123456")
floatVal := FPU.STR_To_F32(strPtr)

strPtr2 := STRING("9.876543")
floatVal2 := FPU.STR_To_F32(strPtr2)

floatRes := FPU.F32_ADD(floatVal, floatVal2)

PST.Str(strPtr)
PST.Char(PST#NL)
PST.Str(STRING("+"))
PST.Char(PST#NL)
PST.Str(strPtr2)
PST.Char(PST#NL)
PST.Str(STRING("="))
PST.Char(PST#NL)
PST.Str(FPU.F32_To_STR(floatRes, 0))
PST.Char(PST#NL)

QueryReboot

PST.Char(PST#CS)    
PST.Str(STRING("32-bit FLOAT subtraction"))
PST.Chars(PST#NL, 2)

strPtr := STRING("1.123456")
floatVal := FPU.STR_To_F32(strPtr)

strPtr2 := STRING("-9.876543")
floatVal2 := FPU.STR_To_F32(strPtr2)

floatRes := FPU.F32_SUB(floatVal, floatVal2)

PST.Str(strPtr)
PST.Char(PST#NL)
PST.Str(STRING("-"))
PST.Char(PST#NL)
PST.Str(strPtr2)
PST.Char(PST#NL)
PST.Str(STRING("="))
PST.Char(PST#NL)
PST.Str(FPU.F32_To_STR(floatRes, 0))
PST.Char(PST#NL)

QueryReboot

PST.Char(PST#CS)    
PST.Str(STRING("32-bit FLOAT multiplication"))
PST.Chars(PST#NL, 2)

strPtr := STRING("1.123456")
floatVal := FPU.STR_To_F32(strPtr)

strPtr2 := STRING("-9.876543")
floatVal2 := FPU.STR_To_F32(strPtr2)

floatRes := FPU.F32_MUL(floatVal, floatVal2)

PST.Str(strPtr)
PST.Char(PST#NL)
PST.Str(STRING("*"))
PST.Char(PST#NL)
PST.Str(strPtr2)
PST.Char(PST#NL)
PST.Str(STRING("="))
PST.Char(PST#NL)
PST.Str(FPU.F32_To_STR(floatRes, 0))
PST.Char(PST#NL)

QueryReboot

PST.Char(PST#CS)    
PST.Str(STRING("32-bit FLOAT divison"))
PST.Chars(PST#NL, 2)

strPtr := STRING("-1.123456")
floatVal := FPU.STR_To_F32(strPtr)

strPtr2 := STRING("-9.876543")
floatVal2 := FPU.STR_To_F32(strPtr2)

floatRes := FPU.F32_DIV(floatVal, floatVal2)

PST.Str(strPtr)
PST.Char(PST#NL)
PST.Str(STRING("/"))
PST.Char(PST#NL)
PST.Str(strPtr2)
PST.Char(PST#NL)
PST.Str(STRING("="))
PST.Char(PST#NL)
PST.Str(FPU.F32_To_STR(floatRes, 0))
PST.Char(PST#NL)

QueryReboot

PST.Char(PST#CS)
  
PST.Str(STRING("Check some matrix operations with FPU/MA..."))
PST.Chars(PST#NL, 2)
PST.Str(STRING("              1  2  3  ", PST#NL))
PST.Str(STRING("         MA = 4  5  6  ", PST#NL))
PST.Str(STRING("              7  8  8  ", PST#NL))
PST.Char(PST#NL)
 
'Fill up a matrix
'                   ┌       ┐
'                   │ 1 2 3 │
'              MA = │ 4 5 6 │
'                   │ 7 8 8 │
'                   └       ┘
  
'Setup MA then read back it's parameters
FPU.WriteCmd3Bytes(FPU#_SELECTMA, 12, 3, 3)
PST.Str(STRING("Read back parameters of MA..."))
PST.Chars(PST#NL, 2)
PST.Str(STRING("      MA register= "))
PST.Dec(FPU.ReadInterVar(FPU#_MA_REG))
PST.Char(PST#NL)
PST.Str(STRING("       X register= "))
PST.Dec(FPU.ReadInterVar(FPU#_X_REG))
PST.Char(PST#NL)
PST.Str(STRING("          MA rows= "))
PST.Dec(FPU.ReadInterVar(FPU#_MA_ROWS))
PST.Char(PST#NL)
PST.Str(STRING("       MA columns= "))
PST.Dec(FPU.ReadInterVar(FPU#_MA_COLS))
PST.Char(PST#NL)
  
'Allocate MB and MC 3x3 matrices, too
FPU.WriteCmd3Bytes(FPU#_SELECTMB, 24, 3, 3)
FPU.WriteCmd3Bytes(FPU#_SELECTMC, 36, 3, 3)
  
'Fill MA by directly addressing it's cells
FPU.WriteCmdByte(FPU#_SELECTA, 0)    'Reg[A]=Reg[0]!    
FPU.WriteCmdByte(FPU#_FSETI, 1)
FPU.WriteCmd2Bytes(FPU#_SAVEMA, 0, 0) 
FPU.WriteCmdByte(FPU#_FSETI, 2)
FPU.WriteCmd2Bytes(FPU#_SAVEMA, 0, 1)
FPU.WriteCmdByte(FPU#_FSETI, 3)
FPU.WriteCmd2Bytes(FPU#_SAVEMA, 0, 2)
FPU.WriteCmdByte(FPU#_FSETI, 4)
FPU.WriteCmd2Bytes(FPU#_SAVEMA, 1, 0)
FPU.WriteCmdByte(FPU#_FSETI, 5)
FPU.WriteCmd2Bytes(FPU#_SAVEMA, 1, 1)
FPU.WriteCmdByte(FPU#_FSETI, 6)
FPU.WriteCmd2Bytes(FPU#_SAVEMA, 1, 2)
FPU.WriteCmdByte(FPU#_FSETI, 7)
FPU.WriteCmd2Bytes(FPU#_SAVEMA, 2, 0)
FPU.WriteCmdByte(FPU#_FSETI, 8)
FPU.WriteCmd2Bytes(FPU#_SAVEMA, 2, 1)
FPU.WriteCmdByte(FPU#_FSETI, 8)
FPU.WriteCmd2Bytes(FPU#_SAVEMA, 2, 2)

'Copy MA to MB and to MC
FPU.WriteCmdByte(FPU#_MOP, FPU#_MX_COPYAB)
FPU.WriteCmdByte(FPU#_MOP, FPU#_MX_COPYAC)
   
'Now read back MA's elements
PST.Char(PST#NL)
PST.Str(STRING("Read back elements of MA:"))
PST.Chars(PST#NL, 2)
REPEAT r FROM 0 TO 2
  REPEAT c FROM 0 TO 2
    PST.Str(STRING("          MA["))
    PST.Dec(r+1)
    PST.Str(STRING(","))
    PST.Dec(c+1)
    PST.Str(STRING("]= "))
    FPU.WriteCmd2Bytes(FPU#_LOADMA, r, c)
    FPU.WriteCmdByte(FPU#_SELECTA, 0)   
    PST.Str(FPU.ReadRaFloatAsStr(0))
    PST.Char(PST#NL)

QueryReboot

PST.Char(PST#CS)
PST.Str(STRING(16, 1, "Calculate Determinant and Inverse of MA..."))
PST.Char(PST#NL)

' Det(MA) = 3
'
'                    ┌                ┐
'                    │ -8/3   8/3  -1 │
' Inv(MA) = {1/MA} = │ 10/3 -13/3   2 │ 
'                    │   -1    2   -1 │
'                    └                ┘
  
'Calculate determinant of MA
FPU.WriteCmdByte(FPU#_MOP, FPU#_MX_DETERM)
PST.Char(PST#NL)
PST.Str(STRING("          Det(MA)= "))
'Since Reg[A]=Reg[0]
PST.Str(FPU.ReadRaFloatAsStr(0))
PST.Char(PST#NL)
  
'Calculat inverse of MB where MB=original MA
'Inverse will be written to MA
FPU.WriteCmdByte(FPU#_MOP, FPU#_MX_INVERSE)
PST.Char(PST#NL)
PST.Str(STRING("Inverse of (MA):"))
'Now read back elements of MA again.
PST.Chars(PST#NL, 2)
REPEAT r FROM 0 TO 2
  REPEAT c FROM 0 TO 2
    PST.Str(STRING("      {1/MA}["))
    PST.Dec(r+1)
    PST.Str(STRING(","))
    PST.Dec(c+1)
    PST.Str(STRING("]= "))
    FPU.WriteCmd2Bytes(FPU#_LOADMA, r, c) 
    PST.Str(FPU.ReadRaFloatAsStr(0))
    PST.Char(PST#NL) 

QueryReboot

'Now MA contains {1/MA}, MC contains the original MA
'Copy MA to MB
FPU.WriteCmdByte(FPU#_MOP, FPU#_MX_COPYAB)
'Matrix multiply MA= MB*MC i.e. Result = InvMA * MA : should be I matrix
FPU.WriteCmdByte(FPU#_MOP, FPU#_MX_MULTIPLY)
'Now read back elements of MA again
PST.Char(PST#CS)
PST.Str(STRING("Check  MA * {1/MA} matrix product..."))
PST.Chars(PST#NL, 2)
REPEAT r FROM 0 TO 2
  REPEAT c FROM 0 TO 2
    PST.Str(STRING("   MA*{1/MA}["))
    PST.Dec(r+1)
    PST.Str(STRING(","))
    PST.Dec(c+1)
    PST.Str(STRING("]= "))
    FPU.WriteCmd2Bytes(FPU#_LOADMA, r, c) 
    PST.Str(FPU.ReadRaFloatAsStr(0))
    PST.Char(PST#NL)

QueryReboot
  
'Check some 16 points FFT operations
PST.Char(PST#CS)
PST.Str(STRING("16 points, one-shot, in-place  FFT..."))
PST.Char(PST#NL)

'Calculate the frequency domain of a pulse at t=1 (Re[1]=1, Im[1]=0)
PST.Str(STRING(PST#NL,  "Frequency domain of a pulse at t=1"))
PST.Chars(PST#NL, 2)
'ReX(t), ImX(t) data points (16x2=32) can fit in a matrix
'somewhere in the FPU's register memory
FPU.WriteCmd3Bytes(FPU#_SELECTMA, 88, 16, 2) 'For example from Reg[88]
  
'Clear MA, Reg[X] now points to the beginning of MA, so
REPEAT 32
  FPU.WriteCmd(FPU#_CLRX)
'Set ReX[1] = 1 everthing else is zero
FPU.WriteCmdByte(FPU#_SELECTA, 0)    
FPU.WriteCmdByte(FPU#_FSETI, 1)
FPU.WriteCmd2Bytes(FPU#_SAVEMA, 1, 0)
  
'Do one-shot in-place FFT with bit-reverse sort pre-processing
FPU.WriteCmdByte(FPU#_FFT, FPU#_BIT_REVERSE)
  
'Real part of frequency domain (should be cosine shape at f=0)

PST.Str(STRING("Real part (COSINE shape) ..."))
PST.Char(PST#NL)
cntr := 0
REPEAT 16
  FPU.WriteCmd2Bytes(FPU#_LOADMA, cntr++, 0)
  PST.Str(FPU.ReadRaFloatAsStr(0))
  PST.Char(PST#NL)

QueryReboot

PST.Char(PST#CS)

'Imaginary part of frequency domain (should be -sine shape at f=0)
PST.Str(STRING("Frequency domain of a pulse at t=1"))
PST.Chars(PST#NL, 2)
PST.Str(STRING("Imaginary part (-SINE shape) ..."))
PST.Char(PST#NL)
cntr := 0
REPEAT 16
  FPU.WriteCmd2Bytes(FPU#_LOADMA, cntr++, 1)
  PST.Str(FPU.ReadRaFloatAsStr(0))
  PST.Char(PST#NL)

QueryReboot    
'-------------------------------------------------------------------------


PRI QueryReboot | done, r
'-------------------------------------------------------------------------
'------------------------------┌─────────────┐----------------------------
'------------------------------│ QueryReboot │----------------------------
'------------------------------└─────────────┘----------------------------
'-------------------------------------------------------------------------
'     Action: Queries to reboot or to finish
' Parameters: None                                
'     Result: None                
'+Reads/Uses: PST#NL, PST#PX                     (OBJ/CON)
'    +Writes: None                                    
'      Calls: "Parallax Serial Terminal"--------->PST.Str
'                                                 PST.Char 
'                                                 PST.RxFlush
'                                                 PST.CharIn
'------------------------------------------------------------------------
PST.Char(PST#NL)
PST.Str(STRING("[R]eboot or press any other key to continue..."))
PST.Char(PST#NL)
done := FALSE
REPEAT UNTIL done
  PST.RxFlush
  r := PST.CharIn
  IF ((r == "R") OR (r == "r"))
    PST.Char(PST#PX)
    PST.Char(0)
    PST.Char(32)
    PST.Char(PST#NL) 
    PST.Str(STRING("Rebooting..."))
    WAITCNT((CLKFREQ / 10) + CNT) 
    REBOOT
  ELSE
    done := TRUE
'----------------------------End of QueryReboot---------------------------


PRI FloatToString(floatV, format)
'-------------------------------------------------------------------------
'------------------------------┌───────────────┐--------------------------
'------------------------------│ FloatToString │--------------------------
'------------------------------└───────────────┘--------------------------
'-------------------------------------------------------------------------
'     Action: Converts a HUB/floatV into string within FPU then loads it
'             back into HUB
' Parameters: Float value, Format code in FPU convention
'    Results: Pointer to string in HUB
'+Reads/Uses: /FPUMAT:FPU CONs                
'    +Writes: FPU Reg:127
'      Calls: FPU_Matrix_Driver------->FPUMAT.WriteCmdByte
'                                      FPUMAT.WriteCmdLONG
'                                      FPUMAT.ReadRaFloatAsStr
'       Note: Quick solution for debug and test purposes
'-------------------------------------------------------------------------
FPU.WriteCmdByte(FPU#_SELECTA, 127)
FPU.WriteCmdLONG(FPU#_FWRITEA, floatV) 
RESULT := FPU.ReadRaFloatAsStr(format) 
'-------------------------------------------------------------------------


DAT '---------------------------MIT License------------------------------- 


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