# frozen_string_literal: true

# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'

require 'rspec/rails'
require_relative 'covid_research_spec_helper'

RSpec.configure { |config| config.use_transactional_fixtures = true }
RSpec.configure { |config| config.include CovidResearchSpecHelper }
