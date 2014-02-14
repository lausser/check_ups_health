package Classes::Socomec::Netvision::Components::EnvironmentalSubsystem;
our @ISA = qw(Classes::Socomec::Netvision);
use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub new {
  my $class = shift;
  my $self = {};
  bless $self, $class;
  $self->init();
  return $self;
}

sub init {
  my $self = shift;
  $self->get_snmp_objects("Netvision-v6-MIB", (qw(
      upsIdentModel upsIdentClassesFirmwareVersion upsIdentUpsSerialNumber
      upsAlarmsPresent)));
  $self->get_snmp_tables("Netvision-v6-MIB", [
      ["alarms", "upsAlarmTable", "Classes::Socomec::Netvision::Components::EnvironmentalSubsystem::Alarm"],
  ]);
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


package Classes::Socomec::Netvision::Components::EnvironmentalSubsystem::Alarm;
our @ISA = qw(GLPlugin::TableItem);
use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

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

