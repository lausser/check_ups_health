package UPS::Socomec;
our @ISA = qw(UPS::Device);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub init {
  my $self = shift;
  my %params = @_;
  $self->SUPER::init(%params);
  if ($self->{productname} =~ /Net Vision/i) {
    bless $self, 'UPS::Socomec::Netvision';
    $self->debug('using UPS::Socomec::Netvision');
  } else {
    $self->no_such_model();
  }
  $self->init(%params);
}

