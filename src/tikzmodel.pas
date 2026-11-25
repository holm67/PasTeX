unit TikZModel;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils;
type
  TDiagramRange=record First,Last:Integer; end;
  TDiagramEnvironment=record
    Name:string;
    Source,Options,Body:TDiagramRange;
    Parent:Integer;
    HasOptions:Boolean;
  end;
  TDiagramCommand=record
    Name,Modifier:string;
    Source,Options,Body:TDiagramRange;
    Environment:Integer;
    HasOptions:Boolean;
  end;
  TDiagramEnvironments=array of TDiagramEnvironment;
  TDiagramCommands=array of TDiagramCommand;
  TDiagramOption=record Name,Value,Original:string; HasValue:Boolean; Source,ValueRange:TDiagramRange; end;
  TDiagramOptions=array of TDiagramOption;
  TDiagramModel=class
  public
    Source:string;
    Environments:TDiagramEnvironments;
    Commands:TDiagramCommands;
    procedure Load(const Code:string);
    function Text(const Range:TDiagramRange):string;
    function AxisAt(Offset:Integer):Integer;
    function SetEnvironmentOptions(Index:Integer; const Options:string):string;
    function InsertAxis(const Name,Options:string; Parent:Integer=-1):string;
    function DeleteEnvironment(Index:Integer):string;
    function CommandSibling(Index,Direction:Integer):Integer;
    function MoveCommand(Index,Direction:Integer):string;
  end;
function DiagramGroup(const Source:string; var Position:Integer; Open,Close:Char; out Range:TDiagramRange):Boolean;
function DiagramReplace(const Source:string; const Range:TDiagramRange; const Value:string):string;
function DiagramSwap(const Source:string; First,Second:TDiagramRange):string;
function DiagramOptions(const Source:string; Base:Integer=0):TDiagramOptions;
function DiagramOptionSource(const Options:TDiagramOptions):string;
function DiagramSetOption(const Source,Name,Value:string):string;
function DiagramIsAxis(const Name:string):Boolean;
implementation
uses StrUtils, TeXMacros;
function DiagramReplace(const Source:string; const Range:TDiagramRange; const Value:string):string;
begin Result:=Copy(Source,1,Range.First)+Value+Copy(Source,Range.Last+1,MaxInt); end;
function DiagramSwap(const Source:string; First,Second:TDiagramRange):string;
var Temp:TDiagramRange;
begin
  Result:=Source;
  if First.First>Second.First then begin Temp:=First; First:=Second; Second:=Temp; end;
  if (First.First<0) or (First.Last<First.First) or (Second.First<First.Last) or
    (Second.Last<Second.First) or (Second.Last>Length(Source)) then Exit;
  Result:=Copy(Source,1,First.First)+Copy(Source,Second.First+1,Second.Last-Second.First)+
    Copy(Source,First.Last+1,Second.First-First.Last)+Copy(Source,First.First+1,First.Last-First.First)+
    Copy(Source,Second.Last+1,MaxInt);
end;
function DiagramGroup(const Source:string; var Position:Integer; Open,Close:Char; out Range:TDiagramRange):Boolean;
var Start:Integer;
begin
  SkipTeXSpace(Source,Position); Start:=Position;
  Range.First:=Start-1; Range.Last:=Range.First; Result:=Copy(Source,Start,1)=Open;
  if not Result then Exit;
  ReadTeXGroup(Source,Position,Open,Close); Range.First:=Start; Range.Last:=Position-1;
  if Copy(Source,Position-1,1)=Close then Dec(Range.Last);
end;
function DiagramIsAxis(const Name:string):Boolean;
begin Result:=(Name='axis') or (Name='semilogxaxis') or (Name='semilogyaxis') or (Name='loglogaxis') or (Name='polaraxis'); end;
function DiagramOptions(const Source:string; Base:Integer):TDiagramOptions;
var P,A,Depth,Brackets,Equal,I,First,Last:Integer; Item:TDiagramOption;
begin
  Result:=nil; P:=1; A:=1; Depth:=0; Brackets:=0; Equal:=0;
  while P<=Length(Source)+1 do begin
    if P<=Length(Source) then begin
      if Source[P]='\' then begin ReadTeXCommand(Source,P); Continue; end;
      if Source[P]='%' then begin while (P<=Length(Source)) and not (Source[P] in [#10,#13]) do Inc(P); Continue; end;
      if (Source[P]='=') and (Depth=0) and (Brackets=0) and (Equal=0) then Equal:=P;
      case Source[P] of '{':Inc(Depth); '}':Dec(Depth); '[':Inc(Brackets); ']':Dec(Brackets); end;
    end;
    if (P>Length(Source)) or ((Source[P]=',') and (Depth=0) and (Brackets=0)) then begin
      First:=A; Last:=P-1;
      while (First<=Last) and (Source[First] in [' ',#9,#10,#13]) do Inc(First);
      while (Last>=First) and (Source[Last] in [' ',#9,#10,#13]) do Dec(Last);
      if First<=Last then begin
        Item:=Default(TDiagramOption); Item.Original:=Copy(Source,A,P-A); Item.Source.First:=Base+A-1; Item.Source.Last:=Base+P-1;
        Item.HasValue:=Equal>0;
        if Equal=0 then Item.Name:=Copy(Source,First,Last-First+1)
        else begin
          Item.Name:=Trim(Copy(Source,First,Equal-First)); Item.Value:=Trim(Copy(Source,Equal+1,Last-Equal));
          First:=Equal+1; while (First<=Last) and (Source[First] in [' ',#9,#10,#13]) do Inc(First);
          if (First<Last) and (Source[First]='{') and (Source[Last]='}') then begin Inc(First); Dec(Last); end;
          Item.ValueRange.First:=Base+First-1; Item.ValueRange.Last:=Base+Last;
        end;
        I:=Length(Result); SetLength(Result,I+1); Result[I]:=Item;
      end;
      A:=P+1; Equal:=0;
    end;
    Inc(P);
  end;
end;
function DiagramOptionSource(const Options:TDiagramOptions):string;
var I:Integer;
begin
  Result:='';
  for I:=0 to High(Options) do if Trim(Options[I].Name)<>'' then begin
    if Result<>'' then Result:=Result+',';
    Result:=Result+Trim(Options[I].Name);
    if Options[I].HasValue then Result:=Result+'='+Options[I].Value;
  end;
end;
function DiagramSetOption(const Source,Name,Value:string):string;
var Options:TDiagramOptions; I,N:Integer;
begin
  Options:=DiagramOptions(Source); N:=-1;
  for I:=0 to High(Options) do if Options[I].Name=Name then begin N:=I; Break; end;
  if N<0 then begin N:=Length(Options); SetLength(Options,N+1); Options[N].Name:=Name; end;
  Options[N].Value:=Value; Options[N].HasValue:=True; Result:=DiagramOptionSource(Options);
end;
procedure TDiagramModel.Load(const Code:string);
const Editable:array[0..10] of string=('draw','fill','filldraw','path','node','addplot','datavisualization','graph','addlegendentry','coordinate','pic');
var P,A,Q,Depth,Bracket,Current,I:Integer; Name,Env:string; Range:TDiagramRange;
    Environment:TDiagramEnvironment; Command:TDiagramCommand;
begin
  Source:=Code; Environments:=nil; Commands:=nil; P:=1; Current:=-1;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and not (Source[P] in [#10,#13]) do Inc(P); Continue; end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) then begin P:=Q; Continue; end;
    A:=P-1; Name:=ReadTeXCommand(Source,P);
    if Name='begin' then begin
      Env:=ReadTeXGroup(Source,P,'{','}'); if Env='' then Continue;
      Environment:=Default(TDiagramEnvironment); Environment.Name:=Env; Environment.Source.First:=A;
      Environment.Parent:=Current; Q:=P;
      Environment.HasOptions:=DiagramGroup(Source,Q,'[',']',Range);
      if Environment.HasOptions then begin Environment.Options:=Range; P:=Q; end
      else begin Environment.Options.First:=P-1; Environment.Options.Last:=P-1; end;
      Environment.Body.First:=P-1; Environment.Body.Last:=Length(Source); Environment.Source.Last:=Length(Source);
      I:=Length(Environments); SetLength(Environments,I+1); Environments[I]:=Environment; Current:=I; Continue;
    end;
    if Name='end' then begin
      Env:=ReadTeXGroup(Source,P,'{','}'); I:=Current;
      while (I>=0) and (Environments[I].Name<>Env) do I:=Environments[I].Parent;
      if I>=0 then begin Environments[I].Body.Last:=A; Environments[I].Source.Last:=P-1; Current:=Environments[I].Parent; end;
      Continue;
    end;
    if IndexStr(Name,Editable)<0 then Continue;
    Command:=Default(TDiagramCommand); Command.Name:=Name; Command.Source.First:=A; Command.Environment:=Current;
    if (Name='addplot') and (Copy(Source,P,1)='3') then begin Command.Name:='addplot3'; Inc(P); end;
    if Copy(Source,P,1)='+' then begin Command.Modifier:='+'; Inc(P); end;
    Q:=P; Command.HasOptions:=DiagramGroup(Source,Q,'[',']',Range);
    if Command.HasOptions then begin Command.Options:=Range; P:=Q; end
    else begin Command.Options.First:=P-1; Command.Options.Last:=P-1; end;
    SkipTeXSpace(Source,P); Command.Body.First:=P-1;
    if Name='graph' then begin
      DiagramGroup(Source,P,'{','}',Range); Command.Body.Last:=P-1;
      Q:=P; SkipTeXSpace(Source,Q); if Copy(Source,Q,1)=';' then P:=Q+1;
    end else if Name='addlegendentry' then begin
      if DiagramGroup(Source,P,'{','}',Range) then Command.Body:=Range;
    end else begin
      Depth:=0; Bracket:=0;
      while P<=Length(Source) do begin
        if Source[P]='%' then begin while (P<=Length(Source)) and not (Source[P] in [#10,#13]) do Inc(P); Continue; end;
        if Source[P]='\' then begin ReadTeXCommand(Source,P); Continue; end;
        case Source[P] of '{':Inc(Depth); '}':Dec(Depth); '[':Inc(Bracket); ']':Dec(Bracket); end;
        if (Source[P]=';') and (Depth=0) and (Bracket=0) then Break;
        Inc(P);
      end;
      Command.Body.Last:=P-1; if P<=Length(Source) then Inc(P);
    end;
    Command.Source.Last:=P-1; I:=Length(Commands); SetLength(Commands,I+1); Commands[I]:=Command;
  end;
end;
function TDiagramModel.Text(const Range:TDiagramRange):string;
begin Result:=Copy(Source,Range.First+1,Range.Last-Range.First); end;
function TDiagramModel.CommandSibling(Index,Direction:Integer):Integer;
var Step:Integer;
begin
  Result:=-1; if (Index<0) or (Index>=Length(Commands)) or (Direction=0) then Exit;
  Step:=1; if Direction<0 then Step:=-1;
  Result:=Index+Step;
  while (Result>=0) and (Result<Length(Commands)) do begin
    if Commands[Result].Environment=Commands[Index].Environment then Exit; Inc(Result,Step);
  end;
  Result:=-1;
end;
function TDiagramModel.MoveCommand(Index,Direction:Integer):string;
var Other:Integer;
begin
  Result:=Source; Other:=CommandSibling(Index,Direction);
  if Other>=0 then Result:=DiagramSwap(Source,Commands[Index].Source,Commands[Other].Source);
end;
function TDiagramModel.AxisAt(Offset:Integer):Integer;
var I:Integer;
begin
  Result:=-1;
  for I:=0 to High(Environments) do if DiagramIsAxis(Environments[I].Name) and
    (Offset>=Environments[I].Source.First) and (Offset<=Environments[I].Source.Last) then Result:=I;
end;
function TDiagramModel.SetEnvironmentOptions(Index:Integer; const Options:string):string;
var Range:TDiagramRange; Value:string;
begin
  Result:=Source; if (Index<0) or (Index>High(Environments)) then Exit;
  Range:=Environments[Index].Options; Value:=Options;
  if not Environments[Index].HasOptions and (Value<>'') then Value:='['+Value+']';
  Result:=DiagramReplace(Source,Range,Value);
end;
function TDiagramModel.InsertAxis(const Name,Options:string; Parent:Integer):string;
var I:Integer; Range:TDiagramRange; Value:string;
begin
  Result:=Source; if not DiagramIsAxis(Name) then Exit;
  if Parent<0 then for I:=0 to High(Environments) do if (Environments[I].Name='tikzpicture') or
    (Environments[I].Name='circuitikz') then begin Parent:=I; Break; end;
  if (Parent<0) or (Parent>High(Environments)) then Exit;
  Range.First:=Environments[Parent].Body.Last; Range.Last:=Range.First;
  Value:='\begin{'+Name+'}'; if Options<>'' then Value:=Value+'['+Options+']';
  Result:=DiagramReplace(Source,Range,Value+LineEnding+'\end{'+Name+'}'+LineEnding);
end;
function TDiagramModel.DeleteEnvironment(Index:Integer):string;
begin
  Result:=Source;
  if (Index<0) or (Index>High(Environments)) or (Environments[Index].Name='tikzpicture') or
    (Environments[Index].Name='circuitikz') then Exit;
  Result:=DiagramReplace(Source,Environments[Index].Source,'');
end;
end.
