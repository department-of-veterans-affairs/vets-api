# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'time_of_need/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'time_of_need'
  spec.version     = TimeOfNeed::VERSION
  spec.authors     = ['NCA Time of Need']
  spec.email       = ['']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'Time of Need burial scheduling form (40-4962)'
  spec.description = 'Handles burial scheduling requests submitted through VA.gov, routed to NCA via MuleSoft → MDW → CaMEO'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
end
