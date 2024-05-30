# frozen_string_literal: true

require './rakelib/support/shell_command'

module VetsApi
  module Commands
    class Command
      attr_accessor :options, :inputs

      def initialize(args)
        @options = args.select { |a| a.start_with?('--', '-') }
        input_values = args.reject { |a| a.start_with?('--', '-') }
        @inputs = input_values.empty? ? default_inputs : input_values.join(' ')

        unless setup_preference_exists?
          puts 'You must run `bin/setup` before running other binstubs'
          exit 1
        end
      end

      def execute
        case File.read('.developer-setup').chomp
        when 'native'
          execute_native
        when 'hybrid'
          execute_hybrid
        when 'docker'
          execute_docker
        else
          puts 'Invalid option for .developer-setup'
        end
      end

      private

      def setup_preference_exists?
        File.exist?('.developer-setup')
      end

      def default_inputs
        ''
      end

      def execute_native
        raise NotImplementedError, 'This method should be overridden in a subclass'
      end

      def execute_hyrbid
        raise NotImplementedError, 'This method should be overridden in a subclass'
      end

      def execute_docker
        raise NotImplementedError, 'This method should be overridden in a subclass'
      end
    end
  end
end
