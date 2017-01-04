package Classes::XPPC;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_environmental_subsystem('Classes::XPPC::Components::EnvironmentalSubsystem');
  } elsif ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem('Classes::XPPC::Components::BatterySubsystem');
  } else {
    $self->no_such_mode();
  }
}

