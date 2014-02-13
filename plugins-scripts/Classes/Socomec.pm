package Classes::Socomec;
our @ISA = qw(Classes::Device);

sub init {
  my $self = shift;
  if ($self->{productname} =~ /Net Vision/i) {
    bless $self, 'Classes::Socomec::Netvision';
    $self->debug('using Classes::Socomec::Netvision');
  } else {
    $self->no_such_model();
  }
  $self->init();
}

