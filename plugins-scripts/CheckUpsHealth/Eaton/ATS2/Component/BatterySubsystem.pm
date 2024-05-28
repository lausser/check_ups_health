package CheckUpsHealth::Eaton::ATS2::Component::BatterySubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;

  $self->get_snmp_objects("EATON-ATS2-MIB", qw(ats2IdentManufacturer ats2IdentModel
  ));

  $self->get_snmp_tables("EATON-ATS2-MIB", [
      ["inputs", "ats2InputTable+ats2InputStatusTable", "CheckUpsHealth::Eaton::ATS2::Component::BatterySubsystem::Input"],
  ]);




}


package CheckUpsHealth::Eaton::ATS2::Component::BatterySubsystem::Input;
our @ISA = qw(Monitoring::GLPlugin::SNMP::TableItem);
use strict;

sub finish {
  my ($self) = @_;
  $self->{ats2InputVoltage} /= 10;
  $self->{ats2InputFrequency} /= 10;
}

sub check {
  my ($self) = @_;
  if ($self->{ats2InputStatusFrequency}) {
    $self->add_critical(sprintf 'ats2InputStatusFrequency is %s',
        $self->{ats2InputStatusFrequency}) if $self->{ats2InputStatusFrequency} ne "good";
  }
  if ($self->{ats2InputStatusFrequency}) {
    $self->add_critical(sprintf 'ats2InputStatusGood is %s',
        $self->{ats2InputStatusGood}) if $self->{ats2InputStatusGood} ne "voltageAndFreqNormalRange";
  }
  if ($self->{ats2InputStatusInternalFailure}) {
    $self->add_critical('ats2InputStatusInternalFailure')
        if $self->{ats2InputStatusInternalFailure} ne "good";
  }
  if ($self->{ats2InputStatusVoltage}) {
    $self->add_critical(sprintf 'ats2InputStatusVoltage is %s',
        $self->{ats2InputStatusVoltage}) if $self->{ats2InputStatusVoltage} ne "normalRange";
  }
  if ($self->{ats2InputStatusUsed}) {
    # inputPoweringLoad oder inputNotPoweringLoad. Beobachtung: es gibt 2 Input, einer
    # powert, der andere nicht. Scheint also eine Art Failover zu sein, nur aus einer Quelle
    # wird die USV gespeist. Ergo, Status Wurst.
    $self->add_ok(sprintf 'ats2InputStatusUsed is %s',
        $self->{ats2InputStatusUsed});
  }
}



