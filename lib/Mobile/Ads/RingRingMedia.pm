# Mobile::Ads::RingRingMedia.pm version 0.1.0
#
# Copyright (c) 2008 Thanos Chatziathanassioy <tchatzi@arx.net>. All rights reserved.
# This program is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

package Mobile::Ads::RingRingMedia;
local $^W;
require 'Exporter.pm';
use vars qw(@ISA @EXPORT @EXPORT_OK);
@ISA = (Exporter);
@EXPORT = qw();   #&new);
@EXPORT_OK = qw();

$Mobile::Ads::RingRingMedia::VERSION='0.1.0';
$Mobile::Ads::RingRingMedia::ver=$Mobile::Ads::RingRingMedia::VERSION;

use strict 'vars';
use Carp();
use Mobile::Ads();
use Digest::MD5 qw();

=head1 NAME

Mobile::Ads::RingRingMedia - module to serve RingRingMedia ads

Version 0.1.0

=head1 SYNOPSIS

 use Mobile::Ads::RingRingMedia;
 $ad = new Mobile::Ads::RingRingMedia
 ($text,$link,$image) = $ad->get_ringringmedia_ad({
				site	=> 'RingRingMedia site code',
 				remote	=> $ENV{'HTTP_USER_AGENT'},
 				address	=> $ENV{'REMOTE_ADDR'},
 				text	=> 'default ad text',
 				link	=> 'default ad link',
 				test	=> 'set this if this is a test ad',
 				});
 
=head1 DESCRIPTION

C<Mobile::Ads::RingRingMedia> provides an object oriented interface to serve advertisements
from RingRingMedia in mobile sites.
This is just a slightly altered version of the php code found on RingRingMedia's site.

=head1 new Mobile::Ads::RingRingMedia

=head2 Parameters/Properties

=over 4

=item site

C<>=> RingRingMedia site code, delivered by them. Something in the form off ``a1471c9db1c2d27''

=item remote

C<>=> Remote User Agent ($ENV{'HTTP_USER_AGENT'}). In fact $ENV{'HTTP_USER_AGENT'} will be used
if not supplied.

=item address

C<>=> $ENV{'REMOTE_ADDR'}. All things about HTTP_USER_AGENT also apply here.

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

*get_ad = \&get_ringringmedia_ad;

sub get_ringringmedia_ad {
	my $self = shift;
	
	my $rrmedia_version = "2.7.90";
	my $rrmedia_endpoint = 'http://iam.ringringmedia.com/index.php';
	#my $rrmedia_endpoint = 'http://preiam.ringringmedia.com/index.php';
	my $encoding = 'UTF-8';
	
	my ($site,$test,$remote,$address,$uri,$markup,$text,$link,$postal_code,$area_code,$coordinates,$dob,$gender,$keywords,$search) = 
			('','','','','','','','','','','','','','','','');
	
	if (ref $_[0] eq 'HASH') {
		$site	 = $_[0]->{'site'} || $self->{'site'};
		$test	 = $_[0]->{'test'} || '';
		$remote	 = $_[0]->{'remote'} || $ENV{'HTTP_USER_AGENT'};
		$address = $_[0]->{'address'} || $ENV{'REMOTE_ADDR'};
		$uri	 = $_[0]->{'uri'} || 'http://'.$ENV{'HTTP_HOST'}.$ENV{'REQUEST_URI'};
		$markup	 = $_[0]->{'markup'} || 'xml';
		$text	 = $_[0]->{'text'} || $self->{'text'} || '';
		$link	 = $_[0]->{'link'} || $self->{'link'} || '';
		$postal_code = $_[0]->{'postal_code'} || '';
		$area_code 	 = $_[0]->{'area_code'} || '';
		$coordinates = $_[0]->{'coordinates'} || '';
		$keywords	 = $_[0]->{'keywords'} || '';
		$search	 = $_[0]->{'search'} || '';
		$dob	 = $_[0]->{'dob'} || '';
		$gender	 = $_[0]->{'gender'} || '';
	}
	else {
		($site,$test,$remote,$address,$uri,$markup,$text,$link,$postal_code,$area_code,$coordinates,$dob,$gender,$keywords,$search) = @_;
	}
	
	$site	 ||= $self->{'site'};
	$remote	 ||= $ENV{'HTTP_USER_AGENT'};
	$address ||= $ENV{'REMOTE_ADDR'};
	$text ||= $self->{'text'};
	$link ||= $self->{'link'};
	$markup	||= 'xml';
	
	Carp::croak("cant serve ads without site\n") unless ($site);
	Carp::croak("cant serve ads without remote user agent\n") unless ($remote);
	Carp::croak("cant serve ads without remote address\n") unless ($address);
	
	my $rrmedia_post = {
						'pid'	=> $site,
						'ua'	=> $remote,
						'rt'	=> 'ar',
						'ira'	=> $address,
						'au'	=> $uri,
						's'		=> '', #still haven't figured out what this is
						'e'		=> $encoding, 
						'mu'	=> $markup,
						'pv'	=> $rrmedia_version,
						'pc'	=> $postal_code,
						'rac'	=> $area_code,
						'rco'	=> $coordinates,
						'rdb'	=> $dob,
						'rg'	=> $gender,
						't'		=> $keywords,
						'mo'	=> 'live',
						'uniq'	=> '',
					};
	
	#stuff the rest of the $ENV in $rrmedia_post
	foreach (keys(%ENV)) {
		if ( length($_) > 5 && $_ =~ m|^HTTP_| ) {
			$rrmedia_post->{"AR_".$_} = $ENV{$_};
		}
	}
	
	#alter req to ``mo=test'' if testing..
	if ($test eq 'test') {
		$rrmedia_post->{'mo'} = 'test';
	}
	
	#do the POST
	my $res;
	#through $self->{parent} prefrably...
	eval q[$res = $self->{'parent'}->get_ad({
												url		=> $rrmedia_endpoint,
												method	=> 'POST',
												params	=> $rrmedia_post
											});];
	if ($@) {
		#warn "oops: $@ \n";
		return ($text,$link);
	}
	else {
		#warn "response: $res \n";
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
	
	$toparse =~ m|\<clickUrl\>(.+?)\</clickUrl\>|s and $ret->{'link'} = $1;
	$toparse =~ m|\<text\>(.+?)\</text\>|s and $ret->{'text'} = $1;
	$toparse =~ m|\<imageUrl\>(.+?)\</imageUrl\>|s and $ret->{'text'} = $1;
	
	#we need at least link and text to exist...
	if ($ret->{'link'} && $ret->{'text'}) {
		$ret->{'image'} ||= '';
	}
	else {
		$ret->{'link'} = $link;
		$ret->{'text'} = $text;
		$ret->{'image'} = '';
	}
	
	defined($ret->{'link'})  and $ret->{'link'}  = $self->{'parent'}->XMLEncode($ret->{'link'});
	defined($ret->{'text'})  and $ret->{'text'}  = $self->{'parent'}->XMLEncode($ret->{'text'});
	defined($ret->{'image'}) and $ret->{'image'} = $self->{'parent'}->XMLEncode($ret->{'image'});
	
	return $ret;
}

=pod

=head2 Methods

=over 4

=item get_ringringmedia_ad

C<>=> Does the actual fetching of the ad for the site given. Refer to new for details
Returns a list ($text_for_ad,$link_for_ad) value in list context or an 
``<a href="$link">$text</a>'' if called in scalar context.

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
	$ua timeout set to 2 sec
	Implemented the new version AdMob code 
	(still some funky parts in there, but seems to work)
 0.0.6
 	Aliased get_ad to get_v2_ad
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
