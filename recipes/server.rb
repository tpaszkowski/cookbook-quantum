#
# Cookbook Name:: quantum
# Recipe:: server
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

platform_options = node["quantum"]["platform"]

identity_admin_endpoint = endpoint "identity-admin"

db_user = node["quantum"]["db"]["username"]
db_pass = db_password "quantum"
sql_connection = db_uri("quantum", db_user, db_pass)

quantum = config_by_role node["quantum"]["keystone_service_chef_role"], "keystone"

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

quantum_endpoint = endpoint "quantum"

package "curl" do
  action :install
end

platform_options["mysql_python_packages"].each do |pkg|
  package pkg do
    action :install
  end
end

platform_options["quantum_server_packages"].each do |pkg|
  package pkg do
    action :upgrade
  end
end

directory ::File.dirname(node["quantum"]["server"]["auth"]["cache_dir"]) do
  owner node["quantum"]["user"]
  group node["quantum"]["group"]
  mode 00700
end

service "quantum-server" do
  service_name platform_options["quantum_server_service"]
  supports :status => true, :restart => true

  action [:enable, :start]
end

# Register Service Tenant
keystone_register "Register Service Tenant" do
  auth_uri auth_uri
  admin_user ksadmin_user
  admin_tenant_name ksadmin_tenant_name
  admin_password ksadmin_pass
  tenant_name service_tenant_name
  tenant_description "Service Tenant"
  tenant_enabled true # Not required as this is the default

  action :create_tenant
end

# Register Service User
keystone_register "Register #{service_user} User" do
  auth_uri auth_uri
  admin_user ksadmin_user
  admin_tenant_name ksadmin_tenant_name
  admin_password ksadmin_pass
  tenant_name service_tenant_name
  user_name service_user
  user_pass service_pass
  user_enabled true # Not required as this is the default

  action :create_user
end

## Grant Admin role to Service User for Service Tenant ##
keystone_register "Grant '#{service_role}' Role to #{service_user} User for #{service_tenant_name} Tenant" do
  auth_uri auth_uri
  admin_user ksadmin_user
  admin_tenant_name ksadmin_tenant_name
  admin_password ksadmin_pass
  tenant_name service_tenant_name
  user_name service_user
  role_name service_role

  action :grant_role
end

["/etc/quantum", "/etc/quantum/plugins", "/etc/quantum/plugins/openvswitch"].
each do |i|
  directory i do
    owner "root"
    group node["quantum"]["group"]
    mode  00750
  end
end

if node["quantum"]["bind_interface"].nil?
  bind_address = quantum_endpoint.host
else
  bind_address = node["network"]["ipaddress_#{node["quantum"]["bind_interface"]}"]
end
# used for gre tunelling only
local_ip = node["network"]["ipaddress_#{node["quantum"]["ovs"]["local_interface"]}"]


template "/etc/quantum/quantum.conf" do
  source "quantum.conf.erb"
  owner  "root"
  group  node["quantum"]["group"]
  mode   00640
  variables(
    :bind_address => bind_address,
    :bind_port => quantum_endpoint.port,
    :identity_endpoint => identity_admin_endpoint,
    :service_pass => service_pass
  )

  notifies :restart, "service[quantum-server]", :immediately
end

template "/etc/quantum/api-paste.ini" do
  source "api-paste.ini.erb"
  owner  "root"
  group  node["quantum"]["group"]
  mode   00640

  notifies :restart, "service[quantum-server]", :immediately
end

template "/etc/quantum/plugins/openvswitch/ovs_quantum_plugin.ini" do
  source "ovs_quantum_plugin.ini.erb"
  owner  "root"
  group  node["quantum"]["group"]
  mode   00640
  variables(
    :sql_connection => sql_connection,
    :local_ip => local_ip,
  )

  notifies :restart, "service[quantum-server]", :immediately
end
