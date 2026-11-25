unit TeXContext;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Contnrs, TeXMacros, TeXStyles, TeXBibliography, BibliographyData, TeXSectioning, NativePagination;
type
  TTheoremInfo=class
    Name,Title,Style,Counter,Within:string;
    Starred:Boolean;
  end;
  TContextMark=class
    Offset,Row:Integer;
    Number,Title,Labels,Note,Counter:string;
    BareTag:Boolean;
  end;
  TContextLabel=class
    Number,Title,Kind,Caption:string;
    Offset:Integer;
  end;
  TSourcePage=NativePagination.TSourcePage;
  TSourcePages=NativePagination.TSourcePages;
  TTeXContext=class
  private
    FTheorems,FCounters,FNumbers,FLabels,FAliases,FCitations:TStringList;
    FReferenceNames:TStringList;
    FBibliographyData:TBibliographyData;
    FMarks:TObjectList;
    FStyles,FBaseStyles:TTeXStyles;
    FStyleSource,FStyleDirectory:string;
    FLoadedSource,FLoadedDirectory,FLoadedEngine:string;
    FLayoutKey:string;
    FLayoutRevision:QWord;
    FScanOffset:Integer;
    FSourcePages:TSourcePages;
    FPageRevision:QWord;
    FSections,FInitialSections:TSectionState;
    FCounterEventCount:Integer;
    FCounterEvents:array of record Offset:Integer; Values:array[0..2] of Integer; Sections:TSectionState; end;
    FPageNumbers:array of record Offset,Value:Integer; Style:string; Relative:Boolean; end;
    FCleverCapitalise,FCleverNoAbbrev:Boolean;
    procedure RecordCounters;
    function CounterEventBefore(Offset:Integer):Integer;
    function Advance(const Name,Within:string; DefaultChapter:Boolean=False):string;
    function FindLabel(const Key:string):TContextLabel;
    procedure DefineLabel(const Key,Number,Title,Kind,Caption:string; Offset:Integer);
  public
    GeneratedBibliography:string;
    NativePageLayout:Boolean;
    NativePageWidth,NativePageFontSize:Integer;
    NativePageEm:Double;
    NativePageEngine:string;
    NativePageMeasurements:TObject;
    constructor Create;
    destructor Destroy; override;
    procedure Load(Source:string; const Directory:string=''; const Engine:string='pdflatex');
    property Source:string read FLoadedSource;
    property LayoutRevision:QWord read FLayoutRevision;
    property Bibliography:TBibliographyData read FBibliographyData;
    property PageRevision:QWord read FPageRevision;
    procedure SetNativePages(const Pages:TSourcePages);
    function NativePage(Offset:Integer):string;
    function NativePageNumber(Offset:Integer):string;
    procedure Invalidate;
    function CounterBefore(const Name:string; Offset:Integer):Integer;
    function SectionStateBefore(Offset:Integer):TSectionState;
    function AppendixBefore(Offset:Integer):Boolean;
    function Theorem(const Name:string):TTheoremInfo;
    function Mark(Offset:Integer; Row:Integer=0):TContextMark;
    function Reference(const Key:string; WithName:Boolean=False):string;
    function ReferenceText(const Keys,Command:string):string;
    function Citation(const Keys,Note:string):string;
    function CitationText(const Item:TCitationSource):string;
    procedure LabelNames(Dest:TStrings);
    procedure TheoremNames(Dest:TStrings);
  end;
function AppendixLetter(Value:Integer):string;
implementation
uses Math, TeXEditing, BeamerModel;
const CounterNames:array[0..2] of string=('equation','footnote','framenumber');
  ReferenceDash:UTF8String='–';
procedure TTeXContext.SetNativePages(const Pages:TSourcePages);
var I:Integer; Same:Boolean;
begin
  Same:=Length(Pages)=Length(FSourcePages);
  if Same then for I:=0 to High(Pages) do if (Pages[I].Offset<>FSourcePages[I].Offset) or (Pages[I].Page<>FSourcePages[I].Page) then begin Same:=False; Break; end;
  if Same then Exit; FSourcePages:=Copy(Pages); Inc(FPageRevision);
end;
function TTeXContext.NativePage(Offset:Integer):string;
var L,R,M:Integer;
begin
  Result:=''; if Length(FSourcePages)=0 then Exit;
  L:=0; R:=Length(FSourcePages);
  while L<R do begin M:=L+(R-L) div 2; if FSourcePages[M].Offset<=Offset then L:=M+1 else R:=M; end;
  if L>0 then Result:=IntToStr(FSourcePages[L-1].Page);
end;
function TTeXContext.NativePageNumber(Offset:Integer):string;
var Page,Start,Base,I,AtPage:Integer; Style:string;
begin
  Result:=NativePage(Offset); if Result='' then Exit;
  Page:=StrToIntDef(Result,1); Base:=1; Start:=1; Style:='arabic';
  for I:=0 to High(FPageNumbers) do begin
    if FPageNumbers[I].Offset>Offset then Break;
    AtPage:=StrToIntDef(NativePage(FPageNumbers[I].Offset),1);
    if FPageNumbers[I].Relative then Base:=EnsureRange(Int64(Base)+AtPage-Start+FPageNumbers[I].Value,Low(Integer),High(Integer))
    else Base:=FPageNumbers[I].Value;
    if FPageNumbers[I].Style<>'' then Style:=FPageNumbers[I].Style;
    Start:=AtPage;
  end;
  if Style='gobble' then Exit('');
  Result:=FormatTeXCounter(EnsureRange(Int64(Page)-Start+Base,Low(Integer),High(Integer)),Style);
end;
function AppendixLetter(Value:Integer):string;
begin Result:=FormatTeXCounter(Value,'Alph'); end;
procedure TTeXContext.RecordCounters;
var I,N:Integer; Same:Boolean;
begin
  N:=FCounterEventCount; Same:=N>0;
  if Same then begin
    Same:=(FCounterEvents[N-1].Sections.NumberDepth=FSections.NumberDepth) and
      (FCounterEvents[N-1].Sections.MainMatter=FSections.MainMatter) and
      (FCounterEvents[N-1].Sections.Appendix=FSections.Appendix);
    for I:=0 to High(SectionNames) do Same:=Same and (FCounterEvents[N-1].Sections.Values[I]=FSections.Values[I]);
    for I:=0 to High(CounterNames) do Same:=Same and
      (FCounterEvents[N-1].Values[I]=StrToIntDef(FCounters.Values[CounterNames[I]],0));
  end;
  if Same then Exit;
  if N=Length(FCounterEvents) then SetLength(FCounterEvents,Max(32,N*2));
  Inc(FCounterEventCount); FCounterEvents[N].Offset:=FScanOffset;
  FCounterEvents[N].Sections:=FSections;
  for I:=0 to High(CounterNames) do FCounterEvents[N].Values[I]:=StrToIntDef(FCounters.Values[CounterNames[I]],0);
end;
function TTeXContext.CounterEventBefore(Offset:Integer):Integer;
var First,Last,Middle:Integer;
begin
  { Load scans source forwards, including equation endings. Definitions and
    imported styles do not insert events from another source. Find the last
    event strictly before the paragraph, preserving exact-boundary behavior. }
  First:=0; Last:=FCounterEventCount;
  while First<Last do begin
    Middle:=First+(Last-First) div 2;
    if FCounterEvents[Middle].Offset<Offset then First:=Middle+1 else Last:=Middle;
  end;
  Result:=First-1;
end;
function TTeXContext.AppendixBefore(Offset:Integer):Boolean;
begin Result:=SectionStateBefore(Offset).Appendix; end;
function TTeXContext.SectionStateBefore(Offset:Integer):TSectionState;
var I:Integer;
begin
  I:=CounterEventBefore(Offset); Result:=FInitialSections;
  if I>=0 then Result:=FCounterEvents[I].Sections;
end;
function TTeXContext.CounterBefore(const Name:string; Offset:Integer):Integer;
var I,J:Integer; Sections:TSectionState;
begin
  J:=SectionIndex(Name);
  if J>=0 then begin Sections:=SectionStateBefore(Offset); Exit(Sections.Values[J]); end;
  Result:=0; J:=-1; for I:=0 to High(CounterNames) do if CounterNames[I]=Name then J:=I;
  if J<0 then Exit;
  I:=CounterEventBefore(Offset);
  if I>=0 then Result:=FCounterEvents[I].Values[J];
end;
constructor TTeXContext.Create;
begin
  FAliases:=TStringList.Create; FTheorems:=TStringList.Create; FCounters:=TStringList.Create; FNumbers:=TStringList.Create;
  FLabels:=TStringList.Create; FMarks:=TObjectList.Create(True); FCitations:=TStringList.Create;
  FLabels.CaseSensitive:=True; FLabels.Sorted:=True; FLabels.OwnsObjects:=True;
  FCitations.CaseSensitive:=True;
  FReferenceNames:=TStringList.Create;
  FBibliographyData:=TBibliographyData.Create;
  FStyles:=TTeXStyles.Create; FBaseStyles:=TTeXStyles.Create;
end;
destructor TTeXContext.Destroy;
var I:Integer;
begin
  for I:=0 to FTheorems.Count-1 do FTheorems.Objects[I].Free;
  FStyles.Free; FBaseStyles.Free;
  NativePageMeasurements.Free;
  FReferenceNames.Free;
  FBibliographyData.Free;
  FCitations.Free; FAliases.Free; FTheorems.Free; FCounters.Free; FNumbers.Free; FLabels.Free; FMarks.Free; inherited Destroy;
end;
procedure TTeXContext.Invalidate;
begin FLoadedSource:=''; FStyleSource:=''; FreeAndNil(NativePageMeasurements); Inc(FLayoutRevision); end;
function TTeXContext.Citation(const Keys,Note:string):string;
var Names:TStringList; I:Integer; Value:string;
begin
  Result:=''; Names:=TStringList.Create;
  try
    Names.Delimiter:=','; Names.StrictDelimiter:=True; Names.DelimitedText:=Keys;
    for I:=0 to Names.Count-1 do begin
      Value:=FCitations.Values[Trim(Names[I])]; if Value='' then Value:=Trim(Names[I]);
      if Result<>'' then Result:=Result+', '; Result:=Result+Value;
    end;
    if Note<>'' then begin if Result<>'' then Result:=Result+', '; Result:=Result+Note; end;
    Result:='['+Result+']';
  finally Names.Free; end;
end;
function TTeXContext.CitationText(const Item:TCitationSource):string;
begin
  Result:=FBibliographyData.Citation(Item.Keys,Item.Command,Item.PreNote,Item.PostNote,FCitations);
  if Result='' then begin Result:=Citation(Item.Keys,Item.PostNote); if Item.PreNote<>'' then Result:=Item.PreNote+' '+Result; end;
end;
function TTeXContext.Theorem(const Name:string):TTheoremInfo;
var I:Integer;
begin Result:=nil; I:=FTheorems.IndexOf(Name); if I>=0 then Result:=TTheoremInfo(FTheorems.Objects[I]); end;
function CompareContextMarks(A,B:Pointer):Integer;
var Left,Right:TContextMark;
begin
  Left:=TContextMark(A); Right:=TContextMark(B);
  if Left.Offset<Right.Offset then Exit(-1);
  if Left.Offset>Right.Offset then Exit(1);
  if Left.Row<Right.Row then Exit(-1);
  Result:=Ord(Left.Row>Right.Row);
end;
function TTeXContext.Mark(Offset:Integer; Row:Integer):TContextMark;
var First,Last,Middle:Integer; Item:TContextMark;
begin
  Result:=nil; First:=0; Last:=FMarks.Count;
  while First<Last do begin
    Middle:=First+(Last-First) div 2; Item:=TContextMark(FMarks[Middle]);
    if (Item.Offset<Offset) or ((Item.Offset=Offset) and (Item.Row<Row)) then First:=Middle+1
    else Last:=Middle;
  end;
  if First<FMarks.Count then begin
    Item:=TContextMark(FMarks[First]);
    if (Item.Offset=Offset) and (Item.Row=Row) then Result:=Item;
  end;
end;
function TTeXContext.Reference(const Key:string; WithName:Boolean):string;
var Item:TContextLabel;
begin
  Item:=FindLabel(Key); Result:='??'; if Item=nil then Exit;
  if Item.Number<>'' then Result:=Item.Number;
  if WithName and (Item.Title<>'') then Result:=Item.Title+' '+Result;
end;
function TTeXContext.FindLabel(const Key:string):TContextLabel;
var I:Integer;
begin
  Result:=nil; if FLabels.Find(Key,I) then Result:=TContextLabel(FLabels.Objects[I]);
end;
procedure TTeXContext.DefineLabel(const Key,Number,Title,Kind,Caption:string; Offset:Integer);
var Item:TContextLabel;
begin
  if Key='' then Exit; Item:=FindLabel(Key);
  if Item=nil then begin Item:=TContextLabel.Create; FLabels.AddObject(Key,Item); end;
  Item.Number:=Number; Item.Title:=Title; Item.Kind:=Kind; Item.Caption:=ReferenceTitle(Caption); Item.Offset:=Offset;
end;
function TTeXContext.ReferenceText(const Keys,Command:string):string;
var Parts,Types,Numbers:TStringList; I,J,Finish:Integer; Kind,Caption,Group,Value,Plural,Prefix:string;
    Capital,Range,NameOnly,PageRefs:Boolean; Item:TContextLabel;
  function PageNumber(Item:TContextLabel):string;
  begin
    Result:='??'; if (Item<>nil) and (NativePage(Item.Offset)<>'') then Result:=NativePageNumber(Item.Offset);
  end;
  function Number(Index:Integer):string;
  begin
    Result:=Numbers[Index]; if Result='' then Result:='??';
    if Kind='equation' then Result:='('+Result+')';
  end;
  function Consecutive(const A,B:string):Boolean;
  var P,Q,Left,Right:Integer;
  begin
    P:=LastDelimiter('.',A); Q:=LastDelimiter('.',B);
    Result:=(Copy(A,1,P)=Copy(B,1,Q)) and TryStrToInt(Copy(A,P+1,MaxInt),Left) and
      TryStrToInt(Copy(B,Q+1,MaxInt),Right) and (Int64(Right)=Int64(Left)+1);
  end;
begin
  if Command='eqref' then Exit('('+Reference(Keys)+')');
  if Command='autoref' then Exit(Reference(Keys,True));
  if Command='nameref' then begin
    Item:=FindLabel(Keys); Result:='??'; if (Item<>nil) and (Item.Caption<>'') then Result:=Item.Caption; Exit;
  end;
  if Command='pageref' then begin
    Exit(PageNumber(FindLabel(Keys)));
  end;
  if (Command='ref') or (Command='vref') then Exit(Reference(Keys));
  PageRefs:=IsPageReference(Command);
  Capital:=(Command='Cref') or (Command='Crefrange') or (Command='nameCref') or
    (Command='Cpageref') or FCleverCapitalise;
  Range:=(Command='crefrange') or (Command='Crefrange');
  NameOnly:=(Command='namecref') or (Command='nameCref') or (Command='lcnamecref');
  Parts:=TStringList.Create; Types:=TStringList.Create; Numbers:=TStringList.Create;
  try
    Parts.Delimiter:=','; Parts.StrictDelimiter:=True; Parts.DelimitedText:=Keys;
    for I:=0 to Parts.Count-1 do begin
      Item:=FindLabel(Trim(Parts[I])); Parts.Objects[I]:=Item;
      Kind:=''; if Item<>nil then Kind:=Item.Kind;
      if PageRefs then Kind:='page';
      if Types.IndexOf(Kind)<0 then Types.Add(Kind);
    end;
    Result:='';
    for I:=0 to Types.Count-1 do begin
      Kind:=Types[I]; Numbers.Clear; Caption:='';
      for J:=0 to Parts.Count-1 do begin
        Item:=TContextLabel(Parts.Objects[J]);
        if not PageRefs and (((Item=nil) and (Kind<>'')) or ((Item<>nil) and (Item.Kind<>Kind))) then Continue;
        Value:='??';
        if PageRefs then begin
          Value:=PageNumber(Item);
          if Numbers.IndexOf(Value)<0 then Numbers.Add(Value); Caption:='page';
        end else begin
          if Item<>nil then begin if Item.Number<>'' then Value:=Item.Number; Caption:=LowerCase(Item.Title); end;
          Numbers.Add(Value);
        end;
      end;
      if (Kind='equation') and not FCleverNoAbbrev then begin Caption:='eq.'; Plural:='eqs.'; end
      else begin if Caption='' then Caption:=Kind; Plural:=Caption+'s'; end;
      if FReferenceNames.Values[Kind+':one']<>'' then Caption:=FReferenceNames.Values[Kind+':one'];
      if Numbers.Count>1 then begin
        Caption:=Plural;
        if FReferenceNames.Values[Kind+':many']<>'' then Caption:=FReferenceNames.Values[Kind+':many'];
      end;
      if Capital then begin
        if FReferenceNames.Values[Kind+':capital-one']<>'' then begin
          if Numbers.Count>1 then Caption:=FReferenceNames.Values[Kind+':capital-many']
          else Caption:=FReferenceNames.Values[Kind+':capital-one'];
        end else if Caption<>'' then Caption[1]:=UpCase(Caption[1]);
      end;
      Group:=''; J:=0;
      while J<Numbers.Count do begin
        Finish:=J;
        while (Finish+1<Numbers.Count) and Consecutive(Numbers[Finish],Numbers[Finish+1]) do Inc(Finish);
        if Range or (Finish-J>=2) then begin
          if Range then Finish:=Numbers.Count-1;
          Value:=Number(J)+ReferenceDash+Number(Finish);
        end else begin Finish:=J; Value:=Number(J); end;
        if Group<>'' then begin if Finish=Numbers.Count-1 then Group:=Group+' and ' else Group:=Group+', '; end;
        Group:=Group+Value; J:=Finish+1;
      end;
      Prefix:=Caption;
      if not NameOnly then begin
        if Command='labelcref' then Prefix:='';
        if Prefix<>'' then Prefix:=Prefix+' '; Prefix:=Prefix+Group;
      end;
      if Result<>'' then Result:=Result+' and '; Result:=Result+Prefix;
    end;
    if Result='' then Result:='??';
  finally Numbers.Free; Types.Free; Parts.Free; end;
end;
procedure TTeXContext.LabelNames(Dest:TStrings);
var I:Integer;
begin Dest.Clear; for I:=0 to FLabels.Count-1 do Dest.Add(FLabels[I]); end;
procedure TTeXContext.TheoremNames(Dest:TStrings);
var I:Integer;
begin Dest.Clear; for I:=0 to FTheorems.Count-1 do Dest.Add(FTheorems[I]); end;
function TTeXContext.Advance(const Name,Within:string; DefaultChapter:Boolean):string;
var N:Integer; Prefix:string;
begin
  N:=Min(Int64(High(Integer)),Int64(StrToIntDef(FCounters.Values[Name],0))+1); FCounters.Values[Name]:=IntToStr(N);
  Result:=IntToStr(N);
  if Within<>'' then begin
    if SectionIndex(Within)>=0 then Prefix:=FStyles.HeadingNumber(FSections,Within)
    else begin Prefix:=FNumbers.Values[Within]; if Prefix='' then Prefix:=IntToStr(StrToIntDef(FCounters.Values[Within],0)); end;
    if not (DefaultChapter and (Within='chapter') and (FSections.Values[1]<=0) and
      ((Name='equation') or (Name='figure') or (Name='table'))) then Result:=Prefix+'.'+Result;
  end;
  FNumbers.Values[Name]:=Result;
end;
procedure TTeXContext.Load(Source:string; const Directory,Engine:string);
type TFrame=record Env,Tag,Keys:string; Start,Row:Integer; Equation,Numbered,Suppressed,HasTag,BareTag:Boolean; end;
var P,A,Q,I,J,N,Level,HeaderLength,FrameAfter:Integer; Cmd,Name,Title,Style,Shared,Within,Value,LastNumber,LastTitle,LastType,LastCaption,EquationWithin,Preamble,LayoutKey:string;
    T:TTheoremInfo; M:TContextMark; LabelInfo:TContextLabel; Frames:array of TFrame; F:TFrame; Star,DefaultEquationChapter:Boolean;
    Presentation:Boolean; SlideFrame:TBeamerFrame;
  procedure SkipArguments;
  begin
    if Copy(Source,P,1)='*' then Inc(P);
    repeat
      Q:=P; SkipTeXSpace(Source,Q);
      if Copy(Source,Q,1)='{' then begin P:=Q; ReadTeXGroup(Source,P,'{','}'); end
      else if Copy(Source,Q,1)='[' then begin P:=Q; ReadTeXGroup(Source,P,'[',']'); end
      else Break;
    until P>Length(Source);
  end;
  function EquationFrame:Integer;
  begin
    Result:=High(Frames);
    while (Result>=0) and not Frames[Result].Equation do Dec(Result);
  end;
  procedure ReferenceOptions(const Value,Packages:string);
  var Items:TStringList; Item:string; Applies:Boolean;
  begin
    Items:=TStringList.Create;
    try
      Items.Delimiter:=','; Items.StrictDelimiter:=True; Items.DelimitedText:=Packages; Applies:=Packages='';
      for Item in Items do if Trim(Item)='cleveref' then Applies:=True;
      if not Applies then Exit; Items.DelimitedText:=Value;
      for Item in Items do case Trim(Item) of
        'capitalise','capitalize':FCleverCapitalise:=True;
        'noabbrev':FCleverNoAbbrev:=True;
      end;
    finally Items.Free; end;
  end;
  procedure BibliographyItems(const Text:string);
  var K,Number:Integer; Command,Key,LabelText:string;
  begin
    K:=1; Number:=0;
    while K<=Length(Text) do begin
      if Text[K]='%' then begin while (K<=Length(Text)) and (Text[K]<>#10) do Inc(K); Continue; end;
      if Text[K]<>'\' then begin Inc(K); Continue; end;
      Command:=ReadTeXCommand(Text,K); if Command<>'bibitem' then Continue;
      Inc(Number); LabelText:=IntToStr(Number); SkipTeXSpace(Text,K);
      if Copy(Text,K,1)='[' then LabelText:=ReadTeXGroup(Text,K,'[',']');
      Key:=ReadTeXGroup(Text,K,'{','}'); if Key<>'' then FCitations.Values[Key]:=LabelText;
    end;
  end;
  procedure HeadingLabels(const Caption:string; Offset:Integer);
  var K,A,Q:Integer; Key:string;
  begin
    K:=1;
    while K<=Length(Caption) do begin
      SkipTeXSpace(Caption,K); if K>Length(Caption) then Break;
      if Caption[K]<>'\' then begin Inc(K); Continue; end;
      A:=K; Q:=K;
      if ReadTeXDefinition(Caption,Q) or SkipTeXLiteral(Caption,Q) then begin K:=Q; Continue; end;
      if ReadTeXCommand(Caption,K)<>'label' then Continue;
      Key:=ReadTeXGroup(Caption,K,'{','}');
      DefineLabel(Key,LastNumber,LastTitle,LastType,LastCaption,Offset+A-1);
    end;
  end;
  procedure FinishEquation;
  var Keys:TStringList; K:Integer;
  begin
    if Length(Frames)=0 then Exit;
    F:=Frames[High(Frames)]; if not F.Equation then Exit;
    M:=TContextMark.Create; M.Offset:=F.Start; M.Row:=F.Row; M.Title:=FStyles.Name('equationautorefname','Equation'); M.Labels:=F.Keys; M.BareTag:=F.BareTag;
    if F.HasTag then M.Number:=F.Tag
    else if F.Numbered and not F.Suppressed then M.Number:=Advance('equation',EquationWithin,DefaultEquationChapter);
    RecordCounters;
    FMarks.Add(M); LastNumber:=M.Number; LastTitle:=M.Title;
    Keys:=TStringList.Create;
    try
      Keys.Delimiter:=','; Keys.StrictDelimiter:=True; Keys.DelimitedText:=F.Keys;
      for K:=0 to Keys.Count-1 do begin
        LabelInfo:=FindLabel(Keys[K]);
        if LabelInfo<>nil then DefineLabel(Keys[K],M.Number,M.Title,'equation','',LabelInfo.Offset);
      end;
    finally Keys.Free; end;
    Inc(Frames[High(Frames)].Row); Frames[High(Frames)].Tag:=''; Frames[High(Frames)].Keys:='';
    Frames[High(Frames)].Suppressed:=False; Frames[High(Frames)].HasTag:=False; Frames[High(Frames)].BareTag:=False;
  end;
  procedure ResetDependents(const Counter:string; Depth:Integer=0);
  var I:Integer; Info:TTheoremInfo;
    procedure Reset(const Name:string);
    begin FCounters.Values[Name]:='0'; FNumbers.Values[Name]:=''; ResetDependents(Name,Depth+1); end;
  begin
    if Depth>16 then Exit;
    for I:=0 to FTheorems.Count-1 do begin
      Info:=TTheoremInfo(FTheorems.Objects[I]);
      if (Info.Within=Counter) and (Info.Counter<>Counter) then Reset(Info.Counter);
    end;
    if (EquationWithin=Counter) and (Counter<>'equation') then Reset('equation');
    if Counter='chapter' then begin Reset('footnote'); Reset('figure'); Reset('table'); end;
  end;
  procedure PageNumbering(const Style:string; Value:Integer; Relative:Boolean=False);
  var N:Integer;
  begin
    N:=Length(FPageNumbers); SetLength(FPageNumbers,N+1); FPageNumbers[N].Offset:=FScanOffset;
    FPageNumbers[N].Value:=Value; FPageNumbers[N].Style:=Style; FPageNumbers[N].Relative:=Relative;
  end;
begin
  if (Source=FLoadedSource) and (Directory=FLoadedDirectory) and (Engine=FLoadedEngine) and (FLoadedSource<>'') then Exit;
  FLoadedSource:=Source; FLoadedDirectory:=Directory; FLoadedEngine:=Engine; FCounterEventCount:=0;
  Source:=ActiveTeXSource(Source,Engine);
  FSourcePages:=nil; FPageNumbers:=nil; NativePageWidth:=0; Inc(FPageRevision);
  if Source='' then FreeAndNil(NativePageMeasurements);
  for I:=0 to FTheorems.Count-1 do FTheorems.Objects[I].Free;
  FAliases.Clear; FTheorems.Clear; FCounters.Clear; FNumbers.Clear; FLabels.Clear; FMarks.Clear; FCitations.Clear;
  FReferenceNames.Clear;
  FCleverCapitalise:=False; FCleverNoAbbrev:=False;
  Preamble:=TeXStylePreamble(Source);
  HeaderLength:=TeXHeaderLength(Source);
  Presentation:=BeamerSettings(Preamble).Enabled; FrameAfter:=0;
  if (Preamble<>FStyleSource) or (Directory<>FStyleDirectory) or (FStyleSource='') then begin
    FBaseStyles.Load(Preamble,Directory); FStyleSource:=Preamble; FStyleDirectory:=Directory;
  end;
  FStyles.Assign(FBaseStyles);
  if Presentation then for Name in TStringArray.Create('theorem','corollary','fact','lemma','problem','solution',
    'definition','definitions','example','examples') do begin
    T:=TTheoremInfo.Create; T.Name:=Name; T.Title:=UpCase(Name[1])+Copy(Name,2,MaxInt);
    T.Style:=BeamerTheoremStyle(Name); T.Counter:='theorem';
    if Pos('envcountsect',Preamble)>0 then T.Within:='section';
    FTheorems.AddObject(Name,T);
  end;
  FInitialSections:=InitialSectionState(FStyles.HasChapters,FStyles.NumberDepth); FSections:=FInitialSections;
  BibliographyItems(Source);
  FBibliographyData.Load(Source,Directory);
  P:=1; Style:='plain'; LastNumber:=''; LastTitle:=''; LastType:=''; LastCaption:=''; Frames:=nil; EquationWithin:='';
  DefaultEquationChapter:=FStyles.HasChapters;
  if DefaultEquationChapter then EquationWithin:='chapter';
  while P<=Length(Source) do
  begin
    FScanOffset:=P-1;
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Copy(Source,P,2)='$$' then begin
      A:=P-1; Inc(P,2);
      if (Length(Frames)>0) and (Frames[High(Frames)].Env='$$') then begin FinishEquation; SetLength(Frames,Length(Frames)-1); end
      else begin
        F.Env:='$$'; F.Start:=A; F.Row:=0; F.Equation:=True; F.Numbered:=False; F.Suppressed:=False; F.HasTag:=False; F.BareTag:=False; F.Tag:=''; F.Keys:='';
        SetLength(Frames,Length(Frames)+1); Frames[High(Frames)]:=F;
      end; Continue;
    end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) then begin
      if P>Length(Preamble) then FStyles.Apply(Copy(Source,P,Q-P)); P:=Q; Continue;
    end;
    if SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
    A:=P-1; Cmd:=ReadTeXCommand(Source,P);
    if Presentation and (A>=HeaderLength) then begin
      if ((Cmd='begin') or (Cmd='frame')) and ReadBeamerFrame(Source,A+1,SlideFrame) then begin
        FrameAfter:=SlideFrame.After;
        if (SlideFrame.Selection<>'0') and (Pos('noframenumbering',SlideFrame.Options)=0) then Advance('framenumber','');
        RecordCounters;
      end else if (Cmd='maketitle') and (P>=FrameAfter) then begin Advance('framenumber',''); RecordCounters; end;
    end;
    if (Cmd='crefname') or (Cmd='Crefname') then begin
      Name:=ReadTeXGroup(Source,P,'{','}'); Value:=ReadTeXGroup(Source,P,'{','}'); Title:=ReadTeXGroup(Source,P,'{','}');
      Within:=''; if Cmd='Crefname' then Within:='capital-';
      FReferenceNames.Values[Name+':'+Within+'one']:=Value; FReferenceNames.Values[Name+':'+Within+'many']:=Title; Continue;
    end;
    if (Cmd='titleformat') or (Cmd='titlespacing') or (Cmd='ctexset') then begin
      SkipArguments;
      if A>=HeaderLength then FStyles.Apply(Copy(Source,A+1,P-A-1));
      Continue;
    end;
    if Cmd='pagenumbering' then begin PageNumbering(ReadTeXGroup(Source,P,'{','}'),1); Continue; end;
    if (HeaderLength=0) or (A<HeaderLength) then begin
      if (Cmd='documentclass') or (Cmd='usepackage') or (Cmd='RequirePackage') then begin
        Value:=ReadTeXGroup(Source,P,'[',']'); Name:=ReadTeXGroup(Source,P,'{','}');
        if Cmd='documentclass' then Name:=''; ReferenceOptions(Value,Name); Continue;
      end;
      if Cmd='PassOptionsToPackage' then begin
        Value:=ReadTeXGroup(Source,P,'{','}'); Name:=ReadTeXGroup(Source,P,'{','}'); ReferenceOptions(Value,Name); Continue;
      end;
    end;
    { Configuration arguments are data, not body headings or equations. }
    if (HeaderLength>0) and (A<HeaderLength) and
      not ((Cmd='theoremstyle') or (Cmd='newtheoremstyle') or (Cmd='newtheorem') or
        (Cmd='newaliascnt') or (Cmd='aliascntresetthe') or (Cmd='numberwithin') or
        (Cmd='counterwithin') or (Cmd='setcounter') or (Cmd='addtocounter')) then begin
      SkipArguments; Continue;
    end;
    { Citation text comes from source bibitems, or the citation key. Do not
      import stale bibliography output into the independent editor layout. }
    if Cmd='bibliography' then begin ReadTeXGroup(Source,P,'{','}'); Continue; end;
    if Cmd='[' then begin
      F.Env:='display'; F.Start:=A; F.Row:=0; F.Equation:=True; F.Numbered:=False; F.Suppressed:=False; F.HasTag:=False; F.BareTag:=False; F.Tag:=''; F.Keys:='';
      SetLength(Frames,Length(Frames)+1); Frames[High(Frames)]:=F; Continue;
    end;
    if (Cmd=']') and (Length(Frames)>0) and (Frames[High(Frames)].Env='display') then begin FinishEquation; SetLength(Frames,Length(Frames)-1); Continue; end;
    if Cmd='theoremstyle' then begin Style:=ReadTeXGroup(Source,P,'{','}'); Continue; end;
    if Cmd='newtheoremstyle' then
    begin for I:=1 to 9 do ReadTeXGroup(Source,P,'{','}'); Continue; end;
    if Cmd='newaliascnt' then begin
      Name:=ReadTeXGroup(Source,P,'{','}'); Value:=ReadTeXGroup(Source,P,'{','}');
      for I:=0 to FAliases.Count do begin
        if FAliases.Values[Value]='' then Break; Value:=FAliases.Values[Value];
      end;
      if (Name<>'') and (Name<>Value) then FAliases.Values[Name]:=Value;
      Continue;
    end;
    if Cmd='aliascntresetthe' then begin ReadTeXGroup(Source,P,'{','}'); Continue; end;
    if Cmd='newtheorem' then
    begin
      Star:=(P<=Length(Source)) and (Source[P]='*'); if Star then Inc(P);
      Name:=ReadTeXGroup(Source,P,'{','}'); Shared:=''; Within:=''; SkipTeXSpace(Source,P);
      if (P<=Length(Source)) and (Source[P]='[') then Shared:=ReadTeXGroup(Source,P,'[',']');
      Title:=ReadTeXGroup(Source,P,'{','}'); SkipTeXSpace(Source,P);
      if (P<=Length(Source)) and (Source[P]='[') then Within:=ReadTeXGroup(Source,P,'[',']');
      if Name='' then Continue;
      if FAliases.Values[Shared]<>'' then Shared:=FAliases.Values[Shared];
      T:=TTheoremInfo.Create; T.Name:=Name; T.Title:=Title; T.Style:=Style; T.Starred:=Star; T.Within:=Within;
      if Shared='' then T.Counter:=Name else begin T.Counter:=Shared; if Theorem(Shared)<>nil then begin T.Within:=Theorem(Shared).Within; T.Counter:=Theorem(Shared).Counter; end; end;
      I:=FTheorems.IndexOf(Name); if I>=0 then begin FTheorems.Objects[I].Free; FTheorems.Objects[I]:=T; end else FTheorems.AddObject(Name,T);
      Continue;
    end;
    if (Cmd='numberwithin') or (Cmd='counterwithin') then
    begin Name:=ReadTeXGroup(Source,P,'{','}'); Within:=ReadTeXGroup(Source,P,'{','}'); if Name='equation' then begin EquationWithin:=Within; DefaultEquationChapter:=False; end; Continue; end;
    if (Cmd='appendix') or (Cmd='frontmatter') or (Cmd='mainmatter') or (Cmd='backmatter') then begin
      ApplySectionCommand(FSections,'\'+Cmd); FStyles.Apply('\'+Cmd);
      if Cmd='frontmatter' then PageNumbering('roman',1)
      else if Cmd='mainmatter' then PageNumbering('arabic',1);
      RecordCounters; Continue;
    end;
    if (Cmd='setcounter') or (Cmd='addtocounter') then
    begin
      Name:=ReadTeXGroup(Source,P,'{','}'); Value:=ReadTeXGroup(Source,P,'{','}');
      if (Name='page') and TryStrToInt(Trim(Value),N) then PageNumbering('',N,Cmd='addtocounter');
      if (Name='secnumdepth') and (A<HeaderLength) then Continue;
      if not ApplySectionCommand(FSections,Copy(Source,A+1,P-A-1)) and TryStrToInt(Trim(Value),N) then begin
        if Cmd='addtocounter' then N:=EnsureRange(Int64(N)+StrToIntDef(FCounters.Values[Name],0),Low(Integer),High(Integer));
        FCounters.Values[Name]:=IntToStr(N); FNumbers.Values[Name]:=IntToStr(N);
      end;
      RecordCounters; Continue;
    end;
    if (Cmd='footnote') or (Cmd='footnotemark') then begin
      SkipTeXSpace(Source,P);
      if Copy(Source,P,1)='[' then ReadTeXGroup(Source,P,'[',']') else Advance('footnote','');
      RecordCounters;
      if Cmd='footnote' then ReadTeXGroup(Source,P,'{','}'); Continue;
    end;
    Level:=SectionIndex(Cmd);
    if Level>=0 then
    begin
      Star:=(P<=Length(Source)) and (Source[P]='*'); if Star then Inc(P);
      SkipTeXSpace(Source,P); if (P<=Length(Source)) and (Source[P]='[') then ReadTeXGroup(Source,P,'[',']');
      Value:=ReadTeXGroup(Source,P,'{','}'); if Star then begin HeadingLabels(Value,P-Length(Value)-2); Continue; end;
      M:=TContextMark.Create; M.Offset:=A; M.Counter:=Cmd; FMarks.Add(M);
      if StepSection(FSections,Level,False) then begin
        LastType:=Cmd; LastCaption:=Value; LastNumber:=FStyles.HeadingNumber(FSections,Cmd); LastTitle:=Cmd;
        M.Number:=LastNumber; if Cmd='part' then LastTitle:='Part';
        LastTitle:=FStyles.Name(Cmd+'autorefname',LastTitle);
        if FSections.Appendix and (Level=2-Ord(FStyles.HasChapters)) then LastTitle:=FStyles.Name('appendixautorefname','Appendix');
        ResetDependents(Cmd);
        if Level>0 then for I:=Level+1 to High(SectionNames) do ResetDependents(SectionNames[I]);
        RecordCounters;
      end;
      HeadingLabels(Value,P-Length(Value)-2); Continue;
    end;
    if Cmd='begin' then
    begin
      Name:=ReadTeXGroup(Source,P,'{','}');
      if Presentation then ReadBeamerOverlay(Source,P);
      if IsTeXVerbatimEnvironment(Name) then
      begin Value:='\end{'+Name+'}'; Q:=Pos(Value,Copy(Source,P,MaxInt)); if Q>0 then Inc(P,Q-1+Length(Value)) else P:=Length(Source)+1; Continue; end;
      T:=Theorem(Name);
      if (T<>nil) or (Name='proof') then
      begin
        M:=TContextMark.Create; M.Offset:=A;
        if T<>nil then begin M.Title:=T.Title; if not T.Starred then M.Number:=Advance(T.Counter,T.Within); end else M.Title:=FStyles.Name('proofname','Proof');
        SkipTeXSpace(Source,P); if (P<=Length(Source)) and (Source[P]='[') then begin Value:=ReadTeXGroup(Source,P,'[',']'); if Name='proof' then M.Title:=Value else M.Note:=Value; end;
        FMarks.Add(M); LastNumber:=M.Number; if T<>nil then LastTitle:=FStyles.Name(T.Name+'autorefname',T.Title) else LastTitle:=M.Title;
        LastType:=Name; LastCaption:=M.Note;
      end;
      F.Env:=Name; F.Tag:=''; F.Keys:=''; F.Start:=A; F.Row:=0; F.Suppressed:=False; F.HasTag:=False; F.BareTag:=False;
      Value:=StringReplace(Name,'*','',[]);
      F.Equation:=(Value='equation') or (Value='align') or (Value='alignat') or (Value='gather') or (Value='eqnarray'); F.Numbered:=Pos('*',Name)=0;
      SetLength(Frames,Length(Frames)+1); Frames[High(Frames)]:=F; Continue;
    end;
    if (Cmd='\') and (Length(Frames)>0) then
    begin if Frames[High(Frames)].Equation and (Pos('equation',Frames[High(Frames)].Env)<>1) then FinishEquation; Continue; end;
    if Cmd='end' then
    begin
      Name:=ReadTeXGroup(Source,P,'{','}');
      if (Length(Frames)>0) and (Frames[High(Frames)].Env=Name) then begin FinishEquation; SetLength(Frames,Length(Frames)-1); end;
      Continue;
    end;
    if (Cmd='caption') and (Length(Frames)>0) then begin
      Star:=(P<=Length(Source)) and (Source[P]='*'); if Star then Inc(P);
      SkipTeXSpace(Source,P); if (P<=Length(Source)) and (Source[P]='[') then ReadTeXGroup(Source,P,'[',']');
      Value:=ReadTeXGroup(Source,P,'{','}'); Name:='';
      for J:=High(Frames) downto 0 do begin
        Name:=StringReplace(Frames[J].Env,'*','',[]);
        if Name='wrapfigure' then Name:='figure' else if (Name='wraptable') or (Name='longtable') then Name:='table';
        if (Name='table') or (Name='figure') then Break;
      end;
      if (Name='table') or (Name='figure') then begin
        M:=TContextMark.Create; M.Offset:=A; M.Counter:=Name;
        if Name='figure' then Title:='Figure' else Title:='Table'; M.Title:=FStyles.Name(Name+'name',Title);
        Within:=''; if FStyles.HasChapters then Within:='chapter';
        if not Star then M.Number:=Advance(Name,Within,FStyles.HasChapters); M.Note:=Value; FMarks.Add(M);
        LastNumber:=M.Number; LastTitle:=FStyles.Name(Name+'autorefname',M.Title);
        LastType:=Name; LastCaption:=Value; HeadingLabels(Value,P-Length(Value)-2);
      end;
      Continue;
    end;
    if Cmd='tag' then
    begin
      I:=EquationFrame; if I<0 then Continue;
      Frames[I].BareTag:=(P<=Length(Source)) and (Source[P]='*');
      if Frames[I].BareTag then Inc(P);
      Frames[I].Tag:=ReadTeXGroup(Source,P,'{','}'); Frames[I].HasTag:=True; Continue;
    end;
    if (Cmd='notag') or (Cmd='nonumber') then begin I:=EquationFrame; if I>=0 then Frames[I].Suppressed:=True; end;
    if Cmd='label' then
    begin
      Name:=ReadTeXGroup(Source,P,'{','}'); if Name='' then Continue;
      DefineLabel(Name,LastNumber,LastTitle,LastType,LastCaption,A);
      I:=EquationFrame;
      if I>=0 then begin if Frames[I].Keys<>'' then Frames[I].Keys:=Frames[I].Keys+','; Frames[I].Keys:=Frames[I].Keys+Name; end;
    end;
  end;
  { Equation marks are completed at their closing delimiter, so nested
    environments can arrive out of order. Sort the owned list once rather
    than scanning it for every heading, equation row and contents entry. }
  FMarks.Sort(@CompareContextMarks);
  if Length(FCounterEvents)>Max(32,FCounterEventCount*4) then SetLength(FCounterEvents,Max(32,FCounterEventCount*2));
  { Text edits move source offsets but leave existing paragraph geometry and
    numbering intact. Invalidate other cards only when visible metadata changes. }
  LayoutKey:=Preamble+#1+Directory+#1+TeXContextDeclarations(Source)+#1+FCitations.Text+
    #1+FReferenceNames.Text+#1+FBibliographyData.LayoutSignature;
  for I:=0 to FLabels.Count-1 do begin
    LabelInfo:=TContextLabel(FLabels.Objects[I]);
    LayoutKey:=LayoutKey+#1+FLabels[I]+#1+LabelInfo.Number+#1+LabelInfo.Title+#1+LabelInfo.Kind+#1+LabelInfo.Caption;
  end;
  for I:=0 to High(FPageNumbers) do
    LayoutKey:=LayoutKey+#1+FPageNumbers[I].Style+#1+IntToStr(FPageNumbers[I].Value)+IntToStr(Ord(FPageNumbers[I].Relative));
  for I:=0 to FTheorems.Count-1 do begin
    T:=TTheoremInfo(FTheorems.Objects[I]);
    LayoutKey:=LayoutKey+#1+T.Name+#1+T.Title+#1+T.Style+#1+T.Counter+#1+T.Within+IntToStr(Ord(T.Starred));
  end;
  for I:=0 to FMarks.Count-1 do begin
    M:=TContextMark(FMarks[I]);
    LayoutKey:=LayoutKey+#1+M.Number+#1+M.Title+#1+M.Labels+#1+M.Note+#1+M.Counter+IntToStr(Ord(M.BareTag));
  end;
  for I:=0 to FCounterEventCount-1 do begin
    LayoutKey:=LayoutKey+#1+IntToStr(Ord(FCounterEvents[I].Sections.Appendix))+
      IntToStr(Ord(FCounterEvents[I].Sections.MainMatter))+#1+IntToStr(FCounterEvents[I].Sections.NumberDepth);
    for J:=0 to High(SectionNames) do LayoutKey:=LayoutKey+#1+IntToStr(FCounterEvents[I].Sections.Values[J]);
    for J:=0 to High(CounterNames) do LayoutKey:=LayoutKey+#1+IntToStr(FCounterEvents[I].Values[J]);
  end;
  if LayoutKey<>FLayoutKey then begin FLayoutKey:=LayoutKey; Inc(FLayoutRevision); end;
end;
end.
