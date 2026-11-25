unit BundledTeX;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
function BundledTeXFile(const Name:string):string;
implementation
uses Classes, SysUtils, Zipper;
{$R ../resources/native-fonts.res}
type
  TFontArchive=class
    Destination:string;
    procedure Open(Sender:TObject; var Stream:TStream);
    procedure Close(Sender:TObject; var Stream:TStream);
    procedure CreateFile(Sender:TObject; var Stream:TStream; Item:TFullZipFileEntry);
    procedure SaveFile(Sender:TObject; var Stream:TStream; Item:TFullZipFileEntry);
  end;
var Directory:string; Attempted:Boolean; Lock:TRTLCriticalSection;
    Archive:TUnZipper; Events:TFontArchive; Names:TStringList;
procedure TFontArchive.Open(Sender:TObject; var Stream:TStream);
begin Stream:=TResourceStream.Create(HInstance,'NATIVEFONTS',PChar(10)); end;
procedure TFontArchive.Close(Sender:TObject; var Stream:TStream);
begin FreeAndNil(Stream); end;
procedure TFontArchive.CreateFile(Sender:TObject; var Stream:TStream; Item:TFullZipFileEntry);
begin Stream:=TMemoryStream.Create; end;
procedure TFontArchive.SaveFile(Sender:TObject; var Stream:TStream; Item:TFullZipFileEntry);
var Temporary:string; Output:TFileStream;
begin
  Temporary:='';
  try
    Temporary:=GetTempFileName(Directory,'font'); Output:=TFileStream.Create(Temporary,fmCreate);
    try Stream.Position:=0; Output.CopyFrom(Stream,0); finally Output.Free; end;
    if not FileExists(Destination) then RenameFile(Temporary,Destination);
  finally if Temporary<>'' then DeleteFile(Temporary); FreeAndNil(Stream); end;
end;
procedure InitializeFonts;
var ID:TResourceStream; Key:string; I:Integer;
begin
  Attempted:=True; ID:=TResourceStream.Create(HInstance,'NATIVEFONTID',PChar(10));
  try SetLength(Key,ID.Size); if Key<>'' then ID.ReadBuffer(Key[1],Length(Key)); finally ID.Free; end;
  Directory:=IncludeTrailingPathDelimiter(GetAppConfigDir(False))+'cache'+DirectorySeparator+'fonts-'+Key+DirectorySeparator;
  Archive:=TUnZipper.Create; Events:=TFontArchive.Create;
  Names:=TStringList.Create; Names.CaseSensitive:=True; Names.Sorted:=True;
  Archive.OnOpenInputStream:=@Events.Open; Archive.OnCloseInputStream:=@Events.Close;
  Archive.OnCreateStream:=@Events.CreateFile; Archive.OnDoneStream:=@Events.SaveFile;
  Archive.Examine;
  for I:=0 to Archive.Entries.Count-1 do Names.Add(Archive.Entries[I].ArchiveFileName);
end;
function BundledTeXFile(const Name:string):string;
begin
  Result:=''; if (Name='') or (ExtractFileName(Name)<>Name) then Exit;
  EnterCriticalSection(Lock);
  try
    if not Attempted then try InitializeFonts; except Directory:=''; end;
    if (Directory='') or (Names=nil) or (Names.IndexOf(Name)<0) then Exit;
    Result:=Directory+Name;
    if not FileExists(Result) then try
      if ForceDirectories(Directory) then begin Events.Destination:=Result; Archive.UnZipFile(Name); end;
    except Result:=''; end;
    if not FileExists(Result) then Result:='';
  finally LeaveCriticalSection(Lock); end;
end;
initialization InitCriticalSection(Lock);
finalization Names.Free; Archive.Free; Events.Free; DoneCriticalSection(Lock);
end.
