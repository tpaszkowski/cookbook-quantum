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
  include ::Opscode::OpenSSL::Password
end



identity_admin_endpoint = endpoint "identity-admin"

quantum_endpoint = endpoint "quantum"

if node["quantum"]["bind_interface"].nil?
  bind_address = quantum_endpoint.host
else
  bind_interface =  node["quantum"]["bind_interface"]
  interface_node = node["network"]["interfaces"][bind_interface]["addresses"]
  bind_address = interface_node.select do |address, data|
    data['family'] == "inet"
  end[0][0]
end

# Instead of the search to find the keystone service, put this
# into openstack-common as a common attribute?
keystone = config_by_role node["quantum"]["keystone_service_chef_role"], "keystone"

# Instead of the search to find the keystone service, put this
# into openstack-common as a common attribute?
ksadmin_user = keystone["admin_user"]
ksadmin_tenant_name = keystone["admin_tenant_name"]
ksadmin_pass = user_password ksadmin_user
auth_uri = ::URI.decode identity_admin_endpoint.to_s
service_pass = service_password "quantum"
service_tenant_name = node["quantum"]["service_tenant_name"]
service_user = node["quantum"]["service_user"]
service_role = node["quantum"]["service_role"]

["/etc/quantum", "/etc/quantum/plugins"].
each do |i|
  directory i do
    owner "root"
    group node["quantum"]["group"]
    mode  00750
  end
end

directory "/var/lib/quantum" do
  owner "root"
  group node["quantum"]["group"]
  mode  00775
end

rabbit_info = config_by_role node["quantum"]["rabbit_server_chef_role"], "queue"
rabbit_host = rabbit_info["host"] || node["quantum"]["rabbit_host"]
rabbit_port = rabbit_info["port"] || node["quantum"]["rabbit_port"]
rabbit_userid = rabbit_info["username"] || node["quantum"]["rabbit_userid"]
rabbit_virtual_host = rabbit_info["vhost"] || node["quantum"]["rabbit_virtual_host"]
# FIXME: rabbit passwords should be hanlded using opnestack-common libraries
rabbit_password = node["quantum"]["rabbit_password"]

template "/etc/quantum/quantum.conf" do
  source "quantum.conf.erb"
  owner  "root"
  group  node["quantum"]["group"]
  mode   00640
  variables(
    :bind_address => bind_address,
    :bind_port => quantum_endpoint.port,
    :identity_endpoint => identity_admin_endpoint,
    :service_pass => service_pass,
    :rabbit_host => rabbit_host,
    :rabbit_port => rabbit_port,
    :rabbit_userid => rabbit_userid,
    :rabbit_virtual_host => rabbit_virtual_host,
    :rabbit_password => rabbit_password
  )

end

template "/etc/quantum/api-paste.ini" do
  source "api-paste.ini.erb"
  owner  "root"
  group  node["quantum"]["group"]
  mode   00640

end
