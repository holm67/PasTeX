unit TeXFontFeatures;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
function NativeFontFeatures(const Options,Directory:string):string;
implementation
uses Classes, SysUtils, StrUtils, TeXMacros, TeXPackageSources;
var Rules:TStringList; RuleSource:string;
procedure LoadRules(const Directory:string);
var Source,Command,Group,Name,Tag,Added,Removed:string; P,Q:Integer;
begin
  Source:=ReadTeXSource(ResolveTeXSource('fontspec-xetex.sty',Directory));
  if RuleSource=Source then Exit; RuleSource:=Source; Rules.Clear;
  for Command in TStringArray.Create('\__fontspec_define_opentype_onoffreset:nnnnn',
    '\__fontspec_define_opentype_feature:nnnnn','\__fontspec_define_opentype_onreset:nnnnn') do begin
    P:=1;
    repeat
      Q:=PosEx(Command,Source,P); if Q=0 then Break; P:=Q+Length(Command);
      Group:=ReadTeXGroup(Source,P,'{','}'); Name:=ReadTeXGroup(Source,P,'{','}');
      Tag:=ReadTeXGroup(Source,P,'{','}'); Added:=ReadTeXGroup(Source,P,'{','}'); Removed:=ReadTeXGroup(Source,P,'{','}');
      if (Group='') or (Name='') or (Pos('#',Group+Name+Added+Removed)>0) then Continue;
      if Pos('onoffreset',Command)>0 then begin
        Rules.Values[Group+'/'+Name+'Off']:='-'+Added+'|'; Rules.Values[Group+'/No'+Name]:='-'+Added+'|';
        Rules.Values[Group+'/'+Name+'Reset']:='|+'+Added+',-'+Added; Added:='+'+Added;
      end else if Pos('onreset',Command)>0 then Rules.Values[Group+'/'+Name+'Reset']:='|'+Added;
      Rules.Values[Group+'/'+Name]:=Added+'|'+Removed;
    until False;
  end;
  Command:='\aliasfontfeatureoption'; P:=1;
  repeat
    Q:=PosEx(Command,Source,P); if Q=0 then Break; P:=Q+Length(Command);
    Group:=ReadTeXGroup(Source,P,'{','}'); Name:=ReadTeXGroup(Source,P,'{','}'); Tag:=ReadTeXGroup(Source,P,'{','}');
    if Rules.IndexOfName(Group+'/'+Name)>=0 then Rules.Values[Group+'/'+Tag]:=Rules.Values[Group+'/'+Name];
  until False;
  Rules.Values['Ligatures/TeX']:='+tlig|'; Rules.Values['Ligatures/TeXOff']:='-tlig|';
  Rules.Values['Ligatures/TeXReset']:='|+tlig,-tlig';
end;
function NativeFontFeatures(const Options,Directory:string):string;
var Features:TStringList; P,Q,A,B,I,N:Integer; Key,Value,Spec,Rule,Setting:string;
  function Unbrace(const S:string):string;
  var P:Integer;
  begin Result:=Trim(S); if Copy(Result,1,1)='{' then begin P:=1; Result:=ReadTeXGroup(Result,P,'{','}'); end; end;
  procedure Change(const Codes:string; Remove:Boolean);
  var P,Q,A,I:Integer; Code,Tag,Value:string;
  begin
    P:=1;
    while P<=Length(Codes) do begin
      Q:=PosEx(',',Codes,P); if Q=0 then Q:=Length(Codes)+1;
      Code:=Trim(Copy(Codes,P,Q-P)); P:=Q+1; Value:='1';
      if Copy(Code,1,1)='-' then begin Delete(Code,1,1); Value:='0'; end
      else if Copy(Code,1,1)='+' then Delete(Code,1,1);
      A:=Pos('=',Code); Tag:=Code;
      if A>0 then begin Tag:=Trim(Copy(Code,1,A-1)); Value:=Trim(Copy(Code,A+1,MaxInt)); end;
      if (Tag='mapping') and (Value='tex-text') then begin Tag:='tlig'; Value:='1'; end;
      if Length(Tag)<>4 then Continue;
      if Remove then begin
        I:=Features.IndexOfName(Tag); if (I>=0) and (Features.ValueFromIndex[I]=Value) then Features.Delete(I);
      end else Features.Values[Tag]:=Value;
    end;
  end;
begin
  LoadRules(Directory); Features:=TStringList.Create; Features.CaseSensitive:=True;
  try
    P:=1;
    while P<=Length(Options) do begin
      Q:=TopLevelDelimiter(Options,',',P); if Q=0 then Q:=Length(Options)+1;
      Spec:=Trim(Copy(Options,P,Q-P)); P:=Q+1; A:=TopLevelDelimiter(Spec,'='); if A=0 then Continue;
      Key:=Trim(Copy(Spec,1,A-1)); Value:=Unbrace(Copy(Spec,A+1,MaxInt));
      if Key='RawFeature' then begin Change(Value,False); Continue; end;
      if Key='Mapping' then begin if Value='tex-text' then Change('+tlig',False); Continue; end;
      A:=1;
      while A<=Length(Value) do begin
        B:=TopLevelDelimiter(Value,',',A); if B=0 then B:=Length(Value)+1;
        Setting:=Trim(Copy(Value,A,B-A)); A:=B+1; Rule:=Rules.Values[Key+'/'+Setting];
        I:=Pos('|',Rule);
        if I>0 then begin Change(Copy(Rule,I+1,MaxInt),True); Change(Copy(Rule,1,I-1),False); end
        else if (Key='StylisticSet') or (Key='Style') then begin
          N:=StrToIntDef(Setting,0); if (N>=1) and (N<=99) then Change(Format('ss%.2d=1',[N]),False);
        end;
      end;
    end;
    Result:=''; for I:=0 to Features.Count-1 do begin if I>0 then Result:=Result+','; Result:=Result+Features[I]; end;
  finally Features.Free; end;
end;
initialization
  Rules:=TStringList.Create; Rules.CaseSensitive:=True;
finalization
  Rules.Free;
end.
