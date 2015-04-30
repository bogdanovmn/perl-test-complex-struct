package Test::ComplexStruct;

use strict;
use warnings;
use utf8;

use Test::ComplexStruct::Options;
use Test::More;
use Data::Dumper;
use Exporter 'import';

our @EXPORT = qw/
	check_complex_struct

	TYPE_JSON_BOOLEAN
	OPTIONAL
	OPTIONAL_SCALAR
	OPTIONAL_BOOLEAN
	OPTIONAL_INT
	OPTIONAL_UINT
	OPTIONAL_NATURAL
	OPTIONAL_RELATIVE_LINK
	OPTIONAL_LINK
	CAN_BE_EMPTY
	DYNAMIC_KEYS
	EQ
	SKIP

	NATURAL
	BOOLEAN
	UINT
	INT
	NOT_EMPTY_STRING
	LINK
	RELATIVE_LINK
/;
#
# Value types
#
use constant TYPE_UNDEF         => 'UNDEF';
use constant TYPE_SCALAR        => 'SCALAR';
use constant TYPE_HASH          => 'HASH';
use constant TYPE_ARRAY         => 'ARRAY';
use constant TYPE_CODE          => 'CODE';
use constant TYPE_REGEXP        => 'Regexp';
use constant TYPE_JSON_BOOLEAN  => bless {}, 'JSON::PP::Boolean';
#
# Base meta keys
#
use constant META_OPTIONAL          => '__optional';
use constant META_VALUE             => '__value';
use constant META_SHORT             => '__short';
use constant META_FULL              => '__full';
use constant META_DYNAMIC_KEYS      => '__dynamic_keys';
use constant META_FULL_VIEW_COND    => '__full_view_cond';
use constant META_CAN_BE_EMPTY      => '__can_be_empty';
use constant META_DESCR             => '__descr';
use constant META_SKIP              => '__skip';
use constant META_DYNAMIC_PROTOTYPE => '__dynamic_prototype';
#
# Meta macros
#
use constant OPTIONAL         => ( (META_OPTIONAL)     => 1, META_VALUE );
use constant CAN_BE_EMPTY     => ( (META_CAN_BE_EMPTY) => 1, META_VALUE );
use constant DYNAMIC_KEYS     => ( (META_DYNAMIC_KEYS) => 1, META_VALUE );
use constant EQ               => (  META_VALUE                          );

use constant NOT_EMPTY_STRING => { (META_DESCR) => 'must be not empty string', (META_VALUE) => qr{^.+$} };

use constant _INT_KEYS           => ((META_DESCR) => 'must be integer',          (META_VALUE) => qr{^(0|-?[1-9]\d*)$});
use constant _UINT_KEYS          => ((META_DESCR) => 'must be unsigned integer', (META_VALUE) => qr{^([1-9]\d+|\d)$});
use constant _NATURAL_KEYS       => ((META_DESCR) => 'must be natural integer',  (META_VALUE) => qr{^[1-9]\d*$});
use constant _BOOLEAN_KEYS       => ((META_DESCR) => 'must be boolean (0|1)',    (META_VALUE) => qr{^(0|1)$});
use constant _RELATIVE_LINK_KEYS => ((META_DESCR) => 'must be relative link',    (META_VALUE) => qr{^(/[a-z0-9._#-]+)+/?$});
use constant _LINK_KEYS          => ((META_DESCR) => 'must be absolute link',    (META_VALUE) => qr{^https?:/(/[a-z0-9._#-]+)+/?$});

use constant INT           => { _INT_KEYS };
use constant UINT          => { _UINT_KEYS };
use constant NATURAL       => { _NATURAL_KEYS };
use constant BOOLEAN       => { _BOOLEAN_KEYS };
use constant RELATIVE_LINK => { _RELATIVE_LINK_KEYS };
use constant LINK          => { _LINK_KEYS };

use constant SKIP                   => { (META_SKIP)     => 1, (META_OPTIONAL) => 1 };
use constant OPTIONAL_SCALAR        => { (META_OPTIONAL) => 1, (META_VALUE) => '' };
use constant OPTIONAL_INT           => { (META_OPTIONAL) => 1, _INT_KEYS    };
use constant OPTIONAL_UINT          => { (META_OPTIONAL) => 1, _UINT_KEYS    };
use constant OPTIONAL_NATURAL       => { (META_OPTIONAL) => 1, _NATURAL_KEYS };
use constant OPTIONAL_BOOLEAN       => { (META_OPTIONAL) => 1, _BOOLEAN_KEYS };
use constant OPTIONAL_RELATIVE_LINK => { (META_OPTIONAL) => 1, _RELATIVE_LINK_KEYS };
use constant OPTIONAL_LINK          => { (META_OPTIONAL) => 1, _LINK_KEYS };


my %OPTIONAL_KEY_CHECKED;


sub _check_required_keys {
	my ($test_hashref, $check_keys, $test_name) = @_;
	
	my $expected_key;
	foreach my $k (@$check_keys) {
		unless (exists $test_hashref->{$k}) {
			$expected_key = $k;
			last;
		}
	}
	return is undef, $expected_key, $test_name;
}

sub _check_extra_keys {
	my ($test_hashref, $proto_keys, $test_name) = @_;
	my %all_keys = map { $_ => undef } @$proto_keys;

	my $extra_key;
	foreach my $k (keys %$test_hashref) {
		unless (exists $all_keys{$k}) {
			$extra_key = $k;
			last;
		}
	}
	return is $extra_key, undef, $test_name;
}

sub check_complex_struct {
	my ($check_value, $proto_value, $test_name, $options) = @_;

	my $check_type  = ref $check_value || (defined $check_value ? TYPE_SCALAR : TYPE_UNDEF);
	my $proto_type  = ref $proto_value || TYPE_SCALAR;

	my $test_descr;
	my $is_optional;
	my $can_be_empty;
	my $full_view_cond;
	my $check_complete_value = 0;

	my $has_dynamic_keys;
	my %dynamic_key;
	my $check_dynamic_key = 0;

	my $is_root = not $options->{is_not_root};
	if ($is_root) {
		$options->{is_not_root} = 1;
		$options->{path} = 'root';
	}
	#
	# Если значение - хэш, то возможно через ключи указаны мета-атрибуты
	#
	my @meta_keys = $proto_type eq TYPE_HASH
		? ( grep { /^__/ } keys %$proto_value )
		: ();
	if (@meta_keys) {
		#
		# Если прототип динамический, т.е. зависит от значений в структуре $check_value
		# то вызываем сабу, которая вернет нам нужный прототип и погружаемся в рекурсию
		#
		if ($proto_value->{(META_DYNAMIC_PROTOTYPE)}) {
			if (ref $proto_value->{(META_VALUE)} ne 'CODE') {
				die '__value must be coderef';
			}
			return check_complex_struct(
				$check_value,
				$proto_value->{(META_VALUE)}->($check_value),
				$test_name,
				$options
			);
		}
		#
		# Пропустить проверку этого значения
		#
		if ($proto_value->{(META_SKIP)}) {
			return ok 1, sprintf("%s >> just skip it", $test_name);
		}

		$test_descr   = $proto_value->{(META_DESCR)};
		$is_optional  = $proto_value->{(META_OPTIONAL)};
		$can_be_empty = $proto_value->{(META_CAN_BE_EMPTY)};
		#
		# Список динамичных ключей может быть сильно ограниченным
		# Таким образом мы можем и это проверить
		#
		$has_dynamic_keys = $proto_value->{(META_DYNAMIC_KEYS)} ? 1 : 0;
		if ($has_dynamic_keys and ref $proto_value->{(META_DYNAMIC_KEYS)} eq TYPE_ARRAY) {
			%dynamic_key = map { $_ => undef } @{$proto_value->{(META_DYNAMIC_KEYS)}};
			$check_dynamic_key = 1;
		}
		#
		# Если кол-во элементов массива больше $full_view_cond, то 
		# значение проверяется по прототипу __short, иначе по __full
		#
		($full_view_cond) = $proto_value->{(META_FULL_VIEW_COND)} || "" =~ /^(\d+)$/;
		#
		# Это нужно, чтобы указать мета-атрибуты для списоков, скаляров или других отличных от хэшей значений
		#
		if (exists $proto_value->{(META_VALUE)}) {
			$proto_value = $proto_value->{(META_VALUE)}; 
			$proto_type  = ref $proto_value || TYPE_SCALAR;
			#
			# Если задан только один мета-ключ __value, то проверяем
			# значение полностью (а не только тип)
			#
			$check_complete_value  = 1 == @meta_keys;
		}
		else {
			die 'meta key "__value" expected!';
		}
		#
		# При задании условия __full_view_cond, ключи __full & __short - обязательны
		#
		if ($full_view_cond) {
			die '__value must be array ref'          unless ref $proto_value      eq TYPE_ARRAY;
			die '__value must contains one hash ref' unless ref $proto_value->[0] eq TYPE_HASH;
			die 'meta key "__full" expected!'        unless exists $proto_value->[0]->{(META_FULL)};
			die 'meta key "__short" expected!'       unless exists $proto_value->[0]->{(META_SHORT)};
		}
		#
		# Задаем явно тип прототипа, чтобы проверить правильность прототипа,
		# т.к. мы можем задать ключ __dynamic_keys и __value отличное от хэша,
		# но фактическое значение должно быть ссылкой на хэш
		#
		if ($has_dynamic_keys) {
			$proto_type = TYPE_HASH;
		}
	}
	
	my $check_regexp = 0;
	if ($proto_type eq TYPE_REGEXP) {
		$proto_type   = TYPE_SCALAR;
		$check_regexp = 1;
	}

	if ($is_optional) {
		if (defined $check_value) {
			$OPTIONAL_KEY_CHECKED{$options->{path}} = 1;
		}
		elsif (not $OPTIONAL_KEY_CHECKED{$options->{path}}) {
			$OPTIONAL_KEY_CHECKED{$options->{path}} = 0;
		}
	}

	if ($is_optional and not defined $check_value) {
		return ok 1, sprintf("%s >> value type (%s || undef)", $test_name, $proto_type);
	}
	elsif (is $check_type, $proto_type, sprintf("%s >> value type (%s)", $test_name, $proto_type)) {
		if ($proto_type eq TYPE_ARRAY) {
			unless (scalar @$proto_value) { # проверяем только тип
				if (IS_OPTION_STRICT) {
					ok 0, sprintf("%s >> empty prototype!", $test_name);
					_verbose($proto_value, $check_value);
				}
				return 1;
			}

			if (not @$check_value and not ok $can_be_empty, sprintf("%s >> can be empty", $test_name)) {
				_verbose($proto_value, $check_value);
			}

			$test_name       .= sprintf(' >> %s', $proto_type);

			if (scalar @$check_value) {
				my $total_elements = scalar @$check_value;
				#
				# Чтобы не проверять все 100500 элементов, вводим возможность ограничить сверху 
				# кол-во проверяемых элементов
				#
				my $elements_to_check = ($options->{max_elements_to_check} and $options->{max_elements_to_check} < $total_elements)
					? $options->{max_elements_to_check}
					: $total_elements;
				#
				# Иногда список содержит разные элементы, в таких случаях нужна проверка "1 в 1"
				# т.е. первый эелемент сверяется с первым элементом прототипа, второй со вторым и т.д.
				#
				my $static_check = 0;
				if (scalar @$proto_value > 1) {
					$elements_to_check = $total_elements;
					$static_check      = 1;
				}
				
				if ($static_check and $full_view_cond) {
					die 'check array element conflict: static check with full_view_cond!';
				}

				if ($static_check and not ok $total_elements eq scalar @$proto_value, $test_name. 's count') {
					_verbose($proto_value, $check_value);
					return 0;
				}

				my $element_proto_value = $static_check 
					? undef 
					: $full_view_cond
						? $proto_value->[0]->{ $total_elements > $full_view_cond ? META_SHORT : META_FULL }
						: $proto_value->[0];

				for (my $i = 0; $i < $elements_to_check; $i++) {
					return 0 unless check_complex_struct(
						$check_value->[$i], 
						$element_proto_value || $proto_value->[$i], 
						sprintf('%s.%d', $test_name, $i), 
						{ %$options, path => $options->{path}. ' >> array elem' }
					);
				}
			}
		}
		elsif ($proto_type eq TYPE_HASH) {
			if ($has_dynamic_keys) {
				while (my ($key, $value) = each %$check_value) {
					return 0 if $check_dynamic_key and not ok(exists $dynamic_key{$key}, $test_name. " >> dyn.key '$key' >> is legal");
					return 0 unless check_complex_struct(
						$value, 
						$proto_value, 
						$test_name. " >> dyn.key '$key'", 
						{ %$options, path => $options->{path}. ' >> dyn.key' }
					);
				}
			}
			else {
				#
				# Если хэш прототипа пустой, то проверка была только на тип
				#
				unless (scalar keys %$proto_value) { 
					if (IS_OPTION_STRICT) {
						ok 0, sprintf("%s >> empty prototype!", $test_name);
						_verbose($proto_value, $check_value);
					}
					return 1;
				}
				
				if (keys %$check_value) {
					my @proto_keys_all = keys %$proto_value;
					#
					# Фильтруем необязательные ключики
					#
					my @proto_keys_required = grep { not ref $proto_value->{$_} eq TYPE_HASH or not $proto_value->{$_}->{(META_OPTIONAL)} } @proto_keys_all;
					$test_name .= sprintf(' >> %s key', $proto_type);
					#
					# Необходимо проверить не только наличие всех обязательных полей, но и 
					# отсутсвие лишних
					#
					if (_check_required_keys $check_value, \@proto_keys_required, $test_name.'s required'
					and _check_extra_keys    $check_value, \@proto_keys_all,      $test_name.'s without extra') 
					{
						#
						# Рекурсивно проверяем все значнеия по всем фактическим ключам
						#
						foreach my $key (@proto_keys_all) {
							return 0 unless check_complex_struct(
								$check_value->{$key}, 
								$proto_value->{$key}, 
								$test_name. ' >> '. $key, 
								{ %$options, path => $options->{path}. ' >> '. $key }
							);
						}
					}
					else {
						_verbose($proto_value, $check_value);
						return 0;
					}
				}
				#
				# Пустой хэшик
				#
				else { 
					_verbose($proto_value, $check_value) unless ok $can_be_empty, sprintf("%s >> can be empty", $test_name);
				}
			}
		}
		#
		# Scalar check
		#
		else {
			if ($check_complete_value) {
				unless (is $check_value, $proto_value, $test_name. ' >> value') {
					_verbose($proto_value, $check_value);
					return 0;
				}
			}
			elsif ($check_regexp) {
				unless (like $check_value, $proto_value, $test_name. ' >> '. ($test_descr || 'value by regexp')) {
					_verbose($proto_value, $check_value);
					return 0;
				}
			}
			else {
				return 1;
			}
		}
	}
	else {
		_verbose($proto_value, $check_value);
		return 0;
	}

	if ($is_root) {
		if (IS_OPTION_WARN) {
			foreach my $path (grep { not $OPTIONAL_KEY_CHECKED{$_} } keys %OPTIONAL_KEY_CHECKED) {
				warn sprintf "[OPTIONAL KEY WARN] %s\n", $path;
			}
		}
	}

	return 1;
}

sub _verbose {
	my ($proto_value, $check_value) = @_;

	if (IS_OPTION_DEBUG) {
		$Data::Dumper::Maxdepth = 2;
		$Data::Dumper::Sortkeys = 1;
		print Dumper({
			proto => $proto_value,
			value => $check_value
		});
		$Data::Dumper::Maxdepth = 0;
	}
	exit unless IS_OPTION_SOFT;
}

1; 
