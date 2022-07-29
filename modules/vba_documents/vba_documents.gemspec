# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'vba_documents/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'vba_documents'
  s.version     = VBADocuments::VERSION
  s.authors     = ['Patrick Vinograd']
  s.email       = ['patrick@adhocteam.us']
  s.homepage    = 'https://api.va.gov/services/vba_documents/docs/v1/api'
  s.summary     = 'VBA Documents Upload'
  s.description = 'VBA Documents Upload API'
  s.license     = 'CC0'

  s.files = Dir['{app,config,db,lib}/**/*', 'Rakefile']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'aws-sdk-s3', '~> 1'
  s.add_dependency 'sidekiq'

  s.add_development_dependency 'factory_bot_rails'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'rspec-rails'
end
