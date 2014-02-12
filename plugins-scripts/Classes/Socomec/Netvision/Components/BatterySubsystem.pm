package Classes::Socomec::Netvision::Components::BatterySubsystem;
our @ISA = qw(Classes::Socomec::Netvision);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
    inputs => [],
    outputs => [],
    bypasses => [],
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  foreach (qw(upsBatteryStatus upsSecondsonBattery upsEstimatedMinutesRemaining
      upsEstimatedChargeRemaining upsBatteryVoltage upsBatteryTemperature
      upsInputFrequency upsOutputFrequency
      upsOutputSource upsTestResultsSummary upsTestResultsDetail
      upsControlStatusControl)) {
    $self->{$_} = $self->get_snmp_object('Netvision-v6-MIB', $_, 0);
  }
  $self->{upsSecondsonBattery} ||= 0;
  $self->{upsBatteryVoltage} /= 10;
  $self->{upsInputFrequency} /= 10;
  $self->{upsOutputFrequency} /= 10;
  foreach ($self->get_snmp_table_objects('Netvision-v6-MIB', 'upsInputTable')) {
    push(@{$self->{inputs}}, Classes::Socomec::Netvision::Components::BatterySubsystem::Input->new(%{$_}));
  }
  foreach ($self->get_snmp_table_objects('Netvision-v6-MIB', 'upsOutputTable')) {
    push(@{$self->{outputs}}, Classes::Socomec::Netvision::Components::BatterySubsystem::Output->new(%{$_}));
  }
  foreach ($self->get_snmp_table_objects('Netvision-v6-MIB', 'upsBypassTable')) {
    push(@{$self->{bypasses}}, Classes::Socomec::Netvision::Components::BatterySubsystem::Bypass->new(%{$_}));
  }
  foreach ($self->get_snmp_table_objects('Netvision-v6-MIB', 'upsAlarmTable')) {
#printf "%s\n", Data::Dumper::Dumper($_);
##!!!!
  }
}

sub check {
  my $self = shift;
  $self->add_info('checking battery');
  my $info = sprintf 'battery status is %s',
      $self->{upsBatteryStatus};
  $self->add_info($info);
  if ($self->{upsBatteryStatus} ne 'batteryNormal') {
    $self->add_message(CRITICAL, $info);
  } else {
    $self->add_message(OK, $info);
  } 

  $self->set_thresholds(
      metric => 'capacity', warning => '25:', critical => '10:');
  $info = sprintf 'capacity is %.2f%%', $self->{upsEstimatedChargeRemaining};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsEstimatedChargeRemaining},
          metric => 'capacity'), $info);
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{upsEstimatedChargeRemaining},
      uom => '%',
      warning => ($self->get_thresholds(metric => 'capacity'))[0],
      critical => ($self->get_thresholds(metric => 'capacity'))[1],
  );

  $self->set_thresholds(
      metric => 'battery_temperature', warning => '35', critical => '38');
  $info = sprintf 'temperature is %.2fC', $self->{upsBatteryTemperature};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsBatteryTemperature},
          metric => 'battery_temperature'), $info);
  $self->add_perfdata(
      label => 'battery_temperature',
      value => $self->{upsBatteryTemperature},
      warning => ($self->get_thresholds(metric => 'battery_temperature'))[0],
      critical => ($self->get_thresholds(metric => 'battery_temperature'))[1],
  );

  if ($self->{upsEstimatedMinutesRemaining} == -1) {
    $self->set_thresholds(
        metric => 'remaining_time', warning => '0', critical => '0');
    $info = sprintf 'battery run time is unknown';
  } else {
    $self->set_thresholds(
        metric => 'remaining_time', warning => '15:', critical => '10:');
    $info = sprintf 'remaining battery run time is %.2fmin', $self->{upsEstimatedMinutesRemaining};
    $self->add_info($info);
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsEstimatedMinutesRemaining},
            metric => 'remaining_time'), $info);
  }
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{upsEstimatedMinutesRemaining},
      warning => ($self->get_thresholds(metric => 'remaining_time'))[0],
      critical => ($self->get_thresholds(metric => 'remaining_time'))[1],
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
  my $self = shift;
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
our @ISA = qw(Classes::Socomec::Netvision::Components::BatterySubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  foreach (keys %params) {
    $self->{$_} = $params{$_};
  }
  $self->{upsInputVoltage} /= 10;
  $self->{upsInputVoltageMin} /= 10;
  $self->{upsInputVoltageMax} /= 10;
  $self->{upsInputCurrent} /= 10;
  return $self;
}

sub check {
  my $self = shift;
  my $info = sprintf 'input%d voltage is %dV', $self->{upsInputLineIndex}, $self->{upsInputVoltage};
  $self->add_info($info);
}

sub dump {
  my $self = shift;
  printf "[INPUT]\n";
  foreach (grep /^ups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}


package Classes::Socomec::Netvision::Components::BatterySubsystem::Output;
our @ISA = qw(Classes::Socomec::Netvision::Components::BatterySubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  foreach (keys %params) {
    $self->{$_} = $params{$_};
  }
  $self->{upsOutputVoltage} /= 10;
  $self->{upsOutputCurrent} /= 10;
  return $self;
}

sub check {
  my $self = shift;
  $self->set_thresholds(
      metric => 'output_load'.$self->{upsOutputLineIndex}, warning => '75', critical => '85');
  my $info = sprintf 'output load%d %.2f%%', $self->{upsOutputLineIndex}, $self->{upsOutputPercentLoad};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{upsOutputPercentLoad},
          metric => 'output_load'.$self->{upsOutputLineIndex}), $info);
  $self->add_perfdata(
      label => 'output_load'.$self->{upsOutputLineIndex},
      value => $self->{upsOutputPercentLoad},
      uom => '%',
      warning => ($self->get_thresholds(metric => 'output_load'.$_))[0],
      critical => ($self->get_thresholds(metric => 'output_load'.$_))[1],
  );

  $self->add_perfdata(
      label => 'output_voltage'.$self->{upsOutputLineIndex},
      value => $self->{upsOutputVoltage},
  );

}

sub dump {
  my $self = shift;
  printf "[OUTPUT]\n";
  foreach (grep /^ups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}


package Classes::Socomec::Netvision::Components::BatterySubsystem::Bypass;
our @ISA = qw(Classes::Socomec::Netvision::Components::BatterySubsystem);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my %params = @_;
  my $self = {
    blacklisted => 0,
    info => undef,
    extendedinfo => undef,
  };
  bless $self, $class;
  foreach (keys %params) {
    $self->{$_} = $params{$_};
  }
  $self->{upsBypassVoltage} /= 10;
  return $self;
}

sub check {
  my $self = shift;
  my $info = sprintf 'bypass%d voltage is %dV', $self->{upsBypassLineIndex}, $self->{upsBypassVoltage};
  $self->add_info($info);
}

sub dump {
  my $self = shift;
  printf "[BYPASS]\n";
  foreach (grep /^ups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}


