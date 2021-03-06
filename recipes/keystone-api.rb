#
# Cookbook Name:: keystone
# Recipe:: server
#
# Copyright 2012, Rackspace US, Inc.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

::Chef::Recipe.send(:include, Opscode::OpenSSL::Password)
include_recipe "keystone::keystone-rsyslog"
include_recipe "osops-utils"
include_recipe "monitoring"

if not node['package_component'].nil?
  release = node['package_component']
else
  release = "essex-final"
end

platform_options = node["keystone"]["platform"]

platform_options["keystone_packages"].each do |pkg|
  package pkg do
    action :install
    options platform_options["package_options"]
  end
end

platform_options["keystone_ldap_packages"].each do |pkg|
  package pkg do
    action :install
    options platform_options["package_options"]
  end
end

service "keystone" do
  service_name platform_options["keystone_service"]
  supports :status => true, :restart => true
  action [ :enable ]
end

monitoring_procmon "keystone" do
  procname=platform_options["keystone_service"]
  sname=platform_options["keystone_process_name"]
  process_name sname
  script_name procname
end

monitoring_metric "keystone-proc" do
  type "proc"
  proc_name "keystone"
  proc_regex platform_options["keystone_service"]
  alarms(:failure_min => 2.0)
end

directory "/etc/keystone" do
  action :create
  owner "root"
  group "root"
  mode "0755"
end

ks_admin_endpoint = get_bind_endpoint("keystone", "admin-api")
ks_service_endpoint = get_bind_endpoint("keystone", "service-api")
keystone = get_settings_by_role("keystone", "keystone")
mysql_info = get_access_endpoint("mysql-master", "mysql", "db")


template "/etc/keystone/keystone.conf" do
  source "#{release}/keystone.conf.erb"
  owner "root"
  group "root"
  mode "0644"

  variables(
            :debug => keystone["debug"],
            :verbose => keystone["verbose"],
            :user => keystone["db"]["username"],
            :passwd => keystone["db"]["password"],
            :ip_address => ks_admin_endpoint["host"],
            :db_name => keystone["db"]["name"],
            :db_ipaddress => mysql_info["host"],
            :service_port => ks_service_endpoint["port"],
            :admin_port => ks_admin_endpoint["port"],
            :admin_token => keystone["admin_token"],
            :use_syslog => keystone["syslog"]["use"],
            :log_facility => keystone["syslog"]["facility"],
            :auth_type => keystone["auth_type"],
            :ldap_options => keystone["ldap"]
            )
  notifies :restart, resources(:service => "keystone"), :immediately
end


file "/var/lib/keystone/keystone.db" do
  action :delete
end

template "/etc/keystone/logging.conf" do
  source "keystone-logging.conf.erb"
  owner "root"
  group "root"
  mode "0644"
  notifies :restart, resources(:service => "keystone"), :immediately
end

include_recipe "keystone::keystoneclient-patch"
