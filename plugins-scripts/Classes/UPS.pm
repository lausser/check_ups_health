package Classes::UPS;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_environmental_subsystem('Classes::UPS::Components::EnvironmentalSubsystem');
  } elsif ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem('Classes::UPS::Components::BatterySubsystem');
  } else {
    $self->no_such_mode();
  }
}

