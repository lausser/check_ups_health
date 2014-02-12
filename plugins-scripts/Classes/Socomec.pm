package Classes::Socomec;
our @ISA = qw(Classes::Device);

use strict;
use constant { OK => 0, WARNING => 1, CRITICAL => 2, UNKNOWN => 3 };

sub init {
  my $self = shift;
  my %params = @_;
  $self->SUPER::init(%params);
  if ($self->{productname} =~ /Net Vision/i) {
    bless $self, 'Classes::Socomec::Netvision';
    $self->debug('using Classes::Socomec::Netvision');
  } else {
    $self->no_such_model();
  }
  $self->init(%params);
}

