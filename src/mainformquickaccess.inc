{ SPDX-License-Identifier: GPL-3.0-or-later }
procedure TMainForm.BuildQuickCatalog;
var I:Integer;
  procedure Scan(Root:TWinControl; const TabName:string);
  var I:Integer; C:TControl; Handler:TNotifyEvent; Key,Hint:string;
  begin
    for I:=0 to Root.ControlCount-1 do begin
      C:=Root.Controls[I]; if not C.Visible then Continue; Handler:=nil;
      if C is TSpeedButton then Handler:=TSpeedButton(C).OnClick
      else if C is TButton then Handler:=TButton(C).OnClick;
      if Assigned(Handler) then begin
        Hint:=C.Hint; if Hint='' then Hint:=C.Caption; if Hint='' then Continue;
        Key:='ribbon:'+TabName+'/'+Hint;
        if FQuickCatalog.IndexOf(Key)<0 then FQuickCatalog.AddObject(Key,C);
      end;
      if C is TWinControl then Scan(TWinControl(C),TabName);
    end;
  end;
begin
  FQuickCatalog:=TStringList.Create;
  for I:=0 to Ribbon.PageCount-1 do Scan(Ribbon.Pages[I],Ribbon.Pages[I].Caption);
  FQuickMenu:=TPopupMenu.Create(Self); FQuickMenu.Name:='QuickCommands';
  FQuickOverflow:=TSpeedButton.Create(Self); FQuickOverflow.Name:='QuickOverflow'; FQuickOverflow.Parent:=QuickAccessBar;
  FQuickOverflow.Caption:='»'; FQuickOverflow.HelpKeyword:='literal'; FQuickOverflow.Hint:='More quick access commands';
  FQuickOverflow.OnClick:=@QuickOverflowClick; FQuickOverflow.ShowHint:=True; FQuickOverflow.Flat:=True;
end;
function TMainForm.QuickControl(const Key:string):TControl;
var ID:Integer; B:TQuickRibbonButton; Source:TControl;
begin
  ID:=StrToIntDef(Key,-1); if ID>=0 then Exit(QuickActionControl(ID));
  Result:=nil; if FQuickCatalog=nil then Exit; ID:=FQuickCatalog.IndexOf(Key); if ID<0 then Exit;
  Result:=TControl(FindComponent('QuickRibbon'+IntToStr(ID))); if Result<>nil then Exit;
  Source:=TControl(FQuickCatalog.Objects[ID]); B:=TQuickRibbonButton.Create(Self); B.Source:=Source;
  B.Name:='QuickRibbon'+IntToStr(ID); B.Parent:=QuickAccessBar; B.Visible:=False; B.Flat:=True;
  B.Hint:=Source.Hint; B.ShowHint:=True; B.Caption:=Source.Caption; B.Font.Assign(Source.Font);
  B.HelpKeyword:=Source.HelpKeyword; B.Tag:=Source.Tag; B.PopupMenu:=Source.PopupMenu; B.OnClick:=@QuickRibbonClick;
  if Source is TSpeedButton then begin
    B.Glyph.Assign(TSpeedButton(Source).Glyph);
    if TSpeedButton(Source).GroupIndex<>0 then begin B.GroupIndex:=1000+ID; B.AllowAllUp:=True; end;
  end;
  Result:=B;
end;
procedure TMainForm.QuickRibbonClick(Sender:TObject);
var Source:TControl; Handler:TNotifyEvent;
begin
  Source:=TQuickRibbonButton(Sender).Source; if not Source.Enabled then Exit; Handler:=nil;
  if Source is TSpeedButton then Handler:=TSpeedButton(Source).OnClick
  else if Source is TButton then Handler:=TButton(Source).OnClick;
  if Assigned(Handler) then Handler(Sender); SyncQuickAccess;
end;
procedure TMainForm.QuickOverflowClick(Sender:TObject);
var C:TControl; P:TPoint;
begin
  if Sender is TMenuItem then begin
    C:=QuickControl(TMenuItem(Sender).Hint);
    if (C<>nil) and C.Enabled then begin
      if C is TSpeedButton then TSpeedButton(C).Click else if C is TButton then TButton(C).Click;
    end;
  end else begin
    P:=FQuickOverflow.ClientToScreen(Point(0,FQuickOverflow.Height)); FQuickMenu.PopUp(P.X,P.Y);
  end;
end;
procedure TMainForm.SyncQuickAccess;
var I:Integer; B:TQuickRibbonButton; C:TControl;
begin
  if FQuickCatalog=nil then Exit;
  if FQuickWidth<>QuickAccessBar.ClientWidth then begin FQuickWidth:=QuickAccessBar.ClientWidth; LayoutQuickAccess; end;
  for I:=0 to ComponentCount-1 do if Components[I] is TQuickRibbonButton then begin
    B:=TQuickRibbonButton(Components[I]); B.Enabled:=B.Source.Enabled;
    if B.Source is TSpeedButton then B.Down:=TSpeedButton(B.Source).Down;
  end;
  for I:=0 to FQuickMenu.Items.Count-1 do begin
    C:=QuickControl(FQuickMenu.Items[I].Hint);
    if C<>nil then FQuickMenu.Items[I].Enabled:=C.Enabled;
  end;
end;
