# frozen_string_literal: true

require_relative 'command'

module VetsApi
  module Commands
    class Test < Command
      def self.run(args)
        Test.new(args).execute # Command#execute
      end

      private

      def default_inputs
        'spec modules'
      end

      def execute_native
        execute_command(rspec_command, docker: false)
      end

      def execute_hybrid
        execute_native
      end

      def execute_docker
        execute_command(rspec_command, docker: true)
      end

      def execute_command(command, docker:)
        command = "docker compose run --rm --service-ports web bash -c \"#{command}\"" if docker
        puts "running: #{command}"
        system(command)
        puts 'Results can be found at log/rspec.log' if @options.include?('--log')
      end

      def rspec_command
        runtime_variables = 'DISABLE_PRY=1 RAILS_ENV=test DISABLE_BOOTSNAP=true'
        "#{runtime_variables} #{coverage} #{test_command} #{@inputs} #{test_options}".strip.gsub(/\s+/, ' ')
      end

      def coverage
        @options.include?('--coverage') ? '' : ' NOCOVERAGE=true'
      end

      def parallel?
        @options.include?('--parallel')
      end

      def test_command
        parallel? ? 'bundle exec parallel_rspec' : 'bundle exec rspec'
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
