unit TeXProject;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, SourceBuffers;
type
  TTeXInput=record
    First,After:Integer;
    Command,Path:string;
    Included,ClearPage,Subfile:Boolean;
  end;
  TTeXInputs=array of TTeXInput;
  TTeXProject=class
  private
    FOverrides,FCache:TSourceBuffers;
    FStack:TStringList;
    FIncludeOnly,FEngine:string;
    FBytes:SizeInt;
    function Expand(const Text,Path:string; Depth:Integer; Links:TStrings):string;
  public
    Warning:string;
    constructor Create;
    destructor Destroy; override;
    procedure SetSource(const Path,Text:string);
    function HasSource(const Path:string):Boolean;
    function ReadSource(const Path:string):string;
    function Expanded(const Text,Path:string; const Preamble:string=''):string;
    procedure LinkedFiles(const Text,Path:string; Dest:TStrings);
    function RootFile(const Text,Path:string):string;
    property Engine:string read FEngine write FEngine;
  end;
function ResolveTeXInput(const Name,ParentPath:string):string;
function DocumentInputs(const Text,Path,Preamble:string; const Engine:string='pdflatex'):TTeXInputs;
function InputNeedsSpace(const Text:string; Offset:Integer):Boolean;
{ Offset is a zero-based byte position in the containing file's source. }
function LinkedTeXInputAt(const Text,ParentPath:string; Offset:Integer):string;
function LinkedTeXInputRange(const Text:string; Offset:Integer; out First,Last:Integer):Boolean;
function TeXHyperlinkAt(const Text:string; Offset:Integer; out Target:string; out First,Last:Integer):Boolean;
function TeXHyperlinkDestination(const Text,Target:string):Integer;
implementation
uses TeXMacros, TeXDocument;
function InputNeedsSpace(const Text:string; Offset:Integer):Boolean;
var P,A:Integer;
begin
  P:=Offset;
  while (P>0) and (Text[P] in ['a'..'z','A'..'Z','@']) do Dec(P);
  A:=P; while (P>0) and (Text[P]='\') do Dec(P);
  Result:=(A<Offset) and Odd(A-P);
end;
function ReadDocumentCommand(const Text:string; var P:Integer; out Command:string):Boolean;
begin
  Result:=False;
  if ReadTeXDefinition(Text,P) or SkipTeXLiteral(Text,P) then Exit;
  Command:=ReadTeXCommand(Text,P); Result:=True;
end;
function ReadInputName(const Text,Command:string; var P:Integer):string;
var A:Integer;
begin
  Result:=''; SkipTeXSpace(Text,P);
  if Copy(Text,P,1)='{' then Result:=ReadTeXGroup(Text,P,'{','}')
  else if Command='input' then begin
    A:=P;
    while (P<=Length(Text)) and not (Text[P] in [' ',#9,#10,#13,'%']) do Inc(P);
    Result:=Copy(Text,A,P-A);
  end;
end;
function ScanInputs(const Source,Path:string; var Only:string; Collect:Boolean; const Engine:string=''):TTeXInputs;
var P,A,Depth,N:Integer; Command,Name,Text:string;
begin
  Text:=Source; if Engine<>'' then Text:=ActiveTeXSource(Source,Engine);
  Result:=nil; P:=1; Depth:=0;
  while P<=Length(Text) do begin
    if Text[P]='%' then begin while (P<=Length(Text)) and (Text[P]<>#10) do Inc(P); Continue; end;
    if Text[P]='{' then Inc(Depth) else if Text[P]='}' then Dec(Depth);
    if Text[P]<>'\' then begin Inc(P); Continue; end;
    A:=P; if not ReadDocumentCommand(Text,P,Command) then Continue;
    if Depth<>0 then Continue;
    if Command='includeonly' then begin
      Only:=','+StringReplace(ReadTeXGroup(Text,P,'{','}'),' ','',[rfReplaceAll])+','; Continue;
    end;
    if not Collect or not IsTeXInputCommand(Command) then Continue;
    Name:=ReadInputName(Text,Command,P); N:=Length(Result); SetLength(Result,N+1);
    Result[N].First:=A-1; Result[N].After:=P-1; Result[N].Command:=Command;
    Result[N].Path:=ResolveTeXInput(Name,Path);
    Result[N].ClearPage:=(Command='include') or (Command='subfileinclude');
    Result[N].Subfile:=(Command='subfile') or (Command='subfileinclude');
    Result[N].Included:=not Result[N].ClearPage or (Only='') or (Pos(','+Name+',',Only)>0) or
      (Pos(','+ChangeFileExt(Name,'')+',',Only)>0);
  end;
end;
function DocumentInputs(const Text,Path,Preamble:string; const Engine:string):TTeXInputs;
var Only:string;
begin
  Only:=''; ScanInputs(Preamble,'',Only,False,Engine); Result:=ScanInputs(Text,Path,Only,True,Engine);
end;
function InputLink(const Text:string; Offset:Integer; out Name:string; out First,Last:Integer):Boolean;
var P,A,Depth,NameStart:Integer; Command:string;
begin
  Result:=False; Name:=''; First:=-1; Last:=-1; P:=1; Depth:=0;
  if (Offset<0) or (Offset>Length(Text)) then Exit;
  while P<=Length(Text) do begin
    if Text[P]='%' then begin while (P<=Length(Text)) and (Text[P]<>#10) do Inc(P); Continue; end;
    if Text[P]='{' then Inc(Depth) else if Text[P]='}' then Dec(Depth);
    if Text[P]<>'\' then begin Inc(P); Continue; end;
    A:=P; if not ReadDocumentCommand(Text,P,Command) then Continue;
    if (Depth<>0) or not IsTeXInputCommand(Command) then Continue;
    SkipTeXSpace(Text,P); NameStart:=P; if Copy(Text,P,1)='{' then Inc(NameStart);
    Name:=ReadInputName(Text,Command,P);
    if (Offset>=A-1) and (Offset<=P-1) and (ResolveTeXInput(Name,'')<>'') then begin
      First:=NameStart-1; Last:=First+Length(Name);
      while (First<Last) and (Text[First+1] in [' ',#9,#10,#13]) do Inc(First);
      while (Last>First) and (Text[Last] in [' ',#9,#10,#13]) do Dec(Last);
      Exit(True);
    end;
  end;
end;
function LinkedTeXInputRange(const Text:string; Offset:Integer; out First,Last:Integer):Boolean;
var Name:string;
begin Result:=InputLink(Text,Offset,Name,First,Last); end;
function LinkedTeXInputAt(const Text,ParentPath:string; Offset:Integer):string;
var First,Last:Integer; Name:string;
begin
  Result:=''; if InputLink(Text,Offset,Name,First,Last) then Result:=ResolveTeXInput(Name,ParentPath);
end;
function TeXHyperlinkAt(const Text:string; Offset:Integer; out Target:string; out First,Last:Integer):Boolean;
var P,A,Q:Integer; Command,Key:string;
begin
  Result:=False; Target:=''; First:=-1; Last:=-1; P:=1;
  while P<=Length(Text) do begin
    if Text[P]='%' then begin while (P<=Length(Text)) and (Text[P]<>#10) do Inc(P); Continue; end;
    if Text[P]<>'\' then begin Inc(P); Continue; end;
    A:=P; if not ReadDocumentCommand(Text,P,Command) then Continue;
    if (Command<>'href') and (Command<>'url') and (Command<>'hyperref') and (Command<>'hyperlink') then Continue;
    Target:='';
    if Command='href' then ReadTeXGroup(Text,P,'[',']');
    if Command='hyperref' then begin
      SkipTeXSpace(Text,P); if Copy(Text,P,1)<>'[' then Continue;
      Key:=ReadTeXGroup(Text,P,'[',']'); Target:='label:'+Key;
    end else begin
      SkipTeXSpace(Text,P); Q:=P+1; Key:=ReadTeXGroup(Text,P,'{','}',True);
      if Command='hyperlink' then Target:='anchor:'+Key else Target:='url:'+Key;
      if Command='url' then begin First:=Q-1; Last:=First+Length(Key); end;
    end;
    if Command<>'url' then begin
      SkipTeXSpace(Text,P); First:=P; Key:=ReadTeXGroup(Text,P,'{','}'); Last:=First+Length(Key);
    end;
    if (Offset>=A-1) and (Offset<=P-1) then Exit(Target<>'');
    First:=-1; Last:=-1; Target:='';
  end;
end;
function TeXHyperlinkDestination(const Text,Target:string):Integer;
var P,A:Integer; Command,Key,Expected:string;
begin
  Result:=-1; P:=1; Expected:='label'; Key:=Copy(Target,7,MaxInt);
  if Copy(Target,1,7)='anchor:' then begin Expected:='hypertarget'; Key:=Copy(Target,8,MaxInt); end;
  while P<=Length(Text) do begin
    if Text[P]='%' then begin while (P<=Length(Text)) and (Text[P]<>#10) do Inc(P); Continue; end;
    if Text[P]<>'\' then begin Inc(P); Continue; end;
    A:=P; if not ReadDocumentCommand(Text,P,Command) then Continue;
    if (Command=Expected) and (ReadTeXGroup(Text,P,'{','}')=Key) then Exit(A-1);
  end;
end;
function ResolveTeXInput(const Name,ParentPath:string):string;
var Value:string;
begin
  Result:=''; Value:=Trim(Name); if Value='' then Exit;
  if (Pos('\',Value)>0) or (Pos('#',Value)>0) or (Pos('$',Value)>0) then Exit;
  if ExtractFileExt(Value)='' then Value:=Value+'.tex';
  if (ExtractFileDrive(Value)='') and not (Value[1] in ['/','\']) then Value:=IncludeTrailingPathDelimiter(ExtractFileDir(ParentPath))+Value;
  Result:=ExpandFileName(Value);
  { TeX appends .tex to chapter names containing dots as well. }
  if not FileExists(Result) and FileExists(Result+'.tex') then Result:=Result+'.tex';
end;
constructor TTeXProject.Create;
begin
  inherited Create; FEngine:='pdflatex'; FOverrides:=TSourceBuffers.Create; FCache:=TSourceBuffers.Create; FStack:=TStringList.Create;
  {$IFDEF UNIX}
  FStack.CaseSensitive:=True;
  {$ENDIF}
end;
destructor TTeXProject.Destroy;
begin FStack.Free; FCache.Free; FOverrides.Free; inherited Destroy; end;
procedure TTeXProject.SetSource(const Path,Text:string);
begin
  if Path<>'' then FOverrides[ExpandFileName(Path)]:=Text;
end;
function TTeXProject.HasSource(const Path:string):Boolean;
begin Result:=(FOverrides.IndexOf(ExpandFileName(Path))>=0) or FileExists(Path); end;
function TTeXProject.ReadSource(const Path:string):string;
var I:Integer; Stream:TFileStream; Key:string;
begin
  Key:=ExpandFileName(Path); I:=FOverrides.IndexOf(Key); if I>=0 then Exit(FOverrides.ValueFromIndex[I]);
  I:=FCache.IndexOf(Key); if I>=0 then Exit(FCache.ValueFromIndex[I]); Result:='';
  if not FileExists(Key) then begin Warning:='Cannot read subfile: '+Key; Exit; end;
  Stream:=TFileStream.Create(Key,fmOpenRead or fmShareDenyNone);
  try
    if Stream.Size>8*1024*1024 then begin Warning:='Subfile exceeds the 8 MiB preview limit: '+Key; Exit; end;
    SetLength(Result,Stream.Size); if Result<>'' then Stream.ReadBuffer(Result[1],Length(Result));
  finally Stream.Free; end;
  FCache[Key]:=Result;
end;
function TTeXProject.Expand(const Text,Path:string; Depth:Integer; Links:TStrings):string;
var Start:Integer; Value:string; Document:TTeXDocument; Inputs:TTeXInputs; Link:TTeXInput; Output:TMemoryStream;
  procedure Append(const S:string);
  begin if S<>'' then Output.WriteBuffer(S[1],Length(S)); end;
begin
  if Depth>32 then begin Warning:='Subfile nesting exceeds 32 levels.'; Exit(Text); end;
  if Links=nil then Inputs:=ScanInputs(Text,Path,FIncludeOnly,True,FEngine)
  else Inputs:=ScanInputs(Text,Path,FIncludeOnly,True);
  if Length(Inputs)=0 then Exit(Text);
  Output:=TMemoryStream.Create; Start:=0;
  try
    for Link in Inputs do begin
      if Link.Path='' then Continue;
      if (Links=nil) and not Link.Included then begin
        Append(Copy(Text,Start+1,Link.First-Start));
        if Link.ClearPage then Append('\clearpage'+LineEnding);
        Start:=Link.After; Continue;
      end;
      if Links<>nil then if Links.IndexOf(Link.Path)<0 then Links.Add(Link.Path);
      if FStack.IndexOf(Link.Path)>=0 then begin Warning:='Recursive subfile: '+Link.Path; Continue; end;
      Value:=ReadSource(Link.Path);
      if (FOverrides.IndexOf(Link.Path)<0) and (FCache.IndexOf(Link.Path)<0) then Continue;
      Inc(FBytes,Length(Value)); if FBytes>8*1024*1024 then begin Warning:='Expanded preview exceeds 8 MiB.'; Break; end;
      if Link.Subfile then begin
        Document:=TTeXDocument.Create;
        try
          Document.Parse(Value);
          if Document.Preamble<>'' then Value:=Copy(Value,Length(Document.Preamble)+1,
            Length(Value)-Length(Document.Preamble)-Length(Document.Ending));
        finally Document.Free; end;
      end;
      FStack.Add(Link.Path);
      try Value:=Expand(Value,Link.Path,Depth+1,Links); finally FStack.Delete(FStack.Count-1); end;
      Append(Copy(Text,Start+1,Link.First-Start));
      if Link.ClearPage then Append('\clearpage'+LineEnding);
      if not Link.ClearPage and InputNeedsSpace(Text,Link.First) then Append(' ');
      Append(Value);
      if (Value<>'') and not (Value[Length(Value)] in [#10,#13]) then Append(LineEnding);
      if Link.ClearPage then Append('\clearpage'+LineEnding);
      Start:=Link.After;
    end;
    Append(Copy(Text,Start+1,MaxInt)); SetLength(Result,Output.Size);
    if Result<>'' then Move(Output.Memory^,Result[1],Length(Result));
  finally Output.Free; end;
end;
function TTeXProject.Expanded(const Text,Path:string; const Preamble:string):string;
begin
  Warning:=''; FIncludeOnly:=''; ScanInputs(Preamble,'',FIncludeOnly,False,FEngine); FBytes:=Length(Text); FStack.Clear; FStack.Add(ExpandFileName(Path));
  Result:=Expand(Text,Path,0,nil);
end;
procedure TTeXProject.LinkedFiles(const Text,Path:string; Dest:TStrings);
begin
  Dest.Clear; Warning:=''; FIncludeOnly:=''; FBytes:=Length(Text); FStack.Clear; FStack.Add(ExpandFileName(Path)); Expand(Text,Path,0,Dest);
end;
function TTeXProject.RootFile(const Text,Path:string):string;
var Lines:TStringList; I,P:Integer; Line,Command,Options,Name:string;
begin
  Result:=''; Lines:=TStringList.Create;
  try
    Lines.Text:=Text;
    for I:=0 to Lines.Count-1 do begin
      Line:=Trim(Lines[I]); if Pos('% !tex root',LowerCase(Line))<>1 then Continue;
      P:=Pos('=',Line); if P>0 then Exit(ResolveTeXInput(Copy(Line,P+1,MaxInt),Path));
    end;
  finally Lines.Free; end;
  P:=1;
  while P<=Length(Text) do begin
    if Text[P]='%' then begin while (P<=Length(Text)) and (Text[P]<>#10) do Inc(P); Continue; end;
    if Text[P]<>'\' then begin Inc(P); Continue; end;
    Command:=ReadTeXCommand(Text,P);
    if Command<>'documentclass' then Continue;
    SkipTeXSpace(Text,P); Options:=''; if Copy(Text,P,1)='[' then Options:=ReadTeXGroup(Text,P,'[',']');
    Name:=ReadTeXGroup(Text,P,'{','}'); if Name='subfiles' then Result:=ResolveTeXInput(Options,Path); Exit;
  end;
end;
end.
