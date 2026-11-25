unit TeXLists;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type TNativeListOptions=record
  LeftMargin,LabelSep,TopSep,ItemSep,Parsep,LabelText:string;
  Start:Integer;
end;
function NativeListOptions(const Context,Prefix,Name:string; Depth:Integer):TNativeListOptions;
function NativeListLabel(const Template:string; Number:Integer):string;
implementation
uses Classes, SysUtils, Math, TeXMacros, TeXSectioning, TikZModel;
function NativeListOptions(const Context,Prefix,Name:string; Depth:Integer):TNativeListOptions;
var P,Q:Integer; Cmd,Selectors,Value,Item:string; Applies:Boolean; Parts:TStringList;
  procedure Apply(const Options:string);
  var Entry:TDiagramOption; V:string; P:Integer;
  begin
    for Entry in DiagramOptions(Options) do begin
      V:=Entry.Value; P:=1; if Copy(V,1,1)='{' then V:=ReadTeXGroup(V,P,'{','}');
      case Entry.Name of
        'nosep':begin Result.TopSep:='0pt'; Result.ItemSep:='0pt'; Result.Parsep:='0pt'; end;
        'noitemsep':begin Result.ItemSep:='0pt'; Result.Parsep:='0pt'; end;
        'topsep':Result.TopSep:=V; 'itemsep':Result.ItemSep:=V; 'parsep':Result.Parsep:=V;
        'leftmargin':if (V<>'*') and (V<>'!') then Result.LeftMargin:=V;
        'labelsep':Result.LabelSep:=V; 'label':Result.LabelText:=V;
        'start':Result.Start:=EnsureRange(StrToIntDef(V,1),-1000000,1000000);
      end;
    end;
  end;
begin
  Result:=Default(TNativeListOptions); Result.Start:=1; P:=1; Parts:=TStringList.Create;
  try
    Parts.StrictDelimiter:=True; Parts.Delimiter:=',';
    while P<=Length(Context) do begin
      if Context[P]='%' then begin while (P<=Length(Context)) and (Context[P]<>#10) do Inc(P); Continue; end;
      if Context[P]<>'\' then begin Inc(P); Continue; end;
      Q:=P; if ReadTeXDefinition(Context,Q) then begin P:=Q; Continue; end;
      Cmd:=ReadTeXCommand(Context,P); if Cmd<>'setlist' then Continue;
      if Copy(Context,P,1)='*' then Inc(P);
      Selectors:=ReadTeXGroup(Context,P,'[',']'); Value:=ReadTeXGroup(Context,P,'{','}'); Applies:=True;
      Parts.DelimitedText:=Selectors;
      for Item in Parts do if Trim(Item)<>'' then
        Applies:=Applies and ((Trim(Item)=Name) or (StrToIntDef(Trim(Item),-1)=Depth+1));
      if Applies then Apply(Value);
    end;
    P:=1; ReadTeXCommand(Prefix,P); ReadTeXGroup(Prefix,P,'{','}'); Apply(ReadTeXGroup(Prefix,P,'[',']'));
  finally Parts.Free; end;
end;
function NativeListLabel(const Template:string; Number:Integer):string;
var P,A:Integer; Cmd:string;
begin
  Result:=''; P:=1;
  while P<=Length(Template) do begin
    if Template[P]<>'\' then begin Result:=Result+Template[P]; Inc(P); Continue; end;
    A:=P; Cmd:=ReadTeXCommand(Template,P);
    if (Copy(Template,P,1)='*') and ((Cmd='arabic') or (Cmd='alph') or (Cmd='Alph') or (Cmd='roman') or (Cmd='Roman')) then begin
      Inc(P); Result:=Result+FormatTeXCounter(Number,Cmd);
    end else if Cmd='textbullet' then Result:=Result+#$E2#$80#$A2
    else Result:=Result+Copy(Template,A,P-A);
  end;
end;
end.
