unit PluginDialog;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, FPJSON, SynEdit;
type
  TPluginDialog=class(TForm)
  private
    FDefinition:TJSONObject;
    FInputs:array of TControl;
  public
    constructor Create(AOwner:TComponent); override;
    procedure Load(Definition,Values:TJSONObject);
    procedure Store(Values:TJSONObject);
  end;
implementation
uses SysUtils, Math, IniFiles, SourceFonts, SourceStyle, SynEditWrappedView, UITheme;
constructor TPluginDialog.Create(AOwner:TComponent);
begin
  inherited CreateNew(AOwner); Name:='PluginConfiguration'; Position:=poOwnerFormCenter;
  ClientWidth:=740; ClientHeight:=510; Constraints.MinWidth:=540; Constraints.MinHeight:=360;
end;
procedure TPluginDialog.Load(Definition,Values:TJSONObject);
var Tabs:TPageControl; Tab:TTabSheet; Page:TScrollBox; Groups:TStringList; Footer,Row:TPanel;
    Button:TButton; LabelText:TLabel; Field:TJSONObject; I,J,Index:Integer; Key,Kind,Value,Group:string;
    Edit:TEdit; Choice:TComboBox; Check:TCheckBox; Code:TSynEdit; Preferences:TIniFile;
begin
  FDefinition:=Definition; Caption:=Definition.Get('title','Configure command');
  Footer:=TPanel.Create(Self); Footer.Parent:=Self; Footer.Align:=alBottom; Footer.Height:=44; Footer.BevelOuter:=bvNone;
  Button:=TButton.Create(Self); Button.Parent:=Footer; Button.Align:=alRight; Button.Width:=100;
  Button.BorderSpacing.Around:=6; Button.Caption:=Definition.Get('acceptLabel','Apply'); Button.Default:=True; Button.ModalResult:=mrOK;
  Button:=TButton.Create(Self); Button.Parent:=Footer; Button.Align:=alRight; Button.Width:=100;
  Button.BorderSpacing.Around:=6; Button.Caption:='Cancel'; Button.Cancel:=True; Button.ModalResult:=mrCancel;
  Tabs:=TPageControl.Create(Self); Tabs.Parent:=Self; Tabs.Align:=alClient;
  Groups:=TStringList.Create;
  try
    SetLength(FInputs,Min(128,Definition.Arrays['fields'].Count));
    for I:=0 to High(FInputs) do begin
      Field:=Definition.Arrays['fields'].Objects[I]; Key:=Field.Get('key',''); Kind:=Field.Get('type','text');
      Group:=Field.Get('group','Options'); Index:=Groups.IndexOf(Group);
      if Index<0 then begin
        Tab:=TTabSheet.Create(Self); Tab.PageControl:=Tabs; Tab.Caption:=Group;
        Page:=TScrollBox.Create(Self); Page.Parent:=Tab; Page.Align:=alClient; Page.BorderStyle:=bsNone;
        Index:=Groups.AddObject(Group,Page);
      end;
      Page:=TScrollBox(Groups.Objects[Index]); Row:=TPanel.Create(Self); Row.Parent:=Page;
      Row.Top:=MaxInt div 2; Row.Align:=alTop; Row.BevelOuter:=bvNone; Row.BorderSpacing.Around:=10; Row.Height:=70;
      Value:=Field.Get('value',''); if Values.Find(Key)<>nil then Value:=Values.Get(Key,Value);
      if Kind='checkbox' then begin
        Check:=TCheckBox.Create(Self); Check.Parent:=Row; Check.Align:=alClient;
        Check.Caption:=Field.Get('label',Key); Check.Checked:=(LowerCase(Value)='true') or (Value='1'); FInputs[I]:=Check; Row.Height:=34;
      end else begin
        LabelText:=TLabel.Create(Self); LabelText.Parent:=Row; LabelText.Align:=alTop;
        LabelText.Caption:=Field.Get('label',Key); LabelText.BorderSpacing.Bottom:=6;
        if Kind='code' then begin
          Code:=TSynEdit.Create(Self); Code.Parent:=Row; Code.Align:=alClient; Row.Height:=Max(180,Field.Get('height',240));
          UseNativeSourceFonts(Code); Preferences:=TIniFile.Create(GetAppConfigFile(False));
          try
            Code.Font.Name:=NormalizeSourceFont(Preferences.ReadString('Editor','FontName',DefaultSourceFont));
            Code.Font.Size:=EnsureRange(Preferences.ReadInteger('Editor','FontSize',12),8,36);
          finally Preferences.Free; end;
          ApplySourceStyle(Code);
          TLazSynEditLineWrapPlugin.Create(Code); Code.Text:=Value; FInputs[I]:=Code;
        end else if Field.Find('choices') is TJSONArray then begin
          Choice:=TComboBox.Create(Self); Choice.Parent:=Row; Choice.Align:=alTop; Choice.Style:=csDropDown;
          for J:=0 to Field.Arrays['choices'].Count-1 do Choice.Items.Add(Field.Arrays['choices'].Strings[J]);
          Choice.Text:=Value; FInputs[I]:=Choice;
        end else begin
          Edit:=TEdit.Create(Self); Edit.Parent:=Row; Edit.Align:=alTop; Edit.Text:=Value; FInputs[I]:=Edit;
        end;
      end;
      FInputs[I].Name:='PluginInput'+IntToStr(I); FInputs[I].HelpKeyword:=Key;
      FInputs[I].Hint:=Field.Get('hint',''); FInputs[I].ShowHint:=FInputs[I].Hint<>'';
    end;
    if Tabs.PageCount>0 then Tabs.ActivePageIndex:=0;
  finally Groups.Free; end;
  ApplyTheme(Self);
  for I:=0 to High(FInputs) do if FInputs[I] is TSynEdit then ApplySourceStyle(TSynEdit(FInputs[I]));
end;
procedure TPluginDialog.Store(Values:TJSONObject);
var I:Integer; Key:string;
begin
  for I:=0 to High(FInputs) do begin
    Key:=FDefinition.Arrays['fields'].Objects[I].Get('key','');
    if FInputs[I] is TCheckBox then Values.Booleans[Key]:=TCheckBox(FInputs[I]).Checked
    else if FInputs[I] is TSynEdit then Values.Strings[Key]:=TrimRight(TSynEdit(FInputs[I]).Text)
    else if FInputs[I] is TComboBox then Values.Strings[Key]:=TComboBox(FInputs[I]).Text
    else Values.Strings[Key]:=TEdit(FInputs[I]).Text;
  end;
end;
end.
