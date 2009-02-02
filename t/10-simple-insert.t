#!perl

use Test::More tests => 4;

package My::DBIC;
use base 'DBIx::Class';
__PACKAGE__->load_components(qw/+DBICx::TxnInsert/);

package My::Schema::Status;
use base 'My::DBIC';

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('status');
__PACKAGE__->add_columns(qw/id title/);

package My::Schema::User;
use base 'My::DBIC';

__PACKAGE__->load_components(qw/Core/);
__PACKAGE__->table('user');
__PACKAGE__->add_columns(qw/id name status/);
__PACKAGE__->set_primary_key('id');

package My::Storage;
use base 'DBIx::Class::Storage::DBI';

sub _dbh_last_insert_id {
  my ($self, $dbh) = @_;
  return $dbh->last_insert_id(undef,undef,undef,undef);
}

sub last_insert_id {
  my ($self,$source,$col) = @_;
  return $self->dbh_do($self->can('_dbh_last_insert_id'));
}

package My::Schema;
use base 'DBIx::Class::Schema';

__PACKAGE__->load_classes(qw/User Status/);

package main;

my $schema = My::Schema->clone;
$schema->storage(My::Storage->new($schema));
$schema->storage->connect_info( ['DBI:Mock:', '', ''] );
my $dbh  = $schema->storage->dbh;
my $user_rs = $schema->resultset('User');

my $row = $user_rs->create( { name => 'user1' } );

diag("Schema MRO: ".join(' -> ',Class::C3::calculateMRO(ref $schema)));
diag("Storage MRO: ".join(' -> ',Class::C3::calculateMRO(ref $schema->storage)));
diag("ResultSet MRO: ".join(' -> ',Class::C3::calculateMRO(ref $user_rs)));
diag("Row MRO: ".join(' -> ',Class::C3::calculateMRO(ref $row)));


my $hist = $dbh->{mock_all_history};
is( scalar(@$hist),        3,            '3 query' );
is( $hist->[0]->statement, 'BEGIN WORK', '1 - begin' );
like( $hist->[1]->statement, qr/INSERT INTO/, '2 - insert' );
is( $hist->[2]->statement, 'COMMIT', '3 - commit' );

