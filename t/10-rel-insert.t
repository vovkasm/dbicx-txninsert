#!perl

use Test::More tests => 6;

package My::Schema::Status;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw/+DBICx::TxnInsert Core/);
__PACKAGE__->table('status');
__PACKAGE__->add_columns(qw/id name/);
__PACKAGE__->set_primary_key('id');

package My::Schema::User;
use base 'DBIx::Class';

__PACKAGE__->load_components(qw/+DBICx::TxnInsert Core/);
__PACKAGE__->table('user');
__PACKAGE__->add_columns(qw/id name status/);
__PACKAGE__->set_primary_key('id');
__PACKAGE__->belongs_to( status => 'My::Schema::Status', 'status' );

package My::Storage;
use base 'DBIx::Class::Storage::DBI';

sub last_insert_id {
  my ($self,$source,$col) = @_;
  return $self->dbh_do(sub { $_[1]->last_insert_id(undef,undef,undef,undef); });
}

package My::Schema;
use base 'DBIx::Class::Schema';

__PACKAGE__->load_classes(qw/Status User/);

package main;

my $schema = My::Schema->clone;
$schema->storage(My::Storage->new($schema));
$schema->storage->connect_info( ['DBI:Mock:', '', ''] );
my $dbh  = $schema->storage->dbh;
my $user_rs = $schema->resultset('User');

my $row = $user_rs->create( { name => 'user1', status =>{ name => 'status1' } } );

my $hist = $dbh->{mock_all_history};
is( scalar(@$hist),        5,            '5 queries' );
like( $hist->[0]->statement, qr/SELECT.+?FROM status.+?me\.name = \?/, '1 - select from status' );
is( $hist->[1]->statement, 'BEGIN WORK', '2 - begin' );
like( $hist->[2]->statement, qr/INSERT INTO.+?status/, '3 - insert into status' );
like( $hist->[3]->statement, qr/INSERT INTO.+?user/, '4 - insert into user' );
is( $hist->[4]->statement, 'COMMIT', '5 - commit' );

