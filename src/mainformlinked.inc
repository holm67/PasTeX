{ SPDX-License-Identifier: GPL-3.0-or-later }
function TMainForm.LinkedProject:TLinkedSource;
begin
  Result:=nil;
  if (FSessions<>nil) and (FSessionIndex>=0) and (FSessionIndex<FSessions.Count) then
    Result:=TOpenDocument(FSessions[FSessionIndex]).Linked;
end;
function TMainForm.FileDocumentSource(Session:TOpenDocument):string;
begin
  if Session.Linked<>nil then Result:=Session.Linked.FileSource(Session.Linked.Root)
  else Result:=Session.Document.Source;
end;
function TMainForm.SyncLinkedSource:Boolean;
var Linked:TLinkedSource; Error,Value:string;
begin
  Result:=True; if FSyncingLinked or FLoading then Exit;
  Linked:=LinkedProject; if Linked=nil then Exit;
  Value:=Document.Source; FSyncingLinked:=True;
  try
    Result:=Linked.Apply(Value,Error);
    if Value<>Linked.Text then begin
      Document.ParseFile(Linked.Text);
      if not FLinkedRefreshQueued then begin FLinkedRefreshQueued:=True; Application.QueueAsyncCall(@LinkedSourceReady,0); end;
    end;
    if not Result then begin FToolMessage:=Error; FToolMessageUntil:=GetTickCount64+8000; StatusText:=Error; end;
  finally FSyncingLinked:=False; end;
  UpdateLinkedBoundaries;
end;
procedure TMainForm.LinkedSourceReady(Data:PtrInt);
var Offset,Index,Local,Y:Integer;
begin
  FLinkedRefreshQueued:=False; if LinkedProject=nil then Exit;
  FReblockQueued:=False; FSyncingLinked:=True;
  try
    if FPagedView<>nil then begin
      Offset:=FPagedView.SourceOffset; FPagedView.ReplaceSource(Document.Source,Offset,Offset);
    end else begin
      Y:=Scroll.VertScrollBar.Position; Offset:=Document.SourceOffset(ActiveBlock,FormulaEditor.SourceCaret);
      BuildCards; Document.LocateOffset(Offset,Index,Local);
      if Index>=0 then begin EditBlock(Index); FormulaEditor.SetSourceCaret(Local); end;
      SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,Y);
    end;
  finally FSyncingLinked:=False; end;
  QueuePreview;
end;
procedure TMainForm.ToggleInlineSubfiles(Sender:TObject);
var Linked:TLinkedSource; P:TTeXProject; Session:TOpenDocument; Source:string;
begin
  if FUpdatingRibbon or FLoading or DeferInput(@ToggleInlineSubfiles,Sender) then Exit;
  if not SyncLinkedSource then Exit;
  FRestoreInlineSubfiles:=False; ExitSplitView; CurrentVisualEditor.FinishCommand;
  Session:=TOpenDocument(FSessions[FSessionIndex]); Linked:=Session.Linked;
  if Linked=nil then begin
    if (FileName='') or Document.PreambleOnly then begin UpdateStatusBar; Exit; end;
    P:=Project;
    try
      Linked:=TLinkedSource.Create; Linked.Load(Document.Source,FileName,P);
      if Linked.Files.Count<=1 then begin Linked.Free; StatusText:='This document has no readable body subfiles.'; UpdateStatusBar; Exit; end;
      Session.Linked:=Linked;
    finally P.Free; end;
  end else begin
    Linked.SetExpanded(not Linked.Expanded);
    if Linked.Expanded then begin P:=Project; try Linked.Refresh(P); finally P.Free; end; end;
  end;
  Source:=Linked.Text; FReblockQueued:=False; FVisualUndo.Clear; FVisualRedo.Clear;
  Document.ParseFile(Source);
  if FPagedView<>nil then FPagedView.Load(Source,DocumentDirectory,Engine.Text)
  else BuildCards;
  UpdateLinkedBoundaries;
  QueuePreview;
  if FFullSource<>nil then FFullSource.SourceEditor.ClearUndo;
  UpdateStatusBar;
end;
procedure TMainForm.UpdateLinkedBoundaries;
var I,Index,Local:Integer; Panel:TPreviewPanel; Ranges:TSourceRanges;
begin
  FLinkedBoundaries:=nil; FFoldedSources:=nil;
  if LinkedProject<>nil then begin
    FLinkedBoundaries:=LinkedProject.Boundaries; FFoldedSources:=LinkedProject.CollapsedRanges;
  end;
  if FPagedView=nil then for I:=0 to Min(High(Cards),Document.Blocks.Count-1) do begin
    Local:=Document.SourceOffset(I,0);
    Ranges:=ClipSourceRanges(FFoldedSources,Local,Length(Document.Blocks[I]));
    Cards[I].Folded:=SourceCovered(Document.Blocks[I],Ranges); Cards[I].PartlyFolded:=Length(Ranges)>0;
    if Cards[I].Draft<>nil then Cards[I].Draft.SetFoldedRanges(FFoldedSources,Local,Length(Document.Blocks[I]));
    if I=ActiveBlock then FormulaEditor.SetFoldedRanges(FFoldedSources,Local,Length(Document.Blocks[I]));
  end;
  while Length(FLinkedBoundaryPanels)>Length(FLinkedBoundaries) do begin
    FLinkedBoundaryPanels[High(FLinkedBoundaryPanels)].Free;
    SetLength(FLinkedBoundaryPanels,Length(FLinkedBoundaryPanels)-1);
  end;
  while Length(FLinkedBoundaryPanels)<Length(FLinkedBoundaries) do begin
    I:=Length(FLinkedBoundaryPanels); SetLength(FLinkedBoundaryPanels,I+1);
    Panel:=TPreviewPanel.Create(Self); FLinkedBoundaryPanels[I]:=Panel; Panel.Parent:=Scroll;
    Panel.Name:='SubfileBoundary'+IntToStr(I); Panel.Caption:=''; Panel.DoubleSeparator:=True;
    Panel.BevelOuter:=bvNone; Panel.ParentBackground:=False; Panel.Cursor:=crHandPoint;
    Panel.OnMouseDown:=@SubfileBoundaryClick; Panel.Hint:='Click to show/hide; Ctrl+click to open the subfile'; Panel.ShowHint:=True;
  end;
  for I:=0 to High(FLinkedBoundaryPanels) do begin
    Panel:=FLinkedBoundaryPanels[I]; Panel.Color:=PaperColor;
    Panel.SeparatorCaption:=FLinkedBoundaries[I].Caption; Panel.HelpKeyword:=FLinkedBoundaries[I].Path;
    Panel.HelpContext:=Ord(FLinkedBoundaries[I].Ending);
    Document.LocateOffset(Max(0,FLinkedBoundaries[I].Offset-Ord(FLinkedBoundaries[I].Ending)),Index,Local);
    Panel.Tag:=Index;
  end;
  if FPagedView<>nil then begin
    FPagedView.OnBoundaryClick:=@SubfileBoundaryClick;
    FPagedView.SetSourceBoundaries(FLinkedBoundaries,FFoldedSources);
  end;
end;
procedure TMainForm.PlaceLinkedBoundaries(Block:Integer; Ending:Boolean; var Y:Integer; X,AWidth:Integer);
var I:Integer;
begin
  for I:=0 to High(FLinkedBoundaries) do if (FLinkedBoundaryPanels[I].Tag=Block) and (FLinkedBoundaries[I].Ending=Ending) then begin
    FLinkedBoundaryPanels[I].SetDocumentBounds(X,Y,AWidth,28); Inc(Y,28);
    FLinkedBoundaryPanels[I].Visible:=not FPreviewOnly; FLinkedBoundaryPanels[I].Invalidate;
    if FLinkedBoundaryPanels[I].Visible then FLinkedBoundaryPanels[I].BringToFront;
  end;
end;
procedure TMainForm.SubfileBoundaryClick(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
begin
  if Button<>mbLeft then Exit;
  if not (ssCtrl in Shift) then begin
    if (TControl(Sender).HelpContext<>0) or (FSubfileTogglePath<>'') then Exit;
    FSubfileTogglePath:=TControl(Sender).HelpKeyword; FSubfileToggleRoot:=FileName;
    Application.QueueAsyncCall(@ToggleSubfileReady,0); Exit;
  end;
  if FLinkedPath='' then Application.QueueAsyncCall(@OpenLinkedFileAsync,0);
  FLinkedPath:=TControl(Sender).HelpKeyword;
  FLinkedRoot:=TOpenDocument(FSessions[FSessionIndex]).RootName;
  if FLinkedRoot='' then FLinkedRoot:=FileName;
end;
procedure TMainForm.ToggleSubfileReady(Data:PtrInt);
var Path:string; Y:Integer;
begin
  Path:=FSubfileTogglePath; FSubfileTogglePath:='';
  if (LinkedProject=nil) or (FileName<>FSubfileToggleRoot) then Exit;
  CurrentVisualEditor.FinishCommand; if not SyncLinkedSource then Exit;
  LinkedProject.ToggleFile(Path);
  if FPagedView=nil then begin
    Y:=Scroll.VertScrollBar.Position; FormulaBox.Visible:=False; Editor.Visible:=False; ActiveBlock:=-1;
    UpdateLinkedBoundaries; UpdatePreviewCards(0); LayoutCards(nil);
    SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,Y);
  end else UpdateLinkedBoundaries;
end;
procedure TMainForm.SaveLinkedProject(const Path:string);
var Linked:TLinkedSource; DirtyFiles:TStringList; Other:TOpenDocument; I,J:Integer; Value:string;
begin
  Linked:=LinkedProject; DirtyFiles:=TStringList.Create;
  try
    Linked.ChangedFiles(DirtyFiles);
    for I:=0 to FSessions.Count-1 do if I<>FSessionIndex then begin
      Other:=TOpenDocument(FSessions[I]); J:=DirtyFiles.IndexOf(Other.FileName);
      if J<0 then Continue;
      Value:=FileDocumentSource(Other);
      if (Value<>Linked.OriginalSource(Other.FileName)) and (Value<>Linked.FileSource(Other.FileName)) then
        raise Exception.Create('The open tab also changed '+Other.FileName+'. Save or close that tab before saving the project.');
    end;
    Linked.Save(Path);
    for I:=0 to FSessions.Count-1 do if I<>FSessionIndex then begin
      Other:=TOpenDocument(FSessions[I]); if DirtyFiles.IndexOf(Other.FileName)<0 then Continue;
      Value:=Linked.FileSource(Other.FileName); FreeAndNil(Other.Linked);
      Other.Document.ParseFile(Value); Other.Modified:=False; Other.ReloadLinked:=True; Other.NeedsPreview:=True;
      Other.Undo.Clear; Other.Redo.Clear;
    end;
  finally DirtyFiles.Free; end;
end;
