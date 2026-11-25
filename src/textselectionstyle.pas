unit TextSelectionStyle;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, MathModel, TeXTextStyle, TeXStyles, TeXContext, SourceRanges;
type
  TTeXTextSelection=record
    Style:TTeXTextStyle;
    Valid,Bold,Italic,SmallCaps,Slanted,Upright,Underlined:Boolean;
  end;
function QueryTextSelectionStyle(Fields:TList; Current:TMathNode; A,B:Integer;
  const Base:TTeXTextStyle; Styles:TTeXStyles; Context:TTeXContext;
  const Directory:string; const Ranges:TSourceRanges=nil):TTeXTextSelection;
function TextSelectionStyleActive(const Selection:TTeXTextSelection; const Command:string):Boolean;
implementation
uses SysUtils, Math, ParagraphModel, TeXMacros;
function QueryTextSelectionStyle(Fields:TList; Current:TMathNode; A,B:Integer;
  const Base:TTeXTextStyle; Styles:TTeXStyles; Context:TTeXContext;
  const Directory:string; const Ranges:TSourceRanges):TTeXTextSelection;
var I,J,L,R:Integer; N:TMathNode; Style:TTeXTextStyle; Included,Underlined:Boolean; Index:TMathSourceIndex;
  procedure InheritedStyle(Node:TMathNode; var Value:TTeXTextStyle);
  var P,K:Integer; Command:string; Heading:THeadingFormat; Theorem:TTheoremInfo; Previous:TMathNode;
  begin
    if Node=nil then Exit;
    InheritedStyle(Node.Parent,Value);
    if Node.Parent<>nil then for K:=0 to Node.Parent.Children.Count-1 do begin
      Previous:=TMathNode(Node.Parent.Children[K]); if Previous=Node then Break;
      if not (Previous.Kind in [mkUnknownCommand,mkTextCommand]) then Continue;
      P:=1; Command:=ReadTeXCommand(Previous.TeX,P);
      if IsTextStyleSwitch(Command) then ApplyTextStyle(Value,Previous.TeX,Directory);
    end;
    if (Node.Kind=mkGroup) and (Copy(Node.Prefix,1,1)='\') and (Styles<>nil) then begin
      P:=1; Command:=ReadTeXCommand(Node.Prefix,P);
      if HeadingIndex(Command)>=0 then begin
        Heading:=Styles.Heading(Command,Copy(Node.Prefix,P,1)='*');
        ApplyTextStyle(Value,Heading.Format+Heading.BeforeCode,Directory);
      end;
    end;
    if (Node.Kind=mkEnvironment) and (Context<>nil) then begin
      Theorem:=Context.Theorem(Node.Text);
      if (Theorem<>nil) and (Theorem.Style='plain') then ApplyTextStyle(Value,'\itshape',Directory);
    end;
    if ProseFormatName(Node)='\underline' then Underlined:=True;
    if ProseFormatName(Node)<>'' then ApplyTextStyle(Value,Node.Prefix,Directory);
  end;
begin
  Result:=Default(TTeXTextSelection); Result.Style:=Base;
  Result.Bold:=True; Result.Italic:=True; Result.SmallCaps:=True;
  Result.Slanted:=True; Result.Upright:=True; Result.Underlined:=True;
  Index:=nil;
  if (Fields.Count>0) and (A<>B) then begin
    N:=TMathNode(Fields[0]); while N.Parent<>nil do N:=N.Parent;
    Index:=TMathSourceIndex.Create(N);
  end;
  try
  for I:=0 to Fields.Count-1 do begin
    N:=TMathNode(Fields[I]);
    if (N.Kind<>mkProse) or IsMathField(N) or IsCodeField(N) then Continue;
    if (A=B) and (Current<>nil) and (N<>Current) then Continue;
    L:=MathSourceOffset(N); R:=L+Length(N.Text);
    if A=B then begin if (Current=nil) and ((A<L) or (A>R)) then Continue; end
    else if (B<=L) or (A>=R) then Continue;
    if Length(Ranges)>0 then begin
      Included:=False;
      for J:=0 to High(Ranges) do if (R>Ranges[J].Start) and (L<Ranges[J].Finish) then Included:=True;
      if not Included then Continue;
    end;
    if (A<>B) and (Trim(N.Text)='') then Continue;
    Style:=Base; Underlined:=False; InheritedStyle(N,Style);
    Result.Bold:=Result.Bold and ((Style.Series='b') or (Style.Series='bx'));
    Result.Italic:=Result.Italic and ((Pos('it',Style.Shape)>0) or (Pos('sl',Style.Shape)>0));
    Result.SmallCaps:=Result.SmallCaps and (Pos('sc',Style.Shape)=1);
    Result.Slanted:=Result.Slanted and (Pos('sl',Style.Shape)>0);
    Result.Upright:=Result.Upright and ((Style.Shape='n') or (Style.Shape='sc'));
    Result.Underlined:=Result.Underlined and Underlined;
    if not Result.Valid then Result.Style:=Style
    else begin
      if Result.Style.Family<>Style.Family then Result.Style.Family:='';
      if Result.Style.Series<>Style.Series then Result.Style.Series:='';
      if Result.Style.Shape<>Style.Shape then Result.Style.Shape:='';
      if (Result.Style.SizeName<>Style.SizeName) or (Abs(Result.Style.Points-Style.Points)>0.001) then begin
        Result.Style.SizeName:=''; Result.Style.Points:=0;
      end;
    end;
    Result.Valid:=True;
  end;
  finally Index.Free; end;
end;
function TextSelectionStyleActive(const Selection:TTeXTextSelection; const Command:string):Boolean;
begin
  Result:=False; if not Selection.Valid then Exit;
  case Command of
    '\textbf':Result:=Selection.Bold;
    '\textmd':Result:=Selection.Style.Series='m';
    '\textit','\emph':Result:=Selection.Italic;
    '\textsl':Result:=Selection.Slanted;
    '\textsc':Result:=Selection.SmallCaps;
    '\textup':Result:=Selection.Upright;
    '\underline':Result:=Selection.Underlined;
    '\textsf':Result:=Selection.Style.Family=Selection.Style.Sans;
    '\texttt':Result:=Selection.Style.Family=Selection.Style.Mono;
    '\textrm':Result:=Selection.Style.Family=Selection.Style.Roman;
  end;
end;
end.
