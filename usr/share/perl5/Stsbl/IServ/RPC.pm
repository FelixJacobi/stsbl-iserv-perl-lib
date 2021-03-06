# StsBl IServ RPC Perl Library

package Stsbl::IServ::RPC;
use warnings;
use strict;
use Encode qw(encode);
use IServ::RPC;
use Stsbl::IServ::IO;
use Stsbl::IServ::OpenSSH;

BEGIN
{
  use Exporter;
  our @ISA = qw(Exporter);
  our @EXPORT = qw(rcp_message_unicode rpc_linux_current_user rpc_linux_req_nologin);
}

sub rpc_message_unicode($$)
{
  my ($ip, $msg) = @_;
  $msg =~ s/\r?\n/\r/g;
  my @err;
  # NO decoding here, it already breaks special chars like umlauts!
  # Just encode to iso-8859-2 here and set the code page of
  # cmd on client to utf-8 (code page 65001).
  $msg = encode("iso-8859-2", $msg);
  # real limit seems to be at about 4320 chars:
  if (length $msg > 4096)
  {
    @err = "rpc_message_unicode: message too long\n";
  }
  else
  {
    @err = IServ::RPC::winexe $ip, "cmd", "/c", "chcp 65001", ">NUL", "&", IServ::RPC::netlogon "exe\\start", "iserv-msg", $msg;
  }
  wantarray? @err: print STDERR @err;
}

sub rpc_linux_current_user($)
{
  my ($ip) = @_;
  my %ssh_call = openssh_run $ip, "who -u";
  my @out = split /\n/, $ssh_call{stdout};
  my $maxtty = 0;
  my %users;

  for (@out)
  {
    if (/^([a-z][a-z0-9._-]+)\stty([0-9]+)/)
    {
      $users{$2} = $1;
      $maxtty = $2 if $2 > $maxtty;	
    }
  }

  return $users{$maxtty} if defined $users{$maxtty};
}

sub rpc_linux_req_nologin(@)
{
  my (@ips) = @_;
  my $cnt;
  for (@ips)
  {
    rpc_linux_current_user $_ or next;
    print STDERR "$_: still logged in\n";
    $cnt++;
  }
  error "All users must be logged off from the selected computers." if $cnt;
}

1;
