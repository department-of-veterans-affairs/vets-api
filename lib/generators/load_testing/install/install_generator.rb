module LoadTesting
  class InstallGenerator < Rails::Generators::Base
    source_root File.expand_path('templates', __dir__)

    def create_initializer
      template 'initializer.rb', 'config/initializers/load_testing.rb'
    end

    def mount_engine
      route "mount LoadTesting::Engine => '/load_testing'" unless load_testing_mounted?
    end

    private

    def load_testing_mounted?
      File.read('config/routes.rb').include?('LoadTesting::Engine')
    end
  end
end 