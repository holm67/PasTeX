{ SPDX-License-Identifier: GPL-3.0-or-later }
function DraftDimension(const Value:string; Em,LineWidth:Double; Default:Integer; PixelsPerPoint:Double):Integer;
var P:Integer; S,UnitName:string; N:Double; Code:Integer;
begin
  S:=Trim(Value); P:=1; while (P<=Length(S)) and (S[P] in ['0'..'9','.','+','-']) do Inc(P);
  Val(Copy(S,1,P-1),N,Code); if Code<>0 then N:=1;
  UnitName:=Copy(S,P,MaxInt);
  case UnitName of
    '\textwidth','\linewidth','\columnwidth','\hsize':N:=N*LineWidth;
    '\textheight':N:=N*LineWidth*550/345;
    '\paperwidth':N:=N*LineWidth*614.295/345;
    '\paperheight':N:=N*LineWidth*794.97/345;
    'pt':N:=N*PixelsPerPoint; 'cm':N:=N*PixelsPerPoint*72.27/2.54;
    'pc':N:=N*PixelsPerPoint*12; 'sp':N:=N*PixelsPerPoint/65536;
    'bp':N:=N*PixelsPerPoint*72.27/72;
    'mm':N:=N*PixelsPerPoint*72.27/25.4; 'in':N:=N*PixelsPerPoint*72.27;
    'em':N:=N*Em; 'ex':N:=N*Em*0.43;
    else Exit(Default);
  end;
  Result:=EnsureRange(Round(N),0,10000);
end;
function DraftSetting(const Source,Name,Default:string):string;
var P:Integer; Cmd,Key,Value:string;
begin
  Result:=Default; P:=1;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Cmd:=ReadTeXCommand(Source,P);
    if (Cmd='setlength') or (Cmd='renewcommand') then begin
      if (P<=Length(Source)) and (Source[P]='*') then Inc(P);
      Key:=ReadTeXGroup(Source,P,'{','}'); Value:=ReadTeXGroup(Source,P,'{','}');
      if Key='\'+Name then Result:=Value;
    end;
  end;
end;
function LastBoxBaseline(Box:TDraftBox):Integer;
var I:Integer; Child:TDraftBox;
begin
  Result:=Box.Baseline;
  for I:=0 to Box.Children.Count-1 do begin
    Child:=TDraftBox(Box.Children[I]);
    if (Child.H>0) and ((Child.Text<>'') or (Child.Shape<>0) or (Child.Children.Count>0)) then
      Result:=Max(Result,Child.Y+Child.Baseline);
  end;
end;
function TParagraphDraft.BoxDimension(const Value:string; Box:TDraftBox; Size,LineWidth,Default:Integer; Vertical:Boolean):Integer;
var Code,Metric:string; Negative:Boolean; Base,Above:Integer; Points:Double;
begin
  Code:=Trim(Value); Negative:=Copy(Code,1,1)='-'; if Negative then Delete(Code,1,1);
  Points:=MeasureEm(FMathBaseSize)/MathFontPoints(0);
  for Metric in ['\totalheight','\height','\depth','\width'] do if Pos(Metric,Code)>0 then begin
    Base:=0;
    if Box<>nil then begin
      Above:=Box.Baseline; if Vertical then Above:=LastBoxBaseline(Box);
      case Metric of '\width':Base:=Box.W; '\height':Base:=Above;
        '\depth':Base:=Box.H-Above; else Base:=Box.H; end;
    end;
    Code:=StringReplace(Code,Metric,'\textwidth',[rfReplaceAll]);
    Result:=DraftDimension(Code,MeasureEm(Size),Base,Default,Points);
    if Negative then Result:=-Result; Exit;
  end;
  Result:=DraftDimension(Code,MeasureEm(Size),LineWidth,Default,Points);
  if Negative then Result:=-Result;
end;
procedure TParagraphDraft.PositionParagraphBox(Box,Body:TDraftBox; Size:Integer; const Position,Inner,HeightSpec:string);
var Above,Depth,Target:Integer; Align:string;
begin
  { ltboxes: pack the vertical list before choosing vtop, vbox or vcenter.
    A trailing vss removes the depth; a leading vss makes vtop's height zero. }
  Above:=LastBoxBaseline(Body); Depth:=Max(0,Body.H-Above); Body.Y:=0;
  Box.W:=Body.W; Box.H:=Body.H; Align:=Inner;
  if HeightSpec<>'' then begin
    if Align='' then Align:=Position;
    Target:=Max(0,BoxDimension(HeightSpec,Body,Size,Body.W,Above,True));
    if (Align='b') or (Align='r') then Body.Y:=Target-Above
    else if (Align<>'t') and (Align<>'l') and (Align<>'s') then Body.Y:=(Target-Body.H) div 2;
    if (Align<>'b') and (Align<>'r') and (Align<>'s') then Depth:=0;
    Above:=Target; Box.H:=Above+Depth;
  end;
  if Position='b' then Box.Baseline:=Above
  else if Position='t' then begin
    Box.Baseline:=Body.Baseline;
    if (HeightSpec<>'') and (Align<>'t') and (Align<>'l') and (Align<>'s') then Box.Baseline:=0;
  end else Box.Baseline:=(Box.H+1) div 2+Round(MeasureEm(Size)*0.25);
end;
function DraftArrayStretch(const Source:string):Double;
var Format:TFormatSettings;
begin
  Format:=DefaultFormatSettings; Format.DecimalSeparator:='.';
  Result:=Max(0.1,StrToFloatDef(DraftSetting(Source,'arraystretch','1'),1,Format));
end;
function TParagraphDraft.TableBox(Node:TMathNode; Size:Integer):TDraftBox;
var Model:TTeXTable; D:TParagraphDraft; Row,Cell:TMathNode; CellBox,CellFrame:TDraftBox;
    I,J,K,N,Pad,X,Y,TargetWidth,Rule,Top,Bottom,Extra,RuleWidth,RuleGap,StrutAbove,StrutBelow,BoundaryStyle,BoundaryWidth,OrderIndex,LeftPad,RightPad,OwnerRow,OwnerCol,SpanWidth,SpanHeight,Pass,FlexCount,FlexWidth,TotalWidth:Integer;
    Widths,Heights,Above,RowSkips,RowTops,BoundaryPads:array of Integer; Cells:TObjectList; Em,Points,BaseSkip,Stretch:Double; Settings,Skip:string;
    Order:TTableRowOrder; Caption:Boolean; Span:TTableSpan; Alignment,Material,OddColor,EvenColor,ColorName,ColorModel,Command:string; ReplacePadding:Boolean;
    ColorPosition,StripeStart:Integer; Background:TColor;
  function ColorDirective(const Source,Name:string; out Color:TColor):Boolean;
  var P,Q:Integer; Cmd,Model,Value:string;
  begin
    Result:=False; P:=1;
    while P<=Length(Source) do begin
      if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
      if Source[P]<>'\' then begin Inc(P); Continue; end;
      Q:=P; if ReadTeXDefinition(Source,Q) then begin P:=Q; Continue; end;
      Cmd:=ReadTeXCommand(Source,P); if Cmd<>Name then Continue;
      Model:=ReadTeXGroup(Source,P,'[',']'); Value:=ReadTeXGroup(Source,P,'{','}');
      Color:=DocumentColor(Value,Model,Settings); Result:=True;
    end;
  end;
  procedure Line(X1,Y1,X2,Y2,Count:Integer; Stroke:Integer=0);
  var L:Integer;
  begin
    for L:=1 to Count do begin
      N:=Length(Result.Lines); SetLength(Result.Lines,N+1);
      Result.Lines[N].A:=Point(X1,Y1); Result.Lines[N].B:=Point(X2,Y2);
      Result.Lines[N].Width:=Stroke;
      if X1=X2 then begin Inc(X1,RuleGap); Inc(X2,RuleGap); end else begin Inc(Y1,RuleGap); Inc(Y2,RuleGap); end;
    end;
  end;
begin
  Result:=TDraftBox.Create; Result.Shape:=9; Result.ID:=Node.ID; Result.Size:=Size;
  Model:=TTeXTable.Create; Cells:=TObjectList.Create(True); D:=TParagraphDraft.Create;
  try
    InheritDraft(D);
    if not Model.Load(Node.TeX) then Exit;
    Em:=MeasureEm(Size); Points:=MeasureEm(FMathBaseSize)/MathFontPoints(0);
    Settings:=HeadingContext+Copy(FSource,1,MathSourceOffset(Node)-Length(Node.Prefix));
    Result.Color:=FDefaultColor; ColorDirective(Settings,'arrayrulecolor',Result.Color);
    StripeStart:=MaxInt; OddColor:=''; EvenColor:=''; ColorPosition:=1;
    while ColorPosition<=Length(Settings) do begin
      if Settings[ColorPosition]='%' then begin while (ColorPosition<=Length(Settings)) and (Settings[ColorPosition]<>#10) do Inc(ColorPosition); Continue; end;
      if Settings[ColorPosition]<>'\' then begin Inc(ColorPosition); Continue; end;
      K:=ColorPosition; if ReadTeXDefinition(Settings,K) then begin ColorPosition:=K; Continue; end;
      Command:=ReadTeXCommand(Settings,ColorPosition);
      if Command='rowcolors' then begin
        ReadTeXGroup(Settings,ColorPosition,'[',']'); StripeStart:=StrToIntDef(ReadTeXGroup(Settings,ColorPosition,'{','}'),1);
        OddColor:=ReadTeXGroup(Settings,ColorPosition,'{','}'); EvenColor:=ReadTeXGroup(Settings,ColorPosition,'{','}');
      end;
    end;
    Pad:=DraftDimension(DraftSetting(Settings,'tabcolsep','6pt'),Em,FMathWidth,Round(6*Points),Points);
    RuleWidth:=DraftDimension(DraftSetting(Settings,'arrayrulewidth','0.4pt'),Em,FMathWidth,Max(1,Round(0.4*Points)),Points);
    RuleGap:=DraftDimension(DraftSetting(Settings,'doublerulesep','2pt'),Em,FMathWidth,Round(2*Points),Points);
    Result.AccentHeight:=RuleWidth;
    BaseSkip:=FTextStyle.Baseline*FTextStyle.Spread*Points;
    Stretch:=DraftArrayStretch(Settings);
    Extra:=DraftDimension(DraftSetting(Settings,'extrarowheight','0pt'),Em,FMathWidth,0,Points);
    StrutAbove:=Round((BaseSkip*0.7+Extra)*Stretch); StrutBelow:=Round(BaseSkip*0.3*Stretch);
    SetLength(BoundaryPads,Model.Columns.Count+1);
    for J:=0 to Model.Columns.Count do begin
      Material:=Model.BoundaryMaterial(J,ReplacePadding);
      BoundaryPads[J]:=Pad; if ReplacePadding then BoundaryPads[J]:=0;
      { Dimension-only intercolumn material supplies its own gap. }
      if Material<>'' then BoundaryPads[J]:=BoundaryPads[J]+Max(0,DraftDimension(Material,Em,FMathWidth,0,Points)) div 2;
    end;
    SetLength(Widths,Model.Columns.Count); SetLength(Heights,Node.Children.Count); SetLength(Above,Node.Children.Count);
    SetLength(RowSkips,Node.Children.Count); SetLength(RowTops,Node.Children.Count);
    FlexCount:=0; FlexWidth:=0;
    if Model.Environment='tabularx' then for J:=0 to Model.Columns.Count-1 do
      if Model.ColumnAlignment(J)='X' then Inc(FlexCount);
    TotalWidth:=DraftDimension(Model.WidthSpec,Em,FMathWidth,FMathWidth,Points);
    for Pass:=0 to Ord(FlexCount>0) do begin
    if Pass>0 then begin
      FlexWidth:=TotalWidth;
      for J:=0 to High(Widths) do if Model.ColumnAlignment(J)='X' then begin
        Dec(FlexWidth,BoundaryPads[J]+BoundaryPads[J+1]); Widths[J]:=0;
      end else Dec(FlexWidth,Widths[J]);
      FlexWidth:=Max(1,FlexWidth div FlexCount); Cells.Clear;
      for I:=0 to High(Heights) do begin Heights[I]:=0; Above[I]:=0; end;
    end;
    for I:=0 to Node.Children.Count-1 do begin
      Row:=TMathNode(Node.Children[I]);
      Caption:=TTableRow(Model.Rows[I]).Caption;
      K:=3; Skip:=ReadTeXGroup(TTableRow(Model.Rows[I]).Ending,K,'[',']');
      if Copy(Trim(Skip),1,1)='-' then RowSkips[I]:=-DraftDimension(Copy(Trim(Skip),2,MaxInt),Em,FMathWidth,0,Points)
      else RowSkips[I]:=DraftDimension(Skip,Em,FMathWidth,0,Points);
      for J:=0 to Model.Columns.Count-1 do begin
        OwnerRow:=I; OwnerCol:=J;
        if Model.CellOwner(OwnerRow,OwnerCol) then begin Cells.Add(TDraftBox.Create); Continue; end;
        Span:=Model.CellSpan(I,J); Alignment:=Model.ColumnAlignment(J,I);
        LeftPad:=BoundaryPads[J]; RightPad:=BoundaryPads[Min(High(BoundaryPads),J+Span.Columns)];
        D.TextStyleSeed:=FTextStyle;
        ApplyTextStyle(D.TextStyleSeed,Model.ColumnBefore(J,I),Directory);
        if J<Row.Children.Count then Cell:=TMathNode(Row.Children[J]) else Cell:=nil;
        { l/c/r cells have their natural width; only p/m/b columns wrap. }
        TargetWidth:=100000;
        if (Alignment='X') and (Pass>0) then TargetWidth:=FlexWidth;
        if Caption then TargetWidth:=FMathWidth;
        if Alignment[1] in ['p','m','b'] then begin
          K:=2; TargetWidth:=DraftDimension(ReadTeXGroup(Alignment,K,'{','}'),Em,FMathWidth,TargetWidth,MeasureEm(FMathBaseSize)/MathFontPoints(0));
        end;
        if (Span.Width<>'') and (Span.Width<>'*') and (Span.Width<>'=') then
          TargetWidth:=DraftDimension(Span.Width,Em,FMathWidth,TargetWidth,Points);
        D.TableCellLayout:=not Caption;
        if Cell<>nil then begin
          D.Layout(FCanvas,Cell,TargetWidth+20,True,FMathBaseSize,FLayout,FSource,FScale,MeasureEm(FMathBaseSize));
          CellBox:=D.FRoot; D.FRoot:=nil; CellBox.ID:=Cell.ID;
          CellBox.W:=0; Top:=MaxInt; Bottom:=0; CellBox.Baseline:=0;
          for K:=0 to CellBox.Children.Count-1 do begin
            with TDraftBox(CellBox.Children[K]) do begin
              Dec(X,10); Dec(Y,10); CellBox.W:=Max(CellBox.W,X+W);
              if (Trim(Text)<>'') or (Shape<>0) or (Children.Count>0) then begin
                if Top=MaxInt then CellBox.Baseline:=Y+Baseline;
                Top:=Min(Top,Y+D.InkTop(TDraftBox(CellBox.Children[K])));
                Bottom:=Max(Bottom,Y+D.InkBottom(TDraftBox(CellBox.Children[K])));
              end;
            end;
          end;
          if Top=MaxInt then begin Top:=0; Bottom:=StrutAbove+StrutBelow; CellBox.W:=16; CellBox.Baseline:=StrutAbove; end;
          for K:=0 to CellBox.Children.Count-1 do Dec(TDraftBox(CellBox.Children[K]).Y,Top);
          Dec(CellBox.Baseline,Top); CellBox.H:=Bottom-Top;
        end else begin CellBox:=TDraftBox.Create; CellBox.W:=16; CellBox.H:=StrutAbove+StrutBelow; CellBox.Baseline:=StrutAbove; end;
        if (Alignment[1] in ['p','m','b']) or ((Alignment='X') and (Pass>0)) then CellBox.W:=Max(CellBox.W,TargetWidth);
        if (Cell<>nil) and (Trim(Copy(Cell.TeX,1,Length(Cell.TeX)-Length(Cell.Suffix)))='') and
          (CellBox.Children.Count>0) then begin
          TDraftBox(CellBox.Children[0]).Shape:=3; TDraftBox(CellBox.Children[0]).W:=16;
        end;
        Cells.Add(CellBox);
        if not Caption and not Row.Hidden and (Span.Columns=1) then Widths[J]:=Max(Widths[J],CellBox.W+LeftPad+RightPad);
        if Abs(Span.Rows)>1 then begin
          Heights[I]:=Max(Heights[I],StrutBelow); Above[I]:=Max(Above[I],StrutAbove); Continue;
        end;
        Heights[I]:=Max(Heights[I],Max(StrutBelow,CellBox.H-CellBox.Baseline));
        Above[I]:=Max(Above[I],Max(StrutAbove,CellBox.Baseline));
      end;
      { Positive \\[skip] extends the strut depth, rather than adding space
        below a cell whose contents already extend farther down. }
      Heights[I]:=Max(Heights[I],StrutBelow+Max(0,RowSkips[I]));
    end;
    end;
    for I:=0 to Model.Rows.Count-1 do for J:=0 to Model.Columns.Count-1 do begin
      Span:=Model.CellSpan(I,J); if Span.Columns<=1 then Continue;
      SpanWidth:=0; for K:=J to Min(High(Widths),J+Span.Columns-1) do Inc(SpanWidth,Widths[K]);
      K:=Min(High(Widths),J+Span.Columns-1);
      Inc(Widths[K],Max(0,TDraftBox(Cells[I*Model.Columns.Count+J]).W+BoundaryPads[J]+BoundaryPads[K+1]-SpanWidth));
    end;
    Result.W:=0; for J:=0 to High(Widths) do Inc(Result.W,Widths[J]); Y:=0;
    Order:=Model.VisualRows; Cells.OwnsObjects:=False;
    for OrderIndex:=0 to Length(Order) do begin
      if OrderIndex<Length(Order) then I:=Order[OrderIndex]
      else if Length(Order)>0 then I:=Order[High(Order)]+1 else I:=Node.Children.Count;
      Caption:=(I<Model.Rows.Count) and TTableRow(Model.Rows[I]).Caption;
      if (I<Length(Model.RowGaps)) and (Model.RowGaps[I]<>'') then Inc(Y,DraftDimension(Model.RowGaps[I],Em,FMathWidth,0,Points));
      BoundaryStyle:=Model.HorizontalStyle(I); BoundaryWidth:=RuleWidth;
      if BoundaryStyle>=3 then begin
        case BoundaryStyle of
          3,5:BoundaryWidth:=DraftDimension(DraftSetting(Settings,'heavyrulewidth','0.08em'),Em,FMathWidth,Max(1,Round(0.08*Em)),Points);
          6:BoundaryWidth:=DraftDimension(DraftSetting(Settings,'cmidrulewidth','0.03em'),Em,FMathWidth,Max(1,Round(0.03*Em)),Points);
          else BoundaryWidth:=DraftDimension(DraftSetting(Settings,'lightrulewidth','0.05em'),Em,FMathWidth,Max(1,Round(0.05*Em)),Points);
        end;
        if (I<Length(Model.HorizontalWidths)) and (Model.HorizontalWidths[I]<>'') then
          BoundaryWidth:=DraftDimension(Model.HorizontalWidths[I],Em,FMathWidth,BoundaryWidth,Points);
        if (I<Length(Model.RuleAbove)) and (Model.RuleAbove[I]<>'') then Inc(Y,DraftDimension(Model.RuleAbove[I],Em,FMathWidth,0,Points))
        else if I>0 then Inc(Y,DraftDimension(DraftSetting(Settings,'aboverulesep','0.4ex'),Em,FMathWidth,Round(0.4*0.430556*Em),Points));
      end;
      Rule:=0; X:=0;
      for J:=0 to High(Widths) do begin
        K:=Model.HorizontalLine(I,J); Line(X,Y,X+Widths[J],Y,K,BoundaryWidth); Rule:=Max(Rule,K); Inc(X,Widths[J]);
      end;
      if Rule>0 then Inc(Y,BoundaryWidth+Max(0,Rule-1)*RuleGap);
      if (I<Length(Model.RuleBelow)) and (Model.RuleBelow[I]<>'') then Inc(Y,DraftDimension(Model.RuleBelow[I],Em,FMathWidth,0,Points))
      else if BoundaryStyle>=3 then Inc(Y,DraftDimension(DraftSetting(Settings,'belowrulesep','0.65ex'),Em,FMathWidth,Round(0.65*0.430556*Em),Points));
      if OrderIndex=Length(Order) then Break;
      X:=0; RowTops[I]:=Y;
      for J:=0 to High(Widths) do begin
        if Caption and (J>0) then Continue;
        OwnerRow:=I; OwnerCol:=J;
        if Model.CellOwner(OwnerRow,OwnerCol) then begin Inc(X,Widths[J]); Continue; end;
        Span:=Model.CellSpan(I,J); Alignment:=Model.ColumnAlignment(J,I);
        SpanWidth:=0; for K:=J to Min(High(Widths),J+Span.Columns-1) do Inc(SpanWidth,Widths[K]);
        CellBox:=TDraftBox(Cells[I*Model.Columns.Count+J]); Cells[I*Model.Columns.Count+J]:=nil;
        LeftPad:=BoundaryPads[J]; RightPad:=BoundaryPads[Min(High(BoundaryPads),J+Span.Columns)];
        CellBox.X:=LeftPad; CellBox.Y:=Above[I]-CellBox.Baseline;
        if Copy(Alignment,1,1)='c' then Inc(CellBox.X,(SpanWidth-LeftPad-RightPad-CellBox.W) div 2)
        else if Copy(Alignment,1,1)='r' then Inc(CellBox.X,SpanWidth-LeftPad-RightPad-CellBox.W);
        CellFrame:=TDraftBox.Create; CellFrame.ID:=CellBox.ID; CellBox.ID:=-1;
        CellFrame.X:=X; CellFrame.Y:=Y; CellFrame.W:=SpanWidth; CellFrame.H:=Above[I]+Heights[I]; CellFrame.Baseline:=Above[I];
        Background:=clNone; ColorDirective(Model.ColumnBefore(J,I),'columncolor',Background);
        ColorName:=TTableRow(Model.Rows[I]).Color; ColorModel:=TTableRow(Model.Rows[I]).ColorModel;
        if (ColorName='') and (I+1>=StripeStart) then begin
          if Odd(I+1) then ColorName:=OddColor else ColorName:=EvenColor; ColorModel:='';
        end;
        if ColorName<>'' then Background:=DocumentColor(ColorName,ColorModel,Settings);
        ColorDirective(Model.CellContent(I,J),'cellcolor',Background);
        if Background<>clNone then begin CellFrame.Shape:=9; CellFrame.FillColor:=Background; end;
        CellFrame.Row:=I; CellFrame.Col:=J; CellFrame.Children.Add(CellBox); Result.Children.Add(CellFrame); Inc(X,Widths[J]);
        if Caption then begin
          CellFrame.W:=Result.W; CellBox.X:=(Result.W-FMathWidth) div 2;
        end;
      end;
      Extra:=Min(0,RowSkips[I]);
      X:=0;
      for J:=0 to High(Widths)+1 do if not Caption then begin
        Line(X,Y,X,Y+Above[I]+Heights[I]+Extra,Model.VerticalLine(I,J));
        if J<Length(Widths) then Inc(X,Widths[J]);
      end;
      Inc(Y,Above[I]+Heights[I]+Extra);
    end;
    for I:=0 to Result.Children.Count-1 do begin
      CellFrame:=TDraftBox(Result.Children[I]); Span:=Model.CellSpan(CellFrame.Row,CellFrame.Col);
      if Abs(Span.Rows)<=1 then Continue;
      Top:=CellFrame.Row; Bottom:=Top+Span.Rows-1;
      if Span.Rows<0 then begin Bottom:=Top; Inc(Top,Span.Rows+1); end;
      Top:=Max(0,Top); Bottom:=Min(High(Heights),Bottom);
      SpanHeight:=RowTops[Bottom]+Above[Bottom]+Heights[Bottom]-RowTops[Top];
      CellFrame.Y:=RowTops[Top]; CellFrame.H:=SpanHeight; CellBox:=TDraftBox(CellFrame.Children[0]);
      CellBox.Y:=(SpanHeight-CellBox.H) div 2;
      if Span.Vertical='t' then CellBox.Y:=Above[Top]-CellBox.Baseline
      else if Span.Vertical='b' then CellBox.Y:=SpanHeight-Heights[Bottom]-(CellBox.H-CellBox.Baseline);
      Dec(CellBox.Y,DraftDimension(Span.Offset,Em,FMathWidth,0,Points));
    end;
    Result.H:=Y; Result.Baseline:=Y div 2+Round(Em*0.25); X:=0;

  finally D.Free; Cells.OwnsObjects:=True; Cells.Free; Model.Free; end;
end;
procedure BoundFigureRaster(Picture:TPicture; Width,Height:Integer);
var Source,Target:TLazIntfImage; PNG:TPortableNetworkGraphic; Scale,FX,FY,TX,TY:Double;
    W,H,X,Y,X0,X1,Y0,Y1:Integer; C00,C10,C01,C11,C:TFPColor;
  function Blend(A,B,C,D:Word):Word;
  begin Result:=Round((A*(1-TX)+B*TX)*(1-TY)+(C*(1-TX)+D*TX)*TY); end;
begin
  if not (Picture.Graphic is TRasterImage) or (Picture.Width<=0) or (Picture.Height<=0) then Exit;
  Scale:=Min(1,Max(Max(128,Width*2)/Picture.Width,Max(128,Height*2)/Picture.Height));
  Scale:=Min(Scale,Sqrt(1000000/(Double(Picture.Width)*Picture.Height)));
  if Scale>=0.99 then Exit;
  W:=Max(1,Round(Picture.Width*Scale)); H:=Max(1,Round(Picture.Height*Scale));
  Source:=TRasterImage(Picture.Graphic).CreateIntfImage; Target:=TLazIntfImage.Create(0,0); PNG:=TPortableNetworkGraphic.Create;
  try
    Target.DataDescription:=Source.DataDescription; Target.SetSize(W,H);
    for Y:=0 to H-1 do begin
      FY:=Max(0,(Y+0.5)*Source.Height/H-0.5); Y0:=Min(Source.Height-1,Floor(FY)); Y1:=Min(Source.Height-1,Y0+1); TY:=FY-Y0;
      for X:=0 to W-1 do begin
        FX:=Max(0,(X+0.5)*Source.Width/W-0.5); X0:=Min(Source.Width-1,Floor(FX)); X1:=Min(Source.Width-1,X0+1); TX:=FX-X0;
        C00:=Source.Colors[X0,Y0]; C10:=Source.Colors[X1,Y0]; C01:=Source.Colors[X0,Y1]; C11:=Source.Colors[X1,Y1];
        C.Red:=Blend(C00.Red,C10.Red,C01.Red,C11.Red); C.Green:=Blend(C00.Green,C10.Green,C01.Green,C11.Green);
        C.Blue:=Blend(C00.Blue,C10.Blue,C01.Blue,C11.Blue); C.Alpha:=Blend(C00.Alpha,C10.Alpha,C01.Alpha,C11.Alpha); Target.Colors[X,Y]:=C;
      end;
    end;
    PNG.LoadFromIntfImage(Target); Picture.Assign(PNG);
  finally PNG.Free; Target.Free; Source.Free; end;
end;
function TParagraphDraft.PDFPagesBox(Node:TMathNode; Size:Integer):TDraftBox;
var P,I,J,K,Count,TargetW,TargetH:Integer; FileName,Path,Code,Command,Key:string;
    Values:TStringList; Entry:TDiagramOption; Doc:IVectorDocument;
    Pages:TPDFPageNumbers; Page,Frame:TDraftBox; Image:TDraftImage;
    PW,PH,PaperW,PaperH,Ratio,Scale:Double; Format:TFormatSettings;
  procedure Settings(const Code:string);
  var Entry:TDiagramOption;
  begin
    for Entry in DiagramOptions(Code) do
      if Entry.HasValue then Values.Values[Entry.Name]:=Entry.Value else Values.Values[Entry.Name]:='true';
  end;
begin
  Result:=TDraftBox.Create; Result.ID:=Node.ID; Result.W:=FMathWidth;
  Result.CharCount:=UTF8Length(Node.Text); Values:=TStringList.Create;
  try
    P:=1;
    while P<=Length(HeadingContext) do begin
      if HeadingContext[P]='%' then begin while (P<=Length(HeadingContext)) and (HeadingContext[P]<>#10) do Inc(P); Continue; end;
      if HeadingContext[P]<>'\' then begin Inc(P); Continue; end;
      I:=P; if ReadTeXDefinition(HeadingContext,I) then begin P:=I; Continue; end;
      Command:=ReadTeXCommand(HeadingContext,P);
      if Command='includepdfset' then Settings(ReadTeXGroup(HeadingContext,P,'{','}'));
    end;
    P:=1; ReadTeXCommand(Node.Text,P); Settings(ReadTeXGroup(Node.Text,P,'[',']'));
    FileName:=ReadTeXGroup(Node.Text,P,'{','}'); Path:=ExpandFileName(IncludeTrailingPathDelimiter(Directory)+FileName);
    if (Copy(FileName,1,1)='/') or (Copy(FileName,1,1)='\') or (Copy(FileName,2,1)=':') then Path:=ExpandFileName(FileName);
    if ExtractFileExt(Path)='' then begin Path:=Path+'.pdf'; FileName:=FileName+'.pdf'; end;
    if not FileExists(Path) then begin Code:=FindTeXFile(FileName); if Code<>'' then Path:=Code; end;
    Key:='PDFPages|'+Path+'|'+IntToStr(FileAge(Path))+'|';
    if FImages=nil then FImages:=TStringList.Create; Doc:=nil;
    for I:=0 to FImages.Count-1 do if Pos(Key,FImages[I])=1 then begin
      Image:=TDraftImage(FImages.Objects[I]); Doc:=Image.Surface.VectorDocument; Break;
    end;
    if Doc=nil then Doc:=OpenVectorDocument(Path);
    if Doc=nil then begin
      Page:=Leaf('PDF: '+FileName,Node.ID,Size,0); Page.Shape:=12; Result.Children.Add(Page);
      Result.H:=Page.H; Result.Baseline:=Page.Baseline; Exit;
    end;
    Count:=Min(4096,VectorPageCount(Doc));
    Pages:=PDFPageNumbers(Values.Values['pages'],Count);
    DocumentPaperSize(HeadingContext,PaperW,PaperH);
    if Values.Values['landscape']='true' then begin Ratio:=PaperW; PaperW:=PaperH; PaperH:=Ratio; end;
    Format:=DefaultFormatSettings; Format.DecimalSeparator:='.'; Scale:=StrToFloatDef(Values.Values['scale'],1,Format);
    Scale:=EnsureRange(Scale,0.001,100);
    for I:=0 to High(Pages) do begin
      PW:=PaperW*72/72.27; PH:=PaperH*72/72.27;
      if Pages[I]>0 then Doc.PageSize(Pages[I],PW,PH);
      TargetW:=FMathWidth; TargetH:=Max(1,Round(TargetW*PaperH/PaperW));
      if Values.Values['fitpaper']='true' then TargetH:=Max(1,Round(TargetW*PH/PW));
      Frame:=TDraftBox.Create; Frame.W:=TargetW; Frame.H:=TargetH; Frame.Y:=Result.H;
      Frame.ID:=Node.ID; Frame.CharCount:=UTF8Length(Node.Text);
      Frame.Shape:=9; Frame.Color:=clGray; SetLength(Frame.Lines,4);
      Frame.Lines[0].A:=Point(0,0); Frame.Lines[0].B:=Point(TargetW,0);
      Frame.Lines[1].A:=Point(TargetW,0); Frame.Lines[1].B:=Point(TargetW,TargetH);
      Frame.Lines[2].A:=Point(TargetW,TargetH); Frame.Lines[2].B:=Point(0,TargetH);
      Frame.Lines[3].A:=Point(0,TargetH); Frame.Lines[3].B:=Point(0,0);
      if HideEditingMarks then Frame.Lines:=nil;
      if Pages[I]>0 then begin
        Page:=TDraftBox.Create; Page.Shape:=10; Page.Text:=FileName; Page.FontName:=FDefaultFont;
        Page.ID:=Node.ID; Page.CharCount:=UTF8Length(Node.Text);
        Ratio:=Min(TargetW/Max(1,PW),TargetH/Max(1,PH));
        if Values.Values['noautoscale']='true' then Ratio:=MeasureEm(FMathBaseSize)/MathFontPoints(0)*72.27/72;
        Page.W:=Max(1,Round(PW*Ratio*Scale)); Page.H:=Max(1,Round(PH*Ratio*Scale));
        Page.X:=(TargetW-Page.W) div 2; Page.Y:=(TargetH-Page.H) div 2;
        Code:=Key+IntToStr(Pages[I]); J:=FImages.IndexOf(Code); Image:=nil;
        if J>=0 then Image:=TDraftImage(FImages.Objects[J]);
        if Image<>nil then Image.Retain else begin
          Image:=TDraftImage.Create; Image.Surface.SetVector(Doc,Pages[I]);
          { Replaced files/pages must not leave all four cache slots pinned
            to unused documents. Detached boxes retain their own reference. }
          if FImages.Count>=4 then for K:=FImages.Count-1 downto 0 do
            if TDraftImage(FImages.Objects[K]).References=1 then begin
              TDraftImage(FImages.Objects[K]).Release; FImages.Delete(K); if FImages.Count<4 then Break;
            end;
          if FImages.Count<4 then begin Image.Retain; FImages.AddObject(Code,Image); end;
        end;
        Page.Image:=Image; Page.Picture:=Image.Picture; Page.Surface:=Image.Surface;
        Page.Surface.SetSourceGraphics(Node.Text); Frame.Children.Add(Page);
      end;
      Result.Children.Add(Frame); Inc(Result.H,Frame.H);
      if I<High(Pages) then Inc(Result.H,Max(1,Round(6*FMathWidth/DocumentTextWidth(HeadingContext))));
    end;
    Result.Baseline:=Result.H;
  finally Values.Free; end;
end;
function TParagraphDraft.FigureBox(Node:TMathNode; Size:Integer):TDraftBox;
var P,I:Integer; Options,FileName,Path,S,Key:string; Values:TStringList; W,H:Integer; Doc:IVectorDocument; PW,PH:Double; Image:TDraftImage;
begin
  Result:=TDraftBox.Create; Result.Shape:=10; Result.ID:=Node.ID; Result.Size:=Size;
  P:=1; ReadTeXCommand(Node.Text,P); if (P<=Length(Node.Text)) and (Node.Text[P]='*') then Inc(P);
  SkipTeXSpace(Node.Text,P); Options:=ReadTeXGroup(Node.Text,P,'[',']'); FileName:=ReadTeXGroup(Node.Text,P,'{','}');
  Path:=FileName;
  if (Copy(FileName,1,1)<>'/') and (Copy(FileName,1,1)<>'\') and (Copy(FileName,2,1)<>':') then
    Path:=IncludeTrailingPathDelimiter(Directory)+FileName;
  Path:=ExpandFileName(Path);
  if ExtractFileExt(Path)='' then for S in TStringArray.Create('.pdf','.png','.jpg','.jpeg','.bmp') do if FileExists(Path+S) then begin Path:=Path+S; Break; end;
  Key:=Path+'|'+IntToStr(FileAge(Path))+'|'+Node.Text+'|'+IntToStr(FMathWidth)+'|'+FloatToStr(MeasureEm(Size));
  if FImages=nil then FImages:=TStringList.Create;
  I:=FImages.IndexOf(Key); Image:=nil; if I>=0 then Image:=TDraftImage(FImages.Objects[I]);
  if Image<>nil then begin
    Image.Retain; Result.Image:=Image; Result.Picture:=Image.Picture; Result.Surface:=Image.Surface;
    W:=Image.Width; H:=Image.Height;
  end else begin
  Image:=TDraftImage.Create; Result.Image:=Image; Result.Picture:=Image.Picture; Result.Surface:=Image.Surface;
  W:=Min(FMathWidth,Round(MeasureEm(Size)*12)); H:=W*2 div 3;
  try
    if LowerCase(ExtractFileExt(Path))='.pdf' then begin
      Doc:=OpenVectorDocument(Path); if Doc<>nil then begin
        if Doc.PageSize(1,PW,PH) then H:=Round(W*PH/PW);
        { PDF drawing uses the bounded vector cache. Keep only dimensions
          during layout; an eager fallback raster was never painted. }
        Result.Surface.SetVector(Doc,1);
      end;
    end else if FileExists(Path) then Result.Picture.LoadFromFile(Path);
  except Result.Picture.Clear; end;
  if (Result.Picture.Width>0) and (Result.Picture.Height>0) then begin
    W:=Min(FMathWidth,Result.Picture.Width); H:=Round(W*Result.Picture.Height/Result.Picture.Width);
  end;
  Values:=TStringList.Create;
  try
    Values.Delimiter:=','; Values.StrictDelimiter:=True; Values.DelimitedText:=Options;
    if Values.Values['width']<>'' then begin
      I:=DraftDimension(Values.Values['width'],MeasureEm(Size),FMathWidth,W,MeasureEm(FMathBaseSize)/MathFontPoints(0)); H:=Round(H*I/Max(1,W)); W:=I;
    end;
    if Values.Values['height']<>'' then begin
      I:=DraftDimension(Values.Values['height'],MeasureEm(Size),FMathWidth,H,MeasureEm(FMathBaseSize)/MathFontPoints(0));
      if Values.Values['width']='' then W:=Round(W*I/Max(1,H)); H:=I;
    end;
  finally Values.Free; end;
  if Result.Surface.VectorDocument=nil then BoundFigureRaster(Result.Picture,W,H);
  Image.Width:=W; Image.Height:=H;
  { Reuse unchanged image files while typing in their captions. Four entries
    bound cache retention; boxes retain assets independently during a layout. }
  if FImages.Count>=4 then for I:=FImages.Count-1 downto 0 do
    if TDraftImage(FImages.Objects[I]).References=1 then begin TDraftImage(FImages.Objects[I]).Release; FImages.Delete(I); if FImages.Count<4 then Break; end;
  if FImages.Count<4 then begin Image.Retain; FImages.AddObject(Key,Image); end;
  end;
  Result.W:=W; Result.H:=H; Result.Baseline:=H; Result.Text:=FileName; Result.FontName:=FDefaultFont;
  Result.CharCount:=UTF8Length(Node.Text); SetLength(Result.Stops,Result.CharCount+1);
  for I:=1 to Result.CharCount do Result.Stops[I]:=W;
end;
