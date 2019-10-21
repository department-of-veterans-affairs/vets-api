# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'vaos/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'vaos'
  spec.version     = VAOS::VERSION
  spec.authors     = ['Alastair Dawson']
  spec.email       = ['alastair.j.dawson@gmail.com']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'VAOS API'
  spec.description = 'VOAS (VA Online Scheduling) is part of VAMF (VA Mobile Framework) and allows veterans to make and manage appointments for care'
  spec.license     = 'MIT'

  spec.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']

  spec.add_dependency 'rails', '~> 5.2.3'
end
