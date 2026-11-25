unit TeXPackageSources;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
function ResolveTeXSource(const Name,Directory:string):string;
function ReadTeXSource(const Path:string; Refresh:Boolean=False; Retain:Boolean=True):string;
implementation
uses Classes, SysUtils, TeXFileSearch;
const CacheLimit=4*1024*1024; FileLimit=1024*1024; PathLimit=256;
type TSourceEntry=class
  Text:string;
  Age:Int64;
  Size:Int64;
end;
var Paths,Files:TStringList; CacheSize:Integer;
function ResolveTeXSource(const Name,Directory:string):string;
var Local,Key:string; I:Integer; Entry:TSourceEntry;
begin
  Result:=''; if Trim(Name)='' then Exit;
  if (ExtractFileDrive(Name)<>'') or (Name[1] in ['/','\']) then Local:=Name
  else Local:=IncludeTrailingPathDelimiter(Directory)+Name;
  Local:=ExpandFileName(Local); if FileExists(Local) then Exit(Local);
  { TeX's kpathsea search respects TEXINPUTS and the active installation;
    local files keep precedence, including newly created package files. }
  Key:=Directory+'|'+Name; I:=Paths.IndexOf(Key);
  if I>=0 then Exit(TSourceEntry(Paths.Objects[I]).Text);
  Result:=SearchTeXFile(Name);
  if Paths.Count>=PathLimit then Paths.Delete(0);
  Entry:=TSourceEntry.Create; Entry.Text:=Result; Paths.AddObject(Key,Entry);
end;
function ReadTeXSource(const Path:string; Refresh:Boolean; Retain:Boolean):string;
var Entry:TSourceEntry; Search:TSearchRec; I:Integer; Lines:TStringList;
begin
  Result:=''; if (Path='') or (FindFirst(Path,faAnyFile,Search)<>0) then Exit;
  FindClose(Search); if (Search.Size<0) or (Search.Size>FileLimit) then Exit;
  I:=Files.IndexOf(Path);
  if I>=0 then begin
    Entry:=TSourceEntry(Files.Objects[I]);
    if not Refresh and (Entry.Age=Search.Time) and (Entry.Size=Search.Size) then Exit(Entry.Text);
    Dec(CacheSize,Length(Entry.Text)); Files.Delete(I);
  end;
  Lines:=TStringList.Create;
  try try Lines.LoadFromFile(Path); Result:=Lines.Text; except Result:=''; end;
  finally Lines.Free; end;
  if (Result='') or not Retain then Exit;
  while (CacheSize+Length(Result)>CacheLimit) and (Files.Count>0) do begin
    Entry:=TSourceEntry(Files.Objects[0]); Dec(CacheSize,Length(Entry.Text)); Files.Delete(0);
  end;
  Entry:=TSourceEntry.Create; Entry.Text:=Result; Entry.Age:=Search.Time; Entry.Size:=Search.Size;
  Files.AddObject(Path,Entry); Inc(CacheSize,Length(Result));
end;
initialization
  Paths:=TStringList.Create; Paths.CaseSensitive:=True; Paths.UseLocale:=False; Paths.Sorted:=True; Paths.OwnsObjects:=True;
  Files:=TStringList.Create; Files.CaseSensitive:=True; Files.UseLocale:=False; Files.OwnsObjects:=True;
finalization
  Files.Free; Paths.Free;
end.
