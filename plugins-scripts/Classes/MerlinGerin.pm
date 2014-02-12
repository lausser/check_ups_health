package Classes::MerlinGerin;
our @ISA = qw(Classes::Device);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub init {
  my $self = shift;
  my %params = @_;
  $self->SUPER::init(%params);
  if (! $self->check_messages()) {
    if ($self->mode =~ /device::hardware::health/) {
      $self->analyze_environmental_subsystem();
      $self->check_environmental_subsystem();
    } elsif ($self->mode =~ /device::battery/) {
      $self->analyze_battery_subsystem();
      $self->check_battery_subsystem();
    } else {
      $self->no_such_mode();
    }
  }
}

sub analyze_environmental_subsystem {
  my $self = shift;
  $self->{components}->{environmental_subsystem} =
      Classes::MerlinGerin::Components::EnvironmentalSubsystem->new();
}

sub analyze_battery_subsystem {
  my $self = shift;
  $self->{components}->{battery_subsystem} =
      Classes::MerlinGerin::Components::BatterySubsystem->new();
}

