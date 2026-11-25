unit TeXDocument;
{ SPDX-License-Identifier: GPL-3.0-or-later }

{$mode objfpc}{$H+}

interface

uses Classes, SysUtils, Math;

type
  TTeXDocument = class
  private
    FBlocks:TStringList;
    FOffsets:array of Integer;
    FIndexed:Boolean;
    procedure IndexBlocks;
  public
    Preamble, Ending: string;
    PreambleOnly: Boolean;
    property Blocks:TStringList read FBlocks;
    constructor Create;
    destructor Destroy; override;
    procedure Parse(const Source: string);
    procedure ParseFile(const Source: string);
    function Source: string;
    function PreviewSource: string;
    function SourceOffset(BlockIndex,LocalOffset:Integer):Integer;
    procedure LocateOffset(Offset:Integer; out BlockIndex,LocalOffset:Integer);
  end;
function CompilableTeXDocument(const Source:string):Boolean;
function HasTeXDocumentClass(const Source:string):Boolean;
function IsGeneratedTeXCommand(const Command:string):Boolean;
function IsContentsTeXCommand(const Command:string):Boolean;
function TeXCounterSetting(const Source,Name:string; DefaultValue:Integer):Integer;
function IsGeneratedTeXBlock(const Source:string):Boolean;

implementation

uses FormulaRender, TeXMacros, BeamerModel;
type
  TDocumentBlocks=class(TStringList)
  private
    FDocument:TTeXDocument;
  protected
    procedure Changed; override;
  public
    constructor Create(Document:TTeXDocument);
  end;
constructor TDocumentBlocks.Create(Document:TTeXDocument);
begin inherited Create; FDocument:=Document; end;
procedure TDocumentBlocks.Changed;
begin
  { Invalidate even inside BeginUpdate: selection mapping can be queried
    during a grouped edit, before TStringList delivers its OnChange event. }
  if FDocument<>nil then FDocument.FIndexed:=False;
  inherited;
end;
procedure TTeXDocument.IndexBlocks;
var I:Integer;
begin
  if FIndexed then Exit;
  SetLength(FOffsets,FBlocks.Count+1); FOffsets[0]:=0;
  for I:=0 to FBlocks.Count-1 do FOffsets[I+1]:=FOffsets[I]+Length(FBlocks[I]);
  FIndexed:=True;
end;
function TeXCounterSetting(const Source,Name:string; DefaultValue:Integer):Integer;
var P,Q,Value:Integer; Command,Target,Text:string;
begin
  Result:=DefaultValue; P:=1;
  while P<=Length(Source) do begin
    SkipTeXSpace(Source,P); if P>Length(Source) then Break;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) or SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
    Command:=ReadTeXCommand(Source,P);
    if (Command='begin') and (ReadTeXGroup(Source,P,'{','}')='document') then Break;
    if (Command<>'setcounter') and (Command<>'addtocounter') then Continue;
    Target:=ReadTeXGroup(Source,P,'{','}'); Text:=ReadTeXGroup(Source,P,'{','}');
    if (Target<>Name) or not TryStrToInt(Trim(Text),Value) then Continue;
    if Command='setcounter' then Result:=Value
    else Result:=EnsureRange(Int64(Result)+Value,Low(Integer),High(Integer));
  end;
end;
function IsContentsTeXCommand(const Command:string):Boolean;
begin Result:=(Command='tableofcontents') or (Command='listoffigures') or (Command='listoftables'); end;
function IsGeneratedTeXCommand(const Command:string):Boolean;
begin
  Result:=(Command='maketitle') or IsContentsTeXCommand(Command) or (Command='bibliography') or
    (Command='printbibliography') or (Command='printbibliogrphy');
end;
function BibliographySetupOnly(const Source:string):Boolean;
var P:Integer; Command:string;
begin
  Result:=True; P:=1;
  while P<=Length(Source) do begin
    SkipTeXSpace(Source,P); if P>Length(Source) then Break;
    if Source[P]<>'\' then Exit(False); Command:=ReadTeXCommand(Source,P);
    if (Command<>'bibliographystyle') and (Command<>'nocite') then Exit(False);
    SkipTeXSpace(Source,P); ReadTeXGroup(Source,P,'{','}');
  end;
end;
function IsGeneratedTeXBlock(const Source:string):Boolean;
var P:Integer; Command:string;
begin
  Result:=False; P:=1;
  while P<=Length(Source) do begin
    SkipTeXSpace(Source,P); if P>Length(Source) then Break;
    if Source[P]<>'\' then Exit(False); Command:=ReadTeXCommand(Source,P);
    if IsGeneratedTeXCommand(Command) then Result:=True
    else if (Command<>'bibliographystyle') and (Command<>'nocite') then Exit(False);
    SkipTeXSpace(Source,P);
    while Copy(Source,P,1)='[' do begin ReadTeXGroup(Source,P,'[',']'); SkipTeXSpace(Source,P); end;
    if Copy(Source,P,1)='{' then ReadTeXGroup(Source,P,'{','}');
  end;
end;
function MarkerPosition(const S,Marker:string):SizeInt; forward;
procedure DocumentMarkers(const Source:string; out HasClass,HasBody:Boolean);
var ClassAt,BodyAt:SizeInt;
begin
  ClassAt:=MarkerPosition(Source,'\documentclass'); BodyAt:=MarkerPosition(Source,'\begin{document}');
  HasBody:=BodyAt>0; HasClass:=(ClassAt>0) and ((BodyAt=0) or (ClassAt<BodyAt));
end;
function CompilableTeXDocument(const Source:string):Boolean;
var HasClass,HasBody:Boolean;
begin DocumentMarkers(Source,HasClass,HasBody); Result:=HasClass and HasBody; end;
function HasTeXDocumentClass(const Source:string):Boolean;
var HasBody:Boolean;
begin DocumentMarkers(Source,Result,HasBody); end;

constructor TTeXDocument.Create;
begin
  FBlocks := TDocumentBlocks.Create(Self);
end;

destructor TTeXDocument.Destroy;
begin
  Blocks.Free;
  inherited Destroy;
end;

function MarkerPosition(const S, Marker: string): SizeInt;
var I,A,Q,Environments:Integer; Command,Env,Literal:string; Delimiter:Char;
begin
  I:=1; Environments:=0;
  while I<=Length(S) do begin
    if S[I]='%' then begin while (I<=Length(S)) and (S[I]<>#10) do Inc(I); Continue; end;
    if S[I]='{' then begin ReadTeXGroup(S,I,'{','}'); Continue; end;
    if S[I]<>'\' then begin Inc(I); Continue; end;
    A:=I; Q:=I;
    if ReadTeXDefinition(S,Q) or SkipTeXBibResource(S,Q) or SkipTeXLiteral(S,Q) then begin I:=Q; Continue; end;
    Command:=ReadTeXCommand(S,I);
    if (Environments=0) and (Copy(S,A,Length(Marker))=Marker) and
       ((Marker<>'\documentclass') or (Command='documentclass')) then Exit(A);
    if (Command='verb') or (Command='Verb') then begin
      if Copy(S,I,1)='*' then Inc(I);
      if I<=Length(S) then begin
        Delimiter:=S[I]; Inc(I);
        while (I<=Length(S)) and (S[I]<>Delimiter) and not (S[I] in [#10,#13]) do Inc(I);
        if (I<=Length(S)) and (S[I]=Delimiter) then Inc(I);
      end;
    end else if (Command='begin') or (Command='end') then begin
      Env:=ReadTeXGroup(S,I,'{','}');
      if Command='end' then begin if Environments>0 then Dec(Environments); end
      else if IsTeXVerbatimEnvironment(Env) then begin
        Literal:='\end{'+Env+'}'; Q:=Pos(Literal,Copy(S,I,MaxInt));
        if Q=0 then I:=Length(S)+1 else Inc(I,Q-1+Length(Literal));
      end else Inc(Environments);
    end else begin
      SkipTeXSpace(S,I);
      while (Copy(S,I,1)='{') or (Copy(S,I,1)='[') do begin
        if S[I]='{' then ReadTeXGroup(S,I,'{','}') else ReadTeXGroup(S,I,'[',']');
        SkipTeXSpace(S,I);
      end;
    end;
  end;
  Result:=0;
end;

procedure TTeXDocument.Parse(const Source: string);
const BeginDoc = '\begin{document}'; EndDoc = '\end{document}';
var
  Body, Env, Math, Literal,Command: string;
  A, B, I, J, Start, Depth, Environments: SizeInt;
  Q,ConditionalFirst,ConditionalAfter:Integer;
  C: Char;
  RunIn,Presentation:Boolean;
  Frame:TBeamerFrame;
  function GeneratedEnd(Offset:Integer):Integer;
  var P:Integer; Command:string;
  begin
    Result:=0; P:=Offset; Command:=ReadTeXCommand(Body,P);
    if Command='appendix' then begin SkipTeXSpace(Body,P); Exit(P); end;
    if not IsGeneratedTeXCommand(Command) then Exit;
    SkipTeXSpace(Body,P);
    while Copy(Body,P,1)='[' do begin ReadTeXGroup(Body,P,'[',']'); SkipTeXSpace(Body,P); end;
    if Copy(Body,P,1)='{' then ReadTeXGroup(Body,P,'{','}');
    SkipTeXSpace(Body,P); Result:=P;
  end;
  function HeadingEnd(Offset:Integer; out RunIn:Boolean):Integer;
  var P:Integer; Command:string;
  begin
    Result:=0; P:=Offset; Command:=ReadTeXCommand(Body,P);
    RunIn:=(Command='paragraph') or (Command='subparagraph');
    if (Command<>'section') and (Command<>'subsection') and (Command<>'subsubsection') and
       (Command<>'chapter') and (Command<>'part') and not RunIn then Exit;
    if (P<=Length(Body)) and (Body[P]='*') then Inc(P);
    SkipTeXSpace(Body,P);
    if (P<=Length(Body)) and (Body[P]='[') then ReadTeXGroup(Body,P,'[',']');
    SkipTeXSpace(Body,P);
    if (P>Length(Body)) or (Body[P]<>'{') then Exit;
    ReadTeXGroup(Body,P,'{','}');
    if (P>Length(Body)+1) or (Body[P-1]<>'}') then Exit;
    { Keep whitespace and a trailing comment with the heading. }
    while P<=Length(Body) do
      if Body[P] in [' ',#9,#10,#13] then Inc(P)
      else if Body[P]='%' then begin while (P<=Length(Body)) and (Body[P]<>#10) do Inc(P); end
      else Break;
    Result:=P;
  end;
begin
  PreambleOnly:=False;
  Blocks.Clear;
  Preamble := '';
  Ending := '';
  A := MarkerPosition(Source, BeginDoc);
  if A > 0 then
  begin
    Preamble := Copy(Source, 1, A + Length(BeginDoc) - 1);
    Body := Copy(Source, A + Length(BeginDoc), MaxInt);
    B := MarkerPosition(Body, EndDoc);
    if B > 0 then
    begin
      Ending := Copy(Body, B, MaxInt);
      Body := Copy(Body, 1, B - 1);
    end;
  end
  else Body := Source;
  Presentation:=BeamerSettings(Preamble).Enabled;
  I := 1;
  Start := 1;
  Depth := 0;
  Environments := 0;
  Math := '';
  Literal := '';
  while I <= Length(Body) do
  begin
    if Literal <> '' then
    begin
      if Copy(Body, I, Length(Literal)) = Literal then
      begin
        Inc(I, Length(Literal));
        Literal := '';
        Dec(Environments);
      end
      else Inc(I);
      Continue;
    end;
    C := Body[I];
    if C = '%' then
    begin
      while (I <= Length(Body)) and (Body[I] <> #10) do Inc(I);
      Continue;
    end;
    if C = '\' then
    begin
      Q:=I; if ReadTeXDefinition(Body,Q) or SkipTeXLiteral(Body,Q) then begin I:=Q; Continue; end;
      if ReadEngineConditional(Body,'pdflatex',Q,ConditionalFirst,ConditionalAfter) then begin I:=Q; Continue; end;
      if (Depth=0) and (Environments=0) and (Math='') then
      begin
        if Presentation and ReadBeamerFrame(Body,I,Frame) then begin
          J:=Frame.After; while (J<=Length(Body)) and (Body[J] in [' ',#9,#10,#13]) do Inc(J);
          Blocks.Add(Copy(Body,Start,J-Start)); Start:=J; I:=J; Continue;
        end;
        J:=GeneratedEnd(I);
        if (J>0) and not Presentation then begin
          { Generated material is a separate read-only object, even when
            adjacent commands have no blank source line between them. }
          if not BibliographySetupOnly(Copy(Body,Start,I-Start)) then begin
            Blocks.Add(Copy(Body,Start,I-Start)); Start:=I;
          end;
          Blocks.Add(Copy(Body,Start,J-Start)); Start:=J; I:=J; Continue;
        end;
        J:=HeadingEnd(I,RunIn);
        if (J>0) and not Presentation then
        begin
          if Trim(Copy(Body,Start,I-Start))<>'' then
          begin Blocks.Add(Copy(Body,Start,I-Start)); Start:=I; end;
          { A run-in heading starts a paragraph, but source blank lines after
            its title do not separate it from the following text (@xsect). }
          if not RunIn then begin Blocks.Add(Copy(Body,Start,J-Start)); Start:=J; end;
          I:=J; Continue;
        end;
      end;
      Q:=I; Command:=ReadTeXCommand(Body,Q);
      if (Command='verb') or (Command='Verb') then
      begin
        I:=Q;
        if (I <= Length(Body)) and (Body[I] = '*') then Inc(I);
        if I <= Length(Body) then
        begin
          C := Body[I];
          Inc(I);
          while (I <= Length(Body)) and (Body[I] <> C) do Inc(I);
        end;
      end
      else if (Copy(Body, I, 6) = '\begin') or
              (Copy(Body, I, 4) = '\end') then
      begin
        Q:=I; Command:=ReadTeXCommand(Body,Q);
        if (Command<>'begin') and (Command<>'end') then begin I:=Q; Continue; end;
        Env:=ReadTeXGroup(Body,Q,'{','}');
        if Env='' then begin I:=Q; Continue; end;
        if Command='begin' then begin
          Inc(Environments);
          if IsTeXVerbatimEnvironment(Env) then Literal:='\end{'+Env+'}';
        end else if Environments>0 then Dec(Environments);
        I := Q-1;
      end
      else
      begin
        if (Copy(Body, I, 2) = '\[') or (Copy(Body, I, 2) = '\(') then
          Math := Copy(Body, I, 2)
        else if ((Math = '\[') and (Copy(Body, I, 2) = '\]')) or
                ((Math = '\(') and (Copy(Body, I, 2) = '\)')) then Math := '';
        Inc(I);
      end;
    end
    else if C = '{' then Inc(Depth)
    else if C = '}' then begin if Depth>0 then Dec(Depth); end
    else if C = '$' then
    begin
      Env := '$';
      if Copy(Body, I, 2) = '$$' then begin Env := '$$'; Inc(I); end;
      if Math = Env then Math := '' else if Math = '' then Math := Env;
    end
    else if (C = #10) and not Presentation and (Depth = 0) and (Environments = 0) and (Math = '') then
    begin
      J := I + 1;
      while (J <= Length(Body)) and (Body[J] in [' ', #9, #13]) do Inc(J);
      if (J <= Length(Body)) and (Body[J] = #10) then
      begin
        while (J <= Length(Body)) and (Body[J] in [' ', #9, #13, #10]) do Inc(J);
        if (Trim(Copy(Body, Start, J - Start)) <> '') and
           not BibliographySetupOnly(Copy(Body,Start,J-Start)) then
        begin
          Blocks.Add(Copy(Body, Start, J - Start));
          Start := J;
        end;
        I := J - 1;
      end;
    end;
    Inc(I);
  end;
  if Start <= Length(Body) then Blocks.Add(Copy(Body, Start, MaxInt));
  if Blocks.Count = 0 then Blocks.Add('');
end;

procedure TTeXDocument.ParseFile(const Source:string);
begin
  if CompilableTeXDocument(Source) then Parse(Source)
  else begin
    PreambleOnly:=True; Preamble:=Source; Ending:=''; Blocks.Clear;
  end;
end;

function TTeXDocument.Source: string;
var I,P:Integer;
  procedure Append(const Text:string);
  begin
    if Text<>'' then Move(Text[1],Result[P],Length(Text));
    Inc(P,Length(Text));
  end;
begin
  IndexBlocks; SetLength(Result,Length(Preamble)+FOffsets[Blocks.Count]+Length(Ending)); P:=1;
  Append(Preamble);
  for I:=0 to Blocks.Count-1 do Append(Blocks[I]);
  Append(Ending);
end;
function TTeXDocument.SourceOffset(BlockIndex,LocalOffset:Integer):Integer;
begin
  IndexBlocks; Result:=Length(Preamble)+FOffsets[EnsureRange(BlockIndex,0,Blocks.Count)];
  if (BlockIndex>=0) and (BlockIndex<Blocks.Count) then Inc(Result,Math.EnsureRange(LocalOffset,0,Length(Blocks[BlockIndex])));
end;
procedure TTeXDocument.LocateOffset(Offset:Integer; out BlockIndex,LocalOffset:Integer);
var First,Last,Middle:Integer;
begin
  if Blocks.Count=0 then begin BlockIndex:=-1; LocalOffset:=EnsureRange(Offset,0,Length(Preamble)); Exit; end;
  IndexBlocks; LocalOffset:=Max(0,Offset-Length(Preamble)); First:=0; Last:=Blocks.Count-1;
  while First<Last do begin
    Middle:=(First+Last+1) div 2;
    if FOffsets[Middle]<=LocalOffset then First:=Middle else Last:=Middle-1;
  end;
  BlockIndex:=First; LocalOffset:=EnsureRange(LocalOffset-FOffsets[First],0,Length(Blocks[First]));
end;

function TTeXDocument.PreviewSource: string;
begin
  if PreambleOnly then Exit(Source);
  { Reading previews compile the source without editing markers or decorations. }
  Result:=ParagraphDocument(Preamble,Blocks,-1,'',False);
end;

end.
