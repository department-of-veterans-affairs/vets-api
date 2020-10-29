# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'apps_api/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'apps_api'
  s.version     = AppsApi::VERSION
  s.authors     = ['Charley Stran', 'Braden Shipley']
  s.email       = ['braden.shipley@oddball.io']
  s.homepage    = 'https://api.va.gov/services/apps_api/docs/v0'
  s.summary     = 'Applications API'
  s.description = 'Applications API'
  s.license     = 'CC0'

  s.files = Dir['{app,config,db,lib}/**/*', 'Rakefile']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'faraday'
  s.add_dependency 'sidekiq'

  s.add_development_dependency 'factory_bot_rails'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'rspec-rails'
end
