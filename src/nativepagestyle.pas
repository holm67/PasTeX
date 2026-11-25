unit NativePageStyle;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type
  TPageFurniture=record
    Header,Footer:array[0..2] of string;
    HeadHeight,HeadSep,FootSkip,HeadRule,FootRule:Double;
    Number:string;
  end;
function PageFurniture(const Source:string; Page:Integer; const LeftMark,RightMark:string):TPageFurniture;
function PageStyleCommands(const Source:string; Transient:Boolean):string;
function PageHeadingMark(const Source:string; Uppercase:Boolean=True):string;
implementation
uses Classes, SysUtils, Math, TeXMacros, TeXStyles, TeXDocumentMetrics;
function PageHeadingMark(const Source:string; Uppercase:Boolean):string;
var P,A:Integer; Command:string; MathMode:Boolean;
begin
  Result:=''; P:=1; MathMode:=False;
  while P<=Length(Source) do begin
    if Source[P]='\' then begin
      A:=P; Command:=ReadTeXCommand(Source,P);
      if Command='label' then ReadTeXGroup(Source,P,'{','}')
      else begin
        if (Command='(') or (Command='[') then MathMode:=True
        else if (Command=')') or (Command=']') then MathMode:=False;
        Result:=Result+Copy(Source,A,P-A);
      end;
    end else begin
      if Source[P]='$' then MathMode:=not MathMode;
      if Uppercase and not MathMode and (Source[P] in ['a'..'z']) then Result:=Result+UpCase(Source[P])
      else Result:=Result+Source[P]; Inc(P);
    end;
  end;
end;
function PageStyleCommands(const Source:string; Transient:Boolean):string;
var P,A,Q:Integer; Command,Name:string;
begin
  Result:=''; P:=1;
  while P<=Length(Source) do begin
    SkipTeXSpace(Source,P); if P>Length(Source) then Break;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    A:=P; Q:=P;
    if ReadTeXDefinition(Source,Q) or SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
    Command:=ReadTeXCommand(Source,P);
    if (Command='pagestyle') or (Transient and (Command='thispagestyle')) then begin
      ReadTeXGroup(Source,P,'{','}'); Result:=Result+Copy(Source,A,P-A)+#10;
    end else if (Command='fancyhead') or (Command='fancyfoot') or (Command='fancyhf') or
      (Command='lhead') or (Command='chead') or (Command='rhead') or
      (Command='lfoot') or (Command='cfoot') or (Command='rfoot') then begin
      ReadTeXGroup(Source,P,'[',']'); ReadTeXGroup(Source,P,'{','}'); Result:=Result+Copy(Source,A,P-A)+#10;
    end else if (Command='markboth') or (Command='markright') then begin
      ReadTeXGroup(Source,P,'{','}'); if Command='markboth' then ReadTeXGroup(Source,P,'{','}');
      Result:=Result+Copy(Source,A,P-A)+#10;
    end else if (Command='begin') or (Command='end') then begin
      Name:=ReadTeXGroup(Source,P,'{','}');
      if (Command='begin') and IsTeXVerbatimEnvironment(Name) then begin
        Q:=Pos('\end{'+Name+'}',Copy(Source,P,MaxInt));
        if Q=0 then Break else Inc(P,Q+Length(Name)+5);
      end;
    end;
  end;
end;
function PageFurniture(const Source:string; Page:Integer; const LeftMark,RightMark:string):TPageFurniture;
type TFields=array[0..5] of string;
const RomanValue:array[0..12] of Integer=(1000,900,500,400,100,90,50,40,10,9,5,4,1);
      RomanText:array[0..12] of string=('M','CM','D','CD','C','XC','L','XL','X','IX','V','IV','I');
var Heads,Feet:TFields; Style,Numbering,LMark,RMark,PageNumber:string; Named:TStringList;
    I,N,PageBase:Integer; TwoSided,UseFancy:Boolean; Em:Double;
  procedure Fields(const Selector,Area,Value:string);
  var Parts:TStringList; Part:string; I,J:Integer; Header,Footer:Boolean;
  begin
    Parts:=TStringList.Create;
    try
      Parts.Delimiter:=','; Parts.StrictDelimiter:=True; Parts.DelimitedText:=UpperCase(Selector);
      if Parts.Count=0 then Parts.Add('');
      for Part in Parts do begin
        Header:=(Area='h') or ((Area='') and ((Pos('H',Part)>0) or (Pos('F',Part)=0)));
        Footer:=(Area='f') or ((Area='') and ((Pos('F',Part)>0) or (Pos('H',Part)=0)));
        for I:=0 to 5 do begin
          if (Pos('E',Part)>0) and (Pos('O',Part)=0) and (I<3) then Continue;
          if (Pos('O',Part)>0) and (Pos('E',Part)=0) and (I>=3) then Continue;
          J:=I mod 3;
          if ((Pos('L',Part)>0) or (Pos('C',Part)>0) or (Pos('R',Part)>0)) and
            (((J=0) and (Pos('L',Part)=0)) or ((J=1) and (Pos('C',Part)=0)) or ((J=2) and (Pos('R',Part)=0))) then Continue;
          if Header then Heads[I]:=Value; if Footer then Feet[I]:=Value;
        end;
      end;
    finally Parts.Free; end;
  end;
  procedure Parse(const Code:string; Depth:Integer);
  var P,A,Q,Index,Slot:Integer; Command,Name,Options,Value,Even,Base:string; V:Double;
  begin
    if Depth>8 then Exit; P:=1;
    while P<=Length(Code) do begin
      SkipTeXSpace(Code,P); if P>Length(Code) then Break;
      if Code[P]<>'\' then begin Inc(P); Continue; end;
      A:=P; Command:=ReadTeXCommand(Code,P);
      if (Command='pagestyle') or (Command='thispagestyle') then begin
        Style:=ReadTeXGroup(Code,P,'{','}'); Index:=Named.IndexOfName(Style);
        if Index>=0 then begin Parse(Named.ValueFromIndex[Index],Depth+1); UseFancy:=True; end
        else UseFancy:=Style='fancy';
      end else if Command='fancypagestyle' then begin
        Name:=ReadTeXGroup(Code,P,'{','}'); Base:=ReadTeXGroup(Code,P,'[',']'); Value:=ReadTeXGroup(Code,P,'{','}');
        if Base<>'' then Value:='\pagestyle{'+Base+'}'+Value;
        Named.Values[Name]:=Value;
      end else if (Command='fancyhead') or (Command='fancyfoot') or (Command='fancyhf') then begin
        Options:=ReadTeXGroup(Code,P,'[',']'); Value:=ReadTeXGroup(Code,P,'{','}');
        Name:=''; if Command='fancyhead' then Name:='h' else if Command='fancyfoot' then Name:='f'; Fields(Options,Name,Value);
      end else if (Command='lhead') or (Command='chead') or (Command='rhead') or
                  (Command='lfoot') or (Command='cfoot') or (Command='rfoot') then begin
        SkipTeXSpace(Code,P); Index:=Ord(Copy(Code,P,1)='['); Even:=ReadTeXGroup(Code,P,'[',']'); Value:=ReadTeXGroup(Code,P,'{','}');
        Slot:=0; if Command[1]='c' then Slot:=1 else if Command[1]='r' then Slot:=2;
        if Index=0 then Even:=Value;
        if Pos('head',Command)>0 then begin Heads[Slot]:=Value; Heads[Slot+3]:=Even; end
        else begin Feet[Slot]:=Value; Feet[Slot+3]:=Even; end;
      end else if (Command='renewcommand') or (Command='setlength') then begin
        SkipTeXSpace(Code,P); if Copy(Code,P,1)='*' then Inc(P); SkipTeXSpace(Code,P);
        if Copy(Code,P,1)='\' then Name:='\'+ReadTeXCommand(Code,P) else Name:=ReadTeXGroup(Code,P,'{','}');
        if (Name<>'\headrulewidth') and (Name<>'\footrulewidth') and (Name<>'\headheight') and (Name<>'\headsep') and (Name<>'\footskip') then begin
          Q:=A; if ReadTeXDefinition(Code,Q) then P:=Q; Continue;
        end;
        Value:=ReadTeXGroup(Code,P,'{','}'); V:=TeXStyleDimension(Value,Em);
        if IsNan(V) or IsInfinite(V) then Continue; V:=EnsureRange(V,0,1000);
        case Name of '\headrulewidth':Result.HeadRule:=V; '\footrulewidth':Result.FootRule:=V;
          '\headheight':Result.HeadHeight:=V; '\headsep':Result.HeadSep:=V; '\footskip':Result.FootSkip:=V; end;
      end else if Command='pagenumbering' then begin Numbering:=ReadTeXGroup(Code,P,'{','}'); PageBase:=1; end
      else if Command='setcounter' then begin
        Name:=ReadTeXGroup(Code,P,'{','}'); Value:=ReadTeXGroup(Code,P,'{','}');
        if Name='page' then PageBase:=StrToIntDef(Value,1);
      end else if Command='markboth' then begin LMark:=ReadTeXGroup(Code,P,'{','}'); RMark:=ReadTeXGroup(Code,P,'{','}'); end
      else if Command='markright' then RMark:=ReadTeXGroup(Code,P,'{','}')
      else begin Q:=A; if ReadTeXDefinition(Code,Q) or SkipTeXLiteral(Code,Q) then P:=Q; end;
    end;
  end;
  function Expand(const Code:string; Depth:Integer=0; NoUppercase:Boolean=False):string;
  var P,A:Integer; Command,Value:string;
  begin
    Result:=''; if Depth>16 then Exit; P:=1;
    while P<=Length(Code) do begin
      if Code[P]<>'\' then begin Result:=Result+Code[P]; Inc(P); Continue; end;
      A:=P; Command:=ReadTeXCommand(Code,P);
      case Command of
        'thepage':Result:=Result+PageNumber;
        'leftmark':Result:=Result+Expand(LMark,Depth+1,NoUppercase);
        'rightmark':Result:=Result+Expand(RMark,Depth+1,NoUppercase);
        'nouppercase':Result:=Result+Expand(ReadTeXGroup(Code,P,'{','}'),Depth+1,True);
        'MakeUppercase':begin
          Value:=Expand(ReadTeXGroup(Code,P,'{','}'),Depth+1,NoUppercase); Result:=Result+PageHeadingMark(Value,not NoUppercase);
        end;
        'fancyplain':begin ReadTeXGroup(Code,P,'{','}'); Value:=ReadTeXGroup(Code,P,'{','}'); Result:=Result+Expand(Value,Depth+1,NoUppercase); end;
        else Result:=Result+Copy(Code,A,P-A);
      end;
    end;
  end;
begin
  Result:=Default(TPageFurniture); Em:=DocumentFontPoints(Source);
  Result.HeadHeight:=12; Result.HeadSep:=25; Result.FootSkip:=30; Result.HeadRule:=0.4;
  Style:='plain'; UseFancy:=False; Numbering:='arabic'; PageBase:=1; LMark:=LeftMark; RMark:=RightMark;
  if (Pos('{book}',Source)>0) or (Pos('{ctexbook}',Source)>0) then Style:='headings';
  TwoSided:=(Pos('twoside',Source)>0) or (((Pos('{book}',Source)>0) or (Pos('{ctexbook}',Source)>0)) and (Pos('oneside',Source)=0));
  Heads[0]:='\slshape\rightmark'; Heads[2]:='\slshape\leftmark';
  if TwoSided then begin Heads[0]:='\slshape\leftmark'; Heads[2]:='\slshape\rightmark'; end;
  for I:=0 to 2 do begin Heads[I+3]:=Heads[2-I]; Feet[I]:=''; Feet[I+3]:=''; end;
  Feet[1]:='\rmfamily\thepage'; Feet[4]:=Feet[1]; Named:=TStringList.Create; Named.NameValueSeparator:=#1;
  try
    Parse(Source,0);
    I:=Named.IndexOfName(Style);
    if (I>=0) and not UseFancy then begin Parse(Named.ValueFromIndex[I],1); UseFancy:=True; end;
    N:=EnsureRange(Int64(Page)+PageBase-1,-9999,9999);
    Result.Number:=IntToStr(N);
    if (Numbering='roman') or (Numbering='Roman') then begin
      Result.Number:=''; N:=Max(0,N);
      for I:=0 to High(RomanValue) do while N>=RomanValue[I] do begin Result.Number:=Result.Number+RomanText[I]; Dec(N,RomanValue[I]); end;
      if Numbering='roman' then Result.Number:=LowerCase(Result.Number);
    end else if (Numbering='alph') or (Numbering='Alph') then begin
      Result.Number:=''; if (N>=1) and (N<=26) then begin Result.Number:=Chr(Ord('a')+N-1); if Numbering='Alph' then Result.Number:=UpperCase(Result.Number); end;
    end else if Numbering='gobble' then Result.Number:='';
    PageNumber:=Result.Number;
    if not UseFancy and (Style='plain') then begin Result.Footer[1]:=Result.Number; Result.HeadRule:=0; Result.FootRule:=0; end
    else if not UseFancy and (Style='empty') then begin Result.HeadRule:=0; Result.FootRule:=0; end
    else if not UseFancy and ((Style='headings') or (Style='myheadings')) then begin
      Result.HeadRule:=0; Result.FootRule:=0; Result.Header[2]:=Result.Number;
      if TwoSided and not Odd(Page) then begin Result.Header[0]:=Result.Number; Result.Header[2]:='\slshape '+Expand(LMark); end
      else begin if RMark='' then RMark:=LMark; Result.Header[0]:='\slshape '+Expand(RMark); end;
    end else begin
      N:=0; if TwoSided and not Odd(Page) then N:=3;
      for I:=0 to 2 do begin Result.Header[I]:=Expand(Heads[N+I]); Result.Footer[I]:=Expand(Feet[N+I]); end;
    end;
  finally Named.Free; end;
end;
end.
