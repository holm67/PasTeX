unit PluginRunner;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Forms, FPJSON, AddonModel;
function RunPluginAction(Owner:TComponent; Addon:TEditorAddon; const Action:string; Values:TJSONObject; OpenViews:Boolean=True):TJSONObject;
implementation
uses SysUtils, Dialogs, Controls, Process, Base64, Math, ToolJobs, ImportForms, PluginForm, PluginDialog;
function RunPluginAction(Owner:TComponent; Addon:TEditorAddon; const Action:string; Values:TJSONObject; OpenViews:Boolean):TJSONObject;
var Plan,JobData,Prompt:TJSONObject; Args,Substitutions,Lines,Scripts:TStringList;
    Job:TToolJob; Command,Text,Temp,Path,Extension,Next:string; I,Step:Integer; ID:TGUID; D:TOpenDialog; P:TProcess; View:TPluginForm; Configuration:TPluginDialog;
begin
  Result:=nil; Plan:=nil; Temp:=''; Command:=Action; Args:=TStringList.Create; Substitutions:=TStringList.Create; Lines:=TStringList.Create; Scripts:=TStringList.Create;
  try
    for Step:=0 to 15 do begin
      FreeAndNil(Plan); Plan:=Addon.Request(Command,Values);
      if Plan.Get('error','')<>'' then raise Exception.Create(Plan.Get('error',''));
      if Plan.Find('dialog') is TJSONObject then begin
        if not OpenViews then begin Result:=Plan; Plan:=nil; Exit; end;
        Configuration:=TPluginDialog.Create(Owner);
        try
          Configuration.Load(Plan.Objects['dialog'],Values); if Configuration.ShowModal<>mrOK then Exit;
          Configuration.Store(Values); Command:=Plan.Objects['dialog'].Get('action',Command);
        finally Configuration.Free; end;
        Continue;
      end;
      if Plan.Find('prompt') is TJSONObject then begin
        Prompt:=Plan.Objects['prompt']; Text:='';
        if not InputQuery(Prompt.Get('title',Addon.Name),Prompt.Get('message','Value'),Text) then Exit;
        Values.Strings[Prompt.Get('key','value')]:=Text; Continue;
      end;
      if Plan.Get('confirm','')<>'' then begin
        if MessageDlg(Plan.Get('confirm',''),mtConfirmation,[mbYes,mbNo],0)<>mrYes then Exit;
        Values.Booleans['confirmed']:=True; Continue;
      end;
      if Plan.Get('file','')<>'' then begin
        D:=TOpenDialog.Create(Owner);
        try D.Filter:=Plan.Get('file',''); D.InitialDir:=Values.Get('directory',''); if not D.Execute then Exit; Values.Strings['file']:=D.FileName;
        finally D.Free; end; Continue;
      end;
      if Plan.Find('view') is TJSONObject then begin
        if not OpenViews then begin Result:=Plan; Plan:=nil; Exit; end;
        View:=TPluginForm.Create(Owner);
        try View.Load(Addon,Plan.Objects['view'],Values); View.ShowModal; finally View.Free; end;
        Exit(TJSONObject.Create(['handled',True]));
      end;
      if not (Plan.Find('process') is TJSONObject) then begin Result:=Plan; Plan:=nil; Exit; end;
      JobData:=Plan.Objects['process']; Substitutions.Clear;
      for I:=0 to Values.Count-1 do if Values.Items[I].JSONType in [jtString,jtNumber,jtBoolean] then Substitutions.Values[Values.Names[I]]:=Values.Items[I].AsString;
      if Plan.Find('script') is TJSONObject then begin
        if Temp='' then begin CreateGUID(ID); Temp:=IncludeTrailingPathDelimiter(GetTempDir(False))+'pastex-plugin-'+GUIDToString(ID); ForceDirectories(Temp); end;
        Extension:=Plan.Objects['script'].Get('extension','.txt');
        if (Pos('/',Extension)>0) or (Pos('\',Extension)>0) then raise Exception.Create('Invalid script extension');
        Path:=IncludeTrailingPathDelimiter(Temp)+'script'+Extension; Lines.Text:=Plan.Objects['script'].Get('text',''); Lines.SaveToFile(Path); Substitutions.Values['script']:=Path;
        if Scripts.IndexOf(Path)<0 then Scripts.Add(Path);
      end;
      Args.Clear;
      if JobData.Find('arguments') is TJSONArray then for I:=0 to JobData.Arrays['arguments'].Count-1 do begin
        Text:=JobData.Arrays['arguments'].Strings[I];
        if JobData.Get('expandArguments',True) then Text:=ExpandToolText(Text,Substitutions);
        Args.Add(Text);
      end;
      Text:=JobData.Get('executable',Addon.Executable); Path:=JobData.Get('directory',Values.Get('directory',''));
      if JobData.Get('detached',False) and (Temp='') then begin
        P:=TProcess.Create(nil);
        try P.Executable:=FindTool(Text); if P.Executable='' then raise Exception.Create('Executable not found: '+Text);
          P.CurrentDirectory:=Path; P.Parameters.Assign(Args); P.Options:=[poNoConsole]; P.Execute;
        finally P.Free; end;
        Exit(TJSONObject.Create(['handled',True]));
      end;
      Job:=TToolJob.Create;
      try
        Job.TimeoutMS:=EnsureRange(JobData.Get('timeoutMS',120000),1000,600000);
        Job.Add(Text,Path,[]); TToolStep(Job.Steps[0]).Arguments.Assign(Args);
        if JobData.Find('environment') is TJSONObject then
          for I:=0 to JobData.Objects['environment'].Count-1 do
            TToolStep(Job.Steps[0]).Environment.Values[JobData.Objects['environment'].Names[I]]:=JobData.Objects['environment'].Items[I].AsString;
        if not RunToolJob(Owner,Job,Addon.Name) then begin
          if ToolJobCancelled then Exit;
          if Plan.Get('allowFailure',False) then Exit(TJSONObject.Create(['rows',TJSONArray.Create]));
          raise Exception.Create(Job.ErrorText+LineEnding+Job.Output);
        end;
        Values.Strings['outputEncoding']:=JobData.Get('outputEncoding','text');
        if Values.Get('outputEncoding','')='base64' then Values.Strings['output']:=EncodeStringBase64(Job.Output)
        else Values.Strings['output']:=Job.Output;
      finally Job.Free; end;
      Next:=Plan.Get('continuation',''); if Next='' then Exit(TJSONObject.Create(['output',Values.Get('output','')])); Command:=Next;
    end;
    raise Exception.Create('The plug-in exceeded the action step limit');
  finally
    if Temp<>'' then begin
      for Text in Scripts do DeleteFile(Text);
      RemoveDir(Temp);
    end;
    Plan.Free; Scripts.Free; Lines.Free; Substitutions.Free; Args.Free;
  end;
end;
end.
