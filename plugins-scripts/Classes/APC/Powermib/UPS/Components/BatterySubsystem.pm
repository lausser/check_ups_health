package Classes::APC::Powermib::UPS::Components::BatterySubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;
use POSIX qw(mktime);

sub init {
  my ($self) = @_;
  $self->get_snmp_objects('PowerNet-MIB', (qw(
      upsBasicBatteryStatus upsAdvBatteryCapacity 
      upsAdvBatteryReplaceIndicator upsAdvBatteryTemperature 
      upsAdvBatteryRunTimeRemaining 
      upsAdvInputLineVoltage upsAdvInputFrequency 
      upsAdvInputMaxLineVoltage upsAdvInputMinLineVoltage 
      upsAdvOutputVoltage upsAdvOutputFrequency 
      upsBasicOutputStatus upsAdvOutputLoad upsAdvOutputCurrent
      upsHighPrecOutputLoad  
      upsAdvTestLastDiagnosticsDate upsAdvTestDiagnosticTime
      upsAdvInputLineFailCause)));
  $self->{upsAdvBatteryRunTimeRemaining} = $self->{upsAdvBatteryRunTimeRemaining} / 6000;
  # beobachtet bei Smart-Classes RT 1000 RM XL, da gab's nur
  # upsAdvOutputVoltage und upsAdvOutputFrequency
  $self->{upsAdvOutputLoad} = 
      ! defined $self->{upsAdvOutputLoad} || $self->{upsAdvOutputLoad} eq '' ?
      $self->{upsHighPrecOutputLoad} / 10 : $self->{upsAdvOutputLoad};
  # wer keine Angaben macht, gilt als gesund.
  $self->{upsBasicBatteryStatus} ||= 'batteryNormal';
  eval {
    die if ! $self->{upsAdvTestLastDiagnosticsDate};
    $self->{upsAdvTestLastDiagnosticsDate} =~ /(\d+)\/(\d+)\/(\d+)/ || die;
    my($tmon, $tday, $tyear) = ($1, $2, $3);
    $self->{upsAdvTestLastDiagnosticsDate} = mktime(0, 0, 0, $tday, $tmon - 1, $tyear - 1900);
    my $seconds = 0;
    if ($self->{upsAdvTestDiagnosticTime}) {
      $self->{upsAdvTestDiagnosticTime} =~ /(\d+):(\d+)/;
      $seconds = $1 * 3600 + $2 * 60;
    } else {
      my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
      $mon += 1; $year += 1900;
      # war der letzte test heute?
      if ($tyear == $year and $tmon == $mon and $tday == $mday) {
        # falls keine naehere Information vorliegt oder veraltete Information
        # dann wird der jetzige Zeitpunkt als Testzeitpunkt angenommen.
        my $test_info = $self->load_state(name => "test_info");
        if (! $test_info) {
          $seconds = $hour * 3600 + $min * 60 + $sec;
          $self->save_state(name => "test_info", save => {
              upsAdvTestLastDiagnosticsDate => $self->{upsAdvTestLastDiagnosticsDate},
              upsAdvTestDiagnosticTime => $seconds,
          });
        } elsif ($test_info->{upsAdvTestLastDiagnosticsDate} == $self->{upsAdvTestLastDiagnosticsDate}) {
          $seconds = $test_info->{upsAdvTestDiagnosticTime};
        } else {
          $seconds = $hour * 3600 + $min * 60 + $sec;
          $self->save_state(name => "test_info", save => {
              upsAdvTestLastDiagnosticsDate => $self->{upsAdvTestLastDiagnosticsDate},
              upsAdvTestDiagnosticTime => $seconds,
          });
        }
      }
    }
    # der Testtag wird um eine Uhrzeit ergaenzt.
    $self->{upsAdvTestLastDiagnosticsDate} += $seconds;
    $self->{upsAdvTestLastDiagnosticsAgeHours} = (time - $self->{upsAdvTestLastDiagnosticsDate}) / 3600;
  };
  if ($@) {
    # ersatzweise wird angenommen, dass der letzte Selftest eine Woche her ist
    $self->{upsAdvTestLastDiagnosticsAgeHours} = 24*7;
  }
}

sub check {
  # CRITICAL - capacity is 76.00%, battery status is batteryNormal, output load 22.00%, temperature is 25.00C, remaining battery run time is 136.00min
  my ($self) = @_;
  $self->add_info('checking battery');
  $self->add_info(sprintf 'battery status is %s',
      $self->{upsBasicBatteryStatus});
  if ($self->{upsBasicBatteryStatus} ne 'batteryNormal') {
    $self->add_critical();
  } else {
    $self->add_ok();
  } 
  if ($self->{upsAdvBatteryReplaceIndicator} && $self->{upsAdvBatteryReplaceIndicator} eq 'batteryNeedsReplacing') {
    $self->add_critical('battery needs replacing');
  }
  if ($self->{upsBasicOutputStatus}) { # kann auch undef sein (10kv z.b.)
    if ($self->{upsBasicOutputStatus} eq 'onBattery' &&
        $self->{upsAdvInputLineFailCause} eq 'selfTest') {
      $self->add_ok(sprintf 'output status is %s',
          $self->{upsBasicOutputStatus});
      $self->add_ok(sprintf 'caused by %s',
          $self->{upsAdvInputLineFailCause});
    } elsif ($self->{upsBasicOutputStatus} ne 'onLine') {
      $self->add_warning(sprintf 'output status is %s',
          $self->{upsBasicOutputStatus});
      $self->add_warning(sprintf 'caused by %s',
          $self->{upsAdvInputLineFailCause});
    }
  }
  my $relaxed_thresholds = 0;
  if ($self->{upsBasicOutputStatus} and
      $self->{upsBasicOutputStatus} eq 'onBattery' and
      $self->{upsAdvInputLineFailCause} eq 'selfTest') {
    $relaxed_thresholds = 1;
  } elsif ($self->{upsAdvTestLastDiagnosticsAgeHours} <= 4) {
    # nach dem Selbsttest kann es eine Weile dauern, bis die Batterie wieder
    # volle Kapazitaet hat.
    $relaxed_thresholds = 1;
  }

  $self->set_thresholds(
      metric => 'capacity', warning => '25:', critical => '10:');
  my ($warn, $crit) = $self->get_thresholds(metric => 'capacity');
  if ($relaxed_thresholds && $self->check_thresholds(
          value => $self->{upsAdvBatteryCapacity},
          metric => 'capacity')) {
    # Schwellwerte halbieren, da beim Selbsttest durchaus ein paar Prozent
    # verloren gehen.
    $self->add_ok("lowered thresholds");
    (my $nwarn = $warn) =~ s/:$//g;
    (my $ncrit = $crit) =~ s/:$//g;
    $nwarn /= 2;
    $ncrit /= 2;
    $warn = $nwarn.':';
    $crit = $ncrit.':';
  }
  $self->add_info(sprintf 'capacity is %.2f%%', $self->{upsAdvBatteryCapacity});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsAdvBatteryCapacity},
          metric => 'capacity',
          warning => $warn,
          critical => $crit));
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{upsAdvBatteryCapacity},
      uom => '%',
      warning => $warn,
      critical => $crit,
  );

  $self->set_thresholds(
      metric => 'output_load', warning => '75', critical => '85');
  $self->add_info(sprintf 'output load %.2f%%', $self->{upsAdvOutputLoad});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsAdvOutputLoad},
          metric => 'output_load'));
  $self->add_perfdata(
      label => 'output_load',
      value => $self->{upsAdvOutputLoad},
      uom => '%',
  );

  if (defined $self->{upsAdvBatteryTemperature}) {
    $self->set_thresholds(
        metric => 'battery_temperature', warning => '70', critical => '80');
    $self->add_info(sprintf 'temperature is %.2fC', $self->{upsAdvBatteryTemperature});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsAdvBatteryTemperature},
            metric => 'battery_temperature'));
    $self->add_perfdata(
        label => 'battery_temperature',
        value => $self->{upsAdvBatteryTemperature},
    );
  }

  $self->set_thresholds(
      metric => 'remaining_time', warning => '10:', critical => '8:');
  $self->add_info(sprintf 'remaining battery run time is %.2fmin', $self->{upsAdvBatteryRunTimeRemaining});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsAdvBatteryRunTimeRemaining},
          metric => 'remaining_time'));
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{upsAdvBatteryRunTimeRemaining},
  );

  if (defined $self->{upsAdvInputLineVoltage} && $self->{upsAdvInputLineVoltage} < 1 && $self->{upsAdvBatteryCapacity} < 90) {
    # upsAdvInputLineVoltage can be noTransfer after spikes or selftests.
    # this might be tolerable as long as the battery is full.
    # only when external voltage is needed this should raise an alarm
    # (< 100 is not enough, even under normal circumstances the capacity drops
    # below 100)
    $self->add_critical('input power outage');
    if ($self->{upsAdvInputLineFailCause}) {
      $self->add_critical($self->{upsAdvInputLineFailCause});
      if ($self->{upsAdvInputLineFailCause} eq 'noTransfer') {
        $self->add_critical('please repeat self-tests or reboot');
      }
    }
  }
  $self->add_perfdata(
      label => 'input_voltage',
      value => $self->{upsAdvInputLineVoltage},
  ) if defined $self->{upsAdvInputLineVoltage};
  $self->add_perfdata(
      label => 'input_frequency',
      value => $self->{upsAdvInputFrequency},
  ) if defined $self->{upsAdvInputFrequency};
  $self->add_perfdata(
      label => 'output_voltage',
      value => $self->{upsAdvOutputVoltage},
  ) if defined $self->{upsAdvOutputVoltage};;
  $self->add_perfdata(
      label => 'output_frequency',
      value => $self->{upsAdvOutputFrequency},
  ) if defined $self->{upsAdvOutputFrequency};
}

sub dump {
  my ($self) = @_;
  printf "[BATTERY]\n";
  foreach (qw(
      upsBasicBatteryStatus upsAdvBatteryCapacity
      upsAdvBatteryReplaceIndicator upsAdvBatteryTemperature 
      upsAdvBatteryRunTimeRemaining 
      upsAdvInputLineVoltage upsAdvInputFrequency 
      upsAdvInputMaxLineVoltage upsAdvInputMinLineVoltage 
      upsAdvOutputVoltage upsAdvOutputFrequency 
      upsBasicOutputStatus upsAdvOutputLoad upsAdvOutputCurrent
      upsHighPrecOutputLoad
      upsAdvTestLastDiagnosticsDate upsAdvTestDiagnosticTime
      upsAdvInputLineFailCause)) {
    printf "%s: %s\n", $_, $self->{$_} if defined $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}
