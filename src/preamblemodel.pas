unit PreambleModel;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Contnrs;
type
  TPackageOption=class
    Name,Options:string;
    constructor Create(const AName,AOptions:string);
  end;
  TPreambleModel=class
  private
    FSource:string;
    FOriginalSignature:string;
    FSpans:array of record Start,Finish,Kind,PackageCount:Integer; end;
    function Signature:string;
  public
    DocumentClassName,ClassOptions:string;
    Packages:TObjectList;
    constructor Create;
    destructor Destroy; override;
    procedure Load(const Source:string);
    function Source:string;
    function PackageIndex(const Name:string):Integer;
    procedure SetPackage(const Name,Options:string);
    procedure RemovePackage(const Name:string);
  end;
implementation
uses TeXMacros;
constructor TPackageOption.Create(const AName,AOptions:string);
begin inherited Create; Name:=AName; Options:=AOptions; end;
constructor TPreambleModel.Create;
begin inherited Create; Packages:=TObjectList.Create(True); end;
destructor TPreambleModel.Destroy;
begin Packages.Free; inherited Destroy; end;
procedure TPreambleModel.Load(const Source:string);
var P,A,N,Depth:Integer; Command,Options,Names:string; Parts:TStringList; Name:string;
begin
  FSource:=Source; Packages.Clear; FSpans:=nil; DocumentClassName:=''; ClassOptions:=''; P:=1; Depth:=0;
  Parts:=TStringList.Create;
  try
    Parts.Delimiter:=','; Parts.StrictDelimiter:=True;
    while P<=Length(Source) do begin
      if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
      if Source[P]='{' then Inc(Depth) else if Source[P]='}' then Dec(Depth);
      if Source[P]<>'\' then begin Inc(P); Continue; end;
      A:=P; if ReadTeXDefinition(Source,P) then Continue;
      if SkipTeXBibResource(Source,P) then Continue;
      Command:=ReadTeXCommand(Source,P);
      if (Depth<>0) or ((Command<>'documentclass') and (Command<>'usepackage') and (Command<>'RequirePackage')) then Continue;
      SkipTeXSpace(Source,P); Options:='';
      if Copy(Source,P,1)='[' then Options:=ReadTeXGroup(Source,P,'[',']');
      SkipTeXSpace(Source,P); if Copy(Source,P,1)<>'{' then Continue;
      Names:=ReadTeXGroup(Source,P,'{','}'); N:=Length(FSpans); SetLength(FSpans,N+1);
      FSpans[N].Start:=A; FSpans[N].Finish:=P; FSpans[N].Kind:=1;
      if Command='documentclass' then begin DocumentClassName:=Names; ClassOptions:=Options; FSpans[N].Kind:=0; end
      else begin Parts.DelimitedText:=Names; FSpans[N].PackageCount:=0;
        for Name in Parts do if Trim(Name)<>'' then begin Packages.Add(TPackageOption.Create(Trim(Name),Options)); Inc(FSpans[N].PackageCount); end;
        if Trim(Names)='' then begin
          Packages.Add(TPackageOption.Create('',Options)); FSpans[N].PackageCount:=1;
        end;
      end;
    end;
  finally Parts.Free; end;
  FOriginalSignature:=Signature;
end;
function TPreambleModel.Signature:string;
var I:Integer; Package:TPackageOption;
begin
  Result:=DocumentClassName+#0+ClassOptions;
  for I:=0 to Packages.Count-1 do begin Package:=TPackageOption(Packages[I]); Result:=Result+#0+Package.Name+#0+Package.Options; end;
end;
function TPreambleModel.Source:string;
var I,P,K,Slots,Remaining,First:Integer; Package:TPackageOption; S:string; HadClass:Boolean;
  function ClassSource:string;
  begin Result:='\documentclass'; if Trim(ClassOptions)<>'' then Result:=Result+'['+ClassOptions+']'; Result:=Result+'{'+DocumentClassName+'}'; end;
  function PackageSource(Index:Integer):string;
  begin Package:=TPackageOption(Packages[Index]); Result:='\usepackage'; if Trim(Package.Options)<>'' then Result:=Result+'['+Package.Options+']'; Result:=Result+'{'+Package.Name+'}'; end;
begin
  if Signature=FOriginalSignature then Exit(FSource);
  Result:=''; P:=1; K:=0; HadClass:=False; Slots:=0;
  for I:=0 to High(FSpans) do if FSpans[I].Kind=1 then Inc(Slots);
  for I:=0 to High(FSpans) do begin
    Result:=Result+Copy(FSource,P,FSpans[I].Start-P);
    if FSpans[I].Kind=0 then begin if DocumentClassName<>'' then Result:=Result+ClassSource; HadClass:=True; end
    else begin
      Dec(Slots); Remaining:=FSpans[I].PackageCount; if Slots=0 then Remaining:=Packages.Count-K; First:=K;
      while (Remaining>0) and (K<Packages.Count) do begin
        if K>First then Result:=Result+LineEnding;
        Result:=Result+PackageSource(K); Inc(K); Dec(Remaining);
      end;
    end;
    P:=FSpans[I].Finish;
  end;
  S:=''; while K<Packages.Count do begin S:=S+PackageSource(K)+LineEnding; Inc(K); end;
  if not HadClass and (DocumentClassName<>'') then Result:=ClassSource+LineEnding+Result;
  Result:=Result+S+Copy(FSource,P,MaxInt);
end;
function TPreambleModel.PackageIndex(const Name:string):Integer;
var I:Integer;
begin Result:=-1; for I:=0 to Packages.Count-1 do if TPackageOption(Packages[I]).Name=Name then Exit(I); end;
procedure TPreambleModel.SetPackage(const Name,Options:string);
var I:Integer;
begin I:=PackageIndex(Name); if I<0 then Packages.Add(TPackageOption.Create(Name,Options)) else TPackageOption(Packages[I]).Options:=Options; end;
procedure TPreambleModel.RemovePackage(const Name:string);
var I:Integer;
begin repeat I:=PackageIndex(Name); if I>=0 then Packages.Delete(I); until I<0; end;
end.
