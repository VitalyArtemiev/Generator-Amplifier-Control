unit ReadingThreads;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, BaseConF, blcksock;

type

  { tDetBufferThread }
  tDetBufferThread = class(tThread)
    DataList: TList;
    constructor Create(BufferLength: longword);
    procedure Execute; override;
  private
    BuffByte1, BuffByte2: array of byte;
    ParamArr: tIntegerArray;
  end;

 { tDetSimultaneousThread }

  tDetSimultaneousThread = class(tThread)
    DataList: TList;
    procedure Execute; override;
    constructor Create;
  end;

 { tDetOnePerStepThread }

  tDetOnePerStepThread = class(tThread)
    DataList: TList;
    procedure Execute; override;
    constructor Create;
  end;


  { tTempBufferThread }

  tTempBufferThread = class(tThread)
    DataList: TList;
    constructor Create(BufferLength: longword);
    procedure Execute; override;
  private
    Buffers: array of array of double;
    ParamArr: tIntegerArray;
  end;

 { tTempRealTimeThread }

  tTempRealTimeThread = class(tThread)
    DataList: TList;
    Socket: tTCPBlockSocket;
    procedure Execute; override;
    function WaitForPoints(ParamCount{, Number}: integer): PBuffer;
    constructor Create;
    destructor Destroy; override;
  end;

 { tTempSimultaneousThread }

  tTempSimultaneousThread = class(tThread)
    DataList: TList;
    procedure Execute; override;
    constructor Create;
  end;

 { tTempOnePerStepThread }

  tTempOnePerStepThread = class(tThread)
    DataList: TList;
    procedure Execute; override;
    constructor Create;
  end;

implementation

uses
  math, DeviceF, DetControlF, TempControlF;

{ tTempBufferThread }

constructor tTempBufferThread.Create(BufferLength: longword);
begin
  setlength(Buffers, BufferLength);
  setlength(ParamArr, 3);
  inherited Create(false);
  FreeOnTerminate:= false;
end;

procedure tTempBufferThread.Execute;
var
  s: string;
  PointsToRead: longint;
  i: integer;
begin
  with TempControlForm do
    repeat
      try
        EnterCriticalSection(CommCS);
          AddCommand(tStoredPoints, true);               //paus+
          PassCommands;
          s:= RecvString;
      finally
        LeaveCriticalSection(CommCS);
      end;
      val(s, PointsToRead);

      for i:= 0 to PointsToRead do
      begin

      end;

    until Terminated;
end;

function tTempRealTimeThread.WaitForPoints(ParamCount{, Number}: integer): PBuffer;
var
  {Count, }i: integer;
  s: array of string;
begin
  Result:= nil;
  with TempControlForm do
  case ConnectionKind of
    cNone:
      WriteProgramLog('WaitForPoints called without connection');
    cSerial:
      WriteProgramLog('WaitForPoints unsopported for Serial');
    cUSB:
      WriteProgramLog('WaitForPoints for USB under construction');
    cTelNet:
    begin
      setlength(s, ParamCount);
      //repeat
      while (Socket.WaitingData = 0) and not Terminated do    //into readingthreads
        sleep(1);

        if Socket.WaitingData > 0 then
        begin
          for i:= 0 to ParamCount - 1 do
            s[i]:= RecvString;

          new(Result);
          setlength(Result^, ParamCount);

          for i:= 0 to ParamCount - 1 do
            val(s[i], Result^[i]);
          //inc(Count);
        end
      //until Count = Number;
    end;
    cVXI:
      WriteProgramLog('WaitForPoints for VXI under construction');
  end;
end;

{ tTempRealTimeThread }

procedure tTempRealTimeThread.Execute;
var
  pd: PBuffer;
begin
  with TempControlForm do
  repeat
    pd:= WaitForPoints(length(ParToRead));

    if pd <> nil then
    begin
      DataList:= Log.ThreadList.LockList;
        DataList.Add(pd);
      Log.ThreadList.UnlockList;
      Log.ReadPoints+= 1;{length(pd^);}  //add storedpoints field like in buffer?
    end
  until Terminated;
end;

constructor tTempRealTimeThread.Create;
begin
  inherited Create(false);
  FreeOnTerminate:= false;
  if Assigned(TempControlForm.TelNetClient) then
    Socket:= TempControlForm.TelNetClient.Sock;
end;

destructor tTempRealTimeThread.Destroy;
begin
  Socket:= nil;
  inherited Destroy;
end;

{ tTempOnePerStepThread }

procedure tTempOnePerStepThread.Execute;
var
  pd: PBuffer;
  pt: PDateTime;
begin
  with TempControlForm do
  begin
    pd:= RecvSnap(ParToRead);

    if pd <> nil then
    begin
      new(pt);
      pt^:= Log.ElapsedTime;
      DataList:= Log.ThreadList.LockList;
        DataList.Add(pt);
        DataList.Add(pd);
      Log.ThreadList.UnlockList;
      inc(Log.ReadPoints);
    end;
  end;
end;

constructor tTempOnePerStepThread.Create;
begin
  inherited Create(false);
  FreeOnTerminate:= false;
end;

{ tTempSimultaneousThread }

procedure tTempSimultaneousThread.Execute;
var
  pd: PBuffer;
  pt: PDateTime;
begin
  with TempControlForm do
  repeat
    pd:= RecvSnap(ParToRead);

    if pd <> nil then
    begin
      new(pt);
      pt^:= Log.ElapsedTime;
      DataList:= Log.ThreadList.LockList;
        DataList.Add(pt);
        DataList.Add(pd);
      Log.ThreadList.UnlockList;
      inc(Log.ReadPoints);
    end
  until Terminated;
end;

constructor tTempSimultaneousThread.Create;
begin
  inherited Create(false);
  FreeOnTerminate:= false;
end;

{ tDetOnePerStepThread }

constructor tDetOnePerStepThread.Create;
begin
  inherited Create(false);
  FreeOnTerminate:= false;
end;

procedure tDetOnePerStepThread.Execute;
var
  pd: PBuffer;
  pt: PDateTime;
begin
  with DetControlForm do
  begin
    pd:= RecvSnap(ParToRead);

    if pd <> nil then
    begin
      new(pt);
      pt^:= Log.ElapsedTime;
      DataList:= Log.ThreadList.LockList;
        DataList.Add(pt);
        DataList.Add(pd);
      Log.ThreadList.UnlockList;
      inc(Log.ReadPoints);
    end;
  end;
end;

{ tDetSimultaneousThread }

constructor tDetSimultaneousThread.Create;
begin
  inherited Create(false);
  FreeOnTerminate:= false; { TODO : exactly why }
end;

procedure tDetSimultaneousThread.Execute;
var
  pd: PBuffer;
  pt: ^TDateTime;
begin
  with DetControlForm do
  repeat
    try
      pd:= RecvSnap(ParToRead);

    except on E:Exception do
      writeprogramlog(E.Message);
    end;

    if pd <> nil then
    begin
      new(pt);
      pt^:= Log.ElapsedTime;
      DataList:= Log.ThreadList.LockList;
        DataList.Add(pt);
        DataList.Add(pd);
      Log.ThreadList.UnlockList;
      inc(Log.ReadPoints);
    end
  until Terminated;
end;

{ tDetBufferThread }

constructor tDetBufferThread.Create(BufferLength: longword);
begin
  setlength(BuffByte1, BufferLength * 4);
  setlength(BuffByte2, BufferLength * 4);
  setlength(ParamArr, 3);
  inherited Create(false);
  FreeOnTerminate:= false;
end;

procedure tDetBufferThread.Execute;
var
  StoredPoints: longint = 0;
  PointsToRead: longint;
  p1, p2: PBuffer;
  i: integer;
  s: string;
  o: ^smallint;
begin
  with DetControlForm do
  repeat
    try
      EnterCriticalSection(CommCS);
      AddCommand(dStoredPoints, true);               //paus+
      PassCommands;
      s:= RecvString;
    finally
      LeaveCriticalSection(CommCS);
    end;

    val(s, StoredPoints);
    //AddCommand(PAUS, false);
    //PassCommands;
    PointsToRead:= StoredPoints - Log.ReadPoints;

    if PointsToRead > 0 then
    begin
      Serport.RaiseExcept:= false;

      ParamArr[0]:= 1;
      ParamArr[1]:= Log.ReadPoints;
      ParamArr[2]:= PointsToRead;
      try
        EnterCriticalSection(CommCS);
          AddCommand(dReadPointsNative, true, ParamArr);
          PassCommands;
          SerPort.RecvBufferEx(@BuffByte1[0], PointsToRead * 4, CurrentDevice^.Timeout);

          ParamArr[0]:= 2;

          AddCommand(dReadPointsNative, true, ParamArr);
          PassCommands;

          SerPort.RecvBufferEx(@BuffByte2[0], PointsToRead * 4, CurrentDevice^.Timeout);
      finally
          Serport.RaiseExcept:= true;
        LeaveCriticalSection(CommCS);
      end;

      new(p1);
      new(p2);
      setlength(p1^, PointsToRead);
      setlength(p2^, PointsToRead);
      for i:= 0 to PointsToRead - 1 do
      begin
        o:= @BuffByte1[i*4];
        p1^[i]:= smallint(o^) * power(2, BuffByte1[i*4 + 2] - 124);    //конвертация из внутр. формата

        o:= @BuffByte2[i*4];
        p2^[i]:= smallint(o^) * power(2, BuffByte2[i*4 + 2] - 124);
      end;

      DataList:= Log.ThreadList.LockList;
        DataList.Add(p1);
        DataList.Add(p2);
        i:= DataList.Count;
      Log.ThreadList.UnlockList;
      Log.ReadPoints:= StoredPoints;
    end;
    //AddCommand(STRT, false);
    //PassCommands;
    { TODO 1 -cBug : Continuos buffer }
  until Terminated;
end;

end.
