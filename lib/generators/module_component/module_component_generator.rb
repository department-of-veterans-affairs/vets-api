# frozen_string_literal: true

require 'rails/generators'

class ModuleComponentGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)
  argument :methods, type: :array, default: [], banner: "method method"
  # class_option :types, type: :array, default: []

  COMPONENT_TYPES = ["controller", "model", "serializer", "service"]

  def create_component
    # check if the module and dir structure exists
    # if not, prompt the user - ask if they'd like to create
    if !Dir.exist?("modules/#{file_name}")
      if yes?("Module #{file_name} does not exist. Would you like to create it?")
        `rails g module #{file_name}`
      end
    end

    # Take each passed in argument (e.g.) controller, serializer, etc
    # and create the corresponding files within the module for each arg
    path = "modules/#{file_name}/app"
    methods.map(&:downcase).each do |method|
      if COMPONENT_TYPES.include? method
        template "app/#{method.pluralize}/#{method}.rb.erb",
                   File.join(path, "#{method.pluralize}", file_name, 'v0', "#{file_name}_#{method}.rb")
      else
        puts "\n"
        puts "#{method} is not a known type. Types allowed are controller, model and serializer "
        puts "\n"
      end
    end
  end
end
