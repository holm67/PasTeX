{ SPDX-License-Identifier: GPL-3.0-or-later }
  procedure PlaceNode(Node:TPrimitive);
  const Directions:array[0..7] of string=('right','left','above','below','above right','above left','below right','below left');
  var Direction,Value,Reference,Distance:string; I,K,P:Integer; Other:TPrimitive; DX,DY,Gap,MinX,MinY,MaxX,MaxY:Double; Center:TDiagramPoint;
  begin
    for Direction in Directions do begin
      Value:=PlainLabel(NodeStyle.Values[Direction]); K:=Pos('of ',Value); if K=0 then Continue;
      Reference:=Trim(Copy(Value,K+3,MaxInt)); I:=Nodes.IndexOf(Reference); if I<0 then Continue; Other:=TPrimitive(Nodes.Objects[I]);
      Distance:=GlobalStyle.Values['node distance']; P:=Pos(' and ',Distance);
      if P>0 then if (Direction='right') or (Direction='left') then Distance:=Copy(Distance,P+5,MaxInt) else Distance:=Copy(Distance,1,P-1);
      Gap:=LengthPoints(Distance,10*72/72.27,DocumentTextWidth(Context));
      Gap:=LengthPoints(Trim(Copy(Value,1,K-1)),Gap,DocumentTextWidth(Context)); DX:=0; DY:=0;
      if Pos('right',Direction)>0 then DX:=Other.NodeHalfW+Node.LabelW/2+Gap;
      if Pos('left',Direction)>0 then DX:=-Other.NodeHalfW-Node.LabelW/2-Gap;
      if Pos('above',Direction)>0 then DY:=Other.NodeHalfH+Node.LabelH/2+Gap;
      if Pos('below',Direction)>0 then DY:=-Other.NodeHalfH-Node.LabelH/2-Gap;
      Node.NodeCenter:=PointAt(Other.NodeCenter.X+DX,Other.NodeCenter.Y+DY); Node.Points[0]:=Node.NodeCenter;
      Node.AnchorX:=0.5; Node.AnchorY:=0.5; Break;
    end;
    Value:=PlainLabel(NodeStyle.Values['fit']); if Value='' then Exit;
    MinX:=MaxDouble; MinY:=MaxDouble; MaxX:=-MaxDouble; MaxY:=-MaxDouble; P:=1;
    while P<=Length(Value) do begin
      SkipTeXSpace(Value,P); Reference:=ReadTeXGroup(Value,P,'(',')'); if Reference='' then Break;
      I:=Nodes.IndexOf(Reference); if I<0 then Continue; Other:=TPrimitive(Nodes.Objects[I]);
      MinX:=Min(MinX,Other.NodeCenter.X-Other.NodeHalfW); MaxX:=Max(MaxX,Other.NodeCenter.X+Other.NodeHalfW);
      MinY:=Min(MinY,Other.NodeCenter.Y-Other.NodeHalfH); MaxY:=Max(MaxY,Other.NodeCenter.Y+Other.NodeHalfH);
    end;
    if MinX=MaxDouble then Exit; Gap:=LengthPoints(NodeStyle.Values['inner sep'],3.33,DocumentTextWidth(Context));
    Node.NodeCenter:=PointAt((MinX+MaxX)/2,(MinY+MaxY)/2); Node.Points[0]:=Node.NodeCenter;
    Node.LabelW:=MaxX-MinX+2*Gap; Node.LabelH:=MaxY-MinY+2*Gap;
  end;
  procedure NodeOutline(Node:TPrimitive);
  var Border:TPrimitive; X,Y,Gap:Double; Center:TDiagramPoint;
  begin
    Gap:=LengthPoints(NodeStyle.Values['inner sep'],Scene.FontPoints/3*72/72.27,DocumentTextWidth(Context));
    X:=Max(0.1,Node.LabelW/2+Gap); Y:=Max(0.1,Node.LabelH/2+Gap);
    X:=Max(X,LengthPoints(NodeStyle.Values['minimum width'],0,DocumentTextWidth(Context))/2);
    Y:=Max(Y,LengthPoints(NodeStyle.Values['minimum height'],0,DocumentTextWidth(Context))/2);
    Node.NodeCircle:=NodeStyle.IndexOfName('circle')>=0;
    if Node.NodeCircle then begin X:=Max(X,Y); Y:=X; end;
    Node.NodeHalfW:=X; Node.NodeHalfH:=Y; Center:=Node.NodeCenter;
    if (NodeStyle.IndexOfName('draw')<0) and (NodeStyle.IndexOfName('fill')<0) then Exit;
    Border:=TPrimitive.Create; ApplyStyle(Border); Border.Closed:=True;
    { Node outlines are stroked shapes; path arrow tips belong to their edges. }
    Border.Arrow:=False; Border.StartArrow:=False;
    if NodeStyle.IndexOfName('draw')<0 then Border.Stroke:=clNone;
    if Node.NodeCircle then begin
      Border.Kind:=1; Point(Border,PointAt(Center.X-X,Center.Y-Y)); Point(Border,PointAt(Center.X+X,Center.Y+Y));
    end else if NodeStyle.IndexOfName('diamond')>=0 then begin
      X:=X*1.42; Y:=Y*1.42; Node.NodeHalfW:=X; Node.NodeHalfH:=Y;
      Point(Border,PointAt(Center.X,Center.Y-Y)); Point(Border,PointAt(Center.X+X,Center.Y)); Point(Border,PointAt(Center.X,Center.Y+Y)); Point(Border,PointAt(Center.X-X,Center.Y));
    end else begin
      Point(Border,PointAt(Center.X-X,Center.Y-Y)); Point(Border,PointAt(Center.X+X,Center.Y-Y));
      Point(Border,PointAt(Center.X+X,Center.Y+Y)); Point(Border,PointAt(Center.X-X,Center.Y+Y));
    end;
    Scene.Items.Insert(Scene.Items.IndexOf(Node),Border);
  end;
  function Graph(const Code:string; Base:Integer):Boolean;
  var Vertices:TTikZGraphNodes; Edges:TTikZGraphEdges; Labels:array of TPrimitive;
      I:Integer; Grow,Branch:TDiagramPoint; Edge:TPrimitive; VertexOptions:TStringList;
    function Shift(const Prefix:string; Default:TDiagramPoint):TDiagramPoint;
    const Directions:array[0..3] of string=('right','left','up','down');
    var Direction,Value:string; Distance:Double;
    begin
      Result:=Default;
      for Direction in Directions do if Style.IndexOfName(Prefix+' '+Direction)>=0 then begin
        Value:=Style.Values[Prefix+' '+Direction]; Distance:=1;
        if Numeric(Value,Distance) then Distance:=Distance*Scale
        else Distance:=LengthPoints(Value,72/2.54,DocumentTextWidth(Context))*Scale/(72/2.54);
        Result:=PointAt(0,0);
        case Direction of
          'right':Result.X:=Distance; 'left':Result.X:=-Distance;
          'up':Result.Y:=Distance; 'down':Result.Y:=-Distance;
        end;
      end;
    end;
  begin
    Result:=ParseTikZGraph(Code,Vertices,Edges); if not Result then Exit;
    SetLength(Labels,Length(Vertices)); Grow:=Shift('grow',PointAt(Scale,0)); Branch:=Shift('branch',PointAt(0,-Scale));
    VertexOptions:=TStringList.Create;
    try
      VertexOptions.Assign(Style);
      for I:=0 to High(Vertices) do begin
        NodeStyle.Clear; ExpandStyle(PlainLabel(GlobalStyle.Values['every node/.style']),NodeStyle);
        ExpandStyle(PlainLabel(VertexOptions.Values['nodes']),NodeStyle); ExpandStyle(Vertices[I].Options,NodeStyle); Style.Assign(NodeStyle);
        LabelAt(Vertices[I].Text,PointAt(Vertices[I].Level*Grow.X+Vertices[I].Row*Branch.X,
          Vertices[I].Level*Grow.Y+Vertices[I].Row*Branch.Y));
        if LabelItem=nil then Exit(False);
        Labels[I]:=LabelItem; LabelItem.Edit.First:=Base+Vertices[I].First; LabelItem.Edit.Last:=Base+Vertices[I].Last;
        if not Vertices[I].HasLabel then begin
          LabelItem.Edit.ReplacementPrefix:=Copy(Code,Vertices[I].First+1,Vertices[I].Last-Vertices[I].First)+'/{';
          LabelItem.Edit.ReplacementSuffix:='}';
        end;
        Nodes.AddObject(Vertices[I].Name,LabelItem); NodeOutline(LabelItem);
      end;
      Style.Clear; ExpandStyle(PlainLabel(VertexOptions.Values['edges']),Style);
      for I:=0 to High(Edges) do begin
        Edge:=TPrimitive.Create; ApplyStyle(Edge); Edge.Arrow:=Edges[I].Arrow and (not Edges[I].Reverse or Edges[I].Both); Edge.StartArrow:=Edges[I].Arrow and Edges[I].Reverse;
        Point(Edge,Labels[Edges[I].A].NodeCenter); Point(Edge,Labels[Edges[I].B].NodeCenter); Scene.Items.Insert(0,Edge);
      end;
    finally VertexOptions.Free; end;
  end;
  function AnglePicture(const Code:string):Boolean;
  var P,K,I:Integer; Value,Name,Text:string; A,B,C:TDiagramPoint; Start,Finish,Radius,Eccentricity,T:Double; Arc:TPrimitive; Entry:TDiagramOption;
  begin
    Result:=False; P:=1; Value:=ReadTeXGroup(Code,P,'{','}');
    if Copy(Value,1,6)<>'angle=' then Exit; Value:=Copy(Value,7,MaxInt); K:=Pos('--',Value); if K=0 then Exit;
    Name:='('+Copy(Value,1,K-1)+')'; P:=1; if not Coordinate(Name,P,B) then Exit;
    Value:=Copy(Value,K+2,MaxInt); K:=Pos('--',Value); if K=0 then Exit;
    Name:='('+Copy(Value,1,K-1)+')'; P:=1; if not Coordinate(Name,P,A) then Exit;
    Name:='('+Copy(Value,K+2,MaxInt)+')'; P:=1; if not Coordinate(Name,P,C) then Exit;
    Start:=ArcTan2(B.Y-A.Y,B.X-A.X); Finish:=ArcTan2(C.Y-A.Y,C.X-A.X); while Finish<Start do Finish:=Finish+2*Pi;
    Radius:=LengthPoints(Style.Values['angle radius'],0.5*Scale,DocumentTextWidth(Context)); Eccentricity:=1;
    Numeric(Style.Values['angle eccentricity'],Eccentricity);
    Arc:=TPrimitive.Create; ApplyStyle(Arc); Scene.Items.Add(Arc);
    for I:=0 to 32 do begin T:=Start+(Finish-Start)*I/32; Point(Arc,PointAt(A.X*Scale+Radius*Cos(T),A.Y*Scale+Radius*Sin(T))); end;
    Text:=''; for I:=0 to Style.Count-1 do begin Value:=Style.Names[I]; if Copy(Value,1,1)='"' then begin P:=PosEx('"',Value,2); if P>1 then Text:=Copy(Value,2,P-2); end; end;
    NodeStyle.Clear; T:=(Start+Finish)/2; LabelAt(Text,PointAt(A.X*Scale+Radius*Eccentricity*Cos(T),A.Y*Scale+Radius*Eccentricity*Sin(T)));
    Result:=True;
  end;
  procedure Hatch(Path:TPrimitive);
  var Polygon,Crossings,Line:TDiagramPoints; Name:string; Color:TColor; Bounds:array[0..3] of Double; P:TDiagramPoint; I,J,K:Integer; Step,T:Double; Part:TPrimitive;
    procedure Stripe(X1,Y1,X2,Y2:Double);
    var H,I,J:Integer; Swap:TDiagramPoint;
    begin
      SetLength(Line,2); Line[0]:=PointAt(X1,Y1); Line[1]:=PointAt(X2,Y2); Crossings:=PathIntersections(Line,Polygon);
      for I:=1 to High(Crossings) do begin Swap:=Crossings[I]; J:=I-1;
        while (J>=0) and ((Crossings[J].X>Swap.X) or ((Abs(Crossings[J].X-Swap.X)<1e-8) and (Crossings[J].Y>Swap.Y))) do begin Crossings[J+1]:=Crossings[J]; Dec(J); end; Crossings[J+1]:=Swap;
      end;
      H:=0; while H<High(Crossings) do begin
        Part:=TPrimitive.Create; Part.Stroke:=Color; Part.Weight:=0.4*72/72.27;
        Point(Part,Crossings[H]); Point(Part,Crossings[H+1]); Scene.Items.Add(Part); Inc(H,2);
      end;
    end;
  begin
    Name:=Style.Values['pattern']; if Name='' then Exit; Color:=clBlack; ColorValue(Style.Values['pattern color'],Color);
    Polygon:=Copy(Path.Points); if Path.Kind=1 then begin
      SetLength(Polygon,65);
      for I:=0 to 64 do begin
        T:=2*Pi*I/64; Polygon[I]:=PointAt((Path.Points[0].X+Path.Points[1].X)/2+Cos(T)*Abs(Path.Points[1].X-Path.Points[0].X)/2,
          (Path.Points[0].Y+Path.Points[1].Y)/2+Sin(T)*Abs(Path.Points[1].Y-Path.Points[0].Y)/2);
      end;
    end else if Length(Polygon)>0 then begin I:=Length(Polygon); SetLength(Polygon,I+1); Polygon[I]:=Polygon[0]; end;
    if Length(Polygon)<4 then Exit; Bounds[0]:=MaxDouble; Bounds[1]:=MaxDouble; Bounds[2]:=-MaxDouble; Bounds[3]:=-MaxDouble;
    for P in Polygon do begin Bounds[0]:=Min(Bounds[0],P.X); Bounds[1]:=Min(Bounds[1],P.Y); Bounds[2]:=Max(Bounds[2],P.X); Bounds[3]:=Max(Bounds[3],P.Y); end;
    Step:=3*72/72.27;
    for I:=0 to Min(2048,Ceil((Bounds[2]-Bounds[0]+Bounds[3]-Bounds[1])/Step)) do begin
      T:=Bounds[0]-(Bounds[3]-Bounds[1])+I*Step;
      if (Name='north east lines') or (Name='crosshatch') then Stripe(T,Bounds[1]-1,T+Bounds[3]-Bounds[1]+2,Bounds[3]+1);
      if (Name='north west lines') or (Name='crosshatch') then Stripe(T,Bounds[3]+1,T+Bounds[3]-Bounds[1]+2,Bounds[1]-1);
      if (Name='horizontal lines') or (Name='grid') then Stripe(Bounds[0]-1,Bounds[1]+I*Step,Bounds[2]+1,Bounds[1]+I*Step);
      if (Name='vertical lines') or (Name='grid') then Stripe(Bounds[0]+I*Step,Bounds[1]-1,Bounds[0]+I*Step,Bounds[3]+1);
    end;
  end;
  procedure RegisterPath(Path:TPrimitive);
  var Index:Integer;
  begin
    if Path.PathName='' then Exit; Index:=NamedPaths.IndexOf(Path.PathName);
    if Index<0 then NamedPaths.AddObject(Path.PathName,Path) else NamedPaths.Objects[Index]:=Path;
  end;
  function IntersectPaths(const Setting:string):Boolean;
  var Fields:TStringList; Names:TDiagramOptions; Key,A,B:string; I,J,K:Integer; Crossings:TDiagramPoints; Node:TPrimitive;
  begin
    Result:=False; Fields:=TStringList.Create;
    try
      ReadOptions(PlainLabel(Setting),Fields); Key:=Fields.Values['of']; K:=Pos(' and ',Key); if K=0 then Exit;
      A:=Trim(Copy(Key,1,K-1)); B:=Trim(Copy(Key,K+5,MaxInt)); I:=NamedPaths.IndexOf(A); J:=NamedPaths.IndexOf(B);
      if (I<0) or (J<0) then Exit;
      Crossings:=PathIntersections(TPrimitive(NamedPaths.Objects[I]).Points,TPrimitive(NamedPaths.Objects[J]).Points);
      Names:=DiagramOptions(PlainLabel(Fields.Values['by']));
      for I:=0 to High(Crossings) do begin
        Key:='intersection-'+IntToStr(I+1); if I<=High(Names) then Key:=Names[I].Name;
        Node:=TPrimitive.Create; Node.Kind:=3; Node.NodeCenter:=Crossings[I]; Scene.Items.Add(Node); Nodes.AddObject(Key,Node);
      end;
      Result:=True;
    finally Fields.Free; end;
  end;
  function Decorate(Path:TPrimitive):Boolean;
  const Names:array[0..3] of string=('snake','zigzag','coil','brace');
  var Fields:TStringList; Name,Candidate:string; Amplitude,Segment:Double;
  begin
    Result:=True; if Style.IndexOfName('decorate')<0 then Exit; Fields:=TStringList.Create;
    try
      ReadOptions(PlainLabel(Style.Values['decoration']),Fields); Name:=Fields.Values['name'];
      if Name='' then for Candidate in Names do if Fields.IndexOfName(Candidate)>=0 then begin Name:=Candidate; Break; end;
      if IndexStr(Name,['snake','zigzag','coil','brace'])<0 then Exit(False);
      Amplitude:=LengthPoints(Fields.Values['amplitude'],2.5*72/72.27,DocumentTextWidth(Context));
      Segment:=LengthPoints(Fields.Values['segment length'],10*72/72.27,DocumentTextWidth(Context));
      Path.Points:=DecoratedPath(Path.Points,Name,Amplitude,Segment,Fields.IndexOfName('mirror')>=0);
    finally Fields.Free; end;
  end;
  function ReadBox(Plot:TPrimitive):Boolean;
  const Keys:array[0..4] of string=('lower whisker','lower quartile','median','upper quartile','upper whisker');
  var Values:TStringList; I:Integer;
  begin
    Result:=(Style.IndexOfName('boxplot prepared')>=0) or (Style.IndexOfName('boxplot')>=0);
    if not Result then Exit;
    Values:=TStringList.Create;
    try
      ReadOptions(PlainLabel(Style.Values['boxplot prepared']),Values);
      Plot.BoxVertical:=(Style.Values['boxplot/draw direction']='y') or (Options.Values['boxplot/draw direction']='y');
      Plot.BoxPosition:=Plots.Count; Plot.BoxExtent:=0.8;
      Numeric(Options.Values['boxplot/draw position'],Plot.BoxPosition); Numeric(Style.Values['boxplot/draw position'],Plot.BoxPosition);
      Numeric(Values.Values['draw position'],Plot.BoxPosition);
      Numeric(Options.Values['boxplot/box extend'],Plot.BoxExtent); Numeric(Style.Values['boxplot/box extend'],Plot.BoxExtent);
      Plot.WhiskerExtent:=Plot.BoxExtent*0.8; Numeric(Style.Values['boxplot/whisker extend'],Plot.WhiskerExtent);
      Plot.RawBox:=Style.IndexOfName('boxplot prepared')<0;
      Plot.BoxEstimator:=Style.Values['boxplot/estimator']; if Plot.BoxEstimator='' then Plot.BoxEstimator:=Options.Values['boxplot/estimator'];
      Plot.LowerQuantile:=0.25; Plot.UpperQuantile:=0.75; Plot.WhiskerRange:=1.5;
      Numeric(Options.Values['boxplot/lower quartile off'],Plot.LowerQuantile); Numeric(Style.Values['boxplot/lower quartile off'],Plot.LowerQuantile);
      Numeric(Options.Values['boxplot/upper quartile off'],Plot.UpperQuantile); Numeric(Style.Values['boxplot/upper quartile off'],Plot.UpperQuantile);
      Numeric(Options.Values['boxplot/whisker range'],Plot.WhiskerRange); Numeric(Style.Values['boxplot/whisker range'],Plot.WhiskerRange);
      if not Plot.RawBox then begin
        SetLength(Plot.BoxSummary,5);
        for I:=0 to 4 do if not Numeric(Values.Values[Keys[I]],Plot.BoxSummary[I]) then Exit(False);
      end;
      Plot.Markers:=True; Plot.OnlyMarks:=True;
    finally Values.Free; end;
  end;
  procedure BoxRange(Plot:TPrimitive);
  var I:Integer; Values,Outliers:TTikZNumbers; P:TDiagramPoint;
  begin
    if Plot.RawBox then begin
      SetLength(Values,Length(Plot.Points)); for I:=0 to High(Values) do Values[I]:=Plot.Points[I].Y;
      BoxStatistics(Values,Plot.BoxSummary,Outliers,Plot.BoxEstimator,Plot.LowerQuantile,Plot.UpperQuantile,Plot.WhiskerRange); Plot.Points:=nil;
      for I:=0 to High(Outliers) do if Plot.BoxVertical then Point(Plot,PointAt(0,Outliers[I])) else Point(Plot,PointAt(Outliers[I],0));
    end;
    for I:=0 to High(Plot.Points) do begin
      if Plot.BoxVertical then begin
        if not Plot.RawBox then Plot.Points[I].Y:=Plot.Points[I].X;
        Plot.Points[I].X:=Plot.BoxPosition;
      end else Plot.Points[I].Y:=Plot.BoxPosition;
    end;
    for I:=0 to High(Plot.BoxSummary) do begin
      P:=PointAt(Plot.BoxSummary[I],Plot.BoxPosition-Plot.BoxExtent/2);
      if Plot.BoxVertical then P:=PointAt(P.Y,P.X);
      if not HasXMin then XMin:=Min(XMin,P.X); if not HasXMax then XMax:=Max(XMax,P.X);
      if not HasYMin then YMin:=Min(YMin,P.Y); if not HasYMax then YMax:=Max(YMax,P.Y);
      if Plot.BoxVertical then P.X:=Plot.BoxPosition+Plot.BoxExtent/2 else P.Y:=Plot.BoxPosition+Plot.BoxExtent/2;
      if not HasXMax then XMax:=Max(XMax,P.X); if not HasYMax then YMax:=Max(YMax,P.Y);
    end;
  end;
  procedure DrawBox(Plot:TPrimitive);
  var Part:TPrimitive; S:TTikZNumbers; Position,Half,Cap:Double;
    function BoxPoint(Value,Across:Double):TDiagramPoint;
    begin if Plot.BoxVertical then Result:=Project(PointAt(Across,Value)) else Result:=Project(PointAt(Value,Across)); end;
    procedure Line(A,B,C,D:Double);
    begin
      Part:=TPrimitive.Create; Scene.Items.Add(Part); Part.Stroke:=Plot.Stroke; Part.Weight:=Plot.Weight;
      Part.Opacity:=Plot.Opacity; Point(Part,BoxPoint(A,B)); Point(Part,BoxPoint(C,D));
    end;
  begin
    S:=Plot.BoxSummary; if Length(S)<>5 then Exit; Position:=Plot.BoxPosition; Half:=Plot.BoxExtent/2; Cap:=Plot.WhiskerExtent/2;
    Line(S[0],Position,S[1],Position); Line(S[3],Position,S[4],Position);
    Line(S[0],Position-Cap,S[0],Position+Cap); Line(S[4],Position-Cap,S[4],Position+Cap);
    Part:=TPrimitive.Create; Scene.Items.Add(Part); Part.Stroke:=Plot.Stroke; Part.Fill:=Plot.Fill; Part.Weight:=Plot.Weight; Part.Opacity:=Plot.Opacity; Part.Closed:=True;
    Point(Part,BoxPoint(S[1],Position-Half)); Point(Part,BoxPoint(S[3],Position-Half));
    Point(Part,BoxPoint(S[3],Position+Half)); Point(Part,BoxPoint(S[1],Position+Half));
    Line(S[2],Position-Half,S[2],Position+Half);
  end;
  procedure FillBetween(Region:TPrimitive);
  var I,A,B:Integer; Upper,Lower:TPrimitive;
  begin
    A:=NamedPaths.IndexOf(Region.BetweenFirst); B:=NamedPaths.IndexOf(Region.BetweenSecond); if (A<0) or (B<0) then Exit;
    Upper:=TPrimitive(NamedPaths.Objects[A]); Lower:=TPrimitive(NamedPaths.Objects[B]);
    Region.Points:=nil; Region.Closed:=True; Region.Markers:=False; Region.OnlyMarks:=False;
    if Region.Fill=clNone then Region.Fill:=Region.Stroke; Region.Stroke:=clNone;
    for I:=0 to High(Upper.Points) do Point(Region,Upper.Points[I]);
    for I:=High(Lower.Points) downto 0 do Point(Region,Lower.Points[I]);
    { Filled areas lie behind both boundary paths, even when declared later. }
    A:=Min(Scene.Items.IndexOf(Upper),Scene.Items.IndexOf(Lower)); B:=Scene.Items.IndexOf(Region);
    if (A>=0) and (B>A) then Scene.Items.Move(B,A);
  end;
  {$I nativepolar.inc}
