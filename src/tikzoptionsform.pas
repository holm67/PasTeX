unit TikZOptionsForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Grids, CheckLst, TikZOptions, TikZModel;
type
  TDiagramOptionsForm=class(TForm)
  private
    FCatalog:TDiagramOptionCatalog;
    FOptions:TDiagramOptions;
    FRoot,FContext,FDirectory:string;
    FOptionContext:TDiagramOptionContext;
    FUpdating,FEdited,FOwnCatalog:Boolean;
    FInfo,FHeading,FCount:TLabel;
    FActions:array[0..3] of TButton;
    procedure Filter(Sender:TObject);
    procedure Browse(Sender:TObject);
    procedure AddSelected(Sender:TObject);
    procedure Toggle(Sender:TObject);
    procedure CurrentSelected(Sender:TObject; Col,Row:Integer; var CanSelect:Boolean);
    procedure EditValue(Sender:TObject);
    procedure Action(Sender:TObject);
    procedure RefreshOptions;
    procedure Choose(KeyName:string);
    function IndexOf(const KeyName:string):Integer;
    procedure Store;
    procedure Accept(Sender:TObject);
    procedure EditChildren(Sender:TObject);
  public
    Search,OptionName:TEdit;
    OptionValue:TComboBox;
    HasValue:TCheckBox;
    Scope:TComboBox;
    CatalogList:TCheckListBox;
    Current:TStringGrid;
    SubOptions:TButton;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(const AText,Root,Context:string; Catalog:TDiagramOptionCatalog=nil; const Directory:string='';
      OptionContext:TDiagramOptionContext=ocGeneral);
    function OptionsText:string;
  end;
implementation
uses Math, UITheme, Graphics, TeXMacros;
constructor TDiagramOptionsForm.Create(AOwner:TComponent);
var Footer,LeftPane,RightPane,Header,Fields,Row:TPanel; Split:TSplitter; B:TButton; L:TLabel; I:Integer;
  function Panel(Parent:TWinControl; Align:TAlign; Size:Integer):TPanel;
  begin
    Result:=TPanel.Create(Self); Result.BevelOuter:=bvNone; Result.Parent:=Parent; Result.Align:=Align;
    if Align in [alLeft,alRight] then Result.Width:=Size else Result.Height:=Size; Result.BorderSpacing.Around:=6;
  end;
  procedure LabelAt(Parent:TWinControl; const Caption:string);
  begin L:=TLabel.Create(Self); L.Parent:=Parent; L.Caption:=Caption; L.Top:=Parent.ClientHeight; L.Align:=alTop; L.BorderSpacing.Bottom:=4; end;
begin
  inherited CreateNew(AOwner); Caption:='TikZ / PGFPlots options'; Position:=poOwnerFormCenter; PopupMode:=pmAuto;
  ClientWidth:=1040; ClientHeight:=680; Constraints.MinWidth:=800; Constraints.MinHeight:=560;
  FCatalog:=TDiagramOptionCatalog.Create; FOwnCatalog:=True;
  Header:=Panel(Self,alTop,36);
  FHeading:=TLabel.Create(Self); FHeading.Parent:=Header; FHeading.Align:=alClient; FHeading.Layout:=tlCenter; FHeading.Font.Style:=[fsBold];
  Footer:=Panel(Self,alBottom,38);
  FCount:=TLabel.Create(Self); FCount.Parent:=Footer; FCount.Align:=alLeft; FCount.Layout:=tlCenter; FCount.AutoSize:=True;
  B:=TButton.Create(Self); B.Parent:=Footer; B.Caption:='Apply'; B.Align:=alRight; B.Width:=100; B.ModalResult:=mrOK; B.Default:=True; B.OnClick:=@Accept;
  B:=TButton.Create(Self); B.Parent:=Footer; B.Caption:='Cancel'; B.Align:=alRight; B.Width:=100; B.BorderSpacing.Right:=8; B.ModalResult:=mrCancel; B.Cancel:=True;
  LeftPane:=Panel(Self,alLeft,320); LeftPane.Constraints.MinWidth:=250;
  Header:=Panel(LeftPane,alTop,92); LabelAt(Header,'Find an option');
  Search:=TEdit.Create(Self); Search.Parent:=Header; Search.SetBounds(0,24,Header.ClientWidth,28); Search.Anchors:=[akLeft,akTop,akRight];
  Search.TextHint:='Search keys or library names'; Search.OnChange:=@Filter;
  Scope:=TComboBox.Create(Self); Scope.AutoSize:=False; Scope.Parent:=Header; Scope.SetBounds(0,56,Header.ClientWidth,32); Scope.Anchors:=[akLeft,akTop,akRight];
  Scope.Style:=csDropDownList;
  Scope.Items.Text:='All options'+#10+'TikZ'+#10+'PGFPlots'+#10+'Lines and fills'+#10+'Nodes and text'+#10+'Arrows'+#10+
    'Position and transformations'+#10+'Axes'+#10+'Ticks and grids'+#10+'Labels and legends'+#10+'Data and sampling'+#10+
    'Surfaces and colors'+#10+'Data visualization'+#10+'Circuits'+#10+'Decorations'+#10+'Graphs and trees'+#10+'Document styles';
  Scope.ItemIndex:=0; Scope.OnChange:=@Filter; Scope.BorderSpacing.Top:=6;
  CatalogList:=TCheckListBox.Create(Self); CatalogList.Parent:=LeftPane; CatalogList.Align:=alClient; CatalogList.BorderSpacing.Top:=6;
  CatalogList.OnClick:=@Browse; CatalogList.OnClickCheck:=@Toggle;
  CatalogList.OnDblClick:=@AddSelected; CatalogList.Hint:='Check or double-click an option to add it'; CatalogList.ShowHint:=True;
  Split:=TSplitter.Create(Self); Split.Parent:=Self; Split.Align:=alLeft; Split.Left:=LeftPane.Width; Split.Width:=6; Split.MinSize:=250; Split.ResizeControl:=LeftPane;
  RightPane:=Panel(Self,alClient,0); LabelAt(RightPane,'Enabled options · order is preserved');
  Fields:=Panel(RightPane,alBottom,250);
  FInfo:=TLabel.Create(Self); FInfo.Parent:=Fields; FInfo.AutoSize:=False; FInfo.SetBounds(0,0,Fields.ClientWidth,36); FInfo.Anchors:=[akLeft,akTop,akRight]; FInfo.WordWrap:=True;
  L:=TLabel.Create(Self); L.Parent:=Fields; L.AutoSize:=False; L.Caption:='Option'; L.SetBounds(0,42,Fields.ClientWidth,20); L.Anchors:=[akLeft,akTop,akRight];
  OptionName:=TEdit.Create(Self); OptionName.Parent:=Fields; OptionName.SetBounds(0,66,Fields.ClientWidth,32); OptionName.Anchors:=[akLeft,akTop,akRight];
  OptionName.OnChange:=@EditValue;
  HasValue:=TCheckBox.Create(Self); HasValue.Parent:=Fields; HasValue.AutoSize:=False; HasValue.SetBounds(0,104,Fields.ClientWidth-162,28); HasValue.Anchors:=[akLeft,akTop,akRight];
  HasValue.Caption:='Set a value'; HasValue.OnChange:=@EditValue;
  OptionValue:=TComboBox.Create(Self); OptionValue.AutoSize:=False; OptionValue.Parent:=Fields; OptionValue.SetBounds(0,138,Fields.ClientWidth,32); OptionValue.Anchors:=[akLeft,akTop,akRight];
  OptionValue.Style:=csDropDown;
  OptionValue.DropDownCount:=12;
  OptionValue.OnChange:=@EditValue;
  SubOptions:=TButton.Create(Self); SubOptions.Name:='EditSubOptions'; SubOptions.Parent:=Fields;
  SubOptions.Caption:='Edit suboptions…'; SubOptions.SetBounds(Fields.ClientWidth-156,102,156,30);
  SubOptions.Anchors:=[akTop,akRight]; SubOptions.OnClick:=@EditChildren;
  SubOptions.Hint:='Edit a nested list such as grid={…}, ticks={…}, or style={…}'; SubOptions.ShowHint:=True;
  Row:=Panel(Fields,alBottom,68);
  for I:=0 to 3 do begin
    B:=TButton.Create(Self); FActions[I]:=B; B.Parent:=Row; B.Tag:=I; B.OnClick:=@Action;
    case I of 0:B.Caption:='Add / update'; 1:B.Caption:='Remove'; 2:B.Caption:='Move up'; 3:B.Caption:='Move down'; end;
    B.SetBounds((I mod 2)*180,(I div 2)*34,172,30);
    B.Anchors:=[akLeft,akTop];
  end;
  Row.ChildSizing.Layout:=cclLeftToRightThenTopToBottom; Row.ChildSizing.ControlsPerLine:=2;
  Row.ChildSizing.EnlargeHorizontal:=crsHomogenousChildResize; Row.ChildSizing.ShrinkHorizontal:=crsScaleChilds; Row.ChildSizing.HorizontalSpacing:=6; Row.ChildSizing.VerticalSpacing:=4;
  Current:=TStringGrid.Create(Self); Current.Parent:=RightPane; Current.Align:=alClient; Current.FixedCols:=0; Current.FixedRows:=1; Current.RowCount:=2;
  Current.Columns.Add.Title.Caption:='Option'; Current.Columns.Add.Title.Caption:='Value'; Current.AutoFillColumns:=True;
  Current.DefaultRowHeight:=28; Current.Options:=[goRowSelect,goHorzLine,goThumbTracking]; Current.OnSelectCell:=@CurrentSelected;
  {$IFDEF LCLgtk3}Current.ScrollBars:=ssBoth;{$ENDIF}
  ApplyTheme(Self);
end;
destructor TDiagramOptionsForm.Destroy;
begin if FOwnCatalog then FCatalog.Free; inherited; end;
procedure TDiagramOptionsForm.Load(const AText,Root,Context:string; Catalog:TDiagramOptionCatalog; const Directory:string;
  OptionContext:TDiagramOptionContext);
begin
  FHeading.Caption:='Options · '+StringReplace(Copy(Root,2,MaxInt),'/',' › ',[rfReplaceAll]);
  FRoot:=Root; FContext:=Context; FDirectory:=Directory; FOptionContext:=OptionContext; FOptions:=DiagramOptions(AText);
  FUpdating:=True;
  try
    FEdited:=False; OptionName.Clear; OptionValue.Items.Clear; OptionValue.Text:=''; SubOptions.Enabled:=False;
    HasValue.Checked:=True; HasValue.Enabled:=OptionContext<>ocNoOptions; OptionName.Enabled:=HasValue.Enabled;
    Search.Enabled:=HasValue.Enabled; Scope.Enabled:=HasValue.Enabled; CatalogList.Enabled:=HasValue.Enabled;
    OptionValue.Enabled:=HasValue.Enabled; FActions[0].Enabled:=HasValue.Enabled;
    FInfo.Hint:=''; FInfo.ShowHint:=False;
  finally FUpdating:=False; end;
  if Catalog<>nil then begin
    if Catalog<>FCatalog then begin if FOwnCatalog then FCatalog.Free; FCatalog:=Catalog; FOwnCatalog:=False; end;
  end else begin
    if not FOwnCatalog then begin FCatalog:=TDiagramOptionCatalog.Create; FOwnCatalog:=True; end;
    FCatalog.LoadInstalled(Context,Directory);
  end;
  RefreshOptions; Filter(nil);
  if Length(FOptions)>0 then Choose(FOptions[0].Name)
  else if OptionContext=ocNoOptions then FInfo.Caption:='This environment does not accept an option list.'
  else FInfo.Caption:='Choose an option from the document’s loaded libraries, or enter a custom key.';
end;
function TDiagramOptionsForm.IndexOf(const KeyName:string):Integer;
var I:Integer;
begin
  Result:=-1; for I:=0 to High(FOptions) do
    if DiagramOptionPath(FOptions[I].Name,FRoot)=DiagramOptionPath(KeyName,FRoot) then Exit(I);
end;
procedure TDiagramOptionsForm.Filter(Sender:TObject);
var I:Integer; Info:TDiagramOptionInfo; Query,KeyName,Prefix,Match:string;
  function Has(const Words:array of string):Boolean;
  var Word:string;
  begin Result:=False; for Word in Words do if Pos(Word,Match)>0 then Exit(True); end;
  function InCategory:Boolean;
  begin
    case Scope.ItemIndex of
      3:Result:=Has(['line','fill','draw','opacity','pattern','dash','thick']);
      4:Result:=Has(['node','text','font','shape','anchor']);
      5:Result:=Has(['arrow','tip','stealth','latex','barb']);
      6:Result:=Has(['position','shift','scale','rotate','transform','distance','calc']);
      7:Result:=Has(['axis','axes','xmin','xmax','ymin','ymax','zmin','zmax','width','height']);
      8:Result:=Has(['tick','grid']);
      9:Result:=Has(['label','legend','title']);
      10:Result:=Has(['data','table','sample','domain','filter','error bar']);
      11:Result:=Has(['surf','mesh','color','shader','point meta','view']);
      12:Result:=Has(['datavisualization','data visualization','visualizer']);
      13:Result:=Has(['circuit','resistor','capacitor','inductor','voltage']);
      14:Result:=Has(['decorat','snake','brace','marking']);
      15:Result:=Has(['graph','tree','child','level','grow']);
      16:Result:=Info.Origin='Document styles';
      else Result:=True;
    end;
  end;
begin
  FUpdating:=True; CatalogList.Items.BeginUpdate;
  try
    CatalogList.Items.Clear; Query:=LowerCase(Trim(Search.Text)); Prefix:='';
    if Scope.ItemIndex=1 then Prefix:='/tikz/' else if Scope.ItemIndex=2 then Prefix:='/pgfplots/';
    for I:=0 to FCatalog.Count-1 do begin
      Info:=FCatalog[I]; if not FCatalog.Available(Info,FRoot,FOptionContext) then Continue;
      if (Prefix<>'') and (Copy(Info.Path,1,Length(Prefix))<>Prefix) then Continue;
      Match:=LowerCase(Info.Path+' '+Info.Origin); if not InCategory then Continue;
      if (Query<>'') and (Pos(Query,Match)=0) then Continue;
      KeyName:=DiagramOptionName(Info.Path,FRoot); CatalogList.Items.AddObject(KeyName,Info);
      CatalogList.Checked[CatalogList.Count-1]:=IndexOf(KeyName)>=0;
    end;
  finally CatalogList.Items.EndUpdate; FUpdating:=False; end;
  FCount.Caption:=IntToStr(CatalogList.Count)+' available · '+IntToStr(Length(FOptions))+' enabled';
end;
procedure TDiagramOptionsForm.EditChildren(Sender:TObject);
var Form:TDiagramOptionsForm; Value,Root,Key,Tip:string; P:Integer;
begin
  Key:=Trim(OptionName.Text); if Key='' then Exit;
  Value:=Trim(OptionValue.Text); P:=1;
  if Copy(Value,1,1)='{' then Value:=ReadTeXGroup(Value,P,'{','}');
  Root:=FCatalog.ChildRoot(Key,FRoot);
  Tip:='';
  if (Root='/pgf/arrow keys') then begin
    P:=Pos('[',Value);
    if P>0 then begin Tip:=Trim(Copy(Value,1,P-1)); Value:=ReadTeXGroup(Value,P,'[',']'); end
    else begin Tip:=Value; Value:=''; end;
    if Tip='' then Tip:='Latex';
  end;
  Form:=TDiagramOptionsForm.Create(Self);
  try
    Form.Caption:='Suboptions: '+Key; Form.Load(Value,Root,FContext,FCatalog,FDirectory,FCatalog.ChildContext(Key,FRoot,FOptionContext));
    if Form.ShowModal=mrOK then begin
      Value:=Form.OptionsText; if Tip<>'' then Value:=Tip+'['+Value+']';
      HasValue.Checked:=True; OptionValue.Text:='{'+Value+'}'; FEdited:=True; Store;
    end;
  finally Form.Free; end;
end;
procedure TDiagramOptionsForm.Choose(KeyName:string);
var Info:TDiagramOptionInfo; I:Integer; Values:TStringList; ChildRoot:string; ChildContext:TDiagramOptionContext;
begin
  if FEdited then Store;
  FUpdating:=True;
  try
    OptionName.Text:=KeyName; OptionValue.Items.Clear; Info:=FCatalog.Find(DiagramOptionPath(KeyName,FRoot));
    FInfo.Caption:='Custom key. Enter its value exactly as in TeX.';
    HasValue.Checked:=True; HasValue.Enabled:=True; OptionValue.Text:='';
    if Info<>nil then begin
      FInfo.Caption:='Source: '+Info.Origin;
      if Info.ValueRequired then FInfo.Caption:=FInfo.Caption+' · value required'
      else if Info.DefaultValue<>'' then FInfo.Caption:=FInfo.Caption+' · default: '+Info.DefaultValue
      else if not Info.TakesValue then FInfo.Caption:=FInfo.Caption+' · flag';
      FInfo.Hint:=Info.Path+LineEnding+FInfo.Caption; FInfo.ShowHint:=True;
      Values:=TStringList.Create;
      try Values.Text:=Info.Choices; OptionValue.Items.Assign(Values); finally Values.Free; end;
      OptionValue.Text:=Info.DefaultValue;
      if (OptionValue.Text='') and (OptionValue.Items.Count>0) then OptionValue.Text:=OptionValue.Items[0];
      HasValue.Checked:=Info.TakesValue;
    end;
    I:=IndexOf(KeyName); if I>=0 then begin HasValue.Checked:=FOptions[I].HasValue; OptionValue.Text:=FOptions[I].Value; end;
    if Info<>nil then begin
      HasValue.Enabled:=not (Info.ValueRequired or Info.ValueForbidden);
      if Info.ValueRequired then HasValue.Checked:=True;
      if Info.ValueForbidden then HasValue.Checked:=False;
    end;
    FActions[1].Enabled:=I>=0; FActions[2].Enabled:=I>0; FActions[3].Enabled:=(I>=0) and (I<High(FOptions));
    OptionValue.Enabled:=HasValue.Checked;
    ChildRoot:=FCatalog.ChildRoot(KeyName,FRoot); ChildContext:=FCatalog.ChildContext(KeyName,FRoot,FOptionContext);
    SubOptions.Enabled:=False;
    if (Info=nil) or not Info.Choice then
      for I:=0 to FCatalog.Count-1 do if FCatalog.Available(FCatalog[I],ChildRoot,ChildContext) then begin SubOptions.Enabled:=True; Break; end;
  finally FEdited:=False; FUpdating:=False; end;
end;
procedure TDiagramOptionsForm.Browse(Sender:TObject);
begin if not FUpdating and (CatalogList.ItemIndex>=0) then Choose(CatalogList.Items[CatalogList.ItemIndex]); end;
procedure TDiagramOptionsForm.AddSelected(Sender:TObject);
begin
  if FUpdating or (CatalogList.ItemIndex<0) then Exit;
  Choose(CatalogList.Items[CatalogList.ItemIndex]); Store;
end;
procedure TDiagramOptionsForm.Toggle(Sender:TObject);
var I,J:Integer; KeyName:string;
begin
  if FUpdating or (CatalogList.ItemIndex<0) then Exit; KeyName:=CatalogList.Items[CatalogList.ItemIndex];
  if CatalogList.Checked[CatalogList.ItemIndex] then begin Choose(KeyName); Store; end
  else begin
    if DiagramOptionPath(Trim(OptionName.Text),FRoot)=DiagramOptionPath(KeyName,FRoot) then FEdited:=False
    else if FEdited then Store;
    I:=IndexOf(KeyName); if I>=0 then begin for J:=I to High(FOptions)-1 do FOptions[J]:=FOptions[J+1]; SetLength(FOptions,Length(FOptions)-1); end;
    RefreshOptions; Choose(KeyName);
  end;
end;
procedure TDiagramOptionsForm.CurrentSelected(Sender:TObject; Col,Row:Integer; var CanSelect:Boolean);
begin if not FUpdating and (Row>0) and (Row<=Length(FOptions)) then Choose(FOptions[Row-1].Name); end;
procedure TDiagramOptionsForm.EditValue(Sender:TObject);
begin if not FUpdating then begin OptionValue.Enabled:=HasValue.Checked; FEdited:=True; end; end;
procedure TDiagramOptionsForm.RefreshOptions;
var I:Integer;
begin
  FUpdating:=True; Current.BeginUpdate;
  try
    Current.RowCount:=Max(2,Length(FOptions)+1);
    for I:=1 to Current.RowCount-1 do begin
      Current.Cells[0,I]:=''; Current.Cells[1,I]:='';
      if I<=Length(FOptions) then begin Current.Cells[0,I]:=FOptions[I-1].Name; if FOptions[I-1].HasValue then Current.Cells[1,I]:=FOptions[I-1].Value; end;
    end;
    for I:=0 to CatalogList.Count-1 do CatalogList.Checked[I]:=IndexOf(CatalogList.Items[I])>=0;
  finally Current.EndUpdate; FUpdating:=False; end;
  FActions[1].Enabled:=Length(FOptions)>0; FActions[2].Enabled:=(Current.Row>1) and (Length(FOptions)>1);
  FActions[3].Enabled:=(Current.Row<Length(FOptions)) and (Length(FOptions)>1);
  if FCount<>nil then FCount.Caption:=IntToStr(CatalogList.Count)+' available · '+IntToStr(Length(FOptions))+' enabled';
end;
procedure TDiagramOptionsForm.Store;
var I:Integer; KeyName,Value:string;
begin
  KeyName:=Trim(OptionName.Text); if KeyName='' then Exit; I:=IndexOf(KeyName);
  if I<0 then begin I:=Length(FOptions); SetLength(FOptions,I+1); end;
  FOptions[I].Name:=KeyName; FOptions[I].HasValue:=HasValue.Checked; Value:=OptionValue.Text;
  if (Pos(',',Value)>0) and (Copy(Trim(Value),1,1)<>'{') then Value:='{'+Value+'}';
  FOptions[I].Value:=Value; FEdited:=False; RefreshOptions;
  FUpdating:=True; try Current.Row:=I+1; finally FUpdating:=False; end;
end;
procedure TDiagramOptionsForm.Accept(Sender:TObject);
begin if FEdited then Store; end;
procedure TDiagramOptionsForm.Action(Sender:TObject);
var I,J:Integer; Swap:TDiagramOption;
begin
  if TComponent(Sender).Tag=0 then begin Store; Exit; end;
  if TComponent(Sender).Tag=1 then FEdited:=False else if FEdited then Store;
  I:=Current.Row-1; if (I<0) or (I>=Length(FOptions)) then Exit; J:=I;
  case TComponent(Sender).Tag of
    1:begin for J:=I to High(FOptions)-1 do FOptions[J]:=FOptions[J+1]; SetLength(FOptions,Length(FOptions)-1); J:=I; end;
    2:if I>0 then J:=I-1;
    3:if I<High(FOptions) then J:=I+1;
  end;
  if (TComponent(Sender).Tag<>1) and (I<>J) then begin Swap:=FOptions[I]; FOptions[I]:=FOptions[J]; FOptions[J]:=Swap; end;
  RefreshOptions; Current.Row:=EnsureRange(J+1,1,Current.RowCount-1);
  if Length(FOptions)>0 then Choose(FOptions[Current.Row-1].Name)
  else begin
    FUpdating:=True; try OptionName.Clear; OptionValue.Text:=''; finally FUpdating:=False; FEdited:=False; end;
  end;
end;
function TDiagramOptionsForm.OptionsText:string;
begin Result:=DiagramOptionSource(FOptions); end;
end.
