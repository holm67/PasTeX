{ SPDX-License-Identifier: GPL-3.0-or-later }
type
  TDiagramPanel=class(TPreviewPanel)
  protected
    {$IFDEF LCLgtk3}
    procedure CreateWnd; override;
    procedure WMSize(var Message:TLMSize); message LM_SIZE;
    function GetClientRect:TRect; override;
    {$ENDIF}
  end;
  TDiagramScrollBox=class(TScrollBox)
  protected
    {$IFDEF LCLgtk3}function GetClientOrigin:TPoint; override;{$ENDIF}
  public
    procedure ScrollBy(DeltaX,DeltaY:Integer); override;
  end;
  TDiagramStack=class(TDiagramPanel)
  private
    FArranging:Boolean;
  protected
    procedure AlignControls(AControl:TControl; var RemainingClientRect:TRect); override;
  public
    procedure ViewportResize(Sender:TObject);
  end;
  TDiagramRow=class(TDiagramPanel)
  private
    FArranging,FArrangeQueued:Boolean;
    procedure ArrangeDeferred(Data:PtrInt);
  protected
    procedure Resize; override;
  public
    MinCellWidth:Integer;
    Compact,StretchLast:Boolean;
    destructor Destroy; override;
    procedure Arrange;
  end;
{$IFDEF LCLgtk3}
procedure TDiagramPanel.CreateWnd;
var MinW,MinH,MaxW,MaxH:Integer;
begin
  MinW:=Constraints.MinWidth; MinH:=Constraints.MinHeight;
  MaxW:=Constraints.MaxWidth; MaxH:=Constraints.MaxHeight;
  inherited CreateWnd;
  { GTK promotes the initial allocation to explicit constraints when creating
    a widget. Borderless layout panels must retain their configured limits. }
  Constraints.MinWidth:=MinW; Constraints.MinHeight:=MinH;
  Constraints.MaxWidth:=MaxW; Constraints.MaxHeight:=MaxH;
end;
procedure TDiagramPanel.WMSize(var Message:TLMSize);
begin
  { GTK can report a panel's former child extent during a tab switch.
    LCL alignment and splitters own these borderless containers' bounds. }
  Message.Width:=Width; Message.Height:=Height;
  inherited WMSize(Message);
end;
function TDiagramPanel.GetClientRect:TRect;
begin
  Result:=inherited GetClientRect;
  { Borderless panels keep their logical size while GTK allocates hidden tabs. }
  Result:=Rect(0,0,Width,Height);
end;
function TDiagramScrollBox.GetClientOrigin:TPoint;
begin Result:=PreviewViewportOrigin(Self); end;
{$ENDIF}
procedure TDiagramScrollBox.ScrollBy(DeltaX,DeltaY:Integer);
begin
  inherited ScrollBy(DeltaX,DeltaY);
  {$IFDEF LCLgtk3}SetPreviewScroll(Self,HorzScrollBar.Position,VertScrollBar.Position);{$ENDIF}
end;
procedure TDiagramStack.AlignControls(AControl:TControl; var RemainingClientRect:TRect);
var I,H:Integer;
begin
  if FArranging or (csDestroying in ComponentState) then begin inherited; Exit; end;
  FArranging:=True;
  try
    inherited; H:=0;
    for I:=0 to ControlCount-1 do if Controls[I].Visible and (Controls[I].Align=alTop) then
      Inc(H,Controls[I].Height+Controls[I].BorderSpacing.AroundTop+Controls[I].BorderSpacing.AroundBottom);
    SetBounds(Left,Top,Width,Max(1,H));
    ViewportResize(nil);
  finally FArranging:=False; end;
end;
procedure TDiagramStack.ViewportResize(Sender:TObject);
var Scroll:TScrollBox;
begin
  if not (Parent is TScrollBox) then Exit; Scroll:=TScrollBox(Parent);
  Scroll.VertScrollBar.Range:=Max(Height,Scroll.ClientHeight);
  Scroll.VertScrollBar.Page:=Max(1,Scroll.ClientHeight);
end;
procedure TDiagramRow.Arrange;
var I,N,J,Columns,Rows,Column,W,CellHeight,Minimum,X,Y:Integer;
begin
  if FArranging or (csDestroying in ComponentState) then Exit;
  { LCL ignores height changes while a parent's alignment locks our bounds. }
  if BoundsLockCount<>0 then begin
    if not FArrangeQueued then begin FArrangeQueued:=True; Application.QueueAsyncCall(@ArrangeDeferred,0); end;
    Exit;
  end;
  FArranging:=True;
  try
    N:=0; for I:=0 to ControlCount-1 do if Controls[I].Visible then Inc(N);
    if N=0 then begin SetBounds(Left,Top,Width,1); Exit; end;
    if Compact then begin
      if ClientWidth<30 then Exit;
      X:=0; Y:=0; J:=0; CellHeight:=30;
      for I:=0 to ControlCount-1 do if Controls[I].Visible then
        CellHeight:=Max(CellHeight,Controls[I].Constraints.EffectiveMinHeight);
      for I:=0 to ControlCount-1 do if Controls[I].Visible then begin
        W:=Max(30,Controls[I].Constraints.MinWidth);
        if Controls[I] is TSpeedButton then W:=Max(28,MinCellWidth);
        if Controls[I] is TBevel then W:=8;
        if (X>0) and (X+W>ClientWidth) then begin X:=0; Inc(Y,CellHeight+2); end;
        Inc(J); if StretchLast and (J=N) then W:=Max(W,ClientWidth-X);
        Controls[I].SetBounds(X,Y,W,CellHeight); Inc(X,W+2);
      end;
      Constraints.MaxHeight:=0; SetBounds(Left,Top,Width,Y+CellHeight); Exit;
    end;
    Minimum:=Max(28,MinCellWidth);
    for I:=0 to ControlCount-1 do if Controls[I].Visible then begin
      Minimum:=Max(Minimum,Controls[I].Constraints.MinWidth);
      if Controls[I] is TCustomComboBox then Minimum:=Max(Minimum,120);
    end;
    { Hidden tabs briefly have no client width while native handles are built. }
    if ClientWidth<Minimum then Exit;
    Columns:=Max(1,Min(N,(ClientWidth+4) div (Minimum+4))); Rows:=(N+Columns-1) div Columns;
    { Balance the rows so the last action is never a full-width strip. }
    Columns:=(N+Rows-1) div Rows;
    CellHeight:=30; for I:=0 to ControlCount-1 do if Controls[I].Visible then CellHeight:=Max(CellHeight,Controls[I].Height);
    Constraints.MaxHeight:=Rows*(CellHeight+4); SetBounds(Left,Top,Width,Constraints.MaxHeight);
    J:=0;
    for I:=0 to ControlCount-1 do if Controls[I].Visible then begin
      Column:=J mod Columns; W:=(ClientWidth-4*(Columns-1)) div Columns;
      Controls[I].SetBounds(Column*(W+4),(J div Columns)*(CellHeight+4)+(CellHeight-Controls[I].Height) div 2,W,Controls[I].Height); Inc(J);
    end;
  finally FArranging:=False; end;
end;
procedure TDiagramRow.ArrangeDeferred(Data:PtrInt);
begin FArrangeQueued:=False; Arrange; end;
destructor TDiagramRow.Destroy;
begin Application.RemoveAsyncCalls(Self); inherited Destroy; end;
procedure TDiagramRow.Resize;
begin inherited Resize; Arrange; end;
procedure GridSetup(Grid:TStringGrid; const Titles:array of string; Editable:Boolean=True);
var Title:string;
begin
  Grid.FixedCols:=0; Grid.FixedRows:=1; Grid.RowCount:=2; Grid.Columns.Clear;
  { GTK3 auto scrollbars repeatedly change the aligned grid's allocation. }
  {$IFDEF LCLgtk3}Grid.ScrollBars:=ssBoth;{$ENDIF}
  Grid.Options:=[goHorzLine,goColSizing,goTabs,goThumbTracking,goRowHighlight];
  Grid.DefaultRowHeight:=28; Grid.Flat:=True;
  if Editable then Grid.Options:=Grid.Options+[goEditing] else Grid.Options:=Grid.Options+[goRowSelect];
  for Title in Titles do Grid.Columns.Add.Title.Caption:=Title;
  Grid.AutoFillColumns:=True;
end;
constructor TDiagramForm.Create(AOwner:TComponent);
var Body:TWinControl; SourcePanel,Footer,TablePanel,OptionsPanel:TPanel; Tab:TTabSheet; Split:TSplitter; B:TButton; L:TLabel; I:Integer; Row:TDiagramRow; Tool:TSpeedButton;
    Pages:TPageControl; Scroll:TDiagramScrollBox; Bevel:TBevel;
const ToolNames:array[0..10] of string=('Move','Text','Point','Node','Path','Label','Arrow','DeletePoint','Delete','Rectangle','Circle');
  procedure Top(Control:TControl; Parent:TWinControl; H:Integer);
  var I,Y:Integer; Other:TControl;
  begin
    Control.Parent:=Parent; Control.Height:=H; Control.BorderSpacing.Around:=4; Y:=0;
    for I:=0 to Parent.ControlCount-1 do begin
      Other:=Parent.Controls[I];
      if (Other<>Control) and (Other.Align=alTop) then Y:=Max(Y,Other.Top+Other.Height+Other.BorderSpacing.AroundBottom);
    end;
    Control.Top:=Y+1; Control.Align:=alTop;
  end;
  procedure CaptionAt(Parent:TWinControl; const Caption:string);
  begin L:=TLabel.Create(Self); L.Caption:=Caption; L.AutoSize:=False; Top(L,Parent,20); end;
  procedure MinimumWidth(Control:TControl);
  var W,Padding:Integer; Text:string; Measure:TBitmap;
  begin
    if not (Control.Parent is TDiagramRow) then Exit;
    Measure:=TBitmap.Create;
    try
      Measure.SetSize(1,1); Measure.Canvas.Font.Assign(Control.Font); W:=0; Padding:=32;
      if Control is TComboBox then begin
        Padding:=56;
        for Text in TComboBox(Control).Items do W:=Max(W,Measure.Canvas.TextWidth(Text));
      end else W:=Measure.Canvas.TextWidth(TButton(Control).Caption);
      Control.Constraints.MinWidth:=W+Padding;
    finally Measure.Free; end;
  end;
  function Button(Parent:TWinControl; const Caption:string; Tag:Integer; Event:TNotifyEvent):TButton;
  begin Result:=TButton.Create(Self); Result.Parent:=Parent; Result.Height:=30; Result.Caption:=Caption; Result.Tag:=Tag; Result.OnClick:=Event; MinimumWidth(Result); end;
  function Combo(Parent:TWinControl; const Items:array of string):TComboBox;
  var S:string;
  begin
    Result:=TComboBox.Create(Self); Result.AutoSize:=False; Result.Parent:=Parent; Result.Style:=csDropDownList;
    for S in Items do Result.Items.Add(S); Result.ItemIndex:=0; MinimumWidth(Result);
  end;
  function ButtonRow(Parent:TWinControl; Alignment:TAlign; Minimum:Integer=90):TDiagramRow;
  begin
    Result:=TDiagramRow.Create(Self); Result.BevelOuter:=bvNone; Result.MinCellWidth:=Minimum;
    if Alignment=alTop then Top(Result,Parent,34)
    else begin Result.Parent:=Parent; Result.Height:=34; Result.Top:=Parent.ClientHeight; Result.Align:=Alignment; Result.BorderSpacing.Around:=4; end;
  end;
  function ControlsPage(const Title,Name:string):TWinControl;
  begin
    Tab:=TTabSheet.Create(Self); Tab.Name:=Name; Tab.Caption:=Title; Tab.PageControl:=Pages;
    Scroll:=TDiagramScrollBox.Create(Self); Scroll.Parent:=Tab; Scroll.Align:=alClient; Scroll.BorderStyle:=bsNone;
    Scroll.AutoScroll:=False; Scroll.HorzScrollBar.Visible:=False; Scroll.VertScrollBar.Tracking:=True;
    Result:=TDiagramStack.Create(Self); Result.Parent:=Scroll; Result.Align:=alTop;
    TPanel(Result).BevelOuter:=bvNone; Scroll.OnResize:=@TDiagramStack(Result).ViewportResize;
  end;
begin
  FUpdating:=True;
  inherited CreateNew(AOwner); Name:='DiagramEditor'; Caption:='Edit TikZ / PGFPlots'; Position:=poMainFormCenter; PopupMode:=pmAuto;
  ClientWidth:=1180; ClientHeight:=820; Constraints.MinWidth:=800; Constraints.MinHeight:=640;
  KeyPreview:=True; OnKeyDown:=@SketchKey; OnCloseQuery:=@Closing; FDragHandle:=-1; FDragSegment:=-1; FSelectedCommand:=-1;
  FModel:=TDiagramModel.Create; FDataTable:=TDiagramTable.Create; FDataIndex:=-1;
  Footer:=TDiagramPanel.Create(Self); Footer.Parent:=Self; Footer.Align:=alBottom; Footer.Height:=44; Footer.BevelOuter:=bvNone;
  B:=Button(Footer,'Apply',0,@SketchFinish); B.SetBounds(8,7,100,30); B.ModalResult:=mrOK;
  B:=Button(Footer,'Cancel',0,nil); B.SetBounds(116,7,100,30); B.ModalResult:=mrCancel; B.Cancel:=True;
  FStatus:=TLabel.Create(Self); FStatus.Parent:=Footer; FStatus.SetBounds(230,12,900,24); FStatus.AutoSize:=False; FStatus.Anchors:=[akLeft,akTop,akRight];
  SourcePanel:=TDiagramPanel.Create(Self); SourcePanel.Parent:=Self; SourcePanel.Align:=alBottom; SourcePanel.Height:=190; SourcePanel.Constraints.MinHeight:=90; SourcePanel.BevelOuter:=bvNone;
  CaptionAt(SourcePanel,'Complete picture source · Undo / Redo');
  SourceEditor:=TSynEdit.Create(Self); SourceEditor.Parent:=SourcePanel; SourceEditor.Align:=alClient;
  SourceEditor.Highlighter:=TSynTeXSyn.Create(Self); UseNativeSourceFonts(SourceEditor); SourceEditor.SetDefaultKeystrokes; SourceEditor.OnChange:=@Changed;
  SourceEditor.Options:=SourceEditor.Options-[eoScrollPastEol]; SourceEditor.ScrollBars:=ssVertical;
  SourceEditor.Options2:=SourceEditor.Options2-[eoScrollPastEolAddPage,eoScrollPastEolAutoCaret];
  TLazSynEditLineWrapPlugin.Create(SourceEditor);
  Split:=TSplitter.Create(Self); Split.Parent:=Self; Split.Align:=alBottom; Split.MinSize:=90;
  FControlsPane:=TDiagramPanel.Create(Self); FControlsPane.Name:='DiagramControls'; FControlsPane.Parent:=Self;
  FControlsPane.Align:=alLeft; FControlsPane.Width:=400; FControlsPane.Constraints.MinWidth:=320; FControlsPane.BevelOuter:=bvNone;
  Pages:=TEditorPageControl.Create(Self); Pages.Name:='DiagramPages'; Pages.Parent:=FControlsPane; Pages.Align:=alClient;
  Body:=ControlsPage('Elements','DiagramElementsTab');
  CaptionAt(Body,'Objects · select to edit');
  Objects:=TStringGrid.Create(Self); Top(Objects,Body,84); Objects.FixedCols:=0; Objects.FixedRows:=0; Objects.ColCount:=1; Objects.RowCount:=1;
  Objects.AutoFillColumns:=True; Objects.DefaultRowHeight:=28; Objects.Flat:=True;
  Objects.Options:=[goRowSelect,goThumbTracking]; Objects.OnClick:=@Selected;
  Kind:=Combo(Body,Kinds); Top(Kind,Body,30); Kind.OnChange:=@KindChanged; Kind.Visible:=False;
  Row:=ButtonRow(Body,alTop,28); Row.Compact:=True;
  for I:=0 to High(Kinds) do if I<>9 then begin
    Tool:=TSpeedButton.Create(Self); Tool.Parent:=Row; Tool.Name:='DrawingObject'+IntToStr(I);
    Tool.Tag:=I; Tool.Height:=30; Tool.Flat:=True; Tool.Hint:='Add '+LowerCase(Kinds[I]); Tool.ShowHint:=True;
    Tool.OnClick:=@AddObject;
  end;
  RefreshRibbonIcons(Row); Row.Arrange;
  Row:=ButtonRow(Body,alTop,30); Row.Compact:=True;
  B:=Button(Row,'Add',0,@Action); B.Name:='AddDiagramElement';
  B:=Button(Row,'Update',1,@Action); B.Name:='UpdateDiagramElement'; B.Hint:='Apply properties to the selected object'; B.ShowHint:=True;
  Button(Row,'Delete',2,@Action);
  B:=Button(Row,'↑',-1,@ObjectOrder); B.Name:='MoveDiagramObjectUp'; B.Hint:='Move object up'; B.ShowHint:=True;
  B:=Button(Row,'↓',1,@ObjectOrder); B.Name:='MoveDiagramObjectDown'; B.Hint:='Move object down'; B.ShowHint:=True; Row.Arrange;
  OptionsPanel:=TDiagramPanel.Create(Self); OptionsPanel.BevelOuter:=bvNone; Top(OptionsPanel,Body,32);
  L:=TLabel.Create(Self); L.Parent:=OptionsPanel; L.Caption:='Options'; L.Align:=alLeft; L.Layout:=tlCenter; L.BorderSpacing.Right:=4;
  B:=Button(OptionsPanel,'…',0,@BrowseOptions); B.Name:='ElementOptionsBrowser'; B.Align:=alRight; B.Width:=32;
  B.Hint:='Browse options for this object'; B.ShowHint:=True;
  Options:=TEdit.Create(Self); Options.Text:='blue,thick'; Options.Parent:=OptionsPanel; Options.Align:=alClient;
  FPathFields:=TDiagramPanel.Create(Self); FPathFields.Name:='DiagramPathFields'; FPathFields.Caption:='';
  FPathFields.BevelOuter:=bvNone; Top(FPathFields,Body,340);
  Row:=ButtonRow(FPathFields,alBottom,30); Row.Compact:=True;
  Button(Row,'+ Point',0,@PathAction); Button(Row,'+ Node',1,@PathAction); Button(Row,'+ Close',2,@PathAction);
  Button(Row,'Remove',3,@PathAction); Button(Row,'Up',4,@PathAction); Button(Row,'Down',5,@PathAction); Row.Arrange;
  PathGrid:=TStringGrid.Create(Self); PathGrid.Parent:=FPathFields; PathGrid.Align:=alClient; PathGrid.BorderSpacing.Around:=4;
  GridSetup(PathGrid,['Operation','Coordinate / radius','Options','Text','Name']);
  PathGrid.ColWidths[0]:=78; PathGrid.ColWidths[1]:=120; PathGrid.ColWidths[2]:=100; PathGrid.ColWidths[3]:=150; PathGrid.ColWidths[4]:=75;
  for I:=0 to 4 do PathGrid.Columns[I].MinSize:=54;
  PathGrid.Columns[1].SizePriority:=2; PathGrid.Columns[3].SizePriority:=2;
  PathGrid.Columns[2].ButtonStyle:=cbsEllipsis; PathGrid.OnButtonClick:=@PathOptions;
  PathGrid.Columns[0].ButtonStyle:=cbsPickList; PathGrid.Columns[0].PickList.CommaText:='move,line,to,node,cycle,rectangle,circle,|-,-|,raw';
  FPlotFields:=TDiagramPanel.Create(Self); FPlotFields.Name:='DiagramPlotFields'; FPlotFields.Caption:='';
  FPlotFields.BevelOuter:=bvNone; Top(FPlotFields,Body,340); FPlotFields.Visible:=False;
  Row:=ButtonRow(FPlotFields,alTop,140);
  FPlotRow:=Row;
  PlotDimension:=Combo(Row,['2D · addplot','3D · addplot3']); PlotDimension.OnChange:=@PlotChanged;
  PlotInput:=Combo(Row,['Expression','Coordinates','Table data','Table file','Parametric coordinates']); PlotInput.OnChange:=@PlotChanged; Row.Arrange;
  Row:=ButtonRow(FPlotFields,alTop,140); FAxisRow:=Row; AxisList:=Combo(Row,[]);
  AxisList.Hint:='Axis receiving the plot'; AxisList.ShowHint:=True;
  CycleStyles:=TCheckBox.Create(Self); CycleStyles.Parent:=Row; CycleStyles.AutoSize:=False; CycleStyles.Caption:='Use cycle styles (+)'; Row.Arrange;
  Row:=ButtonRow(FPlotFields,alTop,30); Row.Compact:=True; FDataRow:=Row; DataSetList:=Combo(Row,[]); DataSetList.Constraints.MinWidth:=140;
  DataSetList.Name:='DiagramDataSets'; DataSetList.Hint:='Data set to edit'; DataSetList.ShowHint:=True; DataSetList.OnChange:=@DataSelected;
  B:=Button(Row,'Data set…',0,@DataProperties); B.Name:='EditDiagramDataSet';
  B:=Button(Row,'+ Data',0,@DataSetAction); B.Name:='AddDiagramDataSet'; B.Hint:='Add data set'; B.ShowHint:=True;
  B:=Button(Row,'− Data',1,@DataSetAction); B.Name:='RemoveDiagramDataSet'; B.Hint:='Delete data set'; B.ShowHint:=True;
  B:=Button(Row,'↑',-1,@DataSetOrder); B.Name:='MoveDiagramDataSetUp'; B.Hint:='Move data set up'; B.ShowHint:=True;
  B:=Button(Row,'↓',1,@DataSetOrder); B.Name:='MoveDiagramDataSetDown'; B.Hint:='Move data set down'; B.ShowHint:=True;
  B:=Button(Row,'+ Column',0,@DataAction); B.Name:='AddDataColumn';
  B:=Button(Row,'− Column',1,@DataAction); B.Name:='RemoveDataColumn'; Row.Arrange;
  TablePanel:=TDiagramPanel.Create(Self); FTablePanel:=TablePanel; TablePanel.Parent:=FPlotFields; TablePanel.Align:=alBottom; TablePanel.Height:=64; TablePanel.BevelOuter:=bvNone;
  CaptionAt(TablePanel,'Table options (column names / indices)'); TableOptions:=TEdit.Create(Self); Top(TableOptions,TablePanel,30);
  Row:=ButtonRow(FPlotFields,alBottom,30); Row.Compact:=True;
  Button(Row,'+ Data row',6,@PathAction); Button(Row,'Remove row',7,@PathAction); Row.Arrange;
  Content:=TSynEdit.Create(Self); Content.Name:='PlotExpressionEditor'; Content.Parent:=FPlotFields;
  Content.Align:=alClient; Content.BorderSpacing.Around:=4; Content.Text:='x^2';
  Content.SetDefaultKeystrokes; Content.ResetMouseActions; UseNativeSourceFonts(Content);
  TLazSynEditLineWrapPlugin.Create(Content); ApplySourceStyle(Content);
  PlotGrid:=TStringGrid.Create(Self); PlotGrid.Parent:=FPlotFields; PlotGrid.Align:=alClient; PlotGrid.BorderSpacing.Around:=4; GridSetup(PlotGrid,['x','y','z']); PlotGrid.Visible:=False;
  for I:=0 to 2 do PlotGrid.ColWidths[I]:=130;
  Body:=ControlsPage('Environments','DiagramEnvironmentTab');
  CaptionAt(Body,'Picture and nested environments');
  Environments:=TStringGrid.Create(Self); Top(Environments,Body,112);
  GridSetup(Environments,['Environment','Parent'],False); Environments.ColWidths[0]:=260; Environments.ColWidths[1]:=150; Environments.OnClick:=@EnvironmentSelected;
  Row:=ButtonRow(Body,alTop,30); Row.Compact:=True;
  AxisKind:=Combo(Row,['axis','semilogxaxis','semilogyaxis','loglogaxis','polaraxis']); AxisKind.Constraints.MinWidth:=140;
  Button(Row,'Add axis',0,@EnvironmentAction); Button(Row,'Delete axis',1,@EnvironmentAction); Row.Arrange;
  CaptionAt(Body,'Environment options');
  EnvironmentOptions:=TStringGrid.Create(Self); Top(EnvironmentOptions,Body,240);
  GridSetup(EnvironmentOptions,['Option name','Value','Type']); EnvironmentOptions.ColWidths[0]:=150; EnvironmentOptions.ColWidths[1]:=208; EnvironmentOptions.ColWidths[2]:=66;
  EnvironmentOptions.Columns[2].SizePriority:=0; EnvironmentOptions.Columns[2].Width:=66;
  EnvironmentOptions.Columns[2].ButtonStyle:=cbsPickList; EnvironmentOptions.Columns[2].PickList.CommaText:='Value,Flag';
  Row:=ButtonRow(Body,alTop,30); Row.Compact:=True; Button(Row,'+ Option',2,@EnvironmentAction); Button(Row,'Remove',3,@EnvironmentAction);
  B:=Button(Row,'Browse…',1,@BrowseOptions); B.Name:='EnvironmentOptionsBrowser';
  Button(Row,'Apply options',4,@EnvironmentAction); Row.Arrange;
  Pages.ActivePageIndex:=0;
  Split:=TSplitter.Create(Self); Split.Name:='DiagramPaneSplitter'; Split.Left:=FControlsPane.Width;
  Split.Parent:=Self; Split.Align:=alLeft; Split.Width:=7; Split.MinSize:=220; Split.Cursor:=crHSplit;
  Split.ResizeControl:=FControlsPane;
  FPreviewPanel:=TDiagramPanel.Create(Self); FPreviewPanel.Parent:=Self; FPreviewPanel.Align:=alClient; FPreviewPanel.BevelOuter:=bvNone;
  FPreviewPanel.TabStop:=True;
  FPreviewPanel.Constraints.MinWidth:=220;
  SketchTool:=Combo(FPreviewPanel,['Select / move','Edit text','Point','Node','Path','Label','Arrow','Delete point','Delete object','Rectangle','Circle']);
  SketchTool.Visible:=False;
  SketchTool.Constraints.MinWidth:=180; SketchTool.OnChange:=@SketchToolChanged;
  Row:=ButtonRow(FPreviewPanel,alTop,30); Row.Name:='SketchTools'; Row.Caption:=''; Row.Compact:=True;
  for I:=0 to 1 do begin
    Tool:=TSpeedButton.Create(Self); Tool.Parent:=Row; Tool.Tag:=I; Tool.Flat:=True; Tool.Height:=30; Tool.OnClick:=@SketchHistory;
    if I=0 then begin Tool.Name:='DiagramUndo'; Tool.Hint:='Undo drawing · Ctrl+Z'; end
    else begin Tool.Name:='DiagramRedo'; Tool.Hint:='Redo drawing · Ctrl+Y'; end;
  end;
  Bevel:=TBevel.Create(Self); Bevel.Parent:=Row; Bevel.Shape:=bsLeftLine;
  for I:=0 to High(ToolNames) do begin
    Tool:=TSpeedButton.Create(Self); Tool.Parent:=Row; Tool.Name:='DrawingTool'+ToolNames[I]; Tool.Tag:=I;
    Tool.Flat:=True; Tool.Height:=30; Tool.GroupIndex:=41; Tool.AllowAllUp:=False; Tool.OnClick:=@SketchToolClick;
    Tool.Hint:=SketchTool.Items[I]; Tool.ShowHint:=True; Tool.Down:=I=0;
  end;
  FPathFinish:=TSpeedButton.Create(Self); FPathFinish.Parent:=Row; FPathFinish.Name:='FinishSketchPath';
  FPathFinish.Flat:=True; FPathFinish.OnClick:=@SketchFinish; FPathFinish.Hint:='Finish path · Enter or double-click';
  FPathClose:=TSpeedButton.Create(Self); FPathClose.Parent:=Row; FPathClose.Name:='CloseSketchPath'; FPathClose.Tag:=1;
  FPathClose.Flat:=True; FPathClose.OnClick:=@SketchFinish; FPathClose.Hint:='Close polygon';
  RefreshRibbonIcons(Row); Row.Arrange;
  Row:=ButtonRow(FPreviewPanel,alTop,30); Row.Name:='SketchStyleBar'; Row.Caption:=''; Row.Compact:=True; Row.StretchLast:=True;
  Backend:=Combo(Row,['Cached TeX','Native PasTeX']); Backend.Constraints.MinWidth:=142; Backend.OnChange:=@Changed;
  Backend.Hint:='Preview backend: cached TeX output or editable native rendering'; Backend.ShowHint:=True;
  OptionsPanel:=TDiagramPanel.Create(Self); OptionsPanel.Parent:=Row; OptionsPanel.BevelOuter:=bvNone; OptionsPanel.Constraints.MinWidth:=100;
  L:=TLabel.Create(Self); L.Parent:=OptionsPanel; L.Caption:='Snap'; L.Align:=alLeft; L.Layout:=tlCenter; L.BorderSpacing.Right:=4;
  SketchSnap:=Combo(OptionsPanel,['Off','0.1','0.25','0.5','1']); SketchSnap.Align:=alClient;
  SketchSnap.Hint:='Grid snap in centimetres'; SketchSnap.ShowHint:=True;
  OptionsPanel:=TDiagramPanel.Create(Self); OptionsPanel.Parent:=Row; OptionsPanel.BevelOuter:=bvNone; OptionsPanel.Constraints.MinWidth:=140;
  L:=TLabel.Create(Self); L.Parent:=OptionsPanel; L.Caption:='Style'; L.Align:=alLeft; L.Layout:=tlCenter; L.BorderSpacing.Right:=4;
  B:=Button(OptionsPanel,'…',2,@BrowseOptions); B.Name:='SketchOptionsBrowser'; B.Align:=alRight; B.Width:=32;
  B.Hint:='Browse options for the active tool'; B.ShowHint:=True;
  SketchOptions:=TEdit.Create(Self); SketchOptions.Parent:=OptionsPanel; SketchOptions.Align:=alClient; SketchOptions.OnChange:=@SketchStyleChanged;
  Row.Arrange;
  FPaint:=TPaintBox.Create(Self); FPaint.Parent:=FPreviewPanel; FPaint.Align:=alClient;
  FPaint.OnPaint:=@PaintPreview; FPaint.OnResize:=@ResizePreview; FPaint.OnMouseDown:=@PreviewMouseDown; FPaint.OnMouseMove:=@PreviewMouseMove; FPaint.OnMouseUp:=@PreviewMouseUp; FPaint.OnDblClick:=@SketchDoubleClick;
  FLabelViewport:=TDiagramScrollBox.Create(Self); FLabelViewport.Name:='DiagramLabelViewport'; FLabelViewport.Parent:=FPreviewPanel;
  FLabelViewport.Visible:=False; FLabelViewport.BorderStyle:=bsNone; FLabelViewport.AutoScroll:=False;
  FLabelViewport.HorzScrollBar.Visible:=False; FLabelViewport.VertScrollBar.Tracking:=True;
  LabelEditor:=TMathEditor.Create(Self); LabelEditor.Parent:=FLabelViewport; LabelEditor.Visible:=False;
  LabelEditor.OnChange:=@LabelChanged; LabelEditor.OnFinish:=@LabelFinished; LabelEditor.OnParagraphBreak:=@LabelFinished;
  LabelEditor.OnLayout:=@LayoutLabelEditor; LabelEditor.OnSelectionChange:=@LabelCaretMoved;
  LabelEditor.OnDocumentKey:=@LabelKey; LabelEditor.OnExit:=@LabelExit;
  LabelEditor.PreserveColors:=False; LabelEditor.OnBackgroundPaint:=@LabelBackground;
  Footer.Align:=alNone; Footer.Top:=ClientHeight; Footer.Align:=alBottom;
  FPicture:=TPicture.Create; FSurface:=TPreviewSurface.Create; FTimer:=TTimer.Create(Self); FTimer.Interval:=100; FTimer.OnTimer:=@Tick;
  Options.OnChange:=@ElementChanged; TableOptions.OnChange:=@ElementChanged; Content.OnChange:=@ElementChanged;
  PathGrid.OnSetEditText:=@GridChanged; PlotGrid.OnSetEditText:=@GridChanged;
  FSketchStyles[3]:='draw'; FSketchStyles[6]:='->';
  FUpdating:=False; Kind.ItemIndex:=0; KindChanged(nil); SketchToolChanged(nil); ApplyTheme(Self);
end;
