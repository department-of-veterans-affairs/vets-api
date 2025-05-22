# frozen_string_literal: true

# Configure Rails Envinronment
ENV['RAILS_ENV'] = 'test'

require 'rspec/rails'

module Faker
  class Form < Base
    class << self
      def id
        prefix = Faker::Number.number(digits: 4)
        suffix = Faker::Alphanumeric.alpha(number: 2).upcase
        "#{prefix}#{suffix}"
      end
    end
  end
end

module VcrHelpers
  VCR_OPTIONS = {
    match_requests_on: %i[
      method uri headers body
    ].freeze
  }.freeze

  ##
  # This helper encodes best practices for using VCR:
  # - Matching requests on all of its attributes
  # - Placing cassettes in a uniform location, derived from the spec's location
  #
  # **Example cassette location**
  #
  # If invoked with:
  #   `use_cassette('insertions_and_deletions')`
  # Within a spec located at:
  #   `modules/accredited_representative_portal/spec/sidekiq/accredited_representative_portal/allow_list_sync_job_spec.rb` # rubocop:disable Layout/LineLength
  # Cassette will be located at:
  #   `spec/support/vcr_cassettes/accredited_representative_portal/sidekiq/accredited_representative_portal/allow_list_sync_job_spec/insertions_and_deletions.yml` # rubocop:disable Layout/LineLength
  #
  def use_cassette(name, options = {}, &)
    options.with_defaults!(
      **VCR_OPTIONS,
      use_spec_name_prefix: true
    )

    options.delete(:use_spec_name_prefix) and
      name = spec_name_prefix / name

    VCR.use_cassette(name, options, &)
  end

  private

  def spec_name_prefix
    caller.each do |call|
      call = call.split(':').first
      next unless call.end_with?('_spec.rb')

      call.delete_prefix!((AccreditedRepresentativePortal::Engine.root / 'spec/').to_s)
      call.delete_suffix!('.rb')
      return Pathname('accredited_representative_portal') / call
    end
  end
end

module FixtureHelpers
  def load_fixture(path_suffix)
    path =
      AccreditedRepresentativePortal::Engine.root /
      'spec/fixtures/' /
      path_suffix

    fixture = File.read(path)
    fixture = yield(fixture) if block_given?
    fixture
  end
end

RSpec.configure do |config|
  config.use_transactional_fixtures = true
  config.filter_run :focus

  config.include VcrHelpers
  config.include ActiveSupport::Testing::TimeHelpers
  config.extend FixtureHelpers
  config.include FixtureHelpers
end
