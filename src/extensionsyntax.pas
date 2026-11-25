unit ExtensionSyntax;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes;
function ExtensionSyntaxRevision:QWord;
function ExtensionCodeLanguage(const Environment:string):string;
function ExtensionPackage(const Name:string):Boolean;
procedure ExtensionCommands(const PackageName:string; Dest:TStrings);
implementation
uses SysUtils, FPJSON, AddonModel;
var Lock:TRTLCriticalSection; Revision:QWord=High(QWord);
    Environments,Packages:TStringList;
procedure Refresh;
var Catalog:TEditorAddons; A:TEditorAddon; Syntax,Group,Command:TJSONObject;
    I,J,K:Integer; Name,Adapter:string; Commands:TJSONArray;
begin
  if Revision=ExtensionRevision then Exit;
  Environments.Clear; Packages.Clear; Catalog:=TEditorAddons.Create(True);
  try
    Catalog.Load;
    for I:=0 to Catalog.Count-1 do begin
      A:=TEditorAddon(Catalog[I]);
      if not A.Enabled or not A.Installed or not (A.Manifest.Find('tex') is TJSONObject) then Continue;
      Syntax:=A.Manifest.Objects['tex'];
      if Syntax.Find('environments') is TJSONObject then begin
        Group:=Syntax.Objects['environments'];
        for J:=0 to Group.Count-1 do if Group.Items[J].JSONType=jtString then
          Environments.Values[Group.Names[J]]:=Group.Items[J].AsString;
      end;
      if not (Syntax.Find('packages') is TJSONObject) then Continue;
      Group:=Syntax.Objects['packages'];
      for J:=0 to Group.Count-1 do begin
        if not (Group.Items[J] is TJSONArray) then Continue;
        Name:=ChangeFileExt(ExtractFileName(Group.Names[J]),''); Commands:=TJSONArray(Group.Items[J]);
        Packages.Add(Name+#9);
        for K:=0 to Commands.Count-1 do if Commands.Items[K] is TJSONObject then begin
          Command:=Commands.Objects[K]; Adapter:=''; if Command.Get('literal',False) then Adapter:='literal';
          Packages.Add(Name+#9+Command.Get('name','')+#9+Command.Get('signature','')+#9+Command.Get('body','')+#9+Adapter);
        end;
      end;
    end;
    Revision:=ExtensionRevision;
  finally Catalog.Free; end;
end;
function ExtensionSyntaxRevision:QWord;
begin Result:=ExtensionRevision; end;
function ExtensionCodeLanguage(const Environment:string):string;
begin
  EnterCriticalSection(Lock);
  try Refresh; Result:=Environments.Values[Environment]; finally LeaveCriticalSection(Lock); end;
end;
function ExtensionPackage(const Name:string):Boolean;
begin
  EnterCriticalSection(Lock);
  try Refresh; Result:=Packages.IndexOf(ChangeFileExt(ExtractFileName(Name),'')+#9)>=0;
  finally LeaveCriticalSection(Lock); end;
end;
procedure ExtensionCommands(const PackageName:string; Dest:TStrings);
var I:Integer; Prefix:string;
begin
  EnterCriticalSection(Lock);
  try
    Refresh; Prefix:=PackageName+#9;
    for I:=0 to Packages.Count-1 do if (Copy(Packages[I],1,Length(Prefix))=Prefix) and
      (Length(Packages[I])>Length(Prefix)) then Dest.Add(Copy(Packages[I],Length(Prefix)+1,MaxInt));
  finally LeaveCriticalSection(Lock); end;
end;
initialization
  InitCriticalSection(Lock); Environments:=TStringList.Create; Environments.CaseSensitive:=True;
  Packages:=TStringList.Create; Packages.CaseSensitive:=True;
finalization
  Packages.Free; Environments.Free; DoneCriticalSection(Lock);
end.
