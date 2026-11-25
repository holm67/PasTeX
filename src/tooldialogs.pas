unit ToolDialogs;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Spin, Grids,
  Graphics, Buttons, Math, UITheme, MathModel, MathSpacing, SynEdit;
type
  TZoomDialog=class(TForm)
  private
    procedure ModeChanged(Sender:TObject);
  public
    Mode:TComboBox;
    Percent:TSpinEdit;
    constructor Create(AOwner:TComponent); override;
    procedure Load(Value:Integer; FitWidth,FitPage,Paged:Boolean);
  end;
  TMatrixDialog=class(TForm)
  private
    Grid:TDrawGrid;
    procedure DrawCell(Sender:TObject; Col,Row:Integer; R:TRect; State:TGridDrawState);
    procedure SelectCell(Sender:TObject; Col,Row:Integer; var CanSelect:Boolean);
    procedure SizeChanged(Sender:TObject);
  public
    Rows,Columns:TSpinEdit;
    Kind:TComboBox;
    constructor Create(AOwner:TComponent); override;
    function TeX:string;
  end;
type
  TCommandDialog=class(TForm)
  private
    Arguments,Separators:TStringList;
    Trailing:string;
    ArgumentButtons:array[0..3] of TButton;
    FUpdatingArguments:Boolean;
    FArgumentIndex:Integer;
    procedure SelectArgumentRow(Sender:TObject; ACol,ARow:Integer; var CanSelect:Boolean);
    procedure SelectArgument(Sender:TObject);
    procedure ChangeArgument(Sender:TObject);
    procedure ArgumentAction(Sender:TObject);
    procedure RefreshArguments(Index:Integer);
    function ArgumentCaption(Index:Integer):string;
  public
    CommandName:TEdit;
    ArgumentValue:TSynEdit;
    ArgumentList:TStringGrid;
    ArgumentKind:TComboBox;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure LoadSource(const Source:string);
    function Source:string;
  end;
  TMathSpaceDialog=class(TForm)
  private
    FVertical:Boolean;
    FUpdating:Boolean;
    procedure PresetChanged(Sender:TObject);
    procedure WidthChanged(Sender:TObject);
  public
    Preset,Units:TComboBox;
    SpaceWidth:TEdit;
    constructor Create(AOwner:TComponent); override;
    procedure LoadSource(const Source:string);
    function Source:string;
  end;
function EditMathSpaceDialog(Owner:TComponent; var Source:string):Boolean;
function EditIndentDialog(Owner:TComponent; var Source:string):Boolean;
function ChooseSymbol(Owner:TComponent; Commands:TStrings; out Code:string; ArrowGallery:Boolean=False):Boolean;
function EditCommandDialog(Owner:TComponent; var Source:string; const Caption:string='Edit command and arguments'):Boolean;
function ChooseTextSize(Owner:TComponent; var Size,Baseline:string):Boolean;
implementation
uses TeXMacros, TeXStyles, TeXGlyphs, MathCommands, Dialogs, SourceFonts, SourceStyle,
  SynEditWrappedView, UnicodeEdits, IniFiles;
procedure DialogButtons(D:TForm; const Accept:string);
var B:TButton;
begin
  B:=TButton.Create(D); B.Parent:=D; B.SetBounds(D.ClientWidth-204,D.ClientHeight-44,92,30);
  B.Caption:=Accept; B.ModalResult:=mrOK; B.Default:=True;
  B.Anchors:=[akRight,akBottom];
  B:=TButton.Create(D); B.Parent:=D; B.SetBounds(D.ClientWidth-104,D.ClientHeight-44,92,30);
  B.Caption:='Cancel'; B.ModalResult:=mrCancel; B.Cancel:=True;
  B.Anchors:=[akRight,akBottom];
end;
constructor TZoomDialog.Create(AOwner:TComponent);
var L:TLabel;
begin
  inherited CreateNew(AOwner); Name:='PreviewZoomDialog'; Caption:='Preview scale';
  Position:=poMainFormCenter; BorderStyle:=bsDialog; ClientWidth:=340; ClientHeight:=180;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(16,18,92,24); L.Caption:='Fit to';
  Mode:=TComboBox.Create(Self); Mode.Parent:=Self; Mode.SetBounds(112,14,212,30);
  Mode.Style:=csDropDownList; Mode.Items.Add('Percentage'); Mode.Items.Add('Fit Width'); Mode.OnChange:=@ModeChanged;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(16,64,92,24); L.Caption:='Percentage';
  Percent:=TSpinEdit.Create(Self); Percent.Parent:=Self; Percent.SetBounds(112,60,176,30);
  Percent.MinValue:=50; Percent.MaxValue:=200; Percent.Increment:=5;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(296,64,24,24); L.Caption:='%';
  DialogButtons(Self,'Apply'); ApplyTheme(Self);
end;
procedure TZoomDialog.Load(Value:Integer; FitWidth,FitPage,Paged:Boolean);
begin
  if Paged then Mode.Items.Add('Fit Page');
  Percent.Value:=Value; Mode.ItemIndex:=0;
  if FitWidth then Mode.ItemIndex:=1;
  if Paged and FitPage then Mode.ItemIndex:=2;
  ModeChanged(nil);
end;
procedure TZoomDialog.ModeChanged(Sender:TObject);
begin Percent.Enabled:=Mode.ItemIndex=0; end;
function EditIndentDialog(Owner:TComponent; var Source:string):Boolean;
var D:TForm; Choice:TComboBox; L:TLabel;
begin
  Result:=False; D:=TForm.CreateNew(Owner);
  try
    D.Caption:='Paragraph indentation'; D.Position:=poMainFormCenter; D.BorderStyle:=bsDialog;
    D.ClientWidth:=350; D.ClientHeight:=160;
    L:=TLabel.Create(D); L.Parent:=D; L.SetBounds(16,12,318,22); L.Caption:='Indentation command';
    Choice:=TComboBox.Create(D); Choice.Name:='ParagraphIndentCommand'; Choice.Parent:=D; Choice.SetBounds(16,42,318,30);
    Choice.Style:=csDropDownList; Choice.Items.Add('Indent (\indent)'); Choice.Items.Add('No indent (\noindent)');
    Choice.Items.Add('Remove command'); Choice.ItemIndex:=Ord(Source='\noindent');
    DialogButtons(D,'Apply'); ApplyTheme(D); if D.ShowModal<>mrOK then Exit;
    case Choice.ItemIndex of 0:Source:='\indent'; 1:Source:='\noindent'; else Source:=''; end;
    Result:=True;
  finally D.Free; end;
end;
function ChooseTextSize(Owner:TComponent; var Size,Baseline:string):Boolean;
var D:TForm; Number:TEdit; Units:TComboBox; L:TLabel; Value,Points:Double; F:TFormatSettings;
begin
  Result:=False; D:=TForm.CreateNew(Owner);
  try
    D.Caption:='Custom font size'; D.Position:=poMainFormCenter; D.BorderStyle:=bsDialog;
    D.ClientWidth:=320; D.ClientHeight:=150;
    L:=TLabel.Create(D); L.Parent:=D; L.SetBounds(16,12,282,20); L.Caption:='Character size';
    Number:=TEdit.Create(D); Number.Name:='CharacterSizeValue'; Number.Parent:=D;
    Number.SetBounds(16,38,180,30); Number.Text:='13';
    Units:=TComboBox.Create(D); Units.Name:='CharacterSizeUnit'; Units.Parent:=D;
    Units.SetBounds(204,38,100,30); Units.Style:=csDropDownList;
    Units.Items.CommaText:='pt,bp,pc,mm,cm,in,em,ex'; Units.ItemIndex:=0;
    DialogButtons(D,'Apply'); ApplyTheme(D); F:=DefaultFormatSettings; F.DecimalSeparator:='.';
    repeat
      if D.ShowModal<>mrOK then Exit;
      Size:=Trim(Number.Text)+Units.Text; Points:=TeXStyleDimension(Size,10);
      if TryStrToFloat(Trim(Number.Text),Value,F) and (Points>=1) and (Points<=240) then Break;
      MessageDlg('Font size','Enter a size between 1 and 240 TeX points.',mtInformation,[mbOK],0);
    until False;
    Baseline:=FloatToStr(Value*1.2,F)+Units.Text; Result:=True;
  finally D.Free; end;
end;
constructor TMatrixDialog.Create(AOwner:TComponent);
var L:TLabel;
begin
  inherited CreateNew(AOwner);
  Caption:='Insert matrix'; Position:=poMainFormCenter; BorderStyle:=bsDialog;
  ClientWidth:=400; ClientHeight:=410;
  Kind:=TComboBox.Create(Self); Kind.Parent:=Self; Kind.SetBounds(16,14,366,30); Kind.Style:=csDropDownList;
  Kind.Items.CommaText:='pmatrix,bmatrix,Bmatrix,vmatrix,Vmatrix,matrix'; Kind.ItemIndex:=0;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(16,56,366,22); L.Caption:='Click a cell to choose the matrix size';
  Grid:=TDrawGrid.Create(Self); Grid.Parent:=Self; Grid.SetBounds(16,82,366,224);
  Grid.FixedCols:=0; Grid.FixedRows:=0; Grid.ColCount:=10; Grid.RowCount:=6;
  Grid.DefaultColWidth:=34; Grid.DefaultRowHeight:=34; Grid.ScrollBars:=ssNone;
  Grid.OnDrawCell:=@DrawCell; Grid.OnSelectCell:=@SelectCell;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(16,324,46,24); L.Caption:='Rows';
  Rows:=TSpinEdit.Create(Self); Rows.Parent:=Self; Rows.SetBounds(64,318,84,30); Rows.MinValue:=1; Rows.MaxValue:=20; Rows.Value:=2;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(178,324,70,24); L.Caption:='Columns';
  Columns:=TSpinEdit.Create(Self); Columns.Parent:=Self; Columns.SetBounds(252,318,84,30); Columns.MinValue:=1; Columns.MaxValue:=20; Columns.Value:=2;
  Rows.OnChange:=@SizeChanged; Columns.OnChange:=@SizeChanged;
  DialogButtons(Self,'Insert'); ApplyTheme(Self);
end;
procedure TMatrixDialog.DrawCell(Sender:TObject; Col,Row:Integer; R:TRect; State:TGridDrawState);
begin
  Grid.Canvas.Brush.Color:=PaperColor;
  if (Col<Columns.Value) and (Row<Rows.Value) then Grid.Canvas.Brush.Color:=$AC7540;
  Grid.Canvas.FillRect(R); Grid.Canvas.Pen.Color:=InkColor; Grid.Canvas.Rectangle(R);
end;
procedure TMatrixDialog.SelectCell(Sender:TObject; Col,Row:Integer; var CanSelect:Boolean);
begin Rows.Value:=Row+1; Columns.Value:=Col+1; Grid.Invalidate; end;
procedure TMatrixDialog.SizeChanged(Sender:TObject);
begin Grid.Invalidate; end;
function TMatrixDialog.TeX:string;
var I,J:Integer;
begin
  Result:='\begin{'+Kind.Text+'}';
  for I:=1 to Rows.Value do begin
    if I>1 then Result:=Result+'\\'+LineEnding;
    for J:=1 to Columns.Value do begin if J>1 then Result:=Result+'&'; Result:=Result+' '; end;
  end;
  Result:=Result+'\end{'+Kind.Text+'}';
end;
function ChooseSymbol(Owner:TComponent; Commands:TStrings; out Code:string; ArrowGallery:Boolean):Boolean;
var D:TForm; Scroll:TScrollBox; B:TBitBtn; I,J,Answer,Index,Group:Integer; S,Name:string; Em:Double; Bounds:TRect;
    Tabs:TPageControl; Page:TTabSheet; Groups:array[0..2] of TFlowPanel;
const Titles:array[0..2] of string=('No arguments','Upper and optional lower labels','Over / under an argument');
begin
  Result:=False; D:=TForm.CreateNew(Owner);
  try
    D.Caption:='Math symbols — hover for the TeX command'; D.Position:=poMainFormCenter;
    D.ClientWidth:=660; D.ClientHeight:=420; D.Constraints.MinWidth:=330; D.Constraints.MinHeight:=240;
    Tabs:=nil; FillChar(Groups,SizeOf(Groups),0);
    if ArrowGallery then begin
      D.Caption:='Math symbols — Arrows'; Tabs:=TPageControl.Create(D); Tabs.Name:='ArrowGroups'; Tabs.Parent:=D; Tabs.Align:=alClient;
    end;
    for J:=0 to 2 do begin
      if (J>0) and not ArrowGallery then begin Groups[J]:=Groups[0]; Continue; end;
      Scroll:=TScrollBox.Create(D);
      if Tabs<>nil then begin
        Page:=Tabs.AddTabSheet; Page.Caption:=Titles[J]; Scroll.Parent:=Page;
      end else Scroll.Parent:=D;
      Scroll.Align:=alClient; Scroll.BorderStyle:=bsNone; Scroll.HorzScrollBar.Visible:=False;
      Groups[J]:=TFlowPanel.Create(D); Groups[J].Parent:=Scroll; Groups[J].Align:=alTop;
      Groups[J].AutoSize:=True; Groups[J].BevelOuter:=bvNone; Groups[J].BorderSpacing.Around:=6;
    end;
    for I:=0 to Commands.Count-1 do begin
      Name:=Commands[I]; if Copy(Name,1,1)='\' then Delete(Name,1,1);
      S:=SymbolDisplay(Name); if S='' then S:=Name;
      Group:=0;
      if IsExtensibleMathArrow(Name) then Group:=1 else if MathArgumentCount(Name)>0 then Group:=2;
      B:=TBitBtn.Create(D); B.Parent:=Groups[Group]; B.SetBounds(0,0,58,44); B.BorderSpacing.Around:=2;
      B.Caption:=S; B.Hint:=Commands[I]; B.ShowHint:=True; B.ModalResult:=100+I;
      if Length(S)<=4 then B.Font.Size:=18 else B.Font.Size:=11;
      if IsExtensibleMathArrow(Name) then Index:=ChooseTeXGlyph('arrow-'+Name,1.8)
      else Index:=ChooseTeXGlyph('math-symbol-10-'+Name);
      if Index>=0 then begin
        Em:=Min(24,Min(42/Max(0.1,TeXGlyphMetrics[Index].W),30/Max(0.1,TeXGlyphMetrics[Index].H)));
        B.Glyph.SetSize(46,34); B.Glyph.Canvas.Brush.Color:=PaperColor; B.Glyph.Canvas.FillRect(Rect(0,0,46,34));
        Bounds:=TeXGlyphInkBounds(Index,Round((46-TeXGlyphMetrics[Index].W*Em)/2-TeXGlyphLeft(Index)*Em),
          Round((34-TeXGlyphMetrics[Index].H*Em)/2+TeXGlyphMetrics[Index].Above*Em),Em);
        if DrawTeXGlyph(B.Glyph.Canvas,Index,Bounds,InkColor,Em) then B.Caption:='';
        B.Glyph.TransparentColor:=PaperColor; B.Glyph.Transparent:=True;
      end;
    end;
    ApplyTheme(D); Answer:=D.ShowModal;
    Result:=(Answer>=100) and (Answer<100+Commands.Count);
    if Result then Code:=Commands[Answer-100];
  finally D.Free; end;
end;
constructor TCommandDialog.Create(AOwner:TComponent);
var L:TLabel; B:TButton; I:Integer; Ini:TIniFile;
const Captions:array[0..3] of string=('Add','Delete','Move up','Move down');
begin
  inherited CreateNew(AOwner); Arguments:=TStringList.Create; Separators:=TStringList.Create;
  Caption:='Edit command and arguments'; Position:=poMainFormCenter;
  ClientWidth:=620; ClientHeight:=530; Constraints.MinWidth:=560; Constraints.MinHeight:=480;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(16,18,124,24); L.Caption:='Command name';
  CommandName:=TUnicodeEdit.Create(Self); CommandName.Parent:=Self; CommandName.SetBounds(152,14,452,30); CommandName.Anchors:=[akLeft,akRight,akTop];
  ArgumentList:=TStringGrid.Create(Self); ArgumentList.Parent:=Self; ArgumentList.SetBounds(16,60,458,150); ArgumentList.Anchors:=[akLeft,akRight,akTop];
  ArgumentList.ColCount:=1; ArgumentList.FixedCols:=0; ArgumentList.FixedRows:=1;
  ArgumentList.AutoFillColumns:=True;
  ArgumentList.RowCount:=2; ArgumentList.ColWidths[0]:=374;
  ArgumentList.Cells[0,0]:='Arguments'; ArgumentList.Options:=[goRowSelect,goThumbTracking,goHorzLine];
  ArgumentList.OnSelectCell:=@SelectArgumentRow; FArgumentIndex:=-1;
  for I:=0 to 3 do begin
    B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(486,60+I*38,118,32); B.Anchors:=[akRight,akTop]; ArgumentButtons[I]:=B;
    B.Caption:=Captions[I]; B.Tag:=I; B.OnClick:=@ArgumentAction;
  end;
  ArgumentKind:=TComboBox.Create(Self); ArgumentKind.Parent:=Self; ArgumentKind.SetBounds(16,226,170,30);
  ArgumentKind.Style:=csDropDownList; ArgumentKind.Items.Add('Required {...}');
  ArgumentKind.Items.Add('Optional [...]'); ArgumentKind.Items.Add('Literal');
  ArgumentKind.OnChange:=@ChangeArgument;
  ArgumentValue:=TSynEdit.Create(Self); ArgumentValue.Parent:=Self; ArgumentValue.SetBounds(16,266,588,176);
  ArgumentValue.Anchors:=[akLeft,akRight,akTop,akBottom]; UseNativeSourceFonts(ArgumentValue);
  ArgumentValue.SetDefaultKeystrokes; ArgumentValue.ResetMouseActions; TLazSynEditLineWrapPlugin.Create(ArgumentValue);
  Ini:=TIniFile.Create(GetAppConfigFile(False));
  try
    ArgumentValue.Font.Name:=NormalizeSourceFont(Ini.ReadString('Editor','FontName',DefaultSourceFont));
    ArgumentValue.Font.Size:=EnsureRange(Ini.ReadInteger('Editor','FontSize',12),8,36);
  finally Ini.Free; end;
  ArgumentValue.OnChange:=@ChangeArgument;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(196,230,408,24); L.Caption:='Argument contents'; L.Anchors:=[akLeft,akRight,akTop];
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(16,454,588,32); L.Anchors:=[akLeft,akRight,akBottom]; L.WordWrap:=True;
  L.Caption:='Edit the argument contents; braces are added automatically.';
  DialogButtons(Self,'Apply'); ApplyTheme(Self); ApplySourceStyle(ArgumentValue);
end;
destructor TCommandDialog.Destroy;
begin Arguments.Free; Separators.Free; inherited Destroy; end;
procedure TCommandDialog.RefreshArguments(Index:Integer);
var I:Integer;
begin
  FUpdatingArguments:=True;
  try
    ArgumentList.RowCount:=Max(2,Arguments.Count+1);
    if Arguments.Count=0 then ArgumentList.Cells[0,1]:='';
    for I:=0 to Arguments.Count-1 do ArgumentList.Cells[0,I+1]:=ArgumentCaption(I);
    FArgumentIndex:=Min(Index,Arguments.Count-1); ArgumentList.Row:=Max(1,FArgumentIndex+1);
  finally FUpdatingArguments:=False; end;
  SelectArgument(nil);
end;
function TCommandDialog.ArgumentCaption(Index:Integer):string;
var S:string;
begin
  S:=Arguments[Index];
  case PtrInt(Arguments.Objects[Index]) of 0:S:='{'+S+'}'; 1:S:='['+S+']'; end;
  Result:=IntToStr(Index+1)+'. '+StringReplace(S,LineEnding,' ',[rfReplaceAll]);
end;
procedure TCommandDialog.SelectArgumentRow(Sender:TObject; ACol,ARow:Integer; var CanSelect:Boolean);
begin
  if FUpdatingArguments then Exit;
  ChangeArgument(nil);
  FArgumentIndex:=ARow-1; if FArgumentIndex>=Arguments.Count then FArgumentIndex:=-1;
  SelectArgument(Sender);
end;
procedure TCommandDialog.SelectArgument(Sender:TObject);
var I:Integer;
begin
  FUpdatingArguments:=True;
  try
    I:=FArgumentIndex; ArgumentValue.Enabled:=I>=0; ArgumentKind.Enabled:=I>=0;
    if I>=0 then begin ArgumentValue.Text:=Arguments[I]; ArgumentKind.ItemIndex:=PtrInt(Arguments.Objects[I]); end
    else begin ArgumentValue.Text:=''; ArgumentKind.ItemIndex:=-1; end;
    ArgumentButtons[1].Enabled:=I>=0; ArgumentButtons[2].Enabled:=I>0;
    ArgumentButtons[3].Enabled:=(I>=0) and (I<Arguments.Count-1);
  finally FUpdatingArguments:=False; end;
end;
procedure TCommandDialog.ChangeArgument(Sender:TObject);
var I:Integer;
begin
  I:=FArgumentIndex; if FUpdatingArguments or (I<0) then Exit;
  Arguments[I]:=SourceEditorText(ArgumentValue); Arguments.Objects[I]:=TObject(PtrInt(Max(0,ArgumentKind.ItemIndex)));
  ArgumentList.Cells[0,I+1]:=ArgumentCaption(I);
end;
procedure TCommandDialog.ArgumentAction(Sender:TObject);
var I,J:Integer;
begin
  ChangeArgument(nil);
  I:=FArgumentIndex;
  case TControl(Sender).Tag of
    0:begin I:=Arguments.AddObject('',TObject(PtrInt(0))); Separators.Add(''); end;
    1:if I>=0 then begin Arguments.Delete(I); Separators.Delete(I); end;
    2,3:if I>=0 then begin
      J:=I-1; if TControl(Sender).Tag=3 then J:=I+1;
      if (J>=0) and (J<Arguments.Count) then begin Arguments.Exchange(I,J); Separators.Exchange(I,J); I:=J; end;
    end;
  end;
  RefreshArguments(I); if ArgumentValue.CanFocus then ArgumentValue.SetFocus;
end;
procedure TCommandDialog.LoadSource(const Source:string);
var P,Start,Kind:Integer; S:string; OpenChar,CloseChar:Char;
begin
  Arguments.Clear; Separators.Clear; Trailing:=''; P:=1; CommandName.Text:=ReadTeXCommand(Source,P);
  if Copy(Source,P,1)='*' then begin CommandName.Text:=CommandName.Text+'*'; Inc(P); end;
  while P<=Length(Source) do begin
    Start:=P; SkipTeXSpace(Source,P); if P>Length(Source) then begin Trailing:=Copy(Source,Start,MaxInt); Break; end;
    Separators.Add(Copy(Source,Start,P-Start));
    if Source[P] in ['{','['] then begin
      OpenChar:=Source[P]; Kind:=0; CloseChar:='}';
      if OpenChar='[' then begin Kind:=1; CloseChar:=']'; end;
      S:=ReadTeXGroup(Source,P,OpenChar,CloseChar);
    end else begin
      Kind:=2; S:=ReadTeXArgument(Source,P);
    end;
    Arguments.AddObject(S,TObject(PtrInt(Kind)));
  end;
  RefreshArguments(0);
end;
function TCommandDialog.Source:string;
var I:Integer; S:string;
begin
  ChangeArgument(nil);
  Result:=CommandName.Text; if (Result<>' ') and (Result<>'\ ') then Result:=Trim(Result);
  if Copy(Result,1,1)<>'\' then Result:='\'+Result;
  for I:=0 to Arguments.Count-1 do begin
    S:=Arguments[I];
    case PtrInt(Arguments.Objects[I]) of 0:S:='{'+S+'}'; 1:S:='['+S+']'; end;
    Result:=Result+Separators[I];
    if (PtrInt(Arguments.Objects[I])=2) and (S<>'') and (S[1] in ['a'..'z','A'..'Z','@']) and EndsTeXControlWord(Result) then Result:=Result+' ';
    Result:=Result+S;
  end;
  Result:=Result+Trailing;
end;
function EditCommandDialog(Owner:TComponent; var Source:string; const Caption:string):Boolean;
var D:TCommandDialog;
begin
  D:=TCommandDialog.Create(Owner);
  try D.Caption:=Caption; D.LoadSource(Source); Result:=D.ShowModal=mrOK; if Result then Source:=D.Source;
  finally D.Free; end;
end;
constructor TMathSpaceDialog.Create(AOwner:TComponent);
var L:TLabel;
begin
  inherited CreateNew(AOwner);
  Caption:='Math space'; Position:=poMainFormCenter; BorderStyle:=bsDialog;
  ClientWidth:=380; ClientHeight:=188;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(16,18,70,24); L.Caption:='Space';
  Preset:=TComboBox.Create(Self); Preset.Parent:=Self; Preset.SetBounds(88,14,276,32);
  Preset.Style:=csDropDownList;
  Preset.Items.Add('Custom width');
  Preset.Items.Add('\quad'); Preset.Items.Add('\qquad'); Preset.Items.Add('\enspace'); Preset.Items.Add('\enskip');
  Preset.Items.Add('\,'); Preset.Items.Add('\:'); Preset.Items.Add('\;'); Preset.Items.Add('\!'); Preset.Items.Add('\ ');
  Preset.Items.Add('\thinspace'); Preset.Items.Add('\medspace'); Preset.Items.Add('\thickspace');
  Preset.Items.Add('\negthinspace'); Preset.Items.Add('\negmedspace'); Preset.Items.Add('\negthickspace');
  Preset.Items.Add('\>'); Preset.Items.Add('\space'); Preset.ItemIndex:=0;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(16,66,70,24); L.Caption:='Width';
  SpaceWidth:=TEdit.Create(Self); SpaceWidth.Parent:=Self; SpaceWidth.SetBounds(88,62,164,32);
  Units:=TComboBox.Create(Self); Units.Parent:=Self; Units.SetBounds(264,62,100,32);
  Units.Style:=csDropDownList; Units.Items.CommaText:='em,ex,pt,mu'; Units.ItemIndex:=0;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(16,104,348,24);
  L.Caption:='Change the width or units to use a custom space.';
  Preset.OnChange:=@PresetChanged; SpaceWidth.OnChange:=@WidthChanged; Units.OnChange:=@WidthChanged;
  DialogButtons(Self,'Apply'); ApplyTheme(Self);
end;
procedure TMathSpaceDialog.LoadSource(const Source:string);
var Value:Double; DimensionUnit,Command:string; F:TFormatSettings; P:Integer;
begin
  if ReadVerticalSpace(Source,Value,DimensionUnit) then begin
    if not FVertical then begin
      FVertical:=True; Caption:='Vertical space'; Preset.Items.Clear;
      Preset.Items.Add('Custom height'); Preset.Items.Add('\smallskip'); Preset.Items.Add('\medskip'); Preset.Items.Add('\bigskip');
      Units.Items.CommaText:='em,ex,pt,bp,mm,cm,in';
    end;
  end else if not ReadMathSpace(Source,Value,DimensionUnit) then Exit;
  FUpdating:=True;
  try
    P:=1; Command:='\'+ReadTeXCommand(Source,P);
    Preset.ItemIndex:=Max(0,Preset.Items.IndexOf(Command));
    F:=DefaultFormatSettings; F.DecimalSeparator:='.'; SpaceWidth.Text:=FloatToStr(Value,F);
    Units.ItemIndex:=Units.Items.IndexOf(DimensionUnit);
  finally FUpdating:=False; end;
end;
procedure TMathSpaceDialog.PresetChanged(Sender:TObject);
begin
  if not FUpdating and (Preset.ItemIndex>0) then LoadSource(Preset.Items[Preset.ItemIndex]);
end;
procedure TMathSpaceDialog.WidthChanged(Sender:TObject);
begin if not FUpdating then Preset.ItemIndex:=0; end;
function TMathSpaceDialog.Source:string;
var DimensionUnit:string;
begin
  if Preset.ItemIndex>0 then Exit(Preset.Items[Preset.ItemIndex]);
  DimensionUnit:=Units.Text;
  if FVertical then Result:='\vspace{' else if DimensionUnit='mu' then Result:='\mspace{' else Result:='\hspace{';
  Result:=Result+Trim(SpaceWidth.Text)+DimensionUnit+'}';
end;
function EditMathSpaceDialog(Owner:TComponent; var Source:string):Boolean;
var D:TMathSpaceDialog; Value:Double; UnitName,Candidate:string;
begin
  Result:=False; if not ReadMathSpace(Source,Value,UnitName) and not ReadVerticalSpace(Source,Value,UnitName) then Exit;
  D:=TMathSpaceDialog.Create(Owner);
  try
    D.LoadSource(Source);
    repeat
      Result:=D.ShowModal=mrOK; if not Result then Exit;
      Candidate:=D.Source;
      if ReadMathSpace(Candidate,Value,UnitName) or ReadVerticalSpace(Candidate,Value,UnitName) then begin
        if (D.Preset.ItemIndex>0) or D.FVertical then Source:=Candidate else Source:=SpaceSource(Value,UnitName);
        Exit;
      end;
      MessageDlg('Math space','Enter a width between -1000 and 1000, using a decimal point.',mtError,[mbOK],0);
    until False;
  finally D.Free; end;
end;
end.
