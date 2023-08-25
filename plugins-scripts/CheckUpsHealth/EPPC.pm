package CheckUpsHealth::EPPC;
our @ISA = qw(CheckUpsHealth::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::EPPC::Component::EnvironmentalSubsystem');
  } elsif ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem('CheckUpsHealth::EPPC::Component::BatterySubsystem');
  } else {
    $self->no_such_mode();
  }
}

