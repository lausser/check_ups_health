package CheckUpsHealth::Eaton;
our @ISA = qw(CheckUpsHealth::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::hardware::health/) {
    if ($self->implements_mib('EATON-ATS2-MIB')) {
      $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::Eaton::ATS2::Component::EnvironmentalSubsystem');
      if (defined $self->{components}->{environmental_subsystem}->{upsAlarmsPresent} and $self->{components}->{environmental_subsystem}->{upsAlarmsPresent}) {
        if ($self->implements_mib('XUPS-MIB')) {
          $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::XUPS::Component::EnvironmentalSubsystem');
        } elsif ($self->implements_mib('XUPS-MIB')) {
          $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::UPS::Component::EnvironmentalSubsystem');
        }
      }
    } elsif ($self->implements_mib('ATS-THREEPHASE-MIB')) {
      $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::ATS::ATSTHREEPHASE::Component::EnvironmentalSubsystem');
    } elsif ($self->implements_mib('XUPS-MIB')) {
      $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::XUPS::Component::EnvironmentalSubsystem');
    } elsif ($self->implements_mib('UPS-MIB')) {
      $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::UPS::Component::EnvironmentalSubsystem');
    } else {
      $self->no_such_mode();
    }
    if (! $self->check_messages()) {
      $self->add_ok("hardware working fine");
    }
  } elsif ($self->mode =~ /device::battery/) {
    if ($self->implements_mib('EATON-ATS2-MIB')) {
      $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::Eaton::ATS2::Component::BatterySubsystem');
    } elsif ($self->implements_mib('ATS-THREEPHASE-MIB')) {
      $self->analyze_and_check_battery_subsystem('CheckUpsHealth::ATS::ATSTHREEPHASE::Component::BatterySubsystem');
    } elsif ($self->implements_mib('XUPS-MIB')) {
      $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::XUPS::Component::EnvironmentalSubsystem');
    } elsif ($self->implements_mib('UPS-MIB')) {
      $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::UPS::Component::EnvironmentalSubsystem');
    }
  } else {
    $self->no_such_mode();
  }
}
