# frozen_string_literal: true

require './rakelib/support/shell_command'

module VetsApi
  module Commands
    class Test
      attr_accessor :options, :inputs

      def self.run(args)
        Test.new(args)
      end

      def initialize(args)
        @options = args.select { |a| a.start_with?('--', '-') }
        input_values = args.reject { |a| a.start_with?('--', '-') }
        @inputs = input_values.empty? ? 'spec modules' : input_values.join(' ')

        case File.read('.developer-setup').chomp
        when 'native', 'hybrid'
          test_native
        when 'docker'
          test_docker
        else
          puts 'Invalid option for .developer-setup'
        end
        puts 'Results can be found at log/rspec.log' if @options.include?('--log')
      rescue Errno::ENOENT
        puts "You must run `bin/setup` before running other binstubs"
        exit 1
      end

      private

      def test_native
        puts "running: #{rspec_command_builer}"
        ShellCommand.run(rspec_command_builer)
      end

      def test_docker
        docker_rspec_command = "docker-compose run --rm --service-ports web bash -c \"#{rspec_command_builer}\""
        puts "running: #{docker_rspec_command}"
        ShellCommand.run(docker_rspec_command)
      end

      def rspec_command_builer
        runtime_variables = 'RAILS_ENV=test DISABLE_BOOTSNAP=true'
        "#{runtime_variables} #{coverage} bundle exec #{test_command} #{@inputs} #{test_options}".strip.gsub(
          /\s+/, ' '
        )
      end

      def coverage
        @options.include?('--coverage') ? '' : ' NOCOVERAGE=true'
      end

      def parallel?
        !@options.include?('--no-parallel') # rubocop:disable Rails/NegateInclude
      end

      def test_command
        parallel? ? 'parallel_rspec' : 'rspec'
      end

      def test_options
        return '' if log.empty?

        parallel? ? "-o \"#{log}\"" : log
      end

      def log
        @options.include?('--log') ? '--out log/rspec.log' : ''
      end
    end
  end
end
