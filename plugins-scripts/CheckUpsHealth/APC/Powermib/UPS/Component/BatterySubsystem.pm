package CheckUpsHealth::APC::Powermib::UPS::Component::BatterySubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;
use POSIX qw(mktime);

sub init {
  my ($self) = @_;
  $self->{diag} = {};
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
  foreach my $key (qw(
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
    $self->{diag}->{$key} = $self->{$key};
  }
  if (defined $self->{upsAdvBatteryRunTimeRemaining}) {
    $self->{upsAdvBatteryRunTimeRemaining} =
        $self->{upsAdvBatteryRunTimeRemaining} / 6000;
  }
  # beobachtet bei Smart-Classes RT 1000 RM XL, da gab's nur
  # upsAdvOutputVoltage und upsAdvOutputFrequency
  # ergaenzt 4.4.24, APC Web/SNMP Management/Embedded PowerNet SNMP Agent SW v2.2 compatible hat gar nichts in der Art
  if (defined $self->{upsAdvOutputLoad} and $self->{upsAdvOutputLoad} ne '') {
    # passt
  } elsif (defined $self->{upsHighPrecOutputLoad}) {
    $self->{upsAdvOutputLoad} = $self->{upsHighPrecOutputLoad} / 10;
  } else {
    # gabs nicht oder war leer
    $self->{upsAdvOutputLoad} = undef;
  }
  # wer keine Angaben macht, gilt als gesund.
  $self->{upsBasicBatteryStatus} ||= 'batteryNormal';
  $self->{upsAdvTestLastDiagnosticsTrace} = "";
  eval {
    die if ! $self->{upsAdvTestLastDiagnosticsDate};
    $self->{upsAdvTestLastDiagnosticsTrace} .=
        sprintf "upsAdvTestLastDiagnosticsDate is %s",
        $self->{upsAdvTestLastDiagnosticsDate};
    $self->{upsAdvTestLastDiagnosticsDate} =~ /(\d+)\/(\d+)\/(\d+)/ || die;
    my($tmon, $tday, $tyear) = ($1, $2, $3);
    $self->{upsAdvTestLastDiagnosticsDate} = mktime(0, 0, 0, $tday, $tmon - 1, $tyear - 1900);
    my $seconds = 0;
    if (defined $self->{upsAdvTestDiagnosticTime}) {
      $self->{upsAdvTestLastDiagnosticsTrace} .=
          sprintf " upsAdvTestDiagnosticTime is %s",
          $self->{upsAdvTestDiagnosticTime};
      $self->{upsAdvTestDiagnosticTime} =~ /(\d+):(\d+)/;
      $seconds = $1 * 3600 + $2 * 60;
    } else {
      my ($sec,$min,$hour,$mday,$mon,$year,$wday,$yday,$isdst) = localtime(time);
      $mon += 1; $year += 1900;
      $self->{upsAdvTestLastDiagnosticsTrace} .=
          sprintf " upsAdvTestDiagnosticFakeTime is %s", scalar localtime time;
      # war der letzte test heute?
      if ($tyear == $year and $tmon == $mon and $tday == $mday) {
        $self->{upsAdvTestLastDiagnosticsTrace} .= " today";
        # falls keine naehere Information vorliegt oder veraltete Information
        # dann wird der jetzige Zeitpunkt als Testzeitpunkt angenommen.
        my $test_info = $self->load_state(name => "test_info");
        if (! $test_info) {
          $seconds = $hour * 3600 + $min * 60 + $sec;
          $self->{upsAdvTestLastDiagnosticsTrace} .=
              sprintf " seconds %d", $seconds;
          $self->save_state(name => "test_info", save => {
              upsAdvTestLastDiagnosticsDate => $self->{upsAdvTestLastDiagnosticsDate},
              upsAdvTestDiagnosticTime => $seconds,
          });
        } elsif ($test_info->{upsAdvTestLastDiagnosticsDate} == $self->{upsAdvTestLastDiagnosticsDate}) {
          $seconds = $test_info->{upsAdvTestDiagnosticTime};
          $self->{upsAdvTestLastDiagnosticsTrace} .=
              sprintf " loaded seconds %d", $seconds;
        } else {
          $seconds = $hour * 3600 + $min * 60 + $sec;
          $self->save_state(name => "test_info", save => {
              upsAdvTestLastDiagnosticsDate => $self->{upsAdvTestLastDiagnosticsDate},
              upsAdvTestDiagnosticTime => $seconds,
          });
          $self->{upsAdvTestLastDiagnosticsTrace} .=
              sprintf " saved seconds %d", $seconds;
        }
      }
    }
    # der Testtag wird um eine Uhrzeit ergaenzt.
    $self->{upsAdvTestLastDiagnosticsDate} += $seconds;
    $self->{upsAdvTestLastDiagnosticsAgeHours} = (time - $self->{upsAdvTestLastDiagnosticsDate}) / 3600;
  };
  if ($@) {
    $self->{upsAdvTestLastDiagnosticsTrace} .= "no date";
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
    } elsif ($self->{upsBasicOutputStatus} ne 'onLine' &&
        $self->{upsBasicOutputStatus} ne 'eConversion') {
      $self->add_warning(sprintf 'output status is %s',
          $self->{upsBasicOutputStatus});
      $self->add_warning(sprintf 'caused by %s',
          $self->{upsAdvInputLineFailCause});
    }
  }
  my $relaxed_thresholds = 0;
  # braucht bis zu 6, nein, 7 Stunden, um nach dem Selftest wieder normal zu werden. So a Glump.
  $self->opts->override_opt('lookback', 7) if ! $self->opts->lookback;
  if ($self->{upsBasicOutputStatus} and
      $self->{upsBasicOutputStatus} eq 'onBattery' and
      $self->{upsAdvInputLineFailCause} eq 'selfTest') {
    $relaxed_thresholds = 1;
  } elsif ($self->{upsAdvTestLastDiagnosticsAgeHours} <= $self->opts->lookback) {
    # nach dem Selbsttest kann es eine Weile dauern, bis die Batterie wieder
    # volle Kapazitaet hat.
    $relaxed_thresholds = 1;
  }

  if (defined $self->{upsAdvBatteryCapacity}) {
    # hat nicht jeder
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
    if ($self->check_thresholds(
        value => $self->{upsAdvBatteryCapacity},
        metric => 'capacity',
        warning => $warn,
        critical => $crit)) {
      $self->annotate_info(sprintf "last selftest was %.2fh ago",
          $self->{upsAdvTestLastDiagnosticsAgeHours});
      $self->annotate_info(sprintf "trace %s",
          $self->{upsAdvTestLastDiagnosticsTrace});
      $self->annotate_info(sprintf "diag %s",
          Data::Dumper::Dumper($self->{diag}));
    }
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
  }

  if (defined $self->{upsAdvOutputLoad}) {
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
  }

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

  if (defined $self->{upsAdvBatteryRunTimeRemaining}) {
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
  }

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

__END__
Gibt so Billigteile? wie den hier
I am a APC Web/SNMP Management Card (MB:v4.2.9 PF:v2.5.0.8 PN:apc_hw21_aos_2.5.0.8.bin AF1:v2.5.0.1 AN1:apc_hw21_eu3p_2.5.0.1.bin MN:AP9547 HR:3 SN: QA2429170925 MD:07/20/2024) (Embedded PowerNet SNMP Agent SW v2.2 compatible)
mit eingeschraenkten OIDs
diag $VAR1 = {
  'upsAdvInputMaxLineVoltage' => undef,
  'upsAdvOutputVoltage' => undef,
  'upsHighPrecOutputLoad' => undef,
  'upsAdvOutputLoad' => undef,
  'upsAdvInputLineFailCause' => 'noTransfer',
  'upsAdvBatteryTemperature' => undef,
  'upsAdvInputMinLineVoltage' => undef,
  'upsAdvInputFrequency' => undef,
  'upsAdvOutputFrequency' => undef,
  'upsBasicBatteryStatus' => 'batteryNormal',
  'upsAdvOutputCurrent' => undef,
  'upsAdvTestLastDiagnosticsDate' => undef,
  'upsAdvTestDiagnosticTime' => undef,
  'upsAdvBatteryCapacity' => undef,
  'upsAdvBatteryRunTimeRemaining' => '19656000',
  'upsAdvBatteryReplaceIndicator' => undef,
  'upsBasicOutputStatus' => 'onLine',
  'upsAdvInputLineVoltage' => undef
};
Es gibt nur diese:
  'upsAdvInputLineFailCause' => 'noTransfer',
  'upsBasicBatteryStatus' => 'batteryNormal',
  'upsAdvBatteryRunTimeRemaining' => '19656000',
  'upsBasicOutputStatus' => 'onLine',

