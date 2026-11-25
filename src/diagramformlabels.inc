{ SPDX-License-Identifier: GPL-3.0-or-later }
function TDiagramForm.TextLabels:TDiagramTexts;
begin Result:=nil; if FSceneSource=Source then Result:=NativeDiagramTexts(FScene); end;
function TDiagramForm.LabelAt(X,Y:Integer):Integer;
var Items:TDiagramTexts; I:Integer; NX,NY:Double;
begin
  Result:=-1; if (Backend.ItemIndex<>1) or (FImageRect.Width<=0) or (FImageRect.Height<=0) then Exit;
  NX:=(X-FImageRect.Left)/FImageRect.Width; NY:=(Y-FImageRect.Top)/FImageRect.Height; Items:=TextLabels;
  for I:=High(Items) downto 0 do if (NX>=Items[I].Bounds.Left-0.005) and (NX<=Items[I].Bounds.Right+0.005) and
    (NY>=Items[I].Bounds.Top-0.005) and (NY<=Items[I].Bounds.Bottom+0.005) then Exit(I);
end;
function TDiagramForm.BeginLabelEdit(Index:Integer):Boolean;
var Bounds:TRect; W,H,Scale:Double; Caret:Integer; Style:TTeXTextStyle; Error:string;
begin
  FinishLabelEdit; FLabels:=TextLabels;
  Result:=(Backend.ItemIndex=1) and (Index>=0) and (Index<Length(FLabels)); if not Result then Exit;
  FLabelTarget:=FLabels[Index]; FLabelBefore:=Source;
  Bounds:=LabelBounds(FLabelTarget);
  W:=1; H:=1; if FScene<>nil then FScene.PageSize(1,W,H); Scale:=FImageRect.Width/Max(1.0,W);
  Style:=InitialTextStyle(FPreamble,FDirectory,FEngine); ApplyTextStyle(Style,FLabelTarget.FontCode,FDirectory);
  LabelEditor.ConfigureTextStyle(Style,FLabelTarget.Color);
  LabelEditor.SetContext(FPreamble,FDirectory,FEngine,'',False); LabelEditor.PreviewZoom:=Max(0.1,Scale*0.6);
  FLabelBounds:=Bounds; LabelEditor.SetBounds(0,0,Max(120,Bounds.Width),Max(50,Bounds.Height));
  if FLabelTarget.MathLabel then LabelEditor.LoadFormula(FLabelTarget.Text,Error)
  else LabelEditor.LoadParagraph(FLabelTarget.Text,nil);
  LabelEditor.FormulaSourceMode:=False;
  LabelEditor.Font.Color:=InkColor; SetNativeDiagramEditingText(FScene,Index); FSurface.Clear; FPaint.Invalidate;
  LabelEditor.Visible:=True; LayoutLabelEditor(nil); FLabelViewport.Visible:=True; FLabelViewport.BringToFront;
  Caret:=Length(FLabelTarget.Text);
  if (Caret>=2) and (FLabelTarget.Text[1]='$') and (FLabelTarget.Text[Caret]='$') then Dec(Caret)
  else if (Copy(FLabelTarget.Text,1,2)='\(') and (Copy(FLabelTarget.Text,Caret-1,2)='\)') then Dec(Caret,2);
  LabelEditor.SetSourceCaret(Caret); LabelEditor.SetFocus;
  FStatus.Caption:='Editing figure text · Enter applies · Escape cancels';
end;
function TDiagramForm.LabelBounds(const Target:TDiagramText):TRect;
begin
  Result:=Rect(FPaint.Left+FImageRect.Left+Round(Target.Bounds.Left*FImageRect.Width)-10,
    FPaint.Top+FImageRect.Top+Round(Target.Bounds.Top*FImageRect.Height)-10,
    FPaint.Left+FImageRect.Left+Round(Target.Bounds.Right*FImageRect.Width)+10,
    FPaint.Top+FImageRect.Top+Round(Target.Bounds.Bottom*FImageRect.Height)+10);
end;
procedure TDiagramForm.LayoutLabelEditor(Sender:TObject);
var W,H,AvailableHeight,ContentWidth,InnerWidth,InnerHeight,Pass,BarWidth,BarHeight,ScrollX,ScrollY:Integer;
    Vertical,Horizontal,WasVertical:Boolean; Bounds:TRect;
begin
  if FLabelLayout or FClosing or not LabelEditor.Visible then Exit;
  FLabelLayout:=True;
  try
    W:=Max(120,FLabelBounds.Width); if LabelEditor.FormulaSourceMode then W:=Max(W,420);
    W:=Min(W,Max(1,FPaint.Width-8)); AvailableHeight:=Max(1,FPaint.Height-8);
    BarWidth:=GetSystemMetrics(SM_CXVSCROLL); BarHeight:=GetSystemMetrics(SM_CYHSCROLL);
    ScrollX:=FLabelViewport.HorzScrollBar.Position; ScrollY:=FLabelViewport.VertScrollBar.Position;
    Vertical:=False; Horizontal:=False;
    for Pass:=0 to 2 do begin
      WasVertical:=Vertical;
      InnerWidth:=Max(1,W-Ord(Vertical)*BarWidth); LabelEditor.Width:=InnerWidth;
      Bounds:=LabelEditor.EditingFormulaBounds; ContentWidth:=Max(InnerWidth,Bounds.Right+8);
      LabelEditor.Width:=ContentWidth; H:=Max(50,LabelEditor.PreferredHeight+20);
      Horizontal:=ContentWidth>InnerWidth;
      Vertical:=H>AvailableHeight-Ord(Horizontal)*BarHeight;
      if Vertical=WasVertical then Break;
    end;
    FLabelViewport.HorzScrollBar.Visible:=Horizontal; FLabelViewport.VertScrollBar.Visible:=Vertical;
    InnerHeight:=Min(H,Max(1,AvailableHeight-Ord(Horizontal)*BarHeight));
    FLabelViewport.SetBounds(
      EnsureRange(FLabelBounds.Left,FPaint.Left+4,FPaint.Left+Max(4,FPaint.Width-W-4)),
      EnsureRange(FLabelBounds.Top,FPaint.Top+4,FPaint.Top+Max(4,FPaint.Height-InnerHeight-Ord(Horizontal)*BarHeight-4)),
      W,InnerHeight+Ord(Horizontal)*BarHeight);
    SetPreviewScroll(FLabelViewport,0,0); LabelEditor.SetBounds(0,0,ContentWidth,H);
    FLabelViewport.HorzScrollBar.Range:=ContentWidth; FLabelViewport.HorzScrollBar.Page:=InnerWidth;
    FLabelViewport.VertScrollBar.Range:=H; FLabelViewport.VertScrollBar.Page:=InnerHeight;
    SetPreviewScroll(FLabelViewport,Min(ScrollX,Max(0,ContentWidth-InnerWidth)),Min(ScrollY,Max(0,H-InnerHeight)));
  finally FLabelLayout:=False; end;
end;
procedure TDiagramForm.LabelCaretMoved(Sender:TObject);
var P:TPoint; X,Y,W,H:Integer;
begin
  if FLabelLayout or not LabelEditor.Visible then Exit;
  if Sender=nil then LayoutLabelEditor(nil);
  P:=LabelEditor.CaretPoint; X:=FLabelViewport.HorzScrollBar.Position; Y:=FLabelViewport.VertScrollBar.Position;
  W:=FLabelViewport.HorzScrollBar.Page; H:=FLabelViewport.VertScrollBar.Page;
  if P.X<X+4 then X:=Max(0,P.X-4) else if P.X+8>X+W then X:=P.X+8-W;
  if P.Y<Y+12 then Y:=Max(0,P.Y-12) else if P.Y+16>Y+H then Y:=P.Y+16-H;
  SetPreviewScroll(FLabelViewport,EnsureRange(X,0,Max(0,LabelEditor.Width-W)),EnsureRange(Y,0,Max(0,LabelEditor.Height-H)));
end;
procedure TDiagramForm.LabelChanged(Sender:TObject);
var Code,Original:string; A,B,C:Integer;
begin
  if not LabelEditor.Visible or FUpdating then Exit;
  Code:=ReplaceDiagramText(FLabelBefore,FLabelTarget,LabelEditor.Formula,FLabels); Original:=Source;
  if Code=Original then Exit;
  SourceDifference(Original,Code,A,B,C);
  ReplaceCode(Copy(Code,A+1,C-A),A,B); LabelCaretMoved(nil);
end;
procedure TDiagramForm.FinishLabelEdit(Cancel:Boolean);
begin
  if (LabelEditor=nil) or not LabelEditor.Visible then Exit; LabelEditor.Visible:=False; FLabelViewport.Visible:=False;
  SetNativeDiagramEditingText(FScene,-1); FSurface.Clear; FPaint.Invalidate;
  if Cancel and (Source<>FLabelBefore) then ReplaceCode(FLabelBefore,0,Length(Source));
  Changed(SourceEditor);
  FLabelBefore:=''; FLabels:=nil; FRequested:=Source; FDue:=GetTickCount64;
end;
procedure TDiagramForm.LabelFinished(Sender:TObject);
begin FinishLabelEdit; FPaint.Invalidate; end;
procedure TDiagramForm.LabelKey(Sender:TObject; Key:Word; Shift:TShiftState; var Handled:Boolean);
begin Handled:=Key in [VK_RETURN,VK_ESCAPE]; if Handled then FinishLabelEdit(Key=VK_ESCAPE); end;
procedure TDiagramForm.LabelExit(Sender:TObject);
begin if not FUpdating and not FLabelLayout then Application.QueueAsyncCall(@CheckLabelFocus,0); end;
procedure TDiagramForm.CheckLabelFocus(Data:PtrInt);
var Control:TControl;
begin
  Control:=ActiveControl;
  if (Control=nil) or FLabelLayout or FUpdating then Exit;
  while Control<>nil do begin if (Control=LabelEditor) or (Control=FLabelViewport) then Exit; Control:=Control.Parent; end;
  FinishLabelEdit;
end;
