unit TeXTables;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Contnrs, Math, TeXMacros;
const CoveredTableCell=#0;
type
  TTableActionStates=array[0..21] of Boolean;
  TTableSpan=record
    Columns,Rows:Integer;
    Alignment,Width,Vertical,Offset,Content:string;
  end;
  TTableRowOrder=array of Integer;
  TTableRow=class
    Cells:TStringList;
    Starts,Lengths,Borders:array of Integer;
    Leading,Ending:string;
    Start:Integer;
    Section:Integer;
    Caption:Boolean;
    Directives,Color,ColorModel:string;
    constructor Create;
    destructor Destroy; override;
  end;
  TTeXTable=class
  private
    FSpansValid:Boolean;
    FSpans:array of record Row,Col:Integer; Span:TTableSpan; end;
    procedure InvalidateSpans(Sender:TObject);
    function NewRow:TTableRow;
    function CellColumnSpec(Row,Col:Integer):string;
  public
    Rows:TObjectList;
    Columns:TStringList;
    Vertical,Horizontal:array of Integer;
    HorizontalParts:array of array of Integer;
    HorizontalKinds,HorizontalWidths,HorizontalTrims,RuleAbove,RuleBelow,RowGaps:array of string;
    Prefix,Suffix,Environment,TrailingDirectives,WidthSpec:string;
    BodyStart,BodyEnd:Integer;
    HasFirstHead,HasLastFoot:Boolean;
    constructor Create;
    destructor Destroy; override;
    function Load(const Source:string):Boolean;
    procedure Initialize(RowCount,ColumnCount:Integer; const Alignment:string; Lines:Boolean);
    function Source(out CellOffset:Integer; Row,Col:Integer):string;
    procedure CellAt(Offset:Integer; out Row,Col:Integer);
    function Edit(Operation:Integer; var Row,Col:Integer):Boolean;
    procedure ReadColumns(const Spec:string);
    function ColumnSpec:string;
    function CellContent(Row,Col:Integer):string;
    function CellSpan(Row,Col:Integer):TTableSpan;
    function CellOwner(var Row,Col:Integer):Boolean;
    function MergeCells(TopRow,LeftCol,BottomRow,RightCol:Integer):Boolean;
    function SplitCell(Row,Col:Integer):Boolean;
    function SubdivideCell(Row,Col,RowCount,ColumnCount:Integer; Borders:Boolean):Boolean;
    function ColumnAlignment(Col:Integer; Row:Integer=-1):string;
    function ColumnBefore(Col:Integer; Row:Integer=-1):string;
    function ColumnAfter(Col:Integer; Row:Integer=-1):string;
    function BoundaryMaterial(Boundary:Integer; out ReplacePadding:Boolean):string;
    function VerticalLine(Row,Boundary:Integer):Integer;
    function HorizontalLine(Boundary,Col:Integer):Integer;
    procedure SetCellBorders(TopRow,LeftCol,BottomRow,RightCol,Side,Count:Integer);
    procedure SetHorizontalStyle(Boundary,Style:Integer);
    function HorizontalStyle(Boundary:Integer):Integer;
    function VisualRows:TTableRowOrder;
  end;
function ReadTableSpan(const Source:string):TTableSpan;
function TableEnvironment(const Name:string):Boolean;
function FloatEnvironment(const Name:string):Boolean;
function EnvironmentEnd(const Source:string; Start:Integer; const Name:string):Integer;
implementation
function ReadTableSpan(const Source:string):TTableSpan;
var P:Integer; Cmd,Value:string;
begin
  Result:=Default(TTableSpan); Result.Columns:=1; Result.Rows:=1; Result.Content:=Source;
  Value:=Trim(Source); P:=1; Cmd:=ReadTeXCommand(Value,P);
  if Cmd='multicolumn' then begin
    Result.Columns:=EnsureRange(StrToIntDef(ReadTeXGroup(Value,P,'{','}'),1),1,100);
    Result.Alignment:=ReadTeXGroup(Value,P,'{','}'); Result.Content:=ReadTeXGroup(Value,P,'{','}');
    Value:=Trim(Result.Content); P:=1; Cmd:=ReadTeXCommand(Value,P);
  end;
  if Cmd='multirow' then begin
    Result.Vertical:=ReadTeXGroup(Value,P,'[',']');
    Result.Rows:=EnsureRange(StrToIntDef(ReadTeXGroup(Value,P,'{','}'),1),-100,100);
    if Result.Rows=0 then Result.Rows:=1;
    ReadTeXGroup(Value,P,'[',']'); Result.Width:=ReadTeXGroup(Value,P,'{','}');
    Result.Offset:=ReadTeXGroup(Value,P,'[',']'); Result.Content:=ReadTeXGroup(Value,P,'{','}');
  end;
end;
function TableEnvironment(const Name:string):Boolean;
begin Result:=(Name='tabular') or (Name='tabular*') or (Name='tabularx') or (Name='longtable'); end;
function FloatEnvironment(const Name:string):Boolean;
begin Result:=(Name='table') or (Name='table*') or (Name='figure') or (Name='figure*') or
  (Name='wrapfigure') or (Name='wraptable'); end;
function EnvironmentEnd(const Source:string; Start:Integer; const Name:string):Integer;
var P,Q,Depth:Integer; Cmd,Env,Ending:string;
begin
  P:=Start; Depth:=0;
  if IsTeXVerbatimEnvironment(Name) then begin
    ReadTeXCommand(Source,P); ReadTeXGroup(Source,P,'{','}');
    Ending:='\end{'+Name+'}'; Q:=Pos(Ending,Copy(Source,P,MaxInt));
    if Q=0 then Exit(Length(Source)+1);
    Exit(P+Q-1);
  end;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) then begin P:=Q; Continue; end;
    Result:=P; Cmd:=ReadTeXCommand(Source,P);
    if (Cmd='begin') or (Cmd='end') then begin
      Env:=ReadTeXGroup(Source,P,'{','}');
      if Env=Name then begin
        if Cmd='begin' then Inc(Depth) else begin Dec(Depth); if Depth=0 then Exit; end;
      end else if (Cmd='begin') and (IsTeXVerbatimEnvironment(Env)) then begin
        Ending:='\end{'+Env+'}'; Q:=Pos(Ending,Copy(Source,P,MaxInt));
        if Q=0 then P:=Length(Source)+1 else Inc(P,Q-1+Length(Ending));
      end;
    end else if Cmd='verb' then begin
      if (P<=Length(Source)) and (Source[P]='*') then Inc(P);
      if P<=Length(Source) then begin Env:=Source[P]; Inc(P); while (P<=Length(Source)) and (Source[P]<>Env) do Inc(P); if P<=Length(Source) then Inc(P); end;
    end;
  end;
  Result:=Length(Source)+1;
end;
constructor TTableRow.Create;
begin inherited Create; Cells:=TStringList.Create; end;
destructor TTableRow.Destroy;
begin Cells.Free; inherited Destroy; end;
constructor TTeXTable.Create;
begin inherited Create; Rows:=TObjectList.Create(True); Columns:=TStringList.Create; Environment:='tabular'; end;
destructor TTeXTable.Destroy;
begin Columns.Free; Rows.Free; inherited Destroy; end;
procedure TTeXTable.ReadColumns(const Spec:string);
var P,A,N,K,J:Integer; C:Char; Count,Value,Pending:string; Nested:TTeXTable;
begin
  Columns.Clear; Vertical:=nil; SetLength(Vertical,1); P:=1; Pending:='';
  while P<=Length(Spec) do begin
    C:=Spec[P]; A:=P; Inc(P);
    if C='|' then Inc(Vertical[High(Vertical)])
    else if C in ['l','c','r','p','m','b','X'] then begin
      if C in ['p','m','b'] then ReadTeXGroup(Spec,P,'{','}');
      Columns.Add(Pending+Copy(Spec,A,P-A)); Pending:=''; SetLength(Vertical,Columns.Count+1);
    end else if C='*' then begin
      Count:=ReadTeXGroup(Spec,P,'{','}'); Value:=ReadTeXGroup(Spec,P,'{','}');
      Nested:=TTeXTable.Create;
      try
        Nested.ReadColumns(Value); N:=EnsureRange(StrToIntDef(Count,1),0,100);
        for K:=1 to N do begin
          for J:=0 to Nested.Columns.Count-1 do begin
            Inc(Vertical[High(Vertical)],Nested.Vertical[J]); Columns.Add(Nested.Columns[J]); SetLength(Vertical,Columns.Count+1);
          end;
          if Length(Nested.Vertical)>0 then Inc(Vertical[High(Vertical)],Nested.Vertical[High(Nested.Vertical)]);
        end;
      finally Nested.Free; end;
    end else if C in ['@','!','>','<'] then begin
      ReadTeXGroup(Spec,P,'{','}'); Value:=Copy(Spec,A,P-A);
      if (C='<') and (Columns.Count>0) then Columns[Columns.Count-1]:=Columns[Columns.Count-1]+Value
      else Pending:=Pending+Value;
    end;
  end;
  if (Pending<>'') and (Columns.Count>0) then Columns[Columns.Count-1]:=Columns[Columns.Count-1]+Pending;
  if Columns.Count=0 then begin Columns.Add('l'); SetLength(Vertical,2); end;
end;
function ColumnPart(const Spec:string; Part:Char):string;
var P,A:Integer; C:Char; Value:string;
begin
  Result:=''; P:=1;
  while P<=Length(Spec) do begin
    C:=Spec[P]; A:=P; Inc(P);
    if C in ['>','<','@','!'] then begin
      Value:=ReadTeXGroup(Spec,P,'{','}'); if C=Part then Result:=Result+Value;
    end else if C in ['l','c','r','p','m','b','X'] then begin
      if C in ['p','m','b'] then ReadTeXGroup(Spec,P,'{','}');
      if Part='a' then Exit(Copy(Spec,A,P-A));
    end;
  end;
end;
function WithoutColumnRules(const Spec:string):string;
var P,A,Depth:Integer;
begin
  Result:=''; P:=1; Depth:=0;
  while P<=Length(Spec) do begin
    A:=P;
    if Spec[P]='\' then begin ReadTeXCommand(Spec,P); Result:=Result+Copy(Spec,A,P-A); Continue; end;
    if Spec[P]='{' then Inc(Depth) else if Spec[P]='}' then Dec(Depth);
    if (Spec[P]<>'|') or (Depth<>0) then Result:=Result+Spec[P];
    Inc(P);
  end;
end;
function TTeXTable.CellColumnSpec(Row,Col:Integer):string;
begin
  Result:=''; if Row>=0 then Result:=CellSpan(Row,Col).Alignment;
  if Result='' then Result:=Columns[Col];
end;
function TTeXTable.ColumnAlignment(Col:Integer; Row:Integer):string;
begin Result:=ColumnPart(CellColumnSpec(Row,Col),'a'); if Result='' then Result:='l'; end;
function TTeXTable.ColumnBefore(Col:Integer; Row:Integer):string;
begin Result:=ColumnPart(CellColumnSpec(Row,Col),'>'); end;
function TTeXTable.ColumnAfter(Col:Integer; Row:Integer):string;
begin Result:=ColumnPart(CellColumnSpec(Row,Col),'<'); end;
function TTeXTable.BoundaryMaterial(Boundary:Integer; out ReplacePadding:Boolean):string;
var P,Col:Integer; Spec,Value:string; C:Char;
begin
  Result:=''; ReplacePadding:=False; Spec:=ColumnSpec; P:=1; Col:=0;
  while P<=Length(Spec) do begin
    C:=Spec[P]; Inc(P);
    if C in ['>','<','@','!'] then begin
      Value:=ReadTeXGroup(Spec,P,'{','}');
      if (Col=Boundary) and (C in ['@','!']) then begin Result:=Result+Value; ReplacePadding:=ReplacePadding or (C='@'); end;
    end else if C in ['l','c','r','p','m','b','X'] then begin
      Inc(Col); if C in ['p','m','b'] then ReadTeXGroup(Spec,P,'{','}');
    end;
  end;
end;
procedure TTeXTable.InvalidateSpans(Sender:TObject);
begin FSpansValid:=False; end;
function TTeXTable.NewRow:TTableRow;
begin Result:=TTableRow.Create; Result.Cells.OnChange:=@InvalidateSpans; FSpansValid:=False; end;
function TTeXTable.ColumnSpec:string;
var I,J:Integer;
begin
  Result:=''; for I:=0 to Columns.Count do begin
    if I<Length(Vertical) then for J:=1 to Vertical[I] do Result:=Result+'|';
    if I<Columns.Count then Result:=Result+Columns[I];
  end;
end;
function TTeXTable.Load(const Source:string):Boolean;
var P,Q,A,Depth,EnvDepth,I,N,Count,Rules,J,K,L,R,SectionStart:Integer; Cmd,Spec,Env,Cell,Value:string; Row,OtherRow:TTableRow; Partial:array of Integer;
  procedure AddCell(Finish:Integer);
  var K,J:Integer; Span:TTableSpan;
  begin
    K:=Row.Cells.Add(Copy(Source,A,Finish-A)); SetLength(Row.Starts,K+1); SetLength(Row.Lengths,K+1);
    Row.Starts[K]:=A-1; Row.Lengths[K]:=Finish-A;
    Span:=ReadTableSpan(Row.Cells[K]);
    for J:=2 to Span.Columns do begin
      K:=Row.Cells.Add(CoveredTableCell); SetLength(Row.Starts,K+1); SetLength(Row.Lengths,K+1);
      Row.Starts[K]:=Finish-1; Row.Lengths[K]:=0;
    end;
    if Row.Cells.Count=Span.Columns then begin K:=1; Row.Caption:=ReadTeXCommand(Trim(Row.Cells[0]),K)='caption'; end;
  end;
  procedure BeginRow;
  var BeginAt,J,Section,EndAt:Integer;
  begin
    Row:=NewRow; Row.Start:=P-1; BeginAt:=P; Rules:=0; Partial:=nil; SetLength(Partial,Columns.Count);
    while P<BodyEnd do begin
      Q:=P; SkipTeXSpace(Source,Q); if Copy(Source,Q,6)='\hline' then begin P:=Q+6; Inc(Rules); end
      else if Copy(Source,Q,9)='\rowcolor' then begin
        P:=Q+9; Row.ColorModel:=ReadTeXGroup(Source,P,'[',']'); Row.Color:=ReadTeXGroup(Source,P,'{','}');
        ReadTeXGroup(Source,P,'[',']'); ReadTeXGroup(Source,P,'[',']');
      end
      else if (Copy(Source,Q,8)='\toprule') or (Copy(Source,Q,8)='\midrule') or (Copy(Source,Q,11)='\bottomrule') then begin
        P:=Q; Cmd:=ReadTeXCommand(Source,P); N:=Rows.Count;
        SetLength(HorizontalKinds,N+1); SetLength(HorizontalWidths,N+1); HorizontalKinds[N]:=Cmd;
        SkipTeXSpace(Source,P); if Copy(Source,P,1)='[' then HorizontalWidths[N]:=ReadTeXGroup(Source,P,'[',']');
        Inc(Rules);
      end
      else if Copy(Source,Q,13)='\addlinespace' then begin
        P:=Q+13; N:=Rows.Count; SetLength(RowGaps,N+1); RowGaps[N]:=ReadTeXGroup(Source,P,'[',']');
        if RowGaps[N]='' then RowGaps[N]:='0.5em';
      end
      else if Copy(Source,Q,12)='\specialrule' then begin
        P:=Q+12; N:=Rows.Count;
        SetLength(HorizontalKinds,N+1); SetLength(HorizontalWidths,N+1); SetLength(RuleAbove,N+1); SetLength(RuleBelow,N+1);
        HorizontalKinds[N]:='specialrule'; HorizontalWidths[N]:=ReadTeXGroup(Source,P,'{','}');
        RuleAbove[N]:=ReadTeXGroup(Source,P,'{','}'); RuleBelow[N]:=ReadTeXGroup(Source,P,'{','}'); Inc(Rules);
      end
      else if Copy(Source,Q,9)='\cmidrule' then begin
        P:=Q+9; SkipTeXSpace(Source,P); N:=Rows.Count;
        SetLength(HorizontalKinds,N+1); SetLength(HorizontalWidths,N+1); SetLength(HorizontalTrims,N+1); HorizontalKinds[N]:='cmidrule';
        if Copy(Source,P,1)='[' then HorizontalWidths[N]:=ReadTeXGroup(Source,P,'[',']');
        SkipTeXSpace(Source,P); if Copy(Source,P,1)='(' then HorizontalTrims[N]:=ReadTeXGroup(Source,P,'(',')');
        Value:=ReadTeXGroup(Source,P,'{','}'); K:=Pos('-',Value);
        L:=Max(1,StrToIntDef(Copy(Value,1,K-1),1)); R:=Min(Columns.Count,StrToIntDef(Copy(Value,K+1,MaxInt),Columns.Count));
        for J:=L-1 to R-1 do Inc(Partial[J]);
      end
      else if Copy(Source,Q,6)='\cline' then begin
        P:=Q+6; Value:=ReadTeXGroup(Source,P,'{','}'); K:=Pos('-',Value);
        L:=Max(1,StrToIntDef(Copy(Value,1,K-1),1)); R:=Min(Columns.Count,StrToIntDef(Copy(Value,K+1,MaxInt),Columns.Count));
        for J:=L-1 to R-1 do Inc(Partial[J]);
      end
      else if Environment='longtable' then begin
        EndAt:=Q; Cmd:=ReadTeXCommand(Source,EndAt); Section:=0;
        case Cmd of 'endfirsthead':Section:=1; 'endhead':Section:=2; 'endfoot':Section:=3; 'endlastfoot':Section:=4; end;
        if Section=0 then Break;
        for J:=SectionStart to Rows.Count-1 do TTableRow(Rows[J]).Section:=Section;
        SectionStart:=Rows.Count; Row.Directives:=Row.Directives+'\'+Cmd+LineEnding; P:=EndAt;
        if Section=1 then HasFirstHead:=True else if Section=4 then HasLastFoot:=True;
      end else Break;
    end;
    Row.Leading:=Copy(Source,BeginAt,P-BeginAt); N:=Rows.Count; SetLength(Horizontal,N+1); Horizontal[N]:=Rules;
    SetLength(HorizontalParts,N+1); SetLength(HorizontalParts[N],Columns.Count);
    for J:=0 to Columns.Count-1 do begin HorizontalParts[N][J]:=-1; if Partial[J]>0 then HorizontalParts[N][J]:=Rules+Partial[J]; end;
    A:=P;
  end;
begin
  InvalidateSpans(nil); Rows.Clear; Horizontal:=nil; HorizontalParts:=nil; HorizontalKinds:=nil; HorizontalWidths:=nil; HorizontalTrims:=nil; RuleAbove:=nil; RuleBelow:=nil; RowGaps:=nil; Result:=False; P:=1;
  SectionStart:=0; HasFirstHead:=False; HasLastFoot:=False; TrailingDirectives:='';
  if ReadTeXCommand(Source,P)<>'begin' then Exit;
  Environment:=ReadTeXGroup(Source,P,'{','}'); if not TableEnvironment(Environment) then Exit;
  WidthSpec:=''; if (Environment='tabular*') or (Environment='tabularx') then WidthSpec:=ReadTeXGroup(Source,P,'{','}');
  SkipTeXSpace(Source,P); if (P<=Length(Source)) and (Source[P]='[') then ReadTeXGroup(Source,P,'[',']');
  SkipTeXSpace(Source,P); if (P>Length(Source)) or (Source[P]<>'{') then Exit;
  Spec:=ReadTeXGroup(Source,P,'{','}'); ReadColumns(Spec);
  Prefix:=Copy(Source,1,P-1); BodyStart:=P-1; BodyEnd:=EnvironmentEnd(Source,1,Environment);
  Suffix:=Copy(Source,BodyEnd,MaxInt); Depth:=0; EnvDepth:=0; BeginRow;
  try
    while P<BodyEnd do begin
      if Source[P]='%' then begin while (P<BodyEnd) and (Source[P]<>#10) do Inc(P); Continue; end;
      if Source[P]='\' then begin
        Q:=P; Cmd:=ReadTeXCommand(Source,P);
        if (Cmd='begin') or (Cmd='end') then begin Env:=ReadTeXGroup(Source,P,'{','}'); if Cmd='begin' then Inc(EnvDepth) else EnvDepth:=Max(0,EnvDepth-1); end
        else if Cmd='verb' then begin
          if (P<BodyEnd) and (Source[P]='*') then Inc(P);
          if P<BodyEnd then begin Env:=Source[P]; Inc(P); while (P<BodyEnd) and (Source[P]<>Env) do Inc(P); if P<BodyEnd then Inc(P); end;
        end
        else if (Cmd='\') and (Depth=0) and (EnvDepth=0) then begin
          AddCell(Q); if (P<BodyEnd) and (Source[P]='*') then Inc(P);
          I:=P; SkipTeXSpace(Source,I); if (I<BodyEnd) and (Source[I]='[') then begin ReadTeXGroup(Source,I,'[',']'); P:=I; end;
          Row.Ending:=Copy(Source,Q,P-Q); Rows.Add(Row); Row:=nil; BeginRow;
        end;
        Continue;
      end;
      if Source[P]='{' then Inc(Depth)
      else if Source[P]='}' then Depth:=Max(0,Depth-1)
      else if (Source[P]='&') and (Depth=0) and (EnvDepth=0) then begin AddCell(P); A:=P+1; end;
      Inc(P);
    end;
    if (Row.Cells.Count>0) or (Trim(Copy(Source,A,BodyEnd-A))<>'') or (Rows.Count=0) then begin
      AddCell(BodyEnd); Rows.Add(Row); Row:=nil; SetLength(Horizontal,Rows.Count+1);
    end else begin TrailingDirectives:=Row.Directives; Suffix:=Row.Leading+Copy(Source,A,BodyEnd-A)+Suffix; end;
    Count:=Columns.Count;
    for I:=0 to Rows.Count-1 do Count:=Max(Count,TTableRow(Rows[I]).Cells.Count);
    while Columns.Count<Count do begin Columns.Add('l'); SetLength(Vertical,Columns.Count+1); end;
    for I:=0 to Rows.Count-1 do begin
      OtherRow:=TTableRow(Rows[I]);
      for J:=0 to OtherRow.Cells.Count-1 do begin
        Cell:=Trim(OtherRow.Cells[J]); Q:=1; if ReadTeXCommand(Cell,Q)<>'multicolumn' then Continue;
        Count:=EnsureRange(StrToIntDef(ReadTeXGroup(Cell,Q,'{','}'),1),1,Columns.Count-J); Spec:=ReadTeXGroup(Cell,Q,'{','}');
        if Length(OtherRow.Borders)=0 then OtherRow.Borders:=Copy(Vertical);
        L:=0; R:=0; K:=1; while (K<=Length(Spec)) and (Spec[K]='|') do begin Inc(L); Inc(K); end;
        K:=Length(Spec); while (K>0) and (Spec[K]='|') do begin Inc(R); Dec(K); end;
        if J<Length(OtherRow.Borders) then OtherRow.Borders[J]:=L;
        for K:=J+1 to J+Count-1 do OtherRow.Borders[K]:=0;
        if J+Count<Length(OtherRow.Borders) then OtherRow.Borders[J+Count]:=R;
      end;
    end;
    Result:=True;
  finally Row.Free; end;
end;
function TTeXTable.VisualRows:TTableRowOrder;
var I,N,Pass,Section:Integer; Visible:Boolean;
begin
  Result:=nil;
  for Pass:=0 to 2 do for I:=0 to Rows.Count-1 do begin
    Section:=TTableRow(Rows[I]).Section;
    Visible:=((Pass=0) and ((Section=1) or ((Section=2) and not HasFirstHead))) or
      ((Pass=1) and (Section=0)) or ((Pass=2) and ((Section=4) or ((Section=3) and not HasLastFoot)));
    if Visible then begin N:=Length(Result); SetLength(Result,N+1); Result[N]:=I; end;
  end;
end;
procedure TTeXTable.Initialize(RowCount,ColumnCount:Integer; const Alignment:string; Lines:Boolean);
var I,J:Integer; Row:TTableRow;
begin
  Environment:='tabular'; HasFirstHead:=False; HasLastFoot:=False; TrailingDirectives:='';
  InvalidateSpans(nil); Rows.Clear; Columns.Clear; HorizontalParts:=nil; HorizontalKinds:=nil; HorizontalWidths:=nil; HorizontalTrims:=nil; RuleAbove:=nil; RuleBelow:=nil; RowGaps:=nil; RowCount:=EnsureRange(RowCount,1,100); ColumnCount:=EnsureRange(ColumnCount,1,100);
  SetLength(Vertical,ColumnCount+1); SetLength(Horizontal,RowCount+1);
  for I:=0 to ColumnCount do Vertical[I]:=Ord(Lines);
  for I:=1 to ColumnCount do Columns.Add(Alignment);
  for I:=0 to RowCount-1 do begin
    Row:=NewRow; for J:=1 to ColumnCount do Row.Cells.Add(' '); Rows.Add(Row); Horizontal[I]:=Ord(Lines);
  end;
  Horizontal[RowCount]:=Ord(Lines); Prefix:='\begin{tabular}{'+ColumnSpec+'}'; Suffix:='\end{tabular}';
end;
function TTeXTable.HorizontalStyle(Boundary:Integer):Integer;
var Col,Count:Integer;
begin
  Result:=0; if (Boundary<0) or (Boundary>=Length(Horizontal)) then Exit;
  Count:=0; for Col:=0 to Columns.Count-1 do Count:=Max(Count,HorizontalLine(Boundary,Col));
  Result:=Count; if (Count=0) or (Boundary>=Length(HorizontalKinds)) then Exit;
  case HorizontalKinds[Boundary] of
    'toprule':Result:=3; 'midrule','specialrule':Result:=4; 'bottomrule':Result:=5; 'cmidrule':Result:=6;
  end;
end;
procedure TTeXTable.SetHorizontalStyle(Boundary,Style:Integer);
const Kinds:array[0..6] of string=('','','','toprule','midrule','bottomrule','cmidrule');
begin
  if (Boundary<0) or (Boundary>=Length(Horizontal)) then Exit;
  Style:=EnsureRange(Style,0,6); SetLength(HorizontalKinds,Length(Horizontal)); SetLength(HorizontalWidths,Length(Horizontal)); SetLength(HorizontalTrims,Length(Horizontal));
  HorizontalKinds[Boundary]:=Kinds[Style]; HorizontalWidths[Boundary]:=''; HorizontalTrims[Boundary]:='';
  if Boundary<Length(RuleAbove) then RuleAbove[Boundary]:='';
  if Boundary<Length(RuleBelow) then RuleBelow[Boundary]:='';
  if Style>=3 then Horizontal[Boundary]:=1 else Horizontal[Boundary]:=Style;
  if Boundary<Length(HorizontalParts) then HorizontalParts[Boundary]:=nil;
end;
procedure TTeXTable.CellAt(Offset:Integer; out Row,Col:Integer);
var I,J,Distance,Best:Integer; R:TTableRow;
begin
  Row:=0; Col:=0; Best:=MaxInt;
  for I:=0 to Rows.Count-1 do begin
    R:=TTableRow(Rows[I]); for J:=0 to High(R.Starts) do begin
      if R.Cells[J]=CoveredTableCell then Continue;
      Distance:=Max(R.Starts[J]-Offset,Max(Offset-R.Starts[J]-R.Lengths[J],0));
      if Distance<Best then begin Best:=Distance; Row:=I; Col:=J; end;
    end;
  end;
  CellOwner(Row,Col);
end;
function TTeXTable.CellSpan(Row,Col:Integer):TTableSpan;
begin
  Result:=ReadTableSpan('');
  if (Row<0) or (Row>=Rows.Count) or (Col<0) or (Col>=TTableRow(Rows[Row]).Cells.Count) then Exit;
  Result:=ReadTableSpan(TTableRow(Rows[Row]).Cells[Col]);
end;
function TTeXTable.CellContent(Row,Col:Integer):string;
begin Result:=CellSpan(Row,Col).Content; if Result=CoveredTableCell then Result:=''; end;
function TTeXTable.CellOwner(var Row,Col:Integer):Boolean;
var R,C,I,N,First,Last:Integer; Span:TTableSpan;
begin
  Result:=False;
  if not FSpansValid then begin
    FSpans:=nil;
    for R:=0 to Rows.Count-1 do for C:=0 to TTableRow(Rows[R]).Cells.Count-1 do begin
      if Pos('\multi',TTableRow(Rows[R]).Cells[C])=0 then Continue;
      Span:=CellSpan(R,C);
      if (Span.Columns=1) and (Abs(Span.Rows)=1) then Continue;
      N:=Length(FSpans); SetLength(FSpans,N+1);
      FSpans[N].Row:=R; FSpans[N].Col:=C; FSpans[N].Span:=Span;
    end;
    FSpansValid:=True;
  end;
  for I:=0 to High(FSpans) do begin
    R:=FSpans[I].Row; C:=FSpans[I].Col; Span:=FSpans[I].Span;
    First:=R; Last:=R+Span.Rows-1;
    if Span.Rows<0 then begin First:=R+Span.Rows+1; Last:=R; end;
    if (Row>=First) and (Row<=Last) and (Col>=C) and (Col<C+Span.Columns) then begin
      if (R=Row) and (C=Col) then Continue;
      if (R<>Row) and (Trim(CellContent(Row,Col))<>'') then Continue;
      Row:=R; Col:=C; Exit(True);
    end;
  end;
end;
function TTeXTable.MergeCells(TopRow,LeftCol,BottomRow,RightCol:Integer):Boolean;
var R,C,A,B:Integer; Span:TTableSpan; Content,Spec,Value:string; Row:TTableRow;
begin
  Result:=False;
  if (TopRow<0) or (LeftCol<0) or (BottomRow>=Rows.Count) or (RightCol>=Columns.Count) or
    (TopRow>BottomRow) or (LeftCol>RightCol) or ((TopRow=BottomRow) and (LeftCol=RightCol)) then Exit;
  Content:='';
  for R:=TopRow to BottomRow do begin
    Row:=TTableRow(Rows[R]); if Row.Caption then Exit;
    while Row.Cells.Count<Columns.Count do Row.Cells.Add('');
    for C:=LeftCol to RightCol do begin
      A:=R; B:=C; CellOwner(A,B); Span:=CellSpan(A,B);
      if (A<TopRow) or (B<LeftCol) or (A+Max(1,Span.Rows)-1>BottomRow) or
        (A+Min(0,Span.Rows+1)<TopRow) or (B+Span.Columns-1>RightCol) then Exit;
      if (A=R) and (B=C) then begin
        Value:=Trim(CellContent(R,C)); if Value<>'' then begin
          if Content<>'' then Content:=Content+' '; Content:=Content+Value;
        end;
      end;
    end;
  end;
  Spec:=StringOfChar('|',VerticalLine(TopRow,LeftCol))+ColumnAlignment(LeftCol)+StringOfChar('|',VerticalLine(TopRow,RightCol+1));
  if BottomRow>TopRow then Content:='\multirow{'+IntToStr(BottomRow-TopRow+1)+'}{*}{'+Content+'}';
  for R:=TopRow to BottomRow do begin
    Row:=TTableRow(Rows[R]); Value:=''; if R=TopRow then Value:=Content;
    if RightCol>LeftCol then Value:='\multicolumn{'+IntToStr(RightCol-LeftCol+1)+'}{'+Spec+'}{'+Value+'}';
    Row.Cells[LeftCol]:=Value;
    for C:=LeftCol+1 to RightCol do Row.Cells[C]:=CoveredTableCell;
    if R<BottomRow then SetCellBorders(R,LeftCol,R,RightCol,1,0);
  end;
  Result:=True;
end;
function TTeXTable.SplitCell(Row,Col:Integer):Boolean;
var R,C,Top,Bottom:Integer; Span:TTableSpan; Item:TTableRow;
begin
  CellOwner(Row,Col); Span:=CellSpan(Row,Col);
  Result:=(Span.Columns>1) or (Abs(Span.Rows)>1); if not Result then Exit;
  Top:=Row; Bottom:=Row+Span.Rows-1;
  if Span.Rows<0 then begin Top:=Row+Span.Rows+1; Bottom:=Row; end;
  for R:=Max(0,Top) to Min(Rows.Count-1,Bottom) do begin
    Item:=TTableRow(Rows[R]);
    for C:=Col to Min(Columns.Count-1,Col+Span.Columns-1) do begin
      while Item.Cells.Count<=C do Item.Cells.Add('');
      if (R=Row) and (C=Col) then Item.Cells[C]:=Span.Content
      else if (Item.Cells[C]=CoveredTableCell) or (Trim(CellContent(R,C))='') then Item.Cells[C]:='';
    end;
  end;
end;
function TTeXTable.SubdivideCell(Row,Col,RowCount,ColumnCount:Integer; Borders:Boolean):Boolean;
var Target,Span:TTableSpan; Model:TTeXTable; R,C,I,J,K,Top,Bottom,OwnerR,OwnerC,RF,CF,NR,NC,Offset:Integer;
    RM,CM:array of Integer; Item,Old:TTableRow; Code,Spec,Content:string;
  function Factor(A,B:Integer):Integer;
  var X,Y,T:Integer;
  begin X:=A; Y:=B; while Y<>0 do begin T:=X mod Y; X:=Y; Y:=T; end; Result:=B div X; end;
  procedure Put(AtRow,AtCol,Height,Width:Integer; const Value,Alignment,Vertical,BoxWidth:string);
  var RR,CC:Integer; Text,Body,Position,Dimension:string;
  begin
    Body:=Value;
    if Height>1 then begin
      Position:=''; if Vertical<>'' then Position:='['+Vertical+']'; Dimension:=BoxWidth; if Dimension='' then Dimension:='*';
      Body:='\multirow'+Position+'{'+IntToStr(Height)+'}{'+Dimension+'}{'+Body+'}';
    end;
    for RR:=AtRow to AtRow+Height-1 do begin
      Text:=''; if RR=AtRow then Text:=Body;
      if Width>1 then Text:='\multicolumn{'+IntToStr(Width)+'}{'+Alignment+'}{'+Text+'}';
      TTableRow(Model.Rows[RR]).Cells[AtCol]:=Text;
      for CC:=AtCol+1 to AtCol+Width-1 do TTableRow(Model.Rows[RR]).Cells[CC]:=CoveredTableCell;
    end;
  end;
begin
  Result:=False;
  if (Row<0) or (Row>=Rows.Count) or (Col<0) or (Col>=Columns.Count) or
    (RowCount<1) or (ColumnCount<1) or (RowCount>20) or (ColumnCount>20) or (RowCount*ColumnCount=1) then Exit;
  CellOwner(Row,Col); if TTableRow(Rows[Row]).Caption then Exit;
  Target:=CellSpan(Row,Col); Top:=Min(Row,Row+Target.Rows+1); Bottom:=Max(Row,Row+Target.Rows-1);
  if Target.Rows>0 then begin Top:=Row; Bottom:=Row+Target.Rows-1; end;
  if (Top<0) or (Bottom>=Rows.Count) or (Col+Target.Columns>Columns.Count) then Exit;
  for R:=Top to Bottom do if TTableRow(Rows[R]).Caption then Exit;
  RF:=Factor(Abs(Target.Rows),RowCount); CF:=Factor(Target.Columns,ColumnCount);
  NR:=Rows.Count+(Bottom-Top+1)*(RF-1); NC:=Columns.Count+Target.Columns*(CF-1);
  if (NR>100) or (NC>100) then Exit;
  SetLength(RM,Rows.Count+1); SetLength(CM,Columns.Count+1);
  for R:=0 to Rows.Count-1 do RM[R+1]:=RM[R]+1+Ord((R>=Top) and (R<=Bottom))*(RF-1);
  for C:=0 to Columns.Count-1 do CM[C+1]:=CM[C]+1+Ord((C>=Col) and (C<Col+Target.Columns))*(CF-1);
  Model:=TTeXTable.Create;
  try
    Model.Initialize(NR,NC,'l',False); Model.Prefix:=Prefix; Model.Suffix:=Suffix; Model.Environment:=Environment;
    Model.WidthSpec:=WidthSpec; Model.TrailingDirectives:=TrailingDirectives;
    Model.HasFirstHead:=HasFirstHead; Model.HasLastFoot:=HasLastFoot;
    for C:=0 to Columns.Count-1 do for J:=CM[C] to CM[C+1]-1 do Model.Columns[J]:=Columns[C];
    for C:=0 to Columns.Count do if C<Length(Vertical) then Model.Vertical[CM[C]]:=Vertical[C];
    SetLength(Model.HorizontalParts,NR+1); SetLength(Model.HorizontalKinds,NR+1);
    SetLength(Model.HorizontalWidths,NR+1); SetLength(Model.HorizontalTrims,NR+1);
    SetLength(Model.RuleAbove,NR+1); SetLength(Model.RuleBelow,NR+1); SetLength(Model.RowGaps,NR+1);
    for R:=0 to NR do begin
      SetLength(Model.HorizontalParts[R],NC); for C:=0 to NC-1 do Model.HorizontalParts[R][C]:=0;
    end;
    for R:=0 to Rows.Count do begin
      for C:=0 to Columns.Count-1 do for J:=CM[C] to CM[C+1]-1 do Model.HorizontalParts[RM[R]][J]:=HorizontalLine(R,C);
      if R<Length(HorizontalKinds) then Model.HorizontalKinds[RM[R]]:=HorizontalKinds[R];
      if R<Length(HorizontalWidths) then Model.HorizontalWidths[RM[R]]:=HorizontalWidths[R];
      if R<Length(HorizontalTrims) then Model.HorizontalTrims[RM[R]]:=HorizontalTrims[R];
      if R<Length(RuleAbove) then Model.RuleAbove[RM[R]]:=RuleAbove[R];
      if R<Length(RuleBelow) then Model.RuleBelow[RM[R]]:=RuleBelow[R];
      if R<Length(RowGaps) then Model.RowGaps[RM[R]]:=RowGaps[R];
    end;
    for R:=0 to Rows.Count-1 do begin
      Old:=TTableRow(Rows[R]);
      for I:=RM[R] to RM[R+1]-1 do begin
        Item:=TTableRow(Model.Rows[I]); Item.Section:=Old.Section; Item.Caption:=Old.Caption;
        Item.Color:=Old.Color; Item.ColorModel:=Old.ColorModel;
        if I=RM[R] then begin Item.Leading:=Old.Leading; Item.Directives:=Old.Directives; end;
        if I=RM[R+1]-1 then Item.Ending:=Old.Ending;
        SetLength(Item.Borders,NC+1);
        for C:=0 to Columns.Count do Item.Borders[CM[C]]:=VerticalLine(R,C);
      end;
      if Old.Caption then begin TTableRow(Model.Rows[RM[R]]).Cells[0]:=Old.Cells[0]; Continue; end;
      for C:=0 to Columns.Count-1 do begin
        OwnerR:=R; OwnerC:=C; if CellOwner(OwnerR,OwnerC) then Continue;
        if (R=Row) and (C=Col) then Continue;
        Span:=CellSpan(R,C); I:=R; K:=R+Span.Rows-1;
        if Span.Rows<0 then begin I:=R+Span.Rows+1; K:=R; end;
        if (I<0) or (K>=Rows.Count) or (C+Span.Columns>Columns.Count) then Exit;
        Spec:=CellColumnSpec(R,C);
        Put(RM[I],CM[C],RM[K+1]-RM[I],CM[C+Span.Columns]-CM[C],Span.Content,Spec,Span.Vertical,Span.Width);
      end;
    end;
    Spec:=CellColumnSpec(Row,Col); Content:=Target.Content;
    NR:=(RM[Bottom+1]-RM[Top]) div RowCount; NC:=(CM[Col+Target.Columns]-CM[Col]) div ColumnCount;
    for R:=0 to RowCount-1 do for C:=0 to ColumnCount-1 do begin
      I:=RM[Top]+R*NR; J:=CM[Col]+C*NC;
      Put(I,J,NR,NC,Content,Spec,Target.Vertical,Target.Width); Content:='';
      if Borders then for K:=0 to 3 do Model.SetCellBorders(I,J,I+NR-1,J+NC-1,K,1);
    end;
    Code:=Model.Source(Offset,RM[Top],CM[Col]); Result:=Load(Code);
  finally Model.Free; end;
end;
function TTeXTable.VerticalLine(Row,Boundary:Integer):Integer;
var R:TTableRow;
begin
  Result:=0; if (Boundary>=0) and (Boundary<Length(Vertical)) then Result:=Vertical[Boundary];
  if (Row<0) or (Row>=Rows.Count) then Exit; R:=TTableRow(Rows[Row]);
  if (Boundary>=0) and (Boundary<Length(R.Borders)) then Result:=R.Borders[Boundary];
end;
function TTeXTable.HorizontalLine(Boundary,Col:Integer):Integer;
begin
  Result:=0; if (Boundary>=0) and (Boundary<Length(Horizontal)) then Result:=Horizontal[Boundary];
  if (Boundary>=0) and (Boundary<Length(HorizontalParts)) and (Col>=0) and (Col<Length(HorizontalParts[Boundary])) and
    (HorizontalParts[Boundary][Col]>=0) then Result:=HorizontalParts[Boundary][Col];
end;
procedure TTeXTable.SetCellBorders(TopRow,LeftCol,BottomRow,RightCol,Side,Count:Integer);
var I,J,Boundary:Integer; R:TTableRow;
begin
  if (Rows.Count=0) or (Columns.Count=0) then Exit;
  TopRow:=EnsureRange(TopRow,0,Rows.Count-1); BottomRow:=EnsureRange(BottomRow,TopRow,Rows.Count-1);
  LeftCol:=EnsureRange(LeftCol,0,Columns.Count-1); RightCol:=EnsureRange(RightCol,LeftCol,Columns.Count-1); Count:=EnsureRange(Count,0,2);
  if Side in [0,1] then begin
    Boundary:=TopRow; if Side=1 then Boundary:=BottomRow+1;
    if Length(HorizontalParts)<Length(Horizontal) then SetLength(HorizontalParts,Length(Horizontal));
    if Length(HorizontalParts[Boundary])<>Columns.Count then begin
      SetLength(HorizontalParts[Boundary],Columns.Count); for J:=0 to Columns.Count-1 do HorizontalParts[Boundary][J]:=-1;
    end;
    for J:=LeftCol to RightCol do HorizontalParts[Boundary][J]:=Count;
  end else if Side in [2,3] then begin
    Boundary:=LeftCol; if Side=3 then Boundary:=RightCol+1;
    for I:=TopRow to BottomRow do begin R:=TTableRow(Rows[I]); if Length(R.Borders)=0 then R.Borders:=Copy(Vertical); R.Borders[Boundary]:=Count; end;
  end;
end;
function TTeXTable.Source(out CellOffset:Integer; Row,Col:Integer):string;
var I,J,K,P,MaxRule,Value:Integer; R:TTableRow; Spec,Kind,Width,TrimRule,Alignment,CellSource:string; Common,Override,FirstCell:Boolean; Span:TTableSpan;
  function RulesAt(Boundary:Integer):Integer;
  var C:Integer;
  begin Result:=0; for C:=0 to Columns.Count-1 do Result:=Max(Result,HorizontalLine(Boundary,C)); end;
  procedure Rules(Boundary:Integer);
  var C,First,Level,Minimum:Integer;
  begin
    Kind:=''; Width:=''; TrimRule:='';
    if (Boundary<Length(RowGaps)) and (RowGaps[Boundary]<>'') then Result:=Result+'\addlinespace['+RowGaps[Boundary]+']'+LineEnding;
    if Boundary<Length(HorizontalKinds) then Kind:=HorizontalKinds[Boundary];
    if (Boundary<Length(HorizontalWidths)) and (HorizontalWidths[Boundary]<>'') then Width:='['+HorizontalWidths[Boundary]+']';
    if (Boundary<Length(HorizontalTrims)) and (HorizontalTrims[Boundary]<>'') then TrimRule:='('+HorizontalTrims[Boundary]+')';
    MaxRule:=RulesAt(Boundary); Minimum:=MaxRule;
    for C:=0 to Columns.Count-1 do Minimum:=Min(Minimum,HorizontalLine(Boundary,C));
    for Level:=1 to Minimum do
      if (Minimum=1) and (Kind<>'') then begin
        if Kind='specialrule' then Result:=Result+'\specialrule{'+HorizontalWidths[Boundary]+'}{'+RuleAbove[Boundary]+'}{'+RuleBelow[Boundary]+'}'+LineEnding
        else if Kind='cmidrule' then Result:=Result+'\cmidrule'+Width+TrimRule+'{1-'+IntToStr(Columns.Count)+'}'+LineEnding
        else Result:=Result+'\'+Kind+Width+LineEnding;
      end else Result:=Result+'\hline'+LineEnding;
    for Level:=Minimum+1 to MaxRule do begin
      C:=0; while C<Columns.Count do begin
        if HorizontalLine(Boundary,C)<Level then begin Inc(C); Continue; end;
        First:=C; while (C<Columns.Count) and (HorizontalLine(Boundary,C)>=Level) do Inc(C);
        if Kind='cmidrule' then Result:=Result+'\cmidrule'+Width+TrimRule+'{'+IntToStr(First+1)+'-'+IntToStr(C)+'}'+LineEnding
        else Result:=Result+'\cline{'+IntToStr(First+1)+'-'+IntToStr(C)+'}'+LineEnding;
      end;
    end;
  end;
begin
  { Promote borders shared by every row into the column specification. Only
    cells that actually differ need a multicolumn wrapper. Repeated clicks
    therefore produce the same source, without nesting redundant commands. }
  for J:=0 to Columns.Count do begin
    Value:=VerticalLine(0,J); Common:=Rows.Count>0;
    for I:=1 to Rows.Count-1 do Common:=Common and (VerticalLine(I,J)=Value);
    if Common then Vertical[J]:=Value;
  end;
  { Keep optional position/width arguments; replace only the column specification. }
  Result:=Prefix; P:=1; ReadTeXCommand(Result,P); ReadTeXGroup(Result,P,'{','}');
  if (Environment='tabular*') or (Environment='tabularx') then ReadTeXGroup(Result,P,'{','}');
  SkipTeXSpace(Result,P); if (P<=Length(Result)) and (Result[P]='[') then ReadTeXGroup(Result,P,'[',']');
  SkipTeXSpace(Result,P); Result:=Copy(Result,1,P-1)+'{'+ColumnSpec+'}'+LineEnding;
  CellOffset:=Length(Result);
  for I:=0 to Rows.Count do begin
    if I<Rows.Count then Result:=Result+TTableRow(Rows[I]).Directives else Result:=Result+TrailingDirectives;
    Rules(I);
    if I=Rows.Count then Break;
    R:=TTableRow(Rows[I]);
    if R.Caption then begin
      if I=Row then CellOffset:=Length(Result);
      Result:=Result+Trim(R.Cells[0])+' \\'+LineEnding; Continue;
    end;
    FirstCell:=True;
    for J:=0 to Columns.Count-1 do begin
      if (J<R.Cells.Count) and (R.Cells[J]=CoveredTableCell) then Continue;
      if not FirstCell then Result:=Result+' & '; FirstCell:=False;
      Span:=CellSpan(I,J);
      if (Span.Columns>1) or (Abs(Span.Rows)>1) then begin
        if (I=Row) and (J=Col) then CellOffset:=Length(Result);
        CellSource:=Trim(R.Cells[J]);
        if Span.Columns>1 then begin
          P:=1; ReadTeXCommand(CellSource,P); ReadTeXGroup(CellSource,P,'{','}'); ReadTeXGroup(CellSource,P,'{','}');
          Spec:=StringOfChar('|',VerticalLine(I,J))+WithoutColumnRules(Span.Alignment)+
            StringOfChar('|',VerticalLine(I,J+Span.Columns));
          CellSource:='\multicolumn{'+IntToStr(Span.Columns)+'}{'+Spec+'}'+Copy(CellSource,P,MaxInt);
        end;
        Result:=Result+CellSource; Continue;
      end;
      Alignment:=Columns[J];
      if J<R.Cells.Count then begin
        CellSource:=Trim(R.Cells[J]); P:=1;
        if (ReadTeXCommand(CellSource,P)='multicolumn') and (ReadTeXGroup(CellSource,P,'{','}')='1') then
          Alignment:=WithoutColumnRules(ReadTeXGroup(CellSource,P,'{','}'));
      end;
      Override:=VerticalLine(I,J)<>Vertical[J];
      if J=Columns.Count-1 then Override:=Override or (VerticalLine(I,J+1)<>Vertical[J+1]);
      Override:=Override or (Alignment<>Columns[J]);
      if Override then begin
        Spec:=''; for K:=1 to VerticalLine(I,J) do Spec:=Spec+'|'; Spec:=Spec+Alignment;
        if J=Columns.Count-1 then for K:=1 to VerticalLine(I,J+1) do Spec:=Spec+'|';
        Result:=Result+'\multicolumn{1}{'+Spec+'}{';
        if (I=Row) and (J=Col) then CellOffset:=Length(Result);
        Result:=Result+Trim(CellContent(I,J))+'}';
      end else begin
        if (I=Row) and (J=Col) then CellOffset:=Length(Result);
        if J<R.Cells.Count then Result:=Result+Trim(CellContent(I,J));
      end;
    end;
    if (I<Rows.Count-1) or (RulesAt(Rows.Count)>0) or (Trim(R.Ending)<>'') then begin
      if Pos('\\',Trim(R.Ending))=1 then Result:=Result+' '+Trim(R.Ending)
      else Result:=Result+' \\';
    end;
    Result:=Result+LineEnding;
  end;
  Result:=Result+'\end{'+Environment+'}';
end;
function TTeXTable.Edit(Operation:Integer; var Row,Col:Integer):Boolean;
var I,Target,J,First,Last:Integer; R:TTableRow; Span:TTableSpan; Affects:Boolean;
  procedure InsertBoundary(Index:Integer; HorizontalAxis:Boolean);
  var K:Integer;
  begin
    if HorizontalAxis then begin
      SetLength(Horizontal,Length(Horizontal)+1); for K:=High(Horizontal) downto Index+1 do Horizontal[K]:=Horizontal[K-1]; Horizontal[Index]:=0;
      SetLength(HorizontalKinds,Length(Horizontal)); SetLength(HorizontalWidths,Length(Horizontal)); SetLength(HorizontalTrims,Length(Horizontal));
      for K:=High(Horizontal) downto Index+1 do begin HorizontalKinds[K]:=HorizontalKinds[K-1]; HorizontalWidths[K]:=HorizontalWidths[K-1]; HorizontalTrims[K]:=HorizontalTrims[K-1]; end;
      HorizontalKinds[Index]:=''; HorizontalWidths[Index]:=''; HorizontalTrims[Index]:='';
      SetLength(RuleAbove,Length(Horizontal)); SetLength(RuleBelow,Length(Horizontal)); SetLength(RowGaps,Length(Horizontal));
      for K:=High(Horizontal) downto Index+1 do begin RuleAbove[K]:=RuleAbove[K-1]; RuleBelow[K]:=RuleBelow[K-1]; RowGaps[K]:=RowGaps[K-1]; end;
      RuleAbove[Index]:=''; RuleBelow[Index]:=''; RowGaps[Index]:='';
      if Length(HorizontalParts)>0 then begin
        SetLength(HorizontalParts,Length(Horizontal)); for K:=High(HorizontalParts) downto Index+1 do HorizontalParts[K]:=HorizontalParts[K-1]; HorizontalParts[Index]:=nil;
      end;
    end else begin
      SetLength(Vertical,Length(Vertical)+1); for K:=High(Vertical) downto Index+1 do Vertical[K]:=Vertical[K-1]; Vertical[Index]:=0;
    end;
  end;
begin
  Result:=True; Row:=EnsureRange(Row,0,Rows.Count-1); Col:=EnsureRange(Col,0,Columns.Count-1);
  for I:=0 to Rows.Count-1 do while TTableRow(Rows[I]).Cells.Count<Columns.Count do TTableRow(Rows[I]).Cells.Add('');
  if Operation in [0..11] then for I:=Rows.Count-1 downto 0 do
    for J:=Columns.Count-1 downto 0 do begin
      Span:=CellSpan(I,J); Affects:=False;
      if (Operation in [0,1,2,6,7,8]) and (Abs(Span.Rows)>1) then begin
        First:=Min(I,I+Span.Rows+1); Last:=Max(I,I+Span.Rows-1);
        case Operation of
          0:Affects:=(Row>First) and (Row<=Last);
          1:Affects:=(Row>=First) and (Row<Last);
          2,8:Affects:=(Row>=First) and (Row<=Last);
          6:Affects:=(Row>=First) and (Row-1<=Last);
          7:Affects:=(Row+1>=First) and (Row<=Last);
        end;
      end else if (Operation in [3,4,5,9,10,11]) and (Span.Columns>1) then begin
        First:=J; Last:=J+Span.Columns-1;
        case Operation of
          3:Affects:=(Col>First) and (Col<=Last);
          4:Affects:=(Col>=First) and (Col<Last);
          5,9:Affects:=(Col>=First) and (Col<=Last);
          10:Affects:=(Col>=First) and (Col-1<=Last);
          11:Affects:=(Col+1>=First) and (Col<=Last);
        end;
      end;
      if Affects then SplitCell(I,J);
    end;
  InvalidateSpans(nil);
  case Operation of
    13:Result:=SplitCell(Row,Col);
    0,1,8:begin
      Target:=Row; if Operation<>0 then Inc(Target);
      R:=NewRow; if Operation=8 then R.Borders:=Copy(TTableRow(Rows[Row]).Borders);
      for I:=0 to Columns.Count-1 do if Operation=8 then R.Cells.Add(TTableRow(Rows[Row]).Cells[I]) else R.Cells.Add('');
      Rows.Insert(Target,R); InsertBoundary(Target,True); Row:=Target;
    end;
    2:begin
      if Rows.Count=1 then begin R:=TTableRow(Rows[0]); for I:=0 to R.Cells.Count-1 do R.Cells[I]:=''; end
      else begin
        SetLength(RuleAbove,Length(Horizontal)); SetLength(RuleBelow,Length(Horizontal)); SetLength(RowGaps,Length(Horizontal));
        for I:=Row to High(Horizontal)-1 do begin RuleAbove[I]:=RuleAbove[I+1]; RuleBelow[I]:=RuleBelow[I+1]; RowGaps[I]:=RowGaps[I+1]; end;
        Rows.Delete(Row); for I:=Row to High(Horizontal)-1 do Horizontal[I]:=Horizontal[I+1]; SetLength(Horizontal,Length(Horizontal)-1);
        if Row<Length(HorizontalKinds) then for I:=Row to High(HorizontalKinds)-1 do begin HorizontalKinds[I]:=HorizontalKinds[I+1]; HorizontalWidths[I]:=HorizontalWidths[I+1]; if I+1<Length(HorizontalTrims) then HorizontalTrims[I]:=HorizontalTrims[I+1]; end;
        SetLength(HorizontalKinds,Length(Horizontal)); SetLength(HorizontalWidths,Length(Horizontal)); SetLength(HorizontalTrims,Length(Horizontal));
        if Length(HorizontalParts)>0 then begin for I:=Row to High(HorizontalParts)-1 do HorizontalParts[I]:=HorizontalParts[I+1]; SetLength(HorizontalParts,Length(Horizontal)); end;
        Row:=Min(Row,Rows.Count-1); end;
    end;
    3,4,9:begin
      Target:=Col; if Operation<>3 then Inc(Target); Columns.Insert(Target,Columns[Col]); InsertBoundary(Target,False);
      for I:=0 to Rows.Count-1 do begin
        R:=TTableRow(Rows[I]); if R.Caption then Continue;
        while R.Cells.Count<Columns.Count-1 do R.Cells.Add('');
        if Operation=9 then R.Cells.Insert(Target,R.Cells[Col]) else R.Cells.Insert(Target,'');
      end;
      for I:=0 to Rows.Count-1 do begin
        R:=TTableRow(Rows[I]); if Length(R.Borders)>0 then begin
          SetLength(R.Borders,Columns.Count+1); for J:=High(R.Borders) downto Target+1 do R.Borders[J]:=R.Borders[J-1]; R.Borders[Target]:=0;
        end;
      end;
      for I:=0 to High(HorizontalParts) do if Length(HorizontalParts[I])>0 then begin
        SetLength(HorizontalParts[I],Columns.Count); for J:=Columns.Count-1 downto Target+1 do HorizontalParts[I][J]:=HorizontalParts[I][J-1]; HorizontalParts[I][Target]:=-1;
      end;
      Col:=Target;
    end;
    5:begin
      if Columns.Count=1 then begin
        for I:=0 to Rows.Count-1 do begin R:=TTableRow(Rows[I]); if not R.Caption then R.Cells[0]:=''; end;
      end
      else begin
        Columns.Delete(Col);
        for I:=0 to Rows.Count-1 do begin
          R:=TTableRow(Rows[I]); if R.Caption then Continue;
          while R.Cells.Count<=Col do R.Cells.Add(''); R.Cells.Delete(Col);
          if Length(R.Borders)>0 then begin for J:=Col to High(R.Borders)-1 do R.Borders[J]:=R.Borders[J+1]; SetLength(R.Borders,Columns.Count+1); end;
        end;
        for I:=0 to High(HorizontalParts) do if Length(HorizontalParts[I])>0 then begin
          for J:=Col to High(HorizontalParts[I])-1 do HorizontalParts[I][J]:=HorizontalParts[I][J+1]; SetLength(HorizontalParts[I],Columns.Count);
        end;
        for I:=Col to High(Vertical)-1 do Vertical[I]:=Vertical[I+1]; SetLength(Vertical,Length(Vertical)-1); Col:=Min(Col,Columns.Count-1);
      end;
    end;
    6,7:begin Target:=Row-1; if Operation=7 then Target:=Row+1; if (Target<0) or (Target>=Rows.Count) then Exit(False); Rows.Exchange(Row,Target); Row:=Target; end;
    10,11:begin
      Target:=Col-1; if Operation=11 then Target:=Col+1; if (Target<0) or (Target>=Columns.Count) then Exit(False);
      Columns.Exchange(Col,Target);
      for I:=0 to Rows.Count-1 do begin
        R:=TTableRow(Rows[I]); if R.Caption then Continue;
        while R.Cells.Count<Columns.Count do R.Cells.Add(''); R.Cells.Exchange(Col,Target);
      end;
      Col:=Target;
    end;
    else Result:=False;
  end;
end;
end.
