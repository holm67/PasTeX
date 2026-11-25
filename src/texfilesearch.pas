unit TeXFileSearch;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
function SearchTeXFile(const Name:string):string;
implementation
uses SysUtils, Process, Dynlibs;
type
  TNewInstance=function:Pointer; cdecl;
  TFinish=procedure(Instance:Pointer); cdecl;
  TProgramName=procedure(Instance:Pointer; Executable,Name:PChar); cdecl;
  TFindFile=function(Instance:Pointer; Name:PChar; Format,MustExist:Integer):PChar; cdecl;
  TFree=procedure(Value:Pointer); cdecl;
var
  Lock:TRTLCriticalSection;
  LibraryHandle:TLibHandle=NilHandle;
  Instance:Pointer;
  Attempted:Boolean;
  Finish:TFinish;
  FindFile:TFindFile;
  FreeString:TFree;
function FileFormat(const Name:string):Integer;
begin
  { Stable values of kpse_file_format_type in TeX Live's types.h. }
  case LowerCase(ExtractFileExt(Name)) of
    '.tfm':Result:=3; '.afm':Result:=4; '.bib':Result:=6; '.bst':Result:=7;
    '.pfb','.pfa':Result:=32; '.vf':Result:=33; '.ttf','.ttc':Result:=36;
    '.enc':Result:=44; '.otf':Result:=47;
    '.tex','.sty','.cls','.fd','.def','.cfg','.ltx','.bbx','.cbx':Result:=26;
    else Result:=-1;
  end;
end;
procedure InitializeSearch;
var NewInstance:TNewInstance; ProgramName:TProgramName; Executable:string;
begin
  if Attempted then Exit; Attempted:=True;
  if GetEnvironmentVariable('PASTEX_DISABLE_TEX_LOOKUP')='1' then Exit;
  {$IFDEF UNIX}
  Executable:=FileSearch('kpsewhich',GetEnvironmentVariable('PATH'));
  if Executable='' then Exit;
  LibraryHandle:=LoadLibrary('libkpathsea.so.6');
  if LibraryHandle=NilHandle then LibraryHandle:=LoadLibrary('libkpathsea.so');
  if LibraryHandle=NilHandle then Exit;
  Pointer(NewInstance):=GetProcedureAddress(LibraryHandle,'kpathsea_new');
  Pointer(Finish):=GetProcedureAddress(LibraryHandle,'kpathsea_finish');
  Pointer(ProgramName):=GetProcedureAddress(LibraryHandle,'kpathsea_set_program_name');
  Pointer(FindFile):=GetProcedureAddress(LibraryHandle,'kpathsea_find_file');
  Pointer(FreeString):=GetProcedureAddress(LibraryHandle,'free');
  if Assigned(NewInstance) and Assigned(Finish) and Assigned(ProgramName) and
     Assigned(FindFile) and Assigned(FreeString) then begin
    Instance:=NewInstance();
    if Instance<>nil then ProgramName(Instance,PChar(Executable),'kpsewhich');
  end;
  {$ENDIF}
end;
function SearchTeXFile(const Name:string):string;
var Found:PChar; Format:Integer; Output:string; UsedLibrary:Boolean;
begin
  Result:=''; if GetEnvironmentVariable('PASTEX_DISABLE_TEX_LOOKUP')='1' then Exit;
  Format:=FileFormat(Name); UsedLibrary:=False;
  EnterCriticalSection(Lock);
  try
    InitializeSearch;
    if (Instance<>nil) and (Format>=0) then begin
      UsedLibrary:=True; Found:=FindFile(Instance,PChar(Name),Format,0);
      if Found<>nil then begin
        try Result:=string(Found); finally FreeString(Found); end;
      end;
    end;
  finally LeaveCriticalSection(Lock); end;
  if not UsedLibrary then try
    if RunCommand('kpsewhich',[Name],Output,[poNoConsole]) then Result:=Trim(Output);
  except Result:=''; end;
  if (Result<>'') and not FileExists(Result) then Result:='';
end;
initialization
  InitCriticalSection(Lock);
finalization
  if Instance<>nil then Finish(Instance);
  if LibraryHandle<>NilHandle then UnloadLibrary(LibraryHandle);
  DoneCriticalSection(Lock);
end.
