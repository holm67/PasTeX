{ SPDX-License-Identifier: GPL-3.0-or-later }
function TParagraphDraft.DiagramBox(Node:TMathNode; Size,Width:Integer):TDraftBox;
const Colors:array[0..8] of string=('red','blue','green','orange','purple','gray','cyan','magenta','brown');
type TNumbers=array of Integer;
     TBoxes=array of TDraftBox;
     TCellBounds=array of TRect;
var Model:TCommutativeDiagram; Boxes:TBoxes; Cells:TCellBounds;
    ColumnWidths,RowAbove,RowBelow,ColumnX,RowY,ColumnGaps,RowGaps,CellWidths,CellAbove,CellBelow:TNumbers;
    I,J,K,R,C,Index,Start,Gap,Steps,OldLevel,OldBase,MinX,MinY,MaxX,MaxY:Integer;
    B,Lines,Code,Preview:TDraftBox; N:TMathNode; Field:TCommutativeField;
    Em,PadX,PadY,DX,DY,D,NX,NY,CX,CY,C2X,C2Y,SX,SY,EX,EY,T,QX,QY,PX,PY,LastX,LastY,LineWidth,SegmentN,SegmentX,SegmentY,DashPhase,SegmentLength:Double;
    RawSX,RawSY,RawEX,RawEY,PathFirst,PathLast,ShaftFirst,ShaftLast:Double;
    Arrow:TCommutativeArrow; SourceRect,TargetRect:TRect;
    OldDisplay,Controls,Cubic:Boolean; Style:TCommutativeStyle;
    Options,ColorName:string;
  procedure AddLine(X1,Y1,X2,Y2:Double);
  var K:Integer;
  begin
    K:=Length(Lines.Lines); SetLength(Lines.Lines,K+1);
    Lines.Lines[K].A:=Point(Round(X1),Round(Y1)); Lines.Lines[K].B:=Point(Round(X2),Round(Y2));
    Lines.Lines[K].Width:=Max(1,Round(LineWidth));
  end;
  procedure ArrowTip(X,Y,VX,VY:Double; const Kind:string);
  var L,UX,UY:Double; Contours:TArrowContours; Contour:TArrowContour; Tip:TDraftBox; K:Integer;
  begin
    L:=Hypot(VX,VY); if L<0.001 then Exit; UX:=VX/L; UY:=VY/L;
    if (Kind='xy to') or (Kind='xy double to') then begin
      { xyd.mf encodes 16 slope steps per octant, rather than equal angles. }
      if Abs(VX)>=Abs(VY) then begin UX:=Sign(VX); UY:=Floor(16*VY/Abs(VX)+0.5)/16; end
      else begin UY:=Sign(VY); UX:=Floor(16*VX/Abs(VY)+0.5)/16; end;
      L:=Hypot(UX,UY); UX:=UX/L; UY:=UY/L;
    end;
    Contours:=ArrowContours(Kind,LineWidth,Em/MathFontPoints(0));
    for Contour in Contours do begin
      Tip:=TDraftBox.Create; Tip.Shape:=23; Tip.Color:=Lines.Color; Tip.TextEm:=LineWidth;
      if Contour.Filled then Tip.FillColor:=Tip.Color;
      SetLength(Tip.Lines,Length(Contour.Points));
      for K:=0 to High(Contour.Points) do begin
        Tip.Lines[K].A:=Point(Round(X+Contour.Points[K].X*UX-Contour.Points[K].Y*UY),
          Round(Y+Contour.Points[K].X*UY+Contour.Points[K].Y*UX));
        Tip.Lines[K].Width:=Max(1,Round(LineWidth));
      end;
      Result.Children.Insert(0,Tip);
    end;
  end;
  procedure CurvePoint(Position:Double; out X,Y:Double);
  var U:Double;
  begin
    Position:=PathFirst+(PathLast-PathFirst)*Position;
    U:=1-Position;
    if Cubic then begin
      X:=U*U*U*RawSX+3*U*U*Position*CX+3*U*Position*Position*C2X+Position*Position*Position*RawEX;
      Y:=U*U*U*RawSY+3*U*U*Position*CY+3*U*Position*Position*C2Y+Position*Position*Position*RawEY;
    end else begin X:=U*U*RawSX+2*U*Position*CX+Position*Position*RawEX; Y:=U*U*RawSY+2*U*Position*CY+Position*Position*RawEY; end;
  end;
  procedure Tangent(Position:Double; out X,Y:Double);
  begin
    Position:=PathFirst+(PathLast-PathFirst)*Position;
    if Cubic then begin
      X:=Sqr(1-Position)*(CX-RawSX)+2*(1-Position)*Position*(C2X-CX)+Sqr(Position)*(RawEX-C2X);
      Y:=Sqr(1-Position)*(CY-RawSY)+2*(1-Position)*Position*(C2Y-CY)+Sqr(Position)*(RawEY-C2Y);
    end else begin X:=(1-Position)*(CX-RawSX)+Position*(RawEX-CX); Y:=(1-Position)*(CY-RawSY)+Position*(RawEY-CY); end;
  end;
  function ShaftParameter(Distance:Double; Reverse:Boolean):Double;
  var Step,Pass:Integer; A,B,M,X,Y,OriginX,OriginY:Double;
    function Outside(Position:Double):Boolean;
    begin
      if Reverse then Position:=1-Position; CurvePoint(Position,X,Y);
      Result:=Hypot(X-OriginX,Y-OriginY)>=Distance;
    end;
  begin
    Result:=0; if Reverse then CurvePoint(1,OriginX,OriginY) else CurvePoint(0,OriginX,OriginY);
    if Distance>0 then begin
      Result:=1;
      for Step:=1 to 64 do if Outside(Step/64) then begin
        A:=(Step-1)/64; B:=Step/64;
        for Pass:=1 to 14 do begin M:=(A+B)/2; if Outside(M) then B:=M else A:=M; end;
        Result:=B; Break;
      end;
    end;
    if Reverse then Result:=1-Result;
  end;
  function BoundaryParameter(const Bounds:TRect; Reverse:Boolean):Double;
  var Step,Pass:Integer; A,B,M,X,Y:Double;
    function Outside(Position:Double):Boolean;
    begin
      if Reverse then Position:=1-Position; CurvePoint(Position,X,Y);
      Result:=(X<Bounds.Left) or (X>Bounds.Right) or (Y<Bounds.Top) or (Y>Bounds.Bottom);
    end;
  begin
    Result:=0;
    if not Outside(0) then for Step:=1 to 128 do if Outside(Step/128) then begin
      A:=(Step-1)/128; B:=Step/128;
      for Pass:=1 to 14 do begin M:=(A+B)/2; if Outside(M) then B:=M else A:=M; end;
      Result:=B; Break;
    end;
    if Reverse then Result:=1-Result;
  end;
  procedure Direction(const Name:string; out X,Y:Double);
  var C:Char; Length:Double;
  begin
    X:=0; Y:=0;
    for C in Name do case C of 'r':X:=X+1; 'l':X:=X-1; 'u':Y:=Y-1; 'd':Y:=Y+1; end;
    Length:=Hypot(X,Y); if Length>0 then begin X:=X/Length; Y:=Y/Length; end;
  end;
  procedure FitBounds(Box:TDraftBox; X,Y:Integer);
  var I:Integer;
  begin
    Inc(X,Box.X); Inc(Y,Box.Y); MinX:=Min(MinX,X); MinY:=Min(MinY,Y);
    MaxX:=Max(MaxX,X+Box.W); MaxY:=Max(MaxY,Y+Box.H);
    if Box.Shape in [9,23] then for I:=0 to High(Box.Lines) do begin
      MinX:=Min(MinX,X+Min(Box.Lines[I].A.X,Box.Lines[I].B.X)); MinY:=Min(MinY,Y+Min(Box.Lines[I].A.Y,Box.Lines[I].B.Y));
      MaxX:=Max(MaxX,X+Max(Box.Lines[I].A.X,Box.Lines[I].B.X)); MaxY:=Max(MaxY,Y+Max(Box.Lines[I].A.Y,Box.Lines[I].B.Y));
    end;
  end;
begin
  if Node.SourcePreview<>nil then begin
    Controls:=ShowSourceControls; ShowSourceControls:=False;
    try Preview:=DiagramBox(Node.SourcePreview,Size,Width); finally ShowSourceControls:=Controls; end;
    ClearBoxIDs(Preview); Code:=DefinitionBox(TMathNode(Node.Children[0]),Size,Width-8); Code.Shape:=0;
    Result:=TDraftBox.Create; Result.ID:=Node.ID; Result.DiagramContent:=True;
    Result.W:=Max(Preview.W,Code.W)+8; Preview.Y:=4;
    Code.X:=4; Code.Y:=Preview.Y+Preview.H+6; Result.H:=Code.Y+Code.H+4; Result.Baseline:=Preview.Y+Preview.Baseline;
    Result.Children.Add(Preview); Result.Children.Add(Code);
    if ShowSourceControls then AddSourceControl(Result,Preview.Y+Preview.H,MathSourceOffset(Node)-Length(Node.Prefix),True,False);
    Preview.X:=(Result.W-Preview.W) div 2; Exit;
  end;
  Model:=TCommutativeDiagram.Create; Result:=TDraftBox.Create; Result.ID:=Node.ID;
  Result.DiagramContent:=True;
  try
    if not Model.Load(Node.TeX,MathFontPoints(0)) then Exit;
    Em:=MeasureEm(Size); SetLength(Boxes,Length(Model.Fields)); SetLength(Cells,Model.Rows*Model.Columns);
    SetLength(CellWidths,Length(Cells)); SetLength(CellAbove,Length(Cells)); SetLength(CellBelow,Length(Cells));
    PadX:=Em*0.43; PadY:=Em*0.43*0.85;
    if Model.PackageName='xy' then begin PadX:=Em*3/MathFontPoints(0); PadY:=PadX; end;
    SetLength(ColumnWidths,Model.Columns); SetLength(ColumnX,Model.Columns); SetLength(ColumnGaps,Model.Columns);
    SetLength(RowAbove,Model.Rows); SetLength(RowBelow,Model.Rows); SetLength(RowY,Model.Rows); SetLength(RowGaps,Model.Rows);
    for I:=0 to Model.Columns-1 do begin ColumnWidths[I]:=Round(Em*0.7); ColumnGaps[I]:=Round(Em*Model.ColumnGap); end;
    for I:=0 to Model.Rows-1 do begin RowAbove[I]:=Round(Em*0.7); RowBelow[I]:=Round(Em*0.2); RowGaps[I]:=Round(Em*Model.RowGap); end;
    OldDisplay:=FDisplayMath; OldLevel:=FMathLevel; OldBase:=FMathBaseSize;
    FDisplayMath:=False; FMathLevel:=0; FMathBaseSize:=Size;
    try
      for I:=0 to Node.Children.Count-1 do begin
        N:=TMathNode(Node.Children[I]); if (N.Kind<>mkFormula) or (N.DiagramField<0) or (N.DiagramField>=Length(Boxes)) then Continue;
        Index:=N.DiagramField; Field:=Model.Fields[Index]; J:=Size;
        if Field.Kind=cfLabel then begin FMathLevel:=1; J:=MathFontSize(1); end else FMathLevel:=0;
        B:=MathBox(TMathNode(N.Children[0]),J); B.ID:=N.ID; Boxes[Index]:=B;
        R:=Field.Row; C:=Field.Col; K:=R*Model.Columns+C;
        if Field.Kind=cfCell then begin
          Inc(CellWidths[K],B.W); CellAbove[K]:=Max(CellAbove[K],B.Baseline); CellBelow[K]:=Max(CellBelow[K],B.H-B.Baseline);
          ColumnWidths[C]:=Max(ColumnWidths[C],CellWidths[K]+Round(2*PadX));
          RowAbove[R]:=Max(RowAbove[R],CellAbove[K]+Round(PadY)); RowBelow[R]:=Max(RowBelow[R],CellBelow[K]+Round(PadY));
        end;
      end;
    finally FDisplayMath:=OldDisplay; FMathLevel:=OldLevel; FMathBaseSize:=OldBase; end;
    Start:=4;
    Gap:=4;
    for C:=0 to Model.Columns-1 do begin ColumnX[C]:=Gap; Inc(Gap,ColumnWidths[C]+ColumnGaps[C]); end;
    Result.W:=Gap-ColumnGaps[High(ColumnGaps)]+4; Gap:=Start;
    for R:=0 to Model.Rows-1 do begin RowY[R]:=Gap+RowAbove[R]; Inc(Gap,RowAbove[R]+RowBelow[R]+RowGaps[R]); end;
    Result.H:=Gap-RowGaps[High(RowGaps)]+4; Result.Baseline:=Result.H div 2+Round(Em*0.25);
    for R:=0 to Model.Rows-1 do for C:=0 to Model.Columns-1 do begin
      K:=R*Model.Columns+C; J:=ColumnX[C]+(ColumnWidths[C]-CellWidths[K]) div 2;
      Cells[K]:=Rect(J-Round(PadX),RowY[R]-CellAbove[K]-Round(PadY),J+CellWidths[K]+Round(PadX),RowY[R]+CellBelow[K]+Round(PadY));
    end;
    for I:=0 to High(Boxes) do if (Boxes[I]<>nil) and (Model.Fields[I].Kind=cfCell) then begin
      B:=Boxes[I]; Field:=Model.Fields[I]; R:=Field.Row; C:=Field.Col;
      K:=R*Model.Columns+C; B.X:=Cells[K].Left+Round(PadX); Inc(Cells[K].Left,B.W);
      B.Y:=RowY[R]-B.Baseline; Result.Children.Add(B);
    end;
    for K:=0 to High(Cells) do Dec(Cells[K].Left,CellWidths[K]);
    for I:=0 to High(Model.Arrows) do begin
      Arrow:=Model.Arrows[I];
      if (Arrow.Row<0) or (Arrow.Row>=Model.Rows) or (Arrow.Col<0) or (Arrow.Col>=Model.Columns) or
        (Arrow.TargetRow<0) or (Arrow.TargetRow>=Model.Rows) or (Arrow.TargetCol<0) or (Arrow.TargetCol>=Model.Columns) then Continue;
      SourceRect:=Cells[Arrow.Row*Model.Columns+Arrow.Col]; TargetRect:=Cells[Arrow.TargetRow*Model.Columns+Arrow.TargetCol];
      SX:=(SourceRect.Left+SourceRect.Right)/2; SY:=RowY[Arrow.Row]-Em*0.25;
      EX:=(TargetRect.Left+TargetRect.Right)/2; EY:=RowY[Arrow.TargetRow]-Em*0.25;
      DX:=EX-SX; DY:=EY-SY; D:=Hypot(DX,DY); NX:=0; NY:=-1;
      if D>0.001 then begin NX:=DY/D; NY:=-DX/D; end;
      CX:=(SX+EX)/2+NX*D*Tan(EnsureRange(Arrow.Curve,-80,80)*Pi/360);
      CY:=(SY+EY)/2+NY*D*Tan(EnsureRange(Arrow.Curve,-80,80)*Pi/360);
      if Arrow.FixedCurve then begin CX:=(SX+EX)/2+NX*2*Arrow.CurveHeight*Em; CY:=(SY+EY)/2+NY*2*Arrow.CurveHeight*Em; end;
      C2X:=CX; C2Y:=CY;
      Cubic:=(Arrow.OutDirection<>'') and (Arrow.InDirection<>'');
      if Cubic then begin
        Direction(Arrow.OutDirection,PX,PY); CX:=SX+PX*36*Em/MathFontPoints(0); CY:=SY+PY*36*Em/MathFontPoints(0);
        Direction(Arrow.InDirection,PX,PY); C2X:=EX+PX*36*Em/MathFontPoints(0); C2Y:=EY+PY*36*Em/MathFontPoints(0);
      end;
      if (Model.PackageName='tikz-cd') and (Arrow.HasAngles or (Abs(Arrow.Curve)>0.001)) and (D>0.001) then begin
        Cubic:=True; PX:=Arrow.OutAngle*Pi/180; PY:=Arrow.InAngle*Pi/180;
        if not Arrow.HasAngles then begin
          PX:=ArcTan2(-DY,DX)+Arrow.Curve*Pi/180; PY:=ArcTan2(DY,-DX)-Arrow.Curve*Pi/180;
        end;
        T:=D*0.3915*Arrow.Looseness;
        CX:=SX+Cos(PX)*T; CY:=SY-Sin(PX)*T;
        C2X:=EX+Cos(PY)*T; C2Y:=EY-Sin(PY)*T;
      end;
      Options:=Arrow.Options;
      if (D<0.001) and not Cubic then begin
        Cubic:=True; CX:=SX+Em*2; CY:=SY-Em*3; C2X:=SX-Em*2; C2Y:=CY;
        if Pos('loop below',Options)>0 then begin CY:=SY+Em*3; C2Y:=CY; end;
        if Pos('loop left',Options)>0 then begin CX:=SX-Em*3; C2X:=CX; CY:=SY-Em*2; C2Y:=SY+Em*2; end;
        if Pos('loop right',Options)>0 then begin CX:=SX+Em*3; C2X:=CX; CY:=SY-Em*2; C2Y:=SY+Em*2; end;
      end;
      SX:=SX+NX*Arrow.Shift*Em; EX:=EX+NX*Arrow.Shift*Em; CX:=CX+NX*Arrow.Shift*Em;
      SY:=SY+NY*Arrow.Shift*Em; EY:=EY+NY*Arrow.Shift*Em; CY:=CY+NY*Arrow.Shift*Em;
      C2X:=C2X+NX*Arrow.Shift*Em; C2Y:=C2Y+NY*Arrow.Shift*Em;
      RawSX:=SX; RawSY:=SY; RawEX:=EX; RawEY:=EY; PathFirst:=0; PathLast:=1;
      PX:=BoundaryParameter(SourceRect,False); PY:=BoundaryParameter(TargetRect,True);
      PathFirst:=PX; PathLast:=Max(PX,PY); CurvePoint(0,SX,SY); CurvePoint(1,EX,EY);
      Lines:=TDraftBox.Create; Lines.Shape:=9; Lines.Color:=clBlack;
      for ColorName in Colors do
        if Pos(ColorName,Options)>0 then Lines.Color:=NamedColor(ColorName);
      LineWidth:=Em*0.4/MathFontPoints(0); if Pos('thick',Options)>0 then LineWidth:=Em*0.8/MathFontPoints(0);
      Lines.TextEm:=LineWidth;
      Style:=CommutativeStyle(Model.Options,Options);
      if Model.PackageName='xy' then begin
        Style.StartTip:=StringReplace(Style.StartTip,'cm double to','xy double to',[]);
        Style.EndTip:=StringReplace(Style.EndTip,'cm double to','xy double to',[]);
        Style.StartTip:=StringReplace(Style.StartTip,'cm to','xy to',[]);
        Style.EndTip:=StringReplace(Style.EndTip,'cm to','xy to',[]);
        if (Style.StartTip='<') or (Style.StartTip='>') then Style.StartTip:='xy to';
        if (Style.EndTip='<') or (Style.EndTip='>') then Style.EndTip:='xy to';
      end;
      ShaftFirst:=ShaftParameter(ArrowShaftInset(Style.StartTip,LineWidth,Em/MathFontPoints(0)),False);
      ShaftLast:=ShaftParameter(ArrowShaftInset(Style.EndTip,LineWidth,Em/MathFontPoints(0)),True);
      CurvePoint(ShaftFirst,LastX,LastY);
      Steps:=1; if Cubic or Arrow.FixedCurve or (Abs(Arrow.Curve)>0.001) then Steps:=64;
      if Style.Dashed or Style.Dotted then Steps:=Min(4096,Max(Steps,Ceil(Hypot(EX-SX,EY-SY)/Max(1,LineWidth))));
      DashPhase:=0;
      if not Style.Phantom and (ShaftLast>ShaftFirst) then for J:=1 to Steps do begin
        CurvePoint(ShaftFirst+(ShaftLast-ShaftFirst)*J/Steps,QX,QY);
        SegmentLength:=Hypot(QX-LastX,QY-LastY);
        if (not Style.Dashed or (Frac(DashPhase/Max(1,11*LineWidth))<7/11)) and
           (not Style.Dotted or (Frac(DashPhase/Max(1,4*LineWidth))<0.25)) then begin
          if Style.DoubleLine or Style.TripleLine then begin
            SegmentN:=Max(0.001,SegmentLength); SegmentX:=(QY-LastY)/SegmentN*Em*0.08; SegmentY:=-(QX-LastX)/SegmentN*Em*0.08;
            AddLine(LastX+SegmentX,LastY+SegmentY,QX+SegmentX,QY+SegmentY);
            AddLine(LastX-SegmentX,LastY-SegmentY,QX-SegmentX,QY-SegmentY);
            if Style.TripleLine then AddLine(LastX,LastY,QX,QY);
          end else AddLine(LastX,LastY,QX,QY);
        end;
        DashPhase:=DashPhase+SegmentLength;
        LastX:=QX; LastY:=QY;
      end;
      Tangent(1,PX,PY); ArrowTip(EX,EY,PX,PY,Style.EndTip);
      Tangent(0,PX,PY); ArrowTip(SX,SY,-PX,-PY,Style.StartTip);
      Result.Children.Insert(0,Lines);
      for J:=0 to High(Boxes) do if (Boxes[J]<>nil) and (Model.Fields[J].Kind=cfLabel) and (Model.Fields[J].Arrow=I) then begin
        B:=Boxes[J]; Field:=Model.Fields[J]; T:=Field.Position; CurvePoint(T,PX,PY);
        Tangent(T,DX,DY);
        D:=Max(0.001,Hypot(DX,DY));
        NX:=DY/D; NY:=-DX/D;
        if Field.Side<>0 then begin
          D:=Em*0.12; if Model.PackageName='xy' then D:=3*Em/MathFontPoints(0);
          D:=D+Abs(NX)*B.W/2+Abs(NY)*B.H/2;
          PX:=PX+NX*Field.Side*D; PY:=PY+NY*Field.Side*D;
        end;
        B.X:=Round(PX-B.W/2); B.Y:=Round(PY-B.H/2); Result.Children.Add(B);
      end;
    end;
    { Unattached label fields stay editable, including an unfinished route. }
    for I:=0 to High(Boxes) do if (Boxes[I]<>nil) and (Result.Children.IndexOf(Boxes[I])<0) then begin
      B:=Boxes[I]; B.X:=4; B.Y:=Result.H+4; Inc(Result.H,B.H+4); Result.Children.Add(B);
    end;
    MinX:=0; MinY:=0; MaxX:=Result.W; MaxY:=Result.H;
    for I:=0 to Result.Children.Count-1 do FitBounds(TDraftBox(Result.Children[I]),0,0);
    for I:=0 to Result.Children.Count-1 do begin B:=TDraftBox(Result.Children[I]); Inc(B.X,4-MinX); Inc(B.Y,4-MinY); end;
    Result.W:=MaxX-MinX+8; Result.H:=MaxY-MinY+8; Inc(Result.Baseline,4-MinY);
    if ShowSourceControls then AddSourceControl(Result,Result.H-4,MathSourceOffset(Node)-Length(Node.Prefix),False,False);
  finally Model.Free; end;
end;
