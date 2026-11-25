unit TeXRules;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type TTeXRule=record Kind,Width,Height,Depth,RaiseBy,Pattern,Alignment:string; end;
function ReadTeXRule(const Source:string; out Rule:TTeXRule):Boolean;
function TeXRuleSource(const Rule:TTeXRule):string;
implementation
uses SysUtils, TeXMacros;
function ReadTeXRule(const Source:string; out Rule:TTeXRule):Boolean;
var P:Integer; Key,Value:string;
begin
  Rule:=Default(TTeXRule); P:=1; Rule.Kind:=ReadTeXCommand(Source,P);
  Result:=(Rule.Kind='hrule') or (Rule.Kind='vrule') or (Rule.Kind='rule') or (Rule.Kind='hdashrule');
  if not Result then Exit;
  if (Rule.Kind='hrule') or (Rule.Kind='vrule') then begin
    while ReadTeXRuleDimension(Source,P,Key,Value) do
      case Key of 'width':Rule.Width:=Value; 'height':Rule.Height:=Value; 'depth':Rule.Depth:=Value; end;
  end else begin
    Rule.RaiseBy:=ReadTeXGroup(Source,P,'[',']');
    if Rule.Kind='hdashrule' then Rule.Alignment:=ReadTeXGroup(Source,P,'[',']');
    Rule.Width:=ReadTeXGroup(Source,P,'{','}'); Rule.Height:=ReadTeXGroup(Source,P,'{','}');
    if Rule.Kind='hdashrule' then Rule.Pattern:=ReadTeXGroup(Source,P,'{','}');
    Result:=(Trim(Rule.Width)<>'') and (Trim(Rule.Height)<>'');
  end;
  Result:=Result and (Trim(Copy(Source,P,MaxInt))='');
end;
function TeXRuleSource(const Rule:TTeXRule):string;
begin
  Result:='\'+Rule.Kind;
  if (Rule.Kind='hrule') or (Rule.Kind='vrule') then begin
    if Trim(Rule.Width)<>'' then Result:=Result+' width '+Trim(Rule.Width);
    if Trim(Rule.Height)<>'' then Result:=Result+' height '+Trim(Rule.Height);
    if Trim(Rule.Depth)<>'' then Result:=Result+' depth '+Trim(Rule.Depth);
  end else begin
    if (Trim(Rule.RaiseBy)<>'') or (Rule.Alignment<>'') then begin
      if Trim(Rule.RaiseBy)='' then Result:=Result+'[0pt]' else Result:=Result+'['+Trim(Rule.RaiseBy)+']';
    end;
    if (Rule.Kind='hdashrule') and (Rule.Alignment<>'') then Result:=Result+'['+Rule.Alignment+']';
    Result:=Result+'{'+Trim(Rule.Width)+'}{'+Trim(Rule.Height)+'}';
    if Rule.Kind='hdashrule' then Result:=Result+'{'+Trim(Rule.Pattern)+'}';
  end;
end;
end.
