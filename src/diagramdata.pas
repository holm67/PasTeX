unit DiagramData;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, TikZModel;
type
  TDiagramDataSet=record
    Name,Options:string;
    Source,Content,OptionsRange:TDiagramRange;
    HasOptions:Boolean;
  end;
  TDiagramDataSets=array of TDiagramDataSet;
  TDiagramCells=array of string;
  TDiagramFunction=record
    Kind,Name,Expression,Original,Prefix,Signature:string;
  end;
  TDiagramFunctions=class
  public
    Rows:array of TDiagramFunction;
    Suffix:string;
    procedure Load(const Code:string);
    function Source:string;
  end;
  TDiagramTable=class
  private
    FLines:TStringList;
    FOriginal:array of TDiagramCells;
    FLineIndex:array of Integer;
    FSuffix:array of string;
    FSource:string;
    FSeparator:Char;
  public
    Rows:array of TDiagramCells;
    Columns:Integer;
    constructor Create;
    destructor Destroy; override;
    function Load(const Source,Options:string):Boolean;
    function Source:string;
  end;
function DiagramDataSets(const Body:string):TDiagramDataSets;
function ReplaceDiagramData(const Body:string; Index:Integer; const Options,Content:string):string;
function DiagramDataTemplate(const Format:string):string;
implementation
uses SysUtils, Math, TeXMacros, EnvironmentOptions;
function DiagramDataTemplate(const Format:string):string;
begin
  if Format='function' then Result:='var x : interval [0:1] samples 25;'+LineEnding+'func y = \value{x};'+LineEnding
  else if Format='key value pairs' then Result:='x=0, y=0'+LineEnding
  else Result:='x,y'+LineEnding+'0,0'+LineEnding;
end;
function DiagramDataSets(const Body:string):TDiagramDataSets;
var P,A,N,Q:Integer; Options,Name:string; Range,OptionRange,InfoRange:TDiagramRange; HasOptions:Boolean;
begin
  Result:=nil; P:=1;
  while P<=Length(Body) do begin
    SkipTeXSpace(Body,P); if P>Length(Body) then Break;
    A:=P; while (P<=Length(Body)) and (Body[P] in ['a'..'z','A'..'Z']) do Inc(P);
    if Copy(Body,A,P-A)='data' then begin
      HasOptions:=DiagramGroup(Body,P,'[',']',OptionRange); Options:='';
      if HasOptions then Options:=Copy(Body,OptionRange.First+1,OptionRange.Last-OptionRange.First);
      SkipTeXSpace(Body,P);
      if Copy(Body,P,1)='=' then begin Inc(P); SkipTeXSpace(Body,P); end;
      if DiagramGroup(Body,P,'{','}',Range) then begin
        N:=Length(Result); if N>=64 then Exit; SetLength(Result,N+1);
        Name:=EnvironmentOption(Options,'set','');
        if Name='' then Name:='Data '+IntToStr(N+1);
        Result[N].Name:=Name; Result[N].Options:=Options; Result[N].Content:=Range;
        Result[N].Source.First:=A-1; Result[N].Source.Last:=P-1;
        Result[N].HasOptions:=HasOptions; Result[N].OptionsRange:=OptionRange;
        { An info block belongs to the preceding dataset when moving/deleting. }
        repeat
          Q:=P; SkipTeXSpace(Body,Q);
          if (Copy(Body,Q,4)<>'info') or ((Q+4<=Length(Body)) and (Body[Q+4] in ['a'..'z','A'..'Z'])) then Break;
          Inc(Q,4); if Copy(Body,Q,1)=#39 then Inc(Q);
          DiagramGroup(Body,Q,'[',']',InfoRange); SkipTeXSpace(Body,Q);
          if Copy(Body,Q,1)='=' then Inc(Q);
          if not DiagramGroup(Body,Q,'{','}',InfoRange) then Break;
          P:=Q; Result[N].Source.Last:=P-1;
        until False;
      end;
    end else if P=A then begin
      if Copy(Body,P,1)='{' then ReadTeXGroup(Body,P,'{','}')
      else if Copy(Body,P,1)='\' then ReadTeXCommand(Body,P) else Inc(P);
    end;
  end;
end;
function ReplaceDiagramData(const Body:string; Index:Integer; const Options,Content:string):string;
var Sets:TDiagramDataSets; Item:TDiagramDataSet; Range:TDiagramRange;
begin
  Result:=Body; Sets:=DiagramDataSets(Body); if (Index<0) or (Index>=Length(Sets)) then Exit;
  Item:=Sets[Index]; Result:=DiagramReplace(Body,Item.Content,Content);
  if Options=Item.Options then Exit;
  if Item.HasOptions then begin
    Range:=Item.OptionsRange;
    if Trim(Options)='' then begin Dec(Range.First); Inc(Range.Last); end;
    Result:=DiagramReplace(Result,Range,Options);
  end else if Trim(Options)<>'' then begin
    Range.First:=Item.Source.First+4; Range.Last:=Range.First;
    Result:=DiagramReplace(Result,Range,'['+Options+']');
  end;
end;
function FunctionSignature(const Row:TDiagramFunction):string;
begin Result:=Row.Kind+#9+Row.Name+#9+Row.Expression; end;
procedure TDiagramFunctions.Load(const Code:string);
var P,A,Start,Header,Q,Depth,N:Integer; Row:TDiagramFunction; Token:string;
begin
  Rows:=nil; Suffix:=''; P:=1;
  while P<=Length(Code) do begin
    A:=P; SkipTeXSpace(Code,P); if P>Length(Code) then begin Suffix:=Copy(Code,A,MaxInt); Break; end;
    Row:=Default(TDiagramFunction); Start:=P; Header:=P;
    while (P<=Length(Code)) and (Code[P] in ['a'..'z']) do Inc(P);
    Token:=Copy(Code,Header,P-Header); Row.Kind:=Token;
    if (Token='var') or (Token='func') then begin
      SkipTeXSpace(Code,P); Header:=P;
      while (P<=Length(Code)) and not (Code[P] in [':','=',';',#10,#13]) do Inc(P);
      Row.Name:=Trim(Copy(Code,Header,P-Header));
      if (P<=Length(Code)) and (Code[P] in [':','=']) then Inc(P);
    end else begin Row.Kind:='source'; P:=Start; end;
    Header:=P; Depth:=0;
    while P<=Length(Code) do begin
      if Code[P]='%' then begin while (P<=Length(Code)) and not (Code[P] in [#10,#13]) do Inc(P); Continue; end;
      if Code[P]='\' then begin ReadTeXCommand(Code,P); Continue; end;
      if (Depth=0) and (Code[P]=';') then Break;
      if (Depth=0) and (Code[P] in [#10,#13]) then begin
        Q:=P; SkipTeXSpace(Code,Q);
        if (Copy(Code,Q,4)='var ') or (Copy(Code,Q,5)='func ') then Break;
      end;
      case Code[P] of '{','[','(':Inc(Depth); '}',']',')':Dec(Depth); end; Inc(P);
    end;
    Row.Expression:=Trim(Copy(Code,Header,P-Header));
    if Copy(Code,P,1)=';' then Inc(P);
    if Row.Kind='source' then Row.Expression:=Copy(Code,Header,P-Header);
    Row.Prefix:=Copy(Code,A,Start-A); Row.Original:=Copy(Code,Start,P-Start); Row.Signature:=FunctionSignature(Row);
    N:=Length(Rows); if N>=256 then begin Suffix:=Copy(Code,A,MaxInt); Break; end;
    SetLength(Rows,N+1); Rows[N]:=Row;
  end;
end;
function TDiagramFunctions.Source:string;
var Row:TDiagramFunction;
begin
  Result:='';
  for Row in Rows do begin
    Result:=Result+Row.Prefix;
    if FunctionSignature(Row)=Row.Signature then Result:=Result+Row.Original
    else if Row.Kind='var' then Result:=Result+'var '+Row.Name+' : '+Row.Expression+';'
    else if Row.Kind='func' then Result:=Result+'func '+Row.Name+' = '+Row.Expression+';'
    else Result:=Result+Row.Expression;
  end;
  Result:=Result+Suffix;
end;
constructor TDiagramTable.Create;
begin inherited; FLines:=TStringList.Create; end;
destructor TDiagramTable.Destroy;
begin FLines.Free; inherited; end;
function TDiagramTable.Load(const Source,Options:string):Boolean;
var I,J,P,A,Depth,N:Integer; Line,Format,Separator,Value:string; Quote,TooWide:Boolean; C:Char; Cells:TDiagramCells;
  procedure AddCell(Last:Integer);
  begin
    Value:=Trim(Copy(Line,A,Last-A));
    if (Value='') and (FSeparator=' ') then Exit;
    if Length(Cells)>=256 then begin TooWide:=True; Exit; end;
    N:=Length(Cells); SetLength(Cells,N+1); Cells[N]:=Value;
  end;
begin
  Result:=False; Rows:=nil; FOriginal:=nil; FLineIndex:=nil; FSuffix:=nil; Columns:=0; FSource:=Source;
  Format:=EnvironmentOption(Options,'format','table'); if Format<>'table' then Exit;
  Separator:=EnvironmentOption(Options,'separator','');
  FSeparator:=',';
  if Separator='space' then FSeparator:=' '
  else if Length(Separator)=1 then FSeparator:=Separator[1]
  else if Separator<>'' then Exit;
  FLines.Text:=Source;
  for I:=0 to FLines.Count-1 do begin
    Line:=Trim(FLines[I]); if (Line='') or (Line[1]='%') then Continue;
    if (Columns=0) and (Separator='') and (Pos(',',Line)=0) then FSeparator:=' ';
    Cells:=nil; P:=1; A:=1; Depth:=0; Quote:=False; TooWide:=False;
    while P<=Length(Line) do begin
      C:=Line[P];
      if C='\' then begin ReadTeXCommand(Line,P); Continue; end;
      if C='"' then Quote:=not Quote;
      if not Quote then begin
        if C='{' then Inc(Depth) else if C='}' then Dec(Depth);
        if (C='%') and (Depth=0) then Break;
        if (Depth=0) and ((C=FSeparator) or ((FSeparator=' ') and (C=#9))) then begin
          AddCell(P); if TooWide then Exit; A:=P+1;
        end;
      end;
      Inc(P);
    end;
    if (Depth<>0) or Quote then Exit;
    AddCell(P); if TooWide then Exit; if Length(Cells)=0 then Continue;
    J:=Length(Rows); if J>=8192 then Exit;
    SetLength(Rows,J+1); Rows[J]:=Cells; SetLength(FOriginal,J+1); FOriginal[J]:=Copy(Cells);
    SetLength(FLineIndex,J+1); FLineIndex[J]:=I; Columns:=Max(Columns,Length(Cells));
    SetLength(FSuffix,J+1); if Copy(Line,P,1)='%' then FSuffix[J]:=' '+Copy(Line,P,MaxInt);
  end;
  Result:=Columns>0;
end;
function TDiagramTable.Source:string;
var I,J,K:Integer; Same:Boolean; Line:string; Lines:TStringList;
begin
  Same:=Length(Rows)=Length(FOriginal);
  if Same then for I:=0 to High(Rows) do begin
    if Length(Rows[I])<>Length(FOriginal[I]) then begin Same:=False; Break; end;
    for J:=0 to High(Rows[I]) do if Rows[I][J]<>FOriginal[I][J] then begin Same:=False; Break; end;
    if not Same then Break;
  end;
  if Same then Exit(FSource);
  Lines:=TStringList.Create;
  try
    K:=0;
    for I:=0 to High(Rows) do begin
      if I<Length(FLineIndex) then begin
        while K<FLineIndex[I] do begin Lines.Add(FLines[K]); Inc(K); end;
        Inc(K);
      end;
      Same:=(I<Length(FOriginal)) and (Length(Rows[I])=Length(FOriginal[I]));
      if Same then for J:=0 to High(Rows[I]) do if Rows[I][J]<>FOriginal[I][J] then begin Same:=False; Break; end;
      if Same then Lines.Add(FLines[FLineIndex[I]])
      else begin
        Line:='';
        for J:=0 to High(Rows[I]) do begin if J>0 then Line:=Line+FSeparator; Line:=Line+Rows[I][J]; end;
        if I<Length(FSuffix) then Line:=Line+FSuffix[I];
        Lines.Add(Line);
      end;
    end;
    { Keep comments/trailing whitespace; removed data rows are not copied. }
    while K<FLines.Count do begin
      Line:=Trim(FLines[K]); if (Line='') or (Copy(Line,1,1)='%') then Lines.Add(FLines[K]); Inc(K);
    end;
    Result:=Lines.Text;
  finally Lines.Free; end;
end;
end.
