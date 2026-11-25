unit NativeGenerated;
{ SPDX-License-Identifier: GPL-3.0-or-later }
{$mode objfpc}{$H+}
interface
uses TeXContext;
type
  TGeneratedRow=record
    Text,LabelText,Page:string;
    Indent:Double;
    Offset:Integer;
    Bold,Title,Leaders:Boolean;
  end;
  TGeneratedRows=array of TGeneratedRow;
function NativeGeneratedRows(const Command,Source,Directory:string; Context:TTeXContext):TGeneratedRows;
implementation
uses Classes, SysUtils, Math, TeXMacros, TeXStyles, TeXDocument, BibliographyData, TeXBibliography;
function NativeGeneratedRows(const Command,Source,Directory:string; Context:TTeXContext):TGeneratedRows;
var P,Q,A,Depth,TocDepth,Level,N:Integer; Cmd,Name,ShortTitle,Title,Text,Options,Wanted,Extension:string;
    Starred,Chapters,NoHeading,HasShortTitle:Boolean; Styles:TTeXStyles; Mark:TContextMark; Item:TBibliographyItem;
  procedure Add(const Text,LabelText,Page:string; Offset:Integer; Indent:Double; Bold,Title,Leaders:Boolean);
  var I:Integer;
  begin
    I:=Length(Result); SetLength(Result,I+1); Result[I].Text:=Text; Result[I].LabelText:=LabelText;
    Result[I].Page:=Page; Result[I].Offset:=Offset; Result[I].Indent:=Indent;
    Result[I].Bold:=Bold; Result[I].Title:=Title; Result[I].Leaders:=Leaders;
  end;
  function NextCommand(out Command:string; out Offset:Integer):Boolean;
  var After:Integer;
  begin
    Result:=False;
    while P<=Length(Context.Source) do begin
      if Context.Source[P]='%' then begin while (P<=Length(Context.Source)) and (Context.Source[P]<>#10) do Inc(P); Continue; end;
      if Context.Source[P]<>'\' then begin Inc(P); Continue; end;
      After:=P;
      if ReadTeXDefinition(Context.Source,After) or SkipTeXLiteral(Context.Source,After) then begin P:=After; Continue; end;
      Offset:=P-1; Command:=ReadTeXCommand(Context.Source,P); Exit(True);
    end;
  end;
begin
  Result:=nil; if Context=nil then Exit; Styles:=TTeXStyles.Create;
  try
    Styles.Load(Context.Source,Directory); Chapters:=Styles.HasChapters;
    if Chapters then Name:='chapter' else Name:='section';
    if Command='tableofcontents' then begin
      Add('\'+Name+'*{'+Styles.Name('contentsname','Contents')+'}','','',-1,0,False,True,False);
      if Chapters then TocDepth:=2 else TocDepth:=3;
      TocDepth:=TeXCounterSetting(Context.Source,'tocdepth',TocDepth);
      P:=TeXHeaderLength(Context.Source)+1;
      while NextCommand(Cmd,A) do begin
        Level:=HeadingIndex(Cmd); Starred:=Copy(Context.Source,P,1)='*'; if Starred then Inc(P);
        if Level>=0 then begin
          SkipTeXSpace(Context.Source,P); HasShortTitle:=Copy(Context.Source,P,1)='[';
          if HasShortTitle then ShortTitle:=ReadTeXGroup(Context.Source,P,'[',']');
          Title:=ReadTeXGroup(Context.Source,P,'{','}'); if HasShortTitle then Title:=ShortTitle;
          if Starred or (Level-1>TocDepth) then Continue;
          Mark:=Context.Mark(A); Text:=''; if Mark<>nil then Text:=Mark.Number;
          Depth:=Level-2; if Chapters then Inc(Depth); Depth:=Max(0,Depth);
          case Depth of 0:Q:=0; 1:Q:=15; 2:Q:=38; 3:Q:=70; else Q:=100; end;
          Add(ReferenceTitle(Title),Text,Context.NativePageNumber(A),A,Q/10,Level<=2-Ord(Chapters),False,Level>2-Ord(Chapters));
        end else if Cmd='addcontentsline' then begin
          Text:=ReadTeXGroup(Context.Source,P,'{','}'); Name:=ReadTeXGroup(Context.Source,P,'{','}'); Title:=ReadTeXGroup(Context.Source,P,'{','}');
          if Text='toc' then Add(Title,'',Context.NativePageNumber(A),A,Max(0,HeadingIndex(Name)-2+Ord(Chapters))*1.5,False,False,True);
        end;
      end;
    end else if (Command='listoffigures') or (Command='listoftables') then begin
      if Command='listoffigures' then begin Wanted:='figure'; Extension:='lof'; Title:=Styles.Name('listfigurename','List of Figures'); end
      else begin Wanted:='table'; Extension:='lot'; Title:=Styles.Name('listtablename','List of Tables'); end;
      Add('\'+Name+'*{'+Title+'}','','',-1,0,False,True,False);
      P:=TeXHeaderLength(Context.Source)+1;
      while NextCommand(Cmd,A) do begin
        if Cmd='caption' then begin
          Starred:=Copy(Context.Source,P,1)='*'; if Starred then Inc(P);
          SkipTeXSpace(Context.Source,P); HasShortTitle:=Copy(Context.Source,P,1)='[';
          if HasShortTitle then ShortTitle:=ReadTeXGroup(Context.Source,P,'[',']');
          Title:=ReadTeXGroup(Context.Source,P,'{','}'); if HasShortTitle then Title:=ShortTitle;
          Mark:=Context.Mark(A);
          if Starred or (Mark=nil) or (Mark.Counter<>Wanted) then Continue;
          Add(ReferenceTitle(Title),Mark.Number,Context.NativePageNumber(A),A,1.5,False,False,True);
        end else if Cmd='addcontentsline' then begin
          Text:=ReadTeXGroup(Context.Source,P,'{','}'); Name:=ReadTeXGroup(Context.Source,P,'{','}'); Title:=ReadTeXGroup(Context.Source,P,'{','}');
          if Text=Extension then Add(ReferenceTitle(Title),'',Context.NativePageNumber(A),A,1.5,False,False,True);
        end;
      end;
    end else begin
      P:=1; Title:=''; NoHeading:=False;
      while P<=Length(Source) do begin
        if Source[P]<>'\' then begin Inc(P); Continue; end;
        Cmd:=ReadTeXCommand(Source,P);
        if (Cmd='printbibliography') or (Cmd='printbibliogrphy') then begin
          Options:=ReadTeXGroup(Source,P,'[',']');
          { Split only at top-level commas; titles may themselves contain commas. }
          Q:=1;
          while Q<=Length(Options) do begin
            A:=Q; Depth:=0;
            while Q<=Length(Options) do begin
              if Options[Q]='{' then Inc(Depth) else if Options[Q]='}' then Dec(Depth);
              if (Depth=0) and (Options[Q]=',') then Break; Inc(Q);
            end;
            Text:=Trim(Copy(Options,A,Q-A)); Inc(Q); N:=Pos('=',Text);
            if N=0 then Continue; Cmd:=Trim(Copy(Text,1,N-1)); Text:=Trim(Copy(Text,N+1,MaxInt));
            if (Copy(Text,1,1)='{') and (Copy(Text,Length(Text),1)='}') then Text:=Copy(Text,2,Length(Text)-2);
            if Cmd='title' then Title:=Text; if (Cmd='heading') and (Text='none') then NoHeading:=True;
          end;
        end;
      end;
      if Title='' then begin if Chapters then Title:=Styles.Name('bibname','Bibliography') else Title:=Styles.Name('refname','References'); end;
      if not NoHeading then Add('\'+Name+'*{'+Title+'}','','',-1,0,False,True,False);
      for Item in Context.Bibliography.FormattedItems do Add(Item.Text,Item.LabelText,'',-1,0,False,False,False);
    end;
  finally Styles.Free; end;
end;
end.
