package Classes::EPPC::Components::BatterySubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
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
  my ($self) = @_;
  $self->get_snmp_objects('EPPC-MIB', (qw(upsESystemStatus
      upsEBatteryStatus upsESecondsOnBattery
      upsEBatteryEstimatedMinutesRemaining upsEBatteryEstimatedChargeRemaining
      upsESystemConfigBelowCapacityLimit upsESystemConfigBelowRemainTimeLimit
      upsEPositiveBatteryVoltage 
      upsEBatteryTemperature
      upsEBatteryTestStart
  )));
  foreach (qw(upsEPositiveBatteryVoltage upsEBatteryTemperature)) {
    if ($self->{$_} == -1) {
      delete  $self->{$_};
      next;
    }
    $self->{$_} /= 10;
  }
  $self->get_snmp_tables('EPPC-MIB', [
    ["inputs", "upsESystemInputTable", "Classes::EPPC::Components::BatterySubsystem::Input"],
    ["outputs", "upsESystemOutputTable", "Classes::EPPC::Components::BatterySubsystem::Output"],
    ["byps", "upsESystemBypassTable", "Classes::EPPC::Components::BatterySubsystem::Bypass"],
  ]);
}

sub check {
  my ($self) = @_;
  $self->add_info('checking battery');
  $self->add_info(sprintf 'system status is %s', $self->{upsESystemStatus});
  # power-on stand-by by-pass line battery battery-test fault converter eco shutdown on-booster on-reducer other
  if ($self->{upsESystemStatus} eq 'fail') {
    $self->add_critical();
  }
  $self->add_info(sprintf 'battery status is %s', $self->{upsEBatteryStatus});
  if ($self->{upsEBatteryStatus} ne 'batteryNormal') {
    $self->add_critical();
  } else {
    $self->add_ok();
  } 
  if ($self->{upsESystemStatus}) { # kann auch undef sein (10kv z.b.)
    $self->add_info(sprintf 'system status is %s',
        $self->{upsESystemStatus});
    if ($self->{upsESystemStatus} eq 'stand-by') {
      $self->add_ok();
    } elsif ($self->{upsESystemStatus} ne 'line') {
      $self->add_warning();
    } else {
      $self->add_ok();
    }
  }

  $self->set_thresholds(
      metric => 'capacity',
      warning => ($self->{upsESystemConfigBelowCapacityLimit} || 30).":",
      critical => ($self->{upsESystemConfigBelowCapacityLimit} || 30).":",
  );
  $self->add_info(sprintf 'capacity is %.2f%%', $self->{upsEBatteryEstimatedChargeRemaining});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsEBatteryEstimatedChargeRemaining},
          metric => 'capacity'));
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{upsEBatteryEstimatedChargeRemaining},
      uom => '%',
  );
  if ($self->{upsEBatteryEstimatedChargeRemaining} < 100) {
    $self->set_thresholds(
        metric => 'remaining_time',
        warning => ($self->{upsESystemConfigBelowRemainTimeLimit} || 15).":",
        critical => ($self->{upsESystemConfigBelowRemainTimeLimit} || 10).":",
    );
    $self->add_info(sprintf 'remaining time is %.2f%min', $self->{upsEBatteryEstimatedMinutesRemaining});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsEBatteryEstimatedMinutesRemaining},
            metric => 'remaining_time'));
    $self->add_perfdata(
        label => 'remaining_time',
        value => $self->{upsEBatteryEstimatedMinutesRemaining},
    );
  }

  $self->set_thresholds(
      metric => 'battery_temperature', warning => '70', critical => '80');
  if (defined $self->{upsEBatteryTemperature} &&
      $self->{upsEBatteryTemperature} > 0) {
    # if standby, temp can be -1000
    $self->add_info(sprintf 'temperature is %.2fC', $self->{upsEBatteryTemperature});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsEBatteryTemperature},
            metric => 'battery_temperature'));
    $self->add_perfdata(
        label => 'battery_temperature',
        value => $self->{upsEBatteryTemperature},
    );
  }

  $self->SUPER::check();
}

sub xdump {
  my ($self) = @_;
  printf "[BATTERY]\n";
  foreach (qw(upsBaseBatteryStatus
      upsSmartBatteryCapacity upsSmartBatteryVoltage upsSmartBatteryTemperature
      upsSmartBatteryRunTimeRemaining upsSmartBatteryReplaceIndicator
      upsSmartBatteryCurrent 
      upsSmartInputLineVoltage upsSmartInputFrequency upsSmartInputLineFailCause
      upsBaseOutputStatus upsSmartOutputVoltage upsSmartOutputFrequency
      upsSmartOutputLoad)) {
    printf "%s: %s\n", $_, $self->{$_} if defined $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}


package Classes::EPPC::Components::BatterySubsystem::Input;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  foreach (qw(upsESystemInputFrequency upsESystemInputVoltage)) {
    $self->{$_} /= 10 if defined $self->{$_} and not $self->{$_} == -1;
  }
}

sub check {
  my ($self) = @_;
  $self->add_perfdata(
      label => "input_frequency_".$self->{flat_indices},
      value => $self->{upsESystemInputFrequency},
  );
  $self->add_perfdata(
      label => "input_voltage_".$self->{flat_indices},
      value => $self->{upsESystemInputVoltage},
  );
}


package Classes::EPPC::Components::BatterySubsystem::Output;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  foreach (qw(upsESystemOutputFrequency upsESystemOutputVoltage
      upsESystemOutputCurrent
  )) {
    $self->{$_} /= 10 if defined $self->{$_} and not $self->{$_} == -1;
  }
}

sub check {
  my ($self) = @_;
  my $metric = "output_load_".$self->{flat_indices};
  $self->set_thresholds(
      metric => $metric, warning => '75', critical => '85');
  $self->add_info(sprintf 'output load %s %.2f%%', $self->{flat_indices}, 
      $self->{upsESystemOutputLoad});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsESystemOutputLoad},
          metric => $metric));
  $self->add_perfdata(
      label => $metric,
      value => $self->{upsESystemOutputLoad},
      uom => '%',
  );
  $self->add_perfdata(
      label => "output_frequency_".$self->{flat_indices},
      value => $self->{upsESystemOutputFrequency},
  );
  $self->add_perfdata(
      label => "output_voltage_".$self->{flat_indices},
      value => $self->{upsESystemOutputVoltage},
  );
}


package Classes::EPPC::Components::BatterySubsystem::Bypass;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  foreach (qw(upsESystemBypassFrequency upsESystemBypassVoltage
      upsESystemBypassCurrent
  )) {
    $self->{$_} /= 10 if defined $self->{$_} and not $self->{$_} == -1;
  }
}


