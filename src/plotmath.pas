unit PlotMath;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses FPExprPars;
procedure ConfigurePlotMath(Parser:TFPExpressionParser);
function PlotMathExpression(const Source:string; Degrees:Boolean=True):string;
implementation
uses Math;
procedure DegreeSin(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=Sin(DegToRad(ArgToFloat(A[0]))); end;
procedure DegreeCos(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=Cos(DegToRad(ArgToFloat(A[0]))); end;
procedure DegreeTan(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=Tan(DegToRad(ArgToFloat(A[0]))); end;
procedure ToDegrees(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=RadToDeg(ArgToFloat(A[0])); end;
procedure ToRadians(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=DegToRad(ArgToFloat(A[0])); end;
procedure Minimum(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=Min(ArgToFloat(A[0]),ArgToFloat(A[1])); end;
procedure Maximum(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=Max(ArgToFloat(A[0]),ArgToFloat(A[1])); end;
procedure PowerValue(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=Power(ArgToFloat(A[0]),ArgToFloat(A[1])); end;
procedure ASinDegrees(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=RadToDeg(ArcSin(ArgToFloat(A[0]))); end;
procedure ACosDegrees(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=RadToDeg(ArcCos(ArgToFloat(A[0]))); end;
procedure ATanDegrees(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=RadToDeg(ArcTan(ArgToFloat(A[0]))); end;
procedure ATan2Degrees(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=RadToDeg(ArcTan2(ArgToFloat(A[0]),ArgToFloat(A[1]))); end;
procedure FloorValue(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=Floor(ArgToFloat(A[0])); end;
procedure CeilValue(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=Ceil(ArgToFloat(A[0])); end;
procedure ModuloValue(var R:TFPExpressionResult; const A:TExprParameterArray);
begin R.ResFloat:=ArgToFloat(A[0])-ArgToFloat(A[1])*Trunc(ArgToFloat(A[0])/ArgToFloat(A[1])); end;
procedure ConfigurePlotMath(Parser:TFPExpressionParser);
begin
  Parser.BuiltIns:=[bcMath];
  Parser.Identifiers.AddFunction('sind','F','F',@DegreeSin);
  Parser.Identifiers.AddFunction('cosd','F','F',@DegreeCos);
  Parser.Identifiers.AddFunction('tand','F','F',@DegreeTan);
  Parser.Identifiers.AddFunction('deg','F','F',@ToDegrees);
  Parser.Identifiers.AddFunction('rad','F','F',@ToRadians);
  Parser.Identifiers.AddFunction('min','F','FF',@Minimum);
  Parser.Identifiers.AddFunction('max','F','FF',@Maximum);
  Parser.Identifiers.AddFunction('pow','F','FF',@PowerValue);
  Parser.Identifiers.AddFunction('asind','F','F',@ASinDegrees);
  Parser.Identifiers.AddFunction('acosd','F','F',@ACosDegrees);
  Parser.Identifiers.AddFunction('atand','F','F',@ATanDegrees);
  Parser.Identifiers.AddFunction('atan2d','F','FF',@ATan2Degrees);
  Parser.Identifiers.AddFunction('floor','F','F',@FloorValue);
  Parser.Identifiers.AddFunction('ceil','F','F',@CeilValue);
  Parser.Identifiers.AddFunction('mod','F','FF',@ModuloValue);
  Parser.Identifiers.AddFloatVariable('e',Exp(1));
end;
function PlotMathExpression(const Source:string; Degrees:Boolean):string;
var P,First:Integer; Token:string;
begin
  Result:=''; P:=1;
  while P<=Length(Source) do begin
    First:=P;
    if Source[P] in ['a'..'z','A'..'Z'] then begin
      while (P<=Length(Source)) and (Source[P] in ['a'..'z','A'..'Z','0'..'9']) do Inc(P);
      Token:=Copy(Source,First,P-First);
      if Degrees and ((Token='sin') or (Token='cos') or (Token='tan')) then Token:=Token+'d';
      if Degrees and ((Token='asin') or (Token='acos') or (Token='atan') or (Token='atan2')) then Token:=Token+'d';
      Result:=Result+Token;
    end else begin Result:=Result+Source[P]; Inc(P); end;
  end;
end;
end.
