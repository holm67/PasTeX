unit NativeFloats;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses NativePagination;
type
  TPageBlock=record
    Lines:TPageLines;
    NativeHeight,Top,Height:Integer;
    FullPages:Boolean;
    FloatKind,Placement:string;
    Shifts:TPageShifts;
  end;
  TPageBlocks=array of TPageBlock;
  TFloatPageSettings=record
    Body,Pitch,InTextSep,TextFloatSep,FloatSep,FloatPageSep:Integer;
    TopNumber,BottomNumber,TotalNumber:Integer;
    TopFraction,BottomFraction,TextFraction,FloatPageFraction:Double;
  end;
function FloatPageSettings(const Preamble:string; Body,Pitch:Integer; PixelsPerPoint:Double):TFloatPageSettings;
procedure ReadPageFloat(const Source:string; out Kind,Placement:string);
function LayoutPageBlocks(var Blocks:TPageBlocks; const Settings:TFloatPageSettings):Integer;
function PageBlockFirstPage(const Block:TPageBlock; Pitch:Integer):Integer;
function PageSourceMap(const Blocks:TPageBlocks; const BlockPages:TSourcePages; Pitch:Integer):TSourcePages;
implementation
uses Classes, SysUtils, Math, TeXMacros, TeXTables;
type
  TIndices=array of Integer;
  TLineReference=record Block,Line:Integer; end;
function PageBlockFirstPage(const Block:TPageBlock; Pitch:Integer):Integer;
var Top:Integer;
begin
  Top:=Block.Top;
  if (Length(Block.Lines)>0) and (Length(Block.Shifts)>0) then
    Inc(Top,Block.Lines[0].Top+Block.Shifts[0]);
  Result:=Max(0,Top div Max(1,Pitch))+1;
end;
function PageSourceMap(const Blocks:TPageBlocks; const BlockPages:TSourcePages; Pitch:Integer):TSourcePages;
var Count,I,J,N,Page:Integer; Ordered:Boolean;
  function Less(const A,B:TSourcePage):Boolean;
  begin Result:=(A.Offset<B.Offset) or ((A.Offset=B.Offset) and (A.Page<B.Page)); end;
  procedure Add(Offset,Page:Integer);
  begin
    if Count=Length(Result) then SetLength(Result,Max(32,Count*2));
    Result[Count].Offset:=Offset; Result[Count].Page:=Page;
    if Count>0 then Ordered:=Ordered and not Less(Result[Count],Result[Count-1]); Inc(Count);
  end;
  procedure Sort(Left,Right:Integer);
  var I,J:Integer; Pivot,Swap:TSourcePage;
  begin
    I:=Left; J:=Right; Pivot:=Result[Left+(Right-Left) div 2];
    repeat
      while Less(Result[I],Pivot) do Inc(I);
      while Less(Pivot,Result[J]) do Dec(J);
      if I<=J then begin Swap:=Result[I]; Result[I]:=Result[J]; Result[J]:=Swap; Inc(I); Dec(J); end;
    until I>J;
    if Left<J then Sort(Left,J); if I<Right then Sort(I,Right);
  end;
begin
  Result:=nil; Count:=0; Ordered:=True;
  for I:=0 to Min(High(Blocks),High(BlockPages)) do begin
    Add(BlockPages[I].Offset,BlockPages[I].Page);
    for J:=0 to Min(High(Blocks[I].Lines),High(Blocks[I].Shifts)) do begin
      if (Blocks[I].Lines[J].SourceOffset<=0) or (Blocks[I].Lines[J].SourceOffset=MaxInt) then Continue;
      Page:=Max(0,(Blocks[I].Top+Blocks[I].Lines[J].Top+Blocks[I].Shifts[J]) div Max(1,Pitch))+1;
      Add(BlockPages[I].Offset+Blocks[I].Lines[J].SourceOffset,Page);
    end;
  end;
  if Count=0 then Exit; if not Ordered then Sort(0,Count-1); N:=1;
  { Wrapped paragraphs can cross pages. Keep their source transitions while
    folding repeated line/paragraph entries into one compact predecessor map.
    Repeated offsets (generated objects) refer to the first page of the object. }
  for I:=1 to Count-1 do begin
    if Result[I].Offset=Result[I-1].Offset then Continue;
    if Result[I].Page=Result[N-1].Page then Continue;
    Result[N]:=Result[I]; Inc(N);
  end;
  SetLength(Result,N);
end;
function FloatPageSettings(const Preamble:string; Body,Pitch:Integer; PixelsPerPoint:Double):TFloatPageSettings;
var P,Q,N:Integer; Command,Name,Value:string; V:Double; Format:TFormatSettings;
begin
  Result:=Default(TFloatPageSettings); Result.Body:=Max(1,Body); Result.Pitch:=Max(Body,Pitch);
  Result.InTextSep:=Round(12*PixelsPerPoint); Result.TextFloatSep:=Round(20*PixelsPerPoint);
  Result.FloatSep:=Round(12*PixelsPerPoint); Result.FloatPageSep:=Round(8*PixelsPerPoint);
  Result.TopNumber:=2; Result.BottomNumber:=1; Result.TotalNumber:=3;
  Result.TopFraction:=0.7; Result.BottomFraction:=0.3; Result.TextFraction:=0.2; Result.FloatPageFraction:=0.5;
  Format:=DefaultFormatSettings; Format.DecimalSeparator:='.'; P:=1;
  while P<=Length(Preamble) do begin
    SkipTeXSpace(Preamble,P); if P>Length(Preamble) then Break;
    if Preamble[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; Command:=ReadTeXCommand(Preamble,P);
    if (Command='setcounter') or (Command='setlength') or (Command='renewcommand') then begin
      SkipTeXSpace(Preamble,P); if Copy(Preamble,P,1)='*' then Inc(P);
      SkipTeXSpace(Preamble,P);
      if Copy(Preamble,P,1)='\' then Name:='\'+ReadTeXCommand(Preamble,P) else Name:=ReadTeXGroup(Preamble,P,'{','}');
      Value:=Trim(ReadTeXGroup(Preamble,P,'{','}'));
      if Command='setcounter' then begin
        if not TryStrToInt(Value,N) then Continue; N:=EnsureRange(N,0,100);
        case Name of 'topnumber':Result.TopNumber:=N; 'bottomnumber':Result.BottomNumber:=N; 'totalnumber':Result.TotalNumber:=N; end;
      end else if Command='renewcommand' then begin
        if not TryStrToFloat(Value,V,Format) then Continue; V:=EnsureRange(V,0,1);
        case Name of '\topfraction':Result.TopFraction:=V; '\bottomfraction':Result.BottomFraction:=V;
          '\textfraction':Result.TextFraction:=V; '\floatpagefraction':Result.FloatPageFraction:=V; end;
      end else begin
        N:=1; while (N<=Length(Value)) and (Value[N] in ['0'..'9','+','-','.']) do Inc(N);
        if not TryStrToFloat(Copy(Value,1,N-1),V,Format) then Continue;
        Value:=Trim(Copy(Value,N,MaxInt));
        if Copy(Value,1,2)='pt' then V:=V*PixelsPerPoint
        else if Copy(Value,1,2)='bp' then V:=V*PixelsPerPoint*72.27/72
        else if Copy(Value,1,2)='cm' then V:=V*PixelsPerPoint*72.27/2.54
        else if Copy(Value,1,2)='mm' then V:=V*PixelsPerPoint*72.27/25.4
        else if Copy(Value,1,2)='in' then V:=V*PixelsPerPoint*72.27 else Continue;
        N:=EnsureRange(Round(V),0,Body);
        case Name of '\intextsep':Result.InTextSep:=N; '\textfloatsep':Result.TextFloatSep:=N; '\floatsep':Result.FloatSep:=N; end;
      end;
    end else if ReadTeXDefinition(Preamble,Q) then P:=Q;
  end;
end;
procedure ReadPageFloat(const Source:string; out Kind,Placement:string);
var P,Q:Integer; Command,Name:string;
begin
  Kind:=''; Placement:=''; P:=1; SkipTeXSpace(Source,P);
  if Copy(Source,P,1)<>'\' then Exit; Q:=P; Command:=ReadTeXCommand(Source,P);
  if Command<>'begin' then Exit; Name:=ReadTeXGroup(Source,P,'{','}');
  if (Name<>'figure') and (Name<>'table') and (Name<>'figure*') and (Name<>'table*') then Exit;
  SkipTeXSpace(Source,P); if Copy(Source,P,1)='[' then Placement:=ReadTeXGroup(Source,P,'[',']');
  P:=EnvironmentEnd(Source,Q,Name);
  if P>Length(Source) then begin Placement:=''; Exit; end;
  ReadTeXCommand(Source,P); ReadTeXGroup(Source,P,'{','}'); SkipTeXSpace(Source,P);
  if P<=Length(Source) then begin Placement:=''; Exit; end;
  Kind:=StringReplace(Name,'*','',[]); if Placement='' then Placement:='tbp';
  if Trim(Placement)='h' then Placement:='ht';
end;
function LayoutPageBlocks(var Blocks:TPageBlocks; const Settings:TFloatPageSettings):Integer;
var Page,Cursor,TopUsed,BottomUsed,Total,LastPage:Integer;
    Tops,Bottoms,Heres,Pending:TIndices;
    Text:array of TLineReference;
    I,J,H,Y,Gap,Previous,Base:Integer; Forced:Boolean;
  procedure Add(var List:TIndices; Index:Integer);
  begin SetLength(List,Length(List)+1); List[High(List)]:=Index; end;
  function Allowed(Index:Integer; Position:Char):Boolean;
  begin Result:=Pos(Position,Blocks[Index].Placement)>0; end;
  function Relaxed(Index:Integer):Boolean;
  begin Result:=Allowed(Index,'!') or Allowed(Index,'H'); end;
  function Used(const List:TIndices):Integer;
  var Index:Integer;
  begin
    Result:=0; for Index in List do Inc(Result,Blocks[Index].NativeHeight);
    if Length(List)>0 then Inc(Result,(Length(List)-1)*Settings.FloatSep+Settings.TextFloatSep);
  end;
  function SameKind(const List:TIndices; Index:Integer):Boolean;
  var Other:Integer;
  begin Result:=False; for Other in List do if Blocks[Other].FloatKind=Blocks[Index].FloatKind then Exit(True); end;
  procedure Put(Index,Position:Integer);
  begin Blocks[Index].Top:=Page*Settings.Pitch+Position; LastPage:=Max(LastPage,Page); end;
  function Reserve(Index:Integer; AtTop:Boolean):Boolean;
  var Extra,Limit,Required,OldUsed,N,Position:Integer; Ref:TLineReference;
  begin
    Result:=False;
    if AtTop then begin
      if not Allowed(Index,'t') or SameKind(Heres,Index) or SameKind(Bottoms,Index) then Exit;
      Limit:=Settings.TopNumber; N:=Length(Tops); OldUsed:=TopUsed;
      Extra:=Blocks[Index].NativeHeight; if N=0 then Inc(Extra,Settings.TextFloatSep) else Inc(Extra,Settings.FloatSep);
      if not Relaxed(Index) and (TopUsed+Extra-Settings.TextFloatSep>Settings.Body*Settings.TopFraction) then Exit;
    end else begin
      if not Allowed(Index,'b') then Exit;
      Limit:=Settings.BottomNumber; N:=Length(Bottoms); OldUsed:=BottomUsed;
      Extra:=Blocks[Index].NativeHeight; if N=0 then Inc(Extra,Settings.TextFloatSep) else Inc(Extra,Settings.FloatSep);
      if not Relaxed(Index) and (BottomUsed+Extra-Settings.TextFloatSep>Settings.Body*Settings.BottomFraction) then Exit;
    end;
    if not Relaxed(Index) and ((N>=Limit) or (Total>=Settings.TotalNumber)) then Exit;
    Required:=Cursor; if not Relaxed(Index) then Required:=Max(Required,TopUsed+Round(Settings.Body*Settings.TextFraction));
    if Required+BottomUsed+Extra>Settings.Body then Exit;
    if AtTop then begin
      Add(Tops,Index); TopUsed:=Used(Tops); Extra:=TopUsed-OldUsed;
      for Ref in Text do Inc(Blocks[Ref.Block].Shifts[Ref.Line],Extra);
      for N in Heres do Inc(Blocks[N].Top,Extra);
      Inc(Cursor,Extra); Position:=0;
      for N in Tops do begin Put(N,Position); Inc(Position,Blocks[N].NativeHeight+Settings.FloatSep); end;
    end else begin
      Add(Bottoms,Index); BottomUsed:=Used(Bottoms); Position:=Settings.Body-BottomUsed+Settings.TextFloatSep;
      for N in Bottoms do begin Put(N,Position); Inc(Position,Blocks[N].NativeHeight+Settings.FloatSep); end;
    end;
    Inc(Total); Result:=True;
  end;
  procedure FloatPage(Count:Integer);
  var N,Height,Position,Stretch:Integer;
  begin
    Height:=0; for N:=0 to Count-1 do Inc(Height,Blocks[Pending[N]].NativeHeight);
    Inc(Height,Max(0,Count-1)*Settings.FloatPageSep);
    Stretch:=Max(0,(Settings.Body-Height) div Max(2,2*Count)); Position:=Stretch;
    for N:=0 to Count-1 do begin Put(Pending[N],Position); Inc(Position,Blocks[Pending[N]].NativeHeight+Settings.FloatPageSep+2*Stretch); end;
    Delete(Pending,0,Count); Inc(Page);
  end;
  procedure NextPage(Flush:Boolean=False);
  var N,Count,Height:Integer; Failed:TIndices;
  begin
    Inc(Page); Cursor:=0; TopUsed:=0; BottomUsed:=0; Total:=0;
    Tops:=nil; Bottoms:=nil; Heres:=nil; Text:=nil;
    while Length(Pending)>0 do begin
      Count:=0; Height:=0;
      for N in Pending do begin
        if not Flush and not Allowed(N,'p') then Break;
        if (Count>0) and (Height+Settings.FloatPageSep+Blocks[N].NativeHeight>Settings.Body) then Break;
        if Count>0 then Inc(Height,Settings.FloatPageSep); Inc(Height,Blocks[N].NativeHeight); Inc(Count);
      end;
      if (Count=0) or (not Flush and (Height<Settings.Body*Settings.FloatPageFraction)) then Break;
      FloatPage(Count);
    end;
    Failed:=nil;
    for N in Pending do if SameKind(Failed,N) or not (Reserve(N,True) or Reserve(N,False)) then Add(Failed,N);
    Pending:=Failed;
  end;
  procedure Here(Index:Integer; Pinned:Boolean);
  begin
    H:=Blocks[Index].NativeHeight; Gap:=Settings.InTextSep;
    if Cursor=0 then Gap:=0;
    if Pinned and (Cursor>TopUsed) and (Cursor+H+2*Gap+BottomUsed>Settings.Body) then begin NextPage; Gap:=0; end;
    Put(Index,Cursor+Gap); Inc(Cursor,H+2*Gap); Add(Heres,Index); Inc(Total);
  end;
begin
  Page:=0; Cursor:=0; TopUsed:=0; BottomUsed:=0; Total:=0; LastPage:=0;
  for I:=0 to High(Blocks) do begin
    Blocks[I].Height:=Blocks[I].NativeHeight; SetLength(Blocks[I].Shifts,Length(Blocks[I].Lines));
    if Blocks[I].NativeHeight=0 then begin
      for J:=0 to High(Blocks[I].Shifts) do Blocks[I].Shifts[J]:=0;
      Blocks[I].Top:=Page*Settings.Pitch+Cursor; Continue;
    end;
    if Blocks[I].FullPages and (Length(Blocks[I].Lines)>0) then begin
      { pdfpages ships complete sheets after flushing preceding text/floats. }
      if (Cursor>0) or (Total>0) or (Length(Pending)>0) then NextPage(True);
      for J:=0 to High(Blocks[I].Lines) do begin
        Blocks[I].Shifts[J]:=Page*Settings.Pitch; LastPage:=Max(LastPage,Page); NextPage;
      end;
      Continue;
    end;
    if Blocks[I].FloatKind<>'' then begin
      if Allowed(I,'H') then Here(I,True)
      else if SameKind(Pending,I) then Add(Pending,I)
      else if Allowed(I,'h') and (Relaxed(I) or (Total<Settings.TotalNumber)) and
        (Max(Cursor,TopUsed+Ord(not Relaxed(I))*Round(Settings.Body*Settings.TextFraction))+
         Blocks[I].NativeHeight+2*Settings.InTextSep+BottomUsed<=Settings.Body) then Here(I,False)
      else if not (Reserve(I,True) or Reserve(I,False)) then Add(Pending,I);
      Continue;
    end;
    Previous:=0; Forced:=False;
    if Length(Blocks[I].Lines)=0 then begin
      if (Cursor>TopUsed) and (Cursor+Blocks[I].NativeHeight+BottomUsed>Settings.Body) then NextPage;
      Blocks[I].Top:=Page*Settings.Pitch+Cursor; Inc(Cursor,Blocks[I].Height); LastPage:=Max(LastPage,Page);
    end;
    for J:=0 to High(Blocks[I].Lines) do begin
      H:=Max(1,Blocks[I].Lines[J].Bottom-Blocks[I].Lines[J].Top);
      Gap:=Max(0,Blocks[I].Lines[J].Top-Previous); Y:=Cursor+Gap;
      while Forced or ((Y+H+BottomUsed>Settings.Body) and (H<=Settings.Body)) do begin
        NextPage; Y:=Cursor; if J=0 then Inc(Y,Gap);
        Forced:=False;
        { An oversized object is displayed once rather than retrying forever. }
        if (Cursor=0) and (BottomUsed=0) and (Y+H>Settings.Body) then Break;
      end;
      Blocks[I].Shifts[J]:=Page*Settings.Pitch+Y;
      SetLength(Text,Length(Text)+1); Text[High(Text)].Block:=I; Text[High(Text)].Line:=J;
      Cursor:=Y+H; LastPage:=Max(LastPage,Page); Previous:=Blocks[I].Lines[J].Bottom; Forced:=Blocks[I].Lines[J].ForceAfter;
    end;
    if Length(Blocks[I].Lines)>0 then Inc(Cursor,Max(0,Blocks[I].NativeHeight-Previous));
    if Forced then NextPage;
  end;
  if Length(Pending)>0 then NextPage(True);
  for I:=0 to High(Blocks) do begin
    if Blocks[I].NativeHeight=0 then Continue;
    if Blocks[I].FloatKind<>'' then begin
      for J:=0 to High(Blocks[I].Shifts) do Blocks[I].Shifts[J]:=0;
    end else if Length(Blocks[I].Lines)>0 then begin
      Blocks[I].Top:=Blocks[I].Shifts[0]-Blocks[I].Lines[0].Top; Base:=Blocks[I].Top;
      for J:=0 to High(Blocks[I].Shifts) do Dec(Blocks[I].Shifts[J],Base+Blocks[I].Lines[J].Top);
      Blocks[I].Height:=Blocks[I].NativeHeight+Blocks[I].Shifts[High(Blocks[I].Shifts)];
    end;
  end;
  Result:=LastPage+1;
end;
end.
