{ SPDX-License-Identifier: GPL-3.0-or-later }
function TParagraphDraft.PresentationTheme:TBeamerTheme;
begin
  if FBeamerTheme=nil then begin FBeamerTheme:=TBeamerTheme.Create; FBeamerThemeOwner:=True; end;
  if FBeamerThemeOwner and ((FBeamerContext<>HeadingContext+#0+Directory) or
    ((Macros<>nil) and (FBeamerRevision<>Macros.Revision))) then begin
    FBeamerTheme.Load(HeadingContext,Directory); FBeamerContext:=HeadingContext+#0+Directory;
    if Macros<>nil then FBeamerRevision:=Macros.Revision else FBeamerRevision:=0;
  end;
  Result:=FBeamerTheme;
end;
function TParagraphDraft.BeamerContent(Node:TMathNode; Width:Integer; const Style:string; Color:TColor; MeasureOnly:Boolean):TDraftBox;
var Draft:TParagraphDraft;
begin
  Draft:=TParagraphDraft.Create;
  try
    InheritDraft(Draft); Draft.HideEnvironmentCaptions:=True;
    if MeasureOnly then Draft.ShowSourceControls:=False;
    if Color<>clNone then Draft.TextColorSeed:=Color;
    ApplyTextStyle(Draft.TextStyleSeed,Style,Directory);
    Draft.Layout(FCanvas,Node,Max(1,Width)+20,True,FMathBaseSize,nil,FSource,FScale,MeasureEm(FMathBaseSize));
    Result:=Draft.DetachContent(Max(1,Width));
  finally Draft.Free; end;
end;
function TParagraphDraft.BeamerTitlePage(Node:TMathNode; Width:Integer):TDraftBox;
var Theme:TBeamerTheme; Name,Value:string; Part:TMathNode; Band,ElementBox:TDraftBox; Top,Gap:Integer; Points:Double;
begin
  Theme:=PresentationTheme; Result:=TDraftBox.Create; Result.W:=Width; Top:=0;
  Points:=MeasureEm(FMathBaseSize)/MathFontPoints(0); Gap:=Round(8*Points);
  for Name in TStringArray.Create('title','subtitle','author','institute','date','titlegraphic') do begin
    Value:=Theme.Information(Name); if Value='' then Continue;
    Part:=ParseParagraph('\centering '+Value,Macros);
    try ElementBox:=BeamerContent(Part,Max(1,Width-2*Gap),Theme.Font(Name),Theme.Color(Name)); ClearBoxIDs(ElementBox);
    finally Part.Free; end;
    if Name='author' then Inc(Top,Round(FTextStyle.Points*Points));
    Band:=TDraftBox.Create; Band.W:=Width; Band.Y:=Top; Band.Shape:=25; Band.FillColor:=Theme.Color(Name,True);
    ElementBox.X:=Gap; ElementBox.Y:=Gap; Band.H:=ElementBox.H+2*Gap; Band.Children.Add(ElementBox); Result.Children.Add(Band);
    Inc(Top,Band.H);
  end;
  Result.H:=Top+Round(0.5*FTextStyle.Points*Points); Result.Baseline:=0;
end;
function TParagraphDraft.BeamerBox(Node:TMathNode; Size,Width,Slide:Integer):TDraftBox;
var Theme:TBeamerTheme; Settings:TBeamerSettings; Header:TBeamerFrame;
    Projection,Previous:TBeamerProjection; Body,Title,Subtitle,Row,Column,Part:TMathNode;
    B,HeadingBox,SubBox,Band:TDraftBox; I,J,P,Top,Foot,Left,Right,Target,Gap,Used,Count,SlideHeight,BodyHeight,BodyBaseline:Integer;
    Points,Ex,TitleBaseline,TitleDepth:Double; Options,Value,Kind,Style:string; Plain,AtTop,AtBottom,OnlyText:Boolean;
    FontStyle:TTeXTextStyle; Metric:TTeXFontMetric; Zoom:TBeamerZoom; ZoomFactor:Double;
    CropX,CropY,CropW,CropH:Integer;
    FooterEx:Double; FrameNumber,FrameTotal:Integer;
    TheoremInfo:TTheoremInfo; TheoremStyle:string;
  function Content(Part:TMathNode; W:Integer; const Element:string):TDraftBox;
  begin
    Result:=BeamerContent(Part,W,Theme.Font(Element),Theme.Color(Element));
  end;
  function FindTitle(Part:TMathNode; const Role:string):TMathNode;
  var I:Integer;
  begin
    if BeamerNodeRole(Part)=Role then Exit(Part);
    Result:=nil; if Part.Kind=mkFormula then Exit;
    for I:=0 to Part.Children.Count-1 do begin Result:=FindTitle(TMathNode(Part.Children[I]),Role); if Result<>nil then Exit; end;
  end;
  function FirstContent(Part:TMathNode):TMathNode;
  var I:Integer; Role:string;
  begin
    Result:=nil; Role:=BeamerNodeRole(Part);
    if Part.Hidden or (Role='frametitle') or (Role='framesubtitle') or
      ((Part.Kind=mkProse) and (Trim(Part.Text)='')) then Exit;
    if Part.Kind<>mkRow then Exit(Part);
    for I:=0 to Part.Children.Count-1 do begin
      Result:=FirstContent(TMathNode(Part.Children[I])); if Result<>nil then Exit;
    end;
  end;
  function TitleContent(Part:TMathNode; W:Integer; const Element:string):TDraftBox;
  begin
    if Part.Children.Count>0 then Result:=Content(TMathNode(Part.Children[0]),W,Element)
    else Result:=TDraftBox.Create;
  end;
  procedure Background(Box:TDraftBox; Color:TColor);
  begin if Color<>clNone then begin Box.Shape:=25; Box.FillColor:=Color; end; end;
  procedure Margins;
  begin
    Settings:=Theme.Settings;
    Value:=Theme.Dimension('text margin left');
    if Value<>'' then Settings.LeftMargin:=Max(0,TeXStyleDimension(Value,FTextStyle.Points));
    Value:=Theme.Dimension('text margin right');
    if Value<>'' then Settings.RightMargin:=Max(0,TeXStyleDimension(Value,FTextStyle.Points));
  end;
  function ZoomForSlide(Part:TMathNode):Boolean;
  var I,Pause:Integer; Selection:TBeamerOverlay;
  begin
    Result:=False;
    if BeamerNodeRole(Part)='framezoom' then begin
      if not ReadBeamerZoom(Part.TeX,1,Zoom) then Exit;
      Pause:=1; Selection:=DecodeBeamerOverlay(Zoom.ZoomSlides,Settings.Mode,Slide,Pause);
      Exit(Selection.Active);
    end;
    for I:=0 to Part.Children.Count-1 do if ZoomForSlide(TMathNode(Part.Children[I])) then Exit(True);
  end;
  function ExpandedSource(Part:TMathNode):Boolean;
  var I:Integer;
  begin
    if (Part.SourcePreview<>nil) or Part.SourceExpanded then Exit(True);
    for I:=0 to Part.Children.Count-1 do if ExpandedSource(TMathNode(Part.Children[I])) then Exit(True);
    Result:=False;
  end;
  procedure MeasureCollapsedBody;
  var Root:TMathNode; Box:TDraftBox; NativeProjection,SavedProjection:TBeamerProjection;
  begin
    Root:=ParseParagraph(Row.TeX,Macros); NativeProjection:=TBeamerProjection.Create; SavedProjection:=FBeamerProjection;
    try
      NativeProjection.Project(Root,Slide,Settings.Mode,Header.DefaultOverlay); FBeamerProjection:=NativeProjection;
      Box:=BeamerContent(Root,Target,Theme.Font('normal text'),Theme.Color('normal text'),True);
      try BodyHeight:=Box.H; BodyBaseline:=Box.Baseline; finally Box.Free; end;
    finally FBeamerProjection:=SavedProjection; NativeProjection.Free; Root.Free; end;
  end;
  procedure Overprint;
  var Group:TMathNode; Child:TMathNode; I:Integer; Box:TDraftBox;
    procedure AddGroup;
    begin
      if Group.Children.Count=0 then Exit;
      Box:=BeamerContent(Group,Target); Result.Children.Add(Box);
      Result.Baseline:=Max(Result.Baseline,Box.Baseline); Group.Children.Clear;
    end;
  begin
    P:=1; ReadTeXCommand(Node.Prefix,P); ReadTeXGroup(Node.Prefix,P,'{','}');
    Value:=ReadTeXGroup(Node.Prefix,P,'[',']');
    Target:=Max(1,DraftDimension(Value,MeasureEm(Size),Width,Width,Points)); Result.W:=Target;
    Group:=TMathNode.Create(mkRow); Group.Children.OwnsObjects:=False;
    try
      for I:=0 to Body.Children.Count-1 do begin
        Child:=TMathNode(Body.Children[I]);
        if (BeamerNodeRole(Child)='onslide') and (Child.Children.Count=0) then AddGroup
        else Group.Children.Add(Child);
      end;
      AddGroup;
    finally Group.Free; end;
    for I:=0 to Result.Children.Count-1 do begin
      Box:=TDraftBox(Result.Children[I]);
      if (FBeamerProjection<>nil) and (FBeamerProjection.Slide>0) then Box.Y:=Result.Baseline-Box.Baseline
      else Box.Y:=Result.H;
      Result.H:=Max(Result.H,Box.Y+Box.H);
    end;
  end;
  function TheoremHeading(const Element:string):TDraftBox;
  var Caption,OpenText,CloseText,Group,Optional:TMathNode; Mark:TContextMark; I:Integer; Text:string;
  begin
    Text:=Node.Text; if Text<>'' then Text[1]:=UpCase(Text[1]);
    if TheoremInfo<>nil then Text:=TheoremInfo.Title;
    if (Context<>nil) and (Theme.Template('theorems')='numbered') then begin
      Mark:=Context.Mark(ContextOffset+MathSourceOffset(Node)-Length(Node.Prefix));
      if (Mark<>nil) and (Mark.Number<>'') then Text:=Text+' '+Mark.Number;
    end;
    Optional:=nil;
    for I:=0 to Node.Children.Count-1 do begin
      Part:=TMathNode(Node.Children[I]);
      if (Part.Kind=mkOptional) and (Part.Children.Count>0) and (TMathNode(Part.Children[0]).TeX<>'') then
        Optional:=TMathNode(Part.Children[0]);
    end;
    Group:=TMathNode.Create(mkRow); Group.ID:=-1; Group.Children.OwnsObjects:=False;
    Caption:=TMathNode.Create(mkProse,Text); Caption.ID:=-1;
    OpenText:=TMathNode.Create(mkProse,' ('); OpenText.ID:=-1;
    CloseText:=TMathNode.Create(mkProse,')'); CloseText.ID:=-1;
    try
      if (Node.Text<>'proof') or (Optional=nil) then Group.Children.Add(Caption);
      if Optional<>nil then begin
        if Node.Text<>'proof' then Group.Children.Add(OpenText);
        Group.Children.Add(Optional);
        if Node.Text<>'proof' then Group.Children.Add(CloseText);
      end;
      Result:=Content(Group,Max(1,Width-2*Gap),Element);
    finally Group.Free; Caption.Free; OpenText.Free; CloseText.Free; end;
  end;
begin
  Theme:=PresentationTheme; Result:=TDraftBox.Create; Result.W:=Width; Result.ID:=-1;
  Points:=MeasureEm(FMathBaseSize)/MathFontPoints(0); Body:=nil;
  for I:=0 to Node.Children.Count-1 do if TMathNode(Node.Children[I]).Kind=mkRow then Body:=TMathNode(Node.Children[I]);
  if Body=nil then begin Result.Free; Exit(BeamerContent(Node,Width)); end;
  if Node.Text='overprint' then begin Overprint; Exit; end;
  if Node.Text='columns' then begin
    P:=1; ReadTeXCommand(Node.Prefix,P); ReadTeXGroup(Node.Prefix,P,'{','}');
    Options:=ReadTeXGroup(Node.Prefix,P,'[',']'); Used:=0; Count:=0; Margins;
    OnlyText:=Pos('onlytextwidth',Options)>0;
    for I:=0 to Body.Children.Count-1 do begin
      Column:=TMathNode(Body.Children[I]); if (Column.Kind<>mkEnvironment) or (Column.Text<>'column') then Continue;
      P:=1; if ReadTeXCommand(Column.Prefix,P)='begin' then ReadTeXGroup(Column.Prefix,P,'{','}'); ReadBeamerOverlay(Column.Prefix,P);
      Value:=ReadTeXGroup(Column.Prefix,P,'[',']'); Style:=ReadTeXGroup(Column.Prefix,P,'{','}');
      Target:=Max(1,DraftDimension(Style,MeasureEm(Size),Width,Width div 2,Points));
      B:=Content(TMathNode(Column.Children.Last),Target,'normal text'); B.Row:=Ord((Value='t') or (Value='T') or (Pos('t',Options)>0));
      Part:=TMathNode(Column.Children.Last);
      for J:=0 to Part.Children.Count-1 do begin
        Row:=TMathNode(Part.Children[J]); if (Row.Kind=mkProse) and (Trim(Row.Text)='') then Continue;
        if (Row.Kind=mkEnvironment) and ((Row.Text='block') or (Row.Text='alertblock') or (Row.Text='exampleblock')) then B.Baseline:=0;
        Break;
      end;
      Result.Children.Add(B); Inc(Used,Target); Inc(Count); Result.H:=Max(Result.H,B.H);
    end;
    Gap:=0; Left:=0;
    if OnlyText then begin if Count>1 then Gap:=Max(0,(Width-Used) div (Count-1)); end
    else begin
      Gap:=Max(0,(Width+Round((Settings.LeftMargin+Settings.RightMargin)*Points)-Used) div Max(1,Count+1));
      Left:=Gap-Round(Settings.LeftMargin*Points);
    end;
    Top:=0; for I:=0 to Result.Children.Count-1 do Top:=Max(Top,TDraftBox(Result.Children[I]).Baseline);
    Result.H:=0;
    for I:=0 to Result.Children.Count-1 do begin
      B:=TDraftBox(Result.Children[I]); B.X:=Left; Inc(Left,B.W+Gap);
      if B.Row>0 then B.Y:=Top-B.Baseline;
      Result.H:=Max(Result.H,B.Y+B.H);
    end;
    for I:=0 to Result.Children.Count-1 do begin B:=TDraftBox(Result.Children[I]); if B.Row=0 then B.Y:=(Result.H-B.H) div 2; end;
    Result.Baseline:=Top; Exit;
  end;
  TheoremInfo:=nil; if Context<>nil then TheoremInfo:=Context.Theorem(Node.Text);
  TheoremStyle:=BeamerTheoremStyle(Node.Text); if TheoremInfo<>nil then TheoremStyle:=TheoremInfo.Style;
  if (Node.Text='block') or (Node.Text='alertblock') or (Node.Text='exampleblock') or (TheoremStyle<>'') then begin
    Title:=FindTitle(Node,'blocktitle'); Kind:='';
    if Node.Text='alertblock' then Kind:=' alerted' else if Node.Text='exampleblock' then Kind:=' example';
    if TheoremStyle='example' then Kind:=' example';
    Gap:=0; if Theme.Color('block body'+Kind,True)<>clNone then Gap:=Round(MeasureEm(Size)*0.33);
    Top:=Round(6*Points); Left:=Top;
    if (Title<>nil) or (TheoremStyle<>'') then begin
      if TheoremStyle<>'' then B:=TheoremHeading('block title'+Kind)
      else B:=TitleContent(Title,Max(1,Width-2*Gap),'block title'+Kind);
      B.X:=Gap;
      B.Y:=Max(0,Round(FTextStyle.Baseline*Points)-B.Baseline)+Gap;
      Band:=TDraftBox.Create; Band.Y:=Top; Band.W:=Width; Band.H:=B.Y+B.H+Gap; Background(Band,Theme.Color('block title'+Kind,True));
      Band.Children.Add(B); Result.Children.Add(Band); Left:=Top+B.Y+B.Baseline; Inc(Top,Band.H);
    end;
    Style:=Theme.Font('block body'+Kind); if TheoremStyle='plain' then Style:=Style+'\itshape';
    B:=BeamerContent(Body,Max(1,Width-2*Gap),Style,Theme.Color('block body'+Kind)); B.X:=Gap;
    B.Y:=Max(Gap,Left+Round(FTextStyle.Baseline*Points)-Top-B.Baseline);
    Band:=TDraftBox.Create; Band.Y:=Top; Band.W:=Width; Band.H:=B.Y+B.H+Gap;
    Background(Band,Theme.Color('block body'+Kind,True)); Band.Children.Add(B); Result.Children.Add(Band);
    Result.H:=Top+Band.H; Result.Baseline:=0; Exit;
  end;
  if Node.Text='overlayarea' then begin
    P:=1; ReadTeXCommand(Node.Prefix,P); ReadTeXGroup(Node.Prefix,P,'{','}');
    Value:=ReadTeXGroup(Node.Prefix,P,'{','}'); Target:=Max(1,DraftDimension(Value,MeasureEm(Size),Width,Width,Points));
    Value:=ReadTeXGroup(Node.Prefix,P,'{','}'); Result.H:=Max(0,DraftDimension(Value,MeasureEm(Size),Width,0,Points));
    B:=BeamerContent(Body,Target); Result.W:=Target; Result.Children.Add(B); Result.Baseline:=B.Baseline; Exit;
  end;
  if Node.Text<>'frame' then begin Result.Free; Exit(BeamerContent(Body,Width)); end;
  Margins; ReadBeamerFrame(Node.TeX,1,Header);
  Options:=','+StringReplace(Header.Options,' ','',[rfReplaceAll])+',';
  Plain:=Pos(',plain,',Options)>0; AtTop:=Settings.TopAligned; AtBottom:=Pos(',b,',Options)>0;
  if Pos(',t,',Options)>0 then AtTop:=True else if Pos(',c,',Options)>0 then AtTop:=False;
  Left:=Round(Settings.LeftMargin*Points); Right:=Round(Settings.RightMargin*Points);
  SlideHeight:=Round(Settings.PaperHeight*Points); Foot:=0;
  FooterEx:=0;
  if not Plain and (Theme.Template('outer')='infolines') and
    not (Theme.HasTemplate('footline') and (Theme.Template('footline')='')) then begin
    FontStyle:=FTextStyle; ApplyTextStyle(FontStyle,Theme.Font('footline'),Directory);
    Metric:=TeXFontMetric(TextFontShape(FontStyle.Family,FontStyle.Series,FontStyle.Shape,FontStyle.Points,FontStyle.Encoding));
    FooterEx:=FontStyle.Points*0.44444;
    if (Metric<>nil) and (Length(Metric.Parameters)>4) then FooterEx:=FontStyle.Points*Metric.Parameters[4];
    FooterEx:=FooterEx*Points; Foot:=Round(3.25*FooterEx);
  end;
  Target:=Max(20,Width-Left-Right); Top:=0; Previous:=FBeamerProjection; Projection:=TBeamerProjection.Create;
  Row:=TMathNode.Create(mkRow); Row.Children.OwnsObjects:=False;
  try
    Projection.Project(Node,Slide,Settings.Mode,Header.DefaultOverlay); FBeamerProjection:=Projection;
    Title:=FindTitle(Node,'frametitle'); Subtitle:=FindTitle(Node,'framesubtitle'); HeadingBox:=nil; SubBox:=nil;
    if Title<>nil then HeadingBox:=TitleContent(Title,Max(20,Width-Round(0.6*72.27/2.54*Points)),'frametitle');
    if Subtitle<>nil then SubBox:=TitleContent(Subtitle,Max(20,Width-Round(0.6*72.27/2.54*Points)),'framesubtitle');
    if HeadingBox<>nil then begin
      FontStyle:=FTextStyle; ApplyTextStyle(FontStyle,Theme.Font('frametitle'),Directory);
      Metric:=TeXFontMetric(TextFontShape(FontStyle.Family,FontStyle.Series,FontStyle.Shape,FontStyle.Points,FontStyle.Encoding));
      Ex:=FontStyle.Points*0.44444; if (Metric<>nil) and (Length(Metric.Parameters)>4) then Ex:=FontStyle.Points*Metric.Parameters[4];
      { Default frametitle: an empty vbox, -1ex, a strut line and -1ex.
        The empty vbox makes TeX insert baseline glue before the title line. }
      TitleBaseline:=1+0.3*72.27/2.54-Ex+FontStyle.Baseline;
      HeadingBox.X:=Round(0.3*72.27/2.54*Points); HeadingBox.Y:=Round(TitleBaseline*Points)-HeadingBox.Baseline;
      TitleDepth:=Max(FontStyle.Baseline*0.3,(HeadingBox.H-HeadingBox.Baseline)/Points);
      Top:=Round((TitleBaseline+TitleDepth-Ex+0.25*FTextStyle.Points)*Points);
      if Theme.Color('frametitle',True)<>clNone then Inc(Top,Round(0.3*72.27/2.54*Points));
      Band:=TDraftBox.Create; Band.W:=Width; Band.Children.Add(HeadingBox);
      if SubBox<>nil then begin SubBox.X:=HeadingBox.X; SubBox.Y:=Top; Inc(Top,SubBox.H); Band.Children.Add(SubBox); SubBox:=nil; end;
      Band.H:=Top;
      Background(Band,Theme.Color('frametitle',True)); Result.Children.Add(Band);
      { Continuous editing shows the current title command below its ink.
        Keep that annotation clear of the first body line. }
      if not PageLayout then Inc(Top,Max(18,Round(18*FScale)));
    end;
    SubBox.Free;
    for I:=0 to Node.Children.Count-1 do begin
      Part:=TMathNode(Node.Children[I]);
      if (Part<>Title) and (Part<>Subtitle) then Row.Children.Add(Part);
    end;
    B:=Content(Row,Target,'normal text'); B.X:=Left;
    if PageLayout then begin
      BodyHeight:=B.H; BodyBaseline:=B.Baseline;
      if ExpandedSource(Row) then MeasureCollapsedBody;
      Gap:=Max(0,SlideHeight-Foot-Top-BodyHeight+BodyBaseline-Round((4+FTextStyle.Baseline)*Points));
      if AtTop then Gap:=Round(0.2*72.27/2.54*Points) else if not AtBottom then Gap:=Round(Gap*0.4);
      B.Y:=Top+Gap+Round(FTextStyle.Baseline*Points)-BodyBaseline;
      Part:=FirstContent(Row);
      { framezoom starts with par/nointerlineskip in beamerbaseframesize.sty.
        A leading zoom command suppresses the first line's baseline glue. }
      if (Part<>nil) and (BeamerNodeRole(Part)='framezoom') then B.Y:=Top+Gap-InkTop(B);
      Result.H:=SlideHeight+Max(0,B.H-BodyHeight);
    end else begin B.Y:=Top+Round(MeasureEm(Size)*0.4); Result.H:=B.Y+B.H+Round(MeasureEm(Size)); end;
    Result.Baseline:=B.Y+B.Baseline;
    if PageLayout and (Slide>0) and ZoomForSlide(Node) then begin
      CropX:=DraftDimension(Zoom.X,MeasureEm(Size),Target,0,Points);
      CropY:=DraftDimension(Zoom.Y,MeasureEm(Size),Target,0,Points);
      CropW:=DraftDimension(Zoom.Width,MeasureEm(Size),Target,0,Points);
      CropH:=DraftDimension(Zoom.Height,MeasureEm(Size),Target,0,Points);
      if (CropW>0) and (CropH>0) then begin
        { beamerbaseframesize magnifies the raw frame vbox, before its
          centering/top glue. The usable height excludes foot and top skips. }
        Gap:=0; if AtTop then Gap:=Round(0.2*72.27/2.54*Points);
        Used:=Max(1,SlideHeight-Foot-Top-Gap-Round((4*Ord(not Plain)-Ord(HeadingBox<>nil))*Points));
        ZoomFactor:=EnsureRange(Min(Width/CropW,Used/CropH),0.01,64);
        B.X:=-CropX; B.Y:=-InkTop(B)-CropY; B.Scale(ZoomFactor);
        Band:=TDraftBox.Create; Band.Y:=Top; Band.W:=Width; Band.H:=Used+Round(4*Points);
        Band.ClipChildren:=True; Band.Children.Add(B); B:=Band;
      end;
    end;
    Result.Children.Add(B); Result.ClipChildren:=PageLayout; Background(Result,Theme.Color('background canvas',True));
    if Foot>0 then begin
      if not PageLayout then Inc(Result.H,Foot);
      FrameNumber:=1; FrameTotal:=1;
      if Context<>nil then begin
        FrameNumber:=Context.CounterBefore('framenumber',ContextOffset+MathSourceOffset(Node)-Length(Node.Prefix)+1);
        FrameTotal:=Context.CounterBefore('framenumber',MaxInt);
      end;
      for J:=0 to 2 do begin
        case J of
          0:begin
            Kind:='author in head/foot'; Value:=Theme.Information('shortauthor');
            if Theme.Information('shortinstitute')<>'' then Value:=Value+'~~('+Theme.Information('shortinstitute')+')';
            Value:='\centering '+Value;
          end;
          1:begin Kind:='title in head/foot'; Value:='\centering '+Theme.Information('shorttitle'); end;
          else begin
            Kind:='date in head/foot'; Value:='\hfill '+Theme.Information('shortdate')+'{}\hfill ';
            Style:=Theme.Template('page number in head/foot');
            if (Style='framenumber') or (Style='totalframenumber') then begin
              Value:=Value+IntToStr(FrameNumber);
              if Style='totalframenumber' then Value:=Value+'\,/\,'+IntToStr(FrameTotal);
            end;
          end;
        end;
        Part:=ParseParagraph(Value,Macros);
        Target:=Width div 3; if J=2 then Dec(Target,Round(4*FooterEx));
        try B:=BeamerContent(Part,Target,Theme.Font('footline')+Theme.Font(Kind),Theme.Color(Kind)); ClearBoxIDs(B); finally Part.Free; end;
        Band:=TDraftBox.Create; Band.X:=J*Width div 3; Band.Y:=Result.H-Foot; Band.W:=Width div 3; Band.H:=Foot;
        if J=2 then B.X:=Round(2*FooterEx);
        B.Y:=Round(2.25*FooterEx)-B.Baseline;
        Background(Band,Theme.Color(Kind,True)); Band.Children.Add(B); Result.Children.Add(Band);
      end;
    end;
  finally FBeamerProjection:=Previous; Projection.Free; Row.Free; end;
end;
