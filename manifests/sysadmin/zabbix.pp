# zabbix agent config
class ff_gw::sysadmin::zabbix($zabbixserver) {
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
Server=${zabbixserver}
ServerActive=${zabbixserver}
HostnameItem=${::hostname}
";
  }
  ~>
  service { 'zabbix-agent':
    ensure => running,
    enable => true,
  }
}
