{ SPDX-License-Identifier: GPL-3.0-or-later }
  procedure PolarAxes;
  var Values:TPlotTicks; Names:TDiagramOptions; Shape:TPrimitive; Position,Normal:TDiagramPoint;
      I,J,MinTicks:Integer; Radius,Angle,Distance,AxisLength,Span,MaxSpace,TickLength,Outside:Double;
      Key,Text,Setting:string; Full,Grid,DrawAxis:Boolean; F:TFormatSettings;
    procedure Paint(Item:TPrimitive; const Kind,Key:string);
    begin
      Style.Clear;
      if Kind='grid' then begin Style.Values['color']:='black!25'; Style.Values['very thin']:='true'; end;
      if Kind='tick' then begin Style.Values['color']:='gray'; Style.Values['very thin']:='true'; ReadOptions(PlainLabel(Options.Values['every tick/.style']),Style); end;
      ReadOptions(PlainLabel(Options.Values[Kind+' style']),Style);
      if Kind<>'axis line' then ReadOptions(PlainLabel(Options.Values['major '+Kind+' style']),Style);
      ReadOptions(PlainLabel(Options.Values[Key+' '+Kind+' style']),Style);
      ReadOptions(PlainLabel(Options.Values['major '+Key+' '+Kind+' style']),Style);
      ApplyStyle(Item); Item.Markers:=False;
    end;
    procedure Arc(R:Double; Border:Boolean);
    var N,K:Integer;
    begin
      Shape:=TPrimitive.Create; Scene.Items.Insert(AxisPrevious.Count,Shape);
      if Border then Paint(Shape,'axis line','x') else Paint(Shape,'grid','y');
      if Full then begin
        Shape.Kind:=1;
        Point(Shape,PointAt(PlotWidth/2-R/YMax*PlotWidth/2,PlotHeight/2-R/YMax*PlotHeight/2));
        Point(Shape,PointAt(PlotWidth/2+R/YMax*PlotWidth/2,PlotHeight/2+R/YMax*PlotHeight/2));
      end else begin
        N:=Max(2,Ceil(Span/3)); for K:=0 to N do Point(Shape,Project(PointAt(XMin+Span*K/N,R)));
      end;
    end;
    procedure Ray(A:Double; Border:Boolean);
    begin
      Shape:=TPrimitive.Create; Scene.Items.Insert(AxisPrevious.Count,Shape);
      if Border then Paint(Shape,'axis line','y') else Paint(Shape,'grid','x');
      Point(Shape,Project(PointAt(A,YMin))); Point(Shape,Project(PointAt(A,YMax)));
    end;
  begin
    { Follow PGFPlots' polar axis: angular ticks use the circumference,
      radial labels sit above xmin, and a full turn omits its duplicate tick. }
    Span:=Min(360.0,Max(0.0,XMax-XMin)); Full:=Abs(Span-360)<0.002;
    F:=DefaultFormatSettings; F.DecimalSeparator:='.';
    DrawAxis:=Options.Values['axis lines']<>'none';
    if DrawAxis then begin
      Arc(YMax,True); if YMin>0 then Arc(YMin,True);
      if not Full then begin Ray(XMin,True); Ray(XMin+Span,True); end;
    end;
    for J:=0 to 1 do begin
      if J=0 then begin Key:='y'; AxisLength:=PlotWidth/2*(YMax-YMin)/YMax; end
      else begin Key:='x'; AxisLength:=Pi*PlotWidth*Span/360; end;
      Distance:=0; Numeric(Options.Values[Key+'tick distance'],Distance);
      MaxSpace:=35; Numeric(Options.Values['max space between ticks'],MaxSpace);
      MinTicks:=StrToIntDef(Options.Values['try min ticks'],4);
      if J=0 then Values:=PlotTicks(YMin,YMax,AxisLength,Distance,MinTicks,MaxSpace)
      else Values:=PolarTicks(XMin,XMin+Span,AxisLength,Distance,MinTicks,MaxSpace);
      if Options.IndexOfName(Key+'tick')>=0 then Values:=ExplicitTicks(Options.Values[Key+'tick']);
      Names:=DiagramOptions(PlainLabel(Options.Values[Key+'ticklabels']));
      Setting:=Options.Values['grid']; Grid:=(Setting='') or (Setting='major') or (Setting='both');
      if Options.IndexOfName(Key+'majorgrids')>=0 then Grid:=Options.Values[Key+'majorgrids']='true';
      TickLength:=LengthPoints(Options.Values['major tick length'],0.15*72/2.54,DocumentTextWidth(Context));
      Setting:=Options.Values[Key+'tick align']; if Setting='' then Setting:=Options.Values['tick align'];
      Outside:=0; if Setting='outside' then Outside:=TickLength else if Setting='center' then Outside:=TickLength/2;
      for I:=0 to High(Values) do begin
        if J=0 then begin
          Radius:=Values[I]; Angle:=XMin; if (Radius<YMin-1e-8) or (Radius>YMax+1e-8) then Continue;
          if Grid and (Radius>0) then Arc(Radius,False);
          Normal:=PointAt(-Sin(DegToRad(Angle)),Cos(DegToRad(Angle)));
          Text:=FloatToStrF(Radius,ffGeneral,6,0,F);
        end else begin
          Angle:=Values[I]; Radius:=YMax;
          if (Angle<XMin-1e-8) or (Angle>XMin+Span+1e-8) or (Full and (Abs(Angle-XMin-Span)<0.002)) then Continue;
          if Grid then Ray(Angle,False);
          Normal:=PointAt(Cos(DegToRad(Angle)),Sin(DegToRad(Angle)));
          Distance:=Angle; if Distance>360 then Distance:=Distance-360*Floor(Distance/360);
          Text:=FloatToStrF(Distance,ffGeneral,6,0,F);
        end;
        Position:=Project(PointAt(Angle,Radius));
        if DrawAxis then begin
          Shape:=TPrimitive.Create; Scene.Items.Add(Shape); Paint(Shape,'tick',Key);
          Point(Shape,PointAt(Position.X+Normal.X*Outside,Position.Y+Normal.Y*Outside));
          Point(Shape,PointAt(Position.X-Normal.X*(TickLength-Outside),Position.Y-Normal.Y*(TickLength-Outside)));
        end;
        Text:='$'+Text+'$';
        if Options.IndexOfName(Key+'ticklabels')>=0 then begin
          if I>=Length(Names) then Continue; Text:=PlainLabel(Names[I].Name); if Text='' then Continue;
        end;
        Style.Clear; NodeStyle.Clear;
        ReadOptions(PlainLabel(Options.Values['tick label style']),NodeStyle);
        ReadOptions(PlainLabel(Options.Values[Key+' tick label style']),NodeStyle);
        ReadOptions(PlainLabel(Options.Values[Key+'ticklabel style']),NodeStyle);
        LabelAt(Text,PointAt(Position.X+Normal.X*(Outside+3),Position.Y+Normal.Y*(Outside+3))); BindOption(Key+'ticklabels',I);
        if LabelItem<>nil then begin
          LabelItem.AnchorX:=(1-Normal.X)/2; LabelItem.AnchorY:=(1-Normal.Y)/2; LabelOptions;
        end;
      end;
    end;
    Style.Clear; NodeStyle.Clear;
  end;
