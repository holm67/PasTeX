unit BeamerModel;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
type
  TBeamerSettings=record
    Enabled,Serif,SerifMath,TopAligned:Boolean;
    Mode,Theme,ColorTheme,FontTheme:string;
    FontPoints:Integer;
    PaperWidth,PaperHeight,LeftMargin,RightMargin:Double;
  end;
  TBeamerOverlay=record
    Active,Future,Alert:Boolean;
  end;
  TBeamerFrame=record
    First,BodyFirst,BodyAfter,After:Integer;
    TitleFirst,TitleAfter,SubtitleFirst,SubtitleAfter:Integer;
    Selection,DefaultOverlay,Options:string;
  end;
  TBeamerZoom=record
    LinkSlides,ZoomSlides,Options,X,Y,Width,Height:string;
    After:Integer;
  end;
function BeamerSettings(const Source:string):TBeamerSettings;
function ReadBeamerOverlay(const Source:string; var Position:Integer):string;
function DecodeBeamerOverlay(const Spec,Mode:string; Slide:Integer; var Pause:Integer):TBeamerOverlay;
function ReadBeamerFrame(const Source:string; First:Integer; out Frame:TBeamerFrame):Boolean;
function BeamerFrameBlock(const Source:string):Boolean;
function ReadBeamerZoom(const Source:string; First:Integer; out Zoom:TBeamerZoom):Boolean;
function BeamerCommand(const Name:string):Boolean;
function BeamerArgumentCount(const Name:string):Integer;
function BeamerEnvironment(const Name:string):Boolean;
function BeamerTheoremStyle(const Name:string):string;
implementation
uses Classes, SysUtils, Math, TeXMacros;
function BeamerArgumentCount(const Name:string):Integer;
begin
  Result:=-1;
  if (Name='alt') then Result:=2
  else if Name='temporal' then Result:=3
  else if (Name='frame') or (Name='column') or (Name='only') or (Name='onslide') or
    (Name='uncover') or (Name='visible') or (Name='invisible') or (Name='alert') or
    (Name='structure') or (Name='action') or (Name='frametitle') or (Name='framesubtitle') or
    (Name='usebeamerfont') or (Name='usebeamercolor') then Result:=1
  else if (Name='pause') or (Name='titlepage') or (Name='maketitle') then Result:=0;
end;
function BeamerCommand(const Name:string):Boolean;
begin
  Result:=(Name='only') or (Name='onslide') or (Name='uncover') or (Name='visible') or
    (Name='invisible') or (Name='alert') or (Name='structure') or (Name='alt') or
    (Name='temporal') or (Name='action') or (Name='pause') or (Name='frametitle') or
    (Name='framesubtitle') or (Name='titlepage') or (Name='maketitle') or (Name='framezoom') or
    (Name='usebeamerfont') or (Name='usebeamercolor');
end;
function BeamerEnvironment(const Name:string):Boolean;
begin
  Result:=(Name='frame') or (Name='block') or (Name='alertblock') or (Name='exampleblock') or
    (Name='columns') or (Name='column') or (Name='overlayarea') or (Name='overprint') or
    (Name='onlyenv') or (Name='uncoverenv') or (Name='visibleenv') or (Name='invisibleenv') or (Name='actionenv');
end;
function BeamerTheoremStyle(const Name:string):string;
begin
  Result:='';
  if (Name='theorem') or (Name='corollary') or (Name='fact') or (Name='lemma') or
    (Name='problem') or (Name='solution') then Result:='plain'
  else if (Name='definition') or (Name='definitions') then Result:='definition'
  else if (Name='example') or (Name='examples') then Result:='example'
  else if Name='proof' then Result:='proof';
end;
function BeamerSettings(const Source:string):TBeamerSettings;
var P,Q,I,N,D:Integer; Cmd,Name,Options,Item,Value:string; Items:TStringList; V:Double;
  procedure Aspect(const Value:string);
  begin
    case Value of
      '2013':begin V:=14; Result.PaperHeight:=9.1; end;
      '1610':begin V:=16; Result.PaperHeight:=10; end;
      '169':begin V:=16; Result.PaperHeight:=9; end;
      '149':begin V:=14; Result.PaperHeight:=9; end;
      '54':begin V:=12.5; Result.PaperHeight:=10; end;
      '43':begin V:=12.8; Result.PaperHeight:=9.6; end;
      '32':begin V:=13.5; Result.PaperHeight:=9; end;
      '141':begin V:=14.85; Result.PaperHeight:=10.5; end;
      else begin
        N:=StrToIntDef(Value,0); if N<11 then Exit;
        if N<1000 then D:=10 else D:=100;
        if N mod D=0 then Exit;
        Result.PaperHeight:=9.6; V:=9.6*(N div D)/(N mod D);
      end;
    end;
    Result.PaperWidth:=V*72.27/2.54; Result.PaperHeight:=Result.PaperHeight*72.27/2.54;
  end;
  function LengthValue(const Text:string; Default,Em:Double):Double;
  var P:Integer; F:TFormatSettings; Number:Double; UnitName:string;
  begin
    Result:=Default; P:=1;
    while (P<=Length(Text)) and (Text[P] in ['0'..'9','.','+','-']) do Inc(P);
    F:=DefaultFormatSettings; F.DecimalSeparator:='.';
    if not TryStrToFloat(Copy(Text,1,P-1),Number,F) then Exit;
    UnitName:=Trim(Copy(Text,P,MaxInt));
    case UnitName of
      'pt':Result:=Number; 'mm':Result:=Number*72.27/25.4; 'cm':Result:=Number*72.27/2.54;
      'in':Result:=Number*72.27; 'em':Result:=Number*Em; 'bp':Result:=Number*72.27/72;
    end;
    if IsNan(Result) or IsInfinite(Result) or (Result<0) then Result:=Default;
  end;
begin
  Result:=Default(TBeamerSettings); Result.FontPoints:=11; Result.Mode:='beamer'; Result.Theme:='default';
  Result.ColorTheme:='default'; Result.FontTheme:='default';
  Result.PaperWidth:=12.8*72.27/2.54; Result.PaperHeight:=9.6*72.27/2.54;
  Result.LeftMargin:=72.27/2.54; Result.RightMargin:=Result.LeftMargin;
  if Pos('beamer',Source)=0 then Exit;
  P:=1; Items:=TStringList.Create;
  try
    Items.StrictDelimiter:=True; Items.Delimiter:=',';
    while P<=Length(Source) do begin
      SkipTeXSpace(Source,P); if P>Length(Source) then Break;
      if Source[P]<>'\' then begin Inc(P); Continue; end;
      Q:=P; if ReadTeXDefinition(Source,Q) or SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
      Cmd:=ReadTeXCommand(Source,P);
      if Cmd='documentclass' then begin
        Options:=ReadTeXGroup(Source,P,'[',']'); Name:=ReadTeXGroup(Source,P,'{','}');
        Result.Enabled:=(Name='beamer') or (Name='ctexbeamer');
        if not Result.Enabled then Exit;
        Items.DelimitedText:=Options;
        for Item in Items do begin
          Value:=Trim(Item);
          case Value of
            'handout','trans':Result.Mode:=Value;
            't':Result.TopAligned:=True; 'c':Result.TopAligned:=False;
            'smaller':Result.FontPoints:=10; 'bigger':Result.FontPoints:=12;
            '8pt','9pt','10pt','11pt','12pt','14pt','17pt','20pt':Result.FontPoints:=StrToInt(Copy(Value,1,Length(Value)-2));
          end;
          if Copy(Value,1,12)='aspectratio=' then Aspect(Trim(Copy(Value,13,MaxInt)));
        end;
      end else if (Cmd='usetheme') or (Cmd='usecolortheme') or (Cmd='usefonttheme') then begin
        Options:=ReadTeXGroup(Source,P,'[',']'); Name:=ReadTeXGroup(Source,P,'{','}');
        if Cmd='usetheme' then Result.Theme:=Name
        else if Cmd='usecolortheme' then Result.ColorTheme:=Name
        else begin
          Result.FontTheme:=Name;
          if Name='serif' then begin
            Result.Serif:=True; Result.SerifMath:=True;
            if (Pos('onlymath',Options)>0) or (Pos('stillsansseriftext',Options)>0) then Result.Serif:=False;
            if Pos('stillsansserifmath',Options)>0 then Result.SerifMath:=False;
          end else if Name='professionalfonts' then Result.SerifMath:=True;
        end;
      end else if Cmd='setbeamersize' then begin
        Items.DelimitedText:=ReadTeXGroup(Source,P,'{','}');
        for Item in Items do begin
          I:=Pos('=',Item); Name:=Trim(Copy(Item,1,I-1)); Value:=Trim(Copy(Item,I+1,MaxInt));
          if Name='text margin left' then Result.LeftMargin:=LengthValue(Value,Result.LeftMargin,Result.FontPoints);
          if Name='text margin right' then Result.RightMargin:=LengthValue(Value,Result.RightMargin,Result.FontPoints);
        end;
      end;
    end;
  finally Items.Free; end;
end;
function ReadBeamerOverlay(const Source:string; var Position:Integer):string;
var P:Integer;
begin
  Result:=''; P:=Position; SkipTeXSpace(Source,P);
  if Copy(Source,P,1)<>'<' then Exit;
  Result:=ReadTeXGroup(Source,P,'<','>'); Position:=P;
end;
function DecodeBeamerOverlay(const Spec,Mode:string; Slide:Integer; var Pause:Integer):TBeamerOverlay;
var Text,Resolved,Part,Qualifier,Ranges,Token,Action:string; I,J,P,Q,First,Last,Colon,AtSign:Integer; N:Int64;
    Increment,Matched,Active,Future,HasRange:Boolean; Parts,Items:TStringList;
  function ModeMatches(const Value:string):Boolean;
  begin Result:=(Value=Mode) or (Value='all') or ((Value='presentation') and (Mode<>'article')); end;
begin
  Result:=Default(TBeamerOverlay); Result.Active:=True;
  Text:=Trim(Spec); if (Text<>'') and (Text[1]='<') then Delete(Text,1,1);
  if (Text<>'') and (Text[Length(Text)]='>') then Delete(Text,Length(Text),1);
  if Text='' then Exit;
  { beamerbasedecode.sty resolves relative specifications before decoding
    mode/action clauses, and advances beamerpauses once per specification. }
  Resolved:=''; Increment:=False; I:=1;
  while I<=Length(Text) do begin
    if Text[I] in ['+','.'] then begin
      N:=Pause; if Text[I]='+' then Increment:=True else Dec(N); Inc(I);
      if Copy(Text,I,1)='(' then begin
        J:=I+1; while (J<=Length(Text)) and (Text[J]<>')') do Inc(J);
        N:=EnsureRange(N+Int64(StrToIntDef(Trim(Copy(Text,I+1,J-I-1)),0)),Int64(0),Int64(MaxInt));
        I:=Min(J+1,Length(Text)+1);
      end;
      Resolved:=Resolved+IntToStr(Max(0,N));
    end else begin
      if not (Text[I] in [' ',#9,#10,#13]) then Resolved:=Resolved+Text[I]; Inc(I);
    end;
  end;
  if Increment and (Pause<MaxInt) then Inc(Pause);
  Parts:=TStringList.Create; Items:=TStringList.Create; Matched:=False;
  try
    Parts.StrictDelimiter:=True; Parts.Delimiter:='|'; Parts.DelimitedText:=Resolved;
    Items.StrictDelimiter:=True; Items.Delimiter:=',';
    for Part in Parts do begin
      Qualifier:='beamer'; Ranges:=Part; Action:=''; Colon:=Pos(':',Ranges);
      if Colon>0 then begin Qualifier:=Copy(Ranges,1,Colon-1); Ranges:=Copy(Ranges,Colon+1,MaxInt); end;
      AtSign:=Pos('@',Ranges);
      if AtSign>0 then begin Action:=Copy(Ranges,1,AtSign-1); Ranges:=Copy(Ranges,AtSign+1,MaxInt); end;
      if (Colon=0) and (AtSign=0) and (Ranges<>'') and (Ranges[1] in ['a'..'z']) then begin
        Qualifier:=Ranges; Ranges:='1-'; if not Matched then Result.Active:=False;
      end;
      if not ModeMatches(Qualifier) then Continue;
      Active:=False; Future:=False; HasRange:=False; Items.DelimitedText:=Ranges;
      for Token in Items do begin
        if Token='*' then begin Active:=True; HasRange:=True; Continue; end;
        P:=Pos('-',Token); Q:=Length(Token); First:=1; Last:=MaxInt;
        if P=0 then begin
          First:=StrToIntDef(Token,-1); Last:=First;
        end else begin
          if P>1 then First:=StrToIntDef(Copy(Token,1,P-1),-1);
          if P<Q then Last:=StrToIntDef(Copy(Token,P+1,MaxInt),-1);
        end;
        if (First<0) or (Last<First) then Continue;
        HasRange:=True; Active:=Active or ((Slide>=First) and (Slide<=Last));
        Future:=Future or (First>Slide) or ((Last<MaxInt) and (Last>Slide));
      end;
      if not HasRange then Continue;
      Result.Future:=Result.Future or Future;
      if Action='alert' then Result.Alert:=Result.Alert or Active
      else if Action='' then begin Result.Active:=Active; Matched:=True; end;
    end;
  finally Parts.Free; Items.Free; end;
end;
function ReadBeamerFrame(const Source:string; First:Integer; out Frame:TBeamerFrame):Boolean;
var P,Q,Start,Depth:Integer; Cmd,Name,Value:string; Braced:Boolean;
  procedure HeaderArgument(var A,B:Integer);
  var Q:Integer;
  begin
    Q:=P; SkipTeXSpace(Source,Q); if Copy(Source,Q,1)<>'{' then Exit;
    A:=Q+1; ReadTeXGroup(Source,Q,'{','}'); B:=Q;
    if Copy(Source,Q-1,1)='}' then Dec(B); P:=Q;
  end;
begin
  Result:=False; Frame:=Default(TBeamerFrame); P:=First; SkipTeXSpace(Source,P); Frame.First:=P;
  Cmd:=ReadTeXCommand(Source,P); Braced:=Cmd='frame';
  if not Braced then begin
    if Cmd<>'begin' then Exit;
    if ReadTeXGroup(Source,P,'{','}')<>'frame' then Exit;
  end;
  Frame.Selection:=ReadBeamerOverlay(Source,P);
  Q:=P; SkipTeXSpace(Source,Q);
  if Copy(Source,Q,1)='[' then begin
    Value:=ReadTeXGroup(Source,Q,'[',']'); P:=Q;
    if Copy(Trim(Value),1,1)='<' then Frame.DefaultOverlay:=Trim(Value) else Frame.Options:=Value;
    Q:=P; SkipTeXSpace(Source,Q);
    if (Frame.DefaultOverlay<>'') and (Copy(Source,Q,1)='[') then begin Frame.Options:=ReadTeXGroup(Source,Q,'[',']'); P:=Q; end;
  end;
  if Braced then begin
    SkipTeXSpace(Source,P); if Copy(Source,P,1)<>'{' then Exit;
    Frame.BodyFirst:=P+1; ReadTeXGroup(Source,P,'{','}'); Frame.After:=P; Frame.BodyAfter:=P;
    if Copy(Source,P-1,1)='}' then Dec(Frame.BodyAfter);
  end else begin
    HeaderArgument(Frame.TitleFirst,Frame.TitleAfter); HeaderArgument(Frame.SubtitleFirst,Frame.SubtitleAfter);
    Frame.BodyFirst:=P; Depth:=1;
    while P<=Length(Source) do begin
      SkipTeXSpace(Source,P); if P>Length(Source) then Break;
      if Source[P]<>'\' then begin Inc(P); Continue; end;
      Q:=P; if ReadTeXDefinition(Source,Q) or SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
      Start:=P; Cmd:=ReadTeXCommand(Source,P);
      if (Cmd<>'begin') and (Cmd<>'end') then Continue;
      Name:=ReadTeXGroup(Source,P,'{','}'); if Name<>'frame' then Continue;
      if Cmd='begin' then Inc(Depth) else Dec(Depth);
      if Depth=0 then begin Frame.BodyAfter:=Start; Frame.After:=P; Break; end;
    end;
    if Frame.After=0 then begin Frame.After:=Length(Source)+1; Frame.BodyAfter:=Frame.After; end;
  end;
  Result:=True;
end;
function BeamerFrameBlock(const Source:string):Boolean;
var P,Q:Integer; Frame:TBeamerFrame; Command:string;
begin
  P:=1;
  while P<=Length(Source) do begin
    SkipTeXSpace(Source,P); if P>Length(Source) then Break;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) or SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
    if ReadBeamerFrame(Source,P,Frame) then Exit(True);
    Command:=ReadTeXCommand(Source,P); if Command='maketitle' then Exit(True);
  end;
  Result:=False;
end;
function ReadBeamerZoom(const Source:string; First:Integer; out Zoom:TBeamerZoom):Boolean;
var P,I:Integer; Value:string;
begin
  Result:=False; Zoom:=Default(TBeamerZoom); P:=First;
  if ReadTeXCommand(Source,P)<>'framezoom' then Exit;
  Zoom.LinkSlides:=ReadBeamerOverlay(Source,P); Zoom.ZoomSlides:=ReadBeamerOverlay(Source,P);
  Zoom.Options:=ReadTeXGroup(Source,P,'[',']');
  Value:=ReadTeXGroup(Source,P,'(',')'); I:=TopLevelDelimiter(Value,','); if I=0 then Exit;
  Zoom.X:=Trim(Copy(Value,1,I-1)); Zoom.Y:=Trim(Copy(Value,I+1,MaxInt));
  Value:=ReadTeXGroup(Source,P,'(',')'); I:=TopLevelDelimiter(Value,','); if I=0 then Exit;
  Zoom.Width:=Trim(Copy(Value,1,I-1)); Zoom.Height:=Trim(Copy(Value,I+1,MaxInt));
  Zoom.After:=P; Result:=(Zoom.ZoomSlides<>'') and (Zoom.Width<>'') and (Zoom.Height<>'');
end;
end.
