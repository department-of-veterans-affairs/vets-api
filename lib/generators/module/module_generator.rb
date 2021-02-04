# frozen_string_literal: true

require 'rails/generators'
require 'generators/module_helper'

class ModuleGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)
  include ModuleHelper

  def create_directory_structure
    # create the dir structure here
    %w[controllers models serializers service].each do |dir|
      FileUtils.mkdir_p "modules/#{file_name}/app/#{dir}" unless Dir.exist?("modules/#{file_name}/app/#{dir}")
    end
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
  end

  # rubocop:disable Rails/Output
  # :nocov:
  def update_spec_and_simplecov_helper
    # spec and simplecov helper add group

    options = {}
    options[:regex] = /# Modules(.*)end/m
    options[:insert_matcher] = "add_group '#{file_name.camelize}', 'modules/#{file_name}/'"
    options[:new_entry] = "\tadd_group '#{file_name.camelize}'," \
                       "'modules/#{file_name}/'\n"

    module_generator_file_insert('spec/simplecov_helper.rb', options)

    options = {}
    options[:regex] = /# Modules(.*)# End Modules/m
    options[:insert_matcher] = "add_group '#{file_name.camelize}', 'modules/#{file_name}/'"
    options[:new_entry] = "\tadd_group '#{file_name.camelize}'," \
                       "'modules/#{file_name}/'\n"

    module_generator_file_insert('spec/spec_helper.rb', options)
  end

  def update_gemfile
    options = {}
    options[:insert_matcher] = "gem '#{file_name}'"
    options[:new_entry] = "\t#{options[:insert_matcher]}\n"

    module_generator_file_insert('Gemfile', options)
  end

  def update_routes_file
    helper_file = File.read('config/routes.rb')
    existing_entries = helper_file.match(/# Modules(.*)# End Modules/m).to_s.split("\n")

    ## removes the begining and ending matcher
    existing_entries.pop
    existing_entries.shift

    new_entry = "\tmount #{file_name.camelize}::Engine, at: '/#{file_name}'\n"

    existing_entries.each do |entry|
      # if the current entry is alphabetically greater
      # insert new entry before
      if entry.strip > "mount #{file_name.camelize}::Engine, at: '/#{file_name}'"
        insert_into_file 'config/routes.rb', new_entry.to_s, before: entry.to_s
        return true
      end
    end
  end

  def update_and_install
    # spec helper add group
    # Don't add these entries to the files in test env/running specs
    unless Rails.env.test?
      # insert into main app gemfile
      # insert_into_file 'Gemfile', "\tgem '#{file_name}'\n", after: "path 'modules' do\n"
      #
      # insert_into_file 'config/routes.rb',
      #                  "\tmount #{file_name.camelize}::Engine, at: '/#{file_name}'\n", after: "# Modules\n"

      run 'bundle install'

      puts "\n\u{1F64C} new module generated at ./modules/#{file_name}\n\n\n"
    end
  end

  # :nocov:
  # rubocop:enable Rails/Output
end
