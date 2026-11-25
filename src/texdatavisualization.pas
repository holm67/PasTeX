unit TeXDataVisualization;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Contnrs, PlotGeometry;
type
  TDataVisualSet=class
  private
    FCount:Integer;
  public
    Name,Kind,Style,Legend:string;
    Points:array of TPlotPoint;
    procedure Add(const Point:TPlotPoint);
  end;
  TDataVisualization=class
  private
    FDefault:string;
    function FindSet(const Name:string):TDataVisualSet;
    procedure ReadOptions(const Code:string);
    function Data(const Code:string; Settings:TStrings):Boolean;
    function Functions(const Code:string; Settings:TStrings):Boolean;
  public
    Options,InputFiles:TStringList;
    Sets:TObjectList;
    ErrorText:string;
    constructor Create;
    destructor Destroy; override;
    procedure AxisOptions(const Axis:string; Dest:TStrings);
    function AxisAttribute(const Axis:string):string;
    function Load(const Source,Directory:string; var P:Integer; const Defaults:string=''):Boolean;
  end;
implementation
uses SysUtils, Math, FPExprPars, TeXMacros, TikZModel, PlotMath, TikZCalc, DiagramData;
function Ungroup(const Value:string):string;
var P:Integer;
begin
  Result:=Trim(Value);
  if Copy(Result,1,1)='{' then begin P:=1; Result:=ReadTeXGroup(Result,P,'{','}'); end;
end;
procedure SettingsFrom(const Code:string; Values:TStrings);
var Entry:TDiagramOption;
begin
  for Entry in DiagramOptions(Ungroup(Code)) do
    if Entry.HasValue then Values.Values[Entry.Name]:=Ungroup(Entry.Value)
    else Values.Values[Entry.Name]:='true';
end;
function DataNumber(const Value:string; out N:Double):Boolean;
var Format:TFormatSettings;
begin
  Format:=DefaultFormatSettings; Format.DecimalSeparator:='.';
  Result:=TryStrToFloat(Trim(Value),N,Format);
  Result:=Result and not IsNan(N) and not IsInfinite(N) and (Abs(N)<1e100);
end;
procedure TDataVisualSet.Add(const Point:TPlotPoint);
var N:Integer;
begin
  N:=FCount; if N>=8192 then raise Exception.Create('Data visualization exceeds 8192 points per set');
  if N=Length(Points) then SetLength(Points,Min(8192,Max(32,N*2)));
  Points[N]:=Point; Inc(FCount);
end;
constructor TDataVisualization.Create;
begin
  inherited Create; Options:=TStringList.Create; Options.CaseSensitive:=True;
  InputFiles:=TStringList.Create; Sets:=TObjectList.Create(True);
end;
destructor TDataVisualization.Destroy;
begin Sets.Free; InputFiles.Free; Options.Free; inherited Destroy; end;
function TDataVisualization.FindSet(const Name:string):TDataVisualSet;
var I:Integer; Key:string;
begin
  Key:=Ungroup(Name); if Key='' then Key:=FDefault;
  for I:=0 to Sets.Count-1 do begin Result:=TDataVisualSet(Sets[I]); if Result.Name=Key then Exit; end;
  if Sets.Count>=64 then raise Exception.Create('Data visualization exceeds 64 sets');
  Result:=TDataVisualSet.Create; Result.Name:=Key; Result.Kind:='line'; Sets.Add(Result);
end;
procedure TDataVisualization.AxisOptions(const Axis:string; Dest:TStrings);
var I:Integer; Prefix,Name:string;
begin
  Dest.Clear; Prefix:=Axis+' axis/';
  for I:=0 to Options.Count-1 do begin
    Name:=Options.Names[I];
    if Copy(Name,1,Length(Prefix))=Prefix then
      Dest.Values[Copy(Name,Length(Prefix)+1,MaxInt)]:=Options.ValueFromIndex[I];
  end;
end;
function TDataVisualization.AxisAttribute(const Axis:string):string;
begin
  Result:=Options.Values[Axis+' axis/attribute']; if Result='' then Result:=Axis;
  if Copy(Result,1,12)='/data point/' then Delete(Result,1,12);
end;
procedure TDataVisualization.ReadOptions(const Code:string);
  procedure AxisOption(const Axis,Key,Value:string; HasValue:Boolean);
  var Name,Text,Child:string; P:Integer;
  begin
    if Key='ticks and grid' then begin
      AxisOption(Axis,'ticks',Value,HasValue); AxisOption(Axis,'grid',Value,HasValue); Exit;
    end;
    P:=Pos('/',Key); Name:=Key; Text:=Value;
    if P>0 then begin
      Name:=Copy(Key,1,P-1); Child:=Copy(Key,P+1,MaxInt);
      if not ((Name='grid') or (Name='ticks')) then Exit;
      Text:=Child; if HasValue then Text:=Text+'={'+Value+'}'; HasValue:=True;
    end;
    if not HasValue then begin
      if Name='grid' then Text:='at default ticks'
      else if Name='ticks' then Text:='some' else Text:='true';
    end;
    { PGF appends tick/grid actions and survey values in source order. }
    Child:=Axis+' axis/'+Name;
    if ((Name='grid') or (Name='ticks') or (Name='include value')) and
      (Options.Values[Child]<>'') then Text:=Options.Values[Child]+','+Text;
    Options.Values[Child]:=Text;
  end;
  procedure Read(const Input,Prefix:string; Depth:Integer);
  var Entry,Part:TDiagramOption; Name,Kind,Names,Value,Scope,Axis,Key:string; Item:TDataVisualSet; P:Integer;
  begin
    if Depth>8 then Exit; Scope:=Prefix;
    for Entry in DiagramOptions(Input) do begin
      Name:=Scope+Entry.Name; Value:=Ungroup(Entry.Value);
      if Copy(Entry.Name,1,1)='/' then Name:=Entry.Name;
      if Copy(Name,1,25)='/tikz/data visualization/' then Delete(Name,1,25);
      if Name='.cd' then begin Scope:=''; Continue; end;
      if Copy(Name,Length(Name)-3,4)='/.cd' then begin Scope:=Copy(Name,1,Length(Name)-3); Continue; end;
      if (Name='x axis') or (Name='y axis') or (Name='all axes') then begin
        Read(Value,Name+'/',Depth+1); Continue;
      end;
      P:=Pos('/',Name); Axis:=Copy(Name,1,P-1); Key:=Copy(Name,P+1,MaxInt);
      if (Axis='x axis') or (Axis='y axis') or (Axis='all axes') then begin
        if Axis<>'y axis' then AxisOption('x',Key,Value,Entry.HasValue);
        if Axis<>'x axis' then AxisOption('y',Key,Value,Entry.HasValue);
        Continue;
      end;
      if (Name='grid') or (Name='ticks') or (Name='ticks and grid') then begin
        AxisOption('x',Name,Value,Entry.HasValue); AxisOption('y',Name,Value,Entry.HasValue); Continue;
      end;
      if Copy(Name,1,13)='visualize as ' then begin
        Kind:=Copy(Name,14,MaxInt); Names:=Value;
        if (Kind<>'line') and (Kind<>'scatter') and (Kind<>'smooth line') and
          (Kind<>'smooth cycle') then raise Exception.Create('Unsupported visualizer: '+Kind);
        if Names='' then begin Names:='line'; if Kind='scatter' then Names:='scatter'; end;
        for Part in DiagramOptions(Names) do begin
          Item:=FindSet(Part.Name); Item.Kind:=Kind; FDefault:=Item.Name;
        end;
      end else if Entry.HasValue then Options.Values[Name]:=Value else Options.Values[Name]:='true';
    end;
  end;
begin
  Read(Code,'',0);
end;
function TDataVisualization.Data(const Code:string; Settings:TStrings):Boolean;
var Lines,Attrs:TStringList; Row,I,CX,CY,CS,Index,Count:Integer;
    Line,Name,Format,Separator,Text,XName,YName:string; Value:TPlotPoint; Item:TDataVisualSet; Table:TDiagramTable;
  function Cell(N:Integer):string;
  begin
    Result:=''; if (N>=0) and (N<Length(Table.Rows[Row])) then Result:=Ungroup(Table.Rows[Row][N]);
    if (Length(Result)>1) and (Result[1]='"') and (Result[Length(Result)]='"') then Result:=Copy(Result,2,Length(Result)-2);
  end;
  function Coordinate(const Text:string; out N:Double):Boolean;
  var Parser:TFPExpressionParser;
  begin
    Result:=DataNumber(Text,N); if Result or (Copy(Trim(Text),1,1)<>'(') then Exit;
    Parser:=TFPExpressionParser.Create(nil);
    try
      ConfigurePlotMath(Parser); Parser.Expression:=PlotMathExpression(Text); N:=Parser.AsFloat;
      Result:=not IsNan(N) and not IsInfinite(N);
    finally Parser.Free; end;
  end;
begin
  Result:=False; Format:=Settings.Values['format'];
  if Format='function' then Exit(Functions(Code,Settings));
  if (Format<>'') and (Format<>'table') and (Format<>'named') then begin
    ErrorText:='Unsupported data format: '+Format; Exit;
  end;
  Lines:=TStringList.Create; Attrs:=TStringList.Create; Table:=TDiagramTable.Create;
  try
    CX:=-1; CY:=-1; CS:=-1; XName:=AxisAttribute('x'); YName:=AxisAttribute('y');
    Name:=Settings.Values['set']; if Name='' then Name:=Settings.Values['/data point/set'];
    Separator:=Settings.Values['separator'];
    if Format<>'named' then begin
      Text:=''; if Separator<>'' then Text:='separator={'+Separator+'}';
      if not Table.Load(StringReplace(Code,'\\',LineEnding,[rfReplaceAll]),Text) then begin ErrorText:='Invalid data table'; Exit; end;
      Count:=Length(Table.Rows);
    end else begin Lines.Text:=StringReplace(Code,'\\',LineEnding,[rfReplaceAll]); Count:=Lines.Count; end;
    for Row:=0 to Count-1 do begin
      Value:=Default(TPlotPoint);
      if Format='named' then begin
        Line:=Trim(Lines[Row]); Index:=Pos('%',Line); if Index>0 then Line:=Trim(Copy(Line,1,Index-1));
        if Line='' then Continue;
        Attrs.Assign(Settings); SettingsFrom(Line,Attrs);
        if not Coordinate(Attrs.Values[XName],Value.X) or not Coordinate(Attrs.Values[YName],Value.Y) then Exit(False);
        Item:=FindSet(Attrs.Values['set']); Item.Add(Value); Result:=True; Continue;
      end;
      if Length(Table.Rows[Row])<2 then begin ErrorText:='A data row needs x and y'; Exit(False); end;
      if CX<0 then begin
        CX:=0; CY:=1;
        if not Coordinate(Cell(0),Value.X) then begin
          CX:=-1; CY:=-1;
          for I:=0 to High(Table.Rows[Row]) do begin
            if Cell(I)=XName then CX:=I; if Cell(I)=YName then CY:=I; if Cell(I)='set' then CS:=I;
          end;
          if (CX<0) or (CY<0) then begin ErrorText:='Missing data columns: '+XName+', '+YName; Exit(False); end;
          Continue;
        end;
      end;
      if not Coordinate(Cell(CX),Value.X) or not Coordinate(Cell(CY),Value.Y) then begin
        ErrorText:='Invalid data row '+IntToStr(Row+1); Exit(False);
      end;
      if CS>=0 then Item:=FindSet(Cell(CS)) else Item:=FindSet(Name);
      Item.Add(Value); Result:=True;
    end;
  finally Table.Free; Attrs.Free; Lines.Free; end;
end;
function TDataVisualization.Functions(const Code:string; Settings:TStrings):Boolean;
type
  TStatement=record
    Attribute:Integer;
    Values:array of string;
    Parser:TFPExpressionParser;
    Identifiers:array of TFPExprIdentifierDef;
    Expression:string;
  end;
var Statements,Names,Values:TStringList; ProgramCode:array of TStatement; Calc:TTikZCalc;
    Statement,Name,Expression,Range,Token,Input,Variables,FunctionCode:string; I,J,P,Q,N,Index,X,Y,SetIndex,Points:Integer;
    Lower,Upper,Step,Number,SampleCount:Double; Point:TPlotPoint; Format:TFormatSettings; Depth,Last:Integer;
  function Attribute(const Name:string):Integer;
  begin
    Result:=Names.IndexOf(Name); if Result>=0 then Exit;
    if (Name='') or (Names.Count>=64) then raise Exception.Create('Invalid function attribute: '+Name);
    Result:=Names.Add(Name); Values.Add('0');
  end;
  function ReplaceValues(const Source:string):string;
  var P,A,Index:Integer; Name:string;
  begin
    Result:=''; P:=1;
    while P<=Length(Source) do begin
      if Copy(Source,P,6)='\value' then begin
        Inc(P,6); SkipTeXSpace(Source,P);
        if Copy(Source,P,1)='{' then Name:=ReadTeXGroup(Source,P,'{','}')
        else begin A:=P; if P<=Length(Source) then Inc(P); Name:=Copy(Source,A,P-A); end;
        Index:=Names.IndexOf(Name); if Index<0 then raise Exception.Create('Unknown function attribute: '+Name);
        Result:=Result+'v'+IntToStr(Index);
      end else begin Result:=Result+Source[P]; Inc(P); end;
    end;
  end;
  procedure Evaluate(Index:Integer);
  var I,J:Integer; Evaluated:Double; Item:TDataVisualSet;
  begin
    if Index>=Length(ProgramCode) then begin
      Inc(Points); if Points>8192 then raise Exception.Create('Function data exceeds 8192 points');
      if not DataNumber(Values[X],Point.X) or not DataNumber(Values[Y],Point.Y) then
        raise Exception.Create('Function data requires numeric x and y');
      if SetIndex>=0 then Item:=FindSet(Values[SetIndex]) else Item:=FindSet(Settings.Values['set']);
      Item.Add(Point); Exit;
    end;
    if ProgramCode[Index].Parser=nil then begin
      for I:=0 to High(ProgramCode[Index].Values) do begin
        Values[ProgramCode[Index].Attribute]:=ProgramCode[Index].Values[I]; Evaluate(Index+1);
      end;
    end else begin
      for J:=0 to Names.Count-1 do begin
        if not DataNumber(Values[J],Evaluated) then Evaluated:=0;
        ProgramCode[Index].Identifiers[J].AsFloat:=Evaluated;
      end;
      Evaluated:=ProgramCode[Index].Parser.AsFloat;
      if IsNan(Evaluated) or IsInfinite(Evaluated) or (Abs(Evaluated)>1e100) then
        raise Exception.Create('Non-finite function value');
      Values[ProgramCode[Index].Attribute]:=FloatToStr(Evaluated,Format); Evaluate(Index+1);
    end;
  end;

begin
  Result:=False; Statements:=TStringList.Create; Names:=TStringList.Create; Values:=TStringList.Create; Calc:=TTikZCalc.Create;
  try
    Format:=DefaultFormatSettings; Format.DecimalSeparator:='.';
    Statements.StrictDelimiter:=True; Statements.Delimiter:=';';
    Variables:=Settings.Values['vars']; if Variables='' then Variables:=Options.Values['vars'];
    FunctionCode:=Settings.Values['funcs']; if FunctionCode='' then FunctionCode:=Options.Values['funcs'];
    Input:=Variables+';'+Code+';'+FunctionCode; Expression:=''; P:=1; Depth:=0; Last:=0;
    while P<=Length(Input) do begin
      if Input[P]='%' then begin while (P<=Length(Input)) and not (Input[P] in [#10,#13]) do Inc(P); Continue; end;
      if (Input[P] in [#10,#13]) and (Depth=0) then begin
        Q:=P; SkipTeXSpace(Input,Q);
        { Tolerate an unfinished statement terminator during instant editing. }
        if (Last>0) and (Expression[Last]<>';') and
          ((Copy(Input,Q,4)='var ') or (Copy(Input,Q,5)='func ')) then begin
          Expression:=Expression+';'; Last:=Length(Expression);
        end;
      end;
      case Input[P] of '{','[','(':Inc(Depth); '}',']',')':Dec(Depth); end;
      Expression:=Expression+Input[P];
      if not (Input[P] in [' ',#9,#10,#13]) then Last:=Length(Expression);
      Inc(P);
    end;
    Statements.DelimitedText:=Expression;
    if Statements.Count>256 then raise Exception.Create('Function data exceeds 256 declarations');
    SetLength(ProgramCode,Statements.Count); Index:=0;
    for I:=0 to Statements.Count-1 do begin
      Statement:=Trim(Statements[I]); if Statement='' then Continue;
      if Copy(Statement,1,4)='var ' then begin
        P:=Pos(':',Statement); if P=0 then raise Exception.Create('Expected var name : interval [start:end]');
        Name:=Trim(Copy(Statement,5,P-5)); ProgramCode[Index].Attribute:=Attribute(Name);
        Q:=P+1; SkipTeXSpace(Statement,Q);
        if Copy(Statement,Q,1)='{' then begin
          Range:=ReadTeXGroup(Statement,Q,'{','}');
          with TStringList.Create do try
            StrictDelimiter:=True; Delimiter:=','; DelimitedText:=Range;
            if (Count=0) or (Count>8192) then raise Exception.Create('Invalid function value list');
            SetLength(ProgramCode[Index].Values,Count);
            for J:=0 to Count-1 do begin
              Token:=Trim(Strings[J]);
              if Calc.Scalar(Token,Number) then Token:=FloatToStr(Number,Format);
              ProgramCode[Index].Values[J]:=Token;
            end;
          finally Free; end;
        end else begin
          Q:=Pos('[',Statement); if Q=0 then raise Exception.Create('Function variable has no interval');
          Range:=ReadTeXGroup(Statement,Q,'[',']'); P:=Pos(':',Range);
          if P=0 then P:=Pos(',',Range);
          if (P=0) or not Calc.Scalar(Copy(Range,1,P-1),Lower) or
            not Calc.Scalar(Copy(Range,P+1,MaxInt),Upper) then raise Exception.Create('Invalid function interval');
          Token:=Trim(Copy(Statement,Q,MaxInt));
          if Copy(Token,1,5)='step ' then begin
            if not Calc.Scalar(Copy(Token,6,MaxInt),Step) or (Abs(Step)<1e-12) or
              ((Upper-Lower)/Step<0) or ((Upper-Lower)/Step>8191) then raise Exception.Create('Invalid function step');
            N:=Floor((Upper-Lower)/Step+1e-7)+1;
          end else begin
            Expression:=Settings.Values['samples']; if Expression='' then Expression:=Options.Values['samples'];
            if Expression='' then Expression:='25';
            if Copy(Token,1,8)='samples ' then Expression:=Copy(Token,9,MaxInt)
            else if Token<>'' then raise Exception.Create('Expected step or samples');
            if not Calc.Scalar(Expression,SampleCount) or (SampleCount<2) or (SampleCount>8192) then
              raise Exception.Create('Function samples must be between 2 and 8192');
            N:=Trunc(SampleCount); Step:=(Upper-Lower)/(N-1);
          end;
          SetLength(ProgramCode[Index].Values,N);
          for J:=0 to N-1 do ProgramCode[Index].Values[J]:=FloatToStr(Lower+Step*J,Format);
        end;
      end else if Copy(Statement,1,5)='func ' then begin
        P:=Pos('=',Statement); if P=0 then raise Exception.Create('Expected func name = expression');
        ProgramCode[Index].Attribute:=Attribute(Trim(Copy(Statement,6,P-6)));
        ProgramCode[Index].Expression:=Trim(Copy(Statement,P+1,MaxInt));
      end else raise Exception.Create('Expected var or func: '+Statement);
      Inc(Index);
    end;
    SetLength(ProgramCode,Index); SetIndex:=Names.IndexOf('set'); X:=Names.IndexOf(AxisAttribute('x')); Y:=Names.IndexOf(AxisAttribute('y'));
    if (X<0) or (Y<0) then raise Exception.Create('Missing function attributes: '+AxisAttribute('x')+', '+AxisAttribute('y'));
    for I:=0 to High(ProgramCode) do if ProgramCode[I].Expression<>'' then begin
      ProgramCode[I].Parser:=TFPExpressionParser.Create(nil); ConfigurePlotMath(ProgramCode[I].Parser);
      SetLength(ProgramCode[I].Identifiers,Names.Count);
      for J:=0 to Names.Count-1 do ProgramCode[I].Identifiers[J]:=ProgramCode[I].Parser.Identifiers.AddFloatVariable('v'+IntToStr(J),0);
      ProgramCode[I].Parser.Expression:=PlotMathExpression(ReplaceValues(ProgramCode[I].Expression));
    end;
    Points:=0; Point:=Default(TPlotPoint); Evaluate(0); Result:=Points>0;
  finally
    for I:=0 to High(ProgramCode) do ProgramCode[I].Parser.Free;
    Calc.Free; Values.Free; Names.Free; Statements.Free;
  end;
end;
function TDataVisualization.Load(const Source,Directory:string; var P:Integer; const Defaults:string):Boolean;
var Settings,FileData:TStringList; Start,I:Integer; Code,FileName:string;
    Stream:TFileStream; Item:TDataVisualSet;
begin
  Result:=False; ErrorText:=''; Settings:=TStringList.Create; FileData:=TStringList.Create;
  try
    try
      Options.Clear; InputFiles.Clear; Sets.Clear; FDefault:='';
      ReadOptions(Defaults); ReadOptions(ReadTeXGroup(Source,P,'[',']'));
      while P<=Length(Source) do begin
        SkipTeXSpace(Source,P); if Copy(Source,P,1)=';' then begin Inc(P); Result:=True; Break; end;
        if Copy(Source,P,1)='[' then begin ReadOptions(ReadTeXGroup(Source,P,'[',']')); Continue; end;
        if Copy(Source,P,4)<>'data' then begin ErrorText:='Unsupported data visualization statement'; Exit; end;
        Inc(P,4); Settings.Clear; SettingsFrom(ReadTeXGroup(Source,P,'[',']'),Settings);
        SkipTeXSpace(Source,P); if Copy(Source,P,1)='=' then Inc(P);
        FileName:=Settings.Values['source'];
        if FileName<>'' then begin
          if (Copy(FileName,1,1)<>'/') and (Copy(FileName,1,1)<>'\') and (Copy(FileName,2,1)<>':') then
            FileName:=IncludeTrailingPathDelimiter(Directory)+FileName;
          FileName:=ExpandFileName(FileName);
          if InputFiles.IndexOf(FileName)<0 then InputFiles.Add(FileName);
          Stream:=TFileStream.Create(FileName,fmOpenRead or fmShareDenyNone);
          try if Stream.Size>1024*1024 then raise Exception.Create('Data file exceeds 1 MB'); FileData.LoadFromStream(Stream); finally Stream.Free; end;
          Code:=FileData.Text;
        end else begin
          Start:=P; Code:=ReadTeXGroup(Source,P,'{','}');
          if P=Start then begin ErrorText:='Missing data table'; Exit; end;
        end;
        if not Data(Code,Settings) then Exit;
      end;
      for I:=Sets.Count-1 downto 0 do if TDataVisualSet(Sets[I]).FCount=0 then Sets.Delete(I);
      for I:=0 to Sets.Count-1 do begin
        Item:=TDataVisualSet(Sets[I]); SetLength(Item.Points,Item.FCount);
        Settings.Clear; SettingsFrom(Options.Values[Item.Name],Settings);
        Item.Style:=Settings.Values['style']; Item.Legend:=Settings.Values['label in legend'];
        if Copy(Item.Legend,1,5)='text=' then Item.Legend:=Ungroup(Copy(Item.Legend,6,MaxInt));
        if Settings.IndexOfName('smooth line')>=0 then Item.Kind:='smooth line';
        if Settings.IndexOfName('no lines')>=0 then Item.Kind:='scatter';
        if Settings.IndexOfName('straight cycle')>=0 then Item.Kind:='cycle';
      end;
      if Sets.Count=0 then Result:=False;
    except on E:Exception do begin ErrorText:=E.Message; Result:=False; end; end;
  finally FileData.Free; Settings.Free; end;
end;
end.
