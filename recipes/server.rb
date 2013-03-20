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

unless node["roles"].include?(node["quantum"]["quantum_service_chef_role"])
  Chef::Log.fatal!("Quantum::server recipie is called on a node which not assigned quantum role !")
end

class ::Chef::Recipe
  include ::Openstack
  include ::Opscode::OpenSSL::Password
end



identity_admin_endpoint = endpoint "identity-admin"

db_user = node["quantum"]["db"]["username"]
db_pass = db_password "quantum"
sql_connection = db_uri("quantum", db_user, db_pass)

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

# used for gre tunelling only
local_ip = node["network"]["ipaddress_#{node["quantum"]["ovs"]["local_interface"]}"]

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

platform_options = node["quantum"]["platform"]
# we need this stuff for playing with keystone
platform_options["keystone_python_packages"].each do |pkg|
  package pkg do
    action :upgrade
  end
end
# we need this stuff for connecting to mysql database
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

# Register Quantum Service
keystone_register "Register Quantum Service" do
  auth_uri auth_uri
  admin_user ksadmin_user
  admin_tenant_name ksadmin_tenant_name
  admin_password ksadmin_pass
  service_name "quantum"
  service_type "network"
  service_description "Openstack Quantum Service"

  action :create_service
end

# Register Image Endpoint
keystone_register "Register Quantum Endpoint" do
  auth_uri auth_uri
  admin_user ksadmin_user
  admin_tenant_name ksadmin_tenant_name
  admin_password ksadmin_pass
  service_type "network"
  endpoint_region node["quantum"]["region"]
  endpoint_adminurl quantum_endpoint.to_s
  endpoint_internalurl quantum_endpoint.to_s
  endpoint_publicurl quantum_endpoint.to_s

  action :create_endpoint
end

["/etc/quantum", "/etc/quantum/plugins", "/etc/quantum/plugins/openvswitch"].
each do |i|
  directory i do
    owner "root"
    group node["quantum"]["group"]
    mode  00750
  end
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

  notifies :restart, "service[quantum-server]"
end

template "/etc/quantum/api-paste.ini" do
  source "api-paste.ini.erb"
  owner  "root"
  group  node["quantum"]["group"]
  mode   00640

  notifies :restart, "service[quantum-server]"
end

#
# cfg file generation for plugins
#
case node["quantum"]["interface_plugin"]
when "openvswitch"
  template node["quantum"]["openvswitch"]["ini_file"] do
    source "ovs_quantum_plugin.ini.erb"
    owner  "root"
    group  node["quantum"]["group"]
    mode   00640
    variables(
      :sql_connection => sql_connection,
      :local_ip => local_ip,
    )

    notifies :restart, "service[quantum-server]"
  end
  template "/etc/sysconfig/quantum" do
    source "etc.sysconfig.quantum.erb"
    owner  "root"
    group  "root"
    mode   00644
    variables(
      :ini_file => node["quantum"]["openvswitch"]["ini_file"]
    )

    notifies :restart, "service[quantum-server]"
  end
end

service "quantum-server" do
  service_name platform_options["quantum_server_service"]
  supports :status => true, :restart => true

  action [:enable, :start]
end
