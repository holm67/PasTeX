{ SPDX-License-Identifier: GPL-3.0-or-later }
procedure TMainForm.BuildRibbon;
var I,J,X:Integer; Row:TScrollBox; G:TPanel; L:TLabel;
    B:TSpeedButton; C:TComboBox; MenuRoot,GroupMenu,FontItem:TMenuItem; Ini:TIniFile; Separator:TBevel;
  procedure Tab(P:TTabSheet);
  var K:Integer;
  begin
    if P=HomeTab then MenuRoot:=FormatMenu
    else if P=InsertTab then MenuRoot:=InsertMenu
    else if P=EquationTab then MenuRoot:=NavigateMenu
    else if (P=ViewTab) or (P=FViewRibbon) then MenuRoot:=ViewMenu
    else if P=TablesTab then begin MenuRoot:=TMenuItem.Create(Self); MenuRoot.Caption:='&Table'; AppMenu.Items.Add(MenuRoot); end
    else if P=TheoremsTab then begin MenuRoot:=TMenuItem.Create(Self); MenuRoot.Caption:='Theorems'; AppMenu.Items.Add(MenuRoot); end
    else if P=CommandsTab then MenuRoot:=EditMenu
    else if (P=FiguresTab) or (P=ColorBoxesTab) or (P=ListingsTab) then MenuRoot:=FormatMenu
    else begin
      MenuRoot:=nil;
      for K:=0 to AppMenu.Items.Count-1 do if AppMenu.Items[K].Caption='References' then MenuRoot:=AppMenu.Items[K];
      if MenuRoot=nil then MenuRoot:=InsertMenu;
    end;
    for K:=0 to P.ControlCount-1 do P.Controls[K].Visible:=False;
    Row:=TScrollBox.Create(Self); Row.HelpKeyword:='ribbon-content'; Row.Parent:=P; Row.Align:=alClient;
    Row.BorderStyle:=bsNone; Row.VertScrollBar.Visible:=False;
    Row.HorzScrollBar.Tracking:=True; X:=6;
  end;
  procedure Group(const Title:string; Width:Integer);
  begin
    G:=TPanel.Create(Self); G.Parent:=Row; G.SetBounds(X,2,Width,80);
    G.BevelOuter:=bvNone; Inc(X,Width+8);
    Separator:=TBevel.Create(Self); Separator.Parent:=Row; Separator.Shape:=bsLeftLine;
    Separator.SetBounds(X-4,7,2,64);
    GroupMenu:=TMenuItem.Create(Self); GroupMenu.Caption:=Title; GroupMenu.Visible:=False; MenuRoot.Add(GroupMenu);
    L:=TLabel.Create(Self); L.Parent:=G; L.Caption:=Title; L.Alignment:=taCenter;
    L.AutoSize:=False; L.SetBounds(0,62,Width,16); L.Font.Size:=9;
  end;
  function Button(const Title,Symbol:string; Left,Width:Integer; Event:TNotifyEvent):TSpeedButton;
  begin
    Result:=TCommandRibbonButton.Create(Self); Result.Parent:=G; Result.SetBounds(Left,4,Width,34);
    Result.Caption:=Symbol; Result.Hint:=Title; Result.ShowHint:=True; Result.Flat:=True;
    Result.OnClick:=Event;
    if Symbol<>'' then begin
      Result.HelpKeyword:='literal'; Result.Font.Size:=14;
      if UTF8Length(Symbol)>5 then Result.Font.Size:=10;
    end;
  end;
  function DefinitionButton(const Title,Symbol:string; Left,Width,ID:Integer):TSpeedButton;
  var A:TMenuItem;
  begin
    Result:=Button(Title,Symbol,Left,Width,@DefinitionAction); Result.Tag:=ID;
    A:=TMenuItem.Create(Self); A.Caption:=Title; A.Tag:=ID; A.OnClick:=@DefinitionAction;
    GroupMenu.Add(A); GroupMenu.Visible:=True;
  end;
  procedure Action(const Title,Code,Symbol:string; Left:Integer; Width:Integer=34);
  var A:TMenuItem; Btn:TSpeedButton;
  begin
    A:=TMenuItem.Create(Self); A.Caption:=Title; A.Hint:=Code; A.OnClick:=@ToolCommandClick;
    { Every new ribbon command has a keyboard-accessible menu counterpart. }
    GroupMenu.Add(A); GroupMenu.Visible:=True;
    Btn:=Button(Title,Symbol,Left,Width,@RibbonAction); Btn.Tag:=PtrInt(A);
    TCommandRibbonButton(Btn).MenuCommand:=A;
  end;
  procedure Popup(const Title,Symbol:string; Left,Category:Integer; Width:Integer=42);
  var Btn:TSpeedButton; A,M:TMenuItem; K:Integer;
  begin
    Btn:=Button(Title,Symbol,Left,Width,@ToolPopupClick); Btn.Tag:=Category;
    for K:=0 to ToolPopups[Category].Items.Count-1 do begin
      A:=ToolPopups[Category].Items[K]; M:=TMenuItem.Create(Self);
      M.Caption:=A.Caption; M.Hint:=A.Hint; M.Tag:=A.Tag; M.OnClick:=A.OnClick; GroupMenu.Add(M);
    end;
    GroupMenu.Visible:=True;
  end;
  procedure Palette(const Title,Symbol,Commands:string; Left,Width:Integer);
  var Btn:TSpeedButton; Pop:TPopupMenu; Words:TStringList; K:Integer; A,M:TMenuItem;
  begin
    Pop:=TPopupMenu.Create(Self); Words:=TStringList.Create;
    try
      Words.Delimiter:='|'; Words.StrictDelimiter:=True; Words.DelimitedText:=Commands;
      for K:=0 to Words.Count-1 do begin
        A:=TMenuItem.Create(Self); A.Caption:=Words[K];
        if Copy(A.Caption,1,5)='@new:' then A.Caption:=Copy(A.Caption,6,MaxInt)
        else if Copy(A.Caption,1,12)='@bodyinsert:' then A.Caption:=Copy(A.Caption,13,MaxInt)
        else if A.Caption='@list:description' then A.Caption:='Description list'
        else if A.Caption='@textcolor:default' then A.Caption:='Document default color';
        A.Hint:=Words[K]; A.OnClick:=@ToolCommandClick; Pop.Items.Add(A);
        M:=TMenuItem.Create(Self); M.Caption:=A.Caption; M.Hint:=A.Hint; M.OnClick:=@ToolCommandClick; GroupMenu.Add(M);
      end;
    finally Words.Free; end;
    GroupMenu.Visible:=True; Btn:=Button(Title,Symbol,Left,Width,@RibbonDropDown); Btn.PopupMenu:=Pop;
  end;
  function Choice(const Choices,Hint:string; Left,Width,ID:Integer):TComboBox;
  var Menu,A:TMenuItem; K:Integer;
  begin
    Result:=TComboBox.Create(Self); Result.Parent:=G; Result.SetBounds(Left,7,Width,30);
    Result.Style:=csDropDownList; Result.Items.Delimiter:=';'; Result.Items.StrictDelimiter:=True;
    Result.Items.DelimitedText:=Choices; Result.ItemIndex:=0; Result.Hint:=Hint; Result.ShowHint:=True;
    Result.Tag:=ID; Result.OnChange:=@RibbonChoice;
    Menu:=TMenuItem.Create(Self); Menu.Caption:=Hint; Menu.Tag:=PtrInt(Result); GroupMenu.Add(Menu); GroupMenu.Visible:=True;
    for K:=0 to Result.Items.Count-1 do begin
      A:=TMenuItem.Create(Self); A.Caption:=Result.Items[K]; A.Tag:=K; A.OnClick:=@RibbonChoiceMenu; Menu.Add(A);
    end;
  end;
  procedure MoveButton(Control:TControl; Left:Integer; const Title:string);
  begin
    Control.Parent:=G; Control.Visible:=True; Control.SetBounds(Left,4,34,34);
    Control.Hint:=Title;
    if Control is TBitBtn then TBitBtn(Control).Caption:='';
    if Control is TSpeedButton then TSpeedButton(Control).Caption:='';
  end;
  procedure RowAction(const Title,Code,Symbol:string; Left,Top:Integer);
  var Btn:TSpeedButton;
  begin
    Action(Title,Code,Symbol,Left,30); Btn:=TSpeedButton(G.Controls[G.ControlCount-1]);
    if Top=1 then Top:=2 else if Top=25 then Top:=32;
    Btn.Top:=Top; Btn.Height:=28; Btn.Font.Size:=10;
  end;
  procedure FontRow(Control:TControl);
  begin
    {$IFDEF LCLgtk3}Control.Top:=40;{$ELSE}Control.Top:=31;{$ENDIF}
    Control.Height:=28;
  end;
begin
  FUpdatingRibbon:=True;
  try
  Ribbon.Height:=112;
  Tab(HomeTab);
  Group('Clipboard',112);
  MoveButton(HomeEditingPasteButton,0,'Paste'); HomeEditingPasteButton.SetBounds(0,2,42,56);
  MoveButton(HomeEditingCutButton,46,'Cut'); HomeEditingCutButton.Height:=28;
  MoveButton(HomeEditingCopyButton,78,'Copy'); HomeEditingCopyButton.Height:=28;
  MoveButton(HomeEditingSelectallButton,46,'Select all'); HomeEditingSelectallButton.SetBounds(46,32,64,28);
  Group('Font',336); G.Height:=80; L.Top:=62;
  {$IFDEF LCLgtk3}
  { The native GTK3 combo has a taller minimum allocation. }
  G.Height:=90; L.Top:=72; Ribbon.Height:=122;
  {$ENDIF}
  C:=Choice('Roman;Sans serif;Monospace','Text font family',0,184,1); C.Name:='TextFamilyChoice'; C.Top:=1; C.Height:=28;
  C:=Choice('tiny;scriptsize;footnotesize;small;normal;large;Large;LARGE;huge;Huge;Custom…','Text size',188,108,2);
  C.Name:='TextSizeChoice'; C.ItemIndex:=4; C.Top:=1; C.Height:=28;
  MoveButton(HomeTextBoldButton,0,'Bold'); FontRow(HomeTextBoldButton);
  MoveButton(HomeTextItalicButton,36,'Italic'); FontRow(HomeTextItalicButton);
  Action('Sans serif (\textsf)','@textstyle:\textsf','S',72,32);
  B:=TSpeedButton(G.Controls[G.ControlCount-1]); B.AllowAllUp:=True; B.GroupIndex:=31; B.Font.Name:='Sans';
  FontRow(B);
  Action('Monospace (\texttt)','@textstyle:\texttt','T',106,32);
  B:=TSpeedButton(G.Controls[G.ControlCount-1]); B.AllowAllUp:=True; B.GroupIndex:=32; B.Font.Name:=DefaultSourceFont;
  FontRow(B);
  Action('Small caps (\textsc)','@textstyle:\textsc','Sc',140,32);
  B:=TSpeedButton(G.Controls[G.ControlCount-1]); B.AllowAllUp:=True; B.GroupIndex:=33;
  FontRow(B);
  Action('Slanted (\textsl)','@textstyle:\textsl','Sl',174,32);
  B:=TSpeedButton(G.Controls[G.ControlCount-1]); B.AllowAllUp:=True; B.GroupIndex:=34; B.Font.Style:=[fsItalic];
  FontRow(B);
  Action('Upright (\textup)','@textstyle:\textup','U',208,32);
  B:=TSpeedButton(G.Controls[G.ControlCount-1]); B.AllowAllUp:=True; B.GroupIndex:=35;
  FontRow(B);
  Action('Text color…','@textcolor','A',242,30); FontRow(G.Controls[G.ControlCount-1]);
  Palette('Text color options','▾','@textcolor:default',272,18);
  B:=TSpeedButton(G.Controls[G.ControlCount-1]); B.Font.Size:=9; FontRow(B);
  Action('Clear formatting','@clearformat','A×',296,32); G.Controls[G.ControlCount-1].Name:='ClearFormattingButton'; FontRow(G.Controls[G.ControlCount-1]);
  Group('Paragraph',176); G.Height:=80; L.Top:=62;
  {$IFDEF LCLgtk3}G.Height:=90; L.Top:=72;{$ENDIF}
  C:=Choice('Normal','Heading style',0,176,3); C.Top:=1; C.Height:=28;
  C.Name:='ParagraphStyles'; C.OnDropDown:=@RefreshParagraphStyles;
  Action('Align left','@bodyenv:flushleft','≡L',0,38); FontRow(G.Controls[G.ControlCount-1]);
  Action('Center','@bodyenv:center','≡',42,38); FontRow(G.Controls[G.ControlCount-1]);
  Action('Align right','@bodyenv:flushright','≡R',84,38); FontRow(G.Controls[G.ControlCount-1]);
  Action('Justify (normal paragraph)','@bodyenv:','≡J',126,38); FontRow(G.Controls[G.ControlCount-1]);
  Group('Editing',126);
  Action('Comment / uncomment','@comment','%',0,34);
  Button('Edit selection source in place (Ctrl+L)','</>',40,34,@SelectionSourceClick);
  Action('Properties…','@properties','ƒ',80,38);
  G.Controls[G.ControlCount-1].Name:='BodyCommandArgumentsButton';
  FontItem:=TMenuItem.Create(Self); FontItem.Caption:='Edit command and arguments…'; FontItem.Hint:='@command';
  FontItem.OnClick:=@ToolCommandClick; GroupMenu.Add(FontItem);
  B:=nil; MenuRoot:=ViewMenu;
  GroupMenu:=TMenuItem.Create(Self); GroupMenu.Caption:='Full document source…'; GroupMenu.OnClick:=@FullSourceClick;
  GroupMenu.ShortCut:=ShortCut(VK_U,[ssCtrl,ssShift]); ViewMenu.Add(GroupMenu);
  Tab(InsertTab);
  Group('Lists',90);
  RowAction('Bulleted list','@list:itemize','• ≡',4,2);
  RowAction('Numbered list','@list:enumerate','1 ≡',46,2);
  RowAction('Description list','@list:description','a:',4,32);
  Group('Cross reference',90);
  RowAction('Label…','@label','',4,2); RowAction('Tag…','@tag','#',46,2);
  RowAction('Cite a label…','@citation','↗',4,32); RowAction('Edit reference…','@editref','↗✎',46,32);
  Group('Environment',132);
  Action('Insert theorem…','@theorem','T+',0,38);
  Action('Insert environment…','@environmentinsert','',44,38);
  Action('Start appendices','@appendix','A+',88,38);
  Group('Commands',132); Button('Define command','≔',0,38,@DefineCommandClick);
  Button('Renew command','↻≔',44,38,@RenewCommandClick);
  Button('Declare math operator','op',88,38,@DeclareOperatorClick);
  Group('Notes',132);
  B:=Button('Insert footnote','',0,36,@FootnoteClick); B.Tag:=0;
  B:=Button('Insert footnote mark','',44,36,@FootnoteClick); B.Tag:=1;
  B:=Button('Insert margin note','',88,36,@FootnoteClick); B.Tag:=3;
  Group('Equation',142);
  Action('Insert inline formula','@new:inline','x',0,38);
  Action('Insert displayed formula','@new:display','[x]',42,42);
  Palette('Equation environment list','','@new:equation|@new:equation*|@new:align|@new:align*|@new:gather|@new:gather*|@new:gathered|@new:eqnarray',88,48);
  Group('Tables',90);
  Action('Insert table…','@tableinsert','▦',0,38);
  Button('Import spreadsheet data','',44,38,@ImportDataClick);
  Group('Illustrations',90);
  RowAction('Insert image…','@figureinsert','',4,2);
  RowAction('Insert TikZ / PGFPlots…','@diagraminsert','',46,2);
  RowAction('Insert figure environment','@bodyinsert:figure','',4,32);
  RowAction('Include PDF pages…','@pdfinsert','',46,32);
  TablesTab:=TTabSheet.Create(Self); TablesTab.PageControl:=Ribbon; TablesTab.Caption:='Table';
  Tab(TablesTab);
  Group('Rows and columns',254);
  L:=TLabel.Create(Self); L.Parent:=G; L.SetBounds(2,4,54,18); L.Caption:='Rows'; L.Font.Size:=9;
  L:=TLabel.Create(Self); L.Parent:=G; L.SetBounds(2,36,54,18); L.Caption:='Columns'; L.Font.Size:=9;
  RowAction('Insert row above','@table:0','↑+',58,1); RowAction('Insert row below','@table:1','↓+',90,1);
  RowAction('Delete row','@table:2','R−',122,1); RowAction('Swap row up','@table:6','↑',154,1);
  RowAction('Swap row down','@table:7','↓',186,1); RowAction('Duplicate row','@table:8','⧉',218,1);
  RowAction('Insert column before','@table:3','←+',58,25); RowAction('Insert column after','@table:4','→+',90,25);
  RowAction('Delete column','@table:5','C−',122,25); RowAction('Swap column left','@table:10','←',154,25);
  RowAction('Swap column right','@table:11','→',186,25); RowAction('Duplicate column','@table:9','⧉',218,25);
  Group('Cells',88); Action('Merge selected cells','@table:12','',0,38); Action('Split cell','@table:13','',42,38);
  Group('Lines',186); Action('Table lines…','@tablelines','▦',0,42);
  RowAction('Add top border','@border:0','┬+',46,1); RowAction('Add bottom border','@border:1','┴+',80,1);
  RowAction('Add left border','@border:2','├+',114,1); RowAction('Add right border','@border:3','┤+',148,1);
  RowAction('Delete top border','@border:4','┬−',46,25); RowAction('Delete bottom border','@border:5','┴−',80,25);
  RowAction('Delete left border','@border:6','├−',114,25); RowAction('Delete right border','@border:7','┤−',148,25);
  Group('Caption',52); Action('Caption and float placement…','@floatcaption','',0,44);
  Group('Properties',52); Action('Table environment options…','@environmentoptions','',0,44);
  FiguresTab:=TTabSheet.Create(Self); FiguresTab.Name:='FiguresTab'; FiguresTab.PageControl:=Ribbon; FiguresTab.Caption:='Figure';
  Tab(FiguresTab);
  Group('Image',88);
  Action('Insert image…','@figureinsert','',0,38);
  Action('Edit figure image…','@figureedit','',44,38); FigureImageButton:=TSpeedButton(G.Controls[G.ControlCount-1]);
  Group('Drawing',52);
  Action('Edit TikZ / PGFPlots…','@diagramedit','',0,44); FigureDiagramButton:=TSpeedButton(G.Controls[G.ControlCount-1]);
  Group('Caption',52);
  Action('Caption and float placement…','@floatcaption','',0,44); FigureCaptionButton:=TSpeedButton(G.Controls[G.ControlCount-1]);
  Tab(EquationTab);
  Group('Symbols',234);
  Action('Symbol gallery…','@symbols','α β ▾',0,96);
  Action('Arrows…','@arrows','⇄',100,42);
  Action('Functions and limits…','@functions','sin',146,40);
  Action('Insert math command…','@mathcommand','ƒ+',190,40);
  Group('Structure',244);
  RowAction('Superscript','^{}','x²',0,2); RowAction('Subscript','_{}','x₂',36,2);
  RowAction('Square root','\sqrt','√',72,2); RowAction('Nth root','@nroot','ⁿ√',108,2);
  RowAction('Fraction','\frac','',0,32); RowAction('Matrix…','@matrix','▦',36,32);
  Action('Paired delimiters…','@delimiters','( )',72,66); FontRow(G.Controls[G.ControlCount-1]);
  Palette('Large operators','∑ ▾','\sum|\prod|\coprod|\int|\iint|\iiint|\oint|\bigcup|\bigcap|\lim',144,44);
  Palette('Math spaces','␣ ▾','\,|\:|\;|\!|\ |\quad|\qquad',192,44);
  Popup('Accents','â ▾',144,3,44); FontRow(G.Controls[G.ControlCount-1]);
  Group('Math fonts',98); Popup('Math fonts','𝔸 ▾',0,2,94);
  Group('Environments',112); Popup('Math environments','aligned ▾',0,4,108);
  Group('Rows and columns',88);
  Action('Duplicate row','@grid:6','',0,38); DuplicateMathRowButton:=TSpeedButton(G.Controls[G.ControlCount-1]);
  Action('Duplicate column','@grid:7','',42,38); DuplicateMathColumnButton:=TSpeedButton(G.Controls[G.ControlCount-1]);
  Group('Display style',100); Action('Inline','@inline','x',0,44); Action('Displayed','@display','[x]',48,46);
  Group('Edit',48); Action('Edit this equation source','@formulasource','</>',4,38);
  FormulaSourceButton:=TSpeedButton(G.Controls[G.ControlCount-1]);
  FormulaSourceButton.Name:='FormulaSourceButton'; FormulaSourceButton.AllowAllUp:=True; FormulaSourceButton.GroupIndex:=36;
  for I:=0 to Ribbon.PageCount-1 do if Ribbon.Pages[I].Caption='References' then begin Tab(Ribbon.Pages[I]); Break; end;
  Group('Contents',126);
  Action('Table of contents','@bodyinsert:\tableofcontents','',0);
  Action('List of figures','@bodyinsert:\listoffigures','',42);
  Action('List of tables','@bodyinsert:\listoftables','',84);
  Group('Labels',84); Action('Label…','@label','',0); Action('Tag…','@tag','#',42);
  Group('Cite',198); Action('Choose reference and type…','@citation','↗ Cite…',0,110); Action('Edit reference…','@editref','↗✎',122,66);
  Group('Bibliography',204); Action('Bibliography configuration…','@bibliography','',0);
  Action('Insert bibliography list…','@bibliographyinsert','≡+',40,38);
  Action('Bibliography citation…','@bibcite','Cite key…',84,112);
  TheoremsTab:=TTabSheet.Create(Self); TheoremsTab.PageControl:=Ribbon; TheoremsTab.Caption:='Theorems';
  Tab(TheoremsTab);
  Group('Theorems',152);
  Action('Insert theorem…','@theorem','T+',0,42);
  Action('Manage theorem environments…','@theoremmanager','T⚙',46,48);
  Action('Edit theorem title','@theoremtitle','T✎',98,42);
  CommandsTab:=TTabSheet.Create(Self); CommandsTab.Name:='CommandDefinitionTab'; CommandsTab.PageControl:=Ribbon; CommandsTab.Caption:='Command definition'; Tab(CommandsTab);
  Group('Arguments',92);
  DefinitionButton('Add required argument','{#}',4,38,0);
  DefinitionButton('Add optional argument','[#]',48,38,1);
  Group('Definition',306);
  DefinitionKind:=TComboBox.Create(Self); DefinitionKind.Parent:=G; DefinitionKind.Name:='DefinitionKind';
  DefinitionKind.SetBounds(4,7,210,28); DefinitionKind.Style:=csDropDownList;
  DefinitionKind.Items.CommaText:='Define,Renew,Provide,Declare,Robust,"Math operator","Operator with limits","TeX definition"';
  DefinitionKind.Hint:='Definition form: newcommand, renewcommand, providecommand, DeclareDocumentCommand or DeclareRobustCommand'; DefinitionKind.ShowHint:=True;
  DefinitionKind.OnChange:=@DefinitionKindChanged;
  DefinitionButton('Configure definition arguments…','ƒ',220,38,3);
  DefinitionSourceButton:=DefinitionButton('Edit definition source','</>',264,38,4);
  DefinitionSourceButton.GroupIndex:=12; DefinitionSourceButton.AllowAllUp:=True;
  ColorBoxesTab:=TTabSheet.Create(Self); ColorBoxesTab.Name:='ColorBoxesTab';
  ColorBoxesTab.PageControl:=Ribbon; ColorBoxesTab.Caption:='Box'; Tab(ColorBoxesTab);
  Group('Box',88);
  Action('Box settings…','@boxoptions','',0,38);
  Action('Edit box source','@boxsource','',44,38);
  ListingsTab:=TTabSheet.Create(Self); ListingsTab.Name:='ListingsTab';
  ListingsTab.PageControl:=Ribbon; ListingsTab.Caption:='Listing'; Tab(ListingsTab);
  Group('Code listing',44);
  Action('Listing options…','@environmentoptions:lstlisting','',0);
  FViewRibbon:=TTabSheet.Create(Self); FViewRibbon.Name:='DocumentViewTab';
  FViewRibbon.PageControl:=Ribbon; FViewRibbon.Caption:='View'; Tab(FViewRibbon);
  Group('Document views',264);
  MoveButton(HomeModeEquationButton,0,'Visual editor');
  MoveButton(HomeModeSourceButton,42,'Source editor');
  MoveButton(HomeModePreviewButton,84,'Open compiled PDF (Ctrl+R)');
  Button('Full document source','',126,36,@FullSourceClick);
  B:=Button('Paged TeX editor','',168,36,@PagedViewClick); B.Name:='PagedEditorButton';
  B:=Button('Source / compiled PDF','',210,36,@SplitViewClick); B.Name:='SourcePDFButton';
  Group('Locate',88);
  Button('Go to preview position in full source','',0,36,@LocateSourceFromPreview);
  Button('Show source position in preview','',42,36,@LocatePreviewFromSource);
  Group('Preview',88);
  Button('Refresh preview','',0,36,@PreviewClick);
  Button('Export PDF…','',42,36,@ExportPDF);
  Group('Show',192);
  FNavigationCheck:=TCheckBox.Create(Self); FNavigationCheck.Name:='NavigationCheck'; FNavigationCheck.Parent:=G;
  FNavigationCheck.SetBounds(4,0,140,26); FNavigationCheck.Caption:='Navigation panel'; FNavigationCheck.OnClick:=@ToggleNavigation;
  FInlineSubfilesCheck:=TCheckBox.Create(Self); FInlineSubfilesCheck.Parent:=G; FInlineSubfilesCheck.Name:='InlineSubfilesCheck';
  FInlineSubfilesCheck.SetBounds(4,27,140,26); FInlineSubfilesCheck.Caption:='Subfiles in place'; FInlineSubfilesCheck.OnClick:=@ToggleInlineSubfiles;
  B:=Button('Focus / fullscreen (F11)','',148,36,@FocusModeClick); B.Name:='FocusModeButton'; B.GroupIndex:=99; B.AllowAllUp:=True;
  Group('Zoom',112);
  ZoomChoice:=Choice('Fit Width;100%;50%;75%;125%;150%;200%','Preview scale',0,108,5);
  SelectZoom(ZoomChoice,FPreviewPercent);
  Tab(ViewTab); ViewTab.Caption:='Settings';
  Group('Document',170);
  Button('Preamble and document settings','',0,36,@PreambleClick);
  Button('Compiler log','',40,36,@LogClick);
  B:=Button('Document information','',80,36,@DocumentInfoClick); B.Name:='DocumentInformation';
  Engine.Parent:=G; Engine.Visible:=True; Engine.SetBounds(0,34,160,28);
  Group('Editor options',132);
  B:=Button('Source editor settings','',0,36,@PreferencesClick); B.Name:='SourceSettingsButton';
  Button('Keyboard shortcuts','',44,36,@ShortcutsClick);
  Button('Appearance and settings','',88,36,@PreferencesClick);
  Group('Appearance',170);
  AppearanceChoice:=Choice('Light;Dark;Follow system','Appearance (applies immediately)',0,166,4);
  AppearanceChoice.ItemIndex:=Ord(AppearanceMode);
  Group('System',132);
  Button('Add-ons and external tools','',0,36,@AddonsClick);
  Button('Check environment and dependencies','',44,36,@EnvironmentCheckClick);
  Button('About PasTeX','',88,36,@AboutClick);
  HomeTab.PageIndex:=0; InsertTab.PageIndex:=1;
  for I:=0 to Ribbon.PageCount-1 do if Ribbon.Pages[I].Caption='References' then begin Ribbon.Pages[I].PageIndex:=2; Break; end;
  TablesTab.PageIndex:=3; FiguresTab.PageIndex:=4; EquationTab.PageIndex:=5; TheoremsTab.PageIndex:=6;
  CommandsTab.PageIndex:=7; ColorBoxesTab.PageIndex:=8; ListingsTab.PageIndex:=9; FViewRibbon.PageIndex:=10; ViewTab.PageIndex:=11;
  RetainTabPages(Ribbon);
  SetPageVisible(TablesTab,False); SetPageVisible(FiguresTab,False); SetPageVisible(EquationTab,False);
  SetPageVisible(TheoremsTab,False); SetPageVisible(CommandsTab,False);
  SetPageVisible(ColorBoxesTab,False); SetPageVisible(ListingsTab,False);
  FormatMenu.Caption:='F&ormat';
  for I:=InsertMenu.Count-1 downto 0 do if InsertMenu.Items[I].Hint='@theoremtitle' then InsertMenu.Items[I].Free;
  BuildMenu;
  { Replace old quick bar controls, retaining the three existing actions. }
  for I:=0 to QuickAccessBar.ControlCount-1 do QuickAccessBar.Controls[I].Visible:=False;
  QuickUndoButton.Caption:=''; QuickRedoButton.Caption:=''; QuickSaveButton.Caption:='';
  QuickUndoButton.Hint:='Undo'; QuickRedoButton.Hint:='Redo'; QuickSaveButton.Hint:='Save';
  QuickUndoList:=TSpeedButton.Create(Self); QuickUndoList.Parent:=QuickAccessBar;
  QuickUndoList.Name:='QuickUndoHistory'; QuickUndoList.Hint:='Undo history'; QuickUndoList.OnClick:=@HistoryClick; QuickUndoList.Tag:=0;
  QuickRedoList:=TSpeedButton.Create(Self); QuickRedoList.Parent:=QuickAccessBar;
  QuickRedoList.Name:='QuickRedoHistory'; QuickRedoList.Hint:='Redo history'; QuickRedoList.OnClick:=@HistoryClick; QuickRedoList.Tag:=1;
  for J:=0 to 3 do begin
    B:=TSpeedButton.Create(Self); B.Parent:=QuickAccessBar; B.Name:='QuickExtra'+IntToStr(J);
    case J of
      0:begin B.Hint:='New'; B.OnClick:=@NewClick; end;
      1:begin B.Hint:='Open'; B.OnClick:=@OpenClick; end;
      2:begin B.Hint:='Refresh preview'; B.OnClick:=@PreviewClick; end;
      3:begin B.Hint:='Settings'; B.OnClick:=@PreferencesClick; end;
    end;
  end;
  B:=TSpeedButton.Create(Self); B.Parent:=QuickAccessBar; B.Name:='QuickCustomize';
  B.Hint:='Customize quick access toolbar'; B.Caption:='▾'; B.HelpKeyword:='literal';
  B.OnClick:=@ConfigureQuickAccess;
  FCommandSearchButton:=TSpeedButton.Create(Self); FCommandSearchButton.Parent:=QuickAccessBar;
  FCommandSearchButton.Name:='FindCommandButton'; FCommandSearchButton.Caption:='Find a command…';
  FCommandSearchButton.HelpKeyword:='literal'; FCommandSearchButton.Hint:='Find a command (Alt+Q)';
  FCommandSearchButton.ShowHint:=True; FCommandSearchButton.OnClick:=@FindCommandClick; FCommandSearchButton.Flat:=True;
  Ini:=TIniFile.Create(GetAppConfigFile(False));
  try
    QuickUndoButton.Visible:=Ini.ReadBool('QuickAccess','Undo',True);
    QuickRedoButton.Visible:=Ini.ReadBool('QuickAccess','Redo',True);
    QuickSaveButton.Visible:=Ini.ReadBool('QuickAccess','Save',True);
    for J:=0 to 3 do TControl(FindComponent('QuickExtra'+IntToStr(J))).Visible:=Ini.ReadBool('QuickAccess','Extra'+IntToStr(J),J=1);
    FQuickOrder:=TStringList.Create;
    if Ini.ValueExists('QuickAccess','Order') then FQuickOrder.CommaText:=Ini.ReadString('QuickAccess','Order','')
    else for J:=0 to 6 do if QuickActionControl(J).Visible then FQuickOrder.Add(IntToStr(J));
    for J:=0 to FQuickOrder.Count-1 do
    begin
      FQuickOrder[J]:=StringReplace(FQuickOrder[J],'ribbon:Color box/','ribbon:Box/',[]);
      FQuickOrder[J]:=StringReplace(FQuickOrder[J],'ribbon:Home/Edit command and arguments…','ribbon:Home/Properties…',[]);
    end;
    FRibbonFullHeight:=Ribbon.Height; FRibbonCollapsed:=Ini.ReadBool('View','CollapsedRibbon',False);
    UpdateRibbonVisibility;
    SetMenuChecked(TMenuItem(FindComponent('CollapseRibbonMenu')),FRibbonCollapsed);
  finally Ini.Free; end;
  BuildQuickCatalog; LayoutQuickAccess;
  StatusZoomLabel.Cursor:=crHandPoint; StatusZoomLabel.Hint:='Preview scale and fitting options'; StatusZoomLabel.ShowHint:=True; StatusZoomLabel.OnClick:=@StatusZoomClick;
  { Source tools stay next to the source editor, including an automatic-height reset. }
  B:=TSpeedButton.Create(Self); B.Parent:=SourceTools; B.SetBounds(42,2,108,28);
  B.Name:='SourceFitContent'; B.Caption:='Fit content'; B.HelpKeyword:='literal'; B.Hint:='Restore automatic source editor height';
  B.Tag:=-1; B.OnClick:=@RibbonAction;
  Ribbon.ActivePage:=HomeTab;
  finally FUpdatingRibbon:=False; end;
end;

procedure TMainForm.UpdateContextTabs(InEquation,InTable,InTheorem:Boolean; ActivateTab,InFigure:Boolean);
var NewEquation,NewTable,NewFigure,NewTheorem,NewDefinition,InDefinition,ChangedTabs:Boolean;
    InColorBox,InListing,NewColorBox,NewListing:Boolean;
begin
  if TablesTab=nil then Exit;
  RetainTabPages(Ribbon);
  NewEquation:=InEquation and not EquationTab.TabVisible;
  NewTable:=InTable and not TablesTab.TabVisible;
  NewFigure:=InFigure and not FiguresTab.TabVisible;
  NewTheorem:=InTheorem and not TheoremsTab.TabVisible;
  InDefinition:=((BodyEditing and not FPreambleEditing) or FPreambleEditing) and CurrentVisualEditor.EditingDefinition;
  NewDefinition:=InDefinition and not CommandsTab.TabVisible;
  InColorBox:=BodyEditing and not FPreambleEditing and (FormulaEditor.CurrentBoxSource<>'');
  InListing:=BodyEditing and not FPreambleEditing and (FormulaEditor.CurrentEnvironmentSource('lstlisting')<>'');
  NewColorBox:=InColorBox and not ColorBoxesTab.TabVisible; NewListing:=InListing and not ListingsTab.TabVisible;
  ChangedTabs:=(InEquation<>EquationTab.TabVisible) or (InTable<>TablesTab.TabVisible) or (InFigure<>FiguresTab.TabVisible) or
    (InTheorem<>TheoremsTab.TabVisible) or (InDefinition<>CommandsTab.TabVisible) or
    (InColorBox<>ColorBoxesTab.TabVisible) or (InListing<>ListingsTab.TabVisible);
  if ((Ribbon.ActivePage=EquationTab) and not InEquation) or
     ((Ribbon.ActivePage=TablesTab) and not InTable) or
     ((Ribbon.ActivePage=FiguresTab) and not InFigure) or
     ((Ribbon.ActivePage=TheoremsTab) and not InTheorem) or
     ((Ribbon.ActivePage=CommandsTab) and not InDefinition) or
     ((Ribbon.ActivePage=ColorBoxesTab) and not InColorBox) or
     ((Ribbon.ActivePage=ListingsTab) and not InListing) then Ribbon.ActivePage:=HomeTab;
  SetPageVisible(EquationTab,InEquation); SetPageVisible(TablesTab,InTable); SetPageVisible(TheoremsTab,InTheorem);
  DuplicateMathRowButton.Enabled:=InEquation and CurrentVisualEditor.CanEditGrid(6);
  DuplicateMathColumnButton.Enabled:=InEquation and CurrentVisualEditor.CanEditGrid(7);
  SetPageVisible(FiguresTab,InFigure);
  FigureImageButton.Enabled:=InFigure; FigureDiagramButton.Enabled:=InFigure; FigureCaptionButton.Enabled:=InFigure;
  if InFigure and BodyEditing then begin
    FigureImageButton.Enabled:=FormulaEditor.CurrentFigureSource<>'';
    FigureDiagramButton.Enabled:=FormulaEditor.CurrentDiagramSource<>'';
    FigureCaptionButton.Enabled:=FormulaEditor.CurrentFloatSource<>'';
  end;
  SetPageVisible(CommandsTab,InDefinition); if InDefinition then RefreshDefinitionControls;
  SetPageVisible(ColorBoxesTab,InColorBox); SetPageVisible(ListingsTab,InListing);
  UpdateCommandAvailability(InEquation,InTable,InFigure,InTheorem);
  if ChangedTabs then RefreshTabTheme(Ribbon);
  if ActivateTab then begin
    if NewDefinition then Ribbon.ActivePage:=CommandsTab
    else if NewEquation then Ribbon.ActivePage:=EquationTab
    else if NewTable then Ribbon.ActivePage:=TablesTab
    else if NewFigure then Ribbon.ActivePage:=FiguresTab
    else if NewTheorem then Ribbon.ActivePage:=TheoremsTab
    else if NewColorBox then Ribbon.ActivePage:=ColorBoxesTab
    else if NewListing then Ribbon.ActivePage:=ListingsTab;
  end;
end;
procedure TMainForm.UpdateCommandAvailability(InEquation,InTable,InFigure,InTheorem:Boolean);
var Visual:TMathEditor; States:TTableActionStates; Command,Environment,Figure,Drawing,Float,BoxSource:string;
    I:Integer; C:TComponent; B:TCommandRibbonButton; M:TMenuItem; Editable,SourceMode:Boolean;
  function UsesAction(Event:TNotifyEvent):Boolean;
  begin Result:=TMethod(B.OnClick).Code=TMethod(Event).Code; end;
  function Available(const Code:string; Previous:Boolean):Boolean;
  var N:Integer; Name:string;
  begin
    Result:=Previous;
    if Copy(Code,1,7)='@table:' then begin
      N:=StrToIntDef(Copy(Code,8,MaxInt),-1); Result:=False;
      if (N>=0) and (N<=13) then Result:=InTable and (SourceMode or States[N]);
    end else if Copy(Code,1,8)='@border:' then begin
      N:=StrToIntDef(Copy(Code,9,MaxInt),-1); Result:=False;
      if (N>=0) and (N<=7) then Result:=InTable and (SourceMode or States[14+N]);
    end else if Copy(Code,1,6)='@grid:' then begin
      N:=StrToIntDef(Copy(Code,7,MaxInt),-1); Result:=InEquation and Visual.CanEditGrid(N);
    end else if Code='@properties' then Result:=Editable and ((Command<>'') or (Environment<>'') or InTable or InFigure or InTheorem)
    else if Code='@command' then Result:=Editable and (Command<>'')
    else if Code='@editref' then Result:=Editable and ((Command='ref') or (Command='eqref') or (Command='autoref') or
      (Command='pageref') or (Command='nameref') or (Pos('cite',Command)>0) or (Command='label') or (Command='tag'))
    else if Code='@theoremtitle' then Result:=InTheorem
    else if Code='@figureedit' then Result:=InFigure and (Figure<>'') and (Pos('\includepdf',Figure)<>1)
    else if Code='@pdfedit' then Result:=InFigure and (Pos('\includepdf',Figure)=1)
    else if Code='@diagramedit' then Result:=InFigure and (Drawing<>'')
    else if Code='@floatcaption' then Result:=InFigure and (Float<>'')
    else if (Code='@boxoptions') or (Code='@boxsource') then Result:=BoxSource<>''
    else if Code='@tablelines' then Result:=InTable
    else if Code='@environmentoptions' then Result:=Environment<>''
    else if Copy(Code,1,20)='@environmentoptions:' then begin
      Name:=Copy(Code,21,MaxInt); N:=Pos(':',Name); if N>0 then Name:=Copy(Name,1,N-1);
      Result:=Visual.CurrentEnvironmentSource(Name)<>'';
    end
    else if Code='@tag' then Result:=InEquation
    else if (Code='@tableinsert') or (Code='@figureinsert') or (Code='@diagraminsert') or (Code='@pdfinsert') or
      (Code='@appendix') or (Code='@environmentinsert') or (Copy(Code,1,12)='@bodyinsert:') or
      (Copy(Code,1,6)='@list:') or (Code='@theorem') then Result:=Editable and not InEquation;
  end;
begin
  Visual:=CurrentVisualEditor; if Visual=nil then Exit;
  SourceMode:=Editor.Visible; Editable:=not PluginSourceActive and (not Document.PreambleOnly or FPreambleEditing);
  Command:=Visual.CurrentCommandName; Environment:=Visual.CurrentEnvironmentName;
  if SourceMode then begin
    I:=LastDelimiter('\',FSourceCommandPath); Command:='';
    if I>0 then Command:=ReadTeXCommand(FSourceCommandPath,I);
  end;
  Figure:=''; Drawing:=''; Float:=''; BoxSource:=''; FillChar(States,SizeOf(States),0);
  if InTable and not SourceMode then Visual.GetTableActions(States);
  if InFigure then begin Figure:=Visual.CurrentFigureSource; Drawing:=Visual.CurrentDiagramSource; Float:=Visual.CurrentFloatSource; end;
  BoxSource:=Visual.CurrentBoxSource;
  for I:=0 to ComponentCount-1 do begin
    C:=Components[I];
    if C is TMenuItem then begin M:=TMenuItem(C); if M.Hint<>'' then M.Enabled:=Available(M.Hint,M.Enabled); end;
  end;
  for I:=0 to ComponentCount-1 do if Components[I] is TCommandRibbonButton then begin
    B:=TCommandRibbonButton(Components[I]);
    if B.MenuCommand<>nil then B.Enabled:=B.MenuCommand.Enabled
    else if UsesAction(@FootnoteClick) or UsesAction(@ImportDataClick) then
      B.Enabled:=Editable and not InEquation and not FPreambleEditing
    else if UsesAction(@DefineCommandClick) or UsesAction(@RenewCommandClick) or UsesAction(@DeclareOperatorClick) then
      B.Enabled:=Editable
    else if UsesAction(@SelectionSourceClick) then B.Enabled:=Editable and not FPreambleEditing;
  end;
  SyncQuickAccess;
end;
procedure TMainForm.RefreshDefinitionControls;
var D:TCommandDefinition;
begin
  ReadCommandDefinition(CurrentVisualEditor.CurrentDefinitionSource,D);
  DefinitionSourceButton.Down:=CurrentVisualEditor.DefinitionSourceEditing;
  FUpdatingDefinition:=True;
  try
    DefinitionKind.ItemIndex:=-1;
    case D.Command of
      'newcommand','NewDocumentCommand':DefinitionKind.ItemIndex:=0;
      'renewcommand','RenewDocumentCommand':DefinitionKind.ItemIndex:=1;
      'providecommand','ProvideDocumentCommand':DefinitionKind.ItemIndex:=2;
      'DeclareDocumentCommand':DefinitionKind.ItemIndex:=3;
      'DeclareRobustCommand':DefinitionKind.ItemIndex:=4;
      'DeclareMathOperator':DefinitionKind.ItemIndex:=5+Ord(D.Starred);
      'def','gdef','edef','xdef':DefinitionKind.ItemIndex:=7;
    end;
  finally FUpdatingDefinition:=False; end;
end;
procedure TMainForm.DefinitionKindChanged(Sender:TObject);
const Kinds:array[0..7] of string=('newcommand','renewcommand','providecommand','DeclareDocumentCommand',
  'DeclareRobustCommand','DeclareMathOperator','DeclareMathOperator*','def');
var Source,Replacement:string;
begin
  if FUpdatingDefinition or (DefinitionKind.ItemIndex<0) then Exit;
  if (DefinitionKind.ItemIndex in [5,6]) and not FPreambleEditing then begin
    StatusText:='Declare math operators in the preamble using Insert, Commands.'; RefreshDefinitionControls; Exit;
  end;
  Source:=CurrentVisualEditor.CurrentDefinitionSource;
  Replacement:=DefinitionChangeKind(Source,Kinds[DefinitionKind.ItemIndex]);
  if Replacement<>Source then CurrentVisualEditor.ReplaceDefinition(Replacement);
  if (Replacement=Source) and (DefinitionKind.ItemIndex in [5,6,7]) then
    StatusText:='This definition form cannot preserve the current arguments.';
  RefreshDefinitionControls;
end;
procedure TMainForm.DefinitionAction(Sender:TObject);
var D:TDefinitionForm;
begin
  if not CurrentVisualEditor.EditingDefinition then Exit;
  case TComponent(Sender).Tag of
    0:CurrentVisualEditor.EditDefinitionArguments(False);
    1:CurrentVisualEditor.EditDefinitionArguments(True);
    3:begin
      D:=TDefinitionForm.Create(Self);
      try D.BodyEditor.Font.Assign(Editor.Font); D.LoadSource(CurrentVisualEditor.CurrentDefinitionSource); if D.ShowModal=mrOK then CurrentVisualEditor.ReplaceDefinition(D.Source);
      finally D.Free; end;
    end;
    4:CurrentVisualEditor.ToggleDefinitionSource;
  end;
  RefreshDefinitionControls;
end;

procedure TMainForm.RibbonDropDown(Sender:TObject);
var B:TSpeedButton; P:TPoint;
begin B:=TSpeedButton(Sender); P:=B.ClientToScreen(Point(0,B.Height)); B.PopupMenu.PopUp(P.X,P.Y); end;
procedure TMainForm.RibbonChoiceMenu(Sender:TObject);
var C:TComboBox;
begin
  C:=TComboBox(Pointer(TMenuItem(Sender).Parent.Tag)); C.ItemIndex:=TMenuItem(Sender).Tag;
  RibbonChoice(C);
end;
procedure TMainForm.RibbonAction(Sender:TObject);
begin
  if TComponent(Sender).Tag=-1 then begin FSourceHeight:=0; LayoutCards(nil); Exit; end;
  TMenuItem(Pointer(TComponent(Sender).Tag)).Click;
end;

procedure TMainForm.RefreshParagraphStyles(Sender:TObject);
var C:TComboBox; Names,Headings:TStringList; I:Integer; ChoiceMenu,Item:TMenuItem; PreviousChoice,Entry,Title:string;
  procedure Add(const Title,Command:string);
  begin
    Item:=TMenuItem.Create(Self); Item.Caption:=Title; Item.Hint:=Command; Item.Tag:=C.Items.Count;
    Item.OnClick:=@RibbonChoiceMenu; ChoiceMenu.Add(Item); C.Items.AddObject(Title,Item);
  end;
begin
  C:=TComboBox(FindComponent('ParagraphStyles'));
  if (C=nil) or (FormulaEditor=nil) then Exit;
  ChoiceMenu:=nil;
  for I:=0 to ComponentCount-1 do
    if (Components[I] is TMenuItem) and (TMenuItem(Components[I]).Tag=PtrInt(C)) then begin ChoiceMenu:=TMenuItem(Components[I]); Break; end;
  if ChoiceMenu=nil then Exit;
  Names:=TStringList.Create; Headings:=TStringList.Create; FUpdatingRibbon:=True;
  try
    PreviousChoice:=C.Text;
    if (FPagedView=nil) and (ActiveBlock<0) and (FSessions<>nil) then begin FormulaEditor.SetContext(FEffectivePreamble,DocumentDirectory,Engine.Text,'',False);
      FormulaEditor.SetDocumentContext(Document.Blocks,-1,TOpenDocument(FSessions[FSessionIndex]).PreviewContext); end;
    FormulaEditor.TheoremNames(Names); FormulaEditor.HeadingNames(Headings);
    if (Pos('amsthm',Document.Preamble)>0) and (Names.IndexOf('proof')<0) then Names.Add('proof');
    C.Items.Clear; ChoiceMenu.Clear; Add('Normal','@heading:');
    for Entry in Headings do begin
      Title:=Entry; Title[1]:=UpCase(Title[1]);
      Add(Title,'@heading:\'+Entry); Add(Title+' (unnumbered)','@heading:\'+Entry+'*');
    end;
    for Entry in Names do Add(Entry,'@theorem:'+Entry);
    C.ItemIndex:=Max(0,C.Items.IndexOf(PreviousChoice));
  finally FUpdatingRibbon:=False; Headings.Free; Names.Free; end;
  UpdateParagraphControl(FormulaEditor.CurrentParagraphStyle);
end;

procedure TMainForm.RibbonChoice(Sender:TObject);
const Sizes:array[0..9] of string=('tiny','scriptsize','footnotesize','small','normalsize','large','Large','LARGE','huge','Huge');
      Families:array[0..2] of string=('\textrm','\textsf','\texttt');
var C:TComboBox; D:TSettingsForm; Value,Baseline,Command:string; SavedScroll,Index,Anchor,Focus:Integer; WasSource:Boolean;
begin
  if FUpdatingRibbon or FApplyingSettings or FLoading then Exit;
  C:=TComboBox(Sender);
  if C.Tag=5 then begin
    if C.Text='Fit Width' then SetFitWidth else if C.Text='Fit Page' then SetFitPage
    else SetPreviewPercent(StrToIntDef(StringReplace(C.Text,'%','',[]),100));
    Exit;
  end;
  if C.Tag=4 then begin
    D:=TSettingsForm.Create(Self);
    try
      D.Appearance.ItemIndex:=Ord(AppearanceMode); D.SourceWrap.Checked:=SourceWrapMenuItem.Checked;
      D.SourceSize.Value:=Editor.Font.Size; D.SourceFont.Text:=FSourceFontPreference;
      D.RealtimeCompile.Checked:=FRealtimeCompile;
      D.DefaultEngine.ItemIndex:=D.DefaultEngine.Items.IndexOf(Engine.Text);
      SelectZoom(D.PreviewScale,FPreviewPercent);
      D.Appearance.ItemIndex:=C.ItemIndex;
      ApplySettings(D);
    finally D.Free; end;
    Exit;
  end;
  if DeferInput(@RibbonChoice,Sender) then Exit;
  if C.ItemIndex<0 then Exit;
  Index:=C.ItemIndex; Command:='';
  if (C.Tag=3) and (C.Items.Objects[Index]<>nil) then Command:=TMenuItem(C.Items.Objects[Index]).Hint;
  WasSource:=Editor.Visible;
  if WasSource then begin
    Anchor:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockBegin]);
    Focus:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockEnd]);
  end;
  if not BodyEditing then begin
    EquationModeClick(nil);
    if WasSource then FormulaEditor.SetSourceSelection(Anchor,Focus);
  end;
  case C.Tag of
    1:FormulaEditor.SetTextFamily(Families[Index]);
    2:if Index<Length(Sizes) then FormulaEditor.SetTextSize('{\'+Sizes[Index]+' ')
      else begin
        if ChooseTextSize(Self,Value,Baseline) then
          FormulaEditor.SetTextSize('{\fontsize{'+Value+'}{'+Baseline+'}\selectfont ');
      end;
    3:begin
      if Command='' then Exit;
      SavedScroll:=Scroll.VertScrollBar.Position;
      try
        if Copy(Command,1,9)='@heading:' then FormulaEditor.SetHeading(Copy(Command,10,MaxInt))
        else FormulaEditor.SetTheoremEnvironment(Copy(Command,10,MaxInt));
      finally SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,SavedScroll); end;
    end;
  end;
  RefreshFontControls;
  { A style choice is an editing action. In particular an empty heading
    must receive typing rather than leaving focus in this combo box. }
  if BodyEditing and FormulaEditor.CanFocus then begin
    FormulaEditor.SetFocus;
    Application.QueueAsyncCall(@RestoreRibbonEditFocus,PtrInt(C));
  end;
end;
procedure TMainForm.RestoreRibbonEditFocus(Data:PtrInt);
begin
  if (csDestroying in ComponentState) or not Active or not BodyEditing then Exit;
  if (ActiveControl<>TWinControl(Data)) and (ActiveControl<>FormulaEditor) then Exit;
  if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
end;

function TMainForm.QuickActionControl(ID:Integer):TControl;
begin
  case ID of
    0:Result:=QuickSaveButton; 1:Result:=QuickUndoButton; 2:Result:=QuickRedoButton;
    3..6:Result:=TControl(FindComponent('QuickExtra'+IntToStr(ID-3)));
    else Result:=nil;
  end;
end;
{$I mainformquickaccess.inc}
procedure TMainForm.LayoutQuickAccess;
var X,I,ID,Needed,Available:Integer; C:TControl; Item:TMenuItem;
  procedure Place(B:TControl; Width:Integer);
  begin if B.Visible then begin B.SetBounds(X,3,Width,30); Inc(X,Width+2); end; end;
begin
  X:=6;
  Available:=QuickAccessBar.ClientWidth;
  if FCommandSearchButton<>nil then Dec(Available,180);
  for I:=0 to QuickAccessBar.ControlCount-1 do QuickAccessBar.Controls[I].Visible:=False;
  FQuickMenu.Items.Clear;
  for I:=0 to FQuickOrder.Count-1 do begin
    ID:=StrToIntDef(FQuickOrder[I],-1); C:=QuickControl(FQuickOrder[I]); if (C=nil) or C.Visible then Continue;
    Needed:=34; if (ID=1) or (ID=2) then Inc(Needed,18);
    if X+Needed+52>Available then begin
      C.SetBounds(Max(0,Available-60),3,32,30);
      Item:=TMenuItem.Create(Self); Item.Caption:=C.Hint; Item.Hint:=FQuickOrder[I]; Item.Enabled:=C.Enabled;
      Item.OnClick:=@QuickOverflowClick; FQuickMenu.Items.Add(Item); Continue;
    end;
    C.Visible:=True; Place(C,32);
    if ID=1 then begin QuickUndoList.Visible:=True; Place(QuickUndoList,16); end;
    if ID=2 then begin QuickRedoList.Visible:=True; Place(QuickRedoList,16); end;
  end;
  FQuickOverflow.Visible:=FQuickMenu.Items.Count>0; Place(FQuickOverflow,24);
  TControl(FindComponent('QuickCustomize')).Visible:=True; Place(TControl(FindComponent('QuickCustomize')),24);
  if FCommandSearchButton<>nil then begin
    FCommandSearchButton.SetBounds(Max(0,Available),3,174,30); FCommandSearchButton.Visible:=True;
  end;
  RefreshRibbonIcons(QuickAccessBar);
end;

procedure TMainForm.ConfigureQuickAccess(Sender:TObject);
var D:TQuickAccessForm; Ini:TIniFile; I:Integer;
begin
  D:=TQuickAccessForm.Create(Self);
  try
    for I:=0 to FQuickCatalog.Count-1 do D.AddCommand(FQuickCatalog[I],Copy(FQuickCatalog[I],8,MaxInt));
    D.LoadOrder(FQuickOrder); if D.ShowModal<>mrOK then Exit; D.GetOrder(FQuickOrder);
    ForceDirectories(ExtractFileDir(GetAppConfigFile(False))); Ini:=TIniFile.Create(GetAppConfigFile(False));
    try
      Ini.WriteString('QuickAccess','Order',FQuickOrder.CommaText);
    finally Ini.Free; end;
    LayoutQuickAccess;
  finally D.Free; end;
end;
procedure TMainForm.SourceGripDown(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
begin
  if Button<>mbLeft then Exit;
  FSourceDragY:=Mouse.CursorPos.Y; FSourceDragHeight:=Editor.Height;
  SetCaptureControl(SourceGrip);
end;
procedure TMainForm.SourceGripMove(Sender:TObject; Shift:TShiftState; X,Y:Integer);
begin
  if GetCaptureControl<>SourceGrip then Exit;
  FSourceHeight:=Max(Editor.LineHeight*3+12,FSourceDragHeight+Mouse.CursorPos.Y-FSourceDragY);
  LayoutCards(nil);
end;
procedure TMainForm.SourceGripUp(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
begin SetCaptureControl(nil); end;
