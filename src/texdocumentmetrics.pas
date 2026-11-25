unit TeXDocumentMetrics;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
function DocumentTextWidth(const Preamble:string):Double;
function DocumentFontPoints(const Preamble:string):Integer;
function DocumentPreviewWidth(const Preamble:string; Zoom:Double=1):Integer;
function DocumentParagraphIndent(const Source:string; TextPoints:Double=0):Double;
function DocumentUsesCTeX(const Source:string):Boolean;
procedure DocumentPaperSize(const Preamble:string; out Width,Height:Double);
procedure DocumentPageArea(const Preamble:string; out Left,Top,Width,Height:Double);
procedure DocumentMarginNote(const Source:string; Page:Integer; out Width,Separation,Push:Double; out LeftSide:Boolean);
procedure DocumentMarginExtent(const Source:string; out Left,Right:Double);
implementation
uses Classes, SysUtils, Math, TeXMacros, BeamerModel;
function Dimension(const Value:string; Em,Paper,Text:Double; out Points:Double):Boolean;
var S,UnitName:string; P:Integer; Number:Double; Format:TFormatSettings;
begin
  S:=Trim(Value); P:=1;
  while (P<=Length(S)) and (S[P] in ['0'..'9','+','-','.']) do Inc(P);
  if P=1 then Number:=1 else begin
    Format:=DefaultFormatSettings; Format.DecimalSeparator:='.';
    if not TryStrToFloat(Copy(S,1,P-1),Number,Format) then Exit(False);
  end;
  UnitName:=Trim(Copy(S,P,MaxInt)); Result:=True;
  case UnitName of
    'pt':Points:=Number; 'bp':Points:=Number*72.27/72;
    'in':Points:=Number*72.27; 'cm':Points:=Number*72.27/2.54;
    'mm':Points:=Number*72.27/25.4; 'pc':Points:=Number*12;
    'em':Points:=Number*Em; 'ex':Points:=Number*Em*0.431;
    '\paperwidth':Points:=Number*Paper;
    '\textwidth','\linewidth','\columnwidth':Points:=Number*Text;
    else Result:=False;
  end;
  Result:=Result and not IsNan(Points) and not IsInfinite(Points) and (Points>0);
end;
procedure ClassOptions(const Preamble:string; out Options,Name:string);
var P:Integer; Cmd:string;
begin
  Options:=''; Name:='article'; P:=1;
  while P<=Length(Preamble) do begin
    if Preamble[P]='%' then begin while (P<=Length(Preamble)) and (Preamble[P]<>#10) do Inc(P); Continue; end;
    if Preamble[P]<>'\' then begin Inc(P); Continue; end;
    Cmd:=ReadTeXCommand(Preamble,P); if Cmd<>'documentclass' then Continue;
    SkipTeXSpace(Preamble,P); if Copy(Preamble,P,1)='[' then Options:=ReadTeXGroup(Preamble,P,'[',']');
    Name:=ReadTeXGroup(Preamble,P,'{','}'); Exit;
  end;
end;
procedure DocumentMarginNote(const Source:string; Page:Integer; out Width,Separation,Push:Double; out LeftSide:Boolean);
var Options,Name,Header,Command,Key,Value:string; P,Q:Integer; Paper,Height,Text,Points:Double; TwoSided:Boolean;
begin
  ClassOptions(Source,Options,Name); Header:='\documentclass['+Options+']{'+Name+'}';
  DocumentPaperSize(Header,Paper,Height); Text:=DocumentTextWidth(Header);
  TwoSided:=(Pos('twoside',Options)>0) or ((Pos('book',Name)>0) and (Pos('oneside',Options)=0));
  Separation:=11; if Pos('twocolumn',Options)>0 then Separation:=10; Push:=5;
  if TwoSided then Width:=0.6*(Paper-Text)-Separation-0.4*72.27
  else Width:=0.5*(Paper-Text)-Separation-0.8*72.27;
  Width:=Max(1,Trunc(Min(2*72.27,Width))); LeftSide:=TwoSided and not Odd(Max(1,Page)); P:=1;
  while P<=Length(Source) do begin
    SkipTeXSpace(Source,P); if P>Length(Source) then Break;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) then begin P:=Q; Continue; end;
    Command:=ReadTeXCommand(Source,P);
    if Command='reversemarginpar' then LeftSide:=not (TwoSided and not Odd(Max(1,Page)))
    else if Command='normalmarginpar' then LeftSide:=TwoSided and not Odd(Max(1,Page))
    else if (Command='setlength') or (Command='addtolength') then begin
      SkipTeXSpace(Source,P); if Copy(Source,P,1)='{' then Key:=ReadTeXGroup(Source,P,'{','}') else Key:='\'+ReadTeXCommand(Source,P);
      Value:=ReadTeXGroup(Source,P,'{','}');
      if not Dimension(Value,DocumentFontPoints(Source),Paper,Text,Points) then begin
        if Trim(Value)<>'0pt' then Continue; Points:=0;
      end;
      case Key of
        '\marginparwidth':if Command='setlength' then Width:=Points else Width:=Width+Points;
        '\marginparsep':if Command='setlength' then Separation:=Points else Separation:=Separation+Points;
        '\marginparpush':if Command='setlength' then Push:=Points else Push:=Push+Points;
      end;
    end;
  end;
  Width:=EnsureRange(Width,1,Paper); Separation:=EnsureRange(Separation,0,Paper); Push:=EnsureRange(Push,0,Height);
end;
function DocumentFontPoints(const Preamble:string):Integer;
var Options,Name:string; Items:TStringList; Slides:TBeamerSettings;
begin
  Slides:=BeamerSettings(Preamble); if Slides.Enabled then Exit(Slides.FontPoints);
  Result:=10; ClassOptions(Preamble,Options,Name); Items:=TStringList.Create;
  try
    Items.Delimiter:=','; Items.StrictDelimiter:=True; Items.DelimitedText:=Options;
    for Name in Items do begin
      if Trim(Name)='11pt' then Result:=11;
      if Trim(Name)='12pt' then Result:=12;
    end;
  finally Items.Free; end;
end;
procedure DocumentMarginExtent(const Source:string; out Left,Right:Double);
var P,Q,I:Integer; Name,Value,Optional,Header:string; Width,Separation,Push:Double; Side:Boolean;
begin
  Left:=0; Right:=0; P:=1;
  while P<=Length(Source) do begin
    SkipTeXSpace(Source,P); if P>Length(Source) then Break;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) or SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
    Name:=ReadTeXCommand(Source,P); if Name<>'marginpar' then Continue;
    Optional:=ReadTeXGroup(Source,P,'[',']'); Value:=ReadTeXGroup(Source,P,'{','}');
    if (Trim(Value)='') and (Trim(Optional)='') then Continue;
    Header:=Copy(Source,1,Q-1);
    for I:=1 to 2 do begin
      DocumentMarginNote(Header,I,Width,Separation,Push,Side);
      if Side then Left:=Max(Left,Width+Separation) else Right:=Max(Right,Width+Separation);
    end;
  end;
end;
function DocumentParagraphIndent(const Source:string; TextPoints:Double):Double;
var P,Q,A,BaseSize:Integer; Command,Target,Value,Options,ClassName,UnitToken:string; Size,Number,Points:Double; F:TFormatSettings;
  procedure SetIndent(const Text:string; Add:Boolean=False);
  var I:Integer; S:string;
  begin
    S:=Trim(Text); I:=1; while (I<=Length(S)) and (S[I] in ['0'..'9','+','-','.']) do Inc(I);
    if I=1 then Number:=1 else if not TryStrToFloat(Copy(S,1,I-1),Number,F) then Exit;
    UnitToken:=Trim(Copy(S,I,MaxInt)); Points:=0;
    case UnitToken of
      'pt':Points:=Number; 'bp':Points:=Number*72.27/72; 'pc':Points:=Number*12;
      'mm':Points:=Number*72.27/25.4; 'cm':Points:=Number*72.27/2.54; 'in':Points:=Number*72.27;
      'em','\ccwd':Points:=Number*Size; 'ex':Points:=Number*Size*0.431;
      else Exit;
    end;
    if not IsNan(Points) and not IsInfinite(Points) and (Abs(Points)<=500) then
      if Add then Result:=Result+Points else Result:=Points;
  end;
begin
  BaseSize:=DocumentFontPoints(Source); Size:=TextPoints; if Size<=0 then Size:=BaseSize;
  Result:=15; if BaseSize=11 then Result:=17 else if BaseSize=12 then Result:=18;
  F:=DefaultFormatSettings; F.DecimalSeparator:='.'; ClassOptions(Source,Options,ClassName);
  if Pos('ctex',ClassName)=1 then Result:=2*Size;
  if (ClassName='beamer') or (ClassName='ctexbeamer') then Result:=0;
  P:=1;
  while P<=Length(Source) do begin
    SkipTeXSpace(Source,P); if P>Length(Source) then Break;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) or SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
    Command:=ReadTeXCommand(Source,P);
    if (Command='usepackage') or (Command='RequirePackage') then begin
      ReadTeXGroup(Source,P,'[',']'); Value:=StringReplace(ReadTeXGroup(Source,P,'{','}'),' ','',[rfReplaceAll]);
      if (ClassName<>'beamer') and (ClassName<>'ctexbeamer') and
        (Pos(',ctex,',','+Value+',')>0) then Result:=2*Size;
      if Pos(',parskip,',','+Value+',')>0 then Result:=0;
    end else if (Command='setlength') or (Command='addtolength') then begin
      SkipTeXSpace(Source,P); Target:='';
      if Copy(Source,P,1)='{' then Target:=ReadTeXGroup(Source,P,'{','}')
      else if Copy(Source,P,1)='\' then Target:='\'+ReadTeXCommand(Source,P);
      Value:=ReadTeXGroup(Source,P,'{','}');
      if Target='\parindent' then SetIndent(Value,Command='addtolength');
    end else if Command='parindent' then begin
      SkipTeXSpace(Source,P); if Copy(Source,P,1)='=' then Inc(P); SkipTeXSpace(Source,P); A:=P;
      while (P<=Length(Source)) and not (Source[P] in [' ',#9,#10,#13,'\','{','}','%']) do Inc(P);
      SetIndent(Copy(Source,A,P-A));
    end;
  end;
end;
function DocumentUsesCTeX(const Source:string):Boolean;
var P,Q:Integer; Command,Value:string;
begin
  Result:=False; P:=1;
  while P<=Length(Source) do begin
    SkipTeXSpace(Source,P); if P>Length(Source) then Break;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Source,Q) or SkipTeXLiteral(Source,Q) then begin P:=Q; Continue; end;
    Command:=ReadTeXCommand(Source,P);
    if (Command='documentclass') or (Command='usepackage') or (Command='RequirePackage') then begin
      ReadTeXGroup(Source,P,'[',']'); Value:=StringReplace(ReadTeXGroup(Source,P,'{','}'),' ','',[rfReplaceAll]);
      if (Pos('ctex',Value)=1) or (Pos(',ctex,',','+Value+',')>0) then Exit(True);
    end;
  end;
end;
function DocumentDimensions(const Preamble:string; out PaperWidth,PageHeight:Double):Double;
var Options,Name,Cmd,Value,Target:string; P,Q,FontPoints:Integer;
    Paper,PaperHeight,LeftMargin,RightMargin,ExplicitWidth,V:Double;
    TwoColumns,GeometryLoaded:Boolean; Items:TStringList; Slides:TBeamerSettings;
  procedure PaperOption(const Option:string);
  begin
    case Trim(Option) of
      'letterpaper':begin Paper:=8.5*72.27; PaperHeight:=11*72.27; end;
      'a4paper':begin Paper:=210*72.27/25.4; PaperHeight:=297*72.27/25.4; end;
      'a5paper':begin Paper:=148*72.27/25.4; PaperHeight:=210*72.27/25.4; end;
      'b5paper':begin Paper:=176*72.27/25.4; PaperHeight:=250*72.27/25.4; end;
      'legalpaper':begin Paper:=8.5*72.27; PaperHeight:=14*72.27; end;
      'executivepaper':begin Paper:=7.25*72.27; PaperHeight:=10.5*72.27; end;
      'twocolumn':TwoColumns:=True;
      'onecolumn':TwoColumns:=False;
    end;
  end;
  procedure GeometryOptions(const Options:string);
  var Parts:TStringList; Part,Key,Val:string; K,Start,Depth:Integer;
  begin
    GeometryLoaded:=True; Parts:=TStringList.Create; Start:=1; Depth:=0;
    try
      for K:=1 to Length(Options)+1 do begin
        if K<=Length(Options) then begin if Options[K]='{' then Inc(Depth); if Options[K]='}' then Dec(Depth); end;
        if (K>Length(Options)) or ((Options[K]=',') and (Depth=0)) then begin Parts.Add(Trim(Copy(Options,Start,K-Start))); Start:=K+1; end;
      end;
      for Part in Parts do begin
        PaperOption(Part); K:=Pos('=',Part); if K=0 then Continue;
        Key:=Trim(Copy(Part,1,K-1)); Val:=Trim(Copy(Part,K+1,MaxInt));
        if not Dimension(Val,FontPoints,Paper,Result,V) then Continue;
        case Key of
          'paperwidth':Paper:=V;
          'paperheight':PaperHeight:=V;
          'textwidth','width':ExplicitWidth:=V;
          'margin','hmargin':begin LeftMargin:=V; RightMargin:=V; end;
          'left','lmargin','inner':LeftMargin:=V;
          'right','rmargin','outer':RightMargin:=V;
        end;
      end;
    finally Parts.Free; end;
  end;
begin
  Slides:=BeamerSettings(Preamble);
  if Slides.Enabled then begin
    PaperWidth:=Slides.PaperWidth; PageHeight:=Slides.PaperHeight;
    Exit(Max(1,PaperWidth-Slides.LeftMargin-Slides.RightMargin));
  end;
  Paper:=8.5*72.27; PaperHeight:=11*72.27; LeftMargin:=-1; RightMargin:=-1; ExplicitWidth:=-1;
  TwoColumns:=False; GeometryLoaded:=False; FontPoints:=DocumentFontPoints(Preamble);
  ClassOptions(Preamble,Options,Name); Items:=TStringList.Create;
  try
    if Pos('ctex',Name)=1 then PaperOption('a4paper');
    Items.Delimiter:=','; Items.StrictDelimiter:=True; Items.DelimitedText:=Options;
    for Value in Items do PaperOption(Value);
    if Items.IndexOf('landscape')>=0 then begin V:=Paper; Paper:=PaperHeight; PaperHeight:=V; end;
    Result:=345; if FontPoints=11 then Result:=360 else if FontPoints=12 then Result:=390;
    if TwoColumns then Result:=Paper-2*72.27 else Result:=Min(Result,Paper-2*72.27);
    P:=1;
    while P<=Length(Preamble) do begin
      if Preamble[P]='%' then begin while (P<=Length(Preamble)) and (Preamble[P]<>#10) do Inc(P); Continue; end;
      if Preamble[P]<>'\' then begin Inc(P); Continue; end;
      Cmd:=ReadTeXCommand(Preamble,P);
      if (Cmd='usepackage') or (Cmd='RequirePackage') then begin
        Options:=''; SkipTeXSpace(Preamble,P); if Copy(Preamble,P,1)='[' then Options:=ReadTeXGroup(Preamble,P,'[',']');
        Value:=ReadTeXGroup(Preamble,P,'{','}'); Items.DelimitedText:=Value;
        if Items.IndexOf('geometry')>=0 then GeometryOptions(Options);
      end else if Cmd='geometry' then GeometryOptions(ReadTeXGroup(Preamble,P,'{','}'))
      else if Cmd='setlength' then begin
        Target:=ReadTeXGroup(Preamble,P,'{','}');
        if Target='' then begin Q:=P; SkipTeXSpace(Preamble,Q); Target:='\'+ReadTeXCommand(Preamble,Q); P:=Q; end;
        Value:=ReadTeXGroup(Preamble,P,'{','}');
        if (Target='\textwidth') and Dimension(Value,FontPoints,Paper,Result,V) then ExplicitWidth:=V;
      end;
    end;
    if GeometryLoaded then begin
      if (LeftMargin<0) and (RightMargin<0) then Result:=Paper*0.7
      else if LeftMargin<0 then Result:=Paper-2*RightMargin
      else if RightMargin<0 then Result:=Paper-2*LeftMargin
      else Result:=Paper-LeftMargin-RightMargin;
    end;
    if ExplicitWidth>0 then Result:=ExplicitWidth;
    if TwoColumns then Result:=(Result-10)/2;
    Result:=EnsureRange(Result,20,4000);
    PaperWidth:=Paper; PageHeight:=PaperHeight;
  finally Items.Free; end;
end;
function DocumentTextWidth(const Preamble:string):Double;
var Width,Height:Double;
begin Result:=DocumentDimensions(Preamble,Width,Height); end;
procedure DocumentPaperSize(const Preamble:string; out Width,Height:Double);
begin DocumentDimensions(Preamble,Width,Height); end;
procedure DocumentPageArea(const Preamble:string; out Left,Top,Width,Height:Double);
var Paper,PaperHeight,Bottom,V,Baseline:Double; P,Q:Integer; Command,Options,Packages,Key,Value,Target:string; Parts:TStringList; Geometry:Boolean; Slides:TBeamerSettings;
  procedure ApplyOptions(const Text:string);
  var Part:string; K:Integer;
  begin
    if not Geometry then begin Top:=-1; Bottom:=-1; end;
    Geometry:=True; Parts.DelimitedText:=Text;
    for Part in Parts do begin
      K:=Pos('=',Part); if K=0 then Continue; Key:=Trim(Copy(Part,1,K-1)); Value:=Trim(Copy(Part,K+1,MaxInt));
      if not Dimension(Value,DocumentFontPoints(Preamble),PaperHeight,Height,V) then Continue;
      case Key of
        'margin','vmargin':begin Top:=V; Bottom:=V; end;
        'top','tmargin':Top:=V;
        'bottom','bmargin':Bottom:=V;
        'left','lmargin','inner':Left:=V;
        'textheight','height':begin Height:=V; Bottom:=-2; end;
      end;
    end;
  end;
begin
  Slides:=BeamerSettings(Preamble);
  if Slides.Enabled then begin
    Left:=Slides.LeftMargin; Top:=0; Width:=Max(1,Slides.PaperWidth-Left-Slides.RightMargin);
    Height:=Slides.PaperHeight; Exit;
  end;
  DocumentPaperSize(Preamble,Paper,PaperHeight); Width:=DocumentTextWidth(Preamble); Left:=(Paper-Width)/2;
  Baseline:=12; if DocumentFontPoints(Preamble)=11 then Baseline:=13.6 else if DocumentFontPoints(Preamble)=12 then Baseline:=14.5;
  Height:=Trunc((PaperHeight-3.5*72.27)/Baseline)*Baseline+DocumentFontPoints(Preamble);
  Top:=(PaperHeight-Height-30)/2; Bottom:=-1; Geometry:=False;
  Parts:=TStringList.Create; Parts.Delimiter:=','; Parts.StrictDelimiter:=True; P:=1;
  try
    while P<=Length(Preamble) do begin
      if Preamble[P]='%' then begin while (P<=Length(Preamble)) and (Preamble[P]<>#10) do Inc(P); Continue; end;
      if Preamble[P]<>'\' then begin Inc(P); Continue; end;
      Q:=P; if ReadTeXDefinition(Preamble,Q) then begin P:=Q; Continue; end;
      Command:=ReadTeXCommand(Preamble,P);
      if (Command='usepackage') or (Command='RequirePackage') then begin
        Options:=ReadTeXGroup(Preamble,P,'[',']'); Packages:=ReadTeXGroup(Preamble,P,'{','}');
        if Pos(',geometry,',','+StringReplace(Packages,' ','',[rfReplaceAll])+',')>0 then ApplyOptions(Options);
      end else if Command='geometry' then ApplyOptions(ReadTeXGroup(Preamble,P,'{','}'))
      else if Command='setlength' then begin
        Target:=ReadTeXGroup(Preamble,P,'{','}'); Value:=ReadTeXGroup(Preamble,P,'{','}');
        if (Target='\textheight') and Dimension(Value,DocumentFontPoints(Preamble),PaperHeight,Height,V) then begin Height:=V; Bottom:=-2; end;
      end;
    end;
    if Geometry and (Bottom<>-2) then begin
      if (Top<0) and (Bottom<0) then begin Top:=PaperHeight*0.12; Bottom:=PaperHeight*0.18; end
      else if Top<0 then Top:=Bottom else if Bottom<0 then Bottom:=Top;
      Height:=PaperHeight-Top-Bottom;
    end;
    if Top<0 then Top:=(PaperHeight-Height)/2;
    Height:=EnsureRange(Height,36,PaperHeight-24); Top:=EnsureRange(Top,0,PaperHeight-Height);
  finally Parts.Free; end;
end;
function DocumentPreviewWidth(const Preamble:string; Zoom:Double):Integer;
var Slides:TBeamerSettings;
begin
  Slides:=BeamerSettings(Preamble);
  if Slides.Enabled then Exit(Max(1,Round(Slides.PaperWidth*120*Zoom/72.27)+20));
  { Both previews include preview.sty's six TeX point border on each side. }
  Result:=Max(1,Round((DocumentTextWidth(Preamble)+12)*120*Zoom/72.27));
end;
end.
