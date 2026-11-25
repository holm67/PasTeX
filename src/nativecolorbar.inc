{ SPDX-License-Identifier: GPL-3.0-or-later }
  procedure DrawColorbar;
  var Settings:TStringList; Palette,Part:TPrimitive; Horizontal,LeftSide:Boolean;
      X,Y,W,H,Gap,Minimum,Maximum,T0,T1,Position,LabelExtent,TickWidth,Outside,Distance:Double;
      LeftEdge,RightEdge,BottomEdge,PX,PY,RX,RY:Double;
      I,J,N:Integer; AxisKey,Text,Value:string; Ticks:TPlotTicks; Names:TDiagramOptions; F:TFormatSettings;
    procedure Corner(Item:TPrimitive; A,B:Double);
    begin
      if Horizontal then Point(Item,PointAt(X+A*W,Y+B*H)) else Point(Item,PointAt(X+B*W,Y+A*H));
    end;
  begin
    if not PGFPlotsAxis or (Options.Values['colorbar']='false') then Exit;
    Horizontal:=Options.Values['colorbar horizontal']='true'; LeftSide:=Options.Values['colorbar left']='true';
    if not Horizontal and not LeftSide and (Options.Values['colorbar']<>'true') and (Options.Values['colorbar right']<>'true') then Exit;
    Settings:=TStringList.Create; Palette:=TPrimitive.Create;
    try
      ReadOptions(PlainLabel(Options.Values['every colorbar/.style']),Settings);
      ReadOptions(PlainLabel(Options.Values['every colorbar/.append style']),Settings);
      ReadOptions(PlainLabel(Options.Values['colorbar style']),Settings);
      Style.Clear; ApplyStyle(Palette);
      if not Palette.HasMetaMin then Palette.MetaMin:=MetaMin;
      if not Palette.HasMetaMax then Palette.MetaMax:=MetaMax;
      Palette.ColorMap:=LoadPlotColorMap(Palette.ColorMapName,Palette.ColorMapDefinition,Context,Directory);
      Minimum:=Palette.MetaMin; Maximum:=Palette.MetaMax; if Maximum<=Minimum then Maximum:=Minimum+1;
      Gap:=0.3*72/2.54; W:=LengthPoints(Options.Values['colorbar/width'],0.5*72/2.54,DocumentTextWidth(Context)); H:=PlotHeight;
      if Horizontal then begin H:=W; W:=PlotWidth; end;
      W:=Max(1.0,LengthPoints(Settings.Values['width'],W,DocumentTextWidth(Context)));
      H:=Max(1.0,LengthPoints(Settings.Values['height'],H,DocumentTextWidth(Context)));
      LeftEdge:=0; RightEdge:=PlotWidth; BottomEdge:=0;
      { PGFPlots places the scale beyond the parent axis descriptions. }
      for I:=0 to Scene.Items.Count-1 do begin
        Part:=TPrimitive(Scene.Items[I]);
        if (Part.Kind<>2) or (Length(Part.Points)=0) or (AxisPrevious.IndexOf(Part)>=0) then Continue;
        for J:=0 to 3 do begin
          PX:=((J and 1)-Part.AnchorX)*Part.LabelW; PY:=(((J shr 1) and 1)-Part.AnchorY)*Part.LabelH;
          RX:=Part.Points[0].X+Cos(DegToRad(Part.Rotation))*PX-Sin(DegToRad(Part.Rotation))*PY;
          RY:=Part.Points[0].Y+Sin(DegToRad(Part.Rotation))*PX+Cos(DegToRad(Part.Rotation))*PY;
          LeftEdge:=Min(LeftEdge,RX); RightEdge:=Max(RightEdge,RX); BottomEdge:=Min(BottomEdge,RY);
        end;
      end;
      X:=RightEdge+Gap; Y:=PlotHeight-H;
      if LeftSide then X:=LeftEdge-Gap-W;
      if Horizontal then begin X:=0; Y:=BottomEdge-Gap-H; end;
      X:=X+LengthPoints(Settings.Values['xshift'],0,DocumentTextWidth(Context));
      Y:=Y+LengthPoints(Settings.Values['yshift'],0,DocumentTextWidth(Context));
      N:=Length(Palette.ColorMap)-1; if N<1 then N:=64;
      for I:=0 to N-1 do begin
        T0:=I/N; T1:=(I+1)/N;
        if Length(Palette.ColorMap)>1 then begin T0:=Palette.ColorMap[I].Position; T1:=Palette.ColorMap[I+1].Position; end;
        Part:=TPrimitive.Create; Scene.Items.Add(Part); Part.Closed:=True; Part.Stroke:=clNone;
        Part.Fill:=MappedColor(Palette,Minimum+(Maximum-Minimum)*(T0+T1)/2); SetLength(Part.VertexColors,4);
        Part.VertexColors[0]:=MappedColor(Palette,Minimum+(Maximum-Minimum)*T0);
        Part.VertexColors[1]:=MappedColor(Palette,Minimum+(Maximum-Minimum)*T1);
        Part.VertexColors[2]:=Part.VertexColors[1]; Part.VertexColors[3]:=Part.VertexColors[0];
        if (Palette.MapAccess='piecewise constant') or (Palette.MapAccess='const') then Part.VertexColors:=nil;
        Corner(Part,T0,0); Corner(Part,T1,0); Corner(Part,T1,1); Corner(Part,T0,1);
      end;
      Part:=TPrimitive.Create; Scene.Items.Add(Part); Part.Closed:=True;
      Style.Clear; ReadOptions(PlainLabel(Settings.Values['axis line style']),Style); ApplyStyle(Part); Part.Markers:=False;
      Corner(Part,0,0); Corner(Part,1,0); Corner(Part,1,1); Corner(Part,0,1);
      if Horizontal then begin AxisKey:='x'; Distance:=W; end else begin AxisKey:='y'; Distance:=H; end;
      Numeric(Settings.Values[AxisKey+'min'],Minimum); Numeric(Settings.Values[AxisKey+'max'],Maximum);
      TickWidth:=LengthPoints(Settings.Values['major tick length'],0.15*72/2.54,DocumentTextWidth(Context));
      Outside:=0; Value:=Settings.Values[AxisKey+'tick align']; if Value='' then Value:=Settings.Values['tick align'];
      if Value='outside' then Outside:=TickWidth else if Value='center' then Outside:=TickWidth/2;
      Position:=0; Numeric(Settings.Values[AxisKey+'tick distance'],Position); Ticks:=PlotTicks(Minimum,Maximum,Distance,Position);
      if Settings.IndexOfName(AxisKey+'tick')>=0 then Ticks:=ExplicitTicks(Settings.Values[AxisKey+'tick']);
      Names:=DiagramOptions(PlainLabel(Settings.Values[AxisKey+'ticklabels']));
      F:=DefaultFormatSettings; F.DecimalSeparator:='.'; LabelExtent:=0;
      for I:=0 to High(Ticks) do begin
        Position:=(Ticks[I]-Minimum)/Max(1e-12,Maximum-Minimum); if (Position< -1e-8) or (Position>1+1e-8) then Continue;
        Part:=TPrimitive.Create; Scene.Items.Add(Part);
        Style.Clear; Style.Values['color']:='gray'; Style.Values['very thin']:='true';
        ReadOptions(PlainLabel(Settings.Values['every tick/.style']),Style);
        ReadOptions(PlainLabel(Settings.Values['tick style']),Style); ReadOptions(PlainLabel(Settings.Values['major tick style']),Style);
        ReadOptions(PlainLabel(Settings.Values[AxisKey+' tick style']),Style); ApplyStyle(Part); Part.Markers:=False;
        if Horizontal then begin
          Point(Part,PointAt(X+Position*W,Y-Outside)); Point(Part,PointAt(X+Position*W,Y+TickWidth-Outside));
        end else if LeftSide then begin
          Point(Part,PointAt(X-Outside,Y+Position*H)); Point(Part,PointAt(X+TickWidth-Outside,Y+Position*H));
        end else begin
          Point(Part,PointAt(X+W+Outside,Y+Position*H)); Point(Part,PointAt(X+W-TickWidth+Outside,Y+Position*H));
        end;
        Text:='$'+FloatToStrF(Ticks[I],ffGeneral,6,0,F)+'$'; if I<=High(Names) then Text:=PlainLabel(Names[I].Name);
        Style.Clear; NodeStyle.Clear; ReadOptions(PlainLabel(Settings.Values['tick label style']),NodeStyle);
        ReadOptions(PlainLabel(Settings.Values[AxisKey+' tick label style']),NodeStyle);
        if Horizontal then LabelAt(Text,PointAt(X+Position*W,Y-Outside-3))
        else if LeftSide then LabelAt(Text,PointAt(X-Outside-3,Y+Position*H))
        else LabelAt(Text,PointAt(X+W+Outside+3,Y+Position*H));
        BindOption(AxisKey+'ticklabels',I,'colorbar style');
        if LabelItem=nil then Continue;
        if Horizontal then begin LabelItem.AnchorY:=1; LabelExtent:=Max(LabelExtent,LabelItem.LabelH); end
        else begin if LeftSide then LabelItem.AnchorX:=1 else LabelItem.AnchorX:=0; LabelExtent:=Max(LabelExtent,LabelItem.LabelW); end;
      end;
      Style.Clear; NodeStyle.Clear; ReadOptions(PlainLabel(Settings.Values['label style']),NodeStyle);
      ReadOptions(PlainLabel(Settings.Values[AxisKey+' label style']),NodeStyle);
      if Horizontal then LabelAt(Settings.Values['xlabel'],PointAt(X+W/2,Y-Outside-LabelExtent-6))
      else if LeftSide then LabelAt(Settings.Values['ylabel'],PointAt(X-Outside-LabelExtent-6,Y+H/2))
      else LabelAt(Settings.Values['ylabel'],PointAt(X+W+Outside+LabelExtent+6,Y+H/2));
      BindOption(AxisKey+'label',-1,'colorbar style');
      if LabelItem<>nil then begin
        if Horizontal then LabelItem.AnchorY:=1
        else begin LabelItem.Rotation:=LabelItem.Rotation+90; if LeftSide then LabelItem.AnchorY:=0 else LabelItem.AnchorY:=1; end;
      end;
      Style.Clear; NodeStyle.Clear; ReadOptions(PlainLabel(Settings.Values['title style']),NodeStyle);
      LabelAt(Settings.Values['title'],PointAt(X+W/2,Y+H+8)); BindOption('title',-1,'colorbar style');
      if LabelItem<>nil then LabelItem.AnchorY:=0;
    finally Palette.Free; Settings.Free; end;
  end;
