package CheckUpsHealth::Socomec::Netvision;
our @ISA = qw(CheckUpsHealth::Socomec);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::Socomec::Netvision::Component::EnvironmentalSubsystem');
  } elsif ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem('CheckUpsHealth::Socomec::Netvision::Component::BatterySubsystem');
  } else {
    $self->no_such_mode();
  }
}

