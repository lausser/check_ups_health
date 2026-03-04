package CheckUpsHealth::Eaton::PX::Component::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;
sub init {
  my ($self) = @_;
  $self->init_subsystems([
      ["alarm_subsystem", "CheckUpsHealth::Eaton::PX::Component::AlarmSubsystem"],
  ]);
}
sub check { my ($self) = @_; $self->check_subsystems(); $self->reduce_messages_short("environmental hardware working fine") if ! $self->opts->subsystem; }
sub dump { my ($self) = @_; $self->dump_subsystems(); }
1;
