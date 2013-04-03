#
# Cookbook Name:: quantum
# Recipe:: setup
#
# Copyright 2013,  SUSE LINUX Products GmbH, Nuernberg, Germany.
#
# All modifications and additions to the file contributed by third parties
# remain the property of their copyright owners, unless otherwise agreed
# upon. The license for this file, and modifications and additions to the
# file, is the same license as for the pristine package itself (unless the
# license for the pristine package is not an Open Source License, in which
# case the license is the MIT License). An "Open Source License" is a
# license that conforms to the Open Source Definition (Version 1.9)
# published by the Open Source Initiative.

# Please submit bugfixes or comments via http://bugs.opensuse.org/
#

#
# all this stuff shoud be moved to quantum resources (like in the keystone)
#
execute "create_main_router" do
  command "quantum router-create #{node["quantum"]["router"]["main"]["name"]}"

  not_if "quantum router-list | grep -q ' #{node["quantum"]["router"]["main"]["name"]} '"
end

execute "create_external_network" do
  command "quantum net-create #{node["quantum"]["net"]["external"]["name"]} --router:external=True"

  not_if "quantum net-list | grep -q ' #{node["quantum"]["net"]["external"]["name"]} '"
end

execute "create_external_network" do
  command "quantum net-create #{node["quantum"]["net"]["internal"]["name"]} --shared"

  not_if "quantum net-list | grep -q ' #{node["quantum"]["net"]["internal"]["name"]} '"
end

node["quantum"]["subnets"]["external"].each do |subnet|
  execute "create_external_subnet_#{subnet["name"]}" do
    command "quantum subnet-create --name #{subnet["name"]} --allocation-pool start=#{subnet["start"]},end=#{subnet["end"]} --gateway #{subnet["gateway"]} --disable-dhcp #{node["quantum"]["net"]["external"]["name"]} #{subnet["cidr"]}"

    not_if "quantum subnet-list | grep -q ' #{subnet["name"]} '"
  end
end

execute "setup_default_gateway_on_main_router" do
  command "quantum router-gateway-set #{node["quantum"]["router"]["main"]["name"]} #{node["quantum"]["net"]["external"]["name"]}"

  not_if "quantum router-show #{node["quantum"]["router"]["main"]["name"]} | grep -q 'network_id'"
end

node["quantum"]["subnets"]["internal"].each do |subnet|
  execute "create_internal_subnet_#{subnet["name"]}" do
    command "quantum subnet-create --name #{subnet["name"]} --allocation-pool start=#{subnet["start"]},end=#{subnet["end"]} --gateway #{subnet["gateway"]} --dns #{subnet["dns"]} #{node["quantum"]["net"]["internal"]["name"]} #{subnet["cidr"]}"

    not_if "quantum subnet-list | grep -q ' #{subnet["name"]} '"
  end
  subnet_id_match=`quantum subnet-show -f shell --variable id #{subnet["name"]}`.match(/^id=\"([0-9a-f\-]+)\"$/)
  unless subnet_id_match.nil?
    subnet_id=subnet_id_match[1]
    execute "associate_internal_network_with_router" do
      command "quantum router-interface-add #{node["quantum"]["router"]["main"]["name"]} #{subnet["name"]}"

      not_if "quantum router-port-list #{node["quantum"]["router"]["main"]["name"]} | grep -q  '#{subnet_id}'"
    end
  end
end



