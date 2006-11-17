package Logger::Syslog;

=head1 NAME

Logger::Syslog -- an simple wrapper over Syslog for Perl 

=head1 DESCRIPTION

You want to deal with syslog, but you don't want to bother with Sys::Syslog, 
that module is for you.

Logger::Syslog takes care of everything regarding the Syslog communication, all
you have to do is to use the function you need to send a message to syslog.

Logger::Syslog provides one function per Syslog message level: debug, info, 
warning, error, notice, critic, alert.

=head1 NOTES

Logger::Syslog is compliant with mod_perl, all you have to do when using it 
in such an environement is to call logger_init() at the beginning of your CGI,
that will garantee that everything will run smoothly (otherwise, issues with 
the syslog socket can happen in mod_perl env).

=head1 SYNOPSIS

    use Logger::Syslog;

    info("Starting at".localtime());
    
    #...

    if (error) {
        error("An error occured!");
        exit 1;
    }

    notice("There something to notify");
    ...
     
=head1 FUNCTIONS

=cut

BEGIN {
	use Exporter ;
	use vars qw($VERSION @ISA @EXPORT @EXPORT_OK %EXPORT_TAGS %SIG);
	$VERSION = "1.0";
	@ISA = ( 'Exporter' ) ;
	@EXPORT = qw (
		&debug
		&info
		&notice
		&warning
		&error
		&critic
		&alert
		&logger_prefix
		&logger_close
		&logger_init
        &logger_set_default_facility
	);
	@EXPORT_OK=@EXPORT;
	%EXPORT_TAGS = (":all"=>[],);
}

END {
    eval {        
	    logger_close();
    };
}

use strict;
use warnings;
use Carp;
use Sys::Syslog qw(:DEFAULT setlogsock); 
use File::Basename;

sub __get_script_name();
my $DEFAULT_FACILITY = "user";
our $fullname = __get_script_name();
our $basename = basename($fullname);

# If we're not under mod_perl, let's open the Syslog socket.
if (! defined $ENV{'MOD_PERL'}) {
    eval {        
        setlogsock('unix');
        openlog($basename, 'pid', $DEFAULT_FACILITY);
    };
}

=head2 logger_init

That function has to be called in mod_perl environment.
It will open the Syslog socket properly.

=cut

sub logger_init()
{
    return unless $ENV{'MOD_PERL'};
    eval {
        setlogsock('unix');
        $basename = basename($ENV{'SCRIPT_FILENAME'});
        $fullname = __get_script_name();
        openlog($basename, 'pid', $DEFAULT_FACILITY);
        logger_prefix("");
    };
}

=head2 logger_close

Call this to close the Syslog socket.

=cut

sub logger_close()
{
    eval {
        closelog();
    };
}

=head2 logger_prefix

That function lets you set a string that will be prefixed to every 
messages sent to syslog.

Example:
  
    logger_prefix("my program");
    info("starting");
    ...
    info("stopping");

=cut

our $g_rh_prefix = {};
sub logger_prefix(;$)
{
        my ($prefix) = @_;
        $prefix = "" unless defined $prefix;
        $fullname = __get_script_name();
        $g_rh_prefix->{$fullname} = $prefix;
}

my $LOG_FLAGS	=	{
	debug	=>	1,
	info	=>	1,
	notice	=>	1,
	warning =>	1,
	err	=>	1,
	crit 	=>	1,
	alert	=>	1
};

my %g_rh_label = (
	info    => 'info ',
	notice  => 'note ',
	err     => 'error',
	warning => 'warn ',
	debug   => 'debug',
	crit    => 'crit ',
	alert   => 'alert'
);


=head2 logger_set_default_facility(facility)

You can choose which facility to use, the default one is "user".

Example:

    logger_set_default_facility("cron");

=cut

sub logger_set_default_facility($)
{
    my ($facility) = @_;
    $DEFAULT_FACILITY = $facility;
}

=head2 debug(message)

Send a message to syslog, of the level "debug".

=cut

sub debug($)
{
	my ($message) = @_;
	return 0 unless defined $message and length $message;
	return log_with_syslog('debug', $message);
}

=head2 info(message)

Send a message to syslog, of the level "info".

=cut

sub info($)
{
	my ($message) = @_;
	return 0 unless defined $message and length $message;
	return log_with_syslog('info', $message);
}

=head2 notice(message)

Send a message to syslog, of the level "notice".

=cut

=head2 notice(message)

Envoie un message de type notice a syslog

=cut

sub notice($)
{
	my ($message) = @_;
	return 0 unless defined $message and length $message;
	return log_with_syslog('notice', $message);
}

=head2 warning(message)

Send a message to syslog, of the level "warning".

=cut

sub warning($)
{
	my ($message) = @_;
	return 0 unless defined $message and length $message;
	return log_with_syslog('warning', $message);
}

=head2 error(message)

Send a message to syslog, of the level "error".

=cut

sub error ($)
{
	my ($message) = @_;
	return 0 unless defined $message and length $message;
	return log_with_syslog('err', $message);
}

=head2 critic(message)

Send a message to syslog, of the level "critic".

=cut

sub critic ($)
{
	my ($message) = @_;
	return 0 unless defined $message and length $message;
	return log_with_syslog('crit', $message);
}

=head2 alert(message)

Send a message to syslog, of the level "alert".

=cut

sub alert ($)
{
	my ($message) = @_;
	return 0 unless defined $message and length $message;
	return log_with_syslog('alert', $message);
}

sub log_with_syslog ($$)
{
	my ($level, $message) = @_;
	return 0 unless defined $level and defined $message;
	
	my $caller = 2;
	if ($ENV{MOD_PERL}) {
		$caller = 1;
	}
	my ($package, $filename, $line, $fonction) = caller ($caller);

	$package  = "" unless defined $package;
	$filename = "" unless defined $filename;
	$line     = 0 unless defined $line;
	$fonction = $basename unless defined $fonction;
	$level = lc($level);
	$level = 'info' unless defined $level and length $level;
	return 0 unless $LOG_FLAGS->{$level}; 
	
	unless (defined $message and length $message) { 
		$message = "[void]";
	}

	my $level_str = $g_rh_label{$level};
	$message  = $level_str . " * $message";
	$message .= " - $fonction ($filename l. $line)" if $line;

	$message =~ s/%/%%/g; # we have to escape % to avoid a bug related to sprintf()
	$message = $g_rh_prefix->{$fullname} . " > " . $message if 
        (defined $g_rh_prefix->{$fullname} and length $g_rh_prefix->{$fullname}); 

    my $sig = $SIG{__WARN__};
    $SIG{__WARN__} = sub {};
	eval {
        syslog($level, $message);
    };
    $SIG{__WARN__} = $sig;
}

# returns the appropriate filename
sub __get_script_name()
{
        # si on est en mod perl, il faut utiliser $ENV{'SCRIPT_FILENAME'}
        return $ENV{'SCRIPT_FILENAME'} if $ENV{'MOD_PERL'} and $ENV{'SCRIPT_FILENAME'};
        return $0;
}

=head1 LICENSE

This program is free software; you can redistribute it and/or modify it under
the same terms as Perl itself.

=head1 COPYRIGHT

This program is copyright © 2004-2006 Alexis Sukrieh

=head1 AUTHOR

Alexis Sukrieh <sukria@sukria.net>

Very first versions were made at Cegetel (2004-2005) ; Thomas Parmelan gave a
hand for the mod_perl support.

=cut

1;
