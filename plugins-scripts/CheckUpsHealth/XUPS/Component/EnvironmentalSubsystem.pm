package CheckUpsHealth::XUPS::Component::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->init_subsystems([
      ["temphum_subsystem", "CheckUpsHealth::XUPS::Component::TempHumSubsystem"],
      ["alarm_subsystem", "CheckUpsHealth::XUPS::Component::AlarmSubsystem"],
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

