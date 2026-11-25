unit ImportForms;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, SysUtils, Forms, Controls, StdCtrls, ExtCtrls, Grids,
  ToolJobs, SpreadsheetData;
type
  TToolStatusEvent=procedure(const Title:string; Running:Boolean) of object;
  TSpreadsheetForm=class(TForm)
  private
    FBook:TDataWorkbook;
    procedure SheetChanged(Sender:TObject);
    procedure Accept(Sender:TObject);
  public
    Sheet:TComboBox;
    RangeEdit:TEdit;
    Header,Borders:TCheckBox;
    Grid:TStringGrid;
    constructor Create(AOwner:TComponent); override;
    procedure Load(const FileName:string);
    function TableSource:string;
    destructor Destroy; override;
  end;
function RunToolJob(Owner:TComponent; Job:TToolJob; const Title:string):Boolean;
function ToolJobBusy:Boolean;
function ToolJobCancelled:Boolean;
procedure CancelToolJob;
var OnToolStatus:TToolStatusEvent;
implementation
uses Math, Dialogs, UITheme;
var ActiveJob:TToolJob; WasCancelled:Boolean;
function Bar(Owner:TComponent; Parent:TWinControl; Align:TAlign; Height:Integer):TPanel;
begin Result:=TPanel.Create(Owner); Result.Parent:=Parent; Result.Align:=Align; Result.Height:=Height; Result.BevelOuter:=bvNone; Result.BorderSpacing.Around:=6; end;
function Button(Owner:TComponent; Parent:TWinControl; const Caption:string; Event:TNotifyEvent; ResultCode:Integer=0):TButton;
begin
  Result:=TButton.Create(Owner); Result.Parent:=Parent; Result.Caption:=Caption; Result.Align:=alLeft; Result.Width:=140;
  Result.BorderSpacing.Right:=6; Result.OnClick:=Event; Result.ModalResult:=ResultCode;
end;
function ToolJobBusy:Boolean;
begin Result:=ActiveJob<>nil; end;
function ToolJobCancelled:Boolean;
begin Result:=WasCancelled; end;
procedure CancelToolJob;
begin if ActiveJob<>nil then begin WasCancelled:=True; ActiveJob.Terminate; end; end;
function RunToolJob(Owner:TComponent; Job:TToolJob; const Title:string):Boolean;
var Message:string;
begin
  if ActiveJob<>nil then raise Exception.Create('Another external tool is already running.');
  ActiveJob:=Job; WasCancelled:=False;
  try
    if Assigned(OnToolStatus) then OnToolStatus(Title+' · running…',True);
    Job.Start;
    while not Job.Finished do begin
      Application.ProcessMessages; if Application.Terminated then CancelToolJob; Sleep(10);
    end;
    Job.WaitFor; Result:=not WasCancelled and (Job.ErrorText='');
  finally
    if not Job.Finished then begin Job.Terminate; Job.WaitFor; end;
    ActiveJob:=nil; Message:=Title+' · finished';
    if WasCancelled then Message:=Title+' · cancelled' else if Job.ErrorText<>'' then Message:=Title+' · '+Job.ErrorText;
    if Assigned(OnToolStatus) then OnToolStatus(Message,False);
  end;
end;
constructor TSpreadsheetForm.Create(AOwner:TComponent);
var HeaderPane,Footer:TPanel; L:TLabel;
begin
  inherited CreateNew(AOwner); Caption:='Import spreadsheet'; Position:=poOwnerFormCenter;
  ClientWidth:=850; ClientHeight:=520; Constraints.MinWidth:=620; Constraints.MinHeight:=420;
  FBook:=TDataWorkbook.Create(True); HeaderPane:=Bar(Self,Self,alTop,76);
  L:=TLabel.Create(Self); L.Parent:=HeaderPane; L.Caption:='Worksheet'; L.SetBounds(4,3,120,20);
  Sheet:=TComboBox.Create(Self); Sheet.Parent:=HeaderPane; Sheet.Style:=csDropDownList; Sheet.SetBounds(4,25,240,30); Sheet.OnChange:=@SheetChanged;
  L:=TLabel.Create(Self); L.Parent:=HeaderPane; L.Caption:='Range (blank = used cells)'; L.SetBounds(260,3,230,20);
  RangeEdit:=TEdit.Create(Self); RangeEdit.Parent:=HeaderPane; RangeEdit.SetBounds(260,25,220,30); RangeEdit.TextHint:='A1:D20';
  Footer:=Bar(Self,Self,alBottom,70);
  Header:=TCheckBox.Create(Self); Header.Parent:=Footer; Header.Caption:='First row is a header'; Header.SetBounds(4,1,225,24); Header.Checked:=True;
  Borders:=TCheckBox.Create(Self); Borders.Parent:=Footer; Borders.Caption:='Table borders'; Borders.SetBounds(240,1,200,24); Borders.Checked:=True;
  HeaderPane:=Bar(Self,Footer,alBottom,32); Button(Self,HeaderPane,'Insert table',@Accept); Button(Self,HeaderPane,'Cancel',nil,mrCancel);
  Grid:=TStringGrid.Create(Self); Grid.Parent:=Self; Grid.Align:=alClient; Grid.FixedCols:=0; Grid.FixedRows:=0; Grid.Options:=[goHorzLine,goVertLine,goRangeSelect];
  ApplyTheme(Self);
end;
destructor TSpreadsheetForm.Destroy;
begin FBook.Free; inherited; end;
procedure TSpreadsheetForm.Load(const FileName:string);
var I:Integer;
begin FBook.Load(FileName); Sheet.Items.Clear; for I:=0 to FBook.Count-1 do Sheet.Items.Add(TDataSheet(FBook[I]).Name); Sheet.ItemIndex:=0; SheetChanged(nil); end;
procedure TSpreadsheetForm.SheetChanged(Sender:TObject);
var S:TDataSheet; R,C:Integer;
begin
  if Sheet.ItemIndex<0 then Exit; S:=TDataSheet(FBook[Sheet.ItemIndex]); Grid.BeginUpdate;
  try Grid.RowCount:=Max(1,Min(S.RowCount,300)); Grid.ColCount:=Max(1,Min(S.Columns,64));
    for R:=0 to Grid.RowCount-1 do for C:=0 to Grid.ColCount-1 do Grid.Cells[C,R]:=S.Cell(R,C);
  finally Grid.EndUpdate; end;
  Caption:='Import spreadsheet — '+IntToStr(S.RowCount)+' rows × '+IntToStr(S.Columns)+' columns (preview up to 300 × 64)';
end;
function TSpreadsheetForm.TableSource:string;
var S:TDataSheet; T,L,B,R:Integer;
begin
  if Sheet.ItemIndex<0 then Exit(''); S:=TDataSheet(FBook[Sheet.ItemIndex]); T:=0; L:=0; B:=S.RowCount-1; R:=S.Columns-1;
  if (Trim(RangeEdit.Text)<>'') and not DataRange(RangeEdit.Text,T,L,B,R) then raise Exception.Create('Use a range such as A1:D20');
  Result:=S.TeX(T,L,B,R,Header.Checked,Borders.Checked);
end;
procedure TSpreadsheetForm.Accept(Sender:TObject);
begin try if TableSource='' then raise Exception.Create('The worksheet is empty'); ModalResult:=mrOK;
  except on E:Exception do MessageDlg(E.Message,mtError,[mbOK],0); end; end;
end.
