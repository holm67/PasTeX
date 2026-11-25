unit TeXRenderer;
{ SPDX-License-Identifier: GPL-3.0-or-later }

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, FPJSON, Process, Math;

type
  TRenderThread = class(TThread)
  private
    FSource, FDirectory, FEngine,FCompiler,FCompilerArguments: string;
    FCompileSteps:FPJSON.TJSONArray;
    FCommandOutput:string;
    function Run(const ProgramName: string; const Args: array of string; const Directory:string=''; TimeoutMS:Integer=60000): Boolean;
    function CompileSnapshot(const Prefix:string):Boolean;
    procedure ExtractLayout(const Prefix:string);
  protected
    procedure Execute; override;
  public
    PDFOnly,PageLayoutOnly,SyncTeX:Boolean;
    Revision: Integer;
    RenderPasses, DPI, PreviewPage: Integer;
    WorkDir, ErrorText, LogText: string;
    LayoutXML,Positions,FallbackSource,BibliographySource:string;
    Images: TStringList;
    property SourceText:string read FSource;
    constructor Create(const Source, Directory, Engine: string; ARevision: Integer);
    destructor Destroy; override;
  end;

implementation
uses ToolJobs, AddonModel, PreambleModel, TeXMacros, ManagedProcess;

constructor TRenderThread.Create(const Source, Directory, Engine: string; ARevision: Integer);
begin
  inherited Create(True);
  FreeOnTerminate := False;
  FSource := Source;
  FDirectory := Directory;
  FEngine := Engine;
  CompilerProfile(Engine,FCompiler,FCompilerArguments);
  FCompileSteps:=ExtensionCompileSteps;
  Revision := ARevision;
  RenderPasses := 2; DPI := 120;
  Images := TStringList.Create;
end;

destructor TRenderThread.Destroy;
  procedure RemoveWorkDirectory(const Directory:string);
  var Entry:TSearchRec; Path:string;
  begin
    if FindFirst(IncludeTrailingPathDelimiter(Directory)+'*',faAnyFile,Entry)=0 then begin
      try repeat
        if (Entry.Name='.') or (Entry.Name='..') then Continue; Path:=IncludeTrailingPathDelimiter(Directory)+Entry.Name;
        if ((Entry.Attr and faDirectory)<>0) and ((Entry.Attr and faSymLink)=0) then RemoveWorkDirectory(Path) else DeleteFile(Path);
      until FindNext(Entry)<>0; finally FindClose(Entry); end;
    end;
    RemoveDir(Directory);
  end;
begin
  if WorkDir<>'' then RemoveWorkDirectory(WorkDir);
  FCompileSteps.Free; Images.Free;
  inherited Destroy;
end;

function TRenderThread.Run(const ProgramName: string; const Args: array of string; const Directory:string; TimeoutMS:Integer): Boolean;
var
  P: TManagedProcess;
  I, N: Integer;
  Buffer: array[0..8191] of Byte;
  Captured,CommandOutput:TProcessOutput;
  Started: QWord;
  SearchPaths:string;
begin
  Result := False;
  FCommandOutput:='';
  if Terminated then Exit;
  P := TManagedProcess.Create(nil);
  Captured:=nil; CommandOutput:=nil;
  try
    Captured:=TProcessOutput.Create(200000,LogText);
    CommandOutput:=TProcessOutput.Create(200000);
    P.Executable := FindTool(ProgramName); if P.Executable='' then P.Executable:=ProgramName;
    P.CurrentDirectory := FDirectory;
    if Directory<>'' then P.CurrentDirectory:=Directory;
    for I:=1 to GetEnvironmentVariableCount do P.Environment.Add(GetEnvironmentString(I));
    SearchPaths:=WorkDir+PathSeparator+FDirectory+PathSeparator;
    for I:=0 to FCompileSteps.Count-1 do if FCompileSteps.Objects[I].Get('texInputs','')<>'' then
      SearchPaths:=SearchPaths+FCompileSteps.Objects[I].Get('texInputs','')+PathSeparator;
    P.Environment.Values['TEXINPUTS']:=SearchPaths+GetEnvironmentVariable('TEXINPUTS');
    if (ProgramName='bibtex') or (ProgramName='biber') then begin
      P.Environment.Values['BIBINPUTS']:=FDirectory+PathSeparator+GetEnvironmentVariable('BIBINPUTS');
      P.Environment.Values['BSTINPUTS']:=FDirectory+PathSeparator+GetEnvironmentVariable('BSTINPUTS');
    end;
    P.Options := [poUsePipes, poStderrToOutPut, poNoConsole];
    for I := Low(Args) to High(Args) do P.Parameters.Add(Args[I]);
    P.Execute;
    Started := GetTickCount64;
    repeat
      if Terminated or (GetTickCount64 - Started > QWord(TimeoutMS)) then
      begin
        P.Cancel;
        ErrorText := 'Preview cancelled or exceeded the '+IntToStr(TimeoutMS div 1000)+' second timeout.';
        Exit;
      end;
      if P.Output.NumBytesAvailable>0 then begin
        N:=P.Output.Read(Buffer,SizeOf(Buffer)); Captured.Append(Buffer,N); CommandOutput.Append(Buffer,N);
        Continue;
      end;
      if not P.Running then
      begin
        if P.Output.NumBytesAvailable = 0 then Break;
      end
      else Sleep(15);
    until False;
    Result := P.ExitStatus = 0;
    if not Result then ErrorText := ProgramName + ' failed. Open the compiler log for details.';
  finally
    try
      if Captured<>nil then LogText:=Captured.Text;
      if CommandOutput<>nil then FCommandOutput:=CommandOutput.Text;
    finally Captured.Free; CommandOutput.Free; P.Free; end;
  end;
end;

function TRenderThread.CompileSnapshot(const Prefix:string):Boolean;
var Pass,Minimum:Integer; BeforeAux,AfterAux,ScriptPath,Location,Marker:string; Lines,Args,Values:TStringList; HasBibliography:Boolean; Hook,Preparation:TJSONObject; HookParameters:array of string; HookIndex,ParameterIndex,Position:Integer; Packages:TPreambleModel;
  function Compile:Boolean;
  var Parameters:array of string; I,Number:Integer;
  begin
    Values.Values['source']:=Prefix+'preview.tex'; Values.Values['output']:=WorkDir;
    Values.Values['directory']:=FDirectory; Values.Values['engine']:=FEngine;
    Args.Text:=FCompilerArguments;
    if SyncTeX then begin
      for I:=Args.Count-1 downto 0 do
        if (Pos('-synctex=',Args[I])=1) or (Pos('--synctex=',Args[I])=1) then Args.Delete(I)
        else if (Args[I]='-synctex') or (Args[I]='--synctex') then begin
          if (I+1<Args.Count) and TryStrToInt(Args[I+1],Number) then Args.Delete(I+1);
          Args.Delete(I);
        end;
      Args.Insert(0,'-synctex=1');
    end;
    for I:=0 to Args.Count-1 do Args[I]:=ExpandToolText(Args[I],Values);
    SetLength(Parameters,Args.Count); for I:=0 to Args.Count-1 do Parameters[I]:=Args[I];
    Result:=Run(ExpandToolText(FCompiler,Values),Parameters);
  end;
  function Auxiliary:string;
  const Extensions:array[0..3] of string=('aux','toc','out','bcf');
  var Extension:string;
  begin
    Result:='';
    for Extension in Extensions do if FileExists(Prefix+'preview.'+Extension) then begin
      Lines.LoadFromFile(Prefix+'preview.'+Extension); Result:=Result+Extension+#0+Lines.Text;
    end;
  end;
begin
  Result:=False; Lines:=TStringList.Create; Args:=TStringList.Create; Values:=TStringList.Create;
  try
    Minimum:=Max(1,RenderPasses); BeforeAux:='';
    Packages:=TPreambleModel.Create;
    try
      Packages.Load(Copy(FSource,1,TeXHeaderLength(FSource)));
      for HookIndex:=0 to FCompileSteps.Count-1 do begin
        Hook:=FCompileSteps.Objects[HookIndex]; if not (Hook.Find('prepare') is TJSONObject) then Continue;
        Preparation:=Hook.Objects['prepare'];
        if Packages.PackageIndex(Preparation.Get('package',''))<0 then Continue;
        if FileExists(IncludeTrailingPathDelimiter(Hook.Get('texInputs',''))+Preparation.Get('styleFile','')) then Continue;
        ScriptPath:=Prefix+'plugin-prepare-'+IntToStr(HookIndex)+'.py';
        Lines.Text:=Preparation.Get('script',''); Lines.SaveToFile(ScriptPath);
        if not Run(Hook.Get('executable',''),[ScriptPath],WorkDir,300000) then Exit;
        Marker:=Preparation.Get('marker',''); Position:=Pos(Marker,FCommandOutput);
        if (Marker='') or (Position=0) then begin ErrorText:='The plug-in could not locate its TeX package files.'; Exit; end;
        Location:=Copy(FCommandOutput,Position+Length(Marker),MaxInt); Position:=Pos(#10,Location); if Position>0 then SetLength(Location,Position-1); Location:=Trim(Location);
        if not FileExists(IncludeTrailingPathDelimiter(Location)+Preparation.Get('styleFile','')) then begin ErrorText:='The plug-in reported an unavailable package directory: '+Location; Exit; end;
        Hook.Strings['texInputs']:=Location; CacheExtensionPath(Hook.Get('pluginID',''),Hook.Get('executable',''),Location);
      end;
    finally Packages.Free; end;
    for Pass:=1 to Max(4,Minimum) do begin
      if not Compile then Exit;
      AfterAux:=Auxiliary;
      if Pass=1 then begin
        Values.Values['output']:=WorkDir;
        for HookIndex:=0 to FCompileSteps.Count-1 do begin
          Hook:=FCompileSteps.Objects[HookIndex];
          if not FileExists(ExpandToolText(Hook.Get('when',''),Values)) then Continue;
          Args.Clear;
          for ParameterIndex:=0 to Hook.Arrays['arguments'].Count-1 do Args.Add(ExpandToolText(Hook.Arrays['arguments'].Strings[ParameterIndex],Values));
          SetLength(HookParameters,Args.Count); for ParameterIndex:=0 to Args.Count-1 do HookParameters[ParameterIndex]:=Args[ParameterIndex];
          if not Run(Hook.Get('executable',''),HookParameters,ExpandToolText(Hook.Get('directory',WorkDir),Values),EnsureRange(Hook.Get('timeoutMS',60000),1000,600000)) then Exit;
          Minimum:=Max(Minimum,Hook.Get('passes',2));
        end;
        HasBibliography:=FileExists(Prefix+'preview.bcf') or (Pos('\bibdata{',AfterAux)>0);
        if HasBibliography then begin
          if FileExists(Prefix+'preview.bcf') then begin
            if not Run('biber',['--input-directory='+WorkDir,'--output-directory='+WorkDir,'preview']) then Exit;
          end else if not Run('bibtex',['preview'],WorkDir) then Exit;
          Minimum:=Max(Minimum,3);
        end;
      end;
      if (Pass>=Minimum) and ((Pass=1) or (AfterAux=BeforeAux)) then begin
        if FileExists(Prefix+'preview.bbl') then begin Lines.LoadFromFile(Prefix+'preview.bbl'); BibliographySource:=Lines.Text; end;
        Exit(True);
      end;
      BeforeAux:=AfterAux;
    end;
    if FileExists(Prefix+'preview.bbl') then begin Lines.LoadFromFile(Prefix+'preview.bbl'); BibliographySource:=Lines.Text; end;
    Result:=True;
  finally Values.Free; Args.Free; Lines.Free; end;
end;

procedure TRenderThread.ExtractLayout(const Prefix:string);
var SavedError:string; S:TStringList; F:TFormatSettings;
begin
  SavedError:=ErrorText; S:=TStringList.Create;
  F:=DefaultFormatSettings; F.DecimalSeparator:='.';
  try
    try
      if FileExists(Prefix+'preview.pstpos') then
      begin S.LoadFromFile(Prefix+'preview.pstpos'); Positions:=S.Text; end;
      if Run('pdftohtml',['-xml','-hidden','-nomerge','-noroundcoord','-fontfullname','-i',
        '-zoom',FloatToStr(DPI/72,F),Prefix+'preview.pdf',Prefix+'layout.xml']) and
        FileExists(Prefix+'layout.xml') then
      begin S.LoadFromFile(Prefix+'layout.xml'); LayoutXML:=S.Text; end;
    except { Font/layout extraction is optional; keep a usable preview. } end;
  finally ErrorText:=SavedError; S.Free; end;
end;

procedure TRenderThread.Execute;
var
  S: TStringList;
  G: TGUID;
  Entry: TSearchRec;
  I, J, N: Integer;
  Name, Prefix: string; Compiled:Boolean;
begin
  try
    CreateGUID(G);
    WorkDir := IncludeTrailingPathDelimiter(GetTempDir(False)) + 'pastex-' + Copy(GUIDToString(G),2,36);
    if not ForceDirectories(WorkDir) then raise Exception.Create('Cannot create preview directory.');
    Prefix := WorkDir + DirectorySeparator;
    S := TStringList.Create;
    try
      S.Text := FSource;
      S.SaveToFile(Prefix + 'preview.tex');
    finally
      S.Free;
    end;
    Compiled:=CompileSnapshot(Prefix);
    if not Compiled and (FallbackSource<>'') and not Terminated then
    begin
      DeleteFile(Prefix+'preview.pstpos');
      S:=TStringList.Create;
      try S.Text:=FallbackSource; S.SaveToFile(Prefix+'preview.tex'); finally S.Free; end;
      ErrorText:=''; Compiled:=CompileSnapshot(Prefix);
    end;
    if not Compiled or PDFOnly then Exit;
    if PageLayoutOnly then begin ExtractLayout(Prefix); Exit; end;
    if PreviewPage>0 then
    begin
      if not Run('pdftoppm', ['-png', '-r', IntToStr(DPI), '-f',IntToStr(PreviewPage),
        '-l',IntToStr(PreviewPage),'-singlefile',Prefix+'preview.pdf',Prefix+'page']) then Exit;
      if FileExists(Prefix+'page.png') then begin Images.Add(Prefix+'page.png'); ExtractLayout(Prefix); end
      else ErrorText:='LaTeX produced no image for this paragraph.';
      Exit;
    end;
    if not Run('pdftoppm', ['-png', '-r', IntToStr(DPI), Prefix + 'preview.pdf', Prefix + 'page']) then Exit;
    if FindFirst(Prefix + 'page-*.png', faAnyFile, Entry) = 0 then
    begin
      repeat
        Name := ChangeFileExt(Entry.Name, '');
        N := StrToIntDef(Copy(Name, 6, MaxInt), 0);
        if N > 0 then
        begin
          while Images.Count < N do Images.Add('');
          Images[N - 1] := Prefix + Entry.Name;
        end;
      until FindNext(Entry) <> 0;
      FindClose(Entry);
    end;
    if Images.Count = 0 then ErrorText := 'LaTeX produced no preview pages.';
    for J := 0 to Images.Count - 1 do
      if Images[J] = '' then ErrorText := 'LaTeX produced an incomplete preview.';
    if ErrorText='' then ExtractLayout(Prefix);
  except
    on E: Exception do ErrorText := E.Message;
  end;
end;

end.
