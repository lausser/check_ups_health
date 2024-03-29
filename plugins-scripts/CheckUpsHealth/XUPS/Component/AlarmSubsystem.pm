package CheckUpsHealth::XUPS::Component::AlarmSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->get_snmp_objects("XUPS-MIB", qw(xupsAlarms));
  $self->get_snmp_tables("XUPS-MIB", [
      ["alarms", "xupsAlarmTable", "CheckUpsHealth::XUPS::Component::AlarmSubsystem::Alarm"],
  ]);
}

sub check {
  my ($self) = @_;
  $self->add_info(sprintf "%d alarms", $self->{xupsAlarms});
#  if ($self->{xupsAlarms}) {
#    # unfortunately this is >0 even if there are only outdated or bullshit alarms
#    $self->add_critical();
#  }
  $self->add_ok();
  foreach (@{$self->{alarms}}) {
    $_->check();
  }
  if (@{$self->{alarms}} && ! $self->check_messages()) {
    $self->add_ok("old or harmless");
  }
}


package CheckUpsHealth::XUPS::Component::AlarmSubsystem::Alarm;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub check {
  my ($self) = @_;
  my $age = $self->ago_sysuptime($self->{xupsAlarmTime});
  $self->{xupsAlarmTimeHuman} = scalar localtime (time - $age);
  # xupsAlarmDescr: xupsUtilityPowerRestored
  # xupsAlarmTime: 723852361
  # CRITICAL - alarm: xupsUtilityPowerRestored (-11941630 min ago)
  #
  # xupsAlarmTime == 0 means that the problem existed already at boot time
  if ($age < 3600*5*24*180 && $age >= 0 || $self->{xupsAlarmTime} == 0) {
    if ($self->{xupsAlarmDescr} =~ /(xupsOutputOffAsRequested|xupsAlarmTestInProgress|xupsOnMaintenanceBypass|xupsNoticeCondition|xupsOnHighEfficiency|xupsOnBuck|xupsOnBoost)/) {
      $self->{bullshit_alarm} = 1;
    } else {
      my $duration = $self->{xupsAlarmTime} == 0 ? "since boot" : $self->{xupsAlarmTimeHuman};
      $self->add_critical(sprintf "alarm: %s (ID %s, %s)",
          $self->{xupsAlarmDescr}, $self->{xupsAlarmID}, $duration);
    }
  } else {
    # older than half a year. nobody cared...
  }
}

__END__
XUPS-MIB::xupsAlarms = 6
XUPS-MIB::xupsAlarmTable
XUPS-MIB::xupsAlarmID.404 = 404
XUPS-MIB::xupsAlarmID.408 = 408
XUPS-MIB::xupsAlarmID.409 = 409
XUPS-MIB::xupsAlarmID.410 = 410
XUPS-MIB::xupsAlarmID.411 = 411
XUPS-MIB::xupsAlarmID.412 = 412
XUPS-MIB::xupsAlarmDescr.404 = xupsOutputOff
XUPS-MIB::xupsAlarmDescr.408 = xupsAlarmChargerFailed
XUPS-MIB::xupsAlarmDescr.409 = xupsInternalFailure
XUPS-MIB::xupsAlarmDescr.410 = xupsInternalFailure
XUPS-MIB::xupsAlarmDescr.411 = xupsInverterFailure
XUPS-MIB::xupsAlarmDescr.412 = xupsInternalFailure
XUPS-MIB::xupsAlarmTime.404 = 0
XUPS-MIB::xupsAlarmTime.408 = 0
XUPS-MIB::xupsAlarmTime.409 = 0
XUPS-MIB::xupsAlarmTime.410 = 0
XUPS-MIB::xupsAlarmTime.411 = 0
XUPS-MIB::xupsAlarmTime.412 = 0
XUPS-MIB::xupsAlarmNumEvents = 0 <- bisher verwendet bzw. ausgelesen (aug 2023) 

