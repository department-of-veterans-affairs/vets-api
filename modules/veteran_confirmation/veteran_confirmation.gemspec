# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'veteran_confirmation/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'veteran_confirmation'
  s.version     = VeteranConfirmation::VERSION
  s.authors     = ['Ryan Travitz']
  s.email       = ['ryan.travitz@adhocteam.us']
  s.homepage    = 'https://api.va.gov/services/veteran_confirmation/docs/v0/api'
  s.summary     = 'Veteran Confirmation API'
  s.description = 'Collection of API resources intended for confirmation of veteran status'
  s.license     = 'CC0'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.rdoc']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'rails', '~> 5.2.3'

  s.add_development_dependency 'rspec-rails'
end
