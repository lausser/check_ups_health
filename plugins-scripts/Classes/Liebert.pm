package Classes::Liebert;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_environmental_subsystem('Classes::Liebert::Component::EnvironmentalSubsystem');
    if ($self->implements_mib('UPS-MIB')) {
      $self->analyze_and_check_environmental_subsystem('Classes::UPS::Component::EnvironmentalSubsystem');
    }
  } elsif ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem('Classes::Liebert::Component::BatterySubsystem');
    if ($self->implements_mib('UPS-MIB')) {
      $self->analyze_and_check_battery_subsystem('Classes::UPS::Component::BatterySubsystem');
    }
  } else {
    $self->no_such_mode();
  }
}
