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

package Foswiki::Plugins::ControlWikiWordPlugin::Core;

use strict;

BEGIN {

    # Do a dynamic 'use locale' for this module
    if ( $Foswiki::useLocale || $Foswiki::cfg{UseLocale} ) {
        require locale;
        import locale();
    }
}

my $initialised = 0;

# Regular expressions used in module
my $webNameRegex;
my $abbrevRegex;

#my $wikiWordRegex;
#my $upperAlphaRegex;
#my $lowerAlphaRegex;
#my $numericRegex;
#my $singleMixedAlphaNumRegex;

# Module variables used between functions within this module
my $debug;
my $web;

my %acronyms;

#=============

sub _lazyInit {
    return 1 if $initialised;
    $initialised = 1;

    $webNameRegex = Foswiki::Func::getRegularExpression('webNameRegex');
    $abbrevRegex  = Foswiki::Func::getRegularExpression('abbrevRegex');

    #$wikiWordRegex = Foswiki::Func::getRegularExpression('wikiWordRegex');
    #$upperAlphaRegex = Foswiki::Func::getRegularExpression('upperAlpha');
    #$lowerAlphaRegex = Foswiki::Func::getRegularExpression('lowerAlpha');
    #$numericRegex    = Foswiki::Func::getRegularExpression('numeric');
    #$singleMixedAlphaNumRegex =
    #  qr/[$upperAlphaRegex$lowerAlphaRegex$numericRegex]/;

    #$regexInput = $Foswiki::cfg{Plugins}{ControlWikiWordPlugin}{SingletonWords}
    #  || {};

    # Plugin correctly initialized
    return 1;
}

sub _preRender {
    return unless _lazyInit();

    $web = $_[1];

    my $stopWords     = $_[2]->{'stopWords'};
    my $regexInput    = $_[2]->{'regexInput'};
    my $controlAbbrev = $_[2]->{'controlAbbrev'};
    my $dotSINGLETON  = $_[2]->{'dotSINGLETON'};

    my $stopWordsRE = '';    # Clear - handler only processes topic if provided

    if ($stopWords) {

        # build regularex:
        $stopWords =~ s/\, */\|/go;         # Change comma's to "or"
        $stopWords =~ s/^ *//o;             # Drop leading spaces
        $stopWords =~ s/ *$//o;             # Drop trailing spaces
        $stopWords =~ s/[^A-Za-z0-9\|]//go; # Filter any special characters
        $stopWords =~ s/\|/[\\W\\s]|/go;    # Add a Word or Whitespace separator
        $stopWords .= '[\W\s]';             #  .. and a trailing one too.
        $stopWordsRE = "(^|[\( \n\r\t\|])($stopWords)"
          ;    # WikiWord preceeded by space or parens
        Foswiki::Func::writeDebug(
            "ControlWikiWordPlugin -  stopWordsRE: $stopWordsRE")
          if $debug;
    }

    # Get plugin debug flag
    $debug = &Foswiki::Func::getPreferencesFlag("CONTROLWIKIWORDPLUGIN_DEBUG");

    my $renderer         = $Foswiki::Plugins::SESSION->renderer();
    my $removedTextareas = {};
    my $removedProtected = {};

    $_[0] =~ s/$stopWordsRE/$1<nop>$2/g if ($stopWordsRE);

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
            my $linkWeb = $regexInput->{$regex} || $_[1];
            Foswiki::Func::writeDebug(" Regex is $regex Web is $linkWeb  ")
              if $debug;
            $_[0] =~ s/(\s)($regex)\b/$1."[[$linkWeb.$2][$2]]"/ge;
        }

        $_[0] =~ s/(\s+)\.([A-Z]+[a-z]*)/"$1"."[[$_[1].$2][$2]]"/geo
          if ($dotSINGLETON);

        if ($controlAbbrev) {
            undef %acronyms;
            $_[0] =~ s/(
                 (?:^|(?<=[\s\(,]))           # Prefix 
                 (?:$webNameRegex\.)?         # Webname. optional
                 (?:$abbrevRegex)             # Abbreviation
               )
               /&_findAbbrev($_[1],$1)
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

    Foswiki::Func::writeDebug("Found abbrev $_[1] ");
    Foswiki::Func::writeDebug(" - Searching $web if exists ");
    if (   ( exists $acronyms{ $_[1] } )
        && ( Foswiki::Func::topicExists( $web, $_[1] ) ) )
    {
        return "<nop>" . $_[1];
    }
    else {
        $acronyms{ $_[1] } = 1;
        return $_[1];
    }
}

1;

