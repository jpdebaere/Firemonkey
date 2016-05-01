//---------------------------------------------------------------------------
// Copyright (c) 2016 Embarcadero Technologies, Inc. All rights reserved.  
//
// This software is the copyrighted property of Embarcadero Technologies, Inc. 
// ("Embarcadero") and its licensors. You may only use this software if you 
// are an authorized licensee of Delphi, C++Builder or RAD Studio 
// (the "Embarcadero Products").  This software is subject to Embarcadero's 
// standard software license and support agreement that accompanied your 
// purchase of the Embarcadero Products and is considered a Redistributable, 
// as such term is defined thereunder. Your use of this software constitutes 
// your acknowledgement of your agreement to the foregoing software license 
// and support agreement. 
//---------------------------------------------------------------------------
unit StreamingDeviceFrameU;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants, 
  FMX.Types, FMX.Graphics, FMX.Controls, FMX.Forms, FMX.Dialogs, FMX.StdCtrls,
  System.Actions, FMX.ActnList, FMX.Controls.Presentation, FMX.ScrollBox,
  FMX.Memo, FMX.Layouts, System.JSON, Iot.Family.BluetoothLE,
  Iot.Family.BluetoothLE.GattTypes, Iot.Device.GenericHeartRateMonitor, FMX.Edit;

type
  TStreamingDeviceFrame = class(TFrame)
    ButtonStartStop: TButton;
    ActionList1: TActionList;
    ActionStartStop: TAction;
    Memo1: TMemo;
    Layout1: TLayout;
    Layout2: TLayout;
    Layout3: TLayout;
    Layout4: TLayout;
    ButtonClear: TButton;
    BLEManager: TBluetoothDeviceDiscoveryManager;
    ButtonConnect: TButton;
    edDeviceName: TEdit;
    GenericHRM: TGenericHeartRateMonitor;
    procedure ActionStartStopExecute(Sender: TObject);
    procedure ActionStartStopUpdate(Sender: TObject);
    procedure ButtonClearClick(Sender: TObject);
    procedure ButtonConnectClick(Sender: TObject);
    procedure GenericHRMDeviceDisconnect(
      const Sender: TCustomGeneratedBluetoothLEComponent);
    procedure GenericHRMDeviceConnected;
    procedure GenericHRMHeartRateMeasurementUpdate(Sender: TObject;
      const [Ref] Value: TGattHeartRateMeasurement);
    procedure BLEManagerGeneralDiscoveryError(const Sender: TObject;
      const AException: Exception; var Handled: Boolean);
  public type
    TNextValueCallback = reference to procedure(const Value: TJSONObject);
  private
    FValue: TJSONObject;
    FTime: TDateTime;
    FOnChanged: TNotifyEvent;
    FNextValueCallback: TNextValueCallback;
    FOnClear: TNotifyEvent;
    FStarted: Boolean;
    procedure SetStarted(const Value: Boolean);
    function GetStarted: Boolean;
    procedure DoClear;
    { Private declarations }
  protected
    procedure DoChanged; virtual;
    procedure DoNextValue; virtual;
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    procedure ClearLog;
    procedure Start;
    procedure Stop;
    procedure LogValue;
    property Value: TJSONObject read FValue;
    property Time: TDateTime read FTime;
    property Started: Boolean read GetStarted write SetStarted;
    property OnChanged: TNotifyEvent read FOnChanged write FOnChanged;
    property OnClear: TNotifyEvent read FOnClear write FOnClear;
//    property OnNextValue: TNextValueCallback write FNextValueCallback;
  end;

implementation

{$R *.fmx}

procedure TStreamingDeviceFrame.ActionStartStopExecute(Sender: TObject);
begin
  if Started then
    Stop
  else
    Start;
end;

procedure TStreamingDeviceFrame.ActionStartStopUpdate(Sender: TObject);
begin
  if Started then
    TAction(Sender).Text := 'Stop'
  else
    TAction(Sender).Text := 'Start'
end;

procedure TStreamingDeviceFrame.BLEManagerGeneralDiscoveryError(
  const Sender: TObject; const AException: Exception; var Handled: Boolean);
begin
  Memo1.Lines.Insert(0, Format('[%s] %s', [FormatDateTime('mm:ss:zzz', now), 'ERROR discovering devices']));
end;

procedure TStreamingDeviceFrame.ButtonClearClick(Sender: TObject);
begin
  DoClear;
end;

procedure TStreamingDeviceFrame.ClearLog;
begin
  Memo1.Lines.Clear;
end;

procedure TStreamingDeviceFrame.ButtonConnectClick(Sender: TObject);
begin
  GenericHRM.DeviceName := edDeviceName.Text;
  {$IF Defined(WIN32) or Defined(WIN64)}
  BLEManager.DiscoveryMethod := TDiscoveryMethod.Connect;
  {$ELSE}
  BLEManager.DiscoveryMethod := TDiscoveryMethod.ScanResponse;
  {$EndIf}
  BLEManager.DiscoverDevices;
end;

procedure TStreamingDeviceFrame.DoClear;
begin
  if Assigned(FOnClear) then
    FOnClear(Self);
end;

constructor TStreamingDeviceFrame.Create(AOwner: TComponent);
begin
  inherited;
  FValue := TJSONObject.Create;
end;

destructor TStreamingDeviceFrame.Destroy;
begin
  FValue.Free;
  inherited;
end;

procedure TStreamingDeviceFrame.DoChanged;
begin
  if Assigned(FOnChanged) then
    FOnChanged(Self);
end;

procedure TStreamingDeviceFrame.DoNextValue;
begin
  if Assigned(Self.FNextValueCallback) then
  begin
    while FValue.Count > 0 do
      FValue.RemovePair(FValue.Pairs[0].JsonString.Value);
    FNextValueCallback(FValue);
  end;
end;

procedure TStreamingDeviceFrame.GenericHRMDeviceDisconnect(
  const Sender: TCustomGeneratedBluetoothLEComponent);
begin
  ActionStartStop.Enabled := false;
  Stop;
  Memo1.Lines.Insert(0, Format('[%s] %s', [FormatDateTime('mm:ss:zzz', now), 'HRM disconnected']));
end;

procedure TStreamingDeviceFrame.GenericHRMDeviceConnected;
begin
  ActionStartStop.Enabled := true;
  Memo1.Lines.Insert(0, Format('[%s] %s', [FormatDateTime('mm:ss:zzz', now), 'HRM found']));
end;

procedure TStreamingDeviceFrame.GenericHRMHeartRateMeasurementUpdate(
  Sender: TObject; const [Ref] Value: TGattHeartRateMeasurement);
begin
  while FValue.Count > 0 do
    FValue.RemovePair(FValue.Pairs[0].JsonString.Value);
  FValue.AddPair('bpm', TJSONNumber.Create(Value.HeartRateMeasurement));
  FTime := Now;
  DoChanged;
end;

function TStreamingDeviceFrame.GetStarted: Boolean;
begin
  Result := FStarted;
end;

procedure TStreamingDeviceFrame.LogValue;
begin
  Memo1.Lines.Insert(0, Format('[%s] %s', [FormatDateTime('mm:ss:zzz', FTime), Value.ToString]));
end;

procedure TStreamingDeviceFrame.SetStarted(const Value: Boolean);
begin
  FStarted := Value;
end;

procedure TStreamingDeviceFrame.Start;
begin
  FStarted := True;
  GenericHRM.SubscribeHeartRateMeasurement;
end;

procedure TStreamingDeviceFrame.Stop;
begin
  FStarted := False;
  GenericHRM.UnsubscribeHeartRateMeasurement;
end;

end.
