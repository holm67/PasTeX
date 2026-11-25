unit SourceBuffers;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes;
type
  TSourceBuffer=class
    Text:string;
    Revision:QWord;
  end;
  { Keep paths separate from their text: reading a buffer shares the string
    instead of allocating a copy of a name=value entry on every lookup. }
  TSourceBuffers=class
  private
    FItems:TStringList;
    function GetCount:Integer;
    function GetName(Index:Integer):string;
    function GetText(Index:Integer):string;
    function GetValue(const Path:string):string;
    procedure SetValue(const Path,Text:string);
  public
    constructor Create;
    destructor Destroy; override;
    procedure Clear;
    procedure Delete(Index:Integer);
    procedure Assign(Other:TSourceBuffers);
    function IndexOf(const Path:string):Integer;
    function Buffer(Index:Integer):TSourceBuffer;
    property Count:Integer read GetCount;
    property Names[Index:Integer]:string read GetName;
    property ValueFromIndex[Index:Integer]:string read GetText;
    property Values[const Path:string]:string read GetValue write SetValue; default;
  end;
implementation
constructor TSourceBuffers.Create;
begin
  inherited Create; FItems:=TStringList.Create; FItems.OwnsObjects:=True;
  FItems.CaseSensitive:={$IFDEF UNIX}True{$ELSE}False{$ENDIF}; FItems.Sorted:=True;
end;
destructor TSourceBuffers.Destroy;
begin FItems.Free; inherited; end;
procedure TSourceBuffers.Clear;
begin FItems.Clear; end;
procedure TSourceBuffers.Delete(Index:Integer);
begin FItems.Delete(Index); end;
procedure TSourceBuffers.Assign(Other:TSourceBuffers);
var I:Integer;
begin
  if Other=Self then Exit;
  Clear; for I:=0 to Other.Count-1 do Values[Other.Names[I]]:=Other.ValueFromIndex[I];
end;
function TSourceBuffers.GetCount:Integer;
begin Result:=FItems.Count; end;
function TSourceBuffers.GetName(Index:Integer):string;
begin Result:=FItems[Index]; end;
function TSourceBuffers.IndexOf(const Path:string):Integer;
begin Result:=FItems.IndexOf(Path); end;
function TSourceBuffers.Buffer(Index:Integer):TSourceBuffer;
begin Result:=TSourceBuffer(FItems.Objects[Index]); end;
function TSourceBuffers.GetText(Index:Integer):string;
begin Result:=Buffer(Index).Text; end;
function TSourceBuffers.GetValue(const Path:string):string;
var I:Integer;
begin I:=IndexOf(Path); if I<0 then Result:='' else Result:=GetText(I); end;
procedure TSourceBuffers.SetValue(const Path,Text:string);
var I:Integer; Item:TSourceBuffer;
begin
  I:=IndexOf(Path);
  if I<0 then begin Item:=TSourceBuffer.Create; FItems.AddObject(Path,Item); end
  else Item:=Buffer(I);
  if Item.Text=Text then Exit;
  Item.Text:=Text; Inc(Item.Revision);
end;
end.
