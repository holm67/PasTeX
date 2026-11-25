{ SPDX-License-Identifier: GPL-3.0-or-later }
function TParagraphDraft.NativeBox(Node:TMathNode; Size:Integer; MathMode:Boolean):TDraftBox;
var Info:TMacroInfo; Name,Align,Value,Pattern,Key:string; Content,Field:TMathNode; State:TMacroRegistry;
    Draft:TParagraphDraft; Body,Rule,Child:TDraftBox;
    I,J,Q,Count,Period,Start,Index,W,H,Depth,Lift,Pad,Stroke,NaturalW,Target,P:Integer; Points,RulePoints:Double;
    Segments:array of Integer; Entries:TDiagramOptions; Entry:TDiagramOption; Factor:Double; DrawFrame,OldMarks:Boolean;
  function HasMeasuredExtent(Box:TDraftBox):Boolean;
  var I:Integer;
  begin
    if (Box.Text<>'') and (Trim(Box.Text)='') and (Box.Shape=0) and (Box.Children.Count=0) then Exit(False);
    if Box.HasInkMetric then Exit((Box.InkAbove<>0) or (Box.InkBelow<>0));
    if (Box.Shape<>0) or (Trim(Box.Text)<>'') then Exit(True);
    for I:=0 to Box.Children.Count-1 do
      if HasMeasuredExtent(TDraftBox(Box.Children[I])) then Exit(True);
    Result:=False;
  end;
  procedure TextNodes(N:TMathNode);
  var I:Integer; Field:TMathNode; Name:string;
  begin
    { A text box may contain a real math list. Keep its math atoms and fonts;
      converting them to prose leaves MathBox with empty, unmeasurable atoms. }
    if N.Kind=mkFormula then Exit;
    if N.Kind=mkText then N.Kind:=mkProse;
    Name:=N.Text;
    if (N.Kind=mkCommand) and (N.Children.Count=1) and
      ((Name='\textbf') or (Name='\textit') or (Name='\textrm') or (Name='\textsf') or
       (Name='\texttt') or (Name='\textsc') or (Name='\textsl') or (Name='\textup') or
       (Name='\textmd') or (Name='\textnormal') or (Name='\emph') or (Name='\underline')) then begin
      Field:=TMathNode(N.Children.Extract(N.Children[0]));
      N.Kind:=mkGroup; N.Prefix:=N.Prefix+Name+Field.Prefix; N.Suffix:=Field.Suffix+N.Suffix; N.Text:='';
      while Field.Children.Count>0 do N.Add(TMathNode(Field.Children.Extract(Field.Children[0])));
      if Field.Text<>'' then N.Add(TMathNode.Create(mkProse,Field.Text)).ID:=Field.ID;
      Field.Free;
    end;
    for I:=0 to N.Children.Count-1 do TextNodes(TMathNode(N.Children[I]));
  end;
  function Argument(N:Integer):string;
  var Field:TMathNode; P:Integer;
  begin
    Result:='';
    if (Info.PreviewAdapter='savedbox') and (Node.Children.Count=0) and (N=0) then begin
      P:=1; ReadTeXCommand(Node.Text,P); Exit(ReadTeXArgument(Node.Text,P));
    end;
    if (Info.PreviewAdapter='space') and (Node.Children.Count=0) then begin
      P:=1; ReadTeXCommand(Node.Text,P); if Copy(Node.Text,P,1)='*' then Inc(P);
      Exit(ReadTeXGroup(Node.Text,P,'{','}'));
    end;
    if N>=Node.Children.Count then Exit; Field:=TMathNode(Node.Children[N]);
    if (Field.Kind=mkOptional) and (Field.Prefix='') then begin
      if Field.Text='\NoValue' then Exit(''); Exit(Field.Text);
    end;
    Result:=Field.TeX; Result:=Copy(Result,Length(Field.Prefix)+1,Length(Result)-Length(Field.Prefix)-Length(Field.Suffix));
  end;
  function Dim(const Text:string; Default:Integer=0):Integer;
  begin
    Result:=BoxDimension(Text,Body,Size,FMathWidth,Default,Name='parbox');
  end;
begin
  Result:=nil; if not ((Node.Kind in [mkCommand,mkTextCommand]) or ((Node.Kind=mkEnvironment) and (Node.Text='adjustbox'))) or (Macros=nil) or (NativeBoxDepth>=16) then Exit;
  P:=1; Name:=ReadTeXCommand(Node.Text,P); if Copy(Node.Text,P,1)='*' then Name:=Name+'*';
  if Node.Kind=mkEnvironment then Name:=Node.Text;
  Info:=Macros.Find(Name); if Info=nil then Exit;
  if Info.PreviewAdapter='diagbox' then Exit(DiagonalBox(Node,Size));
  if (Info.PreviewAdapter='metadata') or (Info.PreviewAdapter='directive') then begin
    if (Info.PreviewAdapter='metadata') and not HideEditingMarks then Exit(DefinitionBox(Node,Size,FMathWidth));
    Result:=TDraftBox.Create; Result.ID:=Node.ID; Exit;
  end;
  if Info.PreviewAdapter='savedbox' then begin
    State:=Macros.Clone; Inc(NativeBoxDepth);
    try
      State.ApplyDefinitions(Copy(FSource,1,Max(0,MathSourceOffset(Node)-Length(Node.Prefix))));
      Value:=State.SavedBox(Argument(0));
      if Value='' then Exit(DefinitionBox(Node,Size,FMathWidth));
      Content:=ParseParagraph(Value,State); Draft:=TParagraphDraft.Create;
      try
        InheritDraft(Draft); Draft.Macros:=State; Draft.HideEditingMarks:=True; Draft.HboxLayout:=True;
        Draft.Layout(FCanvas,Content,65556,True,FMathBaseSize,nil,Value,FScale,MeasureEm(FMathBaseSize));
        Result:=Draft.DetachContent(-1); ClearBoxIDs(Result); Result.ID:=Node.ID;
        Result.CharCount:=UTF8Length(Node.Text); SetLength(Result.Stops,Result.CharCount+1);
        for I:=1 to Result.CharCount do Result.Stops[I]:=Result.W;
      finally Draft.Free; Content.Free; end;
    finally Dec(NativeBoxDepth); State.Free; end;
    Exit;
  end;
  if Info.PreviewAdapter='phantom' then begin
    if Node.Children.Count=0 then Exit;
    Inc(NativeBoxDepth); Body:=nil; OldMarks:=HideEditingMarks;
    try
      Field:=TMathNode(Node.Children[0]);
      if MathMode then begin
        HideEditingMarks:=True; Body:=MathBox(Field,Size);
      end else begin
        Draft:=TParagraphDraft.Create;
        try
          InheritDraft(Draft); Draft.HideEditingMarks:=True; Draft.HideEnvironmentCaptions:=True;
          Draft.ShowSourceControls:=False; Draft.TableCellLayout:=False; Draft.HboxLayout:=True;
          if FMathLevel>0 then Draft.TextStyleSeed.Points:=MathFontPoints(FMathLevel);
          Draft.Layout(FCanvas,Field,65556,True,FMathBaseSize,nil,FSource,FScale,MeasureEm(FMathBaseSize));
          Body:=Draft.DetachContent(-1);
        finally Draft.Free; end;
      end;
      { latex.ltx measures text with an hbox, and mathematics via mathpalette.
        Copy TeX ink extents rather than the editor's font-leading padding. }
      Result:=TDraftBox.Create; Result.ID:=Node.ID; Result.W:=Body.W;
      if HasMeasuredExtent(Body) then begin
        Result.Baseline:=Max(0,Body.Baseline-InkTop(Body));
        Result.H:=Result.Baseline+Max(0,InkBottom(Body)-Body.Baseline);
      end;
      if Info.PreviewName='vphantom' then Result.W:=0;
      if Info.PreviewName='hphantom' then begin Result.H:=0; Result.Baseline:=0; end;
      Result.HasInkMetric:=True; Result.InkAbove:=Result.Baseline; Result.InkBelow:=Result.H-Result.Baseline;
    finally HideEditingMarks:=OldMarks; Body.Free; Dec(NativeBoxDepth); end;
    Exit;
  end;
  if Info.PreviewAdapter='stack' then begin
    if Node.Children.Count<2 then Exit;
    Field:=TMathNode(Node.Children[1]); Draft:=TParagraphDraft.Create; Inc(NativeBoxDepth);
    try
      InheritDraft(Draft); Draft.TableCellLayout:=False;
      if Name='thead' then ApplyTextStyle(Draft.TextStyleSeed,'\footnotesize',Directory);
      Draft.Layout(FCanvas,Field,65556,True,FMathBaseSize,nil,FSource,FScale,MeasureEm(FMathBaseSize));
      Result:=Draft.DetachContent(-1); Result.ID:=Node.ID; Result.Baseline:=Result.H div 2+Round(MeasureEm(Size)*0.25);
      Align:=Argument(0); if (Pos('l',Align)=0) and (Pos('r',Align)=0) then Align:=Align+'c';
      SetLength(Segments,Result.Children.Count);
      for I:=0 to Result.Children.Count-1 do begin Child:=TDraftBox(Result.Children[I]);
        W:=0; for J:=0 to Result.Children.Count-1 do begin Rule:=TDraftBox(Result.Children[J]);
          if Rule.Y+Rule.Baseline=Child.Y+Child.Baseline then W:=Max(W,Rule.X+Rule.W);
        end;
        Segments[I]:=W;
      end;
      for I:=0 to Result.Children.Count-1 do begin Child:=TDraftBox(Result.Children[I]);
        if Pos('r',Align)>0 then Inc(Child.X,Result.W-Segments[I]) else if Pos('c',Align)>0 then Inc(Child.X,(Result.W-Segments[I]) div 2);
      end;
      if (Pos('t',Align)>0) and (Result.Children.Count>0) then Result.Baseline:=TDraftBox(Result.Children[0]).Baseline
      else if Pos('b',Align)>0 then Result.Baseline:=LastBoxBaseline(Result);
    finally Dec(NativeBoxDepth); Draft.Free; end;
    Exit;
  end;
  if (Info.PreviewAdapter<>'box') and (Info.PreviewAdapter<>'space') and (Info.PreviewAdapter<>'symbol') and (Info.PreviewAdapter<>'adjustbox') and (Info.PreviewAdapter<>'colorbox') then Exit;
  Value:=Node.TeX; if Node.Kind=mkEnvironment then Value:='\'+Name+Copy(Value,Length(Node.Prefix)+1,MaxInt);
  if not PackagePreviewSupported(Info.PreviewAdapter,Info.PreviewName,Value) then Exit;
  Name:=Info.PreviewName; Points:=MeasureEm(FMathBaseSize)/MathFontPoints(0);
  NaturalW:=0; H:=0; Depth:=0; Segments:=nil; Body:=nil;
  Result:=TDraftBox.Create; Result.ID:=Node.ID; Result.Size:=Size; Result.Color:=FDefaultColor;
  Result.CharCount:=UTF8Length(Node.Text);
  if Info.PreviewAdapter='symbol' then begin
    Name:='pzd'; I:=0;
    if Info.PreviewName='Pisymbol' then begin Name:=Argument(0); I:=1; end;
    P:=StrToIntDef(Trim(Argument(I)),-1);
    if (P<0) or (P>255) then begin FreeAndNil(Result); Exit; end;
    Name:=TeXPackageFont('U',Name,Directory); Index:=ChooseTeXGlyph('text-'+Name+'-'+IntToStr(P));
    if Index<0 then begin FreeAndNil(Result); Exit; end;
    Result.Free; Result:=MathGlyphBox(Index,Node.ID,Size,UTF8Length(Node.Text)); Exit;
  end;
  if Info.PreviewAdapter='space' then begin
    Result.Shape:=7; Result.W:=0;
    if Name='indent' then Result.W:=Round(DocumentParagraphIndent(HeadingContext,FTextStyle.Points)*Points)
    else if Name<>'noindent' then Result.W:=Dim(Argument(0));
    Result.H:=0; Result.Baseline:=0; Result.Nonbreaking:=True;
    SetLength(Result.Stops,Result.CharCount+1); for I:=1 to Result.CharCount do Result.Stops[I]:=Result.W;
    Exit;
  end;
  if (Name='rule') or (Name='hdashrule') or (Name='hrule') or (Name='vrule') then begin
    W:=0; H:=0; Lift:=0; Depth:=0;
    if (Name='hrule') or (Name='vrule') then begin
      W:=FMathWidth; H:=Max(1,Round(0.4*Points));
      if Name='vrule' then begin W:=H; H:=Round(MeasureEm(Size)*0.7); Depth:=Round(MeasureEm(Size)*0.3); end;
      P:=1; ReadTeXCommand(Node.Text,P);
      while ReadTeXRuleDimension(Node.Text,P,Key,Value) do
        case Key of 'width':W:=Dim(Value,W); 'height':H:=Dim(Value,H); 'depth':Depth:=Dim(Value,Depth); end;
      Lift:=-Depth; Inc(H,Depth);
    end else if Name='hdashrule' then begin
      W:=Dim(Argument(2)); H:=Max(0,Dim(Argument(3))); Lift:=Dim(Argument(0));
    end else begin W:=Dim(Argument(1)); H:=Max(0,Dim(Argument(2))); Lift:=Dim(Argument(0)); end;
    Result.W:=Max(0,W); Result.Baseline:=Max(0,H+Lift); Result.H:=Result.Baseline+Max(0,-Lift);
    Pattern:=''; if Name='hdashrule' then Pattern:=Trim(Argument(4));
    if Pattern<>'' then begin
      P:=1; Period:=0;
      while (P<=Length(Pattern)) and (Length(Segments)<64) do begin
        SkipTeXSpace(Pattern,P); Q:=P;
        while (P<=Length(Pattern)) and not (Pattern[P] in [' ',#9,#10,#13]) do Inc(P);
        if P=Q then Break; I:=Max(0,Dim(Copy(Pattern,Q,P-Q)));
        SetLength(Segments,Length(Segments)+1); Segments[High(Segments)]:=I; Inc(Period,I);
      end;
      Count:=Length(Segments);
      if Odd(Count) then begin
        SetLength(Segments,Count*2); for I:=0 to Count-1 do Segments[Count+I]:=Segments[I]; Period:=Period*2;
      end;
      if Period<=0 then Exit;
      Count:=Min(2048,Result.W div Period); Align:=Argument(1); Pad:=Result.W-Count*Period;
      Start:=Pad div 2; if Align='x' then Start:=Pad div (Count+1);
      for I:=0 to Count-1 do begin
        Q:=Start+I*Period; if Align='x' then Q:=I*Period+(I+1)*Pad div (Count+1);
        for J:=0 to High(Segments) do begin
          if not Odd(J) and (Segments[J]>0) then begin
            Rule:=TDraftBox.Create; Rule.Shape:=22; Rule.Color:=FDefaultColor; Rule.X:=Q;
            Rule.W:=Segments[J]; Rule.H:=H; Rule.Y:=Result.Baseline-H-Lift; Result.Children.Add(Rule);
          end;
          Inc(Q,Segments[J]);
        end;
      end;
      Exit;
    end;
    Rule:=TDraftBox.Create; Rule.Shape:=22; Rule.Color:=FDefaultColor;
    Rule.W:=Result.W; Rule.H:=H; Rule.Y:=Result.Baseline-H-Lift; Result.Children.Add(Rule); Exit;
  end;
  Index:=Node.Children.Count-1; if Index<0 then Exit;
  Field:=TMathNode(Node.Children[Index]); Content:=PreviewArgument(Field,False,Macros);
  if Content.Kind in [mkGroup,mkOptional] then begin Content.Kind:=mkRow; Content.Prefix:=''; Content.Suffix:=''; end;
  TextNodes(Content);
  Draft:=TParagraphDraft.Create;
  Inc(NativeBoxDepth);
  try
    InheritDraft(Draft); Draft.HboxLayout:=Name<>'parbox';
    { The copied argument starts after its braces. Keep disclosure targets in
      document coordinates, including when a box contains another box. }
    Draft.FControlSourceBase:=FControlSourceBase+MathSourceOffset(Field);
    Target:=65536; if Name='parbox' then Target:=Max(1,Dim(Argument(3)));
    Draft.Layout(FCanvas,Content,Target+20,True,FMathBaseSize,nil,FSource,FScale,MeasureEm(FMathBaseSize));
    Body:=Draft.DetachContent(-1); NaturalW:=Body.W;
    if Name='parbox' then NaturalW:=Target;
    if (Name='minsizebox') or (Name='maxsizebox') then begin
      Factor:=1;
      for I:=0 to 1 do if Argument(I)<>'!' then begin
        if I=0 then W:=Max(1,Body.W) else W:=Max(1,Body.Baseline);
        Target:=Max(0,Dim(Argument(I),W));
        if Name='minsizebox' then Factor:=Max(Factor,Target/W) else Factor:=Min(Factor,Target/W);
      end;
      Body.Scale(EnsureRange(Factor,0.01,100.0)); NaturalW:=Body.W;
    end;
    if Name='adjustbox' then begin
      Entries:=DiagramOptions(Argument(0));
      for Entry in Entries do begin
        Factor:=1;
        if (Entry.Name='width') or (Entry.Name='max width') or (Entry.Name='min width') then begin
          Target:=Max(1,Dim(Entry.Value,Body.W));
          if (Entry.Name='width') or ((Entry.Name='max width') and (Body.W>Target)) or
            ((Entry.Name='min width') and (Body.W<Target)) then Factor:=Target/Max(1,Body.W);
        end else if (Entry.Name='height') or (Entry.Name='totalheight') or (Entry.Name='max height') or (Entry.Name='min height') then begin
          Target:=Max(1,Dim(Entry.Value,Body.H));
          if (Entry.Name='height') or (Entry.Name='totalheight') or ((Entry.Name='max height') and (Body.H>Target)) or
            ((Entry.Name='min height') and (Body.H<Target)) then Factor:=Target/Max(1,Body.H);
        end else if Entry.Name='scale' then Factor:=StrToFloatDef(Entry.Value,1,DefaultFormatSettings);
        Body.Scale(EnsureRange(Factor,0.01,100.0));
      end;
      NaturalW:=Body.W;
    end;
    Body.W:=NaturalW; H:=Body.Baseline; Depth:=Max(0,Body.H-H); W:=NaturalW;
    if (Name='makebox') or (Name='framebox') then begin
      Value:=Argument(0); if Value<>'' then W:=Max(0,Dim(Value,NaturalW)); Align:=Argument(1);
      if Align='r' then Body.X:=W-NaturalW else if (Align<>'l') and (Align<>'s') then Body.X:=(W-NaturalW) div 2;
      if (Align='s') and (W>NaturalW) and (Body.Children.Count>1) then begin
        Index:=0;
        for I:=0 to Body.Children.Count-1 do if Trim(TDraftBox(Body.Children[I]).Text)='' then Inc(Index);
        if Index>0 then begin
          Pad:=0;
          for I:=0 to Body.Children.Count-1 do begin
            Child:=TDraftBox(Body.Children[I]); Inc(Child.X,Pad);
            if Trim(Child.Text)='' then begin Inc(Child.W,(W-NaturalW) div Index); Inc(Pad,(W-NaturalW) div Index); end;
          end;
        end;
      end;
    end;
    Result.Children.Add(Body); Result.W:=W; Result.H:=Body.H; Result.Baseline:=Body.Baseline;
    if Name='parbox' then PositionParagraphBox(Result,Body,Size,Argument(0),Argument(2),Argument(1));
    DrawFrame:=(Name='framebox') or (Name='fbox') or (Name='fcolorbox');
    if Name='adjustbox' then for Entry in Entries do if Entry.Name='frame' then DrawFrame:=True;
    if DrawFrame or (Name='colorbox') then begin
      Value:=HeadingContext+Copy(FSource,1,MathSourceOffset(Node));
      Pad:=Max(0,Dim(DraftSetting(Value,'fboxsep','3pt')));
      RulePoints:=TeXStyleDimension(DraftSetting(Value,'fboxrule','0.4pt'),MathFontPoints(0));
      Stroke:=0; if DrawFrame and (RulePoints>0) then Stroke:=Max(1,Round(RulePoints*Points));
      if Name='colorbox' then Result.FillColor:=DocumentColor(Argument(1),Argument(0),HeadingContext);
      if Name='fcolorbox' then begin Result.Color:=DocumentColor(Argument(1),Argument(0),HeadingContext); Result.FillColor:=DocumentColor(Argument(2),Argument(0),HeadingContext); end;
      Inc(Body.X,Pad+Stroke); Body.Y:=Pad+Stroke;
      Inc(Result.W,2*(Pad+Stroke)); Inc(Result.H,2*(Pad+Stroke)); Inc(Result.Baseline,Pad+Stroke);
      Result.Shape:=9; Result.AccentHeight:=Stroke; SetLength(Result.Lines,4);
      Result.Lines[0].A:=Point(0,0); Result.Lines[0].B:=Point(Result.W,0);
      Result.Lines[1].A:=Point(Result.W,0); Result.Lines[1].B:=Point(Result.W,Result.H);
      Result.Lines[2].A:=Point(Result.W,Result.H); Result.Lines[2].B:=Point(0,Result.H);
      Result.Lines[3].A:=Point(0,Result.H); Result.Lines[3].B:=Point(0,0);
      if Stroke=0 then Result.Lines:=nil;
    end;
    if Name='adjustbox' then for Entry in Entries do begin
      if (Entry.Name='margin') or (Entry.Name='padding') then begin
        Pad:=Dim(Entry.Value); Inc(Body.X,Pad); Inc(Body.Y,Pad);
        Inc(Result.W,2*Pad); Inc(Result.H,2*Pad); Inc(Result.Baseline,Pad);
      end else if (Entry.Name='center') or (Entry.Name='left') or (Entry.Name='right') then begin
        Target:=FMathWidth; if Entry.HasValue then Target:=Dim(Entry.Value,Target);
        W:=Max(0,Target-Result.W); if Entry.Name='center' then W:=W div 2 else if Entry.Name='left' then W:=0;
        { Keep the frame and its content together inside the alignment box. }
        Rule:=Result; Result:=TDraftBox.Create; Result.W:=Target; Result.H:=Rule.H; Result.Baseline:=Rule.Baseline;
        Rule.X:=W; Result.Children.Add(Rule); Result.ID:=Node.ID; Rule.ID:=-1;
      end;
    end;
    if Name='raisebox' then begin
      Lift:=Dim(Argument(0)); H:=Max(0,Body.Baseline+Lift); Depth:=Max(0,Body.H-Body.Baseline-Lift);
      Value:=Argument(1); if Value<>'' then H:=Max(0,Dim(Value,H));
      Value:=Argument(2); if Value<>'' then Depth:=Max(0,Dim(Value,Depth));
      Result.Baseline:=H; Result.H:=H+Depth; Body.Y:=H-Body.Baseline-Lift;
    end;
  finally Dec(NativeBoxDepth); Draft.Free; Content.Free; end;
end;
