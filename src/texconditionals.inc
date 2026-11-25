{ SPDX-License-Identifier: GPL-3.0-or-later }
function EngineConditional(const Command,Engine:string; out Value:Boolean):Boolean;
var Name,EngineName:string;
begin
  Name:=LowerCase(Command); EngineName:=LowerCase(ChangeFileExt(ExtractFileName(Engine),''));
  if EngineName='' then EngineName:='pdflatex';
  Result:=True;
  case Name of
    'ifxetex':Value:=(EngineName='xelatex') or (EngineName='xetex');
    'ifluatex':Value:=(EngineName='lualatex') or (EngineName='luatex') or (EngineName='luahbtex');
    'ifpdftex':Value:=(EngineName='pdflatex') or (EngineName='pdftex');
    'iftutex':Value:=(EngineName='xelatex') or (EngineName='xetex') or
      (EngineName='lualatex') or (EngineName='luatex') or (EngineName='luahbtex');
    'ifpdf':Value:=(EngineName='pdflatex') or (EngineName='pdftex') or
      (EngineName='lualatex') or (EngineName='luatex') or (EngineName='luahbtex');
    'ifetex','iftrue':Value:=True;
    'iffalse':Value:=False;
    else begin Value:=False; Result:=False; end;
  end;
end;

function ReadEngineConditional(const Source,Engine:string; var Position:Integer; out First,After:Integer; Registry:TMacroRegistry):Boolean;
var P,Q,A,Depth,ElseAt,ElseAfter:Integer; Command,Name,Left,Right:string; Value,Invert,Dummy:Boolean; Info:TMacroInfo;
  function ExpandedToken(var At:Integer; Depth:Integer=0):string;
  var BeginAt,R:Integer; M:TMacroInfo; Body:string;
  begin
    BeginAt:=At;
    if At>Length(Source) then Exit('');
    if Source[At]<>'\' then begin Result:=Source[At]; Inc(At); Exit; end;
    Result:='\'+ReadTeXCommand(Source,At);
    if (Length(Result)>1) and (Result[2] in ['a'..'z','A'..'Z']) then SkipTeXSpace(Source,At);
    if (Registry=nil) or (Depth>16) then Exit;
    M:=Registry.Find(Copy(Result,2,MaxInt));
    if (M=nil) or M.Undefined or not M.Expandable or (M.ArgCount<>0) then Exit;
    Body:=Trim(M.Body); R:=0;
    while (Copy(Body,1,1)='\') and (R<16) do begin
      Inc(R); BeginAt:=1; Name:=ReadTeXCommand(Body,BeginAt);
      if BeginAt<=Length(Body) then Break;
      M:=Registry.Find(Name); if (M=nil) or M.Undefined or not M.Expandable or (M.ArgCount<>0) then Break;
      Body:=Trim(M.Body);
    end;
    { Only reduce a single token here. Multi-token expansion requires TeX's
      token input stack and must not consume the following visible text. }
    if (Length(Body)=1) or ((Copy(Body,1,1)='\') and (R<16)) then Result:=Body;
  end;
  procedure SkipControlSpace(var At:Integer);
  var Start,Lines:Integer;
  begin
    Start:=At; Lines:=0;
    while (At<=Length(Source)) and (Source[At] in [' ',#9,#10,#13]) do begin
      if Source[At]=#10 then Inc(Lines);
      Inc(At);
    end;
    if Lines>1 then At:=Start;
  end;
begin
  Result:=False; First:=Position; After:=Position; P:=Position;
  if (Copy(Source,P,3)<>'\if') and (Copy(Source,P,7)<>'\unless') then Exit;
  Command:=ReadTeXCommand(Source,P); Invert:=Command='unless';
  if Invert then begin SkipTeXSpace(Source,P); Command:=ReadTeXCommand(Source,P); end;
  if not EngineConditional(Command,Engine,Value) then begin
    case Command of
      'ifcsname':begin
        if Registry=nil then Exit;
        A:=P; Q:=Pos('\endcsname',Copy(Source,P,MaxInt)); if Q=0 then Exit;
        Name:=StringReplace(Trim(Copy(Source,A,Q-1)),' ','',[rfReplaceAll]);
        if Pos('\',Name)>0 then Exit;
        Inc(P,Q-1+Length('\endcsname')); Info:=Registry.Find(Name);
        Value:=(Info<>nil) and not Info.Undefined;
      end;
      'ifdefined':begin
        if Registry=nil then Exit;
        SkipTeXSpace(Source,P); Name:=ReadTeXCommand(Source,P); if Name='' then Exit;
        Info:=Registry.Find(Name); Value:=(Info<>nil) and not Info.Undefined;
      end;
      'if':begin
        SkipTeXSpace(Source,P); Left:=ExpandedToken(P); Right:=ExpandedToken(P);
        if (Left='') or (Right='') then Exit;
        if (Copy(Left,1,1)='\') or (Copy(Right,1,1)='\') then Exit;
        Value:=Left=Right;
      end;
      else Exit;
    end;
  end;
  if Invert then Value:=not Value;
  { Control words consume blanks, but blank lines still end a paragraph.
    Retain consumed bytes in the conditional node's prefix/suffix. }
  SkipControlSpace(P);
  First:=P; Depth:=1; ElseAt:=0; ElseAfter:=0;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P;
    if ReadTeXDefinition(Source,Q) or SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
    A:=P; Command:=ReadTeXCommand(Source,P);
    if Command='newif' then begin SkipTeXSpace(Source,P); ReadTeXCommand(Source,P); Continue; end;
    if EngineConditional(Command,Engine,Dummy) or
      (Command='if') or (Command='ifx') or (Command='ifcat') or (Command='ifnum') or
      (Command='ifdim') or (Command='ifodd') or (Command='ifcase') or (Command='ifdefined') or
      (Command='ifcsname') or (Command='ifhmode') or (Command='ifvmode') or (Command='ifmmode') or
      (Command='ifinner') or (Command='ifeof') or (Command='ifvoid') or (Command='ifhbox') or (Command='ifvbox') then Inc(Depth)
    else if Command='fi' then begin
      Dec(Depth);
      if Depth=0 then begin
        After:=A;
        if Value then begin if ElseAt>0 then After:=ElseAt; end
        else if ElseAt>0 then First:=ElseAfter else First:=After;
        SkipControlSpace(P);
        Position:=P; Exit(True);
      end;
    end else if (Command='else') and (Depth=1) and (ElseAt=0) then begin
      ElseAt:=A; ElseAfter:=P;
      SkipControlSpace(ElseAfter);
    end;
  end;
end;

function ActiveTeXSource(const Source,Engine:string):string;
  procedure Blank(First,After:Integer);
  var I:Integer;
  begin
    for I:=First to After-1 do if not (Result[I] in [#10,#13]) then Result[I]:=' ';
  end;
  procedure Visit(First,After,Depth:Integer);
  var P,Q,A,B:Integer;
  begin
    if Depth>128 then Exit;
    P:=First;
    while P<After do begin
      if Source[P]='%' then begin while (P<After) and (Source[P]<>#10) do Inc(P); Continue; end;
      if Source[P]<>'\' then begin Inc(P); Continue; end;
      Q:=P;
      if ReadTeXDefinition(Source,Q) or SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
      if ReadEngineConditional(Source,Engine,Q,A,B) and (Q<=After) then begin
        Blank(P,A); Blank(B,Q); Visit(A,B,Depth+1); P:=Q;
      end else ReadTeXCommand(Source,P);
    end;
  end;
begin
  Result:=Source;
  if (Pos('\if',Source)=0) and (Pos('\unless',Source)=0) then Exit;
  Visit(1,Length(Source)+1,0);
end;
