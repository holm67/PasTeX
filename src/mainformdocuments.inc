{ SPDX-License-Identifier: GPL-3.0-or-later }
constructor TOpenDocument.Create;
begin inherited Create; PreviewContext:=TTeXContext.Create; ActiveBlock:=-1; NeedsPreview:=True; Visual:=True; end;
destructor TOpenDocument.Destroy;
var I:Integer;
begin
  for I:=0 to High(Cards) do begin Cards[I].SelectionModel.Free; Cards[I].Panel.Free; end;
  if Wrapped<>nil then Wrapped.Free; if Plain<>nil then Plain.Free;
  Parking.Free; Undo.Free; Redo.Free; Linked.Free; Document.Free; PreviewContext.Free; inherited Destroy;
end;
procedure TMainForm.InitDocumentTabs;
var Session:TOpenDocument; Item:TMenuItem; Popup:TPopupMenu;
begin
  FSessions:=TObjectList.Create(True); FSessionIndex:=0;
  FileTabs:=TTabControl.Create(Self); FileTabs.Name:='DocumentTabs'; FileTabs.Parent:=Self;
  FileTabs.Align:=alTop; FileTabs.Top:=Ribbon.Top+Ribbon.Height; FileTabs.Height:=30;
  FileTabs.OnChange:=@FileTabChanged; FileTabs.Tabs.Add('Untitled.tex'); FileTabs.TabIndex:=0;
  FileTabs.Options:=FileTabs.Options+[nboShowCloseButtons,nboHidePageListPopup];
  TTabControlNoteBookStrings(FileTabs.Tabs).NoteBook.OnCloseTabClicked:=@FileTabCloseClicked;
  FDragTab:=-1; FPressedCloseTab:=-1;
  if not (nbcShowCloseButtons in FileTabs.GetCapabilities) then begin
    { Win32 tabs have no native close buttons. Use a clickable close image in
      each title, keeping the widget's tab layout and overflow scrolling. }
    FTabCloseImages:=TImageList.Create(Self); FTabCloseImages.Width:=Scale96ToForm(16);
    FTabCloseImages.Height:=FTabCloseImages.Width; UpdateFileTabCloseIcon;
    FileTabs.Images:=FTabCloseImages; FileTabs.OnGetImageIndex:=@FileTabImage;
  end;
  FileTabs.OnMouseDown:=@FileTabMouseDown; FileTabs.OnMouseMove:=@FileTabMouseMove; FileTabs.OnMouseUp:=@FileTabMouseUp;
  Popup:=TPopupMenu.Create(Self); FileTabs.PopupMenu:=Popup; Popup.OnPopup:=@FileTabPopup;
  TabMoveLeft:=TMenuItem.Create(Self); TabMoveLeft.Caption:='Move left'; TabMoveLeft.Tag:=-1;
  TabMoveLeft.OnClick:=@MoveFileTabClick; Popup.Items.Add(TabMoveLeft);
  TabMoveRight:=TMenuItem.Create(Self); TabMoveRight.Caption:='Move right'; TabMoveRight.Tag:=1;
  TabMoveRight.OnClick:=@MoveFileTabClick; Popup.Items.Add(TabMoveRight);
  Item:=TMenuItem.Create(Self); Item.Caption:='-'; Popup.Items.Add(Item);
  Item:=TMenuItem.Create(Self); Item.Caption:='Close file'; Item.OnClick:=@CloseFileClick; Popup.Items.Add(Item);
  Session:=TOpenDocument.Create; Session.Document:=Document; Session.Undo:=FVisualUndo; Session.Redo:=FVisualRedo;
  Session.Parking:=TPanel.Create(Self); Session.Parking.Parent:=Self; Session.Parking.Visible:=False;
  FSessions.Add(Session); StoreDocumentTab;
  Item:=TMenuItem.Create(Self); Item.Caption:='Save all'; Item.OnClick:=@SaveAllClick; Item.ShortCut:=ShortCut(VK_S,[ssCtrl,ssShift,ssAlt]); FileMenu.Insert(FileMenu.Count-2,Item);
  Item:=TMenuItem.Create(Self); Item.Caption:='Close file'; Item.OnClick:=@CloseFileClick; Item.ShortCut:=ShortCut(VK_W,[ssCtrl]); FileMenu.Insert(FileMenu.Count-2,Item);
  Item:=TMenuItem.Create(Self); Item.Caption:='Open linked subfiles…'; Item.OnClick:=@OpenLinkedFiles; FileMenu.Insert(2,Item);
  Item:=TMenuItem.Create(Self); Item.Caption:='Open master document'; Item.OnClick:=@OpenRootClick; FileMenu.Insert(3,Item);
  ApplyTheme(FileTabs);
end;
procedure TMainForm.StoreDocumentTab;
var S:TOpenDocument;
begin
  if (FSessions=nil) or (FSessionIndex<0) or (FSessionIndex>=FSessions.Count) then Exit;
  if not (csDestroying in ComponentState) then FormulaEditor.FinishDefinitionEdit;
  if not (csDestroying in ComponentState) and (FDocumentRefreshDue<>0) then QueuePreview;
  S:=TOpenDocument(FSessions[FSessionIndex]); S.Document:=Document; S.Cards:=Cards;
  S.Undo:=FVisualUndo; S.Redo:=FVisualRedo; S.FileName:=FileName; S.Modified:=Modified;
  if S.PluginSource then S.PluginText:=Editor.Text;
  S.Wrapped:=WrappedEditor; S.Plain:=PlainEditor; S.Editor:=Editor; S.WrapPlugin:=SourceWrap;
  S.Visual:=EquationMode; S.ActiveBlock:=ActiveBlock; S.EngineIndex:=Engine.ItemIndex;
  S.CacheContext:=CacheContext; S.LastLog:=LastLog; S.SourceHeight:=FSourceHeight;
  S.PreambleExpanded:=FPreambleExpanded;
  S.ScrollX:=Scroll.HorzScrollBar.Position; S.ScrollY:=Scroll.VertScrollBar.Position;
  if Document.PreambleOnly and not S.PluginSource then PreambleEditor.GetSourceSelection(S.Anchor,S.Focus)
  else if Editor.Visible then begin
    S.Focus:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.LogicalCaretXY]);
    S.Anchor:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockBegin]);
    if S.Anchor=S.Focus then S.Anchor:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockEnd]);
  end else FormulaEditor.GetSourceSelection(S.Anchor,S.Focus);
  S.NeedsPreview:=Pending or (Worker<>nil);
end;
function TMainForm.OpenFileCount:Integer;
begin if FSessions=nil then Result:=0 else Result:=FSessions.Count; end;
function TMainForm.OpenFileName(Index:Integer):string;
begin if Index=FSessionIndex then Result:=FileName else Result:=TOpenDocument(FSessions[Index]).FileName; end;
procedure TMainForm.SwitchDocument(Index:Integer);
var S,Old:TOpenDocument; I:Integer; WasSplit:Boolean; P:TTeXProject; DirtyFiles:TStringList;
begin
  if FSwitchingDocument or (FSessions=nil) or (Index<0) or (Index>=FSessions.Count) or (Index=FSessionIndex) then Exit;
  FManualPreview:=False;
  WasSplit:=FSplitView<>nil; ExitSplitView;
  if FPluginSourceDue<>0 then RefreshPluginSource;
  if FPagedView<>nil then RestoreContinuousWorkspace;
  FScaleClamped:=False;
  FormulaEditor.FinishCommand;
  if FReblockQueued then begin if FormulaBox.Visible then ReblockVisual(0) else ReblockSource(0); end;
  FPreambleRefreshDue:=0;
  StoreDocumentTab;
  S:=TOpenDocument(FSessions[Index]);
  { Refresh linked files before detaching the current editor. A read error
    must leave the active document, histories and controls together. }
  try
    if S.Linked<>nil then begin
      P:=Project; DirtyFiles:=TStringList.Create;
      try
        P.Engine:=Engine.Items[S.EngineIndex];
        S.Linked.Refresh(P);
        if S.Document.Source<>S.Linked.Text then begin
          S.Document.ParseFile(S.Linked.Text); S.ReloadLinked:=True; S.Undo.Clear; S.Redo.Clear;
          S.Linked.ChangedFiles(DirtyFiles); if DirtyFiles.Count>0 then S.Modified:=True;
        end;
      finally DirtyFiles.Free; P.Free; end;
    end;
  except FileTabs.TabIndex:=FSessionIndex; raise; end;
  FSwitchingDocument:=True;
  try
    FLoading:=True;
    try
    if FPluginSourcePane<>nil then begin FPluginSourcePane.Visible:=False; FPluginSourceSplit.Visible:=False; end;
    Inc(Revision); if Worker<>nil then Worker.Terminate; Pending:=False;
    Old:=TOpenDocument(FSessions[FSessionIndex]); ClearDocumentSelection;
    FormulaEditor.CancelSelectionDrag; FormulaBox.Visible:=False; FormulaBox.Parent:=Self;
    Editor.Visible:=False; Editor.Align:=alNone; Editor.Parent:=Old.Parking;
    if SourceTools<>nil then begin SourceTools.Visible:=False; SourceTools.Parent:=Self; end;
    if SourceGrip<>nil then begin SourceGrip.Visible:=False; SourceGrip.Parent:=Self; end;
    for I:=0 to High(Cards) do begin
      Cards[I].Panel.Parent:=Old.Parking; Cards[I].Image.ReleaseRenderCache;
      FreeAndNil(Cards[I].Draft);
    end;
    FSessionIndex:=Index; FileTabs.TabIndex:=Index;
    Document:=S.Document; FileName:=S.FileName; Modified:=S.Modified;
    FVisualUndo:=S.Undo; FVisualRedo:=S.Redo; Cards:=S.Cards; CacheContext:=S.CacheContext; LastLog:=S.LastLog;
    WrappedEditor:=S.Wrapped; PlainEditor:=S.Plain; Editor:=S.Editor; SourceWrap:=S.WrapPlugin;
    if Editor=nil then begin
      WrappedEditor:=TSynEdit.Create(Self); Editor:=WrappedEditor; Editor.Parent:=Self;
      Editor.Visible:=False; Editor.SetDefaultKeystrokes; Editor.ResetMouseActions;
      SourceWrap:=TLazSynEditLineWrapPlugin.Create(Editor); UseNativeSourceFonts(Editor); EnableSourceLinks(Editor);
      Editor.Font.Name:=FSourceFontPreference; Editor.Font.Size:=TOpenDocument(FSessions[0]).Wrapped.Font.Size;
      Editor.Highlighter:=Highlighter; Editor.PopupMenu:=EditPopup; Editor.OnChange:=@EditorChanged;
      Editor.OnKeyDown:=@EditorKeyDown; Editor.OnProcessCommand:=@SourceCommandBefore; Editor.OnCommandProcessed:=@SourceCommandAfter;
      Editor.OnStatusChange:=@SourceSelectionChanged; Editor.OnMouseDown:=@SourceMouseDown; Editor.ScrollBars:=ssVertical;
      Editor.Options:=Editor.Options+[eoPersistentCaret]-[eoScrollPastEol];
      Editor.Options2:=Editor.Options2+[eoPersistentCaretStopBlink]-[eoScrollPastEolAddPage,eoScrollPastEolAutoCaret];
    end;
    SetMenuChecked(SourceWrapMenuItem,Editor=WrappedEditor); SourceWrapButton.Down:=SourceWrapMenuItem.Checked;
    Engine.ItemIndex:=S.EngineIndex; CheckPreviewTools; EquationMode:=S.Visual; FSourceHeight:=S.SourceHeight; FPreambleExpanded:=S.PreambleExpanded;
    ActiveBlock:=-1; FPreambleEditing:=False; FPreviewOnly:=False; FSelectionRevision:=-1; FormulaEditor.InvalidateContext; FSelectionContext.Invalidate;
    FormulaEditor.FormulaSourceMode:=False;
    if FormulaSourceButton<>nil then FormulaSourceButton.Down:=False;
    for I:=0 to High(Cards) do Cards[I].Panel.Parent:=Scroll;
    RefreshProjectContext; UpdateSourceFonts;
    finally FLoading:=False; end;
    RefreshPreambleEditor; UpdateLinkedBoundaries;
    if (Length(Cards)=0) or S.ReloadLinked then BuildCards else UpdatePreviewCards(0);
    S.ReloadLinked:=False;
    if (S.ActiveBlock>=0) and not Document.PreambleOnly and not S.PluginSource then begin
      EditBlock(Min(S.ActiveBlock,Document.Blocks.Count-1));
      if FormulaBox.Visible then FormulaEditor.SetSourceSelection(S.Anchor,S.Focus)
      else begin Editor.BlockBegin:=BytePoint(Editor.Text,S.Anchor); Editor.BlockEnd:=BytePoint(Editor.Text,S.Focus); Editor.LogicalCaretXY:=BytePoint(Editor.Text,S.Focus); end;
    end;
    LayoutCards(nil); ApplyAppearance;
    if S.PluginSource then ShowPluginSourceEditor else begin Editor.Highlighter:=Highlighter; TMenuItem(FindComponent('ExportPluginTeXMenu')).Visible:=False; end;
    if Document.PreambleOnly and not S.PluginSource then begin
      FPreambleEditing:=True; PreambleEditor.SetSourceSelection(S.Anchor,S.Focus);
    end;
    SetPreviewScroll(Scroll,S.ScrollX,S.ScrollY); UpdateTitle;
    if S.NeedsPreview or (FRealtimeCompile and (Length(Cards)>0) and (Cards[0].Image.PreviewWidth=0)) then QueuePreview;
    SyncFullSource(True);
    if FFullSource<>nil then FFullSource.Caption:='Full source — '+ExtractFileName(FileName);
  finally FSwitchingDocument:=False; end;
  if WasSplit and not S.PluginSource then SplitViewClick(nil);
  if S.PageMode and not WasSplit then PagedViewClick(nil);
end;
procedure TMainForm.FileTabChanged(Sender:TObject);
begin if not FLoading and not FSwitchingDocument then SwitchDocument(FileTabs.TabIndex); end;
procedure TMainForm.FileTabCloseClicked(Sender:TObject);
var Index:Integer;
begin
  Index:=FileTabs.Tabs.IndexOfObject(Sender);
  if (Index<0) or (Index>=FSessions.Count) then Exit;
  FDragTab:=-1; FPressedCloseTab:=-1; SetCaptureControl(nil);
  FClosingTab:=TOpenDocument(FSessions[Index]);
  { Do not destroy a tab while its native close-button callback is running. }
  Application.QueueAsyncCall(@CloseFileTabAsync,0);
end;
procedure TMainForm.CloseFileTabAsync(Data:PtrInt);
begin CloseFileTab(nil); end;
procedure TMainForm.CloseFileTab(Sender:TObject);
var Original,Target:TOpenDocument; Index:Integer;
begin
  if DeferInput(@CloseFileTab,Sender) then Exit;
  Target:=FClosingTab; FClosingTab:=nil; Index:=FSessions.IndexOf(Target);
  if Index<0 then Exit;
  Original:=TOpenDocument(FSessions[FSessionIndex]); SwitchDocument(Index); CloseFileClick(nil);
  if Original<>Target then begin
    Index:=FSessions.IndexOf(Original); if Index>=0 then SwitchDocument(Index);
  end;
end;
procedure TMainForm.FileTabImage(Sender:TObject; TabIndex:Integer; var ImageIndex:Integer);
begin ImageIndex:=0; end;
procedure TMainForm.UpdateFileTabCloseIcon;
var Image:TBitmap; N,Inset:Integer;
begin
  if FTabCloseImages=nil then Exit; Image:=TBitmap.Create;
  try
    N:=FTabCloseImages.Width; Inset:=Max(3,N div 4); Image.SetSize(N,N);
    Image.Canvas.Brush.Color:=clFuchsia; Image.Canvas.FillRect(Rect(0,0,N,N));
    Image.Canvas.Pen.Color:=InkColor; Image.Canvas.Pen.Width:=Max(1,N div 8);
    Image.Canvas.Line(Inset,Inset,N-Inset,N-Inset); Image.Canvas.Line(Inset,N-Inset,N-Inset,Inset);
    FTabCloseImages.Clear; FTabCloseImages.AddMasked(Image,clFuchsia);
  finally Image.Free; end;
end;
function TMainForm.FileTabCloseHit(X,Y:Integer):Integer;
var R:TRect;
begin
  Result:=-1; if FTabCloseImages=nil then Exit;
  Result:=FileTabs.IndexOfTabAt(X,Y); if Result<0 then Exit;
  R:=FileTabs.TabRect(Result);
  if (X<R.Left+Scale96ToForm(4)) or (X>=R.Left+Scale96ToForm(8)+FTabCloseImages.Width) then Result:=-1;
end;
procedure TMainForm.MoveDocument(FromIndex,ToIndex:Integer);
var Current:TOpenDocument;
begin
  if FSwitchingDocument or (FSessions=nil) or (FromIndex=ToIndex) or
    (FromIndex<0) or (FromIndex>=FSessions.Count) or (ToIndex<0) or (ToIndex>=FSessions.Count) then Exit;
  Current:=TOpenDocument(FSessions[FSessionIndex]); FSwitchingDocument:=True;
  try
    FSessions.Move(FromIndex,ToIndex); FileTabs.Tabs.Move(FromIndex,ToIndex);
    FSessionIndex:=FSessions.IndexOf(Current); FileTabs.TabIndex:=FSessionIndex;
  finally FSwitchingDocument:=False; end;
end;
procedure TMainForm.FileTabMouseDown(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
var Index:Integer;
begin
  Index:=FileTabs.IndexOfTabAt(X,Y); FDragTab:=-1;
  if Index<0 then Exit;
  FPressedCloseTab:=-1;
  if (Button=mbLeft) and (FileTabCloseHit(X,Y)=Index) then begin FPressedCloseTab:=Index; Exit; end;
  SwitchDocument(Index);
  if Button=mbLeft then begin FDragTab:=Index; FDragTabOrigin:=Point(X,Y); SetCaptureControl(FileTabs); end;
end;
procedure TMainForm.FileTabMouseMove(Sender:TObject; Shift:TShiftState; X,Y:Integer);
var Index:Integer;
begin
  if FDragTab<0 then Exit;
  if not (ssLeft in Shift) then begin FDragTab:=-1; SetCaptureControl(nil); Exit; end;
  if Abs(X-FDragTabOrigin.X)+Abs(Y-FDragTabOrigin.Y)<5 then Exit;
  Index:=FileTabs.IndexOfTabAt(X,Y);
  if (Index>=0) and (Index<>FDragTab) then begin MoveDocument(FDragTab,Index); FDragTab:=Index; end;
end;
procedure TMainForm.FileTabMouseUp(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
var Index:Integer;
begin
  if Button<>mbLeft then Exit;
  FDragTab:=-1; SetCaptureControl(nil); Index:=FPressedCloseTab; FPressedCloseTab:=-1;
  if (Index>=0) and (FileTabCloseHit(X,Y)=Index) then FileTabCloseClicked(FileTabs.Tabs.Objects[Index]);
end;
procedure TMainForm.FileTabPopup(Sender:TObject);
begin TabMoveLeft.Enabled:=FSessionIndex>0; TabMoveRight.Enabled:=FSessionIndex<FSessions.Count-1; end;
procedure TMainForm.MoveFileTabClick(Sender:TObject);
begin MoveDocument(FSessionIndex,FSessionIndex+TMenuItem(Sender).Tag); end;
function TMainForm.QueueLinkedFile(const Source:string; Offset:Integer):Boolean;
var Target:string;
begin
  Target:=LinkedTeXInputAt(Source,FileName,Offset); Result:=Target<>'';
  if not Result then Exit;
  if not FileExists(Target) then begin StatusText:='Cannot open subfile: '+Target; Exit; end;
  if FLinkedPath='' then Application.QueueAsyncCall(@OpenLinkedFileAsync,0);
  FLinkedPath:=Target; FLinkedRoot:=TOpenDocument(FSessions[FSessionIndex]).RootName;
  if FLinkedRoot='' then FLinkedRoot:=FileName;
end;
procedure TMainForm.OpenLinkedFileAsync(Data:PtrInt);
var Target,Root:string;
begin
  Target:=FLinkedPath; Root:=FLinkedRoot; FLinkedPath:=''; FLinkedRoot:='';
  if Target='' then Exit;
  LoadDocument(Target);
  if (FileName=Target) and (Root<>'') and (Root<>Target) then begin
    TOpenDocument(FSessions[FSessionIndex]).RootName:=Root; RefreshProjectContext; QueuePreview;
  end;
end;
procedure TMainForm.SourceMouseDown(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
var SourceEditor:TSynEdit; ClickPos:TPoint; Offset,First,Last:Integer; Target:string;
begin
  if (Button<>mbLeft) or not (ssCtrl in Shift) then Exit;
  SourceEditor:=TSynEdit(Sender); ClickPos:=SourceEditor.PixelsToLogicalPos(Point(X,Y));
  Offset:=Length(SourceEditor.TextBetweenPoints[Point(1,1),ClickPos]);
  if not QueueLinkedFile(SourceEditor.Text,Offset) and TeXHyperlinkAt(SourceEditor.Text,Offset,Target,First,Last) then
    GeneratedAction(Self,Target,-1,False);
end;
procedure TMainForm.VisualLinkClick(Sender:TObject; Offset:Integer; var Handled:Boolean);
var First,Last:Integer; Target:string;
begin
  Handled:=QueueLinkedFile(TMathEditor(Sender).Formula,Offset);
  if not Handled then begin
    Handled:=TeXHyperlinkAt(TMathEditor(Sender).Formula,Offset,Target,First,Last);
    if Handled then GeneratedAction(Sender,Target,-1,False);
  end;
end;
procedure TMainForm.PreviewDoubleClick(Sender:TObject);
begin
  if PluginSourceActive then begin if Editor.CanFocus then Editor.SetFocus; Exit; end;
  if ActiveBlock<>TControl(Sender).Tag then EditBlock(TControl(Sender).Tag);
  if FormulaBox.Visible then FormulaEditor.SelectWord;
end;
procedure TMainForm.CloseFileClick(Sender:TObject);
var Index:Integer; S:TOpenDocument;
begin
  if DeferInput(@CloseFileClick,Sender) then Exit;
  if not MayDiscard then Exit; Index:=FSessionIndex; StoreDocumentTab;
  ExitSplitView;
  if FSessions.Count=1 then begin
    if Worker<>nil then Worker.Terminate; Inc(Revision);
    FreeAndNil(FPagedView); Scroll.Visible:=True;
    S:=TOpenDocument(FSessions[0]); S.PluginSource:=False; S.PluginText:=''; S.PageMode:=False; S.Visual:=True; EquationMode:=True;
    if FPluginSourcePane<>nil then begin FPluginSourcePane.Visible:=False; FPluginSourceSplit.Visible:=False; end;
    Editor.Highlighter:=Highlighter;
    FreeAndNil(S.Linked); Document.Parse(Starter); FileName:=''; Modified:=False; FVisualUndo.Clear; FVisualRedo.Clear;
    S:=TOpenDocument(FSessions[0]); S.RootName:=''; BuildCards; UpdateTitle; RefreshProjectContext; QueuePreview; Exit;
  end;
  if Index>0 then SwitchDocument(Index-1) else SwitchDocument(1);
  FSwitchingDocument:=True;
  try FSessions.Delete(Index); FileTabs.Tabs.Delete(Index); if FSessionIndex>Index then Dec(FSessionIndex); FileTabs.TabIndex:=FSessionIndex;
  finally FSwitchingDocument:=False; end;
  UpdateTitle;
end;
procedure TMainForm.SaveAllClick(Sender:TObject);
var I,Index:Integer;
begin
  if DeferInput(@SaveAllClick,Sender) then Exit; Index:=FSessionIndex;
  for I:=0 to FSessions.Count-1 do begin SwitchDocument(I); if Modified and not SaveDocument(False) then Break; end;
  SwitchDocument(Index);
end;
function TMainForm.Project:TTeXProject;
var I:Integer; S:TOpenDocument;
begin
  Result:=TTeXProject.Create; Result.Engine:=Engine.Text;
  for I:=0 to FSessions.Count-1 do begin
    S:=TOpenDocument(FSessions[I]); if S.Linked<>nil then S.Linked.Sources(Result);
  end;
  for I:=0 to FSessions.Count-1 do begin
    S:=TOpenDocument(FSessions[I]);
    if I=FSessionIndex then Result.SetSource(FileName,FileDocumentSource(S))
    else Result.SetSource(S.FileName,FileDocumentSource(S));
  end;
end;
procedure TMainForm.RefreshProjectContext;
var P:TTeXProject; Master:TTeXDocument; Root,RootSource,Body,Child:string; I,N:Integer; S:TOpenDocument;
begin
  RefreshAddonChecks;
  FEffectivePreamble:=Document.Preamble; FProjectBefore:=''; FProjectAfter:='';
  if Document.PreambleOnly then Exit;
  if FSessions=nil then Exit; P:=Project; Master:=TTeXDocument.Create;
  try
    S:=TOpenDocument(FSessions[FSessionIndex]); Root:=S.RootName;
    if Root='' then Root:=P.RootFile(Document.Source,FileName);
    if (Root<>'') and (Root<>FileName) then begin
      S.RootName:=Root; RootSource:=P.ReadSource(Root); Master.Parse(P.Expanded(RootSource,Root));
      if Master.Preamble<>'' then begin
        FEffectivePreamble:=Master.Preamble; Body:=''; for I:=0 to Master.Blocks.Count-1 do Body:=Body+Master.Blocks[I];
        Child:=''; for I:=0 to Document.Blocks.Count-1 do Child:=Child+P.Expanded(Document.Blocks[I],FileName);
        N:=Pos(Trim(Child),Body);
        if (Trim(Child)<>'') and (N>0) then begin
          FProjectBefore:=Copy(Body,1,N-1); FProjectAfter:=Copy(Body,N+Length(Trim(Child)),MaxInt);
        end;
      end;
    end else if FileName<>'' then FEffectivePreamble:=P.Expanded(Document.Preamble,FileName);
  finally Master.Free; P.Free; end;
end;
function TMainForm.PreviewSnapshot:string;
var P:TTeXProject; Blocks:TStringList; I:Integer; Header,Body:string;
begin
  RefreshProjectContext; P:=Project; Blocks:=TStringList.Create;
  try
    Body:=FProjectBefore;
    for I:=0 to Document.Blocks.Count-1 do begin
      Blocks.Add(P.Expanded(Document.Blocks[I],FileName,FEffectivePreamble)); Body:=Body+Blocks[I];
    end;
    Body:=Body+FProjectAfter;
    Header:=SyncMathRSFS(FEffectivePreamble,Body); Header:=SyncLanguagePackages(Header,Body,Engine.Text); Header:=SyncLayoutPackages(Header,Body);
    Result:=ParagraphDocument(Header,Blocks,-1,'',False,FProjectBefore,FProjectAfter);
  finally Blocks.Free; P.Free; end;
end;
function TMainForm.SyncDocumentPackages(const Body:string):string;
begin
  Result:=Document.Preamble;
  if not CompilableTeXDocument(Result) then Exit;
  { Input fragments inherit their master's packages. Never write preamble
    commands into a body-only subfile. Snapshot dependencies live in the root. }
  if (Result='') and (FSessions<>nil) and
     (TOpenDocument(FSessions[FSessionIndex]).RootName<>'') then Exit;
  Result:=SyncMathRSFS(Result,Body); Result:=SyncLanguagePackages(Result,Body,Engine.Text);
  Result:=SyncCitationPackages(Result,Body);
  Result:=SyncLayoutPackages(Result,Body);
end;
procedure TMainForm.OpenLinkedFiles(Sender:TObject);
var P:TTeXProject; Links:TStringList; D:TForm; List:TListBox; B:TButton; I,ParentIndex:Integer; Root,Selected:string;
begin
  if DeferInput(@OpenLinkedFiles,Sender) then Exit; P:=Project; Links:=TStringList.Create; D:=TForm.CreateNew(Self);
  try
    P.LinkedFiles(FileDocumentSource(TOpenDocument(FSessions[FSessionIndex])),FileName,Links);
    if Links.Count=0 then begin StatusText:='This file has no linked subfiles.'; Exit; end;
    D.Caption:='Open linked subfile'; D.Position:=poMainFormCenter; D.BorderStyle:=bsDialog; D.ClientWidth:=600; D.ClientHeight:=350;
    List:=TListBox.Create(D); List.Parent:=D; List.SetBounds(16,16,568,270); List.Items.Assign(Links); List.ItemIndex:=0;
    B:=TButton.Create(D); B.Parent:=D; B.SetBounds(394,302,90,32); B.Caption:='Open'; B.Default:=True; B.ModalResult:=mrOK;
    B:=TButton.Create(D); B.Parent:=D; B.SetBounds(494,302,90,32); B.Caption:='Cancel'; B.Cancel:=True; B.ModalResult:=mrCancel;
    ApplyTheme(D); if D.ShowModal<>mrOK then Exit; I:=List.ItemIndex; if I<0 then Exit;
    Selected:=Links[I]; ParentIndex:=FSessionIndex; Root:=TOpenDocument(FSessions[ParentIndex]).RootName; if Root='' then Root:=FileName;
    LoadDocument(Selected); if FSessionIndex<>ParentIndex then begin TOpenDocument(FSessions[FSessionIndex]).RootName:=Root; RefreshProjectContext; QueuePreview; end;
  finally D.Free; Links.Free; P.Free; end;
end;
procedure TMainForm.OpenRootClick(Sender:TObject);
var Root:string; P:TTeXProject;
begin
  if DeferInput(@OpenRootClick,Sender) then Exit; Root:=TOpenDocument(FSessions[FSessionIndex]).RootName;
  if Root='' then begin P:=Project; try Root:=P.RootFile(Document.Source,FileName); finally P.Free; end; end;
  if Root<>'' then LoadDocument(Root) else StatusText:='This file is the master document. Use % !TeX root = main.tex in a subfile.';
end;
procedure TMainForm.UpdateSourceFonts;
var FontName:string; I:Integer;
begin
  if FSourceFontPreference='' then FSourceFontPreference:=DefaultSourceFont;
  FontName:=SourceFontForText(FSourceFontPreference,Document.Source);
  if WrappedEditor<>nil then WrappedEditor.Font.Name:=FontName;
  if PlainEditor<>nil then PlainEditor.Font.Name:=FontName;
  FormulaEditor.ConfigureSourceFont(WrappedEditor.Font);
  if FPagedView<>nil then FPagedView.ConfigureSourceFont(WrappedEditor.Font);
  if PreambleEditor<>nil then PreambleEditor.ConfigureSourceFont(WrappedEditor.Font);
  for I:=0 to High(Cards) do if Cards[I].Draft<>nil then Cards[I].Draft.ConfigureSourceFont(WrappedEditor.Font);
end;
procedure TMainForm.ClearCompiledPreviews;
var I:Integer; Session:TOpenDocument;
  procedure ClearCards(var Items:TParagraphCards);
  var J:Integer;
  begin
    for J:=0 to High(Items) do begin
      Items[J].Image.ClearPreview; FreeAndNil(Items[J].SelectionModel);
      Items[J].Positions:=''; Items[J].LayoutXML:=''; Items[J].LayoutPage:=0;
    end;
  end;
begin
  ClearCards(Cards);
  if FSessions<>nil then for I:=0 to FSessions.Count-1 do if I<>FSessionIndex then begin
    Session:=TOpenDocument(FSessions[I]); ClearCards(Session.Cards); Session.NeedsPreview:=True;
  end;
end;
procedure TMainForm.CompleteParagraphPreview;
var I,Count:Integer; VectorPDF:IVectorDocument; Anchor:TPreviewAnchor;
begin
  if (Worker.Revision=Revision) and not PluginSourceActive and (FPagedView=nil) then
  begin
    Anchor:=CapturePreviewAnchor;
    LastLog := Worker.ErrorText + LineEnding + Worker.LogText;
    if Worker.ErrorText='' then VectorPDF:=OpenVectorDocument(Worker.WorkDir+DirectorySeparator+'preview.pdf');
    if (Worker.ErrorText='') and Worker.PageLayoutOnly and (VectorPDF=nil) then begin
      { If the runtime PDF backend cannot open this output, retry with the
        existing raster pipeline. Unchanged previews remain available. }
      FPreviewRasterFallback:=True; Pending:=True; Due:=0; FreeAndNil(Worker); Exit;
    end;
    if Worker.PageLayoutOnly then Count:=VectorPageCount(VectorPDF) else Count:=Worker.Images.Count;
    if (Worker.ErrorText = '') and (Count <> Length(Cards)) then
      Worker.ErrorText := 'Preview page count does not match paragraphs. Check document structure.';
    if Worker.ErrorText = '' then
    begin
      try
        if (FSessions<>nil) and (FSessionIndex>=0) then
          TOpenDocument(FSessions[FSessionIndex]).PreviewContext.GeneratedBibliography:=Worker.BibliographySource;
        for I := 0 to High(Cards) do
        begin
          FreeAndNil(Cards[I].SelectionModel);
          if Worker.PageLayoutOnly then begin
            if not Cards[I].Image.LoadVectorPreview(VectorPDF,I+1,Worker.DPI) then
              raise Exception.Create('Invalid PDF preview page dimensions.');
          end else begin
            Cards[I].Image.LoadPreview(Worker.Images[I]);
            Cards[I].Image.Surface.SetVector(VectorPDF,I+1);
          end;
          Cards[I].Positions:=Worker.Positions; Cards[I].LayoutXML:=Worker.LayoutXML; Cards[I].LayoutPage:=I+1;
          Cards[I].SourceKey := Trim(Document.Blocks[I]);
          Cards[I].Image.Surface.SetSourceGraphics(Cards[I].SourceKey);
          FreeAndNil(Cards[I].Draft);
          Cards[I].Image.Visible:=(I<>ActiveBlock) or
            not (FormulaBox.Visible or Editor.Visible);
          Cards[I].PreviewState:=0;
        end;
        FormulaEditor.PreviewFrame:=0;
        if (ActiveBlock>=0) and FormulaBox.Visible then
          FormulaEditor.SetGeneratedPreview(Cards[ActiveBlock].Image,Cards[ActiveBlock].LayoutXML,Cards[ActiveBlock].LayoutPage);
        UpdatePreviewCards(-1);
        LayoutCards(nil);
        RestorePreviewAnchor(Anchor);
        UpdateDocumentSelection;
        StatusText := IntToStr(Length(Cards)) + ' paragraphs · click to edit · Esc returns to preview';
      except
        on E: Exception do Worker.ErrorText := E.Message;
      end;
    end;
    if Worker.ErrorText <> '' then
    begin
      LastLog := Worker.ErrorText + LineEnding + Worker.LogText;
      StatusText := Worker.ErrorText + ' Previous previews may be out of date.';
      UpdatePreviewCards(2); LayoutCards(nil); RestorePreviewAnchor(Anchor);
    end;
  end;
  FreeAndNil(Worker);
end;

procedure TMainForm.UpdatePreviewCards(State:Integer);
var I,BeforeOffset,ActiveOffset,Prepared,DraftWidth,CardWidth,LayoutWidth:Integer; Directory,Header,FullSource,Declarations,ActiveDeclarations:string; SharedContext:TTeXContext; NewDraft,AppendixMarker,LargeDocument:Boolean; Zoom:Double;
begin
  Prepared:=0; LargeDocument:=Length(Cards)>24;
  Scroll.DisableAlign;
  try
  if State>=0 then RefreshProjectContext;
  FPermanentAvailable:=UseCompiledPreview;
  Header:=FEffectivePreamble+FProjectBefore;
  if Header='' then Header:=Document.Preamble;
  LayoutWidth:=PreviewLayoutWidth(Scroll);
  if FFitWidth then CardWidth:=Max(100,LayoutWidth-64)
  else CardWidth:=Max(100,Round(Min(940,LayoutWidth-64)*FPreviewPercent/100));
  DraftWidth:=DocumentPreviewWidth(Header);
  if FFitWidth then Zoom:=(CardWidth-24)/Max(1,PreviewContentWidth)
  else Zoom:=Min(FPreviewPercent/100,(CardWidth-24)/Max(1,DraftWidth));
  DraftWidth:=Max(80,Min(CardWidth-24,Round(DraftWidth*Zoom)));
  if State>=0 then for I:=0 to High(Cards) do if Cards[I].ContextSource<>Document.Blocks[I] then begin
    Cards[I].ContextSource:=Document.Blocks[I];
    Cards[I].Declarations:=TeXContextDeclarations(Cards[I].ContextSource);
  end;
  Directory:=DocumentDirectory;
  SharedContext:=nil; Declarations:=''; BeforeOffset:=0; ActiveOffset:=0; ActiveDeclarations:='';
  if (FSessions<>nil) and (FSessionIndex>=0) then begin
    SharedContext:=TOpenDocument(FSessions[FSessionIndex]).PreviewContext;
    if State>=0 then begin
      FullSource:=Header;
      for I:=0 to Document.Blocks.Count-1 do FullSource:=FullSource+Document.Blocks[I];
      SharedContext.Load(FullSource+FProjectAfter,Directory,Engine.Text);
    end;
  end;
  for I:=0 to High(Cards) do begin
    AppendixMarker:=Copy(Trim(Document.Blocks[I]),1,9)='\appendix';
    if I>0 then begin
      Declarations:=Declarations+Cards[I-1].Declarations;
      Inc(BeforeOffset,Length(Document.Blocks[I-1]));
    end;
    if I=ActiveBlock then begin ActiveOffset:=BeforeOffset; ActiveDeclarations:=Declarations; end;
    if Cards[I].Folded then begin Cards[I].Panel.Visible:=False; Continue; end;
    if FPermanentAvailable and (Cards[I].Image.PreviewWidth>0) and (Cards[I].SourceKey=Trim(Document.Blocks[I])) and
       not AppendixMarker and not Cards[I].PartlyFolded then begin
      Cards[I].PreviewState:=0;
      if Cards[I].Draft<>nil then Cards[I].Draft.Visible:=False;
      if I<>ActiveBlock then Cards[I].Image.Visible:=True; Continue;
    end;
    if State>0 then Cards[I].PreviewState:=State;
    if Cards[I].PreviewState=0 then Cards[I].PreviewState:=1;
    if not FPermanentAvailable or AppendixMarker then Cards[I].PreviewState:=0;
    if (I=ActiveBlock) and FormulaBox.Visible then begin
      { The visual editor already owns this paragraph's live tree. }
      FreeAndNil(Cards[I].Draft); Cards[I].Image.Visible:=False;
      Continue;
    end;
    if not AppendixMarker and (Prepared>0) and (FPreviewLayoutDeadline<>0) and (GetTickCount64>=FPreviewLayoutDeadline) then begin
      if (State>=0) and (Cards[I].Draft<>nil) then Cards[I].Draft.InvalidateContext;
      Continue;
    end;
    if ((State<0) or LargeDocument) and (I<>ActiveBlock) and
       ((Cards[I].DocumentTop+Max(65,Max(Cards[I].MeasuredHeight,Cards[I].Panel.Height))<Scroll.VertScrollBar.Position) or
        (Cards[I].DocumentTop>Scroll.VertScrollBar.Position+Scroll.ClientHeight) or
        ((Cards[I].DocumentTop=0) and (I>12))) then begin
      { Background refresh must not recreate evicted offscreen cards before
        visible ones. Expensive frames would consume every layout budget. }
      if (State>=0) and (Cards[I].Draft<>nil) then Cards[I].Draft.InvalidateContext;
      Continue;
    end;
    NewDraft:=Cards[I].Draft=nil;
    { Initial card positions are estimates. Let the viewport refresh create
      large-document previews once the scroll range is established. }
    if NewDraft and LargeDocument and (State>=0) then Continue;
    if NewDraft then begin
      Cards[I].Draft:=TMathEditor.Create(Cards[I].Panel); Cards[I].Draft.Parent:=Cards[I].Panel;
      Cards[I].Draft.OnGeneratedAction:=@GeneratedAction; Cards[I].Draft.ReadOnly:=True; Cards[I].Draft.TabStop:=False; Cards[I].Draft.Tag:=I;
      Cards[I].Draft.DeferLayout:=not PluginSourceActive;
      Cards[I].Draft.OnMouseDown:=@PreviewMouseDown; Cards[I].Draft.OnDblClick:=@PreviewDoubleClick; Cards[I].Draft.PopupMenu:=EditPopup;
    end;
    Cards[I].Draft.SetContext(Header,Directory,Engine.Text,'',False);
    Cards[I].Draft.ConfigureSourceFont(WrappedEditor.Font);
    Cards[I].Draft.SetDocumentContext(Document.Blocks,I,SharedContext,Declarations,BeforeOffset);
    Cards[I].Draft.SetFoldedRanges(FFoldedSources,Document.SourceOffset(I,0),Length(Document.Blocks[I]));
    if NewDraft or (Cards[I].Draft.Formula<>Document.Blocks[I]) then Cards[I].Draft.LoadParagraph(Document.Blocks[I],nil);
    Cards[I].Draft.PreviewFrame:=Cards[I].PreviewState; Cards[I].Draft.Visible:=I<>ActiveBlock;
    Cards[I].Image.Visible:=False;
    if Cards[I].Draft.LayoutPending then begin
      Cards[I].Draft.PreviewZoom:=Zoom; Cards[I].Draft.TextAreaWidth:=DraftWidth; Cards[I].Draft.Width:=DraftWidth;
      Cards[I].MeasuredHeight:=Cards[I].Draft.PreferredHeight; Inc(Prepared);
    end;
  end;
  if (ActiveBlock>=0) and FormulaBox.Visible then begin
    FormulaEditor.SetContext(Header,Directory,Engine.Text,'',False);
    FormulaEditor.SetDocumentContext(Document.Blocks,ActiveBlock,SharedContext,ActiveDeclarations,ActiveOffset);
    FormulaEditor.SetFoldedRanges(FFoldedSources,Document.SourceOffset(ActiveBlock,0),Length(Document.Blocks[ActiveBlock]));
    FormulaEditor.PreviewFrame:=Cards[ActiveBlock].PreviewState;
  end;
  finally Scroll.EnableAlign; end;
end;
function TMainForm.DocumentDirectory:string;
var Root:string;
begin
  Root:=FileName;
  if (FSessions<>nil) and (FSessionIndex>=0) then
    if TOpenDocument(FSessions[FSessionIndex]).RootName<>'' then Root:=TOpenDocument(FSessions[FSessionIndex]).RootName;
  Result:=ExtractFileDir(Root); if Result='' then Result:=GetCurrentDir;
end;
procedure TMainForm.NotifyProjectChanged;
var Current,Other:TOpenDocument; Source,Root,OtherRoot:string; I,J:Integer;
begin
  if FSessions=nil then Exit; Current:=TOpenDocument(FSessions[FSessionIndex]); Source:=Document.Source;
  if Current.ObservedSource=Source then Exit; Current.ObservedSource:=Source;
  Root:=Current.RootName; if Root='' then Root:=FileName;
  if Root='' then Exit;
  for I:=0 to FSessions.Count-1 do begin
    if I=FSessionIndex then Continue; Other:=TOpenDocument(FSessions[I]); OtherRoot:=Other.RootName;
    if OtherRoot='' then OtherRoot:=Other.FileName; if OtherRoot<>Root then Continue;
    Other.NeedsPreview:=True;
    for J:=0 to High(Other.Cards) do begin
      if (FileName=Root) or (Pos('\input',Other.Cards[J].SourceKey)>0) or
         (Pos('\include',Other.Cards[J].SourceKey)>0) or (Pos('\subfile',Other.Cards[J].SourceKey)>0) or
         (Pos('\ref',Other.Cards[J].SourceKey)>0) or (Pos('\eqref',Other.Cards[J].SourceKey)>0) or
         (Pos('\autoref',Other.Cards[J].SourceKey)>0) then Other.Cards[J].SourceKey:='';
    end;
  end;
end;
procedure TMainForm.GuideClick(Sender:TObject);
var Directory,Path:string; I:Integer;
begin
  Directory:=GetCurrentDir;
  for I:=0 to 10 do begin
    Path:=IncludeTrailingPathDelimiter(Directory)+'docs'+DirectorySeparator+TMenuItem(Sender).Hint;
    if FileExists(Path) then begin LoadDocument(Path); Exit; end;
    if I=0 then Directory:=ExtractFileDir(Application.ExeName) else Directory:=ExtractFileDir(ExcludeTrailingPathDelimiter(Directory));
  end;
  StatusText:='Install the docs folder beside the program or open the TeX manual from the project.';
end;
