# frozen_string_literal: true

# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'
# require File.expand_path('dummy/config/environment.rb', __dir__)

require 'rspec/rails'

Prawn::Fonts::AFM.hide_m17n_warning = true

ENGINE_RAILS_ROOT = File.join(File.dirname(__FILE__), '../')

# Requires supporting ruby files with custom matchers and macros, etc,
# in spec/support/ and its subdirectories.
Dir[File.join(ENGINE_RAILS_ROOT, 'spec/support/**/*.rb')].sort.each { |f| require f }

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.filter_run :focus

  # Skip generating certain WIP docs by default, unless we ask to via the WIP_DOCS_ENABLED env var
  wip_docs_enabled = ENV.fetch('WIP_DOCS_ENABLED', '').split(',')
  Settings.modules_appeals_api.documentation.wip_docs&.each do |flag|
    config.filter_run_excluding "wip_doc_#{flag}".to_sym unless wip_docs_enabled.include?(flag)
  end
end
