unit EnvironmentOptions;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes;
type
  TEnvironmentHeader=record
    Name,Options,Columns:string;
    BeginEnd,OptionsFirst,OptionsLast,ColumnsFirst,ColumnsLast:Integer;
  end;
function ReadEnvironmentHeader(const Source:string; out Header:TEnvironmentHeader):Boolean;
function SetEnvironmentOptions(const Source,Options:string):string;
function SetEnvironmentColumns(const Source,Columns:string):string;
function EnvironmentOption(const Options,Name:string; const Default:string=''):string;
function SetEnvironmentOption(const Options,Name,Value:string):string;
function ColumnEnvironment(const Name:string):Boolean;
procedure EnvironmentOptionNames(const Name:string; Dest:TStrings);
function EnvironmentOptionGroup(const Name,Key:string):string;
implementation
uses SysUtils, TeXMacros, TikZModel;
function ColumnEnvironment(const Name:string):Boolean;
begin Result:=(Name='longtable') or (Name='tabular') or (Name='tabular*') or (Name='tabularx') or (Name='array'); end;
function ReadEnvironmentHeader(const Source:string; out Header:TEnvironmentHeader):Boolean;
var P,A:Integer;
begin
  Header:=Default(TEnvironmentHeader); Header.OptionsFirst:=-1; Header.ColumnsFirst:=-1;
  P:=1; SkipTeXSpace(Source,P); Result:=ReadTeXCommand(Source,P)='begin'; if not Result then Exit;
  Header.Name:=ReadTeXGroup(Source,P,'{','}'); Result:=Header.Name<>''; if not Result then Exit;
  if (Header.Name='tabular*') or (Header.Name='tabularx') then ReadTeXGroup(Source,P,'{','}');
  Header.BeginEnd:=P-1; SkipTeXSpace(Source,P);
  if Copy(Source,P,1)='[' then begin
    A:=P; Header.Options:=ReadTeXGroup(Source,P,'[',']');
    if Copy(Source,P-1,1)<>']' then Exit(False);
    Header.OptionsFirst:=A-1; Header.OptionsLast:=P-1;
  end;
  if ColumnEnvironment(Header.Name) then begin
    SkipTeXSpace(Source,P); A:=P;
    if Copy(Source,P,1)='{' then begin
      Header.Columns:=ReadTeXGroup(Source,P,'{','}');
      if Copy(Source,P-1,1)<>'}' then Exit(False);
      Header.ColumnsFirst:=A-1; Header.ColumnsLast:=P-1;
    end;
  end;
end;
function SetEnvironmentOptions(const Source,Options:string):string;
var H:TEnvironmentHeader; A,B:Integer; Value:string;
begin
  Result:=Source; if not ReadEnvironmentHeader(Source,H) then Exit;
  Value:=''; if Trim(Options)<>'' then Value:='['+Options+']';
  A:=H.OptionsFirst; B:=H.OptionsLast; if A<0 then begin A:=H.BeginEnd; B:=A; end;
  Result:=Copy(Source,1,A)+Value+Copy(Source,B+1,MaxInt);
end;
function SetEnvironmentColumns(const Source,Columns:string):string;
var H:TEnvironmentHeader;
begin
  Result:=Source; if not ReadEnvironmentHeader(Source,H) or not ColumnEnvironment(H.Name) or (H.ColumnsFirst<0) then Exit;
  Result:=Copy(Source,1,H.ColumnsFirst)+'{'+Columns+'}'+Copy(Source,H.ColumnsLast+1,MaxInt);
end;
function EnvironmentOption(const Options,Name,Default:string):string;
var Entry:TDiagramOption; P:Integer; Value:string;
begin
  Result:=Default;
  for Entry in DiagramOptions(Options) do if Entry.Name=Name then begin
    Value:=Entry.Value; P:=1;
    if (Copy(Value,1,1)='{') then begin Result:=ReadTeXGroup(Value,P,'{','}'); if P<=Length(Value) then Result:=Value; end
    else Result:=Value;
  end;
end;
function SetEnvironmentOption(const Options,Name,Value:string):string;
var Entry:TDiagramOption; Item:string;
begin
  Result:='';
  for Entry in DiagramOptions(Options) do if Entry.Name<>Name then begin
    Item:=Entry.Original; if Trim(Item)='' then Continue;
    if Result<>'' then Result:=Result+','; Result:=Result+Item;
  end;
  if Value<>'' then begin
    if Result<>'' then Result:=Result+','; Result:=Result+Name+'='+Value;
  end;
end;
procedure EnvironmentOptionNames(const Name:string; Dest:TStrings);
var Value:string;
begin
  Value:='';
  if Name='tcolorbox' then Value:='title,colback,colframe,coltext,coltitle,colbacktitle,fonttitle,fontupper,width,boxrule,arc,outer arc,boxsep,left,right,top,bottom,toptitle,bottomtitle,before skip,after skip'
  else if Name='lstlisting' then Value:='language,style,basicstyle,keywordstyle,commentstyle,stringstyle,identifierstyle,numbers,numberstyle,numbersep,firstnumber,stepnumber,frame,rulecolor,backgroundcolor,tabsize,columns,basewidth,breaklines,showstringspaces,caption,label';
  Dest.StrictDelimiter:=True; Dest.CommaText:=Value;
end;
function EnvironmentOptionGroup(const Name,Key:string):string;
begin
  if Name='tcolorbox' then begin
    if (Pos('title',Key)>0) then Exit('Title');
    if (Pos('col',Key)=1) or (Key='fontupper') then Exit('Colors and fonts');
    if (Key='boxrule') or (Key='arc') or (Key='outer arc') then Exit('Border');
    Exit('Size and spacing');
  end;
  if Name='lstlisting' then begin
    if (Key='language') or (Key='style') or (Key='caption') or (Key='label') then Exit('General');
    if (Pos('style',Key)>0) and (Key<>'numberstyle') then Exit('Fonts and highlighting');
    if (Pos('number',Key)>0) then Exit('Line numbers');
    if (Key='frame') or (Pos('color',Key)>0) then Exit('Border and background');
    Exit('Layout');
  end;
  Result:='Layout';
end;
end.
