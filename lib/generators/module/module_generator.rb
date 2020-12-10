class ModuleGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  def create_directory_structure
    # create the dir structure here
  end

  def create_engine
  # create engine file
    path = "modules/#{file_name}/lib"
    template 'lib/namespace/engine.rb.erb', File.join(path, file_name, 'engine.rb')
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

    # create the routes file
    template 'config/routes.rb.erb', File.join(path, 'config', 'routes.rb')

    # create gemspec
    template 'gemspec.erb', File.join(path, "#{file_name}.gemspec")

    # create gemfile
    template 'Gemfile.erb', File.join(path, 'Gemfile')


  end

  def update_configurations
    # spec helper add group
    # insert_into_file 'spec/spec_helper.rb', "add_group '#{file_name.constantize}', 'modules/#{file_name}'\n", after: "# Modules\n"

    # simplecov add group
    # insert_into_file 'spec/simplecov_helper.rb', "add_group '#{file_name.constantize}', 'modules/#{file_name}'\n", after: "# Modules\n"
  end

  # load into gemfile here
  # run bundle
  def install
    insert_into_file 'Gemfile', "gem '#{file_name}', path: 'modules/#{file_name}'\n", after: "# Modules\n"
    route "mount #{file_name.capitalize}::Engine, at: '/#{file_name}'"
    # Do we want this?
    # append_to_file 'config/settings.yml', "\n#{file_name}:\n  url: 'https://api.va.gov'"
    run 'bundle install'

    puts "\n"
    puts "\u{1F64C} new module generated at ./modules/#{file_name}\n\n"
    puts "\n"
  end
end
