unit ConsoleProcess;
{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, process, Pipes;

type
  TmnOnWriteString = procedure(S: string) of object;

  { TmnProcessObject }

  TmnProcessReadStream = (strmOutput, strmError);

  TmnProcessObject = class(TObject)
  protected
    FBuffer: string;
  public
    Process: TProcess;
    Thread: TThread;
    OnWrite: TmnOnWriteString;
    function IsTerminated: Boolean;
    function Read(ReadStream: TmnProcessReadStream = strmOutput): Integer;
    procedure FlushBuffer;
    constructor Create(AProcess: TProcess; AThread: TThread; AOnWrite: TmnOnWriteString);
  end;

  { TmnConsoleThread }

  TmnConsoleThread = class(TThread)
  private
    FOnWriteString: TmnOnWriteString;
  protected
    Buffer: string;
    procedure DoOnWriteString; virtual; //To Sync
    procedure WriteString(S: string);
  public
    Process: TProcess;
    Status: Integer;
    constructor Create(AProcess: TProcess; AOnWriteString: TmnOnWriteString = nil);
    destructor Destroy; override;
    procedure Execute; override;
    procedure Read; virtual;
    property OnWriteString: TmnOnWriteString read FOnWriteString write FOnWriteString;
  end;

implementation

type
  THackThread = class(TThread)
  end;

procedure TmnProcessObject.FlushBuffer;
begin
  if Assigned(OnWrite) then
  begin
    OnWrite(FBuffer);
    FBuffer := '';
  end;
end;

constructor TmnProcessObject.Create(AProcess: TProcess; AThread: TThread; AOnWrite: TmnOnWriteString);
begin
  inherited Create;
  Process := AProcess;
  Thread := AThread;
  OnWrite := AOnWrite;
end;

function TmnProcessObject.IsTerminated: Boolean;
begin
  Result := (Thread <> nil) and THackThread(Thread).Terminated;
end;

function TmnProcessObject.Read(ReadStream: TmnProcessReadStream): Integer;
const
  READ_BYTES = 1024;
var
  C, Count, L: DWORD;
  FirstTime: Boolean;
  aStream: TInputPipeStream;
begin
  FirstTime := True;
  Count := 0;
  C := 0;
    try
      Process.Execute;
      if ReadStream = strmOutput then
        aStream := Process.Output
      else
        aStream := Process.Stderr;

      while not IsTerminated and (FirstTime or Process.Running or (C > 0)) do
      begin
        L := Length(FBuffer);
        Setlength(FBuffer, L + READ_BYTES);
        C := aStream.Read(FBuffer[1 + L], READ_BYTES);
        if Assigned(OnWrite) then
        begin
          SetLength(FBuffer, L + C);
          if Length(FBuffer) > 0 then
          begin
            if Thread <> nil then
              Thread.Synchronize(Thread, @FlushBuffer)
            else
              FlushBuffer;
          end;
        end;

        if C > 0 then
          Inc(Count, C)
        else
          Sleep(100);

        if not Assigned(OnWrite) then
        begin
          //SetLength(FBuffer, L + C);
        end;

        FirstTime := False;
      end;

      Process.WaitOnExit;

      Result := Process.ExitStatus;
    except
      on e : Exception do
      begin
        if Process.Running and IsTerminated then
          Process.Terminate(0);
      end;
    end;
end;

{ TmnConsoleThread }

procedure TmnConsoleThread.DoOnWriteString;
begin
  if Assigned(FOnWriteString) then
    FOnWriteString(Buffer);
end;

procedure TmnConsoleThread.WriteString(S: string);
begin
  Buffer := S;
  Synchronize(@DoOnWriteString);
  //DoOnWriteString;
  Buffer := '';
end;

constructor TmnConsoleThread.Create(AProcess: TProcess; AOnWriteString: TmnOnWriteString);
begin
  inherited Create(true);
  Process := AProcess;
  FOnWriteString := AOnWriteString;
end;

destructor TmnConsoleThread.Destroy;
begin
  inherited Destroy;
end;

procedure TmnConsoleThread.Read;
var
  C: DWORD;
  T: string;
  aBuffer: array[0..79] of AnsiChar;
begin
  aBuffer := '';
  while Process.Running do
  begin
    repeat
      //if (Process.Output.NumBytesAvailable > 0) then
      C := Process.Output.Read(aBuffer, SizeOf(aBuffer));
      if C > 0 then
      begin
        SetString(T, aBuffer, C);
        if T <> '' then
          WriteString(T);
      end;
    until C = 0;
  end;
  WriteString('------exit--------');
end;

procedure TmnConsoleThread.Execute;
begin
  Read;
end;

end.

