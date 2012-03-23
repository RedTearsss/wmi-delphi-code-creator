{**************************************************************************************************}
{                                                                                                  }
{ Unit uWmiCSharpCode                                                                              }
{ Unit for the WMI Delphi Code Creator                                                             }
{                                                                                                  }
{ The contents of this file are subject to the Mozilla Public License Version 1.1 (the "License"); }
{ you may not use this file except in compliance with the License. You may obtain a copy of the    }
{ License at http://www.mozilla.org/MPL/                                                           }
{                                                                                                  }
{ Software distributed under the License is distributed on an "AS IS" basis, WITHOUT WARRANTY OF   }
{ ANY KIND, either express or implied. See the License for the specific language governing rights  }
{ and limitations under the License.                                                               }
{                                                                                                  }
{ The Original Code is uWmiCSharpCode.pas.                                                         }
{                                                                                                  }
{ The Initial Developer of the Original Code is Rodrigo Ruz V.                                     }
{ Portions created by Rodrigo Ruz V. are Copyright (C) 2011-2012 Rodrigo Ruz V.                    }
{ All Rights Reserved.                                                                             }
{                                                                                                  }
{**************************************************************************************************}

unit uWmiCSharpCode;

interface

uses
 uWmiGenCode,
 Classes;


type
  TCSharpWmiClassCodeGenerator=class(TWmiClassCodeGenerator)
  public
    procedure GenerateCode(Props: TStrings);override;
  end;

  TCSharpWmiEventCodeGenerator=class(TWmiEventCodeGenerator)
  public
    procedure GenerateCode(ParamsIn, Values, Conds, PropsOut: TStrings);override;
  end;

  TCSharpWmiMethodCodeGenerator=class(TWmiMethodCodeGenerator)
  private
    function GetWmiClassDescription: string;
  public
    procedure GenerateCode(ParamsIn, Values: TStrings);override;
  end;

implementation

uses
  uSelectCompilerVersion,
  StrUtils,
  IOUtils,
  ComObj,
  uWmi_Metadata,
  SysUtils;


const
  sTagCSharpCode          = '[CSHARPCODE]';
  sTagCSharpEventsWql     = '[CSHARPEVENTSWQL]';
  sTagCSharpEventsOut     = '[CSHARPEVENTSOUT]';
  sTagCSharpCodeParamsIn  = '[CSHARPCODEINPARAMS]';
  sTagCSharpCodeParamsOut = '[CSHARPCODEOUTPARAMS]';

function EscapeCSharpStr(const Value:string) : string;
const
 ArrChr       : Array [0..1] of Char = ('\','"');
 ArrChrEscape : Array [0..1] of Char = ('\','\');
Var
 i : integer;
begin
  Result:=Value;
  for i:= Low(ArrChr) to High(ArrChr) do
   Result:=StringReplace(Result,ArrChr[i],ArrChrEscape[i]+ArrChr[i], [rfReplaceAll]);
end;


{ TCSharpWmiClassCodeGenerator }

procedure TCSharpWmiClassCodeGenerator.GenerateCode(Props: TStrings);
var
  StrCode: string;
  Descr: string;
  DynCode: TStrings;
  i: integer;
  TemplateCode : string;
  Padding    : string;
begin
  Descr := GetWmiClassDescription;

  OutPutCode.BeginUpdate;
  DynCode    := TStringList.Create;
  try
    OutPutCode.Clear;
    StrCode := TFile.ReadAllText(GetTemplateLocation(ListSourceTemplates[Lng_CSharp]));

    StrCode := StringReplace(StrCode, sTagVersionApp, FileVersionStr, [rfReplaceAll]);
    StrCode := StringReplace(StrCode, sTagWmiClassName, WmiClass, [rfReplaceAll]);
    StrCode := StringReplace(StrCode, sTagWmiNameSpace,  EscapeCSharpStr(WmiNamespace), [rfReplaceAll]);
    StrCode := StringReplace(StrCode, sTagHelperTemplate, TemplateCode, [rfReplaceAll]);
    Padding:=StringOfChar(' ',20);
    if Props.Count > 0 then
      for i := 0 to Props.Count - 1 do
          DynCode.Add(Format(
            Padding+'Console.WriteLine("{0,-35} {1,-40}","%s",WmiObject["%s"]);// %s',
            [Props.Names[i], Props.Names[i], Props.ValueFromIndex[i]]));

    StrCode := StringReplace(StrCode, sTagCSharpCode, DynCode.Text, [rfReplaceAll]);
    StrCode := StringReplace(StrCode, sTagWmiClassDescr, Descr, [rfReplaceAll]);
    OutPutCode.Text := StrCode;
  finally
    OutPutCode.EndUpdate;
    DynCode.Free;
  end;
end;


{ TCSharpWmiEventCodeGenerator }

procedure TCSharpWmiEventCodeGenerator.GenerateCode(ParamsIn, Values, Conds,
  PropsOut: TStrings);
var
  StrCode: string;
  sValue:  string;
  Wql:     string;
  i, Len:  integer;
  Props:   TStrings;
  Padding : string;
begin
  Padding :=StringOfChar(' ',10);
  StrCode := TFile.ReadAllText(GetTemplateLocation(ListSourceTemplatesEvents[Lng_CSharp]));

  WQL := Format('Select * From %s Within %d ', [WmiClass, PollSeconds]);
  WQL := Format(Padding+StringOfChar(' ',6)+'WmiQuery ="%s"+%s', [WQL, sLineBreak]);

  if WmiTargetInstance <> '' then
  begin
    sValue := Format('"Where TargetInstance ISA %s "', [QuotedStr(WmiTargetInstance)]);
    WQL    := WQL + Padding+StringOfChar(' ',6) + sValue + '+' + sLineBreak;
  end;

  for i := 0 to Conds.Count - 1 do
  begin
    sValue := '';
    if (i > 0) or ((i = 0) and (WmiTargetInstance <> '')) then
      sValue := 'AND ';
    sValue := sValue + ' ' + ParamsIn.Names[i] + Conds[i] + Values[i] + ' ';
    WQL := WQL + StringOfChar(' ', 8) + QuotedStr(sValue) + '+' + sLineBreak;
  end;

  i := LastDelimiter('+', Wql);
  if i > 0 then
    Wql[i] := ';';


  Len   := GetMaxLengthItem(PropsOut) + 6;
  Props := TStringList.Create;
  try
    for i := 0 to PropsOut.Count - 1 do
     if StartsText(wbemTargetInstance,PropsOut[i]) then
      Props.Add(Format(Padding+'  Console.WriteLine("%-'+IntToStr(Len)+'s" + ((ManagementBaseObject)e.NewEvent.Properties["%s"].Value)["%s"]);',
      [PropsOut[i]+' : ',wbemTargetInstance, StringReplace(PropsOut[i],wbemTargetInstance+'.','',[rfReplaceAll])]))
     else
      Props.Add(Format(Padding+'  Console.WriteLine("%-'+IntToStr(Len)+'s" + e.NewEvent.Properties["%s"].Value.ToString());', [PropsOut[i]+' : ', PropsOut[i]]));

    StrCode := StringReplace(StrCode, sTagCSharpEventsOut, Props.Text, [rfReplaceAll]);
  finally
    props.Free;
  end;

  StrCode := StringReplace(StrCode, sTagVersionApp, FileVersionStr, [rfReplaceAll]);
  StrCode := StringReplace(StrCode, sTagCSharpEventsWql, WQL, [rfReplaceAll]);
  StrCode := StringReplace(StrCode, sTagWmiClassName, WmiClass, [rfReplaceAll]);
  StrCode := StringReplace(StrCode, sTagWmiNameSpace, EscapeCSharpStr(WmiNamespace), [rfReplaceAll]);
  OutPutCode.Text := StrCode;
end;


{ TCSharpWmiMethodCodeGenerator }

procedure TCSharpWmiMethodCodeGenerator.GenerateCode(ParamsIn,
  Values: TStrings);
var
  StrCode: string;
  Descr: string;
  DynCodeInParams: TStrings;
  DynCodeOutParams: TStrings;
  i: integer;

  IsStatic: boolean;
  TemplateCode : string;
  Padding : string;
begin
  Padding := stringofchar(' ', 14);
  Descr := GetWmiClassDescription;
  OutPutCode.BeginUpdate;
  DynCodeInParams := TStringList.Create;
  DynCodeOutParams := TStringList.Create;
  try
    IsStatic := WMiClassMetaData.MethodByName[WmiMethod].IsStatic;

    OutPutCode.Clear;
    if IsStatic then
    begin
      if UseHelperFunctions then
        TemplateCode := TFile.ReadAllText(GetTemplateLocation(sTemplateTemplateFuncts))
      else
        TemplateCode:='';

        StrCode := TFile.ReadAllText(GetTemplateLocation(
          ListSourceTemplatesStaticInvoker[Lng_CSharp]));
    end
    else
    begin

      if UseHelperFunctions then
        TemplateCode := TFile.ReadAllText(GetTemplateLocation(sTemplateTemplateFuncts))
      else
        TemplateCode:='';

        StrCode := TFile.ReadAllText(GetTemplateLocation(
          ListSourceTemplatesNonStaticInvoker[Lng_CSharp]));
    end;

    StrCode := StringReplace(StrCode, sTagVersionApp, FileVersionStr, [rfReplaceAll]);
    StrCode := StringReplace(StrCode, sTagWmiClassName, WmiClass, [rfReplaceAll]);
    StrCode := StringReplace(StrCode, sTagWmiNameSpace, EscapeCSharpStr(WmiNamespace), [rfReplaceAll]);
    StrCode := StringReplace(StrCode, sTagWmiMethodName, WmiMethod, [rfReplaceAll]);
    StrCode := StringReplace(StrCode, sTagWmiPath, EscapeCSharpStr(WmiPath), [rfReplaceAll]);
    StrCode := StringReplace(StrCode, sTagHelperTemplate, TemplateCode, [rfReplaceAll]);


    //In Params
    if ParamsIn.Count > 0 then
      for i := 0 to ParamsIn.Count - 1 do
        if Values[i] <> WbemEmptyParam then
          if ParamsIn.ValueFromIndex[i] = wbemtypeString then
            DynCodeInParams.Add(
              Format(Padding+'  inParams["%s"]="%s";', [ParamsIn.Names[i], Values[i]]))
          else
            DynCodeInParams.Add(
              Format(Padding+'  inParams["%s"]=%s;', [ParamsIn.Names[i], Values[i]]));
    StrCode := StringReplace(StrCode, sTagCSharpCodeParamsIn, DynCodeInParams.Text, [rfReplaceAll]);

    //Out Params
    if WMiClassMetaData.MethodByName[WmiMethod].OutParameters.Count > 1 then
    begin
      for i := 0 to WMiClassMetaData.MethodByName[WmiMethod].OutParameters.Count - 1 do
        DynCodeOutParams.Add(
          Format(Padding+'  Console.WriteLine("{0,-35} {1,-40}","%s",outParams["%s"]);',
          [WMiClassMetaData.MethodByName[WmiMethod].OutParameters[i].Name, WMiClassMetaData.MethodByName[WmiMethod].OutParameters[i].Name]));
    end
    else
    if WMiClassMetaData.MethodByName[WmiMethod].OutParameters.Count = 1 then
    begin
      DynCodeOutParams.Add(
        Format(Padding+'  Console.WriteLine("{0,-35} {1,-40}","Return Value",%s);',['outParams["ReturnValue"]']));
    end;

    StrCode := StringReplace(StrCode, sTagCSharpCodeParamsOut,
      DynCodeOutParams.Text, [rfReplaceAll]);

    StrCode := StringReplace(StrCode, sTagWmiMethodDescr, Descr, [rfReplaceAll]);
    OutPutCode.Text := StrCode;
  finally
    OutPutCode.EndUpdate;
    DynCodeInParams.Free;
    DynCodeOutParams.Free;
  end;
end;


function TCSharpWmiMethodCodeGenerator.GetWmiClassDescription: string;
var
  ClassDescr : TStringList;
  Index      : Integer;
begin
  ClassDescr:=TStringList.Create;
  try
    Result := WMiClassMetaData.MethodByName[WmiMethod].Description;

    if Pos(#10, Result) = 0 then //check if the description has format
      ClassDescr.Text := WrapText(Result, 80)
    else
      ClassDescr.Text := Result;//WrapText(Summary,sLineBreak,[#10],80);

    for Index := 0 to ClassDescr.Count - 1 do
      ClassDescr[Index] := Format('// %s', [ClassDescr[Index]]);

    Result:=ClassDescr.Text;
  finally
     ClassDescr.Free;
  end;
end;

end.