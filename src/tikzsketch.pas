unit TikZSketch;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type
  TDiagramHandle=record
    X,Y,SourceX,SourceY,Scale:Double;
    Command,Row:Integer;
  end;
  TDiagramHandles=array of TDiagramHandle;
  TDiagramSegment=record First,Last:Integer; end;
  TDiagramSegments=array of TDiagramSegment;
function DiagramNumber(Value:Double):string;
function MoveDiagramPoint(const Source:string; Command,Row:Integer; X,Y:Double):string;
function TranslateDiagramSegment(const Source:string; const Handles:TDiagramHandles; First,Last:Integer; DX,DY:Double):string;
function DeleteDiagramPoint(const Source:string; Command,Row:Integer; Whole:Boolean=False):string;
function InsertSketchObject(const Source,Kind,Options,Text:string; X1,Y1,X2,Y2:Double):string;
function InsertSketchPath(const Source,Options:string; const Points:TDiagramHandles; Closed:Boolean=False):string;
implementation
uses SysUtils, Math, StrUtils, TikZModel, TikZPath;
function DiagramNumber(Value:Double):string;
var Settings:TFormatSettings;
begin
  Settings:=DefaultFormatSettings; Settings.DecimalSeparator:='.';
  if Abs(Value)<0.00005 then Value:=0; Result:=FloatToStrF(Value,ffFixed,16,4,Settings);
  while (Pos('.',Result)>0) and (RightStr(Result,1)='0') do Delete(Result,Length(Result),1);
  if RightStr(Result,1)='.' then Delete(Result,Length(Result),1);
end;
function Pair(X,Y:Double):string;
begin Result:=DiagramNumber(X)+','+DiagramNumber(Y); end;
function MoveDiagramPoint(const Source:string; Command,Row:Integer; X,Y:Double):string;
var Model:TDiagramModel; Entry:TDiagramCommand; Rows:TDiagramPathRows; Fields,Keep:TDiagramOptions; I,N,P:Integer; Prefix:string;
begin
  Result:=Source; Model:=TDiagramModel.Create;
  try
    Model.Load(Source); if (Command<0) or (Command>=Length(Model.Commands)) then Exit; Entry:=Model.Commands[Command];
    Rows:=ParseDiagramPath(Model.Text(Entry.Body),Entry.Name='node'); if (Row<0) or (Row>=Length(Rows)) then Exit;
    Prefix:=Trim(Rows[Row].Coordinate); P:=1; while Copy(Prefix,P,1)='+' do Inc(P);
    if P>1 then Rows[Row].Coordinate:=Copy(Prefix,1,P-1)+'('+Pair(X,Y)+')' else Rows[Row].Coordinate:=Pair(X,Y);
    Result:=DiagramReplace(Source,Entry.Body,DiagramPathSource(Rows,Entry.Name='node'));
    if Entry.Name='node' then begin
      Fields:=DiagramOptions(Model.Text(Entry.Options)); Keep:=nil;
      for I:=0 to High(Fields) do begin
        if (Pos('of ',Fields[I].Value)>0) and
          ((Pos('left',Fields[I].Name)>0) or (Pos('right',Fields[I].Name)>0) or (Pos('above',Fields[I].Name)>0) or (Pos('below',Fields[I].Name)>0)) then Continue;
        N:=Length(Keep); SetLength(Keep,N+1); Keep[N]:=Fields[I];
      end;
      if Entry.HasOptions then Result:=DiagramReplace(Result,Entry.Options,DiagramOptionSource(Keep));
    end;
  finally Model.Free; end;
end;
function TranslateDiagramSegment(const Source:string; const Handles:TDiagramHandles; First,Last:Integer; DX,DY:Double):string;
var Model:TDiagramModel; Entry:TDiagramCommand; Rows:TDiagramPathRows; I,J,Command:Integer; RowHandles:array of Integer;
    X,Y,BaseX,BaseY,ShiftX,ShiftY:Double; Prefix:string;
begin
  Result:=Source;
  if (First<0) or (Last<0) or (First>=Length(Handles)) or (Last>=Length(Handles)) then Exit;
  Command:=Handles[First].Command; if Handles[Last].Command<>Command then Exit;
  Model:=TDiagramModel.Create;
  try
    Model.Load(Source); if (Command<0) or (Command>=Length(Model.Commands)) then Exit;
    Entry:=Model.Commands[Command]; Rows:=ParseDiagramPath(Model.Text(Entry.Body)); BaseX:=0; BaseY:=0;
    SetLength(RowHandles,Length(Rows)); for I:=0 to High(RowHandles) do RowHandles[I]:=-1;
    for J:=0 to High(Handles) do if (Handles[J].Command=Command) and (Handles[J].Row>=0) and (Handles[J].Row<Length(Rows)) then RowHandles[Handles[J].Row]:=J;
    for I:=0 to High(Rows) do begin
        J:=RowHandles[I]; if (J<0) or (Handles[J].Scale<=0) then Continue;
        ShiftX:=0; ShiftY:=0;
        if (J=First) or (J=Last) then begin ShiftX:=DX/Handles[J].Scale; ShiftY:=DY/Handles[J].Scale; end;
        X:=Handles[J].SourceX+ShiftX; Y:=Handles[J].SourceY+ShiftY; Prefix:=Trim(Rows[I].Coordinate);
        if Copy(Prefix,1,1)='+' then begin X:=X-BaseX; Y:=Y-BaseY; end;
        if (Abs(X-Handles[J].SourceX)>1e-9) or (Abs(Y-Handles[J].SourceY)>1e-9) then begin
          if Copy(Prefix,1,2)='++' then Rows[I].Coordinate:='++('+Pair(X,Y)+')'
          else if Copy(Prefix,1,1)='+' then Rows[I].Coordinate:='+('+Pair(X,Y)+')'
          else Rows[I].Coordinate:=Pair(X,Y);
        end;
        { A relative endpoint depends on the most recent absolute/++ point.
          Compensate adjacent points so dragging one edge leaves them in place. }
        if (Rows[I].Operation<>'node') and ((Copy(Prefix,1,1)<>'+') or (Copy(Prefix,1,2)='++')) then begin BaseX:=ShiftX; BaseY:=ShiftY; end;
    end;
    Result:=DiagramReplace(Source,Entry.Body,DiagramPathSource(Rows));
  finally Model.Free; end;
end;
function DeleteDiagramPoint(const Source:string; Command,Row:Integer; Whole:Boolean):string;
var Model:TDiagramModel; Entry:TDiagramCommand; Rows:TDiagramPathRows; I:Integer;
begin
  Result:=Source; Model:=TDiagramModel.Create;
  try
    Model.Load(Source); if (Command<0) or (Command>=Length(Model.Commands)) then Exit; Entry:=Model.Commands[Command];
    if Whole or (Entry.Name='node') or (Entry.Name='coordinate') then Exit(DiagramReplace(Source,Entry.Source,''));
    Rows:=ParseDiagramPath(Model.Text(Entry.Body)); if (Row<0) or (Row>=Length(Rows)) then Exit;
    for I:=Row to High(Rows)-1 do Rows[I]:=Rows[I+1]; SetLength(Rows,Length(Rows)-1);
    if Length(Rows)=0 then Exit(DiagramReplace(Source,Entry.Source,''));
    if Rows[0].Operation='line' then Rows[0].Operation:='move';
    Result:=DiagramReplace(Source,Entry.Body,DiagramPathSource(Rows));
  finally Model.Free; end;
end;
function InsertDrawing(const Source,Code:string):string;
var Model:TDiagramModel; I,Offset:Integer; Range:TDiagramRange;
begin
  Result:=Source; Model:=TDiagramModel.Create;
  try
    Model.Load(Source); Offset:=-1;
    for I:=0 to High(Model.Environments) do if (Model.Environments[I].Name='tikzpicture') or
      (Model.Environments[I].Name='circuitikz') then begin Offset:=Model.Environments[I].Body.Last; Break; end;
    if Offset<0 then Exit;
    Range.First:=Offset; Range.Last:=Offset; Result:=DiagramReplace(Source,Range,Code+LineEnding);
  finally Model.Free; end;
end;
function InsertSketchObject(const Source,Kind,Options,Text:string; X1,Y1,X2,Y2:Double):string;
var Code,Style:string;
begin
  Style:=''; if Options<>'' then Style:='['+Options+']';
  if (Kind='node') or (Kind='label') then Code:='\node'+Style+' at ('+Pair(X1,Y1)+') {'+Text+'};'
  else if Kind='point' then Code:='\fill'+Style+' ('+Pair(X1,Y1)+') circle (1.5pt);'
  else if Kind='rectangle' then Code:='\draw'+Style+' ('+Pair(X1,Y1)+') rectangle ('+Pair(X2,Y2)+');'
  else if Kind='circle' then Code:='\draw'+Style+' ('+Pair(X1,Y1)+') circle ('+DiagramNumber(Hypot(X2-X1,Y2-Y1))+'cm);'
  else begin
    if Kind='arrow' then begin if Options<>'' then Style:='[->,'+Options+']' else Style:='[->]'; end;
    Code:='\draw'+Style+' ('+Pair(X1,Y1)+') -- ('+Pair(X2,Y2)+');';
  end;
  Result:=InsertDrawing(Source,Code);
end;
function InsertSketchPath(const Source,Options:string; const Points:TDiagramHandles; Closed:Boolean):string;
var Code:string; I:Integer;
begin
  Result:=Source; if Length(Points)<2 then Exit; Code:='\draw'; if Options<>'' then Code:=Code+'['+Options+']';
  for I:=0 to High(Points) do begin
    if I>0 then Code:=Code+' --'; Code:=Code+' ('+Pair(Points[I].SourceX,Points[I].SourceY)+')';
  end;
  if Closed then Code:=Code+' -- cycle'; Result:=InsertDrawing(Source,Code+';');
end;
end.
