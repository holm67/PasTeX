unit NativePagination;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type
  TSourcePage=record Offset,Page:Integer; end;
  TSourcePages=array of TSourcePage;
  TPageLine=record
    Top,Bottom,SourceOffset,EditorSpace,Slide:Integer;
    ForceAfter:Boolean;
  end;
  TPageLines=array of TPageLine;
  TPageShifts=array of Integer;
function PaginateLines(const Lines:TPageLines; Height,FirstRoom,BodyHeight,Gap:Integer; out Shifts:TPageShifts):Integer;
function SamePageShifts(const A,B:TPageShifts):Boolean;
implementation
uses Math;
function SamePageShifts(const A,B:TPageShifts):Boolean;
var I:Integer;
begin
  if Length(A)<>Length(B) then Exit(False);
  for I:=0 to High(A) do if A[I]<>B[I] then Exit(False);
  Result:=True;
end;
function PaginateLines(const Lines:TPageLines; Height,FirstRoom,BodyHeight,Gap:Integer; out Shifts:TPageShifts):Integer;
var I,J,Shift,Boundary,PageStart,Start,NewTop:Integer; Forced:Boolean;
begin
  SetLength(Shifts,Length(Lines)); Shift:=0; Boundary:=FirstRoom; PageStart:=FirstRoom-BodyHeight; Start:=0; Forced:=False;
  if BodyHeight<=0 then Exit(Height);
  for I:=0 to High(Lines) do begin
    if Forced or ((Lines[I].Bottom+Shift>Boundary) and (Lines[I].Bottom-Lines[I].Top<=BodyHeight)) then begin
      J:=I;
      { Keep two prose lines together at a page boundary when possible.
        Tall, indivisible formula/figure boxes remain intact. }
      if not Forced and (I=High(Lines)) and (I-Start>=2) then Dec(J)
      else if not Forced and (I=1) and (Start=0) and (Lines[0].Top+Shift>PageStart) then J:=0;
      if not Forced and (J=1) and (Start=0) and (Lines[High(Lines)].Bottom-Lines[0].Top<=BodyHeight) then J:=0;
      NewTop:=Boundary+Gap;
      Shift:=NewTop-Lines[J].Top; PageStart:=NewTop; Boundary:=NewTop+BodyHeight; Start:=J;
      while J<I do begin Shifts[J]:=Shift; Inc(J); end;
    end;
    Shifts[I]:=Shift; Forced:=Lines[I].ForceAfter;
  end;
  Result:=Max(Height,Height+Shift);
end;
end.
