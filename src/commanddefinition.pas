unit CommandDefinition;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type
  TDefinitionArgument=record
    Kind:Char; DefaultValue,Spec:string;
    DefaultStart,DefaultEnd:Integer;
  end;
  TDefinitionArguments=array of TDefinitionArgument;
  TCommandDefinition=record
    Name,Parameters,Body,Command,Signature:string;
    Arguments:TDefinitionArguments;
    Starred:Boolean;
    NameStart,NameEnd,BodyStart,BodyEnd:Integer;
  end;
function ReadCommandDefinition(const Source:string; out Definition:TCommandDefinition):Boolean;
function DefinitionParameterCount(const Body:string):Integer;
function DefinitionArgumentsSource(const Source:string; const Arguments:TDefinitionArguments):string;
function DefinitionDeleteArgument(const Source:string; Index:Integer):string;
function DefinitionMoveArgument(const Source:string; Index,Destination:Integer):string;
function DefinitionEnsureArguments(const Source:string; Minimum:Integer):string;
function DefinitionChangeKind(const Source,Command:string):string;
implementation
uses SysUtils, TeXMacros;
function DefinitionParameterCount(const Body:string):Integer;
var P:Integer; Command:string; Delimiter:Char;
begin
  Result:=0; P:=1;
  while P<=Length(Body) do begin
    if Body[P]='%' then begin while (P<=Length(Body)) and not (Body[P] in [#10,#13]) do Inc(P); Continue; end;
    if Body[P]='\' then begin
      Command:=ReadTeXCommand(Body,P);
      if (Command='verb') or (Command='Verb') then begin
        if Copy(Body,P,1)='*' then Inc(P);
        if P<=Length(Body) then begin
          Delimiter:=Body[P]; Inc(P); while (P<=Length(Body)) and (Body[P]<>Delimiter) do Inc(P); Inc(P);
        end;
      end;
      Continue;
    end;
    if (Body[P]='#') and (P<Length(Body)) then begin
      if Body[P+1]='#' then begin Inc(P,2); Continue; end;
      if (Body[P+1] in ['1'..'9']) and (Ord(Body[P+1])-Ord('0')>Result) then Result:=Ord(Body[P+1])-Ord('0');
    end;
    Inc(P);
  end;
end;
function ReadCommandDefinition(const Source:string; out Definition:TCommandDefinition):Boolean;
var P,Q,A,I,Arguments,SignatureStart,DefaultStart:Integer; Command,Value,DefaultValue:string;
  procedure Add(Kind:Char; const DefaultValue,Spec:string);
  var N:Integer;
  begin
    N:=Length(Definition.Arguments); if N>=9 then Exit;
    SetLength(Definition.Arguments,N+1); Definition.Arguments[N].Kind:=Kind;
    Definition.Arguments[N].DefaultValue:=DefaultValue; Definition.Arguments[N].Spec:=Spec;
    Definition.Arguments[N].DefaultStart:=-1; Definition.Arguments[N].DefaultEnd:=-1;
    if Kind in ['o','O'] then Definition.Parameters:=Definition.Parameters+'[#'+IntToStr(N+1)+']'
    else Definition.Parameters:=Definition.Parameters+'{#'+IntToStr(N+1)+'}';
  end;
begin
  Result:=False; Definition:=Default(TCommandDefinition); P:=1;
  Command:=ReadTeXCommand(Source,P);
  if not ((Command='def') or (Command='gdef') or (Command='edef') or (Command='xdef') or
    (Command='newcommand') or (Command='renewcommand') or (Command='providecommand') or
    (Command='DeclareRobustCommand') or (Command='DeclareMathOperator') or
    (Command='NewDocumentCommand') or (Command='RenewDocumentCommand') or
    (Command='ProvideDocumentCommand') or (Command='DeclareDocumentCommand')) then Exit;
  Definition.Command:=Command; Definition.Starred:=Copy(Source,P,1)='*';
  if Definition.Starred then Inc(P); SkipTeXSpace(Source,P);
  if Copy(Source,P,1)='{' then Inc(P); SkipTeXSpace(Source,P);
  if Copy(Source,P,1)<>'\' then Exit;
  Inc(P); Definition.NameStart:=P-1; A:=P;
  while (P<=Length(Source)) and (Source[P] in ['a'..'z','A'..'Z','@']) do Inc(P);
  if P=A then Exit; Definition.NameEnd:=P-1; Definition.Name:=Copy(Source,A,P-A);
  if Copy(Source,P,1)='}' then Inc(P); SkipTeXSpace(Source,P);
  if (Command='def') or (Command='gdef') or (Command='edef') or (Command='xdef') then begin
    A:=P; while (P<=Length(Source)) and (Source[P]<>'{') do Inc(P);
    Value:=Copy(Source,A,P-A);
    Definition.Signature:=Value;
    for I:=1 to DefinitionParameterCount(Value) do Add('m','','m');
  end else begin
    Arguments:=0;
    if Copy(Source,P,1)='[' then begin
      Arguments:=StrToIntDef(ReadTeXGroup(Source,P,'[',']'),0); SkipTeXSpace(Source,P);
      if Arguments>9 then Arguments:=9;
      if Arguments<0 then Arguments:=0;
      if Copy(Source,P,1)='[' then begin
        A:=P; Value:=ReadTeXGroup(Source,P,'[',']'); Add('O',Value,'');
        Definition.Arguments[0].DefaultStart:=A; Definition.Arguments[0].DefaultEnd:=P-2;
      end;
    end else if Pos('DocumentCommand',Command)>0 then begin
      SignatureStart:=P; Value:=ReadTeXGroup(Source,P,'{','}');
      Definition.Signature:=Value;
      Q:=1; I:=0;
      while Q<=Length(Value) do begin
        SkipTeXSpace(Value,Q); if Q>Length(Value) then Break;
        if Length(Definition.Arguments)>=9 then Break;
        A:=Q;
        if Value[Q] in ['+','!'] then Inc(Q);
        if Q>Length(Value) then Break;
        Command:=Value[Q]; Inc(Q);
        if Command='O' then begin
          SkipTeXSpace(Value,Q); DefaultStart:=Q; DefaultValue:=ReadTeXGroup(Value,Q,'{','}');
          Add('O',DefaultValue,Copy(Value,A,Q-A));
          Definition.Arguments[High(Definition.Arguments)].DefaultStart:=SignatureStart+DefaultStart;
          Definition.Arguments[High(Definition.Arguments)].DefaultEnd:=SignatureStart+Q-2;
        end else if (Command='m') or (Command='o') then begin
          Add(Command[1],'',Copy(Value,A,Q-A));
          if Command='o' then begin
            Definition.Arguments[High(Definition.Arguments)].DefaultStart:=SignatureStart+Q-1;
            Definition.Arguments[High(Definition.Arguments)].DefaultEnd:=SignatureStart+Q-1;
          end;
        end
        else begin
          if Command[1] in ['d','D','r','R'] then Inc(Q,2)
          else if Command='t' then Inc(Q);
          if Command[1] in ['D','R','e','E'] then ReadTeXGroup(Value,Q,'{','}');
          if Command='E' then ReadTeXGroup(Value,Q,'{','}');
          Add(Command[1],'',Copy(Value,A,Q-A));
        end;
      end;
    end;
    while Length(Definition.Arguments)<Arguments do Add('m','','m');
  end;
  SkipTeXSpace(Source,P); if Copy(Source,P,1)<>'{' then Exit;
  Definition.BodyStart:=P; Definition.Body:=ReadTeXGroup(Source,P,'{','}'); Definition.BodyEnd:=P-2;
  Result:=(P<=Length(Source)+1) and (Copy(Source,P-1,1)='}');
end;
function DefinitionArgumentsSource(const Source:string; const Arguments:TDefinitionArguments):string;
var D:TCommandDefinition; I,Optional:Integer; Head,Spec,Command:string; AllRequired:Boolean;
begin
  Result:=Source; if not ReadCommandDefinition(Source,D) or (Length(Arguments)>9) then Exit;
  if D.Command='DeclareMathOperator' then Exit;
  AllRequired:=True; Optional:=-1;
  for I:=0 to High(Arguments) do if Arguments[I].Kind<>'m' then begin AllRequired:=False; if Optional=-1 then Optional:=I else Optional:=-2; end;
  Command:=D.Command;
  if AllRequired and ((Command='def') or (Command='gdef') or (Command='edef') or (Command='xdef')) then begin
    Head:=Copy(Source,1,D.NameEnd);
    if Length(Arguments)>=Length(D.Arguments) then begin
      Head:=Head+D.Signature;
      for I:=Length(D.Arguments)+1 to Length(Arguments) do Head:=Head+'#'+IntToStr(I);
    end else for I:=1 to Length(Arguments) do Head:=Head+'#'+IntToStr(I);
  end else if (Pos('DocumentCommand',Command)=0) and (AllRequired or ((Optional=0) and (Arguments[0].Kind='O'))) and
      not ((Command='def') or (Command='gdef') or (Command='edef') or (Command='xdef')) then begin
    Head:='\'+Command; if D.Starred then Head:=Head+'*'; Head:=Head+'{\'+D.Name+'}';
    if Length(Arguments)>0 then Head:=Head+'['+IntToStr(Length(Arguments))+']';
    if Optional=0 then Head:=Head+'['+Arguments[0].DefaultValue+']';
  end else begin
    if Pos('DocumentCommand',Command)=0 then begin
      if Command='renewcommand' then Command:='RenewDocumentCommand'
      else if (Command='providecommand') then Command:='ProvideDocumentCommand'
      else if (Command='def') or (Command='gdef') or (Command='edef') or (Command='xdef') then Command:='DeclareDocumentCommand'
      else Command:='NewDocumentCommand';
    end;
    Spec:='';
    for I:=0 to High(Arguments) do begin
      if I>0 then Spec:=Spec+' ';
      if Arguments[I].Kind='O' then Spec:=Spec+'O{'+Arguments[I].DefaultValue+'}'
      else if Arguments[I].Spec<>'' then Spec:=Spec+Arguments[I].Spec else Spec:=Spec+Arguments[I].Kind;
    end;
    Head:='\'+Command+'{\'+D.Name+'}{'+Spec+'}';
  end;
  Result:=Head+'{'+D.Body+Copy(Source,D.BodyEnd+1,MaxInt);
end;
function DefinitionChangeKind(const Source,Command:string):string;
var D:TCommandDefinition; Kind:string; I:Integer;
begin
  Result:=Source; if not ReadCommandDefinition(Source,D) then Exit;
  Kind:=Command;
  if Pos('DeclareMathOperator',Kind)=1 then begin
    if Length(D.Arguments)>0 then Exit;
    Exit('\'+Kind+'{\'+D.Name+'}{'+D.Body+'}');
  end;
  if Kind='def' then begin
    for I:=0 to High(D.Arguments) do if D.Arguments[I].Kind<>'m' then Exit;
    Result:='\def\'+D.Name;
    for I:=1 to Length(D.Arguments) do Result:=Result+'#'+IntToStr(I);
    Exit(Result+'{'+D.Body+'}');
  end;
  if (Kind='NewDocumentCommand') or (Kind='RenewDocumentCommand') or
     (Kind='ProvideDocumentCommand') or (Kind='DeclareDocumentCommand') then
    Exit(DefinitionArgumentsSource('\'+Kind+'{\'+D.Name+'}{}{'+D.Body+'}',D.Arguments));
  if (Kind<>'newcommand') and (Kind<>'renewcommand') and (Kind<>'providecommand') and (Kind<>'DeclareRobustCommand') then Exit;
  if D.Starred and (D.Command<>'DeclareMathOperator') then Kind:=Kind+'*';
  Result:=DefinitionArgumentsSource('\'+Kind+'{\'+D.Name+'}{'+D.Body+'}',D.Arguments);
end;
function DefinitionEnsureArguments(const Source:string; Minimum:Integer):string;
var D:TCommandDefinition; I,N:Integer;
begin
  Result:=Source; if not ReadCommandDefinition(Source,D) then Exit;
  N:=Length(D.Arguments); if Minimum<=N then Exit; if Minimum>9 then Minimum:=9;
  SetLength(D.Arguments,Minimum);
  for I:=N to Minimum-1 do begin D.Arguments[I].Kind:='m'; D.Arguments[I].Spec:='m'; end;
  Result:=DefinitionArgumentsSource(Source,D.Arguments);
end;
function RemapParameters(const Code:string; const Map:array of Integer):string;
var I,P,N:Integer; Command:string; Delimiter:Char;
begin
  Result:=''; P:=1;
  while P<=Length(Code) do begin
    if Code[P]='%' then begin
      I:=P; while (P<=Length(Code)) and not (Code[P] in [#10,#13]) do Inc(P);
      Result:=Result+Copy(Code,I,P-I); Continue;
    end;
    if Code[P]='\' then begin
      I:=P; Command:=ReadTeXCommand(Code,P);
      if (Command='verb') or (Command='Verb') then begin
        if Copy(Code,P,1)='*' then Inc(P);
        if P<=Length(Code) then begin
          Delimiter:=Code[P]; Inc(P); while (P<=Length(Code)) and (Code[P]<>Delimiter) do Inc(P); Inc(P);
        end;
      end;
      Result:=Result+Copy(Code,I,P-I); Continue;
    end;
    if Copy(Code,P,2)='##' then begin Result:=Result+'##'; Inc(P,2); Continue; end;
    if (Code[P]='#') and (P<Length(Code)) and (Code[P+1] in ['1'..'9']) then begin
      N:=Ord(Code[P+1])-Ord('0'); Inc(P,2);
      if N<Length(Map) then N:=Map[N]; if N>0 then Result:=Result+'#'+IntToStr(N);
    end else begin Result:=Result+Code[P]; Inc(P); end;
  end;
end;
function DefinitionDeleteArgument(const Source:string; Index:Integer):string;
var D:TCommandDefinition; I:Integer; Map:array[0..9] of Integer;
begin
  Result:=Source; if not ReadCommandDefinition(Source,D) or (Index<0) or (Index>=Length(D.Arguments)) then Exit;
  for I:=0 to 9 do begin Map[I]:=I; if I=Index+1 then Map[I]:=0 else if I>Index+1 then Dec(Map[I]); end;
  for I:=Index to High(D.Arguments)-1 do D.Arguments[I]:=D.Arguments[I+1]; SetLength(D.Arguments,Length(D.Arguments)-1);
  for I:=0 to High(D.Arguments) do D.Arguments[I].DefaultValue:=RemapParameters(D.Arguments[I].DefaultValue,Map);
  Result:=Copy(Source,1,D.BodyStart)+RemapParameters(D.Body,Map)+Copy(Source,D.BodyEnd+1,MaxInt);
  Result:=DefinitionArgumentsSource(Result,D.Arguments);
end;
function DefinitionMoveArgument(const Source:string; Index,Destination:Integer):string;
var D:TCommandDefinition; Saved:TDefinitionArgument; I:Integer; Map:array[0..9] of Integer;
begin
  Result:=Source;
  if not ReadCommandDefinition(Source,D) or (Index<0) or (Destination<0) or
     (Index>=Length(D.Arguments)) or (Destination>=Length(D.Arguments)) or (Index=Destination) then Exit;
  for I:=0 to 9 do Map[I]:=I;
  Map[Index+1]:=Destination+1; Saved:=D.Arguments[Index];
  if Index<Destination then for I:=Index to Destination-1 do begin D.Arguments[I]:=D.Arguments[I+1]; Map[I+2]:=I+1; end
  else for I:=Index downto Destination+1 do begin D.Arguments[I]:=D.Arguments[I-1]; Map[I]:=I+1; end;
  D.Arguments[Destination]:=Saved;
  for I:=0 to High(D.Arguments) do D.Arguments[I].DefaultValue:=RemapParameters(D.Arguments[I].DefaultValue,Map);
  Result:=Copy(Source,1,D.BodyStart)+RemapParameters(D.Body,Map)+Copy(Source,D.BodyEnd+1,MaxInt);
  Result:=DefinitionArgumentsSource(Result,D.Arguments);
end;
end.
