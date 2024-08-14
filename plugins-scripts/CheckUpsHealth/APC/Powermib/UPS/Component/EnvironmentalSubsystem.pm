package CheckUpsHealth::APC::Powermib::UPS::Component::EnvironmentalSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;
use POSIX qw(mktime);

sub init {
  my ($self) = @_;
  # aufteilen in eigene packages: basic, advanced und smart
  # wenn adv keine tests hatte, dann upsBasicStateOutputState fragen
  $self->get_snmp_objects('PowerNet-MIB', (qw(
      upsBasicIdentModel 
      upsBasicOutputStatus upsBasicSystemStatus
      upsBasicSystemInternalTemperature
      upsBasicStateOutputState 
      upsAdvIdentDateOfManufacture upsAdvIdentSerialNumber
      upsAdvTestDiagnosticSchedule
      upsAdvTestDiagnosticsResults upsAdvTestLastDiagnosticsDate
      upsAdvStateAbnormalConditions
      upsAdvStateSymmetra3PhaseSpecificFaults
      upsAdvStateDP300ESpecificFaults
      upsAdvStateSymmetraSpecificFaults
      upsAdvStateSmartUPSSpecificFaults
      upsAdvStateSystemMessages
  )));
  eval {
    die if ! $self->{upsAdvTestLastDiagnosticsDate};
    $self->{upsAdvTestLastDiagnosticsDate} =~ /(\d+)\/(\d+)\/(\d+)/ || die;
    $self->{upsAdvTestLastDiagnosticsDate} = mktime(0, 0, 0, $2, $1 - 1, $3 - 1900);
    $self->{upsAdvTestLastDiagnosticsAge} = (time - $self->{upsAdvTestLastDiagnosticsDate}) / (3600 * 24);
  };
  if ($@) {
    $self->{upsAdvTestLastDiagnosticsDate} = 0;
  }
  $self->get_snmp_tables('PowerNet-MIB', [
    ["sensors", "uioSensorStatusTable", "CheckUpsHealth::APC::Powermib::UPS::Component::EnvironmentalSubsystem::Sensor"],
    ["sensorconfigs", "uioSensorConfigTable", "Monitoring::GLPlugin::SNMP::TableItem"],
  ]);
  foreach my $sensor (@{$self->{sensors}}) {
    foreach my $config (@{$self->{sensorconfigs}}) {
      if ($config->{flat_indices} eq $sensor->{flat_indices}) {
        foreach my $key (keys %{$config}) {
          $sensor->{$key} = $config->{$key} if $key =~ /^uio/;
        }
      }
    }
  }
  delete $self->{sensorconfigs};
}

sub check {
  my ($self) = @_;
  my $info = undef;
  $self->add_info('checking hardware and self-tests');
  if (defined $self->{upsBasicStateOutputState}) {
    my @bits = split(//, $self->{upsBasicStateOutputState});
    if (scalar(@bits) == 64) {
      $self->add_unknown('status unknown');
    } else {
      $self->add_ok('On Line') if $bits[4];
      #$self->add_ok('Serial Communication Established') if $bits[6];
      #$self->add_ok('On') if $bits[19];
      $self->add_warning('Abnormal Condition Present') if $bits[1];
      $self->add_warning('Electronic Unit Fan Failure') if $bits[41];
      $self->add_warning('Main Relay Failure') if $bits[42];
      $self->add_warning('Bypass Relay Failure') if $bits[43];
      $self->add_warning('High Internal Temperature') if $bits[45];
      $self->add_warning('Battery Temperature Sensor Fault') if $bits[46];
      $self->add_warning('PFC Failure') if $bits[49];
      $self->add_critical('Critical Hardware Fault') if $bits[50];
      $self->add_critical('Emergency Power Off (EPO) Activated') if $bits[53];
      $self->add_warning('UPS Internal Communication Failure') if $bits[56];
    }
  }
  if ($self->{upsAdvTestLastDiagnosticsDate}) {
    # 28.2.24 nr.2
    # Litauische USV hat zwar upsAdvTestLastDiagnosticsDate, aber ein
    # undefined upsAdvTestDiagnosticsResults. Lieber Archaeologe, da siehst du mal,
    # mit welcher Scheisse sich die Menschen anno 24 herumschlagen mussten, speziell ich.
    if (! defined $self->{upsAdvTestDiagnosticsResults}) {
      $self->{upsAdvTestDiagnosticsResults} = "....i forgot it";
    }
    $self->add_info(sprintf 'selftest result was %s',
        $self->{upsAdvTestDiagnosticsResults});
    if ($self->{upsAdvTestDiagnosticsResults} ne 'ok') {
      $self->add_warning();
    } else {
      $self->add_ok();
    } 
    my $maxage = undef;
    if (! defined $self->{upsAdvTestDiagnosticSchedule}) {
      # 28.2.24
      # sollte nicht vorkommen, aber dennoch kommt es vor. Zypriotische USV hat hier
      # keinen Wert und schmeisst demzufolge in den naechsten Zeilen lauter undefined-Zeugs.
      # Und um mich zu aergern zeigt das Ding beim Debuggen dann doch was an:
      # upsAdvTestDiagnosticSchedule: biweekly
      # Keine Ahnung, warum das verloren geht, zumal die Kommunikation in einer Sekunde
      # ueber die Buehne geht.
      $self->{upsAdvTestDiagnosticSchedule} = "glump varreckts";
    }
    if ($self->{upsAdvTestDiagnosticSchedule} eq 'never') {
      $maxage = 365;
    } elsif ($self->{upsAdvTestDiagnosticSchedule} eq 'biweekly') {
      $maxage = 14;
    } elsif ($self->{upsAdvTestDiagnosticSchedule} eq 'weekly') {
      $maxage = 7;
    } elsif ($self->{upsAdvTestDiagnosticSchedule} eq 'fourWeeks') {
      $maxage = 28;
    } elsif ($self->{upsAdvTestDiagnosticSchedule} eq 'twelveWeeks') {
      $maxage = 84;
    } elsif ($self->{upsAdvTestDiagnosticSchedule} eq 'biweeklySinceLastTest') {
      $maxage = 14;
    } elsif ($self->{upsAdvTestDiagnosticSchedule} eq 'weeklySinceLastTest') {
      $maxage = 7;
    }
    if (! defined $maxage && $self->{upsAdvTestDiagnosticSchedule} ne 'never') {
      $self->set_thresholds(
          metric => 'selftest_age', warning => '30', critical => '60');
    } else {
      $maxage *= 2; # got lots of alerts from my test devices
      $self->set_thresholds(
          metric => 'selftest_age', warning => $maxage, critical => $maxage);
    }
    $self->add_info(sprintf 'last selftest was %d days ago (%s)', $self->{upsAdvTestLastDiagnosticsAge}, scalar localtime $self->{upsAdvTestLastDiagnosticsDate});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsAdvTestLastDiagnosticsAge},
            metric => 'selftest_age'));
    $self->add_perfdata(
        label => 'selftest_age',
        value => $self->{upsAdvTestLastDiagnosticsAge},
    );
  } else {
    $self->add_ok("hardware working fine, at least i hope so, because self-tests were never run") if ! $self->check_messages();
    $self->add_ok("self-tests were never run") if $self->check_messages();
  }
  foreach my $sensor (@{$self->{sensors}}) {
    $sensor->check();
  }
}


package CheckUpsHealth::APC::Powermib::UPS::Component::EnvironmentalSubsystem::Simple;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

package CheckUpsHealth::APC::Powermib::UPS::Component::EnvironmentalSubsystem::Advanced;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

package CheckUpsHealth::APC::Powermib::UPS::Component::EnvironmentalSubsystem::Sensor;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  # Port 2 Temp 2, Port 1 Temp 1 sind uioSensorStatusSensorName
  $self->{label_temp} = lc($self->{uioSensorStatusSensorName} =~ s/ /_/gr);
  $self->{label_hum} = $self->{label_temp} =~ s/temp/hum/gr;
}

sub check {
  my ($self) = @_;
  $self->add_info(sprintf "sensor %s has status %s",
      $self->{uioSensorStatusSensorName},
      lc(substr($self->{uioSensorStatusAlarmStatus}, 3)));
  if ($self->{uioSensorStatusAlarmStatus} eq "uioWarning") {
    $self->add_warning();
  } elsif ($self->{uioSensorStatusAlarmStatus} eq "uioCritical") {
    $self->add_critical();
  } elsif ($self->{uioSensorStatusAlarmStatus} eq "sensorStatusNotApplicable") {
  } else {
    $self->add_ok();
  }
  if ($self->{uioSensorStatusHumidity} != -1) {
    # uioSensorConfigTable may be empty ot not reachable, avoid undef warnings
    foreach (qw(uioSensorConfigLowHumidityThreshold
        uioSensorConfigHighHumidityThreshold
        uioSensorConfigMinHumidityThreshold
        uioSensorConfigMaxHumidityThreshold)) {
      $self->{$_} = -1 if not defined $self->{$_};
    }
    my $warn =
        ($self->{uioSensorConfigLowHumidityThreshold} and $self->{uioSensorConfigLowHumidityThreshold} != -1 ?
        $self->{uioSensorConfigLowHumidityThreshold} : '').':'.
        ($self->{uioSensorConfigHighHumidityThreshold} and $self->{uioSensorConfigHighHumidityThreshold} != -1 ?
        $self->{uioSensorConfigHighHumidityThreshold} : '');
    my $crit =
        ($self->{uioSensorConfigMinHumidityThreshold} and $self->{uioSensorConfigMinHumidityThreshold} != -1 ?
        $self->{uioSensorConfigMinHumidityThreshold} : '').':'.
        ($self->{uioSensorConfigMaxHumidityThreshold} and $self->{uioSensorConfigMaxHumidityThreshold} != -1 ?
        $self->{uioSensorConfigMaxHumidityThreshold} : '');
    $warn = undef if $warn eq ':';
    $crit = undef if $crit eq ':';
    $self->add_thresholds(metric => $self->{label_hum},
        warning => $warn, critical => $crit);
    $self->add_perfdata(
      label => $self->{label_hum},
      value => $self->{uioSensorStatusHumidity},
      uom => "%",
      warning => $warn, critical => $crit,
    );
  }
  if ($self->{uioSensorStatusTemperatureDegC} != -1) {
    # uioSensorConfigTable may be empty ot not reachable, avoid undef warnings
    foreach (qw(uioSensorConfigLowTemperatureThreshold
        uioSensorConfigHighTemperatureThreshold
        uioSensorConfigMinTemperatureThreshold
        uioSensorConfigMaxTemperatureThreshold)) {
      $self->{$_} = -1 if not defined $self->{$_};
    }
    my $warn =
        ($self->{uioSensorConfigLowTemperatureThreshold} and $self->{uioSensorConfigLowTemperatureThreshold} != -1 ?
        $self->{uioSensorConfigLowTemperatureThreshold} : '').':'.
        ($self->{uioSensorConfigHighTemperatureThreshold} and $self->{uioSensorConfigHighTemperatureThreshold} != -1 ?
        $self->{uioSensorConfigHighTemperatureThreshold} : '');
    my $crit =
        ($self->{uioSensorConfigMinTemperatureThreshold} and $self->{uioSensorConfigMinTemperatureThreshold} != -1 ?
        $self->{uioSensorConfigMinTemperatureThreshold} : '').':'.
        ($self->{uioSensorConfigMaxTemperatureThreshold} and $self->{uioSensorConfigMaxTemperatureThreshold} != -1 ?
        $self->{uioSensorConfigMaxTemperatureThreshold} : '');
    $warn = undef if $warn eq ':';
    $crit = undef if $crit eq ':';
    $self->add_thresholds(metric => $self->{label_temp},
        warning => $warn, critical => $crit);
    $self->add_perfdata(
      label => $self->{label_temp},
      value => $self->{uioSensorStatusTemperatureDegC},
      warning => $warn, critical => $crit,
    );
  }
}

