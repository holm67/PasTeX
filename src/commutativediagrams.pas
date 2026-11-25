unit CommutativeDiagrams;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Types;
type
  TCommutativeFieldKind=(cfCell,cfLabel);
  TCommutativeField=record
    First,Last,Row,Col,Arrow,Side:Integer;
    Kind:TCommutativeFieldKind;
    Position:Double;
    MathMode:Boolean;
  end;
  TCommutativeFields=array of TCommutativeField;
  TCommutativeArrow=record
    Row,Col,TargetRow,TargetCol:Integer;
    First,Last:Integer;
    Curve,CurveHeight,Shift:Double;
    FixedCurve:Boolean;
    HasAngles:Boolean;
    OutAngle,InAngle,Looseness:Double;
    OutDirection,InDirection:string;
    Options:string;
  end;
  TCommutativeArrows=array of TCommutativeArrow;
  TCommutativeDiagram=class
  private
    FEmPoints:Double;
    procedure AddField(First,Last,Row,Col,Arrow,Side:Integer; Kind:TCommutativeFieldKind; MathMode:Boolean=True; Position:Double=0.5);
    procedure Cell(First,Last,Row,Col:Integer);
    function Arrow(var P:Integer; Row,Col:Integer):Boolean;
    procedure ArrowOptions(Index,First,Last:Integer);
  public
    Source,PackageName,Options,Unsupported:string;
    Fields:TCommutativeFields;
    Arrows:TCommutativeArrows;
    Rows,Columns:Integer;
    RowGap,ColumnGap:Double;
    function Load(const Code:string; EmPoints:Double=10):Boolean;
  end;
function IsCommutativeDiagram(const Source:string):Boolean;
implementation
uses Math, StrUtils, TeXMacros, TeXTables;
function IsCommutativeDiagram(const Source:string):Boolean;
var P:Integer; C,N:string;
begin
  P:=1; SkipTeXSpace(Source,P); C:=ReadTeXCommand(Source,P);
  Result:=(C='xymatrix') or (Copy(C,1,9)='xymatrix@');
  if C='begin' then begin N:=ReadTeXGroup(Source,P,'{','}'); Result:=(N='tikzcd') or (N='xy'); end;
end;
function StripGroup(const Value:string):string;
var P:Integer;
begin
  Result:=Trim(Value); P:=1;
  if Copy(Result,1,1)='{' then begin
    ReadTeXGroup(Result,P,'{','}');
    if P=Length(Result)+1 then Result:=Copy(Result,2,Length(Result)-2);
  end;
end;
function Number(const S:string; Default:Double):Double;
var F:TFormatSettings;
begin F:=DefaultFormatSettings; F.DecimalSeparator:='.'; Result:=StrToFloatDef(Trim(S),Default,F); end;
function Separation(const Value:string; Default,EmPoints:Double):Double;
var S,UnitName:string; P:Integer; Factor:Double;
begin
  S:=StripGroup(Value);
  if S='tiny' then Exit(Default*0.25);
  if S='small' then Exit(Default*0.5);
  if S='scriptsize' then Exit(Default*0.75);
  if S='normal' then Exit(Default);
  if S='large' then Exit(Default*1.5);
  if S='huge' then Exit(Default*2);
  P:=1; while (P<=Length(S)) and (S[P] in ['0'..'9','+','-','.']) do Inc(P);
  UnitName:=Trim(Copy(S,P,MaxInt)); Factor:=1;
  case UnitName of
    'pt':Factor:=1/EmPoints; 'pc':Factor:=12/EmPoints; 'ex':Factor:=0.43;
    'cm':Factor:=28.453/EmPoints; 'mm':Factor:=2.8453/EmPoints; 'in':Factor:=72.27/EmPoints;
    'em','':Factor:=1;
    else Exit(Default);
  end;
  Result:=Max(0.1,Number(Copy(S,1,P-1),Default/Factor)*Factor);
end;
procedure TCommutativeDiagram.AddField(First,Last,Row,Col,Arrow,Side:Integer; Kind:TCommutativeFieldKind; MathMode:Boolean; Position:Double);
var N:Integer;
begin
  while (First<Last) and (Source[First+1] in [' ',#9,#10,#13]) do Inc(First);
  while (Last>First) and (Source[Last] in [' ',#9,#10,#13]) do Dec(Last);
  N:=Length(Fields); SetLength(Fields,N+1);
  Fields[N].First:=First; Fields[N].Last:=Last; Fields[N].Row:=Row; Fields[N].Col:=Col;
  Fields[N].Arrow:=Arrow; Fields[N].Side:=Side; Fields[N].Kind:=Kind;
  Fields[N].MathMode:=MathMode; Fields[N].Position:=Position;
end;
procedure Direction(const S:string; var Row,Col:Integer);
var C:Char; P:Integer; Name:string;
begin
  Name:=StripGroup(S); P:=Pos('-',Name);
  if (P>1) and (Name[1] in ['0'..'9']) then begin
    Row:=StrToIntDef(Copy(Name,1,P-1),Row+1)-1;
    Col:=StrToIntDef(Copy(Name,P+1,MaxInt),Col+1)-1; Exit;
  end;
  for C in Name do case C of 'r':Inc(Col); 'l':Dec(Col); 'd':Inc(Row); 'u':Dec(Row); end;
end;
procedure TCommutativeDiagram.ArrowOptions(Index,First,Last:Integer);
var P,A,B,Depth,Q,Side,I,Equal:Integer; Quoted:Boolean; Item,Key,Value:string; PosValue:Double;
begin
  P:=First+1; A:=P; Depth:=0; Quoted:=False;
  while P<=Last+1 do begin
    if P<=Last then begin
      if Source[P]='\' then begin ReadTeXCommand(Source,P); Continue; end;
      if Source[P]='{' then Inc(Depth) else if Source[P]='}' then Dec(Depth)
      else if (Source[P]='"') and (Depth=0) then Quoted:=not Quoted;
    end;
    if (P>Last) or ((Source[P]=',') and (Depth=0) and not Quoted) then begin
      B:=P; Q:=A; while (Q<B) and (Source[Q] in [' ',#9,#10,#13]) do Inc(Q);
      Item:=Trim(Copy(Source,A,B-A)); Equal:=Pos('=',Item);
      Key:=Item; Value:=''; if Equal>0 then begin Key:=Trim(Copy(Item,1,Equal-1)); Value:=StripGroup(Copy(Item,Equal+1,MaxInt)); end;
      if Copy(Source,Q,1)='"' then begin
        Inc(Q); I:=Q; Depth:=0;
        while Q<B do begin
          if Source[Q]='\' then begin ReadTeXCommand(Source,Q); Continue; end;
          if Source[Q]='{' then Inc(Depth) else if Source[Q]='}' then Dec(Depth)
          else if (Source[Q]='"') and (Depth=0) then Break;
          Inc(Q);
        end;
        Side:=1; PosValue:=0.5;
        if Pos('''',Copy(Source,Q+1,B-Q-1))>0 then Side:=-1;
        if Pos('description',Item)>0 then Side:=0;
        if Pos('near start',Item)>0 then PosValue:=0.25 else if Pos('near end',Item)>0 then PosValue:=0.75;
        AddField(I-1,Q-1,Arrows[Index].Row,Arrows[Index].Col,Index,Side,cfLabel,True,PosValue);
      end else if Key='to' then Direction(Value,Arrows[Index].TargetRow,Arrows[Index].TargetCol)
      else if Key='from' then begin
        Arrows[Index].Row:=0; Arrows[Index].Col:=0; Direction(Value,Arrows[Index].Row,Arrows[Index].Col);
      end else if Key='bend left' then Arrows[Index].Curve:=Number(Value,30)
      else if Key='bend right' then Arrows[Index].Curve:=-Number(Value,30)
      else if Key='out' then begin Arrows[Index].OutAngle:=Number(Value,0); Arrows[Index].HasAngles:=True; end
      else if Key='in' then begin Arrows[Index].InAngle:=Number(Value,180); Arrows[Index].HasAngles:=True; end
      else if Key='looseness' then Arrows[Index].Looseness:=EnsureRange(Number(Value,1),0,100)
      else if Key='shift left' then Arrows[Index].Shift:=Number(Value,1)*0.22
      else if Key='shift right' then Arrows[Index].Shift:=-Number(Value,1)*0.22
      else if (Copy(Key,1,5)='loop ') then begin
        Arrows[Index].TargetRow:=Arrows[Index].Row; Arrows[Index].TargetCol:=Arrows[Index].Col;
        Arrows[Index].Curve:=180;
      end else if (Key<>'') and (StringReplace(StringReplace(StringReplace(StringReplace(Key,'r','',[rfReplaceAll]),'l','',[rfReplaceAll]),'u','',[rfReplaceAll]),'d','',[rfReplaceAll])='') then
        Direction(Key,Arrows[Index].TargetRow,Arrows[Index].TargetCol);
      A:=P+1;
    end;
    Inc(P);
  end;
end;
function TCommutativeDiagram.Arrow(var P:Integer; Row,Col:Integer):Boolean;
var Start,Q,I,A,B,Side:Integer; C,Style,Route:string;
begin
  Start:=P; Q:=P; C:=ReadTeXCommand(Source,Q);
  if Copy(C,1,3)='ar@' then begin C:='ar'; Q:=Start+3; end;
  Result:=(C='arrow') or (C='ar'); if not Result then Exit;
  I:=Length(Arrows); SetLength(Arrows,I+1);
  Arrows[I].Row:=Row; Arrows[I].Col:=Col; Arrows[I].TargetRow:=Row; Arrows[I].TargetCol:=Col;
  Arrows[I].InAngle:=180; Arrows[I].Looseness:=1;
  Arrows[I].First:=Start-1; P:=Q; SkipTeXSpace(Source,P);
  if PackageName='tikz-cd' then begin
    if Copy(Source,P,1)='[' then begin
      A:=P; ReadTeXGroup(Source,P,'[',']'); B:=P-1;
      if Copy(Source,B,1)=']' then Dec(B);
      Arrows[I].Options:=Copy(Source,A+1,B-A); ArrowOptions(I,A,B);
    end;
    Q:=P; SkipTeXSpace(Source,Q);
    if Copy(Source,Q,1)='{' then begin
      { The package retains its original \arrow{r}[options]{label} syntax. }
      P:=Q; Route:=ReadTeXGroup(Source,P,'{','}'); Direction(Route,Arrows[I].TargetRow,Arrows[I].TargetCol);
      repeat
        Q:=P; SkipTeXSpace(Source,Q); Style:='';
        if Copy(Source,Q,1)='[' then begin P:=Q; Style:=ReadTeXGroup(Source,P,'[',']'); Q:=P; SkipTeXSpace(Source,Q); end;
        if Copy(Source,Q,1)<>'{' then Break;
        P:=Q; A:=P; ReadTeXGroup(Source,P,'{','}'); B:=P-1; if Copy(Source,B,1)='}' then Dec(B);
        Side:=1; if Pos('swap',Style)>0 then Side:=-1; if Pos('description',Style)>0 then Side:=0;
        AddField(A,B,Row,Col,I,Side,cfLabel);
      until P>Length(Source);
    end;
  end else begin
    while (P<=Length(Source)) and (Source[P]='@') do begin
      Inc(P);
      if Copy(Source,P,1)='{' then begin
        Style:=ReadTeXGroup(Source,P,'{','}');
        case Style of
          '=>':Style:='Rightarrow'; '<=>':Style:='Leftrightarrow';
          '<->':Style:='leftrightarrow'; '-->':Style:='dashed'; '.>':Style:='dotted';
          '->>':Style:='two heads'; '|->':Style:='maps to';
          '>->':Style:='tail'; '^->':Style:='hook'; '^{->}':Style:='hook';
          '-':Style:='no head'; '=':Style:='equal';
        end;
        Arrows[I].Options:=Arrows[I].Options+','+Style;
      end else if Copy(Source,P,1)='/' then begin
        Inc(P); A:=P; while (P<=Length(Source)) and (Source[P]<>'/') do Inc(P);
        Style:=Copy(Source,A,P-A); if P<=Length(Source) then Inc(P);
        Arrows[I].FixedCurve:=True; Arrows[I].CurveHeight:=6/FEmPoints;
        if (Style<>'') and (Style[1] in ['^','_']) then begin
          if Length(Style)>1 then Arrows[I].CurveHeight:=Separation(Copy(Style,2,MaxInt),6/FEmPoints,FEmPoints);
          if Style[1]='_' then Arrows[I].CurveHeight:=-Arrows[I].CurveHeight;
        end else if Style<>'' then Arrows[I].CurveHeight:=Separation(Style,6/FEmPoints,FEmPoints);
      end else if Copy(Source,P,1)='<' then begin
        Inc(P); A:=P; while (P<=Length(Source)) and (Source[P]<>'>') do Inc(P);
        Style:=Trim(Copy(Source,A,P-A)); Arrows[I].Shift:=Separation(Style,0.2,FEmPoints);
        if Copy(Style,1,1)='-' then Arrows[I].Shift:=-Separation(Copy(Style,2,MaxInt),0.2,FEmPoints);
        if P<=Length(Source) then Inc(P);
      end else if Copy(Source,P,1)='(' then begin
        Style:=ReadTeXGroup(Source,P,'(',')'); A:=Pos(',',Style);
        if A>0 then begin Arrows[I].OutDirection:=Trim(Copy(Style,1,A-1)); Arrows[I].InDirection:=Trim(Copy(Style,A+1,MaxInt)); end;
      end else begin
        if Copy(Source,P,1)='2' then Arrows[I].Options:=Arrows[I].Options+',Rightarrow';
        if Copy(Source,P,1)='3' then Arrows[I].Options:=Arrows[I].Options+',triple';
        Inc(P);
      end;
      SkipTeXSpace(Source,P);
    end;
    if Copy(Source,P,1)='[' then begin Route:=ReadTeXGroup(Source,P,'[',']'); Direction(Route,Arrows[I].TargetRow,Arrows[I].TargetCol); end;
    while P<=Length(Source) do begin
      Q:=P; SkipTeXSpace(Source,Q); if (Q>Length(Source)) or not (Source[Q] in ['^','_','|']) then Break;
      Side:=1; if Source[Q]='_' then Side:=-1 else if Source[Q]='|' then Side:=0;
      P:=Q+1; SkipTeXSpace(Source,P);
      if Copy(Source,P,1)='{' then begin
        A:=P; ReadTeXGroup(Source,P,'{','}'); B:=P-1; if Copy(Source,B,1)='}' then Dec(B);
      end else begin
        A:=P-1; if Copy(Source,P,1)='\' then ReadTeXCommand(Source,P) else if P<=Length(Source) then Inc(P);
        B:=P-1;
      end;
      AddField(A,B,Row,Col,I,Side,cfLabel);
    end;
  end;
  Arrows[I].Last:=P-1;
end;
procedure TCommutativeDiagram.Cell(First,Last,Row,Col:Integer);
var P,A,Q,Count:Integer; Command:string;
begin
  P:=First+1; A:=P; Count:=0;
  { Cell style syntax belongs to the matrix, not to its math label. }
  SkipTeXSpace(Source,P);
  if Copy(Source,P,2)='|[' then begin
    Inc(P); ReadTeXGroup(Source,P,'[',']'); if Copy(Source,P,1)='|' then Inc(P); A:=P;
  end;
  while P<=Last do begin
    if Source[P]='%' then begin while (P<=Last) and not (Source[P] in [#10,#13]) do Inc(P); Continue; end;
    if Source[P]='{' then begin ReadTeXGroup(Source,P,'{','}'); Continue; end;
    if Source[P]='\' then begin
      Q:=P; Command:=ReadTeXCommand(Source,Q);
      if (Command='arrow') or (Command='ar') or (Copy(Command,1,3)='ar@') then begin
        if (Count=0) or (Trim(Copy(Source,A,P-A))<>'') then begin AddField(A-1,P-1,Row,Col,-1,0,cfCell); Inc(Count); end;
        Arrow(P,Row,Col); A:=P; Continue;
      end;
      P:=Q; Continue;
    end;
    Inc(P);
  end;
  if (Count=0) or (Trim(Copy(Source,A,Last-A+1))<>'') then AddField(A-1,Last,Row,Col,-1,0,cfCell);
end;
function TCommutativeDiagram.Load(const Code:string; EmPoints:Double):Boolean;
var P,A,B,Q,R,C,I,J,Start:Integer; Name,Command,Value,Key:string; F:TCommutativeField;
begin
  Result:=False; Source:=Code; Fields:=nil; Arrows:=nil; Options:=''; Unsupported:='';
  FEmPoints:=Max(1,EmPoints);
  Rows:=0; Columns:=0; RowGap:=1.8; ColumnGap:=2.4; PackageName:='';
  P:=1; SkipTeXSpace(Source,P); Command:=ReadTeXCommand(Source,P);
  if Command='begin' then begin
    Name:=ReadTeXGroup(Source,P,'{','}');
    if Name='tikzcd' then begin
      PackageName:='tikz-cd'; SkipTeXSpace(Source,P);
      if Copy(Source,P,1)='[' then Options:=ReadTeXGroup(Source,P,'[',']');
      A:=P; B:=EnvironmentEnd(Source,1,'tikzcd')-1;
      { Named separations mirror the package's default matrix settings. }
      I:=1;
      while I<=Length(Options) do begin
        J:=I; while (J<=Length(Options)) and (Options[J]<>',') do Inc(J);
        Value:=Trim(Copy(Options,I,J-I)); Q:=Pos('=',Value);
        if Q>0 then begin
          Key:=Trim(Copy(Value,1,Q-1)); Value:=Copy(Value,Q+1,MaxInt);
          if (Key='row sep') or (Key='sep') then RowGap:=Separation(Value,1.8,FEmPoints);
          if (Key='column sep') or (Key='sep') then ColumnGap:=Separation(Value,2.4,FEmPoints);
        end;
        I:=J+1;
      end;
    end else if Name='xy' then begin
      Q:=PosEx('\xymatrix',Source,P); if Q=0 then begin Unsupported:='Low-level XY drawing'; Exit; end;
      P:=Q; Command:=ReadTeXCommand(Source,P); PackageName:='xy';
    end else Exit;
  end else if (Command='xymatrix') or (Copy(Command,1,9)='xymatrix@') then PackageName:='xy' else Exit;
  if PackageName='xy' then begin
    Start:=P; while (P<=Length(Source)) and (Source[P]<>'{') do Inc(P);
    if P>Length(Source) then Exit;
    Options:=Copy(Command,9,MaxInt)+Copy(Source,Start,P-Start); RowGap:=24/FEmPoints; ColumnGap:=24/FEmPoints;
    I:=1;
    while I<=Length(Options) do begin
      if (Options[I]='@') or ((I=1) and (Options[I] in ['R','C'])) then begin
        if Options[I]='@' then Inc(I); if I>Length(Options) then Break;
        Key:=Options[I]; Inc(I); if Copy(Options,I,1)='=' then Inc(I); J:=I;
        while (I<=Length(Options)) and (Options[I]<>'@') do Inc(I); Value:=Copy(Options,J,I-J);
        if Key='R' then RowGap:=Separation(Value,24/FEmPoints,FEmPoints);
        if Key='C' then ColumnGap:=Separation(Value,24/FEmPoints,FEmPoints);
      end else Inc(I);
    end;
    A:=P+1; ReadTeXGroup(Source,P,'{','}'); B:=P-1; if Copy(Source,B,1)='}' then Dec(B);
  end;
  B:=Min(B,Length(Source)); P:=A; Start:=A; R:=0; C:=0;
  while P<=B do begin
    if Source[P]='%' then begin while (P<=B) and not (Source[P] in [#10,#13]) do Inc(P); Continue; end;
    if Source[P]='{' then begin ReadTeXGroup(Source,P,'{','}'); Continue; end;
    if Source[P]='[' then begin ReadTeXGroup(Source,P,'[',']'); Continue; end;
    if Source[P]='\' then begin
      Q:=P; Command:=ReadTeXCommand(Source,Q);
      if Command='begin' then begin
        Name:=ReadTeXGroup(Source,Q,'{','}'); P:=EnvironmentEnd(Source,P,Name);
        if Copy(Source,P,5)='\end{' then begin ReadTeXCommand(Source,P); ReadTeXGroup(Source,P,'{','}'); end;
        Continue;
      end;
      if Command='\' then begin
        Cell(Start-1,P-1,R,C); Columns:=Max(Columns,C+1); C:=0; Inc(R); P:=Q;
        if Copy(Source,P,1)='[' then ReadTeXGroup(Source,P,'[',']');
        Start:=P; Continue;
      end;
      P:=Q; Continue;
    end;
    if Source[P]='&' then begin Cell(Start-1,P-1,R,C); Inc(C); Inc(P); Start:=P; end else Inc(P);
  end;
  if (R=0) or (C>0) or (Trim(Copy(Source,Start,B-Start+1))<>'') then begin
    Cell(Start-1,B,R,C); Columns:=Max(Columns,C+1); Inc(R);
  end;
  Rows:=R;
  { Source order is the single authority for serialization and caret offsets. }
  for I:=1 to High(Fields) do begin
    F:=Fields[I]; J:=I-1;
    while (J>=0) and (Fields[J].First>F.First) do begin Fields[J+1]:=Fields[J]; Dec(J); end;
    Fields[J+1]:=F;
  end;
  Result:=(Rows>0) and (Columns>0) and (Rows<=256) and (Columns<=256);
end;
end.
