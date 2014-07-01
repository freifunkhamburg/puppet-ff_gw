# kitchen sink class for various small settings
class ff_gw::sysadmin($zabbixserver = '127.0.0.1', $muninserver = '127.0.0.1', $sethostname = false, $setip = false, $accounts = {}) {
  # first of all: fix my hostname
  if $sethostname and $setip {
    # set system hostname
    class { 'ff_gw::sysadmin::hostname':
      newname => $sethostname,
      newip   => $setip,
    }
  }

  # next important thing: set up apt repositories
  class { 'ff_gw::sysadmin::software': }

  cron {
    'ntpdate-debian':
      command => '/usr/sbin/ntpdate-debian',
      user    => root,
      minute  => '0';
  }

  # user accounts
  create_resources('account', $accounts)
  # Sudo
  include sudo
  sudo::conf { 'admins':
    priority => 10,
    content  => '%sudo ALL=(ALL) NOPASSWD: ALL',
  }

  # sshd
  augeas { 'harden_sshd':
    context => '/files/etc/ssh/sshd_config',
    changes => [
      'set PermitRootLogin no',
      'set PasswordAuthentication no',
      'set PubkeyAuthentication yes'
    ],
  }
  ~>
  service { 'ssh':
    ensure => running,
    enable => true,
  }

  class { 'ff_gw::sysadmin::zabbix':
    zabbixserver => $zabbixserver,
  }
  class { 'ff_gw::sysadmin::munin':
    muninserver => $muninserver,
  }
}

class ff_gw::sysadmin::hostname($newname, $newip) {
  # short name
  $alias = regsubst($newname, '^([^.]*).*$', '\1')

  # clean old names
  if $::hostname != $alias {
    host { $::hostname: ensure => absent }
  }
  if $::fqdn != $newname {
    host { $::fqdn:     ensure => absent }
  }

  # rewrite config files:
  host { $newname:
    ensure => present,
    ip     => $newip,
    alias  => $alias ? {
      $::hostname => undef,
      default     => $alias
    },
    before => Exec['hostname.sh'],
  }

  file { '/etc/mailname':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "${newname}\n",
  }

  file { '/etc/hostname':
    ensure  => present,
    owner   => 'root',
    group   => 'root',
    mode    => '0644',
    content => "${newname}\n",
    notify  => Exec['hostname.sh'],
  }

  exec { 'hostname.sh':
    command     => '/etc/init.d/hostname.sh start',
    refreshonly => true,
  }
}

# everything related to apt-repos and default tools
class ff_gw::sysadmin::software() {
  class { '::apt':
    always_apt_update => true
  }
  # use backports repo
  apt::source { 'wheezy-backports':
    location => 'http://ftp.de.debian.org/debian/',
    release  => 'wheezy-backports',
    repos    => 'main',
  }
  # batman repo
  apt::source { 'universe-factory':
    location   => 'http://repo.universe-factory.net/debian/',
    release    => 'sid',
    repos      => 'main',
    key        => '16EF3F64CB201D9C',
    key_server => 'pool.sks-keyservers.net',
  }
  # bird repo // TODO: no PGP key
  apt::source { 'bird-network':
    location   => 'http://bird.network.cz/debian/',
    release    => 'wheezy',
    repos      => 'main',
  }

  # then install some basic packages
  package {
    ['vim-nox', 'git', 'etckeeper', 'pv', 'curl', 'atop',
    'screen', 'tcpdump', 'rsync', 'file', 'psmisc', 'ntpdate']:
      ensure => installed,
  }
  ->
  # remove atop cronjob
  file { '/etc/cron.d/atop':
    ensure => absent,
  }
  ->
  # stop atop daemon (cf. https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=506191)
  service { 'atop':
    ensure  => stopped,
    enable  => false,
  }
}
