unit EditablePreamble;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type
  TPreambleField=record
    Start,Finish,DisplayStart,DisplayFinish:Integer;
  end;
  TEditablePreamble=class
  private
    FSource,FText:string;
    FWholeSource:Boolean;
    FFields:array of TPreambleField;
  public
    procedure Load(const Source:string; WholeSource:Boolean=False);
    function Apply(const Text:string):string; overload;
    function Apply(const Text:string; Caret:Integer; out Position:Integer):string; overload;
    function SourceOffset(DisplayOffset:Integer):Integer;
    function DisplayOffset(Position:Integer):Integer;
    property Text:string read FText;
    property Source:string read FSource;
    property WholeSource:Boolean read FWholeSource;
  end;
implementation
uses SourceRanges, SysUtils, Math, TeXMacros, TeXTables;
function InForm(const Command:string):Boolean;
begin
  Result:=(Command='documentclass') or (Command='usepackage') or (Command='RequirePackage') or
    (Command='title') or (Command='author') or (Command='date') or (Command='addbibresource') or
    (Command='hypersetup') or (Command='geometry') or (Command='sisetup') or
    (Command='pgfplotsset') or (Command='tikzset');
end;
procedure TEditablePreamble.Load(const Source:string; WholeSource:Boolean);
var P,A,Q,I,InsertAt:Integer; Command,Env,Ending:string; Configurable,Definition:Boolean;
begin
  FSource:=Source; FText:=''; FWholeSource:=WholeSource; SetLength(FFields,0); P:=1;
  if WholeSource then begin
    FText:=Source; SetLength(FFields,1);
    FFields[0].Start:=0; FFields[0].Finish:=Length(Source);
    FFields[0].DisplayStart:=0; FFields[0].DisplayFinish:=Length(Source); Exit;
  end;
  InsertAt:=Length(Source);
  while P<=Length(Source) do begin
    if Source[P] in [' ',#9,#10,#13] then begin Inc(P); Continue; end;
    A:=P; Definition:=False; Configurable:=False;
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); end
    else if Source[P]='\' then begin
      Definition:=ReadTeXDefinition(Source,P);
      if not Definition then begin
        Command:=ReadTeXCommand(Source,P); Configurable:=InForm(Command);
        if Command='begin' then begin
          Env:=ReadTeXGroup(Source,P,'{','}'); if Env='document' then begin InsertAt:=A-1; Break; end;
          Ending:='\end{'+Env+'}'; Q:=EnvironmentEnd(Source,A,Env);
          if Q<=Length(Source) then P:=Min(Length(Source)+1,Q+Length(Ending)) else P:=Length(Source)+1;
        end else begin
          if Copy(Source,P,1)='*' then Inc(P);
          repeat
            Q:=P; SkipTeXSpace(Source,Q);
            if Copy(Source,Q,1)='[' then begin ReadTeXGroup(Source,Q,'[',']'); P:=Q; end
            else if Copy(Source,Q,1)='{' then begin ReadTeXGroup(Source,Q,'{','}',Command='addbibresource'); P:=Q; end
            else Break;
          until P>Length(Source);
        end;
      end;
    end else begin
      while (P<=Length(Source)) and not (Source[P] in ['\','%',#10,#13]) do Inc(P);
    end;
    if P<=A then Inc(P);
    if Configurable then Continue;
    I:=Length(FFields); SetLength(FFields,I+1);
    if FText<>'' then FText:=FText+LineEnding;
    FFields[I].Start:=A-1; FFields[I].Finish:=P-1;
    FFields[I].DisplayStart:=Length(FText); FText:=FText+Copy(Source,A,P-A); FFields[I].DisplayFinish:=Length(FText);
  end;
  if Length(FFields)=0 then begin
    SetLength(FFields,1); FFields[0]:=Default(TPreambleField);
    FFields[0].Start:=InsertAt; FFields[0].Finish:=InsertAt;
  end;
end;
function TEditablePreamble.SourceOffset(DisplayOffset:Integer):Integer;
var I:Integer;
begin
  Result:=-1;
  for I:=0 to High(FFields) do begin
    if DisplayOffset<FFields[I].DisplayStart then Exit(FFields[I].Start);
    if DisplayOffset<=FFields[I].DisplayFinish then Exit(FFields[I].Start+DisplayOffset-FFields[I].DisplayStart);
  end;
  if Length(FFields)>0 then Result:=FFields[High(FFields)].Finish;
end;
function TEditablePreamble.DisplayOffset(Position:Integer):Integer;
var I:Integer;
begin
  Result:=-1;
  for I:=0 to High(FFields) do
    if (Position>=FFields[I].Start) and (Position<=FFields[I].Finish) then
      Exit(FFields[I].DisplayStart+Position-FFields[I].Start);
end;
function TEditablePreamble.Apply(const Text:string):string;
var Position:Integer;
begin Result:=Apply(Text,Length(Text),Position); end;
function TEditablePreamble.Apply(const Text:string; Caret:Integer; out Position:Integer):string;
var A,B,C,I,L,R,InsertAt,Start,FirstField,LastField:Integer; InReplacement:Boolean;
begin
  Caret:=EnsureRange(Caret,0,Length(Text)); Position:=SourceOffset(Caret);
  Result:=FSource; if Text=FText then Exit;
  SourceDifference(FText,Text,A,B,C);
  FirstField:=-1; LastField:=-1;
  for I:=0 to High(FFields) do
    if (B>FFields[I].DisplayStart) and (A<FFields[I].DisplayFinish) then begin
      if FirstField<0 then FirstField:=I; LastField:=I;
    end;
  if (FirstField>=0) and (LastField>FirstField) then begin
    { Keep the resulting command contiguous. A common closing brace belongs
      beside its replacement, before any intervening protected commands. }
    Inc(C,FFields[LastField].DisplayFinish-B);
    A:=FFields[FirstField].DisplayStart; B:=FFields[LastField].DisplayFinish;
  end;
  InsertAt:=SourceOffset(A); if InsertAt<0 then Exit;
  InReplacement:=(Caret>=A) and (Caret<=C);
  if not InReplacement then begin
    if Caret<A then Position:=SourceOffset(Caret) else Position:=SourceOffset(B+Caret-C);
  end;
  { Delete only editable spans. Class/package/metadata commands between them
    retain their exact source and their order. }
  for I:=High(FFields) downto 0 do begin
    L:=Max(A,FFields[I].DisplayStart); R:=Min(B,FFields[I].DisplayFinish);
    if R>L then begin
      Start:=FFields[I].Start+L-FFields[I].DisplayStart;
      if not InReplacement and (Position>Start) then Dec(Position,Min(Position,Start+R-L)-Start);
      Delete(Result,Start+1,R-L);
    end;
  end;
  Insert(Copy(Text,A+1,C-A),Result,InsertAt+1);
  if InReplacement then Position:=InsertAt+Caret-A
  else if Position>=InsertAt then Inc(Position,C-A);
end;
end.
