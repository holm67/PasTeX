unit PreviewBackdrops;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses FPImage;
type TBackdropMask=array of Byte;
function WhiteBackdropMask(Image:TFPCustomImage):TBackdropMask;
function BackdropPixel(const Mask:TBackdropMask; Index:SizeInt):Boolean; inline;
implementation
function BackdropPixel(const Mask:TBackdropMask; Index:SizeInt):Boolean;
begin Result:=(Index>=0) and (Length(Mask)>(Index shr 3)) and ((Mask[Index shr 3] and (1 shl (Index and 7)))<>0); end;
function WhiteBackdropMask(Image:TFPCustomImage):TBackdropMask;
var Mask:TBackdropMask; Pending:array of SizeInt; Count,X,Y,SX,SY,L,R,Row,W,H,Step,Index:SizeInt; C:TFPColor;
  function Unmarked(X,Y:SizeInt):Boolean;
  begin Result:=not BackdropPixel(Mask,X+Y*W) and (Image.Colors[X,Y].Alpha=65535); end;
  procedure Push(X,Y:SizeInt);
  begin
    if Count=Length(Pending) then SetLength(Pending,Count*2+64);
    Pending[Count]:=X+Y*W; Inc(Count);
  end;
begin
  Result:=nil; Mask:=nil; Count:=0; W:=Image.Width; H:=Image.Height;
  { An opaque painted region is already composited with its text. Protect
    the entire connected region when it contains white paint, including
    solid rules and white text on black. A scanline fill needs one bit per
    pixel and a small stack, rather than a queue entry for every pixel. }
  for SY:=0 to H-1 do for SX:=0 to W-1 do begin
    C:=Image.Colors[SX,SY];
    if (C.Alpha<>65535) or (C.Red<>65535) or (C.Green<>65535) or (C.Blue<>65535) or BackdropPixel(Mask,SX+SY*W) then Continue;
    if Length(Mask)=0 then SetLength(Mask,(W*H+7) div 8);
    Push(SX,SY);
    while Count>0 do begin
      Dec(Count); X:=Pending[Count] mod W; Y:=Pending[Count] div W;
      if not Unmarked(X,Y) then Continue;
      L:=X; R:=X;
      while (L>0) and Unmarked(L-1,Y) do Dec(L);
      while (R+1<W) and Unmarked(R+1,Y) do Inc(R);
      for X:=L to R do begin Index:=X+Y*W; Mask[Index shr 3]:=Mask[Index shr 3] or (1 shl (Index and 7)); end;
      for Step:=0 to 1 do begin
        Row:=Y-1+Step*2; if (Row<0) or (Row>=H) then Continue;
        X:=L;
        while X<=R do begin
          if Unmarked(X,Row) then begin
            Push(X,Row); repeat Inc(X); until (X>R) or not Unmarked(X,Row);
          end else Inc(X);
        end;
      end;
    end;
  end;
  Result:=Mask;
end;
end.
