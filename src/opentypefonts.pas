unit OpenTypeFonts;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
function OpenTypeFamily(const FileName:string):string;
function OpenTypePostScriptName(const FileName:string):string;
function OpenTypeSubfamily(const FileName:string):string;
implementation
uses Classes, SysUtils;
function FontNameFromFile(const FileName:string; NameID,FallbackID:Integer):string;
var F:TFileStream; Data:array of Byte; Header:array[0..15] of Byte; I,J,Count,Offset,Base,Start,Size,Records,Score,Best,ID,Platform:Integer;
    Text,Family:UnicodeString;
  function WordAt(P:Integer):Integer;
  begin if (P<0) or (P+1>=Length(Data)) then Exit(0); Result:=(Integer(Data[P]) shl 8)+Data[P+1]; end;
  function LongAt(P:Integer):Integer;
  begin Result:=(Integer(Header[P]) shl 24)+(Integer(Header[P+1]) shl 16)+(Integer(Header[P+2]) shl 8)+Header[P+3]; end;
begin
  Result:=''; F:=nil;
  try
  try
    F:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyNone); if F.Size<12 then Exit;
    F.ReadBuffer(Header,12); Base:=0;
    if (Header[0]=Ord('t')) and (Header[1]=Ord('t')) and (Header[2]=Ord('c')) and (Header[3]=Ord('f')) then begin
      F.ReadBuffer(Header,4); Base:=LongAt(0); if (Base<0) or (Base+12>F.Size) then Exit;
      F.Position:=Base; F.ReadBuffer(Header,12);
    end;
    Count:=(Integer(Header[4]) shl 8)+Header[5];
    for I:=0 to Count-1 do begin
      F.Position:=Base+12+I*16; if F.Position+16>F.Size then Exit; F.ReadBuffer(Header,16);
      if (Header[0]<>Ord('n')) or (Header[1]<>Ord('a')) or (Header[2]<>Ord('m')) or (Header[3]<>Ord('e')) then Continue;
      Offset:=LongAt(8); Size:=LongAt(12); if (Offset<0) or (Size<6) or (Size>262144) or (Offset+Size>F.Size) then Exit;
      SetLength(Data,Size); F.Position:=Offset; F.ReadBuffer(Data[0],Size); Records:=WordAt(2); Start:=WordAt(4); Best:=-1;
      for J:=0 to Records-1 do begin
        Offset:=6+J*12; if Offset+12>Size then Break; ID:=WordAt(Offset+6); if (ID<>NameID) and (ID<>FallbackID) then Continue;
        Platform:=WordAt(Offset); Score:=Ord(ID=NameID)*10+Ord(Platform=3)*3+Ord(WordAt(Offset+4)=$409);
        Base:=Start+WordAt(Offset+10); Count:=WordAt(Offset+8); if (Base<0) or (Base+Count>Size) or (Score<=Best) then Continue;
        Text:=''; if Platform in [0,3] then begin
          while Count>=2 do begin Text:=Text+WideChar(WordAt(Base)); Inc(Base,2); Dec(Count,2); end;
        end else while Count>0 do begin Text:=Text+WideChar(Data[Base]); Inc(Base); Dec(Count); end;
        if Text<>'' then begin Family:=Text; Best:=Score; end;
      end;
      Result:=UTF8Encode(Family); Exit;
    end;
  except Result:=''; end;
  finally F.Free; end;
end;
function OpenTypeFamily(const FileName:string):string;
begin Result:=FontNameFromFile(FileName,16,1); end;
function OpenTypePostScriptName(const FileName:string):string;
begin Result:=FontNameFromFile(FileName,6,6); end;
function OpenTypeSubfamily(const FileName:string):string;
begin Result:=FontNameFromFile(FileName,17,2); end;
end.
