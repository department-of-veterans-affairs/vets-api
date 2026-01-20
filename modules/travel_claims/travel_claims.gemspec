# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'travel_claims/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'travel_claims'
  spec.version     = TravelClaims::VERSION
  spec.authors     = ['VA.gov']
  spec.email       = ['']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'Standalone travel claims submission'
  spec.description = 'Rails engine for standalone travel reimbursement claims submission without check-in flow'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,lib}/**/*', 'Rakefile', 'README.md']
  spec.test_files = Dir['spec/**/*']
end

