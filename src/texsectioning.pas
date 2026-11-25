unit TeXSectioning;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses SysUtils, TeXMacros;
const SectionNames:array[0..6] of string=('part','chapter','section','subsection','subsubsection','paragraph','subparagraph');
type
  TSectionState=record
    Values:array[0..6] of Integer;
    NumberDepth:Integer;
    Chapters,MainMatter,Appendix:Boolean;
  end;
  TSectionFormat=array of record Text,Format:string; Counter:Integer; end;
function InitialSectionState(Chapters:Boolean; NumberDepth:Integer):TSectionState;
function SectionIndex(const Name:string):Integer;
function StepSection(var State:TSectionState; Index:Integer; Starred:Boolean):Boolean;
function ApplySectionCommand(var State:TSectionState; const Source:string):Boolean;
function FormatTeXCounter(Value:Integer; const Format:string):string;
function CompileSectionFormat(const Source:string; Registry:TMacroRegistry; Chapters:Boolean=False):TSectionFormat;
function RenderSectionFormat(const Template:TSectionFormat; const State:TSectionState):string;
function ExpandSectionCounters(const Source:string; const State:TSectionState; Registry:TMacroRegistry):string;
implementation
uses Math;
function SectionIndex(const Name:string):Integer;
var I:Integer;
begin
  Result:=-1; for I:=0 to High(SectionNames) do if Name=SectionNames[I] then Exit(I);
end;
function InitialSectionState(Chapters:Boolean; NumberDepth:Integer):TSectionState;
begin
  Result:=Default(TSectionState); Result.Chapters:=Chapters;
  Result.MainMatter:=True; Result.NumberDepth:=NumberDepth;
end;
function StepSection(var State:TSectionState; Index:Integer; Starred:Boolean):Boolean;
var I,Level:Integer;
begin
  Result:=False; if (Index<0) or (Index>High(SectionNames)) or Starred then Exit;
  Level:=Index-1; if (Index=0) and not State.Chapters then Level:=0;
  if (Level>State.NumberDepth) or ((Index=1) and not State.MainMatter) then Exit;
  State.Values[Index]:=Min(Int64(High(Integer)),Int64(State.Values[Index])+1);
  { classes.dtx: a part is independent; chapter through subparagraph form
    a reset chain. In particular, a part must not reset the section counter. }
  if Index>0 then for I:=Index+1 to High(SectionNames) do State.Values[I]:=0;
  Result:=True;
end;
function ApplySectionCommand(var State:TSectionState; const Source:string):Boolean;
var P,Index,Value:Integer; Command,Name:string;
begin
  Result:=True; P:=1; SkipTeXSpace(Source,P); Command:=ReadTeXCommand(Source,P);
  case Command of
    'appendix':begin
      State.Appendix:=True; Index:=2-Ord(State.Chapters);
      State.Values[Index]:=0; State.Values[Index+1]:=0;
    end;
    'frontmatter','backmatter':State.MainMatter:=False;
    'mainmatter':State.MainMatter:=True;
    'setcounter','addtocounter':begin
      Name:=ReadTeXGroup(Source,P,'{','}'); Index:=SectionIndex(Name);
      if (Index<0) and (Name<>'secnumdepth') then Exit(False);
      if not TryStrToInt(Trim(ReadTeXGroup(Source,P,'{','}')),Value) then Exit(False);
      if Index<0 then begin
        if Command='addtocounter' then Value:=EnsureRange(Int64(State.NumberDepth)+Value,Low(Integer),High(Integer));
        State.NumberDepth:=Value;
      end else begin
        if Command='addtocounter' then Value:=EnsureRange(Int64(State.Values[Index])+Value,Low(Integer),High(Integer));
        State.Values[Index]:=Value;
      end;
    end;
    else Result:=False;
  end;
end;
function FormatTeXCounter(Value:Integer; const Format:string):string;
const RomanValues:array[0..12] of Integer=(1000,900,500,400,100,90,50,40,10,9,5,4,1);
      RomanDigits:array[0..12] of string=('M','CM','D','CD','C','XC','L','XL','X','IX','V','IV','I');
      ChineseDigits:array[0..9] of string=('零','一','二','三','四','五','六','七','八','九');
      ChineseUnits:array[0..3] of string=('','十','百','千');
var I,Place,Digit:Integer; Zero:Boolean;
begin
  Result:=IntToStr(Value);
  if (Format='roman') or (Format='Roman') then begin
    Result:=''; if Value<=0 then Exit;
    if Value>3999 then Exit(IntToStr(Value));
    for I:=0 to High(RomanValues) do while Value>=RomanValues[I] do begin
      Result:=Result+RomanDigits[I]; Dec(Value,RomanValues[I]);
    end;
    if Format='roman' then Result:=LowerCase(Result);
  end else if (Format='alph') or (Format='Alph') then begin
    if Value=0 then Exit(''); if (Value<1) or (Value>26) then Exit('?');
    Result:=Chr(Ord('A')+Value-1); if Format='alph' then Result:=LowerCase(Result);
  end else if Format='chinese' then begin
    if (Value<0) or (Value>9999) then Exit; if Value=0 then Exit(ChineseDigits[0]);
    Result:=''; Place:=1000; Zero:=False;
    for I:=3 downto 0 do begin
      Digit:=Value div Place; Value:=Value mod Place;
      if Digit=0 then begin if (Result<>'') and (Value>0) then Zero:=True; end
      else begin
        if Zero then Result:=Result+ChineseDigits[0]; Zero:=False;
        if not ((I=1) and (Digit=1) and (Result='')) then Result:=Result+ChineseDigits[Digit];
        Result:=Result+ChineseUnits[I];
      end;
      Place:=Place div 10;
    end;
  end;
end;
function CompileSectionFormat(const Source:string; Registry:TMacroRegistry; Chapters:Boolean):TSectionFormat;
var Budget:Integer;
  procedure Add(const Text,Format:string; Counter:Integer);
  var N:Integer;
  begin
    N:=Length(Result);
    if (Counter<0) and (N>0) and (Result[N-1].Counter<0) then begin Result[N-1].Text:=Result[N-1].Text+Text; Exit; end;
    SetLength(Result,N+1); Result[N].Text:=Text; Result[N].Format:=Format; Result[N].Counter:=Counter;
  end;
  procedure Expand(const Code:string; Depth:Integer);
  var P,A,Index:Integer; Command,Name,Format:string; Info:TMacroInfo;
  begin
    if (Depth>16) or (Budget<=0) or (Length(Code)>8192) then Exit;
    Dec(Budget); P:=1;
    while (P<=Length(Code)) and (Length(Result)<256) do begin
      if Code[P]<>'\' then begin
        A:=P; while (P<=Length(Code)) and (Code[P]<>'\') do Inc(P);
        Add(Copy(Code,A,P-A),'',-1); Continue;
      end;
      A:=P; Command:=ReadTeXCommand(Code,P); Index:=-1;
      Info:=nil; if Registry<>nil then Info:=Registry.Find(Command);
      if Copy(Command,1,3)='the' then Index:=SectionIndex(Copy(Command,4,MaxInt));
      if Index>=0 then begin
        if (Info<>nil) and not Info.Undefined and (Info.ArgCount=0) and (Info.Body<>'') then Expand(Info.Body,Depth+1)
        else begin
          Format:='arabic'; if Index=0 then Format:='Roman';
          if (Index>2) or ((Index=2) and Chapters) then begin Expand('\the'+SectionNames[Index-1],Depth+1); Add('.','',-1); end;
          Add('',Format,Index);
        end;
        SkipTeXSpace(Code,P); Continue;
      end;
      Format:=Command; if Copy(Format,1,1)='@' then Delete(Format,1,1);
      if (Format='arabic') or (Format='Roman') or (Format='roman') or
        (Format='Alph') or (Format='alph') or (Format='chinese') or
        (Format='value') or (Format='number') or (Format='the') then begin
        SkipTeXSpace(Code,P);
        if Copy(Code,P,1)='{' then Name:=ReadTeXGroup(Code,P,'{','}')
        else begin Name:=ReadTeXCommand(Code,P); if Copy(Name,1,2)='c@' then Delete(Name,1,2); end;
        Index:=SectionIndex(Name);
        if Index>=0 then begin Add('',Format,Index); Continue; end;
      end;
      if (Info<>nil) and Info.Expandable and not Info.Undefined and (Info.ArgCount=0) and (Info.Body<>'\'+Command) then
        Expand(Info.Body,Depth+1)
      else Add(Copy(Code,A,P-A),'',-1);
    end;
  end;
begin Result:=nil; Budget:=256; Expand(Source,0); end;
function RenderSectionFormat(const Template:TSectionFormat; const State:TSectionState):string;
var I:Integer;
begin
  Result:='';
  for I:=0 to High(Template) do
    if Template[I].Counter<0 then Result:=Result+Template[I].Text
    else Result:=Result+FormatTeXCounter(State.Values[Template[I].Counter],Template[I].Format);
end;
function ExpandSectionCounters(const Source:string; const State:TSectionState; Registry:TMacroRegistry):string;
begin Result:=RenderSectionFormat(CompileSectionFormat(Source,Registry,State.Chapters),State); end;
end.
