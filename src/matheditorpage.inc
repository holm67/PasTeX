{ SPDX-License-Identifier: GPL-3.0-or-later }
function TMathEditor.PageCaptionKey:string;
var N:TMathNode;
begin
  Result:=''; if FReadOnly then Exit; N:=CurrentNode;
  while N<>nil do begin
    if (N.Kind in [mkCommand,mkTextCommand,mkDefinition,mkUnknownCommand,mkEnvironment,mkDiagram,mkVerbatim]) or
      ((N.Kind in [mkFormula,mkGroup]) and (N.Prefix<>'')) then Result:=Result+':'+IntToStr(N.ID);
    N:=N.Parent;
  end;
end;
function TMathEditor.PageCaptions:TPageCaptions;
var Lines:TPageLines; LabelText:string; Bounds:TRect; N:TMathNode; Used:TPageShifts;
  procedure AddInset(const Text:string; const Anchor:TRect);
  var I,J,Padding:Integer; R:TRect;
  begin
    J:=FDraft.EditingSpaceLine; R:=FDraft.EditingSpaceBounds;
    if (Text='') or R.IsEmpty or (J<0) or (J>=Length(Lines)) then Exit;
    I:=Length(Result); SetLength(Result,I+1); Result[I].Text:=Text; Result[I].Line:=J;
    Padding:=0; if Used[J]=0 then Padding:=FPageCaptionPadding;
    Result[I].Space:=Padding+Max(24,Round(24*FPreviewZoom)); OffsetRect(R,ImageLeft,ImageTop);
    Result[I].Bounds:=R; Result[I].Bounds.Left:=Anchor.Left;
    Inc(Result[I].Bounds.Top,Used[J]+Padding+3);
    Inc(Used[J],Result[I].Space);
  end;
  procedure Add(const Text:string; const R:TRect);
  var I,J,Padding:Integer;
  begin
    if (Text='') or (R.Width<=0) or (R.Height<=0) or (Length(Lines)=0) then Exit;
    if (R.Left>=ImageLeft+TextLayoutWidth-10) or (R.Right<=ImageLeft+10) then begin
      I:=Length(Result); SetLength(Result,I+1); Result[I].Text:=Text; Result[I].Line:=-1;
      Result[I].Space:=Max(24,Round(24*FPreviewZoom)); Result[I].Bounds:=R; Result[I].Bounds.Top:=R.Bottom+3; Exit;
    end;
    J:=PageLineBelow(Lines,R.Bottom);
    Padding:=0;
    if (Used[J]=0) and not PageSourcesExpanded and
      ((Length(SourceFrameRects)=1) or (Length(FDraft.SourceToggles)>0)) then Padding:=30;
    I:=Length(Result); SetLength(Result,I+1); Result[I].Text:=Text; Result[I].Line:=J;
    Result[I].Space:=Padding+Max(24,Round(24*FPreviewZoom)); Result[I].Bounds:=R;
    Result[I].Bounds.Top:=Lines[J].Bottom+Lines[J].EditorSpace+ImageTop+Used[J]+Padding+3;
    if J<Length(FPageShifts) then Inc(Result[I].Bounds.Top,FPageShifts[J]);
    Inc(Used[J],Result[I].Space);
  end;
begin
  Result:=nil; if FReadOnly or not FPagedEditing then Exit;
  EnsureDraft; Lines:=FDraft.PageLines; SetLength(Used,Length(Lines));
  if CommandContext(LabelText,Bounds) and (Copy(LabelText,1,7)<>'\begin{') then begin
    if FDraft.EditingSpaceBounds.IsEmpty then Add(LabelText,Bounds) else AddInset(LabelText,Bounds);
  end;
  N:=EnvironmentNode('');
  if N<>nil then begin
    if not FDraft.EditingSpaceBounds.IsEmpty and ((N.Kind=mkFormula) or IsMathField(N)) then AddInset(CurrentEnvironmentName,NodeBounds(N))
    else Add(CurrentEnvironmentName,NodeBounds(N));
  end;
end;
function TMathEditor.PageLineBelow(const Lines:TPageLines; Bottom:Integer):Integer;
var I,Y,Distance,Best:Integer;
begin
  Result:=0; Best:=MaxInt;
  for I:=0 to High(Lines) do begin
    Y:=Lines[I].Bottom+ImageTop; if I<Length(FPageShifts) then Inc(Y,FPageShifts[I]);
    if (Bottom<=Y) and (Bottom>=Y-Lines[I].Bottom+Lines[I].Top) then Exit(I);
    Distance:=Abs(Y-Bottom); if Distance<Best then begin Best:=Distance; Result:=I; end;
  end;
end;
function TMathEditor.PageHovering:Boolean;
var Toggle:TDraftSourceToggle; N:TMathNode; R:TRect;
begin
  Result:=False; if (FDraft=nil) or (FSourceHover.X<0) then Exit;
  N:=SourcePreviewNode;
  if N<>nil then begin
    R:=NodeBounds(N); InflateRect(R,3,3);
    if PtInRect(R,FSourceHover) or PtInRect(SourceDisclosureBounds,FSourceHover) then Exit(True);
  end;
  for Toggle in FDraft.SourceToggles do
    if not Toggle.Expanded and FDraft.SourceControlVisible(Toggle) then Exit(True);
end;
function TMathEditor.PageEditingLines:TPageLines;
var Note:TPageCaption; Toggle:TDraftSourceToggle; Boxes:TSelectionRects;
  procedure Reserve(Bottom:Integer);
  var I:Integer;
  begin
    if Length(Result)=0 then Exit; I:=PageLineBelow(Result,Bottom);
    Result[I].EditorSpace:=Max(32,Result[I].EditorSpace);
  end;
begin
  Result:=Copy(PageLines);
  for Note in PageCaptions do if Note.Line>=0 then Inc(Result[Note.Line].EditorSpace,Note.Space);
  if not PageHovering then Exit;
  Boxes:=SourceFrameRects;
  if Length(Boxes)=1 then Reserve(Boxes[0].Bottom-3);
  for Toggle in FDraft.SourceToggles do if not Toggle.Expanded and FDraft.SourceControlVisible(Toggle) then
    Reserve(Toggle.PreviewBounds.Bottom+ImageTop);
end;
procedure TMathEditor.PaintPageCaptions;
var Note:TPageCaption;
begin
  Canvas.Font.Name:=FSourceFontName; if Canvas.Font.Name='' then Canvas.Font.Name:='monospace';
  Canvas.Font.Size:=Max(7,Round(9*FPreviewZoom)); Canvas.Font.Style:=[];
  Canvas.Font.Color:=clGray; Canvas.Brush.Style:=bsClear;
  for Note in PageCaptions do Canvas.TextOut(
    EnsureRange(Note.Bounds.Left,0,Max(0,ClientWidth-Canvas.TextWidth(Note.Text))),Note.Bounds.Top,Note.Text);
  Canvas.Brush.Style:=bsSolid;
end;
