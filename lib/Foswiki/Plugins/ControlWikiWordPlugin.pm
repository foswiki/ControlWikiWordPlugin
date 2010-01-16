#
# Foswiki WikiClone ($wikiversion has version info)
#
#  Copyright (C) 2010 George Clark, geonwiki@fenachrone.com
#
# This plugin contains code adapted from the SingletonWikiWordPlugin
#   Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
#   Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# and the StopWikiWordLinkPlugin
#    Copyright (C) 2006 Peter Thoeny, peter@thoeny.org
#    All Rights Reserved.
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details, published at 
# http://www.gnu.org/copyleft/gpl.html
#
# ControlWikiWordPlugin implements features as described on
# http://twiki.org/cgi-bin/view/Codev/?topic=SingletonWikiWord

# =========================
package Foswiki::Plugins::ControlWikiWordPlugin;    # change the package name!!!

use strict;

use vars qw( $VERSION $RELEASE $debug $pluginName $stopWordsRE );

# =========================
use vars qw(
        $web $topic $user $installWeb $VERSION $RELEASE $debug
        $stopWordsRE
    );

# This should always be $Rev: 1340 $ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 1340 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '0.9';


# =========================
sub initPlugin
{
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if( $Foswiki::Plugins::VERSION < 2 ) {
        &Foswiki::Func::writeWarning( "Version mismatch between ControlWikiWordPlugin and Plugins.pm" );
        return 0;
    }

    # Get plugin debug flag
    $debug = &Foswiki::Func::getPreferencesFlag( "CONTROLWIKIWORDPLUGIN_DEBUG" );

    my $stopWords = Foswiki::Func::getPreferencesValue( "STOPWIKIWORDLINK" )
                 || Foswiki::Func::getPreferencesValue( "\U$pluginName\E_STOPWIKIWORDLINK" )
                 || Foswiki::Func::getPreferencesValue( "STOPWIKIWORDPLUGIN_STOPWIKIWORDLINK" )
                 || 'UndefinedStopWikiWordLink';

    # build regex:
    $stopWords =~ s/\, */\|/go;
    $stopWords =~ s/^ *//o;
    $stopWords =~ s/ *$//o;
    $stopWords =~ s/[^A-Za-z0-9\|]//go;
    $stopWordsRE = "(^|[\( \n\r\t\|])($stopWords)"; # WikiWord preceeded by space or parens
    Foswiki::Func::writeDebug( "- $pluginName stopWordsRE: $stopWordsRE" ) if $debug;

    # Plugin correctly initialized
    writeDebug( "- Foswiki::Plugins::ControlWikiWordPlugin::initPlugin( $web.$topic ) is OK" );
    return 1;
}

# =========================
sub commonTagsHandler
{
### my ( $text, $topic, $web ) = @_;   # do not uncomment, use $_[0], $_[1]... instead

    writeDebug( "- X - ControlWikiWordPlugin::commonTagsHandler( $_[0]$_[2].$_[1] )" );

    # This is the place to define customized tags and variables
    # Called by sub handleCommonTags, after %INCLUDE:"..."%
    $_[0] =~ s/(\s+)\.([A-Z]+[a-z]*)/"$1".&Foswiki::Func::internalLink("[[$2]]",$web,$web,"",1)/geo;

}

sub writeDebug 
{
   &Foswiki::Func::writeDebug (@_) if $debug;
}

#===========================================================================
sub preRenderingHandler {
    # do not uncomment, use $_[0], $_[1]... instead
    #my( $text, $pMap ) = @_;

    $_[0] =~ s/$stopWordsRE/$1<nop>$2/g;
}

1;

