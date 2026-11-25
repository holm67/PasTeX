unit MainForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, LResources, Contnrs, IniFiles, RibbonIcons, PlatformLibraries, DocumentOutline, Spin, ToolDialogs, ObjectDialogs, DiagramForm, FullSourceForm, PreambleForm, PreambleModel, BibliographyForm, MathCommands, TeXProject, LinkedSource, EditablePreamble, TeXTextStyle, TextSelectionStyle, TeXStyles, SourceRanges, SourceFonts, SourceStyle, SourceCompletion, TeXDocumentMetrics, TeXBibliography, TeXTables, TeXEditing, ParagraphModel, ProseEditing, UITheme, SettingsForm, AboutForm, SynEditTextBuffer, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  ComCtrls, ImgList, Menus, Buttons, Clipbrd, Types, LCLType, LCLIntf, LCLProc, LazUTF8, Math, MathModel, MathSelection, MathEditor, TeXMacros, CommandDefinition, DefinitionForm, TeXFontData, NativeTeXGlyphs, TeXContext, PreviewImage, GeneratedPreview, VectorPreview, DiagramPreview, QuickAccessForm, DocumentInfo, SynEdit, SourceLinkMarkup, SynEditWrappedView, SynEditKeyCmds, SynEditTypes, SynHighlighterTeX, TeXDocument, TeXRenderer, FormulaRender, EditorStatus, PagedView, SourcePDFView;

type
  TPluginToggle=class(TCheckBox)
  public
    StatePackage:string;
  end;
  TPluginActionButton=class(TActionGlyphButton)
  public
    RequiredPackage:string;
    ToolAvailable:Boolean;
  end;
  TStatusLabel=class(TLabel)
  protected
    procedure DoDrawText(var Bounds:TRect; Flags:Longint); override;
  end;
  TDocumentSnapshot = class
    Blocks:TStringList;
    Preamble,Ending:string;
    PreambleOnly:Boolean;
    BlockIndex,Caret:Integer;
    constructor Create(Document:TTeXDocument; Index,Offset:Integer);
    destructor Destroy; override;
  end;

  TParagraphCard = record
    Panel: TPanel;
    Image: TPreviewImage;
    Draft:TMathEditor;
    SourceKey,LayoutXML,Positions,ContextSource,Declarations:string;
    LayoutPage,PreviewState,DocumentTop,MeasuredHeight:Integer;
    SelectionModel:TParagraphSelection;
    Folded,PartlyFolded:Boolean;
  end;
  TParagraphCards=array of TParagraphCard;
  TPreviewAnchor=record
    Block,Horizontal,Position,CaretY:Integer;
    Offset:Double;
    UseCaret:Boolean;
  end;
  TOpenDocument=class
    Document:TTeXDocument;
    Linked:TLinkedSource;
    ReloadLinked:Boolean;
    PreviewContext:TTeXContext;
    Undo,Redo:TObjectList;
    Cards:TParagraphCards;
    Wrapped,Plain,Editor:TSynEdit;
    WrapPlugin:TLazSynEditLineWrapPlugin;
    Parking:TPanel;
    FileName,RootName,CacheContext,LastLog:string;
    Modified,Visual,NeedsPreview,PreambleExpanded,PluginSource,PageMode:Boolean;
    PluginText,FormatID,FormatName,SourceExtension:string;
    ObservedSource:string;
    ActiveBlock,Anchor,Focus,ScrollX,ScrollY,EngineIndex,SourceHeight:Integer;
    constructor Create;
    destructor Destroy; override;
  end;

  TMainForm = class(TForm)
  published
    QuickAccessBar: TPanel;
    QuickUndoButton: TSpeedButton;
    QuickRedoButton: TSpeedButton;
    QuickSaveButton: TSpeedButton;
    Ribbon: TPageControl;
    HomeTab: TTabSheet;
    InsertTab: TTabSheet;
    EquationTab: TTabSheet;
    ViewTab: TTabSheet;
    HomeFileGroup: TGroupBox;
    HomeFileNewButton: TBitBtn;
    HomeFileOpenButton: TBitBtn;
    HomeFileSaveButton: TBitBtn;
    HomeEditingGroup: TGroupBox;
    HomeEditingUndoButton: TBitBtn;
    HomeEditingRedoButton: TBitBtn;
    HomeEditingCutButton,HomeEditingCopyButton,HomeEditingPasteButton,HomeEditingSelectallButton:TBitBtn;
    HomeTextGroup: TGroupBox;
    HomeTextBoldButton: TSpeedButton;
    HomeTextItalicButton: TSpeedButton;
    HomeTextHeadingButton: TBitBtn;
    HomeModeGroup: TGroupBox;
    HomeModeSourceButton: TBitBtn;
    HomeModeEquationButton: TBitBtn;
    HomeModePreviewButton: TBitBtn;
    InsertDocumentGroup: TGroupBox;
    InsertDocumentParagraphButton: TBitBtn;
    InsertDocumentInsertequationButton: TBitBtn;
    InsertStructureGroup: TGroupBox;
    InsertStructureFractionButton: TBitBtn;
    InsertStructureSquarerootButton: TBitBtn;
    InsertStructureSuperscriptButton: TBitBtn;
    InsertStructureSubscriptButton: TBitBtn;
    EquationStructureGroup: TGroupBox;
    EquationStructureFractionButton: TBitBtn;
    EquationStructureSquarerootButton: TBitBtn;
    EquationStructureSuperscriptButton: TBitBtn;
    EquationStructureSubscriptButton: TBitBtn;
    EquationSymbolGroup: TGroupBox;
    EquationSymbolAlphaButton: TBitBtn;
    EquationSymbolBetaButton: TBitBtn;
    EquationSymbolPiButton: TBitBtn;
    EquationSymbolSumButton: TBitBtn;
    EquationSymbolIntegralButton: TBitBtn;
    EquationSymbolInfinityButton: TBitBtn;
    EquationChoiceGroup: TGroupBox;
    EquationFieldGroup: TGroupBox;
    EquationTemplateGroup: TGroupBox;
    EquationMacroGroup: TGroupBox;
    ViewDocumentGroup: TGroupBox;
    ViewDocumentPreviewButton: TBitBtn;
    ViewDocumentDocumentsettingsButton: TBitBtn;
    ViewDocumentCompilerlogButton: TBitBtn;
    EngineGroup: TGroupBox;
    EquationActionsButton:TSpeedButton;
    EquationSelector: TComboBox;
    FieldSelector: TComboBox;
    TemplateSelector: TComboBox;
    MacroSelector: TComboBox;
    Engine: TComboBox;
    Scroll: TScrollBox;
    Status: TPanel;
    FileTabs:TTabControl;
    ZoomControls:TPanel;
    StatusZoom:TTrackBar;
    StatusZoomLabel:TLabel;
    Editor: TSynEdit;
    FormulaBox: TScrollBox;
    AppMenu: TMainMenu;
    FileMenu: TMenuItem;
    NewMenuItem: TMenuItem;
    OpenMenuItem: TMenuItem;
    SaveMenuItem: TMenuItem;
    SaveAsMenuItem: TMenuItem;
    FileSeparator: TMenuItem;
    ExitMenuItem: TMenuItem;
    EditMenu: TMenuItem;
    UndoMenuItem: TMenuItem;
    RedoMenuItem: TMenuItem;
    EditSeparator: TMenuItem;
    CutMenuItem: TMenuItem;
    CopyMenuItem: TMenuItem;
    PasteMenuItem: TMenuItem;
    SelectAllMenuItem: TMenuItem;
    FormatMenu: TMenuItem;
    BoldMenuItem: TMenuItem;
    ItalicMenuItem: TMenuItem;
    HeadingMenuItem: TMenuItem;
    NormalTextMenuItem:TMenuItem;
    SectionMenuItem,SubsectionMenuItem,SubsubsectionMenuItem:TMenuItem;
    SectionStarMenuItem,SubsectionStarMenuItem,SubsubsectionStarMenuItem:TMenuItem;
    SourceWrapMenuItem:TMenuItem;
    SourceWrapButton:TSpeedButton;
    InsertMenu: TMenuItem;
    ParagraphMenuItem: TMenuItem;
    EquationMenuItem: TMenuItem;
    InsertSeparator: TMenuItem;
    StructuresMenu: TMenuItem;
    FractionMenuItem: TMenuItem;
    RootMenuItem: TMenuItem;
    SuperscriptMenuItem: TMenuItem;
    SubscriptMenuItem: TMenuItem;
    TemplatesMenu: TMenuItem;
    TemplatesPlaceholder: TMenuItem;
    SymbolsMenu: TMenuItem;
    Symbol0MenuItem: TMenuItem;
    Symbol1MenuItem: TMenuItem;
    Symbol2MenuItem: TMenuItem;
    Symbol3MenuItem: TMenuItem;
    Symbol4MenuItem: TMenuItem;
    Symbol5MenuItem: TMenuItem;
    MacrosMenu: TMenuItem;
    MacrosPlaceholder: TMenuItem;
    NavigateMenu: TMenuItem;
    FormulaMenu: TMenuItem;
    FormulaPlaceholder: TMenuItem;
    FieldMenu: TMenuItem;
    FieldPlaceholder: TMenuItem;
    ViewMenu: TMenuItem;
    VisualMenuItem: TMenuItem;
    SourceMenuItem: TMenuItem;
    PreviewMenuItem: TMenuItem;
    ViewSeparator: TMenuItem;
    SettingsMenuItem: TMenuItem;
    LogMenuItem: TMenuItem;
    EngineMenu: TMenuItem;
    EnginePlaceholder: TMenuItem;
    Highlighter: TSynTeXSyn;
    Timer: TTimer;

    procedure ClipboardClick(Sender: TObject);
    procedure ContextPopup(Sender:TObject);
    procedure ContextEditClick(Sender:TObject);
    procedure OpenBibliography(Sender:TObject);
    procedure ExitClick(Sender: TObject);
    procedure PopulateSelectorMenu(Sender: TObject);
    procedure SelectorMenuClick(Sender: TObject);
    procedure AddClick(Sender: TObject);
    procedure Closing(Sender: TObject; var CanClose: Boolean);
    procedure EditorChanged(Sender: TObject);
    procedure EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure EngineChanged(Sender: TObject);
    procedure EquationModeClick(Sender: TObject);
    procedure EquationSelected(Sender: TObject);
    procedure FieldSelected(Sender: TObject);
    procedure FormatClick(Sender: TObject);
    procedure HeadingClick(Sender:TObject);
    procedure SourceWrapClick(Sender:TObject);
    procedure InsertEquationClick(Sender: TObject);
    procedure EquationActionsClick(Sender:TObject);
    procedure EquationActionClick(Sender:TObject);
    procedure LayoutCards(Sender: TObject);
    function CapturePreviewAnchor:TPreviewAnchor;
    procedure RestorePreviewAnchor(const Anchor:TPreviewAnchor);
    procedure LogClick(Sender: TObject);
    procedure MacroSelected(Sender: TObject);
    procedure NewClick(Sender: TObject);
    procedure OpenClick(Sender: TObject);
    procedure PreambleClick(Sender: TObject);
    procedure FormattingAction(Sender:TObject);
    procedure PreviewClick(Sender: TObject);
    procedure RedoClick(Sender: TObject);
    procedure SaveAsClick(Sender: TObject);
    procedure SaveClick(Sender: TObject);
    procedure SourceModeClick(Sender: TObject);
    procedure StructureClick(Sender: TObject);
    procedure SymbolClick(Sender: TObject);
    procedure TemplateSelected(Sender: TObject);
    procedure Tick(Sender: TObject);
    procedure UndoClick(Sender: TObject);
    procedure WindowActivated(Sender: TObject);
    procedure WindowDeactivated(Sender: TObject);
    procedure StatusZoomChanged(Sender:TObject);
  private
    FFocusMode,FFocusNavigation,FFocusRibbon,FFocusQuick,FFocusTabs:Boolean;
    FFocusState:TWindowState;
    FFocusBounds:TRect;
    FFocusExit:TSpeedButton;
    procedure InitExtendedWorkspace;
    procedure FocusModeClick(Sender:TObject);
    procedure PagedViewClick(Sender:TObject);
    function RestoreContinuousWorkspace:Integer;
    procedure ContinuousViewClick(Sender:TObject);
    procedure PagedSourceChanged(Sender:TObject);
    procedure PagedSelectionChanged(Sender:TObject);
  private
    FPagedView:TPagedEditor;
    FPageHistoryStarted:Boolean;
    FPluginSourcePane:TPanel;
    FPluginSourceSplit:TSplitter;
    FPluginSourceDue:QWord;
    FFormatMenu:TMenuItem;
    procedure RefreshDocumentFormatMenus;
    procedure FormatPluginSelection(const Command:string);
    function PluginSourceActive:Boolean;
    procedure ShowPluginSourceEditor;
    procedure RefreshPluginSource;
    procedure ExportPluginTeX(Sender:TObject);
  private
    FAddonsTab:TTabSheet;
    FAddonsRow:TScrollBox;
    FAddonScroll:array[0..1] of TActionGlyphButton;
    FToolPanel,FStatusActions:TPanel;
    FToolProgress:TProgressBar;
    FToolMessage:string;
    FToolMessageUntil:QWord;
    FCloseAfterTool:Boolean;
    procedure ToolStatus(const Title:string; Running:Boolean);
    procedure CancelToolClick(Sender:TObject);
    procedure CloseAfterTool(Data:PtrInt);
    procedure RefreshAddonsRibbon;
    procedure RefreshAddonChecks;
    procedure ScrollAddons(Sender:TObject);
    procedure ResizeAddons(Sender:TObject);
    procedure WheelAddons(Sender:TObject; Shift:TShiftState; WheelDelta:Integer; MousePos:TPoint; var Handled:Boolean);
    procedure AddonActionClick(Sender:TObject);
    procedure AddonMenuClick(Sender:TObject);
    procedure AddonsClick(Sender:TObject);
    procedure ShortcutsClick(Sender:TObject);
    procedure ImportDataClick(Sender:TObject);
    procedure ImportDocumentClick(Sender:TObject);
    procedure OpenPluginDocumentClick(Sender:TObject);
    procedure NewPluginDocumentClick(Sender:TObject);
    procedure OpenPluginSource(const Path:string; const FormatID:string='');
    procedure ExportProjectClick(Sender:TObject);
    procedure FootnoteClick(Sender:TObject);
    procedure InsertBodySource(const Value:string);
    function EditingMath:Boolean;
  private
    FSessions:TObjectList;
    FSessionIndex:Integer;
    FSwitchingDocument:Boolean;
    FPreviewLayoutDeadline:QWord;
    FDragTab:Integer;
    FDragTabOrigin:TPoint;
    FClosingTab:TOpenDocument;
    FPressedCloseTab:Integer;
    FTabCloseImages:TImageList;
    FLinkedPath,FLinkedRoot:string;
    TabMoveLeft,TabMoveRight:TMenuItem;
    FEffectivePreamble,FProjectBefore,FProjectAfter,FSourceFontPreference:string;
    FDiagramRevision:QWord;
    FormulaSourceButton:TSpeedButton;
    DuplicateMathRowButton,DuplicateMathColumnButton:TSpeedButton;
    FPermanentAvailable,FRealtimeCompile,FManualPreview,FCompilerAvailable:Boolean;
    FPreambleFields:TEditablePreamble;
    FFieldsRevision:QWord;
    FPreambleRefreshDue,FMemoryTrimDue,FDocumentRefreshDue:QWord;
    FPreamblePanel,FBodySeparator,FPreambleToggle:TPreviewPanel;
    FSourceStyles:TTeXStyles;
    FPreambleEditing,FPreviewOnly,FPreambleExpanded:Boolean;
    function PreambleContentVisible:Boolean;
    function PreambleAvailable:Boolean;
    procedure SetPreambleExpanded(Value:Boolean);
    procedure TogglePreamble(Sender:TObject);
    procedure UpdatePreambleVisibility(ScrollPosition:Integer);
    procedure RefreshPreambleEditor;
    procedure PreambleChanged(Sender:TObject);
    procedure PreambleSelected(Sender:TObject);
    procedure PreambleBoundary(Sender:TObject; Direction:Integer; Merge:Boolean);
    procedure RefreshFontControls;
    procedure UpdateFontControls(const Selection:TTeXTextSelection);
    procedure UpdateParagraphControl(const Style:string);
    function CurrentVisualEditor:TMathEditor;
    procedure InitDocumentTabs;
    procedure StoreDocumentTab;
    procedure FileTabChanged(Sender:TObject);
    procedure FileTabCloseClicked(Sender:TObject);
    procedure CloseFileTabAsync(Data:PtrInt);
    procedure CloseFileTab(Sender:TObject);
    procedure FileTabImage(Sender:TObject; TabIndex:Integer; var ImageIndex:Integer);
    procedure UpdateFileTabCloseIcon;
    function FileTabCloseHit(X,Y:Integer):Integer;
    procedure FileTabMouseDown(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
    procedure FileTabMouseMove(Sender:TObject; Shift:TShiftState; X,Y:Integer);
    procedure FileTabMouseUp(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
    procedure FileTabPopup(Sender:TObject);
    procedure MoveFileTabClick(Sender:TObject);
    function QueueLinkedFile(const Source:string; Offset:Integer):Boolean;
    procedure OpenLinkedFileAsync(Data:PtrInt);
    procedure SourceMouseDown(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
    procedure VisualLinkClick(Sender:TObject; Offset:Integer; var Handled:Boolean);
    procedure PreviewDoubleClick(Sender:TObject);
    procedure CloseFileClick(Sender:TObject);
    procedure SaveAllClick(Sender:TObject);
    procedure OpenLinkedFiles(Sender:TObject);
    procedure OpenRootClick(Sender:TObject);
    function Project:TTeXProject;
    function DocumentDirectory:string;
    procedure NotifyProjectChanged;
    procedure GuideClick(Sender:TObject);
    procedure RefreshProjectContext;
    function PreviewSnapshot:string;
    procedure UpdateSourceFonts;
    function SyncDocumentPackages(const Body:string):string;
    procedure UpdatePreviewCards(State:Integer);
    function LinkedProject:TLinkedSource;
    function FileDocumentSource(Session:TOpenDocument):string;
    function SyncLinkedSource:Boolean;
    procedure LinkedSourceReady(Data:PtrInt);
    procedure ToggleInlineSubfiles(Sender:TObject);
    procedure SaveLinkedProject(const Path:string);
  private
    FSyncingLinked,FLinkedRefreshQueued,FRestoreInlineSubfiles:Boolean;
    FInlineSubfilesCheck:TCheckBox;
    FLinkedBoundaries:TSourceBoundaries;
    FFoldedSources:TSourceRanges;
    FSubfileTogglePath,FSubfileToggleRoot:string;
    FLinkedBoundaryPanels:array of TPreviewPanel;
    procedure ToggleSubfileReady(Data:PtrInt);
    procedure UpdateLinkedBoundaries;
    procedure PlaceLinkedBoundaries(Block:Integer; Ending:Boolean; var Y:Integer; X,AWidth:Integer);
    procedure SubfileBoundaryClick(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
  private
    FNavigation:TPanel;
    FNavigationTree:TTreeView;
    FNavigationMenu:TMenuItem;
    FViewRibbon:TTabSheet;
    FNavigationCheck:TCheckBox;
    FOutline:TOutlineEntries;
    FNavigationRevision:Integer;
    FPDFWorker:TRenderThread;
    FPDFDestination,FPDFPath,FGeneratedCommand:string;
    FGeneratedTarget:Integer;
    FGeneratedConfigure:Boolean;
    procedure GeneratedAction(Sender:TObject; const Command:string; Target:Integer; Configure:Boolean);
    procedure GeneratedActionReady(Data:PtrInt);
    procedure InitWorkspace;
    procedure ToggleNavigation(Sender:TObject);
    procedure RefreshNavigation;
    procedure NavigateToSource(Offset:Integer);
    procedure NavigateOutline(Sender:TObject; Node:TTreeNode);
    procedure OpenSubfileClick(Sender:TObject);
    procedure WorkspaceKeyDown(Sender:TObject; var Key:Word; Shift:TShiftState);
    procedure ToggleMathSelection(Sender:TObject);
    procedure SelectionSourceClick(Sender:TObject);
    procedure DefineCommandClick(Sender:TObject);
    procedure RenewCommandClick(Sender:TObject);
    procedure DeclareOperatorClick(Sender:TObject);
    procedure InsertCommandDefinition(const Kind:string);
    function NativeDocumentSource:string;
    procedure StartPDF(const Destination:string);
    procedure ExportPDF(Sender:TObject);
    procedure PreviewPDF(Sender:TObject);
    procedure CompletePDF;
  private
    ToolPopups:array[0..7] of TPopupMenu;
    HistoryPopup:TPopupMenu;
    AppearanceChoice,ZoomChoice:TComboBox;
    FUpdatingRibbon,FApplyingSettings,FSourceLayoutQueued:Boolean;
    FPreviewPercent,FSourceHeight,FSourceDragY,FSourceDragHeight:Integer;
    FLayoutZoom:Double;
    FScaleClamped:Boolean;
    FClampAnchor,FClampPosition,FClampBlock:Integer;
    FClampOffset:Double;
    FUpdatingZoom,FFitWidth,FFitPage:Boolean;
    FPreviewMarginRevision,FPreviewMarginLeft,FPreviewMarginRight:Integer;
    FQuickOrder,FQuickCatalog:TStringList;
    FCommandSearchButton:TSpeedButton;
    FRibbonFullHeight:Integer;
    FRibbonCollapsed:Boolean;
    FStatusModes:array[0..4] of TSpeedButton;
    FQuickWidth:Integer;
    FQuickOverflow:TSpeedButton;
    FQuickMenu:TPopupMenu;
    FStatusCache:TEditorStatusCache;
    FStatusPopup:TPopupMenu;
    FStatusDetails:TPanel;
    FStatusTrail,FStatusMetrics:TLabel;
    FStatusShow:array[0..3] of Boolean;
    FSourceCommandPath:string;
    procedure InitStatusBar;
    procedure UpdateStatusBar;
    procedure StatusOptionClick(Sender:TObject);
    procedure BuildQuickCatalog;
    function QuickControl(const Key:string):TControl;
    procedure QuickRibbonClick(Sender:TObject);
    procedure QuickOverflowClick(Sender:TObject);
    procedure SyncQuickAccess;
  private
    TablesTab,FiguresTab,TheoremsTab:TTabSheet;
    ColorBoxesTab,ListingsTab:TTabSheet;
    FigureImageButton,FigureDiagramButton,FigureCaptionButton:TSpeedButton;
    CommandsTab:TTabSheet;
    DefinitionKind:TComboBox;
    FUpdatingDefinition:Boolean;
    DefinitionSourceButton:TSpeedButton;
    procedure DefinitionAction(Sender:TObject);
    procedure RefreshDefinitionControls;
    procedure DefinitionKindChanged(Sender:TObject);
  private
    FFullSource:TFullSourceForm;
    FSplitView:TSourcePDFView;
    FSplitLocateFile:string;
    FSplitLocateLine,FSplitLocateColumn:Integer;
    FSyncingFullSource:Boolean;
    procedure SplitViewClick(Sender:TObject);
    procedure ExitSplitView;
    procedure SplitSourceLocation(Sender:TObject; const Path:string; Line,Column:Integer);
    procedure SplitLocateReady(Data:PtrInt);
    procedure SplitMessage(Sender:TObject; const AText:string);
    procedure UpdateContextTabs(InEquation,InTable,InTheorem:Boolean; ActivateTab:Boolean=True; InFigure:Boolean=False);
    procedure FullSourceClick(Sender:TObject);
    procedure FullSourceChanged(Sender:TObject);
    procedure FullSourceSelection(Sender:TObject);
    procedure LocateSourceFromPreview(Sender:TObject);
    procedure LocatePreviewFromSource(Sender:TObject);
    procedure SyncFullSource(Force:Boolean=False);
    procedure StatusZoomClick(Sender:TObject);
  private
    SourceGrip:TPanel;
    QuickUndoList,QuickRedoList:TSpeedButton;
    procedure SelectZoom(Choice:TComboBox; Percent:Integer);
    procedure SetPreviewPercent(Percent:Integer; SaveSetting:Boolean=True);
    procedure SetFitWidth(SaveSetting:Boolean=True);
    procedure SetFitPage;
    function PreviewContentWidth:Integer;
    function PreviewScalePercent:Integer;
    procedure SourceLayoutReady(Data:PtrInt);
    procedure BuildRibbon;
    procedure BuildMenu;
    procedure FindCommandClick(Sender:TObject);
    procedure UpdateRibbonVisibility;
    procedure UpdateCommandAvailability(InEquation,InTable,InFigure,InTheorem:Boolean);
    procedure ToggleRibbon(Sender:TObject);
    procedure RibbonAction(Sender:TObject);
    procedure RibbonChoice(Sender:TObject);
    procedure RefreshParagraphStyles(Sender:TObject);
    procedure RibbonChoiceMenu(Sender:TObject);
    procedure RestoreRibbonEditFocus(Data:PtrInt);
    procedure RibbonDropDown(Sender:TObject);
    procedure ConfigureQuickAccess(Sender:TObject);
    procedure LayoutQuickAccess;
    function QuickActionControl(ID:Integer):TControl;
    procedure SourceGripDown(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
    procedure SourceGripMove(Sender:TObject; Shift:TShiftState; X,Y:Integer);
    procedure SourceGripUp(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
    procedure SetupTools;
    procedure SourceSelectionChanged(Sender:TObject; Changes:TSynStatusChanges);
    procedure CompletionContext(Source:TSynEdit; out Prefix,Directory,AEngine:string; out MathMode,AEnabled:Boolean);
    procedure ToolPopupClick(Sender:TObject);
    procedure ReferenceToolClick(Sender:TObject);
    procedure TheoremToolClick(Sender:TObject);
    procedure ToolCommandClick(Sender:TObject);
    function ObjectTool(const Code:string):Boolean;
    procedure OpenFigure(Sender:TObject);
    procedure HistoryClick(Sender:TObject);
    procedure HistoryItemClick(Sender:TObject);
    procedure PreferencesClick(Sender:TObject);
    procedure AboutClick(Sender:TObject);
    procedure EnvironmentCheckClick(Sender:TObject);
    procedure PropertiesClick(Sender:TObject);
    procedure DocumentInfoClick(Sender:TObject);
    procedure ApplyAppearance;
  private
    FSourceBeforeCommand:string;
    FSourceUndoBlock,FReblockQueued,FReblockKeepEmpty,FSourceJoinNext:Boolean;
    procedure SourceCommandBefore(Sender:TObject; var Command:TSynEditorCommand; var AChar:TUTF8Char; Data:Pointer);
    procedure SourceCommandAfter(Sender:TObject; var Command:TSynEditorCommand; var AChar:TUTF8Char; Data:Pointer);
    procedure ReblockSource(Data:PtrInt);
    procedure ReblockVisual(Data:PtrInt);
    procedure ParagraphBreak(Sender:TObject);
    procedure ParagraphBoundary(Sender:TObject; Direction:Integer; Merge:Boolean);
  private
    Document: TTeXDocument;
    FVisualUndo,FVisualRedo:TObjectList;
    FRestoringHistory:Boolean;
    SourceTools:TPanel;
    Cards:TParagraphCards;
    FContinuousEditor:TMathEditor;
    SourceWrap:TLazSynEditLineWrapPlugin;
    WrappedEditor,PlainEditor:TSynEdit;
    HeadingPopup,EditPopup,EquationActionsPopup:TPopupMenu;
    FSelectionStartBlock,FSelectionStartOffset,FSelectionEndBlock,FSelectionEndOffset:Integer;
    FDocumentDragging:Boolean;
    FSelectionRegistry:TMacroRegistry;
    FSelectionContext:TTeXContext;
    FSelectionRevision:Integer;
    procedure ClearDocumentSelection;
    function SelectionModelFor(Index:Integer):TParagraphSelection;
    procedure NormalizeParagraphSelection(Index:Integer; var A,B:Integer);
    function ParagraphHitOffset(Index:Integer; P:TPoint):Integer;
    procedure RevealVisualCaret;
    procedure TrimPreviewCaches;
    procedure CompleteParagraphPreview;
    function DocumentSelectionBounds(out A,AO,B,BO:Integer):Boolean;
    procedure UpdateDocumentSelection;
    procedure DocumentGesture(Sender:TObject; ScreenPoint:TPoint; Phase:Integer; Shift:TShiftState);
    procedure DocumentKey(Sender:TObject; Key:Word; Shift:TShiftState; var Handled:Boolean);
    procedure DocumentText(Sender:TObject; const Value:string; var Handled:Boolean);
    procedure PreviewMouseDown(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
    function SelectedDocumentText(ForClipboard:Boolean=False):string;
    procedure ReplaceDocumentSelection(const Value:string);

  private
    EquationMode: Boolean;
    FormulaSpans: TMathSpans;
    FormulaIndex: Integer;
    CacheContext: string;
    Worker: TRenderThread;
    FileName, LastLog: string;
    ActiveBlock, Revision: Integer;
    Modified, FLoading, Pending, FLayoutBusy, FTickBusy, FPreviewRasterFallback: Boolean;
    Due: QWord;
    FDeferredAction:TNotifyEvent;
    FDeferredSender:TObject;
    FDeferredClick:TPoint;
    FReplayingAction:Boolean;
    procedure RecordVisualEdit(Caret:Integer=-1);
    procedure RestoreVisualEdit(Undoing:Boolean);
    function MenuSelector(Kind:Integer):TComboBox;
    function DeferInput(Callback:TNotifyEvent; Sender:TObject):Boolean;
    procedure CloseAfterInput(Sender:TObject);
    procedure BuildCards;
    procedure RefreshFields(Force:Boolean=False);
    procedure VisualSelectionChanged(Sender:TObject);
    procedure FormulaChanged(Sender: TObject);
    procedure LoadEquation;
    procedure CardClick(Sender: TObject);
    procedure EditBlock(Index: Integer);
    procedure QueuePreview(LocalEdit:Boolean=False; CompileNow:Boolean=False);
    procedure CheckPreviewTools;
    function UseCompiledPreview:Boolean;
    procedure ClearCompiledPreviews;
    procedure SyncLabelReferences(const Before,After:string);
    procedure UpdateTitle;
    function SaveDocument(ChooseName: Boolean): Boolean;
    function MayDiscard: Boolean;
    procedure ShowText(const Title, Value: string);
    function BodyEditor:TMathEditor;
    function BodyEditing:Boolean;
    property FormulaEditor:TMathEditor read BodyEditor write FContinuousEditor;
  public
    PreambleEditor:TMathEditor;
    StatusText:string;
    property PreambleExpanded:Boolean read FPreambleExpanded write SetPreambleExpanded;
    procedure LoadDocument(const Path:string; Reload:Boolean=False);
    procedure SwitchDocument(Index:Integer);
    procedure MoveDocument(FromIndex,ToIndex:Integer);
    function OpenFileCount:Integer;
    function OpenFileName(Index:Integer):string;
    procedure ApplySettings(Sender:TObject);
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
  end;

var MainWindow: TMainForm;

implementation
uses AtomicFiles, EditorClipboard, EnvironmentForm, SymbolBrowser, CommandSearch, ToolJobs, ImportForms, AddonForm, TeXRules, MathSpacing,
  ShortcutsForm, DocumentFormats, ExtensionFormats, SpreadsheetData, AddonModel, AddonContext, PluginRunner, FPJSON, Zipper, URIParser, FileUtil, BeamerModel, EnvironmentCheckForm;

type TSourceEditorAccess = class(TSynEdit);
  TQuickRibbonButton=class(TSpeedButton)
    Source:TControl;
  end;
  TCommandRibbonButton=class(TSpeedButton)
    MenuCommand:TMenuItem;
  end;

{$R *.lfm}

constructor TDocumentSnapshot.Create(Document:TTeXDocument; Index,Offset:Integer);
begin
  inherited Create; Blocks:=TStringList.Create; Blocks.Assign(Document.Blocks);
  Preamble:=Document.Preamble; Ending:=Document.Ending; PreambleOnly:=Document.PreambleOnly;
  BlockIndex:=Index; Caret:=Offset;
end;
destructor TDocumentSnapshot.Destroy;
begin Blocks.Free; inherited Destroy; end;

const Starter = '\documentclass[12pt]{article}' + LineEnding +
  '\usepackage{amsmath,amssymb}' + LineEnding +
  '\usepackage[margin=1in]{geometry}' + LineEnding +
  '\begin{document}' + LineEnding +
  '\section*{Welcome to PasTeX}' + LineEnding +
  'Click text or a formula to edit it visually. Use Source to edit LaTeX manually.' +
  LineEnding + LineEnding +
  'Inline mathematics, such as $e^{i\pi}+1=0$, stays right beside your text.' +
  LineEnding + LineEnding +
  '\begin{align}' + LineEnding +
  '  \int_0^\infty e^{-x^2}\,dx &= \frac{\sqrt{\pi}}{2}, \\' + LineEnding +
  '  \sum_{n=1}^\infty \frac{1}{n^2} &= \frac{\pi^2}{6}.' + LineEnding +
  '\end{align}' + LineEnding + LineEnding +
  'Use Document settings to edit packages and custom commands. Blank lines separate paragraphs.' +
  LineEnding + '\end{document}' + LineEnding;

const FormulaKinds:array[0..7] of string = ('inline','display','equation','equation*','align','align*','gather','gather*');
      FormulaLabels:array[0..7] of string = ('Inline formula','Displayed formula','Numbered equation','Unnumbered equation','Align','Align (unnumbered)','Gather','Gather (unnumbered)');
      GridLabels:array[0..7] of string = ('Insert row above','Insert row below (Enter)','Delete current row','Insert column before','Insert column after','Delete current column','Duplicate row','Duplicate column');
function BytePoint(const S:string; Offset:Integer):TPoint; forward;

procedure SetMenuChecked(Item:TMenuItem; Value:Boolean);
var Handler:TNotifyEvent;
begin
  { GTK3 emits activate while setting a native check item. A state refresh
    must never execute its editing command. }
  Handler:=Item.OnClick; Item.OnClick:=nil;
  try Item.Checked:=Value; finally Item.OnClick:=Handler; end;
end;

{$I mainformtools.inc}
{$I mainformribbon.inc}
{$I mainformmenus.inc}
{$I mainformsource.inc}
{$I mainformpreamble.inc}
{$I mainformobjects.inc}
{$I mainformdocuments.inc}
{$I mainformlinked.inc}
{$I mainformworkspace.inc}
{$I mainformstatus.inc}
{$I mainformextended.inc}
{$I mainformformats.inc}
{$I mainformaddons.inc}

constructor TMainForm.Create(TheOwner: TComponent);
var I:Integer; Control:TControl; Item,ActionItem:TMenuItem; WrapIcon:TBitmap;
  procedure PopulateActions(ParentItem:TMenuItem);
  var Group,Action:TMenuItem; J,K:Integer;
  begin
    for J:=1 to 3 do
    begin
      Group:=TMenuItem.Create(Self);
      case J of 1:Group.Caption:='Insert formula'; 2:Group.Caption:='Change formula type'; 3:Group.Caption:='Rows and columns'; end;
      ParentItem.Add(Group);
      for K:=0 to IfThen(J=3,High(GridLabels),High(FormulaKinds)) do
      begin
        Action:=TMenuItem.Create(Self); Action.Tag:=J*100+K;
        if J=3 then Action.Caption:=GridLabels[K] else Action.Caption:=FormulaLabels[K];
        Action.OnClick:=@EquationActionClick; Group.Add(Action);
      end;
    end;
  end;
begin
  { Suppress editor/layout events while the form resource is being streamed. }
  FSelectionStartBlock:=-1; FSelectionEndBlock:=-1;
  ActiveBlock:=-1; FLoading:=True; FLayoutBusy:=True; FPreviewPercent:=100; FPreviewMarginRevision:=-1;
  inherited Create(TheOwner);
  SourceCompletionContext:=@CompletionContext;
  Editor.SetDefaultKeystrokes; Editor.ResetMouseActions;
  Editor.ReadOnly:=False;
  SourceWrap:=TLazSynEditLineWrapPlugin.Create(Editor);
  WrappedEditor:=Editor;
  { Closing the original tab must not clear the published Editor field while
    it points to another tab's widget. TComponent clears fields by name. }
  WrappedEditor.Name:='InitialSourceEditor'; Editor:=WrappedEditor;
  UseNativeSourceFonts(Editor); EnableSourceLinks(Editor);
  Editor.Options:=Editor.Options+[eoPersistentCaret]-[eoScrollPastEol];
  Editor.Options2:=Editor.Options2+[eoPersistentCaretStopBlink]-[eoScrollPastEolAddPage,eoScrollPastEolAutoCaret];
  Editor.ScrollBars:=ssVertical; Editor.LeftChar:=1;
  WrapIcon:=TBitmap.Create;
  try
    WrapIcon.SetSize(24,24);
    with WrapIcon.Canvas do
    begin
      Brush.Color:=clFuchsia; FillRect(Rect(0,0,24,24));
      Pen.Color:=$533617; Pen.Width:=2;
      MoveTo(3,5); LineTo(21,5);
      MoveTo(3,10); LineTo(16,10); LineTo(20,13); LineTo(20,17); LineTo(12,17);
      MoveTo(15,14); LineTo(12,17); LineTo(15,20);
      MoveTo(3,16); LineTo(8,16);
    end;
    WrapIcon.Transparent:=True; SourceWrapButton.Glyph.Assign(WrapIcon);
  finally WrapIcon.Free; end;
  EquationActionsPopup:=TPopupMenu.Create(Self); PopulateActions(EquationActionsPopup.Items);
  Item:=TMenuItem.Create(Self); Item.Caption:='Formula layout'; NavigateMenu.Add(Item); PopulateActions(Item);
  Item:=TMenuItem.Create(Self); Item.Caption:='Formula layouts'; InsertMenu.Add(Item);
  for I:=0 to High(FormulaKinds) do
  begin
    ActionItem:=TMenuItem.Create(Self); ActionItem.Caption:=FormulaLabels[I];
    ActionItem.Tag:=100+I; ActionItem.OnClick:=@EquationActionClick; Item.Add(ActionItem);
  end;
  HeadingPopup:=TPopupMenu.Create(Self);
  for I:=0 to HeadingMenuItem.Count-1 do
  begin
    Item:=TMenuItem.Create(Self); Item.Caption:=HeadingMenuItem.Items[I].Caption;
    Item.Tag:=HeadingMenuItem.Items[I].Tag; Item.OnClick:=@FormatClick; HeadingPopup.Items.Add(Item);
  end;
  Editor.OnProcessCommand:=@SourceCommandBefore;
  Editor.OnCommandProcessed:=@SourceCommandAfter; Editor.OnStatusChange:=@SourceSelectionChanged;
  Editor.OnMouseDown:=@SourceMouseDown;
  for I:=0 to ComponentCount-1 do
    if (Components[I] is TBitBtn) or (Components[I] is TSpeedButton) then
    begin
      Control:=TControl(Components[I]);
      Control.AccessibleName:=Control.Hint;
    end;
  Document:=TTeXDocument.Create; FSelectionRegistry:=TMacroRegistry.Create;
  FSelectionContext:=TTeXContext.Create; FSelectionRevision:=-1;
  FVisualUndo:=TObjectList.Create(True); FVisualRedo:=TObjectList.Create(True);
  EquationMode:=True; FormulaIndex:=0;
  Application.Icon.Assign(Icon);
  { The custom canvas and document-dependent cards are runtime controls. }
  FormulaEditor:=TMathEditor.Create(Self); FormulaEditor.Parent:=FormulaBox;
  FormulaEditor.OnDocumentGesture:=@DocumentGesture;
  FormulaEditor.OnSourceLink:=@VisualLinkClick; FormulaEditor.OnGeneratedAction:=@GeneratedAction;
  FormulaEditor.OnDocumentKey:=@DocumentKey;
  FormulaEditor.OnDocumentText:=@DocumentText;
  EditPopup:=TPopupMenu.Create(Self); EditPopup.OnPopup:=@ContextPopup;
  FormulaEditor.PopupMenu:=EditPopup; Editor.PopupMenu:=EditPopup;
  FormulaEditor.OnChange:=@FormulaChanged; FormulaEditor.OnFinish:=@PreviewClick;
  FormulaEditor.OnFigureEdit:=@OpenFigure;
  FormulaEditor.OnLayout:=@LayoutCards; FormulaEditor.OnSelectionChange:=@VisualSelectionChanged;
  FormulaEditor.OnUndo:=@UndoClick; FormulaEditor.OnRedo:=@RedoClick;
  FormulaEditor.OnParagraphBreak:=@ParagraphBreak; FormulaEditor.OnBoundary:=@ParagraphBoundary;
  FLoading:=False; FLayoutBusy:=False;
  Document.Parse(Starter); BuildCards; UpdateTitle; QueuePreview;
  SourceTools:=TPanel.Create(Self); SourceTools.Parent:=Self; SourceTools.Visible:=False;
  SourceTools.BevelOuter:=bvNone; SourceTools.Height:=32;
  SourceWrapButton.Parent:=SourceTools; SourceWrapButton.SetBounds(4,2,28,28);
  FPreviewPercent:=100;
  SourceGrip:=TPanel.Create(Self); SourceGrip.Name:='SourceResizeHandle'; SourceGrip.Parent:=Self; SourceGrip.Visible:=False;
  SourceGrip.Height:=12; SourceGrip.BevelOuter:=bvNone; SourceGrip.Caption:='────';
  SourceGrip.Cursor:=crVSplit; SourceGrip.Hint:='Drag to resize the source editor'; SourceGrip.ShowHint:=True;
  SourceGrip.OnMouseDown:=@SourceGripDown; SourceGrip.OnMouseMove:=@SourceGripMove; SourceGrip.OnMouseUp:=@SourceGripUp;
  SetupTools;
  FSourceFontPreference:=Editor.Font.Name;
  InitDocumentTabs; InitWorkspace; InitStatusBar; InitExtendedWorkspace;
  for I:=1 to ParamCount do if Copy(ParamStr(I),1,1)<>'-' then LoadDocument(ExpandFileName(ParamStr(I)));
  Timer.Enabled:=True;
end;

destructor TMainForm.Destroy;
begin
  SourceCompletionContext:=nil;
  OnToolStatus:=nil; CancelToolJob;
  FLoading:=True; FLayoutBusy:=True;
  FreeAndNil(FSplitView);
  FreeAndNil(FPagedView);
  CancelTabUpdates(Ribbon);
  if Assigned(FormulaEditor) then FormulaEditor.CancelSelectionDrag;
  if Assigned(PreambleEditor) then PreambleEditor.CancelSelectionDrag;
  Application.RemoveAsyncCalls(Self);
  if Assigned(Timer) then Timer.Enabled := False;
  if Assigned(Worker) then
  begin
    Worker.Terminate;
    Worker.WaitFor;
    FreeAndNil(Worker);
  end;
  if FPDFWorker<>nil then begin FPDFWorker.Terminate; FPDFWorker.WaitFor; FreeAndNil(FPDFWorker); end;
  if FPDFPath<>'' then DeleteFile(FPDFPath);
  SourceWrap:=nil;
  { Both source views and the wrap plugin live until the form is destroyed. }
  ClearDocumentSelection; FSelectionRegistry.Free; FSelectionContext.Free; FPreambleFields.Free; FSourceStyles.Free;
  FQuickOrder.Free; FQuickCatalog.Free; FStatusCache.Free;
  if FSessions<>nil then begin StoreDocumentTab; FreeAndNil(FSessions); end
  else begin FVisualUndo.Free; FVisualRedo.Free; Document.Free; end;
  inherited Destroy;
end;

procedure TMainForm.UpdateTitle;
var DisplayName: string;
begin
  if FileName = '' then begin if PluginSourceActive then DisplayName:='Untitled.'+TOpenDocument(FSessions[FSessionIndex]).SourceExtension else DisplayName:='Untitled.tex'; end
  else DisplayName := ExtractFileName(FileName);
  if Modified then DisplayName := '* ' + DisplayName;
  Caption := DisplayName + ' — PasTeX';
  if (FileTabs<>nil) and (FSessionIndex>=0) and (FSessionIndex<FileTabs.Tabs.Count) then FileTabs.Tabs[FSessionIndex]:=DisplayName;
end;

procedure TMainForm.ClearDocumentSelection;
var I:Integer;
begin
  FSelectionStartBlock:=-1; FSelectionEndBlock:=-1; FDocumentDragging:=False;
  for I:=0 to High(Cards) do
  begin
    Cards[I].Image.SetSelection(nil); FreeAndNil(Cards[I].SelectionModel);
    if Cards[I].Draft<>nil then Cards[I].Draft.ClearSourceSelection;
  end;
end;

function TMainForm.SelectionModelFor(Index:Integer):TParagraphSelection;
var Directory,Header:string; I:Integer;
begin
  if Cards[Index].SelectionModel=nil then begin
    Directory:=DocumentDirectory;
    if FSelectionRevision<>Revision then begin
      FSelectionRegistry.Load(Document.Source,Directory,Engine.Text); FSelectionContext.Load(Document.Source,Directory,Engine.Text);
      FSelectionRevision:=Revision;
    end;
    Header:=Document.Preamble;
    for I:=0 to Index-1 do Header:=Header+Document.Blocks[I];
    Cards[Index].SelectionModel:=TParagraphSelection.Create(Document.Blocks[Index],Header,
      Cards[Index].LayoutXML,Cards[Index].Positions,FSelectionRegistry,Cards[Index].LayoutPage,
      Cards[Index].Image.PreviewWidth,Cards[Index].Image.PreviewHeight,Cards[Index].Image.Width,Canvas,FSelectionContext,Directory);
  end;
  Result:=Cards[Index].SelectionModel;
end;
procedure TMainForm.NormalizeParagraphSelection(Index:Integer; var A,B:Integer);
begin
  if (Index=ActiveBlock) and FormulaBox.Visible then FormulaEditor.NormalizeSelection(A,B)
  else if (Cards[Index].Draft<>nil) and Cards[Index].Draft.Visible then Cards[Index].Draft.NormalizeSelection(A,B)
  else SelectionModelFor(Index).Normalize(A,B);
end;
function TMainForm.ParagraphHitOffset(Index:Integer; P:TPoint):Integer;
begin
  if (Index=ActiveBlock) and FormulaBox.Visible then Result:=FormulaEditor.HitOffset(P.X,P.Y)
  else if (Cards[Index].Draft<>nil) and Cards[Index].Draft.Visible then Result:=Cards[Index].Draft.HitOffset(P.X,P.Y)
  else Result:=SelectionModelFor(Index).HitOffset(P.X,P.Y);
end;
function TMainForm.DocumentSelectionBounds(out A,AO,B,BO:Integer):Boolean;
var T,L,R:Integer;
begin
  A:=FSelectionStartBlock; AO:=FSelectionStartOffset;
  B:=FSelectionEndBlock; BO:=FSelectionEndOffset;
  Result:=(A>=0) and (B>=0) and (A<Length(Cards)) and (B<Length(Cards));
  if not Result then Exit;
  if (A>B) or ((A=B) and (AO>BO)) then
  begin T:=A; A:=B; B:=T; T:=AO; AO:=BO; BO:=T; end;
  Result:=(A<>B) or (AO<>BO);
  if Result then
  begin
    L:=AO; if A=B then R:=BO else R:=Length(Document.Blocks[A]);
    NormalizeParagraphSelection(A,L,R); AO:=L;
    if A=B then BO:=R
    else begin L:=0; R:=BO; NormalizeParagraphSelection(B,L,R); BO:=R; end;
  end;
end;

procedure TMainForm.UpdateDocumentSelection;
var A,AO,B,BO,I,L,R:Integer; Backwards:Boolean; Boxes:TSelectionRects;
begin
  if not DocumentSelectionBounds(A,AO,B,BO) then begin
    for I:=0 to High(Cards) do begin
      Cards[I].Image.SetSelection(nil);
      if Cards[I].Draft<>nil then Cards[I].Draft.ClearSourceSelection;
    end;
    if (FSelectionStartBlock=ActiveBlock) and (ActiveBlock>=0) then
      FormulaEditor.SetSourceSelection(FSelectionStartOffset,FSelectionEndOffset);
    Exit;
  end;
  Backwards:=(FSelectionEndBlock<FSelectionStartBlock) or
    ((FSelectionEndBlock=FSelectionStartBlock) and (FSelectionEndOffset<FSelectionStartOffset));
  for I:=0 to High(Cards) do begin
    Cards[I].Image.SetSelection(nil);
    if Cards[I].Draft<>nil then Cards[I].Draft.ClearSourceSelection;
    { Only partial endpoint paragraphs need parsed selection geometry. }
    if (I<>A) and (I<>B) then FreeAndNil(Cards[I].SelectionModel);
    if (I<A) or (I>B) then Continue;
    L:=0; R:=Length(Document.Blocks[I]); if I=A then L:=AO; if I=B then R:=BO;
    if (I=ActiveBlock) and FormulaBox.Visible then begin
      if Backwards then FormulaEditor.SetSourceSelection(R,L) else FormulaEditor.SetSourceSelection(L,R);
    end else if (Cards[I].Draft<>nil) and Cards[I].Draft.Visible then begin
      if Backwards then Cards[I].Draft.SetSourceSelection(R,L) else Cards[I].Draft.SetSourceSelection(L,R);
    end else begin
      if (I>A) and (I<B) then begin
        SetLength(Boxes,1); Boxes[0]:=Rect(0,0,Cards[I].Image.Width,Cards[I].Image.Height);
      end else Boxes:=SelectionModelFor(I).Rects(L,R);
      Cards[I].Image.SetSelection(Boxes);
    end;
  end;
end;

procedure TMainForm.PreviewMouseDown(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
var P:TPoint; Index,I,Offset:Integer; Inside:Boolean; Boxes:TSelectionRects;
begin
  if PluginSourceActive then begin
    if Editor.CanFocus then Editor.SetFocus;
    Exit;
  end;
  if not (Button in [mbLeft,mbRight]) then Exit;
  P:=TControl(Sender).ClientToScreen(Point(X,Y)); Index:=TControl(Sender).Tag;
  Offset:=ParagraphHitOffset(Index,Point(X,Y));
  if (Button=mbLeft) and (ssCtrl in Shift) and
    QueueLinkedFile(Document.Blocks[Index],Offset) then Exit;
  EquationMode:=True; EditBlock(Index);
  if not FormulaBox.Visible then LoadEquation;
  P:=FormulaEditor.ScreenToClient(P);
  if Button=mbLeft then begin
    if GeneratedBlock(Document.Blocks[ActiveBlock]) then begin ClearDocumentSelection; FormulaEditor.BeginSelectionAt(P.X,P.Y,Shift); end
    else begin FormulaEditor.BeginSelectionAtSource(Offset,Shift); RevealVisualCaret; end;
  end
  else begin
    Inside:=False; Boxes:=FormulaEditor.SelectedRects;
    for I:=0 to High(Boxes) do Inside:=Inside or PtInRect(Boxes[I],P);
    if not Inside then begin ClearDocumentSelection; FormulaEditor.SetSourceCaret(Offset); RevealVisualCaret; end;
  end;
end;
procedure TMainForm.RevealVisualCaret;
var P:TPoint; X,Y:Integer;
begin
  if FPagedView<>nil then Exit;
  if not FormulaBox.Visible or (ActiveBlock<0) or (ActiveBlock>High(Cards)) then Exit;
  { Native allocations can still describe the previous paragraph after a
    mode switch. Use document coordinates to reveal the new source caret. }
  P:=FormulaEditor.CaretPoint+TPreviewPanel(Cards[ActiveBlock].Panel).DocumentOrigin+
    Point(FormulaBox.Left+FormulaEditor.Left,FormulaBox.Top+FormulaEditor.Top);
  X:=Scroll.HorzScrollBar.Position; Y:=Scroll.VertScrollBar.Position;
  Dec(P.X,X); Dec(P.Y,Y);
  if P.X<16 then Inc(X,P.X-16)
  else if P.X>Scroll.ClientWidth-24 then Inc(X,P.X-Scroll.ClientWidth+24);
  if P.Y<16 then Inc(Y,P.Y-16)
  else if P.Y>Scroll.ClientHeight-24 then Inc(Y,P.Y-Scroll.ClientHeight+24);
  SetPreviewScroll(Scroll,X,Y);
end;

procedure TMainForm.DocumentGesture(Sender:TObject; ScreenPoint:TPoint; Phase:Integer; Shift:TShiftState);
var Index,SavedX,SavedY,First,Last,Middle,DocumentY:Integer; P:TPoint;
begin
  if PluginSourceActive then Exit;
  if ActiveBlock<0 then Exit;
  SavedX:=Scroll.HorzScrollBar.Position; SavedY:=Scroll.VertScrollBar.Position;
  case Phase of
    0:begin
      if not (ssShift in Shift) or (FSelectionStartBlock<0) then
      begin ClearDocumentSelection; FSelectionStartBlock:=ActiveBlock; FSelectionStartOffset:=FormulaEditor.SourceCaret; end;
      FSelectionEndBlock:=ActiveBlock; FSelectionEndOffset:=FormulaEditor.SourceCaret;
      FDocumentDragging:=True;
    end;
    1:begin
      if not FDocumentDragging then Exit;
      P:=ScreenPoint-PreviewViewportOrigin(Scroll);
      { Drag selection scrolls only after the pointer leaves the viewport. }
      if P.Y<0 then SetPreviewScroll(Scroll,SavedX,SavedY-18)
      else if P.Y>Scroll.ClientHeight then SetPreviewScroll(Scroll,SavedX,SavedY+18);
      SavedY:=Scroll.VertScrollBar.Position;
      DocumentY:=P.Y+SavedY; First:=0; Last:=High(Cards);
      while First<Last do begin
        Middle:=First+(Last-First) div 2;
        { Native GTK allocations can retain the preceding card's old height.
          Paragraph starts belong to the document layout and stay consistent. }
        if DocumentY<Cards[Middle+1].DocumentTop then Last:=Middle
        else First:=Middle+1;
      end;
      Index:=Last;
      if Index<0 then Exit;
      if Index=ActiveBlock then P:=FormulaEditor.ScreenToClient(ScreenPoint)
      else if (Cards[Index].Draft<>nil) and Cards[Index].Draft.Visible then P:=Cards[Index].Draft.ScreenToClient(ScreenPoint)
      else P:=Cards[Index].Image.ScreenToClient(ScreenPoint);
      FSelectionEndBlock:=Index; FSelectionEndOffset:=ParagraphHitOffset(Index,P);
    end;
    2:FDocumentDragging:=False;
    3:begin FSelectionEndBlock:=ActiveBlock; FSelectionEndOffset:=FormulaEditor.SourceCaret; end;
    4:begin
      FDocumentDragging:=False; FSelectionStartBlock:=ActiveBlock; FSelectionEndBlock:=ActiveBlock;
      FormulaEditor.GetSourceSelection(FSelectionStartOffset,FSelectionEndOffset);
    end;
  end;
  UpdateDocumentSelection;
  if Phase<>3 then begin
    if Phase=2 then VisualSelectionChanged(FormulaEditor);
    SetPreviewScroll(Scroll,SavedX,SavedY);
  end;
end;

function TMainForm.SelectedDocumentText(ForClipboard:Boolean):string;
var A,AO,B,BO,I,L,R:Integer; Root:TMathNode;
begin
  Result:=''; if not DocumentSelectionBounds(A,AO,B,BO) then Exit;
  for I:=A to B do
  begin
    L:=0; R:=Length(Document.Blocks[I]); if I=A then L:=AO; if I=B then R:=BO;
    Root:=ParseParagraph(Document.Blocks[I],FSelectionRegistry);
    try
      if ForClipboard then Result:=Result+BodyClipboardFragment(Root,Document.Blocks[I],L,R)
      else Result:=Result+ProseFragment(Root,Document.Blocks[I],L,R);
    finally Root.Free; end;
  end;
end;

procedure TMainForm.ReplaceDocumentSelection(const Value:string);
var A,AO,B,BO,I,Offset,Index:Integer; Parts:TTeXDocument; Joined:string; Root:TMathNode;
begin
  if not DocumentSelectionBounds(A,AO,B,BO) then Exit;
  RecordVisualEdit;
  Root:=ParseParagraph(Document.Blocks[A],FSelectionRegistry);
  try Joined:=ProseFragment(Root,Document.Blocks[A],0,AO)+Value; finally Root.Free; end;
  Offset:=Length(Joined); Index:=A;
  Root:=ParseParagraph(Document.Blocks[B],FSelectionRegistry);
  try Joined:=Joined+ProseFragment(Root,Document.Blocks[B],BO,Length(Document.Blocks[B])); finally Root.Free; end;
  Parts:=TTeXDocument.Create;
  try
    Parts.Parse(Joined);
    if (Parts.Preamble<>'') or (Parts.Ending<>'') then
    begin Parts.Blocks.Clear; Parts.Blocks.Add(Joined); end;
    if Parts.Blocks.Count=0 then Parts.Blocks.Add('');
    for I:=B downto A do Document.Blocks.Delete(I);
    for I:=0 to Parts.Blocks.Count-1 do Document.Blocks.Insert(A+I,Parts.Blocks[I]);
    while (Index<A+Parts.Blocks.Count-1) and (Offset>Length(Document.Blocks[Index])) do
    begin Dec(Offset,Length(Document.Blocks[Index])); Inc(Index); end;
  finally Parts.Free; end;
  BuildCards; EditBlock(Index); FormulaEditor.SetSourceCaret(Offset);
  Modified:=True; UpdateTitle; QueuePreview;
end;

procedure TMainForm.DocumentText(Sender:TObject; const Value:string; var Handled:Boolean);
var A,AO,B,BO:Integer;
begin
  if DocumentSelectionBounds(A,AO,B,BO) and (A<>B) then
  begin
    if Value='{' then ReplaceDocumentSelection('{'+SelectedDocumentText+'}')
    else ReplaceDocumentSelection(StringReplace(Value,'%','\%',[rfReplaceAll]));
    Handled:=True;
  end
  else if not FDocumentDragging then ClearDocumentSelection;
end;

procedure TMainForm.DocumentKey(Sender:TObject; Key:Word; Shift:TShiftState; var Handled:Boolean);
var A,AO,B,BO,Index,Offset:Integer; HasSelection,Cross,Selecting:Boolean; P:TPoint;
begin
  if (FPagedView<>nil) or not FormulaBox.Visible or (ActiveBlock<0) then Exit;
  HasSelection:=DocumentSelectionBounds(A,AO,B,BO); Cross:=HasSelection and (A<>B);
  if not Cross and FormulaEditor.EditingTable and (ssShift in Shift) and (Key in [VK_UP,VK_DOWN]) then begin
    if FSelectionStartBlock<0 then begin FSelectionStartBlock:=ActiveBlock; FSelectionStartOffset:=FormulaEditor.SourceCaret; end;
    Exit;
  end;
  if ssCtrl in Shift then
  begin
    if Key=VK_A then
    begin
      ClearDocumentSelection; FSelectionStartBlock:=0; FSelectionStartOffset:=0;
      FSelectionEndBlock:=High(Cards); FSelectionEndOffset:=Length(Document.Blocks[High(Cards)]);
      UpdateDocumentSelection; Handled:=True; Exit;
    end;
    if Cross then
      case Key of
        VK_C,VK_X:begin WriteVisualClipboard(SelectedDocumentText,SelectedDocumentText(True)); if Key=VK_X then ReplaceDocumentSelection(''); Handled:=True; end;
        VK_V:begin ReplaceDocumentSelection(ReadBodyClipboard); Handled:=True; end;
      end;
    Exit;
  end;
  if Cross and (Key in [VK_BACK,VK_DELETE,VK_RETURN]) then
  begin
    if Key=VK_RETURN then ReplaceDocumentSelection(LineEnding+LineEnding) else ReplaceDocumentSelection('');
    Handled:=True; Exit;
  end;
  Selecting:=(ssShift in Shift) and (Key in [VK_LEFT,VK_RIGHT,VK_UP,VK_DOWN,VK_HOME,VK_END]);
  if Selecting then
  begin
    if FSelectionStartBlock<0 then
    begin FSelectionStartBlock:=ActiveBlock; FSelectionStartOffset:=FormulaEditor.SourceCaret; end;
    if Cross and (FSelectionEndBlock<>ActiveBlock) then
    begin EditBlock(FSelectionEndBlock); FormulaEditor.SetSourceCaret(FSelectionEndOffset); end;
    Index:=ActiveBlock; Offset:=FormulaEditor.SourceCaret;
    if (Key=VK_LEFT) and (Trim(Copy(Document.Blocks[Index],1,Offset))='') and (Index>0) then
    begin Dec(Index); Offset:=Length(TrimRight(Document.Blocks[Index])); end
    else if (Key=VK_RIGHT) and (Trim(Copy(Document.Blocks[Index],Offset+1,MaxInt))='') and (Index<High(Cards)) then
    begin Inc(Index); Offset:=0; end;
    if (Index=ActiveBlock) and (Key in [VK_UP,VK_DOWN]) then
    begin
      P:=FormulaEditor.CaretPoint;
      if not FormulaEditor.MoveVertical(IfThen(Key=VK_UP,-1,1)) then begin
        if (Key=VK_UP) and (Index>0) then begin
          Dec(Index); EditBlock(Index); P.Y:=FormulaEditor.PreferredHeight-1;
          FormulaEditor.HitOffset(P.X,P.Y);
        end else if (Key=VK_DOWN) and (Index<High(Cards)) then begin
          Inc(Index); EditBlock(Index); FormulaEditor.HitOffset(P.X,0);
        end;
      end;
      FSelectionEndBlock:=ActiveBlock; FSelectionEndOffset:=FormulaEditor.SourceCaret;
      UpdateDocumentSelection; Handled:=True; Exit;
    end;
    if Index<>ActiveBlock then
    begin
      EditBlock(Index); FormulaEditor.SetSourceCaret(Offset);
      FSelectionEndBlock:=ActiveBlock; FSelectionEndOffset:=Offset;
      UpdateDocumentSelection; Handled:=True;
    end;
  end
  else if Key in [VK_LEFT,VK_RIGHT,VK_UP,VK_DOWN,VK_HOME,VK_END,VK_BACK,VK_DELETE] then
  begin
    if Cross then
    begin
      if Key in [VK_LEFT,VK_UP,VK_HOME] then begin Index:=A; Offset:=AO; end
      else begin Index:=B; Offset:=BO; end;
      ClearDocumentSelection; EditBlock(Index); FormulaEditor.SetSourceCaret(Offset); Handled:=True;
    end else ClearDocumentSelection;
  end;
end;

procedure TMainForm.BuildCards;
var I,J,K: Integer; Old: array of TParagraphCard; Used: array of Boolean;
    NextCard:array of Integer; Reuse:TStringList; Context,SourceKey:string;
begin
  Reuse:=TStringList.Create; Reuse.CaseSensitive:=True; Reuse.Duplicates:=dupAccept;
  Scroll.DisableAlign;
  try
  FScaleClamped:=False;
  { Release capture before reparenting destroys a native editor handle. GTK3
    cannot release a grab through the widget after its handle is destroyed. }
  if Assigned(FormulaEditor) then FormulaEditor.CancelSelectionDrag;
  ClearDocumentSelection;
  if SourceTools<>nil then begin SourceTools.Visible:=False; SourceTools.Parent:=Self; end;
  if SourceGrip<>nil then begin SourceGrip.Visible:=False; SourceGrip.Parent:=Self; end;
  Editor.Visible := False; Editor.Parent := Self;
  FormulaBox.Visible := False; FormulaBox.Parent := Self;
  ActiveBlock := -1; FPreambleEditing:=False;
  UpdateContextTabs(False,False,False,False);
  Old := Cards; SetLength(Cards,0);
  SetLength(Used,Length(Old));
  SetLength(Cards,Document.Blocks.Count);
  Context := FileName + #0 + Document.Preamble + #0 + Engine.Text;
  if Context=CacheContext then begin
    { Sort once, then link equal sources in their original document order.
      Rebuilding after a source edit must not rescan every old paragraph. }
    for J:=0 to High(Old) do Reuse.Add(Old[J].SourceKey);
    Reuse.Sorted:=True; SetLength(NextCard,Length(Old));
    for J:=High(Old) downto 0 do begin
      Reuse.Find(Old[J].SourceKey,K); NextCard[J]:=PtrInt(Reuse.Objects[K])-1;
      Reuse.Objects[K]:=TObject(PtrInt(J+1));
    end;
  end;
  for I := 0 to High(Cards) do
  begin
    { Match by source, not index: insertions and deletions do not discard other images. }
    SourceKey:=Trim(Document.Blocks[I]);
    if (Context=CacheContext) and Reuse.Find(SourceKey,K) then begin
      J:=PtrInt(Reuse.Objects[K])-1;
      if J>=0 then begin
        Cards[I]:=Old[J]; Used[J]:=True; Reuse.Objects[K]:=TObject(PtrInt(NextCard[J]+1));
      end;
    end;
    if Cards[I].Panel = nil then
    begin
      Cards[I].Panel := TPreviewPanel.Create(Self);
      with Cards[I].Panel do
      begin
        Visible:=False;
        Parent := Scroll; BevelOuter := bvNone; Color := PaperColor;
        ParentBackground := False; OnClick := @CardClick; Cursor := crHandPoint;
      end;
      Cards[I].Image := TPreviewImage.Create(Cards[I].Panel);
      with Cards[I].Image do
      begin
        Parent := Cards[I].Panel;
        OnMouseDown := @PreviewMouseDown; OnDblClick:=@PreviewDoubleClick; PopupMenu:=EditPopup; Cursor := crIBeam;
      end;
    end;
    Cards[I].SourceKey := SourceKey;
    Cards[I].Image.Surface.SetSourceGraphics(Cards[I].SourceKey);
    Cards[I].Panel.Tag := I; Cards[I].Image.Tag := I;
    if Cards[I].Draft<>nil then Cards[I].Draft.Tag:=I;
    Cards[I].Image.Visible := True;
  end;
  for J := 0 to High(Old) do if not Used[J] then begin Old[J].SelectionModel.Free; Old[J].Panel.Free; end;
  CacheContext := Context;
  RefreshPreambleEditor; UpdateLinkedBoundaries; UpdatePreviewCards(1);
  FPreambleEditing:=Document.PreambleOnly;
  LayoutCards(nil);
  finally Reuse.Free; Scroll.EnableAlign; end;
end;

function TMainForm.CapturePreviewAnchor:TPreviewAnchor;
var I,Y:Integer;
begin
  Result:=Default(TPreviewAnchor); Result.Block:=-1; Result.Horizontal:=Scroll.HorzScrollBar.Position;
  Y:=Scroll.VertScrollBar.Position; Result.Position:=Y;
  for I:=0 to High(Cards) do begin
    if Cards[I].DocumentTop>Y then Break; { The viewport starts in the preamble or top margin. }
    if Cards[I].DocumentTop+Max(1,Cards[I].MeasuredHeight)>Y then begin
      Result.Block:=I; Result.Offset:=(Y-Cards[I].DocumentTop)/Max(1,Cards[I].MeasuredHeight); Break;
    end;
  end;
  if (ActiveBlock>=0) and FormulaBox.Visible and not FormulaEditor.MouseSelecting then begin
    I:=Cards[ActiveBlock].DocumentTop+FormulaBox.Top+FormulaEditor.CaretPoint.Y-Y;
    if (I>=0) and (I<Scroll.ClientHeight) then begin
      Result.Block:=ActiveBlock; Result.CaretY:=I; Result.UseCaret:=True;
    end;
  end;
end;
procedure TMainForm.RestorePreviewAnchor(const Anchor:TPreviewAnchor);
var Y,I:Integer;
begin
  Y:=Anchor.Position;
  if (Anchor.Block>=0) and (Anchor.Block<Length(Cards)) then begin
    Y:=Cards[Anchor.Block].DocumentTop;
    if Anchor.UseCaret and (Anchor.Block=ActiveBlock) and FormulaBox.Visible then
      Inc(Y,FormulaBox.Top+FormulaEditor.CaretPoint.Y-Anchor.CaretY)
    else Inc(Y,Round(Anchor.Offset*Max(1,Cards[Anchor.Block].MeasuredHeight)));
  end;
  FScaleClamped:=False;
  SetPreviewScroll(Scroll,Anchor.Horizontal,Y);
  for I:=0 to High(Cards) do TPreviewPanel(Cards[I].Panel).SyncScrollPosition;
  TrimPreviewCaches;
end;
procedure TMainForm.LayoutCards(Sender: TObject);
var I,J,Y,W,H,IW,LayoutWidth,DocumentWidth,LeftMargin,SavedPosition,SavedHorizontal,Columns,VisualLines,Anchor:Integer;
    Zoom,Ratio,AnchorOffset:Double; ScaleChanged:Boolean; CardWidth,BlockWidth,PanelWidth,ContentWidth,BodyLeft,ContentRight:Integer; PaperWidth,PaperHeight:Double; PDFBlock:Boolean;
begin
  if (FPagedView<>nil) or (FSplitView<>nil) then Exit;
  if not Assigned(Scroll) or FLayoutBusy then Exit;
  if FDocumentDragging or ((FormulaEditor<>nil) and FormulaEditor.MouseSelecting) then Exit;
  FLayoutBusy:=True; SavedPosition:=Scroll.VertScrollBar.Position; SavedHorizontal:=Scroll.HorzScrollBar.Position;
  Scroll.DisableAlign;
  try
    { Keep document positions separate from the scrollbox's shifted children.
      Resetting the scrollbar here moves every native child twice per scroll. }
    { Reserve the vertical scrollbar when scaling, even while it is hidden.
      Otherwise showing it can shrink a nearly fitting document enough to
      hide it again, endlessly alternating editor bounds in LCL layout. }
    LayoutWidth:=PreviewLayoutWidth(Scroll);
    if FFitWidth then W:=Max(100,LayoutWidth-64)
    else W:=Max(100,Round(Min(940,LayoutWidth-64)*FPreviewPercent/100));
    LeftMargin:=Max(16,(Scroll.ClientWidth-W) div 2);
    DocumentWidth:=DocumentPreviewWidth(FEffectivePreamble);
    ContentWidth:=PreviewContentWidth;
    if FFitWidth then Zoom:=(W-24)/Max(1,ContentWidth)
    else Zoom:=Min(FPreviewPercent/100,(W-24)/Max(1,DocumentWidth));
    ScaleChanged:=(FLayoutZoom>0) and not SameValue(Zoom,FLayoutZoom,0.000001);
    Ratio:=1; Anchor:=-1; AnchorOffset:=0;
    if ScaleChanged then begin
      Ratio:=Zoom/FLayoutZoom;
      { Anchor the top of the viewport to the same paragraph, rather than to
        a pixel offset from the old scale. Native widget heights can still
        describe a previous allocation, so use the measured document heights. }
      if FScaleClamped and (SavedPosition=FClampPosition) and (ActiveBlock=FClampBlock) and
         (FClampAnchor>=0) and (FClampAnchor<Length(Cards)) then begin
        Anchor:=FClampAnchor; AnchorOffset:=FClampOffset;
      end else
        for I:=0 to High(Cards) do
          if Cards[I].DocumentTop+Max(1,Cards[I].MeasuredHeight)>SavedPosition then begin
            Anchor:=I; AnchorOffset:=(SavedPosition-Cards[I].DocumentTop)/Max(1,Cards[I].MeasuredHeight); Break;
          end;
      SavedPosition:=16+Round((SavedPosition-16)*Ratio); SavedHorizontal:=Round(SavedHorizontal*Ratio);
    end;
    Y:=16; ContentRight:=W+2*LeftMargin;
    if PreambleEditor<>nil then begin
      if PreambleAvailable and not PluginSourceActive and not Document.PreambleOnly and not FPreviewOnly then begin
        FPreambleToggle.SetDocumentBounds(LeftMargin+12,Y,W-24,28); Inc(Y,32);
      end;
      PreambleEditor.Visible:=PreambleContentVisible;
      if PreambleContentVisible then begin
        IW:=Min(W-24,Round(DocumentWidth*Zoom)); PreambleEditor.PreviewZoom:=Zoom; PreambleEditor.Width:=IW;
        H:=PreambleEditor.PreferredHeight;
        FPreamblePanel.SetDocumentBounds(LeftMargin+(W-IW) div 2,Y,IW,H);
        PreambleEditor.SetBounds(0,0,IW,H); Inc(Y,H+8);
      end;
    end;
    if FBodySeparator<>nil then begin
      FBodySeparator.Visible:=not Document.PreambleOnly and not FPreviewOnly and
        PreambleContentVisible;
      if FBodySeparator.Visible then begin
        FBodySeparator.SetDocumentBounds(LeftMargin+12,Y,W-24,28); Inc(Y,36);
      end;
    end;
    if SourceTools<>nil then SourceTools.Visible:=Editor.Visible and not PluginSourceActive;
    if SourceGrip<>nil then SourceGrip.Visible:=Editor.Visible and not PluginSourceActive;
    for I:=0 to High(Cards) do
    begin
      PlaceLinkedBoundaries(I,False,Y,LeftMargin+12,W-24);
      if Cards[I].Folded then begin
        Cards[I].DocumentTop:=Y; Cards[I].MeasuredHeight:=0; Cards[I].Panel.Visible:=False;
        PlaceLinkedBoundaries(I,True,Y,LeftMargin+12,W-24); Continue;
      end;
      PDFBlock:=Copy(Trim(Document.Blocks[I]),1,11)='\includepdf';
      BlockWidth:=DocumentWidth; CardWidth:=W;
      if PDFBlock then begin
        DocumentPaperSize(FEffectivePreamble,PaperWidth,PaperHeight);
        BlockWidth:=Max(1,Round((PaperWidth+12)*120/72.27));
        CardWidth:=Max(W,Min(LayoutWidth-32,Round(BlockWidth*Zoom)+24));
      end;
      BodyLeft:=(CardWidth-Min(CardWidth-24,Round(BlockWidth*Zoom))) div 2;
      if FFitWidth and not PDFBlock then BodyLeft:=12+Round(FPreviewMarginLeft*Zoom);
      H:=Cards[I].MeasuredHeight;
      if H=0 then H:=Max(40,24+((UTF8Length(Document.Blocks[I])+79) div 80)*22);
      if ScaleChanged then H:=Max(28,Round(H*Ratio));
      if (I=ActiveBlock) and FormulaBox.Visible then
      begin
        IW:=Min(CardWidth-24,Round(BlockWidth*Zoom));
        FormulaEditor.PreviewZoom:=Zoom;
        FormulaEditor.TextAreaWidth:=IW; FormulaEditor.Width:=IW;
        H:=FormulaEditor.PreferredHeight;
        FormulaEditor.SetBounds(0,0,FormulaEditor.PreferredWidth,H);
        FormulaBox.SetBounds(BodyLeft-FormulaEditor.MarginLeft,0,FormulaEditor.PreferredWidth,H);
      end
      else if (I=ActiveBlock) and Editor.Visible then
      begin
        Cards[I].Panel.Width:=W; Editor.Width:=W;
        if (Editor=WrappedEditor) and Assigned(SourceWrap) then
        begin
          SourceWrap.ValidateAll;
          { Include gutter, padding and the native scrollbar in wrap estimates.
            The plugin map may still describe the previous control width. }
          Columns:=Max(1,(W-Editor.Gutter.Width-GetSystemMetrics(SM_CXVSCROLL)-12) div Max(1,Editor.CharWidth));
          VisualLines:=0;
          for J:=0 to Editor.Lines.Count-1 do Inc(VisualLines,Max(1,(UTF8Length(StringReplace(Editor.Lines[J],#9,StringOfChar(' ',Editor.TabWidth),[rfReplaceAll]))+Columns-1) div Columns));
          if SourceWrap.WrapColumn>=Max(2,Columns div 2) then
            VisualLines:=Max(VisualLines,SourceWrap.FLineMapView.ViewedCount)
          else if not FSourceLayoutQueued then begin
            { GTK3 can report a one-column viewport while reparenting. Wait
              until native allocation completes before trusting its wrap map. }
            FSourceLayoutQueued:=True; Application.QueueAsyncCall(@SourceLayoutReady,0);
          end;
          H:=Max(1,VisualLines)*Max(1,Editor.LineHeight)+12;
        end
        else H:=Max(1,Editor.Lines.Count)*Max(1,Editor.LineHeight)+8;
        if not SourceWrapMenuItem.Checked then Inc(H,GetSystemMetrics(SM_CYHSCROLL));
        H:=Max(Editor.LineHeight*3+12,H);
        if FSourceHeight>0 then H:=Max(Editor.LineHeight*3+12,FSourceHeight);
        H:=Min(H,30000); { LCL child coordinates use signed 16-bit positions. }
        SourceGrip.Parent:=Cards[I].Panel; SourceGrip.Align:=alBottom; SourceGrip.Visible:=True;
        Inc(H,SourceGrip.Height);
        if SourceTools<>nil then begin
          SourceTools.Parent:=Cards[I].Panel; SourceTools.Align:=alTop; SourceTools.Visible:=True;
          SourceTools.Top:=0; Inc(H,SourceTools.Height);
        end;
      end
      else if (Cards[I].Draft<>nil) and Cards[I].Draft.Visible then begin
        IW:=Min(CardWidth-24,Round(BlockWidth*Zoom)); Cards[I].Draft.PreviewZoom:=Zoom;
        Cards[I].Draft.TextAreaWidth:=IW; Cards[I].Draft.Width:=IW;
        if ((FPreviewLayoutDeadline=0) or (GetTickCount64<FPreviewLayoutDeadline) or not Cards[I].Draft.LayoutPending) and
           ((Length(Cards)<=24) or (I=ActiveBlock) or
           ((Y+H>=SavedPosition) and (Y<=SavedPosition+Scroll.ClientHeight))) then begin
          H:=Cards[I].Draft.PreferredHeight; Cards[I].MeasuredHeight:=H;
        end;
        Cards[I].Draft.SetBounds(BodyLeft-Cards[I].Draft.MarginLeft,0,Cards[I].Draft.PreferredWidth,H);
      end
      else if Cards[I].Image.PreviewWidth>0 then
      begin
        IW:=Round(Cards[I].Image.PreviewWidth*Zoom);
        if PDFBlock then IW:=Min(IW,CardWidth-24);
        H:=Round(Cards[I].Image.PreviewHeight*IW/Cards[I].Image.PreviewWidth);
        if IW<>Cards[I].Image.Width then FreeAndNil(Cards[I].SelectionModel);
        if PDFBlock then Cards[I].Image.SetBounds((CardWidth-IW) div 2,0,IW,H)
        else Cards[I].Image.SetBounds(BodyLeft+Max(0,(Round(BlockWidth*Zoom)-IW) div 2),0,IW,H);
      end;
      Cards[I].MeasuredHeight:=H;
      Cards[I].DocumentTop:=Y;
      if I=Anchor then SavedPosition:=Y+Round(AnchorOffset*H);
      PanelWidth:=CardWidth;
      if (I=ActiveBlock) and FormulaBox.Visible then PanelWidth:=Max(PanelWidth,FormulaBox.Left+FormulaBox.Width)
      else if (Cards[I].Draft<>nil) and Cards[I].Draft.Visible then
        PanelWidth:=Max(PanelWidth,Cards[I].Draft.Left+Cards[I].Draft.Width)
      else if Cards[I].Image.Visible then PanelWidth:=Max(PanelWidth,Cards[I].Image.Left+Cards[I].Image.Width+12);
      TPreviewPanel(Cards[I].Panel).SetDocumentBounds(Max(16,(Scroll.ClientWidth-CardWidth) div 2),Y,PanelWidth,H);
      ContentRight:=Max(ContentRight,Max(16,(Scroll.ClientWidth-CardWidth) div 2)+PanelWidth+16);
      Cards[I].Panel.Visible:=(I=ActiveBlock) or
        ((Y+H>=SavedPosition-Scroll.ClientHeight) and (Y<=SavedPosition+Scroll.ClientHeight*2));
      if (I<>ActiveBlock) and (Cards[I].Draft<>nil) and
         ((Y+H<SavedPosition-Scroll.ClientHeight) or (Y>SavedPosition+Scroll.ClientHeight*2)) then
        if (Y+H<SavedPosition-Scroll.ClientHeight*3) or (Y>SavedPosition+Scroll.ClientHeight*4) then
          Cards[I].Draft.ReleaseRenderCache;
      Inc(Y,H);
      PlaceLinkedBoundaries(I,True,Y,LeftMargin+12,W-24);
    end;
    { Keep Range >= Page even for a short document: native focus and mouse
      scrolling must not move children when the scrollbar is hidden. }
    Scroll.VertScrollBar.Range:=Max(Y+16,Scroll.ClientHeight);
    Scroll.VertScrollBar.Page:=Max(1,Scroll.ClientHeight);
    Scroll.HorzScrollBar.Visible:=ContentRight>Scroll.ClientWidth;
    Scroll.HorzScrollBar.Range:=Max(ContentRight,Scroll.ClientWidth);
    Scroll.HorzScrollBar.Page:=Max(1,Scroll.ClientWidth); Scroll.HorzScrollBar.Tracking:=True;
    FLayoutZoom:=Zoom;
  finally
    Scroll.EnableAlign; SetPreviewScroll(Scroll,SavedHorizontal,SavedPosition);
    if ScaleChanged then begin
      { A transient native allocation can make the whole document fit and
        clamp scrolling to zero. Retain its logical anchor for the next size. }
      FScaleClamped:=(Anchor>=0) and (SavedPosition>Scroll.VertScrollBar.Position+1);
      FClampAnchor:=Anchor; FClampOffset:=AnchorOffset; FClampPosition:=Scroll.VertScrollBar.Position; FClampBlock:=ActiveBlock;
    end;
    { Updating the range can clamp the scrollbar without moving every child. }
    UpdatePreambleVisibility(Scroll.VertScrollBar.Position);
    if FBodySeparator<>nil then FBodySeparator.SyncScrollPosition;
    for I:=0 to High(FLinkedBoundaryPanels) do FLinkedBoundaryPanels[I].SyncScrollPosition;
    for I:=0 to High(Cards) do TPreviewPanel(Cards[I].Panel).SyncScrollPosition;
    FLayoutBusy:=False;
  end;
  if FFitWidth then begin
    FUpdatingZoom:=True;
    try StatusZoom.Position:=PreviewScalePercent; StatusZoomLabel.Caption:=IntToStr(PreviewScalePercent)+'%';
    finally FUpdatingZoom:=False; end;
  end;
end;

procedure TMainForm.TrimPreviewCaches;
var I,Y:Integer; NeedDraft,Freed:Boolean;
begin
  if FPagedView<>nil then Exit;
  if FLayoutBusy or FDocumentDragging then Exit; NeedDraft:=False; Freed:=False;
  { Visibility and handle changes otherwise trigger a complete LCL layout
    for each card entering or leaving the viewport. }
  Scroll.DisableAlign;
  try
  UpdatePreambleVisibility(Scroll.VertScrollBar.Position);
  for I:=0 to High(FLinkedBoundaryPanels) do begin
    FLinkedBoundaryPanels[I].SyncScrollPosition;
    Y:=FLinkedBoundaryPanels[I].DocumentOrigin.Y-Scroll.VertScrollBar.Position;
    FLinkedBoundaryPanels[I].Visible:=not FPreviewOnly and
      (Y+FLinkedBoundaryPanels[I].Height>=-Scroll.ClientHeight) and (Y<=Scroll.ClientHeight*2);
  end;
  for I:=0 to High(Cards) do begin
    Y:=Cards[I].DocumentTop-Scroll.VertScrollBar.Position;
    TPreviewPanel(Cards[I].Panel).SyncScrollPosition;
    if I=ActiveBlock then Continue;
    Cards[I].Panel.Visible:=not Cards[I].Folded and (Y+Cards[I].Panel.Height>=-Scroll.ClientHeight) and (Y<=Scroll.ClientHeight*2);
    if not Cards[I].Folded and (Y+Cards[I].Panel.Height>=0) and (Y<=Scroll.ClientHeight) and
       (not FPermanentAvailable or Cards[I].PartlyFolded or (Cards[I].Image.PreviewWidth=0) or (Copy(Cards[I].SourceKey,1,9)='\appendix')) then
      if (Cards[I].Draft=nil) or Cards[I].Draft.LayoutPending then NeedDraft:=True;
    if not Cards[I].Panel.Visible then begin
      Freed:=Freed or (Cards[I].Draft<>nil) or Cards[I].Panel.HandleAllocated;
      Cards[I].Image.ReleaseRenderCache;
      FreeAndNil(Cards[I].Draft); FreeAndNil(Cards[I].SelectionModel);
      TPreviewPanel(Cards[I].Panel).ReleaseNativeCache;
    end;
  end;
  if Freed and (FMemoryTrimDue>GetTickCount64+1200) then FMemoryTrimDue:=GetTickCount64+1200;
  if NeedDraft then begin UpdatePreviewCards(-1); LayoutCards(nil); end;
  finally Scroll.EnableAlign; end;
end;

procedure TMainForm.SourceLayoutReady(Data:PtrInt);
begin
  { Keep the flag set through layout to avoid an idle retry loop when hidden. }
  try if Editor.Visible and not FLoading then LayoutCards(nil);
  finally FSourceLayoutQueued:=False; end;
end;

procedure TMainForm.WindowActivated(Sender:TObject);
begin
  { Let the widget set restore focus. Never rebuild/reparent controls on activation. }
  if Assigned(Timer) then Timer.Enabled:=True;
  if Assigned(FormulaEditor) then FormulaEditor.Invalidate;
end;

procedure TMainForm.WindowDeactivated(Sender:TObject);
begin
  FDocumentDragging:=False;
  if Assigned(FormulaEditor) then FormulaEditor.QueueFocusCompletion;
  if Assigned(PreambleEditor) then PreambleEditor.QueueFocusCompletion;
end;

procedure TMainForm.CardClick(Sender: TObject);
var Index,Offset:Integer; P:TPoint;
begin
  if FPagedView<>nil then Exit;
  if PluginSourceActive then begin if Editor.CanFocus then Editor.SetFocus; Exit; end;
  if not FReplayingAction then FDeferredClick:=Mouse.CursorPos;
  if DeferInput(@CardClick,Sender) then Exit;
  Index:=TControl(Sender).Tag;
  P:=Cards[Index].Image.ScreenToClient(FDeferredClick);
  Offset:=ParagraphHitOffset(Index,P);
  EquationMode:=True;
  if Index=ActiveBlock then
  begin
    if Editor.Visible then LoadEquation;
  end
  else EditBlock(Index);
  if FormulaBox.Visible then
  begin
    FormulaEditor.SetSourceCaret(Offset);
    if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
    RevealVisualCaret;
  end;
end;

procedure TMainForm.EditBlock(Index: Integer);
var SavedPosition,Anchor,EmptyIndex:Integer;
begin
  if PluginSourceActive then begin if Editor.CanFocus then Editor.SetFocus; Exit; end;
  if (Index<0) or (Index>High(Cards)) or (Index=ActiveBlock) then Exit;
  if ActiveBlock>=0 then FormulaEditor.FinishVisualSource;
  if ActiveBlock>=0 then FormulaEditor.FinishEmptyScript(True);
  FormulaEditor.FinishDefinitionEdit;
  SavedPosition:=Scroll.VertScrollBar.Position;
  if (ActiveBlock>=0) and (Document.Blocks.Count>1) and (Trim(Document.Blocks[ActiveBlock])='') then
  begin
    EmptyIndex:=ActiveBlock;
    { Remove the editing slot while preserving whitespace in the source. }
    if EmptyIndex>0 then Document.Blocks[EmptyIndex-1]:=Document.Blocks[EmptyIndex-1]+Document.Blocks[EmptyIndex]
    else Document.Blocks[1]:=Document.Blocks[0]+Document.Blocks[1];
    Document.Blocks.Delete(EmptyIndex);
    if Index>EmptyIndex then Dec(Index);
    BuildCards; SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,SavedPosition);
  end;
  Anchor:=Cards[Index].DocumentTop;
  if ActiveBlock>=0 then
  begin
    Cards[ActiveBlock].Image.Visible:=True;
    if Cards[ActiveBlock].Draft<>nil then begin Cards[ActiveBlock].Draft.Visible:=True; Cards[ActiveBlock].Image.Visible:=False; end;
  end;
  Editor.Visible:=False;
  FormulaBox.Visible:=False;
  FLoading:=True;
  try
    ActiveBlock:=Index;
    Editor.Parent:=Cards[Index].Panel; Editor.Align:=alClient;
    if Editor.Text<>Document.Blocks[Index] then begin Editor.Text:=Document.Blocks[Index]; Editor.ClearUndo; end;
    if not FSwitchingDocument then Editor.ClearUndo;
    Cards[Index].Image.Visible:=False;
    Editor.Visible:=not EquationMode;
  finally FLoading:=False; end;
  if EquationMode then LoadEquation else SourceSelectionChanged(Editor,[]);
  LayoutCards(nil);
  SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,SavedPosition+Cards[Index].DocumentTop-Anchor);
  SavedPosition:=Scroll.VertScrollBar.Position;
  if not FSyncingFullSource then begin
    if Editor.Visible and Editor.CanFocus then Editor.SetFocus
    else if FormulaBox.Visible and FormulaEditor.CanFocus then FormulaEditor.SetFocus;
  end;
  SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,SavedPosition);
end;

procedure TMainForm.SourceModeClick(Sender: TObject);
var Index: Integer;
begin
  if DeferInput(@SourceModeClick,Sender) then Exit;
  if FSplitView<>nil then begin FFullSource.SourceEditor.SetFocus; Exit; end;
  if CurrentVisualEditor<>nil then CurrentVisualEditor.FinishVisualSource;
  if (FPagedView<>nil) and not PluginSourceActive then begin
    FormulaEditor.SetParagraphSourceMode(True);
    if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
    UpdateStatusBar; Exit;
  end;
  if PluginSourceActive then begin ShowPluginSourceEditor; if Editor.CanFocus then Editor.SetFocus; Exit; end;
  if Document.PreambleOnly then begin EquationModeClick(nil); Exit; end;
  FormulaEditor.FinishDefinitionEdit;
  ClearDocumentSelection;
  EquationMode := False; FPreambleEditing:=False;
  Index := ActiveBlock; if Index < 0 then Index := 0;
  ActiveBlock := -1; EditBlock(Index);
  Ribbon.ActivePageIndex := 0;
end;

procedure TMainForm.EquationModeClick(Sender: TObject);
begin
  if DeferInput(@EquationModeClick,Sender) then Exit;
  ExitSplitView;
  if (FPagedView<>nil) and not PluginSourceActive then begin
    FormulaEditor.SetParagraphSourceMode(False);
    if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
    UpdateStatusBar; Exit;
  end;
  if PluginSourceActive then begin ShowPluginSourceEditor; Exit; end;
  EquationMode := True; FPreviewOnly:=False; FPreambleEditing:=False;
  if Document.PreambleOnly then begin
    LayoutCards(nil); FPreambleEditing:=True;
    if PreambleEditor.CanFocus then PreambleEditor.SetFocus;
    Exit;
  end;
  if ActiveBlock < 0 then EditBlock(0) else if not FormulaBox.Visible then LoadEquation;
  FormulaEditor.SelectFormula(FormulaIndex);
  if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
end;

procedure TMainForm.LoadEquation;
var I,SavedPosition,BeforeOffset:Integer; Directory,Declarations:string; SharedContext:TTeXContext;
begin
  if ActiveBlock<0 then Exit;
  SavedPosition:=Scroll.VertScrollBar.Position;
  Editor.Visible:=False;
  FormulaSpans:=FindMath(Document.Blocks[ActiveBlock]);
  FLoading:=True;
  try
    if EquationSelector.Showing then begin
      EquationSelector.Items.Clear;
      for I:=0 to High(FormulaSpans) do EquationSelector.Items.Add('Formula '+IntToStr(I+1));
    end;
    if FormulaIndex>High(FormulaSpans) then FormulaIndex:=0;
    if (Length(FormulaSpans)>0) and EquationSelector.Showing then EquationSelector.ItemIndex:=FormulaIndex;
  finally FLoading:=False; end;
  FormulaBox.Parent:=Cards[ActiveBlock].Panel;
  FormulaBox.Visible:=True;
  Directory:=DocumentDirectory;
  FormulaEditor.SetContext(FEffectivePreamble+FProjectBefore,Directory,Engine.Text,'',False);
  Declarations:=''; BeforeOffset:=0; SharedContext:=nil;
  for I:=0 to ActiveBlock-1 do begin
    Declarations:=Declarations+Cards[I].Declarations; Inc(BeforeOffset,Length(Document.Blocks[I]));
  end;
  if (FSessions<>nil) and (FSessionIndex>=0) then SharedContext:=TOpenDocument(FSessions[FSessionIndex]).PreviewContext;
  FormulaEditor.SetDocumentContext(Document.Blocks,ActiveBlock,SharedContext,Declarations,BeforeOffset);
  FormulaEditor.SetFoldedRanges(FFoldedSources,Document.SourceOffset(ActiveBlock,0),Length(Document.Blocks[ActiveBlock]));
  if Cards[ActiveBlock].SourceKey<>Trim(Document.Blocks[ActiveBlock]) then
    FormulaEditor.LoadParagraph(Document.Blocks[ActiveBlock],nil)
  else FormulaEditor.LoadParagraph(Document.Blocks[ActiveBlock],nil,
    Cards[ActiveBlock].LayoutXML,Cards[ActiveBlock].LayoutPage,Cards[ActiveBlock].Positions);
  if Cards[ActiveBlock].SourceKey=Trim(Document.Blocks[ActiveBlock]) then
    FormulaEditor.SetGeneratedPreview(Cards[ActiveBlock].Image,Cards[ActiveBlock].LayoutXML,Cards[ActiveBlock].LayoutPage)
  else FormulaEditor.SetGeneratedPreview(nil);
  if MacroSelector.Showing then begin
    FLoading:=True;
    try FormulaEditor.MacroNames(MacroSelector.Items); finally FLoading:=False; end;
  end;
  Cards[ActiveBlock].Image.Visible:=False;
  if Cards[ActiveBlock].Draft<>nil then begin Cards[ActiveBlock].Draft.Visible:=False; FormulaEditor.PreviewFrame:=Cards[ActiveBlock].Draft.PreviewFrame; end
  else FormulaEditor.PreviewFrame:=0;
  StatusText:='Visual editing · click text or mathematics · Source opens LaTeX manually';
  RefreshFields; RefreshParagraphStyles(nil); LayoutCards(nil);
  SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,SavedPosition);
end;

procedure TMainForm.EquationSelected(Sender: TObject);
begin
  if FLoading or (EquationSelector.ItemIndex<0) then Exit;
  FormulaIndex:=EquationSelector.ItemIndex;
  FormulaEditor.SelectFormula(FormulaIndex);
  if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
end;

procedure TMainForm.RefreshFields(Force:Boolean);
begin
  { These legacy selectors also supply navigation menus. Populate hidden
    native list models only when the corresponding menu is opened. }
  if not Force and not FieldSelector.Showing then Exit;
  FLoading:=True;
  try
    if FFieldsRevision<>FormulaEditor.FieldsRevision then begin
      FieldSelector.Items.BeginUpdate;
      try FormulaEditor.FieldNames(FieldSelector.Items); finally FieldSelector.Items.EndUpdate; end;
      FFieldsRevision:=FormulaEditor.FieldsRevision;
    end;
    FieldSelector.ItemIndex:=FormulaEditor.ActiveField;
  finally FLoading:=False; end;
end;

procedure TMainForm.VisualSelectionChanged(Sender:TObject);
var Anchor,Focus:Integer;
begin
  if FPagedView<>nil then begin
    if Sender=FPagedView.VisualEditor then PagedSelectionChanged(FPagedView);
    Exit;
  end;
  if FLoading then Exit;
  FormulaEditor.GetSourceSelection(Anchor,Focus);
  if FormulaEditor.VerticalNavigation and not FormulaEditor.SelectionGesture and
     (Anchor=Focus) and not FDocumentDragging then RevealVisualCaret;
  FPreambleEditing:=False; UpdateStatusBar;
  if FormulaEditor.FormulaSourceMode and not FormulaEditor.EditingSourcePreview then FormulaEditor.FormulaSourceMode:=False;
  if FormulaSourceButton<>nil then FormulaSourceButton.Down:=FormulaEditor.FormulaSourceMode;
  if FDocumentDragging or FormulaEditor.MouseSelecting then begin SyncFullSource; Exit; end;
  RefreshFields; RefreshFontControls; UpdateParagraphControl(FormulaEditor.CurrentParagraphStyle);
  UpdateContextTabs(FormulaEditor.MathActive,FormulaEditor.EditingTable or
    (Pos('\begin{table',FormulaEditor.CurrentFloatSource)=1),
    FormulaEditor.EditingTheorem,
    not FDocumentDragging and not FormulaEditor.SelectionGesture,FormulaEditor.EditingFigure);
  SyncFullSource;
end;

procedure TMainForm.FieldSelected(Sender:TObject);
begin
  if not FLoading and (FieldSelector.ItemIndex>=0) then
  begin
    FormulaEditor.SelectField(FieldSelector.ItemIndex);
    if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
  end;
end;

procedure TMainForm.MacroSelected(Sender:TObject);
begin
  if FLoading or (MacroSelector.ItemIndex<0) or not BodyEditing then Exit;
  if DeferInput(@MacroSelected,Sender) then Exit;
  FormulaEditor.InsertCommand(FormulaEditor.MacroTemplate(MacroSelector.Text));
  MacroSelector.ItemIndex:=-1;
  if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
end;

procedure TMainForm.TemplateSelected(Sender:TObject);
var K:TMathKind;
begin
  if FLoading or (TemplateSelector.ItemIndex<0) then Exit;
  if DeferInput(@TemplateSelected,Sender) then Exit;
  if not FormulaBox.Visible then EquationModeClick(nil);
  if not FormulaBox.Visible then Exit;
  case TemplateSelector.ItemIndex of
    0: K:=mkIndexedRoot; 1: K:=mkMatrix; 2: K:=mkCases; 3: K:=mkAligned;
    4: K:=mkBinomial; 5: K:=mkAccent;
    else K:=mkRaw;
  end;
  if K<>mkRaw then FormulaEditor.InsertStructure(K)
  else case TemplateSelector.ItemIndex of
    6:FormulaEditor.InsertTeX('\sum_{n=1}^{\infty} a_n');
    7:FormulaEditor.InsertTeX('\int_a^b f(x)\,dx');
    else FormulaEditor.InsertTeX('\lim_{x\to 0} f(x)');
  end;
  TemplateSelector.ItemIndex:=-1;
  if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
end;

procedure TMainForm.SyncLabelReferences(const Before,After:string);
var OldKeys,NewKeys:TStringList; J,Caret,Anchor,Dummy:Integer; S:string; SourceMode:Boolean;
begin
  SourceMode:=Editor.Visible;
  Document.Blocks[ActiveBlock]:=After; OldKeys:=TStringList.Create; NewKeys:=TStringList.Create;
  try
    ChangedLabels(Before,After,OldKeys,NewKeys);
    if SourceMode then begin
      Caret:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.LogicalCaretXY]);
      Anchor:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockBegin]);
      if Anchor=Caret then Anchor:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockEnd]);
    end else FormulaEditor.GetSourceSelection(Anchor,Caret);
    if OldKeys.Count>0 then begin
      Dummy:=0; Document.Preamble:=RenameReferenceKeys(Document.Preamble,OldKeys,NewKeys,Dummy);
      Dummy:=0; Document.Ending:=RenameReferenceKeys(Document.Ending,OldKeys,NewKeys,Dummy);
      for J:=0 to Document.Blocks.Count-1 do begin
        S:=Document.Blocks[J]; Dummy:=0; if J=ActiveBlock then Dummy:=Caret;
        Document.Blocks[J]:=RenameReferenceKeys(S,OldKeys,NewKeys,Dummy);
        if J=ActiveBlock then begin Caret:=Dummy; RenameReferenceKeys(S,OldKeys,NewKeys,Anchor); end;
      end;
    end;
    S:=Document.Blocks[ActiveBlock];
    if SourceMode then begin
      if S<>Editor.Text then begin
        FLoading:=True; Editor.BeginUndoBlock;
        try Editor.SelectAll; Editor.SelText:=S; Editor.BlockBegin:=BytePoint(S,Anchor);
          Editor.BlockEnd:=BytePoint(S,Caret); Editor.LogicalCaretXY:=BytePoint(S,Caret);
        finally Editor.EndUndoBlock; FLoading:=False; end;
      end;
    end else if S<>FormulaEditor.Formula then begin
      FLoading:=True; try FormulaEditor.ReplaceSource(S,Caret); FormulaEditor.SetSourceSelection(Anchor,Caret); finally FLoading:=False; end;
    end;
  finally NewKeys.Free; OldKeys.Free; end;
end;

procedure TMainForm.FormulaChanged(Sender: TObject);
var I:Integer;
begin
  if FPagedView<>nil then Exit;
  if FLoading or FRestoringHistory or (ActiveBlock<0) then Exit;
  if Document.Blocks[ActiveBlock]=FormulaEditor.Formula then Exit;
  ClearDocumentSelection;
  if not FormulaEditor.FormattingSource then RecordVisualEdit(FormulaEditor.EditCaretBefore);
  SyncLabelReferences(Document.Blocks[ActiveBlock],FormulaEditor.Formula);
  FormulaSpans:=FindMath(Document.Blocks[ActiveBlock]);
  FLoading:=True;
  try
    Editor.Text:=Document.Blocks[ActiveBlock];
    if EquationSelector.Showing then begin
      EquationSelector.Items.Clear;
      for I:=0 to High(FormulaSpans) do EquationSelector.Items.Add('Formula '+IntToStr(I+1));
    end;
  finally FLoading:=False; end;
  RefreshFields; UpdateParagraphControl(FormulaEditor.CurrentParagraphStyle);
  if (CommandsTab<>nil) and (CommandsTab.TabVisible or FormulaEditor.EditingDefinition) then
    UpdateContextTabs(FormulaEditor.MathActive,FormulaEditor.EditingTable,FormulaEditor.EditingTheorem,False);
  Modified:=True; UpdateTitle; QueuePreview(True);
  if not FReblockQueued then
  begin FReblockQueued:=True; Application.QueueAsyncCall(@ReblockVisual,0); end;
  SyncFullSource;
end;

procedure TMainForm.ReblockVisual(Data:PtrInt);
var Parts:TTeXDocument; Index,Target,Offset,I,SavedScroll:Integer;
begin
  if not FReblockQueued or FRestoringHistory then Exit;
  SavedScroll:=Scroll.VertScrollBar.Position;
  FReblockQueued:=False;
  if FLoading or not FormulaBox.Visible or (ActiveBlock<0) then Exit;
  Parts:=TTeXDocument.Create;
  try
    Parts.Parse(Document.Blocks[ActiveBlock]);
    if (Parts.Preamble<>'') or (Parts.Ending<>'') or (Parts.Blocks.Count<2) then Exit;
    Offset:=FormulaEditor.SourceCaret; Target:=0;
    while (Target<Parts.Blocks.Count-1) and (Offset>=Length(Parts.Blocks[Target])) do
    begin Dec(Offset,Length(Parts.Blocks[Target])); Inc(Target); end;
    Index:=ActiveBlock; Document.Blocks[Index]:=Parts.Blocks[0];
    for I:=1 to Parts.Blocks.Count-1 do Document.Blocks.Insert(Index+I,Parts.Blocks[I]);
    BuildCards; EditBlock(Index+Target); FormulaEditor.SetSourceCaret(Offset); SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,SavedScroll); QueuePreview;
  finally Parts.Free; end;
end;

procedure TMainForm.EquationActionsClick(Sender:TObject);
var P:TPoint;
begin
  P:=EquationActionsButton.ClientToScreen(Point(0,EquationActionsButton.Height));
  EquationActionsPopup.PopUp(P.X,P.Y);
end;
procedure TMainForm.EquationActionClick(Sender:TObject);
var ActionKind,Index:Integer;
begin
  if DeferInput(@EquationActionClick,Sender) then Exit;
  if not BodyEditing then EquationModeClick(nil);
  if not BodyEditing then Exit;
  ActionKind:=TComponent(Sender).Tag div 100; Index:=TComponent(Sender).Tag mod 100;
  if ActionKind=3 then
  begin
    if not FormulaEditor.EditGrid(Index) then StatusText:='Place the caret in an alignment or matrix first.';
  end
  else if (Index>=0) and (Index<=High(FormulaKinds)) then
    FormulaEditor.SetFormulaKind(FormulaKinds[Index],ActionKind=1);
  if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
end;
procedure TMainForm.InsertEquationClick(Sender: TObject);
begin
  if DeferInput(@InsertEquationClick,Sender) then Exit;
  if not FormulaBox.Visible then EquationModeClick(nil);
  if FormulaBox.Visible then
  begin
    FormulaEditor.InsertEquation('');
    if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
  end;
end;

procedure TMainForm.StructureClick(Sender: TObject);
begin
  if DeferInput(@StructureClick,Sender) then Exit;
  if not BodyEditing then EquationModeClick(nil);
  if BodyEditing then FormulaEditor.InsertStructure(TMathKind(TComponent(Sender).Tag));
  if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
end;

procedure TMainForm.SymbolClick(Sender: TObject);
const Symbols:array[0..5] of string=('\alpha','\beta','\pi','\sum','\int','\infty');
var Index:Integer;
begin
  if DeferInput(@SymbolClick,Sender) then Exit;
  if not BodyEditing then EquationModeClick(nil);
  Index:=TComponent(Sender).Tag;
  if BodyEditing and (Index>=Low(Symbols)) and (Index<=High(Symbols)) then
    FormulaEditor.InsertTeX(Symbols[Index]);
  if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
end;

procedure TMainForm.FormatClick(Sender: TObject);
var Command,Value,AllText:string; A,B,PrefixLength,SavedScroll:Integer; SelStart,SelEnd:TPoint;
begin
  if DeferInput(@FormatClick,Sender) then Exit;
  SavedScroll:=Scroll.VertScrollBar.Position;
  try
  case TComponent(Sender).Tag of
    0:Command:='\textbf'; 1:Command:='\textit'; 2:Command:='\section';
    3:Command:='\subsection'; 4:Command:='\subsubsection';
    5:Command:='\section*'; 6:Command:='\subsection*'; 8:Command:=''; else Command:='\subsubsection*';
  end;
  if PluginSourceActive then begin
    FormatPluginSelection(Command);
    if Editor.CanFocus then Editor.SetFocus; Exit;
  end;
  if Editor.Visible then
  begin
    if (TComponent(Sender).Tag>=2) and (Command<>'') and (Editor.SelText<>'') then
      Editor.SelText:=Command+'{'+Editor.SelText+'}'
    else if TComponent(Sender).Tag>=2 then
    begin
      Value:=Trim(Editor.Lines[Editor.CaretY-1]);
      if (Pos('\section',Value)=1) or (Pos('\subsection',Value)=1) or (Pos('\subsubsection',Value)=1) then
        if (Pos('{',Value)>0) and (Value[Length(Value)]='}') then
          Value:=Copy(Value,Pos('{',Value)+1,Length(Value)-Pos('{',Value)-1);
      if Command='' then Editor.Lines[Editor.CaretY-1]:=Value
      else Editor.Lines[Editor.CaretY-1]:=Command+'{'+Value+'}';
    end
    else
    begin
      SelStart:=Editor.BlockBegin; SelEnd:=Editor.BlockEnd;
      A:=Length(Editor.TextBetweenPoints[Point(1,1),SelStart]); B:=Length(Editor.TextBetweenPoints[Point(1,1),SelEnd]);
      AllText:=Editor.Text; Value:=Editor.SelText; PrefixLength:=Length(Command)+1;
      if (A>=PrefixLength) and (Copy(AllText,A-PrefixLength+1,PrefixLength)=Command+'{') and (Copy(AllText,B+1,1)='}') then
      begin
        Editor.BlockBegin:=BytePoint(AllText,A-PrefixLength); Editor.BlockEnd:=BytePoint(AllText,B+1);
        Editor.SelText:=Value; Dec(A,PrefixLength);
      end else begin
        if Value='' then Value:='Text'; Editor.SelText:=Command+'{'+Value+'}'; Inc(A,PrefixLength);
      end;
      Editor.BlockBegin:=BytePoint(Editor.Text,A); Editor.BlockEnd:=BytePoint(Editor.Text,A+Length(Value));
      SourceSelectionChanged(Editor,[]);
    end;
    Editor.SetFocus;
  end
  else
  begin
    if not BodyEditing then EquationModeClick(nil);
    if TComponent(Sender).Tag>=2 then FormulaEditor.SetHeading(Command)
    else FormulaEditor.FormatText(Command);
    if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
  end;
  finally SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,SavedScroll); end;
end;

procedure TMainForm.HeadingClick(Sender:TObject);
var P:TPoint;
begin
  P:=HomeTextHeadingButton.ClientToScreen(Point(0,HomeTextHeadingButton.Height));
  HeadingPopup.PopUp(P.X,P.Y);
end;
procedure TMainForm.SourceWrapClick(Sender:TObject);
var OldEditor,NewEditor:TSynEdit;
    Caret,SelBegin,SelEnd:TPoint; SavedTop:Integer; WasFocused,WasLoading:Boolean;
begin
  OldEditor:=Editor;
  Caret:=OldEditor.LogicalCaretXY; SelBegin:=OldEditor.BlockBegin; SelEnd:=OldEditor.BlockEnd;
  SavedTop:=OldEditor.TopLine; WasFocused:=OldEditor.Focused; WasLoading:=FLoading; FLoading:=True;
  if OldEditor=WrappedEditor then NewEditor:=PlainEditor else NewEditor:=WrappedEditor;
  try
    if NewEditor=nil then
    begin
      NewEditor:=TSynEdit.Create(Self); PlainEditor:=NewEditor;
      NewEditor.SetDefaultKeystrokes; NewEditor.ResetMouseActions;
      EnableSourceLinks(NewEditor);
    end;
    NewEditor.Visible:=False; NewEditor.Parent:=OldEditor.Parent;
    NewEditor.BoundsRect:=OldEditor.BoundsRect; NewEditor.Align:=OldEditor.Align;
    NewEditor.Font.PixelsPerInch:=OldEditor.Font.PixelsPerInch;
    NewEditor.Font.Assign(OldEditor.Font); UseNativeSourceFonts(NewEditor); NewEditor.Color:=OldEditor.Color;
    NewEditor.Options:=OldEditor.Options+[eoPersistentCaret]-[eoScrollPastEol];
    NewEditor.Options2:=OldEditor.Options2+[eoPersistentCaretStopBlink]-[eoScrollPastEolAddPage,eoScrollPastEolAutoCaret];
    NewEditor.Highlighter:=OldEditor.Highlighter; NewEditor.PopupMenu:=OldEditor.PopupMenu;
    { SynEdit gutter Assign shallow-copies its owned part list. Keep each
      editor's own parts; otherwise toggling wrap double-frees them on shutdown. }
    NewEditor.Gutter.Color:=OldEditor.Gutter.Color;
    NewEditor.Gutter.Visible:=OldEditor.Gutter.Visible;
    NewEditor.Gutter.Width:=OldEditor.Gutter.Width;
    NewEditor.TabWidth:=OldEditor.TabWidth;
    NewEditor.Keystrokes.Assign(OldEditor.Keystrokes); NewEditor.ReadOnly:=OldEditor.ReadOnly;
    if NewEditor.Text<>OldEditor.Text then
    begin NewEditor.Text:=OldEditor.Text; NewEditor.ClearUndo; end;
    NewEditor.OnChange:=@EditorChanged; NewEditor.OnKeyDown:=@EditorKeyDown; NewEditor.OnMouseDown:=@SourceMouseDown;
    NewEditor.OnProcessCommand:=@SourceCommandBefore; NewEditor.OnCommandProcessed:=@SourceCommandAfter; NewEditor.OnStatusChange:=@SourceSelectionChanged;
    SetMenuChecked(SourceWrapMenuItem,NewEditor=WrappedEditor);
    SourceWrapButton.Down:=SourceWrapMenuItem.Checked;
    if SourceWrapMenuItem.Checked then NewEditor.ScrollBars:=ssVertical
    else NewEditor.ScrollBars:=ssBoth;
    NewEditor.LeftChar:=1; NewEditor.Visible:=OldEditor.Visible;
    Editor:=NewEditor;
    OldEditor.Visible:=False; OldEditor.Align:=alNone; OldEditor.Parent:=Self;
    Editor.LogicalCaretXY:=Caret; Editor.BlockBegin:=SelBegin; Editor.BlockEnd:=SelEnd; Editor.TopLine:=SavedTop;
    if SourceWrapMenuItem.Checked then Editor.LeftChar:=1;
    LayoutCards(nil);
    if WasFocused and Editor.CanFocus then Editor.SetFocus;
  finally FLoading:=WasLoading; end;
end;

procedure TMainForm.RecordVisualEdit(Caret:Integer);
begin
  if FRestoringHistory then Exit;
  if Caret<0 then begin
    if FPreambleEditing then Caret:=FPreambleFields.SourceOffset(PreambleEditor.SourceCaret)
    else Caret:=FormulaEditor.SourceCaret;
  end;
  if FPreambleEditing then FVisualUndo.Add(TDocumentSnapshot.Create(Document,-2,Caret))
  else FVisualUndo.Add(TDocumentSnapshot.Create(Document,ActiveBlock,Caret));
  if FVisualUndo.Count>100 then FVisualUndo.Delete(0);
  FVisualRedo.Clear;
end;

procedure TMainForm.RestoreVisualEdit(Undoing:Boolean);
var FromList,ToList:TObjectList; Snapshot:TDocumentSnapshot; Index:Integer;
begin
  if Undoing then begin FromList:=FVisualUndo; ToList:=FVisualRedo; end
  else begin FromList:=FVisualRedo; ToList:=FVisualUndo; end;
  if FromList.Count=0 then Exit;
  if FPreambleEditing then ToList.Add(TDocumentSnapshot.Create(Document,-2,FPreambleFields.SourceOffset(PreambleEditor.SourceCaret)))
  else ToList.Add(TDocumentSnapshot.Create(Document,ActiveBlock,FormulaEditor.SourceCaret));
  Snapshot:=TDocumentSnapshot(FromList.Extract(FromList.Last));
  FRestoringHistory:=True; FReblockQueued:=False; FPreambleRefreshDue:=0;
  try
    Inc(Revision); if Worker<>nil then Worker.Terminate;
    Document.Blocks.Assign(Snapshot.Blocks); Document.Preamble:=Snapshot.Preamble; Document.Ending:=Snapshot.Ending;
    Document.PreambleOnly:=Snapshot.PreambleOnly;
    if not Document.PreambleOnly and (Document.Blocks.Count=0) then Document.Blocks.Add('');
    Index:=Max(0,Min(Snapshot.BlockIndex,Document.Blocks.Count-1));
    BuildCards;
    if Document.PreambleOnly or (Snapshot.BlockIndex=-2) then begin
      FPreviewOnly:=False; SetPreambleExpanded(True); LayoutCards(nil); FPreambleEditing:=True;
      PreambleEditor.SetSourceCaret(Max(0,FPreambleFields.DisplayOffset(Snapshot.Caret)));
      if PreambleEditor.CanFocus then PreambleEditor.SetFocus;
    end else begin EditBlock(Index); FormulaEditor.SetSourceCaret(Snapshot.Caret); end;
    Modified:=True; UpdateTitle; QueuePreview;
  finally FRestoringHistory:=False; Snapshot.Free; end;
end;

procedure TMainForm.UndoClick(Sender: TObject);
begin
  if DeferInput(@UndoClick,Sender) then Exit;
  if FSplitView<>nil then begin FFullSource.SourceEditor.Undo; Exit; end;
  if FPagedView<>nil then begin FPagedView.Undo; Exit; end;
  if Editor.Visible and not FPreambleEditing then Editor.Undo else RestoreVisualEdit(True);
end;

procedure TMainForm.RedoClick(Sender: TObject);
begin
  if DeferInput(@RedoClick,Sender) then Exit;
  if FSplitView<>nil then begin FFullSource.SourceEditor.Redo; Exit; end;
  if FPagedView<>nil then begin FPagedView.RedoEdit; Exit; end;
  if Editor.Visible and not FPreambleEditing then Editor.Redo else RestoreVisualEdit(False);
end;

procedure TMainForm.ClipboardClick(Sender:TObject);
var Handled:Boolean;
begin
  if FSplitView<>nil then begin
    case TComponent(Sender).Tag of
      VK_X:FFullSource.SourceEditor.CutToClipboard;
      VK_C:FFullSource.SourceEditor.CopyToClipboard;
      VK_V:FFullSource.SourceEditor.PasteFromClipboard;
      VK_A:FFullSource.SourceEditor.SelectAll;
    end;
    Exit;
  end;
  if FPreambleEditing and (PreambleEditor<>nil) then begin
    PreambleEditor.ClipboardCommand(TComponent(Sender).Tag); Exit;
  end;
  if BodyEditing then
  begin
    Handled:=False; DocumentKey(Self,TComponent(Sender).Tag,[ssCtrl],Handled);
    if Handled then Exit;
  end;
  if ActiveControl is TCustomEdit then
  begin
    case TComponent(Sender).Tag of
      VK_X:TCustomEdit(ActiveControl).CutToClipboard;
      VK_C:TCustomEdit(ActiveControl).CopyToClipboard;
      VK_V:TCustomEdit(ActiveControl).PasteFromClipboard;
      VK_A:TCustomEdit(ActiveControl).SelectAll;
    end;
    Exit;
  end;
  if DeferInput(@ClipboardClick,Sender) then Exit;
  if Editor.Visible then
    case TComponent(Sender).Tag of
      VK_X:Editor.CommandProcessor(ecCut,'',nil);
      VK_C:Editor.CopyToClipboard;
      VK_V:Editor.CommandProcessor(ecPaste,'',nil);
      VK_A:Editor.SelectAll;
    end
  else if BodyEditing then FormulaEditor.ClipboardCommand(TComponent(Sender).Tag);
end;

procedure TMainForm.ExitClick(Sender:TObject);
begin Close; end;

function TMainForm.MenuSelector(Kind:Integer):TComboBox;
begin
  case Kind of
    0:Result:=EquationSelector;
    1:Result:=FieldSelector;
    2:Result:=TemplateSelector;
    3:Result:=MacroSelector;
    else Result:=Engine;
  end;
end;

procedure TMainForm.PopulateSelectorMenu(Sender:TObject);
var MenuGroup,Item:TMenuItem; Selector:TComboBox; I:Integer;
begin
  MenuGroup:=TMenuItem(Sender); Selector:=MenuSelector(MenuGroup.Tag);
  if BodyEditing then begin
    if (FPagedView<>nil) and (MenuGroup.Tag=0) then FormulaSpans:=FindMath(FormulaEditor.Formula);
    if MenuGroup.Tag=1 then RefreshFields(True);
    if MenuGroup.Tag in [0,3] then begin
      FLoading:=True; Selector.Items.BeginUpdate;
      try
        if MenuGroup.Tag=3 then FormulaEditor.MacroNames(Selector.Items)
        else begin
          Selector.Items.Clear;
          for I:=0 to High(FormulaSpans) do Selector.Items.Add('Formula '+IntToStr(I+1));
          if Length(FormulaSpans)>0 then Selector.ItemIndex:=FormulaIndex;
        end;
      finally Selector.Items.EndUpdate; FLoading:=False; end;
    end;
  end;
  MenuGroup.Clear;
  if (Selector.Items.Count=0) or
     ((MenuGroup.Tag in [0,1,3]) and not BodyEditing) then
  begin
    Item:=TMenuItem.Create(Self); Item.Caption:='(No items available)';
    Item.Enabled:=False; MenuGroup.Add(Item); Exit;
  end;
  for I:=0 to Selector.Items.Count-1 do
  begin
    Item:=TMenuItem.Create(Self);
    Item.Caption:=StringReplace(Selector.Items[I],'&','&&',[rfReplaceAll]);
    Item.Tag:=I; Item.OnClick:=@SelectorMenuClick;
    if MenuGroup.Tag in [0,1,4] then
    begin Item.RadioItem:=True; SetMenuChecked(Item,I=Selector.ItemIndex); end;
    MenuGroup.Add(Item);
  end;
end;

procedure TMainForm.SelectorMenuClick(Sender:TObject);
var Item:TMenuItem; Selector:TComboBox;
begin
  Item:=TMenuItem(Sender); Selector:=MenuSelector(Item.Parent.Tag);
  Selector.ItemIndex:=Item.Tag;
  case Item.Parent.Tag of
    0:EquationSelected(Selector);
    1:FieldSelected(Selector);
    2:TemplateSelected(Selector);
    3:MacroSelected(Selector);
    4:EngineChanged(Selector);
  end;
end;

function EndsParagraph(const S:string):Boolean;
var P:Integer;
begin
  P:=Length(S);
  while (P>0) and (S[P] in [' ',#9,#13]) do Dec(P);
  if (P=0) or (S[P]<>#10) then Exit(False);
  Dec(P); while (P>0) and (S[P] in [' ',#9,#13]) do Dec(P);
  Result:=(P>0) and (S[P]=#10);
end;

procedure TMainForm.EditorChanged(Sender: TObject);
begin
  if PluginSourceActive and not FLoading then begin
    FPluginSourceDue:=GetTickCount64+150; Modified:=True; UpdateTitle; Exit;
  end;
  if FLoading or FRestoringHistory or (ActiveBlock < 0) then Exit;
  FVisualUndo.Clear; FVisualRedo.Clear;
  FReblockKeepEmpty:=not EndsParagraph(Document.Blocks[ActiveBlock]) and EndsParagraph(Editor.Text);
  FSourceJoinNext:=EndsParagraph(Document.Blocks[ActiveBlock]) and not EndsParagraph(Editor.Text)
    and (ActiveBlock<Document.Blocks.Count-1);
  SyncLabelReferences(Document.Blocks[ActiveBlock],Editor.Text);
  Modified := True;
  UpdateTitle;
  LayoutCards(nil);
  QueuePreview;
  if not FReblockQueued then
  begin FReblockQueued:=True; Application.QueueAsyncCall(@ReblockSource,0); end;
end;

function BytePoint(const S:string; Offset:Integer):TPoint;
var I:Integer;
begin
  Result:=Point(1,1);
  for I:=1 to Min(Length(S),Offset) do
    if S[I]=#10 then begin Inc(Result.Y); Result.X:=1; end
    else if S[I]<>#13 then Inc(Result.X);
end;

procedure TMainForm.SourceCommandBefore(Sender:TObject; var Command:TSynEditorCommand; var AChar:TUTF8Char; Data:Pointer);
begin
  if PluginSourceActive then begin FSourceUndoBlock:=False; Exit; end;
  FSourceBeforeCommand:=Editor.Text;
  FSourceUndoBlock:=(Command>=ecEditCommandFirst) and (Command<=ecEditCommandLast) and
    (Command<>ecUndo) and (Command<>ecRedo);
  if FSourceUndoBlock then Editor.BeginUndoBlock;
end;

procedure TMainForm.SourceCommandAfter(Sender:TObject; var Command:TSynEditorCommand; var AChar:TUTF8Char; Data:Pointer);
var Spans:TMathSpans; I:Integer; NewSource:string; P:TPoint;
begin
  try
    if not FSourceUndoBlock then Exit;
    NewSource:=Editor.Text; Spans:=FindMath(FSourceBeforeCommand);
    for I:=0 to High(Spans) do
      if not Spans[I].DisplayMath and (Spans[I].Environment='') and
         (Spans[I].Start>1) and (FSourceBeforeCommand[Spans[I].Start-1]='$') and
         (Spans[I].Count>0) and
         (NewSource=Copy(FSourceBeforeCommand,1,Spans[I].Start-1)+
           Copy(FSourceBeforeCommand,Spans[I].Start+Spans[I].Count,MaxInt)) then
      begin
        P:=BytePoint(NewSource,Spans[I].Start-1);
        Editor.TextBetweenPoints[P,P]:=' ';
        Editor.LogicalCaretXY:=P;
        Break;
      end;
  finally
    if FSourceUndoBlock then begin FSourceUndoBlock:=False; Editor.EndUndoBlock; end;
  end;
end;

procedure TMainForm.ReblockSource(Data:PtrInt);
var Parts:TTeXDocument; I,Index,Offset,Target:Integer;
begin
  FReblockQueued:=False;
  if FLoading or not Editor.Visible or (ActiveBlock<0) then Exit;
  if FSourceJoinNext and (ActiveBlock<Document.Blocks.Count-1) then
  begin
    FSourceJoinNext:=False;
    Offset:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.LogicalCaretXY]);
    Index:=ActiveBlock;
    Document.Blocks[Index]:=Editor.Text+Document.Blocks[Index+1];
    Document.Blocks.Delete(Index+1);
    BuildCards; EditBlock(Index); Editor.LogicalCaretXY:=BytePoint(Editor.Text,Offset);
    QueuePreview;
  end;
  Parts:=TTeXDocument.Create;
  try
    Parts.Parse(Editor.Text);
    if FReblockKeepEmpty and (Trim(Editor.Text)<>'') and EndsParagraph(Editor.Text) then Parts.Blocks.Add('');
    if not FReblockKeepEmpty and (Parts.Blocks.Count>1) and (Parts.Blocks[Parts.Blocks.Count-1]='') then
      Parts.Blocks.Delete(Parts.Blocks.Count-1);
    FReblockKeepEmpty:=False;
    if (Parts.Preamble<>'') or (Parts.Ending<>'') or (Parts.Blocks.Count<2) then Exit;
    Offset:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.LogicalCaretXY]);
    Target:=0;
    while (Target<Parts.Blocks.Count-1) and (Offset>=Length(Parts.Blocks[Target])) do
    begin Dec(Offset,Length(Parts.Blocks[Target])); Inc(Target); end;
    Index:=ActiveBlock;
    Document.Blocks[Index]:=Parts.Blocks[0];
    for I:=1 to Parts.Blocks.Count-1 do Document.Blocks.Insert(Index+I,Parts.Blocks[I]);
    BuildCards; EditBlock(Index+Target);
    Editor.LogicalCaretXY:=BytePoint(Editor.Text,Offset);
    QueuePreview;
  finally Parts.Free; end;
end;

procedure TMainForm.ParagraphBreak(Sender:TObject);
var Before,After:string; Index:Integer; Parts:TTeXDocument;
begin
  if ActiveBlock<0 then Exit;
  if not FormulaEditor.SplitParagraph(Before,After) then Exit;
  if Trim(Document.Blocks[ActiveBlock])='' then
  begin
    FormulaEditor.ReplaceSource(Document.Blocks[ActiveBlock]+LineEnding,Length(Document.Blocks[ActiveBlock])+Length(LineEnding));
    Exit;
  end;
  Parts:=TTeXDocument.Create;
  try
    Parts.Parse(Before+LineEnding+LineEnding+After);
    if (Parts.Blocks.Count<2) and (Trim(Before)<>'') and (Trim(After)<>'') then
    begin
      FormulaEditor.ReplaceSource(Before+LineEnding+LineEnding+After,Length(Before)+2*Length(LineEnding));
      Exit;
    end;
  finally Parts.Free; end;
  RecordVisualEdit;
  Index:=ActiveBlock;
  Document.Blocks[Index]:=TrimRight(Before)+LineEnding+LineEnding;
  After:=TrimLeft(After);
  if Index<Document.Blocks.Count-1 then After:=TrimRight(After)+LineEnding+LineEnding;
  Document.Blocks.Insert(Index+1,After);
  Modified:=True; BuildCards;
  if Trim(Before)='' then EditBlock(Index) else EditBlock(Index+1);
  FormulaEditor.SetSourceCaret(0);
  UpdateTitle; QueuePreview;
end;

procedure TMainForm.ParagraphBoundary(Sender:TObject; Direction:Integer; Merge:Boolean);
var Target,Index,Offset:Integer; Before,After:string; P:TPoint; Vertical:Boolean;
begin
  Target:=ActiveBlock+Direction;
  if (Target<0) or (Target>=Document.Blocks.Count) then Exit;
  if not Merge then
  begin
    Vertical:=FormulaEditor.VerticalNavigation; P:=FormulaEditor.CaretPoint;
    EditBlock(Target);
    if Vertical then begin
      if Direction<0 then P.Y:=FormulaEditor.PreferredHeight-1 else P.Y:=0;
      FormulaEditor.HitOffset(P.X,P.Y); Exit;
    end;
    if Direction<0 then FormulaEditor.SetSourceCaret(Length(TrimRight(Document.Blocks[ActiveBlock])))
    else FormulaEditor.SetSourceCaret(0);
    Exit;
  end;
  RecordVisualEdit;
  Index:=Min(ActiveBlock,Target);
  Before:=TrimRight(Document.Blocks[Index]); After:=TrimLeft(Document.Blocks[Index+1]);
  Offset:=Length(Before);
  Document.Blocks[Index]:=Before+After; Document.Blocks.Delete(Index+1);
  if Index<Document.Blocks.Count-1 then
    Document.Blocks[Index]:=TrimRight(Document.Blocks[Index])+LineEnding+LineEnding;
  Modified:=True; BuildCards; EditBlock(Index); FormulaEditor.SetSourceCaret(Offset);
  UpdateTitle; QueuePreview;
end;

procedure TMainForm.EditorKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = VK_ESCAPE then
  begin
    Key := 0;
    PreviewClick(nil);
  end;
end;

procedure TMainForm.CheckPreviewTools;
begin
  FCompilerAvailable:=CompilerAvailable(Engine.Text,DocumentDirectory) and (VectorPDFSupported or (FindTool('pdftoppm')<>''));
end;
function TMainForm.UseCompiledPreview:Boolean;
begin
  Result:=(FRealtimeCompile or FManualPreview) and FCompilerAvailable and not PluginSourceActive and
    not Document.PreambleOnly and CompilableTeXDocument(FEffectivePreamble) and not BeamerSettings(FEffectivePreamble).Enabled;
end;
procedure TMainForm.QueuePreview(LocalEdit:Boolean; CompileNow:Boolean);
var Body,NewPreamble,Directory:string; I,Anchor,Focus:Integer;
begin
  if not SyncLinkedSource then Exit;
  FManualPreview:=CompileNow;
  if FSplitView<>nil then begin
    FDocumentRefreshDue:=0; Pending:=False;
    if FFullSource.SourceEditor.Text<>Document.Source then begin
      FFullSource.Selection(Anchor,Focus); FFullSource.LoadSource(Document.Source,Anchor,Focus);
    end;
    FSplitView.Changed; Exit;
  end;
  if PluginSourceActive then begin
    Pending:=False; FPermanentAvailable:=False; FDocumentRefreshDue:=0;
    if Worker<>nil then Worker.Terminate;
    RefreshProjectContext; UpdatePreviewCards(1); LayoutCards(nil); Exit;
  end;
  if FPagedView<>nil then begin
    FDocumentRefreshDue:=0; Body:=''; for I:=0 to Document.Blocks.Count-1 do Body:=Body+Document.Blocks[I];
    NewPreamble:=SyncDocumentPackages(Body);
    if NewPreamble<>Document.Preamble then begin Document.Preamble:=NewPreamble; Modified:=True; Inc(Revision); RefreshProjectContext; UpdateTitle; end;
    FPagedView.UpdatePreamble(Document.Preamble,Engine.Text); Exit;
  end;
  if LocalEdit then begin
    FPermanentAvailable:=UseCompiledPreview;
    Inc(Revision); Pending:=FPermanentAvailable; Due:=GetTickCount64+1200;
    FDocumentRefreshDue:=GetTickCount64+120;
    if Worker<>nil then Worker.Terminate;
    if ActiveBlock>=0 then begin Cards[ActiveBlock].PreviewState:=Ord(FPermanentAvailable); FormulaEditor.PreviewFrame:=Cards[ActiveBlock].PreviewState; end;
    LayoutCards(nil); SyncFullSource; Exit;
  end;
  FDocumentRefreshDue:=0;
  Body:=''; for I:=0 to Document.Blocks.Count-1 do Body:=Body+Document.Blocks[I];
  NewPreamble:=SyncDocumentPackages(Body);
  if NewPreamble<>Document.Preamble then begin
    Document.Preamble:=NewPreamble; Modified:=True; UpdateTitle;
    Directory:=DocumentDirectory;
    FormulaEditor.SetContext(Document.Preamble,Directory,Engine.Text,'',False);
  end;
  Inc(Revision);
  Pending := True;
  RefreshProjectContext; FPermanentAvailable:=UseCompiledPreview;
  if not FPermanentAvailable then Pending:=False;
  Due := GetTickCount64 + 1200;
  if Assigned(Worker) then Worker.Terminate;
  NotifyProjectChanged; RefreshPreambleEditor; UpdateSourceFonts; UpdatePreviewCards(1); LayoutCards(nil);
  if FPermanentAvailable then StatusText := 'Preview pending · click a paragraph to edit · Esc returns to preview'
  else if BeamerSettings(FEffectivePreamble).Enabled then StatusText:='Presentation · continuous layout shows all overlays · page layout shows slides'
  else if Document.PreambleOnly then StatusText:='Preamble source · edit this file in the gray box'
  else if not FRealtimeCompile or not FCompilerAvailable then StatusText:='Native instant preview · background LaTeX compilation is off'
  else StatusText:='Source fragment · instant preview';
  SyncFullSource;
end;

function TMainForm.DeferInput(Callback:TNotifyEvent; Sender:TObject):Boolean;
begin
  if Assigned(FormulaEditor) then FormulaEditor.FinishCommand(False);
  Result:=Assigned(FormulaEditor) and BodyEditing and FormulaEditor.InputPending;
  if not Result then Exit;
  FDeferredAction:=Callback; FDeferredSender:=Sender;
  StatusText:='Finishing the typed edit before continuing...';
end;

procedure TMainForm.CloseAfterInput(Sender:TObject);
begin Close; end;

procedure TMainForm.Tick(Sender: TObject);
var I: Integer; Directory: string; Callback:TNotifyEvent; ActionSender:TObject;
var Anchor:TPreviewAnchor;
begin
  if FTickBusy or (csDestroying in ComponentState) then Exit;
  FTickBusy:=True;
  try
  FPreviewLayoutDeadline:=GetTickCount64+12;
  if (FPluginSourceDue<>0) and (GetTickCount64>=FPluginSourceDue) then RefreshPluginSource;
  if RefreshSystemAppearance then ApplyAppearance;
  if (FDocumentRefreshDue<>0) and (GetTickCount64>=FDocumentRefreshDue) then QueuePreview;
  TrimNativeTeXFaces; CompletePDF; UpdateStatusBar;
  if (FNavigationRevision<>Revision) and FNavigation.Visible and
    ((FSplitView=nil) or not FSplitView.Busy) then begin RefreshNavigation; FNavigationRevision:=Revision; end;
  if FSplitView<>nil then Exit;
  TrimPreviewCaches;
  if (GetTickCount64>=FMemoryTrimDue) and not FDocumentDragging and not FormulaEditor.InputPending then begin
    ReleaseUnusedNativeMemory; FMemoryTrimDue:=GetTickCount64+5000;
  end;
  if (FPreambleRefreshDue<>0) and (GetTickCount64>=FPreambleRefreshDue) then begin
    FPreambleRefreshDue:=0; RefreshProjectContext; NotifyProjectChanged; RefreshPreambleEditor; UpdateSourceFonts;
    UpdatePreviewCards(1); RefreshParagraphStyles(nil); LayoutCards(nil);
  end;
  PumpDiagramPreviews;
  if (FDiagramRevision<>DiagramPreviewRevision) and not FDocumentDragging and not FormulaEditor.MouseSelecting then begin
    FDiagramRevision:=DiagramPreviewRevision; Anchor:=CapturePreviewAnchor;
    if FormulaEditor.HasDiagramPreview then FormulaEditor.RefreshDiagramPreview;
    for I:=0 to High(Cards) do if (Cards[I].Draft<>nil) and
      Cards[I].Draft.HasDiagramPreview then Cards[I].Draft.RefreshDiagramPreview;
    LayoutCards(nil); RestorePreviewAnchor(Anchor);
  end;
  if Assigned(Worker) and Worker.Finished and not FDocumentDragging and not FormulaEditor.MouseSelecting then
    CompleteParagraphPreview;
  if Pending and FPermanentAvailable and (Worker = nil) and (GetTickCount64 >= Due) and
     (not FormulaBox.Visible or not FormulaEditor.Rendering) then
  begin
    Pending := False;
    Directory:=DocumentDirectory;
    Worker := TRenderThread.Create(PreviewSnapshot, Directory, Engine.Text, Revision);
    Worker.PageLayoutOnly:=VectorPDFSupported and not FPreviewRasterFallback;
    StatusText := 'Rendering with ' + Engine.Text + '…';
    Worker.Start;
  end;
  if Assigned(FDeferredAction) and not FormulaEditor.InputPending then
  begin
    Callback:=FDeferredAction; ActionSender:=FDeferredSender; FDeferredAction:=nil;
    FReplayingAction:=True;
    try Callback(ActionSender); finally FReplayingAction:=False; end;
  end;
  finally FPreviewLayoutDeadline:=0; FTickBusy:=False; end;
end;

function TMainForm.MayDiscard: Boolean;
var Prompt:TForm; DisplayName:string; Answer:Integer;
begin
  Result := True;
  if not Modified then Exit;
  DisplayName:=ExtractFileName(FileName); if DisplayName='' then DisplayName:='Untitled.tex';
  Prompt:=CreateMessageDialog('Unsaved changes','Save changes to "'+DisplayName+'" before continuing?',
    mtConfirmation,[mbYes,mbNo,mbCancel]);
  try
    Prompt.Position:=poMainFormCenter; ApplyTheme(Prompt); Answer:=Prompt.ShowModal;
  finally Prompt.Free; end;
  case Answer of
    mrYes: Result := SaveDocument(False);
    mrNo: Result := True;
    else Result := False;
  end;
end;

procedure TMainForm.NewClick(Sender: TObject);
var Session:TOpenDocument;
begin
  if DeferInput(@NewClick,Sender) then Exit;
  Session:=TOpenDocument.Create; Session.Document:=TTeXDocument.Create; Session.Document.Parse(Starter);
  Session.Undo:=TObjectList.Create(True); Session.Redo:=TObjectList.Create(True); Session.EngineIndex:=Engine.ItemIndex;
  Session.Parking:=TPanel.Create(Self); Session.Parking.Parent:=Self; Session.Parking.Visible:=False;
  FSessions.Add(Session); FileTabs.Tabs.Add('Untitled.tex'); SwitchDocument(FSessions.Count-1);
end;

procedure TMainForm.LoadDocument(const Path: string; Reload:Boolean);
var Stream: TFileStream; Value,Directive,FullPath,RootSource:string; EngineIndex,I,P,K:Integer; Lines:TStringList;
    Session:TOpenDocument; ProjectFiles:TTeXProject; Reuse,WasPaged,WasSplit:Boolean;
begin
  FManualPreview:=False;
  Value:=FindExtensionFormat(Path);
  if (Value<>'') or ((ExtractFileExt(Path)<>'') and
    (Pos('|'+LowerCase(ExtractFileExt(Path))+'|','|.tex|.ltx|.sty|.cls|')=0)) then begin OpenPluginSource(Path,Value); Exit; end;
  FPreambleRefreshDue:=0;
  FullPath:=ExpandFileName(Path);
  Reuse:=False;
  for I:=0 to OpenFileCount-1 do if OpenFileName(I)=FullPath then begin SwitchDocument(I); if not Reload then Exit; Reuse:=True; Break; end;
  Session:=nil;
  try
    try
      Stream := TFileStream.Create(FullPath, fmOpenRead or fmShareDenyWrite);
      try
        SetLength(Value, Stream.Size);
        if Length(Value) > 0 then Stream.ReadBuffer(Value[1], Length(Value));
      finally
        Stream.Free;
      end;
      Session:=TOpenDocument.Create; Session.Document:=TTeXDocument.Create;
      Session.Document.ParseFile(Value); Session.FileName:=FullPath; EngineIndex:=Engine.ItemIndex;
      Session.Undo:=TObjectList.Create(True); Session.Redo:=TObjectList.Create(True);
      Session.Parking:=TPanel.Create(Self); Session.Parking.Parent:=Self; Session.Parking.Visible:=False;
      ProjectFiles:=Project; RootSource:='';
      try
        Session.RootName:=ProjectFiles.RootFile(Value,FullPath);
        if (Session.RootName<>'') and (Session.RootName<>FullPath) then RootSource:=ProjectFiles.ReadSource(Session.RootName);
        for I:=0 to FSessions.Count-1 do if OpenFileName(I)=Session.RootName then
          if I<>FSessionIndex then EngineIndex:=TOpenDocument(FSessions[I]).EngineIndex;
        Lines:=TStringList.Create;
        try
          for K:=0 to 1 do begin
            if K=0 then Lines.Text:=RootSource else Lines.Text:=Value;
            for I:=0 to Min(19,Lines.Count-1) do begin
              Directive:=LowerCase(Trim(Lines[I]));
              if (Pos('% !tex program',Directive)=1) or (Pos('% !tex ts-program',Directive)=1) then begin
                P:=Pos('=',Directive); P:=Engine.Items.IndexOf(Trim(Copy(Directive,P+1,MaxInt)));
                if P>=0 then EngineIndex:=P;
              end;
            end;
          end;
        finally Lines.Free; end;
        ProjectFiles.Engine:=Engine.Items[EngineIndex];
        if not Session.Document.PreambleOnly and
          (Length(DocumentInputs(Copy(Value,Length(Session.Document.Preamble)+1,MaxInt),FullPath,Session.Document.Preamble,''))>0) then begin
          Session.Linked:=TLinkedSource.Create; Session.Linked.Load(Value,FullPath,ProjectFiles);
          Session.Document.ParseFile(Session.Linked.Text);
        end;
      finally ProjectFiles.Free; end;
      Session.EngineIndex:=EngineIndex;
      Session.PageMode:=(FPagedView<>nil) and not Session.Document.PreambleOnly;
      if Reuse or ((FSessions.Count=1) and (FileName='') and not Modified and not PluginSourceActive) then begin
        WasSplit:=FSplitView<>nil; ExitSplitView;
        WasPaged:=FPagedView<>nil;
        if WasPaged then begin FPagedView.VisualEditor.FinishCommand; FreeAndNil(FPagedView); end;
        TOpenDocument(FSessions[FSessionIndex]).PageMode:=False; Scroll.Visible:=True;
        FormulaEditor.InvalidateContext; FSelectionContext.Invalidate;
        FreeAndNil(TOpenDocument(FSessions[FSessionIndex]).Linked);
        TOpenDocument(FSessions[FSessionIndex]).Linked:=Session.Linked; Session.Linked:=nil;
        Document.ParseFile(Session.Document.Source); FileName:=FullPath; Engine.ItemIndex:=EngineIndex; CheckPreviewTools; EquationMode:=True; FPreambleExpanded:=False;
        FVisualUndo.Clear; FVisualRedo.Clear;
        TOpenDocument(FSessions[FSessionIndex]).RootName:=Session.RootName; FreeAndNil(Session);
        Modified:=False; RefreshProjectContext; BuildCards; UpdateTitle; QueuePreview;
        if WasSplit then SplitViewClick(nil)
        else if WasPaged and not Document.PreambleOnly then PagedViewClick(nil);
      end else begin
        FSessions.Add(Session); Session:=nil;
        FileTabs.Tabs.Add(ExtractFileName(FullPath)); SwitchDocument(FSessions.Count-1);
      end;
    finally Session.Free; end;
    except
      on E: Exception do MessageDlg('Cannot open file', E.Message, mtError, [mbOK], 0);
  end;
end;

procedure TMainForm.OpenClick(Sender: TObject);
var D: TOpenDialog; Path:string;
begin
  if DeferInput(@OpenClick,Sender) then Exit;
  D := TOpenDialog.Create(Self);
  try
    D.Filter := 'LaTeX files|*.tex;*.ltx;*.sty;*.cls|'+ExtensionSourceFilter('')+'All files|*';
    D.Options:=D.Options+[ofAllowMultiSelect];
    if D.Execute then for Path in D.Files do LoadDocument(Path);
  finally
    D.Free;
  end;
end;

function TMainForm.SaveDocument(ChooseName: Boolean): Boolean;
var D: TSaveDialog; Path, Value, TemporaryPath: string; Stream: TFileStream; G: TGUID; Renamed:Boolean;
begin
  Result := False;
  if FPluginSourceDue<>0 then RefreshPluginSource;
  if FSplitView=nil then begin CurrentVisualEditor.FinishDefinitionEdit; CurrentVisualEditor.FinishVisualSource; end;
  if FDocumentRefreshDue<>0 then QueuePreview;
  TemporaryPath := '';
  Path := FileName;
  if ChooseName or (Path = '') then
  begin
    D := TSaveDialog.Create(Self);
    try
      if PluginSourceActive then begin
        D.Filter:=TOpenDocument(FSessions[FSessionIndex]).FormatName+'|*.'+TOpenDocument(FSessions[FSessionIndex]).SourceExtension;
        D.DefaultExt:=TOpenDocument(FSessions[FSessionIndex]).SourceExtension;
      end
      else begin D.Filter := 'LaTeX files|*.tex'; D.DefaultExt := 'tex'; end;
      D.FileName := Path;
      D.Options := D.Options + [ofOverwritePrompt];
      if not D.Execute then Exit;
      Path := ExpandFileName(D.FileName);
    finally
      D.Free;
    end;
  end;
  try
    if LinkedProject<>nil then begin
      if not SyncLinkedSource then Exit;
      SaveLinkedProject(Path); Renamed:=FileName<>Path; FileName:=Path; Modified:=False; UpdateTitle;
      if FSplitView=nil then QueuePreview
      else if Renamed then FSplitView.LoadDocument(FileName,DocumentDirectory,Engine.Text);
      Exit(True);
    end;
    if PluginSourceActive then Value:=Editor.Text else Value := Document.Source;
    CreateGUID(G);
    TemporaryPath := Path + '.pastex-' + GUIDToString(G) + '.tmp';
    Stream := TFileStream.Create(TemporaryPath, fmCreate);
    try
      if Length(Value) > 0 then Stream.WriteBuffer(Value[1], Length(Value));
    finally
      Stream.Free;
    end;
    if not ReplaceFileAtomically(TemporaryPath, Path) then
      raise Exception.Create('Cannot replace the destination file. The original file was kept.');
    Renamed:=FileName<>Path; FileName := Path;
    Modified := False;
    UpdateTitle;
    if FSplitView=nil then QueuePreview
    else if Renamed then FSplitView.LoadDocument(FileName,DocumentDirectory,Engine.Text);
    Result := True;
  except
    on E: Exception do
    begin
      if TemporaryPath <> '' then DeleteFile(TemporaryPath);
      MessageDlg('Cannot save file', E.Message, mtError, [mbOK], 0);
    end;
  end;
end;

procedure TMainForm.SaveClick(Sender: TObject);
begin
  if DeferInput(@SaveClick,Sender) then Exit;
  SaveDocument(False);
end;

procedure TMainForm.SaveAsClick(Sender: TObject);
begin
  if DeferInput(@SaveAsClick,Sender) then Exit;
  SaveDocument(True);
end;

procedure TMainForm.PreviewClick(Sender: TObject);
begin
  if DeferInput(@PreviewClick,Sender) then Exit;
  if FSplitView<>nil then begin FSplitView.Changed; Exit; end;
  if FPagedView<>nil then begin FPagedView.Recompile(Engine.Text); Exit; end;
  if PluginSourceActive then begin RefreshPluginSource; Exit; end;
  FormulaEditor.FinishDefinitionEdit;
  EquationMode:=True; FPreviewOnly:=not Document.PreambleOnly; FPreambleEditing:=Document.PreambleOnly;
  Document.ParseFile(Document.Source);
  BuildCards;
  QueuePreview(False,(Sender<>nil) and (Sender<>FormulaEditor));
  Due := 0;
end;

procedure TMainForm.AddClick(Sender: TObject);
var N: Integer;
begin
  if DeferInput(@AddClick,Sender) then Exit;
  if Document.PreambleOnly then begin EquationModeClick(nil); Exit; end;
  EquationMode:=True;
  N := Document.Blocks.Count - 1;
  if Trim(Document.Blocks[N]) <> '' then
  begin
    Document.Blocks[N] := TrimRight(Document.Blocks[N]) + LineEnding + LineEnding;
    Document.Blocks.Add(LineEnding);
  end;
  Modified := True;
  BuildCards;
  UpdateTitle;
  QueuePreview;
  EditBlock(Document.Blocks.Count - 1);
end;

procedure TMainForm.PreambleClick(Sender: TObject);
var D:TPreambleForm; P:string; Applied:Boolean;
begin
  if DeferInput(@PreambleClick,Sender) then Exit;
  D := TPreambleForm.Create(Self); Applied:=False;
  try
    P := Document.Preamble;
    D.Load(P,DocumentDirectory);
    D.ConfigureSource(FSourceFontPreference,Editor.Font.Size,SourceWrapMenuItem.Checked);
    if D.ShowModal = mrOK then
    begin
      P:=D.Source;
      if HasTeXDocumentClass(P) and (Pos('\begin{document}',P)=0) then P:=TrimRight(P)+LineEnding+'\begin{document}';
      if P=Document.Preamble then Exit;
      RecordVisualEdit;
      Document.Preamble:=P; Document.ParseFile(Document.Source); BuildCards;
      if not Document.PreambleOnly and (Document.Ending = '') then Document.Ending := LineEnding + '\end{document}' + LineEnding;
      Modified := True;
      UpdateTitle;
      if FormulaBox.Visible then LoadEquation;
      QueuePreview;
      Applied:=True;
    end;
  finally
    if D.PackageSourcesChanged and not Applied then begin
      FormulaEditor.InvalidateContext; FSelectionContext.Invalidate; BuildCards; QueuePreview;
    end;
    D.Free;
  end;
end;

procedure TMainForm.ShowText(const Title, Value: string);
var D: TForm; M: TMemo;
begin
  D := TForm.CreateNew(Self);
  try
    D.Caption := Title;
    D.SetBounds(100, 100, 850, 550);
    D.Position := poOwnerFormCenter;
    M := TMemo.Create(D);
    M.Parent := D;
    M.Align := alClient;
    M.ReadOnly := True;
    M.ScrollBars := ssBoth;
    M.WordWrap := False;
    M.Font.Name := 'monospace';
    M.Text := Value;
    ApplyTheme(D); D.ShowModal;
  finally
    D.Free;
  end;
end;

procedure TMainForm.LogClick(Sender: TObject);
begin
  if FSplitView<>nil then ShowText('LaTeX compiler log',FSplitView.CompilerLog)
  else ShowText('LaTeX compiler log', LastLog);
end;

procedure TMainForm.EngineChanged(Sender: TObject);
var Linked:TLinkedSource; P:TTeXProject; Path:string; SourcePos,Local,Index:Integer;
begin
  if FLoading or FSwitchingDocument or FUpdatingRibbon then Exit;
  if DeferInput(@EngineChanged,Sender) then Exit;
  CheckPreviewTools; ClearDiagramPreviews;
  if FSplitView<>nil then begin FSplitView.LoadDocument(FileName,DocumentDirectory,Engine.Text); Exit; end;
  CurrentVisualEditor.FinishCommand;
  if not SyncLinkedSource then Exit;
  Linked:=LinkedProject;
  if (Linked<>nil) and (Linked.Engine<>Engine.Text) then begin
    if FPagedView<>nil then SourcePos:=FPagedView.SourceOffset
    else begin
      Local:=FormulaEditor.SourceCaret;
      if Editor.Visible then Local:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.LogicalCaretXY]);
      SourcePos:=Document.SourceOffset(ActiveBlock,Local);
    end;
    Path:=Linked.FileAt(SourcePos,Local); P:=Project;
    try Linked.Refresh(P); finally P.Free; end;
    Document.ParseFile(Linked.Text); SourcePos:=Linked.ViewOffset(Path,Local);
    if SourcePos<0 then SourcePos:=Length(Document.Preamble);
    FVisualUndo.Clear; FVisualRedo.Clear; FReblockQueued:=False; FPageHistoryStarted:=False;
    RefreshProjectContext;
    if FPagedView<>nil then begin
      FPagedView.Load(Document.Source,DocumentDirectory,Engine.Text);
      FPagedView.SetSourceSelection(SourcePos,SourcePos); UpdateLinkedBoundaries;
    end else begin
      BuildCards; Document.LocateOffset(SourcePos,Index,Local);
      if Index>=0 then begin EditBlock(Index); FormulaEditor.SetSourceCaret(Local); end;
    end;
  end;
  if FormulaBox.Visible then LoadEquation;
  QueuePreview;
end;

procedure TMainForm.Closing(Sender: TObject; var CanClose: Boolean);
var I,Index:Integer;
begin
  if ToolJobBusy then begin FCloseAfterTool:=True; CancelToolJob; CanClose:=False; Exit; end;
  if DeferInput(@CloseAfterInput,Sender) then begin CanClose:=False; Exit; end;
  Index:=FSessionIndex; CanClose:=True;
  for I:=0 to FSessions.Count-1 do begin SwitchDocument(I); if not MayDiscard then begin CanClose:=False; Break; end; end;
  if not CanClose then SwitchDocument(Index);
end;

end.
