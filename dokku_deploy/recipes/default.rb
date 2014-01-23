%w{deploy}.each do |dep|
	include_recipe dep
end

bash 'set_locale' do
	code <<-EOH
		export LANGUAGE=en_US.UTF-8
		export LANG=en_US.UTF-8
		export LC_ALL=en_US.UTF-8
		sudo locale-gen en_US.UTF-8
		sudo dpkg-reconfigure locales
	EOH
end

if node[:opsworks][:instance][:instance_type] == "t1.micro"
	bash 'set_swap' do
		code <<-EOH
			sudo /bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024
			sudo /sbin/mkswap /var/swap.1
			sudo /sbin/swapon /var/swap.1
			sudo echo "/var/swap.1 swap swap defaults 0 0" >> /etc/fstab
		EOH
		not_if 'grep -q "/var/swap.1 swap swap defaults 0 0" /etc/fstab'
	end
end

node[:deploy].each do |application, deploy|

	if deploy[:domains]

		opsworks_deploy_dir do
			user deploy[:user]
			group deploy[:group]
			path deploy[:deploy_to]
		end

		opsworks_deploy do
			deploy_data deploy
			app application
		end

		directory "#{node[:dokku][:root]}/#{deploy[:domains].first}/ssl" do
			owner 'dokku'
			group 'dokku'
			recursive true
			not_if "#{node[:dokku][:root]}/#{deploy[:domains].first}/ssl"
			action :create
		end

		template "#{node[:dokku][:root]}/#{deploy[:domains].first}/ssl/server.crt" do
			mode '0600'
			owner 'dokku'
			source "ssl.key.erb"
			variables :key => deploy[:ssl_certificate]
			only_if do
				deploy[:ssl_support]
			end
			action :create_if_missing
		end

		template "#{node[:dokku][:root]}/#{deploy[:domains].first}/ssl/server.key" do
			mode '0600'
			owner 'dokku'
			source "ssl.key.erb"
			variables :key => deploy[:ssl_certificate_key]
			only_if do
				deploy[:ssl_support]
			end
			action :create_if_missing
		end

		template "#{node[:dokku][:root]}/#{deploy[:domains].first}/ssl/server.ca" do
			mode '0600'
			owner 'dokku'
			source "ssl.key.erb"
			variables :key => deploy[:ssl_certificate_ca]
			only_if do
				deploy[:ssl_support] && deploy[:ssl_certificate_ca]
			end
			action :create_if_missing
		end
		
		execute "git push dokku@localhost:#{deploy[:domains].first} #{deploy[:scm][:revision]}"  do
			command "git push dokku@localhost:#{deploy[:domains].first} #{deploy[:scm][:revision]}"
			cwd deploy[:current_path]
		end
	end
end