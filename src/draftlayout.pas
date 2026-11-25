unit DraftLayout;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}{$modeswitch advancedrecords}
interface
uses Classes, SysUtils, Types, Math, Graphics, IntfGraphics, FPImage, Contnrs, LazUTF8, MathModel, TeXLayout, PreviewImage, GeneratedPreview, ParagraphModel, TeXMacros, TeXContext, TeXBibliography, UITheme, TeXFonts, TeXTextMetrics, TeXGlyphs, TeXFontData, TeXFontShapes, TeXLineBreak, TeXHyphenation, MathSpacing, TeXDocument, TeXTables, VectorPreview, TeXStyles, TeXTextStyle, TeXUnicode, DiagramArrows, NativePagination, TeXSectioning, TeXFontConfig, BeamerModel, BeamerOverlays, BeamerTheme;
type
  TDraftImage=class
    References,Width,Height:Integer;
    Picture:TPicture;
    Surface:TPreviewSurface;
    constructor Create;
    destructor Destroy; override;
    procedure Retain;
    procedure Release;
  end;
  TDraftRegion = record
    ID, FirstChar, CharCount,Baseline,DefinitionArgument,DefinitionOffset,Slide:Integer;
    Bounds:TRect;
    Stops:TCharStops;
    SourceMapped:Boolean;
  end;
  TDraftRegions = array of TDraftRegion;
  TDraftLink=record Bounds:TRect; Offset,ID:Integer; end;
  TDraftLinks=array of TDraftLink;
  TDraftSourceToggle=record
    Bounds,PreviewBounds:TRect;
    Offset:Integer;
    Formula,Expanded:Boolean;
  end;
  TDraftSourceToggles=array of TDraftSourceToggle;
  TDraftChildren=record
  private
    FItems:TFPObjectList;
    function GetCount:Integer;
    function GetItem(Index:Integer):TObject;
  public
    function Add(Item:TObject):Integer;
    procedure Insert(Index:Integer; Item:TObject);
    function Extract(Item:TObject):TObject;
    function IndexOf(Item:TObject):Integer; inline;
    function Last:TObject; inline;
    procedure Clear;
    procedure Free; inline;
    property Count:Integer read GetCount;
    property Items[Index:Integer]:TObject read GetItem; default;
  end;
  TDraftBox = class
    X,Y,W,H,Baseline,ID,FirstChar,Size,BreakPenalty,LinkOffset,DefinitionArgument,DefinitionOffset,Slide:Integer;
    Text,GlyphText,FontName,TextFont,TextOutlineFont,TextFeatures:string;
    TextRun:TTeXTextRun;
    MarginAnchor:TDraftBox;
    TextEm:Double;
    GlueStretch,GlueShrink,HyphenWidth:Double;
    StretchOrder,ShrinkOrder,Leader:Byte;
    KeepGlue:Boolean;
    BreakAfter,Hyphenated,Nonbreaking,InterCharacterGlue,MathGlue:Boolean;
    FontStyle:TFontStyles;
    Color,FillColor:TColor;
    PixelHeight,CharCount,ImagePadding:Integer;
    Stops:TCharStops;
    Anchored,Cached,InlineFlow,SourceMapped,DiagramContent,TextMonospaced,NoHyphenation,ParagraphContent:Boolean;
    CodeText,CodeComment,CodeBackground,ToggleFormula,OwnGenerated,Covered,ClipChildren:Boolean;
    ToggleOffset:Integer;
    Anchor,ImageBounds:TRect;
    ImageWidth:Integer;
    Row,Col:Integer;
    Shape,RuleY,AccentWidth,AccentHeight,AccentVariant:Integer;
    BoxTitleHeight,BoxInnerArc:Integer;
    BoxTitleColor:TColor;
    Glyph,LeftGlyph,RightGlyph,LeftWidth,RightWidth,InkAbove,InkBelow:Integer;
    HasInkMetric:Boolean;
    Lines:array of record A,B:TPoint; Width:Integer; end;
    MathBreaks:array of record Offset,Penalty:Integer; end;
    MathGlues:array of record Offset,Child:Integer; Stretch,Shrink:Double; end;
    Picture:TPicture;
    Surface:TPreviewSurface;
    Image:TDraftImage;
    Generated:TGeneratedPreview;
    Children:TDraftChildren;
    constructor Create;
    destructor Destroy; override;
    procedure Scale(Factor:Double);
  end;
  TParagraphDraft = class
  private
    FCanvas:TCanvas;
    FPaintClip:TRect;
    FPaintOrigin:TPoint;
    FRoot:TDraftBox;
    FLayout:TTeXLayout;
    FSource:string;
    FScale,FEmFactor:Double;
    FNodes:TList;
    FFieldIndex:TMathFieldIndex;
    FControlSourceBase:Integer;
    FTextShapes:TStringList;
    FMacroScopes:TList;
    FSurface:TPreviewSurface;
    FPicture:TPicture;
    FImages:TStringList;
    FDefaultFont,FMathStyle:string;
    FTextStyle:TTeXTextStyle;
    FTextEncoding,FTextRoman,FTextSans,FTextMono:string;
    FTextStyleDepth:Integer;
    FMatrixGap:Integer;
    FDefaultStyle:TFontStyles;
    FDefaultColor:TColor;
    FDefaultHeight:Integer;
    FMathLeaf,FDisplayMath,FCodeLeaf:Boolean;
    FEquationCounter,FMathWidth,FExpansionDepth,FExpansionBudget,FNoteDepth:Integer;
    FMathLevel,FMathBaseSize:Integer;
    FHeadingSize:Integer;
    FHeadingPoints:Double;
    FOpenTypeText:Boolean;
    FStyles,FBaseStyles:TTeXStyles;
    FStyleContext,FStyleDirectory:string;
    FStyleRegistryRevision:QWord;
    FCounterContext:TTeXContext;
    FPageOrigins,FPageGroups:array of Integer;
    FPageLines:TPageLines;
    FBaseHeight,FPageFirst,FPageBody,FPageGap:Integer;
    FAppliedPageShifts:TPageShifts;
    FEditingSpaceID,FEditingSpaceHeight,FEditingSpaceLine,FEditingSpaceSlide:Integer;
    FEditingSpaceBounds:TRect;
    FBeamerTheme:TBeamerTheme;
    FBeamerThemeOwner:Boolean;
    FBeamerContext:string;
    FBeamerRevision:QWord;
    FBeamerProjection:TBeamerProjection;
    FEditingGeometry:array of record Box:TDraftBox; Y,H,Baseline,TitleHeight:Integer; end;
    procedure RestoreEditingSpace;
    procedure InheritDraft(Child:TParagraphDraft);
    function DetachContent(Width:Integer):TDraftBox;
    function ExpandedMacro(Node:TMathNode; Size:Integer):TDraftBox;
    function ExpandedProseMacro(Node:TMathNode):TMathNode;
    function PackageBox(Node:TMathNode; Size:Integer):TDraftBox;
    function NativeBox(Node:TMathNode; Size:Integer; MathMode:Boolean=False):TDraftBox;
    function BoxDimension(const Value:string; Box:TDraftBox; Size,LineWidth,Default:Integer; Vertical:Boolean=False):Integer;
    procedure PositionParagraphBox(Box,Body:TDraftBox; Size:Integer; const Position,Inner,HeightSpec:string);
    function DiagonalBox(Node:TMathNode; Size:Integer):TDraftBox;
    function AnchorFor(ID:Integer):Integer;
    function FieldByID(ID:Integer):TMathNode;
    function TextFontShape(const Family,Series,Shape:string; Points:Double; const Encoding:string):string;
    function TextGlyph(Box:TDraftBox; Code:Integer; Literal:Boolean=False):Integer;
    procedure ShapeTextBox(Box:TDraftBox);
    function EditingCaption(const Name:string):TDraftBox;
    procedure FormulaEnvironmentCaptions(Box:TDraftBox; Node:TMathNode);
    function TextSymbolBox(Node:TMathNode; Size:Integer):TDraftBox;
    function MathGlyphBox(Index,ID,Size,CharCount:Integer):TDraftBox;
    function PackageGlyphBox(Node:TMathNode; Size:Integer; MathMode:Boolean=False):TDraftBox;
    function BraceBox(Node:TMathNode; Size:Integer):TDraftBox;
    function TextAccentBox(Node:TMathNode; Size:Integer):TDraftBox;
    procedure StyleBox(Box:TDraftBox; Index:Integer);
    function FormulaBox(Node:TMathNode; Size:Integer):TDraftBox;
    function SourcePreviewBox(Node:TMathNode; Preview,Code:TDraftBox; Inline:Boolean; Padding:Integer=4):TDraftBox;
    function ProseSourceBox(Node:TMathNode; Size,Width:Integer):TDraftBox;
    function GridBox(Node:TMathNode; Size:Integer; Centered:Boolean; LeftAligned:Boolean=False; RowGap:Integer=0; const ColumnAlign:string=''; Small:Boolean=False):TDraftBox;
    function Leaf(const S:string; ID,Size,FirstChar:Integer):TDraftBox;
    function TextBox(Node:TMathNode; Size:Integer):TDraftBox;
    function TableBox(Node:TMathNode; Size:Integer):TDraftBox;
    function FigureBox(Node:TMathNode; Size:Integer):TDraftBox;
    function PDFPagesBox(Node:TMathNode; Size:Integer):TDraftBox;
    function LogoBox(Node:TMathNode; Size:Integer):TDraftBox;
    function LabelBox(Node:TMathNode; Size:Integer):TDraftBox;
    function DefinitionBox(Node:TMathNode; Size,Width:Integer):TDraftBox;
    function DiagramBox(Node:TMathNode; Size,Width:Integer):TDraftBox;
    procedure AddSourceControl(Box:TDraftBox; PreviewBottom,Offset:Integer; Expanded,Formula:Boolean);
    procedure ClearBoxIDs(Box:TDraftBox);
    function VerbatimBox(Node:TMathNode; Size:Integer):TDraftBox;
    function EnvironmentBox(Node:TMathNode; Size,Width:Integer):TDraftBox;
    function PresentationTheme:TBeamerTheme;
    function BeamerContent(Node:TMathNode; Width:Integer; const Style:string=''; Color:TColor=clNone; MeasureOnly:Boolean=False):TDraftBox;
    function BeamerBox(Node:TMathNode; Size,Width,Slide:Integer):TDraftBox;
    function BeamerTitlePage(Node:TMathNode; Width:Integer):TDraftBox;
    function VerticalSpaceBox(Node:TMathNode; Size:Integer):TDraftBox;
    function GeneratedBox(Node:TMathNode; Width:Integer):TDraftBox;
    function TitleBox(Node:TMathNode; Size,Width:Integer):TDraftBox;
    function MathBox(Node:TMathNode; Size:Integer):TDraftBox;
    function MathBoxContent(Node:TMathNode; Size:Integer):TDraftBox;
    function ModularBox(Node:TMathNode; Size:Integer; const Command:string):TDraftBox;
    function ScriptBox(Node:TMathNode; Size:Integer):TDraftBox;
    function MathFontPoints(Level:Integer):Integer;
    function MathFontSize(Level:Integer):Integer;
    function MathChoiceArgument(Node:TMathNode; Level:Integer; Display:Boolean):TMathNode;
    function MathFontGlyph(const Token:string):Integer;
    function MathTextBox(Node:TMathNode; Size:Integer):TDraftBox;
    function MeasureEm(Size:Integer):Double;
    function LimitSpacing(Size,Index:Integer; Default:Double):Integer;
    function InkTop(Box:TDraftBox):Integer;
    function InkBottom(Box:TDraftBox):Integer;
    function DelimitedBox(Body:TDraftBox; const Left,Right:string; Size,ID:Integer; Stretch:Boolean=True):TDraftBox;
    function DelimiterKind(const Token:string):string;
    function SequenceBox(Node:TMathNode; First,Last,Size:Integer):TDraftBox;
    procedure Collect(Box:TDraftBox; X,Y:Integer; Slide:Integer=0);
    procedure MergeWordRegions;
    function PaintColor(Value:TColor):TColor;
    procedure DrawBox(Box:TDraftBox; X,Y:Integer);
  public
    Context:TTeXContext;
    ContextOffset,SourceBase:Integer;
    Macros:TMacroRegistry;
    HeadingContext:string;
    TeXEngine:string;
    Directory:string;
    HeadingWithChapter:Boolean;
    DocumentFontSize:Integer;
    SourceFontName:string;
    SourceFontPixels:Integer;
    ShowDiagramSource:Boolean;
    ShowSourceControls,OverlaySourceControls:Boolean;
    PreserveColors:Boolean;
    HideEditingMarks,HideEnvironmentCaptions:Boolean;
    PageLayout:Boolean;
    SuppressParagraphIndent:Boolean;
    DiagramSitePrefix:string;
    Generated:TGeneratedPreview;
    TableCellLayout,HboxLayout:Boolean;
    StyleSeed:TTeXStyles;
    TextStyleSeed:TTeXTextStyle;
    TextColorSeed:TColor;
    Regions:TDraftRegions;
    Links:TDraftLinks;
    SourceToggles:TDraftSourceToggles;
    SourceHover:TPoint;
    PinnedSourceOffset:Integer;
    Height:Integer;
    destructor Destroy; override;
    property RootBox:TDraftBox read FRoot;
    function DetachRootBox:TDraftBox;
    function ContentInkBounds:TRect;
    function MarginBounds:TRect;
    function PageLines:TPageLines;
    procedure Paginate(FirstRoom,BodyHeight,Gap:Integer);
    procedure PlacePageLines(const Shifts:TPageShifts; NewHeight:Integer);
    property NativeHeight:Integer read FBaseHeight;
    function SourceControlVisible(const Toggle:TDraftSourceToggle):Boolean;
    function SourcePreviewAt(const Position:TPoint):TMathNode;
    function SetEditingSpace(AnchorID,Space:Integer; Slide:Integer=0):Boolean;
    property EditingSpaceBounds:TRect read FEditingSpaceBounds;
    property EditingSpaceLine:Integer read FEditingSpaceLine;
    procedure PaintSourceControls(Canvas:TCanvas; OffsetX:Integer=0; OffsetY:Integer=0);
    property Styles:TTeXStyles read FStyles;
    procedure Layout(Canvas:TCanvas; Node:TMathNode; Width:Integer; Paragraph:Boolean; FontSize:Integer=12; Previous:TTeXLayout=nil; const Source:string=''; Scale:Double=1; PixelsPerEm:Double=0);
    procedure Paint(Canvas:TCanvas; Surface:TPreviewSurface=nil; Picture:TPicture=nil; OffsetX:Integer=0; OffsetY:Integer=0; DrawControls:Boolean=True);
  end;
implementation
uses CommandDefinition, TeXPackagePreview, DiagramPreview, MathCommands, CommutativeDiagrams, SourceStyle, PlotColors, TikZModel, ListingCode, TeXPreambleCommands, PDFInclusion, TeXDocumentMetrics, OpenTypeShaping, LCLIntf, TeXColors, TeXLists;
constructor TDraftImage.Create;
begin inherited Create; References:=1; Picture:=TPicture.Create; Surface:=TPreviewSurface.Create; Surface.PreserveColors:=True; end;
destructor TDraftImage.Destroy;
begin Surface.Free; Picture.Free; inherited Destroy; end;
procedure TDraftImage.Retain;
begin Inc(References); end;
procedure TDraftImage.Release;
begin Dec(References); if References=0 then Free; end;
function TDraftChildren.GetCount:Integer;
begin if FItems=nil then Result:=0 else Result:=FItems.Count; end;
function TDraftChildren.GetItem(Index:Integer):TObject;
begin
  if FItems=nil then raise EListError.CreateFmt('Invalid child index %d',[Index]);
  Result:=FItems[Index];
end;
function TDraftChildren.Add(Item:TObject):Integer;
begin
  if FItems=nil then FItems:=TFPObjectList.Create(True);
  Result:=FItems.Add(Item);
end;
procedure TDraftChildren.Insert(Index:Integer; Item:TObject);
begin
  if FItems=nil then FItems:=TFPObjectList.Create(True);
  FItems.Insert(Index,Item);
end;
function TDraftChildren.Extract(Item:TObject):TObject;
begin if FItems=nil then Result:=nil else Result:=FItems.Extract(Item); end;
function TDraftChildren.IndexOf(Item:TObject):Integer;
begin if FItems=nil then Result:=-1 else Result:=FItems.IndexOf(Item); end;
function TDraftChildren.Last:TObject;
begin if FItems=nil then Result:=nil else Result:=FItems.Last; end;
procedure TDraftChildren.Clear;
begin FreeAndNil(FItems); end;
procedure TDraftChildren.Free;
begin Clear; end;
constructor TDraftBox.Create;
begin inherited Create; FillColor:=clNone; BoxTitleColor:=clNone; ToggleOffset:=-1; DefinitionArgument:=-1; Glyph:=-1; LinkOffset:=-1; LeftGlyph:=-1; RightGlyph:=-1; ID:=-1; CharCount:=-1; end;
destructor TDraftBox.Destroy;
begin if Image<>nil then Image.Release else begin Surface.Free; Picture.Free; end; if OwnGenerated then Generated.Free; Children.Free; inherited Destroy; end;
procedure TDraftBox.Scale(Factor:Double);
var I:Integer;
  procedure Pixel(var Value:Integer);
  begin Value:=Round(Value*Factor); end;
  procedure Bounds(var Value:TRect);
  begin Pixel(Value.Left); Pixel(Value.Top); Pixel(Value.Right); Pixel(Value.Bottom); end;
begin
  if Factor=1 then Exit;
  Pixel(X); Pixel(Y); Pixel(W); Pixel(H); Pixel(Baseline); Pixel(Size); Pixel(PixelHeight);
  Pixel(ImagePadding); Pixel(ImageWidth); Pixel(RuleY); Pixel(AccentWidth); Pixel(AccentHeight);
  Pixel(BoxTitleHeight); Pixel(BoxInnerArc); Pixel(LeftWidth); Pixel(RightWidth); Pixel(InkAbove); Pixel(InkBelow);
  TextEm:=TextEm*Factor; GlueStretch:=GlueStretch*Factor; GlueShrink:=GlueShrink*Factor; HyphenWidth:=HyphenWidth*Factor;
  Bounds(Anchor);
  for I:=0 to High(Stops) do Pixel(Stops[I]);
  for I:=0 to High(Lines) do begin Pixel(Lines[I].A.X); Pixel(Lines[I].A.Y); Pixel(Lines[I].B.X); Pixel(Lines[I].B.Y); Pixel(Lines[I].Width); end;
  for I:=0 to High(MathBreaks) do Pixel(MathBreaks[I].Offset);
  for I:=0 to High(MathGlues) do begin
    Pixel(MathGlues[I].Offset); MathGlues[I].Stretch:=MathGlues[I].Stretch*Factor; MathGlues[I].Shrink:=MathGlues[I].Shrink*Factor;
  end;
  for I:=0 to Children.Count-1 do TDraftBox(Children[I]).Scale(Factor);
end;
destructor TParagraphDraft.Destroy;
var I:Integer;
begin
  if FBeamerThemeOwner then FBeamerTheme.Free;
  FCounterContext.Free; FStyles.Free; FBaseStyles.Free; FFieldIndex.Free; FNodes.Free; FTextShapes.Free; FRoot.Free;
  if FImages<>nil then begin for I:=0 to FImages.Count-1 do TDraftImage(FImages.Objects[I]).Release; FImages.Free; end;
  inherited Destroy;
end;
function TParagraphDraft.DetachRootBox:TDraftBox;
begin Result:=FRoot; FRoot:=nil; end;
procedure TParagraphDraft.InheritDraft(Child:TParagraphDraft);
begin
  Child.Macros:=Macros; Child.Directory:=Directory; Child.TeXEngine:=TeXEngine;
  Child.Context:=Context; Child.ContextOffset:=ContextOffset; Child.HeadingContext:=HeadingContext;
  Child.StyleSeed:=FStyles; Child.TextStyleSeed:=FTextStyle; Child.TextColorSeed:=FDefaultColor;
  Child.SourceFontName:=SourceFontName; Child.SourceFontPixels:=SourceFontPixels;
  Child.HideEditingMarks:=HideEditingMarks; Child.ShowSourceControls:=ShowSourceControls;
  Child.HideEnvironmentCaptions:=HideEnvironmentCaptions; Child.OverlaySourceControls:=OverlaySourceControls;
  Child.FControlSourceBase:=FControlSourceBase;
  Child.DocumentFontSize:=DocumentFontSize; Child.PreserveColors:=PreserveColors;
  Child.FBeamerTheme:=FBeamerTheme; Child.FBeamerProjection:=FBeamerProjection;
  Child.SuppressParagraphIndent:=True;
end;
function TParagraphDraft.DetachContent(Width:Integer):TDraftBox;
var I:Integer; B:TDraftBox; HaveBaseline:Boolean;
begin
  Result:=DetachRootBox; Result.ParagraphContent:=True; Result.W:=0; Result.H:=Max(0,Height-20); HaveBaseline:=False;
  for I:=0 to Result.Children.Count-1 do begin
    B:=TDraftBox(Result.Children[I]); Dec(B.X,10); Dec(B.Y,10);
    Result.W:=Max(Result.W,B.X+B.W);
    if not HaveBaseline and (B.H>0) and ((B.W>0) or B.HasInkMetric) and
      ((Trim(B.Text)<>'') or (B.Children.Count>0) or (B.Shape<>0) or B.HasInkMetric) then begin
      Result.Baseline:=B.Y+B.Baseline; HaveBaseline:=True;
    end;
  end;
  if Width>=0 then Result.W:=Width;
end;
function TParagraphDraft.PageLines:TPageLines;
var I,J:Integer; Box:TDraftBox;
  function FirstSource(Part:TDraftBox):Integer;
  var Node:TMathNode; K:Integer;
  begin
    Result:=MaxInt; Node:=FieldByID(Part.ID);
    if Node<>nil then begin
      Result:=MathSourceOffset(Node)+Length(UTF8Copy(Node.Text,1,Part.FirstChar));
      Node:=Node.Parent;
      while Node<>nil do begin
        if Node.Kind in [mkFormula,mkDiagram] then Result:=MathSourceOffset(Node)-Length(Node.Prefix);
        Node:=Node.Parent;
      end;
    end;
    for K:=0 to Part.Children.Count-1 do Result:=Min(Result,FirstSource(TDraftBox(Part.Children[K])));
  end;
begin
  if (Generated<>nil) and Generated.IsNative and GeneratedBlock(FSource) then Exit(Generated.PageLines);
  if (Length(FPageOrigins)=0) and (FRoot<>nil) then begin
    SetLength(FPageOrigins,FRoot.Children.Count); SetLength(FPageGroups,FRoot.Children.Count);
    for I:=0 to FRoot.Children.Count-1 do begin
      Box:=TDraftBox(FRoot.Children[I]); FPageOrigins[I]:=Box.Y;
      if Box.MarginAnchor<>nil then begin FPageGroups[I]:=-1; Continue; end;
      J:=High(FPageLines);
      if (J<0) or (Box.Y>=FPageLines[J].Bottom) then begin
        Inc(J); SetLength(FPageLines,J+1); FPageLines[J].Top:=Box.Y; FPageLines[J].SourceOffset:=MaxInt;
      end;
      FPageLines[J].Bottom:=Max(FPageLines[J].Bottom,Box.Y+Max(1,Box.H));
      FPageLines[J].SourceOffset:=Min(FPageLines[J].SourceOffset,FirstSource(Box));
      FPageLines[J].Slide:=Box.Slide;
      FPageLines[J].ForceAfter:=FPageLines[J].ForceAfter or (Box.BreakPenalty=-10000); FPageGroups[I]:=J;
    end;
    for I:=0 to High(FPageLines) do if FPageLines[I].SourceOffset=MaxInt then begin
      if I=0 then FPageLines[I].SourceOffset:=0 else FPageLines[I].SourceOffset:=FPageLines[I-1].SourceOffset;
    end;
    for I:=0 to High(FPageGroups) do if FPageGroups[I]<0 then begin
      J:=FRoot.Children.IndexOf(TDraftBox(FRoot.Children[I]).MarginAnchor);
      if J>=0 then FPageGroups[I]:=FPageGroups[J];
    end;
  end;
  Result:=FPageLines;
end;
procedure TParagraphDraft.Paginate(FirstRoom,BodyHeight,Gap:Integer);
var Shifts:TPageShifts; NewHeight:Integer;
begin
  if (FPageFirst=FirstRoom) and (FPageBody=BodyHeight) and (FPageGap=Gap) then Exit;
  if (Generated<>nil) and Generated.IsNative and GeneratedBlock(FSource) then begin
    Generated.Paginate(FirstRoom,BodyHeight,Gap); Height:=Generated.Height;
    if (FRoot<>nil) and (FRoot.Children.Count>0) then TDraftBox(FRoot.Children[0]).H:=Height;
    Regions:=nil; Links:=nil; SourceToggles:=nil; Collect(FRoot,0,0);
    FPageFirst:=FirstRoom; FPageBody:=BodyHeight; FPageGap:=Gap; Exit;
  end;
  NewHeight:=PaginateLines(PageLines,FBaseHeight,FirstRoom,BodyHeight,Gap,Shifts);
  PlacePageLines(Shifts,NewHeight);
  FPageFirst:=FirstRoom; FPageBody:=BodyHeight; FPageGap:=Gap;
end;
procedure TParagraphDraft.PlacePageLines(const Shifts:TPageShifts; NewHeight:Integer);
var I:Integer;
begin
  if (Generated<>nil) and Generated.IsNative and GeneratedBlock(FSource) then begin
    if (Height=NewHeight) and SamePageShifts(Shifts,FAppliedPageShifts) then Exit;
    Generated.PlacePageLines(Shifts,NewHeight); Height:=Generated.Height;
    if (FRoot<>nil) and (FRoot.Children.Count>0) then TDraftBox(FRoot.Children[0]).H:=Height;
    FAppliedPageShifts:=Copy(Shifts);
    Regions:=nil; Links:=nil; SourceToggles:=nil; Collect(FRoot,0,0);
    FPageBody:=-1; Exit;
  end;
  PageLines;
  if Length(Shifts)<>Length(FPageLines) then Exit;
  if (Height=NewHeight) and SamePageShifts(Shifts,FAppliedPageShifts) then Exit;
  RestoreEditingSpace;
  Height:=NewHeight; FAppliedPageShifts:=Copy(Shifts);
  for I:=0 to High(FPageOrigins) do if FPageGroups[I]>=0 then
    TDraftBox(FRoot.Children[I]).Y:=FPageOrigins[I]+Shifts[FPageGroups[I]];
  Regions:=nil; Links:=nil; SourceToggles:=nil; Collect(FRoot,0,0); MergeWordRegions;
  FPageBody:=-1;
end;
{$I drafteditspace.inc}
function TParagraphDraft.ContentInkBounds:TRect;
var I:Integer; Box:TDraftBox;
begin
  Result:=Rect(MaxInt,MaxInt,0,0);
  if FRoot<>nil then for I:=0 to FRoot.Children.Count-1 do begin
    Box:=TDraftBox(FRoot.Children[I]);
    Result.Left:=Min(Result.Left,Box.X); Result.Right:=Max(Result.Right,Box.X+Box.W);
    Result.Top:=Min(Result.Top,Box.Y+InkTop(Box)); Result.Bottom:=Max(Result.Bottom,Box.Y+InkBottom(Box));
  end;
  if (Result.Right<=Result.Left) or (Result.Bottom<=Result.Top) then Result:=Rect(10,10,10,10);
end;
function TParagraphDraft.MarginBounds:TRect;
var I:Integer; Box:TDraftBox;
begin
  Result:=Rect(0,0,0,0); if FRoot=nil then Exit;
  for I:=0 to FRoot.Children.Count-1 do begin
    Box:=TDraftBox(FRoot.Children[I]); if Box.MarginAnchor=nil then Continue;
    if Result.IsEmpty then Result:=Rect(Box.X,Box.Y,Box.X+Box.W,Box.Y+Box.H)
    else Result:=Rect(Min(Result.Left,Box.X),Min(Result.Top,Box.Y),Max(Result.Right,Box.X+Box.W),Max(Result.Bottom,Box.Y+Box.H));
  end;
end;
function TParagraphDraft.LabelBox(Node:TMathNode; Size:Integer):TDraftBox;
var Field:TMathNode; Part:TDraftBox; Font:string; Style:TFontStyles; Color:TColor; Pixel:Integer; MathLeaf:Boolean;
  procedure Add(const Text:string; ID:Integer);
  begin
    Part:=Leaf(Text,ID,Size,0); Part.X:=Result.W; Inc(Result.W,Part.W);
    Result.H:=Max(Result.H,Part.H); Result.Baseline:=Max(Result.Baseline,Part.Baseline); Result.Children.Add(Part);
  end;
begin
  Result:=TDraftBox.Create;
  if Node.Children.Count=0 then Exit;
  Field:=TMathNode(Node.Children[0]); if Field.Children.Count=0 then Exit; Field:=TMathNode(Field.Children[0]);
  Font:=FDefaultFont; Style:=FDefaultStyle; Pixel:=FDefaultHeight; Color:=FDefaultColor; MathLeaf:=FMathLeaf;
  FDefaultFont:='Monospace'; FDefaultStyle:=[]; FDefaultHeight:=0; FDefaultColor:=clGray; FMathLeaf:=True;
  try Add('[',-1); Add(Field.Text,Field.ID); Add(']',-1);
  finally FDefaultFont:=Font; FDefaultStyle:=Style; FDefaultHeight:=Pixel; FDefaultColor:=Color; FMathLeaf:=MathLeaf; end;
end;
function TParagraphDraft.GeneratedBox(Node:TMathNode; Width:Integer):TDraftBox;
var Link:TGeneratedLink; Box:TDraftBox; Preview:TGeneratedPreview; Owned:Boolean;
begin
  Result:=nil; Preview:=Generated; Owned:=False;
  if Preview=nil then begin
    Preview:=TGeneratedPreview.Create;
    try
      if not Preview.EnsureNative(FCanvas,Node.TeX,Directory,Context,Width,FMathBaseSize,FScale,MeasureEm(FMathBaseSize),Macros,TeXEngine) then Exit;
      Owned:=True;
    finally if not Owned then Preview.Free; end;
  end;
  if Preview.Width<1 then begin if Owned then Preview.Free; Exit; end;
  Result:=TDraftBox.Create; Result.ID:=Node.ID; Result.Shape:=16; Result.Generated:=Preview; Result.OwnGenerated:=Owned;
  if Preview.IsNative then begin Result.W:=Preview.Width; Result.H:=Preview.NativeHeight; end
  else begin Result.W:=Min(Width,Round(Preview.Width*FScale)); Result.H:=Round(Preview.Height*Result.W/Preview.Width); end;
  Result.CharCount:=UTF8Length(Node.Text); SetLength(Result.Stops,Result.CharCount+1);
  if Preview.IsNative then Exit;
  for Link in Preview.Links do begin
    Box:=TDraftBox.Create; Box.LinkOffset:=Link.Offset;
    Box.X:=Round(Link.Bounds.Left*Result.W); Box.Y:=Round(Link.Bounds.Top*Result.H);
    Box.W:=Round((Link.Bounds.Right-Link.Bounds.Left)*Result.W); Box.H:=Round((Link.Bounds.Bottom-Link.Bounds.Top)*Result.H);
    Result.Children.Add(Box);
  end;
end;
function TParagraphDraft.TitleBox(Node:TMathNode; Size,Width:Integer):TDraftBox;
const Names:array[0..2] of string=('title','author','date');
var Items:TObjectList; I:Integer; Text,Value:string; Tree:TMathNode; D:TParagraphDraft;
begin
  Items:=TObjectList.Create(True); D:=TParagraphDraft.Create; Tree:=nil;
  try
    Text:='\begin{center}';
    for I:=0 to High(Names) do begin
      PreambleCommands(HeadingContext,Names[I],Items); Value:='';
      if Items.Count>0 then Value:=TPreambleCommand(Items[Items.Count-1]).Argument;
      if Value='' then Continue;
      if I=0 then Value:='{\LARGE '+Value+'}' else if I=1 then Value:='{\large '+Value+'}';
      Text:=Text+Value+'\par ';
    end;
    Text:=Text+'\end{center}'; Tree:=ParseParagraph(Text,Macros);
    D.Macros:=Macros; D.HeadingContext:=HeadingContext; D.Directory:=Directory; D.TeXEngine:=TeXEngine;
    D.HideEditingMarks:=True; D.DocumentFontSize:=DocumentFontSize; D.PreserveColors:=PreserveColors;
    D.Layout(FCanvas,Tree,Width,True,Size,nil,Text,FScale,MeasureEm(Size));
    Result:=D.DetachRootBox; ClearBoxIDs(Result); Result.ID:=Node.ID;
    Result.W:=Width; Result.H:=D.Height; Result.CharCount:=UTF8Length(Node.Text);
  finally Tree.Free; D.Free; Items.Free; end;
end;
function TParagraphDraft.VerticalSpaceBox(Node:TMathNode; Size:Integer):TDraftBox;
var Value:Double; Units,LabelText:string; Format:TFormatSettings; Caption:TDraftBox;
begin
  Format:=DefaultFormatSettings; Format.DecimalSeparator:='.'; LabelText:=Node.Text;
  Result:=TDraftBox.Create; Result.ID:=Node.ID; Result.Shape:=17; Result.Color:=clGray;
  Result.CharCount:=UTF8Length(Node.Text);
  if ReadVerticalSpace(Node.Text,Value,Units) then begin
    LabelText:=FloatToStr(Value,Format)+' '+Units;
    Result.H:=Round(Abs(TeXStyleDimension(FloatToStr(Value,Format)+Units,MathFontPoints(0)))*MeasureEm(Size)/MathFontPoints(0));
  end;
  Caption:=Leaf(LabelText,-1,Max(7,Round(Size*0.8)),0); Caption.Color:=clGray; Caption.X:=20;
  Result.H:=Max(Caption.H+4,Result.H); Caption.Y:=(Result.H-Caption.H) div 2;
  Result.Children.Add(Caption); Result.W:=Caption.W+24; Result.Baseline:=Caption.Y+Caption.Baseline;
end;
procedure TParagraphDraft.ClearBoxIDs(Box:TDraftBox);
var I:Integer;
begin
  Box.ID:=-1; Box.DefinitionArgument:=-1;
  for I:=0 to Box.Children.Count-1 do ClearBoxIDs(TDraftBox(Box.Children[I]));
end;
procedure TParagraphDraft.AddSourceControl(Box:TDraftBox; PreviewBottom,Offset:Integer; Expanded,Formula:Boolean);
var Header,Part:TDraftBox; I,Gap:Integer;
begin
  Header:=TDraftBox.Create; Header.Shape:=20; Header.ToggleOffset:=Offset+FControlSourceBase; Header.ToggleFormula:=Formula;
  Header.AccentVariant:=Ord(Expanded);
  Box.W:=Max(58,Box.W);
  Header.W:=Box.W-8; Header.H:=28; Header.Baseline:=14;
  Header.X:=4; Header.Y:=PreviewBottom+2; Gap:=Header.H+4;
  for I:=0 to Box.Children.Count-1 do begin
    Part:=TDraftBox(Box.Children[I]); if Part.Y>=Header.Y then Inc(Part.Y,Gap);
  end;
  if Box.Baseline>=Header.Y then Inc(Box.Baseline,Gap);
  if not OverlaySourceControls or Expanded then Box.H:=Max(Box.H+Gap,Header.Y+Header.H+4);
  Box.W:=Max(Box.W,Header.W+8);
  { Source controls share a frame and theme for native diagrams and formulas.
    Header.Anchor records the preview frame relative to the header. }
  Header.Anchor:=Rect(-Header.X,-Header.Y,Box.W-Header.X,1);
  Box.Shape:=24; Box.Children.Add(Header);
end;
function TParagraphDraft.SourceControlVisible(const Toggle:TDraftSourceToggle):Boolean;
begin
  Result:=Toggle.Expanded or (PinnedSourceOffset=Toggle.Offset+1) or
    ((PinnedSourceOffset=0) and (PtInRect(Toggle.PreviewBounds,SourceHover) or PtInRect(Toggle.Bounds,SourceHover)));
end;
function TParagraphDraft.SourcePreviewAt(const Position:TPoint):TMathNode;
var I,Distance,Best:Integer; Node:TMathNode;
begin
  Result:=nil;
  for I:=High(Regions) downto 0 do if PtInRect(Regions[I].Bounds,Position) then begin
    Node:=FieldByID(Regions[I].ID);
    while Node<>nil do begin
      if (Node.Kind=mkDiagram) or ((Node.Kind=mkUnknownCommand) and IsDiagramSource(Node.TeX)) then begin Result:=nil; Break; end;
      if (Node.Kind=mkFormula) or ((Result=nil) and IsSourcePreviewNode(Node)) then Result:=Node;
      if (Node.Kind=mkDefinition) and (Node.Children.Count=2) and (Result<>nil) and
        (MathSourceOffset(Result)<MathSourceOffset(TMathNode(Node.Children[1]))) then Result:=Node;
      Node:=Node.Parent;
    end;
    if Result<>nil then Exit;
  end;
  { Text owns its inline command control. The left gutter exposes the
    enclosing environment, including lists without a printed heading. }
  Best:=33;
  for I:=0 to High(Regions) do if (Position.Y>=Regions[I].Bounds.Top) and
    (Position.Y<Regions[I].Bounds.Bottom) then begin
    Distance:=Regions[I].Bounds.Left-Position.X;
    if (Distance<0) or (Distance>=Best) then Continue;
    Node:=FieldByID(Regions[I].ID);
    while (Node<>nil) and (Node.Kind<>mkEnvironment) do Node:=Node.Parent;
    if (Node<>nil) and IsSourcePreviewNode(Node) then begin Result:=Node; Best:=Distance; end;
  end;
end;
function TParagraphDraft.SourcePreviewBox(Node:TMathNode; Preview,Code:TDraftBox; Inline:Boolean; Padding:Integer):TDraftBox;
var I,Width:Integer; Background:TDraftBox;
begin
  ClearBoxIDs(Preview); Result:=Code;
  Width:=Max(Code.W,Preview.W)+2*Padding;
  Preview.X:=(Width-Preview.W) div 2; Preview.Y:=Padding;
  for I:=0 to Code.Children.Count-1 do Inc(TDraftBox(Code.Children[I]).Y,Preview.H+Padding+2);
  Background:=TDraftBox.Create; Background.CodeBackground:=True; Background.X:=1;
  Background.Y:=Preview.H+Padding+2; Background.H:=Code.H+4;
  Code.Children.Insert(0,Background); Code.Children.Add(Preview);
  Code.W:=Width; Inc(Code.H,Preview.H+2*Padding+4); Code.Baseline:=Preview.Baseline+Padding;
  Code.CodeBackground:=False; Code.ID:=Node.ID; Code.InlineFlow:=Inline;
  if ShowSourceControls then AddSourceControl(Code,Preview.Y+Preview.H,
    MathSourceOffset(Node)-Length(Node.Prefix),True,True);
  Background.W:=Code.W-2; Preview.X:=(Code.W-Preview.W) div 2;
end;
function TParagraphDraft.ProseSourceBox(Node:TMathNode; Size,Width:Integer):TDraftBox;
var Draft:TParagraphDraft; Preview,Code:TDraftBox;
begin
  Draft:=TParagraphDraft.Create; Preview:=nil; Code:=nil;
  try
    InheritDraft(Draft); Draft.HideEditingMarks:=True; Draft.HideEnvironmentCaptions:=True;
    Draft.ShowSourceControls:=False;
    Draft.ContextOffset:=ContextOffset+MathSourceOffset(Node);
    Draft.Layout(FCanvas,Node.SourcePreview,Width+20,True,FMathBaseSize,nil,
      Node.SourcePreview.TeX,FScale,MeasureEm(FMathBaseSize));
    Preview:=Draft.DetachContent(-1);
    Code:=DefinitionBox(TMathNode(Node.Children[0]),Size,Width);
    Result:=SourcePreviewBox(Node,Preview,Code,True); Preview:=nil; Code:=nil;
  finally Code.Free; Preview.Free; Draft.Free; end;
end;
function TParagraphDraft.DefinitionBox(Node:TMathNode; Size,Width:Integer):TDraftBox;
var Field:TMathNode; Line,OldFont,S:string; Part:TDraftBox;
    P,A,First,Chars,Count,MaxChars,CommentStart,OldHeight,I,J,Bytes,BodyX,BodyY:Integer; NameBox,BodyBox,ArgumentBox:TDraftBox; BodyTree:TMathNode; BodyDraft:TParagraphDraft; OldStyle:TFontStyles; OldColor:TColor; OldMathLeaf,OldCodeLeaf:Boolean;
    Definition:TCommandDefinition; OwnTree,Pending:Boolean; Content:TRect; Region:TDraftRegion;
    PDF:IVectorDocument; Diagram,CodeBackground:TDraftBox; PW,PH:Double; DiagramContext:string; Info:TMacroInfo;
  procedure ClearIDs(Box:TDraftBox);
  var J:Integer;
  begin Box.ID:=-1; for J:=0 to Box.Children.Count-1 do ClearIDs(TDraftBox(Box.Children[J])); end;
  procedure ArgumentPart(const Text:string; ID:Integer; Editable:Boolean=False);
  var Piece:TDraftBox;
  begin
    Piece:=Leaf(Text,ID,Size,0); Piece.X:=ArgumentBox.W; Inc(ArgumentBox.W,Piece.W);
    if Editable then begin Piece.Shape:=12; Piece.Color:=clGray; end;
    ArgumentBox.Baseline:=Max(ArgumentBox.Baseline,Piece.Baseline);
    ArgumentBox.H:=Max(ArgumentBox.H,Piece.H); ArgumentBox.Children.Add(Piece);
  end;
begin
  if HideEditingMarks and (Node.Kind=mkUnknownCommand) and (Macros<>nil) then begin
    S:=Node.TeX; P:=1; Info:=Macros.Find(ReadTeXCommand(S,P));
    if (Info<>nil) and ((Info.PreviewAdapter='metadata') or (Info.PreviewAdapter='directive')) then Exit(TDraftBox.Create);
  end;
  Result:=TDraftBox.Create; Result.Shape:=12; Result.ID:=Node.ID; Result.InlineFlow:=True; Result.BreakAfter:=True;
  if (Node.Kind=mkDefinition) and (Node.Children.Count=2) then begin
    Result.Color:=$258ADF;
    OldFont:=FDefaultFont; OldStyle:=FDefaultStyle; OldHeight:=FDefaultHeight; OldMathLeaf:=FMathLeaf; OldCodeLeaf:=FCodeLeaf;
    FDefaultFont:=SourceFontName; if FDefaultFont='' then FDefaultFont:='Monospace';
    FDefaultStyle:=[]; FDefaultHeight:=Round(SourceFontPixels*FScale); FMathLeaf:=True; FCodeLeaf:=True;
    try
      Field:=TMathNode(Node.Children[0]); NameBox:=Leaf(Field.Text,Field.ID,Size,0);
      Part:=Leaf('\',-1,Size,0);
    finally FDefaultFont:=OldFont; FDefaultStyle:=OldStyle; FDefaultHeight:=OldHeight; FMathLeaf:=OldMathLeaf; FCodeLeaf:=OldCodeLeaf; end;
    NameBox.Shape:=12; NameBox.Color:=clGray;
    Part.X:=4; Part.Y:=4; Result.Children.Add(Part);
    NameBox.X:=Part.X+Part.W; NameBox.Y:=4; Result.Children.Add(NameBox);
    { Argument braces are editor notation, not OT1 text slots. }
    FDefaultFont:=NameBox.FontName; FDefaultHeight:=NameBox.PixelHeight; FDefaultStyle:=[];
    FMathLeaf:=True; FCodeLeaf:=True;
    try
      ReadCommandDefinition(Node.TeX,Definition); P:=NameBox.X+NameBox.W+4;
      Count:=Max(Length(Definition.Arguments),DefinitionParameterCount(Definition.Body));
      for I:=1 to Count do begin
        ArgumentBox:=TDraftBox.Create; ArgumentBox.DefinitionArgument:=I-1;
        ArgumentBox.DefinitionOffset:=MathSourceOffset(Node)-Length(Node.Prefix);
        if (I<=Length(Definition.Arguments)) and (Definition.Arguments[I-1].Kind in ['o','O']) then begin
          ArgumentPart('[#'+IntToStr(I)+'=',-1);
          Field:=TMathNode(Node.Children[0]);
          for J:=0 to Field.Children.Count-1 do if TMathNode(Field.Children[J]).DefinitionArgument=I-1 then begin
            Field:=TMathNode(Field.Children[J]); ArgumentPart(Field.Text,Field.ID,True); Break;
          end;
          ArgumentPart(']',-1);
        end else begin
          ArgumentPart('{#'+IntToStr(I)+'}',-1);
          if I>Length(Definition.Arguments) then TDraftBox(ArgumentBox.Children[0]).Color:=clGray;
        end;
        for J:=0 to ArgumentBox.Children.Count-1 do begin
          Part:=TDraftBox(ArgumentBox.Children[J]); Part.Y:=ArgumentBox.Baseline-Part.Baseline;
          ArgumentBox.H:=Max(ArgumentBox.H,Part.Y+Part.H);
        end;
        ArgumentBox.X:=P; ArgumentBox.Y:=4; Inc(P,ArgumentBox.W); Result.Children.Add(ArgumentBox);
      end;
      Part:=Leaf(':=',-1,Size,0);
    finally FDefaultFont:=OldFont; FDefaultHeight:=OldHeight; FDefaultStyle:=OldStyle; FMathLeaf:=OldMathLeaf; FCodeLeaf:=OldCodeLeaf; end;
    Part.X:=P; Part.Y:=4; Result.Children.Add(Part);
    BodyX:=Part.X+Part.W+4; BodyY:=4;
    if Width-BodyX<60 then begin BodyX:=4; BodyY:=Max(NameBox.H,Part.H)+8; end;
    Field:=TMathNode(Node.Children[1]); BodyBox:=nil;
    if (Definition.Body<>'') or (Field.Children.Count>0) then begin
      OwnTree:=Field.Children.Count=0;
      if OwnTree then BodyTree:=ParseParagraph(DefinitionPreviewSource(Field.Text,Macros),Macros)
      else BodyTree:=TMathNode(Field.Children[0]);
      BodyDraft:=TParagraphDraft.Create;
      try
        InheritDraft(BodyDraft);
        BodyDraft.SourceBase:=MathSourceOffset(BodyTree);
        BodyDraft.Layout(FCanvas,BodyTree,Max(60,Width-BodyX-4)+20,True,Size,nil,Definition.Body,FScale,MeasureEm(Size));
        BodyBox:=BodyDraft.DetachRootBox; Content:=Rect(10,10,10,10);
        for I:=0 to BodyBox.Children.Count-1 do begin
          NameBox:=TDraftBox(BodyBox.Children[I]);
          Content:=Rect(Min(Content.Left,NameBox.X),Min(Content.Top,NameBox.Y),
            Max(Content.Right,NameBox.X+NameBox.W),Max(Content.Bottom,NameBox.Y+NameBox.H));
          if I=0 then BodyBox.Baseline:=NameBox.Y+NameBox.Baseline;
        end;
        { Include actual glyph ink, not just advance widths. Italics, accents,
          and nested scripts can extend outside a child's logical box. }
        for Region in BodyDraft.Regions do Content:=Rect(Min(Content.Left,Region.Bounds.Left),
          Min(Content.Top,Region.Bounds.Top),Max(Content.Right,Region.Bounds.Right),Max(Content.Bottom,Region.Bounds.Bottom));
        for I:=0 to BodyBox.Children.Count-1 do begin
          NameBox:=TDraftBox(BodyBox.Children[I]); Inc(NameBox.X,4-Content.Left); Inc(NameBox.Y,4-Content.Top);
        end;
        Inc(BodyBox.Baseline,4-Content.Top);
        BodyBox.W:=Content.Width+8; BodyBox.H:=Content.Height+8;
      finally BodyDraft.Free; if OwnTree then BodyTree.Free; end;
      NameBox:=TDraftBox(Result.Children[1]);
    end;
    if BodyBox=nil then BodyBox:=Leaf(Field.Text,Field.ID,Size,0);
    if Field.Children.Count=0 then begin
      ClearIDs(BodyBox); BodyBox.ID:=Field.ID; BodyBox.CharCount:=UTF8Length(Field.Text);
      SetLength(BodyBox.Stops,BodyBox.CharCount+1);
      for I:=0 to BodyBox.CharCount do BodyBox.Stops[I]:=Round(BodyBox.W*I/Max(1,BodyBox.CharCount));
    end;
    if ShowSourceControls then AddSourceControl(BodyBox,IfThen(Node.SourceExpanded,-2,BodyBox.H-2),
      MathSourceOffset(Node)-Length(Node.Prefix),Node.SourceExpanded,False);
    if BodyBox.W+BodyX+4>Width then begin BodyX:=4; BodyY:=Max(NameBox.H,Part.H)+8; end;
    BodyBox.X:=BodyX; BodyBox.Y:=BodyY; Result.Children.Add(BodyBox);
    Result.W:=Max(Part.X+Part.W+4,BodyBox.X+Max(12,BodyBox.W)+4);
    Result.Baseline:=4+Max(NameBox.Baseline,BodyBox.Baseline);
    for I:=0 to Result.Children.Count-1 do begin Part:=TDraftBox(Result.Children[I]); if (Part<>BodyBox) or (BodyY=4) then Part.Y:=Result.Baseline-Part.Baseline; Result.H:=Max(Result.H,Part.Y+Part.H+4); end;
    Exit;
  end;

  if Node.Children.Count=0 then Field:=Node else Field:=TMathNode(Node.Children[0]);
  S:=Field.Text;
  Result.CodeBackground:=True;
  OldFont:=FDefaultFont; OldStyle:=FDefaultStyle; OldHeight:=FDefaultHeight; OldColor:=FDefaultColor; OldMathLeaf:=FMathLeaf;
  OldCodeLeaf:=FCodeLeaf; FCodeLeaf:=True;
  FDefaultFont:=SourceFontName; if FDefaultFont='' then FDefaultFont:='Monospace';
  FDefaultStyle:=[]; FDefaultHeight:=Round(SourceFontPixels*FScale); FDefaultColor:=clGray; FMathLeaf:=True;
  if Node.Kind=mkComment then begin Result.Color:=$408040; FDefaultColor:=Result.Color; end
  else Result.Color:=clGray;
  try
    { Measure a run: a rounded single-glyph advance overestimates the number
      of characters that fit, especially with fractional Qt font metrics. }
    Part:=Leaf(StringOfChar('M',32),-1,Size,0); MaxChars:=Max(1,Floor((Width-8)*32/Max(1,Part.W))); Part.Free;
    P:=1; First:=0; Result.H:=4; CommentStart:=SourceCommentStart(S,P);
    repeat
      A:=P; Chars:=0;
      while (P<=Length(S)) and not (S[P] in [#10,#13]) and (Chars<MaxChars) do begin
        Bytes:=UTF8CharacterLength(PChar(S)+P-1); Inc(P,Max(1,Bytes)); Inc(Chars);
      end;
      Line:=Copy(S,A,P-A); Part:=Leaf(Line,Field.ID,Size,First);
      while (Part.W>Width-8) and (Chars>1) do begin
        Dec(Chars); Line:=UTF8Copy(Line,1,Chars); P:=A+Length(Line);
        Part.Free; Part:=Leaf(Line,Field.ID,Size,First);
      end;
      Count:=Chars;
      if (P<=Length(S)) and (S[P] in [#10,#13]) then begin
        if (S[P]=#13) and (Copy(S,P+1,1)=#10) then begin Inc(P); Inc(Count); end;
        Inc(P); Inc(Count);
      end;
      Part.CharCount:=Count; Part.Anchored:=False;
      Part.CodeText:=True;
      Part.CodeComment:=(CommentStart>0) and (A>CommentStart);
      if Count>Chars then CommentStart:=SourceCommentStart(S,P);
      if Length(Part.Stops)=0 then begin
        SetLength(Part.Stops,Chars+1);
        for I:=1 to Chars do Part.Stops[I]:=TeXTextWidth(FCanvas,UTF8Copy(Line,1,I));
      end;
      SetLength(Part.Stops,Count+1);
      for I:=Chars+1 to Count do Part.Stops[I]:=Part.W;
      Part.X:=4; Part.Y:=Result.H;
      if Result.Children.Count=0 then Result.Baseline:=Part.Y+Part.Baseline;
      Inc(Result.H,Part.H+2); Result.W:=Max(Result.W,Part.W+8); Result.Children.Add(Part);
      Inc(First,Count);
    until P>Length(S);
    Inc(Result.H,2);
  finally FDefaultFont:=OldFont; FDefaultStyle:=OldStyle; FDefaultHeight:=OldHeight; FDefaultColor:=OldColor; FMathLeaf:=OldMathLeaf; FCodeLeaf:=OldCodeLeaf; end;
  if (Node.Kind=mkUnknownCommand) and not Node.SourceEditing and IsDiagramSource(S) and DiagramPreviewEnabled then begin
    Result.DiagramContent:=True;
    Diagram:=TDraftBox.Create; Diagram.Picture:=TPicture.Create;
    DiagramContext:=HeadingContext+LineEnding+TeXContextDeclarations(Copy(FSource,1,MathSourceOffset(Node)));
    if RequestDiagramPreview(DiagramContext,S,Directory,TeXEngine,
      DiagramSitePrefix+':'+IntToStr(ContextOffset+MathSourceOffset(Node)),PDF,Diagram.Picture,Pending) then begin
      Diagram.Shape:=10; Diagram.Surface:=TPreviewSurface.Create; Diagram.Surface.SetSourceGraphics(S);
      PW:=Diagram.Picture.Width*72/120; PH:=Diagram.Picture.Height*72/120;
      if PDF<>nil then begin PDF.PageSize(1,PW,PH); Diagram.Surface.SetVector(PDF,1); end;
      Diagram.W:=Min(Width-8,Max(1,Round(PW*120*FScale/72))); Diagram.H:=Max(1,Round(PH*Diagram.W/Max(1,PW)));
      Diagram.X:=4; Diagram.Y:=4; Diagram.Baseline:=Diagram.H;
      if ShowSourceControls and not Node.SourceCollapsed then Node.SourceExpanded:=True;
      if ShowDiagramSource or Node.SourceExpanded or Node.SourceEditing then begin
        for I:=0 to Result.Children.Count-1 do Inc(TDraftBox(Result.Children[I]).Y,Diagram.H+6);
        CodeBackground:=TDraftBox.Create; CodeBackground.CodeBackground:=True;
        CodeBackground.X:=1; CodeBackground.Y:=Diagram.H+6; CodeBackground.W:=Result.W-2; CodeBackground.H:=Result.H-1;
        Result.Children.Insert(0,CodeBackground);
        Inc(Result.H,Diagram.H+6); Inc(Result.Baseline,Diagram.H+6);
      end else begin
        Result.Children.Clear; Result.W:=Diagram.W+8; Result.H:=Diagram.H+8; Result.Baseline:=Diagram.H+4;
      end;
      Result.W:=Max(Result.W,Diagram.W+8); Diagram.X:=(Result.W-Diagram.W) div 2; Result.Children.Add(Diagram);
      Result.CodeBackground:=False;
      if ShowSourceControls then AddSourceControl(Result,Diagram.Y+Diagram.H,
        MathSourceOffset(Node)-Length(Node.Prefix),ShowDiagramSource or Node.SourceExpanded or Node.SourceEditing,False);
      Diagram.X:=(Result.W-Diagram.W) div 2;
      if Pending then Result.Color:=$16A9CF;
    end else Diagram.Free;
  end;
end;
{$I commutativelayout.inc}
function TParagraphDraft.TextFontShape(const Family,Series,Shape:string; Points:Double; const Encoding:string):string;
var Key:string; I:Integer;
begin
  Key:=Encoding+#1+Family+#1+Series+#1+Shape+#1+FloatToStr(Points);
  I:=FTextShapes.IndexOfName(Key); if I>=0 then Exit(FTextShapes.ValueFromIndex[I]);
  if Encoding='TU' then Result:=UnicodeFontShape(Family,Series,Shape,Points,Directory)
  else Result:=MetricFontShape(Family,Series,Shape,Points,Directory,Encoding);
  if FTextShapes.Count<128 then FTextShapes.Add(Key+#2+Result);
end;
function TParagraphDraft.Leaf(const S:string; ID,Size,FirstChar:Integer):TDraftBox;
var Metrics:TLCLTextMetric; Above,Depth,Em,ExactPoints,RunWidth:Double; Style,Family,FontFile,Series,Shape,Encoding,Character,Previous:string; Font:TTeXFontMetric; I,J,Points,Code,P,Bytes:Integer; Child,SpaceBox:TDraftBox; Face:TFontFace;
    CharacterCJK,PreviousCJK,HasCJK:Boolean;
begin
  HasCJK:=ContainsCJK(S);
  Result:=TDraftBox.Create; Result.ID:=ID; Result.Text:=S;
  Result.Size:=Size; Result.FirstChar:=FirstChar;
  Result.FontName:=FDefaultFont; Result.FontStyle:=FDefaultStyle;
  Result.TextEm:=MeasureEm(Size);
  if not FMathLeaf then Result.TextEm:=MeasureEm(FMathBaseSize)*FTextStyle.Points/MathFontPoints(0);
  if not FMathLeaf and (FHeadingSize>0) then Result.TextEm:=FHeadingPoints*Size/FHeadingSize*MeasureEm(FMathBaseSize)/MathFontPoints(0);
  Result.PixelHeight:=FDefaultHeight; if Result.PixelHeight=0 then Result.PixelHeight:=Max(1,Round(Result.TextEm));
  Result.Color:=FDefaultColor;
  if not FMathLeaf then StyleBox(Result,AnchorFor(ID));
  if not FMathLeaf and HasCJK and (UTF8Length(S)>1) then begin
    SetLength(Result.Stops,UTF8Length(S)+1);
    P:=1; Character:=''; CharacterCJK:=False;
    for I:=1 to High(Result.Stops) do begin
      Previous:=Character; PreviousCJK:=CharacterCJK;
      Bytes:=Min(Max(1,UTF8CharacterLength(PChar(S)+P-1)),Length(S)-P+1);
      Character:=Copy(S,P,Bytes); Inc(P,Bytes); CharacterCJK:=ContainsCJK(Character);
      if (I>1) and CharacterCJK and PreviousCJK then
        Inc(Result.W,Round(FTextStyle.CJKSpacing*Result.TextEm));
      { Heading numbers and captions also need xeCJK's CJK/Latin glue.
        A combined label bypasses the paragraph's separate-token glue. }
      if (I>1) and (CharacterCJK<>PreviousCJK) and
        (Trim(Character)<>'') and (Trim(Previous)<>'') and
        (Pos(Character,',.;:!?)]}，。！？、：；）》】」』')=0) and
        (Pos(Previous,'([{（【《「『')=0) then begin
        SpaceBox:=Leaf(' ',-1,Size,0); Inc(Result.W,SpaceBox.W); SpaceBox.Free;
      end;
      Child:=Leaf(Character,-1,Size,FirstChar+I-1); Child.X:=Result.W;
      Result.Children.Add(Child); Inc(Result.W,Child.W); Result.Stops[I]:=Result.W;
      Result.Baseline:=Max(Result.Baseline,Child.Baseline);
    end;
    for I:=0 to Result.Children.Count-1 do begin
      Child:=TDraftBox(Result.Children[I]); Child.Y:=Result.Baseline-Child.Baseline; Result.H:=Max(Result.H,Child.Y+Child.H);
    end;
    Exit;
  end;
  Face:=Default(TFontFace);
  if not FCodeLeaf and (not FMathLeaf or HasCJK) then begin
    Style:='rm'; if FTextStyle.Family=FTextStyle.Sans then Style:='sf' else if FTextStyle.Family=FTextStyle.Mono then Style:='tt';
    if FDefaultFont='Latin Modern Sans' then Style:='sf' else if FDefaultFont='Latin Modern Mono' then Style:='tt';
    if HasCJK and (FTextStyle.CJKFamily<>'') then Style:=FTextStyle.CJKFamily;
    if not HasCJK and (FTextStyle.Family<>FTextStyle.Roman) and
      (FTextStyle.Family<>FTextStyle.Sans) and (FTextStyle.Family<>FTextStyle.Mono) then Style:=FTextStyle.Family;
    Series:=FTextStyle.Series; Shape:=FTextStyle.Shape;
    if fsBold in FDefaultStyle then Series:='bx';
    if (fsItalic in FDefaultStyle) and (Shape='n') then Shape:='it';
    Face:=DocumentTextFace(HeadingContext,Style,Series,Shape,Directory,HasCJK,TeXEngine);
    if Face.Name<>'' then begin
      Result.FontName:=Face.Name; Result.FontStyle:=[];
      if Face.Bold then Include(Result.FontStyle,fsBold); if Face.Italic then Include(Result.FontStyle,fsItalic);
      Result.TextEm:=Result.TextEm*Face.Scale; Result.PixelHeight:=Max(1,Round(Result.TextEm));
      if not HasCJK then begin
        Family:=ResolveTeXFont(Face.Name); if Family<>'' then Result.FontName:=Family;
      end;
    end;
  end;
  if not FCodeLeaf and HasCJK and (UTF8Length(S)=1) then begin
    FontFile:=Face.FileName;
    if FontFile='' then FontFile:=OpenTypeFontFile(Result.FontName,Result.FontStyle);
    Result.TextOutlineFont:=FontFile;
    Code:=UTF8CodepointToUnicode(PChar(S),I);
    if (FontFile<>'') and (Face.Features<>'') then begin
      Result.TextOutlineFont:=FontFile; Result.TextFeatures:=Face.Features; ShapeTextBox(Result);
    end;
    if Result.TextRun.Valid then Result.Glyph:=TextGlyph(Result,Result.TextRun.Glyphs[0].Code)
    else if FontFile<>'' then Result.Glyph:=ChooseTeXGlyph('unicode-'+FontFile+'-'+IntToStr(Code));
    if (Result.Glyph>=0) or Result.TextRun.Valid then begin
      Em:=Result.TextEm;
      if not Result.TextRun.Valid then begin
        Result.Shape:=11; Result.W:=Round(TeXGlyphMetrics[Result.Glyph].Advance*Em);
        Result.HasInkMetric:=True;
        Result.InkAbove:=Ceil(TeXGlyphMetrics[Result.Glyph].Above*Em);
        Result.InkBelow:=Ceil((TeXGlyphMetrics[Result.Glyph].H-TeXGlyphMetrics[Result.Glyph].Above)*Em);
      end;
      Result.Baseline:=Max(Result.InkAbove,Round(0.7*1.2*Em));
      Result.H:=Result.Baseline+Max(Result.InkBelow,Round(0.3*1.2*Em));
      SetLength(Result.Stops,2); Result.Stops[1]:=Result.W;
    end;
  end;
  if not FCodeLeaf and not FMathLeaf and not HasCJK and (Face.Name='') then begin
    Family:=FTextStyle.Family; Series:=FTextStyle.Series; Shape:=FTextStyle.Shape;
    if fsBold in FDefaultStyle then Series:='bx';
    if (fsItalic in FDefaultStyle) and (Shape='n') then Shape:='it';
    if FDefaultFont='Latin Modern Sans' then Family:=FTextSans
    else if FDefaultFont='Latin Modern Mono' then Family:=FTextMono;
    ExactPoints:=FTextStyle.Points;
    if FHeadingSize>0 then ExactPoints:=FHeadingPoints*Size/FHeadingSize;
    Encoding:=FTextEncoding; if Encoding='TU' then Encoding:='OT1';
    Points:=Max(5,Round(Size*MathFontPoints(0)/Max(1,FMathBaseSize)));
    if (FLayout<>nil) and (Result.FontName=ResolveTeXFont('CMR12')) then Points:=Max(12,Points);
    Result.TextFont:=TextFontShape(Family,Series,Shape,ExactPoints,Encoding);
    Result.TextMonospaced:=Family=FTextMono;
    if Result.TextFont='' then Result.TextFont:='cmr10';
    Font:=TeXFontMetric(Result.TextFont);
    Result.TextRun:=Font.ShapeText(S);
    if Result.TextRun.Valid then begin
      Em:=MeasureEm(FMathBaseSize)*ExactPoints/MathFontPoints(0);
      Result.TextEm:=Em;
      if FOpenTypeText then begin
        { The NFSS family, not the widget fallback font name, chooses the
          outline. Beamer and inherited font switches can select sans while
          FontName still contains the default Roman fallback. }
        if Family='cmr' then Family:='lmr'
        else if Family='cmss' then Family:='lmss'
        else if Family='cmtt' then Family:='lmtt';
        Result.TextOutlineFont:=TextFontShape(Family,Series,Shape,ExactPoints,'TU');
        { TU uses Unicode input. OT1 supplies ligatures and kerning here, but
          its punctuation slots are not the Unicode characters at those codes. }
        RunWidth:=0;
        for I:=0 to High(Result.TextRun.Glyphs) do with Result.TextRun.Glyphs[I] do begin
          if (Count=1) and (Code in [60,62,92,94,95,123..126]) then begin
            J:=ChooseTeXGlyph('unicode-'+Result.TextOutlineFont+'-'+IntToStr(Code));
            if J>=0 then begin
              Result.TextRun.Glyphs[I].Advance:=TeXGlyphMetrics[J].Advance; Kern:=0;
              Result.TextRun.Height:=Max(Result.TextRun.Height,TeXGlyphMetrics[J].Above);
              Result.TextRun.Depth:=Max(Result.TextRun.Depth,TeXGlyphMetrics[J].H-TeXGlyphMetrics[J].Above);
            end;
          end;
          X:=RunWidth;
          for J:=1 to Count do Result.TextRun.Stops[First+J]:=X+Result.TextRun.Glyphs[I].Advance*J/Count;
          RunWidth:=X+Result.TextRun.Glyphs[I].Advance+Kern;
          Result.TextRun.Stops[First+Count]:=RunWidth;
        end;
        Result.TextRun.Width:=RunWidth;
      end;
      Result.W:=Round(Result.TextRun.Width*Em);
      Result.HasInkMetric:=True; Result.InkAbove:=Round(Result.TextRun.Height*Em); Result.InkBelow:=Round(Result.TextRun.Depth*Em);
      Result.Baseline:=Max(Round(Result.TextRun.Height*Em),Round(0.7*1.2*Em));
      Result.H:=Result.Baseline+Max(Round(Result.TextRun.Depth*Em),Round(0.3*1.2*Em));
      SetLength(Result.Stops,Length(Result.TextRun.Stops));
      for I:=0 to High(Result.Stops) do Result.Stops[I]:=Round(Result.TextRun.Stops[I]*Em);
      if S=' ' then begin
        if Length(Font.Parameters)>2 then Result.GlueStretch:=Font.Parameters[2]*Em;
        if Length(Font.Parameters)>3 then Result.GlueShrink:=Font.Parameters[3]*Em;
      end;
    end;
  end;
  if not FCodeLeaf and not FMathLeaf and not HasCJK and (Face.FileName<>'') then begin
    Result.TextOutlineFont:=Face.FileName; Result.TextFeatures:=Face.Features;
    Result.NoHyphenation:=not Face.Hyphenate;
    ShapeTextBox(Result);
    if Result.TextRun.Valid then begin
      Result.Baseline:=Max(Result.InkAbove,Round(0.7*1.2*Result.TextEm));
      Result.H:=Result.Baseline+Max(Result.InkBelow,Round(0.3*1.2*Result.TextEm));
      if S=' ' then begin
        Em:=Result.TextRun.Width*Result.TextEm;
        Result.GlueStretch:=Em/2*Face.SpaceStretch; Result.GlueShrink:=Em/3*Face.SpaceShrink;
        Result.TextRun.Width:=Result.TextRun.Width*Face.WordSpace;
        Result.TextRun.Stops[1]:=Result.TextRun.Width;
        Result.W:=Round(Result.TextRun.Width*Result.TextEm); Result.Stops[1]:=Result.W;
      end;
    end;
  end;
  { TeX metrics already give all advances and baselines. Selecting and measuring
    the same run in the widget font system adds work and cannot improve them. }
  if not Result.TextRun.Valid and (Result.Shape<>11) then begin
    FCanvas.Font.Name:=Result.FontName; FCanvas.Font.Style:=Result.FontStyle;
    if Result.PixelHeight>0 then FCanvas.Font.Height:=-Result.PixelHeight else FCanvas.Font.Size:=Size;
    Result.W:=TeXTextWidth(FCanvas,S);
    Result.H:=Max(1,Max(FCanvas.TextHeight('Mg'),FCanvas.TextHeight(S))); Result.Baseline:=Result.H*4 div 5;
    if FCanvas.GetTextMetrics(Metrics) then
    begin Result.H:=Max(Result.H,Metrics.Height); Result.Baseline:=Metrics.Ascender; end;
    if not FCodeLeaf and not FMathLeaf and (Face.FileName<>'') then begin
      { Font ascenders describe the whole face, not the height of this TeX
        hbox. Use glyph ink for vertical packing, retaining native shaping. }
      P:=1; Above:=0; Depth:=0;
      while P<=Length(S) do begin
        Code:=NextUTF8CodePoint(S,P); J:=ChooseTeXGlyph('unicode-'+Face.FileName+'-'+IntToStr(Code));
        if J<0 then Continue;
        Above:=Max(Above,TeXGlyphMetrics[J].Above);
        Depth:=Max(Depth,TeXGlyphMetrics[J].H-TeXGlyphMetrics[J].Above);
      end;
      Result.HasInkMetric:=True; Result.InkAbove:=Round(Above*Result.TextEm); Result.InkBelow:=Round(Depth*Result.TextEm);
    end;
  end;
  if FCodeLeaf then Exit;
  if TableCellLayout and not FMathLeaf then begin
    Style:='\mathrm'; if fsItalic in Result.FontStyle then Style:='\mathit';
    if MathInkMetrics(S,Style,Above,Depth) then begin
      Result.HasInkMetric:=True; Result.InkAbove:=Round(Above*MeasureEm(Size)); Result.InkBelow:=Round(Depth*MeasureEm(Size));
    end;
  end;
end;
function TParagraphDraft.EditingCaption(const Name:string):TDraftBox;
var FontName:string; Pixel:Integer; Style:TFontStyles; Color:TColor; MathLeaf,CodeLeaf:Boolean;
begin
  FontName:=FDefaultFont; Pixel:=FDefaultHeight; Style:=FDefaultStyle; Color:=FDefaultColor;
  MathLeaf:=FMathLeaf; CodeLeaf:=FCodeLeaf;
  try
    FDefaultFont:=SourceFontName; if FDefaultFont='' then FDefaultFont:='monospace';
    FDefaultHeight:=Max(8,Round(10*FScale)); FDefaultStyle:=[]; FDefaultColor:=clGray;
    FMathLeaf:=True; FCodeLeaf:=True; Result:=Leaf(Name,-1,8,0);
  finally
    FDefaultFont:=FontName; FDefaultHeight:=Pixel; FDefaultStyle:=Style; FDefaultColor:=Color;
    FMathLeaf:=MathLeaf; FCodeLeaf:=CodeLeaf;
  end;
end;
procedure TParagraphDraft.FormulaEnvironmentCaptions(Box:TDraftBox; Node:TMathNode);
var Names:string; Caption:TDraftBox;
  procedure Find(N:TMathNode);
  var I:Integer; Name:string;
  begin
    Name:=MathEnvironmentName(N);
    if Name<>'' then begin if Names<>'' then Names:=Names+' · '; Names:=Names+Name; end;
    for I:=0 to N.Children.Count-1 do Find(TMathNode(N.Children[I]));
  end;
begin
  if HideEditingMarks or HideEnvironmentCaptions then Exit; Names:=''; Find(Node); if Names='' then Exit;
  Caption:=EditingCaption(Names); Caption.X:=Max(0,(Box.W-Caption.W) div 2); Caption.Y:=Box.H+3;
  { This footer is editor chrome. Preserve the math's ink bounds and baseline. }
  Box.InkAbove:=Box.Baseline-InkTop(Box); Box.InkBelow:=Max(0,InkBottom(Box)-Box.Baseline); Box.HasInkMetric:=True;
  Box.Children.Add(Caption); Inc(Box.H,Caption.H+4);
end;
function TParagraphDraft.TextGlyph(Box:TDraftBox; Code:Integer; Literal:Boolean):Integer;
var NativeCode:Integer;
begin
  Result:=-1;
  if Code<0 then Exit(ChooseTeXGlyph('glyph-'+Box.TextOutlineFont+'-'+IntToStr(-Code-1)));
  if Box.TextOutlineFont<>'' then begin
    NativeCode:=Code;
    if not Box.TextMonospaced and not (Literal and (Code in [60,62,92,94,95,123..126])) then NativeCode:=OT1Unicode(Code);
    Result:=ChooseTeXGlyph('unicode-'+Box.TextOutlineFont+'-'+IntToStr(NativeCode));
  end;
  if Result<0 then Result:=ChooseTeXGlyph('text-'+Box.TextFont+'-'+IntToStr(Code));
end;
procedure TParagraphDraft.ShapeTextBox(Box:TDraftBox);
var I:Integer;
begin
  if Box.TextFont='' then Box.TextRun:=ShapeOpenType(Box.TextOutlineFont,Box.Text,Box.TextFeatures)
  else Box.TextRun:=TeXFontMetric(Box.TextFont).ShapeText(Box.Text);
  if not Box.TextRun.Valid then Exit;
  Box.W:=Round(Box.TextRun.Width*Box.TextEm); Box.HasInkMetric:=True;
  Box.InkAbove:=Ceil(Box.TextRun.Height*Box.TextEm); Box.InkBelow:=Ceil(Box.TextRun.Depth*Box.TextEm);
  SetLength(Box.Stops,Length(Box.TextRun.Stops));
  for I:=0 to High(Box.Stops) do Box.Stops[I]:=Round(Box.TextRun.Stops[I]*Box.TextEm);
end;
function TParagraphDraft.MathGlyphBox(Index,ID,Size,CharCount:Integer):TDraftBox;
var I:Integer; Em:Double;
begin
  Em:=MeasureEm(Size);
  Result:=TDraftBox.Create; Result.Color:=FDefaultColor; Result.Shape:=8;
  Result.Glyph:=Index; Result.ID:=ID; Result.Size:=Size; Result.CharCount:=CharCount;
  Result.W:=Max(1,Round(TeXGlyphMetrics[Index].Advance*Em));
  { Keep layout distances stable; painting includes the rounded ink overhang. }
  Result.H:=Max(1,Round(TeXGlyphMetrics[Index].H*Em));
  Result.Baseline:=Round(TeXGlyphMetrics[Index].Above*Em);
  Result.HasInkMetric:=True; Result.InkAbove:=Result.Baseline; Result.InkBelow:=Result.H-Result.Baseline;
  if CharCount>0 then begin
    SetLength(Result.Stops,CharCount+1);
    for I:=1 to CharCount do Result.Stops[I]:=Result.W;
  end;
end;
function TParagraphDraft.PackageGlyphBox(Node:TMathNode; Size:Integer; MathMode:Boolean):TDraftBox;
var Info:TMacroInfo; I,P:Integer; Em:Double; Metric:TTeXCharMetric; Plan:string;
begin
  Result:=nil; if (Macros=nil) or (Node.Kind<>mkCommand) then Exit;
  Info:=Macros.Find(Copy(Node.Text,2,MaxInt));
  if (Info<>nil) and (Info.GlyphPlan<>'') then begin
    Plan:=Info.GlyphPlan; if MathMode and (Info.MathGlyphPlan<>'') then Plan:=Info.MathGlyphPlan;
    I:=ChooseTeXGlyph('symbol-run-'+Plan);
    if I>=0 then begin
      Result:=MathGlyphBox(I,Node.ID,Size,UTF8Length(Node.Text)); Exit;
    end;
  end;
  if (Info<>nil) and (Info.GlyphFont<>'') then begin
    P:=Info.GlyphCode; Metric:=TeXFontMetric(Info.GlyphFont).Chars[P];
    if FDisplayMath and (Info.SymbolClass='\mathop') and (Metric.Tag=2) then begin
      P:=Metric.Remainder; Metric:=TeXFontMetric(Info.GlyphFont).Chars[P];
    end;
    if Info.SymbolClass='\mathop' then begin
      I:=ChooseTeXGlyph('operator-text-'+Info.GlyphFont+'-'+IntToStr(P));
      if I>=0 then Exit(MathGlyphBox(I,Node.ID,Size,UTF8Length(Node.Text)));
    end;
    I:=ChooseTeXGlyph('text-'+Info.GlyphFont+'-'+IntToStr(P));
    if I>=0 then begin
      Result:=TDraftBox.Create; Result.Color:=FDefaultColor; Result.ID:=Node.ID; Result.Glyph:=I; Result.Shape:=11; Result.Size:=Size;
      Em:=MeasureEm(Size);
      Result.W:=Max(1,Round(Metric.Width*Em)); Result.InkAbove:=Ceil(Metric.Height*Em); Result.InkBelow:=Ceil(Metric.Depth*Em);
      Result.HasInkMetric:=True; Result.Baseline:=Result.InkAbove; Result.H:=Max(1,Result.Baseline+Result.InkBelow);
      Result.Color:=FDefaultColor; Result.CharCount:=UTF8Length(Node.Text); SetLength(Result.Stops,Result.CharCount+1);
      for P:=1 to Result.CharCount do Result.Stops[P]:=Result.W;
      Exit;
    end;
  end;
end;
function TParagraphDraft.TextSymbolBox(Node:TMathNode; Size:Integer):TDraftBox;
var Family,Series,Font,Command,Visible,SymbolEncoding:string; Points,I,P,Code:Integer; Em:Double;
begin
  Result:=nil; P:=1; Command:=ReadTeXCommand(Node.Text,P); SymbolEncoding:=''; Code:=-1;
  case Command of
    '%','&','#','$':Visible:=Command;
    '{','textbraceleft':begin Visible:='{'; Code:=102; SymbolEncoding:='OMS'; end;
    '}','textbraceright':begin Visible:='}'; Code:=103; SymbolEncoding:='OMS'; end;
    'textbackslash':begin Visible:='\'; Code:=110; SymbolEncoding:='OMS'; end;
    'textbar':begin Visible:='|'; Code:=106; SymbolEncoding:='OMS'; end;
    'textless':begin Visible:='<'; Code:=60; SymbolEncoding:='OML'; end;
    'textgreater':begin Visible:='>'; Code:=62; SymbolEncoding:='OML'; end;
    '_','textunderscore':begin Visible:='_'; Code:=95; end;
    'textasciicircum':begin Visible:='^'; Code:=94; end;
    'textasciitilde':begin Visible:='~'; Code:=126; end;
    else Exit;
  end;
  Result:=Leaf(Visible,Node.ID,Size,0);
  if Code<0 then begin
    Result.CharCount:=UTF8Length(Node.Text); SetLength(Result.Stops,Result.CharCount+1);
    for I:=1 to Result.CharCount do Result.Stops[I]:=Result.W;
    Exit;
  end;
  Result.TextRun.Valid:=False;
  Family:=FTextRoman; if FDefaultFont='Latin Modern Sans' then Family:=FTextSans
  else if FDefaultFont='Latin Modern Mono' then Family:=FTextMono;
  Series:='m'; if fsBold in FDefaultStyle then Series:='bx';
  Points:=Max(5,Round(Size*MathFontPoints(0)/Max(1,FMathBaseSize)));
  Font:=Result.TextFont;
  if (SymbolEncoding<>'') and (FTextEncoding='OT1') then Font:=TextFontShape(Family,Series,'n',Points,SymbolEncoding)
  else Code:=Ord(Visible[1]);
  Result.Glyph:=ChooseTeXGlyph('text-'+Font+'-'+IntToStr(Code));
  if FOpenTypeText and (Result.TextOutlineFont<>'') then
    Result.Glyph:=ChooseTeXGlyph('unicode-'+Result.TextOutlineFont+'-'+IntToStr(Ord(Visible[1])));
  if (Visible='_') and (FTextEncoding='OT1') and not FOpenTypeText then begin
    Result.Shape:=14; Result.Glyph:=-1; Result.W:=Max(4,Round(Result.TextEm*0.36));
  end
  else
  if Result.Glyph>=0 then begin
    Em:=Result.TextEm; Result.Shape:=11;
    Result.W:=Round(TeXGlyphMetrics[Result.Glyph].Advance*Em);
    Result.InkAbove:=Ceil(TeXGlyphMetrics[Result.Glyph].Above*Em);
    Result.InkBelow:=Ceil((TeXGlyphMetrics[Result.Glyph].H-TeXGlyphMetrics[Result.Glyph].Above)*Em);
    Result.HasInkMetric:=True; Result.Baseline:=Max(Result.Baseline,Result.InkAbove);
    Result.H:=Max(Result.H,Result.Baseline+Result.InkBelow);
  end;
  Result.CharCount:=UTF8Length(Node.Text); SetLength(Result.Stops,Result.CharCount+1);
  for I:=1 to Result.CharCount do Result.Stops[I]:=Result.W;
end;
function TParagraphDraft.TextAccentBox(Node:TMathNode; Size:Integer):TDraftBox;
var Base,Accent:TDraftBox; Font:TTeXFontMetric; Code,P,Top,Shift:Integer;
    Command,Encoding,FontName:string; Em,XHeight,Slant:Double;
begin
  Result:=nil; P:=1; Command:=ReadTeXCommand(Node.Text,P);
  Encoding:=FTextEncoding; if Encoding='TU' then Encoding:='OT1';
  Code:=TeXTextAccent(Command,Encoding);
  if (Code<0) or (Node.Children.Count=0) then Exit;
  Base:=TextBox(TMathNode(Node.Children[0]),Size); Em:=Base.TextEm;
  if Em<=0 then Em:=MeasureEm(FMathBaseSize)*FTextStyle.Points/MathFontPoints(0);
  FontName:=TextFontShape(FTextStyle.Family,FTextStyle.Series,FTextStyle.Shape,FTextStyle.Points,Encoding);
  Font:=TeXFontMetric(FontName);
  Accent:=TDraftBox.Create; Accent.Shape:=11; Accent.Size:=Size; Accent.TextEm:=Em; Accent.Color:=FDefaultColor;
  Accent.Glyph:=ChooseTeXGlyph('text-'+FontName+'-'+IntToStr(Code));
  if Accent.Glyph<0 then begin Accent.Free; Base.Free; Exit; end;
  Accent.W:=Round(Font.Chars[Code].Width*Em);
  Accent.Baseline:=Ceil(TeXGlyphMetrics[Accent.Glyph].Above*Em);
  Accent.H:=Ceil(TeXGlyphMetrics[Accent.Glyph].H*Em);
  XHeight:=0.430556; Slant:=0;
  if Length(Font.Parameters)>4 then XHeight:=Font.Parameters[4];
  if Length(Font.Parameters)>0 then Slant:=Font.Parameters[0];
  { tex.web make_accent: delta=(w-a)/2+h*t-x*s, shift=x-h. }
  Shift:=Base.InkAbove-Round(XHeight*Em);
  if Command='c' then Shift:=-Round(0.2*Em)-Base.InkBelow;
  if (Command='d') or (Command='b') then Shift:=-Base.InkBelow-Round(0.65*Em);
  Accent.X:=Round((Base.W-Accent.W)/2+(Base.InkAbove-XHeight*Em)*Slant);
  Accent.Y:=Base.Baseline-Accent.Baseline-Shift;
  Top:=Min(0,Accent.Y); Base.Y:=-Top; Dec(Accent.Y,Top);
  Result:=TDraftBox.Create; Result.ID:=Node.ID; Result.Size:=Size;
  Result.W:=Max(Base.W,Accent.X+Accent.W); Result.Baseline:=Base.Baseline+Base.Y;
  Result.H:=Max(Base.Y+Base.H,Accent.Y+Accent.H);
  Result.HasInkMetric:=True; Result.InkAbove:=Result.Baseline; Result.InkBelow:=Max(Base.InkBelow,Result.H-Result.Baseline);
  Result.Children.Add(Base); Result.Children.Add(Accent);
end;
{$I documentdraft.inc}
{$I listinglayout.inc}
threadvar NativeBoxDepth:Integer;
{$I packageenvironments.inc}
{$I beamerlayout.inc}
function TParagraphDraft.FieldByID(ID:Integer):TMathNode;
begin
  Result:=nil; if FFieldIndex<>nil then Result:=FFieldIndex.Find(ID);
end;
function TParagraphDraft.AnchorFor(ID:Integer):Integer;
var N:TMathNode;
begin
  Result:=-1; if (FLayout=nil) or (Length(FLayout.Anchors)=0) or (ID<0) then Exit;
  N:=FieldByID(ID); if N<>nil then Result:=FLayout.AnchorIndex(MathSourceOffset(N),FSource,False,N.Text='');
end;
procedure TParagraphDraft.StyleBox(Box:TDraftBox; Index:Integer);
var A:TTeXAnchor;
begin
  if (Index<0) or (FLayout=nil) then Exit;
  A:=FLayout.Anchors[Index];
  if (A.SourceLength>0) and (FTextStyleDepth=0) then
  begin
    Box.FontName:=A.FontName; Box.FontStyle:=A.Style+FDefaultStyle; Box.Color:=A.Color;
    Box.PixelHeight:=Max(1,Round(A.FontHeight*FScale));
  end;
  Box.Anchor:=Rect(Round(A.Bounds.Left*FScale),Round(A.Bounds.Top*FScale),
    Round(A.Bounds.Right*FScale),Round(A.Bounds.Bottom*FScale));
  FCanvas.Font.Name:=Box.FontName; FCanvas.Font.Style:=Box.FontStyle;
  if Box.PixelHeight>0 then FCanvas.Font.Height:=-Box.PixelHeight else FCanvas.Font.Size:=Box.Size;
  Box.W:=TeXTextWidth(FCanvas,Box.Text);
  Box.H:=Max(1,Box.Anchor.Bottom-Box.Anchor.Top); Box.Baseline:=Box.H*4 div 5;
  Box.Anchored:=Box.FirstChar=A.FirstChar;
end;
procedure EquationLabels(Node:TMathNode; var Counter:Integer; Labels:TStrings);
var Env,TagText:string; P,I:Integer; Body,N:TMathNode;
    Numbered,Suppressed,HasTag,TagStar,HasContent,Single:Boolean;
  procedure FinishRow;
  begin
    if HasTag then
    begin
      if TagStar then Labels.Add(TagText) else Labels.Add('('+TagText+')');
    end
    else if Numbered and not Suppressed then
    begin Inc(Counter); Labels.Add('('+IntToStr(Counter)+')'); end
    else Labels.Add('');
    Suppressed:=False; HasTag:=False; TagStar:=False; TagText:=''; HasContent:=False;
  end;
begin
  Labels.Clear;
  if Node.Kind<>mkFormula then Exit;
  if (Node.Prefix='\[') or (Node.Prefix='$$') then Env:='equation*'
  else begin
    if Pos('\begin{',Node.Prefix)<>1 then Exit;
    P:=Length('\begin')+1; Env:=ReadTeXGroup(Node.Prefix,P,'{','}');
  end;
  Numbered:=Pos('*',Env)=0;
  Env:=StringReplace(Env,'*','',[]);
  if (Env<>'align') and (Env<>'alignat') and (Env<>'gather') and
     (Env<>'equation') and (Env<>'eqnarray') then Exit;
  Single:=Env='equation';
  Suppressed:=False; HasTag:=False; TagStar:=False; TagText:=''; HasContent:=False;
  if Node.Children.Count=0 then Exit;
  Body:=Node.SourcePreview;
  if Body=nil then Body:=TMathNode(Node.Children[0]);
  for I:=0 to Body.Children.Count-1 do
  begin
    N:=TMathNode(Body.Children[I]);
    if not Single and (N.Kind=mkRaw) and (Copy(N.Text,1,2)='\\') then
    begin FinishRow; Continue; end;
    if (N.Text='\notag') or (N.Text='\nonumber') then Suppressed:=True;
    if (N.Text='\tag') or (N.Text='\tag*') then
    begin
      HasTag:=True; TagStar:=N.Text='\tag*';
      if N.Children.Count>0 then
      begin
        N:=TMathNode(N.Children[0]);
        TagText:=Copy(N.TeX,Length(N.Prefix)+1,MathSourceLength(N)-Length(N.Prefix)-Length(N.Suffix));
      end;
    end;
    if Trim(N.TeX)<>'' then HasContent:=True;
  end;
  if HasContent or (Labels.Count=0) then FinishRow;
end;
function TParagraphDraft.FormulaBox(Node:TMathNode; Size:Integer):TDraftBox;
var I,Index,Start,Stop,MaxSize,Base,Distance,Closest,Container,TrimTop,TrimBottom,OldBase,OldLevel,FieldBaseline:Integer; N,Body:TMathNode;
    R:TRect; Have,OldDisplay,HaveTags:Boolean; A:TTeXAnchor; Labels:TStringList; B,CodeBox:TDraftBox; TagWidth,BodyWidth,Shift,RowBase,J:Integer; OldFont:string; OldStyle:TFontStyles; OldHeight:Integer; Mark:TContextMark;
    OuterMacros,LocalMacros:TMacroRegistry;
  function BoxBaseline(Box:TDraftBox; ID,Y:Integer; out Position:Integer):Boolean;
  var K:Integer;
  begin
    Inc(Y,Box.Y); Result:=(Box.ID=ID) and (Box.W>0);
    if Result then begin Position:=Y+Box.Baseline; Exit; end;
    for K:=0 to Box.Children.Count-1 do
      if BoxBaseline(TDraftBox(Box.Children[K]),ID,Y,Position) then Exit(True);
  end;
  function AnnotationBox(RowIndex:Integer; const Caption:string):TDraftBox;
  var K,RowNo,Split:Integer; Field,Arg,TagField:TMathNode; Piece:TDraftBox; NumberText:string;
    procedure AddPart(const Text:string; ID,Count:Integer);
    begin
      Piece:=Leaf(Text,ID,Size,0); Piece.CharCount:=Count;
      Piece.X:=Result.W; Inc(Result.W,Piece.W);
      Result.H:=Max(Result.H,Piece.H); Result.Baseline:=Max(Result.Baseline,Piece.Baseline);
      Result.Children.Add(Piece);
    end;
  begin
    Result:=TDraftBox.Create; RowNo:=0; TagField:=nil;
    for K:=0 to Body.Children.Count-1 do begin
      Field:=TMathNode(Body.Children[K]);
      if (Field.Kind=mkRaw) and (Copy(Field.Text,1,2)='\\') then Inc(RowNo);
      if (RowNo=RowIndex) and ((Field.Text='\tag') or (Field.Text='\tag*')) then TagField:=Field;
    end;
    NumberText:=Caption; Split:=Pos(' [',NumberText); if Split>0 then NumberText:=Copy(NumberText,1,Split-1);
    if (TagField<>nil) and (TagField.Children.Count>0) then begin
      Arg:=TMathNode(TagField.Children[0]);
      if Arg.Children.Count>0 then begin
        Arg:=TMathNode(Arg.Children[0]);
        if TagField.Text='\tag' then AddPart('(',-1,0);
        AddPart(Arg.Text,Arg.ID,UTF8Length(Arg.Text));
        if TagField.Text='\tag' then AddPart(')',-1,0);
      end;
    end else AddPart(NumberText,-1,0);
    RowNo:=0;
    if not HideEditingMarks then for K:=0 to Body.Children.Count-1 do begin
      Field:=TMathNode(Body.Children[K]);
      if (Field.Kind=mkRaw) and (Copy(Field.Text,1,2)='\\') then Inc(RowNo);
      if (RowNo=RowIndex) and (Field.Text='\label') and (Field.Children.Count>0) then begin
        Arg:=TMathNode(Field.Children[0]);
        if Arg.Children.Count>0 then begin
          Arg:=TMathNode(Arg.Children[0]); AddPart(' [',-1,0);
          AddPart(Arg.Text,Arg.ID,UTF8Length(Arg.Text)); AddPart(']',-1,0);
        end;
      end;
    end;
    for K:=0 to Result.Children.Count-1 do begin Piece:=TDraftBox(Result.Children[K]); Piece.Y:=Result.Baseline-Piece.Baseline; end;
  end;

begin
  Start:=MathSourceOffset(Node)-Length(Node.Prefix); Stop:=Start+MathSourceLength(Node);
  Body:=Node.SourcePreview; if Body=nil then Body:=TMathNode(Node.Children[0]);
  CodeBox:=nil;
  Have:=False; MaxSize:=0; Base:=0;
  if (FLayout<>nil) and (Length(FLayout.Anchors)>0) then for I:=0 to FNodes.Count-1 do
  begin
    N:=TMathNode(FNodes[I]);
    if (MathSourceOffset(N)<Start+Length(Node.Prefix)) or (MathSourceOffset(N)>Stop-Length(Node.Suffix)) then Continue;
    Index:=AnchorFor(N.ID); if Index<0 then Continue;
    A:=FLayout.Anchors[Index];
    if not Have then begin R:=A.Bounds; Have:=True; end
    else R:=Rect(Min(R.Left,A.Bounds.Left),Min(R.Top,A.Bounds.Top),Max(R.Right,A.Bounds.Right),Max(R.Bottom,A.Bounds.Bottom));
    if A.FontHeight>MaxSize then begin MaxSize:=A.FontHeight; Base:=A.Bounds.Top+A.Baseline; end;
  end;
  Container:=-1;
  if FLayout<>nil then Container:=FLayout.AnchorIndex(Start,FSource,True);
  if Container>=0 then begin R:=FLayout.Anchors[Container].Bounds; Have:=True; end;
  if Have and IsInlineFormula(Node) then
  begin
    Closest:=MaxInt;
    for I:=0 to FNodes.Count-1 do
    begin
      N:=TMathNode(FNodes[I]); if (N.Kind<>mkProse) or (Trim(N.Text)='') then Continue;
      Index:=AnchorFor(N.ID); if Index<0 then Continue;
      A:=FLayout.Anchors[Index];
      if (A.Bounds.Bottom<R.Top-3) or (A.Bounds.Top>R.Bottom+3) then Continue;
      Distance:=Min(Abs(MathSourceOffset(N)-Stop),Abs(MathSourceOffset(N)+Length(N.Text)-Start));
      if Distance<Closest then
      begin Closest:=Distance; Base:=A.Bounds.Top+A.Baseline; end;
    end;
  end;
  OldDisplay:=FDisplayMath; OldBase:=FMathBaseSize; OldLevel:=FMathLevel;
  FMathBaseSize:=Size; FMathLevel:=0;
  FDisplayMath:=not IsInlineFormula(Node);
  OuterMacros:=Macros; LocalMacros:=nil;
  if HasMacroDefinitions(Node) and (Macros<>nil) then begin
    LocalMacros:=Macros.Clone; Macros:=LocalMacros; FMacroScopes.Add(Macros);
  end;
  try
    if Node.SourcePreview<>nil then begin
      if (Pos('gather',Node.Prefix)>0) or (Pos('align',Node.Prefix)>0) then
        Result:=GridBox(Body,Size,Pos('gather',Node.Prefix)>0,False,Round(MeasureEm(Size)*0.3))
      else Result:=MathBox(Body,Size);
      CodeBox:=MathBox(TMathNode(Node.Children[0]),Size);
    end else if TMathNode(Node.Children[0]).Kind=mkUnknownCommand then Result:=MathBox(TMathNode(Node.Children[0]),Size)
    else if (Pos('gather',Node.Prefix)>0) or (Pos('matrix',Node.Prefix)>0) then
      Result:=GridBox(TMathNode(Node.Children[0]),Size,True,False,Round(MeasureEm(Size)*0.3))
    else Result:=MathBox(TMathNode(Node.Children[0]),Size);
  finally
    if LocalMacros<>nil then begin FMacroScopes.Delete(FMacroScopes.Count-1); Macros:=OuterMacros; LocalMacros.Free; end;
  end;
  if not FDisplayMath and (Result.Shape=0) then begin
    { Native fonts include line leading above the ink. TeX inline boxes do
      not: retaining it pushes the entire text line down around accents. }
    TrimTop:=InkTop(Result); TrimBottom:=InkBottom(Result);
    if TrimBottom>TrimTop then begin
      for I:=0 to Result.Children.Count-1 do Dec(TDraftBox(Result.Children[I]).Y,TrimTop);
      Dec(Result.Baseline,TrimTop); Result.H:=TrimBottom-TrimTop;
    end;
  end;
  Result.InlineFlow:=not FDisplayMath;
  FDisplayMath:=OldDisplay; FMathBaseSize:=OldBase; FMathLevel:=OldLevel; Result.ID:=Node.ID;
  Labels:=TStringList.Create;
  try
    EquationLabels(Node,FEquationCounter,Labels);
    if Context<>nil then
      for I:=0 to Labels.Count-1 do
      begin
        Mark:=Context.Mark(ContextOffset+MathSourceOffset(Node)-Length(Node.Prefix),I);
        if Mark<>nil then
        begin
          if Mark.Number<>'' then begin if Mark.BareTag then Labels[I]:=Mark.Number else Labels[I]:='('+Mark.Number+')'; end else Labels[I]:='';
          if Mark.Labels<>'' then Labels[I]:=Labels[I]+' ['+Mark.Labels+']';
        end;
      end;
    if HideEditingMarks then for I:=0 to Labels.Count-1 do begin
      J:=Pos(' [',Labels[I]); if J>0 then Labels[I]:=Copy(Labels[I],1,J-1);
    end;
    HaveTags:=False;
    for I:=0 to Labels.Count-1 do if Labels[I]<>'' then HaveTags:=True;
    if HaveTags then
    begin
      OldFont:=FDefaultFont; OldStyle:=FDefaultStyle; OldHeight:=FDefaultHeight;
      FDefaultFont:='Latin Modern Roman'; FDefaultStyle:=[]; FDefaultHeight:=0;
      TagWidth:=0;
      for I:=0 to Labels.Count-1 do
      begin B:=AnnotationBox(I,Labels[I]); TagWidth:=Max(TagWidth,B.W); B.Free; end;
      BodyWidth:=Result.W; Result.W:=Max(FMathWidth,BodyWidth+2*(TagWidth+12));
      Shift:=(Result.W-BodyWidth) div 2;
      for I:=0 to Result.Children.Count-1 do Inc(TDraftBox(Result.Children[I]).X,Shift);
      for I:=0 to Labels.Count-1 do
      begin
        if Labels[I]='' then Continue;
        RowBase:=Result.Baseline;
        if (Pos('align',Node.Prefix)>0) or (Pos('gather',Node.Prefix)>0) or (Pos('eqnarray',Node.Prefix)>0) then
          for J:=0 to Result.Children.Count-1 do
          begin B:=TDraftBox(Result.Children[J]); if B.Row=I then begin RowBase:=B.Y+B.Baseline; Break; end; end;
        B:=AnnotationBox(I,Labels[I]);
        B.X:=Result.W-B.W; B.Y:=RowBase-B.Baseline;
        Result.Children.Add(B); Result.H:=Max(Result.H,B.Y+B.H);
      end;
      FDefaultFont:=OldFont; FDefaultStyle:=OldStyle; FDefaultHeight:=OldHeight;
    end;
  finally Labels.Free; end;
  if CodeBox<>nil then begin
    { Equation tags belong to the preview, not to the wider source editor. }
    Result:=SourcePreviewBox(Node,Result,CodeBox,IsInlineFormula(Node));
  end;
  if Have then
  begin
    Result.Anchored:=True;
    if IsInlineFormula(Node) then
      Result.Anchor:=Rect(Round(R.Left*FScale),Round(Base*FScale)-Result.Baseline,0,0)
    else Result.Anchor:=Rect(Round(R.Left*FScale),Round(R.Top*FScale),0,0);
    if not Result.InlineFlow then
      for I:=0 to FNodes.Count-1 do begin
        N:=TMathNode(FNodes[I]);
        if (Trim(N.Text)='') or (MathSourceOffset(N)<Start+Length(Node.Prefix)) or
           (MathSourceOffset(N)>=Stop-Length(Node.Suffix)) then Continue;
        Index:=AnchorFor(N.ID); if Index<0 then Continue;
        if not BoxBaseline(Result,N.ID,0,FieldBaseline) then Continue;
        A:=FLayout.Anchors[Index];
        Result.Anchor.Top:=Round((A.Bounds.Top+A.Baseline)*FScale)-FieldBaseline;
        Break;
      end;
  end;
end;
function TParagraphDraft.GridBox(Node:TMathNode; Size:Integer; Centered:Boolean; LeftAligned:Boolean; RowGap:Integer; const ColumnAlign:string; Small:Boolean):TDraftBox;
var Cell,B:TDraftBox; I,J,Row,Col,X,Y,Above,Below,First,StrutAbove,StrutBelow,Gap:Integer; N:TMathNode; Em,LineHeight,Ex:Double;
    Widths,Heights,Bases:array of Integer;
  procedure FinishCell;
  var K:Integer; C:TDraftBox;
  begin
    Above:=0; Below:=0;
    for K:=0 to Cell.Children.Count-1 do
    begin C:=TDraftBox(Cell.Children[K]); Above:=Max(Above,-C.Y); Below:=Max(Below,C.Y+C.H); end;
    Above:=Max(Above,StrutAbove); Below:=Max(Below,StrutBelow);
    Cell.Baseline:=Above; Cell.H:=Max(1,Above+Below);
    for K:=0 to Cell.Children.Count-1 do begin C:=TDraftBox(Cell.Children[K]); Inc(C.Y,Above); end;
    Cell.Row:=Row; Cell.Col:=Col; Result.Children.Add(Cell);
    if Length(Widths)<=Col then SetLength(Widths,Col+1);
    if Length(Heights)<=Row then begin SetLength(Heights,Row+1); SetLength(Bases,Row+1); end;
    Widths[Col]:=Max(Widths[Col],Cell.W); Bases[Row]:=Max(Bases[Row],Above);
    Heights[Row]:=Max(Heights[Row],Below);
    Cell:=TDraftBox.Create;
  end;
begin
  Result:=TDraftBox.Create; Cell:=TDraftBox.Create; Row:=0; Col:=0; First:=0;
  Widths:=nil; Heights:=nil; Bases:=nil;
  Em:=MeasureEm(Size);
  LineHeight:=1.2;
  if DocumentFontSize=11 then LineHeight:=13.6/11
  else if DocumentFontSize=12 then LineHeight:=14.5/12;
  if LeftAligned then LineHeight:=LineHeight*1.2;
  StrutAbove:=Round(Em*LineHeight*0.7); StrutBelow:=Round(Em*LineHeight*0.3);
  Ex:=MeasureEm(FMathBaseSize)/MathFontPoints(0);
  if Small then begin StrutAbove:=0; StrutBelow:=0; end;
  for I:=0 to Node.Children.Count-1 do
  begin
    N:=TMathNode(Node.Children[I]);
    if (N.Kind=mkRaw) and ((N.Text='&') or (Copy(N.Text,1,2)='\\')) then
    begin
      Cell.Free; Cell:=SequenceBox(Node,First,I-1,Size);
      for J:=0 to Cell.Children.Count-1 do Dec(TDraftBox(Cell.Children[J]).Y,Cell.Baseline);
      FinishCell; First:=I+1;
      if N.Text='&' then Inc(Col) else begin Inc(Row); Col:=0; end;
      Continue;
    end;
  end;
  Cell.Free; Cell:=SequenceBox(Node,First,Node.Children.Count-1,Size);
  for J:=0 to Cell.Children.Count-1 do Dec(TDraftBox(Cell.Children[J]).Y,Cell.Baseline);
  FinishCell; Cell.Free;
  for I:=0 to Result.Children.Count-1 do
  begin
    B:=TDraftBox(Result.Children[I]); X:=0; Y:=0;
    for J:=0 to B.Col-1 do
      if Centered then Inc(X,Widths[J]+FMatrixGap)
      else if LeftAligned then Inc(X,Widths[J]+Round(Em))
      else Inc(X,Widths[J]+IfThen(Odd(J),24,4));
    for J:=0 to B.Row-1 do
      if Small then begin
        Gap:=Round(6*Ex)-Heights[J]-Bases[J+1];
        if Gap<Round(1.5*Ex) then Gap:=Round(1.5*Ex);
        Inc(Y,Bases[J]+Heights[J]+Gap);
      end
      else if Centered or LeftAligned then Inc(Y,Bases[J]+Heights[J]+RowGap)
      else Inc(Y,Bases[J]+Heights[J]+Round(Em*0.3));
    if Centered then begin
      if Copy(ColumnAlign,B.Col+1,1)='r' then Inc(X,Widths[B.Col]-B.W)
      else if Copy(ColumnAlign,B.Col+1,1)<>'l' then Inc(X,(Widths[B.Col]-B.W) div 2);
    end
    else if not LeftAligned and not Odd(B.Col) then Inc(X,Widths[B.Col]-B.W);
    B.X:=X; B.Y:=Y+Bases[B.Row]-B.Baseline;
    Result.W:=Max(Result.W,B.X+B.W); Result.H:=Max(Result.H,B.Y+B.H);
  end;
  if Small then Em:=MeasureEm(FMathBaseSize);
  Result.Baseline:=Result.H div 2+Round(Em*0.25);
end;
function TParagraphDraft.InkTop(Box:TDraftBox):Integer;
var I,Top:Integer; Child:TDraftBox;
begin
  Result:=0;
  if Box.HasInkMetric then Exit(Max(0,Box.Baseline-Box.InkAbove));
  if Box.Shape=5 then begin
    if Box.Children.Count>0 then Exit(Max(0,TDraftBox(Box.Children[0]).Y+InkTop(TDraftBox(Box.Children[0]))-2));
    Exit;
  end;
  if Box.Shape<>0 then Exit;
  if Box.Children.Count=0 then
  begin
    if Box.Text='' then Exit;
    { Font ascenders include room above ordinary glyphs. Do not count that
      leading as the visible clearance below a fraction rule. }
    if (Length(Box.Text)=1) and (Box.Text[1] in ['a','c','e','m','n','o','r','s','u','v','w','x','z']) then
      Exit(Max(0,Box.Baseline-Round(MeasureEm(Box.Size)*0.48)));
    Exit(Max(0,Box.Baseline-Round(MeasureEm(Box.Size)*0.72)));
  end;
  Result:=Box.H;
  for I:=0 to Box.Children.Count-1 do
  begin
    Child:=TDraftBox(Box.Children[I]);
    if (Child.Children.Count=0) and (Child.Text='') and (Child.Shape=0) and not Child.HasInkMetric then Continue;
    Top:=Child.Y+InkTop(Child); Result:=Min(Result,Top);
  end;
  if Result=Box.H then Result:=0;
end;
function TParagraphDraft.InkBottom(Box:TDraftBox):Integer;
var I:Integer; B:TDraftBox;
begin
  if Box.HasInkMetric then Exit(Box.Baseline+Box.InkBelow);
  Result:=Box.H; if Box.Children.Count=0 then Exit;
  if Box.Shape<>0 then Exit;
  Result:=0;
  for I:=0 to Box.Children.Count-1 do begin
    B:=TDraftBox(Box.Children[I]); if (B.Text='') and (B.Children.Count=0) and (B.Shape=0) and not B.HasInkMetric then Continue;
    Result:=Max(Result,B.Y+InkBottom(B));
  end;
end;
function TParagraphDraft.DelimiterKind(const Token:string):string;
var Info:TMacroInfo; Name:string;
begin
  Result:='';
  Name:=Trim(Token);
  if (Macros<>nil) and (Copy(Name,1,1)='\') then begin
    Info:=Macros.Find(Copy(Name,2,MaxInt));
    if (Info<>nil) and (Info.GlyphFont<>'') and (Info.DelimiterFont<>'') then
      Exit('font-delimiter-'+Info.GlyphFont+':'+IntToStr(Info.GlyphCode)+':'+
        Info.DelimiterFont+':'+IntToStr(Info.DelimiterCode));
  end;
  case Trim(Token) of
    '(' : Result:='paren-open'; ')' : Result:='paren-close';
    '[','\lbrack':Result:='square-open'; ']','\rbrack':Result:='square-close';
    '\{','\lbrace':Result:='brace-open'; '\}','\rbrace':Result:='brace-close';
    '\langle','<':Result:='angle-open'; '\rangle','>':Result:='angle-close';
    '\lfloor':Result:='floor-open'; '\rfloor':Result:='floor-close';
    '\lceil':Result:='ceil-open'; '\rceil':Result:='ceil-close';
    '|','\vert','\lvert','\rvert':Result:='vert';
    '\|','\Vert','\lVert','\rVert':Result:='Vert';
    else if (Trim(Token)<>'') and (Trim(Token)<>'.') then Result:='delimiter-'+Trim(Token);
  end;
end;
function TParagraphDraft.DelimitedBox(Body:TDraftBox; const Left,Right:string; Size,ID:Integer; Stretch:Boolean):TDraftBox;
var Em,Needed:Double; Top,Bottom,GlyphHeight,Shift:Integer;
  function SideWidth(Index:Integer; const Token:string):Integer;
  begin
    if Trim(Token)='.' then Exit(Max(1,Round(Em*0.12)));
    if Index<0 then Exit(Max(4,Round(Em*0.35)));
    if Stretch then Result:=Max(2,Round(TeXDelimiterAdvance(Index)*Em))
    else Result:=Max(2,Round(TeXGlyphMetrics[Index].Advance*Em));
  end;
begin
  Em:=MeasureEm(Size);
  Needed:=2*Max(Body.Baseline-InkTop(Body)-Em*0.25,
               InkBottom(Body)-Body.Baseline+Em*0.25)*0.901/Max(1,Em);
  Result:=TDraftBox.Create; Result.Color:=FDefaultColor; Result.Shape:=5; Result.Text:=Left+#1+Right; Result.ID:=ID; Result.Size:=Size;
  if Stretch then begin
    Result.LeftGlyph:=ChooseTeXGlyph(DelimiterKind(Left),Needed);
    Result.RightGlyph:=ChooseTeXGlyph(DelimiterKind(Right),Needed);
  end else begin
    Result.LeftGlyph:=ChooseTeXGlyph('fixed-'+DelimiterKind(Left));
    Result.RightGlyph:=ChooseTeXGlyph('fixed-'+DelimiterKind(Right));
  end;
  Result.LeftWidth:=SideWidth(Result.LeftGlyph,Left); Result.RightWidth:=SideWidth(Result.RightGlyph,Right);
  GlyphHeight:=0;
  if Result.LeftGlyph>=0 then GlyphHeight:=Round(TeXGlyphMetrics[Result.LeftGlyph].H*Em);
  if Result.RightGlyph>=0 then GlyphHeight:=Max(GlyphHeight,Round(TeXGlyphMetrics[Result.RightGlyph].H*Em));
  Top:=Min(0,Body.Baseline-Round(Em*0.25)-GlyphHeight div 2);
  Bottom:=Max(Body.H,Body.Baseline-Round(Em*0.25)+(GlyphHeight+1) div 2); Shift:=-Top;
  Body.X:=Result.LeftWidth; Body.Y:=Shift; Result.Children.Add(Body);
  Result.W:=Body.W+Result.LeftWidth+Result.RightWidth; Result.H:=Bottom+Shift;
  Result.Baseline:=Body.Baseline+Shift;
  Result.HasInkMetric:=True;
  Result.InkAbove:=Max(Body.Baseline-InkTop(Body),Round(Em*0.25)+GlyphHeight div 2);
  Result.InkBelow:=Max(InkBottom(Body)-Body.Baseline,(GlyphHeight+1) div 2-Round(Em*0.25));
end;
function TParagraphDraft.MathFontPoints(Level:Integer):Integer;
begin
  Result:=DocumentFontSize; if Result<=0 then Result:=10;
  if Level=1 then begin if Result>=11 then Result:=8 else Result:=7; end
  else if Level>=2 then begin if Result>=11 then Result:=6 else Result:=5; end;
end;
function TParagraphDraft.MathFontSize(Level:Integer):Integer;
begin Result:=Max(1,Round(FMathBaseSize*MathFontPoints(Level)/MathFontPoints(0))); end;
function TParagraphDraft.MathFontGlyph(const Token:string):Integer;
var Family,Series,Shape,Font,SymbolFamily:string; Code:Integer; Sans,Letter,Symbol:Boolean;
begin
  Result:=-1;
  Sans:=(FBeamerTheme<>nil) and FBeamerTheme.Settings.Enabled and not FBeamerTheme.Settings.SerifMath;
  Letter:=(Length(Token)=1) and (Token[1] in ['a'..'z','A'..'Z','0'..'9']);
  Symbol:=TeXSymbol(Token,SymbolFamily,Code);
  if Letter then Code:=Ord(Token[1]);
  Family:=''; Series:='m'; Shape:='n';
  case FMathStyle of
    '':if Sans and (Letter or (Symbol and (SymbolFamily='cmr'))) then begin
      Family:=FTextStyle.Sans;
      if Letter and not (Token[1] in ['0'..'9']) then Shape:='it';
    end;
    '\mathrm':Family:=FTextStyle.Roman;
    '\mathsf':Family:=FTextStyle.Sans;
    '\mathtt':Family:=FTextStyle.Mono;
    '\mathbf','\mathit':begin
      Family:=FTextStyle.Roman; if Sans then Family:=FTextStyle.Sans;
      if FMathStyle='\mathbf' then Series:='bx' else Shape:='it';
    end;
    '\mathbb','\mathfrak','\mathscr','\mathcal':
      if Letter then Exit(ChooseTeXGlyph(Copy(FMathStyle,2,MaxInt)+'-'+Token));
    else Exit;
  end;
  { Math alphabets change variable-family letters and digits, not binary
    operators or ordinary Greek symbols. Uppercase Greek uses OT1 slots 0..10. }
  if (FMathStyle<>'') and not (Letter or (Symbol and (SymbolFamily='cmr') and (Code<=10))) then begin
    Family:=''; Series:='m'; Shape:='n';
    if Sans and Symbol and (SymbolFamily='cmr') then Family:=FTextStyle.Sans;
  end;
  if Family<>'' then begin
    Font:=TextFontShape(Family,Series,Shape,MathFontPoints(FMathLevel),'OT1');
    Result:=ChooseTeXGlyph('text-'+Font+'-'+IntToStr(Code)); if Result>=0 then Exit;
  end;
  if Copy(Token,1,1)='\' then Result:=ChooseTeXGlyph('math-symbol-'+IntToStr(MathFontPoints(FMathLevel))+'-'+Copy(Token,2,MaxInt))
  else Result:=ChooseTeXGlyph('math-default-'+IntToStr(MathFontPoints(FMathLevel))+'-'+Token);
end;
function TParagraphDraft.MathTextBox(Node:TMathNode; Size:Integer):TDraftBox;
var P,Bytes,I,Index:Integer; Ch:string; B:TDraftBox;
begin
  Result:=TDraftBox.Create; Result.Color:=FDefaultColor; Result.ID:=Node.ID;
  Result.Size:=Size; Result.CharCount:=UTF8Length(Node.Text);
  SetLength(Result.Stops,Result.CharCount+1); P:=1; I:=0;
  while P<=Length(Node.Text) do begin
    Bytes:=Min(Max(1,UTF8CharacterLength(PChar(Node.Text)+P-1)),Length(Node.Text)-P+1);
    Ch:=Copy(Node.Text,P,Bytes); Inc(P,Bytes); Inc(I);
    Result.Stops[I]:=Result.W;
    if (Ch=' ') or (Ch=#9) or (Ch=#10) or (Ch=#13) then Continue;
    Index:=MathFontGlyph(Ch);
    if Index<0 then begin FreeAndNil(Result); Exit; end;
    B:=MathGlyphBox(Index,-1,Size,0); B.Text:=Ch; Result.Text:=Result.Text+Ch;
    B.X:=Result.W; Inc(Result.W,B.W); Result.Baseline:=Max(Result.Baseline,B.Baseline);
    Result.Children.Add(B); Result.Stops[I]:=Result.W;
  end;
  for I:=0 to Result.Children.Count-1 do begin
    B:=TDraftBox(Result.Children[I]); B.Y:=Result.Baseline-B.Baseline; Result.H:=Max(Result.H,B.Y+B.H);
  end;
  Result.HasInkMetric:=True; Result.InkAbove:=Result.Baseline; Result.InkBelow:=Result.H-Result.Baseline;
end;
function TParagraphDraft.MeasureEm(Size:Integer):Double;
begin Result:=Size*FEmFactor; end;
function TParagraphDraft.LimitSpacing(Size,Index:Integer; Default:Double):Integer;
var Font:TTeXFontMetric;
begin
  Font:=TeXFontMetric('cmex10');
  if (Font<>nil) and (Length(Font.Parameters)>Index) then Default:=Font.Parameters[Index];
  Result:=Max(1,Round(Default*MeasureEm(Size)));
end;
function TParagraphDraft.ScriptBox(Node:TMathNode; Size:Integer):TDraftBox;
var OldDisplay:Boolean; OldLevel:Integer;
begin
  OldDisplay:=FDisplayMath; OldLevel:=FMathLevel; FDisplayMath:=False; FMathLevel:=Min(2,FMathLevel+1);
  try Result:=MathBox(Node,MathFontSize(FMathLevel));
  finally FDisplayMath:=OldDisplay; FMathLevel:=OldLevel; end;
end;
function TParagraphDraft.BraceBox(Node:TMathNode; Size:Integer):TDraftBox;
const Parts:array[0..1,0..3] of string=(('braceld','braceru','bracelu','bracerd'),
  ('bracelu','bracerd','braceld','braceru'));
var Body,Part:TDraftBox; OldDisplay:Boolean; OldLevel,I,Side,Gap,BraceHeight,Top,Base,Middle,GlyphIndex:Integer;
    Em:Double; Font:TTeXFontMetric;
begin
  OldDisplay:=FDisplayMath; OldLevel:=FMathLevel; FDisplayMath:=True; FMathLevel:=0;
  if OldLevel>0 then Size:=MathFontSize(0);
  try Body:=MathBox(TMathNode(Node.Children[0]),Size);
  finally FDisplayMath:=OldDisplay; FMathLevel:=OldLevel; end;
  { fontmath.ltx: a display-style nucleus, four CMEX brace parts, and a
    3pt kern on either side of the brace row. The operator always uses limits. }
  Em:=MeasureEm(Size); Font:=TeXFontMetric('cmex10');
  BraceHeight:=Max(1,Round(Font.Chars[$7A].Height*Em));
  Gap:=Max(1,Round(3*MeasureEm(FMathBaseSize)/MathFontPoints(0)));
  Result:=TDraftBox.Create; Result.Shape:=9; Result.Text:=Node.Text; Result.ID:=Node.ID;
  Result.Size:=Size; Result.Color:=FDefaultColor; Result.Children.Add(Body);
  Result.W:=Max(Body.W,Round(4*Font.Chars[$7A].Width*Em)); Middle:=Result.W div 2;
  Body.X:=(Result.W-Body.W) div 2; Side:=Ord(Node.Text='\underbrace');
  if Side=1 then begin Top:=Body.H+Gap; Body.Y:=0; Result.H:=Top+BraceHeight+Gap; end
  else begin Top:=Gap; Body.Y:=2*Gap+BraceHeight; Result.H:=Body.Y+Body.H; end;
  Base:=Top+BraceHeight; Result.Baseline:=Body.Y+Body.Baseline;
  Result.HasInkMetric:=True; Result.InkAbove:=Result.Baseline; Result.InkBelow:=Result.H-Result.Baseline;
  for I:=0 to 3 do begin
    GlyphIndex:=ChooseTeXGlyph('math-symbol-10-'+Parts[Side,I]);
    if GlyphIndex<0 then Continue;
    Part:=MathGlyphBox(GlyphIndex,-1,Size,0); Part.Y:=Base-Part.Baseline;
    case I of 0:Part.X:=0; 1:Part.X:=Middle-Part.W; 2:Part.X:=Middle; 3:Part.X:=Result.W-Part.W; end;
    Result.Children.Add(Part);
  end;
  Gap:=Round(Font.Chars[$7A].Width*Em);
  if Middle>2*Gap then begin
    SetLength(Result.Lines,2);
    Result.Lines[0].A:=Point(Gap,Base-BraceHeight div 2); Result.Lines[0].B:=Point(Middle-Gap,Base-BraceHeight div 2);
    Result.Lines[1].A:=Point(Middle+Gap,Base-BraceHeight div 2); Result.Lines[1].B:=Point(Result.W-Gap,Base-BraceHeight div 2);
    for I:=0 to 1 do Result.Lines[I].Width:=BraceHeight;
  end;
end;
function TParagraphDraft.MathChoiceArgument(Node:TMathNode; Level:Integer; Display:Boolean):TMathNode;
var Info:TMacroInfo; Name:string; Index:Integer;
begin
  Result:=nil; if (Node.Kind<>mkCommand) or (Node.Children.Count<>4) then Exit;
  Name:=Trim(Node.Text); Info:=nil;
  if Macros<>nil then Info:=Macros.Find(Copy(Name,2,MaxInt));
  if Info<>nil then begin
    if Info.Undefined then Exit;
    if Info.PreviewAdapter='mathchoice' then Name:='\mathchoice'
    else if Info.NativeName<>'' then Name:=Info.NativeName
    else if Info.Expandable and (Info.PackageSource='') then Exit;
  end;
  if Name<>'\mathchoice' then Exit;
  if Level>0 then Index:=Min(Level+1,3)
  else if Display then Index:=0 else Index:=1;
  Result:=TMathNode(Node.Children[Index]);
end;
function TParagraphDraft.SequenceBox(Node:TMathNode; First,Last,Size:Integer):TDraftBox;
const Spacing='0234000122*4000133**3**344*0400400*000000234000111*1111112341011';
var I,J,K,Above,Below,ScriptWidth,BaseX,GroupStart,PreviousClass,CurrentClass,NextClass,Gap,ScriptPoints,UpShift,DownShift:Integer;
    OldLevel,ChoiceLevel:Integer; ChoiceDisplay:Boolean; Items:TFPList;
    Em,ScriptEm,SupDrop,IntegralHeight,IntegralDepth,ItalicCorrection:Double;
    Base,Upper,Lower,B:TDraftBox; N,Next:TMathNode; Limits,Large,Brace,Integral,OldDisplay,HadScript,NativeMod,PreviousMod:Boolean; NativeName,OldMathStyle:string; Macro:TMacroInfo;
  function Item(Index:Integer):TMathNode;
  begin
    if Items=nil then Result:=TMathNode(Node.Children[Index]) else Result:=TMathNode(Items[Index]);
  end;
  procedure AppendChoice(A:TMathNode);
  var Branch:TMathNode; Index:Integer;
  begin
    Branch:=MathChoiceArgument(A,ChoiceLevel,ChoiceDisplay);
    if Branch<>nil then begin
      if (Branch.Kind=mkGroup) and (Branch.Children.Count=1) then Branch:=TMathNode(Branch.Children[0]);
      if Branch.Kind=mkRow then
        for Index:=0 to Branch.Children.Count-1 do AppendChoice(TMathNode(Branch.Children[Index]))
      else AppendChoice(Branch);
      Exit;
    end;
    Items.Add(A);
    if A.Kind=mkRaw then case A.Text of
      '\displaystyle':begin ChoiceLevel:=0; ChoiceDisplay:=True; end;
      '\textstyle':begin ChoiceLevel:=0; ChoiceDisplay:=False; end;
      '\scriptstyle':begin ChoiceLevel:=1; ChoiceDisplay:=False; end;
      '\scriptscriptstyle':begin ChoiceLevel:=2; ChoiceDisplay:=False; end;
    end;
  end;
  function AtomClass(A:TMathNode):Integer;
  var V,Modifier:string; Info:TMacroInfo; P:Integer; BaseNode:TMathNode;
  begin
    Result:=0; V:=Trim(A.Text);
    if (FBeamerProjection<>nil) and (FBeamerProjection.State(A).Visibility=bvAbsent) then Exit(-1);
    if (A.Children.Count=0) and (BeamerNodeRole(A)<>'') then Exit(-1);
    if A.Kind=mkRaw then begin
      P:=1; Modifier:=ReadTeXCommand(V,P);
      case Modifier of
        'displaystyle','textstyle','scriptstyle','scriptscriptstyle',
        'limits','nolimits','displaylimits':Exit(-1);
        'bigl','Bigl','biggl','Biggl':Exit(4);
        'bigr','Bigr','biggr','Biggr':Exit(5);
        'bigm','Bigm','biggm','Biggm':Exit(3);
      end;
    end;
    Info:=nil; if (Macros<>nil) and (A.Kind=mkCommand) then Info:=Macros.Find(Copy(V,2,MaxInt));
    if Info<>nil then begin
      if Info.NativeName<>'' then V:=Info.NativeName;
      case Info.SymbolClass of
        '\mathord':Exit(0); '\mathop':Exit(1); '\mathbin':Exit(2); '\mathrel':Exit(3);
        '\mathopen':Exit(4); '\mathclose':Exit(5); '\mathpunct':Exit(6); '\mathinner':Exit(7);
      end;
    end;
    if (A.Children.Count=2) and ((V='\overset') or (V='\underset') or (V='\stackrel')) then begin
      if V='\stackrel' then Exit(3);
      BaseNode:=TMathNode(A.Children[1]);
      while (BaseNode.Kind in [mkGroup,mkRow]) and (BaseNode.Children.Count=1) do
        BaseNode:=TMathNode(BaseNode.Children[0]);
      Exit(AtomClass(BaseNode));
    end;
    if (Info=nil) or (Info.PackageSource<>'') or (Info.NativeName<>'') or
       ((Info.Body='') and not Info.Expandable and not Info.Undefined) then begin
      if V='\bmod' then Exit(2);
      if (V='\pmod') or (V='\pod') then Exit(4);
    end;
    case TeXSymbolClass(V) of
      '\mathord':Exit(0); '\mathop':Exit(1); '\mathbin':Exit(2); '\mathrel':Exit(3);
      '\mathopen':Exit(4); '\mathclose':Exit(5); '\mathpunct':Exit(6); '\mathinner':Exit(7);
    end;
    if (Pos('arrow',V)>0) or (Pos('harpoon',V)>0) or (V='\xlongequal') or (V='\mapsto') or (V='\iff') or (V='\implies') or (V='\impliedby') then Exit(3);
    case V of
      '\mathord':Exit(0); '\mathop':Exit(1); '\mathbin':Exit(2); '\mathrel':Exit(3);
      '\mathopen':Exit(4); '\mathclose':Exit(5); '\mathpunct':Exit(6); '\mathinner':Exit(7);
    end;
    if (V='\,') or (V='\:') or (V='\;') or (V='\!') or (V='\>') or
       (Pos('\hspace',V)=1) or (Pos('\mspace',V)=1) or (V='\quad') or (V='\qquad') or (V='\thinspace') or (V='\medspace') or
       (V='\thickspace') or (V='\enspace') or (V='\enskip') or (V='\negthinspace') or
       (V='\negmedspace') or (V='\negthickspace') or (V='\space') or (A.Text='\ ') then Exit(-1);
    if (A.Kind=mkText) and (V='') then Exit(-1);
    if (A.Kind=mkGroup) and (A.Prefix<>'') and (A.Prefix[1] in ['^','_']) then Exit(-1);
    if (V='+') or (V='-') or (V=#226#136#146) or (V='*') or (V='\pm') or (V='\mp') or
       (V='\times') or (V='\cdot') or (V='\div') or (V='\cup') or (V='\cap') then Exit(2);
    if (V='=') or (V='<') or (V='>') or (V='\le') or (V='\leq') or (V='\ge') or
       (V='\geq') or (V='\ne') or (V='\neq') or (V='\approx') or (V='\sim') or
       (V='\in') or (V='\notin') or (V='\to') or (V='\rightarrow') then Exit(3);
    if (V='(') or (V='[') or (V='\{') or (Pos('\left',V)=1) then Exit(4);
    if (V=')') or (V=']') or (V='\}') or (Pos('\right',V)=1) then Exit(5);
    if (V=',') or (V=';') or (V='\colon') then Exit(6);
    if IsNamedMathOperator(V) or (V='\operatorname*') then Exit(1);
    if (V='\sum') or (V='\prod') or (V='\int') or (V='\oint') or (V='\lim') or
       (V='\underbrace') or (V='\overbrace') or
       (V='\sin') or (V='\cos') or (V='\tan') or (V='\log') or (V='\ln') or
       (V='\exp') or (V='\operatorname') then Exit(1);
  end;
begin
  Result:=TDraftBox.Create; I:=First; Above:=0; Below:=0; OldDisplay:=FDisplayMath; PreviousClass:=-1; PreviousMod:=False;
  OldMathStyle:=FMathStyle; OldLevel:=FMathLevel; Items:=nil;
  try
  try
    { TeX splices the selected mathchoice list into its surrounding list. }
    for K:=First to Last do if MathChoiceArgument(Item(K),FMathLevel,FDisplayMath)<>nil then begin
      Items:=TFPList.Create; ChoiceLevel:=FMathLevel; ChoiceDisplay:=FDisplayMath;
      for J:=First to Last do AppendChoice(TMathNode(Node.Children[J]));
      First:=0; Last:=Items.Count-1; I:=First; Break;
    end;
  while I<=Last do
  begin
    N:=Item(I);
    case N.Text of
      '\rm':FMathStyle:='\mathrm'; '\sf':FMathStyle:='\mathsf'; '\tt':FMathStyle:='\mathtt';
      '\bf':FMathStyle:='\mathbf'; '\it':FMathStyle:='\mathit';
    end;
    if (N.Text='\rm') or (N.Text='\sf') or (N.Text='\tt') or (N.Text='\bf') or (N.Text='\it') then begin Inc(I); Continue; end;
    if (N.Kind=mkRaw) and ((N.Text='\displaystyle') or (N.Text='\textstyle') or
       (N.Text='\scriptstyle') or (N.Text='\scriptscriptstyle')) then begin
      FDisplayMath:=N.Text='\displaystyle'; FMathLevel:=0;
      if N.Text='\scriptstyle' then FMathLevel:=1
      else if N.Text='\scriptscriptstyle' then FMathLevel:=2;
      Size:=MathFontSize(FMathLevel); Inc(I); Continue;
    end;
    if (N.Kind=mkRaw) and ((N.Text='\limits') or (N.Text='\nolimits') or (N.Text='\displaylimits')) then begin Inc(I); Continue; end;
    Base:=MathBox(N,Size); Base.Y:=-Base.Baseline;
    NativeName:=N.Text; Macro:=nil;
    if (Macros<>nil) and (N.Kind=mkCommand) then Macro:=Macros.Find(Copy(N.Text,2,MaxInt));
    if (Macro<>nil) and (Macro.NativeName<>'') then NativeName:=Macro.NativeName;
    NativeMod:=(N.Kind=mkCommand) and ((NativeName='\bmod') or (NativeName='\mod') or
      (NativeName='\pmod') or (NativeName='\pod')) and
      ((Macro=nil) or (Macro.PackageSource<>'') or (Macro.NativeName<>'') or
       ((Macro.Body='') and not Macro.Expandable and not Macro.Undefined));
    Brace:=(NativeName='\underbrace') or (NativeName='\overbrace');
    Integral:=(NativeName='\int') or (NativeName='\iint') or (NativeName='\iiint') or
      (NativeName='\iiiint') or (NativeName='\oint') or (NativeName='\idotsint');
    Large:=(N.Kind=mkCommand) and (Brace or (TeXLargeOperator(NativeName) and not Integral) or MathOperatorHasLimits(NativeName));
    if (Macro<>nil) and (Macro.SymbolClass='\mathop') and not Integral then Large:=True;
    if (Macro<>nil) and (Pos('\operatorname*{',Macro.Body)=1) then Large:=True;
    Limits:=Brace or (Large and FDisplayMath);
    Upper:=nil; Lower:=nil; J:=I+1;
    while J<=Last do
    begin
      Next:=Item(J);
      if (Next.Kind=mkRaw) and ((Next.Text='\limits') or (Next.Text='\nolimits') or (Next.Text='\displaylimits')) then
      begin Limits:=(Next.Text='\limits') or ((Next.Text='\displaylimits') and FDisplayMath); Inc(J); Continue; end;
      if (Next.Kind=mkText) and (Trim(Next.Text)='') then
      begin
        if Next.Text<>'' then begin Inc(J); Continue; end;
        if (J<Last) and (Item(J+1).Kind=mkGroup) and
          (Item(J+1).Prefix<>'') and
          (Item(J+1).Prefix[1] in ['^','_']) then begin Inc(J); Continue; end;
        Break;
      end;
      if (Next.Kind<>mkGroup) or (Next.Prefix='') or not (Next.Prefix[1] in ['^','_']) then Break;
      if Next.Prefix[1]='^' then
      begin if Upper<>nil then Break; Upper:=ScriptBox(Next,Size); end
      else begin if Lower<>nil then Break; Lower:=ScriptBox(Next,Size); end;
      Inc(J);
    end;
    CurrentClass:=AtomClass(N); NextClass:=-1;
    for K:=J to Last do
    begin NextClass:=AtomClass(Item(K)); if NextClass>=0 then Break; end;
    if (CurrentClass=2) and (((PreviousClass<0) or (PreviousClass in [1,2,3,4,6])) or ((NextClass<0) or (NextClass in [3,5,6]))) then CurrentClass:=0;
    if NativeMod and (NativeName<>'\bmod') and (Result.W>0) then begin
      K:=Length(Result.MathBreaks); SetLength(Result.MathBreaks,K+1);
      Result.MathBreaks[K].Offset:=Result.W; Result.MathBreaks[K].Penalty:=0;
    end;
    Gap:=0;
    if (CurrentClass>=0) and (PreviousClass>=0) then
    begin
      { tex.web mlist_to_hlist keeps unconditional operator thin spaces
        in scripts; its other automatic spaces belong to text/display style. }
      case Spacing[PreviousClass*8+CurrentClass+1] of
        '1':if FMathLevel=0 then Gap:=3;
        '2':Gap:=3;
        '3':if FMathLevel=0 then Gap:=4;
        '4':if FMathLevel=0 then Gap:=5;
      end;
      if (N.Text='\colon') and (FMathLevel=0) then Gap:=3;
      { bmod's nonscript cancellation leaves a 5mu kern in scripts,
        where TeX inserts no automatic binary-operator glue. }
      if (FMathLevel>0) and ((NativeMod and (NativeName='\bmod')) or PreviousMod) then Gap:=0;
      if (FMathLevel=0) and (Gap in [4,5]) and
         not ((NativeMod and (NativeName='\bmod')) or PreviousMod) then begin
        { tex.web keeps these mu glues in the outer math list. They can
          stretch during paragraph packing on either side of an operator;
          glue inside grouped nuclei is packed rigidly with its group. }
        Em:=MeasureEm(Size)/18; K:=Length(Result.MathGlues); SetLength(Result.MathGlues,K+1);
        Result.MathGlues[K].Offset:=Result.W+Round(Gap*Em);
        Result.MathGlues[K].Child:=Result.Children.Count;
        if Gap=5 then Result.MathGlues[K].Stretch:=5*Em
        else begin Result.MathGlues[K].Stretch:=2*Em; Result.MathGlues[K].Shrink:=Min(Round(4*Em),4*Em); end;
      end;
      Inc(Result.W,Round(Gap*MeasureEm(Size)/18));
    end;
    if CurrentClass>=0 then begin PreviousClass:=CurrentClass; PreviousMod:=NativeMod and (NativeName='\bmod'); end;
    if NativeMod and ((NativeName='\pmod') or (NativeName='\pod')) then PreviousClass:=5;
    GroupStart:=Result.W; BaseX:=GroupStart; ScriptWidth:=0;
    if Upper<>nil then ScriptWidth:=Max(ScriptWidth,Upper.W);
    if Lower<>nil then ScriptWidth:=Max(ScriptWidth,Lower.W);
    if Limits then
    begin
      { TeX make_op: use the extension font's big_op_spacing parameters. }
      Inc(Result.W,Max(Base.W,ScriptWidth)); BaseX:=GroupStart+(Result.W-GroupStart-Base.W) div 2;
      if Upper<>nil then
      begin
        Upper.X:=GroupStart+(Result.W-GroupStart-Upper.W) div 2;
        Upper.Y:=Base.Y-Upper.H-Max(LimitSpacing(Size,8,0.111111),LimitSpacing(Size,10,0.2)-Max(0,Upper.H-Upper.Baseline));
      end;
      if Lower<>nil then
      begin
        Lower.X:=GroupStart+(Result.W-GroupStart-Lower.W) div 2;
        Lower.Y:=Base.Y+Base.H+Max(LimitSpacing(Size,9,0.166667),LimitSpacing(Size,11,0.6)-Lower.Baseline);
      end;
      if Upper<>nil then Above:=Max(Above,-Upper.Y+LimitSpacing(Size,12,0.1));
      if Lower<>nil then Below:=Max(Below,Lower.Y+Lower.H+LimitSpacing(Size,12,0.1));
    end
    else
    begin
      Inc(Result.W,Base.W+ScriptWidth);
      if Upper<>nil then
      begin Upper.X:=GroupStart+Base.W; Upper.Y:=-Max(1,Round(MeasureEm(Size)*0.4))-Upper.Baseline; end;
      if Lower<>nil then
      begin Lower.X:=GroupStart+Base.W; Lower.Y:=Round(MeasureEm(Size)*0.2)-Lower.Baseline; end;
      if (Upper<>nil) and (Lower<>nil) and (Upper.Y+Upper.H+2>Lower.Y) then Lower.Y:=Upper.Y+Upper.H+2;
    end;
    if not Limits and (Base.Shape=5) then begin
      if Upper<>nil then Upper.Y:=-Max(Round(MeasureEm(Size)*0.413),
        Base.InkAbove-Round(MeasureEm(Size)*0.386))-Upper.Baseline;
      if Lower<>nil then Lower.Y:=Max(Round(MeasureEm(Size)*0.247),
        Base.InkBelow+Round(MeasureEm(Size)*0.05))-Lower.Baseline;
      if (Upper<>nil) and (Lower<>nil) and (Upper.Y+InkBottom(Upper)+2>Lower.Y+InkTop(Lower)) then
        Lower.Y:=Upper.Y+InkBottom(Upper)+2-InkTop(Lower);
    end;
    if not Limits and ((NativeName='\int') or (NativeName='\iint') or (NativeName='\iiint') or (NativeName='\iiiint') or (NativeName='\oint')) then
    begin
      Em:=MeasureEm(Size); ScriptPoints:=MathFontPoints(Min(2,FMathLevel+1));
      ScriptEm:=MeasureEm(MathFontSize(Min(2,FMathLevel+1)));
      SupDrop:=0.353171;
      case ScriptPoints of 5:SupDrop:=0.494446; 6:SupDrop:=0.412033; 8:SupDrop:=0.395834; end;
      IntegralHeight:=IfThen(FDisplayMath,1.361122,0.80556)*Em;
      IntegralDepth:=IfThen(FDisplayMath,0.861122,0.30556)*Em;
      ItalicCorrection:=IfThen(FDisplayMath,0.444446,0.194446)*Em;
      UpShift:=Round(Max(IntegralHeight-ScriptEm*SupDrop,Em*IfThen(FDisplayMath,0.412892,0.362892)));
      DownShift:=Round(Max(IntegralDepth+Em*0.05,Em*IfThen(Upper<>nil,0.247217,0.15)));
      if Upper<>nil then begin Upper.X:=GroupStart+Base.W; Upper.Y:=-UpShift-Upper.Baseline; end;
      if Lower<>nil then begin
        Lower.X:=GroupStart+Base.W-Round(ItalicCorrection); Lower.Y:=DownShift-Lower.Baseline;
      end;
      if (Upper<>nil) and (Lower<>nil) and
         (Upper.Y+InkBottom(Upper)+Round(Em*0.16)>Lower.Y+InkTop(Lower)) then
        Lower.Y:=Upper.Y+InkBottom(Upper)+Round(Em*0.16)-InkTop(Lower);
      Result.W:=GroupStart+Base.W;
      if Upper<>nil then Result.W:=Max(Result.W,Upper.X+Upper.W+Round(Em*0.05));
      if Lower<>nil then Result.W:=Max(Result.W,Lower.X+Lower.W+Round(Em*0.05));
    end;
    if Large and not Limits then
    begin
      if Upper<>nil then Upper.Y:=-Round(MeasureEm(Size)*0.45)-Upper.Baseline;
      if Lower<>nil then Lower.Y:=Round(MeasureEm(Size)*0.2)-Lower.Baseline;
    end;
    Base.X:=BaseX; Result.Children.Add(Base);
    if Upper<>nil then Result.Children.Add(Upper);
    if Lower<>nil then Result.Children.Add(Lower);
    { Preserve separate baseline positions before and after scripts. }
    HadScript:=False;
    for K:=I+1 to J-1 do
    begin
      Next:=Item(K);
      if (Next.Kind=mkGroup) and (Next.Prefix<>'') and (Next.Prefix[1] in ['^','_']) then HadScript:=True;
      if (Next.Kind=mkText) and (Next.Text='') then
      begin
        B:=MathBox(Next,Size);
        if HadScript then B.X:=Result.W else B.X:=BaseX+Base.W;
        B.Y:=-B.Baseline; Result.Children.Add(B);
      end;
    end;
    { tex.web mlist_to_hlist inserts penalties after binary and relation
      noads (including their scripts), outside explicit math groups. }
    if (CurrentClass in [2,3]) and (NextClass>=0) and (NextClass<>3) then begin
      K:=Length(Result.MathBreaks); SetLength(Result.MathBreaks,K+1);
      Result.MathBreaks[K].Offset:=Result.W;
      if CurrentClass=2 then Result.MathBreaks[K].Penalty:=700 else Result.MathBreaks[K].Penalty:=500;
      if NativeMod and (NativeName='\bmod') then Result.MathBreaks[K].Penalty:=900;
    end;
    I:=J;
  end;
  for I:=0 to Result.Children.Count-1 do
  begin
    B:=TDraftBox(Result.Children[I]); Above:=Max(Above,-B.Y); Below:=Max(Below,B.Y+B.H);
  end;
  Result.Baseline:=Above; Result.H:=Max(1,Above+Below);
  for I:=0 to Result.Children.Count-1 do Inc(TDraftBox(Result.Children[I]).Y,Above);
  except Result.Free; raise; end;
  finally
    Items.Free; FDisplayMath:=OldDisplay; FMathStyle:=OldMathStyle; FMathLevel:=OldLevel;
  end;
end;
function TParagraphDraft.LogoBox(Node:TMathNode; Size:Integer):TDraftBox;
var B:TDraftBox; Font:TTeXFontMetric; I,Base,OldHeight,OldHeading,OldDepth:Integer;
    Points,OldPoints,Em,XHeight,THeight:Double; OldMathLeaf:Boolean; Run:TTeXTextRun;
  procedure Letter(const Value:string; FontPoints,RaiseBy,Kern:Double);
  begin
    FTextStyle.Points:=FontPoints;
    B:=Leaf(Value,-1,Max(1,Round(Size*FontPoints/Points)),0);
    B.X:=Result.W+Round(Kern*Em); B.Y:=Base-B.Baseline-Round(RaiseBy);
    Result.Children.Add(B); Result.W:=B.X+B.W;
    Result.InkAbove:=Max(Result.InkAbove,Base-B.Y-B.Baseline+B.InkAbove);
    Result.InkBelow:=Max(Result.InkBelow,B.Y+B.Baseline+B.InkBelow-Base);
  end;
begin
  Result:=TDraftBox.Create; Result.ID:=Node.ID;
  OldHeight:=FDefaultHeight; OldHeading:=FHeadingSize; OldPoints:=FTextStyle.Points;
  OldMathLeaf:=FMathLeaf; OldDepth:=FTextStyleDepth;
  Points:=OldPoints; if OldHeading>0 then Points:=FHeadingPoints*Size/OldHeading;
  FHeadingSize:=0; FTextStyle.Points:=Points; FDefaultHeight:=0; FMathLeaf:=False; Inc(FTextStyleDepth);
  try
    B:=Leaf('T',-1,Size,0);
    Base:=B.Baseline; Em:=B.TextEm; THeight:=B.InkAbove; XHeight:=Em*0.430555;
    if B.TextRun.Valid then begin
      THeight:=B.TextRun.Height*Em;
      if B.TextFont<>'' then begin
        Font:=TeXFontMetric(B.TextFont);
        if Length(Font.Parameters)>4 then XHeight:=Font.Parameters[4]*Em;
        if Length(Font.Parameters)>5 then Em:=Font.Parameters[5]*Em;
      end else begin
        Run:=ShapeOpenType(B.TextOutlineFont,'x',B.TextFeatures); if Run.Valid then XHeight:=Run.Height*Em;
      end;
    end;
    Result.H:=B.H; B.Free;
    { ltlogos.dtx: the script-size A has its top aligned with T; the E
      is lowered by half the current font's x-height. }
    if Pos('\LaTeX',Node.Text)=1 then begin
      Letter('L',Points,0,0);
      Letter('A',TextScriptPoints(Points,Directory),0,-0.36);
      B.Y:=Base-B.Baseline+ B.InkAbove-Round(THeight);
      Result.InkAbove:=Max(Result.InkAbove,Round(THeight));
      Letter('T',Points,0,-0.15);
    end else Letter('T',Points,0,0);
    Letter('E',Points,-0.5*XHeight,-0.1667);
    Letter('X',Points,0,-0.125);
  finally
    FDefaultHeight:=OldHeight; FHeadingSize:=OldHeading; FTextStyle.Points:=OldPoints;
    FMathLeaf:=OldMathLeaf; FTextStyleDepth:=OldDepth;
  end;
  Result.Baseline:=Base; Result.HasInkMetric:=True;
  Result.H:=Max(Result.H,Base+Result.InkBelow);
  Result.CharCount:=UTF8Length(Node.Text); SetLength(Result.Stops,Result.CharCount+1);
  Result.Stops[0]:=0;
  for I:=1 to Result.CharCount do Result.Stops[I]:=Result.W;
end;
function TParagraphDraft.TextBox(Node:TMathNode; Size:Integer):TDraftBox;
var I,Above,Below,P,OldDepth:Integer; B:TDraftBox; S,OldFont,Command:string; OldStyle:TFontStyles; OldHeight:Integer; OldMathLeaf:Boolean; OldPoints:Double; OldTextStyle:TTeXTextStyle;
    SourceMap,RenderedStops:TCharStops;
  procedure NormalizeSpaces;
  var Input,Output,Bytes,SourceCount,VisibleCount:Integer; WasSpace:Boolean;
  begin
    if (Pos('  ',S)=0) and (Pos(#9,S)=0) and (Pos(#10,S)=0) and (Pos(#13,S)=0) then Exit;
    SetLength(SourceMap,UTF8Length(S)+1);
    SetLength(S,Length(Node.Text)); Input:=1; Output:=1; SourceCount:=0; VisibleCount:=0; WasSpace:=False;
    while Input<=Length(Node.Text) do begin
      Bytes:=Min(Max(1,UTF8CharacterLength(PChar(Node.Text)+Input-1)),Length(Node.Text)-Input+1);
      if Node.Text[Input] in [' ',#9,#10,#13] then begin
        if not WasSpace then begin S[Output]:=' '; Inc(Output); Inc(VisibleCount); end;
        WasSpace:=True;
      end else begin
        Move(Node.Text[Input],S[Output],Bytes); Inc(Output,Bytes); Inc(VisibleCount); WasSpace:=False;
      end;
      Inc(Input,Bytes); Inc(SourceCount); SourceMap[SourceCount]:=VisibleCount;
    end;
    SetLength(S,Output-1);
  end;
begin
  if Node.Kind in [mkDefinition,mkUnknownCommand,mkComment,mkDiagram] then Exit(MathBox(Node,Size));
  if (Node.Text='\LaTeX') or (Node.Text='\LaTeX{}') or (Node.Text='\TeX') or (Node.Text='\TeX{}') then Exit(LogoBox(Node,Size));
  Result:=TextSymbolBox(Node,Size); if Result<>nil then Exit;
  Result:=TextAccentBox(Node,Size); if Result<>nil then Exit;
  Result:=PackageGlyphBox(Node,Size); if Result<>nil then Exit;
  Result:=NativeBox(Node,Size); if Result<>nil then Exit;
  OldFont:=FDefaultFont; OldStyle:=FDefaultStyle; OldHeight:=FDefaultHeight;
  OldTextStyle:=FTextStyle; OldDepth:=FTextStyleDepth;
  { Preserve the body family/style, but let script and fraction sizes scale. }
  if Node.Text='\text' then FDefaultHeight:=0;
  if (Node.Text='\operatorname') or (Node.Text='\operatorname*') then begin
    FDefaultFont:='Latin Modern Roman'; FDefaultStyle:=[]; FDefaultHeight:=0;
    FTextStyle.Family:=FTextStyle.Roman; FTextStyle.Series:='m'; FTextStyle.Shape:='n';
    if (FBeamerTheme<>nil) and FBeamerTheme.Settings.Enabled and not FBeamerTheme.Settings.SerifMath then
      FTextStyle.Family:=FTextStyle.Sans;
    Inc(FTextStyleDepth);
  end;
  P:=1; Command:=ReadTeXCommand(Node.Text,P);
  if (Command='textbf') or (Command='textit') or (Command='emph') or (Command='textrm') or
    (Command='textsf') or (Command='texttt') or (Command='textsc') or (Command='textsl') or
    (Command='textup') or (Command='textmd') or (Command='textnormal') then begin
    ApplyTextStyle(FTextStyle,Node.Text,Directory); Inc(FTextStyleDepth); FDefaultStyle:=[]; FDefaultHeight:=0;
    FDefaultFont:='Latin Modern Roman';
    if FTextStyle.Family=FTextStyle.Sans then FDefaultFont:='Latin Modern Sans'
    else if FTextStyle.Family=FTextStyle.Mono then FDefaultFont:='Latin Modern Mono';
  end;
  if Node.Children.Count=0 then
  begin
    S:=Node.Text;
    if Node.Kind=mkText then NormalizeSpaces;
    if (Length(S)=2) and (S[1]='\') then begin
      S:=S[2]; SetLength(SourceMap,UTF8Length(Node.Text)+1);
      for I:=1 to High(SourceMap) do SourceMap[I]:=1;
    end;
    { Text inside mathematics uses the same text metrics and baseline as the
      body. Desktop italic ascenders must not replace TeX's text baseline. }
    OldMathLeaf:=FMathLeaf; FMathLeaf:=False; OldPoints:=FTextStyle.Points;
    if FMathLevel>0 then FTextStyle.Points:=MathFontPoints(FMathLevel);
    try Result:=Leaf(S,Node.ID,Size,0); finally FMathLeaf:=OldMathLeaf; FTextStyle.Points:=OldPoints; end;
    if Length(SourceMap)>0 then begin
      { Shape the visible run once, then map its caret stops back to source
        characters. Re-shaping every prefix was quadratic and lost the full
        run's ligatures, kerning and CJK spacing at intermediate stops. }
      RenderedStops:=Result.Stops;
      if Length(RenderedStops)=0 then begin
        SetLength(RenderedStops,UTF8Length(S)+1); P:=1;
        for I:=1 to High(RenderedStops) do begin
          Inc(P,Max(1,UTF8CharacterLength(PChar(S)+P-1)));
          RenderedStops[I]:=TeXTextWidth(FCanvas,Copy(S,1,P-1));
        end;
      end;
      Result.CharCount:=High(SourceMap); SetLength(Result.Stops,Length(SourceMap));
      for I:=0 to High(SourceMap) do Result.Stops[I]:=RenderedStops[Min(SourceMap[I],High(RenderedStops))];
    end;
    if (Node.ID>=0) and IsEmptyMathArgument(Node) and not HideEditingMarks then begin Result.Shape:=3; Result.W:=14; end;
  end
  else
  begin
    Result:=TDraftBox.Create; Above:=0; Below:=0;
    for I:=0 to Node.Children.Count-1 do
    begin
      B:=TextBox(TMathNode(Node.Children[I]),Size); B.X:=Result.W; Inc(Result.W,B.W);
      Above:=Max(Above,B.Baseline); Below:=Max(Below,B.H-B.Baseline); Result.Children.Add(B);
    end;
    Result.Baseline:=Above; Result.H:=Above+Below;
    for I:=0 to Result.Children.Count-1 do begin B:=TDraftBox(Result.Children[I]); B.Y:=Above-B.Baseline; end;
    Result.HasInkMetric:=True;
    for I:=0 to Result.Children.Count-1 do begin
      B:=TDraftBox(Result.Children[I]); Result.InkAbove:=Max(Result.InkAbove,B.Baseline-InkTop(B));
      Result.InkBelow:=Max(Result.InkBelow,InkBottom(B)-B.Baseline);
    end;
  end;
  FDefaultFont:=OldFont; FDefaultStyle:=OldStyle; FDefaultHeight:=OldHeight;
  FTextStyle:=OldTextStyle; FTextStyleDepth:=OldDepth;
end;
function PreviewArgument(Node:TMathNode; MathMode:Boolean; Macros:TMacroRegistry):TMathNode;
var I,ID:Integer; Error,Value:string;
  procedure Number(N:TMathNode);
  var J:Integer;
  begin
    N.ID:=ID; N.PreviewOrigin:=TMathNode(Node.Children[0]);
    for J:=0 to N.Children.Count-1 do Number(TMathNode(N.Children[J]));
  end;
begin
  if (Node.Kind=mkOptional) and (Node.Prefix='') and (Node.Children.Count>0) then begin
    Value:=Node.Text; if Value='\NoValue' then Value:='';
    ID:=TMathNode(Node.Children[0]).ID;
    if MathMode then begin
      if not ParseMath(Value,Result,Error,Macros,True,@ParseParagraph) then Result:=TMathNode.Create(mkText,Value);
    end else Result:=ParseParagraph(Value,Macros);
    Number(Result); Exit;
  end;
  Result:=TMathNode.Create(Node.Kind,Node.Text); Result.ID:=Node.ID; Result.Prefix:=Node.Prefix; Result.Suffix:=Node.Suffix;
  Result.PreviewOrigin:=Node.PreviewOrigin; if Result.PreviewOrigin=nil then Result.PreviewOrigin:=Node;
  Result.NativePackage:=Node.NativePackage; Result.LiteralArguments:=Node.LiteralArguments;
  Result.OptionalDefault:=Node.OptionalDefault; Result.Hidden:=Node.Hidden; Result.PreviewAtomic:=Node.PreviewAtomic;
  Result.DiagramField:=Node.DiagramField;
  Result.TextMode:=Node.TextMode;
  Result.SourceEditing:=Node.SourceEditing; Result.SourceExpanded:=Node.SourceExpanded; Result.SourceCollapsed:=Node.SourceCollapsed;
  if Node.SourcePreview<>nil then Result.SourcePreview:=PreviewArgument(Node.SourcePreview,MathMode,Macros);
  for I:=0 to Node.Children.Count-1 do Result.Add(PreviewArgument(TMathNode(Node.Children[I]),MathMode,Macros));
end;
{$I nativeboxes.inc}
{$I diagonalbox.inc}
function BindLiteralPreviewArgument(Node:TMathNode; const Args:array of TMathNode;
  const Marker:string; MathMode:Boolean; Macros:TMacroRegistry):Boolean;
var I,J:Integer; Token,Value:string; Argument,Field:TMathNode;
begin
  Result:=False;
  if not (Node.Kind in [mkText,mkProse,mkRaw,mkCommand,mkTextCommand]) or (Node.Children.Count<>0) then Exit;
  for I:=0 to High(Args) do begin
    if Args[I]=nil then Continue; Token:=Marker+'{PasTeXDraftArg'+IntToStr(I+1)+'}';
    if Pos(Token,Node.Text)=0 then Continue;
    Argument:=PreviewArgument(Args[I],MathMode,Macros);
    try
      Value:='';
      if Argument.Kind in [mkGroup,mkOptional] then
        for J:=0 to Argument.Children.Count-1 do Value:=Value+TMathNode(Argument.Children[J]).TeX
      else Value:=Argument.TeX;
      Field:=Argument; while Field.Children.Count>0 do Field:=TMathNode(Field.Children[0]);
      Node.ID:=Field.ID; Node.Text:=StringReplace(Node.Text,Token,Value,[rfReplaceAll]);
      Result:=True;
    finally Argument.Free; end;
  end;
end;
function TParagraphDraft.PackageBox(Node:TMathNode; Size:Integer):TDraftBox;
var Info:TMacroInfo; Values,Formatted:TPackageArguments; Args:array[1..9] of TMathNode;
    Tree:TMathNode; Name,Template,Error:string; I,J:Integer; OldMathLeaf:Boolean; Mapping:TPackagePreviewMap;
  procedure ClearIDs(N:TMathNode);
  var K:Integer;
  begin N.ID:=-1; for K:=0 to N.Children.Count-1 do ClearIDs(TMathNode(N.Children[K])); end;
  function Field(N:TMathNode):TMathNode;
  begin Result:=N; while Result.Children.Count>0 do Result:=TMathNode(Result.Children[0]); end;
  procedure BindTokens(N,Original:TMathNode; const Parts:TPackagePreviewParts);
  var K,Index,Opening:Integer; Child,Replacement:TMathNode; Text,Raw:string;
  begin
    for K:=0 to N.Children.Count-1 do begin
      Child:=TMathNode(N.Children[K]); Text:=Child.TeX; Index:=-1;
      if (Child.Kind=mkCommand) and (Child.Text='\text') and (Pos('\text{PasTeXNative',Text)=1) then
        Index:=StrToIntDef(Copy(Text,19,Length(Text)-19),-1);
      if (Index>=0) and (Index<Length(Parts)) then begin
        Replacement:=nil;
        if not ParseMath(Parts[Index].Text,Replacement,Error,Macros,True,@ParseParagraph) then Replacement:=TMathNode.Create(mkText,Parts[Index].Text);
        ClearIDs(Replacement); Replacement.ID:=Original.ID;
        Replacement.PreviewChars:=Parts[Index].Count; Replacement.PreviewFirst:=Parts[Index].First;
        Raw:=UTF8Copy(Original.Text,Parts[Index].First+1,Parts[Index].Count);
        Opening:=Pos('{',Raw);
        if (Opening>0) and ((Copy(Raw,1,1)='\') or (Copy(Raw,1,1)='^')) then begin
          Replacement.PreviewPrefix:=UTF8Length(Copy(Raw,1,Opening));
          if Copy(Raw,Length(Raw),1)='}' then Replacement.PreviewSuffix:=1;
        end else if Copy(Raw,1,1)='^' then Replacement.PreviewPrefix:=1
        else Replacement.PreviewAtomic:=Copy(Raw,1,1)='\';
        N.Children.Extract(Child); Child.Free; Replacement.Parent:=N; N.Children.Insert(K,Replacement);
      end else BindTokens(Child,Original,Parts);
    end;
  end;
  procedure Bind(N:TMathNode);
  var K,Index:Integer; Child,Replacement,Original:TMathNode; Text:string;
  begin
    N.ID:=-1;
    for K:=0 to N.Children.Count-1 do begin
      Child:=TMathNode(N.Children[K]); Text:=Child.TeX; Index:=0;
      if (Child.Kind=mkCommand) and (Child.Text='\text') then
        for Index:=1 to Length(Values) do if Text='\text{PasTeXDraftArg'+IntToStr(Index)+'}' then Break;
      if (Index>0) and (Index<=Length(Values)) and (Text='\text{PasTeXDraftArg'+IntToStr(Index)+'}') then begin
        if Values[Index-1]='' then begin
          Replacement:=TMathNode.Create(mkRow); Original:=Field(Args[Index]);
          Replacement.Add(TMathNode.Create(mkText)).ID:=Original.ID;
        end else if Formatted[Index-1]=#0 then Replacement:=PreviewArgument(Args[Index],True,Macros)
        else begin
          Replacement:=nil;
          if not ParseMath(Formatted[Index-1],Replacement,Error,Macros,True,@ParseParagraph) then Replacement:=TMathNode.Create(mkText,Values[Index-1]);
          ClearIDs(Replacement); Original:=Field(Args[Index]); Replacement.ID:=Original.ID;
          if Length(Mapping[Index-1])>0 then begin
            Replacement.ID:=-1; BindTokens(Replacement,Original,Mapping[Index-1]);
          end else Replacement.PreviewChars:=UTF8Length(Original.Text);
        end;
        if Replacement.Kind in [mkGroup,mkOptional] then begin Replacement.Kind:=mkRow; Replacement.Prefix:=''; Replacement.Suffix:=''; end;
        N.Children.Extract(Child); Child.Free; Replacement.Parent:=N; N.Children.Insert(K,Replacement);
      end else Bind(Child);
    end;
  end;
begin
  Result:=nil; if (Macros=nil) or (Node.Kind<>mkCommand) then Exit;
  Info:=Macros.Find(Copy(Node.Text,2,MaxInt));
  if (Info=nil) or ((Info.PreviewAdapter<>'units') and (Info.PreviewAdapter<>'derivative')) then Exit;
  FillChar(Args,SizeOf(Args),0); SetLength(Values,Info.ArgCount); J:=0; Name:=Copy(Node.Text,2,MaxInt);
  if Info.PreviewName<>'' then begin Name:=Info.PreviewName; if Pos('*',Node.Text)>0 then Name:=Name+'*'; end;
  for I:=0 to Node.Children.Count-1 do begin
    Tree:=TMathNode(Node.Children[I]);
    if Tree.Kind=mkRaw then begin Name:=Name+Trim(Tree.Text); Continue; end;
    if J>=Length(Values) then Break; Args[J+1]:=Tree;
    if (Tree.Kind=mkOptional) and (Tree.Prefix='') then Values[J]:=Tree.Text
    else begin
      Template:=Tree.TeX;
      Values[J]:=Copy(Template,Length(Tree.Prefix)+1,Length(Template)-Length(Tree.Prefix)-Length(Tree.Suffix));
    end;
    Inc(J);
  end;
  if J<>Length(Values) then Exit;
  if not PackageMathPreview(Name,Values,HeadingContext,Template,Formatted,@Mapping) then Exit;
  Tree:=nil; if not ParseMath(Template,Tree,Error,Macros,True,@ParseParagraph) then Exit;
  OldMathLeaf:=FMathLeaf; FMathLeaf:=True;
  try
    Bind(Tree); Result:=MathBox(Tree,Size); Result.ID:=Node.ID;
    Result.CharCount:=UTF8Length(Node.Text); SetLength(Result.Stops,Result.CharCount+1);
    for I:=1 to Result.CharCount do Result.Stops[I]:=Result.W;
  finally FMathLeaf:=OldMathLeaf; Tree.Free; end;
end;
function TParagraphDraft.ExpandedMacro(Node:TMathNode; Size:Integer):TDraftBox;
var Info:TMacroInfo; Expanded,Err,Token,DefaultValue:string; Tree,Arg:TMathNode; I,J:Integer;
    Args:array[1..9] of TMathNode; Values:array[1..9] of string;
  procedure BindArguments(N:TMathNode);
  var K,Index:Integer; Child,Replacement:TMathNode; S:string;
  begin
    N.ID:=-1;
    for K:=0 to N.Children.Count-1 do
    begin
      Child:=TMathNode(N.Children[K]); S:=Child.TeX; Index:=0;
      if (Child.Kind=mkCommand) and (Child.Text='\text') then
        for Index:=1 to 9 do if S='\text{PasTeXDraftArg'+IntToStr(Index)+'}' then Break;
      if (Index>=1) and (Index<=9) and (S='\text{PasTeXDraftArg'+IntToStr(Index)+'}') and (Args[Index]<>nil) then
      begin
        Replacement:=PreviewArgument(Args[Index],True,Macros);
        if Replacement.Kind in [mkGroup,mkOptional] then
        begin Replacement.Kind:=mkRow; Replacement.Prefix:=''; Replacement.Suffix:=''; end;
        N.Children.Extract(Child); Child.Free; Replacement.Parent:=N; N.Children.Insert(K,Replacement);
      end
      else if not BindLiteralPreviewArgument(Child,Args,'\text',True,Macros) then BindArguments(Child);
    end;
  end;
begin
  Result:=nil;
  if (Macros=nil) or (Node.Kind<>mkCommand) or (FExpansionDepth>=16) or (FExpansionBudget<=0) then Exit;
  Info:=Macros.Find(Copy(Node.Text,2,MaxInt));
  if (Info=nil) or not Info.Expandable or (Info.ArgCount>9) or (Info.GlyphFont<>'') or
     (Info.PreviewAdapter='units') or (Info.PreviewAdapter='derivative') or
     (Info.PreviewAdapter='box') or (Info.PreviewAdapter='adjustbox') or
     (Info.PreviewAdapter='colorbox') or (Info.PreviewAdapter='space') then Exit;
  { Package implementations of supported atoms often call TeX internals.
    Keep their native layout; explicit source redefinitions still expand. }
  if (Info.PackageSource<>'') and (MathArgumentCount(Copy(Node.Text,2,MaxInt))>=0) then Exit;
  if (Node.Text='\reallywidehat') and (Pos('\mathpalette\PasTeXWideHat',Info.Body)>0) then Exit;
  Dec(FExpansionBudget);
  FillChar(Args,SizeOf(Args),0); J:=0;
  for I:=1 to Info.ArgCount do
  begin
    Arg:=nil;
    if J<Node.Children.Count then Arg:=TMathNode(Node.Children[J]);
    if (Info.ArgumentKind(I,DefaultValue) in ['o','O']) and
       ((Arg=nil) or (Arg.Kind<>mkOptional) or (Arg.Prefix='')) then begin
      Token:=DefaultValue;
      if (Arg<>nil) and (Arg.Kind=mkOptional) and (Arg.Children.Count>0) then begin
        Args[I]:=Arg; Inc(J); Token:='\text{PasTeXDraftArg'+IntToStr(I)+'}';
      end;
    end
    else
    begin
      if Arg=nil then Exit;
      Args[I]:=Arg; Inc(J); Token:='\text{PasTeXDraftArg'+IntToStr(I)+'}';
    end;
    if (Info.PreviewAdapter='mathpalette') and (I=1) then
      Token:=Copy(Arg.TeX,Length(Arg.Prefix)+1,Length(Arg.TeX)-Length(Arg.Prefix)-Length(Arg.Suffix));
    Values[I]:=Token;
  end;
  if not SubstituteTeXParameters(Info.Body,Slice(Values,Info.ArgCount),Expanded) then Exit;
  Tree:=nil;
  if not ParseMath(Expanded,Tree,Err,Macros,True,@ParseParagraph) then Exit;
  Inc(FExpansionDepth);
  try
    BindArguments(Tree); Result:=MathBox(Tree,Size); Result.ID:=Node.ID;
    Result.CharCount:=UTF8Length(Node.Text); SetLength(Result.Stops,Result.CharCount+1);
    Result.Stops[0]:=0;
    for I:=1 to Result.CharCount do Result.Stops[I]:=Result.W;
  finally Dec(FExpansionDepth); Tree.Free; end;
end;
function TParagraphDraft.ExpandedProseMacro(Node:TMathNode):TMathNode;
var Info:TMacroInfo; Template,Expanded,Token,DefaultValue:string; I,J:Integer; Arg:TMathNode;
    Args:array[1..9] of TMathNode; Values:array[1..9] of string;
  procedure Bind(N:TMathNode);
  var K,A:Integer; Child,Replacement:TMathNode;
  begin
    N.ID:=Node.ID;
    for K:=0 to N.Children.Count-1 do begin
      Child:=TMathNode(N.Children[K]); A:=0;
      if (Child.Kind=mkCommand) and (Child.Text='\label') then
        for A:=1 to 9 do if Child.TeX='\label{PasTeXDraftArg'+IntToStr(A)+'}' then Break;
      if (A>=1) and (A<=9) and (Args[A]<>nil) and (Child.TeX='\label{PasTeXDraftArg'+IntToStr(A)+'}') then begin
        Replacement:=PreviewArgument(Args[A],False,Macros);
        if Replacement.Kind in [mkGroup,mkOptional] then begin Replacement.Kind:=mkRow; Replacement.Prefix:=''; Replacement.Suffix:=''; end;
        N.Children.Extract(Child); Child.Free; Replacement.Parent:=N; N.Children.Insert(K,Replacement);
      end else if not BindLiteralPreviewArgument(Child,Args,'\label',False,Macros) then Bind(Child);
    end;
  end;
begin
  Result:=nil;
  if (Macros=nil) or (Node.Kind<>mkCommand) or (FExpansionDepth>=16) or (FExpansionBudget<=0) then Exit;
  Info:=Macros.Find(Copy(Node.Text,2,MaxInt));
  if (Info=nil) or not Info.Expandable or Info.Undefined or (Info.ArgCount>9) or (Info.GlyphFont<>'') or
     (Info.PreviewAdapter='units') or (Info.PreviewAdapter='derivative') or
     (Info.PreviewAdapter='box') or (Info.PreviewAdapter='adjustbox') or
     (Info.PreviewAdapter='colorbox') or (Info.PreviewAdapter='space') then Exit;
  Dec(FExpansionBudget); FillChar(Args,SizeOf(Args),0);
  Template:=PackageTextTemplate(Info.PreviewAdapter,Info.PreviewName,Info.Body,HeadingContext); J:=0;
  for I:=1 to Info.ArgCount do begin
    Arg:=nil; if J<Node.Children.Count then Arg:=TMathNode(Node.Children[J]);
    if (Info.ArgumentKind(I,DefaultValue) in ['o','O']) and
       ((Arg=nil) or (Arg.Kind<>mkOptional) or (Arg.Prefix='')) then begin
      Token:=DefaultValue;
      if (Arg<>nil) and (Arg.Kind=mkOptional) and (Arg.Children.Count>0) then begin
        Args[I]:=Arg; Inc(J); Token:='\label{PasTeXDraftArg'+IntToStr(I)+'}';
      end;
    end
    else begin
      if Arg=nil then Exit; Args[I]:=Arg; Inc(J); Token:='\label{PasTeXDraftArg'+IntToStr(I)+'}';
    end;
    Values[I]:=Token;
  end;
  if not SubstituteTeXParameters(Template,Slice(Values,Info.ArgCount),Expanded) then Exit;
  Result:=ParseParagraph(Expanded,Macros); Bind(Result);
end;
function StyledMath(const Text,Style:string):string;
var I,Code:Integer; C:Char;
begin
  Result:='';
  for I:=1 to Length(Text) do
  begin
    C:=Text[I]; Code:=0;
    if C in ['A'..'Z'] then
    begin
      if Style='' then Code:=$1D434+Ord(C)-65;
      if (Style='\mathcal') or (Style='\mathscr') then Code:=$1D49C+Ord(C)-65
      else if Style='\mathbb' then Code:=$1D538+Ord(C)-65
      else if Style='\mathfrak' then Code:=$1D504+Ord(C)-65;
      if Style='\mathbb' then case C of 'C':Code:=$2102; 'H':Code:=$210D; 'N':Code:=$2115; 'P':Code:=$2119; 'Q':Code:=$211A; 'R':Code:=$211D; 'Z':Code:=$2124; end;
      if (Style='\mathcal') or (Style='\mathscr') then case C of 'B':Code:=$212C; 'E':Code:=$2130; 'F':Code:=$2131; 'H':Code:=$210B; 'I':Code:=$2110; 'L':Code:=$2112; 'M':Code:=$2133; 'R':Code:=$211B; end;
      if Style='\mathfrak' then case C of 'C':Code:=$212D; 'H':Code:=$210C; 'I':Code:=$2111; 'R':Code:=$211C; 'Z':Code:=$2128; end;
    end
    else if C in ['a'..'z'] then
    begin
      if Style='' then begin Code:=$1D44E+Ord(C)-97; if C='h' then Code:=$210E; end;
      if Style='\mathfrak' then Code:=$1D51E+Ord(C)-97
      else if Style='\mathbb' then Code:=$1D552+Ord(C)-97;
    end
    else if (C in ['0'..'9']) and (Style='\mathbb') then Code:=$1D7D8+Ord(C)-48;
    if Code=0 then Result:=Result+C else Result:=Result+UnicodeToUTF8(Code);
  end;
end;
function SingleMathAtom(Node:TMathNode):string;
begin
  while Node.Children.Count=1 do Node:=TMathNode(Node.Children[0]);
  if Node.Children.Count=0 then Result:=Node.Text else Result:='';
end;
function TParagraphDraft.ModularBox(Node:TMathNode; Size:Integer; const Command:string):TDraftBox;
var I,Padding:Integer; B:TDraftBox; Em:Double;
  procedure Append(Box:TDraftBox);
  begin
    Box.X:=Result.W; Inc(Result.W,Box.W);
    Result.Baseline:=Max(Result.Baseline,Box.Baseline); Result.Children.Add(Box);
  end;
  procedure Token(const Text:string; OperatorText:Boolean=False);
  var N:TMathNode;
  begin
    if OperatorText then begin
      N:=TMathNode.Create(mkCommand,'\operatorname');
      N.Add(TMathNode.Create(mkText,Text)).ID:=-1;
    end else N:=TMathNode.Create(mkText,Text);
    N.ID:=-1;
    try Append(MathBox(N,Size)); finally N.Free; end;
  end;
begin
  { amsmath.sty's mod family uses fixed mu kerns and ordinary, upright
    operator letters; parentheses remain text-sized even around fractions. }
  Result:=TDraftBox.Create; Result.ID:=Node.ID; Result.Size:=Size;
  Result.Color:=FDefaultColor; Em:=MeasureEm(Size)/18;
  try
    if Command='\bmod' then begin
      Padding:=1; if FMathLevel>0 then Padding:=5;
      Result.W:=Round(Padding*Em); Token('mod',True); Inc(Result.W,Round(Padding*Em));
    end else begin
      Padding:=18;
      if not FDisplayMath then begin Padding:=8; if Command='\mod' then Padding:=12; end;
      Result.W:=Round(Padding*Em);
      if Command<>'\mod' then Token('(');
      if Command<>'\pod' then begin Token('mod',True); Inc(Result.W,Round(6*Em)); end;
      if Node.Children.Count>0 then Append(MathBox(TMathNode(Node.Children[0]),Size));
      if Command<>'\mod' then Token(')');
    end;
    for I:=0 to Result.Children.Count-1 do begin
      B:=TDraftBox(Result.Children[I]); B.Y:=Result.Baseline-B.Baseline;
      Result.H:=Max(Result.H,B.Y+B.H);
    end;
    Result.CharCount:=UTF8Length(Node.Text); SetLength(Result.Stops,Result.CharCount+1);
    for I:=1 to Result.CharCount do Result.Stops[I]:=Result.W;
  except Result.Free; raise; end;
end;
function TParagraphDraft.MathBox(Node:TMathNode; Size:Integer):TDraftBox;
var State:TBeamerNodeState; OldColor:TColor;
begin
  if (Node.Children.Count=0) and (BeamerNodeRole(Node)<>'') then Exit(TDraftBox.Create);
  State:=Default(TBeamerNodeState); if FBeamerProjection<>nil then State:=FBeamerProjection.State(Node);
  if State.Visibility=bvAbsent then Exit(TDraftBox.Create);
  OldColor:=FDefaultColor;
  if State.Alert then FDefaultColor:=PresentationTheme.Color('alerted text')
  else if BeamerNodeRole(Node)='structure' then FDefaultColor:=PresentationTheme.Color('structure');
  try Result:=MathBoxContent(Node,Size); finally FDefaultColor:=OldColor; end;
  Result.Covered:=State.Visibility=bvCovered;
end;
function TParagraphDraft.MathBoxContent(Node:TMathNode; Size:Integer):TDraftBox;
var I,Above,Below,OldHeight,Index,OldLevel,ChildLevel,ShiftUp,ShiftDown,OldDepth:Integer;
    Em,IH,IDep,Clearance,SpaceWidth,Axis,RuleThickness,OldPoints:Double;
    B,A,Stack:TDraftBox; S,PlainText,OldFont,VisiblePrefix,Ch,SavedMathStyle:string; Formula:TMathNode;
    OldStyle:TFontStyles; OldDisplay:Boolean; ChildSize,P:Integer; SpaceUnits:string;
    Info:TMacroInfo; OuterMacros,LocalMacros:TMacroRegistry; Command:string;
    OldTextStyle:TTeXTextStyle; Fill:TTeXFill;
begin
  if Node.Hidden and (Node.Kind=mkRaw) then Exit(TDraftBox.Create);
  if Node.PreviewChars>=0 then begin
    I:=Node.PreviewChars; Node.PreviewChars:=-1;
    try Result:=MathBox(Node,Size); finally Node.PreviewChars:=I; end;
    if Node.TeX='' then begin Result.Children.Clear; Result.Text:=''; Result.Shape:=0; Result.W:=0; end;
    Result.ID:=Node.ID; Result.FirstChar:=Node.PreviewFirst; Result.CharCount:=I; SetLength(Result.Stops,I+1);
    Result.SourceMapped:=True; Result.Size:=Size;
    for P:=0 to I do
      if Node.PreviewAtomic and (P<I) then Result.Stops[P]:=0
      else Result.Stops[P]:=Round(Result.W*EnsureRange(P-Node.PreviewPrefix,0,
        Max(0,I-Node.PreviewPrefix-Node.PreviewSuffix))/Max(1,I-Node.PreviewPrefix-Node.PreviewSuffix)); Exit;
  end;
  OuterMacros:=Macros; LocalMacros:=nil;
  if (Node.Kind in [mkGroup,mkEnvironment]) and HasMacroDefinitions(Node) and (Macros<>nil) then begin
    LocalMacros:=Macros.Clone; Macros:=LocalMacros; FMacroScopes.Add(Macros);
  end;
  try
  if Node.Kind=mkDiagram then Exit(DiagramBox(Node,Size,FMathWidth));
  if Node.Kind=mkFormula then Exit(FormulaBox(Node,Size));
  if Node.Kind in [mkDefinition,mkUnknownCommand,mkComment] then begin
    Result:=DefinitionBox(Node,Size,FMathWidth);
    if (Node.Kind=mkDefinition) and (Macros<>nil) then begin
      Macros.ApplyDefinitions(Node.TeX); P:=1; Command:=ReadTeXCommand(Node.TeX,P);
      if (Command='gdef') or (Command='xdef') then
        for I:=0 to FMacroScopes.Count-2 do TMacroRegistry(FMacroScopes[I]).ApplyDefinitions(Node.TeX);
    end;
    Exit;
  end;
  Formula:=MathChoiceArgument(Node,FMathLevel,FDisplayMath);
  if Formula<>nil then begin Result:=MathBox(Formula,Size); Result.ID:=Node.ID; Exit; end;
  S:=Node.Text;
  if (Node.Kind=mkRaw) and (Copy(S,1,1)='\') then begin
    P:=1; Command:=ReadTeXCommand(S,P); Em:=0;
    case Command of
      'big','bigl','bigr','bigm':Em:=1.2;
      'Big','Bigl','Bigr','Bigm':Em:=1.8;
      'bigg','biggl','biggr','biggm':Em:=2.4;
      'Bigg','Biggl','Biggr','Biggm':Em:=3.0;
      'middle','right':Em:=1;
    end;
    if Em>0 then begin
      Ch:=Trim(Copy(S,P,MaxInt)); Index:=ChooseTeXGlyph(DelimiterKind(Ch),Em);
      if Index>=0 then begin
        Result:=TDraftBox.Create; Result.Color:=FDefaultColor; Result.Shape:=5; Result.Text:=Ch+#1+'.'; Result.Size:=Size; Result.ID:=Node.ID;
        Result.LeftGlyph:=Index; Result.LeftWidth:=Round(TeXDelimiterAdvance(Index)*MeasureEm(Size)); Result.W:=Result.LeftWidth;
        Result.H:=Ceil(TeXGlyphMetrics[Index].H*MeasureEm(Size)); Result.Baseline:=Round(Result.H/2+MeasureEm(Size)*0.25);
        Result.HasInkMetric:=True; Result.InkAbove:=Result.Baseline; Result.InkBelow:=Result.H-Result.Baseline;
        Result.CharCount:=UTF8Length(S); SetLength(Result.Stops,Result.CharCount+1);
        for I:=1 to Result.CharCount do Result.Stops[I]:=Result.W; Exit;
      end;
    end;
  end;
  Info:=nil; if (Macros<>nil) and (Node.Kind=mkCommand) then Info:=Macros.Find(Copy(Node.Text,2,MaxInt));
  Command:=Node.Text; if (Info<>nil) and (Info.NativeName<>'') then Command:=Info.NativeName;
  if (Node.Kind=mkCommand) and ((Command='\bmod') or (Command='\mod') or
     (Command='\pmod') or (Command='\pod')) and
     ((Info=nil) or (Info.PackageSource<>'') or (Info.NativeName<>'') or
      ((Info.Body='') and not Info.Expandable and not Info.Undefined)) then
    Exit(ModularBox(Node,Size,Command));
  if (Node.Kind=mkCommand) and (Node.Children.Count=2) and
     ((Command='\overset') or (Command='\underset') or (Command='\stackrel')) and
     ((Info=nil) or (Info.PackageSource<>'') or (Info.Body='') or (Info.NativeName<>'')) then begin
    { amsmath uses mathop with explicit limits. TeX make_op supplies the
      extension font's clearances, baseline distances and outer padding. }
    A:=MathBox(TMathNode(Node.Children[1]),Size);
    B:=ScriptBox(TMathNode(Node.Children[0]),Size);
    Result:=TDraftBox.Create; Result.Color:=FDefaultColor; Result.ID:=Node.ID; Result.Size:=Size;
    Result.W:=Max(A.W,B.W); A.X:=(Result.W-A.W) div 2; B.X:=(Result.W-B.W) div 2;
    if Command='\underset' then begin
      B.Y:=A.H+Max(LimitSpacing(Size,9,0.166667),LimitSpacing(Size,11,0.6)-B.Baseline);
      Result.H:=B.Y+B.H+LimitSpacing(Size,12,0.1); Result.Baseline:=A.Baseline;
    end else begin
      B.Y:=-B.H-Max(LimitSpacing(Size,8,0.111111),LimitSpacing(Size,10,0.2)-Max(0,B.H-B.Baseline));
      A.Y:=-B.Y+LimitSpacing(Size,12,0.1); Inc(B.Y,A.Y);
      Result.H:=A.Y+A.H; Result.Baseline:=A.Y+A.Baseline;
    end;
    Result.Children.Add(A); Result.Children.Add(B);
    Result.HasInkMetric:=True; Result.InkAbove:=Result.Baseline; Result.InkBelow:=Result.H-Result.Baseline;
    Exit;
  end;
  if (Node.Kind=mkCommand) and (Command='\boxed') and (Node.Children.Count>0) and
     ((Info=nil) or (Info.PackageSource<>'') or (Info.Body='') or (Info.NativeName<>'')) then begin
    OldDisplay:=FDisplayMath; OldLevel:=FMathLevel; FDisplayMath:=True; FMathLevel:=0;
    try A:=MathBox(TMathNode(Node.Children[0]),MathFontSize(0));
    finally FDisplayMath:=OldDisplay; FMathLevel:=OldLevel; end;
    { amsmath boxed uses fbox with display style and the ordinary 3pt inset. }
    P:=Max(1,Round(3.4*FEmFactor));
    Result:=TDraftBox.Create; Result.Color:=FDefaultColor; Result.Shape:=15; Result.ID:=Node.ID; Result.Size:=Size;
    Result.AccentHeight:=Max(1,Round(0.4*FEmFactor)); Result.Color:=FDefaultColor;
    A.X:=P; A.Y:=P; Result.Children.Add(A);
    Result.W:=A.W+2*P; Result.H:=A.H+2*P; Result.Baseline:=A.Baseline+P;
    Result.HasInkMetric:=True; Result.InkAbove:=Result.Baseline; Result.InkBelow:=Result.H-Result.Baseline;
    Exit;
  end;
  if (Node.Kind=mkCommand) and IsNamedMathOperator(Command) and
     ((Info=nil) or (Info.PackageSource<>'') or (Info.Body='') or (Info.NativeName<>'')) then begin
    { amsopn qopname selects symoperators, independently of surrounding
      NFSS text declarations and of the previous paragraph's PDF anchors. }
    OldTextStyle:=FTextStyle; OldDepth:=FTextStyleDepth;
    OldFont:=FDefaultFont; OldStyle:=FDefaultStyle; OldHeight:=FDefaultHeight;
    FDefaultFont:='Latin Modern Roman'; FDefaultStyle:=[]; FDefaultHeight:=0;
    Inc(FTextStyleDepth);
    FTextStyle.Family:=FTextStyle.Roman; FTextStyle.Series:='m'; FTextStyle.Shape:='n';
    FTextStyle.Points:=MathFontPoints(FMathLevel);
    if (FBeamerTheme<>nil) and FBeamerTheme.Settings.Enabled and not FBeamerTheme.Settings.SerifMath then
      FTextStyle.Family:=FTextStyle.Sans;
    Formula:=TMathNode.Create(mkText,SymbolDisplay(Copy(Command,2,MaxInt)));
    Formula.ID:=-1;
    try Result:=TextBox(Formula,Size);
    finally
      Formula.Free; FTextStyle:=OldTextStyle; FTextStyleDepth:=OldDepth;
      FDefaultFont:=OldFont; FDefaultStyle:=OldStyle; FDefaultHeight:=OldHeight;
    end;
    Result.ID:=Node.ID; Result.CharCount:=UTF8Length(Node.Text);
    SetLength(Result.Stops,Result.CharCount+1); Result.Stops[0]:=0;
    for I:=1 to Result.CharCount do Result.Stops[I]:=Result.W;
    Exit;
  end;
  if (Node.Kind in [mkCommand,mkTextCommand]) and
     ((Command='\{') or (Command='\}') or (Command='\lbrace') or (Command='\rbrace')) and
     ((Info=nil) or (Info.PackageSource<>'')) then begin
    { fontmath.ltx declares math braces in the upright symbols family.
      Text-mode braces still go through TextSymbolBox and NFSS. }
    S:='lbrace'; if (Command='\}') or (Command='\rbrace') then S:='rbrace';
    Index:=ChooseTeXGlyph('math-symbol-'+IntToStr(MathFontPoints(FMathLevel))+'-'+S);
    if Index>=0 then begin
      Result:=MathGlyphBox(Index,Node.ID,Size,UTF8Length(Node.Text));
      Result.Text:='{'; if S='rbrace' then Result.Text:='}'; Exit;
    end;
  end;
  if (Node.Kind in [mkCommand,mkTextCommand]) and ((Info=nil) or (Info.PackageSource<>'')) then begin
    OldPoints:=FTextStyle.Points; if FMathLevel>0 then FTextStyle.Points:=MathFontPoints(FMathLevel);
    try Result:=TextSymbolBox(Node,Size); finally FTextStyle.Points:=OldPoints; end;
    if Result<>nil then Exit;
  end;
  if (Node.Kind=mkCommand) and ((Info=nil) or (Info.GlyphFont='')) and (TeXLargeOperator(Command) or (Command='\iint') or
    (Command='\iiint') or (Command='\iiiint')) and ((Info=nil) or (Info.PackageSource<>'') or (Info.NativeName<>'')) then begin
    S:=Copy(Command,2,MaxInt); if FDisplayMath then S:=S+'-display' else S:=S+'-text';
    Index:=ChooseTeXGlyph(S);
    if Index>=0 then begin
      Result:=MathGlyphBox(Index,Node.ID,Size,UTF8Length(Node.Text));
      Result.Text:=SymbolDisplay(Copy(Node.Text,2,MaxInt)); Exit;
    end;
  end;
  Result:=PackageGlyphBox(Node,Size,True); if Result<>nil then Exit;
  if (Node.Kind=mkCommand) and (Node.Children.Count=1) and
     ((S='\mathord') or (S='\mathop') or (S='\mathbin') or (S='\mathrel') or
      (S='\mathopen') or (S='\mathclose') or (S='\mathpunct') or (S='\mathinner')) then begin
    Result:=MathBox(TMathNode(Node.Children[0]),Size); Result.ID:=Node.ID; Exit;
  end;
  if (Node.Kind in [mkCommand,mkTextCommand]) and ReadHorizontalFill(Node.TeX,Fill) then begin
    Result:=Leaf('',Node.ID,Size,0); Result.Shape:=7; Result.HasInkMetric:=True;
    Result.GlueStretch:=Fill.Stretch; Result.GlueShrink:=Fill.Shrink;
    Result.StretchOrder:=Fill.Order; Result.ShrinkOrder:=Fill.ShrinkOrder;
    Result.KeepGlue:=Fill.Keep; Result.Leader:=Fill.Leader;
    Result.CharCount:=UTF8Length(Node.TeX); Exit;
  end;
  if (Node.Kind in [mkCommand,mkTextCommand]) and ReadMathSpace(Node.TeX,SpaceWidth,SpaceUnits) then begin
    Result:=Leaf('',Node.ID,Size,0); Result.Shape:=7;
    { latex.ltx defines quad/enskip with hskip and enspace with kern:
      their text-font dimensions stay fixed when the math style changes.
      Mu glue alone uses the current math symbol font. }
    if (Command='\enspace') or (Command='\enskip') then begin SpaceWidth:=0.5; SpaceUnits:='em'; end
    else if Command='\ ' then begin SpaceWidth:=1/3; SpaceUnits:='em'; end
    else if Command='\space' then SpaceWidth:=0;
    if SpaceUnits='mu' then begin Em:=MeasureEm(Size); SpaceWidth:=SpaceWidth/18; end
    else begin
      Em:=MeasureEm(FMathBaseSize);
      if SpaceUnits='ex' then SpaceWidth:=SpaceWidth*0.430556
      else if SpaceUnits='pt' then SpaceWidth:=SpaceWidth/MathFontPoints(0);
    end;
    Result.W:=Round(Em*SpaceWidth); Result.HasInkMetric:=True;
    Result.CharCount:=UTF8Length(Node.Text); Exit;
  end;
  Result:=NativeBox(Node,Size,True); if Result<>nil then Exit;
  Result:=ExpandedMacro(Node,Size); if Result<>nil then Exit;
  Result:=PackageBox(Node,Size); if Result<>nil then Exit;
  if Node.Text='\label' then begin
    if HideEditingMarks then Exit(TDraftBox.Create);
    Formula:=Node.Parent;
    if Formula<>nil then Formula:=Formula.Parent;
    Ch:=''; if (Formula<>nil) and (Formula.Kind=mkFormula) then begin
      if (Formula.Prefix='\[') or (Formula.Prefix='$$') then Ch:='equation'
      else if Pos('\begin{',Formula.Prefix)=1 then begin P:=7; Ch:=ReadTeXGroup(Formula.Prefix,P,'{','}'); Ch:=StringReplace(Ch,'*','',[]); end;
    end;
    if (Ch<>'equation') and (Ch<>'align') and (Ch<>'alignat') and (Ch<>'gather') and (Ch<>'eqnarray') then
      Exit(LabelBox(Node,Max(7,Round(Size*0.8))));
    Exit(TDraftBox.Create);
  end;
  if (Node.Text='\tag') or (Node.Text='\tag*') or
     (Node.Text='\notag') or (Node.Text='\nonumber') then Exit(TDraftBox.Create);
  if (Node.Kind=mkCommand) and ((Node.Text='\LaTeX') or (Node.Text='\TeX')) then Exit(LogoBox(Node,Size));
  if (Node.Kind=mkCommand) and ((Copy(Node.Text,1,5)='\text') or (Node.Text='\emph') or
     (Node.Text='\operatorname') or (Node.Text='\operatorname*')) then Exit(TextBox(Node,Size));
  P:=1; Ch:=ReadTeXCommand(Node.Text,P);
  if (Node.Kind=mkTextCommand) and IsLabelReference(Ch) then
  begin
    if Copy(Node.Text,P,1)='*' then Inc(P); S:=ReadTeXGroup(Node.Text,P,'{','}');
    if (Ch='crefrange') or (Ch='Crefrange') then S:=S+','+ReadTeXGroup(Node.Text,P,'{','}');
    if Context<>nil then S:=Context.ReferenceText(S,Ch) else S:='??';
    Result:=Leaf(S,Node.ID,Size,0); Result.CharCount:=UTF8Length(Node.Text); Exit;
  end;
  if (Node.Kind=mkCommand) and ((Pos('\math',Node.Text)=1) or (Node.Text='\bm') or (Node.Text='\boldsymbol')) and (Node.Children.Count>0) then
  begin
    SavedMathStyle:=FMathStyle; FMathStyle:=Node.Text;
    try
      A:=MathBox(TMathNode(Node.Children[0]),Size);
      Result:=TDraftBox.Create; Result.Color:=FDefaultColor; Result.ID:=Node.ID; Result.Children.Add(A);
      Result.W:=A.W; Result.H:=A.H; Result.Baseline:=A.Baseline;
    finally FMathStyle:=SavedMathStyle; end; Exit;
  end;
  if (Node.Kind=mkCommand) and (Node.Children.Count=1) and
     ((Node.Text='\overbrace') or (Node.Text='\underbrace')) then Exit(BraceBox(Node,Size));
  if (Node.Kind=mkCommand) and (Node.Children.Count=1) and
    ((Node.Text='\hat') or (Node.Text='\widehat') or (Node.Text='\reallywidehat') or (Node.Text='\bar') or (Node.Text='\overline') or
     (Node.Text='\underline') or (Node.Text='\vec') or (Node.Text='\dot') or (Node.Text='\ddot') or
     (Node.Text='\tilde') or (Node.Text='\widetilde') or (Node.Text='\breve') or (Node.Text='\check') or
     (Node.Text='\acute') or (Node.Text='\grave')) then
  begin
    A:=MathBox(TMathNode(Node.Children[0]),Size); Result:=TDraftBox.Create; Result.Color:=FDefaultColor;
    Result.Shape:=6; Result.Text:=Node.Text; Result.ID:=Node.ID; Result.Size:=Size;
    A.Y:=Max(0,Max(5,Min(12,A.W div 12))-InkTop(A));
    if (Node.Text='\hat') or (Node.Text='\widehat') or (Node.Text='\reallywidehat') then begin
      P:=Round(MeasureEm(Size)); Result.AccentVariant:=0;
      if (Node.Text='\widehat') or (Node.Text='\reallywidehat') then begin
        Result.AccentVariant:=1;
        if A.W>=P*1.03 then Result.AccentVariant:=2;
        if A.W>=P*1.48 then Result.AccentVariant:=3;
      end;
      case Result.AccentVariant of
        0:Result.AccentWidth:=Max(3,Round(P*0.30));
        1:Result.AccentWidth:=Max(3,Round(P*0.58));
        2:Result.AccentWidth:=Max(3,Round(P*1.03));
        3:Result.AccentWidth:=Max(3,Round(P*1.48));
      end;
      if Node.Text='\reallywidehat' then Result.AccentWidth:=Max(Result.AccentWidth,A.W);
      Result.AccentHeight:=Max(2,Round(P*0.19));
      A.Y:=Max(0,Result.AccentHeight+1-InkTop(A));
    end;
    if (Node.Text='\dot') or (Node.Text='\ddot') then begin
      Em:=MeasureEm(Size);
      Result.Glyph:=ChooseTeXGlyph(Copy(Node.Text,2,MaxInt));
      Result.AccentWidth:=Max(3,Round(Em*0.2)); Result.AccentHeight:=Max(2,Round(Em*0.1));
      if Result.Glyph>=0 then begin
        Result.AccentWidth:=Max(1,Round(TeXGlyphMetrics[Result.Glyph].W*Em));
        Result.AccentHeight:=Max(1,Round(TeXGlyphMetrics[Result.Glyph].H*Em));
        A.Y:=Max(0,Round((TeXGlyphMetrics[Result.Glyph].Above-0.430556)*Em)-InkTop(A));
      end;
      Result.LeftWidth:=Round(MathAccentSkew(SingleMathAtom(TMathNode(Node.Children[0])),FMathStyle)*Em);
    end;
    if Node.Text='\underline' then A.Y:=0;
    Result.W:=Max(8,A.W); Result.H:=A.H+A.Y;
    if Node.Text='\underline' then Inc(Result.H,4); Result.Baseline:=A.Baseline+A.Y;
    Result.HasInkMetric:=True;
    Result.InkAbove:=A.Baseline-InkTop(A);
    if Node.Text<>'\underline' then
      Inc(Result.InkAbove,Max(1,Result.AccentHeight)+1);
    Result.InkBelow:=Max(0,InkBottom(A)-A.Baseline);
    if Node.Text='\underline' then Inc(Result.InkBelow,4);
    Result.Children.Add(A); Exit;
  end;
  if (Node.Kind=mkEnvironment) and (Node.Children.Count=1) and
     ((Pos('matrix',Node.Text)>0) or (Pos('array',Node.Text)>0) or (Pos('cases',Node.Text)>0)) then
  begin
    OldDisplay:=FDisplayMath; FDisplayMath:=False;
    VisiblePrefix:='';
    if Node.Text='array' then begin
      P:=1; Ch:=ReadTeXCommand(Node.Prefix,P); Ch:=ReadTeXGroup(Node.Prefix,P,'{','}');
      SkipTeXSpace(Node.Prefix,P);
      if Copy(Node.Prefix,P,1)='[' then Ch:=ReadTeXGroup(Node.Prefix,P,'[',']');
      VisiblePrefix:=ReadTeXGroup(Node.Prefix,P,'{','}');
    end;
    OldLevel:=FMathLevel; P:=FMatrixGap;
    if Node.Text='smallmatrix' then begin
      FMathLevel:=1; FMatrixGap:=Round(MeasureEm(FMathBaseSize)*5/18);
    end else FMathLevel:=0;
    try A:=GridBox(TMathNode(Node.Children[0]),MathFontSize(FMathLevel),Pos('cases',Node.Text)=0,
      Pos('cases',Node.Text)>0,0,VisiblePrefix,Node.Text='smallmatrix');
    finally FMathLevel:=OldLevel; FMatrixGap:=P; FDisplayMath:=OldDisplay; end;
    if Node.Text='array' then begin
      for I:=0 to A.Children.Count-1 do Inc(TDraftBox(A.Children[I]).X,FMatrixGap div 2);
      Inc(A.W,FMatrixGap);
    end;
    S:='';
    if Node.Text='pmatrix' then S:='('+#1+')'
    else if Node.Text='bmatrix' then S:='['+#1+']'
    else if Node.Text='Bmatrix' then S:='\{'+#1+'\}'
    else if Node.Text='vmatrix' then S:='|'+#1+'|'
    else if Node.Text='Vmatrix' then S:='\|'+#1+'\|'
    else if Node.Text='cases' then S:='\{'+#1+'.';
    if S='' then Exit(A);
    I:=Pos(#1,S); Exit(DelimitedBox(A,Copy(S,1,I-1),Copy(S,I+1,MaxInt),Size,Node.ID));
  end;
  if (Node.Kind=mkEnvironment) and (Node.Text='gathered') and (Node.Children.Count=1) then
    Exit(GridBox(TMathNode(Node.Children[0]),Size,True,False,Round(MeasureEm(Size)*0.3)));
  if Node.Kind=mkRow then
    for I:=0 to Node.Children.Count-1 do
      if (TMathNode(Node.Children[I]).Kind=mkRaw) and
         ((TMathNode(Node.Children[I]).Text='&') or (Copy(TMathNode(Node.Children[I]).Text,1,2)='\\')) then
        Exit(GridBox(Node,Size,False));
  if Node.Kind=mkRow then Exit(SequenceBox(Node,0,Node.Children.Count-1,Size));
  if (Node.Kind=mkCommand) and (Node.Children.Count>0) and
     (IsExtensibleMathArrow(Copy(Node.Text,2,MaxInt)) or
      (Node.Text='\overrightarrow') or (Node.Text='\overleftarrow') or (Node.Text='\overleftrightarrow') or
      (Node.Text='\underrightarrow') or (Node.Text='\underleftarrow') or (Node.Text='\underleftrightarrow')) then begin
    Em:=MeasureEm(Size); Result:=TDraftBox.Create; Result.Color:=FDefaultColor; Result.ID:=Node.ID; Result.Size:=Size;
    ChildLevel:=Min(2,FMathLevel+1); OldLevel:=FMathLevel;
    if Copy(Node.Text,1,2)='\x' then FMathLevel:=ChildLevel;
    try
      A:=MathBox(TMathNode(Node.Children.Last),MathFontSize(FMathLevel)); B:=nil;
      if (Copy(Node.Text,1,2)='\x') and (Node.Children.Count>1) then B:=MathBox(TMathNode(Node.Children[0]),MathFontSize(FMathLevel));
    finally FMathLevel:=OldLevel; end;
    SpaceWidth:=Max(1.5,(A.W+Round(Em*0.6))/Em);
    if B<>nil then SpaceWidth:=Max(SpaceWidth,(B.W+Round(Em*0.6))/Em);
    if Copy(Node.Text,1,2)<>'\x' then SpaceWidth:=Max(0.8,A.W/Em);
    Index:=ChooseTeXGlyph('arrow-'+Copy(Node.Text,2,MaxInt),SpaceWidth);
    if Index<0 then begin A.Free; B.Free; Result.Free; Exit(DefinitionBox(Node,Size,FMathWidth)); end;
    Stack:=TDraftBox.Create; Stack.Shape:=8; Stack.Glyph:=Index; Stack.Size:=Size; Stack.Color:=FDefaultColor;
    Stack.W:=Round(SpaceWidth*Em); Stack.H:=Max(2,Round(TeXGlyphMetrics[Index].H*Em));
    Stack.Baseline:=Round(TeXGlyphMetrics[Index].Above*Em);
    Result.W:=Max(A.W,Stack.W); A.X:=(Result.W-A.W) div 2; Stack.X:=(Result.W-Stack.W) div 2;
    if Copy(Node.Text,1,6)='\under' then begin
      Stack.Y:=InkBottom(A)+Max(1,Round(Em*0.1)); Result.Baseline:=A.Baseline;
    end else begin
      Stack.Y:=0;
      if Copy(Node.Text,1,2)='\x' then begin
        Stack.Y:=InkBottom(A)+Max(1,Round(Em*0.1)); Result.Baseline:=Stack.Y+Stack.Baseline;
      end else begin A.Y:=Stack.H+Max(1,Round(Em*0.1))-InkTop(A); Result.Baseline:=A.Y+A.Baseline; end;
    end;
    Result.H:=Max(A.Y+A.H,Stack.Y+Stack.H); Result.Children.Add(A); Result.Children.Add(Stack);
    if B<>nil then begin B.X:=(Result.W-B.W) div 2; B.Y:=Result.Baseline+Round(Em*0.3)-InkTop(B); Result.H:=Max(Result.H,B.Y+B.H); Result.Children.Add(B); end;
    Result.HasInkMetric:=True; Result.InkAbove:=Result.Baseline; Result.InkBelow:=Result.H-Result.Baseline; Exit;
  end;
  if Node.Children.Count=0 then
  begin
    if Node.Kind=mkCommand then begin
      Index:=MathFontGlyph(Node.Text);
      if Index>=0 then begin
        Result:=MathGlyphBox(Index,Node.ID,Size,UTF8Length(Node.Text));
        Result.Text:=SymbolDisplay(Copy(Node.Text,2,MaxInt)); Exit;
      end;
    end;
    S:=Node.Text;
    if Node.Kind=mkText then
      for I:=Length(S) downto 1 do if S[I] in [' ',#9,#10,#13] then Delete(S,I,1);
    if Trim(S)='' then S:='';
    if (Length(S)>1) and (S[1]='\') then
    begin
      S:=SymbolDisplay(Copy(Node.Text,2,MaxInt));
      if S='' then S:=Node.Text;
    end;
    PlainText:=S;
    if (Node.Kind=mkText) and (S<>'') then begin
      Result:=MathTextBox(Node,Size); if Result<>nil then Exit;
    end;
    if (Node.Kind=mkText) and not (((FMathStyle='\mathbb') and (BlackboardFont<>'')) or ((FMathStyle='\mathscr') and (ScriptFont<>'')) or ((FMathStyle='\mathfrak') and (FrakturFont<>''))) then S:=StyledMath(S,FMathStyle);
    if S='-' then S:='−';
    if (Node.Kind=mkCommand) and (UTF8Length(S)=1) then begin
      P:=UTF8Pos(S,'αβγδεζηθικλμνξοπρςστυφχψω');
      if P>0 then S:=UnicodeToUTF8($1D6FC+P-1);
      if Node.Text='\vartheta' then S:=UnicodeToUTF8($1D717);
      if Node.Text='\varrho' then S:=UnicodeToUTF8($1D71A);
      if Node.Text='\varphi' then S:=UnicodeToUTF8($1D719);
      if Node.Text='\varpi' then S:=UnicodeToUTF8($1D71B);
    end;
    OldFont:=FDefaultFont; OldStyle:=FDefaultStyle; OldHeight:=FDefaultHeight;
    FDefaultFont:='Latin Modern Math'; FDefaultHeight:=0; FDefaultStyle:=[];
    if (FMathStyle<>'') and (Node.Kind=mkText) and (S<>'') and (S[1] in ['a'..'z','A'..'Z']) then
    begin FDefaultFont:='Latin Modern Roman'; FDefaultStyle:=[fsItalic]; end;
    if FMathStyle='\mathit' then begin FDefaultFont:='Latin Modern Roman'; FDefaultStyle:=[fsItalic]; end;
    if FMathStyle='\mathrm' then begin FDefaultFont:='Latin Modern Roman'; FDefaultStyle:=[]; end;
    if FMathStyle='\mathbf' then begin FDefaultFont:='Latin Modern Roman'; FDefaultStyle:=[fsBold]; end;
    if FMathStyle='\mathsf' then begin FDefaultFont:='Latin Modern Sans'; FDefaultStyle:=[]; end;
    if FMathStyle='\mathtt' then begin FDefaultFont:='Latin Modern Mono'; FDefaultStyle:=[]; end;
    if (FMathStyle='\mathbb') and (BlackboardFont<>'') then begin FDefaultFont:=BlackboardFont; FDefaultStyle:=[]; end;
    if (FMathStyle='\mathscr') and (ScriptFont<>'') then begin FDefaultFont:=ScriptFont; FDefaultStyle:=[]; end;
    if (FMathStyle='\mathfrak') and (FrakturFont<>'') then begin FDefaultFont:=FrakturFont; FDefaultStyle:=[]; end;
    if (FMathStyle='\bm') or (FMathStyle='\boldsymbol') then Include(FDefaultStyle,fsBold);
    FMathLeaf:=True;
    try
      if FDisplayMath and ((Node.Text='\sum') or (Node.Text='\prod') or (Node.Text='\int') or (Node.Text='\oint')) then
        Result:=Leaf(S,Node.ID,Size*3 div 2,0)
      else Result:=Leaf(S,Node.ID,Size,0);
    finally FMathLeaf:=False; end;
    if (Node.Kind=mkText) and (FMathStyle='') and (S<>PlainText) then begin Result.GlyphText:=S; Result.Text:=PlainText; end;
    if (Node.Kind=mkText) and MathInkMetrics(PlainText,FMathStyle,IH,IDep) then begin
      Em:=MeasureEm(Size); Result.HasInkMetric:=True;
      Result.InkAbove:=Round(IH*Em); Result.InkBelow:=Round(IDep*Em);
    end;
    if not Result.Cached and (Node.Kind=mkCommand) then
    begin
      Result.CharCount:=UTF8Length(Node.Text); SetLength(Result.Stops,Result.CharCount+1);
      Result.Stops[0]:=0;
      for Index:=1 to Result.CharCount do Result.Stops[Index]:=Result.W;
    end;
    if (Node.Kind=mkText) and ((Pos(' ',Node.Text)>0) or (Pos(#9,Node.Text)>0) or
       (Pos(#10,Node.Text)>0) or (Pos(#13,Node.Text)>0)) then
    begin
      Result.CharCount:=UTF8Length(Node.Text); SetLength(Result.Stops,Result.CharCount+1);
      Result.Stops[0]:=0; VisiblePrefix:='';
      for I:=1 to Result.CharCount do
      begin
        Ch:=UTF8Copy(Node.Text,I,1);
        if (Ch<>' ') and (Ch<>#9) and (Ch<>#10) and (Ch<>#13) then
          if Ch='-' then VisiblePrefix:=VisiblePrefix+#226#136#146 else VisiblePrefix:=VisiblePrefix+Ch;
        if Result.GlyphText<>'' then Result.Stops[I]:=TeXTextWidth(FCanvas,StyledMath(VisiblePrefix,''))
        else Result.Stops[I]:=TeXTextWidth(FCanvas,VisiblePrefix);
      end;
    end;
    FDefaultFont:=OldFont; FDefaultStyle:=OldStyle; FDefaultHeight:=OldHeight;
    if (Node.ID>=0) and IsEmptyMathArgument(Node) and not HideEditingMarks then
    begin Result.Shape:=3; Result.W:=Max(14,Size); Result.H:=Max(18,Size+4); Result.Baseline:=Result.H*4 div 5; Result.CharCount:=UTF8Length(Node.Text); end;
    Exit;
  end;
  if (Node.Kind=mkGroup) and ((Pos('\left',Node.Prefix)=1) or (Trim(Node.Prefix)='\lvert') or (Trim(Node.Prefix)='\lVert') or (Trim(Node.Prefix)='\langle')) then
  begin
    if Pos('\left',Node.Prefix)=1 then S:=Trim(Copy(Node.Prefix,6,MaxInt))+#1+Trim(Copy(Node.Suffix,7,MaxInt))
    else S:=Trim(Node.Prefix)+#1+Trim(Node.Suffix);
    A:=MathBox(TMathNode(Node.Children[0]),Size);
    I:=Pos(#1,S); Exit(DelimitedBox(A,Copy(S,1,I-1),Copy(S,I+1,MaxInt),Size,Node.ID,Pos('\left',Node.Prefix)=1));
  end;
  if IsStandaloneMathGroup(Node) and (Node.ID>=0) and not HideEditingMarks then
  begin
    Result:=TDraftBox.Create; Result.Color:=FDefaultColor; Result.Shape:=4; Result.ID:=Node.ID;
    A:=MathBox(TMathNode(Node.Children[0]),Size); A.X:=9; Result.Children.Add(A);
    Result.W:=A.W+18; Result.H:=A.H; Result.Baseline:=A.Baseline; Result.Size:=Size; Exit;
  end;
  Result:=TDraftBox.Create; Result.Color:=FDefaultColor;
  if (Node.Kind=mkCommand) and
     ((Node.Text='\binom') or (Node.Text='\dbinom') or (Node.Text='\tbinom')) and
     (Node.Children.Count=2) then
  begin
    Result.Shape:=5; Result.Text:='('+#1+')'; Result.Size:=Size; Result.ID:=Node.ID;
    ChildLevel:=FMathLevel;
    if ((not FDisplayMath) and (Node.Text<>'\dbinom')) or (Node.Text='\tbinom') then
      ChildLevel:=Min(2,FMathLevel+1);
    ChildSize:=MathFontSize(ChildLevel);
    OldDisplay:=FDisplayMath; OldLevel:=FMathLevel; FMathLevel:=ChildLevel; FDisplayMath:=False;
    try
      A:=MathBox(TMathNode(Node.Children[0]),ChildSize);
      B:=MathBox(TMathNode(Node.Children[1]),ChildSize);
    finally FDisplayMath:=OldDisplay; FMathLevel:=OldLevel; end;
    Result.W:=Max(A.W,B.W)+20;
    A.X:=(Result.W-A.W) div 2; A.Y:=2;
    B.X:=(Result.W-B.W) div 2;
    P:=Max(2,Round(MeasureEm(Size)*0.25));
    B.Y:=A.Y+A.H+P-InkTop(B);
    Result.H:=B.Y+B.H+2;
    Result.Baseline:=A.Y+A.H+P div 2+Round(MeasureEm(Size)*0.25);
    Stack:=TDraftBox.Create; Stack.X:=10; Stack.Y:=2;
    Stack.W:=Result.W-20; Stack.H:=Result.H-4; Stack.Baseline:=Result.Baseline-2;
    Dec(A.X,10); Dec(A.Y,2); Dec(B.X,10); Dec(B.Y,2);
    Stack.Children.Add(A); Stack.Children.Add(B); Result.Free;
    Stack.X:=0; Stack.Y:=0; Exit(DelimitedBox(Stack,'(',')',Size,Node.ID));
  end;
  if (Node.Kind=mkCommand) and
     ((Node.Text='\frac') or (Node.Text='\dfrac') or (Node.Text='\tfrac')) and
     (Node.Children.Count=2) then
  begin
    Result.Shape:=1; OldDisplay:=FDisplayMath; OldLevel:=FMathLevel;
    if (Node.Text='\dfrac') or (Node.Text='\tfrac') then Size:=FMathBaseSize;
    if Node.Text='\dfrac' then FDisplayMath:=True else if Node.Text='\tfrac' then FDisplayMath:=False;
    Em:=MeasureEm(Size); Axis:=Em*0.25; RuleThickness:=Em*0.04;
    if FDisplayMath then begin
      ChildLevel:=0; ShiftUp:=Round(Em*0.676508); ShiftDown:=Round(Em*0.685951); Clearance:=3*RuleThickness;
    end else begin
      if Node.Text='\tfrac' then ChildLevel:=1 else ChildLevel:=Min(2,FMathLevel+1);
      ShiftUp:=Round(Em*0.393732); ShiftDown:=Round(Em*0.344841); Clearance:=RuleThickness;
    end;
    ChildSize:=MathFontSize(ChildLevel); FMathLevel:=ChildLevel; FDisplayMath:=False;
    try
      A:=MathBox(TMathNode(Node.Children[0]),ChildSize);
      B:=MathBox(TMathNode(Node.Children[1]),ChildSize);
    finally FDisplayMath:=OldDisplay; FMathLevel:=OldLevel; end;
    ShiftUp:=Max(ShiftUp,Ceil(InkBottom(A)-A.Baseline+Axis+RuleThickness/2+Clearance));
    ShiftDown:=Max(ShiftDown,Ceil(B.Baseline-InkTop(B)-Axis+RuleThickness/2+Clearance));
    { The empty delimiters retain their 1.2pt width in every math style. }
    Result.ImagePadding:=Max(1,Round(MeasureEm(FMathBaseSize)*1.2/MathFontPoints(0)));
    Result.W:=Max(A.W,B.W)+2*Result.ImagePadding;
    A.X:=(Result.W-A.W) div 2; B.X:=(Result.W-B.W) div 2;
    A.Y:=-ShiftUp-A.Baseline; B.Y:=ShiftDown-B.Baseline;
    Result.Baseline:=Max(-A.Y,-B.Y); Inc(A.Y,Result.Baseline); Inc(B.Y,Result.Baseline);
    Result.RuleY:=Result.Baseline-Round(Axis); Result.H:=Max(A.Y+A.H,B.Y+B.H);
    Result.HasInkMetric:=True;
    Result.InkAbove:=ShiftUp+A.Baseline-InkTop(A); Result.InkBelow:=ShiftDown+InkBottom(B)-B.Baseline;
    Result.Children.Add(A); Result.Children.Add(B); Exit;
  end;
  if (Node.Kind=mkCommand) and (Node.Text='\sqrt') then
  begin
    Result.Shape:=2; Result.ID:=Node.ID; Result.Size:=Size;
    Index:=0; B:=nil;
    if (Node.Children.Count>1) and (TMathNode(Node.Children[0]).Prefix='[') then begin
      OldLevel:=FMathLevel; FMathLevel:=1;
      try B:=ScriptBox(TMathNode(Node.Children[0]),Size); finally FMathLevel:=OldLevel; end;
      Index:=1;
    end;
    if Index<Node.Children.Count then A:=MathBox(TMathNode(Node.Children[Index]),Size)
    else A:=Leaf('',Node.ID,Size,0);
    Em:=MeasureEm(Size);
    Clearance:=0.05*Em;
    if FDisplayMath then Clearance:=(0.04+0.430556/4)*Em;
    Result.Glyph:=ChooseTeXGlyph('radical',(InkBottom(A)-InkTop(A)+Clearance)/Em+0.04);
    P:=Max(4,Round(Em*0.8)); Result.AccentWidth:=P;
    Result.AccentHeight:=Max(1,Round(InkBottom(A)-InkTop(A)+Clearance+0.04*Em));
    if Result.Glyph>=0 then begin
      P:=Max(1,Round(TeXGlyphMetrics[Result.Glyph].Advance*Em));
      Result.AccentWidth:=Max(1,Round(TeXGlyphMetrics[Result.Glyph].W*Em));
      Result.AccentHeight:=Max(1,Round(TeXGlyphMetrics[Result.Glyph].H*Em));
    end;
    Result.RuleY:=0;
    if B<>nil then Result.RuleY:=Max(0,B.W-Round(P*0.6));
    { TeX's make_radical uses the font's depth, not a cropped image height. }
    Clearance:=Clearance+Max(0,TeXRadicalDepth(Result.Glyph)*Em-
      (InkBottom(A)-InkTop(A)+Clearance))/2;
    Result.Baseline:=A.Baseline-InkTop(A)+Round(Clearance+0.04*Em);
    A.X:=Result.RuleY+P; A.Y:=Result.Baseline-A.Baseline;
    Result.Children.Add(A); Result.W:=A.X+A.W+1;
    Result.H:=Max(Result.AccentHeight,A.Y+A.H);
    if B<>nil then begin
      B.X:=Max(0,Result.RuleY+Round(Em*0.07));
      B.Y:=Result.Baseline-Round(0.6*(2*Result.Baseline-Result.AccentHeight))-B.Baseline;
      Result.Children.Add(B);
    end;
    I:=Max(0,-A.Y); if B<>nil then I:=Max(I,-B.Y);
    Inc(A.Y,I); if B<>nil then Inc(B.Y,I);
    Inc(Result.Baseline,I); Inc(Result.H,I); Result.LeftWidth:=I;
    Result.HasInkMetric:=True; Result.InkAbove:=Result.Baseline-I;
    Result.InkBelow:=Max(I+Result.AccentHeight-Result.Baseline,InkBottom(A)-A.Baseline);
    Exit;
  end
  else if Node.Kind=mkCommand then
  begin
    S:=SymbolDisplay(Copy(Node.Text,2,MaxInt)); if S='' then S:=Node.Text;
    B:=Leaf(S,-1,Size,0); Result.Children.Add(B); Result.W:=B.W+3;
  end;
  Above:=0; Below:=0;
  for I:=0 to Node.Children.Count-1 do
  begin
    S:=TMathNode(Node.Children[I]).Prefix;
    if (S<>'') and (S[1] in ['^','_']) then
      B:=ScriptBox(TMathNode(Node.Children[I]),Size)
    else B:=MathBox(TMathNode(Node.Children[I]),Size);
    B.X:=Result.W; Inc(Result.W,B.W);
    B.Y:=-B.Baseline;
    if (S<>'') and (S[1]='^') then Dec(B.Y,Size div 2)
    else if (S<>'') and (S[1]='_') then Inc(B.Y,Size div 2);
    Above:=Max(Above,-B.Y); Below:=Max(Below,B.Y+B.H);
    Result.Children.Add(B);
  end;
  Result.Baseline:=Above; Result.H:=Max(1,Above+Below);
  for I:=0 to Result.Children.Count-1 do
  begin B:=TDraftBox(Result.Children[I]); Inc(B.Y,Above); end;
  finally
    if LocalMacros<>nil then begin FMacroScopes.Delete(FMacroScopes.Count-1); Macros:=OuterMacros; LocalMacros.Free; end;
  end;
end;
procedure TParagraphDraft.Layout(Canvas:TCanvas; Node:TMathNode; Width:Integer; Paragraph:Boolean; FontSize:Integer; Previous:TTeXLayout; const Source:string; Scale,PixelsPerEm:Double);
var X,Y,LineStart,Above,Below,LineBaseline,AnchorShift,AnchorLine,LeftIndent,RightIndent,HeadingHang,TextAlign,AlignDepth,ListDepth,FontIndex,FieldIndex,DisplayBelow,DisplayBottom,PreviousBaseline,PreviousDepth,VerticalGlue:Integer; Reflow,LastWasSpace,AfterDisplay,CaptionFlow,LabelFlow,DescriptionFlow,HeadingUppercase:Boolean; Standalone:TDraftBox; Sections:TSectionState; ParagraphLineStyle:TTeXTextStyle;
    WrapBottom,WrapLeft,WrapRight:Integer; IndentPending,AutoIndent,RunInPending,ExplicitHorizontal:Boolean; ParagraphIndent:Double;
    SavedMacros,WorkingMacros:TMacroRegistry; MacroScopes:TList;
    NativeNode:TMathNode; NativeCommand:string; NativeP:Integer; SourceIndex:TMathSourceIndex;
    Footnotes:array of record Box,Anchor:TDraftBox; Number:string; Marginal:Boolean; end;
    FootnoteNumber,NoteIndex:Integer; NoteBox,NoteMark:TDraftBox;
    MarginWidth,MarginSep,MarginPush,MarginEm,NativeEm:Double; MarginPage,MarginBottom:Integer; MarginLeft:Boolean;
  function NoteMarker(const Number:string; ID:Integer; Points:Double):TDraftBox;
  var Saved:TTeXTextStyle; SavedFont:string; SavedStyle:TFontStyles; SavedHeight,SavedHeading:Integer; Part:TDraftBox;
  begin
    Saved:=FTextStyle; SavedFont:=FDefaultFont; SavedStyle:=FDefaultStyle; SavedHeight:=FDefaultHeight; SavedHeading:=FHeadingSize;
    try
      FTextStyle.Family:=FTextStyle.Roman; FTextStyle.Series:='m'; FTextStyle.Shape:='n';
      FTextStyle.Points:=TextScriptPoints(Points,Directory); FDefaultFont:=ResolveTeXFont('CMR10');
      FDefaultStyle:=[]; FDefaultHeight:=0; FHeadingSize:=0;
      Part:=Leaf(Number,ID,Max(1,Round(FMathBaseSize*FTextStyle.Points/MathFontPoints(0))),0);
      Part.Anchored:=False;
      Result:=TDraftBox.Create; Result.Children.Add(Part); Result.W:=Part.W;
      { Raise the child, not the glyph's own baseline. Changing both height
        and baseline on a leaf otherwise leaves its ink on the body baseline. }
      Result.Baseline:=Part.Baseline+Round(MeasureEm(FMathBaseSize)*Points/MathFontPoints(0)*0.4);
      Result.H:=Max(Part.H,Result.Baseline); Result.Nonbreaking:=True; Result.InlineFlow:=True;
    finally FTextStyle:=Saved; FDefaultFont:=SavedFont; FDefaultStyle:=SavedStyle; FDefaultHeight:=SavedHeight; FHeadingSize:=SavedHeading; end;
  end;
  function BuildNote(Body:TMathNode; Target:Integer=0; Marginal:Boolean=False):TDraftBox;
  var NoteDraft:TParagraphDraft;
  begin
    if FNoteDepth>=8 then Exit(Leaf('[nested note]',Body.ID,Max(6,FontSize-2),0));
    NoteDraft:=TParagraphDraft.Create;
    try
      InheritDraft(NoteDraft); NoteDraft.FNoteDepth:=FNoteDepth+1;
      ApplyTextStyle(NoteDraft.TextStyleSeed,'\normalfont\normalsize',Directory);
      if not Marginal then ApplyTextStyle(NoteDraft.TextStyleSeed,'\footnotesize',Directory);
      NoteDraft.SourceBase:=MathSourceOffset(Body)-Length(Body.Prefix);
      if Target=0 then Target:=Width-55;
      NoteDraft.Layout(Canvas,Body,Target+20,True,FMathBaseSize,nil,Body.TeX,Scale,MeasureEm(FMathBaseSize));
      Result:=NoteDraft.DetachContent(Target); Result.H:=Max(1,Result.H);
    finally NoteDraft.Free; end;
  end;
  function NumberedHeading(N:TMathNode):Boolean;
  var P:Integer; Name:string;
  begin
    P:=1; Name:=ReadTeXCommand(N.Prefix,P);
    Result:=StepSection(Sections,SectionIndex(Name),Copy(N.Prefix,P,1)='*');
  end;
  function CJKLetter(B:TDraftBox):Boolean;
  begin
    Result:=(UTF8Length(B.Text)=1) and ContainsCJK(B.Text);
  end;
  procedure CJKGlue(const Style:TTeXTextStyle; Box:TDraftBox);
  begin
    TextCJKGlue(Style,Max(1,Width-20-LeftIndent-RightIndent)/FEmFactor,
      ParagraphIndent,Box.GlueStretch,Box.GlueShrink);
    Box.GlueStretch:=Box.GlueStretch*FEmFactor; Box.GlueShrink:=Box.GlueShrink*FEmFactor;
  end;
  procedure NativeLines;
  var Items:TTeXInlineItems; Lines:TTeXLines; I,J,K,Start,Finish,Base,Depth,AboveLine,Offset,Shift:Integer;
      B,Part:TDraftBox; Ratio,Advance,SkipHeight,ExactOffset:Double; NeedHyphens:Boolean; Points:THyphenPoints;
      WordText,OldFont:string; LineStyle:TTeXTextStyle; OldStyle:TFontStyles; OldHeight,P,Index,NarrowLines,HyphenGlyph:Integer;
    function MathGlueShift(Child:Integer):Double;
    var L,R,M:Integer;
    begin
      { Glue acts in source order: negative kerns may move a later child
        left of an earlier one without changing which glue precedes it. }
      L:=0; R:=Length(B.MathGlues);
      while L<R do begin
        M:=(L+R) div 2;
        if B.MathGlues[M].Child<=Child then L:=M+1 else R:=M;
      end;
      Result:=0; if L=0 then Exit;
      if Ratio>0 then Result:=Ratio*B.MathGlues[L-1].Stretch
      else Result:=Ratio*B.MathGlues[L-1].Shrink;
    end;
    procedure BuildItems;
    var I:Integer; B,Next:TDraftBox;
    begin
    SetLength(Items,FRoot.Children.Count-LineStart);
    for I:=0 to High(Items) do begin
      B:=TDraftBox(FRoot.Children[LineStart+I]); Items[I].Width:=B.W;
      Items[I].Glue:=(B.StretchOrder>0) or B.InterCharacterGlue or ((B.Text<>'') and (Trim(B.Text)='') and (B.Shape=0));
      Items[I].StretchOrder:=B.StretchOrder; Items[I].ShrinkOrder:=B.ShrinkOrder; Items[I].KeepGlue:=B.KeepGlue;
      if Items[I].Glue and (Items[I].StretchOrder=0) and not B.InterCharacterGlue and not B.Nonbreaking and
         (I>0) and (I<High(Items)) and CJKLetter(TDraftBox(FRoot.Children[LineStart+I-1])) and
         CJKLetter(TDraftBox(FRoot.Children[LineStart+I+1])) then begin
        { xeCJK's default CJKspace=false replaces even explicit source
          spaces/newlines between ideographs with CJKglue. }
        B.W:=Round(ParagraphLineStyle.CJKSpacing*MeasureEm(B.Size)); CJKGlue(ParagraphLineStyle,B);
        Items[I].Width:=B.W; B.InterCharacterGlue:=True;
      end;
      Items[I].Stretch:=B.GlueStretch; Items[I].Shrink:=B.GlueShrink;
      if Items[I].Glue and not (B.MathGlue or B.InterCharacterGlue) and
         not B.TextRun.Valid and (Items[I].Stretch=0) and (B.W>0) then begin Items[I].Stretch:=B.W/2; Items[I].Shrink:=B.W/3; end;
      Items[I].BreakAfter:=(Items[I].Glue or B.BreakAfter) and not B.Nonbreaking;
      Items[I].BreakWidth:=B.HyphenWidth; Items[I].Penalty:=B.BreakPenalty; if B.HyphenWidth>0 then Items[I].Penalty:=50;
      if B.BreakAfter and ContainsCJK(B.Text) and (I<High(Items)) then begin
        Next:=TDraftBox(FRoot.Children[LineStart+I+1]);
        if (Next.Text<>'') and (Pos(UTF8Copy(Next.Text,1,1),'，。！？、：；）》】」』')>0) then Items[I].BreakAfter:=False;
        if Pos(B.Text,'（【《「『')>0 then Items[I].BreakAfter:=False;
      end;
    end;
    end;
    procedure FindLines;
    var FullWidth,Count,First,K,L:Integer; Tail:TTeXLines;
    begin
      FullWidth:=Max(1,Width-20-LeftIndent-RightIndent-HeadingHang); NarrowLines:=0;
      if (WrapBottom>Y) and (WrapLeft+WrapRight>0) then
        NarrowLines:=Ceil((WrapBottom-Y)/Max(1,MeasureEm(FontSize)*1.2));
      Lines:=BreakTeXLines(Items,Max(1,FullWidth-Ord(NarrowLines>0)*(WrapLeft+WrapRight)),TextAlign<>0,HeadingHang);
      if (NarrowLines>0) and (Length(Lines)>NarrowLines) then begin
        First:=Lines[NarrowLines].First; Tail:=BreakTeXLines(Copy(Items,First,Length(Items)-First),FullWidth,TextAlign<>0);
        Count:=NarrowLines; SetLength(Lines,Count+Length(Tail));
        for K:=0 to High(Tail) do begin L:=Count+K; Lines[L]:=Tail[K]; Inc(Lines[L].First,First); Inc(Lines[L].Finish,First); end;
      end;
    end;
  begin
    BuildItems; FindLines;
    NeedHyphens:=False;
    for I:=0 to High(Lines) do if (Lines[I].Ratio>1.26) or (Lines[I].Ratio< -0.99) then NeedHyphens:=True;
    if NeedHyphens and (TextAlign=0) then begin
      for Index:=FRoot.Children.Count-1 downto LineStart do begin
        B:=TDraftBox(FRoot.Children[Index]); if not B.TextRun.Valid or (B.Shape<>0) or B.NoHyphenation then Continue;
        Points:=TeXHyphenPoints(B.Text); if Length(Points)=0 then Continue;
        WordText:=B.Text; OldFont:=FDefaultFont; OldStyle:=FDefaultStyle; OldHeight:=FDefaultHeight;
        FDefaultFont:=B.FontName; FDefaultStyle:=B.FontStyle; FDefaultHeight:=B.PixelHeight;
        FRoot.Children.Extract(B); P:=0; HyphenGlyph:=TextGlyph(B,45);
        try
          for J:=0 to Length(Points) do begin
            K:=Length(WordText); if J<Length(Points) then K:=Points[J];
            Part:=Leaf(Copy(WordText,P+1,K-P),B.ID,B.Size,B.FirstChar+P);
            Part.TextFont:=B.TextFont; Part.TextOutlineFont:=B.TextOutlineFont; Part.TextEm:=B.TextEm;
            Part.TextFeatures:=B.TextFeatures; ShapeTextBox(Part);
            if J<Length(Points) then begin
              Part.BreakAfter:=True;
              if HyphenGlyph>=0 then Part.HyphenWidth:=TeXGlyphMetrics[HyphenGlyph].Advance*B.TextEm
              else Part.HyphenWidth:=TeXFontMetric('cmr10').Chars[45].Width*B.TextEm;
            end;
            FRoot.Children.Insert(Index+J,Part); P:=K;
          end;
        finally B.Free; FDefaultFont:=OldFont; FDefaultStyle:=OldStyle; FDefaultHeight:=OldHeight; end;
      end;
      BuildItems; FindLines;
    end;
    SkipHeight:=MeasureEm(FMathBaseSize)/MathFontPoints(0); LineStyle:=ParagraphLineStyle;
    if FHeadingSize>0 then LineStyle:=FTextStyle;
    { TeX packages the paragraph after local text-command groups have closed.
      A forced line break inside such a group does not change its baseline glue. }
    for I:=0 to High(Lines) do begin
      Start:=Lines[I].First; Finish:=Lines[I].Finish;
      while (Start<Finish) and Items[Start].Glue and not Items[Start].KeepGlue and
        ((Start>0) or (Items[Start].StretchOrder=0)) do Inc(Start);
      while (Finish>Start) and Items[Finish-1].Glue and not Items[Finish-1].KeepGlue do Dec(Finish);
      AboveLine:=0; Depth:=0;
      for J:=Start to Finish-1 do begin
        B:=TDraftBox(FRoot.Children[LineStart+J]); AboveLine:=Max(AboveLine,B.Baseline-InkTop(B)); Depth:=Max(Depth,InkBottom(B)-B.Baseline);
      end;
      Base:=Y+AboveLine;
      if PreviousBaseline>=0 then begin
        Base:=PreviousBaseline+Round(TextBaselineDistance(LineStyle,PreviousDepth/SkipHeight,AboveLine/SkipHeight)*SkipHeight);
      end;
      Offset:=10+LeftIndent; if I<NarrowLines then Inc(Offset,WrapLeft);
      if I>0 then Inc(Offset,HeadingHang); Ratio:=Lines[I].Ratio;
      ExactOffset:=Offset;
      for J:=Lines[I].First to Lines[I].Finish-1 do begin
        B:=TDraftBox(FRoot.Children[LineStart+J]); B.Hyphenated:=False; B.X:=Round(ExactOffset); B.Y:=Base-B.Baseline;
        if Items[J].Glue then begin
          Advance:=0;
          if (J>=Start) and (J<Finish) then begin
            Advance:=Items[J].Width;
            if (Ratio>0) and (Items[J].StretchOrder=Lines[I].GlueOrder) then Advance:=Advance+Ratio*Items[J].Stretch
            else if (Ratio<0) and (Items[J].ShrinkOrder=Lines[I].GlueOrder) then Advance:=Advance+Ratio*Items[J].Shrink;
          end;
          if Lines[I].GlueOrder=0 then Advance:=Max(0,Advance);
          B.W:=Round(ExactOffset+Advance)-Round(ExactOffset);
          for K:=1 to High(B.Stops) do B.Stops[K]:=B.W;
        end else begin
          Advance:=B.W;
          if (Lines[I].GlueOrder=0) and (Length(B.MathGlues)>0) and ((B.GlueStretch>0) or (B.GlueShrink>0)) then begin
            if Ratio>0 then Advance:=Advance+Ratio*B.GlueStretch else Advance:=Advance+Ratio*B.GlueShrink;
            for K:=0 to B.Children.Count-1 do begin
              Part:=TDraftBox(B.Children[K]);
              Part.X:=Round(ExactOffset+Part.X+MathGlueShift(K))-B.X;
            end;
            B.W:=Round(ExactOffset+Advance)-B.X;
          end;
        end;
        { TeX accumulates glue before rounding device coordinates. Rounding
          each individual CJK gap can move the last word by many pixels. }
        ExactOffset:=ExactOffset+Advance; Offset:=Round(ExactOffset);
      end;
      if Lines[I].Hyphenated and (Finish>Start) then begin B:=TDraftBox(FRoot.Children[LineStart+Finish-1]); B.Hyphenated:=True; Inc(Offset,Round(B.HyphenWidth)); end;
      if TextAlign in [1,2] then begin
        Shift:=Max(0,Width-10-RightIndent-Ord(I<NarrowLines)*WrapRight-Offset); if TextAlign=1 then Shift:=Shift div 2;
        for J:=Lines[I].First to Lines[I].Finish-1 do Inc(TDraftBox(FRoot.Children[LineStart+J]).X,Shift);
      end;
      PreviousBaseline:=Base; PreviousDepth:=Depth; Y:=Base+Depth;
    end;
    if DescriptionFlow then begin Inc(LeftIndent,HeadingHang); HeadingHang:=0; end;
    X:=10+LeftIndent; LineStart:=FRoot.Children.Count; Above:=0; Below:=0; LineBaseline:=-1; LastWasSpace:=True;
  end;
  procedure NewLine;
  var I,Shift,EndX:Integer; B:TDraftBox; Em:Double;
  begin
    AnchorLine:=-1; ExplicitHorizontal:=False;
    if LineStart=FRoot.Children.Count then Exit;
    VerticalGlue:=0;
    if ((FLayout=nil) or Reflow) and not (TableCellLayout or CaptionFlow or HboxLayout) then begin NativeLines; Exit; end;
    if LineBaseline>=0 then LineBaseline:=Max(LineBaseline,Y+Above);
    for I:=LineStart to FRoot.Children.Count-1 do
    begin B:=TDraftBox(FRoot.Children[I]); if LineBaseline>=0 then B.Y:=LineBaseline-B.Baseline else B.Y:=Y+Above-B.Baseline; end;
    if TextAlign in [1,2] then begin
      EndX:=0;
      for I:=LineStart to FRoot.Children.Count-1 do begin B:=TDraftBox(FRoot.Children[I]); EndX:=Max(EndX,B.X+B.W); end;
      Shift:=Max(0,Width-10-EndX); if TextAlign=1 then Shift:=Shift div 2;
      for I:=LineStart to FRoot.Children.Count-1 do begin B:=TDraftBox(FRoot.Children[I]); Inc(B.X,Shift); end;
    end;
    if LineBaseline>=0 then Y:=LineBaseline-Above;
    if CaptionFlow or HboxLayout then Inc(Y,Above+Below)
    else if TableCellLayout then begin
      if DocumentFontSize=11 then Shift:=Round(MeasureEm(FontSize)*13.6/11)
      else if DocumentFontSize=12 then Shift:=Round(MeasureEm(FontSize)*14.5/12)
      else Shift:=Round(MeasureEm(FontSize)*1.2);
      Inc(Y,Max(Shift,Above+Below));
    end else begin
      Em:=MeasureEm(FMathBaseSize)/MathFontPoints(0);
      Inc(Y,Round(TextBaselineDistance(ParagraphLineStyle,Below/Em,Above/Em)*Em));
    end;
    X:=10+LeftIndent; LineStart:=FRoot.Children.Count;
    Above:=0; Below:=0; LineBaseline:=-1; LastWasSpace:=not HboxLayout;
  end;
  procedure EndDisplay;
  begin
    if not AfterDisplay then Exit;
    Y:=DisplayBottom+DisplayBelow;
    if PreviousBaseline>=0 then Inc(PreviousBaseline,DisplayBelow);
    AfterDisplay:=False;
  end;
  procedure VerticalSkip(Pixels:Integer);
  var Extra:Integer;
  begin
    { LaTeX's addvspace coalesces adjacent environment skips. }
    Extra:=Max(0,Pixels-VerticalGlue); Inc(Y,Extra);
    if PreviousBaseline>=0 then Inc(PreviousBaseline,Extra);
    VerticalGlue:=Max(VerticalGlue,Pixels);
  end;
  function EnvironmentSkip(N:TMathNode):Integer;
  var Top,Between:Double; P,Q,Breaks:Integer; VerticalStart:Boolean;
  begin
    TextListSpacing(FTextStyle,ListDepth,Directory,Top,Between);
    P:=MathSourceOffset(N)-Length(N.Prefix)-SourceBase; Breaks:=0;
    while (P>0) and (P<=Length(FSource)) and (FSource[P] in [' ',#9,#10,#13]) do begin
      if FSource[P]=#10 then Inc(Breaks); Dec(P);
    end;
    VerticalStart:=(P=0) or (Breaks>=2);
    if (P>0) and (FSource[P]='}') then begin
      Q:=P; while (Q>0) and not (FSource[Q] in ['{','\']) do Dec(Q);
      VerticalStart:=VerticalStart or ((Q>=5) and (Copy(FSource,Q-4,5)='\end{'));
    end;
    if VerticalStart then Top:=Top+TextListPartSkip(FTextStyle,ListDepth,Directory);
    Result:=Round(Top*MeasureEm(FMathBaseSize)/MathFontPoints(0));
  end;
  procedure Append(B:TDraftBox);
  var Desired,FitWidth,EndChar,RightEdge,I:Integer; Last,Glue:TDraftBox; LeftCJK,RightCJK:Boolean;
  begin
    if RunInPending and ((Trim(B.Text)<>'') or (B.Children.Count>0) or (B.Shape<>0)) then RunInPending:=False;
    if IndentPending and (((B.Text<>'') and (Trim(B.Text)<>'')) or (B.Children.Count>0) or
       ((B.W>0) and (B.Shape in [8,11]))) then begin
      IndentPending:=False;
      if AutoIndent and (FHeadingSize=0) and (ListDepth=0) and (TextAlign=0) and
         not CaptionFlow and not LabelFlow and (ParagraphIndent<>0) then begin
        Glue:=TDraftBox.Create; Glue.W:=Round(ParagraphIndent*MeasureEm(FMathBaseSize)/MathFontPoints(0));
        Glue.X:=X; Glue.Y:=Y; Glue.Nonbreaking:=True; Inc(X,Glue.W); FRoot.Children.Add(Glue);
      end;
    end;
    if ((FLayout=nil) or Reflow) and not (CaptionFlow or LabelFlow or TableCellLayout) and
       (FRoot.Children.Count>LineStart) then begin
      Last:=TDraftBox(FRoot.Children.Last); LeftCJK:=CJKLetter(Last); RightCJK:=CJKLetter(B);
      if (LeftCJK or RightCJK) and ((Last.Text<>'') or Last.InlineFlow) and
         ((B.Text<>'') or B.InlineFlow) and ((Last.Text='') or (Trim(Last.Text)<>'')) and
         ((B.Text='') or (Trim(B.Text)<>'')) and
         ((B.Text='') or (Pos(UTF8Copy(B.Text,1,1),',.;:!?)]}，。！？、：；）》】」』')=0)) and
         ((Last.Text='') or (Pos(UTF8Copy(Last.Text,UTF8Length(Last.Text),1),'([{（【《「『')=0)) then begin
        if LeftCJK and RightCJK then begin
          Glue:=TDraftBox.Create; Glue.Size:=B.Size;
          Glue.W:=Round(FTextStyle.CJKSpacing*MeasureEm(B.Size)); CJKGlue(FTextStyle,Glue);
        end else Glue:=Leaf(' ',-1,B.Size,0);
        Glue.Text:=''; Glue.InterCharacterGlue:=True; Glue.Stops:=nil; Glue.CharCount:=0;
        Last.BreakAfter:=False; Glue.BreakAfter:=True;
        Glue.X:=X; Inc(X,Glue.W); FRoot.Children.Add(Glue);
      end;
    end;
    if CaptionFlow or LabelFlow or TableCellLayout then B.Anchored:=False;
    if B.Anchored and not Reflow then
    begin
      Desired:=B.Anchor.Top+B.Baseline+AnchorShift;
      if (AnchorLine>=0) and (B.Anchor.Top+B.Baseline>AnchorLine+Max(5,B.H div 2)) then
      NewLine;
      if LineBaseline<0 then begin LineBaseline:=Max(Y+B.Baseline,Desired); Y:=LineBaseline-B.Baseline; end;
      if (FLayout<>nil) and (FSource<>FLayout.Source) and not B.Cached then Reflow:=True;
      if (AlignDepth=0) and ((LineStart=FRoot.Children.Count) or (not Reflow and not B.InlineFlow)) then
        X:=Max(X,B.Anchor.Left);
      AnchorLine:=B.Anchor.Top+B.Baseline;
    end;
    FitWidth:=B.W; EndChar:=UTF8Length(TrimRight(B.Text));
    if (EndChar<UTF8Length(B.Text)) and (EndChar<Length(B.Stops)) then FitWidth:=B.Stops[EndChar];
    RightEdge:=Width-10;
    if (FLayout<>nil) and (Length(FLayout.Anchors)>0) then RightEdge:=Width;
    if not (LabelFlow or HboxLayout) and (((FLayout<>nil) and not Reflow) or TableCellLayout or CaptionFlow) and (X>10) and (X+FitWidth>RightEdge) then
    begin
      NewLine;
      if B.Anchored and not Reflow then
      begin
        AnchorShift:=Max(AnchorShift,Y+B.Baseline-B.Anchor.Top-B.Baseline);
        LineBaseline:=B.Anchor.Top+B.Baseline+AnchorShift;
      end;
    end;
    if not HboxLayout and (X=10) and (Trim(B.Text)='') and (B.Text<>'') then begin B.W:=0; B.Text:=''; for I:=0 to High(B.Stops) do B.Stops[I]:=0; end;
    if (B.Text<>'') and (Trim(B.Text)='') and LastWasSpace then
    begin B.W:=0; for I:=0 to High(B.Stops) do B.Stops[I]:=0; end;
    if B.Text<>'' then LastWasSpace:=B.Text[Length(B.Text)] in [' ',#9,#10,#13]
    else if (B.Children.Count>0) or (B.W>0) or B.Cached then LastWasSpace:=False;
    B.X:=X; Inc(X,B.W);
    if TableCellLayout or HboxLayout then begin Above:=Max(Above,B.Baseline-InkTop(B)); Below:=Max(Below,InkBottom(B)-B.Baseline); end
    else begin Above:=Max(Above,B.Baseline); Below:=Max(Below,B.H-B.Baseline); end;
    FRoot.Children.Add(B);
  end;
  procedure AppendInsertion(B:TDraftBox);
  var Last:TDraftBox;
  begin
    if (LineStart=FRoot.Children.Count) and (LineStart>0) then begin
      Last:=TDraftBox(FRoot.Children.Last);
      if not (Last.Shape in [9,10]) and not AfterDisplay then begin
        B.X:=Last.X+Last.W; B.Y:=Last.Y+Last.Baseline-B.Baseline;
        FRoot.Children.Add(B); LineStart:=FRoot.Children.Count; Exit;
      end;
    end;
    Append(B);
  end;
  procedure AppendInlineFormula(Box:TDraftBox);
  var I,J,K,GlueIndex,ChildStart,ChildEnd,LeadingChild,Start,Finish,Leading,Above,Depth:Integer; Part,Child,Glue:TDraftBox;
  begin
    if ((FLayout<>nil) and not Reflow) or CaptionFlow or TableCellLayout or
       (Box.Shape<>0) or ((Length(Box.MathBreaks)=0) and (Length(Box.MathGlues)=0)) then begin Append(Box); Exit; end;
    Start:=0; GlueIndex:=0; ChildEnd:=0;
    try
      for I:=0 to Length(Box.MathBreaks) do begin
        Finish:=Box.W; if I<Length(Box.MathBreaks) then Finish:=Box.MathBreaks[I].Offset;
        Part:=TDraftBox.Create; Part.ID:=Box.ID; Part.Size:=Box.Size; Part.InlineFlow:=True;
        Leading:=Finish; Above:=0; Depth:=0; ChildStart:=ChildEnd; LeadingChild:=ChildEnd;
        while Box.Children.Count>0 do begin
          Child:=TDraftBox(Box.Children[0]);
          if (I<Length(Box.MathBreaks)) and ((Child.X>Finish) or ((Child.X=Finish) and (Child.W>0))) then Break;
          Box.Children.Extract(Child); Part.Children.Add(Child);
          if (Child.W>0) and (Child.X<=Leading) then begin Leading:=Child.X; LeadingChild:=ChildEnd; end;
          Inc(ChildEnd);
          Dec(Child.Y,Box.Baseline);
          Above:=Max(Above,-Child.Y-InkTop(Child)); Depth:=Max(Depth,Child.Y+InkBottom(Child));
        end;
        if I=0 then Leading:=Start;
        if Leading>Start then begin
          { Math glue following a break penalty is discarded at the start
            of the next line, just like TeX's post_line_break routine. }
          Glue:=TDraftBox.Create; Glue.W:=Leading-Start; Glue.Size:=Box.Size;
          Glue.InterCharacterGlue:=True; Glue.Nonbreaking:=True; Glue.MathGlue:=True;
          while (GlueIndex<Length(Box.MathGlues)) and (Box.MathGlues[GlueIndex].Child<=LeadingChild) and
                (Box.MathGlues[GlueIndex].Offset<=Leading) do begin
            Glue.GlueStretch:=Glue.GlueStretch+Box.MathGlues[GlueIndex].Stretch;
            Glue.GlueShrink:=Glue.GlueShrink+Box.MathGlues[GlueIndex].Shrink; Inc(GlueIndex);
          end;
          Append(Glue);
        end;
        while (GlueIndex<Length(Box.MathGlues)) and (Box.MathGlues[GlueIndex].Child<ChildEnd) do begin
          K:=Length(Part.MathGlues); SetLength(Part.MathGlues,K+1);
          Part.MathGlues[K].Offset:=Box.MathGlues[GlueIndex].Offset-Leading;
          Part.MathGlues[K].Child:=Box.MathGlues[GlueIndex].Child-ChildStart;
          Part.GlueStretch:=Part.GlueStretch+Box.MathGlues[GlueIndex].Stretch;
          Part.GlueShrink:=Part.GlueShrink+Box.MathGlues[GlueIndex].Shrink;
          Part.MathGlues[K].Stretch:=Part.GlueStretch; Part.MathGlues[K].Shrink:=Part.GlueShrink;
          Inc(GlueIndex);
        end;
        Part.W:=Max(0,Finish-Leading); Part.Baseline:=Above; Part.H:=Max(1,Above+Depth);
        if Length(Box.MathBreaks)=0 then Part.W:=Finish-Leading;
        Part.HasInkMetric:=True; Part.InkAbove:=Above; Part.InkBelow:=Depth;
        for J:=0 to Part.Children.Count-1 do begin
          Child:=TDraftBox(Part.Children[J]); Dec(Child.X,Leading);
          if Child.W=0 then Child.X:=Max(0,Child.X);
          Inc(Child.Y,Above);
        end;
        Part.BreakAfter:=I<Length(Box.MathBreaks);
        if Part.BreakAfter then Part.BreakPenalty:=Box.MathBreaks[I].Penalty;
        Append(Part); Start:=Finish;
      end;
    finally Box.Free; end;
  end;
  function SavedSpace(ID,DefaultWidth:Integer):Integer;
  var Index,I,J,Trailing,Distance,Best,Width:Integer; SourceText,Tail:string;
  begin
    Result:=DefaultWidth; if (FLayout=nil) or CaptionFlow or TableCellLayout then Exit;
    Index:=AnchorFor(ID); Best:=MaxInt;
    for I:=0 to High(FLayout.Anchors) do
    begin
      if FLayout.Anchors[I].IsContainer then Continue;
      SourceText:=Copy(FLayout.Source,FLayout.Anchors[I].SourceStart+1,FLayout.Anchors[I].SourceLength);
      Tail:=Copy(SourceText,Length(TrimRight(SourceText))+1,MaxInt);
      if (Tail='') or (Pos(#10,Tail)>0) or (Pos(#13,Tail)>0) then Continue;
      Trailing:=UTF8Length(Tail); J:=FLayout.Anchors[I].CharCount;
      if (J<Trailing) or (J>=Length(FLayout.Anchors[I].Stops)) then Continue;
      Width:=Round((FLayout.Anchors[I].Stops[J]-FLayout.Anchors[I].Stops[J-Trailing])*FScale);
      if Width<=0 then Continue;
      Distance:=Abs(I-Index); if Index<0 then Distance:=I;
      if Distance<Best then begin Best:=Distance; Result:=Width; end;
    end;
  end;
  procedure Prose(N:TMathNode; Size:Integer);
  var P,A,I,First,Index,Last,SavedHeight,Breaks,EndChar,Gap,J,K,Q,Character:Integer;
      S,T,Part,SavedFont:string; B:TDraftBox; SavedStyle:TFontStyles; SavedColor:TColor; CJK:Boolean;
    procedure WordBox(const WordText:string; CharOffset:Integer; Ideograph:Boolean=False);
    var Part:TDraftBox; I:Integer;
    begin
      Part:=Leaf(WordText,N.ID,Size,CharOffset);
      if CharOffset>0 then Part.Anchored:=False;
      if (Part.W>Width-20) and not LabelFlow and not Part.TextRun.Valid then begin
        Part.Free;
        for I:=1 to UTF8Length(WordText) do begin
          Part:=Leaf(UTF8Copy(WordText,I,1),N.ID,Size,CharOffset+I-1);
          Part.Anchored:=False; Part.BreakAfter:=True; Append(Part);
        end;
      end else begin
        Part.BreakAfter:=Ideograph or ((WordText<>'') and (WordText[Length(WordText)]='-'));
        Append(Part);
      end;
    end;
  begin
    SavedFont:=FDefaultFont; SavedStyle:=FDefaultStyle; SavedHeight:=FDefaultHeight; SavedColor:=FDefaultColor;
    try
    S:=N.Text; if S='~' then S:=' ';

    { TeX ignores source whitespace in vertical mode. Retain an insertion
      marker between environments without making an extra line of text. }
    if not HboxLayout and (S<>'') and (Trim(S)='') and (LineStart=FRoot.Children.Count) then begin
      B:=Leaf('',N.ID,Size,0); B.CharCount:=UTF8Length(S); SetLength(B.Stops,B.CharCount+1);
      B.X:=X; B.Y:=Y;
      if FRoot.Children.Count>0 then begin
        B.X:=TDraftBox(FRoot.Children.Last).X+TDraftBox(FRoot.Children.Last).W;
        B.Y:=TDraftBox(FRoot.Children.Last).Y+TDraftBox(FRoot.Children.Last).Baseline-B.Baseline;
      end;
      FRoot.Children.Add(B); LineStart:=FRoot.Children.Count; Exit;
    end;
    if Trim(S)<>'' then EndDisplay;

    if not HboxLayout and (Trim(S)='') and (Trim(Copy(FSource,MathSourceOffset(N)-SourceBase+1,MaxInt))='') and
       (FRoot.Children.Count>0) then begin
      B:=Leaf('',N.ID,Size,0); B.CharCount:=UTF8Length(S); SetLength(B.Stops,B.CharCount+1);
      B.X:=TDraftBox(FRoot.Children.Last).X+TDraftBox(FRoot.Children.Last).W;
      B.Y:=TDraftBox(FRoot.Children.Last).Y+TDraftBox(FRoot.Children.Last).Baseline-B.Baseline;
      if LineStart=FRoot.Children.Count then Inc(LineStart);
      FRoot.Children.Add(B); Exit;
    end;

    Index:=AnchorFor(N.ID);
    if (Index>=0) and (FTextStyleDepth=0) and not DescriptionFlow then
    begin
      FDefaultFont:=FLayout.Anchors[Index].FontName;
      FDefaultStyle:=FDefaultStyle+FLayout.Anchors[Index].Style; FDefaultColor:=FLayout.Anchors[Index].Color;
      FDefaultHeight:=Max(1,Round(FLayout.Anchors[Index].FontHeight*FScale));
    end;
    if not Reflow and (FTextStyleDepth=0) and not DescriptionFlow and not CaptionFlow and not TableCellLayout and (Index>=0) and (FDefaultStyle=FLayout.Anchors[Index].Style) and (Round((FLayout.Anchors[Index].Bounds.Right-FLayout.Anchors[Index].Bounds.Left)*FScale)<=Width-20) and (S=Copy(FLayout.Source,FLayout.Anchors[Index].SourceStart+1,FLayout.Anchors[Index].SourceLength)) then
    begin
      Last:=Index;
      while (Last<=High(FLayout.Anchors)) and (FLayout.Anchors[Last].ID=FLayout.Anchors[Index].ID) do
      begin
        B:=Leaf(FLayout.Anchors[Last].Text,N.ID,Size,FLayout.Anchors[Last].FirstChar);
        StyleBox(B,Last); if Reflow then B.Anchored:=False; B.Cached:=True; B.ImageBounds:=FLayout.Anchors[Last].Bounds;
        B.W:=B.Anchor.Right-B.Anchor.Left; B.H:=B.Anchor.Bottom-B.Anchor.Top; B.Baseline:=B.H*4 div 5;
        B.CharCount:=FLayout.Anchors[Last].CharCount; B.Stops:=Copy(FLayout.Anchors[Last].Stops);
        for I:=0 to High(B.Stops) do B.Stops[I]:=Round(B.Stops[I]*FScale);
        { Glue belongs to the advance, not to the cached picture. A tall
          delimiter in the next formula can overlap the prose line's font
          rectangle and must never be copied with the preceding word. }
        if FLayout.Anchors[Last].InkRight>B.ImageBounds.Left then
          B.ImageBounds.Right:=Min(B.ImageBounds.Right,FLayout.Anchors[Last].InkRight);
        B.ImageWidth:=Round((B.ImageBounds.Right-B.ImageBounds.Left)*FScale);
        { A compiled line-end has no glue. Reflow may put the next word on
          this line, so restore its space without stretching the cached ink. }
        EndChar:=UTF8Length(TrimRight(B.Text));
        if (EndChar<UTF8Length(B.Text)) and (EndChar<High(B.Stops)) and
           (B.Stops[High(B.Stops)]=B.Stops[EndChar]) then begin
          Gap:=SavedSpace(N.ID,TeXTextWidth(FCanvas,' '));
          Inc(B.W,Gap);
          for I:=EndChar+1 to High(B.Stops) do Inc(B.Stops[I],Gap);
        end;
        Append(B); Inc(Last);
      end;
      Exit;
    end;
    if S='' then begin
      B:=Leaf('',N.ID,Size,0);
      AppendInsertion(B);
      Exit;
    end;
    P:=1; First:=0;
    while P<=Length(S) do
    begin
      A:=P;
      if S[P] in [' ',#9,#10,#13] then
      begin
        Breaks:=0;
        while (P<=Length(S)) and (S[P] in [' ',#9,#10,#13]) do begin
          if S[P]=#10 then Inc(Breaks); Inc(P);
        end;
        if (Breaks>=2) and not (RunInPending or HboxLayout) then begin
          { The stored separator has source positions but no extra visible line.
            Keep its insertion stops beside the final content. }
          if MathSourceOffset(N)-SourceBase+P-1<Length(FSource) then begin NewLine; IndentPending:=True; end;
          B:=Leaf('',N.ID,Size,First); B.CharCount:=P-A; SetLength(B.Stops,B.CharCount+1);
          AppendInsertion(B);
          Inc(First,P-A); Continue;
        end;
        B:=Leaf(' ',N.ID,Size,First); if not Reflow then B.W:=SavedSpace(N.ID,B.W);
        B.Nonbreaking:=N.Text='~';
        B.Anchored:=False; B.CharCount:=P-A; SetLength(B.Stops,B.CharCount+1); B.Stops[0]:=0;
        for I:=1 to B.CharCount do B.Stops[I]:=B.W;
        Append(B); Inc(First,P-A); Continue;
      end;
      while (P<=Length(S)) and not (S[P] in [' ',#9,#10,#13]) do Inc(P);
      T:=Copy(S,A,P-A); if HeadingUppercase then T:=UTF8UpperCase(T);
      if ContainsCJK(T) then begin
        { xeCJK inserts glue at script boundaries, while the Latin run still
          goes through the font's ligature and kern program as a whole. }
        J:=1; Character:=First;
        while J<=Length(T) do begin
          K:=J; CJK:=CJKCodePoint(NextUTF8CodePoint(T,J));
          if not CJK then while J<=Length(T) do begin
            Q:=J; if CJKCodePoint(NextUTF8CodePoint(T,Q)) then Break; J:=Q;
          end;
          Part:=Copy(T,K,J-K); WordBox(Part,Character,CJK); Inc(Character,UTF8Length(Part));
        end;
        Inc(First,UTF8Length(T)); Continue;
      end;
      WordBox(T,First);
      Inc(First,UTF8Length(Copy(S,A,P-A)));
    end;
    finally FDefaultFont:=SavedFont; FDefaultStyle:=SavedStyle; FDefaultHeight:=SavedHeight; FDefaultColor:=SavedColor; end;
  end;
  procedure Walk(N:TMathNode; Size:Integer); forward;
  procedure WalkContent(N:TMathNode; Size:Integer);
  var I,Index,OldHeight,SavedIndent,ItemNumber,J,SavedAlign,DisplayAbove,EnvironmentSpace,LastLineRight,CaptionFirst,CaptionX,CaptionY:Integer; S,OldFont:string; OldStyle:TFontStyles; OldColor:TColor; Heading,AMSDisplay,ShortDisplay:Boolean; Child:TMathNode; Decoration:TDraftBox; Info:TTheoremInfo; Mark:TContextMark; P:Integer; Cmd,Key:string; Em,TopPoints,BetweenPoints:Double; Citation:TCitationSource; LinkBox:TDraftBox;
      OuterScope,LocalScope:TMacroRegistry; ListOptions:TNativeListOptions; ItemSkipPoints,ParagraphSkipPoints:Double;
      HeadingFormat:THeadingFormat; HeadingStyle:THeadingStyle; HeadingName,BeforeHeading,AfterHeading:string;
      OldRight,OldHang,HeadingStart,Separator,OldHeadingSize:Integer; OldUppercase:Boolean; OldHeadingPoints:Double;
      OldTextDepth:Integer; FormatName:string; OldTextStyle:TTeXTextStyle; Declaration,Horizontal:Boolean;
      Slide,Slides,Pause:Integer; Overlay:TBeamerOverlay; ItemState:TBeamerNodeState;
      Expanded,BraceNode,PreviewNode:TMathNode; FontSwitch:TMacroInfo; OldMarks:Boolean; Fill:TTeXFill; SpaceWidth:Double;
    procedure GrayBrace(const Value:string);
    begin
      if HideEditingMarks then Exit;
      BraceNode:=TMathNode.Create(mkTextCommand,'\'+Value);
      try
        BraceNode.ID:=N.ID; Decoration:=TextSymbolBox(BraceNode,Size);
        if Decoration<>nil then begin Decoration.Color:=clGray; Decoration.Anchored:=False; Append(Decoration); end;
      finally BraceNode.Free; end;
    end;
    procedure ApplyDeclaration(const Value:string);
    begin
      ApplyTextStyle(FTextStyle,Value,Directory); Inc(FTextStyleDepth); Declaration:=True;
      FDefaultHeight:=0; FDefaultStyle:=[]; FDefaultFont:='Latin Modern Roman';
      if FTextStyle.Family=FTextStyle.Sans then FDefaultFont:='Latin Modern Sans'
      else if FTextStyle.Family=FTextStyle.Mono then FDefaultFont:='Latin Modern Mono';
    end;
    function DescriptionLabel(LabelNode:TMathNode):TDraftBox;
    var Start,LabelX,LabelAbove,LabelBelow,LabelDepth,LabelHeight:Integer;
        Part:TDraftBox; LabelStyle:TTeXTextStyle; LabelFont:string; LabelFontStyle:TFontStyles;
        WasLabelFlow,WasSpace:Boolean;
    begin
      Result:=TDraftBox.Create; Result.Nonbreaking:=True; Result.HasInkMetric:=True;
      Start:=FRoot.Children.Count; LabelX:=X;
      LabelStyle:=FTextStyle; LabelDepth:=FTextStyleDepth; LabelFont:=FDefaultFont;
      LabelFontStyle:=FDefaultStyle; LabelHeight:=FDefaultHeight; WasLabelFlow:=LabelFlow; WasSpace:=LastWasSpace;
      ApplyTextStyle(FTextStyle,'\normalfont\bfseries',Directory); Inc(FTextStyleDepth);
      FDefaultFont:='Latin Modern Roman'; FDefaultStyle:=[fsBold]; FDefaultHeight:=0;
      LabelFlow:=True; LastWasSpace:=True;
      try
        Walk(LabelNode,Size);
        LabelAbove:=0; LabelBelow:=0;
        while FRoot.Children.Count>Start do begin
          Part:=TDraftBox(FRoot.Children[Start]); FRoot.Children.Extract(Part);
          Part.X:=Result.W; Inc(Result.W,Part.W); Result.Baseline:=Max(Result.Baseline,Part.Baseline);
          LabelAbove:=Max(LabelAbove,Part.Baseline-InkTop(Part)); LabelBelow:=Max(LabelBelow,InkBottom(Part)-Part.Baseline);
          Result.Children.Add(Part);
        end;
        Result.InkAbove:=LabelAbove; Result.InkBelow:=LabelBelow; Result.H:=Result.Baseline+LabelBelow;
        for Start:=0 to Result.Children.Count-1 do begin
          Part:=TDraftBox(Result.Children[Start]); Part.Y:=Result.Baseline-Part.Baseline;
        end;
      finally
        FTextStyle:=LabelStyle; FTextStyleDepth:=LabelDepth; FDefaultFont:=LabelFont;
        FDefaultStyle:=LabelFontStyle; FDefaultHeight:=LabelHeight; LabelFlow:=WasLabelFlow; LastWasSpace:=WasSpace;
        X:=LabelX; LineStart:=Min(LineStart,FRoot.Children.Count);
      end;
    end;
    procedure DescriptionList;
    var Body,Item,Part:TMathNode; LabelBox,Gap:TDraftBox;
        K,L,M,Count,Indent,Hang,Alignment,ItemSkip,TopSkip,MarginPixels:Integer; PointPixels,ListEm,Margin,TopPoints,BetweenPoints:Double; WasReflow,WasDescription:Boolean;
    begin
      EndDisplay; NewLine; TopSkip:=EnvironmentSkip(N); Indent:=LeftIndent; Hang:=HeadingHang; Alignment:=TextAlign; WasReflow:=Reflow; WasDescription:=DescriptionFlow;
      TextAlign:=0; Reflow:=True; DescriptionFlow:=True;
      PointPixels:=MeasureEm(FMathBaseSize)/MathFontPoints(0); ListEm:=PointPixels*FTextStyle.Points;
      { article/report/book: description has labelwidth=0 and itemindent=-leftmargin.
        Its label is a normalfont/bfseries hbox; ltlists.dtx adds labelsep after it.
        Continuation lines use leftmargini (2.5em) and the size*.clo list skips. }
      case ListDepth of 0:Margin:=2.5; 1:Margin:=2.2; 2:Margin:=1.87; else Margin:=1.7; end;
      if (ListDepth=0) and (Pos('twocolumn',HeadingContext)>0) then Margin:=2;
      MarginPixels:=Round(Margin*ListEm); HeadingHang:=MarginPixels;
      TextListSpacing(FTextStyle,ListDepth,Directory,TopPoints,BetweenPoints,@ItemSkipPoints,@ParagraphSkipPoints);
      ListOptions:=NativeListOptions(HeadingContext,N.TeX,N.Text,ListDepth);
      if ListOptions.TopSep<>'' then TopSkip:=DraftDimension(ListOptions.TopSep,ListEm,Width,TopSkip,PointPixels);
      if ListOptions.LeftMargin<>'' then MarginPixels:=DraftDimension(ListOptions.LeftMargin,ListEm,Width,MarginPixels,PointPixels);
      if ListOptions.ItemSep<>'' then ItemSkipPoints:=TeXStyleDimension(ListOptions.ItemSep,FTextStyle.Points);
      if ListOptions.Parsep<>'' then ParagraphSkipPoints:=TeXStyleDimension(ListOptions.Parsep,FTextStyle.Points);
      BetweenPoints:=ItemSkipPoints+ParagraphSkipPoints;
      ItemSkip:=Round(BetweenPoints*PointPixels); VerticalSkip(TopSkip);
      Inc(ListDepth); Count:=0;
      try
        for K:=0 to N.Children.Count-1 do begin
          Body:=TMathNode(N.Children[K]);
          for L:=0 to Body.Children.Count-1 do begin
            Item:=TMathNode(Body.Children[L]); if Pos('\item',MathPreviewNode(Item).Prefix)<>1 then Continue;
            NewLine; if Count>0 then VerticalSkip(ItemSkip); Inc(Count);
            LeftIndent:=Indent; HeadingHang:=MarginPixels; X:=10+Indent;
            if MathPreviewNode(Item)<>Item then begin Walk(Item,Size); NewLine; Continue; end;
            for M:=0 to Item.Children.Count-1 do begin
              Part:=TMathNode(Item.Children[M]); if Part.Kind<>mkOptional then Continue;
              LabelBox:=DescriptionLabel(Part); Append(LabelBox);
            end;
            Gap:=TDraftBox.Create; Gap.W:=Round(ListEm*0.5); Gap.InlineFlow:=True; Gap.Nonbreaking:=True; Append(Gap);
            LastWasSpace:=True;
            for M:=0 to Item.Children.Count-1 do begin
              Part:=TMathNode(Item.Children[M]); if Part.Kind<>mkOptional then Walk(Part,Size);
            end;
            NewLine;
          end;
        end;
        if Count>0 then VerticalSkip(TopSkip);
      finally
        Dec(ListDepth); LeftIndent:=Indent; HeadingHang:=Hang; TextAlign:=Alignment; Reflow:=WasReflow; DescriptionFlow:=WasDescription; X:=10+LeftIndent;
      end;
    end;
  begin
    OldTextDepth:=FTextStyleDepth; OldTextStyle:=FTextStyle; Declaration:=False;
    OldMarks:=HideEditingMarks;
    if IsProseGroup(N) then HideEditingMarks:=True;
    FormatName:=ProseFormatName(N);
    if (FormatName<>'') and (FormatName<>'\underline') then Inc(FTextStyleDepth);
    OuterScope:=Macros; LocalScope:=nil;
    if (N.Kind in [mkGroup,mkEnvironment]) and HasMacroDefinitions(N) and (Macros<>nil) then begin
      LocalScope:=Macros.Clone; Macros:=LocalScope; MacroScopes.Add(Macros);
    end;
    try
    if (BeamerNodeRole(N)='usebeamerfont') or (BeamerNodeRole(N)='usebeamercolor') then begin
      if N.Children.Count=0 then Exit;
      S:=TMathNode(N.Children[0]).TeX; P:=1; S:=ReadTeXGroup(S,P,'{','}');
      if BeamerNodeRole(N)='usebeamerfont' then begin
        S:=PresentationTheme.Font(S);
        if Pos('\usebeamerfont*',N.Prefix)=1 then begin
          Key:='\sffamily'; if PresentationTheme.Settings.Serif then Key:='\rmfamily';
          S:='\normalfont'+Key+S;
        end;
        ApplyDeclaration(S);
      end
      else begin
        P:=1; ReadTeXCommand(N.Prefix,P); Key:=ReadTeXGroup(N.Prefix,P,'[',']');
        if (Key='fg') or (Key='bg') then FDefaultColor:=PresentationTheme.Color(S,Key='bg');
      end;
      Exit;
    end;
    PreviewNode:=MathPreviewNode(N);
    if (Macros<>nil) and Macros.Presentation and (PreviewNode.Kind=mkEnvironment) and
      ((PreviewNode.Text='frame') or ((N=PreviewNode) and
      ((N.Text='columns') or (N.Text='block') or (N.Text='alertblock') or
       (N.Text='exampleblock') or (N.Text='overlayarea') or (N.Text='overprint') or Macros.IsTheorem(N.Text)))) then begin
      EndDisplay; NewLine; Slides:=0;
      if (PreviewNode.Text='frame') and PageLayout then Slides:=BeamerSlideCount(PreviewNode,PresentationTheme.Settings.Mode);
      for Slide:=Ord(Slides>0) to Slides do begin
        Pause:=1; Overlay:=DecodeBeamerOverlay(BeamerNodeSpec(N),PresentationTheme.Settings.Mode,Slide,Pause);
        if PageLayout and not Overlay.Active then Continue;
        Decoration:=BeamerBox(PreviewNode,Size,Width-20-LeftIndent-RightIndent,Slide);
        if N<>PreviewNode then Decoration:=SourcePreviewBox(N,Decoration,
          DefinitionBox(TMathNode(N.Children[0]),Size,Decoration.W),False,0);
        Decoration.X:=10+LeftIndent; Decoration.Y:=Y; Decoration.Slide:=Slide;
        FRoot.Children.Add(Decoration); Inc(Y,Decoration.H); LineStart:=FRoot.Children.Count;
      end;
      X:=10+LeftIndent; PreviousBaseline:=-1; PreviousDepth:=0; LastWasSpace:=True; Exit;
    end;
    if ((N.Kind=mkSource) or IsProseGroup(N)) and (N.SourcePreview<>nil) then begin
      EndDisplay; Append(ProseSourceBox(N,Size,Width-20-LeftIndent)); Exit;
    end;
    if ((N.Kind=mkGroup) and ((Pos('\footnote{',N.Prefix)=1) or (Pos('\footnote[',N.Prefix)=1) or
      (Pos('\footnotetext',N.Prefix)=1) or (Pos('\marginpar',N.Prefix)=1))) or
      ((N.Kind=mkTextCommand) and (Pos('\footnotemark',N.Text)=1)) then begin
      S:=N.Prefix; if N.Kind=mkTextCommand then S:=N.Text;
      P:=1; Cmd:=ReadTeXCommand(S,P); Key:=ReadTeXGroup(S,P,'[',']');
      if Key='' then begin if (Cmd='footnote') or (Cmd='footnotemark') then Inc(FootnoteNumber); Key:=IntToStr(Max(1,FootnoteNumber)); end;
      if (Cmd<>'footnotetext') and (Cmd<>'marginpar') then begin
        Decoration:=NoteMarker(Key,N.ID,FTextStyle.Points); Append(Decoration);
      end;
      if N.Children.Count>0 then begin
        { Expanded macro trees are temporary. Retain rendered boxes, never a
          node that will be released before the paragraph footer is laid out. }
        I:=Length(Footnotes); SetLength(Footnotes,I+1); Footnotes[I].Number:=Key;
        Footnotes[I].Marginal:=Cmd='marginpar';
        if Footnotes[I].Marginal then begin
          Decoration:=TDraftBox.Create; Decoration.Nonbreaking:=True; Append(Decoration); Footnotes[I].Anchor:=Decoration;
          MarginPage:=1; if Context<>nil then MarginPage:=StrToIntDef(Context.NativePage(ContextOffset+MathSourceOffset(N)),1);
          DocumentMarginNote(HeadingContext,MarginPage,MarginWidth,MarginSep,MarginPush,MarginLeft);
          MarginEm:=MeasureEm(FMathBaseSize)/MathFontPoints(0);
          Footnotes[I].Box:=BuildNote(TMathNode(N.Children.Last),Round(MarginWidth*MarginEm),True);
          Footnotes[I].Box.MarginAnchor:=Decoration;
          if MarginLeft then Footnotes[I].Box.X:=10-Round((MarginSep+MarginWidth)*MarginEm)
          else Footnotes[I].Box.X:=Width-10+Round(MarginSep*MarginEm);
        end else Footnotes[I].Box:=BuildNote(TMathNode(N.Children.Last));
      end;
      Exit;
    end;
    if N.Kind=mkDiagram then begin
      Horizontal:=ExplicitHorizontal or (FRoot.Children.Count>LineStart);
      EndDisplay; NewLine; Decoration:=DiagramBox(N,Size,Width-20-LeftIndent);
      Decoration.X:=Max(10+LeftIndent,(Width-Decoration.W) div 2); Decoration.Y:=Y;
      Key:=MathEnvironmentName(N);
      if (Key='xy') or (Key='xymatrix') then begin
        { xy.tex's xynomath emits an hbox without leavevmode. In vertical
          mode, center's paragraph glue therefore does not center it. }
        if not Horizontal or (TextAlign=0) then Decoration.X:=10+LeftIndent
        else if TextAlign=2 then Decoration.X:=Max(10+LeftIndent,Width-10-Decoration.W);
      end;
      FRoot.Children.Add(Decoration); Inc(Y,Decoration.H+6); LineStart:=FRoot.Children.Count;
      X:=10+LeftIndent; PreviousBaseline:=-1; PreviousDepth:=0; LastWasSpace:=True; Exit;
    end;
    if N.Kind in [mkDefinition,mkUnknownCommand,mkComment] then begin
      if N.SourceEditing then begin Append(DefinitionBox(N,Size,Width-20-LeftIndent)); Exit; end;
      if (N.Kind=mkComment) and HideEditingMarks then Exit;
      EndDisplay;
      P:=1; Cmd:=ReadTeXCommand(N.TeX,P);
      if (N.Kind=mkUnknownCommand) and IsTextStyleSwitch(Cmd) then begin
        if not HideEditingMarks then Append(DefinitionBox(N,Size,Width-20-LeftIndent));
        ApplyDeclaration(N.TeX); Exit;
      end;
      Decoration:=nil;
      if not HideEditingMarks or (N.Kind=mkUnknownCommand) then Decoration:=DefinitionBox(N,Size,Width-20-LeftIndent);
      if (Decoration<>nil) and (N.Kind=mkComment) and (Trim(Copy(N.TeX,2,MaxInt))='') then begin
        { An empty end-of-line comment suppresses whitespace in TeX. Keep its
          marker in the preceding gap without shifting adjacent minipages. }
        LinkBox:=TDraftBox.Create; LinkBox.Nonbreaking:=True;
        Decoration.X:=-Decoration.W; Decoration.Y:=-Decoration.Baseline;
        LinkBox.Children.Add(Decoration); Decoration:=LinkBox;
      end;
      if Decoration<>nil then Append(Decoration);
      if N.Kind=mkComment then Exit;
      FStyles.Apply(N.TeX);
      if N.Kind=mkUnknownCommand then ApplySectionCommand(Sections,N.TeX);
      if N.Kind=mkUnknownCommand then Exit;
      if Macros<>nil then Macros.ApplyDefinitions(N.TeX);
      P:=1; Cmd:=ReadTeXCommand(N.TeX,P);
      if (Cmd='gdef') or (Cmd='xdef') then for I:=0 to MacroScopes.Count-2 do TMacroRegistry(MacroScopes[I]).ApplyDefinitions(N.TeX);
      Exit;
    end;
    if (N.Kind=mkCommand) and (N.Text='\label') then begin
      if HideEditingMarks then Exit;
      Decoration:=LabelBox(N,Max(7,Round(Size*0.8))); Decoration.Anchored:=False; Append(Decoration); Exit;
    end;
    if N.Kind in [mkCommand,mkTextCommand] then
      if ReadHorizontalFill(N.TeX,Fill) or
        ((N.Text<>'\ ') and (N.Text<>'\space') and ReadMathSpace(N.TeX,SpaceWidth,Key)) then begin
        EndDisplay; Reflow:=True; Append(MathBox(N,Size)); LastWasSpace:=False; Exit;
      end;
    if N.Kind=mkCommand then begin
      P:=1; Cmd:=ReadTeXCommand(N.Text,P);
      FontSwitch:=nil; if Macros<>nil then FontSwitch:=Macros.Find(Cmd);
      if (FontSwitch<>nil) and (FontSwitch.PreviewAdapter='fontswitch') then begin
        if not HideEditingMarks then Append(DefinitionBox(N,Size,Width-20-LeftIndent));
        ApplyDeclaration(FontSwitch.Body); Exit;
      end;
      if (Cmd='indent') or (Cmd='noindent') then IndentPending:=False;
      if Cmd='par' then begin
        if not HboxLayout then begin NewLine; IndentPending:=True; end;
        Exit;
      end;
      if Cmd='appendix' then begin
        EndDisplay; NewLine; ApplySectionCommand(Sections,N.TeX); FStyles.Apply(N.TeX);
        if not HideEditingMarks then begin
          Decoration:=Leaf('Appendix',N.ID,Max(7,Round(Size*0.8)),0);
          Decoration.Color:=clGray; Decoration.Shape:=19; Decoration.W:=Width-20-LeftIndent;
          Decoration.H:=Max(22,Decoration.H);
          Decoration.CharCount:=UTF8Length(N.Text);
          Append(Decoration); NewLine;
        end;
        Exit;
      end;
      if IsGeneratedCommand(Cmd) then begin
        Decoration:=GeneratedBox(N,Width-20);
        if Decoration<>nil then begin
          EndDisplay; NewLine; Decoration.X:=10; Decoration.Y:=Y; FRoot.Children.Add(Decoration);
          Inc(Y,Decoration.H); LineStart:=FRoot.Children.Count; Exit;
        end;
        if Cmd='maketitle' then begin
          EndDisplay; NewLine; Decoration:=TitleBox(N,Size,Width-20);
          Decoration.X:=10; Decoration.Y:=Y; FRoot.Children.Add(Decoration); Inc(Y,Decoration.H);
          LineStart:=FRoot.Children.Count; Exit;
        end;
        EndDisplay; NewLine; Decoration:=TDraftBox.Create; Decoration.ID:=N.ID;
        Decoration.CharCount:=UTF8Length(N.Text); Decoration.W:=Width-20; Decoration.Baseline:=Round(MeasureEm(Size));
        case Cmd of
          'tableofcontents':S:=FStyles.Name('contentsname','Contents');
          'listoffigures':S:=FStyles.Name('listfigurename','List of Figures');
          'listoftables':S:=FStyles.Name('listtablename','List of Tables');
          else S:=FStyles.Name('refname',FStyles.Name('bibname','Bibliography'));
        end;
        LinkBox:=Leaf(S,-1,Size,0); Decoration.Children.Add(LinkBox); Decoration.H:=LinkBox.H+8;
        Decoration.X:=10; Decoration.Y:=Y; FRoot.Children.Add(Decoration); Inc(Y,Decoration.H);
        LineStart:=FRoot.Children.Count; Exit;
      end;
      if IsTeXInputCommand(Cmd) then begin
        S:=ReadTeXGroup(N.Text,P,'{','}'); if S='' then S:=Trim(Copy(N.Text,P,MaxInt));
        Decoration:=Leaf('['+Cmd+': '+S+']',N.ID,Size,0); Decoration.Shape:=12; Decoration.Color:=clGray;
        Decoration.CharCount:=UTF8Length(N.Text); Append(Decoration); Exit;
      end;
      if (Cmd='vspace') or (Cmd='vskip') or (Cmd='smallskip') or (Cmd='medskip') or (Cmd='bigskip') then begin
        EndDisplay; NewLine; Decoration:=VerticalSpaceBox(N,Size);
        Decoration.X:=10+LeftIndent; Decoration.Y:=Y; FRoot.Children.Add(Decoration); Inc(Y,Decoration.H); LineStart:=FRoot.Children.Count; Exit;
      end;
      Decoration:=TextAccentBox(N,Size);
      if Decoration<>nil then begin EndDisplay; Append(Decoration); Exit; end;
      Decoration:=PackageGlyphBox(N,Size);
      if Decoration<>nil then begin EndDisplay; Append(Decoration); Exit; end;
      Decoration:=NativeBox(N,Size);
      if Decoration<>nil then begin
        if Cmd='hrule' then begin
          EndDisplay; NewLine; Decoration.X:=10+LeftIndent; Decoration.Y:=Y;
          FRoot.Children.Add(Decoration); Inc(Y,Decoration.H); LineStart:=FRoot.Children.Count;
          PreviousBaseline:=-1; PreviousDepth:=0; Exit;
        end;
        EndDisplay; Append(Decoration);
        if (Cmd='indent') or (Cmd='noindent') then LastWasSpace:=True;
        Exit;
      end;
      Decoration:=PackageBox(N,Size);
      if Decoration<>nil then begin EndDisplay; Append(Decoration); Exit; end;
      Expanded:=ExpandedProseMacro(N);
      if Expanded<>nil then begin
        Inc(FExpansionDepth);
        try Walk(Expanded,Size); finally Dec(FExpansionDepth); Expanded.Free; end;
        Exit;
      end;
    end;
    if N.Kind=mkEnvironment then EndDisplay;
    if (N.Kind=mkEnvironment) and (N.Text='adjustbox') then begin
      NewLine; Decoration:=NativeBox(N,Size);
      if Decoration=nil then Decoration:=DefinitionBox(N,Size,Width-20-LeftIndent);
      Append(Decoration); NewLine; Exit;
    end;
    if (N.Kind=mkEnvironment) and (N.Text='minipage') then begin
      Decoration:=EnvironmentBox(N,Size,Width-20-LeftIndent-RightIndent);
      Append(Decoration); Exit;
    end;
    if (N.Kind=mkEnvironment) and ((N.Text='wrapfigure') or (N.Text='wraptable')) then begin
      NewLine; P:=7; ReadTeXGroup(N.Prefix,P,'{','}'); ReadTeXGroup(N.Prefix,P,'[',']');
      Key:=ReadTeXGroup(N.Prefix,P,'{','}'); ReadTeXGroup(N.Prefix,P,'[',']');
      S:=ReadTeXGroup(N.Prefix,P,'{','}');
      J:=DraftDimension(S,MeasureEm(Size),Width-20,(Width-20) div 3,MeasureEm(Size)/MathFontPoints(0));
      Decoration:=EnvironmentBox(N,Size,EnsureRange(J,80,Max(80,Width-60)));
      if not HideEditingMarks then begin
        LinkBox:=EditingCaption(N.Text); LinkBox.X:=10; LinkBox.Y:=Decoration.H;
        Decoration.Children.Add(LinkBox); Inc(Decoration.H,LinkBox.H+4);
      end;
      Decoration.X:=10+LeftIndent;
      if (Key='r') or (Key='R') or (Key='o') or (Key='O') then Decoration.X:=Width-10-Decoration.W;
      Decoration.Y:=Y; FRoot.Children.Add(Decoration); WrapBottom:=Y+Decoration.H+Round(MeasureEm(Size)*0.4);
      WrapLeft:=0; WrapRight:=0; J:=Decoration.W+Round(MeasureEm(Size));
      if Decoration.X=10+LeftIndent then WrapLeft:=J else WrapRight:=J;
      LineStart:=FRoot.Children.Count; X:=10+LeftIndent+WrapLeft; LastWasSpace:=True;
      PreviousBaseline:=-1; PreviousDepth:=0; Reflow:=True; Exit;
    end;
    if (N.Kind=mkEnvironment) and (N.Text='tcolorbox') then begin
      NewLine; Decoration:=EnvironmentBox(N,Size,Width-20-LeftIndent-RightIndent);
      Decoration.X:=10+LeftIndent; Decoration.Y:=Y; FRoot.Children.Add(Decoration); Inc(Y,Decoration.H);
      LineStart:=FRoot.Children.Count; X:=10+LeftIndent; LastWasSpace:=True;
      PreviousBaseline:=-1; PreviousDepth:=0; Exit;
    end;
    if (N.Kind=mkEnvironment) and FloatEnvironment(N.Text) then begin
      NewLine; SavedAlign:=TextAlign; TextAlign:=0;
      for I:=0 to N.Children.Count-1 do if TMathNode(N.Children[I]).Kind<>mkOptional then Walk(TMathNode(N.Children[I]),Size);
      NewLine; TextAlign:=SavedAlign; Exit;
    end;
    if N.Kind=mkTable then begin
      EndDisplay; NewLine; Decoration:=TableBox(N,Size);
      Decoration.X:=10+LeftIndent; if (TextAlign=1) or (N.Text='longtable') then Decoration.X:=Max(10,(Width-Decoration.W) div 2)
      else if TextAlign=2 then Decoration.X:=Max(10,Width-10-Decoration.W);
      Decoration.Y:=Y; FRoot.Children.Add(Decoration); Inc(Y,Decoration.H);
      LineStart:=FRoot.Children.Count; X:=10+LeftIndent; LastWasSpace:=True;
      PreviousBaseline:=-1; PreviousDepth:=0; Exit;
    end;
    if (N.Kind=mkGroup) and (Pos('\caption',N.Prefix)=1) then begin
      NewLine; Inc(Y,Round(MeasureEm(FMathBaseSize)*10/MathFontPoints(0))); CaptionFlow:=True;
      CaptionFirst:=FRoot.Children.Count; CaptionY:=Y; SavedAlign:=TextAlign; TextAlign:=0;
      Mark:=nil; if Context<>nil then Mark:=Context.Mark(ContextOffset+MathSourceOffset(N)-Length(N.Prefix));
      S:='Caption'; if Mark<>nil then begin
        if Mark.Counter<>'' then S:=FStyles.Caption(Mark.Counter,Mark.Number)
        else begin S:=Mark.Title; if Mark.Number<>'' then S:=S+' '+Mark.Number; end;
      end;
      Append(Leaf(S+': ',-1,Size,0));
      for I:=0 to N.Children.Count-1 do Walk(TMathNode(N.Children[I]),Size);
      NewLine; CaptionX:=0; J:=0;
      for I:=CaptionFirst to FRoot.Children.Count-1 do begin
        Decoration:=TDraftBox(FRoot.Children[I]); CaptionX:=Max(CaptionX,Decoration.X+Decoration.W);
        if I=CaptionFirst then CaptionY:=Decoration.Y+Decoration.Baseline;
        if Abs(Decoration.Y+Decoration.Baseline-CaptionY)>2 then J:=1;
      end;
      if J=0 then for I:=CaptionFirst to FRoot.Children.Count-1 do Inc(TDraftBox(FRoot.Children[I]).X,Max(0,(Width-CaptionX-10) div 2));
      CaptionFlow:=False; TextAlign:=SavedAlign; PreviousBaseline:=-1; PreviousDepth:=0; Exit;
    end;
    if N.Kind=mkVerbatim then begin
      EndDisplay; NewLine; EnvironmentSpace:=EnvironmentSkip(N); VerticalSkip(EnvironmentSpace);
      Decoration:=VerbatimBox(N,Size); Em:=MeasureEm(FMathBaseSize)/MathFontPoints(0);
      Decoration.X:=10+LeftIndent; Decoration.Y:=Y;
      if PreviousBaseline>=0 then Decoration.Y:=PreviousBaseline+
        Round(TextBaselineDistance(FTextStyle,PreviousDepth/Em,(Decoration.Baseline-InkTop(Decoration))/Em)*Em)-Decoration.Baseline;
      FRoot.Children.Add(Decoration); VerticalGlue:=0;
      PreviousBaseline:=Decoration.Y+Decoration.H-Max(1,Round(FTextStyle.Baseline*FTextStyle.Spread*Em))+Decoration.Baseline;
      PreviousDepth:=Max(0,Decoration.Y+InkBottom(Decoration)-PreviousBaseline);
      Y:=PreviousBaseline+PreviousDepth; VerticalSkip(EnvironmentSpace);
      LineStart:=FRoot.Children.Count; X:=10+LeftIndent; LastWasSpace:=True; Exit;
    end;
    if (N.Kind=mkEnvironment) and ((N.Text='center') or (N.Text='flushleft') or (N.Text='flushright')) then begin
      EndDisplay; NewLine; EnvironmentSpace:=EnvironmentSkip(N); VerticalSkip(EnvironmentSpace); SavedAlign:=TextAlign; Inc(AlignDepth);
      if N.Text='center' then TextAlign:=1 else if N.Text='flushright' then TextAlign:=2 else TextAlign:=0;
      for I:=0 to N.Children.Count-1 do Walk(TMathNode(N.Children[I]),Size);
      NewLine; VerticalSkip(EnvironmentSpace); TextAlign:=SavedAlign; Dec(AlignDepth); Exit;
    end;
    if (N.Kind=mkEnvironment) and (N.Text='description') then begin DescriptionList; Exit; end;
    if (N.Kind=mkEnvironment) and ((N.Text='itemize') or (N.Text='enumerate')) then begin
      EndDisplay; NewLine; EnvironmentSpace:=EnvironmentSkip(N);
      TextListSpacing(FTextStyle,ListDepth,Directory,TopPoints,BetweenPoints,@ItemSkipPoints,@ParagraphSkipPoints);
      Em:=2.5;
      ListOptions:=NativeListOptions(HeadingContext,N.TeX,N.Text,ListDepth);
      if ListOptions.TopSep<>'' then EnvironmentSpace:=DraftDimension(ListOptions.TopSep,MeasureEm(Size),Width,EnvironmentSpace,MeasureEm(FMathBaseSize)/MathFontPoints(0));
      if ListOptions.ItemSep<>'' then ItemSkipPoints:=TeXStyleDimension(ListOptions.ItemSep,FTextStyle.Points);
      if ListOptions.Parsep<>'' then ParagraphSkipPoints:=TeXStyleDimension(ListOptions.Parsep,FTextStyle.Points);
      BetweenPoints:=ItemSkipPoints+ParagraphSkipPoints;
      if ListOptions.LeftMargin<>'' then Em:=DraftDimension(ListOptions.LeftMargin,MeasureEm(Size),Width,Round(2.5*MeasureEm(Size)),MeasureEm(FMathBaseSize)/MathFontPoints(0))/MeasureEm(Size);
      if (Macros<>nil) and Macros.Presentation then begin
        Em:=2;
        if ListDepth=0 then begin EnvironmentSpace:=Round(3*MeasureEm(FMathBaseSize)/MathFontPoints(0)); BetweenPoints:=3; end
        else begin EnvironmentSpace:=Round(2*MeasureEm(FMathBaseSize)/MathFontPoints(0)); BetweenPoints:=0; end;
      end;
      VerticalSkip(EnvironmentSpace);
      SavedIndent:=LeftIndent; Inc(LeftIndent,Round(MeasureEm(Size)*Em)); ItemNumber:=ListOptions.Start-1; Inc(ListDepth);
      for I:=0 to N.Children.Count-1 do begin
        Child:=TMathNode(N.Children[I]); if Child.Kind=mkOptional then Continue;
        for J:=0 to Child.Children.Count-1 do begin
          if Pos('\item',MathPreviewNode(TMathNode(Child.Children[J])).Prefix)<>1 then Continue;
          NewLine; if ItemNumber>=ListOptions.Start then VerticalSkip(Round(BetweenPoints*MeasureEm(FMathBaseSize)/MathFontPoints(0)));
          Inc(ItemNumber); X:=10+SavedIndent;
          S:='•'; if N.Text='enumerate' then S:=IntToStr(ItemNumber)+'.';
          if ListOptions.LabelText<>'' then S:=NativeListLabel(ListOptions.LabelText,ItemNumber);
          Key:=MathPreviewNode(TMathNode(Child.Children[J])).Prefix;
          P:=6; if (Macros<>nil) and Macros.Presentation then ReadBeamerOverlay(Key,P);
          Key:=ReadTeXGroup(Key,P,'[',']'); if Key<>'' then S:=Key;
          Decoration:=Leaf(S,-1,Size,0);
          if ListOptions.LabelSep<>'' then X:=10+LeftIndent-Decoration.W-DraftDimension(ListOptions.LabelSep,MeasureEm(Size),Width,6,MeasureEm(FMathBaseSize)/MathFontPoints(0));
          if (Macros<>nil) and Macros.Presentation then begin
            Decoration.Color:=PresentationTheme.Color('item');
            if (N.Text='itemize') and (Key='') then begin
              Index:=ChooseTeXGlyph('math-symbol-'+IntToStr(MathFontPoints(0))+'-blacktriangleright');
              if Index>=0 then begin
                Decoration.Free; Decoration:=MathGlyphBox(Index,-1,Size,0);
                Inc(Decoration.Baseline,Round(1.25*MeasureEm(FMathBaseSize)/MathFontPoints(0)));
              end;
              Decoration.Color:=PresentationTheme.Color('itemize item');
            end;
            X:=10+LeftIndent-Round(0.5*MeasureEm(Size))-Decoration.W;
          end;
          if FBeamerProjection<>nil then begin
            ItemState:=FBeamerProjection.State(TMathNode(Child.Children[J]));
            Decoration.Covered:=ItemState.Visibility<>bvVisible;
            if ItemState.Alert then Decoration.Color:=PresentationTheme.Color('alerted text');
          end;
          Append(Decoration); X:=Max(X+6,10+LeftIndent);
          Walk(TMathNode(Child.Children[J]),Size); NewLine;
        end;
      end;
      Dec(ListDepth); VerticalSkip(EnvironmentSpace); LeftIndent:=SavedIndent; X:=10+LeftIndent; Exit;
    end;
    if (N.Kind=mkEnvironment) and (N.Text='abstract') then begin
      EndDisplay; NewLine; SavedAlign:=TextAlign; SavedIndent:=LeftIndent; OldRight:=RightIndent;
      OldFont:=FDefaultFont; OldStyle:=FDefaultStyle; OldHeight:=FDefaultHeight;
      VerticalSkip(EnvironmentSkip(N)); ApplyDeclaration('\small');
      TextAlign:=1; FDefaultStyle:=[fsBold];
      S:='Abstract'; FontSwitch:=nil; if Macros<>nil then FontSwitch:=Macros.Find('abstractname');
      if (FontSwitch<>nil) and FontSwitch.Expandable and (FontSwitch.ArgCount=0) then S:=FontSwitch.Body;
      Append(Leaf(S,-1,Size,0)); NewLine; FDefaultStyle:=[]; TextAlign:=0;
      Inc(LeftIndent,Round(2.5*MeasureEm(Size))); Inc(RightIndent,Round(2.5*MeasureEm(Size)));
      X:=10+LeftIndent; VerticalSkip(Round(0.5*MeasureEm(Size))); IndentPending:=True;
      for I:=0 to N.Children.Count-1 do Walk(TMathNode(N.Children[I]),Size);
      NewLine; LeftIndent:=SavedIndent; RightIndent:=OldRight; TextAlign:=SavedAlign;
      VerticalSkip(EnvironmentSkip(N)); X:=10+LeftIndent; Declaration:=False;
      FDefaultFont:=OldFont; FDefaultStyle:=OldStyle; FDefaultHeight:=OldHeight; Exit;
    end;
    if (N.Kind=mkEnvironment) and (Context<>nil) then
    begin
      Info:=Context.Theorem(N.Text);
      if (Info<>nil) or (N.Text='proof') then
      begin
        EndDisplay; NewLine; EnvironmentSpace:=EnvironmentSkip(N); VerticalSkip(EnvironmentSpace); IndentPending:=False; SavedAlign:=TextAlign; TextAlign:=0;
        Mark:=Context.Mark(ContextOffset+MathSourceOffset(N)-Length(N.Prefix));
        OldStyle:=FDefaultStyle; OldHeight:=FDefaultHeight;
        if (N.Text='proof') or ((Info<>nil) and (Info.Style='remark')) then FDefaultStyle:=[fsItalic] else FDefaultStyle:=[fsBold];
        S:=N.Text; if Mark<>nil then begin S:=Mark.Title; if Mark.Number<>'' then S:=S+' '+Mark.Number;  end;
        Append(Leaf(S, -1,Size,0)); FDefaultStyle:=[];
        for I:=0 to N.Children.Count-1 do begin
          Child:=TMathNode(N.Children[I]); if Child.Kind<>mkOptional then Continue;
          Append(Leaf(' (',-1,Size,0));
          if Child.Children.Count>0 then begin
            if TMathNode(Child.Children[0]).TeX<>'' then Walk(TMathNode(Child.Children[0]),Size)
            else begin
              Decoration:=Leaf('title',TMathNode(Child.Children[0]).ID,Size,0); Decoration.Color:=clGray;
              Decoration.CharCount:=0; SetLength(Decoration.Stops,1); Append(Decoration);
            end;
          end;
          Append(Leaf(')',-1,Size,0));
        end;
        Append(Leaf('. ', -1,Size,0));
        if (Info<>nil) and (Info.Style='plain') then FDefaultStyle:=[fsItalic];
        for I:=0 to N.Children.Count-1 do if TMathNode(N.Children[I]).Kind<>mkOptional then Walk(TMathNode(N.Children[I]),Size);
        if N.Text='proof' then begin Decoration:=Leaf('□',-1,Size,0); X:=Max(X,Width-Decoration.W-10); Append(Decoration); end;
        FDefaultStyle:=OldStyle; FDefaultHeight:=OldHeight; NewLine; VerticalSkip(EnvironmentSpace); TextAlign:=SavedAlign; Exit;
      end;
    end;
    if (N.Kind in [mkTextCommand,mkRaw]) and (Copy(N.Text,1,1)='\') then
    begin
      P:=1; Cmd:=ReadTeXCommand(N.Text,P);
      if IsTextStyleSwitch(Cmd) then begin
        ApplyDeclaration(N.Text); Exit;
      end;
      if (Cmd='label') then Exit;
      if Cmd='bibliographystyle' then Exit;
      if IsCitationCommand(Cmd) or (Cmd='bibliography') then begin
        EndDisplay;
        if ReadCitation(N.Text,Citation) then begin
          if Context<>nil then S:=Context.CitationText(Citation) else S:='['+Citation.Keys+']';
        end else if Cmd='bibliography' then begin NewLine; S:='Bibliography: '+ReadTeXGroup(N.Text,P,'{','}'); end
        else S:='[?]';
        Decoration:=Leaf(S,N.ID,Size,0); Decoration.CharCount:=UTF8Length(N.Text);
        SetLength(Decoration.Stops,Decoration.CharCount+1); Decoration.Stops[0]:=0;
        for I:=1 to Decoration.CharCount do Decoration.Stops[I]:=Decoration.W;
        Append(Decoration); if Cmd='bibliography' then NewLine; Exit;
      end;
      if (Cmd='centering') or (Cmd='raggedright') or (Cmd='raggedleft') then begin
        NewLine; if Cmd='centering' then TextAlign:=1 else if Cmd='raggedleft' then TextAlign:=2 else TextAlign:=0; Exit;
      end;
      if Cmd='leavevmode' then begin ExplicitHorizontal:=True; Exit; end;
      if (Cmd='includegraphics') or (Cmd='includepdf') then begin
        EndDisplay; NewLine;
        if Cmd='includepdf' then Decoration:=PDFPagesBox(N,Size) else Decoration:=FigureBox(N,Size);
        if (Cmd='includepdf') and OverlaySourceControls and (Decoration.Children.Count>0) then begin
          { Each included sheet is a separate pagination line. Keep the PDF
            vector surfaces shared; never rasterize a whole multi-page strip. }
          while Decoration.Children.Count>0 do begin
            LinkBox:=TDraftBox(Decoration.Children.Extract(Decoration.Children[0]));
            LinkBox.X:=10; LinkBox.Y:=Y; Inc(Y,LinkBox.H); FRoot.Children.Add(LinkBox);
          end;
          Decoration.Free;
          LineStart:=FRoot.Children.Count; X:=10; LastWasSpace:=True;
          PreviousBaseline:=-1; PreviousDepth:=0; Exit;
        end;
        Decoration.X:=10+LeftIndent;
        if TextAlign=1 then Decoration.X:=Max(10,(Width-Decoration.W) div 2);
        Decoration.Y:=Y; FRoot.Children.Add(Decoration); Inc(Y,Decoration.H+3);
        LineStart:=FRoot.Children.Count; X:=10+LeftIndent; LastWasSpace:=True;
        PreviousBaseline:=-1; PreviousDepth:=0; Exit;
      end;
      if Cmd='par' then begin
        if not HideEditingMarks then begin
          Decoration:=Leaf('',N.ID,Size,0); Decoration.Shape:=13; Decoration.W:=Max(9,Round(MeasureEm(Size)*0.8));
          Decoration.CharCount:=UTF8Length(N.Text); SetLength(Decoration.Stops,Decoration.CharCount+1);
          for I:=1 to Decoration.CharCount do Decoration.Stops[I]:=Decoration.W;
          { A paragraph-end marker is an overlay, not an extra strut or line. }
          Decoration.Y:=-Decoration.Baseline; LinkBox:=TDraftBox.Create;
          LinkBox.Nonbreaking:=True; LinkBox.HasInkMetric:=True; LinkBox.Children.Add(Decoration);
          if LineStart<FRoot.Children.Count then Append(LinkBox)
          else begin LinkBox.X:=X; LinkBox.Y:=Y; FRoot.Children.Add(LinkBox); LineStart:=FRoot.Children.Count; end;
        end;
        NewLine; IndentPending:=True; Exit;
      end;
      if (Cmd='\') or (Cmd='newline') or (Cmd='linebreak') or
         (Cmd='newpage') or (Cmd='clearpage') or (Cmd='pagebreak') then begin
        Decoration:=Leaf('',N.ID,Size,0); Decoration.Shape:=13; Decoration.W:=Max(9,Round(MeasureEm(Size)*0.8));
        if (Cmd='newpage') or (Cmd='clearpage') or (Cmd='pagebreak') then Decoration.BreakPenalty:=-10000;
        Decoration.CharCount:=UTF8Length(N.Text); SetLength(Decoration.Stops,Decoration.CharCount+1);
        for I:=1 to Decoration.CharCount do Decoration.Stops[I]:=Decoration.W;
        Append(Decoration); NewLine; Exit;
      end;
      if (Cmd='nolinebreak') or (Cmd='nopagebreak') then begin
        Decoration:=Leaf('',N.ID,Size,0); Decoration.CharCount:=UTF8Length(N.Text);
        SetLength(Decoration.Stops,Decoration.CharCount+1); Append(Decoration); Exit;
      end;
      if IsLabelReference(Cmd) then
      begin
        EndDisplay;
        if Copy(N.Text,P,1)='*' then Inc(P);
        Key:=ReadTeXGroup(N.Text,P,'{','}'); S:='??';
        if (Cmd='crefrange') or (Cmd='Crefrange') then Key:=Key+','+ReadTeXGroup(N.Text,P,'{','}');
        if Context<>nil then S:=Context.ReferenceText(Key,Cmd);
        Decoration:=Leaf(S,N.ID,Size,0); Decoration.CharCount:=UTF8Length(N.Text);
        SetLength(Decoration.Stops,Decoration.CharCount+1); Decoration.Stops[0]:=0;
        for I:=1 to Decoration.CharCount do Decoration.Stops[I]:=Decoration.W;
        Append(Decoration); Exit;
      end;
    end;
    if (N.Kind=mkGroup) and IsVerbatimField(N) then begin
      EndDisplay;
      OldFont:=FDefaultFont; OldStyle:=FDefaultStyle; OldHeight:=FDefaultHeight;
      FTextStyle.Family:=FTextStyle.Mono; FTextStyle.Series:='m'; FTextStyle.Shape:='n';
      FDefaultFont:='Latin Modern Mono'; FDefaultStyle:=[]; FDefaultHeight:=0;
      for I:=0 to N.Children.Count-1 do begin
        Child:=TMathNode(N.Children[I]); Decoration:=Leaf(Child.Text,Child.ID,Size,0); Append(Decoration);
      end;
      FDefaultFont:=OldFont; FDefaultStyle:=OldStyle; FDefaultHeight:=OldHeight; Exit;
    end;
    if (N.Kind=mkRaw) and (Copy(N.Text,1,5)='\verb') then begin
      P:=6; if (P<=Length(N.Text)) and (N.Text[P]='*') then Inc(P);
      S:=Copy(N.Text,P+1,Max(0,Length(N.Text)-P-1));
      OldFont:=FDefaultFont; OldHeight:=FDefaultHeight; FDefaultFont:='Latin Modern Mono'; FDefaultHeight:=0;
      Decoration:=Leaf(S,N.ID,Size,0); Decoration.CharCount:=UTF8Length(N.Text);
      SetLength(Decoration.Stops,Decoration.CharCount+1);
      for I:=0 to Decoration.CharCount do Decoration.Stops[I]:=Round(Decoration.W*I/Max(1,Decoration.CharCount));
      Append(Decoration); FDefaultFont:=OldFont; FDefaultHeight:=OldHeight; Exit;
    end;
    if N.Kind=mkFormula then
    begin
      LastLineRight:=10;
      if not IsInlineFormula(N) then begin
        EndDisplay; NewLine;
        for I:=FRoot.Children.Count-1 downto 0 do begin
          Decoration:=TDraftBox(FRoot.Children[I]);
          if Decoration.Text='' then Continue;
          if Decoration.Y+Decoration.Baseline<PreviousBaseline-2 then Break;
          LastLineRight:=Max(LastLineRight,Decoration.X+Decoration.W);
        end;
      end;
      Decoration:=FormulaBox(N,Size);
      FormulaEnvironmentCaptions(Decoration,N);
      if not IsInlineFormula(N) then
      begin
        AMSDisplay:=(Pos('\begin{align',N.Prefix)=1) or (Pos('\begin{gather',N.Prefix)=1) or
          (Pos('\begin{eqnarray',N.Prefix)=1);
        Em:=MeasureEm(FMathBaseSize)/MathFontPoints(0);
        ShortDisplay:=not AMSDisplay and (LastLineRight+2*MeasureEm(Size)<(Width-Decoration.W)/2);
        TextDisplaySpacing(FTextStyle,ShortDisplay,Directory,TopPoints,BetweenPoints);
        DisplayAbove:=Round(TopPoints*Em); DisplayBelow:=Round(BetweenPoints*Em);
        if Decoration.Anchored and not Reflow then Y:=Max(Y,Decoration.Anchor.Top)
        else if PreviousBaseline>=0 then Y:=PreviousBaseline+
          { TeX appends the complete display box, including its alignment
            strut. Using glyph ink here removes space between displays. }
          Round(TextBaselineDistance(FTextStyle,PreviousDepth/Em,Decoration.Baseline/Em)*Em)-Decoration.Baseline+DisplayAbove
        else Inc(Y,DisplayAbove);
        Decoration.Anchored:=False; Decoration.X:=Max(10,(Width-Decoration.W) div 2); Decoration.Y:=Y;
        FRoot.Children.Add(Decoration); VerticalGlue:=0; DisplayBottom:=Y+Decoration.H; Y:=DisplayBottom;
        PreviousBaseline:=Decoration.Y+Decoration.Baseline;
        PreviousDepth:=Max(0,Decoration.H-Decoration.Baseline);
        AfterDisplay:=True; X:=10+LeftIndent; LineStart:=FRoot.Children.Count;
        Above:=0; Below:=0; LineBaseline:=-1; AnchorLine:=-1; LastWasSpace:=True;
        Exit;
      end;
      EndDisplay;
      AppendInlineFormula(Decoration);
      Exit;
    end;
    if N.Kind=mkProse then begin Prose(N,Size); Exit; end;
    if N.Kind=mkTextCommand then
    begin
      EndDisplay;
      Decoration:=NativeBox(N,Size);
      if Decoration<>nil then begin Append(Decoration); Exit; end;
      S:=N.Text;
      if (S='\LaTeX') or (S='\LaTeX{}') or (S='\TeX') or (S='\TeX{}') then
      begin Append(LogoBox(N,Size)); Exit; end;
      if (S='\ ') or (S='\space') or (S='\space{}') then begin
        Decoration:=Leaf(' ',N.ID,Size,0); Decoration.CharCount:=UTF8Length(N.Text);
        SetLength(Decoration.Stops,Decoration.CharCount+1); Decoration.Stops[0]:=0;
        for I:=1 to Decoration.CharCount do Decoration.Stops[I]:=Decoration.W;
        Append(Decoration); Exit;
      end;
      Decoration:=TextSymbolBox(N,Size); if Decoration<>nil then begin Append(Decoration); Exit; end;
      Append(Leaf(S,N.ID,Size,0)); Exit;
    end;
    OldFont:=FDefaultFont; OldStyle:=FDefaultStyle; OldHeight:=FDefaultHeight; OldColor:=FDefaultColor;
    Heading:=(N.Kind=mkGroup) and ((Pos('\section',N.Prefix)=1) or
      (Pos('\subsection',N.Prefix)=1) or (Pos('\subsubsection',N.Prefix)=1) or
      (Pos('\chapter',N.Prefix)=1) or (Pos('\part',N.Prefix)=1) or
      (Pos('\paragraph',N.Prefix)=1) or (Pos('\subparagraph',N.Prefix)=1));
    if Heading then
    begin
      EndDisplay; NewLine; IndentPending:=False; P:=1; HeadingName:=ReadTeXCommand(N.Prefix,P);
      HeadingFormat:=FStyles.Heading(HeadingName,Copy(N.Prefix,P,1)='*');
      HeadingStyle:=FStyles.Style(HeadingFormat.Format);
      ApplyTextStyle(FTextStyle,HeadingFormat.Format,Directory);
      SavedAlign:=TextAlign; SavedIndent:=LeftIndent; OldRight:=RightIndent; OldHang:=HeadingHang;
      OldUppercase:=HeadingUppercase;
      OldHeadingSize:=FHeadingSize; OldHeadingPoints:=FHeadingPoints;
      FDefaultStyle:=[]; if HeadingStyle.Bold then Include(FDefaultStyle,fsBold);
      if HeadingStyle.Italic then Include(FDefaultStyle,fsItalic);
      case HeadingStyle.Family of
        'sf':FDefaultFont:='Latin Modern Sans'; 'tt':FDefaultFont:='Latin Modern Mono';
        else FDefaultFont:=ResolveTeXFont('CMR10');
      end;
      if HeadingStyle.HasColor then FDefaultColor:=RGBToColor((HeadingStyle.Color shr 16) and 255,(HeadingStyle.Color shr 8) and 255,HeadingStyle.Color and 255);
      FDefaultHeight:=0; TextAlign:=HeadingStyle.Alignment;
      Em:=MeasureEm(FMathBaseSize)/MathFontPoints(0);
      if Trim(HeadingFormat.Left)='\parindent' then
        Inc(LeftIndent,Round(DocumentParagraphIndent(HeadingContext,OldTextStyle.Points)*Em))
      else Inc(LeftIndent,Round(TeXStyleDimension(HeadingFormat.Left,HeadingStyle.Points)*Em));
      RightIndent:=Round(TeXStyleDimension(HeadingFormat.Right,HeadingStyle.Points)*Em);
      if FRoot.Children.Count>0 then Inc(Y,Round(Abs(TeXStyleDimension(HeadingFormat.Above,MathFontPoints(0)))*Em));
      PreviousBaseline:=-1; PreviousDepth:=0; X:=10+LeftIndent; HeadingHang:=0; HeadingStart:=X;
      if (HeadingFormat.Shape='runin') and (LeftIndent<>SavedIndent) then begin
        { The run-in indent belongs to the heading's first line, not to the
          following body lines. Keep it as an item when the paragraph reflows. }
        Decoration:=TDraftBox.Create; Decoration.W:=LeftIndent-SavedIndent;
        LeftIndent:=SavedIndent; X:=10+LeftIndent; Decoration.Nonbreaking:=True; Append(Decoration);
      end;
      Size:=Max(1,Round(FMathBaseSize*HeadingStyle.Points/MathFontPoints(0)));
      FHeadingSize:=Size; FHeadingPoints:=HeadingStyle.Points;
      S:=''; if NumberedHeading(N) then S:=FStyles.HeadingLabel(HeadingFormat.LabelCode,Sections);
      if S<>'' then begin
        Append(Leaf(S,-1,Size,0));
        Separator:=Round(TeXStyleDimension(HeadingFormat.Separator,HeadingStyle.Points)*Em);
        if HeadingFormat.Shape='display' then begin NewLine; Inc(Y,Separator); PreviousBaseline:=-1; end
        else begin Decoration:=TDraftBox.Create; Decoration.W:=Separator; Append(Decoration); end;
      end;
      if (HeadingFormat.Shape='hang') and (TextAlign=0) then HeadingHang:=X-HeadingStart;
      if HeadingFormat.BeforeCode<>'' then begin
        HeadingStyle:=FStyles.Style(HeadingFormat.Format+HeadingFormat.BeforeCode);
        ApplyTextStyle(FTextStyle,HeadingFormat.BeforeCode,Directory);
        FDefaultStyle:=[]; if HeadingStyle.Bold then Include(FDefaultStyle,fsBold);
        if HeadingStyle.Italic then Include(FDefaultStyle,fsItalic);
        case HeadingStyle.Family of
          'sf':FDefaultFont:='Latin Modern Sans'; 'tt':FDefaultFont:='Latin Modern Mono';
          else FDefaultFont:=ResolveTeXFont('CMR10');
        end;
        if HeadingStyle.HasColor then FDefaultColor:=RGBToColor((HeadingStyle.Color shr 16) and 255,(HeadingStyle.Color shr 8) and 255,HeadingStyle.Color and 255);
        Size:=Max(1,Round(FMathBaseSize*HeadingStyle.Points/MathFontPoints(0)));
        FHeadingSize:=Size; FHeadingPoints:=HeadingStyle.Points;
      end;
      HeadingUppercase:=Pos('\MakeUppercase',HeadingFormat.BeforeCode)>0;
      BeforeHeading:=FStyles.Text(HeadingFormat.BeforeCode,'','');
      if BeforeHeading<>'' then Append(Leaf(BeforeHeading,-1,Size,0));
      for I:=0 to N.Children.Count-1 do Walk(TMathNode(N.Children[I]),Size);
      AfterHeading:=FStyles.Text(HeadingFormat.AfterCode,'','');
      if AfterHeading<>'' then Append(Leaf(AfterHeading,-1,Size,0));
      if HeadingFormat.Shape='runin' then begin
        { @xsect removes trailing title glue, inserts the horizontal afterskip,
          then ignores source whitespace before the body. }
        if FRoot.Children.Count>LineStart then begin
          Decoration:=TDraftBox(FRoot.Children.Last);
          if (Decoration.Text<>'') and (Trim(Decoration.Text)='') and (Decoration.Shape=0) then begin
            Dec(X,Decoration.W); Decoration.W:=0;
            for I:=0 to High(Decoration.Stops) do Decoration.Stops[I]:=0;
          end;
        end;
        Decoration:=TDraftBox.Create;
        Decoration.W:=Round(Abs(TeXStyleDimension(HeadingFormat.Below,MathFontPoints(0)))*Em);
        Decoration.InterCharacterGlue:=True; Decoration.MathGlue:=True; Append(Decoration);
        LastWasSpace:=True; RunInPending:=True;
      end else begin
        NewLine; Inc(Y,Round(Max(0,TeXStyleDimension(HeadingFormat.Below,MathFontPoints(0)))*Em));
        PreviousBaseline:=-1; PreviousDepth:=0;
      end;
      TextAlign:=SavedAlign; LeftIndent:=SavedIndent; RightIndent:=OldRight; HeadingHang:=OldHang;
      HeadingUppercase:=OldUppercase;
      FHeadingSize:=OldHeadingSize; FHeadingPoints:=OldHeadingPoints;
      if HeadingFormat.Shape<>'runin' then begin X:=10+LeftIndent; IndentPending:=AutoIndent; end;
      FDefaultFont:=OldFont; FDefaultStyle:=OldStyle; FDefaultHeight:=OldHeight; FDefaultColor:=OldColor; Exit;
    end;
    if (FLayout<>nil) and (Length(FLayout.Anchors)>0) and (N.Kind=mkGroup) and (FTextStyleDepth=0) and not DescriptionFlow then
    begin
      for I:=0 to FNodes.Count-1 do
      begin
        Child:=TMathNode(FNodes[I]);
        if (MathSourceOffset(Child)>=MathSourceOffset(N)) and
           (MathSourceOffset(Child)<MathSourceOffset(N)+MathSourceLength(N)-Length(N.Prefix)) then
        begin
          Index:=AnchorFor(Child.ID); if Index<0 then Continue;
          FDefaultFont:=FLayout.Anchors[Index].FontName; FDefaultStyle:=FDefaultStyle+FLayout.Anchors[Index].Style; FDefaultColor:=FLayout.Anchors[Index].Color;
          FDefaultHeight:=Max(1,Round(FLayout.Anchors[Index].FontHeight*FScale));
          Break;
        end;
      end;
    end;
    if FormatName<>'' then begin
      if fsBold in FDefaultStyle then FTextStyle.Series:='bx';
      if (fsItalic in FDefaultStyle) and (FTextStyle.Shape='n') then FTextStyle.Shape:='it';
      ApplyTextStyle(FTextStyle,N.Prefix,Directory);
      FDefaultHeight:=0;
      FDefaultFont:='Latin Modern Roman';
      if FTextStyle.Family=FTextStyle.Sans then FDefaultFont:='Latin Modern Sans'
      else if FTextStyle.Family=FTextStyle.Mono then FDefaultFont:='Latin Modern Mono';
      Exclude(FDefaultStyle,fsBold); Exclude(FDefaultStyle,fsItalic);
      if (FTextStyle.Series='b') or (FTextStyle.Series='bx') then Include(FDefaultStyle,fsBold);
      if (Pos('it',FTextStyle.Shape)>0) or (Pos('sl',FTextStyle.Shape)>0) then Include(FDefaultStyle,fsItalic);
      Size:=EnsureRange(Round(FTextStyle.Points*FMathBaseSize/MathFontPoints(0)),1,240);
    end;
    if Pos('\textcolor',N.Prefix)=1 then begin
      P:=1; ReadTeXCommand(N.Prefix,P); Key:=ReadTeXGroup(N.Prefix,P,'[',']');
      S:=ReadTeXGroup(N.Prefix,P,'{','}');
      FDefaultColor:=DocumentColor(S,Key,HeadingContext+Copy(FSource,1,Max(0,MathSourceOffset(N)-Length(N.Prefix))));
    end;
    if (N.Kind=mkRaw) and ((N.Text='{') or (N.Text='}')) then GrayBrace(N.Text)
    else if (N.Kind=mkRaw) and (Trim(N.Text)<>'') then Prose(N,Size);
    if (N.Kind=mkGroup) and (N.Prefix='{') and (N.Text<>'@beamer:argument') then GrayBrace('{');
    for I:=0 to N.Children.Count-1 do Walk(TMathNode(N.Children[I]),Size);
    if (N.Kind=mkGroup) and (N.Prefix='{') and (N.Suffix='}') and (N.Text<>'@beamer:argument') then GrayBrace('}');
    FDefaultFont:=OldFont; FDefaultStyle:=OldStyle; FDefaultHeight:=OldHeight; FDefaultColor:=OldColor;
    finally
      HideEditingMarks:=OldMarks;
      if not Declaration then begin FTextStyleDepth:=OldTextDepth; FTextStyle:=OldTextStyle; end;
      if LocalScope<>nil then begin MacroScopes.Delete(MacroScopes.Count-1); Macros:=OuterScope; LocalScope.Free; end;
    end;
  end;
  procedure Walk(N:TMathNode; Size:Integer);
  var Name,Role,ThemeFont:string; Caption:TDraftBox; First,I,OldDepth:Integer; State:TBeamerNodeState; OldColor:TColor;
      SavedTextStyle:TTeXTextStyle;
  begin
    if (N.Kind=mkTextCommand) and (Copy(N.Text,1,6)='\color') then begin
      I:=1; Name:=ReadTeXCommand(N.Text,I);
      if Name='color' then begin
        Role:=ReadTeXGroup(N.Text,I,'[',']'); Name:=ReadTeXGroup(N.Text,I,'{','}');
        FDefaultColor:=DocumentColor(Name,Role,HeadingContext); Exit;
      end;
    end;
    if N.Hidden and (N.Kind=mkRaw) then Exit;
    if PageLayout and (Macros<>nil) and Macros.Presentation and (FBeamerProjection=nil) and not N.SourceEditing and
      (N.Kind<>mkRow) and not ((MathPreviewNode(N).Kind=mkEnvironment) and (MathPreviewNode(N).Text='frame')) then Exit;
    Role:=BeamerNodeRole(N);
    if (Role='usebeamerfont') or (Role='usebeamercolor') then begin WalkContent(N,Size); Exit; end;
    if (Role='pause') or (Role='frametitle') or (Role='framesubtitle') or (Role='framezoom') then Exit;
    State:=Default(TBeamerNodeState); if FBeamerProjection<>nil then State:=FBeamerProjection.State(N);
    if State.Visibility=bvAbsent then Exit;
    if (Role='titlepage') or (Role='maketitle') then begin
      EndDisplay; NewLine; Caption:=BeamerTitlePage(N,Width-20-LeftIndent-RightIndent);
      Caption.X:=10+LeftIndent; Caption.Y:=Y; FRoot.Children.Add(Caption); Inc(Y,Caption.H);
      LineStart:=FRoot.Children.Count; X:=10+LeftIndent; PreviousBaseline:=-1; PreviousDepth:=0; Exit;
    end;
    First:=FRoot.Children.Count; OldColor:=FDefaultColor;
    if (Role='alert') and (FBeamerProjection=nil) then State.Alert:=True;
    ThemeFont:='';
    if State.Alert then begin FDefaultColor:=PresentationTheme.Color('alerted text'); ThemeFont:=PresentationTheme.Font('alerted text'); end
    else if Role='structure' then begin FDefaultColor:=PresentationTheme.Color('structure'); ThemeFont:=PresentationTheme.Font('structure'); end;
    SavedTextStyle:=FTextStyle; OldDepth:=FTextStyleDepth;
    if ThemeFont<>'' then begin ApplyTextStyle(FTextStyle,ThemeFont,Directory); Inc(FTextStyleDepth); end;
    if FTextStyleDepth>0 then Size:=EnsureRange(Round(FTextStyle.Points*FMathBaseSize/MathFontPoints(0)),1,1920);
    try WalkContent(N,Size); finally
      FDefaultColor:=OldColor;
      if ThemeFont<>'' then begin FTextStyle:=SavedTextStyle; FTextStyleDepth:=OldDepth; end;
    end;
    if State.Visibility=bvCovered then for I:=First to FRoot.Children.Count-1 do TDraftBox(FRoot.Children[I]).Covered:=True;
    if HideEditingMarks or HideEnvironmentCaptions or (N.Kind=mkFormula) or
      ((N.Kind=mkEnvironment) and (N.Text='minipage')) or
      ((N.Kind=mkEnvironment) and ((N.Text='wrapfigure') or (N.Text='wraptable'))) then Exit;
    Name:=MathEnvironmentName(N); if Name='' then Exit;
    EndDisplay; NewLine; Caption:=EditingCaption(Name);
    Caption.X:=10+LeftIndent; Caption.Y:=Y+2; FRoot.Children.Add(Caption);
    Inc(Y,Caption.H+4); LineStart:=FRoot.Children.Count; X:=10+LeftIndent;
    PreviousBaseline:=-1; PreviousDepth:=0; LastWasSpace:=True;
  end;
  procedure PageMarks(N:TMathNode);
  var I,J,K,Offset:Integer; P:Integer; Name:string; Box:TDraftBox; Info:TMacroInfo; Marked,OldMarks:Boolean;
  begin
    if N.Hidden or IsProseGroup(N) then Exit;
    Marked:=N.Kind in [mkDefinition,mkComment];
    if N.Kind in [mkCommand,mkUnknownCommand] then begin
      P:=1; Name:=ReadTeXCommand(N.TeX,P);
      Marked:=(Name='label') or IsTextStyleSwitch(Name);
      if (Macros<>nil) and not Marked then begin
        Info:=Macros.Find(Name); Marked:=(Info<>nil) and
          ((Info.PreviewAdapter='fontswitch') or (Info.PreviewAdapter='metadata') or (Info.PreviewAdapter='directive'));
      end;
    end;
    if Marked then begin
      OldMarks:=HideEditingMarks; HideEditingMarks:=False;
      try
        if Name='label' then Box:=LabelBox(N,Max(7,Round(FontSize*0.8))) else Box:=DefinitionBox(N,FontSize,Width-20);
      finally HideEditingMarks:=OldMarks; end;
      Offset:=MathSourceOffset(N)-Length(N.Prefix); K:=0;
      if Length(FPageLines)=0 then begin SetLength(FPageLines,1); FPageLines[0].SourceOffset:=Offset; end;
      for I:=1 to High(FPageLines) do if FPageLines[I].SourceOffset<=Offset then K:=I;
      Box.X:=10; Box.Y:=FPageLines[K].Bottom+FPageLines[K].EditorSpace+2;
      Inc(FPageLines[K].EditorSpace,Box.H+4); J:=FRoot.Children.Add(Box);
      SetLength(FPageOrigins,J+1); SetLength(FPageGroups,J+1); FPageOrigins[J]:=Box.Y; FPageGroups[J]:=K; Exit;
    end;
    for I:=0 to N.Children.Count-1 do PageMarks(TMathNode(N.Children[I]));
  end;
begin
  if (Context<>nil) and not Context.NativePageLayout and HasPageReferences(Source) then begin
    NativeEm:=PixelsPerEm; if NativeEm<=0 then NativeEm:=FontSize*Canvas.Font.PixelsPerInch/72;
    EnsureNativePages(Canvas,Context,Directory,Width,FontSize,Scale,NativeEm,TeXEngine);
  end;
  SourceIndex:=TMathSourceIndex.Create(Node);
  try
  if FBeamerThemeOwner and ((Macros=nil) or not Macros.Presentation) then begin
    FreeAndNil(FBeamerTheme); FBeamerThemeOwner:=False; FBeamerContext:='';
  end;
  if FTextShapes=nil then begin FTextShapes:=TStringList.Create; FTextShapes.NameValueSeparator:=#2; FTextShapes.CaseSensitive:=True; end;
  FTextShapes.Clear;
  FDefaultFont:=ResolveTeXFont('CMR10');
  if Pos('12pt',HeadingContext)>0 then FDefaultFont:=ResolveTeXFont('CMR12');
  if FDefaultFont='' then FDefaultFont:='Latin Modern Roman';
  FDefaultStyle:=[]; FDefaultColor:=TextColorSeed; FDefaultHeight:=0; FMathLeaf:=False; FMathStyle:=''; FDisplayMath:=not Paragraph;
  FTextStyleDepth:=0;
  FMathLevel:=0; FMathBaseSize:=FontSize; FHeadingSize:=0; FHeadingPoints:=0;
  if TextStyleSeed.Points>0 then begin FTextStyle:=TextStyleSeed; FTextStyleDepth:=1; end
  else FTextStyle:=InitialTextStyle(HeadingContext,Directory,TeXEngine,Macros);
  FOpenTypeText:=FTextStyle.Encoding='TU';
  ParagraphLineStyle:=FTextStyle;
  FTextEncoding:=FTextStyle.Encoding; FTextRoman:=FTextStyle.Roman; FTextSans:=FTextStyle.Sans; FTextMono:=FTextStyle.Mono;
  FCanvas:=Canvas;
  { Native font changes can reset PixelsPerInch on Qt. Layout distances use
    the document's exact preview scale rather than a rounded native font size. }
  FEmFactor:=Canvas.Font.PixelsPerInch/72;
  if PixelsPerEm>0 then FEmFactor:=PixelsPerEm/Max(1,FontSize);
  FMatrixGap:=Round(MeasureEm(FontSize));
  if Pos('12pt',HeadingContext)>0 then FMatrixGap:=Round(FMatrixGap*10/12)
  else if Pos('11pt',HeadingContext)>0 then FMatrixGap:=Round(FMatrixGap*10/11);
  FLayout:=Previous; FSource:=Source; FScale:=Scale;
  if FStyles=nil then FStyles:=TTeXStyles.Create;
  if StyleSeed<>nil then FStyles.Assign(StyleSeed)
  else begin
    if FBaseStyles=nil then FBaseStyles:=TTeXStyles.Create;
    if (FStyleContext<>HeadingContext) or (FStyleDirectory<>Directory) or (FStyleContext='') or
       ((Macros<>nil) and (FStyleRegistryRevision<>Macros.Revision)) then begin
      FBaseStyles.Load(HeadingContext,Directory,Macros); FStyleContext:=HeadingContext; FStyleDirectory:=Directory;
      if Macros<>nil then FStyleRegistryRevision:=Macros.Revision else FStyleRegistryRevision:=0;
    end;
    FStyles.Assign(FBaseStyles);
  end;
  if FNodes=nil then FNodes:=TList.Create; FNodes.Clear; MathFields(Node,FNodes);
  if FFieldIndex=nil then FFieldIndex:=TMathFieldIndex.Create;
  FFieldIndex.Build(FNodes);
  { New words inherit the paragraph's compiled body face and exact pixel size.
    Otherwise an unmapped inserted word falls back to a different optical size. }
  if FLayout<>nil then for FieldIndex:=0 to FNodes.Count-1 do
    if (TMathNode(FNodes[FieldIndex]).Kind=mkProse) and
       (TMathNode(FNodes[FieldIndex]).Parent=Node) then begin
      FontIndex:=AnchorFor(TMathNode(FNodes[FieldIndex]).ID);
      if (FontIndex>=0) and (FLayout.Anchors[FontIndex].SourceLength>0) then begin
        FDefaultFont:=FLayout.Anchors[FontIndex].FontName;
        FDefaultHeight:=Max(1,Round(FLayout.Anchors[FontIndex].FontHeight*FScale)); Break;
      end;
    end;
  RestoreEditingSpace;
  FreeAndNil(FRoot); FRoot:=TDraftBox.Create; Regions:=nil; Links:=nil; SourceToggles:=nil;
  TextAlign:=0; AlignDepth:=0; LeftIndent:=0; RightIndent:=0; HeadingHang:=0; HeadingUppercase:=False; Width:=Max(80,Width); X:=10; Y:=10; LineStart:=0; Above:=0; Below:=0; LineBaseline:=-1; AnchorShift:=0; AnchorLine:=-1; Reflow:=HasCodeObjects(Node) or ContainsCJK(FSource) or ((FLayout<>nil) and (FSource<>FLayout.Source)); LastWasSpace:=not HboxLayout;
  { beamer.cls starts its document ragged right. Keep natural interword
    glue instead of stretching slide text to article-style justification. }
  if (Macros<>nil) and Macros.Presentation then TextAlign:=3;
  VerticalGlue:=0; AfterDisplay:=False; PreviousBaseline:=-1; PreviousDepth:=0; DisplayBottom:=0; DisplayBelow:=0; CaptionFlow:=False; LabelFlow:=False; DescriptionFlow:=False; ListDepth:=0; ExplicitHorizontal:=False;
  Footnotes:=nil; FootnoteNumber:=0;
  FEquationCounter:=0; FMathWidth:=Width-20; FExpansionDepth:=0; FExpansionBudget:=256;
  WrapBottom:=0; WrapLeft:=0; WrapRight:=0;
  AutoIndent:=Paragraph and not TableCellLayout and not SuppressParagraphIndent and
    (Node.Parent=nil) and DocumentUsesCTeX(HeadingContext);
  IndentPending:=AutoIndent; RunInPending:=False; ParagraphIndent:=0;
  if AutoIndent then ParagraphIndent:=DocumentParagraphIndent(HeadingContext,FTextStyle.Points);
  Sections:=InitialSectionState(FStyles.HasChapters or HeadingWithChapter,FStyles.NumberDepth);
  if Context<>nil then begin
    Sections:=Context.SectionStateBefore(ContextOffset);
    FEquationCounter:=Context.CounterBefore('equation',ContextOffset);
  end else if not TableCellLayout then begin
    if FCounterContext=nil then FCounterContext:=TTeXContext.Create;
    FCounterContext.Load(HeadingContext,Directory,TeXEngine);
    Sections:=FCounterContext.SectionStateBefore(Length(HeadingContext)+1);
    FEquationCounter:=FCounterContext.CounterBefore('equation',Length(HeadingContext)+1);
  end;
  if Context<>nil then FootnoteNumber:=Context.CounterBefore('footnote',ContextOffset)
  else if FCounterContext<>nil then FootnoteNumber:=FCounterContext.CounterBefore('footnote',Length(HeadingContext)+1);
  SavedMacros:=Macros; WorkingMacros:=nil;
  MacroScopes:=TList.Create; FMacroScopes:=MacroScopes;
  if HasMacroDefinitions(Node) then begin
    if Macros<>nil then WorkingMacros:=Macros.Clone else begin WorkingMacros:=TMacroRegistry.Create; WorkingMacros.Load('',Directory); end;
    Macros:=WorkingMacros;
  end;
  MacroScopes.Add(Macros);
  try
    if Paragraph and (Generated<>nil) and GeneratedBlock(FSource) then begin
      NativeNode:=Node;
      for FieldIndex:=0 to FNodes.Count-1 do begin
        NativeP:=1; NativeCommand:=ReadTeXCommand(TMathNode(FNodes[FieldIndex]).Text,NativeP);
        if (TMathNode(FNodes[FieldIndex]).Kind=mkCommand) and IsGeneratedCommand(NativeCommand) then begin
          NativeNode:=TMathNode(FNodes[FieldIndex]); Break;
        end;
      end;
      Standalone:=GeneratedBox(NativeNode,Width); Standalone.X:=Max(0,(Width-Standalone.W) div 2); Standalone.Y:=0;
      FRoot.Children.Add(Standalone); Y:=Standalone.H; LineStart:=FRoot.Children.Count;
    end else if Paragraph then Walk(Node,FontSize)
    else begin Standalone:=MathBox(Node,FontSize); X:=Max(10,(Width-Standalone.W) div 2); Append(Standalone); end;
  finally FMacroScopes:=nil; MacroScopes.Free; Macros:=SavedMacros; WorkingMacros.Free; end;
  NewLine; if AfterDisplay then Y:=DisplayBottom+DisplayBelow;
  FieldIndex:=0; for NoteIndex:=0 to High(Footnotes) do if not Footnotes[NoteIndex].Marginal then Inc(FieldIndex);
  if FieldIndex>0 then begin
    Inc(Y,Round(MeasureEm(FontSize)*0.6)); NoteBox:=TDraftBox.Create; NoteBox.Shape:=22; NoteBox.W:=Max(30,Round((Width-20)*0.4)); NoteBox.H:=1; NoteBox.X:=10; NoteBox.Y:=Y;
    FRoot.Children.Add(NoteBox); Inc(Y,Round(MeasureEm(FontSize)*0.5));
    for NoteIndex:=0 to High(Footnotes) do begin
      if Footnotes[NoteIndex].Marginal then Continue;
      NoteBox:=Footnotes[NoteIndex].Box; NoteBox.X:=30; NoteBox.Y:=Y; FRoot.Children.Add(NoteBox); Footnotes[NoteIndex].Box:=nil;
      NoteMark:=NoteMarker(Footnotes[NoteIndex].Number,-1,MathFontPoints(0)-2);
      NoteMark.X:=30-NoteMark.W; NoteMark.Y:=Y+NoteBox.Baseline-NoteMark.Baseline; FRoot.Children.Add(NoteMark);
      Inc(Y,NoteBox.H+2);
    end;
  end;
  Height:=Max(Y,WrapBottom)+10;
  if Paragraph and (Generated<>nil) and GeneratedBlock(FSource) then Height:=Y;
  if (FLayout<>nil) and not Reflow then Height:=Max(Height,Round(FLayout.Height*FScale));
  MarginBottom:=-MaxInt;
  for NoteIndex:=0 to High(Footnotes) do if Footnotes[NoteIndex].Marginal then begin
    NoteBox:=Footnotes[NoteIndex].Box; NoteMark:=Footnotes[NoteIndex].Anchor;
    NoteBox.Y:=Max(NoteMark.Y+NoteMark.Baseline-NoteBox.Baseline,MarginBottom);
    MarginBottom:=NoteBox.Y+NoteBox.H+Round(MarginPush*MarginEm);
    FRoot.Children.Add(NoteBox); Footnotes[NoteIndex].Box:=nil;
  end;
  FBaseHeight:=Height; FPageLines:=nil; FPageOrigins:=nil; FPageGroups:=nil; FAppliedPageShifts:=nil;
  FPageBody:=0; FPageFirst:=0; FPageGap:=0;
  if PageLayout and not ((Generated<>nil) and Generated.IsNative and GeneratedBlock(FSource)) then begin
    for FieldIndex:=0 to FRoot.Children.Count-1 do Dec(TDraftBox(FRoot.Children[FieldIndex]).Y,10);
    Height:=Max(0,Height-20); FBaseHeight:=Height;
    PageLines; PageMarks(Node);
  end;
  Collect(FRoot,0,0); MergeWordRegions;
  finally for NoteIndex:=0 to High(Footnotes) do Footnotes[NoteIndex].Box.Free; SourceIndex.Free; end;
end;
procedure TParagraphDraft.Collect(Box:TDraftBox; X,Y:Integer; Slide:Integer);
var I,N,J,K,Total,GlyphIndex,FirstRegion,FirstLink,FirstToggle:Integer; MeasureText:string; Em:Double; G:TTeXTextGlyph; Ink,Clip,VisibleBounds:TRect; Field:TMathNode;
  procedure IncludeInk(Index,OriginX:Integer; OffsetY:Integer=0);
  begin
    Ink:=TeXGlyphInkBounds(Index,OriginX,Y+Box.Baseline-OffsetY,Em);
    Regions[N].Bounds.Left:=Min(Regions[N].Bounds.Left,Ink.Left);
    Regions[N].Bounds.Right:=Max(Regions[N].Bounds.Right,Ink.Right);
    Regions[N].Bounds.Top:=Min(Regions[N].Bounds.Top,Ink.Top);
    Regions[N].Bounds.Bottom:=Max(Regions[N].Bounds.Bottom,Ink.Bottom);
  end;
begin
  if Box.Covered then Exit;
  if Box.Slide>0 then Slide:=Box.Slide;
  FirstRegion:=Length(Regions); FirstLink:=Length(Links); FirstToggle:=Length(SourceToggles);
  Inc(X,Box.X); Inc(Y,Box.Y);
  if Box.ToggleOffset>=0 then begin
    N:=Length(SourceToggles); SetLength(SourceToggles,N+1);
    SourceToggles[N].Bounds:=Rect(X+(Box.W-28) div 2,Y,X+(Box.W+28) div 2,Y+28);
    SourceToggles[N].PreviewBounds:=Box.Anchor; OffsetRect(SourceToggles[N].PreviewBounds,X,Y);
    SourceToggles[N].Offset:=Box.ToggleOffset; SourceToggles[N].Formula:=Box.ToggleFormula;
    SourceToggles[N].Expanded:=Box.AccentVariant<>0;
  end;
  if Box.LinkOffset>=0 then begin
    N:=Length(Links); SetLength(Links,N+1); Links[N].Bounds:=Rect(X,Y,X+Box.W,Y+Box.H);
    Links[N].Offset:=Box.LinkOffset; Links[N].ID:=Box.ID;
  end;
  if (Box.ID>=0) or (Box.DefinitionArgument>=0) then
  begin
    N:=Length(Regions); SetLength(Regions,N+1);
    Regions[N].ID:=Box.ID; Regions[N].Slide:=Slide; Regions[N].Bounds:=Rect(X,Y,X+Max(3,Box.W),Y+Box.H);
    Regions[N].SourceMapped:=Box.SourceMapped;
    Regions[N].DefinitionArgument:=Box.DefinitionArgument; Regions[N].DefinitionOffset:=Box.DefinitionOffset;
    Regions[N].Baseline:=Box.Baseline;
    if (Box.TextRun.Valid or (Box.Shape=11)) and not Box.Cached and (Box.Text<>'') and (Trim(Box.Text)<>'') then begin
      Regions[N].Bounds.Top:=Y+Box.Baseline-Box.InkAbove;
      Regions[N].Bounds.Bottom:=Y+Box.Baseline+Max(1,Box.InkBelow);
      Em:=MeasureEm(Box.Size); if Box.TextEm>0 then Em:=Box.TextEm;
      if Box.Shape=11 then IncludeInk(Box.Glyph,X)
      else for G in Box.TextRun.Glyphs do begin
        if G.Code=32 then Continue;
        GlyphIndex:=TextGlyph(Box,G.Code,G.Count=1); if GlyphIndex<0 then Continue;
        IncludeInk(GlyphIndex,X+Round(G.X*Em),Round(G.Y*Em));
      end;
      Regions[N].Baseline:=Box.Baseline-(Regions[N].Bounds.Top-Y);
    end;
    if Box.Shape=7 then begin
      Em:=MeasureEm(Box.Size);
      Regions[N].Bounds:=Rect(X+Min(0,Box.W),Min(Y,Y+Box.Baseline-Round(Em*0.75)),
        X+Max(6,Box.W),Max(Y+Box.H,Y+Box.Baseline+4));
      Regions[N].Baseline:=Y+Box.Baseline-Regions[N].Bounds.Top;
    end;
    if Box.SourceMapped then begin
      Em:=MeasureEm(Box.Size);
      Regions[N].Bounds.Top:=Min(Regions[N].Bounds.Top,Y+Box.Baseline-Round(Em*0.75));
      Regions[N].Bounds.Bottom:=Max(Regions[N].Bounds.Bottom,Y+Box.Baseline+Round(Em*0.2));
      Regions[N].Baseline:=Y+Box.Baseline-Regions[N].Bounds.Top;
    end;
    Regions[N].FirstChar:=Box.FirstChar; Regions[N].CharCount:=UTF8Length(Box.Text);
    if Box.CharCount>=0 then Regions[N].CharCount:=Box.CharCount;
    if Length(Box.Stops)>0 then Regions[N].Stops:=Copy(Box.Stops)
    else if (Regions[N].CharCount<=1) or (Box.Shape=11) or (Box.Text='') then
    begin
      { Glyphs and generated objects use their measured bounds. Measuring an
        empty Text for a nonempty source command would collapse every stop. }
      SetLength(Regions[N].Stops,Regions[N].CharCount+1);
      for J:=0 to Regions[N].CharCount do
        Regions[N].Stops[J]:=Round(Box.W*J/Max(1,Regions[N].CharCount));
    end
    else
    begin
      FCanvas.Font.Name:=Box.FontName; FCanvas.Font.Style:=Box.FontStyle;
      if Box.PixelHeight>0 then FCanvas.Font.Height:=-Box.PixelHeight else FCanvas.Font.Size:=Box.Size;
      MeasureText:=Box.Text; if Box.GlyphText<>'' then MeasureText:=Box.GlyphText;
      Total:=Max(1,TeXTextWidth(FCanvas,MeasureText));
      SetLength(Regions[N].Stops,Regions[N].CharCount+1); Regions[N].Stops[0]:=0;
      for J:=1 to Regions[N].CharCount do
        Regions[N].Stops[J]:=Round(Box.W*TeXTextWidth(FCanvas,UTF8Copy(MeasureText,1,J))/Total);
    end;
    if Regions[N].Bounds.Left<X then
      for J:=0 to High(Regions[N].Stops) do Inc(Regions[N].Stops[J],X-Regions[N].Bounds.Left);
    { A default is displayed without adding [value] to the document. Its
      source field remains empty until the user explicitly starts editing. }
    Field:=FieldByID(Box.ID);
    if (Field<>nil) and (MissingOptionalArgument(Field)<>nil) then begin
      Regions[N].FirstChar:=0; Regions[N].CharCount:=0; SetLength(Regions[N].Stops,1);
      Regions[N].Stops[0]:=0;
    end;
  end;
  for I:=0 to Box.Children.Count-1 do Collect(TDraftBox(Box.Children[I]),X,Y,Slide);
  if Box.ClipChildren then begin
    Clip:=Rect(X,Y,X+Box.W,Y+Box.H); K:=FirstRegion;
    for J:=FirstRegion to High(Regions) do if IntersectRect(VisibleBounds,Regions[J].Bounds,Clip) then begin
      Regions[K]:=Regions[J];
      Dec(Regions[K].Baseline,VisibleBounds.Top-Regions[K].Bounds.Top);
      for I:=0 to High(Regions[K].Stops) do
        Regions[K].Stops[I]:=EnsureRange(Regions[K].Stops[I]+Regions[K].Bounds.Left-VisibleBounds.Left,0,VisibleBounds.Width);
      Regions[K].Bounds:=VisibleBounds; Inc(K);
    end;
    SetLength(Regions,K); K:=FirstLink;
    for J:=FirstLink to High(Links) do if IntersectRect(VisibleBounds,Links[J].Bounds,Clip) then begin
      Links[K]:=Links[J]; Links[K].Bounds:=VisibleBounds; Inc(K);
    end;
    SetLength(Links,K); K:=FirstToggle;
    for J:=FirstToggle to High(SourceToggles) do if IntersectRect(VisibleBounds,SourceToggles[J].Bounds,Clip) then begin
      SourceToggles[K]:=SourceToggles[J]; Inc(K);
    end;
    SetLength(SourceToggles,K);
  end;
end;
procedure TParagraphDraft.MergeWordRegions;
var I,J,K,Count,OldCount,TailID,TailChar:Integer; Last:TMathNode;
begin
  TailID:=-1; TailChar:=0;
  if FNodes.Count>0 then begin
    Last:=TMathNode(FNodes.Last);
    if (Last.Kind=mkProse) and not IsCodeField(Last) and
      (MathSourceOffset(Last)-SourceBase+Length(Last.Text)=Length(FSource)) then begin
      TailID:=Last.ID; TailChar:=UTF8Length(TrimRight(Last.Text));
    end;
  end;
  Count:=0;
  for I:=0 to High(Regions) do
  begin
    J:=Count-1;
    if (J>=0) and (Regions[J].ID=Regions[I].ID) and (Regions[J].Slide=Regions[I].Slide) and
       not Regions[J].SourceMapped and not Regions[I].SourceMapped and
       (Regions[J].DefinitionArgument<0) and (Regions[I].DefinitionArgument<0) and
       (Regions[J].FirstChar+Regions[J].CharCount=Regions[I].FirstChar) and
       not ((Regions[I].ID=TailID) and (Regions[I].FirstChar>=TailChar)) and
       (Abs(Regions[J].Bounds.Top-Regions[I].Bounds.Top)<=2) and
       (Regions[I].Bounds.Left>=Regions[J].Bounds.Left) then
    begin
      OldCount:=Regions[J].CharCount;
      Inc(Regions[J].CharCount,Regions[I].CharCount);
      SetLength(Regions[J].Stops,Regions[J].CharCount+1);
      for K:=1 to Regions[I].CharCount do
        if K<Length(Regions[I].Stops) then
          Regions[J].Stops[OldCount+K]:=Regions[I].Bounds.Left-Regions[J].Bounds.Left+Regions[I].Stops[K];
      Regions[J].Bounds.Right:=Max(Regions[J].Bounds.Right,Regions[I].Bounds.Right);
      Regions[J].Bounds.Bottom:=Max(Regions[J].Bounds.Bottom,Regions[I].Bounds.Bottom);
    end
    else
    begin
      if Count<>I then Regions[Count]:=Regions[I];
      Inc(Count);
    end;
  end;
  SetLength(Regions,Count);
end;
function TParagraphDraft.PaintColor(Value:TColor):TColor;
begin if PreserveColors then Result:=Value else Result:=ThemeText(Value); end;
procedure TParagraphDraft.DrawBox(Box:TDraftBox; X,Y:Integer);
var I,J,N,Stroke,GlyphIndex,T:Integer; Em:Double; G:TTeXTextGlyph; Ink:TRect; Metrics:TLCLTextMetric;
    SavedColors:Boolean; Points:array of TPoint; Header:TDraftBox; Hover:TPoint;
  function DisclosureVisible(Part:TDraftBox; Left,Top:Integer):Boolean;
  var Preview,Button:TRect;
  begin
    Preview:=Part.Anchor; OffsetRect(Preview,Left,Top);
    Button:=Rect(Left+(Part.W-28) div 2,Top,Left+(Part.W+28) div 2,Top+28);
    Result:=(Part.AccentVariant<>0) or (PinnedSourceOffset=Part.ToggleOffset+1) or
      ((PinnedSourceOffset=0) and (PtInRect(Preview,Hover) or PtInRect(Button,Hover)));
  end;
  procedure DrawText(const Text:string; Left:Integer);
  var Top:Integer;
  begin
    if Text='' then Exit;
    Top:=Y;
    if FCanvas.GetTextMetrics(Metrics) then Top:=Y+Box.Baseline-Metrics.Ascender;
    FCanvas.TextOut(Left,Top,Text);
  end;
  procedure Delimiter(const Token:string; LeftSide:Boolean);
  var L,T,H,Mid,Sign,GlyphIndex:Integer; V:string;
  begin
    V:=Token; if (V='') or (V='.') then Exit;
    if Box.Shape=5 then begin
      if LeftSide then GlyphIndex:=Box.LeftGlyph else GlyphIndex:=Box.RightGlyph;
      if GlyphIndex>=0 then begin
        Ink:=TeXGlyphInkBounds(GlyphIndex,0,0,MeasureEm(Box.Size));
        H:=Max(1,Ink.Height); Mid:=Max(1,Ink.Width);
        T:=Y+Box.Baseline-Round(MeasureEm(Box.Size)*0.25)-H div 2;
        if LeftSide then L:=X+(Box.LeftWidth-Mid) div 2
        else L:=X+Box.W-Box.RightWidth+(Box.RightWidth-Mid) div 2;
        if DrawTeXGlyph(FCanvas,GlyphIndex,Rect(L,T,L+Mid,T+H),PaintColor(Box.Color),MeasureEm(Box.Size)) then Exit;
      end;
    end;
    L:=X+2; Sign:=1;
    if not LeftSide then begin L:=X+Box.W-2; Sign:=-1; end;
    T:=Y+1; H:=Max(8,Box.H-2);
    if Box.Children.Count>0 then begin
      T:=Y+Max(0,TDraftBox(Box.Children[0]).Y+InkTop(TDraftBox(Box.Children[0]))-2);
      H:=Max(10,Y+TDraftBox(Box.Children[0]).Y+TDraftBox(Box.Children[0]).H-T);
    end; Mid:=T+H div 2;
    if (V='\{') or (V='\}') or (V='\lbrace') or (V='\rbrace') then
    begin
      FCanvas.Polyline([Point(L+6*Sign,T),Point(L+2*Sign,T+2),Point(L+2*Sign,Mid-2),
        Point(L,Mid),Point(L+2*Sign,Mid+2),Point(L+2*Sign,T+H-2),Point(L+6*Sign,T+H)]);
    end
    else if (V='[') or (V=']') or (V='\lbrack') or (V='\rbrack') then
      FCanvas.Polyline([Point(L+6*Sign,T),Point(L,T),Point(L,T+H),Point(L+6*Sign,T+H)])
    else if (V='\lfloor') or (V='\rfloor') then
      FCanvas.Polyline([Point(L,T),Point(L,T+H),Point(L+6*Sign,T+H)])
    else if (V='\lceil') or (V='\rceil') then
      FCanvas.Polyline([Point(L+6*Sign,T),Point(L,T),Point(L,T+H)])
    else if (V='|') or (V='\vert') or (V='\lvert') or (V='\rvert') or (V='\lVert') or (V='\rVert') or (V='\Vert') or (V='\|') then
    begin
      FCanvas.Pen.Width:=1;
      FCanvas.MoveTo(L, T); FCanvas.LineTo(L,T+H);
      if (V='\Vert') or (V='\lVert') or (V='\rVert') or (V='\|') then begin FCanvas.MoveTo(L+3*Sign,T); FCanvas.LineTo(L+3*Sign,T+H); end;
    end
    else if (V='\langle') or (V='\rangle') or (V='<') or (V='>') then
      FCanvas.Polyline([Point(L+6*Sign,T),Point(L,Mid),Point(L+6*Sign,T+H)])
    else
      FCanvas.Polyline([Point(L+6*Sign,T),Point(L+2*Sign,T+H div 4),Point(L,Mid),
        Point(L+2*Sign,T+3*H div 4),Point(L+6*Sign,T+H)]);
  end;
begin
  if Box.Covered then Exit;
  if Box.InterCharacterGlue and (Box.Text='') and (Box.Children.Count=0) then Exit;
  Inc(X,Box.X); Inc(Y,Box.Y);
  Hover:=Point(SourceHover.X+FPaintOrigin.X,SourceHover.Y+FPaintOrigin.Y);
  if (Box.W>0) and (Box.H>0) and (FPaintClip.Right>FPaintClip.Left) and (FPaintClip.Bottom>FPaintClip.Top) then begin
    I:=Max(4,Round(MeasureEm(Box.Size)));
    if (X+Box.W+I<FPaintClip.Left) or (X-I>FPaintClip.Right) or
       (Y+Box.H+I<FPaintClip.Top) or (Y-I>FPaintClip.Bottom) then Exit;
  end;
  SavedColors:=PreserveColors;
  if (Box.Shape=21) or ((Box.Shape=9) and (Box.FillColor<>clNone)) then PreserveColors:=True;
  try
  { Drawing images and filled accents can change native canvas brush state.
    Every box starts with transparent text and an ordinary ink pen. }
  FCanvas.Brush.Style:=bsClear;
  FCanvas.Pen.Color:=PaintColor(Box.Color); FCanvas.Pen.Width:=1; FCanvas.Pen.Style:=psSolid;
  if (Box.Shape=25) and (Box.FillColor<>clNone) then begin
    FCanvas.Brush.Style:=bsSolid; FCanvas.Brush.Color:=PaintColor(Box.FillColor);
    FCanvas.FillRect(Rect(X,Y,X+Box.W,Y+Box.H)); FCanvas.Brush.Style:=bsClear;
  end;
  if Box.Shape=22 then begin
    FCanvas.Brush.Style:=bsSolid; FCanvas.Brush.Color:=PaintColor(Box.Color);
    FCanvas.FillRect(Rect(X,Y,X+Box.W,Y+Box.H)); FCanvas.Brush.Style:=bsClear;
  end;
  if (Box.Shape=9) and (Box.FillColor<>clNone) then begin
    FCanvas.Brush.Style:=bsSolid; FCanvas.Brush.Color:=PaintColor(Box.FillColor);
    FCanvas.FillRect(Rect(X,Y,X+Box.W,Y+Box.H)); FCanvas.Brush.Style:=bsClear;
  end;
  if Box.CodeBackground then begin
    FCanvas.Brush.Style:=bsSolid; FCanvas.Brush.Color:=SourceBackgroundColor;
    FCanvas.FillRect(Rect(X,Y,X+Box.W,Y+Box.H)); FCanvas.Brush.Style:=bsClear;
  end;
  if Box.Shape=20 then begin
    if DisclosureVisible(Box,X,Y) then begin
      FCanvas.Pen.Color:=clGray;
      if Box.AccentVariant<>0 then begin
        FCanvas.Pen.Style:=psDash; FCanvas.Line(X,Y+14,X+Box.W,Y+14); FCanvas.Pen.Style:=psSolid;
      end;
    end;
  end;
  if Box.Shape=24 then begin
    for I:=0 to Box.Children.Count-1 do begin
      Header:=TDraftBox(Box.Children[I]); if Header.Shape<>20 then Continue;
      if not DisclosureVisible(Header,X+Header.X,Y+Header.Y) then Break;
      Ink:=Rect(X,Y,X+Box.W,Y+Box.H);
      if Header.AccentVariant=0 then Ink.Bottom:=Y+Header.Y+1;
      FCanvas.Pen.Color:=clGray; FCanvas.Pen.Style:=psDash; FCanvas.Rectangle(Ink); FCanvas.Pen.Style:=psSolid;
      Break;
    end;
  end;
  if Box.Shape=19 then begin DrawEditorSeparator(FCanvas,Rect(X,Y,X+Box.W,Y+Box.H),Box.Text); Exit; end;
  if Box.Shape=16 then begin Box.Generated.Draw(FCanvas,Rect(X,Y,X+Box.W,Y+Box.H)); Exit; end;
  if Box.Shape=12 then begin
    FCanvas.Pen.Color:=PaintColor(Box.Color); FCanvas.Rectangle(X,Y,X+Box.W,Y+Box.H);
    FCanvas.Pen.Color:=PaintColor(Box.Color);
  end;
  if Box.Shape=21 then begin
    { Paint one frame. Separate rounded title and body frames leave square
      corners and a double rule at the title join. Arc values are diameters. }
    FCanvas.Pen.Style:=psClear; FCanvas.Brush.Style:=bsSolid;
    FCanvas.Brush.Color:=PaintColor(Box.Color);
    FCanvas.RoundRect(X,Y,X+Box.W,Y+Box.H,Box.AccentWidth,Box.AccentWidth);
    I:=Box.AccentHeight;
    FCanvas.Brush.Color:=PaintColor(Box.FillColor);
    FCanvas.RoundRect(X+I,Y+I,X+Box.W-I,Y+Box.H-I,Box.BoxInnerArc,Box.BoxInnerArc);
    if (Box.BoxTitleHeight>I) and (Box.BoxTitleColor<>clNone) then begin
      FCanvas.Brush.Color:=PaintColor(Box.BoxTitleColor);
      FCanvas.RoundRect(X+I,Y+I,X+Box.W-I,Y+Box.BoxTitleHeight+Box.BoxInnerArc,
        Box.BoxInnerArc,Box.BoxInnerArc);
      FCanvas.Brush.Color:=PaintColor(Box.Color);
      FCanvas.FillRect(Rect(X+I,Y+Box.BoxTitleHeight-I,X+Box.W-I,Y+Box.BoxTitleHeight));
      FCanvas.Brush.Color:=PaintColor(Box.FillColor);
      FCanvas.FillRect(Rect(X+I,Y+Box.BoxTitleHeight,X+Box.W-I,
        Min(Y+Box.H-I-Box.BoxInnerArc div 2,Y+Box.BoxTitleHeight+Box.BoxInnerArc+1)));
    end;
    FCanvas.Brush.Style:=bsClear; FCanvas.Pen.Style:=psSolid; FCanvas.Pen.Width:=1;
  end;
  if Box.Shape=15 then begin
    FCanvas.Pen.Color:=PaintColor(Box.Color); FCanvas.Pen.Width:=Max(1,Box.AccentHeight);
    FCanvas.Rectangle(X,Y,X+Box.W,Y+Box.H); FCanvas.Pen.Width:=1;
  end;
  if Box.Shape=18 then begin
    FCanvas.Pen.Color:=clGray; FCanvas.Pen.Width:=1;
    FCanvas.MoveTo(X+1,Y+Box.Baseline-2); FCanvas.LineTo(X+1,Y+Box.Baseline);
    FCanvas.LineTo(X+Box.W-1,Y+Box.Baseline); FCanvas.LineTo(X+Box.W-1,Y+Box.Baseline-2); Exit;
  end;
  if Box.Shape=17 then begin
    FCanvas.Pen.Color:=PaintColor(clGray); I:=X+8;
    FCanvas.MoveTo(I,Y+2); FCanvas.LineTo(I,Y+Box.H-2);
    FCanvas.MoveTo(X+2,Y+2); FCanvas.LineTo(X+14,Y+2);
    FCanvas.MoveTo(X+2,Y+Box.H-2); FCanvas.LineTo(X+14,Y+Box.H-2);
    if Box.H>=20 then begin
      FCanvas.Polyline([Point(I-3,Y+7),Point(I,Y+2),Point(I+3,Y+7)]);
      FCanvas.Polyline([Point(I-3,Y+Box.H-7),Point(I,Y+Box.H-2),Point(I+3,Y+Box.H-7)]);
    end;
  end;
  if Box.Shape=13 then begin
    FCanvas.Pen.Color:=PaintColor(clGray);
    I:=Y+Box.Baseline-2;
    FCanvas.Polyline([Point(X+Box.W-2,Y+Max(2,Box.Baseline div 3)),Point(X+Box.W-2,I),Point(X+2,I)]);
    FCanvas.Polyline([Point(X+5,I-3),Point(X+2,I),Point(X+5,I+3)]); Exit;
  end;
  if Box.Shape=14 then begin
    FCanvas.Pen.Color:=PaintColor(Box.Color);
    FCanvas.MoveTo(X+Round(Box.TextEm*0.06),Y+Box.Baseline);
    FCanvas.LineTo(X+Box.W,Y+Box.Baseline); Exit;
  end;
  if Box.Cached and (FSurface<>nil) and (FPicture<>nil) then
  begin
    FSurface.DrawRegion(FCanvas,Rect(X-Box.ImagePadding,Y-Box.ImagePadding,
      X+Box.ImageWidth+Box.ImagePadding,Y+Box.H+Box.ImagePadding),Box.ImageBounds,FPicture);
    Exit;
  end;
  if (Box.Children.Count=0) and ((Box.Text<>'') or (Box.GlyphText<>'')) and
     not (Box.Shape in [5,8,9,10,11]) and not Box.TextRun.Valid then
  begin
    FCanvas.Font.Name:=Box.FontName; FCanvas.Font.Style:=Box.FontStyle; FCanvas.Font.Color:=PaintColor(Box.Color);
    if Box.PixelHeight>0 then FCanvas.Font.Height:=-Box.PixelHeight else FCanvas.Font.Size:=Box.Size;
    FCanvas.Brush.Style:=bsClear;
    if Box.CodeText then begin
      T:=Y; if FCanvas.GetTextMetrics(Metrics) then T:=Y+Box.Baseline-Metrics.Ascender;
      PaintSourceLine(FCanvas,X,T,Box.Text,Box.CodeComment);
    end else if Box.GlyphText<>'' then DrawText(Box.GlyphText,X) else DrawText(Box.Text,X);
  end;
  if Box.TextRun.Valid then begin
    Em:=MeasureEm(Box.Size); if Box.TextEm>0 then Em:=Box.TextEm;
    for G in Box.TextRun.Glyphs do begin
      if G.Code=32 then Continue;
      GlyphIndex:=TextGlyph(Box,G.Code,G.Count=1);
      if GlyphIndex<0 then begin
        FCanvas.Font.Name:=Box.FontName; FCanvas.Font.Height:=-Box.PixelHeight; FCanvas.Font.Style:=Box.FontStyle;
        FCanvas.Font.Color:=PaintColor(Box.Color); DrawText(Box.Text,X); Break;
      end;
      Ink:=TeXGlyphInkBounds(GlyphIndex,X+Round(G.X*Em),Y+Box.Baseline-Round(G.Y*Em),Em);
      DrawTeXGlyph(FCanvas,GlyphIndex,Ink,PaintColor(Box.Color),Em);
    end;
  end;
  if Box.Hyphenated then begin
    GlyphIndex:=-1;
    if Box.TextRun.Valid then GlyphIndex:=TextGlyph(Box,45);
    if GlyphIndex>=0 then begin
      Em:=MeasureEm(Box.Size); if Box.TextEm>0 then Em:=Box.TextEm;
      Ink:=TeXGlyphInkBounds(GlyphIndex,X+Box.W,Y+Box.Baseline,Em);
      DrawTeXGlyph(FCanvas,GlyphIndex,Ink,PaintColor(Box.Color),Em);
    end else begin
      FCanvas.Font.Name:=Box.FontName; FCanvas.Font.Height:=-Box.PixelHeight; FCanvas.Font.Style:=Box.FontStyle;
      FCanvas.Font.Color:=PaintColor(Box.Color); DrawText('-',X+Box.W);
    end;
  end;
  if Box.Shape=11 then begin
    Em:=MeasureEm(Box.Size); if Box.TextEm>0 then Em:=Box.TextEm;
    Ink:=TeXGlyphInkBounds(Box.Glyph,X,Y+Box.Baseline,Em);
    DrawTeXGlyph(FCanvas,Box.Glyph,Ink,PaintColor(Box.Color),Em);
  end;
  if Box.Shape=8 then begin
    Em:=MeasureEm(Box.Size); Ink:=TeXGlyphInkBounds(Box.Glyph,X,Y+Box.Baseline,Em);
    if not DrawTeXGlyph(FCanvas,Box.Glyph,Ink,PaintColor(Box.Color),Em) then begin
      FCanvas.Font.Name:='Latin Modern Math'; FCanvas.Font.Size:=Box.Size;
      FCanvas.Font.Color:=PaintColor(Box.Color); FCanvas.TextOut(X,Y,Box.Text);
    end;
  end;
  if Box.Shape=9 then begin
    { Paint connected shafts as paths. Separate one-pixel Line calls lose
      endpoints when a shallow curve is rounded to screen coordinates. }
    SetLength(Points,Length(Box.Lines)+1); I:=0;
    while I<Length(Box.Lines) do begin
      Stroke:=Box.Lines[I].Width; if Stroke<=0 then Stroke:=Max(1,Box.AccentHeight);
      FCanvas.Pen.Width:=Stroke; N:=1; Points[0]:=Point(X+Box.Lines[I].A.X,Y+Box.Lines[I].A.Y);
      repeat
        Points[N]:=Point(X+Box.Lines[I].B.X,Y+Box.Lines[I].B.Y);
        if Points[N]<>Points[N-1] then Inc(N);
        J:=I; Inc(I);
      until (I>=Length(Box.Lines)) or (Box.Lines[I].A<>Box.Lines[J].B) or
        (Box.Lines[I].Width<>Box.Lines[J].Width);
      if N>1 then FCanvas.Polyline(Slice(Points,N));
    end;
    FCanvas.Pen.Width:=1;
  end;
  if (Box.Shape=23) and (Length(Box.Lines)>0) then begin
    SetLength(Points,Length(Box.Lines));
    for I:=0 to High(Points) do Points[I]:=Point(X+Box.Lines[I].A.X,Y+Box.Lines[I].A.Y);
    FCanvas.Pen.Width:=Max(1,Round(Box.TextEm));
    if Box.FillColor<>clNone then begin
      FCanvas.Brush.Style:=bsSolid; FCanvas.Brush.Color:=PaintColor(Box.FillColor); FCanvas.Polygon(Points);
    end else FCanvas.Polyline(Points);
    FCanvas.Brush.Style:=bsClear; FCanvas.Pen.Width:=1;
  end;
  if Box.Shape=10 then begin
    if (Box.Surface<>nil) and (Box.Surface.VectorDocument<>nil) then Box.Surface.DrawVector(FCanvas,Rect(X,Y,X+Box.W,Y+Box.H))
    else if (Box.Picture<>nil) and (Box.Picture.Width>0) then Box.Surface.Draw(FCanvas,Rect(X,Y,X+Box.W,Y+Box.H),Box.Picture)
    else begin
      FCanvas.Pen.Color:=clGray; FCanvas.Rectangle(X,Y,X+Box.W,Y+Box.H);
      FCanvas.Font.Name:=Box.FontName; FCanvas.Font.Size:=Box.Size; FCanvas.Font.Color:=clGray;
      FCanvas.TextOut(X+6,Y+6,'Image: '+Box.Text);
    end;
  end;
  if Box.Shape=6 then
  begin
    FCanvas.Pen.Color:=PaintColor(Box.Color); FCanvas.Pen.Width:=1;
    I:=Y+2;
    if Box.Children.Count>0 then I:=Y+TDraftBox(Box.Children[0]).Y+InkTop(TDraftBox(Box.Children[0]))-4;
    if Box.Text='\underline' then I:=Y+Box.H-2;
    if (Box.Text='\hat') or (Box.Text='\widehat') or (Box.Text='\reallywidehat') then begin
      I:=Y+TDraftBox(Box.Children[0]).Y+InkTop(TDraftBox(Box.Children[0]))-Box.AccentHeight-1;
      GlyphIndex:=ChooseTeXGlyph('hat'+IntToStr(Box.AccentVariant));
      if not DrawTeXGlyph(FCanvas,GlyphIndex,Rect(X+(Box.W-Box.AccentWidth) div 2,I,
        X+(Box.W-Box.AccentWidth) div 2+Box.AccentWidth,I+Box.AccentHeight),PaintColor(Box.Color)) then
        FCanvas.Polyline([Point(X+(Box.W-Box.AccentWidth) div 2,I+Box.AccentHeight),
          Point(X+Box.W div 2,I),Point(X+(Box.W+Box.AccentWidth) div 2,I+Box.AccentHeight)]);
    end
    else if (Box.Text='\check') or (Box.Text='\breve') then
      FCanvas.Polyline([Point(X,I),Point(X+Box.W div 2,I+3),Point(X+Box.W,I)])
    else if (Box.Text='\tilde') or (Box.Text='\widetilde') then
      FCanvas.Polyline([Point(X,I+2),Point(X+Box.W div 3,I),Point(X+2*Box.W div 3,I+3),Point(X+Box.W,I+1)])
    else if (Box.Text='\dot') or (Box.Text='\ddot') then
    begin
      I:=Y+TDraftBox(Box.Children[0]).Y+InkTop(TDraftBox(Box.Children[0]))-Box.AccentHeight-1;
      if Box.Glyph>=0 then I:=Y+TDraftBox(Box.Children[0]).Y+InkTop(TDraftBox(Box.Children[0]))-
        Round((TeXGlyphMetrics[Box.Glyph].Above-0.430556)*MeasureEm(Box.Size));
      if not DrawTeXGlyph(FCanvas,Box.Glyph,Rect(X+(Box.W-Box.AccentWidth) div 2+Box.LeftWidth,I,
          X+(Box.W-Box.AccentWidth) div 2+Box.LeftWidth+Box.AccentWidth,I+Box.AccentHeight),PaintColor(Box.Color)) then begin
        FCanvas.Brush.Color:=PaintColor(Box.Color); FCanvas.Brush.Style:=bsSolid;
        if Box.Text='\dot' then FCanvas.Ellipse(X+Box.W div 2-1,I,X+Box.W div 2+2,I+Box.AccentHeight)
        else begin
          FCanvas.Ellipse(X+Box.W div 2-3,I,X+Box.W div 2-1,I+Box.AccentHeight);
          FCanvas.Ellipse(X+Box.W div 2+1,I,X+Box.W div 2+3,I+Box.AccentHeight);
        end;
        FCanvas.Brush.Style:=bsClear;
      end;
    end
    else if (Box.Text='\acute') or (Box.Text='\grave') then
    begin if Box.Text='\acute' then FCanvas.Line(X+Box.W div 2-2,I+3,X+Box.W div 2+2,I) else FCanvas.Line(X+Box.W div 2-2,I,X+Box.W div 2+2,I+3); end
    else begin
      FCanvas.Line(X,I+1,X+Box.W,I+1);
      if Box.Text='\vec' then FCanvas.Polyline([Point(X+Box.W-4,I-1),Point(X+Box.W,I+1),Point(X+Box.W-4,I+3)]);
    end;
  end;
  if Box.Shape=7 then begin
    if Box.Leader>0 then begin
      Em:=MeasureEm(Box.Size);
      if Box.Leader=1 then begin
        FCanvas.Pen.Width:=Max(1,Round(Em*0.04)); FCanvas.Line(X,Y+Box.Baseline,X+Box.W,Y+Box.Baseline);
      end else begin
        Stroke:=Max(1,Round(Em*0.08)); N:=Max(1,Round(Em*0.44));
        FCanvas.Brush.Style:=bsSolid; FCanvas.Brush.Color:=PaintColor(Box.Color);
        I:=N div 2; while I+Stroke<=Box.W do begin
          FCanvas.Ellipse(X+I,Y+Box.Baseline-Stroke,X+I+Stroke,Y+Box.Baseline); Inc(I,N);
        end;
        FCanvas.Brush.Style:=bsClear;
      end;
    end;
    if HideEditingMarks or (Box.ID<0) then Exit;
    FCanvas.Pen.Color:=clGray; FCanvas.Pen.Width:=1;
    FCanvas.Line(X,Y+Box.Baseline+2,X+Box.W,Y+Box.Baseline+2);
    FCanvas.Line(X,Y+Box.Baseline-1,X,Y+Box.Baseline+4);
    FCanvas.Line(X+Box.W,Y+Box.Baseline-1,X+Box.W,Y+Box.Baseline+4);
  end;
  if Box.Shape=5 then
  begin
    FCanvas.Pen.Color:=PaintColor(Box.Color); FCanvas.Pen.Width:=1;
    FCanvas.Pen.Width:=2;
    I:=Pos(#1,Box.Text); Delimiter(Copy(Box.Text,1,I-1),True); Delimiter(Copy(Box.Text,I+1,MaxInt),False); FCanvas.Pen.Width:=1;
  end;
  if Box.Shape=4 then begin
    FCanvas.Pen.Color:=clGray; FCanvas.Pen.Width:=1;
    Delimiter('\{',True); Delimiter('\}',False);
    FCanvas.Pen.Color:=PaintColor(Box.Color);
  end;
  if Box.Shape=3 then
  begin
    FCanvas.Pen.Color:=clGray; FCanvas.Pen.Style:=psDot;
    FCanvas.Rectangle(X+2,Y+2,X+Box.W-2,Y+Box.H-2);
    FCanvas.Pen.Style:=psSolid; FCanvas.Pen.Color:=PaintColor(Box.Color);
  end;
  if Box.Shape=1 then
  begin
    I:=Box.RuleY;
    FCanvas.MoveTo(X+Box.ImagePadding,Y+I); FCanvas.LineTo(X+Box.W-Box.ImagePadding,Y+I);
  end;
  if Box.Shape=2 then
  begin
    if not DrawTeXGlyph(FCanvas,Box.Glyph,Rect(X+Box.RuleY,Y+Box.LeftWidth,
       X+Box.RuleY+Box.AccentWidth,Y+Box.LeftWidth+Box.AccentHeight),PaintColor(Box.Color)) then begin
      FCanvas.Polyline([Point(X+Box.RuleY,Y+Box.AccentHeight div 2),
        Point(X+Box.RuleY+Box.AccentWidth div 3,Y+Box.AccentHeight-1),
        Point(X+Box.RuleY+Box.AccentWidth,Y+Box.LeftWidth)]);
    end;
    FCanvas.Pen.Width:=Max(1,Round(MeasureEm(Box.Size)*0.04));
    I:=TDraftBox(Box.Children[0]).X;
    FCanvas.Line(X+I-1,Y+Box.LeftWidth,X+Box.W,Y+Box.LeftWidth); FCanvas.Pen.Width:=1;
  end;
  if Box.ClipChildren then begin
    FCanvas.SaveHandleState;
    try
      IntersectClipRect(FCanvas.Handle,X,Y,X+Box.W,Y+Box.H);
      for I:=0 to Box.Children.Count-1 do DrawBox(TDraftBox(Box.Children[I]),X,Y);
    finally FCanvas.RestoreHandleState; end;
  end else for I:=0 to Box.Children.Count-1 do DrawBox(TDraftBox(Box.Children[I]),X,Y);
  finally PreserveColors:=SavedColors; end;
end;
procedure TParagraphDraft.PaintSourceControls(Canvas:TCanvas; OffsetX:Integer; OffsetY:Integer);
var Toggle:TDraftSourceToggle; R:TRect;
begin
  for Toggle in SourceToggles do if SourceControlVisible(Toggle) then begin
    R:=Toggle.Bounds; OffsetRect(R,OffsetX,OffsetY);
    DrawSourceDisclosure(Canvas,R,Toggle.Expanded);
  end;
end;
procedure TParagraphDraft.Paint(Canvas:TCanvas; Surface:TPreviewSurface; Picture:TPicture; OffsetX:Integer; OffsetY:Integer; DrawControls:Boolean);
var BrushColor:TColor; BrushStyle:TBrushStyle;
begin
  BrushColor:=Canvas.Brush.Color; BrushStyle:=Canvas.Brush.Style;
  FSurface:=Surface; FPicture:=Picture; FCanvas:=Canvas; FPaintClip:=Canvas.ClipRect;
  FPaintOrigin:=Point(OffsetX,OffsetY);
  Canvas.Font.Color:=InkColor; Canvas.Brush.Style:=bsClear;
  Canvas.Pen.Color:=InkColor; Canvas.Pen.Width:=1;
  try
    if FRoot<>nil then DrawBox(FRoot,OffsetX,OffsetY);
    if DrawControls then PaintSourceControls(Canvas,OffsetX,OffsetY);
  finally
    Canvas.Brush.Color:=BrushColor; Canvas.Brush.Style:=BrushStyle;
  end;
end;
end.
