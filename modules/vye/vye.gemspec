# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'vye/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'vye'
  spec.version     = Vye::VERSION
  spec.authors     = ['Vanson Samuel']
  spec.email       = ['37637+binq@users.noreply.github.com']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'An api.va.gov module'
  spec.description = 'This module was auto-generated please update this description'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib,spec}/**/*', 'Rakefile', 'README.md']

  spec.add_development_dependency 'rspec-rails'

  # Rubocop flagged this missing and Claude.ai says it won't break anything
  spec.metadata['rubygems_mfa_required'] = 'true'
end
