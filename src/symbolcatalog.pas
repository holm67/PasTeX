unit SymbolCatalog;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, TeXMacros;
procedure InstalledSymbolPackages(Dest:TStrings);
procedure ComprehensiveSymbolNames(Dest:TStrings; Packages:TStrings=nil);
procedure PackageSymbolNames(const PackageName:string; Registry:TMacroRegistry; Dest:TStrings);
implementation
uses SysUtils, Process, ZStream, TeXFontData, RegExpr, StrUtils;
procedure InstalledSymbolPackages(Dest:TStrings);
const Packages='amssymb,wasysym,stmaryrd,latexsym,marvosym,bbding,ifsym,pifont,manfnt,'+
  'textcomp,gensymb,eurosym,esint,mathabx,mathabx-type1, MnSymbol,fdsymbol,stix,stix2,'+
  'tipa,phonetic,adforn,fourier,mathdesign,txfonts,pxfonts,newtxmath,boisik,utfsym';
var Names:TStringList; Name:string;
begin
  Dest.Clear; Names:=TStringList.Create;
  try
    Names.CommaText:=Packages;
    for Name in Names do if FindTeXFile(Trim(Name)+'.sty')<>'' then Dest.Add(Trim(Name));
  finally Names.Free; end;
end;
function ReadCatalogue(const Path:string):string;
var Data:TGZFileStream;
    Buffer:array[0..4095] of Byte; Count,Total:Integer; Memory:TMemoryStream;
begin
  Result:=''; if not FileExists(Path) then Exit;
  Data:=TGZFileStream.Create(Path,gzopenread); Memory:=TMemoryStream.Create;
  try
    Total:=0;
    repeat
      Count:=Data.Read(Buffer,SizeOf(Buffer)); Inc(Total,Count);
      if Total>2*1024*1024 then Exit; Memory.WriteBuffer(Buffer,Count);
    until Count=0;
    SetLength(Result,Total); if Total>0 then begin Memory.Position:=0; Memory.ReadBuffer(Result[1],Total); end;
  finally Memory.Free; Data.Free; end;
end;
procedure CataloguePackages(const Source:string; Packages:TStrings);
var Maps,Tables,Entries:TRegExpr; Names:TStringList; PackageName,Table,Command,Key:string; Start,Next:Integer;
begin
  Names:=TStringList.Create; Maps:=TRegExpr.Create; Tables:=TRegExpr.Create; Entries:=TRegExpr.Create;
  try
    Packages.Add('\ding=pifont'); Packages.Add('\Pisymbol=pifont'); Packages.Add('\mvchr=marvosym');
    Maps.Expression:='\\newcommand\\([A-Za-z]+)\{\\pkgname\{([^{}]+)\}\}';
    if Maps.Exec(Source) then repeat Names.Values[Maps.Match[1]]:=Maps.Match[2]; until not Maps.ExecNext;
    Names.Values['AMS']:='amssymb';
    Tables.Expression:='\\begin\{symtable\}(?:\[([^\]]+)\])?';
    Entries.Expression:='\\(?:K[A-Za-z]*|X[A-Za-z]*|cmdI)\s*(?:\[[^\]]*\])?\s*\\([A-Za-z]+)';
    if Tables.Exec(Source) then repeat
      Key:=Tables.Match[1]; PackageName:=Names.Values[Key];
      if PackageName='' then Continue;
      Start:=Tables.MatchPos[0]+Tables.MatchLen[0]; Next:=PosEx('\begin{symtable}',Source,Start);
      if Next=0 then Next:=Length(Source)+1;
      Table:=Copy(Source,Start,Next-Start);
      if Entries.Exec(Table) then repeat
        Command:='\'+Entries.Match[1]; Packages.Add(Command+'='+PackageName);
      until not Entries.ExecNext;
    until not Tables.ExecNext;
  finally Entries.Free; Tables.Free; Maps.Free; Names.Free; end;
end;
procedure ComprehensiveSymbolNames(Dest:TStrings; Packages:TStrings);
var Path,Name:string; Lines:TStringList; I,A:Integer; Valid:Boolean;
begin
  { The catalogue belongs to the user's TeX distribution; do not retain its
    source or allocate a glyph for every entry. Loading happens on request. }
  Dest.Clear; if Packages<>nil then Packages.Clear; Path:='';
  try
    if not RunCommand('kpsewhich',['--format=TeX system documentation','SYMLIST.gz'],Path,[poNoConsole]) then Exit;
  except Exit; end;
  Path:=Trim(Path); if not FileExists(Path) then Exit;
  Lines:=TStringList.Create;
  try
      Lines.Text:=ReadCatalogue(Path);
      for Name in Lines do begin
        if (Length(Name)<2) or (Name[1]<>'\') or (Length(Name)>120) then Continue;
        I:=2; while (I<=Length(Name)) and (Name[I] in ['A'..'Z','a'..'z']) do Inc(I);
        if I=2 then begin if Length(Name)=2 then Dest.Add(Name); Continue; end;
        Valid:=True;
        while I<=Length(Name) do begin
          if Name[I]='*' then begin Inc(I); Continue; end;
          A:=I;
          if Name[I]='{' then ReadTeXGroup(Name,I,'{','}',True)
          else if Name[I]='[' then ReadTeXGroup(Name,I,'[',']',True)
          else begin Valid:=False; Break; end;
          if I=A then begin Valid:=False; Break; end;
        end;
        if Valid then Dest.Add(Name);
      end;
      if Dest is TStringList then begin
        TStringList(Dest).CaseSensitive:=True; TStringList(Dest).UseLocale:=False;
        TStringList(Dest).Sorted:=True; TStringList(Dest).Duplicates:=dupIgnore;
      end;
      if Packages<>nil then CataloguePackages(ReadCatalogue(ExtractFilePath(Path)+'source'+DirectorySeparator+'symbols.tex.gz'),Packages);
  finally Lines.Free; end;
end;
procedure PackageSymbolNames(const PackageName:string; Registry:TMacroRegistry; Dest:TStrings);
var Names:TStringList; Name:string; Info:TMacroInfo;
begin
  Dest.Clear; Registry.Load('\documentclass{article}\usepackage{'+PackageName+'}',GetCurrentDir);
  Names:=TStringList.Create;
  try
    Registry.Names(Names);
    for Name in Names do begin
      Info:=Registry.Find(Copy(Name,2,MaxInt));
      if (Info=nil) or (Info.ArgCount<>0) or (Info.Undefined) or (Pos('@',Name)>0) then Continue;
      if (Info.GlyphFont<>'') or (Info.GlyphPlan<>'') or (Info.NativeName<>'') or
        (Info.Expandable and (Info.PackageSource<>'') and
         (ChangeFileExt(ExtractFileName(Info.PackageSource),'')=PackageName)) then Dest.Add(Name);
    end;
  finally Names.Free; end;
end;
end.
