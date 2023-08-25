package Classes::APC::Powermib::UPS;
our @ISA = qw(Classes::APC::Powermib);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem(ref($self).'::Component::BatterySubsystem');
  } elsif ($self->mode =~ /device::hardware/) {
    $self->analyze_and_check_environmental_subsystem(ref($self).'::Component::EnvironmentalSubsystem');
  } else {
    $self->no_such_mode();
  }
}

