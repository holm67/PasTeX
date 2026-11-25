unit TikZPath;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type
  TDiagramPathRow=record
    Operation,Coordinate,Options,Text,Name:string;
    Leading,Original,Signature:string;
  end;
  TDiagramPathRows=array of TDiagramPathRow;
function ParseDiagramPath(const Source:string; StandaloneNode:Boolean=False):TDiagramPathRows;
function DiagramPathSource(const Rows:TDiagramPathRows; StandaloneNode:Boolean=False):string;
function DiagramPathSignature(const Row:TDiagramPathRow):string;
implementation
uses SysUtils, TeXMacros, TikZModel;
function DiagramPathSignature(const Row:TDiagramPathRow):string;
begin Result:=Row.Operation+#0+Row.Coordinate+#0+Row.Options+#0+Row.Text+#0+Row.Name; end;
function ParseDiagramPath(const Source:string; StandaloneNode:Boolean):TDiagramPathRows;
var P,A,Start,Q,I:Integer; Row:TDiagramPathRow; Group:TDiagramRange;
  function WordAt(const Word:string):Boolean;
  begin Result:=(Copy(Source,P,Length(Word))=Word) and
    ((P+Length(Word)>Length(Source)) or not (Source[P+Length(Word)] in ['a'..'z','A'..'Z'])); end;
  function GroupText(Open,Close:Char):string;
  begin
    Result:=''; if DiagramGroup(Source,P,Open,Close,Group) then Result:=Copy(Source,Group.First+1,Group.Last-Group.First);
  end;
begin
  Result:=nil; P:=1;
  while P<=Length(Source) do begin
    A:=P; SkipTeXSpace(Source,P); if P>Length(Source) then begin
      if Length(Result)>0 then Result[High(Result)].Original:=Result[High(Result)].Original+Copy(Source,A,MaxInt);
      Break;
    end;
    Row:=Default(TDiagramPathRow); Start:=P; Row.Leading:=Copy(Source,A,P-A);
    if StandaloneNode then Row.Operation:='node'
    else if Copy(Source,P,2)='--' then begin Inc(P,2); Row.Operation:='line'; end
    else if WordAt('to') then begin Inc(P,2); Row.Operation:='to'; Row.Options:=GroupText('[',']'); end
    else if Copy(Source,P,2)='|-' then begin Inc(P,2); Row.Operation:='|-'; end
    else if Copy(Source,P,2)='-|' then begin Inc(P,2); Row.Operation:='-|'; end
    else if WordAt('rectangle') then begin Inc(P,9); Row.Operation:='rectangle'; end
    else if WordAt('circle') then begin Inc(P,6); Row.Operation:='circle'; end
    else if WordAt('node') then begin Inc(P,4); Row.Operation:='node'; end
    else if Copy(Source,P,1)='(' then Row.Operation:='move';
    SkipTeXSpace(Source,P);
    if WordAt('cycle') then begin Inc(P,5); Row.Operation:='cycle'; end
    else if Row.Operation='node' then begin
      Row.Options:=GroupText('[',']'); SkipTeXSpace(Source,P);
      if Copy(Source,P,1)='(' then Row.Name:=GroupText('(',')');
      SkipTeXSpace(Source,P);
      if WordAt('at') then begin Inc(P,2); Row.Coordinate:=GroupText('(',')'); end;
      Row.Text:=GroupText('{','}');
    end else if Row.Operation<>'' then begin
      Q:=P;
      while Copy(Source,P,1)='+' do Inc(P);
      if P>Q then begin
        Row.Coordinate:=Copy(Source,Q,P-Q)+'('+GroupText('(',')')+')';
      end else Row.Coordinate:=GroupText('(',')');
    end;
    if (Row.Operation='') or (P<=Start) then begin
      Row.Operation:='raw'; P:=Start;
      while P<=Length(Source) do begin
        if (P>Start) and ((Copy(Source,P,2)='--') or WordAt('node') or WordAt('to')) then Break;
        if Source[P]='\' then ReadTeXCommand(Source,P)
        else if Source[P]='{' then ReadTeXGroup(Source,P,'{','}') else Inc(P);
      end;
      Row.Text:=Copy(Source,Start,P-Start);
    end;
    Row.Original:=Copy(Source,A,P-A); Row.Signature:=DiagramPathSignature(Row);
    I:=Length(Result); SetLength(Result,I+1); Result[I]:=Row;
    if StandaloneNode then Break;
  end;
end;
function DiagramPathSource(const Rows:TDiagramPathRows; StandaloneNode:Boolean):string;
var Row:TDiagramPathRow; Value,Coordinate,Options:string;
begin
  Result:='';
  for Row in Rows do begin
    if Row.Signature=DiagramPathSignature(Row) then begin Result:=Result+Row.Original; Continue; end;
    Coordinate:=Trim(Row.Coordinate);
    if (Coordinate<>'') and not (Coordinate[1] in ['(','+']) then Coordinate:='('+Coordinate+')';
    Options:=''; if Trim(Row.Options)<>'' then Options:='['+Row.Options+']';
    case Row.Operation of
      'move':Value:=Coordinate;
      'line':Value:='-- '+Coordinate;
      'to':Value:='to'+Options+' '+Coordinate;
      '|-','-|':Value:=Row.Operation+' '+Coordinate;
      'rectangle','circle':Value:=Row.Operation+' '+Coordinate;
      'cycle':Value:='-- cycle';
      'node':begin
        Value:=''; if not StandaloneNode then Value:='node'+Options+' ';
        if Row.Name<>'' then Value:=Value+'('+Row.Name+') ';
        if Coordinate<>'' then Value:=Value+'at '+Coordinate+' ';
        Value:=Value+'{'+Row.Text+'}';
      end;
      else Value:=Row.Text;
    end;
    if Row.Leading<>'' then Value:=Row.Leading+Value
    else if Result<>'' then Value:=' '+Value;
    Result:=Result+Value;
  end;
end;
end.
