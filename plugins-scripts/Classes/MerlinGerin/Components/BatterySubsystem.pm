package Classes::MerlinGerin::Components::BatterySubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->get_snmp_objects('MG-SNMP-UPS-MIB', (qw(
      upsmgBatteryRemainingTime upsmgBatteryLevel
      upsmgBatteryRechargeTime upsmgBatteryRechargeLevel
      upsmgBatteryVoltage upsmgBatteryCurrent
      upsmgBatteryTemperature upsmgBatteryFullRechargeTime
      upsmgBatteryFaultBattery upsmgBatteryNoBattery
      upsmgBatteryReplacement upsmgBatteryUnavailableBattery
      upsmgBatteryNotHighCharge upsmgBatteryLowBattery
      upsmgBatteryChargerFault upsmgBatteryLowCondition
      upsmgBatteryLowRecharge
      upsmgInputPhaseNum upsmgOutputPhaseNum
      upsmgInputLineFailCause)));
  $self->get_snmp_tables('MG-SNMP-UPS-MIB', [
      ['inputs', 'upsmgInputPhaseTable', 'Classes::MerlinGerin::Components::BatterySubsystem::Input'],
      ['outputs', 'upsmgOutputPhaseTable', 'Classes::MerlinGerin::Components::BatterySubsystem::Output'],
  ]);
  @{$self->{inputs}} = grep {
      defined $_->{mginputFrequency} && defined $_->{mginputVoltage}
  } @{$self->{inputs}};
  @{$self->{inputs}} = splice(@{$self->{inputs}}, 0, $self->{upsmgInputPhaseNum});
  @{$self->{outputs}} = splice(@{$self->{outputs}}, 0, $self->{upsmgOutputPhaseNum});
  $self->{upsmgBatteryVoltage} /= 10;
}

sub check {
  my ($self) = @_;
  $self->add_info('checking battery');
  if ($self->{upsmgBatteryNoBattery} && $self->{upsmgBatteryNoBattery} eq "yes") {
    $self->add_critical("NO battery");
  }
  if ($self->{upsmgBatteryReplacement} && $self->{upsmgBatteryReplacement} eq "yes") {
    $self->add_critical("battery needs to be replaced");
  }
  if ($self->{upsmgBatteryChargerFault} && $self->{upsmgBatteryChargerFault} eq "yes") {
    $self->add_critical("charger fault");
  }
  if ($self->{upsmgBatteryLowRecharge} && $self->{upsmgBatteryLowRecharge} eq "yes") {
    $self->add_critical("low recharge");
  }
  if ($self->{upsmgBatteryLowRecharge} && $self->{upsmgBatteryLowRecharge} eq "yes") {
    $self->add_critical("low recharge");
  }
  if ($self->{upsmgBatteryFaultBattery} && $self->{upsmgBatteryFaultBattery} eq "yes") {
    $self->add_critical("battery fault");
  }
  if (! $self->check_messages()) {
    $self->add_ok("battery ok");
  }
  $self->set_thresholds(
      metric => 'capacity', warning => '25:', critical => '10:');
  $self->add_info(sprintf "capacity is %.2f%%", $self->{upsmgBatteryLevel});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsmgBatteryLevel},
          metric => 'capacity'));
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{upsmgBatteryLevel},
      uom => '%',
  );

  if ($self->{upsmgBatteryTemperature}) {
    $self->set_thresholds(
        metric => 'battery_temperature', warning => '35', critical => '38');
    $self->add_info(sprintf 'temperature is %.2fC', $self->{upsmgBatteryTemperature});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsmgBatteryTemperature},
            metric => 'battery_temperature'));
    $self->add_perfdata(
        label => 'battery_temperature',
        value => $self->{upsmgBatteryTemperature},
    );
  }

  $self->{upsmgBatteryRemainingTime} /= 60;
  $self->set_thresholds(
      metric => 'remaining_time', warning => '15:', critical => '10:');
  $self->add_info(sprintf 'remaining battery run time is %.2fmin', $self->{upsmgBatteryRemainingTime});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsmgBatteryRemainingTime},
          metric => 'remaining_time'));
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{upsmgBatteryRemainingTime},
  );

  if (defined ($self->{upsmgBatteryVoltage})) {
    $self->add_info(sprintf 'battery voltage is %d VDC', $self->{upsmgBatteryVoltage});
    $self->add_perfdata(
      label => 'battery_voltage',
      value => $self->{upsmgBatteryVoltage},
    );
  }

  foreach (@{$self->{inputs}}) {
    $_->check();
  }
  foreach (@{$self->{outputs}}) {
    $_->check();
  }
  if ($self->check_messages()) {
    $self->add_critical(sprintf 'input line fail cause: %s',
        $self->{upsmgInputLineFailCause});
  }
}

sub dump {
  my ($self) = @_;
  printf "[BATTERY]\n";
  foreach (grep /^upsmg/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  foreach (@{$self->{inputs}}) {
    $_->dump();
  }
  foreach (@{$self->{outputs}}) {
    $_->dump();
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}

package Classes::MerlinGerin::Components::BatterySubsystem::Input;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{mginputCurrent} ||= 0; # mandatory, but sometimes missing
}

sub check {
  my ($self) = @_;
  $self->{mginputVoltage} /= 10;
  $self->{mginputFrequency} /= 10;
  $self->{mginputCurrent} /= 10;
  if ($self->{mginputVoltage} < 1) {
    $self->add_critical(sprintf 'input power%s outage', $self->{flat_indices});
  }
  $self->add_perfdata(
      label => 'input_voltage'.$self->{flat_indices},
      value => $self->{mginputVoltage},
  );
  $self->add_perfdata(
      label => 'input_frequency'.$self->{flat_indices},
      value => $self->{mginputFrequency},
  );
  $self->add_perfdata(
      label => 'input_current'.$self->{flat_indices},
      value => $self->{mginputCurrent},
  );
}

package Classes::MerlinGerin::Components::BatterySubsystem::Output;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
  my $metric = 'output_load'.$self->{flat_indices};
  $self->set_thresholds(
      metric => $metric, warning => '75', critical => '85');
  $self->add_info(sprintf 'output load%d %.2f%%', $self->{flat_indices}, $self->{mgoutputLoadPerPhase});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{mgoutputLoadPerPhase},
          metric => $metric)
  );
  $self->add_perfdata(
      label => $metric,
      value => $self->{mgoutputLoadPerPhase},
      uom => '%',
  );
  $self->{mgoutputVoltage} /= 10;
  $self->{mgoutputFrequency} /= 10;
  $self->{mgoutputCurrent} /= 10;
  $self->add_perfdata(
      label => 'output_voltage'.$self->{flat_indices},
      value => $self->{mgoutputVoltage},
  );
  $self->add_perfdata(
      label => 'output_frequency'.$self->{flat_indices},
      value => $self->{mgoutputFrequency},
  );
  $self->add_perfdata(
      label => 'output_current'.$self->{flat_indices},
      value => $self->{mgoutputCurrent},
  );
}

