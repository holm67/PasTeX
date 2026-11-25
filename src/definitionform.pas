unit DefinitionForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, Grids, ExtCtrls, SynEdit,
  SynEditWrappedView, CommandDefinition, UITheme;
type TDefinitionForm=class(TForm)
  private
    FSource:string;
    FArguments:TDefinitionArguments;
    FUpdating:Boolean;
    procedure Refresh(Index:Integer);
    procedure Selected(Sender:TObject; Col,Row:Integer; var CanSelect:Boolean);
    procedure Changed(Sender:TObject);
    procedure BodyChanged(Sender:TObject);
    procedure Action(Sender:TObject);
    procedure Accept(Sender:TObject);
  public
    CommandName,DefaultValue:TEdit;
    ArgumentList:TStringGrid;
    ArgumentType:TComboBox;
    BodyEditor:TSynEdit;
    constructor Create(AOwner:TComponent); override;
    procedure LoadSource(const Code:string);
    function Source:string;
  end;
implementation
uses Dialogs, Math, Types, Graphics, SynHighlighterTeX, SourceFonts, SourceStyle;
constructor TDefinitionForm.Create(AOwner:TComponent);
var L:TLabel; B:TButton; I:Integer; Header,Arguments,Body,Footer,Row,Buttons:TPanel; Split:TSplitter;
const Actions:array[0..4] of string=('Add required','Add optional','Delete','Move up','Move down');
begin
  inherited CreateNew(AOwner); Caption:='Command definition'; Position:=poMainFormCenter;
  ClientWidth:=720; ClientHeight:=620; Constraints.MinWidth:=560; Constraints.MinHeight:=560;
  Footer:=TPanel.Create(Self); Footer.Parent:=Self; Footer.Align:=alBottom; Footer.Height:=74; Footer.BevelOuter:=bvNone;
  Row:=TPanel.Create(Self); Row.Parent:=Footer; Row.Align:=alBottom; Row.Height:=42; Row.BevelOuter:=bvNone;
  B:=TButton.Create(Self); B.Parent:=Row; B.Align:=alRight; B.Width:=96; B.BorderSpacing.Right:=12; B.BorderSpacing.Bottom:=8;
  B.Caption:='Cancel'; B.Cancel:=True; B.ModalResult:=mrCancel;
  B:=TButton.Create(Self); B.Parent:=Row; B.Align:=alRight; B.Width:=92; B.BorderSpacing.Right:=8; B.BorderSpacing.Bottom:=8;
  B.Caption:='Apply'; B.Default:=True; B.OnClick:=@Accept;
  L:=TLabel.Create(Self); L.Parent:=Footer; L.Align:=alClient; L.BorderSpacing.Left:=12; L.BorderSpacing.Right:=12; L.AutoSize:=False; L.WordWrap:=True;
  L.Caption:='Moving arguments renumbers their # references. Deleting an argument removes its references.';
  Header:=TPanel.Create(Self); Header.Parent:=Self; Header.Align:=alTop; Header.Height:=48; Header.BevelOuter:=bvNone;
  L:=TLabel.Create(Self); L.Parent:=Header; L.AutoSize:=False; L.Align:=alLeft; L.Width:=132; L.BorderSpacing.Left:=12; L.Layout:=tlCenter; L.Caption:='Command name';
  CommandName:=TEdit.Create(Self); CommandName.Parent:=Header; CommandName.Align:=alClient;
  CommandName.BorderSpacing.Around:=10; CommandName.BorderSpacing.Left:=12; CommandName.BorderSpacing.Right:=12;
  Arguments:=TPanel.Create(Self); Arguments.Parent:=Self; Arguments.Align:=alTop; Arguments.Top:=48;
  Arguments.Height:=268; Arguments.Constraints.MinHeight:=256; Arguments.BevelOuter:=bvNone;
  Row:=TPanel.Create(Self); Row.Parent:=Arguments; Row.Align:=alBottom; Row.Height:=48; Row.BevelOuter:=bvNone;
  ArgumentType:=TComboBox.Create(Self); ArgumentType.Parent:=Row; ArgumentType.Align:=alLeft; ArgumentType.Width:=148; ArgumentType.AutoSize:=False;
  ArgumentType.BorderSpacing.Around:=10; ArgumentType.BorderSpacing.Left:=12; ArgumentType.BorderSpacing.Right:=0;
  ArgumentType.Style:=csDropDownList; ArgumentType.Items.CommaText:='Required,Optional'; ArgumentType.OnChange:=@Changed;
  DefaultValue:=TEdit.Create(Self); DefaultValue.Parent:=Row; DefaultValue.Align:=alClient;
  DefaultValue.BorderSpacing.Around:=10; DefaultValue.BorderSpacing.Left:=12; DefaultValue.BorderSpacing.Right:=12;
  DefaultValue.TextHint:='Optional argument default'; DefaultValue.OnChange:=@Changed;
  Buttons:=TPanel.Create(Self); Buttons.Parent:=Arguments; Buttons.Align:=alRight; Buttons.Width:=124; Buttons.BevelOuter:=bvNone; Buttons.BorderSpacing.Top:=4;
  for I:=0 to High(Actions) do begin
    B:=TButton.Create(Self); B.Parent:=Buttons; B.AutoSize:=False; B.Top:=I*36; B.Align:=alTop; B.Height:=30;
    B.BorderSpacing.Right:=12; B.BorderSpacing.Bottom:=6; B.Caption:=Actions[I]; B.Tag:=I; B.OnClick:=@Action;
  end;
  ArgumentList:=TStringGrid.Create(Self); ArgumentList.Parent:=Arguments; ArgumentList.Align:=alClient;
  ArgumentList.BorderSpacing.Left:=12; ArgumentList.BorderSpacing.Top:=4; ArgumentList.BorderSpacing.Right:=8; ArgumentList.BorderSpacing.Bottom:=8;
  ArgumentList.ColCount:=3; ArgumentList.FixedCols:=0; ArgumentList.FixedRows:=1; ArgumentList.RowCount:=2;
  ArgumentList.Options:=ArgumentList.Options+[goRowSelect]-[goEditing]; ArgumentList.OnSelectCell:=@Selected;
  ArgumentList.ColWidths[0]:=64; ArgumentList.ColWidths[1]:=118; ArgumentList.ColWidths[2]:=168;
  Split:=TSplitter.Create(Self); Split.Parent:=Self; Split.Align:=alTop; Split.Top:=316; Split.MinSize:=256; Split.ResizeControl:=Arguments;
  Body:=TPanel.Create(Self); Body.Parent:=Self; Body.Align:=alClient; Body.BevelOuter:=bvNone; Body.BorderSpacing.Around:=12;
  L:=TLabel.Create(Self); L.Parent:=Body; L.Caption:='Definition body'; L.Align:=alTop; L.BorderSpacing.Bottom:=6;
  BodyEditor:=TSynEdit.Create(Self); BodyEditor.Parent:=Body; BodyEditor.Align:=alClient;
  BodyEditor.Highlighter:=TSynTeXSyn.Create(Self); BodyEditor.Font.Name:=DefaultSourceFont; BodyEditor.Font.Size:=12;
  UseNativeSourceFonts(BodyEditor); BodyEditor.SetDefaultKeystrokes; BodyEditor.ResetMouseActions;
  TLazSynEditLineWrapPlugin.Create(BodyEditor); BodyEditor.OnChange:=@BodyChanged;
  Header.TabOrder:=0; Arguments.TabOrder:=1; Body.TabOrder:=2; Footer.TabOrder:=3;
  ApplyTheme(Self); ApplySourceStyle(BodyEditor);
end;
procedure TDefinitionForm.Refresh(Index:Integer);
var I:Integer;
begin
  FUpdating:=True;
  try
    ArgumentList.RowCount:=Max(2,Length(FArguments)+1);
    ArgumentList.Cells[0,0]:='Argument'; ArgumentList.Cells[1,0]:='Type'; ArgumentList.Cells[2,0]:='Default';
    for I:=0 to High(FArguments) do begin
      ArgumentList.Cells[0,I+1]:='#'+IntToStr(I+1);
      if FArguments[I].Kind in ['o','O'] then ArgumentList.Cells[1,I+1]:='Optional' else ArgumentList.Cells[1,I+1]:='Required';
      ArgumentList.Cells[2,I+1]:=FArguments[I].DefaultValue;
    end;
    if Length(FArguments)=0 then for I:=0 to 2 do ArgumentList.Cells[I,1]:='';
    Index:=EnsureRange(Index,0,Max(0,Length(FArguments)-1)); ArgumentList.Row:=Index+1;
    ArgumentType.Enabled:=Length(FArguments)>0; DefaultValue.Enabled:=False; ArgumentType.ItemIndex:=-1; DefaultValue.Text:='';
    if Length(FArguments)>0 then begin
      if FArguments[Index].Kind in ['o','O'] then ArgumentType.ItemIndex:=1 else ArgumentType.ItemIndex:=0;
      DefaultValue.Enabled:=ArgumentType.ItemIndex=1; DefaultValue.Text:=FArguments[Index].DefaultValue;
    end;
  finally FUpdating:=False; end;
end;
procedure TDefinitionForm.LoadSource(const Code:string);
var D:TCommandDefinition;
begin
  FSource:=Code;
  if ReadCommandDefinition(FSource,D) then begin
    FSource:=DefinitionEnsureArguments(FSource,DefinitionParameterCount(D.Body)); ReadCommandDefinition(FSource,D);
    FArguments:=Copy(D.Arguments); CommandName.Text:=D.Name;
    FUpdating:=True; try BodyEditor.Text:=D.Body; finally FUpdating:=False; end;
  end;
  Refresh(0);
end;
procedure TDefinitionForm.BodyChanged(Sender:TObject);
var Count,I:Integer;
begin
  if FUpdating then Exit; Count:=DefinitionParameterCount(BodyEditor.Text);
  I:=Length(FArguments); if Count<=I then Exit;
  SetLength(FArguments,Count);
  while I<Count do begin FArguments[I].Kind:='m'; FArguments[I].Spec:='m'; Inc(I); end;
  FSource:=DefinitionArgumentsSource(FSource,FArguments); Refresh(ArgumentList.Row-1);
end;
procedure TDefinitionForm.Selected(Sender:TObject; Col,Row:Integer; var CanSelect:Boolean);
begin if not FUpdating and (Row>0) then Refresh(Row-1); end;
procedure TDefinitionForm.Changed(Sender:TObject);
var I:Integer;
begin
  I:=ArgumentList.Row-1; if FUpdating or (I<0) or (I>=Length(FArguments)) then Exit;
  if ArgumentType.ItemIndex=1 then begin FArguments[I].Kind:='O'; FArguments[I].DefaultValue:=DefaultValue.Text; end
  else begin FArguments[I].Kind:='m'; FArguments[I].DefaultValue:=''; end;
  FArguments[I].Spec:=''; FSource:=DefinitionArgumentsSource(FSource,FArguments);
  if Sender=DefaultValue then ArgumentList.Cells[2,I+1]:=DefaultValue.Text else Refresh(I);
end;
procedure TDefinitionForm.Action(Sender:TObject);
var I,Operation:Integer; D:TCommandDefinition; Code:string;
begin
  BodyChanged(nil); I:=Length(FArguments); Operation:=TComponent(Sender).Tag;
  if Operation>=2 then begin
    I:=ArgumentList.Row-1; Code:=Source;
    if not ReadCommandDefinition(Code,D) then begin
      MessageDlg('Definition body','Match the braces in the body before moving or deleting arguments.',mtInformation,[mbOK],0); Exit;
    end;
    case Operation of
      2:Code:=DefinitionDeleteArgument(Code,I);
      3:begin Code:=DefinitionMoveArgument(Code,I,I-1); I:=Max(0,I-1); end;
      4:begin Code:=DefinitionMoveArgument(Code,I,I+1); I:=Min(Length(FArguments)-1,I+1); end;
    end;
    FSource:=Code; ReadCommandDefinition(FSource,D); FArguments:=Copy(D.Arguments);
    FUpdating:=True; try BodyEditor.Text:=D.Body; finally FUpdating:=False; end;
  end else begin
    if I>=9 then Exit; SetLength(FArguments,I+1);
    if TComponent(Sender).Tag=1 then FArguments[I].Kind:='O' else FArguments[I].Kind:='m';
    FSource:=DefinitionArgumentsSource(FSource,FArguments);
  end;
  Refresh(I);
end;
function TDefinitionForm.Source:string;
var D:TCommandDefinition;
begin
  Result:=DefinitionEnsureArguments(FSource,DefinitionParameterCount(BodyEditor.Text));
  if not ReadCommandDefinition(Result,D) then Exit;
  Result:=Copy(Result,1,D.BodyStart)+SourceEditorText(BodyEditor)+Copy(Result,D.BodyEnd+1,MaxInt);
  Result:=Copy(Result,1,D.NameStart)+Trim(CommandName.Text)+Copy(Result,D.NameEnd+1,MaxInt);
end;
procedure TDefinitionForm.Accept(Sender:TObject);
var Command:string; I:Integer;
begin
  Command:=Trim(CommandName.Text);
  for I:=1 to Length(Command) do if not (Command[I] in ['a'..'z','A'..'Z','@']) then begin
    MessageDlg('Command name','Use letters in the command name, without the backslash.',mtInformation,[mbOK],0); Exit;
  end;
  if Command<>'' then ModalResult:=mrOK;
end;
end.
