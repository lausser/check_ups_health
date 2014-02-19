package Classes::UPS::Components::EnvironmentalSubsystem;
our @ISA = qw(Classes::UPS);
use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  $self->init();
  return $self;
}

sub init {
  my $self = shift;
  $self->get_snmp_objects("UPS-MIB", qw(upsAlarmsPresent upsTestResultsSummary
      upsTestResultsDetail upsTestStartTime));
  $self->get_snmp_tables("UPS-MIB", [
      ["alarms", "upsAlarmTable", "Classes::UPS::Components::EnvironmentalSubsystem::Alarm"],
  ]);
}

sub check {
  my $self = shift;
  $self->add_info('checking alarms');
  foreach (@{$self->{alarms}}) {
    $_->check();
  }
  if ($self->{upsTestStartTime}) {
    my $result = sprintf "test result from %s was %s", 
        scalar localtime time - $GLPlugin::SNMP::uptime + $self->{upsTestStartTime},
        $self->{upsTestResultsDetail} ? $self->{upsTestResultsDetail} : $self->{upsTestResultsSummary};
    if ($self->{upsTestResultsSummary} eq "doneWarning") {
      $self->add_warning($result);
    } elsif ($self->{upsTestResultsSummary} eq "doneError") {
      $self->add_critical($result);
    }
    my $last_test = $GLPlugin::SNMP::uptime - $self->{upsTestStartTime};
    my $days_ago = (time - $last_test) / (3600 * 24);
    my $info = sprintf 'last selftest was %d days ago (%s)',
        $self->{upsAdvTestLastDiagnosticsAge}, scalar localtime $self->{upsAdvTestLastDiagnosticsDate};
    $self->add_info($info);
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsAdvTestLastDiagnosticsAge},
            metric => 'selftest_age'), $info);
    $self->add_perfdata(
        label => 'selftest_age',
        value => $self->{upsAdvTestLastDiagnosticsAge},
        warning => ($self->get_thresholds(metric => 'selftest_age'))[0],
        critical => ($self->get_thresholds(metric => 'selftest_age'))[1],
    );
  }

  if (! $self->check_messages()) {
    $self->add_ok("hardware working fine. no alarms");
  }
}

sub dump {
  my $self = shift;
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
our @ISA = qw(GLPlugin::TableItem);
use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub check {
  my $self = shift;
  foreach (qw(upsAlarmBatteryBad upsAlarmOnBattery upsAlarmLowBattery
      upsAlarmDepletedBattery upsAlarmTempBad upsAlarmInputBad
      upsAlarmOutputBad upsAlarmOutputOverload upsAlarmOnBypass
      upsAlarmBypassBad upsAlarmOutputOffAsRequested upsAlarmUpsOffAsRequested
      upsAlarmChargerFailed upsAlarmUpsOutputOff upsAlarmUpsSystemOff
      upsAlarmFanFailure upsAlarmFuseFailure upsAlarmGeneralFault
      upsAlarmDiagnosticTestFailed upsAlarmCommunicationsLost upsAlarmAwaitingPower
      upsAlarmShutdownPending upsAlarmShutdownImminent upsAlarmTestInProgress)) {
    if ($self->{upsAlarmDescr} eq  $GLPlugin::SNMP::mibs_and_oids->{"UPS-MIB"}->{$_}) {
      $self->{upsAlarmDescr} = $_;
    }
  }
  my $age = $GLPlugin::SNMP::uptime - $self->{upsAlarmTime};
  if ($age < 3600) {
    $self->add_critical(sprintf "alarm: %s (%d min ago)",
        $self->{upsAlarmDescr}, $age / 60);
  }
}
