unit AddonContext;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
function ListingAt(const Source:string; Offset:Integer; out First,Finish:Integer; out Code,Language:string):Boolean;
implementation
uses Classes, SysUtils, StrUtils, TeXMacros, ExtensionSyntax;
function ListingAt(const Source:string; Offset:Integer; out First,Finish:Integer; out Code,Language:string):Boolean;
var P,Q,A,B:Integer; Options,Name,Value,EnvironmentName,Ending:string; Entries:TStringList;
begin
  Result:=False; P:=1; Code:=''; Language:=''; First:=0; Finish:=0;
  while P<=Length(Source) do begin
    A:=PosEx('\begin{',Source,P); if A=0 then Exit; Q:=A+Length('\begin'); EnvironmentName:=ReadTeXGroup(Source,Q,'{','}'); P:=Q;
    Language:=ExtensionCodeLanguage(EnvironmentName);
    if (EnvironmentName<>'lstlisting') and (Language='') then Continue;
    Options:=''; if EnvironmentName='lstlisting' then Options:=ReadTeXGroup(Source,Q,'[',']');
    Ending:='\end{'+EnvironmentName+'}'; B:=PosEx(Ending,Source,Q); if B=0 then Exit;
    P:=B+Length(Ending);
    if (Offset<A-1) or (Offset>P) then Continue;
    First:=A-1; Finish:=P-1; Code:=Trim(Copy(Source,Q,B-Q)); Entries:=TStringList.Create;
    try Entries.Delimiter:=','; Entries.StrictDelimiter:=True; Entries.DelimitedText:=Options;
      for Value in Entries do begin Name:=Trim(Copy(Value,1,Pos('=',Value)-1));
        if Name='language' then Language:=LowerCase(Trim(Copy(Value,Pos('=',Value)+1,MaxInt)));
      end;
    finally Entries.Free; end;
    Exit(True);
  end;
end;
end.
