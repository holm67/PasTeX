unit ObjectDialogs;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Contnrs, Types, Math, Graphics, Forms, Controls, StdCtrls, ExtCtrls, Spin,
  Dialogs, Grids, UITheme, TeXMacros, TeXTables, MathModel, ParagraphModel, PDFInclusion, EnvironmentOptions;
type
  TEnvironmentDialog=class(TForm)
  private
    procedure Changed(Sender:TObject);
    procedure Accept(Sender:TObject);
  public
    EnvironmentName,PackageName:TComboBox;
    Arguments:TEdit;
    constructor Create(AOwner:TComponent); override;
    function Source(out Caret:Integer):string;
  end;
  TTheoremSpec=class
    Name,Title,Style,Shared,Within,OriginalName,OriginalDeclaration:string;
    Starred:Boolean;
    function Declaration:string;
  end;
  TTheoremDialog=class(TForm)
  private
    FSource:string;
    FSpecs:TObjectList;
    FUpdating:Boolean;
    procedure SelectTheorem(Sender:TObject);
    procedure Changed(Sender:TObject);
    procedure Action(Sender:TObject);
    procedure Accept(Sender:TObject);
    procedure RefreshList(Index:Integer);
  public
    List:TListBox;
    EnvironmentName,Title:TEdit;
    Style,Shared,Within:TComboBox;
    Starred:TCheckBox;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(const Preamble:string);
    function Preamble:string;
  end;
  TTableDialog=class(TForm)
  private
    Grid:TDrawGrid;
    procedure DrawCell(Sender:TObject; Col,Row:Integer; R:TRect; State:TGridDrawState);
    procedure SelectCell(Sender:TObject; Col,Row:Integer; var CanSelect:Boolean);
    procedure SizeChanged(Sender:TObject);
  public
    Rows,Columns:TSpinEdit;
    Alignment,CaptionPosition,Placement:TComboBox;
    Lines,UseFloat:TCheckBox;
    CaptionText:TEdit;
    constructor Create(AOwner:TComponent); override;
    function Source(out Caret:Integer):string;
  end;
  TTableLinesDialog=class(TForm)
  private
    FModel:TTeXTable;
    FUpdating:Boolean;
    procedure Selected(Sender:TObject);
    procedure Changed(Sender:TObject);
    procedure DrawLines(Sender:TObject);
    procedure ToggleLine(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
  public
    Diagram:TPaintBox;
    Horizontal,Vertical:TListBox;
    HStyle,VStyle:TComboBox;
    constructor Create(AOwner:TComponent); override;
    procedure Load(Model:TTeXTable);
  end;
  TSplitCellDialog=class(TForm)
  private
    ApplyButton:TButton;
    procedure Changed(Sender:TObject);
  public
    Rows,Columns:TSpinEdit;
    Borders:TCheckBox;
    constructor Create(AOwner:TComponent); override;
  end;
  TFigureDialog=class(TForm)
  private
    FSource,FImage,FExtraOptions:string;
    FImageStart,FImageEnd:Integer;
    FStarred:Boolean;
    procedure Browse(Sender:TObject);
    procedure Accept(Sender:TObject);
  public
    FileName,ImageWidth,ImageHeight,CaptionText,LabelText:TEdit;
    CaptionPosition,Placement,WidthUnits,HeightUnits:TComboBox;
    UseFloat:TCheckBox;
    Directory:string;
    constructor Create(AOwner:TComponent); override;
    procedure Load(const Source:string; const SelectedImage:string=''; InsertImage:Boolean=False);
    function ImageSource:string;
    function Source:string;
  end;
  TPDFDialog=class(TForm)
  private
    procedure Browse(Sender:TObject);
    procedure Accept(Sender:TObject);
  public
    FileName,Options:TEdit;
    Pages:TComboBox;
    Directory:string;
    constructor Create(AOwner:TComponent); override;
    procedure Load(const Source:string);
    function Source:string;
  end;
  TFloatDialog=class(TForm)
  private
    FSource,FEnvironment:string;
    CaptionStart,CaptionEnd,LabelStart,LabelEnd,BodyStart,BodyEnd:Integer;
    CaptionLabel,CaptionPrefix:string;
    procedure Accept(Sender:TObject);
  public
    CaptionText:TMemo;
    LabelText:TEdit;
    CaptionPosition,Placement:TComboBox;
    RemoveCaption:TCheckBox;
    constructor Create(AOwner:TComponent); override;
    procedure Load(const Source:string);
    function Source:string;
  end;
implementation
function LabelAt(D:TForm; const Title:string; X,Y:Integer):TLabel;
begin Result:=TLabel.Create(D); Result.Parent:=D; Result.SetBounds(X,Y,180,22); Result.Caption:=Title; end;
function EditAt(D:TForm; X,Y,W:Integer):TEdit;
begin Result:=TEdit.Create(D); Result.Parent:=D; Result.SetBounds(X,Y,W,30); end;
function ComboAt(D:TForm; const Items:string; X,Y,W:Integer):TComboBox;
begin
  Result:=TComboBox.Create(D); Result.Parent:=D; Result.SetBounds(X,Y,W,30); Result.Style:=csDropDownList;
  Result.Items.Delimiter:=';'; Result.Items.StrictDelimiter:=True; Result.Items.DelimitedText:=Items; Result.ItemIndex:=0;
end;
procedure Buttons(D:TForm; const Title:string; Handler:TNotifyEvent=nil);
var B:TButton;
begin
  B:=TButton.Create(D); B.Parent:=D; B.SetBounds(D.ClientWidth-204,D.ClientHeight-44,92,30); B.Caption:=Title; B.Default:=True;
  if Assigned(Handler) then B.OnClick:=Handler else B.ModalResult:=mrOK;
  B:=TButton.Create(D); B.Parent:=D; B.SetBounds(D.ClientWidth-104,D.ClientHeight-44,92,30); B.Caption:='Cancel'; B.Cancel:=True; B.ModalResult:=mrCancel;
end;
constructor TPDFDialog.Create(AOwner:TComponent);
var B:TButton;
begin
  inherited CreateNew(AOwner); Caption:='Included PDF pages'; Position:=poMainFormCenter;
  BorderStyle:=bsDialog; ClientWidth:=560; ClientHeight:=282;
  LabelAt(Self,'PDF file',16,12); FileName:=EditAt(Self,16,36,430);
  B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(454,36,90,30); B.Caption:='Browse…'; B.OnClick:=@Browse;
  LabelAt(Self,'Pages',16,80); Pages:=ComboAt(Self,'1;-;1-3;3-1',16,104,528); Pages.Style:=csDropDown;
  LabelAt(Self,'A page, range, list (2,4-6), or - for all pages',16,138).Width:=528;
  LabelAt(Self,'Other pdfpages options',16,168); Options:=EditAt(Self,16,192,528);
  Buttons(Self,'Apply',@Accept); ApplyTheme(Self);
end;
procedure TPDFDialog.Load(const Source:string);
var Path,Selection,Value:string;
begin
  ReadPDFInclusion(Source,Path,Selection,Value); FileName.Text:=Path; Pages.Text:=Selection;
  Options.Text:=SetEnvironmentOption(Value,'pages','');
end;
function TPDFDialog.Source:string;
begin Result:=PDFInclusionSource(Trim(FileName.Text),Trim(Pages.Text),Trim(Options.Text)); end;
procedure TPDFDialog.Browse(Sender:TObject);
var D:TOpenDialog;
begin
  D:=TOpenDialog.Create(Self);
  try
    D.Filter:='PDF files|*.pdf|All files|*'; D.InitialDir:=Directory;
    if D.Execute then begin
      if Directory='' then FileName.Text:=D.FileName
      else FileName.Text:=StringReplace(ExtractRelativePath(IncludeTrailingPathDelimiter(Directory),D.FileName),'\','/',[rfReplaceAll]);
    end;
  finally D.Free; end;
end;
procedure TPDFDialog.Accept(Sender:TObject);
begin
  if Trim(FileName.Text)='' then begin FileName.SetFocus; Exit; end;
  ModalResult:=mrOK;
end;
function TTheoremSpec.Declaration:string;
begin
  Result:='\theoremstyle{'+Style+'}'+LineEnding+'\newtheorem'; if Starred then Result:=Result+'*';
  Result:=Result+'{'+Name+'}'; if not Starred and (Shared<>'') then Result:=Result+'['+Shared+']';
  Result:=Result+'{'+Title+'}'; if not Starred and (Shared='') and (Within<>'') then Result:=Result+'['+Within+']';
end;
constructor TEnvironmentDialog.Create(AOwner:TComponent);
begin
  inherited CreateNew(AOwner); Caption:='Insert environment'; Position:=poMainFormCenter;
  BorderStyle:=bsDialog; ClientWidth:=450; ClientHeight:=254;
  LabelAt(Self,'Environment name',16,16);
  EnvironmentName:=ComboAt(Self,'figure;table;figure*;table*;wrapfigure;wraptable;minipage;longtable;tcolorbox;lstlisting;tikzpicture;circuitikz;axis;tikzcd;xy;quote;quotation;verse;abstract;proof;itemize;enumerate;description',16,42,416);
  EnvironmentName.Style:=csDropDown; EnvironmentName.OnChange:=@Changed;
  LabelAt(Self,'Arguments: [options] or {required}',16,82); Arguments:=EditAt(Self,16,108,416);
  LabelAt(Self,'Package (if needed)',16,148); PackageName:=ComboAt(Self,';tikz;pgfplots;circuitikz;tikz-cd;xy;amsthm;wrapfig;longtable;tcolorbox;listings',16,174,416);
  PackageName.Style:=csDropDown; Changed(nil); Buttons(Self,'Insert',@Accept); ApplyTheme(Self);
end;
procedure TEnvironmentDialog.Changed(Sender:TObject);
begin
  PackageName.Text:=''; Arguments.Text:='';
  if EnvironmentName.Text='tikzpicture' then PackageName.Text:='tikz'
  else if EnvironmentName.Text='circuitikz' then PackageName.Text:='circuitikz'
  else if EnvironmentName.Text='tcolorbox' then PackageName.Text:='tcolorbox'
  else if EnvironmentName.Text='lstlisting' then begin PackageName.Text:='listings'; Arguments.Text:='[language=Pascal]'; end
  else if EnvironmentName.Text='longtable' then begin PackageName.Text:='longtable'; Arguments.Text:='{ll}'; end
  else if EnvironmentName.Text='minipage' then Arguments.Text:='[t]{0.45\linewidth}'
  else if (EnvironmentName.Text='wrapfigure') or (EnvironmentName.Text='wraptable') then begin PackageName.Text:='wrapfig'; Arguments.Text:='{r}{.35\textwidth}'; end
  else if EnvironmentName.Text='tikzcd' then PackageName.Text:='tikz-cd'
  else if EnvironmentName.Text='xy' then PackageName.Text:='xy'
  else if EnvironmentName.Text='axis' then PackageName.Text:='pgfplots'
  else if EnvironmentName.Text='proof' then PackageName.Text:='amsthm'
  else if (EnvironmentName.Text='figure') or (EnvironmentName.Text='table') or
          (EnvironmentName.Text='figure*') or (EnvironmentName.Text='table*') then Arguments.Text:='[htbp]';
end;
procedure TEnvironmentDialog.Accept(Sender:TObject);
var Ch:Char;
begin
  if Trim(EnvironmentName.Text)='' then Exit;
  for Ch in Trim(EnvironmentName.Text) do if not (Ch in ['a'..'z','A'..'Z','0'..'9','*','@',':','_','-']) then Exit;
  ModalResult:=mrOK;
end;
function TEnvironmentDialog.Source(out Caret:Integer):string;
var Environment:string;
begin
  Environment:=Trim(EnvironmentName.Text); Result:='\begin{'+Environment+'}'+Trim(Arguments.Text)+LineEnding;
  if Environment='axis' then Result:='\begin{tikzpicture}'+LineEnding+Result;
  if (Environment='itemize') or (Environment='enumerate') or (Environment='description') then Result:=Result+'\item ';
  Caret:=Length(Result);
  if Environment='tikzcd' then Result:=Result+'A \arrow[r] & B';
  if Environment='xy' then begin Result:=Result+'\xymatrix{'; Caret:=Length(Result); Result:=Result+'A \ar[r] & B}'; end;
  Result:=Result+LineEnding+'\end{'+Environment+'}';
  if Environment='axis' then Result:=Result+LineEnding+'\end{tikzpicture}';
end;
constructor TTheoremDialog.Create(AOwner:TComponent);
var B:TButton; I:Integer;
begin
  inherited CreateNew(AOwner); FSpecs:=TObjectList.Create(True);
  Caption:='Manage theorem environments'; Position:=poMainFormCenter; BorderStyle:=bsDialog; ClientWidth:=640; ClientHeight:=390;
  LabelAt(Self,'Environments',16,14); List:=TListBox.Create(Self); List.Parent:=Self; List.SetBounds(16,40,206,244); List.OnClick:=@SelectTheorem;
  for I:=0 to 1 do begin B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(16+I*108,298,98,30); B.Caption:='Add'; if I=1 then B.Caption:='Delete'; B.Tag:=I; B.OnClick:=@Action; end;
  LabelAt(Self,'Environment name',242,14); EnvironmentName:=EditAt(Self,242,40,380);
  LabelAt(Self,'Printed title',242,80); Title:=EditAt(Self,242,106,380);
  LabelAt(Self,'Theorem style',242,146); Style:=ComboAt(Self,'plain;definition;remark',242,172,380);
  LabelAt(Self,'Share counter with',242,212); Shared:=ComboAt(Self,'',242,238,180); Shared.Style:=csDropDown;
  LabelAt(Self,'Number within',440,212); Within:=ComboAt(Self,';section;subsection;chapter',440,238,182); Within.Style:=csDropDown;
  Starred:=TCheckBox.Create(Self); Starred.Parent:=Self; Starred.SetBounds(242,292,370,30); Starred.Caption:='Unnumbered (starred)';
  EnvironmentName.OnChange:=@Changed; Title.OnChange:=@Changed; Style.OnChange:=@Changed; Shared.OnChange:=@Changed; Within.OnChange:=@Changed; Starred.OnChange:=@Changed;
  Buttons(Self,'Apply',@Accept); ApplyTheme(Self);
end;
destructor TTheoremDialog.Destroy;
begin FSpecs.Free; inherited Destroy; end;
procedure TTheoremDialog.RefreshList(Index:Integer);
var I:Integer;
begin
  FUpdating:=True;
  try
    List.Items.Clear; Shared.Items.Clear; Shared.Items.Add('');
    for I:=0 to FSpecs.Count-1 do begin List.Items.Add(TTheoremSpec(FSpecs[I]).Name); Shared.Items.Add(TTheoremSpec(FSpecs[I]).Name); end;
    List.ItemIndex:=Min(Index,List.Items.Count-1);
  finally FUpdating:=False; end;
  SelectTheorem(nil);
end;
procedure TTheoremDialog.SelectTheorem(Sender:TObject);
var S:TTheoremSpec; I:Integer;
begin
  if FUpdating then Exit; I:=List.ItemIndex; FUpdating:=True;
  try
    EnvironmentName.Enabled:=I>=0; Title.Enabled:=I>=0; Style.Enabled:=I>=0; Starred.Enabled:=I>=0;
    Shared.Enabled:=I>=0; Within.Enabled:=I>=0;
    if I<0 then begin EnvironmentName.Text:=''; Title.Text:=''; Exit; end;
    S:=TTheoremSpec(FSpecs[I]); EnvironmentName.Text:=S.Name; Title.Text:=S.Title;
    if Style.Items.IndexOf(S.Style)<0 then Style.Items.Add(S.Style); Style.ItemIndex:=Style.Items.IndexOf(S.Style);
    Shared.Text:=S.Shared; Within.Text:=S.Within; Starred.Checked:=S.Starred;
    Shared.Enabled:=not S.Starred; Within.Enabled:=not S.Starred;
  finally FUpdating:=False; end;
end;
procedure TTheoremDialog.Changed(Sender:TObject);
var S:TTheoremSpec;
begin
  if FUpdating or (List.ItemIndex<0) then Exit; S:=TTheoremSpec(FSpecs[List.ItemIndex]);
  S.Name:=Trim(EnvironmentName.Text); S.Title:=Title.Text; S.Style:=Style.Text;
  S.Shared:=Trim(Shared.Text); S.Within:=Trim(Within.Text); S.Starred:=Starred.Checked;
  List.Items[List.ItemIndex]:=S.Name; Shared.Enabled:=not S.Starred; Within.Enabled:=not S.Starred;
end;
procedure TTheoremDialog.Action(Sender:TObject);
var I:Integer; S:TTheoremSpec;
begin
  I:=List.ItemIndex;
  if TComponent(Sender).Tag=0 then begin S:=TTheoremSpec.Create; S.Name:='theorem'+IntToStr(FSpecs.Count+1); S.Title:='Theorem'; S.Style:='plain'; I:=FSpecs.Add(S); end
  else if I>=0 then FSpecs.Delete(I);
  RefreshList(I);
end;
procedure TTheoremDialog.Accept(Sender:TObject);
var I,J:Integer; S:TTheoremSpec; C:Char;
begin
  for I:=0 to FSpecs.Count-1 do begin
    S:=TTheoremSpec(FSpecs[I]);
    if (S.Name='') or (S.Title='') then begin MessageDlg('Theorem settings','Enter an environment name and printed title.',mtInformation,[mbOK],0); Exit; end;
    for C in S.Name do if not (C in ['a'..'z','A'..'Z','0'..'9','@','*',':','-']) then begin MessageDlg('Theorem settings','The environment name contains an invalid character.',mtInformation,[mbOK],0); Exit; end;
    for J:=0 to I-1 do if TTheoremSpec(FSpecs[J]).Name=S.Name then begin MessageDlg('Theorem settings','Environment names must be unique.',mtInformation,[mbOK],0); Exit; end;
    if not S.Starred and (S.Shared<>'') and (S.Within<>'') then begin MessageDlg('Theorem settings','Choose a shared counter or a parent counter.',mtInformation,[mbOK],0); Exit; end;
  end;
  ModalResult:=mrOK;
end;
procedure TTheoremDialog.Load(const Preamble:string);
var P:Integer; Cmd,CurrentStyle:string; S:TTheoremSpec;
begin
  FSource:=Preamble; FSpecs.Clear; P:=1; CurrentStyle:='plain';
  while P<=Length(Preamble) do begin
    if Preamble[P]='%' then begin while (P<=Length(Preamble)) and (Preamble[P]<>#10) do Inc(P); Continue; end;
    if Preamble[P]<>'\' then begin Inc(P); Continue; end;
    Cmd:=ReadTeXCommand(Preamble,P);
    if Cmd='theoremstyle' then CurrentStyle:=ReadTeXGroup(Preamble,P,'{','}')
    else if Cmd='newtheorem' then begin
      S:=TTheoremSpec.Create; S.Style:=CurrentStyle; S.Starred:=(P<=Length(Preamble)) and (Preamble[P]='*'); if S.Starred then Inc(P);
      S.Name:=ReadTeXGroup(Preamble,P,'{','}'); SkipTeXSpace(Preamble,P);
      if (P<=Length(Preamble)) and (Preamble[P]='[') then S.Shared:=ReadTeXGroup(Preamble,P,'[',']');
      S.Title:=ReadTeXGroup(Preamble,P,'{','}'); SkipTeXSpace(Preamble,P);
      if (P<=Length(Preamble)) and (Preamble[P]='[') then S.Within:=ReadTeXGroup(Preamble,P,'[',']');
      S.OriginalName:=S.Name; S.OriginalDeclaration:=S.Declaration;
      FSpecs.Add(S);
    end;
  end;
  RefreshList(0);
end;
function TTheoremDialog.Preamble:string;
var P,A,I:Integer; Cmd,EnvName,CurrentStyle,Replacement:string; Used:array of Boolean; S:TTheoremSpec; HasPackage:Boolean;
begin
  Result:=FSource; P:=1; CurrentStyle:='plain'; SetLength(Used,FSpecs.Count); HasPackage:=Pos('amsthm',Result)>0;
  while P<=Length(Result) do begin
    if Result[P]='%' then begin while (P<=Length(Result)) and (Result[P]<>#10) do Inc(P); Continue; end;
    if Result[P]<>'\' then begin Inc(P); Continue; end;
    A:=P; Cmd:=ReadTeXCommand(Result,P);
    if not HasPackage and (FSpecs.Count>0) and ((Cmd='theoremstyle') or (Cmd='newtheorem')) then begin
      { Basic LaTeX declarations may predate amsthm. Load the package before
        any style command introduced while editing those declarations. }
      Replacement:='\usepackage{amsthm}'+LineEnding; Insert(Replacement,Result,A);
      Inc(A,Length(Replacement)); Inc(P,Length(Replacement)); HasPackage:=True;
    end;
    if Cmd='theoremstyle' then CurrentStyle:=ReadTeXGroup(Result,P,'{','}')
    else if Cmd='newtheorem' then begin
      if (P<=Length(Result)) and (Result[P]='*') then Inc(P);
      EnvName:=ReadTeXGroup(Result,P,'{','}'); SkipTeXSpace(Result,P);
      if (P<=Length(Result)) and (Result[P]='[') then ReadTeXGroup(Result,P,'[',']');
      ReadTeXGroup(Result,P,'{','}'); I:=P; SkipTeXSpace(Result,I);
      if (I<=Length(Result)) and (Result[I]='[') then begin ReadTeXGroup(Result,I,'[',']'); P:=I; end;
      Replacement:='';
      for I:=0 to FSpecs.Count-1 do if TTheoremSpec(FSpecs[I]).OriginalName=EnvName then begin
        S:=TTheoremSpec(FSpecs[I]);
        if S.Declaration=S.OriginalDeclaration then Replacement:=Copy(Result,A,P-A)
        else Replacement:=S.Declaration+LineEnding+'\theoremstyle{'+CurrentStyle+'}'; Used[I]:=True; Break;
      end;
      Delete(Result,A,P-A); Insert(Replacement,Result,A); P:=A+Length(Replacement);
    end;
  end;
  Replacement:=''; for I:=0 to FSpecs.Count-1 do if not Used[I] then Replacement:=Replacement+TTheoremSpec(FSpecs[I]).Declaration+LineEnding;
  if (FSpecs.Count>0) and not HasPackage then Replacement:='\usepackage{amsthm}'+LineEnding+Replacement;
  P:=Pos('\begin{document}',Result); if P=0 then P:=Length(Result)+1; Insert(Replacement,Result,P);
end;
constructor TTableDialog.Create(AOwner:TComponent);
begin
  inherited CreateNew(AOwner); Caption:='Insert table'; Position:=poMainFormCenter; BorderStyle:=bsDialog; ClientWidth:=500; ClientHeight:=470;
  Grid:=TDrawGrid.Create(Self); Grid.Parent:=Self; Grid.SetBounds(16,16,468,168); Grid.FixedCols:=0; Grid.FixedRows:=0; Grid.ColCount:=10; Grid.RowCount:=6;
  Grid.DefaultColWidth:=45; Grid.DefaultRowHeight:=26; Grid.ScrollBars:=ssNone; Grid.OnDrawCell:=@DrawCell; Grid.OnSelectCell:=@SelectCell;
  LabelAt(Self,'Rows',16,202); Rows:=TSpinEdit.Create(Self); Rows.Parent:=Self; Rows.SetBounds(76,196,80,30); Rows.MinValue:=1; Rows.MaxValue:=100; Rows.Value:=3; Rows.OnChange:=@SizeChanged;
  LabelAt(Self,'Columns',178,202); Columns:=TSpinEdit.Create(Self); Columns.Parent:=Self; Columns.SetBounds(260,196,80,30); Columns.MinValue:=1; Columns.MaxValue:=100; Columns.Value:=3; Columns.OnChange:=@SizeChanged;
  Alignment:=ComboAt(Self,'Left;Center;Right',354,196,130);
  Lines:=TCheckBox.Create(Self); Lines.Parent:=Self; Lines.SetBounds(16,242,208,26); Lines.Caption:='Grid lines'; Lines.Checked:=True;
  UseFloat:=TCheckBox.Create(Self); UseFloat.Parent:=Self; UseFloat.SetBounds(252,242,232,26); UseFloat.Caption:='Table float'; UseFloat.Checked:=True;
  LabelAt(Self,'Caption (optional)',16,284); CaptionText:=EditAt(Self,16,310,468);
  LabelAt(Self,'Caption position',16,356); CaptionPosition:=ComboAt(Self,'Above;Below',16,380,208);
  LabelAt(Self,'Float placement',252,356); Placement:=ComboAt(Self,'htbp;h;t;b;p;!htbp',252,380,232); Placement.Style:=csDropDown;
  Buttons(Self,'Insert'); ApplyTheme(Self);
end;
procedure TTableDialog.DrawCell(Sender:TObject; Col,Row:Integer; R:TRect; State:TGridDrawState);
begin Grid.Canvas.Brush.Color:=PaperColor; if (Col<Columns.Value) and (Row<Rows.Value) then Grid.Canvas.Brush.Color:=$AC7540; Grid.Canvas.FillRect(R); Grid.Canvas.Pen.Color:=InkColor; Grid.Canvas.Rectangle(R); end;
procedure TTableDialog.SelectCell(Sender:TObject; Col,Row:Integer; var CanSelect:Boolean);
begin Columns.Value:=Col+1; Rows.Value:=Row+1; Grid.Invalidate; end;
procedure TTableDialog.SizeChanged(Sender:TObject);
begin Grid.Invalidate; end;
function TTableDialog.Source(out Caret:Integer):string;
var T:TTeXTable; Prefix,Suffix,CaptionCode:string;
begin
  T:=TTeXTable.Create;
  try T.Initialize(Rows.Value,Columns.Value,Copy('lcr',Alignment.ItemIndex+1,1),Lines.Checked); Result:=T.Source(Caret,0,0); finally T.Free; end;
  if not UseFloat.Checked then Exit;
  Prefix:='\begin{table}['+Placement.Text+']'+LineEnding+'\centering'+LineEnding; Suffix:=LineEnding+'\end{table}';
  if CaptionText.Text<>'' then begin
    CaptionCode:='\caption{'+CaptionText.Text+'}'+LineEnding;
    if CaptionPosition.ItemIndex=0 then Prefix:=Prefix+CaptionCode else Suffix:=LineEnding+CaptionCode+'\end{table}';
  end;
  Inc(Caret,Length(Prefix)); Result:=Prefix+Result+Suffix;
end;
constructor TTableLinesDialog.Create(AOwner:TComponent);
begin
  inherited CreateNew(AOwner); Caption:='Table lines'; Position:=poMainFormCenter; BorderStyle:=bsDialog; ClientWidth:=720; ClientHeight:=380;
  LabelAt(Self,'Click a boundary to cycle its line style',16,16).Width:=310;
  Diagram:=TPaintBox.Create(Self); Diagram.Parent:=Self; Diagram.SetBounds(16,48,310,270); Diagram.OnPaint:=@DrawLines; Diagram.OnMouseDown:=@ToggleLine;
  Diagram.Hint:='Click a horizontal line for single, double or booktabs rules; click a vertical line for single or double.'; Diagram.ShowHint:=True;
  LabelAt(Self,'Horizontal boundaries',344,16); LabelAt(Self,'Vertical boundaries',528,16);
  Horizontal:=TListBox.Create(Self); Horizontal.Parent:=Self; Horizontal.SetBounds(344,44,168,234); Horizontal.OnClick:=@Selected;
  Vertical:=TListBox.Create(Self); Vertical.Parent:=Self; Vertical.SetBounds(528,44,176,234); Vertical.OnClick:=@Selected;
  HStyle:=ComboAt(Self,'None;Single;Double;Top rule;Middle rule;Bottom rule;Partial rule',344,294,168);
  VStyle:=ComboAt(Self,'None;Single;Double',528,294,176);
  HStyle.OnChange:=@Changed; VStyle.OnChange:=@Changed; Buttons(Self,'Apply'); ApplyTheme(Self);
end;
procedure TTableLinesDialog.Load(Model:TTeXTable);
var I:Integer; S:string;
begin
  FModel:=Model; Horizontal.Items.Clear; Vertical.Items.Clear;
  for I:=0 to Model.Rows.Count do begin S:='After row '+IntToStr(I); if I=0 then S:='Top'; if I=Model.Rows.Count then S:='Bottom'; Horizontal.Items.Add(S); end;
  for I:=0 to Model.Columns.Count do begin S:='After column '+IntToStr(I); if I=0 then S:='Left'; if I=Model.Columns.Count then S:='Right'; Vertical.Items.Add(S); end;
  Horizontal.ItemIndex:=0; Vertical.ItemIndex:=0; Selected(nil);
end;
constructor TSplitCellDialog.Create(AOwner:TComponent);
var L:TLabel; B:TButton;
begin
  inherited CreateNew(AOwner); Name:='SplitCellDialog'; Caption:='Split cell'; Position:=poOwnerFormCenter;
  BorderStyle:=bsDialog; ClientWidth:=360; ClientHeight:=220;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='Columns'; L.SetBounds(20,22,120,24);
  Columns:=TSpinEdit.Create(Self); Columns.Parent:=Self; Columns.SetBounds(160,18,176,30);
  Columns.MinValue:=1; Columns.MaxValue:=20; Columns.Value:=2; Columns.OnChange:=@Changed;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='Rows'; L.SetBounds(20,66,120,24);
  Rows:=TSpinEdit.Create(Self); Rows.Parent:=Self; Rows.SetBounds(160,62,176,30);
  Rows.MinValue:=1; Rows.MaxValue:=20; Rows.Value:=1; Rows.OnChange:=@Changed;
  Borders:=TCheckBox.Create(Self); Borders.Parent:=Self; Borders.Caption:='Add borders between new cells';
  Borders.SetBounds(20,108,316,28); Borders.Checked:=True;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Caption:='The contents remain in the first cell.'; L.SetBounds(20,142,320,24);
  ApplyButton:=TButton.Create(Self); ApplyButton.Parent:=Self; ApplyButton.Caption:='Split';
  ApplyButton.SetBounds(144,176,96,30); ApplyButton.ModalResult:=mrOK; ApplyButton.Default:=True;
  B:=TButton.Create(Self); B.Parent:=Self; B.Caption:='Cancel'; B.SetBounds(248,176,96,30);
  B.ModalResult:=mrCancel; B.Cancel:=True; ApplyTheme(Self);
end;
procedure TSplitCellDialog.Changed(Sender:TObject);
begin if ApplyButton<>nil then ApplyButton.Enabled:=Rows.Value*Columns.Value>1; end;
procedure TTableLinesDialog.Selected(Sender:TObject);
begin
  if FModel=nil then Exit; FUpdating:=True;
  try
    if Horizontal.ItemIndex>=0 then HStyle.ItemIndex:=FModel.HorizontalStyle(Horizontal.ItemIndex);
    if Vertical.ItemIndex>=0 then VStyle.ItemIndex:=EnsureRange(FModel.Vertical[Vertical.ItemIndex],0,2);
  finally FUpdating:=False; end;
  Diagram.Invalidate;
end;
procedure TTableLinesDialog.Changed(Sender:TObject);
begin
  if FUpdating or (FModel=nil) then Exit;
  if (Sender=HStyle) and (Horizontal.ItemIndex>=0) then FModel.SetHorizontalStyle(Horizontal.ItemIndex,HStyle.ItemIndex);
  if (Sender=VStyle) and (Vertical.ItemIndex>=0) then FModel.Vertical[Vertical.ItemIndex]:=VStyle.ItemIndex;
  Diagram.Invalidate;
end;
procedure TTableLinesDialog.DrawLines(Sender:TObject);
var I,J,X,Y:Integer; C:TCanvas;
begin
  C:=Diagram.Canvas; C.Brush.Color:=PaperColor; C.FillRect(Diagram.ClientRect); if FModel=nil then Exit;
  C.Pen.Width:=1;
  for I:=0 to High(FModel.Horizontal) do begin
    Y:=12+Round(I*(Diagram.Height-24)/Max(1,FModel.Rows.Count));
    C.Pen.Style:=psSolid; C.Pen.Color:=InkColor; C.Pen.Width:=1;
    if FModel.HorizontalStyle(I) in [3,5] then C.Pen.Width:=3;
    if FModel.HorizontalStyle(I)=0 then begin C.Pen.Color:=clGray; C.Pen.Style:=psDot; end;
    C.Line(12,Y,Diagram.Width-12,Y);
    if FModel.Horizontal[I]>1 then C.Line(12,Y+3,Diagram.Width-12,Y+3);
  end;
  for J:=0 to High(FModel.Vertical) do begin
    X:=12+Round(J*(Diagram.Width-24)/Max(1,FModel.Columns.Count));
    C.Pen.Style:=psSolid; C.Pen.Color:=InkColor; C.Pen.Width:=1;
    if FModel.Vertical[J]=0 then begin C.Pen.Color:=clGray; C.Pen.Style:=psDot; end;
    C.Line(X,12,X,Diagram.Height-12);
    if FModel.Vertical[J]>1 then C.Line(X+3,12,X+3,Diagram.Height-12);
  end;
  C.Pen.Style:=psSolid;
end;
procedure TTableLinesDialog.ToggleLine(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
var R,C,DH,DV:Integer;
begin
  if (Button<>mbLeft) or (FModel=nil) then Exit;
  if (X<6) or (X>Diagram.Width-6) or (Y<6) or (Y>Diagram.Height-6) then Exit;
  R:=EnsureRange(Round((Y-12)*FModel.Rows.Count/(Diagram.Height-24)),0,FModel.Rows.Count);
  C:=EnsureRange(Round((X-12)*FModel.Columns.Count/(Diagram.Width-24)),0,FModel.Columns.Count);
  DH:=Abs(Y-12-Round(R*(Diagram.Height-24)/Max(1,FModel.Rows.Count)));
  DV:=Abs(X-12-Round(C*(Diagram.Width-24)/Max(1,FModel.Columns.Count)));
  if Min(DH,DV)>8 then Exit;
  if DH<DV then begin FModel.SetHorizontalStyle(R,(FModel.HorizontalStyle(R)+1) mod 7); Horizontal.ItemIndex:=R; end
  else begin FModel.Vertical[C]:=(FModel.Vertical[C]+1) mod 3; Vertical.ItemIndex:=C; end;
  Selected(nil);
end;
constructor TFigureDialog.Create(AOwner:TComponent);
var B:TButton;
begin
  inherited CreateNew(AOwner); Caption:='Insert figure'; Position:=poMainFormCenter; BorderStyle:=bsDialog; ClientWidth:=520; ClientHeight:=456;
  LabelAt(Self,'Image file (PNG, JPEG, PDF)',16,16); FileName:=EditAt(Self,16,42,382);
  B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(408,42,96,30); B.Caption:='Browse…'; B.OnClick:=@Browse;
  LabelAt(Self,'Width (blank = automatic)',16,88); ImageWidth:=EditAt(Self,16,114,76); ImageWidth.Text:='0.6';
  WidthUnits:=ComboAt(Self,'\linewidth;\textwidth;\columnwidth;\textheight;\paperwidth;\paperheight;pt;bp;mm;cm;in;em;ex',98,114,150);
  LabelAt(Self,'Height (blank = automatic)',272,88); ImageHeight:=EditAt(Self,272,114,76);
  HeightUnits:=ComboAt(Self,WidthUnits.Items.DelimitedText,354,114,150);
  UseFloat:=TCheckBox.Create(Self); UseFloat.Parent:=Self; UseFloat.SetBounds(16,164,232,28); UseFloat.Caption:='Figure float'; UseFloat.Checked:=True;
  LabelAt(Self,'Caption (optional)',16,208); CaptionText:=EditAt(Self,16,234,488);
  LabelAt(Self,'Caption position',16,282); CaptionPosition:=ComboAt(Self,'Above;Below',16,306,232); CaptionPosition.ItemIndex:=1;
  LabelAt(Self,'Float placement',272,282); Placement:=ComboAt(Self,'htbp;h;t;b;p;!htbp',272,306,232); Placement.Style:=csDropDown;
  LabelAt(Self,'Label (optional)',16,348); LabelText:=EditAt(Self,16,372,488);
  Buttons(Self,'Apply',@Accept); ApplyTheme(Self);
end;
procedure TFigureDialog.Accept(Sender:TObject);
var N:Double; Code:Integer; E:TEdit; C:Char;
begin
  if Trim(FileName.Text)='' then begin MessageDlg('Figure','Choose an image file.',mtInformation,[mbOK],0); Exit; end;
  for E in [ImageWidth,ImageHeight] do if Trim(E.Text)<>'' then begin
    Val(Trim(E.Text),N,Code);
    if (Code<>0) or (N<=0) then begin MessageDlg('Figure size','Enter a positive number and choose its unit, or leave the size blank.',mtInformation,[mbOK],0); E.SetFocus; Exit; end;
  end;
  for C in Placement.Text do if not (C in ['h','t','b','p','!','H']) then begin MessageDlg('Float placement','Use h, t, b, p or ! (H requires the float package).',mtInformation,[mbOK],0); Exit; end;
  for C in LabelText.Text do if C in [' ',#9,#10,#13,'{','}','\'] then begin MessageDlg('Figure label','Use a label without spaces, braces or backslashes.',mtInformation,[mbOK],0); Exit; end;
  ModalResult:=mrOK;
end;
procedure TFigureDialog.Browse(Sender:TObject);
var D:TOpenDialog;
begin
  D:=TOpenDialog.Create(Self);
  try
    D.Filter:='Images|*.png;*.jpg;*.jpeg;*.pdf;*.bmp|All files|*'; D.InitialDir:=Directory;
    if D.Execute then begin if Directory<>'' then FileName.Text:=StringReplace(ExtractRelativePath(IncludeTrailingPathDelimiter(Directory),D.FileName),'\','/',[rfReplaceAll]) else FileName.Text:=D.FileName; end;
  finally D.Free; end;
end;
procedure TFigureDialog.Load(const Source:string; const SelectedImage:string; InsertImage:Boolean);
var P,I:Integer; Options:TStringList; Root:TMathNode; D:TFloatDialog;
  procedure Find(N:TMathNode);
  var J:Integer;
  begin
    if not InsertImage and (N.Kind=mkTextCommand) and (Pos('\includegraphics',N.Text)=1) and
       ((FImage='') or (N.TeX=SelectedImage)) then begin
      FImage:=N.TeX; FImageStart:=MathSourceOffset(N); FImageEnd:=FImageStart+Length(FImage);
    end;
    for J:=0 to N.Children.Count-1 do Find(TMathNode(N.Children[J]));
  end;
  procedure Dimension(const Value:string; Edit:TEdit; Units:TComboBox);
  var K:Integer; S,U:string;
  begin
    S:=Trim(Value); K:=1; while (K<=Length(S)) and (S[K] in ['0'..'9','.','+','-']) do Inc(K);
    Edit.Text:=Copy(S,1,K-1); U:=Trim(Copy(S,K,MaxInt));
    if (S<>'') and (Edit.Text='') then Edit.Text:='1';
    if U<>'' then begin if Units.Items.IndexOf(U)<0 then Units.Items.Add(U); Units.ItemIndex:=Units.Items.IndexOf(U); end;
  end;
begin
  FSource:=Source; FImage:=''; FExtraOptions:=''; CaptionText.Text:=''; LabelText.Text:='';
  Root:=ParseParagraph(Source,nil); try Find(Root); finally Root.Free; end;
  UseFloat.Checked:=Pos('\begin{figure',Source)=1; UseFloat.Enabled:=not UseFloat.Checked;
  if UseFloat.Checked then begin
    D:=TFloatDialog.Create(Self);
    try D.Load(Source); CaptionText.Text:=TrimRight(D.CaptionText.Text); LabelText.Text:=D.LabelText.Text;
      CaptionPosition.ItemIndex:=D.CaptionPosition.ItemIndex; Placement.Text:=D.Placement.Text;
    finally D.Free; end;
    if FImage='' then begin
      { Insert into the existing float, before its caption or closing command. }
      FImageStart:=Pos('\caption',Source)-1;
      if FImageStart<0 then FImageStart:=Pos('\end{figure',Source)-1;
      FImageStart:=Max(0,FImageStart); FImageEnd:=FImageStart;
    end;
  end;
  if FImage='' then Exit;
  P:=1; ReadTeXCommand(FImage,P); FStarred:=(P<=Length(FImage)) and (FImage[P]='*'); if FStarred then Inc(P); Options:=TStringList.Create;
  try
    Options.Delimiter:=','; Options.StrictDelimiter:=True; Options.DelimitedText:=ReadTeXGroup(FImage,P,'[',']');
    for I:=0 to Options.Count-1 do Options[I]:=Trim(Options[I]);
    Dimension(Options.Values['width'],ImageWidth,WidthUnits); Dimension(Options.Values['height'],ImageHeight,HeightUnits);
    FileName.Text:=ReadTeXGroup(FImage,P,'{','}');
    for I:=Options.Count-1 downto 0 do if (Trim(Options.Names[I])='width') or (Trim(Options.Names[I])='height') then Options.Delete(I);
    FExtraOptions:=Options.DelimitedText;
  finally Options.Free; end;
end;
function TFigureDialog.ImageSource:string;
var Options:string;
begin
  Options:=FExtraOptions; if Trim(ImageWidth.Text)<>'' then begin if Options<>'' then Options:=Options+','; Options:=Options+'width='+Trim(ImageWidth.Text)+WidthUnits.Text; end;
  if Trim(ImageHeight.Text)<>'' then begin if Options<>'' then Options:=Options+','; Options:=Options+'height='+Trim(ImageHeight.Text)+HeightUnits.Text; end;
  if Options<>'' then Options:='['+Options+']'; Result:='\includegraphics'; if FStarred then Result:=Result+'*'; Result:=Result+Options+'{'+FileName.Text+'}';
end;
function TFigureDialog.Source:string;
var Prefix,Suffix,C:string; D:TFloatDialog;
begin
  Result:=ImageSource; if not UseFloat.Checked then Exit;
  if Pos('\begin{figure',FSource)=1 then begin
    if FImage='' then Result:=LineEnding+Result+LineEnding;
    Result:=Copy(FSource,1,FImageStart)+Result+Copy(FSource,FImageEnd+1,MaxInt);
    D:=TFloatDialog.Create(Self);
    try D.Load(Result); D.CaptionText.Text:=CaptionText.Text; D.RemoveCaption.Checked:=CaptionText.Text='';
      D.LabelText.Text:=LabelText.Text; D.CaptionPosition.ItemIndex:=CaptionPosition.ItemIndex; D.Placement.Text:=Placement.Text;
      Result:=D.Source;
    finally D.Free; end;
    Exit;
  end;
  Prefix:='\begin{figure}['+Placement.Text+']'+LineEnding+'\centering'+LineEnding; Suffix:=LineEnding+'\end{figure}';
  C:=''; if CaptionText.Text<>'' then C:='\caption{'+CaptionText.Text+'}'+LineEnding;
  if Trim(LabelText.Text)<>'' then C:=C+'\label{'+Trim(LabelText.Text)+'}'+LineEnding;
  if CaptionPosition.ItemIndex=0 then Prefix:=Prefix+C else Suffix:=LineEnding+C+'\end{figure}';
  Result:=Prefix+Result+Suffix;
end;
constructor TFloatDialog.Create(AOwner:TComponent);
begin
  inherited CreateNew(AOwner); Caption:='Caption, label and float placement'; Position:=poMainFormCenter; BorderStyle:=bsDialog; ClientWidth:=540; ClientHeight:=422;
  LabelAt(Self,'Caption (edit LaTeX or edit it directly in the document)',16,16);
  CaptionText:=TMemo.Create(Self); CaptionText.Parent:=Self; CaptionText.SetBounds(16,44,508,134); CaptionText.ScrollBars:=ssVertical;
  RemoveCaption:=TCheckBox.Create(Self); RemoveCaption.Parent:=Self; RemoveCaption.SetBounds(16,194,508,28); RemoveCaption.Caption:='Remove caption';
  LabelAt(Self,'Caption position',16,238); CaptionPosition:=ComboAt(Self,'Above;Below',16,266,240);
  LabelAt(Self,'Float placement',280,238); Placement:=ComboAt(Self,'htbp;h;t;b;p;!htbp',280,266,244); Placement.Style:=csDropDown;
  LabelAt(Self,'Label (optional)',16,310); LabelText:=EditAt(Self,16,334,508);
  Buttons(Self,'Apply',@Accept); ApplyTheme(Self);
end;
procedure TFloatDialog.Accept(Sender:TObject);
var C:Char;
begin
  for C in Placement.Text do if not (C in ['h','t','b','p','!','H']) then begin MessageDlg('Float placement','Use h, t, b, p or ! (H requires the float package).',mtInformation,[mbOK],0); Exit; end;
  for C in LabelText.Text do if C in [' ',#9,#10,#13,'{','}','\'] then begin MessageDlg('Float label','Use a label without spaces, braces or backslashes.',mtInformation,[mbOK],0); Exit; end;
  ModalResult:=mrOK;
end;
procedure TFloatDialog.Load(const Source:string);
var P,I:Integer; Root:TMathNode;
  procedure Visit(N:TMathNode);
  var J:Integer;
  begin
    if (N.Kind=mkGroup) and (Pos('\caption',N.Prefix)=1) and (CaptionStart<0) then begin
      CaptionStart:=MathSourceOffset(N)-Length(N.Prefix); CaptionEnd:=CaptionStart+Length(N.TeX);
      CaptionPrefix:=N.Prefix;
      CaptionText.Text:=Copy(Source,MathSourceOffset(N)+1,Length(N.TeX)-Length(N.Prefix)-Length(N.Suffix));
      Exit;
    end;
    if ((N.Kind=mkRaw) and (Pos('\label{',N.Text)=1) or
        (N.Kind=mkCommand) and (N.Text='\label')) and (LabelStart<0) then begin
      LabelStart:=MathSourceOffset(N); LabelEnd:=LabelStart+Length(N.TeX); CaptionLabel:=N.TeX;
    end;
    if (N.Kind=mkTable) or (N.Kind=mkFormula) then Exit;
    for J:=0 to N.Children.Count-1 do Visit(TMathNode(N.Children[J]));
  end;
begin
  FSource:=Source; CaptionText.Text:=''; LabelText.Text:=''; RemoveCaption.Checked:=False; Placement.Text:='';
  P:=1; ReadTeXCommand(Source,P); FEnvironment:=ReadTeXGroup(Source,P,'{','}');
  BodyStart:=P-1; I:=P; SkipTeXSpace(Source,I); if (I<=Length(Source)) and (Source[I]='[') then begin Placement.Text:=ReadTeXGroup(Source,I,'[',']'); BodyStart:=I-1; end;
  BodyEnd:=EnvironmentEnd(Source,1,FEnvironment)-1; CaptionStart:=-1; CaptionEnd:=-1; LabelStart:=-1; LabelEnd:=-1; CaptionLabel:=''; CaptionPrefix:='\caption{'; Root:=ParseParagraph(Source,nil);
  try Visit(Root); finally Root.Free; end;
  P:=1; ReadTeXCommand(CaptionLabel,P); LabelText.Text:=ReadTeXGroup(CaptionLabel,P,'{','}');
  CaptionPosition.ItemIndex:=1;
  if (CaptionStart>=0) and (Pos('\begin{tabular',Copy(Source,CaptionEnd+1,MaxInt))>0) then CaptionPosition.ItemIndex:=0;
  if (CaptionStart>=0) and (Pos('\includegraphics',Copy(Source,CaptionEnd+1,MaxInt))>0) then CaptionPosition.ItemIndex:=0;
end;
function TFloatDialog.Source:string;
var Body,C,Prefix:string;
begin
  Body:=Copy(FSource,BodyStart+1,BodyEnd-BodyStart);
  if LabelStart>CaptionStart then begin
    if LabelStart>=0 then Delete(Body,LabelStart-BodyStart+1,LabelEnd-LabelStart);
    if CaptionStart>=0 then Delete(Body,CaptionStart-BodyStart+1,CaptionEnd-CaptionStart);
  end else begin
    if CaptionStart>=0 then Delete(Body,CaptionStart-BodyStart+1,CaptionEnd-CaptionStart);
    if LabelStart>=0 then Delete(Body,LabelStart-BodyStart+1,LabelEnd-LabelStart);
  end;
  C:=''; if not RemoveCaption.Checked then begin
    C:=CaptionPrefix+TrimRight(CaptionText.Text)+'}'+LineEnding;
  end;
  if not RemoveCaption.Checked and (Trim(LabelText.Text)<>'') then C:=C+'\label{'+Trim(LabelText.Text)+'}'+LineEnding;
  Prefix:='\begin{'+FEnvironment+'}'; if Placement.Text<>'' then Prefix:=Prefix+'['+Placement.Text+']'; Prefix:=Prefix+LineEnding;
  if CaptionPosition.ItemIndex=0 then Body:=C+Trim(Body) else Body:=Trim(Body)+LineEnding+C;
  Result:=Prefix+Body+LineEnding+'\end{'+FEnvironment+'}';
end;
end.
