unit DiagramForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Types, Math, Forms, Controls, StdCtrls, ExtCtrls, Graphics, Buttons,
  SynEdit, SynHighlighterTeX, TeXRenderer, VectorPreview, Grids, ComCtrls,
  TikZModel, TikZPath, TikZSketch, DiagramData, MathEditor, NativeDiagrams, LCLType, SynEditTypes, SynEditWrappedView, PreviewImage;
type
  TDiagramForm=class(TForm)
  private
    FModel:TDiagramModel;
    FPathRows:TDiagramPathRows;
    FDataSets:TDiagramDataSets;
    FDataTable:TDiagramTable;
    FDataBody:string;
    FDataIndex:Integer;
    FDataLoading,FDataEdited:Boolean;
    FAxisIndices:array of Integer;
    FPreamble,FDirectory,FEngine,FRequested,FWorkingSource,FCommand,FModifier:string;
    FLabelBefore,FSceneSource,FInitialSource:string;
    FLabelTarget:TDiagramText;
    FLabels:TDiagramTexts;
    FUpdating,FClosing,FLabelLayout,FElementDirty:Boolean;
    FDue:QWord;
    FTimer:TTimer;
    FWorker:TRenderThread;
    FScene:IVectorDocument;
    FPicture:TPicture;
    FSurface:TPreviewSurface;
    FPaint:TPaintBox;
    FPreviewPanel:TPanel;
    FLabelViewport:TScrollBox;
    FLabelBounds:TRect;
    FControlsPane:TPanel;
    FStatus:TLabel;
    FPathFields,FPlotFields:TPanel;
    FTablePanel,FDataRow,FPlotRow,FAxisRow:TPanel;
    FImageRect:TRect;
    FDragHandle,FDragOther,FDragSegment,FDragLabel,FSelectedCommand:Integer;
    FDragging,FSketchWaiting:Boolean;
    FDragStart,FDragPoint:TPoint;
    FDragSource,FSketchSource:string;
    FSketchPoints:TDiagramHandles;
    FSketchStyles:array[0..10] of string;
    FSketchStyleTool:Integer;
    FPathFinish,FPathClose:TSpeedButton;
    procedure Changed(Sender:TObject);
    procedure ElementChanged(Sender:TObject);
    procedure GridChanged(Sender:TObject; ACol,ARow:Integer; const Value:string);
    procedure KindChanged(Sender:TObject);
    procedure AddObject(Sender:TObject);
    procedure Selected(Sender:TObject);
    procedure Action(Sender:TObject);
    procedure ObjectOrder(Sender:TObject);
    procedure UpdateObjectOrder;
    procedure PathAction(Sender:TObject);
    procedure EnvironmentSelected(Sender:TObject);
    function EnvironmentOptionSource:string;
    procedure EnvironmentAction(Sender:TObject);
    procedure BrowseOptions(Sender:TObject);
    procedure PathOptions(Sender:TObject; ACol,ARow:Integer);
    procedure PlotChanged(Sender:TObject);
    procedure DataSelected(Sender:TObject);
    procedure StoreDataGrid;
    procedure DataAction(Sender:TObject);
    procedure DataProperties(Sender:TObject);
    procedure DataSetAction(Sender:TObject);
    procedure DataSetOrder(Sender:TObject);
    procedure ReloadDataSets(Index:Integer);
    procedure ApplyDataBody(Index:Integer);
    procedure Tick(Sender:TObject);
    procedure PaintPreview(Sender:TObject);
    function PreparePreview:Boolean;
    procedure LabelBackground(Sender:TObject);
    procedure ResizePreview(Sender:TObject);
    procedure PreviewMouseDown(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
    procedure PreviewMouseMove(Sender:TObject; Shift:TShiftState; X,Y:Integer);
    procedure PreviewMouseUp(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
    procedure SketchToolChanged(Sender:TObject);
    procedure SketchToolClick(Sender:TObject);
    procedure SnapPoint(var X,Y:Double);
    procedure SketchStyleChanged(Sender:TObject);
    procedure SketchFinish(Sender:TObject);
    procedure SketchDoubleClick(Sender:TObject);
    procedure FinishSketchPath(Closed:Boolean=False);
    procedure CancelSketch;
    procedure UpdateSketchActions;
    procedure SketchHistory(Sender:TObject);
    procedure SketchKey(Sender:TObject; var Key:Word; Shift:TShiftState);
    procedure PaintSketch;
    function HandleAt(X,Y:Integer):Integer;
    function SegmentAt(X,Y:Integer):Integer;
    function DraggedHandle(Index:Integer):Boolean;
    procedure LabelChanged(Sender:TObject);
    procedure LayoutLabelEditor(Sender:TObject);
    procedure LabelCaretMoved(Sender:TObject);
    procedure LabelFinished(Sender:TObject);
    procedure LabelKey(Sender:TObject; Key:Word; Shift:TShiftState; var Handled:Boolean);
    procedure LabelExit(Sender:TObject);
    procedure CheckLabelFocus(Data:PtrInt);
    procedure RefreshStatements(Index:Integer);
    procedure LoadPathGrid;
    procedure ReadPathGrid;
    procedure ReplaceCode(const Code:string; First,Last:Integer);
    function SelectedAxis:Integer;
    function LabelAt(X,Y:Integer):Integer;
    function LabelBounds(const Target:TDiagramText):TRect;
    procedure Closing(Sender:TObject; var CanClose:Boolean);
    function ApplyPending:Boolean;
  protected
    function ConfirmUnapplied:Integer; virtual;
  public
    SourceEditor:TSynEdit;
    Objects,PathGrid,PlotGrid,Environments,EnvironmentOptions:TStringGrid;
    Kind,Backend,PlotDimension,PlotInput,AxisList,AxisKind,SketchTool,DataSetList:TComboBox;
    Options,TableOptions,SketchOptions:TEdit;
    CycleStyles:TCheckBox;
    SketchSnap:TComboBox;
    Content:TSynEdit;
    LabelEditor:TMathEditor;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(const Preamble,Source,Directory,Engine:string; SourceFont:TFont);
    function Source:string;
    function TextLabels:TDiagramTexts;
    function BeginLabelEdit(Index:Integer):Boolean;
    procedure FinishLabelEdit(Cancel:Boolean=False);
    property Preview:TPaintBox read FPaint;
    property ControlsPane:TPanel read FControlsPane;
  end;
implementation
uses Dialogs, TeXMacros, DiagramPreview, SourceFonts, SourceStyle, SourceCompletion, UITheme, RibbonIcons, TeXTextStyle, StrUtils, SourceRanges, TikZOptions, TikZOptionsForm, DiagramDataForm, EnvironmentOptions, LCLIntf, LMessages;
const Kinds:array[0..10] of string=('Line','Rectangle','Circle','Node / text',
  'Function plot','Surface plot','Coordinate plot','Path','Legend entry','Command source','Data visualization');
{$I diagramformcontrols.inc}
destructor TDiagramForm.Destroy;
var I:Integer;
begin
  FUpdating:=True; Application.RemoveAsyncCalls(Self);
  if FTimer<>nil then begin FTimer.Enabled:=False; FTimer.OnTimer:=nil; end;
  if SourceEditor<>nil then begin SourceEditor.OnChange:=nil; SourceEditor.Highlighter:=nil; end;
  if FPaint<>nil then begin FPaint.OnPaint:=nil; FPaint.OnResize:=nil; FPaint.OnMouseDown:=nil; FPaint.OnMouseMove:=nil; FPaint.OnMouseUp:=nil; end;
  if LabelEditor<>nil then begin LabelEditor.OnChange:=nil; LabelEditor.OnExit:=nil; end;
  if Objects<>nil then Objects.OnClick:=nil;
  for I:=0 to ComponentCount-1 do if Components[I] is TDiagramScrollBox then TDiagramScrollBox(Components[I]).OnResize:=nil;
  CancelTabUpdates(TPageControl(FindComponent('DiagramPages')));
  if HandleAllocated then Hide;
  if FWorker<>nil then begin FWorker.Terminate; FWorker.WaitFor; FreeAndNil(FWorker); end;
  FScene:=nil; FSurface.Free; FPicture.Free; FModel.Free; FDataTable.Free; inherited Destroy;
end;
procedure TDiagramForm.Load(const Preamble,Source,Directory,Engine:string; SourceFont:TFont);
begin
  FPreamble:=Preamble; FDirectory:=Directory; FEngine:=Engine; SourceEditor.Font.Assign(SourceFont);
  ApplySourceStyle(SourceEditor); LabelEditor.ConfigureSourceFont(SourceFont);
  Content.Font.Assign(SourceFont); ApplySourceStyle(Content);
  SetSourceCompletionContext(SourceEditor,Preamble,Directory,Engine);
  SetSourceCompletionContext(Content,Preamble,Directory,Engine,True);
  FUpdating:=True; try SourceEditor.Text:=Source; Backend.ItemIndex:=Ord(SelectedDiagramBackend); finally FUpdating:=False; end;
  Backend.Enabled:=True;
  FControlsPane.Visible:=DiagramPackage(Source)='tikz';
  if not FControlsPane.Visible then Caption:='Edit commutative diagram';
  SketchTool.Enabled:=FControlsPane.Visible and (Backend.ItemIndex=1);
  UpdateSketchActions;
  FSurface.SetSourceGraphics(Source); RefreshStatements(0); if Length(FModel.Commands)>0 then Selected(nil);
  FRequested:=Self.Source; FDue:=GetTickCount64+100;
  FInitialSource:=Self.Source; FClosing:=False;
end;
function TDiagramForm.ConfirmUnapplied:Integer;
begin
  Result:=QuestionDlg('Unapplied figure changes',
    'Apply the changes to this figure before closing?',mtConfirmation,
    [mrYes,'Apply',mrNo,'Discard',mrCancel,'Keep editing','IsDefault'],0);
end;
function TDiagramForm.ApplyPending:Boolean;
begin
  FinishLabelEdit;
  if FElementDirty and (FSelectedCommand>=0) then Action(FindComponent('UpdateDiagramElement'));
  if FDragging then PreviewMouseUp(FPaint,mbLeft,[],FDragPoint.X,FDragPoint.Y);
  FinishSketchPath;
  Result:=not FSketchWaiting;
  if not Result then FStatus.Caption:='Add a second point or cancel the unfinished path.';
end;
procedure TDiagramForm.Closing(Sender:TObject; var CanClose:Boolean);
var Answer:Integer;
begin
  if FClosing then Exit;
  if ModalResult=mrOK then CanClose:=ApplyPending
  else if (Source<>FInitialSource) or FSketchWaiting or FDragging or FElementDirty then begin
    Answer:=ConfirmUnapplied;
    case Answer of
      mrYes:begin CanClose:=ApplyPending; if CanClose then ModalResult:=mrOK; end;
      mrNo:begin CancelSketch; ModalResult:=mrCancel; end;
      else CanClose:=False;
    end;
  end;
  FClosing:=CanClose;
  if not CanClose then ModalResult:=mrNone;
end;
procedure TDiagramForm.ElementChanged(Sender:TObject);
begin
  if FUpdating or FDataLoading then Exit; FElementDirty:=True;
  if (Kind.ItemIndex=10) and ((Sender=Content) or (Sender=PlotGrid)) then FDataEdited:=True;
end;
procedure TDiagramForm.GridChanged(Sender:TObject; ACol,ARow:Integer; const Value:string);
begin ElementChanged(Sender); end;
function TDiagramForm.Source:string;
var Last:Integer;
begin
  Last:=SourceEditor.Lines.Count-1; Result:='';
  if Last>=0 then Result:=SourceEditor.TextBetweenPoints[Point(1,1),Point(Length(SourceEditor.Lines[Last])+1,Last+1)];
end;
procedure TDiagramForm.RefreshStatements(Index:Integer);
var I,N,OldAxis:Integer; Entry:TDiagramCommand;
begin
  FModel.Load(Source); OldAxis:=AxisList.ItemIndex;
  Objects.BeginUpdate; Environments.BeginUpdate; AxisList.Items.BeginUpdate;
  try
    Objects.Clean; Objects.RowCount:=Max(1,Length(FModel.Commands));
    for I:=0 to High(FModel.Commands) do begin
      Entry:=FModel.Commands[I]; Objects.Cells[0,I]:=Copy(StringReplace(StringReplace(
        FModel.Text(Entry.Source),#10,' ',[rfReplaceAll]),#13,'',[rfReplaceAll]),1,130);
    end;
    Objects.Row:=EnsureRange(Index,0,Objects.RowCount-1);
    Environments.Clean; Environments.RowCount:=Max(2,Length(FModel.Environments)+1);
    Environments.Cells[0,0]:='Environment'; Environments.Cells[1,0]:='Parent';
    AxisList.Items.Clear; FAxisIndices:=nil;
    for I:=0 to High(FModel.Environments) do begin
      Environments.Cells[0,I+1]:=FModel.Environments[I].Name;
      if FModel.Environments[I].Parent>=0 then
        Environments.Cells[1,I+1]:=FModel.Environments[FModel.Environments[I].Parent].Name;
      if DiagramIsAxis(FModel.Environments[I].Name) then begin
        N:=Length(FAxisIndices); SetLength(FAxisIndices,N+1); FAxisIndices[N]:=I;
        AxisList.Items.Add(FModel.Environments[I].Name+' '+IntToStr(N+1));
      end;
    end;
    if AxisList.Items.Count>0 then AxisList.ItemIndex:=EnsureRange(OldAxis,0,AxisList.Items.Count-1);
  finally AxisList.Items.EndUpdate; Environments.EndUpdate; Objects.EndUpdate; end;
  EnvironmentSelected(nil);
  UpdateObjectOrder;
end;
procedure TDiagramForm.Changed(Sender:TObject);
begin
  if FUpdating then Exit;
  if Sender=Backend then begin FinishLabelEdit; CancelSketch; end;
  SketchTool.Enabled:=FControlsPane.Visible and (Backend.ItemIndex=1);
  UpdateSketchActions;
  if Sender=SourceEditor then begin
    if FSketchWaiting and (Source<>FSketchSource) then CancelSketch;
    RefreshStatements(Objects.Row); if not LabelEditor.Visible then Selected(nil);
  end;
  FRequested:=Source; FDue:=GetTickCount64+250;
end;
procedure TDiagramForm.LoadPathGrid;
var I:Integer; Row:TDiagramPathRow;
begin
  PathGrid.RowCount:=Max(2,Length(FPathRows)+1);
  for I:=1 to PathGrid.RowCount-1 do begin
    Row:=Default(TDiagramPathRow); if I<=Length(FPathRows) then Row:=FPathRows[I-1];
    PathGrid.Cells[0,I]:=Row.Operation; PathGrid.Cells[1,I]:=Row.Coordinate;
    PathGrid.Cells[2,I]:=Row.Options; PathGrid.Cells[3,I]:=Row.Text; PathGrid.Cells[4,I]:=Row.Name;
  end;
end;
procedure TDiagramForm.ReadPathGrid;
var I:Integer;
begin
  SetLength(FPathRows,PathGrid.RowCount-1);
  for I:=0 to High(FPathRows) do begin
    FPathRows[I].Operation:=PathGrid.Cells[0,I+1]; FPathRows[I].Coordinate:=PathGrid.Cells[1,I+1];
    FPathRows[I].Options:=PathGrid.Cells[2,I+1]; FPathRows[I].Text:=PathGrid.Cells[3,I+1]; FPathRows[I].Name:=PathGrid.Cells[4,I+1];
  end;
end;
procedure TDiagramForm.KindChanged(Sender:TObject);
var IsPath:Boolean;
begin
  IsPath:=Kind.ItemIndex in [0..3,7];
  FPathFields.Visible:=IsPath; FPlotFields.Visible:=not IsPath;
  Options.Enabled:=Kind.ItemIndex<>3;
  if Sender<>nil then begin
    case Kind.ItemIndex of
      0:FPathRows:=ParseDiagramPath('(0,0) -- (2,1)');
      1:FPathRows:=ParseDiagramPath('(0,0) rectangle (2,1)');
      2:FPathRows:=ParseDiagramPath('(0,0) circle (1cm)');
      3:FPathRows:=ParseDiagramPath('at (0,0) {Text}',True);
      4:begin PlotDimension.ItemIndex:=0; PlotInput.ItemIndex:=0; end;
      5:begin
        PlotDimension.ItemIndex:=1; PlotInput.ItemIndex:=0;
        if Pos('surf',Options.Text)=0 then Options.Text:='surf'; Content.Text:='exp(-x^2-y^2)';
      end;
      6:begin
        PlotInput.ItemIndex:=1; GridSetup(PlotGrid,['x','y','z']); PlotGrid.RowCount:=3; PlotGrid.Cells[0,1]:='0';
        PlotGrid.Cells[1,1]:='0'; PlotGrid.Cells[0,2]:='1'; PlotGrid.Cells[1,2]:='1';
      end;
      7:FPathRows:=ParseDiagramPath('(0,0) -- (2,1) -- (1,2) -- cycle');
      10:begin
        FCommand:='datavisualization'; Options.Text:='scientific axes,visualize as line';
        FDataBody:='data {'+LineEnding+'x,y'+LineEnding+'0,0'+LineEnding+'1,1'+LineEnding+'}';
        FDataSets:=DiagramDataSets(FDataBody); FDataIndex:=-1;
        DataSetList.Items.Clear; DataSetList.Items.Add('Data 1'); DataSetList.ItemIndex:=0; DataSelected(nil);
      end;
    end;
    LoadPathGrid;
  end;
  PlotChanged(nil);
end;
procedure TDiagramForm.AddObject(Sender:TObject);
var AddAction:TButton;
begin
  if FElementDirty and (FSelectedCommand>=0) then Action(FindComponent('UpdateDiagramElement'));
  FUpdating:=True;
  try
    Options.Text:=''; Content.Text:='x^2'; CycleStyles.Checked:=False;
    PlotDimension.ItemIndex:=0; PlotInput.ItemIndex:=0;
    if TComponent(Sender).Tag=8 then Content.Text:='Legend';
  finally FUpdating:=False; end;
  Kind.ItemIndex:=TComponent(Sender).Tag; KindChanged(Kind);
  AddAction:=TButton(FindComponent('AddDiagramElement')); Action(AddAction);
end;
procedure TDiagramForm.PlotChanged(Sender:TObject);
var I:Integer;
begin
  FPlotRow.Visible:=Kind.ItemIndex in [4..6];
  FAxisRow.Visible:=Kind.ItemIndex in [4..6,8];
  AxisList.Visible:=(AxisList.Items.Count>0) and FAxisRow.Visible;
  CycleStyles.Visible:=Kind.ItemIndex in [4..6]; TDiagramRow(FAxisRow).Arrange;
  FDataRow.Visible:=Kind.ItemIndex=10; DataSetList.Visible:=DataSetList.Items.Count>0;
  TControl(FindComponent('EditDiagramDataSet')).Enabled:=DataSetList.ItemIndex>=0;
  TControl(FindComponent('RemoveDiagramDataSet')).Enabled:=DataSetList.ItemIndex>=0;
  TControl(FindComponent('MoveDiagramDataSetUp')).Enabled:=DataSetList.ItemIndex>0;
  TControl(FindComponent('MoveDiagramDataSetDown')).Enabled:=(DataSetList.ItemIndex>=0) and (DataSetList.ItemIndex<High(FDataSets));
  TControl(FindComponent('AddDiagramDataSet')).Enabled:=Length(FDataSets)<64;
  TControl(FindComponent('AddDataColumn')).Visible:=(Kind.ItemIndex=10) and PlotGrid.Visible;
  TControl(FindComponent('RemoveDataColumn')).Visible:=(Kind.ItemIndex=10) and PlotGrid.Visible;
  TDiagramRow(FDataRow).Arrange;
  FTablePanel.Visible:=(Kind.ItemIndex in [4..6]) and (PlotInput.ItemIndex in [2,3]);
  if Kind.ItemIndex<>10 then begin
    PlotGrid.Visible:=(PlotInput.ItemIndex=1) and (Kind.ItemIndex in [4..6]);
    if PlotGrid.Columns.Count<>3 then GridSetup(PlotGrid,['x','y','z']);
    PlotGrid.Columns[2].SizePriority:=0; PlotGrid.ColWidths[2]:=0;
    if PlotDimension.ItemIndex=1 then begin PlotGrid.ColWidths[2]:=130; PlotGrid.Columns[2].SizePriority:=1; end;
  end;
  Content.Visible:=not PlotGrid.Visible;
  TableOptions.Enabled:=PlotInput.ItemIndex in [2,3];
  for I:=0 to ComponentCount-1 do if (Components[I] is TButton) and
    (TButton(Components[I]).Parent<>nil) and (TButton(Components[I]).Parent.Parent=FPlotFields) and
    (TButton(Components[I]).Tag in [6,7]) then
    TButton(Components[I]).Enabled:=PlotGrid.Visible;
end;
{$I diagramformdata.inc}
procedure TDiagramForm.ReplaceCode(const Code:string; First,Last:Integer);
var Original:string;
begin
  Original:=Source; FUpdating:=True;
  try
    SourceEditor.BeginUndoBlock;
    try
      SourceEditor.LogicalCaretXY:=SourceBytePoint(Original,Last);
      SourceEditor.BlockBegin:=SourceBytePoint(Original,First); SourceEditor.BlockEnd:=SourceBytePoint(Original,Last);
      SourceEditor.SelText:=Code;
    finally SourceEditor.EndUndoBlock; end;
  finally FUpdating:=False; end;
  Changed(SourceEditor);
end;
function TDiagramForm.SelectedAxis:Integer;
begin
  Result:=-1; if (AxisList.ItemIndex>=0) and (AxisList.ItemIndex<Length(FAxisIndices)) then Result:=FAxisIndices[AxisList.ItemIndex];
end;
{$I diagramformedit.inc}
{$I diagramformlabels.inc}
{$I diagramformsketch.inc}
procedure TDiagramForm.Tick(Sender:TObject);
var Bytes:Int64;
begin
  if LabelEditor.Visible or FDragging then Exit;
  if (FWorker<>nil) and FWorker.Finished then begin
    if (FWorkingSource=FRequested) and (Backend.ItemIndex=0) then begin
      if FWorker.ErrorText='' then begin
        FScene:=OpenVectorDocument(FWorker.WorkDir+DirectorySeparator+'preview.pdf');
        FSurface.SetVector(FScene,1);
        FPicture.Clear;
        if (FScene=nil) and (FWorker.Images.Count>0) then FPicture.LoadFromFile(FWorker.Images[0]);
        FStatus.Caption:='TeX preview updated';
      end else FStatus.Caption:='TeX error — correct the source; previous preview retained';
      FPaint.Invalidate;
    end;
    FreeAndNil(FWorker);
  end;
  if (FDue=0) or (GetTickCount64<FDue) then Exit;
  if FWorker<>nil then begin FWorker.Terminate; Exit; end; FDue:=0;
  if Backend.ItemIndex=1 then begin
    FScene:=NativeDiagram(FPreamble,FRequested,FDirectory,Bytes,FEngine);
    FSceneSource:=FRequested;
    FSurface.SetVector(FScene,1); FSurface.SetSourceGraphics(FRequested);
    FPicture.Clear;
    if FScene=nil then FStatus.Caption:='Unsupported native operation — choose Cached TeX for package output'
    else FStatus.Caption:='Native preview updated · drag points/segments or click text to edit'; FPaint.Invalidate;
  end else begin
    FWorkingSource:=FRequested; FStatus.Caption:='Updating TeX preview…';
    FWorker:=TRenderThread.Create(DiagramDocument(FPreamble,FRequested),FDirectory,FEngine,0);
    FWorker.PDFOnly:=VectorPDFSupported; FWorker.RenderPasses:=1; FWorker.PreviewPage:=1; FWorker.Start;
  end;
end;
procedure TDiagramForm.ResizePreview(Sender:TObject);
begin
  if FLabelLayout then Exit;
  if (LabelEditor<>nil) and LabelEditor.Visible and PreparePreview then begin
    FLabelBounds:=LabelBounds(FLabelTarget); LayoutLabelEditor(nil);
  end;
  FPaint.Invalidate;
end;
function TDiagramForm.PreparePreview:Boolean;
var W,H,Scale:Double; ImageWidth,ImageHeight:Integer;
begin
  Result:=False;
  FImageRect:=Rect(0,0,0,0);
  if FScene<>nil then begin if not FScene.PageSize(1,W,H) then Exit; end
  else begin W:=FPicture.Width; H:=FPicture.Height; end;
  if (W<=0) or (H<=0) then Exit;
  Scale:=Min(Max(1,FPaint.Width-16)/W,Max(1,FPaint.Height-16)/H);
  ImageWidth:=Max(1,Round(W*Scale)); ImageHeight:=Max(1,Round(H*Scale));
  FImageRect:=Rect((FPaint.Width-ImageWidth) div 2,(FPaint.Height-ImageHeight) div 2,0,0);
  FImageRect.Right:=FImageRect.Left+ImageWidth; FImageRect.Bottom:=FImageRect.Top+ImageHeight;
  Result:=(FScene<>nil) or (FPicture.Graphic<>nil);
end;
procedure TDiagramForm.PaintPreview(Sender:TObject);
begin
  FPaint.Canvas.Brush.Color:=PaperColor; FPaint.Canvas.FillRect(FPaint.ClientRect);
  if PreparePreview then begin FSurface.Draw(FPaint.Canvas,FImageRect,FPicture); PaintSketch; end;
end;
procedure TDiagramForm.LabelBackground(Sender:TObject);
var R:TRect; Origin:TPoint;
begin
  LabelEditor.Canvas.Brush.Color:=PaperColor; LabelEditor.Canvas.FillRect(LabelEditor.ClientRect);
  if PreparePreview then begin
    Origin:=LabelEditor.ScreenToClient(FPaint.ClientToScreen(Point(0,0)));
    R:=FImageRect; Types.OffsetRect(R,Origin.X,Origin.Y);
    FSurface.Draw(LabelEditor.Canvas,R,FPicture);
  end;
end;

end.
