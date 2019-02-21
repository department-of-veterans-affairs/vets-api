# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'va_facilities/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'va_facilities'
  s.version     = VaFacilities::VERSION
  s.authors     = ['Patrick Vinograd']
  s.email       = ['patrick@adhocteam.us']
  s.homepage    = 'https://api.va.gov/services/facilities/docs/v0'
  s.summary     = 'VA Facilities'
  s.description = 'VA Facilities API'
  s.license     = 'CC0'

  s.files = Dir['{app,config,db,lib}/**/*', 'Rakefile']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'rails', '~> 5.0.7.1'

  s.add_development_dependency 'rspec-rails'
end
