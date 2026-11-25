unit SourceSelectionMarkup;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Types, Graphics, SynEdit, SynEditMarkup, SynEditTypes, SynEditMiscClasses, SourceRanges;
type
  TSourceSelectionMarkup=class(TSynEditMarkup)
  private
    FSpans:array of record First,Last:TPoint; end;
  public
    procedure SetRanges(const Source:string; const Ranges:TSourceRanges);
    function GetMarkupAttributeAtRowCol(const Row:Integer; const Col:TLazSynDisplayTokenBound;
      const Rtl:TLazSynDisplayRtlInfo):TSynSelectedColor; override;
    procedure GetNextMarkupColAfterRowCol(const Row:Integer; const Col:TLazSynDisplayTokenBound;
      const Rtl:TLazSynDisplayRtlInfo; out NextPhys,NextLog:Integer); override;
  end;
implementation
uses Math;
procedure TSourceSelectionMarkup.SetRanges(const Source:string; const Ranges:TSourceRanges);
var I,Position:Integer; PointNow:TPoint;
  function PositionAt(Offset:Integer):TPoint;
  begin
    Offset:=EnsureRange(Offset,0,Length(Source));
    if Offset<Position then begin Position:=0; PointNow:=Point(1,1); end;
    while Position<Offset do begin
      Inc(Position);
      if Source[Position]=#10 then begin Inc(PointNow.Y); PointNow.X:=1; end
      else if Source[Position]<>#13 then Inc(PointNow.X);
    end;
    Result:=PointNow;
  end;
begin
  if (Length(Ranges)=0) and (Length(FSpans)=0) then Exit;
  SetLength(FSpans,Length(Ranges));
  Position:=0; PointNow:=Point(1,1);
  for I:=0 to High(Ranges) do begin FSpans[I].First:=PositionAt(Ranges[I].Start); FSpans[I].Last:=PositionAt(Ranges[I].Finish); end;
  MarkupInfo.Foreground:=clHighlightText; MarkupInfo.Background:=clHighlight;
  { Invalidate the viewport without passing an artificial end line through
    SynEdit's wrapped-line map. }
  TSynEdit(SynEdit).Invalidate;
end;
function TSourceSelectionMarkup.GetMarkupAttributeAtRowCol(const Row:Integer;
  const Col:TLazSynDisplayTokenBound; const Rtl:TLazSynDisplayRtlInfo):TSynSelectedColor;
var I,L,R:Integer;
begin
  Result:=nil;
  for I:=0 to High(FSpans) do begin
    if (Row<FSpans[I].First.Y) or (Row>FSpans[I].Last.Y) then Continue;
    L:=1; R:=MaxInt; if Row=FSpans[I].First.Y then L:=FSpans[I].First.X; if Row=FSpans[I].Last.Y then R:=FSpans[I].Last.X;
    if (Col.Logical>=L) and (Col.Logical<R) then Exit(MarkupInfo);
  end;
end;
procedure TSourceSelectionMarkup.GetNextMarkupColAfterRowCol(const Row:Integer;
  const Col:TLazSynDisplayTokenBound; const Rtl:TLazSynDisplayRtlInfo; out NextPhys,NextLog:Integer);
var I,L,R:Integer;
  procedure Include(Value:Integer);
  begin if (Value>Col.Logical) and ((NextLog<0) or (Value<NextLog)) then NextLog:=Value; end;
begin
  NextPhys:=-1; NextLog:=-1;
  for I:=0 to High(FSpans) do begin
    if (Row<FSpans[I].First.Y) or (Row>FSpans[I].Last.Y) then Continue;
    L:=1; R:=MaxInt; if Row=FSpans[I].First.Y then L:=FSpans[I].First.X; if Row=FSpans[I].Last.Y then R:=FSpans[I].Last.X;
    Include(L); if R<MaxInt then Include(R);
  end;
end;
end.
