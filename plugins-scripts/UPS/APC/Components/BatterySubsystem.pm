package UPS::APC::Components::BatterySubsystem;
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
  foreach (qw(upsBasicBatteryStatus upsBasicBatteryTimeOnBattery upsBasicBatteryLastReplaceDate
      upsAdvBatteryCapacity upsAdvBatteryTemperature upsAdvBatteryRunTimeRemaining
      upsAdvBatteryReplaceIndicator upsAdvBatteryNumOfBattPacks upsAdvBatteryNumOfBadBattPacks
      upsAdvBatteryNominalVoltage upsAdvBatteryActualVoltage upsAdvBatteryCurrent
      upsAdvTotalDCCurrent upsAdvBatteryFullCapacity)) {
    $self->{$_} = $self->get_snmp_object('PowerNet-MIB', $_, 0);
printf "%s %s\n", $_, $self->{$_};
sleep 1;
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
    $self->add_message(WARNING, $info);
  } elsif ($self->{dupsBatteryCondiction} eq 'replace') {
    $self->add_message(CRITICAL, $info);
  } 
  if ($self->{dupsOutputSource} eq 'battery') {
    if ($self->{dupsBatteryStatus} ne 'ok') {
      $self->add_message(CRITICAL, $info);
    }
  }
  if (! $self->check_messages()) {
    $self->add_message(OK, $info);
  }
  $self->add_perfdata(
      label => 'battery_charge',
      value => $self->{dupsBatteryCapacity},
      uom => '%',
  );
}

sub dump {
  my $self = shift;
  printf "[BATTERY]\n";
  foreach (qw(upsBasicBatteryStatus upsBasicBatteryTimeOnBattery upsBasicBatteryLastReplaceDate
      upsAdvBatteryCapacity upsAdvBatteryTemperature upsAdvBatteryRunTimeRemaining
      upsAdvBatteryReplaceIndicator upsAdvBatteryNumOfBattPacks upsAdvBatteryNumOfBadBattPacks
      upsAdvBatteryNominalVoltage upsAdvBatteryActualVoltage upsAdvBatteryCurrent
      upsAdvTotalDCCurrent upsAdvBatteryFullCapacity)) {
    printf "%s: %s\n", $_, $self->{$_};
  }
  printf "info: %s\n", $self->{info};
  printf "\n";
}
