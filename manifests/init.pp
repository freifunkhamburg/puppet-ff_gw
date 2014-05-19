class ff_gw($ff_net, $ff_mesh_net, $ff_as, $mesh_mac, $gw_ipv4, $gw_ipv6, $secret_key, $vpn_ca_crt, $vpn_usr_crt, $vpn_usr_key, $dhcprange_start, $dhcprange_end, $gw_do_ic_peering = false, $tinc_name, $tinc_keyfile, $ic_vpn_ip4, $ic_vpn_ip6) {
  class { 'ff_gw::software': }
  ->
  class { 'ff_gw::fastd':
    mesh_mac   => $mesh_mac,
    gw_ipv4    => $gw_ipv4,
    gw_ipv6    => $gw_ipv6,
    secret_key => $secret_key,
  }
  ->
  class { 'ff_gw::dhcpd':
    gw_ipv4         => $gw_ipv4,
    dhcprange_start => $dhcprange_start,
    dhcprange_end   => $dhcprange_end,
  }
  ->
  class { 'ff_gw::radvd':
    own_ipv6 => $gw_ipv6,
  }
  ->
  class { 'ff_gw::vpn':
    usr_crt => $vpn_usr_crt,
    usr_key => $vpn_usr_key,
    ca_crt  => $vpn_ca_crt,
  }
  ->
  class { 'ff_gw::iptables': }
  ->
  class { 'ff_gw::dnsmasq': }
  ->
  class { 'ff_gw::bird':
    ff_net           => $ff_net,
    ff_mesh_net      => $ff_mesh_net,
    ff_as            => $ff_as,
    own_ipv4         => $gw_ipv4,
    own_ipv6         => $gw_ipv6,
    gw_do_ic_peering => $gw_do_ic_peering,
  }

  if $gw_do_ic_peering {
    class { 'ff_gw::tinc':
      tinc_name    => $tinc_name,
      tinc_keyfile => $tinc_keyfile,
      ic_vpn_ip4   => $ic_vpn_ip4,
      ic_vpn_ip6   => $ic_vpn_ip6
    }
  }
}

class ff_gw::software {
  package {
    'batctl':
      ensure => installed;
    'batman-adv-dkms':
      ensure => installed;
    'fastd':
      ensure => installed;
    'bridge-utils':
      ensure => installed;
  }
  exec {
    'enable_batman_mod':
      command => 'echo batman-adv >> /etc/modules',
      unless  => 'grep -q ^batman-adv /etc/modules',
      path    => ['/bin', '/usr/sbin'],
  }
}

class ff_gw::fastd($mesh_mac, $gw_ipv4, $gw_ipv6, $secret_key) {
  validate_re($mesh_mac, '^de:ad:be:[0-9a-f]{2}:[0-9a-f]{2}:[0-9a-f]{2}$')

  file {
    '/etc/fastd/ffhh-mesh-vpn':
      ensure => directory;
    '/etc/fastd/ffhh-mesh-vpn/fastd.conf':
      ensure  => file,
      notify  => Service['fastd'],
      content => template('ff_gw/etc/fastd/ffhh-mesh-vpn/fastd.conf.erb');
    '/etc/fastd/ffhh-mesh-vpn/secret.conf':
      ensure  => file,
      mode    => '0600',
      content => inline_template('secret "<%= @secret_key %>";');
    '/root/bin':
      ensure => directory;
    '/root/bin/autoupdate_fastd_keys.sh':
      ensure => file,
      mode   => '0755',
      source => 'puppet:///modules/ff_gw/root/bin/autoupdate_fastd_keys.sh';
    '/usr/local/bin/check_gateway':
      ensure => file,
      mode   => '0755',
      source => 'puppet:///modules/ff_gw/usr/local/bin/check_gateway';
    '/etc/network/interfaces':
      ensure  => file,
      #
      content => inline_template('# managed by puppet

# The loopback network interface
auto lo
iface lo inet loopback

# The primary network interface
allow-hotplug eth0
iface eth0 inet dhcp

auto br-ffhh
iface br-ffhh inet6 static
  bridge-ports none
  address <%= @gw_ipv6 %>
  netmask 64
iface br-ffhh inet static
  address <%= @gw_ipv4 %>
  netmask 255.255.192.0

allow-hotplug bat0
iface bat0 inet6 manual
  pre-up modprobe batman-adv
  pre-up batctl if add ffhh-mesh-vpn
  up ip link set $IFACE up
  post-up brctl addif br-ffhh $IFACE
  post-up batctl it 10000
  post-up /sbin/ip rule add from all fwmark 0x1 table 42
  pre-down brctl delif br-ffhh $IFACE || true
  down ip link set $IFACE down
');
  }
  ->
  vcsrepo { '/etc/fastd/ffhh-mesh-vpn/peers':
    ensure   => present,
    provider => git,
    source   => 'git@freifunk-gw01.hamburg.ccc.de:fastdkeys',
  }

  cron {
    'autoupdate_fastd':
      command => '/root/bin/autoupdate_fastd_keys.sh',
      user    => root,
      minute  => '*/5';
    'check_gateway':
      command => '/usr/local/bin/check_gateway',
      user    => root,
      minute  => '*';
  }
  exec {
    'start_bridge_if':
      command => '/sbin/brctl addbr br-ffhh && /sbin/ifup br-ffhh',
      unless  => '/sbin/ifconfig br-ffhh';
    'batman_mod':
      command => '/sbin/modprobe batman-adv',
      unless  => '/sbin/lsmod | /bin/grep -q "^batman_adv"';
  }
  ->
  service {
    'fastd':
      ensure => running,
      enable => true,
  }
}

class ff_gw::dhcpd($gw_ipv4, $dhcprange_start, $dhcprange_end) {
  if ! is_ip_address($dhcprange_start)
  or ! is_ip_address($dhcprange_end)
  or ! is_ip_address($gw_ipv4) {
    fail('require gateway IP and DHCP range start/end')
  }

  # this class uses way too much dependencies
  # -- but with all those exec resources we really want
  # to stop processing if anything goes wrong

  package {
    'isc-dhcp-server':
      ensure => installed;
  }
  ->
  file {
    '/etc/dhcp/dhcpd.conf':
      ensure  => file,
      notify  => Service['isc-dhcp-server'],
      content => template('ff_gw/etc/dhcp/dhcpd.conf.erb');
  }
  ->
  user {
    'dhcpstatic':
      ensure => present,
      home   => '/home/dhcpstatic';
  }
  ->
  file {
    '/home/dhcpstatic':
      ensure => directory,
      owner  => dhcpstatic;
  }
  ->
  vcsrepo { '/home/dhcpstatic/dhcp-static':
    ensure   => present,
    provider => git,
    user     => 'dhcpstatic',
    source   => 'https://github.com/freifunkhamburg/dhcp-static',
  }
  ->
  exec {
    'updateStatics':
      command => '/home/dhcpstatic/dhcp-static/updateStatics.sh',
      creates => '/etc/dhcp/static.conf';
  }
  ->
  cron {
    'update_statics':
      command => '/home/dhcpstatic/dhcp-static/updateStatics.sh',
      user    => root,
      minute  => '*/5';
  }
  ->
  file {
    '/var/log/dhcpd.log':
      ensure => file,
      owner  => 'root',
      group  => 'adm',
      mode   => '0600';
    '/etc/rsyslog.d/dhcpd.conf':
      ensure  => file,
      notify  => Service['rsyslog'],
      content => 'local7.warn /var/log/dhcpd.log';
    '/etc/default/isc-dhcpd':
      ensure  => file,
      content => '# managed by puppet

#DHCPD_CONF=/etc/dhcp/dhcpd.conf
#DHCPD_PID=/var/run/dhcpd.pid
#OPTIONS=""
# On what interfaces should the DHCP server (dhcpd) serve DHCP requests?
# Separate multiple interfaces with spaces, e.g. "eth0 eth1".
INTERFACES="br-ffhh"
';
  }
  ->
  exec {
    'syslog_filter_l7':
      command => 'sed -i \'s:\*\.\*;auth,authpriv\.none:*.*;auth,authpriv.none;local7.none:\' /etc/rsyslog.conf',
      unless  => 'grep -q \'authpriv.none;local7.none\' /etc/rsyslog.conf',
      path    => ['/bin', '/usr/sbin'],
      notify  => Service['rsyslog'];
  }
  ->
  service {
    'rsyslog':
      ensure => running,
      enable => true,
  }
  ->
  service {
    'isc-dhcp-server':
      ensure => running,
      enable => true,
  }
}

class ff_gw::dnsmasq() {
  package {
    'dnsmasq':
      ensure => installed;
  }
  ->
  user {
    'ffdnsmasq':
      ensure => present,
      home   => '/home/ffdnsmasq',
  }
  ->
  file {
    '/home/ffdnsmasq':
      ensure => directory,
      owner  => 'ffdnsmasq',
  }
  ->
  vcsrepo { '/home/ffdnsmasq/dnsmasq':
    ensure   => present,
    provider => git,
    user     => 'ffdnsmasq',
    source   => 'https://github.com/freifunkhamburg/dnsmasq',
  }
  ->
  exec {
    'updateDnsmasq':
      command => '/home/ffdnsmasq/dnsmasq/updateDnsmasq.sh',
      creates => '/etc/dnsmasq.d/rules';
    'fix_dnsmasq_init.d':
      command => 'sed -i -e \'s/^# Required-Start: \$network \$remote_fs \$syslog/# Required-Start: $network $remote_fs $syslog openvpn/\' /etc/init.d/dnsmasq',
      unless  => 'grep \'^# Required-Start: $network $remote_fs $syslog openvpn$\' /etc/init.d/dnsmasq',
      path    => ['/bin'],
  }
  ->
  cron {
    'update_Dnsmasq':
      command => '/home/ffdnsmasq/dnsmasq/updateDnsmasq.sh',
      user    => root,
      minute  => '*/5';
  }
  ->
  service {
    'dnsmasq':
      ensure  => running,
      enable  => true,
      require => Service['openvpn'],
  }
}

class ff_gw::radvd($own_ipv6) {
  package {
    'radvd':
      ensure => installed;
  }
  ->
  file {
    '/etc/radvd.conf':
      ensure  => file,
      content => template('ff_gw/etc/radvd.conf.erb');
  }
  ->
  service {
    'radvd':
      ensure => running,
      enable => true,
  }

  augeas { 'enable_ip_forwarding':
    context => '/files/etc/sysctl.conf',
    changes => [
      'set net.ipv4.ip_forward 1',
      'set net.ipv6.conf.all.forwarding 1'
    ],
  }
  ~>
  exec {
    'sysctl':
      command     => '/sbin/sysctl -p',
      # this gets notified to run only if /etc/sysctl.conf is changed:
      refreshonly => true;
  }
}

class ff_gw::vpn($ca_crt, $usr_crt, $usr_key, $openvpn_version = '2.3.2-7~bpo70+1', $ensure = 'running') {
  # TODO: this name is used in several places including dnsmasq
  # and is even used for other providers, thus hard to change
  $vpnname = 'mullvad'

  package {
    'openvpn':
      ensure => $openvpn_version;
  }
  ->
  file {
    "/etc/openvpn/${vpnname}":
      ensure => directory;
    "/etc/openvpn/${vpnname}/ca.crt":
      ensure  => file,
      content => $ca_crt;
    "/etc/openvpn/${vpnname}/client.crt":
      ensure  => file,
      content => $usr_crt;
    "/etc/openvpn/${vpnname}/client.key":
      ensure  => file,
      mode    => '0600',
      content => $usr_key;
    "/etc/openvpn/${vpnname}/mullvad-up":
      ensure  => file,
      mode    => '0755',
      content => '#!/bin/sh
ip route replace 0.0.0.0/1 via $5 table 42
ip route replace 128.0.0.0/1 via $5 table 42
/usr/sbin/service dnsmasq restart
exit 0';
    "/etc/openvpn/${vpnname}.conf":
      ensure => file,
      source => "puppet:///modules/ff_gw/etc/openvpn/${vpnname}.conf";
  }
  ~>
  service { 'openvpn':
    ensure => $ensure,
    enable => true,
  }
  ~>
  exec { 'openvpn_sleep':
    # OpenVPN takes some time to set up the interface
    command     => '/bin/sleep 5',
    refreshonly => true,
  }
}

class ff_gw::iptables {
  package {
    'iptables-persistent':
      ensure => installed;
  }
  ->
  file {
    '/etc/iptables/rules.v4':
      ensure => file,
      source => 'puppet:///modules/ff_gw/etc/iptables/rules.v4';
    '/etc/rc.local':
      ensure  => file,
      content => '#!/bin/sh -e
# managed by puppet
#
# rc.local
#
# This script is executed at the end of each multiuser runlevel.
# Make sure that the script will "exit 0" on success or any other
# value on error.
#
# In order to enable or disable this script just change the execution
# bits.
#
# By default this script does nothing.

/sbin/ip route add unreachable default table 42
/sbin/ip rule add from all fwmark 0x1 table 42
exit 0';
  }
  ~>
  service {
    'iptables-persistent':
      ensure => running,
      enable => true,
  }
}

class ff_gw::bird($ff_net, $ff_mesh_net, $ff_as, $own_ipv4, $own_ipv6, $gw_do_ic_peering, $version = 'present') {
  # read peering data from data file
  $module_path = get_module_path($module_name)
  $peeringdata = loadyaml("${module_path}/data/peering.yaml")
  $peerings_v4 = $peeringdata[peerings_v4]
  $peerings_v6 = $peeringdata[peerings_v6]
  $ic_peerings_v4 = $peeringdata[ic_peerings_v4]
  $ic_peerings_v6 = $peeringdata[ic_peerings_v6]

  package {
    'bird6':
      ensure => $version,
  }
  ->
  file {
    '/etc/bird6.conf':
      ensure  => file,
      content => template('ff_gw/etc/bird6.conf.erb');
  }
  ~>
  service {
    'bird6':
      ensure  => running,
      enable  => true,
      require => Service['openvpn'],
  }


  package {
    'bird':
      ensure => $version,
  }
  ->
  file {
    '/etc/bird.conf':
      ensure  => file,
      content => template('ff_gw/etc/bird.conf.erb');
  }
  ~>
  service {
    'bird':
      ensure  => running,
      enable  => true,
      require => Service['openvpn'],
  }
}

class ff_gw::tinc($tinc_name, $tinc_keyfile = '/etc/tinc/rsa_key.priv', $ic_vpn_ip4, $ic_vpn_ip6, $version = 'present') {
  package {
    'tinc':
      ensure => $version,
  }
  ->
  vcsrepo { '/etc/tinc/icvpn':
    ensure   => present,
    provider => git,
    source   => 'https://github.com/freifunk/icvpn',
  }
  ->
  file {
    '/etc/tinc/icvpn/tinc.conf':
      ensure  => file,
      content => template('ff_gw/etc/tinc/icvpn/tinc.conf.erb');
    '/etc/tinc/icvpn/tinc-up':
      ensure  => file,
      mode    => '0755',
      content => inline_template('#!/bin/sh
/sbin/ip link set dev $INTERFACE up
/sbin/ip addr add dev $INTERFACE <%= @ic_vpn_ip4 %>/16 broadcast 10.207.255.255
/sbin/ip -6 addr add dev $INTERFACE <%= @ic_vpn_ip6 %>/96 preferred_lft 0
');
    '/etc/tinc/icvpn/tinc-down':
      ensure  => file,
      mode    => '0755',
      content => inline_template('#!/bin/sh
/sbin/ip addr del dev $INTERFACE <%= @ic_vpn_ip4 %>/16 broadcast 10.207.255.255
/sbin/ip -6 addr del dev $INTERFACE <%= @ic_vpn_ip6 %>/96
/sbin/ip link set dev $INTERFACE down
');
  }
  ~>
  service {
    'tinc':
      ensure  => running,
      enable  => true,
      require => Service['openvpn'],
  }
}
