#
# Cookbook Name:: quantum
# Recipe:: db
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

# This recipe should be placed in the run_list of the node that
# runs the database server that houses the Nova main database

class ::Chef::Recipe
  include ::Openstack
end

include_recipe("mysql::client")
include_recipe("mysql::ruby")

db_pass = db_password "quantum"

db_create_with_user("quantum", node["quantum"]["db"]["username"], db_pass)
