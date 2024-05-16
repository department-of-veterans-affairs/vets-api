# frozen_string_literal: true

require './rakelib/support/shell_command'

module VetsApi
  module Commands
    class Lint
      attr_accessor :options, :inputs

      def self.run(args)
        Lint.new(args)
      end

      def initialize(args)
        @options = args.select { |a| a.start_with?('--', '-') }
        input_values = args.reject { |a| a.start_with?('--', '-') }
        @inputs = input_values.empty? ? '' : input_values.join(' ')

        case File.read('.developer-setup').chomp
        when 'native', 'hybrid'
          lint_native
        when 'docker'
          lint_docker
        else
          puts 'Invalid option for .developer-setup'
        end
      end

      private

      def lint_native
        unless only_brakeman?
          puts "running: #{rubocop_command_builder}"
          ShellCommand.run(rubocop_command_builder)
          puts
        end
        unless only_rubocop?
          puts "running: #{brakeman_command_builder}"
          ShellCommand.run(brakeman_command_builder)
          puts
          puts 'running: bundle-audit check'
          ShellCommand.run('bundle-audit check')
        end
      end

      def lint_docker
        docker_rubocop_command = "docker-compose run --rm --service-ports web bash -c \"#{rubocop_command_builder}\""
        docker_brakeman_command = "docker-compose run --rm --service-ports web bash -c \"#{brakeman_command_builder}\""

        unless only_brakeman?
          puts "running: #{docker_rubocop_command}"
          ShellCommand.run(docker_rubocop_command)
          puts
        end
        unless only_rubocop?
          puts "running: #{docker_brakeman_command}"
          ShellCommand.run(docker_brakeman_command)
          puts
          puts 'running: docker-compose run --rm --service-ports web bash -c "bundle-audit check"'
          ShellCommand.run('docker-compose run --rm --service-ports web bash -c "bundle-audit check"')
        end
      end

      def rubocop_command_builder
        "bundle exec rubocop #{autocorrect} --color #{@inputs}".strip.gsub(/\s+/, ' ')
      end

      def brakeman_command_builder
        'bundle exec brakeman --ensure-latest --confidence-level=2 --no-pager --format=plain'
      end

      def autocorrect
        @options.include?('--dry') ? '' : ' -a'
      end

      def only_rubocop?
        @options.include?('--only-rubocop')
      end

      def only_brakeman?
        @options.include?('--only-brakeman')
      end
    end
  end
end
