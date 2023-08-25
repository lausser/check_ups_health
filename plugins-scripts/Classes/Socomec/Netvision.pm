package Classes::Socomec::Netvision;
our @ISA = qw(Classes::Socomec);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_environmental_subsystem('Classes::Socomec::Netvision::Component::EnvironmentalSubsystem');
  } elsif ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem('Classes::Socomec::Netvision::Component::BatterySubsystem');
  } else {
    $self->no_such_mode();
  }
}

