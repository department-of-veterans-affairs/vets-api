# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'digital_forms_api/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'digital_forms_api'
  spec.version     = DigitalFormsApi::VERSION
  spec.authors     = ['Bryan Alexander']
  spec.email       = ['bryan.alexander@adhocteam.us']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'An api.va.gov module'
  spec.description = 'This module was auto-generated please update this description'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
end
