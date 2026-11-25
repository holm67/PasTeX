unit PagedView;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Graphics, Types,
  MathEditor, TeXDocument, TeXContext, PreviewImage, NativePagination, NativeFloats, SourceRanges,
  DraftLayout, MathModel, TeXMacros, NativePageStyle, PageExpansion;
type
  TPagedEditor=class;
  TPageText=class(TMathEditor)
  protected
    procedure MouseDown(Button:TMouseButton; Shift:TShiftState; X,Y:Integer); override;
    procedure MouseMove(Shift:TShiftState; X,Y:Integer); override;
  public
    Host:TPagedEditor;
  end;
  TNativePage=class(TPreviewPanel)
  private
    FStyle:TPageFurniture;
    FRows:array[0..5] of TParagraphDraft;
    FTrees:array[0..5] of TMathNode;
    FText:array[0..5] of string;
    FPreamble,FDirectory,FEngine:string;
    FRegistry:TMacroRegistry;
    FLeft,FTop,FWidth,FBody:Integer;
    FScale:Double;
    procedure DrawRow(Target:TCanvas; Index,Baseline,OffsetX:Integer);
  protected
    procedure Paint; override;
  public
    destructor Destroy; override;
    procedure ReleaseRenderCache;
    procedure PaintFurniture(Target:TCanvas; Offset:TPoint);
    procedure Configure(const Preamble,Directory,Engine:string; Registry:TMacroRegistry;
      const Style:TPageFurniture; Scale:Double; TextLeft,TextTop,TextWidth,TextHeight:Integer);
  end;
  TPagedEditor=class(TPanel)
  private
    FDocument:TTeXDocument;
    FContext:TTeXContext;
    FFurnitureRegistry:TMacroRegistry;
    FDirectory,FEngine,FCaptionKey:string;
    FSourceFont:TFont;
    FOnChange,FOnSelectionChange:TNotifyEvent;
    FOnGeneratedAction:TGeneratedActionEvent;
    FOnSourceLink:TSourceLinkEvent;
    FZoomPercent:Integer; FFitWidth,FFitPage,FReadOnly,FLoading,FPlacing,FUpdatingViewport:Boolean;
    FViewportQueued,FViewportDirty,FEvictionQueued:Boolean;
    FViewport:TRect;
    FLastCaretBlock,FLastCaret:Integer;
    FSelectionAnchor,FSelectionFocus,FChangedBlock:Integer;
    FSelecting,FApplyingSelection,FHandlingInput:Boolean;
    FPagePass:Integer;
    FBlock,FTextWidth,FPaperWidth,FPaperHeight,FPitch,FTextLeft,FTextTop,FBodyHeight:Integer;
    FScale:Double;
    FContextDue,FReblockDue,FLastUndo:QWord;
    FReblockOffset:Integer;
    FTimer:TTimer;
    FScroll:TScrollBox;
    FMeasure:TMathEditor;
    FPages:array of TNativePage;
    FSourceBoundaries:TSourceBoundaries;
    FFoldedSources:TSourceRanges;
    FBoundaryPanels:array of TPreviewPanel;
    FOnBoundaryClick:TMouseEvent;
    FBlocks:array of record
      Panel:TPreviewPanel;
      Editor:TPageText;
      Base,Flow:TPageBlock;
      Measured,Folded,FullPages:Boolean;
      Before:string;
      PageStyle,ThisPageStyle:string;
    end;
    FUndo,FRedo:TStringList;
    procedure Poll(Sender:TObject);
    procedure ViewportChanged(Sender:TObject);
    procedure RefreshViewport(Data:PtrInt);
    procedure LayoutPages(Sender:TObject);
    procedure LayoutBoundaries(var Flow:TPageBlocks; var PageExtra:TPageShifts);
    procedure BoundaryClick(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
    procedure EditorChanged(Sender:TObject);
    procedure EditorLayout(Sender:TObject);
    procedure EditorBackground(Sender:TObject);
    procedure History(Sender:TObject);
    procedure Redo(Sender:TObject);
    procedure SelectionChanged(Sender:TObject);
    procedure ApplySelection(Editor:TMathEditor; Index:Integer);
    procedure DocumentGesture(Sender:TObject; Position:TPoint; Phase:Integer; Shift:TShiftState);
    procedure DocumentKey(Sender:TObject; Key:Word; Shift:TShiftState; var Handled:Boolean);
    procedure DocumentText(Sender:TObject; const Value:string; var Handled:Boolean);
    function BlockAt(const Position:TPoint):Integer;
    function CrossSelection:Boolean;
    procedure ReplaceSelection(const Value:string);
    procedure GeneratedAction(Sender:TObject; const Command:string; Target:Integer; Configure:Boolean);
    procedure ParagraphBreak(Sender:TObject);
    procedure Boundary(Sender:TObject; Direction:Integer; Merge:Boolean);
    procedure SetActive(Index:Integer);
    procedure Configure(Editor:TMathEditor; Index:Integer);
    function BlockWidth(Index:Integer):Integer;
    function EditorNeeded(Index:Integer):Boolean;
    procedure MeasureBlock(Index:Integer);
    procedure FitEditor(Index:Integer);
    procedure UpdateVisible;
    procedure EvictEditors(Data:PtrInt);
    procedure ClearBlocks;
    function EditorIndex(Sender:TObject):Integer;
    function BlockOffset(Index:Integer):Integer;
    procedure LocateOffset(Offset:Integer; out Index,Local:Integer);
    function BodyEnd:Integer;
    procedure ResetBlocks(Offset:Integer);
    procedure UpdateContext;
    function GetEditor:TMathEditor;
    function GetPageCount:Integer;
  public
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(const Value,Directory,Engine:string);
    procedure SetSourceBoundaries(const Boundaries:TSourceBoundaries; const Folded:TSourceRanges);
    procedure ConfigureSourceFont(SourceFont:TFont);
    procedure UpdatePreamble(const Value,Engine:string);
    procedure ActivateBlock(Index,Offset:Integer);
    function ParagraphEditor(Index:Integer):TMathEditor;
    function Source:string;
    function BlockCount:Integer;
    function SourceOffset:Integer;
    procedure GetSourceSelection(out Anchor,Focus:Integer);
    procedure SetSourceSelection(Anchor,Focus:Integer; Activate:Boolean=True);
    function SelectedSourceRanges:TSourceRanges;
    procedure ReplaceSource(const Value:string; Anchor,Focus:Integer);
    procedure RevealOffset(Offset:Integer);
    procedure RevealPage(Number:Integer);
    function ViewOffset:Integer;
    procedure SetZoom(Percent:Integer; FitWidth:Boolean; FitPage:Boolean=False);
    function ScalePercent:Integer;
    function CurrentPage:Integer;
    procedure Undo;
    procedure RedoEdit;
    procedure Recompile(const Engine:string='');
    property VisualEditor:TMathEditor read GetEditor;
    property EditingBlock:Integer read FBlock;
    property ChangedBlock:Integer read FChangedBlock;
    property PageCount:Integer read GetPageCount;
    property ScrollBox:TScrollBox read FScroll;
    property ReadOnly:Boolean read FReadOnly write FReadOnly;
    property OnChange:TNotifyEvent read FOnChange write FOnChange;
    property OnSelectionChange:TNotifyEvent read FOnSelectionChange write FOnSelectionChange;
    property OnGeneratedAction:TGeneratedActionEvent read FOnGeneratedAction write FOnGeneratedAction;
    property OnSourceLink:TSourceLinkEvent read FOnSourceLink write FOnSourceLink;
    property OnBoundaryClick:TMouseEvent read FOnBoundaryClick write FOnBoundaryClick;
  end;
implementation
uses Math, LCLType, TeXDocumentMetrics, UITheme, EditorClipboard, ParagraphModel, ProseEditing, DocumentOutline, PDFInclusion, BeamerModel, TeXBibliography;
type
  TPageViewport=class(TScrollBox)
  public
    OnViewportChange:TNotifyEvent;
    procedure ScrollBy(DeltaX,DeltaY:Integer); override;
  end;
procedure TPageViewport.ScrollBy(DeltaX,DeltaY:Integer);
begin
  inherited ScrollBy(DeltaX,DeltaY);
  if Assigned(OnViewportChange) then OnViewportChange(Self);
end;
procedure TPageText.MouseDown(Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
begin
  if (Button in [mbLeft,mbRight]) and (Host<>nil) then Host.SetActive(Tag);
  inherited MouseDown(Button,Shift,X,Y);
end;
procedure TPageText.MouseMove(Shift:TShiftState; X,Y:Integer);
begin
  inherited MouseMove(Shift,X,Y);
  if Host<>nil then Host.FitEditor(Tag);
end;
{$I pagefurniture.inc}
constructor TPagedEditor.Create(AOwner:TComponent);
begin
  inherited Create(AOwner); BevelOuter:=bvNone; Caption:=''; FFitWidth:=True; FZoomPercent:=100; FBlock:=-1;
  FSelectionAnchor:=-1; FSelectionFocus:=-1; FChangedBlock:=-1;
  FDocument:=TTeXDocument.Create; FContext:=TTeXContext.Create; FUndo:=TStringList.Create; FRedo:=TStringList.Create;
  FFurnitureRegistry:=TMacroRegistry.Create;
  FContext.NativePageLayout:=True;
  FSourceFont:=TFont.Create;
  FScroll:=TPageViewport.Create(Self); FScroll.Parent:=Self; FScroll.Align:=alClient; FScroll.OnResize:=@LayoutPages;
  TPageViewport(FScroll).OnViewportChange:=@ViewportChanged;
  FScroll.VertScrollBar.Tracking:=True; FScroll.HorzScrollBar.Tracking:=True;
  FViewportDirty:=True;
  { The page range is explicit. Virtualized child visibility must not shrink it. }
  FScroll.AutoScroll:=False; FLastCaretBlock:=-1; FLastCaret:=-1;
  FMeasure:=TMathEditor.Create(Self); FMeasure.Parent:=Self; FMeasure.Visible:=False; FMeasure.ReadOnly:=True;
  FTimer:=TTimer.Create(Self); FTimer.Interval:=80; FTimer.OnTimer:=@Poll; ApplyTheme(Self);
end;
destructor TPagedEditor.Destroy;
begin
  FLoading:=True; FTimer.Enabled:=False; FOnChange:=nil; FOnSelectionChange:=nil;
  Application.RemoveAsyncCalls(Self); TPageViewport(FScroll).OnViewportChange:=nil;
  FScroll.OnResize:=nil; ClearBlocks;
  FContext.Free; FDocument.Free; FSourceFont.Free; FUndo.Free; FRedo.Free; FFurnitureRegistry.Free;
  inherited;
end;
procedure DetachPageEditor(Editor:TPageText);
begin
  if Editor=nil then Exit;
  Editor.Host:=nil; Editor.OnChange:=nil; Editor.OnLayout:=nil; Editor.OnSelectionChange:=nil;
  Editor.OnParagraphBreak:=nil; Editor.OnBoundary:=nil; Editor.OnUndo:=nil; Editor.OnRedo:=nil;
  Editor.OnBackgroundPaint:=nil; Editor.OnGeneratedAction:=nil; Editor.OnSourceLink:=nil;
  Editor.OnDocumentGesture:=nil; Editor.OnDocumentKey:=nil; Editor.OnDocumentText:=nil;
  Editor.CancelSelectionDrag;
end;
procedure TPagedEditor.ClearBlocks;
var I:Integer; Editor:TPageText;
begin
  FBlock:=-1;
  for I:=0 to High(FBlocks) do begin
    Editor:=FBlocks[I].Editor; FBlocks[I].Editor:=nil;
    DetachPageEditor(Editor);
    if FHandlingInput then begin
      { A native key/mouse callback can still be using this editor's handle. }
      FBlocks[I].Panel.Visible:=False;
      Application.ReleaseComponent(FBlocks[I].Panel); FBlocks[I].Panel:=nil;
    end else FreeAndNil(FBlocks[I].Panel);
  end;
  FBlocks:=nil;
end;
function TPagedEditor.EditorIndex(Sender:TObject):Integer;
var Index:Integer;
begin
  Result:=-1; if not (Sender is TPageText) then Exit;
  Index:=TPageText(Sender).Tag;
  if (Index>=0) and (Index<Length(FBlocks)) and (Index<FDocument.Blocks.Count) and
     (FBlocks[Index].Editor=Sender) then Result:=Index;
end;
function TPagedEditor.BlockOffset(Index:Integer):Integer;
begin Result:=FDocument.SourceOffset(Index,0); end;
procedure TPagedEditor.LocateOffset(Offset:Integer; out Index,Local:Integer);
begin FDocument.LocateOffset(Offset,Index,Local); end;
function TPagedEditor.BodyEnd:Integer;
begin Result:=BlockOffset(FDocument.Blocks.Count); end;
function TPagedEditor.Source:string;
begin Result:=FDocument.Source; end;
function TPagedEditor.BlockCount:Integer;
begin Result:=FDocument.Blocks.Count; end;
function TPagedEditor.GetPageCount:Integer;
begin Result:=Length(FPages); end;
function TPagedEditor.GetEditor:TMathEditor;
begin
  if (FBlock>=0) and (FBlock<Length(FBlocks)) and (FBlocks[FBlock].Editor<>nil) then Result:=FBlocks[FBlock].Editor else Result:=FMeasure;
end;
procedure TPagedEditor.ConfigureSourceFont(SourceFont:TFont);
var I:Integer; MetricsChanged:Boolean;
begin
  MetricsChanged:=(FSourceFont.Name<>SourceFont.Name) or (Abs(FSourceFont.Height)<>Abs(SourceFont.Height));
  FSourceFont.Assign(SourceFont); FMeasure.ConfigureSourceFont(SourceFont);
  for I:=0 to High(FBlocks) do begin
    if MetricsChanged then FBlocks[I].Measured:=False;
    if FBlocks[I].Editor<>nil then FBlocks[I].Editor.ConfigureSourceFont(SourceFont);
  end;
  if MetricsChanged and not FLoading then LayoutPages(nil);
end;
procedure TPagedEditor.Load(const Value,Directory,Engine:string);
var Index,Caret,Position:Integer;
begin
  Index:=FBlock; Caret:=VisualEditor.SourceCaret; Position:=FScroll.VertScrollBar.Position;
  FDirectory:=Directory; FEngine:=Engine; FDocument.ParseFile(Value); FUndo.Clear; FRedo.Clear;
  FContextDue:=0; FReblockDue:=0;
  if (Index>=0) and (Index<FDocument.Blocks.Count) then ResetBlocks(FDocument.SourceOffset(Index,Caret)) else ResetBlocks(0);
  SetPreviewScroll(FScroll,0,Position);
end;
procedure TPagedEditor.UpdatePreamble(const Value,Engine:string);
var I,A,B,Delta:Integer; Editor:TMathEditor;
begin
  if (Value=FDocument.Preamble) and (Engine=FEngine) then Exit;
  Delta:=Length(Value)-Length(FDocument.Preamble);
  if FSelectionAnchor>=0 then Inc(FSelectionAnchor,Delta);
  if FSelectionFocus>=0 then Inc(FSelectionFocus,Delta);
  if FReblockDue<>0 then Inc(FReblockOffset,Delta);
  FDocument.Preamble:=Value; FEngine:=Engine; FLoading:=True; FContextDue:=0;
  try
    UpdateContext;
    for I:=0 to High(FBlocks) do begin
      FBlocks[I].Measured:=False; Editor:=FBlocks[I].Editor; if Editor=nil then Continue;
      Configure(Editor,I);
      Editor.GetSourceSelection(A,B); Editor.LoadParagraph(FDocument.Blocks[I],nil); Editor.SetSourceSelection(A,B);
      if not EditorNeeded(I) then Editor.ReleaseRenderCache;
    end;
    LayoutPages(nil);
  finally FLoading:=False; end;
  if Assigned(FOnSelectionChange) then FOnSelectionChange(Self);
end;
procedure TPagedEditor.UpdateContext;
var I:Integer; Declarations,FileName,Pages,Options:string; Revision:QWord; ContextChanged,Presentation:Boolean;
begin
  Revision:=FContext.LayoutRevision; FContext.Load(Source,FDirectory,FEngine);
  ContextChanged:=Revision<>FContext.LayoutRevision; Declarations:='';
  FFurnitureRegistry.Load(FDocument.Preamble,FDirectory,FEngine);
  Presentation:=FFurnitureRegistry.Presentation;
  for I:=0 to High(FBlocks) do begin
    { Retain hidden measurements on text-only edits. Recreating every visited
      editor here defeats cache eviction and makes typing slower after scrolling. }
    if ContextChanged or (FBlocks[I].Before<>Declarations) then FBlocks[I].Measured:=False;
    FBlocks[I].Before:=Declarations;
    FBlocks[I].FullPages:=ReadPDFInclusion(FDocument.Blocks[I],FileName,Pages,Options);
    if Presentation and BeamerFrameBlock(FDocument.Blocks[I]) then FBlocks[I].FullPages:=True;
    FBlocks[I].Base.FullPages:=FBlocks[I].FullPages and not FBlocks[I].Folded;
    Declarations:=Declarations+TeXContextDeclarations(FDocument.Blocks[I]);
    FBlocks[I].PageStyle:=PageStyleCommands(FDocument.Blocks[I],False);
    FBlocks[I].ThisPageStyle:=PageStyleCommands(FDocument.Blocks[I],True);
    if EditorNeeded(I) then begin Configure(FBlocks[I].Editor,I); if FBlocks[I].Editor.LayoutPending then FBlocks[I].Measured:=False; end;
  end;
end;
procedure TPagedEditor.ResetBlocks(Offset:Integer);
var I,Index,Local:Integer;
begin
  FLoading:=True;
  try
    ClearBlocks; FSelectionAnchor:=-1; FSelectionFocus:=-1; FSelecting:=False;
    FCaptionKey:=''; FLastCaretBlock:=-1; FLastCaret:=-1;
    FChangedBlock:=-1; SetLength(FBlocks,FDocument.Blocks.Count);
    for I:=0 to High(FBlocks) do begin
      FBlocks[I].Panel:=TPreviewPanel.Create(Self); FBlocks[I].Panel.Parent:=FScroll;
      FBlocks[I].Panel.BevelOuter:=bvNone; FBlocks[I].Panel.Color:=PaperColor; FBlocks[I].Panel.Visible:=False;
    end;
    FTextWidth:=0; UpdateContext; LayoutPages(nil);
    if Length(FBlocks)>0 then begin
      LocateOffset(Offset,Index,Local);
      SetActive(Index); VisualEditor.SetSourceCaret(Local);
    end else begin
      for I:=0 to High(FPages) do FPages[I].Free;
      FPages:=nil; FScroll.VertScrollBar.Range:=0; FScroll.HorzScrollBar.Range:=0;
      SetPreviewScroll(FScroll,0,0);
    end;
  finally FLoading:=False; end;
end;
procedure TPagedEditor.Configure(Editor:TMathEditor; Index:Integer);
begin
  Editor.PagedEditing:=True; Editor.SetContext(FDocument.Preamble,FDirectory,FEngine,'',False);
  Editor.TextAreaWidth:=BlockWidth(Index);
  Editor.SetDocumentContext(FDocument.Blocks,Index,FContext,FBlocks[Index].Before,BlockOffset(Index)-Length(FDocument.Preamble));
  Editor.SetFoldedRanges(FFoldedSources,BlockOffset(Index),Length(FDocument.Blocks[Index]));
  Editor.PreviewZoom:=FScale;
end;
function TPagedEditor.BlockWidth(Index:Integer):Integer;
begin
  Result:=FTextWidth; if FBlocks[Index].Base.FullPages then Result:=FPaperWidth+20;
end;
function TPagedEditor.EditorNeeded(Index:Integer):Boolean;
begin
  Result:=(FBlocks[Index].Editor<>nil) and ((Index=FBlock) or FBlocks[Index].Panel.Visible or
    FBlocks[Index].Editor.PageSourcesExpanded or FBlocks[Index].Editor.DefinitionSourceEditing);
end;
procedure TPagedEditor.MeasureBlock(Index:Integer);
var Editor:TMathEditor;
begin
  FBlocks[Index].Base.FullPages:=FBlocks[Index].FullPages;
  Editor:=nil; if EditorNeeded(Index) then Editor:=FBlocks[Index].Editor;
  if Editor<>nil then begin Configure(Editor,Index); Editor.Width:=BlockWidth(Index); end;
  if (Editor=nil) or Editor.PageSourcesExpanded then begin
    Editor:=FMeasure; Configure(Editor,Index); Editor.Width:=BlockWidth(Index);
    Editor.LoadParagraph(FDocument.Blocks[Index],nil);
  end;
  FBlocks[Index].Base.NativeHeight:=Editor.NativeHeight; FBlocks[Index].Base.Lines:=Copy(Editor.PageLines);
  FBlocks[Index].Folded:=Editor.SourceFolded;
  if FBlocks[Index].Folded then begin
    FBlocks[Index].Base.NativeHeight:=0; FBlocks[Index].Base.Lines:=nil;
    FBlocks[Index].Base.FullPages:=False;
  end;
  if FFurnitureRegistry.Presentation and (Length(FBlocks[Index].Base.Lines)=0) then FBlocks[Index].Base.NativeHeight:=0;
  FBlocks[Index].Measured:=True;
  ReadPageFloat(FDocument.Blocks[Index],FBlocks[Index].Base.FloatKind,FBlocks[Index].Base.Placement);
end;
function TPagedEditor.ParagraphEditor(Index:Integer):TMathEditor;
var Editor:TPageText;
begin
  if (Index<0) or (Index>High(FBlocks)) then Exit(nil);
  Editor:=FBlocks[Index].Editor;
  if Editor=nil then begin
    Editor:=TPageText.Create(FBlocks[Index].Panel); FBlocks[Index].Editor:=Editor;
    Editor.Host:=Self; Editor.Tag:=Index; Editor.Name:='NativeParagraph'+IntToStr(Index); Editor.Parent:=FBlocks[Index].Panel;
    Editor.ReadOnly:=True; Editor.ConfigureSourceFont(FSourceFont); Configure(Editor,Index);
    Editor.Width:=BlockWidth(Index); Editor.LoadParagraph(FDocument.Blocks[Index],nil);
    Editor.OnChange:=@EditorChanged; Editor.OnLayout:=@EditorLayout; Editor.OnSelectionChange:=@SelectionChanged;
    Editor.OnParagraphBreak:=@ParagraphBreak; Editor.OnBoundary:=@Boundary; Editor.OnUndo:=@History; Editor.OnRedo:=@Redo;
    Editor.OnBackgroundPaint:=@EditorBackground;
    Editor.OnGeneratedAction:=@GeneratedAction;
    Editor.OnSourceLink:=FOnSourceLink;
    Editor.OnDocumentGesture:=@DocumentGesture; Editor.OnDocumentKey:=@DocumentKey; Editor.OnDocumentText:=@DocumentText;
    Editor.PopupMenu:=PopupMenu;
    ApplySelection(Editor,Index);
  end else Configure(Editor,Index);
  Editor.ConfigurePageLayout(FBlocks[Index].Flow.Shifts,Max(0,FBlocks[Index].Flow.Height),FBodyHeight);
  { Visible cards may retain their height after evicting drawing data. Restore
    the layout before sizing margin notes and other content outside the body. }
  Editor.NativeHeight;
  FitEditor(Index); Result:=Editor;
end;
procedure TPagedEditor.FitEditor(Index:Integer);
var Editor:TMathEditor; H,W,X:Integer;
begin
  if (Index<0) or (Index>High(FBlocks)) then Exit;
  Editor:=FBlocks[Index].Editor; if Editor=nil then Exit;
  H:=Max(FBlocks[Index].Flow.Height,Editor.PreferredHeight);
  W:=Editor.PreferredWidth;
  X:=FTextLeft;
  if FBlocks[Index].Base.FullPages then X:=Max(16,(FScroll.ClientWidth-FPaperWidth) div 2)-10;
  FBlocks[Index].Panel.SetDocumentBounds(X-Editor.MarginLeft,FBlocks[Index].Flow.Top,W,H);
  Editor.SetBounds(0,0,W,H);
end;
procedure TPagedEditor.SetActive(Index:Integer);
begin
  if (Index<0) or (Index>High(FBlocks)) then Exit;
  if (FBlock>=0) and (FBlock<>Index) and (FBlocks[FBlock].Editor<>nil) then begin
    FBlocks[FBlock].Editor.FinishCommand; FBlocks[FBlock].Editor.FinishEmptyScript(True);
    FBlocks[FBlock].Editor.FinishDefinitionEdit; FBlocks[FBlock].Editor.ReadOnly:=True; FBlocks[FBlock].Editor.Invalidate;
  end;
  FBlock:=Index; ParagraphEditor(Index).ReadOnly:=FReadOnly;
end;
procedure TPagedEditor.ActivateBlock(Index,Offset:Integer);
begin
  FSelectionAnchor:=-1; FSelectionFocus:=-1;
  SetActive(Index); if FBlock<>Index then Exit;
  FLastCaretBlock:=-1;
  VisualEditor.SetSourceCaret(Offset);
  Offset:=BlockOffset(Index)+VisualEditor.SourceCaret; SetSourceSelection(Offset,Offset);
  if VisualEditor.CanFocus then VisualEditor.SetFocus; SelectionChanged(VisualEditor);
end;
procedure TPagedEditor.SetSourceBoundaries(const Boundaries:TSourceBoundaries; const Folded:TSourceRanges);
var I:Integer; Same:Boolean; Panel:TPreviewPanel;
begin
  Same:=Length(Boundaries)=Length(FSourceBoundaries);
  if Same then for I:=0 to High(Boundaries) do
    if (Boundaries[I].Offset<>FSourceBoundaries[I].Offset) or
       (Boundaries[I].Caption<>FSourceBoundaries[I].Caption) or
       (Boundaries[I].Path<>FSourceBoundaries[I].Path) or
       (Boundaries[I].Ending<>FSourceBoundaries[I].Ending) then begin Same:=False; Break; end;
  Same:=Same and (Length(Folded)=Length(FFoldedSources));
  if Same then for I:=0 to High(Folded) do
    if (Folded[I].Start<>FFoldedSources[I].Start) or (Folded[I].Finish<>FFoldedSources[I].Finish) then begin Same:=False; Break; end;
  if Same then Exit;
  FSourceBoundaries:=Copy(Boundaries); FFoldedSources:=Copy(Folded);
  for I:=0 to High(FBlocks) do begin
    FBlocks[I].Measured:=False;
    if FBlocks[I].Editor<>nil then Configure(FBlocks[I].Editor,I);
  end;
  while Length(FBoundaryPanels)>Length(Boundaries) do begin
    FBoundaryPanels[High(FBoundaryPanels)].Free; SetLength(FBoundaryPanels,Length(FBoundaryPanels)-1);
  end;
  while Length(FBoundaryPanels)<Length(Boundaries) do begin
    I:=Length(FBoundaryPanels); SetLength(FBoundaryPanels,I+1);
    Panel:=TPreviewPanel.Create(Self); FBoundaryPanels[I]:=Panel; Panel.Parent:=FScroll;
    Panel.Name:='PageSubfileBoundary'+IntToStr(I); Panel.Caption:=''; Panel.BevelOuter:=bvNone;
    Panel.DoubleSeparator:=True; Panel.ParentBackground:=False; Panel.Cursor:=crHandPoint;
    Panel.OnMouseDown:=@BoundaryClick; Panel.Hint:='Click to show/hide; Ctrl+click to open the subfile'; Panel.ShowHint:=True;
  end;
  for I:=0 to High(FBoundaryPanels) do begin
    FBoundaryPanels[I].SeparatorCaption:=Boundaries[I].Caption; FBoundaryPanels[I].HelpKeyword:=Boundaries[I].Path;
    FBoundaryPanels[I].HelpContext:=Ord(Boundaries[I].Ending);
  end;
  if (FBlock>=0) and (FBlocks[FBlock].Editor<>nil) and FBlocks[FBlock].Editor.SourceFolded then begin
    FBlocks[FBlock].Editor.ReadOnly:=True;
    for I:=0 to High(FBlocks) do
      if not SourceCovered(FDocument.Blocks[I],ClipSourceRanges(Folded,BlockOffset(I),Length(FDocument.Blocks[I]))) then begin
        SetActive(I); Break;
      end;
  end;
  LayoutPages(nil);
end;
procedure TPagedEditor.BoundaryClick(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
begin if Assigned(FOnBoundaryClick) then FOnBoundaryClick(Sender,Button,Shift,X,Y); end;
procedure TPagedEditor.LayoutBoundaries(var Flow:TPageBlocks; var PageExtra:TPageShifts);
var Gaps:TPageGaps; I,Index,Local,Y:Integer;
  function Edge(const Block:TPageBlock; Offset:Integer; Ending:Boolean):Integer;
  var J:Integer;
  begin
    Result:=Block.Top; if Length(Block.Lines)=0 then Exit;
    J:=0;
    while (J<High(Block.Lines)) and (Block.Lines[J+1].SourceOffset<=Offset) do Inc(J);
    if Ending then Inc(Result,Block.Lines[J].Bottom+Block.Shifts[J]+Block.Lines[J].EditorSpace)
    else Inc(Result,Block.Lines[J].Top+Block.Shifts[J]);
  end;
begin
  if Length(FSourceBoundaries)=0 then Exit;
  SetLength(Gaps,Length(FSourceBoundaries));
  for I:=0 to High(Gaps) do begin
    LocateOffset(Max(0,FSourceBoundaries[I].Offset-Ord(FSourceBoundaries[I].Ending)),Index,Local);
    Index:=EnsureRange(Index,0,High(Flow)); FBoundaryPanels[I].Tag:=Index;
    { Use the source line, not the panel padding or a following clearpage.
      Adjacent panels may overlap their padding around heading ink. }
    Gaps[I].Position:=Edge(Flow[Index],Local,FSourceBoundaries[I].Ending);
    Y:=Edge(FBlocks[Index].Base,Local,FSourceBoundaries[I].Ending)-Ord(FSourceBoundaries[I].Ending);
    Gaps[I].Height:=28; Gaps[I].Page:=EnsureRange(Y div Max(1,FPitch),0,High(PageExtra));
  end;
  InsertPageGaps(Flow,Gaps,PageExtra);
  for I:=0 to High(Gaps) do begin
    Y:=18+FTextTop+Gaps[I].Position;
    if Flow[FBoundaryPanels[I].Tag].FullPages then Dec(Y,FTextTop);
    FBoundaryPanels[I].Color:=PaperColor;
    FBoundaryPanels[I].SetDocumentBounds(FTextLeft,Y,FTextWidth,Gaps[I].Height);
  end;
end;
procedure TPagedEditor.LayoutPages(Sender:TObject);
var I,J,PageWidth,Anchor,AnchorTop,ScrollY,ScrollX,OldWidth,Count,Extra:Integer;
    Pages,SourcePages:TSourcePages; Flow:TPageBlocks; Expanded:TExpandedPageLines; PageExtra:TPageShifts; Revision:QWord; Reflow:Boolean;
    PageSetup,PageHere,LeftMarks,RightMarks:array of string;
    Outline:TOutlineEntries; Entry:TOutlineEntry; Mark:TContextMark; Heading,Settings:string;
    Paper,PaperHeight,MarginLeft,MarginTop,TextWidth,TextHeight,AnchorFraction:Double;
begin
  if FPlacing or FUpdatingViewport or (Length(FBlocks)=0) then Exit; FPlacing:=True;
  ScrollY:=FScroll.VertScrollBar.Position; ScrollX:=FScroll.HorzScrollBar.Position; Anchor:=-1; AnchorFraction:=0;
  { Floats can precede their source paragraph on a page. Anchor by geometry. }
  for I:=0 to High(FBlocks) do if FBlocks[I].Flow.Top<=ScrollY then
    if (Anchor<0) or (FBlocks[I].Flow.Top>FBlocks[Anchor].Flow.Top) then Anchor:=I;
  if Anchor>=0 then AnchorFraction:=(ScrollY-FBlocks[Anchor].Flow.Top)/Max(1,FBlocks[Anchor].Flow.Height);
  AnchorTop:=0; if Anchor>=0 then AnchorTop:=FBlocks[Anchor].Flow.Top;
  Reflow:=False;
  try
    DocumentPaperSize(FDocument.Preamble,Paper,PaperHeight); DocumentPageArea(FDocument.Preamble,MarginLeft,MarginTop,TextWidth,TextHeight);
    if FFitWidth or FFitPage then PageWidth:=Max(160,PreviewLayoutWidth(FScroll)-48) else PageWidth:=Max(160,Round(Paper*96/72.27*FZoomPercent/100));
    if FFitPage then PageWidth:=Max(80,Min(PageWidth,Floor(Max(80,FScroll.ClientHeight-36)*Paper/PaperHeight)));
    FScale:=PageWidth/(Paper*120/72.27); FPaperWidth:=PageWidth; FPaperHeight:=Round(PageWidth*PaperHeight/Paper); FPitch:=FPaperHeight+24;
    OldWidth:=FTextWidth; FTextWidth:=Max(80,Round(TextWidth*120/72.27*FScale)+20);
    FTextLeft:=Max(16,(FScroll.ClientWidth-PageWidth) div 2)+Round(MarginLeft*PageWidth/Paper)-10;
    FTextTop:=Round(MarginTop*PageWidth/Paper); FBodyHeight:=Max(40,Round(TextHeight*PageWidth/Paper));
    SetLength(Flow,Length(FBlocks)); SetLength(Expanded,Length(FBlocks));
    for I:=0 to High(FBlocks) do begin
      if (OldWidth<>FTextWidth) or not FBlocks[I].Measured then MeasureBlock(I);
      Flow[I]:=FBlocks[I].Base;
      Expanded[I]:=FBlocks[I].Base.Lines;
      if not FBlocks[I].Folded and (FBlocks[I].Editor<>nil) and
        (FBlocks[I].Editor.PageSourcesExpanded or FBlocks[I].Editor.PageHovering or (I=FBlock)) then
        Expanded[I]:=FBlocks[I].Editor.PageEditingLines;
    end;
    Count:=LayoutPageBlocks(Flow,FloatPageSettings(FDocument.Preamble,FBodyHeight,FPitch,PageWidth/Paper));
    SetLength(Pages,Length(FBlocks));
    for I:=0 to High(FBlocks) do begin
      FBlocks[I].Base:=Flow[I];
      Pages[I].Offset:=BlockOffset(I);
      Pages[I].Page:=PageBlockFirstPage(Flow[I],FPitch);
    end;
    SourcePages:=PageSourceMap(Flow,Pages,FPitch);
    ExpandPageSources(Flow,Expanded,FPitch,Count,PageExtra);
    LayoutBoundaries(Flow,PageExtra);
    for I:=0 to High(FBlocks) do begin
      FBlocks[I].Flow:=Flow[I]; Inc(FBlocks[I].Flow.Top,18+FTextTop);
      if Flow[I].FullPages then Dec(FBlocks[I].Flow.Top,FTextTop);
      FBlocks[I].Panel.SetDocumentBounds(FTextLeft,FBlocks[I].Flow.Top,FTextWidth,Flow[I].Height);
      if FBlocks[I].Editor<>nil then begin
        FBlocks[I].Editor.ConfigurePageLayout(Flow[I].Shifts,Max(0,Flow[I].Height),FBodyHeight);
        if EditorNeeded(I) then FitEditor(I);
      end;
    end;
    Revision:=FContext.PageRevision; FContext.SetNativePages(SourcePages);
    if Revision<>FContext.PageRevision then for I:=0 to High(FBlocks) do
      if IsGeneratedTeXBlock(FDocument.Blocks[I]) or HasPageReferences(FDocument.Blocks[I]) or
        (Pos('\marginpar',FDocument.Blocks[I])>0) then begin
        FBlocks[I].Measured:=False; Reflow:=True;
        if FBlocks[I].Editor<>nil then FBlocks[I].Editor.InvalidateContext;
      end;
    while Length(FPages)>Count do begin FPages[High(FPages)].Free; SetLength(FPages,Length(FPages)-1); end;
    while Length(FPages)<Count do begin
      I:=Length(FPages); SetLength(FPages,I+1); FPages[I]:=TNativePage.Create(Self); FPages[I].Name:='NativePage'+IntToStr(I+1);
      FPages[I].Parent:=FScroll; FPages[I].Tag:=I; FPages[I].BevelOuter:=bvNone; FPages[I].Color:=PaperColor; FPages[I].SendToBack;
    end;
    SetLength(PageSetup,Count); SetLength(PageHere,Count); SetLength(LeftMarks,Count); SetLength(RightMarks,Count);
    for I:=0 to High(FBlocks) do begin
      J:=EnsureRange(Pages[I].Page-1,0,Count-1);
      PageSetup[J]:=PageSetup[J]+FBlocks[I].PageStyle; PageHere[J]:=PageHere[J]+FBlocks[I].ThisPageStyle;
      if FBlocks[I].Base.FullPages then
        for Extra:=J to Min(Count-1,J+Length(FBlocks[I].Base.Lines)-1) do PageHere[Extra]:='\thispagestyle{empty}';
      if Pos('\maketitle',FDocument.Blocks[I])>0 then PageHere[J]:=PageHere[J]+'\thispagestyle{plain}';
    end;
    Outline:=DocumentOutlineEntries(FDocument.Blocks);
    for Entry in Outline do if (Entry.Group=0) and (Entry.BlockIndex>=0) and
      ((Entry.Command='chapter') or (Entry.Command='section') or (Entry.Command='subsection')) then begin
      J:=EnsureRange(Pages[Entry.BlockIndex].Page-1,0,Count-1); Heading:=Entry.Target;
      Mark:=FContext.Mark(BlockOffset(Entry.BlockIndex)+Entry.Offset);
      if (Mark<>nil) and (Mark.Number<>'') then Heading:=Mark.Number+'\quad '+Heading;
      Heading:=PageHeadingMark(Heading,False);
      if (Entry.Command='chapter') or (Entry.Command='section') then LeftMarks[J]:='\MakeUppercase{'+Heading+'}'
      else RightMarks[J]:=Heading;
      if (Entry.Command='chapter') then PageHere[J]:=PageHere[J]+'\thispagestyle{plain}';
    end;
    Settings:=FDocument.Preamble; Extra:=0;
    for I:=0 to High(FPages) do begin
      Settings:=Settings+PageSetup[I];
      if I>0 then begin
        if LeftMarks[I]='' then LeftMarks[I]:=LeftMarks[I-1];
        if RightMarks[I]='' then RightMarks[I]:=RightMarks[I-1];
      end;
      FPages[I].Color:=PaperColor;
      FPages[I].SetDocumentBounds(Max(16,(FScroll.ClientWidth-PageWidth) div 2),18+I*FPitch+Extra,PageWidth,FPaperHeight+PageExtra[I]);
      FPages[I].Configure(FDocument.Preamble,FDirectory,FEngine,FFurnitureRegistry,
        PageFurniture(Settings+PageHere[I],I+1,LeftMarks[I],RightMarks[I]),FScale,
        FTextLeft-FPages[I].DocumentOrigin.X+10,FTextTop,FTextWidth-20,FBodyHeight+PageExtra[I]);
      Inc(Extra,PageExtra[I]);
    end;
    FScroll.Color:=UIBackground; FScroll.VertScrollBar.Range:=18+Count*FPitch+Extra; FScroll.HorzScrollBar.Range:=Max(FScroll.ClientWidth,PageWidth+48);
    FScroll.VertScrollBar.Page:=Max(1,FScroll.ClientHeight); FScroll.HorzScrollBar.Page:=Max(1,FScroll.ClientWidth);
    if (Anchor>=0) and (OldWidth<>0) then begin
      if OldWidth<>FTextWidth then ScrollY:=FBlocks[Anchor].Flow.Top+Round(AnchorFraction*FBlocks[Anchor].Flow.Height)
      else Inc(ScrollY,FBlocks[Anchor].Flow.Top-AnchorTop);
    end;
  finally SetPreviewScroll(FScroll,ScrollX,ScrollY); FPlacing:=False; FViewportDirty:=True; end;
  if Reflow and (FPagePass<3) then begin Inc(FPagePass); try LayoutPages(nil); finally Dec(FPagePass); end; end;
  UpdateVisible;
end;
procedure TPagedEditor.ViewportChanged(Sender:TObject);
begin
  if FLoading or FPlacing or FUpdatingViewport or FViewportQueued then Exit;
  FViewportQueued:=True; Application.QueueAsyncCall(@RefreshViewport,0);
end;
procedure TPagedEditor.RefreshViewport(Data:PtrInt);
begin
  FViewportQueued:=False;
  if not FLoading then UpdateVisible;
end;
procedure TPagedEditor.UpdateVisible;
var I,ViewTop,ViewBottom:Integer; InView,WasVisible:Boolean; Editor:TMathEditor; View:TRect;
begin
  if FPlacing or FUpdatingViewport then Exit;
  View:=Rect(FScroll.HorzScrollBar.Position,FScroll.VertScrollBar.Position,
    FScroll.HorzScrollBar.Position+FScroll.ClientWidth,FScroll.VertScrollBar.Position+FScroll.ClientHeight);
  if not FViewportDirty and (View=FViewport) then Exit;
  FUpdatingViewport:=True; FScroll.DisableAlign;
  try
  ViewTop:=FScroll.VertScrollBar.Position-Max(600,FScroll.ClientHeight); ViewBottom:=ViewTop+3*Max(600,FScroll.ClientHeight);
  for I:=0 to High(FPages) do begin
    FPages[I].SyncScrollPosition;
    InView:=(FPages[I].DocumentOrigin.Y+FPages[I].Height>=ViewTop) and (FPages[I].DocumentOrigin.Y<=ViewBottom);
    WasVisible:=FPages[I].Visible; FPages[I].Visible:=InView;
    if InView and not WasVisible then FPages[I].SendToBack;
    { Keep the paper window's stacking order; discard its text caches. }
    if not InView then FPages[I].ReleaseRenderCache;
  end;
  for I:=0 to High(FBoundaryPanels) do begin
    FBoundaryPanels[I].SyncScrollPosition;
    FBoundaryPanels[I].Visible:=(FBoundaryPanels[I].DocumentOrigin.Y+FBoundaryPanels[I].Height>=ViewTop) and
      (FBoundaryPanels[I].DocumentOrigin.Y<=ViewBottom);
  end;
  for I:=0 to High(FBlocks) do begin
    FBlocks[I].Panel.SyncScrollPosition;
    InView:=(FBlocks[I].Flow.Top+FBlocks[I].Flow.Height>=ViewTop) and (FBlocks[I].Flow.Top<=ViewBottom);
    InView:=InView and not FBlocks[I].Folded;
    WasVisible:=FBlocks[I].Panel.Visible;
    FBlocks[I].Panel.Visible:=InView or ((I=FBlock) and not FBlocks[I].Folded);
    if InView then begin
      Editor:=ParagraphEditor(I);
      if not WasVisible then Editor.Invalidate;
    end
    else if (I<>FBlock) and (FBlocks[I].Editor<>nil) then begin
      FBlocks[I].Editor.ReleaseRenderCache;
      if not EditorNeeded(I) and not FEvictionQueued then begin
        FEvictionQueued:=True; Application.QueueAsyncCall(@EvictEditors,0);
      end;
    end;
  end;
  FViewport:=View; FViewportDirty:=False;
  finally FScroll.EnableAlign; FUpdatingViewport:=False; end;
  { Restore native stacking after the newly visible widgets are allocated.
    Long text controls also span the space reserved for floats. }
  for I:=0 to High(FBlocks) do if FBlocks[I].Panel.Visible then FBlocks[I].Panel.BringToFront;
  for I:=0 to High(FBlocks) do if FBlocks[I].Panel.Visible and (FBlocks[I].Flow.FloatKind<>'') then
    FBlocks[I].Panel.BringToFront;
  for I:=0 to High(FBoundaryPanels) do if FBoundaryPanels[I].Visible then
    FBoundaryPanels[I].BringToFront;
end;
procedure TPagedEditor.EvictEditors(Data:PtrInt);
var I:Integer; Editor:TPageText;
begin
  FEvictionQueued:=False;
  if FLoading or FPlacing or FUpdatingViewport or FHandlingInput or FSelecting then begin
    FViewportDirty:=True; Exit;
  end;
  { Native callbacks finish before their offscreen controls are released.
    Measurements and the document selection survive independently of editors. }
  FScroll.DisableAlign;
  try
    for I:=0 to High(FBlocks) do begin
      Editor:=FBlocks[I].Editor;
      if (Editor=nil) or EditorNeeded(I) or Editor.MouseSelecting then Continue;
      FBlocks[I].Editor:=nil; DetachPageEditor(Editor); Editor.Free;
      FBlocks[I].Panel.ReleaseNativeCache;
    end;
  finally FScroll.EnableAlign; end;
end;
procedure TPagedEditor.EditorBackground(Sender:TObject);
var Editor:TMathEditor; I,Y,Index,First,Last:Integer; Paper:TRect;
begin
  Editor:=TMathEditor(Sender); Editor.Canvas.Brush.Color:=UIBackground; Editor.Canvas.FillRect(Editor.ClientRect);
  Index:=EditorIndex(Sender); if Index<0 then Exit;
  First:=Max(FBlocks[Index].Flow.Top,FScroll.VertScrollBar.Position);
  Last:=Min(FBlocks[Index].Flow.Top+Editor.Height,FScroll.VertScrollBar.Position+FScroll.ClientHeight);
  for I:=0 to High(FPages) do begin
    Y:=FPages[I].DocumentOrigin.Y+FPages[I].Height;
    if (Y+24<First) or (FPages[I].DocumentOrigin.Y>Last) then Continue;
    Paper:=Rect(0,0,FPages[I].Width,FPages[I].Height);
    OffsetRect(Paper,FPages[I].DocumentOrigin.X-FBlocks[Index].Panel.DocumentOrigin.X,
      FPages[I].DocumentOrigin.Y-FBlocks[Index].Panel.DocumentOrigin.Y);
    Editor.Canvas.Brush.Color:=PaperColor; Editor.Canvas.FillRect(Paper);
    Dec(Y,FBlocks[Index].Flow.Top);
    Editor.Canvas.Brush.Color:=UIBackground;
    Editor.Canvas.FillRect(Rect(0,Y,Editor.Width,Y+24));
    FPages[I].PaintFurniture(Editor.Canvas,FPages[I].DocumentOrigin-FBlocks[Index].Panel.DocumentOrigin);
  end;
end;
procedure TPagedEditor.EditorChanged(Sender:TObject);
var Index:Integer;
begin
  if FLoading then Exit; Index:=EditorIndex(Sender); if Index<0 then Exit; FBlock:=Index;
  if not VisualEditor.FormattingSource and ((FLastUndo=0) or (GetTickCount64-FLastUndo>700)) then begin
    FUndo.Add(Source); if FUndo.Count>20 then FUndo.Delete(0);
  end;
  FLastUndo:=GetTickCount64; FRedo.Clear;
  FDocument.Blocks[FBlock]:=VisualEditor.Formula;
  FChangedBlock:=FBlock;
  FBlocks[FBlock].Measured:=False; FContextDue:=GetTickCount64+150; LayoutPages(nil);
  SelectionChanged(VisualEditor);
  if Assigned(FOnChange) then FOnChange(Self);
end;
procedure TPagedEditor.EditorLayout(Sender:TObject);
var Index:Integer;
begin
  if FLoading or FPlacing or FUpdatingViewport then Exit;
  Index:=EditorIndex(Sender); if Index<0 then Exit;
  if TMathEditor(Sender).Formula<>FDocument.Blocks[Index] then Exit;
  if not TMathEditor(Sender).PageSourcesExpanded and (FBlocks[Index].Base.NativeHeight<>TMathEditor(Sender).NativeHeight) then
    FBlocks[Index].Measured:=False;
  LayoutPages(nil);
end;
procedure TPagedEditor.Poll(Sender:TObject);
var Value:string; Offset:Integer;
begin
  if FLoading or FPlacing or FUpdatingViewport then Exit;
  if (FReblockDue<>0) and (GetTickCount64>=FReblockDue) then begin
    FReblockDue:=0; FContextDue:=0; Value:=Source; Offset:=FReblockOffset; FDocument.ParseFile(Value); ResetBlocks(Offset);
    if Assigned(FOnChange) then FOnChange(Self);
    if VisualEditor.CanFocus then VisualEditor.SetFocus;
  end;
  if (FContextDue<>0) and (GetTickCount64>=FContextDue) then begin FContextDue:=0; UpdateContext; LayoutPages(nil); end;
  UpdateVisible;
end;
procedure TPagedEditor.SelectionChanged(Sender:TObject);
var P:TPoint; Y,Caret,A,B:Integer; Moved:Boolean; Key:string;
begin
  if FLoading or FPlacing or FUpdatingViewport or FApplyingSelection or FSelecting or (FBlock<0) or (Sender<>VisualEditor) then Exit;
  VisualEditor.GetSourceSelection(A,B);
  FSelectionAnchor:=BlockOffset(FBlock)+A; FSelectionFocus:=BlockOffset(FBlock)+B;
  Caret:=VisualEditor.SourceCaret; Moved:=(FLastCaretBlock<>FBlock) or (FLastCaret<>Caret);
  FLastCaretBlock:=FBlock; FLastCaret:=Caret;
  Key:=VisualEditor.PageCaptionKey; if Key<>'' then Key:=IntToStr(FBlock)+Key;
  if Key<>FCaptionKey then begin FCaptionKey:=Key; LayoutPages(nil); end;
  { Layout/cache refreshes also notify selection. Only a caret move follows it. }
  if Moved and not VisualEditor.MouseSelecting and VisualEditor.Focused then begin
    P:=VisualEditor.CaretPoint; Y:=FBlocks[FBlock].Flow.Top+P.Y;
    if Y<FScroll.VertScrollBar.Position+12 then SetPreviewScroll(FScroll,FScroll.HorzScrollBar.Position,Max(0,Y-24))
    else if Y>FScroll.VertScrollBar.Position+FScroll.ClientHeight-18 then SetPreviewScroll(FScroll,FScroll.HorzScrollBar.Position,Y-FScroll.ClientHeight+36);
  end;
  if Assigned(FOnSelectionChange) then FOnSelectionChange(Self);
end;
procedure TPagedEditor.GeneratedAction(Sender:TObject; const Command:string; Target:Integer; Configure:Boolean);
begin
  if not Configure and (Target>=Length(FDocument.Preamble)) then RevealOffset(Target)
  else if Assigned(FOnGeneratedAction) then FOnGeneratedAction(Sender,Command,Target,Configure);
end;
function TPagedEditor.SourceOffset:Integer;
begin Result:=0; if FSelectionFocus>=0 then Result:=FSelectionFocus else if FBlock>=0 then Result:=BlockOffset(FBlock)+VisualEditor.SourceCaret; end;
{$I pagedselection.inc}
procedure TPagedEditor.ParagraphBreak(Sender:TObject);
begin
  VisualEditor.InsertBody(LineEnding+LineEnding,Length(LineEnding)*2);
  FReblockOffset:=SourceOffset; FReblockDue:=GetTickCount64+1;
end;
procedure TPagedEditor.Boundary(Sender:TObject; Direction:Integer; Merge:Boolean);
var Index,Offset:Integer;
begin
  Index:=FBlock+Direction; if (Index<0) or (Index>=Length(FBlocks)) then Exit;
  if not Merge then begin
    if Direction<0 then Offset:=Length(TrimRight(FDocument.Blocks[Index])) else Offset:=0;
    ActivateBlock(Index,Offset); Exit;
  end;
  if Direction<0 then begin Index:=FBlock-1; Offset:=Length(TrimRight(FDocument.Blocks[Index])); end
  else begin Index:=FBlock; Offset:=Length(TrimRight(FDocument.Blocks[Index])); end;
  FUndo.Add(Source); FRedo.Clear;
  FDocument.Blocks[Index]:=TrimRight(FDocument.Blocks[Index])+' '+TrimLeft(FDocument.Blocks[Index+1]); FDocument.Blocks.Delete(Index+1);
  FReblockOffset:=BlockOffset(Index)+Offset; FReblockDue:=GetTickCount64+1;
end;
procedure TPagedEditor.History(Sender:TObject);
var FromList,ToList:TStringList; Value:string; Offset:Integer; HandlingInput:Boolean;
begin
  FromList:=FUndo; ToList:=FRedo; if Sender=FRedo then begin FromList:=FRedo; ToList:=FUndo; end;
  if FromList.Count=0 then Exit;
  Offset:=SourceOffset; Value:=FromList[FromList.Count-1]; FromList.Delete(FromList.Count-1); ToList.Add(Source);
  HandlingInput:=FHandlingInput; FHandlingInput:=True;
  try
    FDocument.ParseFile(Value); FLastUndo:=0; ResetBlocks(Offset); if Assigned(FOnChange) then FOnChange(Self);
  finally FHandlingInput:=HandlingInput; end;
end;
procedure TPagedEditor.Redo(Sender:TObject);
begin History(FRedo); end;
procedure TPagedEditor.SetZoom(Percent:Integer; FitWidth:Boolean; FitPage:Boolean);
begin FZoomPercent:=EnsureRange(Percent,10,800); FFitWidth:=FitWidth; FFitPage:=FitPage; LayoutPages(nil); end;
function TPagedEditor.ScalePercent:Integer;
begin Result:=Max(1,Round(FScale*125)); end;
function TPagedEditor.CurrentPage:Integer;
var I,Y:Integer;
begin
  Result:=1; Y:=FScroll.VertScrollBar.Position;
  if (FBlock>=0) and (FBlocks[FBlock].Editor<>nil) then Y:=FBlocks[FBlock].Flow.Top+VisualEditor.CaretPoint.Y;
  for I:=0 to High(FPages) do if Y>=FPages[I].DocumentOrigin.Y then Result:=I+1;
end;
procedure TPagedEditor.Undo;
begin History(nil); end;
procedure TPagedEditor.RedoEdit;
begin History(FRedo); end;
procedure TPagedEditor.Recompile(const Engine:string);
var I:Integer;
begin
  VisualEditor.FinishCommand; if Engine<>'' then FEngine:=Engine;
  UpdateContext; for I:=0 to High(FBlocks) do begin FBlocks[I].Measured:=False; if FBlocks[I].Editor<>nil then FBlocks[I].Editor.InvalidateContext; end;
  LayoutPages(nil);
end;
end.
