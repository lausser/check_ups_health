package Classes::APC::Powermib;
our @ISA = qw(Classes::APC);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem('Classes::APC::Powermib::Components::EnvironmentalSubsystem');
  } elsif ($self->mode =~ /device::hardware/) {
    $self->analyze_and_check_environmental_subsystem('Classes::APC::Powermib::Components::BatterySubsystem');
  } else {
    $self->no_such_mode();
  }
}

