{ SPDX-License-Identifier: GPL-3.0-or-later }
procedure TMainForm.InitWorkspace;
var Item:TMenuItem; Title:TLabel;
  procedure Menu(Root:TMenuItem; const Caption:string; Handler:TNotifyEvent; Shortcut:TShortCut=0);
  begin Item:=TMenuItem.Create(Self); Item.Caption:=Caption; Item.OnClick:=Handler; Item.ShortCut:=Shortcut; Root.Add(Item); end;
begin
  FNavigation:=TPanel.Create(Self); FNavigation.Name:='NavigationPanel'; FNavigation.Parent:=Self;
  FNavigation.Align:=alLeft; FNavigation.Width:=230; FNavigation.BevelOuter:=bvNone; FNavigation.Visible:=False;
  Title:=TLabel.Create(Self); Title.Parent:=FNavigation; Title.Align:=alTop; Title.Caption:='Navigation'; Title.BorderSpacing.Around:=8;
  FNavigationTree:=TTreeView.Create(Self); FNavigationTree.Name:='DocumentOutline'; FNavigationTree.Parent:=FNavigation;
  FNavigationTree.Align:=alClient; FNavigationTree.ReadOnly:=True; FNavigationTree.OnChange:=@NavigateOutline;
  Menu(ViewMenu,'Navigation panel',@ToggleNavigation,ShortCut(VK_N,[ssCtrl,ssShift])); FNavigationMenu:=Item;
  Menu(FileMenu,'Export PDF…',@ExportPDF); Menu(ViewMenu,'Open compiled PDF',@PreviewPDF,ShortCut(VK_R,[ssCtrl]));
  Menu(ViewMenu,'Source / compiled PDF',@SplitViewClick,ShortCut(VK_P,[ssCtrl,ssShift])); Item.Name:='SourcePDFMenu';
  Menu(FileMenu,'Document information…',@DocumentInfoClick);
  Menu(EditMenu,'Toggle formula / body',@ToggleMathSelection,ShortCut(VK_OEM_PLUS,[ssAlt]));
  Menu(EditMenu,'Edit selection source in place',@SelectionSourceClick,ShortCut(VK_L,[ssCtrl]));
  Menu(InsertMenu,'Define command',@DefineCommandClick);
  Menu(InsertMenu,'Renew command',@RenewCommandClick);
  Menu(InsertMenu,'Declare math operator',@DeclareOperatorClick);
  HomeModePreviewButton.OnClick:=@PreviewPDF; HomeModePreviewButton.Hint:='Open compiled PDF (Ctrl+R)';
  OnKeyDown:=@WorkspaceKeyDown; KeyPreview:=True;
end;
procedure TMainForm.ToggleNavigation(Sender:TObject);
begin
  if Sender=FNavigationCheck then FNavigation.Visible:=FNavigationCheck.Checked
  else FNavigation.Visible:=not FNavigation.Visible;
  SetMenuChecked(FNavigationMenu,FNavigation.Visible);
  FNavigationCheck.OnClick:=nil;
  try FNavigationCheck.Checked:=FNavigation.Visible;
  finally FNavigationCheck.OnClick:=@ToggleNavigation; end;
  if FNavigation.Visible then RefreshNavigation; LayoutCards(nil);
end;
procedure TMainForm.RefreshNavigation;
const Titles:array[0..3] of string=('Headings','Figures and tables','Labels and tags','Subfiles');
var Roots:array[0..3] of TTreeNode; Headings:array[0..6] of TTreeNode; Node,HeadingParent:TTreeNode; I,J,Depth,N,Offset:Integer;
    Mark:TContextMark; CaptionText:string;
begin
  if (FNavigationTree=nil) or not FNavigation.Visible then Exit;
  FNavigationTree.OnChange:=nil; FNavigationTree.Items.BeginUpdate;
  try
    FSelectionContext.Load(Document.Source,DocumentDirectory,Engine.Text);
    FOutline:=DocumentOutlineEntries(Document.Blocks,Document.Preamble); FNavigationTree.Items.Clear;
    if (LinkedProject<>nil) and LinkedProject.Expanded then
      for I:=0 to LinkedProject.Files.Count-1 do begin
        Offset:=LinkedProject.FilePosition(LinkedProject.Files.Names[I]); if Offset<0 then Continue;
        N:=Length(FOutline); SetLength(FOutline,N+1); FOutline[N].Group:=3; FOutline[N].BlockIndex:=-1;
        FOutline[N].Offset:=Offset; FOutline[N].Caption:=ExtractRelativePath(ExtractFilePath(FileName),LinkedProject.Files.Names[I]);
      end;
    FillChar(Headings,SizeOf(Headings),0);
    for I:=0 to 3 do Roots[I]:=FNavigationTree.Items.Add(nil,Titles[I]);
    for I:=0 to High(FOutline) do begin
      HeadingParent:=Roots[FOutline[I].Group]; Depth:=EnsureRange(FOutline[I].Depth,0,High(Headings));
      if FOutline[I].Group=0 then
        for J:=Depth-1 downto 0 do if Headings[J]<>nil then begin HeadingParent:=Headings[J]; Break; end;
      CaptionText:=FOutline[I].Caption;
      if FOutline[I].Group=0 then begin
        Mark:=FSelectionContext.Mark(Document.SourceOffset(FOutline[I].BlockIndex,FOutline[I].Offset));
        if (Mark<>nil) and (Mark.Number<>'') then CaptionText:=Mark.Number+' '+CaptionText;
      end;
      Node:=FNavigationTree.Items.AddChild(HeadingParent,CaptionText); Node.Data:=Pointer(PtrInt(I+1));
      if FOutline[I].Group=0 then begin
        Headings[Depth]:=Node; for J:=Depth+1 to High(Headings) do Headings[J]:=nil;
      end;
    end;
    for I:=0 to 3 do Roots[I].Expand(False);
  finally FNavigationTree.Items.EndUpdate; FNavigationTree.OnChange:=@NavigateOutline; end;
end;
procedure TMainForm.NavigateOutline(Sender:TObject; Node:TTreeNode);
var I:Integer;
begin
  if (Node=nil) or (Node.Data=nil) then Exit; I:=PtrInt(Node.Data)-1;
  if (I<0) or (I>High(FOutline)) then Exit;
  if FOutline[I].BlockIndex<0 then NavigateToSource(FOutline[I].Offset)
  else NavigateToSource(Document.SourceOffset(FOutline[I].BlockIndex,FOutline[I].Offset));
end;
procedure TMainForm.NavigateToSource(Offset:Integer);
var Index,Local:Integer;
begin
  Offset:=EnsureRange(Offset,0,Length(Document.Source));
  if FSplitView<>nil then begin
    FFullSource.SetSelection(Offset,Offset); FFullSource.RevealOffset(Offset);
    FFullSource.SourceEditor.SetFocus; FSplitView.ForwardSearch(nil); Exit;
  end;
  Document.LocateOffset(Offset,Index,Local);
  if FPagedView<>nil then begin
    if (Index<0) or (Offset<Length(Document.Preamble)) then begin
      FullSourceClick(nil); FFullSource.SetSelection(Offset,Offset); FFullSource.RevealOffset(Offset);
    end else FPagedView.RevealOffset(Offset);
    Exit;
  end;
  if (Index<0) or (Offset<Length(Document.Preamble)) then begin
    FPreviewOnly:=False; SetPreambleExpanded(True); FPreambleEditing:=True; SetPreviewScroll(Scroll,0,0); LayoutCards(nil);
    PreambleEditor.SetSourceCaret(Max(0,FPreambleFields.DisplayOffset(Offset)));
    if PreambleEditor.CanFocus then PreambleEditor.SetFocus; Exit;
  end;
  EquationMode:=True; EditBlock(Index); if Editor.Visible then LoadEquation;
  FormulaEditor.SetSourceCaret(Local); SetPreviewScroll(Scroll,0,Cards[ActiveBlock].DocumentTop);
  if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
end;
procedure TMainForm.OpenSubfileClick(Sender:TObject);
begin
  if Editor.Visible then QueueLinkedFile(Editor.Text,Length(Editor.TextBetweenPoints[Point(1,1),Editor.LogicalCaretXY]))
  else QueueLinkedFile(FormulaEditor.Formula,FormulaEditor.SourceCaret);
end;
procedure TMainForm.WorkspaceKeyDown(Sender:TObject; var Key:Word; Shift:TShiftState);
var Item:TMenuItem;
begin
  if (Key=VK_ESCAPE) and (ActiveControl is TMathEditor) and
    TMathEditor(ActiveControl).MathShortcutKey(Key,Shift) then Exit;
  if FFocusMode and (Key=VK_ESCAPE) and (Shift=[]) then begin FocusModeClick(nil); Key:=0; Exit; end;
  Item:=EditorShortcutCommand(AppMenu.Items,ShortCut(Key,Shift));
  if Item<>nil then begin
    if ActiveControl is TMathEditor then TMathEditor(ActiveControl).CancelMathShortcut;
    Item.Click; Key:=0;
  end
  else if ActiveControl is TMathEditor then TMathEditor(ActiveControl).MathShortcutKey(Key,Shift);
end;
procedure TMainForm.ToggleMathSelection(Sender:TObject);
begin
  if not BodyEditing then EquationModeClick(nil);
  FormulaEditor.ToggleSelectedMath;
end;
procedure TMainForm.SelectionSourceClick(Sender:TObject);
begin
  if FPreambleEditing then Exit;
  if not BodyEditing then EquationModeClick(nil);
  FormulaEditor.ToggleSelectionSource;
end;
procedure TMainForm.DefineCommandClick(Sender:TObject);
begin
  if DeferInput(@DefineCommandClick,Sender) then Exit;
  InsertCommandDefinition('newcommand');
end;
procedure TMainForm.RenewCommandClick(Sender:TObject);
begin
  if DeferInput(@RenewCommandClick,Sender) then Exit;
  InsertCommandDefinition('renewcommand');
end;
procedure TMainForm.DeclareOperatorClick(Sender:TObject);
begin
  if DeferInput(@DeclareOperatorClick,Sender) then Exit;
  InsertCommandDefinition('DeclareMathOperator');
end;
procedure TMainForm.InsertCommandDefinition(const Kind:string);
var CommandName:string; Visual:TMathEditor; A,B,NameStart:Integer;
begin
  if Kind='DeclareMathOperator' then begin
    if Pos('amsmath',Document.Preamble)=0 then begin
      RecordVisualEdit; A:=Pos('\begin{document}',Document.Preamble); if A=0 then A:=Length(Document.Preamble)+1;
      Insert('\usepackage{amsmath}'+LineEnding,Document.Preamble,A);
    end;
    RefreshPreambleEditor;
    if not FPreambleEditing then begin
      FPreambleEditing:=True;
      PreambleEditor.SetSourceCaret(Length(PreambleEditor.Formula));
    end;
  end;
  if not FPreambleEditing and not BodyEditing then EquationModeClick(nil);
  Visual:=CurrentVisualEditor; CommandName:='mycommand';
  if Kind='renewcommand' then begin
    if Visual.CurrentCommandName<>'' then CommandName:=Visual.CurrentCommandName;
  end else begin
    if Kind='DeclareMathOperator' then CommandName:='myoperator';
    while Pos('\'+CommandName,Document.Source)>0 do CommandName:=CommandName+'x';
  end;
  Visual.WrapSelection('\'+Kind+'{\'+CommandName+'}{','}'); Visual.GetSourceSelection(A,B);
  NameStart:=Min(A,B)-Length(CommandName)-2;
  Visual.SetSourceSelection(NameStart,NameStart+Length(CommandName));
  if Visual.CanFocus then Visual.SetFocus;
end;
function TMainForm.NativeDocumentSource:string;
var P:TTeXProject; Root:string;
begin
  P:=Project;
  try
    Root:=TOpenDocument(FSessions[FSessionIndex]).RootName;
    if (Root<>'') and (Root<>FileName) then Result:=P.Expanded(P.ReadSource(Root),Root)
    else Result:=P.Expanded(Document.Source,FileName);
  finally P.Free; end;
end;
procedure TMainForm.StartPDF(const Destination:string);
begin
  if FDocumentRefreshDue<>0 then QueuePreview;
  if FPDFWorker<>nil then begin StatusText:='PDF compilation is already running'; Exit; end;
  if PluginSourceActive or Document.PreambleOnly or not CompilableTeXDocument(FEffectivePreamble) then begin
    StatusText:='This file has no compilable document; open its master first'; Exit;
  end;
  FPDFDestination:=Destination;
  FPDFWorker:=TRenderThread.Create(NativeDocumentSource,DocumentDirectory,Engine.Text,Revision);
  FPDFWorker.PDFOnly:=True; FPDFWorker.Start; StatusText:='Compiling document PDF…';
end;
procedure TMainForm.PreviewPDF(Sender:TObject);
begin if not DeferInput(@PreviewPDF,Sender) then StartPDF(''); end;
procedure TMainForm.ExportPDF(Sender:TObject);
var D:TSaveDialog;
begin
  if DeferInput(@ExportPDF,Sender) then Exit;
  D:=TSaveDialog.Create(Self);
  try
    D.Filter:='PDF document|*.pdf'; D.DefaultExt:='pdf'; D.Options:=[ofOverwritePrompt,ofPathMustExist];
    if FileName='' then D.FileName:='document.pdf' else D.FileName:=ChangeFileExt(FileName,'.pdf');
    if D.Execute then StartPDF(D.FileName);
  finally D.Free; end;
end;
procedure TMainForm.CompletePDF;
var Input,Output:TFileStream; Path,Destination:string;
begin
  if (FPDFWorker=nil) or not FPDFWorker.Finished then Exit;
  LastLog:=FPDFWorker.LogText;
  try
    if FPDFWorker.ErrorText<>'' then raise Exception.Create(FPDFWorker.ErrorText);
    Path:=FPDFWorker.WorkDir+DirectorySeparator+'preview.pdf';
    Destination:=FPDFDestination;
    if Destination='' then begin
      if FPDFPath<>'' then DeleteFile(FPDFPath);
      FPDFPath:=IncludeTrailingPathDelimiter(GetTempDir(False))+'pastex-document-'+IntToStr(PtrUInt(Self))+'.pdf';
      Destination:=FPDFPath;
    end;
    Input:=TFileStream.Create(Path,fmOpenRead or fmShareDenyNone);
    try Output:=TFileStream.Create(Destination,fmCreate); try Output.CopyFrom(Input,0); finally Output.Free; end;
    finally Input.Free; end;
    if FPDFDestination<>'' then StatusText:='Exported '+Destination
    else begin OpenDocument(Destination); StatusText:='Opened compiled document PDF'; end;
  except on E:Exception do StatusText:=E.Message; end;
  FreeAndNil(FPDFWorker);
end;
procedure TMainForm.GeneratedAction(Sender:TObject; const Command:string; Target:Integer; Configure:Boolean);
begin
  FGeneratedCommand:=Command; FGeneratedTarget:=Target; FGeneratedConfigure:=Configure;
  Application.QueueAsyncCall(@GeneratedActionReady,0);
end;
procedure TMainForm.GeneratedActionReady(Data:PtrInt);
var Index,Offset,I:Integer; Depth,Title,Code,TitleKey,DefaultTitle:string; D:TForm; Levels:TComboBox; Value:TEdit; L:TLabel; B:TButton;
    Styles:TTeXStyles;
begin
  if Copy(FGeneratedCommand,1,4)='url:' then begin OpenURL(Copy(FGeneratedCommand,5,MaxInt)); Exit; end;
  if (Copy(FGeneratedCommand,1,6)='label:') or (Copy(FGeneratedCommand,1,7)='anchor:') then begin
    Offset:=TeXHyperlinkDestination(Document.Source,FGeneratedCommand);
    if Offset<0 then begin StatusText:='Link target is not defined in this file.'; Exit; end;
    NavigateToSource(Offset); Exit;
  end;
  if Copy(FGeneratedCommand,1,5)='page:' then begin
    I:=StrToIntDef(Copy(FGeneratedCommand,6,MaxInt),-1);
    if FPagedView<>nil then begin FPagedView.RevealPage(I); Exit; end;
    for Index:=0 to High(Cards) do if Cards[Index].LayoutPage=I then begin
      NavigateToSource(Document.SourceOffset(Index,0)); Exit;
    end;
    Exit;
  end;
  if FGeneratedConfigure then begin
    if Pos('\maketitle',FGeneratedCommand)>0 then begin PreambleClick(nil); Exit; end;
    TitleKey:='contentsname'; DefaultTitle:='Contents';
    if Pos('listoffigures',FGeneratedCommand)>0 then begin TitleKey:='listfigurename'; DefaultTitle:='List of Figures'; end
    else if Pos('listoftables',FGeneratedCommand)>0 then begin TitleKey:='listtablename'; DefaultTitle:='List of Tables'; end
    else if Pos('tableofcontents',FGeneratedCommand)=0 then begin OpenBibliography(nil); Exit; end;
    D:=TForm.CreateNew(Self);
    Styles:=TTeXStyles.Create;
    try
      Styles.Load(Document.Preamble,DocumentDirectory);
      D.Caption:=DefaultTitle; D.BorderStyle:=bsDialog; D.Position:=poMainFormCenter; D.ClientWidth:=380; D.ClientHeight:=172;
      L:=TLabel.Create(D); L.Parent:=D; L.SetBounds(16,14,110,24); L.Caption:='Heading depth';
      L.Visible:=TitleKey='contentsname';
      Levels:=TComboBox.Create(D); Levels.Parent:=D; Levels.SetBounds(136,10,228,30); Levels.Style:=csDropDownList;
      Levels.Items.CommaText:='Part,Chapter,Section,Subsection,Subsubsection,Paragraph,Subparagraph';
      Levels.ItemIndex:=EnsureRange(TeXCounterSetting(Document.Preamble,'tocdepth',3-Ord(Styles.HasChapters))+1,0,6);
      Levels.Visible:=TitleKey='contentsname';
      L:=TLabel.Create(D); L.Parent:=D; L.SetBounds(16,56,110,24); L.Caption:='List title';
      Value:=TEdit.Create(D); Value.Parent:=D; Value.SetBounds(136,52,228,30); Value.Text:=Styles.Name(TitleKey,DefaultTitle);
      if not Levels.Visible then begin D.ClientHeight:=132; L.Top:=16; Value.Top:=12; end;
      B:=TButton.Create(D); B.Parent:=D; B.SetBounds(176,D.ClientHeight-48,90,30); B.Caption:='Apply'; B.ModalResult:=mrOK;
      B:=TButton.Create(D); B.Parent:=D; B.SetBounds(274,D.ClientHeight-48,90,30); B.Caption:='Cancel'; B.ModalResult:=mrCancel; ApplyTheme(D);
      if D.ShowModal<>mrOK then Exit;
      Depth:=IntToStr(Levels.ItemIndex-1); Title:=Value.Text;
      RecordVisualEdit; I:=Pos('\begin{document}',Document.Preamble); if I=0 then I:=Length(Document.Preamble)+1;
      Code:='\renewcommand{\'+TitleKey+'}{'+Title+'}'+LineEnding;
      if TitleKey='contentsname' then Code:='\setcounter{tocdepth}{'+Depth+'}'+LineEnding+Code;
      Insert(Code,Document.Preamble,I); Modified:=True; QueuePreview; UpdateTitle;
    finally Styles.Free; D.Free; end;
  end else if FGeneratedTarget>=Length(FEffectivePreamble) then begin
    Offset:=FGeneratedTarget-Length(FEffectivePreamble)+Length(Document.Preamble);
    NavigateToSource(Offset);
  end;
end;
