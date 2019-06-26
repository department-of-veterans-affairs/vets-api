# frozen_string_literal: true

$LOAD_PATH.push File.expand_path('lib', __dir__)

# Maintain your gem's version:
require 'vsp/version'

# Describe your gem and declare its dependencies:
Gem::Specification.new do |spec|
  spec.name        = 'vsp'
  spec.version     = Vsp::VERSION
  spec.authors     = ['Alastair Dawson']
  spec.email       = ['alastair.j.dawson@gmail.com']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'VSP Hello, World! App'
  spec.description = 'An example app that shows how to wire up an endpoint.'
  spec.license     = 'MIT'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  if spec.respond_to?(:metadata)
    spec.metadata['allowed_push_host'] = "TODO: Set to 'http://mygemserver.com'"
  else
    raise 'RubyGems 2.0 or newer is required to protect against ' \
      'public gem pushes.'
  end

  spec.files = Dir['{app,config,db,lib}/**/*', 'MIT-LICENSE', 'Rakefile', 'README.md']

  spec.add_dependency 'dry-struct'
  spec.add_dependency 'dry-types'
  spec.add_dependency 'fast_jsonapi'
  spec.add_dependency 'rails', '~> 5.2.3'
end
