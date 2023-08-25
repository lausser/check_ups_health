package CheckUpsHealth::EPPC::Component::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;
use POSIX qw(mktime);

sub init {
  my ($self) = @_;
  $self->get_snmp_objects('EPPC-MIB', (qw(upsEBatteryTestStart
      upsEBatteryTestResult
      upsEBatteryTestStartTime
      upsESystemTemperature upsESystemConfigOverTemperatureSetPoint
      upsEEnvironmentCurrentTemperature
      upsEEnvironmentTemperatureHighSetPoint
      upsEEnvironmentTemperatureHighStatus
      upsEEnvironmentTemperatureLowSetPoint
      upsEEnvironmentTemperatureLowStatus
      upsEEnvironmentTemperatureOffset
      upsEEnvironmentCurrentHumidity
      upsEEnvironmentHumidityHighSetPoint
      upsEEnvironmentHumidityHighStatus
      upsEEnvironmentHumidityLowSetPoint
      upsEEnvironmentHumidityLowStatus
      upsEEnvironmentHumidityOffset
      upsESystemWarningCode upsESystemFaultCode
  )));
  eval {
    die if ! $self->{upsEBatteryTestStart};
    $self->{upsEBatteryTestStartTime} =~ /(\d+)\/(\d+)\/(\d+)/;
    $self->{upsEBatteryTestDate} = mktime(0, 0, 0, $1, $2 - 1, $3 - 1900);
    $self->{upsEBatteryTestAge} = (time - $self->{upsEBatteryTestDate}) / (3600 * 24);
  };
  if ($@) {
    $self->{upsEBatteryTestStartTime} = 0;
  }
}

sub check {
  my ($self) = @_;
  $self->add_info('checking hardware and self-tests');
  if ($self->{upsESystemWarningCode}) {
    $self->add_warning(sprintf "warning code %s", $self->{upsESystemWarningCode});
  }
  if ($self->{upsESystemFaultCode}) {
    $self->add_critical(sprintf "fault code %s", $self->{upsESystemFaultCode});
  }
  if ($self->{upsESystemTemperature} && $self->{upsESystemTemperature} != -1) {
    $self->{upsESystemTemperature} /= 10;
    $self->{upsESystemConfigOverTemperatureSetPoint} /= 10;
    $self->set_thresholds(
        metric => 'system_temperature',
        warning => $self->{upsESystemConfigOverTemperatureSetPoint},
        critical => $self->{upsESystemConfigOverTemperatureSetPoint});
    $self->add_info(sprintf 'system temperature is %.2fC',
        $self->{upsESystemTemperature});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsESystemTemperature},
            metric => 'system_temperature'));
    $self->add_perfdata(
        label => 'system_temperature',
        value => $self->{upsESystemTemperature},
    );
  }
  if ($self->{upsEEnvironmentCurrentTemperature} && $self->{upsEEnvironmentCurrentTemperature} != -1) {
    $self->{upsEEnvironmentCurrentTemperature} /= 10;
    my $under =
        $self->{upsEEnvironmentTemperatureLowStatus} eq "enable" ?
            $self->{upsEEnvironmentTemperatureLowSetPoint} / 10 : 15;
    my $over =
        $self->{upsEEnvironmentTemperatureHighStatus} eq "enable" ?
            $self->{upsEEnvironmentTemperatureHighSetPoint} / 10 : 50;
    $self->set_thresholds(
        metric => 'temperature', warning => $under.':'.$over, critical => $under.':'.$over);
    $self->add_info(sprintf 'temperature is %.2fC', $self->{upsEEnvironmentCurrentTemperature});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsEEnvironmentCurrentTemperature},
            metric => 'temperature'));
    $self->add_perfdata(
        label => 'temperature',
        value => $self->{upsEEnvironmentCurrentTemperature},
    );
  }
  if ($self->{upsEEnvironmentCurrentHumidity} && $self->{upsEEnvironmentCurrentHumidity} != -1) {
    $self->{upsEEnvironmentCurrentHumidity} /= 10;
    my $under =
        $self->{upsEEnvironmentHumidityLowStatus} eq "enable" ?
            $self->{upsEEnvironmentHumidityLowSetPoint} / 10 : 50;
    my $over =
        $self->{upsEEnvironmentHumidityHighStatus} eq "enable" ?
            $self->{upsEEnvironmentHumidityHighSetPoint} / 10 : 90;
    $self->set_thresholds(
        metric => 'humidity', warning => $under.':'.$over, critical => $under.':'.$over);
    $self->add_info(sprintf 'humidity is %.2f%%', $self->{upsEEnvironmentCurrentHumidity});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsEEnvironmentCurrentHumidity},
            metric => 'humidity'));
    $self->add_perfdata(
        label => 'humidity',
        value => $self->{upsEEnvironmentCurrentHumidity},
    );
  }
  if ($self->{upsEBatteryTestDate}) {
    $self->add_info(sprintf 'selftest result was %s', $self->{upsEBatteryTestResult});
    if ($self->{upsEBatteryTestResult} ne 'noFailure') {
      $self->add_warning();
    } else {
      $self->add_ok();
    }
    $self->set_thresholds(
        metric => 'selftest_age', warning => '30', critical => '60');
    $self->add_info(sprintf 'last selftest was %d days ago (%s)', $self->{upsEBatteryTestAge}, scalar localtime $self->{upsEBatteryTestDate});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsEBatteryTestAge},
            metric => 'selftest_age'));
    $self->add_perfdata(
        label => 'selftest_age',
        value => $self->{upsEBatteryTestAge},
    );
  } elsif ($self->{upsEBatteryTestResult}) {
    $self->add_info(sprintf 'selftest result was %s (run date unknown)', $self->{upsEBatteryTestResult});
    if ($self->{upsEBatteryTestResult} ne 'noFailure') {
      $self->add_warning();
    } else {
      $self->add_ok();
    }
  } else {
    $self->add_warning("please run diagnostics");
  }
  if (! $self->check_messages()) {
    $self->add_ok("hardware working fine");
  }
}

sub xdump {
  my ($self) = @_;
  printf "[HARDWARE]\n";
  foreach (qw(upsBasicIdentModel 
      upsAdvIdentDateOfManufacture upsAdvIdentSerialNumber
      upsSmartTestDiagnosticSchedule
      upsAdvTestDiagnosticsResults upsSmartTestLastDiagnosticsDate)) {
    printf "%s: %s\n", $_, $self->{$_} if defined $self->{$_};
    printf "%s: %s\n", $_, scalar localtime $self->{$_} if (defined $self->{$_} && $_ =~ /Date$/);
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}
