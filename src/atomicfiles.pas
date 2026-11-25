unit AtomicFiles;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
{ Temporary and destination must be on the same filesystem. }
function ReplaceFileAtomically(const Temporary,Destination:string):Boolean;
implementation
uses SysUtils{$IFDEF MSWINDOWS}, Windows{$ENDIF};
function ReplaceFileAtomically(const Temporary,Destination:string):Boolean;
begin
  {$IFDEF MSWINDOWS}
  Result:=MoveFileExW(PWideChar(UTF8Decode(Temporary)),PWideChar(UTF8Decode(Destination)),
    MOVEFILE_REPLACE_EXISTING or MOVEFILE_WRITE_THROUGH);
  {$ELSE}
  Result:=RenameFile(Temporary,Destination);
  {$ENDIF}
end;
end.
