package Coverity::WS::v2::Serializer;

BEGIN {
    # namespaces and anonymous data structures
    my $ns   = 0;
    my $name = 0;
    my $prefix = 'c-';
    sub gen_ns { 'namesp' . ++$ns }
    sub gen_name { join '', $prefix, 'gensym', ++$name }
    sub prefix { $prefix =~ s/^[^\-]+-/$_[1]-/; $_[0]; }
}

#use strict;
use SOAP::Lite;
use parent -norequire, 'SOAP::Serializer';

sub encode_literal_array {
    my($self, $array, $name, $type, $attr) = @_;

    # If typing is disabled, just serialize each of the array items
    # with no type information, each using the specified name,
    # and do not crete a wrapper array tag.
    if (!$self->autotype) {
        $name ||= gen_name;
        return map {$self->encode_object($_, $name)} @$array;
    }

    my $items = 'item';

    # TODO: add support for multidimensional, partially transmitted and sparse arrays
    my @items = map {$self->encode_object($_, $items)} @$array;
    my $num = @items;
    my($arraytype, %types) = '-';
    for (@items) {
       $arraytype = $_->[1]->{'xsi:type'} || '-';
       $types{$arraytype}++
    }
    $arraytype = sprintf "%s\[$num]", keys %types > 1 || $arraytype eq '-'
        ? SOAP::Utils::qualify(xsd => $self->xmlschemaclass->anyTypeValue)
        : $arraytype;

    $type = SOAP::Utils::qualify($self->encprefix => 'Array')
        if !defined $type;

    return [$name || SOAP::Utils::qualify($self->encprefix => 'Array'),
        {
            SOAP::Utils::qualify($self->encprefix => 'arrayType') => $arraytype,
            'xsi:type' => $self->maptypetouri($type), %$attr
        },
        [ @items ],
        $self->gen_id($array)
    ];
}

1;
