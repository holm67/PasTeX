unit TeXFontConfig;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses Classes;
type
  TDocumentFont=record
    Command,Family,Alias,Name,Options,Original:string;
    First,Last:Integer;
    Deleted,AppendFeatures:Boolean;
  end;
  TDocumentFonts=array of TDocumentFont;
  TFontFace=record
    Name,FileName,Features:string;
    Scale,WordSpace,SpaceStretch,SpaceShrink:Double;
    Bold,Italic,Hyphenate:Boolean;
  end;
function ReadDocumentFont(const Source:string; var Position:Integer; out Font:TDocumentFont):Boolean;
function DocumentFonts(const Source:string):TDocumentFonts;
function DocumentFontCode(const Font:TDocumentFont):string;
function NamedDocumentFont(const Command:string):Boolean;
function ReplaceDocumentFonts(const Source:string; const Fonts:TDocumentFonts):string;
function DocumentFontFace(const Fonts:TDocumentFonts; CJK:Boolean; const Family,Series,Shape,Directory:string):TFontFace;
implementation
uses SysUtils, Math, TeXMacros, TeXFontFeatures;
function NamedDocumentFont(const Command:string):Boolean;
begin
  case Command of
    'newCJKfontfamily','renewCJKfontfamily','newfontfamily','renewfontfamily',
    'setfontfamily','providefontfamily','newfontface','renewfontface','setfontface','providefontface':Result:=True;
    else Result:=False;
  end;
end;
function ReadDocumentFont(const Source:string; var Position:Integer; out Font:TDocumentFont):Boolean;
var P,A:Integer; Cmd,Extra:string;
begin
  Result:=False; Font:=Default(TDocumentFont); P:=Position;
  if (Copy(Source,P,4)<>'\set') and (Copy(Source,P,4)<>'\new') and
    (Copy(Source,P,6)<>'\renew') and (Copy(Source,P,8)<>'\provide') and (Copy(Source,P,8)<>'\default') then Exit;
  Cmd:=ReadTeXCommand(Source,P);
  if not ((Cmd='setmainfont') or (Cmd='setromanfont') or (Cmd='setsansfont') or (Cmd='setmonofont') or
    (Cmd='setCJKmainfont') or (Cmd='setCJKromanfont') or (Cmd='setCJKsansfont') or (Cmd='setCJKmonofont') or
    (Cmd='setCJKfamilyfont') or NamedDocumentFont(Cmd) or (Cmd='defaultfontfeatures') or
    (Cmd='defaultCJKfontfeatures')) then Exit;
  Font.Command:=Cmd;
  if Pos('default',Cmd)=1 then begin
    SkipTeXSpace(Source,P);
    if Cmd='defaultfontfeatures' then begin
      Font.AppendFeatures:=Copy(Source,P,1)='+'; if Font.AppendFeatures then Inc(P);
      Font.Family:=ReadTeXGroup(Source,P,'[',']');
    end;
    Font.Options:=ReadTeXGroup(Source,P,'{','}');
  end else begin
    Font.Family:='rm';
    if Pos('sans',Cmd)>0 then Font.Family:='sf' else if Pos('mono',Cmd)>0 then Font.Family:='tt';
    if Cmd='setCJKfamilyfont' then Font.Family:=ReadTeXGroup(Source,P,'{','}')
    else if NamedDocumentFont(Cmd) then begin
      if Pos('CJK',Cmd)>0 then Font.Family:=ReadTeXGroup(Source,P,'[',']') else Font.Family:='';
      SkipTeXSpace(Source,P);
      if Copy(Source,P,1)='{' then begin
        Extra:=ReadTeXGroup(Source,P,'{','}'); Font.Alias:=StringReplace(Extra,'\','',[]);
      end else Font.Alias:=ReadTeXCommand(Source,P);
      if Font.Family='' then Font.Family:=Font.Alias;
    end;
    Font.Options:=ReadTeXGroup(Source,P,'[',']'); Font.Name:=ReadTeXGroup(Source,P,'{','}');
    A:=P; SkipTeXSpace(Source,A);
    if Copy(Source,A,1)='[' then begin
      Extra:=ReadTeXGroup(Source,A,'[',']');
      if (Font.Options<>'') and (Extra<>'') then Font.Options:=Font.Options+',';
      Font.Options:=Font.Options+Extra; P:=A;
    end;
  end;
  Font.First:=Position; Font.Last:=P; Font.Original:=DocumentFontCode(Font);
  Position:=P; Result:=True;
end;
function DocumentFonts(const Source:string):TDocumentFonts;
var P,Q,N:Integer; Font:TDocumentFont;
begin
  Result:=nil; P:=1;
  while P<=Length(Source) do begin
    if Source[P]='%' then begin while (P<=Length(Source)) and (Source[P]<>#10) do Inc(P); Continue; end;
    if Source[P]<>'\' then begin Inc(P); Continue; end;
    if SkipTeXLiteral(Source,P) then Continue;
    Q:=P; if ReadTeXDefinition(Source,Q) then begin P:=Q; Continue; end;
    if ReadDocumentFont(Source,P,Font) then begin
      N:=Length(Result); SetLength(Result,N+1); Result[N]:=Font;
    end else ReadTeXCommand(Source,P);
  end;
end;
function DocumentFontCode(const Font:TDocumentFont):string;
begin
  Result:=''; if Font.Deleted or (Font.Command='') then Exit;
  if Pos('default',Font.Command)<>1 then begin
    if (Trim(Font.Name)='') or (NamedDocumentFont(Font.Command) and (Trim(Font.Alias)='')) or
      ((Font.Command='setCJKfamilyfont') and (Trim(Font.Family)='')) then Exit;
  end;
  Result:='\'+Font.Command;
  if Pos('default',Font.Command)=1 then begin
    if (Font.Command='defaultfontfeatures') and Font.AppendFeatures then Result:=Result+'+';
    if Font.Family<>'' then Result:=Result+'['+Font.Family+']';
    Exit(Result+'{'+Font.Options+'}');
  end;
  if Font.Command='setCJKfamilyfont' then Result:=Result+'{'+Font.Family+'}'
  else if NamedDocumentFont(Font.Command) then begin
    if (Pos('CJK',Font.Command)>0) and (Font.Family<>Font.Alias) and (Font.Family<>'') then
      Result:=Result+'['+Font.Family+']';
    Result:=Result+'{\'+Font.Alias+'}';
  end;
  if Font.Options<>'' then Result:=Result+'['+Font.Options+']';
  Result:=Result+'{'+Font.Name+'}';
end;
function ReplaceDocumentFonts(const Source:string; const Fonts:TDocumentFonts):string;
var Font:TDocumentFont; P:Integer; Code,Added:string;
begin
  Result:=''; Added:=''; P:=1;
  for Font in Fonts do begin
    Code:=DocumentFontCode(Font);
    if Font.First=0 then begin if Code<>'' then Added:=Added+Code+LineEnding; Continue; end;
    Result:=Result+Copy(Source,P,Font.First-P);
    if not Font.Deleted and (Code=Font.Original) then Result:=Result+Copy(Source,Font.First,Font.Last-Font.First) else Result:=Result+Code;
    P:=Font.Last;
  end;
  Result:=Result+Copy(Source,P,MaxInt);
  if Added<>'' then begin
    if (Result<>'') and not (Result[Length(Result)] in [#10,#13]) then Result:=Result+LineEnding;
    Result:=Result+Added;
  end;
end;
function DocumentFontFace(const Fonts:TDocumentFonts; CJK:Boolean; const Family,Series,Shape,Directory:string):TFontFace;
var Font,Selected:TDocumentFont; Defaults,CJKDefaults,Value,Base,Path,Ext,Face,Features,FeatureSource,Target:string;
    Options,NamedDefaults,FaceDefaults:TStringList; P,Q:Integer; Bold,Italic,ExplicitFace,DisabledFace:Boolean; F:TFormatSettings;
  function Unbrace(const S:string):string;
  var P:Integer;
  begin Result:=Trim(S); if Copy(Result,1,1)='{' then begin P:=1; Result:=ReadTeXGroup(Result,P,'{','}'); end; end;
  function TargetName(const S:string):string;
  var Ext:string;
  begin
    Result:=Unbrace(S); Ext:=LowerCase(ExtractFileExt(Result));
    if (Ext='.otf') or (Ext='.ttf') or (Ext='.ttc') then Result:=ChangeFileExt(Result,'');
  end;
  procedure AddOptions(const S:string);
  var P,Q,A:Integer; Spec,Key,Value:string;
  begin
    FeatureSource:=FeatureSource+','+S;
    P:=1;
    while P<=Length(S) do begin
      Q:=TopLevelDelimiter(S,',',P); if Q=0 then Q:=Length(S)+1;
      Spec:=Trim(Copy(S,P,Q-P)); P:=Q+1; A:=TopLevelDelimiter(Spec,'=');
      if A=0 then begin Key:=Spec; Value:='true'; end
      else begin Key:=Trim(Copy(Spec,1,A-1)); Value:=Unbrace(Copy(Spec,A+1,MaxInt)); end;
      if Key<>'' then Options.Values[Key]:=Value;
      if Key='Scale' then Result.Scale:=StrToFloatDef(Value,1,F)
      else if Key='ScaleAgain' then Result.Scale:=Result.Scale*StrToFloatDef(Value,1,F);
    end;
  end;
begin
  Result:=Default(TFontFace); Result.Scale:=1; Result.WordSpace:=1; Result.SpaceStretch:=1; Result.SpaceShrink:=1;
  Result.Hyphenate:=True; F:=DefaultFormatSettings; F.DecimalSeparator:='.';
  Selected:=Default(TDocumentFont); Defaults:=''; CJKDefaults:='';
  Options:=TStringList.Create; NamedDefaults:=TStringList.Create; FaceDefaults:=TStringList.Create;
  try
    NamedDefaults.CaseSensitive:=True; NamedDefaults.NameValueSeparator:=#1;
    for Font in Fonts do begin
      if Font.Deleted then Continue;
      if Font.Command='defaultCJKfontfeatures' then begin CJKDefaults:=Font.Options; Continue; end;
      if Font.Command='defaultfontfeatures' then begin
        if Font.Family='' then begin
          if Font.AppendFeatures then Defaults:=Defaults+','+Font.Options else Defaults:=Font.Options;
        end else begin
          P:=1;
          while P<=Length(Font.Family) do begin
            Q:=TopLevelDelimiter(Font.Family,',',P); if Q=0 then Q:=Length(Font.Family)+1;
            Target:=TargetName(Copy(Font.Family,P,Q-P)); P:=Q+1; if Target='' then Continue;
            if Font.AppendFeatures then NamedDefaults.Values[Target]:=NamedDefaults.Values[Target]+','+Font.Options
            else NamedDefaults.Values[Target]:=Font.Options;
          end;
        end;
        Continue;
      end;
      if ((Pos('CJK',Font.Command)>0)<>CJK) or (Trim(Font.Family)<>Family) then Continue;
      if (Pos('provide',Font.Command)=1) and (Selected.Name<>'') then Continue;
      Selected:=Font; Target:='';
      if not CJK then begin
        if Font.Alias<>'' then Target:='\'+Font.Alias
        else if (Family='rm') or (Family='sf') or (Family='tt') then Target:='\'+Family+'family';
      end;
      { fontspec-xetex: global, family, font defaults, then explicit options.
        Capture these when the family is defined, not at its later use. }
      Selected.Options:=Defaults+','+NamedDefaults.Values[Target]+','+NamedDefaults.Values[TargetName(Font.Name)];
      if CJK then Selected.Options:=Selected.Options+','+CJKDefaults;
      if Pos('fontface',Font.Command)>0 then Selected.Options:=Selected.Options+',BoldFont={},ItalicFont={},SmallCapsFont={}';
      Selected.Options:=Selected.Options+','+Font.Options;
      FaceDefaults.Assign(NamedDefaults); FaceDefaults.NameValueSeparator:=#1; FaceDefaults.CaseSensitive:=True;
    end;
    if Trim(Selected.Name)='' then Exit;
    FeatureSource:=''; Options.CaseSensitive:=True; AddOptions(Selected.Options);
    Bold:=(Series='b') or (Series='bx'); Italic:=(Shape='it') or (Shape='sl') or (Shape='scit') or (Shape='scsl');
    Face:='Upright';
    if Bold and Italic then Face:='BoldItalic' else if Bold then Face:='Bold' else if Italic then Face:='Italic';
    if Shape='sc' then begin Face:='SmallCaps'; if Bold then Face:='BoldSmallCaps'; end;
    if (Shape='scit') or (Shape='scsl') then begin
      Face:='ItalicSmallCaps'; if Bold then Face:='BoldItalicSmallCaps';
    end;
    Value:=Options.Values[Face+'Font'];
    DisabledFace:=(Value='') and (Options.IndexOfName(Face+'Font')>=0);
    if (Face='BoldItalic') and ((Options.IndexOfName('BoldFont')>=0) and (Options.Values['BoldFont']='') or
      (Options.IndexOfName('ItalicFont')>=0) and (Options.Values['ItalicFont']='')) then DisabledFace:=True;
    if DisabledFace then begin
      Face:='Upright'; Value:=Options.Values['UprightFont']; Bold:=False; Italic:=False;
    end;
    if (Value='') and (Face<>'Upright') and CJK then begin
      if Bold then begin Face:='Bold'; Value:=Options.Values['BoldFont']; end;
      if Value='' then begin Face:='Upright'; Value:=Options.Values['UprightFont']; end;
    end;
    ExplicitFace:=Value<>'';
    Base:=Trim(Selected.Name); if Value='' then Value:=Base;
    Value:=StringReplace(Value,'*',Base,[rfReplaceAll]);
    Features:=Options.Values[Face+'Features']; Target:=TargetName(Value);
    if not ExplicitFace and not DisabledFace then
      case Face of 'Bold':Target:=Target+'/B'; 'Italic':Target:=Target+'/I'; 'BoldItalic':Target:=Target+'/BI'; end;
    { fontspec loads the chosen face's defaults once more while declaring
      its NFSS shape, before that shape's explicit Upright/Bold/etc. features. }
    AddOptions(FaceDefaults.Values[Target]); AddOptions(Features);
    Path:=Options.Values['Path']; Ext:=Options.Values['Extension'];
    if (Ext<>'') and (ExtractFileExt(Value)='') then Value:=Value+Ext;
    if Path<>'' then Value:=IncludeTrailingPathDelimiter(Path)+Value;
    if (Directory<>'') and (ExtractFileDrive(Value)='') and (Copy(Value,1,1)<>'/') and
      ((Path<>'') or FileExists(IncludeTrailingPathDelimiter(Directory)+Value)) then
      Value:=ExpandFileName(IncludeTrailingPathDelimiter(Directory)+Value);
    Result.Name:=Value;
    Result.Bold:=Bold and not ExplicitFace and (ExtractFileExt(Value)='');
    Result.Italic:=Italic and not ExplicitFace and (ExtractFileExt(Value)='');
    Result.Scale:=EnsureRange(Result.Scale,0.1,10);
    Value:=Options.Values['WordSpace']; P:=Pos(',',Value);
    if P=0 then begin
      Result.WordSpace:=Max(0,StrToFloatDef(Value,1,F));
      Result.SpaceStretch:=Result.WordSpace; Result.SpaceShrink:=Result.WordSpace;
    end else begin
      Result.WordSpace:=Max(0,StrToFloatDef(Trim(Copy(Value,1,P-1)),1,F));
      Delete(Value,1,P); P:=Pos(',',Value); if P=0 then P:=Length(Value)+1;
      Result.SpaceStretch:=Max(0,StrToFloatDef(Trim(Copy(Value,1,P-1)),1,F));
      Result.SpaceShrink:=Max(0,StrToFloatDef(Trim(Copy(Value,P+1,MaxInt)),1,F));
    end;
    Result.Hyphenate:=Options.Values['HyphenChar']<>'None';
    if Pos('SmallCaps',Face)>0 then FeatureSource:=FeatureSource+',Letters=SmallCaps';
    Result.Features:=NativeFontFeatures(FeatureSource,Directory);
  finally FaceDefaults.Free; NamedDefaults.Free; Options.Free; end;
end;
end.
