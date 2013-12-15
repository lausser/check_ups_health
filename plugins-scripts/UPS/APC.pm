package UPS::APC;
our @ISA = qw(UPS::Device);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub init {
  my $self = shift;
  my %params = @_;
 $self->SUPER::init(%params);
  $self->{upsBasicIdentModel} = $self->get_snmp_object('PowerNet-MIB', 'upsBasicIdentModel');
  if ($self->{upsBasicIdentModel} =~ /mge/i) {
    bless $self, 'UPS::APC::MGE';
    $self->debug('using UPS::APC::MGE');
  } else {
    die;
  }
  $self->init(%params);
}

