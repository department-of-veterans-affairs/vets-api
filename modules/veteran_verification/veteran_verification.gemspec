# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'veteran_verification/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'veteran_verification'
  s.version     = VeteranVerification::VERSION
  s.authors     = ['Edward Paget']
  s.email       = ['ed@adhocteam.us']
  s.homepage    = 'https://api.vets.gov/services/veteran_verification/docs/v0/api'
  s.summary     = 'Veteran Verification APIs'
  s.description = 'Collection of API resources intended for 3rd verification of veteran status and service history'
  s.license     = 'MIT'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.rdoc']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'rails', '~> 4.2.7.1'

  s.add_development_dependency 'rspec-rails'
end
