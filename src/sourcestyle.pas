unit SourceStyle;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Graphics, IniFiles, SynEdit;
type
  TSourceScheme=(ssAppearance,ssLight,ssDark,ssCustom);
  TSourceToken=(stText,stCommand,stComment,stMath,stBrace,stBracket);
  TSourcePalette=array[TSourceToken] of TColor;
  TSourceHighlight=record Enabled,CustomDark:Boolean; Scheme:TSourceScheme; Colors:TSourcePalette; end;
const SourceTokenNames:array[TSourceToken] of string=('Text','Commands','Comments','Math delimiters','Braces','Brackets');
var SourceHighlight:TSourceHighlight;
function SourcePalette(const Settings:TSourceHighlight):TSourcePalette;
function SourceBackgroundColor:TColor;
function SourceForegroundColor:TColor;
function SourceCommentStart(const Code:string; First:Integer):Integer;
procedure PaintSourceLine(Canvas:TCanvas; X,Y:Integer; const Code:string; InComment:Boolean=False);
procedure ApplySourceStyle(Editor:TSynEdit); overload;
function SourceEditorText(Editor:TSynEdit):string;
procedure ApplySourceStyle(Editor:TSynEdit; const Settings:TSourceHighlight); overload;
procedure ReadSourceHighlight(Ini:TCustomIniFile);
procedure WriteSourceHighlight(Ini:TCustomIniFile);
implementation
uses Math, Types, UITheme, SourceFonts, SynHighlighterTeX, EditorClipboard, SourceCompletion;
var CodeHighlighter:TSynTeXSyn;
function SourceBackgroundColor:TColor;
var Dark:Boolean;
begin
  Dark:=(SourceHighlight.Scheme=ssDark) or ((SourceHighlight.Scheme=ssAppearance) and DarkMode);
  if SourceHighlight.Scheme=ssCustom then Dark:=SourceHighlight.CustomDark;
  Result:=clWhite; if Dark then Result:=$242424;
end;
function SourceForegroundColor:TColor;
var Palette:TSourcePalette;
begin
  Palette:=SourcePalette(SourceHighlight); Result:=Palette[stText];
  if not SourceHighlight.Enabled then begin
    Result:=$202020; if SourceBackgroundColor<>clWhite then Result:=$EEEEEE;
  end;
end;
function SourceCommentStart(const Code:string; First:Integer):Integer;
begin
  Result:=Max(1,First);
  while (Result<=Length(Code)) and not (Code[Result] in [#10,#13]) do begin
    if Code[Result]='%' then Exit;
    if (Code[Result]='\') and (Result<Length(Code)) and not (Code[Result+1] in [#10,#13]) then Inc(Result);
    Inc(Result);
  end;
  Result:=0;
end;
procedure PaintSourceLine(Canvas:TCanvas; X,Y:Integer; const Code:string; InComment:Boolean);
var Palette:TSourcePalette; Color,Foreground:TColor; Token:string; Left:Integer;
begin
  Palette:=SourcePalette(SourceHighlight); Foreground:=SourceForegroundColor;
  Canvas.Brush.Style:=bsClear;
  if InComment then begin
    Canvas.Font.Color:=Foreground; if SourceHighlight.Enabled then Canvas.Font.Color:=Palette[stComment];
    Canvas.TextOut(X,Y,Code); Exit;
  end;
  if CodeHighlighter=nil then CodeHighlighter:=TSynTeXSyn.Create(nil);
  CodeHighlighter.ResetRange; CodeHighlighter.SetLine(Code,0);
  while not CodeHighlighter.GetEol do begin
    Token:=CodeHighlighter.GetToken; Color:=Foreground;
    if SourceHighlight.Enabled then begin
      if CodeHighlighter.GetTokenAttribute=CodeHighlighter.ControlSequenceAttri then Color:=Palette[stCommand]
      else if CodeHighlighter.GetTokenAttribute=CodeHighlighter.CommentAttri then Color:=Palette[stComment]
      else if CodeHighlighter.GetTokenAttribute=CodeHighlighter.MathmodeAttri then Color:=Palette[stMath]
      else if CodeHighlighter.GetTokenAttribute=CodeHighlighter.BraceAttri then Color:=Palette[stBrace]
      else if CodeHighlighter.GetTokenAttribute=CodeHighlighter.BracketAttri then Color:=Palette[stBracket];
    end;
    Left:=X+Canvas.TextWidth(Copy(Code,1,CodeHighlighter.GetTokenPos));
    Canvas.Font.Color:=Color; Canvas.TextOut(Left,Y,Token); CodeHighlighter.Next;
  end;
end;
function SourcePalette(const Settings:TSourceHighlight):TSourcePalette;
var Dark:Boolean;
begin
  if Settings.Scheme=ssCustom then Exit(Settings.Colors);
  Dark:=(Settings.Scheme=ssDark) or ((Settings.Scheme=ssAppearance) and DarkMode);
  if Dark then begin
    Result[stText]:=$EEEEEE; Result[stCommand]:=$F0C58A; Result[stComment]:=$91BF87;
    Result[stMath]:=$D4A6E3; Result[stBrace]:=$83D6DF; Result[stBracket]:=$B5ADFF;
  end else begin
    Result[stText]:=$202020; Result[stCommand]:=$9F441B; Result[stComment]:=$357532;
    Result[stMath]:=$8B2789; Result[stBrace]:=$00668A; Result[stBracket]:=$A04479;
  end;
end;
procedure ApplySourceStyle(Editor:TSynEdit; const Settings:TSourceHighlight);
var Palette:TSourcePalette; I:Integer; Highlighter:TSynTeXSyn; Background,Foreground,GutterText:TColor; Dark:Boolean;
begin
  if Editor=nil then Exit;
  ConfigureClipboard(Editor);
  EnsureSourceCompletion(Editor);
  Dark:=(Settings.Scheme=ssDark) or ((Settings.Scheme=ssAppearance) and DarkMode);
  if Settings.Scheme=ssCustom then Dark:=Settings.CustomDark;
  Background:=clWhite; if Dark then Background:=$242424;
  Palette:=SourcePalette(Settings); Foreground:=$202020; if Dark then Foreground:=$EEEEEE;
  if Settings.Enabled then Foreground:=Palette[stText];
  Editor.Color:=Background; Editor.Font.Color:=Foreground; SmoothSourceFont(Editor.Font);
  Editor.LineHighlightColor.Background:=clNone;
  Editor.SelectedColor.Background:=$915F36; Editor.SelectedColor.Foreground:=clWhite;
  GutterText:=Foreground; if Dark then GutterText:=clWhite;
  StyleSourceGutter(Editor); Editor.Gutter.Color:=Background;
  Editor.Gutter.CurrentLineColor.Background:=Background; Editor.Gutter.CurrentLineColor.Foreground:=GutterText;
  for I:=0 to Editor.Gutter.Parts.Count-1 do begin
    Editor.Gutter.Parts[I].MarkupInfo.Background:=Background;
    Editor.Gutter.Parts[I].MarkupInfo.Foreground:=GutterText;
  end;
  if Editor.Highlighter=nil then Editor.Highlighter:=TSynTeXSyn.Create(Editor);
  if Editor.Highlighter is TSynTeXSyn then begin
    Highlighter:=TSynTeXSyn(Editor.Highlighter);
    for I:=0 to Highlighter.AttrCount-1 do begin
      Highlighter.Attribute[I].Background:=clNone; Highlighter.Attribute[I].Foreground:=Foreground;
      Highlighter.Attribute[I].Style:=[];
    end;
    if Settings.Enabled then begin
      Highlighter.ControlSequenceAttri.Foreground:=Palette[stCommand]; Highlighter.CommentAttri.Foreground:=Palette[stComment];
      Highlighter.MathmodeAttri.Foreground:=Palette[stMath]; Highlighter.BraceAttri.Foreground:=Palette[stBrace];
      Highlighter.BracketAttri.Foreground:=Palette[stBracket];
    end;
  end;
  Editor.Invalidate;
end;
procedure ApplySourceStyle(Editor:TSynEdit);
begin ApplySourceStyle(Editor,SourceHighlight); end;
function SourceEditorText(Editor:TSynEdit):string;
var Last:Integer;
begin
  Last:=Editor.Lines.Count-1; Result:='';
  if Last>=0 then Result:=Editor.TextBetweenPoints[Point(1,1),Point(Length(Editor.Lines[Last])+1,Last+1)];
end;
procedure ReadSourceHighlight(Ini:TCustomIniFile);
var Token:TSourceToken;
begin
  SourceHighlight.Enabled:=Ini.ReadBool('SourceHighlight','Enabled',True);
  SourceHighlight.CustomDark:=Ini.ReadBool('SourceHighlight','CustomDark',False);
  SourceHighlight.Scheme:=TSourceScheme(EnsureRange(Ini.ReadInteger('SourceHighlight','Scheme',0),0,3));
  for Token:=Low(TSourceToken) to High(TSourceToken) do SourceHighlight.Colors[Token]:=Ini.ReadInteger('SourceHighlight',SourceTokenNames[Token],SourceHighlight.Colors[Token]);
end;
procedure WriteSourceHighlight(Ini:TCustomIniFile);
var Token:TSourceToken;
begin
  Ini.WriteBool('SourceHighlight','CustomDark',SourceHighlight.CustomDark);
  Ini.WriteBool('SourceHighlight','Enabled',SourceHighlight.Enabled); Ini.WriteInteger('SourceHighlight','Scheme',Ord(SourceHighlight.Scheme));
  for Token:=Low(TSourceToken) to High(TSourceToken) do Ini.WriteInteger('SourceHighlight',SourceTokenNames[Token],SourceHighlight.Colors[Token]);
end;
initialization
  SourceHighlight.Enabled:=True; SourceHighlight.Scheme:=ssAppearance; SourceHighlight.Colors:=SourcePalette(SourceHighlight);
finalization
  CodeHighlighter.Free;
end.
