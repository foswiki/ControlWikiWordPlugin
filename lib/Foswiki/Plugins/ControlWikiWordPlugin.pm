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

# =========================
package Foswiki::Plugins::ControlWikiWordPlugin;    # change the package name!!!

use strict;

use vars qw( $VERSION $RELEASE $debug $pluginName $stopWordsRE );

# =========================
use vars qw(
  $web $topic $user $installWeb $VERSION $RELEASE $debug
  $stopWordsRE $dotSINGLETON
);

# This should always be $Rev: 1340 $ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
$VERSION = '$Rev: 1340 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
$RELEASE = '0.9';

# You must set $NO_PREFS_IN_TOPIC to 0 if you want your plugin to use
# preferences set in the plugin topic. This is required for compatibility
# with older plugins, but imposes a significant performance penalty, and
# is not recommended. Instead, leave $NO_PREFS_IN_TOPIC at 1 and use
# =$Foswiki::cfg= entries, or if you want the users
# to be able to change settings, then use standard Foswiki preferences that
# can be defined in your %USERSWEB%.SitePreferences and overridden at the web
# and topic level.
#
# %SYSTEMWEB%.DevelopingPlugins has details of how to define =$Foswiki::cfg=
# entries so they can be used with =configure=.
our $NO_PREFS_IN_TOPIC = 1;

# =========================
sub initPlugin {
    ( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 2 ) {
        &Foswiki::Func::writeWarning(
            "Version mismatch between ControlWikiWordPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = &Foswiki::Func::getPreferencesFlag("CONTROLWIKIWORDPLUGIN_DEBUG");

    my $stopWords = Foswiki::Func::getPreferencesValue("STOPWIKIWORDLINK")
      || Foswiki::Func::getPreferencesValue(
        "CONTROLWIKIWORDPLUGIN_STOPWIKIWORDLINK")
      || Foswiki::Func::getPreferencesValue(
        "STOPWIKIWORDLINKPLUGIN_STOPWIKIWORDLINK")
      || '';

    $stopWordsRE = '';    # Clear - handler only processes topic if provided

    if ($stopWords) {

        # build regularex:
        $stopWords =~ s/\, */\|/go;
        $stopWords =~ s/^ *//o;
        $stopWords =~ s/ *$//o;
        $stopWords =~ s/[^A-Za-z0-9\|]//go;
        $stopWordsRE = "(^|[\( \n\r\t\|])($stopWords)"
          ;               # WikiWord preceeded by space or parens
        Foswiki::Func::writeDebug("- $pluginName stopWordsRE: $stopWordsRE")
          if $debug;
    }

    $dotSINGLETON = Foswiki::Func::getPreferencesValue(
        "CONTROLWIKIWORDPLUGIN_DOTSINGLETONENABLE");

    # Plugin correctly initialized
    Foswiki::Func::writeDebug(
"- Foswiki::Plugins::ControlWikiWordPlugin::initPlugin( $web.$topic ) is OK"
    );
    return 1;
}

sub writeDebug {
    &Foswiki::Func::writeDebug(@_) if $debug;
}

#===========================================================================
sub preRenderingHandler {

    # do not uncomment, use $_[0], $_[1]... instead
    #my( $text, $pMap ) = @_;

    my $renderer         = $Foswiki::Plugins::SESSION->{renderer};
    my $removedTextareas = {};
    my $removedProtected = {};

    $_[0] =~ s/$stopWordsRE/$1<nop>$2/g if ($stopWordsRE);

    my $regexInput =
      $Foswiki::cfg{Plugins}{ControlWikiWordPlugin}{SingletonWords} || {};

    # If we don't have any regex and don't want the dot format, forget it.
    if ( scalar keys %$regexInput > 0 || $dotSINGLETON ) {

        # Don't bother at all if NOAUTOLINK is requested for the topic.
        unless ( Foswiki::Func::getPreferencesFlag('NOAUTOLINK') ) {

# Determine which release of Foswiki in use - R1.1 moved takeOUtBlocks into Foswiki proper
# SMELL: Directly calling Foswiki and Render functions is not recommended.
# This needs to be validated for any major changes in Foswiki.   Tested on 1.0.9 and 1.1.0 trunk
#
            eval('$renderer->takeOutBlocks');

            #Foswiki::Func::writeDebug( "Eval returned $@" );
            my $tOB = $@
              ; # If $tOB contains an error, then it failed, so use the Foswiki 1.1+ version

            # Remove any <noautolink> blocks from the topic
            if ($tOB) {
                $_[0] =
                  Foswiki::takeOutBlocks( $_[0], 'noautolink',
                    $removedTextareas );
            }
            else {
                $_[0] =
                  $renderer->takeOutBlocks( $_[0], 'noautolink',
                    $removedTextareas );
            }

            # Also remove any forced links from the topic.
            $_[0] =
              $renderer->_takeOutProtected( $_[0], qr/\[\[(?:.*?)\]\]/si,
                'wikilink', $removedProtected );
            $_[0] = $renderer->_takeOutProtected(
                $_[0],      qr/<a\s(?:.*?)<\/a>/si,
                'htmllink', $removedProtected
            );

            foreach my $regex ( keys(%$regexInput) ) {
                my $linkWeb = $regexInput->{$regex} || $web;
                Foswiki::Func::writeDebug(" Regex is $regex Web is $linkWeb  ");
                $_[0] =~ s/(\s)($regex)\b/$1."[[$linkWeb.$2][$2]]"/ge;
            }
            $_[0] =~ s/(\s+)\.([A-Z]+[a-z]*)/"$1"."[[$web.$2][$2]]"/geo
              if ($dotSINGLETON);

            # put back everything that was removed
            if ($tOB) {
                Foswiki::putBackBlocks( \$_[0], $removedTextareas, 'noautolink',
                    'noautolink' );
            }
            else {
                $renderer->putBackBlocks( \$_[0], $removedTextareas,
                    'noautolink', 'noautolink' );
            }
            $renderer->_putBackProtected( \$_[0], 'wikilink',
                $removedProtected );
            $renderer->_putBackProtected( \$_[0], 'htmllink',
                $removedProtected );
        }
    }

}

1;

