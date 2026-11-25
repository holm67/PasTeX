{ SPDX-License-Identifier: GPL-3.0-or-later }
destructor TNativePage.Destroy;
begin ReleaseRenderCache; inherited; end;
procedure TNativePage.ReleaseRenderCache;
var I:Integer;
begin for I:=0 to High(FRows) do begin FreeAndNil(FRows[I]); FreeAndNil(FTrees[I]); end; end;
procedure TNativePage.Configure(const Preamble,Directory,Engine:string; Registry:TMacroRegistry;
  const Style:TPageFurniture; Scale:Double; TextLeft,TextTop,TextWidth,TextHeight:Integer);
var I:Integer; Rebuild:Boolean;
begin
  Rebuild:=(FPreamble<>Preamble) or (FDirectory<>Directory) or (FEngine<>Engine) or (FScale<>Scale) or (FWidth<>TextWidth);
  for I:=0 to 2 do Rebuild:=Rebuild or (FText[I]<>Style.Header[I]) or (FText[I+3]<>Style.Footer[I]);
  if Rebuild then ReleaseRenderCache;
  FStyle:=Style; FScale:=Scale; FRegistry:=Registry; FPreamble:=Preamble; FDirectory:=Directory; FEngine:=Engine;
  FLeft:=TextLeft; FTop:=TextTop; FWidth:=TextWidth; FBody:=TextHeight;
  for I:=0 to 2 do begin FText[I]:=Style.Header[I]; FText[I+3]:=Style.Footer[I]; end;
  Invalidate;
end;
procedure TNativePage.DrawRow(Target:TCanvas; Index,Baseline,OffsetX:Integer);
var Points,Size,X,Base:Integer; Ink:TRect; Box:TDraftBox; I:Integer;
begin
  if FText[Index]='' then Exit;
  if FRows[Index]=nil then begin
    FRows[Index]:=TParagraphDraft.Create; FTrees[Index]:=ParseParagraph(FText[Index],FRegistry);
    FRows[Index].Macros:=FRegistry; FRows[Index].HeadingContext:=FPreamble; FRows[Index].Directory:=FDirectory;
    FRows[Index].TeXEngine:=FEngine; FRows[Index].HideEditingMarks:=True; FRows[Index].SuppressParagraphIndent:=True;
    Points:=DocumentFontPoints(FPreamble); FRows[Index].DocumentFontSize:=Points;
    Size:=Max(1,Round(Points*120*FScale/Max(1,Target.Font.PixelsPerInch)));
    FRows[Index].Layout(Target,FTrees[Index],FWidth+20,True,Size,nil,FText[Index],FScale,Points*120*FScale/72.27);
  end;
  Ink:=FRows[Index].ContentInkBounds; X:=FLeft-Ink.Left;
  case Index mod 3 of 1:Inc(X,(FWidth-Ink.Width) div 2); 2:Inc(X,FWidth-Ink.Width); end;
  Base:=MaxInt;
  for I:=0 to FRows[Index].RootBox.Children.Count-1 do begin
    Box:=TDraftBox(FRows[Index].RootBox.Children[I]);
    if (Box.H>0) and ((Box.Text<>'') or (Box.Children.Count>0)) then Base:=Min(Base,Box.Y+Box.Baseline);
  end;
  if Base=MaxInt then Base:=Ink.Bottom;
  FRows[Index].Paint(Target,nil,nil,X+OffsetX,Baseline-Base);
end;
procedure TNativePage.Paint;
begin
  Canvas.Brush.Style:=bsSolid; Canvas.Brush.Color:=PaperColor; Canvas.FillRect(ClientRect);
  PaintFurniture(Canvas,Point(0,0));
end;
procedure TNativePage.PaintFurniture(Target:TCanvas; Offset:TPoint);
var I,Y:Integer; Points:Double;
begin
  if FScale<=0 then Exit; Points:=120*FScale/72.27;
  Y:=Offset.Y+FTop-Round(FStyle.HeadSep*Points);
  for I:=0 to 2 do DrawRow(Target,I,Y-Round(0.3*DocumentFontPoints(FPreamble)*Points),Offset.X);
  Target.Pen.Color:=InkColor; Target.Pen.Style:=psSolid;
  if FStyle.HeadRule>0 then begin
    Target.Pen.Width:=Max(1,Round(FStyle.HeadRule*Points)); Target.Line(Offset.X+FLeft,Y,Offset.X+FLeft+FWidth,Y);
  end;
  Y:=Offset.Y+FTop+FBody+Round(FStyle.FootSkip*Points);
  for I:=3 to 5 do DrawRow(Target,I,Y,Offset.X);
  if FStyle.FootRule>0 then begin
    Target.Pen.Width:=Max(1,Round(FStyle.FootRule*Points));
    Dec(Y,Round(DocumentFontPoints(FPreamble)*1.2*Points)); Target.Line(Offset.X+FLeft,Y,Offset.X+FLeft+FWidth,Y);
  end;
  Target.Pen.Width:=1;
end;
