unit DocumentFontsEditor;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, TeXFontConfig, TeXOptionsEditor;
type
  TDocumentFontsEditor=class(TPanel)
  private
    FSource:string;
    FFonts:TDocumentFonts;
    FUpdating:Boolean;
    FIndex:Integer;
    FDetail:TPanel;
    FDelete,FFile:TButton;
    FFontLabel,FFamilyLabel:TLabel;
    procedure Selected(Sender:TObject);
    procedure SelectionChanged(Sender:TObject; User:Boolean);
    procedure Edited(Sender:TObject);
    procedure Action(Sender:TObject);
    procedure ListFonts(Sender:TObject);
    procedure LayoutControls(Sender:TObject);
    procedure RefreshList(Index:Integer);
  public
    FontList:TListBox;
    Command,FontName:TComboBox;
    Family,Alias:TEdit;
    AppendFeatures:TCheckBox;
    Options:TTeXOptionsEditor;
    constructor Create(AOwner:TComponent); override;
    procedure Load(const ASource:string);
    function Source:string;
    function ApplyTo(const ASource:string):string;
    function Changed:Boolean;
  end;
implementation
uses Math, UnicodeEdits, Dialogs;
constructor TDocumentFontsEditor.Create(AOwner:TComponent);
var LeftPanel,Buttons:TPanel; Split:TSplitter; B:TButton; LabelControl:TLabel;
  function LabelAt(const Title:string; Y:Integer):TLabel;
  begin
    Result:=TLabel.Create(Self); Result.Parent:=FDetail; Result.Caption:=Title;
    Result.SetBounds(0,Y,150,24);
  end;
begin
  inherited Create(AOwner); BevelOuter:=bvNone; FIndex:=-1;
  LeftPanel:=TPanel.Create(Self); LeftPanel.Parent:=Self; LeftPanel.Align:=alLeft; LeftPanel.Width:=235; LeftPanel.BevelOuter:=bvNone;
  Buttons:=TPanel.Create(Self); Buttons.Parent:=LeftPanel; Buttons.Align:=alBottom; Buttons.Height:=42; Buttons.BevelOuter:=bvNone;
  B:=TButton.Create(Self); B.Parent:=Buttons; B.Caption:='Add'; B.SetBounds(0,6,108,30); B.OnClick:=@Action;
  FDelete:=TButton.Create(Self); FDelete.Parent:=Buttons; FDelete.Caption:='Delete'; FDelete.Tag:=1;
  FDelete.SetBounds(116,6,108,30); FDelete.OnClick:=@Action;
  FontList:=TListBox.Create(Self); FontList.Parent:=LeftPanel; FontList.Align:=alClient;
  FontList.OnClick:=@Selected; FontList.OnSelectionChange:=@SelectionChanged;
  {$IFDEF LCLgtk3}FontList.Style:=lbOwnerDrawFixed; FontList.ItemHeight:=24;{$ENDIF}
  Split:=TSplitter.Create(Self); Split.Parent:=Self; Split.Align:=alLeft; Split.Left:=235; Split.Width:=8;
  FDetail:=TPanel.Create(Self); FDetail.Parent:=Self; FDetail.Align:=alClient; FDetail.BevelOuter:=bvNone;
  FDetail.Constraints.MinWidth:=520; LeftPanel.Constraints.MinWidth:=150;
  LabelControl:=LabelAt('Font command',4); LabelControl.Hint:='CJK commands require xeCJK or ctex with XeLaTeX.'; LabelControl.ShowHint:=True;
  Command:=TComboBox.Create(Self); Command.Parent:=FDetail; Command.Style:=csDropDownList;
  Command.Items.CommaText:='setCJKmainfont,setCJKsansfont,setCJKmonofont,setCJKfamilyfont,newCJKfontfamily,setmainfont,setsansfont,setmonofont,newfontfamily,renewfontfamily,providefontfamily,newfontface,defaultCJKfontfeatures,defaultfontfeatures';
  Command.OnChange:=@Edited;
  FFontLabel:=LabelAt('Font name or file',44);
  FontName:=TUnicodeComboBox.Create(Self); FontName.Parent:=FDetail; FontName.OnChange:=@Edited; FontName.OnDropDown:=@ListFonts;
  FFile:=TButton.Create(Self); FFile.Parent:=FDetail; FFile.Caption:='Browse…'; FFile.Tag:=2; FFile.OnClick:=@Action;
  AppendFeatures:=TCheckBox.Create(Self); AppendFeatures.Parent:=FDetail; AppendFeatures.Caption:='Append to existing defaults';
  AppendFeatures.OnChange:=@Edited;
  FFamilyLabel:=LabelAt('Family',84); Family:=TUnicodeEdit.Create(Self); Family.Parent:=FDetail; Family.OnChange:=@Edited;
  Family.ShowHint:=True;
  LabelControl:=LabelAt('Command name',124); Alias:=TUnicodeEdit.Create(Self); Alias.Parent:=FDetail; Alias.OnChange:=@Edited;
  LabelControl:=LabelAt('Font features (BoldFont, ItalicFont, Scale, Path, …)',164); LabelControl.Width:=520;
  Options:=TTeXOptionsEditor.Create(Self); Options.Parent:=FDetail; Options.OnChange:=@Edited;
  FDetail.OnResize:=@LayoutControls; SetBounds(0,0,880,408); LayoutControls(nil); Selected(nil);
end;
procedure TDocumentFontsEditor.LayoutControls(Sender:TObject);
var W:Integer;
begin
  if Options=nil then Exit; W:=Max(240,FDetail.ClientWidth-154);
  Command.SetBounds(148,0,W,30); FontName.SetBounds(148,40,Max(120,W-96),30); FFile.SetBounds(148+W-90,40,90,30);
  AppendFeatures.SetBounds(148,40,W,30);
  Family.SetBounds(148,80,W,30); Alias.SetBounds(148,120,W,30);
  Options.SetBounds(0,192,Max(480,FDetail.ClientWidth),Max(140,FDetail.ClientHeight-192));
end;
procedure TDocumentFontsEditor.ListFonts(Sender:TObject);
var SelectedFont:string;
begin
  if FontName.Items.Count>0 then Exit;
  SelectedFont:=FontName.Text; FUpdating:=True;
  try FontName.Items.Assign(Screen.Fonts); FontName.Text:=SelectedFont;
  finally FUpdating:=False; end;
end;
procedure TDocumentFontsEditor.Load(const ASource:string);
begin FSource:=ASource; FFonts:=DocumentFonts(ASource); RefreshList(0); end;
function TDocumentFontsEditor.Source:string;
begin Result:=ReplaceDocumentFonts(FSource,FFonts); end;
function TDocumentFontsEditor.Changed:Boolean;
begin Result:=Source<>FSource; end;
function TDocumentFontsEditor.ApplyTo(const ASource:string):string;
var Current:TDocumentFonts; I,J,Index:Integer; Used:array of Boolean;
begin
  if not Changed then Exit(ASource);
  Current:=DocumentFonts(ASource); SetLength(Used,Length(Current));
  for I:=0 to High(FFonts) do begin
    Index:=-1;
    if FFonts[I].First>0 then
      for J:=0 to High(Used) do if not Used[J] and (Current[J].Original=FFonts[I].Original) then begin Index:=J; Used[J]:=True; Break; end;
    if not FFonts[I].Deleted and (DocumentFontCode(FFonts[I])=FFonts[I].Original) then Continue;
    if Index>=0 then begin
      Current[Index].Command:=FFonts[I].Command; Current[Index].Name:=FFonts[I].Name;
      Current[Index].Family:=FFonts[I].Family; Current[Index].Alias:=FFonts[I].Alias;
      Current[Index].Options:=FFonts[I].Options; Current[Index].Deleted:=FFonts[I].Deleted;
      Current[Index].AppendFeatures:=FFonts[I].AppendFeatures;
    end else if not FFonts[I].Deleted then begin
      SetLength(Current,Length(Current)+1); Current[High(Current)]:=FFonts[I]; Current[High(Current)].First:=0;
    end;
  end;
  Result:=ReplaceDocumentFonts(ASource,Current);
end;
procedure TDocumentFontsEditor.RefreshList(Index:Integer);
var I:Integer; Title:string;
begin
  FUpdating:=True; FontList.Items.BeginUpdate;
  try
    FontList.Items.Clear;
    for I:=0 to High(FFonts) do if not FFonts[I].Deleted then begin
      Title:='\'+FFonts[I].Command;
      if FFonts[I].Family<>'' then Title:=Title+' ('+FFonts[I].Family+')';
      FontList.Items.AddObject(Title,TObject(PtrInt(I)));
    end;
    FontList.ItemIndex:=Min(Index,FontList.Count-1);
  finally FontList.Items.EndUpdate; FUpdating:=False; end;
  Selected(nil);
end;
procedure TDocumentFontsEditor.Selected(Sender:TObject);
var Valid,Named,Defaults:Boolean;
begin
  if FUpdating then Exit; FUpdating:=True;
  try
    FIndex:=-1; if FontList.ItemIndex>=0 then FIndex:=PtrInt(FontList.Items.Objects[FontList.ItemIndex]);
    Valid:=FIndex>=0; Command.Enabled:=Valid; Options.Enabled:=Valid; FDelete.Enabled:=Valid;
    Command.ItemIndex:=-1; FontName.Text:=''; Family.Text:=''; Alias.Text:=''; Options.Text:=''; AppendFeatures.Checked:=False;
    if Valid then begin
      if Command.Items.IndexOf(FFonts[FIndex].Command)<0 then Command.Items.Add(FFonts[FIndex].Command);
      Command.ItemIndex:=Command.Items.IndexOf(FFonts[FIndex].Command);
      FontName.Text:=FFonts[FIndex].Name; Family.Text:=FFonts[FIndex].Family;
      Alias.Text:=FFonts[FIndex].Alias; Options.Text:=FFonts[FIndex].Options;
      AppendFeatures.Checked:=FFonts[FIndex].AppendFeatures;
    end;
    Named:=NamedDocumentFont(Command.Text) or (Command.Text='setCJKfamilyfont'); Defaults:=Pos('default',Command.Text)=1;
    Family.Enabled:=Valid and (Named or (Command.Text='defaultfontfeatures'));
    Alias.Enabled:=Valid and NamedDocumentFont(Command.Text);
    FontName.Enabled:=Valid and not Defaults; FFile.Enabled:=FontName.Enabled;
    FontName.Visible:=not Defaults; FFile.Visible:=not Defaults; FFontLabel.Visible:=not Defaults;
    AppendFeatures.Visible:=Command.Text='defaultfontfeatures'; AppendFeatures.Enabled:=Valid;
    FFamilyLabel.Caption:='Family'; Family.Hint:='The CJK family name used with \CJKfamily.';
    if Command.Text='defaultfontfeatures' then begin
      FFamilyLabel.Caption:='Targets (optional)';
      Family.Hint:='Font names or commands such as \rmfamily,\sffamily; leave blank for all fonts.';
    end;
  finally FUpdating:=False; end;
end;
procedure TDocumentFontsEditor.SelectionChanged(Sender:TObject; User:Boolean);
begin Selected(Sender); end;
procedure TDocumentFontsEditor.Edited(Sender:TObject);
var I:Integer;
begin
  if FUpdating or (FIndex<0) then Exit;
  FFonts[FIndex].Command:=Command.Text; FFonts[FIndex].Name:=FontName.Text;
  FFonts[FIndex].Options:=Options.Text; FFonts[FIndex].Family:=Family.Text;
  FFonts[FIndex].AppendFeatures:=AppendFeatures.Checked and (Command.Text='defaultfontfeatures');
  FFonts[FIndex].Alias:=StringReplace(Alias.Text,'\','',[]);
  if Sender=Command then begin
    if Pos('default',Command.Text)=1 then FFonts[FIndex].Family:=''
    else if not NamedDocumentFont(Command.Text) and (Command.Text<>'setCJKfamilyfont') then begin
      FFonts[FIndex].Family:='rm';
      if Pos('sans',Command.Text)>0 then FFonts[FIndex].Family:='sf'
      else if Pos('mono',Command.Text)>0 then FFonts[FIndex].Family:='tt';
    end else FFonts[FIndex].Family:='';
    I:=FontList.ItemIndex; RefreshList(I);
  end;
end;
procedure TDocumentFontsEditor.Action(Sender:TObject);
var I:Integer; Dialog:TOpenDialog;
begin
  case TComponent(Sender).Tag of
    0:begin
      I:=Length(FFonts); SetLength(FFonts,I+1);
      FFonts[I].Command:='setCJKmainfont'; FFonts[I].Family:='rm'; RefreshList(FontList.Count);
    end;
    1:if FIndex>=0 then begin FFonts[FIndex].Deleted:=True; RefreshList(FontList.ItemIndex); end;
    2:begin
      Dialog:=TOpenDialog.Create(Self);
      try
        Dialog.Title:='Choose a document font'; Dialog.Filter:='OpenType / TrueType|*.otf;*.ttf;*.ttc|All files|*';
        if Dialog.Execute then begin
          FontName.Text:=StringReplace(Dialog.FileName,'\','/',[rfReplaceAll]); Edited(FontName);
        end;
      finally Dialog.Free; end;
    end;
  end;
end;
end.
