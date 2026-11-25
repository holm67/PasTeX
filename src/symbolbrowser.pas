unit SymbolBrowser;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}{$codepage utf8}
interface
uses Classes, Forms, Controls, StdCtrls, ExtCtrls, TeXMacros, DraftLayout;
type
  TSymbolBrowser=class(TForm)
  private
    FAll,FCommon,FPackageMap:TStringList;
    FPreviewPackage:string;
    FRegistry:TMacroRegistry;
    FDraft:TParagraphDraft;
    FPreview:TPaintBox;
    FStatus:TLabel;
    FInsert:TButton;
    procedure Filter(Sender:TObject);
    procedure LoadPackage(Sender:TObject);
    procedure PaintSymbol(Sender:TObject);
    procedure SelectSymbol(Sender:TObject);
  public
    Search:TEdit;
    PackageList:TComboBox;
    Symbols:TListBox;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure LoadCommon(Commands:TStrings);
    function PackageName:string;
    function Command:string;
  end;
function ChooseInstalledSymbol(Owner:TComponent; Commands:TStrings; out Code,PackageName:string):Boolean;
implementation
uses SysUtils, Math, Graphics, Types, UITheme, SymbolCatalog, MathModel, TeXGlyphs, TeXFontData, NativeTeXGlyphs;
constructor TSymbolBrowser.Create(AOwner:TComponent);
var TopBar,BottomBar,PreviewPanel:TPanel; L:TLabel; Cancel:TButton;
begin
  inherited CreateNew(AOwner); Caption:='Math symbols'; Position:=poMainFormCenter;
  ClientWidth:=680; ClientHeight:=470; Constraints.MinWidth:=450; Constraints.MinHeight:=300;
  FAll:=TStringList.Create; FAll.CaseSensitive:=True; FAll.UseLocale:=False; FAll.Sorted:=True; FAll.Duplicates:=dupIgnore;
  FCommon:=TStringList.Create; FPackageMap:=TStringList.Create; FPackageMap.CaseSensitive:=True;
  FRegistry:=TMacroRegistry.Create; FDraft:=TParagraphDraft.Create;
  TopBar:=TPanel.Create(Self); TopBar.Parent:=Self; TopBar.Align:=alTop; TopBar.Height:=82; TopBar.BevelOuter:=bvNone;
  L:=TLabel.Create(Self); L.Parent:=TopBar; L.SetBounds(12,8,240,20); L.Caption:='Package / symbol list';
  PackageList:=TComboBox.Create(Self); PackageList.Parent:=TopBar; PackageList.SetBounds(12,32,250,30);
  PackageList.Style:=csDropDownList; InstalledSymbolPackages(PackageList.Items);
  PackageList.Items.Insert(0,'Common symbols'); PackageList.Items.Insert(1,'Comprehensive symbol list'); PackageList.ItemIndex:=0;
  L:=TLabel.Create(Self); L.Parent:=TopBar; L.SetBounds(276,8,200,20); L.Caption:='Search commands';
  Search:=TEdit.Create(Self); Search.Parent:=TopBar; Search.SetBounds(276,32,392,30); Search.Anchors:=[akLeft,akRight,akTop];
  Search.OnChange:=@Filter; PackageList.OnChange:=@LoadPackage;
  BottomBar:=TPanel.Create(Self); BottomBar.Parent:=Self; BottomBar.Align:=alBottom; BottomBar.Height:=48; BottomBar.BevelOuter:=bvNone;
  FInsert:=TButton.Create(Self); FInsert.Parent:=BottomBar; FInsert.Caption:='Insert'; FInsert.ModalResult:=mrOK; FInsert.Default:=True;
  FInsert.SetBounds(476,8,92,30); FInsert.Anchors:=[akRight,akTop];
  Cancel:=TButton.Create(Self); Cancel.Parent:=BottomBar; Cancel.Caption:='Cancel'; Cancel.ModalResult:=mrCancel; Cancel.Cancel:=True;
  Cancel.SetBounds(576,8,92,30); Cancel.Anchors:=[akRight,akTop];
  PreviewPanel:=TPanel.Create(Self); PreviewPanel.Parent:=Self; PreviewPanel.Align:=alRight; PreviewPanel.Width:=260; PreviewPanel.BevelOuter:=bvNone;
  FStatus:=TLabel.Create(Self); FStatus.Parent:=PreviewPanel; FStatus.Align:=alBottom; FStatus.AutoSize:=False;
  FStatus.Height:=108; FStatus.WordWrap:=True; FStatus.BorderSpacing.Around:=12;
  FPreview:=TPaintBox.Create(Self); FPreview.Parent:=PreviewPanel; FPreview.Align:=alClient; FPreview.OnPaint:=@PaintSymbol;
  Symbols:=TListBox.Create(Self); Symbols.Parent:=Self; Symbols.Align:=alClient; Symbols.BorderSpacing.Around:=12;
  Symbols.OnClick:=@SelectSymbol; ApplyTheme(Self);
end;
destructor TSymbolBrowser.Destroy;
begin FDraft.Free; FRegistry.Free; FPackageMap.Free; FCommon.Free; FAll.Free; inherited Destroy; end;
function TSymbolBrowser.PackageName:string;
var P:Integer;
begin
  Result:=''; if PackageList.ItemIndex>=2 then Result:=PackageList.Text
  else if PackageList.ItemIndex=1 then begin
    Result:=FPackageMap.Values[Command];
    if Result='' then begin P:=1; Result:=FPackageMap.Values['\'+ReadTeXCommand(Command,P)]; end;
  end;
end;
function TSymbolBrowser.Command:string;
begin Result:=''; if Symbols.ItemIndex>=0 then Result:=Symbols.Items[Symbols.ItemIndex]; end;
procedure TSymbolBrowser.LoadCommon(Commands:TStrings);
begin FCommon.Assign(Commands); LoadPackage(nil); end;
procedure TSymbolBrowser.LoadPackage(Sender:TObject);
var I:Integer; Value:string;
begin
  case PackageList.ItemIndex of
    0:begin FAll.Assign(FCommon); FRegistry.Load('\documentclass{article}\usepackage{amsmath,amssymb}',GetCurrentDir); end;
    1:begin
      ComprehensiveSymbolNames(FAll,FPackageMap);
      for I:=0 to FPackageMap.Count-1 do begin
        Value:=FPackageMap.ValueFromIndex[I];
        if (Value<>'') and (PackageList.Items.IndexOf(Value)<0) and (FindTeXFile(Value+'.sty')<>'') then PackageList.Items.Add(Value);
      end;
      FRegistry.Load('\documentclass{article}\usepackage{amsmath,amssymb}',GetCurrentDir);
    end;
    else PackageSymbolNames(PackageName,FRegistry,FAll);
  end;
  FPreviewPackage:=PackageName; Filter(nil);
end;
procedure TSymbolBrowser.Filter(Sender:TObject);
var SymbolName,Needle:string; I:Integer;
begin
  Needle:=LowerCase(Trim(Search.Text)); Symbols.Items.BeginUpdate;
  try
    {$IFDEF LCLgtk3}
    { GTK3's Clear autosizes rows before invalidating its cached iterators. }
    for I:=Symbols.Count-1 downto 0 do Symbols.Items.Delete(I);
    {$ELSE}
    Symbols.Items.Clear;
    {$ENDIF}
    for SymbolName in FAll do if (Needle='') or (Pos(Needle,LowerCase(SymbolName))>0) then Symbols.Items.Add(SymbolName);
    if Symbols.Count>0 then Symbols.ItemIndex:=0;
  finally Symbols.Items.EndUpdate; end;
  SelectSymbol(nil);
end;
procedure TSymbolBrowser.SelectSymbol(Sender:TObject);
begin
  FInsert.Enabled:=Command<>'';
  FStatus.Caption:=Format('%d commands',[Symbols.Count])+LineEnding+Command;
  if PackageName<>'' then FStatus.Caption:=FStatus.Caption+LineEnding+'Package: '+PackageName;
  if PackageName<>FPreviewPackage then begin
    FRegistry.Load('\documentclass{article}\usepackage{amsmath,amssymb,'+PackageName+'}',GetCurrentDir);
    FPreviewPackage:=PackageName;
  end;
  if (PackageName<>'') and (FindTeXFile(PackageName+'.sty')='') then begin
    FStatus.Caption:=FStatus.Caption+LineEnding+'This package is not installed.'; FInsert.Enabled:=False;
  end;
  if PackageList.ItemIndex=1 then FStatus.Caption:=FStatus.Caption+LineEnding+
    'Package-specific symbols require their package in the document preamble.';
  FPreview.Invalidate;
end;
procedure TSymbolBrowser.PaintSymbol(Sender:TObject);
var Tree:TMathNode; Source,ErrorText,SymbolName,Kind,Family:string; Info:TMacroInfo; Glyph:TNativeTeXGlyph;
    P,Slot,W,H:Integer; Em:Double;
begin
  FPreview.Canvas.Brush.Color:=PaperColor; FPreview.Canvas.FillRect(FPreview.ClientRect); Source:=Command; if Source='' then Exit;
  Tree:=nil;
  Glyph:=nil; P:=1; SymbolName:=ReadTeXCommand(Source,P); Info:=FRegistry.Find(SymbolName); Kind:='';
  try
    try
      { Browsing thousands of unrelated fonts must not exhaust the stable
        glyph indices held by the open document. Only this preview owns it. }
      if (Info<>nil) and (Info.GlyphPlan<>'') then Kind:='symbol-run-'+Info.GlyphPlan
      else if (Info<>nil) and (Info.GlyphFont<>'') then Kind:='text-'+Info.GlyphFont+'-'+IntToStr(Info.GlyphCode)
      else if TeXSymbol('\'+SymbolName,Family,Slot) then Kind:='text-'+TeXOpticalFont(Family,10)+'-'+IntToStr(Slot);
      if Kind<>'' then Glyph:=CreateNativeTeXGlyph(Kind,0);
      if Glyph<>nil then begin
        Em:=Min(52,Min((FPreview.Width-24)/Max(0.01,Glyph.Width),(FPreview.Height-24)/Max(0.01,Glyph.Height)));
        W:=Max(1,Ceil(Glyph.Width*Em)); H:=Max(1,Ceil(Glyph.Height*Em));
        if Glyph.Draw(FPreview.Canvas,Rect((FPreview.Width-W) div 2,(FPreview.Height-H) div 2,
          (FPreview.Width-W) div 2+W,(FPreview.Height-H) div 2+H),InkColor) then Exit;
      end;
      if not ParseMath(Source,Tree,ErrorText,FRegistry) then begin FStatus.Caption:=FStatus.Caption+LineEnding+ErrorText; Exit; end;
      FDraft.Macros:=FRegistry; FDraft.Layout(FPreview.Canvas,Tree,Max(100,FPreview.Width-24),False,26,nil,Source);
      FDraft.Paint(FPreview.Canvas,nil,nil,12,Max(12,(FPreview.Height-FDraft.Height) div 2));
    except FStatus.Caption:=FStatus.Caption+LineEnding+'Native preview unavailable.'; end;
  finally Glyph.Free; Tree.Free; end;
end;
function ChooseInstalledSymbol(Owner:TComponent; Commands:TStrings; out Code,PackageName:string):Boolean;
var Form:TSymbolBrowser; Info:TMacroInfo; P:Integer;
begin
  Code:=''; PackageName:=''; Form:=TSymbolBrowser.Create(Owner);
  try
    Form.LoadCommon(Commands); Result:=(Form.ShowModal=mrOK) and (Form.Command<>'');
    if Result then begin
      Code:=Form.Command; PackageName:=Form.PackageName;
      P:=1; Info:=Form.FRegistry.Find(ReadTeXCommand(Code,P));
      if (Info<>nil) and ((Info.GlyphPlan<>'') or (Info.PreviewAdapter='symbol')) then Code:='\mbox{'+Code+'}';
    end;
  finally Form.Free; end;
end;
end.
