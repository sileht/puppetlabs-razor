require 'spec_helper'

describe 'razor', :type => :class do
  let (:params) do
    {
      :username            => 'blade',
      :directory           => '/var/lib/razor',
      :persist_host        => '127.0.0.1',
      :mk_checkin_interval => '60',
      :git_source          => 'http://github.com/johndoe/Razor.git',
      :git_revision        => '1ef7d2',
      :server_opts_hash    => { 'mk_log_level' => 'Logger::DEBUG' },
    }
  end

  [ { :osfamily  => 'Debian',
      :path      => '/srv/tftp', },
    { :osfamily  => 'Debian',
      :os        => 'Ubuntu',
      :lsb       => 'precise',
      :path      => '/var/lib/tftpboot' },
    { :osfamily  => 'RedHat',
      :path      => '/var/lib/tftpboot' },
  ].each do |platform|
    context "on #{platform[:os] || platform[:osfamily]} operatingsystems" do
      let(:facts) do
        { :osfamily        => platform[:osfamily],
          :operatingsystem => platform[:os] || platform[:osfamily],
          :lsbdistcodename => platform[:lsb] || :undef,
          :ipaddress       => '10.13.1.3',
        }
      end
      it {
        should include_class('mongodb')
        should include_class('sudo')
        should contain_class('razor::nodejs').with(
          :directory => params[:directory]
        )
        should include_class('razor::tftp')
        should include_class('razor::ruby')
        should contain_user(params[:username]).with(
          :ensure => 'present',
          :gid    => params[:username],
          :home   => params[:directory]
        )
        should contain_group(params[:username]).with(
          :ensure => 'present'
        )
        should contain_sudo__conf('razor').with(
          :priority => '10',
          :content  => /#{params[:username]} ALL=\(root\)/
        )
        should contain_package('git').with( :ensure => 'present' )
        should contain_vcsrepo(params[:directory]).with(
          :ensure   => 'latest',
          :provider => 'git',
          :source   => params[:git_source],
          :revision => params[:git_revision]
        )
        should contain_file(params[:directory]).with(
          :ensure => 'directory',
          :mode   => '0755',
          :owner  => params[:username],
          :group  => params[:username]
        )
        should contain_service('razor').with(
          :ensure    => 'running',
          :hasstatus => true,
          :status    => "/var/lib/razor/bin/razor_daemon.rb status",
          :start     => "/var/lib/razor/bin/razor_daemon.rb start",
          :stop      => "/var/lib/razor/bin/razor_daemon.rb stop",
          :require   => ['Class[Mongodb]', 'File[/var/lib/razor]', 'Sudo::Conf[razor]'],
          :subscribe => ['Class[Razor::Nodejs]', "Vcsrepo[#{params[:directory]}]"]
        )
        should contain_exec('get_default_config').with_command("#{params[:directory]}/bin/razor config factory | sed -e 's/^[[:space:]]*//g' -e 's/[[:space:]]*\$//g' -e 's/:\$/: \"\"/g' -e 's/persist_mode: /&:/' | grep -v -e '^ProjectRazor Config' -e '^image_svc_host:' -e '^image_svc_path:' -e '^mk_checkin_interval:' -e '^mk_log_level:' -e '^mk_uri:' -e '^persist_host:' | sort > #{params[:directory]}/conf/razor_server.conf.default")
        should include_class('concat::setup')
        should contain_concat__fragment("razor_server.conf.default").with(
          #:require => 'Exec[get_default_config]', # disable due to "razor config default" workaround
          :source => "#{params[:directory]}/conf/razor_server.conf.default"
        )
        should contain_concat__fragment("razor_server.conf.custom").with(
          :content => /image_svc_host: #{facts[:ipaddress]}/,
          :content => /image_svc_path: #{params[:directory]}\/image/,
          :content => /mk_uri: http:\/\/#{facts[:ipaddress]}:8026/,
          :content => /mk_checkin_interval: #{params[:mk_checkin_interval]}/,
          :content => /persist_host: #{params[:persist_host]}/,
          :content => /mk_log_level: #{params[:server_opts_hash]['mk_log_level']}/
        )
        should contain_concat("#{params[:directory]}/conf/razor_server.conf").with(
          :notify  => 'Service[razor]'
        )
        should contain_exec('gen_ipxe').with_command("#{params[:directory]}/bin/razor config ipxe > /tmp/razor.ipxe")
        should contain_exec('gen_ipxe').with(
          :subscribe => "File[#{params[:directory]}/conf/razor_server.conf]"
        )
        should contain_file("#{platform[:path]}/razor.ipxe").with(
          :source => '/tmp/razor.ipxe',
          :subscribe => 'Exec[gen_ipxe]'
        )
      }
    end
  end
end
