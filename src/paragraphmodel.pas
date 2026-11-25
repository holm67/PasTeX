unit ParagraphModel;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Math, MathModel, TeXMacros, TeXTables;
function ParseParagraph(const Source:string; Macros:TMacroRegistry):TMathNode;
function ParseParagraphSource(const Source:string; Macros:TMacroRegistry; First,Last:Integer):TMathNode;
function ParsePreambleCode(const Source:string; Macros:TMacroRegistry):TMathNode;
function InstrumentParagraph(Node:TMathNode):string;
function IsVerbatimField(Node:TMathNode):Boolean;
function IsDefinitionField(Node:TMathNode):Boolean;
function IsCodeField(Node:TMathNode):Boolean;
function HasCodeObjects(Node:TMathNode):Boolean;
function HasMacroDefinitions(Node:TMathNode):Boolean;
function IsMathField(Node:TMathNode):Boolean;
function IsProseGroup(Node:TMathNode):Boolean;
function IsSourcePreviewNode(Node:TMathNode):Boolean;
function IsLabelField(Node:TMathNode):Boolean;
function ProseFormatName(Node:TMathNode):string;
function ParagraphStyleName(Node:TMathNode; Registry:TMacroRegistry):string;
function DefinitionPreviewSource(const Text:string; Registry:TMacroRegistry=nil):string;
procedure PrepareDefinitionBodies(Root:TMathNode; Registry:TMacroRegistry);
implementation
uses TeXBibliography, TeXTextStyle, TeXFontData, TeXUnicode, TeXPackagePreview, CommandDefinition, TikZModel, TeXDocument, MathSpacing, BeamerModel;
function ParseParagraphSource(const Source:string; Macros:TMacroRegistry; First,Last:Integer):TMathNode;
var Marker,Code:string; Point:Cardinal; Restored:Boolean;
  procedure Restore(Node:TMathNode);
  var I,P:Integer; Before,After:string; Kind:TMathKind; Box:TMathNode;
  begin
    P:=Pos(Marker,Node.Text);
    if (P>0) and (Node.Kind in [mkText,mkProse]) then begin
      Kind:=Node.Kind; Before:=Copy(Node.Text,1,P-1); After:=Copy(Node.Text,P+Length(Marker),MaxInt);
      Node.Kind:=mkRow; Node.Text:=''; Node.Children.Clear;
      if Before<>'' then Node.Add(TMathNode.Create(Kind,Before));
      Box:=Node.Add(TMathNode.Create(mkUnknownCommand)); Box.SourceEditing:=True;
      Box.Add(TMathNode.Create(mkProse,Code));
      if After<>'' then Node.Add(TMathNode.Create(Kind,After));
      Restored:=True; Exit;
    end;
    for I:=0 to Node.Children.Count-1 do Restore(TMathNode(Node.Children[I]));
  end;
begin
  { Parse the surrounding structure once. Selected code stays opaque even
    while its braces or environment names are incomplete. }
  Point:=$E000;
  repeat Marker:=UTF8Encode(UnicodeString(WideChar(Point))); Inc(Point); until Pos(Marker,Source)=0;
  Code:=Copy(Source,First+1,Last-First); Restored:=False;
  Result:=ParseParagraph(Copy(Source,1,First)+Marker+Copy(Source,Last+1,MaxInt),Macros);
  try
    Restore(Result);
    if not Restored or (Result.TeX<>Source) then raise Exception.Create('Invalid source selection');
  except Result.Free; raise; end;
end;
function ParsePreambleCode(const Source:string; Macros:TMacroRegistry):TMathNode;
var P,Q,First:Integer; Command,Name,Ending:string; Delimiter:Char;
  procedure CodeUntil(Finish:Integer);
  begin
    if Finish<=First then Exit;
    if Trim(Copy(Source,First,Finish-First))='' then Result.Add(TMathNode.Create(mkProse,Copy(Source,First,Finish-First)))
    else Result.Add(TMathNode.Create(mkUnknownCommand)).Add(TMathNode.Create(mkProse,Copy(Source,First,Finish-First)));
  end;
begin
  Result:=TMathNode.Create(mkRow); P:=1; First:=1;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and not (Source[P] in [#10,#13]) do Inc(P); Continue; end;
    if Source[P]='{' then begin ReadTeXGroup(Source,P,'{','}'); Continue; end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P;
    if ReadTeXDefinition(Source,Q) then begin
      CodeUntil(P); Result.Add(DefinitionNode(Copy(Source,P,Q-P))); P:=Q; First:=P;
    end else begin
      Command:=ReadTeXCommand(Source,P);
      if (Command='verb') or (Command='Verb') then begin
        if Copy(Source,P,1)='*' then Inc(P);
        if P<=Length(Source) then begin
          Delimiter:=Source[P]; Inc(P); while (P<=Length(Source)) and (Source[P]<>Delimiter) do Inc(P); Inc(P);
        end;
      end else if Command='begin' then begin
        Name:=ReadTeXGroup(Source,P,'{','}');
        if IsTeXVerbatimEnvironment(Name) then begin
          Ending:='\end{'+Name+'}'; P:=Min(Length(Source)+1,EnvironmentEnd(Source,P,Name)+Length(Ending));
        end;
      end;
    end;
  end;
  CodeUntil(P); PrepareDefinitionBodies(Result,Macros);
end;
function DefinitionPreviewSource(const Text:string; Registry:TMacroRegistry):string;
  function MathContent(const Source:string; Depth:Integer):Boolean;
  var P,A,Count,Slot:Integer; Command,Family,WordText:string; Info:TMacroInfo;
      HasMath,HasProse,HasAtom,Native:Boolean; Delimiter:Char;
  begin
    HasMath:=False; HasProse:=False; HasAtom:=False; P:=1;
    while P<=Length(Source) do begin
      SkipTeXSpace(Source,P); if P>Length(Source) then Break;
      if Source[P]='\' then begin
        Command:=ReadTeXCommand(Source,P);
        if (Command='begin') or (Command='end') then begin
          Family:=ReadTeXGroup(Source,P,'{','}');
          Native:=(Pos('matrix',Family)>0) or (Family='array') or (Family='cases') or
            (Family='aligned') or (Family='alignedat') or (Family='gathered') or (Family='split');
          HasMath:=HasMath or Native; HasProse:=HasProse or not Native; Continue;
        end;
        if (Command='verb') or (Command='Verb') then begin
          HasProse:=True; if Copy(Source,P,1)='*' then Inc(P);
          if P<=Length(Source) then begin
            Delimiter:=Source[P]; Inc(P);
            while (P<=Length(Source)) and (Source[P]<>Delimiter) do Inc(P); Inc(P);
          end;
          Continue;
        end;
        Native:=not IsTextStyleSwitch(Command) and not IsCitationCommand(Command) and not IsLabelReference(Command) and
          ((Command='text') or (Copy(Command,1,4)<>'text')) and (Command<>'emph') and
          (Command<>'underline') and (Command<>'label') and (Command<>'space') and (Length(Command)>1) and
          ((MathArgumentCount(Command)>=0) or TeXSymbol('\'+Command,Family,Slot) or
           (Command='left') or (Command='right') or (Command='middle') or (Copy(Command,1,3)='big'));
        Info:=nil; if Registry<>nil then Info:=Registry.Find(Command);
        if not Native and (Info<>nil) and Info.Expandable and (Depth<8) then Native:=MathContent(Info.Body,Depth+1);
        HasMath:=HasMath or Native;
        if not Native and (Info<>nil) and Info.Expandable and not IsTextStyleSwitch(Command) then HasProse:=True;
        if not Native and ((Copy(Command,1,4)='text') or (Command='emph') or (Command='underline') or
           (Command='LaTeX') or (Command='TeX') or IsCitationCommand(Command) or IsLabelReference(Command)) then HasProse:=True;
        if Native or HasProse then begin
          SkipTeXSpace(Source,P); if Copy(Source,P,1)='[' then ReadTeXGroup(Source,P,'[',']');
          SkipTeXSpace(Source,P); while Copy(Source,P,1)='{' do begin ReadTeXGroup(Source,P,'{','}'); SkipTeXSpace(Source,P); end;
        end;
        Continue;
      end;
      if (Source[P]='#') and (P<Length(Source)) and (Source[P+1] in ['1'..'9']) then begin Inc(P,2); Continue; end;
      if Source[P] in ['a'..'z','A'..'Z'] then begin
        A:=P; Count:=0;
        while (P<=Length(Source)) and (Source[P] in ['a'..'z','A'..'Z']) do begin
          if Source[P] in ['a'..'z'] then Inc(Count); Inc(P);
        end;
        WordText:=Copy(Source,A,P-A); HasAtom:=True;
        if (Length(WordText)>2) and (Count>1) then HasProse:=True;
        Continue;
      end;
      if Source[P] in ['^','_','+','-','=','<','>','/','*','(',')','[',']'] then HasMath:=True
      else if Source[P] in ['0'..'9'] then HasAtom:=True
      else if (Ord(Source[P])>=128) or (Source[P]='$') then HasProse:=True;
      Inc(P);
    end;
    Result:=(HasMath or HasAtom) and not HasProse;
  end;
begin
  Result:=Text;
  if (Length(FindMath(Text))=0) and MathContent(Text,0) then Result:='$'+Text+'$';
end;
procedure PrepareDefinitionBodies(Root:TMathNode; Registry:TMacroRegistry);
var I:Integer; Field,Body,Formula:TMathNode; Text,Error:string; Definition:TCommandDefinition;
begin
  if (Root.Kind=mkDefinition) and (Root.Children.Count=2) then begin
    Field:=TMathNode(Root.Children[1]);
    if Field.Kind=mkProse then begin
      Text:=Field.Text; Body:=nil;
      if ReadCommandDefinition(Root.TeX,Definition) and (Definition.Command='DeclareMathOperator') then
        Body:=ParseParagraph(Text,Registry)
      else if DefinitionPreviewSource(Text,Registry)<>Text then begin
        Formula:=TMathNode.Create(mkFormula);
        if ParseMath(Text,Body,Error,Registry,True,@ParseParagraph) then Formula.Add(Body)
        else Formula.Add(TMathNode.Create(mkText,Text));
        Body:=Formula;
      end else Body:=ParseParagraph(Text,Registry);
      Field.Kind:=mkRow; Field.Text:=''; Field.Add(Body);
    end;
  end;
  for I:=0 to Root.Children.Count-1 do PrepareDefinitionBodies(TMathNode(Root.Children[I]),Registry);
end;
function ParagraphStyleName(Node:TMathNode; Registry:TMacroRegistry):string;
var P:Integer; Command:string;
begin
  Result:='@heading:';
  while Node<>nil do begin
    P:=1; Command:=ReadTeXCommand(Node.Prefix,P);
    if (Command='part') or (Command='chapter') or (Command='section') or
      (Command='subsection') or (Command='subsubsection') or (Command='paragraph') or (Command='subparagraph') then begin
      Result:='@heading:\'+Command; if Copy(Node.Prefix,P,1)='*' then Result:=Result+'*'; Exit;
    end;
    if (Node.Kind=mkEnvironment) and ((Node.Text='proof') or ((Registry<>nil) and Registry.IsTheorem(Node.Text))) then Exit('@theorem:'+Node.Text);
    Node:=Node.Parent;
  end;
end;
function IsCodeField(Node:TMathNode):Boolean;
var Child:TMathNode;
begin
  Result:=False; Child:=nil;
  while Node<>nil do begin
    if Node.Kind in [mkUnknownCommand,mkComment] then Exit(True);
    if Node.Kind=mkDefinition then begin
      if (Node.Children.Count<>2) or (Child=TMathNode(Node.Children[0])) or
        (TMathNode(Node.Children[1]).Kind=mkProse) then Exit(True);
    end;
    Child:=Node;
    Node:=Node.Parent;
  end;
end;
function HasCodeObjects(Node:TMathNode):Boolean;
var I:Integer;
begin
  if Node.Kind in [mkDefinition,mkUnknownCommand,mkComment] then Exit(True);
  for I:=0 to Node.Children.Count-1 do if HasCodeObjects(TMathNode(Node.Children[I])) then Exit(True);
  Result:=False;
end;
function IsDefinitionField(Node:TMathNode):Boolean;
begin
  while Node<>nil do begin
    if Node.Kind=mkDefinition then Exit(True);
    Node:=Node.Parent;
  end;
  Result:=False;
end;
function HasMacroDefinitions(Node:TMathNode):Boolean;
var I:Integer;
begin
  if Node.Kind=mkDefinition then Exit(True);
  for I:=0 to Node.Children.Count-1 do if HasMacroDefinitions(TMathNode(Node.Children[I])) then Exit(True);
  Result:=False;
end;
function IsLabelField(Node:TMathNode):Boolean;
begin
  while Node<>nil do begin
    if (Node.Kind=mkCommand) and (Node.Text='\label') then Exit(True);
    Node:=Node.Parent;
  end;
  Result:=False;
end;
function ProseFormatName(Node:TMathNode):string;
var P:Integer; Command:string;
begin
  Result:='';
  if (Node=nil) or (Node.Kind<>mkGroup) or IsMathField(Node) then Exit;
  if Copy(Node.Prefix,1,2)='{\' then begin
    P:=2; Command:=ReadTeXCommand(Node.Prefix,P);
    if IsTextStyleSwitch(Command) then Result:='\'+Command;
    Exit;
  end;
  P:=1; Command:=ReadTeXCommand(Node.Prefix,P);
  if (Command='textbf') or (Command='textit') or (Command='emph') or
     (Command='textrm') or (Command='textsf') or (Command='texttt') or
     (Command='textsc') or (Command='textsl') or (Command='textup') or (Command='textmd') or (Command='textnormal') or
     (Command='textcolor') or (Command='underline') then Result:='\'+Command;
end;
function IsVerbatimField(Node:TMathNode):Boolean;
begin
  while Node<>nil do begin
    if (Node.Kind=mkVerbatim) or ((Node.Kind=mkGroup) and
      ((Copy(Node.Prefix,1,5)='\verb') or (Copy(Node.Prefix,1,10)='\lstinline'))) then Exit(True);
    Node:=Node.Parent;
  end;
  Result:=False;
end;

function IsMathField(Node:TMathNode):Boolean;
begin
  Result:=False;
  while Node<>nil do
  begin
    if Node.TextMode then Exit(False);
    if Node.Kind=mkFormula then Exit(True);
    Node:=Node.Parent;
  end;
end;

function IsProseGroup(Node:TMathNode):Boolean;
begin
  Result:=(Node<>nil) and (Node.Kind=mkGroup) and (Node.Prefix='{') and
    ((Node.Parent=nil) or (Node.Parent.Kind=mkRow)) and not IsMathField(Node);
end;
function IsSourcePreviewNode(Node:TMathNode):Boolean;
var Parent:TMathNode;
begin
  Result:=False; if Node=nil then Exit;
  if Node.Kind in [mkFormula,mkSource] then Exit(True);
  if Node.Hidden or Node.SourceEditing or (Node.Kind=mkDiagram) then Exit;
  Parent:=Node.Parent;
  while Parent<>nil do begin
    if (Parent.Kind in [mkFormula,mkDiagram,mkSource]) or Parent.SourceEditing then Exit;
    Parent:=Parent.Parent;
  end;
  Result:=IsProseGroup(Node) or (Copy(Node.Prefix,1,1)='\') or
    (Node.Kind in [mkCommand,mkTextCommand,mkDefinition,mkUnknownCommand,mkVerbatim]);
end;

function ParseParagraph(const Source:string; Macros:TMacroRegistry):TMathNode;
var Spans:TMathSpans; Serial,Nesting,NextSpan,FrameDepth:Integer; Scope:TMacroRegistry; Scopes:TList; HasDefinitions,OwnScope:Boolean;
  function KnownTextCommand(const Name:string):Boolean;
  begin
    Result:=(Name='LaTeX') or (Name='TeX') or (Name='space') or (Name=' ') or
      (Name='textbackslash') or (Name='textbraceleft') or (Name='textbraceright') or
      (Name='textless') or (Name='textgreater') or
      (Name='textunderscore') or (Name='textasciicircum') or (Name='textasciitilde') or (Name='textbar') or
      IsLabelReference(Name) or (Name='verb') or (Name='lstinline') or
      (Name='includegraphics') or (Name='includepdf') or (Name='bibliography') or (Name='bibliographystyle') or
      (Name='setcounter') or (Name='centering') or (Name='raggedleft') or (Name='raggedright') or (Name='leavevmode') or
      (Name='footnote') or (Name='footnotetext') or (Name='footnotemark') or (Name='marginpar') or
      (Name='\') or (Name='newline') or (Name='par') or (Name='linebreak') or (Name='nolinebreak') or
      (Name='pagebreak') or (Name='nopagebreak') or (Name='newpage') or (Name='clearpage') or
      (Name='$') or (Name='%') or (Name='&') or (Name='#') or (Name='_') or (Name='{') or (Name='}') or
      IsCitationCommand(Name);
  end;

  function RenderedEnvironment(const Name:string):Boolean;
  begin
    Result:=FloatEnvironment(Name) or Scope.IsTheorem(Name) or
      (Name='adjustbox') or (Name='landscape') or (Name='abstract') or (Name='proof') or (Name='center') or (Name='flushleft') or (Name='flushright') or
      (Name='itemize') or (Name='enumerate') or (Name='description') or (Name='minipage') or (Name='tcolorbox') or
      (Scope.Presentation and BeamerEnvironment(Name));
  end;

  procedure Number(Node:TMathNode);
  var I:Integer;
  begin
    Node.ID:=Serial; Inc(Serial);
    for I:=0 to Node.Children.Count-1 do Number(TMathNode(Node.Children[I]));
  end;

  function Part(var P:Integer; Limit:Integer; Grouped:Boolean; const StopEnv:string=''; StopItem:Boolean=False; StopColumn:Boolean=False):TMathNode;
  var A,Q,I,J,K,Opening,Closing,MathStart,EndAt,CellEnd:Integer; Cmd,Env,Error:string;
      Node,MathRoot,Option,RowNode,CellNode:TMathNode; Editable,Structural:Boolean;
      Table:TTeXTable; TableRow:TTableRow; SavedScope,LocalScope:TMacroRegistry; Info:TMacroInfo; Count:Integer;
      Entry:TDiagramOption; TitleNode:TMathNode; FirstAt,LastAt,After:Integer;
      RowOrder:TTableRowOrder; Fill:TTeXFill; SpaceWidth:Double;
      Frame:TBeamerFrame; Zoom:TBeamerZoom; Role,Overlay:string;
      VisibleRows:array of Boolean;
    procedure ControlWordSpace(Field:TMathNode);
    var Q,Lines:Integer;
    begin
      if (Cmd='') or not (Cmd[1] in ['a'..'z','A'..'Z']) or
        (Field.Children.Count<>0) or (Field.Text<>'\'+Cmd) or
        (Field.Prefix<>'') or (Field.Suffix<>'') then Exit;
      Q:=P; Lines:=0;
      while (Q<=Limit) and (Source[Q] in [' ',#9,#10,#13]) do begin
        if Source[Q]=#10 then Inc(Lines); Inc(Q);
      end;
      if Lines<2 then begin Field.Suffix:=Copy(Source,P,Q-P); P:=Q; end;
    end;
    procedure BeamerArgument(Parent:TMathNode; const Role:string='');
    var First,Last,After:Integer; Field:TMathNode;
    begin
      First:=P; SkipTeXSpace(Source,First);
      if (First>Limit) or (Source[First]<>'{') then Exit;
      After:=First; ReadTeXGroup(Source,After,'{','}'); After:=Min(After,Limit+1);
      Last:=After; if Copy(Source,Last-1,1)='}' then Dec(Last);
      Field:=Parent.Add(TMathNode.Create(mkGroup,Role));
      if Role='' then Field.Text:='@beamer:argument';
      Field.Prefix:=Copy(Source,P,First-P+1);
      P:=First+1; Field.Add(Part(P,Last-1,False)); Field.Suffix:=Copy(Source,Last,After-Last); P:=After;
    end;
    procedure FrameField(First,After,Next:Integer; const Role:string);
    var Field:TMathNode;
    begin
      if First=0 then Exit;
      Field:=Node.Add(TMathNode.Create(mkGroup,Role)); P:=First;
      Field.Add(Part(P,After-1,False)); Field.Suffix:=Copy(Source,After,Next-After);
    end;
  begin
    Inc(Nesting);
    if Nesting>128 then begin Dec(Nesting); raise Exception.Create('Paragraph nesting is too deep.'); end;
    SavedScope:=Scope; LocalScope:=nil;
    if HasDefinitions and (Grouped or (StopEnv<>'')) then begin
      LocalScope:=Scope.Clone; Scope:=LocalScope; Scopes.Add(Scope);
    end;
    try
    Result:=TMathNode.Create(mkRow);
    try
      while P<=Limit do
      begin
        if Grouped and (Source[P]='}') then Break;
        if (StopEnv='@group') and (Copy(Source,P,9)='\endgroup') and
          ((P+9>Limit) or not (Source[P+9] in ['a'..'z','A'..'Z'])) then Break;
        if StopItem and (Copy(Source,P,5)='\item') and ((P+5>Limit) or not (Source[P+5] in ['a'..'z','A'..'Z'])) then Break;
        if StopColumn and (Copy(Source,P,7)='\column') and ((P+7>Limit) or not (Source[P+7] in ['a'..'z','A'..'Z'])) then Break;
        if (StopEnv<>'') and (Copy(Source,P,Length(StopEnv)+6)='\end{'+StopEnv+'}') then Break;
        { Parts visit source in order. Skip spans consumed by literal commands
          instead of searching every equation for every word in a paragraph. }
        while (NextSpan<Length(Spans)) and (Spans[NextSpan].Start<=P) do Inc(NextSpan);
        if NextSpan<Length(Spans) then begin
          I:=NextSpan;
          if Spans[I].Environment<>'' then
          begin
            Opening:=Length('\begin{'+Spans[I].Environment+'}');
            Closing:=Length('\end{'+Spans[I].Environment+'}');
          end
          else if (Copy(Source,Spans[I].Start-2,2)='$$') or
            (Copy(Source,Spans[I].Start-2,2)='\(') or
            (Copy(Source,Spans[I].Start-2,2)='\[') then
          begin Opening:=2; Closing:=2; end
          else begin Opening:=1; Closing:=1; end;
          if P=Spans[I].Start-Opening then begin
          Node:=Result.Add(TMathNode.Create(mkFormula));
          Node.Prefix:=Copy(Source,P,Opening);
          Node.Suffix:=Copy(Source,Spans[I].Start+Spans[I].Count,Closing);
          MathStart:=Spans[I].Start;
          if (Spans[I].Environment='alignat') or (Spans[I].Environment='alignat*') then
          begin
            ReadTeXGroup(Source,MathStart,'{','}');
            Node.Prefix:=Node.Prefix+Copy(Source,Spans[I].Start,MathStart-Spans[I].Start);
          end;
          if not ParseMath(Copy(Source,MathStart,Spans[I].Count+Spans[I].Start-MathStart),MathRoot,Error,Scope,True,@ParagraphModel.ParseParagraph) then
            MathRoot:=TMathNode.Create(mkText,Copy(Source,MathStart,Spans[I].Count+Spans[I].Start-MathStart));
          Node.Add(MathRoot);
          P:=Spans[I].Start+Spans[I].Count+Closing; Inc(NextSpan); Continue;
          end;
        end;
        A:=P;
        if Source[P]='%' then
        begin
          while (P<=Limit) and (Source[P]<>#10) do Inc(P);
          if P<=Limit then Inc(P);
          Node:=TMathNode.Create(mkComment); Node.Add(TMathNode.Create(mkProse,Copy(Source,A,P-A))); Result.Add(Node); Continue;
        end;
        if Source[P]='\' then
        begin
          Q:=P;
          if ReadEngineConditional(Source,Scope.Engine,Q,FirstAt,LastAt,Scope) and (Q<=Limit+1) then begin
            P:=FirstAt; Node:=Part(P,LastAt-1,False);
            Node.Prefix:=Copy(Source,A,FirstAt-A); Node.Suffix:=Copy(Source,LastAt,Q-LastAt);
            Result.Add(Node); P:=Q; Continue;
          end;
          if ReadTeXDefinition(Source,Q) then begin
            P:=Min(Q,Limit+1); Node:=DefinitionNode(Copy(Source,A,P-A)); Result.Add(Node);
            Scope.ApplyDefinitions(Node.TeX);
            Q:=1; Cmd:=ReadTeXCommand(Node.TeX,Q);
            if (Cmd='gdef') or (Cmd='xdef') then for J:=0 to Scopes.Count-2 do TMacroRegistry(Scopes[J]).ApplyDefinitions(Node.TeX);
            Continue;
          end;
          Cmd:=ReadTeXCommand(Source,P);
          if Cmd='color' then begin
            ReadTeXGroup(Source,P,'[',']'); ReadTeXGroup(Source,P,'{','}');
            Result.Add(TMathNode.Create(mkTextCommand,Copy(Source,A,P-A))); Continue;
          end;
          if Cmd='begingroup' then begin
            Node:=Result.Add(TMathNode.Create(mkGroup)); Node.Prefix:=Copy(Source,A,P-A);
            Node.Add(Part(P,Limit,False,'@group'));
            Q:=P; if ReadTeXCommand(Source,Q)='endgroup' then begin Node.Suffix:=Copy(Source,P,Q-P); P:=Q; end;
            Continue;
          end;
          if Scope.Presentation and ((Cmd='begin') or (Cmd='frame')) and ReadBeamerFrame(Source,A,Frame) then begin
            Frame.BodyAfter:=Min(Frame.BodyAfter,Limit+1); Frame.After:=Min(Frame.After,Limit+1);
            Node:=Result.Add(TMathNode.Create(mkEnvironment,'frame'));
            FirstAt:=Frame.BodyFirst;
            if Frame.SubtitleFirst>0 then FirstAt:=Frame.SubtitleFirst;
            if Frame.TitleFirst>0 then FirstAt:=Frame.TitleFirst;
            Node.Prefix:=Copy(Source,A,FirstAt-A);
            LastAt:=Frame.BodyFirst; if Frame.SubtitleFirst>0 then LastAt:=Frame.SubtitleFirst;
            FrameField(Frame.TitleFirst,Frame.TitleAfter,LastAt,'@beamer:frametitle');
            FrameField(Frame.SubtitleFirst,Frame.SubtitleAfter,Frame.BodyFirst,'@beamer:framesubtitle');
            P:=Frame.BodyFirst; Inc(FrameDepth);
            try Node.Add(Part(P,Frame.BodyAfter-1,False)); finally Dec(FrameDepth); end;
            Node.Suffix:=Copy(Source,Frame.BodyAfter,Frame.After-Frame.BodyAfter); P:=Frame.After; Continue;
          end;
          if Scope.Presentation and (Cmd='column') then begin
            ReadTeXGroup(Source,P,'[',']'); ReadTeXGroup(Source,P,'{','}');
            Node:=Result.Add(TMathNode.Create(mkEnvironment,'column')); Node.Prefix:=Copy(Source,A,P-A);
            Node.Add(Part(P,Limit,False,StopEnv,False,True)); Continue;
          end;
          if Scope.Presentation and (Cmd='maketitle') and (FrameDepth=0) then begin
            Node:=Result.Add(TMathNode.Create(mkEnvironment,'frame'));
            RowNode:=Node.Add(TMathNode.Create(mkRow));
            Node:=RowNode.Add(TMathNode.Create(mkGroup,'@beamer:titlepage'));
            Node.Prefix:=Copy(Source,A,P-A); Continue;
          end;
          if Scope.Presentation and BeamerCommand(Cmd) then begin
            if (Cmd='framezoom') and ReadBeamerZoom(Source,A,Zoom) then begin
              Node:=Result.Add(TMathNode.Create(mkGroup,'@beamer:framezoom'));
              P:=Zoom.After; Node.Prefix:=Copy(Source,A,P-A); Continue;
            end;
            Role:=Cmd; if (Cmd='onslide') and (Copy(Source,P,1)='*') then begin Inc(P); Role:='only'; end
            else if (Cmd='onslide') and (Copy(Source,P,1)='+') then begin Inc(P); Role:='visible'; end
            else if (Cmd='usebeamerfont') and (Copy(Source,P,1)='*') then Inc(P);
            Overlay:=ReadBeamerOverlay(Source,P);
            if (Cmd='pause') or (Cmd='frametitle') or (Cmd='framesubtitle') or (Cmd='usebeamercolor') then begin
              Q:=P; SkipTeXSpace(Source,Q); if Copy(Source,Q,1)='[' then begin ReadTeXGroup(Source,Q,'[',']'); P:=Q; end;
            end;
            Node:=Result.Add(TMathNode.Create(mkGroup,'@beamer:'+Role)); Node.Prefix:=Copy(Source,A,P-A);
            Count:=1; if Cmd='alt' then Count:=2 else if Cmd='temporal' then Count:=3
            else if (Cmd='pause') or (Cmd='titlepage') or (Cmd='maketitle') then Count:=0;
            for I:=1 to Count do BeamerArgument(Node);
            if (Overlay='') and (Copy(Source,P,1)='<') then begin
              Q:=P; ReadBeamerOverlay(Source,P); Node.Suffix:=Copy(Source,Q,P-Q);
            end;
            Continue;
          end;
          if ReadHorizontalFill('\'+Cmd,Fill) then begin
            while (P<=Limit) and (Source[P] in [' ',#9,#10,#13]) do Inc(P);
            Result.Add(TMathNode.Create(mkCommand,Copy(Source,A,P-A))); Continue;
          end;
          if (Cmd<>' ') and (Cmd<>'space') and ReadMathSpace('\'+Cmd,SpaceWidth,Error) then begin
            Node:=Result.Add(TMathNode.Create(mkCommand,Copy(Source,A,P-A)));
            ControlWordSpace(Node); Continue;
          end;
          if (Cmd='protect') or (Cmd='relax') then begin
            while (P<=Limit) and (Source[P] in [' ',#9,#10,#13]) do Inc(P);
            Node:=Result.Add(TMathNode.Create(mkRaw,Copy(Source,A,P-A))); Node.Hidden:=True; Continue;
          end;
          if Cmd='appendix' then begin
            Result.Add(TMathNode.Create(mkCommand,Copy(Source,A,P-A))); Continue;
          end;
          if (Cmd='hrule') or (Cmd='vrule') then begin
            Q:=P;
            while ReadTeXRuleDimension(Source,Q,Env,Error) do P:=Q;
            Result.Add(TMathNode.Create(mkCommand,Copy(Source,A,P-A))); Continue;
          end;
          if (Cmd='xymatrix') or (Copy(Cmd,1,9)='xymatrix@') then begin
            Q:=P;
            while (Q<=Limit) and not (Source[Q] in ['{',#10,#13]) do Inc(Q);
            if Copy(Source,Q,1)='{' then begin ReadTeXGroup(Source,Q,'{','}'); P:=Q; end;
            Node:=TMathNode.Create(mkUnknownCommand);
            Node.Add(TMathNode.Create(mkProse,Copy(Source,A,P-A))); Result.Add(Node); Continue;
          end;
          if IsTeXInputCommand(Cmd) or
             (Cmd='vspace') or (Cmd='vskip') or (Cmd='smallskip') or (Cmd='medskip') or (Cmd='bigskip') or
             IsGeneratedTeXCommand(Cmd) then begin
            if Copy(Source,P,1)='*' then Inc(P);
            Q:=P; SkipTeXSpace(Source,Q);
            if Copy(Source,Q,1)='[' then begin ReadTeXGroup(Source,Q,'[',']'); P:=Q; SkipTeXSpace(Source,Q); end;
            if Copy(Source,Q,1)='{' then begin ReadTeXGroup(Source,Q,'{','}'); P:=Q; end
            else if (Cmd='input') or (Cmd='vskip') then begin P:=Q; while (P<=Limit) and not (Source[P] in [' ',#9,#10,#13]) do Inc(P); end;
            Node:=TMathNode.Create(mkCommand,Copy(Source,A,P-A)); Result.Add(Node); Continue;
          end;
          Info:=Scope.Find(Cmd);
          if (Cmd='hspace') and (Copy(Source,P,1)='*') then begin Inc(P); Cmd:=Cmd+'*'; Info:=Scope.Find(Cmd); end;
          if IsTextStyleSwitch(Cmd) and ((Info=nil) or (Info.PackageSource<>'')) then begin
            ReadTextStyleArguments(Source,Cmd,P);
            Node:=Result.Add(TMathNode.Create(mkUnknownCommand));
            Node.Add(TMathNode.Create(mkProse,Copy(Source,A,P-A))); Continue;
          end;
          if ((Info=nil) or not Info.Undefined) and ((TeXTextAccent(Cmd)>=0) or
            ((Info<>nil) and ((Info.GlyphFont<>'') or (Info.GlyphPlan<>''))) or ((Info<>nil) and Info.Expandable and
            ((Info.PackageSource='') or (not KnownTextCommand(Cmd) and (Cmd<>'textbf') and (Cmd<>'textit') and
             (Cmd<>'textsf') and (Cmd<>'texttt') and (Cmd<>'textrm') and (Cmd<>'textsc') and (Cmd<>'textsl') and
             (Cmd<>'textup') and (Cmd<>'textmd') and (Cmd<>'textnormal') and (Cmd<>'emph') and (Cmd<>'underline'))))) then begin
            Node:=Result.Add(TMathNode.Create(mkCommand,Copy(Source,A,P-A)));
            Node.NativePackage:=(Info<>nil) and (Info.PreviewName<>'');
            if Info<>nil then Node.LiteralArguments:=Scope.RequiresLiteralArguments(Cmd);
            if (Info<>nil) and (Info.PreviewAdapter='derivative') and (Copy(Source,P,1)='*') then begin
              Node.Text:=Node.Text+'*'; Inc(P);
            end;
            Count:=1; if Info<>nil then Count:=Info.ArgCount;
            if Info<>nil then Count:=PackageArgumentCount(Info.PreviewAdapter,Source,P,Count);
            if TeXTextAccent(Cmd)>=0 then Count:=1;
            if (Info<>nil) and Info.OptionalFirst and (Info.Signature='') then begin
              Option:=Node.Add(TMathNode.Create(mkOptional));
              Info.ArgumentKind(1,Option.Text);
              Option.OptionalDefault:=True;
              Q:=P; SkipTeXSpace(Source,Q);
              if Copy(Source,Q,1)='[' then begin
                Opening:=Q+1; Error:=ReadTeXGroup(Source,Q,'[',']');
                Option.Prefix:=Copy(Source,P,Opening-P); Option.Suffix:=']';
                EndAt:=Q-2; Option.Add(Part(Opening,EndAt,False)); P:=Q;
              end else Option.Add(TMathNode.Create(mkProse));
              Dec(Count);
            end;
            for I:=1 to Count do begin
              if (Info<>nil) and (Info.PreviewAdapter='derivative') and (I=3) then begin
                Q:=P; SkipTeXSpace(Source,Q);
                while (Q<=Limit) and (Source[Q] in ['/','!']) do Inc(Q);
                if Trim(Copy(Source,P,Q-P))<>'' then begin Node.Add(TMathNode.Create(mkRaw,Copy(Source,P,Q-P))); P:=Q; end;
              end;
              Q:=P; SkipTeXSpace(Source,Q);
              if (Info<>nil) and (Info.Signature<>'') and (Info.ArgumentKind(I,Error) in ['o','O']) then begin
                Option:=Node.Add(TMathNode.Create(mkOptional)); Option.Text:=Error;
                Option.OptionalDefault:=Info.ArgumentKind(I,Error)='O';
                if Copy(Source,Q,1)='[' then begin
                  Opening:=Q+1; Error:=ReadTeXGroup(Source,Q,'[',']',PackageLiteralArgument(Info.PreviewAdapter,Info.PreviewName,I));
                  Option.Prefix:=Copy(Source,P,Opening-P); Option.Suffix:=']';
                  EndAt:=Q-2;
                  if PackageLiteralArgument(Info.PreviewAdapter,Info.PreviewName,I) then Option.Add(TMathNode.Create(mkProse,Error))
                  else Option.Add(Part(Opening,EndAt,False)); P:=Q;
                end else Option.Add(TMathNode.Create(mkProse));
                if Info.PreviewName<>'' then Option.Hidden:=not PackageVisibleArgument(Info.PreviewAdapter,Info.PreviewName,I);
                Continue;
              end;
              if Q>Limit then Break;
              if Source[Q]='{' then begin
                Opening:=Q+1; Option:=Node.Add(TMathNode.Create(mkGroup)); Option.Prefix:=Copy(Source,P,Opening-P);
                if (Info<>nil) and PackageLiteralArgument(Info.PreviewAdapter,Info.PreviewName,I) then begin
                  P:=Q; Error:=ReadTeXGroup(Source,P,'{','}',True); Option.Add(TMathNode.Create(mkProse,Error));
                  if (P>1) and (Source[P-1]='}') then Option.Suffix:='}';
                end else begin
                  P:=Opening; Option.Add(Part(P,Limit,True));
                  if Copy(Source,P,1)='}' then begin Option.Suffix:='}'; Inc(P); end;
                end;
              end else begin
                Opening:=Q;
                if Source[Q]='\' then begin ReadTeXCommand(Source,Q); Option:=TMathNode.Create(mkTextCommand,Copy(Source,Opening,Q-Opening)); end
                else begin NextUTF8CodePoint(Source,Q); Option:=TMathNode.Create(mkProse,Copy(Source,Opening,Q-Opening)); end;
                Node.Add(Option); Option.Prefix:=Copy(Source,P,Opening-P); P:=Q;
              end;
              if (Info<>nil) and (Info.PreviewName<>'') then Option.Hidden:=not PackageVisibleArgument(Info.PreviewAdapter,Info.PreviewName,I);
            end;
            Count:=Node.Children.Count;
            for I:=0 to Node.Children.Count-1 do if TMathNode(Node.Children[I]).Kind=mkRaw then Dec(Count);
            if (Info<>nil) and ((Node.NativePackage and (Count<Info.ArgCount)) or
               not PackagePreviewSupported(Info.PreviewAdapter,Info.PreviewName,Node.TeX)) then begin
              LiteralCommand(Node);
            end;
            if (Node.Kind=mkCommand) and (Info<>nil) and (Info.PreviewAdapter='space') then begin
              Error:=Node.TeX; Node.Children.Clear; Node.Text:=Error;
            end;
            if Node.Kind=mkCommand then ControlWordSpace(Node);
            if (Info<>nil) and (Info.PreviewAdapter='metadata') then Scope.ApplyDefinitions(Node.TeX);
            if (Info<>nil) and ((Info.PreviewAdapter='metadata') or (Info.PreviewAdapter='directive')) then LiteralCommand(Node);
            if (Info<>nil) and (Info.PreviewAdapter='savedbox') then AtomicCommand(Node);
            Continue;
          end;
          if (Cmd='item') and ((StopEnv='itemize') or (StopEnv='enumerate') or (StopEnv='description')) then begin
            if Scope.Presentation then ReadBeamerOverlay(Source,P);
            Q:=P; SkipTeXSpace(Source,Q);
            if (StopEnv='description') and (Q<=Limit) and (Source[Q]='[') then begin
              Node:=Result.Add(TMathNode.Create(mkGroup)); Node.Prefix:=Copy(Source,A,P-A);
              Option:=Node.Add(TMathNode.Create(mkOptional)); Option.Prefix:=Copy(Source,P,Q-P)+'[';
              Opening:=Q+1; P:=Q; ReadTeXGroup(Source,P,'[',']');
              EndAt:=P-1; if (P>Q) and (Source[P-1]=']') then Dec(EndAt);
              Option.Add(Part(Opening,EndAt,False));
              if (P>Q) and (Source[P-1]=']') then Option.Suffix:=']';
              Node.Add(Part(P,Limit,False,StopEnv,True)); Continue;
            end;
            if (Q<=Limit) and (Source[Q]='[') then begin ReadTeXGroup(Source,Q,'[',']'); P:=Q; end;
            Node:=Result.Add(TMathNode.Create(mkGroup)); Node.Prefix:=Copy(Source,A,P-A);
            Node.Add(Part(P,Limit,False,StopEnv,True)); Continue;
          end;
          if Cmd='begin' then
          begin
            Q:=P; Env:=ReadTeXGroup(Source,Q,'{','}');
            if (Env='verbatim') or (Env='verbatim*') or (Env='lstlisting') or
              ((Env<>'filecontents') and (Env<>'filecontents*') and IsTeXVerbatimEnvironment(Env)) then begin
              if Env='lstlisting' then begin
                SkipTeXSpace(Source,Q);
                if Copy(Source,Q,1)='[' then ReadTeXGroup(Source,Q,'[',']');
              end;
              EndAt:=Min(Limit+1,EnvironmentEnd(Source,A,Env));
              Node:=TMathNode.Create(mkVerbatim,Env); Node.Prefix:=Copy(Source,A,Q-A);
              Node.Add(TMathNode.Create(mkProse,Copy(Source,Q,EndAt-Q))); P:=EndAt;
              if P<=Limit then begin ReadTeXCommand(Source,P); ReadTeXGroup(Source,P,'{','}'); end;
              P:=Min(P,Limit+1); Node.Suffix:=Copy(Source,EndAt,P-EndAt); Result.Add(Node); Continue;
            end;
            if TableEnvironment(Env) then begin
              EndAt:=EnvironmentEnd(Source,A,Env);
              Table:=TTeXTable.Create;
              try
                if Table.Load(Copy(Source,A,Min(Limit+1,EndAt+Length(Env)+6)-A)) then begin
                  if (Result.Children.Count=0) or (TMathNode(Result.Children.Last).Kind<>mkProse) then
                    Result.Add(TMathNode.Create(mkProse));
                  Node:=Result.Add(TMathNode.Create(mkTable,Env)); Node.Prefix:=Table.Prefix;
                  RowOrder:=Table.VisualRows;
                  VisibleRows:=nil; SetLength(VisibleRows,Table.Rows.Count);
                  for K:=0 to High(RowOrder) do VisibleRows[RowOrder[K]]:=True;
                  for J:=0 to Table.Rows.Count-1 do begin
                    TableRow:=TTableRow(Table.Rows[J]); RowNode:=Node.Add(TMathNode.Create(mkTableRow)); RowNode.Prefix:=TableRow.Leading;
                    RowNode.Hidden:=not VisibleRows[J];
                    for K:=0 to TableRow.Cells.Count-1 do begin
                      if TableRow.Cells[K]=CoveredTableCell then begin
                        CellNode:=RowNode.Add(TMathNode.Create(mkTableCell)); CellNode.Hidden:=True; Continue;
                      end;
                      P:=A+TableRow.Starts[K]; CellEnd:=P+TableRow.Lengths[K];
                      CellNode:=RowNode.Add(TMathNode.Create(mkTableCell));
                      if (Pos('$',Table.ColumnBefore(K,J))>0) and (Pos('$',Table.ColumnAfter(K,J))>0) then begin
                        Option:=CellNode.Add(TMathNode.Create(mkFormula));
                        if not ParseMath(Copy(Source,P,CellEnd-P),MathRoot,Error,Scope,True,@ParagraphModel.ParseParagraph) then
                          MathRoot:=TMathNode.Create(mkText,Copy(Source,P,CellEnd-P));
                        Option.Add(MathRoot); P:=CellEnd;
                      end else CellNode.Add(Part(P,CellEnd-1,False));
                      if K+Table.CellSpan(J,K).Columns<TableRow.Cells.Count then CellNode.Suffix:='&';
                      FirstAt:=J; LastAt:=K; CellNode.Hidden:=Table.CellOwner(FirstAt,LastAt);
                    end;
                    RowNode.Suffix:=TableRow.Ending;
                  end;
                  Node.Suffix:=Table.Suffix; P:=A+Length(Node.TeX);
                  Continue;
                end;
              finally Table.Free; end;
            end;
            if (Env<>'') and not RenderedEnvironment(Env) then begin
              EndAt:=EnvironmentEnd(Source,A,Env); P:=EndAt;
              if P<=Limit then begin ReadTeXCommand(Source,P); ReadTeXGroup(Source,P,'{','}'); end;
              P:=Min(P,Limit+1); Node:=TMathNode.Create(mkUnknownCommand);
              Node.Add(TMathNode.Create(mkProse,Copy(Source,A,P-A))); Result.Add(Node); Continue;
            end;
            if Env<>'' then
            begin
              P:=Q; Node:=Result.Add(TMathNode.Create(mkEnvironment,Env)); Node.Prefix:=Copy(Source,A,P-A);
              if Env='adjustbox' then begin
                Q:=P; SkipTeXSpace(Source,Q); Opening:=Q+1; Error:=ReadTeXGroup(Source,Q,'{','}');
                Option:=Node.Add(TMathNode.Create(mkGroup)); Option.Prefix:=Copy(Source,P,Opening-P); Option.Suffix:='}';
                Option.Hidden:=True; Option.Add(TMathNode.Create(mkProse,Error)); P:=Q;
              end;
              if Scope.Presentation and BeamerEnvironment(Env) then begin
                ReadBeamerOverlay(Source,P);
                Q:=P; SkipTeXSpace(Source,Q); if Copy(Source,Q,1)='[' then begin ReadTeXGroup(Source,Q,'[',']'); P:=Q; end;
                if (Env='column') or (Env='overlayarea') then begin
                  Q:=P; SkipTeXSpace(Source,Q); if Copy(Source,Q,1)='{' then begin ReadTeXGroup(Source,Q,'{','}'); P:=Q; end;
                  if Env='overlayarea' then ReadTeXGroup(Source,P,'{','}');
                end;
                Node.Prefix:=Copy(Source,A,P-A);
                if (Env='block') or (Env='alertblock') or (Env='exampleblock') then BeamerArgument(Node,'@beamer:blocktitle');
                Node.Add(Part(P,Limit,False,Env));
                if Copy(Source,P,Length(Env)+6)='\end{'+Env+'}' then begin Node.Suffix:='\end{'+Env+'}'; Inc(P,Length(Node.Suffix)); end;
                Continue;
              end;
              if Scope.Presentation and Scope.IsTheorem(Env) then begin
                ReadBeamerOverlay(Source,P); Node.Prefix:=Copy(Source,A,P-A); Q:=P;
              end;
              if Env='minipage' then begin
                for I:=1 to 3 do begin
                  Q:=P; SkipTeXSpace(Source,Q); if Copy(Source,Q,1)<>'[' then Break;
                  P:=Q; ReadTeXGroup(Source,P,'[',']');
                end;
                ReadTeXGroup(Source,P,'{','}'); Node.Prefix:=Copy(Source,A,P-A); Q:=P;
              end;
              if (Env='wrapfigure') or (Env='wraptable') then begin
                SkipTeXSpace(Source,P); if Copy(Source,P,1)='[' then ReadTeXGroup(Source,P,'[',']');
                ReadTeXGroup(Source,P,'{','}');
                SkipTeXSpace(Source,P); if Copy(Source,P,1)='[' then ReadTeXGroup(Source,P,'[',']');
                ReadTeXGroup(Source,P,'{','}'); Node.Prefix:=Copy(Source,A,P-A); Q:=P;
              end;
              SkipTeXSpace(Source,Q);
              if (Env='tcolorbox') and (Q<=Limit) and (Source[Q]='[') then begin
                Option:=Node.Add(TMathNode.Create(mkOptional)); Option.Prefix:=Copy(Source,P,Q-P)+'[';
                After:=Q; Error:=ReadTeXGroup(Source,After,'[',']'); EndAt:=After-1;
                if Copy(Source,EndAt,1)=']' then Option.Suffix:=']' else Inc(EndAt);
                TitleNode:=nil;
                for Entry in DiagramOptions(Error,Q) do if (Entry.Name='title') and Entry.HasValue then begin
                  FirstAt:=Entry.ValueRange.First+1; LastAt:=Entry.ValueRange.Last;
                  if Copy(Source,FirstAt,1)='{' then begin Inc(FirstAt); if Copy(Source,LastAt,1)='}' then Dec(LastAt); end;
                  TitleNode:=Option.Add(TMathNode.Create(mkGroup,'@boxtitle')); TitleNode.Prefix:=Copy(Source,Q+1,FirstAt-Q-1);
                  TitleNode.Suffix:=Copy(Source,LastAt+1,EndAt-LastAt-1);
                  P:=FirstAt; TitleNode.Add(Part(P,LastAt,False)); Break;
                end;
                if TitleNode=nil then begin Option.Prefix:=Copy(Source,P,EndAt-P); Option.Hidden:=True; end;
                P:=After;
              end else if (Q<=Limit) and (Source[Q]='[') then begin
                Option:=Node.Add(TMathNode.Create(mkOptional)); Option.Prefix:=Copy(Source,P,Q-P)+'[';
                Option.LiteralArguments:=(Env<>'proof') and not Scope.IsTheorem(Env);
                Opening:=Q+1; P:=Q; Error:=ReadTeXGroup(Source,P,'[',']');
                EndAt:=P-1; if (P>Q) and (Source[P-1]=']') then Dec(EndAt);
                Option.Add(Part(Opening,EndAt,False));
                if (P>Q) and (Source[P-1]=']') then Option.Suffix:=']';
              end else if (Env='proof') or Scope.IsTheorem(Env) then begin
                Option:=TMathNode.Create(mkOptional); Option.Add(TMathNode.Create(mkProse)); Node.Add(Option);
              end;
              Node.Add(Part(P,Limit,False,Env));
              if Copy(Source,P,Length(Env)+6)='\end{'+Env+'}' then
              begin Node.Suffix:='\end{'+Env+'}'; Inc(P,Length(Node.Suffix)); end;
              Continue;
            end;
          end;
          Structural:=(Cmd='begin') or (Cmd='end') or (Cmd='item') or
            (Cmd='def') or (Cmd='gdef') or (Cmd='edef') or (Cmd='xdef') or
            (Cmd='newcommand') or (Cmd='renewcommand') or (Cmd='providecommand') or
            (Cmd='DeclareMathOperator') or (Cmd='DeclareRobustCommand') or
            (Cmd='NewDocumentCommand') or (Cmd='RenewDocumentCommand') or (Cmd='DeclareDocumentCommand') or
            (Cmd='ProvideDocumentCommand') or (Cmd='label') or (Cmd='verb') or
            (Cmd='input') or (Cmd='include') or (Cmd='usepackage');
          Editable:=(Cmd='textbf') or (Cmd='textit') or (Cmd='emph') or
            (Cmd='textrm') or (Cmd='textsf') or (Cmd='texttt') or (Cmd='textcolor') or
            (Cmd='textsc') or (Cmd='textsl') or (Cmd='textup') or (Cmd='textmd') or (Cmd='textnormal') or
            (Cmd='underline') or (Cmd='section') or (Cmd='subsection') or
            (Cmd='subsubsection') or (Cmd='paragraph') or (Cmd='subparagraph') or
            (Cmd='chapter') or (Cmd='part') or (Cmd='title') or (Cmd='caption') or (Cmd='footnote') or (Cmd='footnotetext') or (Cmd='marginpar');
          if (P<=Limit) and (Source[P]='*') then Inc(P);
          if (Cmd='multicolumn') or (Cmd='multirow') then begin
            Q:=P;
            if Cmd='multirow' then ReadTeXGroup(Source,Q,'[',']');
            ReadTeXGroup(Source,Q,'{','}');
            if Cmd='multirow' then ReadTeXGroup(Source,Q,'[',']');
            ReadTeXGroup(Source,Q,'{','}');
            if Cmd='multirow' then ReadTeXGroup(Source,Q,'[',']');
            SkipTeXSpace(Source,Q);
            if Copy(Source,Q,1)='{' then begin
              P:=Q+1; Node:=Result.Add(TMathNode.Create(mkGroup)); Node.Prefix:=Copy(Source,A,P-A);
              Node.Add(Part(P,Limit,True)); if Copy(Source,P,1)='}' then begin Node.Suffix:='}'; Inc(P); end;
              Continue;
            end;
          end;
          if Cmd='label' then begin
            Q:=P; SkipTeXSpace(Source,Q);
            if (Q<=Limit) and (Source[Q]='{') then begin
              Node:=TMathNode.Create(mkCommand,Copy(Source,A,P-A));
              Option:=TMathNode.Create(mkGroup); Option.Prefix:=Copy(Source,P,Q-P)+'{';
              P:=Q; Env:=ReadTeXGroup(Source,P,'{','}'); Option.Add(TMathNode.Create(mkProse,Env));
              if (P>Q) and (Source[P-1]='}') then Option.Suffix:='}';
              Node.Add(Option); Result.Add(Node); Continue;
            end;
          end;
          if (Cmd='verb') or (Cmd='lstinline') then
          begin
            if Cmd='lstinline' then ReadTeXGroup(Source,P,'[',']');
            if P<=Limit then begin
              Env:=Source[P]; Inc(P); Q:=P;
              if (Cmd='lstinline') and (Env='{') then begin
                P:=Q-1; ReadTeXGroup(Source,P,'{','}'); Env:='}';
                if Copy(Source,P-1,1)='}' then Dec(P);
              end else while (P<=Limit) and (Source[P]<>Env) and not (Source[P] in [#10,#13]) do Inc(P);
              Node:=TMathNode.Create(mkGroup); Node.Prefix:=Copy(Source,A,Q-A);
              Node.Add(TMathNode.Create(mkProse,Copy(Source,Q,P-Q)));
              if (P<=Limit) and (Source[P]=Env) then begin Node.Suffix:=Env; Inc(P); end;
              Result.Add(Node); Continue;
            end;
          end
          else if (Cmd='def') or (Cmd='gdef') or (Cmd='edef') or (Cmd='xdef') then
          begin
            while (P<=Limit) and (Source[P]<>'{') do Inc(P);
            ReadTeXGroup(Source,P,'{','}');
          end
          else
          begin
            Q:=P; SkipTeXSpace(Source,Q);
            while (Q<=Limit) and (Source[Q]='[') do
            begin ReadTeXGroup(Source,Q,'[',']'); P:=Q; SkipTeXSpace(Source,Q); end;
            Q:=P; SkipTeXSpace(Source,Q);
            if (Cmd='textcolor') and (Q<=Limit) and (Source[Q]='{') then begin ReadTeXGroup(Source,Q,'{','}'); SkipTeXSpace(Source,Q); end;
            if Editable and (Q<=Limit) and (Source[Q]='{') then
            begin
              P:=Q+1; Node:=Result.Add(TMathNode.Create(mkGroup)); Node.Prefix:=Copy(Source,A,P-A);
              Node.Add(Part(P,Limit,True));
              if (P<=Limit) and (Source[P]='}') then begin Node.Suffix:='}'; Inc(P); end;
              Continue;
            end;
            while (Q<=Limit) and (Source[Q]='{') do
            begin
              Env:=ReadTeXGroup(Source,Q,'{','}'); P:=Q;
              SkipTeXSpace(Source,Q);
              if (Q<=Limit) and (Source[Q]='[') then
              begin ReadTeXGroup(Source,Q,'[',']'); P:=Q; SkipTeXSpace(Source,Q); end;
            end;
          end;
          if Structural and not ((Cmd='input') or (Cmd='include') or (Cmd='usepackage')) then
            Result.Add(TMathNode.Create(mkRaw,Copy(Source,A,P-A)))
          else if KnownTextCommand(Cmd) and ((Info=nil) or (Info.PackageSource<>'') or not Info.Undefined) then begin
            Node:=Result.Add(TMathNode.Create(mkTextCommand,Copy(Source,A,P-A))); ControlWordSpace(Node);
          end
          else begin
            Node:=TMathNode.Create(mkUnknownCommand); Node.Add(TMathNode.Create(mkProse,Copy(Source,A,P-A))); Result.Add(Node);
          end;
          Continue;
        end;
        if Source[P]='{' then
        begin
          Inc(P); Node:=Result.Add(TMathNode.Create(mkGroup)); Node.Prefix:='{';
          Node.Add(Part(P,Limit,True));
          if (P<=Limit) and (Source[P]='}') then begin Node.Suffix:='}'; Inc(P); end;
          Continue;
        end;
        if Source[P] in [' ',#9,#10,#13] then
        begin
          while (P<=Limit) and (Source[P] in [' ',#9,#10,#13]) do Inc(P);
          Result.Add(TMathNode.Create(mkProse,Copy(Source,A,P-A))); Continue;
        end;
        if Source[P]='~' then begin Inc(P); Result.Add(TMathNode.Create(mkProse,'~')); Continue; end;
        if Source[P] in ['}','$','&'] then
        begin Inc(P); Result.Add(TMathNode.Create(mkRaw,Copy(Source,A,P-A))); Continue; end;
        while (P<=Limit) and not (Source[P] in [' ',#9,#10,#13,'\','{','}','$','%','&','~']) do Inc(P);
        { Keep trailing whitespace in the editable word, but outside its position markers. }
        while (P<=Limit) and (Source[P] in [' ',#9,#10,#13]) do Inc(P);
        Result.Add(TMathNode.Create(mkProse,Copy(Source,A,P-A)));
      end;
      if (Result.Children.Count=0) or (TMathNode(Result.Children.Last).Kind<>mkProse) then
        Result.Add(TMathNode.Create(mkProse));
    except Result.Free; raise; end;
    finally
      if LocalScope<>nil then begin Scopes.Delete(Scopes.Count-1); Scope:=SavedScope; LocalScope.Free; end;
      Dec(Nesting);
    end;
  end;
var P:Integer;
begin
  HasDefinitions:=ContainsTeXDefinitions(Source); OwnScope:=(Macros=nil) or HasDefinitions;
  if not OwnScope then Scope:=Macros
  else if Macros<>nil then Scope:=Macros.Clone else begin Scope:=TMacroRegistry.Create; Scope.Load('',GetCurrentDir); end;
  Scopes:=TList.Create; Scopes.Add(Scope);
  try
    Nesting:=0; FrameDepth:=0; NextSpan:=0; Spans:=FindMath(Source); P:=1; Result:=Part(P,Length(Source),False);
    try
      PrepareDefinitionBodies(Result,Scope); PrepareCommutativeDiagrams(Result,Scope,@ParagraphModel.ParseParagraph); Serial:=0; Number(Result);
    except Result.Free; raise; end;
  finally Scopes.Free; if OwnScope then Scope.Free; end;
end;

function InstrumentParagraph(Node:TMathNode):string;
var I,P:Integer; WordText,Command:string;
begin
  if Node.NativePackage or Node.LiteralArguments then Exit(Node.TeX);
  if Node.Kind in [mkDefinition,mkUnknownCommand,mkComment,mkVerbatim,mkDiagram] then Exit(Node.TeX);
  if IsLabelField(Node) then Exit(Node.TeX);
  if IsVerbatimField(Node) then Exit(Node.TeX);
  if Node.Kind=mkTextCommand then begin
    P:=1; Command:=ReadTeXCommand(Node.Text,P);
    { Structural controls must see their following tokens directly, and must
      not gain leavevmode/save-position nodes on either side of a forced break. }
    if (Command='\') or (Command='newline') or (Command='par') or
      (Command='linebreak') or (Command='nolinebreak') or (Command='pagebreak') or
      (Command='nopagebreak') or (Command='newpage') or (Command='clearpage') then Exit(Node.TeX);
  end;
  { A save-position whatsit on its own between displays can start an empty
    TeX paragraph. Whitespace has no printed field; retain it literally. }
  if (Node.Kind=mkProse) and (Trim(Node.Text)='') then Exit(Node.Text);
  if (Node.Kind=mkOptional) and (Node.TeX='') then Exit('');
  if Node.Kind=mkFormula then
    Exit(Node.Prefix+InstrumentMath(TMathNode(Node.Children[0]))+Node.Suffix);
  if Node.Kind in [mkProse,mkTextCommand] then
  begin
    WordText:=TrimRight(Node.Text);
    if WordText='' then
      Exit('\PasTeXTextPosition{'+IntToStr(Node.ID)+'}{S}'+Node.Text+
        '\PasTeXTextPosition{'+IntToStr(Node.ID)+'}{E}');
    Exit('\PasTeXTextField{'+IntToStr(Node.ID)+'}{'+WordText+Node.Suffix+'}'+
      Copy(Node.Text,Length(TrimRight(Node.Text))+1,MaxInt));
  end;
  Result:=Node.Prefix;
  if Node.Kind in [mkRaw,mkText,mkCommand] then Result:=Result+Node.Text;
  for I:=0 to Node.Children.Count-1 do Result:=Result+InstrumentParagraph(TMathNode(Node.Children[I]));
  Result:=Result+Node.Suffix;
end;
end.
