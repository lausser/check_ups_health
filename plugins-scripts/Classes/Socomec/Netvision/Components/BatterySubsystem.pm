package Classes::Socomec::Netvision::Components::BatterySubsystem;
our @ISA = qw(Classes::Socomec::Netvision);
use strict;

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  $self->init();
  return $self;
}

sub init {
  my ($self) = @_;
  $self->get_snmp_objects('Netvision-v6-MIB', (qw(
      upsBatteryStatus upsSecondsonBattery upsEstimatedMinutesRemaining
      upsEstimatedChargeRemaining upsBatteryVoltage upsBatteryTemperature
      upsInputFrequency upsOutputFrequency
      upsOutputSource upsTestResultsSummary upsTestResultsDetail
      upsControlStatusControl)));
  $self->{upsSecondsonBattery} ||= 0;
  $self->{upsBatteryVoltage} /= 10;
  $self->{upsInputFrequency} /= 10;
  $self->{upsOutputFrequency} /= 10;
  $self->get_snmp_tables('Netvision-v6-MIB', [
      ['inputs', 'upsInputTable', 'Classes::Socomec::Netvision::Components::BatterySubsystem::Input'],
      ['outputs', 'upsOutputTable', 'Classes::Socomec::Netvision::Components::BatterySubsystem::Output'],
      ['bypasses', 'upsBypassTable', 'Classes::Socomec::Netvision::Components::BatterySubsystem::Bypass'],
  ]);
  foreach ($self->get_snmp_table_objects('Netvision-v6-MIB', 'upsAlarmTable')) {
#printf "%s\n", Data::Dumper::Dumper($_);
##!!!!
  }
}

sub check {
  my ($self) = @_;
  $self->add_info('checking battery');
  $self->add_info(sprintf 'battery status is %s', $self->{upsBatteryStatus});
  if ($self->{upsBatteryStatus} ne 'batteryNormal') {
    $self->add_critical();
  } else {
    $self->add_ok();
  } 

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

  if ($self->{upsEstimatedMinutesRemaining} == -1) {
    $self->set_thresholds(
        metric => 'remaining_time', warning => '0', critical => '0');
    $self->add_info('battery run time is unknown');
  } else {
    $self->set_thresholds(
        metric => 'remaining_time', warning => '15:', critical => '10:');
    $self->add_info(sprintf 'remaining battery run time is %.2fmin', $self->{upsEstimatedMinutesRemaining});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsEstimatedMinutesRemaining},
            metric => 'remaining_time'));
  }
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{upsEstimatedMinutesRemaining},
  );

  $self->add_perfdata(
      label => 'input_frequency',
      value => $self->{upsInputFrequency},
  );

  foreach (@{$self->{inputs}}) {
    $_->check();
  }
  $self->add_perfdata(
      label => 'output_frequency',
      value => $self->{upsOutputFrequency},
  );

  foreach (@{$self->{outputs}}) {
    $_->check();
  }

}

sub dump {
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
  foreach (@{$self->{bypasses}}) {
    $_->dump();
  }
}


package Classes::Socomec::Netvision::Components::BatterySubsystem::Input;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;


sub check {
  my ($self) = @_;
  $self->{upsInputVoltage} /= 10;
  $self->{upsInputVoltageMin} /= 10;
  $self->{upsInputVoltageMax} /= 10;
  $self->{upsInputCurrent} /= 10;
  $self->add_info(sprintf 'input%d voltage is %dV', $self->{upsInputLineIndex}, $self->{upsInputVoltage});
  if ($self->{upsInputVoltage} < 1) {
    $self->add_critical(sprintf 'input power%s outage', $self->{upsInputLineIndex});
  }
  $self->add_perfdata(
      label => 'input_voltage'.$self->{upsInputLineIndex},
      value => $self->{upsInputVoltage},
  );
}

sub dump {
  my ($self) = @_;
  printf "[INPUT]\n";
  foreach (grep /^ups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}


package Classes::Socomec::Netvision::Components::BatterySubsystem::Output;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;


sub check {
  my ($self) = @_;
  $self->{upsOutputVoltage} /= 10;
  $self->{upsOutputCurrent} /= 10;
  $self->set_thresholds(
      metric => 'output_load'.$self->{upsOutputLineIndex}, warning => '75', critical => '85');
  $self->add_info(sprintf 'output load%d %.2f%%', $self->{upsOutputLineIndex}, $self->{upsOutputPercentLoad});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsOutputPercentLoad},
          metric => 'output_load'.$self->{upsOutputLineIndex}));
  $self->add_perfdata(
      label => 'output_load'.$self->{upsOutputLineIndex},
      value => $self->{upsOutputPercentLoad},
      uom => '%',
  );

  $self->add_perfdata(
      label => 'output_voltage'.$self->{upsOutputLineIndex},
      value => $self->{upsOutputVoltage},
  );

}

sub dump {
  my ($self) = @_;
  printf "[OUTPUT]\n";
  foreach (grep /^ups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}


package Classes::Socomec::Netvision::Components::BatterySubsystem::Bypass;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;


sub check {
  my ($self) = @_;
  $self->{upsBypassVoltage} /= 10;
  $self->add_info(sprintf 'bypass%d voltage is %dV', $self->{upsBypassLineIndex}, $self->{upsBypassVoltage});
}

sub dump {
  my ($self) = @_;
  printf "[BYPASS]\n";
  foreach (grep /^ups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}


