package CheckUpsHealth::UPS::Component::AlarmSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->get_snmp_objects("UPS-MIB", qw(upsAlarmsPresent));
  $self->get_snmp_tables("UPS-MIB", [
      ["alarms", "upsAlarmTable", "CheckUpsHealth::UPS::Component::EnvironmentalSubsystem::Alarm", sub { shift->{upsAlarmDescr} =~ /0.0.0.0.0.0.0.0.0.0.0/ ? 0 : 1 } ],
  ]);
}

sub check {
  my ($self) = @_;
  $self->add_info(sprintf "%d alarms", $self->{upsAlarmsPresent});
  $self->add_ok();
  foreach (@{$self->{alarms}}) {
    next if ! $_->{upsAlarmDescr}; # irgendwelche Blindgaenger sind auch moeglich, z.b. einer bei upsTestResultsSummary: noTestsInitiated
    $_->check();
  }
  if (@{$self->{alarms}} && ! $self->check_messages()) {
    $self->add_ok("old or harmless");
  }
}


package CheckUpsHealth::UPS::Component::EnvironmentalSubsystem::Alarm;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
  my $age = $self->ago_sysuptime($self->{upsAlarmTime});
  $self->{upsAlarmTimeHuman} = scalar localtime (time - $age);
  if ($age < 3600*5*24*180 && $age >= 0 || $self->{upsAlarmTime} == 0) {
    if ($self->{upsAlarmDescr} =~ /(upsAlarmTestInProgress|.*AsRequested)/) {
      $self->{bullshit_alarm} = 1;
    } else {
      my $duration = $self->{upsAlarmTime} == 0 ? "since boot" : $self->{upsAlarmTimeHuman};
      $self->add_critical(sprintf "alarm: %s (%s)",
          $self->{upsAlarmDescr}, $duration);
    }
  }
}
