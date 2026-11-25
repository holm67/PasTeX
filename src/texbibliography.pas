unit TeXBibliography;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes;
type
  TCitationSource=record
    Command,Keys,PreNote,PostNote:string;
    Starred:Boolean;
    OptionalCount:Integer;
  end;
function IsCitationCommand(const Command:string):Boolean;
function IsLabelReference(const Command:string):Boolean;
function IsPageReference(const Command:string):Boolean;
function HasPageReferences(const Source:string):Boolean;
function ReferenceTitle(const Source:string):string;
function ReadCitation(const Source:string; out Citation:TCitationSource):Boolean;
function CitationSource(const Citation:TCitationSource):string;
procedure BibliographyKeys(const Source,Directory:string; Dest:TStrings);
implementation
uses SysUtils, TeXMacros;
function IsCitationCommand(const Command:string):Boolean;
begin
  Result:=(Command='cite') or (Command='citep') or (Command='citet') or
    (Command='autocite') or (Command='parencite') or (Command='textcite') or
    (Command='footcite') or (Command='footfullcite') or (Command='fullcite') or
    (Command='smartcite') or (Command='supercite') or (Command='nocite') or
    (Command='citeauthor') or (Command='citeyear') or (Command='citeyearpar') or
    (Command='citenum');
end;
function IsLabelReference(const Command:string):Boolean;
begin
  Result:=(Command='ref') or (Command='eqref') or (Command='autoref') or
    IsPageReference(Command) or (Command='nameref') or (Command='vref') or (Command='cref') or (Command='Cref') or
    (Command='crefrange') or (Command='Crefrange') or
    (Command='labelcref') or (Command='namecref') or (Command='nameCref') or (Command='lcnamecref');
end;
function IsPageReference(const Command:string):Boolean;
begin Result:=(Command='pageref') or (Command='cpageref') or (Command='Cpageref'); end;
function HasPageReferences(const Source:string):Boolean;
var P,Q:Integer;
begin
  Result:=False; if Pos('pageref',Source)=0 then Exit; P:=1;
  while P<=Length(Source) do begin
    SkipTeXSpace(Source,P); if P>Length(Source) then Break;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) or SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
    if IsPageReference(ReadTeXCommand(Source,P)) then Exit(True);
  end;
end;
function ReferenceTitle(const Source:string):string;
var P,A,Q:Integer; Command:string;
begin
  Result:=Source; P:=1;
  while P<=Length(Result) do begin
    SkipTeXSpace(Result,P); if P>Length(Result) then Break;
    if Result[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if SkipTeXLiteral(Result,Q) then begin P:=Q; Continue; end;
    A:=P; Command:=ReadTeXCommand(Result,P);
    if (Command='label') or (Command='index') then begin
      ReadTeXGroup(Result,P,'{','}'); Delete(Result,A,P-A); P:=A;
    end;
  end;
end;
function ReadCitation(const Source:string; out Citation:TCitationSource):Boolean;
var P:Integer;
begin
  Citation:=Default(TCitationSource); P:=1; Citation.Command:=ReadTeXCommand(Source,P);
  Result:=IsCitationCommand(Citation.Command); if not Result then Exit;
  Citation.Starred:=Copy(Source,P,1)='*'; if Citation.Starred then Inc(P);
  SkipTeXSpace(Source,P);
  if Copy(Source,P,1)='[' then begin
    Citation.PostNote:=ReadTeXGroup(Source,P,'[',']'); Citation.OptionalCount:=1;
    SkipTeXSpace(Source,P);
    if Copy(Source,P,1)='[' then begin
      Citation.PreNote:=Citation.PostNote; Citation.PostNote:=ReadTeXGroup(Source,P,'[',']'); Citation.OptionalCount:=2;
    end;
  end;
  SkipTeXSpace(Source,P); Result:=Copy(Source,P,1)='{';
  if Result then begin Citation.Keys:=ReadTeXGroup(Source,P,'{','}'); Result:=Trim(Copy(Source,P,MaxInt))=''; end;
end;
function CitationSource(const Citation:TCitationSource):string;
begin
  Result:='\'+Citation.Command; if Citation.Starred then Result:=Result+'*';
  if (Citation.OptionalCount>=2) or (Citation.PreNote<>'') then Result:=Result+'['+Citation.PreNote+']['+Citation.PostNote+']'
  else if (Citation.OptionalCount=1) or (Citation.PostNote<>'') then Result:=Result+'['+Citation.PostNote+']';
  Result:=Result+'{'+Citation.Keys+'}';
end;
procedure BibliographyKeys(const Source,Directory:string; Dest:TStrings);
var P:Integer; Cmd,Names,Path,Name:string; Files,Text:TStringList; Seen:TStringList;
  procedure AddKey(const Key:string);
  var I:Integer; Value:string;
  begin
    Value:=Trim(Key); if Value='' then Exit;
    for I:=0 to Dest.Count-1 do if Dest[I]=Value then Exit;
    Dest.Add(Value);
  end;
  procedure ReadDatabase(const Text:string);
  var I,A,Depth:Integer; Kind,Key:string; Closing:Char; Quoted:Boolean;
  begin
    I:=1;
    while I<=Length(Text) do begin
      if Text[I]='%' then begin while (I<=Length(Text)) and (Text[I]<>#10) do Inc(I); Continue; end;
      if Text[I]<>'@' then begin Inc(I); Continue; end;
      Inc(I); A:=I; while (I<=Length(Text)) and (Text[I] in ['a'..'z','A'..'Z']) do Inc(I);
      Kind:=LowerCase(Copy(Text,A,I-A)); SkipTeXSpace(Text,I);
      if (I>Length(Text)) or not (Text[I] in ['{','(']) then Continue;
      Closing:='}'; if Text[I]='(' then Closing:=')'; Inc(I); A:=I;
      while (I<=Length(Text)) and not (Text[I] in [',',Closing,#10,#13]) do Inc(I);
      Key:=Copy(Text,A,I-A);
      if (I<=Length(Text)) and (Text[I]=',') and (Kind<>'comment') and (Kind<>'string') and (Kind<>'preamble') then AddKey(Key);
      { Skip the complete entry, so an @ in a title cannot become a key. }
      Depth:=0; Quoted:=False;
      while I<=Length(Text) do begin
        if Text[I]='\' then begin Inc(I,2); Continue; end;
        if Text[I]='"' then Quoted:=not Quoted;
        if not Quoted then begin
          if (Text[I]=Closing) and (Depth=0) then begin Inc(I); Break; end;
          if Text[I]='{' then Inc(Depth) else if Text[I]='}' then Dec(Depth);
        end;
        Inc(I);
      end;
    end;
  end;
begin
  Dest.Clear; Files:=TStringList.Create; Text:=TStringList.Create; Seen:=TStringList.Create;
  try
    Files.Delimiter:=','; Files.StrictDelimiter:=True; P:=1;
    while P<=Length(Source) do begin
      if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
      if Source[P]<>'\' then begin Inc(P); Continue; end;
      Cmd:=ReadTeXCommand(Source,P);
      if Cmd='verb' then begin
        if Copy(Source,P,1)='*' then Inc(P);
        if P<=Length(Source) then begin Name:=Source[P]; Inc(P); while (P<=Length(Source)) and (Source[P]<>Name[1]) do Inc(P); Inc(P); end;
        Continue;
      end;
      if (Cmd='bibitem') or (Cmd='addbibresource') then begin
        SkipTeXSpace(Source,P); if Copy(Source,P,1)='[' then ReadTeXGroup(Source,P,'[',']');
      end;
      if Cmd='bibitem' then AddKey(ReadTeXGroup(Source,P,'{','}'))
      else if (Cmd='bibliography') or (Cmd='addbibresource') then begin
        Names:=ReadTeXGroup(Source,P,'{','}'); Files.DelimitedText:=Names;
        for Name in Files do begin
          Path:=Trim(Name); if Path='' then Continue;
          if ExtractFileExt(Path)='' then Path:=Path+'.bib';
          if (ExtractFileDrive(Path)='') and not (Path[1] in ['/','\']) then Path:=IncludeTrailingPathDelimiter(Directory)+Path;
          Path:=ExpandFileName(Path); if Seen.IndexOf(Path)>=0 then Continue; Seen.Add(Path);
          if not FileExists(Path) then Continue;
          try Text.LoadFromFile(Path); ReadDatabase(Text.Text); except on E:EFOpenError do Continue; on E:EReadError do Continue; end;
        end;
      end;
    end;
  finally Seen.Free; Text.Free; Files.Free; end;
end;
end.
