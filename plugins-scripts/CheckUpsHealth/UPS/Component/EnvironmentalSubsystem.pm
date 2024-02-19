package CheckUpsHealth::UPS::Component::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->init_subsystems([
      ["selftest_subsystem", "CheckUpsHealth::UPS::Component::SelftestSubsystem"],
      ["alarm_subsystem", "CheckUpsHealth::UPS::Component::AlarmSubsystem"],
  ]);
}

sub check {
  my ($self) = @_;
  $self->check_subsystems();
  $self->reduce_messages_short("environmental hardware working fine")
      if ! $self->opts->subsystem;
}

sub dump {
  my ($self) = @_;
  $self->dump_subsystems();
}

1;
