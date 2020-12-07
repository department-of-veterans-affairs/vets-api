# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'covid_vaccine/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'covid_vaccine'
  s.version     = CovidVaccine::VERSION
  s.authors     = ['Kam Karshenas']
  s.email       = ['kam@adhocteam.us']
  s.homepage    = 'https://api.va.gov'
  s.summary     = 'COVID-19 Registry API'
  s.description = 'The Vetext COVID-19 Vaccine Registry API allows for adding veterans into a vaccine registry database.'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.rdoc']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'sidekiq'
  s.add_development_dependency 'factory_bot_rails'
  s.add_development_dependency 'rspec-rails'
end
