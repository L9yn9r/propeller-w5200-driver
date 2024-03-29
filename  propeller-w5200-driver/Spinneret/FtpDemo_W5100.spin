{{
  Basic FTP Server
  -------------------------------------
  Author:   Mike Gebhard
  Release:  1/7/2014
  Email:    mike.gebhard@agaverobotics.com

  This library was created and tested using FileZilla and
  implements the basic commands to get FileZilla working.

  If something is not working as expected check if
  "502 Command not implemented" was returned.

  For more information on the FTP protocol see
  http://tools.ietf.org/html/rfc959
   
}}
CON
  _clkmode = xtal1 + pll16x     
  _xinfreq = 5_000_000

  { Buffers Size}
  MAIN_BUFFER        = $800  '2K
  WORKSPACE_BUFFER   = $100  '256
  WORKING_DIR_BUFFER = $50   '80
  MAX_PORT_RESPONSE  = 30 

  { ASCII Characters }
  CR    = $0D
  LF    = $0A
  SPACE = $20

  { SD IO }
  DISK_PARTION  = 0
  SUCCESS       = -1
  IO_OK         = 0
  IO_READ       = "r"
  IO_WRITE      = "w"
  FORWARD_SLASH = "/"

  { FTP Ports }
  FTP_COMMAND_PORT          =  21     'Default FTP Command Port
  FTP_DEFAULT_DATA_PORT     =  8156   'Default FTP Data Port (Not standard)

  { Enums }
  #0, IP_4, IP_3, IP_2, IP_1, PORT_HIGH, PORT_LOW
  #0, FTP_COMMAND, FTP_COMMAND_PARAM
  #0, FTP_PI_1, FTP_PI_2, FTP_DTP
  #0, CLIENT_TO_SERVER_DTP, SERVER_TO_CLIENT_DTP
  #0, CLOSED, TCP, UDP, IPRAW, MACRAW, PPPOE

  #0, DATA_RECEIVED, CLIENT_CLOSED_CON, CLIENT_OPENED_NEW_CON

  FILE_TYPES    = 2
  #0, TYPE_FILE, TYPE_DIR
  
  TYPE_COMMANDS = 7
  #0, TYPE_A, TYPE_N, TYPE_T, TYPE_E, TYPE_C, TYPE_I, TYPE_L
  
  FTP_COMMANDS  = 21
  #0, CMD_PWD,  CMD_CWD,  CMD_MKD, {
}     CMD_USER, CMD_PASS, CMD_SYST, CMD_FEAT, CMD_TYPE, {
}     CMD_PASV, CMD_LIST, CMD_QUIT, CMD_PORT, CMD_MODE, {
}     CMD_STRU, CMD_RETR, CMD_STRO, CMD_NOOP, CMD_XPWD, {
}     CMD_CDUP, CMD_SIZE, CMD_DELE
     

  { Spinneret PIN IO  }  
  SPI_MISO          = 0 ' SPI master in serial out from slave 
  SPI_MOSI          = 1 ' SPI master out serial in to slave
  SPI_CS            = 2 ' SPI chip select (active low)
  SPI_SCK           = 3  ' SPI clock from master to all slaves
  WIZ_INT           = 13
  WIZ_RESET         = 14
  WIZ_SPI_MODE      = 15

  { FTP Configuration }
  ALLOW_ANONYMOUS = true
  
VAR

DAT
  ver             byte  "1.0",0
  username        byte  "anonymous",0
  password        byte  "anon@localhost",0
  hostIp          byte  192,168,1,191
  macAddr         byte  $00, $08, $DC, $16, $F1, $32
  subnet          byte  255, 255, 255, 0
  router          byte  192, 168, 1, 1

OBJ
  pst           : "Parallax Serial Terminal"
  wiz           : "W5100" 
  sock[3]       : "Socket"
  sd            : "S35390A_SD-MMC_FATEngineWrapper"
 
PUB Main | connected, rc, oldId
  connected := false
  
  InitAll
  
  repeat 'Main program
    connected := Welcome
    repeat while(connected)
      rc := \WaitForClientCommand(@buff, @clientCmd, @buffCount)
      case rc
        CLIENT_OPENED_NEW_CON:
          oldId := piId
          piId := NextPiId
          'Send welcome
          Send(@rc220, piId)
          CloseDisconnect(oldId)
          OpenListen(oldId)
        CLIENT_CLOSED_CON:
          connected := false
        DATA_RECEIVED:        
          ProcessFtpCommand(clientCmd[0])


PRI ProcessFtpCommand(command) | id, ptr
{{
  Process client FTP commands and set up passive connections.
}}
  id := CommandId(command)
  
  case id
    CMD_PWD: 'Working directory
      pst.str(string(CR, "**** PWD ****", CR))
      ptr := BuildCwdResponse(@rc257, @cwdBuff)
      Send(ptr, piId)
    CMD_XPWD: ' Win FTP
      pst.str(string(CR, "**** XPWD ****", CR))
      ptr := BuildCwdResponse(@rc257, @cwdBuff)
      Send(ptr, piId)
    CMD_CWD:
      pst.str(string(CR, "**** CWD ****", CR))
      if(ChangeDir(clientCmd[FTP_COMMAND_PARAM]))
        if AddCwd(@cwdBuff, clientCmd[FTP_COMMAND_PARAM])
          ptr := BuildCwdResponse(@rc250, @cwdBuff)
          Send(ptr, piId)
        else
          Send(@rc553, piId)
      else
        Send(@rc450, piId)
    CMD_CDUP:
      pst.str(string(CR, "**** CDUP ****", CR))
      UpDir
      send(@rc200,piId)
      ptr := BuildCwdResponse(@rc250, @cwdBuff)
      Send(ptr, piId) 
    CMD_USER:  'Username
      pst.str(string(CR, "**** USER ****", CR))
      ValidateUserName(clientCmd[FTP_COMMAND_PARAM])
      Send(@rc331, piId)
    CMD_PASS: 'Password
      pst.str(string(CR, "**** PASS ****", CR))
      if(ValidatePassword(clientCmd[FTP_COMMAND_PARAM], @workspace))  
        Send(@rc230, piId)
      else
        Send(@rc332, piId) 
    CMD_SYST: 'System
      Send(@rc215, piId) 
    CMD_FEAT: 'Features
      pst.str(string(CR, "**** FEAT ****", CR))
      Send(@rc211, piId)
    CMD_TYPE:
      pst.str(string(CR, "**** TYPE ****", CR)) 
      type := types[TypeId(clientCmd[FTP_COMMAND_PARAM])]
      Send(@rc200type, piId) 
    CMD_PASV: 'Passive 
      pst.str(string(CR, "**** PASV ****", CR))
      Send(@rc227, piId)
    CMD_LIST: 'Directory of files and folder
      pst.str(string(CR, "**** LIST ****", CR))
      BufferDirectoryList(@buff)
      OpenSocket(FTP_DTP, ConnDirection)
      ReceivePassiveConnection(FTP_DTP)
      Send(@rc150, piId)
      Send(@buff, FTP_DTP)
      Send(@rc226, piId)
      CloseDisconnect(FTP_DTP)
    CMD_QUIT:
      pst.str(string(CR, "**** QUIT ****", CR))
      return false
    CMD_PORT: 'Client determines the port
      pst.str(string(CR, "**** PORT ****", CR))
      ConnDirection := SERVER_TO_CLIENT_DTP
      ProcessPortValue(clientCmd[FTP_COMMAND_PARAM])
      InitSocket(FTP_DTP, FTP_DEFAULT_DATA_PORT)
      InitRemoteHostPort(FTP_DTP, @ipPort)
      Send(@rc200, piId) 
    CMD_MODE: 'S - Stream, B - Block, C - Compressed
      pst.str(string(CR, "**** MODE ****", CR))
      Send(@rc202, piId)
    CMD_STRU: 'Structure
      pst.str(string(CR, "**** STRU ****", CR))
      Send(@rc202, piId) 
    CMD_RETR: 'Retrive
      pst.str(string(CR, "**** RETR ****", CR))
      ptr := BuildPath(@cwdBuff, clientCmd[FTP_COMMAND_PARAM])
      OpenSocket(FTP_DTP, ConnDirection)
      ReceivePassiveConnection(FTP_DTP)
      Send(@rc150, piId)
      SendFile(FTP_DTP, ptr, @buff)
      Send(@rc226, piId)
      CloseDisconnect(FTP_DTP)
    CMD_SIZE:
      pst.str(string(CR, "**** SIZE ****", CR))
      Send(@rc502, piId)  
    CMD_STRO: 'Store
      pst.str(string(CR, "**** STRO ****", CR))
      PrepareFileForSTOR(clientCmd[FTP_COMMAND_PARAM])
      OpenSocket(FTP_DTP, ConnDirection)
      Send(@rc150, piId)
      StoreFile(FTP_DTP, clientCmd[FTP_COMMAND_PARAM], @buff)
      Send(@rc226, piId)
      pst.str(@buff)
      CloseDisconnect(FTP_DTP)
    CMD_DELE:
      DeleteFile(clientCmd[FTP_COMMAND_PARAM])
      Send(@rc250d, piId) 
    CMD_NOOP:
      pst.str(string(CR, "**** NOOP ****", CR))
      Send(@rc200, piId)
    CMD_MKD: 'Create directory
      pst.str(string(CR, "**** MKD ****", CR))
      MakeDirectory(@cwdBuff, clientCmd[FTP_COMMAND_PARAM]) 
      Send(@rc200, piId) 
    OTHER:
      pst.str(string(CR, "**** Unknown Command: "))
      pst.str(command)
      pst.str(string(" ****", CR))
      Send(@rc502, piId)

  pst.str(string("**** End ****", CR, CR))
  ResetBuffer    
  return true

{--------------------------------
 Enumerations  
---------------------------------}
PRI CommandId(command) : i
{{
  Converts a client command to an enumeration (number).
}}
  repeat i from 0 to FTP_COMMANDS-1
    if(strcomp(@@ptrcmds[i], command))
      return i
  return -1 

PRI TypeId(typeVal) : i
{{
  Converts a type to an enumeration
}}
  repeat i from 0 to TYPE_COMMANDS- 1
    if(types[i] == byte[typeVal])
      return i
  return 0 'Default to ASCII   

{--------------------------------
  Connection management
---------------------------------}
PRI Welcome
{{
  Displays a welcome message on connection to port 21.  This
  can happen several times during an FTP session. 
  Welcome blocks until a connection is made by the client
}}
  pst.str(string(CR, "Listening for client FTP connections", CR))

  'First connection?
  if(piId == $FFFF_FFFF)
    piId := FTP_PI_1
  else
    CloseDisconnect(NextPiId)
    
  OpenListen(piId) 
  repeat until sock[piId].Connected
    pause(100)
  Send(@rc220, piId)

  'Start the second PI listener
  OpenListen(NextPiId)
  return true
  
PRI WaitForClientCommand(buffer, command, ptrBuffCount) | rc
{{
  Listens for a client command on the PI (protocol interpreter) connection.
}}
  result := WaitForData(buffer, piId, ptrBuffCount)
  if (result == DATA_RECEIVED)
    ReadClientData(buffer, piId, ptrBuffCount) 
    WriteDebugLine(string("<-- bytesToRead"), long[ptrBuffCount], true) 
    long[command][0] := buffer
    long[command][1] := SplitCommand(buffer)
    pst.str(string("<-- "))
    WriteDebugLine(string("Command"), clientCmd[FTP_COMMAND], false)
    pst.str(string("<-- ")) 
    WriteDebugLine(string("Value"), clientCmd[FTP_COMMAND_PARAM], false)
    
  WriteDebugLine(string("Client Cmd Result"), result, true) 


PRI WaitForData(buffer, sockId, ptrBuffCount) | nextId
{{
  Blocks until a client command is received unless the current
  PI connection is closed by the client or a new connection is established.
}}
  nextId := NextPiId
  'Wait for data in the buffer
  WriteDebugLine(string("Current Socket"), piId, true) 
  WriteSocketStatus(FTP_PI_1, sock[FTP_PI_1].GetStatus)
  WriteSocketStatus(FTP_PI_2, sock[FTP_PI_2].GetStatus) 
  repeat until (long[ptrBuffCount] := sock[sockId].Available) > 0
    pause(500)
    'WriteHexDebugLine(string("Status"), sock[sockId].GetStatus, 2)
    if(sock[sockId].IsCloseWait)
      return CLIENT_CLOSED_CON
    if(sock[sockId].IsClosed)
      return CLIENT_CLOSED_CON 
    if(sock[nextId].Connected)
      return CLIENT_OPENED_NEW_CON
      
  return DATA_RECEIVED

  
PRI ReadClientData(buffer, sockId, ptrBuffCount)
{{
  Moves data from the socket buffer to main memory
}}
  'Check for a timeout
  if(long[ptrBuffCount] > 0)
    sock[sockId].Receive(buffer, long[ptrBuffCount])
    buff[long[ptrBuffCount]] := 0
    return true
    
  buff[0] := 0
  return false

PRI ReceivePassiveConnection(sockId) | status
{{
  Waits for the client to connect after
  receiving the PASV command
}}
  pst.str(string("Receive PASV", CR))
  WriteSocketStatus(sockId, sock[sockId].GetStatus)
  
  repeat 
    status := sock[sockId].GetStatus
    if( status > $16)
      return status
    pause(10)

  return -1

PRI Send(msg, sockId)
{{
  Command return code and message
}}
  pst.str(String("--> "))
  pst.str(msg)
  sock[sockId].Send(msg, strsize(msg))
    
{--------------------------------
  File and directory  
---------------------------------}
PRI BuildPath(cwd, fn) | ptr
{{
  Builds a file path using a pointer to the current
  working directory and file name
}}
  ptr := StrMove(@workspace, cwd)
  
  ifnot(byte[ptr-1] == FORWARD_SLASH)
    byte[ptr++] := FORWARD_SLASH
    
  ptr := StrMove(ptr, fn)
  byte[ptr] := null
  WriteDebugLine(string("BuildPath"), @workspace, false)
  return @workspace 

PRI FileExists(path) | rc
{{
  Verify the file exists
}}
  rc := sd.listEntry(path)
  return rc == 0


PRI PrepareFileForSTOR(fn)
{{
  Prepares a file for the STOR command.
  Create the file if the file does not exit
  and open the file.   
}}
  if(FileExists(fn))
    sd.deleteEntry(fn)

  sd.newFile(fn)
  Openfile(fn, IO_WRITE)

  
PRI ChangeDir(dir) | t1, i
{{
  Change directory
}}
  t1 := sd.changeDirectory(dir)

  repeat i from 0 to 11
    if byte[t1][i] == 32
       byte[t1][i] := 0
       quit
       
  if not strcomp(dir, @cwdBuff)
    SetCwd(dir)

  return true

PRI BufferDirectoryList(buffer) | t1, t2, ptr
{{
  Creates a directory listing in memory.  This
  list is sent to the client in response to the
  LIST command

  type=dir; dir
  type=file; file.text 
}}

  ptr := buffer
  sd.startFindFile
  repeat while t1 := sd.nextFile
    'dir=0 or file=1 type
    t2 := sd.ListType(t1)
    ptr := StrMove(ptr, @@ptrFileTypes[t2])
    'size
    if(t2 == 1)
      t2 := sd.getFileSize
      ptr := StrMove(ptr, @filesize)
      ptr := StrMove(ptr, Dec(t2))
      ptr := StrMove(ptr, string("; "))
    ptr := StrMove(ptr, t1)
    byte[ptr++] := CR
    byte[ptr++] := LF
  byte[ptr] := 0
  return ptr-buffer
    
{--------------------------------
 File IO  
---------------------------------}
PRI SendFile(sockId, fn, buffer) | fs, bytes, mtuBuff
{{
  Render a static file from the SD Card
}}
  mtuBuff := sock[sockId].GetMtu

  OpenFile(fn, IO_READ)
  fs := sd.getFileSize 

  repeat until fs =< 0
    if(fs < mtuBuff)
      bytes := fs
    else
      bytes := mtuBuff

    sd.readFromFile(buffer, bytes)
    fs -= sock[sockId].Send(buffer, bytes)

  sd.closeFile
  return

PRI OpenFile(path, ioType) | rc
{{
  Open a file
}}
  if(FileExists(path))
    rc := sd.openFile(path, ioType)
    if(rc == SUCCESS)
      return true
  return false

PRI DeleteFile(fn)
{{
  Delete a file
}}
  sd.deleteEntry(fn)

  
PRI MakeDirectory(cwd, dir) | ptr
{{
  Make a directory using a pointer to the current
  working directory and directory sent from the client
}}
  ptr := @workspace
  ptr := StrMove(ptr, cwd) 
  
  if(strsize(cwd) > 4)
    byte[ptr++] := "/"
    
  ptr := StrMove(ptr, dir)
  byte[ptr] := 0
  WriteDebugLine(string("MKD"), @workspace, false)
  
  sd.Createdirectory(@workspace)
    
PRI StoreFile(sockId, fn, buffer) | totalBytes, bytesToRead
{{
  Store file on the SD card.
}}
  totalBytes~
  'Read until bytesToRead = 0
  repeat while bytesToRead := sock[sockId].Available
    WriteDebugLine(string("bytesToRead"), bytesToRead, true)
    
    'Timeout waiting for initial data
    if(bytesToRead < 0)
      sd.closeFile 
      return bytesToRead 

    'Update total bytes received and write bytes to the SD card  
    totalBytes += bytesToRead
    sock[sockId].Receive(buffer, bytesToRead)
    sd.writeData(buffer, bytesToRead)

  sd.closeFile
  return totalBytes


{--------------------------------
  Current working directory  
---------------------------------}  
PRI AddCwd(path, dir) | ptr
{{
  Add a directory to the current working directory buffer
  /help/me/find/the/path,CR,LF,0, _    
}}


  if((strsize(path) + strsize(dir)) > WORKING_DIR_BUFFER)
    return false

  if(strcomp(path, dir))
    WriteDebugLine(string("CWD"), path, false)
    return true  
    
  ptr := path
  ptr += strsize(ptr)
  
  if(strsize(path) > 4)
    byte[ptr++] := "/"
    
  ptr := StrMove(ptr, dir)
  byte[ptr] := 0
  WriteDebugLine(string("CWD"), path, false)

  return true

PRI RemoveLastCwd(path) | ptr, char
{{
  Remove the last current working directory from the buffer
  /help/me/find/the/path,CR,LF,0, _
}}

  if(strsize(path) == 3)
    return
    
  ptr := path
  ptr += strsize(ptr)

  repeat until (char == "/")
    char := byte[--ptr]
    
  if(ptr > path)
    byte[ptr] := 0
  else
    byte[++ptr] := 0
    
  WriteDebugLine(string("CWD"), path, false) 

PRI UpDir | ptr
{{
  Up one directory level
}}
  ptr := \ChangeDir(string(".."))
  RemoveLastCwd(@cwdBuff)
  WriteDebugLine(string("Up dir"), @cwdBuff, false)
  return ptr

PRI SetCwd(path) | ptr
{{
  Set the current working directory
}}
  ptr := StrMove(@cwdBuff, path)
  byte[ptr] := 0


PRI BuildCwdResponse(ptrCode, ptrCwd) | ptr
{{
  Build a the client response with response code
}}
  ptr := StrMove(@workspace, ptrCode)
  ptr := Strmove(ptr, ptrCwd)
  ptr := StrMove(ptr, @cwdEnd)
  byte[ptr] := null
  return @workspace
  

{--------------------------------
  Username and password
---------------------------------}
PRI ValidateUserName(user)
{{
  Immediately returns true of ALLOW_ANONYMOUS is set to true.
  Otherwise, stores the user name in the workspace buffer to
  be validated with the password.
}}
  if (ALLOW_ANONYMOUS)
    return true
     
  'buffer the username for later validation
  bytemove(@workspace, user, strsize(user))
  workspace[strsize(user)] := null
  return true

PRI ValidatePassword(pass, user)
{{
  Immediately returns true of ALLOW_ANONYMOUS is set to true.
  Otherwise, validates the username and password received by
  the client.  
}}
  if(ALLOW_ANONYMOUS)
    return true
  return strcomp(@password, pass) AND strcomp(@username, user)

{--------------------------------
 Helper methods  
---------------------------------}

PRI StrMove(dest, src)
{{
  Move a string and return a pointer pointing to
  the end of the string
}}
  bytemove(dest, src, strsize(src))
  return dest+strsize(src)


PRI NextPiId
{{
  Returns the next PI ID. There are
  two PI sockets; 0 and 1.  Only one is
  active at a time.
}}
  case piId
    FTP_PI_1: result := FTP_PI_2
    FTP_PI_2: result := FTP_PI_1
    other: result := FTP_PI_1
      
PRI SplitCommand(buffer) : valptr | char
{{
  Split the client command and command parameters

  TODO: Refactor
}}
  valptr := buffer
  'find the first space
  repeat until (char := byte[buffer++]) == SPACE
    'Validation
    if(buffer-valptr) > 5
      buffer :=  valptr
      valptr := @null
      repeat until (char := byte[buffer++]) == 0 
        if IsToken(char)
          byte[buffer-1] := 0
      return
  
  'Found the first space.
  'Place a zero between the command and value 
  byte[buffer-1] := 0
  valptr := buffer
  
  'Replace the end of line chars (13, 10) with zeros
  repeat until (char := byte[buffer++]) == 0 
    if IsToken(char)
      byte[buffer-1] := 0

  
PRI IsToken(value)
{{
  Used to find CR or LF
}}
  return lookdown(value & $FF: CR, LF)

  
PRI ProcessPortValue(ptr)  | char, i, t1
{{
  Used to initialize an active connection.
  
  Convert IP and Port strings to numeric values.

  NOTE: Active connections require firewall setup!
}}
  t1 := ptr
  i := 0

  repeat until (char := byte[ptr++]) == 0
    if (char == ",")
      byte[ptr-1] := 0
      ipPort[i++] := StrToBase(t1, 10) & $FF
      t1 := ptr
         
  'Last value
  ipPort[i] := StrToBase(t1, 10) & $FF

PRI InitRemoteHostPort(sockId, params)
{{
  Used to initialize an active connection.
  
  Initialize IP and Port

  NOTE: Active connections require firewall setup!
}}
  PrintIp(params)
  sock[sockId].RemoteIp(byte[params][0], byte[params][1], byte[params][2], byte[params][3]) 
  WriteHexDebugLine(string("Remote Port"), BytesToWord(byte[params][4], byte[params][5]), 4)  
  sock[sockId].RemotePort(BytesToWord(byte[params][4], byte[params][5]))

 
PRI ResetBuffer
{{
  Reset buffer, client command, and command
  parameter
}}
  buff := 0
  clientCmd[0] := @null
  clientCmd[1] := @null
  

{--------------------------------
  Initialize Hardware
---------------------------------}  
PRI InitAll
{{
  Initialize hardware sockets
}}
  InitPst
  InitWiz
  InitSdDriver
  InitSocket(FTP_PI_1, FTP_COMMAND_PORT)
  InitSocket(FTP_PI_2, FTP_COMMAND_PORT) 
  InitSocket(FTP_DTP, FTP_DEFAULT_DATA_PORT)
  InitPassiveIpAndPort(@pasIpPort)
  InitCwdBuff(@cwdBuff)

PRI InitCwdBuff(ptrCwd)
{{
  Initialize the current working directory
}}
  byte[ptrCwd][0] := "/"
  byte[ptrCwd][1] := 0 

PRI InitPst
{{
  Initialize terminal
}}
  pst.Start(115_200)   
  
PRI InitWiz
{{
    Initialize Wiznet
}}
  wiz.HardReset(WIZ#WIZ_RESET)
  pause(1500)
  pst.str(string("Starting PropNet FTP Server v0.5",CR))
  wiz.Start(WIZ#SPI_CS, WIZ#SPI_SCK, WIZ#SPI_MOSI, WIZ#SPI_MISO)
  wiz.SetCommonnMode(0)
  wiz.SetGateway(router[0], router[1], router[2], router[3])
  wiz.SetSubnetMask(subnet[0], subnet[1], subnet[2], subnet[3])
  wiz.SetIp(hostIp[0], hostIp[1], hostIp[2], hostIp[3])
  wiz.SetMac(macAddr[0], macAddr[1], macAddr[2], macAddr[3], macAddr[4], macAddr[5])
  pst.str(string("IP Address: "))
  PrintIp(@hostIp)
  pst.char(CR)

PRI InitPassiveIpAndPort(ptr227) | snum, i
{{
  Initialize the passive IP and port response code and
  parameters.
}}
  pasIpPort := 0

  'Convert the number IP to a string ip separated by commas
  repeat i from 0 to 3
    snum := dec(hostIp[i])
    ptr227 := StrMove(ptr227, snum) 
    byte[ptr227++] := ","

  'Convert the numeric port to a string port separated by commas
  'and end with a ) 
  snum := dec(FTP_DEFAULT_DATA_PORT >> 8)
  ptr227 := StrMove(ptr227, snum)
  byte[ptr227++] := "," 

  snum := dec(FTP_DEFAULT_DATA_PORT & $FF)
  ptr227 := StrMove(ptr227, snum)
  byte[ptr227++] := ")"

  'End of line with zero terminator
  byte[ptr227++] := CR
  byte[ptr227++] := LF
  byte[ptr227++] := 0

PRI InitSdDriver
{{
  Initialize the SD driver
}}
  ifnot(sd.Start)
    pst.str(string("Failed to start SD driver", CR))
  else
    pst.str(string("Started SD Driver -> "))
  pst.str(string("Mount SD Card - "))
  pst.str(sd.mount(DISK_PARTION))
  pst.char(CR)
  pst.char(CR)

{--------------------------------
  Socket Methods
---------------------------------}
PRI InitSocket(sockId, ftpPort)
{{
  Initialize a socket
}}
  WriteDebugLine(string("Init Socket"), sockId, true)
  WriteDebugLine(string("On Port"), ftpPort, true)
  sock[sockId].Init(sockId, TCP, ftpPort)
  

PRI OpenSocket(sockId, conDirection)
{{
  Open a socket in response to the PASV command.
}}
  WriteDebugLine(string("Con Direction"), conDirection, true)
  if(conDirection == CLIENT_TO_SERVER_DTP)
    OpenListen(sockId)
  if(conDirection == SERVER_TO_CLIENT_DTP)
    OpenConnect(sockId)   
  
PRI OpenListen(sockId)
{{
  Set a socket to open then listen.
}}
  WriteDebugLine(string("Open Listen Sock"), sockId, true)
  
  sock[sockId].Open
  WriteHexDebugLine(string("Open"), sock[sockId].GetStatus, 2)
  sock[sockId].Listen
  WriteHexDebugLine(string("Listen"), sock[sockId].GetStatus, 2)


PRI OpenConnect(sockId)
{{
  Set a socket to open then connect.
}}
  WriteDebugLine(string("Open Connect Sock"), sockId, true)
  
  sock[sockId].Open
  WriteHexDebugLine(string("Open"), sock[sockId].GetStatus, 2)
  pause(200)
  sock[sockId].Connect
  WriteHexDebugLine(string("Connect"), sock[sockId].GetStatus, 2)
  
PRI CloseDisconnect(sockId)
{{
  Close and disconnect a socket.
}}
  WriteDebugLine(string("Close Disconnect Sock"), sockId, true)
  
  sock[sockId].Disconnect
  WriteHexDebugLine(string("Disconnect"), sock[sockId].GetStatus, 2)
  sock[sockId].Close
  WriteHexDebugLine(string("Close"), sock[sockId].GetStatus, 2) 

{--------------------------------
  Helper Methods
---------------------------------}
PRI StrToBase(stringptr, base) : value | chr, index
{Converts a zero terminated string representation of a number to a value in the designated base.
Ignores all non-digit characters (except negative (-) when base is decimal (10)).}

  value := index := 0
  repeat until ((chr := byte[stringptr][index++]) == 0)
    chr := -15 + --chr & %11011111 + 39*(chr > 56)                              'Make "0"-"9","A"-"F","a"-"f" be 0 - 15, others out of range     
    if (chr > -1) and (chr < base)                                              'Accumulate valid values into result; ignore others
      value := value * base + chr                                                  
  if (base == 10) and (byte[stringptr] == "-")                                  'If decimal, address negative sign; ignore otherwise
    value := - value

PUB Dec(value) | i, x, j
{{Send value as decimal characters.
  Parameter:
    value - byte, word, or long value to send as decimal characters.

Note: This source came from the Parallax Serial Termianl library
}}

  j := 0
  x := value == NEGX                                                            'Check for max negative
  if value < 0
    value := ||(value+x)                                                        'If negative, make positive; adjust for max negative                                                                  'and output sign

  i := 1_000_000_000                                                            'Initialize divisor

  repeat 10                                                                     'Loop for 10 digits
    if value => i
      workspace[j++] := value / i + "0" + x*(i == 1)                                      'If non-zero digit, output digit; adjust for max negative
      value //= i                                                               'and digit from value
      result~~                                                                  'flag non-zero found
    elseif result or i == 1
      workspace[j++] := "0"                                                                'If zero digit (or only digit) output it
    i /= 10
    
  workspace[j] := 0
  return @workspace
  
PRI BytesToWord(hByte, lByte)
  return ((hByte<<8) + lByte)
  
PRI pause(Duration)  
  waitcnt(((clkfreq / 1_000 * Duration - 3932) #> 381) + cnt)
  return

{--------------------------------
  Debug
---------------------------------}
PRI SocketStatuses
  WriteHexDebugLine(string("CMD Sock Status"), sock[piId].GetStatus, 2)
  WriteHexDebugLine(string("Data socket Status"), sock[FTP_DTP].GetStatus, 2)
  
PUB PrintIp(addr) | i
  repeat i from 0 to 3
    pst.dec(byte[addr][i])
    if(i < 3)
      pst.char($2E)
    else
      pst.char($0D)
      
PRI WriteSocketStatus(sockId, value)
  pst.str(string("Socket["))
  pst.dec(sockId)
  pst.str(string("]"))
  repeat 25-9
    pst.char(".")
  pst.hex(value, 2)
  pst.char(CR)
 
PRI PrintBuffer
  {{ Process the Rx data}}
  pst.char(CR)
  pst.str(@buff)

PRI WriteHexDebugLine(label, value, digits)
  pst.str(label)
  repeat 25 - strsize(label)
    pst.char(".")

  pst.hex(value, digits)
  pst.char(CR)
  
PRI WriteDebugLine(label, value, isNum)
    pst.str(label)
  repeat 25 - strsize(label)
    pst.char(".")
  if(isNum)
    pst.dec(value)
  else
    pst.str(value)
  pst.char(CR)

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

DAT
  'buffers
  ipPort          byte  $0[5],0
  buff            byte  $0[MAIN_BUFFER+1]
  workspace       byte  $0[WORKSPACE_BUFFER]
  cwdBuff         byte  $0[WORKING_DIR_BUFFER]
  
  'Return code and state
  rc200           byte  "200 Ok",CR,LF,0
  rc200type       byte  "200 Type set to "
  type            byte  "I",CR,LF,0
  rc202           byte  "202 Command not implemented, superfluous at this site.",CR,LF,0 
  rc220           byte  "220 Welcome to the PropNet FTP Server.",CR,LF,0
  rc331           byte  "331 User name okay, need password.",CR,LF,0
  rc332           byte  "332 Need account for login.",CR,LF,0 
  rc230           byte  "230 Logged On",CR,LF,0
  rc215           byte  "215 PropNet",CR,LF,0
  rc211           byte  "211-Features:",CR, LF,"REST STREAM",CR,LF,"UTF8",CR,LF,"211 End",CR,LF,0
  rc250           byte  "250 CWD successful. ", $22, 0
  rc257           byte  "257 ", $22, 0
  cwdEnd          byte  $22, " is the current directory",CR,LF,0
  rc250d          byte  "250 File deleted successfully",CR,LF,0
  rc227           byte  "227 Entering Passive Mode ("
  pasIpPort       byte  $0[27],0  'default port 31,220 = 8156 
  rc150           byte  "150 Connection Accepted",CR,LF,0
  rc226           byte  "226 Transfer complete",CR,LF,0
  rc450           byte  "450 Requested file action not taken.", CR, LF, 0
  rc502           byte  "502 Command not implemented.",CR,LF,0
  rc553           byte  "553 Requested action not taken. Directory buffer overrun",CR,LF,0
  types           byte  "A","N","T","E","C","I","L"
  modes           byte  "S","B","C"
  mode            byte  "S"
  fileTypes       byte  "type=dir; ",0,"type=file;",0
  fileSize        byte  "size=",0
  ptrFileTypes    long  @filetypes+0, @filetypes+11 
  cmds3           byte  "PWD", 0, "CWD", 0, "MKD", 0
  cmds4           byte  "USER",0, "PASS",0, "SYST",0, "FEAT",0, "TYPE",0, {
}                       "PASV",0, "LIST",0, "QUIT",0, "PORT",0, "MODE",0, {
}                       "STRU",0, "RETR",0, "STOR",0, "NOOP",0, "XPWD",0, {
}                       "CDUP",0, "SIZE",0, "DELE", 0
  ptrcmds         long  @cmds3+00, @cmds3+04, @cmds3+08, {
}                       @cmds4+00, @cmds4+05, @cmds4+10, @cmds4+15, @cmds4+20, {
}                       @cmds4+25, @cmds4+30, @cmds4+35, @cmds4+40, @cmds4+45, {
}                       @cmds4+50, @cmds4+55, @cmds4+60, @cmds4+65, @cmds4+70, {
}                       @cmds4+75, @cmds4+80, @cmds4+85
                     
  'State
  piId            long  $FFFF_FFFF 
  clientCmd       long  $0[2]
  buffCount       long  $0
  ConnDirection   long  CLIENT_TO_SERVER_DTP
  null            long  $0
{{
┌──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                   TERMS OF USE: MIT License                                                  │                                                            
├──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┤
│Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation    │ 
│files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy,    │
│modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software│
│is furnished to do so, subject to the following conditions:                                                                   │
│                                                                                                                              │
│The above copyright notice and this permission notice shall be included in all copies or substantial ions of the Software.│
│                                                                                                                              │
│THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE          │
│WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR         │
│COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,   │
│ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.                         │
└──────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────────┘
}}