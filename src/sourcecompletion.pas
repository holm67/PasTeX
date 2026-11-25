unit SourceCompletion;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Types, LCLType, SynEdit, SynCompletion, SynEditTypes, SynEditKeyCmds, Controls, TeXMacros;
type
  TSourceCompletionContext=procedure(Editor:TSynEdit; out Prefix,Directory,Engine:string;
    out MathMode,Enabled:Boolean) of object;
  TTeXSourceCompletion=class(TSynCompletion)
  private
    FNames:TStringList;
    FRegistry:TMacroRegistry;
    FPrefix,FDirectory,FEngine,FToken,FEnvironment:string;
    FExplicitContext,FMathMode,FQueued,FChanging:Boolean;
    FFirst:TPoint;
    procedure AfterCommand(Sender:TObject; AfterProcessing:Boolean; var Handled:Boolean;
      var Command:TSynEditorCommand; var AChar:TUTF8Char; Data,HandlerData:Pointer);
    procedure Offer(Data:PtrInt);
    procedure Prepare(Sender:TSynBaseCompletion; var Current:string; var APosition,X,Y:Integer; var Flags:TOnBeforeExeucteFlags);
    procedure Filter(var APosition:Integer);
    procedure Complete(var Value:string; SourceValue:string; var First,Last:TPoint; KeyChar:TUTF8Char; Shift:TShiftState);
    procedure Accept(Sender:TObject);
    procedure FocusEditor;
    procedure Cancelled(Sender:TObject);
    procedure PopupKey(Sender:TObject; var Key:Word; Shift:TShiftState);
    procedure Typed(Sender:TObject; var Key:TUTF8Char);
    function TokenAtCaret(out Token,Environment:string; out First:TPoint):Boolean;
  public
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure SetContext(const Prefix,Directory,Engine:string; MathMode:Boolean=False);
    procedure Suggest;
  end;
var SourceCompletionContext:TSourceCompletionContext;
function EnsureSourceCompletion(Editor:TSynEdit):TTeXSourceCompletion;
procedure SetSourceCompletionContext(Editor:TSynEdit; const Prefix,Directory,Engine:string; MathMode:Boolean=False);
implementation
uses SysUtils, Math, Forms, SourceRanges, CommandHints, MathCommands, MathModel, BeamerModel
  {$IFDEF LCLgtk2}, Gtk2, Gtk2Globals{$ENDIF};

function EnsureSourceCompletion(Editor:TSynEdit):TTeXSourceCompletion;
var I:Integer;
begin
  for I:=0 to Editor.ComponentCount-1 do
    if Editor.Components[I] is TTeXSourceCompletion then Exit(TTeXSourceCompletion(Editor.Components[I]));
  Result:=TTeXSourceCompletion.Create(Editor);
end;
procedure SetSourceCompletionContext(Editor:TSynEdit; const Prefix,Directory,Engine:string; MathMode:Boolean);
begin EnsureSourceCompletion(Editor).SetContext(Prefix,Directory,Engine,MathMode); end;
constructor TTeXSourceCompletion.Create(AOwner:TComponent);
begin
  { SynEdit plug-ins attach to an editor owner in their base constructor,
    before TSynCompletion has created its popup. Attach only after that. }
  inherited Create(nil); AOwner.InsertComponent(Self);
  FNames:=TStringList.Create; FRegistry:=TMacroRegistry.Create;
  Name:='TeXSourceCompletion'; Editor:=AOwner as TSynEdit;
  FEngine:='pdflatex'; FDirectory:=GetCurrentDir;
  CaseSensitive:=True; AutoUseSingleIdent:=False; Width:=320; LinesInWindow:=8;
  OnBeforeExecute:=@Prepare; OnCodeCompletion:=@Complete; OnSearchPosition:=@Filter;
  OnKeyCompletePrefix:=@Accept; OnUTF8KeyPress:=@Typed; OnCancel:=@Cancelled; OnKeyDown:=@PopupKey;
  Editor.RegisterCommandHandler(@AfterCommand,nil,[hcfFinish]);
  {$IFDEF LCLgtk2}
  { GTK2 assigns the first native window as its clipboard owner. Completion
    can create that window before the main form; realize it without showing it. }
  if TheForm.HandleAllocated and (ClipboardWidget=PGtkWidget(TheForm.Handle)) then gtk_widget_realize(ClipboardWidget);
  {$ENDIF}
end;
destructor TTeXSourceCompletion.Destroy;
begin
  Application.RemoveAsyncCalls(Self);
  if Editor<>nil then Editor.UnregisterCommandHandler(@AfterCommand);
  Editor:=nil;
  FRegistry.Free; FNames.Free; inherited Destroy;
end;
procedure TTeXSourceCompletion.SetContext(const Prefix,Directory,Engine:string; MathMode:Boolean);
begin
  FExplicitContext:=True; FPrefix:=Prefix; FDirectory:=Directory; FEngine:=Engine; FMathMode:=MathMode;
end;
procedure TTeXSourceCompletion.AfterCommand(Sender:TObject; AfterProcessing:Boolean; var Handled:Boolean;
  var Command:TSynEditorCommand; var AChar:TUTF8Char; Data,HandlerData:Pointer);
begin
  if not AfterProcessing or FChanging or IsActive or FQueued or Editor.ReadOnly then Exit;
  if (Command<>ecChar) and (Command<>ecDeleteLastChar) then Exit;
  FQueued:=True; Application.QueueAsyncCall(@Offer,0);
end;
procedure TTeXSourceCompletion.Offer(Data:PtrInt);
var Token,Environment:string; First:TPoint;
begin
  FQueued:=False;
  if FChanging or IsActive or not Editor.Focused or not Editor.Showing or Editor.ReadOnly then Exit;
  if TokenAtCaret(Token,Environment,First) and ((Length(Token)>1) or (Environment<>'')) then Suggest;
end;
procedure TTeXSourceCompletion.Suggest;
var P:TPoint;
begin
  if Editor.ReadOnly then Exit;
  P:=Editor.ClientToScreen(Point(Editor.CaretXPix,Editor.CaretYPix+Editor.LineHeight+1));
  Execute('',P.X,P.Y);
end;
function TTeXSourceCompletion.TokenAtCaret(out Token,Environment:string; out First:TPoint):Boolean;
var S:string; P,A,Q:Integer;
begin
  Token:=''; Environment:=''; First:=Editor.LogicalCaretXY; Result:=False;
  if Editor.SelAvail or (First.Y<1) or (First.Y>Editor.Lines.Count) then Exit;
  S:=Editor.Lines[First.Y-1]; P:=Min(First.X-1,Length(S)); A:=P;
  while (A>0) and (S[A] in ['a'..'z','A'..'Z','*','@']) do Dec(A);
  if (A>0) and (S[A]='\') then begin
    Q:=A-1; while (Q>0) and (S[Q]='\') do Dec(Q);
    if Odd(A-Q) then begin First.X:=A; Token:=Copy(S,A,P-A+1); Exit(True); end;
  end;
  if (A=0) or (S[A]<>'{') then Exit;
  Q:=A-1; while (Q>0) and (S[Q] in [#9,' ']) do Dec(Q);
  if (Q>=6) and (Copy(S,Q-5,6)='\begin') then Environment:='begin'
  else if (Q>=4) and (Copy(S,Q-3,4)='\end') then Environment:='end' else Exit;
  First.X:=A+1; Token:=Copy(S,A+1,P-A); Result:=True;
end;

function CompletionMathMode(const Source:string; Initial:Boolean; out Literal:Boolean):Boolean;
var P,Q:Integer; Command,Environment:string; Modes:array of Boolean; Depth:Integer;
begin
  Result:=Initial; Literal:=False; P:=1; Depth:=0;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin
      while (P<=Length(Source)) and not (Source[P] in [#10,#13]) do Inc(P);
      if P>Length(Source) then begin Literal:=True; Exit; end;
      Continue;
    end;
    if Source[P]='$' then begin
      Result:=not Result; Inc(P); if Copy(Source,P,1)='$' then Inc(P); Continue;
    end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P;
    if SkipTeXLiteral(Source,Q) then begin
      if Q>Length(Source) then begin
        Command:=ReadTeXCommand(Source,P);
        if Command='begin' then begin
          Environment:=ReadTeXGroup(Source,P,'{','}');
          Literal:=Pos('\end{'+Environment+'}',Copy(Source,P,MaxInt))=0;
        end else begin
          if Copy(Source,P,1)='*' then Inc(P);
          if Command<>'verb' then ReadTeXGroup(Source,P,'[',']');
          Literal:=(P>Length(Source));
          if not Literal then Literal:=(P=Length(Source)) or (Source[Length(Source)]<>Source[P]);
        end;
      end;
      P:=Q; Continue;
    end;
    if ReadTeXDefinition(Source,Q) or ReadTeXEnvironmentDefinition(Source,Q) then begin P:=Q; Continue; end;
    Command:=ReadTeXCommand(Source,P);
    if (Command='(') or (Command='[') then Result:=True
    else if (Command=')') or (Command=']') then Result:=False
    else if Command='begin' then begin
      Environment:=ReadTeXGroup(Source,P,'{','}');
      SetLength(Modes,Depth+1); Modes[Depth]:=Result; Inc(Depth);
      if (Environment='equation') or (Environment='equation*') or (Environment='align') or
        (Environment='align*') or (Environment='gather') or (Environment='gather*') or
        (Environment='multline') or (Environment='multline*') or (Environment='math') or
        (Environment='displaymath') or (Environment='eqnarray') then Result:=True;
    end else if Command='end' then begin
      ReadTeXGroup(Source,P,'{','}'); if Depth>0 then begin Dec(Depth); Result:=Modes[Depth]; end;
    end;
  end;
end;
procedure TTeXSourceCompletion.Prepare(Sender:TSynBaseCompletion; var Current:string;
  var APosition,X,Y:Integer; var Flags:TOnBeforeExeucteFlags);
const BodyEnvironments='document itemize enumerate description figure figure* table table* tabular tabular* '+
  'center flushleft flushright quote quotation verse minipage verbatim verbatim* equation equation* displaymath math';
  PreambleCommands='documentclass usepackage newcommand renewcommand providecommand newenvironment newtheorem '+
  'DeclareMathOperator NewDocumentCommand RenewDocumentCommand def title author date setlength';
var Prefix,Directory,Engine,Before,Candidate:string; MathMode,Enabled,Literal:Boolean; Names:TStringList; I:Integer;
begin
  if not TokenAtCaret(FToken,FEnvironment,FFirst) then begin Include(Flags,befAbort); Exit; end;
  Prefix:=FPrefix; Directory:=FDirectory; Engine:=FEngine; MathMode:=FMathMode; Enabled:=True;
  if not FExplicitContext and Assigned(SourceCompletionContext) then
    SourceCompletionContext(TSynEdit(Editor),Prefix,Directory,Engine,MathMode,Enabled);
  if not Enabled then begin Include(Flags,befAbort); Exit; end;
  Before:=Editor.TextBetweenPoints[Point(1,1),FFirst];
  MathMode:=CompletionMathMode(Prefix+Before,MathMode,Literal);
  if Literal then begin Include(Flags,befAbort); Exit; end;
  FRegistry.Load(Prefix,Directory,Engine);
  CollectCommandHints(FRegistry,Before,MathMode,FNames,FRegistry);
  Names:=TStringList.Create;
  try
    if FEnvironment<>'' then begin
      FNames.Clear;
      if MathMode then MathCommandNames('array',Names) else MathCommandNames(BodyEnvironments,Names);
      for Candidate in Names do FNames.Add(Copy(Candidate,2,MaxInt));
      FRegistry.EnvironmentNames(FNames);
      for I:=FNames.Count-1 downto 0 do
        if (Pos('@',FNames[I])>0) or (Pos(':',FNames[I])>0) or (Pos('PasTeX',FNames[I])>0) then FNames.Delete(I);
    end else begin
      if not MathMode then begin
        MathCommandNames(PreambleCommands,Names); FNames.AddStrings(Names);
      end;
      I:=FNames.IndexOf('\begin'); if I>=0 then FNames.Delete(I);
      FNames.Add('\begin{}…'); FNames.Add('\end{}');
    end;
  finally Names.Free; end;
  Current:=FToken; APosition:=0;
  TheForm.BackgroundColor:=Editor.Color; TheForm.TextColor:=Editor.Font.Color;
  TheForm.TextSelectedColor:=Editor.SelectedColor.Foreground;
  SelectedColor:=Editor.SelectedColor.Background;
end;
procedure TTeXSourceCompletion.Filter(var APosition:Integer);
var Candidate:string;
begin
  ItemList.BeginUpdate;
  try
    ItemList.Clear;
    for Candidate in FNames do if Copy(Candidate,1,Length(CurrentString))=CurrentString then ItemList.Add(Candidate);
  finally ItemList.EndUpdate; end;
  APosition:=0; if ItemList.Count=0 then APosition:=-1;
end;
procedure TTeXSourceCompletion.Accept(Sender:TObject);
begin if Assigned(TheForm.OnValidate) then TheForm.OnValidate(TheForm,'',[]); end;
procedure TTeXSourceCompletion.FocusEditor;
begin
  if (Editor<>nil) and not (csDestroying in Editor.ComponentState) and Editor.Showing and Editor.CanFocus then Editor.SetFocus;
end;
procedure TTeXSourceCompletion.Cancelled(Sender:TObject);
begin
  { Passive deactivation has already hidden the popup. Leave focus with the
    control or application the user clicked. Explicit cancellation restores it. }
  if not IsActive then Exit;
  Deactivate; FocusEditor;
end;
procedure TTeXSourceCompletion.PopupKey(Sender:TObject; var Key:Word; Shift:TShiftState);
var Command:TSynEditorCommand;
begin
  Command:=ecNone;
  case Key of
    VK_ESCAPE:begin Deactivate; FocusEditor; Key:=0; Exit; end;
    VK_LEFT:begin Command:=ecLeft; if ssShift in Shift then Command:=ecSelLeft; end;
    VK_RIGHT:begin Command:=ecRight; if ssShift in Shift then Command:=ecSelRight; end;
    VK_Z:if ssCtrl in Shift then begin Command:=ecUndo; if ssShift in Shift then Command:=ecRedo; end;
    VK_Y:if ssCtrl in Shift then Command:=ecRedo;
    VK_C:if ssCtrl in Shift then Command:=ecCopy;
    VK_X:if ssCtrl in Shift then Command:=ecCut;
    VK_V:if ssCtrl in Shift then Command:=ecPaste;
    VK_A:if ssCtrl in Shift then Command:=ecSelectAll;
  end;
  if Command=ecNone then Exit;
  Deactivate; FocusEditor; Key:=0; Editor.CommandProcessor(Command,'',nil);
end;
procedure TTeXSourceCompletion.Typed(Sender:TObject; var Key:TUTF8Char);
var Value:TUTF8Char;
begin
  if (Length(Key)=1) and (Key[1] in ['a'..'z','A'..'Z','*','@']) then Exit;
  { Punctuation and spaces remain literal source input. Only Enter/Tab or a
    list click accepts a template; typing a brace must not duplicate it. }
  Value:=Key; Key:=''; Deactivate; FocusEditor;
  if Value<>'' then Editor.CommandProcessor(ecChar,Value,nil);
end;
function HasEnvironmentEnd(const Source,Name:string):Boolean;
var P,Q,Depth:Integer; Command,Environment:string;
begin
  Result:=False; P:=1; Depth:=0;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
    Command:=ReadTeXCommand(Source,P);
    if (Command<>'begin') and (Command<>'end') then Continue;
    Environment:=ReadTeXGroup(Source,P,'{','}'); if Environment<>Name then Continue;
    if Command='begin' then Inc(Depth) else if Depth=0 then Exit(True) else Dec(Depth);
  end;
end;
procedure TTeXSourceCompletion.Complete(var Value:string; SourceValue:string;
  var First,Last:TPoint; KeyChar:TUTF8Char; Shift:TShiftState);
var S,Line,Indent,Candidate,Replacement,After,DefaultValue:string; A,B,Caret,I,Count,HeaderCaret:Integer; Info:TMacroInfo; Options:TSynEditorOptions;
begin
  FChanging:=True;
  try
    Deactivate; FocusEditor; S:=Editor.Text; A:=Length(Editor.TextBetweenPoints[Point(1,1),FFirst]);
    B:=Length(Editor.TextBetweenPoints[Point(1,1),Editor.LogicalCaretXY]);
    while (B<Length(S)) and (S[B+1] in ['a'..'z','A'..'Z','*','@']) do Inc(B);
    Candidate:=Value; Replacement:=Candidate; Caret:=A+Length(Replacement);
    if FEnvironment<>'' then begin
      if Copy(S,B+1,1)='}' then Inc(B);
      Replacement:=Candidate+'}'; Caret:=A+Length(Replacement);
      if (FEnvironment='begin') and not HasEnvironmentEnd(Copy(S,B+1,MaxInt),Candidate) then begin
        HeaderCaret:=-1;
        Line:=Editor.Lines[FFirst.Y-1]; I:=1;
        while (I<=Length(Line)) and (Line[I] in [' ',#9]) do Inc(I);
        Indent:=Copy(Line,1,I-1);
        if (Candidate='tabular') or (Candidate='array') then Replacement:=Replacement+'{c}'
        else if Candidate='tabular*' then Replacement:=Replacement+'{\linewidth}{c}'
        else if Candidate='minipage' then Replacement:=Replacement+'{\linewidth}'
        else if Candidate='thebibliography' then Replacement:=Replacement+'{9}'
        else if FRegistry.Presentation then begin
          if (Candidate='frame') or (Candidate='block') or (Candidate='alertblock') or (Candidate='exampleblock') then begin
            HeaderCaret:=A+Length(Replacement)+1; Replacement:=Replacement+'{}';
          end else if Candidate='column' then Replacement:=Replacement+'{.5\textwidth}'
          else if Candidate='overlayarea' then Replacement:=Replacement+'{\textwidth}{.5\textheight}';
        end;
        Replacement:=Replacement+LineEnding+Indent+'  '; Caret:=A+Length(Replacement);
        Replacement:=Replacement+LineEnding+Indent+'\end{'+Candidate+'}';
        if HeaderCaret>=0 then Caret:=HeaderCaret;
      end;
    end else if (Candidate='\begin{}…') or (Candidate='\end{}') then begin
      Replacement:='\begin{}'; if Candidate='\end{}' then Replacement:='\end{}';
      Caret:=A+Length(Replacement)-1;
      if Copy(S,B+1,1)='{' then begin Replacement:=Copy(Replacement,1,Pos('{',Replacement)-1); Caret:=A+Length(Replacement)+1; end;
    end else if Candidate='\verb' then begin Replacement:=Candidate+'||'; Caret:=A+Length(Candidate)+1; end
    else if not (Copy(S,B+1,1)='{') and not (Copy(S,B+1,1)='[') then begin
      Count:=MathArgumentCount(Copy(Candidate,2,MaxInt)); Info:=FRegistry.Find(Copy(Candidate,2,MaxInt));
      if FRegistry.Presentation and (BeamerArgumentCount(Copy(Candidate,2,MaxInt))>=0) then begin
        Count:=BeamerArgumentCount(Copy(Candidate,2,MaxInt)); Info:=nil;
      end;
      if (Count<0) and (Info<>nil) then Count:=Info.ArgCount;
      if (Candidate='\documentclass') or (Candidate='\usepackage') or (Candidate='\title') or (Candidate='\author') or
        (Candidate='\date') or (Candidate='\input') or (Candidate='\include') or (Candidate='\label') or (Candidate='\ref') or
        (Candidate='\pageref') or (Candidate='\cite') or (Candidate='\textbf') or (Candidate='\textit') or (Candidate='\section') then Count:=1;
      if Candidate='\setlength' then Count:=2;
      for I:=1 to Min(9,Count) do
        if (Info=nil) or not (Info.ArgumentKind(I,DefaultValue) in ['o','O','s','t']) then Replacement:=Replacement+'{}';
      if Length(Replacement)>Length(Candidate) then Caret:=A+Length(Candidate)+1;
    end;
    After:=Copy(S,B+1,MaxInt);
    Options:=Editor.Options; Editor.Options:=Options-[eoTrimTrailingSpaces];
    try
      Editor.TextBetweenPointsEx[FFirst,SourceBytePoint(S,B),scamEnd]:=Replacement;
      Editor.LogicalCaretXY:=SourceBytePoint(Copy(S,1,A)+Replacement+After,Caret);
    finally Editor.Options:=Options; end;
    First:=Editor.LogicalCaretXY; Last:=First; Value:='';
  finally FChanging:=False; end;
  if (Candidate='\begin{}…') or (Candidate='\end{}') then begin FQueued:=True; Application.QueueAsyncCall(@Offer,0); end;
end;
end.
