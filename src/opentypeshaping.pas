unit OpenTypeShaping;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$packrecords c}{$pointermath on}
interface
uses TeXFontData;
function ShapeOpenType(const FileName,Text,Features:string):TTeXTextRun;
function OpenTypeShapingAvailable:Boolean;
function OpenTypeShapingFaceCount:Integer;
implementation
uses Classes, SysUtils, Math, Dynlibs, PlatformLibraries, TeXUnicode;
type
  THBInfo=record Code,Mask,Cluster,Reserved1,Reserved2:LongWord; end;
  PHBInfo=^THBInfo;
  THBPosition=record AdvanceX,AdvanceY,OffsetX,OffsetY:LongInt; Reserved:LongWord; end;
  PHBPosition=^THBPosition;
  THBExtent=record X,Y,W,H:LongInt; end;
  THBFeature=record Tag,Value,First,Last:LongWord; end;
  TShapeFace=class
    Font:Pointer;
    Units:LongWord;
    destructor Destroy; override;
  end;
var LibraryHandle:TLibHandle; Loaded,Ready:Boolean; Faces:TStringList;
    BlobFile:function(Name:PChar):Pointer; cdecl;
    BlobData:function(Data:Pointer; Count,Mode:LongWord; User,Destroy:Pointer):Pointer; cdecl;
    BlobDestroy,FaceDestroy,FontDestroy,BufferDestroy:procedure(Value:Pointer); cdecl;
    FaceCreate:function(Blob:Pointer; Index:LongWord):Pointer; cdecl;
    FaceUnits,FaceGlyphs:function(Face:Pointer):LongWord; cdecl;
    FontCreate:function(Face:Pointer):Pointer; cdecl;
    FontFuncs:procedure(Font:Pointer); cdecl;
    FontScale:procedure(Font:Pointer; X,Y:LongInt); cdecl;
    GlyphExtents:function(Font:Pointer; Code:LongWord; out Extent:THBExtent):LongInt; cdecl;
    BufferCreate:function:Pointer; cdecl;
    BufferAdd:procedure(Buffer:Pointer; Code,Cluster:LongWord); cdecl;
    BufferType,BufferDirection,BufferClusters:procedure(Buffer:Pointer; Value:LongWord); cdecl;
    BufferGuess:procedure(Buffer:Pointer); cdecl;
    Shape:procedure(Font,Buffer,Features:Pointer; Count:LongWord); cdecl;
    GetInfos:function(Buffer:Pointer; out Count:LongWord):PHBInfo; cdecl;
    GetPositions:function(Buffer:Pointer; out Count:LongWord):PHBPosition; cdecl;
    ReadFeature:function(Text:PChar; Count:LongInt; out Feature:THBFeature):LongInt; cdecl;
destructor TShapeFace.Destroy;
begin if Font<>nil then FontDestroy(Font); inherited Destroy; end;
function OpenTypeShapingAvailable:Boolean;
  procedure Bind(var Proc; const Name:string);
  begin Pointer(Proc):=GetProcedureAddress(LibraryHandle,Name); if Pointer(Proc)=nil then Ready:=False; end;
begin
  if Loaded then Exit(Ready); Loaded:=True;
  {$IFDEF MSWINDOWS}LibraryHandle:=LoadOptionalLibrary(['libharfbuzz-0.dll','harfbuzz.dll']);
  {$ELSE}{$IFDEF DARWIN}LibraryHandle:=LoadOptionalLibrary(['libharfbuzz.0.dylib','libharfbuzz.dylib']);
  {$ELSE}LibraryHandle:=LoadOptionalLibrary(['libharfbuzz.so.0','libharfbuzz.so']);{$ENDIF}{$ENDIF}
  if LibraryHandle=NilHandle then Exit(False); Ready:=True;
  Pointer(BlobFile):=GetProcedureAddress(LibraryHandle,'hb_blob_create_from_file_or_fail');
  Bind(BlobData,'hb_blob_create'); Bind(BlobDestroy,'hb_blob_destroy');
  Bind(FaceCreate,'hb_face_create'); Bind(FaceDestroy,'hb_face_destroy'); Bind(FaceUnits,'hb_face_get_upem');
  Bind(FaceGlyphs,'hb_face_get_glyph_count');
  Bind(FontCreate,'hb_font_create'); Bind(FontDestroy,'hb_font_destroy'); Bind(FontFuncs,'hb_ot_font_set_funcs');
  Bind(FontScale,'hb_font_set_scale'); Bind(GlyphExtents,'hb_font_get_glyph_extents');
  Bind(BufferCreate,'hb_buffer_create'); Bind(BufferDestroy,'hb_buffer_destroy'); Bind(BufferAdd,'hb_buffer_add');
  Bind(BufferType,'hb_buffer_set_content_type'); Bind(BufferDirection,'hb_buffer_set_direction');
  Bind(BufferClusters,'hb_buffer_set_cluster_level'); Bind(BufferGuess,'hb_buffer_guess_segment_properties');
  Bind(Shape,'hb_shape'); Bind(GetInfos,'hb_buffer_get_glyph_infos'); Bind(GetPositions,'hb_buffer_get_glyph_positions');
  Bind(ReadFeature,'hb_feature_from_string'); Result:=Ready;
end;
function FontFace(const Name:string):TShapeFace;
var I:Integer; Blob,Face:Pointer; Stream:TMemoryStream;
begin
  Result:=nil; if not OpenTypeShapingAvailable then Exit;
  I:=Faces.IndexOf(Name);
  if I>=0 then begin Result:=TShapeFace(Faces.Objects[I]); Faces.Move(I,Faces.Count-1); Exit; end;
  Blob:=nil; Face:=nil; Stream:=nil;
  try
    if Assigned(BlobFile) then Blob:=BlobFile(PChar(Name));
    if Blob=nil then begin
      { Unicode file paths on systems whose C file loader cannot open them. }
      Stream:=TMemoryStream.Create;
      try Stream.LoadFromFile(Name); except on E:EStreamError do Exit; end;
      if (Stream.Size=0) or (Stream.Size>32*1024*1024) then Exit;
      Blob:=BlobData(Stream.Memory,Stream.Size,0,nil,nil);
    end;
    if Blob=nil then Exit; Face:=FaceCreate(Blob,0); if (Face=nil) or (FaceGlyphs(Face)=0) then Exit;
    Result:=TShapeFace.Create; Result.Units:=FaceUnits(Face); Result.Font:=FontCreate(Face);
    if (Result.Font=nil) or (Result.Units=0) then begin FreeAndNil(Result); Exit; end;
    { XeTeX shapes in design units with device adjustments disabled. }
    FontFuncs(Result.Font); FontScale(Result.Font,Result.Units,Result.Units);
    if Faces.Count>=8 then begin Faces.Objects[0].Free; Faces.Delete(0); end;
    Faces.AddObject(Name,Result);
  finally if Face<>nil then FaceDestroy(Face); if Blob<>nil then BlobDestroy(Blob); Stream.Free; end;
end;
function ShapeOpenType(const FileName,Text,Features:string):TTeXTextRun;
var Face:TShapeFace; Buffer:Pointer; Info:PHBInfo; Positions:PHBPosition; Extent:THBExtent;
    Feature:THBFeature; Specs:array of THBFeature; Parts:TStringList; Spec:string;
    N,Count,Code:LongWord; P,I,J,K,First,Last,Characters,Consumed:Integer; Pen,Start:Double; TeXLigatures:Boolean;
begin
  Result:=Default(TTeXTextRun); if (FileName='') or (Text='') then Exit;
  Face:=FontFace(FileName); if Face=nil then Exit; Buffer:=BufferCreate(); if Buffer=nil then Exit;
  Parts:=TStringList.Create;
  try
    Specs:=nil; Parts.StrictDelimiter:=True; Parts.Delimiter:=','; Parts.DelimitedText:=Features;
    TeXLigatures:=Parts.IndexOf('tlig=1')>=0;
    for Spec in Parts do if ReadFeature(PChar(Spec),Length(Spec),Feature)<>0 then begin
      I:=Length(Specs); SetLength(Specs,I+1); Specs[I]:=Feature;
    end;
    P:=1; Characters:=0; BufferType(Buffer,1); BufferDirection(Buffer,4); BufferClusters(Buffer,1);
    while P<=Length(Text) do begin
      Code:=NextUTF8CodePoint(Text,P); Consumed:=1;
      if TeXLigatures then case Code of
        45:if Copy(Text,P,1)='-' then begin
          Inc(P); Inc(Consumed); Code:=$2013;
          if Copy(Text,P,1)='-' then begin Inc(P); Inc(Consumed); Code:=$2014; end;
        end;
        96,39:begin
          if Copy(Text,P,1)=Chr(Code) then begin Inc(P); Inc(Consumed); if Code=96 then Code:=$201C else Code:=$201D; end
          else if Code=96 then Code:=$2018 else Code:=$2019;
        end;
      end;
      BufferAdd(Buffer,Code,Characters); Inc(Characters,Consumed);
    end;
    BufferGuess(Buffer); if Length(Specs)=0 then Shape(Face.Font,Buffer,nil,0)
    else Shape(Face.Font,Buffer,@Specs[0],Length(Specs));
    Info:=GetInfos(Buffer,N); Positions:=GetPositions(Buffer,Count);
    if (Info=nil) or (Positions=nil) or (N<>Count) or (N=0) then Exit;
    SetLength(Result.Glyphs,N); SetLength(Result.Stops,Characters+1); I:=0; Pen:=0;
    while I<Integer(N) do begin
      First:=Info[I].Cluster; J:=I+1;
      while (J<Integer(N)) and (Info[J].Cluster=Info[I].Cluster) do Inc(J);
      Last:=Characters; if J<Integer(N) then Last:=Info[J].Cluster;
      if (First<0) or (Last>Characters) or (Last<=First) then Exit(Default(TTeXTextRun));
      Start:=Pen;
      for K:=I to J-1 do begin
        if Info[K].Code=0 then Exit(Default(TTeXTextRun));
        with Result.Glyphs[K] do begin
          Code:=-Integer(Info[K].Code)-1; First:=Info[K].Cluster; Count:=0;
          X:=Pen+Positions[K].OffsetX/Face.Units; Y:=Positions[K].OffsetY/Face.Units;
          Advance:=Positions[K].AdvanceX/Face.Units; Pen:=Pen+Advance;
          if GlyphExtents(Face.Font,Info[K].Code,Extent)<>0 then begin
            Result.Height:=Max(Result.Height,Y+Extent.Y/Face.Units);
            Result.Depth:=Max(Result.Depth,-Y-(Extent.Y+Extent.H)/Face.Units);
            if (Extent.W=0) or (Extent.H=0) then Code:=32;
          end;
        end;
      end;
      Result.Glyphs[I].Count:=Last-First;
      for K:=First to Last do Result.Stops[K]:=Start+(Pen-Start)*(K-First)/(Last-First);
      I:=J;
    end;
    Result.Width:=Pen; Result.Valid:=True;
  finally Parts.Free; BufferDestroy(Buffer); end;
end;
function OpenTypeShapingFaceCount:Integer;
begin Result:=Faces.Count; end;
var I:Integer;
initialization
  Faces:=TStringList.Create; Faces.CaseSensitive:=True;
finalization
  for I:=0 to Faces.Count-1 do Faces.Objects[I].Free;
  Faces.Free; if LibraryHandle<>NilHandle then UnloadLibrary(LibraryHandle);
end.
