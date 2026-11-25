unit JSONUTF8;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses FPJSON;
function ParseJSONUTF8(const Source:UTF8String):TJSONData;
implementation
uses SysUtils, JSONParser;
function NormalizeEscapes(const Source:UTF8String):UTF8String;
var I,N,J,Code,Low:Integer; InString:Boolean;
  function Hex4(At:Integer):Integer;
  var K,Digit:Integer;
  begin
    Result:=0; if At+3>Length(Source) then raise EConvertError.Create('Incomplete JSON Unicode escape');
    for K:=At to At+3 do begin
      case Source[K] of
        '0'..'9':Digit:=Ord(Source[K])-Ord('0');
        'a'..'f':Digit:=Ord(Source[K])-Ord('a')+10;
        'A'..'F':Digit:=Ord(Source[K])-Ord('A')+10;
        else raise EConvertError.Create('Invalid JSON Unicode escape');
      end;
      Result:=Result*16+Digit;
    end;
  end;
  procedure Put(Value:Byte);
  begin Inc(N); Result[N]:=AnsiChar(Value); end;
begin
  { FPC 3.2.2's scanner uses a four-byte short string for two adjacent \u
    escapes. Normalize printable codepoints first so CJK pairs cannot truncate. }
  if Pos('\u',Source)=0 then Exit(Source);
  SetLength(Result,Length(Source)); I:=1; N:=0; InString:=False;
  while I<=Length(Source) do begin
    if InString and (Source[I]='\') and (I<Length(Source)) then begin
      if Source[I+1]<>'u' then begin Put(Ord(Source[I])); Put(Ord(Source[I+1])); Inc(I,2); Continue; end;
      Code:=Hex4(I+2); J:=I+6;
      if (Code>=$D800) and (Code<=$DBFF) then begin
        if Copy(Source,J,2)<>'\u' then raise EConvertError.Create('Missing JSON low surrogate');
        Low:=Hex4(J+2); if (Low<$DC00) or (Low>$DFFF) then raise EConvertError.Create('Invalid JSON low surrogate');
        Code:=$10000+(Code-$D800)*$400+(Low-$DC00); Inc(J,6);
      end else if (Code>=$DC00) and (Code<=$DFFF) then raise EConvertError.Create('Unexpected JSON low surrogate');
      if Code<32 then begin while I<J do begin Put(Ord(Source[I])); Inc(I); end; Continue; end;
      if (Code=Ord('"')) or (Code=Ord('\')) then begin Put(Ord('\')); Put(Code); end
      else if Code<$80 then Put(Code)
      else if Code<$800 then begin Put($C0 or (Code shr 6)); Put($80 or (Code and $3F)); end
      else if Code<$10000 then begin Put($E0 or (Code shr 12)); Put($80 or ((Code shr 6) and $3F)); Put($80 or (Code and $3F)); end
      else begin Put($F0 or (Code shr 18)); Put($80 or ((Code shr 12) and $3F)); Put($80 or ((Code shr 6) and $3F)); Put($80 or (Code and $3F)); end;
      I:=J; Continue;
    end;
    if Source[I]='"' then InString:=not InString;
    Put(Ord(Source[I])); Inc(I);
  end;
  SetLength(Result,N);
end;
function ParseJSONUTF8(const Source:UTF8String):TJSONData;
begin Result:=GetJSON(NormalizeEscapes(Source)); end;
end.
