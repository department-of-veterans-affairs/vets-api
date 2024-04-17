# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'in_progress_forms/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'in_progress_forms'
  spec.version     = InProgressForms::VERSION
  spec.authors     = ['Sam Raudabaugh']
  spec.email       = ['sraudabaugh@gmail.com']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'An api.va.gov module'
  spec.description = 'This module was auto-generated please update this description'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
  spec.test_files = Dir['spec/**/*']
  spec.add_development_dependency 'rspec-rails'
end
