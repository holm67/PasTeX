{ SPDX-License-Identifier: GPL-3.0-or-later }
  function ArcPath(Path:TPrimitive; var Position:Integer):Boolean;
  var ArcOptions:TStringList; Parameters,Code:string; P,I,Steps:Integer;
      StartAngle,EndAngle,RX,RY,CX,CY,Angle:Double; Endpoint:TDiagramPoint;
    function Number(const Key:string; Default:Double):Double;
    begin
      Code:=ArcOptions.Values[Key]; Result:=Default;
      if (Code<>'') and not Calc.Scalar(Code,Result) then raise EConvertError.Create('Invalid arc '+Key);
    end;
  begin
    Result:=False; if Length(Path.Points)=0 then Exit; ArcOptions:=TStringList.Create;
    try
      SkipTeXSpace(Body,Position);
      if Copy(Body,Position,1)='[' then ReadOptions(ReadTeXGroup(Body,Position,'[',']'),ArcOptions)
      else begin
        Parameters:=ReadTeXGroup(Body,Position,'(',')');
        P:=Pos(':',Parameters); if P=0 then Exit;
        ArcOptions.Values['start angle']:=Copy(Parameters,1,P-1); Delete(Parameters,1,P);
        P:=Pos(':',Parameters); if P=0 then Exit;
        ArcOptions.Values['end angle']:=Copy(Parameters,1,P-1); ArcOptions.Values['radius']:=Copy(Parameters,P+1,MaxInt);
      end;
      StartAngle:=Number('start angle',0); EndAngle:=Number('end angle',StartAngle+Number('delta angle',0));
      RX:=Number('x radius',Number('radius',1)); RY:=Number('y radius',Number('radius',1));
      if (Abs(EndAngle-StartAngle)>36000) or (Abs(RX)>1e6) or (Abs(RY)>1e6) then Exit;
      Endpoint:=Path.Points[High(Path.Points)];
      CX:=Endpoint.X-RX*Scale*Cos(DegToRad(StartAngle)); CY:=Endpoint.Y-RY*Scale*Sin(DegToRad(StartAngle));
      Steps:=Max(1,Min(2048,Ceil(Abs(EndAngle-StartAngle)/2)));
      for I:=1 to Steps do begin
        Angle:=DegToRad(StartAngle+(EndAngle-StartAngle)*I/Steps);
        Endpoint.X:=CX+RX*Scale*Cos(Angle); Endpoint.Y:=CY+RY*Scale*Sin(Angle); Point(Path,Endpoint);
      end;
      RelativeBase:=PointAt(Endpoint.X/Scale,Endpoint.Y/Scale); Result:=True;
    finally ArcOptions.Free; end;
  end;
  procedure RotatePathLabel(LabelObject:TPrimitive; Rotation:Double);
  var Angle,DX,DY:Double;
  begin
    Angle:=DegToRad(Rotation-LabelObject.Rotation);
    DX:=LabelObject.Points[0].X-LabelObject.NodeCenter.X; DY:=LabelObject.Points[0].Y-LabelObject.NodeCenter.Y;
    LabelObject.Points[0].X:=LabelObject.NodeCenter.X+DX*Cos(Angle)-DY*Sin(Angle);
    LabelObject.Points[0].Y:=LabelObject.NodeCenter.Y+DX*Sin(Angle)+DY*Cos(Angle);
    LabelObject.Rotation:=Rotation;
  end;
  procedure CoordinateLabels(const Position:TDiagramPoint; CommandIndex:Integer);
  const Directions:array[0..7] of string=('above','below','left','right','above left','above right','below left','below right');
  var Entry:TDiagramOption; Text,FontOptions,Direction,SavedStyle:string; P,First,Last,Base,Colon:Integer;
      Distance,Angle:Double; LabelPosition:TDiagramPoint;
  begin
    SavedStyle:=NodeStyle.Text;
    try
      for Entry in DiagramOptions(Model.Text(Model.Commands[CommandIndex].Options),Model.Commands[CommandIndex].Options.First) do begin
        if (Entry.Name<>'label') or not Entry.HasValue then Continue;
        Base:=Entry.ValueRange.First; Text:=Copy(Source,Base+1,Entry.ValueRange.Last-Base);
        P:=1; FontOptions:=ReadTeXGroup(Text,P,'[',']'); SkipTeXSpace(Text,P); First:=P;
        Direction:='above'; Colon:=PosEx(':',Text,P);
        if Colon>0 then begin
          Direction:=Trim(Copy(Text,P,Colon-P));
          if (IndexStr(Direction,Directions)>=0) or Calc.Scalar(Direction,Angle) then First:=Colon+1
          else Direction:='above';
        end;
        while (First<=Length(Text)) and (Text[First] in [' ',#9,#10,#13]) do Inc(First);
        Last:=Length(Text); while (Last>=First) and (Text[Last] in [' ',#9,#10,#13]) do Dec(Last);
        NodeStyle.Clear; ExpandStyle(FontOptions,NodeStyle);
        LabelPosition:=Position;
        Distance:=LengthPoints(Style.Values['label distance'],0,DocumentTextWidth(Context));
        if IndexStr(Direction,Directions)>=0 then begin
          NodeStyle.Values[Direction]:='true';
          if Pos('left',Direction)>0 then LabelPosition.X:=LabelPosition.X-Distance;
          if Pos('right',Direction)>0 then LabelPosition.X:=LabelPosition.X+Distance;
          if Pos('above',Direction)>0 then LabelPosition.Y:=LabelPosition.Y+Distance;
          if Pos('below',Direction)>0 then LabelPosition.Y:=LabelPosition.Y-Distance;
        end else if Calc.Scalar(Direction,Angle) then begin
          NodeStyle.Values['anchor']:='center';
          LabelPosition.X:=LabelPosition.X+Cos(DegToRad(Angle))*(Distance+Scene.FontPoints/2);
          LabelPosition.Y:=LabelPosition.Y+Sin(DegToRad(Angle))*(Distance+Scene.FontPoints/2);
        end;
        CaptionRange.First:=Base+First-1; CaptionRange.Last:=Base+Last;
        LabelAt(Copy(Text,First,Last-First+1),LabelPosition); BindRange;
      end;
    finally NodeStyle.Text:=SavedStyle; end;
  end;
