{ SPDX-License-Identifier: GPL-3.0-or-later }
  function CircuitStyle(Values:TStrings):string;
  var I:Integer;
  begin
    Result:=CircuitKind(PlainLabel(Values.Values['shape'])); if Result<>'' then Exit;
    for I:=0 to Values.Count-1 do begin Result:=CircuitKind(Values.Names[I]); if Result<>'' then Exit; end;
  end;
  function CircuitIEC:Boolean;
  begin
    Result:=not Circuitikz;
    if (GlobalStyle.IndexOfName('european')>=0) or (GlobalStyle.IndexOfName('european resistors')>=0) then Result:=True;
    if (GlobalStyle.IndexOfName('american')>=0) or (GlobalStyle.IndexOfName('american resistors')>=0) then Result:=False;
    if GlobalStyle.IndexOfName('circuit logic US')>=0 then Result:=False;
    if GlobalStyle.IndexOfName('circuit logic IEC')>=0 then Result:=True;
  end;
  function CircuitUnit:Double;
  var UnitSize:Double;
  begin
    UnitSize:=7;
    if GlobalStyle.IndexOfName('tiny circuit symbols')>=0 then UnitSize:=5;
    if GlobalStyle.IndexOfName('small circuit symbols')>=0 then UnitSize:=6;
    if GlobalStyle.IndexOfName('large circuit symbols')>=0 then UnitSize:=8;
    if GlobalStyle.IndexOfName('huge circuit symbols')>=0 then UnitSize:=10;
    UnitSize:=LengthPoints(GlobalStyle.Values['circuit symbol unit'],UnitSize*72/72.27,DocumentTextWidth(Context));
    Result:=UnitSize*Scale/(72/2.54);
  end;
  function CircuitComponent(const Name:string; Values:TStrings; out UnitSize:Double; Inputs:Integer=2):TCircuitSymbol;
    procedure Append(Options:TStrings);
    var I,J:Integer; Key:string;
    begin
      for I:=0 to Options.Count-1 do begin
        Key:=CircuitOptionName(Options.Names[I]); J:=CircuitOptions.IndexOfName(Key);
        if J>=0 then CircuitOptions.Delete(J);
        CircuitOptions.Values[Key]:=PlainLabel(Options.ValueFromIndex[I]);
      end;
    end;
  begin
    Result:=Default(TCircuitSymbol); UnitSize:=CircuitUnit;
    if Circuitikz then begin
      CircuitOptions.Clear; Append(CircuitDefaults); Append(GlobalStyle); Append(Values);
      Result:=CircuitikzShape(Name,CircuitOptions);
      if Result.Width>0 then begin
        UnitSize:=LengthPoints(CircuitOptions.Values['bipoles/length'],1.4*72/2.54,DocumentTextWidth(Context))*Scale/(72/2.54);
        Exit;
      end;
    end;
    Result:=CircuitShape(Name,CircuitIEC,Inputs);
  end;
  procedure CircuitDrawing(const Shape:TCircuitSymbol; const Center:TDiagramPoint; Angle,UnitSize:Double; Node:TPrimitive=nil);
  var I,J:Integer; Piece:TPrimitive; C,S,Left,Right,Top,Bottom,Direction,Inset:Double; Pivot,At:TDiagramPoint; Text:string;
    function Position(const P:TDiagramPoint):TDiagramPoint;
    begin Result:=PointAt(Center.X+UnitSize*(P.X*C-P.Y*S),Center.Y+UnitSize*(P.X*S+P.Y*C)); end;
  begin
    C:=Cos(DegToRad(Angle)); S:=Sin(DegToRad(Angle));
    for I:=0 to High(Shape.Paths) do begin
      Piece:=TPrimitive.Create; ApplyStyle(Piece); Piece.Arrow:=False; Piece.StartArrow:=False;
      if Shape.RoundCap then Piece.Cap:=1;
      if (Shape.StrokeScale>0) and not Shape.Paths[I].Upright then Piece.Weight:=Piece.Weight*Shape.StrokeScale;
      Piece.Closed:=Shape.Paths[I].Closed; if Shape.Paths[I].Filled then Piece.Fill:=Piece.Stroke else Piece.Fill:=clNone;
      SetLength(Piece.Points,Length(Shape.Paths[I].Points));
      if Shape.Paths[I].Upright then begin
        Left:=MaxDouble; Right:=-MaxDouble; Top:=MaxDouble; Bottom:=-MaxDouble;
        for J:=0 to High(Piece.Points) do begin
          Left:=Min(Left,Shape.Paths[I].Points[J].X); Right:=Max(Right,Shape.Paths[I].Points[J].X);
          Top:=Min(Top,Shape.Paths[I].Points[J].Y); Bottom:=Max(Bottom,Shape.Paths[I].Points[J].Y);
        end;
        Pivot:=PointAt((Left+Right)/2,(Top+Bottom)/2); At:=Position(Pivot);
        for J:=0 to High(Piece.Points) do Piece.Points[J]:=PointAt(At.X+UnitSize*(Shape.Paths[I].Points[J].X-Pivot.X),
          At.Y+UnitSize*(Shape.Paths[I].Points[J].Y-Pivot.Y));
      end else for J:=0 to High(Piece.Points) do Piece.Points[J]:=Position(Shape.Paths[I].Points[J]);
      Scene.Items.Add(Piece);
    end;
    if Node<>nil then begin
      Node.NodeHalfW:=UnitSize*(Abs(C)*Shape.Width+Abs(S)*Shape.Height)/2;
      Node.NodeHalfH:=UnitSize*(Abs(S)*Shape.Width+Abs(C)*Shape.Height)/2;
      Node.CircuitPorts:=Copy(Shape.Ports);
      for I:=0 to High(Node.CircuitPorts) do Node.CircuitPorts[I].Position:=Position(Node.CircuitPorts[I].Position);
    end;
    if Shape.Text<>'' then begin
      LabelAt(Shape.Text,Center);
      if LabelItem<>nil then begin
        if (Shape.Text<>'A') and (Shape.Text<>'V') and (Shape.Text<>'$\Omega$') then LabelItem.Rotation:=Angle;
        LabelItem.Edit.First:=-1; LabelItem.Edit.Last:=-1;
      end;
    end;
    if Shape.Positive<>'' then for I:=0 to 1 do begin
      Direction:=1; Text:=Shape.Positive;
      if I=1 then begin Direction:=-1; Text:=Shape.Negative; end;
      At:=Position(PointAt(-Direction*Shape.PolarityMargin*Shape.Width/2,0));
      LabelAt(Text,At);
      if LabelItem<>nil then begin
        Inset:=LabelItem.LabelH/2;
        LabelItem.Points[0]:=PointAt(At.X+Direction*C*Inset,At.Y+Direction*S*Inset);
        LabelItem.Rotation:=Angle+90; LabelItem.Edit.First:=-1; LabelItem.Edit.Last:=-1;
      end;
    end;
  end;
  function CircuitNode(Node:TPrimitive):Boolean;
  var Name,Value:string; Shape:TCircuitSymbol; UnitSize,Angle:Double; Inputs,I:Integer;
  begin
    Name:=CircuitStyle(NodeStyle); Result:=Name<>''; if not Result then Exit;
    Inputs:=2; Value:=PlainLabel(NodeStyle.Values['inputs']);
    if Value='' then Value:=PlainLabel(NodeStyle.Values['logic gate inputs']);
    if Value<>'' then begin
      Inputs:=1; if Pos(',',Value)>0 then begin for I:=1 to Length(Value) do if Value[I]=',' then Inc(Inputs); end
      else Inputs:=Length(Value);
    end;
    Shape:=CircuitComponent(Name,NodeStyle,UnitSize,Inputs); Angle:=0;
    if Circuitikz and (Name='ground') then Angle:=-90;
    if NodeStyle.Values['rotate']<>'' then Numeric(NodeStyle.Values['rotate'],Angle);
    if NodeStyle.IndexOfName('point up')>=0 then Angle:=90;
    if NodeStyle.IndexOfName('point down')>=0 then Angle:=-90;
    if NodeStyle.IndexOfName('point left')>=0 then Angle:=180;
    CircuitDrawing(Shape,Node.NodeCenter,Angle,UnitSize,Node);
    if Node.CircuitPorts<>nil then begin
      Node.LabelW:=Max(Node.LabelW,Node.NodeHalfW*2); Node.LabelH:=Max(Node.LabelH,Node.NodeHalfH*2);
    end;
  end;
  procedure CircuitLabel(const Entry:TDiagramOption; const Center:TDiagramPoint; DX,DY,UnitSize,Above,Below:Double);
  var Value,Key,UnitName:string; Range:TDiagramRange; At:TDiagramPoint; Side,Distance:Double;
  begin
    Key:=CircuitOptionName(Entry.Name); Value:=PlainLabel(Entry.Value); if Value='' then Exit; Side:=1;
    if (Pos('_',Key)>0) or (Pos('''',Key)>0) then Side:=-1;
    UnitName:='';
    case Key of
      'ohm':UnitName:='\Omega'; 'volt':UnitName:='\mathrm{V}'; 'ampere':UnitName:='\mathrm{A}';
      'farad':UnitName:='\mathrm{F}'; 'henry':UnitName:='\mathrm{H}'; 'watt':UnitName:='\mathrm{W}';
    end;
    if UnitName<>'' then Value:='$'+Value+'\,'+UnitName+'$';
    At:=PointAt(Center.X-DY*UnitSize*1.8*Side,Center.Y+DX*UnitSize*1.8*Side);
    NodeStyle.Clear; LabelAt(Value,At); if LabelItem=nil then Exit;
    if Circuitikz then begin
      { Circuitikz places labels beyond the component border, with .75ex
        clearance. A fixed center offset overlaps the longer capacitor plates. }
      Distance:=IfThen(Side>0,Above,Below)+0.75*0.43056*Scene.FontPoints*72/72.27+
        (Abs(DY)*LabelItem.LabelW+Abs(DX)*LabelItem.LabelH)/2;
      Distance:=Distance+LengthPoints(CircuitOptions.Values['label distance'],0,DocumentTextWidth(Context));
      LabelItem.Points[0]:=PointAt(Center.X-DY*Distance*Side,Center.Y+DX*Distance*Side);
    end;
    Range:=Entry.ValueRange;
    if (Copy(Source,Range.First+1,1)='{') and (Copy(Source,Range.Last,1)='}') then begin Inc(Range.First); Dec(Range.Last); end;
    LabelItem.Edit.First:=Range.First; LabelItem.Edit.Last:=Range.Last;
    LabelItem.Edit.Text:=Copy(Source,Range.First+1,Range.Last-Range.First);
    LabelItem.Edit.MathLabel:=UnitName<>'';
  end;
  procedure CircuitSegment(const Start,Finish:TDiagramPoint; const Code:string; Base:Integer);
  var Entries,Inner:TDiagramOptions; Entry,LabelEntry:TDiagramOption; Name,Value,RawCode,SavedStyle,ComponentStyle:string;
      Center,EndWire:TDiagramPoint; Shape:TCircuitSymbol; UnitSize,SymbolUnit,Length,DX,DY,Angle,At,Half,Last,Above,Below:Double;
      Count,Index,K,L:Integer;
    function IsLabel(const Entry:TDiagramOption):Boolean;
    var Key:string;
    begin
      Key:=CircuitOptionName(Entry.Name);
      Result:=(Key='l') or (Key='l_') or (Key='l^') or (Key='label') or
        (Pos('info',Key)=1) or (Key='a') or (Key='a_') or (Key='a^') or
        (Key='ohm') or (Key='volt') or (Key='ampere') or (Key='farad') or (Key='henry') or (Key='watt');
    end;
    procedure Wire(const Stop:TDiagramPoint);
    begin Point(Item,Stop); end;
    procedure Resume(const Position:TDiagramPoint);
    begin Item:=TPrimitive.Create; ApplyStyle(Item); Scene.Items.Add(Item); Point(Item,Position); end;
  begin
    RawCode:=Code; SavedStyle:=Style.Text; ReadOptions(RawCode,Style);
    try
    Length:=Hypot(Finish.X-Start.X,Finish.Y-Start.Y); if Length<0.001 then Exit;
    DX:=(Finish.X-Start.X)/Length; DY:=(Finish.Y-Start.Y)/Length; Angle:=RadToDeg(ArcTan2(DY,DX));
    UnitSize:=CircuitUnit; Entries:=DiagramOptions(RawCode,Base); Count:=0;
    for Entry in Entries do if CircuitKind(Entry.Name)<>'' then Inc(Count);
    Index:=0; Last:=0; Above:=0; Below:=0;
    for Entry in Entries do begin
      Name:=CircuitKind(Entry.Name); if Name='' then Continue; Inc(Index);
      if Name='open' then begin Resume(Finish); Continue; end;
      if Name='wire' then Continue;
      Shape:=CircuitComponent(Name,Style,SymbolUnit); Half:=Shape.Width*SymbolUnit/2; At:=Index/(Count+1);
      Value:=PlainLabel(Entry.Value); Inner:=DiagramOptions(Value,Entry.ValueRange.First);
      for LabelEntry in Inner do begin
        if LabelEntry.Name='near start' then At:=0.25 else if LabelEntry.Name='near end' then At:=0.75
        else if LabelEntry.Name='pos' then Numeric(LabelEntry.Value,At);
      end;
      At:=EnsureRange(At,0.05,0.95)*Length;
      Half:=Min(Half,Length*0.4/Max(1,Count)); At:=EnsureRange(At,Last+Half,Max(Last+Half,Length-Half));
      Center:=PointAt(Start.X+DX*At,Start.Y+DY*At);
      Wire(PointAt(Center.X-DX*Half,Center.Y-DY*Half));
      ComponentStyle:=Style.Text; ReadOptions(Value,Style);
      SymbolUnit:=Min(SymbolUnit,2*Half/Max(0.001,Shape.Width));
      try CircuitDrawing(Shape,Center,Angle,SymbolUnit);
      finally Style.Text:=ComponentStyle; end;
      Above:=0; Below:=0;
      for K:=0 to High(Shape.Paths) do for L:=0 to High(Shape.Paths[K].Points) do begin
        Above:=Max(Above,Shape.Paths[K].Points[L].Y*SymbolUnit);
        Below:=Max(Below,-Shape.Paths[K].Points[L].Y*SymbolUnit);
      end;
      EndWire:=PointAt(Center.X+DX*Half,Center.Y+DY*Half); Resume(EndWire); Last:=At+Half;
      for LabelEntry in Inner do if IsLabel(LabelEntry) then CircuitLabel(LabelEntry,Center,DX,DY,UnitSize,Above,Below);
    end;
    Wire(Finish); Center:=PointAt((Start.X+Finish.X)/2,(Start.Y+Finish.Y)/2);
    for Entry in Entries do if IsLabel(Entry) then CircuitLabel(Entry,Center,DX,DY,UnitSize,Above,Below);
    if Pos('*-',RawCode)>0 then CircuitDrawing(CircuitShape('contact'),Start,0,UnitSize);
    if Pos('-*',RawCode)>0 then CircuitDrawing(CircuitShape('contact'),Finish,0,UnitSize);
    if Pos('o-',RawCode)>0 then CircuitDrawing(CircuitShape('open contact'),Start,0,UnitSize);
    if Pos('-o',RawCode)>0 then CircuitDrawing(CircuitShape('open contact'),Finish,0,UnitSize);
    finally Style.Text:=SavedStyle; end;
  end;
