package CheckUpsHealth::Liebert;
our @ISA = qw(CheckUpsHealth::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::Liebert::Component::EnvironmentalSubsystem');
    if ($self->implements_mib('UPS-MIB')) {
      $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::UPS::Component::EnvironmentalSubsystem');
    }
  } elsif ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem('CheckUpsHealth::Liebert::Component::BatterySubsystem');
    if ($self->implements_mib('UPS-MIB')) {
      $self->analyze_and_check_battery_subsystem('CheckUpsHealth::UPS::Component::BatterySubsystem');
    }
  } else {
    $self->no_such_mode();
  }
}
