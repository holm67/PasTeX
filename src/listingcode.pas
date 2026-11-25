unit ListingCode;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes;
type
  TListingKind=(lkPlain,lkKeyword,lkComment,lkString);
  TListingToken=record First,Finish:Integer; Kind:TListingKind; end;
  TListingTokens=array of TListingToken;
procedure ListingOptions(const Context,Prefix:string; Dest:TStrings);
function ListingTokens(const Source:string; Options:TStrings; const Context,Directory:string):TListingTokens;
implementation
uses SysUtils, Math, TeXMacros, TikZModel, TeXPackageSources;
var LanguageCache:TStringList;
function Uncomment(const Text:string):string;
var P,A:Integer;
begin
  Result:=''; P:=1; A:=1;
  while P<=Length(Text) do
    if Text[P]='\' then Inc(P,2)
    else if Text[P]='%' then begin
      Result:=Result+Copy(Text,A,P-A); while (P<=Length(Text)) and (Text[P]<>#10) do Inc(P); A:=P;
    end else Inc(P);
  Result:=Result+Copy(Text,A,MaxInt);
end;
function Unbrace(const Text:string):string;
var P:Integer;
begin
  Result:=Trim(Text); P:=1;
  if Copy(Result,1,1)='{' then begin
    Result:=ReadTeXGroup(Text,P,'{','}'); if P<=Length(Trim(Text)) then Result:=Trim(Text);
  end;
end;
procedure ListingOptions(const Context,Prefix:string; Dest:TStrings);
var P,Q:Integer; Name,Value:string; Styles:TStringList;
  procedure Add(const Text:string; Depth:Integer=0);
  var Entry:TDiagramOption; V:string; I:Integer;
  begin
    if Depth>8 then Exit;
    for Entry in DiagramOptions(Uncomment(Text)) do begin
      V:=Unbrace(Entry.Value);
      if Entry.Name='style' then Add(Styles.Values[V],Depth+1)
      else begin
        I:=Dest.IndexOfName(Entry.Name);
        if I<0 then Dest.Add(Entry.Name+'='+V) else Dest[I]:=Entry.Name+'='+V;
      end;
    end;
  end;
begin
  Dest.Clear; Dest.Add('keywordstyle=\bfseries'); Dest.Add('commentstyle=\itshape');
  Dest.Add('basewidth=0.6em,0.45em'); Dest.Add('columns=[c]fixed');
  Styles:=TStringList.Create;
  try
    P:=1;
    while P<=Length(Context) do begin
      if Context[P]='%' then begin while (P<=Length(Context)) and (Context[P]<>#10) do Inc(P); Continue; end;
      if Context[P]<>'\' then begin Inc(P); Continue; end;
      Q:=P; if ReadTeXDefinition(Context,Q) then begin P:=Q; Continue; end;
      Name:=ReadTeXCommand(Context,P);
      if Name='lstdefinestyle' then begin Value:=ReadTeXGroup(Context,P,'{','}'); Styles.Values[Value]:=ReadTeXGroup(Context,P,'{','}'); end
      else if Name='lstset' then Add(ReadTeXGroup(Context,P,'{','}'));
    end;
    P:=1; ReadTeXCommand(Prefix,P); ReadTeXGroup(Prefix,P,'{','}');
    Add(ReadTeXGroup(Prefix,P,'[',']'));
  finally Styles.Free; end;
end;
function LanguageSettings(const Language,Context,Directory:string; Depth:Integer=0):string;
var Name,Dialect,Base,Settings,Text,Key,Value,Cmd,D,N,ParentDialect:string; P,Q,I:Integer; Entry:TDiagramOption;
  function Find(const Source:string):Boolean;
  var A:Integer; CandidateBase:string;
  begin
    Result:=False; A:=1;
    while A<=Length(Source) do begin
      if Source[A]<>'\' then begin Inc(A); Continue; end;
      Cmd:=ReadTeXCommand(Source,A);
      if (Cmd<>'lst@definelanguage') and (Cmd<>'lstdefinelanguage') then Continue;
      D:=ReadTeXGroup(Source,A,'[',']'); N:=ReadTeXGroup(Source,A,'{','}'); SkipTeXSpace(Source,A);
      ParentDialect:=''; CandidateBase:='';
      if Copy(Source,A,1)='[' then begin
        ParentDialect:=ReadTeXGroup(Source,A,'[',']'); CandidateBase:=ReadTeXGroup(Source,A,'{','}');
        if ParentDialect<>'' then CandidateBase:='['+ParentDialect+']'+CandidateBase;
      end;
      Value:=ReadTeXGroup(Source,A,'{','}');
      if SameText(N,Name) and SameText(D,Dialect) then begin Settings:=Value; Base:=CandidateBase; Result:=True; end;
    end;
  end;
begin
  Result:=''; if (Language='') or (Depth>8) then Exit;
  P:=1; Dialect:=ReadTeXGroup(Language,P,'[',']'); Name:=Trim(Copy(Language,P,MaxInt));
  if Dialect='' then begin
    Text:=ReadTeXSource(ResolveTeXSource('listings.cfg',Directory)); P:=1;
    while P<=Length(Text) do begin
      if Text[P]<>'\' then begin Inc(P); Continue; end;
      Cmd:=ReadTeXCommand(Text,P); if Cmd<>'lstset' then Continue;
      Value:=ReadTeXGroup(Text,P,'{','}');
      for Entry in DiagramOptions(Uncomment(Value)) do if Entry.Name='defaultdialect' then begin
        Q:=1; D:=ReadTeXGroup(Entry.Value,Q,'[',']');
        if SameText(Trim(Copy(Entry.Value,Q,MaxInt)),Name) then Dialect:=D;
      end;
    end;
  end;
  Settings:=''; Base:='';
  if Find(Uncomment(Context)) then begin
    Result:=LanguageSettings(Base,Context,Directory,Depth+1)+','+Settings; Exit;
  end;
  Key:=Directory+'|['+LowerCase(Dialect)+']'+LowerCase(Name); I:=LanguageCache.IndexOfName(Key);
  if I>=0 then Exit(LanguageCache.ValueFromIndex[I]);
  for I:=0 to 3 do begin
    Text:=Uncomment(ReadTeXSource(ResolveTeXSource('lstlang'+IntToStr(I)+'.sty',Directory)));
    if Find(Text) then begin Result:=LanguageSettings(Base,Context,Directory,Depth+1)+','+Settings; Break; end;
  end;
  if LanguageCache.Count>=16 then LanguageCache.Delete(0); LanguageCache.Add(Key+'='+Result);
end;
function ListingTokens(const Source:string; Options:TStrings; const Context,Directory:string):TListingTokens;
type TDelimiter=record First,Last:string; Kind:TListingKind; Mode:Char; end;
var Keywords:TStringList; Delimiters:array of TDelimiter; Sensitive:Boolean;
    P,A,N,I:Integer; WordText,Mode,First,Last:string; Kind:TListingKind;
  function Letter(C:Char):Boolean;
  begin Result:=C in ['a'..'z','A'..'Z','0'..'9','_']; end;
  procedure Words(const Text:string; Remove:Boolean=False);
  var List:TStringList; I,J:Integer; Word:string;
  begin
    List:=TStringList.Create;
    try
      List.StrictDelimiter:=True; List.CommaText:=Unbrace(Text);
      for I:=0 to List.Count-1 do begin
        Word:=Trim(List[I]); if Word='' then Continue;
        if Remove then begin J:=Keywords.IndexOf(Word); if J>=0 then Keywords.Delete(J); end else Keywords.Add(Word);
      end;
    finally List.Free; end;
  end;
  procedure Settings(const Text:string);
  var Entry:TDiagramOption; Value:string; K:Integer;
  begin
    for Entry in DiagramOptions(Text) do begin
      Value:=Trim(Entry.Value);
      if Entry.Name='sensitive' then begin Sensitive:=not ((Value='f') or (Value='false')); Keywords.CaseSensitive:=Sensitive; end
      else if (Entry.Name='keywords') or (Entry.Name='morekeywords') or (Entry.Name='deletekeywords') then begin
        P:=1; ReadTeXGroup(Value,P,'[',']');
        if Entry.Name='keywords' then Keywords.Clear;
        Words(Copy(Value,P,MaxInt),Entry.Name='deletekeywords');
      end else if (Entry.Name='morecomment') or (Entry.Name='morestring') then begin
        P:=1; Mode:=ReadTeXGroup(Value,P,'[',']'); ReadTeXGroup(Value,P,'[',']'); SkipTeXSpace(Value,P);
        if Copy(Value,P,1)='{' then First:=ReadTeXGroup(Value,P,'{','}') else begin First:=Copy(Value,P,1); Inc(P); end;
        Last:=''; if Mode='s' then Last:=ReadTeXGroup(Value,P,'{','}') else if Entry.Name='morestring' then Last:=First;
        First:=StringReplace(StringReplace(First,'\{','{',[rfReplaceAll]),'\}','}',[rfReplaceAll]);
        Last:=StringReplace(StringReplace(Last,'\{','{',[rfReplaceAll]),'\}','}',[rfReplaceAll]);
        if First='' then Continue;
        K:=Length(Delimiters); SetLength(Delimiters,K+1); Delimiters[K].First:=First; Delimiters[K].Last:=Last;
        Delimiters[K].Kind:=lkComment; if Entry.Name='morestring' then Delimiters[K].Kind:=lkString;
        Delimiters[K].Mode:=#0; if Mode<>'' then Delimiters[K].Mode:=Mode[1];
      end;
    end;
  end;
begin
  Result:=nil; Keywords:=TStringList.Create; Sensitive:=True; Delimiters:=nil;
  try
    Keywords.CaseSensitive:=True; Keywords.Sorted:=True; Keywords.Duplicates:=dupIgnore;
    Settings(LanguageSettings(Options.Values['language'],Context,Directory));
    Keywords.CaseSensitive:=Sensitive;
    { Local keyword and delimiter options override the language definition. }
    for I:=0 to Options.Count-1 do if Options.Names[I]<>'' then Settings(Options[I]);
    Keywords.CaseSensitive:=Sensitive; P:=1; N:=0;
    while P<=Length(Source) do begin
      A:=P; Kind:=lkPlain;
      for I:=High(Delimiters) downto 0 do if Copy(Source,P,Length(Delimiters[I].First))=Delimiters[I].First then begin
        Kind:=Delimiters[I].Kind; Inc(P,Length(Delimiters[I].First));
        First:=Delimiters[I].First; Last:=Delimiters[I].Last;
        while P<=Length(Source) do begin
          if (Last='') and (Source[P] in [#10,#13]) then Break;
          if (Last<>'') and (Copy(Source,P,Length(Last))=Last) then begin
            Inc(P,Length(Last));
            if (Delimiters[I].Mode='d') and (Copy(Source,P,Length(Last))=Last) then Inc(P,Length(Last)) else Break;
          end else if (Delimiters[I].Mode='b') and (Source[P]='\') then Inc(P,2) else Inc(P);
        end;
        Break;
      end;
      if P=A then begin
        if Source[P] in ['a'..'z','A'..'Z','_'] then begin
          while (P<=Length(Source)) and Letter(Source[P]) do Inc(P);
          WordText:=Copy(Source,A,P-A); if Keywords.IndexOf(WordText)>=0 then Kind:=lkKeyword;
        end else Inc(P);
      end;
      P:=Min(P,Length(Source)+1);
      if (N>0) and (Result[N-1].Kind=Kind) then Result[N-1].Finish:=P
      else begin
        if N=Length(Result) then SetLength(Result,N+32);
        Result[N].First:=A; Result[N].Finish:=P; Result[N].Kind:=Kind; Inc(N);
      end;
    end;
    SetLength(Result,N);
  finally Keywords.Free; end;
end;
initialization
  LanguageCache:=TStringList.Create; LanguageCache.NameValueSeparator:='=';
finalization
  LanguageCache.Free;
end.
