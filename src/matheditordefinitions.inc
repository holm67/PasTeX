{ SPDX-License-Identifier: GPL-3.0-or-later }
function TMathEditor.DefinitionNodeAtCaret:TMathNode;
begin
  Result:=CurrentNode;
  while (Result<>nil) and (Result.Kind<>mkDefinition) do Result:=Result.Parent;
end;
function TMathEditor.EditingDefinition:Boolean;
begin Result:=DefinitionNodeAtCaret<>nil; end;
function TMathEditor.DefinitionSourceEditing:Boolean;
begin Result:=FDefinitionSourceStart>=0; end;
procedure TMathEditor.ToggleDefinitionSource;
var N:TMathNode; Position:Integer;
begin
  FinishDefinitionEdit; N:=DefinitionNodeAtCaret; if N=nil then Exit; Position:=SourceCaret;
  if FDefinitionSourceStart>=0 then FDefinitionSourceStart:=-1
  else FDefinitionSourceStart:=MathSourceOffset(N)-Length(N.Prefix);
  ParseSource; SetSourceCaret(Position); Schedule; if Assigned(FLayout) then FLayout(Self);
end;
function TMathEditor.CurrentDefinitionSource:string;
var N:TMathNode;
begin N:=DefinitionNodeAtCaret; Result:=''; if N<>nil then Result:=N.TeX; end;
procedure TMathEditor.BeginDefinitionEdit;
var N:TMathNode; D:TCommandDefinition;
begin
  if (FDefinitionStart>=0) or FFinishingDefinition then Exit;
  N:=DefinitionNodeAtCaret;
  if (N=nil) or not ReadCommandDefinition(N.TeX,D) then Exit;
  FDefinitionStart:=MathSourceOffset(N)-Length(N.Prefix);
  FDefinitionMinimum:=Length(D.Arguments);
end;
function TMathEditor.CompleteDefinition(const Source:string; var Caret:Integer):string;
var P,Start:Integer; Code,Replacement:string; D:TCommandDefinition;
begin
  Result:=Source; Start:=FDefinitionStart; FDefinitionStart:=-1;
  if Start<0 then Exit; P:=Start+1;
  if not ReadTeXDefinition(Source,P) then Exit;
  Code:=Copy(Source,Start+1,P-Start-1); if not ReadCommandDefinition(Code,D) then Exit;
  Replacement:=DefinitionEnsureArguments(Code,Max(FDefinitionMinimum,DefinitionParameterCount(D.Body)));
  if Caret>=Start+D.BodyStart then Inc(Caret,Length(Replacement)-Length(Code));
  Result:=Copy(Source,1,Start)+Replacement+Copy(Source,P,MaxInt);
end;
procedure TMathEditor.FinishDefinitionEdit;
var Code:string; Position:Integer;
begin
  FinishOptionalEdit;
  if FFinishingDefinition or (FDefinitionStart<0) then Exit;
  Position:=SourceCaret; Code:=CompleteDefinition(FSource,Position); FFinishingDefinition:=True;
  try if Code<>FSource then Commit(Code,Position); finally FFinishingDefinition:=False; end;
end;
procedure TMathEditor.ReplaceDefinition(const Value:string);
var N:TMathNode; Start,Position,BodyOffset:Integer; Old,New:TCommandDefinition;
begin
  N:=DefinitionNodeAtCaret; if (N=nil) or not ReadCommandDefinition(Value,New) then Exit;
  Start:=MathSourceOffset(N)-Length(N.Prefix); ReadCommandDefinition(N.TeX,Old);
  BodyOffset:=SourceCaret-Start-Old.BodyStart; Position:=Start+New.BodyStart+Max(0,BodyOffset);
  Position:=Min(Start+New.BodyEnd,Position); FDefinitionStart:=-1; FFinishingDefinition:=True;
  try Commit(Copy(FSource,1,Start)+Value+Copy(FSource,Start+Length(N.TeX)+1,MaxInt),Position);
  finally FFinishingDefinition:=False; end;
end;
procedure TMathEditor.EditDefinitionArguments(Optional:Boolean; DeleteIndex:Integer);
var Code:string; D:TCommandDefinition; N:Integer;
begin
  FinishDefinitionEdit;
  Code:=CurrentDefinitionSource; if not ReadCommandDefinition(Code,D) then Exit;
  if DeleteIndex>=0 then Code:=DefinitionDeleteArgument(Code,DeleteIndex)
  else begin
    N:=Length(D.Arguments); if N>=9 then Exit; SetLength(D.Arguments,N+1);
    if Optional then D.Arguments[N].Kind:='O' else D.Arguments[N].Kind:='m';
    Code:=DefinitionArgumentsSource(Code,D.Arguments);
  end;
  ReplaceDefinition(Code);
end;
procedure TMathEditor.SetDefinitionArgumentKind(Index:Integer; Optional:Boolean);
var Code:string; D:TCommandDefinition;
begin
  FinishDefinitionEdit; Code:=CurrentDefinitionSource;
  if not ReadCommandDefinition(Code,D) or (Index<0) or (Index>=Length(D.Arguments)) then Exit;
  if Optional then begin
    if D.Arguments[Index].Kind in ['o','O'] then Exit;
    D.Arguments[Index].Kind:='O';
  end else begin
    if D.Arguments[Index].Kind='m' then Exit;
    D.Arguments[Index].Kind:='m'; D.Arguments[Index].DefaultValue:='';
  end;
  D.Arguments[Index].Spec:=''; ReplaceDefinition(DefinitionArgumentsSource(Code,D.Arguments));
end;
procedure TMathEditor.SetDefinitionArgumentDefault(Index:Integer; const Value:string; Caret:Integer);
var Code,Replacement:string; D:TCommandDefinition; N:TMathNode; Start,Position:Integer;
begin
  FinishDefinitionEdit; N:=DefinitionNodeAtCaret; if N=nil then Exit; Code:=N.TeX;
  if not ReadCommandDefinition(Code,D) or (Index<0) or (Index>=Length(D.Arguments)) then Exit;
  D.Arguments[Index].Kind:='O'; D.Arguments[Index].DefaultValue:=Value; D.Arguments[Index].Spec:='';
  Replacement:=DefinitionArgumentsSource(Code,D.Arguments); if not ReadCommandDefinition(Replacement,D) then Exit;
  Start:=MathSourceOffset(N)-Length(N.Prefix);
  Position:=Start+D.Arguments[Index].DefaultStart+Length(UTF8Copy(Value,1,Caret));
  FDefinitionStart:=-1; FFinishingDefinition:=True;
  try Commit(Copy(FSource,1,Start)+Replacement+Copy(FSource,Start+Length(Code)+1,MaxInt),Position);
  finally FFinishingDefinition:=False; end;
  NotifySelection;
end;
procedure TMathEditor.SetDefinitionArgumentDefaultValue(Index:Integer; const Value:string);
var Code:string; D:TCommandDefinition;
begin
  FinishDefinitionEdit; Code:=CurrentDefinitionSource;
  if not ReadCommandDefinition(Code,D) or (Index<0) or (Index>=Length(D.Arguments)) or
    not (D.Arguments[Index].Kind in ['o','O']) then Exit;
  if (D.Arguments[Index].Kind='O') and (D.Arguments[Index].DefaultValue=Value) then Exit;
  D.Arguments[Index].Kind:='O'; D.Arguments[Index].DefaultValue:=Value; D.Arguments[Index].Spec:='';
  ReplaceDefinition(DefinitionArgumentsSource(Code,D.Arguments));
end;
function TMathEditor.PrepareDefinitionArgumentMenu(X,Y:Integer):TPopupMenu;
var Region:TDraftRegion; D:TCommandDefinition; Item:TMenuItem; I:Integer;
begin
  Result:=nil; if FReadOnly then Exit;
  FinishDefinitionEdit; EnsureDraft;
  for Region in FDraft.Regions do if (Region.DefinitionArgument>=0) and
    PtInRect(Region.Bounds,Point(X-ImageLeft,Y-ImageTop)) then begin
    if not ReadCommandDefinition(Copy(FSource,Region.DefinitionOffset+1,MaxInt),D) or
      (Region.DefinitionArgument>=Length(D.Arguments)) then Exit;
    SetSourceCaret(Region.DefinitionOffset+D.NameStart);
    FDefinitionMenuArgument:=Region.DefinitionArgument;
    if FDefinitionArgumentMenu=nil then begin
      FDefinitionArgumentMenu:=TPopupMenu.Create(Self); FDefinitionArgumentMenu.Name:='DefinitionArgumentMenu';
      for I:=0 to 1 do begin
        Item:=TMenuItem.Create(FDefinitionArgumentMenu); Item.Tag:=I; Item.RadioItem:=True; Item.GroupIndex:=1;
        if I=0 then Item.Caption:='Required argument' else Item.Caption:='Optional argument';
        Item.OnClick:=@DefinitionArgumentMenuClick; FDefinitionArgumentMenu.Items.Add(Item);
      end;
    end;
    FDefinitionArgumentMenu.Items[0].Checked:=not (D.Arguments[FDefinitionMenuArgument].Kind in ['o','O']);
    FDefinitionArgumentMenu.Items[1].Checked:=not FDefinitionArgumentMenu.Items[0].Checked;
    Exit(FDefinitionArgumentMenu);
  end;
end;
procedure TMathEditor.DefinitionArgumentMenuClick(Sender:TObject);
begin SetDefinitionArgumentKind(FDefinitionMenuArgument,TMenuItem(Sender).Tag=1); NotifySelection; end;
procedure TMathEditor.DoContextPopup(MousePos:TPoint; var Handled:Boolean);
var Menu:TPopupMenu; ScreenPoint:TPoint;
begin
  if MousePos.X<0 then MousePos:=CaretPoint;
  Menu:=PrepareDefinitionArgumentMenu(MousePos.X,MousePos.Y);
  if Menu=nil then begin inherited DoContextPopup(MousePos,Handled); Exit; end;
  Handled:=True; ScreenPoint:=ClientToScreen(MousePos); Menu.PopUp(ScreenPoint.X,ScreenPoint.Y);
end;
