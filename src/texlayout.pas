unit TeXLayout;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, SysUtils, Types, Math, SourceRanges, Graphics, DOM, XMLRead, LazUTF8, MathModel, ParagraphModel, TeXTextMetrics, TeXFonts, VectorPreview;
type
  TCharStops = array of Integer;
  TTeXAnchor = record
    ID,FirstChar,CharCount,SourceStart,SourceLength,FontHeight,Baseline,InkRight:Integer;
    Bounds:TRect;
    Text,FontName:string;
    Stops:TCharStops;
    Style:TFontStyles;
    Color:TColor;
    IsContainer:Boolean;
  end;
  TTeXAnchors = array of TTeXAnchor;
  TTeXGlyph = record
    Text,FontName:string;
    Bounds:TRect;
    FontHeight:Integer;
    Style:TFontStyles;
    Color:TColor;
  end;
  TTeXGlyphs=array of TTeXGlyph;
  TTeXLayout = class
  private
    FGlyphs:TTeXGlyphs;
  public
    Links:TVectorLinks;
    Anchors:TTeXAnchors;
    Source:string;
    Width,Height:Integer;
    property Glyphs:TTeXGlyphs read FGlyphs;
    function Glyph(const Text:string; const Anchor:TTeXAnchor; out Value:TTeXGlyph):Boolean;
    procedure Clear;
    procedure Load(const XML:string; Page:Integer; Canvas:TCanvas);
    procedure Bind(Root:TMathNode; const ASource:string);
    function AnchorIndex(Offset:Integer; const CurrentSource:string; Container:Boolean=False; Empty:Boolean=False):Integer;
  end;
implementation
function Number(E:TDOMElement; const Name:string):Double;
var F:TFormatSettings;
begin F:=DefaultFormatSettings; F.DecimalSeparator:='.'; Result:=StrToFloatDef(string(E.GetAttribute(UTF8Decode(Name))),0,F); end;
function PlainText(N:TDOMNode):string;
var C:TDOMNode;
begin
  if (N.NodeType=TEXT_NODE) or (N.NodeType=CDATA_SECTION_NODE) then Exit(UTF8Encode(N.NodeValue));
  Result:=''; C:=N.FirstChild;
  while C<>nil do begin Result:=Result+PlainText(C); C:=C.NextSibling; end;
end;
function Normal(const S:string):string;
begin
  Result:=StringReplace(S,'ﬁ','fi',[rfReplaceAll]);
  Result:=StringReplace(Result,'ﬂ','fl',[rfReplaceAll]);
  Result:=StringReplace(Result,'ﬀ','ff',[rfReplaceAll]);
  Result:=StringReplace(Result,'ﬃ','ffi',[rfReplaceAll]);
  Result:=StringReplace(Result,'ﬄ','ffl',[rfReplaceAll]);
  Result:=StringReplace(Result,' ',' ',[rfReplaceAll]);
  Result:=StringReplace(Result,'­','-',[rfReplaceAll]);
end;
function TTeXLayout.Glyph(const Text:string; const Anchor:TTeXAnchor; out Value:TTeXGlyph):Boolean;
var I:Integer;
begin
  Result:=False;
  for I:=0 to High(FGlyphs) do
    if (FGlyphs[I].Text=Text) and (FGlyphs[I].FontName=Anchor.FontName) and
       (FGlyphs[I].FontHeight=Anchor.FontHeight) and (FGlyphs[I].Style=Anchor.Style) and
       (FGlyphs[I].Color=Anchor.Color) then
    begin Value:=FGlyphs[I]; Exit(True); end;
end;
procedure TTeXLayout.Clear;
begin FGlyphs:=nil; Anchors:=nil; Links:=nil; Source:=''; Width:=0; Height:=0; end;
procedure TTeXLayout.Load(const XML:string; Page:Integer; Canvas:TCanvas);
var Doc:TXMLDocument; Stream:TStringStream; PageNode,N,C:TDOMNode; E,F:TDOMElement;
    Fonts:TStringList; I,J,Count,X,Y,W,H,Size,Total,Advance,ColorValue,RunStart,CharIndex:Integer;
    S,Family,Lower,ExactFont,PostScript:string; Style:TFontStyles; G:TTeXGlyph;
  procedure ReadLinks(Node:TDOMNode);
  var Child:TDOMNode; First,Last,I,N,P:Integer; Link:TVectorLink; Target:string; R:TRect;
  begin
    First:=CharIndex;
    if Node.NodeType in [TEXT_NODE,CDATA_SECTION_NODE] then Inc(CharIndex,UTF8Length(Normal(UTF8Encode(Node.NodeValue))))
    else begin Child:=Node.FirstChild; while Child<>nil do begin ReadLinks(Child); Child:=Child.NextSibling; end; end;
    if (Node.NodeName<>'a') or not (Node is TDOMElement) or (CharIndex<=First) then Exit;
    Target:=UTF8Encode(TDOMElement(Node).GetAttribute('href')); if Target='' then Exit;
    Link:=Default(TVectorLink); Link.Page:=-1; P:=Pos('#',Target);
    if (P>0) and (Pos('://',Target)=0) then Link.Page:=StrToIntDef(Copy(Target,P+1,MaxInt),-1)
    else Link.URI:=Target;
    if (Link.Page<1) and (Link.URI='') then Exit;
    First:=RunStart+First; Last:=Min(RunStart+CharIndex-1,High(FGlyphs)); if First>Last then Exit;
    R:=FGlyphs[First].Bounds;
    for I:=First+1 to Last do begin
      R.Left:=Min(R.Left,FGlyphs[I].Bounds.Left); R.Right:=Max(R.Right,FGlyphs[I].Bounds.Right);
      R.Top:=Min(R.Top,FGlyphs[I].Bounds.Top); R.Bottom:=Max(R.Bottom,FGlyphs[I].Bounds.Bottom);
    end;
    Link.Bounds.Left:=R.Left/Max(1,Width); Link.Bounds.Right:=R.Right/Max(1,Width);
    Link.Bounds.Top:=R.Top/Max(1,Height); Link.Bounds.Bottom:=R.Bottom/Max(1,Height);
    N:=Length(Links); SetLength(Links,N+1); Links[N]:=Link;
  end;
begin
  Clear; if XML='' then Exit;
  Doc:=nil; Stream:=TStringStream.Create(XML); Fonts:=TStringList.Create;
  try
    ReadXMLFile(Doc,Stream);
    PageNode:=Doc.DocumentElement.FirstChild;
    while PageNode<>nil do
    begin
      N:=PageNode.FirstChild;
      while N<>nil do
      begin
        if N.NodeName='fontspec' then Fonts.AddObject(string(TDOMElement(N).GetAttribute('id')),TObject(N));
        N:=N.NextSibling;
      end;
      if (PageNode.NodeName='page') and (StrToIntDef(string(TDOMElement(PageNode).GetAttribute('number')),0)=Page) then
      begin
        E:=TDOMElement(PageNode); Width:=Round(Number(E,'width')); Height:=Round(Number(E,'height'));
        N:=PageNode.FirstChild;
        while N<>nil do
        begin
          if N.NodeName='fontspec' then
            Fonts.AddObject(string(TDOMElement(N).GetAttribute('id')),TObject(N));
          N:=N.NextSibling;
        end;
        N:=PageNode.FirstChild;
        while N<>nil do
        begin
          if N.NodeName='text' then
          begin
            E:=TDOMElement(N); S:=Normal(PlainText(N)); Style:=[];
            X:=Round(Number(E,'left')); Y:=Round(Number(E,'top'));
            W:=Round(Number(E,'width')); H:=Max(1,Round(Number(E,'height')));
            Size:=H; Family:='Latin Modern Roman'; ColorValue:=0;
            I:=Fonts.IndexOf(string(E.GetAttribute('font')));
            if I>=0 then
            begin
              F:=TDOMElement(Fonts.Objects[I]); Family:=string(F.GetAttribute('family'));
              Size:=Max(1,Round(Number(F,'size')));
              ColorValue:=StrToIntDef('$'+StringReplace(string(F.GetAttribute('color')),'#','',[]),0);
            end;
            I:=Pos('+',Family); if I>0 then Delete(Family,1,I);
            PostScript:=Family;
            Lower:=LowerCase(Family);
            if (Pos('bold',Lower)>0) or (Pos('cmbx',Lower)>0) or (Pos('cmb',Lower)=1) then Include(Style,fsBold);
            if (Pos('italic',Lower)>0) or (Pos('cmti',Lower)>0) or (Pos('cmmi',Lower)>0) then Include(Style,fsItalic);
            C:=N.FirstChild;
            while C<>nil do
            begin
              if C.NodeName='b' then Include(Style,fsBold);
              if C.NodeName='i' then Include(Style,fsItalic);
              C:=C.NextSibling;
            end;
            if (Pos('cm',Lower)=1) or (Pos('lm',Lower)=1) or (Pos('+cm',Lower)>0) then
            begin
              Family:='Latin Modern Roman';
              { Use a family name without a trailing number: Pango treats it as a size. }
              if (Pos('ss',Lower)>0) or (Pos('sans',Lower)>0) then Family:='Latin Modern Sans'
              else if (Pos('tt',Lower)>0) or (Pos('mono',Lower)>0) then Family:='Latin Modern Mono';
            end;
            ExactFont:=ResolveTeXFont(PostScript);
            if ExactFont<>'' then Family:=ExactFont;
            Canvas.Font.Name:=Family; Canvas.Font.Height:=-Size; Canvas.Font.Style:=Style;
            Total:=Max(1,TeXTextWidth(Canvas,S)); Advance:=0; RunStart:=Length(FGlyphs);
            for J:=1 to UTF8Length(S) do
            begin
              G.Text:=UTF8Copy(S,J,1); G.FontName:=Family; G.FontHeight:=Size; G.Style:=Style;
              G.Color:=TColor(((ColorValue and $FF) shl 16) or (ColorValue and $FF00) or ((ColorValue shr 16) and $FF));
              G.Bounds:=Rect(X+Round(W*Advance/Total),Y,0,Y+H);
              Advance:=TeXTextWidth(Canvas,UTF8Copy(S,1,J)); G.Bounds.Right:=X+Round(W*Advance/Total);
              Count:=Length(FGlyphs); SetLength(FGlyphs,Count+1); FGlyphs[Count]:=G;
            end;
            CharIndex:=0; ReadLinks(N);
          end;
          N:=N.NextSibling;
        end;
        Break;
      end;
      PageNode:=PageNode.NextSibling;
    end;
  except Clear; end;
  Fonts.Free; Doc.Free; Stream.Free;
end;
procedure TTeXLayout.Bind(Root:TMathNode; const ASource:string);
var Fields:TList; I,J,K,P,Start,Matched,N,First,Leading,Trailing,Gap,Leftmost:Integer; Node:TMathNode;
    Wanted,CharText:string; A:TTeXAnchor; Found:Boolean;
begin
  Anchors:=nil; Source:=ASource; P:=0; Fields:=TList.Create;
  try
    MathFields(Root,Fields);
    for I:=0 to Fields.Count-1 do
    begin
      Node:=TMathNode(Fields[I]);
      if IsLabelField(Node) then Continue;
      if Node.Kind in [mkText,mkCommand] then Continue;
      Wanted:=Trim(Normal(Node.Text));
      if (Node.Kind=mkCommand) and (Length(Wanted)>1) then
      begin
        CharText:=SymbolDisplay(Copy(Wanted,2,MaxInt));
        if CharText<>'' then Wanted:=CharText;
      end;
      if Node.Kind=mkTextCommand then
      begin
        if Pos('\LaTeX',Wanted)=1 then Wanted:='LaTeX'
        else if Pos('\TeX',Wanted)=1 then Wanted:='TeX';
      end;
      if Wanted='' then Continue;
      Start:=P; Found:=False;
      while Start<Length(FGlyphs) do
      begin
        { A PDF space belongs to the preceding word's glue, never to the
          next word's cached image as well. }
        while (Start<Length(FGlyphs)) and (Trim(FGlyphs[Start].Text)='') do Inc(Start);
        if Start>=Length(FGlyphs) then Break;
        J:=Start; Matched:=0;
        while (J<Length(FGlyphs)) and (Matched<UTF8Length(Wanted)) do
        begin
          CharText:=UTF8Copy(Wanted,Matched+1,1);
          if FGlyphs[J].Text=CharText then Inc(Matched)
          else if (FGlyphs[J].Text='-') and (J+1<Length(FGlyphs)) and
                  (FGlyphs[J+1].Bounds.Top>FGlyphs[J].Bounds.Top+3) then
          begin { TeX's discretionary end-of-line hyphen is not in the source. } end
          else if Trim(FGlyphs[J].Text)<>'' then Break;
          Inc(J);
        end;
        if Matched=UTF8Length(Wanted) then begin Found:=True; Break; end;
        Inc(Start);
      end;
      if not Found then Continue;
      K:=Start; First:=0; Leading:=UTF8Length(Node.Text)-UTF8Length(TrimLeft(Node.Text));
      while K<J do
      begin
        A.IsContainer:=False; A.ID:=Node.ID; A.SourceStart:=MathSourceOffset(Node); A.SourceLength:=Length(Node.Text);
        A.FontName:=FGlyphs[K].FontName; A.FontHeight:=FGlyphs[K].FontHeight; A.Style:=FGlyphs[K].Style; A.Color:=FGlyphs[K].Color;
        A.Bounds:=FGlyphs[K].Bounds; A.InkRight:=0; A.Baseline:=(A.Bounds.Bottom-A.Bounds.Top)*4 div 5; A.FirstChar:=First+Leading; A.CharCount:=0; A.Stops:=nil; SetLength(A.Stops,1); A.Stops[0]:=0; A.Text:='';
        while K<J do
        begin
          if Abs(FGlyphs[K].Bounds.Top-A.Bounds.Top)>3 then Break;
          if (A.Text<>'') and ((FGlyphs[K].FontName<>A.FontName) or (FGlyphs[K].FontHeight<>A.FontHeight) or
             (FGlyphs[K].Style<>A.Style) or (FGlyphs[K].Color<>A.Color)) then Break;
          A.Bounds.Right:=Max(A.Bounds.Right,FGlyphs[K].Bounds.Right);
          A.Bounds.Bottom:=Max(A.Bounds.Bottom,FGlyphs[K].Bounds.Bottom);
          A.Text:=A.Text+FGlyphs[K].Text;
          if (First<UTF8Length(Wanted)) and (FGlyphs[K].Text=UTF8Copy(Wanted,First+1,1)) then
          begin
            Inc(First); Inc(A.CharCount); SetLength(A.Stops,A.CharCount+1);
            A.Stops[A.CharCount]:=FGlyphs[K].Bounds.Right-A.Bounds.Left;
          end;
          Inc(K);
        end;
        A.InkRight:=A.Bounds.Right;
        N:=Length(Anchors); SetLength(Anchors,N+1); Anchors[N]:=A;
      end;
      { Include source whitespace in the final fragment so typing at a word's
        end does not snap the caret back onto the last visible letter. }
      Trailing:=UTF8Length(Node.Text)-UTF8Length(TrimRight(Node.Text));
      if (Trailing>0) and (Length(Anchors)>0) then
      begin
        N:=High(Anchors); A:=Anchors[N]; Gap:=0; K:=J;
        while (K<Length(FGlyphs)) and (Trim(FGlyphs[K].Text)='') do Inc(K);
        if (K<Length(FGlyphs)) and (Abs(FGlyphs[K].Bounds.Top-A.Bounds.Top)<=3) then
        begin
          { TeX emits an accent before its argument. Its centered glyph can
            be far to the right of the first letter, so PDF drawing order
            cannot determine the width of the preceding space. }
          Leftmost:=FGlyphs[K].Bounds.Left; Inc(K);
          while (K<Length(FGlyphs)) and (Abs(FGlyphs[K].Bounds.Top-A.Bounds.Top)<=3) do
          begin
            if (FGlyphs[K].Bounds.Left>=A.Bounds.Right) and
               (FGlyphs[K].Bounds.Left<Leftmost) then Leftmost:=FGlyphs[K].Bounds.Left;
            Inc(K);
          end;
          Gap:=Max(0,Leftmost-A.Bounds.Right);
        end;
        First:=A.CharCount; Inc(A.CharCount,Trailing);
        SetLength(A.Stops,A.CharCount+1);
        for K:=1 to Trailing do A.Stops[First+K]:=A.Bounds.Right-A.Bounds.Left+Gap;
        Inc(A.Bounds.Right,Gap); A.Text:=A.Text+' '; Anchors[N]:=A;
      end;
      P:=J;
    end;
  finally Fields.Free; end;
end;
function TTeXLayout.AnchorIndex(Offset:Integer; const CurrentSource:string; Container:Boolean; Empty:Boolean):Integer;
var Prefix,OldEnd,NewEnd,I,Mapped:Integer;
begin
  Result:=-1; SourceDifference(Source,CurrentSource,Prefix,OldEnd,NewEnd);
  Mapped:=Offset;
  if Offset>=NewEnd then Mapped:=Offset+OldEnd-NewEnd
  else if Offset>Prefix then Exit;
  for I:=0 to High(Anchors) do
    if (Anchors[I].IsContainer=Container) and ((Anchors[I].SourceLength=0)=Empty) and (Anchors[I].SourceStart=Mapped) then Exit(I);
  for I:=0 to High(Anchors) do
    if (Anchors[I].IsContainer=Container) and ((Anchors[I].SourceLength=0)=Empty) and (Mapped>=Anchors[I].SourceStart) and (Mapped<Anchors[I].SourceStart+Anchors[I].SourceLength) then Exit(I);
end;
end.
