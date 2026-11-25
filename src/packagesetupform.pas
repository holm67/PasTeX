unit PackageSetupForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Contnrs, Forms, Controls, StdCtrls, ExtCtrls, TeXOptionsEditor, TeXPreambleCommands;
type
  TPackageSetupForm=class(TForm)
  private
    FItems:TObjectList;
    FPreamble,FCommand,FOriginal,FDirectory:string;
    FUpdating,FResources:Boolean;
    procedure ResourceSelected(Sender:TObject);
    procedure ResourceSelectionChanged(Sender:TObject; User:Boolean);
    procedure ResourceChanged(Sender:TObject);
    procedure ResourceAction(Sender:TObject);
    procedure BrowseResource(Sender:TObject);
    function Commands:string;
  public
    ResourceList:TListBox;
    ResourceFile:TEdit;
    Options:TTeXOptionsEditor;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(const PackageName,Preamble,Directory:string);
    function Source:string;
  end;
function PackageSetupCommand(const PackageName:string):string;
implementation
uses UnicodeEdits, Math, Dialogs, UITheme;
function PackageSetupCommand(const PackageName:string):string;
begin
  case PackageName of
    'biblatex':Result:='addbibresource'; 'hyperref':Result:='hypersetup';
    'geometry':Result:='geometry'; 'siunitx':Result:='sisetup';
    'pgfplots':Result:='pgfplotsset'; 'tikz':Result:='tikzset';
    else Result:='';
  end;
end;
constructor TPackageSetupForm.Create(AOwner:TComponent);
begin inherited CreateNew(AOwner); FItems:=TObjectList.Create(True); end;
destructor TPackageSetupForm.Destroy;
begin FItems.Free; inherited Destroy; end;
procedure TPackageSetupForm.Load(const PackageName,Preamble,Directory:string);
var LabelControl:TLabel; B:TButton; I:Integer; Item:TPreambleCommand; Value:string;
  procedure LabelAt(const Title:string; X,Y:Integer);
  begin LabelControl:=TLabel.Create(Self); LabelControl.Parent:=Self; LabelControl.Caption:=Title; LabelControl.SetBounds(X,Y,400,20); end;
begin
  FPreamble:=Preamble; FDirectory:=Directory; FCommand:=PackageSetupCommand(PackageName); FResources:=PackageName='biblatex';
  if FCommand='' then raise Exception.Create('No setup editor is defined for this package.');
  Caption:=PackageName+' setup'; Position:=poMainFormCenter; BorderStyle:=bsDialog;
  ClientWidth:=884; ClientHeight:=412; PreambleCommands(Preamble,FCommand,FItems);
  if FResources then begin
    LabelAt('Bibliography resource files',16,14);
    ResourceList:=TListBox.Create(Self); ResourceList.Parent:=Self; ResourceList.SetBounds(16,42,208,308);
    ResourceList.OnClick:=@ResourceSelected; ResourceList.OnSelectionChange:=@ResourceSelectionChanged;
    for I:=0 to 3 do begin
      B:=TButton.Create(Self); B.Parent:=Self; B.Tag:=I; B.SetBounds(234,42+I*42,92,32);
      case I of 0:B.Caption:='Add'; 1:B.Caption:='Delete'; 2:B.Caption:='Move up'; 3:B.Caption:='Move down'; end;
      B.OnClick:=@ResourceAction;
    end;
    LabelAt('Database file or URL',344,14); LabelAt('Resource options',344,100);
    ResourceFile:=TUnicodeEdit.Create(Self); ResourceFile.Parent:=Self; ResourceFile.SetBounds(344,42,422,30); ResourceFile.OnChange:=@ResourceChanged;
    B:=TButton.Create(Self); B.Parent:=Self; B.Caption:='Browse…'; B.SetBounds(776,42,92,32); B.OnClick:=@BrowseResource;
    Options:=TTeXOptionsEditor.Create(Self); Options.Parent:=Self; Options.SetBounds(344,128,524,222); Options.OnChange:=@ResourceChanged;
    for I:=0 to FItems.Count-1 do ResourceList.Items.Add(TPreambleCommand(FItems[I]).Argument);
    if FItems.Count>0 then ResourceList.ItemIndex:=0; ResourceSelected(nil);
  end else begin
    LabelAt('\'+FCommand+' options',16,14);
    Options:=TTeXOptionsEditor.Create(Self); Options.Parent:=Self; Options.SetBounds(16,42,852,308);
    Value:='';
    for I:=0 to FItems.Count-1 do begin
      Item:=TPreambleCommand(FItems[I]); if Trim(Item.Argument)='' then Continue;
      if Value<>'' then Value:=Value+','; Value:=Value+Item.Argument;
    end;
    Options.Text:=Value;
  end;
  B:=TButton.Create(Self); B.Parent:=Self; B.Caption:='Apply'; B.SetBounds(676,368,92,32); B.ModalResult:=mrOK; B.Default:=True;
  B:=TButton.Create(Self); B.Parent:=Self; B.Caption:='Cancel'; B.SetBounds(776,368,92,32); B.ModalResult:=mrCancel; B.Cancel:=True;
  FOriginal:=Commands; ApplyTheme(Self);
end;
procedure TPackageSetupForm.ResourceSelected(Sender:TObject);
var I:Integer; Item:TPreambleCommand;
begin
  if FUpdating then Exit; I:=ResourceList.ItemIndex; if I>=FItems.Count then I:=-1; FUpdating:=True;
  try
    ResourceFile.Enabled:=I>=0; Options.Enabled:=I>=0;
    if I<0 then begin ResourceFile.Text:=''; Options.Text:=''; end
    else begin Item:=TPreambleCommand(FItems[I]); ResourceFile.Text:=Item.Argument; Options.Text:=Item.Options; end;
  finally FUpdating:=False; end;
end;
procedure TPackageSetupForm.ResourceSelectionChanged(Sender:TObject; User:Boolean);
begin ResourceSelected(Sender); end;
procedure TPackageSetupForm.ResourceChanged(Sender:TObject);
var I:Integer; Item:TPreambleCommand;
begin
  if FUpdating then Exit; I:=ResourceList.ItemIndex; if (I<0) or (I>=FItems.Count) then Exit;
  FUpdating:=True;
  try
    Item:=TPreambleCommand(FItems[I]); Item.Argument:=ResourceFile.Text; Item.Options:=Options.Text;
    Item.HasOptions:=Trim(Item.Options)<>''; ResourceList.Items[I]:=Item.Argument;
  finally FUpdating:=False; end;
end;
procedure TPackageSetupForm.ResourceAction(Sender:TObject);
var I,J:Integer;
begin
  I:=ResourceList.ItemIndex; FUpdating:=True;
  try
    case TComponent(Sender).Tag of
      0:begin I:=FItems.Add(TPreambleCommand.Create); ResourceList.Items.Add(''); end;
      1:if I>=0 then begin FItems.Delete(I); ResourceList.Items.Delete(I); I:=Min(I,FItems.Count-1); end;
      2,3:begin
        J:=I+IfThen(TComponent(Sender).Tag=2,-1,1);
        if (I>=0) and (J>=0) and (J<FItems.Count) then begin FItems.Exchange(I,J); ResourceList.Items.Exchange(I,J); I:=J; end;
      end;
    end;
    ResourceList.ItemIndex:=I;
  finally FUpdating:=False; end;
  ResourceSelected(nil); if ResourceFile.CanFocus then ResourceFile.SetFocus;
end;
procedure TPackageSetupForm.BrowseResource(Sender:TObject);
var D:TOpenDialog;
begin
  D:=TOpenDialog.Create(Self);
  try
    D.Filter:='Bibliography databases|*.bib|All files|*'; D.InitialDir:=FDirectory;
    if D.Execute then begin
      if ResourceList.ItemIndex<0 then begin
        D.Tag:=0; ResourceAction(D);
      end;
      if FDirectory='' then ResourceFile.Text:=StringReplace(D.FileName,'\','/',[rfReplaceAll])
      else ResourceFile.Text:=StringReplace(ExtractRelativePath(IncludeTrailingPathDelimiter(FDirectory),D.FileName),'\','/',[rfReplaceAll]);
    end;
  finally D.Free; end;
end;
function TPackageSetupForm.Commands:string;
var I:Integer; Item:TPreambleCommand;
begin
  Result:='';
  if not FResources then begin
    if Trim(Options.Text)<>'' then Result:='\'+FCommand+'{'+Options.Text+'}'; Exit;
  end;
  for I:=0 to FItems.Count-1 do begin
    Item:=TPreambleCommand(FItems[I]); if Trim(Item.Argument)='' then Continue;
    if Result<>'' then Result:=Result+LineEnding; Result:=Result+Item.Source(FCommand);
  end;
end;
function TPackageSetupForm.Source:string;
var Code:string;
begin
  Code:=Commands; if Code=FOriginal then Result:=FPreamble else Result:=ReplacePreambleCommands(FPreamble,FCommand,Code);
end;
end.
