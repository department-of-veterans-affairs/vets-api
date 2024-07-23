# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'claims_api/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'claims_api'
  s.version     = ClaimsApi::VERSION
  s.authors     = ['Alex Teal']
  s.email       = ['alex.teal@oddball.io']
  s.homepage    = 'https://api.va.gov/services/claims/docs/v1'
  s.summary     = 'EVSS Claims Status'
  s.description = 'EVSS claim status API'
  s.license     = 'CC0'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.rdoc']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'dry-schema'

  s.add_development_dependency 'factory_bot_rails'
  s.add_development_dependency 'pg'
  s.add_development_dependency 'rspec-rails'
end
