unit TikZOptions;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes;
type
  TDiagramOptionContext=(ocGeneral,ocGrid,ocTicks,ocLineStyle,ocNodeStyle,ocPath,ocPlot,ocCoordinate,ocPic,
    ocPicture,ocScope,ocAxis,ocGroupPlot,ocNoOptions,ocTransform);
  TDiagramOptionContexts=set of TDiagramOptionContext;
  TDiagramOptionInfo=class
    Path,DefaultValue,Choices,Origin,ChildrenRoot,ForwardTo:string;
    TakesValue,Choice,Family,ValueRequired,ValueForbidden:Boolean;
    Contexts:TDiagramOptionContexts;
  end;
  TDiagramOptionCatalog=class
  private
    FKeys,FSearchRoots,FSetters:TStringList;
    function GetCount:Integer;
    function GetItem(Index:Integer):TDiagramOptionInfo;
    function DefineKey(const Path,Origin:string):TDiagramOptionInfo;
    procedure ReadKeys(const Text,Root,Origin:string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure ReadSource(const Text,Origin:string);
    procedure LoadInstalled(const Context:string; const Directory:string='');
    procedure CompleteChoices;
    function Find(const Path:string):TDiagramOptionInfo;
    function Available(Info:TDiagramOptionInfo; const Root:string; Context:TDiagramOptionContext=ocGeneral):Boolean;
    function ChildRoot(const Key,Root:string):string;
    function ChildContext(const Key,Root:string; Parent:TDiagramOptionContext):TDiagramOptionContext;
    property Count:Integer read GetCount;
    property Items[Index:Integer]:TDiagramOptionInfo read GetItem; default;
  end;
function DiagramOptionPath(const Name,Root:string):string;
function DiagramOptionName(const Path,Root:string):string;
function DiagramCommandOptions(const Command:string; out Root:string):TDiagramOptionContext;
function DiagramEnvironmentOptions(const Name:string; out Root:string):TDiagramOptionContext;
implementation
uses SysUtils, StrUtils, TeXMacros, TeXPackageSources, TikZModel;
function DiagramOptionPath(const Name,Root:string):string;
begin Result:=Trim(Name); if (Result<>'') and (Result[1]<>'/') then Result:=Root+'/'+Result; end;
function DiagramOptionName(const Path,Root:string):string;
begin Result:=Path; if Copy(Path,1,Length(Root)+1)=Root+'/' then Delete(Result,1,Length(Root)+1); end;
function DiagramCommandOptions(const Command:string; out Root:string):TDiagramOptionContext;
begin
  Root:='/tikz'; Result:=ocGeneral;
  case Command of
    'node','addlegendentry':Result:=ocNodeStyle;
    'coordinate':Result:=ocCoordinate;
    'draw','fill','filldraw','path','to','edge':Result:=ocPath;
    'pic':Result:=ocPic;
    'addplot','addplot3':begin Root:='/pgfplots'; Result:=ocPlot; end;
    'axis','semilogxaxis','semilogyaxis','loglogaxis','polaraxis':begin Root:='/pgfplots'; Result:=ocAxis; end;
    'groupplot':begin Root:='/pgfplots'; Result:=ocGroupPlot; end;
    'datavisualization':Root:='/tikz/data visualization';
    'data':Root:='/pgf/data';
    'graph':Root:='/tikz/graphs';
  end;
end;
function DiagramEnvironmentOptions(const Name:string; out Root:string):TDiagramOptionContext;
begin
  Root:='/tikz';
  case Name of
    'tikzpicture','circuitikz':Result:=ocPicture;
    'scope':Result:=ocScope;
    'axis','semilogxaxis','semilogyaxis','loglogaxis','polaraxis','smithchart','ternaryaxis':
      begin Root:='/pgfplots'; Result:=ocAxis; end;
    'groupplot':begin Root:='/pgfplots'; Result:=ocGroupPlot; end;
    'tikzcd':begin Root:='/tikz/commutative diagrams'; Result:=ocGeneral; end;
    else begin Root:=''; Result:=ocNoOptions; end;
  end;
end;
constructor TDiagramOptionCatalog.Create;
begin
  inherited; FKeys:=TStringList.Create; FKeys.OwnsObjects:=True; FKeys.UseLocale:=False; FKeys.Sorted:=True; FKeys.CaseSensitive:=True;
  FSearchRoots:=TStringList.Create; FSearchRoots.CaseSensitive:=True; FSearchRoots.UseLocale:=False;
  FSetters:=TStringList.Create; FSetters.CaseSensitive:=True; FSetters.UseLocale:=False;
end;
destructor TDiagramOptionCatalog.Destroy;
begin FSetters.Free; FSearchRoots.Free; FKeys.Free; inherited; end;
function TDiagramOptionCatalog.GetCount:Integer;
begin Result:=FKeys.Count; end;
function TDiagramOptionCatalog.GetItem(Index:Integer):TDiagramOptionInfo;
begin Result:=TDiagramOptionInfo(FKeys.Objects[Index]); end;
function TDiagramOptionCatalog.Find(const Path:string):TDiagramOptionInfo;
var I:Integer;
begin Result:=nil; if FKeys.Find(Path,I) then Result:=Items[I]; end;
function TDiagramOptionCatalog.DefineKey(const Path,Origin:string):TDiagramOptionInfo;
begin
  Result:=nil;
  if (Length(Path)>160) or (Pos('@',Path)>0) or (Pos('#',Path)>0) or (Pos('\',Path)>0) or
    (Pos('{',Path)>0) or (Pos('}',Path)>0) or (Pos(',',Path)>0) or (Pos('=',Path)>0) or (Pos('/.',Path)>0) then Exit;
  if (Copy(Path,1,6)<>'/tikz/') and (Copy(Path,1,10)<>'/pgfplots/') and (Copy(Path,1,5)<>'/pgf/') then Exit;
  Result:=Find(Path);
  if Result=nil then begin Result:=TDiagramOptionInfo.Create; Result.Path:=Path; Result.TakesValue:=True; FKeys.AddObject(Path,Result); end;
  Result.Origin:=Origin;
end;
procedure TDiagramOptionCatalog.ReadKeys(const Text,Root,Origin:string);
var Fields:TDiagramOptions; Field:TDiagramOption; Name,Handler,Base,Value,Child,Command,Arguments:string; P,Q:Integer; Info:TDiagramOptionInfo;
begin
  Fields:=DiagramOptions(Text); Base:=Root;
  for Field in Fields do begin
    if (Field.Name='new axis system') or (Field.Name='new axis') then begin
      P:=1; Name:=ReadTeXGroup(Field.Value,P,'{','}');
      if Name<>'' then begin
        Info:=DefineKey(DiagramOptionPath(Name,Base),Origin);
        if Info<>nil then begin
          Info.ChildrenRoot:=Info.Path;
          if Field.Name='new axis' then Info.ChildrenRoot:=DiagramOptionPath('axis options',Base);
        end;
      end;
      Continue;
    end;
    Name:=Trim(Field.Name); P:=Pos('/.',Name);
    if P>0 then begin Handler:=Trim(Copy(Name,P+2,MaxInt)); Name:=Trim(Copy(Name,1,P-1)); end
    else if Copy(Name,1,1)='.' then begin Handler:=Copy(Name,2,MaxInt); Name:=''; end
    else Continue;
    if Handler='cd' then begin if Name<>'' then Base:=DiagramOptionPath(Name,Base); Continue; end;
    Value:=Trim(Field.Value);
    if (Length(Value)>=2) and (Value[1]='{') and (Value[Length(Value)]='}') then Value:=Copy(Value,2,Length(Value)-2);
    if Handler='search also' then begin
      Child:=DiagramOptionPath(Name,Base); if Child='' then Child:=Base;
      FSearchRoots.Values[Child]:=Value; Continue;
    end;
    if Name='' then Continue;
    if not ((Handler='initial') or (Handler='default') or (Handler='style') or (Handler='is choice') or
      (Handler='is if') or (Handler='store in') or (Handler='estore in') or (Handler='is family') or
      (Handler='forward to') or (Handler='value required') or (Handler='value forbidden') or
      (Handler='expression') or (Copy(Handler,1,4)='code') or (Copy(Handler,1,5)='ecode') or
      (Copy(Handler,1,5)='style') or (Handler='append style') or (Handler='prefix style') or
      (Handler='append code') or (Handler='prefix code') or (Handler='add code') or (Handler='pic')) then Continue;
    Name:=DiagramOptionPath(Name,Base);
    if (Handler='pic') and (Copy(Name,1,6)='/tikz/') then Insert('pics/',Name,7);
    Info:=DefineKey(Name,Origin); if Info=nil then Continue;
    if Handler='is family' then begin Info.Family:=True; Continue; end;
    Info.Family:=False;
    if Handler='value required' then begin Info.ValueRequired:=True; Info.ValueForbidden:=False; Info.TakesValue:=True; Continue; end;
    if Handler='value forbidden' then begin Info.ValueForbidden:=True; Info.ValueRequired:=False; Info.TakesValue:=False; Continue; end;
    if Handler='forward to' then begin Info.ForwardTo:=DiagramOptionPath(Value,Base); Continue; end;
    P:=Pos('/.cd',Value);
    if P>0 then begin
      Q:=P-1; while (Q>0) and not (Value[Q] in ['{',',','}']) do Dec(Q);
      Child:=Trim(Copy(Value,Q+1,P-Q-1));
      if (Child<>'') and (Child[1]='/') and (Pos('\',Child)=0) then Info.ChildrenRoot:=Child;
    end;
    P:=1;
    while P<=Length(Value) do begin
      if Value[P]<>'\' then begin Inc(P); Continue; end;
      Command:=ReadTeXCommand(Value,P); Child:='';
      case Command of
        'pgfqkeys','pgfqkeysalso':Child:=ReadTeXGroup(Value,P,'{','}');
        'tikzset':Child:='/tikz'; 'pgfplotsset':Child:='/pgfplots'; 'pgfset':Child:='/pgf';
        else Child:=FSetters.Values[Command];
      end;
      if Child='' then Continue;
      Arguments:=ReadTeXGroup(Value,P,'{','}');
      if (Trim(Arguments)='#1') and (Child[1]='/') and (Pos('\',Child)=0) then Info.ChildrenRoot:=Child;
    end;
    if (Pos('store in',Handler)>0) or (Handler='expression') then Info.TakesValue:=True;
    if (Handler='initial') or (Handler='default') then begin
      if Handler='initial' then Info.TakesValue:=True;
      if (Pos('\',Value)=0) and (Pos('#',Value)=0) and (Length(Value)<160) then Info.DefaultValue:=Value;
    end else if Handler='is choice' then begin Info.Choice:=True; Info.TakesValue:=True; end
    else if Handler='is if' then begin Info.Choices:='true'+#10+'false'; Info.DefaultValue:='true'; end
    else if (Pos('style',Handler)>0) or (Pos('code',Handler)>0) or (Handler='pic') then begin
      if (Pos('append ',Handler)=1) or (Pos('prefix ',Handler)=1) or (Handler='add code') then
        Info.TakesValue:=Info.TakesValue or (Pos('#',Value)>0)
      else Info.TakesValue:=Info.ValueRequired or (Pos('#',Value)>0);
    end;
    if Info.ValueForbidden then Info.TakesValue:=False;
  end;
end;
procedure TDiagramOptionCatalog.ReadSource(const Text,Origin:string);
var Clean,Command,Root,Group,Name,Default,Setter:string; P,Start,Q,A:Integer; Info:TDiagramOptionInfo;
begin
  { Read registration syntax without executing TeX. Values may contain arbitrary
    nested code, so parse balanced groups rather than matching source lines. }
  Clean:=''; P:=1; Start:=1;
  while P<=Length(Text) do begin
    if Text[P]='\' then ReadTeXCommand(Text,P)
    else if Text[P]='%' then begin
      Clean:=Clean+Copy(Text,Start,P-Start); while (P<=Length(Text)) and not (Text[P] in [#10,#13]) do Inc(P); Start:=P;
    end else Inc(P);
  end;
  Clean:=Clean+Copy(Text,Start,MaxInt); P:=1;
  while P<=Length(Clean) do begin
    if Clean[P]<>'\' then begin Inc(P); Continue; end;
    Command:=ReadTeXCommand(Clean,P); Root:='';
    case Command of
      'def','gdef','newcommand','renewcommand','providecommand':begin
        Q:=P; SkipTeXSpace(Clean,Q); if Copy(Clean,Q,1)='*' then Inc(Q);
        if Copy(Clean,Q,1)='{' then begin
          Group:=ReadTeXGroup(Clean,Q,'{','}'); A:=1; Name:=ReadTeXCommand(Group,A);
        end else Name:=ReadTeXCommand(Clean,Q);
        if (Command='def') or (Command='gdef') then
          while (Q<=Length(Clean)) and (Clean[Q]<>'{') do Inc(Q)
        else begin ReadTeXGroup(Clean,Q,'[',']'); ReadTeXGroup(Clean,Q,'[',']'); end;
        Group:=ReadTeXGroup(Clean,Q,'{','}'); A:=1; Setter:=ReadTeXCommand(Group,A);
        if (Setter='pgfqkeys') or (Setter='pgfqkeysalso') then begin
          Root:=ReadTeXGroup(Group,A,'{','}'); Default:=Trim(ReadTeXGroup(Group,A,'{','}'));
          if (Name<>'') and ((Default='') or (Default='#1')) and (Copy(Root,1,1)='/') and
            (Pos('\',Root)=0) and (Pos('#',Root)=0) then begin FSetters.Values[Name]:=Root; P:=Q; end;
        end;
        Continue;
      end;
      'pgfdeclareshape','definecolor','providecolor','colorlet':begin
        Name:=ReadTeXGroup(Clean,P,'{','}'); if (Name='') or (Find('/tikz/'+Name)<>nil) then Continue;
        Info:=DefineKey('/tikz/'+Name,Origin); if Info=nil then Continue;
        Info.TakesValue:=False;
        if Command='pgfdeclareshape' then Info.Contexts:=[ocNodeStyle]
        else Info.Contexts:=[ocLineStyle,ocNodeStyle,ocPath,ocPlot,ocPic,ocPicture,ocScope,ocAxis,ocGroupPlot];
        Continue;
      end;
      'tikzset':Root:='/tikz'; 'pgfplotsset':Root:='/pgfplots'; 'pgfset':Root:='/pgf';
      'pgfkeys','pgfkeysalso':Root:='';
      'pgfqkeys','pgfqkeysalso':Root:=ReadTeXGroup(Clean,P,'{','}');
      'tikzdatavisualizationset':Root:='/tikz/data visualization';
      'tikzgraphsset':Root:='/tikz/graphs';
      'ctikzset':Root:='/tikz/circuitikz';
      'tikzoption':begin
        Name:=ReadTeXGroup(Clean,P,'{','}'); Default:=ReadTeXGroup(Clean,P,'[',']'); Group:=ReadTeXGroup(Clean,P,'{','}');
        ReadKeys(Name+'/.code={'+Group+'}', '/tikz',Origin);
        if Default<>'' then ReadKeys(Name+'/.default={'+Default+'}','/tikz',Origin); Continue;
      end;
      'pgfkeysdef','pgfkeysdefargs':begin
        Name:=ReadTeXGroup(Clean,P,'{','}'); if Command='pgfkeysdefargs' then ReadTeXGroup(Clean,P,'{','}');
        Group:=ReadTeXGroup(Clean,P,'{','}'); ReadKeys(Name+'/.code={'+Group+'}','',Origin); Continue;
      end;
      'pgfkeyssetvalue','pgfkeyslet':begin
        Name:=ReadTeXGroup(Clean,P,'{','}'); Group:=ReadTeXGroup(Clean,P,'{','}');
        if RightStr(Name,6)='/.@def' then ReadKeys(Copy(Name,1,Length(Name)-6)+'/.default={'+Group+'}','',Origin)
        else if Pos('/.',Name)=0 then ReadKeys(Name+'/.initial={'+Group+'}','',Origin);
        Continue;
      end;
      else begin Root:=FSetters.Values[Command]; if Root='' then Continue; end;
    end;
    Q:=P; SkipTeXSpace(Clean,Q);
    if Copy(Clean,Q,1)='{' then begin Group:=ReadTeXGroup(Clean,P,'{','}'); ReadKeys(Group,Root,Origin); end;
  end;
end;
procedure TDiagramOptionCatalog.CompleteChoices;
var I,J,Pass:Integer; Prefix,Value:string; Info,Target:TDiagramOptionInfo;
begin
  for I:=0 to Count-1 do begin
    Info:=Items[I]; if not Info.Choice then Continue; Prefix:=Info.Path+'/'; Info.Choices:=''; FKeys.Find(Prefix,J);
    while (J<Count) and (Copy(Items[J].Path,1,Length(Prefix))=Prefix) do begin
      Value:=Copy(Items[J].Path,Length(Prefix)+1,MaxInt);
      if Pos('/',Value)=0 then begin if Info.Choices<>'' then Info.Choices:=Info.Choices+#10; Info.Choices:=Info.Choices+Value; end; Inc(J);
    end;
  end;
  for Pass:=1 to 4 do for I:=0 to Count-1 do begin
    Info:=Items[I]; if Info.ForwardTo='' then Continue; Target:=Find(Info.ForwardTo); if Target=nil then Continue;
    Info.Choices:=Target.Choices; Info.TakesValue:=Target.TakesValue; Info.ValueRequired:=Target.ValueRequired;
    Info.ValueForbidden:=Target.ValueForbidden; Info.Contexts:=Target.Contexts;
    if Info.DefaultValue='' then Info.DefaultValue:=Target.DefaultValue;
    if Info.ChildrenRoot='' then Info.ChildrenRoot:=Target.ChildrenRoot;
  end;
end;
function TDiagramOptionCatalog.Available(Info:TDiagramOptionInfo; const Root:string; Context:TDiagramOptionContext):Boolean;
var Path,Parent,Search:string; P:Integer; Owner:TDiagramOptionInfo; SearchRoots:TDiagramOptions; SearchRoot:TDiagramOption;
  function Relevant:Boolean;
  var Key,Family:string; Drawing,Positioning,Node,Line,Plot,Defaults:Boolean;
  begin
    if Context=ocGeneral then Exit(True); Key:=Copy(Path,LastDelimiter('/',Path)+1,MaxInt);
    if Info.Contexts<>[] then Exit(Context in Info.Contexts);
    if Context in [ocGrid,ocTicks] then begin
      Result:=IndexStr(Key,['step','minor steps between steps','major','minor','subminor','common',
        'at','also at','major at','minor at','subminor at','major also at','minor also at','subminor also at',
        'options at','at default ticks','at default steps','at ticks','some','few','many','none','low','high','style'])>=0;
      if Context=ocTicks then Result:=Result or (Copy(Key,1,5)='tick ') or (Copy(Key,1,8)='no tick ') or (Key='node style');
      Exit;
    end;
    if Info.Origin='Document styles' then Exit(True);
    Drawing:=IndexStr(Key,['draw','fill','color','opacity','draw opacity','fill opacity',
      'line width','line cap','line join','miter limit','dash pattern','dash phase','solid','dashed','dotted',
      'densely dashed','loosely dashed','densely dotted','loosely dotted','dash dot','dash dot dot',
      'ultra thin','very thin','thin','semithick','thick','very thick','ultra thick','help lines',
      'rounded corners','sharp corners','pattern','pattern color','shade','shading','shading angle','double','double distance',
      'dash','dash expand off','cap','join','densely dash dot','loosely dash dot','densely dash dot dot','loosely dash dot dot',
      'dashdotted','densely dashdotted','loosely dashdotted','dashdotdotted','densely dashdotdotted','loosely dashdotdotted',
      'double distance between line centers','double equal sign distance','path fading','fit fading','fading angle','fading transform',
      'top color','middle color','bottom color','left color','right color','inner color','outer color','ball color',
      'opaque','transparent','nearly opaque','very nearly opaque','ultra nearly opaque','nearly transparent',
      'very nearly transparent','ultra nearly transparent','semitransparent','blend mode','blend group','transparency group'])>=0;
    Drawing:=Drawing or (Pos('patterns',Info.Origin)>0) or (Pos('shadings',Info.Origin)>0) or (Pos('fadings',Info.Origin)>0);
    Positioning:=IndexStr(Key,['at','rotate','rotate around','scale','scale around','xscale','yscale','shift','xshift','yshift','xslant','yslant',
      'transform shape','transform shape nonlinear','transform canvas','cm','x','y','z','reset cm','shift only',
      'rotate around x','rotate around y','rotate around z'])>=0;
    Node:=IndexStr(Key,['font','node font','text','text opacity','text width','text height','text depth','align',
      'anchor','shape','minimum size','minimum width','minimum height','name','alias','label','pin','pin distance','label distance',
      'inner sep','inner xsep','inner ysep','outer sep','outer xsep','outer ysep','row sep','column sep','matrix anchor','baseline',
      'above','below','left','right','above left','above right','below left','below right','circle','rectangle','ellipse','diamond',
      'node distance','pos','auto','swap','sloped','allow upside down','near start','near end','very near start','very near end',
      'at start','at end','midway','matrix','matrix of nodes','matrix of math nodes','nodes','every node','append after command',
      'behind path','in front of path','path picture','label position','pin position','node contents','ampersand replacement',
      'cells','every cell','every matrix','every label','every pin','every child node','after node path','prefix after command',
      'badness warnings for centered text','node halign header','centered','late options',
      'execute at begin node','execute at end node','execute at begin matrix','execute at end matrix',
      'execute at begin cell','execute at end cell','execute at empty cell',
      'above of','below of','left of','right of','above left of','above right of','below left of','below right of'])>=0;
    Node:=Node or (Copy(Key,1,5)='text ') or (Copy(Key,1,6)='label ') or (Copy(Key,1,4)='pin ') or
      (Pos('shapes',Info.Origin)>0) or (Pos('gates',Info.Origin)>0) or
      (Pos('tikzlibrarypositioning.',Info.Origin)>0) or (Pos('tikzlibraryfit.',Info.Origin)>0);
    Line:=IndexStr(Key,['arrows','>','<','tips','shorten >','shorten <','shorten >=','shorten <=','bend left','bend right',
      'in','out','in looseness','out looseness','looseness','in distance','out distance','min distance','max distance',
      'relative','to path','edge node','edge label','edge label''','decorate','decoration','name path','name path global',
      'use path','insert path','even odd rule','nonzero rule','clip','rounded rectangle','domain','samples','samples at',
      'smooth','smooth cycle','tension','mark','mark size','mark options','mark indices','mark phase','mark repeat',
      'only marks','sharp plot','const plot','const plot mark left','const plot mark right','ycomb','xcomb','jump mark left',
      'jump mark right','nodes','every node','font','node font','save path','preaction','postaction','use as bounding box',
      'double equal sign distance','dashdotted','densely dashdotted','loosely dashdotted',
      'dashdotdotted','densely dashdotdotted','loosely dashdotdotted','absolute','current point is local',
      'bend','bend pos','bend at start','bend at end','parabola height','radius','x radius','y radius',
      'start angle','end angle','delta angle','step','xstep','ystep','turn','path only','variable','parametric',
      'prefix','range','xrange','yrange','raw gnuplot','polar comb','no markers','sharp cycle',
      'edge from parent','edge from parent path','edge from parent macro','edge macro','snake'])>=0;
    Line:=Line or (Pos('intersections',Info.Origin)>0) or (Pos('decorations',Info.Origin)>0) or
      (Pos('plothandlers',Info.Origin)>0) or (Pos('plotmarks',Info.Origin)>0);
    if (Context=ocPlot) and (Copy(Path,1,10)='/pgfplots/') then Key:=Copy(Path,11,MaxInt);
    Plot:=IndexStr(Key,['domain','y domain','samples','samples y','samples at','variable','variable y','parametric',
      'mesh','surf','shader','scatter','scatter src','scatter classes','scatter/use mapped color','point meta','point meta min',
      'point meta max','point meta rel','colormap name','colormap access','z buffer','unbounded coords','filter discard warning',
      'x filter','y filter','z filter','filter point','restrict x to domain','restrict y to domain','restrict z to domain',
      'restrict expr to domain','each nth point','skip coords between index','forget plot','no marks','no markers',
      'only marks','only marks*','jump mark left','jump mark right','ybar','xbar','ybar interval','xbar interval',
      'bar width','bar shift','area legend','sharp plot','const plot','const plot mark left','const plot mark right',
      'smooth','tension','stack plots','fill between','boxplot','boxplot prepared','hist','patch','patch type',
      'nodes near coords','nodes near coords align','visualization depends on','cycle list','cycle list name',
      'cycle list shift','cycle multi list','cycle multiindex list','cycle list/Dark2','colorbar source',
      'discard if not','x expr','y expr','z expr','meta expr'])>=0;
    for Family in ['error bars/','mesh/','scatter/','patch/','quiver/','contour/','boxplot/','hist/','point meta/','colormap/'] do
      Plot:=Plot or (Copy(Key,1,Length(Family))=Family);
    { Picture/scope keys set drawing defaults; node placement and path syntax
      belong to their element editors. Both environments use tikzset in PGF. }
    Defaults:=Drawing or (Positioning and (Key<>'at')) or (Copy(Key,1,6)='every ') or
      (IndexStr(Key,['font','node font','text','text opacity','node distance','nodes','arrows','>','<','tips',
        'shorten >=','shorten <=','name prefix','name suffix','local bounding box','overlay','transparency group',
        'blend group','blend mode','isolation','on background layer','execute at begin scope','execute at end scope'])>=0);
    case Context of
      ocLineStyle:Result:=Drawing;
      ocNodeStyle:Result:=Drawing or Positioning or Node;
      ocPath:Result:=Drawing or Positioning or Line;
      ocPlot:begin
        if Copy(Path,1,10)='/pgfplots/' then Result:=Plot
        else Result:=Drawing or Positioning or Line;
      end;
      ocCoordinate:Result:=Positioning or (IndexStr(Key,['name','alias','label','pin','anchor','above','below','left','right',
        'above left','above right','below left','below right','node distance'])>=0) or (Pos('tikzlibrarypositioning.',Info.Origin)>0);
      ocPic:Result:=Drawing or Positioning or Line or (Copy(Key,1,4)='pic ') or (Copy(Path,1,11)='/tikz/pics/');
      ocPicture:Result:=Defaults or (IndexStr(Key,['baseline','trim left','trim right','remember picture',
        'execute at begin picture','execute at end picture','handle active characters in code','handle active characters in nodes'])>=0);
      ocScope:Result:=Defaults;
      ocTransform:Result:=Positioning;
      ocAxis,ocGroupPlot:begin
        if Copy(Path,1,10)='/pgfplots/' then begin
          Result:=Key<>'colorbar source'; { PGFPlots explicitly rejects this outside addplot. }
          if (Key='group style') or (Pos('axis group',Key)>0) then Result:=Context=ocGroupPlot;
        end else Result:=Defaults or (IndexStr(Key,['baseline','trim left','trim right'])>=0);
      end;
      else Result:=True;
    end;
  end;
begin
  if (Info=nil) or Info.Family or (Context=ocNoOptions) then Exit(False); Path:=Info.Path; Parent:=Path;
  repeat
    P:=LastDelimiter('/',Parent); if P<2 then Break;
    SetLength(Parent,P-1); Owner:=Find(Parent);
    { Values of a choice key belong to its value list, not the key list. }
    if (Owner<>nil) and Owner.Choice then Exit(False);
  until False;
  { A nested key family is not a list of keys accepted by its parent command. }
  Result:=(Copy(Path,1,Length(Root)+1)=Root+'/') and
    (Pos('/',Copy(Path,Length(Root)+2,MaxInt))=0);
  if (Context=ocPlot) and (Copy(Path,1,10)='/pgfplots/') then Result:=True;
  if (Context=ocPic) and (Copy(Path,1,11)='/tikz/pics/') then Result:=True;
  if (Context=ocGroupPlot) and (Copy(Path,1,16)='/pgfplots/group/') then
    Result:=Pos('/',Copy(Path,17,MaxInt))=0;
  { PGFPlots and datavisualization pass unknown drawing keys to TikZ/PGF.
    Nested families remain in their own editors. }
  if not Result and (Root='/pgfplots') then
    Result:=(Copy(Path,1,6)='/tikz/') and (Pos('/',Copy(Path,7,MaxInt))=0);
  if not Result and ((Root='/tikz') or (Root='/pgfplots')) then
    Result:=(Copy(Path,1,5)='/pgf/') and (Pos('/',Copy(Path,6,MaxInt))=0);
  if not Result then begin
    Search:=FSearchRoots.Values[Root];
    if Search<>'' then begin
      SearchRoots:=DiagramOptions(Search);
      for SearchRoot in SearchRoots do if
        (Copy(Path,1,Length(SearchRoot.Name)+1)=SearchRoot.Name+'/') and
        (Pos('/',Copy(Path,Length(SearchRoot.Name)+2,MaxInt))=0) then begin Result:=True; Break; end;
    end;
  end;
  Result:=Result and Relevant;
end;
function TDiagramOptionCatalog.ChildContext(const Key,Root:string; Parent:TDiagramOptionContext):TDiagramOptionContext;
begin
  Result:=ocGeneral;
  if (Root='/pgfplots') and (Key='group style') then Exit;
  if Key='every scope' then Exit(ocScope);
  if Key='every picture' then Exit(ocPicture);
  if Key='transform canvas' then Exit(ocTransform);
  if ((Root='/pgfplots') and ((Key='every axis') or (Key='axis style'))) or
    ((Root='/pgfplots/group') and (Key='every plot')) then Exit(ocAxis);
  if Pos('/data visualization',Root)>0 then begin
    if (Key='grid') or (Key='ticks and grid') then Exit(ocGrid);
    if Key='ticks' then Exit(ocTicks);
    if (Parent in [ocGrid,ocTicks]) and (IndexStr(Key,['major','minor','subminor','common'])>=0) then Exit(Parent);
  end;
  if (Key='edges') or (Key='edge style') or (Key='every edge') or (Key='every path') or
    (Key='preaction') or (Key='postaction') or (Key='every to') or (Key='mark options') then Exit(ocPath);
  if (Key='every plot') or (Key='plot style') then Exit(ocPlot);
  if (Root='/pgfplots') and (Pos('every axis plot',Key)=1) then Exit(ocPlot);
  if (Root='/pgfplots') and (Key='colorbar style') then Exit(ocAxis);
  if (Key='node style') or (Key='nodes') or (Key='every node') or
    (Pos('label',Key)>0) or (Pos('legend',Key)>0) or (Pos('text',Key)>0) then Exit(ocNodeStyle);
  if Pos('style',Key)>0 then Result:=ocLineStyle;
end;
function TDiagramOptionCatalog.ChildRoot(const Key,Root:string):string;
var Info:TDiagramOptionInfo;
begin
  if (Root='/tikz') and ((Key='>') or (Key='<')) then Exit('/pgf/arrow keys');
  if (Root='/pgfplots') and (Key='group style') then Exit('/pgfplots/group');
  if (Root='/pgfplots') and ((Key='every axis') or (Key='axis style')) then Exit(Root);
  if (Root='/pgfplots') and ((Pos('every axis plot',Key)=1) or (Key='colorbar style')) then Exit(Root);
  if (Root='/pgfplots/group') and (Key='every plot') then Exit('/pgfplots');
  Info:=Find(DiagramOptionPath(Key,Root));
  if (Info<>nil) and (Info.ChildrenRoot<>'') then Exit(Info.ChildrenRoot);
  if Pos('/data visualization',Root)>0 then begin
    if (Key='all axes') or (Key='x axis') or (Key='y axis') or (Key='z axis') then
      Exit('/tikz/data visualization/axis options');
    if IndexStr(Key,['grid','ticks','ticks and grid','major','minor','subminor','common'])>=0 then Exit('/tikz/data visualization');
  end;
  if (Pos('style',Key)>0) or (IndexStr(Key,['every node','every edge','every path','every scope','every picture','nodes','edges',
    'preaction','postaction','every to','every plot','mark options','transform canvas'])>=0) then Exit('/tikz');
  Result:=DiagramOptionPath(Key,Root);
end;
procedure TDiagramOptionCatalog.LoadInstalled(const Context:string; const Directory:string);
var Visited:TStringList; ReadBytes:Integer;
  procedure Scan(const Text,Origin,Base:string; Depth:Integer); forward;
  procedure Import(const Name,Base:string; Depth:Integer);
  var Path,Text:string;
  begin
    if (Depth>24) or (Visited.Count>=192) or (ReadBytes>8*1024*1024) or
      (Name='') or (Pos('\',Name)>0) or (Pos('#',Name)>0) then Exit;
    Path:=ResolveTeXSource(Name,Base);
    if (Path='') or (Visited.IndexOf(Path)>=0) then Exit; Visited.Add(Path);
    { Browsing options must not evict the renderer's package sources. }
    Text:=ReadTeXSource(Path,False,False); Inc(ReadBytes,Length(Text));
    Scan(Text,ExtractFileName(Path),ExtractFileDir(Path),Depth+1);
  end;
  procedure Scan(const Text,Origin,Base:string; Depth:Integer);
  var P,Q,A:Integer; Command,Names,Name,FileName,Prefix,Suffix:string; Parts:TStringList;
  begin
    { Follow literal imports instead of scanning the entire TeX installation.
      Definitions and examples must not activate libraries that were not loaded. }
    P:=1; Parts:=TStringList.Create;
    try
      Parts.StrictDelimiter:=True; Parts.Delimiter:=',';
      while P<=Length(Text) do begin
        SkipTeXSpace(Text,P); if P>Length(Text) then Break;
        if Text[P]<>'\' then begin Inc(P); Continue; end;
        Q:=P;
        if ReadTeXDefinition(Text,Q) or SkipTeXLiteral(Text,Q) then begin P:=Q; Continue; end;
        Command:=ReadTeXCommand(Text,P); if Command='endinput' then Break;
        Prefix:=''; Suffix:='';
        case Command of
          'usetikzlibrary':begin Prefix:='tikzlibrary'; Suffix:='.code.tex'; end;
          'usepgflibrary':begin Prefix:='pgflibrary'; Suffix:='.code.tex'; end;
          'usepgfmodule':begin Prefix:='pgfmodule'; Suffix:='.code.tex'; end;
          'usepgfplotslibrary':begin Prefix:='tikzlibrarypgfplots.'; Suffix:='.code.tex'; end;
          'usepackage','RequirePackage','RequirePackageWithOptions':begin ReadTeXGroup(Text,P,'[',']'); Suffix:='.sty'; end;
          'documentclass','LoadClass','LoadClassWithOptions':begin ReadTeXGroup(Text,P,'[',']'); Suffix:='.cls'; end;
          'input','pgfutil@input':;
          else Continue;
        end;
        SkipTeXSpace(Text,P); if P>Length(Text) then Break;
        if Text[P]='{' then Names:=ReadTeXGroup(Text,P,'{','}')
        else if Text[P]='[' then Names:=ReadTeXGroup(Text,P,'[',']')
        else begin
          A:=P; while (P<=Length(Text)) and not (Text[P] in [' ',#9,#10,#13,'%', '\','{','}']) do Inc(P);
          Names:=Copy(Text,A,P-A);
        end;
        Parts.DelimitedText:=Names;
        for Name in Parts do begin
          FileName:=Trim(Name);
          if (Prefix='') and (Suffix='') and (ExtractFileExt(FileName)='') then FileName:=FileName+'.tex';
          if (Command='usetikzlibrary') and (ResolveTeXSource(Prefix+FileName+Suffix,Base)='') then
            Import('pgflibrary'+FileName+Suffix,Base,Depth)
          else if (Command='usepgfplotslibrary') and (ResolveTeXSource(Prefix+FileName+Suffix,Base)='') then
            Import('pgflibrarypgfplots.'+FileName+Suffix,Base,Depth)
          else Import(Prefix+FileName+Suffix,Base,Depth);
        end;
      end;
    finally Parts.Free; end;
    ReadSource(Text,Origin);
  end;
begin
  FKeys.Clear; FSearchRoots.Clear; FSetters.Clear; Visited:=TStringList.Create; ReadBytes:=0;
  Visited.Sorted:=True; Visited.CaseSensitive:=True; Visited.UseLocale:=False;
  try
    Scan(Context,'Document styles',Directory,0);
    CompleteChoices;
  finally Visited.Free; end;
end;
end.
