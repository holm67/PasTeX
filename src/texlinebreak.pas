unit TeXLineBreak;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type
  TTeXInlineItem=record Width,Stretch,Shrink,BreakWidth:Double; Glue,BreakAfter,KeepGlue:Boolean; StretchOrder,ShrinkOrder:Byte; Penalty:Integer; end;
  TTeXInlineItems=array of TTeXInlineItem;
  TTeXLine=record First,Finish:Integer; Ratio:Double; Hyphenated:Boolean; GlueOrder:Byte; end;
  TTeXLines=array of TTeXLine;
function TeXBadness(Amount,Available:Double):Integer;
function BreakTeXLines(const Items:TTeXInlineItems; Width:Double; Ragged:Boolean=False; FirstLineExtra:Double=0):TTeXLines;
implementation
uses Math;
function TeXBadness(Amount,Available:Double):Integer;
var T,S,R:Int64;
begin
  { TeX.web's badness routine uses scaled integers and bounds its cubic
    calculation. The ratio is unchanged when pixels replace TeX points. }
  if Amount<=0 then Exit(0); if Available<=0 then Exit(10000);
  T:=Round(Min(Amount,1E9)*65536); S:=Round(Min(Available,1E9)*65536);
  if T=0 then Exit(0); if S<=0 then Exit(10000);
  if T<=7230584 then R:=(T*297) div S
  else if S>=1663497 then R:=T div (S div 297)
  else R:=T;
  if R>1290 then Exit(10000);
  Result:=(R*R*R+131072) div 262144;
end;
function BreakTeXLines(const Items:TTeXInlineItems; Width:Double; Ragged:Boolean; FirstLineExtra:Double):TTeXLines;
type TState=record Cost,Ratio:Double; Previous,Fit:Integer; GlueOrder:Byte; end;
var Cuts:array of Integer; Totals:array of Double; Stretch,Shrink:array[0..3] of array of Double; States:array of array[0..3] of TState;
    Reachable:array of Boolean;
    I,J,K,C,F,PF,Start,Finish,Last,Pass,Bad,Penalty,BestFit,N,Order,MaxOrder:Integer; Natural,Available,Delta,Ratio,Cost,Best:Double;
    Line:TTeXLine; Valid,EndLine,Monotone:Boolean;
begin
  Result:=nil; N:=Length(Items); if N=0 then Exit;
  MaxOrder:=0;
  for I:=0 to N-1 do MaxOrder:=Max(MaxOrder,Min(3,Max(Items[I].StretchOrder,Items[I].ShrinkOrder)));
  SetLength(Totals,N+1);
  for K:=0 to MaxOrder do begin SetLength(Stretch[K],N+1); SetLength(Shrink[K],N+1); end;
  Cuts:=nil;
  SetLength(Cuts,1); Cuts[0]:=0; Monotone:=True;
  for I:=0 to N-1 do begin
    if (Items[I].Shrink<0) or (Items[I].Width<Items[I].Shrink) or (Items[I].ShrinkOrder>0) then Monotone:=False;
    Totals[I+1]:=Totals[I]+Items[I].Width;
    for K:=0 to MaxOrder do begin
      Stretch[K][I+1]:=Stretch[K][I]; Shrink[K][I+1]:=Shrink[K][I];
      if Items[I].StretchOrder=K then Stretch[K][I+1]:=Stretch[K][I+1]+Items[I].Stretch;
      if Items[I].ShrinkOrder=K then Shrink[K][I+1]:=Shrink[K][I+1]+Items[I].Shrink;
    end;
    if Items[I].BreakAfter and (I<N-1) and (Items[I].Penalty<10000) then begin C:=Length(Cuts); SetLength(Cuts,C+1); Cuts[C]:=I+1; end;
  end;
  C:=Length(Cuts); SetLength(Cuts,C+1); Cuts[C]:=N; SetLength(States,Length(Cuts));
  SetLength(Reachable,Length(Cuts));
  BestFit:=-1;
  for Pass:=0 to 1 do begin
    for I:=0 to High(States) do begin
      Reachable[I]:=False;
      for F:=0 to 3 do begin States[I][F].Cost:=1E100; States[I][F].Previous:=-1; end;
    end;
    States[0][1].Cost:=0; Reachable[0]:=True;
    for I:=1 to High(Cuts) do begin
      Finish:=Cuts[I]; while (Finish>0) and Items[Finish-1].Glue and not Items[Finish-1].KeepGlue do Dec(Finish);
      EndLine:=I=High(Cuts); Penalty:=0; if not EndLine then Penalty:=Items[Cuts[I]-1].Penalty;
      for J:=I-1 downto Max(0,I-256) do begin
        Start:=Cuts[J]; while (Start<Finish) and Items[Start].Glue and not Items[Start].KeepGlue and
          ((Start>0) or (Items[Start].StretchOrder=0)) do Inc(Start);
        if Start>=Finish then Continue;
        Natural:=Totals[Finish]-Totals[Start];
        if not EndLine then Natural:=Natural+Items[Cuts[I]-1].BreakWidth;
        { Earlier starts cannot fit once even maximum shrink is too wide.
          Negative kerns disable this bound; the fallback pass is unchanged. }
        if (Pass=0) and Monotone and
          (Natural-Shrink[0][Finish]+Shrink[0][Start]>Width+Max(0,FirstLineExtra)+1e-7) then Break;
        if not Reachable[J] then Continue;
        Delta:=Width-Natural; if J=0 then Delta:=Delta+FirstLineExtra; Ratio:=0; Order:=0;
        if Delta>=0 then begin
          for K:=MaxOrder downto 1 do if Stretch[K][Finish]-Stretch[K][Start]>0 then begin Order:=K; Break; end;
          Available:=Stretch[Order][Finish]-Stretch[Order][Start];
          if Order>0 then begin
            { TeX appends 0pt plus 1fil at paragraph end. Fill (order 2)
              outranks it; an explicit fil shares the remaining width. }
            if (Order=1) and (EndLine or Ragged) then Available:=Available+1;
            Ratio:=Delta/Available; Bad:=0;
          end else if EndLine or Ragged then Bad:=0
          else begin Bad:=TeXBadness(Delta,Available); if Available>0 then Ratio:=Delta/Available; end;
          F:=1; if Bad>12 then F:=2; if Bad>99 then F:=3;
        end else begin
          for K:=MaxOrder downto 1 do if Shrink[K][Finish]-Shrink[K][Start]>0 then begin Order:=K; Break; end;
          Available:=Shrink[Order][Finish]-Shrink[Order][Start]; Bad:=TeXBadness(-Delta,Available);
          if Available>0 then Ratio:=Delta/Available else Ratio:=-2;
          if Order>0 then Bad:=0 else if Ratio< -1 then Bad:=10001; F:=1; if Bad>12 then F:=0;
        end;
        Valid:=Bad<=2000; if (Pass=0) and not Valid then Continue;
        Cost:=Sqr(10+Min(10000,Bad));
        if Penalty>=0 then Cost:=Cost+Sqr(Penalty) else Cost:=Cost-Sqr(Penalty);
        if Bad>10000 then Cost:=Cost+1E9+Sqr(Delta)*10000;
        for PF:=0 to 3 do begin
          Best:=Cost+States[J][PF].Cost;
          if Abs(F-PF)>1 then Best:=Best+10000;
          if Best<States[I][F].Cost then begin
            States[I][F].Cost:=Best; States[I][F].Previous:=J; States[I][F].Fit:=PF; States[I][F].Ratio:=Ratio;
            States[I][F].GlueOrder:=Order;
            Reachable[I]:=True;
          end;
        end;
      end;
    end;
    Best:=1E100;
    for F:=0 to 3 do if States[High(States)][F].Cost<Best then begin Best:=States[High(States)][F].Cost; BestFit:=F; end;
    if BestFit>=0 then Break;
  end;
  if BestFit<0 then begin SetLength(Result,1); Result[0].First:=0; Result[0].Finish:=N; Exit; end;
  I:=High(Cuts); F:=BestFit;
  while I>0 do begin
    J:=States[I][F].Previous; if J<0 then Break;
    Line.First:=Cuts[J]; Line.Finish:=Cuts[I]; Line.GlueOrder:=States[I][F].GlueOrder; Line.Ratio:=States[I][F].Ratio;
    if Line.GlueOrder=0 then Line.Ratio:=Max(-1,Line.Ratio);
    Line.Hyphenated:=(I<High(Cuts)) and (Items[Cuts[I]-1].BreakWidth>0);
    K:=Length(Result); SetLength(Result,K+1); Result[K]:=Line;
    PF:=States[I][F].Fit; I:=J; F:=PF;
  end;
  Last:=High(Result); for I:=0 to Length(Result) div 2-1 do begin Line:=Result[I]; Result[I]:=Result[Last-I]; Result[Last-I]:=Line; end;
end;
end.
