unit PlotGeometry;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$modeswitch advancedrecords}
interface
type
  TPlotPoint=record X,Y,Z:Double; end;
  TPlotTicks=array of Double;
  TPlotGeometry=record
    Minimum,Maximum,Ratio:TPlotPoint;
    Width,Height,Azimuth,Elevation:Double;
    ThreeD:Boolean;
    Origin,XVector,YVector,ZVector:TPlotPoint;
    procedure Prepare;
    function Project(const Point:TPlotPoint):TPlotPoint;
    function Depth(const Point:TPlotPoint):Double;
  end;
function PlotTicks(Minimum,Maximum,Length:Double; Distance:Double=0; MinTicks:Integer=4; MaxSpace:Double=35):TPlotTicks;
function DataVisualizationTicks(Minimum,Maximum:Double; Distance:Double=0; About:Double=5; Outside:Boolean=False):TPlotTicks;
function PolarTicks(Minimum,Maximum,Length:Double; Distance:Double=0; MinTicks:Integer=4; MaxSpace:Double=35):TPlotTicks;
implementation
uses Math;
procedure TPlotGeometry.Prepare;
var W,H:Double;
begin
  Origin:=Default(TPlotPoint); XVector:=Default(TPlotPoint); YVector:=Default(TPlotPoint); ZVector:=Default(TPlotPoint);
  if not ThreeD then begin XVector.X:=Width; YVector.Y:=Height; Exit; end;
  { pgfplotssetaxesfromazel uses the negative elevation, then fits the
    entire projected plot box, including its z extent, to width/height. }
  XVector.X:=Cos(Azimuth)*Ratio.X; XVector.Y:=-Sin(Azimuth)*Sin(Elevation)*Ratio.X;
  YVector.X:=Sin(Azimuth)*Ratio.Y; YVector.Y:=Cos(Azimuth)*Sin(Elevation)*Ratio.Y;
  ZVector.Y:=Cos(Elevation)*Ratio.Z;
  W:=Max(1e-12,Abs(XVector.X)+Abs(YVector.X));
  H:=Max(1e-12,Abs(XVector.Y)+Abs(YVector.Y)+Abs(ZVector.Y));
  XVector.X:=XVector.X*Width/W; XVector.Y:=XVector.Y*Height/H;
  YVector.X:=YVector.X*Width/W; YVector.Y:=YVector.Y*Height/H; ZVector.Y:=ZVector.Y*Height/H;
  Origin.X:=-Min(0.0,XVector.X)-Min(0.0,YVector.X);
  Origin.Y:=-Min(0.0,XVector.Y)-Min(0.0,YVector.Y)-Min(0.0,ZVector.Y);
end;
function TPlotGeometry.Project(const Point:TPlotPoint):TPlotPoint;
var X,Y,Z:Double;
begin
  X:=(Point.X-Minimum.X)/Max(1e-12,Maximum.X-Minimum.X);
  Y:=(Point.Y-Minimum.Y)/Max(1e-12,Maximum.Y-Minimum.Y); Z:=0;
  if ThreeD then Z:=(Point.Z-Minimum.Z)/Max(1e-12,Maximum.Z-Minimum.Z);
  Result.X:=Origin.X+X*XVector.X+Y*YVector.X;
  Result.Y:=Origin.Y+X*XVector.Y+Y*YVector.Y+Z*ZVector.Y; Result.Z:=0;
end;
function TPlotGeometry.Depth(const Point:TPlotPoint):Double;
var X,Y,Z:Double;
begin
  X:=(Point.X-Minimum.X)/Max(1e-12,Maximum.X-Minimum.X)*Ratio.X;
  Y:=(Point.Y-Minimum.Y)/Max(1e-12,Maximum.Y-Minimum.Y)*Ratio.Y;
  Z:=(Point.Z-Minimum.Z)/Max(1e-12,Maximum.Z-Minimum.Z)*Ratio.Z;
  Result:=-Sin(Azimuth)*Cos(Elevation)*X+Cos(Azimuth)*Cos(Elevation)*Y-Sin(Elevation)*Z;
end;
function PlotTicks(Minimum,Maximum,Length:Double; Distance:Double; MinTicks:Integer; MaxSpace:Double):TPlotTicks;
var Step,Power,Mantissa,First:Double; I,Count,Desired,Attempt:Integer;
begin
  Result:=nil; if Maximum<=Minimum then Exit;
  Step:=Abs(Distance);
  Desired:=Max(Max(2,MinTicks),Trunc(Length/Max(1.0,MaxSpace))+1);
  for Attempt:=0 to 14 do begin
    if Distance=0 then begin
      Step:=(Maximum-Minimum)/(Desired-1); Power:=IntPower(10,Floor(Log10(Step))); Mantissa:=Step/Power;
      { pgfplotsticks normalizes to 1, 2 or 5, then retries a lone tick. }
      if Mantissa<1.5 then Step:=Power else if Mantissa<3.5 then Step:=2*Power
      else if Mantissa<7.5 then Step:=5*Power else Step:=10*Power;
    end;
    if Step<=0 then Exit;
    First:=Ceil(Minimum/Step-1e-8)*Step; Count:=EnsureRange(Floor((Maximum-First)/Step+1e-8)+1,0,200);
    if (Count>=2) or (Distance<>0) then Break;
    Inc(Desired);
  end;
  SetLength(Result,Count);
  for I:=0 to Count-1 do begin Result[I]:=First+I*Step; if Abs(Result[I])<Step*1e-8 then Result[I]:=0; end;
end;
function DataVisualizationTicks(Minimum,Maximum:Double; Distance:Double; About:Double; Outside:Boolean):TPlotTicks;
var Step,Power,Mantissa:Double;
begin
  Result:=nil; if Maximum<=Minimum then Exit;
  Step:=Abs(Distance);
  if Step=0 then begin
    Step:=(Maximum-Minimum)/Max(1.0,About); Power:=IntPower(10,Floor(Log10(Step))); Mantissa:=Step/Power;
    { TikZ's standard about strategy includes 2.5, independently of the
      physical axis length. PGFPlots uses a different tick algorithm. }
    if Mantissa<1.5 then Step:=Power else if Mantissa<2.3 then Step:=2*Power
    else if Mantissa<4 then Step:=2.5*Power else if Mantissa<7 then Step:=5*Power else Step:=10*Power;
  end;
  if Outside then begin Minimum:=Floor(Minimum/Step)*Step; Maximum:=Ceil(Maximum/Step)*Step; end;
  Result:=PlotTicks(Minimum,Maximum,1,Step);
end;
function PolarTicks(Minimum,Maximum,Length:Double; Distance:Double; MinTicks:Integer; MaxSpace:Double):TPlotTicks;
var Step,First:Double; Desired,Count,I:Integer;
begin
  Result:=nil; if Maximum<=Minimum then Exit;
  Step:=Abs(Distance);
  if Step=0 then begin
    Desired:=Max(Max(2,MinTicks),Trunc(Length/Max(1.0,MaxSpace))+1);
    Step:=(Maximum-Minimum)/(Desired-1);
    { PGFPlots polar normalizetickdist snaps angle steps to this set. }
    if Step>67 then Step:=90 else if Step>30 then Step:=45 else if Step>18 then Step:=30
    else if Step>10 then Step:=15 else if Step>6 then Step:=10 else Step:=5;
  end;
  First:=Ceil(Minimum/Step-1e-8)*Step; Count:=EnsureRange(Floor((Maximum-First)/Step+1e-8)+1,0,200);
  SetLength(Result,Count); for I:=0 to Count-1 do Result[I]:=First+I*Step;
end;
end.
