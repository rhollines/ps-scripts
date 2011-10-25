#!/usr/bin/perl -w

# Output to stdout a list of C# executables and dlls.  Suggested usage:
#
# perl findAssemblies.pl . > assemblies.txt
# cov-analyze-cs --dir intermediate --concurrency @assemblies.txt

use strict;

use File::Find;

# map of base filename -> fullpath including filename
#
# use a map to ensure that only the first found binary is included because
# often the same binary exists in both the bin and obj directories
my %hash = ();

sub wanted {
    if (! -f) {  # is $_ not a plain file?
        return;
    }

    if (!(/.*exe$/ || /.*dll$/)) {
        return;
    }

    my $fileName = $_;
    my $filePath = $File::Find::name;

    # .pdb contains debugging information and it must exist alongside the
    # binary for cov-analyze-cs to proceed
    my $pdb = substr($fileName, 0, -3) . 'pdb';
    if (! -e $pdb) {
        return;
    }


    # to determine if this binary is managed or not we'll use the Microsoft
    # CorFlags.exe which displays some flags for a given assembly.
    #
    # Exit status:
    # 0 = no error, binary is managed
    # 1 = not managed
    # C:\Program Files\Microsoft SDKs\Windows\v7.0\Bin\x64
    my $result = `"C:\\Program Files\\Microsoft SDKs\\Windows\\v7.0\\Bin\\x64\\corflags" "$fileName"`;

    if ($? == 0) {
        # don't overwrite pre-existing entries
        if (!exists($hash{$fileName})) {
            $hash{$fileName} = $filePath;
        }
    }
}

# first command line argument is the search path root
if ($#ARGV != 0) {
    print "usage: perl findAssemblies.pl PATH\n";
    exit;
}


sub preprocess {
    my @list;

    foreach my $f (@_) {
        if (-d $f && $f eq 'bin') {
            next;  # don't traverse into bin directories
        }
        push(@list, $f);
    }

    return @list;
}


find({
    wanted => \&wanted,
    preprocess => \&preprocess,
}, $ARGV[0]);

foreach my $key (keys %hash) {
    print $hash{$key}, "\n";
}
