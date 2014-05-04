# kitchen sink class for various small settings
class ff_gw::sysadmin {

  # use Hiera as a Puppet data source
  file {
    '/etc/puppet/hiera.yaml':
      # content from git repo, not from puppet
      ensure => file;
    '/etc/hiera.yaml':
      ensure => link,
      target => '/etc/puppet/hiera.yaml';
  }

  # use backports repo
  apt::source { 'wheezy-backports':
    location   => 'http://ftp.de.debian.org/debian/',
    release    => 'wheezy-backports',
    repos      => 'main',
  }
  # some more packages
  package {
    ['vim-nox', 'git', 'etckeeper', 'pv', 'curl', 'atop',
    'screen', 'tcpdump', 'rsync', 'file']:
      ensure => installed,
  }

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

  # zabbix
  apt::source { 'zabbix':
    location   => 'http://repo.zabbix.com/zabbix/2.2/debian',
    release    => 'wheezy',
    repos      => 'main',
    key        => '79EA5ED4',
    key_server => 'pgpkeys.mit.edu',
  }
  ->
  package { 'zabbix-agent':
    ensure => latest;
  }
  ->
  file { '/etc/zabbix/zabbix_agentd.d/argos_monitoring.conf':
    ensure  => file,
    content => "# managed by puppet
Server=argos.mschuette.name
ServerActive=argos.mschuette.name
HostnameItem=${::hostname}
";
  }
  ~>
  service { 'zabbix-agent':
    ensure => running,
    enable => true,
  }

  # munin
  package {
    [ 'munin-node', 'vnstat' ]:
      ensure => installed,
  }
  ->
  file {
    '/etc/munin/munin-node.conf':
      ensure  => file,
      # mostly Debin pkg default
      content => inline_template('# managed by puppet
log_level 4
log_file /var/log/munin/munin-node.log
pid_file /var/run/munin/munin-node.pid

background 1
setsid 1

user root
group root

# Regexps for files to ignore
ignore_file [\#~]$
ignore_file DEADJOE$
ignore_file \.bak$
ignore_file %$
ignore_file \.dpkg-(tmp|new|old|dist)$
ignore_file \.rpm(save|new)$
ignore_file \.pod$

port 4949

host_name <%= @fqdn %>
cidr_allow 78.47.49.236/32
host <%= @ipaddress_eth0 %>
');
    '/usr/share/munin/plugins/vnstat_':
      ensure => file,
      mode   => '0755',
      source => 'puppet:///modules/ff_gw/usr/share/munin/plugins/vnstat_';
    '/etc/munin/plugins/vnstat_eth0_monthly_rxtx':
      ensure => link,
      target => '/usr/share/munin/plugins/vnstat_';
    '/usr/share/munin/plugins/udp-statistics':
      ensure => file,
      mode   => '0755',
      source => 'puppet:///modules/ff_gw/usr/share/munin/plugins/udp-statistics';
    '/etc/munin/plugins/udp-statistics':
      ensure => link,
      target => '/usr/share/munin/plugins/udp-statistics';
    # TODO: delete not needed plugins
    '/etc/munin/plugin-conf.d/vnstat':
      ensure  => file,
      content => '[vnstat_eth0_monthly_rxtx]
env.estimate 1';
  }
  ~>
  service { 'munin-node':
    ensure => running,
    enable => true;
  }
}
