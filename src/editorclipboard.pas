unit EditorClipboard;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Types, LCLType, Clipbrd, SynEdit, SynEditTypes;
function ReadClipboardText:string;
function ReadBodyClipboard:string;
function HasVisualClipboard:Boolean;
procedure WriteVisualClipboard(const Source,Body:string);
procedure ConfigureClipboard(Editor:TSynEdit);
implementation
uses SysUtils
  {$IFDEF LCLqt5}, Qt5{$ENDIF}{$IFDEF LCLqt6}, Qt6{$ENDIF};
const BodyFormat='application/x-pastex-body';
function ReadFormat(const Name:string; out Value:string):Boolean;
{$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}
var Data:QMimeDataH; Bytes:QByteArrayH; Mime:WideString;
begin
  Value:=''; Mime:=UTF8Decode(Name);
  Data:=QClipboard_mimeData(QGuiApplication_clipboard(),QClipboardClipboard);
  Result:=(Data<>nil) and QMimeData_hasFormat(Data,@Mime); if not Result then Exit;
  Bytes:=QByteArray_create;
  try
    QMimeData_data(Data,Bytes,@Mime); SetLength(Value,QByteArray_size(Bytes));
    if Value<>'' then Move(QByteArray_constData(Bytes)^,Value[1],Length(Value));
  finally QByteArray_destroy(Bytes); end;
{$ELSE}
var Stream:TMemoryStream; Format:TClipboardFormat;
begin
  Value:=''; Format:=RegisterClipboardFormat(Name);
  Result:=Clipboard.HasFormat(Format); if not Result then Exit;
  Stream:=TMemoryStream.Create;
  try
    Result:=Clipboard.GetFormat(Format,Stream);
    if not Result then Exit;
    SetLength(Value,Stream.Size); Stream.Position:=0;
    if Value<>'' then Stream.ReadBuffer(Value[1],Length(Value));
  finally Stream.Free; end;
{$ENDIF}
  if (Value<>'') and (Value[Length(Value)]=#0) then SetLength(Value,Length(Value)-1);
end;
function ReadClipboardText:string;
const Formats:array[0..2] of string=('text/plain;charset=utf-8','text/plain;charset=UTF-8','UTF8_STRING');
var Name:string;
  {$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}Data:QMimeDataH; Text:WideString;{$ENDIF}
begin
  { Ask for Unicode text explicitly. Legacy STRING and rich-text targets can
    contain encoding escapes rather than the characters the user copied. }
  for Name in Formats do
    if ReadFormat(Name,Result) and (Result<>'') then Exit;
  {$IF DEFINED(LCLqt5) OR DEFINED(LCLqt6)}
  Data:=QClipboard_mimeData(QGuiApplication_clipboard(),QClipboardClipboard);
  if (Data<>nil) and QMimeData_hasText(Data) then begin
    QMimeData_text(Data,@Text); Exit(UTF8Encode(Text));
  end;
  {$ENDIF}
  Result:=Clipboard.AsText;
end;
function ReadBodyClipboard:string;
begin if not ReadFormat(BodyFormat,Result) then Result:=ReadClipboardText; end;
function HasVisualClipboard:Boolean;
var Value:string;
begin Result:=ReadFormat(BodyFormat,Value); end;
procedure WriteVisualClipboard(const Source,Body:string);
var Stream:TStringStream;
begin
  Clipboard.AsText:=Source;
  Stream:=TStringStream.Create(Body);
  try Clipboard.AddFormat(RegisterClipboardFormat(BodyFormat),Stream); finally Stream.Free; end;
end;
type
  TClipboardAdapter=class(TComponent)
  private
    FPrevious:TSynCopyPasteEvent;
    procedure Paste(Sender:TObject; var Text:string; var Mode:TSynSelectionMode;
      Start:TPoint; var Action:TSynCopyPasteAction);
  end;
procedure TClipboardAdapter.Paste(Sender:TObject; var Text:string; var Mode:TSynSelectionMode;
  Start:TPoint; var Action:TSynCopyPasteAction);
begin
  { Keep SynEdit's own selection mode and folding metadata when available. }
  Text:=ReadClipboardText;
  if Assigned(FPrevious) then FPrevious(Sender,Text,Mode,Start,Action);
end;
procedure ConfigureClipboard(Editor:TSynEdit);
var I:Integer; Adapter:TClipboardAdapter;
begin
  for I:=0 to Editor.ComponentCount-1 do if Editor.Components[I] is TClipboardAdapter then Exit;
  Adapter:=TClipboardAdapter.Create(Editor); Adapter.FPrevious:=Editor.OnPaste; Editor.OnPaste:=@Adapter.Paste;
end;
end.
