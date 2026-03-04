package CheckUpsHealth::Eaton::PX::Component::AlarmSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;
sub init {
  my ($self) = @_;
  $self->get_snmp_tables("EATON-PXG-MIB", [
      ["alarms", "activeAlarmsTable", "CheckUpsHealth::Eaton::PX::Component::AlarmSubsystem::Alarm"],
  ]);
}
sub check {
  my ($self) = @_;
  foreach (@{$self->{alarms}}) { $_->check(); }
  if (@{$self->{alarms}} && ! $self->check_messages()) { $self->add_info("no active alarms"); $self->add_ok(); }
}
package CheckUpsHealth::Eaton::PX::Component::AlarmSubsystem::Alarm;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;
sub finish {
  my ($self) = @_;
  if (defined $self->{alarmTime}) {
    my $age = $self->ago_sysuptime($self->{alarmTime});
    $self->{alarmAge} = int($age) if defined $age;
    $self->{alarmEpoch} = int(time - $age) if defined $age && $age >= 0;
  }
}
sub check {
  my ($self) = @_;
  return unless defined $self->{alarmValue};
  my $val = $self->{alarmValue};
  my $active = ($val =~ /=\s*true\s*$/i);
  return unless $active;
  my $name = $self->{alarmName} || $self->{alarmID} || "alarm";
  if ($val =~ /([^=\s]+)\s*=\s*(true|false)\s*$/i) { $name = $1 unless ($self->{alarmName} || $self->{alarmID}); }
  my $timeinfo = defined $self->{alarmEpoch} ? sprintf(" (%s)", scalar localtime($self->{alarmEpoch})) : "";
  my $level = lc($self->{alarmLevel} // '');
  if ($level =~ /critical/) {
    $self->add_critical(sprintf "alarm: %s%s", $name, $timeinfo);
  } elsif ($level =~ /(cautionary|warning)/) {
    $self->add_warning(sprintf "alarm: %s%s", $name, $timeinfo);
  } elsif ($level =~ /(informational|notice|normal|ok)/) {
    $self->add_ok(sprintf "alarm: %s%s", $name, $timeinfo);
  } else {
    $self->add_critical(sprintf "alarm: %s%s", $name, $timeinfo);
  }
}
1;
