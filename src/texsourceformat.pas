unit TeXSourceFormat;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses TeXMacros;
type
  TSourceFormatEdit=record First,After:Integer; Text:string; end;
  TSourceFormatEdits=array of TSourceFormatEdit;
function FormatTeXFragment(const Source:string; Macros:TMacroRegistry; out Edits:TSourceFormatEdits):string;
function FormattedOffset(Offset:Integer; const Edits:TSourceFormatEdits):Integer;
implementation
uses SysUtils, Math;
function FormattedOffset(Offset:Integer; const Edits:TSourceFormatEdits):Integer;
var Edit:TSourceFormatEdit; Delta:Integer;
begin
  if Offset<0 then Exit(Offset);
  Delta:=0;
  for Edit in Edits do begin
    if Offset<Edit.First then Break;
    if Offset<=Edit.After then Exit(Edit.First+Delta+Length(Edit.Text));
    Inc(Delta,Length(Edit.Text)-(Edit.After-Edit.First));
  end;
  Result:=Offset+Delta;
end;
function FormatTeXFragment(const Source:string; Macros:TMacroRegistry; out Edits:TSourceFormatEdits):string;
type TEnvironment=record Name:string; Grid:Boolean; end;
var Stack:array of TEnvironment; Depth,P,Q,A,I,N,Count:Integer; Command,Environment,Indent,Ending:string;
  function Supported(const Name:string):Boolean;
  begin
    Result:=(Pos('|'+Name+'|','|itemize|enumerate|description|quote|quotation|center|flushleft|flushright|'+
      'equation|equation*|align|align*|aligned|alignedat|alignat|alignat*|gather|gather*|gathered|multline|multline*|'+
      'eqnarray|eqnarray*|array|tabular|tabular*|longtable|matrix|pmatrix|bmatrix|Bmatrix|vmatrix|Vmatrix|smallmatrix|cases|'+
      'figure|figure*|table|table*|minipage|')>0) or ((Macros<>nil) and Macros.IsTheorem(Name));
  end;
  procedure LineAt(Offset,Level:Integer; InsertBreak:Boolean);
  var Left,Right,J,Lines,Last:Integer; Text:string;
  begin
    Left:=Offset; Right:=Offset;
    while (Left>0) and (Source[Left] in [' ',#9,#10,#13]) do Dec(Left);
    while (Right<Length(Source)) and (Source[Right+1] in [' ',#9,#10,#13]) do Inc(Right);
    Lines:=0; for J:=Left+1 to Right do if Source[J]=#10 then Inc(Lines);
    if not InsertBreak and (Lines=0) then Exit;
    { Never add blank paragraphs or alter whitespace after a percent comment. }
    if Right=Length(Source) then Exit;
    Text:=''; for J:=1 to Max(1,Lines) do Text:=Text+Ending;
    Text:=Text+Indent+StringOfChar(' ',Level*2);
    if Left=0 then Text:=Indent+StringOfChar(' ',Level*2);
    Last:=Length(Edits)-1;
    if (Last>=0) and (Edits[Last].First=Left) and (Edits[Last].After=Right) then begin
      Edits[Last].Text:=Text; Exit;
    end;
    if (Last>=0) and (Left<Edits[Last].After) then Exit;
    if Copy(Source,Left+1,Right-Left)=Text then Exit;
    SetLength(Edits,Last+2); Edits[Last+1].First:=Left; Edits[Last+1].After:=Right; Edits[Last+1].Text:=Text;
  end;
begin
  Result:=Source; Edits:=nil; Depth:=0; Stack:=nil; P:=1; Ending:=LineEnding;
  if Pos(#13#10,Source)>0 then Ending:=#13#10;
  while (P<=Length(Source)) and (Source[P] in [' ',#9]) do Inc(P);
  Indent:=Copy(Source,1,P-1);
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Source[P]=#10 then begin
      if Depth>0 then LineAt(P,Depth,False); Inc(P); Continue;
    end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P;
    if SkipTeXLiteral(Source,Q) or ReadTeXDefinition(Source,Q) or ReadTeXEnvironmentDefinition(Source,Q) then begin P:=Q; Continue; end;
    A:=P-1; Command:=ReadTeXCommand(Source,P);
    if Command='begin' then begin
      Environment:=ReadTeXGroup(Source,P,'{','}');
      if Copy(Source,P-1,1)<>'}' then Continue;
      if not Supported(Environment) then begin
        { Unknown environments may change catcodes or treat whitespace as data. }
        Q:=Pos('\end{'+Environment+'}',Copy(Source,P,MaxInt));
        if Q>0 then Inc(P,Q-1+Length(Environment)+6) else P:=Length(Source)+1;
        Continue;
      end;
      Q:=P; ReadTeXGroup(Source,Q,'[',']'); if Copy(Source,Q-1,1)=']' then P:=Q;
      Count:=0;
      if (Environment='array') or (Environment='tabular') or (Environment='longtable') or
        (Environment='alignat') or (Environment='alignat*') or (Environment='alignedat') or (Environment='minipage') then Count:=1;
      if Environment='tabular*' then Count:=2;
      for I:=1 to Count do ReadTeXGroup(Source,P,'{','}');
      if (Count>0) and (Copy(Source,P-1,1)<>'}') then Continue;
      if Depth>0 then LineAt(A,Depth,True);
      SetLength(Stack,Depth+1); Stack[Depth].Name:=Environment;
      Stack[Depth].Grid:=Pos('|'+Environment+'|','|array|tabular|tabular*|longtable|align|align*|aligned|alignat|alignat*|'+
        'alignedat|gather|gather*|gathered|eqnarray|eqnarray*|matrix|pmatrix|bmatrix|Bmatrix|vmatrix|Vmatrix|smallmatrix|cases|')>0;
      Inc(Depth); LineAt(P-1,Depth,True);
    end else if Command='end' then begin
      Environment:=ReadTeXGroup(Source,P,'{','}');
      if (Depth>0) and (Stack[Depth-1].Name=Environment) then begin Dec(Depth); LineAt(A,Depth,True); end;
    end else if (Command='item') and (Depth>0) and
      ((Stack[Depth-1].Name='itemize') or (Stack[Depth-1].Name='enumerate') or (Stack[Depth-1].Name='description')) then
      LineAt(A,Depth,True)
    else if (Command='\') and (Depth>0) and Stack[Depth-1].Grid then begin
      if Copy(Source,P,1)='*' then Inc(P);
      Q:=P; ReadTeXGroup(Source,Q,'[',']'); if Copy(Source,Q-1,1)=']' then P:=Q;
      LineAt(P-1,Depth,True);
    end;
  end;
  { Apply once, in source order; neither preview text nor individual keystrokes
    allocate a reformatted document. Edits also map UTF-8 byte selections. }
  N:=Length(Source);
  for I:=0 to High(Edits) do Inc(N,Length(Edits[I].Text)-(Edits[I].After-Edits[I].First));
  if Length(Edits)=0 then Exit;
  SetLength(Result,N); P:=1; Q:=1;
  for I:=0 to High(Edits) do begin
    Count:=Edits[I].First-P+1; if Count>0 then Move(Source[P],Result[Q],Count);
    Inc(Q,Count); Count:=Length(Edits[I].Text);
    if Count>0 then Move(Edits[I].Text[1],Result[Q],Count);
    Inc(Q,Count); P:=Edits[I].After+1;
  end;
  if P<=Length(Source) then Move(Source[P],Result[Q],Length(Source)-P+1);
end;
end.
