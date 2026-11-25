unit TeXGlyphs;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Types, Graphics;
type TTeXGlyphMetric=record
  Kind:string;
  W,H,Above,Advance:Double; { units of one 10pt design em }
end;
var TeXGlyphMetrics:array of TTeXGlyphMetric;
function ChooseTeXGlyph(const Kind:string; Height:Double=0):Integer;
function IsNativeTeXGlyph(Index:Integer):Boolean;
function TeXDelimiterAdvance(Index:Integer):Double;
function TeXRadicalDepth(Index:Integer):Double;
function DrawTeXGlyph(Canvas:TCanvas; Index:Integer; const Bounds:TRect; Color:TColor=clDefault; PixelsPerEm:Double=0):Boolean;
function TeXGlyphLeft(Index:Integer):Double;
function TeXGlyphInkBounds(Index,OriginX,Baseline:Integer; PixelsPerEm:Double):TRect;
function TeXGlyphCacheCount:Integer;
procedure ClearTeXGlyphCache;
implementation
uses Math, NativeTeXGlyphs;
const NativeLimit=2048;
var TriedNext:Integer;
    NativeGlyphs:array of TNativeTeXGlyph;
    Tried:array of record Kind:string; Height:Double; Index,Bucket,Next:Integer; end;
    TriedBuckets:array[0..1023] of Integer;
function GlyphBucket(const Kind:string; Height:Double):Integer;
var Hash:LongWord; Bits:QWord; I:Integer;
begin
  {$push}{$Q-}{$R-}
  Bits:=QWord(Trunc(Height*1024)); Hash:=LongWord(Bits xor (Bits shr 32));
  for I:=1 to Length(Kind) do Hash:=(Hash xor Byte(Kind[I]))*16777619;
  {$pop}
  Result:=Hash and High(TriedBuckets);
end;
procedure RememberGlyph(const Kind:string; Height:Double; Index,Bucket:Integer);
var N,I,Previous:Integer;
begin
  if Length(Tried)<NativeLimit then begin N:=Length(Tried); SetLength(Tried,N+1); end
  else begin
    N:=TriedNext; TriedNext:=(TriedNext+1) mod NativeLimit;
    I:=TriedBuckets[Tried[N].Bucket]; Previous:=0;
    while I<>N+1 do begin Previous:=I; I:=Tried[I-1].Next; end;
    if Previous=0 then TriedBuckets[Tried[N].Bucket]:=Tried[N].Next
    else Tried[Previous-1].Next:=Tried[N].Next;
  end;
  Tried[N].Kind:=Kind; Tried[N].Height:=Height; Tried[N].Index:=Index;
  Tried[N].Bucket:=Bucket; Tried[N].Next:=TriedBuckets[Bucket]; TriedBuckets[Bucket]:=N+1;
end;
function SameParts(A,B:TNativeTeXGlyph):Boolean;
var I:Integer;
begin
  Result:=False;
  if (A=nil) or (A.Advance<>B.Advance) or (Length(A.Parts)<>Length(B.Parts)) then Exit;
  for I:=0 to High(A.Parts) do
    if (A.Parts[I].Font<>B.Parts[I].Font) or (A.Parts[I].Code<>B.Parts[I].Code) or
       (A.Parts[I].X<>B.Parts[I].X) or (A.Parts[I].Y<>B.Parts[I].Y) then Exit;
  Result:=True;
end;
function ChooseTeXGlyph(const Kind:string; Height:Double):Integer;
var I,Bucket:Integer; Glyph:TNativeTeXGlyph;
begin
  { A stable index keeps draft boxes safe while the bounded lookup grows.
    Large delimiters are assembled from TFM recipes at any requested size. }
  Height:=Ceil(Max(0,Height)*1024)/1024;
  Bucket:=GlyphBucket(Kind,Height); I:=TriedBuckets[Bucket];
  while I<>0 do begin
    if (Tried[I-1].Kind=Kind) and (Tried[I-1].Height=Height) then Exit(Tried[I-1].Index);
    I:=Tried[I-1].Next;
  end;
  Result:=-1;
  Glyph:=CreateNativeTeXGlyph(Kind,Height);
  if Glyph<>nil then begin
    { Nearby requested heights often select the same font glyph or recipe.
      Share that plan while keeping indices stable in existing draft boxes. }
    for I:=0 to High(NativeGlyphs) do
      if (TeXGlyphMetrics[I].Kind=Kind) and SameParts(NativeGlyphs[I],Glyph) then begin Result:=I; Break; end;
    if (Result<0) and (Length(NativeGlyphs)<NativeLimit) then begin
      Result:=Length(TeXGlyphMetrics); SetLength(TeXGlyphMetrics,Result+1); SetLength(NativeGlyphs,Result+1);
      NativeGlyphs[Result]:=Glyph;
      TeXGlyphMetrics[Result].Kind:=Kind; TeXGlyphMetrics[Result].W:=Glyph.Width;
      TeXGlyphMetrics[Result].H:=Glyph.Height; TeXGlyphMetrics[Result].Above:=Glyph.Above;
      TeXGlyphMetrics[Result].Advance:=Glyph.Advance;
      Glyph:=nil;
    end;
    Glyph.Free;
  end;
  RememberGlyph(Kind,Height,Result,Bucket);
end;
function IsNativeTeXGlyph(Index:Integer):Boolean;
begin Result:=(Index>=0) and (Index<Length(NativeGlyphs)) and (NativeGlyphs[Index]<>nil); end;
function TeXDelimiterAdvance(Index:Integer):Double;
begin
  Result:=TeXGlyphMetrics[Index].Advance;
end;
function TeXRadicalDepth(Index:Integer):Double;
begin
  Result:=0; if IsNativeTeXGlyph(Index) then Result:=NativeGlyphs[Index].TeXDepth;
end;
function TeXGlyphLeft(Index:Integer):Double;
begin Result:=0; if IsNativeTeXGlyph(Index) then Result:=NativeGlyphs[Index].Left; end;
function TeXGlyphInkBounds(Index,OriginX,Baseline:Integer; PixelsPerEm:Double):TRect;
var L:Double;
begin
  Result:=Rect(OriginX,Baseline,OriginX,Baseline);
  if (Index<0) or (Index>High(TeXGlyphMetrics)) then Exit;
  L:=TeXGlyphLeft(Index);
  with TeXGlyphMetrics[Index] do Result:=Rect(OriginX+Floor(L*PixelsPerEm),
    Baseline-Ceil(Above*PixelsPerEm),OriginX+Ceil((L+W)*PixelsPerEm),
    Baseline-Floor((Above-H)*PixelsPerEm));
end;
function DrawTeXGlyph(Canvas:TCanvas; Index:Integer; const Bounds:TRect; Color:TColor; PixelsPerEm:Double):Boolean;
begin
  Result:=IsNativeTeXGlyph(Index);
  if Result then Result:=NativeGlyphs[Index].Draw(Canvas,Bounds,Color,PixelsPerEm);
end;
function TeXGlyphCacheCount:Integer;
begin Result:=NativeTeXGlyphCacheCount; end;
procedure ClearTeXGlyphCache;
begin ClearNativeTeXGlyphCache; end;
var I:Integer;
finalization
  ClearTeXGlyphCache;
  for I:=0 to High(NativeGlyphs) do NativeGlyphs[I].Free;
end.
