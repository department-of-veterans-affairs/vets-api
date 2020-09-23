# frozen_string_literal: true

require 'generators/provider_state/provider_state_generator'

module Pact
  class Command
    class PactCommand < Rails::Command::Base
      namespace 'pact'

      no_commands do
        def help
          Rails::Command.invoke :application, ['--help']
        end
      end

      def perform(type = nil, *args)
        Rails::Command.invoke :generate, ['provider_state', '--help'] unless type == 'new'
        ProviderStateGenerator.start args
      end
    end
  end
end
