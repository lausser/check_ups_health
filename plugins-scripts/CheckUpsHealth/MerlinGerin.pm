package CheckUpsHealth::MerlinGerin;
our @ISA = qw(CheckUpsHealth::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::MerlinGerin::Component::EnvironmentalSubsystem');
    # (x)ups alarm-table ist auch noch interessant...
    if ($self->implements_mib("XUPS-MIB")) {
      $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::XUPS::Component::AlarmSubsystem');
    } elsif ($self->implements_mib("UPS-MIB")) {
      $self->analyze_and_check_environmental_subsystem('CheckUpsHealth::UPS::Component::AlarmSubsystem');
    }
  } elsif ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem('CheckUpsHealth::MerlinGerin::Component::BatterySubsystem');
  } else {
    $self->no_such_mode();
  }
}

