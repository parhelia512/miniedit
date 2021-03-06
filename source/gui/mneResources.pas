unit mneResources;
{$mode objfpc}{$H+}
{**
 * Mini Edit
 *
 * @license    GPL 2 (http://www.gnu.org/licenses/gpl.html)
 * @author    Zaher Dirkey <zaher at parmaja dot com>
 *}

interface

uses
  SysUtils, Classes, ImgList, Controls, contnrs,
  LCLType,
  EditorEngine;

type
  TThemeStyle = (thsLight, thsDark);

  { TEditorResource }

  TEditorResource = class(TDataModule)
    FileImages: TImageList;
    BookmarkImages: TImageList;
    DebugImages: TImageList;
    PanelImages: TImageList;
    PanelImages1: TImageList;
    ToolbarImageList: TImageList;
    procedure DataModuleCreate(Sender: TObject);
    procedure DataModuleDestroy(Sender: TObject);
  private
  public
    Extensions: TEditorExtensions;
    function GetFileImageIndex(const FileName: string): integer;
    procedure Switch(Style: TThemeStyle);
  end;

const
  DEBUG_IMAGE_EXECUTE = 0;
  DEBUG_IMAGE_BREAKPOINT = 1;
  DEBUG_IMAGE_MARGINES = 0;

var
  EditorResource: TEditorResource = nil;

implementation

uses
  Graphics, GraphType;

function TEditorResource.GetFileImageIndex(const FileName: string): integer;
var
  Extension: TEditorExtension;
  s: string;
begin
  s := ExtractFileExt(FileName);
  if LeftStr(s, 1) = '.' then
    s := Copy(s, 2, MaxInt);

  Extension := Extensions.Find(s);
  if Extension <> nil then
    Result := Extension.ImageIndex
  else
    Result := 1;//any file
end;

procedure TEditorResource.Switch(Style: TThemeStyle);
var
  img: TRawImage;
  Bmp: TBitmap;
  p: PRGBAQuad;
  c, i: integer;
  new: Byte;
begin
  PanelImages.BeginUpdate;
  try
    if Style = thsLight then
      new := 0
    else
      new := $ff;
    Bmp := TBitmap.Create;
    PanelImages.GetFullBitmap(Bmp);
    Img := Bmp.RawImage;
    //PanelImages.GetFullRawImage(m, img);
    p := PRGBAQuad(img.Data);
    c := img.DataSize div SizeOf(p^);
    i := 0;
    while i < c do
    begin
      //stupid idea, but the mask will work with it
      //if p^.Green = 0 then //we should check if masked
      begin
        p^.Blue := new;
        p^.Green := new;
        p^.Red := new;
      end;
      inc(p);
      inc(i);
    end;
    PanelImages.Clear;
    PanelImages.AddMasked(Bmp, clFuchsia);
  finally
    PanelImages.EndUpdate;
  end;
end;


{$R *.lfm}

procedure TEditorResource.DataModuleCreate(Sender: TObject);
begin
  Extensions := TEditorExtensions.Create(true);
  Extensions.Add('php', 3);
  Extensions.Add('pas', 4);
  Extensions.Add('d', 5);
  Extensions.Add('py', 6);
  Extensions.Add('lua', 7);
  Extensions.Add('mne-project', 8);
  Extensions.Add('png', 9);
  Extensions.Add('jpg', 9);
end;

procedure TEditorResource.DataModuleDestroy(Sender: TObject);
begin
  FreeAndNil(Extensions);
end;

end.
