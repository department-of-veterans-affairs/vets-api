# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'ivc_champva/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'ivc_champva'
  spec.version     = IvcChampva::VERSION
  spec.authors     = ['Bryan Alexander', 'Don Shin']
  spec.email       = ['bryan.alexander@adhocteam.us', 'donald.shin@agile6.com']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'An api.va.gov module'
  spec.description = 'This module is responsible for parsing and filling IVC CHAMPVA forms'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
end
