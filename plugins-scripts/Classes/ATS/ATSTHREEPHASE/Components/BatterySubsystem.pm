package Classes::ATS::ATSTHREEPHASE::Components::BatterySubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->get_snmp_objects("ATS-THREEPHASE-MIB", qw(sysUpsRecInputPresentOk sysUpsBypInputPresentOk
      sysUpsOperationMode sysUpsOutputSource sysUpsBatteryDischargerOn
      sysUpsBatteryChargerOn sysUpsLoadOnManualBypass sysUpsBatteryStatus
      sysUpsBatteryGroupRemainingCapacity sysUpsBatteryGroupRemainingRunTime
      sysUpsBatteryGroupPositiveTotalBatteryVoltage sysUpsBatteryGroupNegativeTotalBatteryVoltage
      sysUpsBatteryGroupPositiveBatteryVoltagePerCell sysUpsBatteryGroupNegativeBatteryVoltagePerCell
      sysUpsBatteryGroupChargingWatt sysUpsBatteryGroupDischargingWatt
      sysUpsBatteryGroupPositiveBatteryChargerCurrent sysUpsBatteryGroupNegativeBatteryChargerCurrent
      sysUpsBatteryGroupPositiveBatteryDischargerCurrent sysUpsBatteryGroupNegativeBatteryDischargerCurrent


  ));
  $self->get_snmp_tables("ATS-THREEPHASE-MIB", [
      ["batteries", "upsBatteryGroupTable", "Classes::ATS::ATSTHREEPHASE::Components::BatterySubsystem::Battery"],
      ["sysbatteries", "", "Monitoring::GLPlugin::SNMP::TableItem"],
      ["load", "upsLoadGroupTable", "Classes::ATS::ATSTHREEPHASE::Components::BatterySubsystem::Load"],
      ["inputs", "upsInputGroupTable", "Classes::ATS::ATSTHREEPHASE::Components::BatterySubsystem::Input"],
      ["outputs", "upsOutputGroupTable", "Classes::ATS::ATSTHREEPHASE::Components::BatterySubsystem::Output"],
      ["bypass", "upsBypassGroupTable", "Classes::ATS::ATSTHREEPHASE::Components::BatterySubsystem::Bypass"],
      ["wkstatus", "upsStatusGroupTable", "Classes::ATS::ATSTHREEPHASE::Components::BatterySubsystem::WKStatus"], #upsWellKnownStatusTable

  ]);
  @{$self->{batteries}} = grep { $_->{valid} } @{$self->{batteries}};
  @{$self->{wkstatus}} = grep { $_->{valid} } @{$self->{wkstatus}};
  @{$self->{inputs}} = grep { $_->{valid} } @{$self->{inputs}};
  @{$self->{outputs}} = grep { $_->{valid} } @{$self->{outputs}};
  @{$self->{bypass}} = grep { $_->{valid} } @{$self->{bypass}};
  @{$self->{load}} = grep { $_->{valid} } @{$self->{load}};
}

sub xcheck {
  my ($self) = @_;
  $self->add_info('checking battery');

  if (defined $self->{upsBatteryTemperature}) {
    $self->set_thresholds(
        metric => 'battery_temperature', warning => '35', critical => '38');
    $self->add_info(sprintf 'temperature is %.2fC', $self->{upsBatteryTemperature});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsBatteryTemperature},
            metric => 'battery_temperature'));
    $self->add_perfdata(
        label => 'battery_temperature',
        value => $self->{upsBatteryTemperature},
    );
  }

  if ($self->{upsSecondsOnBattery}) {
    $self->set_thresholds(
        metric => 'remaining_time', warning => '15:', critical => '10:');
    $self->add_info(sprintf 'remaining battery run time is %.2fmin', $self->{upsEstimatedMinutesRemaining});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsEstimatedMinutesRemaining},
            metric => 'remaining_time'));
  } else {
    $self->set_thresholds(
        metric => 'remaining_time', warning => '0:', critical => '0:');
    # do not evaluate with check_thresholds, because there might be
    # higher thresholds set by warningx/criticalx
    $self->add_ok('unit is not on battery power');
  }
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{upsEstimatedMinutesRemaining},
  );

  if (defined $self->{upsEstimatedChargeRemaining}) {
    $self->set_thresholds(
        metric => 'capacity', warning => '25:', critical => '10:');
    $self->add_info(sprintf 'capacity is %.2f%%', $self->{upsEstimatedChargeRemaining});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsEstimatedChargeRemaining},
            metric => 'capacity'));
    $self->add_perfdata(
        label => 'capacity',
        value => $self->{upsEstimatedChargeRemaining},
        uom => '%',
    );
  }

  if (defined ($self->{upsBatteryVoltage})) {
    $self->add_info(sprintf 'battery voltage is %d VDC', $self->{upsBatteryVoltage});
    $self->add_perfdata(
      label => 'battery_voltage',
      value => $self->{upsBatteryVoltage},
    );
  }

  $self->add_perfdata(
      label => 'output_frequency',
      value => $self->{upsOutputFrequency},
  );

  foreach (@{$self->{inputs}}) {
    $_->check();
  }
  foreach (@{$self->{outputs}}) {
    $_->check();
  }

  if ($self->{upsBatteryStatus} && $self->{upsBatteryStatus} ne "batteryNormal") {
    $self->add_critical("battery has status: ".$self->{upsBatteryStatus});
  }
}

sub xdump {
  my ($self) = @_;
  printf "[BATTERY]\n";
  foreach (grep /^ups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
  foreach (@{$self->{inputs}}) {
    $_->dump();
  }
  foreach (@{$self->{outputs}}) {
    $_->dump();
  }
}


package Classes::ATS::ATSTHREEPHASE::Components::BatterySubsystem::Battery;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{valid} = 0;
  foreach (qw(upsBatteryGroupPositiveBatteryVoltagePerCell
      upsBatteryGroupNegativeBatteryVoltagePerCell
      upsBatteryGroupNegativeTotalBatteryVoltage
      upsBatteryGroupPositiveTotalBatteryVoltage)) {
    if ($self->{$_}) {
      $self->{valid} = 1;
    }
  }
  if ($self->{valid}) {
    $self->{upsBatteryGroupRemainingCapacity} /= 10;
    foreach (qw(upsBatteryGroupPositiveTotalBatteryVoltage
        upsBatteryGroupNegativeTotalBatteryVoltage upsBatteryGroupPositiveBatteryVoltagePerCell
        upsBatteryGroupNegativeBatteryVoltagePerCell upsBatteryGroupChargingWatt
        upsBatteryGroupDischargingWatt upsBatteryGroupPositiveBatteryChargerCurrent
        upsBatteryGroupNegativeBatteryChargerCurrent upsBatteryGroupPositiveBatteryDischargerCurrent
        upsBatteryGroupNegativeBatteryDischargerCurrent)) {
      $self->{$_} /= 100;
    }
  }
}

sub check {
  my ($self) = @_;
  $self->set_thresholds(
      metric => 'capacity', warning => '25:', critical => '10:');
  $self->add_info(sprintf 'capacity is %.2f%%', $self->{upsBatteryGroupRemainingCapacity});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsBatteryGroupRemainingCapacity},
          metric => 'capacity'));
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{upsBatteryGroupRemainingCapacity},
      uom => '%',
  );
  if ($self->{upsBatteryGroupRemainingRunTime}) {
    $self->set_thresholds(
        metric => 'remaining_time', warning => '15:', critical => '10:');
    $self->add_info(sprintf 'remaining battery run time is %.2fmin', $self->{upsBatteryGroupRemainingRunTime});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsBatteryGroupRemainingRunTime},
            metric => 'remaining_time'));
  } else {
    $self->set_thresholds(
        metric => 'remaining_time', warning => '0:', critical => '0:');
    # do not evaluate with check_thresholds, because there might be
    # higher thresholds set by warningx/criticalx
    $self->add_ok('unit is not on battery power');
  }
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{upsBatteryGroupRemainingRunTime},
  );
}


package Classes::ATS::ATSTHREEPHASE::Components::BatterySubsystem::Input;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{valid} = 0;
  foreach (qw(upsInputGroupCurrentR upsInputGroupCurrentS
      upsInputGroupCurrentT)) {
    if ($self->{$_}) {
      $self->{valid} = 1;
    }
  }
  foreach (grep /^upsInput/, keys %{$self}) {
    $self->{$_} /= 10;
  }
}

sub check {
  my ($self) = @_;
  if ($self->{upsInputGroupVoltageR} < 1 && $self->{upsInputGroupVoltageS} < 1 &&
      $self->{upsInputGroupVoltageT}) {
    $self->add_critical(sprintf 'input power%s outage', $self->{flat_indices});
  }
  $self->add_perfdata(
      label => 'input_voltageR'.$self->{flat_indices},
      value => $self->{upsInputGroupVoltageR},
  );
  $self->add_perfdata(
      label => 'input_voltageS'.$self->{flat_indices},
      value => $self->{upsInputGroupVoltageS},
  );
  $self->add_perfdata(
      label => 'input_voltageT'.$self->{flat_indices},
      value => $self->{upsInputGroupVoltageT},
  );
  $self->add_perfdata(
      label => 'input_frequency'.$self->{flat_indices},
      value => $self->{upsInputGroupFrequency},
  );
  $self->add_perfdata(
      label => 'input_currentR'.$self->{flat_indices},
      value => $self->{upsInputGroupCurrentR},
  );
  $self->add_perfdata(
      label => 'input_currentS'.$self->{flat_indices},
      value => $self->{upsInputGroupCurrentS},
  );
  $self->add_perfdata(
      label => 'input_currentT'.$self->{flat_indices},
      value => $self->{upsInputGroupCurrentT},
  );
}

package Classes::ATS::ATSTHREEPHASE::Components::BatterySubsystem::Output;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{valid} = 0;
  foreach (qw(upsOutputGroupCurrentR upsOutputGroupCurrentS
      upsOutputGroupCurrentT)) {
    if ($self->{$_}) {
      $self->{valid} = 1;
    }
  }
  foreach (grep /^upsOutput/, keys %{$self}) {
    $self->{$_} /= 10;
  }
}

sub check {
  my ($self) = @_;
  $self->add_perfdata(
      label => 'output_voltageR'.$self->{flat_indices},
      value => $self->{upsOutputGroupVoltageR},
  );
  $self->add_perfdata(
      label => 'output_voltageS'.$self->{flat_indices},
      value => $self->{upsOutputGroupVoltageS},
  );
  $self->add_perfdata(
      label => 'output_voltageT'.$self->{flat_indices},
      value => $self->{upsOutputGroupVoltageT},
  );
  $self->add_perfdata(
      label => 'output_frequency'.$self->{flat_indices},
      value => $self->{upsOutputGroupFrequency},
  );
  $self->add_perfdata(
      label => 'output_currentR'.$self->{flat_indices},
      value => $self->{upsOutputGroupCurrentR},
  );
  $self->add_perfdata(
      label => 'output_currentS'.$self->{flat_indices},
      value => $self->{upsOutputGroupCurrentS},
  );
  $self->add_perfdata(
      label => 'output_currentT'.$self->{flat_indices},
      value => $self->{upsOutputGroupCurrentT},
  );
  $self->add_perfdata(
      label => 'output_powerR'.$self->{flat_indices},
      value => $self->{upsOutputGroupPowerFactorR} || 0,
  );
  $self->add_perfdata(
      label => 'output_powerS'.$self->{flat_indices},
      value => $self->{upsOutputGroupPowerFactorS} || 0,
  );
  $self->add_perfdata(
      label => 'output_powerT'.$self->{flat_indices},
      value => $self->{upsOutputGroupPowerFactor} || 0,
  );
}


package Classes::ATS::ATSTHREEPHASE::Components::BatterySubsystem::Bypass;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{valid} = 0;
  foreach (qw(upsBypassGroupCurrentR upsBypassGroupCurrentS
      upsBypassGroupCurrentT)) {
    if ($self->{$_}) {
      $self->{valid} = 1;
    }
  }
  foreach (grep /^upsBypass/, keys %{$self}) {
    $self->{$_} /= 10;
  }
}

sub check {
  my ($self) = @_;
  $self->add_perfdata(
      label => 'bypass_voltageR'.$self->{flat_indices},
      value => $self->{upsBypassGroupVoltageR},
  );
  $self->add_perfdata(
      label => 'bypass_voltageS'.$self->{flat_indices},
      value => $self->{upsBypassGroupVoltageS},
  );
  $self->add_perfdata(
      label => 'bypass_voltageT'.$self->{flat_indices},
      value => $self->{upsBypassGroupVoltageT},
  );
  $self->add_perfdata(
      label => 'bypass_frequency'.$self->{flat_indices},
      value => $self->{upsBypassGroupFrequency},
  );
  $self->add_perfdata(
      label => 'bypass_currentR'.$self->{flat_indices},
      value => $self->{upsBypassGroupCurrentR},
  );
  $self->add_perfdata(
      label => 'bypass_currentS'.$self->{flat_indices},
      value => $self->{upsBypassGroupCurrentS},
  );
  $self->add_perfdata(
      label => 'bypass_currentT'.$self->{flat_indices},
      value => $self->{upsBypassGroupCurrentT},
  );
}


package Classes::ATS::ATSTHREEPHASE::Components::BatterySubsystem::Load;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{valid} = 0;
  foreach (qw(upsLoadGroupLoadR upsLoadGroupLoadS
      upsLoadGroupLoadT)) {
    if ($self->{$_}) {
      $self->{valid} = 1;
    }
  }
  foreach (grep /^upsLoad/, keys %{$self}) {
    $self->{$_} /= 10;
  }
}

sub check {
  my ($self) = @_;
  my $metric = 'output_loadR'.$self->{flat_indices};
  $self->set_thresholds(
      metric => $metric, warning => '75', critical => '85');
  $self->add_info(sprintf 'output loadR%d %.2f%%', $self->{flat_indices}, $self->{upsLoadGroupLoadR});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsLoadGroupLoadR},
          metric => $metric));
  $self->add_perfdata(
      label => $metric,
      value => $self->{upsLoadGroupLoadR},
      uom => '%',
  );
  $metric = 'output_loadS'.$self->{flat_indices};
  $self->set_thresholds(
      metric => $metric, warning => '75', critical => '85');
  $self->add_info(sprintf 'output loadS%d %.2f%%', $self->{flat_indices}, $self->{upsLoadGroupLoadS});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsLoadGroupLoadS},
          metric => $metric));
  $self->add_perfdata(
      label => $metric,
      value => $self->{upsLoadGroupLoadS},
      uom => '%',
  );
  $metric = 'output_loadT'.$self->{flat_indices};
  $self->set_thresholds(
      metric => $metric, warning => '75', critical => '85');
  $self->add_info(sprintf 'output loadT%d %.2f%%', $self->{flat_indices}, $self->{upsLoadGroupLoadT});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsLoadGroupLoadT},
          metric => $metric));
  $self->add_perfdata(
      label => $metric,
      value => $self->{upsLoadGroupLoadT},
      uom => '%',
  );
}


package Classes::ATS::ATSTHREEPHASE::Components::BatterySubsystem::WKStatus;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{valid} = 0;
  foreach (qw(upsStatusGroupBatteryStatus
      upsStatusGroupOperationMode upsStatusGroupOutputSource
      upsStatusGroupParallelUnitary)) {
    if ($self->{$_} ne "unknown") {
      $self->{valid} = 1;
    }
  }
}

sub check {
  my ($self) = @_;
  $self->add_info(sprintf "battery status is %s", $self->{upsStatusGroupBatteryStatus});
  if ($self->{upsStatusGroupBatteryStatus} eq "batteryOk") {
    $self->add_ok();
  } elsif ($self->{upsStatusGroupBatteryStatus} eq "batteryLow" ||
       $self->{upsStatusGroupBatteryStatus} eq "batteryWeake" ||
       $self->{upsStatusGroupBatteryStatus} eq "upsOff") {
    $self->add_warning();
  } elsif ($self->{upsStatusGroupBatteryStatus} eq "unknown") {
    $self->add_unknown();
  }
}



