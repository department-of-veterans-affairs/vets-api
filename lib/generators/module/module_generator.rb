class ModuleGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  def create_directory_structure
    # create the dir structure here
  end

  def create_and_configure
    # create engine file
    # create rakefile
    # create readme
    # create bin/rails

    #spec helper add group
    # simplecov add group
    # /spec/spec_helper
    # create gemspec
    # create gemfile
  end

  #load into gemfile here
  # run bundle
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
end
