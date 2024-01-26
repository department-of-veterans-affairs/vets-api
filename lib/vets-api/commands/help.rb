module VetsApi
  module Commands
    class Help
      def self.run
        puts <<~HELP
          Usage:
            bin/vets [options]
            bin/vets [command] [options]

          Options:
            --help, -h        Display help message

          Commands
            info              Display version related informtation
            setup             Create the base developer setup

          Examples:
            bin/vets --help   Show help message

        HELP
      end
    end
  end
end
