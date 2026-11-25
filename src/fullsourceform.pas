unit FullSourceForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Math, Types, Graphics, Forms, Controls, StdCtrls, ExtCtrls, SynEdit,
  SynEditTypes, SynEditWrappedView, SynHighlighterTeX, SynEditKeyCmds, Clipbrd, LCLType, UITheme, SourceRanges, SourceSelectionMarkup, SourceLinkMarkup, SourceFonts, LazUTF8;
type
  TFullSourceForm=class(TForm)
    Toolbar:TPanel;
    SaveButton,CloseButton,PreviewPositionButton,ShowPreviewButton:TButton;
    SourceEditor:TSynEdit;
    Highlighter:TSynTeXSyn;
    procedure CloseClick(Sender:TObject);
    procedure SaveClick(Sender:TObject);
    procedure LocateClick(Sender:TObject);
    procedure SourceChanged(Sender:TObject);
    procedure SourceStatus(Sender:TObject; Changes:TSynStatusChanges);
  private
    FUpdating:Boolean;
    FWrap:TLazSynEditLineWrapPlugin;
    FRangeMarkup:TSourceSelectionMarkup;
    FRanges:TSourceRanges;
    FRangeAnchor,FRangeFocus:Integer;
    FPreferredFont:string;
    procedure SourceCommand(Sender:TObject; var Command:TSynEditorCommand; var AChar:TUTF8Char; Data:Pointer);
  public
    OnSourceChange,OnSelectionChange,OnSaveRequest,OnLocateSource,OnLocatePreview:TNotifyEvent;
    constructor Create(AOwner:TComponent); override;
    procedure LoadSource(const Source:string; Anchor,Focus:Integer);
    procedure SetSelection(Anchor,Focus:Integer);
    procedure Selection(out Anchor,Focus:Integer);
    procedure SetSelectedRanges(const Ranges:TSourceRanges; Anchor,Focus:Integer);
    function SelectedRanges:TSourceRanges;
    procedure RevealOffset(Offset:Integer);
    function ViewOffset:Integer;
    procedure ApplyAppearance(const FontName:string; FontSize:Integer);
  end;
implementation
uses SourceStyle, EditorClipboard;
{$R *.lfm}
type TSourceScroll=class(TSynEdit) public property TopView; end;

constructor TFullSourceForm.Create(AOwner:TComponent);
begin
  inherited Create(AOwner); UseNativeSourceFonts(SourceEditor); SourceEditor.SetDefaultKeystrokes; SourceEditor.ResetMouseActions;
  EnableSourceLinks(SourceEditor);
  FWrap:=TLazSynEditLineWrapPlugin.Create(SourceEditor);
  FRangeMarkup:=TSourceSelectionMarkup.Create(SourceEditor); SourceEditor.MarkupManager.AddMarkUp(FRangeMarkup);
  SourceEditor.OnProcessCommand:=@SourceCommand;
  SourceEditor.Options:=SourceEditor.Options+[eoPersistentCaret]-[eoScrollPastEol];
  SourceEditor.Options2:=SourceEditor.Options2+[eoPersistentCaretStopBlink]-[eoScrollPastEolAddPage,eoScrollPastEolAutoCaret];
  ApplyAppearance(DefaultSourceFont,12);
end;
procedure TFullSourceForm.ApplyAppearance(const FontName:string; FontSize:Integer);
var WasUpdating:Boolean;
begin
  WasUpdating:=FUpdating; FUpdating:=True;
  try
    FPreferredFont:=FontName;
    ApplyTheme(Self); SourceEditor.Font.Name:=SourceFontForText(FontName,SourceEditor.Text); SourceEditor.Font.Size:=FontSize;
    SmoothSourceFont(SourceEditor.Font); ApplySourceStyle(SourceEditor);
  finally FUpdating:=WasUpdating; end;
end;
procedure TFullSourceForm.SetSelection(Anchor,Focus:Integer);
var WasUpdating:Boolean;
begin
  WasUpdating:=FUpdating; FUpdating:=True;
  try
    FRanges:=nil; FRangeMarkup.SetRanges('',nil);
    SourceEditor.LogicalCaretXY:=SourceBytePoint(SourceEditor.Text,Focus);
    SourceEditor.BlockBegin:=SourceBytePoint(SourceEditor.Text,Anchor); SourceEditor.BlockEnd:=SourceBytePoint(SourceEditor.Text,Focus);
    SourceEditor.LogicalCaretXY:=SourceBytePoint(SourceEditor.Text,Focus);
  finally FUpdating:=WasUpdating; end;
end;
procedure TFullSourceForm.LoadSource(const Source:string; Anchor,Focus:Integer);
var SavedTop:Integer;
begin
  FUpdating:=True; SavedTop:=SourceEditor.TopLine;
  try
    if SourceEditor.Text<>Source then SourceEditor.Text:=Source;
    SourceEditor.Font.Name:=SourceFontForText(FPreferredFont,Source);
    SetSelection(Anchor,Focus); SourceEditor.TopLine:=SavedTop;
  finally FUpdating:=False; end;
end;
procedure TFullSourceForm.Selection(out Anchor,Focus:Integer);
var A,B:Integer;
begin
  if Length(FRanges)>0 then begin Anchor:=FRangeAnchor; Focus:=FRangeFocus; Exit; end;
  Focus:=Length(SourceEditor.TextBetweenPoints[Point(1,1),SourceEditor.LogicalCaretXY]);
  A:=Length(SourceEditor.TextBetweenPoints[Point(1,1),SourceEditor.BlockBegin]); B:=Length(SourceEditor.TextBetweenPoints[Point(1,1),SourceEditor.BlockEnd]);
  Anchor:=A; if Focus=A then Anchor:=B;
end;
procedure TFullSourceForm.SetSelectedRanges(const Ranges:TSourceRanges; Anchor,Focus:Integer);
var WasUpdating:Boolean;
begin
  WasUpdating:=FUpdating; FUpdating:=True;
  try SetSelection(Focus,Focus); FRanges:=Copy(Ranges); FRangeAnchor:=Anchor; FRangeFocus:=Focus; FRangeMarkup.SetRanges(SourceEditor.Text,FRanges);
  finally FUpdating:=WasUpdating; end;
end;
function TFullSourceForm.SelectedRanges:TSourceRanges;
begin Result:=Copy(FRanges); end;
procedure TFullSourceForm.SourceCommand(Sender:TObject; var Command:TSynEditorCommand; var AChar:TUTF8Char; Data:Pointer);
var I,Caret,R,C:Integer; SelectionText,S,Value:string; Lines,Cells:TStringList;
begin
  if FUpdating or (Length(FRanges)=0) then Exit;
  if (Command<>ecCopy) and (Command<>ecCut) and (Command<>ecPaste) and
     (Command<>ecDeleteChar) and (Command<>ecDeleteLastChar) and (Command<>ecChar) then Exit;
  SelectionText:=''; R:=-1; C:=-1;
  for I:=0 to High(FRanges) do begin
    if (R>=0) and (FRanges[I].Row<>R) then SelectionText:=SelectionText+LineEnding
    else if (R>=0) then SelectionText:=SelectionText+#9;
    SelectionText:=SelectionText+Trim(Copy(SourceEditor.Text,FRanges[I].Start+1,FRanges[I].Finish-FRanges[I].Start)); R:=FRanges[I].Row;
  end;
  if (Command=ecCopy) or (Command=ecCut) then Clipboard.AsText:=SelectionText;
  if Command=ecCopy then begin Command:=ecNone; Exit; end;
  Value:=''; if Command=ecPaste then Value:=ReadClipboardText else if Command=ecChar then Value:=AChar;
  Lines:=TStringList.Create; Cells:=TStringList.Create;
  try
    Lines.Text:=Value; Cells.Delimiter:=#9; Cells.StrictDelimiter:=True; S:=SourceEditor.Text; Caret:=FRanges[0].Start;
    for I:=High(FRanges) downto 0 do begin
      R:=FRanges[I].Row; C:=FRanges[I].Col; Cells.Clear; if R<Lines.Count then Cells.DelimitedText:=Lines[R];
      SelectionText:=''; if C<Cells.Count then SelectionText:=Cells[C];
      Delete(S,FRanges[I].Start+1,FRanges[I].Finish-FRanges[I].Start); Insert(SelectionText,S,FRanges[I].Start+1);
      if I=0 then Inc(Caret,Length(SelectionText));
    end;
    FUpdating:=True;
    try
      SourceEditor.BeginUndoBlock;
      try SourceEditor.SelectAll; SourceEditor.SelText:=S; SetSelection(Caret,Caret);
      finally SourceEditor.EndUndoBlock; end;
    finally FUpdating:=False; end;
    if Assigned(OnSourceChange) then OnSourceChange(Self);
  finally Cells.Free; Lines.Free; end;
  Command:=ecNone;
end;
procedure TFullSourceForm.SourceChanged(Sender:TObject);
begin
  if FUpdating then Exit;
  SourceEditor.Font.Name:=SourceFontForText(FPreferredFont,SourceEditor.Text);
  if Assigned(OnSourceChange) then OnSourceChange(Self);
end;
procedure TFullSourceForm.SourceStatus(Sender:TObject; Changes:TSynStatusChanges);
begin
  if FUpdating or not Visible or not SourceEditor.Focused or (Changes*[scCaretX,scCaretY,scSelection]=[]) then Exit;
  FRanges:=nil; if FRangeMarkup<>nil then FRangeMarkup.SetRanges('',nil);
  if Assigned(OnSelectionChange) then OnSelectionChange(Self);
end;
procedure TFullSourceForm.CloseClick(Sender:TObject);
begin Hide; end;
procedure TFullSourceForm.SaveClick(Sender:TObject);
begin if Assigned(OnSaveRequest) then OnSaveRequest(Self); end;
procedure TFullSourceForm.LocateClick(Sender:TObject);
begin
  if Sender=PreviewPositionButton then begin if Assigned(OnLocateSource) then OnLocateSource(Self); end
  else if Assigned(OnLocatePreview) then OnLocatePreview(Self);
end;
procedure TFullSourceForm.RevealOffset(Offset:Integer);
var P:TPoint;
begin
  P:=SourceEditor.TextXYToScreenXY(SourceEditor.LogicalToPhysicalPos(SourceBytePoint(SourceEditor.Text,Offset)));
  TSourceScroll(SourceEditor).TopView:=Max(1,TSourceScroll(SourceEditor).TopView+P.Y-Max(1,SourceEditor.LinesInWindow div 3));
end;
function TFullSourceForm.ViewOffset:Integer;
var P,Screen:TPoint;
begin
  P:=SourceEditor.LogicalCaretXY; Screen:=SourceEditor.TextXYToScreenXY(SourceEditor.LogicalToPhysicalPos(P));
  if (Screen.Y<1) or (Screen.Y>SourceEditor.LinesInWindow) then
    P:=SourceEditor.PhysicalToLogicalPos(SourceEditor.ScreenXYToTextXY(Point(1,1)));
  Result:=Length(SourceEditor.TextBetweenPoints[Point(1,1),P]);
end;
end.
