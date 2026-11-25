unit VectorPreview;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Dynlibs, Graphics, Types;
type
  ITransparentVectorDocument=interface
    ['{62E9CD9D-9C68-47A0-B767-854CD8203903}']
    function RenderTransparent(Page,Width,Height:Integer; const Region:TRect; Picture:TPicture):Boolean;
  end;
  TVectorImageBounds=record Left,Top,Right,Bottom:Double; end;
  TVectorImageRegions=array of TVectorImageBounds;
  TVectorLink=record Bounds:TVectorImageBounds; URI,Destination:string; Page:Integer; Top:Double; end;
  TVectorLinks=array of TVectorLink;
  IVectorDocument=interface
    ['{E76B459F-C164-4F3F-896B-7C30E432AF18}']
    function Render(Page,Width,Height:Integer; Picture:TPicture):Boolean;
    function RenderRegion(Page,Width,Height:Integer; const Region:TRect; Picture:TPicture):Boolean;
    function PageSize(Page:Integer; out Width,Height:Double):Boolean;
    function ImageRegions(Page:Integer):TVectorImageRegions;
    function FindText(Page:Integer; const Text:string):TVectorImageRegions;
    function TextLayout(Page:Integer; out Text:string):TVectorImageRegions;
    function PageLinks(Page:Integer):TVectorLinks;
  end;
  IPagedVectorDocument=interface
    ['{78F5E3D4-1902-4A1C-BBD2-1ED5DD520CCA}']
    function PageCount:Integer;
  end;
function OpenVectorDocument(const FileName:string):IVectorDocument;
function VectorPageCount(const Document:IVectorDocument):Integer;
function VectorPDFSupported:Boolean;
function VectorSVGSupported:Boolean;
function RenderSVG(const Source:string; Width,Height:Integer; Picture:TPicture):Boolean;
implementation
uses PlatformLibraries, Math, IntfGraphics, GraphType;
type TRsvgRectangle=record X,Y,Width,Height:Double; end;
     TRsvgDimensions=record Width,Height:Integer; Em,Ex:Double; end;
     TWritePNG=function(Closure,Data:Pointer; Length:Cardinal):Integer; cdecl;
     PImageList=^TImageList;
     TImageList=record Data:Pointer; Next,Previous:PImageList; end;
     PImageMapping=^TImageMapping;
     TImageMapping=record X1,Y1,X2,Y2:Double; ImageID:LongInt; end;
     PPDFDest=^TPDFDest;
     TPDFDest=record Kind,Page:LongInt; Left,Bottom,Right,Top,Zoom:Double; Name:PChar; Flags:Cardinal; end;
     PPDFAction=^TPDFAction;
     TPDFAction=record Kind:LongInt; Title:PChar; Data:Pointer; end;
     PPDFLink=^TPDFLink;
     TPDFLink=record Bounds:TVectorImageBounds; Action:PPDFAction; end;
var
  PopplerHandle,CairoHandle,GLibHandle,GObjectHandle,SVGHandle:TLibHandle;
  rsvg_handle_render_document:function(Handle,Context:Pointer; var Viewport:TRsvgRectangle; Error:PPointer):LongBool; cdecl;
  rsvg_handle_new_from_data:function(Data:PChar; Size:PtrUInt; Error:PPointer):Pointer; cdecl;
  rsvg_handle_get_dimensions:procedure(Handle:Pointer; var Dimensions:TRsvgDimensions); cdecl;
  rsvg_handle_render_cairo:function(Handle,Context:Pointer):LongBool; cdecl;
  g_bytes_new:function(Data:Pointer; Size:PtrUInt):Pointer; cdecl;
g_bytes_unref:procedure(Bytes:Pointer); cdecl;
g_object_unref:procedure(Obj:Pointer); cdecl;
g_error_free:procedure(Error:Pointer); cdecl;
poppler_document_new_from_bytes:function(Bytes:Pointer; Password:PChar; Error:PPointer):Pointer; cdecl;
poppler_document_get_page:function(Doc:Pointer; Index:Integer):Pointer; cdecl;
poppler_document_get_n_pages:function(Doc:Pointer):Integer; cdecl;
poppler_page_get_size:procedure(Page:Pointer; W,H:PDouble); cdecl;
poppler_page_render:procedure(Page,Context:Pointer); cdecl;
poppler_page_get_image_mapping:function(Page:Pointer):PImageList; cdecl;
poppler_page_free_image_mapping:procedure(List:PImageList); cdecl;
poppler_page_find_text:function(Page:Pointer; Text:PChar):PImageList; cdecl;
poppler_rectangle_free:procedure(Rectangle:Pointer); cdecl;
g_list_free:procedure(List:PImageList); cdecl;
g_free:procedure(Data:Pointer); cdecl;
poppler_page_get_text:function(Page:Pointer):PChar; cdecl;
poppler_page_get_text_layout:function(Page:Pointer; Rectangles:PPointer; Count:PCardinal):LongBool; cdecl;
poppler_page_get_link_mapping:function(Page:Pointer):PImageList; cdecl;
poppler_page_free_link_mapping:procedure(List:PImageList); cdecl;
poppler_document_find_dest:function(Document:Pointer; Name:PChar):PPDFDest; cdecl;
poppler_dest_free:procedure(Destination:PPDFDest); cdecl;
cairo_image_surface_create:function(Format,W,H:Integer):Pointer; cdecl;
cairo_create:function(Surface:Pointer):Pointer; cdecl;
cairo_destroy:procedure(Context:Pointer); cdecl;
cairo_surface_destroy:procedure(Surface:Pointer); cdecl;
cairo_surface_flush:procedure(Surface:Pointer); cdecl;
cairo_image_surface_get_data:function(Surface:Pointer):PByte; cdecl;
cairo_image_surface_get_stride:function(Surface:Pointer):Integer; cdecl;
cairo_set_source_rgb:procedure(Context:Pointer; R,G,B:Double); cdecl;
cairo_paint:procedure(Context:Pointer); cdecl;
cairo_scale:procedure(Context:Pointer; X,Y:Double); cdecl;
cairo_translate:procedure(Context:Pointer; X,Y:Double); cdecl;
cairo_surface_write_to_png_stream:function(Surface:Pointer; Writer:TWritePNG; Closure:Pointer):Integer; cdecl;
var SVGInitialized,PDFInitialized:Boolean;
procedure EnsureVectorLibraries(ForSVG:Boolean); forward;
type TVectorDocument=class(TInterfacedObject,IVectorDocument,ITransparentVectorDocument,IPagedVectorDocument)
  Document:Pointer;
  destructor Destroy; override;
  function Render(Page,Width,Height:Integer; Picture:TPicture):Boolean;
  function RenderRegion(Page,Width,Height:Integer; const Region:TRect; Picture:TPicture):Boolean;
  function RenderTransparent(Page,Width,Height:Integer; const Region:TRect; Picture:TPicture):Boolean;
  function PaintRegion(Page,Width,Height:Integer; const Region:TRect; Picture:TPicture; Opaque:Boolean):Boolean;
  function PageSize(Page:Integer; out Width,Height:Double):Boolean;
  function PageCount:Integer;
  function ImageRegions(Page:Integer):TVectorImageRegions;
  function FindText(Page:Integer; const Text:string):TVectorImageRegions;
  function TextLayout(Page:Integer; out Text:string):TVectorImageRegions;
  function PageLinks(Page:Integer):TVectorLinks;
end;
function VectorPageCount(const Document:IVectorDocument):Integer;
var Pages:IPagedVectorDocument; W,H:Double;
begin
  Result:=0; if Document=nil then Exit;
  if Supports(Document,IPagedVectorDocument,Pages) then Exit(Max(0,Pages.PageCount));
  while (Result<4096) and Document.PageSize(Result+1,W,H) do Inc(Result);
end;
function TVectorDocument.PageCount:Integer;
var W,H:Double;
begin
  if Assigned(poppler_document_get_n_pages) then Exit(poppler_document_get_n_pages(Document));
  Result:=0; while (Result<4096) and PageSize(Result+1,W,H) do Inc(Result);
end;
function TVectorDocument.TextLayout(Page:Integer; out Text:string):TVectorImageRegions;
var P,Data:Pointer; UTF8:PChar; Count,I:Cardinal; W,H:Double; R:^TVectorImageBounds;
begin
  Result:=nil; Text:='';
  if not Assigned(poppler_page_get_text) or not Assigned(poppler_page_get_text_layout) or not Assigned(g_free) then Exit;
  P:=poppler_document_get_page(Document,Page-1); if P=nil then Exit; Data:=nil; UTF8:=nil;
  try
    UTF8:=poppler_page_get_text(P); if UTF8<>nil then Text:=UTF8;
    poppler_page_get_size(P,@W,@H); if (W<=0) or (H<=0) then Exit;
    Count:=0; if not poppler_page_get_text_layout(P,@Data,@Count) or (Count=0) then Exit;
    SetLength(Result,Count); R:=Data;
    for I:=0 to Count-1 do begin
      Result[I].Left:=R^.Left/W; Result[I].Right:=R^.Right/W;
      Result[I].Top:=R^.Top/H; Result[I].Bottom:=R^.Bottom/H; Inc(R);
    end;
  finally g_free(Data); g_free(UTF8); g_object_unref(P); end;
end;
function TVectorDocument.PageLinks(Page:Integer):TVectorLinks;
var P:Pointer; List,Item:PImageList; Mapping:PPDFLink; Destination,Resolved:PPDFDest; Link:TVectorLink; W,H:Double; I:Integer;
begin
  Result:=nil;
  if not Assigned(poppler_page_get_link_mapping) or not Assigned(poppler_page_free_link_mapping) then Exit;
  P:=poppler_document_get_page(Document,Page-1); if P=nil then Exit; List:=nil;
  try
    poppler_page_get_size(P,@W,@H); if (W<=0) or (H<=0) then Exit;
    List:=poppler_page_get_link_mapping(P); Item:=List;
    while Item<>nil do begin
      Mapping:=Item^.Data; Item:=Item^.Next; if (Mapping=nil) or (Mapping^.Action=nil) then Continue;
      Link:=Default(TVectorLink); Link.Page:=-1;
      Link.Bounds.Left:=Mapping^.Bounds.Left/W; Link.Bounds.Right:=Mapping^.Bounds.Right/W;
      Link.Bounds.Top:=1-Mapping^.Bounds.Bottom/H; Link.Bounds.Bottom:=1-Mapping^.Bounds.Top/H;
      if Mapping^.Action^.Kind=5 then begin if Mapping^.Action^.Data<>nil then Link.URI:=PChar(Mapping^.Action^.Data); end
      else if Mapping^.Action^.Kind=2 then begin
        Destination:=Mapping^.Action^.Data; Resolved:=nil;
        if Destination<>nil then begin
          if (Destination^.Name<>nil) and Assigned(poppler_document_find_dest) and Assigned(poppler_dest_free) then begin
            Link.Destination:=Destination^.Name; Resolved:=poppler_document_find_dest(Document,Destination^.Name);
            if Resolved<>nil then Destination:=Resolved;
          end;
          Link.Page:=Destination^.Page; Link.Top:=Destination^.Top;
        end;
        if Resolved<>nil then poppler_dest_free(Resolved);
      end;
      if (Link.URI='') and (Link.Page<1) and (Link.Destination='') then Continue;
      I:=Length(Result); SetLength(Result,I+1); Result[I]:=Link;
    end;
  finally if List<>nil then poppler_page_free_link_mapping(List); g_object_unref(P); end;
end;
function TVectorDocument.FindText(Page:Integer; const Text:string):TVectorImageRegions;
var P:Pointer; List,Item:PImageList; Bounds:^TVectorImageBounds; W,H:Double; I:Integer;
begin
  Result:=nil;
  if (Text='') or not Assigned(poppler_page_find_text) or not Assigned(poppler_rectangle_free) or not Assigned(g_list_free) then Exit;
  P:=poppler_document_get_page(Document,Page-1); if P=nil then Exit; List:=nil;
  try
    poppler_page_get_size(P,@W,@H); if (W<=0) or (H<=0) then Exit;
    List:=poppler_page_find_text(P,PChar(Text)); Item:=List;
    while Item<>nil do begin
      Bounds:=Item^.Data;
      if Bounds<>nil then begin
        I:=Length(Result); SetLength(Result,I+1);
        Result[I].Left:=Min(Bounds^.Left,Bounds^.Right)/W; Result[I].Right:=Max(Bounds^.Left,Bounds^.Right)/W;
        { Text search uses PDF's bottom-left coordinates. }
        Result[I].Top:=1-Max(Bounds^.Top,Bounds^.Bottom)/H; Result[I].Bottom:=1-Min(Bounds^.Top,Bounds^.Bottom)/H;
      end;
      Item:=Item^.Next;
    end;
  finally
    Item:=List;
    while Item<>nil do begin if Item^.Data<>nil then poppler_rectangle_free(Item^.Data); Item:=Item^.Next; end;
    if List<>nil then g_list_free(List); g_object_unref(P);
  end;
end;
function TVectorDocument.ImageRegions(Page:Integer):TVectorImageRegions;
var P:Pointer; List,Item:PImageList; Image:PImageMapping; W,H:Double; I:Integer;
begin
  Result:=nil;
  if not Assigned(poppler_page_get_image_mapping) or not Assigned(poppler_page_free_image_mapping) then Exit;
  P:=poppler_document_get_page(Document,Page-1); if P=nil then Exit;
  List:=nil;
  try
    poppler_page_get_size(P,@W,@H); if (W<=0) or (H<=0) then Exit;
    List:=poppler_page_get_image_mapping(P); Item:=List;
    while Item<>nil do begin
      Image:=PImageMapping(Item^.Data);
      if Image<>nil then begin
        I:=Length(Result); SetLength(Result,I+1);
        { Poppler's image mapping uses the rendered page's top-left origin. }
        Result[I].Left:=Min(Image^.X1,Image^.X2)/W; Result[I].Right:=Max(Image^.X1,Image^.X2)/W;
        Result[I].Top:=Min(Image^.Y1,Image^.Y2)/H; Result[I].Bottom:=Max(Image^.Y1,Image^.Y2)/H;
      end;
      Item:=Item^.Next;
    end;
  finally if List<>nil then poppler_page_free_image_mapping(List); g_object_unref(P); end;
end;
function WritePNG(Closure,Data:Pointer; Length:Cardinal):Integer; cdecl;
begin
  try TStream(Closure).WriteBuffer(Data^,Length); Result:=0;
  except Result:=11; end;
end;
function SurfacePicture(Surface:Pointer; Width,Height:Integer; Picture:TPicture):Boolean;
var Stream:TMemoryStream;
    {$IFNDEF LCLgtk3}Raw:TRawImage; Image:TLazIntfImage; Data,Dest:PByte;
    Pixel:PLongWord; Value:LongWord; X,Y,Stride,Alpha:Integer;{$ENDIF}
begin
  {$IFNDEF LCLgtk3}
  if Assigned(cairo_surface_flush) and Assigned(cairo_image_surface_get_data) and
     Assigned(cairo_image_surface_get_stride) then begin
    cairo_surface_flush(Surface); Data:=cairo_image_surface_get_data(Surface);
    Stride:=cairo_image_surface_get_stride(Surface);
    if (Data=nil) or (Stride<Width*4) then Exit(False);
    Raw.Init; Raw.Description.Init_BPP32_B8G8R8A8_BIO_TTB(Width,Height); Raw.CreateData(False);
    try
      { Cairo stores premultiplied native-endian ARGB. LCL needs straight
        alpha; transfer pixels directly without a PNG encode/decode roundtrip. }
      Dest:=Raw.Data;
      for Y:=0 to Height-1 do begin
        Pixel:=PLongWord(Data+Y*Stride);
        for X:=0 to Width-1 do begin
          Value:=Pixel^; Inc(Pixel); Alpha:=Value shr 24; Dest[3]:=Alpha;
          if (Alpha=0) or (Alpha=255) then begin
            Dest[0]:=Value and 255; Dest[1]:=(Value shr 8) and 255; Dest[2]:=(Value shr 16) and 255;
          end else begin
            Dest[0]:=((Value and 255)*255+Alpha div 2) div Alpha;
            Dest[1]:=(((Value shr 8) and 255)*255+Alpha div 2) div Alpha;
            Dest[2]:=(((Value shr 16) and 255)*255+Alpha div 2) div Alpha;
          end;
          Inc(Dest,4);
        end;
      end;
      Image:=TLazIntfImage.Create(Raw,False);
      try Picture.Bitmap.LoadFromIntfImage(Image); finally Image.Free; end;
      Exit(True);
    finally Raw.FreeData; end;
  end;
  {$ENDIF}
  { GTK3's native bitmap alpha handling still needs the encoded path. }
  Stream:=TMemoryStream.Create;
  try
    Result:=cairo_surface_write_to_png_stream(Surface,@WritePNG,Stream)=0;
    if Result then begin Stream.Position:=0; Picture.LoadFromStream(Stream); end;
  finally Stream.Free; end;
end;
destructor TVectorDocument.Destroy;
begin if Document<>nil then g_object_unref(Document); inherited Destroy; end;
function TVectorDocument.Render(Page,Width,Height:Integer; Picture:TPicture):Boolean;
begin Result:=RenderRegion(Page,Width,Height,Rect(0,0,Width,Height),Picture); end;
function TVectorDocument.RenderRegion(Page,Width,Height:Integer; const Region:TRect; Picture:TPicture):Boolean;
begin Result:=PaintRegion(Page,Width,Height,Region,Picture,True); end;
function TVectorDocument.RenderTransparent(Page,Width,Height:Integer; const Region:TRect; Picture:TPicture):Boolean;
begin Result:=PaintRegion(Page,Width,Height,Region,Picture,False); end;
function TVectorDocument.PaintRegion(Page,Width,Height:Integer; const Region:TRect; Picture:TPicture; Opaque:Boolean):Boolean;
var P,Surface,Context:Pointer; W,H:Double;
begin
  Result:=False;
  if (Width<1) or (Height<1) or (Region.Width<1) or (Region.Height<1) or
     (Int64(Region.Width)*Region.Height>64000000) or not Assigned(cairo_translate) then Exit;
  P:=poppler_document_get_page(Document,Page-1); if P=nil then Exit;
  Surface:=nil; Context:=nil;
  try
    poppler_page_get_size(P,@W,@H); if (W<=0) or (H<=0) then Exit;
    Surface:=cairo_image_surface_create(0,Region.Width,Region.Height); Context:=cairo_create(Surface);
    if Opaque then begin cairo_set_source_rgb(Context,1,1,1); cairo_paint(Context); end;
    cairo_translate(Context,-Region.Left,-Region.Top);
    cairo_scale(Context,Width/W,Height/H); poppler_page_render(P,Context);
    Result:=SurfacePicture(Surface,Region.Width,Region.Height,Picture);
  finally
    if Context<>nil then cairo_destroy(Context);
    if Surface<>nil then cairo_surface_destroy(Surface);
    g_object_unref(P);
  end;
end;
function TVectorDocument.PageSize(Page:Integer; out Width,Height:Double):Boolean;
var P:Pointer;
begin
  Result:=False; Width:=0; Height:=0;
  if (Page<1) or (Assigned(poppler_document_get_n_pages) and (Page>poppler_document_get_n_pages(Document))) then Exit;
  P:=poppler_document_get_page(Document,Page-1); if P=nil then Exit;
  try poppler_page_get_size(P,@Width,@Height); Result:=(Width>0) and (Height>0); finally g_object_unref(P); end;
end;
function VectorSVGSupported:Boolean;
begin
  EnsureVectorLibraries(True);
  Result:=Assigned(rsvg_handle_new_from_data) and Assigned(rsvg_handle_render_cairo) and
    Assigned(rsvg_handle_get_dimensions) and Assigned(cairo_create) and Assigned(g_object_unref);
end;
function VectorPDFSupported:Boolean;
begin
  EnsureVectorLibraries(False);
  Result:=Assigned(poppler_document_new_from_bytes) and Assigned(cairo_create) and
    Assigned(g_bytes_new) and Assigned(g_object_unref);
end;
function OpenVectorDocument(const FileName:string):IVectorDocument;
var Stream:TMemoryStream; Bytes,Error:Pointer; Doc:TVectorDocument;
begin
  Result:=nil; EnsureVectorLibraries(False);
  if not Assigned(poppler_document_new_from_bytes) or not Assigned(cairo_create) or
     not Assigned(g_bytes_new) or not Assigned(g_object_unref) then Exit;
  Stream:=TMemoryStream.Create; Doc:=TVectorDocument.Create;
  try
    try
    Stream.LoadFromFile(FileName); Bytes:=g_bytes_new(Stream.Memory,Stream.Size); Error:=nil;
    try Doc.Document:=poppler_document_new_from_bytes(Bytes,nil,@Error);
    finally g_bytes_unref(Bytes); end;
    if Error<>nil then g_error_free(Error);
    if Doc.Document<>nil then begin Result:=Doc; Doc:=nil; end;
    except Result:=nil; end;
  finally Doc.Free; Stream.Free; end;
end;
function RenderSVG(const Source:string; Width,Height:Integer; Picture:TPicture):Boolean;
var Handle,Error,Surface,Context:Pointer; D:TRsvgDimensions; Viewport:TRsvgRectangle;
begin
  Result:=False;
  if not VectorSVGSupported or (Width<1) or (Height<1) or
     (Int64(Width)*Height>64000000) then Exit;
  Error:=nil; Handle:=rsvg_handle_new_from_data(PChar(Source),Length(Source),@Error);
  if Error<>nil then g_error_free(Error);
  if Handle=nil then Exit;
  Surface:=nil; Context:=nil;
  try
    rsvg_handle_get_dimensions(Handle,D); if (D.Width<1) or (D.Height<1) then Exit;
    Surface:=cairo_image_surface_create(0,Width,Height); Context:=cairo_create(Surface);
    if Assigned(rsvg_handle_render_document) then begin
      Viewport.X:=0; Viewport.Y:=0; Viewport.Width:=Width; Viewport.Height:=Height; Error:=nil;
      Result:=rsvg_handle_render_document(Handle,Context,Viewport,@Error);
      if Error<>nil then g_error_free(Error); if not Result then Exit;
    end else begin
      cairo_scale(Context,Width/D.Width,Height/D.Height);
      if not rsvg_handle_render_cairo(Handle,Context) then Exit;
    end;
    Result:=SurfacePicture(Surface,Width,Height,Picture);
  finally
    if Context<>nil then cairo_destroy(Context);
    if Surface<>nil then cairo_surface_destroy(Surface);
    g_object_unref(Handle);
  end;
end;
procedure EnsureVectorLibraries(ForSVG:Boolean);
begin
  if not ForSVG and (GetEnvironmentVariable('PASTEX_DISABLE_PDF')='1') then Exit;
  if ForSVG then begin if SVGInitialized then Exit; SVGInitialized:=True; end
  else begin if PDFInitialized then Exit; PDFInitialized:=True; end;
  {$IFDEF MSWINDOWS}
  if ForSVG then SVGHandle:=LoadOptionalLibrary(['librsvg-2-2.dll','rsvg-2.dll']);
  if not ForSVG then PopplerHandle:=LoadOptionalLibrary(['libpoppler-glib-8.dll','poppler-glib.dll']);
  if CairoHandle=NilHandle then CairoHandle:=LoadOptionalLibrary(['libcairo-2.dll','cairo.dll']);
  if GLibHandle=NilHandle then GLibHandle:=LoadOptionalLibrary(['libglib-2.0-0.dll','glib-2.0.dll']);
  if GObjectHandle=NilHandle then GObjectHandle:=LoadOptionalLibrary(['libgobject-2.0-0.dll','gobject-2.0.dll']);
  {$ELSE}{$IFDEF DARWIN}
  if ForSVG then SVGHandle:=LoadOptionalLibrary(['librsvg-2.2.dylib','librsvg-2.dylib']);
  if not ForSVG then PopplerHandle:=LoadOptionalLibrary(['libpoppler-glib.8.dylib','libpoppler-glib.dylib']);
  if CairoHandle=NilHandle then CairoHandle:=LoadOptionalLibrary(['libcairo.2.dylib','libcairo.dylib']);
  if GLibHandle=NilHandle then GLibHandle:=LoadOptionalLibrary(['libglib-2.0.0.dylib','libglib-2.0.dylib']);
  if GObjectHandle=NilHandle then GObjectHandle:=LoadOptionalLibrary(['libgobject-2.0.0.dylib','libgobject-2.0.dylib']);
  {$ELSE}
  if ForSVG then SVGHandle:=LoadOptionalLibrary(['librsvg-2.so.2']);
  if not ForSVG then PopplerHandle:=LoadOptionalLibrary(['libpoppler-glib.so.8']);
  if CairoHandle=NilHandle then CairoHandle:=LoadOptionalLibrary(['libcairo.so.2']);
  if GLibHandle=NilHandle then GLibHandle:=LoadOptionalLibrary(['libglib-2.0.so.0']);
  if GObjectHandle=NilHandle then GObjectHandle:=LoadOptionalLibrary(['libgobject-2.0.so.0']);
  {$ENDIF}{$ENDIF}
  Pointer(rsvg_handle_render_document):=GetProcedureAddress(SVGHandle,'rsvg_handle_render_document');
  Pointer(rsvg_handle_new_from_data):=GetProcedureAddress(SVGHandle,'rsvg_handle_new_from_data');
  Pointer(rsvg_handle_get_dimensions):=GetProcedureAddress(SVGHandle,'rsvg_handle_get_dimensions');
  Pointer(rsvg_handle_render_cairo):=GetProcedureAddress(SVGHandle,'rsvg_handle_render_cairo');
  Pointer(g_bytes_new):=GetProcedureAddress(GLibHandle,'g_bytes_new');
  Pointer(g_bytes_unref):=GetProcedureAddress(GLibHandle,'g_bytes_unref');
  Pointer(g_object_unref):=GetProcedureAddress(GObjectHandle,'g_object_unref');
  Pointer(g_error_free):=GetProcedureAddress(GLibHandle,'g_error_free');
  Pointer(poppler_document_new_from_bytes):=GetProcedureAddress(PopplerHandle,'poppler_document_new_from_bytes');
  Pointer(poppler_document_get_page):=GetProcedureAddress(PopplerHandle,'poppler_document_get_page');
  Pointer(poppler_document_get_n_pages):=GetProcedureAddress(PopplerHandle,'poppler_document_get_n_pages');
  Pointer(poppler_page_get_size):=GetProcedureAddress(PopplerHandle,'poppler_page_get_size');
  Pointer(poppler_page_render):=GetProcedureAddress(PopplerHandle,'poppler_page_render');
  Pointer(poppler_page_get_image_mapping):=GetProcedureAddress(PopplerHandle,'poppler_page_get_image_mapping');
  Pointer(poppler_page_free_image_mapping):=GetProcedureAddress(PopplerHandle,'poppler_page_free_image_mapping');
  Pointer(poppler_page_find_text):=GetProcedureAddress(PopplerHandle,'poppler_page_find_text');
  Pointer(poppler_rectangle_free):=GetProcedureAddress(PopplerHandle,'poppler_rectangle_free');
  Pointer(g_list_free):=GetProcedureAddress(GLibHandle,'g_list_free');
  Pointer(g_free):=GetProcedureAddress(GLibHandle,'g_free');
  Pointer(poppler_page_get_text):=GetProcedureAddress(PopplerHandle,'poppler_page_get_text');
  Pointer(poppler_page_get_text_layout):=GetProcedureAddress(PopplerHandle,'poppler_page_get_text_layout');
  Pointer(poppler_page_get_link_mapping):=GetProcedureAddress(PopplerHandle,'poppler_page_get_link_mapping');
  Pointer(poppler_page_free_link_mapping):=GetProcedureAddress(PopplerHandle,'poppler_page_free_link_mapping');
  Pointer(poppler_document_find_dest):=GetProcedureAddress(PopplerHandle,'poppler_document_find_dest');
  Pointer(poppler_dest_free):=GetProcedureAddress(PopplerHandle,'poppler_dest_free');
  Pointer(cairo_image_surface_create):=GetProcedureAddress(CairoHandle,'cairo_image_surface_create');
  Pointer(cairo_create):=GetProcedureAddress(CairoHandle,'cairo_create');
  Pointer(cairo_destroy):=GetProcedureAddress(CairoHandle,'cairo_destroy');
  Pointer(cairo_surface_destroy):=GetProcedureAddress(CairoHandle,'cairo_surface_destroy');
  Pointer(cairo_surface_flush):=GetProcedureAddress(CairoHandle,'cairo_surface_flush');
  Pointer(cairo_image_surface_get_data):=GetProcedureAddress(CairoHandle,'cairo_image_surface_get_data');
  Pointer(cairo_image_surface_get_stride):=GetProcedureAddress(CairoHandle,'cairo_image_surface_get_stride');
  Pointer(cairo_set_source_rgb):=GetProcedureAddress(CairoHandle,'cairo_set_source_rgb');
  Pointer(cairo_paint):=GetProcedureAddress(CairoHandle,'cairo_paint');
  Pointer(cairo_scale):=GetProcedureAddress(CairoHandle,'cairo_scale');
  Pointer(cairo_translate):=GetProcedureAddress(CairoHandle,'cairo_translate');
  Pointer(cairo_surface_write_to_png_stream):=GetProcedureAddress(CairoHandle,'cairo_surface_write_to_png_stream');
{ Keep these library references until process exit: Forms finalization can
  release preview controls after this unit has finalized. Unloading Poppler
  earlier leaves live GObject destructors pointing into an unloaded library. }
end;
end.
