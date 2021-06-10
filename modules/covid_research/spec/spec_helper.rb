# frozen_string_literal: true

# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'
# require File.expand_path('dummy/config/environment.rb', __dir__)

require 'rspec/rails'
require_relative 'covid_research_spec_helper'

ENGINE_RAILS_ROOT = File.join(File.dirname(__FILE__), '../')

RSpec.configure { |config| config.use_transactional_fixtures = true }
RSpec.configure { |config| config.include CovidResearchSpecHelper }
