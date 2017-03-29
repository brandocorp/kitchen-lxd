# -*- encoding: utf-8 -*-
#
# Author:: Brandon Raabe (<brandocorp@gmail.com>)
#
# Copyright (C) 2017, Brandon Raabe
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
require 'tempfile'
require 'kitchen'
require 'mixlib/shellout'
require 'kitchen/driver/lxd/lxc'

module Kitchen
  module Driver

    # Lxd driver for Kitchen.
    #
    # @author Brandon Raabe <brandocorp@gmail.com>
    class Lxd < Kitchen::Driver::SSHBase

      default_config :username, 'ubuntu'
      default_config :client_cert
      default_config :client_key

      attr_reader :client

      def username
        config[:username]
      end

      def create(state)
        create_container unless container_exists?
        
	unless container_status =~ /running/i
	  start_container
	end
	
        wait_for_container 
        configure_ssh
        update_state(state)

        instance.transport.connection(state).wait_until_ready
      end

      def destroy(state)
        stop_container if container_exists? && running?
        delete_container if container_exists?
      end

      private

      def running?
        container_status == 'running'
      end

      def stopped?
        container_status == 'stopped'
      end

      def wait_for_container
	return if running? 
	10.times do
	  sleep 6 
	  return if running?
	end

	raise "Container failed to start in 30s"
      end

      def client
        @client ||= LXC.new
      end

      def container_exists?
        client.list(container_name).first || false
      end

      def container_name
        instance.name
      end

      def create_container
        image = instance.platform.name
        client.launch(container_name, image)
      end

      def start_container
        client.start(container_name)
      end

      def container_status
        container_state['status'].downcase
      end

      def stop_container
        client.stop(container_name)
      end

      def delete_container
        client.delete(container_name)
      end

      def update_state(state)
        cs = container_state
        state[:name] = cs['name']
        state[:hostname] = first_ipv4_address(cs)
        state[:ssh_key] ||= config[:ssh_key]
        state[:username] ||= username
      end

      def first_ipv4_address(state)
        address = nil
        ifaces = state['network'].select {|net, data| data['type'] != 'loopback' }
        ifaces.each do |iface, data|
          data['addresses'].each do |addr|
            address = addr['address'] if addr['family'] == 'inet'
            debug "Found #{address} for #{container_name}"
            break
          end
        end
        address
      end

      def container_state
        data = client.list(container_name).first
	data['state']
      end

      def configure_ssh
        debug "Configuring SSH for #{container_name}"

        if config[:ssh_key] && ::File.exist?(config[:ssh_key])
          copy_keypair
	else
	  raise 'No SSH key provided'
	end
      end

      def copy_keypair
        debug "Creating new keypair on #{container_name}"
        destination = "/home/#{username}/.ssh/authorized_keys"
	private_key = OpenSSL::PKey::RSA.new(File.read(config[:ssh_key]))
	public_key = [ private_key.to_blob ].pack("m0")

	client.exec(container_name, "test -f #{destination} || touch #{destination}")
	client.exec(container_name, "echo 'ssh-rsa #{public_key}' > #{destination}")
        client.exec(container_name, "chown -R #{username}:#{username} #{destination}")	
      end

      def run(cmd)
        client.exec(container_name, cmd)
      end
    end
  end
end
