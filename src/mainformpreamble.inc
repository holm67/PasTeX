{ SPDX-License-Identifier: GPL-3.0-or-later }
function TMainForm.PreambleAvailable:Boolean;
begin Result:=Trim(Document.Preamble)<>''; end;
function TMainForm.PreambleContentVisible:Boolean;
begin Result:=not PluginSourceActive and (Document.PreambleOnly or (FPreambleExpanded and not FPreviewOnly and PreambleAvailable)); end;
procedure TMainForm.SetPreambleExpanded(Value:Boolean);
begin
  if Value=FPreambleExpanded then Exit;
  if not Value and FPreambleEditing and not Document.PreambleOnly then begin
    PreambleEditor.FinishCommand; FPreambleEditing:=False;
    if FormulaBox.Visible and FormulaEditor.CanFocus then FormulaEditor.SetFocus else if Scroll.CanFocus then Scroll.SetFocus;
  end;
  FPreambleExpanded:=Value;
  if not FLoading then LayoutCards(nil);
end;
procedure TMainForm.TogglePreamble(Sender:TObject);
begin SetPreambleExpanded(not FPreambleExpanded); end;
procedure TMainForm.UpdatePreambleVisibility(ScrollPosition:Integer);
var Y:Integer; ToggleCaption:string; WasVisible:Boolean;
  function NearViewport(Panel:TPreviewPanel):Boolean;
  begin
    Y:=Panel.DocumentOrigin.Y-ScrollPosition;
    Result:=(Y+Panel.Height>=-Scroll.ClientHeight) and (Y<=Scroll.ClientHeight*2);
  end;
begin
  if (FPreamblePanel=nil) or (PreambleEditor=nil) then Exit;
  WasVisible:=FPreamblePanel.Visible and PreambleEditor.Visible;
  PreambleEditor.Visible:=PreambleContentVisible;
  FPreamblePanel.SyncScrollPosition;
  FPreamblePanel.Visible:=PreambleContentVisible and NearViewport(FPreamblePanel);
  { Keep this editable widget's handle stable. Destroying its off-screen
    parent can lose Qt/GTK child visibility and focus when it returns. }
  if FPreamblePanel.Visible and not WasVisible then PreambleEditor.Invalidate;
  FPreambleToggle.SyncScrollPosition;
  if FPreambleExpanded then ToggleCaption:='Preamble  [hide]' else ToggleCaption:='Preamble  [show]';
  if FPreambleToggle.SeparatorCaption<>ToggleCaption then begin
    FPreambleToggle.SeparatorCaption:=ToggleCaption; FPreambleToggle.Invalidate;
  end;
  { This small header is navigation, not an evictable paragraph preview.
    Keep it available even when every existing option is handled by the form. }
  FPreambleToggle.Visible:=not PluginSourceActive and PreambleAvailable and not Document.PreambleOnly and not FPreviewOnly;
  FBodySeparator.SyncScrollPosition;
  FBodySeparator.Visible:=not Document.PreambleOnly and PreambleContentVisible and not FPreviewOnly and NearViewport(FBodySeparator);
end;
function TMainForm.CurrentVisualEditor:TMathEditor;
begin
  if FPagedView<>nil then Result:=FPagedView.VisualEditor
  else if FPreambleEditing and (PreambleEditor<>nil) then Result:=PreambleEditor else Result:=FormulaEditor;
end;
function TMainForm.BodyEditor:TMathEditor;
begin
  if FPagedView<>nil then Result:=FPagedView.VisualEditor else Result:=FContinuousEditor;
end;
function TMainForm.BodyEditing:Boolean;
begin Result:=(FPagedView<>nil) or FormulaBox.Visible; end;
procedure TMainForm.RefreshPreambleEditor;
var SourceCaret,Caret:Integer; WasLoading:Boolean;
begin
  if FPreambleFields=nil then FPreambleFields:=TEditablePreamble.Create;
  if PreambleEditor=nil then begin
    FPreambleToggle:=TPreviewPanel.Create(Self); FPreambleToggle.Parent:=Scroll;
    FPreambleToggle.Name:='PreambleToggle'; FPreambleToggle.BevelOuter:=bvNone;
    FPreambleToggle.ParentBackground:=False; FPreambleToggle.Color:=PaperColor;
    FPreambleToggle.Cursor:=crHandPoint; FPreambleToggle.OnClick:=@TogglePreamble;
    FPreambleToggle.Hint:='Show or hide editable preamble commands'; FPreambleToggle.ShowHint:=True;
    FPreamblePanel:=TPreviewPanel.Create(Self); FPreamblePanel.Parent:=Scroll;
    FPreamblePanel.BevelOuter:=bvNone; FPreamblePanel.ParentBackground:=False;
    FPreamblePanel.Color:=PaperColor;
    PreambleEditor:=TMathEditor.Create(FPreamblePanel); PreambleEditor.Parent:=FPreamblePanel;
    PreambleEditor.PopupMenu:=EditPopup;
    PreambleEditor.CodeOnly:=True; PreambleEditor.DefinitionsInCode:=True;
    PreambleEditor.Hint:='Preamble commands · edit definitions in orange boxes or other code in gray boxes';
    PreambleEditor.ShowHint:=True; PreambleEditor.OnChange:=@PreambleChanged;
    PreambleEditor.OnSelectionChange:=@PreambleSelected; PreambleEditor.OnEnter:=@PreambleSelected;
    PreambleEditor.OnLayout:=@LayoutCards; PreambleEditor.OnBoundary:=@PreambleBoundary;
    PreambleEditor.OnUndo:=@UndoClick; PreambleEditor.OnRedo:=@RedoClick;
    PreambleEditor.OnSourceLink:=@VisualLinkClick;
    FBodySeparator:=TPreviewPanel.Create(Self); FBodySeparator.Parent:=Scroll;
    FBodySeparator.Name:='BodySeparator'; FBodySeparator.BevelOuter:=bvNone;
    FBodySeparator.ParentBackground:=False; FBodySeparator.Color:=PaperColor;
    FBodySeparator.SeparatorCaption:='Document body';
  end;
  PreambleEditor.ConfigureSourceFont(WrappedEditor.Font);
  { Typing updates the source projection before the deferred context refresh.
    The directory and engine can also change without changing that projection. }
  PreambleEditor.SetContext(Document.Preamble,DocumentDirectory,Engine.Text,'',False);
  if (FPreambleFields.Source=Document.Preamble) and (FPreambleFields.WholeSource=Document.PreambleOnly) then Exit;
  SourceCaret:=FPreambleFields.SourceOffset(PreambleEditor.SourceCaret);
  FPreambleFields.Load(Document.Preamble,Document.PreambleOnly); WasLoading:=FLoading; FLoading:=True;
  try
    if PreambleEditor.Formula<>FPreambleFields.Text then begin
      PreambleEditor.LoadParagraph(FPreambleFields.Text,nil);
      Caret:=FPreambleFields.DisplayOffset(SourceCaret); PreambleEditor.SetSourceCaret(Max(0,Caret));
    end;
  finally FLoading:=WasLoading; end;
end;
procedure TMainForm.PreambleSelected(Sender:TObject);
begin
  if FLoading then Exit; SetPreambleExpanded(True); FPreambleEditing:=True; ClearDocumentSelection;
  RefreshFontControls; UpdateContextTabs(False,False,False,False); SyncFullSource; UpdateStatusBar;
end;
procedure TMainForm.PreambleChanged(Sender:TObject);
var SourceCaret,SavedScroll,Index,Offset:Integer; Before,After:string;
begin
  if FLoading or FRestoringHistory then Exit;
  Before:=Document.Preamble; After:=FPreambleFields.Apply(PreambleEditor.Formula,PreambleEditor.SourceCaret,SourceCaret);
  if After=Before then begin
    if PreambleEditor.Formula<>FPreambleFields.Text then begin
      FLoading:=True;
      try
        PreambleEditor.LoadParagraph(FPreambleFields.Text,nil);
        PreambleEditor.SetSourceCaret(Max(0,FPreambleFields.DisplayOffset(SourceCaret)));
      finally FLoading:=False; end;
    end;
    Exit;
  end;
  FPreambleEditing:=True; RecordVisualEdit(FPreambleFields.SourceOffset(PreambleEditor.EditCaretBefore));
  SavedScroll:=Scroll.VertScrollBar.Position; Document.Preamble:=After; Modified:=True;
  { Keep the lightweight source projection current so undo can restore the
    visible text before deferred package/font processing runs. }
  FPreambleFields.Load(After,Document.PreambleOnly);
  if PreambleEditor.Formula<>FPreambleFields.Text then begin
    FLoading:=True;
    try PreambleEditor.LoadParagraph(FPreambleFields.Text,nil); PreambleEditor.SetSourceCaret(Max(0,FPreambleFields.DisplayOffset(SourceCaret)));
    finally FLoading:=False; end;
  end;
  if Document.PreambleOnly and CompilableTeXDocument(After) then begin
    Document.ParseFile(After); BuildCards; Document.LocateOffset(SourceCaret,Index,Offset);
    if SourceCaret<Length(Document.Preamble) then begin
      FPreambleEditing:=True; PreambleEditor.SetSourceCaret(Max(0,FPreambleFields.DisplayOffset(SourceCaret)));
    end else begin EditBlock(Index); FormulaEditor.SetSourceCaret(Offset); end;
    UpdateTitle; QueuePreview; Exit;
  end;
  { Rebuild package registries only after typing pauses, not for every key. }
  FPreambleRefreshDue:=GetTickCount64+400; Pending:=True; Due:=FPreambleRefreshDue+350; Inc(Revision);
  FPreambleEditing:=True; UpdateTitle; SyncFullSource; LayoutCards(nil);
  UpdateContextTabs(False,False,False,False);
  SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,SavedScroll);
end;
procedure TMainForm.PreambleBoundary(Sender:TObject; Direction:Integer; Merge:Boolean);
begin
  if (Direction<0) or Document.PreambleOnly then Exit; FPreambleEditing:=False; EditBlock(0);
  FormulaEditor.SetSourceCaret(0); if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
end;
procedure TMainForm.RefreshFontControls;
var Visual:TMathEditor;
begin
  Visual:=CurrentVisualEditor; if Visual<>nil then UpdateFontControls(Visual.SelectionTextState);
end;
procedure TMainForm.UpdateFontControls(const Selection:TTeXTextSelection);
var Style:TTeXTextStyle; HasStyle:Boolean; I:Integer; Button:TSpeedButton; Item:TMenuItem; C:TComboBox;
begin
  HasStyle:=Selection.Valid; Style:=Selection.Style;
  HomeTextBoldButton.Enabled:=HasStyle; HomeTextItalicButton.Enabled:=HasStyle;
  HomeTextBoldButton.Down:=TextSelectionStyleActive(Selection,'\textbf'); HomeTextItalicButton.Down:=TextSelectionStyleActive(Selection,'\textit');
  for I:=0 to ComponentCount-1 do if Components[I] is TSpeedButton then begin
    Button:=TSpeedButton(Components[I]);
    if (Button.GroupIndex>=31) and (Button.GroupIndex<=35) then begin
      Button.Enabled:=HasStyle; Item:=TMenuItem(Pointer(Button.Tag)); Button.Down:=TextSelectionStyleActive(Selection,Copy(Item.Hint,12,MaxInt));
    end;
  end;
  SetMenuChecked(BoldMenuItem,HomeTextBoldButton.Down); SetMenuChecked(ItalicMenuItem,HomeTextItalicButton.Down);
  FUpdatingRibbon:=True;
  try
    C:=TComboBox(FindComponent('TextFamilyChoice'));
    if C<>nil then begin
      C.Enabled:=HasStyle; C.ItemIndex:=-1;
      if HasStyle then begin
        if Style.Family=Style.Roman then C.ItemIndex:=0
        else if Style.Family=Style.Sans then C.ItemIndex:=1 else if Style.Family=Style.Mono then C.ItemIndex:=2;
      end;
    end;
    C:=TComboBox(FindComponent('TextSizeChoice'));
    if C<>nil then begin
      C.Enabled:=HasStyle; C.ItemIndex:=-1;
      if HasStyle then begin
        if Style.SizeName='normalsize' then C.ItemIndex:=4 else C.ItemIndex:=C.Items.IndexOf(Style.SizeName);
        if (C.ItemIndex<0) and (Style.Points>0) then C.ItemIndex:=C.Items.Count-1;
      end;
    end;
  finally FUpdatingRibbon:=False; end;
end;
procedure TMainForm.UpdateParagraphControl(const Style:string);
var C:TComboBox; I:Integer; WasUpdating:Boolean;
begin
  C:=TComboBox(FindComponent('ParagraphStyles')); if C=nil then Exit;
  WasUpdating:=FUpdatingRibbon; FUpdatingRibbon:=True;
  try
    C.ItemIndex:=-1;
    for I:=0 to C.Items.Count-1 do
      if (C.Items.Objects[I] is TMenuItem) and (TMenuItem(C.Items.Objects[I]).Hint=Style) then begin C.ItemIndex:=I; Break; end;
  finally FUpdatingRibbon:=WasUpdating; end;
end;
procedure TMainForm.FormattingAction(Sender:TObject);
var Commenting:Boolean; Visual:TMathEditor; A,B,AO,BO,I,L,R,NewA,NewB:Integer;
    Root:TMathNode; S,Value,Command:string; FirstPoint,LastPoint:TPoint;
begin
  if DeferInput(@FormattingAction,Sender) then Exit;
  Commenting:=(Sender is TMenuItem) and (TMenuItem(Sender).Hint='@comment');
  Command:='@all';
  if FPreambleEditing then begin if Commenting then PreambleEditor.ToggleComment; Exit; end;
  if DocumentSelectionBounds(A,AO,B,BO) and (A<>B) then begin
    if Commenting then begin ReplaceDocumentSelection(ToggleSourceComment(SelectedDocumentText)+LineEnding); Exit; end;
    RecordVisualEdit;
    for I:=A to B do begin
      S:=Document.Blocks[I]; L:=0; R:=Length(S); if I=A then L:=AO; if I=B then R:=BO;
      Root:=ParseParagraph(S,FSelectionRegistry);
      try
        Value:=ProseFragment(Root,S,0,L); NewA:=Length(Value);
        Value:=Value+ProseFragment(Root,S,L,R,Command); NewB:=Length(Value);
        Value:=Value+ProseFragment(Root,S,R,Length(S)); CompactProseFormatting(Value,NewA,NewB);
      finally Root.Free; end;
      Document.Blocks[I]:=Value; if I=A then AO:=NewA; if I=B then BO:=NewB;
    end;
    BuildCards; EditBlock(B); FSelectionStartBlock:=A; FSelectionStartOffset:=AO;
    FSelectionEndBlock:=B; FSelectionEndOffset:=BO; FormulaEditor.SetSourceCaret(BO); UpdateDocumentSelection;
    Modified:=True; UpdateTitle; QueuePreview; Exit;
  end;
  if Editor.Visible then begin
    FirstPoint:=Editor.BlockBegin; LastPoint:=Editor.BlockEnd;
    A:=Length(Editor.TextBetweenPoints[Point(1,1),FirstPoint]); B:=Length(Editor.TextBetweenPoints[Point(1,1),LastPoint]);
    S:=Editor.Text;
    if A=B then begin
      if not Commenting then Exit;
      FirstPoint:=Point(1,Editor.CaretY); LastPoint:=Point(Length(Editor.Lines[Editor.CaretY-1])+1,Editor.CaretY);
      A:=Length(Editor.TextBetweenPoints[Point(1,1),FirstPoint]); B:=A+Length(Editor.Lines[Editor.CaretY-1]);
    end;
    Root:=ParseParagraph(S,FSelectionRegistry);
    try
      Value:=ProseFragment(Root,S,0,A); NewA:=Length(Value);
      if Commenting then begin
        if (Value<>'') and (Value[Length(Value)]<>#10) then Value:=Value+LineEnding;
        Value:=Value+ToggleSourceComment(Copy(S,A+1,B-A))+LineEnding;
      end else Value:=Value+ProseFragment(Root,S,A,B,Command);
      NewB:=Length(Value); Value:=Value+ProseFragment(Root,S,B,Length(S));
      CompactProseFormatting(Value,NewA,NewB);
    finally Root.Free; end;
    Editor.BeginUndoBlock;
    try Editor.SelectAll; Editor.SelText:=Value; Editor.BlockBegin:=BytePoint(Value,NewA); Editor.BlockEnd:=BytePoint(Value,NewB);
    finally Editor.EndUndoBlock; end;
    if Editor.CanFocus then Editor.SetFocus; Exit;
  end;
  if not BodyEditing then EquationModeClick(nil);
  Visual:=CurrentVisualEditor;
  if Commenting then Visual.ToggleComment else Visual.ClearTextFormatting;
  RefreshFontControls; if Visual.CanFocus then Visual.SetFocus;
end;
