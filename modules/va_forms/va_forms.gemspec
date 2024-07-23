# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'va_forms/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'va_forms'
  s.version     = VAForms::VERSION
  s.authors     = ['Charley Stran']
  s.email       = ['charley.stran@oddball.io']
  s.homepage    = 'https://api.va.gov/services/va_forms/docs/v0'
  s.summary     = 'VA Forms API'
  s.description = 'VA Forms API'
  s.license     = 'CC0'

  s.files = Dir['{app,config,db,lib}/**/*', 'Rakefile']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'faraday'
  s.add_dependency 'nokogiri'
  s.add_dependency 'sidekiq'

  s.add_development_dependency 'factory_bot_rails'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'rspec-rails'
end
