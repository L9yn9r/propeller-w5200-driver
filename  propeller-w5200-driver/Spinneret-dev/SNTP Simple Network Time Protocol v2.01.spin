OBJ
{{
******************************************************************
* SNTP Simple Network Time Protocol                       v2.01  *
* Author: Beau Schwabe                                           *
*                                                                *
* Recognition: Benjamin Yaroch, A.G.Schmidt                      *
*                                                                *
* Copyright (c) 2011 Parallax                                    *
* See end of file for terms of use.                              *
******************************************************************


Revision History:
v1      04-07-2011              - File created

v1.01   09-08-2011              - Minor code update to correct days in Month rendering
                                - and replace bytefill with bytemove for the 'ref-id' string                               

v2      01-29-2013              - Fixed an illusive bug that caused problems around the first of the year

v2.01   02-02-2013              - Logic order error with previous bug fix

                           1                   2                   3
       0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9 0 1 2 3 4 5 6 7 8 9  0  1
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |LI | VN  |Mode |    Stratum    |     Poll      |   Precision    |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                          Root  Delay                           |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                       Root  Dispersion                         |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                     Reference Identifier                       |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                                                                |
      |                    Reference Timestamp (64)                    |
      |                                                                |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                                                                |
      |                    Originate Timestamp (64)                    |
      |                                                                |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                                                                |
      |                     Receive Timestamp (64)                     |
      |                                                                |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                                                                |
      |                     Transmit Timestamp (64)                    |
      |                                                                |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                 Key Identifier (optional) (32)                 |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+
      |                                                                |
      |                                                                |
      |                 Message Digest (optional) (128)                |
      |                                                                |
      |                                                                |
      +-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+-+

}}
PUB CreateUDPtimeheader(BufferAddress)
  '---------------------------------------------------------------------
  '                     UDP IP Address - 4 Bytes 
  '---------------------------------------------------------------------
    'BYTEMOVE(BufferAddress,IPAddr,4)
  '---------------------------------------------------------------------
  '                       UDP Header - 4 Bytes 
  '---------------------------------------------------------------------
    'byte[BufferAddress][4] := 0
    'byte[BufferAddress][5] := 123 '<- Port Address 
    'byte[BufferAddress][6] := 0 
    'byte[BufferAddress][7] := 48  '<- Header + Packet
  '---------------------------------------------------------------------
  '                       UDP Packet - 44 Bytes
  '---------------------------------------------------------------------
    byte[BufferAddress][0]  := %11_100_011    'leap,version, and mode
    byte[BufferAddress][1]  := 0              'stratum
    byte[BufferAddress][2] := 0              'Poll   
    byte[BufferAddress][3] := %10010100      'precision
    
    byte[BufferAddress][4] := 0              'rootdelay
    byte[BufferAddress][5] := 0              'rootdelay   
    byte[BufferAddress][6] := 0              'rootdispersion
    byte[BufferAddress][7] := 0              'rootdispersion

    bytemove(BufferAddress+8,string("LOCL"),4) 'ref-id ; four-character ASCII string

    bytefill(BufferAddress+12,0,32)           '(ref, originate, receive, transmit) time 
  
  {
leap           = %11           ; alarm condition (clock not synchronized) 
version        = %011 or %100  ; Version 3 or 4
Mode           = %011          ; Client        
stratum        = %00000000     ; unspecified
Poll           = %00000000     ; = 2^n seconds (maximum interval between successive messages)
precision      = %10010100     ; -20 (8-bit signed integer)
rootdelay      = 0             ; 32 bit value
rootdispersion = 0             ; 32 bit value
ref id         = "LOCL"        ; four-character ASCII string
ref time       = 0             ; 64 bit value
originate time = 0             ; 64 bit value   
receive time   = 0             ; 64 bit value
transmit time  = 0             ; 64 bit value
  }


PUB GetMode(BufferAddress)
    result := byte[BufferAddress][8] & %00000111
    '0 - reserved
    '1 - symmetric active
    '2 - symmetric passive
    '3 - client
    '4 - server
    '5 - broadcast
    '6 - reserved for NTP control message
    '7 - reserved for private use

PUB GetVersion(BufferAddress)    
    result := (byte[BufferAddress][8] & %00111000)>>3
    '3 - Version 3 (IPv4 only)
    '4 - Version 4 (IPv4, IPv6 and OSI)

PUB GetLI(BufferAddress)
    result := (byte[BufferAddress][8] & %11000000)>>6
    '0 - No warning
    '1 - last minute has 61 seconds
    '2 - last minute has 59 seconds
    '3 - alarm condition (clock not synchronized)   

PUB GetStratum(BufferAddress)
    result := byte[BufferAddress][9]
    '0      - unspecified or unavailable
    '1      - primary reference (e.g., radio clock)
    '2-15   - secondary reference (via NTP or SNTP) 
    '16-255 - reserved

PUB GetPoll(BufferAddress)
    result := byte[BufferAddress][10]
    'This is an eight-bit signed integer indicating the
    'maximum interval between successive messages, in seconds
    'to the nearest power of two. The values that can appear
    'in this field presently range from 4 (16 s) to 14 (16384 s);
    'however, most applications use only the sub-range 6 (64 s)
    'to 10 (1024 s). 

PUB GetPrecision(BufferAddress)
    result := byte[BufferAddress][10]
    'This is an eight-bit signed integer indicating the
    'precision of the local clock, in seconds to the nearest
    'power of two. The values that normally appear in this
    'field range from -6 for mains-frequency clocks to -20 for
    'microsecond clocks found in some workstations.

PUB GetRootDelay(BufferAddress)|Temp1
    Temp1 := byte[BufferAddress][12]<<24+byte[BufferAddress][13]<<16
    Temp1 += byte[BufferAddress][14]<<8 +byte[BufferAddress][15]
    result  := Temp1
    'This is a 32-bit signed fixed-point number indicating the
    'total roundtrip delay to the primary reference source, in
    'seconds with fraction point between bits 15 and 16. Note
    'that this variable can take on both positive and negative
    'values, depending on the relative time and frequency offsets.
    'The values that normally appear in this field range from
    'negative values of a few milliseconds to positive values of
    'several hundred milliseconds.

PUB GetRootDispersion(BufferAddress)|Temp1
    Temp1 := byte[BufferAddress][16]<<24+byte[BufferAddress][17]<<16
    Temp1 += byte[BufferAddress][18]<<8 +byte[BufferAddress][19]
    result  := Temp1
    'This is a 32-bit unsigned fixed-point number indicating the
    'nominal error relative to the primary reference source, in
    'seconds with fraction point between bits 15 and 16. The values
    'that normally appear in this field range from 0 to several
    'hundred milliseconds.          

PUB{
      Calling example:          
            PST.str(GetReferenceIdentifier(@Buffer,string("----"))

            dashes get replaced with 4-Character Buffer contents

}   GetReferenceIdentifier(BufferAddress,FillAddress)
    bytemove(FillAddress,BufferAddress+20,4)
    result := FillAddress
{          Reference Identifier return codes
       
           Code     External Reference Source
           -----------------------------------------------------------
           LOCL     uncalibrated local clock used as a primary reference for
                    a subnet without external means of synchronization
           PPS      atomic clock or other pulse-per-second source
                    individually calibrated to national standards
           ACTS     NIST dialup modem service
           USNO     USNO modem service
           PTB      PTB (Germany) modem service
           TDF      Allouis (France) Radio 164 kHz
           DCF      Mainflingen (Germany) Radio 77.5 kHz
           MSF      Rugby (UK) Radio 60 kHz
           WWV      Ft. Collins (US) Radio 2.5, 5, 10, 15, 20 MHz
           WWVB     Boulder (US) Radio 60 kHz
           WWVH     Kaui Hawaii (US) Radio 2.5, 5, 10, 15 MHz
           CHU      Ottawa (Canada) Radio 3330, 7335, 14670 kHz
           LORC     LORAN-C radionavigation system
           OMEG     OMEGA radionavigation system
           GPS      Global Positioning Service
           GOES     Geostationary Orbit Environment Satellite                   }

PUB  GetReferenceTimestamp(Offset,BufferAddress,Long1,Long2)|Temp1
     Temp1 := byte[BufferAddress][24]<<24+byte[BufferAddress][25]<<16
     Temp1 += byte[BufferAddress][26]<<8 +byte[BufferAddress][27]
     long[Long1]:=Temp1
     Temp1 := byte[BufferAddress][28]<<24+byte[BufferAddress][29]<<16
     Temp1 += byte[BufferAddress][30]<<8 +byte[BufferAddress][31]
     long[Long2]:=Temp1     
     'This is the time at which the local clock was
     'last set or corrected, in 64-bit timestamp format.
     HumanTime(Offset,Long1)

PUB  GetOriginateTimestamp(Offset,BufferAddress,Long1,Long2)|Temp1
     Temp1 := byte[BufferAddress][32]<<24+byte[BufferAddress][33]<<16
     Temp1 += byte[BufferAddress][34]<<8 +byte[BufferAddress][35]
     long[Long1]:=Temp1
     Temp1 := byte[BufferAddress][36]<<24+byte[BufferAddress][37]<<16
     Temp1 += byte[BufferAddress][38]<<8 +byte[BufferAddress][39]
     long[Long2]:=Temp1     
     'This is the time at which the request departed the
     'client for the server, in 64-bit timestamp format.
     HumanTime(Offset,Long1)

PUB  GetReceiveTimestamp(Offset,BufferAddress,Long1,Long2)|Temp1
     Temp1 := byte[BufferAddress][40]<<24+byte[BufferAddress][41]<<16
     Temp1 += byte[BufferAddress][42]<<8 +byte[BufferAddress][43]
     long[Long1]:=Temp1
     Temp1 := byte[BufferAddress][44]<<24+byte[BufferAddress][45]<<16
     Temp1 += byte[BufferAddress][46]<<8 +byte[BufferAddress][47]
     long[Long2]:=Temp1     
     'This is the time at which the request arrived at
     'the server, in 64-bit timestamp format.
     HumanTime(Offset,Long1)     

PUB  GetTransmitTimestamp(Offset,BufferAddress,Long1,Long2)|Temp1
     Temp1 := byte[BufferAddress][48]<<24+byte[BufferAddress][49]<<16
     Temp1 += byte[BufferAddress][50]<<8 +byte[BufferAddress][51]
     long[Long1]:=Temp1
     Temp1 := byte[BufferAddress][52]<<24+byte[BufferAddress][53]<<16
     Temp1 += byte[BufferAddress][54]<<8 +byte[BufferAddress][55]
     long[Long2]:=Temp1     
     'This is the time at which the reply departed the
     'server for the client, in 64-bit timestamp format.
     HumanTime(Offset,Long1)
     
PUB HumanTime(Offset,TimeStampAddress)|i,Seconds,Days,Years,LYrs,DW,DD,HH,MM,SS,Month,Date,Year
    Seconds := long[TimeStampAddress] + Offset * 3600
    Days    := ((Seconds >>= 7)/675) + 1 '<- Days since Jan 1, 1900 ... divide by 86,400 and add 1

    DW      := (Days-1) // 7
    
    Years := Days / 365         '   Number of Days THIS year and
    Days -= (Years * 365)       '   number of years since 1900.

    LYrs := Years / 4           '<- Leap years since 1900
    Year := Years + 1900        '<- Current Year                   

    Days -= LYrs                '<- Leap year Days correction
                                '   for THIS year
    repeat
      repeat i from 1 to 12     '<- Calculate number of days 
        Month := 30             '   in each month.  Stop if
         if i&1 <> (i&8)>>3     '   Month has been reached
           Month += 1
        if i == 2
           Month := 28 
        if Days =< Month        '<- When done, Days will contain
           quit                 '   the number of days so far this 
        if Days > Month         '   month.  In other words, the Date.
           Days -= Month     

{
        if Days > Month         '<- When done, Days will contain
           Days -= Month        '   the number of days so far this 
        if Days =< Month        '   month.  In other words, the Date.
           quit     
}

    until Days =< Month
    Month := i                  '<- Current Month               
    Date  := Days               '<- Current Date


    SS := long[TimeStampAddress] + Offset * 3600
    SS := SS -(((Years*365)*675)<<7) '<- seconds this year
         
    MM := SS / 60                        '<- minutes this year
    SS := SS - (MM * 60)                 '<- current seconds

    HH := MM / 60                        '<- hours this year
    MM := MM - (HH * 60)                 '<- current minutes

    DD := HH / 24                        '<- days this year
    HH := HH - (DD * 24)                 '<- current hour

    DD -= LYrs                           '<- Leap year Days correction
                                         '   for THIS year

    long[TimeStampAddress][2] := Month<<24+Date<<16+Year
    long[TimeStampAddress][3] := DW<<24+HH<<16+MM<<8+SS                                     

'    DD is redundant but I included it for completion...
'    If you subtract the number of days so far this year from
'    DD and add one, you should get today's date.  This is calculated
'    from another angle above from Days
     