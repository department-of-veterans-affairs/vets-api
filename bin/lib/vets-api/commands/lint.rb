# frozen_string_literal: true

require_relative 'command'

module VetsApi
  module Commands
    class Lint < Command
      def self.run(args)
        Lint.new(args).execute # Command#execute
      end

      private

      def execute_native
        execute_commands(docker: false)
      end

      def execute_hybrid
        execute_native
      end

      def execute_docker
        execute_commands(docker: true)
      end

      def execute_commands(docker:)
        execute_command(rubocop_command, docker:) unless only_brakeman?
        execute_command(brakeman_command, docker:) unless only_rubocop?
        execute_command(bundle_audit_command, docker:) unless only_rubocop?
        execute_command(codeowners_command) unless only_rubocop? || only_brakeman?
      end

      def execute_command(command, docker: false)
        command = "docker compose run --rm --service-ports web bash -c \"#{command}\"" if docker
        puts "running: #{command}"
        ShellCommand.run(command)
      end

      def rubocop_command
        "bundle exec rubocop #{autocorrect} --color #{@inputs}".strip.gsub(/\s+/, ' ')
      end

      def brakeman_command
        'bundle exec brakeman --confidence-level=2 --no-pager --format=plain'
      end

      def bundle_audit_command
        'bundle exec bundle-audit check'
      end

      def codeowners_command
        '.github/scripts/check_codeowners.sh'
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
