unit PageExpansion;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses NativePagination, NativeFloats;
type
  TExpandedPageLines=array of TPageLines;
  TPageGap=record Position,Height,Page:Integer; end;
  TPageGaps=array of TPageGap;
{ Add editor-only space without changing the collapsed document's page breaks. }
procedure ExpandPageSources(var Blocks:TPageBlocks; const Expanded:TExpandedPageLines;
  Pitch,PageCount:Integer; out PageExtra:TPageShifts);
procedure InsertPageGaps(var Blocks:TPageBlocks; var Gaps:TPageGaps; var PageExtra:TPageShifts);
implementation
uses Math;
procedure InsertPageGaps(var Blocks:TPageBlocks; var Gaps:TPageGaps; var PageExtra:TPageShifts);
var Order,Totals:TPageShifts; Original:TPageGaps; I,J,K,Before,After,Y:Integer; Base:TPageBlock;
  function ShiftAt(Position:Integer):Integer;
  var L,R,M:Integer;
  begin
    L:=0; R:=Length(Order);
    while L<R do begin M:=(L+R) div 2; if Original[Order[M]].Position<=Position then L:=M+1 else R:=M; end;
    Result:=0; if L>0 then Result:=Totals[L-1];
  end;
begin
  if Length(Gaps)=0 then Exit;
  Original:=Copy(Gaps); SetLength(Order,Length(Gaps)); SetLength(Totals,Length(Gaps));
  for I:=0 to High(Order) do begin
    J:=I;
    while (J>0) and (Original[Order[J-1]].Position>Original[I].Position) do begin Order[J]:=Order[J-1]; Dec(J); end;
    Order[J]:=I;
  end;
  Before:=0;
  for I:=0 to High(Order) do begin
    K:=Order[I]; Inc(Gaps[K].Position,Before); Inc(Before,Gaps[K].Height); Totals[I]:=Before;
    if (Gaps[K].Page>=0) and (Gaps[K].Page<Length(PageExtra)) then Inc(PageExtra[Gaps[K].Page],Gaps[K].Height);
  end;
  for I:=0 to High(Blocks) do begin
    Base:=Blocks[I]; Before:=ShiftAt(Base.Top); After:=ShiftAt(Base.Top+Base.Height-1);
    Inc(Blocks[I].Top,Before); Inc(Blocks[I].Height,After-Before);
    Blocks[I].Shifts:=Copy(Base.Shifts);
    for J:=0 to High(Base.Lines) do begin
      Y:=Base.Top+Base.Lines[J].Top+Base.Shifts[J];
      Inc(Blocks[I].Shifts[J],ShiftAt(Y)-Before);
    end;
  end;
end;
procedure ExpandPageSources(var Blocks:TPageBlocks; const Expanded:TExpandedPageLines;
  Pitch,PageCount:Integer; out PageExtra:TPageShifts);
type TBand=record Position,Height,Total:Integer; end;
     TMapping=record Line,First,Bottom,Added,Before:TPageShifts; end;
var Bands:array of TBand; Maps:array of TMapping; Band:TBand;
    I,J,K,N,Y,Top,Height,Extra:Integer; Base:TPageBlock; SameLines,HasSpace:Boolean;
  function ShiftAt(Position:Integer):Integer;
  var L,R,K:Integer;
  begin
    L:=0; R:=Length(Bands);
    while L<R do begin K:=(L+R) div 2; if Bands[K].Position<=Position then L:=K+1 else R:=K; end;
    Result:=0; if L>0 then Result:=Bands[L-1].Total;
  end;
begin
  PageExtra:=nil; SetLength(PageExtra,PageCount); Bands:=nil; Maps:=nil;
  for I:=0 to Min(High(Blocks),High(Expanded)) do begin
    if (Length(Expanded[I])=0) or (Length(Blocks[I].Lines)=0) then Continue;
    Base:=Blocks[I]; SameLines:=Length(Expanded[I])=Length(Base.Lines); HasSpace:=False;
    if SameLines then for J:=0 to High(Base.Lines) do begin
      if (Expanded[I][J].Top<>Base.Lines[J].Top) or (Expanded[I][J].Bottom<>Base.Lines[J].Bottom) or
        (Expanded[I][J].SourceOffset<>Base.Lines[J].SourceOffset) then begin SameLines:=False; Break; end;
      HasSpace:=HasSpace or (Expanded[I][J].EditorSpace<>0) or (Base.Lines[J].EditorSpace<>0);
    end;
    { Most paragraphs reuse their collapsed lines. Only expanded source and
      annotations need a mapping; untouched blocks use the final shift pass. }
    if SameLines and not HasSpace then Continue;
    if Length(Maps)=0 then SetLength(Maps,Length(Blocks));
    SetLength(Maps[I].Line,Length(Expanded[I])); SetLength(Maps[I].Before,Length(Expanded[I]));
    SetLength(Maps[I].Added,Length(Base.Lines)); SetLength(Maps[I].First,Length(Base.Lines));
    SetLength(Maps[I].Bottom,Length(Base.Lines));
    for J:=0 to High(Base.Lines) do Maps[I].First[J]:=MaxInt;
    K:=0;
    for J:=0 to High(Expanded[I]) do begin
      if SameLines then K:=J
      else if Expanded[I][J].Slide>0 then begin
        while (K<High(Base.Lines)) and (Base.Lines[K].Slide<Expanded[I][J].Slide) do Inc(K);
      end else
        while (K<High(Base.Lines)) and (Base.Lines[K+1].SourceOffset<=Expanded[I][J].SourceOffset) do Inc(K);
      Maps[I].Line[J]:=K; Maps[I].First[K]:=Min(Maps[I].First[K],Expanded[I][J].Top);
      Maps[I].Bottom[K]:=Max(Maps[I].Bottom[K],Expanded[I][J].Bottom);
      Maps[I].Before[J]:=Maps[I].Added[K]; Inc(Maps[I].Added[K],Expanded[I][J].EditorSpace);
    end;
    for J:=0 to High(Base.Lines) do if Maps[I].First[J]<>MaxInt then begin
      Extra:=Max(0,Maps[I].Bottom[J]-Maps[I].First[J]-(Base.Lines[J].Bottom-Base.Lines[J].Top))+Maps[I].Added[J];
      if Extra=0 then Continue;
      Y:=Base.Top+Base.Lines[J].Bottom+Base.Shifts[J]; N:=Length(Bands); SetLength(Bands,N+1);
      Bands[N].Position:=Y; Bands[N].Height:=Extra;
      if PageCount>0 then Inc(PageExtra[EnsureRange((Y-1) div Max(1,Pitch),0,PageCount-1)],Extra);
    end;
  end;
  if Length(Bands)=0 then Exit;
  for I:=1 to High(Bands) do begin
    Band:=Bands[I]; J:=I;
    while (J>0) and (Bands[J-1].Position>Band.Position) do begin Bands[J]:=Bands[J-1]; Dec(J); end;
    Bands[J]:=Band;
  end;
  Extra:=0;
  for I:=0 to High(Bands) do begin Inc(Extra,Bands[I].Height); Bands[I].Total:=Extra; end;
  for I:=0 to High(Blocks) do begin
    Base:=Blocks[I]; Top:=Base.Top+ShiftAt(Base.Top); Height:=Base.Height+ShiftAt(Base.Top+Base.Height)-ShiftAt(Base.Top);
    Blocks[I].Top:=Top;
    if (I<=High(Expanded)) and (Length(Maps[I].Line)>0) then begin
      Blocks[I].Lines:=Expanded[I]; Blocks[I].Shifts:=nil; SetLength(Blocks[I].Shifts,Length(Expanded[I]));
      for J:=0 to High(Expanded[I]) do begin
        K:=Maps[I].Line[J]; Y:=Base.Top+Base.Lines[K].Top+Base.Shifts[K];
        Blocks[I].Shifts[J]:=Y+ShiftAt(Y)-Top-Maps[I].First[K]+Maps[I].Before[J];
      end;
    end else begin
      Blocks[I].Shifts:=Copy(Base.Shifts);
      for J:=0 to High(Base.Lines) do begin
        Y:=Base.Top+Base.Lines[J].Top+Base.Shifts[J];
        Inc(Blocks[I].Shifts[J],ShiftAt(Y)-ShiftAt(Base.Top));
      end;
    end;
    for J:=0 to High(Blocks[I].Lines) do Height:=Max(Height,Blocks[I].Lines[J].Bottom+Blocks[I].Shifts[J]+Blocks[I].Lines[J].EditorSpace+2);
    Blocks[I].Height:=Height;
  end;
end;
end.
