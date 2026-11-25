unit TikZGeometry;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses PlotGeometry;
type
  TTikZPoints=array of TPlotPoint;
  TTikZNumbers=array of Double;
function PathIntersections(const A,B:TTikZPoints):TTikZPoints;
function DecoratedPath(const Points:TTikZPoints; const Name:string; Amplitude,SegmentLength:Double; Mirror:Boolean):TTikZPoints;
procedure BoxStatistics(const Data:TTikZNumbers; out Summary:TTikZNumbers; out Outliers:TTikZNumbers;
  const Estimator:string='legacy'; LowerQuantile:Double=0.25; UpperQuantile:Double=0.75; WhiskerRange:Double=1.5);
implementation
uses Math, SysUtils;
function PathIntersections(const A,B:TTikZPoints):TTikZPoints;
var I,J,K,N:Integer; D,T,U,X,Y:Double; P:TPlotPoint; Duplicate:Boolean;
begin
  Result:=nil;
  for I:=1 to Min(High(A),2048) do for J:=1 to Min(High(B),2048) do begin
    X:=B[J-1].X-A[I-1].X; Y:=B[J-1].Y-A[I-1].Y;
    D:=(A[I].X-A[I-1].X)*(B[J].Y-B[J-1].Y)-(A[I].Y-A[I-1].Y)*(B[J].X-B[J-1].X);
    if Abs(D)<1e-12 then Continue;
    T:=(X*(B[J].Y-B[J-1].Y)-Y*(B[J].X-B[J-1].X))/D;
    U:=(X*(A[I].Y-A[I-1].Y)-Y*(A[I].X-A[I-1].X))/D;
    if (T< -1e-9) or (T>1+1e-9) or (U< -1e-9) or (U>1+1e-9) then Continue;
    P:=Default(TPlotPoint); P.X:=A[I-1].X+T*(A[I].X-A[I-1].X); P.Y:=A[I-1].Y+T*(A[I].Y-A[I-1].Y);
    Duplicate:=False; for K:=0 to High(Result) do if Hypot(P.X-Result[K].X,P.Y-Result[K].Y)<1e-7 then begin Duplicate:=True; Break; end;
    if Duplicate then Continue; N:=Length(Result); if N>=256 then Exit; SetLength(Result,N+1); Result[N]:=P;
  end;
end;
function DecoratedPath(const Points:TTikZPoints; const Name:string; Amplitude,SegmentLength:Double; Mirror:Boolean):TTikZPoints;
var I,J,N,K:Integer; Length,Total,Offset,T,S,Along,Across,DX,DY,Envelope:Double; P:TPlotPoint;
begin
  Result:=nil; if System.Length(Points)<2 then Exit(Points);
  SegmentLength:=Max(0.1,SegmentLength); if Mirror then Amplitude:=-Amplitude;
  Total:=0; for I:=1 to High(Points) do Total:=Total+Hypot(Points[I].X-Points[I-1].X,Points[I].Y-Points[I-1].Y);
  Offset:=0;
  for I:=1 to High(Points) do begin
    DX:=Points[I].X-Points[I-1].X; DY:=Points[I].Y-Points[I-1].Y; Length:=Hypot(DX,DY); if Length<1e-10 then Continue;
    N:=Max(2,Min(2048,Ceil(Length/SegmentLength*24)));
    for J:=0 to N do begin
      if (I>1) and (J=0) then Continue; T:=J/N; S:=Offset+T*Length; Along:=0; Across:=0;
      if Name='brace' then begin
        T:=S/Max(1e-10,Total);
        { Rounded shoulders and the central cusp of PGF's brace decoration. }
        if T<0.1 then Across:=Amplitude*Sin(T/0.1*Pi/2)
        else if T>0.9 then Across:=Amplitude*Sin((1-T)/0.1*Pi/2)
        else if T<0.5 then Across:=Amplitude*(1+Power((T-0.1)/0.4,8))
        else Across:=Amplitude*(1+Power((0.9-T)/0.4,8));
      end else begin
        Envelope:=Min(1.0,Min(S,Total-S)/(SegmentLength/2));
        if Name='zigzag' then Across:=Amplitude*(2/Pi)*ArcSin(Sin(2*Pi*S/SegmentLength))*Envelope
        else begin Across:=Amplitude*Sin(2*Pi*S/SegmentLength)*Envelope;
          if Name='coil' then Along:=Amplitude*0.55*(1-Cos(2*Pi*S/SegmentLength))*Envelope;
        end;
      end;
      T:=J/N; P:=Points[I-1]; P.X:=P.X+T*DX+(Along*DX-Across*DY)/Length; P.Y:=P.Y+T*DY+(Along*DY+Across*DX)/Length;
      K:=System.Length(Result); if K>=8192 then Exit; SetLength(Result,K+1); Result[K]:=P;
    end;
    Offset:=Offset+Length;
  end;
end;
procedure BoxStatistics(const Data:TTikZNumbers; out Summary:TTikZNumbers; out Outliers:TTikZNumbers;
  const Estimator:string; LowerQuantile,UpperQuantile,WhiskerRange:Double);
var Values:TTikZNumbers; I,N:Integer; V,LowerFence,UpperFence:Double;
  procedure Sort(L,R:Integer);
  var I,J:Integer; Pivot,Swap:Double;
  begin
    I:=L; J:=R; Pivot:=Values[(L+R) div 2];
    repeat
      while Values[I]<Pivot do Inc(I); while Values[J]>Pivot do Dec(J);
      if I<=J then begin Swap:=Values[I]; Values[I]:=Values[J]; Values[J]:=Swap; Inc(I); Dec(J); end;
    until I>J;
    if L<J then Sort(L,J); if I<R then Sort(I,R);
  end;
  function At(Index:Integer):Double;
  begin Result:=Values[EnsureRange(Index,1,Length(Values))-1]; end;
  function Quantile(P:Double):Double;
  var H:Double; K:Integer;
  begin
    H:=Length(Values)*P;
    { PGFPlots' legacy estimator differs from R7/Excel, even at the median. }
    if (Estimator='') or (Estimator='legacy') then begin
      K:=Floor(H); Result:=At(K); if H>K then Result:=(Result+At(K+1))/2; Exit;
    end;
    if Estimator='R1' then Exit(At(Ceil(H)));
    if Estimator='R2' then Exit((At(Ceil(H))+At(Floor(H+1)))/2);
    if Estimator='R3' then Exit(At(Floor(H+0.5)));
    if Estimator='R5' then H:=H+0.5
    else if Estimator='R6' then H:=(Length(Values)+1)*P
    else if (Estimator='R7') or (Estimator='Excel') then H:=(Length(Values)-1)*P+1
    else if Estimator='R8' then H:=(Length(Values)+1/3)*P+1/3
    else if Estimator='R9' then H:=(Length(Values)+1/4)*P+3/8;
    K:=Floor(H); Result:=At(K)+(At(K+1)-At(K))*(H-K);
  end;
begin
  Summary:=nil; Outliers:=nil; if Length(Data)=0 then Exit;
  Values:=Copy(Data); Sort(0,High(Values));
  SetLength(Summary,5); Summary[1]:=Quantile(LowerQuantile); Summary[2]:=Quantile(0.5); Summary[3]:=Quantile(UpperQuantile);
  LowerFence:=Summary[1]-WhiskerRange*(Summary[3]-Summary[1]); UpperFence:=Summary[3]+WhiskerRange*(Summary[3]-Summary[1]);
  I:=0; while (I<Length(Values)-1) and (Values[I]<LowerFence) do Inc(I); Summary[0]:=Values[I];
  I:=Length(Values)-1; while (I>0) and (Values[I]>UpperFence) do Dec(I); Summary[4]:=Values[I];
  for V in Values do if (V<Summary[0]) or (V>Summary[4]) then begin N:=Length(Outliers); SetLength(Outliers,N+1); Outliers[N]:=V; end;
end;
end.
