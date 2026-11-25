{ SPDX-License-Identifier: GPL-3.0-or-later }
procedure TMainForm.InitExtendedWorkspace;
var Tools,Group,Item:TMenuItem; I:Integer;
  procedure Command(Root:TMenuItem; const Title,Name:string; Handler:TNotifyEvent; Key:TShortCut=0);
  begin Item:=TMenuItem.Create(Self); Item.Caption:=Title; Item.Name:=Name; Item.OnClick:=Handler; Item.ShortCut:=Key; Root.Add(Item); end;
begin
  Command(ViewMenu,'Focus / fullscreen','FocusModeMenu',@FocusModeClick,ShortCut(VK_F11,[]));
  Command(ViewMenu,'Paged layout','PagedEditorMenu',@PagedViewClick,ShortCut(VK_P,[ssCtrl,ssAlt]));
  Command(ViewMenu,'Continuous layout','ContinuousEditorMenu',@ContinuousViewClick);
  Command(ViewMenu,'Subfiles in place','InlineSubfilesMenu',@ToggleInlineSubfiles);
  Command(FileMenu,'Export as LaTeX…','ExportPluginTeXMenu',@ExportPluginTeX); Item.Visible:=False;
  FFormatMenu:=TMenuItem.Create(Self); FFormatMenu.Caption:='Other document formats'; FileMenu.Add(FFormatMenu);
  Command(FileMenu,'Import document…','ImportDocumentMenu',@ImportDocumentClick);
  Command(FileMenu,'Export project ZIP…','ExportProjectMenu',@ExportProjectClick);
  Command(InsertMenu,'Spreadsheet data…','ImportDataMenu',@ImportDataClick);
  Group:=TMenuItem.Create(Self); Group.Caption:='Notes'; InsertMenu.Add(Group);
  Command(Group,'Footnote','InsertFootnoteMenu',@FootnoteClick); Item.Tag:=0;
  Command(Group,'Footnote mark','InsertFootnoteMarkMenu',@FootnoteClick); Item.Tag:=1;
  Command(Group,'Footnote text','InsertFootnoteTextMenu',@FootnoteClick); Item.Tag:=2;
  Command(Group,'Margin note','InsertMarginNoteMenu',@FootnoteClick); Item.Tag:=3;
  Tools:=nil; for I:=0 to AppMenu.Items.Count-1 do if StringReplace(AppMenu.Items[I].Caption,'&','',[rfReplaceAll])='Tools' then Tools:=AppMenu.Items[I];
  if Tools=nil then begin Tools:=TMenuItem.Create(Self); Tools.Caption:='&Tools'; AppMenu.Items.Insert(AppMenu.Items.Count-1,Tools); end;
  Command(Tools,'Add-ons and external tools…','AddonsMenu',@AddonsClick);
  Command(Tools,'Keyboard shortcuts…','ShortcutsMenu',@ShortcutsClick);
  FFocusExit:=TSpeedButton.Create(Self); FFocusExit.Name:='StatusFullscreen'; FFocusExit.Parent:=Status;
  FFocusExit.Align:=alRight; FFocusExit.Left:=Status.ClientWidth; FFocusExit.Width:=32;
  FFocusExit.Flat:=True; FFocusExit.GroupIndex:=98; FFocusExit.AllowAllUp:=True;
  FFocusExit.Hint:='Fullscreen (F11)'; FFocusExit.ShowHint:=True; FFocusExit.OnClick:=@FocusModeClick;
  RefreshRibbonIcons(Status);
  ExitMenuItem.MenuIndex:=FileMenu.Count-1;
  RefreshAddonsRibbon;
  LoadEditorShortcuts(AppMenu);
end;
procedure TMainForm.FocusModeClick(Sender:TObject);
begin
  DisableAlign;
  try
  if not FFocusMode then begin
    FFocusBounds:=BoundsRect; FFocusState:=WindowState; FFocusNavigation:=FNavigation.Visible;
    FFocusRibbon:=Ribbon.Visible; FFocusQuick:=QuickAccessBar.Visible; FFocusTabs:=FileTabs.Visible;
    FFocusMode:=True; FNavigation.Visible:=False; Ribbon.Visible:=False; QuickAccessBar.Visible:=False; FileTabs.Visible:=False;
    Menu:=nil; WindowState:=wsFullScreen;
  end else begin
    FFocusMode:=False; Menu:=AppMenu; WindowState:=wsNormal; BoundsRect:=FFocusBounds; WindowState:=FFocusState;
    FNavigation.Visible:=FFocusNavigation; Ribbon.Visible:=FFocusRibbon; QuickAccessBar.Visible:=FFocusQuick; FileTabs.Visible:=FFocusTabs;
    UpdateRibbonVisibility;
    QuickAccessBar.Top:=0; Ribbon.Top:=QuickAccessBar.Height; FileTabs.Top:=Ribbon.Top+Ribbon.Height;
  end;
  finally EnableAlign; end;
  FFocusExit.Down:=FFocusMode; SetMenuChecked(TMenuItem(FindComponent('FocusModeMenu')),FFocusMode);
  LayoutCards(nil); UpdateStatusBar;
end;
procedure TMainForm.PagedViewClick(Sender:TObject);
begin
  if DeferInput(@PagedViewClick,Sender) then Exit;
  ExitSplitView;
  CurrentVisualEditor.FinishDefinitionEdit;
  if Document.PreambleOnly then begin StatusText:='Open a compilable document for paged layout.'; Exit; end;
  if FPluginSourceDue<>0 then RefreshPluginSource;
  FContinuousEditor.CancelSelectionDrag; ClearDocumentSelection; FormulaBox.Visible:=False; FPreambleEditing:=False;
  if SourceTools<>nil then SourceTools.Visible:=False;
  if SourceGrip<>nil then SourceGrip.Visible:=False;
  if FPagedView=nil then begin
    FPageHistoryStarted:=False;
    FPagedView:=TPagedEditor.Create(Self); FPagedView.Name:='PagedEditor'; FPagedView.Parent:=Self; FPagedView.Align:=alClient;
    FPagedView.OnChange:=@PagedSourceChanged; FPagedView.OnSelectionChange:=@PagedSelectionChanged;
    FPagedView.OnGeneratedAction:=@GeneratedAction;
    FPagedView.OnSourceLink:=@VisualLinkClick;
    FPagedView.PopupMenu:=EditPopup;
    FPagedView.ReadOnly:=PluginSourceActive;
    FPagedView.ConfigureSourceFont(Editor.Font); FPagedView.Load(Document.Source,DocumentDirectory,Engine.Text);
    UpdateLinkedBoundaries;
  end;
  FPagedView.SetZoom(FPreviewPercent,FFitWidth,FFitPage); FPagedView.Visible:=True;
  FUpdatingRibbon:=True; try SelectZoom(ZoomChoice,FPreviewPercent); finally FUpdatingRibbon:=False; end;
  Scroll.Visible:=False; Editor.Visible:=PluginSourceActive; Pending:=False; Inc(Revision); if Worker<>nil then Worker.Terminate;
  TOpenDocument(FSessions[FSessionIndex]).PageMode:=True; UpdateStatusBar;
  StatusText:='Native paged layout · click text or formulas to edit';
end;
function TMainForm.RestoreContinuousWorkspace:Integer;
var WasBusy:Boolean;
begin
  Result:=0; if FPagedView=nil then Exit;
  FPagedView.VisualEditor.FinishCommand; Result:=FPagedView.SourceOffset;
  WasBusy:=FLayoutBusy; FLayoutBusy:=True; DisableAlign;
  try
    { GTK can resize immediately when aligned controls disappear. Rebuild the
      paragraph cards before exposing the continuous workspace to layout. }
    FreeAndNil(FPagedView); Document.ParseFile(Document.Source); BuildCards;
    Scroll.Visible:=True;
  finally
    try EnableAlign; finally FLayoutBusy:=WasBusy; end;
  end;
  LayoutCards(nil);
end;
procedure TMainForm.ContinuousViewClick(Sender:TObject);
var Index,Offset,SavedOffset:Integer;
begin
  ExitSplitView;
  if FPagedView<>nil then begin
    SavedOffset:=RestoreContinuousWorkspace;
    if not PluginSourceActive and not Document.PreambleOnly then begin
      Document.LocateOffset(SavedOffset,Index,Offset); EquationMode:=True; EditBlock(Index); FormulaEditor.SetSourceCaret(Offset);
    end else if PluginSourceActive then ShowPluginSourceEditor;
    QueuePreview;
  end;
  if (FSessions<>nil) and (FSessionIndex>=0) then TOpenDocument(FSessions[FSessionIndex]).PageMode:=False;
  FFitPage:=False; FUpdatingRibbon:=True; try SelectZoom(ZoomChoice,FPreviewPercent); finally FUpdatingRibbon:=False; end;
  Scroll.Visible:=True; UpdateStatusBar;
end;
procedure TMainForm.PagedSourceChanged(Sender:TObject);
begin
  if FLoading or PluginSourceActive then Exit;
  if not FPageHistoryStarted then begin RecordVisualEdit; FPageHistoryStarted:=True; end;
  if (FPagedView.ChangedBlock>=0) and (Document.Blocks.Count=FPagedView.BlockCount) then
    Document.Blocks[FPagedView.ChangedBlock]:=FPagedView.ParagraphEditor(FPagedView.ChangedBlock).Formula
  else Document.ParseFile(FPagedView.Source);
  SyncLinkedSource;
  Inc(Revision); Modified:=True; FDocumentRefreshDue:=GetTickCount64+150; UpdateTitle; SyncFullSource(True);
end;
procedure TMainForm.PagedSelectionChanged(Sender:TObject);
begin
  if FLoading or (csDestroying in ComponentState) or (FPagedView=nil) or (Sender<>FPagedView) then Exit;
  UpdateContextTabs(FormulaEditor.MathActive,FormulaEditor.EditingTable or
    (Pos('\begin{table',FormulaEditor.CurrentFloatSource)=1),FormulaEditor.EditingTheorem,
    not FormulaEditor.SelectionGesture,FormulaEditor.EditingFigure);
  RefreshFields; RefreshFontControls; UpdateParagraphControl(FormulaEditor.CurrentParagraphStyle); UpdateStatusBar; SyncFullSource;
end;
procedure TMainForm.ExportPluginTeX(Sender:TObject);
var D:TSaveDialog; Lines:TStringList; Preview,Error:string;
begin
  if not PluginSourceActive then Exit;
  if not RenderExtensionDocument(TOpenDocument(FSessions[FSessionIndex]).FormatID,Editor.Text,DocumentDirectory,Preview,Error) then begin
    MessageDlg(Error,mtError,[mbOK],0); Exit;
  end;
  D:=TSaveDialog.Create(Self); Lines:=TStringList.Create;
  try D.Filter:='LaTeX document|*.tex'; D.DefaultExt:='tex'; D.FileName:=ChangeFileExt(FileName,'.tex'); D.Options:=[ofOverwritePrompt,ofPathMustExist];
    if D.Execute then begin Lines.Text:=Preview; Lines.SaveToFile(D.FileName); end;
  finally Lines.Free; D.Free; end;
end;
procedure TMainForm.InsertBodySource(const Value:string);
begin
  if Value='' then Exit;
  if FPagedView<>nil then begin FormulaEditor.InsertBody(Value,Length(Value)); Exit; end;
  if FPreambleEditing then PreambleEditor.InsertTeX(Value)
  else if Editor.Visible then Editor.SelText:=Value
  else begin if not BodyEditing then EquationModeClick(nil); FormulaEditor.InsertBody(Value,Length(Value)); end;
end;
function TMainForm.EditingMath:Boolean;
var Spans:TMathSpans; Span:TMathSpan; Offset:Integer;
begin
  if FPreambleEditing then Exit(False);
  if not Editor.Visible then Exit(FormulaEditor.MathActive);
  Result:=False; Offset:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.LogicalCaretXY]); Spans:=FindMath(Editor.Text);
  for Span in Spans do if (Offset>=Span.Start-1) and (Offset<=Span.Start+Span.Count-1) then Exit(True);
end;
procedure TMainForm.AddonsClick(Sender:TObject);
var Form:TAddonForm; Value,BeforeHooks:string; A,B:Integer;
  function HookSignature:string;
  var Steps:TJSONArray;
  begin Steps:=ExtensionCompileSteps; try Result:=Steps.AsJSON; finally Steps.Free; end; end;
begin
  if DeferInput(@AddonsClick,Sender) then Exit;
  BeforeHooks:=HookSignature;
  Form:=TAddonForm.Create(Self);
  try
    Value:=SelectedDocumentText; if Editor.Visible then Value:=Editor.SelText;
    if FPreambleEditing then begin PreambleEditor.GetSourceSelection(A,B); Value:=Copy(PreambleEditor.Formula,Min(A,B)+1,Abs(B-A)); end;
    Form.Load(FileName,Value);
    if (Sender is TControl) and (Copy(TControl(Sender).HelpKeyword,1,10)='configure:') then
      Form.SelectPlugin(Copy(TControl(Sender).HelpKeyword,11,MaxInt));
    if Form.ShowModal=mrOK then begin
      Value:=Form.InsertText; if Value='' then Exit; if not Form.InsertAsTeX then Value:=EscapeTeXText(Value);
      if Form.InsertAsMath and EditingMath then begin if Editor.Visible then Editor.SelText:=Value else FormulaEditor.InsertTeX(Value); end
      else begin if Form.InsertAsMath then Value:='$'+Value+'$'; InsertBodySource(Value); end;
    end;
  finally
    Form.Free; RefreshAddonsRibbon;
    if PluginSourceActive then RefreshPluginSource;
    if BeforeHooks<>HookSignature then QueuePreview;
  end;
end;
procedure TMainForm.ShortcutsClick(Sender:TObject);
var Form:TShortcutsForm;
begin Form:=TShortcutsForm.Create(Self); try Form.Load(AppMenu); Form.ShowModal; finally Form.Free; end; end;
procedure TMainForm.ImportDataClick(Sender:TObject);
var D:TOpenDialog; Form:TSpreadsheetForm;
begin
  if DeferInput(@ImportDataClick,Sender) then Exit;
  if EditingMath or FPreambleEditing or Document.PreambleOnly then begin StatusText:='Insert a table in body text, outside an equation.'; Exit; end;
  D:=TOpenDialog.Create(Self);
  try
    D.Filter:='Spreadsheet data|*.xlsx;*.ods;*.gnumeric;*.csv;*.tsv'; if not D.Execute then Exit;
    Form:=TSpreadsheetForm.Create(Self);
    try Form.Load(D.FileName); if Form.ShowModal=mrOK then InsertBodySource(Form.TableSource);
    except on E:Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
    Form.Free;
  finally D.Free; end;
end;
procedure TMainForm.ImportDocumentClick(Sender:TObject);
var D:TOpenDialog; Save:TSaveDialog; Job:TToolJob; Lines:TStringList; SourcePath,Destination,Ext,Temp,Input,Report:string; G:TGUID; Entry:TSearchRec;
begin
  if DeferInput(@ImportDocumentClick,Sender) then Exit;
  D:=TOpenDialog.Create(Self); Save:=TSaveDialog.Create(Self); Job:=TToolJob.Create; Lines:=TStringList.Create; Temp:='';
  try
  try
    D.Filter:='Importable documents|*.doc;*.docx;*.odt;*.rtf;*.lyx'; if not D.Execute then Exit; SourcePath:=ExpandFileName(D.FileName);
    Save.Filter:='LaTeX document|*.tex'; Save.DefaultExt:='tex'; Save.FileName:=ChangeFileExt(SourcePath,'.tex'); Save.Options:=[ofOverwritePrompt,ofPathMustExist]; if not Save.Execute then Exit;
    Destination:=ExpandFileName(Save.FileName); if SameFileName(SourcePath,Destination) then raise Exception.Create('Choose a different destination; the original document must be preserved.');
    Ext:=LowerCase(ExtractFileExt(SourcePath)); Input:=SourcePath; Report:='Converted to LaTeX';
    if Ext='.lyx' then begin
      Job.Add('lyx',ExtractFileDir(SourcePath),['--export-to','latex',Destination,SourcePath]);
      if not RunToolJob(Self,Job,'Import LyX') then raise Exception.Create(Job.ErrorText+#10+Copy(Job.Output,1,1500));
    end else begin
      if (Ext='.doc') or (Ext='.odt') or (Ext='.rtf') then begin
        CreateGUID(G); Temp:=IncludeTrailingPathDelimiter(GetTempDir(False))+'pastex-import-'+GUIDToString(G); ForceDirectories(Temp);
        Job.Add('libreoffice',ExtractFileDir(SourcePath),['-env:UserInstallation='+FilenameToURI(Temp+DirectorySeparator+'profile'),
          '--headless','--convert-to','docx','--outdir',Temp,SourcePath]);
        if not RunToolJob(Self,Job,'Convert document') then raise Exception.Create(Job.ErrorText+#10+Copy(Job.Output,1,1500));
        Input:=IncludeTrailingPathDelimiter(Temp)+ChangeFileExt(ExtractFileName(SourcePath),'.docx');
        if not FileExists(Input) then raise Exception.Create('LibreOffice did not produce a DOCX file. Check the installed conversion filters.');
        FreeAndNil(Job); Job:=TToolJob.Create;
      end;
      if FindTool('pandoc')<>'' then begin
        Job.Add('pandoc',ExtractFileDir(Destination),['--from=docx','--to=latex','--standalone',
          '--extract-media='+ChangeFileExt(ExtractFileName(Destination),'-media'),'--output='+Destination,Input]);
        if not RunToolJob(Self,Job,'Import document') then raise Exception.Create(Job.ErrorText+#10+Copy(Job.Output,1,1500));
      end else begin Lines.Text:=WordToTeX(Input,Report); Lines.SaveToFile(Destination); end;
    end;
    if not FileExists(Destination) then raise Exception.Create('The converter did not create a TeX file');
    LoadDocument(Destination); StatusText:=Report;
    if Pos('omitted',Report)>0 then MessageDlg(Report,mtInformation,[mbOK],0);
  except on E:Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
  finally
    if Temp<>'' then begin
      if FindFirst(IncludeTrailingPathDelimiter(Temp)+'*',faAnyFile,Entry)=0 then begin
        repeat if (Entry.Attr and faDirectory)=0 then DeleteFile(IncludeTrailingPathDelimiter(Temp)+Entry.Name); until FindNext(Entry)<>0; FindClose(Entry);
      end;
      { LibreOffice's isolated profile is confined to this temporary directory. }
      DeleteDirectory(Temp,False);
    end;
    Job.Free; Lines.Free; Save.Free; D.Free;
  end;
end;
procedure TMainForm.ExportProjectClick(Sender:TObject);
var D:TSaveDialog; Zip:TZipper; Root,Destination:string; Total:Int64; Count:Integer;
  procedure AddDirectory(const Directory,Relative:string; Depth:Integer);
  var Entry:TSearchRec; Path,Name,Ext:string;
  begin
    if Depth>16 then Exit;
    if FindFirst(IncludeTrailingPathDelimiter(Directory)+'*',faAnyFile,Entry)<>0 then Exit;
    try repeat
      Name:=Entry.Name; if (Name='') or (Name[1]='.') or (Name='bin') or (Name='backup') or ((Entry.Attr and faSymLink)<>0) then Continue;
      Path:=IncludeTrailingPathDelimiter(Directory)+Name;
      if (Entry.Attr and faDirectory)<>0 then AddDirectory(Path,Relative+Name+'/',Depth+1)
      else begin
        Ext:=LowerCase(ExtractFileExt(Name));
        if SameFileName(Path,ChangeFileExt(FileName,'.pdf')) then Continue;
        if (Pos('|'+Ext+'|','|.tex|.bib|.sty|.cls|.bst|.bbx|.cbx|.lbx|.def|.fd|.otf|.ttf|.png|.jpg|.jpeg|.pdf|.svg|.eps|.csv|.tsv|.dat|.txt|.json|.md|.py|.r|.m|')=0) or SameFileName(Path,Destination) then Continue;
        Inc(Count); Inc(Total,Entry.Size); if (Count>10000) or (Total>256*1024*1024) then raise Exception.Create('Project ZIP exceeds 10,000 files or 256 MB. Export a smaller project folder.');
        Zip.Entries.AddFileEntry(Path,Relative+Name);
      end;
    until FindNext(Entry)<>0; finally FindClose(Entry); end;
  end;
begin
  if (FileName='') or Modified then if not SaveDocument(False) then Exit;
  D:=TSaveDialog.Create(Self); Zip:=TZipper.Create;
  try
  try
    D.Filter:='Project ZIP|*.zip'; D.DefaultExt:='zip'; D.FileName:=ChangeFileExt(FileName,'.zip'); D.Options:=[ofOverwritePrompt,ofPathMustExist];
    if not D.Execute then Exit; Destination:=ExpandFileName(D.FileName); Root:=DocumentDirectory; Count:=0; Total:=0;
    AddDirectory(Root,'',0); Zip.FileName:=Destination; Zip.ZipAllFiles; StatusText:='Exported '+IntToStr(Count)+' project files. Project source and assets exported.';
  except on E:Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
  finally Zip.Free; D.Free; end;
end;
procedure TMainForm.FootnoteClick(Sender:TObject);
const Commands:array[0..3] of string=('footnote','footnotemark','footnotetext','marginpar');
var ID:Integer; Value:string;
begin
  if DeferInput(@FootnoteClick,Sender) then Exit;
  if EditingMath or FPreambleEditing or Document.PreambleOnly then begin StatusText:='Insert notes in body text.'; Exit; end;
  ID:=EnsureRange(TComponent(Sender).Tag,0,3); Value:='\'+Commands[ID];
  if ID=1 then Value:=Value+'{}'
  else begin if Editor.Visible then Value:=Value+'{'+Editor.SelText+'}' else Value:=Value+'{'+SelectedDocumentText+'}'; end;
  InsertBodySource(Value);
  if BodyEditing and (ID<>1) then FormulaEditor.SetSourceCaret(Max(0,FormulaEditor.SourceCaret-1));
end;
