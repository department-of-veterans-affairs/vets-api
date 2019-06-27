# frozen_string_literal: true
require 'rails/generators'
require 'pry'

class ModuleGenerator < Rails::Generators::NamedBase
  source_root File.expand_path('templates', __dir__)

  def create_module
    ns = file_name
    app_path = "modules/#{ns}/app"
    template 'controller.rb.erb', File.join(app_path, 'controllers', 'vsp', 'v0', "#{ns}_controller.rb")
    template 'application_controller.rb.erb', File.join(app_path, 'controllers', 'vsp', 'application_controller.rb')
    template 'resource.rb.erb', File.join(app_path, 'models', 'vsp', "#{ns}.rb")
    template 'serializer.rb.erb', File.join(app_path, 'serializers', 'vsp', "#{ns}_serializer.rb")
    template 'configuration.rb.erb', File.join(app_path, 'services', 'vsp', "configuration.rb")
    template 'service.rb.erb', File.join(app_path, 'services', 'vsp', "service.rb")
    route "mount #{ns.capitalize}::Engine, at: '/#{ns}'"
  end
end
