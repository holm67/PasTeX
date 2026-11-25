{ SPDX-License-Identifier: GPL-3.0-or-later }
{ Math sequences follow lib/bind/math.bind and cua.bind in
  https://git.lyx.org/repos/lyx.git (1aaf97e5a8).
  Printable keys are decoded after keyboard-layout/IME translation. }
procedure TMathEditor.SetMathShortcut(const Value:string);
begin
  if FMathShortcut=Value then Exit;
  FMathShortcut:=Value; FVerticalRun:=False;
  if Assigned(FSelectionChange) then FSelectionChange(Self);
end;
procedure TMathEditor.CancelMathShortcut;
begin SetMathShortcut(''); end;
function TMathEditor.GetMathShortcutHint:string;
begin
  case FMathShortcut of
    'math':Result:='Math: f fraction, s root, e superscript, x subscript, g Greek, ( [ { delimiters; Esc cancels';
    'g':Result:='Greek: a alpha, b beta, g gamma, p pi; Shift for capitals; Esc cancels';
    'w':Result:='Rows: i insert below, d delete, c duplicate; Esc cancels';
    'c':Result:='Columns: i insert right, d delete, c duplicate; Esc cancels';
    't':Result:='Layout: i inline, d equation, a align, m multline, e eqnarray; Esc cancels';
    else Result:='';
  end;
end;
function TMathEditor.MathShortcutKey(var Key:Word; Shift:TShiftState):Boolean;
begin
  Result:=False;
  if FReadOnly or FCodeOnly or IsCodeField(CurrentNode) or IsVerbatimField(CurrentNode) or CommandActive or GeneratedTextActive then begin
    SetMathShortcut(''); Exit;
  end;
  if (Key=VK_ESCAPE) and (FMathShortcut<>'') then begin SetMathShortcut(''); Key:=0; Exit(True); end;
  if (Key=VK_M) and ((Shift=[ssAlt]) or (Shift=[ssCtrl]) or (Shift=[ssCtrl,ssShift])) then begin
    if Shift=[ssAlt] then SetMathShortcut('math')
    else if ssShift in Shift then begin SetMathShortcut(''); SetFormulaKind('display',False); end
    else begin SetMathShortcut(''); EnterShortcutMath; end;
    Key:=0; Exit(True);
  end;
  if (FMathShortcut<>'') and not (Key in [VK_SHIFT,VK_CONTROL,VK_MENU]) and
    (((Shift*[ssCtrl,ssAlt,ssMeta])<>[]) or
     (Key in [VK_LEFT,VK_RIGHT,VK_UP,VK_DOWN,VK_HOME,VK_END,VK_PRIOR,VK_NEXT,VK_TAB,VK_RETURN,VK_BACK,VK_DELETE])) then
    SetMathShortcut('');
end;
procedure TMathEditor.EnterShortcutMath;
var A,B:Integer;
begin
  if InMath and not InTextArgument then WrapMathSelection('\text{','}')
  else begin
    if not SelectionRange(A,B) then begin A:=SourceCaret; B:=A; end;
    if A<>B then WrapSelectionRange('$','$',A,B)
    else begin
      Commit(Copy(FSource,1,A)+'$ $'+Copy(FSource,A+1,MaxInt),A+1);
      SetSourceSelection(A+1,A+2);
    end;
  end;
end;
procedure TMathEditor.WrapMathSelection(const Prefix,Suffix:string; ReplaceContent:Boolean);
var A,B,Caret:Integer; IsMath:Boolean; Opening,Closing,Source:string;
  procedure InsideFormula(Node:TMathNode);
  var First,Last,I:Integer;
  begin
    if Node=nil then Exit;
    if Node.Kind=mkFormula then begin
      First:=MathSourceOffset(Node)-Length(Node.Prefix); Last:=First+Length(Node.TeX);
      if (A=First) and (B=Last) then begin
        Inc(A,Length(Node.Prefix)); Dec(B,Length(Node.Suffix)); IsMath:=True; Exit;
      end;
      if (A>=First+Length(Node.Prefix)) and (B<=Last-Length(Node.Suffix)) then IsMath:=True;
    end;
    for I:=0 to Node.Children.Count-1 do InsideFormula(TMathNode(Node.Children[I]));
  end;
begin
  IsMath:=InMath;
  if SelectionRange(A,B) then begin IsMath:=not FParagraph; InsideFormula(FRoot); end
  else begin A:=SourceCaret; B:=A; end;
  Opening:=Prefix; Closing:=Suffix;
  if not IsMath then begin Opening:='$'+Opening; Closing:=Closing+'$'; end;
  if ReplaceContent then begin
    Source:=ReplaceProseRange(FRoot,FSource,A,B,Opening+Closing,Caret,False);
    Commit(Source,Caret-Length(Closing));
  end else WrapSelectionRange(Opening,Closing,A,B);
end;
function TMathEditor.MathShortcutText(const Value:string):Boolean;
const Greek:array['a'..'z'] of ShortString=('alpha','beta','chi','delta','epsilon','phi','gamma',
  'eta','iota','varphi','kappa','lambda','mu','nu','omega','pi','vartheta','rho','sigma','tau',
  'upsilon','theta','omega','xi','psi','zeta');
var Mode,Command,Opening,Closing,Kind:string; Key:Char; Operation:Integer;
begin
  Result:=False; Mode:=FMathShortcut; if Mode='' then Exit;
  SetMathShortcut('');
  if FReadOnly or FCodeOnly or CommandActive or IsCodeField(CurrentNode) or IsVerbatimField(CurrentNode) or (Length(Value)<>1) then Exit;
  Key:=Value[1]; Command:=''; Opening:=''; Closing:=''; Kind:=''; Operation:=-1;
  if Mode='g' then begin
    if Key in ['a'..'z'] then Command:=Greek[Key]
    else case Key of
      'D':Command:='Delta'; 'E':Command:='varepsilon'; 'F':Command:='Phi'; 'G':Command:='Gamma';
      'I':Command:='iota'; 'J':Command:='epsilon'; 'L':Command:='Lambda'; 'O','W':Command:='Omega';
      'P':Command:='Pi'; 'Q':Command:='vartheta'; 'R':Command:='varrho'; 'S':Command:='Sigma';
      'T':Command:='varsigma'; 'U':Command:='Upsilon'; 'V':Command:='Theta'; 'X':Command:='Xi'; 'Y':Command:='Psi';
    end;
    if Command<>'' then Command:='\'+Command;
  end else if (Mode='w') or (Mode='c') then begin
    case Key of 'i':Operation:=1; 'd':Operation:=2; 'c':Operation:=6; end;
    if Operation<0 then Exit;
    if Mode='c' then begin if Operation=6 then Operation:=7 else Inc(Operation,3); end;
    { Consume unavailable grid actions rather than inserting their key as text. }
    if CanEditGrid(Operation) then EditGrid(Operation);
    Exit(True);
  end else if Mode='t' then begin
    case Key of 'i':Kind:='inline'; 'd':Kind:='equation'; 'a':Kind:='align';
      'm':Kind:='multline'; 'e':Kind:='eqnarray'; end;
  end else if Mode='math' then begin
    case Key of
      'g','w','c','t':begin SetMathShortcut(Value); Exit(True); end;
      'm':begin EnterShortcutMath; Exit(True); end;
      'd':Kind:='display';
      'f':begin Opening:='\frac{'; Closing:='}{}'; end;
      's':begin Opening:='\sqrt{'; Closing:='}'; end;
      'r':begin Opening:='\sqrt[]{'; Closing:='}'; end;
      'e':begin Opening:='^{'; Closing:='}'; end;
      'x':begin Opening:='_{'; Closing:='}'; end;
      '(':begin Opening:='\left('; Closing:='\right)'; end;
      '[':begin Opening:='\left['; Closing:='\right]'; end;
      '{':begin Opening:='\left\{'; Closing:='\right\}'; end;
      '<':begin Opening:='\left\langle '; Closing:='\right\rangle '; end;
      '>':begin Opening:='\left\rangle '; Closing:='\right\langle '; end;
      '|':begin Opening:='\left|'; Closing:='\right|'; end;
      'h':Command:='\hat'; 'v':Command:='\vec'; 'b':Command:='\overline';
      '-':Command:='\bar'; '.':Command:='\dot'; '"':Command:='\ddot';
      '\':Command:='\grave'; '/':Command:='\acute'; '&':Command:='\tilde';
      'V':Command:='\check'; 'U':Command:='\breve'; '_':Command:='\underline';
      'u':Command:='\sum'; 'i':Command:='\int'; 'y':Command:='\oint';
      'p':Command:='\partial'; '8':Command:='\infty'; '''':Command:='\prime';
      '+':Command:='\pm'; '=':Command:='\neq'; ' ':Command:='\,';
    end;
    if (Command<>'') and (MathArgumentCount(Copy(Command,2,MaxInt))>0) then begin Opening:=Command+'{'; Closing:='}'; Command:=''; end;
  end;
  if Opening<>'' then WrapMathSelection(Opening,Closing)
  else if Kind<>'' then SetFormulaKind(Kind,False)
  else if Command<>'' then WrapMathSelection(Command+' ','',True)
  else Exit;
  NotifySelection; Result:=True;
end;
