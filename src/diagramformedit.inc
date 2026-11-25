{ SPDX-License-Identifier: GPL-3.0-or-later }
procedure TDiagramForm.Selected(Sender:TObject);
var Entry:TDiagramCommand; Code,Data,Value:string; P,I,J,Axis:Integer; Range:TDiagramRange; Cells:TStringList; WasUpdating:Boolean;
begin
  I:=Objects.Row; if (I<0) or (I>=Length(FModel.Commands)) then Exit; FinishLabelEdit;
  if (Sender=Objects) and FElementDirty and (FSelectedCommand>=0) and (FSelectedCommand<>I) then begin
    Objects.Row:=FSelectedCommand; Action(FindComponent('UpdateDiagramElement')); Objects.Row:=I;
  end;
  WasUpdating:=FUpdating; FUpdating:=True;
  try
  FSelectedCommand:=I; FPaint.Invalidate;
  Entry:=FModel.Commands[I]; FCommand:=Entry.Name; FModifier:=Entry.Modifier; Code:=FModel.Text(Entry.Body);
  Options.Text:=FModel.Text(Entry.Options); FPathRows:=nil;
  if (FCommand='addplot') or (FCommand='addplot3') then begin
    if PlotGrid.Columns.Count<>3 then GridSetup(PlotGrid,['x','y','z']);
    Kind.ItemIndex:=4+Ord(FCommand='addplot3'); PlotDimension.ItemIndex:=Ord(FCommand='addplot3');
    PlotInput.ItemIndex:=0; CycleStyles.Checked:=FModifier='+'; P:=1; TableOptions.Text:=''; SkipTeXSpace(Code,P);
    if Copy(Code,P,11)='coordinates' then begin Inc(P,11); PlotInput.ItemIndex:=1; end
    else if Copy(Code,P,5)='table' then begin
      Inc(P,5); PlotInput.ItemIndex:=2;
      if DiagramGroup(Code,P,'[',']',Range) then TableOptions.Text:=Copy(Code,Range.First+1,Range.Last-Range.First);
    end else if Copy(Code,P,1)='(' then PlotInput.ItemIndex:=4;
    Data:=Code;
    if DiagramGroup(Code,P,'{','}',Range) then Data:=Copy(Code,Range.First+1,Range.Last-Range.First);
    Content.Text:=Data;
    if PlotInput.ItemIndex=1 then begin
      PlotGrid.RowCount:=2; for J:=0 to 2 do PlotGrid.Cells[J,1]:=''; P:=1; J:=1; Cells:=TStringList.Create;
      try
        while DiagramGroup(Data,P,'(',')',Range) do begin
          PlotGrid.RowCount:=J+1; Value:=Copy(Data,Range.First+1,Range.Last-Range.First);
          Cells.StrictDelimiter:=True; Cells.Delimiter:=','; Cells.DelimitedText:=Value;
          if Cells.Count>0 then PlotGrid.Cells[0,J]:=Trim(Cells[0]);
          if Cells.Count>1 then PlotGrid.Cells[1,J]:=Trim(Cells[1]);
          if Cells.Count>2 then PlotGrid.Cells[2,J]:=Trim(Cells[2]); Inc(J);
        end;
      finally Cells.Free; end;
    end else if (PlotInput.ItemIndex=2) and (Pos(#10,Data)=0) and
      ((Pos('.dat',Data)>0) or (Pos('.csv',Data)>0) or (Pos('.txt',Data)>0)) then PlotInput.ItemIndex:=3;
    Axis:=FModel.AxisAt(Entry.Source.First);
    for J:=0 to High(FAxisIndices) do if FAxisIndices[J]=Axis then AxisList.ItemIndex:=J;
  end else if FCommand='datavisualization' then begin
    Kind.ItemIndex:=10; FDataBody:=Code; ReloadDataSets(0);
  end else if FCommand='addlegendentry' then begin Kind.ItemIndex:=8; Content.Text:=Code; end
  else if (FCommand='draw') or (FCommand='fill') or (FCommand='filldraw') or (FCommand='path') or (FCommand='node') then begin
    FPathRows:=ParseDiagramPath(Code,FCommand='node'); Kind.ItemIndex:=7;
    if FCommand='node' then Kind.ItemIndex:=3
    else if Length(FPathRows)=2 then begin
      if FPathRows[1].Operation='line' then Kind.ItemIndex:=0
      else if FPathRows[1].Operation='rectangle' then Kind.ItemIndex:=1
      else if FPathRows[1].Operation='circle' then Kind.ItemIndex:=2;
    end;
    if (FCommand='node') and (Length(FPathRows)>0) then begin
      FPathRows[0].Options:=Options.Text; FPathRows[0].Signature:=DiagramPathSignature(FPathRows[0]);
    end;
    LoadPathGrid;
  end else begin Kind.ItemIndex:=9; Content.Text:=Code; end;
  KindChanged(nil);
  if Sender=Objects then begin
    SourceEditor.BlockBegin:=SourceBytePoint(Source,Entry.Source.First);
    SourceEditor.BlockEnd:=SourceBytePoint(Source,Entry.Source.Last);
  end;
  finally FUpdating:=WasUpdating; FElementDirty:=False; end;
  UpdateObjectOrder;
end;
procedure TDiagramForm.UpdateObjectOrder;
begin
  TControl(FindComponent('MoveDiagramObjectUp')).Enabled:=FModel.CommandSibling(Objects.Row,-1)>=0;
  TControl(FindComponent('MoveDiagramObjectDown')).Enabled:=FModel.CommandSibling(Objects.Row,1)>=0;
end;
procedure TDiagramForm.ObjectOrder(Sender:TObject);
var I,J,Direction:Integer; Code:string;
begin
  FinishLabelEdit; Direction:=TComponent(Sender).Tag; SourceEditor.BeginUndoBlock;
  try
    if FElementDirty then Action(FindComponent('UpdateDiagramElement'));
    I:=Objects.Row; J:=FModel.CommandSibling(I,Direction); if J<0 then Exit;
    Code:=FModel.MoveCommand(I,Direction); Objects.Row:=J; ReplaceCode(Code,0,Length(Source)); Selected(Objects);
  finally SourceEditor.EndUndoBlock; end;
end;
procedure TDiagramForm.Action(Sender:TObject);
var Code,Header,Body,Style,Original:string; I,J,A,B,Axis,Operation:Integer;
begin
  FinishLabelEdit; Operation:=TComponent(Sender).Tag; I:=Objects.Row; Original:=Source;
  PathGrid.EditorMode:=False; PlotGrid.EditorMode:=False;
  if Operation=2 then begin
    if I<Length(FModel.Commands) then ReplaceCode('',FModel.Commands[I].Source.First,FModel.Commands[I].Source.Last); Exit;
  end;
  Style:=''; if Trim(Options.Text)<>'' then Style:='['+Options.Text+']';
  if Kind.ItemIndex in [0..3,7] then begin
    ReadPathGrid; Header:='\draw';
    if (Operation=1) and ((FCommand='fill') or (FCommand='filldraw') or (FCommand='path')) then Header:='\'+FCommand;
    if Kind.ItemIndex=3 then begin
      Header:='\node'; if Length(FPathRows)>0 then begin Style:=''; if FPathRows[0].Options<>'' then Style:='['+FPathRows[0].Options+']'; end;
    end;
    Body:=DiagramPathSource(FPathRows,Kind.ItemIndex=3); Code:=Header+Style+' '+Body+';';
  end else if Kind.ItemIndex=8 then Code:='\addlegendentry'+Style+'{'+TrimRight(Content.Text)+'}'
  else if Kind.ItemIndex=10 then begin StoreDataGrid; Code:='\datavisualization'+Style+' '+FDataBody+';'; end
  else if Kind.ItemIndex=9 then Code:='\'+FCommand+FModifier+Style+' '+TrimRight(Content.Text)+';'
  else begin
    Header:='\addplot'; if PlotDimension.ItemIndex=1 then Header:=Header+'3'; if CycleStyles.Checked then Header:=Header+'+';
    Body:=TrimRight(Content.Text);
    case PlotInput.ItemIndex of
      1:begin
        Body:='';
        for J:=1 to PlotGrid.RowCount-1 do if Trim(PlotGrid.Cells[0,J])<>'' then begin
          if Body<>'' then Body:=Body+' ';
          Body:=Body+'('+PlotGrid.Cells[0,J]+','+PlotGrid.Cells[1,J];
          if PlotDimension.ItemIndex=1 then Body:=Body+','+PlotGrid.Cells[2,J]; Body:=Body+')';
        end;
        Body:='coordinates {'+Body+'}';
      end;
      2,3:begin
        if TableOptions.Text<>'' then Body:='table['+TableOptions.Text+'] {'+Body+'}' else Body:='table {'+Body+'}';
      end;
      4:if Copy(Trim(Body),1,1)<>'(' then Body:='('+Body+')';
      else Body:='{'+Body+'}';
    end;
    Code:=Header+Style+' '+Body+';';
  end;
  if Operation=0 then begin
    Axis:=-1; if Kind.ItemIndex in [4..6,8] then Axis:=SelectedAxis;
    if (Axis<0) and (Kind.ItemIndex in [4..6,8]) then begin
      Original:=FModel.InsertAxis('axis','width=7cm,height=5cm,domain=-2:2,y domain=-2:2,samples=17');
      ReplaceCode(Original,0,Length(Source)); Axis:=SelectedAxis;
    end;
    if Axis>=0 then A:=FModel.Environments[Axis].Body.Last
    else begin
      A:=-1;
      for J:=0 to High(FModel.Environments) do if (FModel.Environments[J].Name='tikzpicture') or
        (FModel.Environments[J].Name='circuitikz') then begin A:=FModel.Environments[J].Body.Last; Break; end;
    end;
    if A<0 then Exit; B:=A; Code:=Code+LineEnding;
  end else begin
    if I>=Length(FModel.Commands) then Exit; A:=FModel.Commands[I].Source.First; B:=FModel.Commands[I].Source.Last;
  end;
  ReplaceCode(Code,A,B);
end;
procedure TDiagramForm.PathAction(Sender:TObject);
var I,J,Count,Operation:Integer; Row:TDiagramPathRow;
begin
  Operation:=TComponent(Sender).Tag; ElementChanged(Sender);
  if Operation>=6 then begin
    if Kind.ItemIndex=10 then FDataEdited:=True;
    if Operation=6 then PlotGrid.RowCount:=PlotGrid.RowCount+1
    else if PlotGrid.RowCount>2 then begin
      for I:=PlotGrid.Row to PlotGrid.RowCount-2 do for J:=0 to PlotGrid.ColCount-1 do PlotGrid.Cells[J,I]:=PlotGrid.Cells[J,I+1];
      PlotGrid.RowCount:=PlotGrid.RowCount-1;
    end else for J:=0 to PlotGrid.ColCount-1 do PlotGrid.Cells[J,1]:=''; Exit;
  end;
  ReadPathGrid; I:=EnsureRange(PathGrid.Row-1,0,High(FPathRows)); Count:=Length(FPathRows);
  case Operation of
    0..2:begin
      Row:=Default(TDiagramPathRow);
      case Operation of
        0:begin Row.Operation:='line'; Row.Coordinate:='0,0'; end;
        1:begin Row.Operation:='node'; Row.Text:='Text'; end;
        2:Row.Operation:='cycle';
      end;
      if (Count=1) and (FPathRows[0].Operation='') then begin
        if Operation=0 then Row.Operation:='move'; FPathRows[0]:=Row;
      end else begin
        SetLength(FPathRows,Count+1); for J:=Count downto I+2 do FPathRows[J]:=FPathRows[J-1]; FPathRows[I+1]:=Row;
      end;
    end;
    3:begin for J:=I to Count-2 do FPathRows[J]:=FPathRows[J+1]; SetLength(FPathRows,Max(0,Count-1)); end;
    4:if I>0 then begin Row:=FPathRows[I-1]; FPathRows[I-1]:=FPathRows[I]; FPathRows[I]:=Row; Dec(I); end;
    5:if I<Count-1 then begin Row:=FPathRows[I+1]; FPathRows[I+1]:=FPathRows[I]; FPathRows[I]:=Row; Inc(I); end;
  end;
  LoadPathGrid; PathGrid.Row:=EnsureRange(I+1,1,PathGrid.RowCount-1);
end;
procedure TDiagramForm.EnvironmentSelected(Sender:TObject);
var I,J:Integer; Items:TDiagramOptions;
begin
  I:=Environments.Row-1; if (I<0) or (I>=Length(FModel.Environments)) then Exit;
  Items:=DiagramOptions(FModel.Text(FModel.Environments[I].Options)); EnvironmentOptions.RowCount:=Max(2,Length(Items)+1);
  for J:=1 to EnvironmentOptions.RowCount-1 do begin
    EnvironmentOptions.Cells[0,J]:=''; EnvironmentOptions.Cells[1,J]:=''; EnvironmentOptions.Cells[2,J]:='Flag';
    if J<=Length(Items) then begin
      EnvironmentOptions.Cells[0,J]:=Items[J-1].Name; EnvironmentOptions.Cells[1,J]:=Items[J-1].Value;
      if Items[J-1].HasValue then EnvironmentOptions.Cells[2,J]:='Value';
    end;
  end;
end;
function TDiagramForm.EnvironmentOptionSource:string;
var J,N:Integer; Items:TDiagramOptions;
begin
  EnvironmentOptions.EditorMode:=False; Items:=nil;
  for J:=1 to EnvironmentOptions.RowCount-1 do if Trim(EnvironmentOptions.Cells[0,J])<>'' then begin
    N:=Length(Items); SetLength(Items,N+1); Items[N].Name:=EnvironmentOptions.Cells[0,J]; Items[N].Value:=EnvironmentOptions.Cells[1,J];
    Items[N].HasValue:=(EnvironmentOptions.Cells[2,J]='Value') or (Items[N].Value<>'');
  end;
  Result:=DiagramOptionSource(Items);
end;
procedure TDiagramForm.EnvironmentAction(Sender:TObject);
var I,J,K:Integer; Code:string;
begin
  FinishLabelEdit; I:=Environments.Row-1;
  case TComponent(Sender).Tag of
    0:Code:=FModel.InsertAxis(AxisKind.Text,'width=7cm,height=5cm,xlabel={$x$},ylabel={$y$}');
    1:Code:=FModel.DeleteEnvironment(I);
    2:begin EnvironmentOptions.RowCount:=EnvironmentOptions.RowCount+1; EnvironmentOptions.Row:=EnvironmentOptions.RowCount-1; Exit; end;
    3:begin
      if EnvironmentOptions.RowCount>2 then begin
        for J:=EnvironmentOptions.Row to EnvironmentOptions.RowCount-2 do for K:=0 to 2 do EnvironmentOptions.Cells[K,J]:=EnvironmentOptions.Cells[K,J+1];
        EnvironmentOptions.RowCount:=EnvironmentOptions.RowCount-1;
      end else for K:=0 to 2 do EnvironmentOptions.Cells[K,1]:=''; Exit;
    end;
    4:Code:=FModel.SetEnvironmentOptions(I,EnvironmentOptionSource);
    else Exit;
  end;
  if Code<>Source then ReplaceCode(Code,0,Length(Source));
end;
procedure TDiagramForm.BrowseOptions(Sender:TObject);
var Form:TDiagramOptionsForm; I,Target:Integer; OptionText,Root,Code,Command:string; Context:TDiagramOptionContext;
begin
  FinishLabelEdit; Target:=TComponent(Sender).Tag; OptionText:=Options.Text; I:=Objects.Row;
  Command:=FCommand;
  case Kind.ItemIndex of
    0..2,7:Command:='draw'; 3:Command:='node'; 4..6:Command:='addplot';
    8:Command:='addlegendentry'; 10:Command:='datavisualization';
  end;
  if Target=2 then begin
    OptionText:=SketchOptions.Text; Command:='draw'; if SketchTool.ItemIndex in [3,5] then Command:='node';
  end else if Target=1 then begin
    I:=Environments.Row-1; if (I<0) or (I>=Length(FModel.Environments)) then Exit;
    OptionText:=FModel.Text(FModel.Environments[I].Options); Command:=FModel.Environments[I].Name;
    Code:=EnvironmentOptionSource;
    if Code<>DiagramOptionSource(DiagramOptions(OptionText)) then OptionText:=Code;
  end;
  if Target=1 then Context:=DiagramEnvironmentOptions(Command,Root)
  else Context:=DiagramCommandOptions(Command,Root);
  Form:=TDiagramOptionsForm.Create(Self);
  try
    Form.Caption:=Command+' options';
    Form.Load(OptionText,Root,FPreamble+LineEnding+Source,nil,FDirectory,Context);
    if Form.ShowModal<>mrOK then Exit; OptionText:=Form.OptionsText;
    if Target=2 then begin SketchOptions.Text:=OptionText; Exit; end;
    if Target=1 then Code:=FModel.SetEnvironmentOptions(I,OptionText)
    else begin
      Options.Text:=OptionText;
      if Kind.ItemIndex=3 then begin PathGrid.Cells[2,1]:=OptionText; ReadPathGrid; end;
      if (I<0) or (I>=Length(FModel.Commands)) then Exit;
      Action(FindComponent('UpdateDiagramElement')); Exit;
    end;
    if Code<>Source then ReplaceCode(Code,0,Length(Source));
  finally Form.Free; end;
end;
procedure TDiagramForm.PathOptions(Sender:TObject; ACol,ARow:Integer);
var Form:TDiagramOptionsForm; Command,Root:string; Context:TDiagramOptionContext;
begin
  if (ACol<>2) or (ARow<1) then Exit;
  Command:=PathGrid.Cells[0,ARow]; if (Command<>'node') and (Command<>'to') then Exit;
  Context:=DiagramCommandOptions(Command,Root);
  Form:=TDiagramOptionsForm.Create(Self);
  try
    Form.Caption:=Command+' options'; Form.Load(PathGrid.Cells[ACol,ARow],Root,FPreamble+LineEnding+Source,nil,FDirectory,Context);
    if Form.ShowModal=mrOK then begin
      PathGrid.Cells[ACol,ARow]:=Form.OptionsText; ReadPathGrid;
      if Kind.ItemIndex=3 then Options.Text:=Form.OptionsText;
    end;
  finally Form.Free; end;
end;
