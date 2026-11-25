unit TeXOptionsEditor;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Controls, StdCtrls, ExtCtrls;
type
  TTeXOptionsEditor=class(TPanel)
  private
    FOptions:TStringList;
    FText:string;
    FUpdating:Boolean;
    FChange:TNotifyEvent;
    FNameLabel:TLabel;
    procedure SetText(const Value:string);
    procedure Selected(Sender:TObject);
    procedure SelectionChanged(Sender:TObject; User:Boolean);
    procedure Edited(Sender:TObject);
    procedure Action(Sender:TObject);
    procedure Changed;
    procedure LayoutControls(Sender:TObject);
  public
    OptionsList:TListBox;
    OptionName,OptionValue:TEdit;
    HasValue:TCheckBox;
    AddButton,DeleteButton,UpButton,DownButton:TButton;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    property Text:string read FText write SetText;
    property OnChange:TNotifyEvent read FChange write FChange;
  end;
implementation
uses UnicodeEdits, Math, TeXMacros;
function OptionCaption(const Value:string):string;
begin Result:=Trim(Value); if Result='' then Result:='(new option)'; end;
constructor TTeXOptionsEditor.Create(AOwner:TComponent);
  function Button(const Title:string; TagValue:Integer):TButton;
  begin
    Result:=TButton.Create(Self); Result.Parent:=Self; Result.Caption:=Title; Result.Tag:=TagValue;
    Result.OnClick:=@Action;
  end;
begin
  inherited Create(AOwner); BevelOuter:=bvNone; Caption:=''; FOptions:=TStringList.Create;
  OptionsList:=TListBox.Create(Self); OptionsList.Parent:=Self;
  {$IFDEF LCLgtk3}
  { Native cell text callbacks can read stale iterators while replacing rows. }
  OptionsList.Style:=lbOwnerDrawFixed; OptionsList.ItemHeight:=24;
  {$ENDIF}
  OptionsList.OnClick:=@Selected; OptionsList.OnSelectionChange:=@SelectionChanged;
  AddButton:=Button('Add',0); DeleteButton:=Button('Delete',1);
  UpButton:=Button('Move up',2); DownButton:=Button('Move down',3);
  FNameLabel:=TLabel.Create(Self); FNameLabel.Parent:=Self; FNameLabel.Caption:='Option name';
  OptionName:=TUnicodeEdit.Create(Self); OptionName.Parent:=Self; OptionName.OnChange:=@Edited;
  HasValue:=TCheckBox.Create(Self); HasValue.Parent:=Self; HasValue.Caption:='Key / value'; HasValue.OnChange:=@Edited;
  OptionValue:=TUnicodeEdit.Create(Self); OptionValue.Parent:=Self; OptionValue.OnChange:=@Edited;
  OptionName.Hint:='A plain option such as a4paper, or a key such as margin'; OptionName.ShowHint:=True;
  OptionValue.Hint:='The value after =, such as 2cm or {red,green,blue}'; OptionValue.ShowHint:=True;
  SetBounds(0,0,560,260); OnResize:=@LayoutControls; LayoutControls(nil); Selected(nil);
end;
destructor TTeXOptionsEditor.Destroy;
begin FUpdating:=True; FChange:=nil; FOptions.Free; inherited Destroy; end;
procedure TTeXOptionsEditor.LayoutControls(Sender:TObject);
var ListWidth,FieldLeft,FieldWidth:Integer;
begin
  ListWidth:=Max(100,Round(ClientWidth*0.4)); FieldLeft:=ListWidth+108; FieldWidth:=Max(80,ClientWidth-FieldLeft-8);
  OptionsList.SetBounds(0,0,ListWidth,Max(160,ClientHeight));
  AddButton.SetBounds(ListWidth+8,0,92,32); DeleteButton.SetBounds(ListWidth+8,40,92,32);
  UpButton.SetBounds(ListWidth+8,80,92,32); DownButton.SetBounds(ListWidth+8,120,92,32);
  FNameLabel.SetBounds(FieldLeft,2,FieldWidth,20); OptionName.SetBounds(FieldLeft,28,FieldWidth,30);
  HasValue.SetBounds(FieldLeft,72,FieldWidth,24); OptionValue.SetBounds(FieldLeft,106,FieldWidth,30);
end;
procedure TTeXOptionsEditor.SetText(const Value:string);
var P,A:Integer;
begin
  FUpdating:=True; OptionsList.Items.BeginUpdate;
  try
    FText:=Value; FOptions.Clear; OptionsList.Items.Clear; A:=1;
    while A<=Length(Value) do begin
      P:=TopLevelDelimiter(Value,',',A); if P=0 then P:=Length(Value)+1;
      FOptions.Add(Copy(Value,A,P-A)); OptionsList.Items.Add(OptionCaption(FOptions[FOptions.Count-1])); A:=P+1;
    end;
    if OptionsList.Count>0 then OptionsList.ItemIndex:=0;
  finally OptionsList.Items.EndUpdate; FUpdating:=False; end;
  Selected(nil); if Assigned(FChange) then FChange(Self);
end;
procedure TTeXOptionsEditor.Selected(Sender:TObject);
var I,P:Integer; Value:string;
begin
  if FUpdating then Exit; FUpdating:=True;
  try
    I:=OptionsList.ItemIndex; if I>=FOptions.Count then begin I:=-1; OptionsList.ItemIndex:=-1; end;
    Value:=''; if I>=0 then Value:=Trim(FOptions[I]);
    P:=TopLevelDelimiter(Value,'='); HasValue.Checked:=P>0;
    if P>0 then begin OptionName.Text:=Trim(Copy(Value,1,P-1)); OptionValue.Text:=Trim(Copy(Value,P+1,MaxInt)); end
    else begin OptionName.Text:=Value; OptionValue.Text:=''; end;
    OptionName.Enabled:=I>=0; HasValue.Enabled:=I>=0; OptionValue.Enabled:=(I>=0) and HasValue.Checked;
    DeleteButton.Enabled:=I>=0; UpButton.Enabled:=I>0; DownButton.Enabled:=(I>=0) and (I<FOptions.Count-1);
    if HasValue.Checked then FNameLabel.Caption:='Key' else FNameLabel.Caption:='Option name';
  finally FUpdating:=False; end;
end;
procedure TTeXOptionsEditor.SelectionChanged(Sender:TObject; User:Boolean);
begin Selected(Sender); end;
procedure TTeXOptionsEditor.Changed;
var Value:string;
begin
  FText:='';
  for Value in FOptions do if Trim(Value)<>'' then begin
    if FText<>'' then FText:=FText+','; FText:=FText+Value;
  end;
  if Assigned(FChange) then FChange(Self);
end;
procedure TTeXOptionsEditor.Edited(Sender:TObject);
var I:Integer; Value:string;
begin
  if FUpdating then Exit; I:=OptionsList.ItemIndex; if (I<0) or (I>=FOptions.Count) then Exit;
  Value:=Trim(OptionName.Text); if HasValue.Checked and (Value<>'') then Value:=Value+'='+OptionValue.Text;
  FUpdating:=True;
  try FOptions[I]:=Value; OptionsList.Items[I]:=OptionCaption(Value);
  finally FUpdating:=False; end;
  OptionValue.Enabled:=HasValue.Checked;
  if HasValue.Checked then FNameLabel.Caption:='Key' else FNameLabel.Caption:='Option name';
  Changed;
end;
procedure TTeXOptionsEditor.Action(Sender:TObject);
var I,J:Integer;
begin
  I:=OptionsList.ItemIndex; FUpdating:=True;
  try
    case TComponent(Sender).Tag of
      0:begin I:=FOptions.Add(''); OptionsList.Items.Add('(new option)'); end;
      1:if I>=0 then begin FOptions.Delete(I); OptionsList.Items.Delete(I); I:=Min(I,FOptions.Count-1); end;
      2,3:begin
        J:=I+IfThen(TComponent(Sender).Tag=2,-1,1);
        if (I>=0) and (J>=0) and (J<FOptions.Count) then begin FOptions.Exchange(I,J); OptionsList.Items.Exchange(I,J); I:=J; end;
      end;
    end;
    OptionsList.ItemIndex:=I;
  finally FUpdating:=False; end;
  Selected(nil); Changed; if (TComponent(Sender).Tag=0) and OptionName.CanFocus then OptionName.SetFocus;
end;
end.
