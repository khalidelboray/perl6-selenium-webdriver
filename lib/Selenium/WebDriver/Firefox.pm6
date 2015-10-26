
use v6;

use Selenium::WebDriver::Wire;
use File::Which;
use File::Temp;
use JSON::Tiny;

unit class Selenium::WebDriver::Firefox is Selenium::WebDriver::Wire;

has Proc::Async $.process    is rw;

method start {
  self.url-prefix = "/hub";

  my $webdriver-xpi;
  for @*INC -> $lib is copy {
    $lib = $lib.subst(/^ \w+ '#'/,"");
    my $f = $*SPEC.catfile($lib, "Selenium/WebDriver/Firefox/extension/webdriver.xpi");
    if $f.IO ~~ :e {
        $webdriver-xpi = $f;
        last;
    }
  }
  fail("Cannot find webdriver.xpi") unless $webdriver-xpi.defined;

  my ($directory, $dirhandle) = tempdir;

  # unzip webdriver.xpi
  my $profile-path = "$directory/perl6-selenium-webdriver";
  my $extension-path = "$profile-path/extensions/fxdriver@googlecode.com";
  my $prefs-file-name = "$profile-path/user.js";

  # Read firefox json-formatted preferences
  my $firefox-prefs = "lib/Selenium/WebDriver/Firefox/extension/prefs.json";
  my $prefs = from-json($firefox-prefs.IO.slurp);

  # Create temporary profile path
  $profile-path.IO.mkdir;

  # Modify port...
  $prefs<mutable><webdriver_firefox_port> = self.port;

  # Write a user.js file in profile path
  my $fh = $prefs-file-name.IO.open(:w);
  for $prefs<frozen>.kv -> $k, $v {
    my $value = to-json($v);
    $fh.say(qq{user_pref("$k", $value);});
  }
  for $prefs<mutable>.kv -> $k, $v {
    my $value = to-json($v);
    $fh.say(qq{user_pref("$k", $value);});
  }
  $fh.close;

  $extension-path.IO.mkdir;

  run "unzip", "-d", $extension-path, $webdriver-xpi;

  # Setup firefox environment
  # %*ENV<XRE_CONSOLE_LOG> = "firefox.log";
  %*ENV<XRE_PROFILE_PATH> = $profile-path;
  %*ENV<MOZ_CRASHREPORTER_DISABLE> = "1";
  %*ENV<MOZ_NO_REMOTE> = "1";
  %*ENV<NO_EM_RESTART> = "1";

  say "Launching firefox";

  # Find process in PATH
  my $firefox = which("firefox");
  die "Cannot find firefox in your PATH" unless $firefox.defined;
  say "Firefox found at '$firefox'";
  my $p = Proc::Async.new($firefox);
  $p.start;

  self.process = $p;
}

method stop {
  self.process.kill if self.process.defined;
}
