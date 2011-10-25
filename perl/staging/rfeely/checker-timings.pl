#!/usr/bin/perl
use Data::Dumper;

$intdir = $ARGV[0];
$maxTime = $ARGV[1];

opendir(INT, "$intdir/c");
@files = grep { m/^output.?/ } readdir(INT);
closedir(INT);

$outputDirCount=0;
%newAnalysis ;

print '@echo off'."\n";

sub convertTimeS {

                my $ms = shift;
                my $ret = "";

                @parts = gmtime($ms);
                
                $ret = sprintf("%02d:%02d:%02d:%02d", @parts[7,2,1,0]);

                return $ret;
}

sub convertTime {
                my $ms = shift;
                return convertTimeS($ms/1000);
}


for $fl (@files) {
                $rollingTime = 0;
                $overheadTime = 0;
                print "REM dir: $fl\n";
                
                if ($fl =~ m/output.?/) {
                
                                ## find the checkers which actually ran..
                                print "REM ------------------------------------------------------\n";
                                open(T, "$intdir/c/$fl/ANALYSIS.metrics.xml") || die "Couldnt open";
                                $contents = "";
                                while(<T>) {
                                                chomp;
                                                $contents .= $_;
                                }
                                close(T);
                                
                                if($contents =~ m|enabled-checkers</name>\s+<value>(.+?)</value>|) {
                                                @checkers = split(',', $1);
                                }

                                if($contents =~ m|time</name>\s+<value>(.+?)</value>|) {
                                                print "REM Total time: $1 s  " . convertTimeS($1) . " \n";
                                }
                                
                                ## create a map of how long the checkers took to run..
                                open(T, "$intdir/c/$fl/timing.txt");
                                while(<T>) { 
                                                chomp; 
                                                if ($_ =~ m/^(\w+)\s+(\d+)/) {
                                                                $checkerTimes{$1} = $2;
                                                                #print "$1 => $2\n";
                                                }
                                                
                                                if ($_ =~ m/^Compute topo.+?(\d+)/) {
                                                                $overheadTime = $overheadTime + $1;
                                                }
                                                
                                                if ($_ =~ m/^build vir.+?(\d+)/) {
                                                                $overheadTime = $overheadTime + $1;
                                                }

                                                if ($_ =~ m/^types.warning pass.+?(\d+)/) {
                                                                $overheadTime = $overheadTime + $1;
                                                }

                                                if ($_ =~ m/^.+?_DERIVERS\s+(\d+)/) {
                                                                $overheadTime = $overheadTime + $1;
                                                }
                                                
                                }
                                close(T);
                                
                                
                                print "REM --- Overhead time: $overheadTime  " . convertTime($overheadTime)." (dd:hh:mm:ss) \n";
                                
                                %runTimes = ();
                                for $ch (@checkers) {
                                                $runTimes{$ch} = $checkerTimes{$ch};
                                                my $tm = $checkerTimes{$ch};
                                                my $tmsec = $tm / 1000;
                                                printf "REM %30s %7d ms (%s)\n", $ch, $tm, convertTime($tm);
                                }
                                
                                @pr = sort { $runTimes{$b} <=> $runTimes{$a} } keys %runTimes;
                                
                                for $pp (@pr) {
                                                $newAnalysis{$outputDirCount}{$pp} = $checkerTimes{$pp};
                                                $rollingTime = $rollingTime + $checkerTimes{$pp};
                                                if ($rollingTime > $maxTime) {
                                                                #print "rolling time: $rollingTime\n";
                                                                $rollingTime = 0;
                                                                $outputDirCount++;
                                                }
                                
                                }
                                
                }
}

for $k (keys %newAnalysis) {
                %t = %{ $newAnalysis{$k} };
                
                print "cov-analyze --dir $ARGV[0] --outputdir $ARGV[0]/c/parallel-output-$k --disable-default ";
                for $p (keys %t) {

                                print " --enable $p ";
                }
                print "\n\n";
}

#print Dumper(%newAnalysis);


