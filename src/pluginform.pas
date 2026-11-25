unit PluginForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, FPJSON, AddonModel;
type
  TPluginForm=class(TForm)
  private
    FAddon:TEditorAddon;
    FContext,FView:TJSONObject;
    FPages:TPageControl;
    FLists:array of TListBox;
    FRows:array of TJSONArray;
    FFields:array of TEdit;
    FLog:TMemo;
    procedure Action(Sender:TObject);
    procedure Reload(Sender:TObject);
    function Values:TJSONObject;
  public
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(Addon:TEditorAddon; Definition,Context:TJSONObject);
  end;
implementation
uses SysUtils, Dialogs, Buttons, PluginRunner, UITheme;
constructor TPluginForm.Create(AOwner:TComponent);
var Split:TSplitter; Bar:TPanel; Button:TButton;
begin
  inherited CreateNew(AOwner); Position:=poOwnerFormCenter; ClientWidth:=1050; ClientHeight:=700;
  Constraints.MinWidth:=800; Constraints.MinHeight:=500;
  Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alTop; Bar.Height:=36; Bar.BevelOuter:=bvNone;
  Button:=TButton.Create(Self); Button.Parent:=Bar; Button.Caption:='Refresh'; Button.SetBounds(6,3,100,30); Button.OnClick:=@Reload;
  FLog:=TMemo.Create(Self); FLog.Parent:=Self; FLog.Align:=alBottom; FLog.Height:=210; FLog.ReadOnly:=True; FLog.ScrollBars:=ssAutoBoth;
  Split:=TSplitter.Create(Self); Split.Parent:=Self; Split.Align:=alBottom; Split.Height:=6;
  FPages:=TPageControl.Create(Self); FPages.Parent:=Self; FPages.Align:=alClient;
end;
destructor TPluginForm.Destroy;
var I:Integer;
begin for I:=0 to High(FRows) do FRows[I].Free; FView.Free; FContext.Free; inherited; end;
procedure TPluginForm.Load(Addon:TEditorAddon; Definition,Context:TJSONObject);
var I,J:Integer; Tab:TTabSheet; Bar:TPanel; Button:TButton; Input,Page,Command:TJSONObject; L:TLabel;
begin
  FAddon:=Addon; FView:=TJSONObject(Definition.Clone); FContext:=TJSONObject(Context.Clone); Caption:=FView.Get('title',Addon.Name);
  FContext.Strings['directory']:=FView.Get('directory',FContext.Get('directory',''));
  SetLength(FLists,FView.Arrays['tabs'].Count); SetLength(FRows,Length(FLists));
  if FView.Find('fields') is TJSONArray then begin
    Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alBottom; Bar.Height:=40; Bar.BevelOuter:=bvNone;
    SetLength(FFields,FView.Arrays['fields'].Count);
    for I:=0 to High(FFields) do begin
      Input:=FView.Arrays['fields'].Objects[I]; L:=TLabel.Create(Self); L.Parent:=Bar; L.Caption:=Input.Get('label',''); L.SetBounds(8,10,170,24);
      FFields[I]:=TEdit.Create(Self); FFields[I].Name:='PluginField_'+Input.Get('key','value'); FFields[I].Parent:=Bar; FFields[I].SetBounds(180,5,840,30); FFields[I].Anchors:=[akLeft,akTop,akRight];
    end;
  end;
  for I:=0 to High(FLists) do begin
    Page:=FView.Arrays['tabs'].Objects[I]; Tab:=TTabSheet.Create(Self); Tab.PageControl:=FPages; Tab.Caption:=Page.Get('title','');
    Bar:=TPanel.Create(Self); Bar.Parent:=Tab; Bar.Align:=alTop; Bar.Height:=38; Bar.BevelOuter:=bvNone;
    for J:=0 to Page.Arrays['actions'].Count-1 do begin
      Command:=Page.Arrays['actions'].Objects[J]; Button:=TButton.Create(Self); Button.Parent:=Bar; Button.Left:=Bar.ClientWidth;
      Button.Align:=alLeft; Button.AutoSize:=True; Button.BorderSpacing.Around:=4; Button.Caption:=Command.Get('title',''); Button.HelpKeyword:=Command.Get('id',''); Button.OnClick:=@Action;
    end;
    FLists[I]:=TListBox.Create(Self); FLists[I].Name:='PluginList_'+Page.Get('id',IntToStr(I)); FLists[I].Parent:=Tab; FLists[I].Align:=alClient;
    {$IFDEF LCLgtk3}FLists[I].Style:=lbOwnerDrawFixed; FLists[I].ItemHeight:=24;{$ENDIF}
  end;
  ApplyTheme(Self); Reload(nil);
end;
function TPluginForm.Values:TJSONObject;
var I,Index:Integer;
begin
  Result:=TJSONObject(FContext.Clone); Index:=FPages.ActivePageIndex;
  if (Index>=0) and (FLists[Index].ItemIndex>=0) then Result.Strings['value']:=FRows[Index].Objects[FLists[Index].ItemIndex].Get('id','');
  for I:=0 to High(FFields) do Result.Strings[FView.Arrays['fields'].Objects[I].Get('key','value')]:=FFields[I].Text;
end;
procedure TPluginForm.Reload(Sender:TObject);
var I,J:Integer; Context,Response:TJSONObject;
begin
  try
    for I:=0 to High(FLists) do begin
      Context:=Values;
      try Response:=RunPluginAction(Self,FAddon,'list:'+FView.Arrays['tabs'].Objects[I].Get('id',''),Context);
        try
          if Response=nil then Continue; FreeAndNil(FRows[I]); FRows[I]:=TJSONArray(Response.Arrays['rows'].Clone); FLists[I].Items.BeginUpdate;
          try FLists[I].Clear; for J:=0 to FRows[I].Count-1 do FLists[I].Items.Add(FRows[I].Objects[J].Get('text','')); if FLists[I].Count>0 then FLists[I].ItemIndex:=0;
          finally FLists[I].Items.EndUpdate; end;
        finally Response.Free; end;
      finally Context.Free; end;
    end;
  except on E:Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
end;
procedure TPluginForm.Action(Sender:TObject);
var Context,Response:TJSONObject;
begin
  Context:=Values;
  try
    try Response:=RunPluginAction(Self,FAddon,TControl(Sender).HelpKeyword,Context);
      try if Response=nil then Exit; FLog.Text:=Response.Get('output',''); if Response.Get('refresh',False) then Reload(nil);
      finally Response.Free; end;
    except on E:Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
  finally Context.Free; end;
end;
end.
