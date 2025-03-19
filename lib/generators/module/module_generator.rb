# frozen_string_literal: true

require 'rails/generators'
require 'generators/module_helper'

class ModuleGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)
  include ModuleHelper

  def create_directory_structure
    # create the dir structure
    %w[controllers models serializers services].each do |dir|
      FileUtils.mkdir_p "modules/#{file_name}/app/#{dir}/#{file_name}"
      FileUtils.touch("modules/#{file_name}/app/#{dir}/#{file_name}/.gitkeep")
    end

    # create the Rspec dir structure
    %w[controllers models lib serializers services factories support].each do |dir|
      FileUtils.mkdir_p "modules/#{file_name}/spec/#{dir}/#{file_name}"
      FileUtils.touch("modules/#{file_name}/spec/#{dir}/#{file_name}/.gitkeep")
    end

    # create the documentation folder
    FileUtils.mkdir_p "modules/#{file_name}/documentation/"
    FileUtils.touch("modules/#{file_name}/documentation/.gitkeep")
  end

  def create_engine
    # create engine file
    path = "modules/#{file_name}/lib"
    template 'lib/namespace/engine.rb.erb', File.join(path, file_name, 'engine.rb')
    template 'lib/namespace/version.rb.erb', File.join(path, file_name, 'version.rb')
    template 'lib/namespace.rb.erb', File.join(path, "#{file_name}.rb")
  end

  def create_additional_files
    path = "modules/#{file_name}"

    # create rakefile
    template 'Rakefile.erb', File.join(path, 'Rakefile')

    # create readme
    template 'README.rdoc.erb', File.join(path, 'README.rdoc')

    # create bin/rails
    template 'bin/rails.erb', File.join(path, 'bin', 'rails')
    chmod File.join(path, 'bin', 'rails'), 0o755

    # /spec/spec_helper
    template 'spec/spec_helper.rb.erb', File.join(path, 'spec', 'spec_helper.rb')

    # create the routes file
    template 'config/routes.rb.erb', File.join(path, 'config', 'routes.rb')

    # create gemspec
    template 'gemspec.erb', File.join(path, "#{file_name}.gemspec")

    # create gemfile
    template 'Gemfile.erb', File.join(path, 'Gemfile')

    # create adr-dir
    template 'adr-dir.erb', File.join(path, '.adr-dir')

    # create irbrc
    template 'irbrc.erb', File.join(path, '.irbrc')

    # create rspec
    template 'rspec.erb', File.join(path, '.rspec')

    # create gitignore
    template 'gitignore.erb', File.join(path, '.gitignore')
  end

  # rubocop:disable Rails/Output
  def update_spec_helper
    options_hash = {}
    options_hash[:regex] = /# Modules(.*)# End Modules/m
    options_hash[:insert_matcher] = "add_group '#{file_name.camelize}', 'modules/#{file_name}/'"
    options_hash[:new_entry] = "    add_group '#{file_name.camelize}', " \
                               "'modules/#{file_name}/'\n"

    module_generator_file_insert('spec/spec_helper.rb', options_hash)
  end

  def update_simplecov_helper
    # spec and simplecov helper add group

    options_hash = {}
    options_hash[:regex] = /# Modules(.*)end/m
    options_hash[:insert_matcher] = "add_group '#{file_name.camelize}', 'modules/#{file_name}/'"
    options_hash[:new_entry] = "    add_group '#{file_name.camelize}', " \
                               "'modules/#{file_name}/'\n"

    module_generator_file_insert('spec/simplecov_helper.rb', options_hash)
  end

  def update_gemfile
    options_hash = {}
    options_hash[:insert_matcher] = "gem '#{file_name}'"
    options_hash[:new_entry] = "  #{options_hash[:insert_matcher]}\n"

    module_generator_file_insert('Gemfile', options_hash)
  end

  def update_routes_file
    options_hash = {}
    options_hash[:regex] = /# Modules(.*)# End Modules/m
    options_hash[:insert_matcher] = "mount #{file_name.camelize}::Engine, at: '/#{file_name}'"
    options_hash[:new_entry] = "  mount #{file_name.camelize}::Engine, at: '/#{file_name}'\n"

    module_generator_file_insert('config/routes.rb', options_hash)
  end

  # :nocov:
  def update_and_install
    run 'bundle install'
    puts "\n\u{1F64C} new module generated at ./modules/#{file_name}\n\n\n"
  end
  # :nocov:
  # rubocop:enable Rails/Output
end
