{ SPDX-License-Identifier: GPL-3.0-or-later }
procedure TMainForm.SplitViewClick(Sender:TObject);
var RestoreSubfiles:Boolean;
begin
  if DeferInput(@SplitViewClick,Sender) then Exit;
  if PluginSourceActive then begin StatusText:='Split PDF view is available for TeX documents'; Exit; end;
  if FSplitView<>nil then begin FFullSource.SourceEditor.SetFocus; Exit; end;
  if FPagedView<>nil then RestoreContinuousWorkspace;
  RestoreSubfiles:=(LinkedProject<>nil) and LinkedProject.Expanded;
  if RestoreSubfiles then ToggleInlineSubfiles(nil);
  FRestoreInlineSubfiles:=RestoreSubfiles;
  FullSourceClick(nil);
  FContinuousEditor.CancelSelectionDrag; ClearDocumentSelection; FPreambleEditing:=False;
  FSplitView:=TSourcePDFView.Create(Self); FSplitView.Name:='SourcePDFWorkspace';
  FSplitView.Parent:=Self; FSplitView.Align:=alClient;
  FSplitView.OnSourceLocation:=@SplitSourceLocation; FSplitView.OnMessage:=@SplitMessage;
  FSplitView.Attach(FFullSource); FSplitView.LoadDocument(FileName,DocumentDirectory,Engine.Text);
  FFitWidth:=True; FFitPage:=False; SelectZoom(ZoomChoice,FPreviewPercent);
  FormulaBox.Visible:=False; Editor.Visible:=False; Scroll.Visible:=False;
  SourceTools.Visible:=False; SourceGrip.Visible:=False; Pending:=False;
  FDocumentRefreshDue:=0; FPreambleRefreshDue:=0;
  if Worker<>nil then Worker.Terminate;
  ApplyTheme(FSplitView); FFullSource.ApplyAppearance(FSourceFontPreference,Editor.Font.Size);
  FFullSource.SourceEditor.SetFocus; UpdateStatusBar;
end;
procedure TMainForm.ExitSplitView;
var Anchor,Focus,Index,Offset:Integer; RestoreSubfiles:Boolean;
begin
  if FSplitView=nil then Exit;
  FFullSource.Selection(Anchor,Focus); FreeAndNil(FSplitView);
  RestoreSubfiles:=FRestoreInlineSubfiles; FRestoreInlineSubfiles:=False;
  if RestoreSubfiles and (LinkedProject<>nil) and not LinkedProject.Expanded then begin
    ToggleInlineSubfiles(nil); Focus:=LinkedProject.ViewOffset(LinkedProject.Root,Focus);
  end;
  RefreshProjectContext; BuildCards; Scroll.Visible:=True;
  Document.LocateOffset(Focus,Index,Offset);
  if (Index>=0) and not Document.PreambleOnly then begin
    EquationMode:=True; EditBlock(Index); FormulaEditor.SetSourceCaret(Offset);
  end;
  QueuePreview;
end;
procedure TMainForm.SplitMessage(Sender:TObject; const AText:string);
begin StatusText:=AText; FToolMessage:=AText; FToolMessageUntil:=GetTickCount64+6000; UpdateStatusBar; end;
procedure TMainForm.SplitSourceLocation(Sender:TObject; const Path:string; Line,Column:Integer);
begin
  FSplitLocateFile:=Path; FSplitLocateLine:=Line; FSplitLocateColumn:=Column;
  Application.QueueAsyncCall(@SplitLocateReady,0);
end;
procedure TMainForm.SplitLocateReady(Data:PtrInt);
var P:TPoint; Offset:Integer;
begin
  if FSplitView=nil then Exit;
  if (FSplitLocateFile<>'') and not SameFileName(FSplitLocateFile,FileName) then begin
    if not FileExists(FSplitLocateFile) then begin StatusText:='SyncTeX source file is unavailable: '+FSplitLocateFile; Exit; end;
    LoadDocument(FSplitLocateFile); SplitViewClick(nil);
  end;
  P.Y:=EnsureRange(FSplitLocateLine,1,Max(1,FFullSource.SourceEditor.Lines.Count));
  P.X:=EnsureRange(FSplitLocateColumn,1,Length(FFullSource.SourceEditor.Lines[P.Y-1])+1);
  Offset:=Length(FFullSource.SourceEditor.TextBetweenPoints[Point(1,1),P]);
  FFullSource.SetSelection(Offset,Offset); FFullSource.RevealOffset(Offset); FFullSource.SourceEditor.SetFocus;
  UpdateStatusBar;
end;

procedure TMainForm.CompletionContext(Source:TSynEdit; out Prefix,Directory,AEngine:string; out MathMode,AEnabled:Boolean);
begin
  Prefix:=''; Directory:=ExtractFilePath(FileName); AEngine:=Engine.Text; MathMode:=False;
  AEnabled:=not PluginSourceActive;
  if Document=nil then Exit;
  if (FFullSource<>nil) and (Source=FFullSource.SourceEditor) then Exit;
  Prefix:=Document.Preamble;
  if (Source=Editor) and (ActiveBlock>=0) then Prefix:=Copy(Document.Source,1,Document.SourceOffset(ActiveBlock,0));
end;
procedure TMainForm.SyncFullSource(Force:Boolean);
var Anchor,Focus,A,AO,B,BO,I:Integer; Ranges:TSourceRanges;
begin
  if (FFullSource=nil) or FSyncingFullSource or FLoading then Exit;
  if FSplitView<>nil then Exit;
  if PluginSourceActive then begin FFullSource.Hide; Exit; end;
  if not Force and not FFullSource.Visible then Exit;
  A:=ActiveBlock; B:=ActiveBlock;
  if not Force and FFullSource.SourceEditor.Focused and not FPreambleEditing then begin
    FFullSource.Selection(Anchor,Focus);
    if (Min(Anchor,Focus)<Length(Document.Preamble)) or
       (Max(Anchor,Focus)>Length(Document.Source)-Length(Document.Ending)) then Exit;
  end;
  FSyncingFullSource:=True;
  try
    if FPagedView<>nil then begin
      FPagedView.GetSourceSelection(Anchor,Focus); FFullSource.LoadSource(Document.Source,Anchor,Focus);
      Ranges:=FPagedView.SelectedSourceRanges;
      if Length(Ranges)>0 then FFullSource.SetSelectedRanges(Ranges,Anchor,Focus);
      Exit;
    end;
    if FPreambleEditing and (PreambleEditor<>nil) then begin
      PreambleEditor.GetSourceSelection(Anchor,Focus);
      FFullSource.LoadSource(Document.Source,FPreambleFields.SourceOffset(Anchor),FPreambleFields.SourceOffset(Focus)); Exit;
    end;
    if ActiveBlock<0 then begin FFullSource.LoadSource(Document.Source,0,0); Exit; end;
    if DocumentSelectionBounds(A,AO,B,BO) and (A<>B) then begin
      Anchor:=Document.SourceOffset(A,AO); Focus:=Document.SourceOffset(B,BO);
      if FSelectionStartBlock>FSelectionEndBlock then begin A:=Anchor; Anchor:=Focus; Focus:=A; end;
    end else begin
      if Editor.Visible then begin
        Focus:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.LogicalCaretXY]);
        Anchor:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockBegin]);
        if Anchor=Focus then Anchor:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockEnd]);
      end else FormulaEditor.GetSourceSelection(Anchor,Focus);
      Anchor:=Document.SourceOffset(ActiveBlock,Anchor); Focus:=Document.SourceOffset(ActiveBlock,Focus);
    end;
    FFullSource.LoadSource(Document.Source,Anchor,Focus);
    if FormulaBox.Visible and FormulaEditor.SelectingTableCells and not ((A<>B) and (FSelectionStartBlock>=0)) then begin
      Ranges:=FormulaEditor.SelectedSourceRanges;
      for I:=0 to High(Ranges) do begin Ranges[I].Start:=Document.SourceOffset(ActiveBlock,Ranges[I].Start); Ranges[I].Finish:=Document.SourceOffset(ActiveBlock,Ranges[I].Finish); end;
      FFullSource.SetSelectedRanges(Ranges,Anchor,Focus);
    end;
  finally FSyncingFullSource:=False; end;
end;
procedure TMainForm.FullSourceClick(Sender:TObject);
begin
  if DeferInput(@FullSourceClick,Sender) then Exit;
  if FSplitView<>nil then begin FFullSource.SourceEditor.SetFocus; Exit; end;
  if CurrentVisualEditor<>nil then CurrentVisualEditor.FinishVisualSource;
  if PluginSourceActive then begin if Editor.CanFocus then Editor.SetFocus; Exit; end;
  WindowDeactivated(nil);
  if FFullSource=nil then begin
    FFullSource:=TFullSourceForm.Create(Self); FFullSource.OnSourceChange:=@FullSourceChanged;
    FFullSource.OnSelectionChange:=@FullSourceSelection; FFullSource.OnSaveRequest:=@SaveClick;
    FFullSource.OnLocateSource:=@LocateSourceFromPreview; FFullSource.OnLocatePreview:=@LocatePreviewFromSource;
    FFullSource.SourceEditor.OnMouseDown:=@SourceMouseDown;
  end;
  FFullSource.ApplyAppearance(FSourceFontPreference,Editor.Font.Size); SyncFullSource(True);
  FFullSource.Show; FFullSource.BringToFront; if FFullSource.SourceEditor.CanFocus then FFullSource.SourceEditor.SetFocus;
end;
procedure TMainForm.LocateSourceFromPreview(Sender:TObject);
var Anchor:TPreviewAnchor; I,Y,Offset:Integer;
begin
  if FSplitView<>nil then begin FSplitView.InverseSearch(Sender); Exit; end;
  if FFullSource=nil then FullSourceClick(nil);
  if FPagedView<>nil then begin
    FFullSource.Show; FFullSource.BringToFront; FFullSource.RevealOffset(FPagedView.ViewOffset); Exit;
  end;
  Anchor:=CapturePreviewAnchor; Offset:=0;
  if Anchor.UseCaret then Offset:=Document.SourceOffset(Anchor.Block,FormulaEditor.SourceCaret)
  else if PreambleContentVisible and (Scroll.VertScrollBar.Position<FPreamblePanel.DocumentOrigin.Y+FPreamblePanel.Height) then
    Offset:=Max(0,FPreambleFields.SourceOffset(PreambleEditor.SourceCaret))
  else begin
    Y:=Scroll.VertScrollBar.Position+16;
    for I:=0 to High(Cards) do if Cards[I].DocumentTop+Cards[I].MeasuredHeight>Y then begin
      Offset:=SelectionModelFor(I).HitOffset(0,Max(0,Y-Cards[I].DocumentTop-Cards[I].Image.Top));
      Offset:=Document.SourceOffset(I,Offset); Break;
    end;
  end;
  FFullSource.Show; FFullSource.BringToFront; FFullSource.RevealOffset(Offset);
end;
procedure TMainForm.LocatePreviewFromSource(Sender:TObject);
var Offset,Index,LocalOffset,Y:Integer; Rects:TSelectionRects;
begin
  if FSplitView<>nil then begin FSplitView.ForwardSearch(Sender); Exit; end;
  if FFullSource=nil then begin FullSourceClick(nil); Exit; end;
  Offset:=FFullSource.ViewOffset;
  if FPagedView<>nil then begin FPagedView.RevealOffset(Offset); BringToFront; Exit; end;
  if Document.PreambleOnly or (Offset<Length(Document.Preamble)) then begin
    FPreviewOnly:=False; SetPreambleExpanded(True); LayoutCards(nil); Y:=0;
  end else begin
    Document.LocateOffset(Offset,Index,LocalOffset); if Index<0 then Exit;
    Y:=Cards[Index].DocumentTop+Cards[Index].Image.Top;
    if (Index=ActiveBlock) and FormulaBox.Visible and (FormulaEditor.SourceCaret=LocalOffset) then
      Y:=Cards[Index].DocumentTop+FormulaBox.Top+FormulaEditor.Top+FormulaEditor.CaretPoint.Y
    else begin
      Rects:=SelectionModelFor(Index).Rects(LocalOffset,Min(Length(Document.Blocks[Index]),LocalOffset+1));
      if Length(Rects)>0 then Inc(Y,Rects[0].Top);
    end;
    Y:=Max(0,Y-Scroll.ClientHeight div 3);
  end;
  SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,Y); BringToFront;
end;
procedure TMainForm.FullSourceChanged(Sender:TObject);
var S,Header:string; Anchor,Focus,Index,Offset,SavedScroll,PrefixSize,Delta:Integer;
begin
  if FSyncingFullSource or FLoading then Exit; S:=FFullSource.SourceEditor.Text;
  if S=Document.Source then Exit;
  if FSplitView<>nil then begin
    Document.ParseFile(S); Modified:=True; Inc(Revision); UpdateTitle;
    FSplitView.Changed; UpdateStatusBar; Exit;
  end;
  if FPagedView<>nil then begin
    FSyncingFullSource:=True;
    try
      FFullSource.Selection(Anchor,Focus);
      { Page view owns its edit history. Keep a separate snapshot only when
        leaving it for a source fragment, so Undo restores the current body. }
      if FPageHistoryStarted and not CompilableTeXDocument(S) then RecordVisualEdit;
      FPagedView.ReplaceSource(S,Anchor,Focus);
      if Document.PreambleOnly then begin
        ContinuousViewClick(nil); PreambleEditor.SetSourceSelection(Anchor,Focus);
      end;
      Modified:=True; UpdateTitle;
    finally FSyncingFullSource:=False; end;
    Exit;
  end;
  FSyncingFullSource:=True; SavedScroll:=Scroll.VertScrollBar.Position;
  try
    FFullSource.Selection(Anchor,Focus); RecordVisualEdit; FReblockQueued:=False;
    S:=SynchronizeReferences(Document.Source,S,Anchor,Focus);
    FFullSource.LoadSource(S,Anchor,Focus);
    Document.ParseFile(S); PrefixSize:=Length(Document.Preamble);
    Header:=SyncDocumentPackages(S);
    Delta:=Length(Header)-PrefixSize; Document.Preamble:=Header;
    if Anchor>=PrefixSize then Inc(Anchor,Delta); if Focus>=PrefixSize then Inc(Focus,Delta);
    FFullSource.LoadSource(Document.Source,Anchor,Focus); Document.LocateOffset(Focus,Index,Offset);
    BuildCards;
    if Document.PreambleOnly then begin
      FPreambleEditing:=True; PreambleEditor.SetSourceSelection(Anchor,Focus);
    end else begin
      EditBlock(Index); FormulaEditor.SetSourceCaret(Offset);
      if Editor.Visible then Editor.LogicalCaretXY:=BytePoint(Document.Blocks[Index],Offset);
    end;
    Modified:=True; UpdateTitle; QueuePreview;
    SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,SavedScroll);
  finally FSyncingFullSource:=False; end;
  FullSourceSelection(Sender);
end;
procedure TMainForm.FullSourceSelection(Sender:TObject);
var Anchor,Focus,A,AO,B,BO,I,SavedScroll:Integer; Ranges:TSourceRanges;
begin
  if FSyncingFullSource or FLoading or (FFullSource=nil) then Exit;
  if FSplitView<>nil then begin UpdateStatusBar; Exit; end;
  FSyncingFullSource:=True; SavedScroll:=Scroll.VertScrollBar.Position;
  try
    FFullSource.Selection(Anchor,Focus);
    if FPagedView<>nil then begin
      if (Min(Anchor,Focus)>=Length(Document.Preamble)) and
         (Max(Anchor,Focus)<=Length(Document.Source)-Length(Document.Ending)) then begin
        FPagedView.SetSourceSelection(Anchor,Focus);
        FPagedView.GetSourceSelection(Anchor,Focus); Ranges:=FPagedView.SelectedSourceRanges;
        if Length(Ranges)>0 then FFullSource.SetSelectedRanges(Ranges,Anchor,Focus)
        else FFullSource.SetSelection(Anchor,Focus);
      end;
      Exit;
    end;
    if Document.PreambleOnly or (Max(Anchor,Focus)<Length(Document.Preamble)) then begin
      AO:=FPreambleFields.DisplayOffset(Anchor); BO:=FPreambleFields.DisplayOffset(Focus);
      if (AO>=0) and (BO>=0) then begin
        FPreviewOnly:=False; SetPreambleExpanded(True); LayoutCards(nil); FPreambleEditing:=True;
        PreambleEditor.SetSourceSelection(AO,BO); RefreshFontControls;
      end;
      ClearDocumentSelection; Exit;
    end;
    if (Min(Anchor,Focus)<Length(Document.Preamble)) or
       (Max(Anchor,Focus)>Length(Document.Source)-Length(Document.Ending)) then begin
      ClearDocumentSelection;
      Exit;
    end;
    Document.LocateOffset(Anchor,A,AO); Document.LocateOffset(Focus,B,BO);
    if ActiveBlock<>B then EditBlock(B);
    FSelectionStartBlock:=A; FSelectionStartOffset:=AO; FSelectionEndBlock:=B; FSelectionEndOffset:=BO;
    if A=B then begin
      for I:=0 to High(Cards) do Cards[I].Image.SetSelection(nil);
      FormulaEditor.SetSourceSelection(AO,BO);
      FormulaEditor.GetSourceSelection(AO,BO);
      FSelectionStartOffset:=AO; FSelectionEndOffset:=BO;
      if FormulaBox.Visible then begin
        if FormulaEditor.SelectingTableCells then begin
          Ranges:=FormulaEditor.SelectedSourceRanges;
          for I:=0 to High(Ranges) do begin Ranges[I].Start:=Document.SourceOffset(A,Ranges[I].Start); Ranges[I].Finish:=Document.SourceOffset(B,Ranges[I].Finish); end;
          FFullSource.SetSelectedRanges(Ranges,Document.SourceOffset(A,AO),Document.SourceOffset(B,BO));
        end else FFullSource.SetSelection(Document.SourceOffset(A,AO),Document.SourceOffset(B,BO));
      end;
      if Editor.Visible then begin Editor.BlockBegin:=BytePoint(Document.Blocks[B],AO); Editor.BlockEnd:=BytePoint(Document.Blocks[B],BO); Editor.LogicalCaretXY:=BytePoint(Document.Blocks[B],BO); end;
    end else UpdateDocumentSelection;
    SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,SavedScroll);
  finally FSyncingFullSource:=False; end;
end;
procedure TMainForm.StatusZoomClick(Sender:TObject);
var Dialog:TZoomDialog;
begin
  Dialog:=TZoomDialog.Create(Self);
  try
    Dialog.Load(PreviewScalePercent,FFitWidth,FFitPage,FPagedView<>nil);
    if Dialog.ShowModal<>mrOK then Exit;
    case Dialog.Mode.ItemIndex of
      1:SetFitWidth;
      2:SetFitPage;
      else SetPreviewPercent(Dialog.Percent.Value);
    end;
    UpdateStatusBar;
  finally Dialog.Free; end;
end;
