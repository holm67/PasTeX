unit PackageSourceForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, SynEdit, SynEditTypes, SynEditWrappedView;
type
  TPackageSourceForm=class(TForm)
  private
    FPath,FOriginal:string;
    FLoading,FSaved:Boolean;
    procedure Changed(Sender:TObject);
    procedure SaveClick(Sender:TObject);
    procedure CloseClick(Sender:TObject);
    procedure ConfirmClose(Sender:TObject; var CanClose:Boolean);
    procedure EditorKeyDown(Sender:TObject; var Key:Word; Shift:TShiftState);
  public
    SourceEditor:TSynEdit;
    FilePath:TEdit;
    SaveButton,SaveAsButton:TButton;
    constructor Create(AOwner:TComponent); override;
    procedure Load(const Path,FontName:string; FontSize:Integer; Wrap:Boolean);
    function SaveToFile(const Path:string):Boolean;
    property Path:string read FPath;
    property Saved:Boolean read FSaved;
  end;
implementation
uses Dialogs, LCLType, SynHighlighterTeX, SourceFonts, SourceStyle, SourceCompletion, UITheme, TeXPackageSources;
constructor TPackageSourceForm.Create(AOwner:TComponent);
var Bar:TPanel; B:TButton;
begin
  inherited CreateNew(AOwner); Position:=poMainFormCenter; Caption:='Package source';
  ClientWidth:=920; ClientHeight:=640; Constraints.MinWidth:=600; Constraints.MinHeight:=300;
  Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alTop; Bar.Height:=44; Bar.BevelOuter:=bvNone;
  SaveButton:=TButton.Create(Self); SaveButton.Parent:=Bar; SaveButton.Caption:='Save';
  SaveButton.SetBounds(12,7,90,30); SaveButton.OnClick:=@SaveClick;
  SaveAsButton:=TButton.Create(Self); SaveAsButton.Parent:=Bar; SaveAsButton.Caption:='Save As…';
  SaveAsButton.SetBounds(110,7,110,30); SaveAsButton.Tag:=1; SaveAsButton.OnClick:=@SaveClick;
  B:=TButton.Create(Self); B.Parent:=Bar; B.Caption:='Close'; B.SetBounds(228,7,90,30); B.OnClick:=@CloseClick; B.Cancel:=True;
  FilePath:=TEdit.Create(Self); FilePath.Parent:=Self; FilePath.Align:=alTop; FilePath.ReadOnly:=True;
  FilePath.Hint:='The package source is saved separately from the document preamble.'; FilePath.ShowHint:=True;
  SourceEditor:=TSynEdit.Create(Self); SourceEditor.Parent:=Self; SourceEditor.Align:=alClient;
  SourceEditor.Highlighter:=TSynTeXSyn.Create(Self); SourceEditor.SetDefaultKeystrokes; SourceEditor.ResetMouseActions;
  SourceEditor.Options:=SourceEditor.Options-[eoScrollPastEol];
  SourceEditor.Options2:=SourceEditor.Options2-[eoScrollPastEolAddPage,eoScrollPastEolAutoCaret];
  UseNativeSourceFonts(SourceEditor); SourceEditor.OnChange:=@Changed; SourceEditor.OnKeyDown:=@EditorKeyDown; OnCloseQuery:=@ConfirmClose;
end;
procedure TPackageSourceForm.Load(const Path,FontName:string; FontSize:Integer; Wrap:Boolean);
begin
  FLoading:=True;
  try
    FSaved:=False; FPath:=ExpandFileName(Path); SourceEditor.Lines.LoadFromFile(FPath); FOriginal:=SourceEditor.Text;
    if Wrap then TLazSynEditLineWrapPlugin.Create(SourceEditor) else SourceEditor.ScrollBars:=ssBoth;
    ApplyTheme(Self); SourceEditor.Font.Name:=SourceFontForText(FontName,SourceEditor.Text); SourceEditor.Font.Size:=FontSize;
    ApplySourceStyle(SourceEditor); SetSourceCompletionContext(SourceEditor,'',ExtractFilePath(FPath),'pdflatex'); SourceEditor.ClearUndo;
  finally FLoading:=False; end;
  Changed(nil);
end;
procedure TPackageSourceForm.Changed(Sender:TObject);
begin
  if FLoading then Exit;
  FilePath.Text:=FPath; Caption:=ExtractFileName(FPath)+' — Package source';
  SaveButton.Enabled:=SourceEditor.Text<>FOriginal;
  if SaveButton.Enabled then Caption:='* '+Caption;
end;
function TPackageSourceForm.SaveToFile(const Path:string):Boolean;
begin
  Result:=False;
  try
    SourceEditor.Lines.SaveToFile(Path); FPath:=ExpandFileName(Path); FOriginal:=SourceEditor.Text; ReadTeXSource(FPath,True); FSaved:=True;
    Changed(nil); Result:=True;
  except on E:Exception do MessageDlg('Could not save package source',E.Message+LineEnding+'Use Save As to save a local copy.',mtError,[mbOK],0); end;
end;
procedure TPackageSourceForm.EditorKeyDown(Sender:TObject; var Key:Word; Shift:TShiftState);
begin
  if (Key=VK_S) and (ssCtrl in Shift) then begin
    if ssShift in Shift then SaveClick(SaveAsButton) else SaveClick(SaveButton); Key:=0;
  end;
end;
procedure TPackageSourceForm.SaveClick(Sender:TObject);
var D:TSaveDialog;
begin
  if (Sender<>SaveAsButton) and SaveToFile(FPath) then Exit;
  D:=TSaveDialog.Create(Self);
  try
    D.Filter:='LaTeX package source|*.sty|All files|*'; D.DefaultExt:='sty'; D.FileName:=FPath;
    D.Options:=D.Options+[ofOverwritePrompt]; if D.Execute then SaveToFile(D.FileName);
  finally D.Free; end;
end;
procedure TPackageSourceForm.CloseClick(Sender:TObject);
begin Close; end;
procedure TPackageSourceForm.ConfirmClose(Sender:TObject; var CanClose:Boolean);
begin
  if SourceEditor.Text=FOriginal then Exit;
  case MessageDlg('Save package source?',ExtractFileName(FPath)+' has unsaved changes.',mtConfirmation,[mbYes,mbNo,mbCancel],0) of
    mrYes:begin SaveClick(SaveButton); CanClose:=SourceEditor.Text=FOriginal; end;
    mrCancel:CanClose:=False;
  end;
end;
end.
