unit mneLSLClasses;
{$mode objfpc}{$H+}
{**
 * Mini Edit
 *
 * @license    GPL 2 (http://www.gnu.org/licenses/gpl.html)
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *}

interface

uses
  Messages, Forms, SysUtils, StrUtils, Variants, Classes, Controls, Graphics, Contnrs, Dialogs,
  LCLintf, LCLType, LazFileUtils,
  EditorOptions, EditorRun, EditorClasses, mneRunFrames,
  SynEditHighlighter, SynEditSearch, SynEdit, Registry, EditorEngine, mnXMLRttiProfile, mnXMLUtils,
  SynEditTypes, SynCompletion, SynHighlighterHashEntries, EditorProfiles,
  mnSynHighlighterMultiProc, mnSynHighlighterLSL;

type

  { TmneSynLSLSyn }

  TmneSynLSLSyn = class(TSynLSLSyn)
  public
  end;

  { TLSLFile }

  TLSLFile = class(TSourceEditorFile)
  protected
    procedure NewContent; override;
  public
  end;

  { TLSLFileCategory }

  TLSLFileCategory = class(TTextFileCategory)
  private
  protected
    function DoCreateHighlighter: TSynCustomHighlighter; override;
    procedure InitMappers; override;
    procedure InitCompletion(vSynEdit: TCustomSynEdit); override;
    procedure DoExecuteCompletion(Sender: TObject); override;
  public
  end;

  TLSLEditorDebugger = class(TEditorDebugger)
  end;

  { TLSLTendency }

  TLSLTendency = class(TEditorTendency)
  protected
    procedure Created; override;
    function CreateDebugger: TEditorDebugger; override;
    procedure DoRun(Info: TmneRunInfo); override;
  public
    procedure CreateOptionsFrame(AOwner: TComponent; ATendency: TEditorTendency; AddFrame: TAddFrameCallBack); override;
  end;

implementation

uses
  IniFiles, mnStreams, mnUtils;

{ TLSLTendency }

procedure TLSLTendency.Created;
begin
  FCapabilities := [{capExecute, } capLint];
  FHaveOptions := True;
  FName := 'LSL';
  FTitle := 'LSL project';
  FDescription := 'LSL Files, *.LSL';
  FImageIndex := -1;
end;

function TLSLTendency.CreateDebugger: TEditorDebugger;
begin
  //Result := TLSLEditorDebugger.Create;
  Result := inherited CreateDebugger;
end;

procedure TLSLTendency.CreateOptionsFrame(AOwner: TComponent; ATendency: TEditorTendency; AddFrame: TAddFrameCallBack);
var
  aFrame: TRunFrameOptions;
begin
  aFrame := TRunFrameOptions.Create(AOwner);
  aFrame.Options := ATendency.RunOptions;
  EnumRunCommands(aFrame.CommandEdit.Items);
  aFrame.Caption := 'Options';
  AddFrame(aFrame);
end;

procedure TLSLTendency.DoRun(Info: TmneRunInfo);
var
  aRunItem: TmneRunItem;
begin
  Engine.Session.Run.Clear;

  if rnaExecute in Info.Actions then //not yet
  begin
    Engine.SendAction(eaClearOutput);

    aRunItem := Engine.Session.Run.Add;
    aRunItem.Info.Run.Pause := Info.Pause;
    aRunItem.Info.Run.Console := Info.Console;
    aRunItem.Info.Title := ExtractFileNameWithoutExt(Info.MainFile);
    aRunItem.Info.CurrentDirectory := Info.Root;
    aRunItem.Info.StatusMessage := 'Runing ' + Info.MainFile;
    {
    if RunOptions.Require <> '' then
      RunItem.Info.Run.AddParam('-l '+ RunOptions.Require);
    if rnaDebug in Info.Actions then
      aRunItem.Info.Run.AddParam('-e '+ '"require(''mobdebug'').start()"'); //using mobdebug
    }
    aRunItem.Info.Run.Command := Info.Command;
    if Info.Command = '' then
    begin
      {$ifdef windows}
        aRunItem.Info.Run.Command := 'LSL.exe';
      {$else}
        aRunItem.Info.Run.Command := 'LSL';
      {$endif}
    end;
    aRunItem.Info.Run.AddParam(' "' + Info.MainFile + '"');
  end
  else if (rnaLint in Info.Actions) then
  begin
    Engine.SendAction(eaClearOutput);

    aRunItem := Engine.Session.Run.Add;
    aRunItem.Info.Title := ExtractFileNameWithoutExt(Info.MainFile);
    aRunItem.Info.CurrentDirectory := Info.Root;
    aRunItem.Info.Run.Silent := True;
    aRunItem.Info.Run.Console := False;

    aRunItem.Info.StatusMessage := 'Linting ' + Info.MainFile;
    aRunItem.Info.Run.AddParam('-p ');
    //aRunItem.Info.Run.AddParam('-l ');

    {$ifdef windows}
      aRunItem.Info.Run.Command := 'lslint.exe';
    {$else}
      aRunItem.Info.Run.Command := 'lslint';
    {$endif}
    aRunItem.Info.Run.AddParam(' "' + Info.MainFile + '"');
  end;

  if Engine.Session.Run.Active then //if there is items ready to run
    Engine.Session.Run.Start(Debugger);
end;

{ TLSLFileCategory }

function TLSLFileCategory.DoCreateHighlighter: TSynCustomHighlighter;
begin
  Result := TmneSynLSLSyn.Create(nil);
end;

procedure TLSLFileCategory.InitMappers;
begin
  with Highlighter as TSynLSLSyn do
  begin
    Mapper.Add(WhitespaceAttri, attDefault);
    Mapper.Add(CommentAttri, attComment);
    Mapper.Add(ProcessorAttri, attDirective);
    Mapper.Add(KeywordAttri, attKeyword);
    Mapper.Add(DocumentAttri, attDocument);
    Mapper.Add(IdentifierAttri, attIdentifier);
    Mapper.Add(VariableAttri, attVariable);
    Mapper.Add(TypeAttri, attDataType);
    Mapper.Add(ValueAttri, attDataValue);
    Mapper.Add(FunctionAttri, attCommon);
    Mapper.Add(TextAttri, attText);
    Mapper.Add(NumberAttri, attNumber);
    Mapper.Add(StringAttri, attQuotedString);
    Mapper.Add(SymbolAttri, attSymbol);
  end
end;

procedure TLSLFileCategory.InitCompletion(vSynEdit: TCustomSynEdit);
begin
  inherited;
  Completion.EndOfTokenChr := '{}()[].<>/\:!&*+-=%;';//what about $
end;

procedure TLSLFileCategory.DoExecuteCompletion(Sender: TObject);
var
  aSynEdit: TCustomSynEdit;
begin
  inherited;
  Screen.Cursor := crHourGlass;
  Completion.ItemList.BeginUpdate;
  try
    Completion.ItemList.Clear;
    aSynEdit := (Sender as TSynCompletion).TheForm.CurrentEditor as TCustomSynEdit;
    if (aSynEdit <> nil) then
    begin
      EnumerateKeywords(Ord(attKeyword), sLSLKeywords, Highlighter.IdentChars, @DoAddCompletion);
      EnumerateKeywords(Ord(attDataType), sLSLTypes, Highlighter.IdentChars, @DoAddCompletion);
      EnumerateKeywords(Ord(attDataValue), sLSLValues, Highlighter.IdentChars, @DoAddCompletion);
      EnumerateKeywords(Ord(attCommon), sLSLFunctions, Highlighter.IdentChars, @DoAddCompletion);
      EnumerateKeywords(Ord(attCommon), sOpenSIMFunctions, Highlighter.IdentChars, @DoAddCompletion);
    end;
  finally
    Completion.ItemList.EndUpdate;
    Screen.Cursor := crDefault;
  end;
end;

{ TLSLFile }

procedure TLSLFile.NewContent;
begin
  inherited NewContent;
end;

initialization
  with Engine do
  begin
    Tendencies.Add(TLSLTendency);
    Categories.Add(TLSLFileCategory.Create(TLSLTendency, 'LSL', 'SecondLife/OpenSIM Script'));
    Groups.Add(TLSLFile, 'LSL', 'OpenSIM Script', TLSLFileCategory, ['.lsl', '.ossl'], [fgkAssociated, fgkFolding, fgkBrowsable], [capLint]);
  end;
end.
