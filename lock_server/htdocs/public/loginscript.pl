#!/usr/bin/perl

use strict;
use Apache2::RequestUtil;

my $r = Apache2::RequestUtil->request;

# Setting the status to 200 here causes the default apache 403 page to be
# appended to the custom error document.  We understand but the user may not
# $r->status(200);
my $uri = $r->prev->uri;

my $creds = $r->prev->pnotes("LockServerCreds");

# if there are args, append that to the uri
my $args = $r->prev->args;
if ($args) {
    $uri .= "?$args";
}

my $reason = $r->prev->subprocess_env("AuthCookieReason");

my $form = <<HERE;
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<HTML xmlns="http://www.w3.org/1999/xhtml">
<HEAD>
	<link href="/style.css" rel="stylesheet" type="text/css" />
	<META http-equiv="Content-Type" content="text/html; charset=UTF-8" />
	<TITLE>Lock Server : Enter Login and Password</TITLE>
</HEAD>
<BODY onLoad="document.forms[0].credential_0.focus();">
HERE

# output creds in a comment so the test case can see them.
if (defined $creds) {
    $form .= "<!-- creds: @{$creds} -->\n";
}

$form .= <<FORM;
<FORM METHOD="POST" ACTION="/login" AUTOCOMPLETE="on">
  <input type=hidden name=destination value="$uri" />
  <table align="left">
    <tr>
      <td align="right"><p>Login:</p></td>
      <td><p><input type="text" name="credential_0" size="12" maxlength="32" autocomplete="on" /></p></td>
    </tr>
    <tr>
      <td align="right"><p>Password:</p></td>
      <td><p><input type="password" name="credential_1" size="12" maxlength="32" autocomplete="on" /></p></td>
    </tr>
    <tr>
      <td colspan="2" align="right"><p><input type="submit" value="Continue" /></p></td>
    </tr>
  </table>
</FORM>
</BODY>
</HTML>
FORM

$r->no_cache(1);
my $length = length($form);
$r->content_type("text/html");
$r->headers_out->set("Content-length","$length");
$r->headers_out->set("Pragma", "no-cache");

$r->print ($form);
