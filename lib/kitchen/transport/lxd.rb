require 'kitchen'
require 'websocket/driver'

module Kitchen
  module Transport
    class Lxd < Transport::Base

      kitchen_transport_api_version 2

      default_config :api_endpoint, 'https://localhost:8443'
      default_config :verify_ssl, false
      default_config :client_cert
      default_config :client_key

      # Create a new transport by providing a configuration hash.
      #
      # @param config [Hash] initial provided configuration
      def initialize(config = {})
        init_config(config)
      end

      # Creates a new Connection, configured by a merging of configuration
      # and state data. Depending on the implementation, the Connection could
      # be saved or cached to speed up multiple calls, given the same state
      # hash as input.
      #
      # @param state [Hash] mutable instance state
      # @return [Connection] a connection for this transport
      # @raise [TransportFailed] if a connection could not be returned
      def connection(state)
        @connection = build_connection(state)
      end

      def build_connection(state)
        Kitchen::Transport::Lxd::Connection.new(state)
      end


      # A Connection instance can be generated and re-generated, given new
      # connection details such as connection port, hostname, credentials, etc.
      # This object is responsible for carrying out the actions on the remote
      # host such as executing commands, transferring files, etc.
      #
      # @author Fletcher Nichol <fnichol@nichol.ca>
      class Connection
        include Logging

        # Create a new Connection instance.
        #
        # @param options [Hash] connection options
        # @yield [self] yields itself for block-style invocation
        def initialize(options = {})
          init_options(options)

          yield self if block_given?
        end

        # Closes the session connection, if it is still active.
        def close
          # this method may be left unimplemented if that is applicable
        end

        # Execute a command on the remote host.
        #
        # @param command [String] command string to execute
        # @raise [TransportFailed] if the command does not exit successfully,
        #   which may vary by implementation
        def execute(command)
          logger.debug("[#{self.class}] #{self} (#{command})")
          exit_code = execute_with_exit(env_command(command))
          if exit_code != 0
            raise TransportFailed, "[#{name}] exited (#{exit_code}) for command: [#{command}]"
          end
        end

        # Execute a command on the remote host and retry
        #
        # @param command [String] command string to execute
        # @param retryable_exit_codes [Array] Array of exit codes to retry against
        # @param max_retries [Fixnum] maximum number of retry attempts
        # @param wait_time [Fixnum] number of seconds to wait before retrying command
        # @raise [TransportFailed] if the command does not exit successfully,
        #   which may vary by implementation
        def execute_with_retry(command, retryable_exit_codes = [], max_retries = 1, wait_time = 30)
          tries = 0
          begin
            tries += 1
            debug("Attempting to execute command - try #{tries} of #{max_retries}.")
            execute(command)
          rescue Kitchen::Transport::TransportFailed => e
            if retry?(tries, max_retries, retryable_exit_codes, e.exit_code)
              close
              sleep wait_time
              retry
            else
              raise e
            end
          end
        end

        def retry?(current_try, max_retries, retryable_exit_codes, exit_code)
          current_try <= max_retries &&
            !retryable_exit_codes.nil? &&
            retryable_exit_codes.include?(exit_code)
        end

        # Builds a LoginCommand which can be used to open an interactive
        # session on the remote host.
        #
        # @return [LoginCommand] an object containing the array of command line
        #   tokens and exec options to be used in a fork/exec
        # @raise [ActionFailed] if the action could not be completed
        def login_command
          driver = WebSocket::Driver.client(socket, options)
          session.execute_command(
            hostname,
            '/bin/bash',
            interactive: true,
            width: 80,
            height: 25
          )
        end

        # Uploads local files or directories to remote host.
        #
        # @param locals [Array<String>] paths to local files or directories
        # @param remote [String] path to remote destination
        # @raise [TransportFailed] if the files could not all be uploaded
        #   successfully, which may vary by implementation
        def upload(locals, remote) # rubocop:disable Lint/UnusedMethodArgument
          raise ClientError, "#{self.class}#upload must be implemented"
        end

        # Block and return only when the remote host is prepared and ready to
        # execute command and upload files. The semantics and details will
        # vary by implementation, but a round trip through the hosted
        # service is preferred to simply waiting on a socket to become
        # available.
        def wait_until_ready
          # this method may be left unimplemented if that is applicable
        end

        private

        # @return [Kitchen::Logger] a logger
        # @api private
        attr_reader :logger

        # @return [Hash] connection options
        # @api private
        attr_reader :options

        # Initialize incoming options for use by the object.
        #
        # @param options [Hash] configuration options
        def init_options(options)
          @options = options.dup
          @logger = @options.delete(:logger) || Kitchen.logger
        end
      end

      class Connection

        def login_command
        end

        def upload(locals, remote)
          local.each do |path|
            session.write_file(
              hostname,
              remote,
              mode: 644,
              owner: 1000,
              group: 1000,
              content: File.read(path)
            )
          end
        end

        def wait_until_ready
          logger.info "Waiting for container #{hostname} to be ready..."
          elapsed = Benchmark.measure do
            iterations = 10
            while container_status !~ /running/i
              raise TransportFailed, 'Took too long' if iterations == 0
              iterations -= 1
              sleep 3
            end
          end
          logger.debug("[#{self.class}] wait_until_ready #{elapsed.real}")
        end

        private

        def execute_with_exit(command, exit_code)
          result = session.execute_command(command)
          result.metadata.return
        end

        def session
          @session ||= establish_connection
        end

        def container_status
          container_state.status.downcase
        end

        def container_state
          session.container_state(hostname)
        end

        def establish_connection
          Hyperkit::Client.new(client_options)
        end

        def client_options
          {}.tap do |opts|
            opts[:verify_ssl] = options[:verify_ssl]
            opts[:api_endpoint] = options[:api_endpoint] if options[:api_endpoint]
            opts[:client_cert] = options[:client_cert] if options[:client_cert]
            opts[:client_key] = options[:client_key] if options[:client_key]
          end
        end
      end
    end
  end
end
