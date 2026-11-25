unit MathSelection;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes,SysUtils,Types,Math,Graphics,LazUTF8,MathModel,TeXMacros,ParagraphModel,
  TeXLayout,TeXContext,DraftLayout,PreviewImage,SourceRanges;
function TableCellSelection(Root:TMathNode; Anchor,Focus:Integer; out Table:TMathNode;
  out Top,Left,Bottom,Right:Integer):Boolean;
function TableCellSourceRanges(Table:TMathNode; Top,Left,Bottom,Right:Integer):TSourceRanges;
procedure ReadMathRegions(const Data:string; Page,Width,Height:Integer; Fields:TList; out Regions:TDraftRegions);
procedure MergeMathRegions(Layout:TTeXLayout; Fields:TList; const Source:string; var Regions:TDraftRegions);
procedure AddMathFormulaRegions(Root:TMathNode; Layout:TTeXLayout; Fields:TList; Width,Height:Integer; Paragraph:Boolean; var Regions:TDraftRegions);
procedure NormalizeMathSelection(Root:TMathNode; var A,B:Integer);
function MathDelimiterOffset(Root:TMathNode; const Regions:TDraftRegions; X,Y:Integer; out Offset:Integer):Boolean;
function MathSelectionRects(Root:TMathNode; Fields:TList; const Regions:TDraftRegions; A,B:Integer):TSelectionRects;
type
  TParagraphSelection=class
  private
    FRoot:TMathNode;
    FFields:TList;
    FFieldIndex:TMathFieldIndex;
    FRegions:TDraftRegions;
    FScale:Double;
  public
    constructor Create(const Source,Header,XML,Positions:string; Registry:TMacroRegistry;
      Page,Width,Height,ViewWidth:Integer; Canvas:TCanvas; Context:TTeXContext=nil; const Directory:string='');
    destructor Destroy; override;
    procedure Normalize(var A,B:Integer);
    function HitOffset(X,Y:Integer):Integer;
    function Rects(A,B:Integer):TSelectionRects;
  end;
implementation
uses TeXEnvironmentSelection, TeXTables;
function TableCellSelection(Root:TMathNode; Anchor,Focus:Integer; out Table:TMathNode;
  out Top,Left,Bottom,Right:Integer):Boolean;
var A,B:TMathNode; R1,C1,R2,C2,R,C,X,Y,Before:Integer; Model:TTeXTable; Span:TTableSpan;
  function CellAt(N:TMathNode; Offset:Integer):TMathNode;
  var I,L,R:Integer;
  begin
    Result:=nil; L:=MathSourceOffset(N)-Length(N.Prefix); R:=L+Length(N.TeX);
    if (Offset<L) or (Offset>R) then Exit;
    if (N.Kind=mkTableCell) and (Offset<=R-Length(N.Suffix)) then Exit(N);
    for I:=0 to N.Children.Count-1 do begin Result:=CellAt(TMathNode(N.Children[I]),Offset); if Result<>nil then Exit; end;
  end;
begin
  Result:=False; Table:=nil; Top:=0; Left:=0; Bottom:=0; Right:=0;
  if (Root=nil) or (Anchor<0) or (Focus<0) or (Anchor=Focus) then Exit;
  A:=CellAt(Root,Anchor); B:=CellAt(Root,Focus);
  if (A=nil) or (B=nil) or (A=B) or (A.Parent.Parent<>B.Parent.Parent) then Exit;
  Table:=A.Parent.Parent; if Table.Kind<>mkTable then begin Table:=nil; Exit; end;
  R1:=Table.Children.IndexOf(A.Parent); C1:=A.Parent.Children.IndexOf(A);
  R2:=Table.Children.IndexOf(B.Parent); C2:=B.Parent.Children.IndexOf(B);
  Top:=Min(R1,R2); Left:=Min(C1,C2); Bottom:=Max(R1,R2); Right:=Max(C1,C2); Result:=True;
  Model:=TTeXTable.Create;
  try
    if not Model.Load(Table.TeX) then Exit;
    repeat
      Before:=Top+Left-Bottom-Right;
      for R:=Top to Bottom do for C:=Left to Right do begin
        X:=R; Y:=C; Model.CellOwner(X,Y); Span:=Model.CellSpan(X,Y);
        Top:=Min(Top,Min(X,X+Span.Rows+1)); Bottom:=Max(Bottom,Max(X,X+Span.Rows-1));
        Left:=Min(Left,Y); Right:=Max(Right,Y+Span.Columns-1);
      end;
      Top:=Max(0,Top); Bottom:=Min(Model.Rows.Count-1,Bottom); Right:=Min(Model.Columns.Count-1,Right);
    until Before=Top+Left-Bottom-Right;
  finally Model.Free; end;
end;
function TableCellSourceRanges(Table:TMathNode; Top,Left,Bottom,Right:Integer):TSourceRanges;
var R,C,N,P,A:Integer; Row,Cell:TMathNode; S,Count:string;
begin
  Result:=nil; if Table=nil then Exit;
  for R:=Top to Bottom do begin
    Row:=TMathNode(Table.Children[R]);
    for C:=Left to Min(Right,Row.Children.Count-1) do begin
      Cell:=TMathNode(Row.Children[C]); N:=Length(Result); SetLength(Result,N+1);
      Result[N].Start:=MathSourceOffset(Cell); Result[N].Finish:=Result[N].Start+MathSourceLength(Cell)-Length(Cell.Suffix);
      { A one-cell multicolumn stores local vertical borders. Copy or erase
        its body while preserving that structural wrapper. }
      S:=Copy(Cell.TeX,1,MathSourceLength(Cell)-Length(Cell.Suffix)); P:=1; SkipTeXSpace(S,P);
      if ReadTeXCommand(S,P)='multicolumn' then begin
        Count:=ReadTeXGroup(S,P,'{','}'); ReadTeXGroup(S,P,'{','}'); SkipTeXSpace(S,P); A:=P;
        if (Trim(Count)='1') and (Copy(S,P,1)='{') then begin
          ReadTeXGroup(S,P,'{','}');
          Result[N].Start:=MathSourceOffset(Cell)+A; Result[N].Finish:=MathSourceOffset(Cell)+P-2;
        end;
      end;
      Result[N].Row:=R-Top; Result[N].Col:=C-Left;
    end;
  end;
end;
procedure ReadMathRegions(const Data:string; Page,Width,Height:Integer; Fields:TList; out Regions:TDraftRegions);
const Scale=120/(65536*72.27);
var Lines,Values:TStringList; I,J,N,ID,X,Y,W,H,D:Integer; Index:TMathFieldIndex; Field:TMathNode;
    Starts:array of record ID,Region,Baseline:Integer; end;
begin
  SetLength(Regions,0); Starts:=nil;
  if Data='' then Exit;
  Lines:=TStringList.Create; Values:=TStringList.Create;
  try
    Lines.Text:=Data; Values.StrictDelimiter:=True; Values.Delimiter:='|';
    for I:=0 to Lines.Count-1 do
    begin
      Values.DelimitedText:=Lines[I];
      if Values.Count=7 then
      begin
        if StrToIntDef(Values[0],0)<>Page then Continue;
        Values.Delete(0);
      end;
      if Values.Count<>6 then Continue;
      ID:=StrToIntDef(Trim(Values[0]),-1);
      if (Values[1]='S') or (Values[1]='E') then
      begin
        X:=Round(StrToFloatDef(Values[2],0)*Scale);
        Y:=Height-Round(StrToFloatDef(Values[3],0)*Scale);
        H:=Max(1,Round(StrToFloatDef(Values[4],0)*Scale));
        D:=Max(0,Round(StrToFloatDef(Values[5],0)*Scale));
        if Values[1]='S' then
        begin
          N:=Length(Regions); SetLength(Regions,N+1);
          Regions[N].ID:=ID; Regions[N].Bounds:=Rect(X,Y-H,X+1,Y+D); Regions[N].DefinitionArgument:=-1;
          J:=Length(Starts); SetLength(Starts,J+1);
          Starts[J].ID:=ID; Starts[J].Region:=N; Starts[J].Baseline:=Y;
        end
        else for J:=High(Starts) downto 0 do
          if Starts[J].ID=ID then
          begin
            N:=Starts[J].Region;
            if Abs(Starts[J].Baseline-Y)<=2 then
              Regions[N].Bounds.Right:=Max(Regions[N].Bounds.Left+1,X)
            else
            begin
              { A hyphenated word has a region on each of its end lines. }
              Regions[N].Bounds.Right:=Width-Round(6*120/72.27);
              N:=Length(Regions); SetLength(Regions,N+1);
              Regions[N].ID:=ID; Regions[N].DefinitionArgument:=-1;
              Regions[N].Bounds:=Rect(Round(6*120/72.27),Y-H,X,Y+D);
            end;
            Break;
          end;
        Continue;
      end;
      X:=Round(StrToFloatDef(Values[1],0)*Scale);
      Y:=Height-Round(StrToFloatDef(Values[2],0)*Scale);
      W:=Max(1,Round(StrToFloatDef(Values[3],0)*Scale));
      H:=Max(1,Round(StrToFloatDef(Values[4],0)*Scale));
      D:=Max(0,Round(StrToFloatDef(Values[5],0)*Scale));
      N:=Length(Regions); SetLength(Regions,N+1);
      Regions[N].ID:=ID; Regions[N].Bounds:=Rect(X,Y-H,X+W,Y+D); Regions[N].Baseline:=H; Regions[N].DefinitionArgument:=-1;
    end;
  finally Values.Free; Lines.Free; end;
  Index:=TMathFieldIndex.Create;
  try
    Index.Build(Fields);
    for I:=0 to High(Regions) do begin
      Field:=Index.Find(Regions[I].ID);
      if Field<>nil then Regions[I].CharCount:=UTF8Length(Field.Text);
    end;
  finally Index.Free; end;
end;
procedure MergeMathRegions(Layout:TTeXLayout; Fields:TList; const Source:string; var Regions:TDraftRegions);
var I,J,K,N,Reference,Previous,Closest,Position,Distance,RowStart,RowEnd:Integer; A:TTeXAnchor; Field,Candidate,Child:TMathNode; Found:Boolean;
begin
  { PDF text runs contain every line of a hyphenated word, actual font metrics,
    and source-relative character ranges. Prefer these to strut-sized markers. }
  for I:=0 to High(Layout.Anchors) do
  begin
    A:=Layout.Anchors[I];
    if (I=0) or (Layout.Anchors[I-1].ID<>A.ID) then
      for J:=High(Regions) downto 0 do
        if Regions[J].ID=A.ID then
        begin
          for K:=J to High(Regions)-1 do Regions[K]:=Regions[K+1];
          SetLength(Regions,Length(Regions)-1);
        end;
    N:=Length(Regions); SetLength(Regions,N+1);
    Regions[N].ID:=A.ID; Regions[N].Bounds:=A.Bounds; Regions[N].DefinitionArgument:=-1;
    Regions[N].FirstChar:=A.FirstChar; Regions[N].CharCount:=A.CharCount; Regions[N].Stops:=Copy(A.Stops);
  end;
  { Keep zero-width TeX insertion markers, which do not appear in PDF text. }
  for I:=0 to High(Regions) do
  begin
    Found:=False;
    for J:=0 to High(Layout.Anchors) do if Layout.Anchors[J].ID=Regions[I].ID then Found:=True;
    if Found then Continue;
    for J:=0 to Fields.Count-1 do
    begin
      Field:=TMathNode(Fields[J]); if Field.ID<>Regions[I].ID then Continue;
      A:=Default(TTeXAnchor); A.ID:=Field.ID; A.SourceStart:=MathSourceOffset(Field); A.SourceLength:=Length(Field.Text);
      A.FirstChar:=Regions[I].FirstChar; A.CharCount:=Regions[I].CharCount; A.Stops:=Copy(Regions[I].Stops); A.Bounds:=Regions[I].Bounds;
      A.Text:=Field.Text; A.FontName:='Latin Modern Roman'; A.Style:=[]; A.Color:=clBlack;
      A.FontHeight:=Max(10,A.Bounds.Bottom-A.Bounds.Top); A.Baseline:=Regions[I].Baseline;
      if A.Baseline=0 then A.Baseline:=A.FontHeight*4 div 5;
      N:=Length(Layout.Anchors); SetLength(Layout.Anchors,N+1); Layout.Anchors[N]:=A;
      Break;
    end;
  end;
  for I:=0 to Fields.Count-1 do
  begin
    Field:=TMathNode(Fields[I]);
    if (Field.Kind<>mkText) or (Field.Text<>'') then Continue;
    Found:=False;
    for J:=0 to High(Regions) do if Regions[J].ID=Field.ID then Found:=True;
    if Found then Continue;
    Position:=MathSourceOffset(Field); RowStart:=0; RowEnd:=Length(Source);
    if (Field.Parent<>nil) and (Field.Parent.Kind=mkRow) then
      for J:=0 to Field.Parent.Children.Count-1 do
      begin
        Child:=TMathNode(Field.Parent.Children[J]);
        if (Child.Kind=mkRaw) and (Copy(Child.Text,1,2)='\\') then
          if MathSourceOffset(Child)<Position then RowStart:=MathSourceOffset(Child)+Length(Child.TeX)
          else begin RowEnd:=MathSourceOffset(Child); Break; end;
      end;
    Reference:=-1; Previous:=-1; Closest:=MaxInt;
    for J:=0 to Fields.Count-1 do
    begin
      Candidate:=TMathNode(Fields[J]);
      if (Candidate=Field) or (MathSourceOffset(Candidate)<RowStart) or
         (MathSourceOffset(Candidate)>RowEnd) then Continue;
      for K:=0 to High(Layout.Anchors) do
        if Layout.Anchors[K].ID=Candidate.ID then
        begin
          A:=Layout.Anchors[K];
          if (A.SourceStart+A.SourceLength<=Position) and (A.CharCount>0) then
            if (Previous<0) or (A.SourceStart>Layout.Anchors[Previous].SourceStart) then Previous:=K;
          if Candidate.Parent<>Field.Parent then Continue;
          Distance:=Abs(A.SourceStart-Position);
          if (A.CharCount>0) and (Distance<Closest) then begin Reference:=K; Closest:=Distance; end;
        end;
    end;
    if Reference<0 then Continue;
    A:=Layout.Anchors[Reference];
    if Previous>=0 then A.Bounds.Left:=Layout.Anchors[Previous].Bounds.Right
    else A.Bounds.Left:=Max(0,A.Bounds.Left-3);
    A.Bounds.Right:=A.Bounds.Left+3; A.ID:=Field.ID; A.IsContainer:=False;
    A.SourceStart:=Position; A.SourceLength:=0; A.FirstChar:=0; A.CharCount:=0;
    A.Text:=''; A.Stops:=nil; SetLength(A.Stops,1); A.Stops[0]:=0;
    N:=Length(Layout.Anchors); SetLength(Layout.Anchors,N+1); Layout.Anchors[N]:=A;
    N:=Length(Regions); SetLength(Regions,N+1); Regions[N].ID:=A.ID; Regions[N].Bounds:=A.Bounds; Regions[N].DefinitionArgument:=-1;
    Regions[N].FirstChar:=0; Regions[N].CharCount:=0; Regions[N].Stops:=Copy(A.Stops);
  end;
end;
procedure AddMathFormulaRegions(Root:TMathNode; Layout:TTeXLayout; Fields:TList; Width,Height:Integer; Paragraph:Boolean; var Regions:TDraftRegions);
var Formulas:TList; Index:TMathFieldIndex; Bounds:array of TRect;
    Present:array of Boolean; I,J,K:Integer; P,Owner,Node:TMathNode;
    R:TRect; A:TTeXAnchor; RootText,Text:string;
  procedure Collect(Node:TMathNode);
  var I:Integer;
  begin
    if (Node.Kind=mkFormula) or ((Node=Root) and not Paragraph) then begin Formulas.Add(Node); Exit; end;
    for I:=0 to Node.Children.Count-1 do Collect(TMathNode(Node.Children[I]));
  end;
begin
  Formulas:=TList.Create; Index:=TMathFieldIndex.Create;
  try
    Collect(Root); if Formulas.Count=0 then Exit;
    Index.Build(Fields); SetLength(Bounds,Formulas.Count); SetLength(Present,Formulas.Count);
    { Resolve each region once instead of rescanning every field for every
      formula. Only the outermost formula owns a paragraph container. }
    for I:=0 to High(Regions) do begin
      P:=Index.Find(Regions[I].ID); Owner:=nil;
      while P<>nil do begin
        if (P.Kind=mkFormula) or ((P=Root) and not Paragraph) then Owner:=P;
        P:=P.Parent;
      end;
      if Owner=nil then Continue;
      J:=Formulas.IndexOf(Owner); if J<0 then Continue;
      R:=Regions[I].Bounds;
      if not Present[J] then Bounds[J]:=R
      else Bounds[J]:=Rect(Min(Bounds[J].Left,R.Left),Min(Bounds[J].Top,R.Top),
        Max(Bounds[J].Right,R.Right),Max(Bounds[J].Bottom,R.Bottom));
      Present[J]:=True;
    end;
    RootText:=Trim(Root.TeX);
    for J:=0 to Formulas.Count-1 do begin
      Node:=TMathNode(Formulas[J]); Text:=Node.TeX;
      R:=Bounds[J];
      if RootText=Trim(Text) then begin R:=Rect(8,8,Max(9,Width-8),Max(9,Height-8)); Present[J]:=True; end;
      if not Present[J] then Continue;
      InflateRect(R,2,2);
      K:=Length(Regions); SetLength(Regions,K+1);
      Regions[K].ID:=Node.ID; Regions[K].Bounds:=R; Regions[K].DefinitionArgument:=-1;
      A:=Default(TTeXAnchor); A.ID:=Node.ID; A.IsContainer:=True;
      A.Bounds:=R; InflateRect(A.Bounds,-2,-2);
      A.SourceStart:=MathSourceOffset(Node)-Length(Node.Prefix); A.SourceLength:=MathSourceLength(Node);
      A.Text:=Text; A.FontName:='Latin Modern Math'; A.Color:=clBlack; A.FontHeight:=16;
      A.Baseline:=(R.Bottom-R.Top)*4 div 5;
      K:=Length(Layout.Anchors); SetLength(Layout.Anchors,K+1); Layout.Anchors[K]:=A;
    end;
  finally Index.Free; Formulas.Free; end;
end;

procedure NormalizeMathSelection(Root:TMathNode; var A,B:Integer);
var PreviousA,PreviousB:Integer; SourceIndex:TMathSourceIndex;
  procedure Expand(Node:TMathNode);
  var I,J,K,L,R,AL,AR:Integer; Arg,Base:TMathNode; Inside:Boolean;
  begin
    L:=MathSourceOffset(Node)-Length(Node.Prefix); R:=L+MathSourceLength(Node);
    if (A>=R) or (B<=L) then Exit;
    if (Node.Kind=mkGroup) and (Node.Prefix<>'') and (Node.Prefix[1] in ['^','_']) and
       (Node.Parent<>nil) and (Node.Parent.Kind=mkRow) and ((A<=L) or (B>=R)) then
    begin
      J:=Node.Parent.Children.IndexOf(Node); K:=J-1;
      while K>=0 do
      begin
        Base:=TMathNode(Node.Parent.Children[K]);
        if ((Base.Kind=mkText) and (Trim(Base.Text)='')) or
           ((Base.Kind=mkGroup) and (Base.Prefix<>'') and (Base.Prefix[1] in ['^','_'])) then Dec(K)
        else Break;
      end;
      if K>=0 then
      begin
        Base:=TMathNode(Node.Parent.Children[K]);
        AL:=MathSourceOffset(Base)-Length(Base.Prefix);
        if (Base.Kind=mkText) and (UTF8Length(TrimRight(Base.Text))>1) then
          Inc(AL,Length(UTF8Copy(TrimRight(Base.Text),1,UTF8Length(TrimRight(Base.Text))-1)));
        A:=Min(A,AL);
        for I:=K+1 to Node.Parent.Children.Count-1 do
        begin
          Arg:=TMathNode(Node.Parent.Children[I]);
          if (Arg.Kind=mkText) and (Trim(Arg.Text)='') then Continue;
          if (Arg.Kind<>mkGroup) or (Arg.Prefix='') or not (Arg.Prefix[1] in ['^','_']) then Break;
          B:=Max(B,MathSourceOffset(Arg)-Length(Arg.Prefix)+MathSourceLength(Arg));
        end;
      end;
    end;
    if (Node.Kind=mkTextCommand) or ((Node.Kind=mkCommand) and (Node.Children.Count=0)) then
    begin A:=Min(A,L); B:=Max(B,R); end;
    if (Node.Kind in [mkGroup,mkOptional,mkEnvironment,mkFormula,mkTable]) and (ProseFormatName(Node)='') and (Node.Suffix<>'') and
       ((A<MathSourceOffset(Node)) or (B>R-Length(Node.Suffix))) then
    begin A:=Min(A,L); B:=Max(B,R); end;
    if ((Node.Kind=mkCommand) and (Node.Children.Count>0)) or IsStandaloneMathGroup(Node) or
       ((Node.Kind=mkGroup) and ((Pos('\left',Node.Prefix)=1) or (Trim(Node.Prefix)='\lvert') or (Trim(Node.Prefix)='\lVert') or (Trim(Node.Prefix)='\langle'))) then
    begin
      Inside:=False;
      for I:=0 to Node.Children.Count-1 do
      begin
        Arg:=TMathNode(Node.Children[I]); AL:=MathSourceOffset(Arg);
        AR:=AL+MathSourceLength(Arg)-Length(Arg.Prefix)-Length(Arg.Suffix);
        if (A>=AL) and (B<=AR) then Inside:=True;
      end;
      if not Inside then begin A:=Min(A,L); B:=Max(B,R); end;
    end;
    for I:=0 to Node.Children.Count-1 do Expand(TMathNode(Node.Children[I]));
  end;
begin
  if A>=B then Exit;
  SourceIndex:=TMathSourceIndex.Create(Root);
  try
  repeat
    PreviousA:=A; PreviousB:=B; Expand(Root);
  until (A=PreviousA) and (B=PreviousB);
  MatchEnvironmentSelection(Root.TeX,A,B);
  finally SourceIndex.Free; end;
end;

function MathDelimiterOffset(Root:TMathNode; const Regions:TDraftRegions; X,Y:Integer; out Offset:Integer):Boolean;
var BestArea:Integer;
  procedure Visit(Node:TMathNode);
  var I,J,Left,Right,Area:Integer; R:TRect; Found:Boolean;
    procedure ContentBounds(Child:TMathNode);
    var K,L:Integer;
    begin
      for K:=0 to High(Regions) do if Regions[K].ID=Child.ID then begin
        Left:=Min(Left,Regions[K].Bounds.Left); Right:=Max(Right,Regions[K].Bounds.Right); Found:=True;
      end;
      for L:=0 to Child.Children.Count-1 do ContentBounds(TMathNode(Child.Children[L]));
    end;
  begin
    if (Node.Kind=mkGroup) and ((Pos('\left',Node.Prefix)=1) or
       (Trim(Node.Prefix)='\lvert') or (Trim(Node.Prefix)='\lVert') or (Trim(Node.Prefix)='\langle')) then
      for I:=0 to High(Regions) do if Regions[I].ID=Node.ID then begin
        R:=Regions[I].Bounds;
        if (X<R.Left-2) or (X>R.Right+2) or (Y<R.Top) or (Y>R.Bottom) then Continue;
        Left:=R.Right; Right:=R.Left; Found:=False;
        for J:=0 to Node.Children.Count-1 do ContentBounds(TMathNode(Node.Children[J]));
        if not Found then Continue;
        if (X>Max(R.Left+2,Left)) and (X<Min(R.Right-2,Right)) then Continue;
        Area:=(R.Right-R.Left)*(R.Bottom-R.Top);
        if Area>=BestArea then Continue;
        BestArea:=Area; Offset:=MathSourceOffset(Node)-Length(Node.Prefix);
        if X>(R.Left+R.Right) div 2 then Inc(Offset,MathSourceLength(Node));
        Result:=True;
      end;
    for I:=0 to Node.Children.Count-1 do Visit(TMathNode(Node.Children[I]));
  end;
begin
  Result:=False; Offset:=0; BestArea:=MaxInt; if Root<>nil then Visit(Root);
end;

function MathSelectionRects(Root:TMathNode; Fields:TList; const Regions:TDraftRegions; A,B:Integer):TSelectionRects;
var I,J,L,R,First,Last,Top,Left,Bottom,Right:Integer; N,Table,Row,Cell:TMathNode; Box:TRect;
    SourceIndex:TMathSourceIndex; FieldIndex:TMathFieldIndex;
  procedure AddBounds(const Bounds:TRect);
  var K,M:Integer; Value:TRect;
  begin
    if Bounds.Right<=Bounds.Left then Exit;
    Value:=Bounds; K:=0;
    while K<Length(Result) do begin
      if (Value.Top<Result[K].Bottom) and (Value.Bottom>Result[K].Top) then begin
        Value:=Rect(Min(Value.Left,Result[K].Left),Min(Value.Top,Result[K].Top),Max(Value.Right,Result[K].Right),Max(Value.Bottom,Result[K].Bottom));
        for M:=K to High(Result)-1 do Result[M]:=Result[M+1]; SetLength(Result,Length(Result)-1);
      end else Inc(K);
    end;
    K:=0; while (K<Length(Result)) and (Result[K].Top<Value.Top) do Inc(K);
    SetLength(Result,Length(Result)+1); for M:=High(Result) downto K+1 do Result[M]:=Result[M-1]; Result[K]:=Value;
  end;
  procedure IncludeGroup(Node:TMathNode);
  var K,L,R:Integer; Bounds:TRect;
  begin
    L:=MathSourceOffset(Node)-Length(Node.Prefix); R:=L+MathSourceLength(Node);
    if (A<=L) and (B>=R) and (Node.Kind in [mkGroup,mkOptional,mkFormula,mkTable]) and (ProseFormatName(Node)='') then
      for K:=0 to High(Regions) do if Regions[K].ID=Node.ID then
      begin
        Bounds:=Regions[K].Bounds;
        AddBounds(Bounds);
      end;
    for K:=0 to Node.Children.Count-1 do IncludeGroup(TMathNode(Node.Children[K]));
  end;
  function StopAt(Index:Integer):Integer;
  begin
    Index:=EnsureRange(Index,0,Regions[I].CharCount);
    if Index<Length(Regions[I].Stops) then Result:=Regions[I].Stops[Index]
    else Result:=Round((Box.Right-Box.Left)*Index/Max(1,Regions[I].CharCount));
  end;
begin
  Result:=nil; if A>=B then Exit;
  SourceIndex:=TMathSourceIndex.Create(Root);
  FieldIndex:=TMathFieldIndex.Create;
  try
  FieldIndex.Build(Fields);
  if TableCellSelection(Root,A,B,Table,Top,Left,Bottom,Right) then begin
    for I:=Top to Bottom do begin
      Row:=TMathNode(Table.Children[I]);
      for J:=Left to Min(Right,Row.Children.Count-1) do begin
        Cell:=TMathNode(Row.Children[J]);
        for L:=0 to High(Regions) do if Regions[L].ID=Cell.ID then AddBounds(Regions[L].Bounds);
      end;
    end;
    if Length(Result)>1 then begin
      Box:=Result[0]; for I:=1 to High(Result) do Box:=Rect(Min(Box.Left,Result[I].Left),Min(Box.Top,Result[I].Top),Max(Box.Right,Result[I].Right),Max(Box.Bottom,Result[I].Bottom));
      SetLength(Result,1); Result[0]:=Box;
    end;
    Exit;
  end;
  for I:=0 to High(Regions) do begin
    N:=FieldIndex.Find(Regions[I].ID); if N=nil then Continue;
    L:=Max(A,MathSourceOffset(N)); R:=Min(B,MathSourceOffset(N)+Length(N.Text));
    if R<=L then Continue;
    if N.Kind in [mkCommand,mkTextCommand] then
    begin First:=0; Last:=Regions[I].CharCount; end
    else begin
    First:=UTF8Length(Copy(N.Text,1,L-MathSourceOffset(N)))-Regions[I].FirstChar;
    Last:=UTF8Length(Copy(N.Text,1,R-MathSourceOffset(N)))-Regions[I].FirstChar;
    end;
    if (Last<=0) or (First>=Regions[I].CharCount) then Continue;
    Box:=Regions[I].Bounds; L:=Box.Left+StopAt(First); R:=Box.Left+StopAt(Last);
    AddBounds(Rect(L,Box.Top,R,Box.Bottom));
  end;
  IncludeGroup(Root);
  finally FieldIndex.Free; SourceIndex.Free; end;
end;
constructor TParagraphSelection.Create(const Source,Header,XML,Positions:string; Registry:TMacroRegistry;
  Page,Width,Height,ViewWidth:Integer; Canvas:TCanvas; Context:TTeXContext; const Directory:string);
var Previous:TTeXLayout; Draft:TParagraphDraft; Points,Size,I,J,K,NativeCount:Integer;
    NeedsDraft,Found:Boolean; Region:TDraftRegion; SourceIndex:TMathSourceIndex;
begin
  inherited Create; FFields:=TList.Create;
  try
    FRoot:=ParseParagraph(Source,Registry);
    if FRoot.TeX<>Source then raise Exception.Create('Incomplete source');
  except
    FRoot.Free; FRoot:=TMathNode.Create(mkProse,Source); FRoot.ID:=0;
  end;
  MathFields(FRoot,FFields); if FFields.Count=0 then FFields.Add(FRoot);
  FFieldIndex:=TMathFieldIndex.Create; FFieldIndex.Build(FFields);
  FScale:=Max(0.001,ViewWidth/Max(1,Width)); Previous:=TTeXLayout.Create;
  SourceIndex:=TMathSourceIndex.Create(FRoot);
  try
    Previous.Load(XML,Page,Canvas); Previous.Bind(FRoot,Source);
    ReadMathRegions(Positions,Page,Width,Height,FFields,FRegions);
    MergeMathRegions(Previous,FFields,Source,FRegions);
    { Hit testing a compiled page must use its PDF text and TeX markers.
      A source-only layout fills missing fields without replacing PDF anchors. }
    NativeCount:=Length(FRegions); NeedsDraft:=NativeCount=0;
    for I:=0 to FFields.Count-1 do begin
      Found:=False;
      for J:=0 to NativeCount-1 do if FRegions[J].ID=TMathNode(FFields[I]).ID then begin Found:=True; Break; end;
      if not Found then begin NeedsDraft:=True; Break; end;
    end;
    if NeedsDraft then begin
      Draft:=TParagraphDraft.Create;
      try
        if Width<=0 then FScale:=1;
        Points:=10; if Pos('11pt',Header)>0 then Points:=11;
        if Pos('12pt',Header)>0 then Points:=12;
        Size:=Max(8,Round(Points*120*FScale/Max(1,Canvas.Font.PixelsPerInch)));
        Draft.Macros:=Registry; Draft.HeadingContext:=Header; Draft.DocumentFontSize:=Points;
        Draft.Directory:=Directory;
        Draft.Context:=Context; Draft.ContextOffset:=Length(Header);
        Draft.HeadingWithChapter:=(Pos('{book}',Header)>0) or (Pos('{report}',Header)>0);
        Draft.Layout(Canvas,FRoot,Max(80,ViewWidth),True,Size,Previous,Source,FScale,Points*120*FScale/72);
        for I:=0 to High(Draft.Regions) do begin
          Region:=Draft.Regions[I]; Found:=False;
          for J:=0 to NativeCount-1 do if FRegions[J].ID=Region.ID then begin Found:=True; Break; end;
          if Found then Continue;
          Region.Bounds:=Rect(Round(Region.Bounds.Left/FScale),Round(Region.Bounds.Top/FScale),
            Round(Region.Bounds.Right/FScale),Round(Region.Bounds.Bottom/FScale));
          Region.Stops:=Copy(Region.Stops);
          for K:=0 to High(Region.Stops) do Region.Stops[K]:=Round(Region.Stops[K]/FScale);
          J:=Length(FRegions); SetLength(FRegions,J+1); FRegions[J]:=Region;
        end;
      finally Draft.Free; end;
    end;
    AddMathFormulaRegions(FRoot,Previous,FFields,Width,Height,True,FRegions);
  finally SourceIndex.Free; Previous.Free; end;
end;
destructor TParagraphSelection.Destroy;
begin FFieldIndex.Free; FRoot.Free; FFields.Free; inherited Destroy; end;
procedure TParagraphSelection.Normalize(var A,B:Integer);
begin NormalizeMathSelection(FRoot,A,B); end;
function TParagraphSelection.HitOffset(X,Y:Integer):Integer;
var I,K,Best,Distance,BestDistance,Area,BestArea,Stop,Count:Integer; R:TRect; N:TMathNode; SourceIndex:TMathSourceIndex;
begin
  Result:=0; X:=Round(X/Max(0.001,FScale)); Y:=Round(Y/Max(0.001,FScale));
  SourceIndex:=TMathSourceIndex.Create(FRoot);
  try
  if MathDelimiterOffset(FRoot,FRegions,X,Y,Result) then Exit;
  Best:=-1; BestDistance:=MaxInt; BestArea:=MaxInt;
  for I:=0 to High(FRegions) do begin
    R:=FRegions[I].Bounds;
    N:=FFieldIndex.Find(FRegions[I].ID); if N=nil then Continue;
    Distance:=Max(Max(R.Left-X,0),X-R.Right)+4*Max(Max(R.Top-Y,0),Y-R.Bottom);
    Area:=(R.Right-R.Left)*(R.Bottom-R.Top);
    if (Distance>BestDistance) or ((Distance=BestDistance) and (Area>=BestArea)) then Continue;
    Best:=I; BestDistance:=Distance; BestArea:=Area; Count:=UTF8Length(N.Text);
    Stop:=FRegions[I].CharCount;
    if N.Kind in [mkProse,mkText] then begin
      Stop:=EnsureRange(Round((X-R.Left)*Stop/Max(1,R.Right-R.Left)),0,Stop);
      if Length(FRegions[I].Stops)>0 then begin
        Stop:=0; Distance:=MaxInt;
        for K:=0 to High(FRegions[I].Stops) do
          if Abs(X-R.Left-FRegions[I].Stops[K])<Distance then begin
            Stop:=K; Distance:=Abs(X-R.Left-FRegions[I].Stops[K]);
          end;
      end;
      Stop:=EnsureRange(Stop+FRegions[I].FirstChar,0,Count);
      if not IsVerbatimField(N) and not IsCodeField(N) then
        while (Stop>0) and (Stop<Count) and
          (UTF8Copy(N.Text,Stop,1)[1] in [' ',#9,#10,#13]) and
          (UTF8Copy(N.Text,Stop+1,1)[1] in [' ',#9,#10,#13]) do Inc(Stop);
    end else if (N.Kind=mkTextCommand) and (X<(R.Left+R.Right) div 2) then Stop:=0
    else Stop:=Count;
    Result:=MathSourceOffset(N)+Length(UTF8Copy(N.Text,1,Stop));
  end;
  if Best<0 then Result:=0;
  finally SourceIndex.Free; end;
end;
function TParagraphSelection.Rects(A,B:Integer):TSelectionRects;
var I:Integer;
begin
  Normalize(A,B); Result:=MathSelectionRects(FRoot,FFields,FRegions,A,B);
  for I:=0 to High(Result) do with Result[I] do begin
    Left:=Round(Left*FScale); Right:=Round(Right*FScale);
    Top:=Round(Top*FScale); Bottom:=Round(Bottom*FScale);
  end;
end;
end.
