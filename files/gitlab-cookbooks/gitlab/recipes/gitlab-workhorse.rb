#
# Copyright:: Copyright (c) 2015 GitLab B.V.
# License:: Apache License, Version 2.0
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
account_helper = AccountHelper.new(node)
redis_helper = RedisHelper.new(node)
workhorse_helper = GitlabWorkhorseHelper.new(node)

working_dir = node['gitlab']['gitlab-workhorse']['dir']
log_directory = node['gitlab']['gitlab-workhorse']['log_directory']
gitlab_workhorse_static_etc_dir = "/opt/gitlab/etc/gitlab-workhorse"
workhorse_env_dir = node['gitlab']['gitlab-workhorse']['env_directory']
gitlab_workhorse_socket_dir = workhorse_helper.sockets_directory

directory working_dir do
  owner account_helper.gitlab_user
  group account_helper.web_server_group
  mode '0750'
  recursive true
end

if workhorse_helper.unix_socket?
  directory gitlab_workhorse_socket_dir do
    owner account_helper.gitlab_user
    group account_helper.web_server_group
    mode '0750'
    recursive true
  end
end

directory log_directory do
  owner account_helper.gitlab_user
  mode '0700'
  recursive true
end

directory gitlab_workhorse_static_etc_dir do
  owner account_helper.gitlab_user
  mode '0700'
  recursive true
end

env_dir workhorse_env_dir do
  variables node['gitlab']['gitlab-workhorse']['env']
  notifies :restart, "runit_service[gitlab-workhorse]"
end

runit_service 'gitlab-workhorse' do
  start_down node['gitlab']['gitlab-workhorse']['ha']
  options({
    log_directory: log_directory,
    found_orphan_socket: workhorse_helper.orphan_socket?,
    orphan_socket_path: workhorse_helper.orphan_socket
  }.merge(params))
  log_options node['gitlab']['logging'].to_hash.merge(node['gitlab']['gitlab-workhorse'].to_hash)
end

consul_service 'workhorse' do
  action Prometheus.service_discovery_action
  socket_address node['gitlab']['gitlab-workhorse']['prometheus_listen_addr']
  reload_service false unless node['consul']['enable']
end

version_file 'Create version file for Workhorse' do
  version_file_path File.join(working_dir, 'VERSION')
  version_check_cmd '/opt/gitlab/embedded/bin/gitlab-workhorse --version'
  notifies :restart, "runit_service[gitlab-workhorse]"
end

_redis_host, _redis_port, redis_password = redis_helper.redis_params
redis_url = redis_helper.redis_url.to_s
redis_sentinels = node['gitlab']['gitlab-rails']['redis_sentinels']
redis_sentinel_master = node['redis']['master_name']
redis_sentinel_master_password = node['redis']['master_password']
config_file_path = File.join(working_dir, "config.toml")
object_store = node['gitlab']['gitlab-rails']['object_store']
provider = object_store.dig('connection', 'provider')
object_store_provider = provider if %w(AWS AzureRM).include?(provider)

template config_file_path do
  source "workhorse-config.toml.erb"
  owner "root"
  group account_helper.gitlab_group
  mode "0640"
  variables(object_store: object_store, object_store_provider: object_store_provider, redis_url: redis_url, password: redis_password, sentinels: redis_sentinels, sentinel_master: redis_sentinel_master, master_password: redis_sentinel_master_password)
  notifies :restart, "runit_service[gitlab-workhorse]"
  notifies :run, 'bash[Set proper security context on ssh files for selinux]', :delayed if SELinuxHelper.enabled?
end
