{ SPDX-License-Identifier: GPL-3.0-or-later }
procedure TMainForm.BuildMenu;
var Tools,DocumentMenu,TableMenu,References,Theorems,FontMenu,ParagraphMenu,Lists,MathMenu:TMenuItem;
    I,Operation:Integer; Item,Group,Target:TMenuItem;
  function Title(Menu:TMenuItem):string;
  begin Result:=StringReplace(Menu.Caption,'&','',[rfReplaceAll]); end;
  function Find(Root:TMenuItem; const Caption:string):TMenuItem;
  var K:Integer;
  begin Result:=nil; for K:=0 to Root.Count-1 do if Title(Root.Items[K])=Caption then Exit(Root.Items[K]); end;
  function Submenu(Root:TMenuItem; const Caption:string):TMenuItem;
  begin Result:=Find(Root,Caption); if Result=nil then begin Result:=TMenuItem.Create(Self); Result.Caption:=Caption; Root.Add(Result); end; Result.Visible:=True; end;
  procedure Move(Menu,Dest:TMenuItem);
  begin if Menu=nil then Exit; if Menu.Parent<>nil then Menu.Parent.Remove(Menu); Dest.Add(Menu); Menu.Visible:=True; end;
  procedure MoveContents(Menu,Dest:TMenuItem);
  begin
    if Menu=nil then Exit;
    while Menu.Count>0 do Move(Menu.Items[0],Dest);
    Menu.Visible:=False;
  end;
  procedure Order(const Caption:string; Index:Integer);
  var M:TMenuItem;
  begin M:=Find(AppMenu.Items,Caption); if M<>nil then M.MenuIndex:=Index; end;
  procedure MoveBibliographyInsert(Menu:TMenuItem);
  var K:Integer;
  begin
    for K:=Menu.Count-1 downto 0 do
      if Menu.Items[K].Hint='@bibliographyinsert' then Move(Menu.Items[K],InsertMenu);
  end;
begin
  Tools:=Submenu(AppMenu.Items,'&Tools'); DocumentMenu:=Submenu(Tools,'Document');
  TableMenu:=Find(AppMenu.Items,'Table'); References:=Find(AppMenu.Items,'References'); Theorems:=Find(AppMenu.Items,'Theorems');
  Move(NavigateMenu,Tools); NavigateMenu.Caption:='Equation';
  MoveContents(Find(Theorems,'Theorems'),Theorems); Move(Theorems,Tools);
  FontMenu:=Find(FormatMenu,'Font'); if FontMenu=nil then FontMenu:=Submenu(FormatMenu,'Font');
  Move(BoldMenuItem,FontMenu); BoldMenuItem.MenuIndex:=0; Move(ItalicMenuItem,FontMenu); ItalicMenuItem.MenuIndex:=1;
  ParagraphMenu:=Find(FormatMenu,'Paragraph'); if ParagraphMenu=nil then ParagraphMenu:=Submenu(FormatMenu,'Paragraph');
  HeadingMenuItem.Visible:=False; { Paragraph style includes document theorem styles too. }
  MoveContents(Find(FormatMenu,'Clipboard'),EditMenu);
  MoveContents(Find(FormatMenu,'Editing'),EditMenu);
  for I:=ViewMenu.Count-1 downto 0 do if ViewMenu.Items[I].Hint='@comment' then begin
    Item:=ViewMenu.Items[I]; Item.ShortCut:=ShortCut(VK_OEM_2,[ssCtrl]); Move(Item,EditMenu);
  end;
  for I:=ViewMenu.Count-1 downto 0 do begin
    Item:=ViewMenu.Items[I];
    if (Item=SettingsMenuItem) or (Item=LogMenuItem) or (Item=EngineMenu) then Move(Item,DocumentMenu);
  end;
  MoveContents(Find(ViewMenu,'Document'),DocumentMenu);
  MoveContents(Find(ViewMenu,'Zoom'),ViewMenu);
  Group:=Find(ViewMenu,'Source editor'); if Group<>nil then begin
    for I:=Group.Count-1 downto 0 do if Group.Items[I].Hint='Source word wrap' then Group.Items[I].Visible:=False;
    Move(SourceWrapMenuItem,Group);
  end;
  for I:=FileMenu.Count-1 downto 0 do if Title(FileMenu.Items[I])='Options…' then Move(FileMenu.Items[I],Tools);
  for I:=ViewMenu.Count-1 downto 0 do if Title(ViewMenu.Items[I])='Appearance and settings…' then ViewMenu.Items[I].Visible:=False;
  Lists:=Find(InsertMenu,'Lists'); if Lists=nil then Lists:=Submenu(InsertMenu,'Lists');
  MoveContents(Find(InsertMenu,'Commands'),Submenu(EditMenu,'Commands'));
  for I:=InsertMenu.Count-1 downto 0 do if (InsertMenu.Items[I].Hint='@list:itemize') or
    (InsertMenu.Items[I].Hint='@list:enumerate') or (InsertMenu.Items[I].Hint='@theorem') or
    (InsertMenu.Items[I].Hint='@theoremtitle') then InsertMenu.Items[I].Visible:=False;
  Group:=Submenu(InsertMenu,'Cross-references'); MoveContents(Find(InsertMenu,'Cross reference'),Group);
  if References<>nil then begin
    for I:=References.Count-1 downto 0 do begin
      Item:=References.Items[I];
      if Title(Item)='Bibliography' then begin MoveBibliographyInsert(Item); Move(Item,Tools); end
      else if Title(Item)='Contents' then Move(Item,InsertMenu)
      else MoveContents(Item,Group);
    end;
    References.Visible:=False;
  end;
  MoveContents(Find(FormatMenu,'Image'),Submenu(FormatMenu,'Figures and captions'));
  MoveContents(Find(FormatMenu,'Drawing'),Submenu(FormatMenu,'Figures and captions'));
  MoveContents(Find(FormatMenu,'Caption'),Submenu(FormatMenu,'Figures and captions'));
  MathMenu:=Find(InsertMenu,'Equation');
  if MathMenu<>nil then begin
    MathMenu.Caption:='Equations'; MathMenu.OnClick:=nil;
    Move(StructuresMenu,MathMenu); Move(TemplatesMenu,MathMenu); Move(SymbolsMenu,MathMenu);
  end;
  Group:=Find(InsertMenu,'Formula layouts'); if Group<>nil then Group.Visible:=False;
  Group:=Find(InsertMenu,'Equation tools'); if Group<>nil then Move(Group,NavigateMenu);
  if TableMenu<>nil then begin
    Group:=Find(TableMenu,'Rows and columns');
    if Group<>nil then while Group.Count>0 do begin
      Item:=Group.Items[0]; Operation:=StrToIntDef(Copy(Item.Hint,8,MaxInt),-1);
      case Operation of
        0,1,3,4:Target:=Submenu(TableMenu,'Insert');
        2,5:Target:=Submenu(TableMenu,'Delete');
        6,7,10,11:Target:=Submenu(TableMenu,'Move');
        else Target:=Submenu(TableMenu,'Duplicate');
      end;
      Move(Item,Target);
    end;
    if Group<>nil then Group.Visible:=False;
    Group:=Find(TableMenu,'Lines'); if Group<>nil then Group.Caption:='Borders';
  end;
  Order('File',0); Order('Edit',1); Order('View',2); Order('Insert',3); Order('Format',4);
  Order('Table',5); Order('Tools',6); Order('Help',AppMenu.Items.Count-1);
  Item:=TMenuItem.Create(Self); Item.Caption:='Find a command…'; Item.ShortCut:=ShortCut(VK_Q,[ssAlt]); Item.OnClick:=@FindCommandClick;
  EditMenu.Insert(0,Item);
  Item:=TMenuItem.Create(Self); Item.Caption:='Collapse ribbon'; Item.ShortCut:=ShortCut(VK_F1,[ssCtrl]); Item.OnClick:=@ToggleRibbon;
  Item.Name:='CollapseRibbonMenu'; ViewMenu.Add(Item);
  Item:=TMenuItem.Create(Self); Item.Caption:='Go to preview position in full source'; Item.OnClick:=@LocateSourceFromPreview; ViewMenu.Add(Item);
  Item:=TMenuItem.Create(Self); Item.Caption:='Show source position in preview'; Item.OnClick:=@LocatePreviewFromSource; ViewMenu.Add(Item);
end;
procedure TMainForm.FindCommandClick(Sender:TObject);
var Form:TCommandSearchForm; Command:TMenuItem;
begin
  if DeferInput(@FindCommandClick,Sender) then Exit;
  Command:=nil; Form:=TCommandSearchForm.Create(Self);
  try Form.Load(AppMenu); if Form.ShowModal=mrOK then Command:=Form.SelectedCommand;
  finally Form.Free; end;
  if (Command<>nil) and Command.Enabled then Command.Click;
end;
procedure TMainForm.UpdateRibbonVisibility;
var I,J:Integer; Page:TTabSheet; Control:TControl;
begin
  if FFocusMode then begin Ribbon.Visible:=False; Exit; end;
  {$IFDEF LCLgtk3}
  { GTK3's notebook retains its page minimum after child widgets are hidden. }
  Ribbon.Visible:=not FRibbonCollapsed;
  Exit;
  {$ENDIF}
  Ribbon.DisableAlign;
  try
    for I:=0 to Ribbon.PageCount-1 do begin
      Page:=Ribbon.Pages[I];
      for J:=0 to Page.ControlCount-1 do begin
        Control:=Page.Controls[J];
        if Control.HelpKeyword='ribbon-content' then Control.Visible:=not FRibbonCollapsed;
      end;
    end;
    if FRibbonCollapsed then Ribbon.Height:=34 else Ribbon.Height:=FRibbonFullHeight;
  finally Ribbon.EnableAlign; end;
end;
procedure TMainForm.ToggleRibbon(Sender:TObject);
var Ini:TIniFile; Item:TMenuItem;
begin
  FRibbonCollapsed:=not FRibbonCollapsed;
  UpdateRibbonVisibility;
  Item:=TMenuItem(FindComponent('CollapseRibbonMenu')); if Item<>nil then SetMenuChecked(Item,FRibbonCollapsed);
  Ini:=TIniFile.Create(GetAppConfigFile(False));
  try Ini.WriteBool('View','CollapsedRibbon',FRibbonCollapsed); finally Ini.Free; end;
end;
