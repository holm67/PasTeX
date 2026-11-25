unit TeXFontData;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils;
type
  TTeXCharMetric=record
    Width,Height,Depth,Italic:Double;
    Tag,Remainder:Byte;
    Valid:Boolean;
  end;
  TTeXRecipe=record Top,Middle,Bottom,RepeatChar:Byte; end;
  TTeXTextGlyph=record Code,First,Count:Integer; X,Y,Advance,Kern:Double; end;
  TTeXTextRun=record Glyphs:array of TTeXTextGlyph; Stops:array of Double; Width,Height,Depth:Double; Valid:Boolean; end;
  TTeXFontMetric=class
  private
    LigKern:array of record Skip,Next,Operation,Value:Byte; end;
    Kerns:array of Double;
    function Pair(Left,Right:Integer; out Ligature:Integer; out Kern:Double):Boolean;
  public
    Chars:array[0..255] of TTeXCharMetric;
    Recipes:array of TTeXRecipe;
    Parameters:array of Double;
    Valid:Boolean;
    constructor Create(const FileName:string);
    function ShapeText(const Text:string):TTeXTextRun;
  end;
function FindTeXFile(const Name:string):string;
function TeXFontMetric(const Name:string):TTeXFontMetric;
function TeXSymbol(const Name:string; out Family:string; out Code:Integer):Boolean;
function TeXSymbolClass(const Name:string):string;
function TeXDelimiter(const Name:string; out SmallFamily,LargeFamily:string; out SmallCode,LargeCode:Integer):Boolean;
function TeXLargeOperator(const Name:string):Boolean;
procedure TeXArrowNames(Dest:TStrings);
procedure TeXCoreSymbolNames(Dest:TStrings);
function TeXTextAccent(const Command:string; const Encoding:string='OT1'):Integer;
function TeXOpticalFont(const Family:string; Points:Integer):string;
implementation
uses Process, RegExpr, Math, TeXFileSearch, MathCommands, BundledTeX;
var Paths,Fonts,Symbols,SymbolClasses,Delimiters,TextAccents:TStringList;
    SymbolIndex,ClassIndex,DelimiterIndex:TStringList;
    SymbolsLoaded:Boolean;
    CoreSymbolCount:Integer;
function FindTeXFile(const Name:string):string;
var I:Integer; Path,Root:string; Roots:TStringList;
begin
  I:=Paths.IndexOfName(Name); if I>=0 then Exit(Paths.ValueFromIndex[I]);
  Result:=''; Roots:=TStringList.Create;
  try
    Roots.StrictDelimiter:=True; Roots.Delimiter:=PathSeparator;
    Roots.DelimitedText:=GetEnvironmentVariable('PASTEX_FONT_PATH');
    Roots.Add(ExtractFilePath(ParamStr(0))+'fonts');
    for Root in Roots do begin
      Path:=IncludeTrailingPathDelimiter(Root)+Name;
      if FileExists(Path) then begin Result:=ExpandFileName(Path); Break; end;
    end;
    if Result='' then Result:=BundledTeXFile(Name);
    if Result='' then try
      Result:=SearchTeXFile(Name);
    except end;
    {$IFDEF MSWINDOWS}
    if Result='' then try
      if RunCommand('findtexmf',[Name],Path,[poNoConsole]) and FileExists(Trim(Path)) then Result:=Trim(Path);
    except end;
    {$ENDIF}
  finally Roots.Free; end;
  Paths.Add(Name+'='+Result);
end;
constructor TTeXFontMetric.Create(const FileName:string);
var Data:TMemoryStream; Bytes:PByte; Sizes:array[0..11] of Integer;
    CharOffset,WidthOffset,HeightOffset,DepthOffset,ItalicOffset,LigOffset,KernOffset,RecipeOffset,ParamOffset,I,C,Count:Integer;
  function WordAt(P:Integer):Integer;
  begin Result:=(Integer(Bytes[P]) shl 8)+Bytes[P+1]; end;
  function FixedAt(P:Integer):Double;
  var V:LongWord;
  begin
    V:=(LongWord(Bytes[P]) shl 24) or (LongWord(Bytes[P+1]) shl 16) or
       (LongWord(Bytes[P+2]) shl 8) or Bytes[P+3];
    Result:=LongInt(V)/1048576.0;
  end;
begin
  inherited Create; Data:=TMemoryStream.Create;
  try
    try
      if FileName='' then Exit;
      Data.LoadFromFile(FileName); if Data.Size<24 then Exit; Bytes:=Data.Memory;
      for I:=0 to 11 do Sizes[I]:=WordAt(I*2);
      Count:=Sizes[3]-Sizes[2]+1;
      if (Count<0) or (Sizes[2]>256) or (Sizes[3]>255) or
         (Sizes[0]*4>Data.Size) or (Sizes[4]=0) or (Sizes[5]=0) or (Sizes[6]=0) or (Sizes[7]=0) then Exit;
      { TeX reads the declared TFM words; some EC files have trailing
        padding, which is not part of those tables. }
      C:=6+Sizes[1]+Count; for I:=4 to 11 do Inc(C,Sizes[I]); if C<>Sizes[0] then Exit;
      CharOffset:=24+Sizes[1]*4; WidthOffset:=CharOffset+Count*4;
      HeightOffset:=WidthOffset+Sizes[4]*4; DepthOffset:=HeightOffset+Sizes[5]*4;
      ItalicOffset:=DepthOffset+Sizes[6]*4;
      LigOffset:=ItalicOffset+Sizes[7]*4; KernOffset:=LigOffset+Sizes[8]*4;
      RecipeOffset:=ItalicOffset+(Sizes[7]+Sizes[8]+Sizes[9])*4;
      ParamOffset:=RecipeOffset+Sizes[10]*4;
      for I:=Sizes[2] to Sizes[3] do begin
        C:=CharOffset+(I-Sizes[2])*4;
        if (Bytes[C]>=Sizes[4]) or (Bytes[C+1] shr 4>=Sizes[5]) or
           (Bytes[C+1] and 15>=Sizes[6]) or (Bytes[C+2] shr 2>=Sizes[7]) then Exit;
        Chars[I].Valid:=Bytes[C]<>0;
        Chars[I].Width:=FixedAt(WidthOffset+Bytes[C]*4);
        Chars[I].Height:=FixedAt(HeightOffset+(Bytes[C+1] shr 4)*4);
        Chars[I].Depth:=FixedAt(DepthOffset+(Bytes[C+1] and 15)*4);
        Chars[I].Italic:=FixedAt(ItalicOffset+(Bytes[C+2] shr 2)*4);
        Chars[I].Tag:=Bytes[C+2] and 3; Chars[I].Remainder:=Bytes[C+3];
      end;
      SetLength(Recipes,Sizes[10]);
      for I:=0 to High(Recipes) do begin
        C:=RecipeOffset+I*4;
        Recipes[I].Top:=Bytes[C]; Recipes[I].Middle:=Bytes[C+1];
        Recipes[I].Bottom:=Bytes[C+2]; Recipes[I].RepeatChar:=Bytes[C+3];
      end;
      SetLength(LigKern,Sizes[8]); SetLength(Kerns,Sizes[9]);
      for I:=0 to High(LigKern) do begin
        C:=LigOffset+I*4; LigKern[I].Skip:=Bytes[C]; LigKern[I].Next:=Bytes[C+1];
        LigKern[I].Operation:=Bytes[C+2]; LigKern[I].Value:=Bytes[C+3];
      end;
      for I:=0 to High(Kerns) do Kerns[I]:=FixedAt(KernOffset+I*4);
      SetLength(Parameters,Sizes[11]);
      for I:=0 to High(Parameters) do Parameters[I]:=FixedAt(ParamOffset+I*4);
      Valid:=True;
    except { An optional or damaged font must leave source editing usable. } end;
  finally Data.Free; end;
end;
function TTeXFontMetric.Pair(Left,Right:Integer; out Ligature:Integer; out Kern:Double):Boolean;
var P,N,K:Integer;
begin
  Result:=False; Ligature:=-1; Kern:=0;
  if not Valid or (Left<0) or (Left>255) or (Chars[Left].Tag<>1) then Exit;
  P:=Chars[Left].Remainder;
  if (P<Length(LigKern)) and (LigKern[P].Skip>128) then P:=256*LigKern[P].Operation+LigKern[P].Value;
  for N:=0 to Length(LigKern) do begin
    if (P<0) or (P>=Length(LigKern)) then Exit;
    if LigKern[P].Next=Right then begin
      if LigKern[P].Operation>=128 then begin
        K:=256*(LigKern[P].Operation-128)+LigKern[P].Value;
        if K<Length(Kerns) then Kern:=Kerns[K];
      end else if LigKern[P].Operation=0 then Ligature:=LigKern[P].Value;
      Exit(True);
    end;
    if LigKern[P].Skip>=128 then Exit; Inc(P,LigKern[P].Skip+1);
  end;
end;
function TTeXFontMetric.ShapeText(const Text:string):TTeXTextRun;
var I,J,N,Lig:Integer; Kern,X:Double; G:TTeXTextGlyph;
begin
  Result:=Default(TTeXTextRun); if not Valid then Exit;
  for I:=1 to Length(Text) do if (Ord(Text[I])>127) or ((Text[I]<>' ') and not Chars[Ord(Text[I])].Valid) then Exit;
  SetLength(Result.Glyphs,Length(Text)); SetLength(Result.Stops,Length(Text)+1);
  N:=0;
  for I:=1 to Length(Text) do begin
    { Keep the current left glyph at the end of the compacted output. A
      ligature can combine with the next input character again (ff -> ffi),
      without moving the remaining source glyphs after every combination. }
    if (N>0) and (Text[I]<>' ') and (Result.Glyphs[N-1].Code<>32) and
       Pair(Result.Glyphs[N-1].Code,Ord(Text[I]),Lig,Kern) then begin
      if Lig>=0 then begin
        Result.Glyphs[N-1].Code:=Lig; Inc(Result.Glyphs[N-1].Count); Continue;
      end;
      Result.Glyphs[N-1].Kern:=Kern;
    end;
    Result.Glyphs[N].Code:=Ord(Text[I]); Result.Glyphs[N].First:=I-1;
    Result.Glyphs[N].Count:=1; Inc(N);
  end;
  SetLength(Result.Glyphs,N); X:=0;
  for I:=0 to N-1 do begin
    G:=Result.Glyphs[I]; G.X:=X; G.Advance:=Chars[G.Code].Width;
    { Text spaces are glue; slot 32 can contain an unrelated OT1 glyph. }
    if G.Code=32 then begin
      if Length(Parameters)>1 then G.Advance:=Parameters[1];
    end else begin
      Result.Height:=Max(Result.Height,Chars[G.Code].Height); Result.Depth:=Max(Result.Depth,Chars[G.Code].Depth);
    end;
    for J:=1 to G.Count do Result.Stops[G.First+J]:=X+G.Advance*J/G.Count;
    X:=X+G.Advance+G.Kern; Result.Stops[G.First+G.Count]:=X; Result.Glyphs[I]:=G;
  end;
  Result.Width:=X; Result.Valid:=True;
end;
function TeXFontMetric(const Name:string):TTeXFontMetric;
var I:Integer;
begin
  I:=Fonts.IndexOf(Name);
  if I<0 then I:=Fonts.AddObject(Name,TTeXFontMetric.Create(FindTeXFile(Name+'.tfm')));
  Result:=TTeXFontMetric(Fonts.Objects[I]);
end;
function TeXOpticalFont(const Family:string; Points:Integer):string;
var Size:Integer;
begin
  Size:=Points;
  if Family='cmex' then Size:=10
  else if Family='rsfs' then begin if Size<7 then Size:=5 else if Size<10 then Size:=7 else Size:=10; end
  else if (Family='msam') or (Family='msbm') or (Family='eufm') then begin if Size<7 then Size:=5 else if Size<10 then Size:=7 else Size:=10; end
  else begin
    if Size<5 then Size:=5; if Size=11 then Size:=10;
    if Size>12 then Size:=12;
    if (Family='cmsy') and (Size>10) then Size:=10;
    if (Family='cmbsy') or (Family='cmmib') then Size:=10;
  end;
  Result:=Family+IntToStr(Size);
end;
function FontFamily(const Group:string):string;
begin
  Result:='';
  case Group of
    'operators':Result:='cmr'; 'letters':Result:='cmmi';
    'symbols':Result:='cmsy'; 'largesymbols':Result:='cmex';
    'AMSa':Result:='msam'; 'AMSb':Result:='msbm';
  end;
end;
procedure LoadSymbols(const FileName:string);
var FileText,Fields:TStringList; R:TRegExpr; Text,Name,Family,Slot,Raw,Path,Line:string; Code,P,A:Integer;
  function SlotNumber(const Value:string):Integer;
  begin
    Result:=StrToIntDef(Value,-1);
    if Copy(Value,1,1)='"' then Result:=StrToIntDef('$'+Copy(Value,2,MaxInt),-1)
    else if (Length(Value)=2) and (Value[1]='`') then Result:=Ord(Value[2]);
  end;
begin
  Path:=BundledTeXFile(FileName+'.symbols');
  if Path<>'' then begin
    FileText:=TStringList.Create; Fields:=TStringList.Create;
    try
      FileText.LoadFromFile(Path); Fields.StrictDelimiter:=True; Fields.Delimiter:=#9;
      for Line in FileText do begin
        Fields.DelimitedText:=Line; if Fields.Count<3 then Continue; Name:=Fields[1];
        case Fields[0] of
          'S':if Fields.Count=5 then begin Symbols.Values[Name]:=Fields[2]+':'+Fields[3]; SymbolClasses.Values[Name]:=Fields[4]; end;
          'D':if Fields.Count=6 then Delimiters.Values[Name]:=Fields[2]+':'+Fields[3]+':'+Fields[4]+':'+Fields[5];
          'L':if Symbols.IndexOfName(Fields[2])>=0 then begin
            Symbols.Values[Name]:=Symbols.Values[Fields[2]]; SymbolClasses.Values[Name]:=SymbolClasses.Values[Fields[2]];
            Delimiters.Values[Name]:=Delimiters.Values[Fields[2]];
          end;
        end;
      end;
    finally Fields.Free; FileText.Free; end;
    Exit;
  end;
  if FindTeXFile(FileName)='' then Exit;
  FileText:=TStringList.Create; R:=TRegExpr.Create;
  try
    FileText.LoadFromFile(FindTeXFile(FileName)); Raw:=FileText.Text; Text:=''; P:=1; A:=1;
    while P<=Length(Raw) do begin
      if (Raw[P]='%') and ((P=1) or (Raw[P-1]<>'\')) then begin
        Text:=Text+Copy(Raw,A,P-A); while (P<=Length(Raw)) and (Raw[P]<>#10) do Inc(P); A:=P;
      end else Inc(P);
    end;
    Text:=Text+Copy(Raw,A,MaxInt);
    { Read the installed LaTeX/AMS font declarations, not a finite icon list.
      Only declarations are read; no document commands are executed. }
    R.Expression:='\\DeclareMath(?:Symbol|Delimiter)\s*(?:\{([^{}]+)\}|(\\[a-zA-Z]+|\\.))\s*\{([^{}]+)\}\s*\{([^{}]+)\}\s*\{([^{}]+)\}';
    if R.Exec(Text) then repeat
      Name:=R.Match[1]; if Name='' then Name:=R.Match[2];
      Family:=FontFamily(R.Match[4]); Slot:=R.Match[5]; Code:=StrToIntDef(Slot,-1);
      if Copy(Slot,1,1)='"' then Code:=StrToIntDef('$'+Copy(Slot,2,MaxInt),-1)
      else if (Length(Slot)=2) and (Slot[1]='`') then Code:=Ord(Slot[2]);
      if (Family<>'') and (Code>=0) and (Code<=255) then begin
        Symbols.Values[Name]:=Family+':'+IntToStr(Code);
        SymbolClasses.Values[Name]:=R.Match[3];
      end;
    until not R.ExecNext;
    R.Expression:='\\DeclareMathDelimiter\s*\{([^{}]+)\}\s*\{[^{}]+\}\s*\{([^{}]+)\}\s*\{([^{}]+)\}\s*\{([^{}]+)\}\s*\{([^{}]+)\}';
    if R.Exec(Text) then repeat
      Delimiters.Values[R.Match[1]]:=FontFamily(R.Match[2])+':'+IntToStr(SlotNumber(R.Match[3]))+':'+
        FontFamily(R.Match[4])+':'+IntToStr(SlotNumber(R.Match[5]));
    until not R.ExecNext;
    R.Expression:='\\(?:let\s*|DeclareRobustCommand\s*\{)(\\[a-zA-Z]+)\}?\s*=?\s*(\\[a-zA-Z]+)';
    if R.Exec(Text) then repeat
      P:=Symbols.IndexOfName(R.Match[2]); if P>=0 then begin
        Symbols.Values[R.Match[1]]:=Symbols.ValueFromIndex[P]; SymbolClasses.Values[R.Match[1]]:=SymbolClasses.Values[R.Match[2]];
        Delimiters.Values[R.Match[1]]:=Delimiters.Values[R.Match[2]];
      end;
    until not R.ExecNext;
  finally R.Free; FileText.Free; end;
end;
function TeXSymbol(const Name:string; out Family:string; out Code:Integer):Boolean;
var S:string; P:Integer;
  procedure IndexNames(Values,Index:TStringList);
  var I:Integer;
  begin
    Index.Sorted:=True; Index.CaseSensitive:=True;
    for I:=0 to Values.Count-1 do Index.AddObject(Values.Names[I],TObject(PtrInt(I)));
  end;
begin
  if not SymbolsLoaded then begin
    SymbolsLoaded:=True;
    LoadSymbols('fontmath.ltx'); CoreSymbolCount:=Symbols.Count;
    LoadSymbols('amssymb.sty'); LoadSymbols('amsmath.sty');
    Symbols.Values['\int']:=Symbols.Values['\intop'];
    Symbols.Values['\oint']:=Symbols.Values['\ointop'];
    SymbolClasses.Values['\int']:='\mathop'; SymbolClasses.Values['\oint']:='\mathop';
    Symbols.Values['\colon']:='cmr:58';
    Symbols.Values['(']:='cmr:40'; Symbols.Values[')']:='cmr:41';
    Symbols.Values['[']:='cmr:91'; Symbols.Values[']']:='cmr:93';
    IndexNames(Symbols,SymbolIndex); IndexNames(SymbolClasses,ClassIndex); IndexNames(Delimiters,DelimiterIndex);
  end;
  P:=SymbolIndex.IndexOf(Name); S:=''; if P>=0 then S:=Symbols.ValueFromIndex[PtrInt(SymbolIndex.Objects[P])];
  P:=Pos(':',S); Result:=P>0;
  Family:=Copy(S,1,P-1); Code:=StrToIntDef(Copy(S,P+1,MaxInt),-1);
end;
procedure TeXCoreSymbolNames(Dest:TStrings);
var Family:string; Code,I:Integer;
begin
  if not SymbolsLoaded then TeXSymbol('',Family,Code);
  for I:=0 to CoreSymbolCount-1 do
    if Copy(Symbols.Names[I],1,1)='\' then Dest.Add(Symbols.Names[I]);
end;
function TeXSymbolClass(const Name:string):string;
var Family:string; Code,I:Integer;
begin
  if not SymbolsLoaded then TeXSymbol(Name,Family,Code);
  I:=ClassIndex.IndexOf(Name); Result:='';
  if I>=0 then Result:=SymbolClasses.ValueFromIndex[PtrInt(ClassIndex.Objects[I])];
end;
function TeXDelimiter(const Name:string; out SmallFamily,LargeFamily:string; out SmallCode,LargeCode:Integer):Boolean;
var S,Family:string; Code,P:Integer;
begin
  if not SymbolsLoaded then TeXSymbol(Name,Family,Code);
  P:=DelimiterIndex.IndexOf(Name); S:=''; if P>=0 then S:=Delimiters.ValueFromIndex[PtrInt(DelimiterIndex.Objects[P])];
  P:=Pos(':',S);
  SmallFamily:=Copy(S,1,P-1); Delete(S,1,P); P:=Pos(':',S);
  SmallCode:=StrToIntDef(Copy(S,1,P-1),-1); Delete(S,1,P); P:=Pos(':',S);
  LargeFamily:=Copy(S,1,P-1); LargeCode:=StrToIntDef(Copy(S,P+1,MaxInt),-1);
  Result:=(SmallFamily<>'') and (LargeFamily<>'') and (SmallCode>=0) and (LargeCode>=0);
end;
function TeXLargeOperator(const Name:string):Boolean;
var Family:string; Code:Integer;
begin Result:=TeXSymbol(Name,Family,Code) and (Family='cmex') and (TeXSymbolClass(Name)='\mathop'); end;
procedure TeXArrowNames(Dest:TStrings);
const Extra:array[0..22] of string=('\to','\gets','\mapsto','\longmapsto','\longrightarrow','\longleftarrow','\longleftrightarrow',
    '\Longrightarrow','\Longleftarrow','\Longleftrightarrow','\hookrightarrow','\hookleftarrow','\iff',
    '\implies','\impliedby','\xrightarrow','\xleftarrow','\overrightarrow','\overleftarrow','\overleftrightarrow',
    '\underrightarrow','\underleftarrow','\underleftrightarrow');
var Family,Name:string; Code,I:Integer;
begin
  TeXSymbol('\rightarrow',Family,Code); Dest.Clear;
  if Dest is TStringList then TStringList(Dest).CaseSensitive:=True;
  for I:=0 to Symbols.Count-1 do begin
    Name:=Symbols.Names[I];
    if (Pos('arrow',LowerCase(Name))>0) or (Pos('harpoon',LowerCase(Name))>0) then Dest.Add(Name);
  end;
  for Name in Extra do if Dest.IndexOf(Name)<0 then Dest.Add(Name);
  for Name in ExtensibleArrows.Split([' ']) do
    if (Name<>'') and (Dest.IndexOf('\'+Name)<0) then Dest.Add('\'+Name);
end;
function TeXTextAccent(const Command:string; const Encoding:string):Integer;
const Encodings:array[0..1] of string=('ot1enc.def','t1enc.def');
var Source:TStringList; R:TRegExpr; FileName,Path:string;
begin
  if TextAccents=nil then begin
    TextAccents:=TStringList.Create; TextAccents.CaseSensitive:=True; TextAccents.NameValueSeparator:=#1;
    TextAccents.Values['OT1/\`']:='18'; TextAccents.Values['OT1/\''']:='19';
    TextAccents.Values['OT1/\v']:='20'; TextAccents.Values['OT1/\u']:='21';
    TextAccents.Values['OT1/\=']:='22'; TextAccents.Values['OT1/\r']:='23';
    TextAccents.Values['OT1/\^']:='94'; TextAccents.Values['OT1/\~']:='126';
    TextAccents.Values['OT1/\"']:='127'; TextAccents.Values['OT1/\.']:='95';
    Source:=TStringList.Create; R:=TRegExpr.Create;
    try
      R.Expression:='\\DeclareTextAccent\s*\{([^{}]+)\}\s*\{([^{}]+)\}\s*\{([0-9]+)\}';
      for FileName in Encodings do begin
        Path:=FindTeXFile(FileName); if Path='' then Continue;
        Source.LoadFromFile(Path);
        if R.Exec(Source.Text) then repeat TextAccents.Values[R.Match[2]+'/'+R.Match[1]]:=R.Match[3]; until not R.ExecNext;
      end;
      TextAccents.Values['OT1/\c']:='24'; TextAccents.Values['OT1/\d']:='46'; TextAccents.Values['OT1/\b']:='95';
      TextAccents.Values['T1/\c']:='11'; TextAccents.Values['T1/\d']:='12'; TextAccents.Values['T1/\b']:='9';
    finally R.Free; Source.Free; end;
  end;
  Result:=StrToIntDef(TextAccents.Values[Encoding+'/\'+Command],-1);
  if Result<0 then Result:=StrToIntDef(TextAccents.Values['OT1/\'+Command],-1);
end;
var I:Integer;
initialization
  Paths:=TStringList.Create; Fonts:=TStringList.Create; Symbols:=TStringList.Create;
  SymbolClasses:=TStringList.Create; Delimiters:=TStringList.Create; Delimiters.CaseSensitive:=True;
  Symbols.CaseSensitive:=True; SymbolClasses.CaseSensitive:=True;
  Symbols.NameValueSeparator:=#1; SymbolClasses.NameValueSeparator:=#1;
  Delimiters.NameValueSeparator:=#1;
  SymbolIndex:=TStringList.Create; ClassIndex:=TStringList.Create; DelimiterIndex:=TStringList.Create;
  Paths.Sorted:=True; Paths.NameValueSeparator:='=';
finalization
  for I:=0 to Fonts.Count-1 do Fonts.Objects[I].Free;
  Fonts.Free; Paths.Free; Symbols.Free; SymbolClasses.Free; Delimiters.Free; TextAccents.Free;
  SymbolIndex.Free; ClassIndex.Free; DelimiterIndex.Free;
end.
