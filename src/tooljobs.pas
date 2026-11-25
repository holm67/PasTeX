unit ToolJobs;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Process, Contnrs;
type
  TToolStep=class
    Executable,Directory:string;
    Arguments,Environment:TStringList;
    constructor Create(const ProgramName,WorkingDirectory:string; const Args:array of string);
    destructor Destroy; override;
  end;
  TToolJob=class(TThread)
  protected
    procedure Execute; override;
  public
    Steps:TObjectList;
    Output,ErrorText:string;
    TimeoutMS:QWord;
    constructor Create;
    destructor Destroy; override;
    procedure Add(const ProgramName,Directory:string; const Args:array of string);
  end;
function FindTool(const Name:string):string;
function ExpandToolText(const Text:string; Values:TStrings):string;
procedure ExpandToolArgs(Lines,Values,Dest:TStrings);
procedure CompilerProfile(const Engine:string; out Executable,Arguments:string);
function CompilerPath(const Engine,Directory:string):string;
function CompilerAvailable(const Engine,Directory:string):Boolean;
function ExtensionBuildEnabled:Boolean;
function DefaultCompilerArguments:string;
implementation
uses IniFiles, StrUtils, FPHTTPClient, ManagedProcess;
type TBoundedToolStream=class(TMemoryStream)
  function Write(const Buffer; Count:LongInt):LongInt; override;
end;
function TBoundedToolStream.Write(const Buffer; Count:LongInt):LongInt;
begin
  if Position+Count>262144 then raise Exception.Create('HTTP response exceeds 256 KB');
  Result:=inherited Write(Buffer,Count);
end;
function FindTool(const Name:string):string;
var Candidate:string; Ini:TIniFile;
begin
  Result:=''; if Trim(Name)='' then Exit;
  Candidate:=Name;
  if ExtractFilePath(Name)='' then begin
    Ini:=TIniFile.Create(GetAppConfigFile(False)); try Candidate:=Ini.ReadString('Tools',Name,Name); finally Ini.Free; end;
  end;
  if FileExists(Candidate) then Exit(ExpandFileName(Candidate));
  Result:=ExeSearch(Candidate,GetEnvironmentVariable('PATH'));
  {$IFDEF MSWINDOWS}if (Result='') and (ExtractFileExt(Candidate)='') then Result:=ExeSearch(Candidate+'.exe',GetEnvironmentVariable('PATH'));{$ENDIF}
end;
function ExpandToolText(const Text:string; Values:TStrings):string;
var I,J,K:Integer; Key:string;
begin
  { Expand placeholders once, never rescan substituted user text. }
  I:=1; Result:='';
  while I<=Length(Text) do begin
    if Text[I]='{' then begin
      J:=PosEx('}',Text,I+1);
      if J>0 then begin
        Key:=Copy(Text,I+1,J-I-1); K:=Values.IndexOfName(Key);
        if K>=0 then begin Result:=Result+Values.ValueFromIndex[K]; I:=J+1; Continue; end;
      end;
    end;
    Result:=Result+Text[I]; Inc(I);
  end;
end;
procedure ExpandToolArgs(Lines,Values,Dest:TStrings);
var I:Integer;
begin Dest.Clear; for I:=0 to Lines.Count-1 do if Lines[I]<>'' then Dest.Add(ExpandToolText(Lines[I],Values)); end;
function DefaultCompilerArguments:string;
begin Result:='-no-shell-escape'+#10+'-recorder'+#10+'-synctex=1'+#10+'-interaction=nonstopmode'+#10+
  '-halt-on-error'+#10+'-file-line-error'+#10+'-output-directory={output}'+#10+'{source}'; end;
procedure CompilerProfile(const Engine:string; out Executable,Arguments:string);
var Ini:TIniFile; I,Count:Integer;
begin
  Ini:=TIniFile.Create(GetAppConfigFile(False));
  try Executable:=Ini.ReadString('Compiler.'+Engine,'Executable',Engine);
    Arguments:=''; Count:=Ini.ReadInteger('Compiler.'+Engine,'ArgumentCount',-1);
    if Count<0 then Arguments:=DefaultCompilerArguments
    else for I:=0 to Count-1 do begin
      if I>0 then Arguments:=Arguments+#10;
      Arguments:=Arguments+Ini.ReadString('Compiler.'+Engine,'Argument'+IntToStr(I),'');
    end;
  finally Ini.Free; end;
end;
function CompilerPath(const Engine,Directory:string):string;
var Executable,Arguments:string; Values:TStringList;
begin
  CompilerProfile(Engine,Executable,Arguments); Values:=TStringList.Create;
  try
    Values.Values['engine']:=Engine; Values.Values['directory']:=Directory;
    Executable:=ExpandToolText(Executable,Values);
    Result:=FindTool(Executable);
    if (Result='') and not IsPathDelimiter(Executable,1) and (ExtractFileDrive(Executable)='') and
      (ExtractFilePath(Executable)<>'') and FileExists(IncludeTrailingPathDelimiter(Directory)+Executable) then
      Result:=ExpandFileName(IncludeTrailingPathDelimiter(Directory)+Executable);
  finally Values.Free; end;
end;
function CompilerAvailable(const Engine,Directory:string):Boolean;
begin Result:=CompilerPath(Engine,Directory)<>''; end;
function ExtensionBuildEnabled:Boolean;
var Ini:TIniFile;
begin Ini:=TIniFile.Create(GetAppConfigFile(False)); try Result:=Ini.ReadBool('Compiler','ExtensionSteps',True); finally Ini.Free; end; end;
constructor TToolStep.Create(const ProgramName,WorkingDirectory:string; const Args:array of string);
var S:string;
begin inherited Create; Executable:=ProgramName; Directory:=WorkingDirectory; Arguments:=TStringList.Create; Environment:=TStringList.Create;
  for S in Args do Arguments.Add(S); end;
destructor TToolStep.Destroy;
begin Environment.Free; Arguments.Free; inherited; end;
constructor TToolJob.Create;
begin inherited Create(True); FreeOnTerminate:=False; TimeoutMS:=120000; Steps:=TObjectList.Create(True); end;
destructor TToolJob.Destroy;
begin
  if not Finished then begin Terminate; if Suspended then Start; WaitFor; end;
  Steps.Free; inherited;
end;
procedure TToolJob.Add(const ProgramName,Directory:string; const Args:array of string);
begin Steps.Add(TToolStep.Create(ProgramName,Directory,Args)); end;
procedure TToolJob.Execute;
var P:TManagedProcess; Step:TToolStep; I,J,N:Integer; Buffer:array[0..8191] of Byte; Started:QWord;
    HTTP:TFPHTTPClient; Response:TBoundedToolStream; Captured:TProcessOutput;
begin
  try
    for I:=0 to Steps.Count-1 do begin
      if Terminated then raise Exception.Create('Cancelled'); Step:=TToolStep(Steps[I]);
      if Step.Executable='http:get' then begin
        if Step.Arguments.Count<>1 then raise Exception.Create('HTTP tools require one URL argument');
        HTTP:=TFPHTTPClient.Create(nil); Response:=TBoundedToolStream.Create;
        try HTTP.ConnectTimeout:=3000; HTTP.IOTimeout:=3000; HTTP.Get(Step.Arguments[0],Response);
          SetLength(Output,Response.Size); Response.Position:=0; if Output<>'' then Response.ReadBuffer(Output[1],Length(Output));
        finally Response.Free; HTTP.Free; end;
        Continue;
      end;
      if FindTool(Step.Executable)='' then raise Exception.Create('Tool not found: '+Step.Executable+'. Set its executable in Add-ons or install it.');
      P:=TManagedProcess.Create(nil); Captured:=nil;
      try
        Captured:=TProcessOutput.Create(262144,Output);
        P.Executable:=FindTool(Step.Executable); P.Parameters.Assign(Step.Arguments); P.CurrentDirectory:=Step.Directory;
        if Step.Environment.Count>0 then begin
          for J:=1 to GetEnvironmentVariableCount do P.Environment.Add(GetEnvironmentString(J));
          for J:=0 to Step.Environment.Count-1 do P.Environment.Values[Step.Environment.Names[J]]:=Step.Environment.ValueFromIndex[J];
        end;
        P.Options:=[poUsePipes,poStderrToOutPut,poNoConsole]; P.Execute; Started:=GetTickCount64;
        repeat
          if Terminated or (GetTickCount64-Started>TimeoutMS) then begin P.Cancel; raise Exception.Create('Cancelled or timed out'); end;
          if P.Output.NumBytesAvailable>0 then begin
            N:=P.Output.Read(Buffer,SizeOf(Buffer)); Captured.Append(Buffer,N); Continue;
          end;
          if not P.Running and (P.Output.NumBytesAvailable=0) then Break;
          Sleep(10);
        until False;
        if P.ExitStatus<>0 then raise Exception.Create(Step.Executable+' exited with code '+IntToStr(P.ExitCode));
      finally
        try if Captured<>nil then Output:=Captured.Text;
        finally Captured.Free; P.Free; end;
      end;
    end;
  except on E:Exception do ErrorText:=E.Message; end;
end;
end.
