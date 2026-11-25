unit EnvironmentCheckForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, Contnrs, AddonModel;
type
  TEnvironmentCheckForm=class(TForm)
    Heading:TLabel;
    ComponentsList:TListView;
    Details:TMemo;
    Divider:TSplitter;
    Footer:TPanel;
    RefreshButton,CopyButton,WebsiteButton,CloseButton:TButton;
    procedure RefreshClick(Sender:TObject);
    procedure CopyClick(Sender:TObject);
    procedure WebsiteClick(Sender:TObject);
    procedure Selected(Sender:TObject; Item:TListItem; Select:Boolean);
  private
    FEntries:TObjectList;
    procedure Entry(const ComponentName,Status,Location,Description,URL:string);
    procedure Tool(const ToolName,Feature:string; const URL:string='https://tug.org/texlive/quickinstall.html');
  public
    Engine,Directory:string;
    Addons:TEditorAddons;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
  end;
implementation
uses Clipbrd, LCLIntf, LCLVersion, LCLPlatformDef, UITheme, ToolJobs, NativeTeXGlyphs,
  OpenTypeShaping, VectorPreview, BundledTeX, TeXFontData;
type TDependencyEntry=class
  Description,URL:string;
end;
{$R *.lfm}
constructor TEnvironmentCheckForm.Create(AOwner:TComponent);
begin
  inherited Create(AOwner); FEntries:=TObjectList.Create(True); ApplyTheme(Self);
end;
destructor TEnvironmentCheckForm.Destroy;
begin ComponentsList.OnSelectItem:=nil; ComponentsList.Items.Clear; FEntries.Free; inherited Destroy; end;
procedure TEnvironmentCheckForm.Entry(const ComponentName,Status,Location,Description,URL:string);
var Row:TListItem; Data:TDependencyEntry;
begin
  Data:=TDependencyEntry.Create; Data.Description:=Description; Data.URL:=URL; FEntries.Add(Data);
  Row:=ComponentsList.Items.Add; Row.Caption:=ComponentName; Row.SubItems.Add(Status); Row.SubItems.Add(Location); Row.Data:=Data;
end;
procedure TEnvironmentCheckForm.Tool(const ToolName,Feature,URL:string);
var Path,Status,Help:string;
begin
  Path:=FindTool(ToolName); Status:='Available'; if Path='' then Status:='Not found (optional)';
  Help:=Feature+LineEnding+LineEnding+'Native editing does not require this tool.'+LineEnding;
  if Path='' then Help:=Help+'Install the tool using your operating system package manager or its official installer. '+
    'Add its executable directory to PATH, or configure its path in PasTeX settings, then click Check again.'
  else Help:=Help+'Detected executable: '+Path;
  Entry(ToolName,Status,Path,Help,URL);
end;
procedure TEnvironmentCheckForm.RefreshClick(Sender:TObject);
var Path,Status:string; I:Integer; Addon:TEditorAddon;
begin
  Screen.Cursor:=crHourGlass; ComponentsList.Items.BeginUpdate;
  try
    ComponentsList.Items.Clear; FEntries.Clear; Details.Clear;
    Entry('GUI runtime','Available',LCLPlatformDisplayNames[GetBuildLCLWidgetType]+' / LCL '+lcl_version,
      'The GUI runtime is loaded. Lazarus and Free Pascal are needed to build PasTeX, not to run an installed build.','');
    Path:=BundledTeXFile('cmr10.tfm'); Status:='Available'; if not TeXFontMetric('cmr10').Valid then Status:='Unavailable';
    Entry('Bundled TeX fonts and metrics',Status,Path,
      'Native text and mathematics use the bundled fonts and metrics. If this check fails, reinstall the complete PasTeX build. '+
      'Custom document fonts and CJK fonts must also be installed or selected in the document.','');
    Status:='Available'; if not NativeTeXFontsAvailable then Status:='Widget font fallback';
    Entry('FreeType',Status,'Native font outlines',
      'FreeType draws the bundled TeX font outlines. Without it, PasTeX uses the widget font fallback. '+
      'Install the FreeType runtime through your system package manager. On Windows, use a compatible FreeType DLL beside PasTeX.',
      'https://freetype.org/download.html');
    Status:='Available'; if not OpenTypeShapingAvailable then Status:='Basic shaping fallback';
    Entry('HarfBuzz',Status,'OpenType text shaping',
      'HarfBuzz provides OpenType ligatures, kerning and text shaping. Install its runtime through your system package manager '+
      'or place a compatible HarfBuzz DLL beside PasTeX on Windows.','');
    Status:='Available'; if not VectorPDFSupported then Status:='Not found (optional)';
    Entry('Poppler / Cairo',Status,'Vector PDF display',
      'The Poppler GLib, GLib/GObject and Cairo runtimes provide vector PDF display and PDF images. '+
      'Install compatible runtimes using your system package manager. Poppler command-line tools can provide raster preview instead. '+
      'Native document editing remains available without these libraries.','https://poppler.freedesktop.org/');
    Status:='Available'; if not VectorSVGSupported then Status:='Raster icon fallback';
    Entry('librsvg / Cairo',Status,'SVG images and vector artwork',
      'Install the librsvg and Cairo runtimes for SVG images and vector artwork. PasTeX icons also include a raster fallback.',
      'https://gnome.pages.gitlab.gnome.org/librsvg/');
    Path:=CompilerPath(Engine,Directory);
    Status:='Not found (optional)'; if Path<>'' then Status:='Available';
    Entry('Configured compiler: '+Engine,Status,Path,
      'This is the executable configured for the current TeX engine. Install a TeX distribution for compiled preview and PDF export. '+
      'Use Settings, TeX to change the executable and arguments. Native editing does not require a compiler.',
      'https://tug.org/texlive/quickinstall.html');
    Tool('pdflatex','Compile pdfLaTeX documents.'); Tool('xelatex','Compile Unicode and CJK documents with XeLaTeX.');
    Tool('lualatex','Compile documents with LuaLaTeX.'); Tool('kpsewhich','Locate installed TeX packages, fonts and bibliography styles.');
    Tool('bibtex','Build bibliographies that use BibTeX.'); Tool('biber','Build bibliographies that use the biblatex Biber backend.');
    Tool('synctex','Synchronize source positions with the compiled PDF.');
    Tool('pdftoppm','Raster PDF preview and PDF images.','https://poppler.freedesktop.org/');
    Tool('pdftocairo','PDF image conversion.','https://poppler.freedesktop.org/');
    Tool('pdftohtml','Compiled paragraph layout and source-position information.','https://poppler.freedesktop.org/');
    Tool('pdftotext','Text extraction from compiled documents.','https://poppler.freedesktop.org/');
    if Addons<>nil then for I:=0 to Addons.Count-1 do begin
      Addon:=TEditorAddon(Addons[I]); if not Addon.Installed then Continue;
      Status:='Installed, disabled'; if Addon.Enabled then Status:='Installed, enabled';
      Entry('Add-on: '+Addon.DisplayName,Status,Addon.ManifestPath,Addon.Description,'');
      if Addon.Executable<>'' then Tool(Addon.Executable,'External program used by '+Addon.DisplayName,Addon.Manifest.Get('homepage',''));
    end;
    if ComponentsList.Items.Count>0 then begin ComponentsList.Items[0].Selected:=True; Selected(ComponentsList,ComponentsList.Items[0],True); end;
  finally ComponentsList.Items.EndUpdate; Screen.Cursor:=crDefault; end;
end;
procedure TEnvironmentCheckForm.Selected(Sender:TObject; Item:TListItem; Select:Boolean);
var Data:TDependencyEntry;
begin
  if not Select or (Item=nil) or (Item.Data=nil) then Exit; Data:=TDependencyEntry(Item.Data);
  Details.Text:=Item.Caption+LineEnding+Item.SubItems[0]+LineEnding+Item.SubItems[1]+LineEnding+LineEnding+Data.Description;
  WebsiteButton.Enabled:=(Copy(Data.URL,1,8)='https://') or (Copy(Data.URL,1,7)='http://');
end;
procedure TEnvironmentCheckForm.CopyClick(Sender:TObject);
var Lines:TStringList; I:Integer; Item:TListItem;
begin
  Lines:=TStringList.Create;
  try
    for I:=0 to ComponentsList.Items.Count-1 do begin
      Item:=ComponentsList.Items[I]; Lines.Add(Item.Caption+': '+Item.SubItems[0]+' '+Item.SubItems[1]);
      Lines.Add(TDependencyEntry(Item.Data).Description); Lines.Add('');
    end;
    Clipboard.AsText:=Lines.Text;
  finally Lines.Free; end;
end;
procedure TEnvironmentCheckForm.WebsiteClick(Sender:TObject);
begin if WebsiteButton.Enabled and (ComponentsList.Selected<>nil) then OpenURL(TDependencyEntry(ComponentsList.Selected.Data).URL); end;
end.
