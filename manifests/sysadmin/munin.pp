# munin config
class ff_gw::sysadmin::munin($muninserver) {
  package {
    [ 'munin-node', 'vnstat', 'bc' ]:
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
cidr_allow <%= @muninserver %>/32
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
    '/usr/share/munin/plugins/dhcp-pool':
      ensure => file,
      mode   => '0755',
      source => 'puppet:///modules/ff_gw/usr/share/munin/plugins/dhcp-pool';
    '/etc/munin/plugins/dhcp-pool':
      ensure => link,
      target => '/usr/share/munin/plugins/dhcp-pool';
    '/etc/munin/plugin-conf.d/dhcp-pool':
      ensure  => file,
      content => '[dhcp-pool]
env.leasefile /var/lib/dhcp/dhcpd.leases
env.conffile /etc/dhcp/dhcpd.conf';
    '/etc/munin/plugins/if_mullvad':
      ensure => link,
      target => '/usr/share/munin/plugins/if_';
    '/etc/munin/plugins/if_err_mullvad':
      ensure => link,
      target => '/usr/share/munin/plugins/if_err_';
    '/etc/munin/plugins/if_bat0':
      ensure => link,
      target => '/usr/share/munin/plugins/if_';
    '/etc/munin/plugins/if_err_bat0':
      ensure => link,
      target => '/usr/share/munin/plugins/if_err_';
    '/etc/munin/plugins/if_br-ffhh':
      ensure => link,
      target => '/usr/share/munin/plugins/if_';
    '/etc/munin/plugins/if_err_br-ffhh':
      ensure => link,
      target => '/usr/share/munin/plugins/if_err_';
    '/etc/munin/plugins/if_ffhh-mesh-vpn':
      ensure => link,
      target => '/usr/share/munin/plugins/if_';
    '/etc/munin/plugins/if_err_ffhh-mesh-vpn':
      ensure => link,
      target => '/usr/share/munin/plugins/if_err_';
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
