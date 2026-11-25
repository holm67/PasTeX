unit PreambleForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, Graphics, StdCtrls, ComCtrls, ExtCtrls, Math, Contnrs, PreambleModel, TeXOptionsEditor,
  SynEdit, SynEditTypes, SynEditWrappedView, SynHighlighterTeX, DocumentFontsEditor;
type
  TPreambleForm=class(TForm)
  private
    FModel:TPreambleModel;
    FUpdating:Boolean;
    FIndex:Integer;
    FDirectory,FDocumentStart:string;
    FOriginalInfo:array[0..2] of string;
    FInfoGroups:array[0..2] of TGroupBox;
    Pages:TPageControl;
    RawTab:TTabSheet;
    FWrappedSource,FPlainSource:TSynEdit;
    FWrap:TLazSynEditLineWrapPlugin;
    FHighlighter:TSynTeXSyn;
    procedure PackageSelected(Sender:TObject);
    procedure PackageSelectionChanged(Sender:TObject; User:Boolean);
    procedure PackageChanged(Sender:TObject);
    procedure PackageAction(Sender:TObject);
    procedure PackageSetup(Sender:TObject);
    procedure PackageSource(Sender:TObject);
    procedure InfoChanged(Sender:TObject);
    procedure ClassChanged(Sender:TObject);
    function InfoCode(Index:Integer):string;
    procedure PageChanging(Sender:TObject; var AllowChange:Boolean);
    procedure RefreshPackages(Index:Integer);
  public
    DocumentClass:TComboBox;
    PackageName:TEdit;
    ClassOptions,PackageOptions:TTeXOptionsEditor;
    PackageList:TListBox;
    PackageSetupButton,PackageSourceButton:TButton;
    PackageSourcesChanged:Boolean;
    DocumentTitle,DocumentAuthor,DocumentDate:TEdit;
    ShortTitle,ShortAuthor:TEdit;
    SetTitle,SetAuthor,SetDate,UseShortTitle,UseShortAuthor:TCheckBox;
    RawSource:TSynEdit;
    FontsEditor:TDocumentFontsEditor;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Load(const Preamble:string; const Directory:string='');
    procedure ConfigureSource(const FontName:string; FontSize:Integer; Wrap:Boolean);
    function Source:string;
  end;
implementation
uses UnicodeEdits, UITheme, SourceFonts, SourceStyle, SourceCompletion, TeXPreambleCommands, PackageSetupForm, PackageSourceForm, TeXPackageSources, TeXMacros, TeXFontConfig, Dialogs;
function PackageCaption(const Name:string):string;
begin if Name='' then Result:='(empty package)' else Result:=Name; end;
constructor TPreambleForm.Create(AOwner:TComponent);
var Tab:TTabSheet; L:TLabel; B:TButton; I:Integer; Bar:TPanel;
  function SourceEditor:TSynEdit;
  begin
    Result:=TSynEdit.Create(Self); Result.Parent:=RawTab; Result.Align:=alClient;
    Result.SetDefaultKeystrokes; Result.ResetMouseActions; UseNativeSourceFonts(Result);
    Result.Options:=Result.Options-[eoScrollPastEol];
    Result.Options2:=Result.Options2-[eoScrollPastEolAddPage,eoScrollPastEolAutoCaret];
    Result.Highlighter:=FHighlighter;
  end;
  procedure LabelAt(const Text:string; X,Y:Integer);
  begin L:=TLabel.Create(Self); L.Parent:=Tab; L.Caption:=Text; L.SetBounds(X,Y,210,20); end;
  procedure Information(const Title:string; Index,Y:Integer; out Value:TEdit; out EnabledBox:TCheckBox);
  var Group:TGroupBox; Edit:TEdit; ShortBox:TCheckBox;
  begin
    Group:=TGroupBox.Create(Self); Group.Parent:=Tab; Group.Caption:=Title; Group.SetBounds(16,Y,872,122);
    Group.Anchors:=[akLeft,akTop,akRight]; FInfoGroups[Index]:=Group;
    EnabledBox:=TCheckBox.Create(Self); EnabledBox.Parent:=Group; EnabledBox.Caption:='Set '+LowerCase(Title); EnabledBox.SetBounds(12,12,120,26);
    Value:=TUnicodeEdit.Create(Self); Value.Parent:=Group; Value.Tag:=Index; Value.SetBounds(144,12,708,30);
    Value.Anchors:=[akLeft,akTop,akRight]; Value.BorderStyle:=bsSingle; Value.OnChange:=@InfoChanged;
    Value.Hint:='Text and LaTeX commands are accepted'; Value.ShowHint:=True;
    if Index<2 then begin
      ShortBox:=TCheckBox.Create(Self); ShortBox.Parent:=Group; ShortBox.Caption:='Short '+LowerCase(Title); ShortBox.SetBounds(144,82,128,24);
      Edit:=TUnicodeEdit.Create(Self); Edit.Parent:=Group; Edit.Tag:=Index+3; Edit.SetBounds(282,80,570,30); Edit.OnChange:=@InfoChanged;
      Edit.Anchors:=[akLeft,akTop,akRight];
      if Index=0 then begin ShortTitle:=Edit; UseShortTitle:=ShortBox; end
      else begin ShortAuthor:=Edit; UseShortAuthor:=ShortBox; end;
    end else begin
      L:=TLabel.Create(Self); L.Parent:=Group; L.Caption:='Unset uses the document default; a blank custom date hides it.';
      L.AutoSize:=False; L.WordWrap:=True; L.SetBounds(144,52,700,36); L.Anchors:=[akLeft,akTop,akRight];
    end;
  end;
begin
  inherited CreateNew(AOwner); FModel:=TPreambleModel.Create; FIndex:=-1;
  Caption:='Preamble and document settings'; Position:=poMainFormCenter; BorderStyle:=bsDialog;
  ClientWidth:=920; ClientHeight:=510; Constraints.MinWidth:=920; Constraints.MinHeight:=510;
  Bar:=TPanel.Create(Self); Bar.Parent:=Self; Bar.Align:=alBottom; Bar.Height:=48; Bar.BevelOuter:=bvNone;
  B:=TButton.Create(Self); B.Parent:=Bar; B.Caption:='Apply'; B.SetBounds(710,8,90,32); B.ModalResult:=mrOK; B.Default:=True;
  B:=TButton.Create(Self); B.Parent:=Bar; B.Caption:='Cancel'; B.SetBounds(810,8,90,32); B.ModalResult:=mrCancel; B.Cancel:=True;
  Pages:=TEditorPageControl.Create(Self); Pages.Parent:=Self; Pages.Align:=alClient;
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=Pages; Tab.Caption:='Document class';
  LabelAt('Document class',16,16);
  DocumentClass:=TComboBox.Create(Self); DocumentClass.Parent:=Tab; DocumentClass.SetBounds(16,40,260,30);
  DocumentClass.Items.CommaText:='article,report,book,letter,beamer,scrartcl,scrreprt,scrbook,ctexart,ctexrep,ctexbook,standalone,subfiles';
  LabelAt('Class options',16,92);
  ClassOptions:=TTeXOptionsEditor.Create(Self); ClassOptions.Parent:=Tab; ClassOptions.SetBounds(16,120,872,278);
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=Pages; Tab.Caption:='Packages';
  LabelAt('Packages (loaded in this order)',16,16);
  PackageList:=TListBox.Create(Self); PackageList.Parent:=Tab; PackageList.SetBounds(16,44,220,354); PackageList.OnClick:=@PackageSelected;
  {$IFDEF LCLgtk3}PackageList.Style:=lbOwnerDrawFixed; PackageList.ItemHeight:=24;{$ENDIF}
  PackageList.OnSelectionChange:=@PackageSelectionChanged;
  for I:=0 to 3 do begin
    B:=TButton.Create(Self); B.Parent:=Tab; B.Tag:=I; B.SetBounds(246,44+I*42,90,32);
    case I of 0:B.Caption:='Add'; 1:B.Caption:='Delete'; 2:B.Caption:='Move up'; 3:B.Caption:='Move down'; end;
    B.OnClick:=@PackageAction;
  end;
  LabelAt('Package name',352,16); LabelAt('Package options',352,92);
  PackageName:=TUnicodeEdit.Create(Self); PackageName.Parent:=Tab; PackageName.SetBounds(352,44,536,30); PackageName.OnChange:=@PackageChanged;
  PackageOptions:=TTeXOptionsEditor.Create(Self); PackageOptions.Parent:=Tab; PackageOptions.SetBounds(352,120,536,278); PackageOptions.OnChange:=@PackageChanged;
  PackageSetupButton:=TButton.Create(Self); PackageSetupButton.Parent:=Tab; PackageSetupButton.Caption:='Package setup…';
  PackageSetupButton.SetBounds(742,6,146,32); PackageSetupButton.OnClick:=@PackageSetup;
  PackageSourceButton:=TButton.Create(Self); PackageSourceButton.Parent:=Tab; PackageSourceButton.Caption:='Edit source (.sty)…';
  PackageSourceButton.SetBounds(570,6,164,32); PackageSourceButton.OnClick:=@PackageSource;
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=Pages; Tab.Caption:='Document information';
  Information('Title',0,8,DocumentTitle,SetTitle); Information('Author',1,140,DocumentAuthor,SetAuthor);
  Information('Date',2,272,DocumentDate,SetDate);
  Tab:=TTabSheet.Create(Self); Tab.PageControl:=Pages; Tab.Caption:='Fonts';
  L:=TLabel.Create(Self); L.Parent:=Tab; L.Align:=alBottom; L.AutoSize:=False; L.Height:=28;
  L.Caption:='CJK font commands require XeLaTeX; Latin fontspec fonts also work with LuaLaTeX.';
  FontsEditor:=TDocumentFontsEditor.Create(Self); FontsEditor.Parent:=Tab; FontsEditor.Align:=alClient;
  RawTab:=TTabSheet.Create(Self); RawTab.PageControl:=Pages; RawTab.Caption:='Complete preamble';
  FHighlighter:=TSynTeXSyn.Create(Self);
  FWrappedSource:=SourceEditor; FPlainSource:=SourceEditor; FPlainSource.Visible:=False;
  FWrap:=TLazSynEditLineWrapPlugin.Create(FWrappedSource); RawSource:=FWrappedSource;
  ConfigureSource(DefaultSourceFont,12,True);
  Pages.OnChanging:=@PageChanging;
  DocumentClass.OnChange:=@ClassChanged; ClassChanged(nil);
  ApplyTheme(Self);
end;
destructor TPreambleForm.Destroy;
begin
  FUpdating:=True;
  if Pages<>nil then begin Pages.OnChanging:=nil; CancelTabUpdates(Pages); end;
  try inherited Destroy; finally FModel.Free; end;
end;
procedure TPreambleForm.ConfigureSource(const FontName:string; FontSize:Integer; Wrap:Boolean);
var NewView,Editor:TSynEdit;
begin
  NewView:=FPlainSource; if Wrap then NewView:=FWrappedSource;
  { Removing a live SynEdit wrap view corrupts its display-line callbacks.
    Keep both views attached and transfer their editing state when switching. }
  if NewView<>RawSource then begin
    NewView.Text:=RawSource.Text; NewView.LogicalCaretXY:=RawSource.LogicalCaretXY;
    NewView.BlockBegin:=RawSource.BlockBegin; NewView.BlockEnd:=RawSource.BlockEnd;
    RawSource.Visible:=False; RawSource:=NewView;
  end;
  RawSource.Visible:=True;
  for Editor in [FWrappedSource,FPlainSource] do begin
    Editor.Font.Name:=SourceFontForText(FontName,RawSource.Text); Editor.Font.Size:=FontSize;
    ApplySourceStyle(Editor);
    SetSourceCompletionContext(Editor,'',FDirectory,'pdflatex');
  end;
end;
procedure TPreambleForm.Load(const Preamble:string; const Directory:string);
const Commands:array[0..2] of string=('title','author','date');
var Items:TObjectList; Item:TPreambleCommand; I,P,A,Q:Integer; Value:TEdit; EnabledBox:TCheckBox; Header,Command:string;
begin
  FDocumentStart:=''; Header:=Preamble; P:=1;
  while P<=Length(Header) do begin
    if Header[P]='%' then begin while (P<=Length(Header)) and (Header[P]<>#10) do Inc(P); Continue; end;
    if Header[P]<>'\' then begin Inc(P); Continue; end;
    Q:=P; if ReadTeXDefinition(Header,Q) then begin P:=Q; Continue; end;
    A:=P; Command:=ReadTeXCommand(Header,P);
    if (Command='begin') and (ReadTeXGroup(Header,P,'{','}')='document') then begin
      FDocumentStart:=Copy(Header,A,MaxInt); Header:=Copy(Header,1,A-1); Break;
    end;
  end;
  FDirectory:=Directory;
  SetSourceCompletionContext(FWrappedSource,'',Directory,'pdflatex');
  SetSourceCompletionContext(FPlainSource,'',Directory,'pdflatex');
  Items:=TObjectList.Create(True); FUpdating:=True;
  try
    FModel.Load(Header); DocumentClass.Text:=FModel.DocumentClassName; ClassOptions.Text:=FModel.ClassOptions;
    for I:=0 to 2 do begin
      case I of 0:begin Value:=DocumentTitle; EnabledBox:=SetTitle; end;
        1:begin Value:=DocumentAuthor; EnabledBox:=SetAuthor; end;
        else begin Value:=DocumentDate; EnabledBox:=SetDate; end;
      end;
      PreambleCommands(Header,Commands[I],Items); EnabledBox.Checked:=Items.Count>0; Item:=nil;
      if Items.Count>0 then Item:=TPreambleCommand(Items[Items.Count-1]);
      if Item=nil then Value.Text:='' else Value.Text:=Item.Argument;
      if I<2 then begin
        if I=0 then begin UseShortTitle.Checked:=(Item<>nil) and Item.HasOptions; ShortTitle.Text:=''; if Item<>nil then ShortTitle.Text:=Item.Options; end
        else begin UseShortAuthor.Checked:=(Item<>nil) and Item.HasOptions; ShortAuthor.Text:=''; if Item<>nil then ShortAuthor.Text:=Item.Options; end;
      end;
      FOriginalInfo[I]:=InfoCode(I);
    end;
    RawSource.Text:=Header;
    FontsEditor.Load(Header);
  finally FUpdating:=False; Items.Free; end;
  ClassChanged(nil); RefreshPackages(0);
end;
procedure TPreambleForm.RefreshPackages(Index:Integer);
var I:Integer; Package:TPackageOption;
begin
  FUpdating:=True; PackageList.Items.BeginUpdate;
  try
    PackageList.Items.Clear;
    for I:=0 to FModel.Packages.Count-1 do begin Package:=TPackageOption(FModel.Packages[I]); PackageList.Items.Add(PackageCaption(Package.Name)); end;
    PackageList.ItemIndex:=Min(Index,PackageList.Items.Count-1);
  finally PackageList.Items.EndUpdate; FUpdating:=False; end;
  PackageSelected(nil);
end;
procedure TPreambleForm.PackageSelectionChanged(Sender:TObject; User:Boolean);
begin if not FUpdating then PackageSelected(Sender); end;
procedure TPreambleForm.PackageSelected(Sender:TObject);
var Package:TPackageOption;
begin
  FIndex:=PackageList.ItemIndex; if FIndex>=FModel.Packages.Count then FIndex:=-1; FUpdating:=True;
  try
    PackageName.Enabled:=FIndex>=0; PackageOptions.Enabled:=FIndex>=0;
    PackageSetupButton.Enabled:=False;
    PackageSourceButton.Enabled:=False;
    if FIndex<0 then begin PackageName.Text:=''; PackageOptions.Text:=''; end
    else begin Package:=TPackageOption(FModel.Packages[FIndex]); PackageName.Text:=Package.Name; PackageOptions.Text:=Package.Options;
      PackageSetupButton.Enabled:=PackageSetupCommand(Package.Name)<>'';
      PackageSourceButton.Enabled:=Trim(Package.Name)<>'';
    end;
  finally FUpdating:=False; end;
end;
procedure TPreambleForm.PackageChanged(Sender:TObject);
var Package:TPackageOption;
begin
  if FUpdating or (FIndex<0) or (FIndex>=FModel.Packages.Count) then Exit; Package:=TPackageOption(FModel.Packages[FIndex]);
  FUpdating:=True;
  try
    Package.Name:=Trim(PackageName.Text); Package.Options:=PackageOptions.Text;
    PackageList.Items[FIndex]:=PackageCaption(Package.Name);
    PackageSetupButton.Enabled:=PackageSetupCommand(Package.Name)<>'';
    PackageSourceButton.Enabled:=Trim(Package.Name)<>'';
  finally FUpdating:=False; end;
end;
procedure TPreambleForm.PackageSetup(Sender:TObject);
var Dialog:TPackageSetupForm; Package:TPackageOption;
begin
  if FIndex<0 then Exit; Package:=TPackageOption(FModel.Packages[FIndex]);
  if PackageSetupCommand(Package.Name)='' then Exit;
  FModel.DocumentClassName:=Trim(DocumentClass.Text); FModel.ClassOptions:=ClassOptions.Text;
  Dialog:=TPackageSetupForm.Create(Self);
  try
    Dialog.Load(Package.Name,FModel.Source,FDirectory);
    if Dialog.ShowModal=mrOK then begin FModel.Load(Dialog.Source); RefreshPackages(FIndex); end;
  finally Dialog.Free; end;
end;
procedure TPreambleForm.PackageSource(Sender:TObject);
var Dialog:TPackageSourceForm; Path,PackageFile:string;
begin
  if (FIndex<0) or (FIndex>=FModel.Packages.Count) then Exit;
  PackageFile:=Trim(TPackageOption(FModel.Packages[FIndex]).Name); if PackageFile='' then Exit;
  if ExtractFileExt(PackageFile)='' then PackageFile:=PackageFile+'.sty'; Path:=ResolveTeXSource(PackageFile,FDirectory);
  if Path='' then begin MessageDlg('Package source not found','Could not locate '+PackageFile+' in the document folder or the TeX installation.',mtInformation,[mbOK],0); Exit; end;
  Dialog:=TPackageSourceForm.Create(Self);
  try
    try
      Dialog.Load(Path,RawSource.Font.Name,RawSource.Font.Size,RawSource=FWrappedSource); Dialog.ShowModal;
      PackageSourcesChanged:=PackageSourcesChanged or Dialog.Saved;
    except on E:Exception do MessageDlg('Could not open package source',E.Message,mtError,[mbOK],0); end;
  finally Dialog.Free; end;
end;
procedure TPreambleForm.InfoChanged(Sender:TObject);
begin
  if FUpdating then Exit;
  case TComponent(Sender).Tag of
    0:SetTitle.Checked:=True; 1:SetAuthor.Checked:=True; 2:SetDate.Checked:=True;
    3:begin SetTitle.Checked:=True; UseShortTitle.Checked:=True; end;
    4:begin SetAuthor.Checked:=True; UseShortAuthor.Checked:=True; end;
  end;
end;
procedure TPreambleForm.ClassChanged(Sender:TObject);
var SupportsShort:Boolean; Registry:TMacroRegistry; Info:TMacroInfo;
  function Optional(const Command:string):Boolean;
  begin
    Info:=Registry.Find(Command);
    Result:=SupportsShort or ((Info<>nil) and (Info.OptionalFirst or (Pos('\@dblarg',Info.Body)>0)));
  end;
begin
  SupportsShort:=Trim(DocumentClass.Text)='beamer';
  Registry:=TMacroRegistry.Create;
  try
    FModel.DocumentClassName:=Trim(DocumentClass.Text); Registry.Load(FModel.Source,FDirectory);
    UseShortTitle.Visible:=Optional('title'); ShortTitle.Visible:=UseShortTitle.Visible;
    UseShortAuthor.Visible:=Optional('author'); ShortAuthor.Visible:=UseShortAuthor.Visible;
  finally Registry.Free; end;
  UseShortTitle.Enabled:=True; ShortTitle.Enabled:=True; UseShortAuthor.Enabled:=True; ShortAuthor.Enabled:=True;
  if Sender=DocumentClass then begin
    if not UseShortTitle.Visible then UseShortTitle.Checked:=False;
    if not UseShortAuthor.Visible then UseShortAuthor.Checked:=False;
  end;
  if UseShortTitle.Visible then FInfoGroups[0].Height:=128 else FInfoGroups[0].Height:=110;
  if UseShortAuthor.Visible then FInfoGroups[1].Height:=128 else FInfoGroups[1].Height:=110;
  FInfoGroups[1].Top:=FInfoGroups[0].Top+FInfoGroups[0].Height+8;
  FInfoGroups[2].Top:=FInfoGroups[1].Top+FInfoGroups[1].Height+8;
end;
function TPreambleForm.InfoCode(Index:Integer):string;
var Value:TEdit; EnabledBox:TCheckBox; Command,Short:string;
begin
  Result:=''; Short:='';
  case Index of
    0:begin Value:=DocumentTitle; EnabledBox:=SetTitle; Command:='title'; if UseShortTitle.Checked then Short:='['+ShortTitle.Text+']'; end;
    1:begin Value:=DocumentAuthor; EnabledBox:=SetAuthor; Command:='author'; if UseShortAuthor.Checked then Short:='['+ShortAuthor.Text+']'; end;
    else begin Value:=DocumentDate; EnabledBox:=SetDate; Command:='date'; end;
  end;
  if EnabledBox.Checked then Result:='\'+Command+Short+'{'+TrimRight(Value.Text)+'}';
end;
procedure TPreambleForm.PackageAction(Sender:TObject);
var I,J:Integer;
begin
  I:=FIndex;
  case TComponent(Sender).Tag of
    0:begin I:=FModel.Packages.Add(TPackageOption.Create('package','')); end;
    1:if I>=0 then FModel.Packages.Delete(I);
    2,3:begin J:=I+IfThen(TComponent(Sender).Tag=2,-1,1); if (I>=0) and (J>=0) and (J<FModel.Packages.Count) then begin FModel.Packages.Exchange(I,J); I:=J; end; end;
  end;
  RefreshPackages(I); if PackageName.CanFocus then PackageName.SetFocus;
end;
function TPreambleForm.Source:string;
const Commands:array[0..2] of string=('title','author','date');
var I:Integer; Code:string; Fonts:TDocumentFonts; FontSpec:TDocumentFont; CJK:Boolean;
begin
  if Pages.ActivePage=RawTab then Exit(RawSource.Text+FDocumentStart);
  FModel.DocumentClassName:=Trim(DocumentClass.Text); FModel.ClassOptions:=ClassOptions.Text;
  if FontsEditor.Changed then begin
    Fonts:=DocumentFonts(FontsEditor.Source); CJK:=False;
    for FontSpec in Fonts do if Pos('CJK',FontSpec.Command)>0 then CJK:=True;
    if CJK then begin
      if (Pos('ctex',FModel.DocumentClassName)<>1) and (FModel.PackageIndex('ctex')<0) and
        (FModel.PackageIndex('xeCJK')<0) then FModel.SetPackage('xeCJK','');
    end else if Length(Fonts)>0 then begin
      if FModel.PackageIndex('fontspec')<0 then FModel.SetPackage('fontspec','');
    end;
  end;
  Result:=FontsEditor.ApplyTo(FModel.Source);
  for I:=0 to 2 do begin
    Code:=InfoCode(I); if Code<>FOriginalInfo[I] then Result:=ReplacePreambleCommands(Result,Commands[I],Code);
  end;
  Result:=Result+FDocumentStart;
end;
procedure TPreambleForm.PageChanging(Sender:TObject; var AllowChange:Boolean);
var Boundary:string;
begin
  if Pages.ActivePage=RawTab then begin
    Boundary:=FDocumentStart; Load(RawSource.Text,FDirectory);
    if FDocumentStart='' then FDocumentStart:=Boundary;
  end else RawSource.Text:=Copy(Source,1,Length(Source)-Length(FDocumentStart));
end;
end.
