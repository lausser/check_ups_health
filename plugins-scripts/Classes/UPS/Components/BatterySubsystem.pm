package Classes::UPS::Components::BatterySubsystem;
our @ISA = qw(Classes::UPS);
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
  $self->get_snmp_objects("UPS-MIB", qw(upsBatteryStatus upsSecondsOnBattery 
      upsEstimatedMinutesRemaining upsBatteryVoltage upsBatteryCurrent
      upsBatteryTemperature upsOutputFrequency upsEstimatedChargeRemaining));
  $self->get_snmp_tables("UPS-MIB", [
      ["inputs", "upsInputTable", "Classes::UPS::Components::BatterySubsystem::Input"],
      ["outputs", "upsOutputTable", "Classes::UPS::Components::BatterySubsystem::Output"],
  ]);
  # Une generex cs141 situé en france n'avait pas de upsBatteryCurrent
  # C'était en juin 2016. La grève dans les centrales nucléaires était
  # annoncé à ce temps là, peut-être il y avait une coupure de courant.
  $self->{upsBatteryCurrent} = 0 if ! $self->{upsBatteryCurrent};
  $self->{upsBatteryVoltage} /= 10;
  $self->{upsBatteryCurrent} /= 10;
  $self->{upsOutputFrequency} /= 10;
  # bad firmware, no sensor? who knows...
  $self->{upsBatteryTemperature} = 0 if defined $self->{upsBatteryTemperature}
      && $self->{upsBatteryTemperature} == -50;
  # The same generex cs141 had inputs and outputs with only the index oid.
  # So these do not exist in reality.
  @{$self->{inputs}} = grep {
      exists $_->{upsInputVoltage} && exists $_->{upsInputFrequency};
  } @{$self->{inputs}};
  @{$self->{outputs}} = grep {
      exists $_->{upsOutputVoltage} && exists $_->{upsOutputPower};
  } @{$self->{outputs}};
}

sub check {
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
  } else {
    $self->set_thresholds(
        metric => 'remaining_time', warning => '0:', critical => '0:');
    $self->add_info('unit is not on battery power');
  }
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsEstimatedMinutesRemaining},
          metric => 'remaining_time'));
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{upsEstimatedMinutesRemaining},
  );

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
}


package Classes::UPS::Components::BatterySubsystem::Input;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
  $self->{upsInputFrequency} /= 10;
  $self->{upsInputCurrent} /= 10;
  if ($self->{upsInputVoltage} < 1) {
    $self->add_critical(sprintf 'input power%s outage', $self->{flat_indices});
  }
  $self->add_perfdata(
      label => 'input_voltage'.$self->{flat_indices},
      value => $self->{upsInputVoltage},
  );
  $self->add_perfdata(
      label => 'input_frequency'.$self->{flat_indices},
      value => $self->{upsInputFrequency},
  );
  $self->add_perfdata(
      label => 'input_current'.$self->{flat_indices},
      value => $self->{upsInputCurrent},
  );
}

package Classes::UPS::Components::BatterySubsystem::Output;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub check {
  my ($self) = @_;
  $self->{upsOutputCurrent} /= 10;
  my $metric = 'output_load'.$self->{flat_indices};
  $self->set_thresholds(
      metric => $metric, warning => '75', critical => '85');
  $self->add_info(sprintf 'output load%d %.2f%%', $self->{flat_indices}, $self->{upsOutputPercentLoad});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsOutputPercentLoad},
          metric => $metric));
  $self->add_perfdata(
      label => $metric,
      value => $self->{upsOutputPercentLoad},
      uom => '%',
  );
  $self->add_perfdata(
      label => 'output_voltage'.$self->{flat_indices},
      value => $self->{upsOutputVoltage},
  );
  $self->add_perfdata(
      label => 'output_current'.$self->{flat_indices},
      value => $self->{upsOutputCurrent},
  );
}

