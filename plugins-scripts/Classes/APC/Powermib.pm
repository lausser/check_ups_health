package Classes::APC::Powermib;
our @ISA = qw(Classes::APC);
use strict;

sub init {
  my $self = shift;
  if ($self->mode =~ /device::battery/) {
    $self->analyze_and_check_battery_subsystem();
  } elsif ($self->mode =~ /device::hardware/) {
    $self->analyze_and_check_environmental_subsystem();
  } else {
    $self->no_such_mode();
  }
}

sub analyze_environmental_subsystem {
  my $self = shift;
  $self->{components}->{environmental_subsystem} =
      Classes::APC::Powermib::Components::EnvironmentalSubsystem->new();
}

sub analyze_battery_subsystem {
  my $self = shift;
  $self->{components}->{battery_subsystem} =
      Classes::APC::Powermib::Components::BatterySubsystem->new();
}

