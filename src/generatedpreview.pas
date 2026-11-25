unit GeneratedPreview;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Types, Graphics, PreviewImage, VectorPreview, TeXContext, TeXMacros, NativePagination;
type
  TGeneratedLink=record Bounds:TVectorImageBounds; Offset,Page:Integer; URI:string; end;
  TGeneratedLinks=array of TGeneratedLink;
  TGeneratedPreview=class
  private
    FPNG:RawByteString;
    FPicture:TPicture;
    FNative:TObject;
    procedure LoadTextLayout(const XML:string; Page:Integer);
  public
    Width,Height:Integer;
    Source,RenderedText:string;
    Characters:TVectorImageRegions;
    Surface:TPreviewSurface;
    Links:TGeneratedLinks;
    constructor Create;
    destructor Destroy; override;
    procedure Load(Image:TPreviewImage; const Text:string; Context:TTeXContext; const LayoutXML:string=''; LayoutPage:Integer=1);
    procedure Draw(Canvas:TCanvas; const Bounds:TRect);
    function EnsureNative(Canvas:TCanvas; const Text,Directory:string; Context:TTeXContext;
      LayoutWidth,FontSize:Integer; Scale,PixelsPerEm:Double; Macros:TMacroRegistry; const Engine:string=''):Boolean;
    function IsNative:Boolean;
    function PageLines:TPageLines;
    procedure Paginate(FirstRoom,BodyHeight,Gap:Integer);
    procedure PlacePageLines(const Shifts:TPageShifts; NewHeight:Integer);
    function NativeHeight:Integer;
    function Hit(X,Y:Double):Integer;
    function SelectedText(First,Last:Integer):string;
    function SelectionBounds(First,Last:Integer):TVectorImageRegions;
  end;
function IsGeneratedCommand(const Command:string):Boolean;
function GeneratedBlock(const Source:string):Boolean;
procedure EnsureNativePages(Canvas:TCanvas; Context:TTeXContext; const Directory:string;
  Width,Size:Integer; Scale,Em:Double; const Engine:string);
implementation
uses Math, LazUTF8, TeXDocument, DocumentOutline, TeXBibliography, TeXLayout, NativeGenerated, DraftLayout, MathModel, ParagraphModel, UITheme, TeXDocumentMetrics, NativeFloats, TeXTextStyle;
type
  TNativeRow=class
    Body,LabelDraft,PageDraft:TParagraphDraft;
    Trees:array[0..2] of TMathNode;
    X,Y,Origin,Height,BaseHeight,LabelX,PageX,Target,FirstGroup,LastGroup:Integer;
    LabelShift,PageShift,LastRight,LastBaseline:Integer;
    Leaders:Boolean;
    destructor Destroy; override;
  end;
  TPageMeasurementCache=class
    Sources:TStringList;
    Blocks:TPageBlocks;
    Directory,Engine:string;
    Width,Size:Integer;
    Scale,Em:Double;
    Revision:QWord;
    constructor Create;
    destructor Destroy; override;
    procedure Store(const Keys:TStrings; const Flow:TPageBlocks);
  end;
var BuildingPages:Boolean;
constructor TPageMeasurementCache.Create;
begin
  Sources:=TStringList.Create; Sources.CaseSensitive:=True; Sources.Sorted:=True; Sources.Duplicates:=dupIgnore;
end;
destructor TPageMeasurementCache.Destroy;
begin Sources.Free; inherited Destroy; end;
procedure TPageMeasurementCache.Store(const Keys:TStrings; const Flow:TPageBlocks);
const Limit=2*1024*1024;
var I,J,N,Bytes,EntryBytes:Integer;
begin
  Sources.Clear; Blocks:=nil; SetLength(Blocks,Length(Flow)); N:=0; Bytes:=0;
  for I:=0 to High(Flow) do begin
    if Sources.Find(Keys[I],J) then Continue;
    EntryBytes:=Length(Keys[I])+Length(Flow[I].Lines)*SizeOf(TPageLine)+SizeOf(TPageBlock)+64;
    if EntryBytes>Limit-Bytes then Continue;
    Sources.AddObject(Keys[I],TObject(PtrInt(N))); Blocks[N]:=Flow[I];
    { Only line measurements survive. No drawing trees, glyph runs, images or
      source-editor spaces are retained by this cache. }
    Blocks[N].Shifts:=nil; Inc(N); Inc(Bytes,EntryBytes);
  end;
  SetLength(Blocks,N);
end;
procedure NativeTextEdges(Box:TDraftBox; X,Y:Integer; var First,Last,Right:Integer);
var I,Base:Integer;
begin
  Inc(X,Box.X); Inc(Y,Box.Y);
  if (Box.Text<>'') and (Trim(Box.Text)<>'') and (Box.Children.Count=0) then begin
    Base:=Y+Box.Baseline; First:=Min(First,Base);
    if Base>Last+2 then begin Last:=Base; Right:=X+Box.W; end
    else if Abs(Base-Last)<=2 then Right:=Max(Right,X+Box.W);
  end;
  for I:=0 to Box.Children.Count-1 do NativeTextEdges(TDraftBox(Box.Children[I]),X,Y,First,Last,Right);
end;
procedure EnsureNativePages(Canvas:TCanvas; Context:TTeXContext; const Directory:string;
  Width,Size:Integer; Scale,Em:Double; const Engine:string);
var Doc:TTeXDocument; Draft:TParagraphDraft; Preview:TGeneratedPreview; Tree:TMathNode; Pages:TSourcePages;
    I,J,Pass,Body,Pitch,DeclarationVersion:Integer; L,T,W,TextHeight,Paper,PaperHeight:Double; Flow:TPageBlocks;
    Registry:TMacroRegistry; Declarations,NextDeclarations,Key:string; Revision:QWord;
    Cache:TPageMeasurementCache; Keys:TStringList; Reuse:Boolean;
begin
  if Context=nil then Exit;
  if BuildingPages or Context.NativePageLayout or ((Context.NativePageWidth=Width) and (Context.NativePageEm=Em) and
    (Context.NativePageFontSize=Size) and (Context.NativePageEngine=Engine)) then Exit;
  BuildingPages:=True; Doc:=TTeXDocument.Create; Draft:=TParagraphDraft.Create; Preview:=TGeneratedPreview.Create;
  Registry:=TMacroRegistry.Create; Tree:=nil; Keys:=TStringList.Create;
  try
    Doc.ParseFile(Context.Source); DocumentPageArea(Doc.Preamble,L,T,W,TextHeight); DocumentPaperSize(Doc.Preamble,Paper,PaperHeight);
    if Context.NativePageMeasurements=nil then Context.NativePageMeasurements:=TPageMeasurementCache.Create;
    Cache:=TPageMeasurementCache(Context.NativePageMeasurements);
    Reuse:=(Cache.Revision=Context.LayoutRevision) and
      (Cache.Directory=Directory) and (Cache.Engine=Engine) and (Cache.Width=Width) and
      (Cache.Size=Size) and (Cache.Scale=Scale) and (Cache.Em=Em);
    Body:=Max(40,Round(TextHeight*120/72.27*Scale)); Pitch:=Max(Body+24,Round(PaperHeight*120/72.27*Scale)+24);
    SetLength(Pages,Doc.Blocks.Count); SetLength(Flow,Doc.Blocks.Count);
    Draft.Context:=Context; Draft.Macros:=Registry; Draft.Directory:=Directory; Draft.TeXEngine:=Engine;
    Draft.PageLayout:=True; Draft.HideEditingMarks:=True; Draft.HideEnvironmentCaptions:=True;
    Draft.DocumentFontSize:=Max(1,Round(Em/Max(0.01,Scale)*72.27/120));
    { Contents page numbers can change their own line breaks. Keep ordinary
      paragraph measurements and repeat only generated blocks until stable. }
    for Pass:=0 to 3 do begin
      Registry.Load(Doc.Preamble,Directory,Engine); Declarations:=''; DeclarationVersion:=0;
      for I:=0 to Doc.Blocks.Count-1 do begin
        Key:=IntToStr(DeclarationVersion)+#0+Doc.Blocks[I];
        if Pass=0 then Keys.Add(Key);
        if (Pass=0) and Reuse and Cache.Sources.Find(Key,J) then begin
          Flow[I]:=Cache.Blocks[PtrInt(Cache.Sources.Objects[J])]; Flow[I].Shifts:=nil;
        end else if (Pass=0) or GeneratedBlock(Doc.Blocks[I]) or HasPageReferences(Doc.Blocks[I]) then begin
          Draft.HeadingContext:=Doc.Preamble+Declarations;
          Tree:=ParseParagraph(Doc.Blocks[I],Registry); Draft.Generated:=nil;
          if Preview.EnsureNative(Canvas,Doc.Blocks[I],Directory,Context,Width,Size,Scale,Em,Registry,Engine) then Draft.Generated:=Preview;
          Draft.ContextOffset:=Doc.SourceOffset(I,0);
          Draft.Layout(Canvas,Tree,Width,True,Size,nil,Doc.Blocks[I],Scale,Em);
          Flow[I].Lines:=Copy(Draft.PageLines); Flow[I].NativeHeight:=Max(0,Draft.NativeHeight);
          ReadPageFloat(Doc.Blocks[I],Flow[I].FloatKind,Flow[I].Placement);
          FreeAndNil(Tree);
        end;
        Pages[I].Offset:=Doc.SourceOffset(I,0);
        NextDeclarations:=TeXContextDeclarations(Doc.Blocks[I]);
        if NextDeclarations<>'' then begin
          Registry.ApplyDefinitions(NextDeclarations); Declarations:=Declarations+NextDeclarations; Inc(DeclarationVersion);
        end;
      end;
      LayoutPageBlocks(Flow,FloatPageSettings(Doc.Preamble,Body,Pitch,120*Scale/72.27));
      for I:=0 to High(Flow) do Pages[I].Page:=PageBlockFirstPage(Flow[I],Pitch);
      Revision:=Context.PageRevision; Context.SetNativePages(PageSourceMap(Flow,Pages,Pitch));
      if Revision=Context.PageRevision then Break;
    end;
    Context.NativePageWidth:=Width; Context.NativePageEm:=Em;
    Context.NativePageFontSize:=Size; Context.NativePageEngine:=Engine;
    Cache.Store(Keys,Flow); Cache.Revision:=Context.LayoutRevision;
    Cache.Directory:=Directory; Cache.Engine:=Engine; Cache.Width:=Width; Cache.Size:=Size; Cache.Scale:=Scale; Cache.Em:=Em;
  finally Keys.Free; Tree.Free; Preview.Free; Draft.Free; Registry.Free; Doc.Free; BuildingPages:=False; end;
end;
type
  TNativeLayout=class
    LinkMacros:TMacroRegistry;
    Rows:array of TNativeRow;
    Lines:TPageLines;
    Shifts:TPageShifts;
    Boxes:array of record Box:TDraftBox; Y,Group:Integer; end;
    Width,BaseHeight,Height,Size,First,Body,Gap:Integer;
    Scale,Em:Double;
    FullSource,Directory,Engine:string;
    Revision,PageRevision:QWord;
    Context:TTeXContext;
    destructor Destroy; override;
    procedure IndexLines;
    procedure MapText(Preview:TGeneratedPreview);
    procedure Draw(Canvas:TCanvas; X,Y:Integer);
  end;
destructor TNativeRow.Destroy;
var I:Integer;
begin Body.Free; LabelDraft.Free; PageDraft.Free; for I:=0 to 2 do Trees[I].Free; inherited; end;
destructor TNativeLayout.Destroy;
var Row:TNativeRow;
begin for Row in Rows do Row.Free; LinkMacros.Free; inherited; end;
procedure TNativeLayout.IndexLines;
var Row:TNativeRow; D:TParagraphDraft; I,J,N,Y:Integer; Box:TDraftBox;
begin
  Lines:=nil; Boxes:=nil;
  for Row in Rows do begin
    D:=Row.Body; Row.FirstGroup:=Length(Lines);
    for I:=0 to D.RootBox.Children.Count-1 do begin
      Box:=TDraftBox(D.RootBox.Children[I]); Y:=Row.Origin+Box.Y; J:=High(Lines);
      if (J<0) or (Y>=Lines[J].Bottom) then begin Inc(J); SetLength(Lines,J+1); Lines[J].Top:=Y; end;
      Lines[J].Bottom:=Max(Lines[J].Bottom,Y+Max(1,Box.H));
      N:=Length(Boxes); SetLength(Boxes,N+1); Boxes[N].Box:=Box; Boxes[N].Y:=Box.Y; Boxes[N].Group:=J;
    end;
    if Length(Lines)=Row.FirstGroup then begin
      J:=Length(Lines); SetLength(Lines,J+1);
      Lines[J].Top:=Row.Origin+10; Lines[J].Bottom:=Row.Origin+Max(11,Row.BaseHeight-10);
    end;
    Row.LastGroup:=High(Lines);
  end;
end;
procedure TNativeLayout.MapText(Preview:TGeneratedPreview);
var Last:TRect; Row:TNativeRow; SuppressGap:Boolean;
  procedure Add(const Text:string; const R:TRect);
  var I:Integer;
  begin
    if Text='' then Exit; Preview.RenderedText:=Preview.RenderedText+Text;
    I:=Length(Preview.Characters); SetLength(Preview.Characters,I+1);
    Preview.Characters[I].Left:=R.Left/Max(1,Width); Preview.Characters[I].Right:=R.Right/Max(1,Width);
    Preview.Characters[I].Top:=R.Top/Max(1,Height); Preview.Characters[I].Bottom:=R.Bottom/Max(1,Height);
  end;
  procedure Visit(Box:TDraftBox; X,Y:Integer);
  var I,Count,L,R:Integer; Bounds:TRect; Text:string;
  begin
    Inc(X,Box.X); Inc(Y,Box.Y); Text:=Box.Text;
    if (Text<>'') and (Box.Children.Count=0) then begin
      Bounds:=Rect(X,Y,X+Box.W,Y+Box.H);
      if not SuppressGap and (Preview.RenderedText<>'') then begin
        if Abs(Bounds.Top+Box.Baseline-Last.Bottom)>Max(3,Box.H div 2) then Add(#10,Rect(0,0,0,0))
        else if (Bounds.Left>Last.Right+Max(2,Box.H div 8)) and not (Preview.RenderedText[Length(Preview.RenderedText)] in [' ',#10]) then
          Add(' ',Rect(Last.Right,Y,X,Y+Box.H));
      end;
      SuppressGap:=False; Count:=UTF8Length(Text);
      for I:=0 to Count-1 do begin
        L:=Round(Box.W*I/Max(1,Count)); R:=Round(Box.W*(I+1)/Max(1,Count));
        if Length(Box.Stops)=Count+1 then begin L:=Box.Stops[I]; R:=Box.Stops[I+1]; end;
        Add(UTF8Copy(Text,I+1,1),Rect(X+L,Y,X+Max(L+1,R),Y+Box.H));
      end;
      Last:=Rect(Bounds.Left,Bounds.Top,Bounds.Right,Bounds.Top+Box.Baseline);
    end;
    for I:=0 to Box.Children.Count-1 do Visit(TDraftBox(Box.Children[I]),X,Y);
  end;
  procedure URLs(const Text:string);
  var P,A,I,J,N,Count:Integer; Command,URI,Caption:string; R:TVectorImageBounds;
  begin
    P:=1;
    while P<=Length(Text) do begin
      if Text[P]<>'\' then begin Inc(P); Continue; end; Command:=ReadTeXCommand(Text,P);
      if (Command<>'url') and (Command<>'href') then Continue;
      URI:=ReadTeXGroup(Text,P,'{','}'); Caption:=URI;
      if Command='href' then Caption:=ReadTeXGroup(Text,P,'{','}');
      A:=Pos(Caption,Preview.RenderedText); if A=0 then Continue;
      I:=UTF8Length(Copy(Preview.RenderedText,1,A-1)); Count:=UTF8Length(Caption);
      for J:=I to Min(I+Count-1,High(Preview.Characters)) do begin
        R:=Preview.Characters[J]; if R.Right<=R.Left then Continue;
        N:=Length(Preview.Links); SetLength(Preview.Links,N+1); Preview.Links[N].Bounds:=R;
        Preview.Links[N].Offset:=-1; Preview.Links[N].Page:=-1; Preview.Links[N].URI:=URI;
      end;
    end;
  end;
var N:Integer;
begin
  Preview.RenderedText:=''; Preview.Characters:=nil; Preview.Links:=nil; Last:=Rect(0,0,0,0); SuppressGap:=True;
  for Row in Rows do begin
    if Row.LabelDraft<>nil then Visit(Row.LabelDraft.RootBox,Row.LabelX,Row.Y+Row.LabelShift);
    Visit(Row.Body.RootBox,Row.X,Row.Origin);
    if Row.PageDraft<>nil then begin
      SuppressGap:=True; Add(#9,Rect(0,0,0,0));
      Visit(Row.PageDraft.RootBox,Row.PageX,Row.Y+Row.Height-Row.BaseHeight+Row.PageShift);
    end;
    Add(#10,Rect(0,0,0,0)); SuppressGap:=True;
    if Row.Target>=0 then begin
      N:=Length(Preview.Links); SetLength(Preview.Links,N+1);
      Preview.Links[N].Bounds.Left:=0; Preview.Links[N].Bounds.Right:=1;
      Preview.Links[N].Bounds.Top:=(Row.Y+10)/Max(1,Height); Preview.Links[N].Bounds.Bottom:=(Row.Y+Row.Height-10)/Max(1,Height);
      Preview.Links[N].Offset:=Row.Target; Preview.Links[N].Page:=-1;
    end;
  end;
  for Row in Rows do URLs(Row.Trees[0].TeX);
end;
procedure TNativeLayout.Draw(Canvas:TCanvas; X,Y:Integer);
var Row:TNativeRow; Start,Stop,Baseline:Integer;
begin
  for Row in Rows do begin
    Row.Body.Paint(Canvas,nil,nil,X+Row.X,Y+Row.Origin);
    if Row.LabelDraft<>nil then Row.LabelDraft.Paint(Canvas,nil,nil,X+Row.LabelX,Y+Row.Y+Row.LabelShift);
    if Row.PageDraft<>nil then Row.PageDraft.Paint(Canvas,nil,nil,X+Row.PageX,Y+Row.Y+Row.Height-Row.BaseHeight+Row.PageShift);
    if Row.Leaders and (Row.PageDraft<>nil) then begin
      Start:=X+Row.X+Row.LastRight+Round(Em*0.4); Stop:=X+Row.PageX-Round(Em*0.3);
      Baseline:=Y+Row.Y+Row.Height-Row.BaseHeight+Row.LastBaseline;
      Canvas.Pen.Color:=InkColor; Canvas.Pen.Width:=1;
      while Start<Stop do begin Canvas.Brush.Color:=InkColor; Canvas.FillRect(Rect(Start,Baseline-1,Start+2,Baseline+1)); Inc(Start,Max(3,Round(Em*0.45))); end;
    end;
  end;
end;
function IsGeneratedCommand(const Command:string):Boolean;
begin
  Result:=IsGeneratedTeXCommand(Command);
end;
function GeneratedBlock(const Source:string):Boolean;
begin
  Result:=IsGeneratedTeXBlock(Source);
end;
constructor TGeneratedPreview.Create;
begin inherited Create; Surface:=TPreviewSurface.Create; FPicture:=TPicture.Create; end;
destructor TGeneratedPreview.Destroy;
begin FNative.Free; Surface.Free; FPicture.Free; inherited Destroy; end;
function TGeneratedPreview.IsNative:Boolean;
begin Result:=FNative<>nil; end;
function TGeneratedPreview.NativeHeight:Integer;
begin if IsNative then Result:=TNativeLayout(FNative).BaseHeight else Result:=Height; end;
function TGeneratedPreview.PageLines:TPageLines;
begin if IsNative then Result:=TNativeLayout(FNative).Lines else Result:=nil; end;
procedure TGeneratedPreview.Paginate(FirstRoom,BodyHeight,Gap:Integer);
var Layout:TNativeLayout; Shifts:TPageShifts; NewHeight:Integer;
begin
  if not IsNative then Exit; Layout:=TNativeLayout(FNative);
  if (Layout.First=FirstRoom) and (Layout.Body=BodyHeight) and (Layout.Gap=Gap) then Exit;
  NewHeight:=PaginateLines(Layout.Lines,Layout.BaseHeight,FirstRoom,BodyHeight,Gap,Shifts);
  PlacePageLines(Shifts,NewHeight);
  Layout.First:=FirstRoom; Layout.Body:=BodyHeight; Layout.Gap:=Gap;
end;
procedure TGeneratedPreview.PlacePageLines(const Shifts:TPageShifts; NewHeight:Integer);
var Layout:TNativeLayout; I:Integer; Row:TNativeRow;
begin
  if not IsNative then Exit; Layout:=TNativeLayout(FNative);
  if Length(Shifts)<>Length(Layout.Lines) then Exit;
  if (Height=NewHeight) and SamePageShifts(Shifts,Layout.Shifts) then Exit;
  Height:=NewHeight; Layout.Height:=Height; Layout.Shifts:=Copy(Shifts); Layout.Body:=-1;
  for I:=0 to High(Layout.Boxes) do Layout.Boxes[I].Box.Y:=Layout.Boxes[I].Y+Shifts[Layout.Boxes[I].Group];
  for Row in Layout.Rows do begin
    Row.Y:=Row.Origin; Row.Height:=Row.BaseHeight;
    if Row.LastGroup>=Row.FirstGroup then begin
      Inc(Row.Y,Shifts[Row.FirstGroup]); Inc(Row.Height,Shifts[Row.LastGroup]-Shifts[Row.FirstGroup]);
    end;
  end;
  Layout.MapText(Self);
end;
function TGeneratedPreview.EnsureNative(Canvas:TCanvas; const Text,Directory:string; Context:TTeXContext;
  LayoutWidth,FontSize:Integer; Scale,PixelsPerEm:Double; Macros:TMacroRegistry; const Engine:string):Boolean;
var Layout:TNativeLayout; Data:TGeneratedRows; Item:TGeneratedRow; Row:TNativeRow;
    I,P,Y,Inset,LabelWidth,RightWidth,First,Last,Right,OtherFirst,OtherLast,OtherRight,PreviousBaseline,BaselineSkip:Integer; Cmd,Value:string;
    RenderMacros:TMacroRegistry; TextStyle:TTeXTextStyle;
  function MakeDraft(const Text:string; W,Slot:Integer):TParagraphDraft;
  begin
    Result:=TParagraphDraft.Create;
    Result.Macros:=RenderMacros; Result.Context:=Context; Result.HeadingContext:=Context.Source;
    Result.Directory:=Directory; Result.DocumentFontSize:=Round(PixelsPerEm/Max(0.01,Scale)*72.27/120);
    Result.TeXEngine:=Engine;
    Result.HideEditingMarks:=True; Result.SuppressParagraphIndent:=True;
    Row.Trees[Slot]:=ParseParagraph(Text,RenderMacros);
    Result.Layout(Canvas,Row.Trees[Slot],Max(80,W),True,FontSize,nil,Text,Scale,PixelsPerEm);
  end;
begin
  Result:=False; if (Context=nil) or not GeneratedBlock(Text) then Exit;
  P:=1; Cmd:='';
  while P<=Length(Text) do begin
    if Text[P]<>'\' then begin Inc(P); Continue; end; Cmd:=ReadTeXCommand(Text,P);
    if IsGeneratedCommand(Cmd) then Break;
    ReadTeXGroup(Text,P,'{','}');
  end;
  if (Cmd='') or (Cmd='maketitle') then Exit; Result:=True;
  EnsureNativePages(Canvas,Context,Directory,LayoutWidth,FontSize,Scale,PixelsPerEm,Engine);
  if IsNative then begin
    Layout:=TNativeLayout(FNative);
    if (Source=Text) and (Layout.FullSource=Context.Source) and (Layout.Directory=Directory) and
      (Layout.Width=LayoutWidth) and (Layout.Size=FontSize) and (Layout.Scale=Scale) and
      (Layout.Em=PixelsPerEm) and (Layout.Engine=Engine) and (Layout.Revision=Context.LayoutRevision) and (Layout.PageRevision=Context.PageRevision) then Exit;
  end;
  FreeAndNil(FNative); FPNG:=''; FPicture.Clear; Surface.SetVector(nil,-1);
  Layout:=TNativeLayout.Create; FNative:=Layout; Source:=Text; Layout.FullSource:=Context.Source;
  Layout.Directory:=Directory; Layout.Width:=LayoutWidth; Layout.Size:=FontSize; Layout.Scale:=Scale; Layout.Em:=PixelsPerEm;
  Layout.Engine:=Engine;
  Layout.Revision:=Context.LayoutRevision; Layout.PageRevision:=Context.PageRevision; Layout.Context:=Context;
  RenderMacros:=Macros;
  if not IsContentsTeXCommand(Cmd) and ((Macros=nil) or (Macros.Find('href')=nil) or (Macros.Find('url')=nil)) then begin
    if Macros<>nil then Layout.LinkMacros:=Macros.Clone else Layout.LinkMacros:=TMacroRegistry.Create;
    { Bibliography links are editor objects even without hyperref in the file.
      Keep these native adapters private; source and command hints stay intact. }
    Layout.LinkMacros.InstallPackagePreview('hyperref','hyperref.sty'); RenderMacros:=Layout.LinkMacros;
  end;
  Data:=NativeGeneratedRows(Cmd,Text,Directory,Context); Y:=0; PreviousBaseline:=-1; BaselineSkip:=0;
  if IsContentsTeXCommand(Cmd) then begin
    TextStyle:=InitialTextStyle(Context.Source,Directory,Engine,RenderMacros);
    BaselineSkip:=Round(TextBaselineDistance(TextStyle,0,0)*PixelsPerEm/Max(1,TextStyle.Points));
  end;
  for Item in Data do begin
    Row:=TNativeRow.Create; I:=Length(Layout.Rows); SetLength(Layout.Rows,I+1); Layout.Rows[I]:=Row;
    Row.Target:=Item.Offset; Row.Leaders:=Item.Leaders;
    Inset:=Round(Item.Indent*PixelsPerEm); LabelWidth:=0; RightWidth:=0;
    if Item.LabelText<>'' then begin
      Value:=Item.LabelText; if Item.Bold then Value:='\textbf{'+Value+'}';
      Row.LabelDraft:=MakeDraft('\noindent '+Value,LayoutWidth,1);
      LabelWidth:=Max(Round(PixelsPerEm*1.5),Row.LabelDraft.ContentInkBounds.Right-10+Round(PixelsPerEm*0.5));
      Row.LabelX:=Inset;
    end;
    if (Item.Page<>'') or IsContentsTeXCommand(Cmd) and not Item.Title then begin
      Value:=Item.Page; if Value='' then Value:='?'; if Item.Bold then Value:='\textbf{'+Value+'}';
      Row.PageDraft:=MakeDraft('\noindent '+Value,LayoutWidth,2);
      RightWidth:=Max(Round(PixelsPerEm*2),Row.PageDraft.ContentInkBounds.Right);
      Row.PageX:=LayoutWidth-Row.PageDraft.ContentInkBounds.Right-10;
    end;
    Value:=Item.Text; if Value='' then Value:='~';
    if Item.Bold then Value:='\textbf{'+Value+'}';
    if not Item.Title then Value:='\noindent\raggedright '+Value;
    Row.Body:=MakeDraft(Value,LayoutWidth-Inset-LabelWidth-RightWidth,0); Row.X:=Inset+LabelWidth;
    First:=MaxInt; Last:=0; Right:=0; NativeTextEdges(Row.Body.RootBox,0,0,First,Last,Right);
    if Row.LabelDraft<>nil then begin
      OtherFirst:=MaxInt; OtherLast:=0; OtherRight:=0;
      NativeTextEdges(Row.LabelDraft.RootBox,0,0,OtherFirst,OtherLast,OtherRight);
      if First=MaxInt then begin First:=OtherFirst; Last:=OtherLast; end;
      if (First<>MaxInt) and (OtherFirst<>MaxInt) then Row.LabelShift:=First-OtherFirst;
    end;
    if Row.PageDraft<>nil then begin
      OtherFirst:=MaxInt; OtherLast:=0; OtherRight:=0;
      NativeTextEdges(Row.PageDraft.RootBox,0,0,OtherFirst,OtherLast,OtherRight);
      if First=MaxInt then begin First:=OtherFirst; Last:=OtherLast; end;
      if (Last>0) and (OtherFirst<>MaxInt) then Row.PageShift:=Last-OtherFirst;
    end;
    Row.LastRight:=Right; Row.LastBaseline:=Last;
    if Item.Bold then Inc(Y,Round(PixelsPerEm));
    Row.Origin:=Y; if not Item.Title then Dec(Row.Origin,10);
    { Separate row drafts still share TeX's baseline glue, even when a short
      caption is empty and only its number and page are printed. }
    if not Item.Title and (BaselineSkip>0) and (PreviousBaseline>=0) and (First<>MaxInt) then
      Row.Origin:=Max(Row.Origin,PreviousBaseline+BaselineSkip-First);
    Row.Y:=Row.Origin; Row.Height:=Row.Body.Height;
    if Row.LabelDraft<>nil then Row.Height:=Max(Row.Height,Row.LabelDraft.Height);
    if Row.PageDraft<>nil then Row.Height:=Max(Row.Height,Row.PageDraft.Height);
    Row.BaseHeight:=Row.Height;
    Y:=Row.Origin+Row.Height; if not Item.Title then Dec(Y,10);
    if not Item.Title and not IsContentsTeXCommand(Cmd) then Inc(Y,Round(PixelsPerEm*0.4));
    if Item.Title then Inc(Y,Round(PixelsPerEm*0.2));
    if Last>0 then PreviousBaseline:=Row.Origin+Last;
  end;
  Width:=LayoutWidth; Height:=Max(28,Y+10); Layout.Height:=Height; Layout.BaseHeight:=Height;
  Layout.First:=Low(Integer); Layout.IndexLines; Layout.MapText(Self);
end;
procedure TGeneratedPreview.LoadTextLayout(const XML:string; Page:Integer);
var Layout:TTeXLayout; Bitmap:TBitmap; Glyph:TTeXGlyph; Previous:TRect; I:Integer; Native:TVectorLink;
  procedure Add(const Value:string; const Bounds:TRect);
  var N:Integer;
  begin
    RenderedText:=RenderedText+Value; N:=Length(Characters); SetLength(Characters,N+1);
    Characters[N].Left:=Bounds.Left/Max(1,Layout.Width); Characters[N].Right:=Bounds.Right/Max(1,Layout.Width);
    Characters[N].Top:=Bounds.Top/Max(1,Layout.Height); Characters[N].Bottom:=Bounds.Bottom/Max(1,Layout.Height);
  end;
begin
  if XML='' then Exit; Layout:=TTeXLayout.Create; Bitmap:=TBitmap.Create;
  try
    Bitmap.SetSize(1,1); Layout.Load(XML,Page,Bitmap.Canvas); Previous:=Rect(0,0,0,0);
    for Glyph in Layout.Glyphs do begin
      if RenderedText<>'' then begin
        if Abs(Glyph.Bounds.Top+Glyph.Bounds.Height*0.8-Previous.Top-Previous.Height*0.8)>Max(2,Previous.Height*0.4) then
          Add(#10,Rect(0,0,0,0))
        else if (Glyph.Bounds.Left-Previous.Right>Max(2,Previous.Height*0.12)) and
          not (RenderedText[Length(RenderedText)] in [' ',#10]) and (Glyph.Text<>' ') then
          Add(' ',Rect(Previous.Right,Glyph.Bounds.Top,Glyph.Bounds.Left,Glyph.Bounds.Bottom));
      end;
      Add(Glyph.Text,Glyph.Bounds); Previous:=Glyph.Bounds;
    end;
    for Native in Layout.Links do begin
      I:=Length(Links); SetLength(Links,I+1); Links[I].Bounds:=Native.Bounds; Links[I].Offset:=-1;
      Links[I].Page:=Native.Page; Links[I].URI:=Native.URI;
    end;
  finally Bitmap.Free; Layout.Free; end;
end;
procedure TGeneratedPreview.Load(Image:TPreviewImage; const Text:string; Context:TTeXContext; const LayoutXML:string; LayoutPage:Integer);
var Doc:TTeXDocument; Entries:TOutlineEntries; I,P,A:Integer; Command,Caption,Key,LabelText:string; Native:TVectorLink;
  function CitationOffset(const Key:string):Integer;
  var P,A:Integer; Command,Keys:string;
  begin
    Result:=-1; P:=1;
    while P<=Length(Context.Source) do begin
      SkipTeXSpace(Context.Source,P); if P>Length(Context.Source) then Break;
      if Context.Source[P]<>'\' then begin Inc(P); Continue; end;
      A:=P; Command:=ReadTeXCommand(Context.Source,P);
      if not IsCitationCommand(Command) then Continue;
      if Copy(Context.Source,P,1)='*' then Inc(P);
      SkipTeXSpace(Context.Source,P);
      while Copy(Context.Source,P,1)='[' do begin ReadTeXGroup(Context.Source,P,'[',']'); SkipTeXSpace(Context.Source,P); end;
      Keys:=StringReplace(ReadTeXGroup(Context.Source,P,'{','}'),' ','',[rfReplaceAll]);
      if Pos(','+Key+',',','+Keys+',')>0 then Exit(A-1);
    end;
  end;
  procedure Link(const Text:string; Offset:Integer; WholeLine:Boolean);
  var Matches:TVectorImageRegions; Match:TVectorImageBounds; N,P,First:Integer;
  begin
    if (Offset<0) or (Text='') then Exit;
    if Surface.VectorDocument<>nil then Matches:=Surface.VectorDocument.FindText(Surface.VectorPage,Text)
    else begin
      Matches:=nil; P:=Pos(Text,RenderedText);
      if P>0 then begin First:=UTF8Length(Copy(RenderedText,1,P-1)); Matches:=SelectionBounds(First,First+UTF8Length(Text)); end;
    end;
    for Match in Matches do begin
      N:=Length(Links); SetLength(Links,N+1); Links[N].Bounds:=Match; Links[N].Offset:=Offset; Links[N].Page:=-1;
      if WholeLine then begin Links[N].Bounds.Left:=0; Links[N].Bounds.Right:=1; end;
    end;
  end;
begin
  FreeAndNil(FNative);
  Source:=Text; Width:=Image.PreviewWidth; Height:=Image.PreviewHeight;
  FPNG:=Image.PNGData; FPicture.Clear; Links:=nil; RenderedText:=''; Characters:=nil;
  Surface.SetVector(Image.Surface.VectorDocument,Image.Surface.VectorPage);
  Surface.ContainsPictures:=Image.Surface.ContainsPictures;
  if Surface.VectorDocument<>nil then begin
    Characters:=Surface.VectorDocument.TextLayout(Surface.VectorPage,RenderedText);
    for Native in Surface.VectorDocument.PageLinks(Surface.VectorPage) do begin
      I:=Length(Links); SetLength(Links,I+1); Links[I].Bounds:=Native.Bounds; Links[I].Offset:=-1;
      Links[I].Page:=Native.Page; Links[I].URI:=Native.URI;
    end;
  end;
  if RenderedText='' then LoadTextLayout(LayoutXML,LayoutPage);
  if Context=nil then Exit;
  if Pos('\maketitle',Text)>0 then Exit;
  Doc:=TTeXDocument.Create;
  try
    if Pos('\tableofcontents',Text)>0 then begin
      Doc.ParseFile(Context.Source); Entries:=DocumentOutlineEntries(Doc.Blocks);
      for I:=0 to High(Entries) do if Entries[I].Group=0 then begin
        Caption:=Entries[I].Caption; P:=1;
        while P<=Length(Caption) do begin
          if Caption[P]<>'\' then begin Inc(P); Continue; end;
          A:=P; Command:=ReadTeXCommand(Caption,P);
          if (Command='label') or (Command='index') then ReadTeXGroup(Caption,P,'{','}');
          if Command='LaTeX' then Delete(Caption,A,1)
          else begin Delete(Caption,A,P-A); P:=A; end;
        end;
        Caption:=StringReplace(Caption,'~',' ',[rfReplaceAll]);
        Caption:=Trim(StringReplace(StringReplace(Caption,'{','',[rfReplaceAll]),'}','',[rfReplaceAll]));
        Link(Caption,Doc.SourceOffset(Entries[I].BlockIndex,Entries[I].Offset),True);
      end;
    end else begin
      { Keep the labels and order chosen by BibTeX/Biber, rather than listing
        database keys as if they were formatted bibliography entries. }
      P:=1; I:=0;
      while P<=Length(Context.GeneratedBibliography) do begin
        if Context.GeneratedBibliography[P]<>'\' then begin Inc(P); Continue; end;
        Command:=ReadTeXCommand(Context.GeneratedBibliography,P);
        if (Command<>'bibitem') and (Command<>'entry') then Continue;
        LabelText:=''; SkipTeXSpace(Context.GeneratedBibliography,P);
        if Copy(Context.GeneratedBibliography,P,1)='[' then LabelText:=ReadTeXGroup(Context.GeneratedBibliography,P,'[',']');
        Key:=ReadTeXGroup(Context.GeneratedBibliography,P,'{','}'); Inc(I);
        if LabelText='' then LabelText:=IntToStr(I);
        A:=CitationOffset(Key); Link('['+LabelText+']',A,True);
      end;
    end;
  finally Doc.Free; end;
end;
function TGeneratedPreview.Hit(X,Y:Double):Integer;
var I:Integer; R:TVectorImageBounds; Distance,Best,DX,DY:Double;
begin
  Result:=0; Best:=MaxDouble;
  for I:=0 to Min(High(Characters),UTF8Length(RenderedText)-1) do begin
    R:=Characters[I]; if (R.Right<=R.Left) or (R.Bottom<=R.Top) then Continue;
    DX:=Max(R.Left-X,Max(X-R.Right,0)); DY:=Max(R.Top-Y,Max(Y-R.Bottom,0)); Distance:=DY*DY*100+DX*DX;
    if Distance<Best then begin
      Best:=Distance; Result:=I; if X>(R.Left+R.Right)/2 then Inc(Result);
    end;
  end;
end;
function TGeneratedPreview.SelectedText(First,Last:Integer):string;
begin Result:=UTF8Copy(RenderedText,Min(First,Last)+1,Abs(Last-First)); end;
function TGeneratedPreview.SelectionBounds(First,Last:Integer):TVectorImageRegions;
var I,N,Swap:Integer; R:TVectorImageBounds;
begin
  Result:=nil; if First>Last then begin Swap:=First; First:=Last; Last:=Swap; end;
  for I:=Max(0,First) to Min(Last-1,High(Characters)) do begin
    R:=Characters[I]; if (R.Right<=R.Left) or (R.Bottom<=R.Top) then Continue;
    N:=Length(Result);
    if (N>0) and (Abs(Result[N-1].Top-R.Top)<0.003) and (Abs(Result[N-1].Bottom-R.Bottom)<0.003) then
      Result[N-1].Right:=Max(Result[N-1].Right,R.Right)
    else begin SetLength(Result,N+1); Result[N]:=R; end;
  end;
end;
procedure TGeneratedPreview.Draw(Canvas:TCanvas; const Bounds:TRect);
var Stream:TMemoryStream;
begin
  if IsNative then begin TNativeLayout(FNative).Draw(Canvas,Bounds.Left,Bounds.Top); Exit; end;
  if Surface.DrawVector(Canvas,Bounds) then Exit;
  if (FPicture.Width=0) and (FPNG<>'') then begin
    Stream:=TMemoryStream.Create;
    try Stream.WriteBuffer(FPNG[1],Length(FPNG)); Stream.Position:=0; FPicture.LoadFromStream(Stream);
    finally Stream.Free; end;
  end;
  Surface.Draw(Canvas,Bounds,FPicture);
end;
end.
