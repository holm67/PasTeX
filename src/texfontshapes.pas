unit TeXFontShapes;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
function UnicodeFontShape(const Family,Series,Shape:string; Points:Double; const Directory:string=''):string;
function MetricFontShape(const Family,Series,Shape:string; Points:Double; const Directory:string=''; const Encoding:string='OT1'):string;
function MergeFontShape(const Encoding,Family,Series,Current,Requested:string; const Directory:string=''):string;
function OT1Unicode(Code:Integer):Integer;
implementation
uses Classes, SysUtils, Math, Contnrs, TeXMacros, TeXPackageSources, TeXFontData, BundledTeX;
type TShapeDefinitions=class
  Path,Source:string;
  Definitions:TStringList;
  destructor Destroy; override;
end;
var DefinitionsCache:TObjectList; ShapeRules,BundledShapes:TStringList; ShapeRuleSource:string;
destructor TShapeDefinitions.Destroy;
begin Definitions.Free; inherited Destroy; end;
function FontDefinition(const WantedEncoding,Family,Series,Shape,Directory:string):string;
var Path,Source,Command,Encoding,FontFamily,FontSeries,FontShape,Name,Expanded:string;
    Entry:TShapeDefinitions; I,P,Q,J:Integer; Registry:TMacroRegistry; Macro:TMacroInfo;
    Arguments:array[1..6] of string;
  procedure Declaration(const Text:string; var Position:Integer);
  begin
    Encoding:=ReadTeXGroup(Text,Position,'{','}'); FontFamily:=ReadTeXGroup(Text,Position,'{','}');
    FontSeries:=ReadTeXGroup(Text,Position,'{','}'); FontShape:=ReadTeXGroup(Text,Position,'{','}');
    Name:=ReadTeXGroup(Text,Position,'{','}'); ReadTeXGroup(Text,Position,'{','}');
    if (Encoding=WantedEncoding) and (FontFamily=Family) then Entry.Definitions.Values[FontSeries+'/'+FontShape]:=Name;
  end;
begin
  if BundledShapes=nil then begin
    BundledShapes:=TStringList.Create; BundledShapes.CaseSensitive:=True; BundledShapes.NameValueSeparator:=#9;
    Path:=BundledTeXFile('font-shapes.tsv'); if Path<>'' then BundledShapes.LoadFromFile(Path);
  end;
  Name:=LowerCase(WantedEncoding+Family)+'.fd';
  if not FileExists(IncludeTrailingPathDelimiter(Directory)+Name) then begin
    Result:=BundledShapes.Values[WantedEncoding+'/'+Family+'/'+Series+'/'+Shape]; if Result<>'' then Exit;
  end;
  Result:=''; Path:=ResolveTeXSource(LowerCase(WantedEncoding+Family)+'.fd',Directory); Source:=ReadTeXSource(Path);
  if Source='' then Exit;
  for I:=0 to DefinitionsCache.Count-1 do begin
    Entry:=TShapeDefinitions(DefinitionsCache[I]);
    if Entry.Path=Path then begin
      if Entry.Source=Source then Exit(Entry.Definitions.Values[Series+'/'+Shape]);
      DefinitionsCache.Delete(I); Break;
    end;
  end;
  Entry:=TShapeDefinitions.Create; Entry.Path:=Path; Entry.Source:=Source; Entry.Definitions:=TStringList.Create;
  Registry:=TMacroRegistry.Create;
  try
  Registry.ApplyDefinitions(Source); P:=1;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) then begin P:=Q; Continue; end;
    Command:=ReadTeXCommand(Source,P);
    if Command='DeclareFontShape' then Declaration(Source,P)
    else begin
      Macro:=Registry.Find(Command);
      if (Macro=nil) or (Macro.ArgCount>6) or (Pos('\DeclareFontShape',Macro.Body)=0) then Continue;
      for J:=1 to Macro.ArgCount do Arguments[J]:=ReadTeXArgument(Source,P);
      if not SubstituteTeXParameters(Macro.Body,Slice(Arguments,Macro.ArgCount),Expanded) then Continue;
      Q:=Pos('\DeclareFontShape',Expanded)+Length('\DeclareFontShape'); Declaration(Expanded,Q);
    end;
  end;
  finally Registry.Free; end;
  Result:=Entry.Definitions.Values[Series+'/'+Shape];
  if (Length(Source)>65536) then Entry.Free
  else begin if DefinitionsCache.Count>=16 then DefinitionsCache.Delete(0); DefinitionsCache.Add(Entry); end;
end;
function MergeFontShape(const Encoding,Family,Series,Current,Requested:string; const Directory:string):string;
var Source,Command,FromShape,ToShape,Primary,Alternate,Rule:string; P,Split:Integer;
begin
  Source:=ReadTeXSource(ResolveTeXSource('latex.ltx',Directory));
  if (ShapeRuleSource<>Source) or (ShapeRules.Count=0) then begin
    ShapeRuleSource:=Source; ShapeRules.Clear; P:=1;
    if Source='' then begin Rule:=BundledTeXFile('shape-rules.tsv'); if Rule<>'' then ShapeRules.LoadFromFile(Rule); end;
    while P<=Length(Source) do begin
      if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
      if Source[P]<>'\' then begin Inc(P); Continue; end;
      Command:=ReadTeXCommand(Source,P); if Command<>'DeclareFontShapeChangeRule' then Continue;
      FromShape:=ReadTeXGroup(Source,P,'{','}'); ToShape:=ReadTeXGroup(Source,P,'{','}');
      Primary:=ReadTeXGroup(Source,P,'{','}'); Alternate:=ReadTeXGroup(Source,P,'{','}');
      if (FromShape<>'') and (ToShape<>'') then ShapeRules.Values[FromShape+'/'+ToShape]:=Primary+'|'+Alternate;
    end;
  end;
  Result:=Requested; Rule:=ShapeRules.Values[Current+'/'+Requested]; Split:=Pos('|',Rule);
  if Split=0 then Exit;
  Primary:=Copy(Rule,1,Split-1); Alternate:=Copy(Rule,Split+1,MaxInt);
  { selectfont first tries the combined shape; merge@font@shape then tries
    the rule's alternate, and finally the requested shape. }
  if FontDefinition(Encoding,Family,Series,Primary,Directory)<>'' then Result:=Primary
  else if (Alternate<>'') and (FontDefinition(Encoding,Family,Series,Alternate,Directory)<>'') then Result:=Alternate;
end;
function SizeDefinition(const Definition:string; Points:Double; out DesignSize:Double):string;
var Clean,Name,Range:string; P,A,I,Dash:Integer; Ranges:TStringList;
    Low,High,Distance,Best:Double; Format:TFormatSettings;
begin
  Result:=''; DesignSize:=Points; Clean:=''; P:=1;
  while P<=Length(Definition) do begin
    if Definition[P]='%' then while (P<=Length(Definition)) and (Definition[P]<>#10) do Inc(P)
    else begin Clean:=Clean+Definition[P]; Inc(P); end;
  end;
  Format:=DefaultFormatSettings; Format.DecimalSeparator:='.'; P:=1; Best:=1e9;
  Ranges:=TStringList.Create;
  try
    while P<=Length(Clean) do begin
      if Clean[P]<>'<' then begin Inc(P); Continue; end;
      Ranges.Clear;
      repeat
        Inc(P); A:=P; while (P<=Length(Clean)) and (Clean[P]<>'>') do Inc(P);
        Ranges.Add(Trim(Copy(Clean,A,P-A))); Inc(P); SkipTeXSpace(Clean,P);
      until Copy(Clean,P,1)<>'<';
      A:=P; while (P<=Length(Clean)) and (Clean[P]<>'<') do Inc(P);
      Name:=Trim(Copy(Clean,A,P-A)); if Name='' then Continue;
      for I:=0 to Ranges.Count-1 do begin
        Range:=Ranges[I]; Dash:=Pos('-',Range);
        if Dash>0 then begin
          Low:=StrToFloatDef(Copy(Range,1,Dash-1),0,Format);
          High:=StrToFloatDef(Copy(Range,Dash+1,MaxInt),1e9,Format);
          if (Points>=Low) and (Points<High) then begin DesignSize:=Points; Exit(Name); end;
        end else begin
          Low:=StrToFloatDef(Range,-1,Format); if Low<0 then Continue;
          Distance:=Abs(Points-Low);
          if Distance<0.001 then begin DesignSize:=Low; Exit(Name); end;
          if Distance<Best then begin Best:=Distance; Result:=Name; DesignSize:=Low; end;
        end;
      end;
    end;
  finally Ranges.Free; end;
end;
function ShapeFile(const Encoding,Family,Series,Shape:string; Points:Double; const Directory:string; Depth:Integer):string;
var FontFamily,FontSeries,FontShape,Definition,Name,Substitution:string;
    A,Slash:Integer; Format:TFormatSettings; DesignSize:Double;
begin
  Result:=''; if Depth>8 then Exit;
  FontFamily:=Family; FontSeries:=Series; FontShape:=Shape;
  Definition:=FontDefinition(Encoding,FontFamily,FontSeries,FontShape,Directory);
  { latex.ltx's wrong@fontshape replaces shape, then series, then family. }
  if Definition='' then begin
    FontShape:='n'; Definition:=FontDefinition(Encoding,FontFamily,FontSeries,FontShape,Directory);
    if Definition='' then begin
      FontSeries:='m'; Definition:=FontDefinition(Encoding,FontFamily,FontSeries,FontShape,Directory);
      if Definition='' then begin
        FontFamily:='cmr'; if Encoding='TU' then FontFamily:='lmr';
        Definition:=FontDefinition(Encoding,FontFamily,FontSeries,FontShape,Directory);
      end;
    end;
  end;
  if Definition='' then Exit;
  Name:=SizeDefinition(Definition,Points,DesignSize);
  if Encoding='TU' then begin
    A:=Pos('\UnicodeFontFile',Name);
    if A>0 then begin
      Inc(A,Length('\UnicodeFontFile')); Name:=ReadTeXGroup(Name,A,'{','}');
      if ExtractFileExt(Name)='' then Name:=Name+'.otf'; Result:=FindTeXFile(Name); Exit;
    end;
  end;
  A:=Pos('sub',Name);
  if A>0 then begin
    Inc(A,3); while (A<=Length(Name)) and (Name[A] in [' ',#9,#10,#13,'*']) do Inc(A);
    Substitution:=Trim(Copy(Name,A,MaxInt)); Slash:=Pos('/',Substitution);
    if Slash>0 then begin
      FontFamily:=Copy(Substitution,1,Slash-1); Delete(Substitution,1,Slash); Slash:=Pos('/',Substitution);
      if Slash>0 then Exit(ShapeFile(Encoding,FontFamily,Copy(Substitution,1,Slash-1),Trim(Copy(Substitution,Slash+1,MaxInt)),Points,Directory,Depth+1));
    end;
    Exit;
  end;
  if Encoding='TU' then Exit;
  { Standard TFM declarations contain a name, or gen*/sgen* plus a size. }
  if Pos('genb*',Name)=1 then begin
    Delete(Name,1,5); Name:=Name+SysUtils.Format('%.4d',[Round(DesignSize*100)]);
  end else if (Pos('gen*',Name)=1) or (Pos('sgen*',Name)=1) then begin
    Delete(Name,1,Pos('*',Name)); Format:=DefaultFormatSettings; Format.DecimalSeparator:='.';
    Name:=Name+FloatToStr(DesignSize,Format);
  end else if (Pos('s*',Name)=1) then begin
    Delete(Name,1,2);
    if Copy(Name,1,1)='[' then begin A:=1; ReadTeXGroup(Name,A,'[',']'); Delete(Name,1,A-1); end;
  end;
  Name:=Trim(Name);
  if (Name<>'') and (Pos('\',Name)=0) and (Pos('*',Name)=0) and (FindTeXFile(Name+'.tfm')<>'') then Result:=Name;
end;
function UnicodeFontShape(const Family,Series,Shape:string; Points:Double; const Directory:string):string;
begin Result:=ShapeFile('TU',Family,Series,Shape,Points,Directory,0); end;
function MetricFontShape(const Family,Series,Shape:string; Points:Double; const Directory,Encoding:string):string;
begin Result:=ShapeFile(Encoding,Family,Series,Shape,Points,Directory,0); end;
function OT1Unicode(Code:Integer):Integer;
const LowSlots:array[0..31] of Integer=($393,$394,$398,$39B,$39E,$3A0,$3A3,$3A5,
  $3A6,$3A8,$3A9,$FB00,$FB01,$FB02,$FB03,$FB04,$131,$237,$60,$B4,$2C7,$2D8,
  $AF,$2DA,$B8,$DF,$E6,$153,$F8,$C6,$152,$D8);
begin
  if (Code>=0) and (Code<=31) then Exit(LowSlots[Code]);
  case Code of
    34:Result:=$201D; 39:Result:=$2019; 60:Result:=$A1; 62:Result:=$BF;
    92:Result:=$201C; 95:Result:=$2D9; 96:Result:=$2018;
    123:Result:=$2013; 124:Result:=$2014; 125:Result:=$2DD; 127:Result:=$A8;
    else Result:=Code;
  end;
end;
initialization
  DefinitionsCache:=TObjectList.Create(True);
  ShapeRules:=TStringList.Create; ShapeRules.CaseSensitive:=True;
  ShapeRules.NameValueSeparator:=#9;
finalization
  BundledShapes.Free;
  ShapeRules.Free;
  DefinitionsCache.Free;
end.
