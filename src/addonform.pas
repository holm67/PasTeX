unit AddonForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Grids, AddonModel;
type
  TAddonForm=class(TForm)
  private
    FCatalog:TEditorAddons;
    FCurrent:Integer;
    FUpdating:Boolean;
    FDocument,FSelection:string;
    FDescription:TMemo;
    FBuildEnabled:TCheckBox;
    FPackageGroup:TGroupBox;
    FDetect:TButton;
    FPackageHint:TLabel;
    FOriginalStylePath,FOriginalExecutable:string;
    FDetail:TScrollBox;
    FEmpty:TLabel;
    procedure SelectAddon(Sender:TObject; ACol,ARow:Integer; var CanSelect:Boolean);
    procedure CheckAddon(Sender:TObject; ACol,ARow:Integer; State:TCheckboxState);
    procedure Store(ForceStyle:Boolean=False);
    procedure PathChanged(Sender:TObject);
    procedure BuildChanged(Sender:TObject);
    procedure Browse(Sender:TObject);
    procedure BrowseStyle(Sender:TObject);
    procedure DetectStyle(Sender:TObject);
    procedure Action(Sender:TObject);
    procedure RefreshList;
    procedure ShowDetails(Index:Integer);
  public
    Items:TStringGrid;
    Executable,StylePath:TEdit;
    InsertText:string;
    InsertAsTeX,InsertAsMath:Boolean;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(const Document,Selection:string);
    procedure SelectPlugin(const ID:string);
    procedure SetAddonState(Index:Integer; Installed,PluginEnabled:Boolean);
  end;
implementation
uses Dialogs, FPJSON, PluginRunner, UITheme, IniFiles, Math, UnicodeEdits, ImportForms, Themes, Types;
type
  TPluginGrid=class(TStringGrid)
  protected
    function EditingAllowed(ACol:Integer=-1):Boolean; override;
    procedure DrawCell(ACol,ARow:Integer; ARect:TRect; AState:TGridDrawState); override;
  end;
function TPluginGrid.EditingAllowed(ACol:Integer):Boolean;
begin
  if ACol<0 then ACol:=Col;
  Result:=inherited EditingAllowed(ACol);
  if (ACol=2) and (Row>0) and (Cells[1,Row]<>'1') then Result:=False;
end;
procedure TPluginGrid.DrawCell(ACol,ARow:Integer; ARect:TRect; AState:TGridDrawState);
var Details:TThemedElementDetails; Size:TSize;
begin
  if (ACol<>2) or (ARow<1) or (Cells[1,ARow]='1') then begin inherited; Exit; end;
  Canvas.Brush.Color:=Color; Canvas.FillRect(ARect);
  Details:=ThemeServices.GetElementDetails(tbCheckBoxUncheckedDisabled);
  Size:=ThemeServices.GetDetailSize(Details);
  ARect:=Bounds(ARect.Left+(ARect.Width-Size.CX) div 2,ARect.Top+(ARect.Height-Size.CY) div 2,Size.CX,Size.CY);
  ThemeServices.DrawElement(Canvas.Handle,Details,ARect);
end;
constructor TAddonForm.Create(AOwner:TComponent);
var Detail:TScrollBox; Row,Footer,ExecutableRow:TPanel; Split:TSplitter; L:TLabel; B:TButton; I:Integer;
begin
  inherited CreateNew(AOwner); Caption:='PasTeX plug-ins'; Position:=poOwnerFormCenter; ClientWidth:=980; ClientHeight:=560;
  Constraints.MinWidth:=800; Constraints.MinHeight:=440; FCatalog:=TEditorAddons.Create(True); FCurrent:=-1;
  Footer:=TPanel.Create(Self); Footer.Parent:=Self; Footer.Align:=alBottom; Footer.Height:=44; Footer.BevelOuter:=bvNone;
  for I:=3 downto 0 do begin
    B:=TButton.Create(Self); B.Parent:=Footer; B.Left:=Footer.ClientWidth; B.Align:=alLeft; B.AutoSize:=True; B.BorderSpacing.Around:=5; B.Tag:=I; B.OnClick:=@Action;
    case I of 0:B.Caption:='Run'; 1:B.Caption:='Install plug-in file…'; 2:B.Caption:='Save configuration'; 3:begin B.Caption:='Close'; B.ModalResult:=mrClose; end; end;
  end;
  Items:=TPluginGrid.Create(Self); Items.Name:='PluginChecklist'; Items.Parent:=Self; Items.Align:=alLeft; Items.Width:=430; Items.BorderSpacing.Around:=8;
  Items.FixedCols:=0; Items.FixedRows:=1; Items.RowCount:=2; Items.DefaultRowHeight:=32; Items.Options:=Items.Options+[goEditing,goColSizing]-[goRangeSelect];
  Items.Columns.Clear;
  for I:=0 to 2 do with Items.Columns.Add do begin
    case I of 0:begin Title.Caption:='Plug-in'; Width:=230; ReadOnly:=True; end;
      1:begin Title.Caption:='Installed'; Width:=82; end; 2:begin Title.Caption:='Enabled'; Width:=82; end; end;
    if I>0 then begin ButtonStyle:=cbsCheckboxColumn; ValueChecked:='1'; ValueUnchecked:='0'; end;
  end;
  Items.OnSelectCell:=@SelectAddon; Items.OnCheckboxToggled:=@CheckAddon;
  Items.AutoFillColumns:=True;
  Split:=TSplitter.Create(Self); Split.Parent:=Self; Split.Align:=alLeft; Split.Width:=6;
  Detail:=TScrollBox.Create(Self); Detail.Parent:=Self; Detail.Align:=alClient; Detail.BorderSpacing.Around:=12; Detail.BorderStyle:=bsNone; Detail.HorzScrollBar.Visible:=False;
  FDetail:=Detail; Detail.Name:='PluginDetails';
  FEmpty:=TLabel.Create(Self); FEmpty.Parent:=Self; FEmpty.Align:=alClient; FEmpty.AutoSize:=False;
  FEmpty.Name:='PluginEmptyState'; FEmpty.WordWrap:=True; FEmpty.BorderSpacing.Around:=12; FEmpty.Visible:=False;
  Detail.DisableAlign;
  L:=TLabel.Create(Self); L.Parent:=Detail; L.Align:=alTop; L.Caption:='Executable (program name or full path)'; L.BorderSpacing.Bottom:=6;
  Row:=TPanel.Create(Self); Row.Parent:=Detail; Row.Top:=10000; Row.Align:=alTop; Row.Height:=34; Row.BevelOuter:=bvNone; Row.BorderSpacing.Bottom:=12;
  ExecutableRow:=Row;
  B:=TButton.Create(Self); B.Parent:=Row; B.Align:=alRight; B.Width:=36; B.Caption:='…'; B.Hint:='Browse for executable'; B.ShowHint:=True; B.OnClick:=@Browse;
  Executable:=TUnicodeEdit.Create(Self); Executable.Name:='PluginExecutable'; Executable.Parent:=Row; Executable.Align:=alClient; Executable.BorderSpacing.Right:=6; Executable.OnExit:=@PathChanged;
  FBuildEnabled:=TCheckBox.Create(Self); FBuildEnabled.Parent:=Detail; FBuildEnabled.Top:=10000; FBuildEnabled.Align:=alTop;
  FBuildEnabled.Caption:='Enable document compilation steps'; FBuildEnabled.AutoSize:=True; FBuildEnabled.BorderSpacing.Bottom:=12; FBuildEnabled.OnClick:=@BuildChanged;
  FPackageGroup:=TGroupBox.Create(Self); FPackageGroup.Parent:=Detail; FPackageGroup.Top:=10000; FPackageGroup.Align:=alTop;
  FPackageGroup.Height:=148; FPackageGroup.BorderSpacing.Bottom:=12; FPackageGroup.DisableAlign;
  Row:=TPanel.Create(Self); Row.Parent:=FPackageGroup; Row.Align:=alTop; Row.Height:=34; Row.BevelOuter:=bvNone; Row.BorderSpacing.Around:=5;
  B:=TButton.Create(Self); B.Parent:=Row; B.Align:=alRight; B.Width:=36; B.Caption:='…'; B.Hint:='Browse for style directory'; B.ShowHint:=True; B.OnClick:=@BrowseStyle;
  StylePath:=TUnicodeEdit.Create(Self); StylePath.Name:='PluginStylePath'; StylePath.Parent:=Row; StylePath.Align:=alClient; StylePath.OnExit:=@PathChanged;
  FPackageHint:=TLabel.Create(Self); FPackageHint.Parent:=FPackageGroup; FPackageHint.Top:=10000; FPackageHint.Align:=alTop;
  FPackageHint.AutoSize:=False; FPackageHint.WordWrap:=True; FPackageHint.Height:=34; FPackageHint.BorderSpacing.Left:=5;
  FDetect:=TButton.Create(Self); FDetect.Name:='DetectPluginStyle'; FDetect.Parent:=FPackageGroup; FDetect.Top:=10000; FDetect.Align:=alTop;
  FDetect.Height:=30; FDetect.BorderSpacing.Around:=5; FDetect.OnClick:=@DetectStyle;
  Row.Top:=0; FDetect.Top:=40; FPackageHint.Top:=80; FPackageGroup.EnableAlign;
  FDescription:=TMemo.Create(Self); FDescription.Parent:=Detail; FDescription.Align:=alClient; FDescription.ReadOnly:=True;
  FDescription.WordWrap:=True; FDescription.ScrollBars:=ssAutoVertical; FDescription.BorderStyle:=bsNone;
  L.Top:=0; ExecutableRow.Top:=30; FBuildEnabled.Top:=80; FPackageGroup.Top:=120; Detail.EnableAlign;
  ApplyTheme(Self);
end;
destructor TAddonForm.Destroy;
begin FUpdating:=True; FCatalog.Free; inherited; end;
procedure TAddonForm.RefreshList;
var I:Integer; A:TEditorAddon;
begin
  FUpdating:=True;
  try
    FCurrent:=-1; Items.RowCount:=Max(2,FCatalog.Count+1);
    for I:=0 to FCatalog.Count-1 do begin
      A:=TEditorAddon(FCatalog[I]); Items.Cells[0,I+1]:=A.Name;
      Items.Cells[1,I+1]:=IntToStr(Ord(A.Installed)); Items.Cells[2,I+1]:=IntToStr(Ord(A.Installed and A.Enabled));
    end;
  finally FUpdating:=False; end;
  FEmpty.Visible:=FCatalog.Count=0;
  if FCatalog.Count>0 then begin Items.Row:=1; ShowDetails(0); end
  else begin
    FDetail.Visible:=False;
    FEmpty.Caption:='No plug-ins installed. Choose Install plug-in file to add a compiled module.'+LineEnding+FCatalog.Warning;
  end;
  if FCatalog.Warning<>'' then FDescription.Lines.Add(FCatalog.Warning);
end;
procedure TAddonForm.Load(const Document,Selection:string);
begin FDocument:=Document; FSelection:=Selection; FCatalog.Load; RefreshList; end;
procedure TAddonForm.SelectPlugin(const ID:string);
var I:Integer;
begin
  for I:=0 to FCatalog.Count-1 do if TEditorAddon(FCatalog[I]).ID=ID then begin
    Items.Row:=I+1; ShowDetails(I); Exit;
  end;
end;
procedure TAddonForm.Store(ForceStyle:Boolean);
var A:TEditorAddon; Ini:TIniFile; Value:string;
begin
  if FUpdating or (FCurrent<0) or (FCurrent>=FCatalog.Count) then Exit;
  A:=TEditorAddon(FCatalog[FCurrent]); if not A.Installed then Exit;
  if Trim(Executable.Text)<>FOriginalExecutable then begin
    A.Executable:=Trim(Executable.Text); FCatalog.Save; FOriginalExecutable:=A.Executable;
  end;
  if FPackageGroup.Visible then begin
    Value:=Trim(StylePath.Text);
    if (Value<>FOriginalStylePath) or ForceStyle then begin
      Ini:=TIniFile.Create(GetAppConfigFile(False));
      try Ini.WriteString('Plugin.'+A.ID,'CompileTexInputs',Value); finally Ini.Free; end;
      CacheExtensionPath(A.ID,A.Executable,Value); FOriginalStylePath:=Value;
    end;
  end;
end;
procedure TAddonForm.PathChanged(Sender:TObject);
begin Store; end;
procedure TAddonForm.BuildChanged(Sender:TObject);
var Ini:TIniFile; A:TEditorAddon;
begin
  if FUpdating or (FCurrent<0) then Exit; A:=TEditorAddon(FCatalog[FCurrent]); ForceDirectories(GetAppConfigDir(False));
  Ini:=TIniFile.Create(GetAppConfigFile(False));
  try Ini.WriteBool('Plugin.'+A.ID,'CompileEnabled',FBuildEnabled.Checked);
    if FBuildEnabled.Checked then Ini.WriteBool('Compiler','ExtensionSteps',True);
  finally Ini.Free; end;
end;
procedure TAddonForm.ShowDetails(Index:Integer);
var A:TEditorAddon; Ini:TIniFile; Hook,Prepare:TJSONObject;
begin
  if (Index<0) or (Index>=FCatalog.Count) then Exit; Store; FCurrent:=Index; A:=TEditorAddon(FCatalog[Index]); FUpdating:=True;
  try
    FDetail.Visible:=A.Installed;
    Executable.Text:=A.Executable; FOriginalExecutable:=A.Executable;
    FDescription.Text:=A.Name+LineEnding+LineEnding+A.Description+LineEnding+LineEnding+'Module: '+A.ManifestPath+LineEnding+'ABI: '+IntToStr(PluginABI);
    FDescription.Hint:=A.ManifestPath; FBuildEnabled.Visible:=A.Manifest.Find('compileHook') is TJSONObject;
    Hook:=nil; Prepare:=nil; if FBuildEnabled.Visible then Hook:=A.Manifest.Objects['compileHook'];
    if (Hook<>nil) and (Hook.Find('prepare') is TJSONObject) then Prepare:=Hook.Objects['prepare'];
    FPackageGroup.Visible:=Prepare<>nil;
    Ini:=TIniFile.Create(GetAppConfigFile(False));
    try
      FBuildEnabled.Checked:=Ini.ReadBool('Plugin.'+A.ID,'CompileEnabled',True);
      StylePath.Text:=Ini.ReadString('Plugin.'+A.ID,'CompileTexInputs','');
    finally Ini.Free; end;
    if (StylePath.Text='') and (Prepare<>nil) then begin
      StylePath.Text:=CachedExtensionPath(A.ID,A.Executable);
      if StylePath.Text='' then StylePath.Text:=Hook.Get('texInputs','');
    end;
    FOriginalStylePath:=StylePath.Text;
    if Prepare<>nil then begin
      FPackageGroup.Caption:=A.Manifest.Get('packagePathTitle','Package style directory');
      FPackageHint.Caption:='Folder containing '+Prepare.Get('styleFile','package styles')+'. Blank uses automatic discovery.';
    end;
    FDetect.Visible:=(A.Manifest.Find('configurationActions') is TJSONArray) and (A.Manifest.Arrays['configurationActions'].Count>0);
    if FDetect.Visible then begin
      FDetect.Caption:=A.Manifest.Arrays['configurationActions'].Objects[0].Get('title','Detect directory');
      FDetect.Hint:=A.Manifest.Arrays['configurationActions'].Objects[0].Get('id','');
      FDetect.Enabled:=A.Installed and A.Enabled;
    end;
  finally FUpdating:=False; end;
end;
procedure TAddonForm.BrowseStyle(Sender:TObject);
var D:TSelectDirectoryDialog;
begin
  D:=TSelectDirectoryDialog.Create(Self);
  try D.FileName:=StylePath.Text; if D.Execute then begin StylePath.Text:=D.FileName; Store; end;
  finally D.Free; end;
end;
procedure TAddonForm.DetectStyle(Sender:TObject);
var Values,Response:TJSONObject; A:TEditorAddon;
begin
  if (FCurrent<0) or ToolJobBusy then Exit; Store; A:=TEditorAddon(FCatalog[FCurrent]);
  Values:=TJSONObject.Create(['document',FDocument,'directory',ExtractFileDir(FDocument)]); Response:=nil;
  try
    try
      Response:=RunPluginAction(Self,A,FDetect.Hint,Values);
      if (Response<>nil) and (Response.Get('texInputs','')<>'') then begin
        StylePath.Text:=Response.Get('texInputs',''); Store(True);
        FPackageHint.Caption:='Directory detected. Edit the path or Browse to change it.';
      end;
    except on E:Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
  finally Response.Free; Values.Free; end;
end;
procedure TAddonForm.SelectAddon(Sender:TObject; ACol,ARow:Integer; var CanSelect:Boolean);
begin if not FUpdating and (ARow>0) then ShowDetails(ARow-1); end;
procedure TAddonForm.SetAddonState(Index:Integer; Installed,PluginEnabled:Boolean);
var A:TEditorAddon;
begin
  if (Index<0) or (Index>=FCatalog.Count) then Exit; Store; A:=TEditorAddon(FCatalog[Index]);
  if Installed and not FileExists(A.ManifestPath) then raise Exception.Create('Reinstall this module with Install plug-in file.');
  if not Installed then FCatalog.RemoveAddon(Index)
  else begin A.Installed:=True; A.Enabled:=PluginEnabled; if not PluginEnabled then A.Unload; end;
  FCatalog.Save; FUpdating:=True;
  try Items.Cells[1,Index+1]:=IntToStr(Ord(A.Installed)); Items.Cells[2,Index+1]:=IntToStr(Ord(A.Installed and A.Enabled));
  finally FUpdating:=False; end;
  ShowDetails(Index); Items.Invalidate;
end;
procedure TAddonForm.CheckAddon(Sender:TObject; ACol,ARow:Integer; State:TCheckboxState);
var A:TEditorAddon; Installed,PluginEnabled:Boolean;
begin
  if FUpdating or (ARow<1) or (ARow>FCatalog.Count) then Exit; A:=TEditorAddon(FCatalog[ARow-1]);
  Installed:=A.Installed; PluginEnabled:=A.Enabled;
  if ACol=1 then begin Installed:=State=cbChecked; if not Installed then PluginEnabled:=False; end
  else if ACol=2 then begin
    if not Installed then begin Items.Cells[2,ARow]:='0'; Exit; end;
    PluginEnabled:=State=cbChecked;
  end else Exit;
  try SetAddonState(ARow-1,Installed,PluginEnabled);
  except on E:Exception do begin Items.Cells[ACol,ARow]:=IntToStr(Ord(A.Installed and ((ACol=1) or A.Enabled))); MessageDlg(E.Message,mtError,[mbOK],0); end; end;
end;
procedure TAddonForm.Browse(Sender:TObject);
var D:TOpenDialog;
begin
  D:=TOpenDialog.Create(Self);
  try D.Filter:='Programs|*'; D.FileName:=Executable.Text; if D.Execute then begin Executable.Text:=D.FileName; Store; end;
  finally D.Free; end;
end;
procedure TAddonForm.Action(Sender:TObject);
var ID:Integer; A:TEditorAddon; D:TOpenDialog; Context,Response:TJSONObject; Directory,ActionID:string;
begin
  Store; ID:=TComponent(Sender).Tag;
  try
    if ID=1 then begin
      D:=TOpenDialog.Create(Self); try D.Filter:='PasTeX plug-in|*'+PluginExtension;
        if D.Execute then begin FCatalog.InstallFile(D.FileName); RefreshList; end;
      finally D.Free; end; Exit;
    end;
    if (FCurrent<0) or (ID<>0) then Exit; A:=TEditorAddon(FCatalog[FCurrent]);
    Directory:=ExtractFileDir(FDocument); if Directory='' then Directory:=GetCurrentDir;
    Context:=TJSONObject.Create(['document',FDocument,'directory',Directory,'selection',FSelection,'code',FSelection,'math',FSelection]);
    try
      if A.Manifest.Arrays['actions'].Count=0 then Exit; ActionID:=A.Manifest.Arrays['actions'].Objects[0].Get('id','run');
      Response:=RunPluginAction(Self,A,ActionID,Context);
      try
        if Response=nil then Exit; InsertText:=Response.Get('text',''); InsertAsTeX:=Response.Get('format','plain')<>'plain'; InsertAsMath:=Response.Get('format','plain')='math';
        if InsertText<>'' then ModalResult:=mrOK;
      finally Response.Free; end;
    finally Context.Free; end;
  except on E:Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
end;
end.
