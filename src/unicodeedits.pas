unit UnicodeEdits;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses StdCtrls
  {$IFDEF LCLqt5}, Qt5{$ENDIF}{$IFDEF LCLqt6}, Qt6{$ENDIF};
type
  {$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}
  TUnicodeInputHook=class
  private
    FHandle:QObject_hookH;
    function InputEvent(Sender:QObjectH; Event:QEventH):Boolean; cdecl;
  public
    constructor Create(Widget:QWidgetH);
    destructor Destroy; override;
  end;
  {$ENDIF}
  TUnicodeEdit=class(TEdit)
  {$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}
  private
    FInputHook:TUnicodeInputHook;
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
  {$ENDIF}
  end;
  TUnicodeComboBox=class(TComboBox)
  {$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}
  private
    FInputHook:TUnicodeInputHook;
  protected
    procedure CreateWnd; override;
    procedure DestroyWnd; override;
  {$ENDIF}
  end;
implementation
{$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}
uses SysUtils, QtWidgets, LCLType;
procedure TUnicodeEdit.CreateWnd;
begin
  inherited CreateWnd;
  FInputHook:=TUnicodeInputHook.Create(TQtWidget(Handle).Widget);
end;
procedure TUnicodeEdit.DestroyWnd;
begin
  FreeAndNil(FInputHook);
  inherited DestroyWnd;
end;
procedure TUnicodeComboBox.CreateWnd;
begin
  inherited CreateWnd;
  FInputHook:=TUnicodeInputHook.Create(QComboBox_lineEdit(QComboBoxH(TQtWidget(Handle).Widget)));
end;
procedure TUnicodeComboBox.DestroyWnd;
begin
  FreeAndNil(FInputHook);
  inherited DestroyWnd;
end;
constructor TUnicodeInputHook.Create(Widget:QWidgetH);
begin
  inherited Create; if Widget=nil then Exit;
  FHandle:=QObject_hook_create(Widget); QObject_hook_hook_events(FHandle,@InputEvent);
end;
destructor TUnicodeInputHook.Destroy;
begin
  if FHandle<>nil then QObject_hook_destroy(FHandle);
  inherited Destroy;
end;
function TUnicodeInputHook.InputEvent(Sender:QObjectH; Event:QEventH):Boolean; cdecl;
var Committed:WideString;
begin
  Result:=False;
  if QEvent_type(Event)=QEventInputMethod then begin
    { Let QLineEdit retain its composition, replacement and undo semantics.
      The LCL key bridge needlessly converts a commit into individual keys. }
    QObject_event(Sender,Event); Result:=True;
  end else if QEvent_type(Event)=QEventKeyPress then begin
    QKeyEvent_text(QKeyEventH(Event),@Committed);
    { Some input methods commit a whole phrase in one key event. LCL's
      TUTF8Char buffer holds only seven bytes and truncates longer phrases. }
    if Length(UTF8Encode(Committed))>SizeOf(TUTF8Char)-1 then begin
      if not QLineEdit_isReadOnly(QLineEditH(Sender)) then QLineEdit_insert(QLineEditH(Sender),@Committed);
      QEvent_accept(Event); Result:=True;
    end;
  end;
end;
{$ENDIF}
end.
