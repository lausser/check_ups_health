package Classes::APC::Powermib::ATS::Components::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;
use POSIX qw(mktime);

sub init {
  my $self = shift;
  $self->get_snmp_objects('PowerNet-MIB', (qw(atsIdentHardwareRev
   atsIdentFirmwareRev atsIdentFirmwareDate atsIdentDateOfManufacture
   atsIdentModelNumber atsIdentSerialNumber atsIdentNominalLineVoltage
   atsIdentNominalLineFrequency atsIdentDeviceRating atsStatusCommStatus
   atsStatusSelectedSource atsStatusRedundancyState atsStatusOverCurrentState
   atsStatus5VPowerSupply atsStatus24VPowerSupply atsStatus24VSourceBPowerSupply
   atsStatusPlus12VPowerSupply atsStatusMinus12VPowerSupply
   atsStatusSwitchStatus atsStatusFrontPanel atsStatusSourceAStatus
   atsStatusSourceBStatus atsStatusPhaseSyncStatus atsStatusVoltageOutStatus
   atsStatusHardwareStatus 
  )));
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

