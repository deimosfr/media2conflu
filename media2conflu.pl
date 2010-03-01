#!/usr/bin/perl
#===============================================================================
#
#         FILE:  media2conflu.pl
#
#        USAGE:  ./media2conflu.pl
#
#  DESCRIPTION:  Convert MediaWiki code to confluence code
#
#      OPTIONS:  ---
# REQUIREMENTS:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Pierre Mavro (), pierre@mavro.fr
#      COMPANY:  
#      VERSION:  0.2
#      CREATED:  29/01/2010 18:33:59
#     REVISION:  ---
#===============================================================================

use strict;
use warnings;
use LWP::Simple;

# Get all the html page
sub get_html_source
{
	my $url = "http://www.deimos.fr/blocnotesinfo/index.php?title=Replication_Master_to_Master";
	
	# Check if the link is source page or change to it
	unless ($url =~ /&action=edit$/)
	{
		$url .= '&action=edit';
	}

	# Now get HTML source code
	my $good_url = get($url);
	return $good_url;
}

# Get all wiki code from the html page
sub only_wiki_text
{
	my $url = shift;
	my $is_wiki=0;
	my @wiki_content;
	
	# Put content in array to parse it
	my @html_content = split($/,$url);
	
	# Parse html source to only get wiki code
	foreach (@html_content)
	{
		chomp $_;
		if ($is_wiki == 0)
		{
			if ($_ =~ /<textarea/)
			{
				# Pull off extra html code
				s/.*<textarea.*>(.*)/$1/;
				push @wiki_content, $_;
				$is_wiki = 1;
			}
		}
		else
		{
			if ($_ =~ /<\/textarea/)
			{
				# Pull off extra html code
				s/(.*)<\/textarea>.*/$1/;
				push @wiki_content, $_;
				last;
			}
			push @wiki_content, $_;
		}
	}
	
	return \@wiki_content; 
}

# Convert 
sub convert_to_confluence
{
	my $ref_wiki_content = shift;
	my @wiki_content = @$ref_wiki_content;
	my @confluence_code;
	
	my $code=0;
	my $config=0;
	my $command=0;
	my $pre=0;
	my $array=0;
	my $array_title=0;

	# Convert default MediaWiki code to Confluence Code
	foreach (@wiki_content)
	{
		# Command content
		if ($command == 1)
		{
			if (/(^|^<\/pre>|^&lt;\/pre&gt;)\}\}/g)
			{
				push @confluence_code, "\{tip\}\n";
				$command=0;
			}
			else
			{
				s/-/\\-/g;
				push @confluence_code, "$_\n";
			}
		}
		# Config content
		elsif ($config == 1)
		{
			if (/^\}\}.*/g)
			{
				push @confluence_code, "\{info\}\n";
				$config=0;
			}
			else
			{
				s/-/\\-/g;
				push @confluence_code, "$_\n";
			}
		}
		# Pre content
		elsif ($pre == 1)
		{
			if (/<\/pre>|\&lt;\/pre\&gt;/)
			{
				s/(<\/pre>|\&lt;\/pre\&gt;)/\{code\}/;
				push @confluence_code, "$_\n";
				$pre=0;
			}
			else
			{
				push @confluence_code, "$_\n";
			}
		}
		# Array content
		elsif ($array == 1)
		{
			if (/^\!(.*)/)
			{
				push @confluence_code, " $1 \|\| ";
				$array_title=1;
			}
			elsif (/^\{\{/)
			{
				if ($array_title == 1)
				{
					push @confluence_code, "\n";
					$array_title=0;
				}
				
				# Add spaces to |
				s/\|/ \| /g;
				# Remove first argument of the array and replace {{
				s/\{\{(\S* \|)/\|/;
				# Replace }}
				s/\}\}/ \|/g;
				
				push @confluence_code, "$_\n";
			}
			elsif (/^\|(.*)$/)
			{
				push @confluence_code, " $1 \| ";
			}
			elsif (/^\|-/)
			{
				push @confluence_code, "\n\| ";
			}
			elsif (/\|\}/)
			{
				push @confluence_code, "\n\{table-plus\}\n";
				$array_title=0;
				$array=0;
			}
		}
		# Start content and anything in 1 line
		else
		{
			# h3
			if (/^===\s*(.*)\s*===\s*$/)
			{
				push @confluence_code, "h3. $1\n\n";
			}
			# h2
			elsif (/^==\s*(.*)\s*==\s*$/)
			{
				push @confluence_code, "h2. $1\n\n";
			}
			# h1
			elsif (/^=\s*(.*)\s*=\s*$/)
			{
				push @confluence_code, "h1. $1\n\n";
			}
			# TOC index
			elsif (/^__TOC__/)
			{
				push @confluence_code, "\{TOC\}\n";
			}
			# Command style
			elsif (/^\{\{command\|(.*)\|/)
			{
				if ($1)
				{
					push @confluence_code, "\{tip:title=$1\}\n";
				}
				else
				{
					push @confluence_code, "\{tip\}\n";
				}
				$command=1;
			}
			# Config style
			elsif (/^\{\{config\|(.*)\|/)
			{
				if ($1)
				{
					push @confluence_code, "\{info:title=$1\}\n";
				}
				else
				{
					push @confluence_code, "\{info\}\n";
				}
				$config=1;
			}
			# <pre>
			elsif (/<pre>|\&lt;pre\&gt;/)
			{
				s/(<pre>|\&lt;pre\&gt;)/\{code\}/;
				push @confluence_code, "$_\n";
				$pre=1;
			}
			# Arrays
			elsif (/\{\|/)
			{
				push @confluence_code, "\{table-plus\}\n\|\| ";
				$array=1;
			}
			else
			{
				push @confluence_code, "$_\n";
			}
		}
	}

	sub pulloff_less
	{
		my $line = shift;
		$line = s/!(^-)/\\-/;
		return $line;
	}

	# Mettre - en \-
	foreach (@confluence_code)
	{
		# Replace bold signs
		{
			my $total_bold=0;
			# Count number of bolds
			$total_bold++ while ($_ =~ s/(?:'''|<b>|<\/b>)/*/);
			
			if (($total_bold != 0) and ($total_bold % 2 ))
			{
				s/$/*/;
			}
		}
		# Replace italic signs
		{
			my $total_italic=0;
			# Count number of italic
			$total_italic++ while ($_ =~ s/(?:''|<i>|<\/i>)/\_/);
			
			if (($total_italic != 0) and ($total_italic % 2 ))
			{
				s/$/\_/;
			}
		}
		# Adapt code
		s/^ //;
		# Pull off <nowiki> <pre>
		s/(?:<nowiki>|<\/nowiki>|<pre>|<\/pre>|&lt;pre&gt;|&lt;\/pre&gt;|&lt;nowiki&gt;|&lt;\/nowiki&gt;)//g;
		# Adapt for #
		s/^#/\\#/;
		# Adapt for []
		s/(\[|\])/\\$1/g; 
		# Adapt for <>
		s/(?:&gt;)/>/g;
		s/(?:&lt;)/</g;
		# Change some confluence signs
		s/\(?:x\)/\\(x\\)/g;
	}
	print @confluence_code;
}

# Get HTML source code
my $url = get_html_source;
# Parse it to get only wiki code
my $ref_wiki_text = only_wiki_text($url);
# Convert to confluence
convert_to_confluence($ref_wiki_text);