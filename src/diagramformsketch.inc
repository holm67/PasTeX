{ SPDX-License-Identifier: GPL-3.0-or-later }
function TDiagramForm.HandleAt(X,Y:Integer):Integer;
var Handles:TDiagramHandles; I:Integer; Distance,Best,DX,DY:Double;
begin
  Result:=-1; Best:=10; if FSceneSource<>Source then Exit; Handles:=NativeDiagramHandles(FScene);
  for I:=High(Handles) downto 0 do begin
    DX:=FImageRect.Left+Handles[I].X*FImageRect.Width-X; DY:=FImageRect.Top+Handles[I].Y*FImageRect.Height-Y; Distance:=Hypot(DX,DY);
    if Distance<Best then begin Best:=Distance; Result:=I; end;
  end;
end;
function TDiagramForm.SegmentAt(X,Y:Integer):Integer;
var Handles:TDiagramHandles; Segments:TDiagramSegments; I:Integer; AX,AY,DX,DY,T,Distance,Best:Double;
begin
  Result:=-1; Best:=6; if FSceneSource<>Source then Exit;
  Handles:=NativeDiagramHandles(FScene); Segments:=NativeDiagramSegments(FScene);
  for I:=High(Segments) downto 0 do begin
    AX:=FImageRect.Left+Handles[Segments[I].First].X*FImageRect.Width;
    AY:=FImageRect.Top+Handles[Segments[I].First].Y*FImageRect.Height;
    DX:=(Handles[Segments[I].Last].X-Handles[Segments[I].First].X)*FImageRect.Width;
    DY:=(Handles[Segments[I].Last].Y-Handles[Segments[I].First].Y)*FImageRect.Height;
    if Sqr(DX)+Sqr(DY)<1 then Continue;
    T:=EnsureRange(((X-AX)*DX+(Y-AY)*DY)/(Sqr(DX)+Sqr(DY)),0.0,1.0);
    Distance:=Hypot(X-AX-T*DX,Y-AY-T*DY);
    if Distance<Best then begin Best:=Distance; Result:=I; end;
  end;
end;
function TDiagramForm.DraggedHandle(Index:Integer):Boolean;
begin
  Result:=(Index=FDragHandle) or ((FDragSegment>=0) and (Index=FDragOther));
end;
procedure TDiagramForm.SketchToolChanged(Sender:TObject);
var I:Integer;
begin
  if FUpdating then Exit;
  FinishLabelEdit; CancelSketch; FDragging:=False; SetCaptureControl(nil);
  FSketchStyleTool:=EnsureRange(SketchTool.ItemIndex,0,10); SketchOptions.Text:=FSketchStyles[FSketchStyleTool]; UpdateSketchActions;
  for I:=0 to ComponentCount-1 do if (Components[I] is TSpeedButton) and
    (TSpeedButton(Components[I]).Parent=FindComponent('SketchTools')) and (Copy(Components[I].Name,1,11)='DrawingTool') then
    TSpeedButton(Components[I]).Down:=TComponent(Components[I]).Tag=FSketchStyleTool;
  if SketchTool.ItemIndex in [4,6] then FStatus.Caption:='Click path points; Enter or double-click finishes. Click the first point to close. Escape cancels.'
  else if SketchTool.ItemIndex=9 then FStatus.Caption:='Click two opposite corners to draw a rectangle. Escape cancels.'
  else if SketchTool.ItemIndex=10 then FStatus.Caption:='Click the center, then a point on the circumference. Escape cancels.'
  else FStatus.Caption:='Drag a point or line segment to move it. Tool styles are independent of the selected element.';
end;
procedure TDiagramForm.SketchToolClick(Sender:TObject);
begin SketchTool.ItemIndex:=TComponent(Sender).Tag; SketchToolChanged(SketchTool); end;
procedure TDiagramForm.SnapPoint(var X,Y:Double);
var Step:Double; Format:TFormatSettings;
begin
  if SketchSnap.ItemIndex<=0 then Exit;
  Format:=DefaultFormatSettings; Format.DecimalSeparator:='.';
  Step:=StrToFloatDef(SketchSnap.Text,0,Format); if Step<=0 then Exit;
  X:=Round(X/Step)*Step; Y:=Round(Y/Step)*Step;
end;
procedure TDiagramForm.SketchStyleChanged(Sender:TObject);
begin if not FUpdating then FSketchStyles[FSketchStyleTool]:=SketchOptions.Text; end;
procedure TDiagramForm.UpdateSketchActions;
var I:Integer;
begin
  FPathFinish.Enabled:=(Backend.ItemIndex=1) and FSketchWaiting and (Length(FSketchPoints)>=2);
  FPathClose.Enabled:=FPathFinish.Enabled and (SketchTool.ItemIndex=4) and (Length(FSketchPoints)>=3);
  TDiagramRow(FPathFinish.Parent).Arrange;
  TControl(FindComponent('DiagramUndo')).Enabled:=SourceEditor.CanUndo;
  TControl(FindComponent('DiagramRedo')).Enabled:=SourceEditor.CanRedo;
  SketchOptions.Enabled:=(Backend.ItemIndex=1) and (SketchTool.ItemIndex in [2..6,9,10]);
  TControl(FindComponent('SketchOptionsBrowser')).Enabled:=SketchOptions.Enabled;
  for I:=0 to ComponentCount-1 do if (Components[I] is TSpeedButton) and
    (TSpeedButton(Components[I]).Parent=FindComponent('SketchTools')) and (Copy(Components[I].Name,1,11)='DrawingTool') then
    TSpeedButton(Components[I]).Enabled:=SketchTool.Enabled;
end;
procedure TDiagramForm.CancelSketch;
begin
  FSketchWaiting:=False; FSketchPoints:=nil; FSketchSource:=''; UpdateSketchActions; FPaint.Invalidate;
end;
procedure TDiagramForm.FinishSketchPath(Closed:Boolean);
var Code:string;
begin
  if not FSketchWaiting or (Length(FSketchPoints)<2) then Exit;
  if Source<>FSketchSource then begin CancelSketch; Exit; end;
  Code:=InsertSketchPath(Source,SketchOptions.Text,FSketchPoints,Closed); CancelSketch;
  if Code<>Source then begin ReplaceCode(Code,0,Length(Source)); FSelectedCommand:=-1; FDue:=GetTickCount64; end;
end;
procedure TDiagramForm.SketchFinish(Sender:TObject);
begin FinishLabelEdit; FinishSketchPath(TComponent(Sender).Tag=1); end;
procedure TDiagramForm.SketchDoubleClick(Sender:TObject);
begin FinishSketchPath; end;
procedure TDiagramForm.SketchHistory(Sender:TObject);
begin
  FinishLabelEdit; CancelSketch;
  if TComponent(Sender).Tag=0 then SourceEditor.Undo else SourceEditor.Redo;
end;
procedure TDiagramForm.SketchKey(Sender:TObject; var Key:Word; Shift:TShiftState);
begin
  if LabelEditor.Visible then Exit;
  if Key=VK_ESCAPE then begin
    if FDragging or FSketchWaiting then begin FDragging:=False; CancelSketch; SetCaptureControl(nil); Key:=0; end;
  end else if FSketchWaiting and not SourceEditor.Focused and not SketchOptions.Focused and (Shift=[]) then begin
    case Key of
      VK_RETURN:begin FinishSketchPath; Key:=0; end;
      VK_BACK:begin
        SetLength(FSketchPoints,Max(0,Length(FSketchPoints)-1));
        if Length(FSketchPoints)=0 then CancelSketch else begin UpdateSketchActions; FPaint.Invalidate; end; Key:=0;
      end;
    end;
  end else if (ssCtrl in Shift) and (Key in [VK_Z,VK_Y]) then begin
    CancelSketch; if (Key=VK_Y) or (ssShift in Shift) then SourceEditor.Redo else SourceEditor.Undo; Key:=0;
  end;
end;
procedure TDiagramForm.PaintSketch;
var Handles:TDiagramHandles; I,X,Y,Count:Integer; First:TPoint;
begin
  if (Backend.ItemIndex<>1) or LabelEditor.Visible then Exit;
  Handles:=NativeDiagramHandles(FScene); FPaint.Canvas.Pen.Color:=clHighlight; FPaint.Canvas.Pen.Width:=1;
  FPaint.Canvas.Brush.Color:=PaperColor;
  Count:=0; First:=Point(0,0);
  if FDragging then begin
    FPaint.Canvas.Pen.Style:=psDash;
    for I:=0 to High(Handles) do if Handles[I].Command=FSelectedCommand then begin
      X:=FImageRect.Left+Round(Handles[I].X*FImageRect.Width); Y:=FImageRect.Top+Round(Handles[I].Y*FImageRect.Height);
      if DraggedHandle(I) then begin Inc(X,FDragPoint.X-FDragStart.X); Inc(Y,FDragPoint.Y-FDragStart.Y); end;
      if Count=0 then begin First:=Point(X,Y); FPaint.Canvas.MoveTo(X,Y); end else FPaint.Canvas.LineTo(X,Y); Inc(Count);
    end;
    if (Count>1) and (FSelectedCommand<Length(FModel.Commands)) and
      (Pos('cycle',FModel.Text(FModel.Commands[FSelectedCommand].Body))>0) then FPaint.Canvas.LineTo(First.X,First.Y);
    FPaint.Canvas.Pen.Style:=psSolid;
  end;
  for I:=0 to High(Handles) do begin
    if (Handles[I].Command<>FSelectedCommand) and (SketchTool.ItemIndex=1) then Continue;
    if (FSelectedCommand>=0) and (Handles[I].Command<>FSelectedCommand) then Continue;
    X:=FImageRect.Left+Round(Handles[I].X*FImageRect.Width); Y:=FImageRect.Top+Round(Handles[I].Y*FImageRect.Height);
    if FDragging and DraggedHandle(I) then begin Inc(X,FDragPoint.X-FDragStart.X); Inc(Y,FDragPoint.Y-FDragStart.Y); end;
    FPaint.Canvas.Rectangle(X-4,Y-4,X+5,Y+5);
  end;
  if FSketchWaiting then begin
    FPaint.Canvas.Pen.Width:=2;
    if SketchTool.ItemIndex in [9,10] then begin
      X:=FImageRect.Left+Round(FSketchPoints[0].X*FImageRect.Width);
      Y:=FImageRect.Top+Round(FSketchPoints[0].Y*FImageRect.Height);
      FPaint.Canvas.Brush.Style:=bsClear;
      if SketchTool.ItemIndex=9 then FPaint.Canvas.Rectangle(Min(X,FDragPoint.X),Min(Y,FDragPoint.Y),Max(X,FDragPoint.X),Max(Y,FDragPoint.Y))
      else begin I:=Round(Hypot(FDragPoint.X-X,FDragPoint.Y-Y)); FPaint.Canvas.Ellipse(X-I,Y-I,X+I,Y+I); end;
      FPaint.Canvas.Pen.Width:=1; Exit;
    end;
    for I:=0 to High(FSketchPoints) do begin
      X:=FImageRect.Left+Round(FSketchPoints[I].X*FImageRect.Width); Y:=FImageRect.Top+Round(FSketchPoints[I].Y*FImageRect.Height);
      if I=0 then FPaint.Canvas.MoveTo(X,Y) else FPaint.Canvas.LineTo(X,Y);
    end;
    FPaint.Canvas.Pen.Style:=psDash; FPaint.Canvas.LineTo(FDragPoint.X,FDragPoint.Y); FPaint.Canvas.Pen.Style:=psSolid; FPaint.Canvas.Pen.Width:=1;
    for I:=0 to High(FSketchPoints) do begin
      X:=FImageRect.Left+Round(FSketchPoints[I].X*FImageRect.Width); Y:=FImageRect.Top+Round(FSketchPoints[I].Y*FImageRect.Height);
      FPaint.Canvas.Rectangle(X-4,Y-4,X+5,Y+5);
    end;
  end;
end;
procedure TDiagramForm.PreviewMouseDown(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
var Handles:TDiagramHandles; Segments:TDiagramSegments; Index,Tool,N:Integer; X2,Y2:Double; Code,ObjectKind,Style:string;
begin
  if (Button=mbRight) and FSketchWaiting then begin FinishSketchPath; Exit; end;
  if Button<>mbLeft then Exit; FinishLabelEdit;
  if (Backend.ItemIndex<>1) or not PreparePreview then Exit;
  Tool:=SketchTool.ItemIndex;
  if not PtInRect(FPaint.ClientRect,Point(X,Y)) then Exit;
  if not (Tool in [2..6,9,10]) and not PtInRect(FImageRect,Point(X,Y)) then Exit;
  Index:=HandleAt(X,Y); Handles:=NativeDiagramHandles(FScene);
  if Tool=1 then begin BeginLabelEdit(LabelAt(X,Y)); Exit; end;
  if Tool=0 then begin
    FDragSegment:=-1; FDragLabel:=LabelAt(X,Y);
    if Index<0 then begin
      if FDragLabel>=0 then begin BeginLabelEdit(FDragLabel); Exit; end;
      FDragSegment:=SegmentAt(X,Y); if FDragSegment<0 then Exit;
      Segments:=NativeDiagramSegments(FScene); Index:=Segments[FDragSegment].First; FDragOther:=Segments[FDragSegment].Last;
    end;
    FDragHandle:=Index; FDragStart:=Point(X,Y); FDragPoint:=FDragStart;
    FSelectedCommand:=Handles[Index].Command; FDragSource:=Source; FDragging:=True; SetCaptureControl(FPaint);
    Objects.Row:=FSelectedCommand; Selected(nil); FPaint.Invalidate; Exit;
  end;
  if Tool in [7,8] then begin
    if Index<0 then Exit;
    Code:=DeleteDiagramPoint(Source,Handles[Index].Command,Handles[Index].Row,Tool=8);
  end else begin
    if not NativeDiagramCoordinate(FScene,(X-FImageRect.Left)/FImageRect.Width,(Y-FImageRect.Top)/FImageRect.Height,X2,Y2) then Exit;
    SnapPoint(X2,Y2);
    if Tool in [9,10] then begin
      if not FSketchWaiting then begin
        FSketchSource:=Source; FSketchWaiting:=True; SetLength(FSketchPoints,1);
        FSketchPoints[0].SourceX:=X2; FSketchPoints[0].SourceY:=Y2;
        FSketchPoints[0].X:=(X-FImageRect.Left)/FImageRect.Width; FSketchPoints[0].Y:=(Y-FImageRect.Top)/FImageRect.Height;
        FDragPoint:=Point(X,Y); if FPreviewPanel.CanFocus then FPreviewPanel.SetFocus; FPaint.Invalidate; Exit;
      end;
      ObjectKind:='rectangle'; if Tool=10 then ObjectKind:='circle';
      Code:=InsertSketchObject(Source,ObjectKind,SketchOptions.Text,'',FSketchPoints[0].SourceX,FSketchPoints[0].SourceY,X2,Y2);
      CancelSketch;
    end else
    if Tool in [4,6] then begin
      if FPreviewPanel.CanFocus then FPreviewPanel.SetFocus; N:=Length(FSketchPoints);
      if (N>=3) and (Tool=4) and (Hypot(X-FImageRect.Left-FSketchPoints[0].X*FImageRect.Width,Y-FImageRect.Top-FSketchPoints[0].Y*FImageRect.Height)<8) then begin FinishSketchPath(True); Exit; end;
      if (N>0) and (Hypot(X-FImageRect.Left-FSketchPoints[N-1].X*FImageRect.Width,Y-FImageRect.Top-FSketchPoints[N-1].Y*FImageRect.Height)<3) then Exit;
      if N>=2048 then Exit;
      if not FSketchWaiting then FSketchSource:=Source;
      FSketchWaiting:=True; SetLength(FSketchPoints,N+1); FSketchPoints[N]:=Default(TDiagramHandle);
      FSketchPoints[N].X:=(X-FImageRect.Left)/FImageRect.Width; FSketchPoints[N].Y:=(Y-FImageRect.Top)/FImageRect.Height;
      FSketchPoints[N].SourceX:=X2; FSketchPoints[N].SourceY:=Y2;
      FDragPoint:=Point(X,Y); UpdateSketchActions; FPaint.Invalidate; Exit;
    end else begin
      case Tool of 2:ObjectKind:='point'; 3:ObjectKind:='node'; else ObjectKind:='label'; end;
      Style:=SketchOptions.Text;
      Code:=InsertSketchObject(Source,ObjectKind,Style,'Text',X2,Y2,X2,Y2);
    end;
  end;
  if Code<>Source then begin ReplaceCode(Code,0,Length(Source)); FSelectedCommand:=-1; FDue:=GetTickCount64; end;
  FPaint.Invalidate;
end;
procedure TDiagramForm.PreviewMouseMove(Sender:TObject; Shift:TShiftState; X,Y:Integer);
begin
  if Backend.ItemIndex<>1 then begin FPaint.Cursor:=crDefault; Exit; end;
  if not PreparePreview then begin FPaint.Cursor:=crDefault; Exit; end;
  if FDragging or FSketchWaiting then begin FDragPoint:=Point(X,Y); FPaint.Invalidate; end;
  if SketchTool.ItemIndex>1 then FPaint.Cursor:=crCross
  else if FDragging or ((SketchTool.ItemIndex=0) and ((HandleAt(X,Y)>=0) or ((LabelAt(X,Y)<0) and (SegmentAt(X,Y)>=0)))) then FPaint.Cursor:=crSizeAll
  else if LabelAt(X,Y)>=0 then FPaint.Cursor:=crIBeam else FPaint.Cursor:=crDefault;
end;
procedure TDiagramForm.PreviewMouseUp(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
var Code:string; Index:Integer;
begin
  if (Button<>mbLeft) or not FDragging then Exit; FDragging:=False; SetCaptureControl(nil);
  if Hypot(X-FDragStart.X,Y-FDragStart.Y)<3 then begin Index:=FDragLabel; BeginLabelEdit(Index); Exit; end;
  if Source<>FDragSource then Exit;
  if FDragSegment>=0 then Code:=MoveNativeDiagramSegment(FScene,FDragSource,FDragSegment,
    (X-FDragStart.X)/Max(1,FImageRect.Width),(Y-FDragStart.Y)/Max(1,FImageRect.Height))
  else Code:=MoveNativeDiagramPoint(FScene,FDragSource,FDragHandle,(X-FImageRect.Left)/Max(1,FImageRect.Width),(Y-FImageRect.Top)/Max(1,FImageRect.Height));
  if Code<>Source then begin ReplaceCode(Code,0,Length(Source)); FDue:=GetTickCount64; end;
  FDragSource:=''; FPaint.Invalidate;
end;
