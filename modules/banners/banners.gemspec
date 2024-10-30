# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'banners/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'banners'
  spec.version     = Banners::VERSION
  spec.authors     = ['Daniel Sasser']
  spec.email       = ['221539+dsasser@users.noreply.github.com']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'An api.va.gov module'
  spec.description = 'The Banners API.'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
  spec.metadata['rubygems_mfa_required'] = 'true'
end
