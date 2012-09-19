# Example for how to specify per host policy based on macaddress.

define system (
  $macaddress,
  $hostname       = $name, # The actual model is actually prefix, a model with hostname is required.
  $domainname     = 'puppetlabs.lan',
  $rootpassword   = 'puppet',
  $image          = 'precise',
  $model_template = 'ubuntu_precise',
) {

  rz_model { $name:
    ensure      => present,
    image       => $image,
    metadata    => { 'domainname'      => $domainname,
                     'hostname_prefix' => $hostname,
                     'rootpassword'    => $rootpassword, },
    template    => $model_template,
  }

  rz_tag { $name:
    tag_label   => $name,
    tag_matcher => [ { 'key'     => 'macaddress_eth0',
                       'compare' => 'equal',
                       'value'   => $macaddress,
                       'inverse' => false,
                     } ],
  }

  rz_policy { $name:
    ensure  => 'present',
    broker  => 'none',
    model   => $name,
    enabled => 'true',
    tags    => [$name],
    template => 'linux_deploy',
    maximum => 1,
  }
}

rz_image { 'rz_mk_prod-image.0.9.0.4.iso':
  ensure  => present,
  type    => 'mk',
  source  => 'https://github.com/downloads/puppetlabs/Razor-Microkernel/rz_mk_prod-image.0.9.0.4.iso',
}

rz_image { 'UbuntuPrecise':
  ensure => present,
  type    => 'os',
  version => '12.04',
  source  => '/opt/razor/ubuntu-12.04.1-server-amd64.iso',
}

system { 'demo':
  macaddress   => '00:25:B5:00:05:BF',
  rootpassword => 'test1234',
  image        => 'UbuntuPrecise',
}
