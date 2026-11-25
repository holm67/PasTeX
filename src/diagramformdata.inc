{ SPDX-License-Identifier: GPL-3.0-or-later }
procedure TDiagramForm.StoreDataGrid;
var I,J,N:Integer; Value:string;
begin
  if FDataLoading or (FDataIndex<0) or (FDataIndex>=Length(FDataSets)) then Exit;
  if not PlotGrid.Visible and not FDataEdited then Exit;
  if PlotGrid.Visible then begin
    PlotGrid.EditorMode:=False;
    SetLength(FDataTable.Rows,PlotGrid.RowCount-1);
    for I:=1 to PlotGrid.RowCount-1 do begin
      N:=PlotGrid.ColCount;
      if FDataTable.Columns=N then
        while (N>Length(FDataTable.Rows[I-1])) and (PlotGrid.Cells[N-1,I]='') do Dec(N);
      SetLength(FDataTable.Rows[I-1],N);
      for J:=0 to N-1 do FDataTable.Rows[I-1][J]:=PlotGrid.Cells[J,I];
    end;
    FDataTable.Columns:=PlotGrid.ColCount;
    Value:=FDataTable.Source;
  end else Value:=Content.Text;
  FDataBody:=DiagramReplace(FDataBody,FDataSets[FDataIndex].Content,Value);
  FDataSets:=DiagramDataSets(FDataBody);
  FDataEdited:=False;
end;
procedure TDiagramForm.DataSelected(Sender:TObject);
var I,J,Index:Integer; Code:string;
begin
  if FDataLoading then Exit; Index:=DataSetList.ItemIndex;
  StoreDataGrid; FDataIndex:=Index;
  if (Index<0) or (Index>=Length(FDataSets)) then begin
    FDataLoading:=True;
    try PlotGrid.Visible:=False; Content.Text:=FDataBody; finally FDataLoading:=False; end;
    PlotChanged(nil); Exit;
  end;
  FDataLoading:=True;
  try
    Code:=Copy(FDataBody,FDataSets[Index].Content.First+1,FDataSets[Index].Content.Last-FDataSets[Index].Content.First);
    PlotGrid.Visible:=FDataTable.Load(Code,FDataSets[Index].Options);
    Content.Visible:=not PlotGrid.Visible; Content.Text:=Code;
    if PlotGrid.Visible then begin
      PlotGrid.BeginUpdate;
      try
        PlotGrid.Columns.Clear;
        for I:=1 to FDataTable.Columns do begin
          with PlotGrid.Columns.Add do begin Title.Caption:='Column '+IntToStr(I); MinSize:=55; end;
        end;
        PlotGrid.RowCount:=Max(2,Length(FDataTable.Rows)+1);
        for I:=1 to PlotGrid.RowCount-1 do for J:=0 to PlotGrid.ColCount-1 do begin
          PlotGrid.Cells[J,I]:='';
          if (I<=Length(FDataTable.Rows)) and (J<Length(FDataTable.Rows[I-1])) then
            PlotGrid.Cells[J,I]:=FDataTable.Rows[I-1][J];
        end;
      finally PlotGrid.EndUpdate; end;
    end;
    TControl(FindComponent('UpdateDiagramElement')).Hint:='Apply the edited cells and properties to the selected object';
  finally FDataLoading:=False; end;
  PlotChanged(nil);
end;
procedure TDiagramForm.ReloadDataSets(Index:Integer);
var I:Integer;
begin
  FDataLoading:=True;
  try
    FDataSets:=DiagramDataSets(FDataBody); FDataIndex:=-1; FDataEdited:=False; DataSetList.Items.BeginUpdate;
    try
      DataSetList.Items.Clear;
      for I:=0 to High(FDataSets) do DataSetList.Items.Add(FDataSets[I].Name);
      if Length(FDataSets)>0 then DataSetList.ItemIndex:=EnsureRange(Index,0,High(FDataSets));
    finally DataSetList.Items.EndUpdate; end;
  finally FDataLoading:=False; end;
  DataSelected(nil);
end;
procedure TDiagramForm.ApplyDataBody(Index:Integer);
begin
  ReloadDataSets(Index); ElementChanged(nil); Action(FindComponent('UpdateDiagramElement')); ReloadDataSets(Index);
end;
procedure TDiagramForm.DataSetAction(Sender:TObject);
var Dialog:TDiagramDataForm; Index,N,J:Integer; NewSetName,DataFormat,Data:string; Unique:Boolean;
begin
  if Kind.ItemIndex<>10 then Exit; StoreDataGrid; Index:=DataSetList.ItemIndex;
  if TComponent(Sender).Tag=1 then begin
    if (Index<0) or (Index>=Length(FDataSets)) then Exit;
    FDataBody:=DiagramReplace(FDataBody,FDataSets[Index].Source,''); ApplyDataBody(Max(0,Index-1)); Exit;
  end;
  if Length(FDataSets)>=64 then Exit;
  N:=Length(FDataSets);
  repeat
    Inc(N); NewSetName:='data'+IntToStr(N); Unique:=True;
    for J:=0 to High(FDataSets) do if FDataSets[J].Name=NewSetName then Unique:=False;
  until Unique;
  DataFormat:='table';
  if (Index>=0) and (Index<Length(FDataSets)) then DataFormat:=EnvironmentOption(FDataSets[Index].Options,'format','table');
  Dialog:=TDiagramDataForm.Create(Self);
  try
    Dialog.Caption:='Add data set'; Dialog.Load(DiagramDataTemplate(DataFormat),'set='+NewSetName+',format='+DataFormat,
      FPreamble+LineEnding+Source,FDirectory,SourceEditor.Font,True);
    if Dialog.ShowModal<>mrOK then Exit;
    Data:='data'; if Dialog.OptionsText<>'' then Data:=Data+'['+Dialog.OptionsText+']';
    Index:=Length(FDataSets); FDataBody:=FDataBody+LineEnding+Data+' {'+Dialog.DataText+'}'+LineEnding;
    ApplyDataBody(Index);
  finally Dialog.Free; end;
end;
procedure TDiagramForm.DataAction(Sender:TObject);
var I,J:Integer;
begin
  if not PlotGrid.Visible or (Kind.ItemIndex<>10) then Exit;
  ElementChanged(Sender); FDataEdited:=True;
  PlotGrid.EditorMode:=False;
  if TComponent(Sender).Tag=0 then begin
    if PlotGrid.Columns.Count>=256 then Exit;
    with PlotGrid.Columns.Add do begin Title.Caption:='Column '+IntToStr(PlotGrid.Columns.Count); MinSize:=55; end;
  end else if PlotGrid.Columns.Count>1 then begin
    J:=PlotGrid.Col;
    for I:=J to PlotGrid.ColCount-2 do PlotGrid.Cols[I].Assign(PlotGrid.Cols[I+1]);
    PlotGrid.Columns.Delete(PlotGrid.Columns.Count-1);
  end;
end;
procedure TDiagramForm.DataSetOrder(Sender:TObject);
var I,J:Integer;
begin
  if Kind.ItemIndex<>10 then Exit; StoreDataGrid; I:=DataSetList.ItemIndex; J:=I+TComponent(Sender).Tag;
  if (I<0) or (J<0) or (J>=Length(FDataSets)) then Exit;
  FDataBody:=DiagramSwap(FDataBody,FDataSets[I].Source,FDataSets[J].Source); ApplyDataBody(J);
end;
procedure TDiagramForm.DataProperties(Sender:TObject);
var Dialog:TDiagramDataForm; Index:Integer; Code:string;
begin
  Index:=DataSetList.ItemIndex;
  if (Kind.ItemIndex<>10) or (Index<0) or (Index>=Length(FDataSets)) then Exit;
  StoreDataGrid; Dialog:=TDiagramDataForm.Create(Self);
  try
    with FDataSets[Index] do Code:=Copy(FDataBody,Content.First+1,Content.Last-Content.First);
    Dialog.Load(Code,FDataSets[Index].Options,FPreamble+LineEnding+Source,FDirectory,SourceEditor.Font);
    if Dialog.ShowModal<>mrOK then Exit;
    FDataBody:=ReplaceDiagramData(FDataBody,Index,Dialog.OptionsText,Dialog.DataText);
    ApplyDataBody(Index);
  finally Dialog.Free; end;
end;
