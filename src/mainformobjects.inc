{ SPDX-License-Identifier: GPL-3.0-or-later }
procedure TMainForm.OpenFigure(Sender:TObject);
begin
  if Pos('\includepdf',FormulaEditor.CurrentFigureSource)=1 then ObjectTool('@pdfedit')
  else ObjectTool('@figureedit');
end;
function TMainForm.ObjectTool(const Code:string):Boolean;
var TableDialog:TTableDialog; LinesDialog:TTableLinesDialog; FigureDialog:TFigureDialog;
    FloatDialog:TFloatDialog; TheoremDialog:TTheoremDialog; EnvironmentDialog:TEnvironmentDialog; DiagramDialog:TDiagramForm; Model:TTeXTable;
    OptionsDialog:TEnvironmentForm; PDFDialog:TPDFDialog; SplitDialog:TSplitCellDialog;
    S,Directory,Environment,PropertyName:string; Caret,Offset,I,SavedScroll:Integer;
  procedure RequirePackage(const Name:string);
  var Header:TPreambleModel; Options:TStringList; Text,Value:string; Index,J:Integer;
  begin
    if Name='' then Exit;
    Header:=TPreambleModel.Create; Options:=TStringList.Create;
    try
      Header.Load(Document.Preamble); Index:=Header.PackageIndex(Name);
      if Index<0 then begin
        Value:=''; if Name='xy' then Value:='all'; Header.SetPackage(Name,Value);
      end else if Name='xy' then begin
        Value:=TPackageOption(Header.Packages[Index]).Options;
        Options.StrictDelimiter:=True; Options.CommaText:=Value;
        for J:=0 to Options.Count-1 do Options[J]:=Trim(Options[J]);
        if Options.IndexOf('all')<0 then begin
          if Trim(Value)<>'' then Value:=Value+','; Header.SetPackage(Name,Value+'all');
        end;
      end;
      Text:=Header.Source;
      if Text<>Document.Preamble then begin
        RecordVisualEdit; Document.Preamble:=Text;
        FormulaEditor.SetContext(Text,DocumentDirectory,Engine.Text,'',False);
      end;
    finally Options.Free; Header.Free; end;
  end;
begin
  Result:=True; SavedScroll:=Scroll.VertScrollBar.Position;
  try
    if Code='@boxsource' then FormulaEditor.EditBoxSource
    else if Code='@boxoptions' then begin
      S:=FormulaEditor.CurrentBoxSource; if S='' then Exit;
      if Pos('\begin{',S)=1 then begin
        if Pos('\begin{tcolorbox}',S)=1 then ObjectTool('@environmentoptions:tcolorbox')
        else if EditCommandDialog(Self,S,'Box arguments') then FormulaEditor.ReplaceBox(S);
      end else if EditCommandDialog(Self,S,'Box arguments') then FormulaEditor.ReplaceBox(S);
    end else if (Code='@pdfedit') or (Code='@pdfinsert') then begin
      if (Code='@pdfinsert') and FormulaEditor.MathActive then Exit;
      S:='\includepdf{example.pdf}';
      if Code='@pdfedit' then begin S:=FormulaEditor.CurrentFigureSource; if Pos('\includepdf',S)<>1 then Exit; end;
      PDFDialog:=TPDFDialog.Create(Self);
      try
        PDFDialog.Directory:=DocumentDirectory; PDFDialog.Load(S);
        if PDFDialog.ShowModal=mrOK then begin
          RequirePackage('pdfpages');
          if Code='@pdfedit' then FormulaEditor.ReplaceFigure(PDFDialog.Source)
          else FormulaEditor.InsertBody(PDFDialog.Source,0);
        end;
      finally PDFDialog.Free; end;
    end else if Copy(Code,1,19)='@environmentoptions' then begin
      Environment:=''; if Copy(Code,20,1)=':' then Environment:=Copy(Code,21,MaxInt);
      PropertyName:=''; I:=Pos(':',Environment);
      if I>0 then begin PropertyName:=Copy(Environment,I+1,MaxInt); Environment:=Copy(Environment,1,I-1); end;
      S:=FormulaEditor.CurrentEnvironmentSource(Environment); if S='' then Exit;
      OptionsDialog:=TEnvironmentForm.Create(Self);
      try
        OptionsDialog.Load(S);
        OptionsDialog.SelectProperty(PropertyName);
        if OptionsDialog.ShowModal=mrOK then begin
          S:=OptionsDialog.Source;
          if S<>FormulaEditor.CurrentEnvironmentSource(Environment) then FormulaEditor.ReplaceEnvironment(S,Environment);
        end;
      finally OptionsDialog.Free; end;
    end else if Code='@environmentinsert' then begin
      if FormulaEditor.MathActive then begin StatusText:='Place the caret outside an equation to insert a document environment.'; Exit; end;
      EnvironmentDialog:=TEnvironmentDialog.Create(Self);
      try if EnvironmentDialog.ShowModal=mrOK then begin
        S:=Trim(EnvironmentDialog.PackageName.Text);
        RequirePackage(S);
        S:=EnvironmentDialog.Source(Caret); FormulaEditor.InsertBody(S,Caret);
      end; finally EnvironmentDialog.Free; end;
    end else if Code='@tableinsert' then begin
      if FormulaEditor.MathActive then begin StatusText:='Place the caret outside an equation to insert a table.'; Exit; end;
      TableDialog:=TTableDialog.Create(Self);
      try if TableDialog.ShowModal=mrOK then begin S:=TableDialog.Source(Caret); FormulaEditor.InsertBody(S,Caret); end;
      finally TableDialog.Free; end;
    end else if Copy(Code,1,7)='@table:' then begin
      if Code='@table:13' then begin
        if CurrentVisualEditor.CurrentTableSource='' then Exit;
        SplitDialog:=TSplitCellDialog.Create(Self);
        try
          if SplitDialog.ShowModal=mrOK then
            if not CurrentVisualEditor.SplitTableCell(SplitDialog.Rows.Value,SplitDialog.Columns.Value,SplitDialog.Borders.Checked) then
              MessageDlg('Split cell','This split exceeds the table limit or the caret is not in an editable cell.',mtInformation,[mbOK],0);
        finally SplitDialog.Free; end;
      end else if not FormulaEditor.EditTable(StrToIntDef(Copy(Code,8,MaxInt),-1)) then
        StatusText:='Click a table cell to use this command.';
    end else if Copy(Code,1,8)='@border:' then begin
      I:=StrToIntDef(Copy(Code,9,MaxInt),-1); if (I<0) or (I>7) then Exit;
      Caret:=1; if I>=4 then Caret:=0;
      if not FormulaEditor.EditTableBorder(I mod 4,Caret) then StatusText:='Click a table cell or select cells to edit their borders.';
    end else if Code='@tablelines' then begin
      S:=FormulaEditor.CurrentTableSource; if S='' then begin StatusText:='Click a table cell to edit its lines.'; Exit; end;
      Model:=TTeXTable.Create;
      try
        if not Model.Load(S) then Exit; LinesDialog:=TTableLinesDialog.Create(Self);
        try LinesDialog.Load(Model); if LinesDialog.ShowModal=mrOK then begin S:=Model.Source(Offset,0,0); FormulaEditor.ReplaceTable(S,-1,-1); end;
        finally LinesDialog.Free; end;
      finally Model.Free; end;
    end else if (Code='@diagramedit') or (Code='@diagraminsert') then begin
      if Code='@diagraminsert' then begin
        if FormulaEditor.MathActive then begin StatusText:='Place the caret outside an equation to insert a drawing.'; Exit; end;
        S:='\begin{tikzpicture}'+LineEnding+LineEnding+'\end{tikzpicture}';
      end else begin
        S:=FormulaEditor.CurrentDiagramSource;
        if S='' then begin StatusText:='Click a TikZ picture to edit its drawing elements.'; Exit; end;
      end;
      DiagramDialog:=TDiagramForm.Create(Self);
      try
        if Code='@diagraminsert' then DiagramDialog.Caption:='Insert TikZ / PGFPlots';
        DiagramDialog.Load(Document.Preamble,S,DocumentDirectory,Engine.Text,Editor.Font);
        if DiagramDialog.ShowModal=mrOK then begin
          S:=DiagramDialog.Source;
          Directory:=DiagramPackage(S); if DiagramNeedsPlots(S) then Directory:='pgfplots';
          RequirePackage(Directory);
          if Code='@diagraminsert' then FormulaEditor.InsertBody(S,Length('\begin{tikzpicture}')+Length(LineEnding))
          else FormulaEditor.ReplaceDiagram(S);
        end;
      finally DiagramDialog.Free; end;
    end else if (Code='@figureinsert') or (Code='@figureedit') then begin
      if (Code='@figureedit') and (Pos('\includepdf',FormulaEditor.CurrentFigureSource)=1) then begin ObjectTool('@pdfedit'); Exit; end;
      if (Code='@figureinsert') and FormulaEditor.MathActive then begin StatusText:='Place the caret outside an equation to insert an image.'; Exit; end;
      if FileName='' then Directory:=GetCurrentDir else Directory:=ExtractFileDir(FileName);
      FigureDialog:=TFigureDialog.Create(Self);
      try
        FigureDialog.Directory:=Directory;
        if Code='@figureedit' then begin
          S:=FormulaEditor.CurrentFigureSource; if S='' then begin StatusText:='Click a figure to edit the image settings.'; Exit; end;
          FigureDialog.Caption:='Edit figure image';
          if Pos('\begin{figure',FormulaEditor.CurrentFloatSource)=1 then FigureDialog.Load(FormulaEditor.CurrentFloatSource,S)
          else FigureDialog.Load(S);
        end else if Pos('\begin{figure',FormulaEditor.CurrentFloatSource)=1 then
          FigureDialog.Load(FormulaEditor.CurrentFloatSource,'',True);
        if FigureDialog.ShowModal=mrOK then begin
          if Pos('graphicx',Document.Preamble)=0 then begin
            RecordVisualEdit; I:=Pos('\begin{document}',Document.Preamble); if I=0 then I:=Length(Document.Preamble)+1;
            Insert('\usepackage{graphicx}'+LineEnding,Document.Preamble,I);
            FormulaEditor.SetContext(Document.Preamble,Directory,Engine.Text,'',False);
          end;
          if (Code='@figureedit') or (Pos('\begin{figure',FormulaEditor.CurrentFloatSource)=1) then begin
            if Pos('\begin{figure',FormulaEditor.CurrentFloatSource)=1 then FormulaEditor.ReplaceFloat(FigureDialog.Source)
            else FormulaEditor.ReplaceFigure(FigureDialog.Source);
          end
          else begin S:=FigureDialog.Source; Caret:=Pos('\includegraphics',S)-1; FormulaEditor.InsertBody(S,Caret); end;
        end;
      finally FigureDialog.Free; end;
    end else if Code='@floatcaption' then begin
      S:=FormulaEditor.CurrentFloatSource; if S='' then begin StatusText:='Click inside a table or figure float to edit its caption.'; Exit; end;
      FloatDialog:=TFloatDialog.Create(Self);
      try FloatDialog.Load(S); if FloatDialog.ShowModal=mrOK then FormulaEditor.ReplaceFloat(FloatDialog.Source);
      finally FloatDialog.Free; end;
    end else if Code='@theoremmanager' then begin
      TheoremDialog:=TTheoremDialog.Create(Self);
      try
        TheoremDialog.Load(Document.Preamble);
        if TheoremDialog.ShowModal=mrOK then begin
          S:=TheoremDialog.Preamble; if S=Document.Preamble then Exit;
          Caret:=FormulaEditor.SourceCaret; RecordVisualEdit; Document.Preamble:=S;
          Modified:=True; LoadEquation; FormulaEditor.SetSourceCaret(Caret); RefreshParagraphStyles(nil); UpdateTitle; QueuePreview; SyncFullSource;
        end;
      finally TheoremDialog.Free; end;
    end else Result:=False;
  finally SetPreviewScroll(Scroll,Scroll.HorzScrollBar.Position,SavedScroll); end;
end;
