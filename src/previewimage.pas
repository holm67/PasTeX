unit PreviewImage;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Types, Controls, ExtCtrls, Graphics, LCLIntf, LCLType, LMessages, Forms, VectorPreview, UITheme, FPImage, FPReadPNG, FPWritePNG
  {$IFDEF LCLgtk3}, Gtk3Objects, LazGdkPixbuf2, LazGdk3, LazGObject2, LazCairo1{$ENDIF};
type
  TPreviewPanel = class(TPanel)
  private
    FDocumentOrigin,FDocumentSize:TPoint;
    FDocumentBounds:Boolean;
    FSeparatorCaption:string;
    FDoubleSeparator:Boolean;
  protected
    procedure ConstrainedResize(var MinWidth,MinHeight,MaxWidth,MaxHeight:TConstraintSize); override;
    procedure Paint; override;
    {$IFDEF LCLgtk3}
    procedure CreateWnd; override;
    function GetClientOrigin:TPoint; override;
    {$ENDIF}
    procedure SendMoveSizeMessages(SizeChanged,PosChanged:Boolean); override;
    procedure WMMove(var Message:TLMMove); message LM_MOVE;
    procedure WMSize(var Message:TLMSize); message LM_SIZE;
  public
    property DocumentOrigin:TPoint read FDocumentOrigin;
    property SeparatorCaption:string read FSeparatorCaption write FSeparatorCaption;
    property DoubleSeparator:Boolean read FDoubleSeparator write FDoubleSeparator;
    procedure SetDocumentBounds(X,Y,W,H:Integer);
    procedure SyncScrollPosition;
    procedure ReleaseNativeCache;
  end;
  TSelectionRects = array of TRect;
  TPreviewSurface = class
  private
    FVectorZoom:Double;
    FVector:IVectorDocument; FVectorPage:Integer; FVectorPicture:TPicture;
    FVectorWidth,FVectorHeight:Integer;
    FVectorRegion:TRect;
    FVectorStamp:QWord;
    FCachedPixels:Int64;
    FCacheNext,FCachePrevious:TPreviewSurface;
    FPreserveColors:Boolean;
    FContainsPictures:Boolean;
    FImageRegions:TVectorImageRegions;
    FImageRegionsKnown:Boolean;
    FTransparent:Boolean;
    FDark:TPicture; FWasDark:Boolean;
    procedure SetPreserveColors(Value:Boolean);
    procedure PrepareVector(Width,Height:Integer; const Region:TRect);
    function PixelCost(Width,Height:Integer):Int64;
    function DrawVectorAt(Canvas:TCanvas; const Bounds:TRect; Width,Height:Integer):Boolean;
    function Themed(Picture:TPicture):TPicture;
    procedure DrawPixels(Canvas:TCanvas; const Bounds:TRect; Picture:TPicture);
  private
    {$IFDEF LCLgtk3}
    FPixels:PGdkPixbuf;
    procedure Decode(Picture:TPicture);
    {$ENDIF}
  public
    destructor Destroy; override;
    property PreserveColors:Boolean read FPreserveColors write SetPreserveColors;
    property ContainsPictures:Boolean read FContainsPictures write FContainsPictures;
    property VectorZoom:Double read FVectorZoom write FVectorZoom;
    property VectorDocument:IVectorDocument read FVector;
    property VectorPage:Integer read FVectorPage;
    procedure SetVector(const Document:IVectorDocument; Page:Integer);
    procedure SetSourceGraphics(const Source:string);
    procedure Clear;
    function DrawVector(Canvas:TCanvas; const Bounds:TRect):Boolean;
    procedure Draw(Canvas:TCanvas; const Bounds:TRect; Picture:TPicture);
    procedure DrawRegion(Canvas:TCanvas; const Bounds,Source:TRect; Picture:TPicture);
  end;
  TPreviewImage = class(TCustomControl)
  private
    FSelection:TSelectionRects;
    FPicture:TPicture;
    FStoredPNG:RawByteString;
    FPreviewWidth,FPreviewHeight:Integer;
    FLoadingPicture:Boolean;
    FSurface:TPreviewSurface;
    function GetPicture:TPicture;
    procedure PictureChanged(Sender:TObject);
  protected
    {$IFDEF LCLgtk3}
    procedure CreateWnd; override;
    function GetClientOrigin:TPoint; override;
    {$ENDIF}
    function DoMouseWheel(Shift:TShiftState; WheelDelta:Integer; MousePos:TPoint):Boolean; override;
    procedure Resize; override;
    procedure Paint; override;
  public
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure SetSelection(const Rects:TSelectionRects);
    procedure LoadPreview(const FileName:string);
    function LoadVectorPreview(const Document:IVectorDocument; Page,DPI:Integer):Boolean;
    procedure ReleaseRenderCache;
    procedure ClearPreview;
    property PreviewWidth:Integer read FPreviewWidth;
    property PreviewHeight:Integer read FPreviewHeight;
    property PNGData:RawByteString read FStoredPNG;
    property Picture:TPicture read GetPicture;
    property Surface:TPreviewSurface read FSurface;
  end;
procedure SetPreviewScroll(Scroll:TScrollBox; X,Y:Integer);
procedure DrawEditorSeparator(Canvas:TCanvas; const Bounds:TRect; const Caption:string; DoubleLine:Boolean=False);
function PreviewViewportOrigin(Scroll:TScrollBox):TPoint;
function PreviewLayoutWidth(Scroll:TScrollBox):Integer;
function PreviewMovePosition(Control:TWinControl; const Message:TLMMove; out Position:TPoint):Boolean;
function PreviewNativeClientOrigin(Control:TWinControl; out Origin:TPoint):Boolean;
function PreviewCanvasScale(Canvas:TCanvas):Double;
function PreviewRasterCachePixels:Int64;
{$IFDEF LCLgtk3}procedure ConfigurePreviewPainting(Control:TWinControl);{$ENDIF}
procedure DrawSelectionOutline(Canvas:TCanvas; const Boxes:TSelectionRects;
  Color:TColor=$D08030; Width:Integer=2; Style:TPenStyle=psSolid);
implementation
uses Math, PreviewBackdrops, IntfGraphics {$IFDEF LCLgtk3}, Gtk3Widgets, LazGtk3, LazGLib2{$ENDIF};
{$IFDEF LCLgtk3}
function PaintPreviewWidget(Widget:PGtkWidget; Context:Pcairo_t; Data:gpointer):gboolean; cdecl;
begin Result:=TGtk3Widget(Data).GtkEventPaint(Widget,Context); end;
procedure ConfigurePreviewPainting(Control:TWinControl);
var Native:TGtk3Widget; Widget:PGtkWidget;
begin
  { Lazarus 4.0 queues another draw when the clip is shorter than a quarter
    of the widget. Scrolled previews legitimately have such clips, producing
    an endless redraw loop. The scroll container can span the whole document,
    so keep LCL painting without that retry on it and the preview itself. }
  while Control<>nil do begin
    if Control.HandleAllocated then begin
      Native:=TGtk3Widget(Control.Handle); Widget:=Native.GetContainerWidget;
      if (Widget<>nil) and (g_signal_handler_find(Widget,[G_SIGNAL_MATCH_FUNC,G_SIGNAL_MATCH_DATA],
        0,0,nil,@PaintPreviewWidget,Native)=0) then begin
        g_signal_handlers_disconnect_matched(Widget,[G_SIGNAL_MATCH_ID,G_SIGNAL_MATCH_DATA],
          g_signal_lookup('draw',gtk_widget_get_type),0,nil,nil,Native);
        g_signal_connect_data(Widget,'draw',TGCallback(@PaintPreviewWidget),Native,nil,G_CONNECT_DEFAULT);
      end;
    end;
    Control:=Control.Parent;
    while (Control<>nil) and not (Control is TScrollBox) do Control:=Control.Parent;
  end;
end;
procedure RequestPreviewSize(Control:TWinControl; W,H:Integer);
var Widget:PGtkWidget; OldWidth,OldHeight:gint;
begin
  if not Control.HandleAllocated then Exit;
  Widget:=TGtk3Widget(Control.Handle).GetContainerWidget; if Widget=nil then Exit;
  Widget^.get_size_request(@OldWidth,@OldHeight);
  if (OldWidth<>Max(1,W)) or (OldHeight<>Max(1,H)) then Widget^.set_size_request(Max(1,W),Max(1,H));
  { GTK also copies this request into LCL constraints. Parent alignment reads
    those directly, bypassing the control's ConstrainedResize override. }
  Control.Constraints.MinWidth:=0; Control.Constraints.MinHeight:=0;
end;
{$ENDIF}
function PreviewLayoutWidth(Scroll:TScrollBox):Integer;
begin
  {$IFDEF LCLgtk3}
  { GTK3 reports the previous viewport allocation during resize, and can
    report a zero scrollbar size until that scrollbar has been allocated. }
  Result:=Max(1,Scroll.Width-GetSystemMetrics(SM_CXVSCROLL));
  {$ELSE}
  Result:=Max(1,Scroll.VertScrollBar.ClientSizeWithBar);
  {$ENDIF}
end;
const VectorCachePixels=4000000;
var VectorHead:TPreviewSurface; VectorPixels:Int64; VectorClock:QWord;
function PreviewRasterCachePixels:Int64;
begin Result:=VectorPixels; end;
function VisiblePreviewRect(Canvas:TCanvas; const Bounds:TRect):TRect;
var Control,Parent:TWinControl; P:TPoint; Clip:TRect;
begin
  Result:=Bounds; Clip:=Canvas.ClipRect;
  if (Clip.Width>0) and (Clip.Height>0) then IntersectRect(Result,Result,Clip);
  if not (Canvas is TControlCanvas) or not (TControlCanvas(Canvas).Control is TWinControl) then Exit;
  Control:=TWinControl(TControlCanvas(Canvas).Control); Parent:=Control.Parent;
  while Parent<>nil do begin
    if Parent is TScrollBox then begin
      P:=Control.ScreenToClient(PreviewViewportOrigin(TScrollBox(Parent)));
      IntersectRect(Result,Result,Rect(P.X,P.Y,P.X+Parent.ClientWidth,P.Y+Parent.ClientHeight));
    end;
    Parent:=Parent.Parent;
  end;
end;
function PreviewCanvasScale(Canvas:TCanvas):Double;
begin
  Result:=1;
  if (Canvas is TControlCanvas) and (TControlCanvas(Canvas).Control<>nil) then
    Result:=Max(1,TControlCanvas(Canvas).Control.GetCanvasScaleFactor);
end;
function PreviewNativeClientOrigin(Control:TWinControl; out Origin:TPoint):Boolean;
{$IFDEF LCLgtk3}
var Widget,TopWidget:PGtkWidget; Window:PGdkWindow; OffsetX,OffsetY,X,Y:Integer;
{$ENDIF}
begin
  Result:=False;
  {$IFDEF LCLgtk3}
  if not Control.HandleAllocated then Exit;
  Widget:=TGtk3Widget(Control.Handle).GetContainerWidget;
  if Widget=nil then Exit;
  TopWidget:=Widget^.get_toplevel;
  if TopWidget=nil then Exit;
  Window:=TopWidget^.get_window;
  if Window=nil then Exit;
  { GTK3's LCL origin sums allocations and misses the viewport's scrolled
    window offset. Native coordinate translation includes that offset. }
  if not Widget^.translate_coordinates(TopWidget,0,0,@OffsetX,@OffsetY) then Exit;
  Window^.get_origin(@X,@Y); Origin:=Point(X+OffsetX,Y+OffsetY); Result:=True;
  {$ENDIF}
end;
{$IFDEF LCLgtk3}
procedure TPreviewPanel.CreateWnd;
begin
  inherited CreateWnd; ConfigurePreviewPainting(Self);
  if FDocumentBounds then RequestPreviewSize(Self,FDocumentSize.X,FDocumentSize.Y);
end;
procedure TPreviewImage.CreateWnd;
begin inherited CreateWnd; ConfigurePreviewPainting(Self); end;
function TPreviewPanel.GetClientOrigin:TPoint;
begin if not PreviewNativeClientOrigin(Self,Result) then Result:=inherited GetClientOrigin; end;
function TPreviewImage.GetClientOrigin:TPoint;
begin if not PreviewNativeClientOrigin(Self,Result) then Result:=inherited GetClientOrigin; end;
{$ENDIF}
procedure DrawEditorSeparator(Canvas:TCanvas; const Bounds:TRect; const Caption:string; DoubleLine:Boolean);
var W,H,X,Y,D:Integer;
begin
  Canvas.Font.Name:='Sans'; Canvas.Font.Size:=9; Canvas.Font.Style:=[fsBold];
  Canvas.Font.Color:=InkColor; Canvas.Brush.Style:=bsClear;
  W:=Canvas.TextWidth(Caption); H:=Canvas.TextHeight(Caption);
  X:=Bounds.Left+(Bounds.Width-W) div 2; Y:=Bounds.Top+Bounds.Height div 2;
  Canvas.Pen.Color:=clGray; Canvas.Pen.Style:=psDash; Canvas.Pen.Width:=1;
  D:=0; if DoubleLine then D:=2;
  Canvas.Line(Bounds.Left,Y-D,Max(Bounds.Left,X-10),Y-D);
  Canvas.Line(Min(Bounds.Right,X+W+10),Y-D,Bounds.Right,Y-D);
  if DoubleLine then begin
    Canvas.Line(Bounds.Left,Y+D,Max(Bounds.Left,X-10),Y+D);
    Canvas.Line(Min(Bounds.Right,X+W+10),Y+D,Bounds.Right,Y+D);
  end;
  Canvas.Pen.Style:=psSolid; Canvas.Brush.Style:=bsSolid; Canvas.Brush.Color:=PaperColor;
  Canvas.FillRect(Rect(X-8,Y-H div 2-2,X+W+8,Y+(H+1) div 2+2));
  Canvas.Brush.Style:=bsClear; Canvas.TextOut(X,Y-H div 2,Caption);
end;
procedure TPreviewPanel.Paint;
begin
  inherited Paint;
  if FSeparatorCaption<>'' then DrawEditorSeparator(Canvas,ClientRect,FSeparatorCaption,FDoubleSeparator);
end;
function PreviewMovePosition(Control:TWinControl; const Message:TLMMove; out Position:TPoint):Boolean;
var Bounds:TRect;
begin
  Result:=False;
  if ((Message.MoveType and Move_SourceIsInterface)=0) or (Control.Parent=nil) or not Control.HandleAllocated then Exit;
  if GetWindowRect(Control.Handle,Bounds)=0 then Exit;
  Position:=Control.Parent.ScreenToClient(Bounds.TopLeft);
  Result:=(Position.X<>Message.XPos) or (Position.Y<>Message.YPos);
end;
procedure TPreviewPanel.WMMove(var Message:TLMMove);
var Position:TPoint;
begin
  { Native scroll notifications can be delayed, truncated, or refer to the
    old scrollbar range. The document position remains authoritative. }
  if FDocumentBounds and (Parent is TScrollBox) and
     ((Message.MoveType and Move_SourceIsInterface)<>0) then Exit
  else if PreviewMovePosition(Self,Message,Position) then SetBounds(Position.X,Position.Y,Width,Height)
  else inherited WMMove(Message);
end;
procedure TPreviewPanel.SetDocumentBounds(X,Y,W,H:Integer);
begin
  FDocumentOrigin:=Point(X,Y); FDocumentSize:=Point(W,H); FDocumentBounds:=True;
  {$IFDEF LCLgtk3}
  { GtkFixed retains its initial size request (usually 50 pixels high).
    Keep that native minimum in sync with the measured document rectangle. }
  RequestPreviewSize(Self,W,H);
  {$ENDIF}
  { Qt and GTK apply the scroll offset in their viewport. Win32 moves each
    child window, so it needs the offset in the requested native bounds. }
  {$IFDEF MSWINDOWS}
  if Parent is TScrollBox then begin
    Dec(X,TScrollBox(Parent).HorzScrollBar.Position);
    Dec(Y,TScrollBox(Parent).VertScrollBar.Position);
  end;
  {$ENDIF}
  SetBounds(X,Y,W,H);
end;
procedure TPreviewPanel.SyncScrollPosition;
begin
  if FDocumentBounds then SetDocumentBounds(FDocumentOrigin.X,FDocumentOrigin.Y,FDocumentSize.X,FDocumentSize.Y);
end;
procedure TPreviewPanel.ConstrainedResize(var MinWidth,MinHeight,MaxWidth,MaxHeight:TConstraintSize);
begin
  inherited ConstrainedResize(MinWidth,MinHeight,MaxWidth,MaxHeight);
  if FDocumentBounds then begin
    { GTK3 retains the panel's default minimum height. Clamping a shorter
      paragraph to it also moves its top when the old bottom is unchanged. }
    MinWidth:=0; MinHeight:=0; MaxWidth:=0; MaxHeight:=0;
  end;
end;
procedure TPreviewPanel.WMSize(var Message:TLMSize);
begin
  { A delayed allocation must not replace the newer document geometry.
    GTK3 can deliver the old paper size after a Fit Page resize. }
  if FDocumentBounds and (Parent is TScrollBox) and
    ((Message.SizeType and Size_SourceIsInterface)<>0) and
    ((Message.Width<>FDocumentSize.X) or (Message.Height<>FDocumentSize.Y)) then Exit;
  inherited WMSize(Message);
end;
procedure TPreviewPanel.SendMoveSizeMessages(SizeChanged,PosChanged:Boolean);
begin
  { Native bounds use integers. The simulated VCL move notification packs
    them into SmallInts and is unnecessary for these undocked page panels. }
  inherited SendMoveSizeMessages(SizeChanged,PosChanged and
    (Left>=Low(SmallInt)) and (Left<=High(SmallInt)) and
    (Top>=Low(SmallInt)) and (Top<=High(SmallInt)));
end;
procedure TPreviewPanel.ReleaseNativeCache;
begin if not Visible and HandleAllocated then DestroyHandle; end;
procedure DrawSelectionOutline(Canvas:TCanvas; const Boxes:TSelectionRects;
  Color:TColor; Width:Integer; Style:TPenStyle);
var Points:array of TPoint; I,Y:Integer;
  procedure Add(X,Y:Integer);
  var N:Integer;
  begin N:=Length(Points); SetLength(Points,N+1); Points[N]:=Point(X,Y); end;
begin
  if Length(Boxes)=0 then Exit;
  Canvas.Brush.Style:=bsClear; Canvas.Pen.Color:=Color; Canvas.Pen.Width:=Width; Canvas.Pen.Style:=Style;
  Add(Boxes[0].Left,Boxes[0].Top); Add(Boxes[0].Right,Boxes[0].Top);
  for I:=1 to High(Boxes) do begin
    Y:=(Boxes[I-1].Bottom+Boxes[I].Top) div 2;
    Add(Boxes[I-1].Right,Y); Add(Boxes[I].Right,Y);
  end;
  Add(Boxes[High(Boxes)].Right,Boxes[High(Boxes)].Bottom); Add(Boxes[High(Boxes)].Left,Boxes[High(Boxes)].Bottom);
  for I:=High(Boxes) downto 1 do begin
    Y:=(Boxes[I-1].Bottom+Boxes[I].Top) div 2;
    Add(Boxes[I].Left,Y); Add(Boxes[I-1].Left,Y);
  end;
  Add(Boxes[0].Left,Boxes[0].Top); Canvas.Polyline(Points);
  Canvas.Pen.Width:=1; Canvas.Pen.Style:=psSolid; Canvas.Brush.Style:=bsSolid;
end;
procedure SetPreviewScroll(Scroll:TScrollBox; X,Y:Integer);
{$IFDEF LCLgtk3}
var Widget:TGtk3ScrollingWinControl; Native:PGtkScrolledWindow;
{$ENDIF}
begin
  { LCL accepts positive positions when Range < Page. Some widget sets then
    reset the reported position to zero after moving the child controls. }
  Scroll.HorzScrollBar.Position:=EnsureRange(X,0,Max(0,Scroll.HorzScrollBar.Range-Scroll.ClientWidth));
  Scroll.VertScrollBar.Position:=EnsureRange(Y,0,Max(0,Scroll.VertScrollBar.Range-Scroll.ClientHeight));
  {$IFDEF LCLgtk3}
  { LCL GTK3's ScrollBy updates its counters without moving the viewport.
    Also restore the native adjustments after GTK scrolls a focused child. }
  if Scroll.HandleAllocated then begin
    Widget:=TGtk3ScrollingWinControl(Scroll.Handle); Native:=Widget.GetScrolledWindow;
    if Native<>nil then begin
      Widget.BeginUpdate;
      try
        Native^.get_hadjustment^.set_value(Scroll.HorzScrollBar.Position);
        Native^.get_vadjustment^.set_value(Scroll.VertScrollBar.Position);
      finally Widget.EndUpdate; end;
    end;
  end;
  {$ENDIF}
end;
function PreviewViewportOrigin(Scroll:TScrollBox):TPoint;
{$IFDEF LCLgtk3}
var Widget,TopWidget:PGtkWidget; Window:PGdkWindow; X,Y,OffsetX,OffsetY:Integer;
{$ENDIF}
begin
  {$IFDEF LCLgtk3}
  if Scroll.HandleAllocated then begin
    { Translate the outer scrolled window, whose origin stays at the viewport.
      LCL parent coordinates can lag behind GTK's current allocation. }
    Widget:=TGtk3Widget(Scroll.Handle).Widget;
    if Widget<>nil then begin
      TopWidget:=Widget^.get_toplevel;
      if TopWidget<>nil then begin
        Window:=TopWidget^.get_window;
        if (Window<>nil) and Widget^.translate_coordinates(TopWidget,0,0,@OffsetX,@OffsetY) then begin
          Window^.get_origin(@X,@Y); Result:=Point(X+OffsetX,Y+OffsetY);
          if Scroll.BorderStyle=bsSingle then begin Inc(Result.X,2); Inc(Result.Y,2); end;
          Exit;
        end;
      end;
    end;
  end;
  {$ENDIF}
  { Some widget sets report the scrolled content origin as ClientToScreen(0,0).
    The parent's coordinates locate the stationary viewport instead. }
  Result:=Scroll.Parent.ClientToScreen(Point(Scroll.Left,Scroll.Top));
  if Scroll.BorderStyle=bsSingle then begin Inc(Result.X,2); Inc(Result.Y,2); end;
end;
destructor TPreviewSurface.Destroy;
begin Clear; inherited Destroy; end;
procedure TPreviewSurface.SetVector(const Document:IVectorDocument; Page:Integer);
begin
  Clear; FVector:=Document; FVectorPage:=Page; FImageRegions:=nil; FImageRegionsKnown:=False;
end;
procedure TPreviewSurface.Clear;
begin
  if FVectorPicture<>nil then begin
    Dec(VectorPixels,FCachedPixels);
    if FCachePrevious<>nil then FCachePrevious.FCacheNext:=FCacheNext else VectorHead:=FCacheNext;
    if FCacheNext<>nil then FCacheNext.FCachePrevious:=FCachePrevious;
    FCachePrevious:=nil; FCacheNext:=nil;
  end;
  FCachedPixels:=0;
  FreeAndNil(FDark); FreeAndNil(FVectorPicture);
  {$IFDEF LCLgtk3}
  if FPixels<>nil then g_object_unref(FPixels);
  FPixels:=nil;
  {$ENDIF}
end;
{$IFDEF LCLgtk3}
procedure TPreviewSurface.Decode(Picture:TPicture);
var Stream:TMemoryStream; Loader:PGdkPixbufLoader;
begin
  Stream:=TMemoryStream.Create;
  Loader:=gdk_pixbuf_loader_new;
  try
    { Decode the raster directly; GTK3 paints through its own pixbuf. }
    Picture.Graphic.SaveToStream(Stream);
    if not gdk_pixbuf_loader_write(Loader,Stream.Memory,Stream.Size,nil) then Exit;
    if not gdk_pixbuf_loader_close(Loader,nil) then Exit;
    FPixels:=gdk_pixbuf_loader_get_pixbuf(Loader);
    if FPixels<>nil then g_object_ref(FPixels);
  finally g_object_unref(Loader); Stream.Free; end;
end;
{$ENDIF}
procedure TPreviewSurface.SetSourceGraphics(const Source:string);
var Pictures:Boolean;
begin
  Pictures:=(Pos('\includegraphics',Source)>0) or (Pos('\includepdf',Source)>0);
  if (FContainsPictures<>Pictures) or FPreserveColors then Clear;
  FContainsPictures:=Pictures; FPreserveColors:=False;
end;
procedure TPreviewSurface.SetPreserveColors(Value:Boolean);
begin
  if FPreserveColors=Value then Exit;
  Clear; FPreserveColors:=Value;
end;
function TPreviewSurface.Themed(Picture:TPicture):TPicture;
var Img:TLazIntfImage; X,Y,I:Integer; C:TFPColor; Keep,Transparent:Boolean;
    Images:array of TRect; Backdrops:TBackdropMask;
begin
  if FWasDark<>DarkMode then begin Clear; FWasDark:=DarkMode; end;
  Result:=Picture;
  if FPreserveColors then Exit;
  if DarkMode and (FVector<>nil) and not FImageRegionsKnown then begin
    if FVector<>nil then FImageRegions:=FVector.ImageRegions(FVectorPage);
    FImageRegionsKnown:=True;
  end;
  if not DarkMode or (Picture.Width<=0) then Exit;
  { Only an unmapped raster image needs the conservative fallback. A PDF
    figure is not a raster image: its caption and prose still follow the theme. }
  if FContainsPictures and (FVector=nil) and (Length(FImageRegions)=0) then Exit;
  if not (Picture.Graphic is TCustomBitmap) then Exit;
  if FDark=nil then begin
    Img:=TCustomBitmap(Picture.Graphic).CreateIntfImage;
    try
      Transparent:=(Picture=FVectorPicture) and FTransparent;
      if Transparent then Backdrops:=WhiteBackdropMask(Img);
      SetLength(Images,Length(FImageRegions));
      for I:=0 to High(Images) do begin
        if (Picture=FVectorPicture) and (FVectorWidth>0) then
          Images[I]:=Rect(Floor(FImageRegions[I].Left*FVectorWidth)-FVectorRegion.Left,
            Floor(FImageRegions[I].Top*FVectorHeight)-FVectorRegion.Top,
            Ceil(FImageRegions[I].Right*FVectorWidth)-FVectorRegion.Left,
            Ceil(FImageRegions[I].Bottom*FVectorHeight)-FVectorRegion.Top)
        else Images[I]:=Rect(Floor(FImageRegions[I].Left*Img.Width),Floor(FImageRegions[I].Top*Img.Height),
          Ceil(FImageRegions[I].Right*Img.Width),Ceil(FImageRegions[I].Bottom*Img.Height));
      end;
      for Y:=0 to Img.Height-1 do for X:=0 to Img.Width-1 do begin
        Keep:=BackdropPixel(Backdrops,X+Y*Img.Width);
        for I:=0 to High(Images) do if PtInRect(Images[I],Point(X,Y)) then begin Keep:=True; Break; end;
        C:=Img.Colors[X,Y];
        if not Keep then begin
          if Transparent then begin
            { Unpainted paper is transparent. Explicit white fills and colored
              paths stay intact; default black ink becomes light ink. }
            if (C.Red=0) and (C.Green=0) and (C.Blue=0) then begin C.Red:=$EEEE; C.Green:=$EEEE; C.Blue:=$EEEE; end;
          end else if (C.Red=C.Green) and (C.Green=C.Blue) then begin
            C.Red:=$EEEE-(Int64(C.Red)*($EEEE-$2424) div 65535); C.Green:=C.Red; C.Blue:=C.Red;
          end;
        end;
        if Transparent then begin
          C.Red:=(Int64(C.Red)*C.Alpha+Int64($2424)*(65535-C.Alpha)) div 65535;
          C.Green:=(Int64(C.Green)*C.Alpha+Int64($2424)*(65535-C.Alpha)) div 65535;
          C.Blue:=(Int64(C.Blue)*C.Alpha+Int64($2424)*(65535-C.Alpha)) div 65535; C.Alpha:=65535;
        end;
        Img.Colors[X,Y]:=C;
      end;
      FDark:=TPicture.Create; FDark.Bitmap.LoadFromIntfImage(Img);
    finally Img.Free; end;
  end;
  Result:=FDark;
end;
function TPreviewSurface.PixelCost(Width,Height:Integer):Int64;
var Copies:Integer;
begin
  { Reserve the themed copy and GTK's drawing buffer in the same budget. }
  Copies:=1+Ord(DarkMode and not FPreserveColors);
  {$IFDEF LCLgtk3}Inc(Copies);{$ENDIF}
  Result:=Int64(Width)*Height*Copies;
end;
procedure TPreviewSurface.PrepareVector(Width,Height:Integer; const Region:TRect);
var Oldest,Candidate:TPreviewSurface; Transparent:ITransparentVectorDocument; Rendered:Boolean; Pixels:Int64;
begin
  if FWasDark<>DarkMode then begin Clear; FWasDark:=DarkMode; end;
  if (FVector=nil) or (Width<1) or (Height<1) then Exit;
  Inc(VectorClock); FVectorStamp:=VectorClock;
  if (FVectorPicture=nil) or (FVectorWidth<>Width) or (FVectorHeight<>Height) or
    (Region.Left<FVectorRegion.Left) or (Region.Top<FVectorRegion.Top) or
    (Region.Right>FVectorRegion.Right) or (Region.Bottom>FVectorRegion.Bottom) then begin
    Clear;
    Pixels:=PixelCost(Region.Width,Region.Height);
    if Pixels>VectorCachePixels then Exit;
    while (VectorPixels+Pixels>VectorCachePixels) and (VectorHead<>nil) do begin
      Oldest:=VectorHead; Candidate:=VectorHead.FCacheNext;
      while Candidate<>nil do begin
        if Candidate.FVectorStamp<Oldest.FVectorStamp then Oldest:=Candidate;
        Candidate:=Candidate.FCacheNext;
      end;
      Oldest.Clear;
    end;
    FVectorWidth:=Width; FVectorHeight:=Height; FVectorRegion:=Region; FVectorPicture:=TPicture.Create;
    try
      FTransparent:=DarkMode and not FPreserveColors and Supports(FVector,ITransparentVectorDocument,Transparent);
      Rendered:=False;
      if FTransparent then Rendered:=Transparent.RenderTransparent(FVectorPage,Width,Height,Region,FVectorPicture);
      if not Rendered then begin FTransparent:=False; Rendered:=FVector.RenderRegion(FVectorPage,Width,Height,Region,FVectorPicture); end;
      if not Rendered then FreeAndNil(FVectorPicture);
    except FreeAndNil(FVectorPicture); raise; end;
    if FVectorPicture<>nil then
    begin
      FCachedPixels:=Pixels; Inc(VectorPixels,FCachedPixels);
      FCacheNext:=VectorHead; if VectorHead<>nil then VectorHead.FCachePrevious:=Self; VectorHead:=Self;
    end;
  end;
end;
function TPreviewSurface.DrawVectorAt(Canvas:TCanvas; const Bounds:TRect; Width,Height:Integer):Boolean;
var Visible,Region,Part:TRect; Scale:Double; X,Y,TileW,TileH,Pixels:Integer;
  function PaintTile(const Region:TRect):Boolean;
  var Tile:TRect;
  begin
    PrepareVector(Width,Height,Region); Result:=FVectorPicture<>nil;
    if not Result then Exit;
    Tile:=Rect(Bounds.Left+Round(FVectorRegion.Left*Bounds.Width/Width),
      Bounds.Top+Round(FVectorRegion.Top*Bounds.Height/Height),
      Bounds.Left+Round(FVectorRegion.Right*Bounds.Width/Width),Bounds.Top+Round(FVectorRegion.Bottom*Bounds.Height/Height));
    DrawPixels(Canvas,Tile,Themed(FVectorPicture));
  end;
begin
  Result:=False; if (FVector=nil) or (Bounds.Width<1) or (Bounds.Height<1) then Exit;
  Scale:=PreviewCanvasScale(Canvas); Width:=Max(1,Round(Width*Scale)); Height:=Max(1,Round(Height*Scale));
  Region:=Rect(0,0,Width,Height);
  if PixelCost(Width,Height)>VectorCachePixels then begin
    Visible:=VisiblePreviewRect(Canvas,Bounds);
    if (Visible.Width<1) or (Visible.Height<1) then Exit(True);
    Region:=Rect(Max(0,Floor((Visible.Left-Bounds.Left)*Width/Bounds.Width)-32),
      Max(0,Floor((Visible.Top-Bounds.Top)*Height/Bounds.Height)-64),
      Min(Width,Ceil((Visible.Right-Bounds.Left)*Width/Bounds.Width)+32),
      Min(Height,Ceil((Visible.Bottom-Bounds.Top)*Height/Bounds.Height)+64));
  end;
  if PixelCost(Region.Width,Region.Height)<=VectorCachePixels then Exit(PaintTile(Region));
  { A high DPI viewport can itself exceed the budget. Draw bounded tiles
    rather than retaining an oversized raster after evicting every other page. }
  Pixels:=VectorCachePixels div PixelCost(1,1); TileW:=Min(Region.Width,Trunc(Sqrt(Pixels)));
  TileH:=Max(1,Pixels div Max(1,TileW)); Y:=Region.Top div TileH*TileH;
  while Y<Region.Bottom do begin
    X:=Region.Left div TileW*TileW;
    while X<Region.Right do begin
      Part:=Rect(X,Y,Min(Width,X+TileW),Min(Height,Y+TileH));
      if not PaintTile(Part) then Exit(False); Inc(X,TileW);
    end;
    Inc(Y,TileH);
  end;
  Result:=True;
end;
function TPreviewSurface.DrawVector(Canvas:TCanvas; const Bounds:TRect):Boolean;
begin Result:=DrawVectorAt(Canvas,Bounds,Bounds.Width,Bounds.Height); end;
procedure TPreviewSurface.Draw(Canvas:TCanvas; const Bounds:TRect; Picture:TPicture);
begin
  if not DrawVector(Canvas,Bounds) then DrawPixels(Canvas,Bounds,Themed(Picture));
end;
procedure TPreviewSurface.DrawPixels(Canvas:TCanvas; const Bounds:TRect; Picture:TPicture);
{$IFDEF LCLgtk3}var DC:TGtk3DeviceContext;
{$ELSE}var SavedCopyMode:LongInt;{$ENDIF}
begin
  if (Picture.Width<=0) or (Picture.Height<=0) or
     (Bounds.Right<=Bounds.Left) or (Bounds.Bottom<=Bounds.Top) then Exit;
  {$IFDEF LCLgtk3}
  if FPixels=nil then Decode(Picture);
  if FPixels=nil then Exit;
  DC:=TGtk3DeviceContext(Canvas.Handle);
  if (DC=nil) or (DC.pcr=nil) then Exit;
  cairo_save(DC.pcr);
  try
    cairo_new_path(DC.pcr);
    cairo_rectangle(DC.pcr,Bounds.Left,Bounds.Top,Bounds.Right-Bounds.Left,Bounds.Bottom-Bounds.Top);
    cairo_clip(DC.pcr);
    cairo_translate(DC.pcr,Bounds.Left,Bounds.Top);
    cairo_scale(DC.pcr,(Bounds.Right-Bounds.Left)/Picture.Width,(Bounds.Bottom-Bounds.Top)/Picture.Height);
    gdk_cairo_set_source_pixbuf(DC.pcr,FPixels,0,0);
    cairo_set_operator(DC.pcr,CAIRO_OPERATOR_OVER);
    cairo_paint(DC.pcr);
  finally cairo_restore(DC.pcr); end;
  {$ELSE}
  { A preview is already themed. Shared canvases can retain a raster
    operation from selection/caret painting; never apply it to PDF colors. }
  SavedCopyMode:=Canvas.CopyMode; Canvas.CopyMode:=cmSrcCopy;
  try Canvas.StretchDraw(Bounds,Picture.Graphic);
  finally Canvas.CopyMode:=SavedCopyMode; end;
  {$ENDIF}
end;
procedure TPreviewSurface.DrawRegion(Canvas:TCanvas; const Bounds,Source:TRect; Picture:TPicture);
var SX,SY:Double; R:TRect;
  {$IFDEF LCLgtk3}DC:TGtk3DeviceContext;{$ENDIF}
begin
  if (Source.Right<=Source.Left) or (Source.Bottom<=Source.Top) then Exit;
  SX:=(Bounds.Right-Bounds.Left)/(Source.Right-Source.Left);
  SY:=(Bounds.Bottom-Bounds.Top)/(Source.Bottom-Source.Top);
  R:=Rect(Bounds.Left-Round(Source.Left*SX),Bounds.Top-Round(Source.Top*SY),
    Bounds.Left+Round((Picture.Width-Source.Left)*SX),Bounds.Top+Round((Picture.Height-Source.Top)*SY));
  {$IFDEF LCLgtk3}
  DC:=TGtk3DeviceContext(Canvas.Handle);
  if (DC=nil) or (DC.pcr=nil) then Exit;
  cairo_save(DC.pcr);
  try
    cairo_new_path(DC.pcr);
    cairo_rectangle(DC.pcr,Bounds.Left,Bounds.Top,Bounds.Right-Bounds.Left,Bounds.Bottom-Bounds.Top);
    cairo_clip(DC.pcr);
    if (FVector=nil) or (FVectorZoom<=0) or
      not DrawVectorAt(Canvas,R,Round(Picture.Width*FVectorZoom),Round(Picture.Height*FVectorZoom)) then
      DrawPixels(Canvas,R,Themed(Picture));
  finally cairo_restore(DC.pcr); end;
  {$ELSE}
  Canvas.SaveHandleState;
  try
    IntersectClipRect(Canvas.Handle,Bounds.Left,Bounds.Top,Bounds.Right,Bounds.Bottom);
    if (FVector=nil) or (FVectorZoom<=0) or
      not DrawVectorAt(Canvas,R,Round(Picture.Width*FVectorZoom),Round(Picture.Height*FVectorZoom)) then
      DrawPixels(Canvas,R,Themed(Picture));
  finally Canvas.RestoreHandleState; end;
  {$ENDIF}
end;
constructor TPreviewImage.Create(AOwner:TComponent);
begin
  inherited Create(AOwner);
  FSurface:=TPreviewSurface.Create; FPicture:=TPicture.Create;
  FPicture.OnChange:=@PictureChanged;
  Color:=PaperColor; TabStop:=False; DoubleBuffered:=False;
  ControlStyle:=ControlStyle+[csOpaque];
end;
destructor TPreviewImage.Destroy;
begin FPicture.Free; FreeAndNil(FSurface); inherited Destroy; end;
procedure TPreviewImage.Resize;
begin
  inherited Resize;
  if FSurface<>nil then begin FSurface.Clear; Invalidate; end;
end;
procedure TPreviewImage.PictureChanged(Sender:TObject);
begin
  if not FLoadingPicture then begin
    FStoredPNG:=''; FPreviewWidth:=FPicture.Width; FPreviewHeight:=FPicture.Height;
  end;
  FSurface.Clear; if not FLoadingPicture then Invalidate;
end;
function TPreviewImage.GetPicture:TPicture;
var Stream:TStringStream;
begin
  if (FPicture.Width=0) and (FStoredPNG<>'') then begin
    Stream:=TStringStream.Create(FStoredPNG); FLoadingPicture:=True;
    try FPicture.LoadFromStream(Stream);
    finally FLoadingPicture:=False; Stream.Free; end;
  end;
  Result:=FPicture;
end;
procedure TPreviewImage.LoadPreview(const FileName:string);
var Stream:TFileStream; Bytes:RawByteString; W,H:Integer;
  function Dimension(Offset:Integer):Integer;
  begin
    Result:=(Ord(Bytes[Offset]) shl 24) or (Ord(Bytes[Offset+1]) shl 16) or
      (Ord(Bytes[Offset+2]) shl 8) or Ord(Bytes[Offset+3]);
  end;
begin
  Stream:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyWrite);
  try SetLength(Bytes,Stream.Size); if Bytes<>'' then Stream.ReadBuffer(Bytes[1],Length(Bytes));
  finally Stream.Free; end;
  if (Length(Bytes)<33) or (Copy(Bytes,1,8)<>#137+'PNG'+#13#10#26#10) or
     (Copy(Bytes,13,4)<>'IHDR') then
    raise Exception.Create('Invalid preview PNG');
  W:=Dimension(17); H:=Dimension(21);
  if (W<1) or (H<1) or (Int64(W)*H>64000000) then
    raise Exception.Create('Invalid preview dimensions');
  FStoredPNG:=Bytes; FPreviewWidth:=W; FPreviewHeight:=H;
  FLoadingPicture:=True;
  try FPicture.Clear; finally FLoadingPicture:=False; end;
  FSurface.SetVector(nil,0); Invalidate;
end;
procedure TPreviewImage.ReleaseRenderCache;
begin
  FSurface.Clear;
  if (FStoredPNG<>'') and (FPicture.Width>0) then begin
    FLoadingPicture:=True;
    try FPicture.Clear; finally FLoadingPicture:=False; end;
  end;
end;
procedure TPreviewImage.ClearPreview;
begin
  FSurface.SetVector(nil,0); FStoredPNG:=''; FPreviewWidth:=0; FPreviewHeight:=0; FSelection:=nil;
  FLoadingPicture:=True;
  try FPicture.Clear; finally FLoadingPicture:=False; end;
  Invalidate;
end;
function TPreviewImage.LoadVectorPreview(const Document:IVectorDocument; Page,DPI:Integer):Boolean;
var W,H:Double;
begin
  Result:=False;
  if (Document=nil) or (DPI<=0) or not Document.PageSize(Page,W,H) then Exit;
  W:=Ceil(W*DPI/72); H:=Ceil(H*DPI/72);
  if (W<1) or (H<1) or (W>MaxInt div 4) or (H>MaxInt div 4) then Exit;
  FStoredPNG:=''; FPreviewWidth:=Round(W); FPreviewHeight:=Round(H);
  FLoadingPicture:=True;
  try FPicture.Clear; finally FLoadingPicture:=False; end;
  FSurface.SetVector(Document,Page); Invalidate; Result:=True;
end;
procedure TPreviewImage.SetSelection(const Rects:TSelectionRects);
var I:Integer; Same:Boolean;
begin
  Same:=Length(Rects)=Length(FSelection);
  if Same then for I:=0 to High(Rects) do
    if not EqualRect(Rects[I],FSelection[I]) then begin Same:=False; Break; end;
  if Same then Exit;
  FSelection:=Copy(Rects); Invalidate;
end;
function TPreviewImage.DoMouseWheel(Shift:TShiftState; WheelDelta:Integer; MousePos:TPoint):Boolean;
var C:TWinControl;
begin
  C:=Parent;
  while C<>nil do begin
    if C is TScrollBox then begin
      SetPreviewScroll(TScrollBox(C),TScrollBox(C).HorzScrollBar.Position,
        TScrollBox(C).VertScrollBar.Position-Round(WheelDelta/120*72));
      Exit(True);
    end;
    C:=C.Parent;
  end;
  Result:=inherited DoMouseWheel(Shift,WheelDelta,MousePos);
end;
procedure TPreviewImage.Paint;
begin
  Canvas.Brush.Color:=PaperColor; Canvas.FillRect(ClientRect);
  { Keep the stored fallback PNG compressed while vector drawing succeeds. }
  if not FSurface.DrawVector(Canvas,ClientRect) then FSurface.Draw(Canvas,ClientRect,GetPicture);
  DrawSelectionOutline(Canvas,FSelection);
end;
end.
