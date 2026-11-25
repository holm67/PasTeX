unit AddonModel;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Contnrs, Dynlibs, FPJSON;
const PluginABI=1;
      PluginExtension={$IFDEF MSWINDOWS}'.dll'{$ELSE}'.so'{$ENDIF};
type
  TPluginCall=function(Value:PChar):PChar; cdecl;
  TPluginFree=procedure(Value:PChar); cdecl;
  TEditorAddon=class
  private
    FHandle:TLibHandle;
    FCall:TPluginCall;
    FFree:TPluginFree;
    procedure OpenLibrary;
  public
    ID,Name,Executable,Description,ManifestPath:string;
    Installed,Enabled:Boolean;
    Manifest:TJSONObject;
    constructor Create;
    destructor Destroy; override;
    procedure LoadLibraryFile(const Path:string);
    procedure Unload;
    function DisplayName:string;
    function Request(const Action:string; Values:TJSONObject):TJSONObject;
  end;
  TEditorAddons=class(TObjectList)
  public
    Warning:string;
    procedure RemoveAddon(Index:Integer);
    function Find(const ID:string):TEditorAddon;
    procedure InstallFile(const FileName:string);
    procedure Load;
    procedure Save;
  end;
function ExtensionRevision:QWord;
function AddonsDirectory:string;
function PluginTarget:string;
function ExtensionsDisabled:Boolean;
function ExtensionCompileSteps:TJSONArray;
function CachedExtensionPath(const ID,Executable:string):string;
procedure CacheExtensionPath(const ID,Executable,Path:string);
implementation
uses JSONUTF8, ToolJobs, IniFiles, AtomicFiles;
type TPluginVersion=function:LongWord; cdecl;
     TPluginDescribe=function:PChar; cdecl;
var SyntaxRevision:LongInt=0;
    PathLock,StateLock:TRTLCriticalSection;
    KnownPaths:array of record ID,Executable,Path:string; end;
function ExtensionRevision:QWord;
begin Result:=InterlockedCompareExchange(SyntaxRevision,0,0); end;
function CachedExtensionPath(const ID,Executable:string):string;
var I:Integer;
begin
  Result:=''; EnterCriticalSection(PathLock);
  try for I:=0 to High(KnownPaths) do if (KnownPaths[I].ID=ID) and (KnownPaths[I].Executable=Executable) then Exit(KnownPaths[I].Path);
  finally LeaveCriticalSection(PathLock); end;
end;
procedure CacheExtensionPath(const ID,Executable,Path:string);
var I:Integer;
begin
  EnterCriticalSection(PathLock);
  try
    for I:=0 to High(KnownPaths) do if (KnownPaths[I].ID=ID) and (KnownPaths[I].Executable=Executable) then begin KnownPaths[I].Path:=Path; Exit; end;
    if Length(KnownPaths)>=64 then begin for I:=0 to High(KnownPaths)-1 do KnownPaths[I]:=KnownPaths[I+1]; SetLength(KnownPaths,63); end;
    I:=Length(KnownPaths); SetLength(KnownPaths,I+1); KnownPaths[I].ID:=ID; KnownPaths[I].Executable:=Executable; KnownPaths[I].Path:=Path;
  finally LeaveCriticalSection(PathLock); end;
end;
function PluginTarget:string;
begin Result:=LowerCase({$I %FPCTARGETCPU%}+'-'+{$I %FPCTARGETOS%}); end;
function ExtensionsDisabled:Boolean;
var I:Integer;
begin
  Result:=False;
  for I:=1 to ParamCount do if SameText(ParamStr(I),'--no-extensions') or SameText(ParamStr(I),'-no-extensions') then Exit(True);
end;
function AddonsDirectory:string;
begin Result:=IncludeTrailingPathDelimiter(GetAppConfigDir(False))+'extensions'; end;
constructor TEditorAddon.Create;
begin inherited; FHandle:=NilHandle; end;
procedure TEditorAddon.Unload;
begin if FHandle<>NilHandle then UnloadLibrary(FHandle); FHandle:=NilHandle; FCall:=nil; FFree:=nil; end;
destructor TEditorAddon.Destroy;
begin Unload; Manifest.Free; inherited; end;
procedure TEditorAddon.OpenLibrary;
var Version:TPluginVersion;
begin
  if FHandle<>NilHandle then Exit;
  FHandle:=Dynlibs.LoadLibrary(ManifestPath); if FHandle=NilHandle then raise Exception.Create('Cannot load '+ManifestPath+': '+GetLoadErrorStr);
  Pointer(Version):=GetProcedureAddress(FHandle,'pastex_plugin_abi');
  Pointer(FCall):=GetProcedureAddress(FHandle,'pastex_plugin_call'); Pointer(FFree):=GetProcedureAddress(FHandle,'pastex_plugin_free');
  if not Assigned(Version) or not Assigned(FCall) or not Assigned(FFree) then begin Unload; raise Exception.Create('Missing PasTeX plug-in exports'); end;
  if Version()<>PluginABI then begin Unload; raise Exception.Create('Unsupported PasTeX plug-in ABI'); end;
end;
procedure TEditorAddon.LoadLibraryFile(const Path:string);
var Describe:TPluginDescribe; Buffer:PChar; Data:TJSONData; C:Char; I:Integer; Candidate:string;
begin
  ManifestPath:=ExpandFileName(Path); OpenLibrary; Pointer(Describe):=GetProcedureAddress(FHandle,'pastex_plugin_describe');
  if not Assigned(Describe) then raise Exception.Create('Missing plug-in descriptor export');
  Buffer:=Describe(); if Buffer=nil then raise Exception.Create('Empty plug-in descriptor');
  try Data:=ParseJSONUTF8(UTF8String(Buffer)); finally FFree(Buffer); end;
  if not (Data is TJSONObject) then begin Data.Free; raise Exception.Create('A plug-in descriptor must be an object'); end;
  FreeAndNil(Manifest); Manifest:=TJSONObject(Data); ID:=Manifest.Get('id','');
  if ID='' then raise Exception.Create('The plug-in ID is empty');
  for C in ID do if not (C in ['a'..'z','A'..'Z','0'..'9','-','_']) then raise Exception.Create('Invalid plug-in ID');
  Name:=Manifest.Get('name',ID); Description:=Manifest.Get('description',''); Executable:=Manifest.Get('executable','');
  Installed:=True; Enabled:=(Executable='') or (FindTool(Manifest.Get('detect',Executable))<>'');
  if not Enabled and (Manifest.Find('executableAlternatives') is TJSONArray) then
    for I:=0 to Manifest.Arrays['executableAlternatives'].Count-1 do begin
      Candidate:=Manifest.Arrays['executableAlternatives'].Strings[I];
      if FindTool(Candidate)<>'' then begin Executable:=Candidate; Enabled:=True; Break; end;
    end;
end;
function TEditorAddon.DisplayName:string;
begin
  Result:=Name; if not Installed then Result:=Result+' [not installed]'
  else if Enabled then Result:=Result+' [enabled]' else Result:=Result+' [disabled]';
end;
function TEditorAddon.Request(const Action:string; Values:TJSONObject):TJSONObject;
var Input:TJSONObject; Buffer:PChar; Data:TJSONData; Text:UTF8String;
begin
  if not Installed or not Enabled then raise Exception.Create('Enable this plug-in before running it');
  OpenLibrary; Input:=TJSONObject.Create(['action',Action,'context',Values.Clone,'config',TJSONObject.Create(['executable',Executable])]);
  try Text:=Input.AsJSON; Buffer:=FCall(PChar(Text));
    if Buffer=nil then raise Exception.Create('The plug-in returned no response');
    try Data:=ParseJSONUTF8(UTF8String(Buffer)); finally FFree(Buffer); end;
    if not (Data is TJSONObject) then begin Data.Free; raise Exception.Create('The plug-in response must be an object'); end;
    Result:=TJSONObject(Data);
  finally Input.Free; end;
end;
function TEditorAddons.Find(const ID:string):TEditorAddon;
var I:Integer;
begin Result:=nil; for I:=0 to Count-1 do if TEditorAddon(Items[I]).ID=ID then Exit(TEditorAddon(Items[I])); end;
procedure TEditorAddons.RemoveAddon(Index:Integer);
var A:TEditorAddon;
begin
  A:=TEditorAddon(Items[Index]); A.Enabled:=False; A.Installed:=False; A.Unload;
  if ExtractFileDir(A.ManifestPath)=AddonsDirectory then SysUtils.DeleteFile(A.ManifestPath);
end;
procedure TEditorAddons.InstallFile(const FileName:string);
var A:TEditorAddon; Input,Output:TFileStream; Destination,ID:string;
begin
  A:=TEditorAddon.Create;
  try A.LoadLibraryFile(FileName); ID:=A.ID; finally A.Free; end;
  ForceDirectories(AddonsDirectory); Destination:=IncludeTrailingPathDelimiter(AddonsDirectory)+'pastex-'+ID+PluginExtension;
  if ExpandFileName(FileName)<>ExpandFileName(Destination) then begin
    A:=Find(ID); if A<>nil then A.Unload;
    Input:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
    try Output:=TFileStream.Create(Destination,fmCreate); try Output.CopyFrom(Input,0); finally Output.Free; end; finally Input.Free; end;
  end;
  Load; A:=Find(ID); if A<>nil then begin A.Installed:=True; A.Enabled:=True; end; Save;
end;
procedure TEditorAddons.Load;
var Directories,Lines:TStringList; Directory,Ancestor:string; Search:TSearchRec; A,Previous:TEditorAddon; I:Integer; Data:TJSONData; Item:TJSONObject;
  procedure ReadDirectory(const Path:string);
  begin
    if FindFirst(IncludeTrailingPathDelimiter(Path)+'pastex-*'+PluginExtension,faAnyFile,Search)<>0 then Exit;
    try repeat
      if (Search.Attr and faDirectory)<>0 then Continue; A:=TEditorAddon.Create;
      try A.LoadLibraryFile(IncludeTrailingPathDelimiter(Path)+Search.Name); Previous:=Find(A.ID);
        if Previous<>nil then Remove(Previous); Add(A); A:=nil;
      except on E:Exception do Warning:=Warning+Search.Name+': '+E.Message+LineEnding; end;
      A.Free;
    until FindNext(Search)<>0; finally SysUtils.FindClose(Search); end;
  end;
begin
  Clear; Warning:=''; OwnsObjects:=True; Directories:=TStringList.Create; Lines:=TStringList.Create; Data:=nil;
  try
    if ExtensionsDisabled then Exit;
    Ancestor:=ExcludeTrailingPathDelimiter(ExtractFileDir(ExpandFileName(ParamStr(0))));
    for I:=0 to 4 do begin
      Directory:=IncludeTrailingPathDelimiter(Ancestor)+'extensions'; Directories.Add(Directory+DirectorySeparator+PluginTarget); Directories.Add(Directory);
      Directory:=ExtractFileDir(Ancestor); if Directory=Ancestor then Break; Ancestor:=Directory;
    end;
    for I:=Directories.Count-1 downto 0 do ReadDirectory(Directories[I]);
    ReadDirectory(AddonsDirectory);
    EnterCriticalSection(StateLock);
    try if FileExists(IncludeTrailingPathDelimiter(GetAppConfigDir(False))+'extensions.json') then begin
      Lines.LoadFromFile(IncludeTrailingPathDelimiter(GetAppConfigDir(False))+'extensions.json'); Data:=ParseJSONUTF8(Lines.Text);
      if Data is TJSONArray then for I:=0 to Data.Count-1 do if Data.Items[I] is TJSONObject then begin
        Item:=TJSONObject(Data.Items[I]); A:=Find(Item.Get('id','')); if A=nil then Continue;
        A.Enabled:=Item.Get('enabled',A.Enabled); A.Installed:=Item.Get('installed',A.Installed); A.Executable:=Item.Get('executable',A.Executable);
      end;
    end;
    except on E:Exception do Warning:=Warning+'Plug-in settings could not be read: '+E.Message+LineEnding; end;
    LeaveCriticalSection(StateLock);
    for I:=0 to Count-1 do begin A:=TEditorAddon(Items[I]); if not A.Installed or not A.Enabled then A.Unload; end;
  finally Data.Free; Lines.Free; Directories.Free; end;
end;
procedure TEditorAddons.Save;
var Entries:TJSONArray; I:Integer; A:TEditorAddon; Lines:TStringList; Path,Temporary:string;
begin
  Entries:=TJSONArray.Create; Lines:=TStringList.Create;
  try
    for I:=0 to Count-1 do begin A:=TEditorAddon(Items[I]);
      Entries.Add(TJSONObject.Create(['id',A.ID,'enabled',A.Enabled,'installed',A.Installed,'executable',A.Executable]));
    end;
    ForceDirectories(GetAppConfigDir(False)); Lines.Text:=Entries.FormatJSON;
    Path:=IncludeTrailingPathDelimiter(GetAppConfigDir(False))+'extensions.json'; Temporary:=Path+'.'+IntToStr(GetProcessID)+'.new';
    EnterCriticalSection(StateLock);
    try
      Lines.SaveToFile(Temporary);
      { Readers, including compiler workers, must see a complete JSON file. }
      if not ReplaceFileAtomically(Temporary,Path) then RaiseLastOSError;
      InterlockedIncrement(SyntaxRevision);
    finally SysUtils.DeleteFile(Temporary); LeaveCriticalSection(StateLock); end;
  finally Lines.Free; Entries.Free; end;
end;
function ExtensionCompileSteps:TJSONArray;
var Catalog:TEditorAddons; A:TEditorAddon; I:Integer; Ini:TIniFile; Hook,Setup,Values:TJSONObject; Path:string;
begin
  Result:=TJSONArray.Create; if not ExtensionBuildEnabled then Exit; Catalog:=TEditorAddons.Create(True); Ini:=TIniFile.Create(GetAppConfigFile(False));
  try Catalog.Load;
    for I:=0 to Catalog.Count-1 do begin A:=TEditorAddon(Catalog[I]);
      if not A.Installed or not A.Enabled or not Ini.ReadBool('Plugin.'+A.ID,'CompileEnabled',True) then Continue;
      if A.Manifest.Find('compileHook') is TJSONObject then begin
        Hook:=TJSONObject(A.Manifest.Objects['compileHook'].Clone); Hook.Strings['executable']:=A.Executable; Result.Add(Hook);
        if Hook.Get('setupAction','')<>'' then begin
          Values:=TJSONObject.Create;
          try Setup:=A.Request(Hook.Get('setupAction',''),Values);
            try if Setup.Find('compileHook') is TJSONObject then begin
              Result.Delete(Result.Count-1); Hook:=TJSONObject(Setup.Objects['compileHook'].Clone); Result.Add(Hook);
            end; finally Setup.Free; end;
          finally Values.Free; end;
        end;
        Hook.Strings['pluginID']:=A.ID;
        Path:=CachedExtensionPath(A.ID,A.Executable); if Path<>'' then Hook.Strings['texInputs']:=Path;
        Path:=Ini.ReadString('Plugin.'+A.ID,'CompileTexInputs',''); if Path<>'' then Hook.Strings['texInputs']:=Path;
      end;
    end;
  finally Ini.Free; Catalog.Free; end;
end;
initialization
  InitCriticalSection(PathLock);
  InitCriticalSection(StateLock);
finalization
  DoneCriticalSection(StateLock);
  DoneCriticalSection(PathLock);
end.
