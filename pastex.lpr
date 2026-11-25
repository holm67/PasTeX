program PasTeX;
{ SPDX-License-Identifier: GPL-3.0-or-later }

{$mode objfpc}{$H+}

uses
  {$IFDEF LINUX}cmem,{$ENDIF}
  {$IFDEF UNIX}cthreads,{$ENDIF}
  Interfaces, Forms, MainForm;

{$R *.res}

begin
  RequireDerivedFormResource := True;
  Application.Scaled:=True;
  Application.Title:='PasTeX';
  Application.Initialize;
  Application.CreateForm(TMainForm, MainWindow);
  Application.Run;
end.
