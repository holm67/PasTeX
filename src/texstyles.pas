unit TeXStyles;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, TeXMacros, TeXSectioning;
type
  THeadingFormat=record
    Shape,Format,LabelCode,Separator,BeforeCode,AfterCode:string;
    NameBefore,NameAfter,NumberCode:string;
    Left,Right,Above,Below:string;
    Custom,Numberless:Boolean;
  end;
  THeadingStyle=record
    Points:Double;
    Bold,Italic,HasColor:Boolean;
    Family:string;
    Alignment,Color:Integer;
  end;
  TStyleRegistry=class
    Registry:TMacroRegistry;
    References:Integer;
    constructor Create(Value:TMacroRegistry);
    destructor Destroy; override;
    procedure Retain;
    procedure Release;
  end;
  TTeXStyles=class
  private
    FHeadings,FStarred:array[0..6] of THeadingFormat;
    FNumberFormats:array[0..6] of TSectionFormat;
    FNumberRevision:QWord;
    FNames,FVisited:TStringList;
    FRegistry:TMacroRegistry;
    FRegistryOwner:TStyleRegistry;
    FDirectory:string;
    FReadBytes:Integer;
    FPoints,FNumberDepth:Integer;
    FHasChapters:Boolean;
    FExpansionBudget,FTextDepth:Integer;
    procedure ReleaseRegistry;
    procedure OwnRegistry;
    procedure PrepareNumberFormats;
    function Expand(const Code,Counter,Number:string; Depth:Integer):string;
    procedure Scan(const Source,Directory:string; Imports:Boolean; Depth:Integer=0);
    procedure Keys(const Source,Heading:string);
    procedure CTeXDefaults(const Options,DocumentClass,Directory:string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load(const Input,Directory:string; Registry:TMacroRegistry=nil);
    procedure Assign(Other:TTeXStyles);
    procedure Apply(const Source:string);
    function Heading(const Name:string; Starred:Boolean):THeadingFormat;
    function HeadingNumber(const State:TSectionState; const Name:string):string;
    function HeadingLabel(const Code:string; const State:TSectionState):string;
    function Style(const Code:string):THeadingStyle;
    function Text(const Code,Counter,Number:string):string;
    function Caption(const Kind,Number:string):string;
    function Name(const Command,Default:string):string;
    property HasChapters:Boolean read FHasChapters;
    property NumberDepth:Integer read FNumberDepth;
  end;
function HeadingIndex(const Name:string):Integer;
function TeXStyleDimension(const Value:string; Em:Double):Double;
function TeXStylePreamble(const Source:string):string;
implementation
uses Math, Contnrs, TeXPackageSources, TeXDocumentMetrics;
type TStyleCache=class
  Key:string;
  Styles:TTeXStyles;
  destructor Destroy; override;
end;
var StyleCache:TObjectList;
function HeadingIndex(const Name:string):Integer;
begin Result:=SectionIndex(Name); end;
function TeXStylePreamble(const Source:string):string;
var P,Q:Integer; Command:string;
begin
  P:=1; Result:=Source;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) then begin P:=Q; Continue; end;
    Command:=ReadTeXCommand(Source,P);
    if (Command='begin') and (ReadTeXGroup(Source,P,'{','}')='document') then Exit(Copy(Source,1,P-1));
  end;
end;
function TeXStyleDimension(const Value:string; Em:Double):Double;
var S,UnitName:string; P:Integer; N:Double; F:TFormatSettings;
begin
  Result:=0; S:=Trim(Value); if S='\z@' then Exit;
  if S='\quad' then Exit(Em); if S='\qquad' then Exit(2*Em);
  if (S='\enspace') or (S='\enskip') then Exit(Em/2);
  if S='\,' then Exit(Em/6); if S='\:' then Exit(Em*2/9); if S='\;' then Exit(Em*5/18);
  if Pos('\hspace',S)=1 then begin P:=1; ReadTeXCommand(S,P); S:=ReadTeXGroup(S,P,'{','}'); end;
  P:=1; while (P<=Length(S)) and (S[P] in ['0'..'9','+','-','.']) do Inc(P);
  F:=DefaultFormatSettings; F.DecimalSeparator:='.';
  if not TryStrToFloat(Copy(S,1,P-1),N,F) then Exit;
  S:=TrimLeft(Copy(S,P,MaxInt)); P:=1; while (P<=Length(S)) and (S[P] in ['a'..'z']) do Inc(P);
  UnitName:=Copy(S,1,P-1);
  case UnitName of
    'pt':Result:=N; 'bp':Result:=N*72.27/72; 'pc':Result:=N*12;
    'in':Result:=N*72.27; 'mm':Result:=N*72.27/25.4; 'cm':Result:=N*72.27/2.54;
    'em':Result:=N*Em; 'ex':Result:=N*Em*0.430555;
  end;
end;
function ReadStartSection(const Code:string; Points:Double; var H:THeadingFormat):Boolean;
var P:Integer;
begin
  P:=Pos('\@startsection',Code); Result:=P>0; if not Result then Exit;
  Inc(P,Length('\@startsection')); ReadTeXGroup(Code,P,'{','}'); ReadTeXGroup(Code,P,'{','}');
  H.Left:=ReadTeXGroup(Code,P,'{','}'); H.Above:=ReadTeXGroup(Code,P,'{','}');
  H.Below:=ReadTeXGroup(Code,P,'{','}'); H.Format:=ReadTeXGroup(Code,P,'{','}');
  { latex.ltx's @xsect uses a nonpositive afterskip for a run-in heading. }
  H.Shape:='hang'; if TeXStyleDimension(H.Below,Points)<=0 then H.Shape:='runin';
end;
constructor TTeXStyles.Create;
begin
  inherited Create; FNames:=TStringList.Create; FNames.CaseSensitive:=True;
  FVisited:=TStringList.Create; FVisited.CaseSensitive:=True;
end;
destructor TTeXStyles.Destroy;
begin ReleaseRegistry; FVisited.Free; FNames.Free; inherited Destroy; end;
constructor TStyleRegistry.Create(Value:TMacroRegistry);
begin inherited Create; Registry:=Value; References:=1; end;
destructor TStyleRegistry.Destroy;
begin Registry.Free; inherited Destroy; end;
procedure TStyleRegistry.Retain;
begin Inc(References); end;
procedure TStyleRegistry.Release;
begin Dec(References); if References=0 then Free; end;
procedure TTeXStyles.ReleaseRegistry;
begin
  if FRegistryOwner<>nil then FRegistryOwner.Release;
  FRegistryOwner:=nil; FRegistry:=nil;
end;
procedure TTeXStyles.OwnRegistry;
var Value:TMacroRegistry;
begin
  if (FRegistryOwner=nil) or (FRegistryOwner.References=1) then Exit;
  Value:=FRegistry.Clone; ReleaseRegistry;
  FRegistry:=Value; FRegistryOwner:=TStyleRegistry.Create(Value);
end;
destructor TStyleCache.Destroy;
begin Styles.Free; inherited Destroy; end;
function Argument(const S:string; var P:Integer):string;
var A:Integer;
begin
  SkipTeXSpace(S,P); if Copy(S,P,1)='{' then Exit(ReadTeXGroup(S,P,'{','}'));
  A:=P; if Copy(S,P,1)='\' then ReadTeXCommand(S,P) else if P<=Length(S) then Inc(P);
  Result:=Copy(S,A,P-A);
end;
function Options(const S:string; var P:Integer):string;
begin
  Result:=''; SkipTeXSpace(S,P); if Copy(S,P,1)='[' then Result:=ReadTeXGroup(S,P,'[',']');
end;
procedure SplitKeys(const Source:string; Parts:TStrings);
var P,A,Level,Q:Integer;
begin
  Parts.Clear; P:=1; A:=1; Level:=0;
  while P<=Length(Source)+1 do begin
    if P<=Length(Source) then begin
      if Source[P]='\' then begin Q:=P; ReadTeXCommand(Source,Q); P:=Q; Continue; end;
      if Source[P]='{' then Inc(Level) else if Source[P]='}' then Dec(Level);
    end;
    if (P>Length(Source)) or ((Source[P]=',') and (Level=0)) then begin
      Parts.Add(Trim(Copy(Source,A,P-A))); A:=P+1;
    end;
    Inc(P);
  end;
end;
procedure TTeXStyles.Keys(const Source,Heading:string);
var Parts,Pair:TStringList; Part,Key,Value,Target:string; P,Q,I:Integer; H:THeadingFormat;
begin
  Parts:=TStringList.Create;
  try
    SplitKeys(Source,Parts);
    for Part in Parts do begin
      P:=Pos('=',Part); if P=0 then Continue;
      Key:=StringReplace(Trim(Copy(Part,1,P-1)),' ','',[rfReplaceAll]); Value:=Trim(Copy(Part,P+1,MaxInt));
      if Copy(Value,1,1)='{' then begin Q:=1; Value:=ReadTeXGroup(Value,Q,'{','}'); end;
      Target:=Heading; P:=Pos('/',Key);
      if P>0 then begin Target:=Copy(Key,1,P-1); Key:=Copy(Key,P+1,MaxInt); end;
      I:=HeadingIndex(Target);
      if I>=0 then begin
        if (Key=Target) or (Key='') then begin Keys(Value,Target); Continue; end;
        H:=FHeadings[I]; H.Custom:=True;
        case Key of
          'format':H.Format:=Value;
          'name':begin
            Pair:=TStringList.Create;
            try
              SplitKeys(Value,Pair); H.NameBefore:=''; H.NameAfter:='';
              if Pair.Count>0 then H.NameBefore:=Pair[0];
              if Pair.Count>1 then H.NameAfter:=Pair[1];
              if H.NumberCode='' then H.NumberCode:='\the'+Target;
              H.LabelCode:=H.NameBefore+H.NumberCode+H.NameAfter;
            finally Pair.Free; end;
          end;
          'number':begin H.NumberCode:=Value; H.LabelCode:=H.NameBefore+Value+H.NameAfter; end;
          'aftername':H.Separator:=Value;
          'beforeskip':H.Above:=Value; 'afterskip':H.Below:=Value;
          'indent':H.Left:=Value; 'titleformat':H.BeforeCode:=Value;
          'runin':if Value='true' then H.Shape:='runin' else if Value='false' then H.Shape:='hang';
          'hang':if Value='false' then H.Shape:='block';
        end;
        FHeadings[I]:=H; FStarred[I]:=H; Continue;
      end;
      I:=HeadingIndex(Key);
      if I>=0 then begin Keys(Value,Key); Continue; end;
      if (Key='figurename') or (Key='tablename') or (Key='proofname') or (Key='partname') or
        (Key='chaptername') or (Key='refname') or (Key='bibname') or (Pos('autorefname',Key)>0) then FNames.Values[Key]:=Value;
    end;
  finally Parts.Free; end;
end;
procedure TTeXStyles.CTeXDefaults(const Options,DocumentClass,Directory:string);
var Source,Scheme,Base,Target:string; P:Integer;
begin
  Scheme:='chinese'; if (Pos('scheme=plain',StringReplace(Options,' ','',[rfReplaceAll]))>0) or (Pos('nocap',Options)>0) then Scheme:='plain';
  if Scheme='chinese' then begin
    Source:=ReadTeXSource(ResolveTeXSource('ctex-name-utf8.cfg',Directory));
    P:=Pos('{ ctex }',Source);
    if P>0 then begin Inc(P,Length('{ ctex }')); Keys(ReadTeXGroup(Source,P,'{','}'),''); end;
  end;
  { The package only changes headings when heading is enabled; ctex classes
    enable them. Its .def files express their styles as ctex_set:nn keys. }
  if Pos('heading=false',StringReplace(Options,' ','',[rfReplaceAll]))>0 then Exit;
  if (Pos('ctex',DocumentClass)<>1) and (Pos('heading',Options)=0) then Exit;
  Base:=DocumentClass; if Pos('ctex',Base)=1 then Delete(Base,1,4);
  if Base='art' then Base:='article'; if Base='rep' then Base:='report';
  Source:=ReadTeXSource(ResolveTeXSource('ctex-scheme-'+Scheme+'-'+Base+'.def',Directory));
  P:=1;
  while P<=Length(Source) do begin
    if Copy(Source,P,12)='\ctex_set:nn' then begin
      Inc(P,12); Target:=ReadTeXGroup(Source,P,'{','}'); Keys(ReadTeXGroup(Source,P,'{','}'),Trim(Target));
    end else Inc(P);
  end;
end;
procedure TTeXStyles.Scan(const Source,Directory:string; Imports:Boolean; Depth:Integer);
var P,Q,I,Number:Integer; Cmd,Target,Value,Option,Shape,Path,Imported,Base,NumberBody:string;
    Star,Numberless:Boolean; H:THeadingFormat; M:TMacroInfo; Packages:TStringList;
begin
  if Depth>12 then Exit; P:=1;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P;
    if ReadTeXDefinition(Source,Q) then begin
      Value:=Copy(Source,P,Q-P); Target:=TeXDefinitionName(Value);
      I:=HeadingIndex(Target);
      if I>=0 then begin
        H:=FHeadings[I];
        if ReadStartSection(Value,FPoints,H) then begin FHeadings[I]:=H; FStarred[I]:=H; end;
      end;
      if ((Target='@part') or (Target='part')) and (Pos('\partname',Value)>0) then begin
        H:=FHeadings[0]; H.LabelCode:='\partname~\thepart'; H.NumberCode:='\thepart';
        H.NameBefore:='\partname~'; H.Shape:='display'; FHeadings[0]:=H; FStarred[0]:=H;
      end;
      if (Copy(Target,Length(Target)-3,4)='name') or (Pos('fnum@',Target)=1) then begin
        FRegistry.ApplyDefinitions(Value); M:=FRegistry.Find(Target); if M<>nil then FNames.Values[Target]:=M.Body;
      end;
      if (Copy(Target,1,3)='the') and (SectionIndex(Copy(Target,4,MaxInt))>=0) then begin
        OwnRegistry; FRegistry.ApplyDefinitions(Value);
      end;
      P:=Q; Continue;
    end;
    Cmd:=ReadTeXCommand(Source,P);
    if (Cmd='setcounter') or (Cmd='addtocounter') then begin
      Target:=ReadTeXGroup(Source,P,'{','}'); Value:=ReadTeXGroup(Source,P,'{','}');
      if (Target='secnumdepth') and TryStrToInt(Trim(Value),Number) then
        if Cmd='setcounter' then FNumberDepth:=Number
        else FNumberDepth:=EnsureRange(Int64(FNumberDepth)+Number,Low(Integer),High(Integer));
      Continue;
    end;
    if Cmd='appendix' then begin
      { Class and package sources can mention \appendix in a hook or alias.
        Only a document declaration changes the current counter format. }
      if Depth>0 then Continue;
      Target:='section'; if FHasChapters then Target:='chapter';
      OwnRegistry; FRegistry.ApplyDefinitions('\renewcommand{\the'+Target+'}{\Alph{'+Target+'}}'); Continue;
    end;
    if Cmd='verb' then begin
      if Copy(Source,P,1)='*' then Inc(P);
      if P<=Length(Source) then begin Value:=Source[P]; Inc(P); while (P<=Length(Source)) and (Source[P]<>Value) do Inc(P); Inc(P); end;
      Continue;
    end;
    if Cmd='begin' then begin
      Value:=ReadTeXGroup(Source,P,'{','}');
      if (Value='verbatim') or (Value='verbatim*') or (Value='lstlisting') or (Value='minted') then begin
        Target:='\end{'+Value+'}'; Q:=Pos(Target,Copy(Source,P,MaxInt));
        if Q=0 then P:=Length(Source)+1 else Inc(P,Q-1+Length(Target));
      end;
      Continue;
    end;
    if (Cmd='ctexset') then begin Keys(ReadTeXGroup(Source,P,'{','}'),''); Continue; end;
    if (Cmd='titleformat') or (Cmd='titlespacing') then begin
      Star:=Copy(Source,P,1)='*'; if Star then Inc(P);
      Target:=ReadTeXGroup(Source,P,'{','}'); Numberless:=Pos('numberless',Target)>0;
      Q:=1; while (Q<=Length(Target)) and (Target[Q]<>'\') do Inc(Q);
      Target:=ReadTeXCommand(Target,Q); I:=HeadingIndex(Target); if I<0 then Continue;
      if Numberless then H:=FStarred[I] else H:=FHeadings[I]; H.Custom:=True;
      if Cmd='titlespacing' then begin
        H.Left:=ReadTeXGroup(Source,P,'{','}'); H.Above:=ReadTeXGroup(Source,P,'{','}');
        H.Below:=ReadTeXGroup(Source,P,'{','}'); H.Right:=Options(Source,P);
      end else if Star then H.Format:=ReadTeXGroup(Source,P,'{','}')
      else begin
        Shape:=Options(Source,P); if Shape='' then Shape:='hang'; H.Shape:=Shape;
        H.Format:=ReadTeXGroup(Source,P,'{','}'); H.LabelCode:=ReadTeXGroup(Source,P,'{','}');
        H.NameBefore:=''; H.NameAfter:=''; H.NumberCode:=H.LabelCode;
        H.Separator:=ReadTeXGroup(Source,P,'{','}'); H.BeforeCode:=ReadTeXGroup(Source,P,'{','}'); H.AfterCode:=Options(Source,P);
      end;
      if Numberless then begin H.Numberless:=True; FStarred[I]:=H; end
      else begin FHeadings[I]:=H; if not FStarred[I].Numberless then FStarred[I]:=H; end;
      Continue;
    end;
    if not Imports then Continue;
    if not ((Cmd='documentclass') or (Cmd='LoadClass') or (Cmd='usepackage') or (Cmd='RequirePackage') or (Cmd='input') or (Cmd='include')) then Continue;
    Option:=Options(Source,P); Value:=ReadTeXGroup(Source,P,'{','}');
    if (Value='') and (Cmd='input') then begin Q:=P; while (P<=Length(Source)) and not (Source[P] in [' ',#10,#13,'\','{','}']) do Inc(P); Value:=Copy(Source,Q,P-Q); end;
    Packages:=TStringList.Create;
    try
      SplitKeys(Value,Packages);
      for Base in Packages do begin
        if ((Cmd='documentclass') or (Cmd='LoadClass')) and
          ((Base='book') or (Base='report') or (Base='ctexbook') or (Base='ctexrep')) then FHasChapters:=True;
        Path:=Trim(Base); if (Path='') or (Pos('\',Path)>0) then Continue;
        if ExtractFileExt(Path)='' then
          if (Cmd='documentclass') or (Cmd='LoadClass') then Path:=Path+'.cls'
          else if (Cmd='usepackage') or (Cmd='RequirePackage') then Path:=Path+'.sty' else Path:=Path+'.tex';
        Path:=ResolveTeXSource(Path,Directory);
        if (Path<>'') and (FVisited.IndexOf(Path)<0) and (FVisited.Count<64) then begin
          FVisited.Add(Path); Imported:=ReadTeXSource(Path);
          if FReadBytes+Length(Imported)<=2*1024*1024 then begin
            Inc(FReadBytes,Length(Imported));
            { Package definitions may contain inactive language branches.
              Class names come from the registry; execute only the selected
              hyperref language definition, not every branch in its source. }
            if Base='hyperref' then begin
              { Private package macros are deliberately omitted by the macro
                registry. Read the selected language block from its source. }
              Q:=Pos('\def\HyLang@english',Imported);
              if Q>0 then begin
                ReadTeXCommand(Imported,Q); ReadTeXCommand(Imported,Q);
                Scan(ReadTeXGroup(Imported,Q,'{','}'),ExtractFileDir(Path),False,Depth+1);
              end;
            end else Scan(Imported,ExtractFileDir(Path),True,Depth+1);
          end;
        end;
        if (Base='ctex') or (Base='ctexart') or (Base='ctexbook') or (Base='ctexrep') or (Base='ctexbeamer') then begin
          if Base='ctex' then NumberBody:='article' else NumberBody:=Base;
          CTeXDefaults(Option,NumberBody,Directory);
        end;
      end;
    finally Packages.Free; end;
  end;
end;
procedure TTeXStyles.Load(const Input,Directory:string; Registry:TMacroRegistry);
var I:Integer; M:TMacroInfo; H:THeadingFormat; Names:TStringList; Command,Body,Key,Source:string; Entry:TStyleCache;
begin
  Source:=Input; if Registry<>nil then Source:=ActiveTeXSource(Input,Registry.Engine);
  if Registry<>nil then begin
    Key:=IncludeTrailingPathDelimiter(ExpandFileName(Directory))+#0+Source+#0+IntToStr(Registry.Revision);
    for I:=StyleCache.Count-1 downto 0 do begin
      Entry:=TStyleCache(StyleCache[I]);
      if Entry.Key=Key then begin Assign(Entry.Styles); Exit; end;
    end;
  end;
  FNames.Clear; FVisited.Clear; FReadBytes:=0; FDirectory:=Directory; FPoints:=DocumentFontPoints(Source);
  ReleaseRegistry;
  if Registry<>nil then FRegistry:=Registry.Clone else begin FRegistry:=TMacroRegistry.Create; FRegistry.Load(Source,Directory); end;
  FRegistryOwner:=TStyleRegistry.Create(FRegistry);
  Key:=IncludeTrailingPathDelimiter(ExpandFileName(Directory))+#0+Source+#0+IntToStr(FRegistry.Revision);
  for I:=StyleCache.Count-1 downto 0 do begin
    Entry:=TStyleCache(StyleCache[I]);
    if Entry.Key=Key then begin Assign(Entry.Styles); Exit; end;
  end;
  FHasChapters:=FRegistry.Find('chapter')<>nil; FNumberDepth:=3-Ord(FHasChapters);
  for I:=0 to High(FHeadings) do begin
    H:=Default(THeadingFormat); H.Shape:='hang'; H.Format:='\normalfont\bfseries'; H.LabelCode:='\the'+SectionNames[I]; H.NumberCode:=H.LabelCode; H.Separator:='1em';
    case I of 0,1:H.Format:=H.Format+'\huge'; 2:H.Format:=H.Format+'\Large'; 3:H.Format:=H.Format+'\large'; end;
    M:=FRegistry.Find(SectionNames[I]);
    if M<>nil then ReadStartSection(M.Body,FPoints,H);
    FHeadings[I]:=H; FStarred[I]:=H;
  end;
  Names:=TStringList.Create;
  try
    FRegistry.Names(Names);
    for Command in Names do begin
      Body:=Copy(Command,2,MaxInt);
      if ((Copy(Body,Length(Body)-3,4)='name') or (Pos('fnum@',Body)=1)) then begin
        M:=FRegistry.Find(Body);
        if (M<>nil) and (Pos('hyperref',M.PackageSource)=0) then FNames.Values[Body]:=M.Body;
      end;
    end;
  finally Names.Free; end;
  Scan(Source,Directory,True);
  PrepareNumberFormats;
  if Length(Source)<=65536 then begin
    Entry:=TStyleCache.Create; Entry.Key:=Key; Entry.Styles:=TTeXStyles.Create; Entry.Styles.Assign(Self);
    if StyleCache.Count>=4 then StyleCache.Delete(0); StyleCache.Add(Entry);
  end;
end;
procedure TTeXStyles.Apply(const Source:string);
begin
  if FRegistry=nil then Exit;
  if ContainsTeXDefinitions(Source) then begin OwnRegistry; FRegistry.ApplyDefinitions(Source); end;
  Scan(Source,FDirectory,False);
end;
procedure TTeXStyles.Assign(Other:TTeXStyles);
begin
  if Other=Self then Exit;
  FHeadings:=Other.FHeadings; FStarred:=Other.FStarred; FNames.Assign(Other.FNames);
  FNumberFormats:=Other.FNumberFormats; FNumberRevision:=Other.FNumberRevision;
  FDirectory:=Other.FDirectory; FPoints:=Other.FPoints; FReadBytes:=Other.FReadBytes; FHasChapters:=Other.FHasChapters; FNumberDepth:=Other.FNumberDepth;
  ReleaseRegistry; FRegistry:=Other.FRegistry; FRegistryOwner:=Other.FRegistryOwner;
  if FRegistryOwner<>nil then FRegistryOwner.Retain;
end;
function TTeXStyles.Heading(const Name:string; Starred:Boolean):THeadingFormat;
var I:Integer;
begin
  I:=HeadingIndex(Name); Result:=Default(THeadingFormat); if I<0 then Exit;
  if Starred then Result:=FStarred[I] else Result:=FHeadings[I];
  if Starred then Result.LabelCode:='';
end;
function TTeXStyles.HeadingNumber(const State:TSectionState; const Name:string):string;
var Index:Integer;
begin
  Result:=''; Index:=SectionIndex(Name); if Index<0 then Exit;
  PrepareNumberFormats; Result:=RenderSectionFormat(FNumberFormats[Index],State);
  if (Pos('\',Result)>0) or (Pos('{',Result)>0) or (Pos('~',Result)>0) then Result:=Text(Result,'','');
end;
procedure TTeXStyles.PrepareNumberFormats;
var I:Integer;
begin
  if (FRegistry=nil) or (FNumberRevision=FRegistry.Revision) then Exit;
  for I:=0 to High(SectionNames) do FNumberFormats[I]:=CompileSectionFormat('\the'+SectionNames[I],FRegistry,FHasChapters);
  FNumberRevision:=FRegistry.Revision;
end;
function TTeXStyles.HeadingLabel(const Code:string; const State:TSectionState):string;
var I:Integer;
begin
  for I:=0 to High(SectionNames) do if Code='\the'+SectionNames[I] then Exit(HeadingNumber(State,SectionNames[I]));
  Result:=Text(ExpandSectionCounters(Code,State,FRegistry),'','');
end;
function TTeXStyles.Name(const Command,Default:string):string;
begin
  Result:=FNames.Values[Command]; if Result='' then Exit(Default);
  Result:=Text(Result,'',''); if Result='' then Result:=Default;
end;
function TTeXStyles.Expand(const Code,Counter,Number:string; Depth:Integer):string;
var P,A,N:Integer; Command,Value:string; M:TMacroInfo;
begin
  Result:=''; if (Depth>16) or (Length(Code)>8192) or (FExpansionBudget<=0) then Exit;
  Dec(FExpansionBudget); P:=1;
  while (P<=Length(Code)) and (Length(Result)<8192) do begin
    if Code[P]='%' then begin while (P<=Length(Code)) and (Code[P]<>#10) do Inc(P); Continue; end;
    if Code[P]<>'\' then begin Result:=Result+Code[P]; Inc(P); Continue; end;
    A:=P; Command:=ReadTeXCommand(Code,P);
    if Command='the'+Counter then begin Result:=Result+Number; SkipTeXSpace(Code,P); Continue; end;
    if (Command='arabic') or (Command='roman') or (Command='Roman') or (Command='alph') or (Command='Alph') or (Command='chinese') then begin
      Value:=Trim(ReadTeXGroup(Code,P,'{','}')); N:=StrToIntDef(Number,0);
      if Value=Counter then begin
        Value:=Number; if Command<>'arabic' then Value:=FormatTeXCounter(N,Command);
        Result:=Result+Value;
      end;
      Continue;
    end;
    Value:=FNames.Values[Command];
    if Value<>'' then begin Result:=Result+Expand(Value,Counter,Number,Depth+1); Continue; end;
    M:=FRegistry.Find(Command);
    if (M<>nil) and M.Expandable and (M.ArgCount=0) and (M.Body<>'\'+Command) then begin
      Result:=Result+Expand(M.Body,Counter,Number,Depth+1); Continue;
    end;
    Result:=Result+Copy(Code,A,P-A);
  end;
end;
function TTeXStyles.Text(const Code,Counter,Number:string):string;
var S,Command,Value:string; P:Integer;
begin
  Result:=''; if FTextDepth>=32 then Exit;
  Inc(FTextDepth);
  try
  if FTextDepth=1 then FExpansionBudget:=256;
  S:=Expand(Code,Counter,Number,0); P:=1;
  while P<=Length(S) do begin
    if S[P]='\' then begin
      Command:=ReadTeXCommand(S,P);
      if (Command='quad') or (Command='qquad') or (Command='space') or (Command='nobreakspace') or (Command=' ') then Result:=Result+' '
      else if (Command='{') or (Command='}') or (Command='%') or (Command='#') or (Command='&') then Result:=Result+Command
      else if (Command='textbf') or (Command='textit') or (Command='emph') or (Command='MakeUppercase') then begin
        Value:=ReadTeXGroup(S,P,'{','}'); Value:=Text(Value,Counter,Number); if Command='MakeUppercase' then Value:=UpperCase(Value); Result:=Result+Value;
      end else if (Command='color') or (Command='textcolor') then begin Options(S,P); ReadTeXGroup(S,P,'{','}'); end;
      Continue;
    end;
    if S[P]='~' then Result:=Result+' ' else if not (S[P] in ['{','}']) then Result:=Result+S[P]; Inc(P);
  end;
  Result:=Trim(Result);
  finally Dec(FTextDepth); end;
end;
function TTeXStyles.Caption(const Kind,Number:string):string;
var Code:string;
begin
  Code:=FNames.Values['fnum@'+Kind]; if Code='' then Code:='\'+Kind+'name\nobreakspace\the'+Kind;
  Result:=Text(Code,Kind,Number);
end;
function TTeXStyles.Style(const Code:string):THeadingStyle;
var S,Command,Value,Model:string; P:Integer; N:Double; F:TFormatSettings;
begin
  Result:=Default(THeadingStyle); Result.Points:=FPoints; Result.Family:='rm';
  FExpansionBudget:=256; S:=Expand(Code,'','',0); P:=1; F:=DefaultFormatSettings; F.DecimalSeparator:='.';
  while P<=Length(S) do begin
    if S[P]<>'\' then begin Inc(P); Continue; end;
    Command:=ReadTeXCommand(S,P);
    case Command of
      'normalfont':begin Result.Bold:=False; Result.Italic:=False; Result.Family:='rm'; end;
      'bf','bfseries':Result.Bold:=True; 'mdseries':Result.Bold:=False;
      'it','itshape','slshape':Result.Italic:=True; 'upshape':Result.Italic:=False;
      'sffamily','sf':Result.Family:='sf'; 'ttfamily','tt':Result.Family:='tt'; 'rmfamily','rm':Result.Family:='rm';
      'centering','filcenter':Result.Alignment:=1; 'raggedleft','filright':Result.Alignment:=2;
      'raggedright','filleft':Result.Alignment:=0;
      'tiny':begin Result.Points:=5; if FPoints=12 then Result.Points:=6; end;
      'scriptsize':begin Result.Points:=7; if FPoints=12 then Result.Points:=8; end;
      'footnotesize':begin Result.Points:=8; if FPoints=11 then Result.Points:=9 else if FPoints=12 then Result.Points:=10; end;
      'small':begin Result.Points:=9; if FPoints=11 then Result.Points:=10 else if FPoints=12 then Result.Points:=10.95; end;
      'normalsize':Result.Points:=FPoints;
      'large':begin Result.Points:=12; if FPoints=12 then Result.Points:=14.4; end;
      'Large':begin Result.Points:=14.4; if FPoints=12 then Result.Points:=17.28; end;
      'LARGE':begin Result.Points:=17.28; if FPoints=12 then Result.Points:=20.74; end;
      'huge':begin Result.Points:=20.74; if FPoints=12 then Result.Points:=24.88; end;
      'Huge':Result.Points:=24.88;
      'fontsize':begin Value:=Argument(S,P); Argument(S,P); N:=TeXStyleDimension(Value,FPoints); if N=0 then N:=StrToFloatDef(Value,FPoints,F); Result.Points:=EnsureRange(N,1,240); end;
      'color':begin
        Model:=Options(S,P); Value:=ReadTeXGroup(S,P,'{','}'); Result.HasColor:=True;
        if Model='HTML' then Result.Color:=StrToIntDef('$'+Value,0)
        else case Value of
          'red':Result.Color:=$FF0000; 'green':Result.Color:=$00FF00; 'blue':Result.Color:=$0000FF;
          'gray':Result.Color:=$808080; 'white':Result.Color:=$FFFFFF; 'black':Result.Color:=0;
          else Result.HasColor:=False;
        end;
      end;
    end;
  end;
end;
initialization
  StyleCache:=TObjectList.Create(True);
finalization
  StyleCache.Free;
end.
