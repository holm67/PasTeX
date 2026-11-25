unit AboutForm;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes, Types, Forms, Controls, StdCtrls, ExtCtrls, ComCtrls, VectorArtwork, AppVersion;
type
  TAboutForm=class(TForm)
    TitleLabel,VersionLabel,DescriptionLabel,LicenseLabel:TLabel;
    CloseButton:TButton;
    ProgramLogo:TImage;
    Pages:TPageControl;
    AboutPage,InformationPage:TTabSheet;
    Information:TMemo;
    constructor Create(AOwner:TComponent); override;
  end;
implementation
uses ProgramInfo;
{$R *.lfm}
constructor TAboutForm.Create(AOwner:TComponent);
var Logo:TImage; LogoBounds:TRect;
begin
  inherited Create(AOwner);
  VersionLabel.Caption:='Version '+PasTeXVersion;
  { The designer control supplies DPI-scaled bounds; the vector control keeps
    an embedded PNG fallback on systems without the SVG libraries. }
  LogoBounds:=ProgramLogo.BoundsRect; ProgramLogo.Free;
  Logo:=TVectorLogo.Create(Self); Logo.Name:='ProgramLogo'; Logo.Parent:=AboutPage; Logo.BoundsRect:=LogoBounds;
  Logo.Anchors:=[akTop,akRight];
  ProgramLogo:=Logo;
  Logo.Proportional:=True; Logo.Center:=True; Logo.Stretch:=True;
  ProgramInformation(Information.Lines);
end;
end.
