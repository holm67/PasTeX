unit TeXInstalledStyles;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes;
procedure InstalledBibliographyStyles(const Directory:string; BibTeX,BibLaTeX,Citations:TStrings);
implementation
uses SysUtils, StrUtils, Process, Contnrs;
type
  TStylePath=class
    Base:string;
    Recursive,DatabaseOnly:Boolean;
    BibTeX:Boolean;
  end;
procedure InstalledBibliographyStyles(const Directory:string; BibTeX,BibLaTeX,Citations:TStrings);
var Paths:TObjectList; Databases,Visited,Names,BBX,CBX:TStringList; Path:TStylePath;
    Root,Value,Base:string; I,P:Integer;
  procedure ReadPaths(const FormatName:string; ForBibTeX:Boolean);
  var List:TStringList; Item:TStylePath; Entry,Text,ProgramName:string; Q,K:Integer;
  begin
    Text:='';
    ProgramName:='latex'; if ForBibTeX then ProgramName:='bibtex';
    try RunCommand('kpsewhich',['--progname='+ProgramName,'--show-path='+FormatName],Text,[poNoConsole]); except end;
    List:=TStringList.Create;
    try
      List.StrictDelimiter:=True; List.Delimiter:=PathSeparator; List.QuoteChar:=#0; List.DelimitedText:=Trim(Text);
      for K:=0 to List.Count-1 do begin
        Entry:=List[K];
        if Entry='' then Continue;
        Item:=TStylePath.Create; Item.BibTeX:=ForBibTeX; Item.DatabaseOnly:=Copy(Entry,1,2)='!!';
        while Copy(Entry,1,1)='!' do Delete(Entry,1,1);
        Entry:=StringReplace(Entry,'\','/',[rfReplaceAll]);
        if Copy(Entry,1,2)='//' then Q:=PosEx('//',Entry,3) else Q:=Pos('//',Entry);
        Item.Recursive:=Q>0; if Q>0 then Entry:=Copy(Entry,1,Q-1);
        if (Entry='.') and (Directory<>'') then Entry:=Directory;
        Item.Base:=IncludeTrailingPathDelimiter(ExpandFileName(Entry)); Paths.Add(Item);
      end;
    finally List.Free; end;
  end;
  function Kind(const FileName:string):Integer;
  begin
    case LowerCase(ExtractFileExt(FileName)) of
      '.bst':Result:=0; '.bbx':Result:=1; '.cbx':Result:=2;
      else Result:=-1;
    end;
  end;
  function Allowed(const Folder:string; StyleKind:Integer):Boolean;
  var J:Integer; Item:TStylePath;
  begin
    Result:=False;
    for J:=0 to Paths.Count-1 do begin
      Item:=TStylePath(Paths[J]); if Item.BibTeX<>(StyleKind=0) then Continue;
      if SameFileName(Folder,Item.Base) or
        (Item.Recursive and SameFileName(Copy(Folder,1,Length(Item.Base)),Item.Base)) then Exit(True);
    end;
  end;
  procedure AddFile(const Folder,FileName:string);
  var K:Integer; StyleName:string;
  begin
    K:=Kind(FileName); if (K<0) or not Allowed(Folder,K) or not FileExists(Folder+FileName) then Exit;
    StyleName:=ChangeFileExt(FileName,'');
    case K of 0:Names.Add(StyleName); 1:BBX.Add(StyleName); 2:CBX.Add(StyleName); end;
  end;
  procedure Database(const DBRoot:string);
  var DB:TextFile; Line,Folder:string;
  begin
    if Databases.IndexOf(DBRoot)>=0 then Exit; Databases.Add(DBRoot);
    AssignFile(DB,DBRoot+'ls-R'); try Reset(DB); except Exit; end;
    try
      Folder:=DBRoot;
      while not EOF(DB) do begin
        ReadLn(DB,Line); if Line='' then Continue;
        if (Line[Length(Line)]=':') and (Copy(Line,1,1)='.') then begin
          Delete(Line,Length(Line),1); Folder:=IncludeTrailingPathDelimiter(ExpandFileName(DBRoot+Line));
        end else if Kind(Line)>=0 then AddFile(Folder,Line);
      end;
    finally CloseFile(DB); end;
  end;
  procedure Scan(const Folder:string; Recursive:Boolean; Depth:Integer=0);
  var Entry:TSearchRec;
  begin
    if (Depth>64) or (Visited.IndexOf(Folder)>=0) then Exit;
    { A nonrecursive path must not suppress a later recursive search. }
    if Recursive then Visited.Add(Folder);
    if FindFirst(Folder+'*',faAnyFile,Entry)<>0 then Exit;
    try
      repeat
        if (Entry.Name='.') or (Entry.Name='..') then Continue;
        if Entry.Attr and faDirectory<>0 then begin
          if Recursive then Scan(IncludeTrailingPathDelimiter(Folder+Entry.Name),True,Depth+1);
        end else AddFile(Folder,Entry.Name);
      until FindNext(Entry)<>0;
    finally FindClose(Entry); end;
  end;
  function SortedNames:TStringList;
  begin Result:=TStringList.Create; Result.CaseSensitive:=True; Result.Sorted:=True; Result.Duplicates:=dupIgnore; end;
begin
  Paths:=TObjectList.Create(True); Databases:=TStringList.Create; Visited:=TStringList.Create;
  Names:=SortedNames; BBX:=SortedNames; CBX:=SortedNames;
  try
    ReadPaths('bst',True); ReadPaths('tex',False);
    { Even without kpsewhich, document-local styles remain usable. No list
      from the build machine is embedded in the executable. }
    for P:=0 to 1 do begin
      Path:=TStylePath.Create; Path.BibTeX:=P=0;
      Base:=Directory; if Base='' then Base:=GetCurrentDir;
      Path.Base:=IncludeTrailingPathDelimiter(ExpandFileName(Base)); Paths.Add(Path);
    end;
    for I:=0 to Paths.Count-1 do begin
      Path:=TStylePath(Paths[I]); Root:=ExcludeTrailingPathDelimiter(Path.Base);
      while (Root<>'') and not FileExists(IncludeTrailingPathDelimiter(Root)+'ls-R') do begin
        Value:=ExtractFileDir(Root); if Value=Root then begin Root:=''; Break; end; Root:=Value;
      end;
      if Root<>'' then Database(IncludeTrailingPathDelimiter(Root));
      { TeX Live indexes system trees with ls-R; user trees and MiKTeX
        trees without this index are enumerated directly. }
      if not Path.DatabaseOnly or (Root='') then Scan(Path.Base,Path.Recursive);
    end;
    BibTeX.Assign(Names); BibLaTeX.Assign(BBX); Citations.Assign(CBX);
  finally CBX.Free; BBX.Free; Names.Free; Visited.Free; Databases.Free; Paths.Free; end;
end;
end.
