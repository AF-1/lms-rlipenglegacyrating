#
# RL iPeng Legacy Rating
#
# (c) 2026 AF
#
# GPLv3 license
#

package Plugins::RLiPengLegacyRating::Plugin;

use strict;
use warnings;
use utf8;
use base qw(Slim::Plugin::Base);

use Slim::Utils::Log;
use Slim::Utils::PluginManager;
use Slim::Control::Request;
use Slim::Music::Import;

my $log = Slim::Utils::Log->addLogCategory({
	'category' => 'plugin.rlipenglegacyrating',
	'defaultLevel' => 'ERROR',
	'description' => 'RL iPeng Legacy Rating',
});

sub initPlugin {
	my $class = shift;
	$class->SUPER::initPlugin(@_);
}

sub postinitPlugin {
	if (Slim::Utils::PluginManager->isEnabled('Plugins::RatingsLight::Plugin') &&
		!Slim::Utils::PluginManager->isEnabled('Plugins::TrackStat::Plugin')) {
		Slim::Control::Request::addDispatch(['trackstat', 'getrating', '_trackid'], [0, 1, 0, \&getRating]);
		Slim::Control::Request::addDispatch(['trackstat', 'setrating', '_trackid', '_rating', '_incremental'], [1, 0, 1, \&setRating]);
		Slim::Control::Request::addDispatch(['trackstat', 'setratingpercent','_trackid', '_rating', '_incremental'], [1, 0, 1, \&setRating]);
		Slim::Control::Request::addDispatch(['trackstat', 'changedrating', '_url', '_trackid', '_rating', '_ratingpercent'], [0, 0, 0, undef]);
	}
}

sub setRating {
	my $request = shift;

	if (Slim::Music::Import->stillScanning) {
		$log->warn('Warning: access to rating values blocked until library scan is completed');
		$request->setStatusDone();
		return;
	}

	if ($request->isNotCommand([['trackstat'],['setrating']]) && $request->isNotCommand([['trackstat'],['setratingpercent']])) {
		$request->setStatusBadDispatch();
		$log->warn('incorrect command');
		return;
	}

	my $source = $request->source // '';
	if ($source !~ /iPeng/) {
		$request->setStatusBadDispatch();
		$log->warn('TS legacy rating is only available for iPeng clients. Please use the correct ratingslight dispatch instead.');
		return;
	}

	my $rlCmd = $request->isCommand([['trackstat'],['setratingpercent']]) ? 'setratingpercent' : 'setrating';
	my $trackID= $request->getParam('_trackid');
	my $rating= $request->getParam('_rating');
	my $incremental = $request->getParam('_incremental');

	main::DEBUGLOG && $log->is_debug && $log->debug("Forwarding iPeng TS legacy setRating to RL: cmd = $rlCmd -- trackid = $trackID -- rating = $rating -- incremental = ".(defined $incremental ? $incremental : 'undef'));

	my @args = ('ratingslight', $rlCmd, $trackID, $rating);
	push @args, $incremental if defined $incremental;

	my $client = $request->client();
	my $rlRequest = Slim::Control::Request::executeRequest($client, \@args);

	if ($rlRequest) {
		$request->addResult('rating', $rlRequest->getResult('rating')) if defined $rlRequest->getResult('rating');
		$request->addResult('ratingpercentage', $rlRequest->getResult('ratingpercentage')) if defined $rlRequest->getResult('ratingpercentage');
	}
	$request->setStatusDone();
}

sub getRating {
	my $request = shift;
	main::DEBUGLOG && $log->is_debug && $log->debug('getRating - request source: '.($request->source // 'undef'));

	if (Slim::Music::Import->stillScanning) {
		$log->warn('Warning: access to rating values blocked until library scan is completed');
		$request->setStatusDone();
		return;
	}

	if ($request->isNotQuery([['trackstat'],['getrating']])) {
		$request->setStatusBadDispatch();
		$log->warn('incorrect command');
		return;
	}

	my $source = $request->source // '';
	if ($source !~ /iPeng/) {
		$request->setStatusBadDispatch();
		$log->warn('TS legacy rating is only available for iPeng clients. Please use the correct ratingslight dispatch instead.');
		return;
	}

	my $trackID = $request->getParam('_trackid');
	main::DEBUGLOG && $log->is_debug && $log->debug("Forwarding iPeng TS legacy getRating to RL: trackid = $trackID");

	my $rlRequest = Slim::Control::Request::executeRequest($request->client(), ['ratingslight', 'getrating', $trackID]);
	if ($rlRequest) {
		$request->addResult('rating', $rlRequest->getResult('rating')) if defined $rlRequest->getResult('rating');
		$request->addResult('ratingpercentage', $rlRequest->getResult('ratingpercentage')) if defined $rlRequest->getResult('ratingpercentage');
	}
	$request->setStatusDone();
}

1;