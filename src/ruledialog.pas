unit RuleDialog;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Forms, StdCtrls, TeXRules;
type TRuleDialog=class(TForm)
  private
    FRule:TTeXRule;
    FApply:TButton;
    procedure Changed(Sender:TObject);
    procedure CommandChanged(Sender:TObject);
  public
    RuleWidth,RuleHeight,RuleDepth,RaiseBy,Pattern:TEdit;
    Command,Alignment:TComboBox;
    constructor Create(AOwner:TComponent); override;
    procedure Load(const Rule:TTeXRule);
    function Source:string;
  end;
function EditRuleDialog(Owner:TComponent; var Source:string):Boolean;
implementation
uses SysUtils, Controls, UITheme;
constructor TRuleDialog.Create(AOwner:TComponent);
  function Field(const Text:string; Row:Integer):TEdit;
  var LabelControl:TLabel;
  begin
    LabelControl:=TLabel.Create(Self); LabelControl.Parent:=Self; LabelControl.SetBounds(16,62+Row*42,130,24); LabelControl.Caption:=Text;
    Result:=TEdit.Create(Self); Result.Parent:=Self; Result.SetBounds(154,58+Row*42,230,30);
    Result.Anchors:=[akLeft,akTop,akRight];
    Result.OnChange:=@Changed;
  end;
var LabelControl:TLabel; Button:TButton;
begin
  inherited CreateNew(AOwner); Caption:='Rule'; Position:=poMainFormCenter; BorderStyle:=bsDialog;
  ClientWidth:=400; ClientHeight:=396;
  LabelControl:=TLabel.Create(Self); LabelControl.Parent:=Self; LabelControl.SetBounds(16,20,130,24); LabelControl.Caption:='Command';
  Command:=TComboBox.Create(Self); Command.Parent:=Self; Command.SetBounds(154,16,230,30); Command.Style:=csDropDownList;
  Command.Items.AddStrings(['\hrule','\rule','\hdashrule','\vrule']); Command.ItemIndex:=0;
  Command.OnChange:=@CommandChanged;
  RuleWidth:=Field('Width',0); RuleHeight:=Field('Thickness / height',1); RuleDepth:=Field('Depth',2);
  RaiseBy:=Field('Raise',3); Pattern:=Field('Dash / gap lengths',4);
  LabelControl:=TLabel.Create(Self); LabelControl.Parent:=Self; LabelControl.SetBounds(16,272,130,24); LabelControl.Caption:='Dash alignment';
  Alignment:=TComboBox.Create(Self); Alignment.Parent:=Self; Alignment.SetBounds(154,268,230,30); Alignment.Style:=csDropDownList;
  Alignment.Items.Add('Centered'); Alignment.Items.Add('Equal gaps'); Alignment.ItemIndex:=0;
  LabelControl:=TLabel.Create(Self); LabelControl.Parent:=Self; LabelControl.SetBounds(16,312,368,36);
  LabelControl.WordWrap:=True; LabelControl.AutoSize:=False; LabelControl.Caption:='Use lengths such as 0.6pt, 3mm or \linewidth. Empty primitive dimensions keep TeX defaults.';
  FApply:=TButton.Create(Self); FApply.Parent:=Self; FApply.SetBounds(204,356,86,30); FApply.Caption:='Apply'; FApply.Default:=True; FApply.ModalResult:=mrOK;
  Button:=TButton.Create(Self); Button.Parent:=Self; Button.SetBounds(298,356,86,30); Button.Caption:='Cancel'; Button.Cancel:=True; Button.ModalResult:=mrCancel;
  ApplyTheme(Self);
end;
procedure TRuleDialog.Load(const Rule:TTeXRule);
begin
  FRule:=Rule; Caption:='Rule '+ '\'+Rule.Kind;
  Command.ItemIndex:=Command.Items.IndexOf('\'+Rule.Kind);
  RuleWidth.Text:=Rule.Width; RuleHeight.Text:=Rule.Height; RuleDepth.Text:=Rule.Depth;
  RaiseBy.Text:=Rule.RaiseBy; Pattern.Text:=Rule.Pattern;
  RuleDepth.Enabled:=(Rule.Kind='hrule') or (Rule.Kind='vrule'); RaiseBy.Enabled:=not RuleDepth.Enabled;
  Pattern.Enabled:=Rule.Kind='hdashrule'; Alignment.Enabled:=Pattern.Enabled;
  if Rule.Alignment='x' then Alignment.ItemIndex:=1 else Alignment.ItemIndex:=0;
  Changed(nil);
end;
procedure TRuleDialog.CommandChanged(Sender:TObject);
var Primitive:Boolean;
begin
  Primitive:=(Command.Text='\hrule') or (Command.Text='\vrule');
  RuleDepth.Enabled:=Primitive; RaiseBy.Enabled:=not Primitive;
  Pattern.Enabled:=Command.Text='\hdashrule'; Alignment.Enabled:=Pattern.Enabled;
  if not Primitive then begin
    if Trim(RuleWidth.Text)='' then RuleWidth.Text:='\linewidth';
    if Trim(RuleHeight.Text)='' then RuleHeight.Text:='0.4pt';
  end;
  if Pattern.Enabled and (Trim(Pattern.Text)='') then Pattern.Text:='3pt 2pt';
  Changed(nil);
end;
procedure TRuleDialog.Changed(Sender:TObject);
var Rule:TTeXRule;
begin if FApply<>nil then FApply.Enabled:=ReadTeXRule(Source,Rule); end;
function TRuleDialog.Source:string;
var Rule:TTeXRule;
begin
  Rule:=FRule; Rule.Kind:=Copy(Command.Text,2,MaxInt);
  Rule.Width:=RuleWidth.Text; Rule.Height:=RuleHeight.Text; Rule.Depth:=RuleDepth.Text;
  Rule.RaiseBy:=RaiseBy.Text; Rule.Pattern:=Pattern.Text;
  if Alignment.ItemIndex=1 then Rule.Alignment:='x' else Rule.Alignment:='';
  Result:=TeXRuleSource(Rule);
end;
function EditRuleDialog(Owner:TComponent; var Source:string):Boolean;
var Rule:TTeXRule; Dialog:TRuleDialog;
begin
  Result:=False; if not ReadTeXRule(Source,Rule) then Exit;
  Dialog:=TRuleDialog.Create(Owner);
  try Dialog.Load(Rule); Result:=Dialog.ShowModal=mrOK; if Result then Source:=Dialog.Source;
  finally Dialog.Free; end;
end;
end.
