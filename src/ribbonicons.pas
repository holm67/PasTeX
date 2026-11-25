unit RibbonIcons;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Controls, Buttons;
type TActionGlyphButton=class(TSpeedButton)
  public IconName:string;
end;
procedure RefreshRibbonIcons(Root:TWinControl);
implementation
uses Classes, SysUtils, Types, Graphics, ComCtrls, LResources, IntfGraphics, GraphType, FPImage, UITheme;
procedure SmoothIcon(Bitmap:TBitmap);
var Large,Small:TLazIntfImage; Pixel:TFPColor; X,Y,I,J,R,G,B:Integer;
begin
  Large:=Bitmap.CreateIntfImage; Small:=TLazIntfImage.Create(24,24,[riqfRGB]);
  try
    for Y:=0 to 23 do for X:=0 to 23 do begin
      R:=0; G:=0; B:=0;
      for J:=0 to 3 do for I:=0 to 3 do begin
        Pixel:=Large.Colors[X*4+I,Y*4+J]; Inc(R,Pixel.Red); Inc(G,Pixel.Green); Inc(B,Pixel.Blue);
      end;
      Pixel.Red:=R div 16; Pixel.Green:=G div 16; Pixel.Blue:=B div 16; Pixel.Alpha:=65535;
      Small.Colors[X,Y]:=Pixel;
    end;
    Bitmap.LoadFromIntfImage(Small);
  finally Small.Free; Large.Free; end;
end;
procedure RibbonGlyph(Button:TControl);
var Bitmap:TBitmap; Key,Letter,Asset,Name:string; Glyph:TIcon;
  procedure Line(X1,Y1,X2,Y2:Integer);
  begin Bitmap.Canvas.Line(X1*4,Y1*4,X2*4,Y2*4); end;
  procedure Box(X1,Y1,X2,Y2:Integer);
  begin Bitmap.Canvas.RoundRect(X1*4,Y1*4,X2*4,Y2*4,12,12); end;
  procedure Ellipse(X1,Y1,X2,Y2:Integer);
  begin Bitmap.Canvas.Ellipse(X1*4,Y1*4,X2*4,Y2*4); end;
  procedure Polyline(const Points:array of TPoint);
  var Scaled:array of TPoint; I:Integer;
  begin
    SetLength(Scaled,Length(Points));
    for I:=0 to High(Points) do Scaled[I]:=Point(Points[I].X*4,Points[I].Y*4);
    Bitmap.Canvas.Polyline(Scaled);
  end;
  procedure TextOut(X,Y:Integer; const Text:string);
  begin Bitmap.Canvas.TextOut(X*4,Y*4,Text); end;
  function Has(const Word:string):Boolean;
  begin Result:=Pos(Word,Key)>0; end;
  procedure AssignGlyph;
  var Normal,Strip:TLazIntfImage; Pixel,Background:TFPColor; X,Y,Gray:Integer;
  begin
    { Supply LCL's disabled glyph explicitly. Native widget sets otherwise
      disagree about disabled images, especially on dark backgrounds. }
    Normal:=Bitmap.CreateIntfImage; Strip:=TLazIntfImage.Create(48,24,[riqfRGB]);
    try
      Background:=Normal.Colors[0,0];
      for Y:=0 to 23 do for X:=0 to 23 do begin
        Pixel:=Normal.Colors[X,Y]; Strip.Colors[X,Y]:=Pixel;
        if (Pixel.Red<>Background.Red) or (Pixel.Green<>Background.Green) or (Pixel.Blue<>Background.Blue) then begin
          Gray:=(Pixel.Red*30+Pixel.Green*59+Pixel.Blue*11) div 100;
          Gray:=(Gray*2+(Background.Red+Background.Green+Background.Blue)) div 5;
          Pixel.Red:=Gray; Pixel.Green:=Gray; Pixel.Blue:=Gray;
        end;
        Strip.Colors[X+24,Y]:=Pixel;
      end;
      Bitmap.LoadFromIntfImage(Strip);
    finally Strip.Free; Normal.Free; end;
    Bitmap.TransparentColor:=UIBackground; Bitmap.Transparent:=True;
    if Button is TSpeedButton then begin TSpeedButton(Button).Glyph.Assign(Bitmap); TSpeedButton(Button).NumGlyphs:=2; end
    else if Button is TBitBtn then begin TBitBtn(Button).Glyph.Assign(Bitmap); TBitBtn(Button).NumGlyphs:=2; end;
  end;
begin
  Key:=LowerCase(Button.Name+' '+Button.Hint);
  if Button is TSpeedButton then Key:=Key+' '+LowerCase(TSpeedButton(Button).Caption)
  else if Button is TBitBtn then Key:=Key+' '+LowerCase(TBitBtn(Button).Caption);
  Asset:='';
  if (Button.HelpKeyword<>'') and (Button.HelpKeyword<>'literal') then Key:=Key+' '+LowerCase(Button.HelpKeyword);
  if (Button is TActionGlyphButton) and (TActionGlyphButton(Button).IconName<>'') then
    Key:='action:'+LowerCase(TActionGlyphButton(Button).IconName);
  if Has('action:') or Has('source / compiled pdf') or Has('drawingtool') or Has('drawingobject') or Has('go to preview position') or Has('show source position') or
    Has('paged layout') or Has('continuous layout') or Has('configure') then Asset:=''
  else if Has('equation environment list') then Asset:='equation-list'
  else if Has('refresh preview') then Asset:='refresh'
  else if Has('compiled pdf') then Asset:='pdf-preview'
  else if Has('export pdf') then Asset:='pdf-export'
  else if Has('document information') then Asset:='document-info'
  else if Has('preamble and document') then Asset:='preamble'
  else if Has('compiler log') then Asset:='compiler-log'
  else if Has('full document source') then Asset:='document-source'
  else if Has('visual editor') then Asset:='visual-editor'
  else if not Has('history') then
    for Name in ['superscript','subscript','fraction','integral','infinity','equation','paragraph','selectall',
      'heading','preview','source','settings','italic','bold','alpha','beta','root','sum','undo','redo','save','paste','copy','cut','open','new','log','pi'] do
      if Has(Name) then begin Asset:=Name; Break; end;
  Bitmap:=TBitmap.Create;
  try
    if Asset<>'' then begin
      if DarkMode then Asset:=Asset+'-dark' else Asset:=Asset+'-light';
      if LazarusResources.Find(Asset)<>nil then begin
        Bitmap.SetSize(24,24); Bitmap.Canvas.Brush.Color:=UIBackground; Bitmap.Canvas.FillRect(Rect(0,0,24,24));
        Glyph:=TIcon.Create;
        try Glyph.LoadFromLazarusResource(Asset); Glyph.Current:=Glyph.GetBestIndexForSize(Size(24,24)); Bitmap.Canvas.Draw(0,0,Glyph);
        finally Glyph.Free; end;
        AssignGlyph; Exit;
      end;
    end;
    { Supersample procedural icons so Qt, GTK and Win32 share smooth strokes. }
    Bitmap.SetSize(96,96);
    with Bitmap.Canvas do begin
      Brush.Color:=UIBackground; FillRect(Rect(0,0,96,96)); Brush.Style:=bsClear;
      Pen.Color:=InkColor; Pen.Width:=8; Pen.EndCap:=pecRound; Pen.JoinStyle:=pjsRound;
      Font.Color:=InkColor; Font.Name:='DejaVu Sans'; Font.Size:=44;
    end;
    if Key='action:calculate' then begin
      Box(3,2,21,22); Line(6,7,18,7); Line(6,13,12,13); Line(9,10,9,16);
      Line(15,12,18,12); Line(15,15,18,15);
    end
    else if Key='action:run' then begin
      Box(2,3,22,21); Polyline([Point(8,7),Point(17,12),Point(8,17),Point(8,7)]);
    end
    else if Key='action:plot' then begin
      Polyline([Point(3,3),Point(3,21),Point(22,21)]);
      Polyline([Point(5,17),Point(9,9),Point(13,15),Point(20,4)]);
    end
    else if Key='action:insert' then begin
      Box(3,3,17,21); Line(6,8,13,8); Line(6,12,11,12);
      Line(18,12,18,22); Line(13,17,23,17);
    end
    else if Key='action:download' then begin
      Line(12,2,12,16); Polyline([Point(6,10),Point(12,16),Point(18,10)]);
      Polyline([Point(3,16),Point(3,22),Point(21,22),Point(21,16)]);
    end
    else if Key='action:upload' then begin
      Line(12,2,12,16); Polyline([Point(6,8),Point(12,2),Point(18,8)]);
      Polyline([Point(3,16),Point(3,22),Point(21,22),Point(21,16)]);
    end
    else if Key='action:changes' then begin
      Box(3,2,20,22); Line(6,7,16,7); Line(6,12,12,12); Line(6,17,12,17);
      Line(16,10,16,14); Line(14,12,18,12); Line(14,17,18,17);
    end
    else if Key='action:browser' then begin
      Ellipse(2,2,22,22); Ellipse(8,2,16,22); Line(3,8,21,8); Line(3,16,21,16);
    end
    else if Key='action:open' then begin
      Polyline([Point(3,18),Point(3,4),Point(10,4),Point(12,7),Point(20,7),Point(20,10)]);
      Polyline([Point(3,20),Point(7,10),Point(23,10),Point(19,20),Point(3,20)]);
    end
    else if Key='action:help' then begin
      Ellipse(2,2,22,22); Polyline([Point(8,8),Point(10,5),Point(15,5),Point(17,8),Point(12,12),Point(12,15)]); Line(12,18,12,19);
    end
    else if Key='action:sync-right' then begin
      Line(3,12,21,12); Polyline([Point(14,5),Point(21,12),Point(14,19)]);
    end
    else if Key='action:sync-left' then begin
      Line(3,12,21,12); Polyline([Point(10,5),Point(3,12),Point(10,19)]);
    end
    else if Key='action:refresh' then begin
      Polyline([Point(20,8),Point(17,4),Point(7,4),Point(3,9),Point(3,16),Point(7,20),Point(17,20),Point(21,15)]);
      Polyline([Point(20,2),Point(20,8),Point(14,8)]);
    end
    else if Has('source / compiled pdf') then begin
      Box(2,3,22,21); Line(12,3,12,21); Line(4,7,9,7); Line(4,11,9,11); Line(4,15,8,15);
      Box(15,6,20,18);
    end
    else if Has('go to preview position') or Has('show source position') then begin
      Box(3,3,15,21); Line(6,7,12,7); Line(6,11,12,11);
      if Has('go to preview position') then begin Line(13,16,23,16); Polyline([Point(17,12),Point(13,16),Point(17,20)]); end
      else begin Line(13,16,23,16); Polyline([Point(19,12),Point(23,16),Point(19,20)]); end;
    end
    else if Has('fullscreen') then begin
      Polyline([Point(3,9),Point(3,3),Point(9,3)]); Polyline([Point(15,3),Point(21,3),Point(21,9)]);
      Polyline([Point(3,15),Point(3,21),Point(9,21)]); Polyline([Point(15,21),Point(21,21),Point(21,15)]);
    end
    else if Has('paged tex') or Has('paged layout') then begin Box(7,2,21,19); Box(2,6,16,23); Line(5,11,13,11); Line(5,15,13,15); Line(5,19,11,19); end
    else if Has('continuous layout') then begin Box(4,2,20,22); Line(7,6,17,6); Line(7,10,17,10); Line(7,14,17,14); Line(7,18,17,18); end
    else if Has('configure') then begin Line(3,6,21,6); Line(3,12,21,12); Line(3,18,21,18); Box(7,3,10,9); Box(14,9,17,15); Box(7,15,10,21); end
    else if Key='action:repository' then begin Line(7,5,7,19); Polyline([Point(17,5),Point(17,10),Point(7,15)]); Ellipse(4,2,10,8); Ellipse(14,2,20,8); Ellipse(4,16,10,22); end
    else if Key='action:document-run' then begin Box(3,2,18,22); Line(6,7,14,7); Line(6,11,14,11); Polyline([Point(15,14),Point(15,22),Point(22,18),Point(15,14)]); end
    else if Key='action:calculator' then begin Box(3,2,21,22); Line(6,8,18,8); Line(7,13,11,13); Line(9,11,9,15); Line(14,12,18,12); Line(14,15,18,15); end
    else if Key='action:terminal' then begin
      Box(2,3,22,21); Polyline([Point(6,8),Point(10,12),Point(6,16)]); Line(13,16,18,16);
    end
    else if Has('bibliography editor') or (Key='action:bibliography') then begin Box(3,3,21,21); Line(12,3,12,21); Line(6,8,9,8); Line(15,8,18,8); Line(6,13,9,13); Line(15,13,18,13); end
    else if Key='action:references' then begin Box(3,3,21,21); Polyline([Point(7,7),Point(17,7),Point(7,17),Point(17,17)]); end
    else if Has('footnote mark') then begin TextOut(3,6,'a'); Line(12,4,17,4); Line(15,2,15,9); end
    else if Has('footnote') then begin Line(3,4,18,4); Line(3,8,14,8); TextOut(17,1,'¹'); Line(3,15,13,15); Line(3,19,20,19); Line(3,22,17,22); end
    else if Has('margin note') then begin Box(3,3,15,21); Box(18,9,23,17); Line(6,7,12,7); Line(6,11,12,11); end
    else if Has('spreadsheet') then begin Box(2,3,18,21); Line(2,9,18,9); Line(2,15,18,15); Line(8,3,8,21); Line(14,3,14,21); Polyline([Point(17,9),Point(23,12),Point(17,15)]); end
    else if Has('keyboard shortcut') then begin Box(2,6,22,19); Line(5,10,7,10); Line(10,10,12,10); Line(15,10,17,10); Line(5,14,7,14); Line(10,14,18,14); end
    else if Has('add-ons') or Has('action:') then begin Box(3,4,20,21); Ellipse(9,1,15,7); Ellipse(17,9,23,15); Line(7,11,13,17); Line(13,11,7,17); end
    else if Has('finishsketchpath') then Polyline([Point(4,12),Point(10,18),Point(20,6)])
    else if Has('closesketchpath') then begin
      Polyline([Point(4,18),Point(11,4),Point(20,18),Point(4,18)]); Ellipse(2,16,6,20);
    end
    else if Has('drawingtoolmove') then begin
      Line(3,12,21,12); Line(12,3,12,21);
      Polyline([Point(7,8),Point(3,12),Point(7,16)]); Polyline([Point(17,8),Point(21,12),Point(17,16)]);
      Polyline([Point(8,7),Point(12,3),Point(16,7)]); Polyline([Point(8,17),Point(12,21),Point(16,17)]);
    end
    else if Has('drawingtooldeletepoint') then begin Ellipse(3,3,21,21); Line(7,12,17,12); end
    else if Has('drawingtooldelete') then begin Box(6,7,18,21); Line(4,7,20,7); Line(9,3,15,3); Line(10,11,10,17); Line(14,11,14,17); end
    else if Has('drawingtooltext') or Has('drawingtoollabel') then begin
      Line(4,4,18,4); Line(11,4,11,20); Line(7,20,15,20);
      if Has('label') then Line(19,14,23,18) else begin Line(21,8,21,20); Line(19,8,23,8); end;
    end
    else if Has('drawingtoolpoint') then begin Ellipse(8,8,16,16); Line(12,2,12,6); Line(12,18,12,22); Line(2,12,6,12); Line(18,12,22,12); end
    else if Has('drawingtoolnode') or Has('drawingobject3') then begin Box(3,5,21,19); Line(7,10,17,10); Line(9,14,15,14); end
    else if Has('drawingtoolrectangle') or Has('drawingobject1 ') then Box(3,4,21,20)
    else if Has('drawingtoolcircle') or Has('drawingobject2') then Ellipse(3,3,21,21)
    else if Has('drawingtoolarrow') then begin Line(3,20,21,3); Polyline([Point(12,3),Point(21,3),Point(21,12)]); end
    else if Has('drawingtoolpath') or Has('drawingobject7') then begin
      Polyline([Point(4,18),Point(11,5),Point(20,16)]); Box(2,16,6,20); Box(9,3,13,7); Box(18,14,22,18);
    end
    else if Has('drawingobject0') then begin Line(4,19,20,5); Ellipse(2,17,6,21); Ellipse(18,3,22,7); end
    else if Has('drawingobject10') or Has('drawingobject6') then begin Box(3,3,21,21); Line(3,9,21,9); Line(3,15,21,15); Line(9,3,9,21); Line(15,3,15,21); end
    else if Has('drawingobject8') then begin Box(3,4,21,20); Line(6,8,10,8); Line(13,8,18,8); Line(6,15,10,15); Line(13,15,18,15); end
    else if Has('drawingobject5') then begin Polyline([Point(3,16),Point(10,3),Point(21,10),Point(15,22),Point(3,16)]); Line(3,16,21,10); Line(10,3,15,22); end
    else if Has('drawingobject4') then begin Line(3,3,3,21); Line(3,21,22,21); Polyline([Point(5,18),Point(9,15),Point(13,8),Point(17,5),Point(21,4)]); end
    else if Has('history') then begin Line(6,9,12,15); Line(12,15,18,9); end
    else if Has('undo') or Has('redo') then begin
      if Has('undo') then begin
        Polyline([Point(8,4),Point(3,9),Point(8,14)]);
        Polyline([Point(3,9),Point(15,9),Point(20,12),Point(20,16),Point(16,20),Point(8,20)]);
      end else begin
        Polyline([Point(16,4),Point(21,9),Point(16,14)]);
        Polyline([Point(21,9),Point(9,9),Point(4,12),Point(4,16),Point(8,20),Point(16,20)]);
      end;
    end
    else if Has('save') then begin Box(4,3,20,21); Box(8,3,16,9); Box(8,14,16,21); end
    else if Has('duplicate row') then begin Box(3,3,20,20); Line(3,8,20,8); Line(3,14,20,14); Line(7,10,16,10); Line(7,12,16,12); end
    else if Has('duplicate column') then begin Box(3,3,20,20); Line(8,3,8,20); Line(14,3,14,20); Line(10,7,10,16); Line(12,7,12,16); end
    else if Has('copy') then begin Box(8,7,20,21); Line(4,17,4,3); Line(4,3,16,3); end
    else if Has('paste') then begin Box(5,5,19,21); Box(9,3,15,7); Line(8,12,16,12); Line(8,16,16,16); end
    else if Has('cut') then begin
      Ellipse(3,3,10,10); Ellipse(3,14,10,21);
      Line(9,8,21,20); Line(9,16,21,4);
    end
    else if Has('open') then begin Line(3,8,3,19); Line(3,8,9,8); Line(9,8,11,5); Line(11,5,19,5); Box(6,10,21,20); end
    else if Has('box colors') then begin Box(3,3,21,21); Line(3,9,21,9); Ellipse(8,12,16,20); end
    else if Has('box title') then begin Box(3,3,21,21); Line(3,10,21,10); Line(7,6,17,6); end
    else if Has('color box') then begin Box(3,3,21,21); Line(3,9,21,9); Line(7,14,17,14); Line(7,18,14,18); end
    else if Has('box arguments') then begin Box(3,3,21,21); Line(7,8,17,8); Line(7,16,17,16); Box(10,6,13,10); Box(13,14,16,18); end
    else if Has('pdf pages') then begin Box(3,3,16,21); Line(6,8,12,8); Line(6,12,12,12); Line(14,17,23,17); Line(20,14,23,17); Line(23,17,20,20); end
    else if Has('listing language') then begin Box(3,3,21,21); TextOut(6,3,'L'); end
    else if Has('listing font') then begin Line(3,6,9,6); Line(3,12,9,12); Line(3,18,9,18); TextOut(11,3,'A'); end
    else if Has('listing options') then begin Box(3,3,21,21); Polyline([Point(9,8),Point(6,12),Point(9,16)]); Polyline([Point(15,8),Point(18,12),Point(15,16)]); end
    else if Has('table environment options') then begin Box(2,3,15,21); Line(2,9,15,9); Line(8,3,8,21); Line(20,4,20,20); Line(17,9,23,9); Line(17,16,23,16); end
    else if Has('bold') or Has('italic') or Has('font') or Has('symbol') or Has('accent') then begin
      Letter:='A'; if Has('bold') then Letter:='B'; if Has('italic') then Letter:='I';
      if Has('symbol') then Letter:='Σ';
      if Has('alpha') then Letter:='α' else if Has('beta') then Letter:='β'
      else if Has('pi') then Letter:='π' else if Has('integral') then Letter:='∫'
      else if Has('infinity') then Letter:='∞';
      TextOut(5,3,Letter);
      if Has('accent') then begin Line(8,4,12,1); Line(12,1,16,4); end;
    end
    else if Has('fraction') or (Has('structures') and not Has('root') and not Has('script')) then begin Box(9,3,15,8); Line(4,12,20,12); Box(9,16,15,21); end
    else if Has('root') then begin Line(3,13,7,17); Line(7,17,11,5); Line(11,5,21,5); end
    else if Has('script') then begin
      Line(5,11,13,20); Line(5,20,13,11);
      if Has('subscript') then Box(16,16,21,21) else Box(16,3,21,8);
    end
    else if Has('bibliography') then begin Box(3,4,21,20); Line(12,5,12,20); Line(6,8,9,8); Line(15,8,18,8); Line(6,12,9,12); Line(15,12,18,12); end
    else if Has('reference') or Has('named') then begin
      Box(3,12,11,21); Box(13,3,21,12); Line(8,16,17,7);
    end
    else if Has('label') or Has('tag') then begin
      Polyline([Point(3,6),Point(15,6),Point(21,12),Point(15,18),Point(3,18),Point(3,6)]);
      Ellipse(14,10,18,14);
    end
    else if Has('theorem') or Has('title') then begin Box(3,3,21,21); Line(7,7,17,7); Line(12,7,12,17); end
    else if Has('tikz') or Has('pgfplot') then begin
      Polyline([Point(5,18),Point(12,5),Point(20,14),Point(5,18)]);
      Box(2,15,8,21); Box(9,2,15,8); Box(17,11,23,17);
    end
    else if Has('table of contents') then begin
      Line(3,5,17,5); Line(6,12,17,12); Line(9,19,17,19); Box(20,4,22,6); Box(20,11,22,13); Box(20,18,22,20);
    end
    else if Has('list of figures') then begin
      Box(2,3,12,11); Polyline([Point(3,10),Point(6,6),Point(9,9),Point(11,7)]);
      Line(15,5,22,5); Line(15,10,22,10); Line(3,16,22,16); Line(3,21,22,21);
    end
    else if Has('list of tables') then begin
      Box(2,3,12,11); Line(2,7,12,7); Line(7,3,7,11);
      Line(15,5,22,5); Line(15,10,22,10); Line(3,16,22,16); Line(3,21,22,21);
    end
    else if Has('figure environment') then begin Box(3,3,21,16); Line(5,20,19,20); end
    else if Has('figure') or Has('image') then begin Box(3,4,21,20); Ellipse(6,7,10,11); Polyline([Point(4,18),Point(10,12),Point(14,16),Point(17,11),Point(21,17)]); end
    else if Has('caption') then begin Box(3,3,21,15); Line(4,19,20,19); Line(7,22,17,22); end
    else if Has('table') then begin Box(3,3,21,21); Line(3,9,21,9); Line(3,15,21,15); Line(9,3,9,21); Line(15,3,15,21); end
    else if Has('dependencies') or Has('check environment') then begin
      Box(3,3,21,21); Line(7,9,10,12); Line(10,12,17,5);
      Line(7,17,12,17); Line(16,16,16,19);
    end
    else if Has('properties') or Has('setting') then begin
      Line(3,6,21,6); Line(3,12,21,12); Line(3,18,21,18);
      Box(7,3,10,9); Box(15,9,18,15); Box(5,15,8,21);
    end
    else if Has('wrap') then begin
      Line(3,5,21,5); Line(3,10,18,10); Line(18,10,21,13); Line(21,13,18,17);
      Line(18,17,11,17); Line(14,14,11,17); Line(11,17,14,20); Line(3,17,7,17);
    end
    else if Has('environment') or Has('matrix') then begin Box(3,3,21,21); Line(12,3,12,21); Line(3,12,21,12); end
    else if Has('layout') or Has('heading') or Has('paragraph') then begin Line(3,5,21,5); Line(6,10,18,10); Line(3,15,21,15); Line(6,20,18,20); end
    else if Has('preview') then begin Ellipse(2,6,22,18); Ellipse(9,9,15,15); end
    else if Has('source') or Has('command') then begin Line(8,5,3,12); Line(3,12,8,19); Line(16,5,21,12); Line(21,12,16,19); Line(14,3,10,21); end
    else if Has('selectall') or Has('select all') then begin
      Bitmap.Canvas.Pen.Style:=psDash; Box(3,3,21,21); Bitmap.Canvas.Pen.Style:=psSolid;
      Line(7,8,17,8); Line(7,12,17,12); Line(7,16,14,16);
    end
    else if Has('edit') then begin Line(4,20,7,13); Line(7,13,17,3); Line(17,3,21,7); Line(21,7,11,17); Line(11,17,4,20); end
    else if Has('actions') then begin Ellipse(10,3,14,7); Ellipse(10,10,14,14); Ellipse(10,17,14,21); end
    else begin Box(5,3,19,21); Line(8,8,16,8); Line(8,12,16,12); Line(8,16,14,16); end;
    if Has('image') or Has('tikz') or Has('pgfplot') then begin
      Bitmap.Canvas.Brush.Style:=bsSolid; Bitmap.Canvas.Brush.Color:=UIBackground;
      Bitmap.Canvas.FillRect(Rect(56,56,96,96));
      if Has('insert ') then begin Line(19,15,19,23); Line(15,19,23,19); end
      else if Has('edit ') then begin Line(15,22,22,15); Line(15,22,16,18); Line(18,22,15,22); end;
    end;
    SmoothIcon(Bitmap); AssignGlyph;
  finally Bitmap.Free; end;
end;
procedure RefreshRibbonIcons(Root:TWinControl);
var I:Integer; C:TControl;
begin
  { Repaint only. Geometry and captions belong to the ribbon builder. }
  for I:=0 to Root.ControlCount-1 do begin
    C:=Root.Controls[I];
    if not C.Visible and not (C is TTabSheet) then Continue;
    if (C is TSpeedButton) or (C is TBitBtn) then begin
      C.ShowHint:=True;
      if C.HelpKeyword<>'literal' then RibbonGlyph(C);
    end;
    if (C is TWinControl) and not (C is TBitBtn) then RefreshRibbonIcons(TWinControl(C));
  end;
end;
initialization
{$I toolbaricons.lrs}
end.
