unit SourceLinkMarkup;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Types, Graphics, Controls, ExtCtrls, SynEdit, SourceSelectionMarkup;
type
  TSourceLinkMarkup=class(TSourceSelectionMarkup)
  private
    FEditor:TSynEdit;
    FTimer:TTimer;
    FLastSource:string;
    FLastOffset:Integer;
    FFirst,FLast:Integer;
    procedure MouseMove(Sender:TObject; Shift:TShiftState; X,Y:Integer);
    procedure MouseLeave(Sender:TObject);
    procedure KeyChange(Sender:TObject; var Key:Word; Shift:TShiftState);
    procedure Timer(Sender:TObject);
  protected
    procedure DoTextChanged(StartLine,EndLine,CountDiff:Integer); override;
  public
    constructor Create(Editor:TSynEdit);
    destructor Destroy; override;
    procedure UpdateLink(Offset:Integer; CtrlPressed:Boolean);
    property LinkFirst:Integer read FFirst;
    property LinkLast:Integer read FLast;
  end;
procedure EnableSourceLinks(Editor:TSynEdit);
implementation
uses LCLType, Forms, TeXProject, SourceRanges;
constructor TSourceLinkMarkup.Create(Editor:TSynEdit);
begin
  inherited Create(Editor); FEditor:=Editor; FFirst:=-1; FLast:=-1; FLastOffset:=-1;
  FTimer:=TTimer.Create(nil); FTimer.Interval:=50; FTimer.Enabled:=False; FTimer.OnTimer:=@Timer;
  Editor.OnMouseMove:=@MouseMove; Editor.OnMouseLeave:=@MouseLeave;
  Editor.RegisterBeforeKeyDownHandler(@KeyChange); Editor.RegisterBeforeKeyUpHandler(@KeyChange);
end;
destructor TSourceLinkMarkup.Destroy;
begin
  FTimer.Free;
  FEditor.UnregisterBeforeKeyDownHandler(@KeyChange); FEditor.UnregisterBeforeKeyUpHandler(@KeyChange);
  inherited Destroy;
end;
procedure TSourceLinkMarkup.UpdateLink(Offset:Integer; CtrlPressed:Boolean);
var First,Last:Integer; Source,Target:string; Ranges:TSourceRanges;
begin
  First:=-1; Last:=-1; Source:='';
  if CtrlPressed then begin
    Source:=FEditor.Text;
    if (Offset=FLastOffset) and (Source=FLastSource) then begin First:=FFirst; Last:=FLast; end
    else if not LinkedTeXInputRange(Source,Offset,First,Last) then TeXHyperlinkAt(Source,Offset,Target,First,Last);
  end;
  FLastOffset:=Offset; if not CtrlPressed then FLastOffset:=-1; FLastSource:=Source;
  if (First=FFirst) and (Last=FLast) then Exit;
  FFirst:=First; FLast:=Last; Ranges:=nil;
  if First>=0 then begin SetLength(Ranges,1); Ranges[0].Start:=First; Ranges[0].Finish:=Last; end;
  SetRanges(Source,Ranges); MarkupInfo.Foreground:=clNone; MarkupInfo.Background:=clNone;
  MarkupInfo.Style:=[fsUnderline]; MarkupInfo.StyleMask:=[fsUnderline];
  if First>=0 then FEditor.Cursor:=crHandPoint else FEditor.Cursor:=crIBeam;
end;
procedure TSourceLinkMarkup.MouseMove(Sender:TObject; Shift:TShiftState; X,Y:Integer);
var P:TPoint;
begin
  FTimer.Enabled:=True;
  if not (ssCtrl in Shift) then begin UpdateLink(-1,False); Exit; end;
  P:=FEditor.PixelsToLogicalPos(Point(X,Y));
  UpdateLink(Length(FEditor.TextBetweenPoints[Point(1,1),P]),True);
end;
procedure TSourceLinkMarkup.MouseLeave(Sender:TObject);
begin FTimer.Enabled:=False; UpdateLink(-1,False); end;
procedure TSourceLinkMarkup.KeyChange(Sender:TObject; var Key:Word; Shift:TShiftState);
begin
  if Key<>VK_CONTROL then Exit;
  if ssCtrl in Shift then Timer(nil) else UpdateLink(-1,False);
end;
procedure TSourceLinkMarkup.Timer(Sender:TObject);
var P:TPoint;
begin
  P:=FEditor.ScreenToClient(Mouse.CursorPos);
  if not Application.Active or not FEditor.Visible or not PtInRect(FEditor.ClientRect,P) then begin MouseLeave(nil); Exit; end;
  MouseMove(nil,GetKeyShiftState,P.X,P.Y);
end;
procedure TSourceLinkMarkup.DoTextChanged(StartLine,EndLine,CountDiff:Integer);
begin FLastOffset:=-1; UpdateLink(-1,False); inherited DoTextChanged(StartLine,EndLine,CountDiff); end;
procedure EnableSourceLinks(Editor:TSynEdit);
begin Editor.MarkupManager.AddMarkUp(TSourceLinkMarkup.Create(Editor)); end;
end.
