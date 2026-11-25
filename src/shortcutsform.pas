unit ShortcutsForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Menus;
type
  TShortcutsForm=class(TForm)
  private
    FCommands:TList;
    FKeys:TStringList;
    FHotkey:TShortCut;
    procedure Selected(Sender:TObject);
    procedure CaptureKey(Sender:TObject; var Key:Word; Shift:TShiftState);
    procedure Action(Sender:TObject);
  public
    Items:TListBox;
    Hotkey:TEdit;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(MainMenu:TMainMenu);
  end;
procedure LoadEditorShortcuts(Menu:TMainMenu);
function EditorShortcutCommand(Root:TMenuItem; Key:TShortCut):TMenuItem;
implementation
uses IniFiles, LCLType, LCLProc, Dialogs, UITheme;
var DefaultKeys:TStringList;
function ActionPath(Item:TMenuItem):string;
begin
  Result:=StringReplace(StringReplace(Item.Caption,'&','',[rfReplaceAll]),'=','_',[rfReplaceAll]);
  if (Item.Parent<>nil) and (Item.Parent.Parent<>nil) then Result:=ActionPath(Item.Parent)+' / '+Result;
end;
procedure LoadEditorShortcuts(Menu:TMainMenu);
var Ini:TIniFile;
  procedure Visit(Item:TMenuItem);
  var I:Integer; Key:string;
  begin
    if Assigned(Item.OnClick) and (Item.Count=0) then begin
      Key:=ActionPath(Item); if DefaultKeys.IndexOfName(Key)<0 then DefaultKeys.Values[Key]:=IntToStr(Item.ShortCut);
      Item.ShortCut:=Ini.ReadInteger('Shortcuts',Key,Item.ShortCut);
    end;
    for I:=0 to Item.Count-1 do Visit(Item.Items[I]);
  end;
begin
  if DefaultKeys=nil then DefaultKeys:=TStringList.Create;
  Ini:=TIniFile.Create(GetAppConfigFile(False)); try Visit(Menu.Items); finally Ini.Free; end;
end;
function EditorShortcutCommand(Root:TMenuItem; Key:TShortCut):TMenuItem;
var I:Integer;
begin
  Result:=nil; if (Key=0) or not Root.Enabled then Exit;
  if (Root.ShortCut=Key) and Assigned(Root.OnClick) and (Root.Count=0) then Exit(Root);
  for I:=0 to Root.Count-1 do begin Result:=EditorShortcutCommand(Root.Items[I],Key); if Result<>nil then Exit; end;
end;
constructor TShortcutsForm.Create(AOwner:TComponent);
var Footer,Fields:TPanel; B:TButton; I:Integer; L:TLabel;
begin
  inherited CreateNew(AOwner); Caption:='Keyboard shortcuts'; Position:=poOwnerFormCenter; ClientWidth:=780; ClientHeight:=550;
  FCommands:=TList.Create; FKeys:=TStringList.Create;
  Footer:=TPanel.Create(Self); Footer.Parent:=Self; Footer.Align:=alBottom; Footer.Height:=44; Footer.BevelOuter:=bvNone;
  for I:=0 to 3 do begin B:=TButton.Create(Self); B.Parent:=Footer; B.SetBounds(8+I*190,5,180,32); B.Tag:=I; B.OnClick:=@Action;
    case I of 0:B.Caption:='Assign'; 1:B.Caption:='Clear'; 2:B.Caption:='Restore defaults'; 3:B.Caption:='Apply'; end; end;
  Fields:=TPanel.Create(Self); Fields.Parent:=Self; Fields.Align:=alBottom; Fields.Height:=70; Fields.BevelOuter:=bvNone;
  L:=TLabel.Create(Self); L.Parent:=Fields; L.Caption:='Select a command, then press its new shortcut here'; L.SetBounds(8,4,750,22);
  Hotkey:=TEdit.Create(Self); Hotkey.Parent:=Fields; Hotkey.SetBounds(8,30,500,30); Hotkey.ReadOnly:=True; Hotkey.OnKeyDown:=@CaptureKey;
  Items:=TListBox.Create(Self); Items.Parent:=Self; Items.Align:=alClient; Items.OnClick:=@Selected;
  {$IFDEF LCLgtk3}Items.Style:=lbOwnerDrawFixed; Items.ItemHeight:=24;{$ENDIF}
  ApplyTheme(Self);
end;
destructor TShortcutsForm.Destroy;
begin FCommands.Free; FKeys.Free; inherited; end;
procedure TShortcutsForm.Load(MainMenu:TMainMenu);
  procedure Visit(Item:TMenuItem);
  var I:Integer;
  begin
    if not Item.Visible then Exit;
    if Assigned(Item.OnClick) and (Item.Count=0) then begin FCommands.Add(Item); FKeys.Add(IntToStr(Item.ShortCut)); Items.Items.Add(ActionPath(Item)+'    '+ShortCutToText(Item.ShortCut)); end;
    for I:=0 to Item.Count-1 do Visit(Item.Items[I]);
  end;
begin FCommands.Clear; FKeys.Clear; Items.Items.Clear; Visit(MainMenu.Items); if Items.Count>0 then begin Items.ItemIndex:=0; Selected(nil); end; end;
procedure TShortcutsForm.Selected(Sender:TObject);
begin if Items.ItemIndex<0 then Exit; FHotkey:=StrToIntDef(FKeys[Items.ItemIndex],0); Hotkey.Text:=ShortCutToText(FHotkey); end;
procedure TShortcutsForm.CaptureKey(Sender:TObject; var Key:Word; Shift:TShiftState);
begin
  if Key in [VK_SHIFT,VK_CONTROL,VK_MENU] then Exit;
  if (Key in [VK_DELETE,VK_BACK]) and (Shift=[]) then FHotkey:=0 else FHotkey:=ShortCut(Key,Shift);
  Hotkey.Text:=ShortCutToText(FHotkey); Key:=0;
end;
procedure TShortcutsForm.Action(Sender:TObject);
var I,J:Integer; Item:TMenuItem; Ini:TIniFile;
begin
  I:=Items.ItemIndex;
  case TComponent(Sender).Tag of
    0,1:begin
      if I<0 then Exit; if TComponent(Sender).Tag=1 then FHotkey:=0;
      if FHotkey<>0 then for J:=0 to FKeys.Count-1 do if (J<>I) and (StrToIntDef(FKeys[J],0)=FHotkey) then begin
        MessageDlg('This shortcut belongs to '+ActionPath(TMenuItem(FCommands[J]))+'. Clear it first.',mtInformation,[mbOK],0); Exit;
      end;
      FKeys[I]:=IntToStr(FHotkey); Items.Items[I]:=ActionPath(TMenuItem(FCommands[I]))+'    '+ShortCutToText(FHotkey); Selected(nil);
    end;
    2:for J:=0 to FKeys.Count-1 do begin FKeys[J]:=DefaultKeys.Values[ActionPath(TMenuItem(FCommands[J]))]; Items.Items[J]:=ActionPath(TMenuItem(FCommands[J]))+'    '+ShortCutToText(StrToIntDef(FKeys[J],0)); end;
    3:begin
      ForceDirectories(GetAppConfigDir(False)); Ini:=TIniFile.Create(GetAppConfigFile(False));
      try for J:=0 to FKeys.Count-1 do begin Item:=TMenuItem(FCommands[J]); Item.ShortCut:=StrToIntDef(FKeys[J],0); Ini.WriteInteger('Shortcuts',ActionPath(Item),Item.ShortCut); end;
      finally Ini.Free; end; ModalResult:=mrOK;
    end;
  end;
end;
finalization
  DefaultKeys.Free;
end.
