unit PlotColors;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Graphics;
type
  TPlotColorStop=record Position:Double; Color:TColor; end;
  TPlotColorMap=array of TPlotColorStop;
function LoadPlotColorMap(const Name,Definition,Context,Directory:string):TPlotColorMap;
function PlotMapColor(const Map:TPlotColorMap; Value:Double; ConstantColors:Boolean=False):TColor;
function NamedColor(const Name:string):TColor;
implementation
uses Classes, SysUtils, Math, StrUtils, TeXMacros, TeXPackageSources;
var Maps:TStringList;
function Number(const S:string; Default:Double=0):Double;
var F:TFormatSettings;
begin
  F:=DefaultFormatSettings; F.DecimalSeparator:='.';
  if not TryStrToFloat(Trim(S),Result,F) or IsNan(Result) or IsInfinite(Result) then Result:=Default;
end;
function NamedColor(const Name:string):TColor;
var S,A,B:string; P:Integer; Part,Other:TColor; N:Double;
begin
  S:=Trim(Name); P:=Pos('!',S);
  if (Length(S)=7) and (S[1]='#') then begin
    P:=StrToIntDef('$'+Copy(S,2,6),0); Exit(RGBToColor(P shr 16,(P shr 8) and 255,P and 255));
  end;
  if P>0 then begin
    A:=Copy(S,1,P-1); B:=Copy(S,P+1,MaxInt); P:=Pos('!',B); N:=Number(B,50);
    if P>0 then begin N:=Number(Copy(B,1,P-1),50); B:=Copy(B,P+1,MaxInt); end else B:='white';
    N:=EnsureRange(N/100,0.0,1.0); Part:=ColorToRGB(NamedColor(A)); Other:=ColorToRGB(NamedColor(B));
    Exit(RGBToColor(Round((Part and 255)*N+(Other and 255)*(1-N)),Round(((Part shr 8) and 255)*N+((Other shr 8) and 255)*(1-N)),
      Round(((Part shr 16) and 255)*N+((Other shr 16) and 255)*(1-N))));
  end;
  case S of
    'white':Result:=clWhite; 'red':Result:=clRed; 'green':Result:=clLime; 'blue':Result:=clBlue;
    'cyan':Result:=clAqua; 'magenta':Result:=clFuchsia; 'yellow':Result:=clYellow;
    'orange':Result:=$0080FF; 'gray':Result:=$808080; 'lightgray':Result:=$BFBFBF;
    'darkgray':Result:=$404040; 'lime':Result:=$00FFBF; 'olive':Result:=$008080;
    'pink':Result:=$CCBFFF; 'teal':Result:=$808000;
    'brown':Result:=$4080BF; 'violet':Result:=$800080; 'purple':Result:=$4000BF;
    else Result:=clBlack;
  end;
end;
procedure ScanMaps(const Source:string; Dest:TStrings);
var P,Q:Integer; Name,Body:string;
begin
  P:=1;
  repeat
    Q:=PosEx('colormap=',Source,P); if Q=0 then Break; P:=Q+9;
    Name:=ReadTeXGroup(Source,P,'{','}'); Body:=ReadTeXGroup(Source,P,'{','}');
    if (Name<>'') and (Length(Name)<80) and (Body<>'') then Dest.Values[Name]:=Body;
  until P>Length(Source);
end;
function ParseMap(const Body:string):TPlotColorMap;
var P,A,N,I,J:Integer; Model,Value,Position,UnitName:string; Cells:TStringList; RGB:array[0..3] of Double;
    At,Scale,Origin,Extent:Double; Stop:TPlotColorStop;
begin
  Result:=nil; P:=1; At:=-1; Cells:=TStringList.Create;
  try
    while (P<=Length(Body)) and (Length(Result)<2048) do begin
      SkipTeXSpace(Body,P); if P>Length(Body) then Break;
      if Body[P]='[' then begin ReadTeXGroup(Body,P,'[',']'); Continue; end;
      if not (Body[P] in ['a'..'z','A'..'Z']) then begin Inc(P); Continue; end;
      A:=P; while (P<=Length(Body)) and (Body[P] in ['a'..'z','A'..'Z','0'..'9']) do Inc(P);
      Model:=Copy(Body,A,P-A); Position:=ReadTeXGroup(Body,P,'(',')'); SkipTeXSpace(Body,P);
      if Copy(Body,P,1)<>'=' then Continue; Inc(P); Value:=ReadTeXGroup(Body,P,'(',')'); if Value='' then Continue;
      if Position='' then At:=At+1 else begin
        I:=1; while (I<=Length(Position)) and (Position[I] in ['0'..'9','-','+','.']) do Inc(I);
        At:=Number(Copy(Position,1,I-1)); UnitName:=Trim(Copy(Position,I,MaxInt));
        if UnitName='mm' then At:=At/10 else if UnitName='pt' then At:=At*2.54/72.27;
      end;
      Stop.Position:=At;
      if Model='color' then Stop.Color:=NamedColor(Value)
      else begin
        Cells.StrictDelimiter:=True; Cells.Delimiter:=','; Cells.DelimitedText:=Value;
        for I:=0 to 3 do begin RGB[I]:=0; if I<Cells.Count then RGB[I]:=Number(Cells[I]); end;
        Scale:=255; if Model='rgb255' then Scale:=1;
        if Model='gray' then begin RGB[1]:=RGB[0]; RGB[2]:=RGB[0]; end
        else if Model='cmyk' then for I:=0 to 2 do RGB[I]:=1-Min(1.0,RGB[I]+RGB[3])
        else if (Model<>'rgb') and (Model<>'rgb255') then Continue;
        Stop.Color:=RGBToColor(EnsureRange(Round(RGB[0]*Scale),0,255),EnsureRange(Round(RGB[1]*Scale),0,255),EnsureRange(Round(RGB[2]*Scale),0,255));
      end;
      N:=Length(Result); SetLength(Result,N+1); Result[N]:=Stop;
    end;
    { Palette stops are tiny; insertion sort preserves explicit positions. }
    for I:=1 to High(Result) do begin Stop:=Result[I]; J:=I-1;
      while (J>=0) and (Result[J].Position>Stop.Position) do begin Result[J+1]:=Result[J]; Dec(J); end; Result[J+1]:=Stop;
    end;
    if Length(Result)>1 then begin
      Origin:=Result[0].Position; Extent:=Max(1e-12,Result[High(Result)].Position-Origin);
      for I:=0 to High(Result) do Result[I].Position:=(Result[I].Position-Origin)/Extent;
    end;
  finally Cells.Free; end;
end;
function LoadPlotColorMap(const Name,Definition,Context,Directory:string):TPlotColorMap;
var Local:TStringList; Body,MapName:string; P:Integer;
begin
  if Maps=nil then begin
    Maps:=TStringList.Create;
    ScanMaps(ReadTeXSource(ResolveTeXSource('pgfplots.code.tex',Directory)),Maps);
    ScanMaps(ReadTeXSource(ResolveTeXSource('tikzlibrarypgfplots.colormaps.code.tex',Directory)),Maps);
  end;
  Body:=Maps.Values[Name]; Local:=TStringList.Create;
  try
    ScanMaps(Context,Local); if Local.IndexOfName(Name)>=0 then Body:=Local.Values[Name];
    P:=1; MapName:=ReadTeXGroup(Definition,P,'{','}');
    if (MapName=Name) and (MapName<>'') then Body:=ReadTeXGroup(Definition,P,'{','}');
    Result:=ParseMap(Body);
  finally Local.Free; end;
end;
function PlotMapColor(const Map:TPlotColorMap; Value:Double; ConstantColors:Boolean):TColor;
var I:Integer; T:Double; A,B:TColor;
begin
  Result:=clBlack; if Length(Map)=0 then Exit; Value:=EnsureRange(Value,0.0,1.0); I:=0;
  while (I<High(Map)) and (Map[I+1].Position<=Value) do Inc(I);
  A:=ColorToRGB(Map[I].Color); Result:=A; if (I=High(Map)) or ConstantColors then Exit;
  B:=ColorToRGB(Map[I+1].Color); T:=(Value-Map[I].Position)/Max(1e-12,Map[I+1].Position-Map[I].Position);
  Result:=RGBToColor(Round((A and 255)*(1-T)+(B and 255)*T),Round(((A shr 8) and 255)*(1-T)+((B shr 8) and 255)*T),
    Round(((A shr 16) and 255)*(1-T)+((B shr 16) and 255)*T));
end;
finalization
  Maps.Free;
end.
