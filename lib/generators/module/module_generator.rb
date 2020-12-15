# frozen_string_literal: true

require 'rails/generators'

class ModuleGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

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
  def update_and_install
    # spec helper add group
    insert_into_file 'spec/spec_helper.rb', "\tadd_group '#{file_name.camelize}',
      'modules/#{file_name}/'\n", after: "# Modules\n"

    # simplecov add group
    insert_into_file 'spec/simplecov_helper.rb', "\tadd_group '#{file_name.camelize}',
      'modules/#{file_name}/'\n", after: "# Modules\n"

    # insert into main app gemfile
    insert_into_file 'Gemfile', "\tgem '#{file_name}'\n", after: "path 'modules' do\n"
    route "mount #{file_name.camelize}::Engine, at: '/#{file_name}'"

    run 'bundle install'

    puts "\n"
    puts "\u{1F64C} new module generated at ./modules/#{file_name}\n\n"
    puts "\n"
  end
  # :nocov:
  # rubocop:enable Rails/Output
end
