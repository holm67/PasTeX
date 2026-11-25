unit NativeTeXGlyphs;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Types, Graphics, TeXFontData;
type
  TNativeTeXPart=record Font:string; Code:Integer; X,Y:Double; end;
  TNativeTeXGlyph=class
    Parts:array of TNativeTeXPart;
    Left,Top,Width,Height,Advance,Above,TeXHeight,TeXDepth:Double;
    destructor Destroy; override;
    function Draw(Canvas:TCanvas; const Bounds:TRect; Color:TColor=clDefault; PixelsPerEm:Double=0):Boolean;
  end;
function CreateNativeTeXGlyph(const Kind:string; NeededHeight:Double):TNativeTeXGlyph;
function NativeTeXFontsAvailable:Boolean;
function NativeTeXFaceCount:Integer;
function NativeTeXGlyphCacheCount:Integer;
procedure ClearNativeTeXGlyphCache;
procedure TrimNativeTeXFaces;
function NativeMonospaceFont(const Path:string):Boolean;
implementation
uses Math, Dynlibs, freetypehdyn, FPImage, FPWritePNG, PreviewImage, UITheme, PlatformLibraries, TeXSymbolRuns;
const FaceLimit=32;
      RasterLimit=96;
      RasterPixels=2000000;
type
  TFace=class
    Handle:PFT_Face;
    LastUsed:QWord;
    Data:TMemoryStream;
    Names:array of string;
    destructor Destroy; override;
  end;
  TSelectMap=function(Face:PFT_Face; Encoding:LongWord):Integer; cdecl;
  TNameIndex=function(Face:PFT_Face; Name:PChar):FT_UInt; cdecl;
  TMemoryFace=function(LibraryHandle:PFT_Library; Data:PByte; Size,Index:FT_Long; var Face:PFT_Face):Integer; cdecl;
  TFreeTypeAPI=record
    Init:TFT_Init_FreeType;
    Done:TFT_Done_FreeType;
    DoneFace:TFT_Done_Face;
    FileFace:TFT_New_Face;
    CharIndex:TFT_Get_Char_Index;
    NameIndex:TNameIndex;
    LoadGlyph:TFT_Load_Glyph;
    SetSize:TFT_Set_Char_Size;
    SetTransform:TFT_Set_Transform;
    GetGlyph:TFT_Get_Glyph;
    DoneGlyph:TFT_Done_Glyph;
    GetBounds:TFT_Glyph_Get_CBox;
    ToBitmap:TFT_Glyph_To_Bitmap;
  end;
  TRasterEntry=record
    Glyph:TNativeTeXGlyph;
    Picture:TPicture;
    Surface:TPreviewSurface;
    W,H:Integer;
    PixelsPerEm:Double;
    Color:TColor;
    Stamp:QWord;
  end;
var Engine:PFT_Library; Faces:TStringList; Initialized,Ready:Boolean; LibraryHandle:TLibHandle;
    SelectMap:TSelectMap; MemoryFace:TMemoryFace; API:TFreeTypeAPI;
    Rasters:array[0..RasterLimit-1] of TRasterEntry; Clock:QWord;
procedure FreeRaster(Index:Integer);
begin
  FreeAndNil(Rasters[Index].Surface); FreeAndNil(Rasters[Index].Picture); Rasters[Index].Glyph:=nil;
end;
destructor TNativeTeXGlyph.Destroy;
var I:Integer;
begin
  for I:=0 to High(Rasters) do if Rasters[I].Glyph=Self then FreeRaster(I);
  inherited Destroy;
end;
procedure ClearNativeTeXGlyphCache;
var I:Integer;
begin for I:=0 to High(Rasters) do FreeRaster(I); end;
procedure TrimNativeTeXFaces;
var I:Integer; Now:QWord;
begin
  Now:=GetTickCount64;
  for I:=Faces.Count-1 downto 0 do if Now-TFace(Faces.Objects[I]).LastUsed>1000 then begin
    Faces.Objects[I].Free; Faces.Delete(I);
  end;
end;
function NativeTeXGlyphCacheCount:Integer;
var I:Integer;
begin
  Result:=0; for I:=0 to High(Rasters) do if Rasters[I].Picture<>nil then Inc(Result);
end;
destructor TFace.Destroy;
begin if Handle<>nil then API.DoneFace(Handle); Data.Free; inherited Destroy; end;
function NativeTeXFontsAvailable:Boolean;
var Names:array[0..2] of string; Name:string;
begin
  if Initialized then Exit(Ready); Initialized:=True;
  if GetEnvironmentVariable('PASTEX_DISABLE_RUNTIME_FONTS')='1' then Exit(False);
  {$IFDEF MSWINDOWS}Names[0]:='freetype.dll'; Names[1]:='libfreetype-6.dll'; Names[2]:='freetype6.dll';
  {$ELSE}{$IFDEF DARWIN}Names[0]:='libfreetype.6.dylib'; Names[1]:='libfreetype.dylib'; Names[2]:='';
  {$ELSE}Names[0]:='libfreetype.so.6'; Names[1]:='libfreetype.so'; Names[2]:='';{$ENDIF}{$ENDIF}
  { Own the callbacks and library reference. FCL's dynamic FreeType unit
    may clear its global callbacks before this unit's font-cache finalizer. }
  for Name in Names do if Name<>'' then begin
    LibraryHandle:=LoadOptionalLibrary([Name]); if LibraryHandle=NilHandle then Continue;
    Pointer(SelectMap):=GetProcedureAddress(LibraryHandle,'FT_Select_Charmap');
    Pointer(MemoryFace):=GetProcedureAddress(LibraryHandle,'FT_New_Memory_Face');
    Pointer(API.Init):=GetProcedureAddress(LibraryHandle,'FT_Init_FreeType');
    Pointer(API.Done):=GetProcedureAddress(LibraryHandle,'FT_Done_FreeType');
    Pointer(API.DoneFace):=GetProcedureAddress(LibraryHandle,'FT_Done_Face');
    Pointer(API.FileFace):=GetProcedureAddress(LibraryHandle,'FT_New_Face');
    Pointer(API.CharIndex):=GetProcedureAddress(LibraryHandle,'FT_Get_Char_Index');
    Pointer(API.NameIndex):=GetProcedureAddress(LibraryHandle,'FT_Get_Name_Index');
    Pointer(API.LoadGlyph):=GetProcedureAddress(LibraryHandle,'FT_Load_Glyph');
    Pointer(API.SetSize):=GetProcedureAddress(LibraryHandle,'FT_Set_Char_Size');
    Pointer(API.SetTransform):=GetProcedureAddress(LibraryHandle,'FT_Set_Transform');
    Pointer(API.GetGlyph):=GetProcedureAddress(LibraryHandle,'FT_Get_Glyph');
    Pointer(API.DoneGlyph):=GetProcedureAddress(LibraryHandle,'FT_Done_Glyph');
    Pointer(API.GetBounds):=GetProcedureAddress(LibraryHandle,'FT_Glyph_Get_CBox');
    Pointer(API.ToBitmap):=GetProcedureAddress(LibraryHandle,'FT_Glyph_To_Bitmap');
    Ready:=Assigned(SelectMap) and Assigned(MemoryFace) and Assigned(API.Init) and Assigned(API.Done) and
      Assigned(API.DoneFace) and Assigned(API.CharIndex) and Assigned(API.LoadGlyph) and Assigned(API.SetSize) and
      Assigned(API.SetTransform) and Assigned(API.GetGlyph) and Assigned(API.DoneGlyph) and
      Assigned(API.GetBounds) and Assigned(API.ToBitmap);
    if Ready then Ready:=API.Init(Engine)=0;
    if Ready then Break;
    Engine:=nil;
    UnloadLibrary(LibraryHandle); LibraryHandle:=NilHandle;
  end;
  Result:=Ready;
end;
function MappedFont(const Name:string; out EncodingFile:string):string;
var Map:TextFile; Path,Line,Token:string; P,A:Integer;
begin
  Result:=''; EncodingFile:=''; Path:=FindTeXFile('pdftex.map'); if Path='' then Exit;
  { Read only the matching entry, rather than retaining the complete map.
    TFM aliases and their encodings are selected by the user's TeX setup. }
  AssignFile(Map,Path);
  try Reset(Map); except Exit; end;
  try
    while not EOF(Map) do begin
      ReadLn(Map,Line); Line:=TrimLeft(Line); P:=1;
      while (P<=Length(Line)) and not (Line[P] in [' ',#9]) do Inc(P);
      if Copy(Line,1,P-1)<>Name then Continue;
      while P<=Length(Line) do begin
        if Line[P]<>'<' then begin Inc(P); Continue; end;
        while (P<=Length(Line)) and (Line[P] in ['<','[']) do Inc(P); A:=P;
        while (P<=Length(Line)) and not (Line[P] in [' ',#9,'"']) do Inc(P);
        Token:=Copy(Line,A,P-A);
        case LowerCase(ExtractFileExt(Token)) of
          '.pfb','.pfa':Result:=FindTeXFile(Token);
          '.enc':EncodingFile:=FindTeXFile(Token);
        end;
      end;
      Break;
    end;
  finally CloseFile(Map); end;
end;
procedure LoadEncoding(Entry:TFace; const Path:string);
var Lines:TStringList; Source:string; P,A,N:Integer;
begin
  if (Path='') or not Assigned(API.NameIndex) then Exit;
  Lines:=TStringList.Create;
  try
    Lines.LoadFromFile(Path); Source:=Lines.Text; P:=1;
    while P<=Length(Source) do begin
      if Source[P]='%' then while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P)
      else if Source[P]='[' then Break else Inc(P);
    end;
    if P>Length(Source) then Exit; Inc(P); SetLength(Entry.Names,256); N:=0;
    while (P<=Length(Source)) and (Source[P]<>']') and (N<256) do begin
      if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
      if Source[P]<>'/' then begin Inc(P); Continue; end;
      Inc(P); A:=P;
      while (P<=Length(Source)) and not (Source[P] in [' ',#9,#10,#13,'/',']']) do Inc(P);
      Entry.Names[N]:=Copy(Source,A,P-A); Inc(N);
    end;
  finally Lines.Free; end;
end;
function GetFace(const Name:string):PFT_Face;
var I:Integer; Entry:TFace; Path,EncodingFile:string; Encoding:LongWord;
begin
  Result:=nil; if not NativeTeXFontsAvailable then Exit;
  I:=Faces.IndexOf(Name);
  if I>=0 then begin TFace(Faces.Objects[I]).LastUsed:=GetTickCount64; Result:=TFace(Faces.Objects[I]).Handle; Faces.Move(I,Faces.Count-1); Exit; end;
  { Glyph plans retain names, not face pointers. Evict the least recently
    used face so a newly selected document font never loses its outlines. }
  if Faces.Count>=FaceLimit then begin Faces.Objects[0].Free; Faces.Delete(0); end;
  Entry:=TFace.Create; Entry.LastUsed:=GetTickCount64; Faces.AddObject(Name,Entry);
  Encoding:=$41444243; EncodingFile:='';
  if FileExists(Name) then begin Path:=Name; Encoding:=$756E6963; end
  else begin
    Path:=FindTeXFile(Name+'.pfb');
    if Path='' then Path:=MappedFont(Name,EncodingFile);
  end;
  if Path='' then Exit;
  try
    { FreeType can read font tables from a file stream without our retaining
      another complete CJK font buffer. Memory remains the Unicode-path
      fallback for platforms whose FreeType file loader cannot open it. }
    if not Assigned(API.FileFace) or (API.FileFace(Engine,PChar(Path),0,Entry.Handle)<>0) then begin
      Entry.Data:=TMemoryStream.Create; Entry.Data.LoadFromFile(Path);
      if MemoryFace(Engine,Entry.Data.Memory,Entry.Data.Size,0,Entry.Handle)<>0 then Exit;
    end;
    { Type 1 faces retain TeX's original slots; OpenType uses Unicode.
      Reading bytes also supports Unicode font paths on Windows. }
    LoadEncoding(Entry,EncodingFile);
    if (SelectMap(Entry.Handle,Encoding)<>0) and (Length(Entry.Names)=0) then begin API.DoneFace(Entry.Handle); Entry.Handle:=nil; end;
    Result:=Entry.Handle;
  except Result:=nil; end;
end;
function GlyphIndex(Face:PFT_Face; const Font:string; Code:Integer):FT_UInt;
var I:Integer; Entry:TFace;
begin
  if Code<0 then Exit(FT_UInt(-Code-1));
  I:=Faces.IndexOf(Font);
  if I>=0 then begin
    Entry:=TFace(Faces.Objects[I]);
    if (Code>=0) and (Code<Length(Entry.Names)) then Exit(API.NameIndex(Face,PChar(Entry.Names[Code])));
  end;
  Result:=API.CharIndex(Face,Code);
end;
function NativeMonospaceFont(const Path:string):Boolean;
const Samples='MiW0@. ';
var Face:PFT_Face; I:Integer; Advance:FT_Pos;
begin
  Result:=False; Face:=GetFace(Path); if Face=nil then Exit;
  API.SetTransform(Face,nil,nil); Advance:=0;
  for I:=1 to Length(Samples) do begin
    if API.LoadGlyph(Face,API.CharIndex(Face,Ord(Samples[I])),FT_LOAD_NO_SCALE or FT_LOAD_NO_HINTING)<>0 then Exit;
    if I=1 then Advance:=Face^.glyph^.metrics.horiAdvance
    else if Advance<>Face^.glyph^.metrics.horiAdvance then Exit;
  end;
  Result:=Advance>0;
end;
function NativeTeXFaceCount:Integer;
begin Result:=Faces.Count; end;
function CharInk(const Font:string; Code:Integer; out Bounds:FT_BBox; out Units:Double):Boolean;
var Face:PFT_Face; Glyph:PFT_Glyph; Index:FT_UInt;
begin
  Result:=False; Face:=GetFace(Font); if Face=nil then Exit;
  API.SetTransform(Face,nil,nil);
  Index:=GlyphIndex(Face,Font,Code); if Index=0 then Exit;
  if API.LoadGlyph(Face,Index,FT_LOAD_NO_SCALE or FT_LOAD_NO_HINTING)<>0 then Exit;
  Glyph:=nil; if API.GetGlyph(Face^.glyph,Glyph)<>0 then Exit;
  try
    API.GetBounds(Glyph,ft_glyph_bbox_unscaled,Bounds); Units:=Face^.units_per_EM;
    Result:=(Units>0) and (Bounds.xMax>Bounds.xMin) and (Bounds.yMax>Bounds.yMin);
  finally API.DoneGlyph(Glyph); end;
end;
function FinishGlyph(G:TNativeTeXGlyph):Boolean;
var Part:TNativeTeXPart; Bounds:FT_BBox; Units,L,R,T,B,Bottom,Right:Double; First:Boolean;
begin
  Result:=False; First:=True; Bottom:=0; Right:=0;
  for Part in G.Parts do begin
    if not CharInk(Part.Font,Part.Code,Bounds,Units) then Exit;
    L:=Part.X+Bounds.xMin/Units; R:=Part.X+Bounds.xMax/Units;
    T:=Part.Y+Bounds.yMax/Units; B:=Part.Y+Bounds.yMin/Units;
    if First then begin G.Left:=L; Right:=R; G.Top:=T; Bottom:=B; First:=False; end
    else begin G.Left:=Min(G.Left,L); Right:=Max(Right,R); G.Top:=Max(G.Top,T); Bottom:=Min(Bottom,B); end;
  end;
  if First then Exit;
  G.Width:=Right-G.Left; G.Height:=G.Top-Bottom; G.Above:=G.Top;
  Result:=(G.Width>0) and (G.Height>0);
end;
function CompositeArrow(const Name:string; Points:Integer; Width:Double):TNativeTeXGlyph;
var Left,Right,Bar,Family,Font:string; Code,N:Integer; X,Shift:Double; Metric:TTeXFontMetric; G:TNativeTeXGlyph;
  function SymbolWidth(const Symbol:string):Double;
  begin
    Result:=0;
    if TeXSymbol(Symbol,Family,Code) then Result:=TeXFontMetric(TeXOpticalFont(Family,Points)).Chars[Code].Width;
  end;
  function Part(const Symbol:string; AtX:Double; AtY:Double=0):Double;
  begin
    Result:=0;
    if not TeXSymbol(Symbol,Family,Code) then Exit;
    Font:=TeXOpticalFont(Family,Points); Metric:=TeXFontMetric(Font);
    N:=Length(G.Parts); SetLength(G.Parts,N+1);
    G.Parts[N].Font:=Font; G.Parts[N].Code:=Code; G.Parts[N].X:=AtX; G.Parts[N].Y:=AtY;
    Result:=Metric.Chars[Code].Width;
    G.TeXHeight:=Max(G.TeXHeight,Metric.Chars[Code].Height+AtY);
    G.TeXDepth:=Max(G.TeXDepth,Metric.Chars[Code].Depth-AtY);
  end;
  procedure Fill(const LeftEnd,RightEnd:string; AtY:Double);
  var L,R,BarWidth,First,Last,Step,X:Double; I:Integer;
  begin
    L:=Part(LeftEnd,0,AtY); R:=SymbolWidth(RightEnd); Part(RightEnd,Width-R,AtY);
    BarWidth:=SymbolWidth(Bar); if BarWidth<=0 then Exit;
    { AMS arrowfill joins endpoints by -7mu and repeats bars with -2mu
      on either side. Keep the leaders away from the tips of arrowheads. }
    First:=Max(0,L-9/18); Last:=Min(Width,Width-R+9/18);
    Step:=Max(0.05,BarWidth-4/18); X:=First;
    for I:=0 to Min(1024,Ceil(Max(0,Last-First)/Step)) do begin
      if Last-First<BarWidth then Break;
      Part(Bar,Min(X,Last-BarWidth),AtY); if X+BarWidth>=Last then Break;
      X:=X+Step;
    end;
  end;
begin
  Result:=nil; Left:=''; Right:=''; Bar:='-';
  case Name of
    'longrightarrow','overrightarrow','underrightarrow','xrightarrow','xlongrightarrow':Right:='\rightarrow';
    'longleftarrow','overleftarrow','underleftarrow','xleftarrow','xlongleftarrow':Left:='\leftarrow';
    'longleftrightarrow','overleftrightarrow','underleftrightarrow','xleftrightarrow','xlongleftrightarrow':begin Left:='\leftarrow'; Right:='\rightarrow'; end;
    'Longrightarrow','implies','xRightarrow','xLongrightarrow':begin Bar:='='; Right:='\Rightarrow'; end;
    'Longleftarrow','impliedby','xLeftarrow','xLongleftarrow':begin Bar:='='; Left:='\Leftarrow'; end;
    'Longleftrightarrow','iff','xLeftrightarrow','xLongleftrightarrow':begin Bar:='='; Left:='\Leftarrow'; Right:='\Rightarrow'; end;
    'mapsto','longmapsto','xmapsto':begin Left:='\mapstochar'; Right:='\rightarrow'; end;
    'hookrightarrow','xhookrightarrow':begin Left:='\lhook'; Right:='\rightarrow'; end;
    'hookleftarrow','xhookleftarrow':begin Left:='\leftarrow'; Right:='\rhook'; end;
    'xrightharpoonup':Right:='\rightharpoonup'; 'xrightharpoondown':Right:='\rightharpoondown';
    'xleftharpoonup':Left:='\leftharpoonup'; 'xleftharpoondown':Left:='\leftharpoondown';
    'xrightleftharpoons','xleftrightharpoons':;
    'xlongequal':Bar:='=';
    else Exit;
  end;
  Result:=TNativeTeXGlyph.Create; G:=Result;
  try
    if (Width<=0) and (Copy(Name,1,1)='x') then Width:=1.5;
    if Width>0 then begin
      Width:=Max(0.8,Width);
      if (Name='xrightleftharpoons') or (Name='xleftrightharpoons') then begin
        Metric:=TeXFontMetric(TeXOpticalFont('cmsy',Points)); Shift:=0.22*0.430556;
        if Length(Metric.Parameters)>4 then Shift:=0.22*Metric.Parameters[4];
        if Name='xrightleftharpoons' then begin
          Fill(Bar,'\rightharpoonup',Shift); Fill('\leftharpoondown',Bar,-Shift);
        end else begin
          Fill('\leftharpoonup',Bar,Shift); Fill(Bar,'\rightharpoondown',-Shift);
        end;
      end else begin
        if Left='' then Left:=Bar; if Right='' then Right:=Bar;
        Width:=Max(Width,SymbolWidth(Left)+SymbolWidth(Right)-14/18);
        Fill(Left,Right,0);
      end;
      Result.Advance:=Width;
    end else begin
      X:=0;
      if Left<>'' then X:=Part(Left,0);
      if (Name='longmapsto') or (Name='longrightarrow') or (Name='Longrightarrow') or
         (Name='longleftarrow') or (Name='Longleftarrow') or (Name='implies') or (Name='impliedby') then begin
        if X>0 then X:=X-1/6; X:=X+Part(Bar,X);
      end;
      if Right<>'' then begin
        if (X>0) and (Name<>'mapsto') and (Name<>'longmapsto') then X:=X-1/6;
        X:=X+Part(Right,X);
      end;
      Result.Advance:=X;
    end;
    if not FinishGlyph(Result) then FreeAndNil(Result);
  except FreeAndNil(Result); end;
end;
function CreateNativeTeXGlyph(const Kind:string; NeededHeight:Double):TNativeTeXGlyph;
var Name,Family,Font,Token,Variant,LargeFamily:string; Code,Points,P,I,SmallCode,LargeCode,Steps,J,Copies:Integer;
    Metric:TTeXFontMetric; M:TTeXCharMetric; Recipe:TTeXRecipe;
    Total,StepHeight,Offset,Shift,Units:Double; Fixed,OperatorGlyph,Found:Boolean;
    Face:PFT_Face; Bounds:FT_BBox; Run:TSymbolRun;
  procedure AddPart(AChar:Integer; X,Y:Double);
  var N:Integer;
  begin
    N:=Length(Result.Parts); SetLength(Result.Parts,N+1);
    Result.Parts[N].Font:=Font; Result.Parts[N].Code:=AChar; Result.Parts[N].X:=X; Result.Parts[N].Y:=Y;
  end;
  procedure Stack(AChar:Integer);
  var C:TTeXCharMetric;
  begin
    C:=Metric.Chars[AChar]; AddPart(AChar,0,-Offset-C.Height); Offset:=Offset+C.Height+C.Depth;
  end;
begin
  Result:=nil; if not NativeTeXFontsAvailable then Exit;
  Font:=''; Name:=Kind; Points:=10; SmallCode:=-1; LargeCode:=-1; Code:=-1;
  OperatorGlyph:=False; Fixed:=False; Copies:=1;
  if Copy(Name,1,11)='symbol-run-' then begin
    if not DecodeSymbolRun(Copy(Name,12,MaxInt),Run) then Exit;
    Result:=TNativeTeXGlyph.Create; Result.Advance:=Run.Advance;
    for I:=0 to High(Run.Parts) do begin
      Font:=Run.Parts[I].Font; AddPart(Run.Parts[I].Code,Run.Parts[I].X,Run.Parts[I].Y);
      M:=TeXFontMetric(Font).Chars[Run.Parts[I].Code];
      Result.TeXHeight:=Max(Result.TeXHeight,M.Height+Run.Parts[I].Y);
      Result.TeXDepth:=Max(Result.TeXDepth,M.Depth-Run.Parts[I].Y);
    end;
    if not FinishGlyph(Result) then FreeAndNil(Result); Exit;
  end;
  if Copy(Name,1,6)='arrow-' then Exit(CompositeArrow(Copy(Name,7,MaxInt),10,NeededHeight));
  if (Copy(Name,1,8)='unicode-') or (Copy(Name,1,6)='glyph-') then begin
    P:=Pos('-',Name); Token:=Copy(Name,P+1,MaxInt); P:=LastDelimiter('-',Token); if P=0 then Exit;
    Font:=Copy(Token,1,P-1); Code:=StrToIntDef(Copy(Token,P+1,MaxInt),-1);
    if Code<0 then Exit;
    if Copy(Name,1,6)='glyph-' then Code:=-Code-1;
    if not CharInk(Font,Code,Bounds,Units) then Exit;
    Face:=GetFace(Font); Result:=TNativeTeXGlyph.Create;
    Result.Advance:=Face^.glyph^.metrics.horiAdvance/Units;
    Result.TeXHeight:=Max(0,Bounds.yMax/Units); Result.TeXDepth:=Max(0,-Bounds.yMin/Units);
    AddPart(Code,0,0);
    if not FinishGlyph(Result) then FreeAndNil(Result);
    Exit;
  end;
  if Copy(Name,1,6)='fixed-' then begin Delete(Name,1,6); Fixed:=True; end;
  if Copy(Name,1,9)='operator-' then begin Delete(Name,1,9); OperatorGlyph:=True; end;
  case Name of
    'paren-open':begin Family:='cmr'; SmallCode:=$28; LargeCode:=$00; end;
    'paren-close':begin Family:='cmr'; SmallCode:=$29; LargeCode:=$01; end;
    'square-open':begin Family:='cmr'; SmallCode:=$5B; LargeCode:=$02; end;
    'square-close':begin Family:='cmr'; SmallCode:=$5D; LargeCode:=$03; end;
    'brace-open':begin Family:='cmsy'; SmallCode:=$66; LargeCode:=$08; end;
    'brace-close':begin Family:='cmsy'; SmallCode:=$67; LargeCode:=$09; end;
    'angle-open':begin Family:='cmsy'; SmallCode:=$68; LargeCode:=$0A; end;
    'angle-close':begin Family:='cmsy'; SmallCode:=$69; LargeCode:=$0B; end;
    'vert':begin Family:='cmsy'; SmallCode:=$6A; LargeCode:=$0C; end;
    'Vert':begin Family:='cmsy'; SmallCode:=$6B; LargeCode:=$0D; end;
    'floor-open':begin Family:='cmsy'; SmallCode:=$62; LargeCode:=$04; end;
    'floor-close':begin Family:='cmsy'; SmallCode:=$63; LargeCode:=$05; end;
    'ceil-open':begin Family:='cmsy'; SmallCode:=$64; LargeCode:=$06; end;
    'ceil-close':begin Family:='cmsy'; SmallCode:=$65; LargeCode:=$07; end;
    'radical':begin Family:='cmsy'; SmallCode:=$70; LargeCode:=$70; end;
  end;
  LargeFamily:='cmex';
  if Copy(Name,1,10)='delimiter-' then begin
    if not TeXDelimiter(Copy(Name,11,MaxInt),Family,LargeFamily,SmallCode,LargeCode) then Exit;
  end;
  if Copy(Name,1,15)='font-delimiter-' then begin
    Token:=Copy(Name,16,MaxInt); P:=Pos(':',Token); if P=0 then Exit;
    Font:=Copy(Token,1,P-1); Delete(Token,1,P); P:=Pos(':',Token); if P=0 then Exit;
    SmallCode:=StrToIntDef(Copy(Token,1,P-1),-1); Delete(Token,1,P); P:=Pos(':',Token); if P=0 then Exit;
    LargeFamily:=Copy(Token,1,P-1); LargeCode:=StrToIntDef(Copy(Token,P+1,MaxInt),-1);
    if (SmallCode<0) or (SmallCode>255) or (LargeCode<0) or (LargeCode>255) then Exit;
    Metric:=TeXFontMetric(Font); if not Metric.Valid then Exit;
    Code:=SmallCode; M:=Metric.Chars[Code];
    if not Fixed and (M.Height+M.Depth<NeededHeight-0.0001) then begin Font:=LargeFamily; Code:=LargeCode; end;
  end else if SmallCode>=0 then begin
    Font:=Family+'10'; Code:=SmallCode; Metric:=TeXFontMetric(Font);
    if not Metric.Valid then Exit;
    M:=Metric.Chars[Code];
    if not Fixed and (M.Height+M.Depth<NeededHeight-0.0001) then begin Font:=LargeFamily+'10'; Code:=LargeCode; end;
  end else if Copy(Name,1,5)='text-' then begin
    Token:=Copy(Name,6,MaxInt); P:=LastDelimiter('-',Token); if P=0 then Exit;
    Font:=Copy(Token,1,P-1); Code:=StrToIntDef(Copy(Token,P+1,MaxInt),-1);
    if (Code<0) or (Code>255) then Exit;
  end else if Copy(Name,1,13)='math-default-' then begin
    Token:=Copy(Name,14,MaxInt); P:=Pos('-',Token); Points:=StrToIntDef(Copy(Token,1,P-1),10); Token:=Copy(Token,P+1,MaxInt);
    if Length(Token)<>1 then Exit;
    if not TeXSymbol(Token,Family,Code) then Exit;
    Font:=TeXOpticalFont(Family,Points);
  end else if Copy(Name,1,12)='math-symbol-' then begin
    Token:=Copy(Name,13,MaxInt); P:=Pos('-',Token); Points:=StrToIntDef(Copy(Token,1,P-1),10); Token:=Copy(Token,P+1,MaxInt);
    Result:=CompositeArrow(Token,Points,0); if Result<>nil then Exit;
    if not TeXSymbol('\'+Token,Family,Code) then Exit(CompositeArrow(Token,Points,0));
    Font:=TeXOpticalFont(Family,Points);
  end else if (Copy(Name,1,7)='mathbb-') or (Copy(Name,1,9)='mathfrak-') or
              (Copy(Name,1,8)='mathscr-') or (Copy(Name,1,8)='mathcal-') then begin
    P:=Pos('-',Name); Token:=Copy(Name,P+1,MaxInt); if Length(Token)<>1 then Exit;
    Code:=Ord(Token[1]); Family:=Copy(Name,1,P-1);
    case Family of 'mathbb':Font:='msbm10'; 'mathfrak':Font:='eufm10'; 'mathscr':Font:='rsfs10'; 'mathcal':Font:='cmsy10'; end;
  end else if (Name='dot') or (Name='ddot') then begin
    Font:='cmr10'; if Name='dot' then Code:=$5F else Code:=$7F;
  end else if Copy(Name,1,3)='hat' then begin
    Variant:=Copy(Name,4,MaxInt); I:=StrToIntDef(Variant,0);
    if I=0 then begin Font:='cmr10'; Code:=$5E; end
    else begin Font:='cmex10'; Code:=$62+EnsureRange(I-1,0,2); end;
  end else begin
    P:=Pos('-display',Name); if P=0 then P:=Pos('-text',Name);
    if P>0 then begin
      Token:=Copy(Name,1,P-1);
      if Token='iint' then begin Token:='int'; Copies:=2; end
      else if Token='iiint' then begin Token:='int'; Copies:=3; end;
      if Token='iiiint' then begin Token:='int'; Copies:=4; end;
      if not TeXSymbol('\'+Token,Family,Code) or (Family<>'cmex') then Exit;
      Font:='cmex10'; OperatorGlyph:=True;
      if Pos('-display',Name)>0 then begin
        Metric:=TeXFontMetric(Font); if Metric.Chars[Code].Tag=2 then Code:=Metric.Chars[Code].Remainder;
      end;
    end;
  end;
  if (Font='') or (Code<0) or (GetFace(Font)=nil) then Exit;
  Metric:=TeXFontMetric(Font); if not Metric.Valid then Exit;
  Found:=False;
  for I:=0 to 255 do begin
    M:=Metric.Chars[Code]; if not M.Valid then Exit;
    if (M.Tag=3) or (M.Height+M.Depth>=NeededHeight-0.0001) or (M.Tag<>2) or Fixed then begin Found:=True; Break; end;
    Code:=M.Remainder;
  end;
  if not Found then Exit;
  Result:=TNativeTeXGlyph.Create;
  try
    Result.Advance:=M.Width;
    if (SmallCode<0) and (Copy(Name,1,3)<>'hat') then Result.Advance:=M.Width+M.Italic;
    Result.TeXHeight:=M.Height; Result.TeXDepth:=M.Depth;
    if (M.Tag=3) and not Fixed then begin
      if M.Remainder>=Length(Metric.Recipes) then begin FreeAndNil(Result); Exit; end;
      Recipe:=Metric.Recipes[M.Remainder]; Total:=0;
      if Recipe.Top<>0 then Total:=Total+Metric.Chars[Recipe.Top].Height+Metric.Chars[Recipe.Top].Depth;
      if Recipe.Middle<>0 then Total:=Total+Metric.Chars[Recipe.Middle].Height+Metric.Chars[Recipe.Middle].Depth;
      if Recipe.Bottom<>0 then Total:=Total+Metric.Chars[Recipe.Bottom].Height+Metric.Chars[Recipe.Bottom].Depth;
      StepHeight:=Metric.Chars[Recipe.RepeatChar].Height+Metric.Chars[Recipe.RepeatChar].Depth;
      if Recipe.Middle<>0 then StepHeight:=StepHeight*2;
      Steps:=0;
      if StepHeight>0 then Steps:=EnsureRange(Ceil((NeededHeight-Total)/StepHeight),0,1024);
      Offset:=0;
      if Recipe.Top<>0 then Stack(Recipe.Top);
      for J:=1 to Steps do Stack(Recipe.RepeatChar);
      if Recipe.Middle<>0 then begin Stack(Recipe.Middle); for J:=1 to Steps do Stack(Recipe.RepeatChar); end;
      if Recipe.Bottom<>0 then Stack(Recipe.Bottom);
      Result.Advance:=Metric.Chars[Recipe.RepeatChar].Width;
      Result.TeXHeight:=0; Result.TeXDepth:=Offset;
      if Length(Result.Parts)>0 then Result.TeXHeight:=Metric.Chars[Result.Parts[0].Code].Height;
      Result.TeXDepth:=Offset-Result.TeXHeight;
    end else begin
      AddPart(Code,0,0);
      if Copies>1 then begin
        Offset:=M.Width+M.Italic-1/6;
        if Pos('-display',Name)>0 then Offset:=M.Width+M.Italic-1/3;
        for J:=2 to Copies do AddPart(Code,(J-1)*Offset,0);
        Result.Advance:=Result.Advance+(Copies-1)*Offset;
      end;
    end;
    { TeX centers a large operator on the math axis; CMEX glyphs have most
      of their ink below their own baseline. }
    if OperatorGlyph then begin
      Shift:=(M.Depth-M.Height)/2+0.25;
      for I:=0 to High(Result.Parts) do Result.Parts[I].Y:=Result.Parts[I].Y+Shift;
    end;
    if not FinishGlyph(Result) then FreeAndNil(Result);
  except FreeAndNil(Result); end;
end;
function TNativeTeXGlyph.Draw(Canvas:TCanvas; const Bounds:TRect; Color:TColor; PixelsPerEm:Double):Boolean;
var Image:TFPMemoryImage; Writer:TFPWriterPNG; Stream:TMemoryStream; Picture:TPicture; Surface:TPreviewSurface;
    Part:TNativeTeXPart; Face:PFT_Face; Glyph:PFT_Glyph; Bitmap:PFT_BitmapGlyph;
    Transform:FT_Matrix; Delta:FT_Vector; SX,SY,Scale:Double; W,H,X,Y,DX,DY,Pitch,Alpha,OldAlpha,Row:Integer;
    Pixel:TFPColor; RGB:LongInt; Slot,I,Oldest:Integer; Pixels:Int64; ActualColor:TColor;
begin
  ActualColor:=Color; if ActualColor=clDefault then ActualColor:=InkColor;
  Result:=False; Scale:=PreviewCanvasScale(Canvas);
  W:=Round((Bounds.Right-Bounds.Left)*Scale); H:=Round((Bounds.Bottom-Bounds.Top)*Scale);
  PixelsPerEm:=PixelsPerEm*Scale;
  if (W<1) or (H<1) or (Int64(W)*H>4000000) then Exit;
  Inc(Clock); Slot:=0;
  for I:=0 to High(Rasters) do begin
    if (Rasters[I].Glyph=Self) and (Rasters[I].W=W) and (Rasters[I].H=H) and
       (Rasters[I].Color=ActualColor) and (Rasters[I].PixelsPerEm=PixelsPerEm) and (Rasters[I].Picture<>nil) then begin
      Rasters[I].Stamp:=Clock; Rasters[I].Surface.Draw(Canvas,Bounds,Rasters[I].Picture); Exit(True);
    end;
    if (Rasters[I].Picture=nil) or (Rasters[I].Stamp<Rasters[Slot].Stamp) then Slot:=I;
  end;
  FreeRaster(Slot);
  Image:=TFPMemoryImage.Create(W,H); Writer:=TFPWriterPNG.Create; Stream:=TMemoryStream.Create;
  Picture:=TPicture.Create; Surface:=TPreviewSurface.Create; Surface.PreserveColors:=True;
  try
    Pixel:=colTransparent;
    for Y:=0 to H-1 do for X:=0 to W-1 do Image.Colors[X,Y]:=Pixel;
    if PixelsPerEm>0 then begin SX:=PixelsPerEm; SY:=PixelsPerEm; end
    else begin SX:=W/Width; SY:=H/Height; end;
    RGB:=ColorToRGB(ActualColor);
    for Part in Parts do begin
      Face:=GetFace(Part.Font); if Face=nil then Exit;
      if API.SetSize(Face,0,Max(64,Round(SY*64)),72,72)<>0 then Exit;
      Transform.xx:=Round(SX/SY*65536); Transform.yy:=65536; Transform.xy:=0; Transform.yx:=0;
      { Keep each part's fractional position until FreeType rasterizes it.
        Rounding a part's baseline first can move its last row outside the
        ink bounds, especially for axis-centered integral glyphs. }
      if PixelsPerEm>0 then begin
        Delta.x:=Round(Part.X*SX*64); Delta.y:=Round(Part.Y*SY*64);
      end else begin
        Delta.x:=Round((Part.X-Left)*SX*64); Delta.y:=Round((Part.Y-Top)*SY*64);
      end;
      API.SetTransform(Face,@Transform,@Delta);
      if API.LoadGlyph(Face,GlyphIndex(Face,Part.Font,Part.Code),FT_LOAD_NO_HINTING or FT_LOAD_NO_BITMAP)<>0 then Exit;
      Glyph:=nil; if API.GetGlyph(Face^.glyph,Glyph)<>0 then Exit;
      try
        if API.ToBitmap(Glyph,FT_RENDER_MODE_NORMAL,nil,True)<>0 then Exit;
        Bitmap:=PFT_BitmapGlyph(Glyph);
        if PixelsPerEm>0 then begin
          DX:=Bitmap^.left-Floor(Left*SX);
          DY:=Ceil(Top*SY)-Bitmap^.top;
        end else begin
          DX:=Bitmap^.left; DY:=-Bitmap^.top;
        end;
        Pitch:=Bitmap^.bitmap.pitch;
        for Y:=0 to Integer(Bitmap^.bitmap.rows)-1 do begin
          if (DY+Y<0) or (DY+Y>=H) then Continue;
          Row:=Y*Pitch; if Pitch<0 then Row:=(Integer(Bitmap^.bitmap.rows)-1-Y)*(-Pitch);
          for X:=0 to Integer(Bitmap^.bitmap.width)-1 do begin
            if (DX+X<0) or (DX+X>=W) then Continue;
            Alpha:=PByte(Bitmap^.bitmap.buffer)[Row+X]*257; if Alpha=0 then Continue;
            OldAlpha:=Image.Colors[DX+X,DY+Y].Alpha;
            Pixel.Red:=(RGB and 255)*257; Pixel.Green:=((RGB shr 8) and 255)*257; Pixel.Blue:=((RGB shr 16) and 255)*257;
            Pixel.Alpha:=Min(65535,OldAlpha+Alpha-(Int64(OldAlpha)*Alpha div 65535)); Image.Colors[DX+X,DY+Y]:=Pixel;
          end;
        end;
      finally API.DoneGlyph(Glyph); end;
    end;
    Writer.UseAlpha:=True; Image.SaveToStream(Stream,Writer); Stream.Position:=0; Picture.LoadFromStream(Stream);
    Surface.Draw(Canvas,Bounds,Picture); Result:=True;
    { Keep both glyph count and total pixel memory bounded across editors. }
    if Int64(W)*H<=RasterPixels then begin
      repeat
        Pixels:=Int64(W)*H; Oldest:=-1;
        for I:=0 to High(Rasters) do if Rasters[I].Picture<>nil then begin
          Inc(Pixels,Int64(Rasters[I].W)*Rasters[I].H);
          if (Oldest<0) or (Rasters[I].Stamp<Rasters[Oldest].Stamp) then Oldest:=I;
        end;
        if (Pixels<=RasterPixels) or (Oldest<0) then Break;
        FreeRaster(Oldest);
      until False;
      Rasters[Slot].Glyph:=Self; Rasters[Slot].W:=W; Rasters[Slot].H:=H;
      Rasters[Slot].PixelsPerEm:=PixelsPerEm;
      Rasters[Slot].Color:=ActualColor; Rasters[Slot].Stamp:=Clock;
      Rasters[Slot].Picture:=Picture; Rasters[Slot].Surface:=Surface; Picture:=nil; Surface:=nil;
    end;
  finally Surface.Free; Picture.Free; Stream.Free; Writer.Free; Image.Free; end;
end;
var I:Integer;
initialization
  Faces:=TStringList.Create;
finalization
  ClearNativeTeXGlyphCache;
  for I:=0 to Faces.Count-1 do Faces.Objects[I].Free;
  Faces.Free;
  if Engine<>nil then API.Done(Engine);
  if LibraryHandle<>NilHandle then UnloadLibrary(LibraryHandle);
end.
