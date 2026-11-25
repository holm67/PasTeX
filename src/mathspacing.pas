unit MathSpacing;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type TTeXFill=record Stretch,Shrink:Double; Order,ShrinkOrder,Leader:Byte; Keep:Boolean; end;
function ReadHorizontalFill(const Source:string; out Fill:TTeXFill):Boolean;
function ReadMathSpace(const Source:string; out Width:Double; out Units:string):Boolean;
function ReadVerticalSpace(const Source:string; out Width:Double; out Units:string):Boolean;
function SpaceSource(Width:Double; const Units:string):string;
implementation
uses SysUtils, Math, TeXMacros;
function ReadHorizontalFill(const Source:string; out Fill:TTeXFill):Boolean;
var P,Q:Integer; Command,Value:string; F:TFormatSettings;
begin
  Fill:=Default(TTeXFill); P:=1; Command:=ReadTeXCommand(Source,P); Result:=True;
  Fill.Order:=1; Fill.Stretch:=1;
  case Command of
    'hfil':;
    'hfill':Fill.Order:=2;
    'hfilneg':Fill.Stretch:=-1;
    'hss':begin Fill.Shrink:=1; Fill.ShrinkOrder:=1; end;
    'hrulefill','dotfill':begin Fill.Order:=2; Fill.Keep:=True; Fill.Leader:=1+Ord(Command='dotfill'); end;
    'hspace':begin
      if Copy(Source,P,1)='*' then begin Inc(P); Fill.Keep:=True; end;
      Value:=Trim(ReadTeXGroup(Source,P,'{','}')); Q:=1; Command:=ReadTeXCommand(Value,Q);
      if Command='fill' then Fill.Order:=2
      else if Command='stretch' then begin
        F:=DefaultFormatSettings; F.DecimalSeparator:='.';
        Result:=TryStrToFloat(ReadTeXGroup(Value,Q,'{','}'),Fill.Stretch,F); Fill.Order:=2;
      end else Result:=False;
      Result:=Result and (Trim(Copy(Value,Q,MaxInt))='');
    end;
    else Result:=False;
  end;
  Result:=Result and (Trim(Copy(Source,P,MaxInt))='') and
    not IsNan(Fill.Stretch) and not IsInfinite(Fill.Stretch) and (Abs(Fill.Stretch)<=1000);
end;
function ReadMathSpace(const Source:string; out Width:Double; out Units:string):Boolean;
var P,I:Integer; Cmd,Value:string; F:TFormatSettings;
begin
  Result:=True; P:=1; Cmd:=ReadTeXCommand(Source,P); Units:='mu'; Width:=0;
  case Cmd of
    ',','thinspace':Width:=3;
    ':','>','medspace':Width:=4;
    ';','thickspace':Width:=5;
    '!','negthinspace':Width:=-3;
    'negmedspace':Width:=-4; 'negthickspace':Width:=-5;
    'enspace','enskip':Width:=9;
    'quad':begin Width:=1; Units:='em'; end;
    'qquad':begin Width:=2; Units:='em'; end;
    ' ','space':Width:=6;
    'hspace','mspace':begin
      if (Cmd='hspace') and (Copy(Source,P,1)='*') then Inc(P);
      Value:=Trim(ReadTeXGroup(Source,P,'{','}')); I:=Length(Value);
      while (I>0) and (Value[I] in ['a'..'z']) do Dec(I);
      Units:=Copy(Value,I+1,MaxInt); F:=DefaultFormatSettings; F.DecimalSeparator:='.';
      Result:=TryStrToFloat(Trim(Copy(Value,1,I)),Width,F) and
        ((Units='em') or (Units='ex') or (Units='pt') or (Units='mu'));
      if (Cmd='mspace') and (Units<>'mu') then Result:=False;
      if (Cmd='hspace') and (Units='mu') then Result:=False;
    end;
    else Result:=False;
  end;
  Result:=Result and (Trim(Copy(Source,P,MaxInt))='') and not IsNan(Width) and not IsInfinite(Width) and (Abs(Width)<=1000);
end;
function ReadVerticalSpace(const Source:string; out Width:Double; out Units:string):Boolean;
var P,I:Integer; Command,Value:string; F:TFormatSettings;
begin
  P:=1; Command:=ReadTeXCommand(Source,P); Width:=0; Units:='em'; Result:=True;
  case Command of
    'smallskip':Width:=0.3;
    'medskip':Width:=0.6;
    'bigskip':Width:=1.2;
    'vspace','vskip':begin
      if Copy(Source,P,1)='*' then Inc(P); SkipTeXSpace(Source,P);
      if Copy(Source,P,1)='{' then Value:=Trim(ReadTeXGroup(Source,P,'{','}')) else begin Value:=Trim(Copy(Source,P,MaxInt)); P:=Length(Source)+1; end;
      I:=Length(Value); while (I>0) and (Value[I] in ['a'..'z']) do Dec(I);
      Units:=Copy(Value,I+1,MaxInt); F:=DefaultFormatSettings; F.DecimalSeparator:='.';
      Result:=TryStrToFloat(Copy(Value,1,I),Width,F) and ((Units='pt') or (Units='em') or (Units='ex') or (Units='cm') or (Units='mm') or (Units='in') or (Units='bp'));
    end;
    else Result:=False;
  end;
  Result:=Result and (Trim(Copy(Source,P,MaxInt))='') and not IsNan(Width) and not IsInfinite(Width) and (Abs(Width)<=1000);
end;
function SpaceSource(Width:Double; const Units:string):string;
var F:TFormatSettings;
begin
  F:=DefaultFormatSettings; F.DecimalSeparator:='.';
  if Units='mu' then Result:='\mspace{' else Result:='\hspace{';
  Result:=Result+FloatToStr(Width,F)+Units+'}';
end;
end.
