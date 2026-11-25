{ SPDX-License-Identifier: GPL-3.0-or-later }
function ShortHistory(const S:string):string;
var I,N,Words:Integer; Space:Boolean; C:Char;
begin
  Result:=''; Words:=0; Space:=True; I:=1;
  while I<=Length(S) do begin
    C:=S[I]; N:=1;
    while (I+N<=Length(S)) and ((Byte(S[I+N]) and $C0)=$80) do Inc(N);
    if C in [' ',#9,#10,#13,'{','}','\','$'] then begin
      if not Space then begin Inc(Words); if Words>=4 then Break; Result:=Result+' '; end; Space:=True;
    end else begin Result:=Result+Copy(S,I,N); Space:=False; end;
    Inc(I,N);
    if UTF8Length(Result)>=28 then Break;
  end;
  Result:=Trim(Result);
end;
function DescribeChange(const Before,After:string):string;
var A,B,C:Integer; Added,Removed:string;
begin
  SourceDifference(Before,After,A,B,C); Inc(A);
  Added:=ShortHistory(Copy(After,A,C-A+1)); Removed:=ShortHistory(Copy(Before,A,B-A+1));
  if (Added='') and (Removed='') then Exit('Change spacing');
  if B<A then Result:='Insert '+Added else if C<A then Result:='Delete '+Removed else Result:='Replace '+Added;
end;
procedure TMainForm.SetupTools;
const Titles:array[0..7] of string=('Symbols','Structures','Math fonts','Accents','Environments','Layout','References','Commands');
var I,J:Integer; M,Group,ReferencesMenu:TMenuItem; RefTab:TTabSheet; Ini:TIniFile;
  procedure Add(Category:Integer; const Caption,Code:string);
  var A,C:TMenuItem;
  begin
    A:=TMenuItem.Create(Self); A.Caption:=Caption; A.Hint:=Code;
    A.OnClick:=@ToolCommandClick; ToolPopups[Category].Items.Add(A);
    C:=TMenuItem.Create(Self); C.Caption:=Caption; C.Hint:=Code;
    C.OnClick:=@ToolCommandClick; Group.Items[Category].Add(C);
  end;
  procedure Words(Category:Integer; const List:string);
  var L:TStringList; K:Integer; V:string;
  begin
    L:=TStringList.Create;
    try L.Delimiter:=' '; L.StrictDelimiter:=True; L.DelimitedText:=List;
      for K:=0 to L.Count-1 do begin V:=L[K]; Add(Category,V,'\'+V); end;
    finally L.Free; end;
  end;
begin
  { Contextual Equation ribbon: one compact row of categorized tools. }
  for I:=0 to EquationTab.ControlCount-1 do EquationTab.Controls[I].Visible:=False;
  Group:=TMenuItem.Create(Self); Group.Caption:='Equation tools'; InsertMenu.Add(Group);
  RefTab:=TTabSheet.Create(Self); RefTab.PageControl:=Ribbon; RefTab.Caption:='References';
  for I:=0 to 7 do
  begin
    ToolPopups[I]:=TPopupMenu.Create(Self);
    M:=TMenuItem.Create(Self); M.Caption:=Titles[I]; Group.Add(M);
    if I=6 then Continue;
  end;
  Words(0,'alpha beta gamma delta epsilon varepsilon zeta eta theta vartheta iota kappa lambda mu nu xi pi varpi rho varrho sigma varsigma tau upsilon phi varphi chi psi omega');
  Words(0,'Gamma Delta Theta Lambda Xi Pi Sigma Upsilon Phi Psi Omega');
  Words(0,'pm mp times div cdot cap cup setminus in notin subset subseteq supset supseteq leq geq neq approx sim equiv to mapsto leftarrow Rightarrow Leftrightarrow infty nabla partial forall exists emptyset');
  Words(0,'sin cos tan cot sec csc sinh cosh tanh arcsin arccos arctan log ln exp lim min max sup inf det gcd');
  Add(0,'+','+'); Add(0,'−','-'); Add(0,'=','='); Words(0,'sum prod int iint oint colon lVert rVert');
  Add(1,'Thin space','\,'); Add(1,'Medium space','\:'); Add(1,'Thick space','\;');
  Add(1,'Quad space','\quad'); Add(1,'Double quad space','\qquad');
  Add(1,'Fraction','\frac'); Add(1,'Square root','\sqrt');
  Add(1,'Superscript','^{}'); Add(1,'Subscript','_{}');
  Add(1,'Matrix…','@matrix'); Add(1,'Paired delimiters…','@delimiters');
  for J:=0 to High(GridLabels) do begin M:=TMenuItem.Create(Self); M.Caption:=GridLabels[J]; M.Tag:=300+J; M.OnClick:=@EquationActionClick; ToolPopups[1].Items.Add(M);
    M:=TMenuItem.Create(Self); M.Caption:=GridLabels[J]; M.Tag:=300+J; M.OnClick:=@EquationActionClick; Group.Items[1].Add(M); end;
  Words(2,'mathrm mathit mathbf mathsf mathtt mathcal mathscr mathbb mathfrak');
  Words(3,'hat widehat reallywidehat bar overline underline vec dot ddot tilde widetilde breve check acute grave overbrace underbrace');
  Add(4,'align','@env:align'); Add(4,'align*','@env:align*'); Add(4,'aligned','@env:aligned');
  Add(4,'gather','@env:gather'); Add(4,'gather*','@env:gather*'); Add(4,'cases','@env:cases');
  Add(4,'gathered','@env:gathered'); Add(4,'eqnarray','@env:eqnarray');
  Add(4,'equation','@env:equation'); Add(4,'equation*','@env:equation*');
  Add(5,'Inline','@inline'); Add(5,'Displayed','@display');
  Add(6,'Label…','@label'); Add(6,'Equation tag…','@tag');
  Add(6,'Reference…','@ref'); Add(6,'Equation reference…','@eqref'); Add(6,'Named reference…','@autoref');
  Add(6,'Edit label or reference…','@editref');
  Add(6,'Bibliography…','@bibliography');
  Add(7,'Edit command name…','@rename'); Add(7,'Custom command…','@custom');
  ReferencesMenu:=Group.Items[6]; Group.Remove(ReferencesMenu); AppMenu.Items.Add(ReferencesMenu);
  ToolPopups[7].Items[0].ShortCut:=ShortCut(VK_F2,[]);
  Group.Items[6].Items[0].ShortCut:=ShortCut(VK_F2,[]);
  M:=TMenuItem.Create(Self); M.Caption:='Bulleted list'; M.Hint:='@list:itemize'; M.OnClick:=@ToolCommandClick; InsertMenu.Add(M);
  M:=TMenuItem.Create(Self); M.Caption:='Numbered list'; M.Hint:='@list:enumerate'; M.OnClick:=@ToolCommandClick; InsertMenu.Add(M);
  M:=TMenuItem.Create(Self); M.Caption:='Theorem environment…'; M.Hint:='@theorem'; M.OnClick:=@ToolCommandClick; InsertMenu.Add(M);
  M:=TMenuItem.Create(Self); M.Caption:='Edit theorem title…'; M.Hint:='@theoremtitle'; M.OnClick:=@ToolCommandClick; InsertMenu.Add(M);
  { Keep existing document-specific field, macro and template menus available. }
  HomeFileGroup.Visible:=False;
  HomeEditingGroup.Left:=6; HomeEditingGroup.Caption:='Clipboard and history';
  HomeTextGroup.Left:=HomeEditingGroup.Left+HomeEditingGroup.Width+6; HomeTextGroup.Caption:='Font and paragraph';
  HomeModeGroup.Left:=HomeTextGroup.Left+HomeTextGroup.Width+6;
  FormatMenu.Caption:='F&ormat'; NavigateMenu.Caption:='E&quation';
  HistoryPopup:=TPopupMenu.Create(Self);
  M:=TMenuItem.Create(Self); M.Caption:='Options…'; M.OnClick:=@PreferencesClick; FileMenu.Insert(FileMenu.Count-1,M);
  M:=TMenuItem.Create(Self); M.Caption:='Appearance and settings…'; M.OnClick:=@PreferencesClick; ViewMenu.Add(M);
  Group:=TMenuItem.Create(Self); Group.Caption:='&Help'; AppMenu.Items.Add(Group);
  M:=TMenuItem.Create(Self); M.Caption:='About PasTeX…'; M.OnClick:=@AboutClick; Group.Add(M);
  M:=TMenuItem.Create(Self); M.Caption:='Check environment and dependencies…'; M.OnClick:=@EnvironmentCheckClick; Group.Insert(0,M);
  M:=TMenuItem.Create(Self); M.Caption:='User guide and reference'; M.Hint:='user-guide.tex'; M.OnClick:=@GuideClick; Group.Insert(0,M);
  Ini:=TIniFile.Create(GetAppConfigFile(False));
  try
    SetAppearance(TAppearanceMode(EnsureRange(Ini.ReadInteger('Appearance','Mode',IfThen(Ini.ValueExists('Appearance','Dark'),Ord(Ini.ReadBool('Appearance','Dark',False)),2)),0,2)));
    ReadSourceHighlight(Ini);
    Editor.Font.Size:=EnsureRange(Ini.ReadInteger('Editor','FontSize',12),8,36);
    Editor.Font.Name:=NormalizeSourceFont(Ini.ReadString('Editor','FontName',DefaultSourceFont));
    FSourceFontPreference:=Editor.Font.Name;
    FPreviewPercent:=EnsureRange(Ini.ReadInteger('Appearance','PreviewScale',100),50,200);
    FFitWidth:=Ini.ReadBool('Appearance','FitWidth',False);
    FRealtimeCompile:=Ini.ReadBool('Preview','RealtimeCompile',True);
    SetDiagramPreviewEnabled(Ini.ReadBool('Preview','TeXDiagrams',True));
    SetDiagramBackend(TDiagramBackend(EnsureRange(Ini.ReadInteger('Preview','DiagramBackend',0),0,1)));
    FormulaEditor.PreviewZoom:=FPreviewPercent/100;
    I:=Engine.Items.IndexOf(Ini.ReadString('Compiler','Engine',Engine.Text)); if I>=0 then Engine.ItemIndex:=I;
    if Ini.ReadBool('Editor','WordWrap',True)<>SourceWrapMenuItem.Checked then SourceWrapClick(nil);
  finally Ini.Free; end;
  CheckPreviewTools; BuildRibbon;

  ApplyAppearance; QueuePreview;
end;

procedure TMainForm.ReferenceToolClick(Sender:TObject);
begin ToolPopups[6].Items[TComponent(Sender).Tag].Click; end;

procedure TMainForm.ToolPopupClick(Sender:TObject);
var P:TPoint; B:TSpeedButton;
begin B:=TSpeedButton(Sender); P:=B.ClientToScreen(Point(0,B.Height)); ToolPopups[B.Tag].PopUp(P.X,P.Y); end;

procedure TMainForm.ToolCommandClick(Sender:TObject);
var Code,Value,S,L,R,SymbolPackage:string; Chosen:Boolean; D:TForm; Kind,LeftD,RightD:TComboBox;
    B:TButton; Lab:TLabel; I,J,SourceAnchor,SourceFocus:Integer; WasSource:Boolean;
    Matrix:TMatrixDialog; Commands:TStringList; ColorDialog:TColorDialog; Bibliography:TBibliographyForm;
  procedure PrepareMathCommand(const Text:string; const RequiredPackage:string='');
  var P,At:Integer; Name,PackageName,Header,Packages:string; Model:TPreambleModel; Names:TStringList;
  begin
    P:=1; Name:=ReadTeXCommand(Text,P); Packages:=RequiredPackage; if Packages='' then Packages:=MathCommandPackages(Name); if Packages='' then Exit;
    Model:=TPreambleModel.Create; Names:=TStringList.Create;
    try
      Names.CaseSensitive:=True; FormulaEditor.MacroNames(Names);
      if (RequiredPackage='') and (Names.IndexOf('\'+Name)>=0) then Exit;
      Model.Load(Document.Preamble); Names.CommaText:=Packages;
      for PackageName in Names do if Model.PackageIndex(PackageName)<0 then Model.SetPackage(PackageName,'');
      Header:=Model.Source;
      if Name='reallywidehat' then begin
        FormulaEditor.MacroNames(Names);
        if Names.IndexOf('\reallywidehat')<0 then begin
          At:=Pos('\begin{document}',Header); if At=0 then At:=Length(Header)+1;
          Insert(ReallyWideHatDefinition,Header,At);
        end;
      end;
      if Header<>Document.Preamble then begin
        RecordVisualEdit; Document.Preamble:=Header; Modified:=True;
        FormulaEditor.SetContext(Header,DocumentDirectory,Engine.Text,'',False);
      end;
    finally Names.Free; Model.Free; end;
  end;
  procedure LabelAt(const Caption:string; Y:Integer);
  begin Lab:=TLabel.Create(D); Lab.Parent:=D; Lab.Caption:=Caption; Lab.SetBounds(12,Y,125,24); end;
  function Choice(Y:Integer; const Choices:string):TComboBox;
  begin Result:=TComboBox.Create(D); Result.Parent:=D; Result.SetBounds(150,Y,170,28);
    Result.Style:=csDropDownList; Result.Items.Delimiter:=';'; Result.Items.StrictDelimiter:=True;
    Result.Items.DelimitedText:=Choices; Result.ItemIndex:=0; end;
  procedure Dialog;
  begin D:=TForm.CreateNew(Self); D.Caption:='Formula options'; D.Position:=poMainFormCenter; D.BorderStyle:=bsDialog;
    D.ClientWidth:=340; D.ClientHeight:=190;
    B:=TButton.Create(D); B.Parent:=D; B.SetBounds(160,145,78,30); B.Caption:='Insert'; B.Default:=True; B.ModalResult:=mrOK;
    B:=TButton.Create(D); B.Parent:=D; B.SetBounds(245,145,78,30); B.Caption:='Cancel'; B.Cancel:=True; B.ModalResult:=mrCancel;
  end;
begin
  if DeferInput(@ToolCommandClick,Sender) then Exit;
  if FPreambleEditing and (Sender is TMenuItem) and
    ((TMenuItem(Sender).Hint='@properties') or (TMenuItem(Sender).Hint='@command')) then begin PropertiesClick(Sender); Exit; end;
  if (Sender is TMenuItem) and (TMenuItem(Sender).Hint='@formulasource') then begin
    FormulaEditor.FormulaSourceMode:=not FormulaEditor.FormulaSourceMode;
    FormulaSourceButton.Down:=FormulaEditor.FormulaSourceMode; Exit;
  end;
  if (Sender is TMenuItem) and ((TMenuItem(Sender).Hint='@clearformat') or (TMenuItem(Sender).Hint='@comment')) then begin FormattingAction(Sender); Exit; end;
  WasSource:=Editor.Visible; SourceAnchor:=0; SourceFocus:=0;
  if WasSource then begin
    SourceAnchor:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockBegin]);
    SourceFocus:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockEnd]);
    if Editor.LogicalCaretXY=Editor.BlockBegin then begin I:=SourceAnchor; SourceAnchor:=SourceFocus; SourceFocus:=I; end;
  end;
  if not BodyEditing then EquationModeClick(nil);
  if not BodyEditing then Exit;
  if WasSource then FormulaEditor.SetSourceSelection(SourceAnchor,SourceFocus);
  if Sender is TMenuItem then Code:=TMenuItem(Sender).Hint
  else if TComponent(Sender).Tag=8 then Code:='@theorem' else Code:='@theoremtitle';
  if ObjectTool(Code) then begin if FormulaEditor.CanFocus then FormulaEditor.SetFocus; Exit; end;
  if (Code<>'') and (Code[1]<>'@') and not FormulaEditor.MathActive then FormulaEditor.SetFormulaKind('inline',False);
  if ((Code='@delimiters') or (Code='@matrix')) and not FormulaEditor.MathActive then FormulaEditor.SetFormulaKind('inline',False);
  PrepareMathCommand(Code);
  if Copy(Code,1,6)='@grid:' then FormulaEditor.EditGrid(StrToIntDef(Copy(Code,7,MaxInt),-1))
  else if Copy(Code,1,11)='@textstyle:' then FormulaEditor.FormatText(Copy(Code,12,MaxInt))
  else if (Code='@symbols') or (Code='@arrows') or (Code='@functions') then begin
    Commands:=TStringList.Create;
    try
      if Code='@arrows' then TeXArrowNames(Commands)
      else if Code='@functions' then MathCommandNames(CommonMathFunctions,Commands)
      else for I:=0 to ToolPopups[0].Items.Count-1 do Commands.Add(ToolPopups[0].Items[I].Hint);
      SymbolPackage:='';
      if Code='@symbols' then Chosen:=ChooseInstalledSymbol(Self,Commands,Value,SymbolPackage)
      else Chosen:=ChooseSymbol(Self,Commands,Value,Code='@arrows');
      if Chosen then begin
        if not FormulaEditor.MathActive then FormulaEditor.SetFormulaKind('inline',False);
        PrepareMathCommand(Value,SymbolPackage);
        FormulaEditor.InsertCommand(Value);
      end;
    finally Commands.Free; end;
  end else if Code='@mathcommand' then begin
    Value:='\operatorname{}';
    if EditCommandDialog(Self,Value,'Insert math command') then begin
      if not FormulaEditor.MathActive then FormulaEditor.SetFormulaKind('inline',False);
      PrepareMathCommand(Value); FormulaEditor.InsertCommand(Value);
    end;
  end else if Code='@nroot' then begin
    if not FormulaEditor.MathActive then FormulaEditor.SetFormulaKind('inline',False);
    FormulaEditor.InsertTeX('\sqrt[]{}');
  end else if Copy(Code,1,5)='@new:' then begin
    Value:=Copy(Code,6,MaxInt);
    if Value='gathered' then begin
      if not FormulaEditor.MathActive then FormulaEditor.SetFormulaKind('display',True);
      FormulaEditor.InsertTeX('\begin{gathered} \\ \end{gathered}');
    end else FormulaEditor.SetFormulaKind(Value,True);
  end else if Copy(Code,1,9)='@bodyenv:' then begin
    Value:=Copy(Code,10,MaxInt); FormulaEditor.SetParagraphAlignment(Value);
  end else if Code='@appendix' then begin
    if FormulaEditor.MathActive then begin StatusText:='Place the caret outside an equation to start appendices.'; Exit; end;
    FormulaEditor.InsertBody(LineEnding+LineEnding+'\appendix'+LineEnding+LineEnding,Length(LineEnding)*4+Length('\appendix'));
  end else if Copy(Code,1,12)='@bodyinsert:' then begin
    if FormulaEditor.MathActive then begin StatusText:='Place the caret outside an equation to insert a text environment.'; Exit; end;
    Value:=Copy(Code,13,MaxInt);
    if (Value='proof') and (Pos('amsthm',Document.Preamble)=0) then begin
      I:=Pos('\begin{document}',Document.Preamble); if I=0 then I:=Length(Document.Preamble)+1;
      RecordVisualEdit; Insert('\usepackage{amsthm}'+LineEnding,Document.Preamble,I);
      FormulaEditor.SetContext(Document.Preamble,ExtractFileDir(FileName),Engine.Text,'',False);
    end;
    FormulaEditor.WrapSelection('\begin{'+Value+'}'+LineEnding,LineEnding+'\end{'+Value+'}');
  end else if Code='@textcolor:default' then begin
    FormulaEditor.SetTextColor('');
  end else if Code='@textcolor' then begin
    ColorDialog:=TColorDialog.Create(Self);
    try
      if ColorDialog.Execute then begin
        if Pos('{xcolor}',Document.Preamble)=0 then begin
          RecordVisualEdit;
          I:=Pos('\begin{document}',Document.Preamble);
          Insert('\usepackage{xcolor}'+LineEnding,Document.Preamble,I);
        end;
        J:=ColorToRGB(ColorDialog.Color);
        Value:=IntToHex(J and 255,2)+IntToHex((J shr 8) and 255,2)+IntToHex((J shr 16) and 255,2);
        FormulaEditor.SetTextColor(Value);
      end;
    finally ColorDialog.Free; end;
  end else if Code='@properties' then PropertiesClick(Sender)
  else if Code='@command' then begin
    Value:=CurrentVisualEditor.CurrentCommandSource;
    if Value='' then begin MessageDlg('Edit command','Place the caret inside a command first.',mtInformation,[mbOK],0); Exit; end;
    if EditCommandDialog(Self,Value) then CurrentVisualEditor.ReplaceCurrentCommand(Value);
  end else if (Code='@citation') or (Code='@bibcite') then begin
    Dialog;
    try
      D.Caption:='Insert citation'; LabelAt('Citation type',14);
      if Code='@bibcite' then Kind:=Choice(10,'cite;citep;citet;autocite;parencite')
      else Kind:=Choice(10,'ref;eqref;autoref;pageref;nameref');
      LabelAt('Target label / key',54); LeftD:=Choice(50,''); LeftD.Style:=csDropDown;
      if Code='@citation' then FormulaEditor.LabelNames(LeftD.Items)
      else FormulaEditor.CitationNames(LeftD.Items);
      LeftD.ItemIndex:=-1; ApplyTheme(D);
      if D.ShowModal=mrOK then FormulaEditor.InsertAnnotation(Kind.Text,LeftD.Text);
    finally D.Free; end;
  end else if Copy(Code,1,6)='@list:' then begin
    Value:=Copy(Code,7,MaxInt); FormulaEditor.WrapSelection('\begin{'+Value+'}'+LineEnding+'\item ',LineEnding+'\end{'+Value+'}');
  end else if (Code='@bibliography') or (Code='@bibliographyinsert') then begin
    Bibliography:=TBibliographyForm.Create(Self);
    try
      Bibliography.Load(Document.Source,DocumentDirectory);
      if (Code='@bibliography') or not Bibliography.Configured then
        if Bibliography.ShowModal<>mrOK then Exit;
      RecordVisualEdit;
      try J:=Bibliography.Apply(Document,ActiveBlock+1,Code='@bibliographyinsert');
      except on E:Exception do begin MessageDlg('Bibliography',E.Message,mtError,[mbOK],0); Exit; end; end;
      Modified:=True; BuildCards; EditBlock(J); UpdateTitle; QueuePreview;
    finally Bibliography.Free; end;
  end else if Code='@editref' then FormulaEditor.EditAnnotation
  else if Code='@theoremtitle' then FormulaEditor.EditTheoremTitle
  else if Code='@theorem' then begin
    Dialog;
    try
      D.Caption:='Insert theorem'; LabelAt('Environment',14); Kind:=Choice(10,'');
      FormulaEditor.TheoremNames(Kind.Items);
      if Kind.Items.Count=0 then Kind.Items.Add('theorem');
      Kind.Items.Add('proof'); Kind.ItemIndex:=0; ApplyTheme(D);
      if D.ShowModal<>mrOK then Exit;
      Value:=Kind.Text; S:=''; FormulaEditor.TheoremNames(Kind.Items);
      if Pos('amsthm',Document.Preamble)=0 then S:='\usepackage{amsthm}'+LineEnding;
      if (Value<>'proof') and (Kind.Items.IndexOf(Value)<0) then S:=S+'\newtheorem{'+Value+'}{Theorem}'+LineEnding;
      if S<>'' then begin
        I:=Pos('\begin{document}',Document.Preamble);
        if I=0 then begin MessageDlg('Theorem insertion','Add amsthm and a newtheorem declaration in Document settings first.',mtInformation,[mbOK],0); Exit; end;
        RecordVisualEdit; Insert(S,Document.Preamble,I);
        if FileName='' then R:=GetCurrentDir else R:=ExtractFileDir(FileName);
        FormulaEditor.SetContext(Document.Preamble,R,Engine.Text,'',False);
      end;
      FormulaEditor.WrapSelection('\begin{'+Value+'}'+LineEnding,LineEnding+'\end{'+Value+'}');
    finally D.Free; end;
  end else if Code='@matrix' then begin
    Matrix:=TMatrixDialog.Create(Self);
    try if Matrix.ShowModal=mrOK then FormulaEditor.InsertTeX(Matrix.TeX); finally Matrix.Free; end;
  end else if Code='@delimiters' then begin
    Dialog;
    try
      LabelAt('Opening delimiter',14); LeftD:=Choice(10,'(;[;\{;|;\|;\langle;.;\lfloor;\lceil');
      LabelAt('Closing delimiter',54); RightD:=Choice(50,');];\};|;\|;\rangle;.;\rfloor;\rceil');
      ApplyTheme(D); if D.ShowModal<>mrOK then Exit;
      L:='\left'+LeftD.Text; R:='\right'+RightD.Text;
      FormulaEditor.WrapSelection(L+' ',R);
    finally D.Free; end;
  end else if Copy(Code,1,5)='@env:' then begin
    Value:=Copy(Code,6,MaxInt);
    if Value='gathered' then FormulaEditor.InsertTeX('\begin{gathered} \\ \end{gathered}')
    else if (Value='aligned') or (Value='cases') then FormulaEditor.InsertTeX('\begin{'+Value+'} & \\ & \end{'+Value+'}')
    else FormulaEditor.SetFormulaKind(Value,False);
  end else if Code='@inline' then FormulaEditor.SetFormulaKind('inline',False)
  else if Code='@display' then FormulaEditor.SetFormulaKind('display',False)
  else if Code='@rename' then begin
    Value:=FormulaEditor.CurrentCommandName;
    if InputQuery('Edit command','Command name (arguments are preserved):',Value) then FormulaEditor.RenameCommand(Value);
  end else if Code='@custom' then begin
    Value:='\'; if InputQuery('Insert command','LaTeX command:',Value) then FormulaEditor.InsertCommand(Value);
  end else if (Code<>'') and (Code[1]='@') then begin
    Value:=''; S:=Copy(Code,2,MaxInt);
    Dialog;
    try
      D.Caption:='Insert '+S; LabelAt('Label or tag',14);
      Kind:=Choice(10,''); Kind.Style:=csDropDown;
      if (S='ref') or (S='eqref') or (S='autoref') then FormulaEditor.LabelNames(Kind.Items);
      Kind.ItemIndex:=-1; Kind.Text:=''; ApplyTheme(D);
      if D.ShowModal=mrOK then FormulaEditor.InsertAnnotation(S,Kind.Text);
    finally D.Free; end;
  end else if (Pos('\math',Code)=1) or (TMenuItem(Sender).Parent=ToolPopups[3].Items) or
    (Code='\hat') or (Code='\widehat') or (Code='\bar') or (Code='\vec') or
    (Code='\dot') or (Code='\ddot') or (Code='\tilde') or (Code='\widetilde') or
    (Code='\overline') or (Code='\underline') or (Code='\breve') or (Code='\check') or
    (Code='\acute') or (Code='\grave') or (Code='\overbrace') or (Code='\underbrace') then
    FormulaEditor.WrapSelection(Code+'{','}')
  else if (Code='^{}') or (Code='_{}') then FormulaEditor.WrapSelection(Copy(Code,1,2),'}')
  else if (Length(Code)>1) and (Code[1]='\') then FormulaEditor.InsertCommand(Code)
  else FormulaEditor.InsertTeX(Code);
  if FormulaEditor.CanFocus then FormulaEditor.SetFocus;
end;

procedure TMainForm.HistoryClick(Sender:TObject);
var L:TObjectList; I,N:Integer; M:TMenuItem; P:TPoint; S:TDocumentSnapshot; CaptionText,BeforeText,AfterText:string; Current:TDocumentSnapshot;
begin
  if DeferInput(@HistoryClick,Sender) then Exit;
  HistoryPopup.Items.Clear;
  if TComponent(Sender).Tag=0 then L:=FVisualUndo else L:=FVisualRedo;
  N:=L.Count;
  if Editor.Visible and not FPreambleEditing then begin
    if TComponent(Sender).Tag=0 then N:=TSynEditStringList(TSourceEditorAccess(Editor).GetTextBuffer).UndoList.RealCount
    else N:=TSynEditStringList(TSourceEditorAccess(Editor).GetTextBuffer).RedoList.RealCount;
  end;
  for I:=1 to Min(30,N) do begin
    CaptionText:='Source edit '+IntToStr(I);
    if not Editor.Visible or FPreambleEditing then begin
      S:=TDocumentSnapshot(L[L.Count-I]); BeforeText:=S.Blocks.Text;
      if I=1 then AfterText:=Document.Blocks.Text else begin Current:=TDocumentSnapshot(L[L.Count-I+1]); AfterText:=Current.Blocks.Text; end;
      if TComponent(Sender).Tag=0 then CaptionText:=DescribeChange(BeforeText,AfterText)
      else CaptionText:=DescribeChange(AfterText,BeforeText);
      if BeforeText=AfterText then begin
        BeforeText:=S.Preamble;
        if I=1 then AfterText:=Document.Preamble else AfterText:=Current.Preamble;
        if BeforeText=AfterText then CaptionText:='Document settings'
        else if TComponent(Sender).Tag=0 then CaptionText:='Preamble: '+DescribeChange(BeforeText,AfterText)
        else CaptionText:='Preamble: '+DescribeChange(AfterText,BeforeText);
      end;
    end;
    M:=TMenuItem.Create(Self); M.Caption:=IntToStr(I)+'. '+StringReplace(CaptionText,'&','&&',[rfReplaceAll]);
    M.Tag:=I+TComponent(Sender).Tag*1000; M.OnClick:=@HistoryItemClick; HistoryPopup.Items.Add(M);
  end;
  if N=0 then begin M:=TMenuItem.Create(Self); M.Caption:='No history'; M.Enabled:=False; HistoryPopup.Items.Add(M); end;
  P:=TControl(Sender).ClientToScreen(Point(0,TControl(Sender).Height)); HistoryPopup.PopUp(P.X,P.Y);
end;
procedure TMainForm.HistoryItemClick(Sender:TObject);
var I:Integer;
begin
  if DeferInput(@HistoryItemClick,Sender) then Exit;
  for I:=1 to TComponent(Sender).Tag mod 1000 do
    if Editor.Visible and not FPreambleEditing then begin
      if TComponent(Sender).Tag<1000 then Editor.Undo else Editor.Redo;
    end else RestoreVisualEdit(TComponent(Sender).Tag<1000);
end;
procedure TMainForm.ApplyAppearance;
var I:Integer; WasUpdating:Boolean;
begin
  ApplyTheme(Self);
  if FPagedView<>nil then begin ApplyTheme(FPagedView); FPagedView.Invalidate; end;
  UpdateFileTabCloseIcon;
  for I:=0 to Screen.FormCount-1 do if (Screen.Forms[I]<>Self) and (Screen.Forms[I]<>FFullSource) then ApplyTheme(Screen.Forms[I]);
  Scroll.Color:=PaperColor; FormulaBox.Color:=PaperColor;
  if FBodySeparator<>nil then FBodySeparator.Color:=PaperColor;
  if FPreambleToggle<>nil then FPreambleToggle.Color:=PaperColor;
  if FPreamblePanel<>nil then FPreamblePanel.Color:=PaperColor;
  ApplySourceStyle(WrappedEditor); ApplySourceStyle(PlainEditor);
  if FFullSource<>nil then FFullSource.ApplyAppearance(FSourceFontPreference,Editor.Font.Size);
  for I:=0 to High(Cards) do begin Cards[I].Panel.Color:=PaperColor; Cards[I].Image.Invalidate; end;
  RefreshRibbonIcons(Ribbon); RefreshRibbonIcons(QuickAccessBar);
  RefreshRibbonIcons(Status);
  if SourceTools<>nil then begin ApplyTheme(SourceTools); RefreshRibbonIcons(SourceTools); end;
  FormulaEditor.Invalidate;
  if PreambleEditor<>nil then PreambleEditor.Invalidate;
  WasUpdating:=FUpdatingRibbon; FUpdatingRibbon:=True;
  try
  if AppearanceChoice<>nil then AppearanceChoice.ItemIndex:=Ord(AppearanceMode);
  SelectZoom(ZoomChoice,FPreviewPercent);
  FUpdatingZoom:=True;
  try StatusZoom.Position:=PreviewScalePercent; StatusZoomLabel.Caption:=IntToStr(PreviewScalePercent)+'%';
  finally FUpdatingZoom:=False; end;
  finally FUpdatingRibbon:=WasUpdating; end;
end;
procedure TMainForm.PreferencesClick(Sender:TObject);
var D:TSettingsForm;
begin
  if DeferInput(@PreferencesClick,Sender) then Exit;
  D:=TSettingsForm.Create(Self);
  try
    D.Appearance.ItemIndex:=Ord(AppearanceMode); D.SourceWrap.Checked:=SourceWrapMenuItem.Checked;
    D.SourceSize.Value:=Editor.Font.Size; D.DefaultEngine.ItemIndex:=D.DefaultEngine.Items.IndexOf(Engine.Text);
    D.SourceFont.Text:=FSourceFontPreference;
    D.RealtimeCompile.Checked:=FRealtimeCompile;
    SelectZoom(D.PreviewScale,FPreviewPercent);
    if (Sender is TControl) and (TControl(Sender).Name='SourceSettingsButton') then D.Pages.ActivePage:=D.SourceTab;
    D.OnApply:=@ApplySettings; ApplyTheme(D); D.ShowModal;
  finally D.Free; end;
end;
procedure TMainForm.ApplySettings(Sender:TObject);
var D:TSettingsForm; Ini:TIniFile; OldEngine:string; Size:Integer; OldBuildSteps,OldRealtime:Boolean; Anchor:TPreviewAnchor;
begin
  if FApplyingSettings or FLoading then Exit;
  FApplyingSettings:=True;
  try
  D:=TSettingsForm(Sender); Size:=EnsureRange(D.SourceSize.Value,8,36);
  OldBuildSteps:=ExtensionBuildEnabled;
  Anchor:=CapturePreviewAnchor;
  OldRealtime:=FRealtimeCompile; FRealtimeCompile:=D.RealtimeCompile.Checked;
  if OldRealtime<>FRealtimeCompile then FManualPreview:=False;
  if OldRealtime and not FRealtimeCompile then ClearCompiledPreviews;
  SourceHighlight:=D.Highlighting;
  SetDiagramPreviewEnabled(D.DiagramBackend.Checked);
  SetDiagramBackend(TDiagramBackend(EnsureRange(D.DiagramRenderer.ItemIndex,0,1)));
  SetAppearance(TAppearanceMode(EnsureRange(D.Appearance.ItemIndex,0,2)));
  if D.SourceWrap.Checked<>SourceWrapMenuItem.Checked then SourceWrapClick(nil);
  WrappedEditor.ParentFont:=False; WrappedEditor.Font.Size:=Size;
  if D.SourceFont.Text<>'' then FSourceFontPreference:=NormalizeSourceFont(D.SourceFont.Text);
  UpdateSourceFonts;
  if D.PreviewScale.Text='Fit Width' then SetFitWidth(False)
  else if D.PreviewScale.Text='Fit Page' then SetFitPage
  else if D.PreviewScale.ItemIndex>=0 then SetPreviewPercent(StrToIntDef(StringReplace(D.PreviewScale.Items[D.PreviewScale.ItemIndex],'%','',[]),100),False);
  if PlainEditor<>nil then begin PlainEditor.ParentFont:=False; PlainEditor.Font.Size:=Size; PlainEditor.Font.Name:=WrappedEditor.Font.Name; end;
  OldEngine:=Engine.Text;
  if (D.DefaultEngine.ItemIndex>=0) and (D.DefaultEngine.ItemIndex<D.DefaultEngine.Items.Count) then
    Engine.ItemIndex:=Engine.Items.IndexOf(D.DefaultEngine.Items[D.DefaultEngine.ItemIndex]);
  ApplyAppearance; ApplyTheme(D); LayoutCards(nil);
  ForceDirectories(ExtractFileDir(GetAppConfigFile(False)));
  Ini:=TIniFile.Create(GetAppConfigFile(False));
  try
    WriteSourceHighlight(Ini);
    Ini.WriteInteger('Appearance','Mode',Ord(AppearanceMode)); Ini.WriteBool('Appearance','Dark',UITheme.DarkMode); Ini.WriteBool('Editor','WordWrap',SourceWrapMenuItem.Checked);
    Ini.WriteInteger('Appearance','PreviewScale',FPreviewPercent);
    Ini.WriteBool('Appearance','FitWidth',FFitWidth);
    Ini.WriteString('Editor','FontName',FSourceFontPreference);
    Ini.WriteInteger('Editor','FontSize',Size); Ini.WriteString('Compiler','Engine',Engine.Text);
    Ini.WriteBool('Compiler','ExtensionSteps',D.ExtensionSteps.Checked);
    Ini.WriteBool('Preview','TeXDiagrams',DiagramPreviewEnabled);
    Ini.WriteBool('Preview','RealtimeCompile',FRealtimeCompile);
    Ini.WriteInteger('Preview','DiagramBackend',Ord(SelectedDiagramBackend));
  finally Ini.Free; end;
  if (OldEngine<>Engine.Text) or D.CompilerCommandChanged or (OldBuildSteps<>D.ExtensionSteps.Checked) then begin D.CompilerCommandChanged:=False; EngineChanged(nil); end;
  if OldRealtime<>FRealtimeCompile then begin QueuePreview; RestorePreviewAnchor(Anchor); end;
  finally FApplyingSettings:=False; end;
end;
procedure TMainForm.SelectZoom(Choice:TComboBox; Percent:Integer);
var Index:Integer; ScaleText,Options:string;
begin
  if Choice=nil then Exit;
  Options:='Fit Width'+LineEnding;
  if FPagedView<>nil then Options:=Options+'Fit Page'+LineEnding;
  Options:=Options+'100%'+LineEnding+'50%'+LineEnding+'75%'+LineEnding+'125%'+LineEnding+'150%'+LineEnding+'200%'+LineEnding;
  if Choice.Items.Text<>Options then Choice.Items.Text:=Options;
  Choice.Style:=csDropDown; Choice.ReadOnly:=True;
  if FFitPage and (FPagedView<>nil) then ScaleText:='Fit Page'
  else if FFitWidth then ScaleText:='Fit Width' else ScaleText:=IntToStr(Percent)+'%';
  Index:=Choice.Items.IndexOf(ScaleText);
  Choice.ItemIndex:=Index; Choice.Text:=ScaleText;
end;
procedure TMainForm.SetPreviewPercent(Percent:Integer; SaveSetting:Boolean);
var OldPercent:Integer; Ini:TIniFile; WasUpdating,WasFit:Boolean;
begin
  Percent:=EnsureRange(Percent,50,200); OldPercent:=PreviewScalePercent; WasFit:=FFitWidth or FFitPage; FFitWidth:=False; FFitPage:=False;
  FUpdatingZoom:=True; WasUpdating:=FUpdatingRibbon; FUpdatingRibbon:=True;
  try
    StatusZoom.Position:=Percent; StatusZoomLabel.Caption:=IntToStr(Percent)+'%';
    SelectZoom(ZoomChoice,Percent);
    if (Percent=OldPercent) and not WasFit then Exit;
    FPreviewPercent:=Percent;
    if FSplitView<>nil then FSplitView.Preview.Zoom(Percent,False);
    if FPagedView<>nil then FPagedView.SetZoom(Percent,False);
    if FPagedView=nil then FormulaEditor.PreviewZoom:=Percent/100; LayoutCards(nil);
    if SaveSetting then begin
      ForceDirectories(ExtractFileDir(GetAppConfigFile(False))); Ini:=TIniFile.Create(GetAppConfigFile(False));
      try Ini.WriteInteger('Appearance','PreviewScale',Percent); Ini.WriteBool('Appearance','FitWidth',False); finally Ini.Free; end;
    end;
  finally FUpdatingZoom:=False; FUpdatingRibbon:=WasUpdating; end;
end;
function TMainForm.PreviewScalePercent:Integer;
begin
  if FSplitView<>nil then Exit(FSplitView.Preview.ScalePercent);
  if FPagedView<>nil then Exit(FPagedView.ScalePercent);
  Result:=FPreviewPercent;
  if FFitWidth then Result:=Max(1,Round((PreviewLayoutWidth(Scroll)-88)*100/Max(1,PreviewContentWidth)));
end;
function TMainForm.PreviewContentWidth:Integer;
var LeftPoints,RightPoints:Double;
begin
  if FPreviewMarginRevision<>Revision then begin
    DocumentMarginExtent(FEffectivePreamble+Document.Blocks.Text,LeftPoints,RightPoints);
    FPreviewMarginLeft:=Ceil(LeftPoints*120/72.27); FPreviewMarginRight:=Ceil(RightPoints*120/72.27); FPreviewMarginRevision:=Revision;
  end;
  Result:=DocumentPreviewWidth(FEffectivePreamble)+FPreviewMarginLeft+FPreviewMarginRight;
end;
procedure TMainForm.SetFitPage;
var WasUpdating:Boolean;
begin
  if FPagedView=nil then Exit;
  WasUpdating:=FUpdatingRibbon; FUpdatingRibbon:=True;
  try
    FFitPage:=True; FFitWidth:=False; FPagedView.SetZoom(FPreviewPercent,False,True);
    SelectZoom(ZoomChoice,FPreviewPercent);
  finally FUpdatingRibbon:=WasUpdating; end;
end;
procedure TMainForm.SetFitWidth(SaveSetting:Boolean);
var Ini:TIniFile; WasUpdating:Boolean;
begin
  WasUpdating:=FUpdatingRibbon; FUpdatingRibbon:=True; FFitWidth:=True; FFitPage:=False;
  try
    SelectZoom(ZoomChoice,FPreviewPercent); LayoutCards(nil);
    if FSplitView<>nil then FSplitView.Preview.Zoom(FPreviewPercent,True);
    if FPagedView<>nil then FPagedView.SetZoom(FPreviewPercent,True);
    SetPreviewScroll(Scroll,0,Scroll.VertScrollBar.Position);
  finally FUpdatingRibbon:=WasUpdating; end;
  if SaveSetting then begin
    ForceDirectories(ExtractFileDir(GetAppConfigFile(False))); Ini:=TIniFile.Create(GetAppConfigFile(False));
    try Ini.WriteBool('Appearance','FitWidth',True); finally Ini.Free; end;
  end;
end;
procedure TMainForm.StatusZoomChanged(Sender:TObject);
begin
  if FUpdatingZoom or FLoading or (FormulaEditor=nil) then Exit;
  SetPreviewPercent(StatusZoom.Position);
end;
procedure TMainForm.AboutClick(Sender:TObject);
var D:TAboutForm;
begin D:=TAboutForm.Create(Self); try ApplyTheme(D); D.ShowModal; finally D.Free; end; end;
procedure TMainForm.EnvironmentCheckClick(Sender:TObject);
var D:TEnvironmentCheckForm; Catalog:TEditorAddons;
begin
  Catalog:=TEditorAddons.Create(True); D:=TEnvironmentCheckForm.Create(Self);
  try Catalog.Load; D.Engine:=Engine.Text; D.Directory:=DocumentDirectory; D.Addons:=Catalog; D.RefreshClick(nil); D.ShowModal;
  finally D.Free; Catalog.Free; end;
end;
procedure TMainForm.PropertiesClick(Sender:TObject);
var Visual:TMathEditor; Definition:TDefinitionForm; Value,Command,Code:string;
begin
  if DeferInput(@PropertiesClick,Sender) then Exit;
  Visual:=CurrentVisualEditor; if Visual=nil then Exit;
  if Visual.EditingDefinition then begin
    Definition:=TDefinitionForm.Create(Self);
    try Definition.LoadSource(Visual.CurrentDefinitionSource); if Definition.ShowModal=mrOK then Visual.ReplaceDefinition(Definition.Source);
    finally Definition.Free; end; Exit;
  end;
  Command:=Visual.CurrentCommandName; Code:='';
  if Command='includegraphics' then Code:='@figureedit'
  else if Command='includepdf' then Code:='@pdfedit'
  else if (Command='') or (Command='begin') or (Command='end') then begin
    if Visual.CurrentDiagramSource<>'' then Code:='@diagramedit'
    else if Visual.CurrentEnvironmentSource<>'' then Code:='@environmentoptions';
  end;
  if Code<>'' then begin ObjectTool(Code); Exit; end;
  Value:=Visual.CurrentCommandSource;
  if (Value<>'') and EditCommandDialog(Self,Value) then Visual.ReplaceCurrentCommand(Value);
end;
procedure TMainForm.DocumentInfoClick(Sender:TObject);
var D:TDocumentInfoForm;
begin
  if DeferInput(@DocumentInfoClick,Sender) then Exit;
  D:=TDocumentInfoForm.Create(Self);
  try D.Load(Document,FileName,Engine.Text,Modified); D.ShowModal; finally D.Free; end;
end;

procedure TMainForm.SourceSelectionChanged(Sender:TObject; Changes:TSynStatusChanges);
var Root,N,Current:TMathNode; Fields:TList; I,A,B,L,R,Caret:Integer;
    InEquation,InTable,InTheorem,InFigure:Boolean; Header,Directory:string;
    Selection:TTeXTextSelection;
  procedure ContextAt(N:TMathNode);
  var J,Start:Integer;
  begin
    Start:=MathSourceOffset(N)-Length(N.Prefix);
    if (Caret<Start) or (Caret>Start+Length(N.TeX)) then Exit;
    InTable:=InTable or (N.Kind=mkTable) or ((N.Kind=mkEnvironment) and ((N.Text='table') or (N.Text='table*')));
    InEquation:=InEquation or (N.Kind=mkFormula);
    InTheorem:=InTheorem or ((N.Kind=mkEnvironment) and ((N.Text='proof') or FSelectionRegistry.IsTheorem(N.Text)));
    InFigure:=InFigure or IsFigureNode(N);
    for J:=0 to N.Children.Count-1 do ContextAt(TMathNode(N.Children[J]));
  end;
begin
  if FLoading or not Editor.Visible or FPreambleEditing then Exit;
  if PluginSourceActive then begin FSourceCommandPath:=''; UpdateStatusBar; Exit; end;
  { Scrolling and native allocation also report status changes. Explicit
    callers use [] when the editor or document context has been replaced. }
  if (Changes<>[]) and (Changes*[scCaretX,scCaretY,scSelection,scModified]=[]) then Exit;
  SyncFullSource;
  A:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockBegin]);
  B:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.BlockEnd]);
  Root:=nil; Fields:=TList.Create;
  try
    Directory:=DocumentDirectory;
    if FSelectionRevision<>Revision then begin
      FSelectionRegistry.Load(Document.Source,Directory,Engine.Text); FSelectionContext.Load(Document.Source,Directory,Engine.Text);
      FSelectionRevision:=Revision;
    end;
    try Root:=ParseParagraph(Editor.Text,FSelectionRegistry); except Exit; end;
    Caret:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.LogicalCaretXY]); InEquation:=False; InTable:=False; InTheorem:=False; InFigure:=False;
    ContextAt(Root); MathFields(Root,Fields);
    Header:=FEffectivePreamble+FProjectBefore;
    for I:=0 to ActiveBlock-1 do Header:=Header+Document.Blocks[I];
    if FSourceStyles=nil then FSourceStyles:=TTeXStyles.Create;
    FSourceStyles.Load(Header,Directory,FSelectionRegistry);
    Current:=nil;
    if A=B then begin
      A:=Caret; B:=Caret;
      for I:=Fields.Count-1 downto 0 do begin
        N:=TMathNode(Fields[I]); L:=MathSourceOffset(N); R:=L+Length(N.Text);
        if (Caret>=L) and (Caret<=R) then begin Current:=N; Break; end;
      end;
    end;
    Selection:=QueryTextSelectionStyle(Fields,Current,A,B,
      InitialTextStyle(Header,Directory,Engine.Text,FSelectionRegistry),FSourceStyles,FSelectionContext,Directory);
    UpdateFontControls(Selection);
    if Current=nil then for I:=0 to Fields.Count-1 do begin
      N:=TMathNode(Fields[I]); L:=MathSourceOffset(N); R:=L+Length(N.Text);
      if (Caret>=L) and (Caret<=R) then begin Current:=N; Break; end;
    end;
    UpdateParagraphControl(ParagraphStyleName(Current,FSelectionRegistry));
    FSourceCommandPath:=CommandPath(Current);
    UpdateContextTabs(InEquation,InTable,InTheorem,False,InFigure); UpdateStatusBar;
  finally Fields.Free; Root.Free; end;
end;

procedure TMainForm.TheoremToolClick(Sender:TObject);
begin ToolCommandClick(Sender); end;

procedure TMainForm.ContextEditClick(Sender:TObject);
var Visual:TMathEditor; P:TPoint; Bounds:TRect; CommandName:string;
begin
  if DeferInput(@ContextEditClick,Sender) then Exit;
  Visual:=CurrentVisualEditor; P:=Visual.CaretPoint;
  if Visual.CommandContext(CommandName,Bounds) then P:=Bounds.CenterPoint;
  case TComponent(Sender).Tag of
    1:Visual.EditSpaceAt(P.X,P.Y);
    2:Visual.EditInputAt(P.X,P.Y);
    3:GeneratedAction(Visual,Visual.Formula,-1,True);
  end;
end;

procedure TMainForm.ContextPopup(Sender:TObject);
var Item,MenuParent:TMenuItem; Visual:TMathEditor;
    Editing,Selected,Math,Table,Theorem,Generated,Properties:Boolean;
    Command,Environment,Source,Units:string; A,B:Integer; SpaceWidth:Double; Rule:TTeXRule;
  procedure Add(const Caption:string; Handler:TNotifyEvent; Tag:Integer=0; const Code:string='');
  begin
    Item:=TMenuItem.Create(EditPopup); Item.Caption:=Caption; Item.OnClick:=Handler;
    Item.Tag:=Tag; Item.Hint:=Code; MenuParent.Add(Item);
  end;
  procedure Separator;
  begin
    if (MenuParent.Count>0) and (MenuParent.Items[MenuParent.Count-1].Caption<>'-') then Add('-',nil);
  end;
  procedure Tool(const Caption,Code:string);
  begin Add(Caption,@ToolCommandClick,0,Code); end;
  procedure PropertyTool(const Caption,Code:string);
  begin Tool(Caption,Code); Properties:=True; end;
  procedure ClipboardItem(const Caption:string; Key:Word);
  begin Add(Caption,@ClipboardClick,Key); Item.ShortCut:=ShortCut(Key,[ssCtrl]); end;
  procedure TableGroup(const Caption:string; Operation:Integer);
  begin
    Add(Caption,nil); MenuParent:=Item;
    Tool('Insert before','@table:'+IntToStr(Operation)); Tool('Insert after','@table:'+IntToStr(Operation+1));
    Tool('Delete','@table:'+IntToStr(Operation+2)); MenuParent:=EditPopup.Items;
  end;
begin
  { A pending edit action can still refer to one of these menu items. }
  if Assigned(FDeferredAction) then Exit;
  EditPopup.Items.Clear; MenuParent:=EditPopup.Items; Visual:=CurrentVisualEditor;
  Editing:=BodyEditing or FPreambleEditing or ((ActiveBlock>=0) and Editor.Visible);
  Selected:=False; Generated:=False;
  if Editor.Visible then Selected:=Editor.SelAvail
  else if Editing then begin Selected:=Length(Visual.SelectedRects)>0; Generated:=GeneratedBlock(Visual.Formula) and not Visual.CodeOnly; end;
  if FPagedView<>nil then begin FPagedView.GetSourceSelection(A,B); Selected:=Selected or (A<>B); end
  else if (FSelectionStartBlock>=0) and (FSelectionStartBlock<>FSelectionEndBlock) then Selected:=True;
  if Selected then begin
    if Editing and not Generated then ClipboardItem('Cut',VK_X);
    ClipboardItem('Copy',VK_C);
  end;
  if not Generated then begin ClipboardItem('Paste',VK_V); Item.Enabled:=Editing and Clipboard.HasFormat(CF_TEXT); end;
  ClipboardItem('Select all',VK_A); Item.Enabled:=Editing;
  if Editor.Visible then begin
    Separator; Add('Wrap source lines',@SourceWrapClick); SetMenuChecked(Item,Editor=WrappedEditor);
    if not PluginSourceActive then begin Tool('Comment / uncomment','@comment'); Add('Visual editing',@EquationModeClick); end;
    if LinkedTeXInputAt(Editor.Text,FileName,Length(Editor.TextBetweenPoints[Point(1,1),Editor.LogicalCaretXY]))<>'' then
      Add('Open file',@OpenSubfileClick);
    Exit;
  end;
  if not Editing then Exit;
  Separator;
  if (FPagedView<>nil) and Visual.CodeOnly then begin
    Tool('Comment / uncomment','@comment'); Add('Visual editing',@EquationModeClick); Exit;
  end;
  if Generated then begin
    if Pos('\maketitle',Visual.Formula)>0 then Source:='Document title settings…'
    else if (Pos('\bibliography',Visual.Formula)>0) or (Pos('\printbibliography',Visual.Formula)>0) or
      (Pos('\begin{thebibliography}',Visual.Formula)>0) then Source:='Bibliography settings…'
    else Source:='Contents settings…';
    Add(Source,@ContextEditClick,3); Add('Edit paragraph source',@SourceModeClick); Exit;
  end;
  if Visual.EditingDefinition then begin
    Add('Definition and arguments…',@DefinitionAction,3);
    Add('Add required argument',@DefinitionAction,0); Add('Add optional argument',@DefinitionAction,1);
    Add('Edit definition source',@DefinitionAction,4); SetMenuChecked(Item,Visual.DefinitionSourceEditing);
  end else if FPreambleEditing then Add('Preamble settings…',@PreambleClick)
  else begin
    Math:=Visual.EditingMath; Table:=Visual.EditingTable; Theorem:=Visual.EditingTheorem;
    Command:=Visual.CurrentCommandName; Environment:=Visual.CurrentEnvironmentName; Properties:=False;
    Source:=Visual.CurrentCommandSource;
    if ReadTeXRule(Source,Rule) then begin Add('Rule settings…',@ContextEditClick,1); Properties:=True; end
    else if ReadMathSpace(Source,SpaceWidth,Units) or ReadVerticalSpace(Source,SpaceWidth,Units) or
      (Command='indent') or (Command='noindent') then begin Add('Spacing settings…',@ContextEditClick,1); Properties:=True; end;
    if LinkedTeXInputAt(Visual.Formula,FileName,Visual.SourceCaret)<>'' then begin
      Add('Open file',@OpenSubfileClick); Add('Choose subfile…',@ContextEditClick,2); Properties:=True;
    end;
    if IsLabelReference(Command) then PropertyTool('Edit reference target…','@editref');
    if IsCitationCommand(Command) then PropertyTool('Edit bibliography citation…','@editref');
    if (Command='label') or (Command='tag') then PropertyTool('Edit label or tag…','@editref');
    if Pos('\includepdf',Visual.CurrentFigureSource)=1 then PropertyTool('Included PDF pages…','@pdfedit')
    else if Visual.CurrentFigureSource<>'' then PropertyTool('Edit figure image…','@figureedit');
    if Visual.CurrentBoxSource<>'' then PropertyTool('Box settings…','@boxoptions');
    if Visual.CurrentDiagramSource<>'' then PropertyTool('Edit diagram…','@diagramedit');
    if Visual.CurrentFloatSource<>'' then PropertyTool('Caption, label and placement…','@floatcaption');
    if Table then begin
      TableGroup('Rows',0); TableGroup('Columns',3); Tool('Merge selected cells','@table:12'); Tool('Split cell','@table:13'); PropertyTool('Table lines…','@tablelines');
      PropertyTool('Table environment options…','@environmentoptions');
    end else if Visual.CurrentEnvironmentSource('lstlisting')<>'' then
      PropertyTool('Listing options…','@environmentoptions:lstlisting');
    if Theorem then PropertyTool('Edit theorem title','@theoremtitle');
    if (Command<>'') and not Properties then Tool('Edit command and arguments…','@command');
    if Math then begin
      Tool('Inline formula','@inline'); Tool('Displayed formula','@display');
      Tool('Edit equation source','@formulasource'); SetMenuChecked(Item,Visual.FormulaSourceMode);
      if Visual.CanEditGrid(6) then begin
        Add('Rows and columns',nil); MenuParent:=Item;
        Add('Insert row below',@EquationActionClick,301); Add('Delete row',@EquationActionClick,302);
        Add('Duplicate row',@EquationActionClick,306);
        if Visual.CanEditGrid(7) then begin
          Add('Insert column',@EquationActionClick,304); Add('Delete column',@EquationActionClick,305);
          Add('Duplicate column',@EquationActionClick,307);
        end;
        MenuParent:=EditPopup.Items;
      end;
    end else begin
      if Selected and not Visual.SelectingTableCells then begin
        Separator;
        Add('Bold',@FormatClick,0); SetMenuChecked(Item,Visual.TextStyleActive('\textbf'));
        Add('Italic',@FormatClick,1); SetMenuChecked(Item,Visual.TextStyleActive('\textit'));
        Tool('Text color…','@textcolor'); Tool('Clear formatting','@clearformat');
      end;
      if (Copy(Visual.CurrentParagraphStyle,1,9)='@heading:') and (Visual.CurrentParagraphStyle<>'@heading:') then
        Add('Normal paragraph',@FormatClick,8);
      if not Table and not Properties then Tool('Comment / uncomment','@comment');
    end;
    Separator;
    if Selected then Add('Edit selection source in place',@SelectionSourceClick)
    else if (Command<>'') or (Environment<>'') then Add('Edit source in place',@SelectionSourceClick);
    Add('Edit paragraph source',@SourceModeClick);
  end;
end;

procedure TMainForm.OpenBibliography(Sender:TObject);
var I:Integer;
begin
  for I:=0 to ToolPopups[6].Items.Count-1 do
    if ToolPopups[6].Items[I].Hint='@bibliography' then begin ToolCommandClick(ToolPopups[6].Items[I]); Exit; end;
end;
