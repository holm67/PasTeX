unit NativeDiagrams;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$modeswitch nestedprocvars}
interface
uses Classes, VectorPreview, TikZSketch;
type
  TDiagramText=record
    Bounds:TVectorImageBounds;
    Text,OptionKey,OptionScope,FontCode:string;
    ReplacementPrefix,ReplacementSuffix:string;
    Color:LongInt;
    First,Last,Owner,Index:Integer;
    Rotation:Double;
    MathLabel:Boolean;
  end;
  TDiagramTexts=array of TDiagramText;
function NativeDiagram(const Context,Source,Directory:string; out Bytes:Int64; const Engine:string='pdflatex'; Diagnostics:TStrings=nil; InputFiles:TStrings=nil):IVectorDocument;
function NativeDiagramTexts(const Document:IVectorDocument):TDiagramTexts;
function NativeDiagramHandles(const Document:IVectorDocument):TDiagramHandles;
function NativeDiagramSegments(const Document:IVectorDocument):TDiagramSegments;
function NativeDiagramCoordinate(const Document:IVectorDocument; NX,NY:Double; out X,Y:Double):Boolean;
function MoveNativeDiagramPoint(const Document:IVectorDocument; const Source:string; Index:Integer; NX,NY:Double):string;
function MoveNativeDiagramSegment(const Document:IVectorDocument; const Source:string; Index:Integer; DX,DY:Double):string;
procedure SetNativeDiagramEditingText(const Document:IVectorDocument; Index:Integer);
function ReplaceDiagramText(const Source:string; const Item:TDiagramText; const Text:string; const Labels:TDiagramTexts):string;
implementation
uses SysUtils, Types, Math, Graphics, Contnrs, FPExprPars, TeXMacros,
  TeXDocumentMetrics, StrUtils, DraftLayout, MathModel, ParagraphModel, PlotGeometry, PlotMath, TikZModel, TikZPath, DiagramCanvas, DiagramArrows, PlotColors, TikZGeometry, TikZGraph, CommutativeDiagrams, CircuitGeometry, TeXDataVisualization, TikZCalc
  {$IFDEF LCLgtk3}, Gtk3Objects, LazCairo1{$ENDIF};
{$IFDEF LCLgtk3}
type TWriteDiagramPNG=function(Closure,Data:Pointer; Length:Cardinal):Tcairo_status_t; cdecl;
function WriteDiagramSurface(Surface:Pcairo_surface_t; Writer:TWriteDiagramPNG; Closure:Pointer):Tcairo_status_t;
  cdecl; external LIB_CAIRO name 'cairo_surface_write_to_png_stream';
function WriteDiagramPNG(Closure,Data:Pointer; Length:Cardinal):Tcairo_status_t; cdecl;
begin
  try TStream(Closure).WriteBuffer(Data^,Length); Result:=CAIRO_STATUS_SUCCESS;
  except Result:=CAIRO_STATUS_WRITE_ERROR; end;
end;
{$ENDIF}
type
  TDiagramPoint=TPlotPoint;
  TDiagramPoints=TTikZPoints;
  TPrimitive=class
    Points:TDiagramPoints;
    Text:string;
    Kind:Integer;
    Stroke,Fill:TColor;
    Weight,Opacity,Rotation:Double;
    ColorMapName,ColorMapDefinition,MapAccess:string; ColorMap:TPlotColorMap;
    PathName,BetweenFirst,BetweenSecond:string;
    BoxSummary:TTikZNumbers;
    BoxPosition,BoxExtent,WhiskerExtent:Double;
    BoxEstimator:string; LowerQuantile,UpperQuantile,WhiskerRange:Double;
    BoxVertical,RawBox:Boolean;
    MetaMin,MetaMax:Double; HasMetaMin,HasMetaMax:Boolean;
    VertexColors:array of TColor;
    Dash:array of Double;
    ArrowKind,StartArrowKind,MarkKind:string;
    Cap,Join:Integer;
    Dashed,Arrow,StartArrow,Closed,Markers,OnlyMarks,Bars,Surface,SmoothShade,ThreeD:Boolean;
    GridCols,MarkerIndex:Integer;
    Depth:Double;
    LabelTree:TMathNode;
    LabelW,LabelH:Double;
    AnchorX,AnchorY:Double;
    NodeHalfW,NodeHalfH:Double;
    NodeCircle,Hidden,BackLayer:Boolean; NodeCenter:TDiagramPoint;
    CircuitPorts:TCircuitPorts;
    Edit:TDiagramText;
    constructor Create;
    destructor Destroy; override;
    function RetainedBytes:Int64;
  end;
  INativeDiagram=interface
    ['{9A1A7B42-906B-4C6D-87FA-67F5237E8B52}']
    function Labels:TDiagramTexts;
    function Handles:TDiagramHandles;
    function Segments:TDiagramSegments;
    function Coordinate(NX,NY:Double; out X,Y:Double):Boolean;
    function MovePoint(const Source:string; Index:Integer; NX,NY:Double):string;
    function MoveSegment(const Source:string; Index:Integer; DX,DY:Double):string;
    procedure HideText(Index:Integer);
  end;
  TNativeDiagram=class(TInterfacedObject,IVectorDocument,INativeDiagram,ITransparentVectorDocument)
    Items:TObjectList;
    LabelDraft:TParagraphDraft;
    Left,Bottom,Width,Height:Double;
    UnitScale:Double;
    EditPoints:TDiagramHandles;
    EditSegments:TDiagramSegments;
    Macros:TMacroRegistry;
    FontPoints:Integer;
    procedure ConfigureLabels(const Context,Directory,Engine:string; Registry:TMacroRegistry);
    function LayoutLabel(Item:TPrimitive; Canvas:TCanvas; Scale:Double):TRect;
    function Labels:TDiagramTexts;
    function Handles:TDiagramHandles;
    function Segments:TDiagramSegments;
    function Coordinate(NX,NY:Double; out X,Y:Double):Boolean;
    function MovePoint(const Source:string; Index:Integer; NX,NY:Double):string;
    function MoveSegment(const Source:string; Index:Integer; DX,DY:Double):string;
    procedure HideText(Index:Integer);
    constructor Create;
    destructor Destroy; override;
    function Render(Page,W,H:Integer; Picture:TPicture):Boolean;
    function RenderSmooth(W,H:Integer; const Region:TRect; Picture:TPicture; Opaque:Boolean=True):Boolean;
    function RenderTransparent(Page,W,H:Integer; const Region:TRect; Picture:TPicture):Boolean;
    function RenderRegion(Page,W,H:Integer; const Region:TRect; Picture:TPicture):Boolean;
    function PageSize(Page:Integer; out W,H:Double):Boolean;
    function ImageRegions(Page:Integer):TVectorImageRegions;
    function FindText(Page:Integer; const Text:string):TVectorImageRegions;
    function TextLayout(Page:Integer; out Text:string):TVectorImageRegions;
    function PageLinks(Page:Integer):TVectorLinks;
    procedure Measure;
  end;
constructor TPrimitive.Create;
begin
  Stroke:=clBlack; Fill:=clNone; Weight:=0.4*72/72.27; Opacity:=1;
  AnchorX:=0.5; AnchorY:=0.5; MarkerIndex:=-1; ArrowKind:='to'; ColorMapName:='hot'; MarkKind:='*';
  Edit.First:=-1; Edit.Last:=-1; Edit.Owner:=-1; Edit.Index:=-1;
end;
destructor TPrimitive.Destroy;
begin LabelTree.Free; inherited Destroy; end;
function MathTreeBytes(Node:TMathNode):Int64;
var I:Integer;
begin
  Result:=0; if Node=nil then Exit;
  Result:=Node.InstanceSize+Length(Node.Text)+Length(Node.Prefix)+Length(Node.Suffix)+
    Node.Children.InstanceSize+Int64(Node.Children.Capacity)*SizeOf(Pointer);
  Inc(Result,MathTreeBytes(Node.SourcePreview));
  for I:=0 to Node.Children.Count-1 do Inc(Result,MathTreeBytes(TMathNode(Node.Children[I])));
end;
function TPrimitive.RetainedBytes:Int64;
var I:Integer;
begin
  Result:=InstanceSize+Length(Text)+Length(ColorMapName)+Length(ColorMapDefinition)+Length(MapAccess)+
    Length(PathName)+Length(BetweenFirst)+Length(BetweenSecond)+Length(BoxEstimator)+
    Length(ArrowKind)+Length(StartArrowKind)+Length(MarkKind)+Length(Edit.Text)+
    Length(Edit.OptionKey)+Length(Edit.OptionScope)+Length(Edit.FontCode)+
    Length(Edit.ReplacementPrefix)+Length(Edit.ReplacementSuffix);
  Inc(Result,Int64(Length(Points))*SizeOf(TDiagramPoint)+Int64(Length(ColorMap))*SizeOf(TPlotColorStop)+
    Int64(Length(BoxSummary))*SizeOf(Double)+Int64(Length(VertexColors))*SizeOf(TColor)+
    Int64(Length(Dash))*SizeOf(Double)+Int64(Length(CircuitPorts))*SizeOf(TCircuitPort));
  for I:=0 to High(CircuitPorts) do Inc(Result,Length(CircuitPorts[I].Name));
  Inc(Result,MathTreeBytes(LabelTree));
end;
constructor TNativeDiagram.Create;
begin Items:=TObjectList.Create(True); end;
destructor TNativeDiagram.Destroy;
begin LabelDraft.Free; Items.Free; Macros.Free; inherited Destroy; end;
procedure TNativeDiagram.ConfigureLabels(const Context,Directory,Engine:string; Registry:TMacroRegistry);
begin
  LabelDraft:=TParagraphDraft.Create; LabelDraft.Macros:=Registry;
  LabelDraft.HeadingContext:=Context; LabelDraft.Directory:=Directory; LabelDraft.TeXEngine:=Engine;
  LabelDraft.DocumentFontSize:=FontPoints; LabelDraft.PreserveColors:=True; LabelDraft.HideEditingMarks:=True;
  LabelDraft.SuppressParagraphIndent:=True;
end;
function TNativeDiagram.LayoutLabel(Item:TPrimitive; Canvas:TCanvas; Scale:Double):TRect;
begin
  LabelDraft.Layout(Canvas,Item.LabelTree,Max(64,Round(2048*Scale)),True,FontPoints,nil,Item.Text,Scale,FontPoints*72/72.27*Scale);
  Result:=LabelDraft.ContentInkBounds;
end;
function TNativeDiagram.PageSize(Page:Integer; out W,H:Double):Boolean;
begin W:=Width; H:=Height; Result:=Page=1; end;
function TNativeDiagram.ImageRegions(Page:Integer):TVectorImageRegions;
begin Result:=nil; end;
function TNativeDiagram.FindText(Page:Integer; const Text:string):TVectorImageRegions;
begin Result:=nil; end;
function TNativeDiagram.TextLayout(Page:Integer; out Text:string):TVectorImageRegions;
begin Text:=''; Result:=nil; end;
function TNativeDiagram.PageLinks(Page:Integer):TVectorLinks;
begin Result:=nil; end;
function NativeDiagramTexts(const Document:IVectorDocument):TDiagramTexts;
var Native:INativeDiagram;
begin Result:=nil; if Supports(Document,INativeDiagram,Native) then Result:=Native.Labels; end;
function NativeDiagramHandles(const Document:IVectorDocument):TDiagramHandles;
var Native:INativeDiagram;
begin Result:=nil; if Supports(Document,INativeDiagram,Native) then Result:=Native.Handles; end;
function NativeDiagramSegments(const Document:IVectorDocument):TDiagramSegments;
var Native:INativeDiagram;
begin Result:=nil; if Supports(Document,INativeDiagram,Native) then Result:=Native.Segments; end;
function NativeDiagramCoordinate(const Document:IVectorDocument; NX,NY:Double; out X,Y:Double):Boolean;
var Native:INativeDiagram;
begin Result:=Supports(Document,INativeDiagram,Native) and Native.Coordinate(NX,NY,X,Y); end;
function MoveNativeDiagramPoint(const Document:IVectorDocument; const Source:string; Index:Integer; NX,NY:Double):string;
var Native:INativeDiagram;
begin Result:=Source; if Supports(Document,INativeDiagram,Native) then Result:=Native.MovePoint(Source,Index,NX,NY); end;
function TNativeDiagram.Handles:TDiagramHandles;
var I:Integer;
begin
  Result:=Copy(EditPoints);
  for I:=0 to High(Result) do begin Result[I].X:=(Result[I].X-Left)/Width; Result[I].Y:=(Bottom+Height-Result[I].Y)/Height; end;
end;
function TNativeDiagram.Segments:TDiagramSegments;
begin Result:=Copy(EditSegments); end;
function MoveNativeDiagramSegment(const Document:IVectorDocument; const Source:string; Index:Integer; DX,DY:Double):string;
var Native:INativeDiagram;
begin Result:=Source; if Supports(Document,INativeDiagram,Native) then Result:=Native.MoveSegment(Source,Index,DX,DY); end;
function TNativeDiagram.MoveSegment(const Source:string; Index:Integer; DX,DY:Double):string;
begin
  Result:=Source; if (Index<0) or (Index>=Length(EditSegments)) then Exit;
  Result:=TranslateDiagramSegment(Source,EditPoints,EditSegments[Index].First,EditSegments[Index].Last,DX*Width,-DY*Height);
end;
function TNativeDiagram.Coordinate(NX,NY:Double; out X,Y:Double):Boolean;
begin Result:=UnitScale>0; if Result then begin X:=(Left+NX*Width)/UnitScale; Y:=(Bottom+Height-NY*Height)/UnitScale; end; end;
function TNativeDiagram.MovePoint(const Source:string; Index:Integer; NX,NY:Double):string;
var Handle:TDiagramHandle; X,Y:Double;
begin
  Result:=Source; if (Index<0) or (Index>=Length(EditPoints)) then Exit; Handle:=EditPoints[Index];
  if Handle.Scale<=0 then Exit;
  X:=Handle.SourceX+(Left+NX*Width-Handle.X)/Handle.Scale;
  Y:=Handle.SourceY+(Bottom+Height-NY*Height-Handle.Y)/Handle.Scale;
  Result:=MoveDiagramPoint(Source,Handle.Command,Handle.Row,X,Y);
end;
procedure SetNativeDiagramEditingText(const Document:IVectorDocument; Index:Integer);
var Native:INativeDiagram;
begin if Supports(Document,INativeDiagram,Native) then Native.HideText(Index); end;
procedure TNativeDiagram.HideText(Index:Integer);
var I,N:Integer; Item:TPrimitive;
begin
  N:=0;
  for I:=0 to Items.Count-1 do begin
    Item:=TPrimitive(Items[I]); Item.Hidden:=False;
    if (Item.Kind<>2) or ((Item.Edit.First<0) and (Item.Edit.OptionKey='')) then Continue;
    Item.Hidden:=N=Index; Inc(N);
  end;
end;
function TNativeDiagram.Labels:TDiagramTexts;
var I,N,J:Integer; Item:TPrimitive; X,Y,RX,RY,MinX,MaxX,MinY,MaxY:Double;
begin
  Result:=nil;
  for I:=0 to Items.Count-1 do begin
    Item:=TPrimitive(Items[I]); if (Item.Kind<>2) or (Length(Item.Points)=0) then Continue;
    if (Item.Edit.First<0) and (Item.Edit.OptionKey='') then Continue;
    MinX:=MaxDouble; MinY:=MaxDouble; MaxX:=-MaxDouble; MaxY:=-MaxDouble;
    for J:=0 to 3 do begin
      X:=((J and 1)-Item.AnchorX)*Item.LabelW; Y:=(((J shr 1) and 1)-Item.AnchorY)*Item.LabelH;
      RX:=Item.Points[0].X+Cos(DegToRad(Item.Rotation))*X-Sin(DegToRad(Item.Rotation))*Y;
      RY:=Item.Points[0].Y+Sin(DegToRad(Item.Rotation))*X+Cos(DegToRad(Item.Rotation))*Y;
      MinX:=Min(MinX,RX); MaxX:=Max(MaxX,RX); MinY:=Min(MinY,RY); MaxY:=Max(MaxY,RY);
    end;
    N:=Length(Result); SetLength(Result,N+1); Result[N]:=Item.Edit; Result[N].Rotation:=Item.Rotation;
    Result[N].Bounds.Left:=(MinX-Left)/Width; Result[N].Bounds.Right:=(MaxX-Left)/Width;
    Result[N].Bounds.Top:=(Bottom+Height-MaxY)/Height; Result[N].Bounds.Bottom:=(Bottom+Height-MinY)/Height;
  end;
end;
function PlainLabel(const S:string):string; forward;
function ReplaceDiagramText(const Source:string; const Item:TDiagramText; const Text:string; const Labels:TDiagramTexts):string;
var Model:TDiagramModel; I,J,Count:Integer; Value,Options,Scoped:string; Values:array of string; Field:TDiagramOption;
begin
  Result:=Source;
  if Text=Item.Text then Exit;
  if Item.First>=0 then begin
    if (Item.Last<Item.First) or (Item.Last>Length(Source)) then Exit;
    Exit(Copy(Source,1,Item.First)+Item.ReplacementPrefix+Text+Item.ReplacementSuffix+Copy(Source,Item.Last+1,MaxInt));
  end;
  if (Item.Owner<0) or (Item.OptionKey='') then Exit;
  Model:=TDiagramModel.Create;
  try
    Model.Load(Source);
    for I:=0 to High(Model.Environments) do if Model.Environments[I].Source.First=Item.Owner then begin
      Value:=Text;
      if Item.Index>=0 then begin
        Count:=Item.Index+1;
        for J:=0 to High(Labels) do if (Labels[J].Owner=Item.Owner) and (Labels[J].OptionKey=Item.OptionKey) and (Labels[J].OptionScope=Item.OptionScope) then Count:=Max(Count,Labels[J].Index+1);
        SetLength(Values,Count);
        for J:=0 to High(Labels) do if (Labels[J].Owner=Item.Owner) and (Labels[J].OptionKey=Item.OptionKey) and (Labels[J].OptionScope=Item.OptionScope) and (Labels[J].Index>=0) then Values[Labels[J].Index]:=Labels[J].Text;
        Values[Item.Index]:=Text; Value:='';
        for J:=0 to Count-1 do begin if J>0 then Value:=Value+','; Value:=Value+'{'+Values[J]+'}'; end;
      end;
      Options:=Model.Text(Model.Environments[I].Options);
      if Item.OptionScope<>'' then begin
        Scoped:=''; for Field in DiagramOptions(Options) do if Field.Name=Item.OptionScope then Scoped:=PlainLabel(Field.Value);
        Scoped:=DiagramSetOption(Scoped,Item.OptionKey,'{'+Value+'}');
        Options:=DiagramSetOption(Options,Item.OptionScope,'{'+Scoped+'}');
      end else Options:=DiagramSetOption(Options,Item.OptionKey,'{'+Value+'}');
      Exit(Model.SetEnvironmentOptions(I,Options));
    end;
  finally Model.Free; end;
end;
procedure TNativeDiagram.Measure;
var Item:TPrimitive; P:TDiagramPoint; Right,Top,X,Y,RX,RY:Double; I,J:Integer;
  procedure TipBounds(First,Second:Integer; const Kind:string);
  var Contours:TArrowContours; Contour:TArrowContour; Point:TArrowPoint; A,UX,UY,X,Y:Double;
  begin
    if Kind='' then Exit;
    A:=ArcTan2(Item.Points[First].Y-Item.Points[Second].Y,Item.Points[First].X-Item.Points[Second].X);
    UX:=Cos(A); UY:=Sin(A); Contours:=ArrowContours(Kind,Item.Weight,1);
    for Contour in Contours do for Point in Contour.Points do begin
      X:=Item.Points[First].X+UX*Point.X+UY*Point.Y; Y:=Item.Points[First].Y+UY*Point.X-UX*Point.Y;
      Left:=Min(Left,X-Contour.PenWidth/2); Right:=Max(Right,X+Contour.PenWidth/2);
      Bottom:=Min(Bottom,Y-Contour.PenWidth/2); Top:=Max(Top,Y+Contour.PenWidth/2);
    end;
  end;
begin
  Left:=MaxDouble; Bottom:=MaxDouble; Right:=-MaxDouble; Top:=-MaxDouble;
  for I:=0 to Items.Count-1 do begin
    Item:=TPrimitive(Items[I]); for P in Item.Points do begin
    Left:=Min(Left,P.X); Bottom:=Min(Bottom,P.Y); Right:=Max(Right,P.X); Top:=Max(Top,P.Y);
    if Item.Kind=2 then begin
      for J:=0 to 3 do begin
        X:=((J and 1)-Item.AnchorX)*Item.LabelW; Y:=(((J shr 1) and 1)-Item.AnchorY)*Item.LabelH;
        RX:=P.X+Cos(DegToRad(Item.Rotation))*X-Sin(DegToRad(Item.Rotation))*Y;
        RY:=P.Y+Sin(DegToRad(Item.Rotation))*X+Cos(DegToRad(Item.Rotation))*Y;
        Left:=Min(Left,RX); Bottom:=Min(Bottom,RY); Right:=Max(Right,RX); Top:=Max(Top,RY);
      end;
    end;
  end;
    if not Item.Closed and (Length(Item.Points)>1) then begin
      if Item.Arrow then TipBounds(High(Item.Points),High(Item.Points)-1,Item.ArrowKind);
      if Item.StartArrow then TipBounds(0,1,Item.StartArrowKind);
    end;
  end;
  if Left=MaxDouble then begin
    { A picture containing only named coordinates has no painted bounds. }
    Left:=-6; Bottom:=-6; Width:=4*UnitScale+12; Height:=3*UnitScale+12; Exit;
  end;
  Left:=Left-6; Bottom:=Bottom-6; Width:=Max(16,Right-Left+6); Height:=Max(16,Top-Bottom+6);
end;
function TNativeDiagram.Render(Page,W,H:Integer; Picture:TPicture):Boolean;
begin Result:=RenderRegion(Page,W,H,Rect(0,0,W,H),Picture); end;
function TNativeDiagram.RenderTransparent(Page,W,H:Integer; const Region:TRect; Picture:TPicture):Boolean;
begin Result:=(Page=1) and RenderSmooth(W,H,Region,Picture,False); end;
function TNativeDiagram.RenderSmooth(W,H:Integer; const Region:TRect; Picture:TPicture; Opaque:Boolean):Boolean;
var Painter:TDiagramCanvas; Item:TPrimitive; I,J,LW,LH:Integer; SX,SY,X,Y,DX,DY,Angle,Radius:Double;
    Bitmap:TBitmap; Stream:TMemoryStream; Dashes:array of Double; MarkFill,FillColor:TColor; Corners:array[0..7] of Double; Bounds:TRect;
  function PX(const P:TDiagramPoint):Double;
  begin Result:=(P.X-Left)*SX-Region.Left; end;
  function PY(const P:TDiagramPoint):Double;
  begin Result:=(Bottom+Height-P.Y)*SY-Region.Top; end;
  procedure Tip(First,Second:Integer);
  var Kind:string;
  begin
    if Item.Stroke=clNone then Exit;
    Angle:=ArcTan2(PY(Item.Points[First])-PY(Item.Points[Second]),PX(Item.Points[First])-PX(Item.Points[Second]));
    Kind:=Item.ArrowKind; if (First=0) and (Item.StartArrowKind<>'') then Kind:=Item.StartArrowKind;
    Painter.Arrow(PX(Item.Points[First]),PY(Item.Points[First]),Angle,Item.Weight*SX,Item.Stroke,Kind,Item.Opacity,SX);
  end;
  procedure PathPoint(Index:Integer);
  var P,Other:TDiagramPoint; Distance,Shorten:Double; Kind:string;
  begin
    P:=Item.Points[Index]; X:=PX(P); Y:=PY(P);
    if ((Index=0) and Item.StartArrow) or ((Index=High(Item.Points)) and Item.Arrow) then begin
      if Index=0 then Other:=Item.Points[1] else Other:=Item.Points[Index-1];
      DX:=PX(Other)-X; DY:=PY(Other)-Y; Distance:=Hypot(DX,DY);
      if Distance>0 then begin
        Kind:=Item.ArrowKind; if (Index=0) and (Item.StartArrowKind<>'') then Kind:=Item.StartArrowKind;
        Shorten:=Min(Distance/2,DiagramArrowLineEnd(Item.Weight*SX,SX,Kind));
        X:=X+DX/Distance*Shorten; Y:=Y+DY/Distance*Shorten;
      end;
    end;
    if Index=0 then Painter.MoveTo(X,Y) else Painter.LineTo(X,Y);
  end;
begin
  Result:=False; if (Region.Width<=0) or (Region.Height<=0) or (Int64(Region.Width)*Region.Height>16*1024*1024) then Exit;
  Painter:=TDiagramCanvas.Create(Region.Width,Region.Height,Opaque);
  Bitmap:=nil; Stream:=nil;
  try
    if not Painter.Ready then Exit; SX:=W/Width; SY:=H/Height;
    Bitmap:=TBitmap.Create; Bitmap.SetSize(1,1); Stream:=TMemoryStream.Create;
    for J:=0 to Items.Count-1 do begin
      Item:=TPrimitive(Items[J]); if Item.Hidden or (Length(Item.Points)=0) then Continue;
      SetLength(Dashes,Length(Item.Dash)); for I:=0 to High(Dashes) do Dashes[I]:=Item.Dash[I]*SX;
      if Item.Dashed and (Length(Dashes)=0) then begin SetLength(Dashes,2); Dashes[0]:=3*SX; Dashes[1]:=3*SX; end;
      Painter.BeginPath;
      case Item.Kind of
        0:if not Item.OnlyMarks then begin
          PathPoint(0); for I:=1 to High(Item.Points) do PathPoint(I);
          if Item.Closed then Painter.ClosePath;
          FillColor:=Item.Fill;
          if (Length(Item.VertexColors)=4) and (Length(Item.Points)=4) then begin
            for I:=0 to 3 do begin Corners[2*I]:=PX(Item.Points[I]); Corners[2*I+1]:=PY(Item.Points[I]); end;
            if Painter.MeshPatch(Corners,Item.VertexColors,Item.Opacity) then FillColor:=clNone;
          end;
          Painter.Paint(Item.Stroke,FillColor,Item.Weight*SX,Dashes,Item.Opacity,Item.Cap,Item.Join);
        end;
        1:if Length(Item.Points)=2 then begin
          Painter.Ellipse((PX(Item.Points[0])+PX(Item.Points[1]))/2,(PY(Item.Points[0])+PY(Item.Points[1]))/2,
            Abs(PX(Item.Points[0])-PX(Item.Points[1]))/2,Abs(PY(Item.Points[0])-PY(Item.Points[1]))/2);
          Painter.Paint(Item.Stroke,Item.Fill,Item.Weight*SX,Dashes,Item.Opacity);
        end;
        2:begin
          { Rounded glyph metrics at the requested scale can exceed the
            one-point measurement. Size the text bitmap from its actual ink. }
          Bounds:=LayoutLabel(Item,Bitmap.Canvas,SX);
          LW:=Max(1,Bounds.Width)+4; LH:=Max(1,Bounds.Height)+4;
          if Int64(LW)*LH>4*1024*1024 then Exit;
          Bitmap.SetSize(LW,LH); Bitmap.Canvas.Brush.Color:=clWhite; Bitmap.Canvas.FillRect(Rect(0,0,LW,LH));
          LabelDraft.Paint(Bitmap.Canvas,nil,nil,2-Bounds.Left,2-Bounds.Top);
          Stream.Clear; DiagramBitmapPNG(Bitmap,Stream);
          X:=-(LW-4)*Item.AnchorX-2; Y:=-(LH-4)*(1-Item.AnchorY)-2; Angle:=-DegToRad(Item.Rotation);
          DX:=Cos(Angle)*X-Sin(Angle)*Y; DY:=Sin(Angle)*X+Cos(Angle)*Y;
          Painter.Image(Stream,PX(Item.Points[0])+DX,PY(Item.Points[0])+DY,LW,LH,Angle);
        end;
      end;
      if Item.Markers then for I:=0 to High(Item.Points) do if (Item.MarkerIndex<0) or (Item.MarkerIndex=I) then begin
        X:=PX(Item.Points[I]); Y:=PY(Item.Points[I]); Radius:=2*72/72.27*SX; Painter.BeginPath;
        if (Item.MarkKind='x') or (Item.MarkKind='+') then begin
          if Item.MarkKind='x' then Radius:=Radius/Sqrt(2);
          DX:=Radius; DY:=Radius; if Item.MarkKind='+' then begin DX:=0; DY:=Radius; end;
          Painter.MoveTo(X-DX,Y-DY); Painter.LineTo(X+DX,Y+DY);
          Painter.MoveTo(X-DY,Y+DX); Painter.LineTo(X+DY,Y-DX);
        end else if Pos('square',Item.MarkKind)=1 then begin
          Painter.MoveTo(X-Radius,Y-Radius); Painter.LineTo(X+Radius,Y-Radius); Painter.LineTo(X+Radius,Y+Radius); Painter.LineTo(X-Radius,Y+Radius); Painter.ClosePath;
        end else if Pos('triangle',Item.MarkKind)=1 then begin
          Painter.MoveTo(X,Y-Radius); Painter.LineTo(X+Radius,Y+Radius); Painter.LineTo(X-Radius,Y+Radius); Painter.ClosePath;
        end else Painter.Ellipse(X,Y,Radius,Radius);
        MarkFill:=Item.Stroke; if (Pos('*',Item.MarkKind)=0) then MarkFill:=clNone;
        Painter.Paint(Item.Stroke,MarkFill,Item.Weight*SX,[],Item.Opacity);
      end;
      if Length(Item.Points)>1 then begin
        if Item.Arrow then Tip(High(Item.Points),High(Item.Points)-1);
        if Item.StartArrow then Tip(0,1);
      end;
    end;
    Result:=Painter.Finish(Picture);
  finally Stream.Free; Bitmap.Free; Painter.Free; end;
end;
function TNativeDiagram.RenderRegion(Page,W,H:Integer; const Region:TRect; Picture:TPicture):Boolean;
var Bitmap:TBitmap; Item:TPrimitive; Points:array of TPoint; I,J:Integer; ScaleX,ScaleY,DX,DY,L:Double; A,B:TPoint;
    {$IFDEF LCLgtk3}Stream:TMemoryStream; DC:TGtk3DeviceContext;{$ENDIF}
  function Pixel(const P:TDiagramPoint):TPoint;
  begin Result:=Point(Round((P.X-Left)*ScaleX)-Region.Left,Round((Bottom+Height-P.Y)*ScaleY)-Region.Top); end;
begin
  Result:=False; if (Page<>1) or (Picture=nil) or (W<=0) or (H<=0) or
    (Region.Width<=0) or (Region.Height<=0) or (Int64(Region.Width)*Region.Height>16*1024*1024) then Exit;
  if RenderSmooth(W,H,Region,Picture) then Exit(True);
  Bitmap:=TBitmap.Create;
  try
    Bitmap.SetSize(Region.Width,Region.Height); Bitmap.Canvas.Brush.Color:=clWhite;
    Bitmap.Canvas.FillRect(Rect(0,0,Region.Width,Region.Height)); ScaleX:=W/Width; ScaleY:=H/Height;
    for J:=0 to Items.Count-1 do begin
      Item:=TPrimitive(Items[J]);
      if Item.Hidden or (Length(Item.Points)=0) then Continue;
      SetLength(Points,Length(Item.Points)); for I:=0 to High(Points) do Points[I]:=Pixel(Item.Points[I]);
      Bitmap.Canvas.Pen.Color:=Item.Stroke; Bitmap.Canvas.Pen.Width:=Max(1,Round(Item.Weight*ScaleX));
      Bitmap.Canvas.Pen.Style:=psSolid; if Item.Dashed then Bitmap.Canvas.Pen.Style:=psDash;
      Bitmap.Canvas.Brush.Style:=bsClear;
      if Item.Fill<>clNone then begin Bitmap.Canvas.Brush.Style:=bsSolid; Bitmap.Canvas.Brush.Color:=Item.Fill; end;
      case Item.Kind of
        0:if not Item.OnlyMarks then begin
          if Item.Closed then Bitmap.Canvas.Polygon(Points) else Bitmap.Canvas.Polyline(Points);
        end;
        1:if Length(Points)=2 then Bitmap.Canvas.Ellipse(Points[0].X,Points[1].Y,Points[1].X,Points[0].Y);
        2:begin
          LayoutLabel(Item,Bitmap.Canvas,ScaleX);
          LabelDraft.Paint(Bitmap.Canvas,nil,nil,Points[0].X-Round(Item.LabelW*Item.AnchorX*ScaleX)-10,
            Points[0].Y-Round(Item.LabelH*(1-Item.AnchorY)*ScaleY)-10);
        end;
      end;
      if Item.Markers then begin
        Bitmap.Canvas.Brush.Style:=bsSolid; Bitmap.Canvas.Brush.Color:=Item.Stroke;
        for I:=0 to High(Points) do if (Item.MarkerIndex<0) or (Item.MarkerIndex=I) then begin
          L:=Max(2,Round(2*ScaleX));
          if (Item.MarkKind='x') or (Item.MarkKind='+') then begin
            if Item.MarkKind='x' then begin DX:=L/Sqrt(2); DY:=DX; end else begin DX:=0; DY:=L; end;
            Bitmap.Canvas.Line(Points[I].X-Round(DX),Points[I].Y-Round(DY),Points[I].X+Round(DX),Points[I].Y+Round(DY));
            Bitmap.Canvas.Line(Points[I].X-Round(DY),Points[I].Y+Round(DX),Points[I].X+Round(DY),Points[I].Y-Round(DX));
          end else Bitmap.Canvas.Ellipse(Points[I].X-Round(L),Points[I].Y-Round(L),Points[I].X+Round(L),Points[I].Y+Round(L));
        end;
      end;
      if Item.Arrow and (Length(Points)>1) then begin
        A:=Points[High(Points)-1]; B:=Points[High(Points)]; DX:=B.X-A.X; DY:=B.Y-A.Y; L:=Hypot(DX,DY);
        if L>0 then begin
          Bitmap.Canvas.MoveTo(B.X-Round((5*DX+2*DY)*ScaleX/L),B.Y-Round((5*DY-2*DX)*ScaleY/L));
          Bitmap.Canvas.LineTo(B.X,B.Y);
          Bitmap.Canvas.LineTo(B.X-Round((5*DX-2*DY)*ScaleX/L),B.Y-Round((5*DY+2*DX)*ScaleY/L));
        end;
      end;
    end;
    {$IFDEF LCLgtk3}
    { Export Cairo's ARGB surface directly. GTK3's LCL bitmap readback
      describes its red/blue channels in the opposite order. }
    DC:=TGtk3DeviceContext(Bitmap.Canvas.Handle); if (DC=nil) or (DC.pcr=nil) then Exit;
    Stream:=TMemoryStream.Create;
    try
      if WriteDiagramSurface(cairo_get_target(DC.pcr),@WriteDiagramPNG,Stream)<>CAIRO_STATUS_SUCCESS then Exit;
      Stream.Position:=0; Picture.LoadFromStream(Stream);
    finally Stream.Free; end;
    {$ELSE}Picture.Assign(Bitmap);{$ENDIF}
    Result:=True;
  finally Bitmap.Free; end;
end;
function PointAt(X,Y:Double):TDiagramPoint;
begin Result.X:=X; Result.Y:=Y; Result.Z:=0; end;
function SurfaceOrder(A,B:Pointer):Integer;
begin Result:=CompareValue(TPrimitive(B).Depth,TPrimitive(A).Depth); end;
function SurfaceColor(Value:Double; Viridis:Boolean):TColor;
const Hot:array[0..3,0..2] of Byte=((0,0,255),(255,255,0),(255,128,0),(255,0,0));
      Green:array[0..17,0..2] of Byte=((68,1,84),(72,23,105),(71,42,122),(67,61,132),
        (61,78,138),(53,94,141),(46,109,142),(41,123,142),(35,137,142),(31,151,139),
        (33,165,133),(46,179,124),(70,192,111),(101,203,94),(137,213,72),(176,221,47),
        (216,226,25),(253,231,37));
var Index,Top:Integer; T:Double;
begin
  Top:=3; if Viridis then Top:=High(Green); T:=EnsureRange(Value,0.0,1.0)*Top; Index:=Min(Top-1,Floor(T)); T:=T-Index;
  if Viridis then Result:=RGBToColor(Round(Green[Index,0]*(1-T)+Green[Index+1,0]*T),
    Round(Green[Index,1]*(1-T)+Green[Index+1,1]*T),Round(Green[Index,2]*(1-T)+Green[Index+1,2]*T))
  else Result:=RGBToColor(Round(Hot[Index,0]*(1-T)+Hot[Index+1,0]*T),
    Round(Hot[Index,1]*(1-T)+Hot[Index+1,1]*T),Round(Hot[Index,2]*(1-T)+Hot[Index+1,2]*T));
end;
function Numeric(const S:string; var Value:Double):Boolean;
var F:TFormatSettings; Parsed:Double;
begin F:=DefaultFormatSettings; F.DecimalSeparator:='.'; Result:=TryStrToFloat(Trim(S),Parsed,F) and not IsNan(Parsed) and not IsInfinite(Parsed); if Result then Value:=Parsed; end;
function LengthPoints(const S:string; Default,TextWidth:Double):Double;
var P:Integer; N:Double; UnitName:string;
begin
  Result:=Default; P:=1; while (P<=Length(S)) and (S[P] in ['0'..'9','-','+','.']) do Inc(P);
  if not Numeric(Copy(S,1,P-1),N) then Exit;
  UnitName:=Trim(Copy(S,P,MaxInt));
  case UnitName of
    'cm':Result:=N*72/2.54; 'mm':Result:=N*72/25.4; 'in':Result:=N*72;
    'pt':Result:=N*72/72.27; 'bp':Result:=N; '\linewidth','\textwidth','\columnwidth':Result:=N*TextWidth;
  end;
end;
procedure ReadOptions(const S:string; Options:TStrings);
var Fields:TDiagramOptions; Field:TDiagramOption; A,B:Double; AngleValue:string;
begin
  Fields:=DiagramOptions(S);
  for Field in Fields do begin
    if Field.HasValue then begin
      if (Field.Name='rotate') and Numeric(Options.Values[Field.Name],A) and Numeric(Field.Value,B) then
        begin Str(A+B:0:8,AngleValue); Options.Values[Field.Name]:=AngleValue; end else Options.Values[Field.Name]:=Field.Value;
    end else Options.Values[Field.Name]:='true';
  end;
end;
function PlainLabel(const S:string):string;
begin
  Result:=Trim(S); if (Length(Result)>1) and (Result[1]='{') and (Result[Length(Result)]='}') then Result:=Copy(Result,2,Length(Result)-2);
end;
function ExplicitTicks(const Code:string):TPlotTicks;
var Fields:TDiagramOptions; I,N,K:Integer; Value,Limit,Step,Start:Double;
  procedure Append(Value:Double);
  begin
    if N=200 then raise EConvertError.Create('Native tick list exceeds 200 entries');
    Result[N]:=Value; Inc(N);
  end;
begin
  { Match pgffor's numeric ellipsis: infer the step from the previous two
    values, or use +/-1. Keep a strict budget for malformed/live input. }
  Result:=nil; if PlainLabel(Code)='\empty' then Exit;
  Fields:=DiagramOptions(PlainLabel(Code));
  SetLength(Result,200); N:=0; I:=0;
  while I<Length(Fields) do begin
    if Fields[I].Name='...' then begin
      if (N=0) or (I=High(Fields)) or not Numeric(Fields[I+1].Name,Limit) then
        raise EConvertError.Create('Incomplete native tick range');
      Start:=Result[N-1]; Step:=1; if Limit<Start then Step:=-1;
      if N>1 then Step:=Start-Result[N-2];
      if (Step=0) or ((Limit-Start)*Step<0) then raise EConvertError.Create('Invalid native tick range step');
      K:=1;
      repeat
        Value:=Start+K*Step;
        if (Value-Limit)*Sign(Step)>Abs(Step)*1e-7 then Break;
        Append(Value); Inc(K);
      until False;
      Inc(I);
    end else begin
      if not Numeric(Fields[I].Name,Value) then raise EConvertError.Create('Unsupported native tick value: '+Fields[I].Name);
      Append(Value);
    end;
    Inc(I);
  end;
  SetLength(Result,N);
end;
{$I nativecommutative.inc}
function NativeDiagram(const Context,Source,Directory:string; out Bytes:Int64; const Engine:string; Diagnostics:TStrings; InputFiles:TStrings):IVectorDocument;
var Scene:TNativeDiagram; Options,Style,AxisDefaults,TikZDefaults:TStringList; Registry:TMacroRegistry; Parser:TFPExpressionParser;
    P,Q,A,I,J,K,Count,Rows,TotalPoints,AxisOwner,CommandStart:Integer; Command,Environment,Body,Word,NodeName,TablePath:string;
    Item,Plot,LabelItem:TPrimitive; First,Next,RelativeBase,NodePosition:TDiagramPoint; NodeAt:Boolean;
    Scale,Radius,Step,XMin,XMax,YMin,YMax,ZMin,ZMax,MetaMin,MetaMax,PlotWidth,PlotHeight,V,X,Y,Z,DomainMin,DomainMax,YDomainMin,YDomainMax,Azimuth,Elevation:Double;
    InAxis,PGFPlotsAxis,HasXMin,HasXMax,HasYMin,HasYMax,HasZMin,HasZMax,ThreeD,Circuitikz:Boolean;
    Plots,Legends,Surfaces:TList; VariableX,VariableY,VariableT:TFPExprIdentifierDef; Info:TMacroInfo; Measure:TBitmap;
    GlobalStyle,NodeStyle,Colors,Nodes,NamedPaths,StyleNames,GroupOptions,CircuitDefaults,CircuitOptions:TStringList; LegendW,LegendH,LX,LY:Double; Geometry:TPlotGeometry;
    Model:TDiagramModel; CaptionRange:TDiagramRange; AxisPrevious:TList; UseCycle,ExplicitStyle:Boolean; StatementIndex:Integer;
    Polar,LogX,LogY,InGroup:Boolean; GroupIndex,GroupColumns:Integer; GroupWidth,GroupHeight:Double;
    Scopes:array of record Style:string; First,FirstHandle:Integer; end;
    PendingNodeEnd,PendingCoordinate,Scan,ScanStart:Integer; PathNodePosition:Double;
    DataOptions:TDiagramOptions; DataDefaults:string; Calc:TTikZCalc;
  const PathCommands:array[0..6] of string=('draw','fill','filldraw','path','node','coordinate','pic');
  procedure Point(Item:TPrimitive; const Value:TDiagramPoint);
  var K:Integer;
  begin K:=Length(Item.Points); SetLength(Item.Points,K+1); Item.Points[K]:=Value; end;
  procedure RememberStyles(Values:TStrings);
  var I:Integer; Key:string;
  begin
    for I:=0 to Values.Count-1 do begin
      Key:=Values.Names[I];
      if RightStr(Key,7)='/.style' then StyleNames.Values[Copy(Key,1,Length(Key)-7)]:=PlainLabel(Values.ValueFromIndex[I]);
    end;
  end;
  procedure ExpandStyle(const Code:string; Values:TStrings; Depth:Integer=0);
  var Entry:TDiagramOption; Value:string;
  begin
    if Depth>8 then Exit;
    for Entry in DiagramOptions(Code) do begin
      Value:=StyleNames.Values[Entry.Name];
      if not Entry.HasValue and (Value<>'') then ExpandStyle(Value,Values,Depth+1)
      else if Entry.HasValue then Values.Values[Entry.Name]:=Entry.Value else Values.Values[Entry.Name]:='true';
    end;
  end;
  function Caption(const Code:string; var Position:Integer; Base:Integer=0):string;
  var Range:TDiagramRange;
  begin
    Result:=''; if not DiagramGroup(Code,Position,'{','}',Range) then Exit;
    Result:=Copy(Code,Range.First+1,Range.Last-Range.First);
    CaptionRange.First:=Base+Range.First; CaptionRange.Last:=Base+Range.Last;
  end;
  procedure BindRange;
  begin
    if LabelItem=nil then Exit;
    LabelItem.Edit.First:=CaptionRange.First; LabelItem.Edit.Last:=CaptionRange.Last;
    LabelItem.Edit.Text:=Copy(Source,CaptionRange.First+1,CaptionRange.Last-CaptionRange.First);
  end;
  function BindDataLabel(const Path:array of string):Boolean;
  var Fields:TDiagramOptions; Entry:TDiagramOption; Range:TDiagramRange; I:Integer; Found:Boolean;
  begin
    Result:=False; if LabelItem=nil then Exit; Fields:=DataOptions;
    for I:=0 to High(Path) do begin
      Found:=False;
      for Entry in Fields do if Entry.Name=Path[I] then begin Range:=Entry.ValueRange; Found:=Entry.HasValue; Break; end;
      if not Found then Exit;
      Fields:=DiagramOptions(Copy(Source,Range.First+1,Range.Last-Range.First),Range.First);
    end;
    LabelItem.Edit.First:=Range.First; LabelItem.Edit.Last:=Range.Last;
    LabelItem.Edit.Text:=Copy(Source,Range.First+1,Range.Last-Range.First); Result:=True;
  end;
  procedure BindOption(const Key:string; Index:Integer=-1; const Scope:string='');
  var Fields,Entries:TDiagramOptions; I,Position:Integer; Range,Group:TDiagramRange; Value:string;
  begin
    if LabelItem=nil then Exit;
    if AxisOwner<0 then begin
      if (Options.Values['@datavis']='true') and ((Key='xlabel') or (Key='ylabel')) then
        if not BindDataLabel([Key[1]+' axis','label','text']) then BindDataLabel([Key[1]+' axis','label']);
      Exit;
    end;
    LabelItem.Edit.Owner:=Model.Environments[AxisOwner].Source.First;
    LabelItem.Edit.OptionKey:=Key; LabelItem.Edit.Index:=Index; LabelItem.Edit.OptionScope:=Scope;
    Fields:=DiagramOptions(Model.Text(Model.Environments[AxisOwner].Options),Model.Environments[AxisOwner].Options.First);
    if Scope<>'' then begin
      Entries:=nil;
      for I:=0 to High(Fields) do if Fields[I].Name=Scope then begin
        Range:=Fields[I].ValueRange;
        Entries:=DiagramOptions(Copy(Source,Range.First+1,Range.Last-Range.First),Range.First); Break;
      end;
      Fields:=Entries;
    end;
    for I:=0 to High(Fields) do if Fields[I].Name=Key then begin
      Range:=Fields[I].ValueRange;
      if Index>=0 then begin
        Value:=Copy(Source,Range.First+1,Range.Last-Range.First); Entries:=DiagramOptions(Value,Range.First);
        if Index>High(Entries) then Exit; Range:=Entries[Index].Source;
        Value:=Copy(Source,Range.First+1,Range.Last-Range.First); Position:=1;
        if DiagramGroup(Value,Position,'{','}',Group) then begin Inc(Group.First,Range.First); Inc(Group.Last,Range.First); Range:=Group; end;
      end;
      LabelItem.Edit.First:=Range.First; LabelItem.Edit.Last:=Range.Last;
      LabelItem.Edit.Text:=Copy(Source,Range.First+1,Range.Last-Range.First); Exit;
    end;
  end;
  function ResolvePoint(const Name:string; out Value:TPlotPoint):Boolean;
  var Dot,Index,I:Integer; Key,Anchor:string; Node:TPrimitive;
  begin
    Result:=False; Value:=Default(TPlotPoint); Dot:=Pos('.',Name); Key:=Name;
    if Dot>0 then Key:=Copy(Name,1,Dot-1);
    Index:=Nodes.IndexOf(Trim(Key)); if Index<0 then Exit;
    Node:=TPrimitive(Nodes.Objects[Index]); Value:=Node.NodeCenter;
    if Dot>0 then begin
      Anchor:=Trim(Copy(Name,Dot+1,MaxInt));
      for I:=0 to High(Node.CircuitPorts) do if Node.CircuitPorts[I].Name=Anchor then begin Value:=Node.CircuitPorts[I].Position; Break; end;
      if Node.CircuitPorts=nil then begin
        if Pos('west',Anchor)>0 then Value.X:=Value.X-Node.NodeHalfW;
        if Pos('east',Anchor)>0 then Value.X:=Value.X+Node.NodeHalfW;
        if Pos('north',Anchor)>0 then Value.Y:=Value.Y+Node.NodeHalfH;
        if Pos('south',Anchor)>0 then Value.Y:=Value.Y-Node.NodeHalfH;
      end;
    end;
    Value.X:=Value.X/Scale; Value.Y:=Value.Y/Scale; Result:=True;
  end;
  function Coordinate(const Text:string; var Position:Integer; out Value:TDiagramPoint):Boolean;
  begin Result:=Calc.Coordinate(Text,Position,Value); end;
  function PathCoordinate(var Position:Integer; out Value:TDiagramPoint):Boolean;
  var Relative,Update:Boolean;
  begin
    SkipTeXSpace(Body,Position); Relative:=Copy(Body,Position,1)='+'; Update:=True;
    if Relative then begin Inc(Position); Update:=Copy(Body,Position,1)='+'; if Update then Inc(Position); end;
    Result:=Coordinate(Body,Position,Value); if not Result then Exit;
    if Relative then begin Value.X:=Value.X+RelativeBase.X; Value.Y:=Value.Y+RelativeBase.Y; end;
    if Update then RelativeBase:=Value;
  end;
  procedure PathHandles(Index:Integer; Node:TPrimitive=nil);
  var Rows:TDiagramPathRows; Row:TDiagramPathRow; I,P,N,First,Previous:Integer; Value,RawValue,Base:TDiagramPoint; Code:string; Relative,Update:Boolean;
    procedure Edge(A,B:Integer);
    var K:Integer;
    begin
      if (A<0) or (B<0) then Exit; K:=Length(Scene.EditSegments); SetLength(Scene.EditSegments,K+1);
      Scene.EditSegments[K].First:=A; Scene.EditSegments[K].Last:=B;
    end;
  begin
    Rows:=ParseDiagramPath(Model.Text(Model.Commands[Index].Body),Node<>nil); Base:=PointAt(0,0); First:=-1; Previous:=-1;
    for I:=0 to High(Rows) do begin
      Row:=Rows[I]; if Row.Operation='cycle' then begin Edge(Previous,First); Continue; end;
      if not ((Row.Operation='move') or (Row.Operation='line') or (Row.Operation='to') or (Row.Operation='rectangle') or (Row.Operation='node') or
        (Row.Operation='|-') or (Row.Operation='-|')) then Continue;
      Relative:=False;
      if Node<>nil then begin Value:=PointAt(Node.NodeCenter.X/Scale,Node.NodeCenter.Y/Scale); RawValue:=Value; end
      else begin
        Code:=Trim(Row.Coordinate); if Code='' then Continue; if not (Code[1] in ['(','+']) then Code:='('+Code+')'; P:=1;
        Relative:=Copy(Code,P,1)='+'; Update:=True;
        if Relative then begin Inc(P); Update:=Copy(Code,P,1)='+'; if Update then Inc(P); end;
        if not Coordinate(Code,P,Value) then Continue;
        RawValue:=Value;
        if Relative then begin Value.X:=Value.X+Base.X; Value.Y:=Value.Y+Base.Y; end;
        if Update and (Row.Operation<>'node') then Base:=Value;
      end;
      N:=Length(Scene.EditPoints); if N>=2048 then Exit; SetLength(Scene.EditPoints,N+1);
      Scene.EditPoints[N].Command:=Index; Scene.EditPoints[N].Row:=I;
      Scene.EditPoints[N].X:=Value.X*Scale; Scene.EditPoints[N].Y:=Value.Y*Scale; Scene.EditPoints[N].Scale:=Scale;
      if Relative then begin Scene.EditPoints[N].SourceX:=RawValue.X; Scene.EditPoints[N].SourceY:=RawValue.Y; end
      else begin Scene.EditPoints[N].SourceX:=Value.X; Scene.EditPoints[N].SourceY:=Value.Y; end;
      if (Row.Operation='line') or (Row.Operation='to') then Edge(Previous,N);
      if Row.Operation<>'node' then begin if Row.Operation='move' then First:=N; Previous:=N; end;
    end;
  end;
  function ColorValue(const Value:string; out Color:TColor; Depth:Integer=0):Boolean;
  var S,A,B,Model:string; K,N,Q:Integer; Part,Other:TColor; Values:TStringList; R,G,Blue:Double;
  begin
    Result:=False; if Depth>8 then Exit; S:=Trim(Value);
    if (Copy(S,1,1)='{') and (Copy(S,Length(S),1)='}') then S:=Copy(S,2,Length(S)-2);
    K:=Pos('!',S);
    if K>0 then begin
      A:=Copy(S,1,K-1); B:=Copy(S,K+1,MaxInt); K:=Pos('!',B);
      if K>0 then begin N:=StrToIntDef(Copy(B,1,K-1),50); B:=Copy(B,K+1,MaxInt); end
      else begin N:=StrToIntDef(B,50); B:='white'; end;
      if not ColorValue(A,Part,Depth+1) or not ColorValue(B,Other,Depth+1) then Exit;
      N:=EnsureRange(N,0,100); Part:=ColorToRGB(Part); Other:=ColorToRGB(Other);
      Color:=RGBToColor(((Part and 255)*N+(Other and 255)*(100-N)) div 100,
        (((Part shr 8) and 255)*N+((Other shr 8) and 255)*(100-N)) div 100,
        (((Part shr 16) and 255)*N+((Other shr 16) and 255)*(100-N)) div 100); Exit(True);
    end;
    Result:=True;
    case S of
      'none':Color:=clNone; 'black':Color:=clBlack; 'white':Color:=clWhite; 'red':Color:=clRed; 'blue':Color:=clBlue;
      'green':Color:=RGBToColor(0,255,0); 'cyan':Color:=RGBToColor(0,255,255);
      'magenta':Color:=RGBToColor(255,0,255); 'yellow':Color:=clYellow;
      'gray':Color:=RGBToColor(128,128,128); 'lightgray':Color:=RGBToColor(191,191,191);
      'darkgray':Color:=RGBToColor(64,64,64); 'orange':Color:=RGBToColor(255,128,0);
      'purple':Color:=RGBToColor(191,0,64); 'violet':Color:=RGBToColor(128,0,128);
      'brown':Color:=RGBToColor(191,128,64); 'teal':Color:=RGBToColor(0,128,128);
      'lime':Color:=RGBToColor(191,255,0); 'olive':Color:=RGBToColor(128,128,0);
      'pink':Color:=RGBToColor(255,191,191);
      else begin
        A:=Colors.Values[S]; K:=Pos(':',A); if K=0 then Exit(False);
        Model:=Copy(A,1,K-1); A:=Copy(A,K+1,MaxInt);
        if Model='HTML' then begin Q:=StrToIntDef('$'+A,0); Color:=RGBToColor(Q shr 16,(Q shr 8) and 255,Q and 255); Exit; end;
        Values:=TStringList.Create;
        try
          Values.StrictDelimiter:=True; Values.Delimiter:=','; Values.DelimitedText:=A;
          R:=0; G:=0; Blue:=0;
          if (Values.Count=3) and Numeric(Values[0],R) and Numeric(Values[1],G) and Numeric(Values[2],Blue) then begin
            if Model='rgb' then begin R:=R*255; G:=G*255; Blue:=Blue*255; end;
            Color:=RGBToColor(EnsureRange(Round(R),0,255),EnsureRange(Round(G),0,255),EnsureRange(Round(Blue),0,255));
          end else if (Model='gray') and Numeric(A,R) then Color:=RGBToColor(Round(R*255),Round(R*255),Round(R*255))
          else Result:=False;
        finally Values.Free; end;
      end;
    end;
  end;
  function ArrowColors(const Specification:string):string;
  var P,A:Integer; Code,Group:string; Fields:TDiagramOptions; Field:TDiagramOption; Color:TColor;
    function HexColor(Color:TColor):string;
    begin
      Color:=ColorToRGB(Color); Result:='#'+IntToHex(Color and 255,2)+IntToHex((Color shr 8) and 255,2)+IntToHex((Color shr 16) and 255,2);
    end;
  begin
    Result:=''; Code:=Specification; P:=1;
    while P<=Length(Code) do begin
      if Code[P]<>'[' then begin Result:=Result+Code[P]; Inc(P); Continue; end;
      Group:=ReadTeXGroup(Code,P,'[',']'); Fields:=DiagramOptions(Group);
      for A:=0 to High(Fields) do begin
        Field:=Fields[A];
        if ((Field.Name='color') or (Field.Name='fill') or (Field.Name='draw')) and (PlainLabel(Field.Value)<>'none') and
          ColorValue(Field.Value,Color) then Fields[A].Value:=HexColor(Color)
        else if not Field.HasValue and ColorValue(Field.Name,Color) then begin
          Fields[A].Name:='color'; Fields[A].HasValue:=True; Fields[A].Value:=HexColor(Color);
        end;
      end;
      Result:=Result+'['+DiagramOptionSource(Fields)+']';
    end;
  end;
  procedure ApplyStyle(Item:TPrimitive);
  var DefaultTip,StartDefault,StartSpecification,EndSpecification,TipMode:string;
    procedure ReadStyle(Values:TStrings);
    var Key,Value,StartTip,EndTip:string; Color:TColor; K:Integer; Fields:TDiagramOptions;
    begin
      for Key in Values do begin
        { A flag such as -{Kite[length=8pt]} contains an inner equals sign.
          Split the stored name/value only at the top level. }
        Fields:=DiagramOptions(Key); if Length(Fields)<>1 then Continue;
        Word:=Fields[0].Name; Value:=Fields[0].Value;
        if ColorValue(Word,Color) then Item.Stroke:=Color;
        if (Word='draw') or (Word='color') then if ColorValue(Value,Color) then Item.Stroke:=Color;
        if Word='fill' then if ColorValue(Value,Color) then Item.Fill:=Color;
        if Pos('colormap/',Word)=1 then Item.ColorMapName:=Copy(Word,10,MaxInt);
        if ((Word='arrows') and ArrowSpecification(Value,StartTip,EndTip)) or ArrowSpecification(Word,StartTip,EndTip) then begin
          Item.StartArrow:=StartTip<>''; Item.Arrow:=EndTip<>'';
          StartSpecification:=StartTip; EndSpecification:=EndTip;
        end;
        case Word of
          '>':begin DefaultTip:=PlainLabel(Value); StartDefault:=DefaultTip; end;
          '<':StartDefault:=PlainLabel(Value);
          'tips':TipMode:=Value;
          'ultra thin':Item.Weight:=0.1*72/72.27; 'very thin':Item.Weight:=0.2*72/72.27; 'thin':Item.Weight:=0.4*72/72.27;
          'semithick':Item.Weight:=0.6*72/72.27; 'thick':Item.Weight:=0.8*72/72.27; 'very thick':Item.Weight:=1.2*72/72.27;
          'ultra thick':Item.Weight:=1.6*72/72.27;
          'line width':Item.Weight:=LengthPoints(Value,Item.Weight,DocumentTextWidth(Context));
          'opacity','draw opacity':Numeric(Value,Item.Opacity);
          'fill opacity':Numeric(Value,Item.Opacity);
          'name path','name path global':Item.PathName:=PlainLabel(Value);
          'line cap':case Value of 'round':Item.Cap:=1; 'rect':Item.Cap:=2; else Item.Cap:=0; end;
          'line join':case Value of 'round':Item.Join:=1; 'bevel':Item.Join:=2; else Item.Join:=0; end;
          'dashed','densely dashed','loosely dashed':begin
            SetLength(Item.Dash,2); Item.Dash[0]:=3*72/72.27; Item.Dash[1]:=Item.Dash[0];
            if Word='densely dashed' then Item.Dash[1]:=2*72/72.27 else if Word='loosely dashed' then Item.Dash[1]:=6*72/72.27;
            Item.Dashed:=True;
          end;
          'dotted','densely dotted','loosely dotted':begin
            SetLength(Item.Dash,2); Item.Dash[0]:=Item.Weight; Item.Dash[1]:=2*72/72.27; Item.Cap:=1;
            if Word='densely dotted' then Item.Dash[1]:=72/72.27 else if Word='loosely dotted' then Item.Dash[1]:=4*72/72.27;
          end;
          'solid':begin Item.Dashed:=False; Item.Dash:=nil; end;
          '->':Item.Arrow:=True; '<-':Item.StartArrow:=True; '<->':begin Item.StartArrow:=True; Item.Arrow:=True; end;
          '-Stealth','-Latex','-stealth','-latex':begin Item.Arrow:=True; Item.ArrowKind:=Copy(Word,2,MaxInt); end;
          'only marks':begin Item.Markers:=True; Item.OnlyMarks:=True; end;
          'mark':begin Item.Markers:=Value<>'none'; Item.MarkKind:=Value; end; 'ybar':Item.Bars:=True;
          'surf':Item.Surface:=True;
          'colormap name':Item.ColorMapName:=PlainLabel(Value);
          'colormap':begin Item.ColorMapDefinition:=Value; K:=1; Item.ColorMapName:=ReadTeXGroup(Value,K,'{','}'); end;
          'colormap access':Item.MapAccess:=Value;
          'point meta min':Item.HasMetaMin:=Numeric(Value,Item.MetaMin);
          'point meta max':Item.HasMetaMax:=Numeric(Value,Item.MetaMax);
          'shader':Item.SmoothShade:=Value='interp';
        end;
      end;
    end;
  begin
    DefaultTip:='to'; StartDefault:=DefaultTip; StartSpecification:=''; EndSpecification:=''; TipMode:='on draw';
    ReadStyle(GlobalStyle); if InAxis then ReadStyle(Options); ReadStyle(Style);
    Item.ArrowKind:=ArrowColors(ResolveArrowDefault(EndSpecification,DefaultTip,False));
    Item.StartArrowKind:=ArrowColors(ResolveArrowDefault(StartSpecification,StartDefault,True));
    if (TipMode='false') or (TipMode='never') then begin Item.Arrow:=False; Item.StartArrow:=False; end;
  end;
  procedure LabelAt(const Caption:string; const Position:TDiagramPoint);
  var R:TRect; K:Integer; CaptionSource,FontCode,Anchor:string; Color:TColor; Separation:Double;
    procedure TextStyle(Values:TStrings);
    var Entry,Key,Value:string; C:TColor;
    begin
      for Entry in Values do begin
        K:=Pos('=',Entry); Key:=Copy(Entry,1,K-1); Value:=Copy(Entry,K+1,MaxInt);
        if ColorValue(Key,C) then Color:=C;
        if (Key='color') or (Key='text') then if ColorValue(Value,C) then Color:=C;
        if Key='font' then FontCode:=PlainLabel(Value);
      end;
    end;
  begin
    LabelItem:=nil; CaptionSource:=PlainLabel(Caption); if CaptionSource='' then Exit;
    Color:=clBlack; FontCode:=''; TextStyle(GlobalStyle); TextStyle(Style); TextStyle(NodeStyle);
    if FontCode<>'' then CaptionSource:='{'+FontCode+' '+CaptionSource+'}';
    Color:=ColorToRGB(Color); CaptionSource:='\textcolor[HTML]{'+IntToHex(Color and 255,2)+
      IntToHex((Color shr 8) and 255,2)+IntToHex((Color shr 16) and 255,2)+'}{'+CaptionSource+'}';
    LabelItem:=TPrimitive.Create; LabelItem.Kind:=2; LabelItem.Text:=CaptionSource; LabelItem.Edit.Text:=PlainLabel(Caption);
    LabelItem.Edit.FontCode:=FontCode; LabelItem.Edit.Color:=Color;
    Scene.Items.Add(LabelItem);
    LabelItem.LabelTree:=ParseParagraph(CaptionSource,Registry); R:=Scene.LayoutLabel(LabelItem,Measure.Canvas,1);
    LabelItem.LabelW:=R.Width; LabelItem.LabelH:=R.Height;
    Anchor:=NodeStyle.Values['anchor'];
    if (NodeStyle.IndexOfName('above')>=0) or (NodeStyle.IndexOfName('above right')>=0) or (NodeStyle.IndexOfName('above left')>=0) or (Pos('south',Anchor)>0) then LabelItem.AnchorY:=0;
    if (NodeStyle.IndexOfName('below')>=0) or (NodeStyle.IndexOfName('below right')>=0) or (NodeStyle.IndexOfName('below left')>=0) or (Pos('north',Anchor)>0) then LabelItem.AnchorY:=1;
    if (NodeStyle.IndexOfName('right')>=0) or (NodeStyle.IndexOfName('above right')>=0) or (NodeStyle.IndexOfName('below right')>=0) or (Pos('west',Anchor)>0) then LabelItem.AnchorX:=0;
    if (NodeStyle.IndexOfName('left')>=0) or (NodeStyle.IndexOfName('above left')>=0) or (NodeStyle.IndexOfName('below left')>=0) or (Pos('east',Anchor)>0) then LabelItem.AnchorX:=1;
    Point(LabelItem,Position); LabelItem.NodeCenter:=Position;
    Numeric(NodeStyle.Values['rotate'],LabelItem.Rotation);
    LabelItem.Points[0].X:=LabelItem.Points[0].X+LengthPoints(NodeStyle.Values['xshift'],0,DocumentTextWidth(Context));
    LabelItem.Points[0].Y:=LabelItem.Points[0].Y+LengthPoints(NodeStyle.Values['yshift'],0,DocumentTextWidth(Context));
    Separation:=LengthPoints(NodeStyle.Values['inner sep'],Scene.FontPoints/3*72/72.27,DocumentTextWidth(Context));
    if LabelItem.AnchorX=0 then LabelItem.Points[0].X:=LabelItem.Points[0].X+Separation
    else if LabelItem.AnchorX=1 then LabelItem.Points[0].X:=LabelItem.Points[0].X-Separation;
    if LabelItem.AnchorY=0 then LabelItem.Points[0].Y:=LabelItem.Points[0].Y+Separation
    else if LabelItem.AnchorY=1 then LabelItem.Points[0].Y:=LabelItem.Points[0].Y-Separation;
  end;
  {$I nativepathops.inc}
  function ExpandConstants(const S:string):string;
  var Position,Pass:Integer; Name,Replacement:string;
  begin
    Result:=S;
    for Pass:=1 to 8 do begin
      Position:=1; Replacement:='';
      while Position<=Length(Result) do begin
        if Result[Position]<>'\' then begin Replacement:=Replacement+Result[Position]; Inc(Position); Continue; end;
        Name:=ReadTeXCommand(Result,Position); Info:=Registry.Find(Name);
        if (Name='x') or (Name='y') or (Name='t') then begin Replacement:=Replacement+Name; Continue; end;
        if (Info=nil) or not Info.Expandable or (Info.ArgCount<>0) then Exit('');
        Replacement:=Replacement+Info.Body;
        if Length(Replacement)>4096 then Exit('');
      end;
      Result:=Replacement; if Pos('\',Result)=0 then Exit;
    end;
  end;
  function PlotExpression(const S:string):string;
  begin
    Result:=PlotMathExpression(ExpandConstants(S),Options.Values['trig format plots']<>'rad');
  end;
  {$I nativeplotdata.inc}
  function SamplePlot(Item:TPrimitive; Parametric:Boolean):Boolean;
  var N,R,I,J,C:Integer; Value:TDiagramPoint; Fields:TDiagramOptions; Expressions:array[0..2] of string;
      Code,Tuple:string; Lower,Upper,YLower,YUpper,T,U:Double;
  begin
    Result:=False; Lower:=DomainMin; Upper:=DomainMax; YLower:=YDomainMin; YUpper:=YDomainMax;
    Code:=Style.Values['domain']; C:=Pos(':',Code);
    if C>0 then begin Numeric(Copy(Code,1,C-1),Lower); Numeric(Copy(Code,C+1,MaxInt),Upper); end;
    Code:=Style.Values['y domain']; C:=Pos(':',Code);
    if C>0 then begin Numeric(Copy(Code,1,C-1),YLower); Numeric(Copy(Code,C+1,MaxInt),YUpper); end;
    if Upper<=Lower then Exit;
    Code:=Style.Values['samples']; if Code='' then Code:=Options.Values['samples']; N:=EnsureRange(StrToIntDef(Code,25),2,512); R:=1;
    if Parametric then begin
      Tuple:=ReadTeXGroup(Source,P,'(',')'); Fields:=DiagramOptions(Tuple);
      if Length(Fields)<>2+Ord(Item.ThreeD) then Exit;
      for C:=0 to High(Fields) do Expressions[C]:=PlotExpression(PlainLabel(Fields[C].Name));
    end else begin
      Expressions[0]:=PlotExpression(ReadTeXGroup(Source,P,'{','}')); if Expressions[0]='' then Exit;
      if Item.ThreeD then begin
        N:=Min(40,N); Code:=Style.Values['samples y']; if Code='' then Code:=Options.Values['samples y'];
        R:=EnsureRange(StrToIntDef(Code,N),1,40); Item.GridCols:=N;
      end;
    end;
    for J:=0 to R-1 do for I:=0 to N-1 do begin
      T:=Lower+(Upper-Lower)*I/(N-1); U:=0; if R>1 then U:=YLower+(YUpper-YLower)*J/(R-1);
      VariableX.AsFloat:=T; VariableT.AsFloat:=T; VariableY.AsFloat:=U; Value:=PointAt(T,U);
      if Parametric then for C:=0 to 1+Ord(Item.ThreeD) do begin
        Parser.Expression:=Expressions[C]; T:=Parser.AsFloat;
        if IsNan(T) or IsInfinite(T) or (Abs(T)>1e8) then Exit;
        case C of 0:Value.X:=T; 1:Value.Y:=T; 2:Value.Z:=T; end;
      end else begin
        Parser.Expression:=Expressions[0]; T:=Parser.AsFloat;
        if IsNan(T) or IsInfinite(T) or (Abs(T)>1e8) then Exit;
        if Item.ThreeD then Value.Z:=T else Value.Y:=T;
      end;
      Point(Item,Value);
    end;
    Result:=True;
  end;
  function Project(const P:TDiagramPoint):TDiagramPoint;
  var Value:TDiagramPoint;
  begin
    if Polar then Exit(PointAt(PlotWidth/2+Cos(DegToRad(P.X))*P.Y/Max(1e-9,YMax)*PlotWidth/2,
      PlotHeight/2+Sin(DegToRad(P.X))*P.Y/Max(1e-9,YMax)*PlotHeight/2));
    Value:=P;
    if LogX then Value.X:=Ln(Max(1e-20,Value.X)); if LogY then Value.Y:=Ln(Max(1e-20,Value.Y));
    Result:=Geometry.Project(Value);
  end;
  procedure Enlarge(var Minimum,Maximum:Double; HasMin,HasMax:Boolean; const Key:string);
  var Setting:string; Extra:Double;
  begin
    if Polar and (Key='x') then Exit;
    Setting:=Options.Values['enlarge '+Key+' limits']; if Setting='' then Setting:=Options.Values['enlargelimits'];
    if Setting='false' then Exit;
    if ((Options.Values['axis lines']='middle') or (Options.Values['axis '+Key+' line']='middle')) and
       ((Setting='') or (Setting='auto')) then Exit;
    if ThreeD and (Key<>'z') and ((Setting='') or (Setting='auto')) then Exit;
    Extra:=0.1; if (Setting<>'') and (Setting<>'auto') and (Setting<>'true') and not Numeric(Setting,Extra) then Exit;
    Extra:=(Maximum-Minimum)*Max(0.0,Extra);
    if not Polar and (not HasMin or (Setting='true')) then Minimum:=Minimum-Extra;
    if not HasMax or (Setting='true') then Maximum:=Maximum+Extra;
  end;
  procedure LabelOptions;
  var Anchor,Value,Prefix:string; P,C:Integer; Offset:TDiagramPoint;
  begin
    if LabelItem=nil then Exit;
    Anchor:=PlainLabel(NodeStyle.Values['anchor']);
    if (Anchor<>'') and (Pos('near ',Anchor)<>1) then begin
      LabelItem.AnchorX:=0.5; LabelItem.AnchorY:=0.5;
      if Pos('west',Anchor)>0 then LabelItem.AnchorX:=0 else if Pos('east',Anchor)>0 then LabelItem.AnchorX:=1;
      if Pos('south',Anchor)>0 then LabelItem.AnchorY:=0 else if Pos('north',Anchor)>0 then LabelItem.AnchorY:=1;
    end;
    Value:=PlainLabel(NodeStyle.Values['at']); C:=Pos(':',Value); Prefix:='';
    if C>0 then begin Prefix:=Trim(Copy(Value,2,C-2)); Value:='('+Copy(Value,C+1,MaxInt); end;
    P:=1;
    if Coordinate(Value,P,Offset) then begin
      if (Prefix='axis description cs') or (Prefix='rel axis cs') then begin Offset.X:=Offset.X*PlotWidth; Offset.Y:=Offset.Y*PlotHeight; end
      else if Prefix='axis cs' then Offset:=Project(Offset)
      else if Prefix='' then begin Offset.X:=Offset.X*Scale; Offset.Y:=Offset.Y*Scale; end else Exit;
      LabelItem.Points[0]:=Offset;
    end;
  end;
  procedure Axis(const A,B:TDiagramPoint; const Key,Caption:string; Labels:Boolean=True);
  var Start,Finish,Position,Value,Normal,TickDirection:TDiagramPoint; Tick,Grid:TPrimitive;
      Values,GridValues:TPlotTicks; Explicit,Text:string; L,Lower,Upper,Distance,AxisLength,TickWidth,Outside,LabelOffset,About:Double;
      Index,MinTicks,Minor,MinorCount:Integer; TickPos,LabelPos,AxisLine,OtherLine,OtherKey:string; BaseRotation:Double; Direction:TDiagramPoint; DrawTicks,DrawLabels,Obscured,DrawGrid:Boolean; Names:TStringList; Entries:TDiagramOptions; Entry:TDiagramOption; F:TFormatSettings;
    procedure GridLine(const At:TDiagramPoint; Minor:Boolean);
    begin
      Grid:=TPrimitive.Create; Grid.Stroke:=$BFBFBF; Grid.Weight:=0.2; Scene.Items.Insert(AxisPrevious.Count,Grid);
      Style.Clear; Style.Values['color']:='black!25'; ReadOptions(PlainLabel(Options.Values['grid style']),Style);
      if Minor then ReadOptions(PlainLabel(Options.Values['minor grid style']),Style)
      else ReadOptions(PlainLabel(Options.Values['major grid style']),Style);
      ApplyStyle(Grid); Grid.Markers:=False;
      if Key='x' then begin Point(Grid,PointAt(At.X,0)); Point(Grid,PointAt(At.X,PlotHeight)); end
      else begin Point(Grid,PointAt(0,At.Y)); Point(Grid,PointAt(PlotWidth,At.Y)); end;
    end;
    procedure SetValue(var P:TDiagramPoint; N:Double);
    begin if Key='x' then P.X:=N else if Key='y' then P.Y:=N else P.Z:=N; end;
    procedure TickLine(Direction:TDiagramPoint; Reverse:Boolean);
    var Size:Double;
    begin
      Size:=Hypot(Direction.X,Direction.Y); if Size<1e-8 then Exit;
      Direction.X:=Direction.X/Size; Direction.Y:=Direction.Y/Size;
      if Reverse then begin Direction.X:=-Direction.X; Direction.Y:=-Direction.Y; end;
      Tick:=TPrimitive.Create; Scene.Items.Add(Tick); Tick.BackLayer:=ThreeD;
      Style.Clear; Style.Values['color']:='gray'; Style.Values['very thin']:='true';
      ReadOptions(PlainLabel(Options.Values['every tick/.style']),Style);
      ReadOptions(PlainLabel(Options.Values['tick style']),Style);
      ReadOptions(PlainLabel(Options.Values['major tick style']),Style); ReadOptions(PlainLabel(Options.Values[Key+' tick style']),Style);
      ReadOptions(PlainLabel(Options.Values['major '+Key+' tick style']),Style); ApplyStyle(Tick); Tick.Markers:=False;
      if not DrawTicks then Tick.Stroke:=clNone;
      Point(Tick,PointAt(Position.X-Direction.X*Outside,Position.Y-Direction.Y*Outside));
      Point(Tick,PointAt(Position.X+Direction.X*(TickWidth-Outside),Position.Y+Direction.Y*(TickWidth-Outside)));
    end;
  begin
    Start:=Project(A); Finish:=Project(B); AxisLength:=Hypot(Finish.X-Start.X,Finish.Y-Start.Y); if AxisLength<1e-6 then Exit;
    Item:=TPrimitive.Create; Scene.Items.Insert(AxisPrevious.Count,Item); Point(Item,Start); Point(Item,Finish); Item.BackLayer:=ThreeD;
    Item.Arrow:=not ThreeD and (Options.Values['axis lines']='middle');
    Style.Clear; ReadOptions(PlainLabel(Options.Values['axis line style']),Style);
    ReadOptions(PlainLabel(Options.Values[Key+' axis line style']),Style); ApplyStyle(Item); Item.Markers:=False;
    Normal:=PointAt((Finish.Y-Start.Y)/AxisLength,-(Finish.X-Start.X)/AxisLength);
    if (not ThreeD and (Key='y') and (Options.Values['axis lines']='middle')) or
       ((ThreeD or (Options.Values['axis lines']<>'middle')) and
        (Normal.X*((Start.X+Finish.X)/2-PlotWidth/2)+Normal.Y*((Start.Y+Finish.Y)/2-PlotHeight/2)<0)) then begin
      Normal.X:=-Normal.X; Normal.Y:=-Normal.Y;
    end;
    DrawTicks:=True; DrawLabels:=Labels;
    if not ThreeD then begin
      TickPos:=Options.Values[Key+'tick pos']; if TickPos='' then TickPos:=Options.Values['tick pos'];
      LabelPos:=Options.Values[Key+'ticklabel pos']; if LabelPos='' then LabelPos:=Options.Values['ticklabel pos'];
      if (TickPos='lower') or (TickPos='left') then DrawTicks:=Labels
      else if (TickPos='upper') or (TickPos='right') then DrawTicks:=not Labels;
      if (LabelPos='upper') or (LabelPos='right') then DrawLabels:=not Labels;
    end;
    if Key='x' then begin Lower:=XMin; Upper:=XMax; end else if Key='y' then begin Lower:=YMin; Upper:=YMax; end
    else begin Lower:=ZMin; Upper:=ZMax; end;
    Distance:=0; Numeric(Options.Values[Key+'tick distance'],Distance); MinTicks:=StrToIntDef(Options.Values['try min ticks'],IfThen(ThreeD,3,4));
    L:=35; Numeric(Options.Values['max space between ticks'],L); Values:=PlotTicks(Lower,Upper,AxisLength,Distance,MinTicks,L);
    if Options.Values['@datavis']='true' then begin
      About:=5; Numeric(Options.Values[Key+' tick about'],About); Values:=DataVisualizationTicks(Lower,Upper,Distance,About);
    end;
    Names:=TStringList.Create;
    try
      Explicit:=Options.Values[Key+'tick'];
      if Options.IndexOfName(Key+'tick')>=0 then Values:=ExplicitTicks(Explicit);
      Entries:=DiagramOptions(PlainLabel(Options.Values[Key+'ticklabels']));
      for Entry in Entries do Names.Add(PlainLabel(Entry.Name));
      F:=DefaultFormatSettings; F.DecimalSeparator:='.'; TickWidth:=0.15*72/2.54;
      TickWidth:=LengthPoints(Options.Values['major tick length'],TickWidth,DocumentTextWidth(Context));
      Outside:=0; Text:=Options.Values[Key+'tick align']; if Text='' then Text:=Options.Values['tick align'];
      if (Text='') and ((Options.Values['axis lines']='middle') or (Options.Values['axis '+Key+' line']='middle')) then Text:='center';
      if Text='outside' then Outside:=TickWidth else if Text='center' then Outside:=TickWidth/2;
      LabelOffset:=0;
      DrawGrid:=(Options.Values['grid']='major') or (Options.Values['grid']='both') or (Options.Values[Key+'majorgrids']='true');
      MinorCount:=EnsureRange(StrToIntDef(Options.Values[Key+' minor tick num'],0),0,50);
      GridValues:=Values;
      if Options.Values['@datavis']='true' then begin
        About:=5;
        if Options.Values[Key+' grid step']='ticks' then Numeric(Options.Values[Key+' tick about'],About)
        else begin Distance:=0; Numeric(Options.Values[Key+' grid step'],Distance); Numeric(Options.Values[Key+' grid about'],About); end;
        if (Options.Values[Key+' grid step']<>'ticks') or (Explicit='') then
          GridValues:=DataVisualizationTicks(Lower,Upper,Distance,About,True);
        if Options.Values[Key+' grid at']<>'' then GridValues:=ExplicitTicks(Options.Values[Key+' grid at']);
      end;
      if not ThreeD and Labels and DrawGrid and (MinorCount>0) then
        for Index:=0 to High(GridValues)-1 do for Minor:=1 to MinorCount do begin
          L:=GridValues[Index]+(GridValues[Index+1]-GridValues[Index])*Minor/(MinorCount+1);
          if (L<Lower) or (L>Upper) then Continue; Value:=A; SetValue(Value,L); GridLine(Project(Value),True);
        end;
      if not ThreeD and Labels and DrawGrid then for Index:=0 to High(GridValues) do begin
        if (GridValues[Index]<Lower) or (GridValues[Index]>Upper) then Continue;
        Value:=A; SetValue(Value,GridValues[Index]); GridLine(Project(Value),False);
      end;
      for Index:=0 to High(Values) do begin
        if (Values[Index]<Lower-1e-8) or (Values[Index]>Upper+1e-8) then Continue;
        Obscured:=False; AxisLine:=Options.Values['axis '+Key+' line']; if AxisLine='' then AxisLine:=Options.Values['axis lines'];
        OtherKey:='y'; if Key='y' then OtherKey:='x'; OtherLine:=Options.Values['axis '+OtherKey+' line']; if OtherLine='' then OtherLine:=Options.Values['axis lines'];
        { pgfplotsticks' tickshow check suppresses ticks at an axis crossing.
          Explicit tick labels follow the same rule unless the user disables it. }
        if not ThreeD and (AxisLine='middle') and (Options.Values['hide obscured '+Key+' ticks']<>'false') and
          (Options.Values['axis '+OtherKey+' line shift']='') then begin
          if (OtherLine='middle') or (OtherLine='center') then Obscured:=Abs(Values[Index])<1e-8
          else if (OtherLine='') or (OtherLine='box') then Obscured:=(Abs(Values[Index]-Lower)<1e-8) or (Abs(Values[Index]-Upper)<1e-8)
          else if (OtherLine='left') or (OtherLine='bottom') then Obscured:=Abs(Values[Index]-Lower)<1e-8
          else if (OtherLine='right') or (OtherLine='top') then Obscured:=Abs(Values[Index]-Upper)<1e-8;
        end;
        Value:=A; SetValue(Value,Values[Index]); Position:=Project(Value);
        if ThreeD then begin
          if Key='z' then begin
            TickLine(Geometry.XVector,Abs(A.X-XMax)<1e-8); TickLine(Geometry.YVector,Abs(A.Y-YMax)<1e-8);
          end else TickLine(Geometry.ZVector,Abs(A.Z-ZMax)<1e-8);
        end else if not Obscured then begin TickDirection:=PointAt(-Normal.X,-Normal.Y); TickLine(TickDirection,False); end;
        if not DrawLabels or Obscured then Continue;
        Text:='$'+FloatToStrF(Values[Index],ffGeneral,6,0,F)+'$'; if Index<Names.Count then Text:=Names[Index];
        Style.Clear; NodeStyle.Clear; ReadOptions(PlainLabel(Options.Values['tick label style']),NodeStyle);
        ReadOptions(PlainLabel(Options.Values[Key+' tick label style']),NodeStyle);
        ReadOptions(PlainLabel(Options.Values[Key+'ticklabel style']),NodeStyle);
        LabelAt(Text,PointAt(Position.X+Normal.X*(Outside+3),Position.Y+Normal.Y*(Outside+3)));
        BindOption(Key+'ticklabels',Index);
        if LabelItem<>nil then begin
          LabelItem.AnchorX:=(1-Normal.X)/2; LabelItem.AnchorY:=(1-Normal.Y)/2;
          LabelOptions; LabelOffset:=Max(LabelOffset,Abs(Normal.X)*LabelItem.LabelW+Abs(Normal.Y)*LabelItem.LabelH);
        end;
      end;
      Style.Clear; NodeStyle.Clear; BaseRotation:=0;
      if ((Key='y') and not ThreeD and (Options.Values['axis lines']<>'middle')) or (Key='z') then BaseRotation:=90;
      if Options.IndexOfName('every axis '+Key+' label/.style')>=0 then BaseRotation:=0;
      ReadOptions(PlainLabel(Options.Values['every axis label/.style']),NodeStyle);
      ReadOptions(PlainLabel(Options.Values['every axis '+Key+' label/.style']),NodeStyle);
      ReadOptions(PlainLabel(Options.Values['every axis '+Key+' label/.append style']),NodeStyle);
      ReadOptions(PlainLabel(Options.Values['label style']),NodeStyle);
      ReadOptions(PlainLabel(Options.Values[Key+' label style']),NodeStyle);
      ReadOptions(PlainLabel(Options.Values[Key+'label style']),NodeStyle);
      Position:=PointAt((Start.X+Finish.X)/2,(Start.Y+Finish.Y)/2);
      if not ThreeD and (Options.Values['axis lines']='middle') then begin
        Position:=Finish;
        if Key='x' then begin Position.Y:=Position.Y+3; Position.X:=Position.X-3; end
        else begin Position.X:=Position.X+3; Position.Y:=Position.Y-3; end;
      end else begin Position.X:=Position.X+Normal.X*(LabelOffset+6); Position.Y:=Position.Y+Normal.Y*(LabelOffset+6); end;
      LabelAt(Caption,Position); BindOption(Key+'label');
      if LabelItem<>nil then begin
        if not ThreeD and (Options.Values['axis lines']='middle') then begin
          if Key='x' then begin LabelItem.AnchorX:=1; LabelItem.AnchorY:=0; end
          else begin LabelItem.AnchorX:=0; LabelItem.AnchorY:=1; end;
        end else begin
          LabelItem.AnchorX:=(1-Normal.X)/2; LabelItem.AnchorY:=(1-Normal.Y)/2;
          if BaseRotation=90 then begin LabelItem.AnchorX:=0.5; LabelItem.AnchorY:=0; end;
        end;
        for Text in ['x','y','z'] do if NodeStyle.IndexOfName('sloped like '+Text+' axis')>=0 then begin
          if Text='x' then Direction:=Geometry.XVector else if Text='y' then Direction:=Geometry.YVector else Direction:=Geometry.ZVector;
          BaseRotation:=RadToDeg(ArcTan2(Direction.Y,Direction.X));
          if BaseRotation>90 then BaseRotation:=BaseRotation-180 else if BaseRotation< -90 then BaseRotation:=BaseRotation+180;
        end;
        LabelItem.Rotation:=LabelItem.Rotation+BaseRotation; LabelOptions;
      end;
    finally Names.Free; end;
  end;
  procedure PlotRange(Item:TPrimitive);
  var P:TDiagramPoint;
  begin
    for P in Item.Points do begin
      if not HasXMin then XMin:=Min(XMin,P.X); if not HasXMax then XMax:=Max(XMax,P.X);
      if not HasYMin then YMin:=Min(YMin,P.Y);
      if not HasYMax then if Polar then YMax:=Max(YMax,Abs(P.Y)) else YMax:=Max(YMax,P.Y);
      if not HasZMin then ZMin:=Min(ZMin,P.Z); if not HasZMax then ZMax:=Max(ZMax,P.Z);
    end;
    if Item.Bars then begin if not HasYMin then YMin:=Min(0,YMin); if not HasYMax then YMax:=Max(0,YMax); end;
  end;
  function MappedColor(Plot:TPrimitive; Value:Double):TColor;
  var T:Double;
  begin
    T:=(Value-Plot.MetaMin)/Max(1e-12,Plot.MetaMax-Plot.MetaMin);
    if Length(Plot.ColorMap)>0 then Result:=PlotMapColor(Plot.ColorMap,T,(Plot.MapAccess='piecewise constant') or (Plot.MapAccess='const'))
    else Result:=SurfaceColor(T,Plot.ColorMapName='viridis');
  end;
  procedure AddMeshEdge(Plot:TPrimitive; A,B:Integer);
  var Item:TPrimitive;
  begin
    Item:=TPrimitive.Create; Scene.Items.Add(Item); Item.Weight:=Plot.Weight;
    Item.Stroke:=MappedColor(Plot,(Plot.Points[A].Z+Plot.Points[B].Z)/2);
    Point(Item,Project(Plot.Points[A])); Point(Item,Project(Plot.Points[B]));
  end;
  procedure StartAxis(const AxisName:string);
  begin
    AxisPrevious.Assign(Scene.Items); Plots.Clear; Legends.Clear; ThreeD:=False;
    XMin:=MaxDouble; XMax:=-MaxDouble; YMin:=MaxDouble; YMax:=-MaxDouble; ZMin:=MaxDouble; ZMax:=-MaxDouble;
    DomainMin:=-5; DomainMax:=5; YDomainMin:=-5; YDomainMax:=5; Azimuth:=DegToRad(25); Elevation:=DegToRad(30);
    AxisOwner:=Model.AxisAt(CommandStart);
    Polar:=AxisName='polaraxis'; LogX:=(AxisName='semilogxaxis') or (AxisName='loglogaxis') or (Options.Values['xmode']='log');
    LogY:=(AxisName='semilogyaxis') or (AxisName='loglogaxis') or (Options.Values['ymode']='log');
    InAxis:=True; PGFPlotsAxis:=True; PlotWidth:=LengthPoints(Options.Values['width'],240,DocumentTextWidth(Context));
    if Polar then PlotHeight:=PlotWidth else PlotHeight:=160;
    PlotHeight:=LengthPoints(Options.Values['height'],PlotHeight,DocumentTextWidth(Context));
    Word:=Options.Values['domain']; A:=Pos(':',Word);
    if A>0 then begin Numeric(Copy(Word,1,A-1),DomainMin); Numeric(Copy(Word,A+1,MaxInt),DomainMax); end;
    Word:=Options.Values['y domain']; A:=Pos(':',Word);
    if A>0 then begin Numeric(Copy(Word,1,A-1),YDomainMin); Numeric(Copy(Word,A+1,MaxInt),YDomainMax); end;
    HasXMin:=Numeric(Options.Values['xmin'],XMin); HasXMax:=Numeric(Options.Values['xmax'],XMax);
    HasYMin:=Numeric(Options.Values['ymin'],YMin); HasYMax:=Numeric(Options.Values['ymax'],YMax);
    HasZMin:=Numeric(Options.Values['zmin'],ZMin); HasZMax:=Numeric(Options.Values['zmax'],ZMax);
    Word:=Options.Values['view']; Q:=1;
    if Word<>'' then begin
      Body:=ReadTeXGroup(Word,Q,'{','}'); if Numeric(Body,V) then Azimuth:=DegToRad(V);
      Body:=ReadTeXGroup(Word,Q,'{','}'); if Numeric(Body,V) then Elevation:=DegToRad(V);
    end;
  end;
  {$I nativecircuits.inc}
  {$I nativelibraries.inc}
  {$I nativecolorbar.inc}
  function FinishAxis:Boolean;
  var AxisX,AxisY:Double; Shift:TDiagramPoint; I,J,K,BackIndex:Integer;
  begin
    Result:=False;
      if (PlotWidth<20) or (PlotHeight<20) then Exit;
      if Plots.Count=0 then begin
        if not HasXMin then XMin:=0; if not HasXMax then XMax:=1;
        if not HasYMin then YMin:=0; if not HasYMax then YMax:=1;
        if not HasZMin then ZMin:=0; if not HasZMax then ZMax:=1;
      end;
      if XMax<=XMin then begin XMin:=XMin-1; XMax:=XMax+1; end;
      if YMax<=YMin then begin YMin:=YMin-1; YMax:=YMax+1; end;
      if ZMax<=ZMin then begin ZMin:=ZMin-1; ZMax:=ZMax+1; end;
      if Polar then begin
        if not HasXMin then XMin:=0; if not HasXMax then XMax:=360;
        if not HasYMin then YMin:=0; YMax:=Max(0.1,YMax);
      end;
      MetaMin:=MaxDouble; MetaMax:=-MaxDouble;
      for I:=0 to Plots.Count-1 do for J:=0 to High(TPrimitive(Plots[I]).Points) do begin
        V:=TPrimitive(Plots[I]).Points[J].Z; MetaMin:=Min(MetaMin,V); MetaMax:=Max(MetaMax,V);
      end;
      if MetaMin=MaxDouble then begin MetaMin:=0; MetaMax:=1; end
      else if MetaMax<=MetaMin then MetaMax:=MetaMin+1;
      if PGFPlotsAxis then begin
        Enlarge(XMin,XMax,HasXMin,HasXMax,'x'); Enlarge(YMin,YMax,HasYMin,HasYMax,'y');
        if ThreeD then Enlarge(ZMin,ZMax,HasZMin,HasZMax,'z');
        if Options.Values['scale only axis']<>'true' then begin
          PlotWidth:=Max(1.0,PlotWidth-45*72/72.27); PlotHeight:=Max(1.0,PlotHeight-45*72/72.27);
        end;
      end;
      Geometry:=Default(TPlotGeometry); Geometry.Minimum:=PointAt(XMin,YMin); Geometry.Minimum.Z:=ZMin;
      Geometry.Maximum:=PointAt(XMax,YMax); Geometry.Maximum.Z:=ZMax;
      if LogX then begin Geometry.Minimum.X:=Ln(Max(1e-20,XMin)); Geometry.Maximum.X:=Ln(Max(1e-20,XMax)); end;
      if LogY then begin Geometry.Minimum.Y:=Ln(Max(1e-20,YMin)); Geometry.Maximum.Y:=Ln(Max(1e-20,YMax)); end;
      Geometry.Width:=PlotWidth; Geometry.Height:=PlotHeight; Geometry.Azimuth:=Azimuth; Geometry.Elevation:=Elevation;
      Geometry.ThreeD:=ThreeD; Geometry.Ratio:=PointAt(1,1); Geometry.Ratio.Z:=1;
      Word:=Options.Values['plot box ratio'];
      if Word<>'' then begin
        Q:=1; Body:=ReadTeXGroup(Word,Q,'{','}');
        if Body<>'' then begin
          Numeric(Body,Geometry.Ratio.X); Numeric(ReadTeXGroup(Word,Q,'{','}'),Geometry.Ratio.Y);
          Numeric(ReadTeXGroup(Word,Q,'{','}'),Geometry.Ratio.Z);
        end else begin
          NodeStyle.Clear; ExtractStrings([' ',#9],[],PChar(PlainLabel(Word)),NodeStyle);
          if NodeStyle.Count=3 then begin Numeric(NodeStyle[0],Geometry.Ratio.X); Numeric(NodeStyle[1],Geometry.Ratio.Y); Numeric(NodeStyle[2],Geometry.Ratio.Z); end;
        end;
      end;
      Geometry.Prepare;
      if ThreeD then ReadOptions(PlainLabel(Options.Values['every 3d description/.style']),Options);
      for I:=0 to Plots.Count-1 do begin
        Plot:=TPrimitive(Plots[I]);
        if Plot.BetweenFirst<>'' then Continue;
        Plot.ColorMap:=LoadPlotColorMap(Plot.ColorMapName,Plot.ColorMapDefinition,Context,Directory);
        if not Plot.HasMetaMin then Plot.MetaMin:=MetaMin; if not Plot.HasMetaMax then Plot.MetaMax:=MetaMax;
        if Plot.ThreeD and (Plot.GridCols>1) then begin
          Count:=Plot.GridCols; Rows:=Length(Plot.Points) div Count;
          if Plot.Surface then begin
            for J:=0 to Rows-2 do for K:=0 to Count-2 do begin
              A:=J*Count+K; Item:=TPrimitive.Create; Item.Closed:=True; Item.Weight:=0.2; Item.Opacity:=Plot.Opacity;
              V:=(Plot.Points[A].Z+Plot.Points[A+1].Z+Plot.Points[A+Count].Z+Plot.Points[A+Count+1].Z)/4;
              Item.Fill:=MappedColor(Plot,V);
              Item.Stroke:=Plot.Stroke;
              if Plot.SmoothShade then begin
                Item.Stroke:=clNone; SetLength(Item.VertexColors,4);
                Item.VertexColors[0]:=MappedColor(Plot,Plot.Points[A].Z); Item.VertexColors[1]:=MappedColor(Plot,Plot.Points[A+1].Z);
                Item.VertexColors[2]:=MappedColor(Plot,Plot.Points[A+Count+1].Z); Item.VertexColors[3]:=MappedColor(Plot,Plot.Points[A+Count].Z);
              end;
              Point(Item,Project(Plot.Points[A])); Point(Item,Project(Plot.Points[A+1]));
              Point(Item,Project(Plot.Points[A+Count+1])); Point(Item,Project(Plot.Points[A+Count]));
              Item.Depth:=(Geometry.Depth(Plot.Points[A])+Geometry.Depth(Plot.Points[A+1])+
                Geometry.Depth(Plot.Points[A+Count])+Geometry.Depth(Plot.Points[A+Count+1]))/4;
              Surfaces.Add(Item);
              if Surfaces.Count+Scene.Items.Count>4096 then Exit;
            end;
          end else begin
            for J:=0 to Rows-1 do for K:=0 to Count-2 do AddMeshEdge(Plot,J*Count+K,J*Count+K+1);
            for K:=0 to Count-1 do for J:=0 to Rows-2 do AddMeshEdge(Plot,J*Count+K,(J+1)*Count+K);
          end;
          Plot.Points:=nil;
        end else if Length(Plot.BoxSummary)>0 then begin
          DrawBox(Plot); for J:=0 to High(Plot.Points) do Plot.Points[J]:=Project(Plot.Points[J]);
        end else if Plot.Bars then begin
          for J:=0 to High(Plot.Points) do begin
            Next:=Plot.Points[J];
            First:=Next; First.Y:=0; First:=Project(First); First.Y:=EnsureRange(First.Y,0.0,PlotHeight);
            Item:=TPrimitive.Create; Item.Stroke:=Plot.Stroke; Item.Fill:=Plot.Fill; if Item.Fill=clNone then Item.Fill:=Plot.Stroke;
            Item.Closed:=True; Item.Weight:=Plot.Weight; V:=4.5; Next:=Project(Next);
            Point(Item,PointAt(Next.X-V,First.Y)); Point(Item,PointAt(Next.X+V,First.Y));
            Point(Item,PointAt(Next.X+V,Next.Y)); Point(Item,PointAt(Next.X-V,Next.Y)); Scene.Items.Add(Item);
          end;
          Plot.Points:=nil;
        end else for J:=0 to High(Plot.Points) do Plot.Points[J]:=Project(Plot.Points[J]);
      end;
      Surfaces.Sort(@SurfaceOrder);
      while Surfaces.Count>0 do begin Scene.Items.Add(TObject(Surfaces[0])); Surfaces.Delete(0); end;
      for I:=0 to Plots.Count-1 do begin Plot:=TPrimitive(Plots[I]); if Plot.BetweenFirst<>'' then FillBetween(Plot); end;
      if Polar then PolarAxes
      else if ThreeD then begin
        First:=PointAt(XMin,YMin); First.Z:=ZMin;
        Next:=First; Next.X:=XMax; Axis(First,Next,'x',Options.Values['xlabel']);
        First:=Next; Next.Y:=YMax; Axis(First,Next,'y',Options.Values['ylabel']);
        First:=PointAt(XMin,YMin); First.Z:=ZMin; Next:=First; Next.Z:=ZMax; Axis(First,Next,'z',Options.Values['zlabel']);
        First:=PointAt(XMin,YMax); First.Z:=ZMax; Next:=First; Next.X:=XMax; Axis(First,Next,'x','',False);
        Next:=First; First.Y:=YMin; Axis(First,Next,'y','',False);
        First:=PointAt(XMax,YMax); First.Z:=ZMin; Next:=First; Next.Z:=ZMax; Axis(First,Next,'z','',False);
        for I:=0 to 2 do begin
          First:=PointAt(XMin,YMax); First.Z:=ZMin; Next:=First;
          case I of 0:Next.X:=XMax; 1:Next.Y:=YMin; 2:Next.Z:=ZMax; end;
          Axis(First,Next,Copy('xyz',I+1,1),'',False);
        end;
        if Options.Values['axis on top']<>'true' then begin
          BackIndex:=AxisPrevious.Count;
          for I:=AxisPrevious.Count to Scene.Items.Count-1 do if TPrimitive(Scene.Items[I]).BackLayer then begin
            Scene.Items.Move(I,BackIndex); Inc(BackIndex);
          end;
        end;
      end else begin
        X:=XMin; Y:=YMin;
        if Options.Values['axis lines']='middle' then begin X:=EnsureRange(0.0,XMin,XMax); Y:=EnsureRange(0.0,YMin,YMax); end;
        Axis(PointAt(XMin,Y),PointAt(XMax,Y),'x',Options.Values['xlabel']);
        Axis(PointAt(X,YMin),PointAt(X,YMax),'y',Options.Values['ylabel']);
        if Options.Values['axis lines']<>'middle' then begin
          Axis(PointAt(XMin,YMax),PointAt(XMax,YMax),'x','',False);
          Axis(PointAt(XMax,YMin),PointAt(XMax,YMax),'y','',False);
        end;
      end;
      NodeStyle.Clear; ReadOptions(PlainLabel(Options.Values['title style']),NodeStyle);
      LabelAt(Options.Values['title'],PointAt(PlotWidth/2,PlotHeight+18));
      BindOption('title');
      if Legends.Count>0 then begin
        LegendW:=0; LegendH:=8;
        for I:=0 to Legends.Count-1 do begin
          LabelItem:=TPrimitive(Legends[I]); LegendW:=Max(LegendW,LabelItem.LabelW+34); LegendH:=LegendH+LabelItem.LabelH+4;
        end;
        Word:=Options.Values['legend pos']; LX:=0.98*PlotWidth; LY:=0.98*PlotHeight; X:=1; Y:=1;
        if Word<>'' then begin
          LX:=0.97*PlotWidth; LY:=0.97*PlotHeight;
          if Pos('west',Word)>0 then begin LX:=0.03*PlotWidth; X:=0; end;
          if Pos('south',Word)>0 then begin LY:=0.03*PlotHeight; Y:=0; end;
          if Word='outer north east' then begin LX:=1.03*PlotWidth; LY:=PlotHeight; X:=0; end;
          if Word='outer east' then begin LX:=PlotWidth+0.8*Scene.FontPoints; LY:=PlotHeight/2; X:=0; Y:=0.5; end;
        end;
        NodeStyle.Clear; ReadOptions(PlainLabel(Options.Values['legend style']),NodeStyle);
        Word:=PlainLabel(NodeStyle.Values['at']); Q:=1;
        if Coordinate(Word,Q,First) then begin LX:=First.X*PlotWidth; LY:=First.Y*PlotHeight; end;
        Word:=NodeStyle.Values['anchor'];
        if Word<>'' then begin
          X:=0.5; Y:=0.5; if Pos('west',Word)>0 then X:=0 else if Pos('east',Word)>0 then X:=1;
          if Pos('south',Word)>0 then Y:=0 else if Pos('north',Word)>0 then Y:=1;
        end;
        LX:=LX-LegendW*X; LY:=LY+LegendH*(1-Y);
        Item:=TPrimitive.Create; Item.Closed:=True; Item.Fill:=clWhite;
        if Options.Values['@datavis']='true' then begin Item.Fill:=clNone; Item.Stroke:=clNone; end;
        Point(Item,PointAt(LX,LY)); Point(Item,PointAt(LX+LegendW,LY));
        Point(Item,PointAt(LX+LegendW,LY-LegendH)); Point(Item,PointAt(LX,LY-LegendH)); Scene.Items.Add(Item);
        V:=LY-4;
        for I:=0 to Legends.Count-1 do begin
          LabelItem:=TPrimitive(Legends[I]); Scene.Items.Extract(LabelItem); Scene.Items.Add(LabelItem);
          LabelItem.AnchorX:=0; LabelItem.AnchorY:=1; X:=(LegendW-34-LabelItem.LabelW)/2;
          if Options.Values['legend cell align']='left' then X:=0 else if Options.Values['legend cell align']='right' then X:=X*2;
          LabelItem.Points[0]:=PointAt(LX+28+X,V);
          if I<Plots.Count then begin
            Plot:=TPrimitive(Plots[I]); Item:=TPrimitive.Create;
            Item.Stroke:=Plot.Stroke; Item.Weight:=Plot.Weight; Item.Dashed:=Plot.Dashed; Item.Dash:=Copy(Plot.Dash); Item.MarkKind:=Plot.MarkKind; Item.Opacity:=Plot.Opacity;
            Item.Markers:=Plot.Markers; Item.OnlyMarks:=Plot.OnlyMarks; Item.MarkerIndex:=1;
            if (Options.Values['@datavis']='true') and not Plot.OnlyMarks then begin
              { TikZ's default zig-zag legend sample spans 2em with .3ex bends. }
              X:=Scene.FontPoints*72/72.27; Y:=0.3*0.43056*X;
              Point(Item,PointAt(LX+23-2*X,V-LabelItem.LabelH/2));
              Point(Item,PointAt(LX+23-1.5*X,V-LabelItem.LabelH/2+Y));
              Point(Item,PointAt(LX+23-0.5*X,V-LabelItem.LabelH/2-Y));
              Point(Item,PointAt(LX+23,V-LabelItem.LabelH/2));
            end else begin
              Point(Item,PointAt(LX+5,V-LabelItem.LabelH/2)); Point(Item,PointAt(LX+14,V-LabelItem.LabelH/2));
              Point(Item,PointAt(LX+23,V-LabelItem.LabelH/2));
            end;
            Scene.Items.Add(Item);
          end;
          V:=V-LabelItem.LabelH-4;
        end;
      end;
    DrawColorbar;
    AxisX:=LengthPoints(Options.Values['xshift'],0,DocumentTextWidth(Context));
    AxisY:=LengthPoints(Options.Values['yshift'],0,DocumentTextWidth(Context));
    Word:=PlainLabel(Options.Values['at']); Q:=1;
    if Coordinate(Word,Q,Shift) then begin AxisX:=AxisX+Shift.X*Scale; AxisY:=AxisY+Shift.Y*Scale; end;
    Word:=Options.Values['anchor'];
    if Pos('east',Word)>0 then AxisX:=AxisX-PlotWidth else if (Word='center') or (Word='north') or (Word='south') then AxisX:=AxisX-PlotWidth/2;
    if Pos('north',Word)>0 then AxisY:=AxisY-PlotHeight else if (Word='center') or (Word='east') or (Word='west') then AxisY:=AxisY-PlotHeight/2;
    if (AxisX<>0) or (AxisY<>0) then for I:=0 to Scene.Items.Count-1 do if AxisPrevious.IndexOf(Scene.Items[I])<0 then begin
      Item:=TPrimitive(Scene.Items[I]);
      for J:=0 to High(Item.Points) do begin Item.Points[J].X:=Item.Points[J].X+AxisX; Item.Points[J].Y:=Item.Points[J].Y+AxisY; end;
    end;
    Plots.Clear; Legends.Clear; InAxis:=False; AxisOwner:=-1; Options.Clear; Style.Clear;
      Result:=True;
  end;
  {$I nativedatavisualization.inc}
begin
  Result:=nil; Bytes:=0; if Length(Source)>64*1024 then Exit;
  if IsCommutativeDiagram(Source) then Exit(NativeCommutativeDiagram(Context,Source,Directory,Bytes,Engine));
  Scene:=TNativeDiagram.Create; Options:=TStringList.Create; Style:=TStringList.Create; AxisDefaults:=TStringList.Create; Plots:=TList.Create;
  Scene.FontPoints:=DocumentFontPoints(Context);
  Registry:=TMacroRegistry.Create; Parser:=TFPExpressionParser.Create(nil); Legends:=TList.Create;
  Calc:=TTikZCalc.Create; Calc.Resolve:=@ResolvePoint;
  Measure:=TBitmap.Create; Measure.SetSize(1,1); GlobalStyle:=TStringList.Create; NodeStyle:=TStringList.Create; Colors:=TStringList.Create;
  Nodes:=TStringList.Create; NamedPaths:=TStringList.Create; StyleNames:=TStringList.Create; GroupOptions:=TStringList.Create; Surfaces:=TList.Create;
  CircuitDefaults:=TStringList.Create; CircuitOptions:=TStringList.Create; TikZDefaults:=TStringList.Create;
  Model:=TDiagramModel.Create; Model.Load(Source); AxisOwner:=-1; AxisPrevious:=TList.Create;
  try
    try
    DataOptions:=nil; Registry.Load(Context,Directory,Engine); Scene.ConfigureLabels(Context,Directory,Engine,Registry);
    ConfigurePlotMath(Parser); VariableX:=Parser.Identifiers.AddFloatVariable('x',0);
    VariableY:=Parser.Identifiers.AddFloatVariable('y',0); VariableT:=Parser.Identifiers.AddFloatVariable('t',0);
    P:=1;
    while P<=Length(Context) do begin
      if Context[P]='%' then begin while (P<=Length(Context)) and (Context[P]<>#10) do Inc(P); Continue; end;
      if Context[P]<>'\' then begin Inc(P); Continue; end;
      Q:=P; if ReadTeXDefinition(Context,Q) or SkipTeXLiteral(Context,Q) then begin P:=Q; Continue; end;
      Command:=ReadTeXCommand(Context,P);
      if (Command='usepackage') or (Command='RequirePackage') then begin
        Body:=ReadTeXGroup(Context,P,'[',']'); Word:=ReadTeXGroup(Context,P,'{','}');
        if Pos('circuitikz',Word)>0 then ReadOptions(Body,CircuitDefaults);
      end;
      if Command='ctikzset' then ReadOptions(ReadTeXGroup(Context,P,'{','}'),CircuitDefaults);
      if Command='definecolor' then begin
        Word:=ReadTeXGroup(Context,P,'{','}'); Body:=ReadTeXGroup(Context,P,'{','}');
        Colors.Values[Word]:=Body+':'+ReadTeXGroup(Context,P,'{','}');
      end;
      if Command='pgfplotsset' then ReadOptions(ReadTeXGroup(Context,P,'{','}'),AxisDefaults);
      if Command='tikzdatavisualizationset' then DataDefaults:=DataDefaults+','+ReadTeXGroup(Context,P,'{','}');
      if Command='tikzset' then begin ReadOptions(ReadTeXGroup(Context,P,'{','}'),TikZDefaults); RememberStyles(TikZDefaults); end;
    end;
    Scopes:=nil; P:=1; InAxis:=False; PGFPlotsAxis:=False; ThreeD:=False; Circuitikz:=False; Polar:=False; LogX:=False; LogY:=False; InGroup:=False; GroupIndex:=0; Scale:=72/2.54; TotalPoints:=0;
    XMin:=MaxDouble; XMax:=-MaxDouble; YMin:=MaxDouble; YMax:=-MaxDouble; ZMin:=MaxDouble; ZMax:=-MaxDouble;
    HasXMin:=False; HasXMax:=False; HasYMin:=False; HasYMax:=False; HasZMin:=False; HasZMax:=False;
    DomainMin:=-5; DomainMax:=5; YDomainMin:=-5; YDomainMax:=5; Azimuth:=DegToRad(25); Elevation:=DegToRad(30);
    PlotWidth:=240; PlotHeight:=160;
    while P<=Length(Source) do begin
      SkipTeXSpace(Source,P); if P>Length(Source) then Break;
      if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
      CommandStart:=P-1; Command:=ReadTeXCommand(Source,P); if Command='' then Exit;
      { PGF's \addplot macro consumes the following digit as a modifier. }
      if (Command='addplot') and (Copy(Source,P,1)='3') then begin Command:='addplot3'; Inc(P); end;
      if Command='begin' then begin
        Environment:=ReadTeXGroup(Source,P,'{','}');
        if Environment='scope' then begin
          I:=Length(Scopes); if I>=16 then Exit; SetLength(Scopes,I+1); Scopes[I].Style:=GlobalStyle.Text; Scopes[I].First:=Scene.Items.Count; Scopes[I].FirstHandle:=Length(Scene.EditPoints);
          ReadOptions(ReadTeXGroup(Source,P,'[',']'),GlobalStyle); Continue;
        end;
        Options.Clear;
        if (Environment='tikzpicture') or (Environment='circuitikz') then Options.Assign(TikZDefaults);
        if DiagramIsAxis(Environment) or (Environment='groupplot') then Options.Assign(AxisDefaults);
        ExpandStyle(ReadTeXGroup(Source,P,'[',']'),Options);
        if (Environment='tikzpicture') or (Environment='circuitikz') then begin
          Circuitikz:=Environment='circuitikz';
          GlobalStyle.Assign(Options); RememberStyles(GlobalStyle);
          if Numeric(Options.Values['scale'],V) then Scale:=Scale*V;
        end else if Environment='groupplot' then begin
          GroupOptions.Assign(Options); InGroup:=True; GroupIndex:=0; Continue;
        end else if DiagramIsAxis(Environment) and not InAxis then begin
          StartAxis(Environment);
        end else Exit;
        Continue;
      end;
      if Command='end' then begin
        Environment:=ReadTeXGroup(Source,P,'{','}');
        if (DiagramIsAxis(Environment) or (Environment='groupplot')) and InAxis and not FinishAxis then Exit;
        if Environment='groupplot' then InGroup:=False;
        if Environment='scope' then begin
          I:=High(Scopes); if I<0 then Exit;
          X:=LengthPoints(GlobalStyle.Values['xshift'],0,DocumentTextWidth(Context)); Y:=LengthPoints(GlobalStyle.Values['yshift'],0,DocumentTextWidth(Context));
          for J:=Scopes[I].First to Scene.Items.Count-1 do begin
            Item:=TPrimitive(Scene.Items[J]); for K:=0 to High(Item.Points) do begin Item.Points[K].X:=Item.Points[K].X+X; Item.Points[K].Y:=Item.Points[K].Y+Y; end;
            Item.NodeCenter.X:=Item.NodeCenter.X+X; Item.NodeCenter.Y:=Item.NodeCenter.Y+Y;
            for K:=0 to High(Item.CircuitPorts) do begin
              Item.CircuitPorts[K].Position.X:=Item.CircuitPorts[K].Position.X+X;
              Item.CircuitPorts[K].Position.Y:=Item.CircuitPorts[K].Position.Y+Y;
            end;
          end;
          for J:=Scopes[I].FirstHandle to High(Scene.EditPoints) do begin Scene.EditPoints[J].X:=Scene.EditPoints[J].X+X; Scene.EditPoints[J].Y:=Scene.EditPoints[J].Y+Y; end;
          if GlobalStyle.IndexOfName('on background layer')>=0 then begin
            Count:=Scene.Items.Count-Scopes[I].First;
            for J:=0 to Count-1 do Scene.Items.Move(Scopes[I].First+J,J);
          end;
          GlobalStyle.Text:=Scopes[I].Style; SetLength(Scopes,I);
        end;
        Continue;
      end;
      if Command='tikzset' then begin ReadOptions(ReadTeXGroup(Source,P,'{','}'),GlobalStyle); RememberStyles(GlobalStyle); Continue; end;
      if Command='ctikzset' then begin ReadOptions(ReadTeXGroup(Source,P,'{','}'),GlobalStyle); Continue; end;
      if Command='tikzdatavisualizationset' then begin DataDefaults:=DataDefaults+','+ReadTeXGroup(Source,P,'{','}'); Continue; end;
      if (Command='nextgroupplot') and InGroup then begin
        if InAxis and not FinishAxis then Exit;
        Options.Assign(GroupOptions); ReadOptions(ReadTeXGroup(Source,P,'[',']'),Options); NodeStyle.Clear;
        ReadOptions(PlainLabel(GroupOptions.Values['group style']),NodeStyle);
        Word:=NodeStyle.Values['group size']; J:=Pos(' by ',Word); GroupColumns:=1;
        if J>0 then GroupColumns:=Max(1,StrToIntDef(Copy(Word,1,J-1),1));
        GroupWidth:=LengthPoints(GroupOptions.Values['width'],240,DocumentTextWidth(Context));
        GroupHeight:=LengthPoints(GroupOptions.Values['height'],160,DocumentTextWidth(Context));
        GroupWidth:=GroupWidth+LengthPoints(NodeStyle.Values['horizontal sep'],72/2.54,DocumentTextWidth(Context));
        GroupHeight:=GroupHeight+LengthPoints(NodeStyle.Values['vertical sep'],72/2.54,DocumentTextWidth(Context));
        Str(GroupWidth*(GroupIndex mod GroupColumns):0:6,Word); Options.Values['xshift']:=Trim(Word)+'bp';
        Str(-GroupHeight*(GroupIndex div GroupColumns):0:6,Word); Options.Values['yshift']:=Trim(Word)+'bp';
        StartAxis('axis'); Inc(GroupIndex); Continue;
      end;
      if Command='graph' then begin
        Style.Clear; ExpandStyle(ReadTeXGroup(Source,P,'[',']'),Style); Body:=Caption(Source,P);
        if not Graph(Body,CaptionRange.First) then Exit;
        SkipTeXSpace(Source,P); if Copy(Source,P,1)=';' then Inc(P); Continue;
      end;
      if Command='datavisualization' then begin
        if not DataVisualization then Exit; Continue;
      end;
      if Command='addlegendentry' then begin
        Style.Clear; NodeStyle.Clear; ReadOptions(PlainLabel(Options.Values['legend style']),NodeStyle);
        LabelAt(Caption(Source,P),PointAt(0,0)); BindRange;
        if LabelItem<>nil then Legends.Add(LabelItem); Continue;
      end;
      if ((Command='addplot') or (Command='addplot3')) and InAxis then begin
        UseCycle:=Copy(Source,P,1)='+'; if UseCycle then Inc(P); SkipTeXSpace(Source,P); ExplicitStyle:=Copy(Source,P,1)='[';
        UseCycle:=UseCycle or not ExplicitStyle; Style.Clear; ExpandStyle(ReadTeXGroup(Source,P,'[',']'),Style);
        if Plots.Count>=128 then Exit;
        Plot:=TPrimitive.Create;
        if UseCycle then begin
          case Plots.Count mod 5 of
            0:begin Plot.Stroke:=clBlue; Plot.MarkKind:='*'; end;
            1:begin Plot.Stroke:=clRed; Plot.MarkKind:='square*'; end;
            2:begin ColorValue('brown!60!black',Plot.Stroke); Plot.MarkKind:='otimes*'; end;
            3:begin Plot.Stroke:=clBlack; Plot.MarkKind:='star'; end;
            4:begin Plot.Stroke:=clBlue; Plot.MarkKind:='diamond*'; end;
          end;
          Plot.Markers:=True; if (Plots.Count mod 10)>=5 then begin Plot.Dashed:=True; SetLength(Plot.Dash,2); Plot.Dash[0]:=3*72/72.27; Plot.Dash[1]:=2*72/72.27; end;
        end;
        Scene.Items.Add(Plot); Plots.Add(Plot); ApplyStyle(Plot);
        RegisterPath(Plot);
        if (Style.IndexOfName('boxplot prepared')>=0) or (Style.IndexOfName('boxplot')>=0) then if not ReadBox(Plot) then Exit;
        Plot.ThreeD:=Command='addplot3'; ThreeD:=ThreeD or Plot.ThreeD;
        SkipTeXSpace(Source,P);
        if Copy(Source,P,12)='fill between' then begin
          Inc(P,12); NodeStyle.Clear; ReadOptions(ReadTeXGroup(Source,P,'[',']'),NodeStyle);
          Word:=NodeStyle.Values['of']; J:=Pos(' and ',Word); if J=0 then Exit;
          Plot.BetweenFirst:=Trim(Copy(Word,1,J-1)); Plot.BetweenSecond:=Trim(Copy(Word,J+5,MaxInt));
        end else if Copy(Source,P,11)='coordinates' then begin
          Inc(P,11); Body:=ReadTeXGroup(Source,P,'{','}'); Q:=1;
          while Coordinate(Body,Q,Next) do begin Point(Plot,Next); if Length(Plot.Points)>4096 then Exit; end;
          if (Q<=Length(TrimRight(Body))) or ((Length(Plot.Points)=0) and (Length(Plot.BoxSummary)=0)) then Exit;
        end else if Copy(Source,P,5)='table' then begin
          Inc(P,5); NodeStyle.Clear; TableOptions(Options); TableOptions(Style);
          ReadOptions(ReadTeXGroup(Source,P,'[',']'),NodeStyle);
          Body:=ReadTeXGroup(Source,P,'{','}');
          if Pos(#10,Body)=0 then begin
            TablePath:=ExpandFileName(IncludeTrailingPathDelimiter(Directory)+Body);
            if (Copy(Body,1,1)='/') or (Copy(Body,1,1)='\') or (ExtractFileDrive(Body)<>'') then TablePath:=ExpandFileName(Body);
            if FileExists(TablePath) then begin
              if (InputFiles<>nil) and (InputFiles.IndexOf(TablePath)<0) then InputFiles.Add(TablePath);
              with TFileStream.Create(TablePath,fmOpenRead or fmShareDenyNone) do
              try if Size>1024*1024 then Exit; SetLength(Body,Size); if Size>0 then ReadBuffer(Body[1],Size); finally Free; end;
            end;
          end;
          if not TablePoints(Body,Plot,NodeStyle) then Exit;
        end else if not SamplePlot(Plot,Copy(Source,P,1)='(') then Exit;
        if Plot.GridCols=0 then Plot.GridCols:=StrToIntDef(Style.Values['mesh/cols'],0);
        Inc(TotalPoints,Length(Plot.Points)); if TotalPoints>8192 then Exit;
        if Plot.RawBox or (Length(Plot.BoxSummary)>0) then BoxRange(Plot);
        PlotRange(Plot);
        SkipTeXSpace(Source,P); if Copy(Source,P,1)<>';' then Exit; Inc(P); Continue;
      end;
      if (IndexStr(Command,PathCommands)<0) or InAxis then Exit;
      Style.Clear; ExpandStyle(ReadTeXGroup(Source,P,'[',']'),Style); SkipTeXSpace(Source,P);
      StatementIndex:=-1;
      for I:=0 to High(Model.Commands) do if Model.Commands[I].Source.First=CommandStart then begin StatementIndex:=I; Break; end;
      if StatementIndex<0 then Exit;
      A:=Model.Commands[StatementIndex].Body.First+1; Body:=Model.Text(Model.Commands[StatementIndex].Body);
      P:=Model.Commands[StatementIndex].Source.Last+1; Q:=1;
      if Command='pic' then begin if not AnglePicture(Body) then Exit; Continue; end;
      if (Command='node') or (Command='coordinate') then begin
        NodeStyle.Clear; ExpandStyle(PlainLabel(GlobalStyle.Values['every node/.style']),NodeStyle);
        ExpandStyle(StringReplace(Style.Text,LineEnding,',',[rfReplaceAll]),NodeStyle); Style.Assign(NodeStyle); NodeName:='';
        if Copy(Body,Q,1)='(' then NodeName:=ReadTeXGroup(Body,Q,'(',')');
        SkipTeXSpace(Body,Q); if Copy(Body,Q,2)='at' then Inc(Q,2);
        SkipTeXSpace(Body,Q);
        Next:=PointAt(0,0);
        if Copy(Body,Q,1)='(' then begin if not Coordinate(Body,Q,Next) then Exit; end;
        First:=PointAt(Next.X*Scale,Next.Y*Scale);
        if Command='coordinate' then begin
          LabelItem:=TPrimitive.Create; LabelItem.Kind:=3; LabelItem.NodeCenter:=First; Scene.Items.Add(LabelItem);
          if NodeName<>'' then Nodes.AddObject(NodeName,LabelItem);
          CoordinateLabels(First,StatementIndex); Continue;
        end;
        LabelAt(Caption(Body,Q,A-1),First); BindRange;
        if LabelItem=nil then begin
          LabelItem:=TPrimitive.Create; LabelItem.Kind:=3; LabelItem.NodeCenter:=First; Point(LabelItem,First); Scene.Items.Add(LabelItem);
        end;
        PlaceNode(LabelItem);
        if NodeName<>'' then Nodes.AddObject(NodeName,LabelItem);
        if not CircuitNode(LabelItem) then NodeOutline(LabelItem); PathHandles(StatementIndex,LabelItem);
        CoordinateLabels(LabelItem.NodeCenter,StatementIndex);
        Continue;
      end;
      if Style.IndexOfName('name intersections')>=0 then begin if not IntersectPaths(Style.Values['name intersections']) then Exit; Continue; end;
      Calc.ClearVariables; SkipTeXSpace(Body,Q);
      if Copy(Body,Q,3)='let' then if not Calc.ReadLet(Body,Q) then Exit;
      RelativeBase:=PointAt(0,0); if not PathCoordinate(Q,First) then Exit;
      PendingNodeEnd:=0; PathNodePosition:=1;
      Item:=TPrimitive.Create; Scene.Items.Add(Item); ApplyStyle(Item);
      RegisterPath(Item);
      if ((Command='fill') or (Command='filldraw')) and (Item.Fill=clNone) and (Style.IndexOfName('pattern')<0) then Item.Fill:=Item.Stroke;
      if (Command='fill') and (Style.IndexOfName('draw')<0) then Item.Stroke:=clNone;
      Point(Item,PointAt(First.X*Scale,First.Y*Scale));
      while Q<=Length(Body) do begin
        SkipTeXSpace(Body,Q); if Q>Length(Body) then Break;
        if (Copy(Body,Q,2)='to') and ((Q+2>Length(Body)) or not (Body[Q+2] in ['a'..'z','A'..'Z'])) then begin
          Inc(Q,2); SkipTeXSpace(Body,Q); ScanStart:=Q;
          Word:=ReadTeXGroup(Body,Q,'[',']');
          if Length(Item.Points)=0 then Exit; First:=Item.Points[High(Item.Points)];
          if not PathCoordinate(Q,Next) then Exit;
          CircuitSegment(First,PointAt(Next.X*Scale,Next.Y*Scale),Word,A+ScanStart-1);
        end else if Copy(Body,Q,2)='--' then begin
          Inc(Q,2); SkipTeXSpace(Body,Q);
          if Copy(Body,Q,5)='cycle' then begin Item.Closed:=True; Inc(Q,5); Continue; end;
          Scan:=Q; ScanStart:=Q;
          while Copy(Body,Scan,4)='node' do begin
            Inc(Scan,4); ReadTeXGroup(Body,Scan,'[',']'); SkipTeXSpace(Body,Scan);
            if Copy(Body,Scan,1)='(' then ReadTeXGroup(Body,Scan,'(',')');
            ReadTeXGroup(Body,Scan,'{','}'); SkipTeXSpace(Body,Scan);
          end;
          PendingCoordinate:=Scan;
          if not PathCoordinate(Scan,Next) then Exit; Point(Item,PointAt(Next.X*Scale,Next.Y*Scale));
          if ScanStart=PendingCoordinate then Q:=Scan else begin PendingNodeEnd:=Scan; PathNodePosition:=0.5; end;
        end else if (Copy(Body,Q,2)='|-') or (Copy(Body,Q,2)='-|') then begin
          Word:=Copy(Body,Q,2); Inc(Q,2); if not PathCoordinate(Q,Next) then Exit;
          if Length(Item.Points)=0 then Exit; First:=Item.Points[High(Item.Points)];
          if Word='|-' then Point(Item,PointAt(First.X,Next.Y*Scale)) else Point(Item,PointAt(Next.X*Scale,First.Y));
          Point(Item,PointAt(Next.X*Scale,Next.Y*Scale));
        end else if Copy(Body,Q,9)='rectangle' then begin
          Inc(Q,9); if not Coordinate(Body,Q,Next) then Exit;
          Point(Item,PointAt(Next.X*Scale,First.Y*Scale)); Point(Item,PointAt(Next.X*Scale,Next.Y*Scale));
          Point(Item,PointAt(First.X*Scale,Next.Y*Scale)); Item.Closed:=True;
        end else if Copy(Body,Q,3)='arc' then begin
          Inc(Q,3); if not ArcPath(Item,Q) then Exit;
        end else if Copy(Body,Q,6)='circle' then begin
          Inc(Q,6); Word:=ReadTeXGroup(Body,Q,'(',')'); Radius:=LengthPoints(Word,-1,DocumentTextWidth(Context));
          if Radius<0 then begin if not Numeric(Word,V) then Exit; Radius:=V*Scale; end;
          Item.Kind:=1; Item.Points:=nil; Point(Item,PointAt(First.X*Scale-Radius,First.Y*Scale-Radius)); Point(Item,PointAt(First.X*Scale+Radius,First.Y*Scale+Radius));
        end else if Copy(Body,Q,4)='grid' then begin
          Inc(Q,4); if not Coordinate(Body,Q,Next) then Exit; Item.Points:=nil;
          Step:=LengthPoints(Style.Values['step'],Scale,DocumentTextWidth(Context)); if Step<=0 then Exit;
          for I:=0 to Min(100,Floor((Next.X-First.X)*Scale/Step)) do begin
            Plot:=TPrimitive.Create; Scene.Items.Add(Plot); ApplyStyle(Plot);
            Point(Plot,PointAt(First.X*Scale+I*Step,First.Y*Scale)); Point(Plot,PointAt(First.X*Scale+I*Step,Next.Y*Scale));
          end;
          for I:=0 to Min(100,Floor((Next.Y-First.Y)*Scale/Step)) do begin
            Plot:=TPrimitive.Create; Scene.Items.Add(Plot); ApplyStyle(Plot);
            Point(Plot,PointAt(First.X*Scale,First.Y*Scale+I*Step)); Point(Plot,PointAt(Next.X*Scale,First.Y*Scale+I*Step));
          end;
        end else if Copy(Body,Q,4)='node' then begin
          Inc(Q,4); NodeStyle.Clear; ReadOptions(ReadTeXGroup(Body,Q,'[',']'),NodeStyle); SkipTeXSpace(Body,Q);
          NodeName:=''; if Copy(Body,Q,1)='(' then NodeName:=ReadTeXGroup(Body,Q,'(',')');
          SkipTeXSpace(Body,Q); NodeAt:=Copy(Body,Q,2)='at';
          if NodeAt then begin Inc(Q,2); if not Coordinate(Body,Q,NodePosition) then Exit; end;
          Word:=Caption(Body,Q,A-1);
          if Length(Item.Points)=0 then Exit; Next:=Item.Points[High(Item.Points)];
          V:=PathNodePosition; if NodeStyle.IndexOfName('midway')>=0 then V:=0.5; Numeric(NodeStyle.Values['pos'],V);
          if Length(Item.Points)>1 then begin
            First:=Item.Points[High(Item.Points)-1]; Next.X:=First.X+(Next.X-First.X)*V; Next.Y:=First.Y+(Next.Y-First.Y)*V;
          end;
          if NodeAt then Next:=PointAt(NodePosition.X*Scale,NodePosition.Y*Scale);
          LabelAt(Word,Next); BindRange;
          if LabelItem<>nil then begin
            if NodeName<>'' then Nodes.AddObject(NodeName,LabelItem);
            if (NodeStyle.IndexOfName('sloped')>=0) and (Length(Item.Points)>1) then begin
              Next:=Item.Points[High(Item.Points)]; First:=Item.Points[High(Item.Points)-1];
              V:=RadToDeg(ArcTan2(Next.Y-First.Y,Next.X-First.X));
              if V>90 then V:=V-180 else if V< -90 then V:=V+180;
              RotatePathLabel(LabelItem,V+LabelItem.Rotation);
            end;
          end;
        end else Exit;
        if PendingNodeEnd>0 then begin
          SkipTeXSpace(Body,Q); if Q>=PendingCoordinate then begin Q:=PendingNodeEnd; PendingNodeEnd:=0; PathNodePosition:=1; end;
        end;
      end;
      PathHandles(StatementIndex); if not Decorate(Item) then Exit; Hatch(Item); if Scene.Items.Count>4096 then Exit;
    end;
    if InAxis and not FinishAxis then Exit;
    if Scene.Items.Count=0 then begin
      if (Length(Model.Environments)=0) or not ((Model.Environments[0].Name='tikzpicture') or
        (Model.Environments[0].Name='circuitikz')) then Exit;
      Item:=TPrimitive.Create; Item.Kind:=3; Point(Item,PointAt(0,0)); Point(Item,PointAt(4*Scale,3*Scale)); Scene.Items.Add(Item);
    end;
    { Edges terminate at named node borders, leaving their labels unobscured. }
    for I:=0 to Scene.Items.Count-1 do begin
      Item:=TPrimitive(Scene.Items[I]); if (Item.Kind<>0) or Item.Closed or (Length(Item.Points)<2) then Continue;
      for J:=0 to Nodes.Count-1 do begin
        LabelItem:=TPrimitive(Nodes.Objects[J]); if (LabelItem.NodeHalfW<=0) or (LabelItem.NodeHalfH<=0) then Continue;
        for K:=0 to 1 do begin
          A:=0; Q:=1; if K=1 then begin A:=High(Item.Points); Q:=A-1; end;
          First:=Item.Points[A]; Next:=LabelItem.NodeCenter;
          if Hypot(First.X-Next.X,First.Y-Next.Y)>0.01 then Continue;
          X:=Item.Points[Q].X-First.X; Y:=Item.Points[Q].Y-First.Y;
          V:=0;
          if LabelItem.NodeCircle then begin
            Step:=Hypot(X/LabelItem.NodeHalfW,Y/LabelItem.NodeHalfH); if Step>0 then V:=1/Step;
          end else begin
            V:=MaxDouble; if X<>0 then V:=Min(V,LabelItem.NodeHalfW/Abs(X));
            if Y<>0 then V:=Min(V,LabelItem.NodeHalfH/Abs(Y));
          end;
          if (V>0) and (V<1) then Item.Points[A]:=PointAt(First.X+X*V,First.Y+Y*V);
        end;
      end;
    end;
    Scene.UnitScale:=Scale; Scene.Measure;
    { Count the actual scene/primitive records and their variable payloads;
      shaded plots retain color arrays as well as their path coordinates. }
    Bytes:=Scene.InstanceSize+Scene.Items.InstanceSize+Int64(Scene.Items.Capacity)*SizeOf(Pointer)+
      Int64(Length(Scene.EditPoints))*SizeOf(TDiagramHandle)+Int64(Length(Scene.EditSegments))*SizeOf(TDiagramSegment);
    for I:=0 to Scene.Items.Count-1 do Inc(Bytes,TPrimitive(Scene.Items[I]).RetainedBytes);
    Scene.Macros:=Registry; Registry:=nil; Result:=Scene; Scene:=nil;
    except on E:Exception do begin Result:=nil; if Diagnostics<>nil then Diagnostics.Add(E.ClassName+': '+E.Message); end; end;
  finally
    if (Result=nil) and (Diagnostics<>nil) then Diagnostics.Add('Native preview stopped near '+Copy(Source,Max(1,CommandStart+1),100));
    if Scene<>nil then Scene.Free;
    for I:=0 to Surfaces.Count-1 do TObject(Surfaces[I]).Free; Surfaces.Free; Nodes.Free;
    GroupOptions.Free; StyleNames.Free; NamedPaths.Free; Colors.Free; NodeStyle.Free; GlobalStyle.Free; Measure.Free; Legends.Free;
    CircuitOptions.Free; CircuitDefaults.Free; TikZDefaults.Free;
    Calc.Free; Parser.Free; Registry.Free; Plots.Free; Style.Free; Options.Free; AxisDefaults.Free; Model.Free; AxisPrevious.Free;
  end;
end;
end.
