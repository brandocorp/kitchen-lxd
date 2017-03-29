require 'json'
require 'mixlib/shellout'

module Kitchen
  module Driver

    # LXC CLI
    #
    # @author Brandon Raabe <brandocorp@gmail.com>
    class LXC
      
      attr_reader :binary
      attr_accessor :remote
      
      def initialize
        @binary = run('which', 'lxc').strip
	@remote = 'local'
      end

      def delete(container, snapshot=nil)
        target = [remote, container].join(':')
	target = File.join(target, snapshot) unless snapshot.nil?
        
	args = [
          binary,
	  'delete',
	  target,
	]
	output = run(args)
      end

      def exec(container, command, options={})
        args = [
	  binary,
	  'exec',
	  "#{remote}:#{container}",
	  '--mode=non-interactive',
          '--',
	  %(bash -c "#{command}"),
	]
	run(args, live_stream: $stdout)
      end

      def file_pull(container, target, destination)
        args = [
	  binary,
	  'file',
	  'pull',
	  "#{remote}:#{container}#{target}",
	  destination,
	]

	output = run(args)
      end

      def file_push(container, target, destination, options = {})
      	args = [
	  binary,
	  'file',
	  'push',
	]

	[:uid, :gid, :mode].each do |opt|
	  next unless options.fetch(opt, nil)
	  args << "--#{opt}"
	  args << options[opt]
        end

	args << target
	args << "#{remote}:#{container}#{destination}"
	
	output = run(args)
      end

      def launch(container, image, options = {})
      	args = [
	  binary,
	  'launch',
	  image,
	  "#{remote}:#{container}",
	]

        args << '--ephemeral' if options.fetch(:ephemeral, nil)

	if options.fetch(:profiles, nil)
	  options[:profiles].each do |profile|
            args << '--profile'
	    args << profile
	  end
	end

	if options.fetch(:config, nil)
	  options[:config].each do |key, value|
	    args << '--config'
	    args << "#{key}=#{value}"
	  end
	end
        run(args, live_stream: $stdout)
      end

      def list(filter = nil)
	args = [
	  binary,
	  'list',
	  "#{remote}:",
	  filter,
	  '--format',
	  'json',
	]
	output = run(args)
	JSON.parse output
      end

      [:start, :stop, :restart].each do |action|
        class_eval <<-TEXT
	  def #{action}(container)
	    args = [
              binary,
	      '#{action}',
	      container,
            ]
	    run(args, live_stream: $stdout)
	  end
	TEXT
      end

      def run(*args, **kwopts)
        cmd = Mixlib::ShellOut.new(args.join(' '), kwopts)
	cmd.run_command
	cmd.error!
	cmd.stdout
      end
    end
  end
end

