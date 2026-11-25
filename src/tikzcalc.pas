unit TikZCalc;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$modeswitch nestedprocvars}
interface
uses Classes, FPExprPars, PlotGeometry;
type
  TResolveTikZPoint=function(const Name:string; out Value:TPlotPoint):Boolean is nested;
  TTikZCalc=class
  private
    FParser:TFPExpressionParser;
    FVariables:TStringList;
    FDepth:Integer;
    function Pair(const Code:string; out Value:TPlotPoint):Boolean;
    function Sum(const Code:string; out Value:TPlotPoint):Boolean;
    function Substitute(const Code:string):string;
  public
    Resolve:TResolveTikZPoint;
    constructor Create;
    destructor Destroy; override;
    function Scalar(const Code:string; out Value:Double):Boolean;
    function Coordinate(const Code:string; var P:Integer; out Value:TPlotPoint):Boolean;
    function ReadLet(const Code:string; var P:Integer):Boolean;
    procedure ClearVariables;
  end;
implementation
uses SysUtils, Math, TeXMacros, PlotMath, TeXStyles;
function Separator(const Code,Token:string; Start:Integer=1):Integer;
var I,Braces,Brackets,Parens:Integer;
begin
  Result:=0; Braces:=0; Brackets:=0; Parens:=0;
  for I:=Start to Length(Code) do begin
    if (Braces=0) and (Brackets=0) and (Parens=0) and (Copy(Code,I,Length(Token))=Token) then Exit(I);
    case Code[I] of
      '{':Inc(Braces); '}':Dec(Braces); '[':Inc(Brackets); ']':Dec(Brackets);
      '(':Inc(Parens); ')':Dec(Parens);
    end;
  end;
end;
constructor TTikZCalc.Create;
begin
  inherited Create; FParser:=TFPExpressionParser.Create(nil); ConfigurePlotMath(FParser);
  FVariables:=TStringList.Create; FVariables.CaseSensitive:=True;
end;
destructor TTikZCalc.Destroy;
begin FVariables.Free; FParser.Free; inherited Destroy; end;
procedure TTikZCalc.ClearVariables;
begin FVariables.Clear; end;
function TTikZCalc.Substitute(const Code:string):string;
var P,A:Integer; Name:string;
begin
  Result:=''; P:=1;
  while P<=Length(Code) do begin
    A:=P;
    if (Code[P]='\') and (Copy(Code,P+1,1)<>'') then begin
      Name:=ReadTeXCommand(Code,P);
      if (Length(Name)=1) and (Name[1] in ['p','x','y','n']) then begin
        if Copy(Code,P,1)='{' then Name:=Name+ReadTeXGroup(Code,P,'{','}')
        else if P<=Length(Code) then begin Name:=Name+Code[P]; Inc(P); end;
        if FVariables.IndexOfName(Name)>=0 then begin Result:=Result+FVariables.Values[Name]; Continue; end;
      end;
    end else Inc(P);
    Result:=Result+Copy(Code,A,P-A);
  end;
end;
function TTikZCalc.Scalar(const Code:string; out Value:Double):Boolean;
var S,UnitToken:string; P:Integer; Factor:Double;
begin
  Result:=False; Value:=0; S:=Trim(Substitute(Code));
  if Copy(S,1,1)='{' then begin P:=1; S:=ReadTeXGroup(S,P,'{','}'); end;
  Factor:=1; P:=Length(S);
  while (P>0) and (S[P] in ['a'..'z']) do Dec(P);
  UnitToken:=Copy(S,P+1,MaxInt);
  if (UnitToken='pt') or (UnitToken='bp') or (UnitToken='mm') or (UnitToken='cm') or
     (UnitToken='in') or (UnitToken='pc') or (UnitToken='em') or (UnitToken='ex') then begin
    Factor:=TeXStyleDimension('1'+UnitToken,10)*2.54/72.27; S:=Trim(Copy(S,1,P));
  end;
  try
    FParser.Expression:=PlotMathExpression(S); Value:=FParser.AsFloat*Factor;
    Result:=not IsNan(Value) and not IsInfinite(Value) and (Abs(Value)<1e8);
  except Result:=False; end;
end;
function TTikZCalc.Coordinate(const Code:string; var P:Integer; out Value:TPlotPoint):Boolean;
var S:string; Start:Integer;
begin
  Result:=False; Value:=Default(TPlotPoint); SkipTeXSpace(Code,P); Start:=P;
  if (FDepth>=32) or (Copy(Code,P,1)<>'(') then Exit;
  S:=Trim(ReadTeXGroup(Code,P,'(',')')); if P=Start then Exit;
  Inc(FDepth);
  try
    if (Copy(S,1,1)='$') and (Copy(S,Length(S),1)='$') then Result:=Sum(Copy(S,2,Length(S)-2),Value)
    else Result:=Pair(Substitute(S),Value);
  finally Dec(FDepth); end;
end;
function TTikZCalc.Pair(const Code:string; out Value:TPlotPoint):Boolean;
var A,B,C:string; P,Q:Integer; N,R:Double; Left,Right:TPlotPoint;
begin
  Result:=False; Value:=Default(TPlotPoint); A:=Trim(Code);
  if FDepth>=32 then Exit; Inc(FDepth);
  try
  P:=Separator(A,'|-'); if P=0 then P:=Separator(A,'-|');
  if P>0 then begin
    B:=Copy(A,1,P-1); C:=Copy(A,P+2,MaxInt);
    if not Pair(B,Left) or not Pair(C,Right) then Exit;
    Value:=Left; if Copy(A,P,2)='|-' then Value.Y:=Right.Y else Value.X:=Right.X; Exit(True);
  end;
  P:=Separator(A,',');
  if P>0 then begin
    B:=Copy(A,P+1,MaxInt); Q:=Separator(B,',');
    if Q>0 then begin if not Scalar(Copy(B,Q+1,MaxInt),Value.Z) then Exit; B:=Copy(B,1,Q-1); end;
    Exit(Scalar(Copy(A,1,P-1),Value.X) and Scalar(B,Value.Y));
  end;
  P:=Separator(A,':');
  if P>0 then begin
    B:=Trim(Copy(A,1,P-1));
    case B of 'right':N:=0; 'up':N:=90; 'left':N:=180; 'down':N:=270;
      else if not Scalar(B,N) then Exit;
    end;
    if not Scalar(Copy(A,P+1,MaxInt),R) then Exit;
    Value.X:=Cos(DegToRad(N))*R; Value.Y:=Sin(DegToRad(N))*R; Exit(True);
  end;
  if Assigned(Resolve) then Result:=Resolve(A,Value);
  finally Dec(FDepth); end;
end;
function TTikZCalc.Sum(const Code:string; out Value:TPlotPoint):Boolean;
var P,A,Q,Sign,Terms:Integer; Factor,Amount,Angle,DX,DY,D,N:Double;
    Token:string; Point,Other,Projection:TPlotPoint; Project,Distance:Boolean;
begin
  Result:=False; Value:=Default(TPlotPoint); P:=1; Terms:=0;
  while P<=Length(Code) do begin
    SkipTeXSpace(Code,P); if P>Length(Code) then Break;
    if Terms>=256 then Exit; Sign:=1;
    if Code[P] in ['+','-'] then begin if Code[P]='-' then Sign:=-1; Inc(P); end
    else if Terms>0 then Exit;
    SkipTeXSpace(Code,P); Factor:=Sign;
    if Copy(Code,P,1)<>'(' then begin
      A:=P; Q:=Separator(Code,'*',P);
      while Q>0 do begin
        P:=Q+1; SkipTeXSpace(Code,P); if Copy(Code,P,1)='(' then Break;
        Q:=Separator(Code,'*',Q+1);
      end;
      if (Q=0) or not Scalar(Copy(Code,A,Q-A),N) then Exit;
      Factor:=Factor*N; P:=Q+1;
    end;
    if not Coordinate(Code,P,Point) then Exit;
    while True do begin
      SkipTeXSpace(Code,P); if Copy(Code,P,1)<>'!' then Break; Inc(P); SkipTeXSpace(Code,P);
      Project:=Copy(Code,P,1)='('; Distance:=False; Amount:=0;
      if Project then begin if not Coordinate(Code,P,Projection) then Exit; end
      else begin
        A:=P; Q:=Separator(Code,'!',P); if Q=0 then Exit;
        Token:=Trim(Copy(Code,A,Q-A)); if not Scalar(Token,Amount) then Exit;
        Distance:=(Length(Token)>0) and (Token[Length(Token)] in ['a'..'z']); P:=Q;
      end;
      SkipTeXSpace(Code,P); if Copy(Code,P,1)<>'!' then Exit; Inc(P); SkipTeXSpace(Code,P); Angle:=0;
      if Copy(Code,P,1)<>'(' then begin
        Q:=Separator(Code,':',P); if (Q=0) or not Scalar(Copy(Code,P,Q-P),Angle) then Exit; P:=Q+1;
      end;
      if not Coordinate(Code,P,Other) then Exit;
      DX:=Other.X-Point.X; DY:=Other.Y-Point.Y;
      N:=DX*Cos(DegToRad(Angle))-DY*Sin(DegToRad(Angle));
      DY:=DX*Sin(DegToRad(Angle))+DY*Cos(DegToRad(Angle)); DX:=N;
      D:=Sqr(DX)+Sqr(DY);
      if Project then begin
        if D<1e-20 then Amount:=0 else Amount:=((Projection.X-Point.X)*DX+(Projection.Y-Point.Y)*DY)/D;
      end else if Distance then begin if D<1e-20 then Amount:=0 else Amount:=Amount/Sqrt(D); end;
      Point.X:=Point.X+Amount*DX; Point.Y:=Point.Y+Amount*DY;
      Point.Z:=Point.Z+Amount*(Other.Z-Point.Z);
    end;
    Value.X:=Value.X+Factor*Point.X; Value.Y:=Value.Y+Factor*Point.Y; Value.Z:=Value.Z+Factor*Point.Z; Inc(Terms);
  end;
  Result:=(Terms>0) and (Abs(Value.X)<1e8) and (Abs(Value.Y)<1e8) and (Abs(Value.Z)<1e8);
end;
function TTikZCalc.ReadLet(const Code:string; var P:Integer):Boolean;
var Kind,Name,Token:string; A,N:Integer; Value:TPlotPoint; Number:Double; F:TFormatSettings;
begin
  Result:=False; F:=DefaultFormatSettings; F.DecimalSeparator:='.';
  if Copy(Code,P,3)<>'let' then Exit; Inc(P,3); ClearVariables;
  for N:=1 to 64 do begin
    SkipTeXSpace(Code,P); if Copy(Code,P,2)='in' then begin Inc(P,2); Exit(True); end;
    Kind:=ReadTeXCommand(Code,P); if (Kind<>'p') and (Kind<>'n') then Exit;
    if Copy(Code,P,1)='{' then Name:=ReadTeXGroup(Code,P,'{','}')
    else begin Name:=Copy(Code,P,1); if Name<>'' then Inc(P); end;
    SkipTeXSpace(Code,P); if (Name='') or (Copy(Code,P,1)<>'=') then Exit; Inc(P); SkipTeXSpace(Code,P);
    if Kind='p' then begin
      if not Coordinate(Code,P,Value) then Exit;
      FVariables.Values['x'+Name]:=FloatToStr(Value.X,F);
      FVariables.Values['y'+Name]:=FloatToStr(Value.Y,F);
      FVariables.Values['p'+Name]:=FloatToStr(Value.X,F)+','+FloatToStr(Value.Y,F);
    end else begin
      if Copy(Code,P,1)='{' then Token:=ReadTeXGroup(Code,P,'{','}')
      else begin A:=P; while (P<=Length(Code)) and not (Code[P] in [',',' ',#10,#13]) do Inc(P); Token:=Copy(Code,A,P-A); end;
      if not Scalar(Token,Number) then Exit; FVariables.Values['n'+Name]:=FloatToStr(Number,F);
    end;
    SkipTeXSpace(Code,P); if Copy(Code,P,1)=',' then Inc(P);
  end;
end;
end.
