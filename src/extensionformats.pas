unit ExtensionFormats;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, FPJSON;
function ExtensionDocumentFormats:TJSONArray;
function FindExtensionFormat(const FileName:string):string;
function ExtensionFormatInfo(const ID:string):TJSONObject;
function ExtensionSourceFilter(const ID:string):string;
function RequestDocumentFormat(const ID,Action:string; Values:TJSONObject; out Error:string):TJSONObject;
function RenderExtensionDocument(const ID,Source,Directory:string; out Preview,Error:string):Boolean;
implementation
uses SysUtils, AddonModel, DocumentFormats;
function ExtensionDocumentFormats:TJSONArray;
var Catalog:TEditorAddons; A:TEditorAddon; I,J:Integer; F:TJSONObject;
begin
  Result:=TJSONArray.Create; Catalog:=TEditorAddons.Create(True);
  try
    Catalog.Load;
    for I:=0 to Catalog.Count-1 do begin
      A:=TEditorAddon(Catalog[I]); if not A.Installed or not A.Enabled or not (A.Manifest.Find('formats') is TJSONArray) then Continue;
      for J:=0 to A.Manifest.Arrays['formats'].Count-1 do begin
        F:=TJSONObject(A.Manifest.Arrays['formats'].Objects[J].Clone); F.Strings['provider']:=A.ID;
        F.Strings['key']:=A.ID+':'+F.Get('id',''); Result.Add(F);
      end;
    end;
  finally Catalog.Free; end;
end;
function FindExtensionFormat(const FileName:string):string;
var Formats:TJSONArray; I,J:Integer; Extension:string;
begin
  Result:=''; Extension:=LowerCase(ExtractFileExt(FileName)); if Copy(Extension,1,1)='.' then Delete(Extension,1,1);
  Formats:=ExtensionDocumentFormats;
  try for I:=0 to Formats.Count-1 do if Formats.Objects[I].Find('extensions') is TJSONArray then
    for J:=0 to Formats.Objects[I].Arrays['extensions'].Count-1 do
      if SameText(Extension,Formats.Objects[I].Arrays['extensions'].Strings[J]) then Exit(Formats.Objects[I].Get('key',''));
  finally Formats.Free; end;
end;
function ExtensionFormatInfo(const ID:string):TJSONObject;
var Formats:TJSONArray; I:Integer;
begin
  Result:=nil; Formats:=ExtensionDocumentFormats;
  try for I:=0 to Formats.Count-1 do if Formats.Objects[I].Get('key','')=ID then Exit(TJSONObject(Formats.Objects[I].Clone));
  finally Formats.Free; end;
end;
function ExtensionSourceFilter(const ID:string):string;
var Formats:TJSONArray; I,J:Integer; Pattern:string; F:TJSONObject;
begin
  Result:=''; Formats:=ExtensionDocumentFormats;
  try
    for I:=0 to Formats.Count-1 do begin
      F:=Formats.Objects[I]; if (ID<>'') and (F.Get('key','')<>ID) then Continue;
      Pattern:=''; if not (F.Find('extensions') is TJSONArray) then Continue;
      for J:=0 to F.Arrays['extensions'].Count-1 do begin
        if Pattern<>'' then Pattern:=Pattern+';'; Pattern:=Pattern+'*.'+F.Arrays['extensions'].Strings[J];
      end;
      if Pattern<>'' then Result:=Result+F.Get('name','Source files')+'|'+Pattern+'|';
    end;
  finally Formats.Free; end;
end;
function RequestDocumentFormat(const ID,Action:string; Values:TJSONObject; out Error:string):TJSONObject;
var Catalog:TEditorAddons; A:TEditorAddon; P:Integer;
begin
  Error:=''; Result:=nil; Catalog:=TEditorAddons.Create(True);
  try
    try
      P:=Pos(':',ID); Catalog.Load; A:=Catalog.Find(Copy(ID,1,P-1));
      if (P=0) or (A=nil) or not A.Installed or not A.Enabled then begin Error:='Install and enable the document-format plug-in to show a preview.'; Exit; end;
      Values.Strings['format']:=Copy(ID,P+1,MaxInt); Result:=A.Request(Action,Values); Error:=Result.Get('error','');
      if Error<>'' then FreeAndNil(Result);
    except on E:Exception do Error:=E.Message; end;
  finally Catalog.Free; end;
end;
function RenderExtensionDocument(const ID,Source,Directory:string; out Preview,Error:string):Boolean;
var Values,Response,Info:TJSONObject;
begin
  Preview:=''; Error:=''; Result:=False; Values:=nil; Response:=nil; Info:=ExtensionFormatInfo(ID);
  try
    if Info=nil then begin Error:='Install and enable the document-format plug-in to show a preview.'; Exit; end;
    Values:=TJSONObject.Create(['source',Source,'directory',Directory]);
    Response:=RequestDocumentFormat(ID,Info.Get('renderAction','render'),Values,Error); if Response=nil then Exit;
    if Response.Find('source')<>nil then Preview:=Response.Get('source','') else Preview:=StandaloneTeX(Response.Get('body',''));
    Result:=True;
  finally Info.Free; Response.Free; Values.Free; end;
end;
end.
