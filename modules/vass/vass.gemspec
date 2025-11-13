# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'vass/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'vass'
  spec.version     = Vass::VERSION
  spec.authors     = ['VASS Team']
  spec.email       = ['vass_team@va.gov']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'An api.va.gov module'
  spec.description = 'This module handles non-authenticated appointment scheduling for first-time VA users'
  spec.license     = 'CC0-1.0'

  spec.files = Dir['{app,config,db,lib}/**/*', 'Rakefile', 'README.md']
  spec.test_files = Dir['spec/**/*']
end

