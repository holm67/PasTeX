unit LinkedSource;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, TeXProject, SourceBuffers, SourceRanges;
type
  { The editing buffer expands body inputs; file buffers retain the original
    input commands. No generated markers are written into a user's files. }
  TLinkedSource=class
  private
    FFiles,FOriginal:TSourceBuffers;
    FStack,FCached,FCollapsed:TStringList;
    FRoot,FText,FHeader,FTextKey,FEngine:string;
    FProject:TTeXProject;
    FSpans:array of record
      Path:string;
      Parent,First,BodyFirst,BodyAfter,After,FileFirst,CommandFirst,CommandAfter:Integer;
    end;
    FHistory:array of record
      BeforeKey,AfterKey,Path,Before,After:string;
      Offset:Integer;
    end;
    FHistoryAt:Integer;
    FActive:Boolean;
    FBytes:SizeInt;
    function ReadFile(const Path:string):string;
    procedure Rebuild;
    procedure HistoryEdit(Index:Integer; Forward:Boolean);
    function FileOffset(Span,Offset:Integer):Integer;
  public
    Warning:string;
    constructor Create;
    destructor Destroy; override;
    procedure Load(const Source,Path:string; Project:TTeXProject);
    function Apply(const Value:string; out Error:string):Boolean;
    procedure SetExpanded(Value:Boolean);
    function FileExpanded(const Path:string):Boolean;
    procedure ToggleFile(const Path:string);
    function CollapsedRanges:TSourceRanges;
    procedure Refresh(Project:TTeXProject);
    function FileSource(const Path:string):string;
    function OriginalSource(const Path:string):string;
    function FileAt(Offset:Integer; out LocalOffset:Integer):string;
    function FilePosition(const Path:string):Integer;
    function ViewOffset(const Path:string; Offset:Integer):Integer;
    function Boundaries:TSourceBoundaries;
    procedure Sources(Project:TTeXProject);
    procedure ChangedFiles(Files:TStrings);
    procedure Save(const RootPath:string);
    property Text:string read FText;
    property Root:string read FRoot;
    property Expanded:Boolean read FActive;
    property Engine:string read FEngine;
    property Files:TSourceBuffers read FFiles;
  end;
implementation
uses Math, MD5, TeXDocument, AtomicFiles, TeXMacros;
type TLinkedInputs=class
  Inputs:TTeXInputs;
  Context,Preamble,Engine:string;
  First,After,Mode:Integer;
  Revision:QWord;
  Ready:Boolean;
end;
function DiskSource(const Path:string):string;
var Stream:TFileStream;
begin
  Result:=''; if not FileExists(Path) then Exit;
  Stream:=TFileStream.Create(Path,fmOpenRead or fmShareDenyNone);
  try SetLength(Result,Stream.Size); if Result<>'' then Stream.ReadBuffer(Result[1],Length(Result));
  finally Stream.Free; end;
end;
constructor TLinkedSource.Create;
begin
  inherited Create;
  FFiles:=TSourceBuffers.Create; FOriginal:=TSourceBuffers.Create; FStack:=TStringList.Create;
  FCached:=TStringList.Create; FCached.OwnsObjects:=True; FCached.Sorted:=True;
  FCollapsed:=TStringList.Create; FCollapsed.Sorted:=True;
  {$IFDEF UNIX}FStack.CaseSensitive:=True; FCached.CaseSensitive:=True; FCollapsed.CaseSensitive:=True;{$ENDIF}
end;
destructor TLinkedSource.Destroy;
begin
  FCollapsed.Free; FCached.Free; FStack.Free; FOriginal.Free; FFiles.Free; inherited;
end;
function TLinkedSource.ReadFile(const Path:string):string;
var I:Integer; Stream:TFileStream;
begin
  I:=FFiles.IndexOf(Path); if I>=0 then Exit(FFiles.ValueFromIndex[I]);
  Result:='';
  if FProject<>nil then begin
    if not FProject.HasSource(Path) then Exit;
    if FileExists(Path) then begin
      Stream:=TFileStream.Create(Path,fmOpenRead or fmShareDenyNone);
      try if Stream.Size>8*1024*1024 then raise Exception.Create('Subfile exceeds 8 MiB: '+Path);
      finally Stream.Free; end;
    end;
    Result:=FProject.ReadSource(Path);
  end
  else if FileExists(Path) then begin
    Stream:=TFileStream.Create(Path,fmOpenRead or fmShareDenyNone);
    try
      if Stream.Size>8*1024*1024 then raise Exception.Create('Subfile exceeds 8 MiB: '+Path);
      SetLength(Result,Stream.Size); if Result<>'' then Stream.ReadBuffer(Result[1],Length(Result));
    finally Stream.Free; end;
  end else Exit;
  if Length(Result)>8*1024*1024 then raise Exception.Create('Subfile exceeds 8 MiB: '+Path);
  FFiles[Path]:=Result; FOriginal[Path]:=DiskSource(Path);
end;
procedure TLinkedSource.Load(const Source,Path:string; Project:TTeXProject);
begin
  FFiles.Clear; FOriginal.Clear; FCached.Clear; FCollapsed.Clear; FHistory:=nil; FHistoryAt:=0;
  FRoot:=ExpandFileName(Path); FFiles[FRoot]:=Source; FOriginal[FRoot]:=DiskSource(FRoot);
  FEngine:='pdflatex'; if Project<>nil then FEngine:=Project.Engine;
  FProject:=Project; FActive:=True;
  try Rebuild; finally FProject:=nil; end;
end;
procedure TLinkedSource.Rebuild;
var Buffer:TMemoryStream;
  function InputsFor(const Path,Source:string; Mode:Integer):TLinkedInputs;
  var I,Base:Integer; FileBuffer:TSourceBuffer; Doc:TTeXDocument;
  begin
    I:=FCached.IndexOf(Path);
    if I<0 then begin Result:=TLinkedInputs.Create; FCached.AddObject(Path,Result); end
    else Result:=TLinkedInputs(FCached.Objects[I]);
    FileBuffer:=FFiles.Buffer(FFiles.IndexOf(Path));
    if Result.Ready and (Result.Revision=FileBuffer.Revision) and (Result.Mode=Mode) and (Result.Engine=FEngine) and
      ((Mode=1) or (Result.Context=FHeader)) then begin
      if Mode=1 then FHeader:=Result.Preamble;
      Exit;
    end;
    Result.First:=0; Result.After:=Length(Source); Base:=0;
    if Mode<>0 then begin
      Doc:=TTeXDocument.Create;
      try
        Doc.Parse(Source); Base:=Length(Doc.Preamble); Result.Preamble:=Doc.Preamble;
        if Mode=1 then FHeader:=Doc.Preamble
        else if Base>0 then begin Result.First:=Base; Result.After:=Length(Source)-Length(Doc.Ending); end;
      finally Doc.Free; end;
    end;
    Result.Inputs:=DocumentInputs(Copy(Source,Base+1,Result.After-Base),Path,FHeader,FEngine);
    for I:=0 to High(Result.Inputs) do begin Inc(Result.Inputs[I].First,Base); Inc(Result.Inputs[I].After,Base); end;
    Result.Context:=FHeader; Result.Engine:=FEngine; Result.Mode:=Mode; Result.Revision:=FileBuffer.Revision; Result.Ready:=True;
  end;
  procedure Append(const Value:string);
  begin if Value<>'' then Buffer.WriteBuffer(Value[1],Length(Value)); end;
  procedure Expand(const Path:string; Parent,CommandFirst,CommandAfter:Integer; IsSubfile,IncludeBreak,ControlSpace:Boolean);
  var Source:string; Inputs:TLinkedInputs; Link:TTeXInput;
      N,A,B,P,Mode:Integer;
  begin
    Source:=ReadFile(Path); Mode:=0; if Parent<0 then Mode:=1 else if IsSubfile then Mode:=2;
    Inputs:=InputsFor(Path,Source,Mode); A:=Inputs.First; B:=Inputs.After;
    N:=Length(FSpans); SetLength(FSpans,N+1);
    FSpans[N].Path:=Path; FSpans[N].Parent:=Parent; FSpans[N].First:=Buffer.Position;
    FSpans[N].CommandFirst:=CommandFirst; FSpans[N].CommandAfter:=CommandAfter;
    if IncludeBreak then Append('\clearpage'+LineEnding);
    if ControlSpace and not IncludeBreak then Append(' ');
    FSpans[N].FileFirst:=A; FSpans[N].BodyFirst:=Buffer.Position;
    FStack.Add(Path); P:=A;
    try
      for Link in Inputs.Inputs do begin
        if not Link.Included or (Link.Path='') then Continue;
        if FBytes>8*1024*1024 then begin Warning:='Expanded project exceeds 8 MiB'; Break; end;
        if FStack.IndexOf(Link.Path)>=0 then begin Warning:='Recursive subfile: '+Link.Path; Continue; end;
        if FStack.Count>32 then begin Warning:='Subfile nesting exceeds 32 levels'; Continue; end;
        if not FileExists(Link.Path) and ((FProject=nil) and (FFiles.IndexOf(Link.Path)<0)) then begin
          Warning:='Cannot read subfile: '+Link.Path; Continue;
        end;
        { Cache before recursing, so empty unsaved files remain editable. }
        try Inc(FBytes,Length(ReadFile(Link.Path)));
        except on E:Exception do begin Warning:=E.Message; Continue; end; end;
        if (FFiles.IndexOf(Link.Path)<0) then begin Warning:='Cannot read subfile: '+Link.Path; Continue; end;
        { Keep an empty file as an input target: a zero-length expansion
          would steal the caret at the start of the following master text. }
        if FileSource(Link.Path)='' then Continue;
        if FBytes>8*1024*1024 then begin Warning:='Expanded project exceeds 8 MiB'; Break; end;
        Append(Copy(Source,P+1,Link.First-P));
        Expand(Link.Path,N,Link.First,Link.After,Link.Subfile,Link.ClearPage,
          InputNeedsSpace(Source,Link.First)); P:=Link.After;
      end;
      Append(Copy(Source,P+1,B-P));
    finally FStack.Delete(FStack.Count-1); end;
    FSpans[N].BodyAfter:=Buffer.Position;
    { TeX terminates the final input line even when the file has no final LF. }
    if (Parent>=0) and (B>A) and not (Source[B] in [#10,#13]) then Append(LineEnding);
    if IncludeBreak then Append('\clearpage'+LineEnding);
    FSpans[N].After:=Buffer.Position;
  end;
begin
  Warning:=''; FTextKey:=''; FSpans:=nil; FStack.Clear; FBytes:=Length(FileSource(FRoot));
  if not FActive then begin FText:=FileSource(FRoot); Exit; end;
  Buffer:=TMemoryStream.Create;
  try
    Expand(FRoot,-1,0,0,False,False,False); SetLength(FText,Buffer.Size);
    if FText<>'' then Move(Buffer.Memory^,FText[1],Length(FText));
  finally Buffer.Free; end;
end;
procedure TLinkedSource.HistoryEdit(Index:Integer; Forward:Boolean);
var Source,OldText,NewText:string; P:Integer;
begin
  Source:=FileSource(FHistory[Index].Path); P:=FHistory[Index].Offset;
  if Forward then begin OldText:=FHistory[Index].Before; NewText:=FHistory[Index].After; end
  else begin OldText:=FHistory[Index].After; NewText:=FHistory[Index].Before; end;
  FFiles[FHistory[Index].Path]:=Copy(Source,1,P)+NewText+Copy(Source,P+Length(OldText)+1,MaxInt);
end;
function TLinkedSource.FileOffset(Span,Offset:Integer):Integer;
var I:Integer;
begin
  Result:=FSpans[Span].FileFirst+Offset-FSpans[Span].BodyFirst;
  for I:=Span+1 to High(FSpans) do if (FSpans[I].Parent=Span) and (FSpans[I].After<=Offset) then
    Inc(Result,FSpans[I].CommandAfter-FSpans[I].CommandFirst-FSpans[I].After+FSpans[I].First);
end;
function TLinkedSource.Apply(const Value:string; out Error:string):Boolean;
var A,B,C,I,Owner,P,Q,Target:Integer; Key,Source:string;
begin
  Result:=True; Error:=''; if Value=FText then Exit;
  if not FActive then begin FFiles[FRoot]:=Value; FText:=Value; FTextKey:=''; Exit; end;
  Key:=MD5Print(MD5String(Value));
  Target:=-1;
  for I:=High(FHistory) downto 0 do begin
    if FHistory[I].AfterKey=Key then begin Target:=I+1; Break; end;
    if FHistory[I].BeforeKey=Key then begin Target:=I; Break; end;
  end;
  if Target>=0 then begin
    while FHistoryAt>Target do begin Dec(FHistoryAt); HistoryEdit(FHistoryAt,False); end;
    while FHistoryAt<Target do begin HistoryEdit(FHistoryAt,True); Inc(FHistoryAt); end;
    Rebuild; if FText=Value then FTextKey:=Key; Exit;
  end;
  SourceDifference(FText,Value,A,B,C);
  Owner:=0;
  for I:=1 to High(FSpans) do
    if (A>=FSpans[I].BodyFirst) and (B<=FSpans[I].BodyAfter) then Owner:=I;
  for I:=Owner+1 to High(FSpans) do if (FSpans[I].Parent=Owner) and
    (A<FSpans[I].After) and (B>FSpans[I].First) then begin
    Error:='Edit one source file at a time. Turn off Subfiles in place to edit the input commands.';
    Exit(False);
  end;
  P:=FileOffset(Owner,A); Q:=FileOffset(Owner,B); Source:=FileSource(FSpans[Owner].Path);
  { Store edit deltas, not a copy of every linked file for each keystroke. }
  if FHistoryAt=100 then begin
    for I:=1 to High(FHistory) do FHistory[I-1]:=FHistory[I]; Dec(FHistoryAt);
  end;
  SetLength(FHistory,FHistoryAt+1);
  if FTextKey='' then FTextKey:=MD5Print(MD5String(FText));
  FHistory[FHistoryAt].BeforeKey:=FTextKey;
  FHistory[FHistoryAt].Path:=FSpans[Owner].Path; FHistory[FHistoryAt].Offset:=P;
  FHistory[FHistoryAt].Before:=Copy(Source,P+1,Q-P); FHistory[FHistoryAt].After:=Copy(Value,A+1,C-A);
  HistoryEdit(FHistoryAt,True); Rebuild;
  if FText=Value then FTextKey:=Key else FTextKey:=MD5Print(MD5String(FText));
  FHistory[FHistoryAt].AfterKey:=FTextKey; Inc(FHistoryAt);
end;
procedure TLinkedSource.SetExpanded(Value:Boolean);
begin FActive:=Value; FHistory:=nil; FHistoryAt:=0; Rebuild; end;
function TLinkedSource.FileExpanded(const Path:string):Boolean;
begin Result:=FCollapsed.IndexOf(Path)<0; end;
procedure TLinkedSource.ToggleFile(const Path:string);
var I:Integer;
begin
  I:=FCollapsed.IndexOf(Path);
  if I>=0 then FCollapsed.Delete(I) else FCollapsed.Add(Path);
end;
function TLinkedSource.CollapsedRanges:TSourceRanges;
var I,N:Integer;
begin
  Result:=nil; if not FActive then Exit;
  for I:=1 to High(FSpans) do if not FileExpanded(FSpans[I].Path) then begin
    N:=Length(Result);
    if (N>0) and (FSpans[I].First<Result[N-1].Finish) then Continue;
    SetLength(Result,N+1); Result[N].Start:=FSpans[I].First; Result[N].Finish:=FSpans[I].After;
  end;
end;
procedure TLinkedSource.Refresh(Project:TTeXProject);
var I:Integer; Path,Value:string;
begin
  if FEngine<>Project.Engine then begin FEngine:=Project.Engine; FHistory:=nil; FHistoryAt:=0; end;
  for I:=0 to FFiles.Count-1 do begin
    Path:=FFiles.Names[I]; if Path=FRoot then Continue;
    if (FileSource(Path)<>OriginalSource(Path)) or not Project.HasSource(Path) then Continue;
    Value:=Project.ReadSource(Path);
    if Value<>FileSource(Path) then begin FFiles[Path]:=Value; FHistory:=nil; FHistoryAt:=0; end;
  end;
  FProject:=Project; try Rebuild; finally FProject:=nil; end;
end;
function TLinkedSource.FileSource(const Path:string):string;
begin Result:=FFiles.Values[ExpandFileName(Path)]; end;
function TLinkedSource.OriginalSource(const Path:string):string;
begin Result:=FOriginal.Values[ExpandFileName(Path)]; end;
function TLinkedSource.FileAt(Offset:Integer; out LocalOffset:Integer):string;
var I,Owner:Integer;
begin
  Result:=FRoot; LocalOffset:=Offset; if not FActive then Exit;
  Owner:=0;
  for I:=1 to High(FSpans) do if (Offset>=FSpans[I].BodyFirst) and (Offset<=FSpans[I].BodyAfter) then Owner:=I;
  Result:=FSpans[Owner].Path; LocalOffset:=FileOffset(Owner,Offset);
end;
function TLinkedSource.FilePosition(const Path:string):Integer;
var I:Integer;
begin
  Result:=-1;
  for I:=1 to High(FSpans) do if SameFileName(Path,FSpans[I].Path) then Exit(FSpans[I].BodyFirst);
end;
function TLinkedSource.ViewOffset(const Path:string; Offset:Integer):Integer;
var I,J:Integer;
begin
  Result:=Offset; if not FActive then Exit;
  Result:=-1;
  for I:=0 to High(FSpans) do if SameFileName(Path,FSpans[I].Path) then begin
    Result:=FSpans[I].BodyFirst+Offset-FSpans[I].FileFirst;
    for J:=I+1 to High(FSpans) do if FSpans[J].Parent=I then begin
      if Offset<FSpans[J].CommandFirst then Break;
      if Offset<FSpans[J].CommandAfter then Exit(FSpans[J].BodyFirst);
      Inc(Result,FSpans[J].After-FSpans[J].First-FSpans[J].CommandAfter+FSpans[J].CommandFirst);
    end;
    Exit(EnsureRange(Result,FSpans[I].BodyFirst,FSpans[I].BodyAfter));
  end;
end;
function TLinkedSource.Boundaries:TSourceBoundaries;
var I,J,N,P,A,B:Integer; Item:TSourceBoundary; Command:string;
begin
  Result:=nil; if not FActive then Exit;
  for I:=1 to High(FSpans) do begin
    J:=FSpans[I].Parent;
    while (J>0) and FileExpanded(FSpans[J].Path) do J:=FSpans[J].Parent;
    if J>0 then Continue;
    P:=FSpans[I].CommandFirst+1;
    Command:=ReadTeXCommand(FileSource(FSpans[FSpans[I].Parent].Path),P);
    { Paragraph blocks own trailing whitespace. A child's leading newline
      must not attach its opening separator to the preceding file's block. }
    A:=FSpans[I].BodyFirst; B:=FSpans[I].BodyAfter;
    while (A<B) and (FText[A+1] in [' ',#9,#10,#13]) do Inc(A);
    while (B>A) and (FText[B] in [' ',#9,#10,#13]) do Dec(B);
    N:=Length(Result); SetLength(Result,N+1);
    Result[N].Offset:=A; Result[N].Path:=FSpans[I].Path;
    Result[N].Caption:=Command+': '+ExtractRelativePath(ExtractFilePath(FRoot),FSpans[I].Path);
    Result[N].Collapsed:=not FileExpanded(FSpans[I].Path);
    if Result[N].Collapsed then begin
      Result[N].Caption:=Result[N].Caption+' [show]';
    end else begin
      SetLength(Result,N+2); Result[N+1]:=Result[N]; Result[N+1].Offset:=B; Result[N+1].Ending:=True;
      Result[N].Caption:=Result[N].Caption+' [hide]';
    end;
  end;
  for I:=1 to High(Result) do begin
    Item:=Result[I]; J:=I;
    { Nested files can end at the same byte; close the inner file first. }
    while (J>0) and ((Result[J-1].Offset>Item.Offset) or
      ((Result[J-1].Offset=Item.Offset) and Result[J-1].Ending and Item.Ending)) do begin
      Result[J]:=Result[J-1]; Dec(J);
    end;
    Result[J]:=Item;
  end;
end;
procedure TLinkedSource.Sources(Project:TTeXProject);
var I:Integer;
begin for I:=0 to FFiles.Count-1 do Project.SetSource(FFiles.Names[I],FFiles.ValueFromIndex[I]); end;
procedure TLinkedSource.ChangedFiles(Files:TStrings);
var I:Integer;
begin
  Files.Clear;
  for I:=0 to FFiles.Count-1 do if FFiles.ValueFromIndex[I]<>FOriginal.Values[FFiles.Names[I]] then Files.Add(FFiles.Names[I]);
end;
procedure TLinkedSource.Save(const RootPath:string);
var Changed:TStringList; I:Integer; Path,Value,Disk,Temp:string; Stream:TFileStream; ID:TGUID;
begin
  Path:=ExpandFileName(RootPath);
  if not SameFileName(ExtractFileDir(Path),ExtractFileDir(FRoot)) then
    raise Exception.Create('Save this project in its current directory to preserve relative subfile paths.');
  Changed:=TStringList.Create;
  try
    ChangedFiles(Changed);
    if Changed.IndexOf(FRoot)<0 then Changed.Add(FRoot);
    { Validate every destination before writing any of them. A second editor
      must never have its newer subfile silently replaced. }
    for I:=0 to Changed.Count-1 do begin
      Disk:=DiskSource(Changed[I]); Value:=FileSource(Changed[I]);
      if (Disk<>OriginalSource(Changed[I])) and (Disk<>Value) then
        raise Exception.Create('File changed outside this project: '+Changed[I]+'. Reopen it before saving.');
    end;
    for I:=0 to Changed.Count-1 do begin
      Value:=FileSource(Changed[I]); Path:=Changed[I]; if Path=FRoot then Path:=ExpandFileName(RootPath);
      if FileExists(Path) and (DiskSource(Path)=Value) then Continue;
      CreateGUID(ID); Temp:=Path+'.pastex-'+GUIDToString(ID)+'.tmp';
      try
        Stream:=TFileStream.Create(Temp,fmCreate);
        try if Value<>'' then Stream.WriteBuffer(Value[1],Length(Value)); finally Stream.Free; end;
        if not ReplaceFileAtomically(Temp,Path) then raise Exception.Create('Cannot replace '+Path+'. The original file was kept.');
      finally if FileExists(Temp) then DeleteFile(Temp); end;
    end;
    Path:=ExpandFileName(RootPath);
    if Path<>FRoot then begin
      Value:=FileSource(FRoot); FFiles.Delete(FFiles.IndexOf(FRoot)); FRoot:=Path; FFiles[Path]:=Value;
      FHistory:=nil; FHistoryAt:=0;
      Rebuild;
    end;
    FOriginal.Assign(FFiles);
  finally Changed.Free; end;
end;
end.
