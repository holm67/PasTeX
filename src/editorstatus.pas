unit EditorStatus;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, TeXDocument, MathModel;
type
  TEditorStatusCache=class
  private
    FParts:TStringList;
    FDocument:TTeXDocument;
    FRevision:Integer;
    FWords:SizeInt;
    FMetrics:array of record Breaks,LastColumn,Line,Column:Integer; Words:SizeInt; end;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Refresh(Document:TTeXDocument; Revision:Integer);
    procedure Position(Block,Offset:Integer; out Line,Column:Integer);
    property Words:SizeInt read FWords;
  end;
function CommandPath(Node:TMathNode):string;
implementation
uses SysUtils, Math, LazUTF8, TeXMacros, DocumentInfo;
function CommandPath(Node:TMathNode):string;
var Name,Code:string; P:Integer;
begin
  Result:='';
  while Node<>nil do begin
    Name:=''; Code:=Node.Prefix;
    if Node.Kind in [mkEnvironment,mkVerbatim] then Name:='\begin{'+Node.Text+'}'
    else if (Node.Kind=mkFormula) and (Pos('\begin{',Code)<>1) then begin
      if Code='$' then Name:='$…$' else if Code='$$' then Name:='$$…$$'
      else if Code='\[' then Name:='\[…\]' else if Code='\(' then Name:='\(…\)';
    end else if Node.Kind in [mkFraction,mkRoot,mkIndexedRoot] then begin
      if Node.Kind=mkFraction then Name:='\frac' else Name:='\sqrt';
    end;
    if (Name='') and not (Node.Kind in [mkRow,mkProse,mkText,mkRaw]) then begin
      if Code='' then Code:=Node.Text;
      if (Code='') and (Node.Kind in [mkDefinition,mkUnknownCommand,mkDiagram]) then Code:=Node.TeX;
      P:=1;
      if Copy(Code,1,1)='\' then begin
        Name:='\'+ReadTeXCommand(Code,P);
        if Name='\begin' then Name:=Name+'{'+ReadTeXGroup(Code,P,'{','}')+'}';
      end else if (Copy(Code,1,1)='^') or (Copy(Code,1,1)='_') then Name:=Code[1];
    end;
    if Name<>'' then begin if Result<>'' then Result:=Name+' › '+Result else Result:=Name; end;
    Node:=Node.Parent;
  end;
end;
procedure Measure(const Text:string; Offset:Integer; out Breaks,LastColumn:Integer);
var P,Start:Integer;
begin
  Breaks:=0; Start:=1; P:=1; Offset:=EnsureRange(Offset,0,Length(Text));
  while P<=Offset do begin
    if Text[P] in [#10,#13] then begin
      if (Text[P]=#13) and (P<Offset) and (Text[P+1]=#10) then Inc(P);
      Inc(Breaks); Start:=P+1;
    end;
    Inc(P);
  end;
  LastColumn:=UTF8Length(Copy(Text,Start,Offset-Start+1));
end;
constructor TEditorStatusCache.Create;
begin inherited Create; FParts:=TStringList.Create; FRevision:=-1; end;
destructor TEditorStatusCache.Destroy;
begin FParts.Free; inherited Destroy; end;
procedure TEditorStatusCache.Refresh(Document:TTeXDocument; Revision:Integer);
var I,N,Line,Column:Integer; Text:string;
begin
  if (Document=FDocument) and (Revision=FRevision) then Exit;
  FDocument:=Document; FRevision:=Revision; FWords:=0; N:=Document.Blocks.Count+1;
  while FParts.Count>N do FParts.Delete(FParts.Count-1);
  SetLength(FMetrics,N); Line:=1; Column:=1;
  for I:=0 to N-1 do begin
    if I=0 then Text:=Document.Preamble else Text:=Document.Blocks[I-1];
    if (I>=FParts.Count) or (FParts[I]<>Text) then begin
      Measure(Text,Length(Text),FMetrics[I].Breaks,FMetrics[I].LastColumn);
      FMetrics[I].Words:=0;
      if (I>0) and not Document.PreambleOnly then FMetrics[I].Words:=DocumentStatistics('',Text).Words;
      if I>=FParts.Count then FParts.Add(Text) else FParts[I]:=Text;
    end;
    FMetrics[I].Line:=Line; FMetrics[I].Column:=Column;
    Inc(Line,FMetrics[I].Breaks);
    if FMetrics[I].Breaks>0 then Column:=FMetrics[I].LastColumn+1 else Inc(Column,FMetrics[I].LastColumn);
    Inc(FWords,FMetrics[I].Words);
  end;
end;
procedure TEditorStatusCache.Position(Block,Offset:Integer; out Line,Column:Integer);
var I,Breaks,LastColumn:Integer;
begin
  Line:=1; Column:=1; I:=Block+1; if (I<0) or (I>=FParts.Count) then Exit;
  Measure(FParts[I],Offset,Breaks,LastColumn); Line:=FMetrics[I].Line+Breaks;
  Column:=LastColumn+1; if Breaks=0 then Column:=FMetrics[I].Column+LastColumn;
end;
end.
