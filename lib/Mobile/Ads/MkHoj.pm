# Mobile::Ads::MkHoj.pm version 0.1.0
#
# Copyright (c) 2008 Thanos Chatziathanassioy <tchatzi@arx.net>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Mobile::Ads::MkHoj;
local $^W;
require 'Exporter.pm';
use vars qw(@ISA @EXPORT @EXPORT_OK);
@ISA = (Exporter);
@EXPORT = qw();   #&new);
@EXPORT_OK = qw();

$Mobile::Ads::MkHoj::VERSION='0.1.0';
$Mobile::Ads::MkHoj::ver=$Mobile::Ads::MkHoj::VERSION;

use strict 'vars';
use Carp();
use Mobile::Ads();

=head1 NAME

Mobile::Ads::MkHoj - module to serve mkhoj.com ads

Version 0.1.0

=head1 SYNOPSIS

 use Mobile::Ads::MkHoj;
 $ad = new Mobile::Ads::MkHoj
 ($text,$link,$image) = $ad->get_mkhoj_ad({
				site	=> 'mkhoj site code',
 				remote	=> $ENV{'HTTP_USER_AGENT'},
 				address	=> $ENV{'REMOTE_ADDR'},
 				test	=> [0|1],
 				text	=> 'default ad text',
 				link	=> 'default ad link',
 				});
 
=head1 DESCRIPTION

C<Mobile::Ads::MkHoj> provides an object oriented interface to serve advertisements
from MkHoj.com in mobile sites.
despite sloppy writing
on this module (all the Mobile::Ads family to be exact)

=head1 new Mobile::Ads::MkHoj

=over 4

=item [$parent]

To reuse Mobile::Ads in multiple (subsequent) ad requests, you can pass a C<Mobile::Ads>
reference here. Instead of creating a new Mobile::Ads object, we will use the one you
pass instead. This might save a little C<LWP::UserAgent> creation/destruction time.

=head2 Parameters/Properties

=over 4

=item site

C<>=> mkhoj.com site code, delivered by them (they call it ``siteId''.
Something in the form off ``unique-id-in-hex-string'' 

=item remote

C<>=> Remote User Agent ($ENV{'HTTP_USER_AGENT'}). In fact $ENV{'HTTP_USER_AGENT'} will be used
if not supplied.

=item address

C<>=> $ENV{'REMOTE_ADDR'}. All things about HTTP_USER_AGENT also apply here.

=item test

C<>=> test mode, defaults to 0 (false)

=item text

C<>=> Should we fail to retrieve a real ad, this is the text of the ad displayed instead

=item link

C<>=> Same with text, but for the ad's link. 

=back

=cut

sub new {
	my $this = shift;
	my $class = ref($this) || $this;
	my $self = {};
	bless $self, $class;
	
	my $parent = shift;
	
	if ($parent && ref($parent) && ref($$parent) && ref($$parent) eq "Mobile::Ads") {
		$self->{'parent'} = $$parent;
	}
	elsif ($parent && ref($parent) && ref($parent) eq "Mobile::Ads") {
		$self->{'parent'} = $parent;
	}
	else {
		$self->{'parent'} = new Mobile::Ads;
	}
	
	return $self;
}

*get_ad = \&get_mkhoj_ad;

sub get_mkhoj_ad {
	my $self = shift;
	
	my ($site,$remote,$address,$text,$link,$test) = ('','','','','','',0);
	if (ref $_[0] eq 'HASH') {
		$site = $_[0]->{'site'} || $self->{'site'};
		$remote  = $_[0]->{'remote'};
		$address = $_[0]->{'address'};
		$text = $_[0]->{'text'};
		$link = $_[0]->{'link'};
		$test = $_[0]->{'test'} || 0;
	}
	else {
		($site,$remote,$address,$text,$link,$test) = @_;
	}
	
	$site	 ||= $self->{'site'};
	$remote	 ||= $ENV{'HTTP_USER_AGENT'};
	$address ||= $ENV{'REMOTE_ADDR'};
	$text ||= $self->{'text'};
	$link ||= $self->{'link'};
	
	Carp::croak("cant serve ads without site\n") unless ($site);
	Carp::croak("cant serve ads without remote user agent\n") unless ($remote);
	Carp::croak("cant serve ads without remote address\n") unless ($address);
	
	# fetch data
	my $res;
	my $params = {
					siteId	=> $site,
					handset	=> $remote,
					carrier	=> $address,
					cpm		=> 0,
				};
	
	my $url = "http://ads1.mkhoj.com/c1.aspx";
	if ($test) {
		$url = "http://www.mkhoj.com/testURL.aspx";
	}
	eval q[$res = $self->{'parent'}->get_ad({ 
											url		=> $url,
											method	=> 'GET',
											params	=> $params
										});];
	if ($@) {
		return ($text,$link);
	}
	elsif (!$res) {
		return ($text,$link);
	}
	else {
		my $ret = $self->parse($res,$text,$link);
		if (wantarray) {
			return ($ret->{'text'},$ret->{'link'},$ret->{'image'});
		}
		else {
			return $ret;
		}
	}
}

sub parse {
	my $self = shift;
	
	my ($toparse,$text,$link) = @_;
	my $ret = { };
	
	if ($toparse && $toparse =~ m|\<a.+?href=\"([^\"]+)\".+?\<img.+?src=\"([^\"]+).+?alt=\"([^\"]+)\"|s) {
		#an ad with both text and image (and link of course)
		(
			$ret->{'link'}  = $1,
			$ret->{'text'}  = $3,
			$ret->{'image'} = $2 
		);
	}
	elsif ($toparse && $toparse =~ m|\<a.+?href=\"([^\"]+)\".+?\<img.+?src=\"([^\"]+).+\>.*?([^\<]+)\</a\>|s) {
		#an ad with both text and image (and link of course)
		(
			$ret->{'link'}  = $1,
			$ret->{'text'}  = $3,
			$ret->{'image'} = $2 
		);
	}
	elsif ($toparse && $toparse =~ m|\<a.+?href=\"([^\"]+)\".+?\>(.+?)\</a\>|s) {
		#an ad with only text and link
		(
			$ret->{'link'}  = $1,
			$ret->{'text'}  = $2
		);
	}
	
	defined($ret->{'link'})  and $ret->{'link'}  = $self->{'parent'}->XMLEncode($ret->{'link'});
	defined($ret->{'text'})  and $ret->{'text'}  = $self->{'parent'}->XMLEncode($ret->{'text'});
	defined($ret->{'image'}) and $ret->{'image'} = $self->{'parent'}->XMLEncode($ret->{'image'});
	
	return $ret;
}

=pod

=head2 Methods

=over 4

=item get_mkhoj_ad

C<>=> Does the actual fetching of the ad for the site given. Refer to new for details
Returns a list ($text_for_ad,$link_for_ad,$ad_image) value.

=back

=cut


=head1 Revision History

 0.0.1 
	Initial Release
 0.0.2 
	Fixed stupid typo
 0.0.3 
	Didn't preserve default values on failure
 0.0.4 
	$ua timeout set to 20 sec
 0.0.5
 	All ua stuff put in Mobile::Ads
 0.0.6
 	Aliased get_ad to get_MkHoj_ad
 0.0.7
 	Option to reuse parent Mobile::Ads instead of creating anew
 0.0.8/0.0.9
 	Skipped those to have same verion number in all modules
 0.1.0
 	One could also use a reference to the parent... :)

=head1 BUGS

Thoughtlessly crafted to avoid having the same piece of code in several places.
Could use lots of enhancements.

=head1 DISCLAIMER

This module borrowed its OO interface from Mail::Sender.pm Version : 0.8.00 
which is available on CPAN.

=head1 AUTHOR

Thanos Chatziathanassiou <tchatzi@arx.net>
http://www.arx.net

=head1 COPYRIGHT

Copyright (c) 2008 arx.net - Thanos Chatziathanassiou . All rights reserved.

This program is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. 

=cut

1;
