package Classes::Socomec;
our @ISA = qw(Classes::Device);
use strict;

sub init {
  my ($self) = @_;
  if ($self->{productname} =~ /Net Vision/i) {
    bless $self, 'Classes::Socomec::Netvision';
    $self->debug('using Classes::Socomec::Netvision');
  } else {
    $self->no_such_model();
  }
  $self->init();
}

