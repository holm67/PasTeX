{ SPDX-License-Identifier: GPL-3.0-or-later }
function TMainForm.PluginSourceActive:Boolean;
begin
  Result:=(FSessions<>nil) and (FSessionIndex>=0) and (FSessionIndex<FSessions.Count) and
    TOpenDocument(FSessions[FSessionIndex]).PluginSource;
end;
procedure TMainForm.ShowPluginSourceEditor;
begin
  if FPluginSourcePane=nil then begin
    FPluginSourcePane:=TPanel.Create(Self); FPluginSourcePane.Name:='PluginSourcePane'; FPluginSourcePane.Parent:=Self;
    FPluginSourcePane.Align:=alLeft; FPluginSourcePane.Width:=420; FPluginSourcePane.BevelOuter:=bvNone;
    FPluginSourcePane.Constraints.MinWidth:=180;
    FPluginSourceSplit:=TSplitter.Create(Self); FPluginSourceSplit.Parent:=Self; FPluginSourceSplit.Align:=alLeft; FPluginSourceSplit.Width:=6;
    FPluginSourceSplit.Name:='SourcePreviewDivider'; FPluginSourceSplit.Left:=FPluginSourcePane.Width;
    FPluginSourceSplit.MinSize:=180; FPluginSourceSplit.AutoSnap:=False; FPluginSourceSplit.ResizeStyle:=rsUpdate;
    FPluginSourceSplit.OnMoved:=@LayoutCards;
  end;
  FPluginSourceSplit.Left:=FPluginSourcePane.Left+FPluginSourcePane.Width;
  FPluginSourcePane.Visible:=True; FPluginSourceSplit.Visible:=True;
  if SourceTools<>nil then SourceTools.Visible:=False;
  if SourceGrip<>nil then SourceGrip.Visible:=False;
  FLoading:=True;
  try
    Editor.Parent:=FPluginSourcePane; Editor.Align:=alClient; Editor.Highlighter:=nil;
    if Editor.Text<>TOpenDocument(FSessions[FSessionIndex]).PluginText then begin
      Editor.Text:=TOpenDocument(FSessions[FSessionIndex]).PluginText; Editor.ClearUndo;
    end;
    Editor.Visible:=True; FormulaBox.Visible:=False; ActiveBlock:=-1; FPreambleEditing:=False;
    if FPreamblePanel<>nil then FPreamblePanel.Visible:=False;
    if FPreambleToggle<>nil then FPreambleToggle.Visible:=False;
    if FBodySeparator<>nil then FBodySeparator.Visible:=False;
  finally FLoading:=False; end;
  TMenuItem(FindComponent('ExportPluginTeXMenu')).Visible:=TOpenDocument(FSessions[FSessionIndex]).FormatID<>'';
  StatusText:=TOpenDocument(FSessions[FSessionIndex]).FormatName+' · edit source beside its native preview'; LayoutCards(nil);
end;
procedure TMainForm.RefreshPluginSource;
var SavedScroll:Integer; Preview,Error:string; S:TOpenDocument;
begin
  FPluginSourceDue:=0; if not PluginSourceActive then Exit;
  SavedScroll:=Scroll.VertScrollBar.Position;
  S:=TOpenDocument(FSessions[FSessionIndex]); S.PluginText:=Editor.Text;
  if S.FormatID='' then S.FormatID:=FindExtensionFormat(S.FileName);
  RenderExtensionDocument(S.FormatID,Editor.Text,DocumentDirectory,Preview,Error);
  Document.ParseFile(Preview); Inc(Revision);
  if FPagedView<>nil then begin FPagedView.Load(Document.Source,DocumentDirectory,'xelatex'); Exit; end;
  BuildCards; RefreshProjectContext; ShowPluginSourceEditor; QueuePreview;
  SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,SavedScroll);
  if Error<>'' then StatusText:=Error;
end;
procedure TMainForm.RefreshDocumentFormatMenus;
var Formats:TJSONArray; I:Integer; Info:TJSONObject; Group,Item:TMenuItem; ID:string;
begin
  if FFormatMenu=nil then Exit; FFormatMenu.Clear; Formats:=ExtensionDocumentFormats;
  try
    for I:=0 to Formats.Count-1 do begin
      Info:=Formats.Objects[I]; ID:=Info.Get('key','');
      Group:=TMenuItem.Create(Self); Group.Caption:=Info.Get('name','Source document'); FFormatMenu.Add(Group);
      Item:=TMenuItem.Create(Self); Item.Name:='FormatNew_'+StringReplace(ID,':','_',[rfReplaceAll]);
      Item.Caption:='New'; Item.Hint:=ID; Item.OnClick:=@NewPluginDocumentClick; Group.Add(Item);
      Item:=TMenuItem.Create(Self); Item.Caption:='Open…'; Item.Hint:=ID; Item.OnClick:=@OpenPluginDocumentClick; Group.Add(Item);
    end;
    FFormatMenu.Visible:=Formats.Count>0;
  finally Formats.Free; end;
end;
procedure TMainForm.OpenPluginSource(const Path:string; const FormatID:string);
var Session:TOpenDocument; Lines:TStringList; I:Integer; FullPath,ID,Preview,Error:string; Info:TJSONObject;
begin
  FullPath:=''; if Path<>'' then FullPath:=ExpandFileName(Path);
  for I:=0 to OpenFileCount-1 do if (FullPath<>'') and (OpenFileName(I)=FullPath) then begin SwitchDocument(I); Exit; end;
  ID:=FormatID; if ID='' then ID:=FindExtensionFormat(Path); Info:=ExtensionFormatInfo(ID); Lines:=TStringList.Create; Session:=nil;
  try
    try
      if FullPath<>'' then Lines.LoadFromFile(FullPath) else if Info<>nil then Lines.Text:=Info.Get('template','');
      Session:=TOpenDocument.Create; Session.PluginSource:=True; Session.Visual:=False; Session.PluginText:=Lines.Text;
      Session.FormatID:=ID; Session.FormatName:='Text'; Session.SourceExtension:=Copy(ExtractFileExt(Path),2,MaxInt);
      if Info<>nil then begin
        Session.FormatName:=Info.Get('name','Source document');
        if (Session.SourceExtension='') and (Info.Find('extensions') is TJSONArray) and (Info.Arrays['extensions'].Count>0) then
          Session.SourceExtension:=Info.Arrays['extensions'].Strings[0];
      end;
      if Session.SourceExtension='' then Session.SourceExtension:='txt';
      RenderExtensionDocument(ID,Lines.Text,ExtractFileDir(FullPath),Preview,Error);
      Session.Document:=TTeXDocument.Create; Session.Document.ParseFile(Preview); Session.FileName:=FullPath;
      Session.Undo:=TObjectList.Create(True); Session.Redo:=TObjectList.Create(True); Session.EngineIndex:=Engine.Items.IndexOf('xelatex');
      Session.Parking:=TPanel.Create(Self); Session.Parking.Parent:=Self; Session.Parking.Visible:=False;
      FSessions.Add(Session); FileTabs.Tabs.Add('Untitled.'+Session.SourceExtension); Session:=nil; SwitchDocument(FSessions.Count-1);
      if Error<>'' then StatusText:=Error;
    except on E:Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
  finally Session.Free; Info.Free; Lines.Free; end;
end;
procedure TMainForm.OpenPluginDocumentClick(Sender:TObject);
var D:TOpenDialog;
begin
  D:=TOpenDialog.Create(Self);
  try D.Filter:=ExtensionSourceFilter(TMenuItem(Sender).Hint)+'All files|*';
    if D.Execute then OpenPluginSource(D.FileName,TMenuItem(Sender).Hint);
  finally D.Free; end;
end;
procedure TMainForm.NewPluginDocumentClick(Sender:TObject);
begin OpenPluginSource('',TMenuItem(Sender).Hint); end;
procedure TMainForm.FormatPluginSelection(const Command:string);
var Values,Response:TJSONObject; Error,Value:string; A,B:Integer;
begin
  A:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockBegin]); B:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockEnd]);
  Values:=TJSONObject.Create(['source',Editor.Text,'command',Command,'anchor',A,'focus',B]); Response:=nil;
  try
    Response:=RequestDocumentFormat(TOpenDocument(FSessions[FSessionIndex]).FormatID,'format',Values,Error); if Response=nil then Exit;
    Value:=Response.Get('source',Editor.Text); if Value=Editor.Text then Exit;
    Editor.BeginUndoBlock;
    try Editor.SelectAll; Editor.SelText:=Value;
      Editor.BlockBegin:=BytePoint(Value,Response.Get('anchor',A)); Editor.BlockEnd:=BytePoint(Value,Response.Get('focus',B));
    finally Editor.EndUndoBlock; end;
  finally Response.Free; Values.Free; end;
end;
