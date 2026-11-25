unit DocumentOutline;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils;
type
  TOutlineEntry=record Caption,Command,Target:string; BlockIndex,Offset,Group,Depth:Integer; end;
  TOutlineEntries=array of TOutlineEntry;
function DocumentOutlineEntries(Blocks:TStrings; const Preamble:string=''):TOutlineEntries;
implementation
uses TeXMacros, TeXStyles, ParagraphModel;
function DocumentOutlineEntries(Blocks:TStrings; const Preamble:string):TOutlineEntries;
var I,P,A,Q,N,Group,ContentStart:Integer; Source,Command,Caption,Target,Environment:string;
begin
  Result:=nil;
  for I:=-1 to Blocks.Count-1 do begin
    if I<0 then Source:=Preamble else Source:=Blocks[I]; P:=1; Environment:='';
    while P<=Length(Source) do begin
      if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
      if Source[P]<>'\' then begin Inc(P); Continue; end;
      Q:=P; if ReadTeXDefinition(Source,Q) then begin P:=Q; Continue; end;
      A:=P-1; Command:=ReadTeXCommand(Source,P); Group:=-1; Caption:=''; Target:='';
      if Command='begin' then begin
        Target:=ReadTeXGroup(Source,P,'{','}'); if (Target='figure') or (Target='table') then Environment:=Target;
        Continue;
      end;
      if Command='verb' then begin
        if Copy(Source,P,1)='*' then Inc(P);
        if P<=Length(Source) then begin Target:=Source[P]; Inc(P); while (P<=Length(Source)) and (Source[P]<>Target) do Inc(P); Inc(P); end;
        Continue;
      end;
      if Copy(Source,P,1)='*' then Inc(P);
      if HeadingIndex(Command)>=0 then Group:=0
      else if Command='caption' then Group:=1
      else if (Command='label') or (Command='tag') then Group:=2
      else if IsTeXInputCommand(Command) then Group:=3;
      if (Group<0) or ((I<0) and (Group<>3)) then Continue;
      SkipTeXSpace(Source,P); if Copy(Source,P,1)='[' then ReadTeXGroup(Source,P,'[',']');
      SkipTeXSpace(Source,P); ContentStart:=P;
      if Copy(Source,P,1)='{' then Target:=ReadTeXGroup(Source,P,'{','}')
      else if Command='input' then begin Q:=P; while (P<=Length(Source)) and not (Source[P] in [' ',#9,#10,#13,'%']) do Inc(P); Target:=Copy(Source,Q,P-Q); end;
      Caption:=Target; if Group=0 then Caption:=StringReplace(StringReplace(Target,'{','',[rfReplaceAll]),'}','',[rfReplaceAll]);
      if Group=1 then Caption:=Environment+': '+StringReplace(StringReplace(Target,'{','',[rfReplaceAll]),'}','',[rfReplaceAll]);
      if Group=2 then Caption:=Command+': '+Target;
      if Group=3 then Caption:=Command+': '+Target;
      N:=Length(Result); SetLength(Result,N+1);
      Result[N].Caption:=Caption; Result[N].Command:=Command; Result[N].Target:=Target;
      Result[N].BlockIndex:=I; Result[N].Offset:=A; Result[N].Group:=Group;
      Result[N].Depth:=HeadingIndex(Command);
      { Labels inside captions and heading arguments still belong in the index. }
      if (Group in [0,1]) and (Copy(Source,ContentStart,1)='{') then P:=ContentStart+1;
    end;
  end;
end;
end.
