unit QuickAccessForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, UITheme;
const QuickActionNames:array[0..6] of string=('Save','Undo and history','Redo and history','New','Open','Preview','Settings');
type TQuickAccessForm=class(TForm)
  private
    FKeys,FOrder:TStringList;
    procedure Action(Sender:TObject);
    procedure RefreshItems(SelectionIndex:Integer);
  public
    Items:TListBox;
    Available:TComboBox;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure AddCommand(const Key,Title:string);
    procedure LoadOrder(Order:TStrings);
    procedure GetOrder(Order:TStrings);
  end;
implementation
{$IFDEF LCLgtk3}
uses Gtk3Widgets, LazGtk3, LazGObject2;
{$ENDIF}
constructor TQuickAccessForm.Create(AOwner:TComponent);
var B:TButton; L:TLabel; I:Integer;
const Actions:array[0..3] of string=('Add','Delete','Move up','Move down');
begin
  inherited CreateNew(AOwner); Caption:='Customize quick access toolbar'; Position:=poMainFormCenter; BorderStyle:=bsDialog;
  ClientWidth:=640; ClientHeight:=340; FKeys:=TStringList.Create; FOrder:=TStringList.Create;
  L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(16,12,608,20); L.Caption:='Choose commands and their order';
  Available:=TComboBox.Create(Self); Available.Parent:=Self; Available.SetBounds(16,38,496,30); Available.Style:=csDropDownList;
  for I:=0 to High(QuickActionNames) do AddCommand(IntToStr(I),QuickActionNames[I]); Available.ItemIndex:=0;
  Items:=TListBox.Create(Self); Items.Parent:=Self; Items.SetBounds(16,82,496,194);
  for I:=0 to High(Actions) do begin
    B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(524,38+I*52,100,30); B.Caption:=Actions[I]; B.Tag:=I; B.OnClick:=@Action;
  end;
  B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(432,296,92,30); B.Caption:='Apply'; B.ModalResult:=mrOK; B.Default:=True;
  B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(532,296,92,30); B.Caption:='Cancel'; B.ModalResult:=mrCancel; B.Cancel:=True;
  ApplyTheme(Self);
end;
destructor TQuickAccessForm.Destroy;
begin inherited Destroy; FOrder.Free; FKeys.Free; end;
procedure TQuickAccessForm.AddCommand(const Key,Title:string);
begin if FKeys.IndexOf(Key)>=0 then Exit; FKeys.Add(Key); Available.Items.Add(Title); end;
procedure TQuickAccessForm.RefreshItems(SelectionIndex:Integer);
var Captions:TStringList; Key:string;
    {$IFDEF LCLgtk3}View:PGtkTreeView; Model:PGtkTreeModel;{$ENDIF}
begin
  Captions:=TStringList.Create;
  {$IFDEF LCLgtk3}
  View:=nil; Model:=nil;
  if Items.HandleAllocated then begin
    View:=PGtkTreeView(TGtk3ListBox(Items.Handle).GetContainerWidget); Model:=gtk_tree_view_get_model(View);
    if Model<>nil then begin
      { GTK3 LCL measures rows during Clear/Move using cached iterators.
        Retain the store and detach the view until the replacement is complete. }
      g_object_ref(PGObject(Model)); gtk_tree_view_set_model(View,nil);
    end;
  end;
  {$ENDIF}
  try
    for Key in FOrder do Captions.Add(Available.Items[FKeys.IndexOf(Key)]);
    Items.Items.Assign(Captions);
  finally
    {$IFDEF LCLgtk3}
    if Model<>nil then begin gtk_tree_view_set_model(View,Model); g_object_unref(PGObject(Model)); end;
    {$ENDIF}
    Captions.Free;
  end;
  if SelectionIndex>=Items.Count then SelectionIndex:=Items.Count-1;
  Items.ItemIndex:=SelectionIndex;
end;
procedure TQuickAccessForm.LoadOrder(Order:TStrings);
var Key:string;
begin
  FOrder.Clear;
  for Key in Order do if (FKeys.IndexOf(Key)>=0) and (FOrder.IndexOf(Key)<0) then FOrder.Add(Key);
  RefreshItems(0);
end;
procedure TQuickAccessForm.GetOrder(Order:TStrings);
begin Order.Assign(FOrder); end;
procedure TQuickAccessForm.Action(Sender:TObject);
var I,J:Integer;
begin
  I:=Items.ItemIndex;
  case TComponent(Sender).Tag of
    0:begin
      J:=Available.ItemIndex; if J<0 then Exit;
      I:=FOrder.IndexOf(FKeys[J]);
      if I<0 then I:=FOrder.Add(FKeys[J]);
    end;
    1:begin if I<0 then Exit; FOrder.Delete(I); if I>=FOrder.Count then Dec(I); end;
    2:if I>0 then begin FOrder.Move(I,I-1); Dec(I); end;
    3:if (I>=0) and (I<FOrder.Count-1) then begin FOrder.Move(I,I+1); Inc(I); end;
  end;
  RefreshItems(I);
end;
end.
