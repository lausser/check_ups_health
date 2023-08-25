package Classes::XUPS::Components::TempHumSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->get_snmp_objects("XUPS-MIB", qw( xupsEnvAmbientTemp
      xupsEnvAmbientLowerLimit xupsEnvAmbientUpperLimit
      xupsEnvAmbientHumidity xupsEnvRemoteTemp
      xupsEnvRemoteHumidity
      xupsEnvRemoteTempLowerLimit xupsEnvRemoteTempUpperLimit
      xupsEnvRemoteHumidityLowerLimit xupsEnvRemoteHumidityUpperLimit));
}

sub upper_lower_limit {
  my $self = shift;
  my ($lower, $upper) = @_;
  my $range = (defined $lower ? $lower : "").":".(defined $upper ? $upper : "");
  return $range eq ":" ? undef : $range;
}

sub check {
  my ($self) = @_;
  if ($self->{xupsEnvAmbientTemp}) {
    $self->add_info(sprintf "ambient temperature is %.2fC", $self->{xupsEnvAmbientTemp});
    if (my $range = $self->upper_lower_limit($self->{xupsEnvAmbientLowerLimit}, $self->{xupsEnvAmbientUpperLimit})) {
      $self->set_thresholds(metric => 'ambient_temperature',
          warning => "",
          critical => $range,
      );
    }
    $self->add_message($self->check_thresholds(
        metric => 'ambient_temperature',
        value => $self->{xupsEnvAmbientTemp},
    ));
    $self->add_perfdata(label => 'ambient_temperature',
        value => $self->{xupsEnvAmbientTemp});
  }
  if ($self->{xupsEnvAmbientHumidity}) {
    $self->add_info(sprintf "ambient humidity is %.2f%%", $self->{xupsEnvAmbientHumidity});
    $self->add_message($self->check_thresholds(
        metric => 'ambient_humidity',
        value => $self->{xupsEnvAmbientHumidity},
    ));
    $self->add_perfdata(label => 'ambient_humidity',
        value => $self->{xupsEnvAmbientHumidity},
        uom => '%');
  }
  if ($self->{xupsEnvRemoteTemp}) {
    $self->add_info(sprintf "remote temperature is %.2fC", $self->{xupsEnvRemoteTemp});
    if (my $range = $self->upper_lower_limit($self->{xupsEnvRemoteTempLowerLimit}, $self->{xupsEnvRemoteTempUpperLimit})) {
      $self->set_thresholds(metric => 'remote_temperature',
          warning => "",
          critical => $range,
      );
    }
    $self->add_message($self->check_thresholds(
        metric => 'remote_temperature',
        value => $self->{xupsEnvRemoteTemp},
    ));
    $self->add_perfdata(label => 'remote_temperature',
        value => $self->{xupsEnvRemoteTemp});
  }
  if ($self->{xupsEnvRemoteHumidity}) {
    $self->add_info(sprintf "remote humidity is %.2f%%", $self->{xupsEnvRemoteHumidity});
    if (my $range = $self->upper_lower_limit($self->{xupsEnvRemoteHumidityLowerLimit}, $self->{xupsEnvRemoteHumidityUpperLimit})) {
      $self->set_thresholds(metric => 'remote_humidity',
          warning => "",
          critical => $range,
      );
    }
    $self->add_message($self->check_thresholds(
        metric => 'remote_humidity',
        value => $self->{xupsEnvRemoteHumidity},
    ));
    $self->add_perfdata(label => 'remote_humidity',
        value => $self->{xupsEnvRemoteHumidity},
        uom => '%');
  }
  $self->reduce_messages_short("temp and hum is fine");
}


