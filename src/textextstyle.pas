unit TeXTextStyle;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses TeXMacros;
type
  TTeXTextStyle=record
    Encoding,Roman,Sans,Mono,DefaultFamily,Family,Series,Shape,SizeName,CJKFamily,CJKSizeScheme,CJKLineStretch:string;
    Points,BasePoints,Baseline,Spread,LineSkip,LineSkipLimit,CJKSpacing:Double;
  end;
function InitialTextStyle(const Input,Directory,Engine:string; Registry:TMacroRegistry=nil):TTeXTextStyle;
procedure ApplyTextStyle(var Style:TTeXTextStyle; const Code,Directory:string);
function IsTextStyleSwitch(const Command:string):Boolean;
procedure ReadTextStyleArguments(const Source,Command:string; var P:Integer);
function StripTextStylePrefix(const Prefix,Category:string):string;
function TextBaselineDistance(const Style:TTeXTextStyle; PreviousDepth,Height:Double):Double;
procedure TextCJKGlue(const Style:TTeXTextStyle; LineWidth,Indent:Double; out Stretch,Shrink:Double);
function TextScriptPoints(Points:Double; const Directory:string):Double;
procedure TextListSpacing(const Style:TTeXTextStyle; Depth:Integer; const Directory:string; out Top,Between:Double; Item:PDouble=nil; Paragraph:PDouble=nil);
function TextListPartSkip(const Style:TTeXTextStyle; Depth:Integer; const Directory:string):Double;
procedure TextDisplaySpacing(const Style:TTeXTextStyle; ShortLine:Boolean; const Directory:string; out Above,Below:Double);
implementation
uses Classes, SysUtils, Math, TeXFontShapes, TeXDocumentMetrics, TeXPackageSources, TeXStyles, TeXFontConfig, BeamerModel;
const SizeNames:array[0..9] of string=('tiny','scriptsize','footnotesize','small','normalsize','large','Large','LARGE','huge','Huge');
var SizeTables:array[8..20] of TStringList;
    ChineseTables:array[0..1] of TStringList;
    MathSizes,ChineseSizes:TStringList;
    ScriptRatio:Double=0.7;
function Number(const S:string; Default:Double):Double;
var F:TFormatSettings;
begin F:=DefaultFormatSettings; F.DecimalSeparator:='.'; Result:=StrToFloatDef(S,Default,F); end;
function Argument(const S:string; var P:Integer):string;
var A:Integer;
begin
  SkipTeXSpace(S,P); A:=P;
  if Copy(S,P,1)='{' then Exit(ReadTeXGroup(S,P,'{','}'));
  if Copy(S,P,1)='\' then ReadTeXCommand(S,P) else if P<=Length(S) then Inc(P);
  Result:=Copy(S,A,P-A);
end;
function TextScriptPoints(Points:Double; const Directory:string):Double;
var Source,Kernel,Command,TextSize,ScriptSize:string; P,I:Integer; Format:TFormatSettings;
  function Constant(const Value:string):Double;
  var P:Integer;
  begin
    if Copy(Value,1,1)<>'\' then Exit(Number(Value,-1));
    P:=Pos('\def'+Value+'{',Kernel);
    if P=0 then Exit(-1); Inc(P,Length('\def'+Value));
    Result:=Number(ReadTeXGroup(Kernel,P,'{','}'),-1);
  end;
begin
  if MathSizes=nil then begin
    MathSizes:=TStringList.Create;
    Kernel:=ReadTeXSource(ResolveTeXSource('latex.ltx',Directory));
    ScriptRatio:=Constant('\defaultscriptratio'); if ScriptRatio<=0 then ScriptRatio:=0.7;
    Source:=ReadTeXSource(ResolveTeXSource('fontmath.ltx',Directory)); P:=1;
    Format:=DefaultFormatSettings; Format.DecimalSeparator:='.';
    while P<=Length(Source) do begin
      SkipTeXSpace(Source,P); if P>Length(Source) then Break;
      if Source[P]<>'\' then begin Inc(P); Continue; end;
      Command:=ReadTeXCommand(Source,P); if Command<>'DeclareMathSizes' then Continue;
      TextSize:=Argument(Source,P); Argument(Source,P); ScriptSize:=Argument(Source,P); Argument(Source,P);
      if (Constant(TextSize)>0) and (Constant(ScriptSize)>0) then
        MathSizes.Values[FloatToStr(Constant(TextSize),Format)]:=FloatToStr(Constant(ScriptSize),Format);
    end;
  end;
  Result:=Points*ScriptRatio;
  for I:=0 to MathSizes.Count-1 do if Abs(Number(MathSizes.Names[I],-1)-Points)<0.001 then
    Exit(Number(MathSizes.ValueFromIndex[I],Result));
end;
function Dimension(const S:string; Em,Default:Double):Double;
var P:Integer; UnitName:string; N:Double;
begin
  P:=1; while (P<=Length(S)) and (S[P] in ['0'..'9','+','-','.']) do Inc(P);
  if P=1 then Exit(Default); N:=Number(Copy(S,1,P-1),Default); UnitName:=Trim(Copy(S,P,MaxInt));
  case UnitName of
    '','pt':Result:=N; 'bp':Result:=N*72.27/72; 'pc':Result:=12*N;
    'mm':Result:=N*72.27/25.4; 'cm':Result:=N*72.27/2.54; 'in':Result:=N*72.27;
    'em':Result:=N*Em; 'ex':Result:=N*Em*0.430555;
    else Result:=Default;
  end;
end;
procedure SizeTable(Base:Integer; const Directory:string);
var Registry:TMacroRegistry; Source,Kernel,Body,A,B,Name,Marker:string; P,Q:Integer;
  function Constant(const Value:string):string;
  var P,Q:Integer;
  begin
    Result:=Value; if Copy(Value,1,1)<>'\' then Exit;
    Marker:='\def'+Value+'{'; P:=Pos(Marker,Kernel);
    if P=0 then Exit; Inc(P,Length(Marker)-1); Q:=P; Result:=ReadTeXGroup(Kernel,Q,'{','}');
  end;
begin
  if SizeTables[Base]<>nil then Exit;
  SizeTables[Base]:=TStringList.Create; SizeTables[Base].CaseSensitive:=True;
  Source:=ReadTeXSource(ResolveTeXSource('size'+IntToStr(Base)+'.clo',Directory));
  Kernel:=ReadTeXSource(ResolveTeXSource('latex.ltx',Directory)); Registry:=TMacroRegistry.Create;
  try
    Registry.ApplyDefinitions(Source);
    for Name in SizeNames do begin
      if Registry.Find(Name)=nil then Continue; Body:=Registry.Find(Name).Body;
      SizeTables[Base].Values['@size:'+Name]:=Body;
      if Pos('\topsep',Body)>0 then SizeTables[Base].Values['@list:'+Name]:=Body;
      P:=Pos('\@setfontsize',Body); if P=0 then Continue; Inc(P,Length('\@setfontsize'));
      Argument(Body,P); A:=Constant(Argument(Body,P)); B:=Constant(Argument(Body,P));
      if (Number(A,-1)>0) and (Number(B,-1)>0) then SizeTables[Base].Values[Name]:=A+'/'+B;
    end;
    for Name in TStringArray.Create('@listi','@listii','@listiii') do
      if Registry.Find(Name)<>nil then SizeTables[Base].Values[Name]:=Registry.Find(Name).Body;
    P:=Pos('\setlength\partopsep',Source);
    if P>0 then begin Inc(P,Length('\setlength\partopsep')); SizeTables[Base].Values['@partopsep']:=ReadTeXGroup(Source,P,'{','}'); end;
  finally Registry.Free; end;
end;
function NaturalSkip(const Body,Name:string; Level:Integer=0):Double;
  var P,A:Integer; Command:string;
  begin
    Result:=0; if Level>3 then Exit;
    P:=Pos('\'+Name,Body); if P=0 then Exit; Inc(P,Length(Name)+1); SkipTeXSpace(Body,P);
    if Copy(Body,P,1)='\' then begin
      Command:=ReadTeXCommand(Body,P);
      if Command='p@' then Result:=1
      else if Command<>'z@' then Result:=NaturalSkip(Body,Command,Level+1);
      Exit;
    end;
    A:=P; while (P<=Length(Body)) and (Body[P] in ['0'..'9','+','-','.']) do Inc(P);
    Result:=Number(Copy(Body,A,P-A),0);
end;
function ListBody(const Style:TTeXTextStyle; Depth:Integer; const Directory:string):string;
var Base:Integer;
begin
  Base:=EnsureRange(Round(Style.BasePoints),Low(SizeTables),High(SizeTables)); SizeTable(Base,Directory);
  Result:=SizeTables[Base].Values['@listi'];
  if Depth=1 then Result:=SizeTables[Base].Values['@listii']
  else if Depth>1 then Result:=SizeTables[Base].Values['@listiii']
  else if SizeTables[Base].Values['@list:'+Style.SizeName]<>'' then Result:=SizeTables[Base].Values['@list:'+Style.SizeName];
end;
procedure TextListSpacing(const Style:TTeXTextStyle; Depth:Integer; const Directory:string; out Top,Between:Double; Item:PDouble; Paragraph:PDouble);
var Body:string; ItemSkip,ParagraphSkip:Double;
begin
  Body:=ListBody(Style,Depth,Directory);
  if Body='' then begin Top:=Style.BasePoints-2; ItemSkip:=Top/2; ParagraphSkip:=Top/2; end
  else begin Top:=NaturalSkip(Body,'topsep'); ItemSkip:=NaturalSkip(Body,'itemsep'); ParagraphSkip:=NaturalSkip(Body,'parsep'); end;
  Between:=ItemSkip+ParagraphSkip; if Item<>nil then Item^:=ItemSkip; if Paragraph<>nil then Paragraph^:=ParagraphSkip;
end;
function TextListPartSkip(const Style:TTeXTextStyle; Depth:Integer; const Directory:string):Double;
var Body:string; Base:Integer;
begin
  Body:=ListBody(Style,Depth,Directory); Base:=EnsureRange(Round(Style.BasePoints),Low(SizeTables),High(SizeTables));
  if Pos('\partopsep',Body)=0 then Body:='\partopsep '+SizeTables[Base].Values['@partopsep'];
  Result:=NaturalSkip(Body,'partopsep');
end;
procedure TextDisplaySpacing(const Style:TTeXTextStyle; ShortLine:Boolean; const Directory:string; out Above,Below:Double);
var Body,Prefix:string; Base:Integer;
begin
  Base:=EnsureRange(Round(Style.BasePoints),Low(SizeTables),High(SizeTables)); SizeTable(Base,Directory);
  Body:=SizeTables[Base].Values['@size:'+Style.SizeName];
  if Pos('\abovedisplayskip',Body)=0 then Body:=SizeTables[Base].Values['@size:normalsize'];
  Prefix:='display'; if ShortLine then Prefix:=Prefix+'short';
  Above:=NaturalSkip(Body,'above'+Prefix+'skip'); Below:=NaturalSkip(Body,'below'+Prefix+'skip');
end;
function ChineseSize(const Name,Directory:string; Default:Double):Double; forward;
procedure NamedSize(var Style:TTeXTextStyle; const Name,Directory:string);
var Base,P,Q:Integer; Pair,Source,Command,Key:string;
const Marker='\ctex_set_font_size:Nnn';
begin
  if Style.CJKSizeScheme<>'' then begin
    Base:=0; Pair:='ctex-c5size.clo'; if Style.CJKSizeScheme='-4' then begin Base:=1; Pair:='ctex-cs4size.clo'; end;
    if ChineseTables[Base]=nil then begin
      ChineseTables[Base]:=TStringList.Create; ChineseTables[Base].CaseSensitive:=True;
      Source:=ReadTeXSource(ResolveTeXSource(Pair,Directory)); P:=1;
      repeat
        Q:=Pos(Marker,Copy(Source,P,MaxInt)); if Q=0 then Break; Inc(P,Q-1+Length(Marker));
        Command:=Argument(Source,P); Key:=Argument(Source,P);
        if (Command<>'') and (Key<>'') then ChineseTables[Base].Values[Command]:=Trim(Key);
      until P>Length(Source);
    end;
    Key:=ChineseTables[Base].Values['\'+Name];
    if Key<>'' then begin
      Style.Points:=ChineseSize(Key,Directory,Style.Points); Style.Baseline:=1.2*Style.Points; Style.SizeName:=Name; Exit;
    end;
  end;
  Base:=EnsureRange(Round(Style.BasePoints),Low(SizeTables),High(SizeTables)); SizeTable(Base,Directory);
  Pair:=SizeTables[Base].Values[Name]; P:=Pos('/',Pair);
  if P=0 then Exit;
  Style.Points:=Number(Copy(Pair,1,P-1),Style.Points);
  Style.Baseline:=Number(Copy(Pair,P+1,MaxInt),Style.Baseline); Style.SizeName:=Name;
end;
function IsTextStyleSwitch(const Command:string):Boolean;
var Name:string;
begin
  for Name in SizeNames do if Command=Name then Exit(True);
  Result:=(Command='rm') or (Command='sf') or (Command='tt') or (Command='bf') or
    (Command='it') or (Command='sl') or (Command='sc') or
    (Command='fontsize') or (Command='selectfont') or (Command='normalfont') or
    (Command='bfseries') or (Command='mdseries') or (Command='itshape') or (Command='slshape') or
    (Command='scshape') or (Command='upshape') or (Command='rmfamily') or (Command='sffamily') or (Command='ttfamily') or
    (Command='songti') or (Command='heiti') or (Command='fangsong') or (Command='kaishu') or
    (Command='lishu') or (Command='youyuan') or (Command='CJKfamily') or (Command='fontfamily') or (Command='zihao') or (Command='ziju');
end;
procedure ReadTextStyleArguments(const Source,Command:string; var P:Integer);
begin
  if Command='fontsize' then begin Argument(Source,P); Argument(Source,P); end
  else if (Command='CJKfamily') or (Command='fontfamily') or (Command='zihao') or (Command='ziju') then Argument(Source,P);
end;
function ChineseSize(const Name,Directory:string; Default:Double):Double;
const Fallback='8,5;7,5.5;-6,6.5;6,7.5;-5,9;5,10.5;-4,12;4,14;-3,15;3,16;-2,18;2,22;-1,24;1,26;-0,36;0,42';
var Source,Key,Value:string; P,I:Integer; Pairs:TStringList;
begin
  if ChineseSizes=nil then begin
    ChineseSizes:=TStringList.Create; Source:=ReadTeXSource(ResolveTeXSource('ctexsize.sty',Directory));
    P:=Pos('\seq_new:N \c__ctex_font_size_seq',Source);
    if P>0 then begin Delete(Source,1,P-1); P:=Pos('\clist_map_inline:nn',Source); end;
    if P>0 then begin Inc(P,Length('\clist_map_inline:nn')); Source:=ReadTeXGroup(Source,P,'{','}'); end else Source:='';
    { The installed size table is a list of {size-name}{size in bp} pairs. }
    P:=1;
    while P<=Length(Source) do begin
      SkipTeXSpace(Source,P); if Copy(Source,P,1)=',' then begin Inc(P); Continue; end;
      I:=P; Key:=ReadTeXGroup(Source,P,'{','}'); Value:=ReadTeXGroup(Source,P,'{','}');
      if (Trim(Key)<>'') and (Trim(Value)<>'') then ChineseSizes.Values[Trim(Key)]:=Trim(StringReplace(Value,'bp','',[]));
      if P=I then Inc(P);
    end;
    if ChineseSizes.Count=0 then begin
      Pairs:=TStringList.Create;
      try
        Pairs.StrictDelimiter:=True; Pairs.Delimiter:=';'; Pairs.DelimitedText:=Fallback;
        for Value in Pairs do begin I:=Pos(',',Value); ChineseSizes.Values[Copy(Value,1,I-1)]:=Copy(Value,I+1,MaxInt); end;
      finally Pairs.Free; end;
    end;
  end;
  Result:=Number(ChineseSizes.Values[Trim(Name)],Default*72/72.27)*72.27/72;
end;
function StripTextStylePrefix(const Prefix,Category:string):string;
var P,A:Integer; Command,Part:string; Remove,Changed:Boolean;
  function Matches(const Name:string):Boolean;
  var Size:string;
  begin
    Result:=False;
    if Category='@all' then Exit(IsTextStyleSwitch(Name) or (Copy(Name,1,4)='text') or (Name='emph') or (Name='underline'));
    if Category='@family' then Exit((Name='textrm') or (Name='textsf') or (Name='texttt') or
      (Name='rmfamily') or (Name='sffamily') or (Name='ttfamily'));
    if Category='@series' then Exit((Name='textbf') or (Name='textmd') or (Name='bfseries') or (Name='mdseries'));
    if Category='@slope' then Exit((Name='textit') or (Name='textsl') or (Name='textup') or (Name='emph') or
      (Name='itshape') or (Name='slshape') or (Name='upshape'));
    if Category='\textsc' then Exit((Name='textsc') or (Name='scshape'));
    if Category='@size' then begin
      if Name='fontsize' then Exit(True); for Size in SizeNames do if Name=Size then Exit(True);
    end;
    Result:='\'+Name=Category;
  end;
begin
  Result:=Prefix; if Category='' then Exit; P:=1;
  if Copy(Prefix,1,2)<>'{\' then begin
    Command:=ReadTeXCommand(Prefix,P); if Matches(Command) then Result:=''; Exit;
  end;
  P:=2; Result:='{'; Changed:=False;
  while P<=Length(Prefix) do begin
    A:=P; Command:=ReadTeXCommand(Prefix,P); if Command='' then begin Inc(P); Continue; end;
    if Command='fontsize' then begin Argument(Prefix,P); Argument(Prefix,P); end;
    Part:=Copy(Prefix,A,P-A); Remove:=Matches(Command) or ((Command='selectfont') and (Category='@size'));
    Changed:=Changed or Remove;
    SkipTeXSpace(Prefix,P);
    if not Remove then Result:=Result+Part+' ';
  end;
  if not Changed then Result:=Prefix else if Result='{' then Result:='';
end;
procedure CTeXLineStretch(var Style:TTeXTextStyle; const Options:string);
var S,Key:string; P,A,Q:Integer;
begin
  if Style.CJKLineStretch='' then Exit;
  P:=1;
  while P<=Length(Options) do begin
    SkipTeXSpace(Options,P); A:=P;
    while (P<=Length(Options)) and not (Options[P] in ['=',',','{']) do Inc(P);
    Key:=Trim(Copy(Options,A,P-A)); S:='';
    if Copy(Options,P,1)='=' then begin
      Inc(P); SkipTeXSpace(Options,P); A:=P;
      while (P<=Length(Options)) and (Options[P]<>',') do begin
        if Options[P]='{' then ReadTeXGroup(Options,P,'{','}') else Inc(P);
      end;
      S:=Trim(Copy(Options,A,P-A));
      Q:=1; if Copy(S,1,1)='{' then S:=Trim(ReadTeXGroup(S,Q,'{','}'));
    end else if Copy(Options,P,1)='{' then ReadTeXGroup(Options,P,'{','}');
    if (Key='linestretch') and (S<>'') then Style.CJKLineStretch:=S;
    if Copy(Options,P,1)=',' then Inc(P);
  end;
end;
procedure ApplyTextStyle(var Style:TTeXTextStyle; const Code,Directory:string);
var P,Q:Integer; Command,Requested,A,B:string; Font:TDocumentFont;
begin
  P:=1;
  while P<=Length(Code) do begin
    if Code[P]='%' then begin while (P<=Length(Code)) and (Code[P]<>#10) do Inc(P); Continue; end;
    if Code[P]<>'\' then begin Inc(P); Continue; end;
    if ReadDocumentFont(Code,P,Font) then Continue;
    Q:=P; if ReadTeXDefinition(Code,Q) then begin P:=Q; Continue; end;
    Command:=ReadTeXCommand(Code,P); Requested:='';
    if (Command='rm') or (Command='sf') or (Command='tt') or (Command='bf') or
       (Command='it') or (Command='sl') or (Command='sc') then begin
      Style.Family:=Style.DefaultFamily; if Style.Family='' then Style.Family:=Style.Roman;
      Style.Series:='m'; Style.Shape:='n';
    end;
    case Command of
      'textrm','rmfamily','rm':Style.Family:=Style.Roman;
      'textsf','sffamily','sf':Style.Family:=Style.Sans;
      'texttt','ttfamily','tt':Style.Family:=Style.Mono;
      'textnormal','normalfont':begin
        Style.Family:=Style.DefaultFamily; if Style.Family='' then Style.Family:=Style.Roman;
        Style.Series:='m'; Style.Shape:='n'; Style.CJKFamily:='';
      end;
      'songti':Style.CJKFamily:='zhsong'; 'heiti':Style.CJKFamily:='zhhei';
      'fangsong':Style.CJKFamily:='zhfs'; 'kaishu':Style.CJKFamily:='zhkai';
      'lishu':Style.CJKFamily:='zhli'; 'youyuan':Style.CJKFamily:='zhyou';
      'CJKfamily':Style.CJKFamily:=Argument(Code,P);
      'fontfamily':Style.Family:=Argument(Code,P);
      'ctexset':CTeXLineStretch(Style,Argument(Code,P));
      'ziju':Style.CJKSpacing:=EnsureRange(Number(Argument(Code,P),Style.CJKSpacing),-0.9,20);
      'zihao':begin
        Style.Points:=ChineseSize(Argument(Code,P),Directory,Style.Points);
        Style.Baseline:=1.2*Style.Points; Style.SizeName:='';
      end;
      'textbf','bfseries','bf':Style.Series:='bx';
      'textmd','mdseries':Style.Series:='m';
      'textit','itshape','it':Requested:='it';
      'textsl','slshape','sl':Requested:='sl';
      'textsc','scshape','sc':Requested:='sc';
      'textup','upshape':Requested:='up';
      'emph':if (Pos('it',Style.Shape)>0) or (Pos('sl',Style.Shape)>0) then Requested:='up' else Requested:='it';
      'fontsize':begin
        A:=Argument(Code,P); B:=Argument(Code,P);
        Style.Points:=EnsureRange(Dimension(A,Style.Points,Style.Points),1,240);
        Style.Baseline:=Max(0,Dimension(B,Style.Points,Style.Baseline)); Style.SizeName:='';
      end;
      'linespread':Style.Spread:=Max(0,Number(Argument(Code,P),Style.Spread));
      'baselinestretch':Style.Spread:=Max(0,Number(Argument(Code,P),Style.Spread));
      'setlength':begin
        A:=Argument(Code,P); B:=Argument(Code,P);
        case A of
          '\baselineskip':Style.Baseline:=Dimension(B,Style.Points,Style.Baseline)/Max(0.001,Style.Spread);
          '\lineskip':Style.LineSkip:=Dimension(B,Style.Points,Style.LineSkip);
          '\lineskiplimit':Style.LineSkipLimit:=Dimension(B,Style.Points,Style.LineSkipLimit);
        end;
      end;
      else if IsTextStyleSwitch(Command) then NamedSize(Style,Command,Directory);
    end;
    if Requested<>'' then Style.Shape:=MergeFontShape(Style.Encoding,Style.Family,Style.Series,Style.Shape,Requested,Directory);
    { Prefixes contain arguments such as color names. They must not execute
      formatting commands hidden inside those arguments. }
    if (Command='textcolor') or (Command='color') then begin
      SkipTeXSpace(Code,P); if Copy(Code,P,1)='[' then ReadTeXGroup(Code,P,'[',']'); Argument(Code,P);
    end;
  end;
end;
function InitialTextStyle(const Input,Directory,Engine:string; Registry:TMacroRegistry):TTeXTextStyle;
var P,Q,A:Integer; Preamble,Command,Options,Packages,Value,Header,Declarations,DocumentDefinitions:string; Info:TMacroInfo; UserDefinitions:TMacroRegistry; Font:TDocumentFont; SizeExplicit:Boolean; Slides:TBeamerSettings;
  procedure Family(const Name:string; var Value:string);
  var I:Integer; S:string;
  begin
    if Registry=nil then Exit; Info:=Registry.Find(Name); if Info=nil then Exit;
    S:=Trim(Info.Body); if S='' then Exit;
    for I:=1 to Length(S) do if not (S[I] in ['a'..'z','A'..'Z','0'..'9']) then Exit;
    Value:=S;
  end;
  procedure CTeXSpacing(const Options:string);
  const Marker='\l__ctex_line_spread_fp {';
  var Source,Part,Compact:string; Parts:TStringList; P:Integer;
  begin
    Compact:=StringReplace(Options,' ','',[rfReplaceAll]);
    Result.CJKLineStretch:='1'; CTeXLineStretch(Result,Options);
    if (Pos('scheme=plain',Compact)=0) and (Pos('nocap',Compact)=0) then begin
      { ctex-scheme-chinese.def chooses c5size unless a class/package size
        was supplied. This affects Latin text as well as Chinese glyphs. }
      if not Slides.Enabled then begin
        if not SizeExplicit then Result.CJKSizeScheme:='5';
        Source:=ReadTeXSource(ResolveTeXSource('ctex-scheme-chinese.def',Directory));
        P:=Pos(Marker,Source);
        if P>0 then begin Inc(P,Length(Marker)-1); Result.Spread:=Number(ReadTeXGroup(Source,P,'{','}'),1.3); end
        else Result.Spread:=1.3;
      end;
    end;
    Parts:=TStringList.Create;
    try
      Parts.StrictDelimiter:=True; Parts.Delimiter:=','; Parts.DelimitedText:=Compact;
      for Part in Parts do begin
        if Copy(Part,1,11)='linespread=' then Result.Spread:=Number(Copy(Part,12,MaxInt),Result.Spread);
        if (Part='zihao=5') or (Part='c5size') then Result.CJKSizeScheme:='5';
        if (Part='zihao=-4') or (Part='cs4size') then Result.CJKSizeScheme:='-4';
        if (Part='zihao=false') or (Part='10pt') or (Part='11pt') or (Part='12pt') then Result.CJKSizeScheme:='';
      end;
    finally Parts.Free; end;
  end;
begin
  Preamble:=ActiveTeXSource(Input,Engine); Slides:=BeamerSettings(Preamble);
  Result:=Default(TTeXTextStyle); Result.BasePoints:=DocumentFontPoints(Preamble);
  Result.Points:=Result.BasePoints; Result.Baseline:=Result.Points*1.2;
  Result.Spread:=1; Result.LineSkip:=1; Result.Encoding:='OT1';
  Result.Roman:='cmr'; Result.Sans:='cmss'; Result.Mono:='cmtt';
  { fonttext.ltx chooses TU and Latin Modern whenever Unicode math codes
    are available, including XeLaTeX/LuaLaTeX without fontspec. }
  if (Engine='xelatex') or (Engine='lualatex') then begin
    Result.Encoding:='TU'; Result.Roman:='lmr'; Result.Sans:='lmss'; Result.Mono:='lmtt';
  end;
  Family('rmdefault',Result.Roman); Family('sfdefault',Result.Sans); Family('ttdefault',Result.Mono);
  Header:=TeXStylePreamble(Preamble); Declarations:=''; DocumentDefinitions:=''; P:=1; SizeExplicit:=False;
  while P<=Length(Header) do begin
    if Header[P]='%' then begin while (P<=Length(Header)) and (Header[P]<>#10) do Inc(P); Continue; end;
    if Header[P]<>'\' then begin Inc(P); Continue; end;
    if ReadDocumentFont(Header,P,Font) then Continue;
    Q:=P; if ReadTeXDefinition(Header,Q) then begin DocumentDefinitions:=DocumentDefinitions+Copy(Header,P,Q-P); P:=Q; Continue; end;
    A:=P; Command:=ReadTeXCommand(Header,P);
    if IsTextStyleSwitch(Command) or (Command='linespread') or (Command='setlength') or (Command='ctexset') then begin
      if Command='ctexset' then Argument(Header,P)
      else if Command='setlength' then begin Argument(Header,P); Argument(Header,P); end
      else if Command='linespread' then Argument(Header,P);
      if IsTextStyleSwitch(Command) then ReadTextStyleArguments(Header,Command,P);
      Declarations:=Declarations+Copy(Header,A,P-A); Continue;
    end;
    if Command='documentclass' then begin
      Options:=''; SkipTeXSpace(Header,P); if Copy(Header,P,1)='[' then Options:=ReadTeXGroup(Header,P,'[',']');
      Value:=ReadTeXGroup(Header,P,'{','}');
      Packages:=','+StringReplace(Options,' ','',[rfReplaceAll])+',';
      SizeExplicit:=(Pos(',10pt,',Packages)>0) or (Pos(',11pt,',Packages)>0) or (Pos(',12pt,',Packages)>0);
      if Pos('ctex',Value)=1 then CTeXSpacing(Options);
      Continue;
    end;
    if (Command<>'usepackage') and (Command<>'RequirePackage') then begin
      Q:=P; SkipTeXSpace(Header,Q);
      while (Copy(Header,Q,1)='{') or (Copy(Header,Q,1)='[') do begin
        if Header[Q]='{' then ReadTeXGroup(Header,Q,'{','}') else ReadTeXGroup(Header,Q,'[',']');
        SkipTeXSpace(Header,Q); P:=Q;
      end;
      Continue;
    end;
    SkipTeXSpace(Header,P); Options:=''; if Copy(Header,P,1)='[' then Options:=ReadTeXGroup(Header,P,'[',']');
    Packages:=','+StringReplace(ReadTeXGroup(Header,P,'{','}'),' ','',[rfReplaceAll])+',';
    if Pos(',ctex,',Packages)>0 then CTeXSpacing(Options);
    if Pos(',fontenc,',Packages)>0 then begin
      Q:=LastDelimiter(',',Options); Value:=Trim(Copy(Options,Q+1,MaxInt));
      if (Value='OT1') or (Value='T1') then Result.Encoding:=Value;
    end;
    if Pos(',lmodern,',Packages)>0 then begin
      Result.Roman:='lmr'; Result.Sans:='lmss'; Result.Mono:='lmtt';
      if Pos(',variablett,',','+StringReplace(Options,' ','',[rfReplaceAll])+',')>0 then Result.Mono:='lmvtt';
    end;
  end;
  Value:=''; UserDefinitions:=TMacroRegistry.Create;
  try
    UserDefinitions.ApplyDefinitions(DocumentDefinitions);
    if UserDefinitions.Find('rmdefault')<>nil then Result.Roman:=Trim(UserDefinitions.Find('rmdefault').Body);
    if UserDefinitions.Find('sfdefault')<>nil then Result.Sans:=Trim(UserDefinitions.Find('sfdefault').Body);
    if UserDefinitions.Find('ttdefault')<>nil then Result.Mono:=Trim(UserDefinitions.Find('ttdefault').Body);
    if UserDefinitions.Find('familydefault')<>nil then Value:=Trim(UserDefinitions.Find('familydefault').Body);
  finally UserDefinitions.Free; end;
  Result.Family:=Result.Roman; Result.Series:='m'; Result.Shape:='n'; NamedSize(Result,'normalsize',Directory);
  if Slides.Enabled and not Slides.Serif then Result.Family:=Result.Sans;
  if Value='\rmdefault' then Result.Family:=Result.Roman
  else if Value='\sfdefault' then Result.Family:=Result.Sans
  else if Value='\ttdefault' then Result.Family:=Result.Mono
  else if (Value<>'') and (Pos('\',Value)=0) then Result.Family:=Value;
  Result.DefaultFamily:=Result.Family;
  if Result.CJKSizeScheme<>'' then Result.BasePoints:=Result.Points;
  if Registry<>nil then begin Info:=Registry.Find('baselinestretch'); if Info<>nil then Result.Spread:=Max(0,Number(Info.Body,Result.Spread)); end;
  { Run only declarations at top level, leaving macro definitions opaque. }
  ApplyTextStyle(Result,Declarations,Directory);
end;
procedure TextCJKGlue(const Style:TTeXTextStyle; LineWidth,Indent:Double; out Stretch,Shrink:Double);
var Em,Reserve,Remainder:Double; N:Integer; Value:string;
begin
  Stretch:=0.08*Style.Baseline*Style.Spread; Shrink:=Abs(Style.CJKSpacing*Style.Points);
  if Style.CJKLineStretch='' then Exit;
  Em:=Style.Points*(1+Style.CJKSpacing); if Em<=0 then begin Stretch:=0; Exit; end;
  { ctex.sty, ctex_update_stretch / ctex_update_ziju: reserve one
    character by default, distributing the remaining line width as glue. }
  if Style.CJKSpacing<>0 then begin
    Remainder:=LineWidth-Style.Points; N:=Trunc(Remainder/Em); Remainder:=Remainder-N*Em;
    if (Indent<>0) and (N>=3) then Dec(N,2);
    if N>0 then begin Stretch:=Remainder/N; Shrink:=Min(Shrink,Max(0,(Em-Remainder)/(N+1))); end
    else Stretch:=0;
    Exit;
  end;
  Value:=Style.CJKLineStretch; if Value='\maxdimen' then Exit;
  Value:=StringReplace(Value,'\ccwd','em',[rfReplaceAll]);
  if Value='em' then Value:='1em';
  Val(Value,Reserve,N);
  if N=0 then begin
    if IsNan(Reserve) or IsInfinite(Reserve) or (Reserve<0) then Exit;
    if Reserve>=Max(0,(LineWidth-Em)/Em) then begin Stretch:=0; Exit; end;
    Reserve:=Reserve*Em;
  end else Reserve:=Dimension(Value,Em,-1);
  if IsNan(Reserve) or IsInfinite(Reserve) or (Reserve<0) then Exit;
  if Reserve>=LineWidth-Em then begin Stretch:=0; Exit; end;
  N:=Trunc((LineWidth-Em-Reserve)/Em);
  if N>0 then Stretch:=Max(0,(LineWidth-Em-N*Em)/N) else Stretch:=0;
end;
function TextBaselineDistance(const Style:TTeXTextStyle; PreviousDepth,Height:Double):Double;
begin
  Result:=Style.Baseline*Style.Spread;
  { tex.web, append_to_vlist: d = baseline_skip - prev_depth - height(b). }
  if Result-PreviousDepth-Height<Style.LineSkipLimit then Result:=PreviousDepth+Height+Style.LineSkip;
end;
var I:Integer;
finalization
  MathSizes.Free;
  ChineseSizes.Free;
  for I:=Low(ChineseTables) to High(ChineseTables) do ChineseTables[I].Free;
  for I:=Low(SizeTables) to High(SizeTables) do SizeTables[I].Free;
end.
