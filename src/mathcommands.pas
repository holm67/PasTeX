unit MathCommands;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils;
const
  ExtensibleArrows='xrightarrow xleftarrow xleftrightarrow xRightarrow xLeftarrow '+
    'xLeftrightarrow xhookrightarrow xhookleftarrow xmapsto xrightharpoonup '+
    'xrightharpoondown xleftharpoonup xleftharpoondown xrightleftharpoons '+
    'xleftrightharpoons xlongequal xlongrightarrow xlongleftarrow '+
    'xlongleftrightarrow xLongrightarrow xLongleftarrow xLongleftrightarrow';
  CommonMathFunctions='sin cos tan cot sec csc arcsin arccos arctan sinh cosh tanh coth '+
    'log ln lg exp lim limsup liminf sup inf max min det gcd hom ker dim deg arg Pr';
  ReallyWideHatDefinition='\providecommand{\reallywidehat}[1]{\mathpalette\PasTeXWideHat{#1}}'+#10+
    '\providecommand{\PasTeXWideHat}[2]{%'+#10+
    '  \begingroup\sbox0{$#1#2$}%'+#10+
    '  \mathord{\overset{\resizebox{\wd0}{0.45ex}{$\wedge$}}{#1#2}}%'+#10+
    '  \endgroup}'+#10;
function IsExtensibleMathArrow(const Command:string):Boolean;
function MathCommandPackages(const Command:string):string;
procedure MathCommandNames(const Words:string; Dest:TStrings);
implementation
function IsExtensibleMathArrow(const Command:string):Boolean;
begin Result:=(Command<>'') and (Pos(' '+Command+' ',' '+ExtensibleArrows+' ')>0); end;
function MathCommandPackages(const Command:string):string;
begin
  Result:='';
  if Command='reallywidehat' then Exit('amsmath,graphicx');
  if not IsExtensibleMathArrow(Command) then Exit;
  if (Pos('xlong',Command)=1) or (Pos('xLong',Command)=1) then Exit('extarrows');
  if (Command='xrightarrow') or (Command='xleftarrow') then Exit('amsmath');
  Result:='mathtools';
end;
procedure MathCommandNames(const Words:string; Dest:TStrings);
var P,A:Integer;
begin
  P:=1;
  while P<=Length(Words) do begin
    while (P<=Length(Words)) and (Words[P]=' ') do Inc(P); A:=P;
    while (P<=Length(Words)) and (Words[P]<>' ') do Inc(P);
    if P>A then Dest.Add('\'+Copy(Words,A,P-A));
  end;
end;
end.
