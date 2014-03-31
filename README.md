# Freifunk Gateway Module

Martin Schütte <info@mschuette.name>

This module tries to automate the configuration of a Freifunk (Hamburg) Gateway.
The idea is to implement the step-by-step guide on http://wiki.freifunk.net/Freifunk_Hamburg/Gateway

A generalization for other communities would be nice, but right now this is all
experimental and we will be glad when it works for our own gateways.

Also note that this is a really ugly puppet module that ignores all principles
of modularity and interoperability; instead it follows the "Big ball of mud"
design pattern.

## Usage

Install as a puppet module, then include with node-specific parameters.

Basically there are three kinds of parameters: user accounts (optional if you
do manual user management), network config (has to be in sync with the wiki
page), and credentials for fastd and openvpn.

Example puppet code:

```class { 'ff_gw':
    # user accounts:
    accounts => {
        mschuett => {
            comment => 'Martin Schuette',
            ssh_key => 'AAAAB3NzaC1yc2EAAAADAQABAAABAQC4qcAOjmLCv+DaF405K9/napCQCq8qJnTJtkbeQR+PGLHAR3kxXFh5rQXKp5n3IxEhZt4js7yin5EBmfCMv+CHYSndT4BGVDarjqIoM7RAKI8MyJUus0SOf5WsnAGamp97mCh8iWHg7v+emqYcF308FFkubKzFLdHjdLGZBCduClUvkyuuUc7vtkXZ3IkInXGkrN5hn388/lHsT1ewUva7j2fZmbVou8P2FHC4+azPInoyezwiIE6YrFKAyquDhuFRDir5QqlFaZpD6C8T+vEiqWRyqPxI7YVGBudh2oec5m99VTWkrPw7cOsC92ndLAgQ2MjxEeDhPh/Tgxly6flb',
            groups => ['sudo', 'users'],
        }
    },

    # network config (example data for gw12)
    mesh_mac        => 'de:ad:be:ef:01:14',
    gw_ipv4         => '10.112.30.1',
    gw_ipv6         => 'fd51:2bb2:fd0d::501',
    dhcprange_start => '10.112.30.2',
    dhcprange_end   => '10.112.31.254',

    # secret credentials for fastd and vpn
    secret_key      => '...',
    vpn_ca_crt      => '-----BEGIN CERTIFICATE-----
MIIE ...
-----END CERTIFICATE-----',
    vpn_usr_crt     => '-----BEGIN CERTIFICATE-----
MIIE ...
-----END CERTIFICATE-----',
    vpn_usr_key     => '-----BEGIN CERTIFICATE-----
MIIE ...
-----END CERTIFICATE-----',
}
```
