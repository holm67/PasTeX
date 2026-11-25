unit UITheme;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Types, Graphics, Controls, TypInfo, StdCtrls, Buttons, ComCtrls, Forms;
type TAppearanceMode=(amLight,amDark,amSystem);
  TEditorPageControl=class(TPageControl)
  protected
    procedure DestroyWnd; override;
  end;
var DarkMode:Boolean=False;
    AppearanceMode:TAppearanceMode=amSystem;
function PaperColor:TColor;
function InkColor:TColor;
function UIBackground:TColor;
function ThemeText(Value:TColor):TColor;
procedure DrawSourceDisclosure(Canvas:TCanvas; const Bounds:TRect; Expanded:Boolean);
procedure ApplyTheme(Root:TControl);
procedure RefreshTabTheme(Pages:TPageControl);
procedure RetainTabPages(Pages:TPageControl);
procedure CancelTabUpdates(Pages:TPageControl);
procedure SetPageVisible(Page:TTabSheet; Visible:Boolean);
procedure SetAppearance(Mode:TAppearanceMode);
function RefreshSystemAppearance:Boolean;
implementation
uses Process, IniFiles, Math, LCLType, LCLIntf, SynEdit, SourceStyle
  {$IF DEFINED(LCLqt5) or DEFINED(LCLqt6)}, QtWidgets, QtObjects{$ENDIF}
  {$IFDEF MSWINDOWS}, Registry, Windows{$ENDIF}
  {$IFDEF LCLqt5}, Qt5{$ENDIF}
  {$IFDEF LCLqt6}, Qt6{$ENDIF}
  {$IFDEF LCLgtk2}, Gtk2, Gdk2{$ENDIF}
  {$IFDEF LCLgtk3}, LazGtk3, LazGdk3, LazGObject2, LazGLib2, Gtk3Widgets{$ENDIF};
var InitialSystemDark:Boolean; LastSystemPoll:QWord; CapturedSystemPalette:Boolean;
{$IFNDEF MSWINDOWS}
var AppearanceProbe:TProcess; ProbeStarted:QWord; ProbeTheme,DesktopPreferenceKnown,DesktopPreference:Boolean;
procedure StopAppearanceProbe;
begin
  if AppearanceProbe=nil then Exit;
  if AppearanceProbe.Running then AppearanceProbe.Terminate(0);
  FreeAndNil(AppearanceProbe);
end;
procedure StartAppearanceProbe(Theme:Boolean);
begin
  if (AppearanceProbe<>nil) or (Pos('KDE',UpperCase(GetEnvironmentVariable('XDG_CURRENT_DESKTOP')))>0) then Exit;
  AppearanceProbe:=TProcess.Create(nil); ProbeTheme:=Theme;
  AppearanceProbe.Executable:='gsettings'; AppearanceProbe.Options:=[poUsePipes,poNoConsole];
  AppearanceProbe.Parameters.Add('get'); AppearanceProbe.Parameters.Add('org.gnome.desktop.interface');
  if Theme then AppearanceProbe.Parameters.Add('gtk-theme') else AppearanceProbe.Parameters.Add('color-scheme');
  try AppearanceProbe.Execute; ProbeStarted:=GetTickCount64;
  except FreeAndNil(AppearanceProbe); end;
end;
function PollAppearanceProbe(out Value:Boolean):Boolean;
var S:string; Theme:Boolean;
begin
  Result:=False; if AppearanceProbe=nil then Exit;
  if AppearanceProbe.Running then begin
    if GetTickCount64-ProbeStarted>=750 then StopAppearanceProbe;
    Exit;
  end;
  Theme:=ProbeTheme;
  SetLength(S,Min(4096,AppearanceProbe.Output.NumBytesAvailable));
  if S<>'' then AppearanceProbe.Output.ReadBuffer(S[1],Length(S));
  if AppearanceProbe.ExitStatus<>0 then S:=''; FreeAndNil(AppearanceProbe);
  if S='' then begin if not Theme then StartAppearanceProbe(True); Exit; end;
  if not Theme then begin
    if Pos('prefer-dark',S)>0 then begin Value:=True; Exit(True); end;
    if Pos('prefer-light',S)>0 then begin Value:=False; Exit(True); end;
    StartAppearanceProbe(True); Exit;
  end;
  Value:=Pos('dark',LowerCase(S))>0; Result:=True;
end;
{$ENDIF}
{$IF DEFINED(LCLqt5) or DEFINED(LCLqt6)}var SystemPalette:QPaletteH;{$ENDIF}
{$IFDEF LCLgtk3}var ThemeProvider:PGtkCssProvider;{$ENDIF}
function PaperColor:TColor;
begin if DarkMode then Result:=$242424 else Result:=clWhite; end;
function InkColor:TColor;
begin if DarkMode then Result:=$EEEEEE else Result:=$202020; end;
function UIBackground:TColor;
begin if AppearanceMode=amSystem then Exit(clBtnFace); if DarkMode then Result:=$303030 else Result:=$F5F5F5; end;
function ThemeText(Value:TColor):TColor;
begin Result:=Value; if DarkMode and (ColorToRGB(Value)=$000000) then Result:=InkColor; end;
procedure DrawSourceDisclosure(Canvas:TCanvas; const Bounds:TRect; Expanded:Boolean);
var X,Y:Integer;
begin
  X:=(Bounds.Left+Bounds.Right) div 2; Y:=(Bounds.Top+Bounds.Bottom) div 2;
  Canvas.Brush.Style:=bsSolid; Canvas.Brush.Color:=PaperColor;
  Canvas.Pen.Color:=clGray; Canvas.Pen.Style:=psSolid; Canvas.Pen.Width:=1;
  Canvas.Rectangle(Bounds); Canvas.Pen.Color:=InkColor; Canvas.Pen.Width:=2;
  Canvas.Line(X-6,Y,X+7,Y); if not Expanded then Canvas.Line(X,Y-6,X,Y+7);
  Canvas.Pen.Width:=1; Canvas.Brush.Style:=bsClear;
end;
function SystemDark:Boolean;
{$IFDEF MSWINDOWS}var Reg:TRegistry;
{$ELSE}var Ini:TIniFile; RGB:TStringList;{$ENDIF}
begin
  Result:=InitialSystemDark;
  {$IFDEF MSWINDOWS}
  Reg:=TRegistry.Create(KEY_READ);
  try
    Reg.RootKey:=HKEY_CURRENT_USER;
    if Reg.OpenKeyReadOnly('Software\Microsoft\Windows\CurrentVersion\Themes\Personalize') and
       Reg.ValueExists('AppsUseLightTheme') then Result:=Reg.ReadInteger('AppsUseLightTheme')=0;
  finally Reg.Free; end;
  {$ELSE}
  if DesktopPreferenceKnown then Result:=DesktopPreference;
  if Pos('KDE',UpperCase(GetEnvironmentVariable('XDG_CURRENT_DESKTOP')))>0 then begin
    Ini:=TIniFile.Create(GetEnvironmentVariable('HOME')+'/.config/kdeglobals'); RGB:=TStringList.Create;
    try
      RGB.CommaText:=Ini.ReadString('Colors:Window','BackgroundNormal','');
      if RGB.Count=3 then Exit((StrToIntDef(RGB[0],255)+StrToIntDef(RGB[1],255)+StrToIntDef(RGB[2],255))<384);
    finally RGB.Free; Ini.Free; end;
  end;
  if not DesktopPreferenceKnown and (GetEnvironmentVariable('GTK_THEME')<>'') then
    Result:=Pos('dark',LowerCase(GetEnvironmentVariable('GTK_THEME')))>0;
  {$ENDIF}
end;
procedure NativeTheme;
var BG,FG,Base,Border,Selection,S:string;
{$IF DEFINED(LCLqt5) or DEFINED(LCLqt6)}
var Wide:WideString; Palette:QPaletteH;
  procedure Role(ID:QPaletteColorRole; Value:TColor);
  var C:TQColor; RGB:LongInt;
  begin
    RGB:=ColorToRGB(Value);
    QColor_fromRgb(@C,RGB and 255,(RGB shr 8) and 255,(RGB shr 16) and 255);
    QPalette_setColor(Palette,ID,@C);
  end;
{$ENDIF}
begin
  {$IF DEFINED(LCLqt5) or DEFINED(LCLqt6)}
  if SystemPalette=nil then begin SystemPalette:=QPalette_Create; QApplication_palette(SystemPalette,QWidgetH(nil)); end;
  Wide:=''; QApplication_setStyleSheet(QApplicationH(QCoreApplication_instance()),@Wide);
  if AppearanceMode=amSystem then begin QApplication_setPalette(SystemPalette); Exit; end;
  {$ENDIF}
  {$IFDEF LCLgtk2}
  if AppearanceMode=amSystem then begin
    gtk_rc_reparse_all_for_settings(gtk_settings_get_default(),True);
    gtk_rc_reset_styles(gtk_settings_get_default()); Exit;
  end;
  {$ENDIF}
  {$IFDEF LCLgtk3}
  if AppearanceMode=amSystem then begin
    if ThemeProvider<>nil then begin
      gtk_style_context_remove_provider_for_screen(gdk_screen_get_default(),PGtkStyleProvider(ThemeProvider));
      g_object_unref(ThemeProvider); ThemeProvider:=nil;
    end;
    Exit;
  end;
  {$ENDIF}
  if DarkMode then begin BG:='#303030'; FG:='#eeeeee'; Base:='#242424'; Border:='#606060'; Selection:='#365f91'; end
  else begin BG:='#f5f5f5'; FG:='#202020'; Base:='#ffffff'; Border:='#aaaaaa'; Selection:='#b8d5f6'; end;
  {$IF DEFINED(LCLqt5) or DEFINED(LCLqt6)}
  { LCL-painted speed buttons use the application palette, not widget CSS. }
  Palette:=QPalette_Create;
  try
    Role(QPaletteWindow,UIBackground); Role(QPaletteButton,UIBackground);
    Role(QPaletteBase,PaperColor); Role(QPaletteText,InkColor);
    Role(QPaletteWindowText,InkColor); Role(QPaletteButtonText,InkColor);
    Role(QPaletteHighlight,$915F36); Role(QPaletteHighlightedText,clWhite);
    if DarkMode then begin
      Role(QPaletteLight,$606060); Role(QPaletteMidlight,$464646);
      Role(QPaletteMid,$383838); Role(QPaletteDark,$181818);
    end else begin
      Role(QPaletteLight,clWhite); Role(QPaletteMidlight,$FAFAFA);
      Role(QPaletteMid,$DDDDDD); Role(QPaletteDark,$AAAAAA);
    end;
    QApplication_setPalette(Palette);
  finally QPalette_Destroy(Palette); end;
  {$ENDIF}
  {$IFDEF LCLgtk2}
  S:='style "pastex-theme" { bg[NORMAL]="'+BG+'" bg[ACTIVE]="'+Selection+'" bg[PRELIGHT]="'+Selection+'" '+
     'bg[SELECTED]="'+Selection+'" bg[INSENSITIVE]="'+BG+'" fg[NORMAL]="'+FG+'" fg[ACTIVE]="'+FG+'" '+
     'fg[PRELIGHT]="'+FG+'" fg[SELECTED]="'+FG+'" fg[INSENSITIVE]="'+Border+'" '+
     'base[NORMAL]="'+Base+'" base[ACTIVE]="'+Base+'" base[SELECTED]="'+Selection+'" '+
     'text[NORMAL]="'+FG+'" text[ACTIVE]="'+FG+'" text[SELECTED]="'+FG+'" } '+
     'class "*" style : highest "pastex-theme" widget "*" style : highest "pastex-theme"';
  gtk_rc_parse_string(PChar(S)); gtk_rc_reset_styles(gtk_settings_get_default());
  {$ENDIF}
  {$IFDEF LCLgtk3}
  if ThemeProvider=nil then begin
    ThemeProvider:=gtk_css_provider_new();
    gtk_style_context_add_provider_for_screen(gdk_screen_get_default(),PGtkStyleProvider(ThemeProvider),800);
  end;
  S:='* { background-color:'+BG+'; color:'+FG+'; border-color:'+Border+'; } '+
     'entry,textview,textview text { background-color:'+Base+'; color:'+FG+'; } '+
     '*:selected,button:hover,notebook tab:checked { background-color:'+Selection+'; color:'+FG+'; } '+
     'scrollbar slider { background-color:'+Border+'; min-width:10px; min-height:10px; } '+
     '*:disabled { color:'+Border+'; }';
  gtk_css_provider_load_from_data(ThemeProvider,PChar(S),Length(S),nil);
  {$ENDIF}
end;
procedure SetAppearance(Mode:TAppearanceMode);
var C:LongInt;
begin
  if not CapturedSystemPalette then begin
    C:=ColorToRGB(clWindow); InitialSystemDark:=((C and 255)+((C shr 8) and 255)+((C shr 16) and 255))<384;
    CapturedSystemPalette:=True;
  end;
  AppearanceMode:=Mode;
  {$IFNDEF MSWINDOWS}StopAppearanceProbe;{$ENDIF}
  if Mode=amSystem then DarkMode:=SystemDark else DarkMode:=Mode=amDark;
  LastSystemPoll:=GetTickCount64; NativeTheme;
  {$IFNDEF MSWINDOWS}if Mode=amSystem then StartAppearanceProbe(False);{$ENDIF}
end;
function RefreshSystemAppearance:Boolean;
var Value:Boolean;
begin
  Result:=False;
  if AppearanceMode<>amSystem then Exit;
  {$IFNDEF MSWINDOWS}
  if PollAppearanceProbe(Value) then begin DesktopPreference:=Value; DesktopPreferenceKnown:=True; end
  else begin
    if (AppearanceProbe<>nil) or (GetTickCount64-LastSystemPoll<3000) then Exit;
    LastSystemPoll:=GetTickCount64; Value:=SystemDark; StartAppearanceProbe(False);
  end;
  {$ELSE}
  if GetTickCount64-LastSystemPoll<3000 then Exit;
  LastSystemPoll:=GetTickCount64; Value:=SystemDark;
  {$ENDIF}
  if Value=DarkMode then Exit;
  DarkMode:=Value; NativeTheme; Result:=True;
end;
{$IFDEF LCLgtk3}
type TTabPageReference=class(TComponent)
private
  Widget:PGtkWidget;
public
  procedure Retain(Page:TTabSheet);
  destructor Destroy; override;
end;
procedure TTabPageReference.Retain(Page:TTabSheet);
var Current:PGtkWidget;
begin
  Current:=nil;
  if Page.HandleAllocated then Current:=TGtk3Widget(Page.Handle).Widget;
  if Current=Widget then Exit;
  if Current<>nil then g_object_ref(Current);
  if Widget<>nil then g_object_unref(Widget);
  Widget:=Current;
end;
destructor TTabPageReference.Destroy;
begin if Widget<>nil then g_object_unref(Widget); inherited Destroy; end;
{$ENDIF}
procedure RetainTabPages(Pages:TPageControl);
{$IFDEF LCLgtk3}var I:Integer; Page:TTabSheet; Reference:TTabPageReference;{$ENDIF}
begin
  {$IFDEF LCLgtk3}
  if (Pages=nil) or not Pages.HandleAllocated then Exit;
  for I:=0 to Pages.PageCount-1 do begin
    Page:=Pages.Pages[I];
    if Page.TabVisible then Page.HandleNeeded;
    Reference:=TTabPageReference(Page.FindComponent('NativeTabReference'));
    if Reference=nil then begin Reference:=TTabPageReference.Create(Page); Reference.Name:='NativeTabReference'; end;
    { GTK removes the page before LCL saves and destroys its child handles.
      Keep it alive until that teardown completes; refresh after recreation. }
    Reference.Retain(Page);
  end;
  {$ENDIF}
end;
procedure RefreshTabTheme(Pages:TPageControl);
{$IF DEFINED(LCLqt5) or DEFINED(LCLqt6)}
var I,VisibleIndex:Integer; Color:TQColor;
{$ENDIF}
begin
  {$IF DEFINED(LCLqt5) or DEFINED(LCLqt6)}
  if not Pages.HandleAllocated then Exit;
  { LCL 4.0 colors Qt tabs using PageIndex, even when preceding pages are
    hidden. Qt's tab bar contains only visible pages. }
  VisibleIndex:=0;
  for I:=0 to Pages.PageCount-1 do if Pages.Pages[I].TabVisible then begin
    FillChar(Color,SizeOf(Color),0); ColorRefToTQColor(ColorToRGB(Pages.Pages[I].Font.Color),Color);
    TQtTabWidget(Pages.Handle).TabBar.SetTabFontColor(VisibleIndex,Color); Inc(VisibleIndex);
  end;
  {$ENDIF}
end;
procedure SetPageVisible(Page:TTabSheet; Visible:Boolean);
{$IFDEF LCLgtk3}var Widget:PGtkWidget;{$ENDIF}
begin
  if Page.TabVisible=Visible then Exit;
  {$IFDEF LCLgtk3}
  Widget:=nil;
  if not Visible and Page.HandleAllocated then begin
    Widget:=TGtk3Widget(Page.Handle).Widget;
    if Widget<>nil then g_object_ref(Widget);
  end;
  try
    { Removing a GTK page otherwise destroys its native children before LCL
      clears their handles. Keep it alive until DestroyHandle has finished. }
    Page.TabVisible:=Visible;
  finally if Widget<>nil then g_object_unref(Widget); end;
  {$ELSE}Page.TabVisible:=Visible;{$ENDIF}
end;
procedure CancelTabUpdates(Pages:TPageControl);
{$IFDEF LCLgtk3}var Widget:PGtkWidget;{$ENDIF}
begin
  {$IFDEF LCLgtk3}
  if (Pages=nil) or not Pages.HandleAllocated then Exit;
  { LCL GTK3 can leave deferred notebook signals targeting a closed dialog. }
  Widget:=TGtk3Notebook(Pages.Handle).GetContainerWidget;
  if Widget<>nil then begin
    { Removing pages during teardown emits switch-page again. Disconnect its
      LCL handlers before destroying children so no new idle can be queued. }
    g_signal_handlers_disconnect_matched(PGObject(Widget),[G_SIGNAL_MATCH_DATA],0,0,nil,nil,Pointer(Pages.Handle));
    g_object_set_data(Widget,'switch-page-signal-stopped',nil);
    while g_idle_remove_by_data(Widget) do ;
  end;
  {$ENDIF}
end;
procedure TEditorPageControl.DestroyWnd;
begin CancelTabUpdates(Self); inherited DestroyWnd; end;
procedure ApplyTheme(Root:TControl);
var I:Integer; Obj:TObject;
begin
  if IsPublishedProp(Root,'ParentColor') then SetOrdProp(Root,'ParentColor',0);
  if IsPublishedProp(Root,'Color') then SetOrdProp(Root,'Color',UIBackground);
  if IsPublishedProp(Root,'ParentFont') then SetOrdProp(Root,'ParentFont',0);
  if IsPublishedProp(Root,'Font') then begin
    Obj:=GetObjectProp(Root,'Font'); if Obj is TFont then begin
      if AppearanceMode=amSystem then TFont(Obj).Color:=clWindowText else TFont(Obj).Color:=InkColor;
    end;
  end;
  if Root is TLabel then TLabel(Root).Transparent:=True;
  if Root is TSpeedButton then begin
    TSpeedButton(Root).Flat:=True; TSpeedButton(Root).Font.Color:=InkColor;
    TSpeedButton(Root).Color:=UIBackground;
  end;
  if Root is TWinControl then for I:=0 to TWinControl(Root).ControlCount-1 do ApplyTheme(TWinControl(Root).Controls[I]);
  if Root is TPageControl then RefreshTabTheme(TPageControl(Root));
  if Root is TSynEdit then ApplySourceStyle(TSynEdit(Root));
  Root.Invalidate;
end;
initialization
  InitialSystemDark:=False;
finalization
  {$IFNDEF MSWINDOWS}StopAppearanceProbe;{$ENDIF}
  {$IF DEFINED(LCLqt5) or DEFINED(LCLqt6)}if SystemPalette<>nil then QPalette_Destroy(SystemPalette);{$ENDIF}
  {$IFDEF LCLgtk3}if ThemeProvider<>nil then g_object_unref(ThemeProvider);{$ENDIF}
end.
