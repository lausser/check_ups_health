package CheckUpsHealth::Liebert;
our @ISA = qw(CheckUpsHealth::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem');
#    if (! defined $self->{components}->{environmental_subsystem}->{lgpSysState} and $self->implements_mib('UPS-MIB')) {
#      $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::UPS::Component::EnvironmentalSubsystem');
#    }
  } elsif ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem('CheckUpsHealth::Liebert::Component::BatterySubsystem');
    if ($self->implements_mib('UPS-MIB')) {
      $self->analyze_and_check_battery_subsystem('CheckUpsHealth::UPS::Component::BatterySubsystem');
    }
  } else {
    $self->no_such_mode();
  }
}

sub pretty_sysdesc {
  my ($self, $sysDescr) = @_;
  #[LIEBERT]
  #classified_as: CheckUpsHealth::Liebert
  #lgpAgentIdentFirmwareVersion: 1.9.1.2
  #lgpAgentIdentManufacturer: Vertiv
  #lgpAgentIdentModel: RDU1xx Platform
  #lgpAgentIdentPartNumber: RDU101_1.9.1.2_0000001 <--
  #lgpAgentIdentSerialNumber: 0047
  #productname: Initialized
  #sysobjectid: .1.3.6.1.4.1.476.1.42
  #uptime: 3647812.92
  #info: device is up since 42d 5h 16m 52s
  #[TABLEITEM] <- gehe von index 1 aus
  #lgpAgentDeviceFirmwareVersion: MCUV230         DSPV160K110
  #lgpAgentDeviceId: .1.3.6.1.4.1.476.1.42.4.2.34
  #lgpAgentDeviceManufactureDate: 2023-08-01
  #lgpAgentDeviceManufacturer: Vertiv
  #lgpAgentDeviceModel: GXT5-6000IRT5UXLN <--
  #lgpAgentDeviceSerialNumber: 2321301348BWGB6 <---
  #lgpAgentDeviceServicePhoneNumber:
  my $part_number = $self->get_snmp_object(
      'LIEBERT-GP-AGENT-MIB', 'lgpAgentIdentPartNumber') || "unknown";
  my $device_model = $self->get_snmp_object(
      'LIEBERT-GP-AGENT-MIB', 'lgpAgentDeviceModel', 1) || "unknown";
  my $serial = $self->get_snmp_object(
      'LIEBERT-GP-AGENT-MIB', 'lgpAgentDeviceSerialNumber', 1) || "unknown";
  return sprintf "%s, %s, serial %s, part no %s",
      $sysDescr, $device_model, $serial, $part_number;
}
