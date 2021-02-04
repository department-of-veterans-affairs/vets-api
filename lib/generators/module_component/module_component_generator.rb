# frozen_string_literal: true

require 'rails/generators'

class ModuleComponentGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)
  argument :methods, type: :array, default: [], banner: 'method method'
  attr_accessor :commit_message_methods

  COMPONENT_TYPES = %w[controller model serializer service].freeze

  def prompt_user
    unless Dir.exist?("modules/#{file_name}")
      `rails g module #{file_name}` if yes?("Module #{file_name} does not exist. Would you like to create it?")
    end
  end

  def create_component
    @commit_message_methods = []

    # Take each passed in argument (e.g.) controller, serializer, etc
    # and create the corresponding files within the module for each arg
    path = "modules/#{file_name}/app"
    methods.map(&:downcase).each do |method|
      if COMPONENT_TYPES.include? method
        commit_message_methods << method

        template_name = method == 'model' ? "#{file_name}.rb" : "#{file_name}_#{method}.rb"
        template "app/#{method.pluralize}/#{method}.rb.erb",
                 File.join(path, method.pluralize.to_s, file_name, 'v0', template_name.to_s)

        if method == 'service'
          template "app/#{method.pluralize}/configuration.rb.erb",
                   File.join(path, method.pluralize.to_s, file_name, 'v0', 'configuration.rb')
        end
      else
        $stdout.puts "\n#{method} is not a known generator command."\
          "Commands allowed are controller, model, serializer and service\n"
      end
    end
  end
end
