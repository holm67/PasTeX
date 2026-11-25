unit BibliographyData;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Contnrs;
type
  TBibliographyItem=record Key,LabelText,Text:string; end;
  TBibliographyItems=array of TBibliographyItem;
  TBibliographyEntry=class
    Key,Kind:string;
    Fields:TStringList;
    constructor Create;
    destructor Destroy; override;
    function Author:string;
    function Year:string;
  end;
  TBibliographyData=class
  private
    FEntries:TObjectList;
    FKeys,FOrder,FCited,FNumbers:TStringList;
    FStamp,FNumberStamp,FStyle:string;
    FEnabled,FSortCitations,FBiblatex:Boolean;
    procedure ReadDatabase(const Source:string);
    procedure UpdateNumbers;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load(const Source,Directory:string);
    function LayoutSignature:string;
    function Citation(const Keys,Command,PreNote,PostNote:string; Numbers:TStrings):string;
    function FormattedItems:TBibliographyItems;
  end;
implementation
uses SysUtils, StrUtils, TeXMacros, TeXBibliography, TikZModel;
constructor TBibliographyEntry.Create;
begin inherited; Fields:=TStringList.Create; Fields.CaseSensitive:=False; end;
destructor TBibliographyEntry.Destroy;
begin Fields.Free; inherited; end;
function Plain(const Source:string):string;
var P:Integer; Command:string;
begin
  Result:=''; P:=1;
  while P<=Length(Source) do begin
    if Source[P] in ['{','}'] then Inc(P)
    else if Source[P]='~' then begin Result:=Result+' '; Inc(P); end
    else if Source[P]='\' then begin
      Command:=ReadTeXCommand(Source,P);
      if Length(Command)=1 then Result:=Result+Command else if (Command='LaTeX') or (Command='TeX') then Result:=Result+Command;
    end else begin Result:=Result+Source[P]; Inc(P); end;
  end;
  Result:=Trim(Result);
end;
function TBibliographyEntry.Author:string;
var Value,Name:string; P,Q,Depth,Count:Integer;
begin
  Result:=''; Value:=Fields.Values['author']; if Value='' then Value:=Fields.Values['editor'];
  P:=1; Count:=0;
  while P<=Length(Value) do begin
    Q:=P; Depth:=0;
    while Q<=Length(Value) do begin
      if Value[Q]='{' then Inc(Depth) else if Value[Q]='}' then Dec(Depth);
      if (Depth=0) and (Copy(Value,Q,5)=' and ') then Break; Inc(Q);
    end;
    Name:=Trim(Copy(Value,P,Q-P));
    if Copy(Name,1,1)<>'{' then begin
      if Pos(',',Name)>0 then Name:=Copy(Name,1,Pos(',',Name)-1)
      else if LastDelimiter(' ',Name)>0 then Name:=Copy(Name,LastDelimiter(' ',Name)+1,MaxInt);
    end;
    Name:=Plain(Name); Inc(Count);
    if Count>2 then begin Result:=Copy(Result,1,Pos(' and ',Result)-1)+' et al.'; Break; end;
    if Result<>'' then Result:=Result+' and '; Result:=Result+Name; P:=Q+5;
  end;
  if Result='' then Result:=Plain(Fields.Values['label']); if Result='' then Result:=Key;
end;
function TBibliographyEntry.Year:string;
begin
  Result:=Fields.Values['year']; if Result='' then Result:=Copy(Fields.Values['date'],1,4);
  if Result='' then Result:='n.d.';
end;
constructor TBibliographyData.Create;
begin
  inherited; FEntries:=TObjectList.Create(True); FKeys:=TStringList.Create;
  FKeys.Sorted:=True; FKeys.CaseSensitive:=True; FOrder:=TStringList.Create; FOrder.Sorted:=True;
  FCited:=TStringList.Create; FCited.CaseSensitive:=True;
  FNumbers:=TStringList.Create; FNumbers.Sorted:=True; FNumbers.CaseSensitive:=True;
end;
destructor TBibliographyData.Destroy;
begin FNumbers.Free; FCited.Free; FOrder.Free; FKeys.Free; FEntries.Free; inherited; end;
function TBibliographyData.LayoutSignature:string;
begin Result:=''; if FEnabled then Result:=FStamp+#1+FNumbers.Text; end;
procedure TBibliographyData.UpdateNumbers;
var Cited:TStringList; Stamp,Key,Value:string; I,Count:Integer; All:Boolean;
  procedure Add(const Key:string);
  begin
    if (FKeys.IndexOf(Key)<0) or (FNumbers.IndexOfName(Key)>=0) then Exit;
    Inc(Count); FNumbers.Add(Key+'='+IntToStr(Count));
  end;
begin
  Stamp:=FStamp+#0+IntToStr(Ord(FSortCitations))+#0+FCited.Text;
  if Stamp=FNumberStamp then Exit;
  FNumberStamp:=Stamp; FNumbers.Clear; Count:=0; Cited:=TStringList.Create;
  try
    Cited.CaseSensitive:=True; Cited.Assign(FCited); Cited.Sorted:=True; All:=Cited.IndexOf('*')>=0;
    if FSortCitations then begin
      for Key in FCited do Add(Key);
      if All then for I:=0 to FEntries.Count-1 do Add(TBibliographyEntry(FEntries[I]).Key);
    end else for Value in FOrder do begin
      Key:=Copy(Value,Pos(#1,Value)+1,MaxInt);
      if All or (Cited.IndexOf(Key)>=0) then Add(Key);
    end;
  finally Cited.Free; end;
end;
procedure TBibliographyData.ReadDatabase(const Source:string);
var P,A,Index:Integer; Kind,Body,Name,Value,Part:string; E:TBibliographyEntry;
  function Atom:string;
  var First:Integer;
  begin
    SkipTeXSpace(Body,P); Result:=''; if P>Length(Body) then Exit;
    if Body[P]='{' then Exit(ReadTeXGroup(Body,P,'{','}'));
    if Body[P]='"' then begin
      Inc(P); First:=P; while (P<=Length(Body)) and (Body[P]<>'"') do begin
        if Body[P]='\' then Inc(P); Inc(P);
      end;
      Result:=Copy(Body,First,P-First); if P<=Length(Body) then Inc(P); Exit;
    end;
    First:=P; while (P<=Length(Body)) and not (Body[P] in [',','#',#10,#13]) do Inc(P);
    Result:=Trim(Copy(Body,First,P-First));
  end;
begin
  P:=1;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Source[P]<>'@' then begin Inc(P); Continue; end;
    Inc(P); A:=P; while (P<=Length(Source)) and (Source[P] in ['a'..'z','A'..'Z']) do Inc(P);
    Kind:=LowerCase(Copy(Source,A,P-A)); SkipTeXSpace(Source,P);
    if (P>Length(Source)) or not (Source[P] in ['{','(']) then Continue;
    if Source[P]='{' then Body:=ReadTeXGroup(Source,P,'{','}',True) else Body:=ReadTeXGroup(Source,P,'(',')',True);
    Index:=P; P:=1;
    try
      if (Kind='comment') or (Kind='string') or (Kind='preamble') then Continue;
      A:=Pos(',',Body); if A=0 then Continue;
      E:=TBibliographyEntry.Create; E.Key:=Trim(Copy(Body,1,A-1)); E.Kind:=Kind; P:=A+1;
      if (E.Key='') or (FKeys.IndexOf(E.Key)>=0) then begin E.Free; Continue; end;
      FEntries.Add(E); FKeys.AddObject(E.Key,E);
      while P<=Length(Body) do begin
        SkipTeXSpace(Body,P); if (P<=Length(Body)) and (Body[P]=',') then begin Inc(P); Continue; end;
        A:=P; while (P<=Length(Body)) and (Body[P] in ['a'..'z','A'..'Z','0'..'9','_','-']) do Inc(P);
        Name:=LowerCase(Copy(Body,A,P-A)); SkipTeXSpace(Body,P);
        if (Name='') or (Copy(Body,P,1)<>'=') then begin Inc(P); Continue; end;
        Inc(P); Value:=Atom; SkipTeXSpace(Body,P);
        while Copy(Body,P,1)='#' do begin Inc(P); Part:=Atom; Value:=Value+Part; SkipTeXSpace(Body,P); end;
        E.Fields.Values[Name]:=Value;
      end;
      FOrder.Add(LowerCase(E.Author+#9+E.Year+#9+E.Fields.Values['title'])+#1+E.Key);
      if FEntries.Count>=10000 then Exit;
    finally P:=Index; end;
  end;
end;
procedure TBibliographyData.Load(const Source,Directory:string);
var Files,Lines:TStringList; P,Q,I:Integer; Command,Name,Options,Path,Stamp,Key,CiteStyle:string;
    Entry:TDiagramOption; Stream:TFileStream; BytesRead:Int64; Stat:TSearchRec;
begin
  Files:=TStringList.Create; Lines:=TStringList.Create;
  try
    P:=1; FEnabled:=False; FBiblatex:=False; FStyle:='numeric'; CiteStyle:=''; FSortCitations:=False; FCited.Clear;
    while P<=Length(Source) do begin
      if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
      if Source[P]<>'\' then begin Inc(P); Continue; end;
      Q:=P; if ReadTeXDefinition(Source,Q) or SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
      Command:=ReadTeXCommand(Source,P);
      if (Command='usepackage') or (Command='RequirePackage') then begin
        Options:=ReadTeXGroup(Source,P,'[',']'); Name:=ReadTeXGroup(Source,P,'{','}');
        if Pos(',biblatex,',','+StringReplace(Name,' ','',[rfReplaceAll])+',')>0 then begin
          FEnabled:=True; FBiblatex:=True;
          for Entry in DiagramOptions(Options) do begin
            if Entry.Name='style' then FStyle:=Plain(Entry.Value);
            if Entry.Name='citestyle' then CiteStyle:=Plain(Entry.Value);
            if Entry.Name='sorting' then FSortCitations:=Entry.Value='none';
          end;
        end;
      end else if Command='addbibresource' then begin
        ReadTeXGroup(Source,P,'[',']'); Name:=ReadTeXGroup(Source,P,'{','}',True);
        if Name<>'' then Files.Add(Name);
      end else if Command='bibliography' then begin
        FEnabled:=True; Lines.StrictDelimiter:=True; Lines.Delimiter:=',';
        Lines.DelimitedText:=ReadTeXGroup(Source,P,'{','}');
        for Name in Lines do if Trim(Name)<>'' then Files.Add(Trim(Name));
      end else if Command='bibliographystyle' then begin
        FStyle:=ReadTeXGroup(Source,P,'{','}');
        FSortCitations:=(FStyle='unsrt') or (FStyle='unsrtnat') or (FStyle='ieeetr');
      end else if IsCitationCommand(Command) then begin
        if Copy(Source,P,1)='*' then Inc(P); SkipTeXSpace(Source,P);
        while Copy(Source,P,1)='[' do begin ReadTeXGroup(Source,P,'[',']'); SkipTeXSpace(Source,P); end;
        Lines.StrictDelimiter:=True; Lines.Delimiter:=','; Lines.DelimitedText:=ReadTeXGroup(Source,P,'{','}');
        for Key in Lines do if (Trim(Key)<>'') and (FCited.IndexOf(Trim(Key))<0) then FCited.Add(Trim(Key));
      end;
    end;
    if CiteStyle<>'' then FStyle:=CiteStyle;
    Stamp:=Directory+#0+Files.Text+#0+FStyle;
    for I:=0 to Files.Count-1 do begin
      Path:=Files[I]; if ExtractFileExt(Path)='' then Path:=Path+'.bib';
      if (Path<>'') and (ExtractFileDrive(Path)='') and not (Path[1] in ['/','\']) then Path:=IncludeTrailingPathDelimiter(Directory)+Path;
      Files[I]:=ExpandFileName(Path); Stamp:=Stamp+#0+IntToStr(FileAge(Files[I]));
      if FindFirst(Files[I],faAnyFile,Stat)=0 then begin Stamp:=Stamp+':'+IntToStr(Stat.Size); FindClose(Stat); end;
    end;
    Stamp:=Stamp+IntToStr(Ord(FEnabled))+IntToStr(Ord(FBiblatex));
    if Stamp=FStamp then begin UpdateNumbers; Exit; end;
    FStamp:=Stamp; FKeys.Clear; FEntries.Clear; FOrder.Clear;
    if not FEnabled then Exit;
    BytesRead:=0;
    for Path in Files do if FileExists(Path) then begin
      if (FEntries.Count>=10000) or (BytesRead>=4*1024*1024) then Break;
      try
        Stream:=TFileStream.Create(Path,fmOpenRead or fmShareDenyNone);
        try if (Stream.Size<=2*1024*1024) and (BytesRead+Stream.Size<=4*1024*1024) then begin
          Inc(BytesRead,Stream.Size); Lines.LoadFromStream(Stream); ReadDatabase(Lines.Text);
        end;
        finally Stream.Free; end;
      except on E:EFOpenError do FStamp:=''; on E:EReadError do FStamp:=''; end;
    end;
    FNumberStamp:=''; UpdateNumbers;
  finally Lines.Free; Files.Free; end;
end;
function TBibliographyData.FormattedItems:TBibliographyItems;
var Ordered:TStringList; I,J,N:Integer; E:TBibliographyEntry; Text,Authors,Name,Year,Style,Title,Part:string; Inverted,Initials:Boolean;
  procedure Append(const Value,Separator:string);
  begin if Value='' then Exit; if Text<>'' then Text:=Text+Separator; Text:=Text+Value; end;
  function FullAuthors(const Value:string):string;
  var P,Q,R,J:Integer; Name,Given,Surname,Short:string;
  begin
    Result:=''; P:=1;
    repeat
      Q:=PosEx(' and ',Value,P); if Q=0 then Q:=Length(Value)+1;
      Name:=Trim(Copy(Value,P,Q-P));
      if Copy(Name,1,1)<>'{' then begin
        R:=Pos(',',Name);
        if R>0 then begin Given:=Trim(Copy(Name,R+1,MaxInt)); Surname:=Trim(Copy(Name,1,R-1)); end
        else begin R:=LastDelimiter(' ',Name); Given:=Trim(Copy(Name,1,R-1)); Surname:=Copy(Name,R+1,MaxInt); end;
        if Initials and (Pos('\',Given)=0) then begin
          Short:=''; J:=1;
          while J<=Length(Given) do begin
            if not (Given[J] in [' ','.','-']) then begin
              if Short<>'' then Short:=Short+' ';
              R:=J+1; while (R<=Length(Given)) and ((Ord(Given[R]) and $C0)=$80) do Inc(R);
              Short:=Short+Copy(Given,J,R-J)+'.';
              while (J<=Length(Given)) and not (Given[J] in [' ','-']) do Inc(J);
            end else Inc(J);
          end;
          Given:=Short;
        end;
        if Inverted then begin Name:=Surname; if Given<>'' then Name:=Name+', '+Given; end
        else Name:=Trim(Given+' '+Surname);
      end;
      if Result<>'' then begin
        if Q>Length(Value) then begin if Style='apa' then Result:=Result+' \& ' else Result:=Result+' and '; end
        else Result:=Result+', ';
      end;
      Result:=Result+Name; P:=Q+5;
    until P>Length(Value);
  end;
begin
  Result:=nil; if not FEnabled then Exit; Ordered:=TStringList.Create;
  try
    for I:=0 to FNumbers.Count-1 do Ordered.AddObject(Format('%.8d',[StrToIntDef(FNumbers.ValueFromIndex[I],0)])+#1+FNumbers.Names[I],nil);
    Ordered.Sort; Style:=LowerCase(FStyle); Inverted:=FBiblatex or (Style='apa');
    Initials:=(Style='apa') or (Style='abbrv') or (Style='abbrvnat') or (Style='ieee') or (Style='ieeetr');
    for Name in Ordered do begin
      J:=FKeys.IndexOf(Copy(Name,Pos(#1,Name)+1,MaxInt)); if J<0 then Continue;
      E:=TBibliographyEntry(FKeys.Objects[J]); Authors:=FullAuthors(E.Fields.Values['author']);
      if Authors='' then Authors:=FullAuthors(E.Fields.Values['editor']);
      Title:=E.Fields.Values['title']; Year:=E.Year; Text:='';
      if (Pos('authoryear',Style)>0) or (Style='apa') then begin
        Append(Authors,''); Append('('+Year+').',' ');
        if Title<>'' then Append('\textit{'+Title+'}.',' ');
      end else begin
        Append(Authors,'');
        if (E.Kind='book') or (E.Kind='manual') or (E.Kind='thesis') then Title:='\textit{'+Title+'}';
        Append(Title,'. ');
      end;
      Part:=E.Fields.Values['journal']; if Part='' then Part:=E.Fields.Values['journaltitle'];
      if Part='' then Part:=E.Fields.Values['booktitle'];
      if Part<>'' then begin
        Append('\textit{'+Part+'}', '. '); Part:=E.Fields.Values['volume'];
        if E.Fields.Values['number']<>'' then Part:=Part+'('+E.Fields.Values['number']+')';
        if E.Fields.Values['pages']<>'' then Part:=Part+':'+E.Fields.Values['pages']; Append(Part,', ');
      end;
      Part:=E.Fields.Values['publisher']; if Part='' then Part:=E.Fields.Values['institution']; Append(Part,'. ');
      if E.Fields.Values['edition']<>'' then Append(E.Fields.Values['edition']+' edition',', ');
      if (Pos('authoryear',Style)=0) and (Style<>'apa') then Append(Year,', ');
      if (Text<>'') and (Text[Length(Text)]<>'.') then Text:=Text+'.';
      Part:=E.Fields.Values['note'];
      if Part<>'' then begin
        Append(Part,' '); if Text[Length(Text)]<>'.' then Text:=Text+'.';
      end;
      Part:=E.Fields.Values['doi'];
      if Part<>'' then Append('\href{https://doi.org/'+Part+'}{doi: '+Part+'}', ' ');
      Part:=E.Fields.Values['url']; if Part<>'' then Append('\url{'+Part+'}', ' ');
      N:=Length(Result); SetLength(Result,N+1); Result[N].Key:=E.Key; Result[N].Text:=Text;
      if (Pos('authoryear',Style)=0) and (Style<>'apa') then Result[N].LabelText:='['+FNumbers.Values[E.Key]+']';
    end;
  finally Ordered.Free; end;
end;
function TBibliographyData.Citation(const Keys,Command,PreNote,PostNote:string; Numbers:TStrings):string;
var List:TStringList; I,J:Integer; E:TBibliographyEntry; Key,Value,Author,Year,Prefix,Style,Note:string;
    AuthorYear,Parenthetical:Boolean;
begin
  Result:=''; if not FEnabled then Exit;
  List:=TStringList.Create;
  try
    List.Delimiter:=','; List.StrictDelimiter:=True; List.DelimitedText:=Keys;
    Style:=LowerCase(FStyle); AuthorYear:=(Pos('authoryear',Style)>0) or (Style='apa') or (Pos('chicago',Style)>0);
    Parenthetical:=(Command='parencite') or (Command='autocite') or (Command='smartcite') or (Command='citep');
    Prefix:='';
    for I:=0 to List.Count-1 do begin
      Key:=Trim(List[I]); J:=FKeys.IndexOf(Key); E:=nil; if J>=0 then E:=TBibliographyEntry(FKeys.Objects[J]);
      Author:=Key; Year:='?'; if E<>nil then begin Author:=E.Author; Year:=E.Year; end;
      if Prefix='' then Prefix:=Author;
      Value:=Key;
      if AuthorYear then begin Value:=Author+' '+Year; if Command='textcite' then Value:=Author+' ('+Year+')'; end
      else begin
        Value:=FNumbers.Values[Key];
        if Value='' then Value:=Numbers.Values[Key];
        if Value='' then Value:='?';
      end;
      case Command of 'citeauthor':Value:=Author; 'citeyear','citeyearpar':Value:=Year; end;
      if Result<>'' then begin if AuthorYear then Result:=Result+'; ' else Result:=Result+', '; end;
      Result:=Result+Value;
    end;
    if PreNote<>'' then Result:=PreNote+' '+Result;
    Note:=PostNote; if Note<>'' then begin
      if Note[1] in ['0'..'9'] then Note:='p. '+Note; Result:=Result+', '+Note;
    end;
    if (Command='citeauthor') or (Command='citeyear') or (Command='citenum') then Exit;
    if Command='citeyearpar' then begin Result:='('+Result+')'; Exit; end;
    if AuthorYear then begin if Parenthetical then Result:='('+Result+')'; end
    else begin Result:='['+Result+']'; if Command='textcite' then Result:=Prefix+' '+Result; end;
  finally List.Free; end;
end;
end.
