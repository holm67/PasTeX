unit SettingsForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Forms, Controls, StdCtrls, Spin, ComCtrls, ExtCtrls, Dialogs, SynEdit, SourceStyle;
type
  TSettingsForm=class(TForm)
    Pages:TPageControl;
    AppearanceTab,SourceTab,PreviewTab,CompilerTab:TTabSheet;
    CompilerExecutable:TEdit;
    CompilerArgs:TMemo;
    ExtensionSteps:TCheckBox;
    Footer:TPanel;
    AppearanceLabel,FontLabel,EngineLabel,SourceFontLabel,ScaleLabel,DiagramRendererLabel:TLabel;
    Appearance,DefaultEngine,SourceFont,PreviewScale,DiagramRenderer:TComboBox;
    SourceWrap,DiagramBackend,HighlightEnabled,RealtimeCompile:TCheckBox;
    HighlightScheme,HighlightToken:TComboBox;
    HighlightColor:TColorButton;
    SourcePreview:TSynEdit;
    SourceSize:TSpinEdit;
    ApplyButton,CancelButton:TButton;
    procedure ApplyClick(Sender:TObject);
    procedure LiveChange(Sender:TObject);
    procedure TokenChanged(Sender:TObject);
    procedure ColorChanged(Sender:TObject);
    procedure CompilerChanged(Sender:TObject);
    procedure SaveCompiler;
  private
    FUpdating,FCustomDark:Boolean;
    FColors:TSourcePalette;
    procedure RefreshPreview;
  public
    CompilerCommandChanged:Boolean;
    OnApply:TNotifyEvent;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    function Highlighting:TSourceHighlight;
  end;
implementation
uses Math, SourceFonts, DiagramPreview, UITheme, ToolJobs, IniFiles, SysUtils;
{$R *.lfm}
constructor TSettingsForm.Create(AOwner:TComponent);
var Token:TSourceToken; L:TLabel; B:TButton;
begin
  FUpdating:=True;
  inherited Create(AOwner);
  try
    SourceFontNames(SourceFont.Items); SourceFont.Style:=csDropDownList;
    SourceFont.ItemIndex:=SourceFont.Items.IndexOf(DefaultSourceFont);
    DiagramBackend.Checked:=DiagramPreviewEnabled; DiagramRenderer.ItemIndex:=Ord(SelectedDiagramBackend);
    HighlightEnabled.Checked:=SourceHighlight.Enabled; HighlightScheme.ItemIndex:=Ord(SourceHighlight.Scheme);
    FColors:=SourceHighlight.Colors; FCustomDark:=SourceHighlight.CustomDark;
    for Token:=Low(TSourceToken) to High(TSourceToken) do HighlightToken.Items.Add(SourceTokenNames[Token]);
    HighlightToken.ItemIndex:=Ord(stCommand); UseNativeSourceFonts(SourcePreview);
    SourcePreview.Text:='% Example source'+LineEnding+'\section{Example}'+LineEnding+
      'Text with \textbf{bold} and $\frac{x^2}{2}$.'+LineEnding+'\begin{equation} E=mc^2 \end{equation}';
    CompilerExecutable:=TEdit.Create(Self); CompilerExecutable.Name:='CompilerExecutable'; CompilerExecutable.Parent:=CompilerTab;
    TControl(FindComponent('EngineHelp')).SetBounds(24,72,555,32);
    CompilerExecutable.SetBounds(24,140,560,30); CompilerExecutable.Anchors:=[akLeft,akTop,akRight];
    L:=TLabel.Create(Self); L.Parent:=CompilerTab; L.Caption:='Executable (path or name)'; L.SetBounds(24,115,560,20);
    L:=TLabel.Create(Self); L.Parent:=CompilerTab; L.Caption:='Arguments — one per line; {source}, {output}, {directory}, {engine}'; L.SetBounds(24,184,560,38); L.AutoSize:=False; L.WordWrap:=True;
    CompilerArgs:=TMemo.Create(Self); CompilerArgs.Name:='CompilerArguments'; CompilerArgs.Parent:=CompilerTab;
    CompilerArgs.SetBounds(24,225,560,200); CompilerArgs.Anchors:=[akLeft,akTop,akRight,akBottom]; CompilerArgs.ScrollBars:=ssAutoBoth;
    B:=TButton.Create(Self); B.Parent:=CompilerTab; B.Caption:='Save compile command'; B.SetBounds(24,440,220,32); B.Anchors:=[akLeft,akBottom]; B.OnClick:=@CompilerChanged; B.Tag:=1;
    B:=TButton.Create(Self); B.Parent:=CompilerTab; B.Caption:='Restore defaults'; B.SetBounds(256,440,180,32); B.Anchors:=[akLeft,akBottom]; B.OnClick:=@CompilerChanged; B.Tag:=2;
    ExtensionSteps:=TCheckBox.Create(Self); ExtensionSteps.Parent:=CompilerTab; ExtensionSteps.SetBounds(444,440,150,32); ExtensionSteps.Anchors:=[akRight,akBottom];
    ExtensionSteps.Caption:='Build plug-ins'; ExtensionSteps.Hint:='Allow enabled plug-ins to run their configured compilation steps'; ExtensionSteps.ShowHint:=True;
    ExtensionSteps.Checked:=ExtensionBuildEnabled; ExtensionSteps.OnChange:=@LiveChange;
    DefaultEngine.OnChange:=@CompilerChanged; CompilerChanged(DefaultEngine);
  finally FUpdating:=False; end;
  RefreshPreview;
end;
destructor TSettingsForm.Destroy;
begin
  FUpdating:=True; OnApply:=nil; CancelTabUpdates(Pages); inherited Destroy;
end;
function TSettingsForm.Highlighting:TSourceHighlight;
begin
  Result.CustomDark:=FCustomDark; Result.Enabled:=HighlightEnabled.Checked; Result.Scheme:=TSourceScheme(EnsureRange(HighlightScheme.ItemIndex,0,3)); Result.Colors:=FColors;
end;
procedure TSettingsForm.RefreshPreview;
var Palette:TSourcePalette; WasUpdating:Boolean;
begin
  if SourcePreview=nil then Exit; WasUpdating:=FUpdating; FUpdating:=True;
  try
    DiagramRenderer.Enabled:=DiagramBackend.Checked; HighlightScheme.Enabled:=HighlightEnabled.Checked;
    HighlightToken.Enabled:=HighlightEnabled.Checked; HighlightColor.Enabled:=HighlightEnabled.Checked;
    Palette:=SourcePalette(Highlighting); HighlightColor.ButtonColor:=Palette[TSourceToken(EnsureRange(HighlightToken.ItemIndex,0,5))];
    SourcePreview.Font.Name:=NormalizeSourceFont(SourceFont.Text); SourcePreview.Font.Size:=SourceSize.Value;
    ApplySourceStyle(SourcePreview,Highlighting);
  finally FUpdating:=WasUpdating; end;
end;
procedure TSettingsForm.ApplyClick(Sender:TObject);
begin SaveCompiler; if Assigned(OnApply) then OnApply(Self); RefreshPreview; end;
procedure TSettingsForm.SaveCompiler;
var Ini:TIniFile; I:Integer; Section,OldProgram,OldArgs:string;
begin
  if (CompilerExecutable=nil) or (Trim(CompilerExecutable.Text)='') then Exit;
  CompilerProfile(DefaultEngine.Text,OldProgram,OldArgs);
  CompilerCommandChanged:=CompilerCommandChanged or (OldProgram<>CompilerExecutable.Text) or (TrimRight(OldArgs)<>TrimRight(CompilerArgs.Text));
  Section:='Compiler.'+DefaultEngine.Text; ForceDirectories(ExtractFileDir(GetAppConfigFile(False)));
  Ini:=TIniFile.Create(GetAppConfigFile(False));
  try Ini.WriteString(Section,'Executable',CompilerExecutable.Text); Ini.WriteInteger(Section,'ArgumentCount',CompilerArgs.Lines.Count);
    for I:=0 to CompilerArgs.Lines.Count-1 do Ini.WriteString(Section,'Argument'+IntToStr(I),CompilerArgs.Lines[I]);
  finally Ini.Free; end;
end;
procedure TSettingsForm.CompilerChanged(Sender:TObject);
var ProgramName,Args:string;
begin
  if Sender is TButton then begin
    if TButton(Sender).Tag=2 then begin CompilerExecutable.Text:=DefaultEngine.Text; CompilerArgs.Text:=DefaultCompilerArguments; end
    else begin SaveCompiler; if Assigned(OnApply) then OnApply(Self); end;
    Exit;
  end;
  CompilerProfile(DefaultEngine.Text,ProgramName,Args); CompilerExecutable.Text:=ProgramName; CompilerArgs.Text:=Args;
  LiveChange(Sender);
end;
procedure TSettingsForm.LiveChange(Sender:TObject);
begin
  if FUpdating or (csLoading in ComponentState) then Exit;
  if Assigned(OnApply) then OnApply(Self); RefreshPreview;
end;
procedure TSettingsForm.TokenChanged(Sender:TObject);
begin if not FUpdating then RefreshPreview; end;
procedure TSettingsForm.ColorChanged(Sender:TObject);
var Palette:TSourcePalette;
begin
  if FUpdating then Exit; Palette:=SourcePalette(Highlighting);
  if HighlightScheme.ItemIndex<>Ord(ssCustom) then FCustomDark:=(HighlightScheme.ItemIndex=Ord(ssDark)) or
    ((HighlightScheme.ItemIndex=Ord(ssAppearance)) and DarkMode);
  Palette[TSourceToken(EnsureRange(HighlightToken.ItemIndex,0,5))]:=HighlightColor.ButtonColor; FColors:=Palette;
  FUpdating:=True; try HighlightScheme.ItemIndex:=Ord(ssCustom); finally FUpdating:=False; end;
  LiveChange(Sender);
end;
end.
