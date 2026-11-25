unit ArchiveXML;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, DOM, Zipper;
function ArchiveText(const FileName,Entry:string):string;
function ParseXMLText(const Text:string):TXMLDocument;
function XMLName(Node:TDOMNode):string;
function XMLAttr(Node:TDOMNode; const Name:string; const Default:string=''):string;
function XMLChild(Node:TDOMNode; const Name:string):TDOMNode;
function XMLContent(Node:TDOMNode):string;
implementation
uses XMLRead;
type TEntryReader=class
  Text:string;
  procedure Open(Sender:TObject; var Stream:TStream; Item:TFullZipFileEntry);
  procedure Done(Sender:TObject; var Stream:TStream; Item:TFullZipFileEntry);
end;
procedure TEntryReader.Open(Sender:TObject; var Stream:TStream; Item:TFullZipFileEntry);
begin
  if Item.Size>32*1024*1024 then raise Exception.Create('Archive entry exceeds 32 MB: '+Item.ArchiveFileName);
  Stream:=TMemoryStream.Create;
end;
procedure TEntryReader.Done(Sender:TObject; var Stream:TStream; Item:TFullZipFileEntry);
begin
  try SetLength(Text,Stream.Size); Stream.Position:=0; if Text<>'' then Stream.ReadBuffer(Text[1],Length(Text));
  finally FreeAndNil(Stream); end;
end;
function ArchiveText(const FileName,Entry:string):string;
var Zip:TUnZipper; Reader:TEntryReader;
begin
  Zip:=TUnZipper.Create; Reader:=TEntryReader.Create;
  try Zip.FileName:=FileName; Zip.OnCreateStream:=@Reader.Open; Zip.OnDoneStream:=@Reader.Done;
    Zip.UnZipFiles(FileName,[RawByteString(Entry)]); Result:=Reader.Text;
  finally Zip.Free; Reader.Free; end;
end;
function ParseXMLText(const Text:string):TXMLDocument;
var Stream:TStringStream;
begin Result:=nil; Stream:=TStringStream.Create(Text); try ReadXMLFile(Result,Stream); finally Stream.Free; end; end;
function XMLName(Node:TDOMNode):string;
var P:Integer;
begin Result:=''; if Node=nil then Exit; Result:=UTF8Encode(Node.NodeName); P:=Pos(':',Result); if P>0 then Delete(Result,1,P); end;
function XMLAttr(Node:TDOMNode; const Name:string; const Default:string):string;
var I:Integer; Attr:TDOMNode;
begin
  Result:=Default; if (Node=nil) or (Node.Attributes=nil) then Exit;
  for I:=0 to Node.Attributes.Length-1 do begin Attr:=Node.Attributes[I];
    if (UTF8Encode(Attr.NodeName)=Name) or (XMLName(Attr)=Name) then Exit(UTF8Encode(Attr.NodeValue)); end;
end;
function XMLChild(Node:TDOMNode; const Name:string):TDOMNode;
begin Result:=nil; if Node=nil then Exit; Result:=Node.FirstChild; while (Result<>nil) and (XMLName(Result)<>Name) do Result:=Result.NextSibling; end;
function XMLContent(Node:TDOMNode):string;
var Child:TDOMNode;
begin
  Result:=''; if Node=nil then Exit;
  if Node.NodeType in [TEXT_NODE,CDATA_SECTION_NODE] then Exit(UTF8Encode(Node.NodeValue));
  Child:=Node.FirstChild;
  while Child<>nil do begin
    if XMLName(Child)='tab' then Result:=Result+#9
    else if XMLName(Child)='line-break' then Result:=Result+#10
    else Result:=Result+XMLContent(Child); Child:=Child.NextSibling;
  end;
end;
end.
