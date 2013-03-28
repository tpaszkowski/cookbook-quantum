#
# Cookbook Name:: quantum
# Recipe:: ovs-common
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

db_user = node["quantum"]["db"]["username"]
db_pass = db_password "quantum"
sql_connection = db_uri("quantum", db_user, db_pass)

# used for gre tunelling only
local_interface =  node["quantum"]["ovs"]["local_interface"]
interface_node = node["network"]["interfaces"][local_interface]["addresses"]
local_ip = interface_node.select do |address, data|
  data['family'] == "inet"
end[0][0]

["/etc/quantum/plugins/openvswitch"].
each do |i|
  directory i do
    owner "root"
    group node["quantum"]["group"]
    mode  00750
  end
end

template node["quantum"]["openvswitch"]["ini_file"] do
  source "ovs_quantum_plugin.ini.erb"
  owner  "root"
  group  node["quantum"]["group"]
  mode   00640
  variables(
    :sql_connection => sql_connection,
    :local_ip => local_ip,
  )

end
