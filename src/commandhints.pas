unit CommandHints;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, TeXMacros;
procedure CollectCommandHints(Base:TMacroRegistry; const BeforeCaret:string; MathMode:Boolean; Dest:TStringList; ScopeResult:TMacroRegistry=nil);
implementation
uses SysUtils, MathCommands, MathModel, TeXFontData;
procedure CollectCommandHints(Base:TMacroRegistry; const BeforeCaret:string; MathMode:Boolean; Dest:TStringList; ScopeResult:TMacroRegistry);
const TextCommands='TeX LaTeX emph textbf textit textsl textsc textsf texttt textrm textnormal underline mbox fbox';
  MathStructures='frac sqrt overline underline hat widehat tilde widetilde bar dot ddot vec acute grave breve check '+
    'underbrace overbrace mathrm mathit mathbf mathsf mathtt mathcal left int oint';
  BodyCommands='section subsection subsubsection chapter part paragraph subparagraph tableofcontents listoffigures listoftables maketitle';
var Scopes:TList; Scope:TMacroRegistry; Names:TStringList; Name,Command,Code:string;
    Info:TMacroInfo; P,Q,A,I:Integer;
  procedure LocalScope;
  begin
    if (Scopes.Count>1) and (Scopes.Last=Scopes[Scopes.Count-2]) then begin
      Scope:=Scope.Clone; Scopes[Scopes.Count-1]:=Scope;
    end;
  end;
  procedure LeaveScope;
  var Previous:TMacroRegistry;
  begin
    if Scopes.Count<=1 then Exit;
    Previous:=Scope; Scopes.Delete(Scopes.Count-1); Scope:=TMacroRegistry(Scopes.Last);
    if Previous<>Scope then Previous.Free;
  end;
  function Complete(const Definition:string):Boolean;
  var P,Depth:Integer;
  begin
    P:=1; Depth:=0;
    while P<=Length(Definition) do begin
      case Definition[P] of
        '\':begin ReadTeXCommand(Definition,P); Continue; end;
        '%':begin while (P<=Length(Definition)) and (Definition[P]<>#10) do Inc(P); Continue; end;
        '{':Inc(Depth);
        '}':begin Dec(Depth); if Depth<0 then Exit(False); end;
      end;
      Inc(P);
    end;
    Result:=Depth=0;
  end;
begin
  Dest.Clear; Dest.CaseSensitive:=True; Dest.UseLocale:=False; Dest.Duplicates:=dupIgnore; Dest.Sorted:=True;
  Scopes:=TList.Create; Names:=TStringList.Create;
  try
    Scope:=Base.Clone; Scopes.Add(Scope); P:=1;
    { Definitions later in the same paragraph must not leak into hints.
      Preserve local TeX groups without reparsing package sources per key. }
    while P<=Length(BeforeCaret) do begin
      case BeforeCaret[P] of
        '%':begin while (P<=Length(BeforeCaret)) and (BeforeCaret[P]<>#10) do Inc(P); Continue; end;
        '{':begin Scopes.Add(Scope); Inc(P); Continue; end;
        '}':begin LeaveScope; Inc(P); Continue; end;
        '\':begin
          A:=P; Q:=P;
          if SkipTeXLiteral(BeforeCaret,Q) then begin P:=Q; Continue; end;
          if ReadTeXDefinition(BeforeCaret,Q) or ReadTeXEnvironmentDefinition(BeforeCaret,Q) then begin
            Code:=Copy(BeforeCaret,A,Q-A); P:=A; Command:=ReadTeXCommand(BeforeCaret,P); P:=Q;
            if Complete(Code) and ((Copy(Code,Length(Code),1)='}') or (Copy(Code,Length(Code),1)=']') or (Command='let') or (Command='undef')) then begin
              if (Command='gdef') or (Command='xdef') then begin
                for I:=0 to Scopes.Count-1 do
                  if (I=0) or (Scopes[I]<>Scopes[I-1]) then TMacroRegistry(Scopes[I]).ApplyDefinitions(Code);
              end else begin LocalScope; Scope.ApplyDefinitions(Code); end;
            end;
            Continue;
          end;
          Command:=ReadTeXCommand(BeforeCaret,P);
          if (Command='begingroup') or (Command='bgroup') then Scopes.Add(Scope)
          else if (Command='endgroup') or (Command='egroup') then LeaveScope
          else if Command='begin' then begin ReadTeXGroup(BeforeCaret,P,'{','}'); Scopes.Add(Scope); end
          else if Command='end' then begin ReadTeXGroup(BeforeCaret,P,'{','}'); LeaveScope; end
          else if IsTeXInputCommand(Command) or
            (Command='usepackage') or (Command='documentclass') then begin
            ReadTeXGroup(BeforeCaret,P,'[',']'); ReadTeXGroup(BeforeCaret,P,'{','}');
            LocalScope; Scope.ApplyDefinitions(Copy(BeforeCaret,A,P-A));
          end;
        end;
        else Inc(P);
      end;
    end;
    if MathMode then begin
      TeXCoreSymbolNames(Dest); MathCommandNames(MathStructures,Dest); MathCommandNames(CommonMathFunctions,Dest);
    end else begin
      MathCommandNames(TextCommands+' label ref pageref cite input include verb newline noindent indent hspace vspace',Dest);
      MathCommandNames(BodyCommands,Names);
      for Name in Names do if Scope.Find(Copy(Name,2,MaxInt))<>nil then Dest.Add(Name);
    end;
    if Scope.Presentation then begin
      MathCommandNames('only onslide uncover visible invisible alert structure alt temporal action pause',Dest);
      if not MathMode then MathCommandNames('frame frametitle framesubtitle titlepage maketitle column',Dest);
    end;
    Dest.Add('\begin'); Scope.Names(Names);
    for Name in Names do begin
      if (Pos('@',Name)>0) or (Pos(':',Name)>0) or (Pos('PasTeX',Name)>0) then Continue;
      Info:=Scope.Find(Copy(Name,2,MaxInt)); if (Info=nil) or Info.Undefined then Continue;
      if Info.PackageSource='' then Dest.Add(Name)
      else if MathMode and ((Info.SymbolClass<>'') or (Info.GlyphFont<>'') or (Info.GlyphPlan<>'') or
        (Info.NativeName<>'') or (MathArgumentCount(Copy(Name,2,MaxInt))>=0)) then Dest.Add(Name)
      else if ((Info.PreviewAdapter='units') or (Info.PreviewAdapter='derivative') or
        (Info.PreviewAdapter='symbol') or (Info.PreviewAdapter='diagbox')) or
        (not MathMode and ((Info.PreviewAdapter='url') or (Info.PreviewAdapter='link') or
          (Info.PreviewAdapter='box') or (Info.PreviewAdapter='space'))) then Dest.Add(Name)
      else if not MathMode and ((Name='\autoref') or (Name='\eqref') or (Name='\nameref') or
        (Name='\cref') or (Name='\printbibliography') or (Name='\subfile')) then Dest.Add(Name);
    end;
    { An explicit undefinition overrides even a built-in candidate. }
    for I:=Dest.Count-1 downto 0 do begin
      Info:=Scope.Find(Copy(Dest[I],2,MaxInt)); if (Info<>nil) and Info.Undefined then Dest.Delete(I);
    end;
    if ScopeResult<>nil then ScopeResult.Assign(Scope);
  finally
    for I:=Scopes.Count-1 downto 0 do if (I=0) or (Scopes[I]<>Scopes[I-1]) then TObject(Scopes[I]).Free;
    Names.Free; Scopes.Free;
  end;
end;
end.
