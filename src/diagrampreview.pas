unit DiagramPreview;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Graphics, VectorPreview;
type TDiagramBackend=(dbCachedTeX,dbNative);
function DiagramPreviewEnabled:Boolean;
procedure SetDiagramPreviewEnabled(Value:Boolean);
function SelectedDiagramBackend:TDiagramBackend;
procedure SetDiagramBackend(Value:TDiagramBackend);
function DiagramPreviewRevision:QWord;
procedure PumpDiagramPreviews;
function RequestDiagramPreview(const Preamble,Source,Directory,Engine,Site:string;
  out PDF:IVectorDocument; Picture:TPicture; out Pending:Boolean):Boolean;
function IsDiagramSource(const Source:string):Boolean;
function DiagramPackage(const Source:string):string;
function DiagramNeedsPlots(const Source:string):Boolean;
function DiagramDocument(const Preamble,Source:string):string;
procedure ClearDiagramPreviews;
implementation
uses Contnrs, TeXMacros, TeXRenderer, FormulaRender, NativeDiagrams, TikZModel, ToolJobs;
const CacheLimit=8*1024*1024; EntryLimit=24; Delay=500;
type TDiagramEntry=class
  Preamble,Source,Directory,Engine,Site,Error:string;
  PDF:IVectorDocument;
  Picture:TPicture;
  Inputs:TStringList;
  Requested,Used:QWord;
  Bytes:Int64;
  Ready,Cancelled,Native:Boolean;
  destructor Destroy; override;
end;
var Entries:TObjectList; Worker:TRenderThread; Current:TDiagramEntry;
    Enabled:Boolean; Backend:TDiagramBackend; Revision:QWord; CheckedEngine:string; CompilerPresent:Boolean;
destructor TDiagramEntry.Destroy;
begin Inputs.Free; Picture.Free; inherited Destroy; end;
function Stamp(const Name:string; Native:Boolean=False):string;
var S:TSearchRec; Stream:TFileStream; Buffer:array[0..8191] of Byte; Count,I:Integer; Hash:LongWord;
begin
  Result:='missing'; if FindFirst(Name,faAnyFile,S)<>0 then Exit;
  try Result:=IntToStr(S.Time)+':'+IntToStr(S.Size); finally FindClose(S); end;
  { Native data files are limited to 1 MiB. Compare their contents too: a
    same-size edit within one timestamp tick must refresh the plot. }
  if Native and (S.Size<=1024*1024) then try
    Stream:=TFileStream.Create(Name,fmOpenRead or fmShareDenyNone);
    try
      Hash:=0;
      repeat
        Count:=Stream.Read(Buffer,SizeOf(Buffer));
        for I:=0 to Count-1 do Hash:=((Hash shl 5) or (Hash shr 27)) xor Buffer[I];
      until Count=0;
      Result:=Result+':'+IntToStr(Hash);
    finally Stream.Free; end;
  except on E:Exception do Result:='unreadable'; end;
end;
function InputsValid(E:TDiagramEntry):Boolean;
var I:Integer;
begin
  Result:=True; if E.Inputs=nil then Exit;
  for I:=0 to E.Inputs.Count-1 do if Stamp(E.Inputs.Names[I],E.Native)<>E.Inputs.ValueFromIndex[I] then Exit(False);
end;
procedure RecordInputs(E:TDiagramEntry; const Path:string);
var Lines:TStringList; Line,Name,Base:string;
begin
  E.Inputs:=TStringList.Create; E.Inputs.NameValueSeparator:=#1; E.Inputs.CaseSensitive:=True;
  if not FileExists(Path) then Exit;
  Base:=IncludeTrailingPathDelimiter(ExpandFileName(E.Directory)); Lines:=TStringList.Create;
  try
    Lines.LoadFromFile(Path);
    for Line in Lines do if Copy(Line,1,6)='INPUT ' then begin
      Name:=Copy(Line,7,MaxInt);
      if Name='' then Continue;
      if (ExtractFileDrive(Name)='') and not (Name[1] in ['/','\']) then Name:=Base+Name;
      Name:=ExpandFileName(Name);
      if (Pos(Base,Name)=1) and FileExists(Name) then E.Inputs.Values[Name]:=Stamp(Name);
    end;
  finally Lines.Free; end;
end;
function DiagramPreviewEnabled:Boolean;
begin Result:=Enabled; end;
function DiagramPreviewRevision:QWord;
begin Result:=Revision; end;
function SelectedDiagramBackend:TDiagramBackend;
begin Result:=Backend; end;
procedure SetDiagramBackend(Value:TDiagramBackend);
begin
  if Value=Backend then Exit; Backend:=Value; ClearDiagramPreviews;
end;
procedure SetDiagramPreviewEnabled(Value:Boolean);
begin
  if Value=Enabled then Exit; Enabled:=Value; Inc(Revision);
  if not Value then ClearDiagramPreviews;
end;
function IsDiagramSource(const Source:string):Boolean;
begin Result:=DiagramPackage(Source)<>''; end;
function DiagramPackage(const Source:string):string;
var P:Integer; Command,Name:string;
begin
  Result:=''; P:=1; SkipTeXSpace(Source,P); Command:=ReadTeXCommand(Source,P);
  if (Command='xymatrix') or (Copy(Command,1,9)='xymatrix@') then Exit('xy');
  if Command<>'begin' then Exit; Name:=ReadTeXGroup(Source,P,'{','}');
  case Name of 'tikzpicture':Result:='tikz'; 'circuitikz':Result:='circuitikz'; 'tikzcd':Result:='tikz-cd'; 'xy':Result:='xy'; end;
end;
function DiagramNeedsPlots(const Source:string):Boolean;
var Model:TDiagramModel; Environment:TDiagramEnvironment;
begin
  Model:=TDiagramModel.Create;
  try
    Model.Load(Source);
    for Environment in Model.Environments do
      if DiagramIsAxis(Environment.Name) or (Environment.Name='groupplot') then Exit(True);
    Result:=False;
  finally Model.Free; end;
end;
function DiagramHeader(const Preamble:string):string;
var P,A,Q:Integer; Command:string;
begin
  Result:=Preamble; P:=1;
  while P<=Length(Result) do begin
    if Result[P]='%' then begin while (P<=Length(Result)) and (Result[P]<>#10) do Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Result,Q) then begin P:=Q; Continue; end;
    if Result[P]<>'\' then begin Inc(P); Continue; end;
    A:=P; Command:=ReadTeXCommand(Result,P);
    if (Command='begin') and (ReadTeXGroup(Result,P,'{','}')='document') then begin Delete(Result,A,P-A); Exit; end;
  end;
end;
function DiagramDocument(const Preamble,Source:string):string;
var Header:string;
begin
  Header:=DiagramHeader(Preamble)+LineEnding;
  if DiagramPackage(Source)='xy' then Header:=Header+'\RequirePackage{xy}\xyoption{all}'+LineEnding
  else if DiagramPackage(Source)='tikz-cd' then Header:=Header+'\RequirePackage{tikz-cd}'+LineEnding
  else if DiagramPackage(Source)='circuitikz' then Header:=Header+'\RequirePackage{circuitikz}'+LineEnding
  else Header:=Header+'\RequirePackage{tikz}'+LineEnding;
  if DiagramNeedsPlots(Source) then Header:=Header+'\RequirePackage{pgfplots}'+LineEnding;
  Result:=FormulaDocument(Header,Source,'',False,False,True);
end;
procedure ClearDiagramPreviews;
var I:Integer;
begin
  CheckedEngine:='';
  if Worker<>nil then Worker.Terminate;
  for I:=Entries.Count-1 downto 0 do
    if Entries[I]=Current then TDiagramEntry(Entries[I]).Cancelled:=True else Entries.Delete(I);
  Inc(Revision);
end;
procedure TrimCache;
var I,Oldest:Integer; Total:Int64; Age:QWord; E:TDiagramEntry;
begin
  repeat
    Total:=0; Oldest:=-1; Age:=High(QWord);
    for I:=0 to Entries.Count-1 do begin
      E:=TDiagramEntry(Entries[I]); Inc(Total,E.Bytes+Length(E.Source)+Length(E.Preamble));
      if (E<>Current) and (E.Used<Age) then begin Age:=E.Used; Oldest:=I; end;
    end;
    if (Oldest<0) or ((Entries.Count<=EntryLimit) and (Total<=CacheLimit)) then Break;
    Entries.Delete(Oldest);
  until False;
end;
function RequestDiagramPreview(const Preamble,Source,Directory,Engine,Site:string;
  out PDF:IVectorDocument; Picture:TPicture; out Pending:Boolean):Boolean;
var I:Integer; E,Found,Previous:TDiagramEntry; Name:string; UseNative:Boolean;
begin
  Result:=False; Pending:=False; PDF:=nil;
  if not Enabled or not IsDiagramSource(Source) or (Length(Source)>256*1024) or (Length(Preamble)>256*1024) then Exit;
  UseNative:=Backend=dbNative;
  if not UseNative then begin
    if Engine+#0+Directory<>CheckedEngine then begin
      CheckedEngine:=Engine+#0+Directory;
      CompilerPresent:=CompilerAvailable(Engine,Directory) and (VectorPDFSupported or (FindTool('pdftoppm')<>''));
    end;
    UseNative:=not CompilerPresent;
  end;
  Found:=nil; Previous:=nil;
  for I:=0 to Entries.Count-1 do begin
    E:=TDiagramEntry(Entries[I]);
    if not E.Cancelled and (E.Native=UseNative) and (E.Source=Source) and (E.Preamble=Preamble) and (E.Directory=Directory) and (E.Engine=Engine) then begin
      if InputsValid(E) then Found:=E else E.Cancelled:=True;
    end;
    if (E.Site<>Site) or (E.Directory<>Directory) then Continue;
    if E.Ready and ((E.PDF<>nil) or (E.Picture<>nil)) then Previous:=E;
  end;
  if Found=nil then begin
    { Replace queued edits at the same drawing; one worker debounces typing. }
    for I:=Entries.Count-1 downto 0 do begin
      E:=TDiagramEntry(Entries[I]); if (E.Site<>Site) or (E.Directory<>Directory) or E.Ready then Continue;
      if E=Current then begin E.Cancelled:=True; Worker.Terminate; end else Entries.Delete(I);
    end;
    Found:=TDiagramEntry.Create; Found.Source:=Source; Found.Preamble:=Preamble;
    Found.Directory:=Directory; Found.Engine:=Engine; Found.Site:=Site; Found.Requested:=GetTickCount64;
    Found.Native:=UseNative;
    Entries.Add(Found);
    if UseNative then begin
      Found.Inputs:=TStringList.Create; Found.Inputs.NameValueSeparator:=#1; Found.Inputs.CaseSensitive:=True;
      Found.PDF:=NativeDiagram(Preamble,Source,Directory,Found.Bytes,Engine,nil,Found.Inputs); Found.Ready:=True;
      for I:=0 to Found.Inputs.Count-1 do begin Name:=Found.Inputs[I]; Found.Inputs[I]:=Name+#1+Stamp(Name,True); end;
      { Native scenes retain coordinates, never a full-size raster per zoom. }
    end;
  end;
  Found.Used:=GetTickCount64; Pending:=not Found.Ready;
  if UseNative and (Found.PDF=nil) then Previous:=nil;
  E:=Found; if (E.PDF=nil) and (E.Picture=nil) and (Previous<>nil) then E:=Previous;
  PDF:=E.PDF;
  if (E.Picture<>nil) and (Picture<>nil) then Picture.Assign(E.Picture);
  Result:=(PDF<>nil) or (E.Picture<>nil); TrimCache;
end;
procedure PumpDiagramPreviews;
var I:Integer; E:TDiagramEntry; Name:string; S:TSearchRec;
begin
  if (Worker<>nil) and Worker.Finished then begin
    E:=Current;
    if Enabled and not E.Cancelled and (Worker.ErrorText='') then begin
      Name:=Worker.WorkDir+DirectorySeparator+'preview.pdf'; E.PDF:=OpenVectorDocument(Name);
      if FindFirst(Name,faAnyFile,S)=0 then begin E.Bytes:=S.Size; FindClose(S); end;
      RecordInputs(E,Worker.WorkDir+DirectorySeparator+'preview.fls');
      if (E.PDF=nil) and (Worker.Images.Count>0) then begin
        E.Picture:=TPicture.Create;
        try E.Picture.LoadFromFile(Worker.Images[0]); Inc(E.Bytes,Int64(E.Picture.Width)*E.Picture.Height*4);
        except FreeAndNil(E.Picture); end;
      end;
    end;
    E.Ready:=True; E.Error:=Worker.ErrorText; FreeAndNil(Worker); Current:=nil; Inc(Revision);
    if E.Cancelled then Entries.Remove(E); TrimCache;
  end;
  if not Enabled or (Worker<>nil) then Exit;
  for I:=Entries.Count-1 downto 0 do begin
    E:=TDiagramEntry(Entries[I]);
    if E.Ready or E.Cancelled or (GetTickCount64-E.Requested<Delay) then Continue;
    Current:=E;
    Worker:=TRenderThread.Create(DiagramDocument(E.Preamble,E.Source),E.Directory,E.Engine,0);
    Worker.PDFOnly:=VectorPDFSupported; Worker.RenderPasses:=2; Worker.DPI:=120; Worker.PreviewPage:=1;
    Worker.Start; Break;
  end;
end;
initialization
  Entries:=TObjectList.Create(True); Revision:=1;
finalization
  if Worker<>nil then begin Worker.Terminate; Worker.WaitFor; Worker.Free; end;
  Entries.Free;
end.
