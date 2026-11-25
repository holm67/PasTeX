{ SPDX-License-Identifier: GPL-3.0-or-later }
procedure TStatusLabel.DoDrawText(var Bounds:TRect; Flags:Longint);
begin
  { LCL labels add DT_NOCLIP. Long command paths must stop before metrics. }
  DrawText(Canvas.Handle,PChar(Caption),Length(Caption),Bounds,(Flags and not DT_NOCLIP) or DT_END_ELLIPSIS);
end;
procedure TMainForm.InitStatusBar;
var Ini:TIniFile; I:Integer; Item:TMenuItem; Content,Modes:TPanel; Cancel:TSpeedButton;
const Titles:array[0..3] of string=('Command path','Line and column','Word count','Page number');
begin
  FStatusCache:=TEditorStatusCache.Create;
  FStatusPopup:=TPopupMenu.Create(Self); FStatusPopup.Name:='StatusOptions';
  Ini:=TIniFile.Create(GetAppConfigFile(False));
  try
    for I:=0 to High(Titles) do begin
      FStatusShow[I]:=Ini.ReadBool('StatusBar',IntToStr(I),True);
      Item:=TMenuItem.Create(Self); Item.Caption:=Titles[I]; Item.Tag:=I; Item.Checked:=FStatusShow[I];
      Item.OnClick:=@StatusOptionClick; FStatusPopup.Items.Add(Item);
    end;
  finally Ini.Free; end;
  Content:=TPanel.Create(Self); Content.Parent:=Status; Content.Align:=alClient; Content.BevelOuter:=bvNone;
  Content.Caption:='';
  Content.ParentBackground:=True; Content.PopupMenu:=FStatusPopup;
  FStatusActions:=TPanel.Create(Self); FStatusActions.Name:='StatusActions'; FStatusActions.Parent:=Content;
  FStatusActions.Align:=alRight; FStatusActions.Width:=176; FStatusActions.BevelOuter:=bvNone; FStatusActions.Caption:='';
  Modes:=TPanel.Create(Self); Modes.Name:='StatusViews'; Modes.Parent:=FStatusActions; Modes.Align:=alRight;
  Modes.Width:=176; Modes.BevelOuter:=bvNone; Modes.Caption:=''; Modes.PopupMenu:=FStatusPopup;
  for I:=0 to High(FStatusModes) do begin
    FStatusModes[I]:=TSpeedButton.Create(Self); FStatusModes[I].Parent:=Modes;
    FStatusModes[I].SetBounds(2+I*34,1,32,26); FStatusModes[I].Flat:=True; FStatusModes[I].ShowHint:=True;
    case I of
      0:begin FStatusModes[I].Hint:='Visual editor'; FStatusModes[I].OnClick:=@EquationModeClick; end;
      1:begin FStatusModes[I].Hint:='Source editor'; FStatusModes[I].OnClick:=@SourceModeClick; end;
      2:begin FStatusModes[I].Hint:='Continuous layout'; FStatusModes[I].OnClick:=@ContinuousViewClick; end;
      3:begin FStatusModes[I].Hint:='Paged layout'; FStatusModes[I].OnClick:=@PagedViewClick; end;
      4:begin FStatusModes[I].Hint:='Source / compiled PDF'; FStatusModes[I].OnClick:=@SplitViewClick; end;
    end;
    FStatusModes[I].GroupIndex:=70+I; FStatusModes[I].AllowAllUp:=True;
  end;
  RefreshRibbonIcons(Modes);
  FStatusDetails:=TPanel.Create(Self); FStatusDetails.Name:='StatusDetails'; FStatusDetails.Parent:=FStatusActions;
  FStatusDetails.Align:=alLeft; FStatusDetails.BevelOuter:=bvNone;
  FStatusDetails.Caption:='';
  FStatusMetrics:=TStatusLabel.Create(Self); FStatusMetrics.Name:='StatusMetrics'; FStatusMetrics.Parent:=FStatusDetails;
  FStatusMetrics.Align:=alClient; FStatusMetrics.AutoSize:=False; FStatusMetrics.Layout:=tlCenter;
  FStatusMetrics.ShowAccelChar:=False;
  FStatusMetrics.BorderSpacing.Left:=8; FStatusMetrics.BorderSpacing.Right:=8;
  FStatusTrail:=TStatusLabel.Create(Self); FStatusTrail.Name:='StatusCommandPath'; FStatusTrail.Parent:=Content;
  FStatusTrail.Align:=alClient; FStatusTrail.AutoSize:=False; FStatusTrail.Layout:=tlCenter;
  FStatusTrail.BorderSpacing.Left:=8; FStatusTrail.ShowHint:=True; FStatusTrail.ShowAccelChar:=False;
  FToolPanel:=TPanel.Create(Self); FToolPanel.Name:='ExternalToolProgress'; FToolPanel.Parent:=FStatusActions;
  FToolPanel.Align:=alClient; FToolPanel.BevelOuter:=bvNone; FToolPanel.Caption:=''; FToolPanel.Visible:=False;
  Cancel:=TSpeedButton.Create(Self); Cancel.Name:='CancelExternalTool'; Cancel.Parent:=FToolPanel;
  Cancel.Align:=alRight; Cancel.Width:=26; Cancel.Caption:='×'; Cancel.Hint:='Cancel external tool'; Cancel.ShowHint:=True; Cancel.OnClick:=@CancelToolClick;
  FToolProgress:=TProgressBar.Create(Self); FToolProgress.Parent:=FToolPanel; FToolProgress.Align:=alClient;
  FToolProgress.BorderSpacing.Around:=5; FToolProgress.Style:=pbstMarquee;
  OnToolStatus:=@ToolStatus;
  Status.PopupMenu:=FStatusPopup; FStatusTrail.PopupMenu:=FStatusPopup; FStatusDetails.PopupMenu:=FStatusPopup;
  FStatusMetrics.PopupMenu:=FStatusPopup; ZoomControls.PopupMenu:=FStatusPopup;
  StatusZoom.PopupMenu:=FStatusPopup; StatusZoomLabel.PopupMenu:=FStatusPopup;
  UpdateStatusBar;
end;
procedure TMainForm.ToolStatus(const Title:string; Running:Boolean);
begin
  FToolMessage:=Title; FToolPanel.Visible:=Running;
  FToolMessageUntil:=GetTickCount64+3000; if Running then FToolMessageUntil:=High(QWord);
  UpdateStatusBar;
  if not Running and FCloseAfterTool then begin FCloseAfterTool:=False; Application.QueueAsyncCall(@CloseAfterTool,0); end;
end;
procedure TMainForm.CancelToolClick(Sender:TObject);
begin CancelToolJob; end;
procedure TMainForm.CloseAfterTool(Data:PtrInt);
begin Close; end;
procedure TMainForm.StatusOptionClick(Sender:TObject);
var I:Integer; Ini:TIniFile;
begin
  I:=TMenuItem(Sender).Tag; FStatusShow[I]:=not FStatusShow[I]; SetMenuChecked(TMenuItem(Sender),FStatusShow[I]);
  ForceDirectories(ExtractFileDir(GetAppConfigFile(False)));
  Ini:=TIniFile.Create(GetAppConfigFile(False));
  try Ini.WriteBool('StatusBar',IntToStr(I),FStatusShow[I]); finally Ini.Free; end;
  UpdateStatusBar;
end;
procedure TMainForm.UpdateStatusBar;
var Line,Column,Offset,Block,ActionsWidth,Percent,PDFPage:Integer; PDFX,PDFY:Double;
    Visual:TMathEditor; Trail,Metrics,OwnerPath:string; WasUpdating,SourceMode:Boolean;
begin
  if (FStatusCache=nil) or (Document=nil) or FLoading then Exit;
  if FInlineSubfilesCheck<>nil then begin
    WasUpdating:=FUpdatingRibbon; FUpdatingRibbon:=True;
    try
      FInlineSubfilesCheck.Enabled:=not Document.PreambleOnly and (FileName<>'') and (FSplitView=nil);
      FInlineSubfilesCheck.Checked:=(LinkedProject<>nil) and LinkedProject.Expanded;
      if FindComponent('InlineSubfilesMenu')<>nil then begin
        TMenuItem(FindComponent('InlineSubfilesMenu')).Enabled:=FInlineSubfilesCheck.Enabled;
        SetMenuChecked(TMenuItem(FindComponent('InlineSubfilesMenu')),FInlineSubfilesCheck.Checked);
      end;
    finally FUpdatingRibbon:=WasUpdating; end;
  end;
  if (FAddonsTab<>nil) and (Ribbon.ActivePage=FAddonsTab) then ResizeAddons(nil);
  FStatusCache.Refresh(Document,Revision); Block:=ActiveBlock; Offset:=0; Trail:='';
  Visual:=CurrentVisualEditor;
  if FPreambleEditing and (Visual<>nil) then begin Block:=-1; Offset:=FPreambleFields.SourceOffset(Visual.SourceCaret); end
  else if Editor.Visible then Offset:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.LogicalCaretXY])
  else if BodyEditing then Offset:=Visual.SourceCaret;
  FStatusCache.Position(Block,Offset,Line,Column);
  if PluginSourceActive then begin Line:=Editor.LogicalCaretXY.Y; Column:=UTF8Length(Editor.TextBetweenPoints[Point(1,Line),Editor.LogicalCaretXY])+1; end;
  if FPagedView<>nil then begin
    Offset:=FPagedView.SourceOffset; Document.LocateOffset(Offset,Block,Offset); FStatusCache.Position(Block,Offset,Line,Column);
  end;
  if Editor.Visible and not FPreambleEditing then Trail:=FSourceCommandPath
  else if (Visual<>nil) and (BodyEditing or FPreambleEditing) then Trail:=Visual.CurrentCommandPath;
  if (Visual<>nil) and (Visual.MathShortcutHint<>'') then Trail:=Visual.MathShortcutHint;
  if (LinkedProject<>nil) and LinkedProject.Expanded then begin
    if FPagedView<>nil then Offset:=FPagedView.SourceOffset
    else Offset:=Document.SourceOffset(Block,Offset);
    OwnerPath:=LinkedProject.FileAt(Offset,Offset);
    if not SameFileName(OwnerPath,FileName) then begin
      if Trail<>'' then Trail:=' · '+Trail;
      Trail:=ExtractRelativePath(ExtractFilePath(FileName),OwnerPath)+Trail;
    end;
  end;
  if (FFullSource<>nil) and FFullSource.Visible and ((FSplitView<>nil) or FFullSource.SourceEditor.Focused) then begin
    Line:=FFullSource.SourceEditor.LogicalCaretXY.Y;
    Column:=UTF8Length(FFullSource.SourceEditor.TextBetweenPoints[Point(1,Line),FFullSource.SourceEditor.LogicalCaretXY])+1;
  end;
  FStatusTrail.Visible:=FStatusShow[0] or (GetTickCount64<FToolMessageUntil);
  if GetTickCount64<FToolMessageUntil then FStatusTrail.Caption:=FToolMessage
  else if Trail='' then FStatusTrail.Caption:=StatusText else FStatusTrail.Caption:=Trail;
  FStatusTrail.Hint:=FStatusTrail.Caption; Metrics:='';
  if FStatusShow[1] then Metrics:=Format('Ln %d, Col %d',[Line,Column]);
  if FStatusShow[2] then begin
    if Metrics<>'' then Metrics:=Metrics+'  ·  '; Metrics:=Metrics+IntToStr(FStatusCache.Words)+' words';
  end;
  if FStatusShow[3] and (FPagedView<>nil) then begin
    if Metrics<>'' then Metrics:=Metrics+'  ·  ';
    Metrics:=Metrics+Format('Page %d of %d',[FPagedView.CurrentPage,FPagedView.PageCount]);
  end;
  if FStatusShow[3] and (FSplitView<>nil) and (FSplitView.Preview.PageCount>0) then begin
    FSplitView.Preview.ViewLocation(PDFPage,PDFX,PDFY);
    if Metrics<>'' then Metrics:=Metrics+'  ·  ';
    Metrics:=Metrics+Format('Page %d of %d',[PDFPage,FSplitView.Preview.PageCount]);
  end;
  FStatusMetrics.Caption:=Metrics;
  FStatusMetrics.Canvas.Font:=FStatusMetrics.Font;
  ActionsWidth:=176+Ord(FToolPanel.Visible)*132;
  FStatusActions.DisableAlign;
  try
    FStatusDetails.Visible:=Metrics<>'';
    FStatusDetails.Width:=Min(Max(0,FStatusActions.Parent.ClientWidth-ActionsWidth-74),FStatusMetrics.Canvas.TextWidth(Metrics)+20);
    if FStatusDetails.Visible then Inc(ActionsWidth,FStatusDetails.Width);
    FStatusActions.Width:=ActionsWidth;
  finally FStatusActions.EnableAlign; end;
  SourceMode:=(FSplitView<>nil) or Editor.Visible or ((FPagedView<>nil) and Visual.CodeOnly);
  FStatusModes[0].Down:=not SourceMode; FStatusModes[1].Down:=SourceMode;
  FStatusModes[2].Down:=(FPagedView=nil) and (FSplitView=nil); FStatusModes[3].Down:=FPagedView<>nil;
  FStatusModes[4].Down:=FSplitView<>nil;
  Percent:=PreviewScalePercent; WasUpdating:=FUpdatingZoom; FUpdatingZoom:=True;
  try StatusZoom.Position:=Percent; StatusZoomLabel.Caption:=IntToStr(Percent)+'%';
  finally FUpdatingZoom:=WasUpdating; end;
  SyncQuickAccess;
end;
