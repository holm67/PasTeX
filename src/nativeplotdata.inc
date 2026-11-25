{ SPDX-License-Identifier: GPL-3.0-or-later }
  function TablePoints(const Data:string; Item:TPrimitive; Settings:TStrings):Boolean;
  var Lines,Cells:TStringList; Line,Mode,Header,Comments,Value:string;
      Row,I,N,CX,CY,CZ:Integer; Separator,Indicator:Char; Whitespace,FirstRow,HasHeader:Boolean;
      PointValue:TDiagramPoint; Number:Double; Comment:TDiagramOption;
    function SplitRow(const Line:string):Boolean;
    var P,Start,Depth:Integer; Quoted,Boundary:Boolean; C:Char;
    begin
      Result:=False; Cells.Clear; Start:=1; P:=1; Depth:=0; Quoted:=False;
      while P<=Length(Line)+1 do begin
        C:=#0; if P<=Length(Line) then C:=Line[P];
        if (Indicator<>#0) and (C=Indicator) then begin
          Quoted:=not Quoted; Inc(P); Continue;
        end;
        if not Quoted then begin
          if C='{' then Inc(Depth) else if C='}' then begin Dec(Depth); if Depth<0 then Exit; end;
        end;
        Boundary:=(P>Length(Line)) or (not Quoted and (Depth=0) and
          (((not Whitespace) and (C=Separator)) or (Whitespace and (C in [' ',#9]))));
        if Boundary then begin
          if (P>Start) or not Whitespace then begin
            if Cells.Count>=4096 then Exit;
            Value:=Trim(Copy(Line,Start,P-Start));
            if (Indicator<>#0) and (Length(Value)>1) and (Value[1]=Indicator) and
              (Value[Length(Value)]=Indicator) then Value:=Copy(Value,2,Length(Value)-2);
            Cells.Add(PlainLabel(Value));
          end;
          Start:=P+1;
        end;
        Inc(P);
      end;
      Result:=(Depth=0) and not Quoted;
    end;
    function Column(const Key:string; Default:Integer):Integer;
    var Name:string;
    begin
      Name:=PlainLabel(Settings.Values[Key]);
      if Name<>'' then begin
        if HasHeader then Result:=Cells.IndexOf(Name) else Result:=-1;
      end else Result:=StrToIntDef(Settings.Values[Key+' index'],Default);
    end;
    function ReadNumber(Index:Integer; var Value:Double):Boolean;
    begin Result:=(Index>=0) and (Index<Cells.Count) and Numeric(Cells[Index],Value); end;
  begin
    Result:=False; Lines:=TStringList.Create; Cells:=TStringList.Create; Cells.CaseSensitive:=True;
    try
      { Match pgfplotstableshared's column and header modes. In particular an
        empty CSV cell is a column, not whitespace to discard. }
      Mode:=Settings.Values['col sep']; Whitespace:=(Mode='') or (Mode='space'); Separator:=#0;
      case Mode of
        'comma':Separator:=','; 'semicolon':Separator:=';'; 'colon':Separator:=':';
        'tab':Separator:=#9; '&','ampersand':Separator:='&';
      end;
      if not Whitespace and (Separator=#0) then Exit;
      Value:=PlainLabel(Settings.Values['text indicator']); Indicator:=#0;
      if Value<>'' then begin if Length(Value)<>1 then Exit; Indicator:=Value[1]; end;
      Header:=Settings.Values['header'];
      if not ((Header='') or (Header='true') or (Header='false') or (Header='has colnames')) then Exit;
      for Value in ['x expr','y expr','z expr'] do if Settings.Values[Value]<>'' then Exit;
      Mode:=Settings.Values['row sep'];
      if (Mode='\\') or (Mode='crcr') then Lines.Text:=StringReplace(Data,'\\',LineEnding,[rfReplaceAll])
      else if (Mode='') or (Mode='newline') then Lines.Text:=Data else Exit;
      { PGF always ignores # lines; comment chars is a comma-separated list,
        whose commas must not discard CSV rows with an empty first cell. }
      Comments:='%#';
      for Comment in DiagramOptions(PlainLabel(Settings.Values['comment chars'])) do begin
        Value:=PlainLabel(Comment.Name); if Length(Value)<>1 then Exit;
        Comments:=Comments+Value;
      end;
      SetLength(Item.Points,Min(4096,Lines.Count)); N:=0; FirstRow:=True; CX:=0; CY:=1; CZ:=2;
      for Row:=0 to Lines.Count-1 do begin
        Line:=Lines[Row]; if Trim(Line)='' then Continue;
        Value:=TrimLeft(Line); if Pos(Value[1],Comments)>0 then Continue;
        I:=Pos('%',Line); if I>0 then Line:=Copy(Line,1,I-1);
        if not SplitRow(Line) or (Cells.Count=0) then Exit;
        if FirstRow then begin
          HasHeader:=Header='has colnames';
          if (Header='') or (Header='true') then
            for I:=0 to Cells.Count-1 do if (Cells[I]<>'') and not Numeric(Cells[I],Number) then HasHeader:=True;
          CX:=Column('x',0); CY:=Column('y',1); CZ:=Column('z',2);
          if Item.RawBox and (Cells.Count=1) and (Settings.Values['y']='') and
            (Settings.Values['y index']='') then CY:=0;
          FirstRow:=False; if HasHeader then Continue;
        end;
        PointValue:=PointAt(0,0);
        if not Item.RawBox and not ReadNumber(CX,PointValue.X) then Exit;
        if not ReadNumber(CY,PointValue.Y) then Exit;
        if Item.ThreeD and not ReadNumber(CZ,PointValue.Z) then Exit;
        if N>=Length(Item.Points) then Exit;
        Item.Points[N]:=PointValue; Inc(N);
      end;
      SetLength(Item.Points,N); Result:=N>0;
    finally Cells.Free; Lines.Free; end;
  end;
  procedure TableOptions(Values:TStrings);
  var I:Integer; Key:string;
  begin
    for I:=0 to Values.Count-1 do begin
      Key:=Values.Names[I]; if LeftStr(Key,6)='table/' then NodeStyle.Values[Copy(Key,7,MaxInt)]:=Values.ValueFromIndex[I];
    end;
  end;
