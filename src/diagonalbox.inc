{ SPDX-License-Identifier: GPL-3.0-or-later }
threadvar DiagonalBoxDepth:Integer;
function TParagraphDraft.DiagonalBox(Node:TMathNode; Size:Integer):TDraftBox;
var Options:TStringList; Entry:TDiagramOption; Field,Content:TMathNode; Draft:TParagraphDraft;
    Labels:array[0..2] of TDraftBox; Seed:TTeXTextStyle; Direction,Value,Settings:string;
    I,Count,Width,BoxHeight,Left,Right,OuterLeft,OuterRight,Stroke,LineHeight,Middle,StrutAbove,StrutBelow:Integer;
    Points,Stretch,XA,XB,XM,YA,YB,YM,S,T,U,V,Delta,Root:Double;
  function Dimension(const Name:string; Default:Integer):Integer;
  var Code:string; Negative:Boolean;
  begin
    Code:=Options.Values[Name]; if Code='' then Exit(Default);
    Code:=Trim(Code); Negative:=Copy(Code,1,1)='-'; if Negative then Delete(Code,1,1);
    if Pos('\line',Code)>0 then Result:=DraftDimension(StringReplace(Code,'\line','\textwidth',[rfReplaceAll]),
      MeasureEm(Size),LineHeight,Default,Points)
    else Result:=DraftDimension(Code,MeasureEm(Size),FMathWidth,Default,Points);
    if Negative then Result:=-Result;
  end;
  function HeaderLabel(Argument:Integer):TDraftBox;
  var Child:TDraftBox; K,Top,Bottom,Base,Above:Integer;
  begin
    Field:=TMathNode(Node.Children[Argument]); Content:=PreviewArgument(Field,False,Macros); Draft:=TParagraphDraft.Create;
    try
      Content.Kind:=mkRow; Content.Prefix:=''; Content.Suffix:='';
      Draft.Macros:=Macros; Draft.Directory:=Directory; Draft.TeXEngine:=TeXEngine;
      Draft.Context:=Context; Draft.ContextOffset:=ContextOffset; Draft.HeadingContext:=HeadingContext;
      Draft.StyleSeed:=FStyles; Draft.TextStyleSeed:=Seed; Draft.TextColorSeed:=FDefaultColor;
      Draft.HideEditingMarks:=HideEditingMarks; Draft.SuppressParagraphIndent:=True;
      Draft.DocumentFontSize:=DocumentFontSize; Draft.PreserveColors:=PreserveColors;
      Draft.Layout(FCanvas,Content,65536,True,FMathBaseSize,nil,FSource,FScale,MeasureEm(FMathBaseSize));
      Result:=Draft.DetachRootBox; Result.W:=0; Top:=MaxInt; Bottom:=0; Base:=StrutAbove;
      for K:=0 to Result.Children.Count-1 do begin
        Child:=TDraftBox(Result.Children[K]); Dec(Child.X,10); Dec(Child.Y,10);
        Result.W:=Max(Result.W,Child.X+Child.W);
        if (Child.Text<>'') or (Child.Shape<>0) or (Child.Children.Count>0) then begin
          if Top=MaxInt then Base:=Child.Y+Child.Baseline;
          Top:=Min(Top,Child.Y+Draft.InkTop(Child)); Bottom:=Max(Bottom,Child.Y+Draft.InkBottom(Child));
        end;
      end;
      if Top=MaxInt then Top:=Base;
      Above:=Max(StrutAbove,Base-Top); Result.Baseline:=Above; Result.H:=Above+Max(StrutBelow,Bottom-Base);
      for K:=0 to Result.Children.Count-1 do Inc(TDraftBox(Result.Children[K]).Y,Above-Base);
    finally Draft.Free; Content.Free; end;
  end;
  procedure Line(X1,Y1,X2,Y2:Integer);
  var K:Integer;
  begin
    K:=Length(Result.Lines); SetLength(Result.Lines,K+1);
    Result.Lines[K].A:=Point(X1+OuterLeft,Y1); Result.Lines[K].B:=Point(X2+OuterLeft,Y2); Result.Lines[K].Width:=Stroke;
  end;
begin
  Result:=nil; if (Node.Children.Count<3) or (DiagonalBoxDepth>=8) then Exit;
  Inc(DiagonalBoxDepth); Options:=TStringList.Create;
  Result:=TDraftBox.Create; Result.ID:=Node.ID; Result.Shape:=9; Result.Size:=Size; Result.Color:=FDefaultColor;
  try
   try
    Field:=TMathNode(Node.Children[0]); Value:=Field.TeX;
    if Field.Prefix<>'' then Value:=Copy(Value,Length(Field.Prefix)+1,Length(Value)-Length(Field.Prefix)-Length(Field.Suffix)) else Value:=Field.Text;
    for Entry in DiagramOptions(Value) do Options.Values[Entry.Name]:=Entry.Value;
    Seed:=FTextStyle; ApplyTextStyle(Seed,Options.Values['font'],Directory);
    Points:=MeasureEm(FMathBaseSize)/MathFontPoints(0); LineHeight:=Round(FTextStyle.Baseline*FTextStyle.Spread*Points);
    Settings:=HeadingContext+Copy(FSource,1,MathSourceOffset(Node)-Length(Node.Prefix));
    Stretch:=DraftArrayStretch(Settings);
    StrutAbove:=Round((LineHeight*0.7+DraftDimension(DraftSetting(Settings,'extrarowheight','0pt'),
      MeasureEm(Size),FMathWidth,0,Points))*Stretch); StrutBelow:=Round(LineHeight*0.3*Stretch);
    Left:=DraftDimension(DraftSetting(Settings,'tabcolsep','6pt'),MeasureEm(Size),FMathWidth,Round(6*Points),Points);
    OuterLeft:=-Left; Right:=Left; OuterRight:=-Right;
    Left:=Dimension('leftsep',Dimension('innerleftsep',Left)); Right:=Dimension('rightsep',Dimension('innerrightsep',Right));
    if Options.Values['leftsep']<>'' then OuterLeft:=-Left; if Options.Values['rightsep']<>'' then OuterRight:=-Right;
    OuterLeft:=Dimension('outerleftsep',OuterLeft); OuterRight:=Dimension('outerrightsep',OuterRight);
    Value:=Options.Values['trim']; if Pos('l',Value)>0 then begin Left:=0; OuterLeft:=0; end;
    if Pos('r',Value)>0 then begin Right:=0; OuterRight:=0; end;
    Direction:=Options.Values['dir']; if Direction='' then Direction:='NW';
    Stroke:=Max(1,Dimension('linewidth',Round(0.4*Points)));
    Count:=Min(3,Node.Children.Count-1);
    for I:=0 to Count-1 do begin Labels[I]:=HeaderLabel(I+1); Result.Children.Add(Labels[I]); end;
    Width:=Dimension('width',0); BoxHeight:=Dimension('height',0);
    if Options.Values['innerwidth']<>'' then Width:=Dimension('innerwidth',0)+Left+Right;
    if Count=2 then begin
      if Width=0 then Width:=2*Max(Labels[0].W+Left,Labels[1].W+Right)+Left+Right;
      if BoxHeight=0 then BoxHeight:=Labels[0].H+Labels[1].H;
      Labels[0].X:=Left+OuterLeft; Labels[1].X:=Width-Right-Labels[1].W+OuterLeft;
      if (Direction='NE') or (Direction='SW') then begin
        Labels[0].Y:=0; Labels[1].Y:=BoxHeight-Labels[1].H; Line(0,BoxHeight,Width,0);
      end else begin Labels[0].Y:=BoxHeight-Labels[0].H; Labels[1].Y:=0; Line(0,0,Width,BoxHeight); end;
    end else begin
      { Geometry of diagbox's three-part header, solved from its label sizes. }
      XA:=Labels[0].W+Left; XB:=Labels[2].W+Right; XM:=Labels[1].W+Right;
      if (Direction='NW') or (Direction='SW') then XM:=Labels[1].W+Left;
      YA:=Labels[0].H; YB:=Labels[2].H; YM:=Labels[1].H;
      S:=XB+XM; T:=YA+YM; U:=XA*YM-XM*YB; V:=S*T-XA*YB;
      Delta:=Sqr(U+V)+4*XA*(T-YB)*(XM*(YB-YM)-XB*YM); Root:=Sqrt(Max(0,Delta));
      if Width=0 then begin
        if (T>YB) and (Delta>=0) then Width:=Round((U+V+Root)/(2*(T-YB)));
        if Width<=0 then Width:=Round(2*(Max(XA,XB)+XM));
      end;
      if BoxHeight=0 then begin
        if (XA<S) and (Delta>=0) then BoxHeight:=Round((U-V-Root)/(2*(XA-S)));
        if BoxHeight<=0 then BoxHeight:=Round(2*(Max(YA,YB)+YM));
      end;
      Labels[0].X:=Left+OuterLeft; Labels[2].X:=Width-Right-Labels[2].W+OuterLeft;
      if (Direction='NW') or (Direction='SW') then Labels[1].X:=Left+OuterLeft
      else Labels[1].X:=Width-Right-Labels[1].W+OuterLeft;
      Middle:=Round(XM);
      case Direction of
        'NE':begin Labels[0].Y:=0; Labels[1].Y:=0; Labels[2].Y:=BoxHeight-Labels[2].H;
          Line(0,BoxHeight,Width-Middle,0); Line(0,BoxHeight,Width,Round(YM)); end;
        'SW':begin Labels[0].Y:=0; Labels[1].Y:=BoxHeight-Labels[1].H; Labels[2].Y:=BoxHeight-Labels[2].H;
          Line(0,BoxHeight-Round(YM),Width,0); Line(Middle,BoxHeight,Width,0); end;
        'SE':begin Labels[0].Y:=BoxHeight-Labels[0].H; Labels[1].Y:=BoxHeight-Labels[1].H; Labels[2].Y:=0;
          Line(0,0,Width-Middle,BoxHeight); Line(0,0,Width,BoxHeight-Round(YM)); end;
        else begin Labels[0].Y:=BoxHeight-Labels[0].H; Labels[1].Y:=0; Labels[2].Y:=0;
          Line(0,Round(YM),Width,BoxHeight); Line(Middle,0,Width,BoxHeight); end;
      end;
    end;
    if Options.Values['linecolor']<>'' then Result.Color:=NamedColor(Options.Values['linecolor']);
    Result.W:=Max(1,Width+OuterLeft+OuterRight); Result.H:=Max(1,BoxHeight);
    Result.Baseline:=Result.H div 2+Round(MeasureEm(Size)*0.25);
   except Result.Free; Result:=nil; raise; end;
  finally Options.Free; Dec(DiagonalBoxDepth); end;
end;
