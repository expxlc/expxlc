package Parsers;

use strict;
use warnings;

use Data::Dumper;

use POSIX qw( !assert );
use Exporter;

require Utils;  # Must use require, to get INC updated
import Utils qw( &get_progname &get_progpath );

BEGIN {
    @Parsers::ISA = ('Exporter');
    @Parsers::EXPORT_OK =
        qw( &parse_xlc &parse_cnbc &parse_xmap
            &parse_instance &parse_explanations
            &parse_blc &parse_acc );
}

use constant F_ERR_MSG =>
    "Please check file name, existence, permissions, etc.\n";
use constant HLPMAP => 1;
use constant CCAT_CH => '_';
use constant CCHK => 0;

if (CCHK) {
    ## Uncomment to use assertions && debug messages
    #use Carp::Assert; # Assertions are on.
}


# Parse XLC format
sub parse_xlc()
{
    my ($opts, $xlc, $fname) = @_;

    open(my $fh, "<$fname") || die "Unable to open file $fname. " . F_ERR_MSG;
    my ($nc, $nr, $rmode) = (0, 0, 0);
    while(<$fh>) {
        chomp;
        next if m/^\s*c\s+$/;
        if ($rmode == 0) {        # Read number of features
            m/^\s*(\d+)\s*$/ || die "Unable to match: $_\n";
            ($xlc->{NV}, $rmode) = ($1, 1);
        }
        elsif ($rmode == 1) {     # Read w0
            m/^\s*(\-?\d+\.?\d*)\s*$/ || die "Unable to match: $_\n";
            ($xlc->{W0}, $rmode) = ($1, 2);
        }
        elsif ($rmode == 2) {     # Read number of real-valued features
            m/^\s*(\d+)\s*$/ || die "Unable to match: $_\n";
            ($xlc->{NReal}, $rmode) = ($1, 3);
            if ($xlc->{NReal} == 0) { $rmode = 4; }
        }
        elsif ($rmode == 3) {     # Read real-valued coefficients
            m/^\s*(\-?\d+\.?\d*)\s*$/ || die "Unable to match: $_\n";
            push @{$xlc->{RVs}}, $1;
            if (++$nr == $xlc->{NReal}) { ($nr, $rmode) = (0, 4); }
        }
        elsif ($rmode == 4) {     # Read number of categorical features
            m/^\s*(\d+)\s*$/ || die "Unable to match: $_\n";
            ($xlc->{NCat}, $rmode) = ($1, 5);
        }
        elsif ($rmode == 5) {     # Read domains and weights of cat. features
            my $cvi = "CVs$nc";
            @{$xlc->{$cvi}} = split(/ +/);
            push @{$xlc->{CDs}}, shift @{$xlc->{$cvi}};
            if (++$nc == $xlc->{NCat}) { $rmode = 6; }
        }
        else { die "Invalid state with input: $_\n"; }
    }
    close($fh);
}


# Parse map file
sub parse_xmap()
{
    my ($opts, $xmap, $fname) = @_;

    open(my $fh, "<$fname") || die "Unable to open file $fname. " . F_ERR_MSG;
    my ($cc, $nv, $nc, $nr, $rmode) = (0, 0, 0, 0, 0);
    while(<$fh>) {
        chomp;
        next if m/^\s*c\s+$/;
        if ($rmode == 0) {        # Read number of classes
            m/^\s*(\d+)\s*$/ || die "Unable to match: $_\n";
            ($xmap->{NC}, $rmode, $cc) = ($1, 1, 0);
            if ($xmap->{NC} == 0) { $rmode = 2; }
        }
        elsif ($rmode == 1) {     # Read class name maps
            my @toks = split(/ +/);
            my $cid = shift @toks;
            ${$xmap->{ClMap}}[$cid] = join(CCAT_CH, @toks);
            if (++$cc == $xmap->{NC}) { $rmode = 2; }
        }
        elsif ($rmode == 2) {     # Read number of features
            m/^\s*(\d+)\s*$/ || die "Unable to match \@ $rmode: $_\n";
            ($xmap->{NV}, $rmode) = ($1, 3);
        }
        elsif ($rmode == 3) {     # Read number of real-valued features
            m/^\s*(\d+)\s*$/ || die "Unable to match \@ $rmode: $_\n";
            ($xmap->{NReal}, $rmode, $nr) = ($1, 4, 0);
            if ($xmap->{NReal} == 0) { $rmode = 5; }
        }
        elsif ($rmode == 4) {     # Read map of real-value features
            my @toks = split(/ +/);
            my $rid = shift @toks;
            ${$xmap->{VMap}}[$rid] = join(CCAT_CH, @toks);
            if (++$nr == $xmap->{NReal}) { $rmode = 5; }
        }
        elsif ($rmode == 5) {     # Read number of categorical features
            m/^\s*(\d+)\s*$/ || die "Unable to match \@ $rmode: $_\n";
            ($xmap->{NCat}, $rmode, $nc) = ($1, 6, $nr);
        }
        elsif ($rmode == 6) {     # Read categorical feature
            my @toks = split(/ +/);
            my $cid = shift @toks;
            if (!HLPMAP) {
                ${$xmap->{VMap}}[$cid] = join(CCAT_CH, @toks); }
            else {
                my ($sch, $ech, $jch) = ('', '', '');
                if ($#toks > 0) { ($sch, $ech, $jch) = ('\'', '\'', ' '); }
                ${$xmap->{VMap}}[$cid] = $sch . join($jch, @toks) . $ech;
            }
            $rmode = 7;
            if (CCHK) { assert($cid == $nc, "Invalid categorical ID"); }
        }
        elsif ($rmode == 7) {     # Read domain size of current feature
            m/^\s*(\d+)\s*$/ || die "Unable to match \@ $rmode: $_\n";
            ($xmap->{CDs}->{$nc}, $rmode, $nv) = ($1, 8, 0);
        }
        elsif ($rmode == 8) {     # Read values of categorical feature
            my @toks = split(/ +/);
            my $vid = shift @toks;
            if (!HLPMAP) {
                ${$xmap->{CMap}->{$nc}}[$vid] = join(CCAT_CH, @toks); }
            else {
                my ($repl, $sch, $ech, $jch) = (0, '', '', '');
                for (my $i=0; $i<=$#toks; ++$i) {
                    if ($toks[$i] =~ m/${$xmap->{VMap}}[$nc]/) {
                        $toks[$i] =~ s/${$xmap->{VMap}}[$nc]/\?\?/g;
                        $repl = 1;
                    }
                }
                if ($#toks > 0 && !$repl) { ($sch,$ech,$jch)=('\'','\'',' '); }
                ${$xmap->{CMap}->{$nc}}[$vid] = $sch . join($jch, @toks) . $ech;
            }
            if (++$nv == $xmap->{CDs}->{$nc}) {
                if (++$nc == $xmap->{NReal}+$xmap->{NCat}) { $rmode = 9; }
                else                                       { $rmode = 6; }
            }
        }
        else { die "Invalid state with input \@ $rmode: $_\n"; }
    }
    close($fh);
}


# Parse CNBC format -- currently hard-coded for 2 classes
sub parse_cnbc()
{
    my ($opts, $cnbc, $fname) = @_;

    open(my $fh, "<$fname") || die "Unable to open file $fname. " . F_ERR_MSG;
    my ($cc, $cv, $pol, $rmode) = (0, 0, 0, 0);
    while(<$fh>) {
        chomp;
        if ($rmode == 0) {        # Read number of classes
            m/^\s*(\d+)\s*$/ || die "Unable to match: $_\n";
            ($cnbc->{NC}, $rmode, $cc) = ($1, 1, 0);
        }
        elsif ($rmode == 1) {     # Read priors
            m/^\s*(\-?\d+\.?\d*)\s*$/ || die "Unable to match: $_\n";
            push @{$cnbc->{Prior}}, $1;
            if (++$cc == $cnbc->{NC}) { $rmode = 2; }
        }
        elsif ($rmode == 2) {     # Read number of features
            m/^\s*(\d+)\s*$/ || die "Unable to match: $_\n";
            ($cnbc->{NV}, $cv, $rmode) = ($1, 0, 3);
        }
        elsif ($rmode == 3) {     # Read domain size of feature
            my $cpt = "CPT$cv";
            if ($cv == $cnbc->{NV}) { die "Too many features specified?\n"; }
            m/^\s*(\d+)\s*$/ || die "Unable to match: $_\n";
            ($cnbc->{$cpt}->{D}, $cc, $rmode) = ($1, 0, 4);
        }
        elsif ($rmode == 4) {     # Read CPT for feature
            my $cpt = "CPT$cv";
            my $ccl = "C$cc";
            my @probs = split(/ +/);
            if ($#probs+1 != $cnbc->{$cpt}->{D}) { die "Invalid CPT def\n"; }
            for (my $i=0; $i<=$#probs; ++$i) {
                $probs[$i] =~ m/(\-?\d+\.?\d*)/ || die "Unable to match: $_\n";
                push @{$cnbc->{$cpt}->{$ccl}}, $probs[$i];
            }
            if (++$cc == $cnbc->{NC}) {
                ($cv, $cc, $rmode) = ($cv+1, 0, 3);  # Move to next feature
            }
        } else { die "Unexpected read mode in CNBC file\n"; }
    }
    close($fh);
}


# Parse BLC format
sub parse_blc()
{
    my ($opts, $blc, $fname) = @_;
    open(my $fh, "<$fname") || die "Unable to open file $fname. " . F_ERR_MSG;
    my ($rmode, $cnt) = (0, 0);
    while(<$fh>) {
        next if m/^\s*$/ || m/^c\s+/;
        chomp;
        if ($rmode == 0) {
            m/\s*(\d+)\s*$/ || die "Unable to match: $_\n";
            ($blc->{NV}, $rmode) = ($1, 1);
        }
        elsif ($rmode == 1) {
            if ($cnt == $blc->{NV}+1) {
                die "Too many lines in BLC description??\n"; }
            m/^\s*(\-?\d+\.?\d*)\s*$/ || die "Unable to match: $_\n";
            ${$blc->{Ws}}[$cnt++] = $1;
        }
    }
    close($fh);
}

# Parse ACC format
sub parse_acc()
{
    my ($opts, $acc, $fname) = @_;

    open(my $fh, "<$fname") || die "Unable to open file $fname. " . F_ERR_MSG;
    my ($cc, $cv, $pol, $rmode) = (0, 0, 0, 0);
    while(<$fh>) {
        next if m/^\s*$/ || m/^c\s+/;
        chomp;
        if ($rmode == 0) {
            m/\s*(\d)\s*$/  || die "Unable to match: $_\n";
            ($acc->{NC}, $rmode) = ($1, 1);
        }
        elsif ($rmode == 1) {
            m/\s*(\d+)\s*$/  || die "Unable to match: $_\n";
            ($acc->{NV}, $rmode) = ($1, 2);
        }
        elsif ($rmode == 2) {
            my $class = "C$cc";
            m/^\s*(\-?\d+\.?\d*)\s*$/  || die "Unable to match: $_\n";
            $acc->{VV}->{$class}->{W0} = $1;
            $rmode = 3;
        }
        elsif ($rmode == 3) {
            my $class = "C$cc";
            my $polarity = "P$pol";
            m/^\s*(\-?\d+\.?\d*)\s*$/ || die "Unable to match: $_\n";
            ${$acc->{VV}->{$class}->{$polarity}}[$cv] = $1;
            $pol = 1 - $pol;
            if ($pol == 0) { $cv++; }
            if ($cv == $acc->{NV}) {
                ($cc, $cv, $pol) = ($cc+1, 0, 0);
                if ($cc == $acc->{NC}) { last; }
                $rmode = 2;
            }
        }
    }
    close($fh);
}


# Parse instance format
sub parse_instance()
{
    my ($opts, $inst, $fname) = @_;

    open(my $fh, "<$fname") || die "Unable to open file $fname. " . F_ERR_MSG;
    my ($cnt, $rmode) = (0, 0);
    while(<$fh>) {
        next if m/^\s*$/ || m/^c\s+/;
        chomp;
        if ($rmode == 0) {
            m/\s*(\d+)\s*$/ || die "Unable to match: $_\n";
            ($inst->{NV}, $rmode) = ($1, 1);
        }
        elsif ($rmode == 1) {
            m/\s*(\d+)\s*$/ || die "Unable to match: $_\n";
            ${$inst->{E}}[$cnt++] = $1;
            if ($cnt == $inst->{NV}) { $rmode = 2; }
        }
        elsif ($rmode == 2) {
            m/\s*(\d+)\s*$/ || die "Unable to match: $_\n";
            $inst->{C} = $1;
        }
    }
    close($fh);
}

# Parse explanations
sub parse_explanations()
{
    my ($fname, $xpl) = @_;
    open(my $fh, "<$fname") || die "Unable to open file $fname. " . F_ERR_MSG;
    while(<$fh>) {
        next if m/^\s*$/ || m/^c\s+/;
        chomp;
        my @lits = split(/ +/);
        shift @lits; # Drop 'Expl: '
        push @{$xpl->{Expl}}, \@lits;
    }
    close($fh);
}


END {
}

1;  # to ensure that the 'require' or 'use' succeeds
