unit SpreadsheetData;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Contnrs;
type
  TDataSheet=class
  private
    FRows:TObjectList;
    FCount:Integer;
  public
    Name:string;
    Columns:Integer;
    constructor Create;
    destructor Destroy; override;
    procedure Put(Row,Column:Integer; const Value:string);
    function Cell(Row,Column:Integer):string;
    function RowCount:Integer;
    function TeX(Top,Left,Bottom,Right:Integer; Header,Borders:Boolean):string;
  end;
  TDataWorkbook=class(TObjectList)
    procedure Load(const FileName:string);
  end;
function DataRange(const Text:string; out Top,Left,Bottom,Right:Integer):Boolean;
function EscapeTeXText(const Text:string):string;
implementation
uses DOM, ArchiveXML, StrUtils, Math, Gzio;
function EscapeTeXText(const Text:string):string;
var C:Char;
begin
  Result:=''; for C in Text do case C of
    '\':Result:=Result+'\textbackslash{}'; '{','}','$','&','#','_','%':Result:=Result+'\'+C;
    '~':Result:=Result+'\textasciitilde{}'; '^':Result:=Result+'\textasciicircum{}';
    #10,#13,#9:Result:=Result+' '; else Result:=Result+C;
  end;
end;
constructor TDataSheet.Create;
begin inherited; FRows:=TObjectList.Create(True); end;
destructor TDataSheet.Destroy;
begin FRows.Free; inherited; end;
procedure TDataSheet.Put(Row,Column:Integer; const Value:string);
var Line:TStringList;
begin
  if Value='' then Exit;
  if (Row<0) or (Row>=10000) or (Column<0) or (Column>=1024) or (FCount>=200000) then
    raise Exception.Create('Import exceeds 10,000 rows, 1,024 columns or 200,000 populated cells. Import a smaller workbook.');
  while FRows.Count<=Row do FRows.Add(TStringList.Create);
  Line:=TStringList(FRows[Row]); while Line.Count<=Column do Line.Add('');
  if Line[Column]='' then Inc(FCount); Line[Column]:=Value; Columns:=Max(Columns,Column+1);
end;
function TDataSheet.Cell(Row,Column:Integer):string;
begin Result:=''; if (Row<0) or (Row>=FRows.Count) or (Column<0) then Exit;
  if Column<TStringList(FRows[Row]).Count then Result:=TStringList(FRows[Row])[Column]; end;
function TDataSheet.RowCount:Integer;
begin Result:=FRows.Count; end;
function TDataSheet.TeX(Top,Left,Bottom,Right:Integer; Header,Borders:Boolean):string;
var R,C:Integer; Spec,Value:string;
begin
  Result:=''; if (RowCount=0) or (Columns=0) then Exit;
  Top:=EnsureRange(Top,0,RowCount-1); Bottom:=EnsureRange(Bottom,Top,RowCount-1);
  Left:=EnsureRange(Left,0,Columns-1); Right:=EnsureRange(Right,Left,Columns-1);
  Spec:=''; for C:=Left to Right do begin if Borders then Spec:=Spec+'|'; Spec:=Spec+'l'; end;
  if Borders then Spec:=Spec+'|'; Result:='\begin{tabular}{'+Spec+'}'+#10;
  if Borders then Result:=Result+'\hline'+#10;
  for R:=Top to Bottom do begin
    for C:=Left to Right do begin
      if C>Left then Result:=Result+' & '; Value:=EscapeTeXText(Cell(R,C));
      if Header and (R=Top) then Value:='\textbf{'+Value+'}'; Result:=Result+Value;
    end;
    Result:=Result+' \\'+#10; if Borders or (Header and (R=Top)) then Result:=Result+'\hline'+#10;
  end;
  Result:=Result+'\end{tabular}';
end;
function CellAddress(const Text:string; out Row,Column:Integer):Boolean;
var P:Integer; S:string;
begin
  S:=UpperCase(StringReplace(Trim(Text),'$','',[rfReplaceAll])); P:=1; Column:=0;
  while (P<=Length(S)) and (S[P] in ['A'..'Z']) do begin Column:=Column*26+Ord(S[P])-Ord('A')+1; Inc(P); if Column>1024 then Exit(False); end;
  Result:=(Column>0) and TryStrToInt(Copy(S,P,MaxInt),Row) and (Row>0) and (Row<=10000); Dec(Column); Dec(Row);
end;
function DataRange(const Text:string; out Top,Left,Bottom,Right:Integer):Boolean;
var P:Integer;
begin
  P:=Pos(':',Text); if P=0 then begin Result:=CellAddress(Text,Top,Left); Bottom:=Top; Right:=Left; end
  else Result:=CellAddress(Copy(Text,1,P-1),Top,Left) and CellAddress(Copy(Text,P+1,MaxInt),Bottom,Right);
  Result:=Result and (Bottom>=Top) and (Right>=Left);
end;
procedure TDataWorkbook.Load(const FileName:string);
var Doc,Data,Relations:TXMLDocument; Node,Sheet,Row,CellNode,Entry,ValueNode:TDOMNode;
    Shared,Lines:TStringList; Table:TDataSheet; I,J,R,C,Rep,RowRep,N,P:Integer;
    Ext,Text,Value,Target,ID,Token:string; GZ:GZFile; Buffer:array[0..8191] of Byte; Quoted:Boolean;
  function NewSheet(const Name:string):TDataSheet;
  begin Result:=TDataSheet.Create; Result.Name:=Name; Add(Result); end;
  procedure ReadShared(Node:TDOMNode);
  var Child:TDOMNode;
  begin
    if XMLName(Node)='si' then begin Shared.Add(XMLContent(Node)); Exit; end;
    Child:=Node.FirstChild; while Child<>nil do begin ReadShared(Child); Child:=Child.NextSibling; end;
  end;
  procedure ReadODS(Node:TDOMNode);
  var Child:TDOMNode; RR,CC:Integer;
  begin
    if XMLName(Node)<>'table' then begin Child:=Node.FirstChild; while Child<>nil do begin ReadODS(Child); Child:=Child.NextSibling; end; Exit; end;
    Table:=NewSheet(XMLAttr(Node,'name','Sheet')); R:=0; Row:=Node.FirstChild;
    while Row<>nil do begin
      if XMLName(Row)='table-row' then begin
        RowRep:=Min(10000,Max(1,StrToIntDef(XMLAttr(Row,'number-rows-repeated','1'),1))); C:=0; CellNode:=Row.FirstChild;
        while CellNode<>nil do begin
          if (XMLName(CellNode)='table-cell') or (XMLName(CellNode)='covered-table-cell') then begin
            Value:=XMLContent(CellNode);
            if Value='' then Value:=XMLAttr(CellNode,'value',XMLAttr(CellNode,'string-value',
              XMLAttr(CellNode,'date-value',XMLAttr(CellNode,'time-value',XMLAttr(CellNode,'boolean-value')))));
            Rep:=Min(1024,Max(1,StrToIntDef(XMLAttr(CellNode,'number-columns-repeated','1'),1)));
            if Value<>'' then for RR:=0 to RowRep-1 do for CC:=0 to Rep-1 do Table.Put(R+RR,C+CC,Value);
            Inc(C,Rep);
          end; CellNode:=CellNode.NextSibling;
        end; Inc(R,RowRep);
      end; Row:=Row.NextSibling;
    end;
  end;
  procedure ReadGnumeric(Node:TDOMNode);
  var Child,Cells:TDOMNode;
  begin
    if XMLName(Node)='Sheet' then begin
      Table:=NewSheet(XMLContent(XMLChild(Node,'Name'))); Cells:=XMLChild(Node,'Cells'); if Cells=nil then Exit;
      Child:=Cells.FirstChild;
      while Child<>nil do begin
        if XMLName(Child)='Cell' then Table.Put(StrToIntDef(XMLAttr(Child,'Row'),0),StrToIntDef(XMLAttr(Child,'Col'),0),XMLContent(Child));
        Child:=Child.NextSibling;
      end; Exit;
    end;
    Child:=Node.FirstChild; while Child<>nil do begin ReadGnumeric(Child); Child:=Child.NextSibling; end;
  end;
begin
  Clear; OwnsObjects:=True; Ext:=LowerCase(ExtractFileExt(FileName)); Doc:=nil; Relations:=nil; Data:=nil;
  Shared:=TStringList.Create; Lines:=TStringList.Create;
  try
    if Ext='.xlsx' then begin
      Text:=ArchiveText(FileName,'xl/sharedStrings.xml'); if Text<>'' then begin Doc:=ParseXMLText(Text); ReadShared(Doc.DocumentElement); FreeAndNil(Doc); end;
      Doc:=ParseXMLText(ArchiveText(FileName,'xl/workbook.xml')); Relations:=ParseXMLText(ArchiveText(FileName,'xl/_rels/workbook.xml.rels'));
      Node:=XMLChild(Doc.DocumentElement,'sheets'); if Node=nil then raise Exception.Create('Workbook has no sheets');
      Sheet:=Node.FirstChild;
      while Sheet<>nil do begin
        if XMLName(Sheet)='sheet' then begin
          ID:=XMLAttr(Sheet,'r:id'); Entry:=Relations.DocumentElement.FirstChild; Target:='';
          while Entry<>nil do begin if XMLAttr(Entry,'Id')=ID then Target:=XMLAttr(Entry,'Target'); Entry:=Entry.NextSibling; end;
          if Target<>'' then begin
            if Target[1]='/' then System.Delete(Target,1,1) else Target:='xl/'+Target;
            if Pos('..',Target)>0 then raise Exception.Create('Unsupported worksheet path');
            Data:=ParseXMLText(ArchiveText(FileName,Target)); Table:=NewSheet(XMLAttr(Sheet,'name','Sheet'));
            Row:=XMLChild(Data.DocumentElement,'sheetData'); if Row<>nil then Row:=Row.FirstChild;
            while Row<>nil do begin
              CellNode:=Row.FirstChild;
              while CellNode<>nil do begin
                if (XMLName(CellNode)='c') and CellAddress(XMLAttr(CellNode,'r'),R,C) then begin
                  ValueNode:=XMLChild(CellNode,'v'); Value:=XMLContent(ValueNode);
                  if XMLAttr(CellNode,'t')='s' then begin I:=StrToIntDef(Value,-1); if (I>=0) and (I<Shared.Count) then Value:=Shared[I]; end
                  else if XMLAttr(CellNode,'t')='inlineStr' then Value:=XMLContent(XMLChild(CellNode,'is'))
                  else if XMLAttr(CellNode,'t')='b' then begin if Value='1' then Value:='TRUE' else Value:='FALSE'; end;
                  Table.Put(R,C,Value);
                end; CellNode:=CellNode.NextSibling;
              end; Row:=Row.NextSibling;
            end; FreeAndNil(Data);
          end;
        end; Sheet:=Sheet.NextSibling;
      end;
    end else if Ext='.ods' then begin Doc:=ParseXMLText(ArchiveText(FileName,'content.xml')); ReadODS(Doc.DocumentElement); end
    else if (Ext='.gnumeric') or (Ext='.xml') then begin
      if Ext='.gnumeric' then begin
        GZ:=gzopen(FileName,'rb'); if GZ=nil then raise Exception.Create('Cannot open Gnumeric workbook'); Text:='';
        try repeat N:=gzread(GZ,@Buffer[0],SizeOf(Buffer)); if N<0 then raise Exception.Create('Invalid compressed workbook');
          I:=Length(Text); if I+N>32*1024*1024 then raise Exception.Create('Workbook exceeds 32 MB');
          SetLength(Text,I+N); if N>0 then System.Move(Buffer[0],Text[I+1],N); until N=0;
        finally gzclose(GZ); end;
      end else begin Lines.LoadFromFile(FileName); Text:=Lines.Text; end;
      Doc:=ParseXMLText(Text); ReadGnumeric(Doc.DocumentElement);
    end else if (Ext='.csv') or (Ext='.tsv') then begin
      Lines.LoadFromFile(FileName); Text:=Lines.Text; Table:=NewSheet(ChangeFileExt(ExtractFileName(FileName),''));
      R:=0; C:=0; Token:=''; Quoted:=False; P:=1; J:=Ord(','); if Ext='.tsv' then J:=9;
      while P<=Length(Text) do begin
        if Text[P]='"' then begin
          if Quoted and (Copy(Text,P+1,1)='"') then begin Token:=Token+'"'; Inc(P); end else Quoted:=not Quoted;
        end else if not Quoted and ((Ord(Text[P])=J) or (Text[P] in [#10,#13])) then begin
          Table.Put(R,C,Token); Token:=''; Inc(C);
          if Text[P] in [#10,#13] then begin if (Text[P]=#13) and (Copy(Text,P+1,1)=#10) then Inc(P); Inc(R); C:=0; end;
        end else Token:=Token+Text[P]; Inc(P);
      end;
      if Quoted then raise Exception.Create('Unclosed CSV quote'); if Token<>'' then Table.Put(R,C,Token);
    end else raise Exception.Create('Choose XLSX, ODS, Gnumeric, CSV or TSV');
    if Count=0 then raise Exception.Create('No worksheets found');
  finally Data.Free; Relations.Free; Doc.Free; Shared.Free; Lines.Free; end;
end;
end.
