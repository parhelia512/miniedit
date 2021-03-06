unit EditorRun;
{$mode objfpc}{$H+}
{$ModeSwitch advancedrecords}
{**
 * Mini Edit
 *
 * @license    GPL 2 (http://www.gnu.org/licenses/gpl.html)
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *}

interface

uses
  Forms, SysUtils, StrUtils, Classes, SyncObjs, contnrs,
  mnUtils, ConsoleProcess, process,
  mnStreams, mneConsoleForms, EditorDebugger, mnClasses, mnXMLUtils;

{$i '..\lib\mne.inc'}

type
  TmneRunErrorType = (
    errError,
    errWarning,
    errParse,
    errNotice
  );

  TmneRunLog = record
    Error: Integer;
    Caption: string;
    Msg: string;
    FileName: string;
    LineNo: Integer;
  end;

  TmneRun = class;
  TmneRunItem = class;
  TmneRunPool = class;

  TRunMessageType = (msgtTemp, msgtLog, msgtOutput);

  { TmneRunItem }

  TmneRunItem = class(TObject)
  private
    FBreakOnFail: Boolean;
  protected
    FProcess: TProcess;
    FControl: TConsoleForm;
    FPool: TmneRunPool;
  protected
    FOnWrite: TmnOnWriteString;
    InternalString: string;
    InternalMessageType: TRunMessageType;
    procedure InternalWrite; //This for sync it, it will send to FOnWriteString
    procedure WriteOutput(S: string); //This assign it to consoles
    procedure InternalMessage; //This for sync it, it will send to FWriteString
    procedure WriteMessage(S: string; vMessageType: TRunMessageType = msgtLog); //This assign it to consoles
  protected
    procedure CreateControl;
    procedure CreateConsole(AInfo: TmneCommandInfo);
    procedure Attach; //To Sync
  public
    Info: TmneCommandInfo;
    Status: integer;
    procedure Execute; virtual;
    procedure Stop; virtual;
    constructor Create(APool: TmneRunPool);
    property BreakOnFail: Boolean read FBreakOnFail write FBreakOnFail;
    property Process: TProcess read FProcess;
  end;

  TmneRunItemClass = class of TmneRunItem;

  { TmneRunItems }

  TmneRunItems = class(specialize GItems<TmneRunItem>);

  { TmneRunPool }

  TmneRunPool = class(TThread)
  protected
    FRun: TmneRun;
    FItems: TmneRunItems;
    FCurrent: TmneRunItem;
    procedure UpdateState;
  public
    constructor Create(ARun: TmneRun);
    destructor Destroy; override;
    procedure Execute; override;
    procedure Stop;
    procedure Show;
    property Items: TmneRunItems read FItems;
    property Current: TmneRunItem read FCurrent;
  end;

  { TmneRun }

  TmneRun = class(TObject)
  private
    FPool: TmneRunPool;
    function GetActive: Boolean;
  protected
    procedure PoolTerminated(Sender: TObject);
  public
    constructor Create;
    destructor Destroy; override;
    function Add(AItemClass: TmneRunItemClass = nil): TmneRunItem; //Return same as parameter
    procedure Clear;
    procedure Start;
    procedure Show;
    procedure Stop;
    property Active: Boolean read GetActive;
    property Pool: TmneRunPool read FPool;
  end;

implementation

uses
  {$ifdef windows}
  Windows,
  {$endif}
  EditorEngine, gdbClasses, lclintf;

{ TmneRunPool }

procedure TmneRunPool.Execute;
begin
  while not Terminated and (Items.Count > 0) do
  begin
    FCurrent := Items[0];
    Items.Extract(Current);
    Current.Execute;
    if Current.BreakOnFail and (Current.Status > 0) then
      Items.Clear;
    FreeAndNil(FCurrent);
    //Synchronize(@UpdateState); //not yet
  end
end;

procedure TmneRunPool.Stop;
begin
  if FCurrent <> nil then
    FCurrent.Stop;
  Terminate;
  WaitFor;
end;
                            
{$ifdef windows}
function WindowsProc(windowHandle: HWND; lParam: LPARAM): Bool; stdcall;
var
  aProcessID: DWORD;
begin
  aProcessID := 0;
  GetWindowThreadProcessId(windowHandle, aProcessID);
  if (THANDLE(lParam) = aProcessID) then
  begin
    SetForegroundWindow(windowHandle);
    Result := False;
    exit;
  end;
  Result := True;
end;
{$endif}

procedure ShowProcess(ID: THandle);
begin  
  {$ifdef windows}
  EnumWindows(@WindowsProc, LPARAM(ID));       
  {$endif}
end;

procedure TmneRunPool.Show;
begin
  //TODO lock.Enter and Leave
  {$ifdef windows}
  if (Current.Process <> nil) and Current.Process.Active then
  begin
    ShowProcess(Current.Process.ProcessID);
  end;
  {$endif}
end;

procedure TmneRunPool.UpdateState;
begin
  Engine.UpdateState([ecsDebug]);
end;

constructor TmneRunPool.Create(ARun: TmneRun);
begin
  inherited Create(True);
  FItems := TmneRunItems.Create(True);
  FRun := ARun;
end;

destructor TmneRunPool.Destroy;
begin
  FreeAndNil(FItems);
  inherited Destroy;
end;

{ TmneRun }

function TmneRun.GetActive: Boolean;
begin
  Result := FPool <> nil;
end;

procedure TmneRun.PoolTerminated(Sender: TObject);
begin
  FPool := nil;
  Engine.UpdateState([ecsDebug]);
end;

constructor TmneRun.Create;
begin
  inherited Create;
end;

destructor TmneRun.Destroy;
begin
  Stop;
  inherited Destroy;
end;

procedure TmneRun.Start;
begin
  if FPool = nil then
    raise Exception.Create('There is no thread Pool');
  FPool.Start;
end;

procedure TmneRun.Show;
begin
  if FPool <> nil then
    FPool.Show;
end;

procedure TmneRun.Stop;
begin
  if FPool <> nil then
  begin
    FPool.Stop;
  end;
end;

function TmneRun.Add(AItemClass: TmneRunItemClass): TmneRunItem;
begin
  if FPool = nil then
  begin
    FPool := TmneRunPool.Create(Self);
    FPool.FreeOnTerminate := True;
    FPool.OnTerminate := @PoolTerminated;
  end;

  if AItemClass = nil then
    Result := TmneRunItem.Create(FPool)
  else
    Result := AItemClass.Create(FPool);
  FPool.Items.Add(Result);
end;

procedure TmneRun.Clear;
begin
  Stop;
  FreeAndNil(FPool);
end;

procedure TmneRunItem.CreateControl;
begin
  FControl := TConsoleForm.Create(Application);
  FControl.Parent := Engine.Container;
  Engine.Files.New('CMD: ' + Info.Title, FControl);

  FControl.CMDBox.Font.Color := Engine.Options.Profile.Attributes.Default.Foreground;
  FControl.CMDBox.BackGroundColor := Engine.Options.Profile.Attributes.Default.Background;
  FControl.ContentPanel.Color := FControl.CMDBox.BackGroundColor;

  FControl.CMDBox.Font.Name := Engine.Options.Profile.Attributes.FontName;
  FControl.CMDBox.Font.Size := Engine.Options.Profile.Attributes.FontSize;
  //FControl.CMDBox.GraphicalCharacterWidth := 14;

  FControl.CMDBox.TextColor(Engine.Options.Profile.Attributes.Default.Foreground);
  FControl.CMDBox.TextBackground(Engine.Options.Profile.Attributes.Default.Background);
  FControl.CMDBox.Write('Ready!'+#13#10);
  FOnWrite := @FControl.WriteText;
  Engine.UpdateState([ecsRefresh]);
end;

procedure TmneRunItem.Attach;
begin
  if Engine.Tendency.Debug <> nil then
  begin
    Engine.Tendency.Debug.Start;
    Engine.Tendency.Debug.Attach(Process, True);
  end;
end;

procedure TmneRunItem.InternalWrite;
begin
  if Assigned(FOnWrite) then
    FOnWrite(InternalString);
end;

procedure TmneRunItem.WriteOutput(S: string);
begin
  InternalString := S;
  FPool.Synchronize(@InternalWrite);
  InternalString := '';
end;

procedure TmneRunItem.InternalMessage;
begin
  //if not Engine.IsShutdown then //not safe to ingore it
  case InternalMessageType of
    msgtTemp: Engine.SendMessage(InternalString, True);
    msgtLog: Engine.SendLog(InternalString);
    msgtOutput: Engine.SendMessage(InternalString);
  end
end;

procedure TmneRunItem.WriteMessage(S: string; vMessageType: TRunMessageType = msgtLog);
begin
  InternalString := S;
  InternalMessageType := vMessageType;
  FPool.Synchronize(@InternalMessage);
  InternalString := '';
end;

procedure TmneRunItem.Stop;
begin
  if FProcess <> nil then
    FProcess.Terminate(1);
end;

constructor TmneRunItem.Create(APool: TmneRunPool);
begin
  inherited Create;
  BreakOnFail := True;
  FPool := APool;
end;

procedure TmneRunItem.CreateConsole(AInfo: TmneCommandInfo);
var
  ProcessObject: TmnProcessObject;
  aOptions: TProcessOptions;
begin
  if (AInfo.Message <> '') then
    WriteMessage(AInfo.Message + #13#10);
  WriteMessage(AInfo.Message + #13#10);
  FProcess := TProcess.Create(nil);
  FProcess.ConsoleTitle := Info.Title;
  FProcess.InheritHandles := True;
  FProcess.CurrentDirectory := ReplaceStr(AInfo.CurrentDirectory, '\', '/');

  FProcess.Executable := ReplaceStr(AInfo.Run.Command, '\', '/');
  WriteMessage(AInfo.Run.Params);
  CommandToList(AInfo.Run.Params, FProcess.Parameters);

  aOptions := [];
  if Info.Suspended then
    aOptions := [poRunSuspended];

  if Assigned(FOnWrite) then
  begin
    FProcess.Options :=  aOptions + [poUsePipes, poStderrToOutPut];
    FProcess.ShowWindow := swoShowNormal;
    FProcess.StartupOptions:=[suoUseShowWindow];
    FProcess.PipeBufferSize := 0; //80 char in line
    ProcessObject := TmnProcessObject.Create(FProcess, FPool, @WriteOutput);
    try
      Status := ProcessObject.Read(strmOutput);
    finally
      FreeAndNil(FProcess);
      FreeAndNil(ProcessObject);
    end;
  end
  else
  begin
    FProcess.Options :=  aOptions + [poWaitOnExit];
    FProcess.ShowWindow := swoShow;
    FProcess.StartupOptions:=[suoUseShowWindow]; //<- need it in linux to show window
    FProcess.CloseInput;
    FProcess.Execute;
    //Status := ProcessObject.Read(strmOutput);
  end;
  WriteMessage(#13#10'End Status: ' + IntToStr(Status)+#13#10, msgtLog);
  WriteMessage('Done', msgtTemp);
end;

procedure TmneRunItem.Execute;
var
  s: string;
{$ifdef windows}
{$else}
  term: string;
{$endif}
begin
  case Info.Run.Mode of
    runConsole:
    begin
      if Info.DebugIt then
      begin
        Info.Run.Command := Info.GetCommandLine;
        Info.Run.Params := '';
        Info.Suspended := True;
        CreateConsole(Info);
        FPool.Synchronize(@Attach);
        Process.Resume;
      end
      else
      begin
        {$ifdef windows}
        s := '/c "'+ Info.GetCommandLine + '"';
        if Info.Run.Pause then
          s := s + ' & pause';
        Info.Run.Params := s;
        Info.Run.Command := 'cmd';
        {$else}

        //s := GetEnvironmentVariable('SHELL');
        term := GetEnvironmentVariable('COLORTERM');
        if term = '' then
           term := GetEnvironmentVariable('TERM');
        if term = '' then
           term := 'xterm';

        //xterm -e "lua lua-test.lua && bash"
        //xterm -e "lua lua-test.lua && read -rsp $''Press any key to continue'' -n1 key"


        if Info.Title <> '' then
            s := '-title "' + Info.Title + '"'
        else
            s := '';
        if term = 'xterm' then
            s := s + ' -fa "' + Engine.Options.Profile.Attributes.FontName+  '" -fs ' + IntToStr(Engine.Options.Profile.Attributes.FontSize);
        s := s + ' -e "'+Info.GetCommandLine;
        if Info.Run.Pause then
          s := s + '; read -rsp $''Press any key to continue'' -n1 key';
        s := s + '"';
        Info.Run.Params := s;

        Info.Run.Command := term;

        {$endif}
        //FOnWrite := @Engine.SendOutout;
        CreateConsole(Info);
      end;
    end;
    runOutput:
    begin
      FOnWrite := @Engine.SendOutout;
      CreateConsole(Info);
    end;
    runBox:
    begin
      FPool.Synchronize(FPool, @CreateControl);
      CreateConsole(Info);
      //not free myself the thread will do
    end;
    runBrowser:
    begin
      OpenURL(Info.Link);
    end;
  end;
end;

end.
