unit MathEditor;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Contnrs, Types, Math, Character, Dialogs, Forms, Controls, Graphics, ExtCtrls, StdCtrls, Menus,
  LCLType, LMessages, LazUTF8, Clipbrd, MathModel, TeXMacros, CommandDefinition, TeXDocumentMetrics, TeXBibliography, ParagraphModel, ProseEditing, PreviewImage, GeneratedPreview, VectorPreview, DraftLayout, MathSelection, TeXContext, UITheme, TeXTables, SourceRanges, TeXProject, TeXTextStyle, TeXStyles, TextSelectionStyle, NativePagination
  {$IFDEF LCLqt5}, Qt5{$ENDIF}{$IFDEF LCLqt6}, Qt6{$ENDIF};
type
  TDocumentGestureEvent = procedure(Sender:TObject; Position:TPoint; Phase:Integer; Shift:TShiftState) of object;
  TDocumentKeyEvent = procedure(Sender:TObject; Key:Word; Shift:TShiftState; var Handled:Boolean) of object;
  TDocumentTextEvent = procedure(Sender:TObject; const Value:string; var Handled:Boolean) of object;
  TSourceLinkEvent = procedure(Sender:TObject; Offset:Integer; var Handled:Boolean) of object;
  TGeneratedActionEvent=procedure(Sender:TObject; const Command:string; Target:Integer; Configure:Boolean) of object;
  TParagraphBoundaryEvent = procedure(Sender:TObject; Direction:Integer; Merge:Boolean) of object;
  TMathRegion = TDraftRegion;
  TPageCaption=record Text:string; Bounds:TRect; Line,Space:Integer; end;
  TPageCaptions=array of TPageCaption;
  TEditorTextStyle=class
    Style:TTeXTextStyle;
    Color:TColor;
  end;
  TMathEditor = class(TCustomControl)
  private
    FTextStyleOverride:TEditorTextStyle;
    FRoot:TMathNode;
    FFields:TList;
    FActive,FCaret,FEditCaretBefore,FActiveSlide:Integer;
    FSelected,FDragging,FKeyboardSelecting:Boolean;
    FSelectionAnchor,FSelectionFocus:Integer;
    FMouseDownPoint:TPoint;
    FMouseMoved:Boolean;
    FVerticalX:Integer;
    FVerticalRun:Boolean;
    FMathShortcut:string;
    procedure SetMathShortcut(const Value:string);
    function MathShortcutText(const Value:string):Boolean;
    function GetMathShortcutHint:string;
    procedure WrapMathSelection(const Prefix,Suffix:string; ReplaceContent:Boolean=False);
    procedure EnterShortcutMath;
    procedure WrapSelectionRange(const Prefix,Suffix:string; A,B:Integer);
  private
    FDocumentGesture:TDocumentGestureEvent;
    FDocumentKey:TDocumentKeyEvent;
    FDocumentText:TDocumentTextEvent;
    FSourceLink:TSourceLinkEvent;
    FGeneratedAction:TGeneratedActionEvent;
    function GeneratedAt(X,Y:Integer; out Command:string; out Target:Integer):Boolean;
  private
    FLinkClick:Boolean;
    FDefinitionStart,FDefinitionMinimum,FDefinitionSourceStart:Integer;
    FFinishingDefinition,FFocusCompletionQueued:Boolean;
    FDefinitionArgumentMenu:TPopupMenu;
    FDefinitionMenuArgument:Integer;
    procedure CompleteFocusEdit(Data:PtrInt);
    function DefinitionNodeAtCaret:TMathNode;
    function CommandNodeAtCaret:TMathNode;
    procedure DefinitionArgumentMenuClick(Sender:TObject);
    procedure SetDefinitionArgumentDefault(Index:Integer; const Value:string; Caret:Integer);
    procedure BeginDefinitionEdit;
    function CompleteDefinition(const Source:string; var Caret:Integer):string;
  private
    FLinkFirst,FLinkLast:Integer;
    FLinkTimer:TTimer;
    FLinkMouse:TPoint;
    FSourceHover:TPoint;
    FHoverPreview:TMathNode;
    FSourceFrameNode:TMathNode;
    FSourceFrameRects:TSelectionRects;
    FSourceFrameSlide:Integer;
    procedure UpdateSourceHover(X,Y:Integer);
    procedure LinkTimer(Sender:TObject);
    procedure UpdateLinkHover(CtrlPressed:Boolean);
    procedure ClearLinkHover;
  private
    FSource,FPreamble,FDirectory,FEngine,FEnvironment,FError:string;
    FStyleSource,FStyleContext:string;
    FStyleAnchor,FStyleFocus:Integer;
    FSelectionStyle:TTeXTextSelection;
    FMacroContext:string;
    FDocumentBlocks:TStrings;
    FBeforeDeclarations:string;
    FBeforeOffset:Integer;
    FSharedContext:TTeXContext;
    FSharedRevision:QWord;
    FOwnDocumentBlocks:TStringList;
    FDocumentIndex:Integer;
    FDisplayMath,FParagraph:Boolean;
    FFormulaSourceMode,FReadOnly,FCodeOnly,FDefinitionsInCode:Boolean;
    FVisualSourceDirty,FFormattingSource:Boolean;
    FDeferLayout:Boolean;
    FSourcePreviewStart,FDiagramSourceStart,FCollapsedDiagramStart,FInlineSourceA,FInlineSourceB:Integer;
    {$IFDEF LCLgtk3}FMeasureBitmap:TBitmap;{$ENDIF}
    FPreviewFrame,FPageCaptionPadding:Integer;
    FEmptyScriptStart:Integer;
    FCleaningScript:Boolean;
    FBackgroundPaint:TNotifyEvent;
    FPreserveColors:Boolean;
    procedure SetPreserveColors(Value:Boolean);
    procedure SetFormulaSourceMode(Value:Boolean);
    procedure SetPreviewSourceMode(Value:Boolean; Offset:Integer; Caret:Integer=-1);
    function SourcePreviewNode:TMathNode;
    function SourceFrameRects:TSelectionRects;
    function SourceToggleAt(X,Y:Integer; out Offset:Integer; out Formula:Boolean):Boolean;
    procedure ToggleSourceAt(Offset:Integer; Formula:Boolean);
    procedure NotifySelection;
    function CurrentEmptyScript:TMathNode;
    procedure TrackEmptyScript;
    function ControlWordSuffix(const Command:string):string;
    function GetSelectionGesture:Boolean;
    procedure ProcessKeyDown(var Key:Word; Shift:TShiftState);
    procedure SetPreviewFrame(Value:Integer);
  private
    FRegistry:TMacroRegistry;
    FDraft:TParagraphDraft;
    FGeneratedPreview:TGeneratedPreview;
    FGeneratedAnchor,FGeneratedFocus,FGeneratedHover:Integer;
    function GeneratedCaretBounds:TRect;
    function GeneratedHit(X,Y:Integer):Integer;
    function GeneratedLinkAt(X,Y:Integer):Integer;
    function GeneratedRects:TSelectionRects;
    function GeneratedMouseDown(Button:TMouseButton; Shift:TShiftState; X,Y:Integer):Boolean;
    function GeneratedKey(var Key:Word; Shift:TShiftState):Boolean;
  private
    FContext:TTeXContext;
    FDraftPageRevision:QWord;
    FDraftWidth,FTextAreaWidth:Integer;
    FCachedHeight,FSourceFontPixels:Integer;
    FFieldsRevision:QWord;
    FSourceFontName:string;
    FDraftDirty,FFallback:Boolean;
    FFoldedRanges:TSourceRanges;
    FCommandEdit:TEdit;
    FCommandHints:TListBox;
    FHintNames:TStringList;
    procedure RefreshCommandHints;
    procedure CommandHintClick(Sender:TObject);
  private
    FIMEPreedit:string;
    {$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}
    FInputHook:QObject_hookH;
    function InputMethodEvent(Sender:QObjectH; Event:QEventH):Boolean; cdecl;
    {$ENDIF}
  private
    FCommandFinishing:Boolean;
    FNormalizeOptional:Boolean;
    FOptionalResumeOffset,FOptionalResumeCaret,FNormalizeCommandStart,FOptionalCommandStart:Integer;
    FMaterializingOptional,FOptionalTransient:Boolean;
    FOptionalBefore:string;
    FOptionalBeforeCaret,FOptionalArgumentIndex:Integer;
    FUndo,FRedo:TStringList;
    FChange,FFinish,FLayout,FSelectionChange,FFigureEdit:TNotifyEvent;
    FParagraphBreak:TNotifyEvent;
    FUndoRequested,FRedoRequested:TNotifyEvent;
    FBoundary:TParagraphBoundaryEvent;
    procedure EnsureDraft;
    procedure InvalidateDraft;
    procedure LoadRegistry(Force:Boolean=False);
    procedure InputText(const AText:string);
    function CommandActive:Boolean; inline;
    procedure BeginCommand;
    procedure CommandKeyDown(Sender:TObject; var Key:Word; Shift:TShiftState);
    procedure CommandChanged(Sender:TObject);
    procedure CommandExit(Sender:TObject);
    function CurrentNode:TMathNode;
    function FieldBounds(Index:Integer):TRect;
    function DisplayBounds(Index:Integer):TRect;
  private
    FPreviewZoom:Double;
    FPageFirst,FPageBody,FPageGap:Integer;
    FPageShifts:TPageShifts;
    FPageHeight:Integer;
    FCustomPages,FPagedEditing:Boolean;
    procedure SetPreviewZoom(Value:Double);
    function ImageTop:Integer;
    function ImageLeft:Integer;
    procedure HitField(X,Y:Integer);
    function InMath:Boolean;
    function InTextArgument:Boolean;
    procedure MovePastNode(Node:TMathNode);
    function LeaveFormula:Boolean;
    function MathSpace:Boolean;
    function DeleteStructure:Boolean;
    function DeleteEmptyFormula:Boolean;
    function DeletePreviousMacro:Boolean;
    function SelectPreviousCommand:Boolean;
    function DeleteVerbatim(Key:Word):Boolean;
    procedure RefocusEditor;
    function InsertScript(const Value:string):Boolean;
    procedure ParseSource;
    procedure Schedule;
    function ActiveRegions:TDraftRegions;
    function CaretRegion(const Regions:TDraftRegions):Integer;
    function ScreenRegions:TDraftRegions;
    function ClickableFieldAt(X,Y:Integer; out Space:Boolean):Integer;
    function RuleAt(X,Y:Integer):TMathNode;
    function SelectionRange(out A,B:Integer):Boolean;
    function FormatTableSelection(const Command,HTMLColor:string):Boolean;
    function SelectionTouchesMath(A,B:Integer):Boolean;
    procedure PaintSelection;
    function ActivateOptionalArgument:Boolean;
    function NativeUnitField:Boolean;
    function UnitTokenAt(Offset:Integer; out First,Last:Integer):Boolean;
    function NodeBounds(Node:TMathNode):TRect;
    function CommandContextNode(out CommandName:string):TMathNode;
    procedure PaintCommandContext;
    function PageLineBelow(const Lines:TPageLines; Bottom:Integer):Integer;
    procedure PaintPageCaptions;
    procedure PaintSourceFrame;
    procedure Commit(const AValue:string; Caret:Integer);
    function NormalizeDiagramEdit(const Value:string; var Caret:Integer):string;
    procedure ReplaceSelection(const Value:string);
    procedure ApplyField(const Value:string; Caret:Integer);
    procedure NotifyChange;
    procedure NextField(Delta:Integer);
    procedure MoveHorizontal(Delta:Integer);
    procedure MoveLineEdge(AtEnd:Boolean);
    function FractionNeighbor(Delta:Integer):TMathNode;
    function MoveGridRow(Delta:Integer):Boolean;
    function CurrentMathGrid:TMathNode;
    function TableNode:TMathNode;
    function EnvironmentNode(const EnvironmentName:string):TMathNode;
    function ReplaceTableSelection(const Value:string):Boolean;
    function TableSelectionText:string;
    function FloatNode:TMathNode;
    function MoveTable(RowDelta,ColDelta:Integer; AtBoundary:Boolean):Boolean;
    function EditList(Key:Word):Boolean;
    function BreakEnvironmentLine(Soft:Boolean):Boolean;
    procedure SnapProseCaret(Delta:Integer);
    function GetPreferredHeight:Integer;
    function GetPreferredWidth:Integer;
    function GetMarginLeft:Integer;
    function TextLayoutWidth:Integer;
    procedure SetTextAreaWidth(Value:Integer);
    function GetReady:Boolean;
    function GetInputPending:Boolean;
    function GetRendering:Boolean;
    function GetLayoutPending:Boolean;
  protected
    function SourceDisclosureBounds:TRect;
    {$IFDEF LCLgtk3}function GetClientOrigin:TPoint; override;{$ENDIF}
    procedure SendMoveSizeMessages(SizeChanged,PosChanged:Boolean); override;
    procedure WMMove(var Message:TLMMove); message LM_MOVE;
    {$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6) OR DEFINED(LCLgtk3)}
    procedure CreateWnd; override;
    {$ENDIF}
    procedure DestroyWnd; override;
    procedure WMGetDlgCode(var Message:TLMGetDlgCode); message LM_GETDLGCODE;
    procedure CMMouseLeave(var Message:TLMessage); message CM_MOUSELEAVE;
    procedure Paint; override;
    procedure MouseDown(Button:TMouseButton; Shift:TShiftState; X,Y:Integer); override;
    procedure DoContextPopup(MousePos:TPoint; var Handled:Boolean); override;
    procedure MouseMove(Shift:TShiftState; X,Y:Integer); override;
    procedure MouseUp(Button:TMouseButton; Shift:TShiftState; X,Y:Integer); override;
    procedure DblClick; override;
    function DoMouseWheel(Shift:TShiftState; WheelDelta:Integer; MousePos:TPoint):Boolean; override;
    procedure KeyDown(var Key:Word; Shift:TShiftState); override;
    procedure KeyUp(var Key:Word; Shift:TShiftState); override;
    procedure UTF8KeyPress(var UTF8Key:TUTF8Char); override;
    procedure DoEnter; override;
    procedure DoExit; override;
  public
    constructor Create(AOwner:TComponent); override;
    property OnBackgroundPaint:TNotifyEvent read FBackgroundPaint write FBackgroundPaint;
    property PreserveColors:Boolean read FPreserveColors write SetPreserveColors;
    destructor Destroy; override;
    procedure SetContext(const Preamble,Directory,Engine,Environment:string; DisplayMath:Boolean);
    procedure ConfigureSourceFont(SourceFont:TFont);
    procedure SetFoldedRanges(const Ranges:TSourceRanges; Offset,Count:Integer);
    function SourceFolded:Boolean;
    procedure ConfigurePagination(FirstRoom,BodyHeight,Gap:Integer);
    procedure ConfigurePageLayout(const Shifts:TPageShifts; NewHeight,BodyHeight:Integer);
    function PageLines:TPageLines;
    function PageEditingLines:TPageLines;
    function PageCaptions:TPageCaptions;
    function PageCaptionKey:string;
    function PageHovering:Boolean;
    function NativeHeight:Integer;
    function MarginNoteBounds:TRect;
    function PageSourcesExpanded:Boolean;
    property PagedEditing:Boolean read FPagedEditing write FPagedEditing;
    procedure ConfigureTextStyle(const Style:TTeXTextStyle; TextColor:TColor);
    procedure InvalidateContext;
    procedure ReleaseRenderCache;
    procedure RefreshDiagramPreview;
    function HasDiagramPreview:Boolean;
    procedure SetDocumentContext(Blocks:TStrings; Index:Integer; SharedContext:TTeXContext=nil; const BeforeDeclarations:string=''; BeforeOffset:Integer=-1);
    function LoadFormula(const Source:string; out Error:string):Boolean;
    procedure LoadParagraph(const Source:string; Preview:TPicture; const LayoutXML:string=''; LayoutPage:Integer=1; const Positions:string='');
    procedure SetGeneratedPreview(Image:TPreviewImage; const LayoutXML:string=''; LayoutPage:Integer=1);
    function GeneratedTextActive:Boolean;
    function GeneratedBounds:TRect;
    procedure ClickPreview(X,Y,PreviewWidth,PreviewHeight:Integer);
    procedure SelectFormula(Index:Integer);
    procedure InsertEquation(const Value:string);
    procedure ToggleSelectedMath;
    procedure ToggleSelectionSource;
    procedure SetParagraphSourceMode(Value:Boolean);
    function FinishVisualSource(Offset:Integer=-1):Integer;
    procedure SetParagraphAlignment(const Environment:string);
    procedure SetTheoremEnvironment(const Environment:string);
    procedure SetFormulaKind(const Kind:string; InsertNew:Boolean);
    function EditGrid(Operation:Integer):Boolean;
    function CanEditGrid(Operation:Integer):Boolean;
    function EditingTable:Boolean;
    function EditingTheorem:Boolean;
    function EditingFigure:Boolean;
    function CurrentEnvironmentName:string;
    function CurrentEnvironmentSource(const EnvironmentName:string=''):string;
    procedure ReplaceEnvironment(const Value:string; const EnvironmentName:string='');
    function CurrentParagraphStyle:string;
    function EditingSourcePreview:Boolean;
    function CurrentTableSource:string;
    function EditTable(Operation:Integer):Boolean;
    procedure GetTableActions(out States:TTableActionStates);
    function SplitTableCell(Rows,Columns:Integer; Borders:Boolean):Boolean;
    function EditTableBorder(Side,Count:Integer):Boolean;
    procedure ReplaceTable(const Value:string; Row,Col:Integer);
    procedure InsertBody(const Value:string; CaretOffset:Integer=0);
    function CurrentFloatSource:string;
    function CurrentFigureSource:string;
    function CurrentBoxSource:string;
    procedure ReplaceBox(const Value:string);
    procedure EditBoxSource;
    function CurrentDiagramSource:string;
    procedure ReplaceDiagram(const Value:string);
    procedure ReplaceFloat(const Value:string);
    procedure ReplaceFigure(const Value:string);
    procedure GetSourceSelection(out Anchor,Focus:Integer);
    function SelectedSourceRanges:TSourceRanges;
    function SelectingTableCells:Boolean;
    procedure FormatText(const Command:string);
    procedure SetTextFamily(const Command:string);
    procedure ClearTextFormatting;
    procedure ToggleComment;
    function SelectionTextStyle(out Style:TTeXTextStyle):Boolean;
    function SelectionTextState:TTeXTextSelection;
    procedure SetTextSize(const Prefix:string);
    procedure SetTextColor(const HTMLColor:string);
    function TextStyleActive(const Command:string):Boolean;
    procedure RenameCommand(const NewName:string);
    function CurrentCommandName:string;
    function CurrentCommandPath:string;
    function CurrentCommandSource:string;
    procedure ReplaceCurrentCommand(const Value:string);
    function CurrentDefinitionSource:string;
    function EditingDefinition:Boolean;
    procedure FinishDefinitionEdit;
    procedure QueueFocusCompletion;
    procedure FinishOptionalEdit;
    procedure EditDefinitionArguments(Optional:Boolean; DeleteIndex:Integer=-1);
    procedure SetDefinitionArgumentKind(Index:Integer; Optional:Boolean);
    procedure SetDefinitionArgumentDefaultValue(Index:Integer; const Value:string);
    function CommandContext(out CommandName:string; out Bounds:TRect):Boolean;
    function PrepareDefinitionArgumentMenu(X,Y:Integer):TPopupMenu;
    procedure ReplaceDefinition(const Value:string);
    procedure ToggleDefinitionSource;
    function DefinitionSourceEditing:Boolean;
    procedure WrapSelection(const Prefix,Suffix:string);
    procedure InsertAnnotation(const Command,Value:string);
    procedure LabelNames(Dest:TStrings);
    procedure CitationNames(Dest:TStrings);
    procedure TheoremNames(Dest:TStrings);
    procedure HeadingNames(Dest:TStrings);
    procedure EditAnnotation;
    function EditReferenceAt(X,Y:Integer):Boolean;
    function EditSpaceAt(X,Y:Integer):Boolean;
    function EditInputAt(X,Y:Integer):Boolean;
    procedure EditTheoremTitle;
    procedure SetHeading(const Command:string);
    property EditingMath:Boolean read InMath;
    function Formula:string;
    procedure InsertStructure(Kind:TMathKind);
    procedure InsertTeX(const Value:string);
    procedure InsertCommand(const Value:string);
    procedure FinishCommand(Refocus:Boolean=False);
    procedure FinishEmptyScript(LeavingEditor:Boolean=False);
    function MathShortcutKey(var Key:Word; Shift:TShiftState):Boolean;
    procedure CancelMathShortcut;
    property MathShortcutHint:string read GetMathShortcutHint;
    procedure InsertSymbol(const Value:string);
    procedure Undo;
    procedure Redo;
    procedure ClipboardCommand(Key:Word);
    function SourceCaret:Integer;
    function MoveVertical(Delta:Integer; Excluded:TMathNode=nil):Boolean;
    property VerticalNavigation:Boolean read FVerticalRun;
    property MouseSelecting:Boolean read FDragging;
    property SelectionGesture:Boolean read GetSelectionGesture;
    procedure SetSourceCaret(Offset:Integer);
    procedure ClearSourceSelection;
    function SplitParagraph(out Before,After:string):Boolean;
    procedure ReplaceSource(const Value:string; Caret:Integer);
    procedure SelectField(Index:Integer);
    procedure SetFieldText(const Value:string);
    procedure BeginSelectionAt(X,Y:Integer; Shift:TShiftState);
    procedure BeginSelectionAtSource(Offset:Integer; Shift:TShiftState);
    procedure CancelSelectionDrag;
    procedure SetSourceSelection(Anchor,Focus:Integer);
    procedure SelectWord;
    procedure NormalizeSelection(var A,B:Integer);
    function SelectedRects:TSelectionRects;
    function HitOffset(X,Y:Integer):Integer;
    function LinkUnderlineRects:TSelectionRects;
    function CaretPoint:TPoint;
    function EditingFormulaBounds:TRect;
    procedure FieldNames(Dest:TStrings);
    procedure MacroNames(Dest:TStrings);
    function MacroTemplate(const MacroName:string):string;
    property OnDocumentGesture:TDocumentGestureEvent read FDocumentGesture write FDocumentGesture;
    property OnDocumentKey:TDocumentKeyEvent read FDocumentKey write FDocumentKey;
    property OnDocumentText:TDocumentTextEvent read FDocumentText write FDocumentText;
    property OnGeneratedAction:TGeneratedActionEvent read FGeneratedAction write FGeneratedAction;
    property OnSourceLink:TSourceLinkEvent read FSourceLink write FSourceLink;
    property ActiveField:Integer read FActive;
    property FieldsRevision:QWord read FFieldsRevision;
    property EditCaretBefore:Integer read FEditCaretBefore;
    property FormattingSource:Boolean read FFormattingSource;
    property MathActive:Boolean read InMath;
    property Ready:Boolean read GetReady;
    property InputPending:Boolean read GetInputPending;
    property Rendering:Boolean read GetRendering;
    property ErrorText:string read FError;
    property OnFigureEdit:TNotifyEvent read FFigureEdit write FFigureEdit;
    property OnFinish:TNotifyEvent read FFinish write FFinish;
    property OnChange:TNotifyEvent read FChange write FChange;
    property OnLayout:TNotifyEvent read FLayout write FLayout;
    property OnSelectionChange:TNotifyEvent read FSelectionChange write FSelectionChange;
    property OnParagraphBreak:TNotifyEvent read FParagraphBreak write FParagraphBreak;
    property OnBoundary:TParagraphBoundaryEvent read FBoundary write FBoundary;
    property PreviewZoom:Double read FPreviewZoom write SetPreviewZoom;
    property OnUndo:TNotifyEvent read FUndoRequested write FUndoRequested;
    property OnRedo:TNotifyEvent read FRedoRequested write FRedoRequested;
    property PreferredHeight:Integer read GetPreferredHeight;
    property PreferredWidth:Integer read GetPreferredWidth;
    property MarginLeft:Integer read GetMarginLeft;
    property TextAreaWidth:Integer read FTextAreaWidth write SetTextAreaWidth;
    property OnMouseDown;
    property OnDblClick;
    property FormulaSourceMode:Boolean read FFormulaSourceMode write SetFormulaSourceMode;
    property ReadOnly:Boolean read FReadOnly write FReadOnly;
    property DeferLayout:Boolean read FDeferLayout write FDeferLayout;
    property LayoutPending:Boolean read GetLayoutPending;
    property CodeOnly:Boolean read FCodeOnly write FCodeOnly;
    property DefinitionsInCode:Boolean read FDefinitionsInCode write FDefinitionsInCode;
    property PreviewFrame:Integer read FPreviewFrame write SetPreviewFrame;
  end;
implementation
uses ToolDialogs, MathSpacing, TeXRules, RuleDialog, DiagramPreview, MathCommands, CommandHints, CommutativeDiagrams, SourceStyle, EditorClipboard, EditorStatus, TeXSourceFormat, BeamerModel
  {$IFDEF LCLgtk3}, LazGtk3, LazGdk3{$ENDIF}
  {$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}, QtWidgets{$ENDIF};
var PreviewMeasureBitmap:TBitmap;
{$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}
procedure TMathEditor.CreateWnd;
begin
  inherited CreateWnd;
  QWidget_setAttribute(TQtWidget(Handle).Widget,QtWA_InputMethodEnabled,not FReadOnly);
  if FReadOnly then Exit;
  FInputHook:=QObject_hook_create(TQtWidget(Handle).Widget);
  QObject_hook_hook_events(FInputHook,@InputMethodEvent);
end;
procedure TMathEditor.DestroyWnd;
begin
  CancelSelectionDrag;
  if FInputHook<>nil then QObject_hook_destroy(FInputHook); FInputHook:=nil;
  FIMEPreedit:=''; inherited DestroyWnd;
end;
function TMathEditor.InputMethodEvent(Sender:QObjectH; Event:QEventH):Boolean; cdecl;
var Committed,Preedit,Surrounding:WideString;
    Start,Count,Cursor16,A,B:Integer; Point:TPoint; R:TRect; Variant:QVariantH;
  procedure Query(Kind:QtInputMethodQuery; Data:QVariantH);
  begin
    QInputMethodQueryEvent_setValue(QInputMethodQueryEventH(Event),Kind,Data); QVariant_Destroy(Data);
  end;
begin
  Result:=False;
  if QEvent_type(Event)=QEventInputMethodQuery then begin
    Point:=CaretPoint; R:=Rect(Point.X,Point.Y-10,Point.X+3,Point.Y+12);
    Surrounding:=UTF8Decode(FSource); Cursor16:=Length(UTF8Decode(Copy(FSource,1,SourceCaret)));
    Query(QtImEnabled,QVariant_Create(True)); Query(QtImCursorRectangle,QVariant_Create(PRect(@R)));
    Query(QtImSurroundingText,QVariant_Create(PWideString(@Surrounding)));
    Variant:=QVariant_Create(Int64(Cursor16)); Query(QtImCursorPosition,Variant);
    Query(QtImAnchorPosition,QVariant_Create(Int64(Cursor16)));
    QEvent_accept(Event); Exit(True);
  end;
  if QEvent_type(Event)<>QEventInputMethod then Exit;
  QInputMethodEvent_commitString(QInputMethodEventH(Event),@Committed);
  QInputMethodEvent_preeditString(QInputMethodEventH(Event),@Preedit);
  FIMEPreedit:=UTF8Encode(Preedit);
  Start:=QInputMethodEvent_replacementStart(QInputMethodEventH(Event));
  Count:=QInputMethodEvent_replacementLength(QInputMethodEventH(Event));
  if (Committed<>'') or (Count>0) then begin
    if (Count>0) and not CommandActive then begin
      Surrounding:=UTF8Decode(FSource); Cursor16:=Length(UTF8Decode(Copy(FSource,1,SourceCaret)));
      Start:=EnsureRange(Cursor16+Start,0,Length(Surrounding)); Count:=EnsureRange(Count,0,Length(Surrounding)-Start);
      A:=Length(UTF8Encode(Copy(Surrounding,1,Start))); B:=Length(UTF8Encode(Copy(Surrounding,1,Start+Count)));
      SetSourceSelection(A,B); if Committed='' then ReplaceSelection('');
    end;
    if Committed<>'' then InputText(UTF8Encode(Committed));
  end;
  { Lazarus 4.0's Qt SlotInputMethod decodes a WideString as UTF-8; the
    low byte of U+4E0D becomes VK_RETURN. Consume the real commit directly. }
  Invalidate; QEvent_accept(Event); Result:=True;
end;
{$ENDIF}
{$IFDEF LCLgtk3}
procedure TMathEditor.CreateWnd;
begin inherited CreateWnd; ConfigurePreviewPainting(Self); end;
function TMathEditor.GetClientOrigin:TPoint;
begin if not PreviewNativeClientOrigin(Self,Result) then Result:=inherited GetClientOrigin; end;
{$ENDIF}
procedure TMathEditor.SetFoldedRanges(const Ranges:TSourceRanges; Offset,Count:Integer);
var Local:TSourceRanges; I:Integer; Same:Boolean;
begin
  Local:=ClipSourceRanges(Ranges,Offset,Count); Same:=Length(Local)=Length(FFoldedRanges);
  if Same then for I:=0 to High(Local) do
    if (Local[I].Start<>FFoldedRanges[I].Start) or (Local[I].Finish<>FFoldedRanges[I].Finish) then begin Same:=False; Break; end;
  if Same then Exit; FFoldedRanges:=Local;
  if FRoot<>nil then ParseSource;
end;
function TMathEditor.SourceFolded:Boolean;
begin Result:=SourceCovered(FSource,FFoldedRanges); end;
procedure TMathEditor.ConfigureSourceFont(SourceFont:TFont);
begin
  if (FSourceFontName=SourceFont.Name) and (FSourceFontPixels=Abs(SourceFont.Height)) then Exit;
  FSourceFontName:=SourceFont.Name; FSourceFontPixels:=Abs(SourceFont.Height);
  if FCommandEdit<>nil then begin FCommandEdit.Font.Assign(SourceFont); FCommandEdit.Font.Style:=[]; end;
  InvalidateDraft; Invalidate;
end;
procedure TMathEditor.InvalidateDraft;
begin FDraftDirty:=True; FCachedHeight:=0; FSourceFrameNode:=nil; FSourceFrameRects:=nil; end;
procedure TMathEditor.WMMove(var Message:TLMMove);
var Position:TPoint;
begin
  if PreviewMovePosition(Self,Message,Position) then SetBounds(Position.X,Position.Y,Width,Height)
  else inherited WMMove(Message);
end;
procedure TMathEditor.SendMoveSizeMessages(SizeChanged,PosChanged:Boolean);
begin
  inherited SendMoveSizeMessages(SizeChanged,PosChanged and
    (Left>=Low(SmallInt)) and (Left<=High(SmallInt)) and
    (Top>=Low(SmallInt)) and (Top<=High(SmallInt)));
end;
{$IF NOT (DEFINED(LCLqt5) OR DEFINED(LCLqt6))}
procedure TMathEditor.DestroyWnd;
begin
  { GTK3 releases capture after freeing its native widget. Release it while
    the handle is valid, including when a preview is rebuilt or reparented. }
  CancelSelectionDrag; inherited DestroyWnd;
end;
{$ENDIF}
constructor TMathEditor.Create(AOwner:TComponent);
begin
  inherited Create(AOwner);
  Color:=clWhite; Height:=160; Width:=700; TabStop:=True; Cursor:=crIBeam;
  FFields:=TList.Create; FRegistry:=TMacroRegistry.Create;
  FDraft:=TParagraphDraft.Create; FDraftDirty:=True;
  DoubleBuffered:=False;
  FPreviewZoom:=1;
  FUndo:=TStringList.Create; FRedo:=TStringList.Create;
  FOwnDocumentBlocks:=TStringList.Create; FDocumentBlocks:=FOwnDocumentBlocks; FDocumentIndex:=-1;
  FSourcePreviewStart:=-1; FDiagramSourceStart:=-1; FCollapsedDiagramStart:=-1;
  FSelectionAnchor:=-1; FSelectionFocus:=-1; FOptionalResumeOffset:=-1; FNormalizeCommandStart:=-1; FOptionalCommandStart:=-1; FEmptyScriptStart:=-1;
  FLinkFirst:=-1; FLinkLast:=-1; FLinkMouse:=Point(-1,-1);
  FSourceHover:=Point(-1,-1); FDraft.SourceHover:=FSourceHover;
  FLinkTimer:=TTimer.Create(Self); FLinkTimer.Enabled:=False; FLinkTimer.Interval:=50; FLinkTimer.OnTimer:=@LinkTimer;
  FInlineSourceA:=-1; FActive:=0; FEngine:='pdflatex'; FDirectory:=GetCurrentDir;
  FDefinitionStart:=-1;
  FDefinitionSourceStart:=-1;
  FGeneratedAnchor:=-1; FGeneratedHover:=-1;
  ControlStyle:=ControlStyle+[csOpaque];
end;
destructor TMathEditor.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  CancelSelectionDrag;
  FLinkTimer.Enabled:=False;
  {$IFDEF LCLgtk3}FMeasureBitmap.Free;{$ENDIF}
  {$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}
  if FInputHook<>nil then QObject_hook_destroy(FInputHook); FInputHook:=nil;
  {$ENDIF}
  FCommandFinishing:=True; if FCommandEdit<>nil then FCommandEdit.OnExit:=nil;
  FRoot.Free; FFields.Free; FRegistry.Free; FUndo.Free; FRedo.Free;
  FTextStyleOverride.Free;
  FHintNames.Free; FContext.Free; FDraft.Free; FGeneratedPreview.Free; FOwnDocumentBlocks.Free;
  inherited Destroy;
end;
function MatchingRight(const Left:string):string;
begin
  Result:='';
  case Trim(Left) of
    '\lvert':Result:='\rvert';
    '\lVert':Result:='\rVert';
    '\langle':Result:='\rangle';
    '\left(':Result:='\right)';
    '\left[':Result:='\right]';
    '\left\{':Result:='\right\}';
    '\left|':Result:='\right|';
    '\left\|':Result:='\right\|';
    '\left\langle':Result:='\right\rangle';
    '\left\lvert':Result:='\right\rvert';
    '\left\lVert':Result:='\right\rVert';
    '\left\lfloor':Result:='\right\rfloor';
    '\left\lceil':Result:='\right\rceil';
  end;
end;
function TMathEditor.CommandActive:Boolean;
begin Result:=(FCommandEdit<>nil) and FCommandEdit.Visible; end;
procedure TMathEditor.BeginCommand;
var R:TRect; Form:TCustomForm;
begin
  if CommandActive then Exit;
  FreeAndNil(FHintNames);
  if FCommandEdit=nil then begin
    { Preview cards never type commands. Create a native input widget only
      when an editable view actually starts entering one. }
    FCommandEdit:=TEdit.Create(Self); FCommandEdit.Visible:=False; FCommandEdit.Parent:=Self;
    if FSourceFontName<>'' then FCommandEdit.Font.Name:=FSourceFontName else FCommandEdit.Font.Name:='monospace';
    if FSourceFontPixels>0 then FCommandEdit.Font.Height:=-FSourceFontPixels else FCommandEdit.Font.Size:=10;
    FCommandEdit.OnKeyDown:=@CommandKeyDown; FCommandEdit.OnChange:=@CommandChanged;
    FCommandEdit.OnExit:=@CommandExit;
    FCommandEdit.Hint:='Enter accepts the selected suggestion; Space inserts the typed command and a space; Escape cancels.'; FCommandEdit.ShowHint:=True;
    ApplyTheme(FCommandEdit);
  end;
  R:=DisplayBounds(FActive);
  FCommandEdit.SetBounds(EnsureRange(R.Left,0,Max(0,ClientWidth-260)),
    EnsureRange(R.Top,0,Max(0,ClientHeight-28)),Min(260,ClientWidth),28);
  FCommandEdit.Text:='\'; FCommandEdit.Visible:=True; FCommandEdit.BringToFront;
  Form:=GetParentForm(Self);
  if (Form<>nil) and Form.Active and FCommandEdit.CanFocus then FCommandEdit.SetFocus;
  FCommandEdit.SelStart:=1; FCommandEdit.SelLength:=0;
end;
procedure TMathEditor.RefocusEditor;
var Form:TCustomForm;
begin
  Form:=GetParentForm(Self);
  { Qt can report CanFocus for a hidden or inactive parent. Completion must
    not force native focus back into such an editor. }
  if (Form<>nil) and Form.Visible and Form.Active and Showing and CanFocus then SetFocus;
end;
procedure TMathEditor.RefreshCommandHints;
var Suggestion,Prefix:string; I:Integer; Origin:TPoint; Scope:TMacroRegistry;
begin
  if not Showing then begin if FCommandHints<>nil then FCommandHints.Visible:=False; Exit; end;
  if FCommandHints=nil then begin
    FCommandHints:=TListBox.Create(Self); FCommandHints.Name:='CommandSuggestions'; FCommandHints.Parent:=GetParentForm(Self);
    {$IFDEF LCLgtk3}FCommandHints.Style:=lbOwnerDrawFixed; FCommandHints.ItemHeight:=20;{$ENDIF}
    FCommandHints.Visible:=False; FCommandHints.TabStop:=False; FCommandHints.OnClick:=@CommandHintClick;
  end;
  LoadRegistry;
  if FHintNames=nil then begin
    FHintNames:=TStringList.Create; Scope:=FRegistry;
    if FCodeOnly then begin Scope:=TMacroRegistry.Create; Scope.Load('',FDirectory); end;
    try CollectCommandHints(Scope,Copy(FSource,1,SourceCaret),InMath and not InTextArgument,FHintNames);
    finally if Scope<>FRegistry then Scope.Free; end;
  end;
  Prefix:=FCommandEdit.Text; FCommandHints.Items.BeginUpdate;
  try
    FCommandHints.Items.Clear;
    if FHintNames.IndexOf(Prefix)>=0 then FCommandHints.Items.Add(Prefix);
    for I:=0 to FHintNames.Count-1 do begin
      Suggestion:=FHintNames[I];
      if (Copy(Suggestion,1,Length(Prefix))=Prefix) and (Suggestion<>Prefix) then
        FCommandHints.Items.Add(Suggestion);
    end;
  finally FCommandHints.Items.EndUpdate; end;
  if FCommandHints.Items.Count=0 then begin FCommandHints.Visible:=False; Exit; end;
  Origin:=FCommandHints.Parent.ScreenToClient(FCommandEdit.ClientToScreen(Point(0,FCommandEdit.Height)));
  FCommandHints.SetBounds(Origin.X,Origin.Y,260,Min(140,FCommandHints.Items.Count*20+8));
  FCommandHints.Visible:=(Length(Prefix)>1) and (FCommandHints.Items.Count>0);
  FCommandHints.ItemIndex:=0; FCommandHints.BringToFront;
end;
procedure TMathEditor.CommandHintClick(Sender:TObject);
begin
  if (FCommandHints=nil) or (FCommandHints.ItemIndex<0) then Exit;
  FCommandFinishing:=True;
  try FCommandEdit.Text:=FCommandHints.Items[FCommandHints.ItemIndex]; finally FCommandFinishing:=False; end;
  FinishCommand(True);
end;
procedure TMathEditor.CommandChanged(Sender:TObject);
var HadFocus:Boolean; I:Integer; Tail,EnvName:string; Key:TUTF8Char;
begin
  if FCommandFinishing or not CommandActive then Exit;
  RefreshCommandHints;
  if FCommandEdit.Text='\\' then begin FinishCommand(True); Exit; end;
  if Copy(FCommandEdit.Text,1,7)='\begin{' then begin
    I:=7; EnvName:=ReadTeXGroup(FCommandEdit.Text,I,'{','}');
    if (EnvName<>'') and (Copy(FCommandEdit.Text,I-1,1)='}') then begin
      Tail:=Copy(FCommandEdit.Text,I,MaxInt); FCommandFinishing:=True;
      try FCommandEdit.Text:=Copy(FCommandEdit.Text,1,I-1); finally FCommandFinishing:=False; end;
      FinishCommand(True);
      while Tail<>'' do begin Key:=UTF8Copy(Tail,1,1); UTF8Delete(Tail,1,1); UTF8KeyPress(Key); end;
    end;
    Exit;
  end;
  if Copy(FCommandEdit.Text,1,5)='\verb' then
  begin
    I:=6;
    if Copy(FCommandEdit.Text,I,1)='*' then Inc(I);
    { The first non-letter is a delimiter, not the next ordinary key after a
      brace-based command. Keep \verb* pending until its delimiter arrives. }
    if (I=7) and (Length(FCommandEdit.Text)<I) then Exit;
    if (Length(FCommandEdit.Text)>=I) and not (FCommandEdit.Text[I] in ['a'..'z','A'..'Z','@',' ',#9,#10,#13]) then
    begin
      Tail:=Copy(FCommandEdit.Text,I+1,MaxInt); FCommandFinishing:=True;
      try FCommandEdit.Text:=Copy(FCommandEdit.Text,1,I); finally FCommandFinishing:=False; end;
      FinishCommand(True);
      while Tail<>'' do begin Key:=UTF8Copy(Tail,1,1); UTF8Delete(Tail,1,1); UTF8KeyPress(Key); end;
      Exit;
    end;
  end;
  if Pos('\left',FCommandEdit.Text)=1 then
  begin
    if MatchingRight(FCommandEdit.Text)<>'' then FinishCommand(True);
    Exit;
  end;
  if (Length(FCommandEdit.Text)>2) and (FCommandEdit.Text[1]='\') then
  begin
    I:=2;
    while (I<=Length(FCommandEdit.Text)) and (FCommandEdit.Text[I] in ['a'..'z','A'..'Z','@']) do Inc(I);
    if (I>2) and (I<=Length(FCommandEdit.Text)) then
    begin
      Tail:=Copy(FCommandEdit.Text,I,MaxInt); FCommandFinishing:=True;
      try FCommandEdit.Text:=Copy(FCommandEdit.Text,1,I-1); finally FCommandFinishing:=False; end;
      FinishCommand(True);
      while Tail<>'' do
      begin
        Key:=UTF8Copy(Tail,1,1); UTF8Delete(Tail,1,1);
        UTF8KeyPress(Key);
      end;
      Exit;
    end;
  end;
  if FCommandEdit.Text<>'' then Exit;
  HadFocus:=FCommandEdit.Focused; FCommandFinishing:=True;
  try FCommandEdit.Visible:=False; finally FCommandFinishing:=False; end;
  if HadFocus then RefocusEditor;
end;
procedure TMathEditor.CommandKeyDown(Sender:TObject; var Key:Word; Shift:TShiftState);
begin
  if (FCommandHints<>nil) and FCommandHints.Visible then begin
    if Key in [VK_UP,VK_DOWN] then begin FCommandHints.ItemIndex:=EnsureRange(FCommandHints.ItemIndex+IfThen(Key=VK_UP,-1,1),0,FCommandHints.Items.Count-1); Key:=0; Exit; end;
    if Key in [VK_TAB,VK_RETURN] then begin CommandHintClick(FCommandHints); Key:=0; Exit; end;
  end;
  if Key=VK_ESCAPE then
  begin
    if FCommandHints<>nil then FCommandHints.Visible:=False;
    FCommandFinishing:=True;
    try FCommandEdit.Visible:=False; finally FCommandFinishing:=False; end;
    Key:=0; RefocusEditor;
  end
  else if (Key=VK_RETURN) or (Key=VK_SPACE) then
  begin
    if (Key=VK_SPACE) and (FCommandEdit.Text='\') then begin
      FCommandFinishing:=True;
      try FCommandEdit.Text:='\ '; finally FCommandFinishing:=False; end;
      FinishCommand(True); Key:=0; Exit;
    end;
    FinishCommand(True);
    Key:=0;
  end;
end;
procedure TMathEditor.CommandExit(Sender:TObject);
begin
  if (FCommandHints<>nil) and FCommandHints.Visible and PtInRect(FCommandHints.ClientRect,FCommandHints.ScreenToClient(Mouse.CursorPos)) then Exit;
  QueueFocusCompletion;
end;
function TMathEditor.ControlWordSuffix(const Command:string):string;
var Fill:TTeXFill;
begin
  if NativeUnitField then Exit('');
  if InMath or ReadHorizontalFill(Command,Fill) or (Command='\protect') or (Command='\relax') then Result:=' '
  else Result:='{}';
end;
procedure TMathEditor.FinishCommand(Refocus:Boolean);
var Value:string; I:Integer; ControlWord:Boolean;
begin
  if FCommandFinishing or not CommandActive then Exit;
  if FCommandHints<>nil then FCommandHints.Visible:=False;
  FCommandFinishing:=True;
  try
    Value:=FCommandEdit.Text; FCommandEdit.Visible:=False;
    if (Value='\') or (Value='\\') then
    begin
      if InMath then Value:='\backslash ' else Value:='\textbackslash{}';
    end
    else if (Value<>'\verb') and (Value<>'\verb*') then
    begin
      ControlWord:=(Length(Value)>1) and (Value[1]='\');
      for I:=2 to Length(Value) do
        if not (Value[I] in ['a'..'z','A'..'Z','@']) then ControlWord:=False;
      if ControlWord then
      begin
        Value:=MacroTemplate(Value);
        if Pos('{',Value)=0 then Value:=Value+ControlWordSuffix(Value);
      end;
    end;
    if MatchingRight(Trim(Value))<>'' then Value:=Trim(Value);
    if Value<>'' then InsertCommand(Value);
  finally FCommandFinishing:=False; end;
  if Refocus then RefocusEditor;
end;
procedure TMathEditor.ToggleSelectedMath;
var N:TMathNode; A,B,Swap:Integer; Value:string;
  function SelectedFormula(Node:TMathNode):TMathNode;
  var I,First:Integer;
  begin
    Result:=nil;
    if Node.Kind=mkFormula then begin
      First:=MathSourceOffset(Node)-Length(Node.Prefix);
      if (First=A) and (First+Length(Node.TeX)=B) then Exit(Node);
    end;
    for I:=0 to Node.Children.Count-1 do begin
      Result:=SelectedFormula(TMathNode(Node.Children[I])); if Result<>nil then Exit;
    end;
  end;
begin
  GetSourceSelection(A,B); if A>B then begin Swap:=A; A:=B; B:=Swap; end;
  N:=nil; if (A<>B) and (FRoot<>nil) then N:=SelectedFormula(FRoot);
  if N=nil then begin N:=CurrentNode; while (N<>nil) and (N.Kind<>mkFormula) do N:=N.Parent; end;
  if N<>nil then begin
    A:=MathSourceOffset(N)-Length(N.Prefix); B:=A+Length(N.TeX);
    Value:=Copy(N.TeX,Length(N.Prefix)+1,Length(N.TeX)-Length(N.Prefix)-Length(N.Suffix));
    Commit(Copy(FSource,1,A)+Value+Copy(FSource,B+1,MaxInt),A+Length(Value));
    SetSourceSelection(A,A+Length(Value));
  end else begin
    Value:=Copy(FSource,A+1,B-A); if Value='' then Value:=' ';
    Commit(Copy(FSource,1,A)+'$'+Value+'$'+Copy(FSource,B+1,MaxInt),A+1);
    SetSourceSelection(A+1,A+Length(Value)+1);
  end;
  RefocusEditor; NotifySelection;
end;
procedure TMathEditor.ToggleSelectionSource;
var A,B,Caret,PreviousA,PreviousB:Integer; N,Target:TMathNode; SourceIndex:TMathSourceIndex;
  procedure Balance(Node:TMathNode);
  var I,L,R:Integer; Opaque:Boolean;
  begin
    L:=MathSourceOffset(Node)-Length(Node.Prefix); R:=L+MathSourceLength(Node);
    if (A>=R) or (B<=L) then Exit;
    Opaque:=(Node.Kind in [mkCommand,mkTextCommand,mkDefinition,mkUnknownCommand,mkComment,mkVerbatim,
      mkTable,mkMatrix,mkAligned,mkCases]) or IsVerbatimField(Node);
    if Opaque or (A<MathSourceOffset(Node)) or (B>R-Length(Node.Suffix)) then begin
      A:=Min(A,L); B:=Max(B,R);
    end;
    if not Opaque then for I:=0 to Node.Children.Count-1 do Balance(TMathNode(Node.Children[I]));
  end;
begin
  Caret:=SourceCaret;
  if not SelectionRange(A,B) then begin
    N:=CurrentNode;
    while N<>nil do begin
      if (N.Kind=mkDiagram) or ((N.Kind=mkUnknownCommand) and IsDiagramSource(N.TeX)) then begin
        ToggleSourceAt(MathSourceOffset(N)-Length(N.Prefix),False); Exit;
      end;
      N:=N.Parent;
    end;
    if InMath then begin FormulaSourceMode:=not FormulaSourceMode; Exit; end;
  end;
  if FInlineSourceA>=0 then begin FInlineSourceA:=-1; ParseSource; SetSourceCaret(Caret); Schedule; if Assigned(FLayout) then FLayout(Self); Exit; end;
  GetSourceSelection(A,B);
  if A>B then begin PreviousA:=A; A:=B; B:=PreviousA; end;
  if A=B then begin
    N:=CurrentNode; Target:=N;
    while N<>nil do begin
      if (N.Kind in [mkFormula,mkDefinition,mkCommand,mkUnknownCommand,mkEnvironment,mkTable,mkVerbatim]) or
        ((N.Kind=mkGroup) and IsVerbatimField(N)) then begin Target:=N; Break; end;
      N:=N.Parent;
    end;
    if Target=nil then Exit; A:=MathSourceOffset(Target)-Length(Target.Prefix); B:=A+Length(Target.TeX);
  end;
  SourceIndex:=TMathSourceIndex.Create(FRoot);
  try repeat PreviousA:=A; PreviousB:=B; Balance(FRoot); until (A=PreviousA) and (B=PreviousB);
  finally SourceIndex.Free; end;
  FInlineSourceA:=A; FInlineSourceB:=B; ParseSource; SetSourceCaret(EnsureRange(Caret,A,B)); Schedule;
  if Assigned(FLayout) then FLayout(Self);
end;
procedure TMathEditor.SetParagraphSourceMode(Value:Boolean);
var A,B:Integer;
begin
  if not FParagraph or (FCodeOnly=Value) then Exit;
  if Value then FinishVisualSource;
  FinishCommand; FinishDefinitionEdit; GetSourceSelection(A,B);
  FCodeOnly:=Value; FInlineSourceA:=-1; FFormulaSourceMode:=False;
  FSourcePreviewStart:=-1; FDiagramSourceStart:=-1;
  ParseSource; SetSourceSelection(A,B); Schedule;
  if Assigned(FLayout) then FLayout(Self);
  NotifySelection;
end;
procedure TMathEditor.SetContext(const Preamble,Directory,Engine,Environment:string; DisplayMath:Boolean);
var Reparse:Boolean; Anchor,Focus:Integer;
begin
  if (FMacroContext<>'') and (FMacroContext<>#0) and (FPreamble=Preamble) and (FDirectory=Directory) and (FEngine=Engine) and
     (FEnvironment=Environment) and (FDisplayMath=DisplayMath) then Exit;
  Reparse:=(FRoot<>nil) and (FEngine<>Engine) and (Pos('\if',FSource)>0) and not FCodeOnly;
  if Reparse then GetSourceSelection(Anchor,Focus);
  FPreamble:=Preamble; FDirectory:=Directory; FEngine:=Engine;
  FEnvironment:=Environment; FDisplayMath:=DisplayMath;
  FreeAndNil(FHintNames); InvalidateDraft;
  if Reparse then begin ParseSource; SetSourceSelection(Anchor,Focus); end;
end;
procedure TMathEditor.InvalidateContext;
begin FMacroContext:=#0; FStyleContext:=#0; if FContext<>nil then FContext.Invalidate; InvalidateDraft; end;
procedure TMathEditor.RefreshDiagramPreview;
begin InvalidateDraft; Invalidate; end;
function TMathEditor.HasDiagramPreview:Boolean;
  function Contains(Box:TDraftBox):Boolean;
  var I:Integer;
  begin
    Result:=False; if Box=nil then Exit;
    if Box.DiagramContent then Exit(True);
    for I:=0 to Box.Children.Count-1 do if Contains(TDraftBox(Box.Children[I])) then Exit(True);
  end;
begin Result:=(FDraft<>nil) and Contains(FDraft.RootBox); end;
procedure TMathEditor.ReleaseRenderCache;
begin
  { Off-screen cards keep their measured height. Layout must not recreate
    their drawing trees on every edit elsewhere in the document. }
  if (FDraft=nil) and (FRegistry=nil) and (FContext=nil) and (FGeneratedPreview=nil) then Exit;
  FLinkTimer.Enabled:=False; FHoverPreview:=nil; FSourceHover:=Point(-1,-1); ClearLinkHover;
  FSourceFrameNode:=nil; FSourceFrameRects:=nil;
  FreeAndNil(FDraft); FreeAndNil(FGeneratedPreview); FreeAndNil(FContext); FDraftDirty:=True;
  if FReadOnly then begin FreeAndNil(FRegistry); FMacroContext:=#0; end;
  {$IFDEF LCLgtk3}FreeAndNil(FMeasureBitmap);{$ENDIF}
end;
procedure TMathEditor.SetPreviewFrame(Value:Integer);
begin if Value=FPreviewFrame then Exit; FPreviewFrame:=Value; Invalidate; end;
procedure TMathEditor.NotifySelection;
var N:TMathNode;
begin
  if not SelectionGesture then FinishEmptyScript;
  if not FMaterializingOptional and not SelectionGesture then begin
    N:=CurrentNode;
    while (N<>nil) and (N.Kind<>mkOptional) do N:=N.Parent;
    if (FOptionalCommandStart>=0) and ((N=nil) or (N.Parent=nil) or
       (MathSourceOffset(N.Parent)-Length(N.Parent.Prefix)<>FOptionalCommandStart) or
       (N.Parent.Children.IndexOf(N)<>FOptionalArgumentIndex)) then begin
      FinishOptionalEdit; N:=CurrentNode;
      while (N<>nil) and (N.Kind<>mkOptional) do N:=N.Parent;
    end;
    if (N<>nil) and N.OptionalDefault and (N.Suffix=']') and (N.Parent<>nil) and
       (N.Parent.Kind=mkCommand) then begin
      FOptionalCommandStart:=MathSourceOffset(N.Parent)-Length(N.Parent.Prefix);
      FOptionalArgumentIndex:=N.Parent.Children.IndexOf(N);
    end;
  end;
  if SourceCaret<>FOptionalResumeOffset then FOptionalResumeOffset:=-1;
  if (FDefinitionStart>=0) and not FFinishingDefinition then begin
    N:=DefinitionNodeAtCaret;
    if (N=nil) or (MathSourceOffset(N)-Length(N.Prefix)<>FDefinitionStart) then FinishDefinitionEdit;
  end;
  if FFormulaSourceMode and FParagraph and not FReadOnly and not EditingSourcePreview then begin SetFormulaSourceMode(False); Exit; end;
  if Assigned(FSelectionChange) then FSelectionChange(Self);
end;
function TMathEditor.CurrentEmptyScript:TMathNode;
var Argument:TMathNode;
begin
  Result:=CurrentNode;
  while Result<>nil do begin
    if (Result.Kind=mkGroup) and (Result.Prefix<>'') and (Result.Prefix[1] in ['^','_']) and
       (Result.Children.Count=1) then begin
      Argument:=TMathNode(Result.Children[0]);
      if (Argument.Kind=mkGroup) and (Argument.Prefix='{') and (Argument.Suffix='}') and
         (Trim(Copy(Argument.TeX,2,Length(Argument.TeX)-2))='') then Exit;
    end;
    Result:=Result.Parent;
  end;
end;
procedure TMathEditor.TrackEmptyScript;
var Node:TMathNode;
begin
  FEmptyScriptStart:=-1; if FCodeOnly or FFormulaSourceMode then Exit;
  Node:=CurrentEmptyScript;
  if Node<>nil then FEmptyScriptStart:=MathSourceOffset(Node)-Length(Node.Prefix);
end;
procedure TMathEditor.FinishEmptyScript(LeavingEditor:Boolean);
var Node:TMathNode; Start,After,Caret,Anchor,Focus:Integer; Value:string; Index:TMathSourceIndex; Selected:Boolean;
  function Find(N:TMathNode):TMathNode;
  var I:Integer;
  begin
    Result:=nil;
    if (N.Kind=mkGroup) and (N.Prefix<>'') and (N.Prefix[1] in ['^','_']) and
       (MathSourceOffset(N)-Length(N.Prefix)=Start) then Exit(N);
    for I:=0 to N.Children.Count-1 do begin Result:=Find(TMathNode(N.Children[I])); if Result<>nil then Exit; end;
  end;
  function Shift(Offset:Integer):Integer;
  begin
    Result:=Offset;
    if Offset>=After then Dec(Result,After-Start) else if Offset>Start then Result:=Start;
  end;
begin
  if FCleaningScript or FReadOnly or FCodeOnly or FFormulaSourceMode or (FRoot=nil) or SelectionGesture then Exit;
  if (FSelectionAnchor>=0) and ((FSelectionFocus<0) or (FSelectionFocus<>FSelectionAnchor)) then Exit;
  Node:=CurrentEmptyScript; Start:=FEmptyScriptStart;
  if not LeavingEditor and (Node<>nil) and (MathSourceOffset(Node)-Length(Node.Prefix)=Start) then Exit;
  FEmptyScriptStart:=-1;
  if Start>=0 then begin
    Index:=TMathSourceIndex.Create(FRoot);
    try Node:=Find(FRoot); finally Index.Free; end;
    if Node<>nil then begin
      Value:=Trim(Copy(Node.TeX,Length(Node.Prefix)+1,MaxInt));
      if (Length(Value)>=2) and (Value[1]='{') and (Value[Length(Value)]='}') and
         (Trim(Copy(Value,2,Length(Value)-2))='') then begin
        After:=Start+Length(Node.TeX); Caret:=Shift(SourceCaret);
        Anchor:=Shift(FSelectionAnchor); Focus:=Shift(FSelectionFocus); Selected:=FSelected;
        Value:=Copy(FSource,1,Start)+Copy(FSource,After+1,MaxInt);
        FCleaningScript:=True;
        try Commit(Value,Caret); FSelectionAnchor:=Anchor; FSelectionFocus:=Focus; FSelected:=Selected;
        finally FCleaningScript:=False; end;
      end;
    end;
  end;
  if not LeavingEditor then TrackEmptyScript;
end;
function TMathEditor.GetSelectionGesture:Boolean;
begin Result:=FDragging or FKeyboardSelecting; end;
procedure TMathEditor.SetFormulaSourceMode(Value:Boolean);
begin SetPreviewSourceMode(Value,-1); end;
procedure TMathEditor.SetPreviewSourceMode(Value:Boolean; Offset:Integer; Caret:Integer);
var A,B:Integer; N:TMathNode;
begin
  if Value=FFormulaSourceMode then Exit; FinishCommand;
  if Value and FParagraph then begin
    if Offset<0 then begin
      N:=CurrentNode; while (N<>nil) and not IsSourcePreviewNode(N) do N:=N.Parent;
      if N=nil then Exit;
      Offset:=MathSourceOffset(N)-Length(N.Prefix);
    end;
    FSourcePreviewStart:=Offset;
  end;
  GetSourceSelection(A,B);
  if Caret>=0 then begin A:=Caret; B:=Caret; end;
  FFormulaSourceMode:=Value;
  ParseSource; SetSourceSelection(A,B); Schedule;
  if Assigned(FLayout) then FLayout(Self);
  NotifySelection;
end;
procedure TMathEditor.ToggleSourceAt(Offset:Integer; Formula:Boolean);
var Caret,I:Integer; N:TMathNode; Picture:Boolean;
begin
  FVerticalRun:=False;
  Offset:=FinishVisualSource(Offset);
  if not Formula then for I:=0 to FFields.Count-1 do begin
    N:=TMathNode(FFields[I]);
    while (N<>nil) and (N.Kind<>mkDefinition) do N:=N.Parent;
    if (N<>nil) and (MathSourceOffset(N)-Length(N.Prefix)=Offset) then begin
      SetSourceCaret(MathSourceOffset(TMathNode(N.Children[1]))); ToggleDefinitionSource; Exit;
    end;
  end;
  if Formula then begin
    if FFormulaSourceMode and (not FParagraph or (Offset=FSourcePreviewStart)) then
      SetFormulaSourceMode(False)
    else begin
      if FFormulaSourceMode then SetFormulaSourceMode(False);
      N:=nil;
      if FParagraph then for I:=0 to FFields.Count-1 do begin
        N:=TMathNode(FFields[I]);
        while (N<>nil) and (not IsSourcePreviewNode(N) or (MathSourceOffset(N)-Length(N.Prefix)<>Offset)) do N:=N.Parent;
        if (N<>nil) and (MathSourceOffset(N)-Length(N.Prefix)=Offset) then Break;
        N:=nil;
      end;
      Caret:=-1;
      if FParagraph then begin
        if N=nil then Exit;
        if (N.Kind=mkFormula) or IsProseGroup(N) then begin
          if (SourceCaret<Offset+Length(N.Prefix)) or (SourceCaret>Offset+Length(N.TeX)-Length(N.Suffix)) then
            Caret:=Offset+Length(N.Prefix);
        end else if (SourceCaret<=Offset) or (SourceCaret>=Offset+Length(N.TeX)) then
          Caret:=Offset+Max(1,Length(N.Prefix));
      end;
      SetPreviewSourceMode(True,Offset,Caret);
    end;
    Exit;
  end;
  FinishCommand; Caret:=SourceCaret;
  Picture:=False;
  for I:=0 to FFields.Count-1 do begin
    N:=TMathNode(FFields[I]);
    while N<>nil do begin
      if (N.Kind=mkUnknownCommand) and not N.SourceEditing and
        (MathSourceOffset(N)-Length(N.Prefix)=Offset) and IsDiagramSource(N.TeX) then Picture:=True;
      N:=N.Parent;
    end;
  end;
  if Picture and not FPagedEditing then begin
    if FCollapsedDiagramStart=Offset then FCollapsedDiagramStart:=-1 else FCollapsedDiagramStart:=Offset;
  end else if FDiagramSourceStart=Offset then FDiagramSourceStart:=-1 else FDiagramSourceStart:=Offset;
  ParseSource; SetSourceCaret(Caret); Schedule;
  if Assigned(FLayout) then FLayout(Self); NotifySelection;
end;
function TMathEditor.SourcePreviewNode:TMathNode;
var N:TMathNode;
begin
  Result:=nil;
  if (FDraft<>nil) and (FDraft.PinnedSourceOffset>0) then Exit;
  N:=FHoverPreview;
  if (N=nil) and InMath then N:=CurrentNode;
  while N<>nil do begin
    if (N.Kind=mkDiagram) or ((N.Kind=mkUnknownCommand) and IsDiagramSource(N.TeX)) then Exit(nil);
    if (N.Kind=mkFormula) or ((Result=nil) and IsSourcePreviewNode(N)) then Result:=N;
    if (N.Kind=mkDefinition) and (N.Children.Count=2) and (Result<>nil) and
      (MathSourceOffset(Result)<MathSourceOffset(TMathNode(N.Children[1]))) then Result:=N;
    N:=N.Parent;
  end;
  if (Result=nil) and not FParagraph and InMath then Result:=FRoot;
  if (Result<>nil) and (Result.SourcePreview<>nil) then Result:=nil;
end;
function TMathEditor.SourceFrameRects:TSelectionRects;
var N,Last:TMathNode; I,J,A,Slide,Distance,Best:Integer; R:TRect; Bounds:TVectorImageBounds;
    Regions:TDraftRegions; Hover:TPoint;
begin
  Result:=nil; N:=SourcePreviewNode; if N=nil then Exit;
  EnsureDraft;
  Slide:=FActiveSlide;
  if FPagedEditing and FRegistry.Presentation and (FHoverPreview<>nil) then begin
    Last:=N; while Last.Children.Count>0 do Last:=TMathNode(Last.Children.Last);
    Best:=MaxInt; Hover:=FSourceHover-Point(ImageLeft,ImageTop);
    for I:=0 to High(FDraft.Regions) do if (FDraft.Regions[I].ID>=N.ID) and (FDraft.Regions[I].ID<=Last.ID) then begin
      R:=FDraft.Regions[I].Bounds;
      Distance:=Max(0,Max(R.Left-Hover.X,Hover.X-R.Right))+Max(0,Max(R.Top-Hover.Y,Hover.Y-R.Bottom));
      if Distance<Best then begin Best:=Distance; Slide:=FDraft.Regions[I].Slide; end;
    end;
  end;
  if (FSourceFrameNode<>N) or (FSourceFrameSlide<>Slide) then begin
    FSourceFrameRects:=nil;
    if GeneratedTextActive then begin
      R:=GeneratedBounds; OffsetRect(R,-ImageLeft,-ImageTop);
      for Bounds in FGeneratedPreview.SelectionBounds(0,UTF8Length(FGeneratedPreview.RenderedText)) do begin
        I:=Length(FSourceFrameRects); SetLength(FSourceFrameRects,I+1);
        FSourceFrameRects[I]:=Rect(R.Left+Round(Bounds.Left*R.Width),R.Top+Round(Bounds.Top*R.Height),
          R.Left+Round(Bounds.Right*R.Width),R.Top+Round(Bounds.Bottom*R.Height));
      end;
    end else begin
      A:=MathSourceOffset(N)-Length(N.Prefix);
      Regions:=FDraft.Regions;
      if Slide>0 then begin
        Regions:=Copy(Regions); J:=0;
        for I:=0 to High(Regions) do if (Regions[I].Slide=0) or (Regions[I].Slide=Slide) then begin
          Regions[J]:=Regions[I]; Inc(J);
        end;
        SetLength(Regions,J);
      end;
      FSourceFrameRects:=MathSelectionRects(FRoot,FFields,Regions,A,A+MathSourceLength(N));
    end;
    if Length(FSourceFrameRects)=0 then begin
      R:=NodeBounds(N); OffsetRect(R,-ImageLeft,-ImageTop);
      if (R.Width>0) and (R.Height>0) then begin SetLength(FSourceFrameRects,1); FSourceFrameRects[0]:=R; end;
    end;
    for I:=0 to High(FSourceFrameRects) do InflateRect(FSourceFrameRects[I],3,3);
    FSourceFrameNode:=N; FSourceFrameSlide:=Slide;
  end;
  Result:=Copy(FSourceFrameRects);
  for I:=0 to High(Result) do OffsetRect(Result[I],ImageLeft,ImageTop);
end;
function TMathEditor.SourceDisclosureBounds:TRect;
var Boxes:TSelectionRects; X,Y,W:Integer;
begin
  Result:=Rect(0,0,0,0);
  if FReadOnly and not FPagedEditing then Exit;
  Boxes:=SourceFrameRects; if Length(Boxes)=0 then Exit;
  Result:=Boxes[0];
  W:=ClientWidth;
  {$IFDEF LCLgtk3}W:=Width;{$ENDIF}
  if Length(Boxes)>1 then begin
    X:=Max(0,Boxes[1].Left-28); Y:=Boxes[1].Top;
  end
  else begin
    X:=EnsureRange((Result.Left+Result.Right-28) div 2,0,Max(0,W-28));
    { Share the bottom stroke, without covering formula ink. }
    Y:=Result.Bottom-1;
  end;
  Result:=Rect(X,Y,X+28,Y+28);
end;
function TMathEditor.SourceToggleAt(X,Y:Integer; out Offset:Integer; out Formula:Boolean):Boolean;
var Toggle:TDraftSourceToggle; N:TMathNode;
begin
  EnsureDraft; Result:=False;
  for Toggle in FDraft.SourceToggles do if FDraft.SourceControlVisible(Toggle) and
    PtInRect(Toggle.Bounds,Point(X-ImageLeft,Y-ImageTop)) then begin
    Offset:=Toggle.Offset; Formula:=Toggle.Formula; Exit(True);
  end;
  if PtInRect(SourceDisclosureBounds,Point(X,Y)) then begin
    N:=SourcePreviewNode;
    Offset:=0; if N<>nil then Offset:=MathSourceOffset(N)-Length(N.Prefix);
    Formula:=True; Exit(True);
  end;
end;
procedure TMathEditor.SetDocumentContext(Blocks:TStrings; Index:Integer; SharedContext:TTeXContext; const BeforeDeclarations:string; BeforeOffset:Integer);
var I:Integer; ContextChanged:Boolean; Declarations:string;
begin
  { The document owns this stable list. Copying every block into every card
    duplicates the entire document once per paragraph. }
  if Blocks=nil then Blocks:=FOwnDocumentBlocks;
  Declarations:=BeforeDeclarations;
  if BeforeOffset<0 then begin
    BeforeOffset:=0;
    for I:=0 to Min(Index-1,Blocks.Count-1) do Inc(BeforeOffset,Length(Blocks[I]));
  end;
  if SharedContext=nil then for I:=0 to Min(Index-1,Blocks.Count-1) do
    Declarations:=Declarations+TeXContextDeclarations(Blocks[I]);
  ContextChanged:=(Blocks<>FDocumentBlocks) or (Index<>FDocumentIndex) or (Declarations<>FBeforeDeclarations) or
    (SharedContext<>FSharedContext) or (SharedContext=nil);
  if SharedContext<>nil then begin
    ContextChanged:=ContextChanged or (FSharedRevision<>SharedContext.LayoutRevision);
    FSharedRevision:=SharedContext.LayoutRevision;
  end;
  FDocumentBlocks:=Blocks; FDocumentIndex:=Index; FSharedContext:=SharedContext;
  FBeforeOffset:=BeforeOffset; FBeforeDeclarations:=Declarations;
  if FDraft<>nil then FDraft.ContextOffset:=Length(FPreamble)+FBeforeOffset;
  LoadRegistry;
  if ContextChanged then begin InvalidateDraft; FStyleContext:=#0; end;
end;
procedure TMathEditor.LoadRegistry(Force:Boolean);
var Source,Key:string;
begin
  Source:=FPreamble+LineEnding+FBeforeDeclarations;
  Key:=FDirectory+#0+FEngine+#0+Source;
  if not Force and (FRegistry<>nil) and (Key=FMacroContext) then Exit;
  if FRegistry=nil then FRegistry:=TMacroRegistry.Create;
  FRegistry.Load(Source,FDirectory,FEngine); FMacroContext:=Key; FreeAndNil(FHintNames);
end;
procedure TMathEditor.ParseSource;
var N,Preview,CodeRoot:TMathNode; Error:string; Serial:Integer;
  function SourcePreviews(Node:TMathNode):TMathNode;
  var I:Integer; Code,Child,Replacement:TMathNode; Value:string;
  begin
    Result:=Node;
    if IsSourcePreviewNode(Node) and (MathSourceOffset(Node)-Length(Node.Prefix)=FSourcePreviewStart) then begin
      Value:=Node.TeX;
      if (Node.Kind=mkFormula) or IsProseGroup(Node) then begin
        Value:=Copy(Value,Length(Node.Prefix)+1,Length(Value)-Length(Node.Prefix)-Length(Node.Suffix));
        if Node.Children.Count=0 then Node.SourcePreview:=TMathNode.Create(mkRow)
        else Node.SourcePreview:=TMathNode(Node.Children.Extract(Node.Children[0]));
        Node.Children.Clear;
      end else begin
        Result:=TMathNode.Create(mkSource); Result.SourcePreview:=Node;
      end;
      Result.SourcePreview.Parent:=nil;
      Code:=Result.Add(TMathNode.Create(mkUnknownCommand)); Code.SourceEditing:=True;
      Code.Add(TMathNode.Create(mkProse,Value)); Exit;
    end;
    for I:=0 to Node.Children.Count-1 do begin
      Child:=TMathNode(Node.Children[I]); Replacement:=SourcePreviews(Child);
      if Child=Replacement then Continue;
      Node.Children.Extract(Child); Node.Children.Insert(I,Replacement); Replacement.Parent:=Node;
    end;
  end;
  procedure SourceDiagrams(Node:TMathNode);
  var I:Integer; Preview,Code:TMathNode; Value:string;
  begin
    if (Node.Kind=mkUnknownCommand) and not Node.SourceEditing and IsDiagramSource(Node.TeX) then begin
      if FPagedEditing then Node.SourceCollapsed:=MathSourceOffset(Node)-Length(Node.Prefix)<>FDiagramSourceStart
      else Node.SourceCollapsed:=MathSourceOffset(Node)-Length(Node.Prefix)=FCollapsedDiagramStart;
    end;
    if (FDiagramSourceStart>=0) and
       ((Node.Kind=mkDiagram) or ((Node.Kind=mkUnknownCommand) and IsDiagramSource(Node.TeX))) and
       (MathSourceOffset(Node)-Length(Node.Prefix)=FDiagramSourceStart) then begin
      Node.SourceExpanded:=True;
      if Node.Kind=mkDiagram then begin
        Value:=Node.TeX; Preview:=TMathNode.Create(mkDiagram,Node.Text);
        while Node.Children.Count>0 do Preview.Add(TMathNode(Node.Children.Extract(Node.Children[0])));
        Node.SourcePreview:=Preview; Node.SourceEditing:=True;
        Code:=Node.Add(TMathNode.Create(mkUnknownCommand)); Code.SourceEditing:=True;
        Code.Add(TMathNode.Create(mkProse,Value));
      end;
      Exit;
    end;
    for I:=0 to Node.Children.Count-1 do SourceDiagrams(TMathNode(Node.Children[I]));
  end;
  procedure Renumber(Node:TMathNode; Grouped:Boolean=False);
  var I,P:Integer; Name:string; Info:TMacroInfo;
  begin
    Node.ID:=Serial; Inc(Serial); Grouped:=Grouped or IsProseGroup(Node);
    { Declarations still affect rendering, but their invisible source is only
      a caret target after the group has been expanded. }
    if Grouped and not Node.SourceEditing and (Node.Kind in [mkCommand,mkUnknownCommand]) then begin
      Name:=Node.Text; if Node.Kind=mkUnknownCommand then Name:=Node.TeX;
      P:=1; Name:=ReadTeXCommand(Name,P); Info:=FRegistry.Find(Name);
      if IsTextStyleSwitch(Name) or ((Info<>nil) and (Info.PreviewAdapter='fontswitch')) then Node.Hidden:=True;
    end;
    { Preview trees share the layout/projection index with editable fields. }
    if Node.SourcePreview<>nil then Renumber(Node.SourcePreview,Grouped);
    for I:=0 to Node.Children.Count-1 do Renumber(TMathNode(Node.Children[I]),Grouped);
  end;
  procedure SourceDefinitions(Node:TMathNode);
  var I:Integer; D:TCommandDefinition; Field,Code:TMathNode;
  begin
    if (Node.Kind=mkDefinition) and (Node.Children.Count=2) and
      (MathSourceOffset(Node)-Length(Node.Prefix)=FDefinitionSourceStart) and ReadCommandDefinition(Node.TeX,D) then begin
      Node.SourceExpanded:=True;
      Field:=TMathNode(Node.Children[1]); Field.Children.Clear; Field.Kind:=mkRow; Field.Text:='';
      Code:=Field.Add(TMathNode.Create(mkUnknownCommand)); Code.Add(TMathNode.Create(mkProse,D.Body)); Exit;
    end;
    for I:=0 to Node.Children.Count-1 do SourceDefinitions(TMathNode(Node.Children[I]));
  end;
begin
  FHoverPreview:=nil;
  if FDraft<>nil then FDraft.PinnedSourceOffset:=0;
  LoadRegistry; N:=nil; FFallback:=False;
  try
    if FCodeOnly and FDefinitionsInCode then N:=ParsePreambleCode(FSource,FRegistry)
    else if FCodeOnly then begin
      N:=TMathNode.Create(mkRow); CodeRoot:=N.Add(TMathNode.Create(mkUnknownCommand));
      CodeRoot.SourceEditing:=True; CodeRoot.Add(TMathNode.Create(mkProse,FSource));
    end else if FParagraph and (FInlineSourceA>=0) then N:=ParseParagraphSource(FSource,FRegistry,FInlineSourceA,FInlineSourceB)
    else if FParagraph then N:=ParseParagraph(FSource,FRegistry)
    else if not ParseMath(FSource,N,Error,FRegistry,True,@ParseParagraph) then
      raise Exception.Create(Error);
    if not FCodeOnly then PrepareDefinitionBodies(N,FRegistry);
    if N.TeX<>FSource then raise Exception.Create('Incomplete source');
  except
    on E:Exception do
    begin
      N.Free; N:=TMathNode.Create(mkProse,FSource); N.ID:=0;
      FFallback:=True;
    end;
  end;
  if FFormulaSourceMode and not FFallback then begin
    if FParagraph then N:=SourcePreviews(N)
    else begin
      Preview:=N; N:=TMathNode.Create(mkFormula); N.SourcePreview:=Preview;
      CodeRoot:=N.Add(TMathNode.Create(mkUnknownCommand)); CodeRoot.SourceEditing:=True;
      CodeRoot.Add(TMathNode.Create(mkProse,FSource));
    end;
    end;
  if (FPagedEditing or (FDiagramSourceStart>=0) or (FCollapsedDiagramStart>=0)) and not FFallback then SourceDiagrams(N);
  if (FDefinitionSourceStart>=0) and not FFallback then SourceDefinitions(N);
  FoldMathSource(N,FFoldedRanges);
  Serial:=0; Renumber(N);
  FFields.Clear; FRoot.Free; FRoot:=N; MathFields(FRoot,FFields);
  Inc(FFieldsRevision);
  if FFields.Count=0 then FFields.Add(FRoot);
  FActive:=EnsureRange(FActive,0,FFields.Count-1); InvalidateDraft;
end;
procedure TMathEditor.EnsureDraft;
var W,Points,Size,I,CaptionID,CaptionSpace:Integer; Scale:Double; FullSource,CaptionName:string;
    LayoutCanvas:TCanvas; CaptionNode,CaptionEnvironment:TMathNode;
begin
  if FRoot=nil then Exit;
  if FDraft=nil then FDraft:=TParagraphDraft.Create;
  W:=TextLayoutWidth;
  if not FDraftDirty and (FDraft.Context<>nil) and (FDraftPageRevision<>FDraft.Context.PageRevision) then begin
    if HasPageReferences(FSource) then FDraftDirty:=True else FDraftPageRevision:=FDraft.Context.PageRevision;
  end;
  if FDraftDirty or (FDraftWidth<>W) then
  begin
    FSourceFrameNode:=nil; FSourceFrameRects:=nil;
    LoadRegistry;
    Scale:=FPreviewZoom;
    if FReadOnly then begin
      { Measuring a hidden preview must not create a native editing widget.
        All measurements run on the GUI thread and share this small canvas. }
      if PreviewMeasureBitmap=nil then begin PreviewMeasureBitmap:=TBitmap.Create; PreviewMeasureBitmap.SetSize(1,1); end;
      LayoutCanvas:=PreviewMeasureBitmap.Canvas; LayoutCanvas.Font.Assign(Font);
    end else begin
    {$IFDEF LCLgtk3}
    { Layout also runs before a card's native widget is realized. A control
      canvas can then retain a destroyed GTK font/DC. Measure on an independent
      surface and use the control canvas only in Paint. }
    if FMeasureBitmap=nil then begin FMeasureBitmap:=TBitmap.Create; FMeasureBitmap.SetSize(1,1); end;
    LayoutCanvas:=FMeasureBitmap.Canvas; LayoutCanvas.Font.Assign(Font);
    {$ELSE}LayoutCanvas:=Canvas;{$ENDIF}
    end;
    if FTextStyleOverride<>nil then begin
      FDraft.TextStyleSeed:=FTextStyleOverride.Style; FDraft.TextColorSeed:=FTextStyleOverride.Color;
    end;
    Points:=DocumentFontPoints(FPreamble);
    if FDraft.TextStyleSeed.Points>0 then Points:=Max(1,Round(FDraft.TextStyleSeed.Points));
    Size:=Max(8,Round(Points*120*Scale/Max(1,LayoutCanvas.Font.PixelsPerInch)));
    FDraft.Macros:=FRegistry; FDraft.Directory:=FDirectory; FDraft.TeXEngine:=FEngine;
    FDraft.DocumentFontSize:=Points; FDraft.PreserveColors:=FPreserveColors;
    FDraft.SourceFontName:=FSourceFontName; FDraft.SourceFontPixels:=FSourceFontPixels;
    FDraft.ShowDiagramSource:=False; FDraft.ShowSourceControls:=not FReadOnly or FPagedEditing;
    FDraft.OverlaySourceControls:=FPagedEditing;
    FDraft.HideEnvironmentCaptions:=FPagedEditing;
    FDraft.PageLayout:=FPagedEditing; FDraft.HideEditingMarks:=FPagedEditing;
    FDraft.DiagramSitePrefix:=IntToHex(PtrUInt(FDocumentBlocks),SizeOf(Pointer)*2);
    FDraft.HeadingContext:=FPreamble+FBeforeDeclarations;
    FDraft.Generated:=nil;
    if (FGeneratedPreview<>nil) and (FGeneratedPreview.Source=FSource) and not FCodeOnly and not FFormulaSourceMode and (FInlineSourceA<0) then
      FDraft.Generated:=FGeneratedPreview;
    if (FSharedContext<>nil) and (FDocumentIndex>=0) and (FDocumentIndex<FDocumentBlocks.Count) and
       (FSource=FDocumentBlocks[FDocumentIndex]) then FDraft.Context:=FSharedContext
    else begin
      FullSource:=FPreamble;
      for I:=0 to FDocumentBlocks.Count-1 do if I=FDocumentIndex then FullSource:=FullSource+FSource else FullSource:=FullSource+FDocumentBlocks[I];
      if FDocumentIndex<0 then FullSource:=FullSource+FSource;
      if FContext=nil then FContext:=TTeXContext.Create;
      FContext.Load(FullSource,FDirectory,FEngine); FDraft.Context:=FContext;
    end;
    FDraft.ContextOffset:=Length(FPreamble)+FBeforeOffset;
    if FParagraph and GeneratedBlock(FSource) and not FCodeOnly and not FFormulaSourceMode and (FInlineSourceA<0) then begin
      if FGeneratedPreview=nil then FGeneratedPreview:=TGeneratedPreview.Create;
      if FGeneratedPreview.EnsureNative(LayoutCanvas,FSource,FDirectory,FDraft.Context,W,Size,Scale,Points*120*Scale/72.27,FRegistry,FEngine) then
        FDraft.Generated:=FGeneratedPreview;
    end;
    FDraft.HeadingWithChapter:=(Pos('{book}',FPreamble)>0) or (Pos('{report}',FPreamble)>0);
    FDraft.Layout(LayoutCanvas,FRoot,W,FParagraph or FFallback,Size,nil,FSource,Scale,Points*120*Scale/72.27);
    if FDraft.Context<>nil then FDraftPageRevision:=FDraft.Context.PageRevision;
    FDraftWidth:=W; FDraftDirty:=False; FCachedHeight:=Max(28,FDraft.Height+2);
    if FPagedEditing then FCachedHeight:=Max(1,FDraft.Height);
    Invalidate; { A deferred layout may keep the same height as its empty frame. }
  end;
  if FCustomPages then FDraft.PlacePageLines(FPageShifts,FPageHeight)
  else if FPageBody>0 then begin
    FDraft.Paginate(FPageFirst,FPageBody,FPageGap);
  end;
  CaptionID:=-1; CaptionSpace:=0; FPageCaptionPadding:=0;
  if FPagedEditing and not FReadOnly then begin
    CaptionNode:=CurrentNode;
    while (CaptionNode<>nil) and (CaptionNode.Kind<>mkFormula) do CaptionNode:=CaptionNode.Parent;
    if CaptionNode<>nil then begin
      CaptionID:=CaptionNode.ID;
      if (FHoverPreview=CaptionNode) and not FFormulaSourceMode then FPageCaptionPadding:=30;
      CaptionSpace:=FPageCaptionPadding+Max(24,Round(24*FPreviewZoom));
      CaptionEnvironment:=EnvironmentNode('');
      if (CaptionEnvironment<>nil) and IsMathField(CaptionEnvironment) and
        (CommandContextNode(CaptionName)<>nil) and (Copy(CaptionName,1,7)<>'\begin{') then
        Inc(CaptionSpace,Max(24,Round(24*FPreviewZoom)));
    end;
  end;
  if FDraft.SetEditingSpace(CaptionID,CaptionSpace,FActiveSlide) then begin FSourceFrameNode:=nil; FSourceFrameRects:=nil; end;
  FCachedHeight:=Max(28,FDraft.Height+2);
  if FPagedEditing then FCachedHeight:=Max(1,FDraft.Height);
end;
procedure TMathEditor.ConfigurePagination(FirstRoom,BodyHeight,Gap:Integer);
begin
  if not FCustomPages and (FPageFirst=FirstRoom) and (FPageBody=BodyHeight) and (FPageGap=Gap) then Exit;
  FCustomPages:=False; FPageShifts:=nil; FSourceFrameNode:=nil;
  FPageFirst:=FirstRoom; FPageBody:=BodyHeight; FPageGap:=Gap; FCachedHeight:=0; Invalidate;
  if (BodyHeight=0) and (FDraft<>nil) then FDraft.Paginate(0,0,0);
end;
procedure TMathEditor.ConfigurePageLayout(const Shifts:TPageShifts; NewHeight,BodyHeight:Integer);
begin
  if FCustomPages and (FPageHeight=NewHeight) and (FPageBody=BodyHeight) and SamePageShifts(FPageShifts,Shifts) then Exit;
  FCustomPages:=True; FPageShifts:=Copy(Shifts); FPageHeight:=NewHeight; FPageBody:=BodyHeight;
  FSourceFrameNode:=nil;
  FCachedHeight:=0; Invalidate;
end;
function TMathEditor.PageLines:TPageLines;
begin EnsureDraft; Result:=FDraft.PageLines; end;
function TMathEditor.NativeHeight:Integer;
begin EnsureDraft; if FPagedEditing then Result:=Max(0,FDraft.NativeHeight) else Result:=Max(28,FDraft.NativeHeight+2); end;
function TMathEditor.PageSourcesExpanded:Boolean;
begin Result:=FFormulaSourceMode or (FDiagramSourceStart>=0) or (FInlineSourceA>=0) or (FPagedEditing and FCodeOnly); end;
function TMathEditor.LoadFormula(const Source:string; out Error:string):Boolean;
begin
  FMathShortcut:=''; FVerticalRun:=False;
  FFormulaSourceMode:=False; FSourcePreviewStart:=-1; FDiagramSourceStart:=-1; FCollapsedDiagramStart:=-1; FInlineSourceA:=-1;
  FOptionalResumeOffset:=-1; FOptionalCommandStart:=-1; FOptionalTransient:=False; FOptionalBefore:='';
  FDefinitionStart:=-1;
  FDefinitionSourceStart:=-1;
  FSelectionAnchor:=-1; FSelectionFocus:=-1;
  FEmptyScriptStart:=-1;
  FParagraph:=False;
  FDocumentIndex:=-1; FDocumentBlocks:=FOwnDocumentBlocks; FOwnDocumentBlocks.Clear;
  FSharedContext:=nil; FBeforeDeclarations:=''; FBeforeOffset:=0;
  FSource:=Source; FActive:=0; FSelected:=True; FCaret:=0; Error:='';
  FUndo.Clear; FRedo.Clear;
  ParseSource; Schedule; Result:=True;
end;
procedure TMathEditor.LoadParagraph(const Source:string; Preview:TPicture; const LayoutXML:string; LayoutPage:Integer; const Positions:string);
begin
  FMathShortcut:=''; FVerticalRun:=False;
  if Source<>FSource then FVisualSourceDirty:=False;
  FEmptyScriptStart:=-1;
  if Source<>FSource then begin FOptionalResumeOffset:=-1; FOptionalCommandStart:=-1; FOptionalTransient:=False; FOptionalBefore:=''; end;
  FGeneratedAnchor:=-1; FGeneratedFocus:=0; FGeneratedHover:=-1;
  if Source<>FSource then FDefinitionStart:=-1;
  if Source<>FSource then FDefinitionSourceStart:=-1;
  if Source<>FSource then begin FInlineSourceA:=-1; FFormulaSourceMode:=False; FSourcePreviewStart:=-1; FDiagramSourceStart:=-1; FCollapsedDiagramStart:=-1; end;
  if FCommandHints<>nil then FCommandHints.Visible:=False;
  FSelectionAnchor:=-1; FSelectionFocus:=-1;
  FParagraph:=True; FSource:=Source; FActive:=0; FSelected:=False; FCaret:=0; FActiveSlide:=0;
  FUndo.Clear; FRedo.Clear; ParseSource; Schedule;
end;
procedure TMathEditor.SetGeneratedPreview(Image:TPreviewImage; const LayoutXML:string; LayoutPage:Integer);
begin
  if GeneratedBlock(FSource) and (Pos('\maketitle',FSource)=0) then begin
    { Contents and bibliography never acquire a compiled image or PDF layout. }
    EnsureDraft; Exit;
  end;
  if not GeneratedBlock(FSource) or (Image=nil) or (Image.PreviewWidth<1) then begin
    if FGeneratedPreview<>nil then begin
      FreeAndNil(FDraft);
      FreeAndNil(FGeneratedPreview); InvalidateDraft;
    end;
    Exit;
  end;
  if FGeneratedPreview=nil then FGeneratedPreview:=TGeneratedPreview.Create;
  FGeneratedPreview.Load(Image,FSource,FSharedContext,LayoutXML,LayoutPage); InvalidateDraft;
end;
procedure TMathEditor.ClickPreview(X,Y,PreviewWidth,PreviewHeight:Integer);
begin EnsureDraft; HitField(X,Y); end;
function TMathEditor.InMath:Boolean;
begin Result:=not FFallback and (not FParagraph or IsMathField(CurrentNode)); end;
procedure TMathEditor.MovePastNode(Node:TMathNode);
var N,P:TMathNode; I,Offset,A,B,Distance,BestDistance:Integer;
begin
  Offset:=MathSourceOffset(Node)-Length(Node.Prefix)+Length(Node.TeX);
  BestDistance:=MaxInt;
  for I:=0 to FFields.Count-1 do begin
    N:=TMathNode(FFields[I]); P:=N;
    while (P<>nil) and (P<>Node) do P:=P.Parent;
    if P<>nil then Continue;
    A:=MathSourceOffset(N); B:=A+Length(N.Text); if B<Offset then Continue;
    Distance:=Max(A-Offset,0);
    if Distance<BestDistance then begin
      BestDistance:=Distance; FActive:=I; FCaret:=UTF8Length(Copy(N.Text,1,Max(0,Offset-A)));
      if Distance=0 then Break;
    end;
  end;
  if BestDistance=MaxInt then SetSourceCaret(Offset);
  FSelected:=False; FSelectionAnchor:=-1; FSelectionFocus:=-1;
  NotifySelection; Invalidate;
end;
function TMathEditor.InTextArgument:Boolean;
var N:TMathNode;
begin
  N:=CurrentNode;
  while N<>nil do
  begin
    if N.Kind=mkFormula then Exit(False);
    if N.TextMode or ((N.Kind=mkCommand) and (N.Text='\text')) then Exit(True);
    N:=N.Parent;
  end;
  Result:=False;
end;
function TMathEditor.LeaveFormula:Boolean;
var N:TMathNode; Finish:Integer;
begin
  Result:=False;
  N:=CurrentNode;
  while (N<>nil) and not (N.Kind in [mkGroup,mkOptional,mkFormula]) do N:=N.Parent;
  if (N<>nil) and (N.Kind=mkFormula) then begin
    Finish:=MathSourceOffset(N)-Length(N.Prefix)+Length(N.TeX)-Length(N.Suffix);
    if Trim(Copy(FSource,SourceCaret+1,Max(0,Finish-SourceCaret)))='' then begin MovePastNode(N); Exit(True); end;
  end;
end;
function TMathEditor.MathSpace:Boolean;
var N,Container:TMathNode;
begin
  Result:=False; if not InMath or InTextArgument then Exit;
  if LeaveFormula then Exit(True);
  Result:=True; N:=CurrentNode;
  while N<>nil do begin
    Container:=N.Parent;
    if N.Kind in [mkGroup,mkOptional] then begin
      if (N.Prefix<>'') and (N.Prefix[1] in ['^','_']) then begin MovePastNode(N); Exit; end;
      if (Container<>nil) and (Container.Kind in [mkCommand,mkFraction,mkRoot,mkIndexedRoot,mkAccent,mkBinomial]) then
        MovePastNode(Container)
      else MovePastNode(N);
      Exit;
    end;
    if N.Kind in [mkCommand,mkFraction,mkRoot,mkIndexedRoot,mkAccent,mkBinomial] then begin MovePastNode(N); Exit; end;
    if N.Kind=mkFormula then Break;
    N:=Container;
  end;
  MoveHorizontal(1); Invalidate;
end;
function TMathEditor.InsertScript(const Value:string):Boolean;
var N,Script:TMathNode; Offset,EndOffset:Integer; S:string;
begin
  Result:=InMath and not InTextArgument and ((Value='^') or (Value='_'));
  if not Result then Exit;
  N:=CurrentNode; if N=nil then Exit;
  if FSelected then begin FSelected:=False; FCaret:=UTF8Length(N.Text); end;
  Offset:=SourceCaret; Script:=N;
  while Script<>nil do
  begin
    if (Script.Kind=mkGroup) and (Script.Prefix<>'') and (Script.Prefix[1] in ['^','_']) then Break;
    Script:=Script.Parent;
  end;
  if Script<>nil then
  begin
    EndOffset:=MathSourceOffset(Script)-Length(Script.Prefix)+Length(Script.TeX);
    S:=Trim(Copy(FSource,Offset+1,EndOffset-Offset));
    while (S<>'') and (S[1]='}') do Delete(S,1,1);
    if (S='') and (Script.Prefix[1]<>Value[1]) then Offset:=EndOffset;
  end;
  Commit(Copy(FSource,1,Offset)+Value+'{}'+Copy(FSource,Offset+1,MaxInt),Offset+2);
end;
function TMathEditor.DeleteEmptyFormula:Boolean;
var N:TMathNode; Start,Finish:Integer;
begin
  Result:=False; N:=CurrentNode;
  while (N<>nil) and (N.Kind<>mkFormula) do N:=N.Parent;
  if (N=nil) or (N.Children.Count=0) or (Trim(TMathNode(N.Children[0]).TeX)<>'') then Exit;
  Start:=MathSourceOffset(N)-Length(N.Prefix); Finish:=Start+Length(N.TeX);
  Commit(Copy(FSource,1,Start)+Copy(FSource,Finish+1,MaxInt),Start); Result:=True;
end;
function TMathEditor.DeleteStructure:Boolean;
var N,Argument,Command,EndingGroup,Field:TMathNode; Start,Finish,Position,I:Integer; Keep,Prefix,Rest,Value:string; SourceIndex:TMathSourceIndex;
    OpeningBrace:Boolean;
  function NeedsSpace(const Left,Right:string):Boolean;
  var P:Integer;
  begin
    Result:=False;
    if (Right='') or not (Right[1] in ['a'..'z','A'..'Z','@']) then Exit;
    P:=Length(Left); while (P>0) and (Left[P] in ['a'..'z','A'..'Z','@']) do Dec(P);
    Result:=(P>0) and (P<Length(Left)) and (Left[P]='\');
  end;
  procedure FindEnding(Node:TMathNode);
  var I,L:Integer; P:TMathNode;
  begin
    L:=MathSourceOffset(Node)-Length(Node.Prefix);
    if IsStandaloneMathGroup(Node) and (Node.Prefix='{') and (MathSourceOffset(Node)=Position) then begin
      EndingGroup:=Node; OpeningBrace:=True;
    end;
    if (IsStandaloneMathGroup(Node) or ((Node.Kind=mkGroup) and ((Pos('\left',Node.Prefix)=1) or (Trim(Node.Prefix)='\lvert') or (Trim(Node.Prefix)='\lVert') or (Trim(Node.Prefix)='\langle')))) and
       not OpeningBrace and ((L+Length(Node.TeX)=Position) or (L=Position)) then
    begin
      P:=N; while (P<>nil) and (P<>Node) do P:=P.Parent;
      if P=nil then EndingGroup:=Node;
    end;
    for I:=0 to Node.Children.Count-1 do FindEnding(TMathNode(Node.Children[I]));
  end;
begin
  Result:=False; N:=CurrentNode; if (N=nil) or IsVerbatimField(N) then Exit;
  Command:=N.Parent;
  while Command<>nil do begin
    if (Command.Kind=mkGroup) and (Command.Prefix<>'') and (Command.Prefix[1] in ['^','_']) and
       (Command.Children.Count=1) and (SourceCaret=MathSourceOffset(TMathNode(Command.Children[0]))) then begin
      Argument:=TMathNode(Command.Children[0]); Keep:=Argument.TeX;
      if (Argument.Kind=mkGroup) and (Argument.Prefix='{') then
        Keep:=Copy(Keep,2,Length(Keep)-1-Length(Argument.Suffix));
      Start:=MathSourceOffset(Command)-Length(Command.Prefix); Finish:=Start+Length(Command.TeX);
      Prefix:=Copy(FSource,1,Start); Rest:=Copy(FSource,Finish+1,MaxInt);
      if NeedsSpace(Prefix,Keep+Rest) then Prefix:=Prefix+' ';
      Position:=Length(Prefix); Value:=Prefix+Keep;
      if NeedsSpace(Value,Rest) then Value:=Value+' ';
      Commit(Value+Rest,Position); Exit(True);
    end;
    Command:=Command.Parent;
  end;
  Position:=SourceCaret; Argument:=N; EndingGroup:=nil; OpeningBrace:=False;
  { A literal immediately to the left takes precedence over a delimiter
    beginning here. This includes the insertion slot after a unary minus. }
  SourceIndex:=TMathSourceIndex.Create(FRoot);
  try
    for I:=0 to FFields.Count-1 do begin
      Field:=TMathNode(FFields[I]);
      if (Field.Kind in [mkText,mkProse]) and (Field.Text<>'') and
         (MathSourceOffset(Field)+Length(Field.Text)=Position) then Exit;
    end;
    FindEnding(FRoot);
  finally SourceIndex.Free; end;
  if EndingGroup<>nil then
  begin
    Start:=MathSourceOffset(EndingGroup)-Length(EndingGroup.Prefix); Finish:=Start+Length(EndingGroup.TeX);
    Keep:=Copy(EndingGroup.TeX,Length(EndingGroup.Prefix)+1,Length(EndingGroup.TeX)-Length(EndingGroup.Prefix)-Length(EndingGroup.Suffix));
   Commit(Copy(FSource,1,Start)+Keep+Copy(FSource,Finish+1,MaxInt),Start+IfThen(OpeningBrace or (Position=Start),0,Length(Keep))); Exit(True);
  end;
  while (Argument<>nil) and (Argument.Parent<>nil) do
  begin
    Command:=Argument.Parent;
    if (IsStandaloneMathGroup(Command) or ((Command.Kind=mkGroup) and ((Pos('\left',Command.Prefix)=1) or (Trim(Command.Prefix)='\lvert') or (Trim(Command.Prefix)='\lVert') or (Trim(Command.Prefix)='\langle')))) and
       (Position=MathSourceOffset(Command)) then
    begin
      Start:=MathSourceOffset(Command)-Length(Command.Prefix);
      Keep:=Copy(Command.TeX,Length(Command.Prefix)+1,Length(Command.TeX)-Length(Command.Prefix)-Length(Command.Suffix));
      Finish:=Start+Length(Command.TeX);
    Commit(Copy(FSource,1,Start)+Keep+Copy(FSource,Finish+1,MaxInt),Start); Exit(True);
    end;
    if (Command.Kind=mkCommand) and (Position=MathSourceOffset(Argument)) then
    begin
      Start:=MathSourceOffset(Command)-Length(Command.Prefix); Finish:=Start+Length(Command.TeX);
      Keep:=Argument.TeX;
      if Argument.Kind in [mkGroup,mkOptional] then
        Keep:=Copy(Keep,Length(Argument.Prefix)+1,Length(Keep)-Length(Argument.Prefix)-Length(Argument.Suffix));
    Commit(Copy(FSource,1,Start)+Keep+Copy(FSource,Finish+1,MaxInt),Start); Exit(True);
    end;
    Argument:=Argument.Parent;
  end;
end;
function TMathEditor.SelectPreviousCommand:Boolean;
var Position,First:Integer; Index:TMathSourceIndex;
  procedure Find(Node:TMathNode);
  var I,A,B:Integer;
  begin
    A:=MathSourceOffset(Node)-Length(Node.Prefix); B:=A+MathSourceLength(Node);
    if (Position<A) or (Position>B) then Exit;
    if (B=Position) and (A<Position) and ((Node.Kind in [mkCommand,mkTextCommand,mkUnknownCommand,mkDefinition]) or
      ((Node.Kind=mkGroup) and (Copy(Node.Prefix,1,1)='\'))) then
      First:=Min(First,A);
    for I:=0 to Node.Children.Count-1 do Find(TMathNode(Node.Children[I]));
  end;
begin
  Result:=False;
  if FCodeOnly or IsCodeField(CurrentNode) or IsVerbatimField(CurrentNode) then Exit;
  Position:=SourceCaret; First:=Position; Index:=TMathSourceIndex.Create(FRoot);
  try Find(FRoot); finally Index.Free; end;
  Result:=First<Position; if Result then SetSourceSelection(First,Position);
end;
function TMathEditor.DeletePreviousMacro:Boolean;
var I,Position,Start,Finish:Integer; N:TMathNode; SourceIndex:TMathSourceIndex;
begin
  Result:=False; if IsVerbatimField(CurrentNode) then Exit; Position:=SourceCaret;
  SourceIndex:=TMathSourceIndex.Create(FRoot);
  try
  for I:=FFields.Count-1 downto 0 do
  begin
    N:=TMathNode(FFields[I]);
    if (N.Parent<>nil) and (N.Parent.Kind in [mkDefinition,mkUnknownCommand]) then begin
      if N=CurrentNode then Continue;
      N:=N.Parent;
    end else if not (N.Kind in [mkCommand,mkTextCommand]) or (N.Children.Count<>0) then Continue;
    Start:=MathSourceOffset(N)-Length(N.Prefix); Finish:=Start+Length(N.TeX);
    if (Finish>Position) or (Trim(Copy(FSource,Finish+1,Position-Finish))<>'') then Continue;
    if (N=CurrentNode) and (FCaret<>0) then Continue;
    Result:=True; Break;
  end;
  finally SourceIndex.Free; end;
  if not Result then Exit;
  while (Position<Length(FSource)) and (FSource[Position+1] in [' ',#9]) do Inc(Position);
  Commit(Copy(FSource,1,Start)+Copy(FSource,Position+1,MaxInt),Start);
end;
function TMathEditor.DeleteVerbatim(Key:Word):Boolean;
var Node,Verbatim:TMathNode; Position,Start,ContentStart,ContentEnd,Finish,A,B:Integer;
  procedure Find(N:TMathNode);
  var I,L,R:Integer;
  begin
    if (N.Kind=mkGroup) and ((Copy(N.Prefix,1,5)='\verb') or (Copy(N.Prefix,1,10)='\lstinline')) then begin
      L:=MathSourceOffset(N)-Length(N.Prefix); R:=L+Length(N.TeX);
      if ((Position>L) and (Position<R)) or ((Key=VK_BACK) and (Position=R)) or
        ((Key=VK_DELETE) and (Position=L)) then Verbatim:=N;
    end;
    for I:=0 to N.Children.Count-1 do Find(TMathNode(N.Children[I]));
  end;
begin
  Result:=False; Position:=SourceCaret;
  if IsVerbatimField(CurrentNode) then begin
    Start:=Position; if Key=VK_BACK then Dec(Start,2);
    if (Start>=0) and (Copy(FSource,Start+1,2)=#13#10) then begin
      Commit(Copy(FSource,1,Start)+Copy(FSource,Start+3,MaxInt),Start); Exit(True);
    end;
  end;
  Verbatim:=nil; Find(FRoot);
  if Verbatim=nil then Exit;
  Start:=MathSourceOffset(Verbatim)-Length(Verbatim.Prefix);
  Finish:=Start+Length(Verbatim.TeX); ContentStart:=MathSourceOffset(Verbatim);
  ContentEnd:=Finish-Length(Verbatim.Suffix);
  if (ContentStart=ContentEnd) or ((Key=VK_BACK) and (Position<=ContentStart)) or
     ((Key=VK_DELETE) and (Position>=ContentEnd)) then begin
   Commit(Copy(FSource,1,Start)+Copy(FSource,ContentStart+1,ContentEnd-ContentStart)+
      Copy(FSource,Finish+1,MaxInt),Start+EnsureRange(Position-ContentStart,0,ContentEnd-ContentStart));
    Exit(True);
  end;
  Node:=TMathNode(Verbatim.Children[0]); Position:=EnsureRange(Position,ContentStart,ContentEnd);
  A:=UTF8Length(Copy(FSource,ContentStart+1,Position-ContentStart)); B:=A;
  if Key=VK_BACK then Dec(A) else Inc(B);
  A:=ContentStart+Length(UTF8Copy(Node.Text,1,Max(0,A)));
  B:=ContentStart+Length(UTF8Copy(Node.Text,1,B));
  Commit(Copy(FSource,1,A)+Copy(FSource,B+1,MaxInt),A); Result:=True;
end;
function TMathEditor.Formula:string;
begin Result:=FSource; end;
function TMathEditor.CurrentNode:TMathNode;
begin Result:=nil; if (FActive>=0) and (FActive<FFields.Count) then Result:=TMathNode(FFields[FActive]); end;
procedure TMathEditor.Schedule;
begin
  FError:=''; FLinkFirst:=-1; FLinkLast:=-1; InvalidateDraft; Invalidate;
end;
function TMathEditor.GetReady:Boolean;
begin EnsureDraft; Result:=FRoot<>nil; end;
function TMathEditor.GetInputPending:Boolean;
begin Result:=False; end;
function TMathEditor.GetRendering:Boolean;
begin Result:=False; end;
function TMathEditor.GetLayoutPending:Boolean;
begin Result:=FDraftDirty or (FDraft=nil) or (FCachedHeight=0) or (FDraftWidth<>TextLayoutWidth); end;
function TMathEditor.TextLayoutWidth:Integer;
begin
  if FTextAreaWidth>0 then Exit(FTextAreaWidth);
  {$IFDEF LCLgtk3}Result:=Max(1,Width);{$ELSE}Result:=Max(1,ClientWidth);{$ENDIF}
end;
procedure TMathEditor.SetTextAreaWidth(Value:Integer);
begin if Value=FTextAreaWidth then Exit; FTextAreaWidth:=Max(0,Value); InvalidateDraft; end;
function TMathEditor.GetMarginLeft:Integer;
var R:TRect;
begin
  Result:=0;
  { The card is moved left by this gutter, so body text keeps its page position. }
  if FParagraph and (FTextAreaWidth>0) and (not FReadOnly or FPagedEditing) then Result:=32;
  if FDraft=nil then Exit; R:=FDraft.MarginBounds; if R.Left<0 then Result:=Max(Result,2-R.Left);
end;
function TMathEditor.MarginNoteBounds:TRect;
begin
  Result:=Rect(0,0,0,0); if FDraft=nil then Exit;
  Result:=FDraft.MarginBounds; OffsetRect(Result,ImageLeft,ImageTop);
end;
function TMathEditor.GetPreferredWidth:Integer;
var R:TRect;
begin
  Result:=TextLayoutWidth+GetMarginLeft; if FDraft=nil then Exit;
  R:=MarginNoteBounds; if not R.IsEmpty then Result:=Max(Result,R.Right+2);
end;
function TMathEditor.GetPreferredHeight:Integer;
var R:TRect; Toggle:TDraftSourceToggle; Note:TPageCaption;
begin
  if (FCachedHeight=0) or (FDraftWidth<>TextLayoutWidth) then EnsureDraft;
  Result:=Max(28,FCachedHeight);
  if FPagedEditing then Result:=Max(1,FCachedHeight);
  if not FReadOnly and (FPageBody=0) then Inc(Result,12); { Room for the current command's name. }
  R:=SourceDisclosureBounds;
  if R.Width>0 then Result:=Max(Result,R.Bottom+2);
  R:=MarginNoteBounds; if not R.IsEmpty then Result:=Max(Result,R.Bottom+2);
  if FPagedEditing and not FReadOnly then for Note in PageCaptions do
    if Note.Line<0 then Result:=Max(Result,Note.Bounds.Top+Note.Space);
  if FPagedEditing and (FDraft<>nil) then for Toggle in FDraft.SourceToggles do
    if FDraft.SourceControlVisible(Toggle) then Result:=Max(Result,Toggle.Bounds.Bottom+ImageTop+2);
end;
{$I matheditorgenerated.inc}
procedure TMathEditor.SetPreviewZoom(Value:Double);
begin
  Value:=EnsureRange(Value,0.1,8.0);
  if Value=FPreviewZoom then Exit;
  FPreviewZoom:=Value; InvalidateDraft; Invalidate;
end;
function TMathEditor.ImageTop:Integer;
begin if FParagraph then Result:=0 else Result:=34; end;
function TMathEditor.ImageLeft:Integer;
begin if FParagraph then Result:=GetMarginLeft else Result:=8; end;
function TMathEditor.DisplayBounds(Index:Integer):TRect;
begin Result:=FieldBounds(Index); OffsetRect(Result,ImageLeft,ImageTop); end;
function TMathEditor.ActiveRegions:TDraftRegions;
var I,J,First:Integer; N:TMathNode; Regions:TDraftRegions;
begin
  Result:=nil;
  EnsureDraft; Regions:=FDraft.Regions;
  N:=CurrentNode;
  while N<>nil do
  begin
    if FRegistry.Presentation then begin
      First:=-1;
      for I:=0 to High(Regions) do if Regions[I].ID=N.ID then begin
        if First<0 then First:=I;
        if (Regions[I].Slide=FActiveSlide) or (Regions[I].Slide=0) then begin First:=I; Break; end;
      end;
      if First>=0 then FActiveSlide:=Regions[First].Slide;
    end;
    for I:=0 to High(Regions) do
      if (Regions[I].ID=N.ID) and ((Regions[I].Slide=0) or (Regions[I].Slide=FActiveSlide)) then
      begin
        J:=Length(Result); SetLength(Result,J+1); Result[J]:=Regions[I];
        OffsetRect(Result[J].Bounds,ImageLeft,ImageTop);
      end;
    if Length(Result)>0 then Exit;
    N:=N.Parent;
  end;
end;
function TMathEditor.FieldBounds(Index:Integer):TRect;
var N:TMathNode; I:Integer;
begin
  EnsureDraft; Result:=Rect(10,10,30,34);
  if (Index<0) or (Index>=FFields.Count) then Exit;
  N:=TMathNode(FFields[Index]);
  for I:=0 to High(FDraft.Regions) do if (FDraft.Regions[I].ID=N.ID) and
    ((FActiveSlide=0) or (FDraft.Regions[I].Slide=0) or (FDraft.Regions[I].Slide=FActiveSlide)) then begin
    Result:=FDraft.Regions[I].Bounds;
    if (Index<>FActive) or ((FCaret>=FDraft.Regions[I].FirstChar) and
       (FCaret<=FDraft.Regions[I].FirstChar+FDraft.Regions[I].CharCount)) then Exit;
  end;
end;
procedure TMathEditor.WMGetDlgCode(var Message:TLMGetDlgCode);
begin Message.Result:=DLGC_WANTARROWS or DLGC_WANTCHARS or DLGC_WANTTAB; end;
procedure TMathEditor.ClearLinkHover;
begin
  if FGeneratedHover>=0 then begin FGeneratedHover:=-1; Cursor:=crIBeam; Invalidate; end;
  if FLinkFirst<0 then Exit;
  FLinkFirst:=-1; FLinkLast:=-1; Cursor:=crIBeam; Invalidate;
end;
procedure TMathEditor.CMMouseLeave(var Message:TLMessage);
var HadHover:Boolean;
begin
  if csDestroying in ComponentState then begin inherited; Exit; end;
  HadHover:=FPagedEditing and PageHovering;
  FHoverPreview:=nil; FSourceHover:=Point(-1,-1);
  if FDraft<>nil then begin FDraft.SourceHover:=FSourceHover; FDraft.PinnedSourceOffset:=0; end;
  Invalidate;
  FLinkTimer.Enabled:=False; ClearLinkHover; inherited;
  if HadHover and Assigned(FLayout) then FLayout(Self);
end;
procedure TMathEditor.UpdateSourceHover(X,Y:Integer);
var Previous,Node:TMathNode; R,B:TRect; Old,OldDraft,Position:TPoint; OldPin,Pin:Integer;
    RepaintNeeded,WasVisible,ButtonHit:Boolean; Toggle:TDraftSourceToggle;
begin
  { Native mouse notifications can arrive after an offscreen cache was freed,
    or before a newly visible paragraph has received its first paint. }
  if FDraft=nil then begin FSourceHover:=Point(X,Y); FHoverPreview:=nil; Exit; end;
  Previous:=FHoverPreview; R:=Rect(0,0,0,0); B:=R; Old:=FSourceHover; OldDraft:=FDraft.SourceHover;
  if not FReadOnly or FPagedEditing then begin
    Node:=SourcePreviewNode;
    if Node<>nil then begin R:=NodeBounds(Node); InflateRect(R,3,3); B:=SourceDisclosureBounds; end;
  end;
  EnsureDraft;
  Position:=Point(X-ImageLeft,Y-ImageTop); OldPin:=FDraft.PinnedSourceOffset; Pin:=0;
  { Test the already visible controls before looking through them at the next
    line. A button owns hover and clicks until the pointer leaves its bounds. }
  ButtonHit:=False;
  for Toggle in FDraft.SourceToggles do if FDraft.SourceControlVisible(Toggle) and PtInRect(Toggle.Bounds,Position) then begin
    Pin:=Toggle.Offset+1; ButtonHit:=True; Break;
  end;
  if not ButtonHit and PtInRect(B,Point(X,Y)) then begin ButtonHit:=True; Pin:=-1; end;
  FSourceHover:=Point(X,Y); FDraft.SourceHover:=Position; FDraft.PinnedSourceOffset:=Pin;
  if (FReadOnly and not FPagedEditing) or FDragging then Exit;
  if Pin>0 then FHoverPreview:=nil
  else if not ButtonHit then begin
    Node:=FDraft.SourcePreviewAt(FDraft.SourceHover);
    { The orange definition's body already owns a disclosure control. Its
      header still exposes the whole command; a nested formula owns its own
      hover outline. Never paint both controls over the same contents. }
    if (Node<>nil) and (Node.Kind=mkDefinition) then
      for Toggle in FDraft.SourceToggles do
        if (Toggle.Offset=MathSourceOffset(Node)-Length(Node.Prefix)) and not Toggle.Formula and
          PtInRect(Toggle.PreviewBounds,Position) then begin Node:=nil; FHoverPreview:=nil; Break; end;
    if (Node<>nil) or not PtInRect(R,FSourceHover) then FHoverPreview:=Node;
    if FHoverPreview<>nil then begin Pin:=-1; FDraft.PinnedSourceOffset:=Pin; end;
  end;
  RepaintNeeded:=(FHoverPreview<>Previous) or (OldPin<>Pin) or
    ((PtInRect(R,Old) or PtInRect(B,Old))<>(PtInRect(R,FSourceHover) or PtInRect(B,FSourceHover)));
  for Toggle in FDraft.SourceToggles do begin
    WasVisible:=Toggle.Expanded or (OldPin=Toggle.Offset+1) or
      ((OldPin=0) and (PtInRect(Toggle.PreviewBounds,OldDraft) or PtInRect(Toggle.Bounds,OldDraft)));
    RepaintNeeded:=RepaintNeeded or (WasVisible<>FDraft.SourceControlVisible(Toggle));
  end;
  if Assigned(FLayout) and ((FPagedEditing and RepaintNeeded) or
    ((FHoverPreview<>Previous) and (FHoverPreview<>nil) and (PreferredHeight>Height))) then FLayout(Self);
  if RepaintNeeded then Invalidate;
  { The layout callback can evict this offscreen editor's render cache. }
  if FPagedEditing and (FHoverPreview<>nil) and (FRegistry<>nil) and
    FRegistry.Presentation and (Old<>FSourceHover) then Invalidate;
end;
procedure TMathEditor.UpdateLinkHover(CtrlPressed:Boolean);
var Regions:TDraftRegions; Region:TDraftRegion; I,J,K,Offset,First,Last,Distance,Best:Integer; N:TMathNode; Target:string;
begin
  if not CtrlPressed then begin ClearLinkHover; Exit; end;
  if GeneratedTextActive then begin
    FGeneratedHover:=GeneratedLinkAt(FLinkMouse.X,FLinkMouse.Y);
    if FGeneratedHover>=0 then Cursor:=crHandPoint else Cursor:=crIBeam;
    Invalidate; Exit;
  end;
  Regions:=ScreenRegions; Offset:=-1;
  for Region in Regions do begin
    if not PtInRect(Region.Bounds,FLinkMouse) then Continue;
    for I:=0 to FFields.Count-1 do begin
      N:=TMathNode(FFields[I]); if N.ID<>Region.ID then Continue;
      Best:=MaxInt; K:=0;
      for J:=0 to Region.CharCount do if J<Length(Region.Stops) then begin
        Distance:=Abs(FLinkMouse.X-Region.Bounds.Left-Region.Stops[J]);
        if Distance<Best then begin Best:=Distance; K:=J; end;
      end;
      Offset:=MathSourceOffset(N)+Length(UTF8Copy(N.Text,1,Region.FirstChar+K)); Break;
    end;
    if Offset>=0 then Break;
  end;
  if not LinkedTeXInputRange(FSource,Offset,First,Last) and
     not TeXHyperlinkAt(FSource,Offset,Target,First,Last) then begin ClearLinkHover; Exit; end;
  if (First=FLinkFirst) and (Last=FLinkLast) then Exit;
  FLinkFirst:=First; FLinkLast:=Last; Cursor:=crHandPoint; Invalidate;
end;
procedure TMathEditor.LinkTimer(Sender:TObject);
begin
  FLinkMouse:=ScreenToClient(Mouse.CursorPos);
  if not Application.Active or not IsVisible or not PtInRect(ClientRect,FLinkMouse) then begin
    FLinkTimer.Enabled:=False; ClearLinkHover; Exit;
  end;
  UpdateLinkHover(ssCtrl in GetKeyShiftState);
end;
procedure TMathEditor.KeyUp(var Key:Word; Shift:TShiftState);
begin if Key=VK_CONTROL then ClearLinkHover; inherited KeyUp(Key,Shift); end;
function TMathEditor.LinkUnderlineRects:TSelectionRects;
var R:TRect; Bounds:TVectorImageBounds;
begin
  Result:=nil;
  if GeneratedTextActive and (FGeneratedHover>=0) and (FGeneratedHover<Length(FGeneratedPreview.Links)) then begin
    R:=GeneratedBounds; Bounds:=FGeneratedPreview.Links[FGeneratedHover].Bounds; SetLength(Result,1);
    Result[0]:=Rect(R.Left+Round(Bounds.Left*R.Width),R.Top+Round(Bounds.Top*R.Height),
      R.Left+Round(Bounds.Right*R.Width),R.Top+Round(Bounds.Bottom*R.Height)); Exit;
  end;
  if FLinkFirst<0 then Exit;
  Result:=MathSelectionRects(FRoot,FFields,ScreenRegions,FLinkFirst,FLinkLast);
end;
function TMathEditor.ScreenRegions:TDraftRegions;
var I:Integer;
begin
  EnsureDraft; Result:=Copy(FDraft.Regions);
  for I:=0 to High(Result) do
    OffsetRect(Result[I].Bounds,ImageLeft,ImageTop);
end;
procedure TMathEditor.NormalizeSelection(var A,B:Integer);
begin
  if (FInlineSourceA>=0) and (A>=FInlineSourceA) and (B<=FInlineSourceB) then Exit;
  if not FCodeOnly or (FDefinitionsInCode and EditingDefinition) then NormalizeMathSelection(FRoot,A,B);
end;
function TMathEditor.SelectionRange(out A,B:Integer):Boolean;
var Ranges:TSourceRanges;
begin
  A:=SourceCaret; if FSelectionFocus>=0 then A:=FSelectionFocus; B:=A;
  Result:=(FSelectionAnchor>=0) and (FSelectionAnchor<>A);
  if Result then begin
    B:=Max(A,FSelectionAnchor); A:=Min(A,FSelectionAnchor);
    if SelectingTableCells then begin Ranges:=SelectedSourceRanges; A:=Ranges[0].Start; B:=Ranges[High(Ranges)].Finish; end
    else NormalizeSelection(A,B);
  end;
end;
function TMathEditor.SelectionTouchesMath(A,B:Integer):Boolean;
var I,L,R:Integer; N:TMathNode;
begin
  Result:=False;
  for I:=0 to FFields.Count-1 do
  begin
    N:=TMathNode(FFields[I]); L:=MathSourceOffset(N); R:=L+Length(N.Text);
    if IsMathField(N) and (A<=R) and (B>=L) then Exit(True);
  end;
end;
function TMathEditor.SelectedRects:TSelectionRects;
var A,B,I,J:Integer; Regions:TDraftRegions;
begin
  if GeneratedTextActive then Exit(GeneratedRects);
  Result:=nil; if not SelectionRange(A,B) then Exit;
  Regions:=ScreenRegions; J:=0;
  for I:=0 to High(Regions) do if (FActiveSlide=0) or (Regions[I].Slide=0) or (Regions[I].Slide=FActiveSlide) then begin
    Regions[J]:=Regions[I]; Inc(J);
  end;
  SetLength(Regions,J); Result:=MathSelectionRects(FRoot,FFields,Regions,A,B);
end;
procedure TMathEditor.PaintSelection;
begin DrawSelectionOutline(Canvas,SelectedRects); end;
procedure TMathEditor.SetSourceSelection(Anchor,Focus:Integer);
var Notify:TNotifyEvent;
begin
  Anchor:=EnsureRange(Anchor,0,Length(FSource)); Focus:=EnsureRange(Focus,0,Length(FSource));
  if not FSelected and (FSelectionAnchor=Anchor) and (FSelectionFocus=Focus) and (SourceCaret=Focus) then Exit;
  Notify:=FSelectionChange; FSelectionChange:=nil;
  try if SourceCaret<>Focus then SetSourceCaret(Focus);
  finally FSelectionChange:=Notify; end;
  FSelectionAnchor:=Anchor; FSelectionFocus:=Focus; FSelected:=False; Invalidate;
  NotifySelection;
end;
procedure TMathEditor.ClearSourceSelection;
begin
  if not FSelected and (FSelectionAnchor<0) and (FSelectionFocus<0) then Exit;
  FSelectionAnchor:=-1; FSelectionFocus:=-1; FSelected:=False;
  Invalidate; NotifySelection;
end;
function TMathEditor.HitOffset(X,Y:Integer):Integer;
begin
  ClickPreview(X-ImageLeft,Y-ImageTop,ClientWidth,ClientHeight);
  Result:=SourceCaret;
end;
function TMathEditor.CaretPoint:TPoint;
var R:TDraftRegions; J,Stop:Integer; Bounds:TRect; Optional:TMathNode;
begin
  if GeneratedTextActive then begin Bounds:=GeneratedCaretBounds; Exit(Point(Bounds.Left,(Bounds.Top+Bounds.Bottom) div 2)); end;
  Optional:=MissingOptionalArgument(CurrentNode);
  if (Optional<>nil) and (SourceCaret=FOptionalResumeOffset) then begin
    Bounds:=NodeBounds(Optional);
    Exit(Point(Bounds.Left+Round(Bounds.Width*FOptionalResumeCaret/Max(1,Length(Optional.Text))),
      (Bounds.Top+Bounds.Bottom) div 2));
  end;
  R:=ActiveRegions; Result:=Point(10,10); J:=CaretRegion(R);
  if J<0 then Exit;
  Stop:=EnsureRange(FCaret-R[J].FirstChar,0,R[J].CharCount);
  Result:=Point(R[J].Bounds.Left,(R[J].Bounds.Top+R[J].Bounds.Bottom) div 2);
  if Stop<Length(R[J].Stops) then Inc(Result.X,R[J].Stops[Stop])
  else Inc(Result.X,Round((R[J].Bounds.Right-R[J].Bounds.Left)*Stop/Max(1,R[J].CharCount)));
end;
function TMathEditor.CaretRegion(const Regions:TDraftRegions):Integer;
var I:Integer; AtParagraphEnd,Units:Boolean;
begin
  Result:=-1;
  Units:=NativeUnitField;
  AtParagraphEnd:=FParagraph and not IsCodeField(CurrentNode) and (SourceCaret=Length(TrimRight(FSource)));
  for I:=0 to High(Regions) do
    if (FCaret>=Regions[I].FirstChar) and (FCaret<=Regions[I].FirstChar+Regions[I].CharCount) then begin
      { At the final visible stop, prefer the text's ink rectangle over the
        following zero-width separator's font rectangle. }
      if AtParagraphEnd and (Result>=0) and (Regions[I].FirstChar=FCaret) and
        (FCaret>Regions[Result].FirstChar) then Continue;
      if Units and (Result>=0) and (Regions[I].FirstChar=FCaret) and
        (FCaret>Regions[Result].FirstChar) then Continue;
      Result:=I;
    end;
  if (Result<0) and (Length(Regions)>0) then Result:=High(Regions);
end;
procedure TMathEditor.BeginSelectionAt(X,Y:Integer; Shift:TShiftState);
begin MouseDown(mbLeft,Shift,X,Y); end;
procedure TMathEditor.BeginSelectionAtSource(Offset:Integer; Shift:TShiftState);
var Anchor:Integer; P:TPoint;
begin
  Anchor:=FSelectionAnchor; if Anchor<0 then Anchor:=SourceCaret;
  FDragging:=True; FMouseMoved:=False; FVerticalRun:=False; FLinkClick:=False;
  SetSourceCaret(Offset); P:=CaretPoint; FMouseDownPoint:=P;
  if ssShift in Shift then FSelectionAnchor:=Anchor else FSelectionAnchor:=SourceCaret;
  MouseCapture:=True;
  if Assigned(FDocumentGesture) then FDocumentGesture(Self,ClientToScreen(P),0,Shift);
end;
procedure TMathEditor.CancelSelectionDrag;
begin
  FDragging:=False;
  if MouseCapture then MouseCapture:=False;
end;
function TMathEditor.NodeBounds(Node:TMathNode):TRect;
var Last:TMathNode; Region:TDraftRegion; Have:Boolean; R:TRect;
begin
  Result:=Rect(0,0,0,0); if Node=nil then Exit;
  EnsureDraft; Have:=False; Last:=Node;
  { ParseSource numbers the tree in preorder. A subtree is one contiguous
    ID range, so painting need not scan every region once per descendant. }
  while Last.Children.Count>0 do Last:=TMathNode(Last.Children[Last.Children.Count-1]);
  for Region in FDraft.Regions do if (Region.ID>=Node.ID) and (Region.ID<=Last.ID) and
    ((FActiveSlide=0) or (Region.Slide=0) or (Region.Slide=FActiveSlide)) then begin
    R:=Region.Bounds;
    if not Have then begin Result:=R; Have:=True; end
    else Result:=Rect(Min(Result.Left,R.Left),Min(Result.Top,R.Top),
      Max(Result.Right,R.Right),Max(Result.Bottom,R.Bottom));
  end;
  if Have then OffsetRect(Result,ImageLeft,ImageTop);
end;
function TMathEditor.EditingFormulaBounds:TRect;
var FormulaNode:TMathNode;
begin
  Result:=Rect(0,0,0,0); if not InMath then Exit;
  FormulaNode:=CurrentNode;
  while (FormulaNode<>nil) and (FormulaNode.Kind<>mkFormula) do FormulaNode:=FormulaNode.Parent;
  if FormulaNode=nil then FormulaNode:=FRoot;
  Result:=NodeBounds(FormulaNode);
end;
function TMathEditor.CommandContextNode(out CommandName:string):TMathNode;
var N:TMathNode; P:Integer; Source,Command:string;
begin
  CommandName:=''; Result:=nil; N:=CurrentNode;
  while N<>nil do begin
    Source:='';
    if N.Kind in [mkCommand,mkTextCommand,mkRaw] then Source:=N.Text
    else if N.Kind in [mkGroup,mkFormula,mkEnvironment] then Source:=TrimLeft(N.Prefix)
    else if N.Kind in [mkDefinition,mkUnknownCommand] then Source:=N.TeX;
    P:=1; Command:=ReadTeXCommand(Source,P);
    if Command<>'' then begin
      CommandName:='\'+Command;
      if Command='begin' then CommandName:=CommandName+'{'+ReadTeXGroup(Source,P,'{','}')+'}'
      else if (Command='left') or (Command='right') or (Command='lvert') or (Command='lVert') or (Command='langle') or
        ((Pos('big',Command)=1) and (N.Suffix<>'')) then
        CommandName:=Trim(N.Prefix)+' … '+Trim(N.Suffix);
      Exit(N);
    end;
    if (N.Kind=mkFormula) and (Source<>'') then begin CommandName:=Source+'…'+N.Suffix; Exit(N); end;
    N:=N.Parent;
  end;
end;
function TMathEditor.CommandContext(out CommandName:string; out Bounds:TRect):Boolean;
begin
  Bounds:=NodeBounds(CommandContextNode(CommandName));
  Result:=(CommandName<>'') and not Bounds.IsEmpty;
end;
procedure TMathEditor.PaintCommandContext;
var LabelText:string; Bounds:TRect;
begin
  if FPagedEditing then begin PaintPageCaptions; Exit; end;
  if not CommandContext(LabelText,Bounds) then Exit;
  { The layout already displays the environment name below its contents. }
  if Copy(LabelText,1,7)='\begin{' then Exit;
  Canvas.Font.Name:=FSourceFontName; if Canvas.Font.Name='' then Canvas.Font.Name:='monospace';
  Canvas.Font.Size:=9; Canvas.Font.Style:=[];
  Canvas.Font.Color:=clGray; Canvas.Brush.Style:=bsClear;
  Canvas.Brush.Color:=PaperColor;
  if Assigned(FBackgroundPaint) then Canvas.Brush.Style:=bsClear else Canvas.Brush.Style:=bsSolid;
  Canvas.TextOut(EnsureRange(Bounds.Left,0,Max(0,ClientWidth-Canvas.TextWidth(LabelText))),
    Bounds.Bottom+3,LabelText);
  Canvas.Brush.Style:=bsSolid;
end;
{$I matheditorpage.inc}
procedure TMathEditor.PaintSourceFrame;
var R,B:TRect; Boxes:TSelectionRects; Hovered:Boolean;
begin
  Boxes:=SourceFrameRects; if Length(Boxes)=0 then Exit;
  B:=SourceDisclosureBounds;
  Hovered:=PtInRect(B,FSourceHover);
  for R in Boxes do Hovered:=Hovered or PtInRect(R,FSourceHover);
  if not Hovered then Exit;
  DrawSelectionOutline(Canvas,Boxes,clGray,1,psDash);
  if B.Width>0 then DrawSourceDisclosure(Canvas,B,False);
end;
procedure TMathEditor.ConfigureTextStyle(const Style:TTeXTextStyle; TextColor:TColor);
begin
  if FTextStyleOverride=nil then FTextStyleOverride:=TEditorTextStyle.Create;
  FTextStyleOverride.Style:=Style; FTextStyleOverride.Color:=TextColor; InvalidateDraft; Invalidate;
end;
procedure TMathEditor.SetPreserveColors(Value:Boolean);
begin
  if FPreserveColors=Value then Exit; FPreserveColors:=Value;
  if FDraft<>nil then FDraft.PreserveColors:=Value; Invalidate;
end;
procedure TMathEditor.Paint;
var R:TRect; N:TMathNode; X,Chosen,Position,A,B:Integer; Regions:TDraftRegions; P:TPoint; Ink:TColor; CodeField:Boolean;
begin
  Ink:=InkColor; if FPreserveColors then Ink:=clBlack;
  Canvas.Brush.Style:=bsSolid;
  if Assigned(FBackgroundPaint) then FBackgroundPaint(Self)
  else begin Canvas.Brush.Color:=PaperColor; Canvas.FillRect(ClientRect); end;
  if FReadOnly and FDeferLayout and LayoutPending then begin
    if (FDraft<>nil) and (FDraft.RootBox<>nil) then FDraft.Paint(Canvas,nil,nil,ImageLeft,ImageTop);
    Canvas.Brush.Style:=bsClear; Canvas.Pen.Color:=clGray; Canvas.Pen.Width:=1;
    if FPreviewFrame=1 then Canvas.Pen.Color:=$16A9CF else if FPreviewFrame=2 then Canvas.Pen.Color:=$3535DC;
    Canvas.Rectangle(1,1,Width-1,Height-1); Exit;
  end;
  EnsureDraft; FDraft.SourceHover:=Point(FSourceHover.X-ImageLeft,FSourceHover.Y-ImageTop);
  FDraft.Paint(Canvas,nil,nil,ImageLeft,ImageTop,False);
  Canvas.Pen.Color:=Ink; Canvas.Pen.Width:=1; Canvas.Pen.Style:=psSolid;
  for R in LinkUnderlineRects do begin Canvas.MoveTo(R.Left,R.Bottom-1); Canvas.LineTo(R.Right,R.Bottom-1); end;
  if FPreviewFrame<>0 then begin
    Canvas.Brush.Style:=bsClear; Canvas.Pen.Width:=2;
    if FPreviewFrame=1 then Canvas.Pen.Color:=$16A9CF else Canvas.Pen.Color:=$3535DC;
    Canvas.Rectangle(1,1,Width-1,Height-1); Canvas.Pen.Width:=1; Canvas.Brush.Style:=bsSolid;
  end;
  try
  if FReadOnly then begin
    PaintSelection;
    Exit;
  end;
  PaintSelection;
  if GeneratedTextActive then begin
    R:=GeneratedCaretBounds; Canvas.Pen.Color:=Ink; Canvas.Pen.Width:=2;
    Canvas.MoveTo(R.Left,R.Top-1); Canvas.LineTo(R.Left,R.Bottom+1); Exit;
  end;
  PaintCommandContext;
  N:=CurrentNode; if N=nil then Exit;
  CodeField:=(N.Parent<>nil) and (N.Parent.Kind in [mkUnknownCommand,mkComment]);
  if CodeField then Ink:=SourceForegroundColor;
  Regions:=ActiveRegions; Chosen:=CaretRegion(Regions);
  Canvas.Brush.Style:=bsClear; Canvas.Pen.Color:=$BE6A21; Canvas.Pen.Width:=1;
  if (Chosen>=0) and not InMath and not SelectionRange(A,B) then
  begin R:=Regions[Chosen].Bounds; InflateRect(R,2,2); Canvas.Rectangle(R); end;
  if Chosen>=0 then
  begin
    R:=Regions[Chosen].Bounds;
    Position:=EnsureRange(FCaret-Regions[Chosen].FirstChar,0,Regions[Chosen].CharCount);
    if N.Kind in [mkCommand,mkTextCommand] then
      if FCaret=0 then Position:=0 else Position:=Regions[Chosen].CharCount;
    if Position<Length(Regions[Chosen].Stops) then X:=R.Left+Regions[Chosen].Stops[Position]
    else X:=R.Left+Round((R.Right-R.Left)*Position/Max(1,Regions[Chosen].CharCount));
    if (SourceCaret=FOptionalResumeOffset) and (MissingOptionalArgument(N)<>nil) then X:=CaretPoint.X;
    Canvas.Pen.Color:=Ink; Canvas.Pen.Style:=psSolid; Canvas.Pen.Width:=2;
    if (Position=0) or (Position=Regions[Chosen].CharCount) then Canvas.Pen.Width:=3;
    Canvas.MoveTo(X,R.Top-1); Canvas.LineTo(X,R.Bottom+1);
  end;
  if Chosen<0 then
  begin
    Canvas.Pen.Color:=Ink; Canvas.Pen.Width:=2;
    Canvas.MoveTo(10,10); Canvas.LineTo(10,30);
  end;
  if FIMEPreedit<>'' then begin
    P:=CaretPoint; Canvas.Font.Name:=Font.Name; Canvas.Font.Size:=Font.Size;
    Canvas.Font.Color:=Ink; Canvas.Brush.Style:=bsSolid; Canvas.Brush.Color:=PaperColor;
    if CodeField then begin
      Canvas.Brush.Color:=SourceBackgroundColor;
      if FSourceFontName<>'' then Canvas.Font.Name:=FSourceFontName;
      if FSourceFontPixels>0 then Canvas.Font.Height:=-FSourceFontPixels;
    end;
    Canvas.TextOut(P.X,P.Y-Canvas.TextHeight(FIMEPreedit) div 2,FIMEPreedit);
    Canvas.Pen.Width:=1; Canvas.MoveTo(P.X,P.Y+12); Canvas.LineTo(P.X+Canvas.TextWidth(FIMEPreedit),P.Y+12);
  end;
  Canvas.Pen.Width:=1; Canvas.Brush.Style:=bsSolid;
  finally
    { Source controls stay above selection, caret and subsequent line content. }
    if not FReadOnly or FPagedEditing then begin
      FDraft.PaintSourceControls(Canvas,ImageLeft,ImageTop); PaintSourceFrame;
    end;
  end;
end;
procedure TMathEditor.SelectField(Index:Integer);
begin

  if FFields.Count=0 then Exit;
  FSelectionAnchor:=-1; FSelectionFocus:=-1;
  FActive:=EnsureRange(Index,0,FFields.Count-1); FSelected:=True; FCaret:=0;
  NotifySelection;
  Invalidate;
end;
procedure TMathEditor.NextField(Delta:Integer);
begin
  if FFields.Count=0 then Exit;
  SelectField((FActive+Delta+FFields.Count) mod FFields.Count);
end;
procedure TMathEditor.SnapProseCaret(Delta:Integer);
var N:TMathNode; Count,I,A,B,Newlines:Integer; Ch:string;
begin
  if UnitTokenAt(FCaret,A,B) then begin
    if Delta<0 then FCaret:=A else FCaret:=B;
  end;
  N:=CurrentNode; if (N=nil) or (N.Kind<>mkProse) then Exit;
  if IsVerbatimField(N) then begin
    if (UTF8Copy(N.Text,FCaret,1)=#13) and (UTF8Copy(N.Text,FCaret+1,1)=#10) then Inc(FCaret,Delta);
    Exit;
  end;
  if IsCodeField(N) then Exit;
  Count:=UTF8Length(N.Text);
  { Collapsed interword spaces share one stop; a paragraph separator is a
    different boundary. Never move a freshly typed space across blank lines. }
  A:=FCaret; B:=FCaret; Newlines:=0;
  while (A>0) and (UTF8Copy(N.Text,A,1)[1] in [' ',#9,#10,#13]) do Dec(A);
  while (B<Count) and (UTF8Copy(N.Text,B+1,1)[1] in [' ',#9,#10,#13]) do Inc(B);
  for I:=A+1 to B do begin Ch:=UTF8Copy(N.Text,I,1); if Ch=#10 then Inc(Newlines); end;
  if Newlines>=2 then Exit;
  while (FCaret>0) and (FCaret<Count) and
    (UTF8Copy(N.Text,FCaret,1)[1] in [' ',#9,#10,#13]) and
    (UTF8Copy(N.Text,FCaret+1,1)[1] in [' ',#9,#10,#13]) do
      Inc(FCaret,Delta);
end;
function TMathEditor.NativeUnitField:Boolean;
var N:TMathNode; Info:TMacroInfo;
begin
  Result:=False; N:=CurrentNode;
  while (N<>nil) and (N.Kind<>mkCommand) do N:=N.Parent;
  if (N=nil) or not N.NativePackage then Exit;
  LoadRegistry;
  Info:=FRegistry.Find(Copy(N.Text,2,MaxInt));
  Result:=(Info<>nil) and (Info.PreviewAdapter='units');
end;
function TMathEditor.UnitTokenAt(Offset:Integer; out First,Last:Integer):Boolean;
var P,A:Integer; S:string;
begin
  Result:=False; if not NativeUnitField then Exit;
  S:=CurrentNode.Text; P:=1;
  while P<=Length(S) do begin
    if S[P]<>'\' then begin Inc(P); Continue; end;
    A:=P; ReadTeXCommand(S,P); First:=UTF8Length(Copy(S,1,A-1)); Last:=UTF8Length(Copy(S,1,P-1));
    if (Offset>First) and (Offset<Last) then Exit(True);
  end;
end;
function TMathEditor.MoveGridRow(Delta:Integer):Boolean;
type TCell=record Start,Finish,Row,Col:Integer; end;
var Env,Body,N:TMathNode; Cells:array of TCell; R,C,Start,I,K,Current,Target,Position,Desired:Integer;
  procedure AddCell(Finish:Integer);
  begin K:=Length(Cells); SetLength(Cells,K+1); Cells[K].Start:=Start; Cells[K].Finish:=Finish; Cells[K].Row:=R; Cells[K].Col:=C; end;
begin
  Result:=False; Env:=CurrentMathGrid;
  if (Env=nil) or (Env.Children.Count=0) then Exit;
  Body:=TMathNode(Env.Children.Last); R:=0; C:=0; Start:=MathSourceOffset(Body); Cells:=nil;
  for I:=0 to Body.Children.Count-1 do begin
    N:=TMathNode(Body.Children[I]);
    if (N.Kind=mkRaw) and ((N.Text='&') or (Copy(N.Text,1,2)='\\')) then begin
      AddCell(MathSourceOffset(N)); Start:=MathSourceOffset(N)+Length(N.TeX);
      if N.Text='&' then Inc(C) else begin Inc(R); C:=0; end;
    end;
  end;
  AddCell(MathSourceOffset(Body)+Length(Body.TeX)); Position:=SourceCaret; Current:=0;
  for I:=0 to High(Cells) do if (Position>=Cells[I].Start) and (Position<=Cells[I].Finish) then Current:=I;
  Target:=-1;
  for I:=0 to High(Cells) do if (Cells[I].Row=Cells[Current].Row+Delta) and (Cells[I].Col<=Cells[Current].Col) then Target:=I;
  Result:=True; if Target<0 then begin Result:=False; Exit; end;
  Desired:=Cells[Target].Start+Min(Position-Cells[Current].Start,Cells[Target].Finish-Cells[Target].Start);
  SetSourceCaret(Desired);
  for I:=0 to FFields.Count-1 do begin
    N:=TMathNode(FFields[I]); K:=MathSourceOffset(N);
    if (K>=Cells[Target].Start) and (K<=Cells[Target].Finish) then begin
      FActive:=I; FCaret:=UTF8Length(Copy(N.Text,1,EnsureRange(Desired-K,0,Length(N.Text))));
      if K+Length(N.Text)>=Desired then Break;
    end;
  end;
  FSelected:=False; Invalidate;
end;
function TMathEditor.EditList(Key:Word):Boolean;
var Item,Env,Body,N:TMathNode; A,B,P,I,Index,EnvStart,EnvEnd,ContentStart:Integer; Content,Replacement:string;
  function ItemBodyStart(Node:TMathNode):Integer;
  begin
    Result:=MathSourceOffset(Node);
    if Node.Children.Count>0 then Result:=MathSourceOffset(TMathNode(Node.Children.Last));
  end;
begin
  Result:=False; Item:=CurrentNode;
  while (Item<>nil) and not ((Item.Kind=mkGroup) and (Pos('\item',Item.Prefix)=1)) do begin
    if Item.Kind=mkOptional then Exit;
    Item:=Item.Parent;
  end;
  if Item=nil then Exit;
  Env:=Item.Parent; while (Env<>nil) and (Env.Kind<>mkEnvironment) do Env:=Env.Parent;
  if Env=nil then Exit;
  A:=MathSourceOffset(Item)-Length(Item.Prefix); B:=A+Length(Item.TeX); P:=SourceCaret;
  ContentStart:=ItemBodyStart(Item); Content:=Copy(FSource,ContentStart+1,B-ContentStart);
  if Key=VK_RETURN then begin
    Body:=Item.Parent; Index:=Body.Children.IndexOf(Item);
    if Trim(Copy(FSource,ContentStart+1,P-ContentStart))='' then
      for I:=Index-1 downto 0 do begin
        N:=TMathNode(Body.Children[I]);
        if Pos('\item',N.Prefix)<>1 then Continue;
        if Trim(Copy(N.TeX,Length(N.Prefix)+1,MaxInt))='' then begin Result:=True; Exit; end;
        Break;
      end;
    if Trim(Copy(FSource,P+1,B-P))='' then
      for I:=Index+1 to Body.Children.Count-1 do begin
        N:=TMathNode(Body.Children[I]);
        if Pos('\item',N.Prefix)<>1 then Continue;
        if Trim(Copy(N.TeX,Length(N.Prefix)+1,MaxInt))='' then begin
          SetSourceCaret(ItemBodyStart(N)); Result:=True; Exit;
        end;
        Break;
      end;
    if Trim(Content)<>'' then begin
      Replacement:=LineEnding+'\item '; Commit(Copy(FSource,1,P)+Replacement+Copy(FSource,P+1,MaxInt),P+Length(Replacement)); Result:=True; Exit;
    end;
    { Repeated Enter keeps one editable empty item. }
    Result:=True; Exit;
  end else if Key=VK_BACK then begin if Trim(Copy(FSource,ContentStart+1,P-ContentStart))<>'' then Exit; end
  else if (Key=VK_DELETE) and (Trim(Content)<>'') then Exit;
  Body:=Item.Parent; Index:=Body.Children.IndexOf(Item);
  for I:=Index-1 downto 0 do begin
    N:=TMathNode(Body.Children[I]);
    if Pos('\item',N.Prefix)=1 then begin
    Commit(Copy(FSource,1,A)+Content+Copy(FSource,B+1,MaxInt),A); Result:=True; Exit;
    end;
  end;
  EnvStart:=MathSourceOffset(Env)-Length(Env.Prefix); EnvEnd:=EnvStart+Length(Env.TeX);
  Replacement:=Copy(FSource,1,EnvStart)+Content;
  for I:=Index+1 to Body.Children.Count-1 do if Pos('\item',TMathNode(Body.Children[I]).Prefix)=1 then begin
    Replacement:=Replacement+Env.Prefix+Copy(FSource,B+1,EnvEnd-B);
   Commit(Replacement+Copy(FSource,EnvEnd+1,MaxInt),EnvStart); Result:=True; Exit;
  end;
  Commit(Replacement+Copy(FSource,EnvEnd+1,MaxInt),EnvStart); Result:=True;
end;
function TMathEditor.BreakEnvironmentLine(Soft:Boolean):Boolean;
var N:TMathNode; A,B:Integer; Value:string;
begin
  Result:=False; if InMath then Exit;
  N:=CurrentNode;
  while N<>nil do begin
    if N.Kind=mkOptional then Exit;
    if N.Kind=mkEnvironment then Break;
    N:=N.Parent;
  end;
  if N=nil then Exit; LoadRegistry;
  if not ((N.Text='proof') or FRegistry.IsTheorem(N.Text)) then Exit;
  { Both Enter variants use a paragraph break; no forced line command. }
  begin
    if not SelectionRange(A,B) then begin A:=SourceCaret; B:=A; end;
    while (A>0) and (FSource[A] in [' ',#9,#10,#13]) do Dec(A);
    while (B<Length(FSource)) and (FSource[B+1] in [' ',#9,#10,#13]) do Inc(B);
    Value:=LineEnding+LineEnding;
   Commit(Copy(FSource,1,A)+Value+Copy(FSource,B+1,MaxInt),A+Length(Value));
  end;
  Result:=True;
end;
function TMathEditor.FractionNeighbor(Delta:Integer):TMathNode;
var N,P:TMathNode; I,First:Integer; Fraction:Boolean;
begin
  Result:=nil; N:=CurrentNode;
  if IsCodeField(N) then Exit;
  while (N<>nil) and (N.Parent<>nil) do begin
    P:=N.Parent;
    Fraction:=(P.Kind in [mkFraction,mkBinomial]) or ((P.Kind=mkCommand) and
      ((P.Text='\frac') or (P.Text='\dfrac') or (P.Text='\tfrac') or (P.Text='\cfrac') or
       (P.Text='\binom') or (P.Text='\dbinom') or (P.Text='\tbinom') or (P.Text='\genfrac')));
    if Fraction and (P.Children.Count>=2) then begin
      First:=P.Children.Count-2; I:=P.Children.IndexOf(N);
      if (I>=First) and (I+Delta>=First) and (I+Delta<P.Children.Count) then
        Exit(TMathNode(P.Children[I+Delta]));
    end;
    N:=P;
  end;
end;
function TMathEditor.MoveVertical(Delta:Integer; Excluded:TMathNode):Boolean;
var Regions:TDraftRegions; Current:TPoint; I,J,RowY,BestY,BestX,DX,CY,Offset,CurrentOffset,TableStart,TableEnd,Slide:Integer;
    N,Field,Target,Ancestor,LastTable,Within:TMathNode;
    RegionFields:array of TMathNode; FieldIndex:TMathFieldIndex;
begin
  Result:=False; Within:=nil;
  if Excluded=nil then begin
    Within:=FractionNeighbor(Delta);
    if (Within=nil) and MoveGridRow(Delta) then begin NotifySelection; Exit(True); end;
  end;
  EnsureDraft; Current:=CaretPoint;
  if not FVerticalRun then FVerticalX:=Current.X;
  FVerticalRun:=True; Regions:=ScreenRegions; BestY:=MaxInt; RowY:=0;
  SetLength(RegionFields,Length(Regions)); CurrentOffset:=SourceCaret; LastTable:=nil;
  { Choose the nearest visual row first, then the stop nearest the desired x.
    Region geometry also handles fractions and scripts without fixed line heights. }
  FieldIndex:=TMathFieldIndex.Create;
  try
  FieldIndex.Build(FFields);
  for I:=0 to High(Regions) do begin
    Field:=FieldIndex.Find(Regions[I].ID);
    if (Field<>nil) and (Excluded<>nil) then begin
      N:=Field; while (N<>nil) and (N<>Excluded) do N:=N.Parent;
      if N<>nil then Field:=nil;
    end;
    if (Field<>nil) and (Within<>nil) then begin
      N:=Field; while (N<>nil) and (N<>Within) do N:=N.Parent;
      if N=nil then Field:=nil;
    end;
    if Field<>nil then begin
      Ancestor:=Field;
      while (Ancestor<>nil) and (Ancestor.Kind<>mkTable) do Ancestor:=Ancestor.Parent;
      if Ancestor<>nil then begin
        if Ancestor<>LastTable then begin
          LastTable:=Ancestor; TableStart:=MathSourceOffset(Ancestor)-Length(Ancestor.Prefix);
          TableEnd:=TableStart+Length(Ancestor.TeX);
        end;
        if ((Delta>0) and (CurrentOffset>=TableEnd)) or
           ((Delta<0) and (CurrentOffset<=TableStart)) then Field:=nil;
      end;
    end;
    RegionFields[I]:=Field;
    if Field=nil then Continue;
    CY:=(Regions[I].Bounds.Top+Regions[I].Bounds.Bottom) div 2;
    if ((CY-Current.Y)*Delta<=Max(3,(Regions[I].Bounds.Bottom-Regions[I].Bounds.Top) div 3)) then Continue;
    if Abs(CY-Current.Y)<BestY then begin BestY:=Abs(CY-Current.Y); RowY:=CY; end;
  end;
  finally FieldIndex.Free; end;
  if BestY=MaxInt then Exit;
  BestX:=MaxInt; Target:=nil; Offset:=0; Slide:=FActiveSlide;
  for I:=0 to High(Regions) do begin
    CY:=(Regions[I].Bounds.Top+Regions[I].Bounds.Bottom) div 2;
    if Abs(CY-RowY)>3 then Continue;
    N:=RegionFields[I]; if N=nil then Continue;
    for J:=0 to Regions[I].CharCount do begin
      if (N.Kind in [mkCommand,mkTextCommand]) and (J<>0) and (J<>Regions[I].CharCount) then Continue;
      if J<Length(Regions[I].Stops) then DX:=Regions[I].Stops[J]
      else DX:=Round((Regions[I].Bounds.Right-Regions[I].Bounds.Left)*J/Max(1,Regions[I].CharCount));
      DX:=Abs(Regions[I].Bounds.Left+DX-FVerticalX);
      if DX<BestX then begin BestX:=DX; Target:=N; Offset:=Regions[I].FirstChar+J; Slide:=Regions[I].Slide; end;
    end;
  end;
  if Target=nil then Exit;
  FActive:=FFields.IndexOf(Target); FActiveSlide:=Slide; FCaret:=EnsureRange(Offset,0,UTF8Length(CurrentNode.Text));
  FSelected:=False; SnapProseCaret(Delta); Invalidate; Result:=True;
  NotifySelection;
end;
procedure TMathEditor.MoveLineEdge(AtEnd:Boolean);
var Regions:TDraftRegions; N:TMathNode; I,J,K,Row,Offset,Edge,Caret:Integer; Found:Boolean;
begin
  if InMath or not FParagraph then begin
    if AtEnd then FCaret:=UTF8Length(CurrentNode.Text) else FCaret:=0;
    FSelected:=False; Exit;
  end;
  EnsureDraft; Regions:=ActiveRegions; Row:=0; Found:=False;
  for I:=0 to High(Regions) do
    if (FCaret>=Regions[I].FirstChar) and (FCaret<=Regions[I].FirstChar+Regions[I].CharCount) then begin
      Row:=Regions[I].Bounds.Top+Regions[I].Baseline; Found:=True;
    end;
  if not Found then Exit;
  Regions:=FDraft.Regions; Edge:=MaxInt; if AtEnd then Edge:=-1;
  for I:=0 to High(Regions) do begin
    if Abs(Regions[I].Bounds.Top+Regions[I].Baseline-Row)>2 then Continue;
    for J:=0 to FFields.Count-1 do begin
      N:=TMathNode(FFields[J]); if (N.ID<>Regions[I].ID) or IsCodeField(N) then Continue;
      K:=Regions[I].FirstChar; if AtEnd then Inc(K,Regions[I].CharCount);
      Offset:=MathSourceOffset(N)+Length(UTF8Copy(N.Text,1,K));
      if AtEnd then Edge:=Max(Edge,Offset) else Edge:=Min(Edge,Offset);
    end;
  end;
  if (Edge<0) or (Edge=MaxInt) then Exit;
  { The end of the final visual row also passes closing style delimiters. }
  if AtEnd then begin
    Found:=False;
    for I:=0 to High(Regions) do
      if Regions[I].Bounds.Top+Regions[I].Baseline>Row+2 then Found:=True;
    if not Found then Edge:=Length(TrimRight(FSource));
  end;
  Caret:=FSelectionAnchor; SetSourceCaret(Edge); FSelectionAnchor:=Caret; FSelected:=False; FVerticalRun:=False;
end;
procedure TMathEditor.MoveHorizontal(Delta:Integer);
var N,OldParent:TMathNode; Offset,Count:Integer;
begin
  N:=CurrentNode; if N=nil then Exit;
  Count:=UTF8Length(N.Text);
  if FSelected then
  begin if Delta<0 then FCaret:=0 else FCaret:=Count; FSelected:=False; Exit; end;
  Offset:=SourceCaret; OldParent:=N.Parent;
  if Delta>0 then
  begin
    while (FCaret>=Count) and (FActive<FFields.Count-1) do
    begin
      Inc(FActive); N:=CurrentNode; FCaret:=0; Count:=UTF8Length(N.Text);
      if (SourceCaret<>Offset) or (N.Parent<>OldParent) then Break;
    end;
    if (SourceCaret=Offset) and (N.Parent=OldParent) then
      if N.Kind in [mkCommand,mkTextCommand] then FCaret:=Count else FCaret:=Min(Count,FCaret+1);
  end
  else
  begin
    while (FCaret=0) and (FActive>0) do
    begin
      Dec(FActive); N:=CurrentNode; Count:=UTF8Length(N.Text); FCaret:=Count;
      if (SourceCaret<>Offset) or (N.Parent<>OldParent) then Break;
    end;
    if (SourceCaret=Offset) and (N.Parent=OldParent) then
      if N.Kind in [mkCommand,mkTextCommand] then FCaret:=0 else FCaret:=Max(0,FCaret-1);
  end;
  N:=CurrentNode;
  while (N.Kind=mkText) and (N.Text='') and (ScriptBoundaryEnd(FRoot,SourceCaret)<>SourceCaret) and
    (FActive+Delta>=0) and (FActive+Delta<FFields.Count) do begin
    Inc(FActive,Delta); N:=CurrentNode; if Delta<0 then FCaret:=UTF8Length(N.Text) else FCaret:=0;
  end;
  SnapProseCaret(Delta);
  FSelected:=False;
  NotifySelection;
end;
procedure TMathEditor.HitField(X,Y:Integer);
var I,K,Best,BestRegion,Distance,BestDistance,Area,BestArea,Offset,Anchor:Integer;
    R:TRect; N,Ancestor:TMathNode; Regions:TDraftRegions; InsideField:Boolean;
begin
  EnsureDraft; Regions:=FDraft.Regions;
  FVerticalRun:=False;
  { A click after the final insertion stop belongs to the paragraph end,
    even when italic ink overhangs that stop or a closing style has no ink. }
  if FParagraph and (FFields.Count>0) then begin
    N:=TMathNode(FFields.Last);
    if (N.Kind=mkProse) and (MathSourceOffset(N)+Length(N.Text)=Length(FSource)) then
      for I:=High(Regions) downto 0 do if Regions[I].ID=N.ID then begin
        R:=Regions[I].Bounds; K:=Regions[I].CharCount;
        Offset:=R.Right; if K<Length(Regions[I].Stops) then Offset:=R.Left+Regions[I].Stops[K];
        InsideField:=False;
        if (X>=Offset) and (Y>=R.Top-2) and (Y<=R.Bottom+2) then
          for K:=0 to High(Regions) do if (X>=Regions[K].Bounds.Left-2) and (X<=Regions[K].Bounds.Right+2) and
            (Y>=Regions[K].Bounds.Top) and (Y<=Regions[K].Bounds.Bottom) then
            for Best:=0 to FFields.Count-2 do if (TMathNode(FFields[Best]).ID=Regions[K].ID) and
              (TMathNode(FFields[Best]).Kind in [mkText,mkProse]) and (TMathNode(FFields[Best]).Text<>'') then InsideField:=True;
        if (X>=Offset) and (Y>=R.Top-2) and (Y<=R.Bottom+2) and not InsideField then begin
          Anchor:=FSelectionAnchor; SetSourceCaret(Length(TrimRight(FSource))); FSelectionAnchor:=Anchor; Invalidate; Exit;
        end;
        Break;
      end;
  end;
  if MathDelimiterOffset(FRoot,Regions,X,Y,Offset) then begin
    Anchor:=FSelectionAnchor; SetSourceCaret(Offset); FSelectionAnchor:=Anchor;
    NotifySelection;
    Exit;
  end;
  FSelectionFocus:=-1; Best:=-1; BestRegion:=-1; BestDistance:=MaxInt; BestArea:=MaxInt;
  for I:=0 to FFields.Count-1 do
  begin
    Ancestor:=TMathNode(FFields[I]);
    while Ancestor<>nil do
    begin
      for K:=0 to High(Regions) do
        if Regions[K].ID=Ancestor.ID then
        begin
          R:=Regions[K].Bounds;
          if Length(Regions[K].Stops)>0 then R.Right:=Max(R.Right,R.Left+Regions[K].Stops[High(Regions[K].Stops)]);
          Distance:=Max(Max(R.Left-X,0),X-R.Right)+4*Max(Max(R.Top-Y,0),Y-R.Bottom);
          Area:=(R.Right-R.Left)*(R.Bottom-R.Top);
          if (Distance<BestDistance) or ((Distance=BestDistance) and
            (((Best>=0) and (TMathNode(FFields[Best]).Text='') and (Ancestor.Text<>'')) or
             ((Area<BestArea) and ((Best<0) or (TMathNode(FFields[Best]).Text='') or (Ancestor.Text<>''))))) then
          begin Best:=I; BestRegion:=K; BestDistance:=Distance; BestArea:=Area; end;
        end;
      Ancestor:=nil;
    end;
  end;
  if Best<0 then Exit;
  FActive:=Best; FActiveSlide:=Regions[BestRegion].Slide; FSelected:=True; FCaret:=0; N:=CurrentNode; R:=Regions[BestRegion].Bounds;
  if N.Kind in [mkProse,mkText] then
  begin
    FSelected:=False;
    Offset:=Round((X-R.Left)*Regions[BestRegion].CharCount/Max(1,R.Right-R.Left));
    if Length(Regions[BestRegion].Stops)>0 then
    begin
      Offset:=0; BestDistance:=MaxInt;
      for K:=0 to High(Regions[BestRegion].Stops) do
        if Abs(X-R.Left-Regions[BestRegion].Stops[K])<BestDistance then
        begin Offset:=K; BestDistance:=Abs(X-R.Left-Regions[BestRegion].Stops[K]); end;
    end;
    FCaret:=EnsureRange(Regions[BestRegion].FirstChar+Offset,0,UTF8Length(N.Text));
  end;
  SnapProseCaret(1);
  if N.Kind in [mkCommand,mkTextCommand] then begin FSelected:=False; FCaret:=UTF8Length(N.Text);
    if (N.Kind=mkTextCommand) and (X<(R.Left+R.Right) div 2) then FCaret:=0;
  end;
  Offset:=ScriptBoundaryEnd(FRoot,SourceCaret,True);
  if Offset<>SourceCaret then begin
    Anchor:=FSelectionAnchor; SetSourceCaret(Offset); FSelectionAnchor:=Anchor;
  end;
  NotifySelection;
  Invalidate;
end;
function TMathEditor.GeneratedAt(X,Y:Integer; out Command:string; out Target:Integer):Boolean;
var Region:TDraftRegion; Link:TDraftLink; N:TMathNode; I,P:Integer;
begin
  EnsureDraft; Result:=False; Target:=-1; Command:=''; Dec(X,ImageLeft); Dec(Y,ImageTop);
  for Region in FDraft.Regions do if PtInRect(Region.Bounds,Point(X,Y)) then
    for I:=0 to FFields.Count-1 do begin
      N:=TMathNode(FFields[I]); if N.ID<>Region.ID then Continue;
      P:=1; Command:=ReadTeXCommand(N.Text,P);
      if IsGeneratedCommand(Command) and not IsCodeField(N) then begin
        for Link in FDraft.Links do if ((Link.ID=N.ID) or (Link.ID<0)) and PtInRect(Link.Bounds,Point(X,Y)) then Target:=Link.Offset;
        Exit(True);
      end;
    end;
end;
procedure TMathEditor.MouseDown(Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
var Anchor,I:Integer; C:TWinControl; Inside:Boolean; Selected:TSelectionRects;
    Scrolls:array of record Control:TScrollBox; X,Y:Integer; end; GeneratedCommand:string; Target:Integer; FormulaToggle:Boolean;
  procedure SaveScroll;
  begin
    Scrolls:=nil; C:=Parent;
    while C<>nil do begin
      if C is TScrollBox then begin
        I:=Length(Scrolls); SetLength(Scrolls,I+1); Scrolls[I].Control:=TScrollBox(C);
        Scrolls[I].X:=TScrollBox(C).HorzScrollBar.Position;
        Scrolls[I].Y:=TScrollBox(C).VertScrollBar.Position;
      end;
      C:=C.Parent;
    end;
  end;
  procedure RestoreScroll;
  var J:Integer;
  begin
    for J:=0 to High(Scrolls) do SetPreviewScroll(Scrolls[J].Control,Scrolls[J].X,Scrolls[J].Y);
  end;
begin
  SetMathShortcut('');
  SaveScroll;
  UpdateSourceHover(X,Y);
  if not FReadOnly and (Button=mbLeft) and SourceToggleAt(X,Y,Target,FormulaToggle) then begin
    try ToggleSourceAt(Target,FormulaToggle); FLinkClick:=True; if CanFocus then SetFocus;
    finally RestoreScroll; end;
    Exit;
  end;
  if GeneratedMouseDown(Button,Shift,X,Y) then Exit;
  if (Button=mbLeft) and GeneratedAt(X,Y,GeneratedCommand,Target) and Assigned(FGeneratedAction) and
     (ssCtrl in Shift) then begin
    FGeneratedAction(Self,GeneratedCommand,Target,Target<0); FLinkClick:=True; Exit;
  end;
  if FReadOnly then begin inherited MouseDown(Button,Shift,X,Y); Exit; end;
  inherited MouseDown(Button,Shift,X,Y);
  if Button=mbRight then begin
    Inside:=False; Selected:=SelectedRects;
    for I:=0 to High(Selected) do Inside:=Inside or PtInRect(Selected[I],Point(X,Y));
    if not Inside then begin
      FSelectionAnchor:=-1; FSelectionFocus:=-1;
      ClickPreview(X-ImageLeft,Y-ImageTop,ClientWidth,ClientHeight);
    end;
    Exit;
  end;
  if Button<>mbLeft then Exit;
  FLinkClick:=False;
  if (ssCtrl in Shift) and Assigned(FSourceLink) then begin
    ClickPreview(X-ImageLeft,Y-ImageTop,ClientWidth,ClientHeight);
    FSourceLink(Self,SourceCaret,FLinkClick);
    if FLinkClick then Exit;
  end;
  Cursor:=crIBeam;
  FMouseDownPoint:=Point(X,Y); FMouseMoved:=False; FVerticalRun:=False;
  FDragging:=True;
  Anchor:=SourceCaret;
  if CanFocus then SetFocus;
  ClickPreview(X-ImageLeft,Y-ImageTop,ClientWidth,ClientHeight);
  if not (ssShift in Shift) then FSelectionAnchor:=SourceCaret
  else if FSelectionAnchor<0 then FSelectionAnchor:=Anchor;
  FDragging:=True; MouseCapture:=True;
  if Assigned(FDocumentGesture) then FDocumentGesture(Self,ClientToScreen(Point(X,Y)),0,Shift);
  RestoreScroll;
end;
procedure TMathEditor.MouseMove(Shift:TShiftState; X,Y:Integer);
var Space,FormulaToggle:Boolean; Target:Integer;
begin
  inherited MouseMove(Shift,X,Y);
  UpdateSourceHover(X,Y);
  FLinkMouse:=Point(X,Y); FLinkTimer.Enabled:=not FDragging; UpdateLinkHover((ssCtrl in Shift) and not FDragging);
  if GeneratedTextActive then begin
    if FDragging and (ssLeft in Shift) then begin FGeneratedFocus:=GeneratedHit(X,Y); FMouseMoved:=True; Invalidate; end;
    if not FDragging and SourceToggleAt(X,Y,Target,FormulaToggle) then Cursor:=crHandPoint;
    Exit;
  end;
  if FReadOnly and not FPagedEditing then Exit;
  if not FDragging then begin
    if (FLinkFirst>=0) or SourceToggleAt(X,Y,Target,FormulaToggle) or (ClickableFieldAt(X,Y,Space)>=0) or
      (RuleAt(X,Y)<>nil) then Cursor:=crHandPoint else Cursor:=crIBeam;
    Exit;
  end;
  if FReadOnly then Exit;
  if (Abs(X-FMouseDownPoint.X)>3) or (Abs(Y-FMouseDownPoint.Y)>3) then FMouseMoved:=True;
  if not MouseCapture or not (ssLeft in Shift) then begin
    CancelSelectionDrag;
    { A missed release must also unblock the document's layout and caches. }
    if Assigned(FDocumentGesture) then FDocumentGesture(Self,ClientToScreen(Point(X,Y)),2,Shift);
    Exit;
  end;
  if Assigned(FDocumentGesture) then
  begin FDocumentGesture(Self,ClientToScreen(Point(X,Y)),1,Shift); Exit; end;
  ClickPreview(X-ImageLeft,Y-ImageTop,ClientWidth,ClientHeight);
  FSelected:=False; Invalidate;
end;
procedure TMathEditor.MouseUp(Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
var A,B:Integer;
begin
  inherited MouseUp(Button,Shift,X,Y);
  if FReadOnly then Exit;
  if FLinkClick then begin FLinkClick:=False; Exit; end;
  if GeneratedTextActive then begin FDragging:=False; MouseCapture:=False; Exit; end;
  if Button=mbLeft then
  begin
    FDragging:=False; MouseCapture:=False;
    if Assigned(FDocumentGesture) then FDocumentGesture(Self,ClientToScreen(Point(X,Y)),2,Shift);
    NotifySelection;
    if not FMouseMoved and not (ssShift in Shift) and not SelectionRange(A,B) then begin
      if ActivateOptionalArgument then Exit;
      if Assigned(FFigureEdit) and (CurrentNode<>nil) and
        ((Pos('\includegraphics',CurrentNode.Text)=1) or (Pos('\includepdf',CurrentNode.Text)=1)) then FFigureEdit(Self)
      else if not EditSpaceAt(X,Y) and not EditInputAt(X,Y) then EditReferenceAt(X,Y);
    end;
  end;
end;
function TMathEditor.DoMouseWheel(Shift:TShiftState; WheelDelta:Integer; MousePos:TPoint):Boolean;
var C:TWinControl; S:TScrollBox;
begin
  FVerticalRun:=False;
  C:=Parent;
  while C<>nil do begin
    if C is TScrollBox then begin
      S:=TScrollBox(C);
      if S.VertScrollBar.Range>S.ClientHeight then begin
        SetPreviewScroll(S,S.HorzScrollBar.Position,S.VertScrollBar.Position-Round(WheelDelta/120*72));
        Exit(True);
      end;
    end;
    C:=C.Parent;
  end;
  Result:=inherited DoMouseWheel(Shift,WheelDelta,MousePos);
end;
procedure TMathEditor.DblClick;
begin inherited DblClick; SelectWord; end;
procedure TMathEditor.SelectWord;
var N,P:TMathNode; Cmd:string; K:Integer;
    A,B,Count,Start:Integer;
  function WordChar(Index:Integer):Boolean;
  var Ch:UnicodeString;
  begin
    Ch:=UTF8Decode(UTF8Copy(N.Text,Index,1));
    Result:=(Ch<>'') and ((Ch='_') or TCharacter.IsLetterOrDigit(Ch,1));
  end;
begin
  if GeneratedTextActive then begin
    FGeneratedAnchor:=FGeneratedFocus;
    while (FGeneratedAnchor>0) and (UTF8Copy(FGeneratedPreview.RenderedText,FGeneratedAnchor,1)<>' ') and
      (UTF8Copy(FGeneratedPreview.RenderedText,FGeneratedAnchor,1)<>#10) do Dec(FGeneratedAnchor);
    while (FGeneratedFocus<UTF8Length(FGeneratedPreview.RenderedText)) and
      (UTF8Copy(FGeneratedPreview.RenderedText,FGeneratedFocus+1,1)<>' ') and
      (UTF8Copy(FGeneratedPreview.RenderedText,FGeneratedFocus+1,1)<>#10) do Inc(FGeneratedFocus);
    Invalidate; Exit;
  end;
  if FReadOnly then Exit;
  N:=CurrentNode;
  P:=N; while P<>nil do begin
    K:=1; Cmd:=ReadTeXCommand(P.Text,K);
    if (Cmd='label') or (Cmd='tag') then begin EditAnnotation; Exit; end;
    if IsLabelReference(Cmd) then begin
      CancelSelectionDrag; SetSourceSelection(MathSourceOffset(P),MathSourceOffset(P)+Length(P.TeX));
      if Assigned(FDocumentGesture) then FDocumentGesture(Self,Point(0,0),4,[]);
      Exit;
    end;
    P:=P.Parent;
  end;
  if (N=nil) or InMath or not (N.Kind in [mkProse,mkText]) then Exit;
  Count:=UTF8Length(N.Text); if Count=0 then Exit;
  K:=Min(FCaret+1,Count);
  if not WordChar(K) and (K>1) and WordChar(K-1) then Dec(K);
  A:=K; B:=K;
  if WordChar(K) then begin
    while (A>1) and WordChar(A-1) do Dec(A);
    while (B<Count) and WordChar(B+1) do Inc(B);
  end;
  Start:=MathSourceOffset(N);
  CancelSelectionDrag;
  SetSourceSelection(Start+Length(UTF8Copy(N.Text,1,A-1)),Start+Length(UTF8Copy(N.Text,1,B)));
  if Assigned(FDocumentGesture) then FDocumentGesture(Self,Point(0,0),4,[]);
end;
procedure TMathEditor.DoEnter;
begin inherited DoEnter; Invalidate; end;
procedure TMathEditor.DoExit;
begin
  SetMathShortcut('');
  if not CommandActive then QueueFocusCompletion;
  inherited DoExit; Invalidate;
end;
procedure TMathEditor.QueueFocusCompletion;
begin
  CancelSelectionDrag;
  if FFocusCompletionQueued or (csDestroying in ComponentState) then Exit;
  FFocusCompletionQueued:=True;
  Application.QueueAsyncCall(@CompleteFocusEdit,0);
end;
procedure TMathEditor.CompleteFocusEdit(Data:PtrInt);
begin
  FFocusCompletionQueued:=False;
  { Source changes can resize or reparent the active editor. Do them after
    the widget set has finished its native focus transition. }
  if CommandActive and FCommandEdit.Focused then Exit;
  FinishCommand(False); FinishDefinitionEdit;
  FinishVisualSource;
end;
function TMathEditor.FinishVisualSource(Offset:Integer):Integer;
var Edits:TSourceFormatEdits; Code:string; A,B:Integer;
begin
  Result:=Offset;
  if not FVisualSourceDirty or FFormattingSource or FReadOnly or FCodeOnly or
    IsCodeField(CurrentNode) or IsVerbatimField(CurrentNode) then Exit;
  FVisualSourceDirty:=False;
  Code:=FormatTeXFragment(FSource,FRegistry,Edits); if Code=FSource then Exit;
  GetSourceSelection(A,B); A:=FormattedOffset(A,Edits); B:=FormattedOffset(B,Edits);
  Result:=FormattedOffset(Offset,Edits);
  FSourcePreviewStart:=FormattedOffset(FSourcePreviewStart,Edits);
  FDefinitionSourceStart:=FormattedOffset(FDefinitionSourceStart,Edits);
  FDefinitionStart:=FormattedOffset(FDefinitionStart,Edits);
  FDiagramSourceStart:=FormattedOffset(FDiagramSourceStart,Edits);
  FCollapsedDiagramStart:=FormattedOffset(FCollapsedDiagramStart,Edits);
  FFormattingSource:=True;
  try Commit(Code,B); SetSourceSelection(A,B); finally FFormattingSource:=False; FVisualSourceDirty:=False; end;
end;
procedure TMathEditor.NotifyChange;
begin if Assigned(FChange) then FChange(Self); end;
function NodeOffset(N:TMathNode):Integer;
begin Result:=MathSourceOffset(N); end;
function TMathEditor.SourceCaret:Integer;
var N:TMathNode;
begin
  N:=CurrentNode; if N=nil then Exit(0);
  Result:=NodeOffset(N)+Length(UTF8Copy(N.Text,1,FCaret));
end;
procedure TMathEditor.SetSourceCaret(Offset:Integer);
begin FVerticalRun:=False; Commit(FSource,EnsureRange(Offset,0,Length(FSource))); NotifySelection; end;
procedure TMathEditor.ReplaceSource(const Value:string; Caret:Integer);
begin Commit(Value,Caret); end;
{$I matheditorobjects.inc}
function TMathEditor.SplitParagraph(out Before,After:string):Boolean;
var N:TMathNode; Offset:Integer;
begin
  Result:=FParagraph and not InMath;
  if not Result then Exit;
  Offset:=SourceCaret;
  Before:=Copy(FSource,1,Offset); After:=Copy(FSource,Offset+1,MaxInt);
  N:=CurrentNode;
  while N<>nil do
  begin
    { Close and reopen formatting groups at a paragraph break. }
    if (N.Kind=mkGroup) and (N.Suffix='}') then
    begin Before:=Before+N.Suffix; After:=N.Prefix+After; end;
    N:=N.Parent;
  end;
end;
procedure TMathEditor.SelectFormula(Index:Integer);
var I,J,Found:Integer; N,Last,Field:TMathNode;
begin
  Found:=-1; Last:=nil;
  for I:=0 to FFields.Count-1 do
  begin
    N:=TMathNode(FFields[I]);
    while (N<>nil) and (N.Kind<>mkFormula) do N:=N.Parent;
    if (N=nil) or (N=Last) then Continue;
    Last:=N; Inc(Found);
    if Found=Index then
    begin
      for J:=I to FFields.Count-1 do
      begin
        Field:=TMathNode(FFields[J]);
        if (NodeOffset(Field)>NodeOffset(N)+Length(N.TeX)) then Break;
        if (Field.Kind in [mkText,mkCommand]) and (Trim(Field.Text)<>'') then
        begin SelectField(J); Exit; end;
      end;
      SelectField(I); Exit;
    end;
  end;
end;
procedure TMathEditor.SetTheoremEnvironment(const Environment:string);
var N:TMathNode; A,B,Offset:Integer; Body,Prefix,Suffix:string; Names:TStringList;
begin
  Names:=TStringList.Create;
  try
    TheoremNames(Names); Names.Add('proof');
    if Names.IndexOf(Environment)<0 then Exit;
    N:=CurrentNode;
    while (N<>nil) and not ((N.Kind=mkEnvironment) and (Names.IndexOf(N.Text)>=0)) do N:=N.Parent;
    Prefix:='\begin{'+Environment+'}'; Suffix:='\end{'+Environment+'}';
    if SelectionRange(A,B) then begin WrapSelection(Prefix,Suffix); Exit; end;
    A:=0; B:=Length(FSource); Body:=FSource; Offset:=SourceCaret;
    if N<>nil then begin
      A:=MathSourceOffset(N)-Length(N.Prefix); B:=A+Length(N.TeX);
      Prefix:=Prefix+Copy(N.Prefix,Length('\begin{'+N.Text+'}')+1,MaxInt);
      Body:=Copy(N.TeX,Length(N.Prefix)+1,Length(N.TeX)-Length(N.Prefix)-Length(N.Suffix));
      Offset:=EnsureRange(SourceCaret-A-Length(N.Prefix),0,Length(Body));
    end;

   Commit(Copy(FSource,1,A)+Prefix+Body+Suffix+Copy(FSource,B+1,MaxInt),A+Length(Prefix)+Offset);
  finally Names.Free; end;
end;
procedure TMathEditor.SetParagraphAlignment(const Environment:string);
var N:TMathNode; A,B,Offset:Integer; Body,Prefix,Suffix:string;
begin
  N:=CurrentNode;
  while (N<>nil) and not ((N.Kind=mkEnvironment) and
    ((N.Text='center') or (N.Text='flushleft') or (N.Text='flushright'))) do N:=N.Parent;
  A:=0; B:=Length(FSource); Body:=FSource; Offset:=SourceCaret;
  if N<>nil then begin
    A:=MathSourceOffset(N)-Length(N.Prefix); B:=A+Length(N.TeX);
    Body:=Copy(FSource,A+Length(N.Prefix)+1,Length(N.TeX)-Length(N.Prefix)-Length(N.Suffix));
    Offset:=EnsureRange(SourceCaret-A-Length(N.Prefix),0,Length(Body));
  end;
  Prefix:=''; Suffix:='';
  if Environment<>'' then begin Prefix:='\begin{'+Environment+'}'; Suffix:='\end{'+Environment+'}'; end;

  Commit(Copy(FSource,1,A)+Prefix+Body+Suffix+Copy(FSource,B+1,MaxInt),A+Length(Prefix)+Offset);
end;
procedure TMathEditor.SetFormulaKind(const Kind:string; InsertNew:Boolean);
var N,BodyNode,Child,OnlyChild:TMathNode; A,B,Offset,I,Count:Integer;
    Body,Prefix,Suffix,GridKind:string; Single,HasGrid:Boolean;
begin
  N:=CurrentNode; while (N<>nil) and (N.Kind<>mkFormula) do N:=N.Parent;
  Body:=' '; Single:=(Kind='inline') or (Kind='display') or (Pos('equation',Kind)=1);
  if (N<>nil) and not InsertNew then
  begin
    A:=MathSourceOffset(N)-Length(N.Prefix); B:=A+Length(N.TeX);
    BodyNode:=TMathNode(N.Children[0]); GridKind:=N.Prefix;
    Count:=0; OnlyChild:=nil;
    for I:=0 to BodyNode.Children.Count-1 do
    begin Child:=TMathNode(BodyNode.Children[I]); if Trim(Child.TeX)<>'' then begin Inc(Count); OnlyChild:=Child; end; end;
    if (Count=1) and (OnlyChild.Kind=mkEnvironment) and
       ((OnlyChild.Text='aligned') or (OnlyChild.Text='gathered')) then
    begin GridKind:=OnlyChild.Text; BodyNode:=TMathNode(OnlyChild.Children[0]); end;
    Body:=''; HasGrid:=False;
    for I:=0 to BodyNode.Children.Count-1 do
    begin
      Child:=TMathNode(BodyNode.Children[I]);
      if (Child.Kind=mkRaw) and ((Child.Text='&') or (Copy(Child.Text,1,2)='\\')) then HasGrid:=True;
      if Single and ((Child.Text='\tag') or (Child.Text='\tag*') or (Child.Text='\notag') or (Child.Text='\nonumber')) then Continue;
      if (Pos('gather',Kind)=1) and (Child.Kind=mkRaw) and (Child.Text='&') then Body:=Body+' '
      else Body:=Body+Child.TeX;
    end;
    if Single and HasGrid then
      if Pos('gather',GridKind)>0 then Body:='\begin{gathered}'+Body+'\end{gathered}'
      else Body:='\begin{aligned}'+Body+'\end{aligned}';
    if Body='' then Body:=' ';
  end
  else
  begin
    if N<>nil then A:=MathSourceOffset(N)-Length(N.Prefix)+Length(N.TeX) else A:=SourceCaret;
    B:=A;
    if (N=nil) and SelectionRange(A,B) then Body:=Copy(FSource,A+1,B-A);
  end;
  if Kind='inline' then begin Prefix:='$'; Suffix:='$'; end
  else if Kind='display' then begin Prefix:='\['; Suffix:='\]'; end
  else begin Prefix:='\begin{'+Kind+'}'; Suffix:='\end{'+Kind+'}'; end;
  if (N<>nil) and InsertNew and (Kind='inline') then Prefix:=' '+Prefix;
  Offset:=A+Length(Prefix);
  Commit(Copy(FSource,1,A)+Prefix+Body+Suffix+Copy(FSource,B+1,MaxInt),Offset);
  SetSourceCaret(Offset);
end;
function TMathEditor.CurrentMathGrid:TMathNode;
var EnvName:string;
begin
  Result:=CurrentNode;
  while Result<>nil do begin
    EnvName:=MathEnvironmentName(Result);
    if (Result.Kind in [mkEnvironment,mkFormula]) and (Result.Children.Count=1) and
       (TMathNode(Result.Children[0]).Kind=mkRow) and
       ((Pos('matrix',EnvName)>0) or (Pos('align',EnvName)>0) or (Pos('gather',EnvName)>0) or
        (Pos('multline',EnvName)>0) or (Pos('cases',EnvName)>0) or (Pos('array',EnvName)>0) or (EnvName='split')) then Exit;
    Result:=Result.Parent;
  end;
end;
function TMathEditor.CanEditGrid(Operation:Integer):Boolean;
var Env:TMathNode; EnvName:string;
begin
  Result:=False; if not (Operation in [0..7]) then Exit;
  Env:=CurrentMathGrid; if Env=nil then Exit;
  EnvName:=MathEnvironmentName(Env);
  Result:=not (Operation in [3..5,7]) or
    ((Pos('gather',EnvName)=0) and (Pos('multline',EnvName)=0) and (Pos('cases',EnvName)=0) and
     (Pos('alignat',EnvName)=0) and (Pos('array',EnvName)=0) and (EnvName<>'split'));
end;
function TMathEditor.EditGrid(Operation:Integer):Boolean;
var Env,Body,N:TMathNode; Rows:TObjectList; Cells,RowBreaks:TStringList;
    I,J,R,C,TargetRow,TargetCol,Start,Finish,Position,Offset,Columns:Integer;
    S:string;
  procedure InsertRow;
  begin
    Rows.Insert(TargetRow,Cells);
    RowBreaks.Insert(Min(TargetRow,RowBreaks.Count),'\\'+LineEnding);
  end;
begin
  Result:=False; if not CanEditGrid(Operation) then Exit;
  Env:=CurrentMathGrid; Body:=TMathNode(Env.Children[0]);
  Rows:=TObjectList.Create(True); RowBreaks:=TStringList.Create;
  try
    Cells:=TStringList.Create; Cells.Add(''); Rows.Add(Cells);
    R:=0; C:=0; TargetRow:=0; TargetCol:=0; Position:=SourceCaret;
    for I:=0 to Body.Children.Count-1 do begin
      N:=TMathNode(Body.Children[I]);
      if (N.Kind=mkRaw) and ((N.Text='&') or (Copy(N.Text,1,2)='\\')) then begin
        if N.Text='&' then begin Inc(C); Cells.Add(''); end
        else begin RowBreaks.Add(N.Text); Inc(R); C:=0; Cells:=TStringList.Create; Cells.Add(''); Rows.Add(Cells); end;
        if Position>=MathSourceOffset(N)+Length(N.TeX) then begin TargetRow:=R; TargetCol:=C; end;
      end else Cells[C]:=Cells[C]+N.TeX;
    end;
    Cells:=TStringList(Rows[TargetRow]); Columns:=Cells.Count;
    case Operation of
      0,1:begin
        if Operation=1 then Inc(TargetRow);
        Cells:=TStringList.Create;
        for I:=1 to Columns do Cells.Add(' ');
        InsertRow; TargetCol:=0;
      end;
      2:begin
        if Rows.Count=1 then begin Cells.Clear; Cells.Add(' '); end
        else begin RowBreaks.Delete(Min(TargetRow,RowBreaks.Count-1)); Rows.Delete(TargetRow); end;
        TargetRow:=Min(TargetRow,Rows.Count-1); TargetCol:=0;
      end;
      6:begin
        Cells:=TStringList.Create; Cells.Assign(TStringList(Rows[TargetRow])); Inc(TargetRow); InsertRow;
      end;
      3,4,5,7:begin
        if Operation=4 then Inc(TargetCol);
        for I:=0 to Rows.Count-1 do begin
          Cells:=TStringList(Rows[I]);
          if Operation=5 then begin
            if TargetCol<Cells.Count then
              if Cells.Count>1 then Cells.Delete(TargetCol) else Cells[0]:=' ';
          end else if Operation=7 then begin
            while Cells.Count<=TargetCol do Cells.Add(' ');
            Cells.Insert(TargetCol+1,Cells[TargetCol]);
          end else begin
            while Cells.Count<TargetCol do Cells.Add(' ');
            Cells.Insert(TargetCol,' ');
          end;
        end;
        if Operation=7 then Inc(TargetCol);
        TargetCol:=Min(TargetCol,TStringList(Rows[TargetRow]).Count-1);
      end;
    end;
    S:=''; Offset:=0;
    for I:=0 to Rows.Count-1 do begin
      if I>0 then S:=S+RowBreaks[I-1];
      Cells:=TStringList(Rows[I]);
      for J:=0 to Cells.Count-1 do begin
        if J>0 then S:=S+'&';
        if (I=TargetRow) and (J=TargetCol) then Offset:=Length(S);
        S:=S+Cells[J];
      end;
    end;
    Start:=MathSourceOffset(Body); Finish:=Start+Length(Body.TeX);
    Commit(Copy(FSource,1,Start)+S+Copy(FSource,Finish+1,MaxInt),Start+Offset);
    SetSourceCaret(Start+Offset); Result:=True;
  finally RowBreaks.Free; Rows.Free; end;
end;
procedure TMathEditor.InsertEquation(const Value:string);
var Offset,I:Integer; N:TMathNode;
begin
  if not FParagraph or InMath then begin ReplaceSelection(Value); Exit; end;
  N:=CurrentNode; if N=nil then Exit;
  Offset:=NodeOffset(N);
  if not FSelected then Inc(Offset,Length(UTF8Copy(N.Text,1,FCaret)));
  if Value='' then ReplaceSelection('$ $') else ReplaceSelection('$'+Value+'$');
  for I:=0 to FFields.Count-1 do
    if IsMathField(TMathNode(FFields[I])) and (NodeOffset(TMathNode(FFields[I]))>=Offset+1) then
    begin SelectField(I); Break; end;
end;
function TMathEditor.SelectionTextState:TTeXTextSelection;
var A,B:Integer; Ranges:TSourceRanges; Base:TTeXTextStyle;
begin
  if not SelectionRange(A,B) then begin A:=SourceCaret; B:=A; end;
  if (FStyleSource=FSource) and (FStyleContext=FPreamble+FEngine+FDirectory) and
     (FStyleAnchor=A) and (FStyleFocus=B) then Exit(FSelectionStyle);
  EnsureDraft; Base:=InitialTextStyle(FPreamble,FDirectory,FEngine,FRegistry);
  Ranges:=nil; if SelectingTableCells then Ranges:=SelectedSourceRanges;
  Result:=QueryTextSelectionStyle(FFields,CurrentNode,A,B,Base,FDraft.Styles,FDraft.Context,FDirectory,Ranges);
  FStyleSource:=FSource; FStyleContext:=FPreamble+FEngine+FDirectory; FStyleAnchor:=A; FStyleFocus:=B;
  FSelectionStyle:=Result;
end;
function TMathEditor.SelectionTextStyle(out Style:TTeXTextStyle):Boolean;
var Selection:TTeXTextSelection;
begin Selection:=SelectionTextState; Style:=Selection.Style; Result:=Selection.Valid; end;
function TMathEditor.TextStyleActive(const Command:string):Boolean;
begin Result:=TextSelectionStyleActive(SelectionTextState,Command); end;
procedure TMathEditor.SetTextFamily(const Command:string);
var N:TMathNode; A,B,NewA,NewB:Integer; S,Middle:string;
begin
  if not ((Command='\textrm') or (Command='\textsf') or (Command='\texttt')) then Exit;
  if FormatTableSelection('@family',Command) then Exit;
  N:=CurrentNode; if (N=nil) or InMath or IsCodeField(N) then Exit;
  if not SelectionRange(A,B) then begin A:=MathSourceOffset(N); B:=A+Length(TrimRight(N.Text)); end;
  if A=B then Exit;
  Middle:=ProseFragment(FRoot,FSource,A,B,'@family');
  S:=ProseFragment(FRoot,FSource,0,A)+Command+'{'; NewA:=Length(S);
  S:=S+Middle; NewB:=Length(S); S:=S+'}'+ProseFragment(FRoot,FSource,B,Length(FSource));
  CompactProseFormatting(S,NewA,NewB); Commit(S,NewB); SetSourceSelection(NewA,NewB);
  NotifySelection;
end;
procedure TMathEditor.SetTextSize(const Prefix:string);
var N:TMathNode; A,B,NewA,NewB:Integer; S:string;
begin
  if FormatTableSelection('@size',Prefix) then Exit;
  N:=CurrentNode; if (N=nil) or InMath or IsCodeField(N) then Exit;
  if not SelectionRange(A,B) then begin A:=MathSourceOffset(N); B:=A+Length(TrimRight(N.Text)); end;
  if A=B then Exit;
  S:=ProseFragment(FRoot,FSource,0,A)+Prefix; NewA:=Length(S);
  S:=S+ProseFragment(FRoot,FSource,A,B,'@size'); NewB:=Length(S);
  S:=S+'}'+ProseFragment(FRoot,FSource,B,Length(FSource)); CompactProseFormatting(S,NewA,NewB);
  Commit(S,NewB); SetSourceSelection(NewA,NewB);
  NotifySelection;
end;
procedure TMathEditor.ClearTextFormatting;
var N:TMathNode; A,B,NewA,NewB:Integer; S:string;
begin
  if FormatTableSelection('@all','') then Exit;
  N:=CurrentNode; if (N=nil) or InMath or IsCodeField(N) then Exit;
  if not SelectionRange(A,B) then begin A:=MathSourceOffset(N); B:=A+Length(TrimRight(N.Text)); end;
  if A=B then Exit;
  S:=ProseFragment(FRoot,FSource,0,A); NewA:=Length(S);
  S:=S+ProseFragment(FRoot,FSource,A,B,'@all'); NewB:=Length(S);
  S:=S+ProseFragment(FRoot,FSource,B,Length(FSource)); CompactProseFormatting(S,NewA,NewB);
  Commit(S,NewB); SetSourceSelection(NewA,NewB);
  NotifySelection;
end;
procedure TMathEditor.ToggleComment;
var A,B,NewA,NewB,Position:Integer; N:TMathNode; S,Middle,BeforeText,AfterText:string; WasComment:Boolean;
begin
  N:=CurrentNode; if N=nil then Exit;
  if not SelectionRange(A,B) then begin
    Position:=SourceCaret; A:=Position; B:=Position;
    while (A>0) and not (FSource[A] in [#10,#13]) do Dec(A);
    while (B<Length(FSource)) and not (FSource[B+1] in [#10,#13]) do Inc(B);
    Middle:=ToggleSourceComment(Copy(FSource,A+1,B-A));
    NewA:=EnsureRange(Position+Length(Middle)-(B-A),A,A+Length(Middle));
    { Keep a following block or end-document marker out of a final comment. }
    if (B=Length(FSource)) and (Copy(TrimLeft(Middle),1,1)='%') then Middle:=Middle+LineEnding;
    S:=Copy(FSource,1,A)+Middle+Copy(FSource,B+1,MaxInt);
    Commit(S,NewA);
    NotifySelection; Exit;
  end;
  WasComment:=False;
  if N.Parent<>nil then if N.Parent.Kind=mkComment then begin
    A:=Min(A,MathSourceOffset(N)); B:=Max(B,MathSourceOffset(N)+Length(N.Text)); WasComment:=True;
  end;
  BeforeText:=ProseFragment(FRoot,FSource,0,A); Middle:=ProseFragment(FRoot,FSource,A,B);
  WasComment:=WasComment or (Copy(TrimLeft(Middle),1,1)='%');
  AfterText:=ProseFragment(FRoot,FSource,B,Length(FSource)); Middle:=ToggleSourceComment(Middle);
  if not WasComment then begin
    if (BeforeText<>'') and (BeforeText[Length(BeforeText)]<>#10) then BeforeText:=BeforeText+LineEnding;
    if (Middle<>'') and (Middle[Length(Middle)]<>#10) then Middle:=Middle+LineEnding;
  end;
  S:=BeforeText; NewA:=Length(S); S:=S+Middle; NewB:=Length(S); S:=S+AfterText;
  Commit(S,NewB); SetSourceSelection(NewA,NewB);
  NotifySelection;
end;
procedure TMathEditor.FormatText(const Command:string);
var N,Root:TMathNode; A,B,NewA,NewB:Integer; S,Middle,Prefix,Suffix,StripCommand:string;
    Fields:TList; Selection:TTeXTextSelection; Override:string;
begin
  if (Command='\textrm') or (Command='\textsf') or (Command='\texttt') then begin
    if TextStyleActive(Command) then SetTextFamily('\textrm') else SetTextFamily(Command); Exit;
  end;
  if FormatTableSelection(Command,'') then Exit;
  N:=CurrentNode; if (N=nil) or InMath then Exit;
  if not SelectionRange(A,B) then begin A:=MathSourceOffset(N); B:=A+Length(TrimRight(N.Text)); end;
  if A=B then Exit;
  Prefix:=''; Suffix:='';
  if (Command<>'\textcolor') and not TextStyleActive(Command) then begin Prefix:=Command+'{'; Suffix:='}'; end;
  StripCommand:=Command; if (Command='\textbf') or (Command='\textmd') then StripCommand:='@series';
  if (Command='\textit') or (Command='\textsl') or (Command='\textup') or (Command='\emph') then StripCommand:='@slope';
  Middle:=ProseFragment(FRoot,FSource,A,B,StripCommand);
  S:=ProseFragment(FRoot,FSource,0,A)+Prefix; NewA:=Length(S);
  S:=S+Middle; NewB:=Length(S);
  S:=S+Suffix+ProseFragment(FRoot,FSource,B,Length(FSource));
  { Heading and theorem fonts are inherited from the paragraph. Removing a
    text wrapper alone cannot switch off that inherited bold/italic shape. }
  if (Prefix='') and ((Command='\textbf') or (Command='\textit') or (Command='\textsl') or (Command='\emph')) then begin
    Root:=ParseParagraph(S,FRegistry); Fields:=TList.Create;
    try
      MathFields(Root,Fields);
      Selection:=QueryTextSelectionStyle(Fields,nil,NewA,NewB,
        InitialTextStyle(FPreamble,FDirectory,FEngine,FRegistry),FDraft.Styles,FDraft.Context,FDirectory);
      Override:='';
      if TextSelectionStyleActive(Selection,Command) then begin
        if Command='\textbf' then Override:='\textmd{' else Override:='\textup{';
      end;
      if Override<>'' then begin Insert('}',S,NewB+1); Insert(Override,S,NewA+1); Inc(NewA,Length(Override)); Inc(NewB,Length(Override)); end;
    finally Fields.Free; Root.Free; end;
  end;
  CompactProseFormatting(S,NewA,NewB);
  Commit(S,NewB); SetSourceSelection(NewA,NewB);
  NotifySelection;
end;
procedure TMathEditor.SetTextColor(const HTMLColor:string);
var N:TMathNode; A,B,NewA,NewB:Integer; S,Middle:string;
begin
  if HTMLColor='' then begin FormatText('\textcolor'); Exit; end;
  if FormatTableSelection('\textcolor',HTMLColor) then Exit;
  N:=CurrentNode; if (N=nil) or InMath then Exit;
  if not SelectionRange(A,B) then begin A:=MathSourceOffset(N); B:=A+Length(TrimRight(N.Text)); end;
  if A=B then Exit;
  Middle:=ProseFragment(FRoot,FSource,A,B,'\textcolor');
  S:=ProseFragment(FRoot,FSource,0,A)+'\textcolor[HTML]{'+HTMLColor+'}{'; NewA:=Length(S);
  S:=S+Middle; NewB:=Length(S); S:=S+'}'+ProseFragment(FRoot,FSource,B,Length(FSource));
  CompactProseFormatting(S,NewA,NewB);
  Commit(S,NewB); SetSourceSelection(NewA,NewB);
  NotifySelection;
end;
procedure TMathEditor.WrapSelection(const Prefix,Suffix:string);
var A,B:Integer;
begin
  if not SelectionRange(A,B) then begin A:=SourceCaret; B:=A; end;
  WrapSelectionRange(Prefix,Suffix,A,B);
end;
procedure TMathEditor.WrapSelectionRange(const Prefix,Suffix:string; A,B:Integer);
var Caret:Integer; S,Value:string;
begin
  Value:=Prefix+ProseFragment(FRoot,FSource,A,B)+Suffix;
  S:=ReplaceProseRange(FRoot,FSource,A,B,Value,Caret,False);
  A:=Caret-Length(Value)+Length(Prefix); B:=Caret-Length(Suffix);
  CompactProseFormatting(S,A,B);
  Commit(S,A); if B>A then SetSourceSelection(A,B);
end;
{$I matheditorshortcuts.inc}
function TMathEditor.CommandNodeAtCaret:TMathNode;
begin
  Result:=CurrentNode;
  while Result<>nil do begin
    if (Result.Kind in [mkCommand,mkTextCommand,mkFraction,mkRoot,mkIndexedRoot,mkAccent,
      mkBinomial,mkDefinition,mkUnknownCommand,mkGroup]) and (Copy(Result.TeX,1,1)='\') then Exit;
    Result:=Result.Parent;
  end;
end;
function TMathEditor.CurrentCommandName:string;
var N:TMathNode; P:Integer;
begin
  Result:=''; N:=CommandNodeAtCaret;
  if N<>nil then begin P:=1; Result:=ReadTeXCommand(N.TeX,P); end;
end;
function TMathEditor.CurrentCommandPath:string;
begin Result:=CommandPath(CurrentNode); end;
{$I matheditordefinitions.inc}
function TMathEditor.CurrentCommandSource:string;
var N:TMathNode;
begin
  Result:=''; N:=CommandNodeAtCaret; if N<>nil then Result:=N.TeX;
end;
procedure TMathEditor.ReplaceCurrentCommand(const Value:string);
var N:TMathNode; A:Integer; WasNormalizing:Boolean;
begin
  N:=CommandNodeAtCaret; if N=nil then Exit;
  A:=MathSourceOffset(N)-Length(N.Prefix);
  WasNormalizing:=FNormalizeOptional; FNormalizeOptional:=True; FNormalizeCommandStart:=A;
  try Commit(Copy(FSource,1,A)+Value+Copy(FSource,A+Length(N.TeX)+1,MaxInt),A+Length(Value));
  finally FNormalizeOptional:=WasNormalizing; FNormalizeCommandStart:=-1; end;
end;
procedure TMathEditor.RenameCommand(const NewName:string);
var N:TMathNode; P,Offset,I:Integer; Value:string;
begin
  Value:=NewName; if Copy(Value,1,1)='\' then Delete(Value,1,1);
  if Value='' then Exit;
  for I:=1 to Length(Value) do if not (Value[I] in ['a'..'z','A'..'Z','@']) then Exit;
  N:=CommandNodeAtCaret;
  if N=nil then Exit;
  P:=1; ReadTeXCommand(N.TeX,P); Offset:=MathSourceOffset(N)-Length(N.Prefix);
  Commit(Copy(FSource,1,Offset)+'\'+Value+Copy(FSource,Offset+P,MaxInt),Offset+Length(Value)+1);
end;
procedure TMathEditor.InsertAnnotation(const Command,Value:string);
var A,B,I:Integer; N,Body,Child:TMathNode;
begin
  if Value='' then Exit;
  if (Pos('{',Value)>0) or (Pos('}',Value)>0) or (Pos('\',Value)>0) then Exit;
  A:=SourceCaret;
  if (Command='label') or (Command='tag') then
  begin
    N:=CurrentNode; while (N<>nil) and (N.Kind<>mkFormula) do N:=N.Parent;
    if N<>nil then
    begin
      Body:=TMathNode(N.Children[0]); B:=MathSourceOffset(N)+Length(N.TeX)-Length(N.Prefix)-Length(N.Suffix);
      for I:=0 to Body.Children.Count-1 do
      begin
        Child:=TMathNode(Body.Children[I]);
        if (Child.Kind=mkRaw) and (Copy(Child.Text,1,2)='\'+ '\') and (MathSourceOffset(Child)>=A) then begin B:=MathSourceOffset(Child); Break; end;
      end;
      A:=B;
    end;
  end;
  Commit(Copy(FSource,1,A)+'\'+Command+'{'+Value+'}'+Copy(FSource,A+1,MaxInt),A+Length(Command)+Length(Value)+3);
end;
procedure TMathEditor.LabelNames(Dest:TStrings);
var S:string; I:Integer;
begin
  S:=FPreamble;
  for I:=0 to FDocumentBlocks.Count-1 do
    if I=FDocumentIndex then S:=S+FSource else S:=S+FDocumentBlocks[I];
  if FDocumentIndex<0 then S:=S+FSource;
  if FContext=nil then FContext:=TTeXContext.Create;
  FContext.Load(S,FDirectory,FEngine); FContext.LabelNames(Dest);
end;
procedure TMathEditor.TheoremNames(Dest:TStrings);
begin LabelNames(Dest); FContext.TheoremNames(Dest); end;
procedure TMathEditor.HeadingNames(Dest:TStrings);
const Names:array[0..6] of string=('part','chapter','section','subsection','subsubsection','paragraph','subparagraph');
var Heading:string; Macro:TMacroInfo;
begin
  Dest.Clear; LoadRegistry;
  for Heading in Names do begin
    Macro:=FRegistry.Find(Heading);
    if ((Macro<>nil) and (Trim(Macro.Body)<>'\relax') and not Macro.Undefined and
        (Trim(Macro.Body)<>'\@undefined')) or
       ((Macro=nil) and (Pos('{letter}',FPreamble)=0) and
        ((Heading<>'chapter') or (Pos('book}',FPreamble)>0) or (Pos('report}',FPreamble)>0) or (Pos('ctexrep}',FPreamble)>0))) then Dest.Add(Heading);
  end;
end;
procedure TMathEditor.CitationNames(Dest:TStrings);
var S:string; I:Integer;
begin
  S:=FPreamble;
  for I:=0 to FDocumentBlocks.Count-1 do
    if I=FDocumentIndex then S:=S+FSource else S:=S+FDocumentBlocks[I];
  if FDocumentIndex<0 then S:=S+FSource;
  BibliographyKeys(S,FDirectory,Dest);
end;
function TMathEditor.EditReferenceAt(X,Y:Integer):Boolean;
var Index:Integer; Space:Boolean;
begin
  Result:=False; Index:=ClickableFieldAt(X,Y,Space);
  if (Index<0) or Space then Exit;
  if Pos('\includegraphics',TMathNode(FFields[Index]).Text)=1 then Exit;
  if (Pos('\input',TMathNode(FFields[Index]).Text)=1) or (Pos('\include',TMathNode(FFields[Index]).Text)=1) or (Pos('\subfile',TMathNode(FFields[Index]).Text)=1) then Exit;
  { Resolve the rendered reference rather than the caret at its right edge. }
  FActive:=Index; FCaret:=0; FSelected:=False; FSelectionAnchor:=-1; FSelectionFocus:=-1;
  EditAnnotation; Result:=True;
end;
function TMathEditor.ClickableFieldAt(X,Y:Integer; out Space:Boolean):Integer;
var Regions:TDraftRegions; I,J,P:Integer; N:TMathNode; Cmd,Units:string;
    SpaceWidth:Double; R:TRect;
begin
  Result:=-1; Space:=False;
  EnsureDraft; Regions:=FDraft.Regions;
  Dec(X,ImageLeft); Dec(Y,ImageTop);
  for I:=0 to High(Regions) do begin
    R:=Regions[I].Bounds;
    if not PtInRect(R,Point(X,Y)) then Continue;
    for J:=0 to FFields.Count-1 do begin
      N:=TMathNode(FFields[J]); if (N.ID<>Regions[I].ID) or IsCodeField(N) then Continue;
      Space:=(N.Kind=mkCommand) and (ReadMathSpace(N.TeX,SpaceWidth,Units) or ReadVerticalSpace(N.TeX,SpaceWidth,Units));
      P:=1; Cmd:=ReadTeXCommand(N.Text,P);
      Space:=Space or (Cmd='indent') or (Cmd='noindent');
      if Space or IsTeXInputCommand(Cmd) or IsLabelReference(Cmd) or IsCitationCommand(Cmd) or
        (Cmd='includegraphics') or (Cmd='includepdf') then Exit(J);
    end;
  end;
end;
function TMathEditor.EditInputAt(X,Y:Integer):Boolean;
var Index,P,A:Integer; Space:Boolean; N:TMathNode; Command,LinkedName,Value:string; D:TOpenDialog;
begin
  Result:=False; Index:=ClickableFieldAt(X,Y,Space); if (Index<0) or Space then Exit;
  N:=TMathNode(FFields[Index]); P:=1; Command:=ReadTeXCommand(N.Text,P);
  if not IsTeXInputCommand(Command) then Exit;
  Result:=True; D:=TOpenDialog.Create(Self);
  try
    D.Filter:='TeX files|*.tex;*.sty|All files|*'; D.InitialDir:=FDirectory;
    if not D.Execute then Exit; LinkedName:=ExtractRelativePath(IncludeTrailingPathDelimiter(FDirectory),D.FileName);
    LinkedName:=StringReplace(LinkedName,DirectorySeparator,'/',[rfReplaceAll]); Value:='\'+Command+'{'+LinkedName+'}';
    A:=MathSourceOffset(N); Commit(Copy(FSource,1,A)+Value+Copy(FSource,A+Length(N.TeX)+1,MaxInt),A+Length(Value));
  finally D.Free; end;
end;
function TMathEditor.RuleAt(X,Y:Integer):TMathNode;
var Region:TDraftRegion; R:TRect; Rule:TTeXRule;
  function Find(Node:TMathNode; ID:Integer):TMathNode;
  var I:Integer; Child:TMathNode;
  begin
    Result:=nil; if Node=nil then Exit; if Node.ID=ID then Exit(Node);
    for I:=Node.Children.Count-1 downto 0 do begin
      Child:=TMathNode(Node.Children[I]); if Child.ID<=ID then Exit(Find(Child,ID));
    end;
  end;
begin
  EnsureDraft; Result:=nil; Dec(X,ImageLeft); Dec(Y,ImageTop);
  for Region in FDraft.Regions do begin
    R:=Region.Bounds; InflateRect(R,0,4); if not PtInRect(R,Point(X,Y)) then Continue;
    Result:=Find(FRoot,Region.ID);
    if (Result<>nil) and (Result.Kind=mkCommand) and ReadTeXRule(Result.TeX,Rule) then Exit;
  end;
  Result:=nil;
end;
function TMathEditor.EditSpaceAt(X,Y:Integer):Boolean;
var Index,A:Integer; N:TMathNode; Value,Tail:string; Space:Boolean;
begin
  N:=RuleAt(X,Y); Result:=N<>nil;
  if Result then begin Value:=N.TeX; if not EditRuleDialog(Self,Value) then Exit; end
  else begin
    Index:=ClickableFieldAt(X,Y,Space); Result:=(Index>=0) and Space;
    if not Result then Exit;
    N:=TMathNode(FFields[Index]); Value:=N.TeX;
    if (Value='\indent') or (Value='\noindent') then begin
      if not EditIndentDialog(Self,Value) then Exit;
    end else if not EditMathSpaceDialog(Self,Value) then Exit;
  end;
  A:=MathSourceOffset(N)-Length(N.Prefix); Tail:=Copy(FSource,A+Length(N.TeX)+1,MaxInt);
  { A named control word must stay separate from a following letter. }
  if (Value<>'') and (Tail<>'') and (Value[Length(Value)] in ['a'..'z','A'..'Z','@']) and
     (Tail[1] in ['a'..'z','A'..'Z','@']) then Value:=Value+' ';
  Commit(Copy(FSource,1,A)+Value+Tail,A+Length(Value));
end;
procedure TMathEditor.EditAnnotation;
var N:TMathNode; P,A,B:Integer; Cmd,Value,Replacement,Star:string; D:TForm; Choices:TComboBox; Button:TButton;
    Citation:TCitationSource; PreNote,PostNote:TEdit; CaptionLabel:TLabel; RangeEnd:TComboBox; LastValue:string;
  procedure FieldCaption(const Text:string; Y:Integer);
  begin
    CaptionLabel:=TLabel.Create(D); CaptionLabel.Parent:=D; CaptionLabel.SetBounds(16,Y,328,20); CaptionLabel.Caption:=Text;
  end;
begin
  N:=CurrentNode;
  while N<>nil do begin
    P:=1; Cmd:=ReadTeXCommand(N.Text,P);
    if (Cmd='label') or (Cmd='tag') or IsLabelReference(Cmd) or IsCitationCommand(Cmd) then Break;
    N:=N.Parent;
  end;
  if N=nil then begin MessageDlg('Edit reference','Click a label, tag, reference, or bibliography citation first.',mtInformation,[mbOK],0); Exit; end;
  P:=Length(Cmd)+2;
  Star:=''; if Copy(N.TeX,P,1)='*' then begin Inc(P); Star:='*'; end;
  Value:=ReadTeXGroup(N.TeX,P,'{','}');
  LastValue:=''; if (Cmd='crefrange') or (Cmd='Crefrange') then LastValue:=ReadTeXGroup(N.TeX,P,'{','}');
  if IsCitationCommand(Cmd) then begin
    if not ReadCitation(N.TeX,Citation) then Exit;
    D:=TForm.CreateNew(Self); D.Caption:='Bibliography citation'; D.Position:=poMainFormCenter;
    D.BorderStyle:=bsDialog; D.ClientWidth:=400; D.ClientHeight:=246;
    try
      FieldCaption('Entry keys (separate multiple keys with commas)',12);
      Choices:=TComboBox.Create(D); Choices.Name:='CitationKeys'; Choices.Parent:=D; Choices.SetBounds(16,34,368,28);
      CitationNames(Choices.Items); Choices.Text:=Citation.Keys;
      FieldCaption('Before citation',76);
      PreNote:=TEdit.Create(D); PreNote.Name:='PreNote'; PreNote.Parent:=D; PreNote.SetBounds(16,98,368,28); PreNote.Text:=Citation.PreNote;
      FieldCaption('After citation / page numbers',140);
      PostNote:=TEdit.Create(D); PostNote.Name:='PostNote'; PostNote.Parent:=D; PostNote.SetBounds(16,162,368,28); PostNote.Text:=Citation.PostNote;
      Button:=TButton.Create(D); Button.Parent:=D; Button.SetBounds(210,206,80,30); Button.Caption:='Apply'; Button.Default:=True; Button.ModalResult:=mrOK;
      Button:=TButton.Create(D); Button.Parent:=D; Button.SetBounds(300,206,80,30); Button.Caption:='Cancel'; Button.Cancel:=True; Button.ModalResult:=mrCancel;
      ApplyTheme(D); if D.ShowModal<>mrOK then Exit;
      Citation.Keys:=Trim(Choices.Text); Citation.PreNote:=PreNote.Text; Citation.PostNote:=PostNote.Text;
      Value:=Citation.Keys;
      if (Pos('}',Value)>0) or (Pos('{',Value)>0) or (Pos(']',Citation.PreNote)>0) or (Pos(']',Citation.PostNote)>0) then Exit;
      Replacement:=''; if Value<>'' then Replacement:=CitationSource(Citation);
    finally D.Free; end;
  end else if IsLabelReference(Cmd) then begin
    D:=TForm.CreateNew(Self); D.Caption:='Reference target'; D.Position:=poMainFormCenter;
    D.BorderStyle:=bsDialog; D.ClientWidth:=360; D.ClientHeight:=110;
    try
      Choices:=TComboBox.Create(D); Choices.Parent:=D; Choices.SetBounds(16,16,328,28);
      LabelNames(Choices.Items); Choices.Text:=Value;
      RangeEnd:=nil;
      if (Cmd='crefrange') or (Cmd='Crefrange') then begin
        D.ClientHeight:=158; RangeEnd:=TComboBox.Create(D); RangeEnd.Parent:=D;
        RangeEnd.SetBounds(16,64,328,28); RangeEnd.Items.Assign(Choices.Items); RangeEnd.Text:=LastValue;
      end;
      Button:=TButton.Create(D); Button.Parent:=D; Button.SetBounds(170,64,80,30); Button.Caption:='Apply'; Button.Default:=True; Button.ModalResult:=mrOK;
      if RangeEnd<>nil then Button.Top:=112;
      Button:=TButton.Create(D); Button.Parent:=D; Button.SetBounds(260,64,80,30); Button.Caption:='Cancel'; Button.Cancel:=True; Button.ModalResult:=mrCancel;
      if RangeEnd<>nil then Button.Top:=112;
      ApplyTheme(D); if D.ShowModal<>mrOK then Exit; Value:=Choices.Text;
      if RangeEnd<>nil then LastValue:=RangeEnd.Text;
    finally D.Free; end;
  end else if not InputQuery('Edit '+Cmd,'Value (empty removes the command):',Value) then Exit;
  if (Pos('{',Value+LastValue)>0) or (Pos('}',Value+LastValue)>0) then Exit;
  A:=MathSourceOffset(N)-Length(N.Prefix); B:=A+Length(N.TeX);
  if not IsCitationCommand(Cmd) then begin Replacement:=''; if Value<>'' then Replacement:='\'+Cmd+Star+'{'+Value+'}'; end;
  if (Replacement<>'') and ((Cmd='crefrange') or (Cmd='Crefrange')) then Replacement:=Replacement+'{'+LastValue+'}';
  Commit(Copy(FSource,1,A)+Replacement+Copy(FSource,B+1,MaxInt),A+Length(Replacement));
end;
procedure TMathEditor.EditTheoremTitle;
var N,Option:TMathNode; I,J,A:Integer;
begin
  N:=CurrentNode;
  while (N<>nil) and (N.Kind<>mkEnvironment) do N:=N.Parent;
  if N=nil then Exit;
  for I:=0 to N.Children.Count-1 do begin
    Option:=TMathNode(N.Children[I]);
    if (Option.Kind=mkOptional) and (Option.Children.Count>0) then begin
      Option:=TMathNode(Option.Children[0]); A:=MathSourceOffset(Option);
      SetSourceSelection(A,A+Length(Option.TeX));
      for J:=0 to FFields.Count-1 do if TMathNode(FFields[J])=Option then begin FActive:=J; FCaret:=UTF8Length(Option.Text); Break; end;
      Invalidate; Exit;
    end;
  end;
end;
procedure TMathEditor.SetHeading(const Command:string);
var N:TMathNode; Prefix,Suffix,S:string; A,B,Start,Offset:Integer;
  function Heading(Node:TMathNode):TMathNode;
  var I,L,R,P:Integer; Name:string;
  begin
    Result:=nil;
    P:=1; Name:=ReadTeXCommand(Node.Prefix,P);
    if (Node.Kind=mkGroup) and ((Name='part') or (Name='chapter') or (Name='section') or
      (Name='subsection') or (Name='subsubsection') or (Name='paragraph') or (Name='subparagraph')) then begin
      L:=MathSourceOffset(Node)-Length(Node.Prefix); R:=L+Length(Node.TeX);
      if (Offset>=L) and (Offset<=R) then Exit(Node);
    end;
    for I:=0 to Node.Children.Count-1 do begin
      Result:=Heading(TMathNode(Node.Children[I])); if Result<>nil then Exit;
    end;
  end;
begin
  Offset:=SourceCaret; N:=Heading(FRoot);
  if InMath and (N=nil) then Exit;
  Prefix:=Command+'{'; Suffix:='}'; if Command='' then begin Prefix:=''; Suffix:=''; end;

  if (Command<>'') and SelectionRange(A,B) then begin
   Commit(Copy(FSource,1,A)+Prefix+Copy(FSource,A+1,B-A)+Suffix+Copy(FSource,B+1,MaxInt),A+Length(Prefix)); Exit;
  end;
  if N<>nil then begin
    Start:=MathSourceOffset(N)-Length(N.Prefix);
    S:=Copy(N.TeX,Length(N.Prefix)+1,Length(N.TeX)-Length(N.Prefix)-Length(N.Suffix));
   Commit(Copy(FSource,1,Start)+Prefix+S+Suffix+Copy(FSource,Start+Length(N.TeX)+1,MaxInt),
      Start+Length(Prefix)+EnsureRange(Offset-Start-Length(N.Prefix),0,Length(S))); Exit;
  end;
  if Command<>'' then Commit(Prefix+Trim(FSource)+Suffix,Length(Prefix));
end;
function TMathEditor.NormalizeDiagramEdit(const Value:string; var Caret:Integer):string;
var N:TMathNode; Model:TCommutativeDiagram; Field:TCommutativeField; A,B,Start,Tail,EndAt:Integer;
begin
  Result:=Value; N:=CurrentNode;
  if (N=nil) or IsCodeField(N) then Exit;
  while (N<>nil) and (N.DiagramField<0) do N:=N.Parent;
  if (N=nil) or (N.Parent=nil) or (N.Parent.Kind<>mkDiagram) then Exit;
  Start:=MathSourceOffset(N.Parent)-Length(N.Parent.Prefix); Model:=TCommutativeDiagram.Create;
  try
    { ApplyField may already have changed the live tree. Use the committed
      source to identify the original unbraced XY-pic label token. }
    if not Model.Load(Copy(FSource,Start+1,MaxInt)) or (Model.PackageName<>'xy') or (N.DiagramField>=Length(Model.Fields)) then Exit;
    Field:=Model.Fields[N.DiagramField];
    if (Field.Kind<>cfLabel) or ((Field.First>0) and (Model.Source[Field.First]='{')) then Exit;
    A:=Start+Field.First; B:=Start+Field.Last; Tail:=Length(FSource)-B; EndAt:=Length(Value)-Tail;
    if (EndAt<A) or (Copy(Value,1,A)<>Copy(FSource,1,A)) or (Copy(Value,EndAt+1,MaxInt)<>Copy(FSource,B+1,MaxInt)) then Exit;
    Result:=Copy(Value,1,A)+'{'+Copy(Value,A+1,EndAt-A)+'}'+Copy(Value,EndAt+1,MaxInt);
    if Caret>=A then Inc(Caret); if Caret>EndAt+1 then Inc(Caret);
  finally Model.Free; end;
end;
procedure TMathEditor.Commit(const AValue:string; Caret:Integer);
var I,A,B,Distance,BestDistance,DesiredDepth,Depth,BestDepth,OldOffset,EndAt,ResumeCaret:Integer; N:TMathNode; SourceChanged:Boolean; Value,HistorySource:string; SourceIndex:TMathSourceIndex;
  function ScriptDepth(Node:TMathNode):Integer;
  begin
    Result:=0;
    while Node<>nil do
    begin
      if (Node.Kind=mkGroup) and (Node.Prefix<>'') and (Node.Prefix[1] in ['^','_']) then Inc(Result);
      Node:=Node.Parent;
    end;
  end;
begin
  Value:=AValue;
  if Value<>FSource then Value:=NormalizeDiagramEdit(Value,Caret);
  if not FFinishingDefinition then begin
    if Value<>FSource then BeginDefinitionEdit;
    if FDefinitionStart>=0 then begin
      EndAt:=FDefinitionStart+1;
      if not ReadTeXDefinition(Value,EndAt) then FDefinitionStart:=-1
      else if (Caret<FDefinitionStart) or (Caret>=EndAt-1) then Value:=CompleteDefinition(Value,Caret);
    end;
  end;
  DesiredDepth:=ScriptDepth(CurrentNode); BestDepth:=MaxInt;
  OldOffset:=SourceCaret;
  HistorySource:=FSource;
  if FOptionalTransient and not FMaterializingOptional then begin HistorySource:=FOptionalBefore; OldOffset:=FOptionalBeforeCaret; end;
  SourceChanged:=Value<>FSource;
  if SourceChanged and not FFormattingSource and not FCodeOnly and
    not IsCodeField(CurrentNode) and not IsVerbatimField(CurrentNode) then FVisualSourceDirty:=True;
  ResumeCaret:=-1;
  if SourceChanged then
  begin
    if (FInlineSourceA>=0) and (OldOffset>=FInlineSourceA) and (OldOffset<=FInlineSourceB) then Inc(FInlineSourceB,Length(Value)-Length(FSource));
    FEditCaretBefore:=OldOffset;
    { The host owns document history. Do not retain a second copy per card. }
    FSource:=Value; ParseSource;
    FOptionalResumeOffset:=-1;
    if FNormalizeOptional and not FFallback and OmitDefaultArgument(FRoot,Caret,ResumeCaret,FNormalizeCommandStart) then begin
      FSource:=FRoot.TeX; ParseSource;
    end;
    if not FMaterializingOptional then begin
      if not FFormattingSource and not Assigned(FUndoRequested) and (FSource<>HistorySource) then begin
        FUndo.Add(HistorySource); if FUndo.Count>100 then FUndo.Delete(0); FRedo.Clear;
      end;
      FOptionalTransient:=False; FOptionalBefore:='';
    end;
  end;
  SourceIndex:=TMathSourceIndex.Create(FRoot);
  try
  FCaret:=0; BestDistance:=MaxInt;
  for I:=0 to FFields.Count-1 do
  begin
    N:=TMathNode(FFields[I]); A:=NodeOffset(N); B:=A+Length(N.Text);
    if (N.Parent<>nil) and N.Parent.SourceEditing and (Caret>=A) and (Caret<=B) then begin
      FActive:=I; FCaret:=UTF8Length(Copy(N.Text,1,Caret-A)); Break;
    end;
    Distance:=Max(A-Caret,Max(Caret-B,0));
    Depth:=Abs(ScriptDepth(N)-DesiredDepth);
    if (Distance<BestDistance) or ((Distance=BestDistance) and ((Depth<BestDepth) or
       ((Depth=BestDepth) and (A<Caret) and (Caret>=OldOffset)))) then
    begin
      BestDistance:=Distance; BestDepth:=Depth; FActive:=I;
      FCaret:=UTF8Length(Copy(N.Text,1,EnsureRange(Caret-A,0,Length(N.Text))));
    end;
  end;
  N:=CurrentNode;
  if (N<>nil) and (N.Kind in [mkCommand,mkTextCommand]) and (FCaret>0) then FCaret:=UTF8Length(N.Text);
  SnapProseCaret(1);
  if ResumeCaret>=0 then begin FOptionalResumeOffset:=SourceCaret; FOptionalResumeCaret:=ResumeCaret; end;
  FSelectionAnchor:=-1; FSelectionFocus:=-1; FSelected:=False; Invalidate;
  finally SourceIndex.Free; end;
  if SourceChanged then begin TrackEmptyScript; Schedule; if not FMaterializingOptional then NotifyChange; end;
end;
procedure TMathEditor.ApplyField(const Value:string; Caret:Integer);
var N,FormulaNode:TMathNode; S:string; Offset:Integer;
begin
  N:=CurrentNode; if N=nil then Exit;
  if N.DefinitionArgument>=0 then begin SetDefinitionArgumentDefault(N.DefinitionArgument,Value,Caret); Exit; end;
  S:=Value; if InMath and not InTextArgument and not IsLabelField(N) and not IsCodeField(N) then S:=TextToTeX(Value);
  if (N=FRoot) then begin Commit(S,Length(S)); Exit; end;
  if (N.Parent<>nil) and ((N.Parent.Kind=mkCommand) or
      ((N.Parent.Kind=mkGroup) and ((N.Parent.Prefix='^') or (N.Parent.Prefix='_')))) then
  begin N.Prefix:=N.Prefix+'{'; N.Suffix:='}'+N.Suffix; end;
  Offset:=Length(UTF8Copy(Value,1,Caret));
  if InMath and not InTextArgument and not IsLabelField(N) and not IsCodeField(N) then Offset:=Length(TextToTeX(UTF8Copy(Value,1,Caret)));
  N.Text:=S;
  if (N.Parent<>nil) and (N.Parent.Kind=mkOptional) and (N.Parent.Parent<>nil) and (N.Parent.Parent.Kind=mkEnvironment) then begin
    if S='' then begin N.Parent.Prefix:=''; N.Parent.Suffix:=''; end
    else begin N.Parent.Prefix:='['; N.Parent.Suffix:=']'; end;
  end;
  FormulaNode:=N;
  while (FormulaNode<>nil) and (FormulaNode.Kind<>mkFormula) do FormulaNode:=FormulaNode.Parent;
  if (FormulaNode<>nil) and (FormulaNode.Prefix='$') and (FormulaNode.Suffix='$') and
     (FormulaNode.TeX='$$') then N.Text:=' ';
  Offset:=NodeOffset(N)+Offset;
  Commit(FRoot.TeX,Offset);
end;
function TMathEditor.ActivateOptionalArgument:Boolean;
var N:TMathNode; Offset,Resume:Integer; Value:string; WasNormalizing:Boolean;
begin
  N:=MissingOptionalArgument(CurrentNode); Result:=N<>nil; if not Result then Exit;
  Offset:=MathSourceOffset(N); Value:=N.Text; if Value='\NoValue' then Value:='';
  Resume:=-1; if SourceCaret=FOptionalResumeOffset then Resume:=FOptionalResumeCaret;
  WasNormalizing:=FNormalizeOptional; FNormalizeOptional:=False;
  FOptionalCommandStart:=MathSourceOffset(N.Parent)-Length(N.Parent.Prefix);
  FOptionalArgumentIndex:=N.Parent.Children.IndexOf(N);
  if N.OptionalDefault then begin
    FOptionalBefore:=FSource; FOptionalBeforeCaret:=SourceCaret;
    FOptionalTransient:=True; FMaterializingOptional:=True;
  end;
  try
    Commit(Copy(FSource,1,Offset)+'['+Value+']'+Copy(FSource,Offset+1,MaxInt),Offset+1+IfThen(Resume<0,Length(Value),Resume));
    if Resume<0 then SetSourceSelection(Offset+1,Offset+1+Length(Value));
  finally FNormalizeOptional:=WasNormalizing; FMaterializingOptional:=False; end;
  NotifySelection;
end;
procedure TMathEditor.FinishOptionalEdit;
var Position,Resume,Anchor,Focus,CommandStart:Integer; Value,Content:string; Silent,Removed:Boolean;
    Argument,Protected:TMathNode; I:Integer;
  function EditedArgument(Node:TMathNode):TMathNode;
  var J:Integer;
  begin
    Result:=nil;
    if (Node.Kind=mkCommand) and (MathSourceOffset(Node)-Length(Node.Prefix)=CommandStart) then begin
      if FOptionalArgumentIndex<Node.Children.Count then Result:=TMathNode(Node.Children[FOptionalArgumentIndex]); Exit;
    end;
    for J:=0 to Node.Children.Count-1 do begin Result:=EditedArgument(TMathNode(Node.Children[J])); if Result<>nil then Exit; end;
  end;
begin
  if FMaterializingOptional or (FOptionalCommandStart<0) or (FRoot=nil) then Exit;
  CommandStart:=FOptionalCommandStart; FOptionalCommandStart:=-1;
  Argument:=EditedArgument(FRoot);
  if (Argument=nil) or (Argument.Kind<>mkOptional) or not Argument.OptionalDefault or (Argument.Suffix<>']') then Exit;
  Content:=''; for I:=0 to Argument.Children.Count-1 do Content:=Content+TMathNode(Argument.Children[I]).TeX;
  if Content<>Argument.Text then Exit;
  { Keep the argument being entered. Removing its brackets would discard
    the click position, and earlier optional slots may depend on it. }
  Protected:=CurrentNode; while (Protected<>nil) and (Protected.Kind<>mkOptional) do Protected:=Protected.Parent;
  if (Protected=Argument) or ((Protected<>nil) and not Protected.OptionalDefault) then Protected:=nil;
  if Protected<>nil then Protected.OptionalDefault:=False;
  Position:=SourceCaret; Anchor:=FSelectionAnchor; Focus:=FSelectionFocus;
  try Removed:=OmitDefaultArgument(FRoot,Position,Resume,CommandStart,@Anchor,@Focus);
  finally if Protected<>nil then Protected.OptionalDefault:=True; end;
  if not Removed then Exit;
  Value:=FRoot.TeX; Silent:=FOptionalTransient and (Value=FOptionalBefore);
  { The omitted field has been freed. Restore the old fields before Commit
    reads their caret and history, then let it parse the normalized source. }
  ParseSource;
  FMaterializingOptional:=Silent;
  try Commit(Value,Position); finally FMaterializingOptional:=False; end;
  FOptionalTransient:=False; FOptionalBefore:=''; FOptionalResumeOffset:=-1;
  FSelectionAnchor:=Anchor; FSelectionFocus:=Focus; Invalidate;
end;
procedure TMathEditor.SetFieldText(const Value:string);
var WasNormalizing:Boolean;
begin
  WasNormalizing:=FNormalizeOptional; FNormalizeOptional:=True;
  try ApplyField(Value,UTF8Length(Value)); finally FNormalizeOptional:=WasNormalizing; end;
end;
procedure TMathEditor.ReplaceSelection(const Value:string);
var N:TMathNode; S,V,Closing,Command:string; A,B,Advance,ReplacementLength,P,Q:Integer;
  procedure InsideFormula(Node:TMathNode);
  var I,L,R:Integer;
  begin
    L:=MathSourceOffset(Node)-Length(Node.Prefix); R:=L+Length(Node.TeX);
    if (Node.Kind=mkFormula) and (A=L) and (B=R) then
    begin Inc(A,Length(Node.Prefix)); Dec(B,Length(Node.Suffix)); Exit; end;
    for I:=0 to Node.Children.Count-1 do InsideFormula(TMathNode(Node.Children[I]));
  end;
begin
  if ReplaceTableSelection(Value) then Exit;
  N:=CurrentNode; if N=nil then Exit;
  if InMath and not InTextArgument and not FSelected and not SelectionRange(A,B) then begin
    A:=ScriptBoundaryEnd(FRoot,SourceCaret);
    if A<>SourceCaret then begin SetSourceCaret(A); N:=CurrentNode; end;
  end;
  Closing:=MatchingRight(Value); V:=Value;
  if Closing<>'' then begin
    if (V<>'') and (V[Length(V)] in ['a'..'z','A'..'Z']) then V:=V+' ';
    if Closing[Length(Closing)] in ['a'..'z','A'..'Z'] then Closing:=Closing+' ';
  end;
  if SelectionRange(A,B) then
  begin
    if (N.Parent<>nil) and (N.Parent.Kind=mkOptional) and (N.Parent.Parent<>nil) and
      (N.Parent.Parent.Kind=mkEnvironment) and (A>=MathSourceOffset(N)) and (B<=MathSourceOffset(N)+Length(N.Text)) then begin
      A:=A-MathSourceOffset(N); B:=B-MathSourceOffset(N);
      S:=Copy(N.Text,1,A)+Value+Copy(N.Text,B+1,MaxInt); ApplyField(S,UTF8Length(Copy(S,1,A+Length(Value)))); Exit;
    end;
    if (Closing<>'') or (Value='{') then
    begin
      InsideFormula(FRoot);
      if Closing='' then Closing:='}';
      S:=V+ProseFragment(FRoot,FSource,A,B)+Closing;
      ReplacementLength:=Length(S);
      S:=ReplaceProseRange(FRoot,FSource,A,B,S,Advance,False);
      Advance:=Advance-ReplacementLength+Length(V); B:=Advance;
      CompactProseFormatting(S,Advance,B); Commit(S,Advance);
    end
    else begin
      S:=ReplaceProseRange(FRoot,FSource,A,B,Value,Advance); Commit(S,Advance);
    end;
    Exit;
  end;
  if FSelected and InMath and not InTextArgument and ((Value='{') or (Closing<>'')) then
  begin
    A:=NodeOffset(N); B:=A+Length(N.Text);
    if Closing='' then Closing:='}';
   Commit(Copy(FSource,1,A)+V+N.Text+Closing+Copy(FSource,B+1,MaxInt),A+Length(V)); Exit;
  end;
  if Closing<>'' then
  begin
    A:=SourceCaret;
   Commit(Copy(FSource,1,A)+V+Closing+Copy(FSource,A+1,MaxInt),A+Length(V)); Exit;
  end;
  if InsertScript(Value) then Exit;
  { An ordinary keystroke is an insertion, never a command-name edit. A
    following script remains attached to the enlarged base group. }
  if InMath and not InTextArgument and not FSelected and (Value<>'') then begin
    A:=SourceCaret; P:=A;
    while (P>0) and (FSource[P] in ['a'..'z','A'..'Z','@']) do Dec(P);
    if (P>0) and (P<A) and (FSource[P]='\') then begin
      Command:=Copy(FSource,P,A-P+1); Q:=A+1; SkipTeXSpace(FSource,Q);
      V:=TextToTeX(Value);
      if (Q<=Length(FSource)) and (FSource[Q] in ['_','^']) then begin
        S:='{'+Command+' '+V+'}'; Advance:=P-1+Length(S)-1;
      end else begin S:=Command+' '+V; Advance:=P-1+Length(S); end;
    Commit(Copy(FSource,1,P-1)+S+Copy(FSource,A+1,MaxInt),Advance); Exit;
    end;
  end;
  V:=Value; Advance:=UTF8Length(V);
  if InMath and not InTextArgument and (V='{') then begin V:='{}'; Advance:=1; end;
  A:=FCaret; if FSelected then begin S:=''; A:=0; end else S:=N.Text;
  if (N.Kind in [mkTextCommand,mkCommand]) and not FSelected and (A=UTF8Length(S)) and
     (S<>'') and (S[Length(S)] in ['a'..'z','A'..'Z','@']) then
  begin
    if InMath then begin S:=S+' '; Inc(A); end
    else begin S:=S+'{}'; Inc(A,2); end;
  end;
  S:=UTF8Copy(S,1,A)+V+UTF8Copy(S,A+1,MaxInt);
  ApplyField(S,A+Advance);
end;
procedure TMathEditor.InsertTeX(const Value:string);
begin if InMath then ReplaceSelection(Value) else InsertEquation(Value); end;
procedure TMathEditor.InsertCommand(const Value:string);
var N,Argument:TMathNode; I,Offset,A,B,Slot,OptionalField:Integer; TextValue,Environment:string; ControlWord:Boolean;
begin
  N:=CurrentNode; if N=nil then Exit;
  if Copy(Value,1,7)='\begin{' then begin
    I:=7; Environment:=ReadTeXGroup(Value,I,'{','}');
    if (Environment<>'') and (I=Length(Value)+1) and (Value[I-1]='}') and
      (Pos('{',Environment)=0) and (Pos('\',Environment)=0) then begin
      WrapSelection(Value+LineEnding,LineEnding+'\end{'+Environment+'}'); Exit;
    end;
  end;
  if (Value='\verb') or (Value='\verb*') then begin WrapSelection(Value+'|','|'); Exit; end;
  if Copy(Value,1,5)='\verb' then begin
    I:=6; if Copy(Value,I,1)='*' then Inc(I);
    if (Length(Value)=I) and not (Value[I] in ['a'..'z','A'..'Z','@',' ',#9,#10,#13]) then
    begin WrapSelection(Value,Value[I]); Exit; end;
  end;
  if MatchingRight(Trim(Value))<>'' then begin ReplaceSelection(Trim(Value)); Exit; end;
  TextValue:=Value; ControlWord:=(Length(Value)>1) and (Value[1]='\');
  for I:=2 to Length(Value) do
    if not (Value[I] in ['a'..'z','A'..'Z','@']) then ControlWord:=False;
  if ControlWord then TextValue:=MacroTemplate(Value);
  if ControlWord and (TextValue=Value) then TextValue:=TextValue+ControlWordSuffix(Value);
  Slot:=Pos('{}',TextValue);
  if (Slot>0) and SelectionRange(A,B) then begin
    WrapSelection(Copy(TextValue,1,Slot),Copy(TextValue,Slot+1,MaxInt)); Exit;
  end;
  if (Slot>0) and FSelected and (N.Text<>'') then begin
    SetSourceSelection(NodeOffset(N),NodeOffset(N)+Length(N.Text));
    WrapSelection(Copy(TextValue,1,Slot),Copy(TextValue,Slot+1,MaxInt)); Exit;
  end;
  Offset:=NodeOffset(N);
  if not FSelected then Inc(Offset,Length(UTF8Copy(N.Text,1,FCaret)));
  ReplaceSelection(TextValue);
  if (Pos('{}',TextValue)=0) and (Pos('[',TextValue)=0) then Exit;
  OptionalField:=-1;
  for I:=0 to FFields.Count-1 do
  begin
    N:=TMathNode(FFields[I]);
    { Empty boundary fields before/after a command are not its arguments. }
    if (NodeOffset(N)<=Offset) or (NodeOffset(N)>=Offset+Length(TextValue)) then Continue;
    Argument:=N.Parent;
    while (Argument<>nil) and not (Argument.Kind in [mkOptional,mkCommand,mkFormula]) do Argument:=Argument.Parent;
    if (Argument<>nil) and (Argument.Kind=mkOptional) then begin
      if OptionalField<0 then OptionalField:=I;
      Continue;
    end;
    if IsEmptyMathArgument(N) or ((N.Text='') and (N.Parent<>nil) and (N.Parent.Parent<>nil) and
      (N.Parent.Parent.Kind=mkGroup)) then begin SelectField(I); Exit; end;
  end;
  if OptionalField>=0 then SelectField(OptionalField);
end;
procedure TMathEditor.InsertSymbol(const Value:string);
begin InsertTeX(TextToTeX(Value)); end;
procedure TMathEditor.InsertStructure(Kind:TMathKind);
var S,V:string; N,P:TMathNode; I,StartOffset,EndOffset:Integer;
begin
  S:=MathTemplate(Kind); N:=CurrentNode;
  if N=nil then Exit;
  StartOffset:=NodeOffset(N);
  if not FSelected then Inc(StartOffset,Length(UTF8Copy(N.Text,1,FCaret)));
  if FSelected then V:=N.Text else V:='';
  if (V<>'') and (Pos('{}',S)>0) then Insert(V,S,Pos('{}',S)+1);
  EndOffset:=StartOffset+Length(S);
  if not InMath then Inc(EndOffset,2);
  if InMath then ReplaceSelection(S) else InsertEquation(S);
  for I:=0 to FFields.Count-1 do
  begin
    N:=TMathNode(FFields[I]); P:=N.Parent;
    if (NodeOffset(N)<StartOffset) or (NodeOffset(N)>EndOffset) then Continue;
    if IsEmptyMathArgument(N) and (P<>nil) and (P.Parent<>nil) and
       (P.Parent.Kind in [mkGroup,mkOptional]) then
    begin SelectField(I); Break; end;
  end;
  FSelected:=True;
end;
procedure TMathEditor.Undo;
var S:string;
begin
  if FUndo.Count=0 then Exit;
  FEmptyScriptStart:=-1;
  FOptionalResumeOffset:=-1; FOptionalCommandStart:=-1; FOptionalTransient:=False; FOptionalBefore:='';
  S:=FUndo[FUndo.Count-1]; FUndo.Delete(FUndo.Count-1); FRedo.Add(FSource);
  FSource:=S; ParseSource; FSelected:=True; Schedule; NotifyChange;
end;
procedure TMathEditor.Redo;
var S:string;
begin
  if FRedo.Count=0 then Exit;
  FEmptyScriptStart:=-1;
  FOptionalResumeOffset:=-1; FOptionalCommandStart:=-1; FOptionalTransient:=False; FOptionalBefore:='';
  S:=FRedo[FRedo.Count-1]; FRedo.Delete(FRedo.Count-1); FUndo.Add(FSource);
  FSource:=S; ParseSource; FSelected:=True; Schedule; NotifyChange;
end;
procedure TMathEditor.ClipboardCommand(Key:Word);
var A,B:Integer; Value,Body,Tail:string; N:TMathNode; Spans:TMathSpans;
begin
  if GeneratedTextActive then begin
    if Key=VK_A then begin FGeneratedAnchor:=0; FGeneratedFocus:=UTF8Length(FGeneratedPreview.RenderedText); Invalidate; end
    else if Key in [VK_C,VK_X] then begin
      if (FGeneratedAnchor>=0) and (FGeneratedAnchor<>FGeneratedFocus) then
        Clipboard.AsText:=FGeneratedPreview.SelectedText(FGeneratedAnchor,FGeneratedFocus)
      else Clipboard.AsText:=FGeneratedPreview.RenderedText;
    end;
    Exit;
  end;
  if CommandActive then
  begin
    case Key of
      VK_A:FCommandEdit.SelectAll;
      VK_C:FCommandEdit.CopyToClipboard;
      VK_X:FCommandEdit.CutToClipboard;
      VK_V:begin
        A:=FCommandEdit.SelStart; B:=FCommandEdit.SelLength; Value:=ReadClipboardText;
        FCommandEdit.Text:=UTF8Copy(FCommandEdit.Text,1,A)+Value+UTF8Copy(FCommandEdit.Text,A+B+1,MaxInt);
        FCommandEdit.SelStart:=A+UTF8Length(Value);
      end;
    end;
    Exit;
  end;
  if (Key in [VK_C,VK_X]) and SelectionRange(A,B) then
  begin
    if SelectingTableCells then Clipboard.AsText:=TableSelectionText
    else WriteVisualClipboard(ProseFragment(FRoot,FSource,A,B),BodyClipboardFragment(FRoot,FSource,A,B,not FParagraph));
    if Key=VK_X then ReplaceSelection(''); Exit;
  end;
  case Key of
    VK_A:begin FSelectionAnchor:=0; SetSourceCaret(Length(FSource)); FSelectionAnchor:=0; Invalidate; end;
    VK_C,VK_X:if CurrentNode<>nil then
      begin
        N:=CurrentNode; A:=MathSourceOffset(N)-Length(N.Prefix); B:=A+Length(N.TeX);
        WriteVisualClipboard(N.TeX,BodyClipboardFragment(FRoot,FSource,A,B,not FParagraph));
        if Key=VK_X then SetFieldText('');
      end;
    VK_V:begin
      if FParagraph and not InMath and not IsCodeField(CurrentNode) and not IsVerbatimField(CurrentNode) then Value:=ReadBodyClipboard
      else Value:=ReadClipboardText;
      if InMath and not InTextArgument and HasVisualClipboard then begin
        Spans:=FindMath(Value);
        if Length(Spans)=1 then begin
          Body:=Copy(Value,1,Spans[0].Start-1);
          Tail:=Copy(Value,Spans[0].Start+Spans[0].Count,MaxInt);
          if (((Body='$') or (Body='$$')) and (Tail=Body)) or
             ((Body='\(') and (Tail='\)')) or ((Body='\[') and (Tail='\]')) then
            Value:=Copy(Value,Spans[0].Start,Spans[0].Count);
        end;
      end;
      ReplaceSelection(Value);
    end;
  end;
end;

{$IFDEF LCLgtk3}
function GTKPrintableKey(Shift:TShiftState; out Text:string):Boolean;
var Event:PGdkEvent;
begin
  Result:=False; Text:='';
  if Shift*[ssCtrl,ssAlt,ssMeta]<>[] then Exit;
  Event:=gtk_get_current_event; if Event=nil then Exit;
  try
    { LCL GTK3 4.0 passes ASCII punctuation as virtual key codes: '(' is
      VK_DOWN, '$' is VK_HOME, etc. Use the native text before navigation
      sees those collisions; actual arrow/function keys have other keyvals. }
    if (Event^.type_=GDK_KEY_PRESS) and
       (Event^.key.keyval in [33..47,58..64,91..96,123..126]) then begin
      Text:=Event^.key.string_; Result:=Text<>'';
    end;
  finally gdk_event_free(Event); end;
end;
{$ENDIF}
procedure TMathEditor.KeyDown(var Key:Word; Shift:TShiftState);
var C:TWinControl; Scroll:TScrollBox; X,Y:Integer; WasNormalizing:Boolean;
    {$IFDEF LCLgtk3}KeyText:string;{$ENDIF}
begin
  {$IFDEF LCLgtk3}
  if GTKPrintableKey(Shift,KeyText) then begin InputText(KeyText); Key:=0; Exit; end;
  {$ENDIF}
  FKeyboardSelecting:=(ssShift in Shift) and (Key in [VK_LEFT,VK_RIGHT,VK_UP,VK_DOWN,VK_HOME,VK_END]);
  Scroll:=nil;
  if FKeyboardSelecting then begin
    C:=Parent;
    while C<>nil do begin
      if C is TScrollBox then Scroll:=TScrollBox(C);
      C:=C.Parent;
    end;
    if Scroll<>nil then begin X:=Scroll.HorzScrollBar.Position; Y:=Scroll.VertScrollBar.Position; end;
  end;
  WasNormalizing:=FNormalizeOptional; FNormalizeOptional:=Key in [VK_BACK,VK_DELETE];
  try
    if FNormalizeOptional and (SourceCaret=FOptionalResumeOffset) then ActivateOptionalArgument;
    ProcessKeyDown(Key,Shift);
  finally
    FNormalizeOptional:=WasNormalizing;
    if Scroll<>nil then SetPreviewScroll(Scroll,X,Y);
    FKeyboardSelecting:=False;
  end;
end;
procedure TMathEditor.ProcessKeyDown(var Key:Word; Shift:TShiftState);
var S:string; N,Adjacent:TMathNode; A,B,Anchor:Integer; Selecting,Handled:Boolean;
begin
  if GeneratedKey(Key,Shift) then Exit;
  if Key=VK_CONTROL then UpdateLinkHover(True);
  if FReadOnly then begin inherited KeyDown(Key,Shift); Exit; end;
  if CommandActive then begin CommandKeyDown(FCommandEdit,Key,Shift); Exit; end;
  if MathShortcutKey(Key,Shift) then Exit;
  if not (Key in [VK_UP,VK_DOWN]) then FVerticalRun:=False;
  Handled:=False;
  if (Key=VK_RETURN) and (CurrentNode<>nil) and (CurrentNode.DefinitionArgument>=0) then begin
    NextField(1); Key:=0; Exit;
  end;
  if (Key=VK_RETURN) and IsDefinitionField(CurrentNode) then begin
    if not InMath or not EditGrid(IfThen(ssShift in Shift,0,1)) then InputText(LineEnding);
    Key:=0; Exit;
  end;
  if Assigned(FDocumentKey) then FDocumentKey(Self,Key,Shift,Handled);
  if Handled then begin Key:=0; Exit; end;
  if Key=VK_ESCAPE then begin Key:=0; if Assigned(FFinish) then FFinish(Self); Exit; end;
  if Key=VK_TAB then begin
    if EditingTable then MoveTable(0,IfThen(ssShift in Shift,-1,1),False)
    else if ssShift in Shift then NextField(-1) else NextField(1);
    Key:=0; Exit;
  end;
  if ssCtrl in Shift then
  begin
    case Key of
      VK_Z:if ssShift in Shift then begin
        if Assigned(FRedoRequested) then FRedoRequested(Self) else Redo;
      end else if Assigned(FUndoRequested) then FUndoRequested(Self) else Undo;
      VK_Y:if Assigned(FRedoRequested) then FRedoRequested(Self) else Redo;
      VK_A,VK_C,VK_X,VK_V:ClipboardCommand(Key);
      VK_OEM_2:InsertStructure(mkFraction);
      VK_HOME,VK_END:begin
        Anchor:=FSelectionAnchor; if Anchor<0 then Anchor:=SourceCaret;
        if Key=VK_HOME then SetSourceCaret(0)
        else if FParagraph then SetSourceCaret(Length(TrimRight(FSource))) else SetSourceCaret(Length(FSource));
        if ssShift in Shift then SetSourceSelection(Anchor,SourceCaret);
      end;
      else begin inherited KeyDown(Key,Shift); Exit; end;
    end;
    Key:=0; Exit;
  end;
  N:=CurrentNode; if N=nil then Exit;
  Selecting:=(ssShift in Shift) and (Key in [VK_LEFT,VK_RIGHT,VK_UP,VK_DOWN,VK_HOME,VK_END]);
  Anchor:=FSelectionAnchor; if Anchor<0 then Anchor:=SourceCaret;
  if (Key in [VK_BACK,VK_DELETE]) and SelectionRange(A,B) then
  begin ReplaceSelection(''); Key:=0; Exit; end;
  if (Key in [VK_BACK,VK_DELETE]) and not FSelected and DeleteVerbatim(Key) then begin Key:=0; Exit; end;
  if (Key=VK_RETURN) and IsVerbatimField(N) then begin
    Adjacent:=N; while (Adjacent<>nil) and (Adjacent.Kind<>mkVerbatim) do Adjacent:=Adjacent.Parent;
    if Adjacent<>nil then begin
      if not SelectionRange(A,B) then begin A:=SourceCaret; B:=A; end;
      Commit(Copy(FSource,1,A)+LineEnding+Copy(FSource,B+1,MaxInt),A+Length(LineEnding));
    end;
    Key:=0; Exit;
  end;
  if (Key=VK_RETURN) and IsCodeField(N) then begin InputText(LineEnding); Key:=0; Exit; end;
  if (Key=VK_RETURN) and IsLabelField(N) then begin NextField(1); Key:=0; Exit; end;
  if EditingTable and not ((Key in [VK_UP,VK_DOWN]) and
    (FractionNeighbor(IfThen(Key=VK_UP,-1,1))<>nil)) then begin
    if ((Key=VK_UP) and MoveTable(-1,0,False)) or
       ((Key=VK_DOWN) and MoveTable(1,0,False)) or
       ((Key=VK_LEFT) and not Selecting and MoveTable(0,-1,True)) or
       ((Key=VK_RIGHT) and not Selecting and MoveTable(0,1,True)) then begin
      if Selecting then begin SetSourceSelection(Anchor,SourceCaret); if Assigned(FDocumentGesture) then FDocumentGesture(Self,Point(0,0),3,Shift); end;
      Key:=0; Exit;
    end;
    if Key=VK_TAB then begin MoveTable(0,IfThen(ssShift in Shift,-1,1),False); Key:=0; Exit; end;
    if Key=VK_RETURN then begin EditTable(1); Key:=0; Exit; end;
  end;
  if Key in [VK_LEFT,VK_RIGHT,VK_UP,VK_DOWN,VK_HOME,VK_END,VK_BACK,VK_DELETE,VK_RETURN] then
  begin
    if not Selecting then FSelectionAnchor:=-1;
    FSelectionFocus:=-1;
  end;
  if (Key in [VK_RETURN,VK_BACK,VK_DELETE]) and not InMath and EditList(Key) then begin Key:=0; Exit; end;
  if (Key=VK_BACK) and not FSelected and DeleteEmptyFormula then begin Key:=0; Exit; end;
  if (Key=VK_BACK) and not FSelected and SelectPreviousCommand then begin Key:=0; Exit; end;
  if (Key=VK_BACK) and not FSelected and DeleteStructure then begin Key:=0; Exit; end;
  if (Key=VK_BACK) and not FSelected and DeletePreviousMacro then begin Key:=0; Exit; end;
  if FParagraph and not InMath and Assigned(FBoundary) and not FSelected then
  begin
    if (Key in [VK_LEFT,VK_BACK]) and (Trim(Copy(FSource,1,SourceCaret))='') then
    begin FBoundary(Self,-1,Key=VK_BACK); Key:=0; Exit; end;
    if (Key in [VK_RIGHT,VK_DELETE]) and (Trim(Copy(FSource,SourceCaret+1,MaxInt))='') then
    begin FBoundary(Self,1,Key=VK_DELETE); Key:=0; Exit; end;
  end;
  case Key of
    VK_RETURN:begin
      if InMath and EditGrid(IfThen(ssShift in Shift,0,1)) then begin Key:=0; Exit; end;
      if BreakEnvironmentLine(ssShift in Shift) then begin Key:=0; Exit; end;
      if FParagraph and not InMath and Assigned(FParagraphBreak) then FParagraphBreak(Self)
      else NextField(1);
    end;
    VK_UP,VK_DOWN:begin
      if not MoveVertical(IfThen(Key=VK_UP,-1,1)) and Assigned(FBoundary) then
        FBoundary(Self,IfThen(Key=VK_UP,-1,1),False);
    end;
    VK_LEFT:MoveHorizontal(-1);
    VK_RIGHT:MoveHorizontal(1);
    VK_HOME:MoveLineEdge(False);
    VK_END:MoveLineEdge(True);
    VK_BACK,VK_DELETE:
      begin
        if FSelected then SetFieldText('')
        else begin
          if (N.Kind in [mkProse,mkText,mkTextCommand]) and (Key=VK_BACK) and (FCaret=0) and (FActive>0) then
          begin
            Adjacent:=TMathNode(FFields[FActive-1]);
            if (Adjacent.Kind in [mkProse,mkText,mkTextCommand]) and (NodeOffset(Adjacent)+Length(Adjacent.Text)=NodeOffset(N)) then
            begin Dec(FActive); N:=Adjacent; FCaret:=UTF8Length(N.Text); end;
          end;
          if (N.Kind in [mkProse,mkText,mkTextCommand]) and (Key=VK_DELETE) and (FCaret=UTF8Length(N.Text)) and (FActive<FFields.Count-1) then
          begin
            Adjacent:=TMathNode(FFields[FActive+1]);
            if (Adjacent.Kind in [mkProse,mkText,mkTextCommand]) and (NodeOffset(N)+Length(N.Text)=NodeOffset(Adjacent)) then
            begin Inc(FActive); N:=Adjacent; FCaret:=0; end;
          end;
          S:=N.Text;
          if UnitTokenAt(FCaret+IfThen(Key=VK_BACK,-1,1),A,B) then begin
            UTF8Delete(S,A+1,B-A); ApplyField(S,A); Key:=0; Exit;
          end;
          if (N.Kind in [mkTextCommand,mkCommand]) and
             (((Key=VK_BACK) and (FCaret>0)) or ((Key=VK_DELETE) and (FCaret<UTF8Length(S)))) then
          begin S:=''; FCaret:=0; end
          else if (N.Kind=mkProse) and not IsVerbatimField(N) and not IsCodeField(N) and
            (((Key=VK_BACK) and (FCaret>0) and (UTF8Copy(S,FCaret,1)[1] in [' ',#9,#10,#13])) or
             ((Key=VK_DELETE) and (FCaret<UTF8Length(S)) and (UTF8Copy(S,FCaret+1,1)[1] in [' ',#9,#10,#13]))) then
          begin
            A:=FCaret; B:=FCaret;
            while (A>0) and (UTF8Copy(S,A,1)[1] in [' ',#9,#10,#13]) do Dec(A);
            while (B<UTF8Length(S)) and (UTF8Copy(S,B+1,1)[1] in [' ',#9,#10,#13]) do Inc(B);
            UTF8Delete(S,A+1,B-A); FCaret:=A;
          end
          else if (Key=VK_BACK) and (FCaret>0) then
          begin UTF8Delete(S,FCaret,1); Dec(FCaret); end
          else if Key=VK_DELETE then UTF8Delete(S,FCaret+1,1);
          ApplyField(S,FCaret);
        end;
      end;
    else begin inherited KeyDown(Key,Shift); Exit; end;
  end;
  if Selecting then
  begin
  FSelectionAnchor:=Anchor; FSelectionFocus:=-1;
    if Assigned(FDocumentGesture) then FDocumentGesture(Self,Point(0,0),3,Shift);
  end;
  Key:=0; Invalidate;
end;
procedure TMathEditor.UTF8KeyPress(var UTF8Key:TUTF8Char);
begin
  InputText(UTF8Key); UTF8Key:='';
end;
procedure TMathEditor.InputText(const AText:string);
var Value,Escaped,Ch,Command:string; Handled,WasNormalizing:Boolean; A,B,I,P:Integer; N:TMathNode; Key:Word;
begin
  if MathShortcutText(AText) then Exit;
  WasNormalizing:=FNormalizeOptional; FNormalizeOptional:=True;
  try
  if GeneratedTextActive then Exit;
  if FReadOnly then Exit;
  if not CommandActive and not SelectionRange(A,B) then ActivateOptionalArgument;
  N:=CurrentNode;
  P:=1; Command:=''; if N<>nil then Command:=ReadTeXCommand(N.Text,P);
  if (N<>nil) and IsGeneratedCommand(Command) and not IsCodeField(N) then begin
    if FSelected or SelectionRange(A,B) then Exit;
  end;
  FVerticalRun:=False; Value:=AText; Handled:=False;
  if not CommandActive and Assigned(FDocumentText) and not IsDefinitionField(N) then FDocumentText(Self,Value,Handled);
  if Handled then Exit;
  if CommandActive then
  begin
    if (Value=' ') or (Value=#10) or (Value=#13) then begin
      Key:=VK_RETURN; if Value=' ' then Key:=VK_SPACE;
      CommandKeyDown(FCommandEdit,Key,[]);
    end
    else begin
      { GTK3 does not implement the native SelText replacement used by LCL.
        Replace the UTF-8 range explicitly and retain the command caret. }
      B:=FCommandEdit.SelLength; A:=FCommandEdit.SelStart;
      { GTK3 reports SelStart=0 when nothing is selected. }
      if B=0 then A:=FCommandEdit.CaretPos.X;
      A:=EnsureRange(A,0,UTF8Length(FCommandEdit.Text));
      FCommandFinishing:=True;
      try
        FCommandEdit.Text:=UTF8Copy(FCommandEdit.Text,1,A)+Value+UTF8Copy(FCommandEdit.Text,A+B+1,MaxInt);
        FCommandEdit.SelStart:=A+UTF8Length(Value); FCommandEdit.SelLength:=0;
      finally FCommandFinishing:=False; end;
      CommandChanged(FCommandEdit);
    end;
    Exit;
  end;
  if (N<>nil) and (N.DefinitionArgument>=0) then begin
    if not SelectionRange(A,B) then begin A:=SourceCaret; B:=A; end;
    I:=MathSourceOffset(N);
    if (A>=I) and (B<=I+Length(N.Text)) then begin
      Value:=Copy(N.Text,1,A-I)+Value+Copy(N.Text,B-I+1,MaxInt);
      ApplyField(Value,UTF8Length(Copy(N.Text,1,A-I))+UTF8Length(AText)); Exit;
    end;
  end;
  if IsCodeField(CurrentNode) or (NativeUnitField and (Value<>'\') and not ((Value=' ') and InMath)) then begin
    if NativeUnitField then Value:=StringReplace(Value,'%','\%',[rfReplaceAll]);
    if not SelectionRange(A,B) then begin A:=SourceCaret; B:=A; end;
    Commit(Copy(FSource,1,A)+Value+Copy(FSource,B+1,MaxInt),A+Length(Value)); Exit;
  end;
  if IsLabelField(CurrentNode) then begin
    if Value=' ' then begin if not MathSpace then NextField(1); Exit; end;
    if (Value<>'') and (Ord(Value[1])>=33) and (Value<>'{') and (Value<>'}') and (Value<>'\') then begin
      if not SelectionRange(A,B) then begin A:=SourceCaret; B:=A; end;
    Commit(Copy(FSource,1,A)+Value+Copy(FSource,B+1,MaxInt),A+Length(Value));
    end;
    Exit;
  end;
  if IsVerbatimField(CurrentNode) then begin
    N:=CurrentNode;
    if not SelectionRange(A,B) and (FCaret=UTF8Length(N.Text)) and
       (N.Parent<>nil) and (Value=N.Parent.Suffix) then begin
      SetSourceCaret(SourceCaret+Length(Value)); Exit;
    end;
    if (Value<>'') and (Ord(Value[1])>=32) then begin
      if not SelectionRange(A,B) then begin A:=SourceCaret; B:=A; end;
    Commit(Copy(FSource,1,A)+Value+Copy(FSource,B+1,MaxInt),A+Length(Value));
    end;
    Exit;
  end;
  if (Value=' ') and not SelectionRange(A,B) and MathSpace then Exit;
  if Value='\' then begin BeginCommand; Exit; end;
  if (Value='{') and ((InMath and not InTextArgument) or
     SelectionRange(A,B)) then
  begin ReplaceSelection('{'); Exit; end;
  if InMath and not InTextArgument and (Value='}') and (Copy(FSource,SourceCaret+1,1)='}') then
  begin SetSourceCaret(SourceCaret+1); Exit; end;
  if (FParagraph and not InMath) or InTextArgument then begin
    Escaped:='';
    for I:=1 to UTF8Length(Value) do begin
      Ch:=UTF8Copy(Value,I,1);
      case Ch of
        '%':Ch:='\%'; '&':Ch:='\&'; '#':if not IsDefinitionField(N) then Ch:='\#';
        '_':Ch:='\_'; '^':Ch:='\textasciicircum{}';
        '$':Ch:='\$'; '{':Ch:='\{'; '}':Ch:='\}';
        '<':Ch:='\textless{}'; '>':Ch:='\textgreater{}'; '|':Ch:='\textbar{}';
      end;
      Escaped:=Escaped+Ch;
    end;
    Value:=Escaped;
  end else Value:=StringReplace(Value,'%','\%',[rfReplaceAll]);
  if (Value<>'') and (Ord(Value[1])>=32) then ReplaceSelection(Value);
  finally FNormalizeOptional:=WasNormalizing; end;
end;
procedure TMathEditor.FieldNames(Dest:TStrings);
var I:Integer; N,P:TMathNode; S:string;
begin
  Dest.Clear;
  for I:=0 to FFields.Count-1 do
  begin
    N:=TMathNode(FFields[I]); S:=N.TeX; P:=N.Parent;
    while P<>nil do
    begin if P.Kind=mkCommand then begin S:=P.Text+' argument: '+S; Break; end; P:=P.Parent; end;
    Dest.Add(IntToStr(I+1)+': '+S);
  end;
end;
procedure TMathEditor.MacroNames(Dest:TStrings);
begin LoadRegistry; FRegistry.Names(Dest); end;
function TMathEditor.MacroTemplate(const MacroName:string):string;
var M:TMacroInfo; I,N:Integer; S:string; Scope:TMacroRegistry;
begin
  LoadRegistry;
  S:=MacroName; if (S<>'') and (S[1]='\') then Delete(S,1,1);
  Scope:=FRegistry.Clone;
  try
    if FParagraph then Scope.ApplyDefinitions(Copy(FSource,1,SourceCaret));
    M:=Scope.Find(S); Result:='\'+S; N:=MathArgumentCount(S);
    if Scope.Presentation and (BeamerArgumentCount(S)>=0) then begin
      for I:=1 to BeamerArgumentCount(S) do Result:=Result+'{}'; Exit;
    end;
    if IsExtensibleMathArrow(S) and ((M=nil) or (M.PackageSource<>'')) then Exit('\'+S+'[]{}');
    if M<>nil then begin
      for I:=1 to M.ArgCount do
        if M.ArgumentKind(I,S) in ['o','O'] then begin
          if S='\NoValue' then S:='';
          Result:=Result+'['+S+']';
        end else Result:=Result+'{}';
      Exit;
    end;
  finally Scope.Free; end;
  if N<0 then Exit;
  for I:=1 to N do Result:=Result+'{}';
end;
finalization
  PreviewMeasureBitmap.Free;
end.
