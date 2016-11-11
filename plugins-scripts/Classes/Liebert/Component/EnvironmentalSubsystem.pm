package Classes::Liebert::Components::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my $self = shift;
  $self->get_snmp_objects("LIEBERT-GP-SYSTEM-MIB", qw(
      lgpSysState
  ));
  $self->get_snmp_objects("LIEBERT-GP-CONDITIONS-MIB", qw(
      lgpConditionsPresent
  ));
  if ($self->{lgpConditionsPresent}) {
    $self->get_snmp_tables("LIEBERT-GP-CONDITIONS-MIB", [
      ["conditions", "lgpConditionsTable", "Classes::Liebert::Components::EnvironmentalSubsystem::Condition"],
    ]);
  }
}

sub check {
  my $self = shift;
  $self->add_info(sprintf 'system state is %s', $self->{lgpSysState});
  if ($self->{lgpSysState} eq 'startUp' ||
      $self->{lgpSysState} eq 'normalOperation') {
    $self->add_ok();
  } elsif ($self->{lgpSysState} eq 'normalWithWarning') {
    $self->add_warning();
  } else {
    $self->add_critical();
  }
}


package Classes::Liebert::Components::EnvironmentalSubsystem::Condition;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my $self = shift;
}
