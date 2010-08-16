# Foswiki WikiClone ($wikiversion has version info)
#
#  Copyright (C) 2010 George Clark, geonwiki@fenachrone.com
#
# This plugin contains code adapted from the SingletonWikiWordPlugin
#   Copyright (C) 2000-2001 Andrea Sterbini, a.sterbini@flashnet.it
#   Copyright (C) 2001 Peter Thoeny, Peter@Thoeny.com
# and the StopWikiWordLinkPlugin
#    Copyright (C) 2006 Peter Thoeny, peter@thoeny.org
# and the FindElsewherePlugin
#    Copyright (C) 2002 Mike Barton, Marco Carnut, Peter Hernst
#	   (C) 2003 Martin Cleaver, (C) 2004 Matt Wilkie (C) 2007 Crawford Currie
#      (C) 2008 Foswiki Contributors
#
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
our $RELEASE = '1.1';

# Short description of this plugin
# # One line description, is shown in the %SYSTEMWEB%.TextFormattingRules topic:
our $SHORTDESCRIPTION =
'Plugin to stop linking of WikiWords or force linking of non-standard WikiWords';

# %SYSTEMWEB%.DevelopingPlugins has details of how to define =$Foswiki::cfg=
# entries so they can be used with =configure=.
our $NO_PREFS_IN_TOPIC = 1;

# Module variables used between functions within this module
my $disabled = 0;
my $web;    # preRendering handler needs current web - passed from initPlugin
my %prefs;
my $debug;

my %acronyms;

BEGIN {

    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::useLocale || $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

sub initPlugin {

    #my( $topic, $web, $user, $installWeb ) = @_;

    # check for Plugins.pm versions
    if ( $Foswiki::Plugins::VERSION < 1 ) {
        Foswiki::Func::writeWarning(
            "Version mismatch between ControlWikiWordPlugin and Plugins.pm");
        return 0;
    }

    # Get plugin debug flag
    $debug = Foswiki::Func::getPreferencesFlag("CONTROLWIKIWORDPLUGIN_DEBUG");

    Foswiki::Func::writeDebug(" CONTROWIKIWORDPLUGIN_DEBUG is enabled ") if $debug;

    if ( Foswiki::Func::getPreferencesFlag('NOAUTOLINK') )
    {    # skip plugin if noautolink set for whole topic
        Foswiki::Func::writeDebug("Disabling plugin - NOAUTOLINK set for whole topic") if $debug;
        $disabled = 1;
        return 1;
    }

    # pre-rendering handler doesn't get passed a web name.  So save it here in a global
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

    if ($prefs{'stopWords'}) {
        Foswiki::Func::writeDebug("stopWords start as ($prefs{'stopWords'})  ") if $debug;
        $prefs{'stopWords'} =~ s/\, */\|/go;         # Change comma's to "or"
        $prefs{'stopWords'} =~ s/^ *//o;             # Drop leading spaces
        $prefs{'stopWords'} =~ s/ *$//o;             # Drop trailing spaces
        #SMELL:  This ought to be done in the config checker - error out non-WikiWords 
        $prefs{'stopWords'} =~ s/[^$Foswiki::regex{mixedAlphaNum}\|]//go;  # Filter any characters not valid in WikiWords
        $prefs{'stopWords'} =~ s/\|/[\\W\\s]|/go;    # Add a Word or Whitespace separator
        $prefs{'stopWords'} .= '[\W\s]';             #  .. and a trailing one too.
    }

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

#=============

sub preRenderingHandler {
    return if ($disabled);

    my $stopWords     = $prefs{'stopWords'};
    my $regexInput    = $prefs{'regexInput'};
    my $controlAbbrev = $prefs{'controlAbbrev'};
    my $dotSINGLETON  = $prefs{'dotSINGLETON'};

    my $stopWordsRE = '';    # Clear - handler only processes topic if provided

    if ($stopWords) {

        # build regularex:
        $stopWordsRE = "(^|[\( \n\r\t\|])($stopWords)"
          ;    # WikiWord preceeded by space or parens
        Foswiki::Func::writeDebug(
            "ControlWikiWordPlugin -  stopWordsRE: $stopWordsRE")
          if $debug;
    }


    my $renderer         = $Foswiki::Plugins::SESSION->renderer();
    my $removedTextareas = {};
    my $removedProtected = {};

    #Foswiki::Func::writeDebug("stopWords ($stopWordsRE) before ($_[0]")  if $debug;
    $_[0] =~ s/$stopWordsRE/$1<nop>$2/g if ($stopWordsRE);
    #Foswiki::Func::writeDebug("stopWords after ($_[0] ") if $debug;

    # If we don't have any regex and don't want the dot format, forget it.
    if ( scalar keys %$regexInput > 0 || $dotSINGLETON || $controlAbbrev ) {

# SMELL: Directly calling Foswiki and Render functions is not recommended.
# This needs to be validated for any major changes in Foswiki.   Tested on 1.0.9 and 1.1.0 trunk
# Determine which release of Foswiki in use - R1.1 moved takeOUtBlocks into Foswiki proper

        # Remove any <noautolink> blocks from the topic
        eval(
'$renderer->takeOutBlocks( $_[0], \'noautolink\', $removedTextareas )'
        );
        if ( $@ ne "" ) {
            $_[0] =
              Foswiki::takeOutBlocks( $_[0], 'noautolink', $removedTextareas );
        }

        # Also remove any forced links from the topic.
        $_[0] =
          $renderer->_takeOutProtected( $_[0], qr/\[\[(?:.*?)\]\]/si,
            'wikilink', $removedProtected );
        $_[0] =
          $renderer->_takeOutProtected( $_[0], qr/<a\s(?:.*?)<\/a>/si,
            'htmllink', $removedProtected );

        foreach my $regex ( keys(%$regexInput) ) {
            my $linkWeb = $regexInput->{$regex} || $web;
            Foswiki::Func::writeDebug(" Regex is $regex Web is $linkWeb  ")
              if $debug;
            $_[0] =~ s/(\s)($regex)\b/$1."[[$linkWeb.$2][$2]]"/ge;
        }

        $_[0] =~ s/(\s+)\.([A-Z]+[a-z]*)/"$1"."[[$web.$2][$2]]"/geo
          if ($dotSINGLETON);

        if ($controlAbbrev) {
            undef %acronyms;
            Foswiki::Func::writeDebug("Clearing acronyms") if $debug;
            $_[0] =~ s/(
                 (?:^|(?<=[\s\(,]))           # Prefix
                 (?:$Foswiki::regex{'webNameRegex'}\.)?         # Webname. optional
                 (?:$Foswiki::regex{'abbrevRegex'})             # Abbreviation
               )
               /&_findAbbrev($web,$1)
               /geox;
        }

        # put back everything that was removed
        if ($@) {
            Foswiki::putBackBlocks( \$_[0], $removedTextareas, 'noautolink',
                'noautolink' );
        }
        else {
            $renderer->putBackBlocks( \$_[0], $removedTextareas, 'noautolink',
                'noautolink' );
        }
        $renderer->_putBackProtected( \$_[0], 'wikilink', $removedProtected );
        $renderer->_putBackProtected( \$_[0], 'htmllink', $removedProtected );
    }
}

sub _findAbbrev {

    Foswiki::Func::writeDebug("Found abbrev $_[1] ") if $debug;
    if (   ( exists $acronyms{$_[1]} )
        && ( Foswiki::Func::topicExists( $_[0], $_[1] ) ) )
    {
        Foswiki::Func::writeDebug(" -- Duplicate - returning <nop>$_[1] ") if $debug;
        return "<nop>" . $_[1];
    }
    else {
        $acronyms{$_[1]} = 1;
        Foswiki::Func::writeDebug(" -- First find, or topic doesn't exist` - returning $_[1] ") if $debug;
        return $_[1];
    }
}

1;

