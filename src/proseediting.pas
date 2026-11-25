unit ProseEditing;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Math, MathModel, ParagraphModel;
{ Visual ranges exclude formatting syntax. Operations split wrappers at those
  ranges, keeping each resulting fragment valid TeX. Source offsets are bytes. }
function ProseFragment(Root:TMathNode; const Source:string; A,B:Integer;
  const StripCommand:string=''):string;
function BodyClipboardFragment(Root:TMathNode; const Source:string; A,B:Integer;
  MathMode:Boolean=False):string;
function ReplaceProseRange(Root:TMathNode; const Source:string; A,B:Integer;
  const Value:string; out Caret:Integer; CompactStyles:Boolean=True):string;
procedure CompactProseFormatting(var Source:string; var A,B:Integer);
function ToggleSourceComment(const Source:string):string;
implementation
uses TeXTextStyle, TeXMacros;
function ProseFragment(Root:TMathNode; const Source:string; A,B:Integer;
  const StripCommand:string):string;
  function Slice(Node:TMathNode):string;
  var L,R,C,D,I,First,P:Integer; Body,Prefix,Command:string; Child,Content:TMathNode; Styled:Boolean;
    function Part(Start,Count:Integer):string;
    var Left,Right:Integer;
    begin
      Left:=Max(A,Start); Right:=Min(B,Start+Count);
      Result:=Copy(Source,Left+1,Max(0,Right-Left));
    end;
  begin
    Result:=''; L:=MathSourceOffset(Node)-Length(Node.Prefix); R:=L+Length(Node.TeX);
    if (A>=R) or (B<=L) then Exit;
    Prefix:=Node.Prefix; First:=0; Styled:=ProseFormatName(Node)<>''; Content:=Node;
    if (Node.Kind=mkGroup) and (Node.Prefix='{') then begin
      { Declarations remain real editable children. Treat their leading run
        as formatting when splitting a visual text selection. }
      if (Node.Children.Count=1) and (TMathNode(Node.Children[0]).Kind=mkRow) then Content:=TMathNode(Node.Children[0]);
      for I:=0 to Content.Children.Count-1 do begin
        Child:=TMathNode(Content.Children[I]);
        if (Child.Kind=mkProse) and (Trim(Child.Text)='') then begin
          Prefix:=Prefix+Child.TeX; First:=I+1; Continue;
        end;
        if not (Child.Kind in [mkUnknownCommand,mkTextCommand]) then Break;
        P:=1; Command:=ReadTeXCommand(Child.TeX,P); if not IsTextStyleSwitch(Command) then Break;
        Styled:=True; Prefix:=Prefix+Child.TeX; First:=I+1;
      end;
    end;
    if Styled then begin
      Body:='';
      for I:=First to Content.Children.Count-1 do Body:=Body+Slice(TMathNode(Content.Children[I]));
      if Body='' then Exit;
      Prefix:=StripTextStylePrefix(Prefix,StripCommand);
      if Prefix='' then Exit(Body);
      Exit(Prefix+Body+Node.Suffix);
    end;
    C:=L+Length(Node.Prefix); D:=R-Length(Node.Suffix);
    Result:=Part(L,Length(Node.Prefix));
    if Node.Kind in [mkText,mkRaw,mkCommand,mkProse,mkTextCommand] then
      Result:=Result+Part(C,Length(Node.Text));
    for I:=0 to Node.Children.Count-1 do Result:=Result+Slice(TMathNode(Node.Children[I]));
    Result:=Result+Part(D,Length(Node.Suffix));
  end;
begin Result:=Slice(Root); end;

function BodyClipboardFragment(Root:TMathNode; const Source:string; A,B:Integer;
  MathMode:Boolean):string;
var Position:Integer;
  function MathFragment(Node:TMathNode; First,Last:Integer):string;
  var TextNode:TMathNode; Start,Finish:Integer;
    procedure FindText(N:TMathNode);
    var I,L,R:Integer;
    begin
      L:=MathSourceOffset(N)-Length(N.Prefix); R:=L+Length(N.TeX);
      if (First<L) or (Last>R) then Exit;
      if (N.Kind=mkCommand) and (N.Text='\text') and (N.Children.Count>0) then TextNode:=TMathNode(N.Children[0]);
      for I:=0 to N.Children.Count-1 do FindText(TMathNode(N.Children[I]));
    end;
  begin
    TextNode:=nil; FindText(Node);
    if TextNode<>nil then begin
      Start:=MathSourceOffset(TextNode); Finish:=Start+Length(TextNode.TeX)-Length(TextNode.Prefix)-Length(TextNode.Suffix);
      Exit(ProseFragment(TextNode,Source,Max(First,Start),Min(Last,Finish)));
    end;
    if Node.Kind=mkFormula then begin
      Start:=MathSourceOffset(Node)-Length(Node.Prefix); Finish:=Start+Length(Node.TeX);
      if (First<=Start) and (Last>=Finish) and (Node.Prefix<>'') then Exit(Node.TeX);
      First:=Max(First,Start+Length(Node.Prefix)); Last:=Min(Last,Finish-Length(Node.Suffix));
    end;
    Result:=ProseFragment(Node,Source,First,Last);
    if Result<>'' then Result:='$'+Result+'$';
  end;
  procedure Visit(Node:TMathNode);
  var I,L,R:Integer;
  begin
    L:=MathSourceOffset(Node)-Length(Node.Prefix); R:=L+Length(Node.TeX);
    if (R<=A) or (L>=B) then Exit;
    if (A<=L) and (B>=R) and ((Node.Kind in [mkDefinition,mkUnknownCommand]) or Node.NativePackage) then Exit;
    if Node.Kind=mkFormula then begin
      if Position<Max(A,L) then Result:=Result+ProseFragment(Root,Source,Position,Max(A,L));
      Result:=Result+MathFragment(Node,Max(A,L),Min(B,R)); Position:=Min(B,R); Exit;
    end;
    for I:=0 to Node.Children.Count-1 do Visit(TMathNode(Node.Children[I]));
  end;
begin
  A:=EnsureRange(A,0,Length(Source)); B:=EnsureRange(B,A,Length(Source));
  if MathMode then Exit(MathFragment(Root,A,B));
  Result:=''; Position:=A; Visit(Root);
  if Position<B then Result:=Result+ProseFragment(Root,Source,Position,B);
end;

function ToggleSourceComment(const Source:string):string;
var Lines:TStringList; I,P:Integer; Uncomment,Found:Boolean; S:string;
begin
  Lines:=TStringList.Create;
  try
    Lines.Text:=Source; Uncomment:=True; Found:=False;
    for I:=0 to Lines.Count-1 do begin
      S:=Lines[I]; P:=1; while (P<=Length(S)) and (S[P] in [' ',#9]) do Inc(P);
      if P>Length(S) then Continue; Found:=True;
      if S[P]<>'%' then Uncomment:=False;
    end;
    Result:='';
    for I:=0 to Lines.Count-1 do begin
      S:=Lines[I]; P:=1; while (P<=Length(S)) and (S[P] in [' ',#9]) do Inc(P);
      if Uncomment and Found then begin
        if (P<=Length(S)) and (S[P]='%') then begin
          Delete(S,P,1); if (P<=Length(S)) and (S[P]=' ') then Delete(S,P,1);
        end;
      end else Insert('% ',S,P);
      if I>0 then Result:=Result+LineEnding; Result:=Result+S;
    end;
    if (Source<>'') and (Source[Length(Source)]=#10) then Result:=Result+LineEnding;
  finally Lines.Free; end;
end;

procedure CompactProseFormatting(var Source:string; var A,B:Integer);
type TDeletion=record Start,Count:Integer; end;
var Root:TMathNode; Deletes:array of TDeletion; I,J:Integer; D:TDeletion;
  procedure Remove(Start,Count:Integer);
  var K:Integer;
  begin
    if Count=0 then Exit;
    K:=Length(Deletes); SetLength(Deletes,K+1); Deletes[K].Start:=Start; Deletes[K].Count:=Count;
  end;
  procedure Visit(Node:TMathNode; const InheritedPrefix:string);
  var K,Start:Integer; N,Previous:TMathNode; Prefix,Scope:string;
  begin
    Prefix:=Node.Prefix; Scope:=InheritedPrefix;
    if ProseFormatName(Node)<>'' then begin
      Start:=MathSourceOffset(Node)-Length(Prefix);
      { Nested emphasis reverses its inherited style; nested underlining adds
        a second rule. Those wrappers are not redundant. }
      if (Prefix=InheritedPrefix) and (ProseFormatName(Node)<>'\emph') and
         (ProseFormatName(Node)<>'\underline') then begin
        Remove(Start,Length(Prefix)); Remove(Start+Length(Node.TeX)-Length(Node.Suffix),Length(Node.Suffix));
      end else Scope:=Prefix;
    end;
    Previous:=nil;
    for K:=0 to Node.Children.Count-1 do begin
      N:=TMathNode(Node.Children[K]); Visit(N,Scope);
      if (N.TeX='') then Continue;
      if (Previous<>nil) and (ProseFormatName(Previous)<>'') and
         (Previous.Prefix=N.Prefix) and (Previous.Suffix=N.Suffix) and
         (N.Prefix<>Scope) then begin
        Start:=MathSourceOffset(N)-Length(N.Prefix);
        Remove(Start-Length(Previous.Suffix),Length(Previous.Suffix)+Length(N.Prefix));
      end;
      Previous:=N;
    end;
  end;
  procedure MapOffset(var Offset:Integer; Start,Count:Integer);
  begin
    if Offset>=Start+Count then Dec(Offset,Count)
    else if Offset>Start then Offset:=Start;
  end;
begin
  Root:=ParseParagraph(Source,nil);
  try
    if Root.TeX<>Source then Exit;
    Visit(Root,'');
  finally Root.Free; end;
  { Apply right to left so the original offsets remain valid. }
  for I:=1 to High(Deletes) do begin
    D:=Deletes[I]; J:=I-1;
    while (J>=0) and (Deletes[J].Start<D.Start) do begin Deletes[J+1]:=Deletes[J]; Dec(J); end;
    Deletes[J+1]:=D;
  end;
  for I:=0 to High(Deletes) do begin
    D:=Deletes[I]; Delete(Source,D.Start+1,D.Count);
    MapOffset(A,D.Start,D.Count); MapOffset(B,D.Start,D.Count);
  end;
end;

function ReplaceProseRange(Root:TMathNode; const Source:string; A,B:Integer;
  const Value:string; out Caret:Integer; CompactStyles:Boolean):string;
var Repair:Boolean; Other:Integer;
  procedure Check(Node:TMathNode);
  var L,R,I:Integer;
  begin
    L:=MathSourceOffset(Node); R:=L+Length(Node.TeX)-Length(Node.Prefix)-Length(Node.Suffix);
    if (ProseFormatName(Node)<>'') and (((A>=L) and (A<R+Length(Node.Suffix)) and (B>R)) or
       ((A<L) and (B>=L) and (B<R+Length(Node.Suffix)))) then Repair:=True;
    for I:=0 to Node.Children.Count-1 do Check(TMathNode(Node.Children[I]));
  end;
begin
  Repair:=False; Check(Root);
  if not Repair then begin
    Result:=Copy(Source,1,A)+Value+Copy(Source,B+1,MaxInt); Caret:=A+Length(Value); Exit;
  end;
  Result:=ProseFragment(Root,Source,0,A)+Value; Caret:=Length(Result);
  Result:=Result+ProseFragment(Root,Source,B,Length(Source)); Other:=Caret;
  if CompactStyles then CompactProseFormatting(Result,Caret,Other);
end;
end.
