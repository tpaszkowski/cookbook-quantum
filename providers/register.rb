# Copyright (c) 2013 SUSE LINUX Products GmbH, Nuernberg, Germany.
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

action :create_router do

  _setup_env new_resource
  if _check_quantum_output(["router-list"], new_resource.router_name) > 0
    Chef::Log.info("Router: '#{new_resource.router_name}' dosen't exists.. creating one")
    if _call_quantum(["router-create", new_resource.router_name]) > 0
      Chef::Log.error("Router: '#{new_resource.router_name}' can't be created")
      new_resource.updated_by_last_action(false)
    else
      Chef::Log.info("Router: '#{new_resource.router_name}' created.")
      new_resource.updated_by_last_action(true)
    end
  else
    Chef::Log.info("Router: '#{new_resource.router_name}' already exists.. Not creating.")
    new_resource.updated_by_last_action(false)
  end

end

action :create_network do

  _setup_env new_resource
  if _check_quantum_output(["net-list"], new_resource.network_name) > 0
    Chef::Log.info("Network: '#{new_resource.network_name}' dosen't exists.. creating one")
    params = ["net-create", new_resource.network_name]
    if new_resource.external
      params.push("--router:external=True")
    end
    if new_resource.shared
      params.push("--shared")
    end
    if _call_quantum(params) > 0
      Chef::Log.error("Network: '#{new_resource.network_name}' can't be created")
      new_resource.updated_by_last_action(false)
    else
      Chef::Log.info("Network: '#{new_resource.network_name}' created.")
      new_resource.updated_by_last_action(true)
    end
  else
    Chef::Log.info("Network: '#{new_resource.network_name}' already exists.. Not creating.")
    new_resource.updated_by_last_action(false)
  end

end

action :create_subnet do

  _setup_env new_resource
  if _check_quantum_output(["subnet-list"], new_resource.subnet_name) > 0
    Chef::Log.info("Subnet: '#{new_resource.subnet_name}' dosen't exists.. creating one")
    params = [
              "subnet-create", "--name", new_resource.subnet_name,
              "--gateway", new_resource.gateway,
              "--allocation-pool", "start=#{new_resource.pool_start},end=#{new_resource.pool_end}",
             ]
    if !new_resource.dhcp
      params.push("--disable-dhcp")
    end
    params.push(new_resource.network_name)
    params.push(new_resource.cidr)
    if _call_quantum(params) > 0
      Chef::Log.error("Subnet: '#{new_resource.subnet_name}' can't be created")
      new_resource.updated_by_last_action(false)
    else
      Chef::Log.info("Subnet: '#{new_resource.subnet_name}' created.")
      new_resource.updated_by_last_action(true)
    end
  else
    Chef::Log.info("Subnet: '#{new_resource.subnet_name}' already exists.. Not creating.")
    new_resource.updated_by_last_action(false)
  end

end

action :router_gateway_set do

  _setup_env new_resource
  if _check_quantum_output(["router-show", new_resource.router_name], "network_id") > 0
    Chef::Log.info("Router-gateway-set: '#{new_resource.network_name}' isn't set.. setting one.")
    params = [
              "router-gateway-set", new_resource.router_name,
              new_resource.network_name
             ]
    if _call_quantum(params) > 0
      Chef::Log.error("Router-gateway-set: '#{new_resource.network_name}' can't be set.")
      new_resource.updated_by_last_action(false)
    else
      Chef::Log.info("Router-gateway-set: '#{new_resource.network_name}' set.")
      new_resource.updated_by_last_action(true)
    end
  else
    Chef::Log.info("Router-gateway-set: '#{new_resource.network_name}' already has gateway. Not setting.")
    new_resource.updated_by_last_action(false)
  end

end

action :router_interface_add do

  _setup_env new_resource
  if ::Quantum.subnet_associated(new_resource.subnet_name,
                                  new_resource.router_name)
    Chef::Log.info("Router-interface-add: '#{new_resource.subnet_name}' already has interface associated with router. Not setting.")
    new_resource.updated_by_last_action(false)
  else
    Chef::Log.info("Router-interface-add: '#{new_resource.subnet_name}' isn't associated.. associating one.")
    params = ["router-interface-add", new_resource.router_name, new_resource.subnet_name]
    if _call_quantum(params) > 0
      Chef::Log.error("Router-interface-add: '#{new_resource.subnet_name}' can't be associated with router.")
      new_resource.updated_by_last_action(false)
    else
      Chef::Log.error("Router-interface-add: '#{new_resource.subnet_name}' associated with router.")
      new_resource.updated_by_last_action(true)
    end
  end

end


# setup environment for quantum client tool
def _setup_env resource

  ENV['OS_AUTH_URL']=resource.auth_uri
  ENV['OS_USERNAME']=resource.admin_user
  ENV['OS_TENANT_NAME']=resource.admin_tenant_name
  ENV['OS_PASSWORD']=resource.admin_password

end

# TODO: pure http implementation
# TODO: check if return code if from grep or from quantum
def _check_quantum_output params, pattern

  cmd = params.join(" ")
  system "quantum #{cmd} | grep -q '#{pattern}'"
  return $?.to_i

end

# TODO: pure http implementation
def _call_quantum params

  cmd = params.join(" ")
  print "CMD #{cmd}\n"
  system "quantum #{cmd}"
  return $?.to_i

end
