unit VectorArtwork;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Types, Graphics, ExtCtrls, LResources, VectorPreview, PreviewImage;
type
  TVectorArtwork=class
  private
    FSource:string; FPicture:TPicture; FSurface:TPreviewSurface;
  public
    constructor Create(const ResourceName:string; PreserveColors:Boolean=False);
    destructor Destroy; override;
    function Draw(Canvas:TCanvas; const Bounds:TRect):Boolean;
  end;
  TVectorLogo=class(TImage)
  private FArtwork:TVectorArtwork; FFallback:TPreviewSurface; FUseVector:Boolean;
  protected procedure Paint; override;
  public
    constructor Create(AOwner:TComponent); override;
    destructor Destroy; override;
    property UseVector:Boolean read FUseVector write FUseVector;
  end;
implementation
constructor TVectorArtwork.Create(const ResourceName:string; PreserveColors:Boolean);
var R:TLResource;
begin
  inherited Create; FPicture:=TPicture.Create; FSurface:=TPreviewSurface.Create;
  FSurface.PreserveColors:=PreserveColors; R:=LazarusResources.Find(ResourceName);
  if R<>nil then FSource:=R.Value;
end;
destructor TVectorArtwork.Destroy;
begin FSurface.Free; FPicture.Free; inherited Destroy; end;
function TVectorArtwork.Draw(Canvas:TCanvas; const Bounds:TRect):Boolean;
begin
  Result:=True;
  if (FPicture.Width<>Bounds.Width) or (FPicture.Height<>Bounds.Height) then begin
    FSurface.Clear; Result:=RenderSVG(FSource,Bounds.Width,Bounds.Height,FPicture);
  end;
  if Result then FSurface.Draw(Canvas,Bounds,FPicture);
end;
constructor TVectorLogo.Create(AOwner:TComponent);
begin
  inherited Create(AOwner); FArtwork:=TVectorArtwork.Create('pastex-vector',True); FUseVector:=True;
  FFallback:=TPreviewSurface.Create; FFallback.PreserveColors:=True;
  Picture.LoadFromLazarusResource('pastex-logo-png');
end;
destructor TVectorLogo.Destroy;
begin FFallback.Free; FArtwork.Free; inherited Destroy; end;
procedure TVectorLogo.Paint;
begin
  { Do not change Picture while painting: TImage invalidates on each change. }
  if not FUseVector or not FArtwork.Draw(Canvas,ClientRect) then FFallback.Draw(Canvas,ClientRect,Picture);
end;
initialization
{$I vectorartwork.lrs}
{$I programlogo.lrs}
end.
