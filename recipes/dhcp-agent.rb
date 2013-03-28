#
# Cookbook Name:: quantum
# Recipe:: dhcp-agent
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

platform_options = node["quantum"]["platform"]
platform_options["quantum_dhcp_agent_packages"].each do |pkg|
  package pkg do
    action :upgrade
  end
end

include_recipe("quantum::common")

template node["quantum"]["dhcp-agent"]["ini_file"] do
  source "dhcp_agent.ini.erb"
  owner  "root"
  group  node["quantum"]["group"]
  mode   00640

end

service "quantum-dhcp-agent" do
  service_name platform_options["quantum_dhcp_agent_service"]
  supports :status => true, :restart => true
  subscribes :restart, resources("template[/etc/quantum/quantum.conf]")
  subscribes :restart, resources("template[#{node["quantum"]["dhcp-agent"]["ini_file"]}]")

  action [:enable, :start]
end
