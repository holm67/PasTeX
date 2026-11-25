unit FormulaRender;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils;
function FormulaDocument(const Preamble, Formula, Environment: string; DisplayMath, Instrumented:Boolean; Paragraph:Boolean=False):string;
function ParagraphDocument(const Preamble:string; Blocks:TStrings; ActiveIndex:Integer;
  const EditedSource:string; Instrumented:Boolean; const BeforeBody:string=''; const AfterBody:string=''):string;
implementation
uses Math, MathModel, ParagraphModel, TeXMacros, TeXEditing, TeXTables, TeXDocumentMetrics, TeXSectioning;
function ParagraphStart(const Source:string; CTeX:Boolean):string;
var P:Integer; Name:string;
begin
  Result:='\parindent=0pt\relax ';
  P:=1; SkipTeXSpace(Source,P); Name:=ReadTeXCommand(Source,P);
  { Heading formats may use parindent for their own left offset. Preserve it
    even when ordinary Latin paragraph cards omit first-line indentation. }
  if CTeX or (SectionIndex(Name)>=0) then
    Result:='\parindent=\PasTeXParagraphIndent\relax ';
  { Keep a short last line at the document's column width. This invisible
    vertical rule neither starts a paragraph nor adds vertical space. }
  Result:=Result+'\hrule width\linewidth height0pt depth0pt\relax ';
end;
function PreviewHeader(const Preamble:string; Instrumented:Boolean):string;
var P:Integer;
begin
  Result:=TrimRight(Preamble); P:=Length(Result)-Length('\begin{document}')+1;
  if (P>0) and (Copy(Result,P,MaxInt)='\begin{document}') then Delete(Result,P,MaxInt);
  if Pos('\documentclass',Result)=0 then Result:='\documentclass{article}'+LineEnding+'\usepackage{amsmath,amssymb}'+LineEnding+Result;
  Result:=Result+LineEnding+'\usepackage[active,tightpage]{preview}'+LineEnding+
    '\setlength\PreviewBorder{6pt}'+LineEnding+
    { preview.sty invokes arrayparboxrestore, which resets parindent. Save
      the document value before entering the preview environment. }
    '\newlength\PasTeXParagraphIndent'+LineEnding+
    '\AtBeginDocument{\PasTeXParagraphIndent=\parindent}'+LineEnding;
  { Paragraph previews place float contents where they occur in the source.
    Real float scheduling cannot run inside preview's boxed paragraph pages. }
  Result:=Result+'\makeatletter'+LineEnding+
    { Inserts cannot escape preview.sty's vbox. Collect notes locally using
      the class's own footnote typography, then include them in the card. }
    '\newbox\PasTeXFootnotes'+LineEnding+
    '\def\PasTeXNotesBegin{\global\setbox\PasTeXFootnotes\box\voidb@x%'+LineEnding+
    '\long\def\@footnotetext##1{\global\setbox\PasTeXFootnotes\vbox{\unvbox\PasTeXFootnotes%'+LineEnding+
    '\reset@font\footnotesize\hsize\columnwidth\@parboxrestore%'+LineEnding+
    '\def\@currentcounter{footnote}\protected@edef\@currentlabel{\csname p@footnote\endcsname\@thefnmark}%'+LineEnding+
    '\color@begingroup\@makefntext{\rule\z@\footnotesep\ignorespaces##1\@finalstrut\strutbox}\par\color@endgroup}}%'+LineEnding+
    '\def\marginpar{\@ifnextchar[\PasTeXMarginOption{\PasTeXMarginOption[]}}}%'+LineEnding+
    '\long\def\PasTeXMarginOption[#1]#2{\leavevmode\vadjust{\nobreak\hbox{\kern\dimexpr\linewidth+\marginparsep\relax%'+LineEnding+
    '\vtop{\hsize\marginparwidth\@parboxrestore\normalfont\normalsize\ignorespaces#2\par}}}}%'+LineEnding+
    '\def\PasTeXNotesEnd{\ifvoid\PasTeXFootnotes\else\par\vskip\skip\footins\footnoterule\unvbox\PasTeXFootnotes\fi}'+LineEnding+
    '\def\PasTeXExportMacro#1{\global\let#1#1}'+LineEnding+
    '\def\PasTeXExportReferences{'+
      '\global\let\@currentlabel\@currentlabel'+
      '\global\let\@currentlabelname\@currentlabelname'+
      '\global\let\@currentcounter\@currentcounter'+
      '\global\let\@currentHref\@currentHref}'+LineEnding+
    '\newif\ifPasTeXAfterFloat'+LineEnding+
    '\@ifundefined{AddToHook}{\everypar\expandafter{\the\everypar\global\PasTeXAfterFloatfalse}}'+
      '{\AddToHook{para/begin}{\global\PasTeXAfterFloatfalse}}'+LineEnding+
    '\def\PasTeXFloatStart#1{\par\global\PasTeXAfterFloatfalse\begingroup\def\@captype{#1}}'+LineEnding+
    '\def\PasTeXFloatEnd{\par\endgroup\global\PasTeXAfterFloattrue}'+LineEnding+
    '\@ifundefined{table}{}{\renewenvironment{table}[1][]{\PasTeXFloatStart{table}}{\PasTeXFloatEnd}}'+LineEnding+
    '\@ifundefined{figure}{}{\renewenvironment{figure}[1][]{\PasTeXFloatStart{figure}}{\PasTeXFloatEnd}}'+LineEnding+
    '\@ifundefined{table*}{}{\renewenvironment{table*}[1][]{\PasTeXFloatStart{table}}{\PasTeXFloatEnd}}'+LineEnding+
    '\@ifundefined{figure*}{}{\renewenvironment{figure*}[1][]{\PasTeXFloatStart{figure}}{\PasTeXFloatEnd}}'+LineEnding+
    { The source-order float already ends its line. Ignore another forced
      break while still in vertical mode just after it. Preserve each original
      command, including optional arguments and table-local definitions. }
    '\let\PasTeXOriginalNewline\newline\let\PasTeXOriginalBreak\\\let\PasTeXOriginalLinebreak\linebreak'+LineEnding+
    '\def\PasTeXSkipBreak{\@ifstar\PasTeXSkipBreak{\@ifnextchar[\PasTeXSkipBreakOption{}}}'+LineEnding+
    '\def\PasTeXSkipBreakOption[#1]{}'+LineEnding+
    '\def\PasTeXChooseBreak#1#2{\let\PasTeXBreakNext#1\ifvmode\ifPasTeXAfterFloat\let\PasTeXBreakNext#2\fi'+
      '\else\global\PasTeXAfterFloatfalse\fi\PasTeXBreakNext}'+LineEnding+
    '\protected\def\newline{\PasTeXChooseBreak\PasTeXOriginalNewline\relax}'+LineEnding+
    '\protected\def\\{\PasTeXChooseBreak\PasTeXOriginalBreak\PasTeXSkipBreak}'+LineEnding+
    '\protected\def\linebreak{\PasTeXChooseBreak\PasTeXOriginalLinebreak\PasTeXSkipBreak}'+LineEnding+
    { PGF's modern shipout hook freezes resource-box offsets before preview
      changes hoffset. XeTeX then clips shifted shading XObjects. Normalize
      resource creation and compensate at shipout, only for that PGF code. }
    '\ifdefined\XeTeXversion'+LineEnding+
    '\AtBeginDocument{\@ifundefined{pgfutil@abb}{}{\@ifundefined{AddToHook}{}{'+LineEnding+
    '\edef\PasTeXPGFCheck{\noexpand\in@{\detokenize{2in-2\hoffset}}{\meaning\pgfutil@insertatbegincurrentpagefrombox}}%'+LineEnding+
    '\PasTeXPGFCheck\ifin@'+LineEnding+
    '\let\PasTeXPGFInsert\pgfutil@insertatbegincurrentpagefrombox'+LineEnding+
    '\def\pgfutil@insertatbegincurrentpagefrombox#1{\begingroup\hoffset=0pt\relax\PasTeXPGFInsert{#1}\endgroup}%'+LineEnding+
    '\AddToHook{shipout/before}{\ifvoid\pgfutil@abb\else\setbox\pgfutil@abb\hbox{\kern-2\hoffset\box\pgfutil@abb}\fi}%'+LineEnding+
    '\fi}}}'+LineEnding+'\fi'+LineEnding+
    { pdfpages normally ships a separate paper sheet, outside preview.sty's
      paragraph box. Keep its page-list parser, but place the selected pages
      inside this one preview card so following cards retain their indices. }
    '\@ifpackageloaded{pdfpages}{%'+LineEnding+
    '\newlength\PasTeXPDFHeight\newlength\PasTeXPDFWidth'+LineEnding+
    '\newlength\PasTeXPaperHeight\newlength\PasTeXPaperWidth'+LineEnding+
    { XeTeX's tight-page driver overwrites paperheight at every shipout.
      Retain the real sheet size before any paragraph preview is shipped. }
    '\AtBeginDocument{\global\PasTeXPaperWidth=\paperwidth\global\PasTeXPaperHeight=\paperheight}%'+LineEnding+
    '\renewcommand\AM@output[1]{\par\begingroup%'+LineEnding+
    '\AM@split@options{Gin@noscale}{#1}\edef\PasTeXPDFScale{\AM@scale@factor}%'+LineEnding+
    '\setlength\PasTeXPDFWidth{\PasTeXPaperWidth}\setlength\PasTeXPDFHeight{\PasTeXPaperHeight}%'+LineEnding+
    '\ifAM@landscape\setlength\PasTeXPDFWidth{\PasTeXPaperHeight}\setlength\PasTeXPDFHeight{\PasTeXPaperWidth}\fi%'+LineEnding+
    '\def\PasTeXPDFNext{\ifx\AM@pagelist\@empty\else%'+LineEnding+
    '\AM@getfirst{\AM@pagelist}\edef\PasTeXPDFPage{\the\toks@}%'+LineEnding+
    '\AM@getfirst{\AM@doclist}\edef\PasTeXPDFFile{\the\toks@}%'+LineEnding+
    '\ifAM@fitpaper\ifx\PasTeXPDFPage\@empty\else%'+LineEnding+
    '\setbox\z@\hbox{\includegraphics[page=\PasTeXPDFPage]{\PasTeXPDFFile}}%'+LineEnding+
    '\setlength\PasTeXPDFWidth{\wd\z@}\setlength\PasTeXPDFHeight{\ht\z@+\dp\z@}\fi\fi%'+LineEnding+
    { The line box must be as wide as the sheet. Otherwise preview.sty
      crops a paper-wide graphic to textwidth, leaving its center at right. }
    '\hsize=\PasTeXPDFWidth\linewidth=\hsize\parindent=0pt\leftskip=0pt\rightskip=0pt%'+LineEnding+
    '\noindent\hbox to\PasTeXPDFWidth{\hfil\vbox to\PasTeXPDFHeight{\vfil%'+LineEnding+
    '\ifx\PasTeXPDFPage\@empty\else%'+LineEnding+
    '\hbox{\ifAM@noautoscale\scalebox{\PasTeXPDFScale}{\includegraphics[page=\PasTeXPDFPage]{\PasTeXPDFFile}}%'+LineEnding+
    '\else\scalebox{\PasTeXPDFScale}{\includegraphics[page=\PasTeXPDFPage,width=\PasTeXPDFWidth,height=\PasTeXPDFHeight,keepaspectratio]{\PasTeXPDFFile}}\fi}\fi%'+LineEnding+
    '\vfil}\hfil}\par\ifx\AM@pagelist\@empty\else\vskip6pt\fi%'+LineEnding+
    '\expandafter\PasTeXPDFNext\fi}\PasTeXPDFNext\endgroup}%'+LineEnding+
    '}{}%'+LineEnding+
    '\makeatother'+LineEnding;
  { Suppress TeX end-of-line spaces inside marker definitions. Even a zero-width
    marker must not add glue: that changes justification and hyphenation. }
  if Instrumented then
    Result:=Result+
      '\makeatletter'+'%'+LineEnding+
      '\ifdefined\pdfsavepos\else'+'%'+LineEnding+
      '\let\pdfsavepos\savepos\let\pdflastxpos\lastxpos\let\pdflastypos\lastypos\fi'+'%'+LineEnding+
      '\def\PasTeXBlock{1}%' +LineEnding+
      '\newwrite\PasTeXPositions'+'%'+LineEnding+
      '\immediate\openout\PasTeXPositions=\jobname.pstpos'+'%'+LineEnding+
      '\long\def\PasTeXBox#1#2#3{\begingroup'+'%'+LineEnding+
      '\setbox0=\hbox{$\m@th#1#3$}'+'%'+LineEnding+
      '\edef\PasTeXWrite{\noexpand\write\PasTeXPositions{\PasTeXBlock|#2|'+
      '\noexpand\the\pdflastxpos|\noexpand\the\pdflastypos|'+
      '\number\wd0|\number\ht0|\number\dp0}}'+'%'+LineEnding+
      '\hbox{\pdfsavepos\PasTeXWrite\box0}\endgroup}'+'%'+LineEnding+
      '\long\def\PasTeXOperatorPosition#1#2#3{\begingroup%' +LineEnding+
      '\setbox0=\hbox{$\m@th#1#3$}%' +LineEnding+
      '\edef\PasTeXWrite{\noexpand\write\PasTeXPositions{\PasTeXBlock|#2|'+
      '\noexpand\the\pdflastxpos|\noexpand\the\pdflastypos|'+
      '\number\wd0|\number\ht0|\number\dp0}}%' +LineEnding+
      '\pdfsavepos\PasTeXWrite\endgroup}%' +LineEnding+
      '\long\def\PasTeXOperator#1#2{\mathchoice'+
      '{\PasTeXOperatorPosition\displaystyle{#1}{#2}}'+
      '{\PasTeXOperatorPosition\textstyle{#1}{#2}}'+
      '{\PasTeXOperatorPosition\scriptstyle{#1}{#2}}'+
      '{\PasTeXOperatorPosition\scriptscriptstyle{#1}{#2}}#2}%' +LineEnding+
      '\long\def\PasTeXField#1#2{\mathchoice'+'%'+LineEnding+
      '{\PasTeXBox\displaystyle{#1}{#2}}{\PasTeXBox\textstyle{#1}{#2}}'+'%'+LineEnding+
      '{\PasTeXBox\scriptstyle{#1}{#2}}{\PasTeXBox\scriptscriptstyle{#1}{#2}}}'+'%'+LineEnding+
      '\protected\def\PasTeXTextPosition#1#2{\pdfsavepos\begingroup'+'%'+LineEnding+
      '\edef\PasTeXWrite{\noexpand\write\PasTeXPositions{\PasTeXBlock|#1|#2|'+
      '\noexpand\the\pdflastxpos|\noexpand\the\pdflastypos|'+
      '\number\ht\strutbox|\number\dp\strutbox}}'+'%'+LineEnding+
      '\PasTeXWrite\endgroup}'+'%'+LineEnding+
      '\protected\long\def\PasTeXTextField#1#2{\leavevmode'+
      '\PasTeXTextPosition{#1}{S}#2\PasTeXTextPosition{#1}{E}}'+'%'+LineEnding+
      '\makeatother'+'%'+LineEnding;
end;
function ExportParagraphMacros(const Source:string):string;
var P,A,Depth:Integer; Name,Command:string; Delimiter:Char;
  procedure ExportName(const Name:string);
  begin
    Result:=Result+'\ifcsname '+Name+'\endcsname'+
      '\expandafter\PasTeXExportMacro\csname '+Name+'\endcsname\fi%'+LineEnding;
  end;
begin
  Result:=''; P:=1; Depth:=0;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and not (Source[P] in [#10,#13]) do Inc(P); Continue; end;
    if Source[P]='{' then Inc(Depth) else if Source[P]='}' then Depth:=Max(0,Depth-1);
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    A:=P;
    if ReadTeXDefinition(Source,P) then begin
      if Depth<>0 then Continue;
      Name:=TeXDefinitionName(Copy(Source,A,P-A));
    end else begin
      P:=A; Command:=ReadTeXCommand(Source,P);
      if Command='begin' then begin
        Command:=ReadTeXGroup(Source,P,'{','}');
        P:=EnvironmentEnd(Source,A,Command);
        if P<=Length(Source) then begin ReadTeXCommand(Source,P); ReadTeXGroup(Source,P,'{','}'); end;
      end else if (Command='verb') or (Command='Verb') then begin
        if Copy(Source,P,1)='*' then Inc(P);
        if P<=Length(Source) then begin
          Delimiter:=Source[P]; Inc(P);
          while (P<=Length(Source)) and (Source[P]<>Delimiter) and not (Source[P] in [#10,#13]) do Inc(P);
          if (P<=Length(Source)) and (Source[P]=Delimiter) then Inc(P);
        end;
      end;
      Continue;
    end;
    if Name='' then Continue;
    { Copy the frozen definition out of preview's extra group. LaTeX stores
      optional/robust and xparse bodies in these companion control sequences. }
    ExportName(Name); ExportName('\string\'+Name); ExportName(Name+' ');
    ExportName(Name+' code'); ExportName(Name+' defaults');
  end;
end;
function ParagraphDocument(const Preamble:string; Blocks:TStrings; ActiveIndex:Integer;
  const EditedSource:string; Instrumented:Boolean; const BeforeBody:string; const AfterBody:string):string;
var I,N,At:Integer; S,Context,Body,MacroExports:string; Root:TMathNode; Registry:TMacroRegistry;
    Buffer:TMemoryStream; CTeX:Boolean;
  procedure Append(const Value:string);
  begin if Value<>'' then Buffer.WriteBuffer(Value[1],Length(Value)); end;
begin
  Registry:=nil; if Instrumented then Registry:=TMacroRegistry.Create;
  Context:=Preamble+BeforeBody; Buffer:=TMemoryStream.Create; CTeX:=DocumentUsesCTeX(Preamble);
  try
  N:=0;
  for I:=0 to Blocks.Count-1 do if I=ActiveIndex then Inc(N,Length(EditedSource)) else Inc(N,Length(Blocks[I]));
  SetLength(Body,N); At:=1;
  for I:=0 to Blocks.Count-1 do begin
    if I=ActiveIndex then S:=EditedSource else S:=Blocks[I];
    if S<>'' then Move(S[1],Body[At],Length(S)); Inc(At,Length(S));
  end;
  Append(PreviewHeader(SyncCitationPackages(Preamble,BeforeBody+Body+AfterBody),Instrumented)+'\begin{document}'+LineEnding+BeforeBody+LineEnding);
  for I:=0 to Blocks.Count-1 do
  begin
    if I=ActiveIndex then S:=EditedSource else S:=Blocks[I];
    MacroExports:=ExportParagraphMacros(S);
    if Instrumented then begin
      Root:=nil;
      try
      try
        Registry.Load(Context,GetCurrentDir); Root:=ParseParagraph(S,Registry);
        if I<>ActiveIndex then S:=InstrumentParagraph(Root);
      except end;
      finally Root.Free; end;
      if I=ActiveIndex then Context:=Context+EditedSource else Context:=Context+Blocks[I];
    end;
    if Instrumented then Append('\def\PasTeXBlock{'+IntToStr(I+1)+'}%'+LineEnding);
    { Keep vertical mode until the source starts its own paragraph. A strut
      before a heading enters horizontal mode and breaks titlesec/ctex. }
    Append('\begin{preview}\PasTeXNotesBegin'+LineEnding+ParagraphStart(S,CTeX)+S+LineEnding+
      MacroExports+'\PasTeXExportReferences\PasTeXNotesEnd%'+LineEnding+'\end{preview}'+LineEnding);
  end;
  Append(AfterBody+LineEnding+'\end{document}'+LineEnding);
  SetLength(Result,Buffer.Size); if Result<>'' then Move(Buffer.Memory^,Result[1],Length(Result));
  finally Buffer.Free; Registry.Free; end;
end;
function FormulaDocument(const Preamble,Formula,Environment:string; DisplayMath,Instrumented:Boolean; Paragraph:Boolean):string;
var OpenMath,CloseMath:string;
begin
  Result:=PreviewHeader(SyncCitationPackages(Preamble,Formula),Instrumented);
  OpenMath:='$'; CloseMath:='$';
  if Environment<>'' then
  begin OpenMath:='\begin{'+Environment+'}'; CloseMath:='\end{'+Environment+'}'; end
  else if DisplayMath then begin OpenMath:='\['; CloseMath:='\]'; end;
  if Paragraph then begin OpenMath:=ParagraphStart(Formula,DocumentUsesCTeX(Preamble)); CloseMath:=''; end;
  Result:=Result+'\begin{document}'+LineEnding+'\begin{preview}\PasTeXNotesBegin'+LineEnding+
    OpenMath+Formula+CloseMath+LineEnding+'\PasTeXNotesEnd\end{preview}'+LineEnding+'\end{document}'+LineEnding;
end;
end.
