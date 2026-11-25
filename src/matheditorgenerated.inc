{ SPDX-License-Identifier: GPL-3.0-or-later }
function TMathEditor.GeneratedTextActive:Boolean;
begin
  Result:=(FGeneratedPreview<>nil) and (FGeneratedPreview.Source=FSource) and
    (FGeneratedPreview.RenderedText<>'') and not FCodeOnly and not FFormulaSourceMode and (FInlineSourceA<0);
end;
function TMathEditor.GeneratedBounds:TRect;
  function Find(Box:TDraftBox; X,Y:Integer):TRect;
  var I:Integer;
  begin
    Result:=Rect(0,0,0,0); if Box=nil then Exit; Inc(X,Box.X); Inc(Y,Box.Y);
    if Box.Shape=16 then Exit(Rect(X,Y,X+Box.W,Y+Box.H));
    for I:=0 to Box.Children.Count-1 do begin Result:=Find(TDraftBox(Box.Children[I]),X,Y); if Result.Right>Result.Left then Exit; end;
  end;
begin EnsureDraft; Result:=Find(FDraft.RootBox,ImageLeft,ImageTop); end;
function TMathEditor.GeneratedCaretBounds:TRect;
var R:TRect; B:TVectorImageBounds; I,X:Integer; AtEnd:Boolean;
begin
  Result:=Rect(10,10,11,30); if Length(FGeneratedPreview.Characters)=0 then Exit;
  R:=GeneratedBounds; I:=EnsureRange(FGeneratedFocus,0,High(FGeneratedPreview.Characters));
  AtEnd:=FGeneratedFocus>=Length(FGeneratedPreview.Characters);
  while (I>0) and ((FGeneratedPreview.Characters[I].Right<=FGeneratedPreview.Characters[I].Left) or
    (FGeneratedPreview.Characters[I].Bottom<=FGeneratedPreview.Characters[I].Top)) do begin Dec(I); AtEnd:=True; end;
  B:=FGeneratedPreview.Characters[I]; X:=R.Left+Round(B.Left*R.Width);
  if AtEnd then X:=R.Left+Round(B.Right*R.Width);
  Result:=Rect(X,R.Top+Round(B.Top*R.Height),X+1,R.Top+Round(B.Bottom*R.Height));
end;
function TMathEditor.GeneratedHit(X,Y:Integer):Integer;
var R:TRect;
begin R:=GeneratedBounds; Result:=FGeneratedPreview.Hit((X-R.Left)/Max(1,R.Width),(Y-R.Top)/Max(1,R.Height)); end;
function TMathEditor.GeneratedLinkAt(X,Y:Integer):Integer;
var R:TRect; I:Integer; PX,PY:Double; Bounds:TVectorImageBounds;
begin
  Result:=-1; if not GeneratedTextActive then Exit; R:=GeneratedBounds;
  PX:=(X-R.Left)/Max(1,R.Width); PY:=(Y-R.Top)/Max(1,R.Height);
  for I:=0 to High(FGeneratedPreview.Links) do begin
    Bounds:=FGeneratedPreview.Links[I].Bounds;
    if (PX>=Bounds.Left) and (PX<=Bounds.Right) and (PY>=Bounds.Top) and (PY<=Bounds.Bottom) then Exit(I);
  end;
end;
function TMathEditor.GeneratedRects:TSelectionRects;
var Bounds:TVectorImageBounds; R:TRect; I:Integer;
begin
  Result:=nil; if not GeneratedTextActive or (FGeneratedAnchor<0) then Exit;
  R:=GeneratedBounds;
  for Bounds in FGeneratedPreview.SelectionBounds(FGeneratedAnchor,FGeneratedFocus) do begin
    I:=Length(Result); SetLength(Result,I+1);
    Result[I]:=Rect(R.Left+Round(Bounds.Left*R.Width),R.Top+Round(Bounds.Top*R.Height),
      R.Left+Round(Bounds.Right*R.Width),R.Top+Round(Bounds.Bottom*R.Height));
  end;
end;
function TMathEditor.GeneratedMouseDown(Button:TMouseButton; Shift:TShiftState; X,Y:Integer):Boolean;
var I,XScroll,YScroll:Integer; Link:TGeneratedLink; Command:string; C:TWinControl; Scroll:TScrollBox;
begin
  Result:=GeneratedTextActive; if not Result then Exit;
  if Button<>mbLeft then Exit;
  FLinkClick:=False;
  I:=GeneratedLinkAt(X,Y);
  if ssCtrl in Shift then begin
    if (I>=0) and Assigned(FGeneratedAction) then begin
      Link:=FGeneratedPreview.Links[I]; Command:=FSource;
      if Link.URI<>'' then Command:='url:'+Link.URI
      else if (Link.Offset<0) and (Link.Page>0) then Command:='page:'+IntToStr(Link.Page);
      FGeneratedAction(Self,Command,Link.Offset,False);
    end else if Assigned(FGeneratedAction) then FGeneratedAction(Self,FSource,-1,True);
    FLinkClick:=True; Exit;
  end;
  FGeneratedFocus:=GeneratedHit(X,Y);
  if not (ssShift in Shift) or (FGeneratedAnchor<0) then FGeneratedAnchor:=FGeneratedFocus;
  FSelectionAnchor:=-1; FSelectionFocus:=-1; FSelected:=False;
  FDragging:=True; FMouseDownPoint:=Point(X,Y); FMouseMoved:=False; MouseCapture:=True;
  Scroll:=nil; C:=Parent;
  while C<>nil do begin if C is TScrollBox then Scroll:=TScrollBox(C); C:=C.Parent; end;
  if Scroll<>nil then begin XScroll:=Scroll.HorzScrollBar.Position; YScroll:=Scroll.VertScrollBar.Position; end;
  if CanFocus then SetFocus; NotifySelection; Invalidate;
  if Scroll<>nil then SetPreviewScroll(Scroll,XScroll,YScroll);
end;
function TMathEditor.GeneratedKey(var Key:Word; Shift:TShiftState):Boolean;
var Selecting:Boolean; P:TPoint; Count:Integer;
begin
  Result:=GeneratedTextActive; if not Result then Exit;
  Count:=UTF8Length(FGeneratedPreview.RenderedText);
  if ssCtrl in Shift then begin
    if Key in [VK_A,VK_C,VK_X,VK_V] then begin ClipboardCommand(Key); Key:=0; end else Result:=False;
    Exit;
  end;
  if Key=VK_ESCAPE then begin if Assigned(FFinish) then FFinish(Self); Key:=0; Exit; end;
  Selecting:=ssShift in Shift;
  if not Selecting then FGeneratedAnchor:=FGeneratedFocus;
  case Key of
    VK_LEFT:FGeneratedFocus:=Max(0,FGeneratedFocus-1);
    VK_RIGHT:FGeneratedFocus:=Min(Count,FGeneratedFocus+1);
    VK_HOME:FGeneratedFocus:=0;
    VK_END:FGeneratedFocus:=Count;
    VK_UP,VK_DOWN:begin
      P:=CaretPoint;
      FGeneratedFocus:=GeneratedHit(P.X,P.Y+IfThen(Key=VK_UP,-20,20));
    end;
    VK_TAB:begin Result:=False; Exit; end;
  end;
  if not Selecting then FGeneratedAnchor:=FGeneratedFocus;
  NotifySelection; Invalidate; Key:=0;
end;
