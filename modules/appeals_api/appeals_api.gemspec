# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'appeals_api/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'appeals_api'
  s.version     = AppealsApi::VERSION
  s.authors     = ['Edward Paget']
  s.email       = ['ed@adhocteam.us}']
  s.homepage    = 'https://api.vets.gov/services/appeals/docs/v0'
  s.summary     = 'Caseflow appeals status'
  s.description = 'Caseflow appeals status API'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.rdoc']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'rails', '~> 4.2.7.1'

  s.add_development_dependency 'rspec-rails'
end
