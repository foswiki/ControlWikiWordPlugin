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

package Foswiki::Plugins::ControlWikiWordPlugin;

use strict;
use warnings;

# This should always be $Rev: 1340 $ so that Foswiki can determine the checked-in
# status of the plugin. It is used by the build automation tools, so
# you should leave it alone.
our $VERSION = '$Rev: 1340 $';

# This is a free-form string you can use to "name" your own plugin version.
# It is *not* used by the build automation tools, but is reported as part
# of the version number in PLUGINDESCRIPTIONS.
our $RELEASE = '1.0-RC1';

# Short description of this plugin
# # One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
'Plugin to stop linking of WikiWords or force linking of non-standard Wikiwords';

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

my $disabled = 0;
my $web;    # preRendering handler needs current web - passed from initPlugin
my %prefs;

sub initPlugin {

    #my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between ControlWikiWordPlugin and Plugins.pm");
        return 0;
    }

    if ( Foswiki::Func::getPreferencesFlag('NOAUTOLINK') )
    {    # skip plugin if noautolink set for whole topic
        $disabled = 1;
        return 1;
    }

    $web = $_[1];

    $prefs{'regexInput'} =
      $Foswiki::cfg{Plugins}{ControlWikiWordPlugin}{SingletonWords}
      || {};

    $prefs{'stopWords'} = Foswiki::Func::getPreferencesValue("STOPWIKIWORDLINK")
      || Foswiki::Func::getPreferencesValue(
        "CONTROLWIKIWORDPLUGIN_STOPWIKIWORDLINK")
      || Foswiki::Func::getPreferencesValue(
        "STOPWIKIWORDLINKPLUGIN_STOPWIKIWORDLINK")
      || '';

    $prefs{'controlAbbrev'} =
      Foswiki::Func::getPreferencesValue("LIMITACRONYMS")
      || Foswiki::Func::getPreferencesValue(
        "CONTROLWIKIWORDPLUGIN_LIMITACRONYMS")
      || '';

    $prefs{'dotSINGLETON'} = Foswiki::Func::getPreferencesValue(
        "CONTROLWIKIWORDPLUGIN_DOTSINGLETONENABLE")
      || '';

    $disabled = 1
      unless ( $prefs{'regexInput'}
        || $prefs{'stopWords'}
        || $prefs{'controlAbbrev'}
        || $prefs{'dotSINGLETON'} );

    return 1;
}

sub preRenderingHandler {
    ### my ( $text, $map ) = @_;
    #
    return if ($disabled);

    require Foswiki::Plugins::ControlWikiWordPlugin::Core;
    return Foswiki::Plugins::ControlWikiWordPlugin::Core::_preRender( $_[0],
        $web, \%prefs );
}

1;
