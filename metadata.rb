name              "quantum"
maintainer       "SUSE LINUX Products GmbH, Nuernberg, Germany."
maintainer_email "tpaszkowski@suse.com"
license          "All rights reserved"
description      "Installs/Configures quantum"
long_description IO.read(File.join(File.dirname(__FILE__), 'README.md'))
version          "0.1.0"

recipe           "quantum::db", "Configures db for quantum stuff"
recipe           "quantum::common", "Configures common stuff for quantum tools"
recipe           "quantum::server", "Configures quantum api server"


%w{ suse }.each do |os|
  supports os
end

depends          "database"
depends          "mysql"
depends          "openstack-common", ">= 0.1.7"
