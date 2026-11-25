unit TikZGraph;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type
  TTikZGraphNode=record Name,Text,Options:string; Level,Row,First,Last:Integer; HasLabel:Boolean; end;
  TTikZGraphNodes=array of TTikZGraphNode;
  TTikZGraphEdge=record A,B:Integer; Arrow,Reverse,Both:Boolean; end;
  TTikZGraphEdges=array of TTikZGraphEdge;
function ParseTikZGraph(const Source:string; out Nodes:TTikZGraphNodes; out Edges:TTikZGraphEdges):Boolean;
implementation
uses SysUtils, Math, TeXMacros;
type TIndices=array of Integer;
function ParseTikZGraph(const Source:string; out Nodes:TTikZGraphNodes; out Edges:TTikZGraphEdges):Boolean;
var P,Depth:Integer;
  procedure Join(var A:TIndices; const B:TIndices);
  var I,N:Integer;
  begin N:=Length(A); SetLength(A,N+Length(B)); for I:=0 to High(B) do A[N+I]:=B[I]; end;
  function Vertex(Level,Row:Integer):Integer;
  var Start,NameFirst,NameLast,I,N:Integer; Name,Text,Options:string; HasLabel:Boolean;
  begin
    Result:=-1; SkipTeXSpace(Source,P); Start:=P; NameFirst:=P-1;
    if Copy(Source,P,1)='"' then begin Inc(P); Start:=P; while (P<=Length(Source)) and (Source[P]<>'"') do Inc(P); Name:=Copy(Source,Start,P-Start); Inc(P); end
    else begin
      while (P<=Length(Source)) and not (Source[P] in [' ',#9,#10,#13,'{','}',',',';','[','/']) and
        (Copy(Source,P,2)<>'->') and (Copy(Source,P,2)<>'--') and (Copy(Source,P,2)<>'<-') do Inc(P);
      Name:=Copy(Source,Start,P-Start);
    end;
    if Name='' then Exit; Text:=Name; NameLast:=P-1; HasLabel:=False; SkipTeXSpace(Source,P);
    if Copy(Source,P,1)='/' then begin
      HasLabel:=True;
      Inc(P); SkipTeXSpace(Source,P); Start:=P;
      if Copy(Source,P,1)='{' then begin Inc(Start); Text:=ReadTeXGroup(Source,P,'{','}'); end
      else begin while (P<=Length(Source)) and not (Source[P] in [',',';','[','}',#10,#13]) and (Copy(Source,P,2)<>'->') and (Copy(Source,P,2)<>'--') do Inc(P); Text:=Trim(Copy(Source,Start,P-Start)); end;
    end;
    Options:=ReadTeXGroup(Source,P,'[',']');
    for I:=0 to High(Nodes) do if Nodes[I].Name=Name then Exit(I);
    N:=Length(Nodes); if N>=256 then Exit; SetLength(Nodes,N+1);
    Nodes[N].Name:=Name; Nodes[N].Text:=Text; Nodes[N].Options:=Options; Nodes[N].Level:=Level; Nodes[N].Row:=Row;
    Nodes[N].HasLabel:=HasLabel; Nodes[N].First:=Start-1; Nodes[N].Last:=Start-1+Length(Text);
    if not HasLabel then begin Nodes[N].First:=NameFirst; Nodes[N].Last:=NameLast; end; Result:=N;
  end;
  function Sequence(Level,Row:Integer; out First,Last:TIndices; out Width,Height:Integer):Boolean;
  var Current,Next,Head,Tail:TIndices; I,J,N,V,Start,ChainWidth,ChainHeight,ElementWidth,ElementHeight:Integer; Arrow,Reverse,Both:Boolean;
    procedure FinishChain;
    begin
      Join(Last,Current); Current:=nil; Width:=Max(Width,ChainWidth); Inc(Height,ChainHeight);
      ChainWidth:=0; ChainHeight:=0;
    end;
  begin
    Result:=False; First:=nil; Last:=nil; Current:=nil; Width:=0; Height:=0; ChainWidth:=0; ChainHeight:=0;
    Inc(Depth); if Depth>16 then Exit;
    try
      while P<=Length(Source) do begin
        SkipTeXSpace(Source,P); if P>Length(Source) then Break;
        if Source[P]='}' then Break;
        if Source[P] in [',',';'] then begin Inc(P); FinishChain; Continue; end;
        Arrow:=False; Reverse:=False; Both:=False; Start:=P;
        if (Copy(Source,P,2)='->') or (Copy(Source,P,2)='--') or (Copy(Source,P,2)='<-') then begin
          Arrow:=Copy(Source,P,2)<>'--'; Reverse:=Copy(Source,P,2)='<-'; Both:=Copy(Source,P,3)='<->';
          Inc(P,2); if Both then Inc(P); SkipTeXSpace(Source,P);
          if Copy(Source,P,1)='[' then ReadTeXGroup(Source,P,'[',']');
        end;
        Next:=nil;
        if Copy(Source,P,1)='{' then begin
          Inc(P); if not Sequence(Level+ChainWidth,Row+Height,Head,Tail,ElementWidth,ElementHeight) then Exit;
          if Copy(Source,P,1)<>'}' then Exit; Inc(P); Next:=Head;
        end else begin
          V:=Vertex(Level+ChainWidth,Row+Height); if V<0 then Exit;
          SetLength(Next,1); Next[0]:=V; Tail:=Copy(Next); ElementWidth:=1; ElementHeight:=1;
        end;
        if Length(Current)=0 then Join(First,Next);
        for I in Current do for J in Next do begin
          N:=Length(Edges); if N>=1024 then Exit; SetLength(Edges,N+1);
          Edges[N].A:=I; Edges[N].B:=J; Edges[N].Arrow:=Arrow; Edges[N].Reverse:=Reverse; Edges[N].Both:=Both;
        end;
        { TikZ's Cartesian placement sums widths along chains and depths
          across groups; nested groups keep their first chain on the origin. }
        Inc(ChainWidth,ElementWidth); ChainHeight:=Max(ChainHeight,ElementHeight);
        Current:=Tail; if P<=Start then Exit;
      end;
      FinishChain; Result:=Length(First)>0;
    finally Dec(Depth); end;
  end;
var First,Last:TIndices; Width,Height:Integer;
begin Nodes:=nil; Edges:=nil; P:=1; Depth:=0; Result:=Sequence(0,0,First,Last,Width,Height) and (P>Length(Source)); end;
end.
