unit TeXHyphenation;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type THyphenPoints=array of Integer;
function TeXHyphenPoints(const WordText:string):THyphenPoints;
implementation
uses Classes, SysUtils, Math, TeXFontData, TeXMacros;
type TNode=record Edge:Integer; Weights:array of Byte; end;
     TEdge=record Letter:Char; Child,Next:Integer; end;
var Nodes:array of TNode; Edges:array of TEdge; Loaded:Boolean; Exceptions:TStringList;
function Child(Node:Integer; Letter:Char; Create:Boolean):Integer;
var E,N:Integer;
begin
  E:=Nodes[Node].Edge; while E>=0 do begin if Edges[E].Letter=Letter then Exit(Edges[E].Child); E:=Edges[E].Next; end;
  Result:=-1; if not Create then Exit;
  N:=Length(Nodes); SetLength(Nodes,N+1); Nodes[N].Edge:=-1;
  E:=Length(Edges); SetLength(Edges,E+1); Edges[E].Letter:=Letter; Edges[E].Child:=N;
  Edges[E].Next:=Nodes[Node].Edge; Nodes[Node].Edge:=E; Result:=N;
end;
procedure LoadPatterns;
var Lines,Words:TStringList; Text,Pattern,Letters,Exception:string; P,I,J,N:Integer; Weights:array of Byte;
begin
  if Loaded then Exit; Loaded:=True; SetLength(Nodes,1); Nodes[0].Edge:=-1;
  Lines:=TStringList.Create; Words:=TStringList.Create; Exceptions:=TStringList.Create;
  try
    Text:=FindTeXFile('hyphen.tex'); if Text='' then Exit; Lines.LoadFromFile(Text);
    Text:=''; for I:=0 to Lines.Count-1 do begin Pattern:=Lines[I]; P:=Pos('%',Pattern); if P>0 then Delete(Pattern,P,MaxInt); Text:=Text+Pattern+' '; end;
    P:=Pos('\patterns',Text); if P=0 then Exit; Inc(P,Length('\patterns'));
    Words.DelimitedText:=ReadTeXGroup(Text,P,'{','}');
    for Pattern in Words do begin
      N:=0; Letters:=''; Weights:=nil; SetLength(Weights,1);
      for I:=1 to Length(Pattern) do if Pattern[I] in ['0'..'9'] then Weights[High(Weights)]:=Ord(Pattern[I])-48
      else begin Letters:=Letters+Pattern[I]; SetLength(Weights,Length(Weights)+1); N:=Child(N,Pattern[I],True); end;
      Nodes[N].Weights:=Copy(Weights);
    end;
    P:=Pos('\hyphenation',Text); if P>0 then begin
      Inc(P,Length('\hyphenation')); Words.DelimitedText:=ReadTeXGroup(Text,P,'{','}');
      for Pattern in Words do begin
        Exception:=''; J:=0; for I:=1 to Length(Pattern) do if Pattern[I]='-' then Exception:=Exception+IntToStr(J)+',' else Inc(J);
        Exceptions.Values[StringReplace(Pattern,'-','',[rfReplaceAll])]:=Exception;
      end;
    end;
  finally Words.Free; Lines.Free; end;
end;
function TeXHyphenPoints(const WordText:string):THyphenPoints;
var Word,Exception:string; I,J,N,K,P:Integer; Weights:array of Byte;
begin
  Result:=nil; if (Length(WordText)<5) or (Length(WordText)>128) then Exit;
  for I:=1 to Length(WordText) do if not (WordText[I] in ['a'..'z','A'..'Z']) then Exit;
  LoadPatterns; Word:=LowerCase(WordText); Exception:=Exceptions.Values[Word];
  if Exception<>'' then begin
    while Exception<>'' do begin P:=Pos(',',Exception); if P=0 then Break; N:=StrToIntDef(Copy(Exception,1,P-1),0);
      Delete(Exception,1,P); if (N>=2) and (N<=Length(Word)-3) then begin K:=Length(Result); SetLength(Result,K+1); Result[K]:=N; end;
    end;
    Exit;
  end;
  Word:='.'+Word+'.'; SetLength(Weights,Length(Word)+1);
  for I:=1 to Length(Word) do begin
    N:=0; for J:=I to Length(Word) do begin
      N:=Child(N,Word[J],False); if N<0 then Break;
      for K:=0 to High(Nodes[N].Weights) do if I-1+K<Length(Weights) then Weights[I-1+K]:=Max(Weights[I-1+K],Nodes[N].Weights[K]);
    end;
  end;
  for I:=2 to Length(WordText)-3 do if Odd(Weights[I+1]) then begin K:=Length(Result); SetLength(Result,K+1); Result[K]:=I; end;
end;
finalization
  Exceptions.Free;
end.
