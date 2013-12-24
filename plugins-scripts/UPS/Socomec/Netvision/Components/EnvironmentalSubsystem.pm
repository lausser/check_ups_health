package UPS::Socomec::Netvision::Components::EnvironmentalSubsystem;
our @ISA = qw(UPS::Socomec::Netvision);

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
  foreach (qw(upsIdentModel upsIdentUPSFirmwareVersion upsIdentUpsSerialNumber
      upsAlarmsPresent
)) {
    $self->{$_} = $self->get_snmp_object('Netvision-v6-MIB', $_, 0);
  }
  foreach ($self->get_snmp_table_objects('Netvision-v6-MIB', 'upsAlarmTable')) {
    push(@{$self->{alarms}}, UPS::Socomec::Netvision::Components::EnvironmentalSubsystem::Alarm->new(%{$_}));
  }
}

sub check {
  my $self = shift;
  $self->add_info('checking alarms');
  my $info = sprintf 'found %d alarms', $self->{upsAlarmsPresent};
  $self->add_info($info);
  if ($self->{upsAlarmsPresent}) {
    $self->add_message(CRITICAL, $info);
  } else {
    $self->add_message(OK, $info);
  } 

}

sub dump {
  my $self = shift;
  printf "[HARDWARE]\n";
  foreach (grep /^ups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
  foreach (@{$self->{alarms}}) {
    $_->dump();
  }
}


package UPS::Socomec::Netvision::Components::EnvironmentalSubsystem::Alarm;
our @ISA = qw(UPS::Socomec::Netvision::Components::EnvironmentalSubsystem);

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
  return $self;
}

sub check {
  my $self = shift;
  my $info = sprintf '%s', $self->{upsAlarmDescr};
  $self->add_info($info);
  $self->add_message(CRITICAL, $info);
}

sub dump {
  my $self = shift;
  printf "[ALARM]\n";
  foreach (grep /^ups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}

