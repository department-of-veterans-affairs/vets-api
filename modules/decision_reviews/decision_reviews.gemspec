require_relative "lib/decision_reviews/version"

Gem::Specification.new do |spec|
  spec.name        = "decision_reviews"
  spec.version     = DecisionReviews::VERSION
  spec.authors     = ['Benefits Decision Reviews']
  spec.email       = ['']
  spec.homepage    = 'https://api.va.gov'
  spec.summary     = 'An api.va.gov module'
  spec.description = 'API code for Decision Review forms and evidence'
  spec.license     = 'CC0-1.0'

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the "allowed_push_host"
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata["allowed_push_host"] = "TODO: Set to 'http://mygemserver.com'"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 7.1.4.1"
end
