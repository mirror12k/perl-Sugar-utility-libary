package Sugar::Test::Compare;
use strict;
use warnings;


use feature 'say';



sub compare_values {
	my ($config, $v1, $v2, $access_key) = @_;
	$access_key //= '';

	return compare_values_hash($config, $v1, $v2, $access_key) if ref $v1 eq 'HASH';
	return compare_values_array($config, $v1, $v2, $access_key) if ref $v1 eq 'ARRAY';
	die "v1$access_key is not defined\n" if not defined $v1 and defined $v2;
	die "v2$access_key is not defined\n" if not defined $v2 and defined $v1;
	die "v1$access_key and v2$access_key do not match: [$v1] <=> [$v2]\n" unless $v1 eq $v2;
}


sub compare_values_hash {
	my ($config, $v1, $v2, $access_key) = @_;

	die "v1$access_key is not a hash\n" unless ref $v1 eq 'HASH';
	die "v2$access_key is not a hash\n" unless ref $v2 eq 'HASH';

	my %hash_keys;
	@hash_keys{keys %$v1, keys %$v2} = ();
	foreach my $key (keys %hash_keys) {
		# say "compare $key";
		next if exists $config->{ignore_keys}{$key};

		die "v1$access_key\->{$key} is missing\n" unless exists $v1->{$key};
		die "v2$access_key\->{$key} is missing\n" unless exists $v2->{$key};

		compare_values($config, $v1->{$key}, $v2->{$key}, "$access_key\->{$key}");
	}
}


sub compare_values_array {
	my ($config, $v1, $v2, $access_key) = @_;

	die "v1$access_key is not a array\n" unless ref $v1 eq 'ARRAY';
	die "v2$access_key is not a array\n" unless ref $v2 eq 'ARRAY';

	my $length_v1 = @$v1;
	my $length_v2 = @$v2;

	die "v1$access_key is missing items: $length_v1 vs $length_v2\n" if @$v1 < @$v2;
	die "v2$access_key is missing items $length_v1 vs $length_v2\n" if @$v2 < @$v1;
	
	foreach my $i (0 .. $#$v1) {
		compare_values($config, $v1->[$i], $v2->[$i], "$access_key\->[$i]");
	}
}



1;


