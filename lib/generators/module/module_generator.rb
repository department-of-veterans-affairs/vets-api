# frozen_string_literal: true

require 'rails/generators'

class ModuleGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  def create_app
    path = "modules/#{file_name}/app"
    template 'app/controllers/controller.rb.erb',
             File.join(path, 'controllers', file_name, 'v0', "#{file_name}_controller.rb")
    template 'app/controllers/application_controller.rb.erb',
             File.join(path, 'controllers', file_name, 'application_controller.rb')
    template 'app/models/resource.rb.erb', File.join(path, 'models', file_name, 'resource.rb')
    template 'app/serializers/serializer.rb.erb',
             File.join(path, 'serializers', file_name, "#{file_name}_serializer.rb")
    template 'app/services/configuration.rb.erb', File.join(path, 'services', file_name, 'configuration.rb')
    template 'app/services/service.rb.erb', File.join(path, 'services', file_name, 'service.rb')
  end

  def create_lib
    path = "modules/#{file_name}/lib"
    template 'lib/namespace/engine.rb.erb', File.join(path, file_name, 'engine.rb')
    template 'lib/namespace/version.rb.erb', File.join(path, file_name, 'version.rb')
    template 'lib/tasks/tasks.rake.erb', File.join(path, 'tasks', "#{file_name}_tasks.rake")
    template 'lib/namespace.rb.erb', File.join(path, "#{file_name}.rb")
  end

  def create_config
    path = "modules/#{file_name}"
    template 'bin/rails.erb', File.join(path, 'bin', 'rails')
    chmod File.join(path, 'bin', 'rails'), 0o755
    template 'config/routes.rb.erb', File.join(path, 'config', 'routes.rb')
    template 'gemspec.erb', File.join(path, "#{file_name}.gemspec")
    template 'Rakefile.erb', File.join(path, 'Rakefile')
    template 'Gemfile.erb', File.join(path, 'Gemfile')
    template 'README.rdoc.erb', File.join(path, 'README.rdoc')
  end

  # rubocop:disable Rails/Output
  # :nocov:
  def install
    insert_into_file 'Gemfile', "gem '#{file_name}', path: 'modules/#{file_name}'\n", after: "# Modules\n"
    route "mount #{file_name.capitalize}::Engine, at: '/#{file_name}'"
    append_to_file 'config/settings.yml', "\n#{file_name}:\n  url: 'https://api.va.gov'"
    run 'bundle install'

    puts "\n"
    puts "\u{1F64C} new va module generated at ./modules/#{file_name}\n\n"
    puts "\u{1F680} run `rails s` then visit http://localhost:3000/#{file_name}/v0/hello_world to see your new endpoint"
    puts "\n"
  end
  # :nocov:
  # rubocop:enable Rails/Output
end
