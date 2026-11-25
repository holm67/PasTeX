{ SPDX-License-Identifier: GPL-3.0-or-later }
function TParagraphDraft.EnvironmentBox(Node:TMathNode; Size,Width:Integer):TDraftBox;
var D:TParagraphDraft; Body,Title,Option,Field:TMathNode; B,Header:TDraftBox;
    P,I,Target,Rule,Separation,LeftPad,RightPad,TopPad,BottomPad,Top,Arc,OuterArc:Integer;
    Value,Settings,Name,Raw,Position,Inner,HeightSpec:string; Options:TStringList; Points:Double;
  procedure ReadOptions(const Text:string; Depth:Integer=0);
  var Entry:TDiagramOption; V:string;
  begin
    if Depth>8 then Exit;
    for Entry in DiagramOptions(Text) do begin
      V:=Trim(Entry.Value);
      if (Length(V)>=2) and (V[1]='{') and (V[Length(V)]='}') then V:=Copy(V,2,Length(V)-2);
      if (V='') and (Options.Values[Entry.Name+'/.style']<>'') then ReadOptions(Options.Values[Entry.Name+'/.style'],Depth+1)
      else begin
        if (V='') and (Pos('=',Entry.Original)=0) then V:='true';
        Options.Values[Entry.Name]:=V;
      end;
    end;
  end;
  function Dimension(const Key,Default:string):Integer;
  begin
    Value:=Options.Values[Key]; if Value='' then Value:=Default;
    Result:=DraftDimension(Value,MeasureEm(Size),Target,0,Points);
  end;
  function ColorOption(const Key,Default:string):TColor;
  var V:string;
  begin V:=Options.Values[Key]; if V='' then V:=Default; Result:=NamedColor(V); end;
  function Content(N:TMathNode; W:Integer; Color:TColor; const Style:string):TDraftBox;
  begin
    D:=TParagraphDraft.Create;
    try
      InheritDraft(D);
      ApplyTextStyle(D.TextStyleSeed,Style,Directory); D.TextColorSeed:=Color;
      { Keep the document's point-to-pixel scale; TextStyleSeed already carries
        the inherited font size. Scaling both would enlarge the contents twice. }
      D.Layout(FCanvas,N,Max(40,W)+20,True,FMathBaseSize,nil,FSource,FScale,MeasureEm(FMathBaseSize));
      Result:=D.DetachContent(Max(1,W));
    finally D.Free; end;
  end;
begin
  if NativeBoxDepth>=16 then Exit(DefinitionBox(Node,Size,Width));
  Inc(NativeBoxDepth);
  try
  Result:=TDraftBox.Create; Result.ID:=Node.ID; Body:=nil; Title:=nil;
  for I:=0 to Node.Children.Count-1 do begin
    Field:=TMathNode(Node.Children[I]);
    if Field.Kind<>mkOptional then Body:=Field
    else for P:=0 to Field.Children.Count-1 do begin
      Option:=TMathNode(Field.Children[P]); if Option.Text='@boxtitle' then Title:=Option;
    end;
  end;
  if Body=nil then Exit;
  if Node.Text='minipage' then begin
    P:=1; ReadTeXCommand(Node.Prefix,P); ReadTeXGroup(Node.Prefix,P,'{','}');
    Position:=ReadTeXGroup(Node.Prefix,P,'[',']');
    HeightSpec:=ReadTeXGroup(Node.Prefix,P,'[',']');
    Inner:=ReadTeXGroup(Node.Prefix,P,'[',']'); if Inner='' then Inner:=Position;
    Value:=ReadTeXGroup(Node.Prefix,P,'{','}'); Points:=MeasureEm(FMathBaseSize)/MathFontPoints(0);
    Target:=Max(1,DraftDimension(Value,MeasureEm(Size),Width,Width,Points));
    B:=Content(Body,Target,FDefaultColor,''); Result.Children.Add(B); Result.W:=Target;
    if (B.H=0) and not HideEditingMarks and (B.Children.Count>0) then begin
      Header:=TDraftBox(B.Children[0]); Header.Shape:=12; Header.Color:=clGray;
      Header.W:=Max(16,Header.W); B.H:=Header.H; B.Baseline:=Header.Baseline;
    end;
    PositionParagraphBox(Result,B,Size,Position,Inner,HeightSpec);
    if not HideEditingMarks and not HideEnvironmentCaptions then begin
      Header:=EditingCaption('minipage'); Header.Y:=Result.H+3;
      Result.Children.Add(Header); Inc(Result.H,Header.H+4);
    end;
    Exit;
  end;
  if (Node.Text='wrapfigure') or (Node.Text='wraptable') then begin
    Result.Free; Result:=Content(Body,Width,FDefaultColor,''); Result.ID:=Node.ID; Exit;
  end;
  Options:=TStringList.Create;
  try
    Settings:=HeadingContext; P:=1;
    while P<=Length(Settings) do begin
      if Settings[P]='%' then begin while (P<=Length(Settings)) and (Settings[P]<>#10) do Inc(P); Continue; end;
      if Settings[P]<>'\' then begin Inc(P); Continue; end;
      I:=P; if ReadTeXDefinition(Settings,P) then Continue; P:=I; Name:=ReadTeXCommand(Settings,P);
      if Name='tcbset' then ReadOptions(ReadTeXGroup(Settings,P,'{','}'));
    end;
    P:=1; ReadTeXCommand(Node.Prefix,P); ReadTeXGroup(Node.Prefix,P,'{','}');
    Value:=ReadTeXGroup(Node.Prefix,P,'[',']');
    for I:=0 to Node.Children.Count-1 do begin
      Option:=TMathNode(Node.Children[I]);
      if Option.Kind=mkOptional then begin Raw:=Option.TeX; P:=1; Value:=ReadTeXGroup(Raw,P,'[',']'); Break; end;
    end;
    ReadOptions(Value); Target:=Width; Points:=MeasureEm(Size)/MathFontPoints(0);
    if Options.Values['width']<>'' then Target:=EnsureRange(Dimension('width','0pt'),40,Max(40,Width));
    Rule:=Max(0,Dimension('boxrule','0.5mm')); Separation:=Dimension('boxsep','1mm');
    LeftPad:=Rule+Separation+Dimension('left','4mm'); RightPad:=Rule+Separation+Dimension('right','4mm');
    TopPad:=Rule+Separation+Dimension('top','2mm'); BottomPad:=Rule+Separation+Dimension('bottom','2mm');
    Arc:=Max(0,Dimension('arc','1mm')); OuterArc:=Arc+Rule;
    if Options.Values['outer arc']<>'' then OuterArc:=Max(0,Dimension('outer arc','0pt'));
    if (Options.Values['sharp corners']='true') or (Options.Values['sharpish corners']='true') then begin Arc:=0; OuterArc:=0; end;
    Result.Shape:=21; Result.Color:=ColorOption('colframe','black!75'); Result.FillColor:=ColorOption('colback','black!5');
    Result.AccentHeight:=Rule; Result.AccentWidth:=2*OuterArc; Result.BoxInnerArc:=2*Arc; Top:=0;
    if (Title<>nil) and (Title.Children.Count>0) then begin
      I:=Rule+Separation+Dimension('lefttitle',Options.Values['left']);
      if Options.Values['lefttitle']='' then I:=LeftPad;
      Header:=Content(Title,Max(40,Target-I-RightPad),ColorOption('coltitle','white'),Options.Values['fonttitle']);
      Header.X:=I; Header.Y:=Rule+Separation+Dimension('toptitle','0pt');
      Top:=Header.Y+Header.H+Separation+Dimension('bottomtitle','0pt');
      Result.BoxTitleHeight:=Top+Rule; Result.BoxTitleColor:=Result.Color;
      if Options.Values['colbacktitle']<>'' then Result.BoxTitleColor:=ColorOption('colbacktitle','black!50')
      else if Options.Values['title filled']='true' then Result.BoxTitleColor:=NamedColor('black!50');
      Result.Children.Add(Header);
    end;
    Name:=Options.Values['coltext']; if Name='' then Name:=Options.Values['colupper']; if Name='' then Name:='black';
    B:=Content(Body,Max(40,Target-LeftPad-RightPad),NamedColor(Name),Options.Values['fontupper']);
    B.X:=LeftPad; B.Y:=Top+TopPad;
    Result.W:=Target; Result.H:=Max(2*(Arc+Rule),B.Y+B.H+BottomPad);
    Result.Baseline:=B.Y+B.Baseline; Result.Children.Add(B);
  finally Options.Free; end;
  finally Dec(NativeBoxDepth); end;
end;
