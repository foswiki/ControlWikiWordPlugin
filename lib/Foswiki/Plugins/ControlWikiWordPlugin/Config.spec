# ---+ Extensions
# ---++ Control WikiWord Plugin 
# Settings for the Control WikiWord Plugin.  This plugin adds additional site control over linking of wikiwords.
# **PERL**
# Matching parameters for Singleton links.  This is a hash of Regular Expression / Web pairs.  
# The example configuration matches the Tasks and Support web topics that would be found on foswiki.org
$Foswiki::cfg{Plugins}{ControlWikiWordPlugin}{SingletonWords} = {
  '(?:Item[[:digit:]]{3,6})' => 'Tasks',
  '(?:Question[[:digit:]]{3,5}|FAQ[[:digit:]]{1,3})' => 'Support',
  '(?:Plugins)' => ''
}; 
