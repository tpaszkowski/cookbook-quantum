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

actions :create_router, :create_network, :create_subnet,
  :router_gateway_set, :router_interface_add

Boolean = [TrueClass, FalseClass]

# keystone authentication parameters
attribute :auth_uri, :kind_of => String, :required => true
attribute :admin_user, :kind_of => String, :required => true
attribute :admin_password, :kind_of => String, :required => true
attribute :admin_tenant_name, :kind_of => String, :required => true

attribute :name, :kind_of => String

# :router_create, :router_interface_add
attribute :router_name, :kind_of => String
# :network_create, :subnet_create, :router_gateway_set
attribute :network_name, :kind_of => String
# :network_create
attribute :external, :kind_of => Boolean, :default => false
attribute :shared, :kind_of => Boolean, :default => false
# :subnet_create, :router_interface_add
attribute :subnet_name, :kind_of => String
# :subnet_create
attribute :dhcp, :kind_of => Boolean, :default => true
attribute :dns, :kind_of => Array
attribute :gateway, :kind_of => String
attribute :pool_start, :kind_of => String
attribute :pool_end, :kind_of => String
attribute :cidr, :kind_of => String
