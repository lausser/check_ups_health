package Classes::APC::Powermib::ATS::Components::BatterySubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;
use POSIX qw(mktime);

sub init {
  my $self = shift;
  $self->get_snmp_objects('PowerNet-MIB', (qw(atsCalibrationNumInputs
      atsCalibrationNumInputPhases atsCalibrationNumOutputs atsCalibrationNumOutputPhases 
      atsNumInputs atsNumOutputs atsOutputBankTableSize
  )));
  $self->get_snmp_tables("PowerNet-MIB", [
      #["alarms", "upsAlarmTable", "Classes::Socomec::Netvision::Components::EnvironmentalSubsystem::Alarm"],
      ["calibrationinputphases", "atsCalibrationInputPhaseTable", "Monitoring::GLPlugin::SNMP::TableItem"],
      ["powersupplyvoltagess", "atsCalibrationPowerSupplyVoltageTable", "Monitoring::GLPlugin::SNMP::TableItem"],
      ["calibrationoutputs", "atsCalibrationOutputTable", "Monitoring::GLPlugin::SNMP::TableItem"],
      ["atsConfigBankTable", "atsConfigBankTable", "Monitoring::GLPlugin::SNMP::TableItem"],
      ["atsConfigPhaseTable", "atsConfigPhaseTable", "Monitoring::GLPlugin::SNMP::TableItem"],
# atsConfigPhaseTable -> bezug zo atsOutputPhaseTable
      ["atsInputTable", "atsInputTable", "Monitoring::GLPlugin::SNMP::TableItem"],
# atsInputFrequency atsInputName
      ["atsInputPhaseTable", "atsInputPhaseTable", "Monitoring::GLPlugin::SNMP::TableItem"],
# atsInputVoltage, atsInputMaxVoltage atsInputMinVoltage , -1 heisst not avail
# atsInputCurrent atsInputMinCurrent atsInputMaxCurrent
# atsInputPower atsInputMaxPower atsInputMinPower
      ["atsOutputTable", "atsOutputTable", "Monitoring::GLPlugin::SNMP::TableItem"],
      ["atsOutputPhaseTable", "atsOutputPhaseTable", "Monitoring::GLPlugin::SNMP::TableItem"],
atsOutputPercentLoad atsOutputPercentPower
atsOutputCurrent atsOutputLoad atsOutputPower atsOutputVoltage
      ["atsOutputBankTable", "atsOutputBankTable", "Monitoring::GLPlugin::SNMP::TableItem"],
  ]);

}

sub check {
  my $self = shift;
  my $info = undef;
  $self->add_info('checking hardware and self-tests');
  $self->add_info('status is '.$self->{atsStatusHardwareStatus});
  foreach my $item (qw(atsStatus24VPowerSupply atsStatus24VSourceBPowerSupply
      atsStatus5VPowerSupply atsStatusMinus12VPowerSupply atsStatusPlus12VPowerSupply)) {
    $self->add_info(sprintf "%s is %s", $item, $self->{$item});
    if ($self->{$item} ne "atsPowerSupplyOK") {
      $self->add_critical();
    }
  }
  foreach my $item (qw(atsStatusHardwareStatus atsStatusSourceAStatus
      atsStatusSourceBStatus atsStatusSwitchStatus atsStatusVoltageOutStatus)) {
    $self->add_info(sprintf "%s is %s", $item, $self->{$item});
    if ($self->{$item} ne "ok") {
      $self->add_critical();
    }
  }
  foreach my $item (qw(atsStatusRedundancyState)) {
    $self->add_info(sprintf "%s is %s", $item, $self->{$item});
    if ($self->{$item} ne "atsFullyRedundant") {
      $self->add_warning();
    }
  }
  if (! $self->check_messages()) {
    $self->add_ok("hardware working fine");
  }
}

