unit PDFInclusion;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type TPDFPageNumbers=array of Integer;
function PDFPageNumbers(const Selection:string; PageCount:Integer):TPDFPageNumbers;
function ReadPDFInclusion(const Source:string; out FileName,Pages,Options:string):Boolean;
function PDFInclusionSource(const FileName,Pages,Options:string):string;
implementation
uses Classes, SysUtils, Math, TeXMacros, EnvironmentOptions;
function ReadPDFInclusion(const Source:string; out FileName,Pages,Options:string):Boolean;
var P:Integer;
begin
  FileName:=''; Pages:='1'; Options:=''; P:=1; SkipTeXSpace(Source,P);
  Result:=ReadTeXCommand(Source,P)='includepdf'; if not Result then Exit;
  SkipTeXSpace(Source,P); if Copy(Source,P,1)='[' then Options:=ReadTeXGroup(Source,P,'[',']');
  FileName:=ReadTeXGroup(Source,P,'{','}'); Pages:=EnvironmentOption(Options,'pages','1');
end;
function PDFInclusionSource(const FileName,Pages,Options:string):string;
var Value:string;
begin
  Value:=Trim(Pages); if (Value='') or (Value='1') then Value:=''
  else if Copy(Value,1,1)<>'{' then Value:='{'+Value+'}';
  Value:=SetEnvironmentOption(Options,'pages',Value); Result:='\includepdf';
  if Value<>'' then Result:=Result+'['+Value+']'; Result:=Result+'{'+FileName+'}';
end;
function PDFPageNumbers(const Selection:string; PageCount:Integer):TPDFPageNumbers;
var Parts:TStringList; Item,Code:string; P,A,B,Step,N:Integer;
  procedure Add(Page:Integer);
  var N:Integer;
  begin
    if (Page<0) or (Page>PageCount) then Exit;
    N:=Length(Result); if N>=4096 then Exit; SetLength(Result,N+1); Result[N]:=Page;
  end;
  function Page(const Value:string; Default:Integer):Integer;
  begin if Trim(Value)='last' then Result:=PageCount else Result:=StrToIntDef(Trim(Value),Default); end;
begin
  Result:=nil; if PageCount<1 then Exit;
  Code:=Trim(Selection); if Code='' then Code:='1';
  if Copy(Code,1,1)='{' then Code:=Copy(Code,2,Length(Code)-2);
  Parts:=TStringList.Create;
  try
    Parts.StrictDelimiter:=True; Parts.Delimiter:=','; Parts.DelimitedText:=Code;
    for Item in Parts do begin
      if (Trim(Item)='') or (Trim(Item)='{}') then begin Add(0); Continue; end;
      P:=Pos('-',Item);
      if P=0 then Add(Page(Item,-1))
      else begin
        A:=Page(Copy(Item,1,P-1),1); B:=Page(Copy(Item,P+1,MaxInt),PageCount);
        A:=EnsureRange(A,1,PageCount); B:=EnsureRange(B,1,PageCount); Step:=1; if B<A then Step:=-1;
        N:=A;
        repeat Add(N); if (N=B) or (Length(Result)>=4096) then Break; Inc(N,Step); until False;
      end;
    end;
  finally Parts.Free; end;
end;
end.
