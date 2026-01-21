# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'increase_compensation/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'increase_compensation'
  spec.version     = IncreaseCompensation::VERSION
  spec.authors     = ['benefits-intake-pingwind']
  spec.email       = ['20232041+Tchase44@users.noreply.github.com']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'An api.va.gov module for the 21-8940'
  spec.description = '21-8940 form pdf filler and related Benifits Intake API actions'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
  spec.metadata['rubygems_mfa_required'] = 'true'
end
