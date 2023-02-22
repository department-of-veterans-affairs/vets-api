require_relative 'lib/mocked_authentication/version'

Gem::Specification.new do |spec|
  spec.name          = 'mocked_authentication'
  spec.version       = MockedAuthentication::VERSION
  spec.authors       = ['Trevor Bosaw']
  spec.email         = ['trevor.bosaw@oddball.io']

  spec.summary       = 'Sign in Service Mocked Authentication'
  spec.description   = 'Mocked Authentication for developers that leverages Sign in Service'
  spec.homepage      = 'https://api.va.gov/'
  spec.license       = 'CC0'

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/department-of-veterans-affairs/vets-api/'
  spec.metadata['changelog_uri'] = 'https://github.com/department-of-veterans-affairs/vets-api/modules/mocked_authentication/CHANGELOG.md'

  spec.files = Dir['{app,config,lib}/**/*', 'Rakefile', 'README.md']

  spec.add_dependency 'rails', '~> 6.1.4', '>= 6.1.4.7'
end
