unit DocumentFormats;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils;
function StandaloneTeX(const Body:string):string;
function WordToTeX(const FileName:string; out Report:string):string;
implementation
uses StrUtils, DOM, ArchiveXML, SpreadsheetData;
function StandaloneTeX(const Body:string):string;
var S:UnicodeString; C:WideChar; Chinese:Boolean;
begin
  S:=UTF8Decode(Body); Chinese:=False; for C in S do if (Ord(C)>=$2E80) and (Ord(C)<=$9FFF) then begin Chinese:=True; Break; end;
  Result:='\documentclass[12pt]{article}'+#10;
  if Chinese then Result:='% !TeX program = xelatex'+#10+Result+'\usepackage{ctex}'+#10;
  Result:=Result+'\usepackage[margin=1in]{geometry}'+#10+'\usepackage{amsmath,amssymb,graphicx,hyperref}'+#10+
    '\begin{document}'+#10+Body+#10+'\end{document}'+#10;
end;
function WordToTeX(const FileName:string; out Report:string):string;
var Doc:TXMLDocument; Body:TDOMNode; Skipped:Integer;
  function Convert(Node:TDOMNode):string;
  var Child,Props,Style:TDOMNode; Name,Value,Command:string;
  begin
    Result:=''; Name:=XMLName(Node);
    if Name='t' then Exit(EscapeTeXText(XMLContent(Node)));
    if (Name='drawing') or (Name='pict') then begin Inc(Skipped); Exit; end;
    if Name='br' then Exit('\\'+#10);
    if Name='tab' then Exit('\quad ');
    Child:=Node.FirstChild; while Child<>nil do begin Result:=Result+Convert(Child); Child:=Child.NextSibling; end;
    if Name='r' then begin
      Props:=XMLChild(Node,'rPr');
      Style:=XMLChild(Props,'b'); if (Style<>nil) and (XMLAttr(Style,'val')<>'0') then Result:='\textbf{'+Result+'}';
      Style:=XMLChild(Props,'i'); if (Style<>nil) and (XMLAttr(Style,'val')<>'0') then Result:='\textit{'+Result+'}';
    end else if Name='p' then begin
      Props:=XMLChild(Node,'pPr'); Style:=XMLChild(Props,'pStyle'); Value:=LowerCase(XMLAttr(Style,'val')); Command:='';
      if Value='heading1' then Command:='section' else if Value='heading2' then Command:='subsection' else if Value='heading3' then Command:='subsubsection';
      if Command<>'' then Result:='\'+Command+'{'+Trim(Result)+'}'; Result:=Result+#10+#10;
    end else if Name='tc' then Result:=Trim(Result)+' & '
    else if Name='tr' then begin Result:=TrimRight(Result); if Copy(Result,Length(Result)-1,2)=' &' then Delete(Result,Length(Result)-1,2); Result:=Result+' \\'+#10; end
    else if Name='tbl' then begin
      Props:=XMLChild(Node,'tblGrid'); Child:=nil; if Props<>nil then Child:=Props.FirstChild; Value:='';
      while Child<>nil do begin if XMLName(Child)='gridCol' then Value:=Value+'l'; Child:=Child.NextSibling; end;
      if Value='' then Value:='l'; Result:='\begin{tabular}{'+Value+'}'+#10+Result+'\end{tabular}'+#10+#10;
    end;
  end;
begin
  Skipped:=0; Report:='Imported text, headings, bold/italic runs and tables. Use Pandoc for richer conversion.';
  Doc:=ParseXMLText(ArchiveText(FileName,'word/document.xml'));
  try Body:=XMLChild(Doc.DocumentElement,'body'); if Body=nil then raise Exception.Create('No Word document body');
    Result:=StandaloneTeX(Convert(Body));
    if Skipped>0 then Report:=Report+' '+IntToStr(Skipped)+' drawings were omitted; install Pandoc to extract media.';
  finally Doc.Free; end;
end;
end.
