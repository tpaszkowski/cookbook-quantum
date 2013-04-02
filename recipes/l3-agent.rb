#
# Cookbook Name:: quantum
# Recipe:: l3-agent
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

# l3-agent needs to be deployed together with metadata-agent on the same system.
#
# l3-agent starts quantum-ns-metadata-proxy processs for each handled network.
# quantum-ns-metadata-proxy accept metadata requests on IP socket and forwards
# them over local unix socket. quantum-metadata-agent accept those requests
# and forwards them to metadata-api over IP socket. 

platform_options = node["quantum"]["platform"]
platform_options["quantum_l3_agent_packages"].each do |pkg|
  package pkg do
    action :upgrade
  end
end
# we need to proxy metadata requests from namespaces
platform_options["quantum_metadata_agent_packages"].each do |pkg|
  package pkg do
    action :upgrade
  end
end

include_recipe("quantum::common")

template node["quantum"]["l3-agent"]["ini_file"] do
  source "l3_agent.ini.erb"
  owner  "root"
  group  node["quantum"]["group"]
  mode   00640

end

metadata_endpoint = endpoint "metadata-api"
metadata_secret = service_password "metadata-api"
service_pass = service_password "quantum"
identity_endpoint = endpoint "identity-api"

template node["quantum"]["metadata-agent"]["ini_file"] do
  source "metadata_agent.ini.erb"
  owner  "root"
  group  node["quantum"]["group"]
  mode   00640

  variables(
    :metadata_ip => metadata_endpoint.host,
    :metadata_port => metadata_endpoint.port,
    :metadata_secret => metadata_secret,
    :service_pass => service_pass,
    :identity_endpoint => identity_endpoint
  )

end

service "quantum-l3-agent" do
  service_name platform_options["quantum_l3_agent_service"]
  supports :status => true, :restart => true
  subscribes :restart, resources("template[/etc/quantum/quantum.conf]")
  subscribes :restart, resources("template[#{node["quantum"]["l3-agent"]["ini_file"]}]")

  action [:enable, :start]
end

service "quantum-metadata-agent" do
  service_name platform_options["quantum_metadata_agent_service"]
  supports :status => true, :restart => true
  subscribes :restart, resources("template[/etc/quantum/quantum.conf]")
  subscribes :restart, resources("template[#{node["quantum"]["metadata-agent"]["ini_file"]}]")

  action [:enable, :start]
end
