package Classes::MerlinGerin::Components::BatterySubsystem;
our @ISA = qw(Classes::MerlinGerin);
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
      upsmgInputPhaseNum upsmgOutputPhaseNum)));
  $self->get_snmp_tables('MG-SNMP-UPS-MIB', [
      ['inputs', 'upsmgInputPhaseTable', 'Classes::MerlinGerin::Components::BatterySubsystem::Input'],
      ['outputs', 'upsmgOutputPhaseTable', 'Classes::MerlinGerin::Components::BatterySubsystem::Output'],
  ]);
  @{$self->{inputs}} = grep {
      defined $_->{mginputFrequency} && defined $_->{mginputVoltage}
  } @{$self->{inputs}};
}

sub check {
  my $self = shift;
  $self->add_info('checking battery');
  my $info = undef;
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
  $info = sprintf "capacity is %.2f%%", $self->{upsmgBatteryLevel};
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsmgBatteryLevel},
          metric => 'capacity'), $info);
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{upsmgBatteryLevel},
      uom => '%',
      warning => ($self->get_thresholds(metric => 'capacity'))[0],
      critical => ($self->get_thresholds(metric => 'capacity'))[1],
  );

  if ($self->{upsmgBatteryTemperature}) {
    $self->set_thresholds(
        metric => 'battery_temperature', warning => '35', critical => '38');
    $info = sprintf 'temperature is %.2fC', $self->{upsmgBatteryTemperature};
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsmgBatteryTemperature},
            metric => 'battery_temperature'), $info);
    $self->add_perfdata(
        label => 'battery_temperature',
        value => $self->{upsmgBatteryTemperature},
      warning => ($self->get_thresholds(metric => 'battery_temperature'))[0],
      critical => ($self->get_thresholds(metric => 'battery_temperature'))[1],
    );
  }

  $self->{upsmgBatteryRemainingTime} /= 60;
  $self->set_thresholds(
      metric => 'remaining_time', warning => '15:', critical => '10:');
  $info = sprintf 'remaining battery run time is %.2fmin', $self->{upsmgBatteryRemainingTime};
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsmgBatteryRemainingTime},
          metric => 'remaining_time'), $info);
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{upsmgBatteryRemainingTime},
      warning => ($self->get_thresholds(metric => 'remaining_time'))[0],
      critical => ($self->get_thresholds(metric => 'remaining_time'))[1],
  );

  foreach (@{$self->{inputs}}) {
    $_->check();
  }
  foreach (@{$self->{outputs}}) {
    $_->check();
  }
}

sub dump {
  my $self = shift;
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
our @ISA = qw(GLPlugin::TableItem);
use strict;

sub check {
  my $self = shift;
  $self->{mginputVoltage} /= 10;
  $self->{mginputFrequency} /= 10;
  $self->{mginputCurrent} /= 10;
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
our @ISA = qw(GLPlugin::TableItem);
use strict;

sub check {
  my $self = shift;
  my $metric = 'output_load'.$self->{flat_indices};
  $self->set_thresholds(
      metric => $metric, warning => '75', critical => '85');
  my $info = sprintf 'output load%d %.2f%%', $self->{flat_indices}, $self->{mgoutputLoadPerPhase};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{mgoutputLoadPerPhase},
          metric => $metric),
      $info,
  );
  $self->add_perfdata(
      label => $metric,
      value => $self->{mgoutputLoadPerPhase},
      uom => '%',
      warning => ($self->get_thresholds(metric => $metric))[0],
      critical => ($self->get_thresholds(metric => $metric))[1],
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

