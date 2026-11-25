unit TeXTextMetrics;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Graphics;
function TeXTextWidth(Canvas:TCanvas; const Text:string):Integer;
implementation
uses LazUTF8
  {$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}, QtObjects{$ENDIF};
function TeXTextWidth(Canvas:TCanvas; const Text:string):Integer;
{$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}
var Wide:WideString;
{$ENDIF}
begin
  { This selects the canvas font into its native device context as well. }
  Result:=Canvas.TextWidth(Text);
  {$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}
  Wide:=UTF8Decode(Text);
  if Length(Wide)<>UTF8Length(Text) then
    { LCL 4.0 passes Unicode character count to a Qt UTF-16 length argument.
      Mathematical alphabets need both halves of each surrogate pair. }
    Result:=TQtDeviceContext(Canvas.Handle).Metrics.width(@Wide,Length(Wide));
  {$ENDIF}
end;
end.
