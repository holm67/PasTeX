unit TeXEditing;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Math, TeXMacros;
procedure LabelKeys(const Source:string; Keys:TStrings);
function RenameReferences(const Source,OldKey,NewKey:string; var Caret:Integer):string;
procedure ChangedLabels(const Before,After:string; OldKeys,NewKeys:TStrings);
function RenameReferenceKeys(const Source:string; OldKeys,NewKeys:TStrings; var Caret:Integer):string;
function SynchronizeReferences(const Before,After:string; var Anchor,Focus:Integer):string;
function SyncMathRSFS(const Preamble,Body:string):string;
function SyncLanguagePackages(const Preamble,Body,Engine:string):string;
function SyncCitationPackages(const Preamble,Body:string):string;
function SyncLayoutPackages(const Preamble,Body:string):string;
implementation
uses TeXTables, TeXUnicode, TeXBibliography;
function NextCommand(const S:string; var P:Integer; out Start:Integer):string; forward;
function SyncLayoutPackages(const Preamble,Body:string):string;
var P,A:Integer; Cmd,Packages:string; Booktabs,Dashrule,Multirow:Boolean;
begin
  Result:=Preamble; P:=1; Booktabs:=False; Dashrule:=False; Multirow:=False;
  while P<=Length(Body) do begin
    Cmd:=NextCommand(Body,P,A);
    if (Cmd='toprule') or (Cmd='midrule') or (Cmd='bottomrule') or (Cmd='cmidrule') or
      (Cmd='addlinespace') or (Cmd='specialrule') then Booktabs:=True;
    if Cmd='hdashrule' then Dashrule:=True;
    if Cmd='multirow' then Multirow:=True;
  end;
  if not Booktabs and not Dashrule and not Multirow then Exit;
  P:=1;
  while P<=Length(Preamble) do begin
    Cmd:=NextCommand(Preamble,P,A); if (Cmd<>'usepackage') and (Cmd<>'RequirePackage') then Continue;
    SkipTeXSpace(Preamble,P); if Copy(Preamble,P,1)='[' then ReadTeXGroup(Preamble,P,'[',']');
    Packages:=','+StringReplace(ReadTeXGroup(Preamble,P,'{','}'),' ','',[rfReplaceAll])+',';
    if Pos(',booktabs,',Packages)>0 then Booktabs:=False;
    if Pos(',dashrule,',Packages)>0 then Dashrule:=False;
    if Pos(',multirow,',Packages)>0 then Multirow:=False;
  end;
  P:=Pos('\begin{document}',Result); if P=0 then P:=Length(Result)+1;
  if Booktabs then Insert('\usepackage{booktabs}'+LineEnding,Result,P);
  if Dashrule then Insert('\usepackage{dashrule}'+LineEnding,Result,P);
  if Multirow then Insert('\usepackage{multirow}'+LineEnding,Result,P);
end;
function SyncCitationPackages(const Preamble,Body:string):string;
var P,A,Q,I,Insertion:Integer; Cmd,Value:string; Needed,Present:Boolean; Names:TStringList;
begin
  Result:=Preamble; P:=1; Needed:=False;
  while P<=Length(Body) do begin
    Cmd:=NextCommand(Body,P,A);
    if (Cmd='citep') or (Cmd='citet') or (Cmd='citeauthor') or (Cmd='citeyear') or
       (Cmd='citeyearpar') or (Cmd='citenum') then Needed:=True;
    if Cmd='cite' then begin
      Q:=P; if Copy(Body,Q,1)='*' then Inc(Q); SkipTeXSpace(Body,Q);
      if Copy(Body,Q,1)='[' then begin
        ReadTeXGroup(Body,Q,'[',']'); SkipTeXSpace(Body,Q);
        if Copy(Body,Q,1)='[' then Needed:=True;
      end;
    end;
    if Needed then Break;
  end;
  if not Needed then Exit;
  Present:=False; P:=1; Insertion:=0; Names:=TStringList.Create;
  try
    Names.Delimiter:=','; Names.StrictDelimiter:=True;
    while P<=Length(Preamble) do begin
      Cmd:=NextCommand(Preamble,P,A);
      if (Insertion=0) and (Cmd='begin') then begin
        Q:=P; if ReadTeXGroup(Preamble,Q,'{','}')='document' then Insertion:=A;
      end;
      if (Cmd<>'usepackage') and (Cmd<>'RequirePackage') then Continue;
      if Insertion=0 then Insertion:=A;
      SkipTeXSpace(Preamble,P); if Copy(Preamble,P,1)='[' then ReadTeXGroup(Preamble,P,'[',']');
      Value:=ReadTeXGroup(Preamble,P,'{','}'); Names.DelimitedText:=Value;
      for I:=0 to Names.Count-1 do if (Trim(Names[I])='natbib') or (Trim(Names[I])='biblatex') then Present:=True;
    end;
  finally Names.Free; end;
  if not Present then begin
    { Load before hyperref so its bibliography integration sees natbib. }
    if Insertion=0 then Insertion:=Length(Result)+1;
    Insert('\usepackage[numbers,square]{natbib}'+LineEnding,Result,Insertion);
  end;
end;
function SyncLanguagePackages(const Preamble,Body,Engine:string):string;
var P,A,I:Integer; Code:Cardinal; Cmd,Value:string; Needed,Present:Boolean; Names:TStringList;
begin
  Result:=Preamble;
  if (Engine<>'xelatex') and (Engine<>'lualatex') then Exit;
  P:=1; Needed:=False;
  while P<=Length(Body) do begin
    if (Body[P]='%') and ((P=1) or (Body[P-1]<>'\')) then begin while (P<=Length(Body)) and (Body[P]<>#10) do Inc(P); Continue; end;
    Code:=NextUTF8CodePoint(Body,P);
    if ((Code>=$2E80) and (Code<=$9FFF)) or ((Code>=$F900) and (Code<=$FAFF)) or
       ((Code>=$20000) and (Code<=$323AF)) then begin Needed:=True; Break; end;
  end;
  if not Needed then Exit;
  Present:=False; P:=1; Names:=TStringList.Create;
  try
    Names.Delimiter:=','; Names.StrictDelimiter:=True;
    while P<=Length(Preamble) do begin
      Cmd:=NextCommand(Preamble,P,A);
      if (Cmd<>'documentclass') and (Cmd<>'usepackage') and (Cmd<>'RequirePackage') then Continue;
      SkipTeXSpace(Preamble,P); if (P<=Length(Preamble)) and (Preamble[P]='[') then ReadTeXGroup(Preamble,P,'[',']');
      Value:=ReadTeXGroup(Preamble,P,'{','}'); Names.DelimitedText:=Value;
      for I:=0 to Names.Count-1 do if (Pos('ctex',Trim(Names[I]))=1) or
        (Trim(Names[I])='xeCJK') or (Trim(Names[I])='CJK') or (Trim(Names[I])='CJKutf8') then Present:=True;
    end;
  finally Names.Free; end;
  if not Present then begin
    P:=Pos('\begin{document}',Result); if P=0 then P:=Length(Result)+1;
    Insert('\usepackage{ctex}'+LineEnding,Result,P);
  end;
end;
function NextCommand(const S:string; var P:Integer; out Start:Integer):string;
var Q:Integer; Cmd,Env:string; Delimiter:Char;
begin
  Result:='';
  while P<=Length(S) do begin
    if S[P]='%' then begin while (P<=Length(S)) and (S[P]<>#10) do Inc(P); end
    else if S[P]='\' then begin
      Start:=P; Cmd:=ReadTeXCommand(S,P);
      if Cmd='verb' then begin
        if (P<=Length(S)) and (S[P]='*') then Inc(P);
        if P<=Length(S) then begin Delimiter:=S[P]; Inc(P); while (P<=Length(S)) and (S[P]<>Delimiter) do Inc(P); if P<=Length(S) then Inc(P); end;
        Continue;
      end;
      if Cmd='begin' then begin
        Q:=P; Env:=ReadTeXGroup(S,Q,'{','}');
        if (Env='verbatim') or (Env='verbatim*') or (Env='lstlisting') or (Env='minted') then begin
          P:=EnvironmentEnd(S,Start,Env)+Length('\end{'+Env+'}'); Continue;
        end;
      end;
      Exit(Cmd);
    end else Inc(P);
  end;
end;
procedure LabelKeys(const Source:string; Keys:TStrings);
var P,A:Integer; Cmd:string;
begin
  Keys.Clear; P:=1;
  while P<=Length(Source) do begin Cmd:=NextCommand(Source,P,A); if Cmd='label' then Keys.Add(ReadTeXGroup(Source,P,'{','}')); end;
end;
function RenameReferenceKeys(const Source:string; OldKeys,NewKeys:TStrings; var Caret:Integer):string;
var P,A,B,L,Delta,I,J,Start,GroupIndex,Groups:Integer; Cmd,Key,Value,Part:string; Open,Close:Char;
begin
  Result:=Source; P:=1;
  while P<=Length(Result) do begin
    Cmd:=NextCommand(Result,P,A);
    if not IsLabelReference(Cmd) and (Cmd<>'hyperref') then Continue;
    if (P<=Length(Result)) and (Result[P]='*') then Inc(P);
    Open:='{'; Close:='}'; if Cmd='hyperref' then begin Open:='['; Close:=']'; end;
    Groups:=1; if (Cmd='crefrange') or (Cmd='Crefrange') then Groups:=2;
    for GroupIndex:=1 to Groups do begin
    SkipTeXSpace(Result,P); B:=P; Key:=ReadTeXGroup(Result,P,Open,Close); Value:=''; Start:=1;
    for I:=1 to Length(Key)+1 do if (I>Length(Key)) or (Key[I]=',') then begin
      Part:=Copy(Key,Start,I-Start); J:=0;
      while (J<OldKeys.Count) and (OldKeys[J]<>Trim(Part)) do Inc(J);
      if (J<OldKeys.Count) and (J<NewKeys.Count) then Part:=NewKeys[J];
      Value:=Value+Part;
      if I<=Length(Key) then Value:=Value+','; Start:=I+1;
    end;
    if Key=Value then Continue;
    L:=P-B; Delete(Result,B,L); Insert(Open+Value+Close,Result,B);
    Delta:=Length(Value)-Length(Key);
    if Caret>=P-1 then Inc(Caret,Delta)
    else if Caret>B then Caret:=Min(Caret,B+Length(Value)+1);
    Inc(P,Delta);
    end;
  end;
end;
function RenameReferences(const Source,OldKey,NewKey:string; var Caret:Integer):string;
var OldKeys,NewKeys:TStringList;
begin
  OldKeys:=TStringList.Create; NewKeys:=TStringList.Create;
  try OldKeys.Add(OldKey); NewKeys.Add(NewKey); Result:=RenameReferenceKeys(Source,OldKeys,NewKeys,Caret);
  finally NewKeys.Free; OldKeys.Free; end;
end;
procedure ChangedLabels(const Before,After:string; OldKeys,NewKeys:TStrings);
var I,J:Integer;
begin
  if OldKeys is TStringList then TStringList(OldKeys).CaseSensitive:=True;
  if NewKeys is TStringList then TStringList(NewKeys).CaseSensitive:=True;
  LabelKeys(Before,OldKeys); LabelKeys(After,NewKeys);
  { A moved declaration retains its key. Match existing keys before pairing
    renamed declarations, so moving table rows cannot retarget references. }
  for I:=OldKeys.Count-1 downto 0 do begin
    J:=NewKeys.IndexOf(OldKeys[I]);
    if J>=0 then begin OldKeys.Delete(I); NewKeys.Delete(J); end;
  end;
  if OldKeys.Count<>NewKeys.Count then begin OldKeys.Clear; NewKeys.Clear; end;
end;
function SynchronizeReferences(const Before,After:string; var Anchor,Focus:Integer):string;
var OldKeys,NewKeys:TStringList;
begin
  Result:=After; OldKeys:=TStringList.Create; NewKeys:=TStringList.Create;
  try
    ChangedLabels(Before,After,OldKeys,NewKeys);
    Result:=RenameReferenceKeys(After,OldKeys,NewKeys,Focus);
    RenameReferenceKeys(After,OldKeys,NewKeys,Anchor);
  finally NewKeys.Free; OldKeys.Free; end;
end;
function SyncMathRSFS(const Preamble,Body:string):string;
var P,A,B,E,I:Integer; Cmd,Value,AllSource:string; Needed,Present,Changed:Boolean; Names:TStringList;
begin
  Result:=Preamble; AllSource:=Preamble+Body; Needed:=False; P:=1;
  while P<=Length(AllSource) do if NextCommand(AllSource,P,A)='mathscr' then begin Needed:=True; Break; end;
  P:=1; Present:=False; Names:=TStringList.Create;
  try
    while P<=Length(Result) do begin
      Cmd:=NextCommand(Result,P,A); if (Cmd<>'usepackage') and (Cmd<>'RequirePackage') then Continue;
      SkipTeXSpace(Result,P); if (P<=Length(Result)) and (Result[P]='[') then ReadTeXGroup(Result,P,'[',']');
      SkipTeXSpace(Result,P); B:=P; Value:=ReadTeXGroup(Result,P,'{','}'); E:=P;
      Names.Delimiter:=','; Names.StrictDelimiter:=True; Names.DelimitedText:=Value; Changed:=False;
      for I:=Names.Count-1 downto 0 do if Trim(Names[I])='mathrsfs' then begin
        Present:=True; if not Needed then begin Names.Delete(I); Changed:=True; end;
      end;
      if Changed then begin
        if Names.Count=0 then begin Delete(Result,A,E-A); P:=A; end
        else begin Value:='{'+Names.DelimitedText+'}'; Delete(Result,B,E-B); Insert(Value,Result,B); P:=B+Length(Value); end;
      end;
    end;
    if Needed and not Present then begin
      P:=Pos('\begin{document}',Result); if P=0 then P:=Length(Result)+1;
      Insert('\usepackage{mathrsfs}'+LineEnding,Result,P);
    end;
  finally Names.Free; end;
end;
end.
