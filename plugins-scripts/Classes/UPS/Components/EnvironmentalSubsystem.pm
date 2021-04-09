package Classes::UPS::Components::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->get_snmp_objects("UPS-MIB", qw(upsAlarmsPresent upsTestResultsSummary
      upsTestResultsDetail upsTestStartTime));
  $self->get_snmp_tables("UPS-MIB", [
      ["alarms", "upsAlarmTable", "Classes::UPS::Components::EnvironmentalSubsystem::Alarm", sub { shift->{upsAlarmDescr} =~ /0.0.0.0.0.0.0.0.0.0.0/ ? 0 : 1 } ],
  ]);
}

sub check {
  my ($self) = @_;
  $self->add_info('checking alarms');
  foreach (@{$self->{alarms}}) {
    next if ! $_->{upsAlarmDescr}; # irgendwelche Blindgaenger sind auch moeglich, z.b. einer bei upsTestResultsSummary: noTestsInitiated
    $_->check();
  }
  if ($self->{upsTestStartTime}) {
    my $result = sprintf "test result from %s was %s", 
        scalar localtime time - $self->uptime() + $self->{upsTestStartTime},
        $self->{upsTestResultsDetail} ? $self->{upsTestResultsDetail} : $self->{upsTestResultsSummary};
    if ($self->{upsTestResultsSummary} eq "doneWarning") {
      $self->add_warning($result);
    } elsif ($self->{upsTestResultsSummary} eq "doneError") {
      $self->add_critical($result);
    }
    my $last_test_ago = $self->ago_sysuptime($self->{upsTestStartTime});
    $self->{upsAdvTestLastDiagnosticsDate} = time - $last_test_ago;
    $self->{upsAdvTestLastDiagnosticsAge} = $last_test_ago / (3600 * 24);
    $self->add_info(sprintf 'last selftest was %d days ago (%s)',
        $self->{upsAdvTestLastDiagnosticsAge}, scalar localtime $self->{upsAdvTestLastDiagnosticsDate});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsAdvTestLastDiagnosticsAge},
            metric => 'selftest_age'));
    $self->add_perfdata(
        label => 'selftest_age',
        value => $self->{upsAdvTestLastDiagnosticsAge},
    );
  }

  if (! $self->check_messages()) {
    $self->add_ok("hardware working fine. no alarms");
  }
}

sub dump {
  my ($self) = @_;
  printf "[ALARMS]\n";
  foreach (grep /^ups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
  foreach (@{$self->{alarms}}) {
    $_->dump();
  }
}


package Classes::UPS::Components::EnvironmentalSubsystem::Alarm;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{upsAlarmEventTime} = time - $self->ago_sysuptime($self->{upsAlarmTime});
  $self->{upsAlarmEventTimeHuman} = scalar localtime $self->{upsAlarmEventTime};
}

sub check {
  my ($self) = @_;
  my $age = $self->ago_sysuptime($self->{upsAlarmTime});
  if ($age < 3600) {
    if ($self->{upsAlarmDescr} !~ /(upsAlarmTestInProgress|.*AsRequested)/) {
      $self->add_critical(sprintf "alarm: %s (%d min ago)",
          $self->{upsAlarmDescr}, $age / 60);
    }
  }
}
