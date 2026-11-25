unit CircuitGeometry;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, TikZGeometry, PlotGeometry;
type
  TCircuitPath=record Points:TTikZPoints; Closed,Filled,Upright:Boolean; end;
  TCircuitPaths=array of TCircuitPath;
  TCircuitPort=record Name:string; Position:TPlotPoint; end;
  TCircuitPorts=array of TCircuitPort;
  TCircuitSymbol=record
    Width,Height,StrokeScale,PolarityMargin:Double;
    Text,Positive,Negative:string;
    Paths:TCircuitPaths; Ports:TCircuitPorts; RoundCap:Boolean;
  end;
function CircuitKind(const Name:string):string;
function CircuitOptionName(const Name:string):string;
function CircuitShape(const Kind:string; IEC:Boolean=True; Inputs:Integer=2):TCircuitSymbol;
function CircuitikzShape(const Kind:string; Settings:TStrings):TCircuitSymbol;
implementation
uses Math, SysUtils, StrUtils;
function CircuitOptionName(const Name:string):string;
begin
  Result:=Trim(Name);
  if Pos('/tikz/circuitikz/',Result)=1 then Delete(Result,1,17)
  else if Pos('/tikz/',Result)=1 then Delete(Result,1,6);
end;
function CircuitKind(const Name:string):string;
var N:string;
begin
  N:=CircuitOptionName(Name); Result:='';
  case N of
    'R','resistor','resistor IEC','european resistor':Result:='resistor';
    'american resistor':Result:='zigzag';
    'vR','variable resistor','var resistor IEC':Result:='variable resistor';
    'C','capacitor','capacitor IEC':Result:='capacitor';
    'pC','polar capacitor','ecap':Result:='polar capacitor';
    'L','inductor','inductor IEC','cute inductor','american inductor':Result:='inductor';
    'D','diode','diode IEC','Do','D*':Result:='diode';
    'zD','zener','Zener diode','Zener diode IEC':Result:='Zener diode';
    'sD','Schottky diode','Schottky diode IEC':Result:='Schottky diode';
    'tD','tunnel diode','tunnel diode IEC':Result:='tunnel diode';
    'backward diode','backward diode IEC':Result:='backward diode';
    'breakdown diode','breakdown diode IEC':Result:='breakdown diode';
    'led','LED','leD':Result:='led'; 'photodiode','pD':Result:='photodiode';
    'battery','battery1','battery IEC':Result:='battery';
    'V','vsource','voltage source','voltage source IEC':Result:='voltage source';
    'I','isource','current source','current source IEC':Result:='current source';
    'sV','vsourcesin','ac source':Result:='ac source';
    'dc source':Result:='dc source'; 'cV','cvsource':Result:='controlled voltage source';
    'cI','cisource':Result:='controlled current source';
    'bulb','lamp','bulb IEC':Result:='bulb';
    'contact','contact IEC','circ':Result:='contact'; 'ocirc':Result:='open contact';
    'ground','ground IEC','gnd','sground':Result:='ground';
    'make contact','make contact IEC','spst','switch','nos':Result:='make contact';
    'break contact','break contact IEC','ncs','closing switch':Result:='break contact';
    'ammeter','amperemeter':Result:='amperemeter'; 'voltmeter':Result:='voltmeter'; 'ohmmeter':Result:='ohmmeter';
    'current direction','current direction''':Result:='current direction';
    'npn','pnp','njfet','pjfet','nmos','pmos','op amp','buffer':Result:=N;
    'short','wire':Result:='wire'; 'open':Result:='open';
    'and gate','nand gate','or gate','nor gate','xor gate','xnor gate','not gate','buffer gate':Result:=N;
    else begin
      if RightStr(N,3)=' US' then Result:=CircuitKind(Copy(N,1,Length(N)-3))
      else if RightStr(N,4)=' IEC' then Result:=CircuitKind(Copy(N,1,Length(N)-4));
    end;
  end;
end;
function CircuitShape(const Kind:string; IEC:Boolean; Inputs:Integer):TCircuitSymbol;
var I,N:Integer; X,Y,A:Double; P:TTikZPoints; Gate,Inverted:Boolean;
  function Point(X,Y:Double):TPlotPoint;
  begin Result:=Default(TPlotPoint); Result.X:=X; Result.Y:=Y; end;
  procedure Path(const Values:array of Double; Closed:Boolean=False; Filled:Boolean=False; Upright:Boolean=False);
  var I,N:Integer;
  begin
    N:=Length(Result.Paths); SetLength(Result.Paths,N+1); SetLength(Result.Paths[N].Points,Length(Values) div 2);
    for I:=0 to High(Result.Paths[N].Points) do Result.Paths[N].Points[I]:=Point(Values[I*2],Values[I*2+1]);
    Result.Paths[N].Closed:=Closed; Result.Paths[N].Filled:=Filled; Result.Paths[N].Upright:=Upright;
  end;
  procedure Circle(X,Y,Radius:Double; Filled:Boolean=False);
  var I,N:Integer;
  begin
    N:=Length(Result.Paths); SetLength(Result.Paths,N+1); SetLength(Result.Paths[N].Points,49);
    for I:=0 to 48 do Result.Paths[N].Points[I]:=Point(X+Radius*Cos(I*Pi/24),Y+Radius*Sin(I*Pi/24));
    Result.Paths[N].Closed:=True; Result.Paths[N].Filled:=Filled;
  end;
  procedure Port(const Name:string; X,Y:Double);
  var N:Integer;
  begin N:=Length(Result.Ports); SetLength(Result.Ports,N+1); Result.Ports[N].Name:=Name; Result.Ports[N].Position:=Point(X,Y); end;
  procedure Arrow(X,Y,DX,DY:Double);
  var L,UX,UY:Double;
  begin
    L:=Hypot(DX,DY); if L=0 then Exit; UX:=DX/L; UY:=DY/L;
    Path([X,Y,X+DX,Y+DY]);
    Path([X+DX,Y+DY,X+DX-0.35*UX+0.16*UY,Y+DY-0.35*UY-0.16*UX,
      X+DX-0.35*UX-0.16*UY,Y+DY-0.35*UY+0.16*UX],True,True);
  end;
begin
  Result:=Default(TCircuitSymbol); Result.Width:=2; Result.Height:=2;
  Gate:=Pos('gate',Kind)>0;
  if Gate then begin
    Inputs:=EnsureRange(Inputs,1,16); Result.Width:=3; Result.Height:=Max(2.5,(Inputs-1)*0.8+0.8);
    X:=Result.Width/2; Y:=Result.Height/2;
    Inverted:=(Kind='nand gate') or (Kind='nor gate') or (Kind='xnor gate') or (Kind='not gate');
    if (Kind='not gate') or (Kind='buffer gate') then begin Path([-X,-Y,-X,Y,X,0],True); Inputs:=1; end
    else if IEC then begin
      Path([-X,-Y,X,-Y,X,Y,-X,Y],True);
      if (Kind='and gate') or (Kind='nand gate') then Result.Text:='\&'
      else if (Kind='or gate') or (Kind='nor gate') then Result.Text:='$\geq 1$' else Result.Text:='$=1$';
    end else if (Kind='and gate') or (Kind='nand gate') then begin
      SetLength(P,27); P[0]:=Point(-X,-Y); P[1]:=Point(-X,Y); P[2]:=Point(0,Y);
      for I:=0 to 24 do P[2+I]:=Point(X*Cos(Pi/2-I*Pi/24),Y*Sin(Pi/2-I*Pi/24));
      N:=Length(Result.Paths); SetLength(Result.Paths,N+1); Result.Paths[N].Points:=Copy(P); Result.Paths[N].Closed:=True;
    end else begin
      SetLength(P,51);
      for I:=0 to 24 do begin A:=I/24; P[I]:=Point(-X+2*X*A,Y*(1-A*A)); end;
      for I:=0 to 24 do begin A:=1-I/24; P[25+I]:=Point(-X+2*X*A,-Y*(1-A*A)); end;
      P[50]:=Point(-X+0.38,0);
      N:=Length(Result.Paths); SetLength(Result.Paths,N+1); Result.Paths[N].Points:=Copy(P); Result.Paths[N].Closed:=True;
      if (Kind='xor gate') or (Kind='xnor gate') then begin
        Path([-X-0.2,-Y,-X+0.12,-Y/2,-X+0.18,0,-X+0.12,Y/2,-X-0.2,Y]);
      end;
    end;
    for I:=1 to Inputs do begin
      A:=0; if Inputs>1 then A:=(Inputs+1-2*I)*Result.Height/(2*Inputs);
      Port('input '+IntToStr(I),-X,A); Port('input'+IntToStr(I),-X,A);
    end;
    if Inputs=1 then Port('input',-X,0);
    if Inverted then begin Circle(X+0.18,0,0.18); Port('output',X+0.36,0); end else Port('output',X,0);
    Exit;
  end;
  if (Kind='resistor') or (Kind='zigzag') or (Kind='variable resistor') then begin
    Result.Width:=4; Result.Height:=1;
    if (Kind='zigzag') or not IEC then begin
      SetLength(P,10); P[0]:=Point(-2,0); P[9]:=Point(2,0);
      for I:=1 to 8 do P[I]:=Point(-2+(I-0.5)*0.5,IfThen(Odd(I),0.5,-0.5));
      SetLength(Result.Paths,1); Result.Paths[0].Points:=P;
    end else Path([-2,-0.5,2,-0.5,2,0.5,-2,0.5],True);
    if Kind='variable resistor' then Arrow(-1.3,-1,2.6,2);
  end else if (Kind='capacitor') or (Kind='polar capacitor') or (Kind='battery') then begin
    Result.Width:=0.5; Result.Height:=2;
    Path([-0.25,-1,-0.25,1]); Y:=1; if Kind='battery' then Y:=0.6;
    Path([0.25,-Y,0.25,Y]);
    if Kind='polar capacitor' then begin Path([-0.7,0.7,-0.7,1.1]); Path([-0.9,0.9,-0.5,0.9]); end;
  end else if Kind='inductor' then begin
    Result.Width:=4; Result.Height:=0.5; Result.RoundCap:=True; SetLength(P,97);
    for I:=0 to 96 do begin A:=(I mod 24)*Pi/24; P[I]:=Point(-2+I div 24+0.5*(1-Cos(A)),0.5*Sin(A)); end;
    SetLength(Result.Paths,1); Result.Paths[0].Points:=P;
  end else if (Pos('diode',Kind)>0) or (Kind='led') or (Kind='photodiode') then begin
    Result.Width:=1.25; Result.Height:=1.25;
    Path([-0.625,-0.625,-0.625,0.625,0.625,0],True); Path([0.625,-0.625,0.625,0.625]);
    if Kind='Zener diode' then begin Path([0.625,0.625,0.9,0.85]); Path([0.625,-0.625,0.35,-0.85]); end;
    if Kind='Schottky diode' then begin Path([0.35,0.35,0.35,0.625,0.9,0.625]); Path([0.9,-0.35,0.9,-0.625,0.35,-0.625]); end;
    if (Kind='tunnel diode') or (Kind='backward diode') then Path([0.35,0.625,0.625,0.625,0.625,-0.625,0.35,-0.625]);
    if Kind='breakdown diode' then Path([-0.3,0.625,0.3,0.625,0.3,-0.625,-0.3,-0.625]);
    if Kind='led' then begin Arrow(0,0.85,0.6,0.6); Arrow(0.6,0.85,0.6,0.6); end;
    if Kind='photodiode' then begin Arrow(0.7,1.5,-0.6,-0.6); Arrow(1.2,1.5,-0.6,-0.6); end;
  end else if (Kind='contact') or (Kind='open contact') then begin
    Result.Width:=0.5; Result.Height:=0.5; Circle(0,0,0.25,Kind='contact');
  end else if Kind='ground' then begin
    Result.Width:=0.75; Result.Height:=2;
    Path([-0.375,-1,-0.375,1]); Path([0,-2/3,0,2/3]); Path([0.375,-1/3,0.375,1/3]);
    Port('center',0,0);
  end else if (Kind='make contact') or (Kind='break contact') then begin
    Result.Width:=2; Result.Height:=1; Circle(-1,0,0.12); Circle(1,0,0.12);
    Y:=0.8; if Kind='break contact' then Y:=0;
    Path([-0.9,0,0.9,Y]);
  end else if (Kind='npn') or (Kind='pnp') or (Kind='nmos') or (Kind='pmos') or
    (Kind='njfet') or (Kind='pjfet') then begin
    Result.Width:=2; Result.Height:=2.5; Path([-1,0,-0.25,0]); Path([-0.25,-0.65,-0.25,0.65]);
    Path([-0.25,0.4,0.75,1.1,0.75,1.5]); Path([-0.25,-0.4,0.75,-1.1,0.75,-1.5]);
    if (Kind='npn') or (Kind='pnp') then begin
      if Kind='npn' then Arrow(0.1,-0.65,0.5,-0.35) else Arrow(0.6,-1,-0.5,0.35);
      Port('base',-1,0); Port('collector',0.75,1.5); Port('emitter',0.75,-1.5);
      Port('B',-1,0); Port('C',0.75,1.5); Port('E',0.75,-1.5);
    end else begin
      Path([-0.05,-0.65,-0.05,0.65]); Port('G',-1,0); Port('D',0.75,1.5); Port('S',0.75,-1.5);
      Port('gate',-1,0); Port('drain',0.75,1.5); Port('source',0.75,-1.5);
    end;
  end else if (Kind='op amp') or (Kind='buffer') then begin
    Result.Width:=3; Result.Height:=3; Path([-1.5,-1.5,-1.5,1.5,1.5,0],True);
    Port('+',-1.5,-0.65); Port('-',-1.5,0.65); Port('out',1.5,0);
    Path([-1.2,-0.65,-0.8,-0.65]); Path([-1,-0.85,-1,-0.45]); Path([-1.2,0.65,-0.8,0.65]);
  end else if Kind='current direction' then begin Result.Width:=1.2; Result.Height:=0.6; Arrow(-0.6,0,1.2,0); end
  else if (Kind<>'wire') and (Kind<>'open') then begin
    if Pos('controlled',Kind)=1 then Path([-1,0,0,1,1,0,0,-1],True) else Circle(0,0,1);
    if IEC and (Kind='current source') then Path([0,-1,0,1])
    else if IEC and (Kind='voltage source') then Path([-1,0,1,0])
    else if Pos('current',Kind)>0 then Arrow(-0.6,0,1.2,0)
    else if (Kind='ac source') then begin
      SetLength(P,33); for I:=0 to 32 do P[I]:=Point(-0.7+I*1.4/32,Sin(I*Pi/16)*0.35);
      N:=Length(Result.Paths); SetLength(Result.Paths,N+1); Result.Paths[N].Points:=P;
    end else if Kind='bulb' then begin Path([-0.7,-0.7,0.7,0.7]); Path([-0.7,0.7,0.7,-0.7]); end
    else if Kind='amperemeter' then Result.Text:='A'
    else if Kind='voltmeter' then Result.Text:='V'
    else if Kind='ohmmeter' then Result.Text:='$\Omega$'
    else begin
      Path([-0.7,-0.2,-0.7,0.2],False,False,True);
      Path([-0.9,0,-0.5,0],False,False,True); Path([0.5,0,0.9,0],False,False,True);
    end;
  end;
  Port('west',-Result.Width/2,0); Port('east',Result.Width/2,0);
end;
function CircuitikzShape(const Kind:string; Settings:TStrings):TCircuitSymbol;
var I,J,N,Count:Integer; Mode,Family,StyleFamily,ShapeName,Key,Value:string;
    W,H,RX,RY,LowerRX,LowerRY,X,Factor:Double; Fmt:TFormatSettings;
  function Number(const Key:string; Default:Double):Double;
  var Value:string;
  begin
    Result:=Default; if Settings=nil then Exit; Value:=Trim(Settings.Values[Key]);
    if (Length(Value)>1) and (Value[1]='{') and (Value[Length(Value)]='}') then Value:=Copy(Value,2,Length(Value)-2);
    if not TryStrToFloat(Value,Result,Fmt) then Result:=Default;
  end;
  procedure Add(X,Y:Double);
  begin
    Result.Paths[0].Points[N]:=Default(TPlotPoint); Result.Paths[0].Points[N].X:=X;
    Result.Paths[0].Points[N].Y:=Y; Inc(N);
  end;
  procedure Arc(Center,RX,RY,Start,Finish:Double);
  var K:Integer; A:Double;
  begin
    for K:=1 to 24 do begin A:=Start+(Finish-Start)*K/24; Add(Center+RX*Cos(A),RY*Sin(A)); end;
  end;
begin
  Result:=Default(TCircuitSymbol); Fmt:=DefaultFormatSettings; Fmt.DecimalSeparator:='.';
  case Kind of
    'resistor','zigzag':begin Family:='resistors'; Mode:='american'; end;
    'capacitor':begin Family:='capacitors'; Mode:=''; end;
    'inductor','american inductor','european inductor','cute inductor':begin Family:='inductors'; Mode:='cute'; end;
    'voltage source','current source','ac source','dc source':begin Family:='sources'; Mode:='european'; end;
    else Exit;
  end;
  StyleFamily:=Family;
  if Family='sources' then begin
    StyleFamily:='voltages'; if Kind='current source' then StyleFamily:='currents';
  end;
  if Settings<>nil then for I:=0 to Settings.Count-1 do begin
    Key:=Settings.Names[I]; Value:=Trim(Settings.ValueFromIndex[I]);
    if (Key='american') or (Key='european') then Mode:=Key;
    if (Family='resistors') and ((Key='resistor') or (Key='resistor/american') or (Key='resistor/european')) then begin
      if Key='resistor' then Mode:=Value else Mode:=Copy(Key,10,MaxInt);
    end;
    if (Family='inductors') and (Key='inductor') then Mode:=Value;
    if (Family='sources') and (Key=Copy(StyleFamily,1,Length(StyleFamily)-1)) then Mode:=Value;
    for J:=0 to 2 do begin
      case J of 0:Value:='american'; 1:Value:='european'; 2:Value:='cute'; end;
      if (Key=Value+' '+StyleFamily) or (Key=Value+' '+Copy(StyleFamily,1,Length(StyleFamily)-1)) or
         (Key=Value+StyleFamily) or (Key=Value+Copy(StyleFamily,1,Length(StyleFamily)-1)) then Mode:=Value;
    end;
  end;
  if Kind='zigzag' then Mode:='american';
  if Pos(' inductor',Kind)>0 then Mode:=Copy(Kind,1,Pos(' ',Kind)-1);
  if Family='resistors' then begin
    ShapeName:='resistor'; if Mode='european' then ShapeName:='generic';
  end else if Family='capacitors' then ShapeName:='capacitor'
  else if Family='sources' then begin
    case Kind of
      'current source':ShapeName:='isource'; 'ac source':ShapeName:='vsourcesin';
      'dc source':ShapeName:='dcvsource'; else ShapeName:='vsource';
    end;
    if ((Kind='voltage source') or (Kind='current source')) and (Mode='american') then ShapeName:=ShapeName+'am';
  end
  else if Mode='european' then ShapeName:='fullgeneric' else ShapeName:=Mode+'inductor';
  W:=0.8; H:=0.3;
  if Family='capacitors' then begin W:=0.2; H:=0.6; end
  else if Family='sources' then begin W:=0.6; H:=0.6; end
  else if ShapeName='cuteinductor' then W:=0.6;
  W:=Number('bipoles/'+ShapeName+'/width',Number(Family+'/width',W));
  H:=Number('bipoles/'+ShapeName+'/height',H);
  W:=EnsureRange(W,0.001,100); H:=EnsureRange(H,0.001,100);
  Result.Width:=W; Result.Height:=H; SetLength(Result.Paths,1); N:=0;
  if Family='sources' then begin
    Result:=CircuitShape(Kind,Mode='european'); RX:=Result.Width; RY:=Result.Height;
    for I:=0 to High(Result.Paths) do for J:=0 to High(Result.Paths[I].Points) do begin
      Result.Paths[I].Points[J].X:=Result.Paths[I].Points[J].X*W/RX;
      Result.Paths[I].Points[J].Y:=Result.Paths[I].Points[J].Y*H/RY;
    end;
    Result.Width:=W; Result.Height:=H;
    if (Kind='voltage source') and (Mode='american') then begin
      { pgfcircbipoles.tex anchors real math text inside the circle. The
        glyph height moves each text box inward from the margin anchor. }
      SetLength(Result.Paths,1); Result.PolarityMargin:=Number('bipoles/'+ShapeName+'/margin',0.7);
      Result.Positive:='$+$'; Result.Negative:='$\vphantom{+}-$';
      if Settings<>nil then begin
        Value:=Settings.Values['bipoles/'+ShapeName+'/inner plus']; if Value<>'' then Result.Positive:=Value;
        Value:=Settings.Values['bipoles/'+ShapeName+'/inner minus']; if Value<>'' then Result.Negative:=Value;
      end;
    end;
  end else if (ShapeName='generic') or (ShapeName='fullgeneric') then begin
    SetLength(Result.Paths[0].Points,4); Add(-W/2,-H/2); Add(W/2,-H/2); Add(W/2,H/2); Add(-W/2,H/2);
    Result.Paths[0].Closed:=True; Result.Paths[0].Filled:=ShapeName='fullgeneric';
  end else if Family='resistors' then begin
    Count:=EnsureRange(Round(Number('resistors/zigs',3)),1,64);
    SetLength(Result.Paths[0].Points,2*Count+2); Add(-W/2,0);
    for I:=0 to 2*Count-1 do Add(-W/2+(2*I+1)*W/(4*Count),IfThen(Odd(I),-H/2,H/2));
    Add(W/2,0);
  end else if Family='capacitors' then begin
    SetLength(Result.Paths,2); SetLength(Result.Paths[0].Points,2); Add(-W/2,-H/2); Add(-W/2,H/2);
    Result.Paths[1]:=Result.Paths[0]; Result.Paths[1].Points:=Copy(Result.Paths[0].Points);
    Result.Paths[1].Points[0].X:=W/2; Result.Paths[1].Points[1].X:=W/2;
  end else begin
    Count:=4; if ShapeName='cuteinductor' then Count:=5;
    Count:=EnsureRange(Round(Number('bipoles/'+ShapeName+'/coils',Number('inductors/coils',Count))),1,64);
    LowerRX:=0; LowerRY:=0;
    if ShapeName='cuteinductor' then begin
      LowerRY:=Number('bipoles/cuteinductor/lower coil height',0.15)/2;
      if Count>1 then LowerRX:=0.5*Number('bipoles/cuteinductor/coil aspect',0.5)*W/(Count-1);
      RY:=H/2;
    end else RY:=Number('bipoles/americaninductor/coil height',0.15);
    RX:=(W+2*(Count-1)*LowerRX)/(2*Count); X:=-W/2;
    SetLength(Result.Paths[0].Points,1+Count*24+(Count-1)*Ord(LowerRX>0)*24); Add(X,0);
    for I:=1 to Count do begin
      Arc(X+RX,RX,RY,Pi,0); X:=X+2*RX;
      if (I<Count) and (LowerRX>0) then begin Arc(X-LowerRX,LowerRX,LowerRY,0,-Pi); X:=X-2*LowerRX; end;
    end;
    Result.Height:=RY+LowerRY;
  end;
  { Dimensions and arc radii follow pgfcircbipoles.tex in units of Rlen. }
  Factor:=EnsureRange(Number(Family+'/scale',1),0.001,100);
  Result.StrokeScale:=EnsureRange(Number(Family+'/thickness',Number('bipoles/thickness',2)),0.001,100);
  Result.Width:=Result.Width*Factor; Result.Height:=Result.Height*Factor;
  for I:=0 to High(Result.Paths) do for J:=0 to High(Result.Paths[I].Points) do begin
    Result.Paths[I].Points[J].X:=Result.Paths[I].Points[J].X*Factor;
    Result.Paths[I].Points[J].Y:=Result.Paths[I].Points[J].Y*Factor;
  end;
  SetLength(Result.Ports,2); Result.Ports[0].Name:='west'; Result.Ports[0].Position:=Default(TPlotPoint);
  Result.Ports[0].Position.X:=-Result.Width/2; Result.Ports[1]:=Result.Ports[0];
  Result.Ports[1].Name:='east'; Result.Ports[1].Position.X:=Result.Width/2;
end;
end.
