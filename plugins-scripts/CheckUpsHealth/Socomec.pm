package CheckUpsHealth::Socomec;
our @ISA = qw(CheckUpsHealth::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->{productname} =~ /Net Vision/i) {
    bless $self, 'CheckUpsHealth::Socomec::Netvision';
    $self->debug('using CheckUpsHealth::Socomec::Netvision');
  } else {
    $self->no_such_model();
  }
  $self->init();
}

