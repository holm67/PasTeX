unit BeamerTheme;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Graphics, BeamerModel;
type
  TBeamerTheme=class
  private
    FValues,FColors,FVisited,FCommands,FFlags:TStringList;
    FDirectory:string;
    FSettings:TBeamerSettings;
    FSteps,FExpansionSteps:Integer;
    procedure Scan(const Source:string; Depth:Integer; const Options:string='');
    procedure Import(const Kind,Name:string; Depth:Integer; const Options:string='');
    function Expand(const Value:string; Depth:Integer=0):string;
    function ReadProperty(const Kind,Name,Key:string; out Value:string; Depth:Integer):Boolean;
    function PropertyValue(const Kind,Name,Key:string; Depth:Integer=0):string;
    function ColorValue(const Value:string; Depth:Integer):TColor;
  public
    constructor Create;
    destructor Destroy; override;
    procedure Load(const Source,Directory:string);
    function Font(const Name:string):string;
    function Color(const Name:string; Background:Boolean=False):TColor;
    function Template(const Name:string):string;
    function HasTemplate(const Name:string):Boolean;
    function Dimension(const Name:string):string;
    function Information(const Name:string):string;
    property Settings:TBeamerSettings read FSettings;
  end;
implementation
uses SysUtils, Math, StrUtils, TeXMacros, TeXPackageSources, TikZModel, PlotColors, CommandDefinition;
constructor TBeamerTheme.Create;
begin
  FValues:=TStringList.Create; FColors:=TStringList.Create; FVisited:=TStringList.Create;
  FCommands:=TStringList.Create; FFlags:=TStringList.Create;
  FValues.CaseSensitive:=True; FColors.CaseSensitive:=True; FVisited.CaseSensitive:=True;
  FCommands.CaseSensitive:=True; FFlags.CaseSensitive:=True;
end;
destructor TBeamerTheme.Destroy;
begin FValues.Free; FColors.Free; FVisited.Free; FCommands.Free; FFlags.Free; inherited; end;
procedure TBeamerTheme.Import(const Kind,Name:string; Depth:Integer; const Options:string);
var FileName,Source:string;
begin
  if (Depth>12) or (FVisited.Count>=64) then Exit;
  FileName:=ResolveTeXSource('beamer'+Kind+'theme'+Name+'.sty',FDirectory);
  if (FileName='') or (FVisited.IndexOf(FileName)>=0) then Exit;
  FVisited.Add(FileName); Source:=ReadTeXSource(FileName); Scan(Source,Depth+1,Options);
end;
function TBeamerTheme.Expand(const Value:string; Depth:Integer):string;
var P,A,I:Integer; Name:string;
begin
  Result:=''; if Depth>12 then Exit(Value); P:=1;
  while P<=Length(Value) do begin
    Inc(FExpansionSteps); if FExpansionSteps>10000 then Break;
    if Value[P]<>'\' then begin Result:=Result+Value[P]; Inc(P); Continue; end;
    A:=P; Name:=ReadTeXCommand(Value,P); I:=FCommands.IndexOfName(Name);
    if I>=0 then Result:=Result+Expand(FCommands.ValueFromIndex[I],Depth+1)
    else Result:=Result+Copy(Value,A,P-A);
  end;
end;
procedure TBeamerTheme.Scan(const Source:string; Depth:Integer; const Options:string);
var P,Q,I,Pause:Integer; Command,Name,Value,Arguments,Kind,Key,Model:string; Starred,Active:Boolean;
    Entry:TDiagramOption; Names,RGB,Handlers,Defaults:TStringList; F:TFormatSettings; Scale:Double; C:array[0..2] of Integer;
    Definition:TCommandDefinition; Selection:TBeamerOverlay;
  function Unwrap(const Value:string):string;
  var P:Integer; Group:string;
  begin
    Result:=Trim(Value); P:=1;
    if Copy(Result,1,1)='{' then begin
      Group:=ReadTeXGroup(Result,P,'{','}');
      if P>Length(Result) then Result:=Group;
    end;
  end;
  procedure SetProperty(const Name,Value:string);
  var I:Integer;
  begin
    I:=FValues.IndexOfName(Name);
    if I<0 then FValues.Add(Name+'='+Value) else FValues[I]:=Name+'='+Value;
  end;
  procedure SetCommand(const Name,Value:string);
  var I:Integer;
  begin
    I:=FCommands.IndexOfName(Name);
    if I<0 then FCommands.Add(Name+'='+Value) else FCommands[I]:=Name+'='+Value;
  end;
  procedure ApplyOptions(const Value:string);
  var Entry:TDiagramOption; Body,Argument,Expanded:string;
  begin
    for Entry in DiagramOptions(Value) do begin
      Body:=Handlers.Values[Entry.Name]; if Body='' then Continue;
      Argument:=Entry.Value; if Argument='' then Argument:=Defaults.Values[Entry.Name];
      if SubstituteTeXParameters(Body,[Argument],Expanded) then Scan(Expanded,Depth+1);
    end;
  end;
  procedure ApplyConditional(Condition:Boolean);
  var Cursor,Start,Finish,ElseStart,ElseAfter,Level,AtCommand:Integer; Name:string;
  begin
    Cursor:=P; Start:=P; Finish:=Length(Source)+1; ElseStart:=0; ElseAfter:=0; Level:=1;
    while Cursor<=Length(Source) do begin
      SkipTeXSpace(Source,Cursor); if Cursor>Length(Source) then Break;
      if Source[Cursor]<>'\' then begin Inc(Cursor); Continue; end;
      if ReadTeXDefinition(Source,Cursor) or SkipTeXLiteral(Source,Cursor) then Continue;
      AtCommand:=Cursor; Name:=ReadTeXCommand(Source,Cursor);
      if Copy(Name,1,2)='if' then Inc(Level)
      else if Name='fi' then begin Dec(Level); if Level=0 then begin Finish:=AtCommand; Break; end; end
      else if (Name='else') and (Level=1) then begin ElseStart:=AtCommand; ElseAfter:=Cursor; end;
    end;
    P:=Cursor;
    if Condition then begin
      if ElseStart>0 then Finish:=ElseStart;
      Scan(Copy(Source,Start,Finish-Start),Depth+1);
    end else if ElseAfter>0 then Scan(Copy(Source,ElseAfter,Finish-ElseAfter),Depth+1);
  end;
begin
  if Depth>24 then Exit;
  P:=1; Active:=True; Names:=TStringList.Create; RGB:=TStringList.Create;
  Handlers:=TStringList.Create; Defaults:=TStringList.Create;
  try
    Names.StrictDelimiter:=True; Names.Delimiter:=','; RGB.StrictDelimiter:=True; RGB.Delimiter:=',';
    F:=DefaultFormatSettings; F.DecimalSeparator:='.';
    while P<=Length(Source) do begin
      Inc(FSteps); if FSteps>50000 then Break;
      SkipTeXSpace(Source,P); if P>Length(Source) then Break;
      if Source[P]='{' then begin ReadTeXGroup(Source,P,'{','}'); Continue; end;
      if Source[P]<>'\' then begin Inc(P); Continue; end;
      Q:=P; I:=P; Command:=ReadTeXCommand(Source,I);
      if (Command<>'let') and ReadTeXDefinition(Source,Q) then begin
        if Active and ReadCommandDefinition(Copy(Source,P,Q-P),Definition) and (Length(Definition.Arguments)=0) then
          SetCommand(Definition.Name,Definition.Body);
        P:=Q; Continue;
      end;
      if SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
      Command:=ReadTeXCommand(Source,P); Starred:=Copy(Source,P,1)='*'; if Starred then Inc(P);
      if Command='mode' then begin
        Value:=ReadBeamerOverlay(Source,P); Pause:=1;
        Selection:=DecodeBeamerOverlay(Value,FSettings.Mode,1,Pause); Q:=P; SkipTeXSpace(Source,Q);
        if Copy(Source,Q,1)='{' then begin
          Value:=ReadTeXGroup(Source,P,'{','}'); if Selection.Active then Scan(Value,Depth+1);
        end else Active:=Selection.Active;
        Continue;
      end;
      if not Active then Continue;
      if Command='newif' then begin
        SkipTeXSpace(Source,P); Name:=ReadTeXCommand(Source,P); FFlags.Values[Name]:='0';
      end else if FFlags.IndexOfName(Command)>=0 then ApplyConditional(FFlags.Values[Command]='1')
      else if (Copy(Command,Length(Command)-3,4)='true') and
        (FFlags.IndexOfName('if'+Copy(Command,1,Length(Command)-4))>=0) then
        FFlags.Values['if'+Copy(Command,1,Length(Command)-4)]:='1'
      else if (Copy(Command,Length(Command)-4,5)='false') and
        (FFlags.IndexOfName('if'+Copy(Command,1,Length(Command)-5))>=0) then
        FFlags.Values['if'+Copy(Command,1,Length(Command)-5)]:='0'
      else if Command='let' then begin
        SkipTeXSpace(Source,P); Name:=ReadTeXCommand(Source,P); SkipTeXSpace(Source,P);
        if Copy(Source,P,1)='=' then begin Inc(P); SkipTeXSpace(Source,P); end;
        Value:=ReadTeXCommand(Source,P);
        if Value='relax' then SetCommand(Name,'') else SetCommand(Name,Expand('\'+Value));
      end else if Command='DeclareOptionBeamer' then begin
        Name:=ReadTeXGroup(Source,P,'{','}'); Defaults.Values[Name]:=ReadTeXGroup(Source,P,'[',']');
        Handlers.Values[Name]:=ReadTeXGroup(Source,P,'{','}');
      end else if Command='ProcessOptionsBeamer' then ApplyOptions(Options)
      else if Command='ExecuteOptionsBeamer' then ApplyOptions(ReadTeXGroup(Source,P,'{','}'))
      else if (Command='usetheme') or (Command='usecolortheme') or (Command='usefonttheme') or
        (Command='useinnertheme') or (Command='useoutertheme') then begin
        Arguments:=ReadTeXGroup(Source,P,'[',']'); Names.DelimitedText:=ReadTeXGroup(Source,P,'{','}');
        Kind:=Copy(Command,4,Length(Command)-8);
        for Name in Names do begin
          if (Kind='outer') or (Kind='inner') then FValues.Values['template:'+Kind]:=Trim(Name);
          Import(Kind,Trim(Name),Depth,Arguments);
        end;
      end else if (Command='setbeamerfont') or (Command='setbeamercolor') then begin
        Name:=ReadTeXGroup(Source,P,'{','}'); Value:=ReadTeXGroup(Source,P,'{','}');
        Kind:='font'; if Command='setbeamercolor' then Kind:='color'; Key:=Kind+':'+Name+':';
        if Starred then for I:=FValues.Count-1 downto 0 do
          if Copy(FValues.Names[I],1,Length(Key))=Key then FValues.Delete(I);
        for Entry in DiagramOptions(Value) do begin
          Model:=Entry.Name; Arguments:=Unwrap(Entry.Value);
          if Kind='font' then case Model of
            'size*':begin Model:='size'; Arguments:='\fontsize'+Arguments+'\selectfont'; end;
            'family*','series*','shape*':begin
              Delete(Model,Length(Model),1); Arguments:='\font'+Model+'{'+Arguments+'}';
            end;
          end;
          SetProperty(Key+Model,Arguments);
        end;
      end else if Command='setbeamertemplate' then begin
        Name:=ReadTeXGroup(Source,P,'{','}'); Q:=P; SkipTeXSpace(Source,Q);
        if Copy(Source,Q,1)='[' then Value:=ReadTeXGroup(Source,P,'[',']') else Value:=ReadTeXGroup(Source,P,'{','}');
        SetProperty('template:'+Name,Value);
      end else if Command='setbeamersize' then begin
        Value:=ReadTeXGroup(Source,P,'{','}');
        for Entry in DiagramOptions(Value) do FValues.Values['dimension:'+Entry.Name]:=Unwrap(Entry.Value);
      end else if (Command='definecolor') or (Command='providecolor') then begin
        Name:=ReadTeXGroup(Source,P,'{','}'); Model:=ReadTeXGroup(Source,P,'{','}'); Value:=ReadTeXGroup(Source,P,'{','}');
        if (Command='providecolor') and (FColors.IndexOfName(Name)>=0) then Continue;
        if Model='HTML' then FColors.Values[Name]:='#'+Value
        else if (Model='rgb') or (Model='RGB') or (Model='gray') then begin
          RGB.DelimitedText:=Value; Scale:=255; if Model='RGB' then Scale:=1;
          if Model='gray' then begin if RGB.Count<>1 then Continue; RGB.Add(RGB[0]); RGB.Add(RGB[0]); end;
          if RGB.Count<>3 then Continue;
          for I:=0 to 2 do C[I]:=EnsureRange(Round(StrToFloatDef(Trim(RGB[I]),0,F)*Scale),0,255);
          FColors.Values[Name]:='#'+IntToHex(C[0],2)+IntToHex(C[1],2)+IntToHex(C[2],2);
        end;
      end else if Command='colorlet' then begin
        Name:=ReadTeXGroup(Source,P,'{','}'); FColors.Values[Name]:=ReadTeXGroup(Source,P,'{','}');
      end else if (Command='title') or (Command='subtitle') or (Command='author') or (Command='institute') or (Command='date') or (Command='titlegraphic') then begin
        Arguments:=ReadTeXGroup(Source,P,'[',']'); Value:=ReadTeXGroup(Source,P,'{','}');
        FValues.Values['info:'+Command]:=Value;
        if Arguments<>'' then FValues.Values['info:short'+Command]:=Arguments else FValues.Values['info:short'+Command]:=Value;
      end else begin
        I:=FCommands.IndexOfName(Command);
        if I>=0 then Scan(FCommands.ValueFromIndex[I],Depth+1);
      end;
    end;
  finally Names.Free; RGB.Free; Handlers.Free; Defaults.Free; end;
end;
procedure TBeamerTheme.Load(const Source,Directory:string);
begin
  FValues.Clear; FColors.Clear; FVisited.Clear; FCommands.Clear; FFlags.Clear;
  FSteps:=0; FExpansionSteps:=0;
  FDirectory:=Directory; FSettings:=BeamerSettings(Source);
  Import('color','default',0); Import('font','default',0);
  Scan(Source,0);
  if FCommands.IndexOfName('familydefault')>=0 then FSettings.Serif:=Expand('\familydefault')='\rmdefault';
  if FCommands.IndexOfName('mathfamilydefault')>=0 then FSettings.SerifMath:=Expand('\mathfamilydefault')='\rmdefault';
end;
function TBeamerTheme.ReadProperty(const Kind,Name,Key:string; out Value:string; Depth:Integer):Boolean;
var Parent,InheritedValue:string; Names:TStringList; I:Integer;
begin
  Value:=''; Result:=False; if Depth>12 then Exit;
  I:=FValues.IndexOfName(Kind+':'+Name+':'+Key);
  if I>=0 then begin Value:=FValues.ValueFromIndex[I]; Exit(True); end;
  Names:=TStringList.Create;
  try
    Names.StrictDelimiter:=True; Names.Delimiter:=','; Names.DelimitedText:=FValues.Values[Kind+':'+Name+':parent'];
    for Parent in Names do if ReadProperty(Kind,Trim(Parent),Key,InheritedValue,Depth+1) then begin
      Value:=InheritedValue; Result:=True;
    end;
  finally Names.Free; end;
end;
function TBeamerTheme.PropertyValue(const Kind,Name,Key:string; Depth:Integer):string;
begin ReadProperty(Kind,Name,Key,Result,Depth); end;
function TBeamerTheme.ColorValue(const Value:string; Depth:Integer):TColor;
var P:Integer; Name,Rest,Resolved,Part:string;
begin
  if Depth>16 then Exit(clBlack);
  Name:=Trim(Value); P:=Pos('!',Name); Rest:='';
  if P>0 then begin Rest:=Copy(Name,P,MaxInt); Name:=Copy(Name,1,P-1); end;
  Resolved:=FColors.Values[Name];
  if (Name='bg') or (Name='fg') then begin
    Resolved:=PropertyValue('color','normal text',Name);
    if Resolved='' then if Name='bg' then Resolved:='white' else Resolved:='black';
  end;
  if Resolved='' then begin
    P:=RPos('.',Name);
    if (P>0) and ((Copy(Name,P,MaxInt)='.fg') or (Copy(Name,P,MaxInt)='.bg')) then
      Resolved:=PropertyValue('color',Copy(Name,1,P-1),Copy(Name,P+1,MaxInt));
  end;
  if Resolved<>'' then begin
    Result:=ColorToRGB(ColorValue(Resolved,Depth+1));
    Name:='#'+IntToHex(Result and 255,2)+IntToHex((Result shr 8) and 255,2)+IntToHex((Result shr 16) and 255,2);
  end;
  if Rest<>'' then begin
    P:=PosEx('!',Rest,2);
    if P>0 then begin
      Part:=Copy(Rest,P+1,MaxInt); Result:=ColorToRGB(ColorValue(Part,Depth+1));
      Rest:=Copy(Rest,1,P)+'#'+IntToHex(Result and 255,2)+IntToHex((Result shr 8) and 255,2)+IntToHex((Result shr 16) and 255,2);
    end;
  end;
  Result:=NamedColor(Name+Rest);
end;
function TBeamerTheme.Color(const Name:string; Background:Boolean):TColor;
var Key,Value:string;
begin
  Key:='fg'; if Background then Key:='bg'; Value:=PropertyValue('color',Name,Key);
  if (Value='') and Background then Exit(clNone);
  if Value='' then Value:=PropertyValue('color','normal text','fg');
  Result:=ColorValue(Value,0);
end;
function TBeamerTheme.Font(const Name:string):string;
var Key:string;
begin
  FExpansionSteps:=0;
  Result:=PropertyValue('font',Name,'size');
  for Key in TStringArray.Create('shape','series','family') do Result:=Result+PropertyValue('font',Name,Key);
  Result:=Expand(Result);
end;
function TBeamerTheme.Template(const Name:string):string;
begin Result:=FValues.Values['template:'+Name]; end;
function TBeamerTheme.HasTemplate(const Name:string):Boolean;
begin Result:=FValues.IndexOfName('template:'+Name)>=0; end;
function TBeamerTheme.Information(const Name:string):string;
begin Result:=FValues.Values['info:'+Name]; end;
function TBeamerTheme.Dimension(const Name:string):string;
begin Result:=FValues.Values['dimension:'+Name]; end;
end.
