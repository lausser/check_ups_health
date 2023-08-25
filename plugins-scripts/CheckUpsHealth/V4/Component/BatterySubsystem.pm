package CheckUpsHealth::V4::Component::BatterySubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
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
  my ($self) = @_;
  $self->add_info('checking battery');
  $self->add_info(sprintf 'output source is %s, battery condition is %s, %s', 
      $self->{dupsOutputSource}, 
      $self->{dupsBatteryCondiction}, $self->{dupsBatteryCharge});
  if ($self->{dupsBatteryCondiction} eq 'weak') {
    $self->add_warning();
  } elsif ($self->{dupsBatteryCondiction} eq 'replace') {
    $self->add_critical();
  } 
  if ($self->{dupsOutputSource} eq 'battery') {
    if ($self->{dupsBatteryStatus} ne 'ok') {
      $self->add_critical();
    }
  }
  if (! $self->check_messages()) {
    $self->add_ok();
  }
  $self->set_thresholds(
      metric => 'capacity', warning => '25:', critical => '10:');
  $self->add_info(sprintf 'capacity is %.2f%%', $self->{dupsBatteryCapacity});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{dupsBatteryCapacity},
          metric => 'capacity'));
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{dupsBatteryCapacity},
      uom => '%',
  );

  foreach (1..$self->{dupsOutputNumLines}) {
    $self->set_thresholds(
        metric => 'output_load'.$_, warning => '75', critical => '85');
    $self->add_info(sprintf 'output load%d %.2f%%', $_, $self->{'dupsOutputLoad'.$_});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{'dupsOutputLoad'.$_},
            metric => 'output_load'.$_));
    $self->add_perfdata(
        label => 'output_load'.$_,
        value => $self->{'dupsOutputLoad'.$_},
        uom => '%',
    );
  }

  $self->set_thresholds(
      metric => 'battery_temperature', warning => '35', critical => '38');
  $self->add_info(sprintf 'temperature is %.2fC', $self->{dupsTemperature});
  $self->add_message(
      $self->check_thresholds(
          value => $self->{dupsTemperature},
          metric => 'battery_temperature'));
  $self->add_perfdata(
      label => 'battery_temperature',
      value => $self->{dupsTemperature},
  );

  if ($self->{dupsSecondsOnBattery}) {
    $self->set_thresholds(
        metric => 'remaining_time', warning => '15:', critical => '10:');
    $self->add_info(sprintf 'remaining battery run time is %.2fmin', $self->{dupsBatteryEstimatedTime});
  } else {
    # laeuft nicht auf batterie, kann also nicht sagen, wie lang diese haelt.
    # dupsBatteryEstimatedTime liefert in dem fall undef
    $self->{dupsBatteryEstimatedTime} = 0;
    $self->force_thresholds(
        metric => 'remaining_time', warning => '0:', critical => '0:');
    $self->add_info(sprintf 'unit is not on battery power');
  }
  $self->add_message(
      $self->check_thresholds(
          value => $self->{dupsBatteryEstimatedTime},
          metric => 'remaining_time'));
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{dupsBatteryEstimatedTime},
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
  my ($self) = @_;
  printf "[BATTERY]\n";
  foreach (grep /^dups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}
