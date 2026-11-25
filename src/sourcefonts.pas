unit SourceFonts;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Graphics, SynEdit;
function DefaultSourceFont:string;
procedure SourceFontNames(Dest:TStrings);
function NormalizeSourceFont(const Name:string):string;
function ChineseSourceFont:string;
function SourceFontForText(const Preferred,Source:string):string;
function IsMonospaceSourceFont(const Name:string):Boolean;
procedure SmoothSourceFont(Font:TFont);
procedure UseNativeSourceFonts(Editor:TSynEdit);
procedure StyleSourceGutter(Editor:TSynEdit);
implementation
uses SysUtils, Forms, SynTextDrawer, UITheme, TeXUnicode, TeXFonts, NativeTeXGlyphs, Process;
var MonospaceFonts:TStringList;
type
  TSourceDrawerAccess=class(TheTextDrawer)
  public
    property FontStock;
  end;
  TSourceEditAccess=class(TSynEdit)
  public
    property TextDrawer;
    procedure UpdateFontGeometry;
  end;
  TSourceFontAdapter=class(TComponent)
  private
    FEditor:TSynEdit;
    FUpdating:Boolean;
    procedure DrawerChanged(Sender:TObject);
  public
    constructor CreateFor(Editor:TSynEdit);
    destructor Destroy; override;
  end;
procedure TSourceEditAccess.UpdateFontGeometry;
begin
  ScreenCaret.CharWidth:=CharWidth; ScreenCaret.CharHeight:=LineHeight;
  SizeOrFontChanged(True); Invalidate;
end;
constructor TSourceFontAdapter.CreateFor(Editor:TSynEdit);
begin
  inherited Create(Editor); FEditor:=Editor;
  TSourceEditAccess(Editor).TextDrawer.RegisterOnFontChangeHandler(@DrawerChanged);
  DrawerChanged(nil);
end;
destructor TSourceFontAdapter.Destroy;
begin
  { SynEdit frees its drawer before its owned components during destruction. }
  if not (csDestroying in FEditor.ComponentState) then
    TSourceEditAccess(FEditor).TextDrawer.UnRegisterOnFontChangeHandler(@DrawerChanged);
  inherited Destroy;
end;
procedure TSourceFontAdapter.DrawerChanged(Sender:TObject);
var NativeFont:TFont; Edit:TSourceEditAccess; I:Integer; FontName:string;
begin
  if FUpdating or (csDestroying in FEditor.ComponentState) then Exit;
  Edit:=TSourceEditAccess(FEditor);
  { SynEdit's private dummy/cache fonts are created at Screen.PixelsPerInch.
    TFont.Assign converts a monitor-scaled font back to that old resolution.
    Supply the actual pixel height to the drawer; keep the public font's point
    size/PPI intact for settings, monitor changes, and wrap calculations. }
  FUpdating:=True; NativeFont:=TFont.Create;
  try
    FontName:=NormalizeSourceFont(Edit.Font.Name);
    if Edit.Font.Name<>FontName then Edit.Font.Name:=FontName;
    Edit.Font.Pitch:=fpFixed;
    if (TSourceDrawerAccess(Edit.TextDrawer).FontStock.BaseFont.Height=Edit.Font.Height) and
       (TSourceDrawerAccess(Edit.TextDrawer).FontStock.BaseFont.Name=Edit.Font.Name) then Exit;
    NativeFont.Assign(Edit.Font); NativeFont.Height:=Edit.Font.Height; NativeFont.Style:=[];
    Edit.TextDrawer.BaseFont:=NativeFont;
    if Edit.Highlighter<>nil then
      for I:=0 to Edit.Highlighter.AttrCount-1 do Edit.TextDrawer.BaseStyle:=Edit.Highlighter.Attribute[I].Style;
    Edit.UpdateFontGeometry;
  finally NativeFont.Free; FUpdating:=False; end;
end;
procedure UseNativeSourceFonts(Editor:TSynEdit);
var I:Integer;
begin
  for I:=0 to Editor.ComponentCount-1 do if Editor.Components[I] is TSourceFontAdapter then Exit;
  SmoothSourceFont(Editor.Font); TSourceFontAdapter.CreateFor(Editor);
end;
procedure SmoothSourceFont(Font:TFont);
begin
  { SynEdit defaults to fqNonAntialiased. Let the native font engine draw
    outlines at the control's DPI, including TrueType and OpenType faces. }
  {$IFDEF WINDOWS}Font.Quality:=fqCleartypeNatural;{$ELSE}Font.Quality:=fqAntialiased;{$ENDIF}
end;
procedure StyleSourceGutter(Editor:TSynEdit);
var I:Integer; TextColor:TColor;
begin
  TextColor:=InkColor; if DarkMode then TextColor:=clWhite;
  Editor.Gutter.Color:=UIBackground;
  Editor.Gutter.CurrentLineColor.Background:=UIBackground;
  Editor.Gutter.CurrentLineColor.Foreground:=TextColor;
  for I:=0 to Editor.Gutter.Parts.Count-1 do begin
    Editor.Gutter.Parts[I].MarkupInfo.Background:=UIBackground;
    Editor.Gutter.Parts[I].MarkupInfo.Foreground:=TextColor;
  end;
end;
function DefaultSourceFont:string;
const Preferred:array[0..8] of string=('Hack','Source Code Pro','JetBrains Mono',
  'Cascadia Code','DejaVu Sans Mono','Liberation Mono','Consolas','Menlo','Courier New');
var Name:string; I:Integer;
begin
  Result:='Monospace'; SourceFontNames(nil);
  for Name in Preferred do begin I:=MonospaceFonts.IndexOf(Name); if I>=0 then Exit(MonospaceFonts[I]); end;
end;
function FixedLatinWidth(Canvas:TCanvas; const Name:string):Boolean;
const Samples:array[0..5] of string=('iiiiiiii','WWWWWWWW','00000000','@@@@@@@@','........','        ');
var Width,I:Integer;
begin
  Canvas.Font.Name:=Name; Canvas.Font.Size:=16; Canvas.Font.Pitch:=fpDefault; Canvas.Font.Style:=[];
  SmoothSourceFont(Canvas.Font); Width:=Canvas.TextWidth('MMMMMMMM'); Result:=Width>0;
  for I:=0 to High(Samples) do if Abs(Canvas.TextWidth(Samples[I])-Width)>1 then Exit(False);
end;
function IsMonospaceSourceFont(const Name:string):Boolean;
var Sample:TBitmap;
begin
  if SameText(Name,'Monospace') then Exit(True);
  SourceFontNames(nil); if MonospaceFonts.IndexOf(Name)>=0 then Exit(True);
  if (Screen=nil) or (Screen.Fonts.IndexOf(Name)<0) then Exit(False);
  Sample:=TBitmap.Create;
  try Sample.SetSize(1,1); Result:=FixedLatinWidth(Sample.Canvas,Name); finally Sample.Free; end;
end;
procedure SourceFontNames(Dest:TStrings);
var Sample:TBitmap; Name,Value:string; Fonts:TStringList; Runner:TProcess; Buffer:array[0..4095] of Byte; Count,I:Integer; Checked:TStringList;
  function Candidate(const Font:string):Boolean;
  var Lower:string;
  begin
    Lower:=LowerCase(Font); Result:=(Pos('mono',Lower)>0) or (Pos('code',Lower)>0) or
      (Pos('courier',Lower)>0) or (Pos('console',Lower)>0) or (Pos('fixed',Lower)>0) or
      (Pos('hack',Lower)>0) or (Pos('consolas',Lower)>0) or (Pos('menlo',Lower)>0) or (Pos('terminal',Lower)>0);
  end;
begin
  if MonospaceFonts=nil then begin
    MonospaceFonts:=TStringList.Create; MonospaceFonts.Sorted:=True;
    MonospaceFonts.CaseSensitive:=False; MonospaceFonts.Duplicates:=dupIgnore; MonospaceFonts.Add('Monospace');
    Fonts:=TStringList.Create; Checked:=TStringList.Create; Checked.Sorted:=True; Checked.Duplicates:=dupIgnore; Runner:=TProcess.Create(nil); Sample:=TBitmap.Create;
    try
      {$IFDEF UNIX}
      { Query font metadata; measuring every installed face loads entire CJK
        collections into native font caches before a document is opened. }
      try
        Runner.Executable:='fc-list'; Runner.Parameters.Add('--format=%{family[0]}|%{spacing}\n');
        Runner.Options:=[poUsePipes,poNoConsole]; Runner.Execute; Value:='';
        repeat Count:=Runner.Output.Read(Buffer,SizeOf(Buffer)); if Count>0 then SetLength(Value,Length(Value)+Count);
          if Count>0 then Move(Buffer[0],Value[Length(Value)-Count+1],Count);
        until Count=0;
        Runner.WaitOnExit; Fonts.Text:=Value;
        for I:=Fonts.Count-1 downto 0 do begin
          Count:=Pos('|',Fonts[I]); Value:=Copy(Fonts[I],Count+1,MaxInt);
          Name:=Copy(Fonts[I],1,Count-1);
          if (Count>0) and (Value='') and Candidate(Name) then begin
            if Checked.IndexOf(Name)<0 then begin
              Checked.Add(Name); if NativeMonospaceFont(OpenTypeFontFile(Name)) then MonospaceFonts.Add(Name);
            end;
          end;
          if (Count=0) or not ((Value='90') or (Value='100') or (Value='110')) then Fonts.Delete(I)
          else Fonts[I]:=Name;
        end;
      except Fonts.Clear; end;
      {$ENDIF}
      Sample.SetSize(1,1);
      if Fonts.Count>0 then MonospaceFonts.AddStrings(Fonts)
      else if Screen<>nil then for Name in Screen.Fonts do
        if Candidate(Name) and FixedLatinWidth(Sample.Canvas,Name) then MonospaceFonts.Add(Name);
    finally Checked.Free; Runner.Free; Fonts.Free; Sample.Free; end;
  end;
  if Dest<>nil then Dest.Assign(MonospaceFonts);
end;
function NormalizeSourceFont(const Name:string):string;
var I:Integer;
begin
  SourceFontNames(nil); I:=MonospaceFonts.IndexOf(Name);
  if I>=0 then Result:=MonospaceFonts[I] else Result:=DefaultSourceFont;
end;
function ChineseSourceFont:string;
const Preferred:array[0..8] of string=('Source Han Mono SC','Sarasa Mono SC','Sarasa Fixed SC',
  'Noto Sans Mono CJK SC','Source Han Mono TC','Sarasa Mono TC','Noto Sans Mono CJK TC','Source Han Mono','Sarasa Mono CL');
var Name:string; I:Integer;
begin
  Result:=''; SourceFontNames(nil);
  for Name in Preferred do begin I:=MonospaceFonts.IndexOf(Name); if I>=0 then Exit(MonospaceFonts[I]); end;
end;
function SourceFontForText(const Preferred,Source:string):string;
var P:Integer; FontName:string;
begin
  Result:=NormalizeSourceFont(Preferred); P:=1;
  while P<=Length(Source) do if CJKCodePoint(NextUTF8CodePoint(Source,P)) then begin
    FontName:=ChineseSourceFont; if FontName<>'' then Result:=FontName; Exit;
  end;
end;
finalization
  MonospaceFonts.Free;
end.
