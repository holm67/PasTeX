{ SPDX-License-Identifier: GPL-3.0-or-later }
function TMathEditor.CurrentParagraphStyle:string;
begin LoadRegistry; Result:=ParagraphStyleName(CurrentNode,FRegistry); end;
function TMathEditor.EditingSourcePreview:Boolean;
var N:TMathNode;
begin
  Result:=FFormulaSourceMode; if not Result or not FParagraph then Exit;
  N:=CurrentNode; while (N<>nil) and not IsSourcePreviewNode(N) do N:=N.Parent;
  Result:=(N<>nil) and (MathSourceOffset(N)-Length(N.Prefix)=FSourcePreviewStart);
end;
function TMathEditor.TableNode:TMathNode;
begin Result:=CurrentNode; while (Result<>nil) and (Result.Kind<>mkTable) do Result:=Result.Parent; end;
function TMathEditor.FloatNode:TMathNode;
begin
  Result:=CurrentNode;
  while (Result<>nil) and not ((Result.Kind=mkEnvironment) and FloatEnvironment(Result.Text)) do Result:=Result.Parent;
end;
function TMathEditor.EditingTable:Boolean;
begin Result:=TableNode<>nil; end;
function TMathEditor.EditingTheorem:Boolean;
var N:TMathNode;
begin
  LoadRegistry; N:=CurrentNode;
  while N<>nil do begin
    if (N.Kind=mkEnvironment) and ((N.Text='proof') or FRegistry.IsTheorem(N.Text)) then Exit(True);
    N:=N.Parent;
  end;
  Result:=False;
end;
function TMathEditor.EditingFigure:Boolean;
var N:TMathNode;
begin
  N:=CurrentNode;
  while N<>nil do begin if IsFigureNode(N) then Exit(True); N:=N.Parent; end;
  Result:=False;
end;
function TMathEditor.EnvironmentNode(const EnvironmentName:string):TMathNode;
var N:TMathNode;
    Environment:string;
begin
  Result:=nil; N:=CurrentNode;
  while N<>nil do begin
    Environment:=MathEnvironmentName(N);
    if (Environment='') and (N.Kind in [mkEnvironment,mkVerbatim]) then Environment:=N.Text;
    if (Environment<>'') and ((EnvironmentName='') or (Environment=EnvironmentName)) then Exit(N);
    N:=N.Parent;
  end;
end;
function TMathEditor.CurrentEnvironmentName:string;
var N:TMathNode;
begin
  Result:=''; N:=EnvironmentNode(''); if N=nil then Exit;
  Result:=MathEnvironmentName(N);
  if (Result='') and (N.Kind in [mkEnvironment,mkVerbatim]) then Result:=N.Text;
end;
function TMathEditor.CurrentEnvironmentSource(const EnvironmentName:string):string;
var N:TMathNode;
begin Result:=''; N:=EnvironmentNode(EnvironmentName); if N<>nil then Result:=N.TeX; end;
procedure TMathEditor.ReplaceEnvironment(const Value:string; const EnvironmentName:string);
var N:TMathNode; A,Offset,OldLength:Integer;
begin
  N:=EnvironmentNode(EnvironmentName); if N=nil then Exit;
  A:=MathSourceOffset(N)-Length(N.Prefix); OldLength:=Length(N.TeX);
  Offset:=EnsureRange(SourceCaret-A+Length(Value)-OldLength,0,Length(Value));
  Commit(Copy(FSource,1,A)+Value+Copy(FSource,A+OldLength+1,MaxInt),A+Offset);
end;
function TMathEditor.FormatTableSelection(const Command,HTMLColor:string):Boolean;
var N,CellRoot:TMathNode; Model:TTeXTable; TopRow,LeftCol,BottomRow,RightCol,Focus,R,C,A,FirstOffset,LastOffset,LastSize:Integer;
    S,Content,Prefix:string; Styled:Boolean;
begin
  Focus:=FSelectionFocus; if Focus<0 then Focus:=SourceCaret;
  Result:=TableCellSelection(FRoot,FSelectionAnchor,Focus,N,TopRow,LeftCol,BottomRow,RightCol); if not Result then Exit;
  Styled:=TextStyleActive(Command); Model:=TTeXTable.Create;
  try
    if not Model.Load(N.TeX) then Exit;
    Prefix:=''; if Command='@family' then Prefix:=HTMLColor+'{'
    else if Command='@size' then Prefix:=HTMLColor
    else if HTMLColor<>'' then Prefix:='\textcolor[HTML]{'+HTMLColor+'}{'
    else if (Command<>'@all') and (Command<>'\textcolor') and not Styled then Prefix:=Command+'{';
    for R:=TopRow to BottomRow do for C:=LeftCol to Min(RightCol,TTableRow(Model.Rows[R]).Cells.Count-1) do begin
      S:=Model.CellContent(R,C); CellRoot:=ParseParagraph(S,FRegistry);
      try Content:=ProseFragment(CellRoot,S,0,Length(S),Command);
      finally CellRoot.Free; end;
      if (Prefix<>'') and (Trim(Content)<>'') then Content:=Prefix+Content+'}';
      TTableRow(Model.Rows[R]).Cells[C]:=Content;
    end;
    A:=MathSourceOffset(N)-Length(N.Prefix); Model.Source(FirstOffset,TopRow,LeftCol);
    S:=Model.Source(LastOffset,BottomRow,RightCol); LastSize:=Length(Trim(Model.CellContent(BottomRow,RightCol)));
    Commit(Copy(FSource,1,A)+S+Copy(FSource,A+Length(N.TeX)+1,MaxInt),A+LastOffset+LastSize);
    SetSourceSelection(A+FirstOffset,A+LastOffset+LastSize);
  finally Model.Free; end;
end;
function TMathEditor.CurrentTableSource:string;
var N:TMathNode;
begin N:=TableNode; Result:=''; if N<>nil then Result:=N.TeX; end;
function TMathEditor.CurrentFloatSource:string;
var N:TMathNode;
begin N:=FloatNode; Result:=''; if N<>nil then Result:=N.TeX; end;
function FindFigure(Node:TMathNode):TMathNode;
var I:Integer;
begin
  Result:=nil; if Node=nil then Exit;
  if (Node.Kind=mkTextCommand) and ((Pos('\includegraphics',Node.Text)=1) or (Pos('\includepdf',Node.Text)=1)) then Exit(Node);
  for I:=0 to Node.Children.Count-1 do begin Result:=FindFigure(TMathNode(Node.Children[I])); if Result<>nil then Exit; end;
end;
function TMathEditor.CurrentFigureSource:string;
var N:TMathNode;
begin
  Result:=''; N:=CurrentNode; if FindFigure(N)=nil then N:=FloatNode;
  N:=FindFigure(N); if N<>nil then Result:=N.TeX;
end;
function BoxAtCaret(Node:TMathNode):TMathNode;
begin
  Result:=Node; while (Result<>nil) and not IsBoxNode(Result) do Result:=Result.Parent;
end;
function TMathEditor.CurrentBoxSource:string;
var N:TMathNode;
begin N:=BoxAtCaret(CurrentNode); Result:=''; if N<>nil then Result:=N.TeX; end;
procedure TMathEditor.ReplaceBox(const Value:string);
var N:TMathNode; A,Offset:Integer;
begin
  N:=BoxAtCaret(CurrentNode); if N=nil then Exit; A:=MathSourceOffset(N)-Length(N.Prefix);
  Offset:=EnsureRange(SourceCaret-A+Length(Value)-Length(N.TeX),0,Length(Value));
  Commit(Copy(FSource,1,A)+Value+Copy(FSource,A+Length(N.TeX)+1,MaxInt),A+Offset);
end;
procedure TMathEditor.EditBoxSource;
var N:TMathNode; A:Integer;
begin
  N:=BoxAtCaret(CurrentNode); if N=nil then Exit; A:=MathSourceOffset(N)-Length(N.Prefix);
  SetSourceSelection(A,A+Length(N.TeX)); ToggleSelectionSource;
end;
function DiagramNode(Node:TMathNode):TMathNode;
var I:Integer;
begin
  Result:=nil; if Node=nil then Exit;
  if IsDiagramSource(Node.TeX) then Exit(Node);
  for I:=0 to Node.Children.Count-1 do begin Result:=DiagramNode(TMathNode(Node.Children[I])); if Result<>nil then Exit; end;
end;
function TMathEditor.CurrentDiagramSource:string;
var N:TMathNode;
begin
  N:=CurrentNode; while (N<>nil) and not IsDiagramSource(N.TeX) do N:=N.Parent;
  if N=nil then N:=DiagramNode(FloatNode);
  Result:=''; if N<>nil then Result:=N.TeX;
end;
procedure TMathEditor.ReplaceDiagram(const Value:string);
var N:TMathNode; A:Integer;
begin
  N:=CurrentNode; while (N<>nil) and not IsDiagramSource(N.TeX) do N:=N.Parent;
  if N=nil then N:=DiagramNode(FloatNode); if N=nil then Exit;
  A:=MathSourceOffset(N)-Length(N.Prefix);
  Commit(Copy(FSource,1,A)+Value+Copy(FSource,A+Length(N.TeX)+1,MaxInt),A);
end;
procedure TMathEditor.GetSourceSelection(out Anchor,Focus:Integer);
var A,B:Integer; N:TMathNode; Ranges:TSourceRanges;
begin
  Focus:=SourceCaret; if FSelectionFocus>=0 then Focus:=FSelectionFocus;
  Anchor:=FSelectionAnchor; if Anchor<0 then Anchor:=Focus;
  if SelectionRange(A,B) then begin
    if SelectingTableCells then begin Ranges:=SelectedSourceRanges; A:=Ranges[0].Start; B:=Ranges[High(Ranges)].Finish; end;
    if Focus<Anchor then begin Anchor:=B; Focus:=A; end else begin Anchor:=A; Focus:=B; end;
  end else if FSelected then begin
    N:=CurrentNode; if N<>nil then begin Anchor:=MathSourceOffset(N); Focus:=Anchor+Length(N.Text); end;
  end;
end;
function TMathEditor.SelectingTableCells:Boolean;
var N:TMathNode; TopRow,LeftCol,BottomRow,RightCol,Focus:Integer;
begin
  Focus:=FSelectionFocus; if Focus<0 then Focus:=SourceCaret;
  Result:=TableCellSelection(FRoot,FSelectionAnchor,Focus,N,TopRow,LeftCol,BottomRow,RightCol);
end;
function TMathEditor.SelectedSourceRanges:TSourceRanges;
var N:TMathNode; TopRow,LeftCol,BottomRow,RightCol,Focus,A,B:Integer;
begin
  Result:=nil; Focus:=FSelectionFocus; if Focus<0 then Focus:=SourceCaret;
  if TableCellSelection(FRoot,FSelectionAnchor,Focus,N,TopRow,LeftCol,BottomRow,RightCol) then Exit(TableCellSourceRanges(N,TopRow,LeftCol,BottomRow,RightCol));
  if SelectionRange(A,B) then begin SetLength(Result,1); Result[0].Start:=A; Result[0].Finish:=B; end;
end;
function TMathEditor.TableSelectionText:string;
var Ranges:TSourceRanges; I:Integer;
begin
  Result:=''; if not SelectingTableCells then Exit; Ranges:=SelectedSourceRanges;
  for I:=0 to High(Ranges) do begin
    if I>0 then begin
      if Ranges[I].Row<>Ranges[I-1].Row then Result:=Result+LineEnding else Result:=Result+#9;
    end;
    Result:=Result+Trim(Copy(FSource,Ranges[I].Start+1,Ranges[I].Finish-Ranges[I].Start));
  end;
end;
function TMathEditor.ReplaceTableSelection(const Value:string):Boolean;
var N:TMathNode; Model:TTeXTable; TopRow,LeftCol,BottomRow,RightCol,Focus,R,C,A,Offset:Integer; S:string; Lines,Cells:TStringList;
begin
  Focus:=FSelectionFocus; if Focus<0 then Focus:=SourceCaret;
  Result:=TableCellSelection(FRoot,FSelectionAnchor,Focus,N,TopRow,LeftCol,BottomRow,RightCol); if not Result then Exit;
  Model:=TTeXTable.Create; Lines:=TStringList.Create; Cells:=TStringList.Create;
  try
    if not Model.Load(N.TeX) then Exit; Lines.Text:=Value; Cells.Delimiter:=#9; Cells.StrictDelimiter:=True;
    for R:=TopRow to BottomRow do begin
      Cells.Clear; if R-TopRow<Lines.Count then Cells.DelimitedText:=Lines[R-TopRow];
      for C:=LeftCol to RightCol do begin
        while TTableRow(Model.Rows[R]).Cells.Count<=C do TTableRow(Model.Rows[R]).Cells.Add('');
        S:=''; if C-LeftCol<Cells.Count then S:=Cells[C-LeftCol]; TTableRow(Model.Rows[R]).Cells[C]:=S;
      end;
    end;
    A:=MathSourceOffset(N)-Length(N.Prefix); S:=Model.Source(Offset,TopRow,LeftCol);
   Commit(Copy(FSource,1,A)+S+Copy(FSource,A+Length(N.TeX)+1,MaxInt),A+Offset);
  finally Cells.Free; Lines.Free; Model.Free; end;
end;
procedure TMathEditor.InsertBody(const Value:string; CaretOffset:Integer);
var A,B,Advance:Integer; S:string;
begin
  if InMath and ((Pos('\begin{table',Value)>0) or (Pos('\begin{tabular',Value)>0)) then Exit;
  if not SelectionRange(A,B) then begin A:=SourceCaret; B:=A; end;
  S:=ReplaceProseRange(FRoot,FSource,A,B,Value,Advance,False);
  Commit(S,Advance-Length(Value)+EnsureRange(CaretOffset,0,Length(Value)));
end;
function TMathEditor.EditTableBorder(Side,Count:Integer):Boolean;
var N:TMathNode; Model:TTeXTable; A,TopRow,LeftCol,BottomRow,RightCol,Focus,Offset,StartOffset,EndOffset,OwnerRow:Integer; S:string; Selected:Boolean; Span:TTableSpan;
begin
  Result:=False; Focus:=FSelectionFocus; if Focus<0 then Focus:=SourceCaret;
  Selected:=TableCellSelection(FRoot,FSelectionAnchor,Focus,N,TopRow,LeftCol,BottomRow,RightCol);
  if not Selected then N:=TableNode; if N=nil then Exit;
  Model:=TTeXTable.Create;
  try
    if not Model.Load(N.TeX) then Exit; A:=MathSourceOffset(N)-Length(N.Prefix);
    if not Selected then begin
      Model.CellAt(SourceCaret-A,TopRow,LeftCol); Model.CellOwner(TopRow,LeftCol); OwnerRow:=TopRow;
      Span:=Model.CellSpan(TopRow,LeftCol); BottomRow:=TopRow+Span.Rows-1;
      if Span.Rows<0 then begin Inc(TopRow,Span.Rows+1); BottomRow:=OwnerRow; end;
      RightCol:=LeftCol+Span.Columns-1;
    end;
    Model.SetCellBorders(TopRow,LeftCol,BottomRow,RightCol,Side,Count);
    S:=Model.Source(StartOffset,TopRow,LeftCol); Model.Source(EndOffset,BottomRow,RightCol);
    Inc(EndOffset,Length(Trim(Model.CellContent(BottomRow,RightCol)))); Offset:=StartOffset;
    if not Selected then Model.Source(Offset,OwnerRow,LeftCol);
   Commit(Copy(FSource,1,A)+S+Copy(FSource,A+Length(N.TeX)+1,MaxInt),A+Offset);
    if Selected then SetSourceSelection(A+StartOffset,A+EndOffset); Result:=True;
  finally Model.Free; end;
end;
procedure TMathEditor.GetTableActions(out States:TTableActionStates);
var N,SelectedTable:TMathNode; Model:TTeXTable; A,R,C,Focus,TopRow,LeftCol,BottomRow,RightCol,I,Side,Value:Integer;
    Selected,EmptyRow,EmptyCol:Boolean; Span:TTableSpan;
begin
  FillChar(States,SizeOf(States),0); N:=TableNode; if N=nil then Exit;
  Model:=TTeXTable.Create;
  try
    if not Model.Load(N.TeX) then Exit; A:=MathSourceOffset(N)-Length(N.Prefix);
    Model.CellAt(SourceCaret-A,R,C); Model.CellOwner(R,C);
    if TTableRow(Model.Rows[R]).Caption then Exit;
    Focus:=FSelectionFocus; if Focus<0 then Focus:=SourceCaret;
    Selected:=TableCellSelection(FRoot,FSelectionAnchor,Focus,SelectedTable,TopRow,LeftCol,BottomRow,RightCol);
    EmptyRow:=True; EmptyCol:=True;
    for I:=0 to Model.Columns.Count-1 do EmptyRow:=EmptyRow and (Trim(Model.CellContent(R,I))='');
    for I:=0 to Model.Rows.Count-1 do EmptyCol:=EmptyCol and (Trim(Model.CellContent(I,C))='');
    States[0]:=Model.Rows.Count<100; States[1]:=States[0]; States[8]:=States[0];
    States[3]:=Model.Columns.Count<100; States[4]:=States[3]; States[9]:=States[3];
    States[2]:=(Model.Rows.Count>1) or not EmptyRow; States[5]:=(Model.Columns.Count>1) or not EmptyCol;
    States[6]:=(R>0) and not TTableRow(Model.Rows[R-1]).Caption and (TTableRow(Model.Rows[R-1]).Section=TTableRow(Model.Rows[R]).Section);
    States[7]:=(R<Model.Rows.Count-1) and not TTableRow(Model.Rows[R+1]).Caption and (TTableRow(Model.Rows[R+1]).Section=TTableRow(Model.Rows[R]).Section);
    States[10]:=C>0; States[11]:=C<Model.Columns.Count-1;
    Span:=Model.CellSpan(R,C); States[13]:=(Model.Rows.Count<100) or (Model.Columns.Count<100) or
      (Span.Columns>1) or (Abs(Span.Rows)>1);
    if not Selected then begin
      TopRow:=R; BottomRow:=R+Span.Rows-1; if Span.Rows<0 then begin TopRow:=R+Span.Rows+1; BottomRow:=R; end;
      LeftCol:=C; RightCol:=C+Span.Columns-1;
    end;
    for Side:=0 to 3 do begin
      if Side<2 then begin
        R:=TopRow; if Side=1 then R:=BottomRow+1;
        for I:=LeftCol to RightCol do begin Value:=Model.HorizontalLine(R,I); States[14+Side]:=States[14+Side] or (Value<>1); States[18+Side]:=States[18+Side] or (Value>0); end;
      end else begin
        C:=LeftCol; if Side=3 then C:=RightCol+1;
        for I:=TopRow to BottomRow do begin Value:=Model.VerticalLine(I,C); States[14+Side]:=States[14+Side] or (Value<>1); States[18+Side]:=States[18+Side] or (Value>0); end;
      end;
    end;
    if Selected then States[12]:=Model.MergeCells(TopRow,LeftCol,BottomRow,RightCol);
  finally Model.Free; end;
end;
function TMathEditor.SplitTableCell(Rows,Columns:Integer; Borders:Boolean):Boolean;
var N:TMathNode; Model:TTeXTable; A,R,C,Offset,FirstRow:Integer; Source:string; Span:TTableSpan;
begin
  Result:=False; N:=TableNode; if N=nil then Exit; Model:=TTeXTable.Create;
  try
    if not Model.Load(N.TeX) then Exit; A:=MathSourceOffset(N)-Length(N.Prefix);
    Model.CellAt(SourceCaret-A,R,C);
    Model.CellOwner(R,C); Span:=Model.CellSpan(R,C); FirstRow:=R;
    if Span.Rows<0 then Inc(FirstRow,Span.Rows+1);
    if not Model.SubdivideCell(R,C,Rows,Columns,Borders) then Exit;
    Source:=Model.Source(Offset,FirstRow,C);
    Commit(Copy(FSource,1,A)+Source+Copy(FSource,A+Length(N.TeX)+1,MaxInt),A+Offset);
    SetSourceCaret(A+Offset); Result:=True;
  finally Model.Free; end;
end;
function TMathEditor.EditTable(Operation:Integer):Boolean;
var N,Table:TMathNode; Model:TTeXTable; A,Row,Col,Offset,TopRow,LeftCol,BottomRow,RightCol,Focus,I:Integer; S:string;
begin
  Result:=False; N:=TableNode; if N=nil then Exit; Model:=TTeXTable.Create;
  try
    if not Model.Load(N.TeX) then Exit;
    A:=MathSourceOffset(N)-Length(N.Prefix); Model.CellAt(SourceCaret-A,Row,Col);
    Focus:=FSelectionFocus; if Focus<0 then Focus:=SourceCaret;
    if Operation=12 then begin
      if not TableCellSelection(FRoot,FSelectionAnchor,Focus,Table,TopRow,LeftCol,BottomRow,RightCol) then Exit;
      if not Model.MergeCells(TopRow,LeftCol,BottomRow,RightCol) then Exit;
      Row:=TopRow; Col:=LeftCol;
    end else if (Operation in [2,5]) and TableCellSelection(FRoot,FSelectionAnchor,Focus,Table,TopRow,LeftCol,BottomRow,RightCol) then begin
      if Operation=2 then for I:=BottomRow downto TopRow do begin Row:=I; Col:=LeftCol; Model.Edit(2,Row,Col); end
      else for I:=RightCol downto LeftCol do begin Col:=I; Row:=TopRow; Model.Edit(5,Row,Col); end;
    end else if not Model.Edit(Operation,Row,Col) then Exit;
    S:=Model.Source(Offset,Row,Col);
   Commit(Copy(FSource,1,A)+S+Copy(FSource,A+Length(N.TeX)+1,MaxInt),A+Offset);
    SetSourceCaret(A+Offset); Result:=True;
  finally Model.Free; end;
end;
procedure TMathEditor.ReplaceTable(const Value:string; Row,Col:Integer);
var N:TMathNode; Model:TTeXTable; A,Offset:Integer; S:string;
begin
  N:=TableNode; if N=nil then Exit; A:=MathSourceOffset(N)-Length(N.Prefix); Model:=TTeXTable.Create;
  try
    if (Row<0) or (Col<0) then begin if Model.Load(N.TeX) then Model.CellAt(SourceCaret-A,Row,Col) else begin Row:=0; Col:=0; end; end;
    S:=Value; Offset:=0; if Model.Load(S) then S:=Model.Source(Offset,Row,Col);
   Commit(Copy(FSource,1,A)+S+Copy(FSource,A+Length(N.TeX)+1,MaxInt),A+Offset);
  finally Model.Free; end;
end;
function TMathEditor.MoveTable(RowDelta,ColDelta:Integer; AtBoundary:Boolean):Boolean;
var N,Row,Cell,Field,Ancestor:TMathNode; R,C,I,J,K,A,B,Offset,Relative,Target,Best,BestCaret,Distance,BestDistance,Base,X:Integer;
    Regions:TDraftRegions; Point:TPoint;
    Order:TTableRowOrder; Model:TTeXTable; RowCount:Integer;
  function TableRow(Index:Integer):TMathNode;
  begin Result:=TMathNode(N.Children[Order[Index]]); end;
  procedure LeaveTable(Direction:Integer);
  var K,Index,OldDocumentIndex,OldActive:Integer; Candidate,Ancestor,OldRoot:TMathNode;
  begin
    if RowDelta<>0 then begin
      { A float caption can follow the table in source while appearing above
        it. Vertical movement must leave through the next visible line. }
      FSelected:=False; FSelectionAnchor:=-1; FSelectionFocus:=-1;
      if MoveVertical(Direction,N) then Exit;
      if Assigned(FBoundary) then begin
        OldRoot:=FRoot; OldDocumentIndex:=FDocumentIndex; OldActive:=FActive;
        FBoundary(Self,Direction,False);
        if (FRoot<>OldRoot) or (FDocumentIndex<>OldDocumentIndex) or (FActive<>OldActive) then Exit;
      end;
      { At the document edge there is no adjacent paragraph. Use the literal
        insertion field outside the table instead of staying in the last cell. }
    end;
    Index:=FActive; K:=Index+Direction;
    while (K>=0) and (K<FFields.Count) do begin
      Candidate:=TMathNode(FFields[K]); Ancestor:=Candidate;
      while (Ancestor<>nil) and (Ancestor<>N) do Ancestor:=Ancestor.Parent;
      if Ancestor=nil then begin
        FActive:=K; FCaret:=0; if Direction<0 then FCaret:=UTF8Length(Candidate.Text);
        FSelected:=False; FSelectionAnchor:=-1; FSelectionFocus:=-1; FVerticalRun:=RowDelta<>0;
        Invalidate; NotifySelection; Exit;
      end;
      Inc(K,Direction);
    end;
    if Assigned(FBoundary) then FBoundary(Self,Direction,False);
  end;
begin
  Result:=False; N:=TableNode; if N=nil then Exit;
  Cell:=CurrentNode; while (Cell<>nil) and (Cell.Kind<>mkTableCell) do Cell:=Cell.Parent;
  if Cell=nil then Exit; Row:=Cell.Parent; R:=N.Children.IndexOf(Row); C:=Row.Children.IndexOf(Cell);
  SetLength(Order,N.Children.Count); for I:=0 to High(Order) do Order[I]:=I;
  if N.Text='longtable' then begin
    Model:=TTeXTable.Create;
    try if Model.Load(N.TeX) then Order:=Model.VisualRows; finally Model.Free; end;
    for I:=0 to High(Order) do if Order[I]=R then begin R:=I; Break; end;
  end;
  RowCount:=Length(Order);
  A:=MathSourceOffset(Cell); B:=A+Length(Cell.TeX)-Length(Cell.Suffix); Offset:=SourceCaret;
  if AtBoundary then begin
    if (ColDelta<0) and (Trim(Copy(FSource,A+1,Max(0,Offset-A)))<>'') then Exit;
    if (ColDelta>0) and (Trim(Copy(FSource,Offset+1,Max(0,B-Offset)))<>'') then Exit;
  end;
  if RowDelta<>0 then begin
    EnsureDraft; Point:=CaretPoint;
    if not FVerticalRun then FVerticalX:=Point.X;
    FVerticalRun:=True;
  end else FVerticalRun:=False;
  Result:=True; Relative:=Max(0,Offset-A);
  repeat
    Inc(R,RowDelta); Inc(C,ColDelta);
    if (R<0) or (R>=RowCount) then begin LeaveTable(IfThen((RowDelta<0) or (ColDelta<0),-1,1)); Exit; end;
    Row:=TableRow(R);
    if ColDelta<>0 then begin
      if C>=Row.Children.Count then begin Inc(R); C:=0; end;
      if C<0 then begin Dec(R); if R>=0 then C:=TableRow(R).Children.Count-1; end;
    end;
    if (R<0) or (R>=RowCount) then begin LeaveTable(IfThen((RowDelta<0) or (ColDelta<0),-1,1)); Exit; end;
    Row:=TableRow(R); C:=EnsureRange(C,0,Row.Children.Count-1); Cell:=TMathNode(Row.Children[C]);
  until not Cell.Hidden;
  A:=MathSourceOffset(Cell); B:=A+Length(Cell.TeX)-Length(Cell.Suffix);
  Target:=A+Min(Relative,B-A); if ColDelta<>0 then begin Target:=A; if AtBoundary and (ColDelta<0) then Target:=B; end;
  Best:=-1; BestCaret:=0; BestDistance:=MaxInt; Base:=0; Regions:=nil;
  if RowDelta<>0 then begin
    Regions:=ScreenRegions;
    for I:=0 to High(Regions) do if Regions[I].ID=Cell.ID then begin Base:=Regions[I].Bounds.Top+Regions[I].Baseline; Break; end;
  end;
  { Choose an editable stop within the destination cell. Source offsets can
    land on a dollar, brace, or macro prefix whose nearest field is another cell. }
  for I:=0 to FFields.Count-1 do begin
    Field:=TMathNode(FFields[I]); Ancestor:=Field; while (Ancestor<>nil) and (Ancestor<>Cell) do Ancestor:=Ancestor.Parent;
    if Ancestor=nil then Continue;
    if RowDelta<>0 then begin
      for J:=0 to High(Regions) do if Regions[J].ID=Field.ID then
        for K:=0 to Regions[J].CharCount do begin
          if (Field.Kind in [mkCommand,mkTextCommand]) and (K<>0) and (K<>Regions[J].CharCount) then Continue;
          X:=Regions[J].Bounds.Left;
          if K<Length(Regions[J].Stops) then Inc(X,Regions[J].Stops[K])
          else Inc(X,Round((Regions[J].Bounds.Right-Regions[J].Bounds.Left)*K/Max(1,Regions[J].CharCount)));
          Distance:=Abs(X-FVerticalX)+4*Abs(Regions[J].Bounds.Top+Regions[J].Baseline-Base);
          if Distance<BestDistance then begin BestDistance:=Distance; Best:=I; BestCaret:=Regions[J].FirstChar+K; end;
        end;
    end else begin
      A:=MathSourceOffset(Field); B:=A+Length(Field.Text); Distance:=Max(A-Target,Max(Target-B,0));
      if Distance<BestDistance then begin
        BestDistance:=Distance; Best:=I; BestCaret:=UTF8Length(Copy(Field.Text,1,EnsureRange(Target-A,0,Length(Field.Text))));
      end;
    end;
  end;
  if Best>=0 then begin FActive:=Best; FCaret:=EnsureRange(BestCaret,0,UTF8Length(CurrentNode.Text)); end;
  FSelected:=False; FSelectionAnchor:=-1; FSelectionFocus:=-1; Invalidate;
  NotifySelection;
end;
procedure TMathEditor.ReplaceFloat(const Value:string);
var N:TMathNode; A:Integer;
begin
  N:=FloatNode; if N=nil then Exit; A:=MathSourceOffset(N)-Length(N.Prefix);
  Commit(Copy(FSource,1,A)+Value+Copy(FSource,A+Length(N.TeX)+1,MaxInt),A+Min(Length(N.Prefix),Length(Value)));
end;
procedure TMathEditor.ReplaceFigure(const Value:string);
var N:TMathNode; A:Integer;
begin
  N:=FindFigure(CurrentNode); if N=nil then N:=FindFigure(FloatNode); if N=nil then Exit;
  A:=MathSourceOffset(N)-Length(N.Prefix);
  Commit(Copy(FSource,1,A)+Value+Copy(FSource,A+Length(N.TeX)+1,MaxInt),A+Length(Value));
end;
