CON
  _clkmode = xtal1 + pll16x     
  _xinfreq = 5_000_000

  BUFFER_2K     = $800
  
  CR            = $0D
  LF            = $0A
  NULL          = $00
  
  #0, CLOSED, TCP, UDP, IPRAW, MACRAW, PPPOE

       
VAR

DAT
  udpHead       byte  192, 168, 1, 104, $1F, $90, $00, $0C
  udpMsg        byte  "Hello World!", $0
  
  buff          byte  $0[BUFFER_2K]

   
OBJ
  pst           : "Parallax Serial Terminal"
  sock          : "Socket"
  wiz           : "W5200"


 
PUB Main | bytesToRead, bytesSent, receiving

  receiving := true
  bytesToRead := 0
  pst.Start(115_200)
  pause(500)
  bytesToRead~

  'Set network parameters
  wiz.Start(WIZ#SPI_CS, WIZ#SPI_SCK, WIZ#SPI_MOSI, WIZ#SPI_MISO) 
  wiz.SetCommonnMode(0)
  wiz.SetGateway(192, 168, 1, 1)
  wiz.SetSubnetMask(255, 255, 255, 0)
  wiz.SetIp(192, 168, 1, 130)
  wiz.SetMac($00, $08, $DC, $16, $F8, $01)
  

  pst.str(string("Initialize", CR))
  sock.Init(0, UDP, 10000)
  sock.RemoteIp(192, 168, 1, 106)
  sock.RemotePort(8000)

  

  
  pst.str(string("Start UPD Socket Server",CR))
  pst.str(string("Open",CR))
  pst.str(string("---------------------------",CR))
  sock.Open 
  repeat

    'Data in the buffer?
    repeat until bytesToRead := sock.DataReady

    'Get the Rx buffer  
    sock.Receive(@buff, bytesToRead)

    {{ Process the Rx data  }} 
    pst.char(CR)
    pst.str(string("Request:",CR))
    PrintIp(@buff)
    pst.dec(DeserializeWord(@buff + 4))
    pst.char(CR)
    
    pst.dec(DeserializeWord(@buff + 6))
    pst.char(CR)
    
    pst.str(@buff + 8)
    pst.char(CR)

    DisplayMemory(@buff, 36, true)
    
    pst.str(string("Send Response",CR))

    
    'sock.RemoteIp(192, 168, 1, 104)
    'sock.RemotePort(8080)
    'PrintIp(sock.GetIp)
    'pst.dec(sock.GetPort)
    
    sock.Send(@udpMsg, strsize(@udpMsg))

    'pst.str(string("Disconnect",CR))
    'sock.Disconnect
    
    bytesToRead~

PUB DisplayMemory(addr, len, isHex) | j
  pst.str(string(13,"-----------------------------------------------------",13))
  pst.str(string(13, "      "))
  repeat j from 0 to $F
    pst.hex(j, 2)
    pst.char($20)
  pst.str(string(13, "      ")) 
  repeat j from 0 to $F
    pst.str(string("-- "))

  pst.char(13) 
  repeat j from 0 to len
    if(j == 0)
      pst.hex(0, 4)
      pst.char($20)
      pst.char($20)
      
    if(isHex)
      pst.hex(byte[addr + j], 2)
    else
      pst.char($20)
      if(byte[addr+j] == 0)
        pst.char($20)
      pst.char(byte[addr+j])

    pst.char($20) 
    if((j+1) // $10 == 0) 
      pst.char($0D)
      pst.hex(j+1, 4)
      pst.char($20)
      pst.char($20)  
  pst.char(13)
  
  pst.char(13)
  pst.str(string("Start: "))
  pst.dec(addr)
  pst.str(string(" Len: "))
  pst.dec(len)
  pst.str(string(13,"-----------------------------------------------------",13,13))
      
PUB PrintIp(addr) | i
  repeat i from 0 to 3
    pst.dec(byte[addr][i])
    if(i < 3)
      pst.char($2E)
    else
      pst.char($0D)
      
      
PRI SerializeWord(value, buffer)
  byte[buffer++] := (value & $FF00) >> 8
  byte[buffer] := value & $FF

PRI DeserializeWord(buffer) | value
  value := byte[buffer++] << 8
  value += byte[buffer]
  return value
        
PRI pause(Duration)  
  waitcnt(((clkfreq / 1_000 * Duration - 3932) #> 381) + cnt)
  return