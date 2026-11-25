unit TeXEnvironmentSelection;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
procedure MatchEnvironmentSelection(const Source:string; var A,B:Integer);
implementation
uses SysUtils, Math, StrUtils, TeXMacros;
type TEnvironmentRange=record Name:string; Start,OpenEnd,CloseStart,Finish:Integer; end;
procedure MatchEnvironmentSelection(const Source:string; var A,B:Integer);
var Stack,Ranges:array of TEnvironmentRange; P,Q,L,N,I,OldA,OldB:Integer; Cmd,Name,Closing:string; Range:TEnvironmentRange;
begin
  if A>=B then Exit; P:=1; Stack:=nil; Ranges:=nil;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) then begin P:=Q; Continue; end;
    L:=P-1; Cmd:=ReadTeXCommand(Source,P);
    if Cmd='verb' then begin
      if Copy(Source,P,1)='*' then Inc(P);
      if P<=Length(Source) then begin Closing:=Source[P]; Inc(P); while (P<=Length(Source)) and (Source[P]<>Closing) do Inc(P); if P<=Length(Source) then Inc(P); end;
      Continue;
    end;
    if (Cmd<>'begin') and (Cmd<>'end') then Continue;
    Name:=ReadTeXGroup(Source,P,'{','}'); if Name='' then Continue;
    if Cmd='begin' then begin
      Range.Name:=Name; Range.Start:=L; Range.OpenEnd:=P-1;
      if IsTeXVerbatimEnvironment(Name) then begin
        Closing:='\end{'+Name+'}'; N:=PosEx(Closing,Source,P);
        if N>0 then begin
          Range.CloseStart:=N-1; Range.Finish:=N-1+Length(Closing);
          I:=Length(Ranges); SetLength(Ranges,I+1); Ranges[I]:=Range; P:=Range.Finish+1;
        end;
      end else begin N:=Length(Stack); SetLength(Stack,N+1); Stack[N]:=Range; end;
    end else if (Length(Stack)>0) and (Stack[High(Stack)].Name=Name) then begin
      Range:=Stack[High(Stack)]; SetLength(Stack,Length(Stack)-1);
      Range.CloseStart:=L; Range.Finish:=P-1; N:=Length(Ranges); SetLength(Ranges,N+1); Ranges[N]:=Range;
    end;
  end;
  repeat
    OldA:=A; OldB:=B;
    for I:=0 to High(Ranges) do begin
      Range:=Ranges[I];
      if ((A<Range.OpenEnd) and (B>Range.Start)) or ((A<Range.Finish) and (B>Range.CloseStart)) then begin
        A:=Min(A,Range.Start); B:=Max(B,Range.Finish);
      end;
    end;
  until (A=OldA) and (B=OldB);
end;
end.
