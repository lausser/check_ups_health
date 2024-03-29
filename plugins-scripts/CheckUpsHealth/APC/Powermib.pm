package CheckUpsHealth::APC::Powermib;
our @ISA = qw(CheckUpsHealth::APC);
use strict;

sub init {
  my ($self) = @_;
  # irgendwelche Billigheimer sind nach dem get von sysUptime erstmal
  # so ueberfordert, daß sysDescr leer ist.
  $Monitoring::GLPlugin::SNMP::session->retries(3) if $Monitoring::GLPlugin::SNMP::session;
  if ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem(ref($self).'::Component::BatterySubsystem');
  } elsif ($self->mode =~ /device::hardware/) {
    $self->analyze_and_check_environmental_subsystem(ref($self).'::Component::EnvironmentalSubsystem');
  } else {
    $self->no_such_mode();
  }
}

