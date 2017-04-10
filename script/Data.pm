package Data;

use strict;
use warnings;

use List::Util qw(sum);

require Exporter;

our @ISA = qw(Exporter);

our %EXPORT_TAGS = (
    'math' => [ qw(average varince stddev sum round median) ],
    'csv'  => [ qw(loadcsv sortapp)                         ],
    'log'  => [ qw(errorp error $SYNTAX)                    ],
    'plot' => [ qw(graph histogram gnuplot)                 ],
    'all'  => [ qw(average varince stddev sum round median
                   loadcsv sortapp
                   errorp error $SYNTAX
                   graph histogram gnuplot)                 ]
    );

our @EXPORT_OK = ( @{$EXPORT_TAGS{'all'}} );


# Runtime =====================================================================

our $SYNTAX = undef;

sub errorp
{
    my ($message, $retcode) = @_;
    my $progname = $0;

    if (!defined($message)) { $message = 'undefined error'; }
    if (!defined($retcode)) { $retcode = 1; }
    
    $progname =~ s|^.*/||;

    printf(STDERR "%s: %s: %s\n", $progname, $message, $!);
    if (defined($SYNTAX)) { printf(STDERR "Syntax: %s\n", $SYNTAX); }
    exit ($retcode);
}

sub error
{
    my ($message, $retcode) = @_;
    my $progname = $0;

    if (!defined($message)) { $message = 'undefined error'; }
    if (!defined($retcode)) { $retcode = 1; }
    
    $progname =~ s|^.*/||;

    printf(STDERR "%s: %s\n", $progname, $message);
    if (defined($SYNTAX)) { printf(STDERR "Syntax: %s\n", $SYNTAX); }
    exit ($retcode);
}


# Input helpers ===============================================================

sub loadcsv
{
    my ($file, $func) = @_;
    my ($fd, $line, @arr, $fdef);

    if (!defined($file))        { error("missing csv operand"); }
    if (!open($fd, '<', $file)) { errorp("cannot load csv '$file'"); }
    if (!defined($func)) {
	$fdef = 1;
	$func = sub {
	    push(@arr, \@_);
	};
    }
    
    while (defined($line = <$fd>)) {
	chomp($line);
	next if ($line =~ /^\s*#/);
	next if ($line =~ /^\s*$/);

	$func->(split(',', $line));
    }

    close($fd);
    
    if (defined($fdef)) {
	return \@arr;
    }
}

sub sortapp
{
    my (@apps) = @_;
    my @order = qw(bodytrack facesim fluidanimate streamcluster swaptions
                   x264 bt.C cg.C dc.B ep.D ft.C lu.C mg.D sp.C ua.C wc wr
                   wrmem pca kmeans psearchy memcached belief bfs cc pagerank
                   sssp cassandra mongodb);
    my %ordinals;
    my ($e, $c);

    $c = 0;
    foreach $e (@order) {
	$ordinals{$e} = $c++;
    }

    return sort {
	my ($orda, $ordb) = ($ordinals{$a}, $ordinals{$b});

	if (!defined($orda) || !defined($ordb)) {
	    $a cmp $b;
	} else {
	    $orda <=> $ordb;
	}
    } @apps;
}


# Gnuplot helpers =============================================================

sub graph
{
    return <<'EOF';
set terminal pdfcairo;
set border 3;
set xtics nomirror;
set ytics nomirror;
set grid y;

set style line 1 linecolor rgb 'black' dashtype 1 pointtype 1;
set style line 2 linecolor rgb 'black' dashtype 2 pointtype 6;
set style line 3 linecolor rgb 'black' dashtype 3 pointtype 2;
set style line 4 linecolor rgb 'black' dashtype 4 pointtype 4;

set yrange [0:];
EOF
}

sub histogram
{
    return graph() . <<'EOF';
set style data histogram;
set style fill solid border -1;
set boxwidth 1;
EOF
}

sub gnuplot
{
    my ($gnucode) = @_;
    return system('gnuplot', '-e', $gnucode);
}


# Math helpers ================================================================

sub _takelist
{
    my @list = @_;

    if (scalar(@list) == 1 && ref($list[0]) eq 'ARRAY') { 
	@list = @{$list[0]};
    }

    return @list;
}

sub round
{
    return map {
	if (($_ - int($_)) >= 0.5) {
	    int($_) + 1;
	} else {
	    int($_);
	}
    } @_;
}

sub average
{
    my @list = _takelist(@_);
    return sum(@list) / scalar(@list);
}

sub median
{
    my @list = _takelist(@_);
    return (sort { $a <=> $b } @list)[scalar(@list) / 2];
}

sub variance
{
    my @list = _takelist(@_);
    my $avg = average(@list);
    return sum(map { ($_ - $avg) ** 2 } @list) / scalar(@list);
}

sub stddev
{
    my @list = _takelist(@_);
    return sqrt(variance(@list));
}


1;
__END__
