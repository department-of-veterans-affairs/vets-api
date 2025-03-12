# frozen_string_literal: true

require 'rails/generators'

class ModuleComponentGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)
  argument :methods, type: :hash

  COMPONENT_TYPES = %w[controller model serializer service].freeze

  def prompt_user
    if !Dir.exist?("modules/#{file_name}") && yes?("Module #{file_name} does not exist. Would you like to create it?")
      `rails g module #{file_name}`
    end
  end

  def create_component
    # Take each passed in argument (e.g.) controller, serializer, etc
    # and create the corresponding files within the module for each arg
    path = "modules/#{file_name}/app"
    methods_hash = methods.to_h
    method = methods_hash['method']
    component_name = methods_hash['component_name'] || file_name

    if COMPONENT_TYPES.include? method
      template_name = method == 'model' ? "#{component_name}.rb" : "#{component_name}_#{method}.rb"
      template "app/#{method.pluralize}/#{method}.rb.erb",
               File.join(path, method.pluralize.to_s, file_name, 'v0', template_name.to_s), comp_name

      if method == 'service'
        template "app/#{method.pluralize}/configuration.rb.erb",
                 File.join(path, method.pluralize.to_s, file_name, 'v0', 'configuration.rb'), comp_name
      end
    else
      $stdout.puts "\n#{method} is not a known generator command." \
                   "Commands allowed are controller, model, serializer and service\n"
    end
  end

  private

  def comp_name
    methods_hash = methods.to_h
    @comp_name = methods_hash['component_name'] || file_name
  end
end
