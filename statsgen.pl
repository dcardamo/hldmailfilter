#!/usr/bin/perl 

###########################################################################
#      Copyright Dan Cardamore <wombat@hld.ca>
#      This program is licensed under the Gnu GPL.  Since this is free
#      software, the author assumes no liability for it and the damages
#      that it may cause.
#
#      Please read the README file.  For install instructions, please visit
#      http://www.hld.ca/opensource/hldfilter
#
###########################################################################
# 	$rcs = ' $Id: statsgen.pl,v 2.8 2001/06/01 15:30:59 wombat Exp $ ' ;
###########################################################################
use strict;
use Date::Manip;		# this is for logging the date
use GD::Graph::pie;		# for image manipulation
use GD::Graph::bars;		# for image manipulation
use Getopt::Long;		# for command line options
use Carp;
############################################################################

use vars (
	  '%rc',
	  '@stats',
	  '@spamstats',
	  '@ignore',
	  '%hashstats',
	  '%hashspamstats',
	  '$spamCount',
	  '$normalCount',
	  '$rblCount',
	  '$checkuserCount',
	  '%folderCount',
	  '%monthStats',
	  '%hourlyStats',
	  '$VERSION',
	  '$logfile',
	  '$opt_help',
	  '$opt_file',
	  '$opt_procmail',
	  '$opt_about'
         );

my $VERSION = "2.4";
my $uid = $>;
my $home = (getpwuid ($uid))[7];
my $configDir = $home . "/.hldfilter";
my $logfile = $configDir . "/log";

sub usage {
  print <<USAGE;
statsgen.pl --option value
    Copyright Dan Cardamore 2000 - 2001.  <wombat\@hld.ca>
    http://www.hld.ca/opensource/hldfilter
Options:
  --file:\t\tStats file name
  --procmail:\t\tParse file in procmail log format
  --about:\t\tInformation about this program
USAGE
}

sub about {
  print <<ABOUT;
Copyright Dan Cardamore 2000 - 2001.  <wombat\@hld.ca>
http://www.hld.ca/opensource/hldfilter

statsgen.pl is provided as part of the HLDFilter package which perfoms mail
filtering and web based statistics.  statsgen.pl can be used without hldfilter
to generate web statistics from procmail log files.

This program is released under the GNU GPL.  It is important to note that no
warranty of any kind is offered or implied with this software.

Please email me at wombat\@hld.ca for any bugs.  General discussions should be
directed to the mailing list at hldfilter\@hld.ca.
ABOUT
}

sub commandLine {
  &getOptions(
	      "file", \$opt_file,
	      "procmail", \$opt_procmail,
	      "about", \$opt_about,
	      "help", \$opt_help,
	      "<>", \&usage
	     );

  if (defined $opt_help) {
    &usage;
    exit;
  }

  if (defined $opt_about) {
    &about;
    exit;
  }

  if (defined $opt_file) {
    $logfile = $opt_file;
  }
}
sub error($)
  {
    my $error = shift;
    $error = "ERROR: $error";
    confess ($error);
  }

sub getConfig {
  open (RC, "<$configDir/hldfilter.rc") or &error($!);
  flock (RC, 2);
  while (<RC>) {
    chomp;
    s/#.*//;                	# no comments
    s/^\s+//;			# no leading white
    s/\s+$//;			# no trailing white
    next unless length;		# anything left?
    my ($var, $value) = split(/\s*=\s*/, $_, 2);
    $rc{$var} = $value;
  }
  flock (*RC, 8);
  close(*RC);

  open (IGNORE, "<$configDir/stats.ignore") or &error($!);
  flock (IGNORE, 2);
  @ignore = <IGNORE>;
  flock (IGNORE, 8);
  close (IGNORE);
  chomp @ignore;

  return 1;
}

sub collectStats {
  $logfile ||= "$rc{'statsdir'}/stats.dat";

  open (STATS, "<$logfile") or error($!);
  flock (STATS, 2);
  my @statsdat = <STATS>;
  flock (STATS, 8);
  close (STATS);
  chomp @statsdat;


  for ( my $i=0; $i <= $#statsdat; $i++) {
    my ($from, $date, $folder, $size, $type, $subject);
    if ($opt_procmail) {

      $statsdat[$i] =~ s/^From //;
      $statsdat[$i] =~ /\s/;
      $from = $`;
      $date = $';
      $i++;			# go to the next line

      $statsdat[$i] =~ s/^Subject: //;
      $subject = $statsdat[$i];
      $i++;			# go to next line
            
      $statsdat[$i] =~ s/^Folder: //;
      $statsdat[$i] =~ /\s/;
      $folder = $`;
      $size = $';
    } else {
      ($from, $date, $type, $folder) = split /~:~/,$statsdat[$i];
      if ($type eq "spam") {
	$hashspamstats{$from}++;
	$spamCount++;
      } elsif ($type eq "normal") {
	$hashstats{$from}++;
	$normalCount++;
      } elsif ($type eq "rbl") {
	$hashspamstats{$from}++;
	$rblCount++;
      } elsif ($type eq "checkuser") {
	$hashspamstats{$from}++;
	$checkuserCount++;
      }
    }

    # Do stats for folder now
    if (defined $folder) {
      $folderCount{$folder}++;
    }
    my $day = int UnixDate($date, "%d");
    my $month = UnixDate($date, "%m");
    my $year = UnixDate($date, "%Y");
    my $thismonth = UnixDate("today", "%m");
    my $thisyear = UnixDate("today", "%Y");

    $monthStats{$day}++ if (($month eq $thismonth) and ($year eq $thisyear));
    my $hour = int UnixDate($date, "%H");
    $hourlyStats{$hour}++;
  }

  foreach my $from (keys %hashspamstats) {
    push @spamstats, "$from~:~$hashspamstats{$from}";
  }
  @spamstats = map { $_->[0] }
    sort { $b->[1] <=> $a->[1] }
      map { [split /~:~/, $_ ] }
	@spamstats;

  foreach my $from (keys %hashstats) {
    push @stats, "$from~:~$hashstats{$from}";
  }
  @stats = map { $_->[0] }
    sort { $b->[1] <=> $a->[1] }
      map { [split /~:~/, $_ ] }
	@stats;
  unless (@stats or @spamstats) {
    print "You have no stats to update.  Please either send yourself\n";
    print "an email, or wait for one to arrive.\n";
    exit (1);
  }
}

sub emailTypeGraph {
  my @data = (
	      ["Normal", "Spam", "RBL", "CheckUser"],
	      [$normalCount, $spamCount, $rblCount, $checkuserCount],
	     );

  my $graph = GD::Graph::pie->new(400,300);


  $graph->set(
	      title => 'Email Types',
	      label => undef,
	      axislabelclr => 'black',
	      pie_height => 36,
	      transparent => 1,
	      shadowclr => 'black',
	      shadow_depth => 5,
	      dclrs => [ qw(green red orange yellow) ]
	     );

  my $gd = $graph->plot(\@data);

  open (IMG, ">$rc{'statsdir'}/emailTypePie.png") or error ($!);
  binmode IMG;
  print IMG $gd->png;
  close (IMG);

  return "<img src=\"emailTypePie.png\" border=0><br>\n";
}

sub MonthlyGraph {
  my $today = &ParseDate("today");
  my $month = UnixDate($today, "%m");
  my $year = UnixDate($today, "%Y");
  my $daysinMonth = &Date_DaysInMonth($month, $year);

  my @dayNames = (1 .. $daysinMonth);
  my @days;
  for (my $i = 1; $i <= $daysinMonth; $i++) {
    push @days, $monthStats{$i};
  }
  my @data = (
	      [@dayNames],
	      [@days]
	     );
  my $graph = GD::Graph::bars->new(750,300);

  $graph->set(
	      title => 'Traffic For this Month Only',
	      label => undef,
	      axislabelclr => 'black',
	      transparent => 1,
	      shadowclr => 'black',
	      shadow_depth => 5,
	      cycle_clrs => 1,
	     );

  my $gd = $graph->plot(\@data);

  open (IMG, ">$rc{'statsdir'}/MonthTraffic.png") or error ($!);
  binmode IMG;
  print IMG $gd->png;
  close (IMG);

  return "<img src=\"MonthTraffic.png\" border=0><br>\n";

}

sub HourlyGraph  {
  my $today = &ParseDate("today");

  my @hourNames = (0 .. 23);
  my @hours;
  for (my $i = 0; $i <= 23; $i++) {
    push @hours, $hourlyStats{$i};
  }
  my @data = (
	      [@hourNames],
	      [@hours]
	     );
  my $graph = GD::Graph::bars->new(750,300);

  $graph->set(
	      title => 'Traffic For Hours in the Day',
	      label => undef,
	      axislabelclr => 'black',
	      transparent => 1,
	      shadowclr => 'black',
	      shadow_depth => 5,
	      cycle_clrs => 1,
	     );

  my $gd = $graph->plot(\@data);

  open (IMG, ">$rc{'statsdir'}/HourlyTraffic.png") or error ($!);
  binmode IMG;
  print IMG $gd->png;
  close (IMG);

  return "<img src=\"HourlyTraffic.png\" border=0><br>\n";

}

sub folderTrafficGraph  {
  my @folderNames = keys %folderCount;
  my @folderCounts;

  if (not defined $folderNames[0]) {
    return "<br>No Folder Data<br>\n";
  }
  foreach my $i (@folderNames) {
    push @folderCounts, $folderCount{$i};
  }
  my @data = (
	      [@folderNames],
	      [@folderCounts]
	     );

  my $graph = GD::Graph::bars->new(750,300);


  $graph->set(
	      title => 'Folder Traffic',
	      label => undef,
	      axislabelclr => 'black',
	      transparent => 1,
	      shadowclr => 'black',
	      shadow_depth => 5,
	      cycle_clrs => 1,
	     );

  my $gd = $graph->plot(\@data);

  open (IMG, ">$rc{'statsdir'}/folderTraffic.png") or error ($!);
  binmode IMG;
  print IMG $gd->png;
  close (IMG);

  return "<img src=\"folderTraffic.png\" border=0><br>\n";
}

sub removeIgnored {
  for (my $i = 0; $i <= $#spamstats; $i++) {
    my ($from, $count) = split /~:~/, $spamstats[$i];
			
    my $ignoreFlag = undef;
    foreach my $test (@ignore) {
      if ($from eq $test) {
	splice @spamstats, $i, 1;
	$i--;
	last;
      }
    }
  }

	
  for (my $i = 0; $i <= $#stats; $i++) {
    my ($from, $count) = split /~:~/, $stats[$i];
			
    my $ignoreFlag = undef;
    foreach my $test (@ignore) {
      if ($from eq $test) {
	splice @stats, $i, 1;
	$i--;
	last;
      }
    }
  }
}

sub writeStats {
  my $today = ParseDate("today");
  $today = UnixDate($today, "%H:%M %D");

  open (STATS, ">$rc{'statsdir'}/stats.shtml") or error($!);
  flock (STATS, 2);

  print STATS "<center>\n";

  print STATS emailTypeGraph();
  print STATS "<hr width=50%>";
  print STATS folderTrafficGraph();
  print STATS "<hr width=50%>";
  print STATS MonthlyGraph();
  print STATS "<hr width=50%>";		
  print STATS HourlyGraph();
  print STATS "<hr width=50%>";		

  unless ($rc{'Stats_HideSpammersEmail'} eq "yes") {
    print STATS "<table border=2 width=100%>\n";
    print STATS "<tr><td bgcolor=#477979 colspan=2 align=center><font color=white>Spammers" .
      "Blocked</font></td></tr>\n";
    print STATS "<tr><td bgcolor=#477979 align=center><font color=white>From</font></td>";
    print STATS "<td bgcolor=#477979 align=center><font color=white>Count</font></td></tr>\n";

    my $max = 1;
    foreach my $line (@spamstats) {
      my ($from, $count) = split /~:~/, $line;
      print STATS "<tr><td>$from</td><td>$hashspamstats{$from}</td></tr>\n";
      last if (($rc{'TopSpammersCount'} ne "0" ) and ($max == $rc{'TopSpammersCount'}));
      $max++;
    }
    print STATS "</table>\n";
  }

  unless ($rc{'Stats_HideAcceptedEmail'} eq "yes") {
    print STATS "<table border=2 width=100%>\n";
    print STATS "<tr><td bgcolor=#477979 colspan=2 align=center><font color=white>Accepted Mail" .
      "</font></td></tr>\n";
    print STATS "<tr><td bgcolor=#477979 align=center><font color=white>From</font></td>";
    print STATS "<td bgcolor=#477979 align=center><font color=white>Count</font></td></tr>\n";

    my $max = 1;
    foreach my $line (@stats) {
      my ($from, $count) = split /~:~/, $line;
      my $maskFrom = $from;
      $maskFrom =~ s/@/ <b>at<\/b> /;
      print STATS "<tr><td>$maskFrom</td><td>$hashstats{$from}</td></tr>\n";
      last if (($rc{'TopAcceptedCount'} ne "0" ) and ($max == $rc{'TopAcceptedCount'}));
      $max++;
    }
    print STATS "</table>\n";
  }
		
  print STATS "</center>\n";
		
  print STATS "<hr>\n";
  print STATS "This page was last updated on $today by " .
    "<a href=\"http://www.hld.ca/opensource/hldfilter\">HLDFilter $VERSION</a>\n";

  flock (STATS, 8);
  close (STATS);
}


###########
#  Start  #
###########

&getConfig;
&collectStats;
&removeIgnored;
&writeStats;
