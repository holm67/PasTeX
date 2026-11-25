unit SourcePDFView;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Types, Forms, Controls, StdCtrls, ExtCtrls, Graphics,
  FullSourceForm, PreviewImage, VectorPreview, TeXRenderer, ToolJobs, RibbonIcons;
type
  TPDFLocationEvent=procedure(Sender:TObject; Page:Integer; X,Y:Double) of object;
  TSourceLocationEvent=procedure(Sender:TObject; const FileName:string; Line,Column:Integer) of object;
  TPreviewMessageEvent=procedure(Sender:TObject; const Text:string) of object;
  TCompiledPDFView=class(TScrollBox)
  private
    FDocument:IVectorDocument;
    FPages:array of TPreviewPanel;
    FScale:Double;
    FFitWidth,FLayoutBusy:Boolean;
    procedure ArrangePages;
    procedure PageMouseDown(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
  protected
    procedure Resize; override;
  public
    OnSourceLocation:TPDFLocationEvent;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    function LoadPDF(const Path:string):Boolean;
    procedure Clear;
    procedure Zoom(Percent:Integer; FitWidth:Boolean);
    procedure Reveal(Page:Integer; X,Y:Double);
    procedure ViewLocation(out Page:Integer; out X,Y:Double);
    function PageCount:Integer;
    function ScalePercent:Integer;
  end;
  TSourcePDFView=class(TPanel)
  private
    FSource:TFullSourceForm;
    FSourceHost,FSyncBar:TPanel;
    FForwardButton,FInverseButton:TActionGlyphButton;
    FPreview:TCompiledPDFView;
    FTimer:TTimer;
    FWorker,FSnapshot:TRenderThread;
    FQuery:TToolJob;
    FName,FDirectory,FEngine,FSnapshotName,FQueryKind,FStatus,FLog:string;
    FDue:QWord;
    FRevision,FQueryRevision:Integer;
    FForwardPending:Boolean;
    procedure Tick(Sender:TObject);
    procedure CompileClick(Sender:TObject);
    procedure PositionSyncButtons(Sender:TObject);
    procedure Inverse(Sender:TObject; Page:Integer; X,Y:Double);
    procedure Query(const Kind:string; const Args:array of string);
    procedure Message(const AText:string);
  public
    OnSourceLocation:TSourceLocationEvent;
    OnMessage:TPreviewMessageEvent;
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    procedure Attach(Source:TFullSourceForm);
    procedure Detach;
    procedure LoadDocument(const FileName,Directory,Engine:string);
    procedure Changed;
    procedure ForwardSearch(Sender:TObject);
    procedure InverseSearch(Sender:TObject);
    property Preview:TCompiledPDFView read FPreview;
    property StatusMessage:string read FStatus;
    property CompilerLog:string read FLog;
    function PDFPath:string;
    function Busy:Boolean;
  end;
implementation
uses Math, LCLType, LazFileUtils, TeXDocument;
type TPDFImage=class(TPreviewImage) public property OnMouseDown; end;

constructor TCompiledPDFView.Create(AOwner:TComponent);
begin
  inherited; BorderStyle:=bsNone; FScale:=1; FFitWidth:=True;
  VertScrollBar.Tracking:=True; HorzScrollBar.Tracking:=True;
end;
destructor TCompiledPDFView.Destroy;
begin Clear; inherited; end;
procedure TCompiledPDFView.Clear;
var I:Integer;
begin
  for I:=0 to High(FPages) do FPages[I].Free;
  FPages:=nil; FDocument:=nil; VertScrollBar.Range:=0; HorzScrollBar.Range:=0;
end;
function TCompiledPDFView.PageCount:Integer;
begin Result:=Length(FPages); end;
function TCompiledPDFView.ScalePercent:Integer;
var W,H:Double;
begin
  Result:=Round(FScale*100);
  if FFitWidth and (Length(FPages)>0) and FDocument.PageSize(1,W,H) then
    Result:=Round(FPages[0].Width*72*100/Max(1,W)/96);
end;
function TCompiledPDFView.LoadPDF(const Path:string):Boolean;
var Document:IVectorDocument; Image:TPDFImage; I,Page:Integer; X,Y:Double;
begin
  Document:=OpenVectorDocument(Path); Result:=Document<>nil; if not Result then Exit;
  ViewLocation(Page,X,Y); DisableAlign;
  try
    Clear; FDocument:=Document; SetLength(FPages,VectorPageCount(Document));
    for I:=0 to High(FPages) do begin
      FPages[I]:=TPreviewPanel.Create(Self); FPages[I].Parent:=Self; FPages[I].BevelOuter:=bvNone;
      Image:=TPDFImage.Create(FPages[I]); Image.Parent:=FPages[I]; Image.Tag:=I+1;
      Image.Align:=alClient; Image.LoadVectorPreview(Document,I+1,96);
      Image.Surface.PreserveColors:=True; Image.OnMouseDown:=@PageMouseDown;
      Image.Hint:='Ctrl+click to show the corresponding source'; Image.ShowHint:=True;
    end;
  finally EnableAlign; end;
  ArrangePages; if Page>0 then Reveal(Page,X,Y);
end;
procedure TCompiledPDFView.ArrangePages;
var I,PageLeft,PageTop,PageRight,W,H:Integer; PW,PH:Double;
begin
  if FLayoutBusy or (FDocument=nil) then Exit; FLayoutBusy:=True;
  DisableAlign;
  try
    PageTop:=16; PageRight:=0;
    for I:=0 to High(FPages) do begin
      if not FDocument.PageSize(I+1,PW,PH) then Continue;
      if FFitWidth then W:=Max(80,PreviewLayoutWidth(Self)-32) else W:=Max(1,Round(PW*96/72*FScale));
      H:=Max(1,Round(W*PH/Max(1,PW)));
      PageLeft:=Max(16,(PreviewLayoutWidth(Self)-W) div 2);
      FPages[I].SetDocumentBounds(PageLeft,PageTop,W,H);
      PageRight:=Max(PageRight,PageLeft+W+16);
      Inc(PageTop,H+16);
    end;
    HorzScrollBar.Range:=PageRight; VertScrollBar.Range:=PageTop;
  finally EnableAlign; FLayoutBusy:=False; end;
end;
procedure TCompiledPDFView.Resize;
var Page:Integer; X,Y:Double;
begin
  ViewLocation(Page,X,Y); inherited; ArrangePages;
  if not FLayoutBusy then Reveal(Page,X,Y);
end;
procedure TCompiledPDFView.Zoom(Percent:Integer; FitWidth:Boolean);
var Page:Integer; X,Y:Double;
begin
  ViewLocation(Page,X,Y); FScale:=EnsureRange(Percent,25,400)/100; FFitWidth:=FitWidth;
  ArrangePages; Reveal(Page,X,Y);
end;
procedure TCompiledPDFView.ViewLocation(out Page:Integer; out X,Y:Double);
var I,ViewTop:Integer; W,H:Double;
begin
  Page:=0; X:=0; Y:=0; ViewTop:=VertScrollBar.Position;
  for I:=0 to High(FPages) do if ViewTop<FPages[I].DocumentOrigin.Y+FPages[I].Height then begin
    Page:=I+1; FDocument.PageSize(Page,W,H);
    X:=(HorzScrollBar.Position+ClientWidth/2-FPages[I].DocumentOrigin.X)*W/Max(1,FPages[I].Width);
    Y:=Max(0,ViewTop-FPages[I].DocumentOrigin.Y)*H/Max(1,FPages[I].Height); Exit;
  end;
end;
procedure TCompiledPDFView.Reveal(Page:Integer; X,Y:Double);
var W,H:Double; I:Integer;
begin
  if (FDocument=nil) or (Length(FPages)=0) then Exit;
  I:=EnsureRange(Page,1,Length(FPages))-1; FDocument.PageSize(I+1,W,H);
  SetPreviewScroll(Self,Max(0,FPages[I].DocumentOrigin.X+Round(X*FPages[I].Width/Max(1,W))-ClientWidth div 2),
    Max(0,FPages[I].DocumentOrigin.Y+Round(Y*FPages[I].Height/Max(1,H))));
end;
procedure TCompiledPDFView.PageMouseDown(Sender:TObject; Button:TMouseButton; Shift:TShiftState; X,Y:Integer);
var W,H:Double; Image:TPreviewImage;
begin
  if (Button<>mbLeft) or not (ssCtrl in Shift) or not Assigned(OnSourceLocation) then Exit;
  Image:=TPreviewImage(Sender); FDocument.PageSize(Image.Tag,W,H);
  OnSourceLocation(Self,Image.Tag,X*W/Max(1,Image.Width),Y*H/Max(1,Image.Height));
end;

constructor TSourcePDFView.Create(AOwner:TComponent);
var Bar,PreviewHost:TPanel; Button:TActionGlyphButton; Split:TSplitter;
  function Add(Parent:TWinControl; const Name,Icon,Hint:string; Handler:TNotifyEvent):TActionGlyphButton;
  begin
    Result:=TActionGlyphButton.Create(Self); Result.Name:=Name; Result.Parent:=Parent;
    Result.IconName:=Icon; Result.Hint:=Hint; Result.ShowHint:=True; Result.Flat:=True; Result.OnClick:=Handler;
  end;
begin
  inherited; BevelOuter:=bvNone;
  FSourceHost:=TPanel.Create(Self); FSourceHost.Parent:=Self; FSourceHost.Align:=alLeft;
  FSourceHost.Width:=480; FSourceHost.Constraints.MinWidth:=180; FSourceHost.BevelOuter:=bvNone;
  Split:=TSplitter.Create(Self); Split.Parent:=Self; Split.Align:=alLeft; Split.Left:=480;
  Split.Name:='SourcePDFSplitter';
  Split.Width:=6; Split.MinSize:=180; Split.AutoSnap:=False; Split.ResizeStyle:=rsUpdate;
  FSyncBar:=TPanel.Create(Self); FSyncBar.Parent:=Self; FSyncBar.Align:=alLeft; FSyncBar.Left:=486;
  FSyncBar.Name:='SyncTeXDivider'; FSyncBar.Caption:=''; FSyncBar.Width:=32; FSyncBar.BevelOuter:=bvNone;
  FForwardButton:=Add(FSyncBar,'SourceToPDF','sync-right','Show source position in PDF (SyncTeX)',@ForwardSearch);
  FInverseButton:=Add(FSyncBar,'PDFToSource','sync-left','Show PDF position in source (SyncTeX)',@InverseSearch);
  FSyncBar.OnResize:=@PositionSyncButtons; PositionSyncButtons(nil);
  PreviewHost:=TPanel.Create(Self); PreviewHost.Parent:=Self; PreviewHost.Align:=alClient; PreviewHost.BevelOuter:=bvNone;
  Bar:=TPanel.Create(Self); Bar.Parent:=PreviewHost; Bar.Align:=alTop; Bar.Height:=36; Bar.BevelOuter:=bvNone;
  Button:=Add(Bar,'RefreshCompiledPDF','refresh','Compile and refresh PDF',@CompileClick);
  Button.Caption:='Refresh PDF'; Button.SetBounds(4,2,128,32);
  FPreview:=TCompiledPDFView.Create(Self); FPreview.Parent:=PreviewHost; FPreview.Align:=alClient; FPreview.OnSourceLocation:=@Inverse;
  RefreshRibbonIcons(Self);
  FTimer:=TTimer.Create(Self); FTimer.Interval:=50; FTimer.OnTimer:=@Tick; FTimer.Enabled:=True;
end;
procedure TSourcePDFView.PositionSyncButtons(Sender:TObject);
var Y:Integer;
begin
  Y:=Max(4,(FSyncBar.ClientHeight-64) div 2);
  FForwardButton.SetBounds(2,Y,28,30); FInverseButton.SetBounds(2,Y+34,28,30);
end;
destructor TSourcePDFView.Destroy;
begin
  FTimer.Enabled:=False; Detach;
  if FWorker<>nil then begin FWorker.Terminate; FWorker.WaitFor; FreeAndNil(FWorker); end;
  FreeAndNil(FQuery); FPreview.Clear; FreeAndNil(FSnapshot); inherited;
end;
procedure TSourcePDFView.Attach(Source:TFullSourceForm);
begin
  FSource:=Source; Source.Hide; Source.BorderStyle:=bsNone; Source.Constraints.MinWidth:=0; Source.Constraints.MinHeight:=0;
  FSourceHost.Width:=Max(180,ClientWidth div 2);
  Source.Parent:=FSourceHost; Source.Align:=alClient; Source.Toolbar.Visible:=False; Source.Show;
end;
procedure TSourcePDFView.Detach;
begin
  if FSource=nil then Exit;
  FSource.Hide; FSource.Parent:=nil; FSource.Align:=alNone; FSource.BorderStyle:=bsSizeable;
  FSource.Toolbar.Visible:=True; FSource.SetBounds(200,120,900,680);
  FSource.Constraints.MinWidth:=640; FSource.Constraints.MinHeight:=300; FSource:=nil;
end;
procedure TSourcePDFView.Message(const AText:string);
begin FStatus:=AText; if Assigned(OnMessage) then OnMessage(Self,AText); end;
procedure TSourcePDFView.LoadDocument(const FileName,Directory,Engine:string);
begin
  Inc(FRevision); FName:=FileName; FDirectory:=Directory; FEngine:=Engine;
  if FWorker<>nil then FWorker.Terminate; FreeAndNil(FQuery);
  FPreview.Clear; FreeAndNil(FSnapshot); FLog:='';
  FForwardPending:=False; FDue:=GetTickCount64+100;
end;
procedure TSourcePDFView.Changed;
begin Inc(FRevision); FDue:=GetTickCount64+800; end;
function TSourcePDFView.PDFPath:string;
begin Result:=''; if FSnapshot<>nil then Result:=IncludeTrailingPathDelimiter(FSnapshot.WorkDir)+'preview.pdf'; end;
function TSourcePDFView.Busy:Boolean;
begin Result:=(FWorker<>nil) or (FQuery<>nil) or (FDue<>0); end;
procedure TSourcePDFView.CompileClick(Sender:TObject);
begin Changed; FDue:=GetTickCount64; end;
procedure TSourcePDFView.Tick(Sender:TObject);
var ResultText:TStringList; Path,Input,SourceText:string; Page,Line,Column:Integer; X,Y:Double; Format:TFormatSettings;
begin
  if not Visible or (FSource=nil) then Exit;
  if (FQuery<>nil) and FQuery.Finished and (FQueryRevision<>FRevision) then begin
    FreeAndNil(FQuery); Message('Source changed during SyncTeX lookup; compile before locating again');
  end;
  if (FQuery<>nil) and FQuery.Finished then begin
    ResultText:=TStringList.Create;
    try
      ResultText.NameValueSeparator:=':'; ResultText.Text:=FQuery.Output;
      if FQuery.ErrorText<>'' then Message('SyncTeX: '+FQuery.ErrorText)
      else if FQueryKind='view' then begin
        Page:=StrToIntDef(ResultText.Values['Page'],0); Format:=DefaultFormatSettings; Format.DecimalSeparator:='.';
        X:=StrToFloatDef(ResultText.Values['x'],0,Format); Y:=StrToFloatDef(ResultText.Values['y'],0,Format);
        if Page>0 then begin FPreview.Reveal(Page,X,Max(0,Y-36)); Message('SyncTeX: page '+IntToStr(Page)); end
        else Message('SyncTeX found no PDF position for this source line');
      end;
      Input:=ResultText.Values['Input']; Line:=StrToIntDef(ResultText.Values['Line'],0);
      Column:=Max(1,StrToIntDef(ResultText.Values['Column'],1));
      if (FQueryKind='edit') and (Line=0) then Message('SyncTeX found no source at this PDF position');
      FreeAndNil(FQuery);
      if (FQueryKind='edit') and (Line>0) then begin
        if SameFileName(ExpandFileName(Input),IncludeTrailingPathDelimiter(FSnapshot.WorkDir)+'preview.tex') then Input:=FSnapshotName
        else if not FilenameIsAbsolute(Input) then Input:=ExpandFileName(IncludeTrailingPathDelimiter(FDirectory)+Input);
        if Assigned(OnSourceLocation) then OnSourceLocation(Self,Input,Line,Column);
      end;
    finally ResultText.Free; end;
  end;
  if (FWorker<>nil) and FWorker.Finished and (FQuery=nil) then begin
    FLog:=FWorker.LogText;
    if FWorker.Revision=FRevision then begin
      if FWorker.ErrorText<>'' then Message('PDF compilation failed; previous PDF retained. '+FWorker.ErrorText)
      else begin
        Path:=IncludeTrailingPathDelimiter(FWorker.WorkDir)+'preview.pdf';
        if FPreview.LoadPDF(Path) then begin
          FreeAndNil(FSnapshot); FSnapshot:=FWorker; FWorker:=nil;
          FSnapshotName:=FName;
          Message('Compiled PDF ready · Ctrl+click the PDF to locate source');
        end else Message('Cannot display the compiled PDF. Check the Poppler installation.');
      end;
    end;
    FreeAndNil(FWorker);
    if FForwardPending and (FSnapshot<>nil) and (FSnapshot.Revision=FRevision) then begin FForwardPending:=False; ForwardSearch(nil); end;
  end;
  if (FDue<>0) and (GetTickCount64>=FDue) and (FWorker=nil) then begin
    FDue:=0;
    SourceText:=FSource.SourceEditor.Text;
    if not CompilableTeXDocument(SourceText) then begin Message('Open the master document to compile a PDF'); Exit; end;
    FWorker:=TRenderThread.Create(SourceText,FDirectory,FEngine,FRevision);
    FWorker.PDFOnly:=True; FWorker.SyncTeX:=True; FWorker.Start; Message('Compiling split-view PDF…');
  end;
end;
procedure TSourcePDFView.Query(const Kind:string; const Args:array of string);
begin
  if FQuery<>nil then Exit;
  if FindTool('synctex')='' then begin Message('SyncTeX is not installed; install it with your TeX distribution'); Exit; end;
  FQueryKind:=Kind; FQueryRevision:=FRevision; FQuery:=TToolJob.Create; FQuery.TimeoutMS:=10000;
  FQuery.Add('synctex',FDirectory,Args);
  TToolStep(FQuery.Steps[0]).Environment.Add('SYNCTEX_EDITOR=');
  TToolStep(FQuery.Steps[0]).Environment.Add('SYNCTEX_VIEWER='); FQuery.Start;
end;
procedure TSourcePDFView.ForwardSearch(Sender:TObject);
var Position:TPoint; Input:string;
begin
  if FSource=nil then Exit;
  if (FSnapshot=nil) or (FSnapshot.SourceText<>FSource.SourceEditor.Text) then begin
    FForwardPending:=True; if FWorker=nil then CompileClick(nil); Exit;
  end;
  Position:=FSource.SourceEditor.LogicalCaretXY;
  Input:=IncludeTrailingPathDelimiter(FSnapshot.WorkDir)+'preview.tex';
  Query('view',['view','-i',IntToStr(Position.Y)+':'+IntToStr(Position.X)+':'+Input,'-o',PDFPath]);
end;
procedure TSourcePDFView.Inverse(Sender:TObject; Page:Integer; X,Y:Double);
var Format:TFormatSettings;
begin
  if (FSnapshot=nil) or (Page<1) then Exit;
  if FSnapshot.SourceText<>FSource.SourceEditor.Text then begin Message('The PDF is out of date; compile before locating source'); Exit; end;
  Format:=DefaultFormatSettings; Format.DecimalSeparator:='.';
  Query('edit',['edit','-o',IntToStr(Page)+':'+FloatToStr(X,Format)+':'+FloatToStr(Y,Format)+':'+PDFPath]);
end;
procedure TSourcePDFView.InverseSearch(Sender:TObject);
var Page:Integer; X,Y:Double;
begin FPreview.ViewLocation(Page,X,Y); Inverse(Self,Page,X,Y+36); end;
end.
