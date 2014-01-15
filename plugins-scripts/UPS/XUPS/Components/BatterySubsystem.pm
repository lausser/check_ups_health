package UPS::XUPS::Components::BatterySubsystem;
our @ISA = qw(UPS::XUPS);

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
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  foreach (qw(xupsBatTimeRemaining xupsBatVoltage xupsBatCurrent xupsBatCapacity)) {
    $self->{$_} = $self->get_snmp_object('XUPS-MIB', $_);
  }
  $self->{xupsBatTimeRemaining} /= 60;
}

sub check {
  my $self = shift;
  $self->add_info('checking battery');
  $self->set_thresholds(
      metric => 'capacity', warning => '25:', critical => '10:');
  my $info = sprintf 'capacity is %.2f%%', $self->{xupsBatCapacity};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{xupsBatCapacity},
          metric => 'capacity'), $info);
  $self->add_perfdata(
      label => 'capacity',
      value => $self->{xupsBatCapacity},
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
      metric => 'remaining_time', warning => '15:', critical => '10:');
  $info = sprintf 'remaining battery run time is %.2fmin', $self->{xupsBatTimeRemaining};
  $self->add_info($info);
  $self->add_message(
      $self->check_thresholds(
          value => $self->{xupsBatTimeRemaining},
          metric => 'remaining_time'), $info);
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{xupsBatTimeRemaining},
      warning => ($self->get_thresholds(metric => 'remaining_time'))[0],
      critical => ($self->get_thresholds(metric => 'remaining_time'))[1],
  );

  foreach (1..$self->{dupsInputNumLines}) {
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
  foreach (grep /^xups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}
