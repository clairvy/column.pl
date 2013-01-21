#!/usr/bin/env perl
# -*- mode: perl; -*-

use 5.008;
use strict;
use warnings;

package main;
use File::Basename ();
use Getopt::Long ();
use Text::ParseWords ();

our $VERSION = 0.001;
our ($Revision) = (q$Revision: 1608 $ =~ m/(\d+)/);
our $debug_flag = 0;
our $verbose_flag = 0;

sub usage
{
    my $cmd = File::Basename::basename($0);

    return <<"    EOL";
NAME
SYNOPSYS
  $cmd [option ...]

OPTIONS
: -d <delimiter>

: -pd <delimiter for print>

: -t
  trim or not.

: -right <num>
  <num>th column treated as align right.
  NOTICE <num> is ZERO-origin.
  <num> can take negative number.

: -comment
  treat line start '#' as comment.

: -skipline
  skip blank line. like comment.

: -help
  print this message.

: -version
  print version.

DESCRIPTION

    EOL
}
sub get_version
{
    return $VERSION;
}
sub prepare_align
{
    my ($right, $size) = @_;
    my %buf;
    my @right = expand_num($right, $size);
    foreach (@right) {
        $buf{$_} = 1;
    }
    print("righten pos(recognised): ", join(", ", sort {$a <=> $b} keys(%buf)), "\n") if ($verbose_flag);
    return \%buf;
}
# expected to return array include positive numbers.
sub expand_num
{
    my ($nums, $size) = @_;
    my $num_expr = qr/[-+]?[0-9]+/;
    my @buf;
    foreach (@$nums) {
        my $n = $_;
        push(@buf, split(qr/,/, $n));
    }
    my @num;
    my @err;
    foreach my $n (@buf) {
        unless ($n =~ m/^($num_expr)(?:(-)($num_expr)?)?$/) {
            push(@err, "cannot parse $n\n");
            next;
        }
        my ($s, $bar, $e) = ($1, $2, $3);
        unless (defined($bar)) { # not range
            $s = $n + 0;
            $e = $s;
        }
        unless (defined($e)) { # not found end
            $e = $size - 1;
        }
        $s %= $size;
        $e %= $size;
        unless ($s < $e) {
            ($s, $e) = ($e, $s);
        }
        push(@num, $s .. $e);
    }
    if (@err > 0) {
        die(@err);
    }
    return @num;
}
sub main
{
    my $help_flag = 0;
    my $version_flag = 0;

    my $delm = '\s+';
    my $print_delm = ' ';
    my $trim_flag = 0;
    my @right;
    my $comment_flag;
    my $skipline_flag;
    my $option_def = {
        'help|h!' => \$help_flag,
        'verbose!' => \$verbose_flag,
        'version|v!' => \$version_flag,
        'debug!' => \$debug_flag,

        'd=s' => \$delm,
        'pd=s' => \$print_delm,
        'trim|t!' => \$trim_flag,
        'right=s' => \@right,

        'comment|c!' => \$comment_flag,
        'skipline|s!' => \$skipline_flag,
    };
    Getopt::Long::GetOptions(%{$option_def});

    if ($help_flag) {
        print(usage(), "\n");
        exit(0);
    }
    if ($version_flag) {
        print(get_version(), "\n");
        exit(0);
    }
    my @len;
    my @buf;
    while (1) {
        my $line = <>;
        last unless (defined($line));
        my $keep = 1;
        chomp($line);

        if (($comment_flag and $line =~ m/^\s*#/) or
            ($skipline_flag and $line =~ m/^\s*$/))
        {
            push(@buf, $line);
            next;
        }
        if ($trim_flag) {
            $line =~ s/^\s+//;
            $line =~ s/\s+$//;
        }
        my @token = Text::ParseWords::quotewords($delm, $keep, $line);
        map {s/^\s+//;s/\s+$//;} @token if ($trim_flag);
        @token = map {defined($_) ? $_ : ''} @token;
        my @len_buf = map {length($_)} @token;
        foreach my $i (0 .. scalar(@token) - 1) {
            next unless (not defined($len[$i]) or ($len[$i] < $len_buf[$i]));
            $len[$i] = $len_buf[$i];
        }
        push(@buf, [@token]);
    }

    my $right = prepare_align(\@right, scalar(@len));

    print(join(q{:}, @len), "\n") if ($debug_flag);

    foreach (@buf) {
        unless (ref($_)) {
            print($_, "\n");
            next;
        }
        my @token = @$_;
        my @pbuf;
        my $last_index = scalar(@token) - 1;
        foreach my $i (0 .. $last_index) {
            my $align = '-';
            my $len = $len[$i];
            if (exists($right->{$i})) {
                $align = '';
            }
            if ($i == $last_index and $align eq '-') {
                $len = 0;
            }
            my $f = "%" . $align . $len . "s";
            push(@pbuf, sprintf($f, $token[$i]));
        }
        print(join($print_delm, @pbuf), "\n");
    }
}

{
    my $fname = File::Basename::basename(__FILE__);
    if (File::Basename::basename($0) eq $fname) {
        main();
        exit(0);
    }
}
1;
