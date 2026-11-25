unit CommandSearch;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Menus;
type TCommandSearchForm=class(TForm)
  private
    FCommands:TStringList;
    procedure Filter(Sender:TObject);
    procedure Accept(Sender:TObject);
    procedure SearchKey(Sender:TObject; var Key:Word; Shift:TShiftState);
  public
    Search:TEdit;
    Matches:TListBox;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(MainMenu:TMainMenu);
    function SelectedCommand:TMenuItem;
  end;
implementation
uses UITheme, LCLType, LCLProc, Math;
constructor TCommandSearchForm.Create(AOwner:TComponent);
var Footer:TPanel; B:TButton; L:TLabel;
begin
  inherited CreateNew(AOwner); Caption:='Find a command'; Position:=poOwnerFormCenter; PopupMode:=pmAuto;
  ClientWidth:=660; ClientHeight:=470; Constraints.MinWidth:=450; Constraints.MinHeight:=300;
  FCommands:=TStringList.Create;
  L:=TLabel.Create(Self); L.Parent:=Self; L.Align:=alTop; L.BorderSpacing.Around:=12;
  L.Caption:='Search by action or menu name. Use ↑ / ↓ and Enter to run a command.';
  Search:=TEdit.Create(Self); Search.Parent:=Self; Search.Align:=alTop; Search.BorderSpacing.Around:=12;
  Search.TextHint:='For example: fraction, table, bibliography, export'; Search.OnChange:=@Filter; Search.OnKeyDown:=@SearchKey;
  Footer:=TPanel.Create(Self); Footer.Parent:=Self; Footer.Align:=alBottom; Footer.Height:=46; Footer.BevelOuter:=bvNone;
  B:=TButton.Create(Self); B.Parent:=Footer; B.Align:=alRight; B.BorderSpacing.Around:=6; B.Width:=100;
  B.Caption:='Run'; B.Default:=True; B.OnClick:=@Accept;
  B:=TButton.Create(Self); B.Parent:=Footer; B.Align:=alRight; B.BorderSpacing.Around:=6; B.Width:=100;
  B.Caption:='Cancel'; B.Cancel:=True; B.ModalResult:=mrCancel;
  Matches:=TListBox.Create(Self); Matches.Parent:=Self; Matches.Align:=alClient; Matches.BorderSpacing.Around:=12;
  Matches.OnDblClick:=@Accept; Matches.OnKeyDown:=@SearchKey; ActiveControl:=Search; ApplyTheme(Self);
end;
destructor TCommandSearchForm.Destroy;
begin FCommands.Free; inherited; end;
procedure TCommandSearchForm.Load(MainMenu:TMainMenu);
  procedure Scan(Item:TMenuItem; const Path:string; Enabled:Boolean);
  var I:Integer; Title,Full:string;
  begin
    if not Item.Visible or (Item.Caption='-') then Exit;
    Enabled:=Enabled and Item.Enabled;
    Title:=StringReplace(Item.Caption,'&','',[rfReplaceAll]); Full:=Path;
    if Full<>'' then Full:=Full+'  ›  '; Full:=Full+Title;
    if (Item.Count=0) and Assigned(Item.OnClick) and Enabled then begin
      if Item.ShortCut<>0 then Full:=Full+'    '+ShortCutToText(Item.ShortCut);
      FCommands.AddObject(Full,Item);
    end;
    for I:=0 to Item.Count-1 do Scan(Item.Items[I],Full,Enabled);
  end;
var I:Integer;
begin
  FCommands.Clear;
  for I:=0 to MainMenu.Items.Count-1 do Scan(MainMenu.Items[I],'',True);
  Filter(nil);
end;
procedure TCommandSearchForm.Filter(Sender:TObject);
var I:Integer; Query:string;
begin
  Query:=LowerCase(Trim(Search.Text)); Matches.Items.BeginUpdate;
  try
    Matches.Items.Clear;
    for I:=0 to FCommands.Count-1 do if (Query='') or (Pos(Query,LowerCase(FCommands[I]))>0) then
      Matches.Items.AddObject(FCommands[I],FCommands.Objects[I]);
    if Matches.Count>0 then Matches.ItemIndex:=0;
  finally Matches.Items.EndUpdate; end;
end;
function TCommandSearchForm.SelectedCommand:TMenuItem;
begin
  Result:=nil; if Matches.ItemIndex>=0 then Result:=TMenuItem(Matches.Items.Objects[Matches.ItemIndex]);
end;
procedure TCommandSearchForm.Accept(Sender:TObject);
begin if SelectedCommand<>nil then ModalResult:=mrOK; end;
procedure TCommandSearchForm.SearchKey(Sender:TObject; var Key:Word; Shift:TShiftState);
begin
  if Key=VK_RETURN then begin Accept(nil); Key:=0; end
  else if (Sender=Search) and (Key in [VK_UP,VK_DOWN]) and (Matches.Count>0) then begin
    if Key=VK_UP then Matches.ItemIndex:=Max(0,Matches.ItemIndex-1)
    else Matches.ItemIndex:=Min(Matches.Count-1,Matches.ItemIndex+1);
    Key:=0;
  end;
end;
end.
