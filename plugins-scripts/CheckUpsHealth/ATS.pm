package CheckUpsHealth::ATS;
our @ISA = qw(CheckUpsHealth::Device);
use strict;

sub init {
  my ($self) = @_;

  if ($self->mode =~ /device::hardware::health/) {
    if ($self->implements_mib('ATS-THREEPHASE-MIB')) {
      $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem');
    } elsif ($self->implements_mib('UPS-MIB')) {
      $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::UPS::Component::EnvironmentalSubsystem');
    }
    if (! $self->check_messages()) {
      $self->add_ok("hardware working fine");
    }
  } elsif ($self->mode =~ /device::battery/) {
    if ($self->implements_mib('ATS-THREEPHASE-MIB')) {
      $self->analyze_and_check_battery_subsystem('CheckUpsHealth::ATS::ATSTHREEPHASE::Component::BatterySubsystem');
#      if ($self->implements_mib('UPS-MIB')) {
#        $self->analyze_and_check_battery_subsystem('CheckUpsHealth::UPS::Component::BatterySubsystem');
#      }
    }
  } else {
    $self->no_such_mode();
  }
}
