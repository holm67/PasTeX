unit ProgramInfo;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes;
procedure ProgramInformation(Details:TStrings);
implementation
uses SysUtils, FileUtil, LCLVersion, LCLPlatformDef, AppVersion;
procedure ProgramInformation(Details:TStrings);
const Tools:array[0..9] of string=('pdflatex','xelatex','lualatex','latex','tectonic','kpsewhich','bibtex','biber','pdftocairo','pdftoppm');
      Variables:array[0..28] of string=('PATH','TEXINPUTS','TEXMFHOME','TEXMFLOCAL','TEXMFVAR','TEXMFCONFIG','TEXMFCNF',
        'TEXMFOUTPUT','TEXFORMATS','BIBINPUTS','BSTINPUTS','FONTCONFIG_FILE','FONTCONFIG_PATH','LANG','LC_ALL','LC_CTYPE',
        'QT_QPA_PLATFORM','QT_SCALE_FACTOR','QT_AUTO_SCREEN_SCALE_FACTOR','GTK_THEME','GDK_SCALE','GDK_DPI_SCALE',
        'XDG_CURRENT_DESKTOP','XDG_SESSION_TYPE','XDG_CONFIG_HOME','DISPLAY','WAYLAND_DISPLAY','HOME','USERPROFILE');
var Name,Value:string;
begin
  Details.BeginUpdate;
  try
    Details.Clear; Details.Add('PasTeX '+PasTeXVersion);
    Details.Add('Platform: '+{$I %FPCTARGETCPU%}+'-'+{$I %FPCTARGETOS%});
    Details.Add('Widget set: '+LCLPlatformDisplayNames[GetBuildLCLWidgetType]);
    Details.Add('Lazarus / LCL: '+lcl_version); Details.Add('Free Pascal: '+{$I %FPCVERSION%});
    Details.Add('Executable: '+ExpandFileName(ParamStr(0))); Details.Add('Working directory: '+GetCurrentDir);
    Details.Add('Settings: '+GetAppConfigFile(False)); Details.Add(''); Details.Add('Detected tools (PATH)');
    for Name in Tools do begin
      Value:=FindDefaultExecutablePath(Name); if Value='' then Value:='Not found'; Details.Add(Name+': '+Value);
    end;
    Details.Add(''); Details.Add('Environment (TeX, fonts and GUI)');
    for Name in Variables do begin
      Value:=GetEnvironmentVariable(Name); if Value='' then Value:='(not set)'; Details.Add(Name+'='+Value);
    end;
  finally Details.EndUpdate; end;
end;
end.
