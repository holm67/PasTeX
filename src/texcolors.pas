unit TeXColors;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Graphics;
function DocumentColor(const Name,Model,Context:string):TColor;
implementation
uses Classes, SysUtils, Math, TeXMacros, PlotColors;
var Definitions:TStringList; LastContext:string;
function Number(const Text:string):Double;
var Format:TFormatSettings;
begin
  Format:=DefaultFormatSettings; Format.DecimalSeparator:='.'; Result:=StrToFloatDef(Trim(Text),0,Format);
  if IsNan(Result) or IsInfinite(Result) then Result:=0;
end;
function ModelColor(const Model,Value:string):TColor;
var Parts:TStringList; R,G,B,K,H,S,V,F,Low,Down,Up:Double; N:LongInt;
  function Part(I:Integer):Double;
  begin Result:=0; if I<Parts.Count then Result:=Number(Parts[I]); end;
begin
  if Model='HTML' then begin N:=StrToIntDef('$'+Value,0); Exit(RGBToColor(N shr 16,(N shr 8) and 255,N and 255)); end;
  Parts:=TStringList.Create;
  try
    Parts.StrictDelimiter:=True; Parts.Delimiter:=','; Parts.DelimitedText:=Value;
    R:=Part(0); G:=Part(1); B:=Part(2);
    if Model='RGB' then begin R:=R/255; G:=G/255; B:=B/255; end
    else if (Model='gray') or (Model='Gray') then begin if Model='Gray' then R:=R/15; G:=R; B:=R; end
    else if Model='cmy' then begin R:=1-R; G:=1-G; B:=1-B; end
    else if (Model='hsb') or (Model='Hsb') or (Model='HSB') then begin
      if Model='Hsb' then R:=R/360
      else if Model='HSB' then begin R:=R/240; G:=G/240; B:=B/240; end;
      H:=Frac(R); if H<0 then H:=H+1; H:=H*6; N:=Trunc(H); F:=H-N;
      S:=EnsureRange(G,0.0,1.0); V:=EnsureRange(B,0.0,1.0);
      Low:=V*(1-S); Down:=V*(1-S*F); Up:=V*(1-S*(1-F));
      case N of
        0:begin R:=V; G:=Up; B:=Low; end; 1:begin R:=Down; G:=V; B:=Low; end;
        2:begin R:=Low; G:=V; B:=Up; end; 3:begin R:=Low; G:=Down; B:=V; end;
        4:begin R:=Up; G:=Low; B:=V; end; else begin R:=V; G:=Low; B:=Down; end;
      end;
    end
    else if Model='cmyk' then begin K:=Part(3); R:=1-Min(1,R+K); G:=1-Min(1,G+K); B:=1-Min(1,B+K); end;
    Result:=RGBToColor(Round(255*EnsureRange(R,0.0,1.0)),Round(255*EnsureRange(G,0.0,1.0)),Round(255*EnsureRange(B,0.0,1.0)));
  finally Parts.Free; end;
end;
function Resolve(const Value:string; Depth:Integer=0):TColor;
var P:Integer; Name,Rest,Other:string; A,B:TColor; Ratio:Double;
begin
  if Depth>16 then Exit(clBlack);
  Name:=Trim(Value); P:=Pos('!',Name); Rest:='';
  if P>0 then begin Rest:=Copy(Name,P+1,MaxInt); Name:=Copy(Name,1,P-1); end;
  Other:=Definitions.Values[Name]; if Other<>'' then A:=Resolve(Other,Depth+1) else A:=NamedColor(Name);
  if Rest='' then Exit(A);
  P:=Pos('!',Rest); Other:='white';
  if P>0 then begin Other:=Copy(Rest,P+1,MaxInt); Rest:=Copy(Rest,1,P-1); end;
  Ratio:=EnsureRange(Number(Rest)/100,0.0,1.0); B:=ColorToRGB(Resolve(Other,Depth+1)); A:=ColorToRGB(A);
  Result:=RGBToColor(Round((A and 255)*Ratio+(B and 255)*(1-Ratio)),
    Round(((A shr 8) and 255)*Ratio+((B shr 8) and 255)*(1-Ratio)),
    Round(((A shr 16) and 255)*Ratio+((B shr 16) and 255)*(1-Ratio)));
end;
function Hex(Color:TColor):string;
begin Color:=ColorToRGB(Color); Result:='#'+IntToHex(Color and 255,2)+IntToHex((Color shr 8) and 255,2)+IntToHex((Color shr 16) and 255,2); end;
function DocumentColor(const Name,Model,Context:string):TColor;
var P,Q:Integer; Cmd,Key,Space,Value:string;
begin
  if Definitions=nil then begin Definitions:=TStringList.Create; Definitions.CaseSensitive:=True; end;
  if Context<>LastContext then begin
    LastContext:=Context; Definitions.Clear; P:=1;
    while P<=Length(Context) do begin
      SkipTeXSpace(Context,P); if P>Length(Context) then Break;
      if Context[P]<>'\' then begin Inc(P); Continue; end;
      Q:=P; if ReadTeXDefinition(Context,Q) or SkipTeXLiteral(Context,Q) then begin P:=Q; Continue; end;
      Cmd:=ReadTeXCommand(Context,P);
      if (Cmd='definecolor') or (Cmd='providecolor') then begin
        ReadTeXGroup(Context,P,'[',']'); Key:=ReadTeXGroup(Context,P,'{','}');
        Space:=ReadTeXGroup(Context,P,'{','}'); Value:=ReadTeXGroup(Context,P,'{','}');
        if (Cmd='definecolor') or (Definitions.IndexOfName(Key)<0) then Definitions.Values[Key]:=Hex(ModelColor(Space,Value));
      end else if Cmd='colorlet' then begin
        ReadTeXGroup(Context,P,'[',']'); Key:=ReadTeXGroup(Context,P,'{','}');
        ReadTeXGroup(Context,P,'[',']'); Value:=ReadTeXGroup(Context,P,'{','}');
        Definitions.Values[Key]:=Hex(Resolve(Value));
      end;
    end;
  end;
  if (Model<>'') and (Model<>'named') then Result:=ModelColor(Model,Name) else Result:=Resolve(Name);
end;
finalization
  Definitions.Free;
end.
