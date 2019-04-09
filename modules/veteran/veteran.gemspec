# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('../lib', __FILE__)

# Maintain your gem's version:
require 'veteran/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |s|
  s.name        = 'veteran'
  s.version     = Veteran::VERSION
  s.authors     = ['Michael Bastos']
  s.email       = ['bastosmichael@gmail.com']
  s.homepage    = 'https://api.vets.gov/services/veteran/docs/v0/api'
  s.summary     = 'Veteran APIs'
  s.description = 'Collection of API resources intended for Veteran related data queries.'
  s.license     = 'CC0'

  s.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.rdoc']
  s.test_files = Dir['spec/**/*']

  s.add_dependency 'rails', '~> 4.2.11.1'

  s.add_development_dependency 'rspec-rails'
end
