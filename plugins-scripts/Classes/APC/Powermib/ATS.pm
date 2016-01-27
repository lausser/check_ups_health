package Classes::APC::Powermib::ATS;
our @ISA = qw(Classes::APC::Powermib);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem(ref($self).'::Components::BatterySubsystem');
  } elsif ($self->mode =~ /device::hardware/) {
    $self->analyze_and_check_environmental_subsystem(ref($self).'::Components::EnvironmentalSubsystem');
  } else {
    $self->no_such_mode();
  }
}

