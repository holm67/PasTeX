{ SPDX-License-Identifier: GPL-3.0-or-later }
function TParagraphDraft.VerbatimBox(Node:TMathNode; Size:Integer):TDraftBox;
var Field,Symbol:TMathNode; Saved,CodeStyle:TTeXTextStyle; FontName,StyleCode,C,Columns,ColumnAlign,Frame:string;
    FontStyle:TFontStyles; Options:TStringList; Tokens:TListingTokens;
    OldHeight,P,First,X,Y,LineHeight,LineBaseline,Count,TokenIndex,LineNumber,LeftPadding,TabSize,Step,NumberSep,NumberWidth,ContentWidth,I,LineCount:Integer;
    Piece,Cell:TDraftBox; BaseColor,OldColor:TColor; NumberPending,Listing,FixedColumns:Boolean;
    Em,Points,CellWidth:Double; CustomFrame:Boolean;
  procedure TokenStyle(const Source:string);
  var Q:Integer; Cmd:string;
  begin
    ApplyTextStyle(FTextStyle,Source,Directory); Q:=1;
    while Q<=Length(Source) do begin
      if Source[Q]<>'\' then begin Inc(Q); Continue; end;
      Cmd:=ReadTeXCommand(Source,Q); if Cmd='color' then FDefaultColor:=NamedColor(ReadTeXGroup(Source,Q,'{','}'));
    end;
    FDefaultFont:='Latin Modern Roman';
    if FTextStyle.Family=FTextStyle.Mono then FDefaultFont:='Latin Modern Mono'
    else if FTextStyle.Family=FTextStyle.Sans then FDefaultFont:='Latin Modern Sans';
  end;
  function Dimension(const Key,Default:string):Integer;
  var Value:string;
  begin
    Value:=Options.Values[Key]; if Value='' then Value:=Default;
    Result:=DraftDimension(Value,Em,FMathWidth,0,Points);
  end;
  function CharacterBox:TDraftBox;
  var Command:string;
  begin
    Command:='';
    if FTextStyle.Family<>FTextStyle.Mono then case C of
      '\':Command:='textbackslash'; '{','}':Command:=C; '|':Command:='textbar';
      '_':Command:='textunderscore'; '^':Command:='textasciicircum'; '~':Command:='textasciitilde';
      '<':Command:='textless'; '>':Command:='textgreater';
    end;
    if Command='' then Exit(Leaf(C,Field.ID,Size,First));
    Symbol:=TMathNode.Create(mkCommand,'\'+Command);
    try Symbol.ID:=Field.ID; Result:=TextSymbolBox(Symbol,Size); finally Symbol.Free; end;
    Result.FirstChar:=First; Result.CharCount:=1; SetLength(Result.Stops,2); Result.Stops[1]:=Result.W;
  end;
  procedure Line(X1,Y1,X2,Y2:Integer);
  var N:Integer;
  begin
    N:=Length(Result.Lines); SetLength(Result.Lines,N+1);
    Result.Lines[N].A:=Point(X1,Y1); Result.Lines[N].B:=Point(X2,Y2); Result.Lines[N].Width:=Max(1,Dimension('framerule','0.4pt'));
  end;
begin
  Result:=TDraftBox.Create; if Node.Children.Count=0 then Exit;
  Field:=TMathNode(Node.Children[0]); Saved:=FTextStyle; FontName:=FDefaultFont;
  FontStyle:=FDefaultStyle; OldHeight:=FDefaultHeight; OldColor:=FDefaultColor; Options:=TStringList.Create;
  try
    Listing:=Node.Text='lstlisting'; Tokens:=nil; TokenIndex:=0; LeftPadding:=0; LineNumber:=1; NumberPending:=True;
    FDefaultStyle:=[]; FDefaultHeight:=0;
    if Listing then begin
      ListingOptions(HeadingContext,Node.Prefix,Options); TokenStyle(Options.Values['basicstyle']);
      Tokens:=ListingTokens(Field.Text,Options,HeadingContext,Directory);
      LineNumber:=StrToIntDef(Options.Values['firstnumber'],1);
    end else begin
      FTextStyle.Family:=FTextStyle.Mono; FTextStyle.Series:='m'; FTextStyle.Shape:='n'; TokenStyle('');
    end;
    BaseColor:=FDefaultColor; CodeStyle:=FTextStyle; Em:=MeasureEm(FMathBaseSize)*CodeStyle.Points/MathFontPoints(0);
    Points:=MeasureEm(FMathBaseSize)/MathFontPoints(0); Step:=Max(1,StrToIntDef(Options.Values['stepnumber'],1));
    Columns:=Options.Values['columns']; P:=1; ColumnAlign:=ReadTeXGroup(Columns,P,'[',']'); Columns:=Copy(Columns,P,MaxInt);
    FixedColumns:=Listing and (Columns='fixed'); C:=Options.Values['basewidth']; P:=Pos(',',C); if P>0 then C:=Copy(C,1,P-1);
    CellWidth:=Max(1,DraftDimension(C,Em,FMathWidth,Round(Em*0.6),Points));
    NumberSep:=Dimension('numbersep','10pt'); NumberWidth:=0;
    if (Options.Values['numbers']='left') or (Options.Values['numbers']='right') then begin
      TokenStyle(Options.Values['numberstyle']);
      LineCount:=1; for I:=1 to Length(Field.Text) do if Field.Text[I]=#10 then Inc(LineCount);
      Piece:=Leaf(IntToStr(LineNumber+LineCount),-1,Size,0); NumberWidth:=Piece.W; Piece.Free;
      if Options.Values['numbers']='left' then LeftPadding:=NumberWidth+NumberSep;
      FTextStyle:=CodeStyle; FDefaultColor:=BaseColor;
    end;
    LineHeight:=Max(1,Round(CodeStyle.Baseline*CodeStyle.Spread*Points)); if LineHeight<2 then LineHeight:=Max(1,Round(Em*1.2));
    Piece:=Leaf('M',-1,Size,0); LineBaseline:=Piece.Baseline; Piece.Free;
    P:=1; First:=0; X:=LeftPadding; Y:=0; ContentWidth:=0;
    while P<=Length(Field.Text) do begin
      FTextStyle:=CodeStyle; FDefaultColor:=BaseColor;
      while (TokenIndex<High(Tokens)) and (P>=Tokens[TokenIndex].Finish) do Inc(TokenIndex);
      StyleCode:=Options.Values['identifierstyle'];
      if TokenIndex<Length(Tokens) then case Tokens[TokenIndex].Kind of
        lkKeyword:StyleCode:=Options.Values['keywordstyle'];
        lkComment:StyleCode:=Options.Values['commentstyle'];
        lkString:StyleCode:=Options.Values['stringstyle'];
      end;
      TokenStyle(StyleCode); C:=UTF8Copy(Copy(Field.Text,P,4),1,1); Count:=1;
      if (C=#13) and (Copy(Field.Text,P+1,1)=#10) then begin C:=#13#10; Count:=2; end;
      if (C=#10) or (Copy(C,1,1)=#13) then begin
        Piece:=Leaf('',Field.ID,Size,First); Piece.CharCount:=Count; SetLength(Piece.Stops,Count+1);
        Piece.X:=X; Piece.Y:=Y; Result.Children.Add(Piece);
        if (P>1) and (P+Length(C)<=Length(Field.Text)) then begin Inc(Y,LineHeight); X:=LeftPadding; Inc(LineNumber); NumberPending:=True; end;
      end else begin
        if NumberPending then begin
          if ((Options.Values['numbers']='left') or (Options.Values['numbers']='right')) and ((LineNumber mod Step)=0) then begin
            FTextStyle:=CodeStyle; FDefaultColor:=BaseColor; TokenStyle(Options.Values['numberstyle']);
            Piece:=Leaf(IntToStr(LineNumber),-1,Size,0); Piece.Y:=Y+LineBaseline-Piece.Baseline;
            if LeftPadding>0 then Piece.X:=LeftPadding-NumberSep-Piece.W else Piece.X:=Max(40,FMathWidth)+NumberSep;
            Result.Children.Add(Piece); FTextStyle:=CodeStyle; FDefaultColor:=BaseColor; TokenStyle(StyleCode);
          end;
          NumberPending:=False;
        end;
        Piece:=CharacterBox;
        if FixedColumns and (C<>#9) then begin
          Cell:=TDraftBox.Create; Cell.ID:=Field.ID; Cell.FirstChar:=First; Cell.CharCount:=1;
          Cell.W:=Round((First+1)*CellWidth)-Round(First*CellWidth); Cell.H:=Piece.H; Cell.Baseline:=Piece.Baseline;
          SetLength(Cell.Stops,2); Cell.Stops[1]:=Cell.W; Piece.ID:=-1;
          if ColumnAlign='r' then Piece.X:=Cell.W-Piece.W
          else if ColumnAlign<>'l' then Piece.X:=(Cell.W-Piece.W) div 2;
          Cell.Children.Add(Piece); Piece:=Cell;
        end;
        if C=#9 then begin
          TabSize:=EnsureRange(StrToIntDef(Options.Values['tabsize'],8),1,32); Piece.Text:='';
          Piece.W:=(TabSize-((X-LeftPadding) div Max(1,Round(CellWidth))) mod TabSize)*Round(CellWidth);
          Piece.CharCount:=1; SetLength(Piece.Stops,2); Piece.Stops[1]:=Piece.W;
        end;
        if (Options.Values['breaklines']='true') and (X+Piece.W>FMathWidth-4) and (X>LeftPadding) then begin Inc(Y,LineHeight); X:=LeftPadding; end;
        Piece.X:=X; Piece.Y:=Y+LineBaseline-Piece.Baseline;
        if (C=' ') and (Node.Text='verbatim*') then Piece.Shape:=18;
        Result.Children.Add(Piece); Inc(X,Piece.W); ContentWidth:=Max(ContentWidth,X);
      end;
      Inc(First,Count); Inc(P,Length(C));
    end;
    Piece:=Leaf('',Field.ID,Size,First); Piece.X:=X; Piece.Y:=Y; Result.Children.Add(Piece);
    Result.W:=Max(12,ContentWidth); Result.H:=Y+Max(LineHeight,LineBaseline); Result.Baseline:=LineBaseline;
    if Listing then begin
      Result.Shape:=9; Result.Color:=BaseColor; Frame:=Options.Values['frame'];
      CustomFrame:=(Frame<>'single') and (Frame<>'lines') and (Frame<>'topline') and (Frame<>'bottomline');
      if (Frame<>'') and (Frame<>'none') then begin
        C:=Options.Values['rulecolor']; if C<>'' then begin FDefaultColor:=BaseColor; TokenStyle(C); Result.Color:=FDefaultColor; end;
        if (Frame='single') or (Frame='lines') or (Frame='topline') or (CustomFrame and (Pos('t',Frame)>0)) then Line(LeftPadding,0,Max(ContentWidth,FMathWidth),0);
        if (Frame='single') or (Frame='lines') or (Frame='bottomline') or (CustomFrame and (Pos('b',Frame)>0)) then Line(LeftPadding,Result.H,Max(ContentWidth,FMathWidth),Result.H);
        if (Frame='single') or (CustomFrame and (Pos('l',Frame)>0)) then Line(LeftPadding,0,LeftPadding,Result.H);
        if (Frame='single') or (CustomFrame and (Pos('r',Frame)>0)) then Line(Max(ContentWidth,FMathWidth),0,Max(ContentWidth,FMathWidth),Result.H);
        Result.W:=Max(Result.W,FMathWidth);
      end;
      if Options.Values['backgroundcolor']<>'' then begin
        FDefaultColor:=clWhite; TokenStyle(Options.Values['backgroundcolor']); Result.FillColor:=FDefaultColor; Result.W:=Max(Result.W,FMathWidth);
      end;
      if Options.Values['numbers']='right' then Result.W:=Max(Result.W,FMathWidth+NumberSep+NumberWidth);
    end;
  finally Options.Free; FTextStyle:=Saved; FDefaultColor:=OldColor; FDefaultFont:=FontName; FDefaultStyle:=FontStyle; FDefaultHeight:=OldHeight; end;
end;
