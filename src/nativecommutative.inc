{ SPDX-License-Identifier: GPL-3.0-or-later }
function NativeCommutativeDiagram(const Context,Source,Directory:string; out Bytes:Int64; const Engine:string):IVectorDocument;
const Precision=32;
var Model:TCommutativeDiagram; Scene:TNativeDiagram; Tree,Diagram:TMathNode; Draft:TParagraphDraft;
    Measure:TBitmap;
  function FindDiagram(Node:TMathNode):TMathNode;
  var I:Integer;
  begin
    Result:=nil; if Node.Kind=mkDiagram then Exit(Node);
    for I:=0 to Node.Children.Count-1 do begin Result:=FindDiagram(TMathNode(Node.Children[I])); if Result<>nil then Exit; end;
  end;
  procedure Extract(Box:TDraftBox; X,Y:Integer);
  var I,J,K:Integer; Node:TMathNode; Field:TCommutativeField; Item:TPrimitive; Bounds:TRect; Code:string;
  begin
    Inc(X,Box.X); Inc(Y,Box.Y);
    if Box.Shape=23 then begin
      Item:=TPrimitive.Create; Item.Kind:=0; Item.Stroke:=Box.Color; Item.Fill:=Box.FillColor;
      Item.Closed:=Box.FillColor<>clNone; Item.Weight:=Max(0.25,Box.TextEm/Precision);
      if not Item.Closed then begin Item.Cap:=1; Item.Join:=1; end;
      SetLength(Item.Points,Length(Box.Lines));
      for I:=0 to High(Box.Lines) do begin
        Item.Points[I].X:=(X+Box.Lines[I].A.X)/Precision; Item.Points[I].Y:=(-Y-Box.Lines[I].A.Y)/Precision;
      end;
      Scene.Items.Add(Item); Inc(Bytes,TPrimitive.InstanceSize+Length(Item.Points)*SizeOf(TDiagramPoint)); Exit;
    end;
    if Box.Shape=9 then begin
      Item:=nil;
      for I:=0 to High(Box.Lines) do begin
        if (Item=nil) or (Item.Points[High(Item.Points)].X<>(X+Box.Lines[I].A.X)/Precision) or
          (Item.Points[High(Item.Points)].Y<>(-Y-Box.Lines[I].A.Y)/Precision) then begin
          Item:=TPrimitive.Create; Item.Kind:=0; Item.Stroke:=Box.Color; Item.Weight:=Max(0.25,Box.TextEm/Precision);
          Item.Cap:=1; Item.Join:=1; SetLength(Item.Points,1);
          Item.Points[0].X:=(X+Box.Lines[I].A.X)/Precision; Item.Points[0].Y:=(-Y-Box.Lines[I].A.Y)/Precision;
          Scene.Items.Add(Item); Inc(Bytes,TPrimitive.InstanceSize+SizeOf(TDiagramPoint));
        end;
        K:=Length(Item.Points); SetLength(Item.Points,K+1);
        Item.Points[K].X:=(X+Box.Lines[I].B.X)/Precision; Item.Points[K].Y:=(-Y-Box.Lines[I].B.Y)/Precision;
        Inc(Bytes,SizeOf(TDiagramPoint));
      end;
      Exit;
    end;
    if Box.ID>=0 then for J:=0 to Diagram.Children.Count-1 do begin
      Node:=TMathNode(Diagram.Children[J]);
      if (Node.ID<>Box.ID) or (Node.DiagramField<0) or (Node.DiagramField>=Length(Model.Fields)) then Continue;
      Field:=Model.Fields[Node.DiagramField]; Code:=Copy(Source,Field.First+1,Field.Last-Field.First);
      Item:=TPrimitive.Create; Scene.Items.Add(Item); Item.Kind:=2; Item.Text:='$'+Code+'$';
      if Field.Kind=cfLabel then Item.Text:='{\scriptsize '+Item.Text+'}';
      Item.Edit.Text:=Code; Item.Edit.First:=Field.First; Item.Edit.Last:=Field.Last; Item.Edit.MathLabel:=True;
      if (Model.PackageName='xy') and (Field.Kind=cfLabel) and
         ((Field.First=0) or (Source[Field.First]<>'{')) then begin
        Item.Edit.ReplacementPrefix:='{'; Item.Edit.ReplacementSuffix:='}';
      end;
      Item.Edit.Color:=clBlack;
      Item.LabelTree:=ParseParagraph(Item.Text,Scene.Macros); Bounds:=Scene.LayoutLabel(Item,Measure.Canvas,1);
      Item.LabelW:=Max(6,Bounds.Width); Item.LabelH:=Max(8,Bounds.Height);
      SetLength(Item.Points,1); Item.Points[0].X:=(X+Box.W/2)/Precision; Item.Points[0].Y:=(-Y-Box.H/2)/Precision;
      Inc(Bytes,TPrimitive.InstanceSize+4096+Length(Item.Text)*64); Exit;
    end;
    for I:=0 to Box.Children.Count-1 do Extract(TDraftBox(Box.Children[I]),X,Y);
  end;
begin
  Result:=nil; Bytes:=0; Model:=TCommutativeDiagram.Create; Scene:=nil; Tree:=nil;
  Draft:=TParagraphDraft.Create; Measure:=TBitmap.Create; Measure.SetSize(1,1);
  try
    if not Model.Load(Source) then Exit;
    Scene:=TNativeDiagram.Create; Scene.FontPoints:=DocumentFontPoints(Context);
    Scene.Macros:=TMacroRegistry.Create; Scene.Macros.Load(Context,Directory,Engine);
    Scene.ConfigureLabels(Context,Directory,Engine,Scene.Macros);
    Tree:=ParseParagraph(Source,Scene.Macros); Diagram:=FindDiagram(Tree); if Diagram=nil then Exit;
    Draft.Macros:=Scene.Macros; Draft.HeadingContext:=Context; Draft.Directory:=Directory;
    Draft.TeXEngine:=Engine; Draft.DocumentFontSize:=Scene.FontPoints; Draft.HideEditingMarks:=True;
    Draft.Layout(Measure.Canvas,Tree,2048*Precision,True,Scene.FontPoints*Precision,nil,Source,Precision,Scene.FontPoints*Precision*72/72.27);
    Extract(Draft.RootBox,0,0); Scene.Measure; Scene.UnitScale:=72/2.54;
    Result:=Scene; Scene:=nil;
  finally Scene.Free; Measure.Free; Draft.Free; Tree.Free; Model.Free; end;
end;
