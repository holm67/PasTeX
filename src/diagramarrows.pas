unit DiagramArrows;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type
  TArrowPoint=record X,Y:Double; end;
  TArrowContour=record
    Points:array of TArrowPoint;
    Filled:Boolean;
    PenWidth,Separation,ShaftInset:Double;
    StrokeColor,FillColor:string;
    Cap,Join:Integer;
  end;
  TArrowContours=array of TArrowContour;
  TCommutativeStyle=record
    StartTip,EndTip:string;
    DoubleLine,TripleLine,Dashed,Dotted,Phantom:Boolean;
  end;
function ArrowSpecification(const Value:string; out StartTip,EndTip:string):Boolean;
function ResolveArrowDefault(const Specification,DefaultTip:string; AtStart:Boolean):string;
function CommutativeStyle(const Defaults,Options:string):TCommutativeStyle;
function ArrowContours(const Kind:string; Weight,PixelsPerPoint:Double):TArrowContours;
function ArrowShaftInset(const Kind:string; Weight,PixelsPerPoint:Double):Double;
implementation
uses Classes, SysUtils, Math, TeXMacros, TeXStyles, TikZModel;
function Ungroup(const Value:string):string;
begin
  Result:=Trim(Value);
  if (Copy(Result,1,1)='{') and (Copy(Result,Length(Result),1)='}') then Result:=Copy(Result,2,Length(Result)-2);
end;
function ArrowSpecification(const Value:string; out StartTip,EndTip:string):Boolean;
var P,Depth:Integer; Code:string;
begin
  Code:=Ungroup(Value); Depth:=0; Result:=False; StartTip:=''; EndTip:='';
  if (Pos('"',Code)>0) or (Pos('\',Code)>0) then Exit;
  for P:=1 to Length(Code) do begin
    case Code[P] of '{','[':Inc(Depth); '}',']':Dec(Depth); end;
    if (Code[P]='-') and (Depth=0) then begin
      StartTip:=Ungroup(Copy(Code,1,P-1)); EndTip:=Ungroup(Copy(Code,P+1,MaxInt)); Exit(True);
    end;
  end;
end;
function ResolveArrowDefault(const Specification,DefaultTip:string; AtStart:Boolean):string;
var Code,Tip:string; P,A:Integer; C:Char;
begin
  Result:=''; Code:=Ungroup(Specification); P:=1;
  while P<=Length(Code) do begin
    C:=Code[P];
    if C='[' then begin A:=P; ReadTeXGroup(Code,P,'[',']'); Result:=Result+Copy(Code,A,P-A); Continue; end;
    if C in ['<','>'] then begin
      Tip:=DefaultTip; if (C='<')<>AtStart then Tip:='[reversed]'+Tip;
      Result:=Result+Tip+' ';
    end else Result:=Result+C;
    Inc(P);
  end;
  Result:=Trim(Result);
end;
function CommutativeStyle(const Defaults,Options:string):TCommutativeStyle;
var Item:TDiagramOption; Key,Value,A,B:string;
begin
  Result:=Default(TCommutativeStyle); Result.EndTip:='cm to';
  for Item in DiagramOptions(Defaults+','+Options) do begin
    Key:=Item.Name; Value:=Ungroup(Item.Value);
    if (Key='arrows') and ArrowSpecification(Value,A,B) or
       (not Item.HasValue and ArrowSpecification(Key,A,B)) then begin
      Result.StartTip:=A; Result.EndTip:=B; Continue;
    end;
    case Key of
      'rightarrow':begin Result.StartTip:=''; Result.EndTip:='cm to'; end;
      'leftarrow':begin Result.StartTip:='cm to'; Result.EndTip:=''; end;
      'leftrightarrow':begin Result.StartTip:='cm to'; Result.EndTip:='cm to'; end;
      'Rightarrow':begin Result.DoubleLine:=True; Result.StartTip:=''; Result.EndTip:='Implies'; end;
      'Leftarrow':begin Result.DoubleLine:=True; Result.StartTip:='Implies'; Result.EndTip:=''; end;
      'Leftrightarrow':begin Result.DoubleLine:=True; Result.StartTip:='Implies'; Result.EndTip:='Implies'; end;
      'maps to':Result.StartTip:='Bar';
      'mapsto':begin Result.StartTip:='Bar'; Result.EndTip:='cm to'; end;
      'mapsfrom':begin Result.StartTip:='cm to'; Result.EndTip:='Bar'; end;
      'Mapsto':begin Result.DoubleLine:=True; Result.StartTip:='Bar'; Result.EndTip:='Implies'; end;
      'Mapsfrom':begin Result.DoubleLine:=True; Result.StartTip:='Implies'; Result.EndTip:='Bar'; end;
      'hook':Result.StartTip:='Hooks[swap]';
      'hookrightarrow':begin Result.StartTip:='Hooks[swap]'; Result.EndTip:='cm to'; end;
      'hook''':Result.StartTip:='Hooks';
      'hookleftarrow':begin Result.StartTip:='cm to'; Result.EndTip:='Hooks'; end;
      'tail':Result.StartTip:='cm to[reversed]';
      'rightarrowtail':begin Result.StartTip:='cm to[reversed]'; Result.EndTip:='cm to'; end;
      'leftarrowtail':begin Result.StartTip:='cm to'; Result.EndTip:='cm to[reversed]'; end;
      'harpoon':Result.EndTip:='cm to[harpoon,swap]';
      'harpoon''':Result.EndTip:='cm to[harpoon]';
      'rightharpoonup':begin Result.StartTip:=''; Result.EndTip:='cm to[harpoon,swap]'; end;
      'rightharpoondown':begin Result.StartTip:=''; Result.EndTip:='cm to[harpoon]'; end;
      'leftharpoonup':begin Result.StartTip:='cm to[harpoon]'; Result.EndTip:=''; end;
      'leftharpoondown':begin Result.StartTip:='cm to[harpoon,swap]'; Result.EndTip:=''; end;
      'two heads':Result.EndTip:='cm double to';
      'twoheadrightarrow':begin Result.StartTip:=''; Result.EndTip:='cm double to'; end;
      'twoheadleftarrow':begin Result.StartTip:='cm double to'; Result.EndTip:=''; end;
      'to head':Result.EndTip:='cm to';
      'no head':Result.EndTip:=''; 'no tail':Result.StartTip:='';
      'dash':begin Result.StartTip:=''; Result.EndTip:=''; end;
      'equal','equals':begin Result.DoubleLine:=True; Result.StartTip:=''; Result.EndTip:=''; end;
      'double','double line':Result.DoubleLine:=True;
      'triple':Result.TripleLine:=True;
      'dashed':Result.Dashed:=True;
      'dashrightarrow':begin Result.Dashed:=True; Result.StartTip:=''; Result.EndTip:='cm to'; end;
      'dashleftarrow':begin Result.Dashed:=True; Result.StartTip:='cm to'; Result.EndTip:=''; end;
      'dotted':Result.Dotted:=True;
      'phantom':begin Result.Phantom:=True; Result.StartTip:=''; Result.EndTip:=''; end;
    end;
  end;
end;
function ArrowContours(const Kind:string; Weight,PixelsPerPoint:Double):TArrowContours;
const TipNames:array[0..41] of string=('Computer Modern Rightarrow','Classical TikZ Rightarrow',
  'cm double to','xy double to','Turned Square','Fast Triangle','Straight Barb','Triangle Cap',
  'Parenthesis','Tee Barb','Arc Barb','Round Cap','Butt Cap','Fast Round','cm left hook',
  'Rectangle','Triangle','Bracket','Diamond','Ellipse','Stealth','Implies','Circle','Square',
  'Hooks','Latex','LaTeX','stealth','latex','Kite','Rays','Hook','cm to','xy to','To','Bar','to','>','<','|','.','_');
var Name,Code:string; Options:TDiagramOptions; Item:TDiagramOption;
    L,W,X0,Y0,U,V,Angle,Shift,Scale,ScaleLength,ScaleWidth,Inset,Arc,PenWidth,Separation,Slant,WidthRatio,InsetRatio:Double;
    Front,BackY,Tip,BackX,Notch,Miter,Middle,HalfAngle:Double;
    StrokeColor,FillColor:string; Cap,Join:Integer; P,I,J,Count,Rays:Integer;
    Harpoon,Swap,Reversed,Open:Boolean; Format:TFormatSettings;
  procedure Path(Filled:Boolean=False);
  var N:Integer;
  begin
    N:=Length(Result); SetLength(Result,N+1); Result[N].Filled:=Filled;
    Result[N].PenWidth:=PenWidth; Result[N].Separation:=Separation; Result[N].StrokeColor:=StrokeColor;
    Result[N].FillColor:=FillColor; Result[N].Cap:=Cap; Result[N].Join:=Join;
  end;
  procedure Point(X,Y:Double);
  var N,K:Integer;
  begin
    K:=High(Result); N:=Length(Result[K].Points); SetLength(Result[K].Points,N+1);
    Result[K].Points[N].X:=X; Result[K].Points[N].Y:=Y;
  end;
  procedure Curve(X1,Y1,X2,Y2,X3,Y3:Double);
  var A:TArrowPoint; K:Integer; S,R:Double;
  begin
    A:=Result[High(Result)].Points[High(Result[High(Result)].Points)];
    for K:=1 to 16 do begin
      S:=K/16; R:=1-S;
      Point(R*R*R*A.X+3*R*R*S*X1+3*R*S*S*X2+S*S*S*X3,
        R*R*R*A.Y+3*R*R*S*Y1+3*R*S*S*Y2+S*S*S*Y3);
    end;
  end;
  procedure InsetPolygon;
  var Original:array of TArrowPoint; N,K,A,B:Integer; Area,Sign,D1,D2,DX1,DY1,DX2,DY2,X,Y,Den,T:Double;
  begin
    N:=Length(Result[High(Result)].Points)-1; if (N<3) or (PenWidth=0) then Exit;
    Original:=Copy(Result[High(Result)].Points); Area:=0;
    for K:=0 to N-1 do Area:=Area+Original[K].X*Original[K+1].Y-Original[K+1].X*Original[K].Y;
    Sign:=1; if Area<0 then Sign:=-1;
    for K:=0 to N-1 do begin
      A:=(K+N-1) mod N; B:=(K+1) mod N;
      DX1:=Original[K].X-Original[A].X; DY1:=Original[K].Y-Original[A].Y;
      DX2:=Original[B].X-Original[K].X; DY2:=Original[B].Y-Original[K].Y;
      D1:=Hypot(DX1,DY1); D2:=Hypot(DX2,DY2); Den:=DX1*DY2-DY1*DX2;
      if (D1<1e-8) or (D2<1e-8) or (Abs(Den)<1e-8) then Continue;
      X:=Original[K].X-Sign*DY1/D1*PenWidth/2; Y:=Original[K].Y+Sign*DX1/D1*PenWidth/2;
      T:=((Original[K].X-Sign*DY2/D2*PenWidth/2-X)*DY2-
          (Original[K].Y+Sign*DX2/D2*PenWidth/2-Y)*DX2)/Den;
      Result[High(Result)].Points[K].X:=X+T*DX1; Result[High(Result)].Points[K].Y:=Y+T*DY1;
    end;
    Result[High(Result)].Points[N]:=Result[High(Result)].Points[0];
  end;
  function Enabled(const Value:string):Boolean;
  begin Result:=(Value<>'false') and (Value<>'0'); end;
  function Dimension(const Value:string; Base:Double; LengthDependent:Boolean=False):Double;
  var Words:TStringList; Number:Double;
  begin
    Result:=0; Words:=TStringList.Create;
    try
      ExtractStrings([' ',#9],[],PChar(Ungroup(Value)),Words);
      if Words.Count>0 then Result:=TeXStyleDimension(Words[0],10)*PixelsPerPoint;
      if (Words.Count>1) and TryStrToFloat(Words[1],Number,Format) then Result:=Result+Number*Base;
      if (Words.Count>2) and LengthDependent and TryStrToFloat(Words[2],Number,Format) then Result:=Result+Number*Weight;
    finally Words.Free; end;
  end;
  function Compound(out Tips:TArrowContours):Boolean;
  var Position,Start,I,J,K,N:Integer; Tip,Global,Local:string;
      Parts:TStringList; Contours:TArrowContours; Offset,Extent,Spacing,LineOffset:Double;
  begin
    Result:=False; Parts:=TStringList.Create;
    try
      Position:=1; Global:='';
      if Copy(Code,Position,1)='[' then Global:=ReadTeXGroup(Code,Position,'[',']');
      while Position<=Length(Code) do begin
        SkipTeXSpace(Code,Position); Start:=Position; Tip:='';
        for I:=0 to High(TipNames) do if Copy(Code,Position,Length(TipNames[I]))=TipNames[I] then begin
          K:=Position+Length(TipNames[I]);
          if (K<=Length(Code)) and (Code[K] in ['a'..'z','A'..'Z']) then Continue;
          Tip:=TipNames[I]; Position:=K; Break;
        end;
        if (Tip='') or (Parts.Count>=16) then Exit;
        SkipTeXSpace(Code,Position); Local:=Global;
        if Copy(Code,Position,1)='[' then begin
          if Local<>'' then Local:=Local+','; Local:=Local+ReadTeXGroup(Code,Position,'[',']');
        end;
        if Local<>'' then Tip:=Tip+'['+Local+']'; Parts.Add(Tip);
        if Position=Start then Exit;
      end;
      if (Parts.Count<2) and (Global='') then Exit;
      Result:=True; Offset:=0; LineOffset:=-1;
      { The rightmost tip is at the end of the path; preceding tips extend
        backwards along the shaft, as in PGF's tip sequence syntax. }
      for I:=Parts.Count-1 downto 0 do begin
        if Copy(Parts[I],1,1)='.' then LineOffset:=Offset;
        Contours:=ArrowContours(Parts[I],Weight,PixelsPerPoint); Extent:=0; N:=Length(Tips);
        SetLength(Tips,N+Length(Contours));
        for J:=0 to High(Contours) do begin
          for K:=0 to High(Contours[J].Points) do begin
            Extent:=Max(Extent,-Contours[J].Points[K].X); Contours[J].Points[K].X:=Contours[J].Points[K].X-Offset;
          end;
          Tips[N+J]:=Contours[J];
        end;
        Spacing:=0; if Length(Contours)>0 then Spacing:=Contours[0].Separation;
        for J:=N to High(Tips) do begin
          Tips[J].ShaftInset:=Tips[J].ShaftInset+Offset; Spacing:=Max(Spacing,Tips[J].Separation);
        end;
        Offset:=Offset+Extent+Spacing;
      end;
      if LineOffset>=0 then for I:=0 to High(Tips) do Tips[I].ShaftInset:=LineOffset;
    finally Parts.Free; end;
  end;
begin
  Result:=nil; Code:=Ungroup(Kind); if (Code='') or (Code='none') then Exit;
  Format:=DefaultFormatSettings; Format.DecimalSeparator:='.';
  if Compound(Result) then Exit;
  P:=Pos('[',Code); Name:=Code; Options:=nil;
  if P>0 then begin Name:=Trim(Copy(Code,1,P-1)); Options:=DiagramOptions(Copy(Code,P+1,Length(Code)-P-1)); end;
  Harpoon:=False; Swap:=False; Reversed:=False; Open:=False; Scale:=1; ScaleLength:=1; ScaleWidth:=1; Rays:=4; Arc:=180; Inset:=-1;
  PenWidth:=Weight; Separation:=0; Slant:=0; Cap:=0; Join:=0; StrokeColor:=''; FillColor:=''; WidthRatio:=2.096774; InsetRatio:=0;
  case Name of
    'LaTeX':Name:='Latex'; 'To','Computer Modern Rightarrow':Name:='cm to';
    'Classical TikZ Rightarrow':Name:='to'; 'Rectangle':Name:='Rectangle';
  end;
  { Computer Modern tip dimensions and curves follow PGF arrows.meta. }
  L:=1.6*PixelsPerPoint+2.2*Weight; W:=2.096774*L;
  if (Name='cm to') or (Name='to') or (Name='>') or (Name='<') then begin Cap:=1; Join:=1; end;
  if (Name='xy to') or (Name='xy double to') then begin L:=5*PixelsPerPoint; W:=3.1*PixelsPerPoint; end;
  if (Name='Stealth') or (Name='Latex') then begin L:=3*PixelsPerPoint+4.5*Weight; WidthRatio:=0.75; end;
  if Name='Stealth' then InsetRatio:=0.325;
  if Name='Triangle' then begin L:=(2.7*PixelsPerPoint+3.6*Weight)*Cos(Pi/6); WidthRatio:=2*Tan(Pi/6); end;
  if (Name='Circle') or (Name='o') or (Name='*') or (Name='Ellipse') then begin
    L:=2.39365*PixelsPerPoint+3.191538*Weight; WidthRatio:=1;
  end;
  if Name='Ellipse' then begin L:=3.3*PixelsPerPoint+4.95*Weight; WidthRatio:=0.5; end;
  if Name='Square' then begin L:=2.12132*PixelsPerPoint+2.828427*Weight; WidthRatio:=1; end;
  if (Name='Kite') or (Name='Diamond') or (Name='Turned Square') then begin L:=3.6*PixelsPerPoint+5.4*Weight; WidthRatio:=0.5; InsetRatio:=0.25; end;
  if Name='Diamond' then InsetRatio:=0.5;
  if Name='Turned Square' then begin L:=3*PixelsPerPoint+4*Weight; WidthRatio:=1; InsetRatio:=0.5; end;
  if Name='Rectangle' then begin L:=3*PixelsPerPoint+4.5*Weight; WidthRatio:=0.5; end;
  if Name='Rays' then begin L:=3*PixelsPerPoint+4*Weight; WidthRatio:=1; end;
  if (Name='Arc Barb') or (Name='Straight Barb') then begin L:=1.5*PixelsPerPoint+2*Weight; WidthRatio:=2; end;
  if Name='Parenthesis' then begin L:=1.725*PixelsPerPoint+2.3*Weight; WidthRatio:=2; Arc:=120; end;
  if (Name='Hooks') or (Name='Hook') then begin L:=0.75*PixelsPerPoint+1.25*Weight; WidthRatio:=4; end;
  if (Name='Bar') or (Name='|') then begin L:=0; InsetRatio:=0.5; end;
  if Name='Tee Barb' then begin L:=1.5*PixelsPerPoint+2*Weight; InsetRatio:=0.5; end;
  if Name='Bracket' then begin L:=0.75*PixelsPerPoint+Weight; InsetRatio:=1; end;
  if (Name='Fast Triangle') or (Name='Fast Round') then Inset:=Weight/2;
  if Name='_' then Separation:=0.88*PixelsPerPoint+0.3*Weight;
  if (Name='Round Cap') or (Name='Butt Cap') or (Name='Triangle Cap') or
     (Name='Fast Triangle') or (Name='Fast Round') then begin L:=Weight/2; WidthRatio:=2; PenWidth:=0; end;
  { Length is an early key; width/inset primes depend on its final value. }
  for Item in Options do if Item.Name='length' then L:=Max(0,Dimension(Ungroup(Item.Value),Weight))
    else if Item.Name='angle' then begin
      P:=Pos(':',Item.Value); if P=0 then Continue;
      Angle:=StrToFloatDef(Copy(Item.Value,1,P-1),60,Format)/2;
      L:=Dimension(Copy(Item.Value,P+1,MaxInt),Weight)*Cos(DegToRad(Angle)); WidthRatio:=2*Tan(DegToRad(Angle));
    end;
  W:=WidthRatio*L;
  if (Name<>'Fast Triangle') and (Name<>'Fast Round') then Inset:=InsetRatio*L;
  if (Name='Hooks') or (Name='Hook') then W:=4*L-Weight;
  if (Name='xy to') or (Name='xy double to') then W:=3.1*PixelsPerPoint;
  if (Name='Bar') or (Name='|') or (Name='Tee Barb') or (Name='Bracket') then W:=3*PixelsPerPoint+4*Weight;
  for Item in Options do case Item.Name of
    'width':W:=Max(Weight,Dimension(Item.Value,Weight));
    'width''':W:=Max(Weight,Dimension(Item.Value,L,True));
    'inset':Inset:=Dimension(Item.Value,Weight);
    'inset''':Inset:=Dimension(Item.Value,L,True);
    'scale':Scale:=EnsureRange(StrToFloatDef(Item.Value,1,Format),0.01,100);
    'scale length':ScaleLength:=EnsureRange(StrToFloatDef(Item.Value,1,Format),0.01,100);
    'scale width':ScaleWidth:=EnsureRange(StrToFloatDef(Item.Value,1,Format),0.01,100);
    'harpoon':Harpoon:=Enabled(Item.Value); 'swap':Swap:=Enabled(Item.Value); 'reversed':Reversed:=Enabled(Item.Value);
    'left':Harpoon:=True; 'right':begin Harpoon:=True; Swap:=True; end;
    'open':Open:=Enabled(Item.Value); 'arc':Arc:=EnsureRange(StrToFloatDef(Item.Value,180,Format),1,359);
    'bend','flex','flex''','quick':; { These modify the optional bending library, not rigid tip geometry. }
    'slant':Slant:=EnsureRange(StrToFloatDef(Item.Value,0,Format),-100,100);
    'sep':begin if Item.Value='' then Separation:=0.88*PixelsPerPoint+0.3*Weight else Separation:=Dimension(Item.Value,Weight); end;
    'line width':PenWidth:=Max(0,Dimension(Item.Value,Weight));
    'line width''':PenWidth:=Max(0,Dimension(Item.Value,L,True));
    'color','draw':StrokeColor:=Ungroup(Item.Value);
    'fill':begin FillColor:=Ungroup(Item.Value); Open:=FillColor='none'; end;
    'round':begin Cap:=1; Join:=1; end; 'sharp':begin Cap:=0; Join:=0; end;
    'line cap':if Item.Value='round' then Cap:=1 else Cap:=0;
    'line join':if Item.Value='round' then Join:=1 else Join:=0;
    'n':Rays:=EnsureRange(StrToIntDef(Item.Value,4),2,64);
    'angle''':W:=2*L*Tan(DegToRad(EnsureRange(StrToFloatDef(Item.Value,60,Format),1,170)/2));
    else if not Item.HasValue then StrokeColor:=Item.Name;
  end;
  L:=Max(0.001,L*Scale*ScaleLength); W:=Max(0.001,W*Scale*ScaleWidth); Inset:=Inset*Scale*ScaleLength;
  if (Name='Round Cap') or (Name='Butt Cap') or (Name='Triangle Cap') or
    (Name='Fast Triangle') or (Name='Fast Round') then begin W:=Weight; PenWidth:=0; end;
  if (Name='Kite') or (Name='Diamond') or (Name='Turned Square') or (Name='Square') or (Name='Rectangle') or
    (Name='Circle') or (Name='Ellipse') then PenWidth:=Min(PenWidth,0.4*Min(L,W));
  case Name of
    '.','_':begin Path; Result[High(Result)].PenWidth:=0; end;
    'Bar','|','Tee Barb','Bracket':begin
      U:=Max(PenWidth/2,L-Inset); V:=Min(-PenWidth/2,-Inset);
      Path; Point(-U,-W/2+PenWidth/2); Point(-U,0);
      if not Harpoon then Point(-U,W/2-PenWidth/2);
      if L>PenWidth then begin
        Path; Point(V-U,-W/2+PenWidth/2); Point(0,-W/2+PenWidth/2);
        if not Harpoon then begin Path; Point(V-U,W/2-PenWidth/2); Point(0,W/2-PenWidth/2); end;
      end;
      for I:=0 to High(Result) do Result[I].ShaftInset:=Max(0,U+PenWidth/4);
    end;
    'Hooks','Hook','cm left hook':begin
      Path;
      for I:=0 to 48 do begin
        Angle:=DegToRad(-Arc/2+Arc*I/48); if Harpoon and (Angle>0) then Continue;
        Point(-L+L*Cos(Angle),-W/2+W/2*Sin(Angle));
      end;
    end;
    'Circle','o','*','Ellipse':begin
      Path(not Open and (Name<>'o'));
      for I:=0 to 48 do begin Angle:=2*Pi*I/48; Point(-L/2+(L-PenWidth)/2*Cos(Angle),(W-PenWidth)/2*Sin(Angle)); end;
    end;
    'Rays':begin
      for I:=0 to Rays-1 do begin
        Angle:=2*Pi*(I+0.5)/Rays; if Harpoon and (Sin(Angle)<0) then Continue;
        Path; Point(-L/2,0); Point(-L/2+L/2*Cos(Angle),W/2*Sin(Angle));
      end;
    end;
    'Arc Barb','Parenthesis':begin
      Path; for I:=0 to 48 do begin
        Angle:=DegToRad(-Arc/2+Arc*I/48); if Harpoon and (Angle<0) then Continue;
        Point(L*(Cos(Angle)-1),W/2*Sin(Angle));
      end;
    end;
    'Round Cap':begin
      Path(True); Point(-Weight,-W/2); Point(-L,-W/2);
      Curve(-L*0.447715,-W/2,0,-W*0.276142,0,0);
      Curve(0,W*0.276142,-L*0.447715,W/2,-L,W/2); Point(-Weight,W/2);
    end;
    'Butt Cap':begin Path(True); Point(0,-W/2); Point(0,W/2); Point(-Weight,W/2); Point(-Weight,-W/2); end;
    'Triangle Cap':begin Path(True); Point(0,0); Point(-L,W/2); Point(-L,-W/2); end;
    'Fast Triangle':begin
      Path(True); Point(-L-Inset,W/2); Point(-L,W/2); Point(0,0); Point(-L,-W/2); Point(-L-Inset,-W/2); Point(-Inset,0); Point(-L-Inset,W/2);
    end;
    'Fast Round':begin
      Path(True); Point(-L-Inset,W/2); Point(-L,W/2);
      Curve(-L*0.447715,W/2,0,W*0.276142,0,0); Curve(0,-W*0.276142,-L*0.447715,-W/2,-L,-W/2);
      Point(-L-Inset,-W/2); Curve(-L*0.447715-Inset,-W/2,-Inset,-W*0.276142,-Inset,0);
      Curve(-Inset,W*0.276142,-L*0.447715-Inset,W/2,-L-Inset,W/2);
    end;
    'Square','Rectangle','Diamond','Kite','Turned Square','Triangle','Stealth','Latex','latex','stealth':begin
      Path(not Open);
      if (Name='Square') or (Name='Rectangle') then begin Point(0,-W/2); Point(0,W/2); Point(-L,W/2); Point(-L,-W/2); end
      else if (Name='Diamond') or (Name='Kite') or (Name='Turned Square') then begin
        if Inset<0 then begin Inset:=L/2; if Name='Kite' then Inset:=L/4; end;
        Point(0,0); Point(-L+Inset,W/2); Point(-L,0); if not Harpoon then Point(-L+Inset,-W/2);
      end
      else if Name='Latex' then begin
        PenWidth:=Min(PenWidth,0.2*L); Result[High(Result)].PenWidth:=PenWidth;
        Front:=Sqrt(9*Sqr(L/W)+1)*PenWidth/2; Shift:=L-PenWidth/2; Tip:=L-Front-PenWidth/2;
        BackY:=W/2-PenWidth/2*(0.2333333*W+Hypot(0.3*L,0.2333333*W))/(0.3*L);
        Point(Tip-Shift,0); Curve(0.877192*Tip-Shift,0.077922*BackY,0.337381*Tip-Shift,0.519480*BackY,-Shift,BackY);
        if not Harpoon then begin
          Point(-Shift,-BackY); Curve(0.337381*Tip-Shift,-0.519480*BackY,0.877192*Tip-Shift,-0.077922*BackY,Tip-Shift,0);
        end;
      end else if Name='latex' then begin
        Point(0,0); Curve(-0.12*L,0.08*W,-0.66*L,0.52*W,-L,W/2);
        if not Harpoon then begin Point(-L,-W/2); Curve(-0.66*L,-0.52*W,-0.12*L,-0.08*W,0,0); end;
      end else if (Name='Stealth') or (Name='Triangle') then begin
        PenWidth:=Min(PenWidth,0.25*Max(0.001,L-Inset)); Result[High(Result)].PenWidth:=PenWidth;
        Front:=Sqrt(4*Sqr(L/W)+1)*PenWidth/2; Tip:=L-Front;
        U:=ArcTan2(L,W/2); Middle:=ArcTan2(Inset,W/2); HalfAngle:=(U-Middle)/2; Middle:=(U+Middle)/2;
        Miter:=PenWidth/2/Max(1e-8,Tan(HalfAngle)); BackX:=Sin(Middle)*Miter; BackY:=W/2-Cos(Middle)*Miter;
        Notch:=Inset+Sqrt(4*Sqr(Inset/W)+1)*PenWidth/2;
        Point(Tip-L,0); Point(BackX-L,BackY); if Name='Stealth' then Point(Notch-L,0);
        if not Harpoon then Point(BackX-L,-BackY);
      end else begin
        Point(0,0); Point(-L,W/2);
        if (Name='Stealth') or (Name='stealth') then begin if Inset<0 then Inset:=L*0.325; Point(-L+Inset,0); end;
        if not Harpoon then Point(-L,-W/2);
      end;
      Point(Result[High(Result)].Points[0].X,Result[High(Result)].Points[0].Y);
      if (Name='Kite') or (Name='Diamond') or (Name='Turned Square') or (Name='Square') or (Name='Rectangle') then InsetPolygon;
    end;
    ']',')':begin
      Path; Point(-L,-W/2);
      if (Name=']') or (Name='Bracket') then begin Point(0,-W/2); Point(0,W/2); Point(-L,W/2); end
      else Curve(L/3,-W/2,L/3,W/2,-L,W/2);
    end;
    else begin
      Count:=1; if (Name='cm double to') or (Name='xy double to') then Count:=2;
      for I:=0 to Count-1 do begin
        Shift:=I*Max(2*Weight,L*0.65); Path;
        if (Name='xy to') or (Name='xy double to') then begin
          { xypsdict.tex /XY: control points (-.1753,.0181),
            (-.3452,.0708), endpoint (-.5,.155), in font-size units. }
          Point(-L-Shift,W/2); Curve(-L*0.6904-Shift,W*0.0708/0.31,
            -L*0.3506-Shift,W*0.0181/0.31,-Shift,0);
          if not Harpoon then Curve(-L*0.3506-Shift,-W*0.0181/0.31,
            -L*0.6904-Shift,-W*0.0708/0.31,-L-Shift,-W/2);
        end else if (Name='>') or (Name='<') or (Name='Straight Barb') then begin
          Point(-L-Shift,W/2); Point(-Shift,0); if not Harpoon then Point(-L-Shift,-W/2);
        end else if (Name='Implies') then begin
          Point(-L-Shift,W*0.4); Curve(-L*0.8-Shift,W*0.18,-L*0.3-Shift,0,-Shift,0);
          Curve(-L*0.3-Shift,0,-L*0.8-Shift,-W*0.18,-L-Shift,-W*0.4);
        end else begin
          U:=Max(0.1,L-Weight); V:=Max(0.1,W-Weight); Point(-U-Shift,V/2);
          Curve(-0.81731*U-Shift,0.2*V,-0.41019*U-Shift,0.05833333*V,-Shift,0);
          if not Harpoon then Curve(-0.41019*U-Shift,-0.05833333*V,-0.81731*U-Shift,-0.2*V,-U-Shift,-V/2);
        end;
      end;
    end;
  end;
  if (Name='Fast Triangle') or (Name='Fast Round') then L:=L+Inset;
  if (Name='Circle') or (Name='o') or (Name='*') or (Name='Ellipse') or (Name='Square') or (Name='Rectangle') or
    (Name='Diamond') or (Name='Kite') or (Name='Turned Square') or (Name='Latex') or (Name='Triangle') then
    for I:=0 to High(Result) do Result[I].ShaftInset:=Max(0,L-PenWidth/2);
  if Name='Stealth' then for I:=0 to High(Result) do Result[I].ShaftInset:=Max(0,L-Notch+Weight/4);
  if (Name='Hooks') or (Name='Hook') or (Name='cm left hook') then
    for I:=0 to High(Result) do Result[I].ShaftInset:=L;
  if (Name='Round Cap') or (Name='Butt Cap') or (Name='Triangle Cap') or
    (Name='Fast Triangle') or (Name='Fast Round') then
    for I:=0 to High(Result) do if not Reversed then Result[I].ShaftInset:=L;
  for I:=0 to High(Result) do for J:=0 to High(Result[I].Points) do begin
    X0:=Result[I].Points[J].X; Y0:=Result[I].Points[J].Y;
    if Reversed then X0:=-L-X0;
    if Swap then Y0:=-Y0;
    X0:=X0+Slant*Y0;
    Result[I].Points[J].X:=X0; Result[I].Points[J].Y:=Y0;
  end;
end;
function ArrowShaftInset(const Kind:string; Weight,PixelsPerPoint:Double):Double;
var Contours:TArrowContours; Contour:TArrowContour;
begin
  Result:=0; Contours:=ArrowContours(Kind,Weight,PixelsPerPoint);
  for Contour in Contours do Result:=Max(Result,Contour.ShaftInset);
end;
end.
