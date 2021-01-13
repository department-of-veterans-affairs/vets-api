# frozen_string_literal: true

require 'rails/generators'

class ModuleComponentGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)
  argument :methods, type: :array, default: [], banner: 'method method'
  attr_accessor :commit_message_methods

  COMPONENT_TYPES = %w[controller model serializer service].freeze

  def create_component
    @commit_message_methods = []

    unless Dir.exist?("modules/#{file_name}")
      `rails g module #{file_name}` if yes?("Module #{file_name} does not exist. Would you like to create it?")
    end

    # Take each passed in argument (e.g.) controller, serializer, etc
    # and create the corresponding files within the module for each arg
    path = "modules/#{file_name}/app"
    methods.map(&:downcase).each do |method|
      if COMPONENT_TYPES.include? method
        commit_message_methods << method
        template "app/#{method.pluralize}/#{method}.rb.erb",
                 File.join(path, method.pluralize.to_s, file_name, 'v0', "#{file_name}_#{method}.rb")

        if method == 'service'
          template "app/#{method.pluralize}/configuration.rb.erb",
                   File.join(path, method.pluralize.to_s, file_name, 'v0', 'configuration.rb')
        end
      else
        # rubocop:disable Rails/Output
        puts "\n"
        puts "#{method} is not a known generator command.
              Commands allowed are controller, model, serializer and service"
        puts "\n"
        # rubocop:enable Rails/Output
      end
    end
  end

  # :nocov:
  def create_commit_message
    unless commit_message_methods.nil?
      git add: '.'
      git commit: "-a -m 'Initial commit of new module #{commit_message_methods.join(', ')} *KEEP THIS COMMIT MESSAGE*'"
    end
  end
  # :nocov:
end
