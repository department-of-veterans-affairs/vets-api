# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'employment_questionnaires/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'employment_questionnaires'
  spec.version     = EmploymentQuestionnaires::VERSION
  spec.authors     = ['VA Benefits Lifestage']
  spec.email       = []
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'An api.va.gov module'
  spec.description = 'This module was auto-generated please update this description'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
  spec.metadata['rubygems_mfa_required'] = 'true'
end
