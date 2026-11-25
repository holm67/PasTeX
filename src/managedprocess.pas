unit ManagedProcess;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Process;
type
  TProcessOutput=class
  private
    FBuffer:RawByteString;
    FStart,FCount:SizeInt;
  public
    constructor Create(Capacity:SizeInt; const Initial:string='');
    procedure Append(const Buffer; Count:SizeInt);
    function Text:string;
  end;
  TManagedProcess=class(TProcess)
  private
    procedure AfterFork(Sender:TObject);
  public
    constructor Create(AOwner:TComponent); override;
    procedure Cancel;
  end;
implementation
uses SysUtils {$IFDEF UNIX}, BaseUnix{$ENDIF};
constructor TProcessOutput.Create(Capacity:SizeInt; const Initial:string);
begin
  inherited Create;
  if Capacity<=0 then raise ERangeError.Create('Output capacity must be positive');
  SetLength(FBuffer,Capacity);
  if Initial<>'' then Append(Initial[1],Length(Initial));
end;
procedure TProcessOutput.Append(const Buffer; Count:SizeInt);
var Capacity,Index,First,Discard:SizeInt; Data:PByte;
begin
  if Count<=0 then Exit;
  Capacity:=Length(FBuffer); Data:=@Buffer;
  if Count>=Capacity then begin
    Inc(Data,Count-Capacity); Move(Data^,FBuffer[1],Capacity);
    FStart:=0; FCount:=Capacity; Exit;
  end;
  Discard:=FCount+Count-Capacity;
  if Discard>0 then begin FStart:=(FStart+Discard) mod Capacity; Dec(FCount,Discard); end;
  Index:=(FStart+FCount) mod Capacity; First:=Count;
  if First>Capacity-Index then First:=Capacity-Index;
  Move(Data^,FBuffer[Index+1],First);
  if First<Count then begin Inc(Data,First); Move(Data^,FBuffer[1],Count-First); end;
  Inc(FCount,Count);
end;
function TProcessOutput.Text:string;
var Skip,First,Capacity:SizeInt;
begin
  Capacity:=Length(FBuffer); Skip:=0;
  { Trimming a UTF-8 tail keeps the first complete character. }
  while (Skip<FCount) and ((Ord(FBuffer[(FStart+Skip) mod Capacity+1]) and $C0)=$80) do Inc(Skip);
  SetLength(Result,FCount-Skip); if Result='' then Exit;
  First:=Capacity-(FStart+Skip) mod Capacity;
  if First>Length(Result) then First:=Length(Result);
  Move(FBuffer[(FStart+Skip) mod Capacity+1],Result[1],First);
  if First<Length(Result) then Move(FBuffer[1],Result[First+1],Length(Result)-First);
end;
constructor TManagedProcess.Create(AOwner:TComponent);
begin
  inherited;
  {$IFDEF UNIX}OnForkEvent:=@AfterFork;{$ENDIF}
end;
procedure TManagedProcess.AfterFork(Sender:TObject);
begin
  {$IFDEF UNIX}if fpSetSid<0 then fpExit(127);{$ENDIF}
end;
procedure TManagedProcess.Cancel;
{$IFDEF MSWINDOWS}var Killer:TProcess;{$ENDIF}
begin
  if ProcessID<=0 then Exit;
  {$IFDEF UNIX}
  { Cancel descendants of wrappers such as mamba as well as the launcher. }
  fpKill(-ProcessID,SIGKILL);
  {$ENDIF}
  {$IFDEF MSWINDOWS}
  Killer:=TProcess.Create(nil);
  try
    Killer.Executable:=IncludeTrailingPathDelimiter(GetEnvironmentVariable('SystemRoot'))+'System32\taskkill.exe';
    Killer.Parameters.Add('/PID'); Killer.Parameters.Add(IntToStr(ProcessID)); Killer.Parameters.Add('/T'); Killer.Parameters.Add('/F');
    Killer.Options:=[poWaitOnExit,poNoConsole];
    try Killer.Execute; except { Fall back to the parent if taskkill is unavailable. } end;
  finally Killer.Free; end;
  {$ENDIF}
  if Running then Terminate(1); WaitOnExit;
end;
end.
