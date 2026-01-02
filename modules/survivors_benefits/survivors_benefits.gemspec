# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'survivors_benefits/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'survivors_benefits'
  spec.version     = SurvivorsBenefits::VERSION
  spec.authors     = ['VA Benefits Lifestage', 'Presidential Innovation Fellows']
  spec.email       = []
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'An api.va.gov module'
  spec.description = 'This module provides support for the 21P-534EZ to the vets-api'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
end
