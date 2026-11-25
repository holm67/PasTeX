unit DocumentInfo;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Forms, StdCtrls, TeXDocument;
type
  TDocumentStatistics=record Words,CJK,Characters,Lines:SizeInt; end;
  TDocumentInfoForm=class(TForm)
  public
    Details:TMemo;
    constructor Create(AOwner:TComponent); override;
    procedure Load(Document:TTeXDocument; const FileName,Engine:string; Modified:Boolean);
  end;
function DocumentStatistics(const Source,Body:string):TDocumentStatistics;
implementation
uses SysUtils, Math, Character, Controls, ExtCtrls, LazUTF8, TeXMacros, UITheme;
function DocumentStatistics(const Source,Body:string):TDocumentStatistics;
var P,Q,N:Integer; Code:Cardinal; Command,Environment,MathEnd:string; InWord:Boolean;
  procedure SkipArgument;
  begin
    SkipTeXSpace(Body,P);
    if Copy(Body,P,1)='[' then begin ReadTeXGroup(Body,P,'[',']'); SkipTeXSpace(Body,P); end;
    if Copy(Body,P,1)='{' then ReadTeXGroup(Body,P,'{','}');
  end;
  procedure CharacterAt;
  begin
    Code:=UTF8CodepointToUnicode(PChar(Body)+P-1,N); Inc(P,Max(1,N));
    if ((Code>=$3400) and (Code<=$9FFF)) or ((Code>=$F900) and (Code<=$FAFF)) or
      ((Code>=$20000) and (Code<=$323AF)) then begin Inc(Result.CJK); Inc(Result.Words); InWord:=False; end
    else if (Code<=$FFFF) and TCharacter.IsLetterOrDigit(WideChar(Code)) then begin
      if not InWord then Inc(Result.Words); InWord:=True;
    end else if not (Code in [39,45]) then InWord:=False;
  end;
begin
  Result:=Default(TDocumentStatistics); Result.Characters:=UTF8Length(Source);
  if Source<>'' then Result.Lines:=1;
  for P:=1 to Length(Source) do
    if (Source[P]=#10) or ((Source[P]=#13) and (Copy(Source,P+1,1)<>#10)) then Inc(Result.Lines);
  P:=1; InWord:=False; MathEnd:='';
  while P<=Length(Body) do begin
    if Body[P]='%' then begin while (P<=Length(Body)) and not (Body[P] in [#10,#13]) do Inc(P); Continue; end;
    if MathEnd<>'' then begin
      if Copy(Body,P,Length(MathEnd))=MathEnd then begin Inc(P,Length(MathEnd)); MathEnd:=''; end
      else if Body[P]='\' then ReadTeXCommand(Body,P) else Inc(P);
      Continue;
    end;
    if Body[P]='$' then begin
      MathEnd:='$'; if Copy(Body,P,2)='$$' then MathEnd:='$$'; Inc(P,Length(MathEnd)); InWord:=False; Continue;
    end;
    if Body[P]='\' then begin
      Q:=P; if ReadTeXDefinition(Body,Q) then begin P:=Q; Continue; end;
      Command:=ReadTeXCommand(Body,P);
      if (Command='(') or (Command='[') then begin
        if Command='(' then MathEnd:='\)' else MathEnd:='\]'; InWord:=False;
      end else if (Command='begin') or (Command='end') then begin
        SkipTeXSpace(Body,P); Environment:=ReadTeXGroup(Body,P,'{','}'); InWord:=False;
        if (Command='begin') and ((Environment='equation') or (Environment='equation*') or
          (Environment='align') or (Environment='align*') or (Environment='gather') or (Environment='gather*')) then
          MathEnd:='\end{'+Environment+'}';
      end else if (Command='label') or (Command='ref') or (Command='eqref') or (Command='autoref') or
        (Command='cite') or (Command='citep') or (Command='citet') or (Command='input') or
        (Command='include') or (Command='includegraphics') or (Command='url') then SkipArgument
      else if Command='href' then SkipArgument
      else if Command='verb' then begin
        if Copy(Body,P,1)='*' then Inc(P);
        if P<=Length(Body) then begin
          Command:=Body[P]; Inc(P);
          while (P<=Length(Body)) and (Body[P]<>Command) and not (Body[P] in [#10,#13]) do CharacterAt;
          if Copy(Body,P,1)=Command then Inc(P);
        end;
      end else if (Command='LaTeX') or (Command='TeX') then begin
        if not InWord then Inc(Result.Words); InWord:=True;
      end else if (Command='\') or (Command='newline') or (Command='par') or (Command='item') then InWord:=False;
      Continue;
    end;
    if Body[P] in ['{','}'] then Inc(P) else CharacterAt;
  end;
end;
constructor TDocumentInfoForm.Create(AOwner:TComponent);
var Bar:TPanel; CloseButton:TButton;
begin
  inherited CreateNew(AOwner); Caption:='Document information'; Position:=poOwnerFormCenter;
  ClientWidth:=620; ClientHeight:=410; Constraints.MinWidth:=380; Constraints.MinHeight:=280;
  Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alBottom; Bar.Height:=48; Bar.BevelOuter:=bvNone;
  CloseButton:=TButton.Create(Self); CloseButton.Parent:=Bar; CloseButton.Align:=alRight; CloseButton.BorderSpacing.Around:=8;
  CloseButton.Width:=96; CloseButton.Caption:='Close'; CloseButton.Cancel:=True; CloseButton.Default:=True; CloseButton.ModalResult:=mrOK;
  Details:=TMemo.Create(Self); Details.Parent:=Self; Details.Align:=alClient; Details.BorderSpacing.Around:=12;
  Details.ReadOnly:=True; Details.WordWrap:=True; Details.ScrollBars:=ssAutoVertical; ApplyTheme(Self);
end;
procedure TDocumentInfoForm.Load(Document:TTeXDocument; const FileName,Engine:string; Modified:Boolean);
var Source,Body,Path:string; Stats:TDocumentStatistics; Entry:TSearchRec;
begin
  Source:=Document.Source; Body:=Document.Blocks.Text; if Document.PreambleOnly then Body:='';
  Stats:=DocumentStatistics(Source,Body); Path:='Not saved'; if FileName<>'' then Path:=ExpandFileName(FileName);
  Details.Lines.BeginUpdate;
  try
    Details.Clear; Details.Lines.Add('Path: '+Path);
    if (FileName<>'') and (FindFirst(FileName,faAnyFile,Entry)=0) then begin
      try
        Details.Lines.Add('Saved file size: '+IntToStr(Entry.Size)+' bytes');
        Details.Lines.Add('Last saved: '+DateTimeToStr(FileDateToDateTime(Entry.Time)));
      finally FindClose(Entry); end;
    end;
    Details.Lines.Add('Current source size: '+IntToStr(Length(Source))+' bytes (UTF-8)');
    if Modified then Details.Lines.Add('Unsaved changes: Yes') else Details.Lines.Add('Unsaved changes: No');
    Details.Lines.Add('');
    Details.Lines.Add('Body words (estimate): '+IntToStr(Stats.Words));
    Details.Lines.Add('CJK characters in body: '+IntToStr(Stats.CJK));
    Details.Lines.Add('Source characters: '+IntToStr(Stats.Characters));
    Details.Lines.Add('Source lines: '+IntToStr(Stats.Lines));
    Details.Lines.Add('Paragraphs / blocks: '+IntToStr(Document.Blocks.Count));
    Details.Lines.Add('TeX engine: '+Engine);
    Details.Lines.Add('');
    Details.Lines.Add('Word estimates exclude comments, definitions and common math environments. Each CJK character counts as one word. Included files are counted separately.');
    if Document.PreambleOnly then Details.Lines.Add('This file contains preamble/source only.');
  finally Details.Lines.EndUpdate; end;
end;
end.
