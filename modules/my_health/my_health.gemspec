require_relative "lib/my_health/version"

Gem::Specification.new do |spec|
  spec.name        = "my_health"
  spec.version     = MyHealth::VERSION
  spec.authors     = ["Patrick Vinograd"]
  spec.email       = ["patrick@adhocteam.us"]
  spec.homepage    = "https://api.va.gov/"
  spec.summary     = "VA.gov MyHealth APIs"
  spec.description = "APIs that power the MyHealth features of VA.gov"
  spec.license     = "CC0"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/department-of-veterans-affairs/vets-api/"
  spec.metadata["changelog_uri"] = "https://github.com/department-of-veterans-affairs/vets-api/modules/my_health/CHANGELOG.md"

  spec.files = Dir["{app,config,db,lib}/**/*", "Rakefile", "README.md"]

  spec.add_dependency "rails", "~> 6.1.4", ">= 6.1.4.7"
end
