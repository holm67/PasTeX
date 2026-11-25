unit SourceRanges;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Types;
type
  TSourceRange=record Start,Finish,Row,Col:Integer; end;
  TSourceRanges=array of TSourceRange;
  TSourceBoundary=record
    Offset:Integer;
    Caption,Path:string;
    Ending,Collapsed:Boolean;
  end;
  TSourceBoundaries=array of TSourceBoundary;
function SourceBytePoint(const Source:string; Offset:Integer):TPoint;
function ClipSourceRanges(const Ranges:TSourceRanges; Offset,Count:Integer):TSourceRanges;
function SourceCovered(const Source:string; const Ranges:TSourceRanges):Boolean;
{ Zero-based replacement [First,OldAfter) -> After[First,NewAfter).
  Keep UTF-8 characters whole, even when their leading bytes are equal. }
procedure SourceDifference(const Before,After:string; out First,OldAfter,NewAfter:Integer);
implementation
uses Math, SysUtils;
function ClipSourceRanges(const Ranges:TSourceRanges; Offset,Count:Integer):TSourceRanges;
var R:TSourceRange; N:Integer;
begin
  Result:=nil;
  for R in Ranges do if (R.Finish>Offset) and (R.Start<Offset+Count) then begin
    N:=Length(Result); SetLength(Result,N+1);
    Result[N].Start:=Max(0,R.Start-Offset); Result[N].Finish:=Min(Count,R.Finish-Offset);
  end;
end;
function SourceCovered(const Source:string; const Ranges:TSourceRanges):Boolean;
var A,B:Integer; R:TSourceRange;
begin
  Result:=False; A:=1; B:=Length(Source);
  while (A<=B) and (Source[A]<=' ') do Inc(A);
  while (B>=A) and (Source[B]<=' ') do Dec(B);
  for R in Ranges do if (R.Start<=A-1) and (R.Finish>=B) then Exit(True);
end;
procedure SourceDifference(const Before,After:string; out First,OldAfter,NewAfter:Integer);
const Chunk=4096;
var Limit:Integer;
begin
  OldAfter:=Length(Before); NewAfter:=Length(After); Limit:=Min(OldAfter,NewAfter); First:=0;
  if Pointer(Before)=Pointer(After) then begin First:=Limit; Exit; end;
  while (Limit-First>=Chunk) and CompareMem(@Before[First+1],@After[First+1],Chunk) do Inc(First,Chunk);
  while (First<Limit) and (Before[First+1]=After[First+1]) do Inc(First);
  while (Min(OldAfter,NewAfter)-First>=Chunk) and
    CompareMem(@Before[OldAfter-Chunk+1],@After[NewAfter-Chunk+1],Chunk) do begin Dec(OldAfter,Chunk); Dec(NewAfter,Chunk); end;
  while (OldAfter>First) and (NewAfter>First) and (Before[OldAfter]=After[NewAfter]) do begin Dec(OldAfter); Dec(NewAfter); end;
  while (First>0) and (First<Length(Before)) and ((Byte(Before[First+1]) and $C0)=$80) do Dec(First);
  while (OldAfter<Length(Before)) and (NewAfter<Length(After)) and
    ((Byte(Before[OldAfter+1]) and $C0)=$80) do begin Inc(OldAfter); Inc(NewAfter); end;
end;
function SourceBytePoint(const Source:string; Offset:Integer):TPoint;
var I:Integer;
begin
  Result:=Point(1,1); for I:=1 to EnsureRange(Offset,0,Length(Source)) do
    if Source[I]=#10 then begin Inc(Result.Y); Result.X:=1; end else if Source[I]<>#13 then Inc(Result.X);
end;
end.
