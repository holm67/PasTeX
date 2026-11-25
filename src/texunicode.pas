unit TeXUnicode;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
function NextUTF8CodePoint(const S:string; var Offset:Integer):Cardinal;
function CJKCodePoint(Code:Cardinal):Boolean;
implementation
function NextUTF8CodePoint(const S:string; var Offset:Integer):Cardinal;
var Count,I:Integer; B:Byte;
begin
  Result:=0; if (Offset<1) or (Offset>Length(S)) then Exit;
  B:=Byte(S[Offset]); Count:=1; Result:=B;
  if (B and $E0)=$C0 then begin Count:=2; Result:=B and $1F; end
  else if (B and $F0)=$E0 then begin Count:=3; Result:=B and $0F; end
  else if (B and $F8)=$F0 then begin Count:=4; Result:=B and $07; end;
  if Offset+Count-1>Length(S) then Count:=1;
  for I:=1 to Count-1 do begin
    B:=Byte(S[Offset+I]); if (B and $C0)<>$80 then begin Count:=1; Break; end;
    Result:=(Result shl 6) or (B and $3F);
  end;
  Inc(Offset,Count);
end;
function CJKCodePoint(Code:Cardinal):Boolean;
begin
  Result:=((Code>=$2E80) and (Code<=$9FFF)) or ((Code>=$AC00) and (Code<=$D7AF)) or
    ((Code>=$F900) and (Code<=$FAFF)) or ((Code>=$20000) and (Code<=$323AF)) or
    ((Code>=$FF00) and (Code<=$FFEF));
end;
end.
