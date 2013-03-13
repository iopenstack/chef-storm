#
# Cookbook Name:: storm
# Recipe:: default
#
# Copyright 2012, Webtrends, Inc.
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

include_recipe "java"
include_recipe "zip"
include_recipe "runit"

if ENV["deploy_build"] == "true" then
  log "The deploy_build value is true so un-deploy first"
  include_recipe "storm::undeploy-default"
end

# install dependency packages
ark 'zeromq' do
  url 'https://github.com/zeromq/zeromq2-x/archive/v2.1.7.tar.gz'
end

ark 'jzmq' do
  url 'https://github.com/zeromq/jzmq/archive/v2.1.0.zip'
end


%w{unzip python}.each do |pkg|
  package pkg do
    action :install
  end
end

# search
storm_nimbus = search(:node, "role:storm_nimbus AND storm_cluster_role:#{node['storm']['cluster_role']} AND chef_environment:#{node.chef_environment}").first

# search for zookeeper servers
zookeeper_quorum = Array.new
search(:node, "role:#{node['storm']['zookeeper']['search_role']} AND chef_environment:#{node.chef_environment}").each do |n|
	zookeeper_quorum << n[:fqdn]
end

install_dir = "#{node['storm']['install_dir']}/storm-#{node['storm']['version']}"

# setup storm group
group "storm"

# setup storm user
user "storm" do
  comment "Storm user"
  gid "storm"
  shell "/bin/bash"
  home "/home/storm"
  supports :manage_home => true
end

# setup directories
%w{install_dir local_dir log_dir}.each do |name|
  directory node['storm'][name] do
    owner "storm"
    group "storm"
    action :create
    recursive true
  end
end

# download storm
remote_file "#{Chef::Config[:file_cache_path]}/storm-#{node[:storm][:version]}.zip" do
  source "https://github.com/downloads/nathanmarz/storm/storm-#{node['storm']['version']}.zip"
  owner  "storm"
  group  "storm"
  mode   00744
  not_if "test -f #{Chef::Config[:file_cache_path]}/storm-#{node['storm']['version']}.zip"
end

# uncompress the application tarball into the install directory
execute "unzip" do
  user    "storm"
  group   "storm"
  creates "#{node['storm']['install_dir']}/storm-#{node['storm']['version']}"
  cwd     "#{node['storm']['install_dir']}"
  command "unzip #{Chef::Config[:file_cache_path]}/storm-#{node['storm']['version']}.zip"
end

# create a link from the specific version to a generic current folder
link "#{node['storm']['install_dir']}/current" do
	to "#{node['storm']['install_dir']}/storm-#{node['storm']['version']}"
end

# storm.yaml
template "#{node['storm']['install_dir']}/storm-#{node['storm']['version']}/conf/storm.yaml" do
  source "storm.yaml.erb"
  mode 00644
  variables(
    :nimbus => storm_nimbus,
    :zookeeper_quorum => zookeeper_quorum
  )
end

# sets up storm users profile
template "/home/storm/.profile" do
  owner  "storm"
  group  "storm"
  source "profile.erb"
  mode   00644
  variables(
    :storm_dir => "#{node['storm']['install_dir']}/storm-#{node['storm']['version']}"
  )
end

template "#{install_dir}/bin/killstorm" do
  source  "killstorm.erb"
  owner "root"
  group "root"
  mode  00755
  variables({
    :log_dir => node['storm']['log_dir']
  })
end
