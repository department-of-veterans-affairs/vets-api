# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'va_notify/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'va_notify'
  spec.version     = VaNotify::VERSION
  spec.authors     = ['Nathan Wright']
  spec.email       = ['nathan.wright@oddball.io']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'An api.va.gov module'
  spec.description = 'This module handles VaNotify integrations within vets-api'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
end
