#!/usr/bin/perl -w

use strict;
use CPAN;


###########################################################################
#
#      Copyright Dan Cardamore <wombat@hld.ca> 2000 - 2001
#      This program is licensed under the GNU GPL.  Since this is free
#      software, the author assumes no liability for it and the damages
#      that it may cause.
#
#      Please read the README file.
#      http://www.hld.ca/opensource/hldfilter
#
###########################################################################
#   $rcs = ' $Id: install.pl,v 2.2 2001/06/01 15:30:59 wombat Exp $ ' ;
###########################################################################

print <<START;
Please make sure you are running this program as root since
if you are not, this install will not succeed.

This will first attempt to download all required modules, and
then it will copy the files hldfilter and statsgen.pl into
/usr/local/bin where all users will be able to access them.

Please make sure that /usr/local/bin is in the system path.
START

sleep 3;

my @modules = (
        "Mail::Audit",
        "Mail::Address",
        "Mail::RBL",
        "Mail::CheckUser",
        "MIME::Lite",
        "Getopt::Long",
        "Date::Manip",
        "GD::Graph",
        "GD::pie",
        "GD::bars"
        );

print "Copying HLDFilter files into /usr/local/bin...\n";
`cp hldfilter /usr/local/bin`;
`chmod 755 /usr/local/bin/hldfilter`;
`cp statsgen.pl /usr/local/bin/`;
`chmod 755 /usr/local/bin/statsgen.pl`;

my $status = 1;
foreach my $module (@modules) {
    print "Installing $module...\n";
    unless (install($module)) { $status = undef; }
}

print "\n\n";
if ($status) {
    print "All modules installed successfully!\n";
}
else {
    print "Some module installs failed.\n";
}
sleep 2;


print <<END;
Installation of modules is complete.  If any errors occured, you
will have to install those yourself either by downloading them and
installing them yourself from www.cpan.org, or by using cpan:
perl -MCPAN -e shell

You will also be required to ensure that the path to perl at the
very top line of both /usr/local/bin/hldfilter and
/usr/local/bin/statsgen.pl is correct.  You can find this path by
typing 'which perl' at the command line.

To get started filtering, type 'hldfilter --init' to set a user up.

If you have problems with hldfilter, please join one of the
mailing lists located at http://www.hld.ca/opensource/hldfilter
END



