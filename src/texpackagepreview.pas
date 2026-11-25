unit TeXPackagePreview;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils;
type
  TPackageArguments=array of string;
  TPackagePreviewPart=record
    Text:string;
    First,Count:Integer;
  end;
  TPackagePreviewParts=array of TPackagePreviewPart;
  PPackagePreviewParts=^TPackagePreviewParts;
  TPackagePreviewMap=array of TPackagePreviewParts;
  PPackagePreviewMap=^TPackagePreviewMap;
procedure PackagePreviewCommands(const PackageName:string; Dest:TStrings);
function PackageArgumentCount(const Adapter,Source:string; Position,Count:Integer):Integer;
const
  OneUnit:array[0..6] of string=('num','tablenum','unit','si','ang','numlist','numproduct');
  TwoUnits:array[0..1] of string=('qty','numrange');
  Ranges:array[0..1] of string=('qtyrange','SIrange');
  Lists:array[0..2] of string=('qtylist','qtyproduct','SIlist');
  Derivatives:array[0..5] of string=('odv','pdv','mdv','fdv','adv','jdv');
  Differentials:array[0..4] of string=('odif','pdif','mdif','fdif','adif');
function PackageLiteralArgument(const Adapter,Name:string; Index:Integer):Boolean;
function PackageVisibleArgument(const Adapter,Name:string; Index:Integer):Boolean;
function PackagePreviewSupported(const Adapter,Name,Source:string):Boolean;
function PackageTextTemplate(const Adapter,Name,Body,Context:string):string;
function PackageMathPreview(const Name:string; const Arguments:TPackageArguments;
  const Context:string; out Template:string; out Formatted:TPackageArguments; Mapping:PPackagePreviewMap=nil):Boolean;
implementation
uses Math, StrUtils, TeXMacros, TeXPackageSources, ExtensionSyntax;
var Units,Prefixes:TStringList; UnitContext:string; CustomUnits:TStringList;
procedure PackagePreviewCommands(const PackageName:string; Dest:TStrings);
  procedure Add(const Name,Signature,Body,Adapter:string);
  begin Dest.Add(Name+#9+Signature+#9+Body+#9+Adapter); end;
var Name:string;
begin
  Dest.Clear;
  case PackageName of
    'latex':begin
      Add('mathchoice','m m m m','','mathchoice');
      Add('mathpalette','m m','\mathchoice{#1\displaystyle{#2}}{#1\textstyle{#2}}'+
        '{#1\scriptstyle{#2}}{#1\scriptscriptstyle{#2}}','mathpalette');
      Add('mbox','m','','box'); Add('fbox','m','','box');
      Add('makebox','o O{c} m','','box'); Add('framebox','o O{c} m','','box');
      Add('rule','O{0pt} m m','','box'); Add('raisebox','m o o m','','box');
      Add('parbox','O{c} o o m m','','box');
      Add('hrule','','','box'); Add('vrule','','','box');
      Add('hspace','m','','space'); Add('hspace*','m','','space');
      Add('hfill','','','space'); Add('hfil','','','space'); Add('hfilneg','','','space'); Add('hss','','','space');
      Add('hrulefill','','','space'); Add('dotfill','','','space');
      Add('noindent','','','space'); Add('indent','','','space');
      Add('newsavebox','m','','metadata'); Add('sbox','m m','','metadata');
      Add('savebox','m o O{c} m','','metadata'); Add('usebox','m','','savedbox');
      Add('typeout','m','','metadata'); Add('message','m','','metadata');
      Add('ignorespaces','','','metadata'); Add('unskip','','','metadata');
      Add('shortstack','O{c} m','','stack');
      Add('phantom','m','','phantom'); Add('hphantom','m','','phantom'); Add('vphantom','m','','phantom');
    end;
    'hyperref','url':begin
      Add('url','m','\texttt{#1}','url'); Add('nolinkurl','m','\texttt{#1}','url');
      if PackageName='hyperref' then begin
        Add('href','O{} m m','#3','link'); Add('hyperref','o m','#2','link');
        Add('hyperlink','m m','#2','link'); Add('hypertarget','m m','#2','link');
        Add('texorpdfstring','m m','#1','');
        Add('hypersetup','m','','metadata'); Add('pdfbookmark','O{0} m m','','metadata');
      end;
    end;
    'siunitx':begin
      for Name in OneUnit do Add(Name,'O{} m','','units');
      for Name in TwoUnits do Add(Name,'O{} m m','','units');
      for Name in Ranges do Add(Name,'O{} m m m','','units');
      for Name in Lists do Add(Name,'O{} m m','','units');
      Add('SI','O{} m o m','','units');
    end;
    'derivative':begin
      for Name in Derivatives do Add(Name,'o m m','','derivative');
      for Name in Differentials do Add(Name,'o m','','derivative');
      Add('slashfrac','o m m','','derivative');
    end;
    'adjustbox':begin
      Add('adjustbox','m m','','adjustbox');
      Add('minsizebox','m m m','','box'); Add('maxsizebox','m m m','','box');
    end;
    'makecell':begin Add('makecell','O{c} m','','stack'); Add('thead','O{c} m','','stack'); end;
    'enumitem':Add('setlist','o m','','metadata');
    'color','xcolor','colortbl':begin
      Add('colorbox','o m m','','colorbox'); Add('fcolorbox','o m m m','','colorbox');
      Add('cellcolor','o m','','directive'); Add('rowcolor','o m o o','','directive');
      Add('columncolor','o m o o','','directive'); Add('arrayrulecolor','o m','','directive');
      Add('rowcolors','o m m m','','directive');
    end;
    'dashrule':Add('hdashrule','O{0pt} O{} m m m','','box');
    'pifont':begin Add('ding','m','','symbol'); Add('Pisymbol','m m','','symbol'); end;
    'diagbox':Add('diagbox','O{} m m','','diagbox');
  end;
  ExtensionCommands(PackageName,Dest);
end;
function PackageArgumentCount(const Adapter,Source:string; Position,Count:Integer):Integer;
begin
  Result:=Count; if Adapter<>'diagbox' then Exit;
  ReadTeXGroup(Source,Position,'[',']');
  ReadTeXGroup(Source,Position,'{','}'); ReadTeXGroup(Source,Position,'{','}'); SkipTeXSpace(Source,Position);
  if Copy(Source,Position,1)='{' then Inc(Result);
end;
function PackageLiteralArgument(const Adapter,Name:string; Index:Integer):Boolean;
begin
  if (Adapter='metadata') or (Adapter='directive') or (Adapter='savedbox') then Exit(True);
  if Adapter='stack' then Exit(Index=1);
  if Adapter='mathpalette' then Exit(Index=1);
  Result:=((Adapter='adjustbox') and (Index=1)) or ((Adapter='colorbox') and ((Index<=2) or ((Name='fcolorbox') and (Index=3)))) or (Adapter='literal') or ((Adapter='diagbox') and (Index=1)) or (Adapter='units') or (Adapter='url') or (Adapter='symbol') or
    (Adapter='space') or ((Adapter='box') and
      (((Name='rule') or (Name='hdashrule')) or ((Name='raisebox') and (Index<4)) or
       (((Name='minsizebox') or (Name='maxsizebox')) and (Index<3)) or
       (((Name='makebox') or (Name='framebox')) and (Index<3)) or
       ((Name='parbox') and (Index<5)))) or
    ((Adapter='derivative') and (Index=1)) or
    ((Adapter='link') and (((Name='href') and (Index<=2)) or
      ((Name<>'href') and (Index=1))));
end;
function PackageVisibleArgument(const Adapter,Name:string; Index:Integer):Boolean;
begin
  Result:=True;
  if (Adapter='metadata') or (Adapter='directive') or (Adapter='savedbox') then Exit(False);
  if Adapter='stack' then Exit(Index=2);
  if Adapter='adjustbox' then Exit(Index=2);
  if Adapter='colorbox' then Exit(Index=3+Ord(Name='fcolorbox'));
  if Adapter='diagbox' then Exit(Index>1);
  if (Adapter='units') or (Adapter='derivative') then Result:=Index>1
  else if Adapter='box' then begin
    if (Name='minsizebox') or (Name='maxsizebox') then Exit(Index=3);
    if (Name='makebox') or (Name='framebox') then Result:=Index=3
    else if Name='parbox' then Result:=Index=5
    else if Name='raisebox' then Result:=Index=4
    else Result:=(Name<>'rule') and (Name<>'hdashrule');
  end
  else if Adapter='link' then begin
    if Name='href' then Result:=Index=3 else Result:=Index=2;
  end else if Name='texorpdfstring' then Result:=Index=1;
end;
function StripGroup(const Value:string):string;
begin
  Result:=Trim(Value);
  if (Length(Result)>=2) and (Result[1]='{') and (Result[Length(Result)]='}') then
    Result:=Copy(Result,2,Length(Result)-2);
end;
procedure Options(const Value:string; Dest:TStrings);
var P,A,Depth,Equal:Integer; Item,Key:string;
begin
  P:=1; A:=1; Depth:=0;
  while P<=Length(Value)+1 do begin
    if P<=Length(Value) then begin
      if Value[P]='{' then Inc(Depth) else if Value[P]='}' then Dec(Depth);
    end;
    if (P>Length(Value)) or ((Value[P]=',') and (Depth=0)) then begin
      Item:=Trim(Copy(Value,A,P-A)); Equal:=Pos('=',Item);
      if Equal>0 then begin Key:=Trim(Copy(Item,1,Equal-1)); Dest.Values[Key]:=StripGroup(Copy(Item,Equal+1,MaxInt)); end
      else if Item<>'' then Dest.Values[Item]:='true';
      A:=P+1;
    end;
    Inc(P);
  end;
end;
procedure ContextOptions(const Context,PackageName,Setup:string; Dest:TStrings);
var P,Q:Integer; Command,Value,Packages:string;
begin
  P:=1;
  while P<=Length(Context) do begin
    if Context[P]='%' then begin while (P<=Length(Context)) and (Context[P]<>#10) do Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Context,Q) then begin P:=Q; Continue; end;
    if Context[P]<>'\' then begin Inc(P); Continue; end;
    Command:=ReadTeXCommand(Context,P);
    if Command=Setup then Options(ReadTeXGroup(Context,P,'{','}'),Dest)
    else if (Command='usepackage') or (Command='RequirePackage') then begin
      Value:=ReadTeXGroup(Context,P,'[',']'); Packages:=ReadTeXGroup(Context,P,'{','}');
      if Pos(','+PackageName+',',','+StringReplace(Packages,' ','',[rfReplaceAll])+',')>0 then Options(Value,Dest);
    end;
  end;
end;
function PackagePreviewSupported(const Adapter,Name,Source:string):Boolean;
var P,I:Integer; Command,Value,Key:string; Settings:TStringList;
begin
  Result:=Adapter<>'literal';
  if Adapter='adjustbox' then begin
    Settings:=TStringList.Create;
    try
      P:=1; ReadTeXCommand(Source,P); Options(ReadTeXGroup(Source,P,'{','}'),Settings);
      for I:=0 to Settings.Count-1 do if Pos('|'+Settings.Names[I]+'|','|width|height|totalheight|max width|max height|min width|min height|scale|center|left|right|frame|margin|padding|keepaspectratio|')=0 then Exit(False);
    finally Settings.Free; end;
    Exit;
  end;
  if (Adapter<>'units') and (Adapter<>'derivative') then Exit;
  P:=1; Command:=ReadTeXCommand(Source,P); if Copy(Source,P,1)='*' then Inc(P);
  Settings:=TStringList.Create;
  try
    Value:=ReadTeXGroup(Source,P,'[',']'); Options(Value,Settings);
    for I:=0 to Settings.Count-1 do begin
      Key:=Settings.Names[I];
      if Adapter='derivative' then begin if Key<>'order' then Exit(False); end
      else if Pos('|'+Key+'|','|locale|per-mode|group-digits|group-minimum-digits|group-separator|output-decimal-marker|'+
        'round-mode|round-precision|inter-unit-product|list-input-separator|product-input-separator|')=0 then Exit(False);
    end;
    if Adapter='derivative' then begin
      if Name='jdv' then Exit(False);
      ReadTeXGroup(Source,P,'{','}'); SkipTeXSpace(Source,P);
      if Copy(Source,P,1)='/' then begin Inc(P); SkipTeXSpace(Source,P); end;
      if Copy(Source,P,1)='!' then Exit(False);
    end;
  finally Settings.Free; end;
end;
function PackageTextTemplate(const Adapter,Name,Body,Context:string):string;
var Settings:TStringList; Color:string;
begin
  Result:=Body; if (Adapter<>'link') and (Adapter<>'url') then Exit;
  if (Name='hypertarget') or (Name='nolinkurl') then Exit;
  Settings:=TStringList.Create;
  try
    ContextOptions(Context,'hyperref','hypersetup',Settings);
    if Settings.Values['colorlinks']<>'true' then Exit;
    Color:=Settings.Values['linkcolor']; if Color='' then Color:='red';
    if (Name='href') or (Name='url') then begin Color:=Settings.Values['urlcolor']; if Color='' then Color:='magenta'; end;
    Result:='\textcolor{'+Color+'}{'+Body+'}';
  finally Settings.Free; end;
end;
procedure LoadUnits;
const BaseUnits:array[0..30] of string=('metre=m','meter=m','second=s','gram=g','kilogram=kg','ampere=A',
  'kelvin=K','mole=mol','candela=cd','radian=rad','steradian=sr','hertz=Hz','newton=N','pascal=Pa',
  'joule=J','watt=W','coulomb=C','volt=V','farad=F','siemens=S','weber=Wb','tesla=T','henry=H',
  'lumen=lm','lux=lx','becquerel=Bq','gray=Gy','sievert=Sv','katal=kat','litre=L','minute=min');
  BasePrefixes:array[0..19] of string=('quecto=q','ronto=r','yocto=y','zepto=z','atto=a','femto=f','pico=p',
    'nano=n','milli=m','centi=c','deci=d','deca=da','hecto=h','kilo=k','mega=M','giga=G','tera=T','peta=P','exa=E','zetta=Z');
var Source,Name,Value,Token:string; P,Q,A:Integer;
  procedure ReadDeclarations(const Prefix:string; PrefixList:Boolean);
  begin
    P:=1;
    repeat
      Q:=Pos(Prefix,Copy(Source,P,MaxInt)); if Q=0 then Break; Inc(P,Q-1+Length(Prefix));
      SkipTeXSpace(Source,P); Name:=ReadTeXCommand(Source,P); if Name='' then Continue;
      Value:=ReadTeXGroup(Source,P,'{','}');
      if PrefixList then begin Value:=ReadTeXGroup(Source,P,'{','}'); Prefixes.Values[Name]:=Trim(Value); end
      else Units.Values[Name]:=Trim(Value);
    until P>Length(Source);
  end;
begin
  if Units<>nil then Exit;
  Units:=TStringList.Create; Units.CaseSensitive:=True;
  Prefixes:=TStringList.Create; Prefixes.CaseSensitive:=True;
  CustomUnits:=TStringList.Create; CustomUnits.CaseSensitive:=True;
  for Token in BaseUnits do Units.Add(Token);
  for Token in BasePrefixes do Prefixes.Add(Token);
  Source:=ReadTeXSource(ResolveTeXSource('siunitx.sty',''));
  ReadDeclarations('\siunitx_declare_unit:Nn',False);
  ReadDeclarations('\siunitx_declare_prefix:Nnn',True);
  { Unicode units are generated through expl3 in the installed package. }
  Units.Values['ohm']:='\Omega'; Units.Values['degreeCelsius']:='{}^{\circ}C';
  Units.Values['degree']:='{}^{\circ}'; Units.Values['arcminute']:='{}^{\prime}';
  Units.Values['arcsecond']:='{}^{\prime\prime}'; Units.Values['percent']:='\%';
  Prefixes.Values['micro']:='\text{\textnormal{µ}}';
  Source:=ReadTeXSource(ResolveTeXSource('siunitx-abbreviations.cfg','')); P:=1;
  while P<=Length(Source) do begin
    A:=P; Token:=ReadTeXCommand(Source,P); if P=A then begin Inc(P); Continue; end;
    if Token<>'DeclareSIUnit' then Continue;
    ReadTeXGroup(Source,P,'[',']'); SkipTeXSpace(Source,P); Name:=ReadTeXCommand(Source,P);
    Value:=ReadTeXGroup(Source,P,'{','}'); if Name<>'' then Units.Values[Name]:=Value;
  end;
end;
procedure LoadCustomUnits(const Context:string);
var P,A,Q:Integer; Command,Name,Value:string;
begin
  LoadUnits; if Context=UnitContext then Exit; UnitContext:=Context; CustomUnits.Clear; P:=1;
  while P<=Length(Context) do begin
    if Context[P]='%' then begin while (P<=Length(Context)) and (Context[P]<>#10) do Inc(P); Continue; end;
    A:=P; Command:=ReadTeXCommand(Context,P); if P=A then begin Inc(P); Continue; end;
    if (Command<>'DeclareSIUnit') and (Command<>'DeclareSIPrefix') then Continue;
    ReadTeXGroup(Context,P,'[',']'); SkipTeXSpace(Context,P); Name:=ReadTeXCommand(Context,P);
    if Copy(Context,P,1)='{' then begin Value:=ReadTeXGroup(Context,P,'{','}'); Q:=1; Name:=ReadTeXCommand(Value,Q); end;
    Value:=ReadTeXGroup(Context,P,'{','}');
    if Command='DeclareSIPrefix' then ReadTeXGroup(Context,P,'{','}');
    if Name<>'' then CustomUnits.Values[Name]:=Value;
  end;
end;
function MappedToken(const Text,Source:string; First,Last:Integer; Parts:PPackagePreviewParts):string;
var N:Integer;
  function Characters(A,B:Integer):Integer;
  var I:Integer;
  begin Result:=0; for I:=A to B-1 do if Byte(Source[I]) and $C0<>$80 then Inc(Result); end;
begin
  Result:=Text; if Parts=nil then Exit;
  N:=Length(Parts^); SetLength(Parts^,N+1);
  Parts^[N].Text:=Text; Parts^[N].First:=Characters(1,First);
  Parts^[N].Count:=Characters(First,Last);
  Result:='\text{PasTeXNative'+IntToStr(N)+'}';
end;
function UnitTokens(const Value:string; Settings:TStrings; Depth:Integer=0;
  Parts:PPackagePreviewParts=nil):string;
var P,A,PowerFirst,PowerLast,N:Integer; Command,Part,Power,NextPower,Prefix,Last,Denominator,Product,PowerText:string; Per:Boolean;
  procedure Flush;
  begin
    if Last='' then Exit;
    PowerText:=Power;
    if Per and (Settings.Values['per-mode']<>'fraction') and (Settings.Values['per-mode']<>'symbol') and
       (Settings.Values['per-mode']<>'repeated-symbol') then begin
      if PowerText='' then PowerText:='-1'
      else if TryStrToInt(PowerText,N) then PowerText:=IntToStr(-N) else PowerText:='-('+PowerText+')';
    end;
    if PowerText<>'' then begin
      if (Parts<>nil) and (PowerFirst>0) then PowerText:=MappedToken(PowerText,Value,PowerFirst,PowerLast,Parts);
      Last:=Last+'^{'+PowerText+'}';
    end;
    if Per then begin
      if Denominator<>'' then Denominator:=Denominator+Product; Denominator:=Denominator+Last;
    end else begin
      if Result<>'' then Result:=Result+Product; Result:=Result+Last;
    end;
    Last:=''; Power:=''; PowerFirst:=0;
  end;
begin
  Result:=''; if Depth>12 then Exit; P:=1; Per:=False; Prefix:=''; Last:=''; Power:=''; NextPower:=''; Denominator:=''; PowerFirst:=0;
  Product:='\,'; if Settings.IndexOfName('inter-unit-product')>=0 then Product:=Settings.Values['inter-unit-product'];
  while P<=Length(Value) do begin
    A:=P;
    if Value[P] in [' ',#9,#10,#13,'~','.','*'] then begin
      Inc(P); Prefix:=Prefix+MappedToken('',Value,A,P,Parts); Continue;
    end;
    if Value[P]='^' then begin
      Inc(P); Power:=ReadTeXGroup(Value,P,'{','}'); if Power='' then begin Power:=Copy(Value,P,1); Inc(P); end;
      PowerFirst:=A; PowerLast:=P; Continue;
    end;
    if Value[P]<>'\' then begin
      while (P<=Length(Value)) and not (Value[P] in ['\',' ',#9,#10,#13,'~','^','.','*']) do Inc(P);
      Flush; Last:=Prefix+MappedToken('\mathrm{'+Copy(Value,A,P-A)+'}',Value,A,P,Parts); Prefix:='';
      Power:=NextPower; NextPower:=''; Continue;
    end;
    Command:=ReadTeXCommand(Value,P);
    if Command='per' then begin Flush; Per:=True; Prefix:=Prefix+MappedToken('',Value,A,P,Parts); Continue; end;
    if (Command='square') or (Command='cubic') then begin
      NextPower:=IfThen(Command='square','2','3');
      Prefix:=Prefix+MappedToken('',Value,A,P,Parts); Continue;
    end;
    if (Command='squared') or (Command='cubed') then begin
      Power:=IfThen(Command='squared','2','3'); PowerFirst:=A; PowerLast:=P; Continue;
    end;
    if (Command='tothe') or (Command='raiseto') then begin
      Power:=ReadTeXGroup(Value,P,'{','}'); PowerFirst:=A; PowerLast:=P; Continue;
    end;
    if Command='of' then begin
      Part:=ReadTeXGroup(Value,P,'{','}'); Last:=Last+'_{'+MappedToken('\mathrm{'+Part+'}',Value,A,P,Parts)+'}'; Continue;
    end;
    Part:=CustomUnits.Values[Command];
    if Part='' then begin
      Part:=Prefixes.Values[Command];
      if Part<>'' then begin Prefix:=Prefix+MappedToken('\mathrm{'+Part+'}',Value,A,P,Parts); Continue; end;
      Part:=Units.Values[Command];
    end;
    if Part='' then Part:='\'+Command
    else if Pos('\',Part)>0 then Part:=UnitTokens(Part,Settings,Depth+1)
    else Part:='\mathrm{'+Part+'}';
    Flush; Last:=Prefix+MappedToken(Part,Value,A,P,Parts); Prefix:=''; Power:=NextPower; NextPower:='';
  end;
  Flush; Result:=Result+Prefix;
  if Denominator<>'' then begin
    case Settings.Values['per-mode'] of
      'fraction':begin if Result='' then Result:='1'; Result:='\frac{'+Result+'}{'+Denominator+'}'; end;
      'symbol','repeated-symbol':begin if Result='' then Result:='1'; Result:=Result+'/'+Denominator; end;
      else begin if Result<>'' then Result:=Result+Product; Result:=Result+Denominator; end;
    end;
  end;
end;
function NumberTokens(const Value:string; Settings:TStrings; Parts:PPackagePreviewParts=nil):string;
var S,Mantissa,Exponent,Whole,Fraction,Uncertainty,Decimal,Separator:string; E,P,I,Minimum:Integer; V:Double; F:TFormatSettings; SourceIndex:array of Integer; Original:string;
  function Token(const Text:string; Index:Integer):string;
  begin
    Result:=Text; if (Parts=nil) or (Index<0) or (Index>=Length(SourceIndex)) then Exit;
    Result:=MappedToken(Text,Value,SourceIndex[Index],SourceIndex[Index]+1,Parts);
  end;
begin
  S:='';
  for I:=1 to Length(Value) do if not (Value[I] in [' ',#9,#10,#13]) then begin
    SetLength(SourceIndex,Length(S)+1); SourceIndex[Length(S)]:=I; S:=S+Value[I];
  end;
  Original:=S; S:=StringReplace(S,',','.',[rfReplaceAll]);
  E:=Pos('e',LowerCase(S)); Exponent:=''; if E>0 then begin Exponent:=Copy(S,E+1,MaxInt); S:=Copy(S,1,E-1); end;
  Uncertainty:=''; P:=Pos('(',S); if P>0 then begin Uncertainty:=Copy(S,P,MaxInt); S:=Copy(S,1,P-1); end;
  F:=DefaultFormatSettings; F.DecimalSeparator:='.';
  if (Settings.Values['round-mode']='places') and TryStrToFloat(S,V,F) then
    begin Parts:=nil; S:=FormatFloat('0'+IfThen(StrToIntDef(Settings.Values['round-precision'],2)>0,'.','')+
      StringOfChar('0',EnsureRange(StrToIntDef(Settings.Values['round-precision'],2),0,12)),V,F); end;
  Decimal:=Settings.Values['output-decimal-marker']; if Decimal='' then begin
    Decimal:='.'; if (Settings.Values['locale']='DE') or (Settings.Values['locale']='FR') then Decimal:=',';
  end;
  if Decimal=',' then Decimal:='{,}'; Separator:=Settings.Values['group-separator']; if Separator='' then Separator:='\,';
  Minimum:=Max(1,StrToIntDef(Settings.Values['group-minimum-digits'],5));
  P:=Pos('.',S); Whole:=S; Fraction:=''; if P>0 then begin Whole:=Copy(S,1,P-1); Fraction:=Copy(S,P+1,MaxInt); end;
  Mantissa:='';
  for I:=1 to Length(Whole) do begin
    Mantissa:=Mantissa+Token(Whole[I],I-1);
    if (Whole[I] in ['0'..'9']) and (Length(Whole)>=Minimum) and (I<Length(Whole)) and
       ((Length(Whole)-I) mod 3=0) and (Settings.Values['group-digits']<>'none') and
       (Settings.Values['group-digits']<>'false') and (Settings.Values['group-digits']<>'decimal') then Mantissa:=Mantissa+Separator;
  end;
  if P>0 then begin
    Mantissa:=Mantissa+Token(Decimal,P-1);
    for I:=1 to Length(Fraction) do begin
      Mantissa:=Mantissa+Token(Fraction[I],P+I-1);
      if (Length(Fraction)>=Minimum) and (I<Length(Fraction)) and (I mod 3=0) and
         (Settings.Values['group-digits']<>'none') and (Settings.Values['group-digits']<>'false') and
         (Settings.Values['group-digits']<>'integer') then Mantissa:=Mantissa+Separator;
    end;
  end;
  Result:=Mantissa+Uncertainty;
  if Exponent<>'' then begin
    if Copy(Exponent,1,1)='+' then Delete(Exponent,1,1);
    Result:=Result+Token('\times 10',E-1)+'^{';
    P:=E+1; if Copy(Original,P,1)='+' then Inc(P);
    for I:=P to Length(Original) do Result:=Result+Token(Original[I],I-1);
    Result:=Result+'}';
  end;
end;
function PackageMathPreview(const Name:string; const Arguments:TPackageArguments;
  const Context:string; out Template:string; out Formatted:TPackageArguments; Mapping:PPackagePreviewMap):Boolean;
var Settings,Values,Orders:TStringList; I,J,N,Total,First,Offset:Integer; UnitIndex,NumberIndex:Integer;
    Differential,Order,Numerator,Denominator,Part,TotalOrder:string; Star,Slash,Compact:Boolean;
  function Parts(Index:Integer):PPackagePreviewParts;
  begin Result:=nil; if Mapping<>nil then Result:=@Mapping^[Index-1]; end;
  function Marker(Index:Integer):string;
  begin Result:='\text{PasTeXDraftArg'+IntToStr(Index)+'}'; end;
  function Arg(Index:Integer):string;
  begin Result:=''; if (Index>0) and (Index<=Length(Arguments)) then Result:=Arguments[Index-1]; if Result='\NoValue' then Result:=''; end;
begin
  Template:=''; if Mapping<>nil then begin Mapping^:=nil; SetLength(Mapping^,Length(Arguments)); end; SetLength(Formatted,Length(Arguments)); for I:=0 to High(Formatted) do Formatted[I]:=#0;
  Result:=False; Settings:=TStringList.Create; Values:=TStringList.Create; Orders:=TStringList.Create;
  try
    Star:=Pos('*',Name)>0; Slash:=Pos('/',Name)>0; Compact:=Pos('!',Name)>0;
    Part:=StringReplace(StringReplace(StringReplace(Name,'*','',[]),'/','',[]),'!','',[]);
    if (Pos('dv',Part)>0) or (Pos('dif',Part)>0) or (Part='slashfrac') then begin
      ContextOptions(Context,'derivative','derivset',Settings); Options(Arg(1),Settings);
      if Part='slashfrac' then begin Template:=Marker(2)+'/'+Marker(3); Exit(True); end;
      case Part of
        'odv','odif':Differential:='\mathrm{d}'; 'mdv','mdif':Differential:='\mathrm{D}';
        'pdv','pdif','jdv':Differential:='\partial'; 'fdv','fdif':Differential:='\delta';
        'adv','adif':Differential:='\Delta'; else Exit;
      end;
      if Settings.Values['italic']='true' then Differential:=StringReplace(Differential,'\mathrm','\mathnormal',[]);
      Order:=Settings.Values['order']; if Order='' then Order:='1';
      if Pos('dif',Part)>0 then begin
        Template:=Differential; if Order<>'1' then Template:=Template+'^{'+Order+'}';
        Template:=Template+' '+Marker(2); Exit(True);
      end;
      if Compact or (Part='jdv') then Exit;
      Values.StrictDelimiter:=True; Values.Delimiter:=','; Values.DelimitedText:=Arg(3);
      if Values.Count=0 then Values.Add('');
      Orders.StrictDelimiter:=True; Orders.Delimiter:=','; Orders.DelimitedText:=Order;
      Total:=0; TotalOrder:=''; Denominator:='';
      for I:=0 to Values.Count-1 do begin
        Order:='1'; if I<Orders.Count then Order:=Trim(Orders[I]);
        N:=StrToIntDef(Order,-1);
        if N>=0 then Inc(Total,N) else begin if TotalOrder<>'' then TotalOrder:=TotalOrder+'+'; TotalOrder:=TotalOrder+Order; end;
        if Values.Count=1 then Part:=Marker(3) else Part:=Trim(Values[I]);
        Denominator:=Denominator+Differential+' '+Part; if Order<>'1' then Denominator:=Denominator+'^{'+Order+'}';
        if I<Values.Count-1 then Denominator:=Denominator+'\,';
      end;
      if TotalOrder='' then TotalOrder:=IntToStr(Total) else if Total>0 then TotalOrder:=TotalOrder+'+'+IntToStr(Total);
      Numerator:=Differential; if TotalOrder<>'1' then Numerator:=Numerator+'^{'+TotalOrder+'}';
      if not Star then Numerator:=Numerator+' '+Marker(2);
      if Slash then Template:='{'+Numerator+'}/{'+Denominator+'}'
      else Template:='\frac{'+Numerator+'}{'+Denominator+'}';
      if Star then Template:=Template+' '+Marker(2); Exit(True);
    end;
    ContextOptions(Context,'siunitx','sisetup',Settings); Options(Arg(1),Settings); LoadCustomUnits(Context);
    UnitIndex:=0; NumberIndex:=2;
    case Part of
      'unit','si':begin UnitIndex:=2; NumberIndex:=0; Template:=Marker(2); end;
      'qty':begin UnitIndex:=3; Template:=Marker(2)+'\,'+Marker(3); end;
      'SI':begin UnitIndex:=4; Template:=Marker(2)+'\,'+Marker(4); if Arg(3)<>'' then Template:=Template+Marker(3); end;
      'num','tablenum':Template:=Marker(2);
      'numrange','qtyrange','SIrange':begin
        Template:=Marker(2)+'\text{ to }'+Marker(3); Formatted[2]:=NumberTokens(Arg(3),Settings,Parts(3));
        if Part<>'numrange' then begin UnitIndex:=4; Template:=Template+'\,'+Marker(4); end;
      end;
      'numlist','qtylist','SIlist','numproduct','qtyproduct':begin
        Values.StrictDelimiter:=True; Values.Delimiter:=';';
        if Pos('product',Name)>0 then Values.Delimiter:='x';
        Part:=Settings.Values['list-input-separator']; if Pos('product',Name)>0 then Part:=Settings.Values['product-input-separator'];
        if Part<>'' then Values.Delimiter:=Part[1];
        Values.DelimitedText:=Arg(2); Part:='';
        for I:=0 to Values.Count-1 do begin
          if I>0 then begin
            if Pos('product',Name)>0 then Part:=Part+'\times '
            else if I=Values.Count-1 then Part:=Part+'\text{ and }' else Part:=Part+'{,}\,';
          end;
          Part:=Part+NumberTokens(Values[I],Settings);
        end;
        Formatted[1]:=Part; NumberIndex:=0; Template:=Marker(2);
        if (Name='qtylist') or (Name='SIlist') or (Name='qtyproduct') then begin UnitIndex:=3; Template:=Template+'\,'+Marker(3); end;
      end;
      'ang':begin
        Values.StrictDelimiter:=True; Values.Delimiter:=';'; Values.DelimitedText:=Arg(2); Part:=''; Offset:=0;
        for I:=0 to Min(2,Values.Count-1) do begin
          if Values[I]<>'' then begin
            First:=0; if Mapping<>nil then First:=Length(Mapping^[1]);
            Part:=Part+NumberTokens(Values[I],Settings,Parts(2));
            if Mapping<>nil then for J:=First to High(Mapping^[1]) do Inc(Mapping^[1][J].First,Offset);
            case I of 0:Part:=Part+'{}^{\circ}'; 1:Part:=Part+'{}^{\prime}'; 2:Part:=Part+'{}^{\prime\prime}'; end;
          end;
          for J:=1 to Length(Values[I]) do if Byte(Values[I][J]) and $C0<>$80 then Inc(Offset);
          Inc(Offset);
        end;
        Formatted[1]:=Part; NumberIndex:=0; Template:=Marker(2);
      end;
      else Exit;
    end;
    if NumberIndex>0 then Formatted[NumberIndex-1]:=NumberTokens(Arg(NumberIndex),Settings,Parts(NumberIndex));
    if UnitIndex>0 then Formatted[UnitIndex-1]:=UnitTokens(Arg(UnitIndex),Settings,0,Parts(UnitIndex));
    Result:=True;
  finally Orders.Free; Values.Free; Settings.Free; end;
end;
finalization
  CustomUnits.Free; Prefixes.Free; Units.Free;
end.
