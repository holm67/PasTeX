{ SPDX-License-Identifier: GPL-3.0-or-later }
  function DataVisualization:Boolean;
  const PositionKeys:array[0..5] of string=('xshift','yshift','at','anchor','title','legend pos');
  var Data:TDataVisualization; AxisOptions,TickOptions,GridOptions,LabelSettings,Science:TStringList;
      DataSet:TDataVisualSet; I,J,OptionAt:Integer; Key,Code,Text:string; Number:Double; Range:TDiagramRange; Loaded:Boolean; MarkColor:TColor;
    procedure TranslateAxis(const Key:string);
    var Name,Raw:string; Entry:TDiagramOption; P:Integer;
      procedure CopyOption(const Name,Target:string);
      begin if AxisOptions.Values[Name]<>'' then Options.Values[Target]:=AxisOptions.Values[Name]; end;
    begin
      Data.AxisOptions(Key,AxisOptions);
      CopyOption('min value',Key+'min'); CopyOption('max value',Key+'max');
      CopyOption('include value',Key+' include value');
      CopyOption('style',Key+' axis line style');
      if AxisOptions.IndexOfName('logarithmic')>=0 then Options.Values[Key+'mode']:='log';
      if AxisOptions.Values['length']<>'' then begin
        if Key='x' then Options.Values['width']:=AxisOptions.Values['length'] else Options.Values['height']:=AxisOptions.Values['length'];
      end;
      TickOptions.Clear;
      Raw:=AxisOptions.Values['ticks'];
      Options.Values[Key+' tick about']:='5';
      ReadOptions(PlainLabel(Raw),TickOptions);
      if TickOptions.IndexOfName('none')>=0 then Options.Values[Key+'tick']:='{}';
      if TickOptions.IndexOfName('few')>=0 then Options.Values[Key+' tick about']:='3';
      if TickOptions.IndexOfName('many')>=0 then Options.Values[Key+' tick about']:='10';
      if TickOptions.Values['about']<>'' then Options.Values[Key+' tick about']:=TickOptions.Values['about'];
      if TickOptions.Values['step']<>'' then Options.Values[Key+'tick distance']:=TickOptions.Values['step'];
      if TickOptions.Values['style']<>'' then Options.Values[Key+' tick style']:=TickOptions.Values['style'];
      if TickOptions.Values['node style']<>'' then Options.Values[Key+'ticklabel style']:=TickOptions.Values['node style'];
      Raw:=PlainLabel(TickOptions.Values['at']);
      if Raw<>'' then begin
        Code:=''; Text:='';
        for Entry in DiagramOptions(Raw) do begin
          Name:=Entry.Name; J:=Pos(' as ',Name);
          if J>0 then begin Text:=Text+','+Copy(Name,J+4,MaxInt); Name:=Trim(Copy(Name,1,J-1)); end
          else Text:=Text+',{$'+Name+'$}';
          Code:=Code+','+Name;
        end;
        Options.Values[Key+'tick']:=Copy(Code,2,MaxInt); Options.Values[Key+'ticklabels']:=Copy(Text,2,MaxInt);
      end;
      GridOptions.Clear; Raw:=AxisOptions.Values['grid'];
      if (Raw<>'') and (Raw<>'none') and (Raw<>'false') then begin
        ReadOptions(PlainLabel(Raw),GridOptions);
        { A grid with options does not implicitly request "at default ticks".
          Without step/about/at, TeX generates no grid positions. }
        if GridOptions.IndexOfName('at default ticks')>=0 then Options.Values[Key+' grid step']:='ticks';
        if GridOptions.Values['step']<>'' then Options.Values[Key+' grid step']:=GridOptions.Values['step']
        else if (GridOptions.Values['about']<>'') or (GridOptions.IndexOfName('few')>=0) or
          (GridOptions.IndexOfName('some')>=0) or (GridOptions.IndexOfName('many')>=0) then begin
          Options.Values[Key+' grid step']:='0'; Name:='5';
          if GridOptions.IndexOfName('few')>=0 then Name:='3' else if GridOptions.IndexOfName('many')>=0 then Name:='10'
          else if GridOptions.Values['about']<>'' then Name:=GridOptions.Values['about'];
          Options.Values[Key+' grid about']:=Name;
        end;
        if Options.Values[Key+' grid step']<>'' then Options.Values[Key+'majorgrids']:='true';
        if GridOptions.Values['at']<>'' then begin
          Options.Values[Key+' grid at']:=PlainLabel(GridOptions.Values['at']); Options.Values[Key+'majorgrids']:='true';
        end;
        Name:=GridOptions.Values['minor steps between steps']; if Name='true' then Name:='9';
        if Name<>'' then Options.Values[Key+' minor tick num']:=Name;
        if GridOptions.Values['style']<>'' then Options.Values['grid style']:=GridOptions.Values['style'];
      end;
      LabelSettings.Clear; Raw:=AxisOptions.Values['label'];
      if Raw<>'' then begin
        if Raw='true' then Options.Values[Key+'label']:='$\mathit{'+Data.AxisAttribute(Key)+'}$'
        else begin
          P:=1;
          if Copy(Raw,1,1)='[' then begin
            ReadOptions(ReadTeXGroup(Raw,P,'[',']'),LabelSettings); Raw:=Copy(Raw,P,MaxInt);
          end else ReadOptions(PlainLabel(Raw),LabelSettings);
          if LabelSettings.Values['text']<>'' then Options.Values[Key+'label']:=PlainLabel(LabelSettings.Values['text'])
          else Options.Values[Key+'label']:=Raw;
          if LabelSettings.Values['node style']<>'' then Options.Values[Key+'label style']:=LabelSettings.Values['node style'];
        end;
      end;
    end;
    procedure IncludeValues(const Key:string; var Lower,Upper:Double; FixedLower,FixedUpper:Boolean);
    var Entry:TDiagramOption; Value:Double;
    begin
      for Entry in DiagramOptions(Options.Values[Key+' include value']) do
        if Numeric(Entry.Name,Value) then begin
          if not FixedLower then Lower:=Min(Lower,Value); if not FixedUpper then Upper:=Max(Upper,Value);
        end;
    end;
  begin
    Result:=False; if InAxis then Exit;
    Data:=TDataVisualization.Create; AxisOptions:=TStringList.Create; TickOptions:=TStringList.Create;
    GridOptions:=TStringList.Create; LabelSettings:=TStringList.Create; Science:=TStringList.Create;
    try
      DataOptions:=nil; OptionAt:=P;
      if DiagramGroup(Source,OptionAt,'[',']',Range) then DataOptions:=DiagramOptions(Copy(Source,Range.First+1,Range.Last-Range.First),Range.First);
      Loaded:=Data.Load(Source,Directory,P,DataDefaults);
      if InputFiles<>nil then for I:=0 to Data.InputFiles.Count-1 do
        if InputFiles.IndexOf(Data.InputFiles[I])<0 then InputFiles.Add(Data.InputFiles[I]);
      if not Loaded then begin if Diagnostics<>nil then Diagnostics.Add(Data.ErrorText); Exit; end;
      Options.Clear; ReadOptions(PlainLabel(Data.Options.Values['scientific axes']),Science);
      Code:=Data.Options.Values['scientific axes/width']; if Code='' then Code:=Science.Values['width'];
      if Code='' then Code:='5cm'; Options.Values['width']:=Code;
      Number:=LengthPoints(Code,5*72/2.54,DocumentTextWidth(Context));
      Code:=Data.Options.Values['scientific axes/height']; if Code='' then Code:=Science.Values['height'];
      if Code='' then begin Str(Number*0.618:0:6,Code); Code:=Trim(Code)+'bp'; end;
      Options.Values['height']:=Code; Options.Values['tick align']:='outside';
      Options.Values['major tick length']:='2pt'; Options.Values['axis line style']:='draw=black!50';
      Options.Values['tick style']:='draw=black!50,thin,line cap=round'; Options.Values['@datavis']:='true';
      Options.Values['major grid style']:='thin'; Options.Values['minor grid style']:='very thin';
      Options.Values['tick label style']:='font=\footnotesize,inner sep=1pt';
      Options.Values['label style']:='font=\small'; Options.Values['legend pos']:='outer east';
      Options.Values['legend cell align']:='left';
      for Key in PositionKeys do
        if Data.Options.Values[Key]<>'' then Options.Values[Key]:=Data.Options.Values[Key];
      for Key in ['x','y'] do TranslateAxis(Key);
      if Data.Options.IndexOfName('school book axes')>=0 then begin
        Options.Values['axis lines']:='middle'; Options.Values['hide obscured x ticks']:='false';
        Options.Values['hide obscured y ticks']:='false'; Options.Values['axis line style']:='draw=black,->';
      end;
      StartAxis('axis'); PGFPlotsAxis:=False;
      IncludeValues('x',XMin,XMax,HasXMin,HasXMax); IncludeValues('y',YMin,YMax,HasYMin,HasYMax);
      for I:=0 to Data.Sets.Count-1 do begin
        DataSet:=TDataVisualSet(Data.Sets[I]); if Length(DataSet.Points)=0 then Continue;
        Plot:=TPrimitive.Create; Plot.Stroke:=clBlack; Plot.Weight:=0.6*72/72.27;
        Plot.OnlyMarks:=DataSet.Kind='scatter'; Plot.Markers:=Plot.OnlyMarks; if Plot.Markers then Plot.MarkKind:='x';
        if Plot.OnlyMarks then Plot.Weight:=0.4*72/72.27;
        Plot.Closed:=(DataSet.Kind='cycle') or (DataSet.Kind='smooth cycle');
        Scene.Items.Add(Plot); Plots.Add(Plot); Style.Clear;
        Code:=Data.Options.Values['style sheet'];
        if Pos('vary hue',Code)>0 then begin
          case I mod 6 of 0:Style.Values['color']:='black'; 1:Style.Values['color']:='red!80!black';
            2:Style.Values['color']:='blue!80!black'; 3:Style.Values['color']:='green!60!black';
            4:Style.Values['color']:='orange!80!black'; 5:Style.Values['color']:='black!60'; end;
        end;
        if (Pos('dashing',Code)>0) and Odd(I) then Style.Values['dashed']:='true';
        if Pos('thickness',Code)>0 then begin Str(0.3+(I+1)*0.2:0:3,Text); Style.Values['line width']:=Trim(Text)+'pt'; end;
        ApplyStyle(Plot); MarkColor:=Plot.Stroke;
        ReadOptions(PlainLabel(Data.Options.Values['every visualizer/.style']),Style);
        ReadOptions(StringReplace(PlainLabel(DataSet.Style),'visualizer color','color',[rfReplaceAll]),Style); ApplyStyle(Plot);
        if Plot.OnlyMarks then begin
          GridOptions.Clear; ReadOptions(PlainLabel(DataSet.Style),GridOptions);
          if GridOptions.Values['visualizer color']<>'' then ColorValue(GridOptions.Values['visualizer color'],MarkColor);
          ReadOptions(PlainLabel(GridOptions.Values['mark options']),GridOptions);
          if GridOptions.Values['draw']<>'' then ColorValue(GridOptions.Values['draw'],MarkColor);
          Plot.Stroke:=MarkColor;
        end;
        for J:=0 to High(DataSet.Points) do Point(Plot,DataSet.Points[J]);
        PlotRange(Plot);
      end;
      if Data.Options.IndexOfName('school book axes')>=0 then begin
        PlotWidth:=Max(20,(XMax-XMin)*72/2.54); PlotHeight:=Max(20,(YMax-YMin)*72/2.54);
      end;
      { scientific axes maps surveyed min/max to its configured length.
        PGFPlots' percentage range enlargement belongs to a different API. }
      for I:=0 to Data.Sets.Count-1 do begin
        DataSet:=TDataVisualSet(Data.Sets[I]);
        if DataSet.Legend<>'' then begin
          Style.Clear; NodeStyle.Clear; NodeStyle.Values['font']:='\small'; LabelAt(DataSet.Legend,PointAt(0,0));
          if not BindDataLabel([DataSet.Name,'label in legend','text']) then BindDataLabel([DataSet.Name,'label in legend']);
          if LabelItem<>nil then Legends.Add(LabelItem);
        end;
      end;
      Result:=FinishAxis;
    finally Science.Free; LabelSettings.Free; GridOptions.Free; TickOptions.Free; AxisOptions.Free; Data.Free; end;
  end;
