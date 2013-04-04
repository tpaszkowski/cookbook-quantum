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

class ::Chef::Recipe
  include ::Openstack
end

identity_admin_endpoint = endpoint "identity-admin"

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

quantum_register "create router" do
  auth_uri auth_uri
  admin_user ksadmin_user
  admin_tenant_name ksadmin_tenant_name
  admin_password ksadmin_pass
  router_name node["quantum"]["router"]["main"]["name"]

  action :create_router
end

quantum_register "create external network" do
  auth_uri auth_uri
  admin_user ksadmin_user
  admin_tenant_name ksadmin_tenant_name
  admin_password ksadmin_pass
  external true
  network_name node["quantum"]["net"]["external"]["name"]

  action :create_network
end

quantum_register "create internal network" do
  auth_uri auth_uri
  admin_user ksadmin_user
  admin_tenant_name ksadmin_tenant_name
  admin_password ksadmin_pass
  network_name node["quantum"]["net"]["internal"]["name"]

  action :create_network
end

node["quantum"]["subnets"]["external"].each do |subnet|
  quantum_register "create external subnet #{subnet["name"]}" do
    auth_uri auth_uri
    admin_user ksadmin_user
    admin_tenant_name ksadmin_tenant_name
    admin_password ksadmin_pass
    dhcp false
    network_name node["quantum"]["net"]["external"]["name"]
    subnet_name subnet["name"]
    cidr subnet["cidr"]
    gateway subnet["gateway"]
    pool_start subnet["start"]
    pool_end subnet["end"]

    action :create_subnet
  end
end

quantum_register "router gateway set for external network" do
  auth_uri auth_uri
  admin_user ksadmin_user
  admin_tenant_name ksadmin_tenant_name
  admin_password ksadmin_pass
  network_name node["quantum"]["net"]["external"]["name"]
  router_name node["quantum"]["router"]["main"]["name"]

  action :router_gateway_set
end

node["quantum"]["subnets"]["internal"].each do |subnet|
  quantum_register "create internal subnet #{subnet["name"]}" do
    auth_uri auth_uri
    admin_user ksadmin_user
    admin_tenant_name ksadmin_tenant_name
    admin_password ksadmin_pass
    dhcp true
    shared true
    network_name node["quantum"]["net"]["internal"]["name"]
    subnet_name subnet["name"]
    cidr subnet["cidr"]
    gateway subnet["gateway"]
    pool_start subnet["start"]
    pool_end subnet["end"]

    action :create_subnet
  end
  quantum_register "router interface add #{subnet["name"]}" do
    auth_uri auth_uri
    admin_user ksadmin_user
    admin_tenant_name ksadmin_tenant_name
    admin_password ksadmin_pass
    subnet_name subnet["name"]
    router_name node["quantum"]["router"]["main"]["name"]

    action :router_interface_add
  end
end
