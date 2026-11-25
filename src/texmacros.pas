unit TeXMacros;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Contnrs;
type
  TMacroInfo = class
  private
    FReferences:Integer;
  public
    Name, Signature, Definition, Body, DefaultArgument: string;
    ArgCount: Integer;
    OptionalFirst: Boolean;
    PackageSource,GlyphFont,GlyphPlan,MathGlyphPlan,SymbolClass,NativeName,PreviewAdapter,PreviewName,DelimiterFont:string;
    GlyphCode,DelimiterCode:Integer;
    Expandable,Undefined:Boolean;
    function ArgumentKind(Index:Integer; out DefaultValue:string):Char;
    constructor Create;
    procedure Retain;
    procedure Release;
  end;
  TMacroRegistry = class
  private
    FItems: TStringList;
    FVisited,FTheorems,FEnvironments,FImports: TStringList;
    FSymbolFonts,FSavedBoxes:TStringList;
    FReadBytes:Integer;
    FSourceDirectory,FEngine:string;
    FDefinitions:string;
    FRevision:QWord;
    FPresentation:Boolean;
    procedure Scan(const Input, Directory: string; Depth: Integer; const PackagePath:string='');
    function FreezeBox(const Value:string; Depth:Integer=0):string;
  public
    procedure InstallPackagePreview(const Name,Path:string);
    constructor Create;
    destructor Destroy; override;
    procedure Load(const Source, Directory: string; const Engine:string='pdflatex');
    function Clone:TMacroRegistry;
    procedure Assign(Other:TMacroRegistry);
    procedure ApplyDefinitions(const Source:string);
    function SavedBox(const Name:string):string;
    function Find(const Name: string): TMacroInfo;
    function RequiresLiteralArguments(const Name:string):Boolean;
    procedure Names(Dest: TStrings);
    procedure EnvironmentNames(Dest:TStrings);
    function IsTheorem(const Name:string):Boolean;
    property Definitions:string read FDefinitions;
    property Revision:QWord read FRevision;
    property Engine:string read FEngine;
    property Presentation:Boolean read FPresentation;
  end;
function TopLevelDelimiter(const Source:string; Delimiter:Char; Start:Integer=1):Integer;
function ReadTeXRuleDimension(const Source:string; var Position:Integer; out Name,Value:string):Boolean;
function ReadTeXGroup(const S: string; var P: Integer; OpenChar, CloseChar: Char; Literal:Boolean=False): string;
function ReadTeXArgument(const Source:string; var Position:Integer; Literal:Boolean=False):string;
procedure SkipTeXSpace(const S: string; var P: Integer);
function ReadTeXCommand(const S: string; var P: Integer): string;
function EndsTeXControlWord(const Text:string):Boolean;
function SubstituteTeXParameters(const Template:string; const Arguments:array of string;
  out Expanded:string; Limit:Integer=65536):Boolean;
function SkipTeXBibResource(const S:string; var P:Integer):Boolean;
function ReadTeXDefinition(const S:string; var P:Integer):Boolean;
function ReadTeXEnvironmentDefinition(const S:string; var P:Integer):Boolean;
function ContainsTeXDefinitions(const S:string):Boolean;
function TeXDefinitionName(const S:string):string;
function TeXHeaderLength(const Source:string):Integer;
function TeXContextDeclarations(const Source:string):string;
function TeXPackageFont(const Encoding,Family,Directory:string):string;
function IsTeXVerbatimEnvironment(const Name:string):Boolean;
function IsTeXInputCommand(const Name:string):Boolean;
function SkipTeXLiteral(const Source:string; var Position:Integer):Boolean;
function EngineConditional(const Command,Engine:string; out Value:Boolean):Boolean;
function ReadEngineConditional(const Source,Engine:string; var Position:Integer; out First,After:Integer; Registry:TMacroRegistry=nil):Boolean;
function ActiveTeXSource(const Source,Engine:string):string;
implementation
uses TeXPackageSources, TeXFontData, TeXPackagePreview, TeXSymbolRuns, RegExpr, TeXFontConfig, BeamerModel, ExtensionSyntax;
type TRegistryCache=class
  Key:string;
  Registry:TMacroRegistry;
  Stamps:TStringList;
  destructor Destroy; override;
end;
var RegistryCache:TObjectList; RegistryRevision:QWord;
{$I texconditionals.inc}
function IsTeXInputCommand(const Name:string):Boolean;
begin Result:=(Name='input') or (Name='include') or (Name='subfile') or (Name='subfileinclude'); end;
function IsTeXVerbatimEnvironment(const Name:string):Boolean;
begin
  Result:=(Name='verbatim') or (Name='verbatim*') or (Name='Verbatim') or (Name='Verbatim*') or
    (Name='BVerbatim') or (Name='LVerbatim') or (Name='SaveVerbatim') or (Name='VerbatimOut') or
    (Name='lstlisting') or (Name='minted') or (Name='codeexample') or
    (Name='filecontents') or (Name='filecontents*') or (ExtensionCodeLanguage(Name)<>'');
end;
function SkipTeXLiteral(const Source:string; var Position:Integer):Boolean;
var P,Q:Integer; Command,Name,Ending:string; Delimiter:Char;
begin
  Result:=False; P:=Position; Command:=ReadTeXCommand(Source,P);
  if (Command='verb') or (Command='Verb') or (Command='lstinline') then begin
    if Copy(Source,P,1)='*' then Inc(P);
    if Command<>'verb' then ReadTeXGroup(Source,P,'[',']');
    if P>Length(Source) then begin Position:=P; Exit(True); end;
    if (Command='lstinline') and (Source[P]='{') then begin ReadTeXGroup(Source,P,'{','}',True); Position:=P; Exit(True); end;
    Delimiter:=Source[P]; Inc(P);
    while (P<=Length(Source)) and not (Source[P] in [Delimiter,#10,#13]) do Inc(P);
    if (P<=Length(Source)) and (Source[P]=Delimiter) then Inc(P);
    Position:=P; Exit(True);
  end;
  if Command<>'begin' then Exit; Name:=ReadTeXGroup(Source,P,'{','}');
  if not IsTeXVerbatimEnvironment(Name) then Exit;
  Ending:='\end{'+Name+'}'; Q:=Pos(Ending,Copy(Source,P,MaxInt));
  if Q=0 then Position:=Length(Source)+1 else Position:=P+Q-1+Length(Ending);
  Result:=True;
end;
function TopLevelDelimiter(const Source:string; Delimiter:Char; Start:Integer=1):Integer;
var P,Braces,Brackets:Integer;
begin
  Result:=0; P:=Start; Braces:=0; Brackets:=0;
  while P<=Length(Source) do begin
    if Source[P]='\' then begin ReadTeXCommand(Source,P); Continue; end;
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if (Source[P]=Delimiter) and (Braces=0) and (Brackets=0) then Exit(P);
    case Source[P] of '{':Inc(Braces); '}':if Braces>0 then Dec(Braces); '[':Inc(Brackets); ']':if Brackets>0 then Dec(Brackets); end;
    Inc(P);
  end;
end;
function ReadTeXRuleDimension(const Source:string; var Position:Integer; out Name,Value:string):Boolean;
const Keywords:array[0..2] of string=('width','height','depth');
var P,A:Integer; Key:string;
begin
  Result:=False; Name:=''; Value:=''; P:=Position; SkipTeXSpace(Source,P);
  for Key in Keywords do if Copy(Source,P,Length(Key))=Key then begin Name:=Key; Break; end;
  if Name='' then Exit;
  Inc(P,Length(Name)); SkipTeXSpace(Source,P); A:=P;
  while (P<=Length(Source)) and (Source[P] in ['0'..'9','.','+','-']) do Inc(P);
  SkipTeXSpace(Source,P);
  if Copy(Source,P,1)='\' then ReadTeXCommand(Source,P)
  else while (P<=Length(Source)) and (Source[P] in ['a'..'z']) do Inc(P);
  Value:=StringReplace(Trim(Copy(Source,A,P-A)),' ','',[rfReplaceAll]);
  Position:=P; Result:=True;
end;
function TeXContextDeclarations(const Source:string):string;
var P,A,Q,I,Arguments,First,After:Integer; Command,Literal:string; Font:TDocumentFont;
begin
  Result:=''; P:=1;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    { Local groups do not change the following paragraph's text style. }
    if Source[P]='{' then begin ReadTeXGroup(Source,P,'{','}'); Continue; end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    A:=P; Q:=P;
    if ReadEngineConditional(Source,'pdflatex',Q,First,After) then begin
      Result:=Result+Copy(Source,A,Q-A)+LineEnding; P:=Q; Continue;
    end;
    if ReadDocumentFont(Source,Q,Font) then begin Result:=Result+Copy(Source,A,Q-A)+LineEnding; P:=Q; Continue; end;
    if ReadTeXDefinition(Source,Q) then begin Result:=Result+Copy(Source,A,Q-A)+LineEnding; P:=Q; Continue; end;
    Command:=ReadTeXCommand(Source,P); Arguments:=-1;
    if (Command='sbox') or (Command='savebox') or (Command='newsavebox') then begin
      SkipTeXSpace(Source,P);
      if Copy(Source,P,1)='{' then ReadTeXGroup(Source,P,'{','}')
      else if Copy(Source,P,1)='\' then ReadTeXCommand(Source,P) else if P<=Length(Source) then Inc(P);
      if Command='savebox' then begin ReadTeXGroup(Source,P,'[',']'); ReadTeXGroup(Source,P,'[',']'); end;
      if Command<>'newsavebox' then ReadTeXGroup(Source,P,'{','}');
      Result:=Result+Copy(Source,A,P-A)+LineEnding; Continue;
    end;
    case Command of
      'begin':begin
        Literal:=ReadTeXGroup(Source,P,'{','}');
        if IsTeXVerbatimEnvironment(Literal) then begin
          Literal:='\end{'+Literal+'}'; Q:=Pos(Literal,Copy(Source,P,MaxInt));
          if Q=0 then P:=Length(Source)+1 else Inc(P,Q-1+Length(Literal));
        end;
      end;
      'input','include','subfile','subfileinclude','ctexset','linespread','sisetup','tikzset','pgfplotsset','tcbset','lstset','setlist','hypersetup','arrayrulecolor':Arguments:=1;
      'definecolor','providecolor','rowcolors':Arguments:=3;
      'colorlet':Arguments:=2;
      'lstdefinestyle','lstdefinelanguage':Arguments:=2;
      'setlength','fontsize','setcounter','addtocounter':Arguments:=2;
      'appendix','frontmatter','mainmatter','backmatter':Arguments:=0;
      'titleformat':Arguments:=5;
      'titlespacing':Arguments:=4;
      'rm','sf','tt','bf','it','sl','sc','bfseries','mdseries','itshape','slshape','scshape','upshape','normalfont','rmfamily','sffamily','ttfamily',
      'tiny','scriptsize','footnotesize','small','normalsize','large','Large','LARGE','huge','Huge','selectfont':Arguments:=0;
      'verb':begin
        if Copy(Source,P,1)='*' then Inc(P);
        if P<=Length(Source) then begin Command:=Source[P]; Inc(P); while (P<=Length(Source)) and (Source[P]<>Command) do Inc(P); Inc(P); end;
      end;
    end;
    if Arguments<0 then Continue;
    if Copy(Source,P,1)='*' then Inc(P);
    for I:=1 to Arguments do begin
      SkipTeXSpace(Source,P); if Copy(Source,P,1)='[' then ReadTeXGroup(Source,P,'[',']');
      SkipTeXSpace(Source,P);
      if Copy(Source,P,1)='{' then ReadTeXGroup(Source,P,'{','}') else begin
        Q:=P; while (P<=Length(Source)) and not (Source[P] in [' ',#9,#10,#13,'\','{','}']) do Inc(P);
        if P=Q then Break;
      end;
    end;
    Result:=Result+Copy(Source,A,P-A)+LineEnding;
  end;
end;
function TeXHeaderLength(const Source:string):Integer;
var P,Q:Integer; Command:string;
begin
  P:=1; Result:=0;
  while P<=Length(Source) do begin
    SkipTeXSpace(Source,P); if P>Length(Source) then Break;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) or SkipTeXBibResource(Source,Q) then begin P:=Q; Continue; end;
    Command:=ReadTeXCommand(Source,P);
    if (Command='begin') and (ReadTeXGroup(Source,P,'{','}')='document') then Exit(P-1);
  end;
end;
destructor TRegistryCache.Destroy;
begin Registry.Free; Stamps.Free; inherited Destroy; end;
function SourceStamp(const Path,Root:string):string;
var Search:TSearchRec; Text:string; I:Integer; Hash:LongWord;
begin
  Result:=''; if (Path='') or (FindFirst(Path,faAnyFile,Search)<>0) then Exit;
  FindClose(Search); Result:=IntToStr(Search.Time)+':'+IntToStr(Search.Size);
  { Local packages can be edited twice within a filesystem timestamp tick. }
  if Pos(Root,Path)=1 then begin
    Text:=ReadTeXSource(Path,True); Hash:=0;
    for I:=1 to Length(Text) do Hash:=((Hash shl 5) or (Hash shr 27)) xor Ord(Text[I]);
    Result:=Result+':'+IntToStr(Hash);
  end;
end;
function CacheValid(Entry:TRegistryCache):Boolean;
var I,P:Integer; Key,Name,Directory,Path:string;
begin
  Result:=False;
  for I:=0 to Entry.Registry.FImports.Count-1 do begin
    Key:=Entry.Registry.FImports.Names[I]; P:=Pos('|',Key);
    Directory:=Copy(Key,1,P-1); Name:=Copy(Key,P+1,MaxInt);
    Path:=Entry.Registry.FSourceDirectory+Name;
    if FileExists(Path) then Path:=ExpandFileName(Path) else Path:=ResolveTeXSource(Name,Directory);
    if Path<>Entry.Registry.FImports.ValueFromIndex[I] then Exit;
    if SourceStamp(Path,Entry.Registry.FSourceDirectory)<>Entry.Stamps[I] then Exit;
  end;
  Result:=True;
end;
function TeXPackageFont(const Encoding,Family,Directory:string):string;
var Definition:string; R:TRegExpr;
begin
  Result:=Family+'10';
  case Family of 'cmm':Exit('cmmi10'); 'msa':Exit('msam10'); 'msb':Exit('msbm10'); end;
  Definition:=ReadTeXSource(ResolveTeXSource(Encoding+Family+'.fd',Directory));
  if Definition='' then Definition:=ReadTeXSource(ResolveTeXSource(LowerCase(Encoding+Family)+'.fd',Directory));
  if Definition='' then Exit;
  R:=TRegExpr.Create;
  try
    R.Expression:='gen\s*\*\s*([a-zA-Z][a-zA-Z0-9_-]*)';
    if R.Exec(Definition) then Exit(R.Match[1]+'10');
    R.Expression:='\b([a-zA-Z][a-zA-Z0-9_-]*10)\b';
    if R.Exec(Definition) then Exit(R.Match[1]);
    R.Expression:='\\DeclareFontShape\s*\{[^{}]+\}\s*\{[^{}]+\}\s*\{m\}\s*\{n\}\s*\{[^{}]*>\s*([a-zA-Z][a-zA-Z0-9_-]*)';
    if R.Exec(Definition) then Result:=R.Match[1];
  finally R.Free; end;
end;
function SimplePackageBody(const Body:string):Boolean;
var P,Q:Integer; Cmd:string;
begin
  Result:=Length(Body)<=8192; if not Result then Exit;
  P:=1;
  while P<=Length(Body) do begin
    if Body[P]='%' then begin while (P<=Length(Body)) and (Body[P]<>#10) do Inc(P); Continue; end;
    if Body[P]<>'\' then begin Inc(P); Continue; end;
    Cmd:=ReadTeXCommand(Body,P);
    Q:=P; while (Q<=Length(Body)) and (Body[Q] in ['a'..'z','A'..'Z','_',':']) do Inc(Q);
    if (Copy(Body,P,2)='__') or (Pos(':',Copy(Body,P,Q-P))>0) then Exit(False);
    if (Pos('@',Cmd)>0) or (Pos('if',Cmd)=1) or (Cmd='else') or (Cmd='fi') or
      (Cmd='csname') or (Cmd='endcsname') or (Cmd='catcode') or (Cmd='let') or
      (Cmd='def') or (Cmd='edef') or (Cmd='gdef') or (Cmd='xdef') or (Cmd='futurelet') or
      (Cmd='expandafter') or (Cmd='noexpand') or (Cmd='protect') or (Cmd='DeclareRobustCommand') or
      (Cmd='newcommand') or (Cmd='newenvironment') or (Cmd='setbox') or (Cmd='box') or
      (Cmd='hbox') or (Cmd='vbox') or (Cmd='vtop') or (Cmd='halign') or (Cmd='ialign') or
      (Cmd='raise') or (Cmd='lower') or (Cmd='advance') or (Cmd='multiply') or
      (Cmd='divide') or (Cmd='input') or (Cmd='include') or (Cmd='write') or
      (Cmd='special') or (Cmd='loop') or (Cmd='repeat') or (Cmd='begingroup') or
      (Cmd='endgroup') or (Cmd='dimexpr') or (Cmd='numexpr') or (Cmd='nobreak') or
      (Cmd='penalty') or (Cmd='hskip') or (Cmd='vskip') or (Cmd='mskip') or
      (Cmd='kern') or (Cmd='mkern') or (Cmd='nonscript') or (Cmd='leavevmode') or
      (Cmd='unhbox') or (Cmd='unhcopy') or (Cmd='vcenter') or (Cmd='vrule') or
      (Cmd='hrule') or (Cmd='aftergroup') or (Cmd='afterassignment') then Exit(False);
  end;
end;
procedure SkipTeXSpace(const S: string; var P: Integer);
begin
  while P<=Length(S) do
    if S[P] in [' ',#9,#10,#13] then Inc(P)
    else if S[P]='%' then
      while (P<=Length(S)) and (S[P]<>#10) do Inc(P)
    else Break;
end;
function ReadTeXCommand(const S: string; var P: Integer): string;
var A:Integer;
begin
  Result:=''; if (P>Length(S)) or (S[P]<>'\') then Exit;
  Inc(P); A:=P;
  if (P<=Length(S)) and (S[P] in ['a'..'z','A'..'Z','@']) then
    while (P<=Length(S)) and (S[P] in ['a'..'z','A'..'Z','@']) do Inc(P)
  else if P<=Length(S) then Inc(P);
  Result:=Copy(S,A,P-A);
end;
function EndsTeXControlWord(const Text:string):Boolean;
var Q,Slashes:SizeInt;
begin
  Q:=Length(Text); Result:=False;
  if (Q=0) or not (Text[Q] in ['a'..'z','A'..'Z','@']) then Exit;
  while (Q>0) and (Text[Q] in ['a'..'z','A'..'Z','@']) do Dec(Q);
  Slashes:=0; while (Q>0) and (Text[Q]='\') do begin Inc(Slashes); Dec(Q); end;
  Result:=Odd(Slashes);
end;
function SubstituteTeXParameters(const Template:string; const Arguments:array of string;
  out Expanded:string; Limit:Integer):Boolean;
var P,A,Count,Index,Total,Destination,Pass,Separator,I:SizeInt;
    WordEnd,TrailingWord:Boolean; ArgumentWordEnd:array[0..8] of Boolean;
  procedure Segment;
  begin
    A:=P; Index:=-1; WordEnd:=False;
    case Template[P] of
      '\':begin
        Inc(P);
        if (P<=Length(Template)) and (Template[P] in ['a'..'z','A'..'Z','@']) then begin
          while (P<=Length(Template)) and (Template[P] in ['a'..'z','A'..'Z','@']) do Inc(P);
          WordEnd:=True;
        end
        else if P<=Length(Template) then Inc(P);
      end;
      '%':while (P<=Length(Template)) and not (Template[P] in [#10,#13]) do Inc(P);
      '#':begin
        if (P<Length(Template)) and (Template[P+1]='#') then begin Inc(P); A:=P; Inc(P); end
        else if (P<Length(Template)) and (Template[P+1] in ['1'..'9']) and
          (Ord(Template[P+1])-Ord('1')<Length(Arguments)) then begin
          Index:=Ord(Template[P+1])-Ord('1'); Inc(P,2);
        end else Inc(P);
      end;
      else begin
        Inc(P); while (P<=Length(Template)) and not (Template[P] in ['\','%','#']) do Inc(P);
      end;
    end;
    Count:=P-A; Separator:=0;
    if Index>=0 then begin
      Count:=Length(Arguments[Index]); WordEnd:=ArgumentWordEnd[Index];
      if (Count>0) and TrailingWord and (Arguments[Index][1] in ['a'..'z','A'..'Z','@']) then Separator:=1;
    end else if TrailingWord and (Template[A] in ['a'..'z','A'..'Z','@']) then Separator:=1;
  end;
begin
  Result:=False; Expanded:=''; if Limit<0 then Exit;
  { TeX substitutes parameter tokens, not text inside control symbols or
    arguments already inserted. Separate joined control words and measure
    first to bound allocation. }
  for I:=0 to High(ArgumentWordEnd) do
    if I<Length(Arguments) then ArgumentWordEnd[I]:=EndsTeXControlWord(Arguments[I]);
  Total:=0; Destination:=1;
  for Pass:=1 to 2 do begin
    P:=1; TrailingWord:=False;
    while P<=Length(Template) do begin
      Segment;
      if Pass=1 then begin
        if Count+Separator>Limit-Total then Exit; Inc(Total,Count+Separator);
      end else if Count>0 then begin
        if Separator>0 then begin Expanded[Destination]:=' '; Inc(Destination); end;
        if Index>=0 then Move(Arguments[Index][1],Expanded[Destination],Count)
        else Move(Template[A],Expanded[Destination],Count);
        Inc(Destination,Count);
      end;
      if Count>0 then TrailingWord:=WordEnd;
    end;
    { A final control word must also remain separate from following source. }
    if TrailingWord then
      if Pass=1 then begin if Total=Limit then Exit; Inc(Total); end
      else Expanded[Destination]:=' ';
    if Pass=1 then SetLength(Expanded,Total);
  end;
  Result:=True;
end;
function ReadTeXGroup(const S: string; var P: Integer; OpenChar, CloseChar: Char; Literal:Boolean): string;
var A,D,Braces:Integer;
begin
  Result:=''; SkipTeXSpace(S,P);
  if (P>Length(S)) or (S[P]<>OpenChar) then Exit;
  Inc(P); A:=P; D:=1; Braces:=0;
  while P<=Length(S) do
  begin
    if S[P]='\' then begin Inc(P); if P<=Length(S) then Inc(P); Continue; end;
    if (S[P]='%') and not Literal then
    begin while (P<=Length(S)) and (S[P]<>#10) do Inc(P); Continue; end;
    { Braced tokens protect an optional argument's delimiters. }
    if OpenChar<>'{' then begin
      if S[P]='{' then Inc(Braces)
      else if (S[P]='}') and (Braces>0) then Dec(Braces);
    end;
    if Braces=0 then
      if S[P]=OpenChar then Inc(D)
      else if S[P]=CloseChar then Dec(D);
    if D=0 then begin Result:=Copy(S,A,P-A); Inc(P); Exit; end;
    Inc(P);
  end;
  Result:=Copy(S,A,MaxInt);
end;
function ReadTeXArgument(const Source:string; var Position:Integer; Literal:Boolean):string;
var First:Integer;
begin
  SkipTeXSpace(Source,Position); Result:=''; if Position>Length(Source) then Exit;
  if Source[Position]='{' then Exit(ReadTeXGroup(Source,Position,'{','}',Literal));
  if Source[Position]='\' then Exit('\'+ReadTeXCommand(Source,Position));
  First:=Position; Inc(Position);
  while (Position<=Length(Source)) and (Byte(Source[Position]) and $C0=$80) do Inc(Position);
  Result:=Copy(Source,First,Position-First);
end;
function SkipTeXBibResource(const S:string; var P:Integer):Boolean;
var Q:Integer; Command:string;
begin
  Result:=False; Q:=P; Command:=ReadTeXCommand(S,Q);
  if (Command<>'addbibresource') and (Command<>'addglobalbib') and (Command<>'addsectionbib') then Exit;
  SkipTeXSpace(S,Q); if Copy(S,Q,1)='[' then ReadTeXGroup(S,Q,'[',']');
  { biblatex changes catcodes for resource names: percent is literal. }
  ReadTeXGroup(S,Q,'{','}',True); P:=Q; Result:=True;
end;
function ReadTeXDefinition(const S:string; var P:Integer):Boolean;
var Q:Integer; Cmd:string;
  procedure NameToken;
  begin
    SkipTeXSpace(S,Q);
    if Copy(S,Q,1)='{' then ReadTeXGroup(S,Q,'{','}')
    else if Copy(S,Q,1)='\' then ReadTeXCommand(S,Q)
    else if Q<=Length(S) then Inc(Q);
  end;
begin
  Result:=False; Q:=P; Cmd:=ReadTeXCommand(S,Q);
  if not ((Cmd='def') or (Cmd='gdef') or (Cmd='edef') or (Cmd='xdef') or
    (Cmd='newcommand') or (Cmd='renewcommand') or (Cmd='providecommand') or
    (Cmd='newrobustcmd') or (Cmd='renewrobustcmd') or (Cmd='providerobustcmd') or
    (Cmd='DeclareRobustCommand') or (Cmd='DeclareMathOperator') or
    (Cmd='NewDocumentCommand') or (Cmd='RenewDocumentCommand') or (Cmd='DeclareDocumentCommand') or
    (Cmd='ProvideDocumentCommand') or (Cmd='DeclarePairedDelimiter') or (Cmd='let') or
    (Cmd='undef') or (Cmd='csundef') or (Cmd='UndefineDocumentCommand')) then Exit;
  if Copy(S,Q,1)='*' then Inc(Q);
  NameToken;
  if (Cmd='undef') or (Cmd='csundef') or (Cmd='UndefineDocumentCommand') then begin P:=Q; Exit(True); end;
  if Cmd='let' then begin
    SkipTeXSpace(S,Q); if Copy(S,Q,1)='=' then Inc(Q); NameToken;
  end else if (Cmd='def') or (Cmd='gdef') or (Cmd='edef') or (Cmd='xdef') then begin
    while (Q<=Length(S)) and (S[Q]<>'{') do begin
      if S[Q]='%' then while (Q<=Length(S)) and (S[Q]<>#10) do Inc(Q) else Inc(Q);
    end;
    ReadTeXGroup(S,Q,'{','}');
  end else if Cmd='DeclarePairedDelimiter' then begin
    ReadTeXGroup(S,Q,'{','}'); ReadTeXGroup(S,Q,'{','}');
  end else begin
    if Pos('DocumentCommand',Cmd)>0 then ReadTeXGroup(S,Q,'{','}')
    else begin
      SkipTeXSpace(S,Q);
      while Copy(S,Q,1)='[' do begin ReadTeXGroup(S,Q,'[',']'); SkipTeXSpace(S,Q); end;
    end;
    ReadTeXGroup(S,Q,'{','}');
  end;
  P:=Q; Result:=True;
end;
function ReadTeXEnvironmentDefinition(const S:string; var P:Integer):Boolean;
var Q:Integer; Command:string;
  procedure Optional;
  var EndAt:Integer;
  begin
    EndAt:=Q; SkipTeXSpace(S,EndAt);
    if Copy(S,EndAt,1)='[' then begin ReadTeXGroup(S,EndAt,'[',']'); Q:=EndAt; end;
  end;
begin
  Q:=P; Command:=ReadTeXCommand(S,Q);
  Result:=(Command='newenvironment') or (Command='renewenvironment') or (Command='provideenvironment') or
    (Command='NewDocumentEnvironment') or (Command='RenewDocumentEnvironment') or
    (Command='ProvideDocumentEnvironment') or (Command='DeclareDocumentEnvironment') or (Command='newtheorem');
  if not Result then Exit;
  if Copy(S,Q,1)='*' then Inc(Q);
  ReadTeXGroup(S,Q,'{','}');
  if Pos('DocumentEnvironment',Command)>0 then ReadTeXGroup(S,Q,'{','}')
  else begin Optional; if Command<>'newtheorem' then Optional; end;
  ReadTeXGroup(S,Q,'{','}');
  if Command='newtheorem' then Optional else ReadTeXGroup(S,Q,'{','}');
  P:=Q;
end;
function ContainsTeXDefinitions(const S:string):Boolean;
var P,Q:Integer;
begin
  Result:=False; P:=1;
  while P<=Length(S) do begin
    if S[P]='%' then begin while (P<=Length(S)) and (S[P]<>#10) do Inc(P); Continue; end;
    if S[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(S,Q) then Exit(True);
    ReadTeXCommand(S,P);
  end;
end;
function TeXDefinitionName(const S:string):string;
var P:Integer;
begin
  P:=1; ReadTeXCommand(S,P); if Copy(S,P,1)='*' then Inc(P); SkipTeXSpace(S,P);
  if Copy(S,P,1)='{' then begin
    Result:=Trim(ReadTeXGroup(S,P,'{','}')); P:=1; Result:=ReadTeXCommand(Result,P);
  end else Result:=ReadTeXCommand(S,P);
end;
constructor TMacroInfo.Create;
begin inherited Create; FReferences:=1; end;
function TMacroInfo.ArgumentKind(Index:Integer; out DefaultValue:string):Char;
var P,N:Integer; Kind:Char; Value:string;
begin
  Result:='m'; DefaultValue:='';
  if Signature='' then begin
    if (Index=1) and OptionalFirst then begin Result:='O'; DefaultValue:=DefaultArgument; end;
    Exit;
  end;
  P:=1; N:=0;
  while P<=Length(Signature) do begin
    SkipTeXSpace(Signature,P); if P>Length(Signature) then Break;
    Kind:=Signature[P]; Inc(P); Value:='';
    if not (Kind in ['m','o','O']) then Continue;
    Inc(N); if Kind='O' then Value:=ReadTeXGroup(Signature,P,'{','}');
    if N=Index then begin Result:=Kind; DefaultValue:=Value; if Kind='o' then DefaultValue:='\NoValue'; Exit; end;
  end;
end;
procedure TMacroInfo.Retain;
begin Inc(FReferences); end;
procedure TMacroInfo.Release;
begin Dec(FReferences); if FReferences=0 then Free; end;
constructor TMacroRegistry.Create;
begin
  FItems:=TStringList.Create; FItems.CaseSensitive:=True; FItems.UseLocale:=False; FItems.Sorted:=True;
  FVisited:=TStringList.Create; FVisited.CaseSensitive:=FileNameCaseSensitive; FVisited.UseLocale:=False;
  FImports:=TStringList.Create; FImports.CaseSensitive:=True; FImports.UseLocale:=False; FImports.NameValueSeparator:=#0;
  FTheorems:=TStringList.Create; FTheorems.CaseSensitive:=True; FTheorems.UseLocale:=False;
  FEnvironments:=TStringList.Create; FEnvironments.CaseSensitive:=True; FEnvironments.UseLocale:=False;
  FSymbolFonts:=TStringList.Create; FSymbolFonts.CaseSensitive:=True; FSymbolFonts.UseLocale:=False;
  FSavedBoxes:=TStringList.Create; FSavedBoxes.CaseSensitive:=True; FSavedBoxes.NameValueSeparator:=#1;
end;
destructor TMacroRegistry.Destroy;
var I:Integer;
begin
  FSavedBoxes.Free;
  for I:=0 to FItems.Count-1 do TMacroInfo(FItems.Objects[I]).Release;
  FItems.Free; FVisited.Free; FImports.Free; FTheorems.Free; FEnvironments.Free; FSymbolFonts.Free; inherited Destroy;
end;
procedure TMacroRegistry.Load(const Source,Directory,Engine:string);
var I,N:Integer; Header,Key,Root:string; Entry:TRegistryCache;
  procedure LoadBody;
  var Base:QWord; J:Integer;
  begin
    if N>=Length(Source) then Exit; Base:=FRevision;
    Scan(Copy(Source,N+1,MaxInt),Directory,0);
    { Identical declarations must share a style-cache key across preview cards.
      The header revision still changes when an imported package changes. }
    {$push}{$Q-}{$R-}
    for J:=N+1 to Length(Source) do Base:=(Base xor Byte(Source[J]))*QWord(1099511628211);
    {$pop}
    FRevision:=Base;
  end;
begin
  N:=TeXHeaderLength(Source); if N=0 then N:=Length(Source);
  Header:=Copy(Source,1,N); Root:=IncludeTrailingPathDelimiter(ExpandFileName(Directory)); Key:=Root+#0+Engine+#0+IntToStr(ExtensionSyntaxRevision)+#0+Header;
  for I:=RegistryCache.Count-1 downto 0 do begin
    Entry:=TRegistryCache(RegistryCache[I]); if Entry.Key<>Key then Continue;
    if CacheValid(Entry) then begin
      Assign(Entry.Registry); LoadBody; Exit;
    end;
    RegistryCache.Delete(I); Break;
  end;
  for I:=0 to FItems.Count-1 do TMacroInfo(FItems.Objects[I]).Release;
  FItems.Clear; FVisited.Clear; FImports.Clear; FTheorems.Clear; FEnvironments.Clear; FSymbolFonts.Clear; FSavedBoxes.Clear; FReadBytes:=0; FDefinitions:='';
  Inc(RegistryRevision); FRevision:=RegistryRevision;
  FSourceDirectory:=Root; FEngine:=Engine; FPresentation:=False;
  FSymbolFonts.Values['operators']:='cmr10'; FSymbolFonts.Values['letters']:='cmmi10';
  FSymbolFonts.Values['symbols']:='cmsy10'; FSymbolFonts.Values['largesymbols']:='cmex10';
  InstallPackagePreview('latex','latex.ltx');
  Scan(Header,Directory,0);
  if Length(Header)<=65536 then begin
    Entry:=TRegistryCache.Create; Entry.Key:=Key; Entry.Registry:=Clone; Entry.Stamps:=TStringList.Create;
    for I:=0 to FImports.Count-1 do Entry.Stamps.Add(SourceStamp(FImports.ValueFromIndex[I],Root));
    if RegistryCache.Count>=4 then RegistryCache.Delete(0); RegistryCache.Add(Entry);
  end;
  LoadBody;
end;
function TMacroRegistry.Clone:TMacroRegistry;
begin
  Result:=TMacroRegistry.Create; Result.Assign(Self);
end;
procedure TMacroRegistry.Assign(Other:TMacroRegistry);
var I:Integer;
begin
  if Other=Self then Exit;
  for I:=0 to FItems.Count-1 do TMacroInfo(FItems.Objects[I]).Release;
  FItems.Assign(Other.FItems);
  for I:=0 to FItems.Count-1 do TMacroInfo(FItems.Objects[I]).Retain;
  FVisited.Assign(Other.FVisited); FImports.Assign(Other.FImports); FTheorems.Assign(Other.FTheorems);
  FEnvironments.Assign(Other.FEnvironments);
  FSymbolFonts.Assign(Other.FSymbolFonts); FDefinitions:=Other.FDefinitions;
  FSavedBoxes.Assign(Other.FSavedBoxes);
  FReadBytes:=Other.FReadBytes; FSourceDirectory:=Other.FSourceDirectory; FRevision:=Other.FRevision; FEngine:=Other.FEngine;
  FPresentation:=Other.FPresentation;
end;
procedure TMacroRegistry.ApplyDefinitions(const Source:string);
begin Scan(Source,FSourceDirectory,0); end;
function TMacroRegistry.SavedBox(const Name:string):string;
begin Result:=FSavedBoxes.Values[Trim(Name)]; end;
function TMacroRegistry.FreezeBox(const Value:string; Depth:Integer):string;
var P,Q,A,I:Integer; Command,Body,DefaultValue,Expanded:string; Info:TMacroInfo; Local:TMacroRegistry;
    Arguments:array[1..9] of string;
begin
  Result:=Value; if (Depth>=16) or (Length(Value)>65536) then Exit;
  Result:=''; P:=1;
  while P<=Length(Value) do begin
    A:=P;
    if Value[P]='%' then begin
      while (P<=Length(Value)) and (Value[P]<>#10) do Inc(P);
      Result:=Result+Copy(Value,A,P-A); Continue;
    end;
    if Value[P]='{' then begin
      Body:=ReadTeXGroup(Value,P,'{','}'); Result:=Result+'{'+FreezeBox(Body,Depth+1)+'}'; Continue;
    end;
    if Value[P]<>'\' then begin Result:=Result+Value[P]; Inc(P); Continue; end;
    Q:=P;
    if ReadTeXDefinition(Value,Q) then begin
      Local:=Clone;
      try
        Local.ApplyDefinitions(Copy(Value,P,Q-P));
        Result:=Result+Copy(Value,P,Q-P)+Local.FreezeBox(Copy(Value,Q,MaxInt),Depth+1);
      finally Local.Free; end;
      Exit;
    end;
    Command:=ReadTeXCommand(Value,P);
    if Command='usebox' then begin Result:=Result+SavedBox(ReadTeXArgument(Value,P)); Continue; end;
    Info:=Find(Command);
    if (Info=nil) or not Info.Expandable or Info.Undefined or (Info.PackageSource<>'') or
       (Info.PreviewName<>'') or (Info.Body='') or (Info.ArgCount>9) then begin
      Result:=Result+Copy(Value,A,P-A); Continue;
    end;
    for I:=1 to Info.ArgCount do begin
      if Info.ArgumentKind(I,DefaultValue) in ['o','O'] then begin
        Q:=P; SkipTeXSpace(Value,Q);
        if Copy(Value,Q,1)='[' then begin P:=Q; Arguments[I]:=ReadTeXGroup(Value,P,'[',']'); end
        else Arguments[I]:=DefaultValue;
      end else Arguments[I]:=ReadTeXArgument(Value,P);
    end;
    if not SubstituteTeXParameters(Info.Body,Slice(Arguments,Info.ArgCount),Expanded) then Exit(Value);
    Result:=Result+FreezeBox(Expanded,Depth+1);
    if Length(Result)>65536 then Exit(Value);
  end;
end;
procedure TMacroRegistry.InstallPackagePreview(const Name,Path:string);
var Specs,Parts:TStringList; I,J,P:Integer; Info:TMacroInfo;
begin
  Specs:=TStringList.Create; Parts:=TStringList.Create;
  try
    PackagePreviewCommands(ChangeFileExt(ExtractFileName(Name),''),Specs);
    Parts.StrictDelimiter:=True; Parts.Delimiter:=#9;
    for I:=0 to Specs.Count-1 do begin
      Parts.DelimitedText:=Specs[I]; if Parts.Count<>4 then Continue;
      Info:=TMacroInfo.Create; Info.Name:=Parts[0]; Info.Signature:=Parts[1];
      Info.Body:=Parts[2]; Info.PreviewAdapter:=Parts[3]; Info.PackageSource:=Path; Info.Expandable:=True;
      Info.PreviewName:=Info.Name;
      P:=1;
      while P<=Length(Info.Signature) do begin
        if Info.Signature[P] in ['m','o','O'] then begin
          Inc(Info.ArgCount); if (Info.ArgCount=1) and (Info.Signature[P]<>'m') then Info.OptionalFirst:=True;
        end;
        if Info.Signature[P]='O' then begin Inc(P); ReadTeXGroup(Info.Signature,P,'{','}'); end else Inc(P);
      end;
      J:=FItems.IndexOf(Info.Name);
      if J>=0 then begin TMacroInfo(FItems.Objects[J]).Release; FItems.Objects[J]:=Info; end
      else FItems.AddObject(Info.Name,Info);
      Inc(RegistryRevision); FRevision:=RegistryRevision;
    end;
  finally Parts.Free; Specs.Free; end;
end;
function TMacroRegistry.Find(const Name:string):TMacroInfo;
var I:Integer; Base:string;
begin
  I:=FItems.IndexOf(Name); Result:=nil;
  if I>=0 then Result:=TMacroInfo(FItems.Objects[I]);
  if (Result=nil) and (Copy(Name,Length(Name),1)='*') then begin
    Base:=Copy(Name,1,Length(Name)-1); I:=FItems.IndexOf(Base);
    if (I>=0) and (TMacroInfo(FItems.Objects[I]).PreviewAdapter='derivative') then Result:=TMacroInfo(FItems.Objects[I]);
  end;
end;
function TMacroRegistry.RequiresLiteralArguments(const Name:string):Boolean;
var Budget:Integer;
  function UsesNative(const Name:string; Depth:Integer):Boolean;
  var Info:TMacroInfo; P,Q:Integer; Command:string;
  begin
    Result:=False; if (Depth>12) or (Budget<=0) then Exit; Dec(Budget);
    Info:=Find(Name); if Info=nil then Exit;
    if Info.PreviewName<>'' then Exit(True);
    if not Info.Expandable or Info.Undefined or (Length(Info.Body)>65536) then Exit;
    P:=1;
    while P<=Length(Info.Body) do begin
      if Info.Body[P]='%' then begin while (P<=Length(Info.Body)) and (Info.Body[P]<>#10) do Inc(P); Continue; end;
      if Info.Body[P]<>'\' then begin Inc(P); Continue; end;
      Q:=P; if ReadTeXDefinition(Info.Body,Q) or SkipTeXLiteral(Info.Body,Q) then begin P:=Q; Continue; end;
      Command:=ReadTeXCommand(Info.Body,P);
      if (Command<>Name) and UsesNative(Command,Depth+1) then Exit(True);
    end;
  end;
begin Budget:=64; Result:=UsesNative(Name,0); end;
function TMacroRegistry.IsTheorem(const Name:string):Boolean;
begin Result:=(FTheorems.IndexOf(Name)>=0) or (FPresentation and (BeamerTheoremStyle(Name)<>'')); end;
procedure TMacroRegistry.EnvironmentNames(Dest:TStrings);
var Name:string;
begin
  Dest.AddStrings(FTheorems); Dest.AddStrings(FEnvironments);
  if FPresentation then for Name in TStringArray.Create('frame','columns','column','block','alertblock','exampleblock',
    'overlayarea','overprint','onlyenv','uncoverenv','visibleenv','invisibleenv','actionenv',
    'theorem','corollary','fact','lemma','problem','solution','definition','example','proof') do
    if Dest.IndexOf(Name)<0 then Dest.Add(Name);
  for Name in FItems do
    if (Copy(Name,1,3)='end') and (Length(Name)>3) and (Find(Copy(Name,4,MaxInt))<>nil) and
      (Pos('@',Name)=0) and (Pos(':',Name)=0) then Dest.Add(Copy(Name,4,MaxInt));
end;
procedure TMacroRegistry.Names(Dest:TStrings);
var I:Integer;
begin Dest.Clear; for I:=0 to FItems.Count-1 do Dest.Add('\'+FItems[I]); end;
procedure TMacroRegistry.Scan(const Input,Directory:string; Depth:Integer; const PackagePath:string);
var P,A,Q,I,N,Count:Integer; Cmd,Name,Value,Path,Spec,Imported,Font,Family,Slot,Parameters,Encoding,ImportName:string;
    M,Target:TMacroInfo; S:TStringList; PackageFile,Delimiters,NativeAlias,OperatorStar:Boolean; PackageOptions,Conditional:string;
    FontDeclaration:TDocumentFont; Source:string;
  function Token:string;
  begin
    SkipTeXSpace(Source,P);
    if Copy(Source,P,1)='{' then Exit(ReadTeXGroup(Source,P,'{','}'));
    if Copy(Source,P,1)='\' then Exit('\'+ReadTeXCommand(Source,P));
    Result:=Copy(Source,P,1); if Result<>'' then Inc(P);
  end;
  procedure StoreMacro;
  var TokenSource,NativeFamily,NativeCommand,Encoding:string; TokenPos,NativeCode:Integer;
  begin
    M.PackageSource:=PackagePath;
    M.Expandable:=not M.Undefined and ((PackagePath='') or SimplePackageBody(M.Body));
    if (M.ArgCount<0) or (M.ArgCount>9) then begin M.ArgCount:=0; M.Expandable:=False; end;
    if (PackagePath<>'') and (Pos('@',Name)>0) and (M.GlyphFont='') then begin M.Free; Exit; end;
    if (PackagePath<>'') and (M.ArgCount<=9) then begin
      if (M.ArgCount>0) and (Pos('\char',M.Body)>0) then begin
        FSymbolFonts.Values['@'+Name]:=M.Body; FSymbolFonts.Values['?'+Name]:=IntToStr(M.ArgCount);
      end;
      TokenPos:=Pos('\fontencoding',M.Body);
      if TokenPos>0 then begin
        ReadTeXCommand(M.Body,TokenPos); Encoding:=ReadTeXGroup(M.Body,TokenPos,'{','}');
        TokenPos:=Pos('\fontfamily',M.Body);
        if TokenPos>0 then begin
          ReadTeXCommand(M.Body,TokenPos); NativeFamily:=ReadTeXGroup(M.Body,TokenPos,'{','}');
          if (M.ArgCount=1) and (NativeFamily='#1') then FSymbolFonts.Values['@font:'+Name]:=Encoding
          else if NativeFamily<>'' then FSymbolFonts.Values[Name]:=TeXPackageFont(Encoding,NativeFamily,Directory);
        end;
      end;
      TokenSource:=Trim(M.Body); TokenPos:=1; NativeCommand:=ReadTeXCommand(TokenSource,TokenPos);
      if (M.ArgCount=0) and ((Pos('\char',M.Body)>0) or (Pos('\hbox',M.Body)>0) or
        (Pos('\wasy@over',M.Body)>0) or (FSymbolFonts.Values['@'+NativeCommand]<>'')) then begin
        FontSymbolRun(M.Body,FSymbolFonts,M.GlyphPlan);
        FontSymbolRun(M.Body,FSymbolFonts,M.MathGlyphPlan,True);
        if M.MathGlyphPlan=M.GlyphPlan then M.MathGlyphPlan:='';
      end;
      if M.GlyphPlan<>'' then begin
        FSymbolFonts.Values['#'+Name]:=M.GlyphPlan;
        FSymbolFonts.Values['#math:'+Name]:=M.MathGlyphPlan;
      end;
    end;
    if not M.Undefined and (M.ArgCount=0) and (M.Body<>'') then begin
      TokenSource:=Trim(M.Body); TokenPos:=1; NativeCommand:=ReadTeXCommand(TokenSource,TokenPos);
      if (TokenPos>Length(TokenSource)) and TeXSymbol('\'+NativeCommand,NativeFamily,NativeCode) then begin
        M.NativeName:='\'+NativeCommand; M.SymbolClass:=TeXSymbolClass(M.NativeName);
      end;
    end;
    I:=FItems.IndexOf(Name);
    if (Cmd='providecommand') or (Cmd='providerobustcmd') or (Cmd='ProvideDocumentCommand') then
      if I>=0 then begin M.Free; Exit; end;
    Inc(RegistryRevision); FRevision:=RegistryRevision;
    if I>=0 then begin TMacroInfo(FItems.Objects[I]).Release; FItems.Objects[I]:=M; end
    else if FItems.Count<4096 then FItems.AddObject(Name,M) else M.Free;
  end;
begin
  if Depth>12 then Exit;
  Source:=ActiveTeXSource(Input,FEngine);
  P:=1;
  while P<=Length(Source) do
  begin
    SkipTeXSpace(Source,P); if P>Length(Source) then Break;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    if SkipTeXBibResource(Source,P) then Continue;
    Q:=P;
    if ReadDocumentFont(Source,Q,FontDeclaration) then begin
      P:=Q;
      if FontDeclaration.Alias<>'' then begin
        Cmd:=FontDeclaration.Command; Name:=FontDeclaration.Alias;
        Target:=Find(Name);
        if (Pos('provide',Cmd)=1) and (Target<>nil) and not Target.Undefined then Continue;
        M:=TMacroInfo.Create; M.Name:=Name;
        M.PreviewAdapter:='fontswitch';
        if Pos('CJK',Cmd)>0 then M.Body:='\CJKfamily{'+FontDeclaration.Family+'}'
        else M.Body:='\fontfamily{'+FontDeclaration.Family+'}\selectfont';
        StoreMacro;
      end;
      Continue;
    end;
    Q:=P;
    if (PackagePath='') and ReadEngineConditional(Source,FEngine,Q,A,Count,Self) then begin
      Scan(Copy(Source,A,Count-A),Directory,Depth+1); P:=Q; Continue;
    end;
    A:=P; Cmd:=ReadTeXCommand(Source,P);
    if (PackagePath<>'') and (Cmd='newif') then begin ReadTeXCommand(Source,P); Continue; end;
    if (ExtractFileName(PackagePath)='wasysym.sty') and
       ((Cmd='ifwasy@compatibility') or (Cmd='ifwasy@euro')) then begin
      Value:=','+FSymbolFonts.Values['!wasysym-options']+',';
      if ((Cmd='ifwasy@compatibility') and ((Pos(',nointegrals,',Value)>0) or (Pos(',integrals,',Value)>0))) or
         ((Cmd='ifwasy@euro') and (Pos(',noeuro,',Value)>0)) then begin
        N:=1;
        while (P<=Length(Source)) and (N>0) do begin
          SkipTeXSpace(Source,P);
          if Copy(Source,P,1)<>'\' then begin Inc(P); Continue; end;
          Conditional:=ReadTeXCommand(Source,P);
          if Copy(Conditional,1,2)='if' then Inc(N) else if Conditional='fi' then Dec(N);
        end;
      end;
      Continue;
    end;
    if (PackagePath<>'') and (Cmd='DeclareSymbolFont') then begin
      Name:=ReadTeXGroup(Source,P,'{','}'); Encoding:=ReadTeXGroup(Source,P,'{','}');
      Family:=ReadTeXGroup(Source,P,'{','}'); ReadTeXGroup(Source,P,'{','}'); ReadTeXGroup(Source,P,'{','}');
      Font:=TeXPackageFont(Encoding,Family,Directory);
      FSymbolFonts.Values[Name]:=Font; Continue;
    end;
    if (PackagePath<>'') and ((Cmd='DeclareMathSymbol') or (Cmd='DeclareMathDelimiter')) then begin
      Value:=Token; Q:=1; Name:=ReadTeXCommand(Value,Q);
      Spec:=Token; Family:=Token; Slot:=Token;
      Count:=StrToIntDef(Slot,-1); if Copy(Slot,1,1)='"' then Count:=StrToIntDef('$'+Copy(Slot,2,MaxInt),-1);
      Font:=FSymbolFonts.Values[Family]; Family:=''; N:=-1;
      if Cmd='DeclareMathDelimiter' then begin
        Family:=Token; Slot:=Token; N:=StrToIntDef(Slot,-1);
        if Copy(Slot,1,1)='"' then N:=StrToIntDef('$'+Copy(Slot,2,MaxInt),-1);
      end;
      if (Name='') or (Font='') or (Count<0) or (Count>255) then Continue;
      M:=TMacroInfo.Create; M.Name:=Name; M.GlyphFont:=Font; M.GlyphCode:=Count; M.SymbolClass:=Spec;
      if (N>=0) and (N<=255) then begin M.DelimiterFont:=FSymbolFonts.Values[Family]; M.DelimiterCode:=N; end;
      StoreMacro; Continue;
    end;
    if Cmd='let' then begin
      SkipTeXSpace(Source,P); Name:=ReadTeXCommand(Source,P); SkipTeXSpace(Source,P);
      if Copy(Source,P,1)='=' then begin Inc(P); SkipTeXSpace(Source,P); end;
      Value:=ReadTeXCommand(Source,P); if (Name='') or (Value='') or (Name=Value) then Continue;
      Target:=Find(Value); M:=TMacroInfo.Create; M.Name:=Name; M.Body:='\'+Value;
      NativeAlias:=False;
      M.Undefined:=(Value='relax') or (Value='undefined') or (Value='@undefined');
      if Target<>nil then begin
        M.ArgCount:=Target.ArgCount; M.Signature:=Target.Signature; M.OptionalFirst:=Target.OptionalFirst; M.DefaultArgument:=Target.DefaultArgument;
        M.PreviewAdapter:=Target.PreviewAdapter; M.PreviewName:=Target.PreviewName;
        M.Body:=Target.Body; M.GlyphFont:=Target.GlyphFont; M.GlyphPlan:=Target.GlyphPlan; M.MathGlyphPlan:=Target.MathGlyphPlan;
        M.GlyphCode:=Target.GlyphCode; M.SymbolClass:=Target.SymbolClass;
        M.DelimiterFont:=Target.DelimiterFont; M.DelimiterCode:=Target.DelimiterCode;
        M.Undefined:=Target.Undefined;
        M.NativeName:=Target.NativeName;
      end;
      if not M.Undefined and ((Target=nil) or (Target.PackageSource<>'')) then begin
        NativeAlias:=((Target=nil) or (Target.GlyphFont='')) and TeXSymbol('\'+Value,Family,Count);
        if NativeAlias then begin M.Body:='\'+Value; M.ArgCount:=0; M.GlyphFont:=''; end
        else if (Value='textbf') or (Value='textit') or (Value='textsf') or (Value='texttt') or (Value='textrm') or
          (Value='textsc') or (Value='textsl') or (Value='textup') or (Value='textmd') or (Value='textnormal') or (Value='emph') then begin
          M.Body:='\'+Value+'{#1}'; M.ArgCount:=1; NativeAlias:=True;
        end else if (Value='frac') or (Value='dfrac') or (Value='tfrac') then begin
          M.Body:='\'+Value+'{#1}{#2}'; M.ArgCount:=2; NativeAlias:=True;
        end else if (Value='bmod') or (Value='mod') or (Value='pmod') or (Value='pod') then begin
          M.NativeName:='\'+Value; M.ArgCount:=Ord(Value<>'bmod'); NativeAlias:=True;
        end;
      end;
      StoreMacro;
      if (Find(Name)=M) and (Target<>nil) and not Target.Expandable and not NativeAlias then M.Expandable:=False;
      Continue;
    end;
    if (Cmd='undef') or (Cmd='csundef') or (Cmd='UndefineDocumentCommand') then begin
      Value:=Token; Q:=1; Name:=ReadTeXCommand(Value,Q);
      if (Name='') and (Cmd='csundef') and (Pos('#',Value)=0) then Name:=Value;
      if Name<>'' then begin M:=TMacroInfo.Create; M.Name:=Name; M.Undefined:=True; StoreMacro; end;
      Continue;
    end;
    if (Cmd='sbox') or (Cmd='savebox') or (Cmd='newsavebox') then begin
      Name:=Token; Spec:=''; Value:='c';
      if Cmd='savebox' then begin
        Spec:=ReadTeXGroup(Source,P,'[',']'); Parameters:=ReadTeXGroup(Source,P,'[',']');
        if Parameters<>'' then Value:=Parameters;
      end;
      if Cmd<>'newsavebox' then begin
        Imported:=FreezeBox(ReadTeXGroup(Source,P,'{','}'));
        if Spec<>'' then Imported:='\makebox['+Spec+']['+Value+']{'+Imported+'}' else Imported:='\mbox{'+Imported+'}';
        if (Name<>'') and (Length(Imported)<=65536) and ((FSavedBoxes.Count<256) or (FSavedBoxes.IndexOfName(Name)>=0)) then FSavedBoxes.Values[Name]:=Imported;
      end;
      Continue;
    end;
    if Cmd='newtheorem' then begin
      if (P<=Length(Source)) and (Source[P]='*') then Inc(P);
      Name:=ReadTeXGroup(Source,P,'{','}'); if (Name<>'') and (FTheorems.IndexOf(Name)<0) then FTheorems.Add(Name); Continue;
    end;
    if (Cmd='newenvironment') or (Cmd='renewenvironment') or (Cmd='provideenvironment') or
      (Cmd='NewDocumentEnvironment') or (Cmd='RenewDocumentEnvironment') or
      (Cmd='ProvideDocumentEnvironment') or (Cmd='DeclareDocumentEnvironment') then begin
      if Copy(Source,P,1)='*' then Inc(P);
      Name:=ReadTeXGroup(Source,P,'{','}');
      if (Name<>'') and (Pos('#',Name)=0) and (FEnvironments.IndexOf(Name)<0) then FEnvironments.Add(Name);
      if Pos('Document',Cmd)>0 then ReadTeXGroup(Source,P,'{','}')
      else begin ReadTeXGroup(Source,P,'[',']'); ReadTeXGroup(Source,P,'[',']'); end;
      ReadTeXGroup(Source,P,'{','}'); ReadTeXGroup(Source,P,'{','}'); Continue;
    end;
    if Cmd='verb' then
    begin
      if (P<=Length(Source)) and (Source[P]='*') then Inc(P);
      if P<=Length(Source) then
      begin Value:=Source[P]; Inc(P); while (P<=Length(Source)) and (Source[P]<>Value) do Inc(P); Inc(P); end;
      Continue;
    end;
    if Cmd='begin' then
    begin
      Value:=ReadTeXGroup(Source,P,'{','}');
      if IsTeXVerbatimEnvironment(Value) then
      begin
        Value:='\end{'+Value+'}';
        while (P<=Length(Source)) and (Copy(Source,P,Length(Value))<>Value) do Inc(P);
        Inc(P,Length(Value));
      end;
      Continue;
    end;
    if IsTeXInputCommand(Cmd) or (Cmd='usepackage') or (Cmd='RequirePackage') or
      (Cmd='documentclass') or (Cmd='LoadClass') then
    begin
      SkipTeXSpace(Source,P);
      PackageOptions:='';
      if (P<=Length(Source)) and (Source[P]='[') then PackageOptions:=ReadTeXGroup(Source,P,'[',']');
      Value:=ReadTeXGroup(Source,P,'{','}');
      if (Value='') and (Cmd='input') then begin
        Q:=P; while (P<=Length(Source)) and not (Source[P] in [' ',#9,#10,#13,'\','{','}','%']) do Inc(P);
        Value:=Copy(Source,Q,P-Q);
      end;
      if Value='' then Continue;
      S:=TStringList.Create;
      try
        S.StrictDelimiter:=True; S.Delimiter:=','; S.DelimitedText:=Value;
        for I:=0 to S.Count-1 do
        begin
          Path:=Trim(S[I]); if Path='' then Continue;
          if (Path[1]='\') and (Copy(Path,1,2)<>'\\') then Continue;
          PackageFile:=(Cmd='usepackage') or (Cmd='RequirePackage') or (Cmd='documentclass') or (Cmd='LoadClass') or (PackagePath<>'');
          if ExtractFileExt(Path)='' then
            if (Cmd='usepackage') or (Cmd='RequirePackage') then Path:=Path+'.sty'
            else if (Cmd='documentclass') or (Cmd='LoadClass') then Path:=Path+'.cls' else Path:=Path+'.tex';
          ImportName:=Path;
          if (ImportName='beamer.cls') or (ImportName='ctexbeamer.cls') then FPresentation:=True;
          if FileExists(FSourceDirectory+Path) then Path:=ExpandFileName(FSourceDirectory+Path)
          else Path:=ResolveTeXSource(Path,Directory);
          FImports.Values[Directory+'|'+ImportName]:=Path;
          if ImportName='wasysym.sty' then FSymbolFonts.Values['!wasysym-options']:=StringReplace(PackageOptions,' ','',[rfReplaceAll]);
          if (Cmd='usepackage') or (Cmd='RequirePackage') then InstallPackagePreview(ImportName,Path);
          if FileExists(Path) and (FVisited.IndexOf(Path)<0) then
          begin
            { Dependency limits must not hide a later explicitly requested
              package merely because an earlier package has many imports. }
            if (PackagePath<>'') and ((FVisited.Count>=64) or (FReadBytes>=2*1024*1024)) then Continue;
            FVisited.Add(Path);
            Imported:=ReadTeXSource(Path,Pos(FSourceDirectory,Path)=1);
            if (Length(Imported)>2*1024*1024) or
              ((PackagePath<>'') and (FReadBytes+Length(Imported)>2*1024*1024)) then Continue;
            Inc(FReadBytes,Length(Imported));
            if PackageFile then Scan(Imported,ExtractFileDir(Path),Depth+1,Path)
            else Scan(Imported,ExtractFileDir(Path),Depth+1);
            if (Cmd='usepackage') or (Cmd='RequirePackage') then InstallPackagePreview(ImportName,Path);
            if (ImportName='wasysym.sty') and (Pos(',integrals,',','+FSymbolFonts.Values['!wasysym-options']+',')>0) then
              Scan('\let\int\wasy@int\let\iint\wasy@iint\let\iiint\wasy@iiint\let\oint\wasy@oint\let\oiint\wasy@oiint',Directory,Depth+1,Path);
          end;
        end;
      finally S.Free; end;
      Continue;
    end;
    Delimiters:=Cmd='DeclarePairedDelimiter';
    if not ((Cmd='newcommand') or (Cmd='renewcommand') or (Cmd='providecommand') or
      (Cmd='newrobustcmd') or (Cmd='renewrobustcmd') or (Cmd='providerobustcmd') or
      (Cmd='DeclareRobustCommand') or (Cmd='DeclareMathOperator') or
      (Cmd='def') or (Cmd='gdef') or (Cmd='edef') or (Cmd='xdef') or
      (Cmd='NewDocumentCommand') or (Cmd='RenewDocumentCommand') or (Cmd='DeclareDocumentCommand') or (Cmd='ProvideDocumentCommand') or Delimiters) then Continue;
    OperatorStar:=(P<=Length(Source)) and (Source[P]='*'); if OperatorStar then Inc(P);
    SkipTeXSpace(Source,P);
    if (P<=Length(Source)) and (Source[P]='{') then
    begin Value:=ReadTeXGroup(Source,P,'{','}'); Q:=1; Name:=ReadTeXCommand(Value,Q); end
    else Name:=ReadTeXCommand(Source,P);
    if Name='' then Continue;
    M:=TMacroInfo.Create; M.Name:=Name;
    SkipTeXSpace(Source,P);
    if Delimiters then begin
      M.ArgCount:=1; M.Body:='\left'+ReadTeXGroup(Source,P,'{','}')+'#1\right'+ReadTeXGroup(Source,P,'{','}');
      StoreMacro; Continue;
    end;
    Parameters:='';
    if Pos('DocumentCommand',Cmd)>0 then
    begin
      Spec:=ReadTeXGroup(Source,P,'{','}'); M.Signature:=Spec; Q:=1;
      while Q<=Length(Spec) do
      begin
        if Spec[Q]='m' then Inc(M.ArgCount)
        else if Spec[Q] in ['o','O'] then
        begin if M.ArgCount=0 then M.OptionalFirst:=True; Inc(M.ArgCount); end;
        Inc(Q);
        if (Q<=Length(Spec)) and (Spec[Q]='{') then
        begin
          Value:=ReadTeXGroup(Spec,Q,'{','}');
          if M.OptionalFirst and (M.ArgCount=1) then M.DefaultArgument:=Value;
        end;
      end;
    end
    else if (Cmd='def') or (Cmd='gdef') or (Cmd='edef') or (Cmd='xdef') then
    begin
      Q:=P;
      while (P<=Length(Source)) and (Source[P]<>'{') do
      begin
        if (Source[P]='#') and (P<Length(Source)) and (Source[P+1] in ['1'..'9']) then
        begin N:=Ord(Source[P+1])-Ord('0'); if N>M.ArgCount then M.ArgCount:=N; end;
        Inc(P);
      end;
      Parameters:=StringReplace(Copy(Source,Q,P-Q),' ','',[rfReplaceAll]);
      for N:=1 to M.ArgCount do Parameters:=StringReplace(Parameters,'#'+IntToStr(N),'',[rfReplaceAll]);
    end
    else if (P<=Length(Source)) and (Source[P]='[') then
    begin
      M.ArgCount:=StrToIntDef(ReadTeXGroup(Source,P,'[',']'),0); SkipTeXSpace(Source,P);
      if (P<=Length(Source)) and (Source[P]='[') then
      begin M.OptionalFirst:=True; M.DefaultArgument:=ReadTeXGroup(Source,P,'[',']'); end;
    end;
    M.Body:=ReadTeXGroup(Source,P,'{','}');
    if Cmd='DeclareMathOperator' then begin
      M.SymbolClass:='\mathop';
      if OperatorStar then M.Body:='\operatorname*{'+M.Body+'}'
      else M.Body:='\operatorname{'+M.Body+'}';
    end;
    if PackagePath='' then begin M.Definition:=Copy(Source,A,P-A); FDefinitions:=FDefinitions+M.Definition+LineEnding; end;
    StoreMacro;
    if (PackagePath<>'') and (Parameters<>'') then begin Target:=Find(Name); if Target<>nil then Target.Expandable:=False; end;
  end;
end;
initialization
  RegistryCache:=TObjectList.Create(True);
finalization
  RegistryCache.Free;
end.
