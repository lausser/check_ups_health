package Classes::XPPC;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /device::hardware::health/) {
    $self->analyze_and_check_environmental_subsystem();
  } elsif ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem();
  } else {
    $self->no_such_mode();
  }
}

sub analyze_environmental_subsystem {
  my $self = shift;
  $self->{components}->{environmental_subsystem} =
      Classes::XPPC::Components::EnvironmentalSubsystem->new();
}

sub analyze_battery_subsystem {
  my $self = shift;
  $self->{components}->{battery_subsystem} =
      Classes::XPPC::Components::BatterySubsystem->new();
}

