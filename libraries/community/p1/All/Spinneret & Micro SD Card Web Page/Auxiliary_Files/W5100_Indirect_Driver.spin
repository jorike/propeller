''**************************************
''
''  WIZnet W5100 Indirect Driver Ver. 00.12
''  Updated: Feb 13, 2011 (Update DAT block too, the one just below this comment section)
''
''  Timothy D. Swieter, P.E.
''  Brilldea - purveyor of prototyping goods
''  www.brilldea.com
''
''  Generously funded by Parallax
''  www.parallax.com
''
''  Copyright (c) 2010 Timothy D. Swieter, P.E.
''  See end of file for terms of use and MIT License
''
''  Original file Brilldea_W5100_Indirect_Driver_Ver006.spin -
''  added to version control repository on January 5, 2011
''
''  This driver now lives on Google Code:  http://code.google.com/p/spinneret-web-server/
''  This means that the community can develop and comment on this project.  It also means that this file
''  may not be the latest file.  You can download the latest file here: http://spinneret-web-server.googlecode.com/svn/trunk/W5100_Indirect_Driver.spin
''
''Description:
''
''      This is an Indirect/parallel Assembly language driver for the W5100.
''      This driver requires /RESET, /WR, /RD, /CS, 8x data and 2x address lines.
''      The SEN singal should be tied low to disable SPI mode.  The /INT signal is
''      not employed in this version of the driver.
''
''      The functions are mostly implemented in ASM for very fast access.  There is high level access
''      to the Indirect/parallel bus, but going through SPIN to do many of the functions adds considerable time.
''
''      One thing to note about this driver is the assumption is makes regarding the pins used for exchanging data
''      with the W5100.  When starting the driver you provide the function with the first data pin - that is Data0.
''      The driver then assumes that all data pins are consecuitive and increasing.  So if you define P0 as Data0, then
''      P2 is Data1....P7 is Data7.
''
''      In the program that calls this driver you will need to set up variables such as the following:
''
''      'Variables to hold the address configuration information as set
''      byte  myMAC[6]          '6 element array contianing MAC or source hardware address ex. "02:00:00:01:23:45"
''      byte  myGateway[4]      '4 element array containing gateway address ex. "192.168.0.1"
''      byte  mySubnet[4]       '4 element array contianing subnet mask ex. "255.255.255.0"
''      byte  myIP[4]           '4 element array containing IP address ex. "192.168.0.13"
''
''reference:
''      W5100_Data Sheet
''
''      2711015Eady.pdf (Circuit Cellar Magazine Article: http://www.circuitcellar.com/archives/viewable/Eady207/2711015Eady.pdf)
''      Hydra EtherX Documentation
''
''      Programming and Customizing the multicore Propeller Microcontroller by various
''      TCP/IP Application Layer Protocols for Embedded Systems by M. Tim Jones
''      Networking and Internetworking with Microcontrollers by Fred Eady
''
''      Initial indirect driver coding done by Patrick von den Driesch (patrick1ab on Parallax's Forum)
''
''Revision Notes:
'' 0.5 ....start of fork from SPI code
'' 0.6 Code enhancements and optimizing
''     Fixed problem in UDP buffer losing data - thanks to Marko!  Problem was in txUDP.
'' 0.6-patch1 Bugfix: Avoid deadlock in txTCP, corrected return value in rxTCP /kuisma
'' 0.7 01/04/2011 Bug fix by jstjohnz.  The packet pointer wasn't being updated properly in the tx.udp method, causing
''     truncated packets when the packet being sent rolled over the end of the buffer.  Search 01-04-2010.
'' 0.8 Merged different patch branches and unified divergent versions. /kuisma
'' 0.9 Removed bug created with the 0.7 update. Add comments to rxTCP and txTCP.  Copied rxTCP, txTCp, rxUDP and txUDP to SPI.
''      This includes comment updates and code fixes in both IND and SPI up to this point.
''     **IMPORTANT NOTE**  Any updates made to the rxTCP, txTCP, rxUDP and txUDP need to be applied to both the SPI and IND driver.
'' 0.10 comment updates at the top of the file to reference Google Code.
'' 0.11 Made the drive singelton by moving VAR variables to a DAT secion, making multiple object multiple cog usage possible.
''      Bugfix: txUDP failed silently if W5100 socket in ARP state. Will now wait for ARP to finnish.
''      txUDP now verifies that the socket is in UDP mode, otherwise returns false.  /kuisma
'' 0.12 Added mutex primitives for multiple access applications. /kuisma
''
''**************************************
CON               'Constants to be located here
'***************************************
  '***************************************
  ' Firmware Version
  '***************************************
  FWmajor       = 0
  FWminor       = 12

DAT
  'TxtFWdate   byte "Feb 13, 2011",0

CON

  '***************************************
  '  System Definitions
  '***************************************

  _OUTPUT       = 1             'Sets pin to output in DIRA register
  _INPUT        = 0             'Sets pin to input in DIRA register
  _HIGH         = 1             'High=ON=1=3.3V DC
  _ON           = 1
  _LOW          = 0             'Low=OFF=0=0V DC
  _OFF          = 0
  _ENABLE       = 1             'Enable (turn on) function/mode
  _DISABLE      = 0             'Disable (turn off) function/mode

  '***************************************
  '  W5100 Common Register Definitions
  '***************************************
  _MR           = $0000         'Mode Register
  _GAR0         = $0001         'Gateway Address Register
  _GAR1         = $0002
  _GAR2         = $0003
  _GAR3         = $0004
  _SUBR0        = $0005         'Subnet Mask Address Register
  _SUBR1        = $0006
  _SUBR2        = $0007
  _SUBR3        = $0008
  _SHAR0        = $0009         'Source Hardware Address Register (MAC)
  _SHAR1        = $000A
  _SHAR2        = $000B
  _SHAR3        = $000C
  _SHAR4        = $000D
  _SHAR5        = $000E
  _SIPR0        = $000F         'Source IP Address Register
  _SIPR1        = $0010
  _SIPR2        = $0011
  _SIPR3        = $0012
  'Reserved space $0013 - $0014
  _IR           = $0015         'Interrupt Register
  _IMR          = $0016         'Interrupt Mask Register
  _RTR0         = $0017         'Retry Time Register
  _RTR1         = $0018
  _RCR          = $0019         'Retry Count Register
  _RMSR         = $001A         'Rx Memory Size Register
  _TMSR         = $001B         'Tx Memory Size Register
  _PATR0        = $001C         'Authentication Type in PPPoE Register
  _PATR1        = $001D
  'Reserved space $001E - $0027
  _PTIMER       = $0028         'PPP LCP Request Timer
  _PMAGIC       = $0029         'PPP LCP Magic Number
  _UIPR0        = $002A         'Unreachable IP Address Register
  _UIPR1        = $002B
  _UIPR2        = $002C
  _UIPR3        = $002D
  _UPORT0       = $002E         'Unreachable Port Register
  _UPORT1       = $002F
  'Reserved space $0030 - $03FF

  '***************************************
  '  W5100 Socket 0 Register Definitions
  '***************************************
  _S0_MR        = $0400         'Socket 0 Mode Register
  _S0_CR        = $0401         'Socket 0 Command Register
  _S0_IR        = $0402         'Socket 0 Interrupt Register
  _S0_SR        = $0403         'Socket 0 Status Register
  _S0_PORT0     = $0404         'Socket 0 Source Port Register
  _S0_PORT1     = $0405
  _S0_DHAR0     = $0406         'Socket 0 Destination Hardware Address Register
  _S0_DHAR1     = $0407
  _S0_DHAR2     = $0408
  _S0_DHAR3     = $0409
  _S0_DHAR4     = $040A
  _S0_DHAR5     = $040B
  _S0_DIPR0     = $040C         'Socket 0 Destination IP Address Register
  _S0_DIPR1     = $040D
  _S0_DIPR2     = $040E
  _S0_DIPR3     = $040F
  _S0_DPORT0    = $0410         'Socket 0 Destination Port Register
  _S0_DPORT1    = $0411
  _S0_MSSR0     = $0412         'Socket 0 Maximum Segment Size Register
  _S0_MSSR1     = $0413
  _S0_PROTO     = $0414         'Socket 0 Protocol in IP Raw Mode Register
  _S0_TOS       = $0415         'Socket 0 IP TOS Register
  _S0_TTL       = $0416         'Socket 0 IP TTL Register
  'Reserved space $0417 - $041F
  _S0_TX_FSRO   = $0420         'Socket 0 TX Free Size Register
  _S0_TX_FSR1   = $0421
  _S0_TX_RD0    = $0422         'Socket 0 TX Read Pointer Register
  _S0_TX_RD1    = $0423
  _S0_TX_WR0    = $0424         'Socket 0 TX Write Pointer Register
  _S0_TX_WR1    = $0425
  _S0_RX_RSR0   = $0426         'Socket 0 RX Received Size Register
  _S0_RX_RSR1   = $0427
  _S0_RX_RD0    = $0428         'Socket 0 RX Read Pointer Register
  _S0_RX_RD1    = $0429
  'Reserved space $042A - $04FF

  '***************************************
  '  W5100 Socket 1 Register Definitions
  '***************************************
  _S1_MR        = $0500         'Socket 1 Mode Register
  _S1_CR        = $0501         'Socket 1 Command Register
  _S1_IR        = $0502         'Socket 1 Interrupt Register
  _S1_SR        = $0503         'Socket 1 Status Register
  _S1_PORT0     = $0504         'Socket 1 Source Port Register
  _S1_PORT1     = $0505
  _S1_DHAR0     = $0506         'Socket 1 Destination Hardware Address Register
  _S1_DHAR1     = $0507
  _S1_DHAR2     = $0508
  _S1_DHAR3     = $0509
  _S1_DHAR4     = $050A
  _S1_DHAR5     = $050B
  _S1_DIPR0     = $050C         'Socket 1 Destination IP Address Register
  _S1_DIPR1     = $050D
  _S1_DIPR2     = $050E
  _S1_DIPR3     = $050F
  _S1_DPORT0    = $0510         'Socket 1 Destination Port Register
  _S1_DPORT1    = $0511
  _S1_MSSR0     = $0512         'Socket 1 Maximum Segment Size Register
  _S1_MSSR1     = $0513
  _S1_PROTO     = $0514         'Socket 1 Protocol in IP Raw Mode Register
  _S1_TOS       = $0515         'Socket 1 IP TOS Register
  _S1_TTL       = $0516         'Socket 1 IP TTL Register
  'Reserved space $0517 - $051F
  _S1_TX_FSRO   = $0520         'Socket 1 TX Free Size Register
  _S1_TX_FSR1   = $0521
  _S1_TX_RD0    = $0522         'Socket 1 TX Read Pointer Register
  _S1_TX_RD1    = $0523
  _S1_TX_WR0    = $0524         'Socket 1 TX Write Pointer Register
  _S1_TX_WR1    = $0525
  _S1_RX_RSR0   = $0526         'Socket 1 RX Received Size Register
  _S1_RX_RSR1   = $0527
  _S1_RX_RD0    = $0528         'Socket 1 RX Read Pointer Register
  _S1_RX_RD1    = $0529
  'Reserved space $052A - $05FF

  '***************************************
  '  W5100 Socket 2 Register Definitions
  '***************************************
  _S2_MR        = $0600         'Socket 2 Mode Register
  _S2_CR        = $0601         'Socket 2 Command Register
  _S2_IR        = $0602         'Socket 2 Interrupt Register
  _S2_SR        = $0603         'Socket 2 Status Register
  _S2_PORT0     = $0604         'Socket 2 Source Port Register
  _S2_PORT1     = $0605
  _S2_DHAR0     = $0606         'Socket 2 Destination Hardware Address Register
  _S2_DHAR1     = $0607
  _S2_DHAR2     = $0608
  _S2_DHAR3     = $0609
  _S2_DHAR4     = $060A
  _S2_DHAR5     = $060B
  _S2_DIPR0     = $060C         'Socket 2 Destination IP Address Register
  _S2_DIPR1     = $060D
  _S2_DIPR2     = $060E
  _S2_DIPR3     = $060F
  _S2_DPORT0    = $0610         'Socket 2 Destination Port Register
  _S2_DPORT1    = $0611
  _S2_MSSR0     = $0612         'Socket 2 Maximum Segment Size Register
  _S2_MSSR1     = $0613
  _S2_PROTO     = $0614         'Socket 2 Protocol in IP Raw Mode Register
  _S2_TOS       = $0615         'Socket 2 IP TOS Register
  _S2_TTL       = $0616         'Socket 2 IP TTL Register
  'Reserved space $0617 - $061F
  _S2_TX_FSRO   = $0620         'Socket 2 TX Free Size Register
  _S2_TX_FSR1   = $0621
  _S2_TX_RD0    = $0622         'Socket 2 TX Read Pointer Register
  _S2_TX_RD1    = $0623
  _S2_TX_WR0    = $0624         'Socket 2 TX Write Pointer Register
  _S2_TX_WR1    = $0625
  _S2_RX_RSR0   = $0626         'Socket 2 RX Received Size Register
  _S2_RX_RSR1   = $0627
  _S2_RX_RD0    = $0628         'Socket 2 RX Read Pointer Register
  _S2_RX_RD1    = $0629
  'Reserved space $062A - $06FF

  '***************************************
  '  W5100 Socket 3 Register Definitions
  '***************************************
  _S3_MR        = $0700         'Socket 3 Mode Register
  _S3_CR        = $0701         'Socket 3 Command Register
  _S3_IR        = $0702         'Socket 3 Interrupt Register
  _S3_SR        = $0703         'Socket 3 Status Register
  _S3_PORT0     = $0704         'Socket 3 Source Port Register
  _S3_PORT1     = $0705
  _S3_DHAR0     = $0706         'Socket 3 Destination Hardware Address Register
  _S3_DHAR1     = $0707
  _S3_DHAR2     = $0708
  _S3_DHAR3     = $0709
  _S3_DHAR4     = $070A
  _S3_DHAR5     = $070B
  _S3_DIPR0     = $070C         'Socket 3 Destination IP Address Register
  _S3_DIPR1     = $070D
  _S3_DIPR2     = $070E
  _S3_DIPR3     = $070F
  _S3_DPORT0    = $0710         'Socket 3 Destination Port Register
  _S3_DPORT1    = $0711
  _S3_MSSR0     = $0712         'Socket 3 Maximum Segment Size Register
  _S3_MSSR1     = $0713
  _S3_PROTO     = $0714         'Socket 3 Protocol in IP Raw Mode Register
  _S3_TOS       = $0715         'Socket 3 IP TOS Register
  _S3_TTL       = $0716         'Socket 3 IP TTL Register
  'Reserved space $0717 - $071F
  _S3_TX_FSRO   = $0720         'Socket 3 TX Free Size Register
  _S3_TX_FSR1   = $0721
  _S3_TX_RD0    = $0722         'Socket 3 TX Read Pointer Register
  _S3_TX_RD1    = $0723
  _S3_TX_WR0    = $0724         'Socket 3 TX Write Pointer Register
  _S3_TX_WR1    = $0725
  _S3_RX_RSR0   = $0726         'Socket 3 RX Received Size Register
  _S3_RX_RSR1   = $0727
  _S3_RX_RD0    = $0728         'Socket 3 RX Read Pointer Register
  _S3_RX_RD1    = $0729
  'Reserved space $072A - $07FF

  '***************************************
  '  W5100 Register Masks & Values Defintions
  '***************************************

  'Used in the mode register (MR)
  _RSTMODE      = %1000_0000    'If 1, internal registers are initialized
  _PBMODE       = %0001_0000    'Ping block mode, 1 is enabled
  _PPPOEMODE    = %0000_1000    'PPPoE mode, 1 is enabled
  _AIMODE       = %0000_0010    'Address auto-increment mode
  _INDMODE      = %0000_0001    'Indirect bus mode

  'Used in the Interrupt Register (IR) & Interrupt Mask Register (IMR)
  _CONFLICTM    = %1000_0000
  _UNREACHM     = %0100_0000
  _PPPoEM       = %0010_0000
  _S3_INTM      = %0000_1000    'Socket 3 interrupt bit mask (1 = interrupt)
  _S2_INTM      = %0000_0100    'Socket 2 interrupt bit mask (1 = interrupt)
  _S1_INTM      = %0000_0010    'Socket 1 interrupt bit mask (1 = interrupt)
  _S0_INTM      = %0000_0001    'Socket 0 interrupt bit mask (1 = interrupt)

  'Used in the RX/TX memory size register(RMSR & TMSR)
  _S3_SM        = %1100_0000    'Socket 3 size mask
  _S2_SM        = %0011_0000    'Socket 2 size mask
  _S1_SM        = %0000_1100    'Socket 1 size mask
  _S0_SM        = %0000_0011    'Socket 0 size mask

  _1KB          = %00           '1KB memory size
  _2KB          = %01           '2KB memory size
  _4KB          = %10           '4KB memory size
  _8KB          = %11           '8KB memory size

  'Used in the socket n mode register (Sn_MR)
  _MULTIM       = %1000_0000    'Enable/disable multicasting in UDP
  _PROTOCOLM    = %0000_1111    'Registers for setting protocol

  _CLOSEDPROTO  = %0000         'Closed
  _TCPPROTO     = %0001         'TCP
  _UDPPROTO     = %0010         'UDP
  _IPRAWPROTO   = %0011         'IPRAW
  _MACRAW       = %0100         'MACRAW (used in socket 0)
  _PPPOEPROTO   = %0101         'PPPoE (used in socket 0)

  'Used in the socket n command register (Sn_CR)
  _OPEN         = $01           'Initialize a socket
  _LISTEN       = $02           'In TCP mode, waits for request from client
  _CONNECT      = $04           'In TCP mode, sends connect request to server
  _DISCON       = $08           'In TCP mode, request to disconnect
  _CLOSE        = $10           'Closes socket
  _SEND         = $20           'Transmits data
  _SEND_MAC     = $21           'In UDP mode, like send, but uses MAC
  _SEND_KEEP    = $22           'In TCP mode, check connection status by sending 1 byte
  _RECV         = $40           'Receiving is processed

  'Used in socket n interrupt register (Sn_IR)
  _SEND_OKM     = %0001_0000    'Set to 1 if send operation is completed
  _TIMEOUTM     = %0000_1000    'Set to 1 if timeout occured during transmission
  _RECVM        = %0000_0100    'Set to 1 if data is received
  _DISCONM      = %0000_0010    'Set to 1 if connection termination is requested
  _CONM         = %0000_0001    'Set to 1 if connection is established

  'Used in socket n status register (Sn_SR)
  _SOCK_CLOSED  = $00
  _SOCK_INIT    = $13
  _SOCK_LISTEN  = $14
  _SOCK_SYNSENT = $15
  _SOCK_SYNRECV = $16
  _SOCK_ESTAB   = $17
  _SOCK_FIN_WAIT= $18
  _SOCK_CLOSING = $1A
  _SOCK_TIME_WAIT=$1B
  _SOCK_LACK_ACK =$1D
  _SOCK_CLOSE_WT= $1C
  _SOCK_UDP     = $22
  _SOCK_IPRAW   = $32
  _SOCK_MACRAW  = $42
  _SOCK_PPPOE   = $5F

  _SOCK_ARP1    = $11
  _SOCK_ARP2    = $21
  _SOCK_ARP3    = $31

  'SPI OP-code when assembly packet to read/write to W5100
  _WRITEOP      = $F0           'Signals a write operation in SPI mode
  _READOP       = $0F           'Signals a read operation in SPI mode

  'RX & TX definitions
  _TX_base      = $4000         'Base address of TX buffer
  _RX_base      = $6000         'Base address of RX buffer

  _TX_mask_1k   = $03FF         'Mask for default 1K buffer for each socket
  _RX_mask_1K   = $03FF         'Mask for default 1K buffer for each socket

  _TX_mask_2k   = $07FF         'Mask for default 2K buffer for each socket
  _RX_mask_2K   = $07FF         'Mask for default 2K buffer for each socket

  _TX_mask_4k   = $0FFF         'Mask for default 4K buffer for each socket
  _RX_mask_4K   = $0FFF         'Mask for default 4K buffer for each socket

  _TX_mask_8k   = $1FFF         'Mask for default 8K buffer for each socket
  _RX_mask_8K   = $1FFF         'Mask for default 8K buffer for each socket

  _UDP_header   = 8             '8 bytes of data in the UDP header from the W5100

  '***************************************
  ' Command Definitions for ASM W5100 Indirect/parallel Routine
  '***************************************

  '_reserved    = 0             'This is the default state - means ASM is waiting for command
  _readIND      = 1 << 16       'High level access to reading from the W5100 via indirect/parallel
  _writeIND     = 2 << 16       'High level access to writing to the W5100 via indirect/parallel
  _SetMAC       = 3 << 16       'Set the MAC ID in the W5100
  _SetGateway   = 4 << 16       'Set the gateway address in the W5100
  _SetSubnet    = 5 << 16       'Set the subnet address in the W5100
  _SetIP        = 6 << 16       'Set the IP address in the W5100
  _ReadMAC      = 7 << 16       'Recall the MAC ID in the W5100
  _ReadGateway  = 8 << 16       'Recall the gateway address in the W5100
  _ReadSubnet   = 9 << 16       'Recall the subnet address in the W5100
  _ReadIP       = 10 << 16      'Recall the IP address in the W5100
  _PingBlock    = 11 << 16      'Enable/disable ping response
  _rstHW        = 12 << 16      'Reset the W5100 IC via hardware
  _rstSW        = 13 << 16      'Reset the W5100 IC via hardware
  _Sopen        = 14 << 16      'Open a socket
  _Sdiscon      = 15 << 16      'Disconnect a socket
  _Sclose       = 16 << 16      'Close a socket

  _lastCmd      = 17 << 16      'Place holder for last command

  '***************************************
  ' Driver Flag Definitions
  '***************************************

  _Flag_ASMstarted = |< 1       'Flag to indicated asm routine is started succesfully

'**************************************
DAT               'Variables to be located here (singelton version)
'***************************************

  'processor overhead
W5100cog        long 0          'Cog ID
W5100flags      long 0          'Flags for status

  'Masks
rx_mask_S       word 0[4]       'Words for holding mask values
tx_mask_S       word 0[4]       'Words for holding mask values

  'Command setup
command         long 0          'stores command and arguments for the ASM driver

lock            byte 255        'Mutex semaphore

  'W5100 Indirect/Parallel pin definitions
        'Pins/masks are actually setup in SPIN by modifying the memory that is copied into the cog.  This saves space.
        'The pins/masks are defined in the dat section.  The definitions include the following pins:

          'Address[0] - output
          'Address[1] - output
          'Chip Select - active low, output
          'Read cmd - active low, output
          'Write cmd - active low, output
          'Reset - active low, output
          'Data[0] to [7] - output/input
          'SPI Enable - output

'***************************************
OBJ               'Object declaration to be located here
'***************************************

  'none

'~~~~~~~~~~~~~~~~~~~~~~~~~~Start/Stop Routines~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'***************************************
PUB StopINDIRECT
'***************************************
'' Stop the W5100 Indirect/parallel Driver cog if one is running.
'' Only a single cog can be running at a time.
'' This routine will free a cog.
''
''  params:  none
''  return:  none

  if W5100cog                                           'Is cog non-zero?
    cogstop(W5100cog~ - 1)                              'Yes, stop the cog and then make value zero

    'Reset any data held by the driver
    W5100flags := 0                                     'Clear all the flags

    ADD0mask   := 0                                     'Clear all masks
    ADD1mask   := 0
    CSmask     := 0
    RDmask     := 0
    WRmask     := 0
    RESETmask  := 0

    BASEpin    := 0
    DATAmask   := 0

    WRCSmask   := 0
    RDCSmask   := 0
    WRRDCSmask := 0

    SENmask    := 0

    'Reset the socket masks
    rx_mask_S[0] := 0
    rx_mask_S[1] := 0
    rx_mask_S[2] := 0
    rx_mask_S[3] := 0

    tx_mask_S[0] := 0
    tx_mask_S[1] := 0
    tx_mask_S[2] := 0
    tx_mask_S[3] := 0

  return 'end of StopINDIRECT

'***************************************
PUB StartINDIRECT(_databit0, _addr0, _addr1, _cs, _rd, _wr, _reset, _sen) : okay
'***************************************
''  Initializes the I/O and registers based on parameters.
''  After initilization another cog is started which is the
''  cog responsible for the Indirect/parallel communication to the W5100.
''
''  The W5100 Indirect/parallel cog will allow only one instance of itself
''  to run and the it consumes only 1 cog.
''
''  params:  the seven pins of required for indirect/parallel
''           _databit0 is the pin for bit0, the other pins are assumed to be sequential following this pin.
''           _sen = the pin of the W5100 SPI_EN.  If not used, set to -1
''  return:  value of cog if started or zero if not started

  'Keeps from two cogs running
  StopINDIRECT

  'Initialize the I/O for writing the mask data to the memory area that will be copied into a COG.
  'This routine assumes Indirect/parallel connection, SPI_EN will be made output low by the ASM cog
  ADD0mask  := |< _addr0
  ADD1mask  := |< _addr1
  CSmask    := |< _cs
  RDmask    := |< _rd
  WRmask    := |< _wr
  RESETmask := |< _reset

  BASEpin   := _databit0                                'The base pin of data byte for shifting operations
  DATAmask  := %1111_1111 << _databit0                  'Special mask setup with eight pins

  WRCSmask  := WRmask | CSmask
  RDCSmask  := RDmask | CSmask
  WRRDCSmask:= WRmask | RDmask | CSmask

  if _sen <> -1
    SENmask := |< _sen
  else
    SENmask := 0

  'Clear the command buffer - be sure no commands were set before initializing
  command := 0

  'Start a cog to execute the ASM routine
  okay := W5100cog := cognew(@Entry, @command) + 1

  'Set a flag if cog started succesfully
  if okay
    W5100flags := _Flag_ASMstarted

    'Initialize the socket masks
    rx_mask_S[0] := _RX_mask_2K
    rx_mask_S[1] := _RX_mask_2K
    rx_mask_S[2] := _RX_mask_2K
    rx_mask_S[3] := _RX_mask_2K

    tx_mask_S[0] := _TX_mask_2K
    tx_mask_S[1] := _TX_mask_2K
    tx_mask_S[2] := _TX_mask_2K
    tx_mask_S[3] := _TX_mask_2K

  return 'end of StartINDIRECT

'~~~~~~~~~~~~~~~~~~~~~~~~~~Command Routines~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'***************************************
PUB InitAddresses( _block, _macPTR, _gatewayPTR, _subnetPTR, _ipPTR)
'***************************************
'' Initialize all four addresses.
''
''  params:  _block if true will wait for ASM routine to send before returning from this function
''           _mac, _gateway, _subnet, _ip are pointers to appropriate size byte arrays
''  return:  none

  'Checks on if the ASM cog is running is done in each of the following routines
  WriteMACaddress(_block, _macPTR)
  WriteGatewayAddress(_block, _gatewayPTR)
  WriteSubnetMask(_block, _subnetPTR)
  WriteIPaddress(_block, _ipPTR)

  return 'end of InitAddresses

'***************************************
PUB WriteMACaddress( _block, _macPTR)
'***************************************
'' Write the specified MAC address to the W5100.
''
''  params:  _block if true will wait for ASM routine to send before continuing
''           The pointer should point to a 6 byte array.
''           byte[0] = highest octet and byte[5] = lowest octet
''           example 02:00:00:01:23:45 where byte[0] = $02 and byte[5] = $45
''
''  return:  none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    'Send the command
    command := _SetMAC + _macPTR

    'wait for the command to complete or just move on
    if _block
      repeat while command

  return 'end of WriteMACaddress

'***************************************
PUB WriteGatewayAddress(_block, _gatewayPTR)
'***************************************
'' Write the specified gateway address to the W5100.
''
''  params:  _block if true will wait for ASM routine to send before continuing
''           The pointer should point to a 4 byte array.
''           byte[0] = highest octet and byte[3] = lowest octet
''           example 192.168.0.1 where byte[0] = 192 and byte[3] = 1
''
''  return:  none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    'Send the command
    command := _SetGateway + _gatewayPTR

    'wait for the command to complete or just move on
    if _block
      repeat while command

  return 'end of WriteGatewayAddress

'***************************************
PUB WriteSubnetMask(_block, _subnetPTR)
'***************************************
'' Write the specified Subnet mask to the W5100.
''
''  params:  _block if true will wait for ASM routine to send before continuing
''           The pointer should point to a 4 byte array.
''           byte[0] = highest octet and byte[3] = lowest octet
''           example 255.255.255.0 where byte[0] = 255 and byte[3] = 0
''
''  return:  none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    'Send the command
    command := _SetSubnet + _subnetPTR

    'wait for the command to complete or just move on
    if _block
      repeat while command

  return 'end of WriteSubnetMask

'***************************************
PUB WriteIPaddress(_block, _ipPTR)
'***************************************
'' Write the specified IP address to the W5100.
''
''  params:  _block if true will wait for ASM routine to send before continuing
''           The pointer should point to a 4 byte array.
''           byte[0] = highest octet and byte[3] = lowest octet
''           example 192.168.0.13 where byte[0] = 192 and byte[3] = 13
''
''  return:  none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    'Send the command
    command := _SetIP + _ipPTR

    'wait for the command to complete or just move on
    if _block
      repeat while command

  return 'end of WriteIPaddress

'***************************************
PUB ReadMACaddress(_macPTR)
'***************************************
'' Read the MAC address from the W5100.
''
''  params:  none
''  return:  The pointer should point to a 6 byte array.
''           byte[0] = highest octet and byte[5] = lowest octet
''           example 02:00:00:01:23:45 where byte[0] = $02 and byte[5] = $45

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    'Send the command
    command := _ReadMAC + _macPTR

    'wait for the command to complete
    repeat while command

  return 'end of ReadMACaddress

'***************************************
PUB ReadGatewayAddress(_gatewayPTR)
'***************************************
'' Read the gateway address from the W5100.
''
''  params:  none
''  return:  The pointer should point to a 4 byte array.
''           byte[0] = highest octet and byte[3] = lowest octet
''           example 192.168.0.1 where byte[0] = 192 and byte[3] = 1

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    'Send the command
    command := _ReadGateway + _gatewayPTR

    'wait for the command to complete
    repeat while command

  return 'end of ReadGatewayAddress

'***************************************
PUB ReadSubnetMask(_subnetPTR)
'***************************************
'' Read the specified Subnet mask from the W5100
''
''  params:  none
''  return:  The pointer should point to a 4 byte array.
''           byte[0] = highest octet and byte[3] = lowest octet
''           example 255.255.255.0 where byte[0] = 255 and byte[3] = 0

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    'Send the command
    command := _ReadSubnet + _subnetPTR

    'wait for the command to complete
    repeat while command

  return 'end of ReadSubnetMask

'***************************************
PUB ReadIPaddress(_ipPTR)
'***************************************
'' Read the specified IP address from the W5100
''
''  params:  none
''  return:  The pointer should point to a 4 byte array.
''           byte[0] = highest octet and byte[3] = lowest octet
''           example 192.168.0.13 where byte[0] = 192 and byte[3] = 13

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    'Send the command
    command := _ReadIP + _ipPTR

    'wait for the command to complete
    repeat while command

  return 'end of ReadIPaddress

'***************************************
PUB PingBlock(_block, _bool)
'***************************************
'' Enable/disable if the W5100 responds to pings.
''
''  params:  _block if true will wait for ASM routine to send before continuing
''           _bool is a bool, true is W5100 will NOT respond, false W5100 will respond
''  return:  none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    'Send the command
    command := _pingBlock + @_bool

    'wait for the command to complete or just move on
    if _block
      repeat while command

  return 'end of PingBlock

'***************************************
PUB ResetHardware(_block)
'***************************************
'' Reset the W5100 via hardware
''
''  params:  _block if true will wait for ASM routine to send before continuing
''  return:  none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    'Send the command
    command := _rstHW

    'wait for the command to complete or just move on
    if _block
      repeat while command

  return 'end of ResetHardware

'***************************************
PUB ResetSoftware(_block)
'***************************************
'' Reset the W5100 via software
''
''  params:  _block if true will wait for ASM routine to send before continuing
''  return:  none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    'Send the command
    command := _rstSW

    'wait for the command to complete or just move on
    if _block
      repeat while command

  return 'end of ResetSoftware

 ''Untested - a work in progress by Timothy D. Swieter
'***************************************
PUB InitSocketMem( _template) | temp0
'***************************************
'' Initialize the socket memory of the W5100.  The W5100 has a total of 8kb for rx memory and 8kb for tx memory.
'' This memory can be assigned in 1kb, 2kb, 4kb and 8kb increments.  Memory assignments starts at socket 0 and work
'' towards socket 3 and if there isn't enough memory left for a socket, the socket doesn't get any and shouldn't
'' be used.
''
'' Users are welcome to add their own templates to fit their design.
''
'' This design assumes that the rx and tx registers are identically sized, but they don't have to be.
''
''  params:  _template
''
''  return:  none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    case _template

    ''1 TEMPLATE
    ''S0 S1 S2 S3
    ''4k 2k 1k 1k
      1     :   rx_mask_S[0] := _RX_mask_4K
                rx_mask_S[1] := _RX_mask_2K
                rx_mask_S[2] := _RX_mask_1K
                rx_mask_S[3] := _RX_mask_1K

                tx_mask_S[0] := _TX_mask_4K
                tx_mask_S[1] := _TX_mask_2K
                tx_mask_S[2] := _TX_mask_1K
                tx_mask_S[3] := _TX_mask_1K

                'Sockets                  S3            S2            S1            S0
                temp0 := constant( (_1KB << 6) | (_1KB << 4) | (_2KB << 2) | (_4KB << 0) )

    ''2 TEMPLATE
    ''S0 S1 S2 S3
    ''4k 4k 0k 0k
      2     :   rx_mask_S[0] := _RX_mask_4K
                rx_mask_S[1] := _RX_mask_4K
                rx_mask_S[2] := 0
                rx_mask_S[3] := 0

                tx_mask_S[0] := _TX_mask_4K
                tx_mask_S[1] := _TX_mask_4K
                tx_mask_S[2] := 0
                tx_mask_S[3] := 0

                'Sockets                  S3            S2            S1            S0
                temp0 := constant( (_1KB << 6) | (_1KB << 4) | (_4KB << 2) | (_4KB << 0) )

    ''3 TEMPLATE
    ''S0 S1 S2 S3
    ''8k 0k 0k 0k
      3     :   rx_mask_S[0] := _RX_mask_8K
                rx_mask_S[1] := 0
                rx_mask_S[2] := 0
                rx_mask_S[3] := 0

                tx_mask_S[0] := _TX_mask_8K
                tx_mask_S[1] := 0
                tx_mask_S[2] := 0
                tx_mask_S[3] := 0

                'Sockets                  S3            S2            S1            S0
                temp0 := constant( (_1KB << 6) | (_1KB << 4) | (_1KB << 2) | (_8KB << 0) )

    ''0 TEMPLATE - default for WIZnet W5100
     'Technically you wouldn't need to execute any code, but the code is included here for completeness
    ''S0 S1 S2 S3
    ''2k 2k 2k 2k
      other :   rx_mask_S[0] := _RX_mask_2K
                rx_mask_S[1] := _RX_mask_2K
                rx_mask_S[2] := _RX_mask_2K
                rx_mask_S[3] := _RX_mask_2K

                tx_mask_S[0] := _TX_mask_2K
                tx_mask_S[1] := _TX_mask_2K
                tx_mask_S[2] := _TX_mask_2K
                tx_mask_S[3] := _TX_mask_2K

                'Sockets                  S3            S2            S1            S0
                temp0 := constant( (_2KB << 6) | (_2KB << 4) | (_2KB << 2) | (_2KB << 0) )

    writeIND(true, _RMSR, @temp0, 1)
    writeIND(false, _TMSR, @temp0, 1)

  return 'end of InitSocketMem

'***************************************
PUB SocketOpen(_socket, _mode, _srcPort, _destPort, _destIP)
'***************************************
'' Open the specified socket in the specified mode on the W5100.
'' The mode can be either TCP or UDP.
''
''  params:  _socket is a value of 0 to 3 - only four sockets on the W5100
''           _mode is one of the constants specifing closed, TCP, UDP, IPRaw etc
''           _srcPort, _destPort are the ports to use in the connection pass by value
''           _destIP is a pointer to the destination IP byte array (use the @on the variable)
''  return:  none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)
    'If the socket has memory allocated, execute the command
    if (rx_mask_S[_socket] <> 0)

      'Send the command
      command := _Sopen + @_socket

      'wait for the command to complete
      repeat while command

  return 'end of SocketOpen

'***************************************
PUB SocketTCPlisten(_socket) | temp0
'***************************************
'' Check if a socket is TCP and open and if so then set the socket to listen on the W5100
''
''  params: _socket is a value of 0 to 3 - only four sockets on the W5100
''  return: none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)
    'If the socket has memory allocated, execute the command
    if (rx_mask_S[_socket] <> 0)

      'Check if the socket is TCP and open by looking at socket status register
      readIND((_S0_SR + (_socket * $0100)), @temp0, 1)

      if temp0.byte[0] <> _SOCK_INIT
        return

      'Tell the W5100 to listen on the particular socket
      temp0 := _LISTEN
      writeIND(true, (_S0_CR + (_socket * $0100)), @temp0, 1)

  return 'end of SocketTCPlisten

'***************************************
PUB SocketTCPconnect(_socket) | temp0
'***************************************
'' Check if a socket is TCP and open and if so then set the socket to connect on the W5100
''
''  params: _socket is a value of 0 to 3 - only four sockets on the W5100
''  return: none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)
    'If the socket has memory allocated, execute the command
    if (rx_mask_S[_socket] <> 0)

      'Check if the socket is TCP and open by looking at socket status register
      readIND((_S0_SR + (_socket * $0100)), @temp0, 1)

      if temp0.byte[0] <> _SOCK_INIT
        return

      'Tell the W5100 to connect to a particular socket
      temp0 := _CONNECT
      writeIND(true, (_S0_CR + (_socket * $0100)), @temp0, 1)

  return 'end of SocketTCPconnect

'***************************************
PUB SocketTCPestablished(_socket) | temp0
'***************************************
'' Check if a socket has established a TCP connection
''
''  params: _socket is a value of 0 to 3 - only four sockets on the W5100
''  return: True if established, false if not

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)
    'If the socket has memory allocated, execute the command
    if (rx_mask_S[_socket] <> 0)

      'Check if the socket is established or not
      readIND((_S0_SR + (_socket * $0100)), @temp0, 1)

      if temp0.byte[0] <> _SOCK_ESTAB
        return false
      else
        return true

  return false 'end of SocketTCPestablished

'***************************************
PUB SocketTCPdisconnect(_socket)
'***************************************
'' Disconnects the specified socket on the W5100.
''
''  params:  _socket is a value of 0 to 3 - only four sockets on the W5100
''  return:  none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)
    'If the socket has memory allocated, execute the command
    if (rx_mask_S[_socket] <> 0)

      'Send the command
      command := _Sdiscon + @_socket

      'wait for the command to complete
      repeat while command

  return 'end of SocketTCPdisconnect

'***************************************
PUB SocketClose(_socket)
'***************************************
'' Closes the specified socket on the W5100.
''
''  params:  _socket is a value of 0 to 3 - only four sockets on the W5100
''  return:  none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)
    'If the socket has memory allocated, execute the command
    if (rx_mask_S[_socket] <> 0)

      'Send the command
      command := _Sclose + @_socket

      'wait for the command to complete
      repeat while command

  return 'end of SocketClose

'***************************************
PUB rxTCP(_socket, _dataPtr) | temp0, RSR, pcktptr, pcktoffset, pcktstart, rolloverpoint
'***************************************
'' Receive TCP data on the specified socket.  Most of the heavy lifting of receiving data is handled by the ASM routine,
'' but for effeciency in coding the SPIN routine walks through the process of receiving data such as verifying and manipulating
'' the various register.  This routine could be completely coded in ASM for faster operation.
''
'' The receive routine streams over the TCP data.  The data streamed over is based on the W5100 receive register size.
''
''  params:  _socket is a value of 0 to 3 - only four sockets on the W5100
''           _dataPtr is a pointer to the byte array to be written to in HUBRAM (use the @ in front of the byte variable)
''  return:  Non-zero value indicating the number of bytes read from W5100 or zero if no data is read
''

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)
    'If the socket has memory allocated, execute the command
    if (rx_mask_S[_socket] <> 0)

      'Check if there is data to receive from the W5100
      readIND((_S0_RX_RSR0 + (_socket * $0100)), @temp0, 2)
      RSR.byte[1] := temp0.byte[0]
      RSR.byte[0] := temp0.byte[1]

      'Bring over the data if there is data
      if RSR.word[0] <> 0

        'Determine the offset and location to read data from in the W5100
        readIND((_S0_RX_RD0 + (_socket * $0100)), @temp0, 2)
        pcktptr.byte[1] := temp0.byte[0]
        pcktptr.byte[0] := temp0.byte[1]
        pcktoffset := pcktptr & rx_mask_S[_socket]
        pcktstart := (_RX_base + (_socket * $0800)) + pcktoffset

        'Read the data of the packet
        if (pcktoffset + RSR.word[0]) > (rx_mask_S[_socket] + 1)
          'process the data in two parts because the buffers rolls over
          rolloverpoint := (rx_mask_S[_socket] + 1) - pcktoffset
          readIND(pcktstart, _dataPtr, rolloverpoint)
          pcktstart := (_RX_base + (_socket * $0800))
          readIND(pcktstart, (_dataPtr + rolloverpoint), (RSR.word[0] - rolloverpoint))

        else
          'process the data in one part
          readIND(pcktstart, _dataPtr, RSR.word[0])

        'Update the W5100 registers, the packet pointer
        temp0 := (pcktptr + RSR.word[0])
        pcktptr.byte[1] := temp0.byte[0]
        pcktptr.byte[0] := temp0.byte[1]
        writeIND(true, (_S0_RX_RD0 + (_socket * $0100)), @pcktptr, 2)

        'Tell the W5100 we received a packet
        temp0 := _RECV
        writeIND(true, (_S0_CR + (_socket * $0100)), @temp0, 1)

        return RSR.word[0]        'bugfix /Q

  return 0 'end of rxTCP

'***************************************
PUB txTCP(_socket, _dataPtr, _size) | temp0, freespace, pcktptr, pcktoffset, pcktstart, rolloverpoint, chunksize
'***************************************
'' Transmit TCP data on the specified socket and port.  Most of the heavy lifting of transmitting data is handled by the ASM routine,
'' but for effeciency in coding the SPIN routine walks through the process of transmitting data such as verifying and manipulating
'' the various register.  This routine could be completely coded in ASM for faster operation.
''
'' The transmit routine sends only the amounve of data specified by _size.  This routine waits for room in the W5100 to send the packet.
''
''  params:  _socket is a value of 0 to 3 - only four sockets on the W5100
''           _dataPtr is a pointer to the byte(s) of data to read from HUBRAM and sent (use the @ in front of the byte variable)
''           _size it the length in bytes of the data to be sent from HUBRAM
''  return:  True if data was put in W5100 and told to be sent, otherwise false
''

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)
    'If the socket has memory allocated, execute the command
    if (rx_mask_S[_socket] <> 0)

      'Initialize
      freespace := 0
      pcktptr:= 0

      repeat while _size > 0
        'wait for room in the W5100 to send some of the data
        repeat until (freespace.word[0] > 0)
          readIND((_S0_TX_FSRO + (_socket * $0100)), @temp0, 2)
          freespace.byte[1] := temp0.byte[0]
          freespace.byte[0] := temp0.byte[1]
        chunksize := _size <# freespace.word[0]

        'Get the place where to start writing the packet in the W5100
        readIND((_S0_TX_WR0 + (_socket * $0100)), @temp0, 2)
        pcktptr.byte[1] := temp0.byte[0]
        pcktptr.byte[0] := temp0.byte[1]
        pcktoffset := pcktptr & tx_mask_S[_socket]
        pcktstart := (_TX_base + (_socket * $0800)) + pcktoffset

        'Write the data based on rolling over in the buffer or not
        if (pcktoffset + chunksize) > (tx_mask_S[_socket] + 1)
          'process the data in two parts because the buffers rolls over
          rolloverpoint := (tx_mask_S[_socket] + 1) - pcktoffset
          writeIND(true, pcktstart, _dataPtr, rolloverpoint)
          pcktstart := (_TX_base + (_socket * $0800))
          writeIND(true, pcktstart, (_dataPtr + rolloverpoint), (chunksize - rolloverpoint))

        else
          'process the data in one part
          writeIND(true, pcktstart, _dataPtr, chunksize)

        'Calculate the packet pointer for the next go around and save it
        temp0 := pcktptr + chunksize
        pcktptr.byte[1] := temp0.byte[0]
        pcktptr.byte[0] := temp0.byte[1]
        writeIND(true, (_S0_TX_WR0 + (_socket * $0100)), @pcktptr, 2)

        'Tell the W5100 to send the packet
        temp0 := _SEND
        writeIND(true, (_S0_CR + (_socket * $0100)), @temp0, 1)

        _size    -= chunksize
        _dataPtr += chunksize

      return true

  return false 'end of txTCP

'***************************************
PUB rxUDP(_socket, _dataPtr) | temp0, RSR, pcktsize, pcktptr, pcktoffset, pcktstart, rolloverpoint
'***************************************
'' Receive UDP data on the specified socket.  Most of the heavy lifting of receiving data is handled by the ASM routine,
'' but for effeciency in coding the SPIN routine walks through the process of receiving data such as verifying and manipulating
'' the various register.  This routine could be completely coded in ASM for faster operation.
''
'' The receive routine brings over only 1 packet of UDP data at a time.  The packet is based on the size of data read in the packet
'' header and not the receive register size.
''
''  params:  _socket is a value of 0 to 3 - only four sockets on the W5100
''           _dataPtr is a pointer to the byte array to be written to in HUBRAM (use the @ in front of the byte variable)
''  return:  Non-zero value indicating bytes read from W5100 or zero if no data is read
''
''  The data returned is the complete packet as provided by the W5100.  This means the following:
''  data[0]..[3] is the source IP address, data[4],[5] is the source port, data[6],[7] is the payload size and data[8] starts the payload

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)
    'If the socket has memory allocated, execute the command
    if (rx_mask_S[_socket] <> 0)

      'Check if there is data to receive from the W5100
      readIND((_S0_RX_RSR0 + (_socket * $0100)), @temp0, 2)
      RSR.byte[1] := temp0.byte[0]
      RSR.byte[0] := temp0.byte[1]

      'Bring over the data if there is data
      if RSR.word[0] <> 0

        'Determine the offset and location to read data from in the W5100
        readIND((_S0_RX_RD0 + (_socket * $0100)), @temp0, 2)
        pcktptr.byte[1] := temp0.byte[0]
        pcktptr.byte[0] := temp0.byte[1]
        pcktoffset := pcktptr & rx_mask_S[_socket]
        pcktstart := (_RX_base + (_socket * $0800)) + pcktoffset

        'Read the header of the packet - the first 8 bytes
        if (pcktoffset + _UDP_header) > (rx_mask_S[_socket] + 1)
          'process the header in two parts because the buffers rolls over
          rolloverpoint := (rx_mask_S[_socket] + 1) - pcktoffset
          readIND(pcktstart, _dataPtr, rolloverpoint)
          pcktstart := (_RX_base + (_socket * $0800))
          readIND(pcktstart, (_dataPtr + rolloverpoint), (_UDP_header - rolloverpoint))

        else
          'process the header in one part
          readIND(pcktstart, _dataPtr, _UDP_header)

        'Get the size of the payload portion
        pcktsize := 0                                     'Must be initialized as ASM routine isn't masking the value so a greater than $FF could cause problems
        pcktsize.byte[1] := byte[_dataPtr][6]
        pcktsize.byte[0] := byte[_dataPtr][7]

        pcktoffset := (pcktptr + _UDP_header) & rx_mask_S[_socket]
        pcktstart := (_RX_base + (_socket * $0800)) + pcktoffset
        _dataPtr += _UDP_header

        'Read the data of the packet
        if (pcktoffset + pcktsize.word[0]) > (rx_mask_S[_socket] + 1)
          'process the data in two parts because the buffers rolls over
          rolloverpoint := (rx_mask_S[_socket] + 1) - pcktoffset
          readIND(pcktstart, _dataPtr, rolloverpoint)
          pcktstart := (_RX_base + (_socket * $0800))
          readIND(pcktstart, (_dataPtr + rolloverpoint), (pcktsize.word[0] - rolloverpoint))

        else
          'process the data in one part
          readIND(pcktstart, _dataPtr, pcktsize.word[0])

        'Update the W5100 registers, the packet pointer
        temp0 := (pcktptr + _UDP_header + pcktsize.word[0])
        pcktptr.byte[1] := temp0.byte[0]
        pcktptr.byte[0] := temp0.byte[1]
        writeIND(true, (_S0_RX_RD0 + (_socket * $0100)), @pcktptr, 2)

        'Tell the W5100 we received a packet
        temp0 := _RECV
        writeIND(true, (_S0_CR + (_socket * $0100)), @temp0, 1)

        return (pcktsize.word[0] + _UDP_header)

  return 0 'end of rxUDP

'***************************************
PUB txUDP(_socket, _dataPtr) | temp0, payloadsize, freespace, pcktptr, pcktoffset, pcktstart, rolloverpoint
'***************************************
'' Transmit UDP data on the specified socket and port.  Most of the heavy lifting of transmitting data is handled by the ASM routine,
'' but for effeciency in coding the SPIN routine walks through the process of transmitting data such as verifying and manipulating
'' the various register.  This routine could be completely coded in ASM for faster operation.
''
'' The transmit routine sends only 1 packet of UDP data at a time.  The packet is based on the size of data read in the packet
'' header.  This routine waits for room in the W5100 to send the packet.
''
''  params:  _socket is a value of 0 to 3 - only four sockets on the W5100
''           _dataPtr is a pointer to the byte(s) of data to read from HUBRAM and sent (use the @ in front of the byte variable)
''  return:  True if data was put in W5100 and told to be sent, otherwise false
''
''  The data packet passed to this routine should be of the form of the following:
''  data[0]..[3] is the destination IP address, data[4],[5] is the destination port, data[6],[7] is the payload size and data[8] starts the payload

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)
    'Give the W5100 time to handle arp
    repeat
      readIND((_S0_SR + (_socket * $0100)), @temp0, 1)
    until temp0.byte[0] & $CF <> $01                            '$11, $21, $31 documented ARP states, $01 undocumented
    'Make sure the socket is open for UDP business
    if temp0.byte[0] <> _SOCK_UDP
      return false

    'If the socket has memory allocated, execute the command
    if (rx_mask_S[_socket] <> 0)

      'Get the size of the packet to send, this doesn't include the header info
      payloadsize := 0
      freespace := 0
      payloadsize.byte[1] := byte[_dataPtr][6]                  'hi-byte
      payloadsize.byte[0] := byte[_dataPtr][7]                  'lo-byte

      'wait for room in the W5100 to send data
      repeat until (freespace.word[0] > payloadsize.word[0])
        readIND((_S0_TX_FSRO + (_socket * $0100)), @temp0, 2)
        freespace.byte[1] := temp0.byte[0]
        freespace.byte[0] := temp0.byte[1]

      'Tell the W5100 the destination address and destination socket
      writeIND(true, (_S0_DIPR0 + (_socket * $0100)), _dataPtr, 6)
      _dataPtr += _UDP_header

      'Get the place where to start writing the packet in the W5100
      readIND((_S0_TX_WR0 + (_socket * $0100)), @temp0, 2)
      pcktptr.byte[1] := temp0.byte[0]
      pcktptr.byte[0] := temp0.byte[1]
      pcktoffset := pcktptr & tx_mask_S[_socket]
      pcktstart := (_TX_base + (_socket * $0800)) + pcktoffset

      'Write the data based on rolling over in the buffer or not
      if (pcktoffset + payloadsize.word[0]) > (tx_mask_S[_socket] + 1)
        'process the data in two parts because the buffers rolls over
        rolloverpoint := (tx_mask_S[_socket] + 1) - pcktoffset
        writeIND(true, pcktstart, _dataPtr, rolloverpoint)
        pcktstart := (_TX_base + (_socket * $0800))
        writeIND(true, pcktstart, (_dataPtr + rolloverpoint), payloadsize.word[0] - rolloverpoint)

      else
        'process the data in one part
        writeIND(true, pcktstart, _dataPtr, payloadsize.word[0])

      'Calculate the packet pointer for the next go around and save it
      'Update the W5100 registers, the packet pointer
      temp0 := (pcktptr + payloadsize.word[0])
      pcktptr.byte[1] := temp0.byte[0]
      pcktptr.byte[0] := temp0.byte[1]
      writeIND(true, (_S0_TX_WR0 + (_socket * $0100)), @pcktptr, 2)

      'Tell the W5100 to send the packet
      temp0 := _SEND
      writeIND(true, (_S0_CR + (_socket * $0100)), @temp0, 1)

      return true

  return false 'end of txUDP

'***************************************
PUB mutexInit
'***************************************
'' Initialize mutex lock semaphore. Called once at driver initialization if application level locking is needed.
''
'' Returns -1 if no more locks available.

  lock := locknew
  return lock

'***************************************
PUB mutexLock
'***************************************
'' Waits until exclusive access to driver guaranteed.
  repeat until not lockset(lock)

'***************************************
PUB mutexRelease
'***************************************
'' Release mutex lock.
  lockclr(lock)

'***************************************
PUB mutexReturn
'***************************************
'' Returns mutex lock to semaphore pool.
  lockret(lock)

'***************************************
PUB readIND(_register, _dataPtr, _Numbytes)
'***************************************
'' High level access to Indirect/parallel routine for reading from the W5100.
'' Note for faster execution of functions code them in assembly routine like the examples of setting the MAC/IP addresses.
''
''  params:  _register is the 2 byte register address.  See the constant block with register definitions
''           _dataPtr is the place to return the byte(s) of data read from the W5100 (use the @ in front of the byte variable)
''           _Numbytes is the number of bytes to read
''  return:  none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    'Send the command
    command := _readIND + @_register

    'wait for the command to complete
    repeat while command

  return 'end of readIND

'***************************************
PUB writeIND(_block, _register, _dataPtr, _Numbytes)
'***************************************
'' High level access to Indirect/parallel routine for writing to the W5100.
'' Note for faster execution of functions code them in assembly routine like the examples of setting the MAC/IP addresses.
''
''  params:  _block if true will wait for ASM routine to send before continuing
''           _register is the 2 byte register address. See the constant block with register definitions
''           _dataPtr is a pointer to the byte(s) of data to be written (use the @ in front of the byte variable)
''           _Numbytes is the number of bytes to write
''  return:  none

  'If the ASM cog is running, execute the command
  if (W5100flags & _Flag_ASMstarted)

    'Send the command
    command := _writeIND + @_register

    'wait for the command to complete or just move on
    if _block
      repeat while command

  return 'end of writeIND

'~~~~~~~~~~~~~~~~~~~~~~~~~~Utility Routines~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
' none

'~~~~~~~~~~~~~~~~~~~~~~~~~~DAT~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~
'***************************************
DAT
'***************************************
''  Assembly language driver for W5100 Indirect/parallel

        org  0
'-----------------------------------------------------------------------------------------------------
'Start of assembly routine
'-----------------------------------------------------------------------------------------------------
Entry
              'Upon starting the ASM cog the first thing to do is set the I/O states and directions.  SPIN already
              'setup the masks for each pin in the defined data section of the routine before starting the COG.

              'The following ASM routine makes some assumptions about I/O states.  CS, RD and WR pins are always
              'assumed to be high.  If code asserts them low, then a code routine must return them high before
              'exiting.

              'Set the initial state of the I/O, unless listed here, the output is initialized as off/low
              mov       outa,   CSmask          'W5100 Chip Select is initialized as high
              or        outa,   RDmask          'W5100 Read cmd is initialized as high
              or        outa,   WRmask          'W5100 Write cmd is initialized as high

                                                'Remaining outputs initialized as low including reset
                                                'NOTE: the W5100 is held in reset because the pin is low

              'Next set up the I/O with the masks in the direction register
              'all outputs pins are set up here because input is the default state
              mov       dira,   ADD0mask        'Set to an output and clears cog dira register
              or        dira,   ADD1mask        'Set to an output
              or        dira,   CSmask          'Set to an output
              or        dira,   RDmask          'Set to an output
              or        dira,   WRmask          'Set to an output
              or        dira,   RESETmask       'Set to an output
              or        dira,   DATAmask        'Set to an output
              or        dira,   SENmask         'Set to an output

              or        outa,   RESETmask       'Finally - make the reset line high for the W5100 to come out of reset

              mov       t0,     _UnrstTime      'Time to wait coming out of reset before proceeding
              add       t0,     cnt             'Add in the current system counter
              waitcnt   t0,     #0              'Wait

              mov       data,   #%0000_0011     'For setting up MR with Indirect mode and autoincrement address function
              call      #wIndirectMR            'Write the values to the register

'-----------------------------------------------------------------------------------------------------
'Main loop
'wait for a command to come in and then process it.
'-----------------------------------------------------------------------------------------------------
CmdWait
              rdlong    cmdAdd, par        wz   'Check for a command being present
        if_z  jmp       #CmdWait                'If there is no command, jump to check again

              mov       t1,     cmdAdd          'Take a copy of the command/address combo to work on
              rdlong    paramA, t1              'Get parameter A value
              add       t1,     #4              'Increment the address pointer by four bytes
              rdlong    paramB, t1              'Get parameter B value
              add       t1,     #4              'Increment the address pointer by four bytes
              rdlong    paramC, t1              'Get parameter C value
              add       t1,     #4              'Increment the address pointer by four bytes
              rdlong    paramD, t1              'Get parameter D value
              add       t1,     #4              'Increment the address pointer by four bytes
              rdlong    paramE, t1              'Get parameter E value

              mov       t0,     cmdAdd          'Take a copy of the command/address combo to work on
              shr       t0,     #16        wz   'Get the command
              cmp       t0,     #(_lastCmd>>16)+1 wc 'Check for valid command
  if_z_or_nc  jmp       #:CmdExit               'Command is invalid so exit loop
              shl       t0,     #1              'Shift left, multiply by two
              add       t0,     #:CmdTable-2    'add in the "call" address"
              jmp       t0                      'Jump to the command

              'The table of commands that can be called
:CmdTable     call      #rINDcmd                'Read a byte from the W5100 - high level call
              jmp       #:CmdExit
              call      #wINDcmd                'Write a byte to the W5100 - high level call
              jmp       #:CmdExit
              call      #wMAC                   'Write the MAC ID
              jmp       #:CmdExit
              call      #wGateway               'Write the Gateway address
              jmp       #:CmdExit
              call      #wSubnet                'Write the Subnet address
              jmp       #:CmdExit
              call      #wIP                    'Write the IP address
              jmp       #:CmdExit
              call      #rMAC                   'Read the MAC ID
              jmp       #:CmdExit
              call      #rGateway               'Read the Gateway address
              jmp       #:CmdExit
              call      #rSubnet                'Read the Subnet address
              jmp       #:CmdExit
              call      #rIP                    'Read the IP Address
              jmp       #:CmdExit
              call      #pingBlk                'Enable/disable a ping response
              jmp       #:CmdExit
              call      #rstHW                  'Hardware reset of W5100
              jmp       #:CmdExit
              call      #rstSW                  'Software reset of W5100
              jmp       #:CmdExit
              call      #sOPEN                  'Open a socket
              jmp       #:CmdExit
              call      #sDISCON                'Disconnect a socket
              jmp       #:CmdExit
              call      #sCLOSE                 'Close a socket
              jmp       #:CmdExit
              call      #LastCMD                'PlaceHolder for last command
              jmp       #:CmdExit
:CmdTableEnd

              'End of processing a command
:CmdExit      wrlong    _zero,  par             'Clear the command status
              jmp       #CmdWait                'Go back to waiting for a new command

'-----------------------------------------------------------------------------------------------------
'Command sub-routine to read a register from the W5100 - a high level call
'-----------------------------------------------------------------------------------------------------
rINDcmd
              mov       reg,    paramA          'Move the register address into a variable for processing
              mov       ram,    ParamB          'Move the address of the returned byte into a variable for processing
              mov       ctr,    ParamC          'Set up a counter for number of bytes to process

              call      #ReadMulti              'Read the byte from the W5100

rINDcmd_ret ret                                 'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine to write a register in the W5100 - a high level call
'-----------------------------------------------------------------------------------------------------
wINDcmd
              mov       reg,    paramA          'Move the register address into a variable for processing
              mov       ram,    paramB          'Move the data byte into a variable for processing
              mov       ctr,    ParamC          'Set up a counter for number of bytes to process

              call      #writeMulti             'Write the byte to the W5100

wINDcmd_ret ret                                 'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine to write the MAC ID in the W5100
'-----------------------------------------------------------------------------------------------------
wMAC
              mov       reg,    #_SHAR0         'Move the MAC ID register address into a variable for processing
              mov       ram,    cmdAdd          'Move the address of the MAC ID array into a variable for processing
              mov       ctr,    #6              'Set up a counter of 6 bytes

              call      #WriteMulti             'Write the bytes out to the W5100

wMAC_ret ret                                    'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine to write the Gateway address in the W5100
'-----------------------------------------------------------------------------------------------------
wGateway
              mov       reg,    #_GAR0          'Move the gateway register address into a variable for processing
              mov       ram,    cmdAdd          'Move the address of the gateway address array into a variable for processing
              mov       ctr,    #4              'Set up a counter of 4 bytes

              call      #WriteMulti             'Write the bytes out to the W5100

wGateway_ret ret                                'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine to write the Subnet address in the W5100
'-----------------------------------------------------------------------------------------------------
wSubnet
              mov       reg,    #_SUBR0         'Move the subnet register address into a variable for processing
              mov       ram,    cmdAdd          'Move the address of the subnet address array into a variable for processing
              mov       ctr,    #4              'Set up a counter of 4 bytes

              call      #WriteMulti             'Write the bytes out to the W5100

wSubnet_ret ret                                 'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine to write the IP address in the W5100
'-----------------------------------------------------------------------------------------------------
wIP
              mov       reg,    #_SIPR0         'Move the IP register address into a variable for processing
              mov       ram,    cmdAdd          'Move the address of the IP address array into a variable for processing
              mov       ctr,    #4              'Set up a counter of 4 bytes

              call      #WriteMulti             'Write the bytes out to the W5100

wIP_ret ret                                     'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine to Read the MAC ID in the W5100
'-----------------------------------------------------------------------------------------------------
rMAC
              mov       reg,    #_SHAR0         'Move the MAC ID register address into a variable for processing
              mov       ram,    cmdAdd          'Move the address of the MAC ID array into a variable for processing
              mov       ctr,    #6              'Set up a counter of 6 bytes

              call      #ReadMulti              'Read the bytes from the W5100

rMAC_ret ret                                    'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine to Read the Gateway address in the W5100
'-----------------------------------------------------------------------------------------------------
rGateway
              mov       reg,    #_GAR0          'Move the gateway register address into a variable for processing
              mov       ram,    cmdAdd          'Move the address of the gateway address array into a variable for processing
              mov       ctr,    #4              'Set up a counter of 4 bytes

              call      #ReadMulti              'Read the bytes from the W5100

rGateway_ret ret                                'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine to Read the Subnet address in the W5100
'-----------------------------------------------------------------------------------------------------
rSubnet
              mov       reg,    #_SUBR0         'Move the subnet register address into a variable for processing
              mov       ram,    cmdAdd          'Move the address of the subnet address array into a variable for processing
              mov       ctr,    #4              'Set up a counter of 4 bytes

              call      #ReadMulti              'Read the bytes from the W5100

rSubnet_ret ret                                 'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine to Read the IP address in the W5100
'-----------------------------------------------------------------------------------------------------
rIP
              mov       reg,    #_SIPR0         'Move the IP register address into a variable for processing
              mov       ram,    cmdAdd          'Move the address of the IP address array into a variable for processing
              mov       ctr,    #4              'Set up a counter of 4 bytes

              call      #ReadMulti              'Read the bytes from the W5100

rIP_ret ret                                     'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine for enabling/disabling a ping response by the W5100, true = blocked, false = not blocked
'-----------------------------------------------------------------------------------------------------
pingBlk
              call      #rIndirectMR            'Read the byte out of the mode register - so we don't overwrite current settings

              rdlong    t0,     cmdAdd          'Read the bool from SPIN command and place in a variable for testing
              cmp       t0,     #0         wz   'Is the value zero or non-zero?
        if_z  andn      data,   #_PBMode        'Disable ping blocking - W5100 will respond to a ping
        if_nz or        data,   #_PBMode        'Enable ping blocking - W5100 will not respond to a ping

              call      #wIndirectMR            'Write the modified byte out to the mode register

pingBlk_ret ret                                 'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine for resetting the W5100 via hardware
'-----------------------------------------------------------------------------------------------------
rstHW
              andn      outa,   RESETmask       'Toggle the reset line low - resets the W5100

              mov       t0,     _rstTime        'Time to hold IC in reset
              add       t0,     cnt             'Add in the current system counter
              waitcnt   t0,     _UnrstTime      'Wait

              or        outa,   RESETmask       'Finally - make the reset line high for the W5100 to come out of reset
              waitcnt   t0,     _UnrstTime      'Time to wait to come out of reset

rstHW_ret ret                                   'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine for resetting the W5100 via software
'-----------------------------------------------------------------------------------------------------
rstSW
              mov       reg,    #_MR            'Move the mode register address into a variable for processing
              call      #ReadSingle             'Read the byte from the W5100
              or        data,   #_RSTMODE       'Software reset
              call      #writeSingle            'Write the byte to the W5100

              mov       t0,     _UnrstTime      'Time to wait to come out of reset
              add       t0,     cnt             'Add in the current system counter
              waitcnt   t0,     #0              'Wait

rstSW_ret ret                                   'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine for opening a socket
'this routine relies upond t0 being persistant across calls to writing routines
'-----------------------------------------------------------------------------------------------------
sOPEN
              mov       t0,     paramA          'Move the socket number into t0 ($000s)
              shl       t0,     #8              'Move the socket number to the third digit ($0s00).  This is the offset to use for below ops.

              'set the mode
              mov       reg,    _S0_MR_d        'Move the register address into a variable for processing
              add       reg,    t0              'Add in the offset for the particular socket to be worked on
              mov       data,   paramB          'Move over the socket type
              call      #WriteSingle            'Write the byte to the W5100

              'set the source port
              mov       reg,    _S0_PORT1_d     'Move the register address into a variable for processing
              add       reg,    t0              'Add in the offset for the particular socket to be worked on
              mov       data,   paramC          'Move over the source socket value
              call      #WriteSingle            'Write the byte to the W5100
              sub       reg,    #1              'Increment the register address
              mov       data,   paramC          'Move over the source socket value
              shr       data,   #8              'shift the data over one byte
              call      #WriteSingle            'Write the byte to the W5100

              'set the destination port
              mov       reg,    _S0_DPORT1_d    'Move the register address into a variable for processing
              add       reg,    t0              'Add in the offset for the particular socket to be worked on
              mov       data,   paramD          'Move over the destination socket value
              call      #WriteSingle            'Write the byte to the W5100
              sub       reg,    #1              'Increment the register address
              mov       data,   paramD          'Move over the destination socket value
              shr       data,   #8              'shift the data over one byte
              call      #WriteSingle            'Write the byte to the W5100

              'set the destination IP
              mov       reg,    _S0_DIPR0_d     'Move the register address into a variable for processing
              add       reg,    t0              'Add in the offset for the particular socket to be worked on
              mov       ram,    paramE          'Move the address of the IP address array into a variable for processing
              mov       ctr,    #4              'Set up a counter of 4 bytes
              call      #WriteMulti             'Write the bytes out to the W5100

              'set the port open
              mov       reg,    _S0_CR_d        'Move the register address into a variable for processing
              add       reg,    t0              'Add in the offset for the particular socket to be worked on
              mov       data,   #_OPEN          'Move over the command
              call      #WriteSingle            'Write the byte to the W5100

sOPEN_ret ret                                   'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine for disconnecting a socket
'-----------------------------------------------------------------------------------------------------
sDISCON
              mov       t0,     paramA          'Move the socket number into t0 ($000s)
              shl       t0,     #8              'Move the socket number to the third digit ($0s00).  This is the offset to use for below ops.

              'set the port to disconnect
              mov       reg,    _S0_CR_d        'Move the register address into a variable for processing
              add       reg,    t0              'Add in the offset for the particular socket to be worked on
              mov       data,   #_DISCON        'Move over the command
              call      #WriteSingle            'Write the byte to the W5100

sDISCON_ret ret                                 'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine for closing a socket
'-----------------------------------------------------------------------------------------------------
sCLOSE
              mov       t0,     paramA          'Move the socket number into t0 ($000s)
              shl       t0,     #8              'Move the socket number to the third digit ($0s00).  This is the offset to use for below ops.

              'set the port close
              mov       reg,    _S0_CR_d        'Move the register address into a variable for processing
              add       reg,    t0              'Add in the offset for the particular socket to be worked on
              mov       data,   #_CLOSE         'Move over the command
              call      #WriteSingle            'Write the byte to the W5100

sCLOSE_ret ret                                  'Command execution complete

'-----------------------------------------------------------------------------------------------------
'Command sub-routine holding place
'-----------------------------------------------------------------------------------------------------
LastCMD

LastCMD_ret ret                                 'Command execution complete

'-----------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------
'Sub-routine to map write to SPI or Indirect/parallel
' data and reg setup before calling this routine
'-----------------------------------------------------------------------------------------------------
WriteSingle
              call      #wIndirectAR            'Set up the address register
              call      #wIndirectDRsetup       'Set up the data register for writing
              call      #wIndirectDRbyte        'Write the data
WriteSingle_ret ret                             'Return to the calling code

'-----------------------------------------------------------------------------------------------------
'Sub-routine to map read to SPI or Indirect/parallel
' reg setup before calling this routine
'-----------------------------------------------------------------------------------------------------
ReadSingle
              call      #wIndirectAR            'Set up the address register
              call      #rIndirectDRsetup       'Set up the data registers for reading
              call      #rIndirectDRbyte        'Read the data
ReadSingle_ret ret                              'Return to the calling code
'-----------------------------------------------------------------------------------------------------
'Sub-routine to map write to SPI or Indirect/parallel and to loop through bytes
' ram and reg and ctr setup before calling this routine
'-----------------------------------------------------------------------------------------------------
WriteMulti
              call      #wIndirectAR            'Set up the address register
              call      #wIndirectDRsetup       'Set up the data register for writing
:bytes        rdbyte    data,   ram             'Read the byte/octet from hubram - this should also clear the DATA value, byte is zero extended
              call      #wIndirectDRbyte        'Write the data
              add       ram,    #1              'Increment the hubram address by one byte
              djnz      ctr,    #:bytes         'Check if there is another byte, if so, process it

WriteMulti_ret ret                              'Return to the calling code

'-----------------------------------------------------------------------------------------------------
'Sub-routine to map read to SPI or Indirect/parallel and to loop through bytes
' reg and ctr setup before calling this routine
'-----------------------------------------------------------------------------------------------------
ReadMulti
              call      #wIndirectAR            'Set up the address register
              call      #rIndirectDRsetup       'Set up the data registers for reading
:bytes        call      #rIndirectDRbyte        'Read the data
              wrbyte    data,   ram             'Write the byte to hubram
              add       ram,    #1              'Increment the hubram address by one byte
              djnz      ctr,    #:bytes         'Check if there is another if so, process it

ReadMulti_ret ret                               'Return to the calling code

'-----------------------------------------------------------------------------------------------------
'Sub-routine to write to the indirect/parallel Mode Register
' data setup before calling this routine
'-----------------------------------------------------------------------------------------------------
wIndirectMR
              or        dira,   DATAmask        'Ensure data pins are outputs

              andn      outa,   ADD0mask        'Set Address to %00 - Mode Register access
              andn      outa,   ADD1mask

              and       data,   _bytemaskLSB    'Prepare the data, ensure there is only a byte in the data
              shl       data,   BASEpin         'Move the data over so it is in the correct spot for copying to outa

              andn      outa,   DATAmask        'Clear the data pins in outa
              or        outa,   data            'Set the new data in outa

              andn      outa,   WRCSmask        'Clear the WR and CS bits - W5100 reads the data
'             nop                               'Kill time - needed?
              or        outa,   WRRDCSmask      'Turn on WR, RD, and CS bits - end of transaction

wIndirectMR_ret ret                             'Return to the calling code

'-----------------------------------------------------------------------------------------------------
'Sub-routine to read from the indirect/parallel Mode Register
' data is returned in the lower byte
'-----------------------------------------------------------------------------------------------------
rIndirectMR
              andn      dira,   DATAmask        'Ensure data pins are inputs

              andn      outa,   ADD0mask        'Set Address to %00 - Mode Register access
              andn      outa,   ADD1mask

              andn      outa,   RDCSmask        'Clear the RD and CS bits
              nop                               'Kill time?  Needed, maybe - see W5100 data sheet, may even want 2 nops
              mov       data,   ina             'Copy data from ina
              or        outa,   WRRDCSmask      'Turn on WR, RD, and CS bits

              shr       data,   BASEpin         'Move the byte to the lowest byte
              and       data,   _bytemaskLSB    'Finalize the data to have only the lowest byte

rIndirectMR_ret ret                             'Return to the calling code

'-----------------------------------------------------------------------------------------------------
'Sub-routine to write to the indirect/parallel Address Registers
' reg setup before calling this routine
'-----------------------------------------------------------------------------------------------------
wIndirectAR
              'MSB address byte
              or        dira,   DATAmask        'Ensure data pins are outputs

              or        outa,   ADD0mask        'Set Address to %01 - MSB address Register access
              andn      outa,   ADD1mask

              mov       t1,     reg             'Get a copy of reg for manipulating
              and       t1,     _bytemaskMSB    'Prepare the byte for sending to W5100
              shr       t1,     #8              'Right justify the byte
              shl       t1,     BASEpin         'Move the byte to the data lines

              andn      outa,   DATAmask        'Clear the data pins in outa
              or        outa,   t1              'Set the MSB address in outa

              andn      outa,   WRCSmask        'Clear the WR and CS bits - W5100 reads the data
'             nop                               'Kill time - needed?
              or        outa,   WRRDCSmask      'Turn on WR, RD, and CS bits - end of transaction

              'LSB address byte
              andn      outa,   ADD0mask        'Set Address to %10 - LSB address Register access
              or        outa,   ADD1mask

              mov       t1,     reg             'Get a copy of reg for manipulating
              and       t1,     _bytemaskLSB    'Prepare the byte for sending to W5100
              shl       t1,     BASEpin         'Move the byte to the data lines

              andn      outa,   DATAmask        'Clear the data pins in outa
              or        outa,   t1              'Set the LSB address in outa

              andn      outa,   WRCSmask        'Clear the WR and CS bits - W5100 reads the data
'             nop                               'Kill time - needed?
              or        outa,   WRRDCSmask      'Turn on WR, RD, and CS bits - end of transaction

wIndirectAR_ret ret                             'Return to the calling code

'-----------------------------------------------------------------------------------------------------
'Sub-routine to setup for writing to the indirect/parallel Data Registers
'-----------------------------------------------------------------------------------------------------
wIndirectDRsetup
              or        dira,   DATAmask        'Ensure data pins are outputs

              or        outa,   ADD0mask        'Set Address to %11 - Data Register access
              or        outa,   ADD1mask

wIndirectDRsetup_ret ret                        'Return to the calling code

'-----------------------------------------------------------------------------------------------------
'Sub-routine to write to the indirect/parallel Data Registers - must be setup first
' data setup before calling this routine
'-----------------------------------------------------------------------------------------------------
wIndirectDRbyte
              shl       data,   BASEpin         'Move the data over so it is in the correct spot for copying to outa

              andn      outa,   DATAmask        'Clear the data pins in outa
              or        outa,   data            'Set the new data in outa

              andn      outa,   WRCSmask        'Clear the WR and CS bits - W5100 reads the data
'             nop                               'Kill time - needed?
              or        outa,   WRRDCSmask      'Turn on WR, RD, and CS bits - end of transaction

wIndirectDRbyte_ret ret                         'Return to the calling code

'-----------------------------------------------------------------------------------------------------
'Sub-routine to setup for reading from the indirect/parallel Data Registers
'-----------------------------------------------------------------------------------------------------
rIndirectDRsetup
              andn      dira,   DATAmask        'Ensure data pins are inputs

              or        outa,   ADD0mask        'Set Address to %11 - Data Register access
              or        outa,   ADD1mask

rIndirectDRsetup_ret ret                        'Return to the calling code

'-----------------------------------------------------------------------------------------------------
'Sub-routine to read from the indirect/parallel Data Registers - must be setup first
' data is returned in the lower byte
'-----------------------------------------------------------------------------------------------------
rIndirectDRbyte
              andn      outa,   RDCSmask        'Clear the RD and CS bits
              nop                               'Kill time?  Needed, maybe - see W5100 data sheet, may even want 2 nops
              mov       data,   ina             'Copy data from ina
              or        outa,   WRRDCSmask      'Turn on WR, RD, and CS bits

              shr       data,   BASEpin         'Move the byte to the lowest byte
              and       data,   _bytemaskLSB    'Finalize the data to have only the lowest byte

rIndirectDRbyte_ret ret                         'Return to the calling code


DAT
'-----------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------
'Defined data
_zero         long      0       'Zero
_bytemaskLSB  long      $FF     'Byte mask LSB
_bytemaskMSB  long      $FF00   'Byte mask MSB
_rstTime      long      100_000 'Time to hold in reset
_UnrstTime    long      200_000 'Time to wait coming out of reset

'Pin/mask definitions are initianlized in SPIN and program/memory modified here before the COG is started
ADD0mask      long      0-0     'W5100 Address[0] - output
ADD1mask      long      0-0     'W5100 Address[1] - output
CSmask        long      0-0     'W5100 Chip Select - active low, output
RDmask        long      0-0     'W5100 Read cmd - active low, output
WRmask        long      0-0     'W5100 Write cmd - active low, output
RESETmask     long      0-0     'W5100 Reset - active low, output

BASEpin       long      0-0     'Base pin of data byte for shifting operation
DATAmask      long      0-0     'W5100 Data[0] to [7] - output/input

WRCSmask      long      0-0     'Various combinations of masks for the CS, RD, and WR pins for expidited processing in ASM routine
RDCSmask      long      0-0     '
WRRDCSmask    long      0-0     '

SENmask       long      0-0     'W5100 SPI Enable 0 output, low = indirect/parallel, high = SPI

'Data defined in constant section, but needed in the ASM for program operation
_S0_MR_d      long      _S0_MR
_S0_PORT1_d   long      _S0_PORT1
_S0_DPORT1_d  long      _S0_DPORT1
_S0_DIPR0_d   long      _S0_DIPR0
_S0_CR_d      long      _S0_CR

'-----------------------------------------------------------------------------------------------------
'-----------------------------------------------------------------------------------------------------
'Uninitialized data
'temporary variables
t0            res 1     'temp0
t1            res 1     'temp1

'Parameters read from commands passed into the ASM routine
cmdAdd        res 1     'Combo of command and address passed into ASM
paramA        res 1     'Parameter A
paramB        res 1     'Parameter B
paramC        res 1     'Parameter C
paramD        res 1     'Parameter D
paramE        res 1     'Parameter E

reg           res 1     'Register address of W5100 for processing
ram           res 1     'Ram address of Prop Hubram for reading/writing data from
ctr           res 1     'Counter of bytes for looping
data          res 1     'Data read to/from the W5100

fit 496                 'Ensure the ASM program and defined/res variables fit in a COG.

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