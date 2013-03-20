#
# Cookbook Name:: quantum
# Recipe:: common
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

class ::Chef::Recipe
  include ::Openstack
end

quantum_endpoint = endpoint "quantum"
if node["quantum"]["bind_interface"].nil?
  bind_address = quantum_endpoint.host
else
  bind_address = node["network"]["ipaddress_#{node["quantum"]["bind_interface"]}"]
end

platform_options = node["quantum"]["platform"]

platform_options["quantum_common_packages"].each do |pkg|
  package pkg do
    action :upgrade
  end
end

directory ::File.dirname(node["quantum"]["server"]["auth"]["cache_dir"]) do
  owner node["quantum"]["user"]
  group node["quantum"]["group"]
  mode 00700
end

directory "/etc/quantum" do
  owner "root"
  group node["quantum"]["group"]
  mode  00750
end

template "/etc/quantum/quantum.conf" do
  source "quantum.conf.erb"
  owner  "root"
  group  node["quantum"]["group"]
  mode   00640
  variables(
    :bind_address => bind_address,
    :bind_port => quantum_endpoint.port,
  )

end

template "/etc/quantum/api-paste.ini" do
  source "api-paste.ini.erb"
  owner  "root"
  group  node["quantum"]["group"]
  mode   00640

end
