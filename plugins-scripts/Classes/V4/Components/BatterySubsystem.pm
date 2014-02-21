package Classes::V4::Components::BatterySubsystem;
our @ISA = qw(Classes::V4);
use strict;

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  $self->init();
  return $self;
}

sub init {
  my $self = shift;
  $self->get_snmp_objects('UPSV4-MIB', (qw(
      dupsBatteryCondiction dupsLastReplaceDate dupsNextReplaceDate
      dupsBatteryStatus dupsBatteryCharge dupsSecondsOnBattery
      dupsBatteryEstimatedTime dupsBatteryVoltage
      dupsBatteryCapacity dupsTemperature dupsLowBattTime dupsOutputSource
      dupsInputNumLines
      dupsOutputNumLines dupsOutputFrequency)));
  $self->{dupsLastReplaceDate} ||= 0;
  $self->{dupsNextReplaceDate} ||= 0;
  $self->{dupsBatteryCurrent} ||= 0;
  $self->{dupsLowBattTime} ||= 0;
  $self->{dupsOutputFrequency} /= 10;
  foreach (1..$self->{dupsInputNumLines}) {
    $self->{'dupsInputVoltage'.$_} = $self->get_snmp_object('UPSV4-MIB', 'dupsInputVoltage'.$_, 0) / 10;
    $self->{'dupsInputFrequency'.$_} = $self->get_snmp_object('UPSV4-MIB', 'dupsInputFrequency'.$_, 0) / 10;
  }
  foreach (1..$self->{dupsOutputNumLines}) {
    $self->{'dupsOutputLoad'.$_} = $self->get_snmp_object('UPSV4-MIB', 'dupsOutputLoad'.$_, 0);
    $self->{'dupsOutputVoltage'.$_} = $self->get_snmp_object('UPSV4-MIB', 'dupsOutputVoltage'.$_, 0) / 10;
  }
}

sub check {
  my $self = shift;
  $self->add_info('checking battery');
  my $info = sprintf 'output source is %s, battery condition is %s, %s', 
      $self->{dupsOutputSource}, 
      $self->{dupsBatteryCondiction}, $self->{dupsBatteryCharge};
  $self->add_info($info);
  if ($self->{dupsBatteryCondiction} eq 'weak') {
    $self->add_warning($info);
  } elsif ($self->{dupsBatteryCondiction} eq 'replace') {
    $self->add_critical($info);
  } 
  if ($self->{dupsOutputSource} eq 'battery') {
    if ($self->{dupsBatteryStatus} ne 'ok') {
      $self->add_critical($info);
    }
  }
  if (! $self->check_messages()) {
    $self->add_ok($info);
  }
  $self->set_thresholds(
      metric => 'capacity', warning => '25:', critical => '10:');
  $info = sprintf 'capacity is %.2f%%', $self->{dupsBatteryCapacity};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{dupsBatteryCapacity},
          metric => 'capacity'), $info);
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{dupsBatteryCapacity},
      uom => '%',
      warning => ($self->get_thresholds(metric => 'capacity'))[0],
      critical => ($self->get_thresholds(metric => 'capacity'))[1],
  );

  foreach (1..$self->{dupsOutputNumLines}) {
    $self->set_thresholds(
        metric => 'output_load'.$_, warning => '75', critical => '85');
    $info = sprintf 'output load%d %.2f%%', $_, $self->{'dupsOutputLoad'.$_};
    $self->add_info($info);
    $self->add_message(
        $self->check_thresholds(
            value => $self->{'dupsOutputLoad'.$_},
            metric => 'output_load'.$_), $info);
    $self->add_perfdata(
        label => 'output_load'.$_,
        value => $self->{'dupsOutputLoad'.$_},
        uom => '%',
        warning => ($self->get_thresholds(metric => 'output_load'.$_))[0],
        critical => ($self->get_thresholds(metric => 'output_load'.$_))[1],
    );
  }

  $self->set_thresholds(
      metric => 'battery_temperature', warning => '35', critical => '38');
  $info = sprintf 'temperature is %.2fC', $self->{dupsTemperature};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{dupsTemperature},
          metric => 'battery_temperature'), $info);
  $self->add_perfdata(
      label => 'battery_temperature',
      value => $self->{dupsTemperature},
      warning => ($self->get_thresholds(metric => 'battery_temperature'))[0],
      critical => ($self->get_thresholds(metric => 'battery_temperature'))[1],
  );

  $self->set_thresholds(
      metric => 'remaining_time', warning => '15:', critical => '10:');
  $info = sprintf 'remaining battery run time is %.2fmin', $self->{dupsBatteryEstimatedTime};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{dupsBatteryEstimatedTime},
          metric => 'remaining_time'), $info);
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{dupsBatteryEstimatedTime},
      warning => ($self->get_thresholds(metric => 'remaining_time'))[0],
      critical => ($self->get_thresholds(metric => 'remaining_time'))[1],
  );

  foreach (1..$self->{dupsInputNumLines}) {
    if ($self->{'dupsInputVoltage'.$_} < 1) {
      $self->add_critical(sprintf 'input power%s outage', $_);
    }
    $self->add_perfdata(
        label => 'input_voltage'.$_,
        value => $self->{'dupsInputVoltage'.$_},
    );
    $self->add_perfdata(
        label => 'input_frequency'.$_,
        value => $self->{'dupsInputFrequency'.$_},
    );
  }
  foreach (1..$self->{dupsOutputNumLines}) {
    $self->add_perfdata(
        label => 'output_voltage'.$_,
        value => $self->{'dupsOutputVoltage'.$_},
    );
  }
  $self->add_perfdata(
      label => 'output_frequency',
      value => $self->{dupsOutputFrequency},
  );
}

sub dump {
  my $self = shift;
  printf "[BATTERY]\n";
  foreach (grep /^dups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}
