unit BibliographyForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, PreambleModel, TeXDocument;
type
  TBibliographyForm=class(TForm)
  private
    FBibTeX,FBibLaTeX,FCitations:TStringList;
    FDirectory:string;
    FStylesLoaded,FConfigured:Boolean;
    procedure RefreshStyles;
    procedure BackendChanged(Sender:TObject);
    procedure StyleChanged(Sender:TObject);
  public
    Databases,Style,Backend,CitationStyle:TComboBox;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(const Source:string; const Directory:string='');
    function Apply(Document:TTeXDocument; InsertIndex:Integer; MoveList:Boolean=False):Integer;
    property Configured:Boolean read FConfigured;
  end;
implementation
uses TeXMacros, TeXInstalledStyles, UITheme;
function SkipLiteral(const Source:string; var P:Integer):Boolean;
var Q,K:Integer; Cmd,Name,Ending:string; Delimiter:Char;
begin
  Result:=False; Q:=P; Cmd:=ReadTeXCommand(Source,Q);
  if Cmd='verb' then begin
    if Copy(Source,Q,1)='*' then Inc(Q);
    if Q<=Length(Source) then begin
      Delimiter:=Source[Q]; Inc(Q);
      while (Q<=Length(Source)) and not (Source[Q] in [Delimiter,#10,#13]) do Inc(Q);
      if (Q<=Length(Source)) and (Source[Q]=Delimiter) then Inc(Q);
    end;
    P:=Q; Exit(True);
  end;
  if Cmd<>'begin' then Exit; Name:=ReadTeXGroup(Source,Q,'{','}');
  if (Name<>'verbatim') and (Name<>'verbatim*') and (Name<>'lstlisting') and (Name<>'minted') then Exit;
  Ending:='\end{'+Name+'}'; K:=Pos(Ending,Copy(Source,Q,MaxInt));
  if K>0 then P:=Q+K-1+Length(Ending) else P:=Length(Source)+1;
  Result:=True;
end;
constructor TBibliographyForm.Create(AOwner:TComponent);
var B:TButton;
  function Combo(const Title,Items:string; Top:Integer):TComboBox;
  var L:TLabel;
  begin
    L:=TLabel.Create(Self); L.Parent:=Self; L.SetBounds(16,Top+6,170,24); L.Caption:=Title;
    Result:=TComboBox.Create(Self); Result.Parent:=Self; Result.SetBounds(190,Top,306,30);
    Result.Items.Delimiter:=';'; Result.Items.StrictDelimiter:=True; Result.Items.DelimitedText:=Items;
    Result.ItemIndex:=0;
  end;
begin
  inherited CreateNew(AOwner); Caption:='Bibliography configuration'; Position:=poMainFormCenter; BorderStyle:=bsDialog;
  FBibTeX:=TStringList.Create; FBibLaTeX:=TStringList.Create; FCitations:=TStringList.Create;
  ClientWidth:=520; ClientHeight:=238;
  Databases:=Combo('Database files', 'references.bib',16); Databases.Hint:='Comma separated .bib files'; Databases.ShowHint:=True;
  Style:=Combo('Bibliography style','',58); Style.Text:='plain'; Style.OnChange:=@StyleChanged;
  Backend:=Combo('Backend','BibTeX;biblatex / Biber;biblatex / BibTeX',100); Backend.Style:=csDropDownList; Backend.OnChange:=@BackendChanged;
  CitationStyle:=Combo('Citation style','Same as bibliography',142); CitationStyle.Enabled:=False;
  B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(306,190,90,32); B.Caption:='Apply'; B.Default:=True; B.ModalResult:=mrOK;
  B:=TButton.Create(Self); B.Parent:=Self; B.SetBounds(406,190,90,32); B.Caption:='Cancel'; B.Cancel:=True; B.ModalResult:=mrCancel;
  ApplyTheme(Self);
end;
destructor TBibliographyForm.Destroy;
begin FCitations.Free; FBibLaTeX.Free; FBibTeX.Free; inherited Destroy; end;
procedure TBibliographyForm.RefreshStyles;
begin
  InstalledBibliographyStyles(FDirectory,FBibTeX,FBibLaTeX,FCitations); FStylesLoaded:=True;
end;
procedure TBibliographyForm.BackendChanged(Sender:TObject);
var OldStyle,OldCitation,DefaultStyle:string;
begin
  if not FStylesLoaded then RefreshStyles;
  OldStyle:=Style.Text; OldCitation:=CitationStyle.Text; CitationStyle.Items.Clear;
  if Backend.ItemIndex=0 then begin
    Style.Items.Assign(FBibTeX); CitationStyle.Enabled:=False; DefaultStyle:='plain';
    if (OldStyle='ieee') then OldStyle:='IEEEtran' else if OldStyle='apa' then OldStyle:='apalike';
  end else begin
    Style.Items.Assign(FBibLaTeX); CitationStyle.Enabled:=True; DefaultStyle:='numeric';
    if OldStyle='IEEEtran' then OldStyle:='ieee' else if OldStyle='apalike' then OldStyle:='apa';
  end;
  CitationStyle.Items.Add('Same as bibliography');
  if Backend.ItemIndex<>0 then CitationStyle.Items.AddStrings(FCitations);
  if CitationStyle.Items.IndexOf(OldCitation)>=0 then CitationStyle.Text:=OldCitation else CitationStyle.ItemIndex:=0;
  if Style.Items.IndexOf(OldStyle)>=0 then Style.Text:=OldStyle
  else if Style.Items.IndexOf(DefaultStyle)>=0 then Style.Text:=DefaultStyle
  else if Style.Items.Count>0 then Style.ItemIndex:=0 else Style.Text:='';
  StyleChanged(nil);
end;
procedure TBibliographyForm.StyleChanged(Sender:TObject);
begin
  if (Backend.ItemIndex=0) or (CitationStyle.Text<>'Same as bibliography') or
     (FCitations.IndexOf(Style.Text)>=0) or (FBibLaTeX.IndexOf(Style.Text)<0) then Exit;
  { Some installed .bbx styles have no corresponding .cbx. Use a real
    citation style instead of requesting a nonexistent file from biblatex. }
  if FCitations.IndexOf('numeric')>=0 then CitationStyle.Text:='numeric'
  else if FCitations.Count>0 then CitationStyle.Text:=FCitations[0];
end;
procedure TBibliographyForm.Load(const Source:string; const Directory:string);
var P,I,Q:Integer; Cmd,Value:string; Model:TPreambleModel; Options:TStringList; Document:TTeXDocument;
begin
  FDirectory:=Directory; FConfigured:=False; RefreshStyles;
  Model:=TPreambleModel.Create; Options:=TStringList.Create; Document:=TTeXDocument.Create; Backend.ItemIndex:=0;
  try
    Document.Parse(Source); Model.Load(Document.Preamble); I:=Model.PackageIndex('biblatex');
    if I>=0 then begin
      Options.Delimiter:=','; Options.StrictDelimiter:=True; Options.NameValueSeparator:='='; Options.DelimitedText:=TPackageOption(Model.Packages[I]).Options;
      Backend.ItemIndex:=1; if Options.Values['backend']='bibtex' then Backend.ItemIndex:=2;
      BackendChanged(nil); Value:=Options.Values['bibstyle']; if Value='' then Value:=Options.Values['style'];
      if Value<>'' then Style.Text:=Value;
      Value:=Options.Values['citestyle']; if Value<>'' then CitationStyle.Text:=Value;
      StyleChanged(nil);
    end else BackendChanged(nil);
    P:=1; Value:='';
    while P<=Length(Source) do begin
      if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
      if Source[P]<>'\' then begin Inc(P); Continue; end;
      if SkipLiteral(Source,P) then Continue;
      if ReadTeXDefinition(Source,P) then Continue; Q:=P; Cmd:=ReadTeXCommand(Source,P);
      if (Cmd<>'addbibresource') and SkipTeXBibResource(Source,Q) then begin P:=Q; Continue; end;
      if Cmd='addbibresource' then begin SkipTeXSpace(Source,P); if Copy(Source,P,1)='[' then ReadTeXGroup(Source,P,'[',']'); end;
      if (Cmd='bibliography') or (Cmd='addbibresource') then begin
        if Value<>'' then Value:=Value+','; Value:=Value+ReadTeXGroup(Source,P,'{','}',Cmd='addbibresource');
      end else if Cmd='bibliographystyle' then Style.Text:=ReadTeXGroup(Source,P,'{','}');
    end;
    if Value<>'' then begin Databases.Text:=Value; FConfigured:=True; end;
  finally Document.Free; Options.Free; Model.Free; end;
end;
function RemoveBibliographyCommands(const Source:string):string;
var P,A,Start,Q:Integer; Cmd:string;
begin
  Result:=''; P:=1; Start:=1;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    if SkipLiteral(Source,P) then Continue;
    A:=P; if ReadTeXDefinition(Source,P) then Continue; Cmd:=ReadTeXCommand(Source,P);
    Q:=A; if (Cmd<>'addbibresource') and SkipTeXBibResource(Source,Q) then begin P:=Q; Continue; end;
    if (Cmd<>'addbibresource') and (Cmd<>'bibliography') and (Cmd<>'bibliographystyle') and (Cmd<>'printbibliography') then Continue;
    SkipTeXSpace(Source,P); if Copy(Source,P,1)='[' then ReadTeXGroup(Source,P,'[',']');
    if Cmd<>'printbibliography' then ReadTeXGroup(Source,P,'{','}',Cmd='addbibresource');
    Result:=Result+Copy(Source,Start,A-Start); Start:=P;
  end;
  Result:=Result+Copy(Source,Start,MaxInt);
end;
function TBibliographyForm.Apply(Document:TTeXDocument; InsertIndex:Integer; MoveList:Boolean):Integer;
var Model:TPreambleModel; Files,Options:TStringList; FileName,S,Code,Value:string; I,J:Integer; HasList:Boolean;
begin
  if Trim(Databases.Text)='' then raise Exception.Create('Enter at least one bibliography database.');
  for S in [Databases.Text,Style.Text,CitationStyle.Text] do
    if (Pos('{',S)>0) or (Pos('}',S)>0) or (Pos('\',S)>0) or (Pos(#10,S)>0) then raise Exception.Create('Use database and style names without TeX commands or braces.');
  Model:=TPreambleModel.Create; Files:=TStringList.Create; Options:=TStringList.Create;
  try
    Model.Load(RemoveBibliographyCommands(Document.Preamble));
    Files.Delimiter:=','; Files.StrictDelimiter:=True; Files.DelimitedText:=Databases.Text;
    Code:='';
    if Backend.ItemIndex=0 then begin
      Model.RemovePackage('biblatex'); Value:=Trim(Style.Text); if Value='' then Value:='plain';
      for I:=0 to Files.Count-1 do Files[I]:=ChangeFileExt(Trim(Files[I]),'');
      Code:='\bibliographystyle{'+Value+'}'+LineEnding+'\bibliography{'+Files.DelimitedText+'}';
    end else begin
      Model.RemovePackage('natbib'); Options.Delimiter:=','; Options.StrictDelimiter:=True; Options.NameValueSeparator:='=';
      I:=Model.PackageIndex('biblatex'); if I>=0 then Options.DelimitedText:=TPackageOption(Model.Packages[I]).Options;
      if Backend.ItemIndex=2 then Options.Values['backend']:='bibtex' else Options.Values['backend']:='biber';
      Value:=Trim(Style.Text); if Value='' then Value:='numeric';
      I:=Options.IndexOfName('bibstyle'); if I>=0 then Options.Delete(I);
      if (FBibLaTeX.IndexOf(Value)>=0) and (FCitations.IndexOf(Value)<0) then begin
        I:=Options.IndexOfName('style'); if I>=0 then Options.Delete(I);
        Options.Values['bibstyle']:=Value;
      end else Options.Values['style']:=Value;
      I:=Options.IndexOfName('citestyle'); if I>=0 then Options.Delete(I);
      if (CitationStyle.Text<>'Same as bibliography') and (Trim(CitationStyle.Text)<>'') then Options.Values['citestyle']:=Trim(CitationStyle.Text);
      Model.SetPackage('biblatex',Options.DelimitedText);
      S:=Model.Source; J:=Pos('\begin{document}',S); if J=0 then J:=Length(S)+1;
      for FileName in Files do begin Value:=Trim(FileName); if ExtractFileExt(Value)='' then Value:=Value+'.bib'; Insert('\addbibresource{'+Value+'}'+LineEnding,S,J); Inc(J,Length('\addbibresource{'+Value+'}'+LineEnding)); end;
      Model.Load(S); Code:='\printbibliography';
    end;
    J:=-1;
    for I:=Document.Blocks.Count-1 downto 0 do begin
      S:=Document.Blocks[I]; HasList:=(Pos('\bibliography{',S)>0) or (Pos('\printbibliography',S)>0);
      if HasList then J:=I;
      Document.Blocks[I]:=RemoveBibliographyCommands(S);
      if MoveList and HasList and (Trim(Document.Blocks[I])='') then begin
        Document.Blocks.Delete(I); if I<InsertIndex then Dec(InsertIndex);
      end;
    end;
    if MoveList then J:=-1;
    if J<0 then begin
      J:=InsertIndex; if J<0 then J:=0; if J>Document.Blocks.Count then J:=Document.Blocks.Count;
      if J>0 then Document.Blocks[J-1]:=TrimRight(Document.Blocks[J-1])+LineEnding+LineEnding;
      Document.Blocks.Insert(J,Code+LineEnding+LineEnding);
    end else Document.Blocks[J]:=TrimRight(Document.Blocks[J])+LineEnding+Code+LineEnding+LineEnding;
    Document.Preamble:=Model.Source;
    Result:=J;
  finally Options.Free; Files.Free; Model.Free; end;
end;
end.
