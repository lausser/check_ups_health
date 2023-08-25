package Classes::MerlinGerin;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_environmental_subsystem('Classes::MerlinGerin::Component::EnvironmentalSubsystem');
    # xups alarm-table ist auch noch interessant...
    $self->clear_ok();
    $self->analyze_and_check_environmental_subsystem('Classes::XUPS::Component::EnvironmentalSubsystem');
  } elsif ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem('Classes::MerlinGerin::Component::BatterySubsystem');
  } else {
    $self->no_such_mode();
  }
}

