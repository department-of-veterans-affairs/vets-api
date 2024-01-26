require_relative 'commands/help'
require_relative 'commands/info'
require_relative 'commands/setup'
require_relative 'setups/native'
require_relative 'setups/docker'
require_relative 'setups/hybrid'

module VetsApi
  class Cli
    def self.run(args)
      option = args.first
      case option
      when '--help', '-h'
        VetsApi::Commands::Help.run
      when 'info'
        VetsApi::Commands::Info.run
      when 'setup'
        VetsApi::Commands::Setup.run(args)
      else
        puts "Invalid option \"#{option}\". Use \"--help\" for usage information."
      end
    end
  end
end
