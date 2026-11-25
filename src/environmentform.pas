unit EnvironmentForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, TeXOptionsEditor, EnvironmentOptions;
type
  TEnvironmentForm=class(TForm)
  private
    FSource:string;
    FHeader:TEnvironmentHeader;
    FUpdating:Boolean;
    FAllOptions:TTabSheet;
    FFields:array of record Key:string; Input:TComboBox; end;
    procedure PropertyChanged(Sender:TObject);
    procedure OptionsChanged(Sender:TObject);
    procedure Accept(Sender:TObject);
  public
    Pages:TPageControl;
    Options:TTeXOptionsEditor;
    Alignment:TComboBox;
    Columns:TEdit;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(const Source:string);
    procedure SelectProperty(const Key:string);
    function Source:string;
  end;
implementation
uses UnicodeEdits, Math, UITheme;
constructor TEnvironmentForm.Create(AOwner:TComponent);
var Footer:TPanel; B:TButton; Tab:TTabSheet;
begin
  inherited CreateNew(AOwner); Caption:='Environment options'; Position:=poOwnerFormCenter;
  SetBounds(0,0,760,560); Constraints.MinWidth:=600; Constraints.MinHeight:=400;
  Footer:=TPanel.Create(Self); Footer.Parent:=Self; Footer.Align:=alBottom; Footer.Height:=52; Footer.BevelOuter:=bvNone;
  B:=TButton.Create(Self); B.Parent:=Footer; B.Caption:='Apply'; B.SetBounds(536,10,96,32);
  B.Anchors:=[akTop,akRight]; B.Default:=True; B.OnClick:=@Accept;
  B:=TButton.Create(Self); B.Parent:=Footer; B.Caption:='Cancel'; B.SetBounds(640,10,96,32);
  B.Anchors:=[akTop,akRight]; B.Cancel:=True; B.ModalResult:=mrCancel;
  Pages:=TPageControl.Create(Self); Pages.Parent:=Self; Pages.Align:=alClient;
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=Pages; Tab.Caption:='All options';
  FAllOptions:=Tab;
  Options:=TTeXOptionsEditor.Create(Self); Options.Parent:=Tab; Options.Align:=alClient;
  Options.BorderSpacing.Around:=16; Options.OnChange:=@OptionsChanged;
end;
destructor TEnvironmentForm.Destroy;
begin
  FUpdating:=True; Options.OnChange:=nil; CancelTabUpdates(Pages);
  inherited Destroy;
end;
procedure TEnvironmentForm.Load(const Source:string);
var Names,Groups:TStringList; I,Y,J:Integer; L:TLabel; Input:TComboBox; BodyPanel:TScrollBox; Tab:TTabSheet; GroupName:string;
  procedure Group(const Title:string);
  begin
    J:=Groups.IndexOf(Title);
    if J<0 then begin
      Tab:=TTabSheet.Create(Self); Tab.PageControl:=Pages; Tab.Caption:=Title; Tab.PageIndex:=Pages.PageCount-2;
      BodyPanel:=TScrollBox.Create(Self); BodyPanel.Parent:=Tab; BodyPanel.Align:=alClient; BodyPanel.BorderStyle:=bsNone;
      Groups.AddObject(Title,BodyPanel);
    end else BodyPanel:=TScrollBox(Groups.Objects[J]);
    Y:=16+(BodyPanel.ControlCount div 2)*42;
  end;
  procedure LabelAt(const Text:string; Top:Integer);
  begin
    L:=TLabel.Create(Self); L.Parent:=BodyPanel; L.Caption:=Text; L.SetBounds(16,Top+5,160,24);
  end;
begin
  FSource:=Source; if not ReadEnvironmentHeader(Source,FHeader) then Exit;
  FUpdating:=True; Names:=TStringList.Create; Groups:=TStringList.Create;
  try
    Caption:=FHeader.Name+' options'; EnvironmentOptionNames(FHeader.Name,Names);
    for I:=Pages.PageCount-1 downto 0 do if Pages.Pages[I]<>FAllOptions then Pages.Pages[I].Free;
    Alignment:=nil; Columns:=nil;
    SetLength(FFields,Names.Count); Y:=16;
    if ColumnEnvironment(FHeader.Name) then begin
      SetPageVisible(FAllOptions,False); Group('Layout');
      LabelAt('Alignment',Y); Alignment:=TComboBox.Create(Self); Alignment.Parent:=BodyPanel;
      Alignment.SetBounds(184,Y,420,30); Alignment.Style:=csDropDownList;
      if FHeader.Name='longtable' then Alignment.Items.CommaText:='Default,l,c,r' else Alignment.Items.CommaText:='Default,t,c,b';
      Alignment.ItemIndex:=Max(0,Alignment.Items.IndexOf(FHeader.Options)); Inc(Y,46);
      LabelAt('Column format',Y); Columns:=TUnicodeEdit.Create(Self); Columns.Parent:=BodyPanel;
      Columns.SetBounds(184,Y,420,30); Columns.Text:=FHeader.Columns; Inc(Y,48);
      LabelAt('Example: |l|c|r| or p{3cm}ll',Y);
      L.AutoSize:=True; Columns.Anchors:=[akLeft,akRight,akTop]; Alignment.Anchors:=Columns.Anchors;
    end else begin
      SetPageVisible(FAllOptions,True);
      for I:=0 to Names.Count-1 do begin
        GroupName:=EnvironmentOptionGroup(FHeader.Name,Names[I]); Group(GroupName);
        LabelAt(Names[I],Y); Input:=TComboBox.Create(Self); Input.Parent:=BodyPanel;
        Input.SetBounds(184,Y,420,30); Input.Anchors:=[akLeft,akRight,akTop]; Input.Style:=csDropDown; Input.Tag:=I;
        FFields[I].Key:=Names[I]; FFields[I].Input:=Input;
        if Pos('col',Names[I])=1 then Input.Items.CommaText:='black,white,red,blue,green,orange,purple,gray,blue!5,blue!60!black';
        if Names[I]='language' then Input.Items.CommaText:='Pascal,[Standard]Pascal,[Borland6]Pascal,Delphi,Python,C,C++,Java,[LaTeX]TeX,Bash,Matlab';
        if Names[I]='numbers' then Input.Items.CommaText:='none,left,right';
        if Names[I]='frame' then Input.Items.CommaText:='none,single,lines,topline,bottomline';
        if Names[I]='columns' then Input.Items.CommaText:='fixed,flexible,fullflexible';
        if Names[I]='breaklines' then Input.Items.CommaText:='false,true';
        if Names[I]='basicstyle' then Input.Items.CommaText:='\ttfamily,\small\ttfamily,\footnotesize\ttfamily,\rmfamily';
        Input.Text:=EnvironmentOption(FHeader.Options,Names[I]); Input.OnChange:=@PropertyChanged;
        Input.Hint:='Leave empty to inherit the package or preamble setting.'; Input.ShowHint:=True;
        Inc(Y,42);
      end;
      Options.Text:=FHeader.Options;
      if Names.Count=0 then Pages.ActivePage:=FAllOptions else Pages.ActivePageIndex:=0;
    end;
  finally Groups.Free; Names.Free; FUpdating:=False; end;
  ApplyTheme(Self);
end;
procedure TEnvironmentForm.PropertyChanged(Sender:TObject);
var I:Integer; Value:string;
begin
  if FUpdating then Exit; I:=TComboBox(Sender).Tag; Value:=TComboBox(Sender).Text;
  if (Value<>'') and ((Pos(',',Value)>0) or (Pos('[',Value)>0) or (Pos(']',Value)>0) or
    (FFields[I].Key='title') or (FFields[I].Key='caption')) then Value:='{'+Value+'}';
  Options.Text:=SetEnvironmentOption(Options.Text,FFields[I].Key,Value);
end;
procedure TEnvironmentForm.SelectProperty(const Key:string);
var I:Integer;
begin
  for I:=0 to High(FFields) do if FFields[I].Key=Key then begin
    Pages.ActivePage:=TTabSheet(FFields[I].Input.Parent.Parent); ActiveControl:=FFields[I].Input; Exit;
  end;
end;
procedure TEnvironmentForm.OptionsChanged(Sender:TObject);
var I:Integer;
begin
  if FUpdating then Exit; FUpdating:=True;
  try for I:=0 to High(FFields) do FFields[I].Input.Text:=EnvironmentOption(Options.Text,FFields[I].Key);
  finally FUpdating:=False; end;
end;
procedure TEnvironmentForm.Accept(Sender:TObject);
begin
  if (Columns<>nil) and (Trim(Columns.Text)='') then begin Columns.SetFocus; Exit; end;
  ModalResult:=mrOK;
end;
function TEnvironmentForm.Source:string;
var Value:string;
begin
  Value:=Options.Text;
  if Alignment<>nil then begin Value:=''; if Alignment.ItemIndex>0 then Value:=Alignment.Text; end;
  Result:=SetEnvironmentOptions(FSource,Value);
  if Columns<>nil then Result:=SetEnvironmentColumns(Result,Columns.Text);
end;
end.
