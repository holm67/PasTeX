unit BeamerOverlays;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses MathModel;
type
  TBeamerVisibility=(bvVisible,bvCovered,bvAbsent);
  TBeamerNodeState=record Visibility:TBeamerVisibility; Alert:Boolean; end;
  TBeamerProjection=class
  private
    FNodes:array of record Node:TMathNode; Value:TBeamerNodeState; end;
    FFirstID,FSlide,FPause:Integer;
    FMode:string;
    FFuture:Boolean;
    procedure SetState(Node:TMathNode; const Value:TBeamerNodeState);
    procedure Visit(Node:TMathNode; State:TBeamerNodeState; const DefaultOverlay:string);
  public
    procedure Project(Root:TMathNode; Slide:Integer; const Mode,DefaultOverlay:string);
    function State(Node:TMathNode):TBeamerNodeState;
    property Future:Boolean read FFuture;
    property Slide:Integer read FSlide;
  end;
function BeamerNodeRole(Node:TMathNode):string;
function BeamerNodeSpec(Node:TMathNode):string;
function BeamerSlideCount(Frame:TMathNode; const Mode:string):Integer;
implementation
uses SysUtils, Math, TeXMacros, BeamerModel;
function BeamerNodeRole(Node:TMathNode):string;
var P:Integer;
begin
  Result:='';
  Node:=MathPreviewNode(Node); if Node=nil then Exit;
  if (Node.Kind=mkGroup) and (Copy(Node.Text,1,8)='@beamer:') then Exit(Copy(Node.Text,9,MaxInt));
  if (Node.Kind=mkEnvironment) and BeamerEnvironment(Node.Text) then Exit(Node.Text);
  if Node.Kind=mkEnvironment then begin
    P:=1; ReadTeXCommand(Node.Prefix,P); ReadTeXGroup(Node.Prefix,P,'{','}');
    if ReadBeamerOverlay(Node.Prefix,P)<>'' then Exit('environment');
  end;
  if Node.Kind<>mkGroup then Exit;
  P:=1; if ReadTeXCommand(Node.Prefix,P)='item' then Result:='item';
end;
function BeamerNodeSpec(Node:TMathNode):string;
var P:Integer; Command:string;
begin
  Node:=MathPreviewNode(Node);
  P:=1; Command:=ReadTeXCommand(Node.Prefix,P);
  if Command='begin' then ReadTeXGroup(Node.Prefix,P,'{','}');
  if (Copy(Node.Prefix,P,1)='*') or (Copy(Node.Prefix,P,1)='+') then Inc(P);
  Result:=ReadBeamerOverlay(Node.Prefix,P);
  if Result='' then begin P:=1; Result:=ReadBeamerOverlay(Node.Suffix,P); end;
end;
function TBeamerProjection.State(Node:TMathNode):TBeamerNodeState;
var I:Integer;
begin
  Result:=Default(TBeamerNodeState);
  while Node<>nil do begin
    if Node.ID>=FFirstID then begin
      I:=Node.ID-FFirstID;
      if (I<Length(FNodes)) and (FNodes[I].Node=Node) then Exit(FNodes[I].Value);
    end;
    Node:=Node.PreviewOrigin;
  end;
end;
procedure TBeamerProjection.SetState(Node:TMathNode; const Value:TBeamerNodeState);
var I:Integer;
begin
  if Node.ID<FFirstID then Exit;
  I:=Node.ID-FFirstID;
  if I<Length(FNodes) then begin FNodes[I].Node:=Node; FNodes[I].Value:=Value; end;
end;
procedure TBeamerProjection.Visit(Node:TMathNode; State:TBeamerNodeState; const DefaultOverlay:string);
var I,Branch,P:Integer; Role,Spec,DefaultSpec,Value:string; Overlay:TBeamerOverlay;
    Child:TMathNode; ChildState,Flow:TBeamerNodeState; Zoom:TBeamerZoom;
  procedure Store(Part:TMathNode; const Value:TBeamerNodeState);
  var J:Integer;
  begin
    SetState(Part,Value);
    for J:=0 to Part.Children.Count-1 do Store(TMathNode(Part.Children[J]),Value);
  end;
begin
  if (Node.Kind=mkSource) and (Node.SourcePreview<>nil) then begin
    Visit(Node.SourcePreview,State,DefaultOverlay);
    Store(Node,Self.State(Node.SourcePreview)); Exit;
  end;
  Role:=BeamerNodeRole(Node); Spec:=''; if Role<>'' then Spec:=BeamerNodeSpec(Node);
  DefaultSpec:=DefaultOverlay; Branch:=-1;
  if (Role='item') and (Spec='') then Spec:=DefaultSpec;
  if (Role='pause') and (FSlide>0) then begin
    P:=1; ReadTeXCommand(Node.Prefix,P); Value:=ReadTeXGroup(Node.Prefix,P,'[',']');
    if FPause<MaxInt then Inc(FPause);
    if Value<>'' then FPause:=Max(0,StrToIntDef(Value,FPause));
    Spec:=IntToStr(FPause)+'-';
  end;
  Overlay:=Default(TBeamerOverlay); Overlay.Active:=True;
  if FSlide>0 then Overlay:=DecodeBeamerOverlay(Spec,FMode,FSlide,FPause);
  FFuture:=FFuture or Overlay.Future;
  if (FSlide>0) and (Role='framezoom') and ReadBeamerZoom(Node.TeX,1,Zoom) then begin
    P:=FPause; Overlay:=DecodeBeamerOverlay(Zoom.ZoomSlides,FMode,FSlide,P); FFuture:=FFuture or Overlay.Future;
  end;
  if Role='invisible' then Overlay.Active:=not Overlay.Active;
  if Role='invisibleenv' then Overlay.Active:=not Overlay.Active;
  if (Role='alt') and (FSlide>0) then begin if Overlay.Active then Branch:=0 else Branch:=1; end;
  if (Role='temporal') and (FSlide>0) then begin
    if Overlay.Active then Branch:=1 else if Overlay.Future then Branch:=0 else Branch:=2;
  end;
  if (Role='alert') or Overlay.Alert then State.Alert:=State.Alert or Overlay.Active;
  if (FSlide>0) and not Overlay.Active then begin
    if (Role='only') or (Role='onlyenv') then State.Visibility:=bvAbsent
    else if (Role='uncover') or (Role='visible') or (Role='invisible') or (Role='onslide') or
      (Role='uncoverenv') or (Role='visibleenv') or (Role='invisibleenv') or (Role='action') or
      (Role='actionenv') or (Role='environment') or (Role='item') or (Role='block') or (Role='alertblock') or (Role='exampleblock') then
      State.Visibility:=bvCovered;
  end;
  SetState(Node,State);
  if State.Visibility=bvAbsent then Exit;
  if Node.SourcePreview<>nil then Visit(Node.SourcePreview,State,DefaultOverlay);
  if (Node.Kind=mkEnvironment) and ((Node.Text='itemize') or (Node.Text='enumerate') or (Node.Text='description')) then
    for I:=0 to Node.Children.Count-1 do begin
      Child:=TMathNode(Node.Children[I]);
      if Child.Kind=mkOptional then begin
        Value:=Trim(Child.TeX); P:=1; Value:=Trim(ReadTeXGroup(Value,P,'[',']'));
        if Copy(Value,1,1)='<' then DefaultSpec:=Value;
      end;
    end;
  Flow:=State;
  for I:=0 to Node.Children.Count-1 do begin
    Child:=TMathNode(Node.Children[I]); ChildState:=Flow;
    if (Branch>=0) and (I<>Branch) then ChildState.Visibility:=bvAbsent;
    Visit(Child,ChildState,DefaultSpec);
    Role:=BeamerNodeRole(Child);
    if (FSlide>0) and ((Role='pause') or
      (((Role='onslide') or (Role='only') or (Role='visible')) and (MathPreviewNode(Child).Children.Count=0))) then begin
      Spec:=BeamerNodeSpec(Child);
      if Role='pause' then Spec:=IntToStr(FPause)+'-';
      { A bare onslide changes the remaining material in its TeX group.
        Its specification was already decoded by Visit: do not increment + twice. }
      P:=FPause; if Pos('+',Spec)>0 then Dec(P);
      Overlay:=DecodeBeamerOverlay(Spec,FMode,FSlide,P); FFuture:=FFuture or Overlay.Future;
      Flow:=State;
      if not Overlay.Active then if Role='only' then Flow.Visibility:=bvAbsent else Flow.Visibility:=bvCovered;
    end;
  end;
end;
procedure TBeamerProjection.Project(Root:TMathNode; Slide:Integer; const Mode,DefaultOverlay:string);
var Last:TMathNode;
begin
  Last:=Root;
  while (Last.Children.Count>0) or (Last.SourcePreview<>nil) do
    if Last.Children.Count>0 then Last:=TMathNode(Last.Children.Last) else Last:=Last.SourcePreview;
  { A frame can start late in the document. Keep only its node range, and
    distinguish generated trees whose local numbering starts over at zero. }
  FFirstID:=Max(0,Root.ID);
  SetLength(FNodes,Max(0,Last.ID-FFirstID+1));
  if Length(FNodes)>0 then FillChar(FNodes[0],Length(FNodes)*SizeOf(FNodes[0]),0);
  FSlide:=Slide; FPause:=1; FMode:=Mode; FFuture:=False;
  Visit(Root,Default(TBeamerNodeState),DefaultOverlay);
end;
function BeamerSlideCount(Frame:TMathNode; const Mode:string):Integer;
var Projection:TBeamerProjection; Header:TBeamerFrame; DefaultSpec:string;
begin
  Result:=1; DefaultSpec:='';
  if ReadBeamerFrame(Frame.TeX,1,Header) then DefaultSpec:=Header.DefaultOverlay;
  Projection:=TBeamerProjection.Create;
  try
    repeat
      Projection.Project(Frame,Result,Mode,DefaultSpec);
      if not Projection.Future then Break;
      Inc(Result);
    until Result>=512;
  finally Projection.Free; end;
end;
end.
