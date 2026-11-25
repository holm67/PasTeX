unit TeXSymbolRuns;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes;
type
  TSymbolPart=record Font:string; Code:Integer; X,Y:Double; end;
  TSymbolRun=record Parts:array of TSymbolPart; Advance:Double; end;
function FontSymbolRun(const Body:string; Fonts:TStrings; out Plan:string; MathMode:Boolean=False):Boolean;
function DecodeSymbolRun(const Plan:string; out Run:TSymbolRun):Boolean;
implementation
uses SysUtils, Math, TeXMacros, TeXFontData, TeXStyles;
function DecodeSymbolRun(const Plan:string; out Run:TSymbolRun):Boolean;
var Entries,Fields:TStringList; I:Integer; F:TFormatSettings;
begin
  Result:=False; Run:=Default(TSymbolRun); Entries:=TStringList.Create; Fields:=TStringList.Create;
  try
    F:=DefaultFormatSettings; F.DecimalSeparator:='.';
    Entries.StrictDelimiter:=True; Entries.Delimiter:=';'; Entries.DelimitedText:=Plan;
    if (Entries.Count<2) or (Entries.Count>65) or not TryStrToFloat(Entries[0],Run.Advance,F) or
      IsNan(Run.Advance) or IsInfinite(Run.Advance) or (Abs(Run.Advance)>10000) then Exit;
    SetLength(Run.Parts,Entries.Count-1); Fields.StrictDelimiter:=True; Fields.Delimiter:=':';
    for I:=1 to Entries.Count-1 do begin
      Fields.DelimitedText:=Entries[I]; if Fields.Count<>4 then Exit;
      with Run.Parts[I-1] do begin
        Font:=Fields[0]; Code:=StrToIntDef(Fields[1],-1);
        if (Code<0) or (Code>255) or not TryStrToFloat(Fields[2],X,F) or not TryStrToFloat(Fields[3],Y,F) or
          IsNan(X) or IsInfinite(X) or IsNan(Y) or IsInfinite(Y) or (Abs(X)>10000) or (Abs(Y)>10000) then Exit;
      end;
    end;
    Result:=True;
  finally Fields.Free; Entries.Free; end;
end;
function FontSymbolRun(const Body:string; Fonts:TStrings; out Plan:string; MathMode:Boolean):Boolean;
var Run:TSymbolRun; F:TFormatSettings; Depth,I:Integer; Valid:Boolean;
  procedure Part(const Font:string; Code:Integer; var X:Double; Y:Double);
  var N:Integer; Metric:TTeXFontMetric;
  begin
    N:=Length(Run.Parts); if (Font='') or (Code<0) or (Code>255) or (N>=64) then begin Valid:=False; Exit; end;
    Metric:=TeXFontMetric(Font); if not Metric.Valid or not Metric.Chars[Code].Valid then begin Valid:=False; Exit; end;
    SetLength(Run.Parts,N+1);
    Run.Parts[N].Font:=Font; Run.Parts[N].Code:=Code; Run.Parts[N].X:=X; Run.Parts[N].Y:=Y;
    X:=X+Metric.Chars[Code].Width;
  end;
  function Dimension(const Code:string; var P:Integer):Double;
  var A:Integer;
  begin
    SkipTeXSpace(Code,P); A:=P;
    while (P<=Length(Code)) and (Code[P] in ['0'..'9','-','+','.']) do Inc(P);
    while (P<=Length(Code)) and (Code[P] in ['a'..'z']) do Inc(P);
    Result:=TeXStyleDimension(Copy(Code,A,P-A),10)/10;
  end;
  procedure Read(const Code:string; var X:Double; Y:Double; Font:string; InMath:Boolean);
  var P,A,Slot,Base,I,First,Last,ArgumentCount:Integer; Command,Group,Family,Template,Expanded:string; Shift,Width,Start:Double;
      BoxWidth:Boolean; Nested:TSymbolRun; Arguments:array[1..9] of string;
    procedure Character(Slot:Integer);
    var Family:string; Code:Integer;
    begin
      if not InMath then begin Part(Font,Slot,X,Y); Exit; end;
      { TeX's \char in math uses \mathcode, not the current text font.
        A surrounding \mbox/\hbox is what keeps wasysym's text symbols. }
      Family:='cmr'; Code:=Slot;
      if (Slot>=0) and (Slot<128) then begin
        if not TeXSymbol(Chr(Slot),Family,Code) then begin
          Family:='cmr'; Code:=Slot;
          if Chr(Slot) in ['a'..'z','A'..'Z'] then Family:='cmmi';
        end;
      end;
      Part(TeXOpticalFont(Family,10),Code,X,Y);
    end;
  begin
    if Depth>=16 then begin Valid:=False; Exit; end; Inc(Depth); P:=1;
    try
      while (P<=Length(Code)) and Valid do begin
        SkipTeXSpace(Code,P); if P>Length(Code) then Break;
        if Code[P]='{' then begin Group:=ReadTeXGroup(Code,P,'{','}'); Read(Group,X,Y,Font,InMath); Continue; end;
        if Code[P]='$' then begin InMath:=not InMath; Inc(P); Continue; end;
        if Code[P]<>'\' then begin
          if InMath then Character(Ord(Code[P]))
          else Part('cmr10',Ord(Code[P]),X,Y);
          Inc(P); Continue;
        end;
        Command:=ReadTeXCommand(Code,P);
        if Fonts.Values[Command]<>'' then begin Font:=Fonts.Values[Command]; Continue; end;
        if Fonts.Values['@font:'+Command]<>'' then begin
          Group:=ReadTeXGroup(Code,P,'{','}'); Font:=TeXPackageFont(Fonts.Values['@font:'+Command],Group,GetCurrentDir); Continue;
        end;
        Template:=Fonts.Values['@'+Command];
        if Template<>'' then begin
          ArgumentCount:=StrToIntDef(Fonts.Values['?'+Command],0);
          if (ArgumentCount<0) or (ArgumentCount>9) then begin Valid:=False; Break; end;
          for I:=1 to ArgumentCount do Arguments[I]:=ReadTeXArgument(Code,P,True);
          if not SubstituteTeXParameters(Template,Slice(Arguments,ArgumentCount),Expanded) then begin Valid:=False; Break; end;
          Read(Expanded,X,Y,Font,InMath); Continue;
        end;
        Group:='#'+Command; if InMath and (Fonts.Values['#math:'+Command]<>'') then Group:='#math:'+Command;
        if DecodeSymbolRun(Fonts.Values[Group],Nested) then begin
          Start:=X;
          for I:=0 to High(Nested.Parts) do begin
            Width:=Start+Nested.Parts[I].X; Part(Nested.Parts[I].Font,Nested.Parts[I].Code,Width,Y+Nested.Parts[I].Y);
          end;
          X:=Start+Nested.Advance; Continue;
        end;
        case Command of
          'char':begin
            SkipTeXSpace(Code,P); Base:=10;
            if Copy(Code,P,1)='"' then begin Base:=16; Inc(P); end
            else if Copy(Code,P,1)='''' then begin Base:=8; Inc(P); end;
            A:=P; while (P<=Length(Code)) and (Code[P] in ['0'..'9','A'..'F','a'..'f']) do Inc(P);
            Group:=Copy(Code,A,P-A); if Base=16 then Group:='$'+Group else if Base=8 then Group:='&'+Group;
            Slot:=StrToIntDef(Group,-1); Character(Slot);
          end;
          'mbox','hbox':begin
            SkipTeXSpace(Code,P); BoxWidth:=Copy(Code,P,2)='to'; Width:=0;
            if BoxWidth then begin Inc(P,2); Width:=Dimension(Code,P); end;
            Start:=X; Group:=ReadTeXGroup(Code,P,'{','}'); Read(Group,X,Y,Font,False);
            if BoxWidth then X:=Start+Width;
          end;
          'raise','lower':begin
            Shift:=Dimension(Code,P); if Command='lower' then Shift:=-Shift;
            Command:=ReadTeXCommand(Code,P); if Command<>'hbox' then begin Valid:=False; Break; end;
            SkipTeXSpace(Code,P); BoxWidth:=Copy(Code,P,2)='to'; Width:=0;
            if BoxWidth then begin Inc(P,2); Width:=Dimension(Code,P); end;
            Start:=X; Group:=ReadTeXGroup(Code,P,'{','}'); Read(Group,X,Y+Shift,Font,False);
            if BoxWidth then X:=Start+Width;
          end;
          'kern':X:=X+Dimension(Code,P);
          'wasy@over':begin
            Group:=ReadTeXGroup(Code,P,'{','}'); Family:=ReadTeXGroup(Code,P,'{','}');
            Start:=X; First:=Length(Run.Parts); Read(Group,X,Y,Font,True); Last:=Length(Run.Parts);
            Width:=X-Start; X:=Start; Read(Family,X,Y,Font,True);
            Shift:=(X-Start-Width)/2;
            for I:=First to Last-1 do Run.Parts[I].X:=Run.Parts[I].X+Shift;
          end;
          'leavevmode','relax','hss','hfil':;
          else begin
            if TeXSymbol('\'+Command,Family,Slot) then Part(TeXOpticalFont(Family,10),Slot,X,Y)
            else Valid:=False;
          end;
        end;
      end;
    finally Dec(Depth); end;
  end;
begin
  Plan:=''; Run:=Default(TSymbolRun); F:=DefaultFormatSettings; F.DecimalSeparator:='.'; Depth:=0; Valid:=True;
  { This reads bounded font/glyph box declarations, never executes TeX. }
  Read(Body,Run.Advance,0,'',MathMode); Result:=Valid and (Length(Run.Parts)>0);
  if not Result then Exit;
  Plan:=FloatToStr(Run.Advance,F);
  for I:=0 to High(Run.Parts) do with Run.Parts[I] do
    Plan:=Plan+';'+Font+':'+IntToStr(Code)+':'+FloatToStr(X,F)+':'+FloatToStr(Y,F);
end;
end.
