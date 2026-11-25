unit TeXFonts;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Graphics, TeXFontConfig;
var BlackboardFont,ScriptFont,FrakturFont:string;
function ResolveTeXFont(const PostScript:string):string;
function ContainsCJK(const Text:string):Boolean;
function DefaultCJKFont(const Preamble:string; Style:TFontStyles=[]; const Family:string='rm'):string;
function CJKTextFont(const Preamble,Family,Series,Shape:string):string;
function DocumentTextFace(const Preamble,Family,Series,Shape,Directory:string; CJK:Boolean; const Engine:string='pdflatex'):TFontFace;
function OpenTypeFontFile(const Family:string; Style:TFontStyles=[]):string;
function MathInkMetrics(const Text,Style:string; out Height,Depth:Double):Boolean;
function MathAccentSkew(const Text,Style:string):Double;
implementation
uses Classes, SysUtils, Dynlibs, Math, Forms, LazUTF8, LazFileUtils, TeXMacros, TeXFontData, OpenTypeFonts, TeXUnicode, TeXPackageSources
  {$IFDEF MSWINDOWS}, Windows{$ENDIF}
  {$IFDEF LCLqt5}, Qt5{$ENDIF}{$IFDEF LCLqt6}, Qt6{$ENDIF};
type TFcAdd=function(Config:Pointer; FileName:PChar):LongBool; cdecl;
     TFcNameParse=function(Name:PChar):Pointer; cdecl;
     TFcMatch=function(Config,Pattern:Pointer; out MatchResult:Integer):Pointer; cdecl;
     TFcString=function(Pattern:Pointer; Name:PChar; Index:Integer; out Value:PChar):Integer; cdecl;
     TFcDestroy=procedure(Pattern:Pointer); cdecl;
type TTFMChar=record Height,Depth,Skew:Double; Valid:Boolean; end;
{$IFDEF MSWINDOWS}
function AddPrivateFont(FileName:PWideChar; Flags:DWORD; Reserved:Pointer):Integer; stdcall;
  external 'gdi32.dll' name 'AddFontResourceExW';
{$ENDIF}
var RomanMetrics,ItalicMetrics,SymbolMetrics:array[0..255] of TTFMChar;
    CommonFonts,OpenTypeFiles,RegisteredFonts:TStringList;
  FontContext,FontDirectory,FontEngine:string;
    ConfiguredFonts:TDocumentFonts;
    FaceCache:array of record Key:string; Face:TFontFace; end;
    LibraryHandle:TLibHandle=NilHandle; AddFont:TFcAdd;
    ParseName:TFcNameParse; MatchFont:TFcMatch; FontString:TFcString; DestroyPattern:TFcDestroy;
procedure RegisterFont(const FileName,Family:string; var Selected:string);
var Path:string;
    {$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}WidePath:WideString;{$ENDIF}
begin
  try
    if FileExists(FileName) then Path:=FileName else Path:=FindTeXFile(FileName);
    if Path='' then Exit;
    Path:=TryReadAllLinks(ExpandFileNameUTF8(Path));
    { Native registrations outlive lookup-cache entries. Register each file
      once, including requests through its filename, PostScript name or path. }
    if RegisteredFonts.IndexOf(Path)>=0 then begin Selected:=Family; Exit; end;
    {$IFDEF MSWINDOWS}
    if AddPrivateFont(PWideChar(UTF8Decode(Path)),$10,nil)>0 then begin
    {$ELSE}
    if Assigned(AddFont) and AddFont(nil,PChar(Path)) then begin
    {$ENDIF}
        Selected:=Family;
        {$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}
        { Notify Qt as well: its font database may already have been populated
          before this unit adds faces to Fontconfig. }
        WidePath:=UTF8Decode(Trim(Path)); QFontDatabase_addApplicationFont(@WidePath);
        {$ENDIF}
        RegisteredFonts.Add(Path);
      end;
  except Selected:=''; end;
end;
procedure CommonFont(const PostScript,Family:string);
var Selected,FileName,Face,NativeFamily:string;
begin
  Face:=PostScript; NativeFamily:=Family;
  { Modern Qt and Pango may exclude legacy Type 1 faces. Latin Modern supplies
    OpenType counterparts of the Computer Modern optical designs. }
  case PostScript of
    'CMR10':Face:='LMRoman10-Regular'; 'CMR12':Face:='LMRoman12-Regular';
    'CMBX10':Face:='LMRoman10-Bold'; 'CMBX12':Face:='LMRoman12-Bold';
    'CMTI10':Face:='LMRoman10-Italic'; 'CMTI12':Face:='LMRoman12-Italic';
    'CMSL10':Face:='LMRomanSlant10-Regular'; 'CMTT10':Face:='LMMono10-Regular';
    'CMSS10':Face:='LMSans10-Regular'; 'CMSS12':Face:='LMSans12-Regular';
  end;
  FileName:=LowerCase(Face)+'.otf';
  case PostScript of
    'CMR10','CMBX10','CMTI10':NativeFamily:='LM Roman 10';
    'CMR12','CMBX12','CMTI12':NativeFamily:='LM Roman 12';
    'CMSL10':NativeFamily:='LM Roman Slanted 10';
    'CMTT10':NativeFamily:='LM Mono 10';
    'CMSS10':NativeFamily:='LM Sans 10'; 'CMSS12':NativeFamily:='LM Sans 12';
  end;
  {$IF DEFINED(LCLgtk2) OR DEFINED(LCLgtk3)}
  { Pango parses a final number as a point size unless followed by a comma. }
  NativeFamily:=NativeFamily+',';
  {$ENDIF}
  Selected:=''; RegisterFont(FileName,NativeFamily,Selected);
  if Selected<>'' then CommonFonts.Values[PostScript]:=Selected;
end;
function ResolveTeXFont(const PostScript:string):string;
var Key,Path,Family,Selected,Query:string; I,MatchResult:Integer; Pattern,Match:Pointer; Value:PChar;
begin
  Query:=PostScript; I:=Pos('-Identity-',Query); if I>0 then Delete(Query,I,MaxInt);
  if FileExists(Query) then Query:=ExpandFileNameUTF8(Query);
  Key:=Query; if ExtractFileExt(Query)='' then Key:=UpperCase(Query);
  I:=CommonFonts.IndexOfName(Key);
  if I>=0 then Exit(CommonFonts.ValueFromIndex[I]);
  Result:=''; Pattern:=nil; Match:=nil;
  { A distribution font file is authoritative. A desktop font matcher can
    return a substitute when a requested PostScript name is unavailable. }
  Path:=''; if FileExists(Query) then Path:=Query else if ExtractFileExt(Query)<>'' then Path:=FindTeXFile(Query);
  if Path='' then Path:=FindTeXFile(Query+'.otf'); if Path='' then Path:=FindTeXFile(LowerCase(Query)+'.otf');
  if Path='' then Path:=FindTeXFile(Query+'.ttf');
  if Path<>'' then begin
    Family:=OpenTypeFamily(Path); Selected:='';
    if Family<>'' then begin RegisterFont(Path,Family,Selected); Result:=Family; end;
  end;
  if (Result='') and Assigned(ParseName) and Assigned(MatchFont) and Assigned(FontString) and Assigned(DestroyPattern) then begin
    Pattern:=ParseName(PChar(':postscriptname='+Query));
    try
      if Pattern<>nil then Match:=MatchFont(nil,Pattern,MatchResult);
      if (Match<>nil) and (FontString(Match,'file',0,Value)=0) then begin
        Path:=string(Value);
        if SameText(OpenTypePostScriptName(Path),Query) and (FontString(Match,'family',0,Value)=0) then Result:=string(Value);
      end;
    finally if Match<>nil then DestroyPattern(Match); if Pattern<>nil then DestroyPattern(Pattern); end;
  end;
  if (Result='') and Assigned(ParseName) and Assigned(MatchFont) and Assigned(FontString) and Assigned(DestroyPattern) then begin
    { Match the requested family without enumerating Qt's complete font
      database, which populates unrelated CJK face caches. }
    Pattern:=ParseName(PChar(Query)); Match:=nil;
    try
      if Pattern<>nil then Match:=MatchFont(nil,Pattern,MatchResult);
      if (Match<>nil) and (FontString(Match,'family',0,Value)=0) and
         SameText(StringReplace(string(Value),' ','',[rfReplaceAll]),StringReplace(Query,'-','',[rfReplaceAll])) then Result:=string(Value);
    finally if Match<>nil then DestroyPattern(Match); if Pattern<>nil then DestroyPattern(Pattern); end;
  end else if (Result='') and (Screen<>nil) then
    for I:=0 to Screen.Fonts.Count-1 do
      if SameText(StringReplace(Screen.Fonts[I],' ','',[rfReplaceAll]),StringReplace(Query,'-','',[rfReplaceAll])) then begin Result:=Screen.Fonts[I]; Break; end;
  {$IF DEFINED(LCLgtk2) OR DEFINED(LCLgtk3)}
  if (Result<>'') and (Result[Length(Result)] in ['0'..'9']) then Result:=Result+',';
  {$ENDIF}
  if CommonFonts.Count>=512 then CommonFonts.Delete(16);
  CommonFonts.Add(Key+'='+Result);
end;
function OpenTypeFontFile(const Family:string; Style:TFontStyles):string;
var Pattern,Match:Pointer; Key,Spec:string; Value:PChar; MatchResult,I:Integer;
begin
  Key:=Family+':'+IntToStr(Ord(fsBold in Style))+IntToStr(Ord(fsItalic in Style));
  I:=OpenTypeFiles.IndexOfName(Key); if I>=0 then Exit(OpenTypeFiles.ValueFromIndex[I]);
  Result:=''; if FileExists(Family) then Result:=Family else if ExtractFileExt(Family)<>'' then Result:=FindTeXFile(Family);
  if Result='' then Result:=FindTeXFile(Family+'.otf'); if Result='' then Result:=FindTeXFile(Family+'.ttf');
  if (Result='') and (Pos('FandolSong',Family)>0) then begin
    if fsBold in Style then Result:=FindTeXFile('FandolSong-Bold.otf') else Result:=FindTeXFile('FandolSong-Regular.otf');
  end else if (Result='') and (Pos('FandolKai',Family)>0) then Result:=FindTeXFile('FandolKai-Regular.otf')
  else if (Result='') and (Pos('FandolHei',Family)>0) then begin
    if fsBold in Style then Result:=FindTeXFile('FandolHei-Bold.otf') else Result:=FindTeXFile('FandolHei-Regular.otf');
  end else if (Result='') and (Pos('FandolFang',Family)>0) then Result:=FindTeXFile('FandolFang-Regular.otf');
  {$IFDEF MSWINDOWS}
  if Result='' then begin
    Spec:='';
    if SameText(Family,'SimSun') then Spec:='simsun.ttc'
    else if SameText(Family,'SimHei') then Spec:='simhei.ttf'
    else if SameText(Family,'KaiTi') then Spec:='simkai.ttf'
    else if SameText(Family,'FangSong') then Spec:='simfang.ttf'
    else if SameText(Family,'Microsoft YaHei') then begin
      Spec:='msyh.ttc'; if fsBold in Style then Spec:='msyhbd.ttc';
    end;
    if Spec<>'' then Spec:=IncludeTrailingPathDelimiter(SysUtils.GetEnvironmentVariable('WINDIR'))+'Fonts'+DirectorySeparator+Spec;
    if FileExists(Spec) then Result:=Spec;
    if (Result='') and (ExtractFileExt(Spec)='.ttc') and FileExists(ChangeFileExt(Spec,'.ttf')) then Result:=ChangeFileExt(Spec,'.ttf');
  end;
  {$ENDIF}
  if (Result='') and Assigned(ParseName) and Assigned(MatchFont) and Assigned(FontString) and Assigned(DestroyPattern) then begin
    Spec:=Family;
    if fsBold in Style then Spec:=Spec+':weight=bold';
    if fsItalic in Style then Spec:=Spec+':slant=italic';
    Pattern:=ParseName(PChar(Spec)); Match:=nil;
    try
      if Pattern<>nil then Match:=MatchFont(nil,Pattern,MatchResult);
      if (Match<>nil) and (FontString(Match,'file',0,Value)=0) then Result:=string(Value);
    finally if Match<>nil then DestroyPattern(Match); if Pattern<>nil then DestroyPattern(Pattern); end;
  end;
  if OpenTypeFiles.Count>=256 then OpenTypeFiles.Delete(0);
  OpenTypeFiles.Add(Key+'='+Result);
end;
function ContainsCJK(const Text:string):Boolean;
var P:Integer;
begin
  P:=1; Result:=False;
  while P<=Length(Text) do begin
    if CJKCodePoint(NextUTF8CodePoint(Text,P)) then Exit(True);
  end;
end;
function DocumentTextFace(const Preamble,Family,Series,Shape,Directory:string; CJK:Boolean; const Engine:string):TFontFace;
var Key,Fontset,Source,Path,Subfamily,Resolved,Active:string; P,Q,I:Integer; Style:TFontStyles;
begin
  if (Preamble<>FontContext) or (Directory<>FontDirectory) or (Engine<>FontEngine) then begin
    FontContext:=Preamble; FontDirectory:=Directory; FontEngine:=Engine; FaceCache:=nil; Fontset:='';
    Active:=ActiveTeXSource(Preamble,Engine); P:=Pos('fontset',Active);
    if P>0 then begin
      Inc(P,7); SkipTeXSpace(Active,P);
      if Copy(Active,P,1)='=' then begin
        Inc(P); SkipTeXSpace(Active,P); Q:=P;
        while (P<=Length(Active)) and (Active[P] in ['a'..'z','A'..'Z','-']) do Inc(P);
        Fontset:=Copy(Active,Q,P-Q);
      end;
    end;
    if (Fontset='') or (Fontset='auto') then begin
      {$IFDEF MSWINDOWS}Fontset:='windows';{$ELSE}Fontset:='fandol';{$ENDIF}
    end;
    Source:=ReadTeXSource(ResolveTeXSource('fontspec.cfg',Directory))+LineEnding+
      ReadTeXSource(ResolveTeXSource('ctex-fontset-'+Fontset+'.def',Directory));
    ConfiguredFonts:=DocumentFonts(ActiveTeXSource(Source,Engine)+LineEnding+Active);
  end;
  Key:=IntToStr(Ord(CJK))+'/'+Family+'/'+Series+'/'+Shape;
  for I:=0 to High(FaceCache) do if FaceCache[I].Key=Key then Exit(FaceCache[I].Face);
  Result:=DocumentFontFace(ConfiguredFonts,CJK,Family,Series,Shape,Directory);
  if Result.Name<>'' then begin
    Style:=[]; if Result.Bold then Include(Style,fsBold); if Result.Italic then Include(Style,fsItalic);
    Path:=OpenTypeFontFile(Result.Name,Style);
    if Path<>'' then begin
      Result.FileName:=Path;
      Subfamily:=LowerCase(OpenTypeSubfamily(Path));
      Result.Bold:=not CJK and (Pos('bold',Subfamily)>0);
      Result.Italic:=not CJK and ((Pos('italic',Subfamily)>0) or (Pos('oblique',Subfamily)>0) or (Pos('slant',Subfamily)>0));
      Resolved:=ResolveTeXFont(Path); if Resolved<>'' then Result.Name:=Resolved;
    end;
  end;
  if CJK and (Result.Name='') then begin
    Result.Name:='FandolSong-Regular';
    if (Series='b') or (Series='bx') then Result.Name:='FandolSong-Bold'
    else if Shape='it' then Result.Name:='FandolKai-Regular';
    if (Family='sf') or (Family='zhhei') then begin
      Result.Name:='FandolHei-Regular'; if (Series='b') or (Series='bx') then Result.Name:='FandolHei-Bold';
    end;
    if (Family='tt') or (Family='zhfs') then Result.Name:='FandolFang-Regular';
    if Family='zhkai' then Result.Name:='FandolKai-Regular';
  end;
  if Length(FaceCache)<128 then begin
    I:=Length(FaceCache); SetLength(FaceCache,I+1); FaceCache[I].Key:=Key; FaceCache[I].Face:=Result;
  end;
end;
function CJKTextFont(const Preamble,Family,Series,Shape:string):string;
begin Result:=DocumentTextFace(Preamble,Family,Series,Shape,'',True).Name; end;
function DefaultCJKFont(const Preamble:string; Style:TFontStyles; const Family:string):string;
var Series,Shape,Name:string;
begin
  Series:='m'; Shape:='n'; if fsBold in Style then Series:='bx'; if fsItalic in Style then Shape:='it';
  Name:=CJKTextFont(Preamble,Family,Series,Shape);
  Result:=ResolveTeXFont(Name); if Result='' then Result:=Name;
end;
procedure LoadTFM(const Name:string; var Metrics:array of TTFMChar);
var Path:string; Data:TMemoryStream; B:PByte;
    LH,BC,EC,NW,NH,ND,NI,NL,NK,CharOffset,HOffset,DOffset,LOffset,KOffset,I,J,Step,C,Index:Integer;
  function WordAt(Offset:Integer):Integer;
  begin Result:=(Integer(B[Offset]) shl 8)+B[Offset+1]; end;
  function FixedAt(Offset:Integer):Double;
  var V:LongWord;
  begin V:=(LongWord(B[Offset]) shl 24) or (LongWord(B[Offset+1]) shl 16) or
    (LongWord(B[Offset+2]) shl 8) or B[Offset+3]; Result:=LongInt(V)/1048576.0; end;
begin
  Data:=TMemoryStream.Create;
  try
    try
    Path:=FindTeXFile(Name); if Path='' then Exit;
    Data.LoadFromFile(Path); if Data.Size<24 then Exit; B:=Data.Memory;
    LH:=WordAt(2); BC:=WordAt(4); EC:=WordAt(6); NW:=WordAt(8); NH:=WordAt(10);
    ND:=WordAt(12); NI:=WordAt(14); NL:=WordAt(16); NK:=WordAt(18);
    CharOffset:=24+LH*4; HOffset:=CharOffset+(EC-BC+1+NW)*4; DOffset:=HOffset+NH*4;
    LOffset:=DOffset+(ND+NI)*4; KOffset:=LOffset+NL*4;
    if (BC>EC) or (EC>High(Metrics)) or (NW=0) or (NH=0) or (ND=0) or
       (KOffset+NK*4>Data.Size) then Exit;
    for I:=BC to EC do begin
      C:=CharOffset+(I-BC)*4;
      if (B[C]>=NW) or (B[C+1] shr 4>=NH) or (B[C+1] and 15>=ND) then Continue;
      Metrics[I].Valid:=B[C]<>0;
      Metrics[I].Height:=FixedAt(HOffset+(B[C+1] shr 4)*4);
      Metrics[I].Depth:=FixedAt(DOffset+(B[C+1] and 15)*4);
      if (B[C+2] and 3)<>1 then Continue;
      Index:=B[C+3];
      for Step:=0 to NL-1 do begin
        if Index>=NL then Break; J:=LOffset+Index*4;
        if B[J]>128 then begin Index:=256*B[J+2]+B[J+3]; Continue; end;
        if (B[J+1]=127) and (B[J+2]>=128) then begin
          Index:=256*(B[J+2]-128)+B[J+3];
          if Index<NK then Metrics[I].Skew:=FixedAt(KOffset+Index*4);
          Break;
        end;
        if B[J]>=128 then Break; Inc(Index,B[J]+1);
      end;
    end;
    except { Optional metrics must not prevent the editor from starting. } end;
  finally Data.Free; end;
end;
function MathInkMetrics(const Text,Style:string; out Height,Depth:Double):Boolean;
var I,C:Integer; M:TTFMChar;
begin
  Result:=Text<>''; Height:=0; Depth:=0;
  for I:=1 to Length(Text) do begin
    C:=Ord(Text[I]);
    if Text[I] in ['a'..'z','A'..'Z'] then begin
      if (Style='') or (Style='\mathit') then M:=ItalicMetrics[C] else M:=RomanMetrics[C];
    end else if Text[I]='-' then M:=SymbolMetrics[0]
    else if Text[I] in ['0'..'9','+','=','(',')','[',']','/','.',',','!',';',':'] then M:=RomanMetrics[C]
    else begin Result:=False; Exit; end;
    if not M.Valid then begin Result:=False; Exit; end;
    Height:=Math.Max(Height,M.Height); Depth:=Math.Max(Depth,M.Depth);
  end;
end;
function MathAccentSkew(const Text,Style:string):Double;
begin
  Result:=0;
  if (Length(Text)=1) and (Text[1] in ['a'..'z','A'..'Z']) and
     ((Style='') or (Style='\mathit')) then Result:=ItalicMetrics[Ord(Text[1])].Skew;
end;
initialization
  CommonFonts:=TStringList.Create; OpenTypeFiles:=TStringList.Create;
  RegisteredFonts:=TStringList.Create; RegisteredFonts.Sorted:=True;
  {$IFNDEF MSWINDOWS}
  CommonFonts.CaseSensitive:=True; OpenTypeFiles.CaseSensitive:=True; RegisteredFonts.CaseSensitive:=True;
  {$ENDIF}
  BlackboardFont:=''; ScriptFont:=''; FrakturFont:='';
  {$IFNDEF MSWINDOWS}LibraryHandle:=LoadLibrary('libfontconfig.so.1');{$ENDIF}
  if LibraryHandle<>NilHandle then begin
    Pointer(AddFont):=GetProcedureAddress(LibraryHandle,'FcConfigAppFontAddFile');
    Pointer(ParseName):=GetProcedureAddress(LibraryHandle,'FcNameParse');
    Pointer(MatchFont):=GetProcedureAddress(LibraryHandle,'FcFontMatch');
    Pointer(FontString):=GetProcedureAddress(LibraryHandle,'FcPatternGetString');
    Pointer(DestroyPattern):=GetProcedureAddress(LibraryHandle,'FcPatternDestroy');
  end;
  { Body fonts use registered OpenType faces. Mathematics reads original
    TeX faces directly with FreeType, including on Windows and GTK. }
  CommonFont('CMR10','PasTeX Roman Ten'); CommonFont('CMR12','PasTeX Roman Twelve');
  CommonFont('CMBX10','PasTeX Bold Ten'); CommonFont('CMBX12','PasTeX Bold Twelve');
  CommonFont('CMTI10','PasTeX Italic Ten'); CommonFont('CMTI12','PasTeX Italic Twelve');
  CommonFont('CMSL10','PasTeX Slanted Ten'); CommonFont('CMTT10','PasTeX Mono Ten');
  CommonFont('CMSS10','PasTeX Sans Ten'); CommonFont('CMSS12','PasTeX Sans Twelve');
  LoadTFM('cmr10.tfm',RomanMetrics); LoadTFM('cmmi10.tfm',ItalicMetrics); LoadTFM('cmsy10.tfm',SymbolMetrics);
finalization
  CommonFonts.Free; OpenTypeFiles.Free; RegisteredFonts.Free;
  if LibraryHandle<>NilHandle then UnloadLibrary(LibraryHandle);
end.
