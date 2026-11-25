{ SPDX-License-Identifier: GPL-3.0-or-later }
procedure TParagraphDraft.RestoreEditingSpace;
var I:Integer;
begin
  for I:=0 to High(FEditingGeometry) do with FEditingGeometry[I] do begin
    Box.Y:=Y; Box.H:=H; Box.Baseline:=Baseline; Box.BoxTitleHeight:=TitleHeight;
  end;
  FEditingGeometry:=nil; FEditingSpaceHeight:=0; FEditingSpaceID:=-1;
  FEditingSpaceSlide:=0;
  FEditingSpaceLine:=-1; FEditingSpaceBounds:=Rect(0,0,0,0);
end;
function TParagraphDraft.SetEditingSpace(AnchorID,Space:Integer; Slide:Integer):Boolean;
var Path:array of TDraftBox; Origins:array of TPoint;
    I,J,Frame,Body,Base,Bottom,Cut,Index:Integer; Parent,Part:TDraftBox;
  function Find(Box:TDraftBox):Boolean;
  var I,Count:Integer;
  begin
    if (Slide>0) and (Box.Slide>0) and (Box.Slide<>Slide) then Exit(False);
    Count:=Length(Path); SetLength(Path,Count+1); Path[Count]:=Box;
    if Box.ID=AnchorID then Exit(True);
    for I:=0 to Box.Children.Count-1 do if Find(TDraftBox(Box.Children[I])) then Exit(True);
    SetLength(Path,Count); Result:=False;
  end;
  procedure Remember(Part:TDraftBox);
  var I:Integer;
  begin
    I:=Length(FEditingGeometry); SetLength(FEditingGeometry,I+1);
    with FEditingGeometry[I] do begin
      Box:=Part; Y:=Part.Y; H:=Part.H;
      Baseline:=Part.Baseline; TitleHeight:=Part.BoxTitleHeight;
    end;
  end;
begin
  Result:=False;
  if (Space=FEditingSpaceHeight) and ((Space=0) or ((AnchorID=FEditingSpaceID) and (Slide=FEditingSpaceSlide))) then Exit;
  Result:=Length(FEditingGeometry)>0; RestoreEditingSpace;
  FEditingSpaceID:=AnchorID; FEditingSpaceHeight:=Space; FEditingSpaceSlide:=Slide;
  try
    if (FRoot=nil) or (AnchorID<0) or (Space<=0) or not Find(FRoot) then Exit;
    Frame:=-1; Body:=-1; SetLength(Origins,Length(Path));
    for I:=0 to High(Path) do begin
      if I>0 then Origins[I]:=Origins[I-1];
      Inc(Origins[I].X,Path[I].X); Inc(Origins[I].Y,Path[I].Y);
      if (Path[I].Shape=21) or (Path[I].Slide>0) then Frame:=I;
      if Path[I].ParagraphContent and (I<High(Path)) then Body:=I;
    end;
    if (Frame<0) or (Body<=Frame) then Exit;
    Parent:=Path[Body]; Part:=Path[Body+1]; Base:=Part.Y+Part.Baseline; Bottom:=Part.Y+Part.H;
    { Reserve space below the whole text/formula line, including taller
      neighbours. The native page-break measurements remain unchanged. }
    for I:=0 to Parent.Children.Count-1 do begin
      Part:=TDraftBox(Parent.Children[I]);
      if Abs(Part.Y+Part.Baseline-Base)<=1 then Bottom:=Max(Bottom,Part.Y+Part.H);
    end;
    FEditingSpaceBounds:=Rect(Origins[High(Path)].X,Origins[Body].Y+Bottom,
      Origins[High(Path)].X+Max(1,Path[High(Path)].W),Origins[Body].Y+Bottom+Space);
    for I:=Body downto 1 do begin
      Parent:=Path[I]; Cut:=FEditingSpaceBounds.Top-Origins[I].Y; Remember(Parent);
      for J:=0 to Parent.Children.Count-1 do begin
        Part:=TDraftBox(Parent.Children[J]);
        if (I<Body) and (Part=Path[I+1]) then Continue;
        { Font boxes on adjacent lines can overlap through their leading.
          Their baselines, rather than their top edges, identify later lines. }
        if (Part.Y>=Cut) or ((I=Body) and (Part.Y+Part.Baseline>Base+1)) then begin
          Remember(Part); Inc(Part.Y,Space);
        end;
      end;
      Inc(Parent.H,Space);
      if Parent.Baseline>=Cut then Inc(Parent.Baseline,Space);
      if (Parent.BoxTitleHeight>0) and (Parent.BoxTitleHeight>=Cut) then Inc(Parent.BoxTitleHeight,Space);
    end;
    Index:=FRoot.Children.IndexOf(Path[1]);
    if (Index>=0) and (Index<Length(FPageGroups)) then FEditingSpaceLine:=FPageGroups[Index];
    FEditingSpaceID:=AnchorID; FEditingSpaceHeight:=Space; Result:=True;
  finally
    if Result then begin Regions:=nil; Links:=nil; SourceToggles:=nil; Collect(FRoot,0,0); MergeWordRegions; end;
  end;
end;
