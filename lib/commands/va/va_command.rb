# frozen_string_literal: true

require 'generators/module/module_generator'

module Va
  class Command
    class VaCommand < Rails::Command::Base
      namespace 'va'

      no_commands do
        def help
          Rails::Command.invoke :application, ['--help']
        end
      end

      def perform(type = nil, *args)
        Rails::Command.invoke :generate, ['module', '--help'] unless type == 'new'
        ModuleGenerator.start args
      end
    end
  end
end
