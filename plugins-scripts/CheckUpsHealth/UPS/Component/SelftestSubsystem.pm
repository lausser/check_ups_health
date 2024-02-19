package CheckUpsHealth::UPS::Component::SelftestSubsystem;
our @ISA = qw(Monitoring::GLPlugin::SNMP::Item);
use strict;

sub init {
  my ($self) = @_;
  $self->get_snmp_objects("UPS-MIB", qw(upsTestResultsSummary
      upsTestResultsDetail upsTestStartTime
  ));
}

sub check {
  my ($self) = @_;
  $self->add_info('checking selftest');
  if ($self->{upsTestStartTime}) {
    my $last_test_ago = $self->ago_sysuptime($self->{upsTestStartTime});
    my $result = sprintf "test result from %s was %s", 
        scalar localtime (time - $last_test_ago),
        $self->{upsTestResultsDetail} ? $self->{upsTestResultsDetail} : $self->{upsTestResultsSummary};
    if ($self->{upsTestResultsSummary} eq "doneWarning") {
      $self->add_warning($result);
    } elsif ($self->{upsTestResultsSummary} eq "doneError") {
      $self->add_critical($result);
    }
    $self->{upsAdvTestLastDiagnosticsDate} = time - $last_test_ago;
    $self->{upsAdvTestLastDiagnosticsAge} = $last_test_ago / (3600 * 24);
    $self->add_info(sprintf 'last selftest was %d days ago (%s)',
        $self->{upsAdvTestLastDiagnosticsAge}, scalar localtime $self->{upsAdvTestLastDiagnosticsDate});
    $self->add_message(
        $self->check_thresholds(
            value => $self->{upsAdvTestLastDiagnosticsAge},
            metric => 'selftest_age'));
    $self->add_perfdata(
        label => 'selftest_age',
        value => $self->{upsAdvTestLastDiagnosticsAge},
    );
  } else {
    $self->add_ok("selftest not possible or never run");
  }

  if (! $self->check_messages()) {
    $self->add_ok("hardware working fine. no selftest failures");
  }
}

