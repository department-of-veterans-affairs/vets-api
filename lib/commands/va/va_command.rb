require 'generators/module/module_generator'

module Va
  module Command
    class VaCommand < Rails::Command::Base
      namespace 'va'

      no_commands do
        def help
          Rails::Command.invoke :application, ["--help"]
        end
      end

      def perform(type = nil, *args)

        run_generator %w( --help ) unless type == "new"
        run_generator args
        ModuleGenerator.start args
      end


      desc 'create_user', 'Creates an admin user'

      def create_user
        require_application_and_environment!
        name = ask("What is your name?")
        email = ask("What is your email address?")
        password = ask("Please choose a password.", echo: false)
        say("\n")
        password_confirmation = ask("Please confirm your password.", echo: false)

        ::Exposition::User.create!(
          name: name, email: email, password: password,
          password_confirmation: password_confirmation
        )
      end

      desc "list_users", "Lists all the admin users"

      def list_users
        require_application_and_environment!
        users = Exposition::User.all
        users = users.map do |user|
          [user.name, user.email]
        end
        say("Exposition users")
        print_table(users)
      end

      private

      def run_generator(args)
        # require "rails/generators"
        # require "rails/generators/rails/plugin/plugin_generator"
        # Rails::Generators::PluginGenerator.start plugin_args
        puts "gen #{args.inspect}"
      end
    end
  end
end
