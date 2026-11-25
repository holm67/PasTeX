unit TeXPreambleCommands;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Contnrs;
type
  TPreambleCommand=class
    Start,Finish:Integer;
    Argument,Options:string;
    HasOptions:Boolean;
    function Source(const Command:string):string;
  end;
procedure PreambleCommands(const Source,Command:string; Dest:TObjectList);
function ReplacePreambleCommands(const Source,Command,Replacement:string):string;
implementation
uses SysUtils, TeXMacros;
function TPreambleCommand.Source(const Command:string):string;
begin
  Result:='\'+Command; if HasOptions then Result:=Result+'['+Options+']'; Result:=Result+'{'+Argument+'}';
end;
procedure CollectCommands(const Source,Command:string; Dest:TObjectList; out DocumentStart:Integer);
var P,A,Depth,Q:Integer; Name,Env,Ending:string; Item:TPreambleCommand; Delimiter:Char; Resource:Boolean;
begin
  Dest.Clear; P:=1; Depth:=0; DocumentStart:=Length(Source)+1;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Source[P]='{' then Inc(Depth) else if Source[P]='}' then Dec(Depth);
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    A:=P; if ReadTeXDefinition(Source,P) then Continue; Name:=ReadTeXCommand(Source,P);
    if Name='verb' then begin
      if Copy(Source,P,1)='*' then Inc(P);
      if P<=Length(Source) then begin
        Delimiter:=Source[P]; Inc(P); while (P<=Length(Source)) and not (Source[P] in [Delimiter,#10,#13]) do Inc(P);
        if Copy(Source,P,1)=Delimiter then Inc(P);
      end;
      Continue;
    end;
    if Name='begin' then begin
      Env:=ReadTeXGroup(Source,P,'{','}');
      if (Env='document') and (Depth=0) then begin DocumentStart:=A; Exit; end;
      if (Env='filecontents') or (Env='filecontents*') or (Env='verbatim') or (Env='verbatim*') then begin
        Ending:='\end{'+Env+'}'; Q:=Pos(Ending,Copy(Source,P,MaxInt));
        if Q=0 then P:=Length(Source)+1 else Inc(P,Q-1+Length(Ending));
      end;
      Continue;
    end;
    Q:=A; Resource:=SkipTeXBibResource(Source,Q);
    if (Depth<>0) or (Name<>Command) then begin if Resource then P:=Q; Continue; end;
    Item:=TPreambleCommand.Create; Item.Start:=A; SkipTeXSpace(Source,P);
    if Copy(Source,P,1)='[' then begin Item.HasOptions:=True; Item.Options:=ReadTeXGroup(Source,P,'[',']'); end;
    SkipTeXSpace(Source,P);
    if Copy(Source,P,1)<>'{' then begin Item.Free; Continue; end;
    Item.Argument:=ReadTeXGroup(Source,P,'{','}',Resource); Item.Finish:=P; Dest.Add(Item);
  end;
end;
procedure PreambleCommands(const Source,Command:string; Dest:TObjectList);
var DocumentStart:Integer;
begin CollectCommands(Source,Command,Dest,DocumentStart); end;
function ReplacePreambleCommands(const Source,Command,Replacement:string):string;
var Items:TObjectList; Item:TPreambleCommand; I,P,InsertAt:Integer; Code:string;
begin
  Items:=TObjectList.Create(True);
  try
    CollectCommands(Source,Command,Items,InsertAt); Result:=''; P:=1;
    if Items.Count=0 then begin
      Result:=Source; if Replacement='' then Exit;
      Code:=Replacement+LineEnding;
      if (InsertAt>1) and not (Source[InsertAt-1] in [#10,#13]) then Code:=LineEnding+Code;
      Insert(Code,Result,InsertAt); Exit;
    end;
    for I:=0 to Items.Count-1 do begin
      Item:=TPreambleCommand(Items[I]); Result:=Result+Copy(Source,P,Item.Start-P);
      if I=0 then Result:=Result+Replacement; P:=Item.Finish;
    end;
    Result:=Result+Copy(Source,P,MaxInt);
  finally Items.Free; end;
end;
end.
