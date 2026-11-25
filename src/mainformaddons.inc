{ SPDX-License-Identifier: GPL-3.0-or-later }
function FindPluginAction(Items:TJSONArray; const ID:string):TJSONObject;
var I:Integer;
begin
  Result:=nil;
  for I:=0 to Items.Count-1 do begin
    if Items.Objects[I].Get('id','')=ID then Exit(Items.Objects[I]);
    if Items.Objects[I].Find('items') is TJSONArray then begin
      Result:=FindPluginAction(Items.Objects[I].Arrays['items'],ID); if Result<>nil then Exit;
    end;
  end;
end;
procedure TMainForm.RefreshAddonsRibbon;
var Catalog:TEditorAddons; Addon:TEditorAddon; I,J,K,X,Slot,CellWidth:Integer; Group:TPanel;
    Actions:TJSONArray; Entry:TJSONObject; Toggle:TPluginToggle; B:TPluginActionButton; Item:TMenuItem; LabelText:TLabel;
  function Button(const Title,Caption,ID,Icon:string; Available:Boolean=True):TPluginActionButton;
  begin
    Result:=TPluginActionButton.Create(Group); Result.Parent:=Group;
    Result.SetBounds(2+(Slot div 2)*CellWidth,(Slot mod 2)*26,CellWidth-4,26); Inc(Slot);
    Result.Flat:=True; Result.ShowHint:=True; Result.Margin:=4; Result.Spacing:=5;
    Result.Caption:=Caption; Result.IconName:=Icon;
    Result.Hint:=Title; Result.HelpKeyword:=ID; Result.ToolAvailable:=Available; Result.Enabled:=Available; Result.OnClick:=@AddonActionClick;
  end;
  procedure BeginGroup(const Title:string; Count:Integer);
  begin
    Slot:=0; Group:=TPanel.Create(FAddonsRow); Group.Parent:=FAddonsRow; Group.BevelOuter:=bvNone;
    Group.SetBounds(X,0,((Count+1) div 2)*CellWidth+4,66); Inc(X,Group.Width+8);
    LabelText:=TLabel.Create(Group); LabelText.Parent:=Group; LabelText.Caption:=Title;
    LabelText.AutoSize:=False; LabelText.Alignment:=taCenter; LabelText.Font.Size:=9;
    LabelText.SetBounds(0,52,Group.Width,14);
    with TBevel.Create(Group) do begin Parent:=Group; Shape:=bsRightLine; SetBounds(Group.Width-2,3,2,60); end;
  end;
begin
  Catalog:=TEditorAddons.Create(True);
  try
    Catalog.Load;
    if FAddonsTab=nil then begin FAddonsTab:=TTabSheet.Create(Self); FAddonsTab.Name:='AddonsTab'; FAddonsTab.PageControl:=Ribbon; FAddonsTab.Caption:='Add-ons'; end;
    if FAddonsRow<>nil then FAddonsRow.OnResize:=nil;
    FAddonsRow:=nil;
    while FAddonsTab.ControlCount>0 do FAddonsTab.Controls[0].Free;
    for I:=0 to 1 do begin
      FAddonScroll[I]:=TActionGlyphButton.Create(FAddonsTab); FAddonScroll[I].Parent:=FAddonsTab;
      FAddonScroll[I].Name:='AddonsScroll'+IntToStr(I); FAddonScroll[I].Width:=28;
      FAddonScroll[I].Tag:=I; FAddonScroll[I].Flat:=True; FAddonScroll[I].ShowHint:=True;
      if I=0 then begin FAddonScroll[I].Align:=alLeft; FAddonScroll[I].IconName:='sync-left'; FAddonScroll[I].Hint:='Previous add-on commands'; end
      else begin FAddonScroll[I].Align:=alRight; FAddonScroll[I].IconName:='sync-right'; FAddonScroll[I].Hint:='More add-on commands'; end;
      FAddonScroll[I].OnClick:=@ScrollAddons;
    end;
    FAddonsRow:=TScrollBox.Create(FAddonsTab); FAddonsRow.Name:='AddonsRibbonContent'; FAddonsRow.HelpKeyword:='ribbon-content';
    FAddonsRow.Parent:=FAddonsTab; FAddonsRow.Align:=alClient; FAddonsRow.BorderStyle:=bsNone;
    FAddonsRow.VertScrollBar.Visible:=False; FAddonsRow.HorzScrollBar.Visible:=False;
    FAddonsRow.HorzScrollBar.Tracking:=True;
    FAddonsRow.OnResize:=@ResizeAddons; FAddonsRow.OnMouseWheel:=@WheelAddons;
    X:=2; CellWidth:=110; BeginGroup('Add-ons',1); Button('Manage add-ons','Manage','configure','configure');
    for I:=0 to Catalog.Count-1 do begin
      Addon:=TEditorAddon(Catalog[I]); if not Addon.Installed or not Addon.Enabled then Continue;
      if not (Addon.Manifest.Find('actions') is TJSONArray) then Continue; Actions:=Addon.Manifest.Arrays['actions'];
      CellWidth:=110;
      for J:=0 to Actions.Count-1 do begin
        Entry:=Actions.Objects[J];
        Canvas.Font.Assign(FAddonsRow.Font);
        CellWidth:=Max(CellWidth,Canvas.TextWidth(Entry.Get('shortTitle',Entry.Get('title',Addon.Name)))+52);
      end;
      BeginGroup(Addon.Name,Actions.Count+1);
      for J:=0 to Actions.Count-1 do begin
        Entry:=Actions.Objects[J];
        if Entry.Get('kind','')='checkbox' then begin
          Toggle:=TPluginToggle.Create(Group); Toggle.Parent:=Group;
          Toggle.SetBounds(6+(Slot div 2)*CellWidth,(Slot mod 2)*26,CellWidth-10,26); Inc(Slot);
          Toggle.Caption:=Entry.Get('shortTitle',Entry.Get('title','')); Toggle.Hint:=Entry.Get('description',Toggle.Caption); Toggle.ShowHint:=True;
          Toggle.HelpKeyword:=Addon.ID+':'+Entry.Get('id',''); Toggle.StatePackage:=Entry.Get('statePackage','');
          Toggle.OnClick:=@AddonActionClick;
        end else begin
          B:=Button(Entry.Get('title',Addon.Name),Entry.Get('shortTitle',Entry.Get('title',Addon.Name)),
            Addon.ID+':'+Entry.Get('id','run'),Entry.Get('icon','extension'),
            (Addon.Executable='') or (Addon.Executable='http:get') or (FindTool(Addon.Executable)<>'') or (Entry.Find('items') is TJSONArray));
          B.RequiredPackage:=Entry.Get('requiresPackage','');
          if Entry.Find('items') is TJSONArray then begin
            B.Caption:=B.Caption+' ▾';
            B.PopupMenu:=TPopupMenu.Create(B); B.PopupMenu.AutoPopup:=False; B.OnClick:=@AddonMenuClick;
            for K:=0 to Actions.Objects[J].Arrays['items'].Count-1 do begin
              Item:=TMenuItem.Create(B.PopupMenu); Item.Caption:=Actions.Objects[J].Arrays['items'].Objects[K].Get('title','');
              Item.Hint:=Addon.ID+':'+Actions.Objects[J].Arrays['items'].Objects[K].Get('id',''); Item.OnClick:=@AddonActionClick; B.PopupMenu.Items.Add(Item);
            end;
          end;
        end;
      end;
      Button('Configure '+Addon.Name,'Settings','configure:'+Addon.ID,'configure');
    end;
    FAddonsRow.HorzScrollBar.Range:=X; ResizeAddons(nil);
    SetPageVisible(FAddonsTab,True); ApplyTheme(FAddonsTab); RefreshRibbonIcons(FAddonsTab); RefreshTabTheme(Ribbon);
  finally Catalog.Free; end;
  RefreshDocumentFormatMenus;
  RefreshAddonChecks;
end;
procedure TMainForm.ResizeAddons(Sender:TObject);
begin
  if FAddonsRow=nil then Exit;
  FAddonScroll[0].Enabled:=FAddonsRow.HorzScrollBar.Position>0;
  FAddonScroll[1].Enabled:=FAddonsRow.HorzScrollBar.Position+FAddonsRow.ClientWidth<FAddonsRow.HorzScrollBar.Range;
end;
procedure TMainForm.ScrollAddons(Sender:TObject);
begin
  FAddonsRow.HorzScrollBar.Position:=FAddonsRow.HorzScrollBar.Position+
    IfThen(TControl(Sender).Tag=0,-1,1)*Max(100,FAddonsRow.ClientWidth div 2);
  ResizeAddons(nil);
end;
procedure TMainForm.WheelAddons(Sender:TObject; Shift:TShiftState; WheelDelta:Integer; MousePos:TPoint; var Handled:Boolean);
begin
  FAddonsRow.HorzScrollBar.Position:=FAddonsRow.HorzScrollBar.Position-WheelDelta;
  ResizeAddons(nil); Handled:=True;
end;
procedure TMainForm.AddonMenuClick(Sender:TObject);
var P:TPoint;
begin
  P:=TControl(Sender).ClientToScreen(Point(0,TControl(Sender).Height));
  TPluginActionButton(Sender).PopupMenu.PopUp(P.X,P.Y);
end;
procedure TMainForm.RefreshAddonChecks;
var Model:TPreambleModel;
  procedure Refresh(Parent:TWinControl);
  var J:Integer; Control:TControl; Handler:TNotifyEvent;
  begin
    for J:=0 to Parent.ControlCount-1 do begin
      Control:=Parent.Controls[J];
      if Control is TPluginActionButton then begin
        with TPluginActionButton(Control) do Enabled:=ToolAvailable and
          ((RequiredPackage='') or (Model.PackageIndex(RequiredPackage)>=0));
      end else if Control is TPluginToggle then begin
        Handler:=TPluginToggle(Control).OnClick; TPluginToggle(Control).OnClick:=nil;
        try TPluginToggle(Control).Checked:=Model.PackageIndex(TPluginToggle(Control).StatePackage)>=0;
        finally TPluginToggle(Control).OnClick:=Handler; end;
      end else if Control is TWinControl then Refresh(TWinControl(Control));
    end;
  end;
begin
  if FAddonsTab=nil then Exit; Model:=TPreambleModel.Create;
  try
    Model.Load(Document.Preamble);
    Refresh(FAddonsTab);
  finally Model.Free; end;
end;
procedure TMainForm.AddonActionClick(Sender:TObject);
var ID,ActionID,Scope,Source,Selection,Code,Language,Value,Format,Placement,Root:string;
    Catalog:TEditorAddons; Addon:TEditorAddon; Context,Response:TJSONObject; Command:TJSONObject; Ini:TIniFile;
    A,B,P,Offset,First,Finish,InsertAt,CaretOffset,SelectionLength:Integer; Visual:TMathEditor; Target,Span:TMathSpan; Listing,DocumentContext:Boolean; Preamble:TPreambleModel; Session:TOpenDocument;
begin
  if ToolJobBusy then Exit;
  if DeferInput(@AddonActionClick,Sender) then Exit;
  if Sender is TMenuItem then ID:=TMenuItem(Sender).Hint else ID:=TControl(Sender).HelpKeyword;
  if (ID='configure') or (Copy(ID,1,10)='configure:') then begin AddonsClick(Sender); Exit; end;
  if (Sender is TPluginToggle) and (TPluginToggle(Sender).StatePackage<>'') then begin
    Preamble:=TPreambleModel.Create;
    try Preamble.Load(Document.Preamble);
      if (Preamble.PackageIndex(TPluginToggle(Sender).StatePackage)>=0)=TPluginToggle(Sender).Checked then Exit;
    finally Preamble.Free; end;
  end;
  P:=Pos(':',ID); ActionID:=Copy(ID,P+1,MaxInt); ID:=Copy(ID,1,P-1); Catalog:=TEditorAddons.Create(True); Context:=nil; Response:=nil;
  try
  try
    Catalog.Load; Addon:=Catalog.Find(ID); if Addon=nil then raise Exception.Create('The plug-in is no longer installed');
    Scope:='none'; DocumentContext:=False; Command:=FindPluginAction(Addon.Manifest.Arrays['actions'],ActionID);
    if Command<>nil then begin
      Scope:=Command.Get('scope','none'); DocumentContext:=Command.Get('contextSource','')='document';
      if Command.Get('requiresSavedDocument',False) and ((FileName='') or Modified) then
        if not SaveDocument(False) then Exit;
    end;
    if (Scope='body') and (EditingMath or FPreambleEditing or Document.PreambleOnly) then begin StatusText:='Place the caret in body text to insert this environment.'; Exit; end;
    Session:=TOpenDocument(FSessions[FSessionIndex]); Visual:=CurrentVisualEditor;
    if Editor.Visible then begin Source:=Editor.Text; Offset:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.LogicalCaretXY]); Selection:=Editor.SelText; end
    else begin Source:=Visual.Formula; Offset:=Visual.SourceCaret; Visual.GetSourceSelection(A,B); Selection:=Copy(Source,Min(A,B)+1,Abs(A-B)); end;
    Context:=TJSONObject.Create(['document',FileName,'directory',DocumentDirectory,'selection',Selection,'source',Source,'caret',Offset]);
    if DocumentContext then begin
      Context.Strings['source']:=NativeDocumentSource; Root:=Session.RootName; if Root='' then Root:=FileName;
      Context.Add('rootDocument',Root);
      if Root<>'' then Context.Strings['directory']:=ExtractFileDir(Root);
    end;
    Listing:=ListingAt(Source,Offset,First,Finish,Code,Language); Context.Add('listing',Listing);
    if Listing then Context.Add('code',Code) else Context.Add('code',Selection); Context.Add('language',Language);
    Target:=Default(TMathSpan);
    for Span in FindMath(Source) do if (Offset>=Span.Start-1) and (Offset<=Span.Start+Span.Count-1) then begin Target:=Span; Break; end;
    if Sender is TCheckBox then Context.Add('checked',TCheckBox(Sender).Checked);
    if Target.Start>0 then begin
      Context.Add('math',Copy(Source,Target.Start,Target.Count)); Context.Add('mathCaret',Offset-Target.Start+1);
      Context.Add('mathEnvironment',Target.Environment);
    end;
    if (Scope='math') and (Target.Start=0) then begin StatusText:='Place the caret in the formula to calculate.'; Exit; end;
    Response:=RunPluginAction(Self,Addon,ActionID,Context); if Response=nil then Exit;
    if Response.Get('openFile','')<>'' then begin LoadDocument(Response.Get('openFile','')); Exit; end;
    if Response.Get('openURL','')<>'' then begin
      Value:=Response.Get('openURL','');
      if (Pos('https://',Value)=1) or (Pos('http://',Value)=1) then OpenURL(Value);
      Exit;
    end;
    if Response.Get('reload',False) and (Session=TOpenDocument(FSessions[FSessionIndex])) and not Modified then LoadDocument(FileName,True);
    if Response.Get('output','')<>'' then ShowText(Addon.Name,Response.Get('output',''));
    if Response.Get('text','')<>'' then begin
      if Editor.Visible then Value:=Editor.Text else Value:=CurrentVisualEditor.Formula;
      if (FSessions.IndexOf(Session)<>FSessionIndex) or (Value<>Source) then begin
        ShowText('Plug-in result — document changed',Response.Get('text','')); Exit;
      end;
      Visual:=CurrentVisualEditor;
    end;
    if Response.Get('texInputs','')<>'' then begin
      Ini:=TIniFile.Create(GetAppConfigFile(False));
      try Ini.WriteString('Plugin.'+ID,'CompileTexInputs',Response.Get('texInputs','')); finally Ini.Free; end;
      StatusText:='Package search path configured: '+Response.Get('texInputs',''); QueuePreview; Exit;
    end;
    if Response.Get('compileEnabled',False) or (Response.Find('packages') is TJSONArray) or (Response.Find('removePackages') is TJSONArray) then begin
      if Response.Get('compileEnabled',False) then begin
        ForceDirectories(GetAppConfigDir(False)); Ini:=TIniFile.Create(GetAppConfigFile(False));
        try Ini.WriteBool('Compiler','ExtensionSteps',True); Ini.WriteBool('Plugin.'+ID,'CompileEnabled',True); finally Ini.Free; end;
      end;
      if (Response.Find('packages') is TJSONArray) or (Response.Find('removePackages') is TJSONArray) then begin
        Preamble:=TPreambleModel.Create;
        try
          Preamble.Load(Document.Preamble);
          if Response.Find('packages') is TJSONArray then
            for P:=0 to Response.Arrays['packages'].Count-1 do if Preamble.PackageIndex(Response.Arrays['packages'].Strings[P])<0 then Preamble.SetPackage(Response.Arrays['packages'].Strings[P],'');
          if Response.Find('removePackages') is TJSONArray then
            for P:=0 to Response.Arrays['removePackages'].Count-1 do begin
              A:=Preamble.PackageIndex(Response.Arrays['removePackages'].Strings[P]); if A>=0 then Preamble.Packages.Delete(A);
            end;
          if Preamble.Source<>Document.Preamble then begin RecordVisualEdit; Document.Preamble:=Preamble.Source; Modified:=True; UpdateTitle; RefreshProjectContext; RefreshPreambleEditor; end;
        finally Preamble.Free; end;
      end;
      RefreshAddonChecks; QueuePreview; if FPagedView=nil then Due:=0; Exit;
    end;
    Value:=Response.Get('text',''); if Value='' then Exit; Format:=Response.Get('format','plain'); Placement:=Response.Get('placement','selection');
    if Placement='source-range' then begin
      A:=EnsureRange(Response.Get('offset',0),0,Length(Source)); B:=EnsureRange(A+Response.Get('count',0),A,Length(Source));
      CaretOffset:=EnsureRange(Response.Get('caretOffset',Length(Value)),0,Length(Value));
      if Editor.Visible then begin Editor.BlockBegin:=BytePoint(Source,A); Editor.BlockEnd:=BytePoint(Source,B); Editor.SelText:=Value; end
      else Visual.ReplaceSource(Copy(Source,1,A)+Value+Copy(Source,B+1,MaxInt),A+CaretOffset);
    end else if ((Placement='math-end') or (Placement='math-offset')) and (Target.Start>0) then begin
      if Placement='math-offset' then InsertAt:=Target.Start-1+EnsureRange(Response.Get('offset',Target.Count),0,Target.Count)
      else begin
        if Copy(TrimRight(Context.Get('math','')),Length(TrimRight(Context.Get('math',''))),1)<>'=' then Value:='='+Value;
        InsertAt:=Target.Start+Target.Count-1;
      end;
      if Editor.Visible then begin Editor.LogicalCaretXY:=BytePoint(Source,InsertAt); Editor.BlockBegin:=Editor.LogicalCaretXY; Editor.BlockEnd:=Editor.BlockBegin; Editor.SelText:=Value; end
      else begin Visual.SetSourceCaret(InsertAt); Visual.InsertTeX(Value); end;
    end else if Listing and (Placement='after-listing') then begin
      Value:=LineEnding+'\begin{verbatim}'+LineEnding+Value+LineEnding+'\end{verbatim}'+LineEnding;
      if Editor.Visible then begin Editor.LogicalCaretXY:=BytePoint(Source,Finish); Editor.BlockBegin:=Editor.LogicalCaretXY; Editor.BlockEnd:=Editor.BlockBegin; Editor.SelText:=Value; end
      else begin Visual.SetSourceCaret(Finish); Visual.InsertBody(Value,Length(Value)); end;
    end else begin
      if (Format='plain') and not PluginSourceActive then Value:=EscapeTeXText(Value);
      if (Format='math') and not EditingMath then Value:='$'+Value+'$';
      if Response.Find('caretOffset')<>nil then begin
        CaretOffset:=EnsureRange(Response.Get('caretOffset',Length(Value)),0,Length(Value)); SelectionLength:=Response.Get('selectionLength',0);
        if Editor.Visible then begin
          A:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockBegin]); Editor.SelText:=Value;
          Editor.BlockBegin:=BytePoint(Editor.Text,A+CaretOffset); Editor.BlockEnd:=BytePoint(Editor.Text,A+CaretOffset+SelectionLength);
        end else begin
          Visual.InsertBody(Value,CaretOffset); A:=Visual.SourceCaret; if SelectionLength>0 then Visual.SetSourceSelection(A,A+SelectionLength);
        end;
      end else InsertBodySource(Value);
    end;
  except on E:Exception do MessageDlg(E.Message,mtError,[mbOK],0); end;
  finally Response.Free; Context.Free; Catalog.Free; end;
end;
