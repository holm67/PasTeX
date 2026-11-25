unit DiagramCanvas;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Graphics;
type
  TDiagramCanvas=class
  private
    FSurface,FContext:Pointer;
  public
    constructor Create(Width,Height:Integer; Opaque:Boolean=True);
    destructor Destroy; override;
    function Ready:Boolean;
    procedure BeginPath;
    procedure MoveTo(X,Y:Double);
    procedure LineTo(X,Y:Double);
    procedure CurveTo(X1,Y1,X2,Y2,X3,Y3:Double);
    procedure ClosePath;
    procedure Ellipse(X,Y,RX,RY:Double);
    procedure Paint(Stroke,Fill:TColor; Width:Double; const Dash:array of Double;
      Opacity:Double=1; Cap:Integer=0; Join:Integer=0);
    procedure Arrow(X,Y,Angle,Weight:Double; Color:TColor; const Kind:string; Opacity:Double=1; PixelsPerPoint:Double=1);
    procedure Image(PNG:TStream; X,Y,Width,Height,Angle:Double);
    function MeshPatch(const Coordinates:array of Double; const Colors:array of TColor; Opacity:Double):Boolean;
    function Finish(Picture:TPicture):Boolean;
  end;
procedure DiagramBitmapPNG(Bitmap:TBitmap; Stream:TStream);
function DiagramArrowLineEnd(Weight,PixelsPerPoint:Double; const Kind:string):Double;
implementation
uses SysUtils, Math, Dynlibs, PlatformLibraries, IntfGraphics, GraphType, FPImage, FPWritePNG, TikZModel, TeXStyles, DiagramArrows, PlotColors
  {$IFDEF LCLgtk3}, Gtk3Objects{$ENDIF};
type TPNGWriter=function(Closure,Data:Pointer; Count:Cardinal):Integer; cdecl;
var LibraryHandle:TLibHandle; Loaded,Available,MeshAvailable:Boolean;
  surface_create:function(Format,Width,Height:Integer):Pointer; cdecl;
  context_create:function(Surface:Pointer):Pointer; cdecl;
  context_destroy,surface_destroy:procedure(Value:Pointer); cdecl;
  new_path,close_path,stroke_path,fill_preserve,save,restore,paint_all:procedure(Context:Pointer); cdecl;
  move_to,line_to,translate,scale:procedure(Context:Pointer; X,Y:Double); cdecl;
  curve_to:procedure(Context:Pointer; X1,Y1,X2,Y2,X3,Y3:Double); cdecl;
  arc:procedure(Context:Pointer; X,Y,Radius,A1,A2:Double); cdecl;
  set_source:procedure(Context:Pointer; R,G,B,A:Double); cdecl;
  set_width,rotate:procedure(Context:Pointer; Value:Double); cdecl;
  set_cap,set_join,set_antialias:procedure(Context:Pointer; Value:Integer); cdecl;
  set_dash:procedure(Context:Pointer; Values:PDouble; Count:Integer; Offset:Double); cdecl;
  write_png:function(Surface:Pointer; Writer:TPNGWriter; Closure:Pointer):Integer; cdecl;
  read_png:function(Reader:TPNGWriter; Closure:Pointer):Pointer; cdecl;
  set_surface:procedure(Context,Surface:Pointer; X,Y:Double); cdecl;
  image_width,image_height:function(Surface:Pointer):Integer; cdecl;
  mesh_create:function:Pointer; cdecl;
  mesh_begin,mesh_end,pattern_destroy:procedure(Pattern:Pointer); cdecl;
  mesh_move,mesh_line:procedure(Pattern:Pointer; X,Y:Double); cdecl;
  mesh_color:procedure(Pattern:Pointer; Corner:Cardinal; R,G,B,A:Double); cdecl;
  pattern_source:procedure(Context,Pattern:Pointer); cdecl;
procedure Load;
  procedure Bind(var Target; const Name:string; Required:Boolean=True);
  begin Pointer(Target):=GetProcedureAddress(LibraryHandle,Name); if Required and (Pointer(Target)=nil) then Available:=False; end;
begin
  if Loaded then Exit; Loaded:=True;
  {$IFDEF MSWINDOWS}LibraryHandle:=LoadOptionalLibrary(['libcairo-2.dll','cairo.dll']);
  {$ELSE}{$IFDEF DARWIN}LibraryHandle:=LoadOptionalLibrary(['libcairo.2.dylib','libcairo.dylib']);
  {$ELSE}LibraryHandle:=LoadOptionalLibrary(['libcairo.so.2','libcairo.so']);{$ENDIF}{$ENDIF}
  if LibraryHandle=NilHandle then Exit; Available:=True;
  Bind(surface_create,'cairo_image_surface_create'); Bind(context_create,'cairo_create');
  Bind(context_destroy,'cairo_destroy'); Bind(surface_destroy,'cairo_surface_destroy');
  Bind(new_path,'cairo_new_path'); Bind(close_path,'cairo_close_path'); Bind(stroke_path,'cairo_stroke'); Bind(fill_preserve,'cairo_fill_preserve');
  Bind(save,'cairo_save'); Bind(restore,'cairo_restore'); Bind(paint_all,'cairo_paint');
  Bind(move_to,'cairo_move_to'); Bind(line_to,'cairo_line_to'); Bind(translate,'cairo_translate'); Bind(scale,'cairo_scale');
  Bind(curve_to,'cairo_curve_to'); Bind(arc,'cairo_arc'); Bind(set_source,'cairo_set_source_rgba'); Bind(set_width,'cairo_set_line_width');
  Bind(rotate,'cairo_rotate'); Bind(set_cap,'cairo_set_line_cap'); Bind(set_join,'cairo_set_line_join'); Bind(set_dash,'cairo_set_dash');
  Bind(set_antialias,'cairo_set_antialias');
  Bind(write_png,'cairo_surface_write_to_png_stream'); Bind(read_png,'cairo_image_surface_create_from_png_stream');
  Bind(set_surface,'cairo_set_source_surface'); Bind(image_width,'cairo_image_surface_get_width'); Bind(image_height,'cairo_image_surface_get_height');
  Bind(mesh_create,'cairo_pattern_create_mesh',False); Bind(mesh_begin,'cairo_mesh_pattern_begin_patch',False);
  Bind(mesh_end,'cairo_mesh_pattern_end_patch',False); Bind(mesh_move,'cairo_mesh_pattern_move_to',False);
  Bind(mesh_line,'cairo_mesh_pattern_line_to',False); Bind(mesh_color,'cairo_mesh_pattern_set_corner_color_rgba',False);
  Bind(pattern_destroy,'cairo_pattern_destroy',False); Bind(pattern_source,'cairo_set_source',False);
  MeshAvailable:=Assigned(mesh_create) and Assigned(mesh_begin) and Assigned(mesh_end) and Assigned(mesh_move) and
    Assigned(mesh_line) and Assigned(mesh_color) and Assigned(pattern_destroy) and Assigned(pattern_source);
end;
function WritePNG(Closure,Data:Pointer; Count:Cardinal):Integer; cdecl;
begin try TStream(Closure).WriteBuffer(Data^,Count); Result:=0; except Result:=11; end; end;
function ReadPNG(Closure,Data:Pointer; Count:Cardinal):Integer; cdecl;
begin try if TStream(Closure).Read(Data^,Count)=Count then Result:=0 else Result:=10; except Result:=10; end; end;
procedure Color(Context:Pointer; Value:TColor; Alpha:Double);
begin Value:=ColorToRGB(Value); set_source(Context,(Value and 255)/255,((Value shr 8) and 255)/255,((Value shr 16) and 255)/255,Alpha); end;
constructor TDiagramCanvas.Create(Width,Height:Integer; Opaque:Boolean);
begin
  Load; if not Available then Exit;
  FSurface:=surface_create(0,Width,Height); if FSurface=nil then Exit;
  FContext:=context_create(FSurface); if FContext=nil then Exit;
  if Opaque then begin set_source(FContext,1,1,1,1); paint_all(FContext); end;
end;
destructor TDiagramCanvas.Destroy;
begin if FContext<>nil then context_destroy(FContext); if FSurface<>nil then surface_destroy(FSurface); inherited Destroy; end;
function TDiagramCanvas.Ready:Boolean;
begin Result:=FContext<>nil; end;
procedure TDiagramCanvas.BeginPath;
begin new_path(FContext); end;
procedure TDiagramCanvas.MoveTo(X,Y:Double);
begin move_to(FContext,X,Y); end;
procedure TDiagramCanvas.LineTo(X,Y:Double);
begin line_to(FContext,X,Y); end;
procedure TDiagramCanvas.CurveTo(X1,Y1,X2,Y2,X3,Y3:Double);
begin curve_to(FContext,X1,Y1,X2,Y2,X3,Y3); end;
procedure TDiagramCanvas.ClosePath;
begin close_path(FContext); end;
procedure TDiagramCanvas.Ellipse(X,Y,RX,RY:Double);
begin
  save(FContext); translate(FContext,X,Y); scale(FContext,Max(1e-8,RX),Max(1e-8,RY)); arc(FContext,0,0,1,0,2*Pi); restore(FContext);
end;
procedure TDiagramCanvas.Paint(Stroke,Fill:TColor; Width:Double; const Dash:array of Double; Opacity:Double; Cap:Integer; Join:Integer);
begin
  if Fill<>clNone then begin Color(FContext,Fill,Opacity); fill_preserve(FContext); end;
  if (Stroke<>clNone) and (Width>0) then begin
    Color(FContext,Stroke,Opacity); set_width(FContext,Width); set_cap(FContext,Cap); set_join(FContext,Join);
    if Length(Dash)>0 then set_dash(FContext,@Dash[0],Length(Dash),0) else set_dash(FContext,nil,0,0);
    stroke_path(FContext);
  end else new_path(FContext);
end;
type TArrowShape=record
  Name:string; UnitSize,Shift,Length,Width,Inset,Tip,BackX,BackY,Notch,LineEnd,PenWidth:Double;
end;
function ArrowShape(Weight,Scale:Double; const Kind:string):TArrowShape;
var P:Integer; Options:TDiagramOptions; Field:TDiagramOption; Front,Back,Middle,HalfAngle,Miter,LocalScale:Double; Code:string; Format:TFormatSettings;
begin
  Result:=Default(TArrowShape); Code:=Trim(Kind);
  if (Length(Code)>1) and (Code[1]='{') and (Code[Length(Code)]='}') then Code:=Copy(Code,2,Length(Code)-2);
  P:=Pos('[',Code); Options:=nil;
  if P>0 then begin Options:=DiagramOptions(Copy(Code,P+1,Length(Code)-P-1)); Code:=Copy(Code,1,P-1); end;
  Result.Name:=Trim(Code); Result.UnitSize:=0.28*72/72.27*Scale+0.3*Weight;
  Result.Shift:=0.21*72/72.27*Scale+0.625*Weight;
  if Result.Name='latex' then Result.Shift:=9*Result.UnitSize else if Result.Name='stealth' then Result.Shift:=5*Result.UnitSize;
  if (Result.Name<>'Latex') and (Result.Name<>'Stealth') then Exit;
  { arrows.meta keeps the stroked outline inside its declared tip length. }
  Result.Length:=3*72/72.27*Scale+4.5*Weight; Result.PenWidth:=Weight;
  for Field in Options do if Field.Name='length' then Result.Length:=TeXStyleDimension(Field.Value,10)*72/72.27*Scale;
  Result.Width:=0.75*Result.Length; Result.Inset:=0.325*Result.Length;
  for Field in Options do begin
    if Field.Name='width' then Result.Width:=TeXStyleDimension(Field.Value,10)*72/72.27*Scale;
    if Field.Name='inset' then Result.Inset:=TeXStyleDimension(Field.Value,10)*72/72.27*Scale;
    if Field.Name='scale' then begin
      Format:=DefaultFormatSettings; Format.DecimalSeparator:='.';
      LocalScale:=Max(0.01,StrToFloatDef(Field.Value,1,Format)); Result.Length:=Result.Length*LocalScale;
      Result.Width:=Result.Width*LocalScale; Result.Inset:=Result.Inset*LocalScale;
    end;
  end;
  Result.Length:=Max(Weight,Result.Length); Result.Width:=Max(Weight,Result.Width); Result.Shift:=Result.Length;
  if Result.Name='Latex' then begin
    Result.PenWidth:=Min(Weight,0.2*Result.Length);
    Front:=Sqrt(9*Sqr(Result.Length/Result.Width)+1)*Result.PenWidth/2;
    Result.Shift:=Result.Length-Result.PenWidth/2; Result.Tip:=Result.Length-Front-Result.PenWidth/2;
    Result.BackY:=Result.Width/2-Result.PenWidth/2*(0.2333333*Result.Width+
      Hypot(0.3*Result.Length,0.2333333*Result.Width))/(0.3*Result.Length);
  end else begin
    Result.PenWidth:=Min(Weight,0.25*(Result.Length-Result.Inset));
    Front:=Sqrt(4*Sqr(Result.Length/Result.Width)+1)*Result.PenWidth/2;
    Back:=ArcTan2(Result.Length,Result.Width/2); Middle:=ArcTan2(Result.Inset,Result.Width/2);
    HalfAngle:=(Back-Middle)/2; Middle:=(Back+Middle)/2;
    Miter:=Result.PenWidth/2/Max(1e-8,Tan(HalfAngle));
    Result.BackX:=Sin(Middle)*Miter; Result.BackY:=Result.Width/2-Cos(Middle)*Miter;
    Result.Tip:=Result.Length-Front;
    Miter:=Sqrt(4*Sqr(Result.Inset/Result.Width)+1)*Result.PenWidth/2;
    Result.Notch:=Result.Inset+Miter; Result.LineEnd:=Result.Notch-Weight/4;
  end;
end;
function DiagramArrowLineEnd(Weight,PixelsPerPoint:Double; const Kind:string):Double;
var Shape:TArrowShape; Inset:Double;
begin
  Shape:=ArrowShape(Weight,PixelsPerPoint,Kind);
  Inset:=ArrowShaftInset(Kind,Weight,PixelsPerPoint);
  if (Inset>0) or (Pos('[',Kind)>0) or
    not ((Shape.Name='Latex') or (Shape.Name='Stealth') or (Shape.Name='latex') or
      (Shape.Name='stealth') or (Shape.Name='to') or (Shape.Name='')) then Exit(Inset);
  if (Shape.Name='Bar') or (Shape.Name='|') then Exit(Weight/2);
  Result:=Max(0.0,Shape.Shift-Shape.LineEnd);
end;
procedure TDiagramCanvas.Arrow(X,Y,Angle,Weight:Double; Color:TColor; const Kind:string; Opacity,PixelsPerPoint:Double);
var T:Double; Shape:TArrowShape; Contours:TArrowContours; Contour:TArrowContour; I:Integer; Stroke,Fill:TColor;
  function TipColor(const Value:string; Default:TColor):TColor;
  begin
    if Value='' then Result:=Default else if Value='none' then Result:=clNone else Result:=NamedColor(Value);
  end;
begin
  Shape:=ArrowShape(Weight,PixelsPerPoint,Kind); T:=Shape.UnitSize;
  if (Pos('[',Kind)>0) or
     not (Shape.Name='Latex') and not (Shape.Name='Stealth') and
     not (Shape.Name='latex') and not (Shape.Name='stealth') and (Shape.Name<>'to') and (Shape.Name<>'') then begin
    Contours:=ArrowContours(Kind,Weight,PixelsPerPoint);
    save(FContext); translate(FContext,X,Y); rotate(FContext,Angle);
    for Contour in Contours do if Length(Contour.Points)>0 then begin
      BeginPath; MoveTo(Contour.Points[0].X,Contour.Points[0].Y);
      for I:=1 to High(Contour.Points) do LineTo(Contour.Points[I].X,Contour.Points[I].Y);
      Stroke:=TipColor(Contour.StrokeColor,Color); Fill:=clNone;
      if Contour.Filled then begin ClosePath; Fill:=TipColor(Contour.FillColor,Stroke); end;
      Paint(Stroke,Fill,Contour.PenWidth,[],Opacity,Contour.Cap,Contour.Join);
    end;
    restore(FContext); Exit;
  end;
  save(FContext); translate(FContext,X,Y); rotate(FContext,Angle); translate(FContext,-Shape.Shift,0); BeginPath;
  if Shape.Name='stealth' then begin
    MoveTo(5*T,0); LineTo(-3*T,4*T); LineTo(0,0); LineTo(-3*T,-4*T); ClosePath;
    Paint(clNone,Color,0,[],Opacity);
  end else if Shape.Name='latex' then begin
    MoveTo(9*T,0); CurveTo(6.3333*T,0.5*T,2*T,2*T,-T,3.75*T); LineTo(-T,-3.75*T);
    CurveTo(2*T,-2*T,6.3333*T,-0.5*T,9*T,0); ClosePath; Paint(clNone,Color,0,[],Opacity);
  end else if Shape.Name='Stealth' then begin
    MoveTo(Shape.Tip,0); LineTo(Shape.BackX,Shape.BackY); LineTo(Shape.Notch,0); LineTo(Shape.BackX,-Shape.BackY); ClosePath;
    Paint(Color,Color,Shape.PenWidth,[],Opacity);
  end else if Shape.Name='Latex' then begin
    MoveTo(Shape.Tip,0);
    CurveTo(0.877192*Shape.Tip,0.077922*Shape.BackY,0.337381*Shape.Tip,0.519480*Shape.BackY,0,Shape.BackY);
    LineTo(0,-Shape.BackY); CurveTo(0.337381*Shape.Tip,-0.519480*Shape.BackY,0.877192*Shape.Tip,-0.077922*Shape.BackY,Shape.Tip,0); ClosePath;
    Paint(Color,Color,Shape.PenWidth,[],Opacity);
  end else begin
    MoveTo(-3*T,4*T); CurveTo(-2.75*T,2.5*T,0,0.25*T,0.75*T,0);
    CurveTo(0,-0.25*T,-2.75*T,-2.5*T,-3*T,-4*T); Paint(Color,clNone,0.8*Weight,[],Opacity,1,1);
  end;
  restore(FContext);
end;
procedure TDiagramCanvas.Image(PNG:TStream; X,Y,Width,Height,Angle:Double);
var Surface:Pointer; W,H:Integer;
begin
  PNG.Position:=0; Surface:=read_png(@ReadPNG,PNG); if Surface=nil then Exit;
  try
    W:=image_width(Surface); H:=image_height(Surface); if (W<1) or (H<1) then Exit;
    { Upright labels were rasterized at this exact device resolution. A second
      fractional translation filters every glyph again and softens its edges. }
    if (Abs(Angle)<1e-9) and (Abs(Width-W)<1e-9) and (Abs(Height-H)<1e-9) then begin X:=Round(X); Y:=Round(Y); end;
    save(FContext); translate(FContext,X,Y); rotate(FContext,Angle); scale(FContext,Width/W,Height/H);
    set_surface(FContext,Surface,0,0); paint_all(FContext); restore(FContext);
  finally surface_destroy(Surface); end;
end;
function TDiagramCanvas.MeshPatch(const Coordinates:array of Double; const Colors:array of TColor; Opacity:Double):Boolean;
var Pattern:Pointer; I:Integer; C:TColor;
begin
  Result:=False; if not MeshAvailable or (Length(Coordinates)<>8) or (Length(Colors)<>4) then Exit;
  Pattern:=mesh_create(); if Pattern=nil then Exit;
  try
    mesh_begin(Pattern); mesh_move(Pattern,Coordinates[0],Coordinates[1]);
    for I:=1 to 3 do mesh_line(Pattern,Coordinates[2*I],Coordinates[2*I+1]);
    for I:=0 to 3 do begin
      C:=ColorToRGB(Colors[I]); mesh_color(Pattern,I,(C and 255)/255,((C shr 8) and 255)/255,((C shr 16) and 255)/255,Opacity);
    end;
    mesh_end(Pattern); save(FContext); pattern_source(FContext,Pattern);
    { Adjacent patches share pixel ownership, avoiding pale antialias seams. }
    set_antialias(FContext,1); fill_preserve(FContext); restore(FContext); Result:=True;
  finally pattern_destroy(Pattern); end;
end;
function TDiagramCanvas.Finish(Picture:TPicture):Boolean;
var Stream:TMemoryStream;
begin
  Result:=False; if not Ready then Exit; Stream:=TMemoryStream.Create;
  try if write_png(FSurface,@WritePNG,Stream)<>0 then Exit; Stream.Position:=0; Picture.LoadFromStream(Stream); Result:=True;
  finally Stream.Free; end;
end;
procedure DiagramBitmapPNG(Bitmap:TBitmap; Stream:TStream);
var PNG:TPortableNetworkGraphic; Input,Output:TLazIntfImage; Writer:TFPWriterPNG; X,Y,A:Integer; C:TFPColor;
    {$IFDEF LCLgtk3}DC:TGtk3DeviceContext; Surface:Pointer; get_target:function(Context:Pointer):Pointer; cdecl; CopyStream:TMemoryStream;{$ENDIF}
begin
  PNG:=TPortableNetworkGraphic.Create;
  try
  {$IFDEF LCLgtk3}
  Load; DC:=TGtk3DeviceContext(Bitmap.Canvas.Handle); if (DC=nil) or (DC.pcr=nil) or not Available then Exit;
  Pointer(get_target):=GetProcedureAddress(LibraryHandle,'cairo_get_target'); if not Assigned(get_target) then Exit;
  Surface:=get_target(DC.pcr); CopyStream:=TMemoryStream.Create;
  try write_png(Surface,@WritePNG,CopyStream); CopyStream.Position:=0; PNG.LoadFromStream(CopyStream); finally CopyStream.Free; end;
  {$ELSE}
  PNG.Assign(Bitmap);
  {$ENDIF}
  { A bitmap mask is not written as an alpha channel by every widget set.
    Recover text coverage from its white background, including antialiasing. }
  Input:=PNG.CreateIntfImage; Output:=nil; Writer:=nil;
  try
    Output:=TLazIntfImage.Create(Input.Width,Input.Height,[riqfRGB,riqfAlpha]);
    for Y:=0 to Input.Height-1 do for X:=0 to Input.Width-1 do begin
      C:=Input.Colors[X,Y]; A:=65535-Min(C.Red,Min(C.Green,C.Blue)); C.Alpha:=A;
      if A>0 then begin
        C.Red:=(Int64(C.Red-65535+A)*65535) div A;
        C.Green:=(Int64(C.Green-65535+A)*65535) div A;
        C.Blue:=(Int64(C.Blue-65535+A)*65535) div A;
      end;
      Output.Colors[X,Y]:=C;
    end;
    Writer:=TFPWriterPNG.Create; Writer.UseAlpha:=True; Writer.WordSized:=False; Output.SaveToStream(Stream,Writer);
  finally Writer.Free; Output.Free; Input.Free; end;
  finally PNG.Free; end;
end;
finalization
  if LibraryHandle<>NilHandle then UnloadLibrary(LibraryHandle);
end.
