package UPS::Socomec::Netvision::Components::BatterySubsystem;
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
    inputs => [];
    outputs => [];
    bypasses => [];
  };
  bless $self, $class;
  $self->init(%params);
  return $self;
}

sub init {
  my $self = shift;
  foreach (qw(upsBatteryStatus upsSecondsonBattery upsEstimatedMinutesRemaining
      upsEstimatedChargeRemaining upsBatteryVoltage upsBatteryTemperature
      upsOutputSource upsTestResultsSummary upsControlStatusControl)) {
    $self->{$_} = $self->get_snmp_object('Netvision-v6-MIB', $_, 0);
  }
  foreach ($self->get_snmp_table_objects('Netvision-v6-MIB', 'upsInputTable')) {
    push(@{$self->{inputs}}, UPS::Socomec::Netvision::Components::BatterySubsystem::Input->new(%{$_});
  }
  foreach ($self->get_snmp_table_objects('Netvision-v6-MIB', 'upsOutputTable')) {
    push(@{$self->{outputs}}, UPS::Socomec::Netvision::Components::BatterySubsystem::Output->new(%{$_});
  }
  foreach ($self->get_snmp_table_objects('Netvision-v6-MIB', 'upsBypassTable')) {
    push(@{$self->{bypasses}}, UPS::Socomec::Netvision::Components::BatterySubsystem::Bypass->new(%{$_});
  }
  foreach ($self->get_snmp_table_objects('Netvision-v6-MIB', 'upsAlarmTable')) {
#printf "%s\n", Data::Dumper::Dumper($_);
##!!!!
  }
}

sub check {
  my $self = shift;
  $self->add_info('checking battery');
  my $info = sprintf 'battery status is %s, capacity is %.2f%%, temperature is %.2fC',
      $self->{upsBatteryStatus}, 
      $self->{upsEstimatedChargeRemaining}, 
      $self->{upsBatteryTemperature};
  $self->add_info($info);
  if ($self->{upsBatteryStatus} ne 'batteryNormal') {
    $self->add_message(CRITICAL, $info);
  } else {
    $self->add_message(OK, $info);
  } 
  $self->set_thresholds(warning => '15:', critical => '10:');
  if ($self->{upsEstimatedMinutesRemaining} != -1) {
    $self->add_message(
        $self->check_thresholds($self->{upsEstimatedMinutesRemaining}), 
        sprintf 'remaining battery run time %.2fmin', 
        $self->{upsEstimatedMinutesRemaining});
  }
  $self->add_perfdata(
      label => 'battery_charge',
      value => $self->{upsEstimatedChargeRemaining},
      uom => '%',
  );
  #$self->add_perfdata(
  #    label => 'output_load',
  #    value => $self->{upsAdvOutputLoad},
  #    uom => '%',
  #);
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{upsEstimatedMinutesRemaining},
      warning => $self->{warning},
      critical => $self->{critical},
  );
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


package UPS::Socomec::Netvision::Components::BatterySubsystem::Input;
our @ISA = qw(UPS::Socomec::Netvision::Components::BatterySubsystem);

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

sub dump {
  my $self = shift;
  printf "[INPUT]\n";
  foreach (grep /^ups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}


package UPS::Socomec::Netvision::Components::BatterySubsystem::Output;
our @ISA = qw(UPS::Socomec::Netvision::Components::BatterySubsystem);

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

sub dump {
  my $self = shift;
  printf "[OUTPUT]\n";
  foreach (grep /^ups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}


package UPS::Socomec::Netvision::Components::BatterySubsystem::Bypass;
our @ISA = qw(UPS::Socomec::Netvision::Components::BatterySubsystem);

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

sub dump {
  my $self = shift;
  printf "[BYPASS]\n";
  foreach (grep /^ups/, keys %{$self}) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}


