package CheckUpsHealth::XPPC::Component::BatterySubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub init {
  my ($self) = @_;
  $self->get_snmp_objects('XPPC-MIB', (qw(upsBaseBatteryStatus
      upsSmartBatteryCapacity upsSmartBatteryVoltage upsSmartBatteryTemperature
      upsSmartBatteryRunTimeRemaining upsSmartBatteryReplaceIndicator
      upsSmartBatteryCurrent 
      upsSmartInputLineVoltage upsSmartInputFrequency upsSmartInputLineFailCause
      upsBaseOutputStatus upsSmartOutputVoltage upsSmartOutputFrequency
      upsSmartOutputLoad)));
  $self->{upsSmartBatteryRunTimeRemaining} /= 60 if $self->{upsSmartBatteryRunTimeRemaining};
  $self->{upsSmartBatteryTemperature} /= 10;
  $self->{upsSmartBatteryVoltage} *= 10;
  $self->{upsSmartInputFrequency} /= 10 if defined $self->{upsSmartInputFrequency};
  $self->{upsSmartOutputVoltage} /= 10 if defined $self->{upsSmartOutputVoltage};
  $self->{upsSmartOutputFrequency} /= 10 if defined $self->{upsSmartOutputFrequency};
  if (defined $self->{upsSmartInputLineVoltage} and $self->{upsSmartInputLineVoltage}!~ /^\d+$/) {
    # muss laut MIB ein INTEGER sein, aber es gibt auch sowas:
    # XPPC-MIB::upsSmartInputLineVoltage = Normal
    # gesehen bei XPPC-MIB::upsSmartIdentAgentFirmwareRevision = 3.8.CY504.AB.210318
    # XPPC-MIB::upsSmartIdentAgentFirmwareRevision = 3.8.CY504.AB.200205 hingegen zeigt korrekterweise upsSmartInputLineVoltage = 2260
    my $upsSmartBatteryVoltage = $self->get_snmp_object('UPS-MIB', "upsInputVoltage", 1);
    $upsSmartBatteryVoltage = undef;
    if (defined $upsSmartBatteryVoltage) {
      $self->{upsSmartInputLineVoltage} = $upsSmartBatteryVoltage;
    } else {
      $self->{upsSmartInputLineVoltageTxt} = $self->{upsSmartInputLineVoltage};
      $self->{upsSmartInputLineVoltage} = undef;
    }
  } else {
    $self->{upsSmartInputLineVoltage} /= 10 if defined $self->{upsSmartInputLineVoltage};
  }
}

sub check {
  my ($self) = @_;
  $self->add_info('checking battery');
  $self->add_info(sprintf 'battery status is %s', $self->{upsBaseBatteryStatus});
  if ($self->{upsBaseBatteryStatus} ne 'batteryNormal') {
    $self->add_critical();
  } else {
    $self->add_ok();
  } 
  if ($self->{upsSmartBatteryReplaceIndicator} &&
      $self->{upsSmartBatteryReplaceIndicator} eq 'batteryNeedsReplacing') {
    $self->add_critical('battery needs replacing');
  }
  if ($self->{upsBaseOutputStatus}) { # kann auch undef sein (10kv z.b.)
    $self->add_info(sprintf 'output status is %s',
        $self->{upsBaseOutputStatus});
    if ($self->{upsBaseOutputStatus} eq 'standBy') {
      $self->add_ok();
    } elsif ($self->{upsBaseOutputStatus} ne 'onLine') {
      $self->add_warning();
      if ($self->{upsSmartInputLineFailCause}) {
        $self->add_warning(sprintf 'caused by %s',
            $self->{upsSmartInputLineFailCause});
      }
    } else {
      $self->add_ok();
    }
  }

  $self->set_thresholds(
      metric => 'capacity', warning => '25:', critical => '10:');
  $self->add_info(sprintf 'capacity is %.2f%%', $self->{upsSmartBatteryCapacity});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsSmartBatteryCapacity},
          metric => 'capacity'));
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{upsSmartBatteryCapacity},
      uom => '%',
  );

  $self->set_thresholds(
      metric => 'output_load', warning => '75', critical => '85');
  $self->add_info(sprintf 'output load %.2f%%', $self->{upsSmartOutputLoad});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsSmartOutputLoad},
          metric => 'output_load'));
  $self->add_perfdata(
      label => 'output_load',
      value => $self->{upsSmartOutputLoad},
      uom => '%',
  );

  $self->set_thresholds(
      metric => 'battery_temperature', warning => '70', critical => '80');
  if (defined $self->{upsSmartBatteryTemperature} &&
      $self->{upsSmartBatteryTemperature} < 0) {
    # if standby, temp can be -1000
    $self->{upsSmartBatteryTemperature} = 0;
  }
  $self->add_info(sprintf 'temperature is %.2fC', $self->{upsSmartBatteryTemperature});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsSmartBatteryTemperature},
          metric => 'battery_temperature'));
  $self->add_perfdata(
      label => 'battery_temperature',
      value => $self->{upsSmartBatteryTemperature},
  );

  $self->set_thresholds(
      metric => 'remaining_time', warning => '15:', critical => '10:');
  $self->add_info(sprintf 'remaining battery run time is %.2fmin', $self->{upsSmartBatteryRunTimeRemaining});
  # $self->{upsSmartBatteryRunTimeRemaining} = 0 probably is normal
  # as long as the battery is not in use
  $self->add_message(
      $self->{upsSmartBatteryRunTimeRemaining} ? $self->check_thresholds(
          value => $self->{upsSmartBatteryRunTimeRemaining},
          metric => 'remaining_time') : OK);
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{upsSmartBatteryRunTimeRemaining},
  );

  if (defined $self->{upsSmartInputLineVoltage} and
      $self->{upsSmartInputLineVoltage} =~ /^\d+$/ and
      $self->{upsSmartInputLineVoltage} < 1) {
    $self->add_critical(sprintf 'input power outage');
  } elsif (defined $self->{upsSmartInputLineVoltageTxt} and
      $self->{upsSmartInputLineVoltageTxt} ne "Normal") {
    $self->add_critical(sprintf 'input voltage is %s', $self->{upsSmartInputLineVoltageTxt});
  }
  $self->add_perfdata(
      label => 'input_voltage',
      value => $self->{upsSmartInputLineVoltage},
  ) if defined $self->{upsSmartInputLineVoltage};
  $self->add_perfdata(
      label => 'input_frequency',
      value => $self->{upsSmartInputFrequency},
  ) if defined $self->{upsSmartInputFrequency};
  $self->add_perfdata(
      label => 'output_voltage',
      value => $self->{upsSmartOutputVoltage},
  ) if defined $self->{upsSmartOutputVoltage};
  $self->add_perfdata(
      label => 'output_frequency',
      value => $self->{upsSmartOutputFrequency},
  ) if defined $self->{upsSmartOutputFrequency};
}

sub dump {
  my ($self) = @_;
  printf "[BATTERY]\n";
  foreach (qw(upsBaseBatteryStatus
      upsSmartBatteryCapacity upsSmartBatteryVoltage upsSmartBatteryTemperature
      upsSmartBatteryRunTimeRemaining upsSmartBatteryReplaceIndicator
      upsSmartBatteryCurrent 
      upsSmartInputLineVoltage upsSmartInputLineVoltageTxt 
      upsSmartInputFrequency upsSmartInputLineFailCause
      upsBaseOutputStatus upsSmartOutputVoltage upsSmartOutputFrequency
      upsSmartOutputLoad)) {
    printf "%s: %s\n", $_, $self->{$_} if defined $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}
