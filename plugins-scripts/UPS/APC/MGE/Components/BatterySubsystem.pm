package UPS::APC::MGE::Components::BatterySubsystem;
our @ISA = qw(UPS::APC);

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
  foreach (qw(upsBasicBatteryStatus upsAdvBatteryCapacity
      upsAdvBatteryReplaceIndicator upsAdvBatteryTemperature
      upsAdvOutputVoltage upsAdvOutputLoad
      upsAdvInputLineVoltage upsAdvBatteryRunTimeRemaining
      upsBasicOutputStatus)) {
    $self->{$_} = $self->get_snmp_object('PowerNet-MIB', $_);
  }
  $self->{upsAdvBatteryRunTimeRemaining} = $self->{upsAdvBatteryRunTimeRemaining} / 6000;
}

sub check {
  my $self = shift;
  $self->add_info('checking battery');
  my $info = sprintf 'battery status is %s, capacity is %.2f%%, output load %.2f%%, temperature is %.2fC',
      $self->{upsBasicBatteryStatus}, 
      $self->{upsAdvBatteryCapacity}, 
      $self->{upsAdvOutputLoad}, 
      $self->{upsAdvBatteryTemperature};
  $self->add_info($info);
  if ($self->{upsBasicBatteryStatus} ne 'batteryNormal') {
    $self->add_message(CRITICAL, $info);
  } else {
    $self->add_message(OK, $info);
  } 
  if ($self->{upsAdvBatteryReplaceIndicator} && $self->{upsAdvBatteryReplaceIndicator} eq 'batteryNeedsReplacing') {
    $self->add_message(CRITICAL, 'battery needs replacing');
  }
  $self->set_thresholds(warning => '15:', critical => '10:');
  $self->add_message(
      $self->check_thresholds($self->{upsAdvBatteryRunTimeRemaining}), 
      sprintf 'remaining battery run time %.2fmin', 
      $self->{upsAdvBatteryRunTimeRemaining});
  $self->add_perfdata(
      label => 'battery_charge',
      value => $self->{upsAdvBatteryCapacity},
      uom => '%',
  );
  $self->add_perfdata(
      label => 'output_load',
      value => $self->{upsAdvOutputLoad},
      uom => '%',
  );
  $self->add_perfdata(
      label => 'remaining_time',
      value => $self->{upsAdvBatteryRunTimeRemaining},
      warning => $self->{warning},
      critical => $self->{critical},
  );
}

sub dump {
  my $self = shift;
  printf "[BATTERY]\n";
  foreach (qw(upsBasicBatteryStatus upsAdvBatteryCapacity
      upsAdvBatteryReplaceIndicator upsAdvBatteryTemperature
      upsAdvOutputVoltage upsAdvOutputLoad
      upsAdvInputLineVoltage upsAdvBatteryRunTimeRemaining
      upsBasicOutputStatus)) {
    printf "%s: %s\n", $_, $self->{$_} if defined $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}
