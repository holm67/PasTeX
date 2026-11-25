unit DiagramDataForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Types, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Grids,
  Graphics, SynEdit, TeXOptionsEditor, DiagramData;
type
  TDiagramDataForm=class(TForm)
  private
    FProgram:TDiagramFunctions;
    FDataPage,FSourcePage:TTabSheet;
    FContext,FDirectory:string;
    FUpdating,FNewData:Boolean;
    FFunctionRow:Integer;
    procedure FunctionSelected(Sender:TObject; ACol,ARow:Integer; var CanSelect:Boolean);
    procedure FunctionTextChanged(Sender:TObject; ACol,ARow:Integer; const Value:string);
    procedure ExpressionChanged(Sender:TObject);
    procedure PropertiesChanged(Sender:TObject);
    procedure OptionsChanged(Sender:TObject);
    procedure Browse(Sender:TObject);
    procedure ReadGrid;
    procedure LoadGrid;
    procedure PageChanging(Sender:TObject; var AllowChange:Boolean);
    procedure FunctionAction(Sender:TObject);
    procedure Accept(Sender:TObject);
    function SourceText:string;
  public
    DataName:TEdit;
    Format:TComboBox;
    Options:TTeXOptionsEditor;
    Functions:TStringGrid;
    SourceEditor,ExpressionEditor:TSynEdit;
    Pages:TPageControl;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(const Data,Settings,Context,Directory:string; SourceFont:TFont; NewData:Boolean=False);
    function DataText:string;
    function OptionsText:string;
  end;
implementation
uses Math, UnicodeEdits, SynHighlighterTeX, SynEditWrappedView, SourceFonts,
  SourceStyle, SourceCompletion, UITheme, EnvironmentOptions, TikZOptionsForm, SynEditTypes;
constructor TDiagramDataForm.Create(AOwner:TComponent);
var Footer,Header,Actions:TPanel; Tab:TTabSheet; LabelControl:TLabel; B:TButton; Split:TSplitter; I:Integer;
  function Button(Parent:TWinControl; const Title,Name:string; Tag:Integer; Event:TNotifyEvent):TButton;
  begin
    Result:=TButton.Create(Self); Result.Parent:=Parent; Result.Caption:=Title; Result.Name:=Name;
    Result.Tag:=Tag; Result.OnClick:=Event; Result.Height:=32;
  end;
begin
  inherited CreateNew(AOwner); Caption:='Data set'; Position:=poOwnerFormCenter; PopupMode:=pmAuto;
  ClientWidth:=800; ClientHeight:=560; Constraints.MinWidth:=680; Constraints.MinHeight:=460;
  FProgram:=TDiagramFunctions.Create;
  Footer:=TPanel.Create(Self); Footer.Parent:=Self; Footer.Align:=alBottom; Footer.Height:=48; Footer.BevelOuter:=bvNone;
  B:=Button(Footer,'Apply','ApplyDataSet',0,@Accept); B.Align:=alRight; B.Width:=104; B.BorderSpacing.Around:=8; B.Default:=True;
  B:=Button(Footer,'Cancel','',0,nil); B.Align:=alRight; B.Width:=104; B.BorderSpacing.Around:=8; B.Cancel:=True; B.ModalResult:=mrCancel;
  Header:=TPanel.Create(Self); Header.Parent:=Self; Header.Align:=alTop; Header.Height:=76; Header.BevelOuter:=bvNone;
  LabelControl:=TLabel.Create(Self); LabelControl.Parent:=Header; LabelControl.Caption:='Set name'; LabelControl.SetBounds(12,8,130,20);
  DataName:=TUnicodeEdit.Create(Self); DataName.Parent:=Header; DataName.SetBounds(12,32,350,30); DataName.OnChange:=@PropertiesChanged;
  LabelControl:=TLabel.Create(Self); LabelControl.Parent:=Header; LabelControl.Caption:='Data format'; LabelControl.SetBounds(380,8,180,20);
  Format:=TComboBox.Create(Self); Format.Parent:=Header; Format.SetBounds(380,32,230,32); Format.AutoSize:=False;
  Format.Items.Text:='table'+#10+'function'+#10+'key value pairs'; Format.OnChange:=@PropertiesChanged;
  Pages:=TEditorPageControl.Create(Self); Pages.Parent:=Self; Pages.Align:=alClient; Pages.OnChanging:=@PageChanging;
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=Pages; Tab.Caption:='Variables and functions'; FDataPage:=Tab;
  { GTK initially reports a 1x1 notebook page. Keep the stacked editor and
    splitter out of negative bounds until the notebook receives its allocation. }
  Tab.Constraints.MinWidth:=400; Tab.Constraints.MinHeight:=280;
  Actions:=TPanel.Create(Self); Actions.Parent:=Tab; Actions.Align:=alBottom; Actions.Height:=76; Actions.BevelOuter:=bvNone;
  Actions.ChildSizing.Layout:=cclLeftToRightThenTopToBottom; Actions.ChildSizing.ControlsPerLine:=3;
  Actions.ChildSizing.EnlargeHorizontal:=crsHomogenousChildResize; Actions.ChildSizing.ShrinkHorizontal:=crsScaleChilds;
  Actions.ChildSizing.HorizontalSpacing:=6; Actions.ChildSizing.VerticalSpacing:=4; Actions.BorderSpacing.Around:=8;
  for I:=0 to 4 do begin
    case I of
      0:B:=Button(Actions,'Add variable','AddDataVariable',I,@FunctionAction);
      1:B:=Button(Actions,'Add function','AddDataFunction',I,@FunctionAction);
      2:B:=Button(Actions,'Remove','RemoveDataFunction',I,@FunctionAction);
      3:B:=Button(Actions,'Move up','MoveDataFunctionUp',I,@FunctionAction);
      4:B:=Button(Actions,'Move down','MoveDataFunctionDown',I,@FunctionAction);
    end;
    B.Width:=140;
  end;
  LabelControl:=TLabel.Create(Self); LabelControl.Parent:=Tab; LabelControl.Align:=alTop;
  LabelControl.BorderSpacing.Around:=8; LabelControl.Caption:='Variable: interval [0:1] samples 25   ·   Function: sin(\value{x})';
  Functions:=TStringGrid.Create(Self); Functions.Parent:=Tab; Functions.Align:=alClient; Functions.BorderSpacing.Around:=8;
  Functions.FixedCols:=0; Functions.FixedRows:=1; Functions.RowCount:=2; Functions.DefaultRowHeight:=30; Functions.AutoFillColumns:=True;
  Functions.Options:=[goEditing,goHorzLine,goColSizing,goTabs,goThumbTracking];
  Functions.Columns.Add.Title.Caption:='Type'; Functions.Columns.Add.Title.Caption:='Attribute'; Functions.Columns.Add.Title.Caption:='Definition';
  Functions.Columns[0].ButtonStyle:=cbsPickList; Functions.Columns[0].PickList.Text:='var'+#10+'func'+#10+'source';
  Functions.Columns[0].Width:=80; Functions.Columns[1].Width:=120; Functions.Columns[2].SizePriority:=3;
  {$IFDEF LCLgtk3}Functions.ScrollBars:=ssBoth;{$ENDIF}
  ExpressionEditor:=TSynEdit.Create(Self); ExpressionEditor.Name:='DataExpressionEditor';
  ExpressionEditor.Parent:=Tab; ExpressionEditor.Align:=alBottom; ExpressionEditor.Height:=100; ExpressionEditor.BorderSpacing.Around:=8;
  ExpressionEditor.SetDefaultKeystrokes; ExpressionEditor.ResetMouseActions; UseNativeSourceFonts(ExpressionEditor);
  TLazSynEditLineWrapPlugin.Create(ExpressionEditor); ExpressionEditor.OnChange:=@ExpressionChanged;
  Split:=TSplitter.Create(Self); Split.Parent:=Tab; Split.Align:=alBottom; Split.MinSize:=60;
  Split.ResizeControl:=ExpressionEditor; Split.Top:=ExpressionEditor.Top-6;
  Functions.OnSelectCell:=@FunctionSelected; Functions.OnSetEditText:=@FunctionTextChanged;
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=Pages; Tab.Caption:='Options';
  B:=Button(Tab,'Browse available options…','BrowseDataOptions',0,@Browse); B.Align:=alBottom; B.BorderSpacing.Around:=8;
  Options:=TTeXOptionsEditor.Create(Self); Options.Parent:=Tab; Options.Align:=alClient; Options.BorderSpacing.Around:=12; Options.OnChange:=@OptionsChanged;
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=Pages; Tab.Caption:='Source'; FSourcePage:=Tab;
  SourceEditor:=TSynEdit.Create(Self); SourceEditor.Parent:=Tab; SourceEditor.Align:=alClient;
  SourceEditor.Highlighter:=TSynTeXSyn.Create(Self); UseNativeSourceFonts(SourceEditor); SourceEditor.SetDefaultKeystrokes;
  SourceEditor.Options:=SourceEditor.Options-[eoScrollPastEol]; SourceEditor.ScrollBars:=ssVertical;
  TLazSynEditLineWrapPlugin.Create(SourceEditor); ApplyTheme(Self); ApplySourceStyle(SourceEditor);
end;
destructor TDiagramDataForm.Destroy;
begin
  FUpdating:=True; Pages.OnChanging:=nil; Options.OnChange:=nil;
  CancelTabUpdates(Pages); FProgram.Free; inherited Destroy;
end;
procedure TDiagramDataForm.Load(const Data,Settings,Context,Directory:string; SourceFont:TFont; NewData:Boolean);
begin
  FUpdating:=True; FNewData:=NewData;
  try
    FContext:=Context; FDirectory:=Directory; SourceEditor.Font.Assign(SourceFont); ApplySourceStyle(SourceEditor);
    ExpressionEditor.Font.Assign(SourceFont); ApplySourceStyle(ExpressionEditor);
    SetSourceCompletionContext(SourceEditor,Context,Directory,'pdflatex',True);
    SetSourceCompletionContext(ExpressionEditor,Context,Directory,'pdflatex',True);
    SourceEditor.Text:=Data; Options.Text:=Settings; FProgram.Load(Data); LoadGrid;
  finally FUpdating:=False; end;
  OptionsChanged(nil);
  if Format.Text='function' then Pages.ActivePage:=FDataPage else Pages.ActivePage:=FSourcePage;
end;
procedure TDiagramDataForm.LoadGrid;
var I:Integer; WasUpdating,Allowed:Boolean;
begin
  WasUpdating:=FUpdating; FUpdating:=True;
  try
  Functions.RowCount:=Max(2,Length(FProgram.Rows)+1);
  for I:=1 to Functions.RowCount-1 do begin
    Functions.Cells[0,I]:=''; Functions.Cells[1,I]:=''; Functions.Cells[2,I]:='';
    if I<=Length(FProgram.Rows) then begin
      Functions.Cells[0,I]:=FProgram.Rows[I-1].Kind; Functions.Cells[1,I]:=FProgram.Rows[I-1].Name;
      Functions.Cells[2,I]:=FProgram.Rows[I-1].Expression;
    end;
  end;
  finally FUpdating:=WasUpdating; end;
  Allowed:=True; FunctionSelected(Functions,Functions.Col,Functions.Row,Allowed);
end;
procedure TDiagramDataForm.FunctionSelected(Sender:TObject; ACol,ARow:Integer; var CanSelect:Boolean);
var WasUpdating:Boolean;
begin
  FFunctionRow:=ARow; WasUpdating:=FUpdating; FUpdating:=True;
  try
    ExpressionEditor.Enabled:=ARow>0;
    if ARow>0 then ExpressionEditor.Text:=Functions.Cells[2,ARow] else ExpressionEditor.Clear;
    ExpressionEditor.ClearUndo;
  finally FUpdating:=WasUpdating; end;
end;
procedure TDiagramDataForm.FunctionTextChanged(Sender:TObject; ACol,ARow:Integer; const Value:string);
begin
  if FUpdating or (ACol<>2) or (ARow<>FFunctionRow) then Exit;
  FUpdating:=True; try ExpressionEditor.Text:=Value; finally FUpdating:=False; end;
end;
procedure TDiagramDataForm.ExpressionChanged(Sender:TObject);
begin
  if FUpdating or (FFunctionRow<1) or (FFunctionRow>=Functions.RowCount) then Exit;
  FUpdating:=True;
  try Functions.Cells[2,FFunctionRow]:=TrimRight(ExpressionEditor.Text); finally FUpdating:=False; end;
end;
procedure TDiagramDataForm.ReadGrid;
var I,N:Integer;
begin
  Functions.EditorMode:=False; N:=Functions.RowCount-1;
  if (N=1) and (Functions.Cells[0,1]='') and (Functions.Cells[1,1]='') and (Functions.Cells[2,1]='') then N:=0;
  SetLength(FProgram.Rows,N);
  for I:=0 to N-1 do begin
    FProgram.Rows[I].Kind:=Functions.Cells[0,I+1]; FProgram.Rows[I].Name:=Functions.Cells[1,I+1];
    FProgram.Rows[I].Expression:=Functions.Cells[2,I+1];
  end;
end;
procedure TDiagramDataForm.PageChanging(Sender:TObject; var AllowChange:Boolean);
begin
  if FUpdating then Exit;
  if Pages.ActivePage=FDataPage then begin ReadGrid; SourceEditor.Text:=FProgram.Source; end
  else begin FProgram.Load(SourceText); LoadGrid; end;
end;
procedure TDiagramDataForm.OptionsChanged(Sender:TObject);
begin
  if FUpdating then Exit; FUpdating:=True;
  try
    DataName.Text:=EnvironmentOption(Options.Text,'set'); Format.Text:=EnvironmentOption(Options.Text,'format','table');
    SetPageVisible(FDataPage,Format.Text='function');
  finally FUpdating:=False; end;
end;
procedure TDiagramDataForm.PropertiesChanged(Sender:TObject);
var Settings:string;
begin
  if FUpdating then Exit; Settings:=Options.Text;
  if Pages.ActivePage=FDataPage then begin ReadGrid; SourceEditor.Text:=FProgram.Source; end;
  if (Sender=Format) and FNewData and (TrimRight(SourceText)=TrimRight(DiagramDataTemplate(EnvironmentOption(Settings,'format','table')))) then begin
    FUpdating:=True;
    try SourceEditor.Text:=DiagramDataTemplate(Format.Text); FProgram.Load(SourceText); LoadGrid;
    finally FUpdating:=False; end;
  end;
  if Sender=DataName then Settings:=SetEnvironmentOption(Settings,'set',DataName.Text)
  else Settings:=SetEnvironmentOption(Settings,'format',Format.Text);
  Options.Text:=Settings;
  if Sender=Format then begin
    if Format.Text='function' then Pages.ActivePage:=FDataPage else Pages.ActivePage:=FSourcePage;
  end;
end;
procedure TDiagramDataForm.Browse(Sender:TObject);
var Dialog:TDiagramOptionsForm;
begin
  Dialog:=TDiagramOptionsForm.Create(Self);
  try
    Dialog.Load(Options.Text,'/pgf/data',FContext,nil,FDirectory);
    if Dialog.ShowModal=mrOK then Options.Text:=Dialog.OptionsText;
  finally Dialog.Free; end;
end;
procedure TDiagramDataForm.FunctionAction(Sender:TObject);
var I,J,N,Operation:Integer; Row:TDiagramFunction;
begin
  ReadGrid; I:=EnsureRange(Functions.Row-1,0,Max(0,High(FProgram.Rows))); N:=Length(FProgram.Rows); Operation:=TComponent(Sender).Tag;
  case Operation of
    0,1:begin
      if N>=256 then Exit; Row:=Default(TDiagramFunction); Row.Prefix:=LineEnding;
      if Operation=0 then begin Row.Kind:='var'; Row.Name:='x'; Row.Expression:='interval [0:1] samples 25'; end
      else begin Row.Kind:='func'; Row.Name:='y'; Row.Expression:='\value{x}'; end;
      I:=Min(I+1,N); SetLength(FProgram.Rows,N+1);
      for J:=N downto I+1 do FProgram.Rows[J]:=FProgram.Rows[J-1]; FProgram.Rows[I]:=Row;
    end;
    2:if N>0 then begin for J:=I to N-2 do FProgram.Rows[J]:=FProgram.Rows[J+1]; SetLength(FProgram.Rows,N-1); end;
    3,4:begin
      J:=I+IfThen(Operation=3,-1,1); if (J<0) or (J>=N) then Exit;
      Row:=FProgram.Rows[I]; FProgram.Rows[I]:=FProgram.Rows[J]; FProgram.Rows[J]:=Row; I:=J;
    end;
  end;
  LoadGrid; Functions.Row:=EnsureRange(I+1,1,Functions.RowCount-1);
end;
function TDiagramDataForm.DataText:string;
begin
  if (Pages.ActivePage=FDataPage) and (Format.Text='function') then begin ReadGrid; Result:=FProgram.Source; end
  else Result:=SourceText;
end;
function TDiagramDataForm.SourceText:string;
var Last:Integer;
begin
  Last:=SourceEditor.Lines.Count-1; Result:='';
  if Last>=0 then Result:=SourceEditor.TextBetweenPoints[Point(1,1),Point(Length(SourceEditor.Lines[Last])+1,Last+1)];
end;
function TDiagramDataForm.OptionsText:string;
begin Result:=Options.Text; end;
procedure TDiagramDataForm.Accept(Sender:TObject);
begin SourceEditor.Text:=DataText; ModalResult:=mrOK; end;
end.
