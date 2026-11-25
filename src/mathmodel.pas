unit MathModel;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Contnrs, TeXMacros, SourceRanges;
type
  TMathKind = (mkRow, mkText, mkFraction, mkRoot, mkSup, mkSub, mkGroup, mkRaw,
    mkCommand, mkOptional, mkEnvironment, mkMatrix, mkCases, mkAligned,
    mkIndexedRoot, mkAccent, mkBinomial, mkProse, mkFormula, mkTextCommand,
    mkTable, mkTableRow, mkTableCell, mkDefinition, mkUnknownCommand, mkComment, mkVerbatim, mkDiagram, mkSource);
  TMathNode = class
  public
    Kind: TMathKind;
    Text, Prefix, Suffix: string;
    Parent: TMathNode;
    PreviewOrigin:TMathNode; { non-owning source of a copied preview argument }
    SourcePreview:TMathNode;
    Children: TFPObjectList;
    ID,DefinitionArgument,PreviewChars,PreviewFirst,PreviewPrefix,PreviewSuffix,DiagramField: Integer;
    OptionalDefault,NativePackage,LiteralArguments,Hidden,PreviewAtomic,SourceEditing,SourceExpanded,SourceCollapsed,TextMode: Boolean;
    SourceStamp:QWord;
    SourceOffset,SourceLength:Integer;
    constructor Create(AKind: TMathKind; const AText: string = '');
    destructor Destroy; override;
    function Add(N: TMathNode): TMathNode;
    function TeX: string;
  end;
  TMathTextParser=function(const Source:string; Macros:TMacroRegistry):TMathNode;
  TMathSpan = record
    Start, Count: Integer;
    Environment: string;
    DisplayMath: Boolean;
  end;
  TMathSpans = array of TMathSpan;
  { Cache offsets only during a read pass; public tree edits remain valid
    outside the scope without retaining another serialized source string. }
  TMathSourceIndex=class
  private
    Previous:QWord;
  public
    constructor Create(Root:TMathNode);
    destructor Destroy; override;
  end;
  { A non-owning lookup for a parsed tree. Sparse external IDs fall back to
    the field list rather than allocating memory proportional to an ID. }
  TMathFieldIndex=class
  private
    FFields:TList;
    FNodes:array of TMathNode;
    FBase:Integer;
  public
    procedure Build(Fields:TList);
    function Find(ID:Integer):TMathNode;
  end;
function DefinitionNode(const Source:string):TMathNode;
procedure LiteralCommand(Node:TMathNode);
procedure AtomicCommand(Node:TMathNode);
function MathEnvironmentName(Node:TMathNode):string;
function MathPreviewNode(Node:TMathNode):TMathNode;
function IsFigureNode(Node:TMathNode):Boolean;
function IsBoxNode(Node:TMathNode):Boolean;
function ParseMath(const Source: string; out Root: TMathNode; out Error: string;
  Macros: TMacroRegistry = nil; Tolerant:Boolean=False; TextParser:TMathTextParser=nil): Boolean;
procedure PrepareCommutativeDiagrams(Node:TMathNode; Macros:TMacroRegistry; TextParser:TMathTextParser=nil);
function FindMath(const Source: string): TMathSpans;
function SymbolDisplay(const Command: string): string;
function IsNamedMathOperator(const Command:string):Boolean;
function MathOperatorHasLimits(const Command:string):Boolean;
function TextToTeX(const Value: string): string;
procedure MathFields(Root:TMathNode; Fields:TList);
procedure FoldMathSource(Root:TMathNode; const Ranges:TSourceRanges);
function InstrumentMath(Root:TMathNode):string;
function MathSourceOffset(N:TMathNode):Integer;
function MathSourceLength(N:TMathNode):Integer;
function ScriptBoundaryEnd(Root:TMathNode; Offset:Integer; IncludeBase:Boolean=False):Integer;
function MissingOptionalArgument(Node:TMathNode):TMathNode;
function OmitDefaultArgument(Root:TMathNode; var Caret:Integer; out ResumeCaret:Integer;
  CommandStart:Integer=-1; Anchor:PInteger=nil; Focus:PInteger=nil):Boolean;
function IsEmptyMathArgument(Node:TMathNode):Boolean;
function HasEmptyMathArgument(Node:TMathNode):Boolean;
function MathArgumentCount(const Command:string):Integer;
function IsStandaloneMathGroup(Node:TMathNode):Boolean;
function IsInlineFormula(Node:TMathNode):Boolean;
function HasStandaloneMathGroup(Node:TMathNode):Boolean;
function MathTemplate(Kind:TMathKind):string;
implementation
uses TeXFontData, TeXTables, CommandDefinition, TeXPackagePreview, MathCommands, CommutativeDiagrams, TeXBibliography, MathSpacing, BeamerModel;
threadvar ActiveSourceStamp,NextSourceStamp:QWord;
          TextParserDepth:Integer;
procedure LiteralCommand(Node:TMathNode);
var Code:string;
begin
  Code:=Node.TeX; Node.Children.Clear; Node.Kind:=mkUnknownCommand;
  Node.Text:=''; Node.Prefix:=''; Node.Suffix:=''; Node.NativePackage:=False;
  Node.Add(TMathNode.Create(mkProse,Code));
end;
procedure AtomicCommand(Node:TMathNode);
var Code:string;
begin
  Code:=Node.TeX; Node.Children.Clear; Node.Kind:=mkTextCommand;
  Node.Text:=Code; Node.Prefix:=''; Node.Suffix:=''; Node.NativePackage:=False;
end;
function MathPreviewNode(Node:TMathNode):TMathNode;
begin
  Result:=Node;
  while (Result<>nil) and (Result.Kind=mkSource) and (Result.SourcePreview<>nil) do Result:=Result.SourcePreview;
end;
function IsBoxNode(Node:TMathNode):Boolean;
var P:Integer; Name,Code:string;
begin
  Result:=False; if Node=nil then Exit;
  if not (Node.Kind in [mkCommand,mkTextCommand,mkGroup,mkUnknownCommand,mkEnvironment]) then Exit;
  if Node.Kind=mkEnvironment then Name:=Node.Text else begin
    Code:=Node.Text; if Code='' then Code:=Node.Prefix;
    if (Code='') and (Node.Children.Count>0) then Code:=TMathNode(Node.Children[0]).Text;
    P:=1; Name:=ReadTeXCommand(Code,P); if Name='begin' then Name:=ReadTeXGroup(Code,P,'{','}');
  end;
  Result:=(Name='mbox') or (Name='fbox') or (Name='makebox') or (Name='framebox') or
    (Name='parbox') or (Name='raisebox') or (Name='boxed') or (Name='colorbox') or
    (Name='fcolorbox') or (Name='hbox') or (Name='vbox') or (Name='vtop') or
    (Name='minipage') or (Name='tcolorbox');
end;
procedure TMathFieldIndex.Build(Fields:TList);
var I,Last:Integer; N:TMathNode; Span:Int64;
begin
  FFields:=Fields; FNodes:=nil; FBase:=MaxInt; Last:=Low(Integer);
  if Fields=nil then Exit;
  for I:=0 to Fields.Count-1 do begin
    N:=TMathNode(Fields[I]);
    if N.ID<FBase then FBase:=N.ID;
    if N.ID>Last then Last:=N.ID;
  end;
  Span:=Int64(Last)-FBase+1;
  if (Span<=0) or (Span>Int64(Fields.Count)*8) then Exit;
  SetLength(FNodes,Span);
  for I:=0 to Fields.Count-1 do begin
    N:=TMathNode(Fields[I]); FNodes[Int64(N.ID)-FBase]:=N;
  end;
end;
function TMathFieldIndex.Find(ID:Integer):TMathNode;
var I:Integer; Position:Int64;
begin
  Result:=nil;
  if Length(FNodes)>0 then begin
    Position:=Int64(ID)-FBase;
    if (Position>=0) and (Position<Length(FNodes)) then Result:=FNodes[Position];
    Exit;
  end;
  if FFields<>nil then for I:=0 to FFields.Count-1 do
    if TMathNode(FFields[I]).ID=ID then Exit(TMathNode(FFields[I]));
end;
function IsFigureNode(Node:TMathNode):Boolean;
var P:Integer; Source,Name,Command:string;
begin
  Result:=False; if Node=nil then Exit;
  if Node.Kind=mkDiagram then Exit(True);
  if Node.Kind=mkTextCommand then Exit((Pos('\includegraphics',Node.Text)=1) or (Pos('\includepdf',Node.Text)=1));
  if Node.Kind=mkEnvironment then Name:=Node.Text
  else if Node.Kind=mkUnknownCommand then begin
    Source:=Node.TeX; P:=1; SkipTeXSpace(Source,P);
    Command:=ReadTeXCommand(Source,P);
    if (Command='xymatrix') or (Copy(Command,1,9)='xymatrix@') then Exit(True);
    if Command<>'begin' then Exit;
    Name:=ReadTeXGroup(Source,P,'{','}');
  end else Exit;
  Result:=(Name='figure') or (Name='figure*') or (Name='wrapfigure') or (Name='tikzpicture') or (Name='circuitikz') or (Name='pgfpicture') or
    (Name='picture') or (Name='tikzcd') or (Name='xy');
end;
function OmitDefaultArgument(Root:TMathNode; var Caret:Integer; out ResumeCaret:Integer;
  CommandStart:Integer; Anchor:PInteger; Focus:PInteger):Boolean;
var Command,Current,Argument:TMathNode; I,First,Last:Integer; Blocked:Boolean;
  procedure Adjust(var Offset:Integer);
  begin
    if Offset>=Last then Dec(Offset,Last-First) else if Offset>=First then Offset:=First;
  end;
  function Content(Node:TMathNode):string;
  var J:Integer;
  begin Result:=''; for J:=0 to Node.Children.Count-1 do Result:=Result+TMathNode(Node.Children[J]).TeX; end;
  function AtCaret(Node:TMathNode):TMathNode;
  var J,A:Integer;
  begin
    Result:=nil;
    if (CommandStart>=0) and (Node.Kind=mkCommand) and (MathSourceOffset(Node)-Length(Node.Prefix)=CommandStart) then begin
      for J:=0 to Node.Children.Count-1 do begin
        Result:=TMathNode(Node.Children[J]);
        if (Result.Kind=mkOptional) and Result.OptionalDefault and (Result.Suffix=']') and (Content(Result)=Result.Text) then Exit;
      end;
      Result:=nil; Exit;
    end;
    if (Node.Kind=mkOptional) and Node.OptionalDefault and (Node.Suffix=']') and
       (Node.Parent<>nil) and (Node.Parent.Kind=mkCommand) then begin
      A:=MathSourceOffset(Node);
      if (Caret>=A) and (Caret<=A+Length(Content(Node))) then Exit(Node);
    end;
    if Node.Kind=mkDefinition then Exit;
    for J:=0 to Node.Children.Count-1 do begin
      Result:=AtCaret(TMathNode(Node.Children[J])); if Result<>nil then Exit;
    end;
  end;
begin
  Result:=False; ResumeCaret:=-1; Current:=AtCaret(Root);
  if (Current=nil) or (Content(Current)<>Current.Text) then Exit;
  Command:=Current.Parent; Blocked:=False;
  { Keep an earlier default when removing it would shift a later optional
    value into the wrong argument. Required arguments separate these runs. }
  for I:=Command.Children.Count-1 downto 0 do begin
    Argument:=TMathNode(Command.Children[I]);
    if Argument.Kind<>mkOptional then begin Blocked:=False; Continue; end;
    if Argument.Suffix<>']' then Continue;
    if Blocked or not Argument.OptionalDefault or (Content(Argument)<>Argument.Text) then begin Blocked:=True; Continue; end;
    First:=MathSourceOffset(Argument)-1; Last:=First+Length(Content(Argument))+2;
    if (Argument=Current) and (Caret>=First+1) and (Caret<Last) then ResumeCaret:=Caret-First-1;
    Adjust(Caret); if Anchor<>nil then Adjust(Anchor^); if Focus<>nil then Adjust(Focus^);
    Argument.Prefix:=Copy(Argument.Prefix,1,Length(Argument.Prefix)-1); Argument.Suffix:='';
    Argument.Children.Clear; Argument.Add(TMathNode.Create(mkText)); Result:=True;
  end;
end;
function MissingOptionalArgument(Node:TMathNode):TMathNode;
begin
  Result:=nil;
  while Node<>nil do begin
    if (Node.Kind=mkOptional) and (Node.Prefix='') and (Node.Parent<>nil) and
       (Node.Parent.Kind=mkCommand) then Exit(Node);
    Node:=Node.Parent;
  end;
end;
const
  Commands: array[0..28] of string = ('alpha','beta','gamma','delta','theta','lambda',
    'mu','pi','rho','sigma','phi','omega','infty','sum','prod','int','partial','nabla',
    'times','cdot','pm','leq','geq','neq','in','to','surd','varepsilon','Gamma');
  Symbols: array[0..28] of string = ('α','β','γ','δ','θ','λ','μ','π','ρ','σ','φ','ω',
    '∞','∑','∏','∫','∂','∇','×','·','±','≤','≥','≠','∈','→','√','ε','Γ');
constructor TMathNode.Create(AKind:TMathKind; const AText:string);
begin Kind:=AKind; Text:=AText; DefinitionArgument:=-1; DiagramField:=-1; PreviewChars:=-1; Children:=TFPObjectList.Create(True); end;
destructor TMathNode.Destroy;
begin SourcePreview.Free; Children.Free; inherited Destroy; end;
function TMathNode.Add(N:TMathNode):TMathNode;
begin
  if N=Self then raise EArgumentException.Create('A math node cannot contain itself');
  N.Parent:=Self; Children.Add(N); Result:=N;
end;
function TMathNode.TeX:string;
var I:Integer;
begin
  Result:=Prefix;
  if Kind in [mkText,mkRaw,mkCommand,mkProse,mkTextCommand] then Result:=Result+Text;
  for I:=0 to Children.Count-1 do Result:=Result+TMathNode(Children[I]).TeX;
  Result:=Result+Suffix;
end;
function MathEnvironmentName(Node:TMathNode):string;
var P:Integer; Source:string;
begin
  Result:=''; if Node=nil then Exit;
  Source:=Node.Prefix;
  if (Source='') and (Node.Kind in [mkUnknownCommand,mkDiagram]) then Source:=Node.TeX;
  P:=1; SkipTeXSpace(Source,P);
  if ReadTeXCommand(Source,P)='begin' then Result:=ReadTeXGroup(Source,P,'{','}');
  if (Result='') and (Node.Kind=mkDiagram) and (Copy(TrimLeft(Source),1,9)='\xymatrix') then Result:='xymatrix';
end;
function DefinitionNode(const Source:string):TMathNode;
var Definition:TCommandDefinition; Field,DefaultField:TMathNode; I,Previous:Integer;
begin
  Result:=TMathNode.Create(mkDefinition);
  if not ReadCommandDefinition(Source,Definition) then begin Result.Add(TMathNode.Create(mkProse,Source)); Exit; end;
  Result.Text:=Definition.Parameters;
  Field:=Result.Add(TMathNode.Create(mkProse,Definition.Name)); Field.Prefix:=Copy(Source,1,Definition.NameStart);
  Previous:=Definition.NameEnd;
  for I:=0 to High(Definition.Arguments) do if Definition.Arguments[I].DefaultStart>=0 then begin
    DefaultField:=Field.Add(TMathNode.Create(mkProse,Definition.Arguments[I].DefaultValue));
    DefaultField.DefinitionArgument:=I;
    DefaultField.Prefix:=Copy(Source,Previous+1,Definition.Arguments[I].DefaultStart-Previous);
    Previous:=Definition.Arguments[I].DefaultEnd;
  end;
  Field.Suffix:=Copy(Source,Previous+1,Definition.BodyStart-Previous);
  Field:=Result.Add(TMathNode.Create(mkProse,Definition.Body)); Field.Suffix:=Copy(Source,Definition.BodyEnd+1,MaxInt);
end;
function SymbolDisplay(const Command:string):string;
var I:Integer;
begin
  Result:=''; for I:=Low(Commands) to High(Commands) do if Commands[I]=Command then Exit(Symbols[I]);
  case Command of
    'colon':Result:=':';
    'varsigma':Result:='ς';
    'langle':Result:='⟨'; 'rangle':Result:='⟩';
    'lVert','rVert','Vert':Result:='‖';
    'lvert','rvert','vert':Result:='|';
    'epsilon':Result:='ε';
    'zeta':Result:='ζ';
    'eta':Result:='η';
    'iota':Result:='ι';
    'kappa':Result:='κ';
    'nu':Result:='ν';
    'xi':Result:='ξ';
    'omicron':Result:='ο';
    'upsilon':Result:='υ';
    'chi':Result:='χ';
    'psi':Result:='ψ';
    'tau':Result:='τ';
    'Delta':Result:='Δ';
    'Theta':Result:='Θ';
    'Lambda':Result:='Λ';
    'Xi':Result:='Ξ';
    'Pi':Result:='Π';
    'Sigma':Result:='Σ';
    'Upsilon':Result:='Υ';
    'Phi':Result:='Φ';
    'Psi':Result:='Ψ';
    'Omega':Result:='Ω';
    'nabla':Result:='∇';
    'cap':Result:='∩';
    'cup':Result:='∪';
    'setminus':Result:='∖';
    'subset':Result:='⊂';
    'subseteq':Result:='⊆';
    'supset':Result:='⊃';
    'supseteq':Result:='⊇';
    'notin':Result:='∉';
    'emptyset':Result:='∅';
    'forall':Result:='∀';
    'exists':Result:='∃';
    'neg':Result:='¬';
    'land':Result:='∧';
    'lor':Result:='∨';
    'oplus':Result:='⊕';
    'otimes':Result:='⊗';
    'div':Result:='÷';
    'mp':Result:='∓';
    'approx':Result:='≈';
    'equiv':Result:='≡';
    'sim':Result:='∼';
    'simeq':Result:='≃';
    'propto':Result:='∝';
    'le':Result:='≤';
    'ge':Result:='≥';
    'ne':Result:='≠';
    'll':Result:='≪';
    'gg':Result:='≫';
    'cdots':Result:='⋯';
    'ldots':Result:='…';
    'vdots':Result:='⋮';
    'ddots':Result:='⋱';
    'rightarrow':Result:='→';
    'leftarrow':Result:='←';
    'leftrightarrow':Result:='↔';
    'Rightarrow':Result:='⇒';
    'Leftarrow':Result:='⇐';
    'Leftrightarrow':Result:='⇔';
    'mapsto':Result:='↦';
    'infty':Result:='∞';
    'ell':Result:='ℓ';
    'hbar':Result:='ℏ';
    'Re':Result:='ℜ';
    'Im':Result:='ℑ';
    'aleph':Result:='ℵ';
    'prod':Result:='∏';
    'bigcup':Result:='⋃';
    'bigcap':Result:='⋂';
    'iint':Result:='∬';
    'iiint':Result:='∭';
    'oint':Result:='∮';
    'varepsilon':Result:='ϵ';
    'vartheta':Result:='ϑ';
    'varphi':Result:='ϕ';
    'varrho':Result:='ϱ';
    'varpi':Result:='ϖ';
    'sin','cos','tan','cot','sec','csc','arcsin','arccos','arctan','sinh','cosh','tanh','coth','log','ln','lg','exp','lim','limsup','liminf','max','min','sup','inf','det','dim','ker','gcd','hom','arg','deg','Pr':Result:=Command;
  end;
end;
function IsNamedMathOperator(const Command:string):Boolean;
var Name:string;
begin
  Name:=Command; if Copy(Name,1,1)='\' then Delete(Name,1,1);
  case Name of
    'sin','cos','tan','cot','sec','csc','arcsin','arccos','arctan','sinh','cosh','tanh','coth',
    'log','ln','lg','exp','lim','limsup','liminf','max','min','sup','inf','det','dim','ker','gcd','hom','arg','deg','Pr':Result:=True;
    else Result:=False;
  end;
end;
function MathOperatorHasLimits(const Command:string):Boolean;
begin
  { amsopn's qopname m operators use display limits; o operators use sides. }
  case Command of
    '\det','\gcd','\inf','\lim','\liminf','\limsup','\max','\min','\Pr','\sup',
    '\injlim','\projlim','\operatorname*','\mathop':Result:=True;
    else Result:=False;
  end;
end;
function TextToTeX(const Value:string):string;
var I:Integer;
begin
  Result:=Value;
  for I:=Low(Commands) to High(Commands) do
    Result:=StringReplace(Result,Symbols[I],'\'+Commands[I]+' ',[rfReplaceAll]);
end;
function MathSourceOffset(N:TMathNode):Integer;
var P:TMathNode; I:Integer;
begin
  if (ActiveSourceStamp<>0) and (N.SourceStamp=ActiveSourceStamp) then Exit(N.SourceOffset);
  Result:=Length(N.Prefix); P:=N.Parent;
  if P=nil then Exit;
  Inc(Result,MathSourceOffset(P));
  if P.Kind in [mkText,mkRaw,mkCommand,mkProse,mkTextCommand] then Inc(Result,Length(P.Text));
  for I:=0 to P.Children.Count-1 do
  begin if P.Children[I]=N then Break; Inc(Result,MathSourceLength(TMathNode(P.Children[I]))); end;
end;
function MathSourceLength(N:TMathNode):Integer;
var I:Integer;
begin
  if (ActiveSourceStamp<>0) and (N.SourceStamp=ActiveSourceStamp) then Exit(N.SourceLength);
  Result:=Length(N.Prefix)+Length(N.Suffix);
  if N.Kind in [mkText,mkRaw,mkCommand,mkProse,mkTextCommand] then Inc(Result,Length(N.Text));
  for I:=0 to N.Children.Count-1 do Inc(Result,MathSourceLength(TMathNode(N.Children[I])));
end;
function ScriptBoundaryEnd(Root:TMathNode; Offset:Integer; IncludeBase:Boolean):Integer;
var SourceIndex:TMathSourceIndex;
  function Script(Node:TMathNode):Boolean;
  begin Result:=(Node.Kind=mkGroup) and (Node.Prefix<>'') and (Node.Prefix[1] in ['^','_']); end;
  function Find(Node:TMathNode):Integer;
  var I,J,First,Last,Start,Finish:Integer; N:TMathNode; Boundary:Boolean;
  begin
    Result:=Offset; Start:=MathSourceOffset(Node)-Length(Node.Prefix);
    if (Offset<Start) or (Offset>Start+MathSourceLength(Node)) then Exit;
    I:=0;
    while I<Node.Children.Count do begin
      N:=TMathNode(Node.Children[I]);
      if Script(N) then begin
        First:=I; Last:=I; Boundary:=False;
        while Last+1<Node.Children.Count do begin
          N:=TMathNode(Node.Children[Last+1]);
          if Script(N) or ((N.Kind=mkText) and (Trim(N.Text)='')) then Inc(Last) else Break;
        end;
        for J:=First to Last do begin
          N:=TMathNode(Node.Children[J]); if not Script(N) then Continue;
          Start:=MathSourceOffset(N)-Length(N.Prefix); Finish:=Start+MathSourceLength(N);
          if (Offset=Start) and ((J>First) or IncludeBase) then Boundary:=True;
        end;
        if Boundary then Exit(Finish); I:=Last;
      end;
      Inc(I);
    end;
    for I:=0 to Node.Children.Count-1 do begin Result:=Find(TMathNode(Node.Children[I])); if Result<>Offset then Exit; end;
  end;
begin
  Result:=Offset; if Root=nil then Exit;
  SourceIndex:=TMathSourceIndex.Create(Root);
  try Result:=Find(Root); finally SourceIndex.Free; end;
end;
constructor TMathSourceIndex.Create(Root:TMathNode);
  function Index(Node:TMathNode; Offset:Integer):Integer;
  var I,ChildOffset:Integer; Child:TMathNode;
  begin
    Node.SourceOffset:=Offset+Length(Node.Prefix); Result:=Length(Node.Prefix);
    if Node.Kind in [mkText,mkRaw,mkCommand,mkProse,mkTextCommand] then Inc(Result,Length(Node.Text));
    for I:=0 to Node.Children.Count-1 do begin
      Child:=TMathNode(Node.Children[I]); ChildOffset:=Offset+Result;
      { Layout groups borrow fields from their original source tree. Keep
        those fields' source positions when indexing the temporary group. }
      if Child.Parent<>Node then ChildOffset:=MathSourceOffset(Child)-Length(Child.Prefix);
      Inc(Result,Index(Child,ChildOffset));
    end;
    Inc(Result,Length(Node.Suffix)); Node.SourceLength:=Result; Node.SourceStamp:=ActiveSourceStamp;
  end;
var Offset:Integer;
begin
  inherited Create; Previous:=ActiveSourceStamp;
  Offset:=MathSourceOffset(Root)-Length(Root.Prefix);
  Inc(NextSourceStamp); ActiveSourceStamp:=NextSourceStamp; Index(Root,Offset);
end;
destructor TMathSourceIndex.Destroy;
begin ActiveSourceStamp:=Previous; inherited Destroy; end;
function IsEmptyMathArgument(Node:TMathNode):Boolean;
var I,AtIndex,L,R:Integer; Row,Child:TMathNode;
  function Separator(N:TMathNode):Boolean;
  begin Result:=(N.Kind=mkRaw) and ((N.Text='&') or (Copy(N.Text,1,2)='\\')); end;
begin
  Result:=False;
  if (Node=nil) or (Node.Kind<>mkText) or (Trim(Node.Text)<>'') or
     (Node.Parent=nil) or (Node.Parent.Kind<>mkRow) then Exit;
  Row:=Node.Parent; AtIndex:=Row.Children.IndexOf(Node); L:=AtIndex; R:=AtIndex;
  while (L>0) and not Separator(TMathNode(Row.Children[L-1])) do Dec(L);
  while (R<Row.Children.Count-1) and not Separator(TMathNode(Row.Children[R+1])) do Inc(R);
  for I:=L to R do
  begin Child:=TMathNode(Row.Children[I]); if (Child.Kind<>mkText) or (Trim(Child.Text)<>'') then Exit; end;
  Result:=True;
end;
function HasEmptyMathArgument(Node:TMathNode):Boolean;
var I:Integer;
begin
  if IsEmptyMathArgument(Node) then Exit(True);
  for I:=0 to Node.Children.Count-1 do
    if HasEmptyMathArgument(TMathNode(Node.Children[I])) then Exit(True);
  Result:=False;
end;
function MathArgumentCount(const Command:string):Integer;
var Fill:TTeXFill;
begin
  if (Command='protect') or (Command='relax') or ReadHorizontalFill('\'+Command,Fill) then Exit(0);
  if Command='mathchoice' then Exit(4);
  if Command='bmod' then Exit(0);
  if (Command='mod') or (Command='pmod') or (Command='pod') then Exit(1);
  if (Command='crefrange') or (Command='Crefrange') then Exit(2);
  if IsLabelReference(Command) then Exit(1);
  Result:=-1;
  if IsExtensibleMathArrow(Command) or (Command='reallywidehat') then Exit(1);
  if (Command='xrightarrow') or (Command='xleftarrow') or
     (Command='overrightarrow') or (Command='overleftarrow') or (Command='overleftrightarrow') or
     (Command='underrightarrow') or (Command='underleftarrow') or (Command='underleftrightarrow') then Exit(1);
  if (Command='longrightarrow') or (Command='longleftarrow') or (Command='longleftrightarrow') or
     (Command='Longrightarrow') or (Command='Longleftarrow') or (Command='Longleftrightarrow') or
     (Command='mapsto') or (Command='longmapsto') or (Command='hookrightarrow') or (Command='hookleftarrow') or
     (Command='iff') or (Command='implies') or (Command='impliedby') then Exit(0);
  if (SymbolDisplay(Command)<>'') or (Command='quad') or (Command='qquad') or
     (Command='rm') or (Command='sf') or (Command='tt') or (Command='bf') or (Command='it') or
     (Command='thinspace') or (Command='medspace') or (Command='thickspace') or
     (Command='enspace') or (Command='enskip') or (Command='space') or
     (Command='negthinspace') or (Command='negmedspace') or (Command='negthickspace') then Exit(0);
  if (Command='frac') or (Command='dfrac') or (Command='tfrac') or
     (Command='binom') or (Command='dbinom') or (Command='tbinom') or
     (Command='overset') or (Command='underset') or (Command='stackrel') then Exit(2);
  if (Command='boxed') or (Command='hspace') or (Command='mspace') or (Command='sqrt') or (Command='hat') or (Command='bar') or (Command='vec') or
     (Command='textbf') or (Command='textit') or (Command='emph') or
     (Command='textsf') or (Command='texttt') or (Command='textrm') or (Command='textsc') or (Command='textsl') or
     (Command='textup') or (Command='textmd') or (Command='textnormal') or
     (Command='mathord') or (Command='mathop') or (Command='mathbin') or (Command='mathrel') or
     (Command='mathopen') or (Command='mathclose') or (Command='mathpunct') or (Command='mathinner') or
     (Command='overline') or (Command='underline') or (Command='widehat') or
     (Command='widetilde') or (Command='dot') or (Command='ddot') or
     (Command='overbrace') or (Command='underbrace') or (Command='mathrm') or
     (Command='boldsymbol') or (Command='bm') or (Command='mathbf') or (Command='mathit') or (Command='mathsf') or
     (Command='mathbb') or (Command='mathcal') or (Command='mathfrak') or
     (Command='mathtt') or (Command='mathscr') or (Command='tilde') or (Command='breve') or (Command='check') or (Command='acute') or (Command='grave') or (Command='ref') or (Command='eqref') or (Command='autoref') or (Command='text') or (Command='operatorname') or (Command='label') or (Command='tag') then Exit(1);
end;
function IsInlineFormula(Node:TMathNode):Boolean;
begin
  Result:=(Node.Kind=mkFormula) and ((Node.Prefix='') or (Node.Prefix='$') or
    (Node.Prefix='\(') or (Node.Prefix='\begin{math}'));
end;
function IsStandaloneMathGroup(Node:TMathNode):Boolean;
begin
  Result:=(Node<>nil) and (Node.Kind=mkGroup) and (Node.Prefix='{') and
    (Node.Parent<>nil) and (Node.Parent.Kind=mkRow);
end;
function HasStandaloneMathGroup(Node:TMathNode):Boolean;
var I:Integer;
begin
  if IsStandaloneMathGroup(Node) then Exit(True);
  for I:=0 to Node.Children.Count-1 do
    if HasStandaloneMathGroup(TMathNode(Node.Children[I])) then Exit(True);
  Result:=False;
end;
function MathTemplate(Kind:TMathKind):string;
begin
  case Kind of
    mkFraction: Result:='\frac{}{}'; mkRoot: Result:='\sqrt{}';
    mkSup: Result:='{}^{}'; mkSub: Result:='{}_{}';
    mkIndexedRoot: Result:='\sqrt[3]{}';
    mkMatrix: Result:='\begin{pmatrix}a & b \\ c & d\end{pmatrix}';
    mkCases: Result:='\begin{cases}x & x\geq 0 \\ -x & x<0\end{cases}';
    mkAligned: Result:='\begin{aligned}a &= b \\ c &= d\end{aligned}';
    mkAccent: Result:='\hat{}'; mkBinomial: Result:='\binom{n}{k}';
    else Result:='';
  end;
end;
type
  TMathParser = class
    Source:string;
    P,Depth:Integer;
    Tolerant,Closed:Boolean;
    Macros:TMacroRegistry;
    TextParser:TMathTextParser;
    Scopes:TList;
    function Row(const Stop:string):TMathNode;
    function Atom:TMathNode;
    function Group(OpenChar,CloseChar:Char):TMathNode;
    function ScopedGroup(const Prefix,Stop:string):TMathNode;
    function ArgumentGroup(OpenChar,CloseChar:Char; Literal:Boolean; TextMode:Boolean=False):TMathNode;
  end;
function TMathParser.ArgumentGroup(OpenChar,CloseChar:Char; Literal,TextMode:Boolean):TMathNode;
var Value:string;
begin
  TextMode:=TextMode and Assigned(TextParser);
  if not Literal and not TextMode then Exit(Group(OpenChar,CloseChar));
  Result:=TMathNode.Create(mkGroup); if OpenChar='[' then Result.Kind:=mkOptional;
  try
    Result.Prefix:=OpenChar; Value:=ReadTeXGroup(Source,P,OpenChar,CloseChar,True);
    if (P>1) and (Source[P-1]=CloseChar) then Result.Suffix:=CloseChar;
    Result.TextMode:=TextMode;
    if TextMode then begin
      { Text boxes can reenter the math parser through an inner $...$.
        Bound the whole callback chain, including its fresh parser objects. }
      if TextParserDepth>=32 then raise Exception.Create('Text/math nesting is too deep.');
      Inc(TextParserDepth);
      try Result.Add(TextParser(Value,Macros)); finally Dec(TextParserDepth); end;
    end else Result.Add(TMathNode.Create(mkText,Value));
  except Result.Free; raise; end;
end;
function TMathParser.Group(OpenChar,CloseChar:Char):TMathNode;
begin
  Inc(P); Result:=ScopedGroup(OpenChar,CloseChar); if OpenChar='[' then Result.Kind:=mkOptional;
end;
function TMathParser.ScopedGroup(const Prefix,Stop:string):TMathNode;
var Outer,Local:TMacroRegistry;
begin
  Result:=TMathNode.Create(mkGroup); Result.Prefix:=Prefix; Result.Suffix:=Stop;
  Outer:=Macros; Local:=nil;
  if Scopes<>nil then begin Local:=Macros.Clone; Macros:=Local; Scopes.Add(Local); end;
  try
    try Result.Add(Row(Stop)); if not Closed then Result.Suffix:=''; except Result.Free; raise; end;
  finally
    if Local<>nil then begin Scopes.Delete(Scopes.Count-1); Macros:=Outer; Local.Free; end;
  end;
end;
function TMathParser.Atom:TMathNode;
var A,Q,Count,I,Slot,NativeCount,First,After:Integer; Cmd,Env,Header,Family,DefaultValue,Engine,Error,Overlay,Role:string; Info:TMacroInfo; N:TMathNode; Known,NativeArrow:Boolean; ArgumentKind:Char;
begin
  if P>Length(Source) then Exit(TMathNode.Create(mkText));
  if Source[P]='{' then Exit(Group('{','}'));
  if Source[P]='\' then
  begin
    A:=P; Q:=P;
    Engine:='pdflatex'; if Macros<>nil then Engine:=Macros.Engine;
    if ReadEngineConditional(Source,Engine,Q,First,After,Macros) then begin
      Header:=Copy(Source,First,After-First);
      if not ParseMath(Header,Result,Error,Macros,True,TextParser) then Result:=TMathNode.Create(mkText,Header);
      Result.Prefix:=Copy(Source,P,First-P); Result.Suffix:=Copy(Source,After,Q-After); P:=Q;
      if (Macros<>nil) and ContainsTeXDefinitions(Header) then Macros.ApplyDefinitions(Header);
      Exit;
    end;
    if ReadTeXDefinition(Source,Q) then begin
      Result:=DefinitionNode(Copy(Source,P,Q-P)); P:=Q;
      if Macros<>nil then Macros.ApplyDefinitions(Result.TeX);
      Q:=1; Cmd:=ReadTeXCommand(Result.TeX,Q);
      if (Scopes<>nil) and ((Cmd='gdef') or (Cmd='xdef')) then
        for I:=0 to Scopes.Count-2 do TMacroRegistry(Scopes[I]).ApplyDefinitions(Result.TeX);
      Exit;
    end;
    A:=P; Cmd:=ReadTeXCommand(Source,P);
    if Cmd='begingroup' then Exit(ScopedGroup(Copy(Source,A,P-A),'\endgroup'));
    if (Macros<>nil) and Macros.Presentation and BeamerCommand(Cmd) then begin
      Role:=Cmd;
      if (Cmd='onslide') and (Copy(Source,P,1)='*') then begin Inc(P); Role:='only'; end
      else if (Cmd='onslide') and (Copy(Source,P,1)='+') then begin Inc(P); Role:='visible'; end;
      Overlay:=ReadBeamerOverlay(Source,P);
      if Cmd='pause' then ReadTeXGroup(Source,P,'[',']');
      Result:=TMathNode.Create(mkGroup,'@beamer:'+Role); Result.Prefix:=Copy(Source,A,P-A);
      Count:=1; if Cmd='alt' then Count:=2 else if Cmd='temporal' then Count:=3 else if Cmd='pause' then Count:=0;
      try
        for I:=1 to Count do begin
          Q:=P; SkipTeXSpace(Source,Q); if Q>Length(Source) then Break;
          if (Cmd='onslide') and (Source[Q]<>'{') then Break;
          Header:=Copy(Source,P,Q-P); P:=Q; N:=Atom(); N.Prefix:=Header+N.Prefix;
          if (N.Kind=mkGroup) and (N.Text='') then N.Text:='@beamer:argument'; Result.Add(N);
        end;
        if (Overlay='') and (Copy(Source,P,1)='<') then begin
          Q:=P; ReadBeamerOverlay(Source,P); Result.Suffix:=Copy(Source,Q,P-Q);
        end;
      except Result.Free; raise; end;
      Exit;
    end;
    if (Cmd='protect') or (Cmd='relax') then begin
      while (P<=Length(Source)) and (Source[P] in [' ',#9,#10,#13]) do Inc(P);
      Result:=TMathNode.Create(mkRaw,Copy(Source,A,P-A)); Result.Hidden:=True; Exit;
    end;
    if (Cmd='xymatrix') or (Copy(Cmd,1,9)='xymatrix@') then begin
      Q:=P; while (Q<=Length(Source)) and not (Source[Q] in ['{',#10,#13]) do Inc(Q);
      if Copy(Source,Q,1)='{' then begin ReadTeXGroup(Source,Q,'{','}'); P:=Q; end;
      Result:=TMathNode.Create(mkUnknownCommand);
      Result.Add(TMathNode.Create(mkProse,Copy(Source,A,P-A))); Exit;
    end;
    if Cmd='begin' then
    begin
      Env:=ReadTeXGroup(Source,P,'{','}');
      if Env='' then raise Exception.Create('An environment needs a name.');
      if not ((Env='matrix') or (Env='pmatrix') or (Env='bmatrix') or (Env='Bmatrix') or
        (Env='vmatrix') or (Env='Vmatrix') or (Env='smallmatrix') or (Env='array') or
        (Env='cases') or (Env='aligned') or (Env='alignedat') or (Env='gathered') or
        (Env='split') or (Env='alignat') or (Env='alignat*') or (Env='equation') or
        (Env='equation*') or (Env='align') or (Env='align*') or (Env='gather') or (Env='gather*') or
        (Env='multline') or (Env='multline*') or (Env='flalign') or (Env='flalign*') or
        (Env='eqnarray') or (Env='eqnarray*') or (Env='displaymath') or (Env='math')) then begin
        P:=EnvironmentEnd(Source,A,Env);
        if P<=Length(Source) then begin ReadTeXCommand(Source,P); ReadTeXGroup(Source,P,'{','}'); end;
        Result:=TMathNode.Create(mkUnknownCommand);
        Result.Add(TMathNode.Create(mkProse,Copy(Source,A,P-A))); Exit;
      end;
      if (Env='array') or (Env='alignedat') or (Env='alignat') or (Env='alignat*') then
      begin
        SkipTeXSpace(Source,P);
        if (P<=Length(Source)) and (Source[P]='[') then ReadTeXGroup(Source,P,'[',']');
        ReadTeXGroup(Source,P,'{','}');
      end;
      Header:=Copy(Source,A,P-A);
      Result:=TMathNode.Create(mkEnvironment,Env); Result.Prefix:=Header; Result.Suffix:='\end{'+Env+'}';
      try Result.Add(Row(Result.Suffix)); if not Closed then Result.Suffix:=''; except Result.Free; raise; end;
      Exit;
    end;
    if (Cmd='lvert') or (Cmd='lVert') or (Cmd='langle') then begin
      if Cmd='lvert' then Env:='\rvert' else if Cmd='lVert' then Env:='\rVert' else Env:='\rangle';
      { Pair only when a matching closing token exists; incomplete input remains editable. }
      if Pos(Env,Copy(Source,P,MaxInt))>0 then begin
        SkipTeXSpace(Source,P);
        Result:=TMathNode.Create(mkGroup); Result.Prefix:=Copy(Source,A,P-A);
        try Result.Add(Row(Env)); if Closed then begin
          Q:=P; SkipTeXSpace(Source,P); Result.Suffix:=Env+Copy(Source,Q,P-Q);
        end; except Result.Free; raise; end;
        Exit;
      end;
    end;
    if Cmd='left' then
    begin
      Q:=P; SkipTeXSpace(Source,Q);
      if Q<=Length(Source) then
        if Source[Q]='\' then ReadTeXCommand(Source,Q) else Inc(Q);
      SkipTeXSpace(Source,Q); P:=Q; Result:=TMathNode.Create(mkGroup); Result.Prefix:=Copy(Source,A,P-A);
      try
        Result.Add(Row('\right'));
        if Closed then
        begin
          A:=P-Length('\right'); Q:=P; SkipTeXSpace(Source,Q);
          if Q<=Length(Source) then
            if Source[Q]='\' then ReadTeXCommand(Source,Q) else Inc(Q);
          SkipTeXSpace(Source,Q); Result.Suffix:=Copy(Source,A,Q-A); P:=Q;
        end;
      except Result.Free; raise; end;
      Exit;
    end;
    Result:=TMathNode.Create(mkCommand,Copy(Source,A,P-A));
    try
      { A delimiter modifier and its following token are indivisible. }
      if (Cmd='left') or (Cmd='right') or (Cmd='middle') or
         (Cmd='big') or (Cmd='Big') or (Cmd='bigg') or (Cmd='Bigg') or
         (Cmd='bigl') or (Cmd='bigr') or (Cmd='bigm') or (Cmd='Bigl') or (Cmd='Bigr') or (Cmd='Bigm') or
         (Cmd='biggl') or (Cmd='biggr') or (Cmd='biggm') or (Cmd='Biggl') or (Cmd='Biggr') or (Cmd='Biggm') then
      begin
        Q:=P; SkipTeXSpace(Source,Q);
        if Q<=Length(Source) then
          if Source[Q]='\' then ReadTeXCommand(Source,Q) else Inc(Q);
        Result.Text:=Result.Text+Copy(Source,P,Q-P); P:=Q; Result.Kind:=mkRaw; Exit;
      end;
      { Structural controls must stay outside instrumented math boxes. }
      if Cmd='\' then
      begin
        Q:=P; if (Q<=Length(Source)) and (Source[Q]='*') then Inc(Q);
        SkipTeXSpace(Source,Q);
        if (Q<=Length(Source)) and (Source[Q]='[') then ReadTeXGroup(Source,Q,'[',']');
        Result.Text:=Result.Text+Copy(Source,P,Q-P); P:=Q; Result.Kind:=mkRaw; Exit;
      end;
      if (Cmd='left') or (Cmd='right') or (Cmd='middle') or
         (Cmd='limits') or (Cmd='nolimits') or (Cmd='displaylimits') or (Cmd='displaystyle') or
         (Cmd='textstyle') or (Cmd='scriptstyle') or (Cmd='scriptscriptstyle') or
         (Cmd='notag') or (Cmd='nonumber') then
      begin Result.Kind:=mkRaw; Exit; end;
      if (P<=Length(Source)) and (Source[P]='*') and
         ((Cmd='operatorname') or (Cmd='tag')) then begin Result.Text:=Result.Text+'*'; Inc(P); end;
      Count:=-1; Info:=nil;
      if (Length(Cmd)=1) and not (Cmd[1] in ['a'..'z','A'..'Z']) then Count:=0;
      if (Cmd='hspace') and (Copy(Source,P,1)='*') then begin Cmd:=Cmd+'*'; Result.Text:=Result.Text+'*'; Inc(P); end;
      if Macros<>nil then Info:=Macros.Find(Cmd);
      NativeArrow:=IsExtensibleMathArrow(Cmd) and ((Info=nil) or (Info.PackageSource<>'') or (Info.Body=''));
      Result.NativePackage:=(Info<>nil) and (Info.PreviewName<>'');
      if (Info<>nil) and (Info.PreviewAdapter='derivative') and (Copy(Source,P,1)='*') then begin
        Result.Text:=Result.Text+'*'; Inc(P);
      end;
      if Info<>nil then Count:=Info.ArgCount;
      NativeCount:=MathArgumentCount(Cmd);
      if (NativeCount>=0) and ((Info=nil) or (Info.PackageSource<>'') or (Info.Body='')) then Count:=NativeCount;
      Known:=(NativeCount>=0) or ((Length(Cmd)=1) and not (Cmd[1] in ['a'..'z','A'..'Z'])) or
        (Cmd='TeX') or (Cmd='LaTeX') or TeXSymbol('\'+Cmd,Family,Slot);
      if Known and (Count<0) then Count:=0;
      if Info<>nil then Known:=Known or Info.Expandable or (Info.GlyphFont<>'') or (Info.GlyphPlan<>'');
      if (Info<>nil) and Info.Undefined and (Info.PackageSource='') then begin Known:=False; Count:=0; end;
      I:=0;
      if (Info<>nil) and (Info.Signature<>'') then begin
        Count:=PackageArgumentCount(Info.PreviewAdapter,Source,P,Info.ArgCount);
        for I:=1 to Count do begin
          if (Info.PreviewAdapter='derivative') and (I=3) then begin
            Q:=P; SkipTeXSpace(Source,Q);
            while (Q<=Length(Source)) and (Source[Q] in ['/','!']) do Inc(Q);
            if Trim(Copy(Source,P,Q-P))<>'' then begin Result.Add(TMathNode.Create(mkRaw,Copy(Source,P,Q-P))); P:=Q; end;
          end;
          ArgumentKind:=Info.ArgumentKind(I,DefaultValue); Q:=P; SkipTeXSpace(Source,Q); Header:=Copy(Source,P,Q-P);
          if ArgumentKind in ['o','O'] then begin
            if Copy(Source,Q,1)='[' then begin P:=Q; N:=ArgumentGroup('[',']',PackageLiteralArgument(Info.PreviewAdapter,Info.PreviewName,I)); N.Prefix:=Header+N.Prefix; N.Text:=DefaultValue; end
            else begin
              N:=TMathNode.Create(mkOptional,DefaultValue); N.Add(TMathNode.Create(mkText));
            end;
            N.OptionalDefault:=ArgumentKind='O';
          end else if Copy(Source,Q,1)='{' then begin
            P:=Q; N:=ArgumentGroup('{','}',PackageLiteralArgument(Info.PreviewAdapter,Info.PreviewName,I),
              ((Info.PreviewAdapter='box') or (Info.PreviewAdapter='diagbox') or
               (Info.PreviewAdapter='adjustbox') or (Info.PreviewAdapter='colorbox')) and
              PackageVisibleArgument(Info.PreviewAdapter,Info.PreviewName,I));
            N.Prefix:=Header+N.Prefix;
          end
          else if (Q<=Length(Source)) and not (Source[Q] in ['}','&','^','_']) then begin
            P:=Q;
            if (Info.PreviewAdapter='mathpalette') and (I=1) and (Source[P]='\') then begin
              ReadTeXCommand(Source,P); N:=TMathNode.Create(mkText,Copy(Source,Q,P-Q));
            end else N:=Atom();
            N.Prefix:=Header+N.Prefix;
          end
          else Break;
          if Info.PreviewName<>'' then N.Hidden:=not PackageVisibleArgument(Info.PreviewAdapter,Info.PreviewName,I);
          Result.Add(N);
        end;
        Count:=Result.Children.Count;
        for I:=0 to Result.Children.Count-1 do if TMathNode(Result.Children[I]).Kind=mkRaw then Dec(Count);
        if (Result.NativePackage and (Count<Info.ArgCount)) or
           not PackagePreviewSupported(Info.PreviewAdapter,Info.PreviewName,Result.TeX) then begin
          LiteralCommand(Result);
        end;
        if (Result.Kind=mkCommand) and (Info.PreviewAdapter='space') then begin
          Header:=Result.TeX; Result.Children.Clear; Result.Text:=Header;
        end;
        if (Info.PreviewAdapter='metadata') or (Info.PreviewAdapter='directive') then LiteralCommand(Result);
        if Info.PreviewAdapter='savedbox' then AtomicCommand(Result);
        Exit;
      end;
      if (Cmd='sqrt') or NativeArrow or ((Info<>nil) and Info.OptionalFirst) then
      begin
        Q:=P; SkipTeXSpace(Source,Q);
        if (Q<=Length(Source)) and (Source[Q]='[') then
        begin
          Header:=Copy(Source,P,Q-P); P:=Q; N:=Group('[',']'); N.Prefix:=Header+N.Prefix;
          if (Info<>nil) and Info.OptionalFirst and (Cmd<>'sqrt') and
             not NativeArrow then begin
            Info.ArgumentKind(1,N.Text); N.OptionalDefault:=True;
          end;
          Result.Add(N);
        end else if (Info<>nil) and Info.OptionalFirst and (Cmd<>'sqrt') and
          not NativeArrow then begin
          Info.ArgumentKind(1,DefaultValue); N:=TMathNode.Create(mkOptional,DefaultValue);
          N.OptionalDefault:=True; N.Add(TMathNode.Create(mkText)); Result.Add(N);
        end;
        if (Info<>nil) and Info.OptionalFirst and (Cmd<>'sqrt') and not NativeArrow then Dec(Count);
      end;
      while (Count<0) or (I<Count) do
      begin
        Q:=P; SkipTeXSpace(Source,Q); Header:=Copy(Source,P,Q-P);
        if (Q<=Length(Source)) and (Source[Q]='{') then
        begin P:=Q; N:=Group('{','}'); N.Prefix:=Header+N.Prefix; Result.Add(N); Inc(I); end
        else if (Count<0) and (Q<=Length(Source)) and (Source[Q]='[') then
        begin P:=Q; N:=Group('[',']'); N.Prefix:=Header+N.Prefix; Result.Add(N); end
        else if (Count>0) and (Q<=Length(Source)) and not (Source[Q] in ['}','&','^','_']) then
        begin P:=Q; N:=Atom(); N.Prefix:=Header+N.Prefix; Result.Add(N); Inc(I); end
        else Break;
      end;
      if (Cmd='hspace') or (Cmd='mspace') then begin
        Header:=Result.TeX; Result.Children.Clear; Result.Text:=Header;
      end;
      if IsLabelReference(Cmd) then
      begin Header:=Result.TeX; Result.Children.Clear; Result.Kind:=mkTextCommand; Result.Text:=Header; end;
      if ((Cmd='label') or (Cmd='tag')) and (Result.Children.Count>0) then
      begin
        N:=TMathNode(Result.Children[0]); Header:=N.TeX;
        Header:=Copy(Header,Length(N.Prefix)+1,Length(Header)-Length(N.Prefix)-Length(N.Suffix));
        N.Children.Clear; N.Add(TMathNode.Create(mkText,Header));
      end;
      if not Known then begin
        Header:=Copy(Source,A,P-A); Result.Children.Clear; Result.Kind:=mkUnknownCommand; Result.Text:='';
        Result.Add(TMathNode.Create(mkProse,Header));
      end;
    except Result.Free; raise; end;
    Exit;
  end;
  if Source[P] in ['^','_'] then
  begin
    Result:=TMathNode.Create(mkGroup); Result.Prefix:=Source[P]; Inc(P);
    try
      Q:=P; SkipTeXSpace(Source,Q); Result.Prefix:=Result.Prefix+Copy(Source,P,Q-P); P:=Q;
      if (P>Length(Source)) and not Tolerant then raise Exception.Create('A script needs an argument.');
      Result.Add(Atom());
    except Result.Free; raise; end;
    Exit;
  end;
  if Source[P]='}' then
    if Tolerant then begin Inc(P); Exit(TMathNode.Create(mkText,'}')); end
    else raise Exception.Create('Unmatched closing brace.');
  if Source[P]='%' then
  begin
    A:=P; while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P);
    if P<=Length(Source) then Inc(P);
    Result:=TMathNode.Create(mkComment); Result.Add(TMathNode.Create(mkProse,Copy(Source,A,P-A))); Exit;
  end;
  if Source[P]='&' then begin Inc(P); Exit(TMathNode.Create(mkRaw,'&')); end;
  A:=P; Inc(P);
  while (P<=Length(Source)) and ((Ord(Source[P]) and $C0)=$80) do Inc(P);
  Result:=TMathNode.Create(mkText,Copy(Source,A,P-A));
end;
function TMathParser.Row(const Stop:string):TMathNode;
var N,Previous:TMathNode;
begin
  Inc(Depth);
  if Depth>128 then begin Dec(Depth); raise Exception.Create('Formula nesting is too deep.'); end;
  try
  Result:=TMathNode.Create(mkRow);
  try
    while P<=Length(Source) do
    begin
      if (Stop<>'') and (Copy(Source,P,Length(Stop))=Stop) and
         ((Stop<>'\right') or (P+Length(Stop)>Length(Source)) or
          not (Source[P+Length(Stop)] in ['a'..'z','A'..'Z'])) then
      begin Closed:=True; Inc(P,Length(Stop)); if (Result.Children.Count=0) or ((TMathNode(Result.Children.Last).Kind=mkRaw) and
        ((TMathNode(Result.Children.Last).Text='&') or (Copy(TMathNode(Result.Children.Last).Text,1,2)='\\'))) then Result.Add(TMathNode.Create(mkText)); Exit; end;
      N:=Atom();
      if (N.Kind=mkRaw) and ((N.Text='&') or (Copy(N.Text,1,2)='\\')) then
        if (Result.Children.Count=0) or ((TMathNode(Result.Children.Last).Kind=mkRaw) and
           ((TMathNode(Result.Children.Last).Text='&') or (Copy(TMathNode(Result.Children.Last).Text,1,2)='\\'))) then
          Result.Add(TMathNode.Create(mkText));
      if (N.Kind=mkText) and (Result.Children.Count>0) and
         (TMathNode(Result.Children.Last).Kind=mkText) and
         (N.Text<>'') and (TMathNode(Result.Children.Last).Text<>'') and
         ((N.Text[1] in ['0'..'9']) = (TMathNode(Result.Children.Last).Text[1] in ['0'..'9'])) and
         (Pos(N.Text,'+-=<>*/:()[],;|')=0) and
         (Pos(TMathNode(Result.Children.Last).Text,'+-=<>*/:()[],;|')=0) then
      begin Previous:=TMathNode(Result.Children.Last); Previous.Text:=Previous.Text+N.Text; N.Free; end
      else Result.Add(N);
    end;
    Closed:=False;
    if (Stop<>'') and not Tolerant then raise Exception.Create('Unclosed group or environment: '+Stop);
    if Result.Children.Count=0 then Result.Add(TMathNode.Create(mkText));
  except Result.Free; raise; end;
  finally Dec(Depth); end;
end;
procedure AddInsertionSlots(N:TMathNode);
var I:Integer; Slot,Child:TMathNode;
  function EditableText(Node:TMathNode):Boolean;
  begin
    Result:=(Node.Kind=mkText) and ((Node.Text='') or (Trim(Node.Text)<>'') or IsEmptyMathArgument(Node));
  end;
begin
  for I:=0 to N.Children.Count-1 do AddInsertionSlots(TMathNode(N.Children[I]));
  if N.Kind<>mkRow then Exit;
  for I:=N.Children.Count-1 downto 0 do
  begin
    Child:=TMathNode(N.Children[I]);
    if (Child.Kind=mkGroup) and (Child.Prefix<>'') and ((Child.Prefix[1] in ['^','_','{']) or (Pos('\left',Child.Prefix)=1) or (Trim(Child.Prefix)='\lvert') or (Trim(Child.Prefix)='\lVert') or (Trim(Child.Prefix)='\langle')) then
      if (I=N.Children.Count-1) or not EditableText(TMathNode(N.Children[I+1])) then
      begin Slot:=TMathNode.Create(mkText); Slot.Parent:=N; N.Children.Insert(I+1,Slot); end;
    Child:=TMathNode(N.Children[I]);
    if (Child.Kind in [mkCommand,mkDefinition,mkUnknownCommand]) or (Child.Kind=mkEnvironment) or
       ((Child.Kind=mkGroup) and (Child.Prefix<>'') and
        ((Child.Prefix[1] in ['^','_','{']) or (Pos('\left',Child.Prefix)=1) or
         (Trim(Child.Prefix)='\lvert') or (Trim(Child.Prefix)='\lVert') or (Trim(Child.Prefix)='\langle'))) then
      if (I=0) or not EditableText(TMathNode(N.Children[I-1])) then
      begin
        Slot:=TMathNode.Create(mkText); Slot.Parent:=N; N.Children.Insert(I,Slot);
      end;
  end;
  if (N.Children.Count>0) and not EditableText(TMathNode(N.Children.Last)) then
    N.Add(TMathNode.Create(mkText));
end;
procedure NumberNodes(N:TMathNode; var ID:Integer);
var I:Integer;
begin N.ID:=ID; Inc(ID); for I:=0 to N.Children.Count-1 do NumberNodes(TMathNode(N.Children[I]),ID); end;
function ParseMath(const Source:string; out Root:TMathNode; out Error:string; Macros:TMacroRegistry; Tolerant:Boolean; TextParser:TMathTextParser):Boolean;
var P:TMathParser; ID:Integer; Local:TMacroRegistry;
begin
  Root:=nil; Error:=''; Result:=False; P:=TMathParser.Create;
  try
    Local:=nil; P.Source:=Source; P.P:=1; P.Macros:=Macros; P.Tolerant:=Tolerant; P.TextParser:=TextParser;
    if ContainsTeXDefinitions(Source) then begin
      if Macros<>nil then Local:=Macros.Clone else begin Local:=TMacroRegistry.Create; Local.Load('',GetCurrentDir); end;
      P.Macros:=Local; P.Scopes:=TList.Create; P.Scopes.Add(Local);
    end;
    try Root:=P.Row(''); PrepareCommutativeDiagrams(Root,P.Macros,TextParser); AddInsertionSlots(Root); ID:=0; NumberNodes(Root,ID); Result:=True;
    except on E:Exception do begin FreeAndNil(Root); Error:=E.Message; end; end;
  finally P.Scopes.Free; Local.Free; P.Free; end;
end;
procedure PrepareCommutativeDiagrams(Node:TMathNode; Macros:TMacroRegistry; TextParser:TMathTextParser);
var Model:TCommutativeDiagram; I,Start:Integer; Code,Error:string; Field:TCommutativeField; Formula,Body:TMathNode;
begin
  if Node.Kind=mkDiagram then Exit;
  if (Node.Kind=mkUnknownCommand) and IsCommutativeDiagram(Node.TeX) then begin
    Model:=TCommutativeDiagram.Create;
    try
      Code:=Node.TeX; if not Model.Load(Code) then Exit;
      Node.Kind:=mkDiagram; Node.Text:=Model.PackageName; Node.Prefix:=''; Node.Suffix:=''; Node.Children.Clear; Start:=0;
      for I:=0 to High(Model.Fields) do begin
        Field:=Model.Fields[I];
        if Field.First<Start then Continue;
        if Field.First>Start then Node.Add(TMathNode.Create(mkRaw,Copy(Code,Start+1,Field.First-Start)));
        Formula:=Node.Add(TMathNode.Create(mkFormula)); Formula.DiagramField:=I;
        if not ParseMath(Copy(Code,Field.First+1,Field.Last-Field.First),Body,Error,Macros,True,TextParser) then
          Body:=TMathNode.Create(mkText,Copy(Code,Field.First+1,Field.Last-Field.First));
        Formula.Add(Body); Start:=Field.Last;
      end;
      if Start<Length(Code) then Node.Add(TMathNode.Create(mkRaw,Copy(Code,Start+1,MaxInt)));
    finally Model.Free; end;
    Exit;
  end;
  for I:=0 to Node.Children.Count-1 do PrepareCommutativeDiagrams(TMathNode(Node.Children[I]),Macros,TextParser);
end;
procedure FoldMathSource(Root:TMathNode; const Ranges:TSourceRanges);
var Index:TMathSourceIndex;
  procedure Hide(Node:TMathNode);
  var Text:string;
  begin
    Text:=Node.TeX; Node.Children.Clear; FreeAndNil(Node.SourcePreview);
    Node.Kind:=mkRaw; Node.Text:=Text; Node.Prefix:=''; Node.Suffix:=''; Node.Hidden:=True;
  end;
  procedure Visit(Node:TMathNode);
  var R:TSourceRange; A,B,I,P,Q:Integer; Text:string; Kind:TMathKind; Child:TMathNode;
  begin
    A:=MathSourceOffset(Node)-Length(Node.Prefix); B:=A+MathSourceLength(Node);
    for R in Ranges do if (R.Start<=A) and (R.Finish>=B) then begin Hide(Node); Exit; end;
    if (Node.Kind in [mkProse,mkText]) and (Node.Children.Count=0) then begin
      Inc(A,Length(Node.Prefix)); Text:=Node.Text; Kind:=Node.Kind; P:=0;
      for R in Ranges do if (R.Finish>A) and (R.Start<A+Length(Text)) then begin
        Q:=R.Start-A; if Q<0 then Q:=0; if Q<P then Q:=P;
        if Q>P then Node.Add(TMathNode.Create(Kind,Copy(Text,P+1,Q-P)));
        P:=R.Finish-A; if P>Length(Text) then P:=Length(Text);
        Child:=Node.Add(TMathNode.Create(mkRaw,Copy(Text,Q+1,P-Q))); Child.Hidden:=True;
      end;
      if Node.Children.Count>0 then begin
        if P<Length(Text) then Node.Add(TMathNode.Create(Kind,Copy(Text,P+1,MaxInt)));
        Node.Kind:=mkRow; Node.Text:='';
      end;
    end else for I:=0 to Node.Children.Count-1 do Visit(TMathNode(Node.Children[I]));
  end;
begin
  if Length(Ranges)=0 then Exit;
  Index:=TMathSourceIndex.Create(Root);
  try Visit(Root); finally Index.Free; end;
end;
procedure MathFields(Root:TMathNode; Fields:TList);
var I:Integer;
begin
  if Root.Hidden then Exit;
  if (Root.Kind=mkText) and (Root.Text<>'') and (Trim(Root.Text)='') and
     not IsEmptyMathArgument(Root) then Exit;
  if (Root.Kind in [mkText,mkProse,mkTextCommand]) or
     ((Root.Kind=mkCommand) and (Root.Children.Count=0)) then Fields.Add(Root);
  for I:=0 to Root.Children.Count-1 do MathFields(TMathNode(Root.Children[I]),Fields);
end;
function InstrumentText(Node:TMathNode):string;
var I:Integer;
begin
  if (Node.Kind=mkText) and (Node.Text<>'') then
    Exit('\PasTeXTextField{'+IntToStr(Node.ID)+'}{'+Node.Text+'}');
  Result:=Node.Prefix;
  if Node.Kind in [mkText,mkRaw,mkCommand,mkTextCommand] then Result:=Result+Node.Text;
  for I:=0 to Node.Children.Count-1 do Result:=Result+InstrumentText(TMathNode(Node.Children[I]));
  Result:=Result+Node.Suffix;
end;
function InstrumentMath(Root:TMathNode):string;
var I:Integer; Cmd:string; Transparent,Hidden:Boolean;
begin
  if Root.NativePackage then Exit(Root.TeX);
  if Root.Kind in [mkDefinition,mkUnknownCommand,mkComment,mkDiagram] then Exit(Root.TeX);
  if IsEmptyMathArgument(Root) then Exit(Root.TeX);
  Cmd:=Root.Text;
  if (Root.Kind=mkCommand) and (Cmd='\text') then Exit(InstrumentText(Root));
  { Preserve native operator noads, italic correction and limit placement. }
  if (Root.Kind=mkCommand) and ((Cmd='\sum') or (Cmd='\prod') or
     (Cmd='\int') or (Cmd='\iint') or (Cmd='\iiint') or (Cmd='\oint') or
     (Cmd='\lim') or (Cmd='\bigcup') or (Cmd='\bigcap')) then
    Exit('\PasTeXOperator{'+IntToStr(Root.ID)+'}{'+Root.TeX+'}');
  Transparent:=(Cmd='\frac') or (Cmd='\dfrac') or (Cmd='\tfrac') or (Cmd='\sqrt') or
    (Cmd='\bmod') or (Cmd='\mod') or (Cmd='\pmod') or (Cmd='\pod') or
    (Cmd='\underbrace') or (Cmd='\overbrace') or
    (Cmd='\binom') or (Cmd='\dbinom') or (Cmd='\tbinom') or
    (Cmd='\overset') or (Cmd='\underset') or (Cmd='\stackrel');
  Hidden:=(Cmd='\label') or (Cmd='\tag') or (Cmd='\tag*');
  if Hidden then Exit(Root.TeX);
  if (Root.Kind=mkTextCommand) or ((Root.Kind=mkText) and (Trim(Root.Text)<>'')) or
     ((Root.Kind=mkCommand) and not Transparent and not Hidden) then
  begin
    Result:='\PasTeXField{'+IntToStr(Root.ID)+'}{'+Root.TeX+'}';
    if (Cmd='\sin') or (Cmd='\cos') or (Cmd='\tan') or (Cmd='\log') or (Cmd='\ln') or (Cmd='\exp') then
      Result:='\mathop{'+Result+'}\nolimits';
    if (Cmd='+') or (Cmd='-') or (Cmd='\times') or (Cmd='\cdot') or (Cmd='\pm') then Result:='\mathbin{'+Result+'}';
    if (Cmd='=') or (Cmd='<') or (Cmd='>') or (Cmd='\leq') or (Cmd='\geq') or (Cmd='\neq') or (Cmd='\in') or (Cmd='\to') then Result:='\mathrel{'+Result+'}';
    Exit;
  end;
  if (Root.Kind=mkText) and (Trim(Root.Text)='') then
    Exit(Root.TeX);
  Result:=Root.Prefix;
  if Root.Kind in [mkText,mkRaw,mkCommand,mkTextCommand] then Result:=Result+Root.Text;
  for I:=0 to Root.Children.Count-1 do
    if (Transparent or (Root.Prefix='^') or (Root.Prefix='_')) and
       not (TMathNode(Root.Children[I]).Kind in [mkGroup,mkOptional]) then
      Result:=Result+'{'+InstrumentMath(TMathNode(Root.Children[I]))+'}'
    else Result:=Result+InstrumentMath(TMathNode(Root.Children[I]));
  Result:=Result+Root.Suffix;
end;
function FindMath(const Source: string): TMathSpans;
var I,J,A,B,N,GroupDepth,Fallback:Integer; OpenToken,CloseToken,Env:string;
begin
  Result := nil; I := 1;
  while I <= Length(Source) do
  begin
    if Source[I] = '%' then
    begin while (I <= Length(Source)) and (Source[I] <> #10) do Inc(I); Continue; end;
    if Source[I]='\' then begin
      J:=I; if ReadTeXDefinition(Source,J) or SkipTeXLiteral(Source,J) then begin I:=J; Continue; end;
      J:=I; Env:=ReadTeXCommand(Source,J);
      if (Env='url') or (Env='nolinkurl') or (Env='href') then begin
        if Env='href' then ReadTeXGroup(Source,J,'[',']');
        ReadTeXGroup(Source,J,'{','}',True); I:=J; Continue;
      end;
    end;
    OpenToken := ''; CloseToken := ''; Env:='';
    if Source[I] = '$' then
    begin
      OpenToken := '$';
      if Copy(Source,I,2) = '$$' then OpenToken := '$$';
      CloseToken := OpenToken;
    end
    else if (Copy(Source,I,2) = '\(') or (Copy(Source,I,2) = '\[') then
    begin
      OpenToken := Copy(Source,I,2); CloseToken := '\)';
      if OpenToken = '\[' then CloseToken := '\]';
    end
    else if Copy(Source,I,7) = '\begin{' then
    begin
      J := I + 7; while (J <= Length(Source)) and (Source[J] <> '}') do Inc(J);
      Env := Copy(Source,I+7,J-I-7);
      if (Env='equation') or (Env='equation*') or (Env='align') or
         (Env='align*') or (Env='gather') or (Env='gather*') or
         (Env='displaymath') or (Env='math') or (Env='multline') or (Env='multline*') or (Env='flalign') or (Env='flalign*') or (Env='eqnarray') or (Env='eqnarray*') or (Env='alignat') or (Env='alignat*') then
      begin OpenToken := Copy(Source,I,J-I+1); CloseToken := '\end{' + Env + '}'; end;
    end;
    if OpenToken <> '' then
    begin
      A := I + Length(OpenToken); B := A; GroupDepth:=0; Fallback:=0;
      while B <= Length(Source) do
      begin
        if Copy(Source,B,Length(CloseToken)) = CloseToken then begin
          if GroupDepth=0 then Break;
          if Fallback=0 then Fallback:=B;
        end;
        if Source[B] = '%' then
          while (B <= Length(Source)) and (Source[B] <> #10) do Inc(B)
        else if Source[B] = '\' then begin
          J:=B; if SkipTeXLiteral(Source,J) then begin B:=J; Continue; end;
          Inc(B);
        end else if Source[B]='{' then Inc(GroupDepth)
        else if (Source[B]='}') and (GroupDepth>0) then Dec(GroupDepth);
        Inc(B);
      end;
      { Keep incomplete groups editable while preferring the outer delimiter
        for valid nested text/math boxes. }
      if (B>Length(Source)) and (Fallback>0) then B:=Fallback;
      if B <= Length(Source) then
      begin
        N := Length(Result); SetLength(Result,N+1);
        Result[N].Start := A; Result[N].Count := B-A;
        Result[N].Environment:=Env; Result[N].DisplayMath:=(OpenToken<>'$') and (OpenToken<>'\(') and (Env<>'math');
        I := B + Length(CloseToken); Continue;
      end;
    end;
    if Source[I] = '\' then Inc(I);
    Inc(I);
  end;
end;
end.
