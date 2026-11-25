{ SPDX-License-Identifier: GPL-3.0-or-later }
procedure TPagedEditor.GetSourceSelection(out Anchor,Focus:Integer);
begin
  if FSelectionAnchor>=0 then begin Anchor:=FSelectionAnchor; Focus:=FSelectionFocus; end
  else begin
    VisualEditor.GetSourceSelection(Anchor,Focus);
    if FBlock>=0 then begin Inc(Anchor,BlockOffset(FBlock)); Inc(Focus,BlockOffset(FBlock)); end;
  end;
end;
procedure TPagedEditor.ApplySelection(Editor:TMathEditor; Index:Integer);
var Base,Limit:Integer; Applying:Boolean;
begin
  if FSelectionAnchor<0 then Exit; Base:=BlockOffset(Index); Limit:=Length(FDocument.Blocks[Index]);
  Applying:=FApplyingSelection; FApplyingSelection:=True;
  try
    if (Max(FSelectionAnchor,FSelectionFocus)<Base) or (Min(FSelectionAnchor,FSelectionFocus)>Base+Limit) then Editor.ClearSourceSelection
    else Editor.SetSourceSelection(EnsureRange(FSelectionAnchor-Base,0,Limit),EnsureRange(FSelectionFocus-Base,0,Limit));
  finally FApplyingSelection:=Applying; end;
end;
procedure TPagedEditor.SetSourceSelection(Anchor,Focus:Integer; Activate:Boolean);
var I,Index,Offset:Integer;
begin
  Anchor:=EnsureRange(Anchor,Length(FDocument.Preamble),BodyEnd);
  Focus:=EnsureRange(Focus,Length(FDocument.Preamble),BodyEnd);
  FApplyingSelection:=True;
  try
    if Activate then begin LocateOffset(Focus,Index,Offset); SetActive(Index); end;
    FSelectionAnchor:=Anchor; FSelectionFocus:=Focus;
    for I:=0 to High(FBlocks) do if FBlocks[I].Editor<>nil then ApplySelection(FBlocks[I].Editor,I);
    if FBlock>=0 then begin FLastCaretBlock:=FBlock; FLastCaret:=VisualEditor.SourceCaret; end;
  finally FApplyingSelection:=False; end;
  if not FLoading and Assigned(FOnSelectionChange) then FOnSelectionChange(Self);
end;
function TPagedEditor.SelectedSourceRanges:TSourceRanges;
var I,Base:Integer;
begin
  Result:=nil; if CrossSelection or (FBlock<0) or not VisualEditor.SelectingTableCells then Exit;
  Result:=VisualEditor.SelectedSourceRanges; Base:=BlockOffset(FBlock);
  for I:=0 to High(Result) do begin Inc(Result[I].Start,Base); Inc(Result[I].Finish,Base); end;
end;
function TPagedEditor.CrossSelection:Boolean;
var A,B,AO,BO:Integer;
begin
  Result:=False; if (FSelectionAnchor<0) or (FSelectionAnchor=FSelectionFocus) then Exit;
  LocateOffset(FSelectionAnchor,A,AO); LocateOffset(FSelectionFocus,B,BO); Result:=A<>B;
end;
function TPagedEditor.BlockAt(const Position:TPoint):Integer;
var I,Distance,Best:Integer; Bounds:TRect;
begin
  Result:=-1; Best:=MaxInt;
  if (Position.X<FTextLeft) or (Position.X>FTextLeft+FTextWidth) then
    for I:=0 to High(FBlocks) do if FBlocks[I].Editor<>nil then begin
      Bounds:=FBlocks[I].Editor.MarginNoteBounds;
      OffsetRect(Bounds,FBlocks[I].Panel.DocumentOrigin.X,FBlocks[I].Panel.DocumentOrigin.Y);
      if PtInRect(Bounds,Position) then Exit(I);
    end;
  for I:=0 to High(FBlocks) do begin
    Bounds:=Rect(FTextLeft,FBlocks[I].Flow.Top,FTextLeft+FTextWidth,FBlocks[I].Flow.Top+FBlocks[I].Flow.Height);
    Distance:=Max(0,Max(Bounds.Top-Position.Y,Position.Y-Bounds.Bottom));
    if (Distance=0) and (FBlocks[I].Flow.FloatKind<>'') then Exit(I);
    if (Distance<Best) or ((Distance=Best) and (Result>=0) and (Bounds.Top>FBlocks[Result].Flow.Top)) then begin Result:=I; Best:=Distance; end;
  end;
end;
procedure TPagedEditor.DocumentGesture(Sender:TObject; Position:TPoint; Phase:Integer; Shift:TShiftState);
var Index,Offset,Anchor,Focus,X,Y:Integer; P:TPoint;
begin
  if FApplyingSelection or FLoading or (EditorIndex(Sender)<0) then Exit;
  X:=FScroll.HorzScrollBar.Position; Y:=FScroll.VertScrollBar.Position;
  case Phase of
    0:begin
      Index:=EditorIndex(Sender); Offset:=BlockOffset(Index)+TMathEditor(Sender).SourceCaret;
      if not (ssShift in Shift) or (FSelectionAnchor<0) then FSelectionAnchor:=Offset;
      FSelecting:=True; SetSourceSelection(FSelectionAnchor,Offset,False);
    end;
    1:begin
      if not FSelecting then Exit; P:=Position-PreviewViewportOrigin(FScroll);
      if P.Y<0 then Dec(Y,18) else if P.Y>FScroll.ClientHeight then Inc(Y,18);
      SetPreviewScroll(FScroll,X,Y); Y:=FScroll.VertScrollBar.Position;
      P:=P+Point(X,Y); Index:=BlockAt(P); if Index<0 then Exit;
      FApplyingSelection:=True;
      try
        { GTK may still report an earlier widget allocation after scrolling.
          The document layout owns the paragraph's position. }
        Offset:=ParagraphEditor(Index).HitOffset(P.X-FBlocks[Index].Panel.DocumentOrigin.X,P.Y-FBlocks[Index].Flow.Top);
      finally FApplyingSelection:=False; end;
      SetSourceSelection(FSelectionAnchor,BlockOffset(Index)+Offset,False);
    end;
    2:begin
      if not FSelecting then Exit; FSelecting:=False; GetSourceSelection(Anchor,Focus);
      SetSourceSelection(Anchor,Focus);
    end;
    3,4:begin
      if Sender<>VisualEditor then Exit;
      TMathEditor(Sender).GetSourceSelection(Anchor,Focus); Index:=EditorIndex(Sender);
      if (Phase=3) and (ssShift in Shift) and (FSelectionAnchor>=0) then Anchor:=FSelectionAnchor
      else Anchor:=BlockOffset(Index)+Anchor;
      SetSourceSelection(Anchor,BlockOffset(Index)+Focus,False);
    end;
  end;
  SetPreviewScroll(FScroll,X,Y);
end;
procedure TPagedEditor.ReplaceSource(const Value:string; Anchor,Focus:Integer);
begin
  if FReadOnly or (Value=Source) then Exit;
  FUndo.Add(Source); if FUndo.Count>20 then FUndo.Delete(0); FRedo.Clear; FLastUndo:=0;
  FContextDue:=0; FReblockDue:=0; FDocument.ParseFile(Value); ResetBlocks(Focus); SetSourceSelection(Anchor,Focus);
  if Assigned(FOnChange) then FOnChange(Self);
end;
procedure TPagedEditor.ReplaceSelection(const Value:string);
var A,B,T:Integer; ContentText:string;
begin
  GetSourceSelection(A,B); if A>B then begin T:=A; A:=B; B:=T; end;
  ContentText:=Source; ReplaceSource(Copy(ContentText,1,A)+Value+Copy(ContentText,B+1,MaxInt),A+Length(Value),A+Length(Value));
end;
procedure TPagedEditor.DocumentText(Sender:TObject; const Value:string; var Handled:Boolean);
begin
  if not CrossSelection then Exit; Handled:=True;
  FHandlingInput:=True;
  try ReplaceSelection(StringReplace(Value,'%','\%',[rfReplaceAll]));
  finally FHandlingInput:=False; end;
end;
procedure TPagedEditor.DocumentKey(Sender:TObject; Key:Word; Shift:TShiftState; var Handled:Boolean);
var A,B,AO,BO,I,T,L,R:Integer; ContentText,ClipboardText:string; Tree:TMathNode;
begin
  if FApplyingSelection or FReadOnly then Exit;
  FHandlingInput:=True;
  try
  if (ssCtrl in Shift) and (Key=VK_A) then begin
    SetSourceSelection(Length(FDocument.Preamble),BodyEnd); Handled:=True; Exit;
  end;
  if not CrossSelection then Exit;
  GetSourceSelection(A,B); if A>B then begin T:=A; A:=B; B:=T; end;
  if (ssCtrl in Shift) and (Key in [VK_C,VK_X]) then begin
    LocateOffset(A,I,AO); LocateOffset(B,T,BO); ContentText:=''; ClipboardText:='';
    while I<=T do begin
      L:=Max(0,A-BlockOffset(I)); R:=Min(Length(FDocument.Blocks[I]),B-BlockOffset(I));
      Tree:=ParseParagraph(FDocument.Blocks[I],nil);
      try ContentText:=ContentText+ProseFragment(Tree,FDocument.Blocks[I],L,R);
        ClipboardText:=ClipboardText+BodyClipboardFragment(Tree,FDocument.Blocks[I],L,R);
      finally Tree.Free; end;
      Inc(I);
    end;
    WriteVisualClipboard(ContentText,ClipboardText); if Key=VK_X then ReplaceSelection(''); Handled:=True;
  end else if (ssCtrl in Shift) and (Key=VK_V) then begin ReplaceSelection(ReadBodyClipboard); Handled:=True; end
  else if (Shift=[]) and (Key in [VK_BACK,VK_DELETE,VK_RETURN]) then begin
    if Key=VK_RETURN then ReplaceSelection(LineEnding+LineEnding) else ReplaceSelection(''); Handled:=True;
  end else if (Shift=[]) and (Key in [VK_LEFT,VK_RIGHT]) then begin
    if Key=VK_LEFT then SetSourceSelection(A,A) else SetSourceSelection(B,B); Handled:=True;
  end;
  finally FHandlingInput:=False; end;
end;
procedure TPagedEditor.RevealOffset(Offset:Integer);
var Index,Local:Integer; P:TPoint;
begin
  LocateOffset(Offset,Index,Local); if Index<0 then Exit;
  ActivateBlock(Index,Local); P:=VisualEditor.CaretPoint;
  SetPreviewScroll(FScroll,FScroll.HorzScrollBar.Position,Max(0,FBlocks[Index].Flow.Top+P.Y-FScroll.ClientHeight div 3));
end;
procedure TPagedEditor.RevealPage(Number:Integer);
begin
  if (Number<1) or (Number>Length(FPages)) then Exit;
  SetPreviewScroll(FScroll,FScroll.HorzScrollBar.Position,FPages[Number-1].DocumentOrigin.Y);
end;
function TPagedEditor.ViewOffset:Integer;
var P:TPoint; Index:Integer;
begin
  Result:=SourceOffset; if FBlock>=0 then begin
    P:=VisualEditor.CaretPoint+FBlocks[FBlock].Panel.DocumentOrigin;
    if (P.Y>=FScroll.VertScrollBar.Position) and (P.Y<FScroll.VertScrollBar.Position+FScroll.ClientHeight) then Exit;
  end;
  Index:=BlockAt(Point(FTextLeft,FScroll.VertScrollBar.Position+16));
  if Index>=0 then Result:=BlockOffset(Index);
end;
