# frozen_string_literal: true

require './rakelib/support/shell_command'
require 'shellwords'

module VetsApi
  module Commands
    class Command
      attr_accessor :options, :inputs

      def initialize(args)
        @options = args.select { |a| a.start_with?('--', '-') }
        input_values = args.reject { |a| a.start_with?('--', '-') }
        @inputs = input_values.empty? ? default_inputs : sanitized_inputs(input_values)

        unless setup_preference_exists? || is_a?(Setup)
          puts 'You must run `bin/setup` before running other binstubs'
          exit 1
        end
      end

      def execute
        case setup_preference
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

      def setup_preference
        File.read('.developer-setup').chomp
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

      def sanitized_inputs(input_values)
        input_values.map { |value| Shellwords.escape(value) }.join(' ')
      end
    end
  end
end
