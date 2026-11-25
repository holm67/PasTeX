unit PlatformLibraries;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Dynlibs;
function LoadOptionalLibrary(const Names:array of string):TLibHandle;
procedure ReleaseUnusedNativeMemory;
implementation
uses SysUtils;
procedure ReleaseUnusedNativeMemory;
{$IFDEF LINUX}
type TTrim=function(Padding:SizeUInt):Integer; cdecl;
var LibraryHandle:TLibHandle; Trim:TTrim;
{$ENDIF}
begin
  {$IFDEF LINUX}
  { Qt/Pango use libc's heap independently of FPC. Return their unused
    font and drawing allocations after a document has settled. }
  LibraryHandle:=LoadLibrary('libc.so.6');
  if LibraryHandle=NilHandle then Exit;
  try Pointer(Trim):=GetProcedureAddress(LibraryHandle,'malloc_trim'); if Assigned(Trim) then Trim(0);
  finally UnloadLibrary(LibraryHandle); end;
  {$ENDIF}
end;
function LoadOptionalLibrary(const Names:array of string):TLibHandle;
var Name:string;
begin
  Result:=NilHandle;
  for Name in Names do begin
    { Prefer explicitly shipped libraries beside the executable. }
    Result:=LoadLibrary(ExtractFilePath(ParamStr(0))+Name);
    if Result=NilHandle then Result:=LoadLibrary(Name);
    if Result<>NilHandle then Exit;
  end;
end;
end.
